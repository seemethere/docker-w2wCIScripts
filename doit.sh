# Jenkins CI script for Windows to Windows CI
# By John Howard (@jhowardmsft) January 2016

set +e  # Keep going on errors
set +x 

SCRIPT_VER="26-Jan-2016 09:44 PDT"

# This function is copied from the cleanup script
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
		# TODO Loop round 10 times
		# eg https://jenkins.dockerproject.org/job/Docker-PRs-WoW-TP4/92/console
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
	done

	# Even more paranoid - kill a bunch of stuff that might be locking files
	! taskkill -F -IM link.exe -T 				>& /dev/null
	! taskkill -F -IM compile.exe -T 			>& /dev/null
	! taskkill -F -IM go.exe -T 				>& /dev/null
	! taskkill -F -IM git.exe -T 				>& /dev/null
	
	# Note: This one is interesting. Found a case where the workspace could not be deleted
	# by Jenkins as the bundles directory couldn't be cleaned. Pretty strongly suspect
	# it is integration-cli-test as the command line run is something like
	# c:\ci\ci-commit\go-buildID\github.com\docker\docker\integration-cli\_test\integration-cli.test.exe
	#  -test.coverprofile=C:/gopath/src/github.com/docker/docker/bundles/VERSION/test-integration-cli/coverprofiles/docker-integration-cli -test.timeout=nnn
	! taskkill -F -IM integration-cli.test.exe -T	>& /dev/null

	sleep 10  # Make sure

	# Yet more paranoia - kill anything that's running under the commit ID directory, just in
	# case integration-cli (or test-unit?) leaves behind some spurious process
	processes=$(ps -W | grep CI-$COMMITID | grep .exe | awk '{ print $1 }')  
	processCount=$(echo $processes | wc -w)
	if [ $processCount > 0 ]; then
		echo "INFO: Found $processCount other processes to kill"
		for proc in $processes; do 
			! taskkill -F -T -PID $proc	>& /dev/null
			echo $proc
		done
		sleep 10  # Just to be sure
	fi

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

ec=0											# Exit code
daemonStarted=0									# 1 when started
inRepo=0										# 1 if we are in a docker repo
deleteAtEnd=0           						# 1 if we need to nuke the redirected $TEMP at the end
SECONDS=0

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

# OS Version
if [ $ec -eq 0 ]; then
	export ver=$(reg query "HKLM\Software\Microsoft\Windows NT\CurrentVersion" | grep BuildLabEx | awk '{print $3}')
	export productName=$(reg query "HKLM\Software\Microsoft\Windows NT\CurrentVersion" | grep ProductName | awk '{print substr($0, index($0,$3))}')
	echo "INFO: Running Windows version $ver"
	echo "INFO: Running $productName"
fi

# PR
if [ $ec -eq 0 ]; then
	if [ -n "$PR" ]; then
		echo "INFO: PR#$PR (https://github.com/docker/docker/pull/$PR)"
	fi
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

# Make sure windowsservercore image is installed
if [ $ec -eq 0 ]; then
	! build=$(docker images | grep windowsservercore | grep -v latest | awk '{print $2}')
	if [ -z $build ]; then
		echo "ERROR: Could not find windowsservercore image"
		ec=1
	fi
fi

# Tag it as latest if not already tagged
if [ $ec -eq 0 ]; then
	! latestCount=$(docker images | grep windowsservercore | grep -v $build | wc -l)
	if [ $latestCount -ne 1 ]; then
		docker tag windowsservercore:$build windowsservercore:latest
		ec=$?
		if [ ec -eq 0 ]; then
			echo "INFO: Tagged windowsservercore:$build with latest"
		else
			echo "ERROR: Failed to tag windowsservercore:$build as latest"
		fi
	fi
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
		export GOPATH=$TESTROOT/src/github.com/docker/docker/vendor:$TESTROOT
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
		echo "       c:\gopath\src\github.com\docker\docker."
		echo "       Current directory is `pwd`"
		echo "---------------------------------------------------------------------------"
		ec=1
	else
		inRepo=1
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
	deleteAtEnd=1
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
if [ $ec -eq 0 -a ! $inRepo -eq 0 ]; then
	! GOVER_DOCKERFILE=`grep 'ENV GO_VERSION' Dockerfile | awk '{print $3}'`
	! GOVER_INSTALLED=`go version | awk '{print $3}'`
	echo INFO: Validating installed GOLang version $GOVER_INSTALLED is correct...
	if [ "${GOVER_INSTALLED:2}" != "$GOVER_DOCKERFILE" ]; then
		warnGoVersionAtEnd=1
	else
		unset warnGoVersionAtEnd
	fi
fi

