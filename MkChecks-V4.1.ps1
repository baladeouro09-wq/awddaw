# ==============================================================================
# MkChecks Forensic Scanner v4.1 - Compact Card (Preto & Roxo) + Deep Forensics
# Apenas leitura. Não apaga ficheiros, não altera registo nem desativa segurança.
# ==============================================================================

# Opcional: define via variável de ambiente $env:MKCHECKS_WEBHOOK_URL ou preenche localmente
$script:WebhookUrl = if ($env:MKCHECKS_WEBHOOK_URL) { $env:MKCHECKS_WEBHOOK_URL } else { "" } # Upload desativado por defeito; configurar explicitamente para ativar
$script:AutoRunAndSend = $true

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Drawing.Text
Add-Type -AssemblyName System.Net.Http
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try { [System.Windows.Forms.Application]::EnableVisualStyles() } catch {}

# Modos disponíveis: "FullForensic", "QuickScan", "FiveMOnly", "RamModule"
$script:ScanMode = "FullForensic"
$script:Threshold = 45
$script:MaxResults = 40

# Padrões fortes: cheats, spoofers, loaders, injectors, bypass pagos, DMA e drivers abusados
$cheatStrongPattern = '(?i)(fivem[-_ ]?exeternal|fivem[-_ ]?external|aimbot|wallhack|wall[-_ ]?hack|hwid[-_ ]?spoofer|hwid[-_ ]?spoof|spoofer|mod[-_ ]?menu|triggerbot|silent[-_ ]?aim|ragebot|redengine|eulen|skript\.gg|lynx|lumia|tz[-_ ]?project|hx[-_ ]?cheats|desudo|brutan|kekhack|interwebz|neverlose|onetap|gamesense|skeet|fatality|aimware|iniuria|vape[-_ ]?v4|wurst|meteor[-_ ]?client|aristois|xenos|extreme[-_ ]?injector|process[-_ ]?hacker|kdmapper|drvmap|gdrv\.sys|capcom\.sys|iqvw64e\.sys|dsefix|winring0|anticheat[-_ ]?bypass|ac[-_ ]?bypass|cleaner[-_ ]?fivem|unban[-_ ]?fivem|aimlock|spinbot|esp[-_ ]?hack|radar[-_ ]?hack|norecoil|no[-_ ]?spread|keyauth|fiveguard[-_ ]?bypass|phantom|macho|susano|tarkov|cs2[-_ ]?cheat|hyperion[-_ ]?bypass|pcileech|screamer[-_ ]?dma|enigma[-_ ]?dma|captain[-_ ]?dma|leetdma|d3d[-_ ]?dma|zandon|p4wn|memprocfs|vmm\.dll|leechcore|leet[-_ ]?spoofer|perm[-_ ]?spoofer|temp[-_ ]?spoofer|fivem[-_ ]?cleaner|trace[-_ ]?cleaner|fxserver[-_ ]?bypass|txadmin[-_ ]?bypass|anticheat[-_ ]?killer|executor[-_ ]?fivem|lua[-_ ]?executor|godmode|noclip|eac[-_ ]?bypass|battleye[-_ ]?bypass|vanguard[-_ ]?bypass|spoof[-_ ]?disk|spoof[-_ ]?mac|spoof[-_ ]?smbios|rust[-_ ]?cheat|valorant[-_ ]?cheat|apex[-_ ]?cheat|fortnite[-_ ]?cheat|midnight|nixware|primordial|aimstar|furia|memesense|ezfrags|osiris|mutiny|supremacy)'

# Padrões médios: técnicas de injeção, mapeamento em memória, loaders genéricos e evasão
$cheatMediumPattern = '(?i)(manual[-_ ]?map|reflective[-_ ]?dll|process[-_ ]?hollowing|dll[-_ ]?inject|offset[-_ ]?finder|cheat[-_ ]?engine|artmoney|wemod|recoil[-_ ]?script|no[-_ ]?recoil|kernel[-_ ]?drv|injector|loader|bypass|cleaner|hwid|unban|fiveguard|mapper|overlay|hook|aim|esp|fpga|xilinx|ftdi|lattice|dma|smbios|mac[-_ ]?changer|serial[-_ ]?changer|dumper|decrypt)'

# Padrões específicos de artefactos FiveM / GTA V / loaders / cleaners / dumps
$fivemForensicPattern = '(?i)(citizenfx|fivem|gta5|gtav|crashpad|adhesive|fiveguard|redengine|eulen|skript|lynx|lumia|susano|phantom|macho|spoofer|hwid|cleaner|unban|loader|injector|ragemp|altv)'

# Padrões para rastos locais do Discord (inclui convites discord.gg / discordapp.com/invite)
$discordCheatPattern = '(?i)(redengine|eulen|skript\.gg|lynx|lumia|tz[-_ ]?project|hx[-_ ]?cheats|fivem[-_ ]?external|fivem[-_ ]?exeternal|hwid[-_ ]?spoofer|spoofer|unban[-_ ]?fivem|cleaner[-_ ]?fivem|anticheat[-_ ]?bypass|cheat[-_ ]?fivem|mod[-_ ]?menu|aimbot|wallhack|silent[-_ ]?aim|triggerbot|xenos|extreme[-_ ]?injector|kdmapper|fiveguard[-_ ]?bypass|keyauth|cheat|cheats|bypass|loader|spoofer|pcileech|dma|executor|injector|cleaner|perm[-_ ]?spoofer|temp[-_ ]?spoofer|macho|susano|phantom|d3d[-_ ]?dma|memprocfs|discord\.gg/[a-zA-Z0-9-]+|discordapp\.com/invite/[a-zA-Z0-9-]+)'

# Padrões de strings/assinaturas internas em executáveis/DLLs/scripts e memória RWX
$binarySignaturePattern = '(?i)(keyauth\.win|api\.keyauth|manualmap|ntcreatethreadex|writeprocessmemory|virtualallocex|setwindowshookex|d3d11|present_hook|fivem\.exe|citizenfx|fiveguard|bypass|spoofer|hwid|redengine|eulen|skript|susano|pcileech|memprocfs|vmm\.dll|leechcore|kdmapper|drvmap|zwunmapviewofsection|ntmapviewofsection|rtlcreateuserthread|loadlibrarya|getprocaddress)'

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
$script:DiscordTraces = [System.Collections.Concurrent.ConcurrentQueue[pscustomobject]]::new()
$script:TimelineEvents = [System.Collections.Concurrent.ConcurrentQueue[pscustomobject]]::new()
$script:SkippedSources = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$script:FinalFindings = [System.Collections.Concurrent.ConcurrentQueue[pscustomobject]]::new()

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
    try {
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    } catch {
        try { $g.TextRenderingHint = [System.Drawing.TextRenderingHint]::AntiAliasGridFit } catch {}
    }

    $rectAll = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
    $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(12, 10, 18))
    $g.FillRectangle($bgBrush, $rectAll)

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
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 243, 255))
    $g.DrawString("MkChecks", $fontBrand, $textBrush, $textRect, $sf)

    $textBrush.Dispose()
    $fontBrand.Dispose()
    $sf.Dispose()
    $penMain.Dispose()
    $penGlow.Dispose()
    $pgr.Dispose()
    $pathGlow.Dispose()
    $bgBrush.Dispose()
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
$form.Text = "MkChecks V4.1"
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
$lblStatus.Text = "A preparar investigação forense v4.1... (0%)"
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

$lblSub = New-Object System.Drawing.Label
$lblSub.Text = "Correlação forense em curso — não feche esta janela"
$lblSub.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblSub.ForeColor = $textGray
$lblSub.Location = New-Object System.Drawing.Point(16, 78)
$lblSub.Size = New-Object System.Drawing.Size(356, 20)
$card.Controls.Add($lblSub)

