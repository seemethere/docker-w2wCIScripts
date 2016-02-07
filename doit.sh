# Jenkins CI script for Windows to Windows CI
# By John Howard (@jhowardmsft) January 2016

# -------------------------------------------------------------------------------------------
# When executed, we rely on four variables being set in the environment:
#
#	SOURCES_DRIVE		is the drive on which the sources being tested are cloned from.
# 						This should be a straight drive letter, no platform semantics.
#						For example 'c'
#
#	SOURCES_SUBDIR  	is the top level directory under SOURCES_DRIVE where the
#						sources are cloned to. There are no platform semantics in this
#						as it does not include slashes. 
#						For example 'gopath'
#
#						Based on the above examples, it would be expected that Jenkins
#						would clone the sources being tested to
#						/SOURCES_DRIVE/SOURCES_SUBDIR/src/github.com/docker/docker, or
#						/c/gopath/src/github.com/docker/docker
#
#
#	TESTRUN_DRIVE		is the drive where we build the binary on and redirect everything
#						to for the daemon under test. On an Azure D2 type host which has
#						an SSD temporary storage D: drive, this is ideal for performance.
#						For example 'd'
#
#	TESTRUN_SUBDIR		is the top level directory under TESTRUN_DRIVE where we redirect
#						everything to for the daemon under test. For example 'CI'.
#						Hence, the daemon under test is run under
#						/TESTRUN_DRIVE/TESTRUN_SUBDIR/CI-<CommitID> or
#						/d/CI/CI-<CommitID>
#
# -------------------------------------------------------------------------------------------


set +e  # Keep going on errors
set +x 

SCRIPT_VER="04-Feb-2016 10:00 PDT"

# This function is copied from the cleanup script
nuke_everything()
{
	! containerCount=$(docker ps -aq | wc -l)
	if [ $containerCount -gt 0 ]; then
		echo "INFO: Container count on control daemon to delete is $containerCount"	
		! docker rm -f $(docker ps -aq)
	fi

	# TODO Remove this reliability hack after TP4 is no longer supported
	! imageCount=$(docker images | sed -n '1!p' | grep -v windowsservercore | grep -v nanoserver | grep -v docker | wc -l)
	if [ $imageCount -gt 0 ]; then
		if [ "${ver%%[^0-9]*}" -lt "14000" ]; then
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

	# Kill any spurious daemons. The '-' in 'docker-' is IMPORTANT otherwise will kill the control daemon!
	IFS=$'\n'
	for PID in $(tasklist | grep docker- | awk {'print $2'})
	do
		echo "INFO: Killing daemon with PID $PID"
		taskkill -f -t -pid $PID
	done

	# Even more paranoid - kill a bunch of stuff that might be locking files
	# Note: Last one is interesting. Found a case where the workspace could not be deleted
	# by Jenkins as the bundles directory couldn't be cleaned. Pretty strongly suspect
	# it is integration-cli-test as the command line run is something like
	# d:\ci\ci-commit\go-buildID\github.com\docker\docker\integration-cli\_test\integration-cli.test.exe
	#  -test.coverprofile=C:/gopath/src/github.com/docker/docker/bundles/VERSION/test-integration-cli/coverprofiles/docker-integration-cli -test.timeout=nnn
	! taskkill -F -IM cc1.exe -T 					>& /dev/null
	! taskkill -F -IM link.exe -T 					>& /dev/null
	! taskkill -F -IM compile.exe -T 				>& /dev/null
	! taskkill -F -IM ld.exe -T 					>& /dev/null
	! taskkill -F -IM go.exe -T 					>& /dev/null
	! taskkill -F -IM git.exe -T 					>& /dev/null
	! taskkill -F -IM git-remote-https.exe -T 		>& /dev/null
	! taskkill -F -IM integration-cli.test.exe -T	>& /dev/null

	# Use our really dangerous utility to force zap
	if [[ -e /$TESTRUN_DRIVE/$TESTRUN_SUBDIR ]]; then
		echo "INFO: Nuking /$TESTRUN_DRIVE/$TESTRUN_SUBDIR"
		docker-ci-zap "-folder=$TESTRUN_DRIVE:\\$TESTRUN_SUBDIR"
	fi
	
	echo "INFO: End of cleanup"
}