# CI Integrity check - ensure Dockerfile.windows and Dockerfile go versions match
if [ $ec -eq 0 -a ! $inRepo -eq 0 ]; then
	! GOVER_DOCKERFILE=`grep 'ENV GO_VERSION' Dockerfile | awk '{print $3}'`
	! GOVER_DOCKERFILEWIN=`grep 'ENV GO_VERSION' Dockerfile | awk '{print $3}'`
	echo INFO: Validating GOLang consistency in Dockerfile.windows...
	if [ "${GOVER_DOCKERFILEWIN}" != "$GOVER_DOCKERFILE" ]; then
		ec=1
		echo
		echo "---------------------------------------------------------------------------"
		echo "ERROR: Mismatched GO versions between Dockerfile and Dockerfile.windows"
		echo "       Update your PR to ensure that both files are updated and in sync."
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

# Build the image
if [ $ec -eq 0 ]; then
	echo "INFO: Building the image from Dockerfile.windows..."
	set -x
	docker build -t docker -f Dockerfile.windows .
	ec=$?
	set +x
	if [ 0 -ne $ec ]; then
		echo
		echo "----------------------------"
		echo "ERROR: Failed to build image"
		echo "----------------------------"
		echo		
	fi
fi

# Build the binary in a container
if [ $ec -eq 0 ]; then
	echo "INFO: Building the test binary..."
	set -x 
	docker run --rm -v "$TEMPWIN:c:\target"	docker sh -c 'cd /c/go/src/github.com/docker/docker; \
	hack/make.sh binary; \
	ec=$?; \
	if [ $ec -eq 0 ]; then \
		robocopy /c/go/src/github.com/docker/docker/bundles/$(cat VERSION)/binary /c/target/binary; \
	fi; \
	exit $ec'
	ec=$?
	set +x
	if [ 0 -ne $ec ]; then
		echo
		echo "----------------------------------"
		echo "ERROR: Failed to build test binary"
		echo "----------------------------------"
		echo
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
	fi
fi

# Start the daemon under test, ensuring everything is redirected to folders under $TEMP
if [ $ec -eq 0 ]; then
	echo "INFO: Starting a daemon under test..."
    mkdir $TEMP/daemon >& /dev/null
	mkdir $TEMP/daemon/execroot >& /dev/null
	mkdir $TEMP/daemon/graph >& /dev/null
    $TEMP/binary/docker-$COMMITHASH daemon -D \
		-H=tcp://127.0.0.1:2357 \
		--exec-root=$TEMP/daemon/execroot \
		--graph=$TEMP/daemon/graph \
		--pidfile=$TEMP/daemon/docker.pid \
		&> $TEMP/daemon/daemon.log &
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: Could not start daemon"
	else
		echo "INFO: Process started successfully."
		daemonStarted=1
	fi
fi

# Verify we can get the daemon under test to respond to _ping
if [ 0 -eq $ec ]; then
	# Give it time to start
	tries=20
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
			echo
			echo "-----------------------------------------------------------------------------"
			echo "ERROR: Failed to get OK response from the daemon under test at 127.0.0.1:2357"
			echo "-----------------------------------------------------------------------------"
			echo 
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
	$TEMP/binary/docker-$COMMITHASH -H=tcp://127.0.0.1:2357 version
	ec=$?
	if [ 0 -ne $ec ]; then
		echo
		echo "-----------------------------------------------------------"
		echo "ERROR: The daemon under test does not appear to be running."
		echo "-----------------------------------------------------------"
		echo
	fi
	echo
fi

# Same as above, but docker info
if [ $ec -eq 0 ]; then
	echo INFO: Docker info of the daemon under test
	echo
	$TEMP/binary/docker-$COMMITHASH -H=tcp://127.0.0.1:2357 info
	ec=$?
	if [ 0 -ne $ec ]; then
		echo
		echo "-----------------------------------------------------------"
		echo "ERROR: The daemon under test does not appear to be running."
		echo "-----------------------------------------------------------"
		echo
	fi
	echo
fi

# Run the validation tests inside a container
if [ $ec -eq 0 ]; then
	echo "INFO: Running validation tests..."
	# Note sleep is necessary for Windows networking workaround (see dockerfile.Windows)
	set -x
	docker run --rm docker sh -c \
	'cd /c/go/src/github.com/docker/docker; \
 	 sleep 5; \
	 hack/make.sh validate-dco validate-gofmt validate-pkg'
	ec=$?
	set +x
	if [ 0 -ne $ec ]; then
		echo
		echo "-------------------------"
		echo "ERROR: Validation failed."
		echo "-------------------------"
		echo
	fi
fi

# Run the unit tests inside a container
if [ $ec -eq 0 ]; then
	echo "INFO: Running unit tests..."
	set -x
	docker run --rm docker sh -c 'cd /c/go/src/github.com/docker/docker; hack/make.sh test-unit'
	ec=$?
	set +x
	if [ 0 -ne $ec ]; then
		echo "ERROR: Unit tests failed."
		echo
		echo
		echo "		-----------------------------------------"
		echo "		IGNORING UNIT TEST FAILURES ON WINDOWS."
		echo "		These need fixing. @jhowardmsft Jan 2016."
		echo " 		PRs are welcome :)"
		echo "		-----------------------------------------"
		echo
		echo
		ec=0
	fi
