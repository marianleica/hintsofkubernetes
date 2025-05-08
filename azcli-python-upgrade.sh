# test 1: install python 3.9

python3.9 -m pip install
# pip install cryptography
pip install cryptography ==43.0.*

python
import cryptography
# Print the version of the cryptography package
print(cryptography.__version__)
