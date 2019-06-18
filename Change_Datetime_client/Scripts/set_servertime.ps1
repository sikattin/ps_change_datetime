# ------------------------------------------------ #
# set_servertime.ps1
# 
# Change system datetime of remote computers.
# Args:
#     Param1 Target[System.String]: Target host group of setting system date of the server.
#     Param2 Mode[System.String]: The mode of setting system date.
#         available values is "Set" or "Return"
#         The mode of "Set" means that it changes the system date of the specified server.
#         The mode of "Return" means that it returns the system date to current date.
#     Param3 Year[System.Int32]: Year of the system date to set it/
#         Defaults: current year.
#     Param4 Month[System.Int32]: Month of the system date to set it. 
#     Param5 Day[System.Int32]: Day of the system date to set it.
#     Param6 Hour[System.Int32]: Hour of the system date to set it.
#     Param7 Minute[System.Int32]: Minute of the system date to set it.
#  
# ------------------------------------------------ #
param(
    [parameter(mandatory)]
    [string]
    $Target,
    [ValidateSet("Set", "Return")]
    [parameter(mandatory)]
    [string]
    $Mode,
    [int32]
    $Year=(Get-Date).Year,
    [int32]
    $Month=(Get-Date).Month,
    [int32]
    $Day=(Get-Date).Day,
    [int32]
    $Hour=(Get-Date).Hour,
    [int32]
    $Minute=(Get-Date).Minute
)
# 時刻変更にかかわるスクリプト類を設置するルートディレクトリ
Set-Variable -Name ROOTDIR_DATETIME -Value "C:\scripts\Change_datetime" -Option constant
# Log output path
Set-Variable -Name LOG_PATH -Value "C:\scripts\log\" -Option constant
# Log file name
Set-Variable -Name LOG_FILENAME -Value "Change_datetime.log"
# config file path
Set-Variable -Name CONFIG_PATH -Value "conf\Change_datetime.conf" -Option constant
# Powershell binary path
Set-Variable -Name PSPATH -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Option constant
# Task scheduler Action -> <add arguments> section
Set-Variable -Name SCRIPTARGS_BASE -Value "-Command `"C:\scripts\Change_datetime\change_datetime.ps1" -Option constant
# Task scheduler Action -> <add arguments> section for script of time synchronization sets ON.
Set-Variable -Name SCRIPTARGS_SYNCON -Value "-Command `"C:\scripts\Change_datetime\sync_on.ps1" -Option constant
Set-Variable -Name ADDWORK_PATH -Value "C:\scripts\Change_datetime\add_work.ps1"
# Task scheduler Action -> [Start in] section
Set-Variable -Name WORKING_DIR -Value "C:\scripts\Change_datetime" -Option constant
# 時刻変更を行うタスクの名前
Set-Variable -Name TASKNAME -Value "ChangeDateTime" -Option constant
# Max retry count of starting scheduled task.
Set-Variable -Name MAX_RETRYCOUNT -Value 50 -Option constant

function init {
    # Debugメッセージを表示するようにする
    $DebugPreference = "Continue"
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.PowerShell.ScheduledJob.ScheduledJobOptions")
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.PowerShell.ScheduledJob.ScheduledJobTrigger")
}
function startScriptAsAdmin
{
# ----------------------------
# 指定のスクリプトをアドミン権限で実行する
# ----------------------------
    param(
        [string]
        $script_path,
        [object[]]
        $argument_list
    )
    $arguments = @()
    $arguments += $script_path
    if($null -ne $argument_list) {
        $arguments += $argument_list
    }
    Start-Process powershell.exe -ArgumentList $arguments -Verb runas
}

function createPSCredential {
    param(
        $User,
        $Password
    )
    $secure_pass = ConvertTo-SecureString $Password -AsPlainText -Force
    Write-Debug "ConvertTo-SecureStringcommandResult: $?"
    New-Object System.Management.Automation.PSCredential $User,$secure_pass -ErrorAction Stop
}
function createNewScheduledTaskAction
{
# ----------------------------------------------------------#
# タスク実行時のアクションを定義するAction引数用のオブジェクトを生成する
# Param1 execute: タスク実行時に実行されるプログラムパス
# Param2 arguments: タスク実行時に実行されるプログラムの引数
# Param3 working_dir: タスク実行時に実行されるプログラムの実行ディレクトリ
# ----------------------------------------------------------#
    param(
    [string]
    $execute,
    [string]
    $arguments,
    [string]
    $working_dir
    )
    New-ScheduledTaskAction -Execute $execute -Argument $arguments -WorkingDirectory $working_dir -ErrorAction Stop
    Write-Debug "ExitCode: $?"
}

