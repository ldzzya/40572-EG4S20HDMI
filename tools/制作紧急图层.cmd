@echo off
set "WARNING_PYTHON=C:\Users\87842\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if exist "%WARNING_PYTHON%" (
 "%WARNING_PYTHON%" -X utf8 "%~dp0prepare_warning.py"
) else (
 py -3 "%~dp0prepare_warning.py"
)
if errorlevel 1 pause

