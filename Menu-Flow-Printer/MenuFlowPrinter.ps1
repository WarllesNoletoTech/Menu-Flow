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
    cashierPrinter = ''
    deviceName = $env:COMPUTERNAME
    deviceId = 'mfp-' + [Guid]::NewGuid().ToString('N')
    enabled = $true
  }
}

function Load-MenuFlowConfig {
  if (!(Test-Path $script:ConfigFile)) { return New-DefaultConfig }
  try {
    $cfg = Get-Content $script:ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if (!$cfg.deviceId) { $cfg | Add-Member -NotePropertyName deviceId -NotePropertyValue ('mfp-' + [Guid]::NewGuid().ToString('N')) -Force }
    if ($null -eq $cfg.enabled) { $cfg | Add-Member -NotePropertyName enabled -NotePropertyValue $true -Force }
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
  $roles = @()
  if ($script:Config.kitchenPrinter) { $roles += 'KITCHEN' }
  if ($script:Config.cashierPrinter) { $roles += 'CASHIER' }
  return $roles
}

function Get-PrinterForRole([string]$Role) {
  switch ($Role) {
    'KITCHEN' { return [string]$script:Config.kitchenPrinter }
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
        $printer = Get-PrinterForRole ([string]$job.printerRole)
        Send-MenuFlowPrint $printer ([string]$job.content) ([int]$job.copies)
        $script:LastPrinted = (Get-Date).ToString('dd/MM/yyyy HH:mm:ss') + ' · ' + $job.type + ' · ' + $job.printerRole
        Invoke-MenuFlowApi ('/printer/agent/jobs/' + $job.id) 'PATCH' @{ deviceId = [string]$script:Config.deviceId; success = $true } | Out-Null
        Set-Status ('Conectado · ultima impressao: ' + $script:LastPrinted) $false
        $script:NotifyIcon.ShowBalloonTip(1200, 'Menu Flow Printer', 'Impressão enviada para ' + $printer, [System.Windows.Forms.ToolTipIcon]::Info)
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
$form.Size = New-Object Drawing.Size(700,600)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object Drawing.Size(680,560)
$form.BackColor = [Drawing.Color]::FromArgb(248,246,242)
$form.Font = New-Object Drawing.Font('Segoe UI',10)

$title = New-Object Windows.Forms.Label
$title.Text = 'Menu Flow Printer'
$title.Font = New-Object Drawing.Font('Segoe UI',20,[Drawing.FontStyle]::Bold)
$title.Location = New-Object Drawing.Point(24,20)
$title.AutoSize = $true
$form.Controls.Add($title)

$subtitle = New-Object Windows.Forms.Label
$subtitle.Text = 'Impressao automatica da cozinha e do caixa'
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
Add-Label 'Impressora da cozinha' 28 278 | Out-Null
$kitchenCombo = Add-Combo 28 301 300
Add-Label 'Impressora do caixa' 353 278 | Out-Null
$cashierCombo = Add-Combo 353 301 300
Add-Label 'Nome deste computador' 28 350 | Out-Null
$deviceBox = Add-TextBox 28 373 625
$deviceBox.Text = [string]$script:Config.deviceName

foreach ($combo in @($kitchenCombo,$cashierCombo)) { [void]$combo.Items.Add(''); foreach($p in $printers){ [void]$combo.Items.Add($p) } }
$kitchenCombo.SelectedItem = [string]$script:Config.kitchenPrinter
$cashierCombo.SelectedItem = [string]$script:Config.cashierPrinter
if ($null -eq $kitchenCombo.SelectedItem) { $kitchenCombo.SelectedIndex = 0 }
if ($null -eq $cashierCombo.SelectedItem) { $cashierCombo.SelectedIndex = 0 }

$enabledCheck = New-Object Windows.Forms.CheckBox
$enabledCheck.Text = 'Ativar impressao automatica'
$enabledCheck.Location = New-Object Drawing.Point(28,425)
$enabledCheck.AutoSize = $true
$enabledCheck.Checked = [bool]$script:Config.enabled
$form.Controls.Add($enabledCheck)

$saveButton = New-Object Windows.Forms.Button
$saveButton.Text = 'Salvar e conectar'
$saveButton.Location = New-Object Drawing.Point(28,470)
$saveButton.Size = New-Object Drawing.Size(180,42)
$saveButton.BackColor = [Drawing.Color]::FromArgb(37,29,25)
$saveButton.ForeColor = [Drawing.Color]::White
$saveButton.FlatStyle = 'Flat'
$form.Controls.Add($saveButton)

$testKitchenButton = New-Object Windows.Forms.Button
$testKitchenButton.Text = 'Testar cozinha'
$testKitchenButton.Location = New-Object Drawing.Point(220,470)
$testKitchenButton.Size = New-Object Drawing.Size(150,42)
$form.Controls.Add($testKitchenButton)

$testCashierButton = New-Object Windows.Forms.Button
$testCashierButton.Text = 'Testar caixa'
$testCashierButton.Location = New-Object Drawing.Point(382,470)
$testCashierButton.Size = New-Object Drawing.Size(150,42)
$form.Controls.Add($testCashierButton)

$hideButton = New-Object Windows.Forms.Button
$hideButton.Text = 'Minimizar'
$hideButton.Location = New-Object Drawing.Point(544,470)
$hideButton.Size = New-Object Drawing.Size(109,42)
$form.Controls.Add($hideButton)

$hint = New-Object Windows.Forms.Label
$hint.Text = 'Depois de configurado, o Menu Flow Printer pode ficar minimizado ao lado do relogio.'
$hint.Location = New-Object Drawing.Point(28,528)
$hint.Size = New-Object Drawing.Size(620,30)
$hint.ForeColor = [Drawing.Color]::DimGray
$form.Controls.Add($hint)

$saveButton.Add_Click({
  $script:Config.apiUrl = $apiBox.Text.Trim()
  $script:Config.token = $tokenBox.Text.Trim()
  $script:Config.kitchenPrinter = [string]$kitchenCombo.SelectedItem
  $script:Config.cashierPrinter = [string]$cashierCombo.SelectedItem
  $script:Config.deviceName = $deviceBox.Text.Trim()
  $script:Config.enabled = $enabledCheck.Checked
  Save-MenuFlowConfig $script:Config
  Set-Status 'Configuracao salva. Conectando...' $false
  Invoke-Poll
})
$testKitchenButton.Add_Click({ try { Send-MenuFlowPrint ([string]$kitchenCombo.SelectedItem) "MENU FLOW PRINTER`n`nTESTE COZINHA`nImpressora configurada corretamente.`n" 1; [Windows.Forms.MessageBox]::Show('Teste enviado para a cozinha.','Menu Flow Printer') | Out-Null } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Erro',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error) | Out-Null } })
$testCashierButton.Add_Click({ try { Send-MenuFlowPrint ([string]$cashierCombo.SelectedItem) "MENU FLOW PRINTER`n`nTESTE CAIXA`nImpressora configurada corretamente.`n" 1; [Windows.Forms.MessageBox]::Show('Teste enviado para o caixa.','Menu Flow Printer') | Out-Null } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Erro',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error) | Out-Null } })
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

if ($script:Config.apiUrl -and $script:Config.token) { Set-Status 'Conectando...' $false; Invoke-Poll }
else { Set-Status 'Configure o backend, a chave e as impressoras.' $true }

[void][Windows.Forms.Application]::Run($form)
$script:NotifyIcon.Dispose()
