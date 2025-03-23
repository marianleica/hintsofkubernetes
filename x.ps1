# Define private IP ranges
$privateIPRanges = @(
    "8.8.0.0/16"
)

# Function to calculate all IPs in a CIDR range
function Get-IPsFromCIDR {
    param (
        [string]$CIDR
    )
    $ip, $prefix = $CIDR -split '/'
    $ipBytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
    $prefix = [int]$prefix
    $totalIPs = [math]::Pow(2, 32 - $prefix)
    $startIP = [BitConverter]::ToUInt32($ipBytes, 0)

    for ($i = 0; $i -lt $totalIPs; $i++) {
        [System.Net.IPAddress]::new($startIP + $i).ToString()
    }
}

# Iterate through all private IP ranges
foreach ($range in $privateIPRanges) {
    $ips = Get-IPsFromCIDR -CIDR $range
    foreach ($ip in $ips) {
        $port = 80
        try {
            $connection = Test-NetConnection -ComputerName $ip -TcpPort $port -WarningAction SilentlyContinue -InformationLevel Quiet
            if ($connection.TcpTestSucceeded) {
                Write-Output "Successful Connection: IP: $ip, Port: $port"
            }
        } catch {
            # Handle any exceptions silently
        }
    }
}
