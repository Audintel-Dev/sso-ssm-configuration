@echo off

powershell.exe -ExecutionPolicy Bypass -Command "db-connect %1"

timeout /t 5 /nobreak > nul