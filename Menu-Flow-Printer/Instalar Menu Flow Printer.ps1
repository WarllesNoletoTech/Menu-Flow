$ErrorActionPreference = 'Stop'
$source = $PSScriptRoot
$target = Join-Path $env:LOCALAPPDATA 'MenuFlowPrinter'
New-Item -ItemType Directory -Path $target -Force | Out-Null
Copy-Item (Join-Path $source 'MenuFlowPrinter.ps1') (Join-Path $target 'MenuFlowPrinter.ps1') -Force
$ps = (Get-Command powershell.exe).Source
$arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $target 'MenuFlowPrinter.ps1') + '"'
$ws = New-Object -ComObject WScript.Shell

$startup = [Environment]::GetFolderPath('Startup')
$startupLink = Join-Path $startup 'Menu Flow Printer.lnk'
$sc = $ws.CreateShortcut($startupLink)
$sc.TargetPath = $ps
$sc.Arguments = $arguments
$sc.WorkingDirectory = $target
$sc.WindowStyle = 7
$sc.Description = 'Menu Flow Printer'
$sc.Save()

$desktop = [Environment]::GetFolderPath('Desktop')
$desktopLink = Join-Path $desktop 'Menu Flow Printer.lnk'
$ds = $ws.CreateShortcut($desktopLink)
$ds.TargetPath = $ps
$ds.Arguments = $arguments
$ds.WorkingDirectory = $target
$ds.WindowStyle = 7
$ds.Description = 'Menu Flow Printer'
$ds.Save()

Start-Process $ps -ArgumentList $arguments
Write-Host 'Menu Flow Printer instalado com sucesso.' -ForegroundColor Green
Write-Host 'Ele iniciara automaticamente com o Windows e tambem foi criado um atalho na Area de Trabalho.'
