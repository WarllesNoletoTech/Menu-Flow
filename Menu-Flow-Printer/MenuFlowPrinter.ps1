# Menu Flow Printer - agente Windows sem dependencias externas.
# Requer Windows PowerShell 5.1+ e uma impressora instalada no Windows.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppDataDir = Join-Path $env:APPDATA 'MenuFlowPrinter'
$script:ConfigFile = Join-Path $script:AppDataDir 'config.json'
$script:Busy = $false
$script:LastPrinted = $null
$script:LastError = $null
New-Item -ItemType Directory -Path $script:AppDataDir -Force | Out-Null

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class MenuFlowRawPrinter {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Ansi)]
  public class DOCINFOA {
    [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
  }
  [DllImport("winspool.Drv", EntryPoint="OpenPrinterA", SetLastError=true, CharSet=CharSet.Ansi, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)] public static extern bool OpenPrinter(string szPrinter, out IntPtr hPrinter, IntPtr pd);
  [DllImport("winspool.Drv", EntryPoint="ClosePrinter", SetLastError=true, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)] public static extern bool ClosePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint="StartDocPrinterA", SetLastError=true, CharSet=CharSet.Ansi, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)] public static extern bool StartDocPrinter(IntPtr hPrinter, Int32 level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);
  [DllImport("winspool.Drv", EntryPoint="EndDocPrinter", SetLastError=true, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)] public static extern bool EndDocPrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint="StartPagePrinter", SetLastError=true, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)] public static extern bool StartPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint="EndPagePrinter", SetLastError=true, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)] public static extern bool EndPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint="WritePrinter", SetLastError=true, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)] public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, Int32 dwCount, out Int32 dwWritten);
  public static void Send(string printer, byte[] bytes) {
    IntPtr h;
    if (!OpenPrinter(printer, out h, IntPtr.Zero)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    try {
      var d = new DOCINFOA(); d.pDocName = "Menu Flow"; d.pDataType = "RAW";
      if (!StartDocPrinter(h, 1, d)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
      try {
        if (!StartPagePrinter(h)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        IntPtr p = Marshal.AllocCoTaskMem(bytes.Length);
        try {
          Marshal.Copy(bytes, 0, p, bytes.Length);
          int written;
          if (!WritePrinter(h, p, bytes.Length, out written)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        } finally { Marshal.FreeCoTaskMem(p); }
        EndPagePrinter(h);
      } finally { EndDocPrinter(h); }
    } finally { ClosePrinter(h); }
  }
}
"@

function New-DefaultConfig {
  [pscustomobject]@{
    apiUrl = ''
    token = ''
    kitchenPrinter = ''
    barPrinter = ''
    cashierPrinter = ''
    sharedProductionPrinter = $true
    deviceName = $env:COMPUTERNAME
    deviceId = 'mfp-' + [Guid]::NewGuid().ToString('N')
    enabled = $true
    testMode = $false
    testPaperWidth = 80
    testFolder = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Menu Flow Printer\Testes')
  }
}

function Load-MenuFlowConfig {
  if (!(Test-Path $script:ConfigFile)) { return New-DefaultConfig }
  try {
    $cfg = Get-Content $script:ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if (!$cfg.deviceId) { $cfg | Add-Member -NotePropertyName deviceId -NotePropertyValue ('mfp-' + [Guid]::NewGuid().ToString('N')) -Force }
    if ($null -eq $cfg.enabled) { $cfg | Add-Member -NotePropertyName enabled -NotePropertyValue $true -Force }
    if ($null -eq $cfg.sharedProductionPrinter) { $cfg | Add-Member -NotePropertyName sharedProductionPrinter -NotePropertyValue $true -Force }
    if ($null -eq $cfg.barPrinter) { $cfg | Add-Member -NotePropertyName barPrinter -NotePropertyValue '' -Force }
    if ($null -eq $cfg.testMode) { $cfg | Add-Member -NotePropertyName testMode -NotePropertyValue $false -Force }
    if ($null -eq $cfg.testPaperWidth) { $cfg | Add-Member -NotePropertyName testPaperWidth -NotePropertyValue 80 -Force }
    if ([string]::IsNullOrWhiteSpace([string]$cfg.testFolder)) { $cfg | Add-Member -NotePropertyName testFolder -NotePropertyValue (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Menu Flow Printer\Testes') -Force }
    return $cfg
  } catch { return New-DefaultConfig }
}

function Save-MenuFlowConfig($cfg) {
  $cfg | ConvertTo-Json -Depth 4 | Set-Content $script:ConfigFile -Encoding UTF8
}

$script:Config = Load-MenuFlowConfig
Save-MenuFlowConfig $script:Config

function Get-PrinterNames {
  try { return @(Get-Printer -ErrorAction Stop | Sort-Object Name | Select-Object -ExpandProperty Name) }
  catch {
    try {
      return @([System.Drawing.Printing.PrinterSettings]::InstalledPrinters | ForEach-Object { [string]$_ })
    } catch { return @() }
  }
}

function Join-ByteArrays([byte[][]]$Arrays) {
  $length = 0
  foreach ($a in $Arrays) { $length += $a.Length }
  $result = New-Object byte[] $length
  $offset = 0
  foreach ($a in $Arrays) { [Array]::Copy($a, 0, $result, $offset, $a.Length); $offset += $a.Length }
  return $result
}

function ConvertTo-EscPosBytes([string]$Text) {
  try { $encoding = [System.Text.Encoding]::GetEncoding(860) }
  catch { $encoding = [System.Text.Encoding]::ASCII }
  $clean = $Text.Replace([char]0x2013, '-').Replace([char]0x2014, '-').Replace([char]0x2022, '*')
  $body = $encoding.GetBytes($clean)
  $init = [byte[]](0x1B,0x40)
  $codePage = [byte[]](0x1B,0x74,0x03)
  $feeds = [byte[]](0x0A,0x0A,0x0A)
  $cut = [byte[]](0x1D,0x56,0x00)
  return Join-ByteArrays @($init,$codePage,$body,$feeds,$cut)
}

function Send-MenuFlowPrint([string]$PrinterName, [string]$Content, [int]$Copies = 1) {
  if ([string]::IsNullOrWhiteSpace($PrinterName)) { throw 'Nenhuma impressora configurada para este setor.' }
  $bytes = ConvertTo-EscPosBytes $Content
  for ($i = 0; $i -lt [Math]::Max(1,$Copies); $i++) { [MenuFlowRawPrinter]::Send($PrinterName, $bytes) }
}

function Get-TestFolder {
  $folder = [string]$script:Config.testFolder
  if ([string]::IsNullOrWhiteSpace($folder)) { $folder = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Menu Flow Printer\Testes' }
  New-Item -ItemType Directory -Path $folder -Force | Out-Null
  return $folder
}

function Get-EdgePath {
  $candidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
  )
  foreach ($candidate in $candidates) { if ($candidate -and (Test-Path $candidate)) { return $candidate } }
  return $null
}

function ConvertTo-HtmlEncoded([string]$Value) {
  return [System.Net.WebUtility]::HtmlEncode($Value)
}

function Save-TestPrint([string]$Type, [string]$Role, [string]$Content, [int]$PaperWidth = 80) {
  $folder = Get-TestFolder
  $paper = if ($PaperWidth -eq 58) { 58 } else { 80 }
  $safeType = ([string]$Type -replace '[^A-Za-z0-9_-]', '_').ToUpperInvariant()
  $safeRole = ([string]$Role -replace '[^A-Za-z0-9_-]', '_').ToUpperInvariant()
  $stamp = (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss-fff')
  $baseName = "$stamp`_${safeRole}_${safeType}_${paper}mm"
  $txtPath = Join-Path $folder ($baseName + '.txt')
  $htmlPath = Join-Path $folder ($baseName + '.html')
  $pdfPath = Join-Path $folder ($baseName + '.pdf')

  $Content | Set-Content -Path $txtPath -Encoding UTF8
  $bodyWidth = if ($paper -eq 58) { 54 } else { 76 }
  $fontSize = if ($paper -eq 58) { 9.3 } else { 10.4 }
  $encoded = ConvertTo-HtmlEncoded $Content
  $html = @"
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>Menu Flow Printer - $safeType</title>
<style>
@page { size: ${paper}mm auto; margin: 0; }
html, body { margin: 0; padding: 0; background: white; }
body { width: ${paper}mm; box-sizing: border-box; padding: 2mm; font-family: Consolas, 'Courier New', monospace; font-size: ${fontSize}pt; line-height: 1.24; color: #111; }
.receipt { width: ${bodyWidth}mm; margin: 0; white-space: pre-wrap; overflow-wrap: normal; word-break: normal; }
</style>
</head>
<body><pre class="receipt">$encoded</pre></body>
</html>
"@
  $html | Set-Content -Path $htmlPath -Encoding UTF8

  $edge = Get-EdgePath
  if ($edge) {
    try {
      $uri = ([System.Uri]$htmlPath).AbsoluteUri
      $args = @('--headless','--disable-gpu','--no-pdf-header-footer',"--print-to-pdf=$pdfPath",$uri)
      Start-Process -FilePath $edge -ArgumentList $args -Wait -WindowStyle Hidden | Out-Null
    } catch {}
  }
  return [pscustomobject]@{ Folder=$folder; Txt=$txtPath; Html=$htmlPath; Pdf=$(if(Test-Path $pdfPath){$pdfPath}else{$null}); Paper=$paper }
}

function Open-TestFolder {
  $folder = Get-TestFolder
  Start-Process explorer.exe $folder
}

function Get-SampleReceipt([string]$Role, [int]$PaperWidth) {
  $w = if ($PaperWidth -eq 58) { 32 } else { 48 }
  $line = '-' * $w
  switch ($Role) {
    'BAR' { return "          MENU FLOW`n        PEDIDO - BAR`n$line`nMesa 07     #MF-1024`nGarcom: Joao`n$line`n2x Coca-Cola Lata`n1x Suco de Maracuja`n  OBS: SEM GELO`n$line`n             BAR`n" }
    'CASHIER' { return "          MENU FLOW`n           PRE-CONTA`n$line`nMesa: Mesa 07`nGarcom: Joao`nPessoas: 3`n$line`n2x X-Bacon             R$ 50,00`n2x Coca-Cola           R$ 12,00`n1x Batata G            R$ 18,00`n$line`nSubtotal                R$ 80,00`nServico 10%              R$ 8,00`n$line`nTOTAL                   R$ 88,00`nSaldo                   R$ 88,00`n$line`n     Esta nao e uma nota fiscal.`n            MENU FLOW`n" }
    default { return "          MENU FLOW`n      PEDIDO - COZINHA`n$line`nMesa 07     #MF-1024`nGarcom: Joao`n$line`n2x X-Bacon`n  + Bacon extra`n  OBS: SEM CEBOLA`n1x Batata Grande`n$line`n           COZINHA`n" }
  }
}

function Invoke-MenuFlowApi([string]$Path, [string]$Method = 'GET', $Body = $null) {
  $base = ([string]$script:Config.apiUrl).TrimEnd('/')
  if (!$base) { throw 'Informe a URL do backend do Menu Flow.' }
  if (!$script:Config.token) { throw 'Informe a chave do Menu Flow Printer.' }
  $headers = @{ 'x-menuflow-printer-token' = [string]$script:Config.token }
  $params = @{ Uri = $base + $Path; Method = $Method; Headers = $headers; TimeoutSec = 15 }
  if ($null -ne $Body) { $params.ContentType = 'application/json'; $params.Body = ($Body | ConvertTo-Json -Depth 8 -Compress) }
  return Invoke-RestMethod @params
}

function Get-ConfiguredRoles {
  if ([bool]$script:Config.testMode) { return @('KITCHEN','BAR','CASHIER') }
  $roles = @()
  if ($script:Config.kitchenPrinter) { $roles += 'KITCHEN' }
  if (($script:Config.sharedProductionPrinter -and $script:Config.kitchenPrinter) -or $script:Config.barPrinter) { $roles += 'BAR' }
  if ($script:Config.cashierPrinter) { $roles += 'CASHIER' }
  return $roles
}

function Get-PrinterForRole([string]$Role) {
  switch ($Role) {
    'KITCHEN' { return [string]$script:Config.kitchenPrinter }
    'BAR' { if ($script:Config.sharedProductionPrinter) { return [string]$script:Config.kitchenPrinter } else { return [string]$script:Config.barPrinter } }
    'CASHIER' { return [string]$script:Config.cashierPrinter }
    default { return '' }
  }
}

function Set-Status([string]$Text, [bool]$IsError = $false) {
  $script:StatusLabel.Text = $Text
  $script:StatusLabel.ForeColor = if ($IsError) { [Drawing.Color]::Firebrick } else { [Drawing.Color]::ForestGreen }
}

function Invoke-Poll {
  if ($script:Busy -or !$script:Config.enabled -or !$script:Config.apiUrl -or !$script:Config.token) { return }
  $roles = @(Get-ConfiguredRoles)
  if ($roles.Count -eq 0) { return }
  $script:Busy = $true
  try {
    $result = Invoke-MenuFlowApi '/printer/agent/claim' 'POST' @{
      deviceId = [string]$script:Config.deviceId
      deviceName = [string]$script:Config.deviceName
      roles = $roles
    }
    $script:LastError = $null
    if ($result.job) {
      $job = $result.job
      try {
        $paper = if ($job.paperWidth -eq 58) { 58 } else { 80 }
        if ([bool]$script:Config.testMode) {
          $preview = Save-TestPrint ([string]$job.type) ([string]$job.printerRole) ([string]$job.content) $paper
          $script:LastPrinted = (Get-Date).ToString('dd/MM/yyyy HH:mm:ss') + ' · TESTE · ' + $job.type + ' · ' + $job.printerRole + ' · ' + $paper + 'mm'
          Invoke-MenuFlowApi ('/printer/agent/jobs/' + $job.id) 'PATCH' @{ deviceId = [string]$script:Config.deviceId; success = $true } | Out-Null
          Set-Status ('Modo de teste · previa salva · ' + $paper + 'mm') $false
          $script:NotifyIcon.ShowBalloonTip(1600, 'Menu Flow Printer', 'Prévia salva em ' + $preview.Folder, [System.Windows.Forms.ToolTipIcon]::Info)
        } else {
          $printer = Get-PrinterForRole ([string]$job.printerRole)
          Send-MenuFlowPrint $printer ([string]$job.content) ([int]$job.copies)
          $script:LastPrinted = (Get-Date).ToString('dd/MM/yyyy HH:mm:ss') + ' · ' + $job.type + ' · ' + $job.printerRole + ' · ' + $paper + 'mm'
          Invoke-MenuFlowApi ('/printer/agent/jobs/' + $job.id) 'PATCH' @{ deviceId = [string]$script:Config.deviceId; success = $true } | Out-Null
          Set-Status ('Conectado · ultima impressao: ' + $script:LastPrinted) $false
          $script:NotifyIcon.ShowBalloonTip(1200, 'Menu Flow Printer', 'Impressão enviada para ' + $printer, [System.Windows.Forms.ToolTipIcon]::Info)
        }
        # Drena rapidamente a fila sem esperar o proximo timer.
        $script:Busy = $false
        Start-Sleep -Milliseconds 100
        Invoke-Poll
        return
      } catch {
        $msg = $_.Exception.Message
        $script:LastError = $msg
        try { Invoke-MenuFlowApi ('/printer/agent/jobs/' + $job.id) 'PATCH' @{ deviceId = [string]$script:Config.deviceId; success = $false; error = $msg } | Out-Null } catch {}
        Set-Status ('Erro de impressao: ' + $msg) $true
        $script:NotifyIcon.ShowBalloonTip(3000, 'Menu Flow Printer', $msg, [System.Windows.Forms.ToolTipIcon]::Error)
      }
    } else {
      Set-Status ('Conectado · aguardando impressoes' + $(if($script:LastPrinted){' · ' + $script:LastPrinted}else{''})) $false
    }
  } catch {
    $script:LastError = $_.Exception.Message
    Set-Status ('Sem conexao: ' + $script:LastError) $true
  } finally { $script:Busy = $false }
}

# --- Interface ---
$form = New-Object Windows.Forms.Form
$form.Text = 'Menu Flow Printer'
$form.Size = New-Object Drawing.Size(800,790)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object Drawing.Size(780,750)
$form.BackColor = [Drawing.Color]::FromArgb(248,246,242)
$form.Font = New-Object Drawing.Font('Segoe UI',10)

$title = New-Object Windows.Forms.Label
$title.Text = 'Menu Flow Printer'
$title.Font = New-Object Drawing.Font('Segoe UI',20,[Drawing.FontStyle]::Bold)
$title.Location = New-Object Drawing.Point(24,20)
$title.AutoSize = $true
$form.Controls.Add($title)

$subtitle = New-Object Windows.Forms.Label
$subtitle.Text = 'Impressao automatica da cozinha, bar e caixa'
$subtitle.Location = New-Object Drawing.Point(28,60)
$subtitle.ForeColor = [Drawing.Color]::DimGray
$subtitle.AutoSize = $true
$form.Controls.Add($subtitle)

$script:StatusLabel = New-Object Windows.Forms.Label
$script:StatusLabel.Location = New-Object Drawing.Point(28,95)
$script:StatusLabel.Size = New-Object Drawing.Size(625,44)
$script:StatusLabel.Text = 'Aguardando configuracao'
$form.Controls.Add($script:StatusLabel)

function Add-Label($text,$x,$y) { $l=New-Object Windows.Forms.Label; $l.Text=$text; $l.Location=New-Object Drawing.Point($x,$y); $l.AutoSize=$true; $l.Font=New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Bold); $form.Controls.Add($l); return $l }
function Add-TextBox($x,$y,$w) { $t=New-Object Windows.Forms.TextBox; $t.Location=New-Object Drawing.Point($x,$y); $t.Size=New-Object Drawing.Size($w,30); $form.Controls.Add($t); return $t }
function Add-Combo($x,$y,$w) { $c=New-Object Windows.Forms.ComboBox; $c.Location=New-Object Drawing.Point($x,$y); $c.Size=New-Object Drawing.Size($w,30); $c.DropDownStyle='DropDownList'; $form.Controls.Add($c); return $c }

Add-Label 'Backend do Menu Flow' 28 145 | Out-Null
$apiBox = Add-TextBox 28 168 625
$apiBox.Text = [string]$script:Config.apiUrl
Add-Label 'Chave do Menu Flow Printer' 28 210 | Out-Null
$tokenBox = Add-TextBox 28 233 625
$tokenBox.Text = [string]$script:Config.token

$printers = @(Get-PrinterNames)
Add-Label 'Impressora da cozinha / producao' 28 278 | Out-Null
$kitchenCombo = Add-Combo 28 301 330
Add-Label 'Impressora do caixa' 385 278 | Out-Null
$cashierCombo = Add-Combo 385 301 330

$sharedCheck = New-Object Windows.Forms.CheckBox
$sharedCheck.Text = 'Usar a mesma impressora para cozinha e bar'
$sharedCheck.Location = New-Object Drawing.Point(28,345)
$sharedCheck.AutoSize = $true
$sharedCheck.Checked = [bool]$script:Config.sharedProductionPrinter
$form.Controls.Add($sharedCheck)

Add-Label 'Impressora do bar (somente se separada)' 28 382 | Out-Null
$barCombo = Add-Combo 28 405 330
Add-Label 'Nome deste computador' 385 382 | Out-Null
$deviceBox = Add-TextBox 385 405 330
$deviceBox.Text = [string]$script:Config.deviceName

foreach ($combo in @($kitchenCombo,$barCombo,$cashierCombo)) { [void]$combo.Items.Add(''); foreach($p in $printers){ [void]$combo.Items.Add($p) } }
$kitchenCombo.SelectedItem = [string]$script:Config.kitchenPrinter
$barCombo.SelectedItem = [string]$script:Config.barPrinter
$cashierCombo.SelectedItem = [string]$script:Config.cashierPrinter
foreach ($combo in @($kitchenCombo,$barCombo,$cashierCombo)) { if ($null -eq $combo.SelectedItem) { $combo.SelectedIndex = 0 } }
$barCombo.Enabled = -not $sharedCheck.Checked
$sharedCheck.Add_CheckedChanged({ $barCombo.Enabled = -not $sharedCheck.Checked })

$testModeCheck = New-Object Windows.Forms.CheckBox
$testModeCheck.Text = 'Modo de teste - nao usa impressora; salva previas em arquivo'
$testModeCheck.Location = New-Object Drawing.Point(28,458)
$testModeCheck.AutoSize = $true
$testModeCheck.Checked = [bool]$script:Config.testMode
$form.Controls.Add($testModeCheck)

Add-Label 'Papel para os testes locais' 385 450 | Out-Null
$paperCombo = Add-Combo 385 473 160
[void]$paperCombo.Items.Add('58 mm')
[void]$paperCombo.Items.Add('80 mm')
$paperCombo.SelectedItem = if ([int]$script:Config.testPaperWidth -eq 58) { '58 mm' } else { '80 mm' }

$openTestFolderButton = New-Object Windows.Forms.Button
$openTestFolderButton.Text = 'Abrir pasta de testes'
$openTestFolderButton.Location = New-Object Drawing.Point(555,470)
$openTestFolderButton.Size = New-Object Drawing.Size(160,32)
$form.Controls.Add($openTestFolderButton)

$enabledCheck = New-Object Windows.Forms.CheckBox
$enabledCheck.Text = 'Ativar impressao automatica'
$enabledCheck.Location = New-Object Drawing.Point(28,515)
$enabledCheck.AutoSize = $true
$enabledCheck.Checked = [bool]$script:Config.enabled
$form.Controls.Add($enabledCheck)

$saveButton = New-Object Windows.Forms.Button
$saveButton.Text = 'Salvar e conectar'
$saveButton.Location = New-Object Drawing.Point(28,558)
$saveButton.Size = New-Object Drawing.Size(170,42)
$saveButton.BackColor = [Drawing.Color]::FromArgb(37,29,25)
$saveButton.ForeColor = [Drawing.Color]::White
$saveButton.FlatStyle = 'Flat'
$form.Controls.Add($saveButton)

$testKitchenButton = New-Object Windows.Forms.Button
$testKitchenButton.Text = 'Testar cozinha'
$testKitchenButton.Location = New-Object Drawing.Point(210,558)
$testKitchenButton.Size = New-Object Drawing.Size(125,42)
$form.Controls.Add($testKitchenButton)

$testBarButton = New-Object Windows.Forms.Button
$testBarButton.Text = 'Testar bar'
$testBarButton.Location = New-Object Drawing.Point(347,558)
$testBarButton.Size = New-Object Drawing.Size(115,42)
$form.Controls.Add($testBarButton)

$testCashierButton = New-Object Windows.Forms.Button
$testCashierButton.Text = 'Testar caixa'
$testCashierButton.Location = New-Object Drawing.Point(474,558)
$testCashierButton.Size = New-Object Drawing.Size(115,42)
$form.Controls.Add($testCashierButton)

$hideButton = New-Object Windows.Forms.Button
$hideButton.Text = 'Minimizar'
$hideButton.Location = New-Object Drawing.Point(601,558)
$hideButton.Size = New-Object Drawing.Size(114,42)
$form.Controls.Add($hideButton)

$hint = New-Object Windows.Forms.Label
$hint.Text = 'Uma impressora: marque a opcao acima. No Modo de Teste, os trabalhos reais da fila sao salvos em Documentos\Menu Flow Printer\Testes, com largura de 58 mm ou 80 mm. Se o Microsoft Edge estiver instalado, o Printer tambem gera PDF automaticamente.'
$hint.Location = New-Object Drawing.Point(28,620)
$hint.Size = New-Object Drawing.Size(730,80)
$hint.ForeColor = [Drawing.Color]::DimGray
$form.Controls.Add($hint)

$saveButton.Add_Click({
  $script:Config.apiUrl = $apiBox.Text.Trim().TrimEnd('/')
  $script:Config.token = $tokenBox.Text.Trim()
  $script:Config.kitchenPrinter = [string]$kitchenCombo.SelectedItem
  $script:Config.barPrinter = [string]$barCombo.SelectedItem
  $script:Config.sharedProductionPrinter = $sharedCheck.Checked
  $script:Config.cashierPrinter = [string]$cashierCombo.SelectedItem
  $script:Config.deviceName = $deviceBox.Text.Trim()
  $script:Config.enabled = $enabledCheck.Checked
  $script:Config.testMode = $testModeCheck.Checked
  $script:Config.testPaperWidth = if ([string]$paperCombo.SelectedItem -eq '58 mm') { 58 } else { 80 }
  Save-MenuFlowConfig $script:Config
  Set-Status 'Configuracao salva. Conectando...' $false
  Invoke-Poll
})
$testKitchenButton.Add_Click({ try { $paper=if([string]$paperCombo.SelectedItem -eq '58 mm'){58}else{80}; $content=Get-SampleReceipt 'KITCHEN' $paper; if($testModeCheck.Checked){$preview=Save-TestPrint 'LOCAL_TEST' 'KITCHEN' $content $paper; [Windows.Forms.MessageBox]::Show('Prévia salva em: ' + $preview.Folder,'Menu Flow Printer')|Out-Null}else{Send-MenuFlowPrint ([string]$kitchenCombo.SelectedItem) $content 1; [Windows.Forms.MessageBox]::Show('Teste enviado para a cozinha.','Menu Flow Printer')|Out-Null} } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Erro',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error) | Out-Null } })
$testBarButton.Add_Click({ try { $paper=if([string]$paperCombo.SelectedItem -eq '58 mm'){58}else{80}; $content=Get-SampleReceipt 'BAR' $paper; if($testModeCheck.Checked){$preview=Save-TestPrint 'LOCAL_TEST' 'BAR' $content $paper; [Windows.Forms.MessageBox]::Show('Prévia salva em: ' + $preview.Folder,'Menu Flow Printer')|Out-Null}else{$target=if($sharedCheck.Checked){[string]$kitchenCombo.SelectedItem}else{[string]$barCombo.SelectedItem}; Send-MenuFlowPrint $target $content 1; [Windows.Forms.MessageBox]::Show('Teste enviado para o bar.','Menu Flow Printer')|Out-Null} } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Erro',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error) | Out-Null } })
$testCashierButton.Add_Click({ try { $paper=if([string]$paperCombo.SelectedItem -eq '58 mm'){58}else{80}; $content=Get-SampleReceipt 'CASHIER' $paper; if($testModeCheck.Checked){$preview=Save-TestPrint 'LOCAL_TEST' 'CASHIER' $content $paper; [Windows.Forms.MessageBox]::Show('Prévia salva em: ' + $preview.Folder,'Menu Flow Printer')|Out-Null}else{Send-MenuFlowPrint ([string]$cashierCombo.SelectedItem) $content 1; [Windows.Forms.MessageBox]::Show('Teste enviado para o caixa.','Menu Flow Printer')|Out-Null} } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Erro',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error) | Out-Null } })
$openTestFolderButton.Add_Click({ Open-TestFolder })
$hideButton.Add_Click({ $form.Hide() })

$script:NotifyIcon = New-Object Windows.Forms.NotifyIcon
$script:NotifyIcon.Icon = [Drawing.SystemIcons]::Application
$script:NotifyIcon.Text = 'Menu Flow Printer'
$script:NotifyIcon.Visible = $true
$trayMenu = New-Object Windows.Forms.ContextMenuStrip
$openItem = $trayMenu.Items.Add('Abrir Menu Flow Printer')
$exitItem = $trayMenu.Items.Add('Sair')
$openItem.Add_Click({ $form.Show(); $form.WindowState = 'Normal'; $form.Activate() })
$exitItem.Add_Click({ $script:NotifyIcon.Visible = $false; $script:Timer.Stop(); $form.Tag = 'EXIT'; $form.Close() })
$script:NotifyIcon.ContextMenuStrip = $trayMenu
$script:NotifyIcon.Add_DoubleClick({ $form.Show(); $form.WindowState='Normal'; $form.Activate() })

$form.Add_FormClosing({ param($sender,$e) if ($form.Tag -ne 'EXIT') { $e.Cancel = $true; $form.Hide(); $script:NotifyIcon.ShowBalloonTip(1200,'Menu Flow Printer','Continuo funcionando ao lado do relogio.',[Windows.Forms.ToolTipIcon]::Info) } })

$script:Timer = New-Object Windows.Forms.Timer
$script:Timer.Interval = 2000
$script:Timer.Add_Tick({ Invoke-Poll })
$script:Timer.Start()

if ($script:Config.apiUrl -and $script:Config.token) { Set-Status $(if($script:Config.testMode){'Conectando em Modo de Teste...'}else{'Conectando...'}) $false; Invoke-Poll }
else { Set-Status 'Configure o backend, a chave e as impressoras.' $true }

[void][Windows.Forms.Application]::Run($form)
$script:NotifyIcon.Dispose()
