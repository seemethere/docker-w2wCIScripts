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

	! containerCount=$(docker ps -aq | wc -l)
	if [ $containerCount -gt 0 ]; then
		echo "INFO: Container count on control daemon to delete is $containerCount"	
		! docker rm -f $(docker ps -aq)
	fi

	# TODO Remove this reliability hack after TP4 is no longer supported
	! imageCount=$(docker images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | grep -v docker | wc -l)
	if [ $imageCount -gt 0 ]; then
		if [ "${ver%%[^0-9]*}" -lt "11100" ]; then
			# TP4 reliability hack  - only clean if we have a docker:latest image. This stops
			# us clearing the cache if the builder fails due to the known TP4 networking issue
			# half way through. This way we can continue the next time from where we got to.
			! dockerLatestCount=$(docker images | sed -n '1!p' | grep docker | grep latest | wc -l)
			if [ "$dockerLatestCount" -gt 0 ]; then
				cleanUpImages=1
			else
				echo "WARN: TP4 reliability hack: Not cleaning $imageCount non-base image(s)"
			fi
		else
			echo "INFO: Non-base image count on control daemon to delete is $imageCount"
			cleanupImages=1
		fi
		
		if [ -n "$cleanupImages" ]; then
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
			# Ignore the literal case.
			if [ "$DIR" != "/c/CI/CI-*" ] ; then
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
						! containerCount=$($TEMP/binary/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 ps -aq | wc -l)
						echo "INFO: Container count on this daemon is $containerCount"
						if [ $containerCount -gt 0 ]; then
							echo "INFO: Found $containerCount container(s) to remove"
							! $TEMP/binary/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 rm -vf $($TEMP/binary/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 ps -aq)
						fi
				
						! imageCount=$($TEMP/binary/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | wc -l)
						echo "INFO: Image count on this daemon is $imageCount"
						if [ $imageCount -gt 0 ]; then
							echo "INFO: Found $imageCount images(s) to remove"
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
				
				if [ -d $TEMP ]; then
					echo "WARN: Failed to completely clean $TEMP"
				fi
			fi
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