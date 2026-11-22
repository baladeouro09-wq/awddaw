# ==============================================================================
# MkChecks Pro - Compact Card Scanner (Preto & Roxo)
# Apenas leitura. Não apaga ficheiros, não altera registo nem desativa segurança.
# ==============================================================================

$script:WebhookUrl = "https://discord.com/api/webhooks/1574173816098259054/P0wRGzaR-zlpIOvH6wqGy6z-nGU4fUFFR-d5sFfi26TGGoRL81Gz-2bS2L-U9wqkx-O6"
$script:AutoRunAndSend = $true

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try { [System.Windows.Forms.Application]::EnableVisualStyles() } catch {}

$script:Threshold = 60
$script:MaxResults = 50

$strongPattern = '(?i)(fivem[-_ ]?exeternal|fivem[-_ ]?external|aimbot|wallhack|wall[-_ ]?hack|spoofer|hwid[-_ ]?spoof|cheat|mod[-_ ]?menu|triggerbot|silent[-_ ]?aim|ragebot|redengine|eulen|skript\.gg|lynx|lumia|tz[-_ ]?project|hx[-_ ]?cheats|desudo|brutan|kekhack|interwebz|neverlose|onetap|gamesense|skeet|fatality|aimware|iniuria|vape[-_ ]?v4|lunar[-_ ]?client[-_ ]?crack|wurst|meteor[-_ ]?client|aristois|xenos|extreme[-_ ]?injector|process[-_ ]?hacker|kdmapper|drvmap|gdrv|capcom\.sys|iqvw64e\.sys|dsefix|winring0|anticheat[-_ ]?bypass|ac[-_ ]?bypass|cleaner[-_ ]?fivem|unban[-_ ]?fivem|aim[-_ ]?assist|esp[-_ ]?hack|radar[-_ ]?hack|norecoil|no[-_ ]?spread|bhop[-_ ]?script|spinbot|aimlock)'
$mediumPattern = '(?i)(injector|manual[-_ ]?map|reflective[-_ ]?dll|hollowing|syscall|spoof|bypass|dumper|offset[-_ ]?finder|memory[-_ ]?edit|cheat[-_ ]?engine|artmoney|wemod|autoclicker|recoil[-_ ]?script|no[-_ ]?recoil|macro[-_ ]?pro|ahk[-_ ]?script|overlay|hook|dll[-_ ]?inject|kernel[-_ ]?drv|mapper|cleaner|unban|hwid)'
$excludedPathPattern = '(?i)\\(Medal|Discord|Microsoft|Windows|NVIDIA|AMD|Intel|Steam|Epic Games|Riot Games|Battle\.net|Ubisoft|Electronic Arts|Overwolf|OBS|Streamlabs|Logitech|Razer|Corsair|SteelSeries|FiveM\\FiveM\.app\\plugins\\reshade)(\\|$)'

$scanRoots = @(
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\OneDrive\Desktop",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\OneDrive\Documents",
    "$env:APPDATA",
    "$env:LOCALAPPDATA",
    "$env:TEMP",
    "$env:ProgramData",
    "C:\Users\Public",
    "C:\"
) | Select-Object -Unique

$script:UiQueue = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
$script:Findings = [System.Collections.Concurrent.ConcurrentQueue[pscustomobject]]::new()
$script:ScanDone = $false

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
# DESENHO DO LOGO "MkChecks" EM PRETO & ROXO
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

# ==============================================================================
# JANELA ÚNICA COMPACTA (QUADRADO PRETO & ROXO)
# ==============================================================================
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
$lblFoot.Text = "MkChecks • Análise de segurança"
$lblFoot.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblFoot.ForeColor = [System.Drawing.Color]::FromArgb(124, 111, 163)
$lblFoot.Location = New-Object System.Drawing.Point(16, 124)
$lblFoot.Size = New-Object System.Drawing.Size(356, 20)
$lblFoot.TextAlign = "MiddleCenter"
$card.Controls.Add($lblFoot)

