#!/bin/bash
export PATH=/usr/sbin:/usr/bin:$PATH
logfile=/cygdrive/c/packer/ConfigureSSH.log
exec > $logfile
mkdir ~/.ssh
pass=$(< /cygdrive/c/packer/SSHpassword.txt)
/usr/bin/ssh-host-config -y -w $pass -c "binmode ntsec"
echo "PasswordAuthentication no" >> /etc/sshd_config
chmod 700 ~/.ssh
cp /cygdrive/c/packer/authorized_keys ~/.ssh/authorized_keys
chmod 644 ~/.ssh/authorized_keys
/usr/bin/cygrunsrv -S sshd