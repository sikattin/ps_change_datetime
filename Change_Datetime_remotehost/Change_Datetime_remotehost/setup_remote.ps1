$ErrorActionPreference = "Stop"

$LOG_PATH = "C:\scripts\log"
$MODULE_DIRNAME = "Module"
$SCRIPTS_DIRNAME = "Scripts"

$DIST_MODULE_PATH = "C:\Program Files\WindowsPowerShell\Modules\modules"
$DIST_INIT_MODULE_PATH = "C:\Program Files\WindowsPowerShell\Modules\init"
$DIST_SCRIPTS_PATH = "C:\scripts\Change_datetime"

# -----------------------------------------------#
Write-Host -BackgroundColor Cyan -ForegroundColor Black `
           "Start setup of change datetime on client host."
Write-Host -BackgroundColor Cyan -ForegroundColor Black `
           "`r`nStep1: *** Create Directories Section ***`r`n"
# create directories
New-Item -Path $DIST_SCRIPTS_PATH -ErrorAction Stop -ItemType "Directory" -Force -Verbose | Out-Null
New-Item -Path $LOG_PATH -ErrorAction Stop -ItemType "Directory" -Force -Verbose | Out-Null
New-Item -Path $DIST_MODULE_PATH -ErrorAction Stop -ItemType "Directory" -Force -Verbose | Out-Null
New-Item -Path $DIST_INIT_MODULE_PATH -ErrorAction Stop -ItemType "Directory" -Force -Verbose | Out-Null
# -----------------------------------------------#

## puts scripts.
# -----------------------------------------------#
Write-Host -BackgroundColor Cyan -ForegroundColor Black `
           "`r`nStep2: *** Copy files ***`r`n"
# get working directory.
$this_path = $MyInvocation.MyCommand.Path
$work_dir = Split-Path -Parent $this_path
# copy scripts, modules and config file.
$source_path = Join-Path  $work_dir $SCRIPTS_DIRNAME
Copy-Item -Path (Join-Path $source_path "*.ps1") -Destination $DIST_SCRIPTS_PATH -ErrorAction Stop -Verbose

$source_path = Join-Path $work_dir $MODULE_DIRNAME
Copy-Item -Path (Join-Path $source_path "*.ps1") -Destination $DIST_MODULE_PATH -Verbose
Copy-Item -Path (Join-Path $source_path "init.psm1") -Destination $DIST_INIT_MODULE_PATH -Verbose
# -----------------------------------------------#

## allow to execute remote command.
# -----------------------------------------------#
Write-Host -BackgroundColor Cyan -ForegroundColor Black `
           "`r`nStep3: *** Enable PowerShell Remoting ***`r`n"
Enable-PSRemoting -Force
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/client '@{AllowUnencrypted="true"}'
# -----------------------------------------------#

Write-Host -BackgroundColor Cyan -ForegroundColor Black "`r`nComplete setup processes."
