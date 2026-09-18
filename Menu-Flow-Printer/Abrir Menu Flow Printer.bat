@echo off
cd /d "%~dp0"
start "Menu Flow Printer" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0MenuFlowPrinter.ps1"
