#-----------------------
# SetupSSH.ps1
#-----------------------

Write-Host "INFO: Executing SetupSSH.ps1"

# Open the firewall
Start-Process -wait netsh -ArgumentList "advfirewall firewall add rule name=SSH dir=in action=allow protocol=TCP localport=22"
c:\cygwin\bin\bash -c 'export PATH=/usr/sbin:/usr/bin:$PATH;/usr/bin/ssh-host-config -y -w {{ user `password` }} -c \"binmode ntsec\";\
echo \"PasswordAuthentication no\" >> /etc/sshd_config;\
mkdir -p ~/.ssh;\
chmod 700 ~/.ssh;\
cp /cygdrive/c/packer/authorized_keys ~/.ssh/authorized_keys;\
chmod 644 ~/.ssh/authorized_keys;\
/usr/bin/cygrunsrv -S sshd' 2>&1 | out-null



### TODO ####
#/usr/bin/ssh-host-config -y -w {{ user `password` }}' -c "binmode ntsec";echo hello'

Write-Host "INFO: SetupSSH.ps1 completed"

