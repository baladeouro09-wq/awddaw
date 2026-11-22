# ==============================================================================
# MkChecks Forensic Scanner - Compact Card (Preto & Roxo) + Motor Forense
# Apenas leitura. Não apaga ficheiros, não altera registo nem desativa segurança.
# ==============================================================================

$script:WebhookUrl = "https://discord.com/api/webhooks/1574173816098259054/P0wRGzaR-zlpIOvH6wqGy6z-nGU4fUFFR-d5sFfi26TGGoRL81Gz-2bS2L-U9wqkx-O6"
$script:AutoRunAndSend = $true

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try { [System.Windows.Forms.Application]::EnableVisualStyles() } catch {}

# Limiar elevado para filtrar ruído e focar em cheats, loaders, injectors e spoofers
$script:Threshold = 65
$script:MaxResults = 20

# Padrões focados exclusivamente em cheats, spoofers, loaders, injectors e manipulação FiveM/GTA
$cheatStrongPattern = '(?i)(fivem[-_ ]?exeternal|fivem[-_ ]?external|aimbot|wallhack|wall[-_ ]?hack|spoofer|hwid[-_ ]?spoof|mod[-_ ]?menu|triggerbot|silent[-_ ]?aim|ragebot|redengine|eulen|skript\.gg|lynx|lumia|tz[-_ ]?project|hx[-_ ]?cheats|desudo|brutan|kekhack|interwebz|neverlose|onetap|gamesense|skeet|fatality|aimware|iniuria|vape[-_ ]?v4|wurst|meteor[-_ ]?client|aristois|xenos|extreme[-_ ]?injector|process[-_ ]?hacker|kdmapper|drvmap|gdrv|capcom\.sys|iqvw64e\.sys|dsefix|winring0|anticheat[-_ ]?bypass|ac[-_ ]?bypass|cleaner[-_ ]?fivem|unban[-_ ]?fivem|aimlock|spinbot|esp[-_ ]?hack|radar[-_ ]?hack|norecoil|no[-_ ]?spread)'
$cheatMediumPattern = '(?i)(manual[-_ ]?map|reflective[-_ ]?dll|hollowing|syscall|hwid|spoofer|injector|loader|dumper|offset[-_ ]?finder|cheat[-_ ]?engine|artmoney|wemod|autoclicker|recoil[-_ ]?script|no[-_ ]?recoil|dll[-_ ]?inject|kernel[-_ ]?drv)'

# Exclusões rigorosas para evitar falsos positivos em software legítimo comum
$strictExcludePattern = '(?i)\\(Windows\\WinSxS|Windows\\System32\\DriverStore|Windows\\servicing|Program Files\\Windows Defender|Program Files\\WindowsApps|ProgramData\\Microsoft\\Windows Defender|Microsoft\\Edge|Google\\Chrome|Mozilla Firefox|Discord|Medal|Steam|Epic Games|Riot Games|Battle\.net|Ubisoft|Electronic Arts|Overwolf|OBS Studio|Streamlabs|Logitech|Razer|Corsair|SteelSeries|NVIDIA Corporation|AMD|Intel)(\\|$)'

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
$script:Findings = [System.Collections.Concurrent.ConcurrentQueue[pscustomobject]]::new()
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
$form.Text = "MkChecks"
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
$lblStatus.Text = "A preparar verificação... (0%)"
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
$lblSub.Text = "Verificação em curso — não feche esta janela"
$lblSub.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblSub.ForeColor = $textGray
$lblSub.Location = New-Object System.Drawing.Point(16, 78)
$lblSub.Size = New-Object System.Drawing.Size(356, 20)
$card.Controls.Add($lblSub)

$lblFoot = New-Object System.Windows.Forms.Label
$lblFoot.Text = "MkChecks • Investigação Forense FiveM & GTA V"
$lblFoot.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblFoot.ForeColor = [System.Drawing.Color]::FromArgb(124, 111, 163)
$lblFoot.Location = New-Object System.Drawing.Point(16, 124)
$lblFoot.Size = New-Object System.Drawing.Size(356, 20)
$lblFoot.TextAlign = "MiddleCenter"
$card.Controls.Add($lblFoot)

