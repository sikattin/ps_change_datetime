$MODULES_PATH = 'C:\Program Files\WindowsPowerShell\Modules\modules'

Get-ChildItem $MODULES_PATH -Include "*.ps1" -Recurse | ? { . $_.PSPath }
Export-ModuleMember -Function *
