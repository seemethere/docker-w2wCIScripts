#-----------------------
# SetupSSH.ps1
#-----------------------

Write-Host "INFO: Executing SetupSSH.ps1"

# Open the firewall
Start-Process -wait netsh -ArgumentList "advfirewall firewall add rule name=SSH dir=in action=allow protocol=TCP localport=22"
c:\cygwin\bin\bash -c 'export PATH=/usr/sbin:/usr/bin:$PATH;\
pass=$(< /cygdrive/c/scripts/SSHpassword.txt);\
/usr/bin/ssh-host-config -y -w $pass -c \"binmode ntsec\";\
echo \"PasswordAuthentication no\" >> /etc/sshd_config;\
mkdir -p ~/.ssh;\
chmod 700 ~/.ssh;\
cp /cygdrive/c/packer/authorized_keys ~/.ssh/authorized_keys;\
chmod 644 ~/.ssh/authorized_keys;\
/usr/bin/cygrunsrv -S sshd' 2>&1 | out-null

echo "SetupSSH.ps1 ran" > $env:SystemDrive\scripts\setupSSH.txt

# Delete the scheduled task
$ConfirmPreference=='none'
Get-ScheduledTask 'SetupSSH' | Unregister-ScheduledTask

Write-Host "INFO: SetupSSH.ps1 completed"