# ==============================================================================
# WORKER FORENSE EM RUNSPACE
# ==============================================================================
$script:Runspace = [runspacefactory]::CreateRunspace()
$script:Runspace.ApartmentState = "STA"
$script:Runspace.Open()
$script:Runspace.SessionStateProxy.SetVariable("WebhookUrl", $script:WebhookUrl)
$script:Runspace.SessionStateProxy.SetVariable("Threshold", $script:Threshold)
$script:Runspace.SessionStateProxy.SetVariable("MaxResults", $script:MaxResults)
$script:Runspace.SessionStateProxy.SetVariable("cheatStrongPattern", $cheatStrongPattern)
$script:Runspace.SessionStateProxy.SetVariable("cheatMediumPattern", $cheatMediumPattern)
$script:Runspace.SessionStateProxy.SetVariable("strictExcludePattern", $strictExcludePattern)
$script:Runspace.SessionStateProxy.SetVariable("scanRoots", $scanRoots)
$script:Runspace.SessionStateProxy.SetVariable("UiQueue", $script:UiQueue)
$script:Runspace.SessionStateProxy.SetVariable("Findings", $script:Findings)
$script:Runspace.SessionStateProxy.SetVariable("SkippedSources", $script:SkippedSources)

$script:PsInstance = [powershell]::Create()
$script:PsInstance.Runspace = $script:Runspace

$workerScript = @'
$script:WebhookUrl = $WebhookUrl
$script:Threshold = $Threshold
$script:MaxResults = $MaxResults
$script:UiQueue = $UiQueue
$script:Findings = $Findings
$script:SkippedSources = $SkippedSources
$script:fileCounter = 0

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

function Get-CertInfoFast {
    param([string]$Path)
    if (-not $Path -or -not ([System.IO.File]::Exists($Path))) {
        return @{ Status = "N/A"; Publisher = "N/A" }
    }
    try {
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromSignedFile($Path)
        if ($cert) {
            $pub = $cert.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
            if (-not $pub) { $pub = $cert.Subject }
            return @{ Status = "Signed"; Publisher = $pub }
        }
        return @{ Status = "Unsigned"; Publisher = "Sem assinatura" }
    } catch {
        return @{ Status = "Unsigned"; Publisher = "Sem assinatura" }
    }
}

