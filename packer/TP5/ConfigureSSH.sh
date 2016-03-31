#!/bin/bash
export PATH=/usr/sbin:/usr/bin:$PATH
logfile=/cygdrive/c/packer/ConfigureSSH.log
exec > $logfile
echo Nuking SSH settings...
cygrunsrv --stop sshd
cygrunsrv --remove sshd
net user sshd /delete
net user cyg_server /delete
rm -r /etc/ssh* /var/empty /var/log/sshd.log /var/log/lastlog /etc/passwd > /dev/nul 2>&1
echo Creating ~/.ssh
mkdir ~/.ssh
echo Configuring SSH with a random password and binmode ntsec
/usr/bin/ssh-host-config -y -w `openssl rand -base64 32` -c "binmode ntsec"
echo Setting PasswordAuthentication to no
echo "PasswordAuthentication no" >> /etc/sshd_config
echo Changing permissions
chmod 700 ~/.ssh
echo Copying authorized keys
cp /cygdrive/c/packer/authorized_keys ~/.ssh/authorized_keys
chmod 644 ~/.ssh/authorized_keys
echo Starting server
/usr/bin/cygrunsrv -S sshd