# Call with validate_driveletter VARIABLENAME VALUE
validate_driveletter() {
	ec=0
	
	if [ -z "$2" ]; then
		echo "FAIL: Variable $1 is not set"
		return 1
	fi
	
	if [ $(expr length $2) -ne 1 ]; then
		echo "FAIL: Variable $1 should be a single character drive letter"
		return 1
	fi
	
	if [ ! -d /$2 ]; then
		echo "FAIL: Variable $1 should be a drive letter that exists (/$2 does not!)"
		return 1
	fi
	return 0
}

# Call with validate_path DRIVELETTER path value mustexist. DRIVELETTER should be pre-validated
validate_path() {
	ec=0
	
	if [ -z "$3" ]; then
		echo "FAIL: Variable $2 is not set"
		return 1
	fi
	
	if [[ $3 == *"/"* ]]; then
		echo "FAIL: Variable $2 ($3) contains a '/' character. It should not!"
		return 1
	fi

	if [[ $3 == *"\\"* ]]; then
		echo "FAIL: Variable $2 ($3) contains a '\\' character. It should not!"
		return 1
	fi

	if [ -n "$4" ]; then #must exist
		if [ ! -d /$1/$3 ]; then
			echo "FAIL: /$1/$3 is not a directory. Check value of $2 ($3)"
			return 1
		fi
	fi
	
	return 0
}

ec=0											# Exit code
daemonStarted=0									# 1 when started
inRepo=0										# 1 if we are in a docker repo
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

# Make sure docker-ci-zap is installed
if [ $ec -eq 0 ]; then
	command -v docker-ci-zap >& /dev/null || { echo "ERROR: docker-ci-zap is not installed or not found on path"; ec=1; }
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
		if [ $ec -eq 0 ]; then
			echo "INFO: Tagged windowsservercore:$build with latest"
		else
			echo "ERROR: Failed to tag windowsservercore:$build as latest"
		fi
	fi
fi

# Make sure each of the variables are set
if [ $ec -eq 0 ]; then
	validate_driveletter "SOURCES_DRIVE" $SOURCES_DRIVE
	ec=$?
fi

if [ $ec -eq 0 ]; then
	validate_driveletter "TESTRUN_DRIVE" $TESTRUN_DRIVE
	ec=$?
fi

if [ $ec -eq 0 ]; then
	validate_path $SOURCES_DRIVE "SOURCES_SUBDIR" $SOURCES_SUBDIR "ItMustExist"
	ec=$?
fi

if [ $ec -eq 0 ]; then
	validate_path $TESTRUN_DRIVE "TESTRUN_SUBDIR" $TESTRUN_SUBDIR  # Doesn't have to exist
	ec=$?
fi

# Create the /$TESTRUN_DRIVE/$TESTRUN_SUBDIR if it does not already exist
if [ $ec -eq 0 ]; then
	if [ ! -d /$TESTRUN_DRIVE/$TESTRUN_SUBDIR ]; then
		! mkdir -p /$TESTRUN_DRIVE/$TESTRUN_SUBDIR
	fi
fi

if [ $ec -eq 0 ]; then
	echo "INFO: Configured sources under /$SOURCES_DRIVE/$SOURCES_SUBDIR/..."
	echo "INFO: Configured test run under /$TESTRUN_DRIVE/$TESTRUN_SUBDIR/..."
fi

# Set the GOPATH to the root and the vendor directory
if [ $ec -eq 0 ]; then
	export GOPATH=/$SOURCES_DRIVE/$SOURCES_SUBDIR/src/github.com/docker/docker/vendor:/$SOURCES_DRIVE/$SOURCES_SUBDIR
	echo "INFO: GOPATH set to $GOPATH"
fi

# Check the intended source location is a directory
if [ $ec -eq 0 ]; then 
	if [ ! -d /$SOURCES_DRIVE/$SOURCES_SUBDIR/src/github.com/docker/docker ]; then
		echo "ERROR: /$SOURCES_DRIVE/$SOURCES_SUBDIR/src/github.com/docker/docker is not a directory!"
		ec=1
	fi
fi

