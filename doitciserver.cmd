REM This version is for the CI servers

rem set TESTROOT=/c/gopath
set TESTROOT=

rem new ones to work with
set SOURCES_DRIVE=c
set SOURCES_SUBDIR=gopath

set TESTRUN_DRIVE=d
set TESTRUN_SUBDIR=CI

sh ./doit.sh