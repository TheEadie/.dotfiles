$global:DefaultUser = [System.Environment]::UserName

Import-Module posh-git
Import-Module oh-my-posh
Set-Theme Paradox

Set-Alias -Name Install-WormsCli -Value C:\Users\work\AppData\Local\Programs\Worms\.update\Install.ps1