function Get-Sha256Fast {
    param([string]$Path)
    if (-not $Path -or -not ([System.IO.File]::Exists($Path))) { return "N/A" }
    try {
        $fi = New-Object System.IO.FileInfo($Path)
        if ($fi.Length -gt 120MB) { return "Grande(>120MB)" }
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $bytes = $sha.ComputeHash($fs)
            return (([System.BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant())
        } finally {
            $fs.Close()
            $sha.Dispose()
        }
    } catch {
        return "N/A"
    }
}

function Clean-Name {
    param([string]$Name, [string]$Path)
    $n = if ($Name) { $Name.Trim() } else { "" }
    if ([string]::IsNullOrWhiteSpace($n) -and $Path) {
        $n = [System.IO.Path]::GetFileName($Path)
        if ([string]::IsNullOrWhiteSpace($n)) {
            $parts = $Path -split '[\\/]'
            $n = ($parts | Where-Object { $_ } | Select-Object -Last 1)
        }
    }
    if ([string]::IsNullOrWhiteSpace($n)) { $n = "artefacto_desconhecido" }
    $n = ($n -replace '[\r\n`\*_~|]', '').Trim()
    if ([string]::IsNullOrWhiteSpace($n)) { $n = "artefacto_desconhecido" }
    if ($n.Length -gt 75) { $n = $n.Substring(0, 72) + "..." }
    return $n
}

function Classify-Category {
    param([string]$Text)
    if ($Text -match '(?i)(spoofer|hwid|cleaner[-_ ]?fivem|unban[-_ ]?fivem|gdrv|capcom|iqvw64e|dsefix|winring0|kdmapper|drvmap)') {
        return "Spoofer / Kernel Manipulator"
    }
    if ($Text -match '(?i)(xenos|extreme[-_ ]?injector|manual[-_ ]?map|reflective[-_ ]?dll|hollowing|injector|dll[-_ ]?inject|loader)') {
        return "Injector / Loader"
    }
    if ($Text -match '(?i)(redengine|eulen|skript\.gg|lynx|lumia|fivem[-_ ]?exeternal|fivem[-_ ]?external|aimbot|wallhack|triggerbot|silent[-_ ]?aim|ragebot|mod[-_ ]?menu|cheat|esp[-_ ]?hack)') {
        return "Cheat / Mod Menu"
    }
    return "Ferramenta de Memória / Bypass"
}

function Evaluate-ForensicTarget {
    param(
        [string]$Area,
        [string]$RawName,
        [string]$RawPath,
        [string]$Details,
        [bool]$IsRunning = $false,
        [bool]$IsHistorical = $false,
        [bool]$IsPersistence = $false,
        [string]$SigStatus = "N/A",
        [string]$Publisher = "N/A",
        [string]$Sha256 = "N/A",
        [string]$Timestamp = "N/A"
    )

    $pathVal = if ([string]::IsNullOrWhiteSpace($RawPath)) { "N/A" } else { $RawPath.Trim() }
    if ($pathVal -ne "N/A" -and ($pathVal -match $strictExcludePattern)) { return }

    $nameVal = Clean-Name -Name $RawName -Path $pathVal
    $combined = "$nameVal $pathVal $Details"

    # Só avalia alvos com correspondência direta a padrões de cheat/spoofer/loader/injector/bypass
    $matchedStrong = ($combined -match $cheatStrongPattern)
    $matchedMedium = ($combined -match $cheatMediumPattern)
    if (-not $matchedStrong -and -not $matchedMedium) { return }

    $score = 0
    $reasons = New-Object System.Collections.Generic.List[string]
    $evidence = New-Object System.Collections.Generic.List[string]

    if ($matchedStrong) {
        $score += 70
        $reasons.Add("assinatura/nome associado a cheat, spoofer, loader ou bypass conhecido")
        $evidence.Add("correspondência direta de assinatura de cheat/spoofer")
    } else {
        $score += 35
        $reasons.Add("termo associado a injeção, mapeamento de memória ou spoofer")
        $evidence.Add("indicador de injeção/memória/spoofer")
    }

    if ($pathVal -match '(?i)\\(AppData|Temp|Downloads|Desktop|Recycle\.Bin|ProgramData)\\') {
        $score += 10
        $reasons.Add("localização frequente de executáveis/loaders de utilizador")
        $evidence.Add("caminho em diretório de utilizador/temp/downloads")
    }

    if ($IsRunning) {
        $score += 20
        $reasons.Add("ativo em memória durante a verificação")
        $evidence.Add("processo ou módulo carregado em execução")
    }

    if ($IsPersistence) {
        $score += 12
        $reasons.Add("presença em mecanismo de arranque/persistência")
        $evidence.Add("entrada de persistência/serviço/tarefa")
    }

    if ($IsHistorical) {
        $score += 8
        $reasons.Add("rasto de execução prévia registado no sistema")
        $evidence.Add("vestígio em Prefetch/BAM/Cache")
    }

    if ($SigStatus -eq "Unsigned") {
        $score += 5
        $reasons.Add("binário sem assinatura digital")
    } elseif ($SigStatus -eq "Signed") {
        # Assinatura válida reduz score mas não anula evidência forte isolada
        $score -= 10
        $reasons.Add("assinatura digital presente ($Publisher)")
    }

    $score = [Math]::Max(0, [Math]::Min(100, $score))
    if ($score -lt $script:Threshold) { return }

    $category = Classify-Category -Text $combined
    $confidence = if ($score -ge 85) { "Elevado" } elseif ($score -ge 70) { "Médio-Alto" } else { "Moderado" }
    $tier = if ($IsRunning -or ($matchedStrong -and $score -ge 80)) {
        "EvidenciaConfirmada"
    } elseif ($score -ge 65) {
        "IndicadorSuspeito"
    } else {
        "DadoInconclusivo"
    }

    $hashShort = if ($Sha256 -and $Sha256.Length -gt 16) { $Sha256.Substring(0, 16) + "..." } else { $Sha256 }

    $script:Findings.Enqueue([pscustomobject]@{
        Score       = $score
        Tier        = $tier
        Nome        = $nameVal
        Caminho     = $pathVal
        Categoria   = $category
        Motivos     = ($reasons -join "; ")
        Evidencias  = ($evidence -join "; ")
        SHA256      = $Sha256
        SHA256Short = $hashShort
        Assinatura  = $SigStatus
        Publisher   = $Publisher
        DataHora    = $Timestamp
        Confianca   = $confidence
        Explicacao  = "Detetado padrão de $category com cruzamento de contexto ($Area)."
        Detalhes    = $Details
    })
}

# 1. PROCESSOS ATIVOS & MÓDULOS
Queue-UI -Percent 10 -Text "A analisar processos e módulos..."
$runningMap = @{}
try {
    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        $exe = $p.ExecutablePath
        $pName = Clean-Name -Name $p.Name -Path $exe
        if ($exe) { $runningMap[$exe.ToLowerInvariant()] = $true }
        $combinedProc = "$pName $exe $($p.CommandLine)"
        if ($combinedProc -match $cheatStrongPattern -or $combinedProc -match $cheatMediumPattern) {
            $ci = Get-CertInfoFast -Path $exe
            $h = Get-Sha256Fast -Path $exe
            $dt = ""
            try { if ($p.CreationDate) { $dt = ([Management.ManagementDateTimeConverter]::ToDateTime($p.CreationDate)).ToString("yyyy-MM-dd HH:mm:ss") } } catch {}
            Evaluate-ForensicTarget -Area "Processo Ativo" -RawName $pName -RawPath $exe `
                -Details "PID=$($p.ProcessId); PPID=$($p.ParentProcessId); Cmd=$($p.CommandLine)" `
                -IsRunning $true -SigStatus $ci.Status -Publisher $ci.Publisher -Sha256 $h -Timestamp $dt
        }
    }

    $targetGames = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match '(?i)(fivem|gta5|gtav|five|ragemp|altv)'
    }
    foreach ($gp in $targetGames) {
        try {
            foreach ($m in $gp.Modules) {
                $mComb = "$($m.ModuleName) $($m.FileName)"
                if ($mComb -match $cheatStrongPattern -or $mComb -match $cheatMediumPattern) {
                    $ciM = Get-CertInfoFast -Path $m.FileName
                    $hM = Get-Sha256Fast -Path $m.FileName
                    Evaluate-ForensicTarget -Area "Módulo em Processo" -RawName $m.ModuleName -RawPath $m.FileName `
                        -Details "Processo=$($gp.ProcessName) (PID=$($gp.Id))" `
                        -IsRunning $true -SigStatus $ciM.Status -Publisher $ciM.Publisher -Sha256 $hM
                }
            }
        } catch {
            Add-Skipped "Módulos de $($gp.ProcessName)"
        }
    }
} catch {
    Add-Skipped "Win32_Process"
}

