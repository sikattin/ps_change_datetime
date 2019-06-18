# ------------------------------------------------ #
# get_servernow.ps1
# 
# Get system datetime of remote computers.
# ------------------------------------------------ #
param(
    [parameter(mandatory)]
    $Target
)
# スクリプト類を設置するルートディレクトリ
Set-Variable -Name ROOTDIR -Value "C:\scripts\Change_datetime" -Option constant
# config file path
Set-Variable -Name CONFIG_PATH -Value "conf\Change_datetime.conf" -Option Constant
# Log
Set-Variable -Name LOG_PATH -Value "C:\scripts\log" -Option Constant
Set-Variable -Name LOG_FILENAME -Value "Change_datetime.log"


function decryptCredential {
    param(
        $key_path,
        $cred_path
    )
    # do decrypt.
    doDecrypt -key_path $key_path -file_path $cred_path | Out-Null
}

function removeDecryptFile{
    # 拡張子を除去
    $decrypt_filepath = removeExtension -file $cred_path
    $result = Test-Path $decrypt_filepath
    # ファイルの存在確認
    if ($result -eq $true) {
        Remove-Item $decrypt_filepath
    }
}
# load module.
Import-Module init
# Setup Logger
while ($true) {
    try {
        $script:logger = Get-Logger -Logfile (Join-Path $LOG_PATH $LOG_FILENAME) -NoDisplay
    }
    catch {
        Import-Module init
        continue
    }
    break
}
# サーバーリストをロードする
try {
    $conf_path = Join-Path $ROOTDIR $CONFIG_PATH
    $conf = Get-Content $conf_path -Raw -ErrorAction Stop | ConvertFrom-StringData
    $conf_server = Get-Content $conf.ServerList_Path -Raw -ErrorAction Stop | ConvertFrom-Json
    # loads a config file.
}
catch {
    $logger.error.Invoke("Failed to loads a server config file. error detail is following.")
    $logger.error.Invoke("$_.Exception")
}
### Decrypt a file defined credential.
try {
    $key_path = $conf.Keyfile_Path
    $cred_path = $conf.Credential_Path
    decryptCredential -key_path $key_path -cred_path $cred_path | Out-Null
}
catch {
    $logger.error.Invoke("Failed to decrypt encrypted file. error detail is following.")
    $logger.error.Invoke($_.Exception)
}
Start-Sleep -m 800
# リモート接続に使用するアカウント情報をロードする
try {
    $decrypt_filepath = removeExtension -file $cred_path
    $conf_account = Get-Content $decrypt_filepath -Raw | ConvertFrom-StringData
}
catch {
    $logger.error.Invoke("Failed to loads a config file. error detail is following.")
    $logger.error.Invoke("$_.Exception")
}

# リモート接続のための準備
$result = @()
$user = $conf_account.User
$password = ConvertTo-SecureString $conf_account.Password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential $conf_account.User,$password
Write-Debug "lastcommandResult: $?"
$command = {Get-Date}
# 返却用のオブジェクト
$ret_obj = @()
# 対象のホストへ接続して現在時刻を取得する
foreach($server in $conf_server.$($Target)) {
    $custom_object = New-Object PSCustomObject
    # 実行結果はDatetime型が返却される
    $ret = Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock $command
    Write-Debug "lastcommandResult: $?"
    # 結果を一旦リストに格納 ホスト名:yyyy/MM/dd HH:mm
    #$result += "${server}:${ret}"
    $custom_object | Add-Member -NotePropertyMembers @{
        Hostname = $server
        Datetime = $ret
    }
    $ret_obj += ($custom_object | Select-Object Hostname, Datetime)
}
# 標準出力にオブジェクトを出力 オブジェクトの型はリスト
$ret_obj
# remove decrypt file.
removeDecryptFile