$lblFoot = New-Object System.Drawing.Label
$lblFoot.Text = "MkChecks V4.1 • Investigação Forense FiveM, Hardware & Anti-Forensics"
$lblFoot.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblFoot.ForeColor = [System.Drawing.Color]::FromArgb(124, 111, 163)
$lblFoot.Location = New-Object System.Drawing.Point(16, 124)
$lblFoot.Size = New-Object System.Drawing.Size(356, 20)
$lblFoot.TextAlign = "MiddleCenter"
$card.Controls.Add($lblFoot)

# ==============================================================================
# WORKER FORENSE v4.0
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
$script:Runspace.SessionStateProxy.SetVariable("fivemForensicPattern", $fivemForensicPattern)
$script:Runspace.SessionStateProxy.SetVariable("discordCheatPattern", $discordCheatPattern)
$script:Runspace.SessionStateProxy.SetVariable("binarySignaturePattern", $binarySignaturePattern)
$script:Runspace.SessionStateProxy.SetVariable("strictExcludePattern", $strictExcludePattern)
$script:Runspace.SessionStateProxy.SetVariable("scanRoots", $scanRoots)
$script:Runspace.SessionStateProxy.SetVariable("UiQueue", $script:UiQueue)
$script:Runspace.SessionStateProxy.SetVariable("DiscordTraces", $script:DiscordTraces)
$script:Runspace.SessionStateProxy.SetVariable("TimelineEvents", $script:TimelineEvents)
$script:Runspace.SessionStateProxy.SetVariable("SkippedSources", $script:SkippedSources)
$script:Runspace.SessionStateProxy.SetVariable("FinalFindings", $script:FinalFindings)

$script:PsInstance = [powershell]::Create()
$script:PsInstance.Runspace = $script:Runspace

$workerScript = @'
$script:WebhookUrl = $WebhookUrl
$script:ScanMode = $ScanMode
$script:Threshold = $Threshold
$script:MaxResults = $MaxResults
$script:UiQueue = $UiQueue
$script:DiscordTraces = $DiscordTraces
$script:TimelineEvents = $TimelineEvents
$script:SkippedSources = $SkippedSources
$script:FinalFindings = $FinalFindings

$script:CorrelationMap = @{}
$script:CertCache = @{}
$script:HashCache = @{}
$script:fileCounter = 0
$script:scanStartTime = Get-Date

$script:DmaBootStatus = [ordered]@{
    SecureBootEstado      = "Desconhecido"
    SecureBootAlerta      = $false
    KernelDmaEstado       = "Desconhecido"
    VbsEstado             = "Desconhecido"
    DmaProtectionAlerta   = $false
    PcieAnomalias         = New-Object System.Collections.Generic.List[string]
    RequerCamaraPcie      = $false
    ContextoHardwareNota  = "Alertas de firmware/DMA requerem confirmação contextual e inspeção física/câmara quando aplicável."
}

$script:FiveMSummary = [ordered]@{
    FiveMAppDataExiste = $false
    CitizenFxExiste    = $false
    CrashpadDumps      = 0
    ModificacoesRecentes = New-Object System.Collections.Generic.List[string]
}

$script:HardwareIdentity = [ordered]@{
    BiosSerial     = "N/A"
    BoardSerial    = "N/A"
    DiskSerials    = New-Object System.Collections.Generic.List[string]
    MacAddresses   = New-Object System.Collections.Generic.List[string]
    UsbRecentCount = 0
}

# APIs nativas para leitura de memória RWX e deteção de janelas/overlays estranhos
try {
    Add-Type -MemberDefinition @"
using System;
using System.Text;
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

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    public const uint PROCESS_VM_READ = 0x0010;
    public const uint PROCESS_QUERY_INFORMATION = 0x0400;
    public const uint MEM_COMMIT = 0x1000;
    public const uint MEM_PRIVATE = 0x20000;
    public const uint PAGE_EXECUTE_READWRITE = 0x40;

    public const int GWL_EXSTYLE = -20;
    public const long WS_EX_TOPMOST = 0x00000008L;
    public const long WS_EX_TRANSPARENT = 0x00000020L;
    public const long WS_EX_LAYERED = 0x00080000L;

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int dwSize, out int lpNumberOfBytesRead);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern int VirtualQueryEx(IntPtr hProcess, IntPtr lpAddress, out MEMORY_BASIC_INFORMATION lpBuffer, uint dwLength);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr")]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowLong")]
    private static extern IntPtr GetWindowLong32(IntPtr hWnd, int nIndex);

    public static long GetExStyle(IntPtr hWnd) {
        IntPtr r = (IntPtr.Size == 8) ? GetWindowLongPtr64(hWnd, GWL_EXSTYLE) : GetWindowLong32(hWnd, GWL_EXSTYLE);
        return r.ToInt64();
    }
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

function Extract-TextFromBytes {
    param([byte[]]$Bytes, [int]$MaxLen = 4194304)
    if (-not $Bytes -or $Bytes.Length -eq 0) { return "" }
    $n = [Math]::Min($Bytes.Length, $MaxLen)
    $asc = [System.Text.Encoding]::ASCII.GetString($Bytes, 0, $n)
    $utf16 = [System.Text.Encoding]::Unicode.GetString($Bytes, 0, ($n - ($n % 2)))
    return ($asc + "`n" + $utf16)
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
    $base = ($base -replace '-[A-F0-9]{8}\.pf$', '' -replace '\.lnk$', '' -replace '\.(exe|dll|sys|bat|cmd|ps1|vbs|js|scr|pf|dmp|asi|lua)$', '').ToLowerInvariant().Trim()
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
        }
    }

    $rec = $script:CorrelationMap[$key]
    if ($pathClean -ne "N/A") { [void]$rec.Caminhos.Add($pathClean) }
    if ($SourceType) { [void]$rec.Fontes.Add($SourceType) }
    if ($EvidenceText -and -not $rec.Evidencias.Contains($EvidenceText)) { $rec.Evidencias.Add($EvidenceText) }
    if ($ExtraDetail -and -not $rec.Detalhes.Contains($ExtraDetail)) { $rec.Detalhes.Add($ExtraDetail) }

    if ($matchedStrong) { $rec.HasStrongMatch = $true }
    if ($matchedMedium) { $rec.HasMediumMatch = $true }
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
                $textBlob = Extract-TextFromBytes -Bytes $buf -MaxLen $n
                $matches = [regex]::Matches($textBlob, $binarySignaturePattern)
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
    if ($Text -match '(?i)(dma|pcileech|fpga|xilinx|lattice|ftdi|secureboot|deviceguard|iommu|pci\\ven_|smbios|serial|mac)') {
        return "Hardware DMA / Spoof / PCIe"
    }
    if ($Text -match '(?i)(spoofer|hwid|cleaner[-_ ]?fivem|unban[-_ ]?fivem|gdrv|capcom|iqvw64e|dsefix|winring0|kdmapper|drvmap)') {
        return "Spoofer / Kernel Driver / Cleaner"
    }
    if ($Text -match '(?i)(xenos|extreme[-_ ]?injector|manual[-_ ]?map|reflective[-_ ]?dll|hollowing|injector|loader|dll[-_ ]?inject|kernel[-_ ]?drv|keyauth|mapper|rwx|unbacked|overlay)') {
        return "Injector / Loader / Overlay / Bypass"
    }
    if ($Text -match '(?i)(redengine|eulen|skript\.gg|lynx|lumia|fivem[-_ ]?exeternal|fivem[-_ ]?external|aimbot|wallhack|triggerbot|silent[-_ ]?aim|ragebot|mod[-_ ]?menu|cheat|esp[-_ ]?hack|phantom|macho|susano|fivem|citizenfx)') {
        return "Cheat / Mod Menu FiveM & GTA"
    }
    return "Manipulação / Bypass / Anti-Forensics"
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
        $motivos.Add("ativo em memória / processo / driver / overlay")
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
        Score            = $score
        RiskLabel        = $riskLabel
        Nome             = $rec.Nome
        Caminho          = $primaryPath
        TodosCaminhos    = ($caminhosArr -join " | ")
        Fontes           = ($fontesArr -join " + ")
        Categoria        = $cat
        Motivos          = ($motivos -join "; ")
        Evidencias       = ($rec.Evidencias -join "; ")
        SHA256           = $rec.SHA256
        SHA256Short      = $hashShort
        Assinatura       = $rec.SigStatus
        Publisher        = $rec.Publisher
        DataHora         = $rec.DataHora
        ApagadoRenomeado = $(if ($rec.IsDeletedOrRenamed) { "Sim" } else { "Não" })
        Ativo            = $(if ($rec.IsRunning) { "Sim" } else { "Não" })
        Confianca        = $(if ($fontesArr.Count -ge 2 -and $score -ge 75) { "Alta (Correlacionada)" } elseif ($score -ge 65) { "Média-Alta" } else { "Moderada" })
        Detalhes         = ($rec.Detalhes -join " | ")
    }
}