# ==============================================================================
# WORKER EM RUNSPACE (ANÁLISE FORENSE + RELATÓRIO DETALHADO)
# ==============================================================================
$script:Runspace = [runspacefactory]::CreateRunspace()
$script:Runspace.ApartmentState = "STA"
$script:Runspace.Open()
$script:Runspace.SessionStateProxy.SetVariable("WebhookUrl", $script:WebhookUrl)
$script:Runspace.SessionStateProxy.SetVariable("Threshold", $script:Threshold)
$script:Runspace.SessionStateProxy.SetVariable("MaxResults", $script:MaxResults)
$script:Runspace.SessionStateProxy.SetVariable("strongPattern", $strongPattern)
$script:Runspace.SessionStateProxy.SetVariable("mediumPattern", $mediumPattern)
$script:Runspace.SessionStateProxy.SetVariable("excludedPathPattern", $excludedPathPattern)
$script:Runspace.SessionStateProxy.SetVariable("scanRoots", $scanRoots)
$script:Runspace.SessionStateProxy.SetVariable("UiQueue", $script:UiQueue)
$script:Runspace.SessionStateProxy.SetVariable("Findings", $script:Findings)

$script:PsInstance = [powershell]::Create()
$script:PsInstance.Runspace = $script:Runspace

$workerFullScript = @'
$script:WebhookUrl = $WebhookUrl
$script:Threshold = $Threshold
$script:MaxResults = $MaxResults
$script:UiQueue = $UiQueue
$script:Findings = $Findings
$script:fileCounter = 0

function Queue-UI {
    param([int]$Percent, [string]$Text, [string]$SubText = "")
    $script:UiQueue.Enqueue(@{
        Percent = [Math]::Max(0, [Math]::Min(100, $Percent))
        Text    = $Text
        SubText = $SubText
    })
}

function Get-SignatureStatusFast {
    param([string]$Path)
    if (-not $Path -or -not ([System.IO.File]::Exists($Path))) { return "N/A" }
    try {
        $sig = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromSignedFile($Path)
        if ($sig) { return "Valid" }
        return "NotSigned"
    } catch {
        return "NotSigned"
    }
}

function Get-FileSha256Short {
    param([string]$Path)
    if (-not $Path -or -not ([System.IO.File]::Exists($Path))) { return "N/A" }
    try {
        $fi = New-Object System.IO.FileInfo($Path)
        if ($fi.Length -gt 100MB) { return "Grande(>100MB)" }
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $hashBytes = $sha.ComputeHash($fs)
            $hex = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
            return $hex.Substring(0, 12)
        } finally {
            $fs.Close()
            $sha.Dispose()
        }
    } catch {
        return "N/A"
    }
}

function Normalize-ItemName {
    param([string]$RawName, [string]$RawPath)
    $n = ""
    if (-not [string]::IsNullOrWhiteSpace($RawName)) {
        $n = $RawName.Trim()
    }
    if ([string]::IsNullOrWhiteSpace($n) -and -not [string]::IsNullOrWhiteSpace($RawPath)) {
        $n = [System.IO.Path]::GetFileName($RawPath)
        if ([string]::IsNullOrWhiteSpace($n)) {
            $parts = $RawPath -split '[\\/]'
            $n = ($parts | Where-Object { $_ } | Select-Object -Last 1)
        }
    }
    if ([string]::IsNullOrWhiteSpace($n)) {
        $n = "item_desconhecido"
    }
    # Remover caracteres que quebram markdown ou deixam em branco no Discord
    $n = ($n -replace '[\r\n`\*_~|]', '').Trim()
    if ([string]::IsNullOrWhiteSpace($n)) { $n = "item_desconhecido" }
    if ($n.Length -gt 80) { $n = $n.Substring(0, 77) + "..." }
    return $n
}

