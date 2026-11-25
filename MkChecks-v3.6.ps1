# ==============================================================================
# MkChecks Forensic Scanner v3.6 - Compact Card (Preto & Roxo) + DMA / PCIe / Bypass
# Apenas leitura. Não apaga ficheiros, não altera registo nem desativa segurança.
# ==============================================================================

$script:WebhookUrl = "https://discord.com/api/webhooks/1574173816098259054/P0wRGzaR-zlpIOvH6wqGy6z-nGU4fUFFR-d5sFfi26TGGoRL81Gz-2bS2L-U9wqkx-O6"
$script:AutoRunAndSend = $true

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try { [System.Windows.Forms.Application]::EnableVisualStyles() } catch {}

# Modos disponíveis: "FullForensic", "QuickScan", "FiveMOnly", "RamModule"
$script:ScanMode = "FullForensic"
$script:Threshold = 50
$script:MaxResults = 30

# Padrões fortes: cheats, spoofers, loaders, injectors, bypass pagos e drivers abusados
$cheatStrongPattern = '(?i)(fivem[-_ ]?exeternal|fivem[-_ ]?external|aimbot|wallhack|wall[-_ ]?hack|hwid[-_ ]?spoofer|hwid[-_ ]?spoof|spoofer|mod[-_ ]?menu|triggerbot|silent[-_ ]?aim|ragebot|redengine|eulen|skript\.gg|lynx|lumia|tz[-_ ]?project|hx[-_ ]?cheats|desudo|brutan|kekhack|interwebz|neverlose|onetap|gamesense|skeet|fatality|aimware|iniuria|vape[-_ ]?v4|wurst|meteor[-_ ]?client|aristois|xenos|extreme[-_ ]?injector|process[-_ ]?hacker|kdmapper|drvmap|gdrv\.sys|capcom\.sys|iqvw64e\.sys|dsefix|winring0|anticheat[-_ ]?bypass|ac[-_ ]?bypass|cleaner[-_ ]?fivem|unban[-_ ]?fivem|aimlock|spinbot|esp[-_ ]?hack|radar[-_ ]?hack|norecoil|no[-_ ]?spread|keyauth|fiveguard[-_ ]?bypass|phantom|macho|susano|tarkov|cs2[-_ ]?cheat|hyperion[-_ ]?bypass|pcileech|screamer[-_ ]?dma|enigma[-_ ]?dma|captain[-_ ]?dma|leetdma)'

# Padrões médios: técnicas de injeção, mapeamento em memória, loaders genéricos e evasão
$cheatMediumPattern = '(?i)(manual[-_ ]?map|reflective[-_ ]?dll|process[-_ ]?hollowing|dll[-_ ]?inject|offset[-_ ]?finder|cheat[-_ ]?engine|artmoney|wemod|recoil[-_ ]?script|no[-_ ]?recoil|kernel[-_ ]?drv|injector|loader|bypass|cleaner|hwid|unban|fiveguard|mapper|overlay|hook|aim|esp|fpga|xilinx|ftdi)'

# Padrões para rastos locais do Discord
$discordCheatPattern = '(?i)(redengine|eulen|skript\.gg|lynx|lumia|tz[-_ ]?project|hx[-_ ]?cheats|fivem[-_ ]?external|fivem[-_ ]?exeternal|hwid[-_ ]?spoofer|spoofer|unban[-_ ]?fivem|cleaner[-_ ]?fivem|anticheat[-_ ]?bypass|cheat[-_ ]?fivem|mod[-_ ]?menu|aimbot|wallhack|silent[-_ ]?aim|triggerbot|xenos|extreme[-_ ]?injector|kdmapper|fiveguard[-_ ]?bypass|keyauth|cheat|cheats|bypass|loader|spoofer|pcileech|dma)'

# Padrões de strings/assinaturas internas em executáveis/DLLs/scripts e memória RWX
$binarySignaturePattern = '(?i)(keyauth\.win|api\.keyauth|manualmap|ntcreatethreadex|writeprocessmemory|virtualallocex|setwindowshookex|d3d11|present_hook|fivem\.exe|citizenfx|fiveguard|bypass|spoofer|hwid|redengine|eulen|skript|susano|pcileech)'

# Exclusões focadas apenas em pastas críticas do sistema e launchers legítimos conhecidos
$strictExcludePattern = '(?i)(\\(Windows\\WinSxS|Windows\\System32\\DriverStore|Windows\\servicing|Program Files\\Windows Defender|Program Files\\WindowsApps|ProgramData\\Microsoft\\Windows Defender|Steam|Epic Games|Riot Games|Battle\.net|Ubisoft|Electronic Arts|NVIDIA Corporation|AMD|Intel)(\\|$)|api-ms-win-core-|natives_loader\.lua|renderer_js\.log)'

$scanRoots = @(
    "$env:APPDATA",
    "$env:LOCALAPPDATA",
    "$env:LOCALAPPDATA\Low",
    "$env:TEMP",
    "$env:SystemRoot\Temp",
    "$env:ProgramData",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\OneDrive\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\OneDrive\Documents",
    "$env:ProgramFiles",
    "${env:ProgramFiles(x86)}",
    "$env:SystemRoot\System32",
    "$env:SystemRoot\System32\drivers",
    "C:\Users\Public",
    "C:\"
) | Where-Object { $_ -and (-not [string]::IsNullOrWhiteSpace($_)) } | Select-Object -Unique

$script:UiQueue = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
$script:CorrelatedInvestigations = [System.Collections.Concurrent.ConcurrentQueue[pscustomobject]]::new()
$script:DiscordTraces = [System.Collections.Concurrent.ConcurrentQueue[pscustomobject]]::new()
$script:TimelineEvents = [System.Collections.Concurrent.ConcurrentQueue[pscustomobject]]::new()
$script:SkippedSources = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

function Queue-UI {
    param([int]$Percent, [string]$Text, [string]$SubText = "")
    $script:UiQueue.Enqueue(@{
        Percent = [Math]::Max(0, [Math]::Min(100, $Percent))
        Text    = $Text
        SubText = $SubText
    })
}

function Apply-QueuedUI {
    $item = $null
    while ($script:UiQueue.TryDequeue([ref]$item)) {
        try {
            $p = [int]$item.Percent
            $lblStatus.Text = "$($item.Text) ($p%)"
            $lblPct.Text = "$p%"
            $fillWidth = [int](($barBg.Width - 4) * ($p / 100.0))
            $barFill.Width = [Math]::Max(0, $fillWidth)
            if ($item.SubText) { $lblSub.Text = $item.SubText }
        } catch {}
    }
}

# ==============================================================================
# LOGO "MkChecks" (QUADRADO PRETO & ROXO)
# ==============================================================================
function New-MkChecksBannerBitmap {
    param([int]$W, [int]$H)
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.TextRenderingHint]::AntiAliasGridFit

    $rectAll = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(12, 10, 18))), $rectAll)

    $pathGlow = New-Object System.Drawing.Drawing2D.GraphicsPath
    $pathGlow.AddEllipse([int]($W * 0.15), [int]($H * 0.08), [int]($W * 0.70), [int]($H * 0.84))
    $pgr = New-Object System.Drawing.Drawing2D.PathGradientBrush($pathGlow)
    $pgr.CenterColor = [System.Drawing.Color]::FromArgb(95, 139, 92, 246)
    $pgr.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 12, 10, 18))
    $g.FillPath($pgr, $pathGlow)

    $cx = $W / 2.0
    $cy = ($H / 2.0) - 24
    $penGlow = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(90, 168, 85, 247), 18)
    $penGlow.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penGlow.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penGlow.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $penMain = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(192, 132, 252), 8)
    $penMain.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penMain.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penMain.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $mPoints = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF(($cx - 46), ($cy + 26))),
        (New-Object System.Drawing.PointF(($cx - 32), ($cy - 28))),
        (New-Object System.Drawing.PointF($cx, ($cy + 4))),
        (New-Object System.Drawing.PointF(($cx + 32), ($cy - 28))),
        (New-Object System.Drawing.PointF(($cx + 46), ($cy + 26)))
    )
    $g.DrawLines($penGlow, $mPoints)
    $g.DrawLines($penMain, $mPoints)

    $fontBrand = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

    $textRect = New-Object System.Drawing.RectangleF(0, ($cy + 34), $W, 42)
    $g.DrawString("MkChecks", $fontBrand, (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 243, 255))), $textRect, $sf)

    $g.Dispose()
    return $bmp
}

$bgBlack     = [System.Drawing.Color]::FromArgb(12, 10, 18)
$bgPanel     = [System.Drawing.Color]::FromArgb(20, 16, 30)
$purpleMain  = [System.Drawing.Color]::FromArgb(147, 51, 234)
$purpleLight = [System.Drawing.Color]::FromArgb(192, 132, 252)
$textWhite   = [System.Drawing.Color]::FromArgb(245, 243, 255)
$textGray    = [System.Drawing.Color]::FromArgb(167, 139, 250)

$form = New-Object System.Windows.Forms.Form
$form.Text = "MkChecks v3.6"
$form.ClientSize = New-Object System.Drawing.Size(420, 440)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.StartPosition = "CenterScreen"
$form.BackColor = $bgBlack
$form.ForeColor = $textWhite

$picBanner = New-Object System.Windows.Forms.PictureBox
$picBanner.Location = New-Object System.Drawing.Point(16, 16)
$picBanner.Size = New-Object System.Drawing.Size(388, 235)
$picBanner.SizeMode = "StretchImage"
$picBanner.Image = New-MkChecksBannerBitmap -W 388 -H 235
$form.Controls.Add($picBanner)

$card = New-Object System.Windows.Forms.Panel
$card.Location = New-Object System.Drawing.Point(16, 263)
$card.Size = New-Object System.Drawing.Size(388, 160)
$card.BackColor = $bgPanel
$form.Controls.Add($card)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "A preparar investigação forense... (0%)"
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$lblStatus.ForeColor = $textWhite
$lblStatus.Location = New-Object System.Drawing.Point(16, 18)
$lblStatus.Size = New-Object System.Drawing.Size(305, 22)
$card.Controls.Add($lblStatus)

$lblPct = New-Object System.Windows.Forms.Label
$lblPct.Text = "0%"
$lblPct.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$lblPct.ForeColor = $purpleLight
$lblPct.Location = New-Object System.Drawing.Point(322, 18)
$lblPct.Size = New-Object System.Drawing.Size(50, 22)
$lblPct.TextAlign = "MiddleRight"
$card.Controls.Add($lblPct)

$barBg = New-Object System.Windows.Forms.Panel
$barBg.Location = New-Object System.Drawing.Point(16, 48)
$barBg.Size = New-Object System.Drawing.Size(356, 16)
$barBg.BackColor = [System.Drawing.Color]::FromArgb(36, 28, 54)
$card.Controls.Add($barBg)

$barFill = New-Object System.Windows.Forms.Panel
$barFill.Location = New-Object System.Drawing.Point(2, 2)
$barFill.Size = New-Object System.Drawing.Size(0, 12)
$barFill.BackColor = $purpleMain
$barBg.Controls.Add($barFill)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Correlação forense em curso — não feche esta janela"
$lblSub.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblSub.ForeColor = $textGray
$lblSub.Location = New-Object System.Drawing.Point(16, 78)
$lblSub.Size = New-Object System.Drawing.Size(356, 20)
$card.Controls.Add($lblSub)

