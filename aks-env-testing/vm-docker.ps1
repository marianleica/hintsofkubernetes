Write-Output "Creating an Azure VM running Ubuntu2204"
Start-Sleep -Seconds 1

# Setting variables
$timestamp = $(Get-Date -Format "yyyy/MM/dd-HH:mm UTCK")
$scenario="azvm-ubuntu2204ssh"
$suffix=$(Get-Random -Minimum 10000 -Maximum 99999)
#suffix=$((10000 + RANDOM % 99999))
$RG="azrez"
$location="uksouth"
$VM="azvm-ubuntu-${suffix}"
$image="Ubuntu2204"

# Generating a random string to use as password
$userName = "azrez"
#$randompass = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 30 | ForEach-Object {[char]$_})
#Read more: https://www.sharepointdiary.com/2020/04/powershell-generate-random-password.html#ixzz8XiwccFos
#$Password = ConvertTo-SecureString $randompass -AsPlainText -Force
#$psCred = New-Object System.Management.Automation.PSCredential($UserName, $Password)

Write-Output "Creating virtual machine ${VM} in resource group ${RG} in location ${location}"
Start-Sleep -Seconds 1
Write-Output ""

Write-Output "The Resource Group:"
# Create RG
az group create -n $RG -l $location
Start-Sleep -Seconds 1
Write-Output ""
Write-Output "The virtual machine ${VM}:"

# Create Ubuntu VM
# New-AzVm -ResourceGroupName $RG -Name $vmName -Location $location -Image $image -VirtualNetworkName "myVnet-${suffix}" -SubnetName "vmsubnet" -SecurityGroupName "vmNSG" -PublicIpAddressName $publicIp -OpenPorts 80,22 -GenerateSshKey
az vm create -n $VM -g $RG --image $image --generate-ssh-keys --admin-username $userName --size Standard_D2s_v3 --nsg-rule ssh --public-ip-sku Standard

Start-Sleep -Seconds 2
# This is the public IP address
# $vmip=$(az vm list-ip-addresses -g $rg -n $vmName --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
$vmip=$(az vm list-ip-addresses -g $RG -n $VM --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)

Start-Sleep -Seconds 1
Write-Output ""
Write-Output "The public IP address allocated to VM ${VM} is ${vmip}"
Write-Output "Save aside your credentials"
Write-Output "The admin user name is: ${userName}"
Write-Output ""
Start-Sleep -Seconds 1

# Logging
if (Test-Path -Path "C:\" -ErrorAction SilentlyContinue) {
    Write-Output "${timestamp}; {${scenario}; RG: ${RG}; Location: ${location}; ResType: VM; ResName: ${VM}; PublicIP: ${vmip}; Admin: azrez}" >> C:\azrez\azrez.log
} else {
    Write-Output "C drive not found, skipping logging."
}

# Run the docker install script commands inside the VM
az vm run-command create --resource-group $RG --async-execution false --run-as-user $userName --script "sudo wget -O - https://raw.githubusercontent.com/marianleica/azrez/refs/heads/progress/pwshjobs/azvm-ubuntu2204-docker-runcommand.sh | bash" --timeout-in-seconds 3600 --run-command-name "SetDockerUp" --vm-name $VM

# Look for user input to perform ssh connection right now
$userinput = Read-Host -Prompt "Do you want to connect to ${VM} via ssh now? (y/n)"
if ($userinput -eq "y"){az ssh vm -g $RG -n $VM --local-user $userName --yes}
else {Write-Output "Save the command for later: az ssh vm -g ${RG} -n ${VM} --local-user ${userName}"}
