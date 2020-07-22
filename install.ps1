# Run as admin (Can only create links as Admin)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit 
}

$CurrentDirectory = $PSScriptRoot
$HomeDirectory = $env:UserProfile
$WindowsTerminalConfigDirectory = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"


Write-Output $CurrentDirectory

# Git
New-Item -ItemType SymbolicLink -Path (Join-Path $HomeDirectory ".gitconfig") -Target (Join-Path $CurrentDirectory "git/.gitconfig")
New-Item -ItemType SymbolicLink -Path (Join-Path $HomeDirectory ".gitconfig.windows") -Target (Join-Path $CurrentDirectory "git/.gitconfig.windows")

# Windows Terminal
New-Item -ItemType SymbolicLink -Path (Join-Path $WindowsTerminalConfigDirectory "settings.json") -Target (Join-Path $CurrentDirectory "terminals/windows-terminal/settings.json")

# PowerShell Profile
New-Item -ItemType SymbolicLink -Path (Join-Path $HomeDirectory "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1") -Target (Join-Path $CurrentDirectory "powershell/Microsoft.PowerShell_profile.ps1")

Read-Host