$lblFoot = New-Object System.Windows.Forms.Label
$lblFoot.Text = "MkChecks v3.6 • Investigação Forense FiveM & Hardware DMA"
$lblFoot.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblFoot.ForeColor = [System.Drawing.Color]::FromArgb(124, 111, 163)
$lblFoot.Location = New-Object System.Drawing.Point(16, 124)
$lblFoot.Size = New-Object System.Drawing.Size(356, 20)
$lblFoot.TextAlign = "MiddleCenter"
$card.Controls.Add($lblFoot)

# ==============================================================================
# WORKER FORENSE v3.6 (CORRELAÇÃO + BYPASS/CLEANERS + MEMÓRIA RWX + DMA/PCIe)
# ==============================================================================
$script:Runspace = [runspacefactory]::CreateRunspace()
$script:Runspace.ApartmentState = "STA"
$script:Runspace.Open()
$script:Runspace.SessionStateProxy.SetVariable("WebhookUrl", $script:WebhookUrl)
$script:Runspace.SessionStateProxy.SetVariable("ScanMode", $script:ScanMode)
$script:Runspace.SessionStateProxy.SetVariable("Threshold", $script:Threshold)
$script:Runspace.SessionStateProxy.SetVariable("MaxResults", $script:MaxResults)
$script:Runspace.SessionStateProxy.SetVariable("cheatStrongPattern", $cheatStrongPattern)
$script:Runspace.SessionStateProxy.SetVariable("cheatMediumPattern", $cheatMediumPattern)
$script:Runspace.SessionStateProxy.SetVariable("discordCheatPattern", $discordCheatPattern)
$script:Runspace.SessionStateProxy.SetVariable("binarySignaturePattern", $binarySignaturePattern)
$script:Runspace.SessionStateProxy.SetVariable("strictExcludePattern", $strictExcludePattern)
$script:Runspace.SessionStateProxy.SetVariable("scanRoots", $scanRoots)
$script:Runspace.SessionStateProxy.SetVariable("UiQueue", $script:UiQueue)
$script:Runspace.SessionStateProxy.SetVariable("CorrelatedInvestigations", $script:CorrelatedInvestigations)
$script:Runspace.SessionStateProxy.SetVariable("DiscordTraces", $script:DiscordTraces)
$script:Runspace.SessionStateProxy.SetVariable("TimelineEvents", $script:TimelineEvents)
$script:Runspace.SessionStateProxy.SetVariable("SkippedSources", $script:SkippedSources)

$script:PsInstance = [powershell]::Create()
$script:PsInstance.Runspace = $script:Runspace

$workerScript = @'
$script:WebhookUrl = $WebhookUrl
$script:ScanMode = $ScanMode
$script:Threshold = $Threshold
$script:MaxResults = $MaxResults
$script:UiQueue = $UiQueue
$script:CorrelatedInvestigations = $CorrelatedInvestigations
$script:DiscordTraces = $DiscordTraces
$script:TimelineEvents = $TimelineEvents
$script:SkippedSources = $SkippedSources

$script:CorrelationMap = @{}
$script:CertCache = @{}
$script:HashCache = @{}
$script:fileCounter = 0

# Estado estruturado do módulo Hardware DMA & Bootkits
$script:DmaBootStatus = [ordered]@{
    SecureBootEstado      = "Desconhecido"
    SecureBootAlerta      = $false
    KernelDmaEstado       = "Desconhecido"
    VbsEstado             = "Desconhecido"
    DmaProtectionAlerta   = $false
    PcieAnomalias         = New-Object System.Collections.Generic.List[string]
    RequerCamaraPcie      = $false
}

# APIs nativas para leitura de memória RWX e threads sem módulo (unbacked)
try {
    Add-Type -MemberDefinition @"
using System;
using System.Runtime.InteropServices;

public static class MkMemNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct MEMORY_BASIC_INFORMATION {
        public IntPtr BaseAddress;
        public IntPtr AllocationBase;
        public uint AllocationProtect;
        public IntPtr RegionSize;
        public uint State;
        public uint Protect;
        public uint Type;
    }

    public const uint PROCESS_VM_READ = 0x0010;
    public const uint PROCESS_QUERY_INFORMATION = 0x0400;
    public const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
    public const uint MEM_COMMIT = 0x1000;
    public const uint MEM_PRIVATE = 0x20000;
    public const uint PAGE_EXECUTE_READWRITE = 0x40;
    public const int ThreadQuerySetWin32StartAddress = 9;

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int dwSize, out int lpNumberOfBytesRead);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern int VirtualQueryEx(IntPtr hProcess, IntPtr lpAddress, out MEMORY_BASIC_INFORMATION lpBuffer, uint dwLength);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("ntdll.dll")]
    public static extern int NtQueryInformationThread(IntPtr ThreadHandle, int ThreadInformationClass, out IntPtr ThreadInformation, int ThreadInformationLength, out int ReturnLength);
}
"@ -Name "MkMemNative" -Namespace "Forensics" -ErrorAction SilentlyContinue
} catch {}

function Queue-UI {
    param([int]$Percent, [string]$Text, [string]$SubText = "")
    $script:UiQueue.Enqueue(@{
        Percent = [Math]::Max(0, [Math]::Min(100, $Percent))
        Text    = $Text
        SubText = $SubText
    })
}

function Add-Skipped {
    param([string]$SourceName)
    if ($SourceName) { $script:SkippedSources.Enqueue($SourceName) }
}

function Add-Timeline {
    param([string]$TimeStr, [string]$Kind, [string]$Source, [string]$Subject, [string]$Detail)
    $t = if ([string]::IsNullOrWhiteSpace($TimeStr) -or $TimeStr -eq "N/A") { (Get-Date -Format "yyyy-MM-dd HH:mm:ss") } else { $TimeStr }
    $script:TimelineEvents.Enqueue([pscustomobject]@{
        DataHora = $t
        Tipo     = $Kind
        Fonte    = $Source
        Alvo     = $Subject
        Detalhe  = $Detail
    })
}

function Normalize-Key {
    param([string]$Name, [string]$Path)
    $base = ""
    if ($Path -and $Path -ne "N/A") {
        $fn = [System.IO.Path]::GetFileName($Path)
        if ([string]::IsNullOrWhiteSpace($fn)) {
            $parts = $Path -split '[\\/]'
            $fn = ($parts | Where-Object { $_ } | Select-Object -Last 1)
        }
        $base = $fn
    }
    if ([string]::IsNullOrWhiteSpace($base) -and $Name) {
        $base = $Name
    }
    $base = ($base -replace '-[A-F0-9]{8}\.pf$', '' -replace '\.lnk$', '' -replace '\.(exe|dll|sys|bat|cmd|ps1|vbs|js|scr|pf)$', '').ToLowerInvariant().Trim()
    if ([string]::IsNullOrWhiteSpace($base)) { $base = "desconhecido" }
    return $base
}

function Clean-DisplayName {
    param([string]$Name, [string]$Path)
    $n = if ($Name) { $Name.Trim() } else { "" }
    if ([string]::IsNullOrWhiteSpace($n) -and $Path -and $Path -ne "N/A") {
        $n = [System.IO.Path]::GetFileName($Path)
    }
    if ([string]::IsNullOrWhiteSpace($n)) { $n = "artefacto_desconhecido" }
    $n = ($n -replace '[\r\n`\*_~|]', '').Trim()
    if ($n.Length -gt 70) { $n = $n.Substring(0, 67) + "..." }
    return $n
}

function Register-Evidence {
    param(
        [string]$RawName,
        [string]$RawPath,
        [string]$SourceType,
        [string]$EvidenceText,
        [bool]$IsStrong = $false,
        [bool]$IsRunning = $false,
        [bool]$IsDeletedOrRenamed = $false,
        [string]$Sha256 = "N/A",
        [string]$SigStatus = "N/A",
        [string]$Publisher = "N/A",
        [string]$Timestamp = "N/A",
        [string]$ExtraDetail = "",
        [int]$BonusScore = 0
    )

    $pathClean = if ([string]::IsNullOrWhiteSpace($RawPath)) { "N/A" } else { $RawPath.Trim() }
    if ($pathClean -ne "N/A" -and ($pathClean -match $strictExcludePattern)) { return }

    $nameClean = Clean-DisplayName -Name $RawName -Path $pathClean
    if ($nameClean -match $strictExcludePattern) { return }

    $combined = "$nameClean $pathClean $EvidenceText $ExtraDetail"

    $matchedStrong = $IsStrong -or ($combined -match $cheatStrongPattern)
    $matchedMedium = ($combined -match $cheatMediumPattern)
    if (-not $matchedStrong -and -not $matchedMedium -and ($BonusScore -le 0)) { return }

    $key = Normalize-Key -Name $nameClean -Path $pathClean
    if (-not $script:CorrelationMap.ContainsKey($key)) {
        $script:CorrelationMap[$key] = @{
            Key                = $key
            Nome               = $nameClean
            Caminhos           = New-Object System.Collections.Generic.HashSet[string]
            Fontes             = New-Object System.Collections.Generic.HashSet[string]
            Evidencias         = New-Object System.Collections.Generic.List[string]
            Detalhes           = New-Object System.Collections.Generic.List[string]
            SHA256             = "N/A"
            SigStatus          = "N/A"
            Publisher          = "N/A"
            DataHora           = "N/A"
            IsRunning          = $false
            IsDeletedOrRenamed = $false
            HasStrongMatch     = $false
            HasMediumMatch     = $false
            InUserOrTempDir    = $false
            BonusScore         = 0
            OnlyBonus          = (-not $matchedStrong -and -not $matchedMedium)
        }
    }

    $rec = $script:CorrelationMap[$key]
    if ($pathClean -ne "N/A") { [void]$rec.Caminhos.Add($pathClean) }
    if ($SourceType) { [void]$rec.Fontes.Add($SourceType) }
    if ($EvidenceText -and -not $rec.Evidencias.Contains($EvidenceText)) { $rec.Evidencias.Add($EvidenceText) }
    if ($ExtraDetail -and -not $rec.Detalhes.Contains($ExtraDetail)) { $rec.Detalhes.Add($ExtraDetail) }

    if ($matchedStrong) { $rec.HasStrongMatch = $true; $rec.OnlyBonus = $false }
    if ($matchedMedium) { $rec.HasMediumMatch = $true; $rec.OnlyBonus = $false }
    if ($IsRunning) { $rec.IsRunning = $true }
    if ($IsDeletedOrRenamed) { $rec.IsDeletedOrRenamed = $true }
    if ($BonusScore -gt $rec.BonusScore) { $rec.BonusScore = $BonusScore }

    if ($pathClean -match '(?i)\\(AppData|Temp|Downloads|Desktop|Recycle\.Bin|ProgramData)\\') {
        $rec.InUserOrTempDir = $true
    }

    if ($Sha256 -and $Sha256 -ne "N/A" -and $rec.SHA256 -eq "N/A") { $rec.SHA256 = $Sha256 }
    if ($SigStatus -and $SigStatus -ne "N/A" -and $rec.SigStatus -eq "N/A") {
        $rec.SigStatus = $SigStatus
        $rec.Publisher = $Publisher
    }
    if ($Timestamp -and $Timestamp -ne "N/A" -and $rec.DataHora -eq "N/A") {
        $rec.DataHora = $Timestamp
    }
}

