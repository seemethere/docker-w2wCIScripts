#-----------------------
# SetupSSH.ps1
#-----------------------

Write-Host "INFO: Executing SetupSSH.ps1"

# Download and install Cygwin for SSH capability
# Note this is post-sysprep as sysprep clears the accounts.
Write-Host "INFO: Downloading Cygwin..."
mkdir $env:SystemDrive\cygwin -erroraction silentlycontinue 2>&1 | Out-Null
$wc=New-Object net.webclient;$wc.Downloadfile("https://cygwin.com/setup-x86_64.exe","$env:SystemDrive\cygwinsetup.exe")
Write-Host "INFO: Installing Cygwin..."
Start-Process $env:SystemDrive\cygwinsetup.exe -ArgumentList "-q -R $env:SystemDrive\cygwin --packages openssh openssl -l $env:SystemDrive\cygwin\packages -s http://mirrors.sonic.net/cygwin/ 2>&1 | Out-Null" -Wait


# Open the firewall
Start-Process -wait netsh -ArgumentList "advfirewall firewall add rule name=SSH dir=in action=allow protocol=TCP localport=22"
c:\cygwin\bin\bash -c 'export PATH=/usr/sbin:/usr/bin:$PATH;\
mkdir -p ~/.ssh;\
pass=$(< /cygdrive/c/scripts/SSHpassword.txt);\
echo $pass;\
/usr/bin/ssh-host-config -y -w $pass -c \"binmode ntsec\";\
echo \"PasswordAuthentication no\" >> /etc/sshd_config;\
chmod 700 ~/.ssh;\
cp /cygdrive/c/packer/authorized_keys ~/.ssh/authorized_keys;\
chmod 644 ~/.ssh/authorized_keys;\
/usr/bin/cygrunsrv -S sshd' 2>&1 | out-null

echo "SetupSSH.ps1 ran" > $env:SystemDrive\scripts\setupSSH.txt

# Delete the scheduled task
$ConfirmPreference=='none'
Get-ScheduledTask 'SetupSSH' | Unregister-ScheduledTask

Write-Host "INFO: SetupSSH.ps1 completed"