# 2. FICHEIROS (RELAÇÃO DE DIRETÓRIOS FIVEM / GTA / SISTEMA / UTILIZADOR)
Queue-UI -Percent 25 -Text "A analisar ficheiros de cheats e spoofers..."
$seen = @{}
$extAllowed = '(?i)^\.(exe|dll|sys|bat|cmd|ps1|vbs|js|scr|rar|zip|7z|asi|lua)$'

function Scan-ForensicDir {
    param([string]$Dir, [int]$Depth, [int]$MaxDepth)
    if ($Depth -gt $MaxDepth) { return }
    if (-not $Dir -or ($Dir -match $strictExcludePattern)) { return }

    $script:fileCounter++
    if (($script:fileCounter % 400) -eq 0) {
        $pct = [Math]::Min(62, 25 + [int](($script:fileCounter / 4000.0) * 37))
        Queue-UI -Percent $pct -Text "A analisar ficheiros de cheats e spoofers..."
    }

    try {
        $files = [System.IO.Directory]::GetFiles($Dir)
        foreach ($f in $files) {
            if ($f -match $strictExcludePattern) { continue }
            $ext = [System.IO.Path]::GetExtension($f)
            if ($ext -notmatch $extAllowed) { continue }
            $fn = [System.IO.Path]::GetFileName($f)
            if ($fn -notmatch $cheatStrongPattern -and $fn -notmatch $cheatMediumPattern) { continue }

            $k = $f.ToLowerInvariant()
            if ($seen.ContainsKey($k)) { continue }
            $seen[$k] = $true

            $isRun = $runningMap.ContainsKey($k)
            $ci = if ($ext -match '(?i)^\.(exe|dll|sys|scr)$') { Get-CertInfoFast -Path $f } else { @{ Status = "N/A"; Publisher = "N/A" } }
            $h = Get-Sha256Fast -Path $f
            $ts = "N/A"
            $szKb = 0
            try {
                $fi = New-Object System.IO.FileInfo($f)
                $ts = $fi.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                $szKb = [Math]::Round($fi.Length / 1KB, 1)
            } catch {}

            Evaluate-ForensicTarget -Area "Ficheiro" -RawName $fn -RawPath $f `
                -Details "Tamanho=${szKb}KB" -IsRunning $isRun `
                -SigStatus $ci.Status -Publisher $ci.Publisher -Sha256 $h -Timestamp $ts
        }
    } catch {}

    try {
        $subs = [System.IO.Directory]::GetDirectories($Dir)
        foreach ($s in $subs) {
            if ($s -match $strictExcludePattern) { continue }
            Scan-ForensicDir -Dir $s -Depth ($Depth + 1) -MaxDepth $MaxDepth
        }
    } catch {}
}

