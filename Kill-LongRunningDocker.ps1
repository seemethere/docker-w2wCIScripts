# This is a temporary TP5 workaround for CI. Runs as a scheduled task
$ErrorActionPreference='continue'

echo "$(date) Kill-LongRunningDocker.ps1 starting..." >> $env:SystemDrive\scripts\Kill-LongRunningDocker.txt
while (1) {
	$p=get-process -name docker -ErrorAction SilentlyContinue
	if ($p -ne $null) {
		if ((new-timespan -start $p.StartTime $(get-date)).Minutes -ge 5) {
			echo "$(date) Killing $p.id" >> $env:SystemDrive\scripts\Kill-LongRunningDocker.txt
			Stop-Process $p -force -ErrorAction SilentlyContinue
		}
	}
	sleep 30
}