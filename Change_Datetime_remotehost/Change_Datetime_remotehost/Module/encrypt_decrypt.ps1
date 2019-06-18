#------------------------------
# this scripts is the module related Encrypt/Decrypt.
#------------------------------
Set-Variable -Name ROOTDIR_ENCDEC -Value "C:\scripts\encrypt_decrypt" -Option constant
Set-Variable -Name SCRIPTFILE -Value "PSCrypto.ps1" -Option constant
Set-Variable -Name MAKEKEY_ARGS -Value " -Mode CreateKey" -option constant
Set-Variable -Name SCRIPT_MAKEKEY -Value "Make256Key.ps1" -Option constant

Set-Variable -Name SCRIPT_ENCDEC -Value "AES256.ps1"

function makePublicKey {
    $exec_path = Join-Path $ROOTDIR_ENCDEC $SCRIPTFILE
    $exec_cmd = $exec_path + $MAKEKEY_ARGS 
    $result = Invoke-Expression $exec_cmd

    $key_info = $result.Split(" ")

    $exec_path = Join-Path $ROOTDIR_ENCDEC $SCRIPT_MAKEKEY
    $exec_cmd = $exec_path + " -Path $key_info[2]" 
    Invoke-Expression $exec_cmd

    Write-Output $key_info[2]
}

function make256Key {
    param(
    [string]
    $key_path)

    $exec_path = Join-Path $ROOTDIR_ENCDEC $SCRIPT_MAKEKEY
    $exec_cmd = $exec_path + " -Path $key_path" 
    Invoke-Expression $exec_cmd
    Write-Output $?
}

function doEncrypt {
    param(
    [string]
    $key_path,
    [string]
    $file_path
    )

    $exec_path = Join-Path $ROOTDIR_ENCDEC $SCRIPT_ENCDEC
    $exec_cmd = $exec_path + " -Encrypto -KeyPath $key_path -Path $file_path"
    Invoke-Expression $exec_cmd
}

function doDecrypt {
    param(
    [string]
    $key_path,
    [string]
    $file_path
    )

    $exec_path = Join-Path $ROOTDIR_ENCDEC $SCRIPT_ENCDEC
    $exec_cmd = $exec_path + " -Decrypto -KeyPath $key_path -Path $file_path"
    Invoke-Expression $exec_cmd
}
