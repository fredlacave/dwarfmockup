@echo off
setlocal EnableDelayedExpansion

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

rem TODO: move the imagick dlls to a vendor subfolder
rem       there's a weird line length limitation that cuts the %OPT% var at 1017 chars.

DEL %TF%* 2>nul:

set /A "odd=1"

FOR %%A in (%IM%\*.dll) DO (
  echo %%~nA.dll
  copy %%A %RUBY_HOME%\vendor\%%~nA.dll
  echo|set /p=--dll vendor\%%~nA.dll >> %TF%!odd!
  set /a "odd=odd+2"
  if !odd!==7 (set /a "odd=1")
)

mkdir %RUBY_HOME%\ruby_builtin_dlls
copy %RUBY_HOME%\..\msys64\mingw64\bin\libssp-0.dll %RUBY_HOME%\ruby_builtin_dlls
echo|set /p=--dll ruby_builtin_dlls\libssp-0.dll >> %TF%9
echo|set /p=--dll ruby_builtin_dlls\libgcc_s_seh-1.dll >> %TF%9
echo|set /p=--dll ruby_builtin_dlls\libwinpthread-1.dll >> %TF%9

ruby -pe '$_.gsub!(/\\/, "/")' < %TF%1 > %TF%2
ruby -pe '$_.gsub!(/\\/, "/")' < %TF%3 > %TF%4
ruby -pe '$_.gsub!(/\\/, "/")' < %TF%5 > %TF%6
ruby -pe '$_.gsub!(/\\/, "/")' < %TF%9 > %TF%0

set /P OPT1=<%TF%2
set /P OPT2=<%TF%4
set /P OPT3=<%TF%6
set /P OPTA=<%TF%0

IF "%1"=="-d" (set OPTD=--console --debug --debug-extract) else (set OPTD=--windows)

call ocra --gemfile Gemfile ^
     %OPTD% ^
     %OPT1% ^
     %OPT2% ^
     %OPT3% ^
     %OPTA% ^
     dwarfmockup.rb ^
     Gemfile ^
     Gemfile.lock ^
     res

DEL %TF%* 2>nul:

IF "%1"=="" GOTO End
IF "%1"=="-d" GOTO End
del DwarfMockup-%1.exe 2>nul:
ren DwarfMockup.exe DwarfMockup-%1.exe

:End