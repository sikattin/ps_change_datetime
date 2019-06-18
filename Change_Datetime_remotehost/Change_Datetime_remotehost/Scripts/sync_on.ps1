# ------------------------------------ #
# Enable time synchronization script.
# ------------------------------------ #
Set-Variable -Name REGPATH -Value 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters'

try {
    Set-ItemProperty -Path $REGPATH -Name Type -Value NT5DS -ErrorAction Stop
    # Windows Time Restart
    Restart-Service W32Time -ErrorAction Stop
    # resync to DC
    # w32tm.exe /resync /nowait
    # Check TimeSync Registory
    $regResult=(Get-ItemProperty $REGPATH).Type
    Write-Debug "Result:$regResult"

    if ($regResult -eq "NT5DS") {
        Write-Output $true
    }
    else { Write-Output $false }
}
catch {
    throw
}