function Get-CertInfoFast {
    param([string]$Path)
    if (-not $Path -or -not ([System.IO.File]::Exists($Path))) { return @{ Status = "N/A"; Publisher = "N/A" } }
    $k = $Path.ToLowerInvariant()
    if ($script:CertCache.ContainsKey($k)) { return $script:CertCache[$k] }

    try {
        $auth = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
        if ($auth -and $auth.SignerCertificate) {
            $pub = $auth.SignerCertificate.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
            if (-not $pub) { $pub = $auth.SignerCertificate.Subject }
            $st = if ($auth.Status -eq [System.Management.Automation.SignatureStatus]::Valid) { "ValidSigned" } else { "InvalidOrUntrustedSig ($($auth.Status))" }
            $res = @{ Status = $st; Publisher = $pub }
            $script:CertCache[$k] = $res
            return $res
        }
        $res = @{ Status = "Unsigned"; Publisher = "Sem assinatura" }
        $script:CertCache[$k] = $res
        return $res
    } catch {
        $res = @{ Status = "Unsigned"; Publisher = "Sem assinatura" }
        $script:CertCache[$k] = $res
        return $res
    }
}

function Get-Sha256Fast {
    param([string]$Path)
    if (-not $Path -or -not ([System.IO.File]::Exists($Path))) { return "N/A" }
    $k = $Path.ToLowerInvariant()
    if ($script:HashCache.ContainsKey($k)) { return $script:HashCache[$k] }

    try {
        $fi = New-Object System.IO.FileInfo($Path)
        if ($fi.Length -gt 120MB) { return "Grande(>120MB)" }
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $bytes = $sha.ComputeHash($fs)
            $h = (([System.BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant())
            $script:HashCache[$k] = $h
            return $h
        } finally {
            $fs.Close()
            $sha.Dispose()
        }
    } catch {
        return "N/A"
    }
}

function Test-BinaryHeuristicStrings {
    param([string]$Path)
    if (-not $Path -or -not ([System.IO.File]::Exists($Path))) { return @() }
    $hits = New-Object System.Collections.Generic.List[string]
    try {
        $fi = New-Object System.IO.FileInfo($Path)
        if ($fi.Length -gt 25MB -or $fi.Length -lt 64) { return @() }
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $readLen = [Math]::Min([int]$fi.Length, 4MB)
            $buf = New-Object byte[] $readLen
            $n = $fs.Read($buf, 0, $readLen)
            if ($n -gt 0) {
                $asc = [System.Text.Encoding]::ASCII.GetString($buf, 0, $n)
                $matches = [regex]::Matches($asc, $binarySignaturePattern)
                foreach ($m in $matches) {
                    $v = $m.Value.ToLowerInvariant()
                    if (-not $hits.Contains($v)) { $hits.Add($v) }
                    if ($hits.Count -ge 6) { break }
                }
            }
        } finally {
            $fs.Close()
        }
    } catch {}
    return @($hits)
}

function Classify-Category {
    param([string]$Text)
    if ($Text -match '(?i)(dma|pcileech|fpga|xilinx|lattice|ftdi|secureboot|deviceguard|iommu|pci\\ven_)') {
        return "Hardware DMA / Bootkit / PCIe"
    }
    if ($Text -match '(?i)(spoofer|hwid|cleaner[-_ ]?fivem|unban[-_ ]?fivem|gdrv|capcom|iqvw64e|dsefix|winring0|kdmapper|drvmap)') {
        return "Spoofer / Kernel Driver"
    }
    if ($Text -match '(?i)(xenos|extreme[-_ ]?injector|manual[-_ ]?map|reflective[-_ ]?dll|hollowing|injector|loader|dll[-_ ]?inject|kernel[-_ ]?drv|keyauth|mapper|rwx|unbacked)') {
        return "Injector / Loader / Bypass"
    }
    if ($Text -match '(?i)(redengine|eulen|skript\.gg|lynx|lumia|fivem[-_ ]?exeternal|fivem[-_ ]?external|aimbot|wallhack|triggerbot|silent[-_ ]?aim|ragebot|mod[-_ ]?menu|cheat|esp[-_ ]?hack|phantom|macho|susano)') {
        return "Cheat / Mod Menu FiveM & GTA"
    }
    return "Manipulação / Bypass"
}

function Score-CorrelatedRecord {
    param($rec)

    $score = 0
    $motivos = New-Object System.Collections.Generic.List[string]
    $fontesArr = @($rec.Fontes)
    $caminhosArr = @($rec.Caminhos)
    $primaryPath = if ($caminhosArr.Count -gt 0) { $caminhosArr[0] } else { "N/A" }

    $realExePaths = @($caminhosArr | Where-Object { $_ -match '^[A-Za-z]:\\' -and $_ -notmatch '\\Prefetch\\' })
    $existsOnDisk = $false
    foreach ($rpCheck in $realExePaths) {
        if ([System.IO.File]::Exists($rpCheck)) { $existsOnDisk = $true; break }
    }

    $hasHistSource = ($fontesArr -contains "DeletedOrPrefetch") -or ($fontesArr -contains "AmcacheShimcache") -or ($fontesArr -contains "BamDamUserAssist") -or ($fontesArr -contains "UserArtifacts") -or ($fontesArr -contains "RecycleBin")
    if (-not $existsOnDisk -and $hasHistSource) {
        $rec.IsDeletedOrRenamed = $true
        if (-not $rec.Evidencias.Contains("ficheiro ausente do caminho registado (possível remoção ou renomeação)")) {
            $rec.Evidencias.Add("ficheiro ausente do caminho registado (possível remoção ou renomeação)")
        }
    } else {
        $rec.IsDeletedOrRenamed = $false
    }

    if ($rec.HasStrongMatch) {
        $score += 45
        $motivos.Add("nome/assinatura forte de cheat/spoofer/loader/bypass")
    } elseif ($rec.HasMediumMatch) {
        $score += 26
        $motivos.Add("indicador de injeção/memória/bypass")
    }

    if ($rec.InUserOrTempDir) {
        $score += 12
        $motivos.Add("localização AppData/Temp/Downloads/Desktop/RecycleBin")
    }

    if ($fontesArr -contains "DeletedOrPrefetch") {
        $score += 15
        $motivos.Add("rasto de execução no Prefetch")
    }

    if ($rec.IsRunning) {
        $score += 16
        $motivos.Add("ativo em memória / processo / driver")
    }

    if ($fontesArr.Count -ge 2) {
        $score += 20
        $motivos.Add("correlacionado em $($fontesArr.Count) fontes forenses")
    }

    if ($rec.IsDeletedOrRenamed) {
        $score += 30
        $motivos.Add("ficheiro apagado/ausente após execução (+30)")
    }

    if ($rec.BonusScore -gt 0) {
        $score += $rec.BonusScore
        $motivos.Add("indicador forense/hardware (+$($rec.BonusScore))")
    }

    if ($rec.SigStatus -eq "Unsigned" -or ($rec.SigStatus -like "InvalidOrUntrustedSig*")) {
        $score += 9
        $motivos.Add("assinatura ausente ou não confiável ($($rec.SigStatus))")
    } elseif ($rec.SigStatus -eq "ValidSigned") {
        $score -= 12
        $motivos.Add("assinatura digital válida ($($rec.Publisher))")
    }

    $score = [Math]::Max(0, [Math]::Min(100, $score))
    $riskLabel = if ($score -ge 80) { "Risco Muito Elevado" }
                 elseif ($score -ge 65) { "Risco Elevado" }
                 elseif ($score -ge 50) { "Suspeito" }
                 elseif ($score -ge 30) { "Alerta Amarelo (Verificar Câmara)" }
                 else { "Baixo Risco" }

    $cat = Classify-Category -Text "$($rec.Nome) $primaryPath $(($rec.Evidencias -join ' '))"
    $hashShort = if ($rec.SHA256 -and $rec.SHA256.Length -gt 16) { $rec.SHA256.Substring(0, 16) + "..." } else { $rec.SHA256 }

    return [pscustomobject]@{
        Score           = $score
        RiskLabel       = $riskLabel
        Nome            = $rec.Nome
        Caminho         = $primaryPath
        TodosCaminhos   = ($caminhosArr -join " | ")
        Fontes          = ($fontesArr -join " + ")
        Categoria       = $cat
        Motivos         = ($motivos -join "; ")
        Evidencias      = ($rec.Evidencias -join "; ")
        SHA256          = $rec.SHA256
        SHA256Short     = $hashShort
        Assinatura      = $rec.SigStatus
        Publisher       = $rec.Publisher
        DataHora        = $rec.DataHora
        ApagadoRenomeado= $(if ($rec.IsDeletedOrRenamed) { "Sim" } else { "Não" })
        Ativo           = $(if ($rec.IsRunning) { "Sim" } else { "Não" })
        Confianca       = $(if ($fontesArr.Count -ge 2 -and $score -ge 75) { "Alta (Correlacionada)" } elseif ($score -ge 65) { "Média-Alta" } else { "Moderada" })
        Detalhes        = ($rec.Detalhes -join " | ")
    }
}

# ==============================================================================
# 1. MEMÓRIA / PROCESSOS ATIVOS / MÓDULOS / DRIVERS / DNS CACHE & HOSTS + RWX
# ==============================================================================
Queue-UI -Percent 10 -Text "A analisar processos, memória RWX, threads, drivers e DNS..."
$runningPaths = @{}
$osBootTime = $null
try {
    $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($osInfo -and $osInfo.LastBootUpTime) { $osBootTime = [datetime]$osInfo.LastBootUpTime }
} catch {}

