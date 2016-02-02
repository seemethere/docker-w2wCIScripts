REM This version is for the CI servers

set GOROOT=d:\go\
set PATH=d:\go\bin;%path%

set TESTROOT=

rem new ones to work with
set SOURCES_DRIVE=d
set SOURCES_SUBDIR=gopath

set TESTRUN_DRIVE=d
set TESTRUN_SUBDIR=CI

robocopy c:\go d:\go /mir
robocopy c:\gopath d:\gopath /mir

sh ./doit.sh