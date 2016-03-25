@echo off

rem This is a varient of runDockerDaemon.cmd in programdata\docker installed by Install-ContainerHost.ps1
rem It has some key differences for use in WIndows CI.
rem - Daemon is NOT debug
rem - Daemon is renamed to dockernssm.exe to spot easily in task manager
rem - Daemon is redirected to d:\daemon, D: being a fast SSD on CI machines
rem - TEMP and TMP are redirected to d:\temp (SSD drive)


set certs=%ProgramData%\docker\certs.d

rem if exist %ProgramData%\docker (goto :run)
rem mkdir %ProgramData%\docker

set TEMP=d:\temp
set TMP=d:\temp
mkdir d:\temp > nul 2>&1

if exist d:\daemon (goto :run)
mkdir d:\daemon

:run
rem if exist %certs%\server-cert.pem (if exist %ProgramData%\docker\tag.txt (goto :secure))
rem docker daemon -D
 
copy %systemroot%\system32\docker.exe %systemroot%\system32\dockernssm.exe /Y
dockernssm daemon --graph=d:\daemon --pidfile=d:\daemon\daemon.pid
goto :eof

rem :secure
REM This isn't used for CI machines.
rem docker daemon -D -H 0.0.0.0:2376 --tlsverify --tlscacert=%certs%\ca.pem --tlscert=%certs%\server-cert.pem --tlskey=%certs%\server-key.pem