function createNewCimSession {
# -------- #
# リモートコンピューターとのセッションオブジェクトを作成します。
# 
# Param1 name: 生成されるセッションオブジェクトの名前
# Param2 computer_name: リモートコンピューターのホスト名/IPアドレス
# Param3 user: リモートコンピューターの認証に使用するユーザー
# Param4 password: 認証に使用するユーザーのパスワード
# -------- #
    param(
        [string]
        $name,
        [string]
        $computer_name,
        [string]
        $user,
        [string]
        $password
    )
    $cred = createPSCredential -User $user -Password $password
    Write-Debug "createCredentiallcommandResult: $?"
    New-CimSession -Name $name -ComputerName $computer_name -Credential $cred -ErrorAction Stop
    Write-Debug "New-CimsessioncommandResult: $?"
}
function registerTask {
# ----------------------------------------------------------#
# タスクスケジューラにタスクを登録する
#
# Param1 task_name[string]: 登録するタスクの名前
# Param2 action[CimInstance#MSFT_TaskAction[]]: タスク実行時のアクション
#     New-ScheduledTaskAction コマンドレットを実行した結果返されるオブジェクトをこの引数のパラメーターとすること
# Param3 task_path[string]: 登録するタスクのパス
# Param4 trigger[CimInstance#MSFT_TaskTrigger[]]: タスクが実行されるトリガー
#     New-ScheduledTaskTrigger コマンドレット実行結果のオブジェクトをこの引数のパラメータとすること
# Param5 settings[CimInstance#MSFT_TaskSettings]: タスクを実行するユーザー
#     New-ScheduledTaskSettingsSet コマンドレット実行結果のオブジェクトをこの引数のパラメータとすること
# Param6 user[string]: タスクを実行するユーザ
# Param7 pw[string]: タスクを実行するユーザのパスワード
# Param8 runlevel: タスクを実行する権限のレベル valid values... Limited | Highest
# Param9 description[string]: タスクの説明
# Param10 forced[boolean]: 確認なしでコマンドレットを実行する
# Param11 cim_session[CimSession[]]: コマンドレットをリモート上で実行する.
#     コンピューター名　または　New-CimSession コマンドレットの出力をこの引数のパラメータとすること
# Param12 as_job[boolean]: タスク登録処理をバックグラウンドジョブとして処理する.
# Param13 principal[CimInstance]: Security Options.
# Param14 input_object: object that result of New-ScheduledTask 
# ----------------------------------------------------------#
    param(
        [parameter(mandatory)]
        [string]
        $task_name,
        $action,
        $task_path,
        $trigger,
        $settings,
        $user,
        $pw,
        $runlevel,
        $description,
        [switch]
        $forced,
        [switch]
        $as_job,
        $cim_session,
        $principal,
        $input_object
    )

    $command_args = @{
        TaskName = $task_name;
    }
    Write-Debug $cim_session
    if($null -ne $action) { $command_args += @{Action = $action;} }
    if($null -ne $task_path) { $command_args += @{TaskPath = $task_path;} }
    if($null -ne $trigger) { $command_args += @{Trigger = $trigger;} }
    if($null -ne $settings) { $command_args += @{Settings = $settings;} }
    if($user -ne $null) { $command_args += @{User = $user;} }
    if($pw -ne $null) { $command_args += @{Password = $pw;} }
    if($null -ne $runlevel) { $command_args += @{RunLevel = $runlevel;} }
    if($description -ne $null) { $command_args += @{Description = $description;} }
    if($forced) {
        $command_args += @{Force = $true;}
    } else {
        $command_args += @{Force = $false;}
    }
    if ($as_job) {
        $command_args += @{ AsJob = $true; }
    } else {
        $command_args += @{ AsJob = $false; }
    }
    if($null -ne $cim_session) { $command_args += @{CimSession = $cim_session;} }
    if($null -ne $principal) { $command_args += @{Principal = $principal;} }
    if($null -ne $input_object) { $command_args += @{InputObject = $input_object;} }

    Write-Debug $command_args
    Register-ScheduledTask @command_args -ErrorAction Stop
}

