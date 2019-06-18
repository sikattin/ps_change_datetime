$ErrorActionPreference = "Stop"

$MODULE_DIRNAME = "Module"
$SCRIPTS_DIRNAME = "Scripts"
$ENCDEC_DIRNAME = "encrypt_decrypt"
$CONF_DIRNAME = "conf"

$DIST_MODULE_PATH = "C:\Program Files\WindowsPowerShell\Modules\modules"
$DIST_INIT_MODULE_PATH = "C:\Program Files\WindowsPowerShell\Modules\init"
$DIST_SCRIPTS_PATH = "C:\scripts\Change_datetime"
$DIST_CONF_PATH = "C:\scripts\Change_datetime\conf"
$DIST_ENCDEC_PATH = "C:\scripts\encrypt_decrypt"

$ENCDEC_SCRIPTNAME = "encrypt_decrypt.ps1"
$KEYFILE_NAME = "commonkey"
$SERVERLIST_NAME = "server_list.json"
$CREDENTIAL_NAME = "credential"
$CONF_NAME = "Change_datetime.conf"

$KEY_KEYFILEPATH = "Keyfile_Path"
$KEY_SERVERLISTPATH = "ServerList_Path"
$KEY_CREDENTIALPATH = "Credential_Path"


function create_directories {
    New-Item -Path $DIST_SCRIPTS_PATH -ErrorAction Stop -ItemType "Directory" -Force -Verbose | Out-Null
    New-Item -Path $DIST_CONF_PATH -ErrorAction Stop -ItemType "Directory" -Force -Verbose | Out-Null
    New-Item -Path $DIST_ENCDEC_PATH -ErrorAction Stop -ItemType "Directory" -Force -Verbose | Out-Null
    New-Item -Path "C:\scripts\log" -ErrorAction Stop -ItemType "Directory" -Force -Verbose | Out-Null
    New-Item -Path $DIST_MODULE_PATH -ErrorAction Stop -ItemType "Directory" -Force -Verbose | Out-Null
    New-Item -Path $DIST_INIT_MODULE_PATH -ErrorAction Stop -ItemType "Directory" -Force -Verbose | Out-Null
}

function copy_files {
    param(
    $Path
    )
    $work_dir = Split-Path -Parent $Path
    # copy scripts, modules and config file.
    $source_path = Join-Path  $work_dir $SCRIPTS_DIRNAME
    Copy-Item -Path (Join-Path $source_path "*.ps1") -Destination $DIST_SCRIPTS_PATH -ErrorAction Stop -Verbose
    Copy-Item -Path (Join-Path $source_path $SERVERLIST_NAME) -Destination $DIST_SCRIPTS_PATH -ErrorAction Stop -Verbose

    $source_path = Join-Path $work_dir $MODULE_DIRNAME
    Copy-Item -Path (Join-Path $source_path "*.ps1") -Destination $DIST_MODULE_PATH -Verbose
    Copy-Item -Path (Join-Path $source_path "init.psm1") -Destination $DIST_INIT_MODULE_PATH -Verbose

    $source_path = Join-Path $work_dir $ENCDEC_DIRNAME
    Copy-Item -Path (Join-Path $source_path "*.ps1") -Destination $DIST_ENCDEC_PATH -Verbose

    $source_path = Join-Path $work_dir $CONF_DIRNAME
    Copy-Item -Path (Join-Path $source_path $CREDENTIAL_NAME) -Destination $DIST_CONF_PATH -Verbose
}

function create_key {
    # make key file
    Out-File $keyfile_path
    $result = make256Key -key_path $keyfile_path
    if($result) {
        Write-Output "Succeeded to create key file: $keyfile_path"
    }
}

function create_config {
    $conf_path = Join-Path $DIST_CONF_PATH $CONF_NAME
    ## remove it if it has already existed.
    if (Test-Path $conf_path) {
        Remove-Item $conf_path
    }
    $lines = @{}
    ## key file path
    $lines.Add($KEY_KEYFILEPATH, $keyfile_path.Replace("\", "\\"))
    ## server list path
    $lines.Add($KEY_SERVERLISTPATH, (Join-Path $DIST_SCRIPTS_PATH $SERVERLIST_NAME).Replace("\", "\\"))
    ## credential path
    $enc_credential = $CREDENTIAL_NAME + ".enc"
    $lines.Add($KEY_CREDENTIALPATH, (Join-Path $DIST_CONF_PATH $enc_credential).Replace("\", "\\"))
    ## write lines in config file
    $KEY_KEYFILEPATH + "=" + $lines[$KEY_KEYFILEPATH] | Out-File $conf_path -Append
    $KEY_SERVERLISTPATH + "=" + $lines[$KEY_SERVERLISTPATH] | Out-File $conf_path -Append
    $KEY_CREDENTIALPATH + "=" + $lines[$KEY_CREDENTIALPATH] | Out-File $conf_path -Append
    Write-Output "Succeeded to create config file: $conf_path"
}

# working directory
$script:this_path = $MyInvocation.MyCommand.Path
# key file path
$script:keyfile_path = Join-Path $DIST_SCRIPTS_PATH $KEYFILE_NAME

Write-Host -BackgroundColor Cyan -ForegroundColor Black `
           "Start setup of change datetime on client host."

# create directories
Write-Host -BackgroundColor Cyan -ForegroundColor Black `
           "`r`nStep1: *** Create Directories Section ***`r`n"
create_directories

# copy files
Write-Host -BackgroundColor Cyan -ForegroundColor Black `
           "`r`nStep2: *** Copy files ***`r`n"
copy_files -Path $this_path

# create key
Write-Host -BackgroundColor Cyan -ForegroundColor Black `
           "`r`nStep3: *** Create key ***`r`n"
. (Join-Path $DIST_ENCDEC_PATH $ENCDEC_SCRIPTNAME)
create_key

# encrypt credential file
Write-Host -BackgroundColor Cyan -ForegroundColor Black `
           "`r`nStep4: *** Encrypt credential file ***`r`n"
doEncrypt -key_path $keyfile_path -file_path (Join-Path $DIST_CONF_PATH $CREDENTIAL_NAME)

# create a config file.
Write-Host -BackgroundColor Cyan -ForegroundColor Black `
           "`r`nStep5: *** Create config file ***`r`n"
create_config

# remove credential file before encription.
Remove-Item (Join-Path $DIST_CONF_PATH $CREDENTIAL_NAME)

# enable winrm
Enable-PSRemoting -Force
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/client '@{AllowUnencrypted="true"}'

# trust hosts
Write-Host -BackgroundColor Cyan -ForegroundColor Black `
           "`r`nStep6: *** Get ready for PowerShell Remoting ***"
Set-Item WSMan:\localhost\Client\TrustedHosts -Value * -Force
Get-Item WSMan:\localhost\Client\TrustedHosts

Write-Host -BackgroundColor Cyan -ForegroundColor Black "`r`nComplete setup processes."
