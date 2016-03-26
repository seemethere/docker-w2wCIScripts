# Jenkins CI script for Windows to Windows CI cleanup
# By John Howard (@jhowardmsft) January 2016

set +e  # Keep going on errors
set +x 

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
	# Split binary mode. Remove above block when split binary in master
	for PID in $(tasklist | grep dockerd- | awk {'print $2'})
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

	# Detach any VHDs
	! powershell -NoProfile -ExecutionPolicy unrestricted -command 'gwmi msvm_mountedstorageimage -namespace root/virtualization/v2 -ErrorAction SilentlyContinue | foreach-object {$_.DetachVirtualHardDisk() }'
	
	# Stop any compute processes
	! powershell -NoProfile -ExecutionPolicy unrestricted -command 'Get-ComputeProcess | Stop-ComputeProcess -Force'
	
	# Use our really dangerous utility to force zap
	if [[ -e /$TESTRUN_DRIVE/$TESTRUN_SUBDIR ]]; then
		echo "INFO: Nuking /$TESTRUN_DRIVE/$TESTRUN_SUBDIR"
		docker-ci-zap "-folder=$TESTRUN_DRIVE:\\$TESTRUN_SUBDIR"
	fi
	
	echo "INFO: End of cleanup"
}

export ver=$(reg query "HKLM\Software\Microsoft\Windows NT\CurrentVersion" | grep BuildLabEx | awk '{print $3}')
! nuke_everything
true