try {
    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        $exe = $p.ExecutablePath
        $pName = Clean-DisplayName -Name $p.Name -Path $exe
        if ($exe) { $runningPaths[$exe.ToLowerInvariant()] = $true }

        $dt = "N/A"
        try { if ($p.CreationDate) { $dt = ([Management.ManagementDateTimeConverter]::ToDateTime($p.CreationDate)).ToString("yyyy-MM-dd HH:mm:ss") } } catch {}

        $combP = "$pName $exe $($p.CommandLine)"
        $isSuspProc = ($combP -match $cheatStrongPattern) -or ($combP -match $cheatMediumPattern)

        if (-not $isSuspProc -and $exe -and ($exe -match '(?i)\\(AppData|Temp|Users\\Public)\\') -and ($exe -notmatch '(?i)\\(Discord|FiveM Application Data|Rockstar Games)\\')) {
            $ciChk = Get-CertInfoFast -Path $exe
            if ($ciChk.Status -ne "ValidSigned") {
                $strHits = Test-BinaryHeuristicStrings -Path $exe
                if ($strHits.Count -ge 2) {
                    $isSuspProc = $true
                    $combP = "$combP strings=$($strHits -join ',')"
                }
            }
        }

        if ($isSuspProc) {
            $ci = Get-CertInfoFast -Path $exe
            $h = Get-Sha256Fast -Path $exe
            Register-Evidence -RawName $pName -RawPath $exe -SourceType "ActiveProcess" `
                -EvidenceText "processo ativo (PID=$($p.ProcessId), PPID=$($p.ParentProcessId))" `
                -IsRunning $true -Sha256 $h -SigStatus $ci.Status -Publisher $ci.Publisher -Timestamp $dt `
                -ExtraDetail "Cmd=$($p.CommandLine)"
            Add-Timeline -TimeStr $dt -Kind "Processo Ativo" -Source "Win32_Process" -Subject $pName -Detail "PID=$($p.ProcessId); $exe"
        }

        if ($pName -match '(?i)(fivem|gta5|gtav)') {
            Add-Timeline -TimeStr $dt -Kind "Sessão FiveM/GTA" -Source "Win32_Process" -Subject $pName -Detail "PID=$($p.ProcessId)"
        }
    }

    # Varrimento de memória (MEM_PRIVATE + PAGE_EXECUTE_READWRITE + strings + threads unbacked)
    $targetProcList = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match '(?i)^(FiveM_GTAProcess|FiveM|explorer|lsass|svchost|GTA5|GTA5_b\d+)$'
    } | Select-Object -First 18

    foreach ($tp in $targetProcList) {
        $procId = [int]$tp.Id
        $procLabel = "$($tp.ProcessName) (PID=$procId)"
        $modRanges = @()
        try {
            foreach ($m in $tp.Modules) {
                $startA = [Int64]$m.BaseAddress
                $endA = $startA + [Int64]$m.ModuleMemorySize
                $modRanges += @{ Start = $startA; End = $endA; Name = $m.ModuleName }
            }
        } catch {}

        # Threads sem módulo válido no disco (unbacked memory)
        try {
            foreach ($th in $tp.Threads) {
                $tid = [int]$th.Id
                $startAddr = [Int64]$th.StartAddress
                if ($startAddr -gt 0) {
                    $inMod = $false
                    foreach ($mr in $modRanges) {
                        if ($startAddr -ge $mr.Start -and $startAddr -lt $mr.End) { $inMod = $true; break }
                    }
                    if (-not $inMod) {
                        $hexAddr = "0x" + $startAddr.ToString("X")
                        Register-Evidence -RawName "unbacked_thread_$($tp.ProcessName)_$tid" -RawPath "MEM://$($tp.ProcessName)/$hexAddr" `
                            -SourceType "MemoryScan" -EvidenceText "thread fora de módulo válido em $procLabel (Start=$hexAddr)" `
                            -IsRunning $true -BonusScore 35
                        Add-Timeline -TimeStr (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Kind "Thread Unbacked" -Source "MemoryScan" -Subject "$($tp.ProcessName):TID$tid" -Detail $hexAddr
                    }
                }
            }
        } catch {}

        # VirtualQueryEx + ReadProcessMemory em regiões MEM_PRIVATE + PAGE_EXECUTE_READWRITE
        $hProc = [Forensics.MkMemNative]::OpenProcess(
            ([Forensics.MkMemNative]::PROCESS_VM_READ -bor [Forensics.MkMemNative]::PROCESS_QUERY_INFORMATION),
            $false, $procId
        )
        if ($hProc -ne [IntPtr]::Zero) {
            try {
                $addr = [IntPtr]::Zero
                $regionsChecked = 0
                $maxAddr = if ([Environment]::Is64BitProcess) { [Int64]0x7FFFFFFFFFFF } else { [Int64]0x7FFF0000 }
                while (([Int64]$addr -lt $maxAddr) -and ($regionsChecked -lt 900)) {
                    $mbi = New-Object Forensics.MkMemNative+MEMORY_BASIC_INFORMATION
                    $vq = [Forensics.MkMemNative]::VirtualQueryEx($hProc, $addr, [ref]$mbi, [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($mbi))
                    if ($vq -le 0) { break }
                    $regionsChecked++

                    $regSize = [Int64]$mbi.RegionSize
                    if ($regSize -le 0) { break }

                    if ($mbi.State -eq [Forensics.MkMemNative]::MEM_COMMIT -and
                        $mbi.Type -eq [Forensics.MkMemNative]::MEM_PRIVATE -and
                        $mbi.Protect -eq [Forensics.MkMemNative]::PAGE_EXECUTE_READWRITE -and
                        $regSize -le 16MB) {
                        $readSize = [int][Math]::Min($regSize, 512KB)
                        $buf = New-Object byte[] $readSize
                        $bytesRead = 0
                        if ([Forensics.MkMemNative]::ReadProcessMemory($hProc, $mbi.BaseAddress, $buf, $readSize, [ref]$bytesRead) -and $bytesRead -gt 16) {
                            $ascMem = [System.Text.Encoding]::ASCII.GetString($buf, 0, $bytesRead)
                            $strMatches = [regex]::Matches($ascMem, $binarySignaturePattern)
                            if ($strMatches.Count -gt 0) {
                                $foundStrs = @($strMatches | ForEach-Object { $_.Value.ToLowerInvariant() } | Select-Object -Unique | Select-Object -First 4)
                                $hexBase = "0x" + ([Int64]$mbi.BaseAddress).ToString("X")
                                $isStrongMem = ($foundStrs -match '(?i)(redengine|eulen|skript|susano|keyauth|fiveguard|spoofer|hwid|pcileech)')
                                Register-Evidence -RawName "rwx_region_$($tp.ProcessName)" -RawPath "MEM://$($tp.ProcessName)/$hexBase" `
                                    -SourceType "MemoryScan" -EvidenceText "memória RWX (MEM_PRIVATE+PAGE_EXECUTE_READWRITE) com strings ($($foundStrs -join ', ')) em $procLabel" `
                                    -IsStrong ([bool]$isStrongMem) -IsRunning $true -BonusScore 100
                                Add-Timeline -TimeStr (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Kind "Memória RWX" -Source "MemoryScan" -Subject $procLabel -Detail "$hexBase -> $($foundStrs -join ', ')"
                            }
                        }
                    }

                    $nextVal = [Int64]$mbi.BaseAddress + $regSize
                    if ($nextVal -le [Int64]$addr) { break }
                    $addr = [IntPtr]$nextVal
                }
            } finally {
                [void][Forensics.MkMemNative]::CloseHandle($hProc)
            }
        }
    }

    $gameProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '(?i)(fivem|gta5|gtav|five|ragemp|altv)' }
    foreach ($gp in $gameProcs) {
        try {
            foreach ($mod in $gp.Modules) {
                $mComb = "$($mod.ModuleName) $($mod.FileName)"
                $mSusp = ($mComb -match $cheatStrongPattern) -or ($mComb -match $cheatMediumPattern)
                if (-not $mSusp -and $mod.FileName -and ($mod.FileName -match '(?i)\\(AppData|Temp|Users\\Public)\\')) {
                    $ciMChk = Get-CertInfoFast -Path $mod.FileName
                    if ($ciMChk.Status -ne "ValidSigned") {
                        $mHits = Test-BinaryHeuristicStrings -Path $mod.FileName
                        if ($mHits.Count -ge 2) { $mSusp = $true; $mComb = "$mComb strings=$($mHits -join ',')" }
                    }
                }
                if ($mSusp) {
                    $ciM = Get-CertInfoFast -Path $mod.FileName
                    $hM = Get-Sha256Fast -Path $mod.FileName
                    Register-Evidence -RawName $mod.ModuleName -RawPath $mod.FileName -SourceType "ActiveProcess" `
                        -EvidenceText "módulo DLL carregado no processo $($gp.ProcessName)" `
                        -IsRunning $true -Sha256 $hM -SigStatus $ciM.Status -Publisher $ciM.Publisher -ExtraDetail $mComb
                }
            }
        } catch { Add-Skipped "Módulos de $($gp.ProcessName)" }
    }

    $drivers = Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue
    foreach ($drv in $drivers) {
        $dPath = $drv.PathName
        $dName = Clean-DisplayName -Name $drv.Name -Path $dPath
        $dComb = "$dName $($drv.DisplayName) $dPath"
        $isRunDrv = ($drv.State -eq "Running")
        if ($dComb -match $cheatStrongPattern -or ($isRunDrv -and ($dComb -match $cheatMediumPattern))) {
            $cleanDrvPath = ($dPath -replace '^\\??\\', '' -replace '^System32\\', "$env:SystemRoot\System32\")
            $ciD = Get-CertInfoFast -Path $cleanDrvPath
            $hD = Get-Sha256Fast -Path $cleanDrvPath
            Register-Evidence -RawName $dName -RawPath $cleanDrvPath -SourceType "SystemDriver" `
                -EvidenceText "driver do sistema (State=$($drv.State), StartMode=$($drv.StartMode))" `
                -IsRunning $isRunDrv -Sha256 $hD -SigStatus $ciD.Status -Publisher $ciD.Publisher
        }
    }
} catch { Add-Skipped "Processos/Memória/Drivers" }

# Coletores de rede / DNS / hosts
try {
    Get-DnsClientCache -ErrorAction SilentlyContinue | ForEach-Object {
        $dnsText = "$($_.Entry) $($_.Data)"
        if ($dnsText -match $cheatStrongPattern -or $dnsText -match '(?i)(keyauth|auth\.gg|fivem.*cheat|spoofer)') {
            Register-Evidence -RawName $_.Entry -RawPath "DNS://$($_.Entry)" -SourceType "NetworkArtifact" `
                -EvidenceText "resolução DNS registada em cache" -IsStrong $true
            Add-Timeline -TimeStr (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Kind "DNS Cache" -Source "DnsClientCache" -Subject $_.Entry -Detail $_.Data
        }
    }
    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    if (Test-Path -LiteralPath $hostsPath) {
        Get-Content -LiteralPath $hostsPath -ErrorAction SilentlyContinue | ForEach-Object {
            $ln = $_.Trim()
            if ($ln -and -not $ln.StartsWith("#") -and ($ln -match $cheatStrongPattern -or $ln -match $cheatMediumPattern)) {
                Register-Evidence -RawName "hosts_redirect" -RawPath $hostsPath -SourceType "NetworkArtifact" `
                    -EvidenceText "entrada suspeita no ficheiro hosts" -ExtraDetail $ln
            }
        }
    }
} catch { Add-Skipped "DNS/Hosts" }

# ==============================================================================
# 2. FICHEIROS, PASTAS FIVEM/GTA V, RECICLAGEM, ADS, TAREFAS & DEFENDER
# ==============================================================================
if ($script:ScanMode -ne "RamModule") {
    Queue-UI -Percent 25 -Text "A analisar ficheiros, assinaturas, Reciclagem e FiveM/GTA V..."
    $seenFiles = @{}
    $extAllowed = '(?i)^\.(exe|dll|sys|bat|cmd|ps1|vbs|js|scr|rar|zip|7z|asi|lua)$'

    function Scan-DirV3 {
        param([string]$Dir, [int]$Depth, [int]$MaxDepth)
        if ($Depth -gt $MaxDepth) { return }
        if (-not $Dir -or ($Dir -match $strictExcludePattern)) { return }

        $script:fileCounter++
        if (($script:fileCounter % 450) -eq 0) {
            $pct = [Math]::Min(55, 25 + [int](($script:fileCounter / 4200.0) * 30))
            Queue-UI -Percent $pct -Text "A analisar ficheiros, assinaturas, Reciclagem e FiveM/GTA V..."
        }

        try {
            $files = [System.IO.Directory]::GetFiles($Dir)
            foreach ($f in $files) {
                if ($f -match $strictExcludePattern) { continue }
                $ext = [System.IO.Path]::GetExtension($f)
                if ($ext -notmatch $extAllowed) { continue }
                $fn = [System.IO.Path]::GetFileName($f)

                $nameMatch = ($fn -match $cheatStrongPattern) -or ($fn -match $cheatMediumPattern) -or ($f -match $cheatStrongPattern)
                $strHits = @()

                if (-not $nameMatch -and ($ext -match '(?i)^\.(exe|dll|sys|asi)$') -and ($f -match '(?i)\\(AppData|Temp|Downloads|Desktop|FiveM|CitizenFX)\\')) {
                    $ciTmp = Get-CertInfoFast -Path $f
                    if ($ciTmp.Status -ne "ValidSigned") {
                        $strHits = Test-BinaryHeuristicStrings -Path $f
                    }
                }

                if (-not $nameMatch -and $strHits.Count -lt 2) { continue }

                $k = $f.ToLowerInvariant()
                if ($seenFiles.ContainsKey($k)) { continue }
                $seenFiles[$k] = $true

                $isRun = $runningPaths.ContainsKey($k)
                $ci = if ($ext -match '(?i)^\.(exe|dll|sys|scr|asi)$') { Get-CertInfoFast -Path $f } else { @{ Status = "N/A"; Publisher = "N/A" } }
                $h = Get-Sha256Fast -Path $f
                $ts = "N/A"
                try { $ts = (New-Object System.IO.FileInfo($f)).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") } catch {}

                $srcType = if ($f -match '(?i)(fivem|gta)') { "FiveMArtifact" } else { "DiskFile" }
                $evText = if ($strHits.Count -ge 2) {
                    "ficheiro em disco com strings suspeitas ($($strHits -join ', '))"
                } else {
                    "ficheiro presente em disco ($srcType)"
                }

                Register-Evidence -RawName $fn -RawPath $f -SourceType $srcType `
                    -EvidenceText $evText `
                    -IsStrong ($strHits.Count -ge 3) `
                    -IsRunning $isRun -Sha256 $h -SigStatus $ci.Status -Publisher $ci.Publisher -Timestamp $ts
                Add-Timeline -TimeStr $ts -Kind "Ficheiro em Disco" -Source $srcType -Subject $fn -Detail $f
            }
        } catch {}

        try {
            $subs = [System.IO.Directory]::GetDirectories($Dir)
            foreach ($s in $subs) {
                if ($s -match $strictExcludePattern) { continue }
                Scan-DirV3 -Dir $s -Depth ($Depth + 1) -MaxDepth $MaxDepth
            }
        } catch {}
    }

    $rootsToUse = if ($script:ScanMode -eq "QuickScan") {
        @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:TEMP", "$env:LOCALAPPDATA")
    } elseif ($script:ScanMode -eq "FiveMOnly") {
        @("$env:LOCALAPPDATA\FiveM", "$env:APPDATA\CitizenFX", "$env:ProgramFiles\Rockstar Games", "${env:ProgramFiles(x86)}\Steam\steamapps\common\Grand Theft Auto V", "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop")
    } else {
        $scanRoots
    }

    foreach ($r in $rootsToUse) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        $md = if ($r -eq 'C:\') { 2 } elseif ($r -match '(?i)\\System32(\\drivers)?$') { 2 } else { 5 }
        Scan-DirV3 -Dir $r -Depth 0 -MaxDepth $md
    }

    # Recycle Bin ($I* metadata para nome original e data de eliminação)
    try {
        $recRoot = 'C:\$Recycle.Bin'
        if (Test-Path -LiteralPath $recRoot) {
            Get-ChildItem -LiteralPath $recRoot -Recurse -Force -Filter '$I*' -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
                    if ($bytes.Length -gt 28) {
                        $orig = [System.Text.Encoding]::Unicode.GetString($bytes, 24, $bytes.Length - 24).TrimEnd([char]0)
                        if ($orig -and ($orig -match $cheatStrongPattern -or $orig -match $cheatMediumPattern)) {
                            $fnR = [System.IO.Path]::GetFileName($orig)
                            $tsR = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                            Register-Evidence -RawName $fnR -RawPath $orig -SourceType "RecycleBin" `
                                -EvidenceText "item encontrado na Reciclagem ($($_.Name))" -IsDeletedOrRenamed $true -Timestamp $tsR
                            Add-Timeline -TimeStr $tsR -Kind "Reciclagem" -Source "RecycleBin" -Subject $fnR -Detail $orig
                        }
                    }
                } catch {}
            }
        }
    } catch { Add-Skipped "Recycle Bin" }

    # Alternate Data Streams (ADS) em Downloads / Desktop / Temp / AppData\Local
    try {
        @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:TEMP", "$env:LOCALAPPDATA") | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object {
            Get-ChildItem -LiteralPath $_ -File -ErrorAction SilentlyContinue | Select-Object -First 300 | ForEach-Object {
                Get-Item -LiteralPath $_.FullName -Stream * -ErrorAction SilentlyContinue | Where-Object { $_.Stream -ne ':$DATA' } | ForEach-Object {
                    $adsComb = "$($_.FileName) $($_.Stream)"
                    if ($adsComb -match $cheatStrongPattern -or $adsComb -match $cheatMediumPattern -or ($_.Stream -notmatch '(?i)^(Zone\.Identifier|OECustomProperty)$')) {
                        Register-Evidence -RawName $_.Stream -RawPath "$($_.FileName):$($_.Stream)" -SourceType "AlternateDataStream" `
                            -EvidenceText "fluxo alternativo de dados (ADS)"
                    }
                }
            }
        }
    } catch { Add-Skipped "Alternate Data Streams" }

    try {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue
        foreach ($tk in $tasks) {
            $tComb = "$($tk.TaskName) $($tk.TaskPath) $(($tk.Actions | ForEach-Object { $_.Execute + ' ' + $_.Arguments }) -join ' ')"
            if ($tComb -match $cheatStrongPattern -or $tComb -match $cheatMediumPattern) {
                Register-Evidence -RawName $tk.TaskName -RawPath $tk.TaskPath -SourceType "Persistence" `
                    -EvidenceText "tarefa agendada suspeita" -ExtraDetail $tComb
            }
        }
    } catch { Add-Skipped "Scheduled Tasks" }

    try {
        $mp = Get-MpPreference -ErrorAction SilentlyContinue
        if ($mp) {
            foreach ($exP in @($mp.ExclusionPath)) {
                if ($exP -and ($exP -match $cheatStrongPattern -or $exP -match $cheatMediumPattern -or $exP -match '(?i)(fivem|temp|appdata)')) {
                    Register-Evidence -RawName ([System.IO.Path]::GetFileName($exP)) -RawPath $exP -SourceType "Persistence" `
                        -EvidenceText "exclusão no Windows Defender"
                }
            }
        }
    } catch { Add-Skipped "Exclusões Windows Defender" }
}

