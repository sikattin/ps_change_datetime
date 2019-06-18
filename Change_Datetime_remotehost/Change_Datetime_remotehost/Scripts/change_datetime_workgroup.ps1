# --------------------------------------------- #
# Set/Return DateTime script.
#
# Args:
#     param1 [int32]year: The year you want to set/return.
#     param2 [int32]month: The month you want to set/return.
#     param3 [int32]day: The day you want to set/return.
#     param4 [int32]hour: The hour your want to set/return.
#     param5 [int32]minute: The minute you want to set/return.
#     param6 [string]mode: Change datetime mode. valid parameter is Set/Return.
# Return:
      
# --------------------------------------------- #
param(
    [ValidateSet("Set", "Return")]
    [parameter(mandatory)]
    $mode,
    [int32]$year,
    [int32]$month,
    [int32]$day,
    [int32]$hour,
    [int32]$minute
)

Set-Variable -Name LOG_OUTPATH -Value "C:\scripts\log\ChangeDateTime.log"
$ErrorActionPreference = "Stop"

function setDateTime {
    $set_date = Set-Date -Date (Get-Date -Year $year -Month $month -Day $day -Hour $hour -Minute $minute)
    $set_date
}

function setDate {
    # Get-Date custom format.
    $script:date = Get-Date -Year $year `
                            -Month $month `
                            -Day $day `
                            -Hour $hour `
                            -Minute $minute `
                            -Format "yyyy/MM/dd HH:mm" `
                            -ErrorAction Stop
    # DateTime Synchronization to DomainController sets "NoSync"
    try {
        $result = Invoke-Expression (Join-Path $working_dir sync_off.ps1)
    }
    catch {
        $logger.error.Invoke("Failed to do unsynchronized setting to DomainController")
        throw
    }
    if ($result) {
            $logger.info.Invoke("DateTime Synchronization type sets NoSync.")
    }
    # Change DateTime
    $logger.info.Invoke("DateTime attempt to change to $date")
    try {
        $result_setdate = setDateTime
    }
    catch {
        $logger.error.Invoke("Failed to change datetime.")
        throw
    }
    $logger.info.Invoke("Change DateTime to $date")
    $result_setdate
}


function ReturnDate {
    # Get-Date custom format.
    $script:date = Get-Date -Year $year `
                            -Month $month `
                            -Day $day `
                            -Hour $hour `
                            -Minute $minute `
                            -Format "yyyy/MM/dd HH:mm" `
                            -ErrorAction Stop
    # Change DateTime
    $logger.info.Invoke("DateTime attempt to change to $date")
    try {
        $result_setdate = setDateTime
    }
    catch {
        $logger.error.Invoke("Failed to change datetime.")
        throw
    }
    $logger.info.Invoke("Change DateTime to $date")
    # DateTime Synchronization to NTPServer sets "NTP"
    try {
        $result = Invoke-Expression (Join-Path $working_dir sync_on_workgroup.ps1)
    }
    catch {
        $logger.error.Invoke("Failed to rewrite registry key.")
        throw
    }
    if ($result) {
            $logger.info.Invoke("DateTime Synchronization type sets NTP.")
    }
    $result
}

# Load modules
Import-Module init
# Setup Logger
$script:logger = Get-Logger -Logfile $LOG_OUTPATH -NoDisplay
# ログディレクトリがない場合は新規に作成する
if (!(Test-Path  (Split-Path -Parent $LOG_OUTPATH))) {
    New-Item -ItemType Directory (Split-Path -Parent $LOG_OUTPATH) 
}
# Get Working Directory
$script_path = $MyInvocation.MyCommand.Path
$script:working_dir = Split-Path -Parent $script_path
if ($mode -eq "Set") {
    try {
        $ret = setDate
    }
    catch {
        $logger.error.Invoke("$_.Exception")
        throw
    }
    # Return Datetime object.
    $ret
}
elseif ($mode -eq "Return") {
    try {
        $ret = ReturnDate
    }
    catch {
        $logger.error.Invoke("$_.Exception")
        throw
    }
    # Return True/False
    $ret
}
else {
    $exception = New-Object System.FormatException
    $logger.error.Invoke("$exception.Message")
    throw $exception
}
