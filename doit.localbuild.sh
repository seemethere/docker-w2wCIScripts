# Jenkins CI script for Windows to Windows CI
# By John Howard (@jhowardmsft) January 2016

# Keep this safe. Example of an older version with local build.

# TODO: Would love to build the binary in a container. That way, we
#       could remove many things from this script, not require so many things
#       installed on the host. But cygwin doesn't work in a container :(

set +e  # Keep going on errors
set +x 

SCRIPT_VER="11-Jan-2016 15:30 PST"

# This function is copied from the cleanup script
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
			
	! IMAGECOUNT=$(docker images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | wc -l)
	if [ $IMAGECOUNT -gt 0 ]; then
		echo "INFO: Non-base image count on control daemon to delete is $IMAGECOUNT"	
		! docker rmi -f $(docker images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | awk '{ print $3 }' )
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


	if [ -e /c/CI -a -e /c/CI/CI-* ]; then
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
	
			if [ -e docker-$CLEANCOMMIT.exe ]; then
				echo "INFO: Starting daemon to cleanup..."
				mkdir $TEMP/daemon >& /dev/null
				$TEMP/docker-$CLEANCOMMIT daemon -D \
					-H=tcp://127.0.0.1:2357 \
					--exec-root=$TEMP/daemon/execroot \
					--gr	aph=$TEMP/daemon/graph \
					--pidfile=$TEMP/daemon/docker.pid \
					&> $TEMP/daemon/daemon.log &
				ec=$?
				if [	 0 -ne $ec ]; then
					echo "ERROR: Failed to start daemon"
				fi
				
				if [ 0 -eq $ec ]; then
					# Give it time to start
					tries=30
					echo "INFO: Waiting for daemon to start..."
						while [ "$ec" -eq 0 ]; do
						reply=""
						reply=$(curl -s http://127.0.0.1:2357/_ping)
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
					! CONTAINERCOUNT=$($TEMP/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 ps -aq | wc -l)
					echo "INFO: Container count on this daemon is $CONTAINERCOUNT"
					if [ $CONTAINERCOUNT -gt 0 ]; then
						echo "INFO: Found $CONTAINERCOUNT container(s) to remove"
						! $TEMP/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 rm -vf $($TEMP/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 ps -aq)
					fi
				
					! IMAGECOUNT=$($TEMP/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | wc -l)
					echo "INFO: Image count on this daemon is $IMAGECOUNT"
					if [ $IMAGECOUNT -gt 0 ]; then
						echo "INFO: Found $IMAGECOUNT images(s) to remove"
						! $TEMP/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 rmi -f $($TEMP/docker-$CLEANCOMMIT -H=tcp://127.0.0.1:2357 images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | awk '{ print $3 }' )
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

ec=0										# Exit code
daemonstarted=0								# 1 when started
inrepo=0									# 1 if we are in a docker repo
deleteatend=0           					# 1 if we need to nuke the redirected $TEMP at the end
export ORIGPATH=$PATH   					# Save our path before we update anything
export DOCKER_HOST="tcp://127.0.0.1:2375"	# In case not set in the environment.

echo INFO: Started at `date`. 
echo INFO: Script version $SCRIPT_VER

# Make sure we are on bash 4.x or later
if [ $ec -eq 0 ]; then
	MAJOR=${BASH_VERSION%%[^0-9]*}
	if [ $MAJOR -lt 4 ]; then
		echo "ERROR: Must be running bash 4.x or later"
		ec=1
	else
		echo "INFO: Running bash version $BASH_VERSION"
	fi
fi

# Make sure docker is installed
if [ $ec -eq 0 ]; then
	command -v docker >& /dev/null || { echo "ERROR: docker is not installed"; ec=1; }
fi

# Make sure rsrc is installed
# TODO: Not needed if building in a container
if [ $ec -eq 0 ]; then
	command -v rsrc >& /dev/null || { echo "ERROR: rsrc is not installed"; ec=1; }
fi

# Make sure TESTROOT is set
if [ $ec -eq 0 ]; then
	if [ -z $TESTROOT ]; then
		echo "ERROR: TESTROOT environment variable is not set!"
		echo "       This should be the root of the workspace,"
		echo "       for example /c/gopath"
		echo 
		echo "       Under TESTROOT is where the repo would be cloned."
		echo "       eg /c/gopath/src/github.com/docker/docker"
		echo 
		ec=1
	else
		echo "INFO: Root for testing is $TESTROOT"
	
		# Set the WORKSPACE
		export WORKSPACE=$TESTROOT/src/github.com/docker/docker
		echo "INFO: Workspace for sources is $WORKSPACE"
		
		# Set the GOPATH to the root and the vendor directory
		export GOPATH=$TESTROOT:$TESTROOT/src/github.com/docker/docker/vendor
		echo "INFO: GOPATH set to $GOPATH"

		# Update our path to include the bin directory for GO
		# TODO: Not needed if building in a container
		echo "INFO: Including $TESTROOT/bin in PATH"
		PATH=$TESTROOT/bin:$PATH
		
	fi
fi

# Testing my stupidity by making sure TESTROOT is in linux semantics.
if [[ "$TESTROOT" == *\\* ]] || [[ "$TESTROOT" == *:* ]]; then
	echo "ERROR: TESTROOT looks to be set to a Windows path as it contains \ or :"
	echo "       It should be the root of the workspace using Linux sematics."
	echo "       eg /c/gopath. Current value is $TESTROOT"
	echo
	ec=1
fi

# Check WORKSPACE is a valid directory
if [ $ec -eq 0 ]; then 
	if [ ! -d $WORKSPACE ]; then
		echo "ERROR: $WORKSPACE is not a directory!"
		ec=1
	fi
fi

# Make sure we start in the workspace
if [ $ec -eq 0 ]; then
	cd $WORKSPACE
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: Failed to change directory to $WORKSPACE"
	fi
fi

# Verify we can get the local daemon to respond to _ping
if [ $ec -eq 0 ]; then
	reply=`curl -s http://127.0.0.1:2375/_ping`
	if [ "$reply" != "OK" ]; then
		ec=1
		echo
		echo "---------------------------------------------------------------------------"
		echo "ERROR: Failed to get OK response from the control daemon at 127.0.0.1:2375. It may be down."
		echo "       Try re-running this CI job, or ask on #docker-dev or #docker-maintainers"
		echo "       to see if the the daemon is running. Also check the nssm configuration."
		echo "---------------------------------------------------------------------------"
		echo
	else
		echo "INFO: The control daemon replied to a ping. Good!"
	fi 
fi

# Make sure we are in repo
if [ $ec -eq 0 ]; then
	if [ ! -d hack ]; then
		echo
		echo "---------------------------------------------------------------------------"
		echo "ERROR: Are you sure this is being launched from a the root of docker repository?"
		echo "       If this is a Windows CI machine, it should be c:\jenkins\gopath\src\github.com\docker\docker."
                echo "       Current directory is `pwd`"
		echo "---------------------------------------------------------------------------"
		ec=1
	else
		inrepo=1
		echo INFO: Repository was found
	fi
fi

# Get the commit has and verify we have something
if [ $ec -eq 0 ]; then
	export COMMITHASH=$(git rev-parse --short HEAD)
	echo INFO: Commit hash is $COMMITHASH
	if [ -z $COMMITHASH ]; then
		echo "ERROR: Failed to get commit hash. Are you sure this is a docker repository?"
		ec=1
	fi
fi

# Nuke everything and go back to our workspace after
if [ $ec -eq 0 ]; then
	! nuke_everything
	cd $WORKSPACE
fi

# Redirect to a temporary location. 
if [ $ec -eq 0 ]; then
	deleteatend=1
	export TEMP=/c/CI/CI-$COMMITHASH
	export TMP=$TMP
	rmdir $TEMP >& /dev/null # Just in case it exists already
	/usr/bin/mkdir -p $TEMP  # Make sure Linux mkdir for -p
	/usr/bin/mkdir $TEMP/userprofile >& /dev/null
	export USERPROFILE=$TEMP/userprofile
	/usr/bin/mkdir $TEMP/localappdata >& /dev/null
	export LOCALAPPDATA=$TEMP/localappdata
	echo INFO: Location for testing is $TEMP
fi 

# CI Integrity check - ensure we are using the same version of go as present in the Dockerfile
if [ $ec -eq 0 -a ! $inrepo -eq 0 ]; then
	! GOVER_DOCKERFILE=`grep 'ENV GO_VERSION' Dockerfile | awk '{print $3}'`
	! GOVER_INSTALLED=`go version | awk '{print $3}'`
	echo INFO: Validating installed GOLang version $GOVER_INSTALLED is correct...
	if [ "${GOVER_INSTALLED:2}" != "$GOVER_DOCKERFILE" ]; then
		ec=1
		echo
		echo "---------------------------------------------------------------------------"
		echo "ERROR: CI should be using go version $GOVER_DOCKERFILE, but it is using ${GOVER_INSTALLED:2}"
		echo 
		echo "       This CI server needs updating. Please ping #docker-dev or"
		echo "       #docker-maintainers."
		echo "---------------------------------------------------------------------------"
		echo
	fi
fi

# CI Integrity check - ensure Dockerfile.windows and Dockerfile go versions match
if [ $ec -eq 0 -a ! $inrepo -eq 0 ]; then
	! GOVER_DOCKERFILE=`grep 'ENV GO_VERSION' Dockerfile | awk '{print $3}'`
	! GOVER_DOCKERFILEWIN=`grep 'ENV GO_VERSION' Dockerfile | awk '{print $3}'`
	echo INFO: Validating GOLang consistency in Dockerfile.windows...
	if [ "${GOVER_DOCKERFILEWIN}" != "$GOVER_DOCKERFILE" ]; then
		ec=1
		echo
		echo "---------------------------------------------------------------------------"
		echo "ERROR: Mismatched GO versions between Dockerfile and Dockerfile.windows"
		echo "       Please update your PR to ensure that both files are updated!!!"
		echo 
		echo "---------------------------------------------------------------------------"
		echo
	fi
fi

# TODO Same integrity check as above for rsrc

# Provide the docker version for debugging purposes.
if [ $ec -eq 0 ]; then
	echo INFO: Docker version of control daemon
	echo
	docker version
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: The control daemon does not appear to be running."
	fi
	echo
fi

# Same as above, but docker info
if [ $ec -eq 0 ]; then
	echo INFO: Docker info of control daemon
	echo
	docker info
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: The control daemon does not appear to be running."
	fi
	echo
fi

# Run the essential tests
# TODO: validate-test test-unit
# TODO: Although works, I don't think they actually are doing the right checks.
if [ $ec -eq 0 ]; then
	echo "INFO: Running initial test suite on sources..."
	hack/make.sh validate-dco validate-gofmt validate-pkg validate-lint validate-toml validate-vet validate-vendor
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: Tests failed."
	fi
fi

# Build locally. #TODO Build in container if we can.
if [ $ec -eq 0 ]; then
	echo "INFO: Building test docker.exe binary..."
	echo
	set -x
	hack/make.sh binary 
	ec=$?
	set +x
	if [ 0 -ne $ec ]; then
	    echo "ERROR: Build of binary on Windows failed"
	fi
fi

# Make a local copy of the built binary and ensure that is first in our path
if [ $ec -eq 0 ]; then
	VERSION=$(< ./VERSION)
	cp bundles/$VERSION/binary/docker.exe $TEMP/docker-$COMMITHASH.exe  # So that task manager can spot the daemon easily
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: Failed to copy built binary to $TEMP"
	else
		export PATH=$TEMP:$PATH
		rm -f $TEMP/docker.exe >& /dev/null  # Just in case
		ln $TEMP/docker-$COMMITHASH.exe $TEMP/docker.exe  
	fi

fi

# Start a daemon, ensuring everything is redirected to $TEMP
if [ $ec -eq 0 ]; then
	ip="${DOCKER_HOST#*://}"
	ip="${ip%%:*}"
	export DOCKER_HOST="tcp://$ip:2357"
	export DOCKER_TEST_HOST=$DOCKER_HOST   # Forces .integration-daemon-start down Windows path

	echo "INFO: Starting a daemon under test..."
        mkdir $TEMP/daemon >& /dev/null
        $TEMP/docker-$COMMITHASH daemon -D \
		-H=$DOCKER_HOST \
		--exec-root=$TEMP/daemon/execroot \
		--graph=$TEMP/daemon/graph \
		--pidfile=$TEMP/daemon/docker.pid \
		&> $TEMP/daemon/daemon.log &
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: Could not start daemon"
	else
		echo "INFO: Daemon under test started"
		daemonstarted=1
	fi
fi

# Verify we can get the daemon under test to respond to _ping
if [ $ec -eq 0 ]; then
	sleep 5 # TODO Put this in a loop for up to 60 seconds
	reply=`curl -s http://127.0.0.1:2357/_ping`
	if [ "$reply" != "OK" ]; then
		ec=1
		echo "ERROR: Failed to get OK response from the daemon under test at 127.0.0.1:2357"
	else
		echo "INFO: The daemon under test replied to a ping. Good!"
	fi 
fi

# Provide the docker version of the daemon under test for debugging purposes.
if [ $ec -eq 0 ]; then
	echo INFO: Docker version of the daemon under test
	echo
	docker version
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: The daemon under test does not appear to be running."
	fi
	echo
fi

# Same as above, but docker info
if [ $ec -eq 0 ]; then
	echo INFO: Docker info of the daemon under test
	echo
	docker info
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: The daemon under test does not appear to be running."
	fi
	echo
fi

# Run the integration tests
if [ $ec -eq 0 ]; then
	echo "INFO: Running integration tests..."
	hack/make.sh test-integration-cli
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: Tests failed."
	fi
fi

# Dump the daemon log if asked to 
if [ $daemonstarted -eq 1 ]; then
	if [ -n "$DUMPDAEMONLOG" ]; then
		echo ----------- DAEMON LOG ------------
		cat $TEMP/daemon/daemon.log
		echo --------- END DAEMON LOG ----------
	fi
fi

# Delete any containers and their volumes, plus any images if the daemon was started,
# before killing the daemon under test itself
if [ $daemonstarted -eq 1 ]; then
	echo "INFO: Removing containers and images..."

	! CONTAINERCOUNT=$(docker ps -aq | wc -l)
	if [ $CONTAINERCOUNT -gt 0 ]; then
		echo "INFO: Removing $CONTAINERCOUNT containers"
		! docker rm -vf $(docker ps -aq)
		sleep 10  # To be sure #TODO Put in a loop
	fi
	
	! IMAGECOUNT=$(docker images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | wc -l)
	if [ $IMAGECOUNT -gt 0 ]; then
		echo "INFO: Removing $IMAGECOUNT images"
		! docker rmi -f $(! docker images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | awk '{ print $3 }' )
		sleep 10 # To be sure
	fi

	PID=$(< $TEMP/daemon/docker.pid)
	if [ ! -z $PID ]; then
		echo "INFO: Stopping daemon under test"
		! taskkill -f -t -pid $PID 
		sleep 10
	fi
fi

# Remove everything. This avoid cleanup having to restart the daemon.
if [ $deleteatend -eq 1 ]; then
	rm -rf $TEMP >& /dev/null
fi

# Tell the user how we did.
if [ $ec -eq 0 ]; then
	echo INFO: Completed successfully at `date`. 
else
	echo ERROR: Failed with exitcode $ec at `date`.
fi
overallrun_ec=$ec

# Nuke everything again, making sure we're point to the installed docker, not the one under test.
PATH=$ORIGPATH
echo "INFO: Tidying up at end of run"
! nuke_everything
! cd $WORKSPACE

echo INFO: Ended at `date`.
exit $overallrun_ec
