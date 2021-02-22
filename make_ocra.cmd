@echo off

SET TF=%TEMP%\__RUBYENV
DEL %TF% 2>nul:

gem environment | ruby -ne 'puts $_.gsub(/.*: (.*)$/, "\\1").gsub(/\//, "\\") if $_ =~ /^\s*- EXECUTABLE DIRECTORY/' > %TF%
set /p RUBY_HOME=<%TF%

DEL %TF% 2>nul:

:HOMEOK

FOR /D %%A in (vendor\*) DO (
  set IM=%%A
  GOTO :NEXT
)

:NEXT

DEL %TF% 2>nul:

FOR %%A in (%IM%\*.dll) DO (
  echo %%~nA.dll
  copy %%A %RUBY_HOME%\%%~nA.dll
  echo|set /p=--dll %%~nA.dll >> %TF%
)

ruby -pe '$_.gsub!(/\\/, "/")' < %TF% > %TF%2

set /P OPT=<%TF%2
DEL %TF% 2>nul:
DEL %TF%2 2>nul:

call ocra --gemfile Gemfile --windows ^
     %OPT% ^
     dwarfmockup.rb ^
     Gemfile ^
     Gemfile.lock ^
     res

IF "%1"=="" GOTO End
del DwarfMockup-%1.exe 2>nul:
ren DwarfMockup.exe DwarfMockup-%1.exe

:End