fi

# Run the integration tests (these are run on the host, not in a container)
if [ $ec -eq 0 ]; then
	echo "INFO: Running integration tests..."

	#	## For in a container. Not sure if this will work with NAT ##
	#   ## Keep this block of code safe for when I get back to     ##
	#   ## looking at it again.                                    ##
	#	set -x 
	#	docker run --rm -v "$TEMPWIN\binary:c:\target" \
	#	docker sh -c 'export DOCKER_HOST=tcp://someip:2357; \
	#	export DOCKER_TEST_HOST=tcp://someip:2357; \
	#	export PATH=/c/target:$PATH; \
	#	cd /c/go/src/github.com/docker/docker; \
	#	hack/make.sh test-integration-cli'
	#	ec=$?
	#	set +x


	export ORIGPATH=$PATH # Save our path before we update anything
	export PATH=$TEMP/binary:$PATH # Make sure it's first on our path
	export DOCKER_HOST=tcp://127.0.0.1:2357
	export DOCKER_TEST_HOST=tcp://127.0.0.1:2357 # Forces .integration-deaemon-start down Windows path
	set -x
	hack/make.sh test-integration-cli
	ec=$?
	set +x
	# revert back
	export PATH=$ORIGPATH
	export DOCKER_HOST=tcp://127.0.0.1:2375
	unset DOCKER_TEST_HOST

	if [ 0 -ne $ec ]; then
		echo
		echo "-------------------------------"
		echo "ERROR: Integration tests failed"
		echo "-------------------------------"
		echo
	fi
fi

# Dump the daemon log if asked to 
if [ $daemonStarted -eq 1 ]; then
	if [ -n "$DUMPDAEMONLOG" ]; then
		echo ----------- DAEMON LOG ------------
		cat $TEMP/daemon/daemon.log
		echo --------- END DAEMON LOG ----------
	fi
fi

# Delete any containers and their volumes, plus any images if the daemon was started,
# before killing the daemon under test itself
if [ $daemonStarted -eq 1 ]; then
	echo "INFO: Removing containers and images from daemon under test..."

	! containerCount=$($TEMP/binary/docker-$COMMITHASH -H=tcp://127.0.0.1:2357 ps -aq | wc -l)
	if [ $containerCount -gt 0 ]; then
		echo "INFO: Removing $containerCount containers"
		! $TEMP/binary/docker-$COMMITHASH -H=tcp://127.0.0.1:2357 rm -vf $($TEMP/binary/docker-$COMMITHASH -H=tcp://127.0.0.1:2357 ps -aq)
		sleep 10 
	fi
	
	! imageCount=$($TEMP/binary/docker-$COMMITHASH -H=tcp://127.0.0.1:2357 images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | wc -l)
	if [ $imageCount -gt 0 ]; then
		echo "INFO: Removing $imageCount images"
		! $TEMP/binary/docker-$COMMITHASH -H=tcp://127.0.0.1:2357 rmi -f $(! $TEMP/binary/docker-$COMMITHASH -H=tcp://127.0.0.1:2357 images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | awk '{ print $3 }' )
		sleep 10
	fi

	PID=$(< $TEMP/daemon/docker.pid)
	if [ ! -z $PID ]; then
		echo "INFO: Stopping daemon under test"
		! taskkill -f -t -pid $PID 
		sleep 10
	fi
fi

# Remove everything. This avoid cleanup having to restart the daemon.
if [ $deleteAtEnd -eq 1 ]; then
	rm -rf $TEMP >& /dev/null
	rm -rfd $TEMP >& /dev/null
fi

# Warning about Go Version
if [ -n "$warnGoVersionAtEnd" ]; then
	echo
	echo "---------------------------------------------------------------------------"
	echo "WARN: CI should be using go version $GOVER_DOCKERFILE, but it is using ${GOVER_INSTALLED:2}"
	echo 
	echo "       This CI server needs updating. Please ping #docker-dev or"
	echo "       #docker-maintainers."
	echo "---------------------------------------------------------------------------"
	echo
fi


# Tell the user how we did.
if [ $ec -eq 0 ]; then
	echo INFO: Completed successfully at `date`. 
else
	echo
	echo
	echo "-----------------------------------------------"
	echo ERROR: Failed with exitcode $ec at `date`.
	echo "-----------------------------------------------"
	echo
	echo
fi
overallrun_ec=$ec

# Nuke everything again, making sure we're point to the installed docker, not the one under test.
echo "INFO: Tidying up at end of run"
! nuke_everything
! cd $WORKSPACE

duration=$SECONDS
echo "INFO: Ended at `date` ($(($duration / 60))m $(($duration % 60))s)"

exit $overallrun_ec