# ==============================================================================
# 3. HISTÓRICO FORENSE: PREFETCH, BAM, LNK/JUMPLISTS, CLEANERS & EVENT LOGS
# ==============================================================================
Queue-UI -Percent 60 -Text "A analisar Prefetch, BAM, Cleaners, Registo e Logs..."
$pfDir = "$env:SystemRoot\Prefetch"
if (Test-Path -LiteralPath $pfDir) {
    try {
        $allPf = @(Get-ChildItem -LiteralPath $pfDir -File -Force -ErrorAction SilentlyContinue)
        if ($allPf.Count -eq 0) {
            Register-Evidence -RawName "empty_prefetch_dir" -RawPath $pfDir -SourceType "AntiForensics" `
                -EvidenceText "pasta Prefetch vazia (possível limpeza/bypass)" -BonusScore 35
            Add-Timeline -TimeStr (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Kind "Bypass Prefetch" -Source "Prefetch" -Subject "Prefetch Vazio" -Detail $pfDir
        } else {
            foreach ($pf in $allPf) {
                $cleanPf = $pf.Name -replace '-[A-F0-9]{8}\.pf$', ''
                $tsPf = $pf.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                $isSuspPf = ($pf.Name -match $cheatStrongPattern) -or ($pf.Name -match $cheatMediumPattern)
                $isRecentPf = ($pf.LastWriteTime -gt (Get-Date).AddHours(-6)) -and ($cleanPf -notmatch '(?i)^(SVCHOST|EXPLORER|RUNTIMEBROKER|SEARCHHOST|DLLHOST|CONHOST|MSEDGE|CHROME|DISCORD|FIVEM|STEAM)$')
                if ($isSuspPf -or $isRecentPf) {
                    Register-Evidence -RawName $cleanPf -RawPath $pf.FullName -SourceType "DeletedOrPrefetch" `
                        -EvidenceText "rasto no Prefetch ($($pf.Name))$(if ($isRecentPf -and -not $isSuspPf) { ' [recente/não-padrão]' })" `
                        -Timestamp $tsPf -BonusScore $(if ($isRecentPf -and -not $isSuspPf) { 15 } else { 0 })
                    Add-Timeline -TimeStr $tsPf -Kind "Execução Prefetch" -Source "Prefetch" -Subject $cleanPf -Detail $pf.FullName
                }
            }
        }
    } catch { Add-Skipped "Prefetch" }
}

# BAM (Background Activity Moderator) com data/hora exata em FILETIME
try {
    Get-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings\*" -ErrorAction SilentlyContinue | ForEach-Object {
        $sidName = $_.PSChildName
        foreach ($vn in $_.GetValueNames()) {
            if ($vn -match '^(SequenceNumber|Version)$') { continue }
            $tsBam = "N/A"
            try {
                $rawVal = $_.GetValue($vn)
                if ($rawVal -is [byte[]] -and $rawVal.Length -ge 8) {
                    $ft = [System.BitConverter]::ToInt64($rawVal, 0)
                    if ($ft -gt 0) {
                        $tsBam = ([DateTime]::FromFileTime($ft)).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
            } catch {}

            $normPath = ($vn -replace '^\\Device\\HarddiskVolume\d+\\', 'C:\')
            $fnBam = [System.IO.Path]::GetFileName($normPath)
            if ([string]::IsNullOrWhiteSpace($fnBam)) { $fnBam = $vn }

            $isMissingBam = ($normPath -match '^[A-Za-z]:\\') -and (-not ([System.IO.File]::Exists($normPath)))
            $isUsbOrTemp = ($normPath -match '(?i)\\(Temp|AppData|Downloads|Desktop)\\')
            $isCheatMatch = ("$fnBam $normPath" -match $cheatStrongPattern) -or ("$fnBam $normPath" -match $cheatMediumPattern)

            if ($isCheatMatch -or ($isMissingBam -and $isUsbOrTemp)) {
                Register-Evidence -RawName $fnBam -RawPath $normPath -SourceType "BamDamUserAssist" `
                    -EvidenceText "rasto BAM (SID=$sidName)$(if ($isMissingBam) { ' [executável ausente do disco]' })" `
                    -IsDeletedOrRenamed $isMissingBam -Timestamp $tsBam
                Add-Timeline -TimeStr $tsBam -Kind "Execução BAM" -Source "BAM" -Subject $fnBam -Detail $normPath
            }
        }
    }
} catch { Add-Skipped "BAM UserSettings" }

# LNK Files & Jump Lists (Recent + AutomaticDestinations)
try {
    $artDirs = @(
        "$env:APPDATA\Microsoft\Windows\Recent",
        "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
    ) | Where-Object { Test-Path -LiteralPath $_ }

    foreach ($aDir in $artDirs) {
        Get-ChildItem -LiteralPath $aDir -File -ErrorAction SilentlyContinue | Select-Object -First 450 | ForEach-Object {
            $rawBytes = [System.IO.File]::ReadAllBytes($_.FullName)
            $asciiStr = [System.Text.Encoding]::ASCII.GetString($rawBytes)
            $uniStr   = [System.Text.Encoding]::Unicode.GetString($rawBytes)
            $lnkComb  = "$($_.Name) $asciiStr $uniStr"
            if ($lnkComb -match $cheatStrongPattern -or $lnkComb -match $cheatMediumPattern) {
                $targetPath = if ($uniStr -match '([A-Za-z]:\\[^\x00-\x1f"]+\.(exe|bat|cmd|ps1|rar|zip|dll))') { $matches[1] } elseif ($asciiStr -match '([A-Za-z]:\\[^\x00-\x1f"]+\.(exe|bat|cmd|ps1|rar|zip|dll))') { $matches[1] } else { $_.FullName }
                $fnLnk = [System.IO.Path]::GetFileName($targetPath)
                if ([string]::IsNullOrWhiteSpace($fnLnk)) { $fnLnk = $_.Name }
                $tsLnk = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                Register-Evidence -RawName $fnLnk -RawPath $targetPath -SourceType "UserArtifacts" `
                    -EvidenceText "atalho/JumpList recente ($($_.Name))" -Timestamp $tsLnk
                Add-Timeline -TimeStr $tsLnk -Kind "Acesso Recente (LNK/JL)" -Source "UserArtifacts" -Subject $fnLnk -Detail $targetPath
            }
        }
    }
} catch { Add-Skipped "LNK / Jump Lists" }

