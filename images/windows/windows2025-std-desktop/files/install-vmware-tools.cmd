@echo off
rem First logon of the build VM (autounattend.xml): install VMware Tools from the ESXi tools CD,
rem then power off. Packer waits for the power-off; Ansible then works through VMware Tools.
for %%d in (D E F G H) do if exist %%d:\setup64.exe set TOOLS=%%d:
if not defined TOOLS (
  echo VMware Tools CD not found > C:\Windows\Temp\vmware-tools.log
  exit /b 1
)
%TOOLS%\setup64.exe /s /v"/qn REBOOT=R /l*v C:\Windows\Temp\vmware-tools.log"
shutdown /s /t 30 /c "VMware Tools installed; handing over to Ansible"