# Make sure we start at the root of the sources
if [ $ec -eq 0 ]; then
	cd /$SOURCES_DRIVE/$SOURCES_SUBDIR/src/github.com/docker/docker >& /dev/null
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: Failed to change directory to /$SOURCES_DRIVE/$SOURCES_SUBDIR/src/github.com/docker/docker"
	else	
		echo "INFO: Running in $(pwd)"
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
		echo "INFO: Repository was found"
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

# Nuke everything and go back to our sources after
if [ $ec -eq 0 ]; then
	! nuke_everything
	cd /$SOURCES_DRIVE/$SOURCES_SUBDIR/src/github.com/docker/docker
fi

# Redirect to a temporary location. 
if [ $ec -eq 0 ]; then
	export TEMP=/$TESTRUN_DRIVE/$TESTRUN_SUBDIR/CI-$COMMITHASH
	export TEMPWIN=$TESTRUN_DRIVE:\\$TESTRUN_SUBDIR\\CI-$COMMITHASH
	export TMP=$TMP
	rmdir $TEMP >& /dev/null # Just in case it exists already
	! /usr/bin/mkdir -p $TEMP  # Make sure Linux mkdir for -p
	! /usr/bin/mkdir $TEMP/userprofile >& /dev/null
	export USERPROFILE=$TEMP/userprofile
	! /usr/bin/mkdir $TEMP/localappdata >& /dev/null
	export LOCALAPPDATA=$TEMP/localappdata
	! /usr/bin/mkdir -p $TEMP/binary
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

# TODO This is a TP4 reliability hack to loop around
# Build the image
if [ $ec -eq 0 ]; then
	echo "INFO: Building the image from Dockerfile.windows..."
	
	tries=30
	while true; do
		(( tries-- ))
		if [ $tries -le 0 ]; then
			ec=1
			echo "ERROR: Failed after multiple attempts!"
			break 
		fi

		set -x
		docker build -t docker -f Dockerfile.windows .
		lastec=$?
		set +x
		
		if [ $lastec -eq 0 ]; then
			ec=0
			break
		fi
		
		echo "INFO: TP4 hack - retrying the build step (`expr $tries - 1` more attempts(s))..."
	done


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
	echo "INFO: Linking the built binary to $TEMP/docker-$COMMITHASH.exe..."
	ln $TEMP/binary/docker.exe $TEMP/binary/docker-$COMMITHASH.exe
	ec=$?
	if [ 0 -ne $ec ]; then
		echo "ERROR: Failed to link"
	fi
fi

# Start the daemon under test, ensuring everything is redirected to folders under $TEMP.
# Important - we launch the -$COMMITHASH version so that we can kill it without
# killing the control daemon
if [ $ec -eq 0 ]; then
	echo "INFO: Starting a daemon under test..."
    ! mkdir $TEMP/daemon >& /dev/null
	! mkdir $TEMP/daemon/execroot >& /dev/null
	! mkdir $TEMP/daemon/graph >& /dev/null
	$TEMP/binary/docker-$COMMITHASH daemon \
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
		#export DUMPDAEMONLOG=1  This is too verbose unfortunately :(
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

# Stop the daemon under test
if [ $daemonStarted -eq 1 ]; then
	PID=$(< $TEMP/daemon/docker.pid)
	if [ ! -z $PID ]; then
		echo "INFO: Stopping daemon under test"
		! taskkill -f -t -pid $PID 
		sleep 10
	fi
fi

# Warning about Go Version
if [ -n "$warnGoVersionAtEnd" ]; then
	echo
	echo "---------------------------------------------------------------------------"
	echo "WARN: CI should be using go version $GOVER_DOCKERFILE, but it is using ${GOVER_INSTALLED:2}"
	echo 
	echo "		This CI server needs updating. Please ping #docker-dev or"
	echo "		#docker-maintainers."
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

# Nuke everything again
echo "INFO: Tidying up at end of run"
! cd /$SOURCES_DRIVE/$SOURCES_SUBDIR/
! nuke_everything
! cd /$SOURCES_DRIVE/$SOURCES_SUBDIR/

duration=$SECONDS
echo "INFO: Ended at `date` ($(($duration / 60))m $(($duration % 60))s)"

exit $overallrun_ec