$regForensicPaths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\dam\State\UserSettings\*",
    "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache",
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store",
    "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SYSTEM\CurrentControlSet\Services\*"
)
foreach ($rp in $regForensicPaths) {
    try {
        Get-Item -Path $rp -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($vn in $_.GetValueNames()) {
                $vd = ""
                try { $vd = [string]$_.GetValue($vn) } catch {}
                $combR = "$vn $vd"
                if ($combR -match $cheatStrongPattern -or $combR -match $cheatMediumPattern) {
                    $cand = if ($vd -match '[A-Za-z]:\\') { $vd } else { $vn }
                    $exN = [System.IO.Path]::GetFileName($cand)
                    if ([string]::IsNullOrWhiteSpace($exN)) { $exN = $vn }
                    $isPersist = ($_.PSPath -match '\\Run$|\\Services\\')
                    $sType = if ($isPersist) { "Persistence" } elseif ($_.PSPath -match 'AppCompatCache|Compatibility') { "AmcacheShimcache" } else { "BamDamUserAssist" }
                    Register-Evidence -RawName $exN -RawPath $cand -SourceType $sType `
                        -EvidenceText "registo forense ($sType)" -ExtraDetail "Chave=$($_.PSChildName)"
                }
            }
        }
    } catch { Add-Skipped $rp }
}

# Deteção de Cleaners: Uptime de serviços críticos (PcaSvc, SysMain, EventLog, DiagTrack)
try {
    $critSvcNames = @("PcaSvc", "SysMain", "EventLog", "DiagTrack")
    foreach ($sn in $critSvcNames) {
        $svcObj = Get-CimInstance Win32_Service -Filter "Name='$sn'" -ErrorAction SilentlyContinue
        if ($svcObj) {
            if ($svcObj.State -ne "Running" -and $sn -ne "DiagTrack") {
                Register-Evidence -RawName "service_$sn" -RawPath "SVC://$sn" -SourceType "AntiForensics" `
                    -EvidenceText "serviço crítico $sn parado/inativo (State=$($svcObj.State))" -BonusScore 35
                Add-Timeline -TimeStr (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Kind "Serviço Parado" -Source "Win32_Service" -Subject $sn -Detail "State=$($svcObj.State)"
            }
            $svcProc = Get-CimInstance Win32_Process -Filter "ProcessId=$($svcObj.ProcessId)" -ErrorAction SilentlyContinue
            if ($svcProc -and $svcProc.CreationDate -and $osBootTime) {
                $svcStart = [Management.ManagementDateTimeConverter]::ToDateTime($svcProc.CreationDate)
                $diffSec = ($svcStart - $osBootTime).TotalSeconds
                if ($diffSec -gt 90) {
                    $tsSvc = $svcStart.ToString("yyyy-MM-dd HH:mm:ss")
                    Register-Evidence -RawName "cleaner_svc_$sn" -RawPath "SVC://$sn" -SourceType "AntiForensics" `
                        -EvidenceText "serviço $sn iniciado $([int]$diffSec)s após o boot (Possível uso de Cleaner)" `
                        -Timestamp $tsSvc -BonusScore 50
                    Add-Timeline -TimeStr $tsSvc -Kind "Possível Cleaner (Svc)" -Source "Win32_Service" -Subject $sn -Detail "+$([int]$diffSec)s após boot"
                }
            }
        }
    }
} catch { Add-Skipped "Uptime Serviços Críticos" }

# USN Journal (fsutil usn queryjournal C:)
try {
    $usnOut = & fsutil usn queryjournal C: 2>&1
    if ($LASTEXITCODE -ne 0 -or ($usnOut -join ' ') -match '(?i)(error|not found|denied)') {
        Register-Evidence -RawName "usn_journal_c" -RawPath "C:\`$Extend\`$UsnJrnl" -SourceType "AntiForensics" `
            -EvidenceText "USN Journal indisponível ou apagado em C:" -BonusScore 30
        Add-Timeline -TimeStr (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Kind "USN Journal" -Source "fsutil" -Subject "C:" -Detail "Indisponível ou reiniciado"
    } else {
        $usnText = ($usnOut -join ' ')
        if ($usnText -match 'Usn Journal ID\s*:\s*([0-9a-fA-Fx]+)') {
            Add-Timeline -TimeStr (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Kind "USN Journal Ativo" -Source "fsutil" -Subject "C:" -Detail "JournalID=$($matches[1])"
        }
    }
} catch { Add-Skipped "USN Journal C:" }

# Event Logs: limpeza de logs (1102 Security / 104 System)
try {
    $clearEvts = Get-WinEvent -FilterHashtable @{ LogName = @('Security','System'); Id = @(1102,104) } -MaxEvents 10 -ErrorAction SilentlyContinue
    foreach ($ev in $clearEvts) {
        $tsEv = $ev.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        Register-Evidence -RawName "eventlog_cleared_$($ev.Id)" -RawPath "EventLog://$($ev.LogName)/$($ev.Id)" -SourceType "AntiForensics" `
            -EvidenceText "log $($ev.LogName) limpo (EventID $($ev.Id))" -Timestamp $tsEv -BonusScore 35
        Add-Timeline -TimeStr $tsEv -Kind "Limpeza de Log" -Source $ev.LogName -Subject "EventID $($ev.Id)" -Detail "Possível limpeza de rasto forense"
    }
} catch { Add-Skipped "Event Logs (Security/System)" }

# ==============================================================================
# 3.5 HARDWARE DMA, SECURE BOOT, KERNEL DMA PROTECTION & ENUMERAÇÃO PCIe
# ==============================================================================
Queue-UI -Percent 70 -Text "A verificar Secure Boot, Kernel DMA Protection e barramento PCIe..."

# 1) Estado do Secure Boot
try {
    $sbEnabled = $null
    try {
        $sbCmd = Confirm-SecureBootUEFI -ErrorAction Stop
        $sbEnabled = [bool]$sbCmd
    } catch {
        $sbRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State"
        if (Test-Path -LiteralPath $sbRegPath) {
            $sbVal = (Get-ItemProperty -LiteralPath $sbRegPath -Name "UEFISecureBootEnabled" -ErrorAction SilentlyContinue).UEFISecureBootEnabled
            if ($null -ne $sbVal) { $sbEnabled = ([int]$sbVal -eq 1) }
        }
    }

    if ($sbEnabled -eq $true) {
        $script:DmaBootStatus.SecureBootEstado = "Ativado (UEFI Secure Boot ON)"
    } elseif ($sbEnabled -eq $false) {
        $script:DmaBootStatus.SecureBootEstado = "DESATIVADO (Alerta Amarelo)"
        $script:DmaBootStatus.SecureBootAlerta = $true
        Register-Evidence -RawName "secureboot_disabled" -RawPath "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" `
            -SourceType "HardwareDmaBoot" -EvidenceText "Secure Boot desativado (alerta amarelo: requer verificação visual/câmara)" -BonusScore 15
        Add-Timeline -TimeStr (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Kind "Secure Boot OFF" -Source "SecureBoot" -Subject "UEFISecureBootEnabled=0" -Detail "Alerta amarelo anti-bootkit/DMA"
    } else {
        $script:DmaBootStatus.SecureBootEstado = "Não suportado / Legacy BIOS (Alerta Amarelo)"
        $script:DmaBootStatus.SecureBootAlerta = $true
        Register-Evidence -RawName "secureboot_unsupported" -RawPath "UEFI://SecureBoot" `
            -SourceType "HardwareDmaBoot" -EvidenceText "Secure Boot não suportado ou modo Legacy BIOS (alerta amarelo)" -BonusScore 15
    }
} catch { Add-Skipped "Secure Boot" }

# 2) Kernel DMA Protection e Virtualização (IOMMU / VT-d / VBS)
try {
    $dgWmi = Get-CimInstance -Namespace "root\Microsoft\Windows\DeviceGuard" -ClassName "Win32_DeviceGuard" -ErrorAction SilentlyContinue
    $csWmi = Get-CimInstance -ClassName "Win32_ComputerSystem" -ErrorAction SilentlyContinue
    $dgReg = Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -ErrorAction SilentlyContinue

    $vbsStatus = if ($dgWmi) { [int]$dgWmi.VirtualizationBasedSecurityStatus } else { -1 }
    $secRunning = if ($dgWmi -and $dgWmi.SecurityServicesRunning) { @($dgWmi.SecurityServicesRunning) } else { @() }
    $regVbs = if ($dgReg -and $null -ne $dgReg.EnableVirtualizationBasedSecurity) { [int]$dgReg.EnableVirtualizationBasedSecurity } else { -1 }
    $hvPresent = if ($csWmi) { [bool]$csWmi.HypervisorPresent } else { $false }

    $script:DmaBootStatus.VbsEstado = switch ($vbsStatus) {
        2 { "Em execução (VBS Ativo)" }
        1 { "Ativado mas não em execução" }
        0 { "Desativado" }
        default { if ($regVbs -eq 1) { "Configurado no Registo" } else { "Indisponível/Desativado" } }
    }

    $hasKernelDma = ($secRunning -contains 7) -or ($vbsStatus -eq 2 -and $hvPresent)
    if ($hasKernelDma) {
        $script:DmaBootStatus.KernelDmaEstado = "Ativo (IOMMU / DMA Protection ON)"
    } else {
        $script:DmaBootStatus.KernelDmaEstado = "Desativado / Bloqueado na BIOS (Alerta Amarelo)"
        $script:DmaBootStatus.DmaProtectionAlerta = $true
        Register-Evidence -RawName "kernel_dma_protection_off" -RawPath "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" `
            -SourceType "HardwareDmaBoot" -EvidenceText "Kernel DMA Protection / VBS desativado ou sem IOMMU ativo (alerta amarelo: requer verificação física)" -BonusScore 15
    }
} catch { Add-Skipped "DeviceGuard / Kernel DMA Protection" }

# 3) Enumeração de Dispositivos PCIe Suspeitos (Placas DMA / Firmwares Clonados)
try {
    $pciDevices = @(Get-CimInstance -ClassName "Win32_PnPEntity" -Filter "DeviceID LIKE 'PCI\\%'" -ErrorAction SilentlyContinue)
    $netAdapters = @(Get-CimInstance -ClassName "Win32_NetworkAdapter" -ErrorAction SilentlyContinue)
    $nicMapByPnp = @{}
    foreach ($na in $netAdapters) {
        if ($na.PNPDeviceID) { $nicMapByPnp[$na.PNPDeviceID.ToUpperInvariant()] = $na }
    }

    $nicCountByModel = @{}

    foreach ($dev in $pciDevices) {
        $pnpId = [string]$dev.DeviceID
        $devName = [string]$dev.Name
        $errCode = [int]$dev.ConfigManagerErrorCode

        $vid = "N/A"; $pidHex = "N/A"; $subsys = "N/A"
        if ($pnpId -match 'VEN_([0-9A-Fa-f]{4})') { $vid = $matches[1].ToUpperInvariant() }
        if ($pnpId -match 'DEV_([0-9A-Fa-f]{4})') { $pidHex = $matches[1].ToUpperInvariant() }
        if ($pnpId -match 'SUBSYS_([0-9A-Fa-f]{8})') { $subsys = $matches[1].ToUpperInvariant() }

        $regService = "N/A"
        $regPciPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId"
        if (Test-Path -LiteralPath $regPciPath) {
            $pProps = Get-ItemProperty -LiteralPath $regPciPath -ErrorAction SilentlyContinue
            if ($pProps -and $pProps.Service) { $regService = [string]$pProps.Service }
        }

        if ($devName -match '(?i)(Realtek PCIe|Intel\(R\) Ethernet|Network|Gigabit)') {
            $mKey = $devName.ToLowerInvariant().Trim()
            if (-not $nicCountByModel.ContainsKey($mKey)) { $nicCountByModel[$mKey] = 0 }
            $nicCountByModel[$mKey]++
        }

        $isFpgaOrDma = ($devName -match '(?i)(Xilinx|Lattice|FTDI|PCIeLeech|Screamer|FPGA)') -or ($vid -in @("10EE", "1134", "0403", "1172"))
        if ($isFpgaOrDma) {
            $msgFpga = "Placa FPGA/DMA detetada: $devName (VID=$vid, PID=$pidHex, SUBSYS=$subsys, Svc=$regService)"
            $script:DmaBootStatus.PcieAnomalias.Add($msgFpga)
            $script:DmaBootStatus.RequerCamaraPcie = $true
            Register-Evidence -RawName "pcie_dma_fpga_${vid}_${pidHex}" -RawPath $pnpId `
                -SourceType "HardwareDmaBoot" -EvidenceText $msgFpga -IsStrong $true -BonusScore 75
            Add-Timeline -TimeStr (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Kind "Hardware FPGA/DMA" -Source "Enum\PCI" -Subject $devName -Detail "VID=$vid PID=$pidHex"
        }

        if ($errCode -ne 0) {
            $msgNoDrv = "Dispositivo PCIe com erro/sem driver (Código $errCode): $devName (VID=$vid, PID=$pidHex, SUBSYS=$subsys)"
            $script:DmaBootStatus.PcieAnomalias.Add($msgNoDrv)
            $script:DmaBootStatus.RequerCamaraPcie = $true
            Register-Evidence -RawName "pcie_err_${errCode}_${vid}_${pidHex}" -RawPath $pnpId `
                -SourceType "HardwareDmaBoot" -EvidenceText $msgNoDrv -BonusScore 40
            Add-Timeline -TimeStr (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Kind "PCIe Sem Driver" -Source "Win32_PnPEntity" -Subject $devName -Detail "ErrCode=$errCode"
        }

        $nicEntry = $nicMapByPnp[$pnpId.ToUpperInvariant()]
        if ($nicEntry -and ($devName -match '(?i)(Realtek PCIe GBE|Realtek PCIe FE|Intel\(R\) Ethernet|Intel\(R\) PRO/1000)')) {
            $isDisabledNic = ($nicEntry.ConfigManagerErrorCode -eq 22) -or ($nicEntry.NetEnabled -eq $false)
            if ($isDisabledNic) {
                $msgNic = "Adaptador Ethernet PCIe desativado (possível firmware DMA clonado): $devName (VID=$vid, PID=$pidHex, SUBSYS=$subsys)"
                $script:DmaBootStatus.PcieAnomalias.Add($msgNic)
                $script:DmaBootStatus.RequerCamaraPcie = $true
                Register-Evidence -RawName "pcie_spoof_nic_${vid}_${pidHex}" -RawPath $pnpId `
                    -SourceType "HardwareDmaBoot" -EvidenceText $msgNic -BonusScore 35
            }
        }
    }

    foreach ($kvNic in $nicCountByModel.GetEnumerator()) {
        if ($kvNic.Value -ge 2) {
            $msgDup = "Adaptador de rede PCIe duplicado ($($kvNic.Value)x): $($kvNic.Key)"
            $script:DmaBootStatus.PcieAnomalias.Add($msgDup)
            $script:DmaBootStatus.RequerCamaraPcie = $true
            Register-Evidence -RawName "pcie_duplicate_nic" -RawPath "PCI://DuplicateNIC" `
                -SourceType "HardwareDmaBoot" -EvidenceText $msgDup -BonusScore 35
        }
    }
} catch { Add-Skipped "Enumeração PCIe / Hardware DMA" }

if (-not (Test-Path -LiteralPath "$env:SystemRoot\AppCompat\Programs\Amcache.hve")) {
    Add-Skipped "Amcache.hve (não acessível/ausente)"
}
Add-Skipped "Memória física bruta / Kernel não-paginado / MFT direto (requer driver kernel próprio)"

# ==============================================================================
# 4. RASTOS LOCAIS DE DISCORD (PRESENÇA / HISTÓRICO E QUANDO)
# ==============================================================================
Queue-UI -Percent 80 -Text "A verificar presença/histórico em Discords de cheats..."
$discordLocalDirs = @(
    "$env:APPDATA\discord\Local Storage\leveldb",
    "$env:APPDATA\discord\Session Storage",
    "$env:APPDATA\discord\Cache\Cache_Data",
    "$env:APPDATA\discord\logs",
    "$env:APPDATA\discordptb\Local Storage\leveldb",
    "$env:APPDATA\discordcanary\Local Storage\leveldb"
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

if ($discordLocalDirs.Count -eq 0) {
    Add-Skipped "Dados locais do Discord (não encontrados)"
} else {
    $seenD = @{}
    foreach ($dDir in $discordLocalDirs) {
        try {
            $dFiles = Get-ChildItem -LiteralPath $dDir -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -lt 15MB -and $_.Extension -match '(?i)\.(ldb|log|txt|json|dat|0|1|2|3|4|5|6|7|8|9)$' } |
                Sort-Object LastWriteTime -Descending | Select-Object -First 45
            foreach ($df in $dFiles) {
                $contentText = ""
                try {
                    $bytes = [System.IO.File]::ReadAllBytes($df.FullName)
                    $sb = New-Object System.Text.StringBuilder
                    foreach ($b in $bytes) {
                        if (($b -ge 32 -and $b -le 126) -or $b -eq 10 -or $b -eq 13) { [void]$sb.Append([char]$b) }
                        else { [void]$sb.Append(' ') }
                    }
                    $contentText = $sb.ToString()
                } catch {}
                if (-not $contentText) { continue }

                foreach ($m in [regex]::Matches($contentText, $discordCheatPattern)) {
                    $term = $m.Value.ToLowerInvariant().Trim()
                    if ([string]::IsNullOrWhiteSpace($term)) { continue }
                    $idx = $m.Index
                    $startIdx = [Math]::Max(0, $idx - 30)
                    $lenCtx = [Math]::Min($contentText.Length - $startIdx, $m.Length + 60)
                    $snippet = (($contentText.Substring($startIdx, $lenCtx) -replace '\s+', ' ') -replace '[\r\n`\*_~|]', '').Trim()
                    if ($snippet.Length -gt 65) { $snippet = $snippet.Substring(0, 62) + "..." }
                    $tsStr = $df.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                    $kD = "$term|$tsStr"
                    if ($seenD.ContainsKey($kD)) { continue }
                    $seenD[$kD] = $true

                    $script:DiscordTraces.Enqueue([pscustomobject]@{
                        Termo    = $term
                        DataHora = $tsStr
                        Origem   = "$($df.Directory.Name)\$($df.Name)"
                        Contexto = $snippet
                    })
                }
            }
        } catch { Add-Skipped "Discord ($dDir)" }
    }
    Add-Skipped "Servidores remotos do Discord / sessões web (requer API/token da conta)"
}

