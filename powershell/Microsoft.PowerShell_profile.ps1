$global:DefaultUser = [System.Environment]::UserName

Import-Module posh-git
Import-Module oh-my-posh
Set-PoshPrompt -Theme Paradox

Invoke-Expression (&starship init powershell)

Set-Alias -Name Install-WormsCli -Value C:\Users\david.eadie\AppData\Local\Programs\Worms\.update\Install.ps1