# ==============================================================================
# 1. MEMÓRIA / PROCESSOS / MÓDULOS / OVERLAYS / DRIVERS / DNS / HOSTS / RWX
# ==============================================================================
Queue-UI -Percent 10 -Text "A analisar processos, memória RWX, overlays, drivers e rede..." -SubText "Fase 1/5 • Processos ativos, módulos, janelas e rede"
$runningPaths = @{}
$procNameByPid = @{}
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
        $procNameByPid[[uint32]$p.ProcessId] = @{ Name = $pName; Path = $exe }
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

    # Enumeração de janelas TopMost + Layered + Transparent (padrão típico de overlays ESP/radar)
    try {
        $overlayList = New-Object System.Collections.Generic.List[pscustomobject]
        $enumCb = [Forensics.MkMemNative+EnumWindowsProc]{
            param([IntPtr]$hWnd, [IntPtr]$lParam)
            if (-not [Forensics.MkMemNative]::IsWindowVisible($hWnd)) { return $true }
            $exStyle = [Forensics.MkMemNative]::GetExStyle($hWnd)
            $isTopMost = (($exStyle -band [Forensics.MkMemNative]::WS_EX_TOPMOST) -ne 0)
            $isLayered = (($exStyle -band [Forensics.MkMemNative]::WS_EX_LAYERED) -ne 0)
            $isTransp  = (($exStyle -band [Forensics.MkMemNative]::WS_EX_TRANSPARENT) -ne 0)
            if ($isTopMost -and ($isLayered -or $isTransp)) {
                $sbTitle = New-Object System.Text.StringBuilder 256
                $sbClass = New-Object System.Text.StringBuilder 256
                [void][Forensics.MkMemNative]::GetWindowText($hWnd, $sbTitle, 256)
                [void][Forensics.MkMemNative]::GetClassName($hWnd, $sbClass, 256)
                $pidOut = [uint32]0
                [void][Forensics.MkMemNative]::GetWindowThreadProcessId($hWnd, [ref]$pidOut)
                $overlayList.Add([pscustomobject]@{
                    Title = $sbTitle.ToString().Trim()
                    Class = $sbClass.ToString().Trim()
                    Pid   = $pidOut
                    Trans = $isTransp
                })
            }
            return $true
        }
        [void][Forensics.MkMemNative]::EnumWindows($enumCb, [IntPtr]::Zero)
        foreach ($ov in $overlayList) {
            $pInfo = $procNameByPid[$ov.Pid]
            $pNm = if ($pInfo) { $pInfo.Name } else { "PID_$($ov.Pid)" }
            $pPt = if ($pInfo -and $pInfo.Path) { $pInfo.Path } else { "WIN://$($ov.Class)" }
            $ovComb = "$($ov.Title) $($ov.Class) $pNm $pPt"
            if (($ovComb -match $cheatStrongPattern) -or ($ovComb -match $cheatMediumPattern) -or ($ov.Trans -and $pPt -match '(?i)\\(AppData|Temp|Users\\Public)\\')) {
                Register-Evidence -RawName $pNm -RawPath $pPt -SourceType "OverlayWindow" `
                    -EvidenceText "janela overlay TopMost/Layered/Transparent (Title='$($ov.Title)', Class='$($ov.Class)', PID=$($ov.Pid))" `
                    -IsRunning $true -BonusScore 45
                Add-Timeline -TimeStr (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Kind "Overlay Suspeito" -Source "EnumWindows" -Subject $pNm -Detail "Title='$($ov.Title)' Class='$($ov.Class)'"
            }
        }
    } catch { Add-Skipped "EnumWindows Overlays" }

    # Varrimento de memória (MEM_PRIVATE + PAGE_EXECUTE_READWRITE + strings) em processos-alvo
    $targetProcList = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match '(?i)^(FiveM_GTAProcess|FiveM|GTA5|GTA5_b\d+|explorer)$'
    }) | Select-Object -First 10

    foreach ($tp in $targetProcList) {
        if (((Get-Date) - $script:scanStartTime).TotalSeconds -gt 75) {
            Add-Skipped "Varredura de memória RWX (limite de tempo atingido)"
            break
        }
        $procId = [int]$tp.Id
        $procLabel = "$($tp.ProcessName) (PID=$procId)"

        $hProc = [Forensics.MkMemNative]::OpenProcess(
            ([Forensics.MkMemNative]::PROCESS_VM_READ -bor [Forensics.MkMemNative]::PROCESS_QUERY_INFORMATION),
            $false, $procId
        )
        if ($hProc -ne [IntPtr]::Zero) {
            try {
                $addr = [IntPtr]::Zero
                $regionsChecked = 0
                $maxAddr = if ([Environment]::Is64BitProcess) { [Int64]0x7FFFFFFFFFFF } else { [Int64]0x7FFF0000 }
                while (([Int64]$addr -lt $maxAddr) -and ($regionsChecked -lt 650)) {
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
                            $memText = Extract-TextFromBytes -Bytes $buf -MaxLen $bytesRead
                            $strMatches = [regex]::Matches($memText, $binarySignaturePattern)
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
} catch { Add-Skipped "Processos/Memória/Overlays/Drivers" }

# Coletores de rede / conexões TCP ativas / DNS / hosts
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
    $tcpConns = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue
    foreach ($tc in $tcpConns) {
        $pInfo = $procNameByPid[[uint32]$tc.OwningProcess]
        if ($pInfo -and $pInfo.Path -and ($pInfo.Path -match '(?i)\\(AppData|Temp|Users\\Public)\\') -and ($pInfo.Path -notmatch '(?i)\\(Discord|FiveM Application Data|Rockstar Games|Microsoft|Google|Mozilla)\\')) {
            $ciTcp = Get-CertInfoFast -Path $pInfo.Path
            if ($ciTcp.Status -ne "ValidSigned") {
                Register-Evidence -RawName $pInfo.Name -RawPath $pInfo.Path -SourceType "NetworkArtifact" `
                    -EvidenceText "conexão TCP ativa em processo não assinado em diretório de utilizador ($($tc.RemoteAddress):$($tc.RemotePort))" `
                    -IsRunning $true -SigStatus $ciTcp.Status -Publisher $ciTcp.Publisher -BonusScore 25
            }
        }
    }
} catch { Add-Skipped "DNS/Hosts/TCP" }

# ==============================================================================
# 2. FICHEIROS, PASTAS FIVEM/GTA V, RECICLAGEM, ADS, TAREFAS & DEFENDER
# ==============================================================================
if ($script:ScanMode -ne "RamModule") {
    Queue-UI -Percent 25 -Text "A analisar ficheiros, assinaturas, Reciclagem e FiveM/GTA V..." -SubText "Fase 2/5 • Sistema de ficheiros, FiveM e persistência"
    $seenFiles = @{}
    $extAllowed = '(?i)^\.(exe|dll|sys|bat|cmd|ps1|vbs|js|scr|rar|zip|7z|asi|lua|dmp|ini)$'

    $fivemDirs = @(
        "$env:LOCALAPPDATA\FiveM\FiveM Application Data",
        "$env:APPDATA\CitizenFX",
        "$env:LOCALAPPDATA\FiveM\FiveM Application Data\crashes",
        "$env:LOCALAPPDATA\FiveM\FiveM Application Data\mods",
        "$env:LOCALAPPDATA\FiveM\FiveM Application Data\plugins"
    )
    foreach ($fd in $fivemDirs) {
        if (-not (Test-Path -LiteralPath $fd)) { continue }
        if ($fd -match 'FiveM Application Data$') { $script:FiveMSummary.FiveMAppDataExiste = $true }
        if ($fd -match 'CitizenFX$') { $script:FiveMSummary.CitizenFxExiste = $true }

        try {
            $fItems = Get-ChildItem -LiteralPath $fd -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 5000
            foreach ($fi in $fItems) {
                if ($fi.FullName -match $strictExcludePattern) { continue }
                if ($fi.Extension -match '(?i)^\.dmp$') {
                    $script:FiveMSummary.CrashpadDumps++
                }
                $isRecentFivem = ($fi.LastWriteTime -gt (Get-Date).AddHours(-24)) -and ($fi.Extension -match '(?i)^\.(dll|asi|lua|exe|ini|dmp)$')
                $isSuspFivem = ("$($fi.Name) $($fi.FullName)" -match $cheatStrongPattern) -or ("$($fi.Name) $($fi.FullName)" -match $cheatMediumPattern)

                if (-not $isSuspFivem -and $isRecentFivem -and ($fi.Extension -match '(?i)^\.(dll|asi|lua|exe)$')) {
                    $ciFChk = Get-CertInfoFast -Path $fi.FullName
                    if ($ciFChk.Status -ne "ValidSigned") {
                        $fHits = Test-BinaryHeuristicStrings -Path $fi.FullName
                        if ($fHits.Count -ge 2) { $isSuspFivem = $true }
                    }
                }

                if ($isRecentFivem -and $script:FiveMSummary.ModificacoesRecentes.Count -lt 8) {
                    $script:FiveMSummary.ModificacoesRecentes.Add("$($fi.Name) ($($fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm')))")
                }

                if ($isSuspFivem) {
                    $ciF = if ($fi.Extension -match '(?i)^\.(exe|dll|sys|scr|asi)$') { Get-CertInfoFast -Path $fi.FullName } else { @{ Status = "N/A"; Publisher = "N/A" } }
                    $hF = Get-Sha256Fast -Path $fi.FullName
                    $tsF = $fi.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                    Register-Evidence -RawName $fi.Name -RawPath $fi.FullName -SourceType "FiveMArtifact" `
                        -EvidenceText "artefacto FiveM/CitizenFX detetado" -IsRunning ($runningPaths.ContainsKey($fi.FullName.ToLowerInvariant())) `
                        -Sha256 $hF -SigStatus $ciF.Status -Publisher $ciF.Publisher -Timestamp $tsF
                    Add-Timeline -TimeStr $tsF -Kind "Artefacto FiveM" -Source "FiveMArtifact" -Subject $fi.Name -Detail $fi.FullName
                }
            }
        } catch { Add-Skipped "Diretório FiveM ($fd)" }
    }

    function Scan-DirV4 {
        param([string]$Dir, [int]$Depth, [int]$MaxDepth)
        if ($Depth -gt $MaxDepth) { return }
        if (-not $Dir -or ($Dir -match $strictExcludePattern)) { return }
        if (((Get-Date) - $script:scanStartTime).TotalSeconds -gt 600) { Add-Skipped "Pesquisa de ficheiros atingiu o limite de 10 minutos"; return }

        $script:fileCounter++
        if (($script:fileCounter % 450) -eq 0) {
            $pct = [Math]::Min(55, 25 + [int](($script:fileCounter / 4200.0) * 30))
            Queue-UI -Percent $pct -Text "A analisar ficheiros, assinaturas, Reciclagem e FiveM/GTA V..." -SubText "Ficheiros inspecionados: $($script:fileCounter)"
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

                $srcType = if ($f -match '(?i)(fivem|gta|citizenfx)') { "FiveMArtifact" } else { "DiskFile" }
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
                Scan-DirV4 -Dir $s -Depth ($Depth + 1) -MaxDepth $MaxDepth
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
        Scan-DirV4 -Dir $r -Depth 0 -MaxDepth $md
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
Queue-UI -Percent 60 -Text "A analisar Prefetch, BAM, Cleaners, Registo e Logs..." -SubText "Fase 3/5 • Histórico de execução e anti-forensics"
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
            $lnkText  = Extract-TextFromBytes -Bytes $rawBytes -MaxLen $rawBytes.Length
            $lnkComb  = "$($_.Name) $lnkText"
            if ($lnkComb -match $cheatStrongPattern -or $lnkComb -match $cheatMediumPattern) {
                $targetPath = if ($lnkText -match '([A-Za-z]:\\[^\x00-\x1f"]+\.(exe|bat|cmd|ps1|rar|zip|dll))') { $matches[1] } else { $_.FullName }
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
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\SYSTEM\CurrentControlSet\Services\*"
)
foreach ($rp in $regForensicPaths) {
    try {
        Get-Item -Path $rp -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($vn in $_.GetValueNames()) {
                $vd = ""
                try {
                    $rawReg = $_.GetValue($vn)
                    if ($rawReg -is [byte[]]) { $vd = Extract-TextFromBytes -Bytes $rawReg -MaxLen $rawReg.Length }
                    else { $vd = [string]$rawReg }
                } catch {}
                $combR = "$vn $vd"
                if ($combR -match $cheatStrongPattern -or $combR -match $cheatMediumPattern) {
                    $cand = if ($vd -match '[A-Za-z]:\\') { $vd } else { $vn }
                    $exN = [System.IO.Path]::GetFileName($cand)
                    if ([string]::IsNullOrWhiteSpace($exN)) { $exN = $vn }
                    $isPersist = ($_.PSPath -match '\\Run(Once)?$|\\Services\\')
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

# Event Logs: limpeza de logs (1102 Security / 104 System) + instalação de serviços (7045 System)
try {
    $clearEvts = Get-WinEvent -FilterHashtable @{ LogName = @('Security','System'); Id = @(1102,104) } -MaxEvents 10 -ErrorAction SilentlyContinue
    foreach ($ev in $clearEvts) {
        $tsEv = $ev.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        Register-Evidence -RawName "eventlog_cleared_$($ev.Id)" -RawPath "EventLog://$($ev.LogName)/$($ev.Id)" -SourceType "AntiForensics" `
            -EvidenceText "log $($ev.LogName) limpo (EventID $($ev.Id))" -Timestamp $tsEv -BonusScore 35
        Add-Timeline -TimeStr $tsEv -Kind "Limpeza de Log" -Source $ev.LogName -Subject "EventID $($ev.Id)" -Detail "Possível limpeza de rasto forense"
    }
    $svcInstallEvts = Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 7045 } -MaxEvents 20 -ErrorAction SilentlyContinue
    foreach ($sev in $svcInstallEvts) {
        $msg7045 = $sev.Message
        if ($msg7045 -match $cheatStrongPattern -or $msg7045 -match $cheatMediumPattern) {
            $ts7045 = $sev.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
            Register-Evidence -RawName "svc_install_7045" -RawPath "EventLog://System/7045" -SourceType "Persistence" `
                -EvidenceText "novo serviço/driver registado (EventID 7045)" -Timestamp $ts7045 -ExtraDetail $msg7045 -BonusScore 30
            Add-Timeline -TimeStr $ts7045 -Kind "Novo Serviço (7045)" -Source "System" -Subject "EventID 7045" -Detail "Correspondência em log de serviço"
        }
    }
} catch { Add-Skipped "Event Logs (Security/System)" }

# ==============================================================================
# 3.5 HARDWARE DMA, SECURE BOOT, KERNEL DMA, PCIe & IDENTIDADE HWID/USB
# ==============================================================================
Queue-UI -Percent 70 -Text "A verificar Secure Boot, Kernel DMA, PCIe e HWID/USB..." -SubText "Fase 4/5 • Integridade de arranque, PCIe e identidade de hardware"

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
            -SourceType "HardwareDmaBoot" -EvidenceText "Secure Boot desativado (alerta amarelo: requer confirmação contextual / verificação por câmara)" -BonusScore 15
        Add-Timeline -TimeStr (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Kind "Secure Boot OFF" -Source "SecureBoot" -Subject "UEFISecureBootEnabled=0" -Detail "Alerta amarelo anti-bootkit/DMA"
    } else {
        $script:DmaBootStatus.SecureBootEstado = "Não suportado / Legacy BIOS (Alerta Amarelo)"
        $script:DmaBootStatus.SecureBootAlerta = $true
        Register-Evidence -RawName "secureboot_unsupported" -RawPath "UEFI://SecureBoot" `
            -SourceType "HardwareDmaBoot" -EvidenceText "Secure Boot não suportado ou modo Legacy BIOS (alerta amarelo)" -BonusScore 15
    }
} catch { Add-Skipped "Secure Boot" }

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
            -SourceType "HardwareDmaBoot" -EvidenceText "Kernel DMA Protection / VBS desativado ou sem IOMMU ativo (alerta amarelo: avaliar contexto e câmara se houver suspeita)" -BonusScore 15
    }
} catch { Add-Skipped "DeviceGuard / Kernel DMA Protection" }

try {
    $pciDevices = @(Get-CimInstance -ClassName "Win32_PnPEntity" -Filter "DeviceID LIKE 'PCI\\%'" -ErrorAction SilentlyContinue)
    $netAdapters = @(Get-CimInstance -ClassName "Win32_NetworkAdapter" -ErrorAction SilentlyContinue)
    $nicMapByPnp = @{}
    foreach ($na in $netAdapters) {
        if ($na.PNPDeviceID) { $nicMapByPnp[$na.PNPDeviceID.ToUpperInvariant()] = $na }
        if ($na.PhysicalAdapter -eq $true -and $na.MACAddress) {
            [void]$script:HardwareIdentity.MacAddresses.Add("$($na.Name)=$($na.MACAddress)")
        }
    }

    $nicCountByIdentity = @{}

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
        if ($nicEntry -and $nicEntry.PhysicalAdapter -eq $true) {
            $idKey = "$vid|$pidHex|$subsys|$($devName.ToLowerInvariant().Trim())"
            if (-not $nicCountByIdentity.ContainsKey($idKey)) {
                $nicCountByIdentity[$idKey] = @{ Count = 0; Name = $devName; Vid = $vid; Pid = $pidHex }
            }
            $nicCountByIdentity[$idKey].Count++

            $isDisabledNic = ($nicEntry.ConfigManagerErrorCode -eq 22) -or ($nicEntry.NetEnabled -eq $false)
            if ($isDisabledNic) {
                $msgNic = "Adaptador de rede físico PCIe desativado (possível firmware DMA clonado): $devName (VID=$vid, PID=$pidHex, SUBSYS=$subsys)"
                $script:DmaBootStatus.PcieAnomalias.Add($msgNic)
                $script:DmaBootStatus.RequerCamaraPcie = $true
                Register-Evidence -RawName "pcie_spoof_nic_${vid}_${pidHex}" -RawPath $pnpId `
                    -SourceType "HardwareDmaBoot" -EvidenceText $msgNic -BonusScore 35
            }
        }
    }

    foreach ($kvNic in $nicCountByIdentity.GetEnumerator()) {
        $infoNic = $kvNic.Value
        if ($infoNic.Count -ge 2) {
            $msgDup = "Adaptador de rede físico PCIe duplicado idêntico ($($infoNic.Count)x): $($infoNic.Name) (VID=$($infoNic.Vid), PID=$($infoNic.Pid))"
            $script:DmaBootStatus.PcieAnomalias.Add($msgDup)
            $script:DmaBootStatus.RequerCamaraPcie = $true
            Register-Evidence -RawName "pcie_duplicate_nic" -RawPath "PCI://DuplicateNIC" `
                -SourceType "HardwareDmaBoot" -EvidenceText $msgDup -BonusScore 35
        }
    }

    # Identidade HWID (BIOS, Board, Disks) e dispositivos USB recentes
    $biosObj = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
    if ($biosObj -and $biosObj.SerialNumber) { $script:HardwareIdentity.BiosSerial = [string]$biosObj.SerialNumber.Trim() }
    $boardObj = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    if ($boardObj -and $boardObj.SerialNumber) { $script:HardwareIdentity.BoardSerial = [string]$boardObj.SerialNumber.Trim() }
    foreach ($dk in @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)) {
        if ($dk.SerialNumber) { [void]$script:HardwareIdentity.DiskSerials.Add("$($dk.Model)=$($dk.SerialNumber.Trim())") }
    }
    $usbDevs = @(Get-CimInstance Win32_PnPEntity -Filter "DeviceID LIKE 'USB\\%'" -ErrorAction SilentlyContinue)
    $script:HardwareIdentity.UsbRecentCount = $usbDevs.Count
    foreach ($ud in $usbDevs) {
        $uComb = "$($ud.Name) $($ud.DeviceID)"
        if ($uComb -match $cheatStrongPattern -or $uComb -match '(?i)(ftdi|usb.*serial|dma|ch340|cp210)') {
            Register-Evidence -RawName "usb_dev_$($ud.Name)" -RawPath $ud.DeviceID -SourceType "HardwareDmaBoot" `
                -EvidenceText "dispositivo USB relevante/suspeito ($($ud.Name))" -BonusScore 25
        }
    }
} catch { Add-Skipped "Enumeração PCIe / Hardware DMA / HWID" }

# ==============================================================================
# 3B. ARTEFACTOS ADICIONAIS (SOMENTE LEITURA): AUTORUNS, SERVIÇOS, TASKS, USB,
#     APPCOMPAT/SHIMCACHE, AMCACHE E EVENTOS DE INSTALAÇÃO/LIMPEZA
# ==============================================================================
Queue-UI -Percent 72 -Text "A analisar artefactos adicionais do Windows..." -SubText "Registry, serviços, tarefas, USB e Event Logs"

# Persistência: chaves Run/RunOnce em HKLM/HKCU e pastas Startup
$autoRunKeys = @(
 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
)
foreach ($rk in $autoRunKeys) {
    try {
        if (Test-Path -LiteralPath $rk) {
            $props = Get-ItemProperty -LiteralPath $rk -ErrorAction Stop
            foreach ($prop in $props.PSObject.Properties) {
                if ($prop.Name -like 'PS*') { continue }
                $val = [string]$prop.Value
                if ($val -match $cheatStrongPattern -or $val -match $cheatMediumPattern) {
                    Register-Evidence -RawName $prop.Name -RawPath $val -SourceType 'Persistence' -EvidenceText "entrada Run/RunOnce suspeita em $rk" -BonusScore 30
                    Add-Timeline -TimeStr (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -Kind 'Autorun' -Source $rk -Subject $prop.Name -Detail $val
                }
            }
        }
    } catch { Add-Skipped "Registry autorun: $rk" }
}

# Serviços e drivers: registar caminhos suspeitos sem assumir que nome genérico é cheat
try {
    foreach ($svc in @(Get-CimInstance Win32_Service -ErrorAction Stop)) {
        $svcText = "$($svc.Name) $($svc.DisplayName) $($svc.PathName)"
        if ($svcText -match $cheatStrongPattern) {
            Register-Evidence -RawName $svc.Name -RawPath $svc.PathName -SourceType 'Persistence' -EvidenceText "serviço com indicador nominal forte; validar assinatura e origem" -BonusScore 35
        }
        if ($svc.PathName -match '(?i)\\Users\\[^\\]+\\(AppData|Downloads|Desktop|Temp)\\' -and $svc.StartMode -eq 'Auto') {
            Register-Evidence -RawName $svc.Name -RawPath $svc.PathName -SourceType 'Persistence' -EvidenceText 'serviço automático a executar de diretório gravável pelo utilizador' -BonusScore 20
        }
    }
} catch { Add-Skipped 'Inventário Win32_Service' }

# Tarefas agendadas: ações com caminhos/argumentos suspeitos
try {
    foreach ($task in @(Get-ScheduledTask -ErrorAction Stop)) {
        foreach ($action in @($task.Actions)) {
            $act = "$($action.Execute) $($action.Arguments) $($action.WorkingDirectory)"
            if ($act -match $cheatStrongPattern -or ($act -match '(?i)\\Users\\[^\\]+\\(AppData|Downloads|Temp)\\' -and $act -match '(?i)\\.(exe|dll|ps1|bat|cmd)')) {
                Register-Evidence -RawName $task.TaskName -RawPath $act -SourceType 'Persistence' -EvidenceText 'ação de tarefa agendada suspeita; confirmar editor, trigger e assinatura' -BonusScore 25
            }
        }
    }
} catch { Add-Skipped 'Tarefas agendadas (Get-ScheduledTask)' }

# Shimcache/AppCompatCache: recolha de metadados acessíveis (não interpretar binário como prova de execução)
try {
    $shimKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache'
    $shim = Get-ItemProperty -LiteralPath $shimKey -Name AppCompatCache -ErrorAction Stop
    if ($shim.AppCompatCache) {
        $shimText = Extract-TextFromBytes -Bytes ([byte[]]$shim.AppCompatCache) -MaxLen 2097152
        foreach ($m in [regex]::Matches($shimText, '(?i)[A-Z]:\\[^\x00\r\n]{3,260}\\[^\x00\r\n]{2,120}\\[^\x00\r\n]{2,120}\.(exe|dll|sys|asi)')) {
            $pathHit = ($m.Value -replace '^\x00+|\x00+$','').Trim()
            if ($pathHit -match $cheatStrongPattern) {
                Register-Evidence -RawName ([IO.Path]::GetFileName($pathHit)) -RawPath $pathHit -SourceType 'AmcacheShimcache' -EvidenceText 'caminho suspeito extraído de AppCompatCache; Shimcache isolado não prova execução' -BonusScore 25
            }
        }
    }
} catch { Add-Skipped 'AppCompatCache/Shimcache não acessível ou formato não reconhecido' }

# Amcache: verificar hive e metadados; não carregar/alterar hive bloqueado
try {
    $amPath = Join-Path $env:SystemRoot 'AppCompat\Programs\Amcache.hve'
    if (Test-Path -LiteralPath $amPath) {
        $amInfo = Get-Item -LiteralPath $amPath -ErrorAction Stop
        Add-Timeline -TimeStr $amInfo.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') -Kind 'Amcache disponível' -Source 'Amcache.hve' -Subject 'Hive presente' -Detail "Tamanho=$($amInfo.Length); análise de conteúdo pode exigir cópia forense consistente"
    } else { Add-Skipped 'Amcache.hve ausente' }
} catch { Add-Skipped 'Metadados Amcache indisponíveis' }

# Dispositivos USB registados (Enumeração histórica do Registry)
try {
    $usbReg = 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB'
    if (Test-Path -LiteralPath $usbReg) {
        foreach ($vendor in @(Get-ChildItem -LiteralPath $usbReg -ErrorAction Stop)) {
            foreach ($instance in @(Get-ChildItem -LiteralPath $vendor.PSPath -ErrorAction SilentlyContinue)) {
                $dp = Get-ItemProperty -LiteralPath $instance.PSPath -ErrorAction SilentlyContinue
                $friendly = if ($dp.FriendlyName) { [string]$dp.FriendlyName } elseif ($dp.DeviceDesc) { [string]$dp.DeviceDesc } else { $vendor.PSChildName }
                if ("$friendly $($vendor.PSChildName)" -match $cheatStrongPattern) {
                    Register-Evidence -RawName $friendly -RawPath $instance.Name -SourceType 'HardwareDmaBoot' -EvidenceText 'dispositivo USB histórico com indicador nominal; requer identificação física' -BonusScore 25
                }
            }
        }
    }
} catch { Add-Skipped 'Histórico USB no Registry' }

# Eventos: limpeza de logs (1102/104), instalação de serviço (7045), driver (Kernel-PnP)
try {
    $eventSpecs = @(
        @{ Log='Security'; Id=1102; Label='Security log limpo' },
        @{ Log='System'; Id=104; Label='Event log limpo' },
        @{ Log='System'; Id=7045; Label='Novo serviço instalado' },
        @{ Log='Microsoft-Windows-Kernel-PnP/Configuration'; Id=400; Label='Dispositivo configurado' }
    )
    foreach ($spec in $eventSpecs) {
        try {
            $events = @(Get-WinEvent -FilterHashtable @{LogName=$spec.Log; Id=$spec.Id; StartTime=(Get-Date).AddDays(-30)} -MaxEvents 100 -ErrorAction Stop)
            foreach ($ev in $events) {
                $msg = [string]$ev.Message
                if ($spec.Id -in @(1102,104)) {
                    Register-Evidence -RawName "EventLog_$($spec.Id)" -RawPath "EventLog://$($spec.Log)/$($ev.RecordId)" -SourceType 'AntiForensics' -EvidenceText "$($spec.Label) nos últimos 30 dias" -BonusScore 35 -Timestamp $ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
                } elseif ($msg -match $cheatStrongPattern) {
                    Register-Evidence -RawName "Event_$($spec.Id)" -RawPath "EventLog://$($spec.Log)/$($ev.RecordId)" -SourceType 'Persistence' -EvidenceText "$($spec.Label): indicador forte no texto do evento" -BonusScore 30 -Timestamp $ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
                }
            }
        } catch { Add-Skipped "EventLog $($spec.Log) ID $($spec.Id) indisponível" }
    }
} catch { Add-Skipped 'Consulta de Event Logs' }

if (-not (Test-Path -LiteralPath "$env:SystemRoot\AppCompat\Programs\Amcache.hve")) {
    Add-Skipped "Amcache.hve (não acessível/ausente)"
}
Add-Skipped "Memória física bruta / Kernel não-paginado / MFT direto (requer driver kernel próprio)"

# ==============================================================================
# 4. RASTOS LOCAIS DE DISCORD (PRESENÇA / HISTÓRICO E QUANDO)
# ==============================================================================
Queue-UI -Percent 80 -Text "A verificar presença/histórico em Discords de cheats..." -SubText "Fase 5/5 • Cache local do Discord e consolidação"
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
                    $contentText = Extract-TextFromBytes -Bytes $bytes -MaxLen $bytes.Length
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
Queue-UI -Percent 90 -Text "A correlacionar evidências e gerar relatório..." -SubText "A compilar correlações, FiveM, DMA, HWID e timeline"
$scoredList = @()
foreach ($kv in $script:CorrelationMap.GetEnumerator()) {
    $scored = Score-CorrelatedRecord -rec $kv.Value
    if ($scored.Score -ge $script:Threshold) {
        $scoredList += $scored
    }
}

$topFindings = @($scoredList | Sort-Object Score -Descending | Select-Object -First $script:MaxResults)
foreach ($tf in $topFindings) { $script:FinalFindings.Enqueue($tf) }

$discordList = @($script:DiscordTraces.ToArray() | Sort-Object DataHora -Descending | Select-Object -First 15)
$timelineTop = @($script:TimelineEvents.ToArray() | Sort-Object DataHora -Descending | Select-Object -First 20)

$pcName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { "PC" }
$userName = if ($env:USERNAME) { $env:USERNAME } else { "Utilizador" }
$dateStr = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

$reportDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "MkChecks Reports"
try { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null } catch { $reportDir = $env:TEMP }
$reportStamp = Get-Date -Format yyyyMMdd_HHmmss
$tempHtml = Join-Path $reportDir "MkChecks-V4.1_${pcName}_${reportStamp}.html"
$tempCsv = Join-Path $reportDir "MkChecks-V4.1_${pcName}_${reportStamp}.csv"
$tempJson = Join-Path $reportDir "MkChecks-V4.1_${pcName}_${reportStamp}.json"
$rowsHtml = ($topFindings | ForEach-Object {
    "<tr><td><strong>$([System.Net.WebUtility]::HtmlEncode($_.Nome))</strong></td><td>$($_.Score)/100 ($([System.Net.WebUtility]::HtmlEncode($_.RiskLabel)))</td><td>$([System.Net.WebUtility]::HtmlEncode($_.Categoria))</td><td>$([System.Net.WebUtility]::HtmlEncode($_.Fontes))</td><td>$([System.Net.WebUtility]::HtmlEncode($_.ApagadoRenomeado))</td><td>$([System.Net.WebUtility]::HtmlEncode($_.Assinatura))</td><td>$([System.Net.WebUtility]::HtmlEncode($_.DataHora))</td><td><code>$([System.Net.WebUtility]::HtmlEncode($_.Caminho))</code></td><td><code>$([System.Net.WebUtility]::HtmlEncode($_.SHA256Short))</code></td><td>$([System.Net.WebUtility]::HtmlEncode($_.Evidencias))</td></tr>"
}) -join "`n"
$fivemRecentesStr = if ($script:FiveMSummary.ModificacoesRecentes.Count -gt 0) { ($script:FiveMSummary.ModificacoesRecentes -join ", ") } else { "Nenhuma alteração recente relevante" }
$pcieAnomStr = if ($script:DmaBootStatus.PcieAnomalias.Count -gt 0) { ($script:DmaBootStatus.PcieAnomalias -join " | ") } else { "Sem anomalias PCIe detetadas" }
$hwIdStr = "Identificadores de hardware recolhidos localmente (omitidos do resumo); USB=$($script:HardwareIdentity.UsbRecentCount)"
$fivemSummaryHtml = "<p><strong>FiveM AppData:</strong> $($script:FiveMSummary.FiveMAppDataExiste) | <strong>CitizenFX:</strong> $($script:FiveMSummary.CitizenFxExiste) | <strong>Crashpad Dumps:</strong> $($script:FiveMSummary.CrashpadDumps) | <strong>Limiar Score:</strong> $($script:Threshold)/100 | <strong>Recentes (24h):</strong> $([System.Net.WebUtility]::HtmlEncode($fivemRecentesStr))</p>"
$dmaSummaryHtml = "<p><strong>Secure Boot:</strong> $([System.Net.WebUtility]::HtmlEncode($script:DmaBootStatus.SecureBootEstado)) | <strong>Kernel DMA:</strong> $([System.Net.WebUtility]::HtmlEncode($script:DmaBootStatus.KernelDmaEstado)) | <strong>VBS:</strong> $([System.Net.WebUtility]::HtmlEncode($script:DmaBootStatus.VbsEstado)) | <strong>PCIe:</strong> $([System.Net.WebUtility]::HtmlEncode($pcieAnomStr))</p>"
$hwIdHtml = "<p><strong>Identidade HWID:</strong> $([System.Net.WebUtility]::HtmlEncode($hwIdStr))</p>"
$htmlDoc = @"
<!DOCTYPE html><html><head><meta charset='utf-8'><title>MkChecks V4.1 — $pcName</title>
<style>body{background:#0c0a12;color:#f5f3ff;font-family:Segoe UI,Arial,sans-serif;padding:24px}h1{color:#c084fc}table{width:100%;border-collapse:collapse;margin-top:16px}th,td{border:1px solid #2e2447;padding:8px;font-size:12px;text-align:left}th{background:#181226;color:#c084fc}code{color:#a78bfa}</style></head>
<body><h1>MkChecks V4.1 — Relatório Forense ($pcName)</h1><p>Utilizador: <strong>$userName</strong> | Data: <strong>$dateStr</strong> | Modo: <strong>$($script:ScanMode)</strong></p>$fivemSummaryHtml$dmaSummaryHtml$hwIdHtml
<table><thead><tr><th>Artefacto</th><th>Risco</th><th>Categoria</th><th>Fontes</th><th>Apagado/Ren.</th><th>Assinatura</th><th>Data/Hora</th><th>Caminho</th><th>SHA256</th><th>Evidências</th></tr></thead><tbody>$rowsHtml</tbody></table></body></html>
"@
try { $htmlDoc | Out-File -LiteralPath $tempHtml -Encoding UTF8 } catch { Add-Skipped "Falha ao guardar relatório HTML: $($_.Exception.Message)" }
try {
    if ($topFindings.Count -gt 0) { $topFindings | Export-Csv -LiteralPath $tempCsv -NoTypeInformation -Encoding UTF8 }
    else { [pscustomobject]@{ Estado='Sem correlações acima do limiar'; Data=$dateStr; PC=$pcName; Modo=$script:ScanMode; Nota='Ausência de deteção não garante sistema limpo' } | Export-Csv -LiteralPath $tempCsv -NoTypeInformation -Encoding UTF8 }
} catch { Add-Skipped "Falha ao guardar CSV: $($_.Exception.Message)" }
try {
    $manifest = [ordered]@{
        Scanner = 'MkChecks V4.1'
        GeneratedAt = (Get-Date).ToString('o')
        Computer = $pcName
        ScanMode = $script:ScanMode
        Threshold = $script:Threshold
        Findings = @($topFindings)
        Timeline = @($script:TimelineEvents.ToArray())
        DiscordArtifacts = @($discordList)
        SkippedSources = @($script:SkippedSources.ToArray() | Select-Object -Unique)
        Limitations = @('Pontuação representa correlação, não probabilidade.', 'Shimcache isolado não prova execução.', 'Ausência de deteção não garante sistema limpo.')
    }
    $manifest | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $tempJson -Encoding UTF8
} catch { Add-Skipped "Falha ao guardar JSON: $($_.Exception.Message)" }

Queue-UI -Percent 96 -Text "A guardar relatório local..." -SubText "Relatórios HTML e CSV; envio externo apenas se configurado"
try {
    if (-not [string]::IsNullOrWhiteSpace($script:WebhookUrl)) {
        $sections = New-Object System.Collections.Generic.List[string]
        $sections.Add("**Utilizador:** ``$userName``  •  **PC:** ``$pcName``  •  **Modo:** ``$($script:ScanMode)``  •  **Limiar:** ``$($script:Threshold)/100``")
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

        $sections.Add("### 🎮 Contexto FiveM & GTA V")
        $sections.Add("• **FiveM AppData / CitizenFX:** $(if ($script:FiveMSummary.FiveMAppDataExiste) { 'Presente' } else { 'Não detetado' }) / $(if ($script:FiveMSummary.CitizenFxExiste) { 'Presente' } else { 'Não detetado' })  •  **Crashpad Dumps:** $($script:FiveMSummary.CrashpadDumps)")
        $sections.Add("• **Alterações recentes (24h):** $fivemRecentesStr")
        $sections.Add("")

        $sections.Add("### 🛡️ Integridade de Arranque, DMA, PCIe & HWID")
        $sections.Add("• **Secure Boot:** $($script:DmaBootStatus.SecureBootEstado)")
        $sections.Add("• **Kernel DMA / VBS:** $($script:DmaBootStatus.KernelDmaEstado) ($($script:DmaBootStatus.VbsEstado))")
        $sections.Add("• **Identidade HWID:** $hwIdStr")
        if ($script:DmaBootStatus.PcieAnomalias.Count -gt 0) {
            foreach ($pa in ($script:DmaBootStatus.PcieAnomalias | Select-Object -First 5)) {
                $sections.Add("• **Anomalia PCIe:** $pa")
            }
        } else {
            $sections.Add("• **Barramento PCIe:** Sem placas FPGA/DMA ou dispositivos sem driver detetados.")
        }
        if ($script:DmaBootStatus.RequerCamaraPcie) {
            $sections.Add("• ⚠️ **Recomendação Staff:** Anomalia de hardware/PCIe detetada — pedir partilha de câmara (telemóvel) na traseira da torre/slots PCIe e no Gestor de Dispositivos.")
        } elseif ($script:DmaBootStatus.SecureBootAlerta -or $script:DmaBootStatus.DmaProtectionAlerta) {
            $sections.Add("• ℹ️ **Nota de Contexto:** Secure Boot ou Kernel DMA/VBS desligado pode ocorrer por configuração de fábrica/dual-boot; só exigir câmara se houver indícios adicionais ou suspeita de DMA.")
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
            foreach ($tl in ($timelineTop | Select-Object -First 8)) {
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

        $tempCsv = Join-Path $env:TEMP "MkChecks_V4.1_${pcName}_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
        if ($topFindings.Count -gt 0 -or $discordList.Count -gt 0) {
            $topFindings | Export-Csv -LiteralPath $tempCsv -NoTypeInformation -Encoding UTF8
        } else {
            "Sem correlacoes acima do limiar em $pcName ($userName) em $dateStr | SecureBoot=$($script:DmaBootStatus.SecureBootEstado) | KernelDMA=$($script:DmaBootStatus.KernelDmaEstado) | $hwIdStr" | Out-File -LiteralPath $tempCsv -Encoding UTF8
        }

        $embedColor = if ($topFindings.Count -gt 0 -or $discordList.Count -gt 0 -or $script:DmaBootStatus.RequerCamaraPcie) { 10181046 } else { 7419530 }
        $payload = @{
            username = "MkChecks V4.1"
            embeds   = @(
                @{
                    title       = "Relatório Forense MkChecks V4.1 — $pcName"
                    description = $desc
                    color       = $embedColor
                    footer      = @{ text = "MkChecks V4.1 • Apenas leitura • CSV e HTML anexados" }
                }
            )
        } | ConvertTo-Json -Depth 6 -Compress

        $sentOk = $false
        $hc = $null
        $mc = $null
        try {
            $hc = New-Object System.Net.Http.HttpClient
            $mc = New-Object System.Net.Http.MultipartFormDataContent
            $mc.Add((New-Object System.Net.Http.StringContent($payload, [System.Text.Encoding]::UTF8, "application/json")), "payload_json")

            if ($tempCsv -and ([System.IO.File]::Exists($tempCsv))) {
                $fbCsv = [System.IO.File]::ReadAllBytes($tempCsv)
                $bcCsv = New-Object System.Net.Http.ByteArrayContent(,$fbCsv)
                $bcCsv.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("text/csv")
                $mc.Add($bcCsv, "files[0]", [System.IO.Path]::GetFileName($tempCsv))
            }

            if ($tempHtml -and ([System.IO.File]::Exists($tempHtml))) {
                $fbHtml = [System.IO.File]::ReadAllBytes($tempHtml)
                $bcHtml = New-Object System.Net.Http.ByteArrayContent(,$fbHtml)
                $bcHtml.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("text/html")
                $mc.Add($bcHtml, "files[1]", [System.IO.Path]::GetFileName($tempHtml))
            }

            $resp = $hc.PostAsync($script:WebhookUrl, $mc).Result
            $sentOk = $resp.IsSuccessStatusCode
            if (-not $sentOk) {
                "Multipart HTTP $([int]$resp.StatusCode): $($resp.ReasonPhrase)" | Out-File -LiteralPath (Join-Path $env:TEMP "MkChecks_last_error.txt") -Encoding UTF8
            }
        } catch {
            "Multipart exception: $($_.Exception.Message)" | Out-File -LiteralPath (Join-Path $env:TEMP "MkChecks_last_error.txt") -Encoding UTF8
        } finally {
            if ($mc) { $mc.Dispose() }
            if ($hc) { $hc.Dispose() }
        }

        if (-not $sentOk) {
            Invoke-RestMethod -Uri $script:WebhookUrl -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -ContentType "application/json; charset=utf-8" -ErrorAction Stop
            Remove-Item -LiteralPath (Join-Path $env:TEMP "MkChecks_last_error.txt") -Force -ErrorAction SilentlyContinue
        }
    }
} catch {
    "Webhook final error: $($_.Exception.Message)" | Out-File -LiteralPath (Join-Path $env:TEMP "MkChecks_last_error.txt") -Encoding UTF8
} finally {
}

Queue-UI -Percent 100 -Text "Análise forense v4.1 concluída" -SubText "HTML, CSV e JSON guardados; upload externo opcional"
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
        } catch {
            "Worker EndInvoke error: $($_.Exception.Message)" | Out-File -LiteralPath (Join-Path $env:TEMP "MkChecks_last_error.txt") -Encoding UTF8
        } finally {
            try { $script:PsInstance.Dispose() } catch {}
            try { $script:Runspace.Close(); $script:Runspace.Dispose() } catch {}
        }
    }
})

$form.Add_Shown({
    $uiTimer.Start()
})

$form.Add_FormClosed({
    try { $uiTimer.Stop() } catch {}
    try { $uiTimer.Dispose() } catch {}
    try { if ($script:PsInstance) { $script:PsInstance.Dispose() } } catch {}
    try { if ($script:Runspace) { $script:Runspace.Close(); $script:Runspace.Dispose() } } catch {}
    try { if ($picBanner.Image) { $picBanner.Image.Dispose() } } catch {}
})

[void]$form.ShowDialog()
