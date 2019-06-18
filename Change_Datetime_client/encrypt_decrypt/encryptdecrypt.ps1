param(
    [parameter(mandatory)]
    [ValidateSet("Encrypt", "Decrypt")]
    $Mode
)

$CONF_PATH = "C:\scripts\Change_datetime\conf\Change_datetime.conf"


Import-Module init
$conf = Get-Content $CONF_PATH -Raw -ErrorAction Stop | ConvertFrom-StringData
if ($Mode -eq "Encrypt") {
    if (Test-Path $conf.Credential_Path) {
        Remove-Item $conf.Credential_Path
    }
    $file_path = removeExtension -file $conf.Credential_Path
    doEncrypt -key_path $conf.Keyfile_Path -file_path $file_path
}
elseif ($Mode -eq "Decrypt") {
    doDecrypt -key_path $conf.Keyfile_Path -file_path $conf.Credential_Path
}
