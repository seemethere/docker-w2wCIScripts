REM This version is for the CI servers

set GOROOT=e:\go\
set PATH=e:\go\bin;%path%

set TESTROOT=

rem new ones to work with
set SOURCES_DRIVE=e
set SOURCES_SUBDIR=gopath

set TESTRUN_DRIVE=e
set TESTRUN_SUBDIR=CI

robocopy c:\go e:\go /mir
robocopy c:\gopath e:\gopath /mir

sh ./doit.sh