function unregisterTask {
# -------------------------- #
# タスクを削除する

# Param1 task_name[string]: 削除するタスクの名前
# Param2 task_path[string]: 削除するタスクのパス
# Param3 cim_session[CimSession[]]: リモートコンピューターとのセッションオブジェクト.
#     リモートコンピューター上でタスクを削除する
# Param4 confirm[boolean]: タスクを削除する前にプロンプト上に確認ダイアログを表示させる
# Param5 as_job[boolean]: タスクをバックグラウンドジョブとして実行する
# -------------------------- #
    param(
        [parameter(mandatory)]
        [string]
        $task_name,
        $task_path,
        $cim_session,
        [switch]
        $confirm,
        [switch]
        $as_job
    )
    
    $command_args = @{
        TaskName = $task_name;
    }

    if ($task_path -ne $null) { $command_args += @{ TaskPath = $task_path } }
    if ($cim_session -ne $null) { $command_args += @{ CimSession = $cim_session } }
    if ($confirm) {
        $command_args += @{ Confirm = $true }
    } else {
        $command_args += @{ Confirm = $false}
    }
    if ($as_job) {
        $command_args += @{ AsJob = $true }
    } else {
        $command_args += @{ AsJob = $false }
    }

    Unregister-ScheduledTask @command_args -ErrorAction Stop
}

function removeDecryptFile{
    # 拡張子を除去
    $decrypt_filepath = removeExtension -file $conf.Credential_Path
    $result = Test-Path $decrypt_filepath
    # ファイルの存在確認
    if ($result -eq $true) {
        Remove-Item $decrypt_filepath -ErrorAction Continue
    }
}

function removeExtension {
# -------------- #
# 拡張子を除外したファイル名、パスを返す
# 
# Param1 file: ファイル名かフルパスで
# -------------- #
    param(
        [string]
        $file
    )
    $start_idx = $file.LastIndexOf(".")
    $rm_charsnum = $file.Length - $start_idx
    $noext_file = $file.Remove($start_idx, $rm_charsnum)
    Write-Output $noext_file
}