foreach ($root in $scanRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $md = if ($root -eq 'C:\') { 2 } elseif ($root -match '(?i)\\System32(\\drivers)?$') { 2 } else { 5 }
    Scan-ForensicDir -Dir $root -Depth 0 -MaxDepth $md
}

# 3. HISTÓRICO FORENSE (PREFETCH & RECENT) & REGISTRY / PERSISTÊNCIA
Queue-UI -Percent 68 -Text "A analisar Prefetch, Registo e persistência..."
$pfDir = "$env:SystemRoot\Prefetch"
if (Test-Path -LiteralPath $pfDir) {
    try {
        Get-ChildItem -LiteralPath $pfDir -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match $cheatStrongPattern -or $_.Name -match $cheatMediumPattern } |
            ForEach-Object {
                $cleanPf = $_.Name -replace '-[A-F0-9]{8}\.pf$', ''
                Evaluate-ForensicTarget -Area "Prefetch" -RawName $cleanPf -RawPath $_.FullName `
                    -Details "Execução registada no Prefetch" -IsHistorical $true `
                    -Timestamp $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
    } catch {
        Add-Skipped "Prefetch"
    }
}

$regTargets = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings\*",
    "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SYSTEM\CurrentControlSet\Services\*"
)
foreach ($rt in $regTargets) {
    try {
        Get-Item -Path $rt -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($vn in $_.GetValueNames()) {
                $vd = ""
                try { $vd = [string]$_.GetValue($vn) } catch {}
                $combR = "$vn $vd"
                if ($combR -match $cheatStrongPattern -or $combR -match $cheatMediumPattern) {
                    $cand = if ($vd -match '[A-Za-z]:\\') { $vd } else { $vn }
                    $exN = [System.IO.Path]::GetFileName($cand)
                    if ([string]::IsNullOrWhiteSpace($exN)) { $exN = $vn }
                    $isPersist = ($_.PSPath -match '\\Run$|\\Services\\')
                    Evaluate-ForensicTarget -Area $(if ($isPersist) { "Persistência/Registry" } else { "Registry BAM/Cache" }) `
                        -RawName $exN -RawPath $cand -Details "Chave=$($_.PSChildName)" `
                        -IsHistorical (-not $isPersist) -IsPersistence $isPersist
                }
            }
        }
    } catch {
        Add-Skipped $rt
    }
}

# Nota explícita de fontes forenses brutas não lidas diretamente sem parser de baixo nível
Add-Skipped "MFT / USN Journal / SRUM / Event Logs (análise parcial)"

# 4. CONSOLIDAÇÃO (TOP 20 RESULTADOS RELEVANTES)
Queue-UI -Percent 88 -Text "A consolidar relatório forense..."
$allRaw = @($script:Findings.ToArray())
$consolidated = $allRaw |
    Group-Object { "$($_.Nome.ToLowerInvariant())|$($_.Caminho.ToLowerInvariant())" } |
    ForEach-Object {
        $top = $_.Group | Sort-Object Score -Descending | Select-Object -First 1
        $top
    } |
    Sort-Object Score -Descending |
    Select-Object -First $script:MaxResults

