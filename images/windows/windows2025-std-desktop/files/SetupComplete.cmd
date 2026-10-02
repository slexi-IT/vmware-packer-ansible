@echo off
rem Run by Windows setup once, as SYSTEM, on the first boot of every VM made from the golden image
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\golden-firstboot.ps1 > C:\Windows\Setup\Scripts\golden-firstboot.log 2>&1
