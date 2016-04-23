@echo off

rem This is a variant of runDockerDaemon.cmd in programdata\docker installed by Install-ContainerHost.ps1
rem It has some key differences for use in Windows CI for TP5+
rem - Daemon is NOT debug
rem - Daemon is renamed to dockernssm.exe to spot easily in task manager
rem - Daemon is redirected to d:\daemon, D: being a fast SSD on CI machines
rem - TEMP and TMP are redirected to d:\temp (SSD drive)

set TEMP=d:\temp
set TMP=d:\temp
mkdir d:\temp > nul 2>&1

if exist d:\daemon (goto :run)
mkdir d:\daemon

:run
copy %systemroot%\system32\dockerd.exe %systemroot%\system32\dockerdnssm.exe /Y
dockerdnssm --graph=d:\daemon --pidfile=d:\daemon\daemon.pid