# 5. ENVIO DO RELATÓRIO LIMPO PARA O WEBHOOK
Queue-UI -Percent 96 -Text "A enviar relatório para o Discord..."
try {
    if (-not [string]::IsNullOrWhiteSpace($script:WebhookUrl) -and $script:WebhookUrl -ne "COLA_AQUI_O_TEU_WEBHOOK_URL") {
        $pcName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { "PC" }
        $userName = if ($env:USERNAME) { $env:USERNAME } else { "Utilizador" }
        $dateStr = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

        $confirmed = @($consolidated | Where-Object { $_.Tier -eq "EvidenciaConfirmada" })
        $suspects  = @($consolidated | Where-Object { $_.Tier -eq "IndicadorSuspeito" })
        $inconcl   = @($consolidated | Where-Object { $_.Tier -eq "DadoInconclusivo" })

        $lines = New-Object System.Collections.Generic.List[string]
        if ($consolidated.Count -eq 0) {
            $lines.Add("Nenhuma correspondência direta a cheats, spoofers, loaders ou injectors detetada acima do limiar ($($script:Threshold)/100).")
        } else {
            foreach ($item in $consolidated) {
                $pShort = if ($item.Caminho -ne "N/A" -and $item.Caminho.Length -gt 72) {
                    "..." + $item.Caminho.Substring($item.Caminho.Length - 69)
                } else {
                    $item.Caminho
                }
                $lines.Add("• **[$($item.Score)/100]** ``$($item.Nome)`` — **$($item.Categoria)** ($($item.Confianca))")
                $lines.Add("  ↳ ``$pShort`` | Hash: ``$($item.SHA256Short)`` | Assinatura: ``$($item.Assinatura)``")
            }
        }

        $skippedList = @($script:SkippedSources.ToArray() | Select-Object -Unique)
        $limNote = if ($skippedList.Count -gt 0) {
            "`n**Limitações / Fontes não analisadas a fundo:** " + ($skippedList -join ", ") + ". A ausência de deteção não garante que o sistema esteja limpo."
        } else {
            "`n**Nota:** A ausência de deteção não garante que o sistema esteja limpo."
        }

        $desc = "**Utilizador:** ``$userName```n**Data:** $dateStr`n**Resumo:** $($consolidated.Count) achados relevantes (Confirmados: $($confirmed.Count) | Suspeitos: $($suspects.Count) | Inconclusivos: $($inconcl.Count))`n`n" + ($lines -join "`n") + $limNote
        if ($desc.Length -gt 3950) {
            $desc = $desc.Substring(0, 3920) + "`n... *(ver CSV completo em anexo)*"
        }

        $tempCsv = Join-Path $env:TEMP "MkChecks_Forensic_${pcName}_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
        if ($consolidated.Count -gt 0) {
            $consolidated | Select-Object Score, Tier, Nome, Categoria, Caminho, SHA256, Assinatura, Publisher, Confianca, DataHora, Motivos, Evidencias, Explicacao, Detalhes |
                Export-Csv -LiteralPath $tempCsv -NoTypeInformation -Encoding UTF8
        } else {
            "Sem correspondencias diretas acima do limiar em $pcName ($userName) em $dateStr" | Out-File -LiteralPath $tempCsv -Encoding UTF8
        }

        $embedColor = if ($confirmed.Count -gt 0) { 10181046 } elseif ($consolidated.Count -gt 0) { 8926719 } else { 7419530 }
        $payload = @{
            username = "MkChecks"
            embeds   = @(
                @{
                    title       = "Relatório Forense MkChecks — $pcName"
                    description = $desc
                    color       = $embedColor
                    footer      = @{ text = "MkChecks Forense • Apenas leitura • Top $script:MaxResults" }
                }
            )
        } | ConvertTo-Json -Depth 6 -Compress

        Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
        $hc = New-Object System.Net.Http.HttpClient
        $mc = New-Object System.Net.Http.MultipartFormDataContent
        $mc.Add((New-Object System.Net.Http.StringContent($payload, [System.Text.Encoding]::UTF8, "application/json")), "payload_json")
        $fb = [System.IO.File]::ReadAllBytes($tempCsv)
        $bc = New-Object System.Net.Http.ByteArrayContent(,$fb)
        $bc.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("text/csv")
        $mc.Add($bc, "file", [System.IO.Path]::GetFileName($tempCsv))
        $null = $hc.PostAsync($script:WebhookUrl, $mc).Result
        $hc.Dispose()
        Remove-Item -LiteralPath $tempCsv -Force -ErrorAction SilentlyContinue
    }
} catch {}

Queue-UI -Percent 100 -Text "Análise concluída" -SubText "Verificação concluída — relatório enviado"
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
