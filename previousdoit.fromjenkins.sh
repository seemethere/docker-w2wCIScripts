# Jenkins CI script for Windows to Windows CI
# By John Howard (@jhowardmsft) January 2016

set +e  # Keep going on errors
set +x 

SCRIPT_VER="22-Jan-2016 14:31 PST"

# TODO Tag windowsservercore to latest

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

# Git version
if [ $ec -eq 0 ]; then
	echo "INFO: Running $(git version)"
fi

# Make sure docker is installed
if [ $ec -eq 0 ]; then
	command -v docker >& /dev/null || { echo "ERROR: docker is not installed or not found on path"; ec=1; }
fi

# Make sure go is installed
if [ $ec -eq 0 ]; then
	command -v go >& /dev/null || { echo "ERROR: go is not installed or not found on path"; ec=1; }
fi

# Make sure golint is installed
if [ $ec -eq 0 ]; then
	command -v golint >& /dev/null || { echo "ERROR: golint is not installed or not found on path"; ec=1; }
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
	echo "INFO: Seeing if the control daemon is up and responding..."
	reply=`curl -m 10 -s http://127.0.0.1:2375/_ping`
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
	if [ ! -e Dockerfile.windows ]; then
		echo
		echo "---------------------------------------------------------------------------"
		echo "ERROR: Are you sure this is being launched from the root of a docker repository?"
		echo "       If this is a Windows CI machine, it should be "
		echo "       c:\jenkins\gopath\src\github.com\docker\docker."
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
	export TEMPWIN=c:\\CI\\CI-$COMMITHASH
	export TMP=$TMP
	rmdir $TEMP >& /dev/null # Just in case it exists already
	/usr/bin/mkdir -p $TEMP  # Make sure Linux mkdir for -p
	/usr/bin/mkdir $TEMP/userprofile >& /dev/null
	export USERPROFILE=$TEMP/userprofile
	/usr/bin/mkdir $TEMP/localappdata >& /dev/null
	export LOCALAPPDATA=$TEMP/localappdata
	/usr/bin/mkdir -p $TEMP/binary
	echo INFO: Location for testing is $TEMP
fi 

# CI Integrity check - ensure we are using the same version of go as present in the Dockerfile
if [ $ec -eq 0 -a ! $inrepo -eq 0 ]; then
	! GOVER_DOCKERFILE=`grep 'ENV GO_VERSION' Dockerfile | awk '{print $3}'`
	! GOVER_INSTALLED=`go version | awk '{print $3}'`
	echo INFO: Validating installed GOLang version $GOVER_INSTALLED is correct...
	if [ "${GOVER_INSTALLED:2}" != "$GOVER_DOCKERFILE" ]; then
		echo
		echo "---------------------------------------------------------------------------"
		echo "WARN: CI should be using go version $GOVER_DOCKERFILE, but it is using ${GOVER_INSTALLED:2}"
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

# TODO RSRC integrity check...

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
# TODO: Can these run in the container instead? Reduces the need for stuff on the host
if [ $ec -eq 0 ]; then
	echo "INFO: Running initial test suite on sources..."
		hack/make.sh validate-dco validate-gofmt validate-pkg validate-lint validate-vet
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: Tests failed."
	fi
fi

# Build the image
if [ $ec -eq 0 ]; then
	echo "INFO: Building the image from Dockerfile.windows..."
	set -x
	docker build -t docker -f Dockerfile.windows .
	ec=$?
	set +x
	if [ 0 -ne $ec ]; then
		echo "ERROR: Failed to build image"
	fi
fi

# Build the binary in a container
if [ $ec -eq 0 ]; then
	echo "INFO: Building the test binary..."
	set -x 
	docker run --rm -v "$TEMPWIN:c:\target" \
		docker sh -c 'cd /c/go/src/github.com/docker/docker; \
						hack/make.sh binary; \
						ec=$?; \
						if [ $ec -eq 0 ]; then \
							robocopy /c/go/src/github.com/docker/docker/bundles/$(cat VERSION)/binary /c/target/binary; \
						fi; \
						exit $ec'
	ec=$?
	set +x
	if [ 0 -ne $ec ]; then
		echo "ERROR: Failed to build test binary"
	fi
fi

# Copy the built docker.exe to docker-$COMMITHASH.exe so that easily spotted in task manager,
# and make sure the built binaries are first on our path
if [ $ec -eq 0 ]; then
	echo "INFO: Linking the built binary to $TEMP/docker-$COMMITHASH..."
	ln $TEMP/binary/docker.exe $TEMP/binary/docker-$COMMITHASH.exe
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: Failed to link"
	else
		# Make sure it's on our path
		export PATH=$TEMP/binary:$PATH
	fi
fi

# Start the daemon under test, ensuring everything is redirected to folders under $TEMP
if [ $ec -eq 0 ]; then
	ip="${DOCKER_HOST#*://}"
	ip="${ip%%:*}"
	export DOCKER_HOST="tcp://$ip:2357"
	export DOCKER_TEST_HOST=$DOCKER_HOST   # Forces .integration-daemon-start down Windows path

	echo "INFO: Starting a daemon under test..."
        mkdir $TEMP/daemon >& /dev/null
        $TEMP/binary/docker-$COMMITHASH daemon -D \
		-H=$DOCKER_HOST \
		--exec-root=$TEMP/daemon/execroot \
		--graph=$TEMP/daemon/graph \
		--pidfile=$TEMP/daemon/docker.pid \
		&> $TEMP/daemon/daemon.log &
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: Could not start daemon"
	else
		echo "INFO: Process started successfully."
		daemonstarted=1
	fi
fi

# Verify we can get the daemon under test to respond to _ping
if [ 0 -eq $ec ]; then
	# Give it time to start
	tries=30
	echo "INFO: Waiting for daemon under test to reply to ping..."
	while [ "$ec" -eq 0 ]; do
		reply=""
		reply=$(curl -m 10 -s http://127.0.0.1:2357/_ping)
		if [ "$reply" == "OK" ]; then				
			break
		fi 
						
		(( tries-- ))
		if [ $tries -le 0 ]; then
			printf "\n"
			echo "ERROR: Failed to get OK response from the daemon under test at 127.0.0.1:2357"
			ec=1
		fi
						
		if [ 0 -eq $ec ]; then
			printf "."
			sleep 1
		fi
	done
	if [ 0 -eq $ec ]; then
		echo "INFO: Daemon under test started and replied!"
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
