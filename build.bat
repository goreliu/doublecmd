@echo off

rem Add Lazarus installation to path
if [%LAZARUS_HOME%] == [] set LAZARUS_HOME=D:\Alexx\Prog\FreePascal\Lazarus
set PATH=%LAZARUS_HOME%;%PATH%

rem You can execute this script with different parameters:
rem components - compiling components needed for doublecmd
rem doublecmd - compiling doublecmd only (release mode)
rem plugins - compiling all doublecmd plugins
rem debug - compiling components, plugins and doublecmd (debug mode)
rem release - compile in release mode (using by default)
if not "%OS_TARGET%" == "" (
  set DC_ARCH=%DC_ARCH% --os=%OS_TARGET%
)
if not "%CPU_TARGET%" == "" (
  set DC_ARCH=%DC_ARCH% --cpu=%CPU_TARGET%
)
if not "%LCL_PLATFORM%" == "" (
  set DC_ARCH=%DC_ARCH% --ws=%LCL_PLATFORM%
)

if "%1"=="components" ( call :components
) else (
if "%1"=="plugins" ( call :plugins
) else (
if "%1"=="beta" ( call :release
) else (
if "%1"=="doublecmd" ( call :doublecmd
) else (
if "%1"=="release" ( call :release
) else (
if "%1"=="darkwin" ( call :darkwin
) else (
if "%1"=="debug" ( call :debug
) else (
if "%1"=="" ( call :release
) else (
  echo ERROR: Mode not defined: %1
  echo Available modes: components, plugins, doublecmd, release, darkwin, debug
))))))))

GOTO:EOF

:components
  call components\build.bat
GOTO:EOF

:plugins
  call plugins\build.bat
GOTO:EOF

:release
  call :remove_old
  call :components
  call :plugins
  call :doublecmd
GOTO:EOF

:debug
  call :remove_old
  call :components
  call :plugins

  rem Build Double Commander
  call :replace_old
  lazbuild src\doublecmd.lpi --bm=debug %DC_ARCH%
GOTO:EOF

:doublecmd
  call :remove_old_doublecmd
  rem Build Double Commander
  call :replace_old
  lazbuild src\doublecmd.lpi --bm=release %DC_ARCH%

  call :extract
GOTO:EOF

:darkwin
  call :remove_old
  call :components
  call :plugins

  rem Build Double Commander
  call :replace_old
  lazbuild src\doublecmd.lpi --bm=darkwin %DC_ARCH%

  call :extract
GOTO:EOF

:extract
  rem Build Dwarf LineInfo Extractor
  lazbuild tools\extractdwrflnfo.lpi

  rem Extract debug line info
  tools\extractdwrflnfo doublecmd.dbg
GOTO:EOF

:remove_old
  call :remove_old_components
  call :remove_old_plugins
  call :remove_old_doublecmd
GOTO:EOF

:remove_old_components
GOTO:EOF

:remove_old_plugins
  del /Q /S plugins\wcx\base64\lib\*.ppu plugins\wcx\base64\lib\*.o 2>NUL
  del /Q /S plugins\wcx\cpio\lib\*.ppu plugins\wcx\cpio\lib\*.o 2>NUL
  del /Q /S plugins\wcx\deb\lib\*.ppu plugins\wcx\deb\lib\*.o 2>NUL
  del /Q /S plugins\wcx\rpm\lib\*.ppu plugins\wcx\rpm\lib\*.o 2>NUL
  del /Q /S plugins\wcx\sevenzip\lib\*.ppu plugins\wcx\sevenzip\lib\*.o 2>NUL
  del /Q /S plugins\wcx\unrar\lib\*.ppu plugins\wcx\unrar\lib\*.o 2>NUL
  del /Q /S plugins\wcx\zip\lib\*.ppu plugins\wcx\zip\lib\*.o 2>NUL
  del /Q /S plugins\wdx\rpm_wdx\lib\*.ppu plugins\wdx\rpm_wdx\lib\*.o 2>NUL
  del /Q /S plugins\wdx\deb_wdx\lib\*.ppu plugins\wdx\deb_wdx\lib\*.o 2>NUL
  del /Q /S plugins\wdx\audioinfo\lib\*.ppu plugins\wdx\audioinfo\lib\*.o 2>NUL
  del /Q /S plugins\wfx\ftp\lib\*.ppu plugins\wfx\ftp\lib\*.o 2>NUL
  del /Q /S plugins\wlx\wmp\lib\*.ppu plugins\wlx\wmp\lib\*.o 2>NUL
  del /Q /S plugins\wlx\preview\lib\*.ppu plugins\wlx\preview\lib\*.o 2>NUL
  del /Q /S plugins\wlx\richview\lib\*.ppu plugins\wlx\richview\lib\*.o 2>NUL

  del /Q /S plugins\*.dsx 2>NUL
  del /Q /S plugins\*.w?x 2>NUL
GOTO:EOF

:remove_old_doublecmd
  del /Q units\i386-win32-win32\*.ppu units\i386-win32-win32\*.o 2>NUL
  del /Q units\x86_64-win64-win32\*.ppu units\x86_64-win64-win32\*.o 2>NUL

  del /Q doublecmd.dbg 2>NUL
  del /Q doublecmd.zdli 2>NUL
GOTO:EOF

:replace_old
  del /Q doublecmd.exe.old
  ren doublecmd.exe doublecmd.exe.old
GOTO:EOF