function Get-Suspicion {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Area = "",
        [bool]$IsRunning = $false,
        [bool]$IsPrefetch = $false,
        [string]$SignatureStatus = "",
        [bool]$HasHiddenOrTempTraits = $false
    )

    $score = 0
    $reasons = New-Object System.Collections.Generic.List[string]
    $combined = "$Name $Path"

    if ($combined -match $strongPattern) {
        $score += 70
        $reasons.Add("assinatura/nome de cheat ou spoofer")
    } elseif ($combined -match $mediumPattern) {
        $score += 38
        $reasons.Add("ferramenta de injeção/bypass/memória")
    } else {
        return $null
    }

    if ($Path -match '(?i)\\AppData\\|\\Temp\\|\\ProgramData\\|\\Downloads\\|\\Recycle\.Bin\\') {
        $score += 15
        $reasons.Add("pasta temporária/downloads/lixeira")
    }

    if ($IsRunning) {
        $score += 25
        $reasons.Add("processo ativo")
    }

    if ($IsPrefetch -or $Area -match 'Prefetch|Registo|BAM|MuiCache|RecentDocs|RunMRU|Startup|Task') {
        $score += 15
        $reasons.Add("rasto de execução/persistência")
    }

    if ($Path -match '(?i)\.(exe|dll|sys|bat|cmd|ps1|vbs|ahk|scr|com|pif)$') {
        $score += 5
        $reasons.Add("binário/script")
    }

    if ($HasHiddenOrTempTraits) {
        $score += 8
        $reasons.Add("atributos/comportamento suspeito")
    }

    if ($SignatureStatus -eq "NotSigned" -or $SignatureStatus -eq "HashMismatch") {
        $score += 12
        $reasons.Add("sem assinatura digital")
    } elseif ($SignatureStatus -eq "Valid") {
        $score -= 25
        $reasons.Add("assinatura válida")
    }

    return [pscustomobject]@{
        Score   = [Math]::Max(0, [Math]::Min(100, $score))
        Reasons = ($reasons -join "; ")
    }
}

function Add-HighFinding {
    param(
        [string]$Area,
        [string]$Item,
        [string]$Path,
        [string]$Details,
        [bool]$IsRunning = $false,
        [bool]$IsPrefetch = $false,
        [string]$SignatureStatus = "",
        [bool]$HasHiddenOrTempTraits = $false,
        [string]$HashShort = "N/A"
    )

    if ($Path -and ($Path -match $excludedPathPattern)) { return }

    $cleanName = Normalize-ItemName -RawName $Item -RawPath $Path
    $cleanPath = if ([string]::IsNullOrWhiteSpace($Path)) { "N/A" } else { $Path.Trim() }

    $s = Get-Suspicion -Name $cleanName -Path $cleanPath -Area $Area `
        -IsRunning $IsRunning -IsPrefetch $IsPrefetch `
        -SignatureStatus $SignatureStatus -HasHiddenOrTempTraits $HasHiddenOrTempTraits

    if ($null -eq $s -or $s.Score -lt $script:Threshold) { return }

    $nivel = if ($s.Score -ge 90) { "CRÍTICO" } elseif ($s.Score -ge 75) { "ALTO" } else { "SUSPEITO" }

    $script:Findings.Enqueue([pscustomobject]@{
        Score      = $s.Score
        Nivel      = $nivel
        Area       = $Area
        Nome       = $cleanName
        Caminho    = $cleanPath
        SHA256     = $HashShort
        Assinatura = if ($SignatureStatus) { $SignatureStatus } else { "N/A" }
        Evidencias = $s.Reasons
        Detalhes   = $Details
    })
}

