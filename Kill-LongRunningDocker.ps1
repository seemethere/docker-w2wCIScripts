# This is a temporary TP5 workaround for CI. 
$ErrorActionPreference='continue'
Write-Host "Kill-LongDocker started..."
while (1) {
	$p=get-process -name docker -ErrorAction SilentlyContinue
	if ($p -ne $null) {
		if ((new-timespan -start $p.StartTime $(get-date)).Minutes -ge 5) {
			Write-Host "Killing" $p.id "at" $(Get-Date)
			Stop-Process $p -force -ErrorAction SilentlyContinue
		}
	}
	sleep 5
}