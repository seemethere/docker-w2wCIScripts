REM This version is for the CI servers

#robocopy e:\go\src\github.com\docker\docker c:\gopath\src\github.com\docker\docker /mir

set SOURCES_DRIVE=c
set SOURCES_SUBDIR=gopath

set TESTRUN_DRIVE=c
set TESTRUN_SUBDIR=CI

sh ./doit.sh