function decryptCredential {
    <#
    # extract Now login user name.
    $current = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $login_user = $current.Name
    $login_user = $login_user.Split("\")[1]
    # create full path of key file.
    $keyfile_name = $login_user + "_$KEYFILE_TAIL"
    #>
    $keyfile_path = $conf.Keyfile_Path
    # create full path of encrypted credential file.
    $encryptfile_path = $conf.Credential_Path
    # do decrypt.
    doDecrypt -key_path $keyfile_path -file_path $encryptfile_path | Out-Null
}

$ErrorActionPreference = "Stop"
# $command = {Register-ScheduledTask -TaskPath $args[0] -TaskName $args[1] -User $args[2] -RunLevel $args[3] -Action $args[4]}
# Invoke-Command -ComputerName $hostname -ScriptBlock $command -ArgumentList $taskpath,$taskname,$taskuser,$runlevel,$action -Credential $cred
Import-Module init
# Setup Logger
$script:logger = Get-Logger -Logfile (Join-Path $LOG_PATH $LOG_FILENAME) -NoDisplay
# ログディレクトリがない場合は新規に作成する
if (!(Test-Path $LOG_PATH)) {
    New-Item -ItemType Directory $LOG_PATH 
}
# 設定ファイルの読み込み
$conf_path = Join-Path $ROOTDIR_DATETIME $CONFIG_PATH
$conf = Get-Content $conf_path -Raw -ErrorAction Stop | ConvertFrom-StringData
# 認証ユーザー定義ファイルの複合化
try {
    decryptCredential
}
catch {
    $logger.error("Failed to decrypt encrypted credential file. please check encrpted file path and key file path.")
    throw
}
# 複合化した認証ユーザー定義ファイルの読み込み
$decrypt_filepath = removeExtension -file $conf.Credential_Path
try {
    $conf_account = Get-Content $decrypt_filepath -Raw -ErrorAction Stop | ConvertFrom-StringData
}
catch {
    $logger.error("Can not open the account file. $decrypt_filepath")
    throw
}
Write-Debug $conf_account.Password
# 接続先ホスト名一覧ファイルをロードする
$hostlist_path = $conf.ServerList_Path
$host_list = Get-Content $hostlist_path -Raw | ConvertFrom-Json
# アクションの定義
switch ($Mode) {
    "Set" {
        $script_args = $SCRIPTARGS_BASE + " -mode $Mode -year $Year -month $Month -day $Day -hour $Hour -minute $Minute`""
        try {
            $action = createNewScheduledTaskAction -execute $PSPATH -arguments $script_args -working_dir $WORKING_DIR
        }
        catch {
            $logger.error.Invoke("Can not the taskaction object the cause of following.")
            $logger.error.Invoke("$($Error[0]).Exception")
        }
    }
    "Return" {
        $script_args = $SCRIPTARGS_BASE + " -mode $Mode`""
        try {
            $action = createNewScheduledTaskAction -execute $PSPATH -arguments $script_args -working_dir $WORKING_DIR
        }
        catch {
            $logger.error.Invoke("Can not the taskaction object the cause of following.")
            $logger.error.Invoke("$($Error[0]).Exception")
        }
    }
}

# defines principal.
try {
    $principal = New-ScheduledTaskPrincipal -UserId $conf_account.User -LogonType Password -RunLevel Highest
}
catch {
    $logger.error.Invoke("Can not create the principal object the cause of following.")
    $logger.error.Invoke("$($Error[0]).Exception")
}

# creates Task.
try {
    $task = New-ScheduledTask -Action $action -Principal $principal -ErrorAction Stop
}
catch {
    $logger.error.Invoke("Can not create the task object the cause of following.")
    $logger.error.Invoke("$($Error[0]).Exception")
    throw
}
$task_name = "$(Get-Date -Format `"yyyyMMddHHmm`")_Change_datetime"
# for Return CustomObject
$ret_obj = @()
$msg = ''
foreach ($conn_host in $host_list.$($Target)) {
    # create Custom Object every host.
    $custom_obj = New-Object PSCustomObject
    # リモート接続用にリモートコンピューターとのセッションを作成する
    try {
        $session = createNewCimSession -name $conn_host+"_session" `
                                       -computer_name $conn_host `
                                       -user $conf_account.User `
                                       -password $conf_account.Password
    }
    catch {
        # logging
        $logger.error.Invoke("Can not create a remote sesssion to $($conn_host) the cause of following.")
        $logger.error.Invoke("$($Error[0]).Exception")
        throw
    }
    Write-Debug $session.GetType()
    # リモートコンピューターに時刻変更用タスクを生成する
    try {
        $reg_task = registerTask -task_name $task_name `
                                 -input_object $task `
                                 -user $conf_account.User `
                                 -pw $conf_account.Password `
                                 -cim_session $session `
                                 -forced
    }
    catch {
        $logger.error.Invoke("Can not register the task the cause of following.")
        $logger.error.Invoke("$($Error[0]).Exception")
        throw
    }
    # Execute the task created.
    try {
        $job_result = Get-ScheduledTask -CimSession $session -TaskName $task_name | Start-ScheduledTask -AsJob
    }
    catch {
        $logger.error.Invoke("Can not start the task the cause of following.")
        $logger.error.Invoke("$($Error[0]).Exception")
        throw
    }
    # Check the state of be executed the task.
    while ($true) {
        $counter = 0
        $job_state = (Get-Job -Id $job_result.Id).State
        if ($job_state -eq "Completed") {
            break
        }
        elseif ($counter -eq $MAX_RETRYCOUNT) {
            break
        }
        $counter += 1
        Start-Sleep -m 100
    }
    # logging
    if ($job_state -eq "Completed") {
        $msg = "[Mode=$($Mode)]Succeeded to change datetime on $conn_host"
        $logger.info.Invoke($msg)
    }
    elseif ($job_state -eq "Running"){
        $msg = "[Mode=$($Mode)]The task change datetime is Running. unfinished. on $conn_host"
        $logger.info.Invoke($msg)
    }
    else {
        $msg = "[Mode=$($Mode)]Failed to change datetime on $conn_host"
        $logger.error.Invoke($msg)
    }
    # タスクを削除する
    try {
        unregisterTask -task_name $task_name `
                       -cim_session $session ` | Out-Null
    }
    catch {
        $logger.error.Invoke("Can not unregister the task the cause of following.")
        $logger.error.Invoke("$($Error[0]).Exception")
        # not throw.
    }
<#
    # Addwork on remote computer.
    if ($Addwork) {
        $cmd= { C:\scripts\Change_datetime\add_work.ps1 -Mode $args[0] }
        $cred = createPSCredential -User $conf_account.User -Password $conf_account.Password
        Invoke-Command -ComputerName $conn_host -ScriptBlock $cmd -ArgumentList $Mode
    }
#>
    # Remove session.
    Remove-CimSession -CimSession $session -ErrorAction Ignore | Out-Null
    # CustomObject
    # Propertys: State, Hostname, Message
    $custom_obj | Add-Member -NotePropertyMembers @{
        State = $job_state
        Hostname = $conn_host
        Message = $msg
        Mode = $Mode
    }
    $ret_obj += ($custom_obj | Select-Object State, Hostname, Message, Mode)
}
removeDecryptFile | Out-Null
# Return Object contained result of executing task.
$ret_obj