function Send-ReportToWebhook {
    param([object[]]$FinalFindings)
    if ([string]::IsNullOrWhiteSpace($script:WebhookUrl) -or $script:WebhookUrl -eq "COLA_AQUI_O_TEU_WEBHOOK_URL") { return }

    try {
        $pcName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { "PC" }
        $userName = if ($env:USERNAME) { $env:USERNAME } else { "Utilizador" }
        $osInfo = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
        if ([string]::IsNullOrWhiteSpace($osInfo)) { $osInfo = "Windows" }
        $dateStr = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

        $safeList = @($FinalFindings | Where-Object { $_ -ne $null })
        $critCount = ($safeList | Where-Object { $_.Nivel -eq "CRÍTICO" }).Count
        $highCount = ($safeList | Where-Object { $_.Nivel -eq "ALTO" }).Count
        $suspCount = ($safeList | Where-Object { $_.Nivel -eq "SUSPEITO" }).Count
        $totalCount = $safeList.Count

        $color = if ($critCount -gt 0) { 10181046 } elseif ($highCount -gt 0) { 12320255 } elseif ($totalCount -gt 0) { 8926719 } else { 7419530 }

        $topSummary = ""
        if ($totalCount -eq 0) {
            $topSummary = "Nenhum indicador detetado acima do limiar ($script:Threshold/100)."
        } else {
            $topItems = $safeList | Select-Object -First 15
            foreach ($f in $topItems) {
                $itemNome = Normalize-ItemName -RawName $f.Nome -RawPath $f.Caminho
                $itemArea = if ($f.Area) { $f.Area } else { "Geral" }
                $itemPath = if ($f.Caminho -and $f.Caminho -ne "N/A") { $f.Caminho } else { "" }
                $topSummary += "• **[$($f.Nivel) - $($f.Score)%]** ``$itemNome`` — *$itemArea*`n"
                if ($itemPath) {
                    $shortPath = if ($itemPath.Length -gt 75) { "..." + $itemPath.Substring($itemPath.Length - 72) } else { $itemPath }
                    $topSummary += "  ↳ ``$shortPath```n"
                }
            }
            if ($totalCount -gt 15) {
                $topSummary += "`n*...e mais $($totalCount - 15) deteções no relatório CSV completo em anexo.*"
            }
        }

        $descText = "**Utilizador:** ``$userName```n**Sistema:** $osInfo`n**Data:** $dateStr`n**Resumo:** $totalCount deteções ($critCount Críticos | $highCount Altos | $suspCount Suspeitos)`n`n**Ficheiros / Rastos Detetados:**`n$topSummary"
        if ($descText.Length -gt 3950) {
            $descText = $descText.Substring(0, 3920) + "`n... *(ver CSV completo em anexo)*"
        }

        $tempCsv = Join-Path $env:TEMP "MkChecks_${pcName}_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
        if ($totalCount -gt 0) {
            $safeList | Select-Object Score, Nivel, Nome, Area, Caminho, SHA256, Assinatura, Evidencias, Detalhes |
                Export-Csv -LiteralPath $tempCsv -NoTypeInformation -Encoding UTF8
        } else {
            "Nenhuma detecao acima do limiar em $pcName ($userName) em $dateStr" | Out-File -LiteralPath $tempCsv -Encoding UTF8
        }

        $payloadObj = @{
            username = "MkChecks"
            embeds   = @(
                @{
                    title       = "Relatório Forense MkChecks — $pcName"
                    description = $descText
                    color       = $color
                    footer      = @{ text = "MkChecks Pro • Top $script:MaxResults deteções + CSV Forense" }
                }
            )
        }
        $jsonPayload = $payloadObj | ConvertTo-Json -Depth 6 -Compress

        Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
        $httpClient = New-Object System.Net.Http.HttpClient
        $content = New-Object System.Net.Http.MultipartFormDataContent

        $jsonContent = New-Object System.Net.Http.StringContent($jsonPayload, [System.Text.Encoding]::UTF8, "application/json")
        $content.Add($jsonContent, "payload_json")

        $fileBytes = [System.IO.File]::ReadAllBytes($tempCsv)
        $byteContent = New-Object System.Net.Http.ByteArrayContent(,$fileBytes)
        $byteContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("text/csv")
        $content.Add($byteContent, "file", [System.IO.Path]::GetFileName($tempCsv))

        $null = $httpClient.PostAsync($script:WebhookUrl, $content).Result
        $httpClient.Dispose()

        Remove-Item -LiteralPath $tempCsv -Force -ErrorAction SilentlyContinue
    } catch {}
}

# ==============================================================================
# ETAPA 1: PROCESSOS ATIVOS, LINHA DE COMANDO & DLLS INJETADAS
# ==============================================================================
Queue-UI -Percent 8 -Text "A analisar processos ativos e DLLs..."

$runningPaths = @{}
try {
    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        $exePath = $p.ExecutablePath
        $procName = Normalize-ItemName -RawName $p.Name -RawPath $exePath
        if ($exePath) {
            $runningPaths[$exePath.ToLowerInvariant()] = $true
            $sigStatus = Get-SignatureStatusFast -Path $exePath
            $hashShort = Get-FileSha256Short -Path $exePath
            Add-HighFinding -Area "Processo Ativo" -Item $procName -Path $exePath `
                -Details "PID=$($p.ProcessId); Cmd=$($p.CommandLine)" `
                -IsRunning $true -SignatureStatus $sigStatus -HashShort $hashShort
        }
        if ($p.CommandLine -and ($p.CommandLine -match $strongPattern -or $p.CommandLine -match $mediumPattern)) {
            $sigCmd = Get-SignatureStatusFast -Path $exePath
            Add-HighFinding -Area "Linha de Comando" -Item $procName -Path $exePath `
                -Details "PID=$($p.ProcessId); Cmd=$($p.CommandLine)" `
                -IsRunning $true -SignatureStatus $sigCmd
        }
    }

    Queue-UI -Percent 18 -Text "A inspecionar módulos e DLLs em memória..."
    $targetProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match '(?i)(fivem|gta|five|cs2|valorant|r5apex|fortnite|minecraft|javaw|roblox|rust|overwolf|discord|cmd|powershell|pwsh|msedge|chrome)'
    }
    foreach ($tp in $targetProcs) {
        try {
            foreach ($mod in $tp.Modules) {
                if ($mod.ModuleName -match $strongPattern -or $mod.FileName -match $strongPattern -or $mod.ModuleName -match $mediumPattern) {
                    $sigMod = Get-SignatureStatusFast -Path $mod.FileName
                    $hashMod = Get-FileSha256Short -Path $mod.FileName
                    $modName = Normalize-ItemName -RawName $mod.ModuleName -RawPath $mod.FileName
                    Add-HighFinding -Area "DLL em Processo" -Item $modName -Path $mod.FileName `
                        -Details "Alvo: $($tp.ProcessName) (PID=$($tp.Id))" `
                        -IsRunning $true -SignatureStatus $sigMod -HashShort $hashMod
                }
            }
        } catch {}
    }
} catch {}

