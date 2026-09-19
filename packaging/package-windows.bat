@echo off
rem
rem Builds the redistributable Windows binary and packages it into dist\
rem
rem Must be run from an "x64 Native Tools Command Prompt for VS 2022". The plain "Developer
rem Command Prompt" and the x86 one both target 32-bit, which compiles but then fails to link
rem with "machine type x86 conflicts with x64". It also needs editbin and dumpbin, which only
rem that shell puts on the PATH.
rem
rem Swift on Windows has no static runtime, so the whole runtime DLL set travels with the
rem executable. That folder already includes the VC redistributable DLLs, so the ZIP is
rem self-contained and needs no separate redist install on the target machine.

setlocal enabledelayedexpansion

if /i not "%VSCMD_ARG_TGT_ARCH%"=="x64" (
    echo error: this must be run from an x64 Native Tools Command Prompt for VS 2022.
    echo        current target architecture is "%VSCMD_ARG_TGT_ARCH%".
    exit /b 1
)

where editbin >nul 2>&1 || (echo error: editbin not found on PATH. & exit /b 1)
where dumpbin >nul 2>&1 || (echo error: dumpbin not found on PATH. & exit /b 1)
where llvm-objcopy >nul 2>&1 || (echo error: llvm-objcopy not found on PATH ^(install the Swift toolchain^). & exit /b 1)

cd /d "%~dp0.."

for /f "tokens=2 delims=[]" %%v in ('findstr /c:"versionNumbers = [" Sources\trailer\Core\Config.swift') do set VERRAW=%%v
if "%VERRAW%"=="" (echo error: could not read the version from Sources\trailer\Core\Config.swift & exit /b 1)
set VERSION=%VERRAW: =%
set VERSION=%VERSION:,=.%

set NAME=trailer-%VERSION%-windows-x86_64
set STAGE=%CD%\dist\%NAME%

echo ==^> Building %NAME%
call swift build -c release -Xswiftc -Ounchecked || exit /b 1
for /f "delims=" %%i in ('swift build -c release --show-bin-path') do set BIN=%%i

rem Pick the highest-numbered installed Swift runtime.
set RTROOT=%LOCALAPPDATA%\Programs\Swift\Runtimes
set RT=
for /f "delims=" %%i in ('dir /b /ad /o-n "%RTROOT%" 2^>nul') do (
    if not defined RT set RT=%RTROOT%\%%i\usr\bin
)
if not defined RT (echo error: no Swift runtime found under "%RTROOT%" & exit /b 1)
echo     runtime: %RT%

echo ==^> Staging
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%"
copy /y "%BIN%\trailer.exe" "%STAGE%\" >nul || exit /b 1
copy /y LICENSE "%STAGE%\" >nul || exit /b 1
copy /y "%RT%\*.dll" "%STAGE%\" >nul || exit /b 1

rem Strip first: llvm-objcopy rewrites the executable, which would discard the stack setting.
rem `-Xswiftc -gnone` does not prevent the debug sections, so stripping is the only thing that
rem shrinks the executable (roughly 5.4MB down to 1.3MB).
llvm-objcopy --strip-all "%STAGE%\trailer.exe" || exit /b 1

rem extendStackSizeIfNeeded() in mainasync.swift skips the setrlimit path on Windows, so the
rem 32MB stack every other platform gets at runtime has to be baked in here instead.
editbin /nologo /stack:24117248 "%STAGE%\trailer.exe" || exit /b 1

echo ==^> Verifying
dumpbin /nologo /headers "%STAGE%\trailer.exe" | findstr /c:"size of stack reserve"
dumpbin /nologo /headers "%STAGE%\trailer.exe" | findstr /c:"1700000 size of stack reserve" >nul || (
    echo error: stack reserve was not set to 24117248.
    exit /b 1
)

rem Launch with a minimal PATH, which proves the Swift DLLs resolve from the executable's own
rem directory. Note this does not prove the VC redist DLLs are bundled, since the executable's
rem directory wins over System32 in the search order either way.
cmd /c "set PATH=C:\Windows\System32&& "%STAGE%\trailer.exe" -mono -version" | findstr /c:"%VERSION%" >nul || (
    echo error: packaged executable did not report version %VERSION%.
    exit /b 1
)

echo ==^> Packaging
if exist "dist\%NAME%.zip" del "dist\%NAME%.zip"
tar -a -c -f "dist\%NAME%.zip" -C "dist" "%NAME%" || exit /b 1
rmdir /s /q "%STAGE%"

certutil -hashfile "dist\%NAME%.zip" SHA256
dir "dist\%NAME%.zip"

endlocal
