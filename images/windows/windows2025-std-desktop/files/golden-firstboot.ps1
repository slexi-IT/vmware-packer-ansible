# First boot of a VM made from the golden image (started by SetupComplete.cmd, as SYSTEM).
# Make sure the built-in Administrator stays disabled with a password nobody knows.
Add-Type -AssemblyName System.Web
$pw = ConvertTo-SecureString ([System.Web.Security.Membership]::GeneratePassword(32, 8)) -AsPlainText -Force
Set-LocalUser -Name Administrator -Password $pw
Disable-LocalUser -Name Administrator
Write-Output "golden-firstboot done $(Get-Date -Format o)"