# ==============================================================================
# ETAPA 2: FICHEIROS, SCRIPTS, ARQUIVOS E LIXEIRA
# ==============================================================================
Queue-UI -Percent 28 -Text "A analisar ficheiros, scripts e Lixeira..."
$seenFiles = @{}
$extRegex = '(?i)^\.(exe|dll|sys|bat|cmd|ps1|vbs|ahk|rar|zip|7z|iso|msi|scr|com|pif|py|lua|cfg|json)$'

function Scan-DirWorker {
    param([string]$DirPath, [int]$Depth = 0, [int]$MaxDepth = 6)
    if ($Depth -gt $MaxDepth) { return }
    if (-not $DirPath -or ($DirPath -match $excludedPathPattern)) { return }

    $script:fileCounter++
    if (($script:fileCounter % 350) -eq 0) {
        $stepPct = [Math]::Min(62, 28 + [int](($script:fileCounter / 3500.0) * 34))
        Queue-UI -Percent $stepPct -Text "A analisar ficheiros, scripts e Lixeira..."
    }

    try {
        $files = [System.IO.Directory]::GetFiles($DirPath)
        foreach ($path in $files) {
            if ($path -match $excludedPathPattern) { continue }
            $ext = [System.IO.Path]::GetExtension($path)
            if ($ext -notmatch $extRegex) { continue }

            $name = [System.IO.Path]::GetFileName($path)
            if ($name -notmatch $strongPattern -and $name -notmatch $mediumPattern -and $path -notmatch $strongPattern) { continue }

            $key = $path.ToLowerInvariant()
            if ($seenFiles.ContainsKey($key)) { continue }
            $seenFiles[$key] = $true

            $areaName = if ($path -match '\$Recycle\.Bin') { "Lixeira" } else { "Ficheiro" }
            $isRunning = $runningPaths.ContainsKey($key)
            $sigStatus = if ($ext -match '(?i)^\.(exe|dll|sys|scr|com|pif)$') { Get-SignatureStatusFast -Path $path } else { "N/A" }
            $hashShort = if ($ext -match '(?i)^\.(exe|dll|sys|bat|cmd|ps1|vbs|ahk)$') { Get-FileSha256Short -Path $path } else { "N/A" }

            $lenKb = 0
            $lastWrite = ""
            $isHidden = $false
            try {
                $fi = New-Object System.IO.FileInfo($path)
                $lenKb = [Math]::Round($fi.Length / 1KB, 1)
                $lastWrite = $fi.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                $isHidden = (($fi.Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0)
            } catch {}

            Add-HighFinding -Area $areaName -Item $name -Path $path `
                -Details "Tamanho=${lenKb}KB; Modificado=$lastWrite" `
                -IsRunning $isRunning -SignatureStatus $sigStatus `
                -HasHiddenOrTempTraits $isHidden -HashShort $hashShort
        }
    } catch {}

    try {
        $subDirs = [System.IO.Directory]::GetDirectories($DirPath)
        foreach ($sub in $subDirs) {
            if ($sub -match $excludedPathPattern) { continue }
            Scan-DirWorker -DirPath $sub -Depth ($Depth + 1) -MaxDepth $MaxDepth
        }
    } catch {}
}

$allTargets = @($scanRoots)
if (Test-Path 'C:\$Recycle.Bin') { $allTargets += 'C:\$Recycle.Bin' }

foreach ($root in $allTargets) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $md = if ($root -eq 'C:\') { 2 } else { 6 }
    Scan-DirWorker -DirPath $root -Depth 0 -MaxDepth $md
}

# ==============================================================================
# ETAPA 3: PREFETCH, STARTUP & TAREFAS AGENDADAS
# ==============================================================================
Queue-UI -Percent 66 -Text "A analisar histórico de execução (Prefetch & Startup)..."
$pf = "$env:SystemRoot\Prefetch"
if (Test-Path -LiteralPath $pf) {
    try {
        Get-ChildItem -LiteralPath $pf -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match $strongPattern -or $_.Name -match $mediumPattern } |
            ForEach-Object {
                $cleanName = $_.Name -replace '-[A-F0-9]{8}\.pf$', ''
                Add-HighFinding -Area "Prefetch" -Item $cleanName -Path $_.FullName `
                    -Details "Última execução=$($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))" `
                    -IsPrefetch $true
            }
    } catch {}
}

$startupDirs = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
)
foreach ($sd in $startupDirs) {
    if (-not (Test-Path -LiteralPath $sd)) { continue }
    try {
        Get-ChildItem -LiteralPath $sd -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match $strongPattern -or $_.Name -match $mediumPattern } |
            ForEach-Object {
                Add-HighFinding -Area "Startup" -Item $_.Name -Path $_.FullName `
                    -Details "Arranque automático detetado" -IsPrefetch $true
            }
    } catch {}
}

# ==============================================================================
# ETAPA 4: REGISTO (BAM, MuiCache, Run/RunOnce, UserAssist/TypedPaths)
# ==============================================================================
Queue-UI -Percent 80 -Text "A verificar rastos no Registo (BAM / Cache / Run)..."
$regPaths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings\*",
    "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths"
)
foreach ($rp in $regPaths) {
    try {
        Get-Item -Path $rp -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($valName in $_.GetValueNames()) {
                $valData = ""
                try { $valData = [string]$_.GetValue($valName) } catch {}
                $combinedReg = "$valName $valData"
                if ($combinedReg -match $strongPattern -or $combinedReg -match $mediumPattern) {
                    $candidatePath = if ($valData -match '[A-Za-z]:\\|\device\\harddiskvolume') { $valData } else { $valName }
                    $exeName = [System.IO.Path]::GetFileName($candidatePath)
                    if ([string]::IsNullOrWhiteSpace($exeName)) { $exeName = $valName }
                    Add-HighFinding -Area "Registo" -Item $exeName -Path $candidatePath `
                        -Details "Chave=$($_.PSChildName); Valor=$valName" `
                        -IsPrefetch $true
                }
            }
        }
    } catch {}
}

