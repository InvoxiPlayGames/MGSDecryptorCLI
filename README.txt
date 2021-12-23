MGSDecryptorCLI
---------------
A command-line decryptor for MacGameStore games protected by their 2007-era DRMWrapper.

This has only been tested on a PowerPC Mac, however in theory it should work on Intel Macs that support 32-bit software.

Usage: ./MGSDecryptorCLI /path/to/encrypted/app "License Name" "License Key" /path/to/output/folder

For example, to decrypt "Peggle Deluxe":
./MGSDecryptorCLI /Applications/Peggle\ Deluxe/Peggle.app "Emma" "XXXXXXXXXXXXXXXX" /Users/emma/Documents/
This command will decrypt the app and place the decrypted app at /Users/emma/Documents/

This has been tested on:
- Bejeweled 2 Deluxe (2006)
- Peggle Deluxe (2007)
- Monopoly Classic (2007)
