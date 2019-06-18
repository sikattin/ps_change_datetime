# ------------------------------------ #
# Disable time synchronization script.
# ------------------------------------ #
Set-Variable -Name REGPATH -Value 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters'

try {
    Set-ItemProperty -Path $REGPATH -Name Type -Value NoSync -ErrorAction Stop
    # Windows Time Restart
    Restart-Service W32Time -ErrorAction Stop
    # Check TimeSync Registory
    $regResult=(Get-ItemProperty $REGPATH).Type

    if ($regResult -eq "NoSync") { Write-Output $true }
    else { Write-Output $false }
}
catch {
    throw
}
