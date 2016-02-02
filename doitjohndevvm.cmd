REM This version is for the CI servers

robocopy e:\go\src\github.com\docker\docker c:\go\src\github.com\docker\docker /mir

set SOURCES_DRIVE=c
set SOURCES_SUBDIR=go

set TESTRUN_DRIVE=c
set TESTRUN_SUBDIR=CI

sh ./doit.sh