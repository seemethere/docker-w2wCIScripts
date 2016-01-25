# Jenkins CI script for Windows to Windows CI cleanup
# By John Howard (@jhowardmsft) January 2016

set +e  # Keep going on errors
set +x 

nuke_everything()
{
	export DOCKER_HOST="tcp://127.0.0.1:2375"
	export OLDTEMP=$TEMP
	export OLDTMP=$TMP
	export OLDUSERPROFILE=$USERPROFILE
	export OLDLOCALAPPDATA=$LOCALAPPDATA

	! CONTAINERCOUNT=$(docker ps -aq | wc -l)
	if [ $CONTAINERCOUNT -gt 0 ]; then
		echo "INFO: Container count on control daemon to delete is $CONTAINERCOUNT"	
		! docker rm -f $(docker ps -aq)
	fi


	# TODO Fix this reliability hack after TP4 is no longer supported
	! IMAGECOUNT=$(docker images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | grep -v docker | wc -l)
	if [ $IMAGECOUNT -gt 0 ]; then
		ver=$(reg query "HKLM\Software\Microsoft\Windows NT\CurrentVersion" | grep BuildLabEx | awk '{print $3}')
		echo "INFO: Operating system version $ver"
		if [ "${ver%%[^0-9]*}" -lt "11100" ]; then
			echo "WARN: TP4 reliability hack: Not cleaning $IMAGECOUNT non-base image(s)"
		else
			echo "INFO: Non-base image count on control daemon to delete is $IMAGECOUNT"	
			! docker rmi -f $(docker images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | grep -v docker | awk '{ print $3 }' )
		fi	
	fi

	# Paranoid moment - kill any spurious daemons. The '-' in 'docker-' is IMPORTANT!
	IFS=$'\n'
	for PID in $(tasklist | grep docker- | awk {'print $2'})
	do
		echo "INFO: Killing daemon with PID $PID"
		taskkill -f -t -pid $PID
		sleep 5  # Make sure
	done

	# Even more paranoid - kill a bunch of stuff that might be locking files
	! taskkill -F -IM link.exe -T 		>& /dev/null
	! taskkill -F -IM compile.exe -T 	>& /dev/null
	! taskkill -F -IM go.exe -T 		>& /dev/null
	! taskkill -F -IM git.exe -T 		>& /dev/null


	if [[ -e /c/CI ]]; then
		for DIR in /c/CI/CI-*; do
			echo "INFO: Cleaning $DIR"
			CLEANCOMMIT=${DIR:9:7}
			local ec=0
			cd $DIR
			export TEMP=$DIR
			export TMP=$DIR
			export USERPROFILE=$DIR/userprofile
			export LOCALAPPDATA=$DIR/localappdata
			echo "INFO: Nuking $DIR"
	
			if [ -e binary/docker-$CLEANCOMMIT.exe ]; then
				echo "INFO: Starting daemon to cleanup..."
				mkdir $TEMP/daemon >& /dev/null
				set +x
				$TEMP/binary/docker-$CLEANCOMMIT daemon -D \
					-H=tcp://127.0.0.1:2357 \
					--exec-root=$TEMP/daemon/execroot \
					--graph=$TEMP/daemon/graph \
					--pidfile=$TEMP/daemon/docker.pid \
					&> $TEMP/daemon/daemon.log &
				ec=$?
				if [ 0 -ne $ec ]; then
					echo "ERROR: Failed to start daemon"
				fi
				
				if [ 0 -eq $ec ]; then
					# Give it time to start
					tries=30
					echo "INFO: Waiting for daemon to start..."
						while [ "$ec" -eq 0 ]; do
						reply=""
						reply=$(curl -m 10 -s http://127.0.0.1:2357/_ping)
						if [ "$reply" == "OK" ]; then				
								break
						fi 
						
						(( tries-- ))
						if [ $tries -le 0 ]; then
							printf "\n"
							echo "WARN: Daemon never started"
							ec=1
						fi
						
						if [ 0 -eq $ec ]; then
							printf "."
							sleep 1
						fi
					done
				fi
				
				if [ 0 -eq $ec ]; then
						echo "INFO: Daemon started ready for cleanup"
					! CONTAINERCOUNT=$($TEMP/binary/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 ps -aq | wc -l)
					echo "INFO: Container count on this daemon is $CONTAINERCOUNT"
					if [ $CONTAINERCOUNT -gt 0 ]; then
						echo "INFO: Found $CONTAINERCOUNT container(s) to remove"
						! $TEMP/binary/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 rm -vf $($TEMP/binary/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 ps -aq)
					fi
				
					! IMAGECOUNT=$($TEMP/binary/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | wc -l)
					echo "INFO: Image count on this daemon is $IMAGECOUNT"
					if [ $IMAGECOUNT -gt 0 ]; then
						echo "INFO: Found $IMAGECOUNT images(s) to remove"
						! $TEMP/binary/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 rmi -f $($TEMP/binary/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | awk '{ print $3 }' )
					fi
	
					# Kill the daemon
					PID=$(< $TEMP/daemon/docker.pid)
					if [ ! -z $PID ]; then
						taskkill -f -t -pid $PID 
						sleep 2
					fi
				fi
			fi
	
			# Force delete
			cd ..
			! rm -rfd $TEMP/* >& /dev/null
			! rm -rfd $TEMP/*. >& /dev/null
			! rmdir $TEMP >& /dev/null
	
		done
	fi
	
	echo "INFO: End of cleanup"
	export TEMP=$OLDTEMP
	export TMP=$OLDTMP
	export USERPROFILE=$OLDUSERPROFILE
	export LOCALAPPDATA=$OLDLOCALAPPDATA	
}

! nuke_everything
true
