@echo off
REM Wrapper script to perform a local run of CI assuming everything is already setup.
REM This is set for the CI servers. The TP5+ servers should be pre-configured with these
REM variables already - the C drive is the system drive, D is a fast SSD.

REM set SOURCES_DRIVE=c
REM set SOURCES_SUBDIR=gopath
REM set TESTRUN_DRIVE=d
REM set TESTRUN_SUBDIR=CI

sh ./executeCI.sh