# ==============================================================================
# ETAPA 5: CONSOLIDAÇÃO & ENVIO DO RELATÓRIO
# ==============================================================================
Queue-UI -Percent 92 -Text "A consolidar relatório forense..."
$rawList = @($script:Findings.ToArray())
$final = $rawList |
    Group-Object { "$($_.Nome.ToLowerInvariant())|$($_.Caminho.ToLowerInvariant())" } |
    ForEach-Object {
        $best = $_.Group | Sort-Object Score -Descending | Select-Object -First 1
        $areas = ($_.Group.Area | Where-Object { $_ } | Select-Object -Unique) -join " + "
        $evid = ($_.Group.Evidencias | Where-Object { $_ } | Select-Object -Unique) -join "; "
        $det = ($_.Group.Detalhes | Where-Object { $_ } | Select-Object -Unique | Select-Object -First 2) -join " | "
        [pscustomobject]@{
            Score      = $best.Score
            Nivel      = $best.Nivel
            Nome       = $best.Nome
            Area       = $areas
            Caminho    = $best.Caminho
            SHA256     = $best.SHA256
            Assinatura = $best.Assinatura
            Evidencias = $evid
            Detalhes   = $det
        }
    } |
    Sort-Object Score -Descending |
    Select-Object -First $script:MaxResults

Queue-UI -Percent 97 -Text "A enviar relatório detalhado..."
Send-ReportToWebhook -FinalFindings @($final)

Queue-UI -Percent 100 -Text "Análise concluída" -SubText "Verificação concluída — relatório enviado"
'@

$script:PsInstance.AddScript($workerFullScript) | Out-Null
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
