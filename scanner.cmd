@echo off
setlocal
set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"
opam exec -- dune exec src/main.exe -- %*
endlocal