# ==============================================================================
# 5. CONSOLIDAÇÃO CORRELACIONADA, TIMELINE & RELATÓRIO (COM HTML + CSV)
# ==============================================================================
Queue-UI -Percent 90 -Text "A correlacionar evidências e gerar relatório..."
$scoredList = @()
foreach ($kv in $script:CorrelationMap.GetEnumerator()) {
    $scored = Score-CorrelatedRecord -rec $kv.Value
    if ($scored.Score -ge $script:Threshold) {
        $scoredList += $scored
    }
}

$topFindings = @($scoredList | Sort-Object Score -Descending | Select-Object -First $script:MaxResults)
$discordList = @($script:DiscordTraces.ToArray() | Sort-Object DataHora -Descending | Select-Object -First 12)
$timelineTop = @($script:TimelineEvents.ToArray() | Sort-Object DataHora -Descending | Select-Object -First 15)

$pcName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { "PC" }
$userName = if ($env:USERNAME) { $env:USERNAME } else { "Utilizador" }
$dateStr = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

$tempHtml = Join-Path $env:TEMP "MkChecks_v36_${pcName}_$(Get-Date -Format yyyyMMdd_HHmmss).html"
$rowsHtml = ($topFindings | ForEach-Object {
    "<tr><td><strong>$([System.Net.WebUtility]::HtmlEncode($_.Nome))</strong></td><td>$($_.Score)/100 ($([System.Net.WebUtility]::HtmlEncode($_.RiskLabel)))</td><td>$([System.Net.WebUtility]::HtmlEncode($_.Categoria))</td><td>$([System.Net.WebUtility]::HtmlEncode($_.Fontes))</td><td>$([System.Net.WebUtility]::HtmlEncode($_.ApagadoRenomeado))</td><td>$([System.Net.WebUtility]::HtmlEncode($_.Assinatura))</td><td>$([System.Net.WebUtility]::HtmlEncode($_.DataHora))</td><td><code>$([System.Net.WebUtility]::HtmlEncode($_.Caminho))</code></td><td><code>$([System.Net.WebUtility]::HtmlEncode($_.SHA256Short))</code></td><td>$([System.Net.WebUtility]::HtmlEncode($_.Evidencias))</td></tr>"
}) -join "`n"
$dmaSummaryHtml = "<p><strong>Secure Boot:</strong> $([System.Net.WebUtility]::HtmlEncode($script:DmaBootStatus.SecureBootEstado)) | <strong>Kernel DMA:</strong> $([System.Net.WebUtility]::HtmlEncode($script:DmaBootStatus.KernelDmaEstado)) | <strong>VBS:</strong> $([System.Net.WebUtility]::HtmlEncode($script:DmaBootStatus.VbsEstado))</p>"
$htmlDoc = @"
<!DOCTYPE html><html><head><meta charset='utf-8'><title>MkChecks v3.6 — $pcName</title>
<style>body{background:#0c0a12;color:#f5f3ff;font-family:Segoe UI,Arial,sans-serif;padding:24px}h1{color:#c084fc}table{width:100%;border-collapse:collapse;margin-top:16px}th,td{border:1px solid #2e2447;padding:8px;font-size:12px;text-align:left}th{background:#181226;color:#c084fc}code{color:#a78bfa}</style></head>
<body><h1>MkChecks v3.6 — Relatório Forense ($pcName)</h1><p>Utilizador: <strong>$userName</strong> | Data: <strong>$dateStr</strong> | Modo: <strong>$($script:ScanMode)</strong></p>$dmaSummaryHtml
<table><thead><tr><th>Artefacto</th><th>Risco</th><th>Categoria</th><th>Fontes</th><th>Apagado/Ren.</th><th>Assinatura</th><th>Data/Hora</th><th>Caminho</th><th>SHA256</th><th>Evidências</th></tr></thead><tbody>$rowsHtml</tbody></table></body></html>
"@
try { $htmlDoc | Out-File -LiteralPath $tempHtml -Encoding UTF8 } catch {}

Queue-UI -Percent 96 -Text "A enviar relatório para o Discord..."
try {
    if (-not [string]::IsNullOrWhiteSpace($script:WebhookUrl)) {
        $sections = New-Object System.Collections.Generic.List[string]
        $sections.Add("**Utilizador:** ``$userName``  •  **PC:** ``$pcName``  •  **Modo:** ``$($script:ScanMode)``")
        $sections.Add("**Data da Análise:** $dateStr")
        $sections.Add("")

        $sections.Add("### 🎯 Correlações Forenses ($($topFindings.Count))")
        if ($topFindings.Count -eq 0) {
            $sections.Add("• Nenhuma correlação acima do limiar ($($script:Threshold)/100) detetada.")
        } else {
            foreach ($f in $topFindings) {
                $pShort = if ($f.Caminho -ne "N/A" -and $f.Caminho.Length -gt 62) { "..." + $f.Caminho.Substring($f.Caminho.Length - 59) } else { $f.Caminho }
                $sections.Add("• **``$($f.Nome)``** — **$($f.Score)/100** (*$($f.RiskLabel)* | $($f.Categoria))")
                $sections.Add("  ↳ **Fontes:** $($f.Fontes)  •  **Apagado/Renomeado:** $($f.ApagadoRenomeado)  •  **Quando:** $($f.DataHora)")
                $sections.Add("  ↳ **Caminho:** ``$pShort``  •  **SHA256:** ``$($f.SHA256Short)``  •  **Sig:** $($f.Assinatura)")
                $sections.Add("  ↳ **Evidências:** $($f.Evidencias)")
                $sections.Add("")
            }
        }

        $sections.Add("### 🛡️ Integridade de Arranque, DMA & PCIe")
        $sections.Add("• **Secure Boot:** $($script:DmaBootStatus.SecureBootEstado)")
        $sections.Add("• **Kernel DMA / VBS:** $($script:DmaBootStatus.KernelDmaEstado) ($($script:DmaBootStatus.VbsEstado))")
        if ($script:DmaBootStatus.PcieAnomalias.Count -gt 0) {
            foreach ($pa in ($script:DmaBootStatus.PcieAnomalias | Select-Object -First 5)) {
                $sections.Add("• **Anomalia PCIe:** $pa")
            }
        } else {
            $sections.Add("• **Barramento PCIe:** Sem placas FPGA/DMA ou dispositivos sem driver detetados.")
        }
        if ($script:DmaBootStatus.SecureBootAlerta -or $script:DmaBootStatus.DmaProtectionAlerta -or $script:DmaBootStatus.RequerCamaraPcie) {
            $sections.Add("• ⚠️ **Recomendação Staff (Alerta Amarelo):** Pedir partilha de câmara (telemóvel) a mostrar a traseira da torre do PC e o Gestor de Dispositivos antes de decidir.")
        }
        $sections.Add("")

        $discordRunning = (@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '(?i)^discord' }).Count -gt 0)
        $presencaEstado = if ($discordList.Count -gt 0) {
            if ($discordRunning) { "Rasto local detetado (Discord ativo / histórico recente)" } else { "Rasto local detetado (histórico anterior / cache)" }
        } else {
            "Nenhum rasto local detetado"
        }
        $sections.Add("### 💬 Presença / Histórico em Discords de Cheats ($($discordList.Count))")
        $sections.Add("• **Estado local:** $presencaEstado")
        if ($discordList.Count -eq 0) {
            $sections.Add("• **Quando:** Sem data/hora local registada para comunidades/termos de cheats.")
        } else {
            foreach ($d in $discordList) {
                $sections.Add("• **Termo/Comunidade:** ``$($d.Termo)``  |  **Quando:** $($d.DataHora)")
                $sections.Add("  ↳ **Origem:** ``$($d.Origem)``  •  **Trecho:** ``$($d.Contexto)``")
                $sections.Add("")
            }
        }

        if ($timelineTop.Count -gt 0) {
            $sections.Add("### 🕒 Timeline Recente (Amostra)")
            foreach ($tl in ($timelineTop | Select-Object -First 6)) {
                $sections.Add("• **$($tl.DataHora)** — [$($tl.Tipo)] ``$($tl.Alvo)``")
            }
            $sections.Add("")
        }

        $skippedList = @($script:SkippedSources.ToArray() | Select-Object -Unique)
        $sections.Add("### ⚠️ Limitações e Fontes")
        if ($skippedList.Count -gt 0) {
            $sections.Add("• Fontes não analisadas a fundo: " + ($skippedList -join "; "))
        }
        $sections.Add("• A pontuação mede correlação de indicadores (não probabilidade) e a ausência de deteção não garante que o PC esteja limpo.")

        $desc = ($sections -join "`n")
        if ($desc.Length -gt 3950) {
            $desc = $desc.Substring(0, 3915) + "`n`n... *(ver CSV/HTML completos)*"
        }

        $tempCsv = Join-Path $env:TEMP "MkChecks_v36_${pcName}_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
        if ($topFindings.Count -gt 0 -or $discordList.Count -gt 0) {
            $topFindings | Export-Csv -LiteralPath $tempCsv -NoTypeInformation -Encoding UTF8
        } else {
            "Sem correlacoes acima do limiar em $pcName ($userName) em $dateStr | SecureBoot=$($script:DmaBootStatus.SecureBootEstado) | KernelDMA=$($script:DmaBootStatus.KernelDmaEstado)" | Out-File -LiteralPath $tempCsv -Encoding UTF8
        }

        $embedColor = if ($topFindings.Count -gt 0 -or $discordList.Count -gt 0 -or $script:DmaBootStatus.RequerCamaraPcie) { 10181046 } else { 7419530 }
        $payload = @{
            username = "MkChecks v3.6"
            embeds   = @(
                @{
                    title       = "Relatório Forense MkChecks v3.6 — $pcName"
                    description = $desc
                    color       = $embedColor
                    footer      = @{ text = "MkChecks v3.6 • Apenas leitura • Relatório HTML guardado em %TEMP%" }
                }
            )
        } | ConvertTo-Json -Depth 6 -Compress

        $sentOk = $false
        try {
            Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
            $hc = New-Object System.Net.Http.HttpClient
            $mc = New-Object System.Net.Http.MultipartFormDataContent
            $mc.Add((New-Object System.Net.Http.StringContent($payload, [System.Text.Encoding]::UTF8, "application/json")), "payload_json")
            $fb = [System.IO.File]::ReadAllBytes($tempCsv)
            $bc = New-Object System.Net.Http.ByteArrayContent(,$fb)
            $bc.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("text/csv")
            $mc.Add($bc, "file", [System.IO.Path]::GetFileName($tempCsv))
            $resp = $hc.PostAsync($script:WebhookUrl, $mc).Result
            $sentOk = $resp.IsSuccessStatusCode
            if (-not $sentOk) {
                "Multipart HTTP $([int]$resp.StatusCode): $($resp.ReasonPhrase)" | Out-File -LiteralPath (Join-Path $env:TEMP "MkChecks_last_error.txt") -Encoding UTF8
            }
            $hc.Dispose()
        } catch {
            "Multipart exception: $($_.Exception.Message)" | Out-File -LiteralPath (Join-Path $env:TEMP "MkChecks_last_error.txt") -Encoding UTF8
        }

        if (-not $sentOk) {
            Invoke-RestMethod -Uri $script:WebhookUrl -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -ContentType "application/json; charset=utf-8" -ErrorAction Stop
            Remove-Item -LiteralPath (Join-Path $env:TEMP "MkChecks_last_error.txt") -Force -ErrorAction SilentlyContinue
        }

        Remove-Item -LiteralPath $tempCsv -Force -ErrorAction SilentlyContinue
    }
} catch {
    "Webhook final error: $($_.Exception.Message)" | Out-File -LiteralPath (Join-Path $env:TEMP "MkChecks_last_error.txt") -Encoding UTF8
}

Queue-UI -Percent 100 -Text "Análise forense v3.6 concluída" -SubText "Relatório enviado e HTML guardado em %TEMP%"
'@

$script:PsInstance.AddScript($workerScript) | Out-Null
$script:AsyncResult = $script:PsInstance.BeginInvoke()

$uiTimer = New-Object System.Windows.Forms.Timer
$uiTimer.Interval = 120
$uiTimer.Add_Tick({
    Apply-QueuedUI
    if ($script:AsyncResult.IsCompleted) {
        $uiTimer.Stop()
        Apply-QueuedUI
        try {
            $script:PsInstance.EndInvoke($script:AsyncResult) | Out-Null
            $script:PsInstance.Dispose()
            $script:Runspace.Close()
            $script:Runspace.Dispose()
        } catch {}
    }
})

$form.Add_Shown({
    if ($script:AutoRunAndSend) {
        $uiTimer.Start()
    }
})

$form.Add_FormClosed({
    try { $uiTimer.Stop() } catch {}
    try { if ($script:PsInstance) { $script:PsInstance.Dispose() } } catch {}
    try { if ($script:Runspace) { $script:Runspace.Close(); $script:Runspace.Dispose() } } catch {}
})

[void]$form.ShowDialog()
