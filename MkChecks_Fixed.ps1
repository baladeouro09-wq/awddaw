# ==============================================================================
# MkChecks - Compact Card Scanner (Preto & Roxo)
# Apenas leitura. Não apaga ficheiros, não altera registo nem desativa segurança.
# ==============================================================================

$script:WebhookUrl = "https://discord.com/api/webhooks/1574173816098259054/P0wRGzaR-zlpIOvH6wqGy6z-nGU4fUFFR-d5sFfi26TGGoRL81Gz-2bS2L-U9wqkx-O6"
$script:AutoRunAndSend = $true

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try { [System.Windows.Forms.Application]::EnableVisualStyles() } catch {}

$script:Findings = New-Object System.Collections.Generic.List[object]
$script:Threshold = 65
$script:MaxResults = 40

$strongPattern = '(?i)(fivem[-_ ]?external|aimbot|wallhack|wall[-_ ]?hack|spoofer|hwid[-_ ]?spoof|cheat|mod[-_ ]?menu|triggerbot|silent[-_ ]?aim|ragebot|redengine|eulen|skript\.gg|lynx|lumia|tz[-_ ]?project|hx[-_ ]?cheats|desudo|brutan|kekhack|interwebz|neverlose|onetap|gamesense|skeet|fatality|aimware|iniuria|vape[-_ ]?v4|lunar[-_ ]?client[-_ ]?crack|wurst|meteor[-_ ]?client|aristois|xenos|extreme[-_ ]?injector|process[-_ ]?hacker|kdmapper|drvmap|gdrv|capcom\.sys|iqvw64e\.sys|dsefix|winring0|anticheat[-_ ]?bypass|ac[-_ ]?bypass|cleaner[-_ ]?fivem|unban[-_ ]?fivem)'
$mediumPattern = '(?i)(injector|manual[-_ ]?map|reflective[-_ ]?dll|hollowing|syscall|spoof|bypass|dumper|offset[-_ ]?finder|memory[-_ ]?edit|cheat[-_ ]?engine|artmoney|wemod|autoclicker|recoil[-_ ]?script|no[-_ ]?recoil|macro[-_ ]?pro|ahk[-_ ]?script)'

$excludedPathPattern = '(?i)\\(Medal|Discord|Microsoft|Windows|NVIDIA|AMD|Intel|Steam|Epic Games|Riot Games|Battle\.net|Ubisoft|Electronic Arts|Overwolf|OBS|Streamlabs|Logitech|Razer|Corsair|SteelSeries|FiveM\\FiveM\.app\\plugins\\reshade)(\\|$)'

$scanRoots = @(
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Documents",
    "$env:APPDATA",
    "$env:LOCALAPPDATA",
    "$env:TEMP",
    "$env:ProgramData",
    "C:\Users\Public"
) | Select-Object -Unique

function Pump-UI {
    try { [System.Windows.Forms.Application]::DoEvents() } catch {}
}

function Set-ProgressUI {
    param([int]$Percent, [string]$Text)
    try {
        $p = [Math]::Max(0, [Math]::Min(100, $Percent))
        $lblStatus.Text = "$Text ($p%)"
        $lblPct.Text = "$p%"
        $fillWidth = [int](($barBg.Width - 4) * ($p / 100.0))
        $barFill.Width = [Math]::Max(0, $fillWidth)
        Pump-UI
    } catch {}
}

function Get-Suspicion {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Area = "",
        [bool]$IsRunning = $false,
        [bool]$IsPrefetch = $false,
        [string]$SignatureStatus = ""
    )

    $score = 0
    $reasons = New-Object System.Collections.Generic.List[string]
    $combined = "$Name $Path"

    if ($combined -match $strongPattern) {
        $score += 70
        $reasons.Add("assinatura/nome de cheat ou spoofer conhecido")
    } elseif ($combined -match $mediumPattern) {
        $score += 35
        $reasons.Add("ferramenta de injeção, bypass ou manipulação de memória")
    } else {
        return $null
    }

    if ($Path -match '(?i)\\AppData\\|\\Temp\\|\\ProgramData\\|\\Downloads\\|\\Recycle\.Bin\\') {
        $score += 15
        $reasons.Add("diretório temporário, downloads ou reciclagem")
    }

    if ($IsRunning) {
        $score += 25
        $reasons.Add("em execução ativa durante a análise")
    }

    if ($IsPrefetch -or $Area -match 'Prefetch|Registo BAM') {
        $score += 15
        $reasons.Add("rasto de execução recente no sistema")
    }

    if ($Path -match '(?i)\.(exe|dll|sys|bat|cmd|ps1|vbs|ahk)$') {
        $score += 5
        $reasons.Add("executável/driver/script")
    }

    if ($SignatureStatus -eq "NotSigned" -or $SignatureStatus -eq "HashMismatch") {
        $score += 15
        $reasons.Add("sem assinatura digital válida")
    } elseif ($SignatureStatus -eq "Valid") {
        $score -= 25
        $reasons.Add("assinatura digital válida")
    }

    return [pscustomobject]@{
        Score   = [Math]::Max(0, [Math]::Min(100, $score))
        Reasons = ($reasons -join "; ")
    }
}

function Get-SignatureStatus {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "N/A" }
    try {
        $sig = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
        return [string]$sig.Status
    } catch {
        return "Desconhecido"
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
        [string]$SignatureStatus = ""
    )

    if ($Path -and $Path -match $excludedPathPattern) { return }

    $s = Get-Suspicion -Name $Item -Path $Path -Area $Area -IsRunning $IsRunning -IsPrefetch $IsPrefetch -SignatureStatus $SignatureStatus
    if ($null -eq $s -or $s.Score -lt $script:Threshold) { return }

    $nivel = if ($s.Score -ge 90) { "CRÍTICO" } elseif ($s.Score -ge 75) { "ALTO" } else { "SUSPEITO" }

    $script:Findings.Add([pscustomobject]@{
        Score      = $s.Score
        Nivel      = $nivel
        Area       = $Area
        Nome       = $Item
        Caminho    = $Path
        Assinatura = if ($SignatureStatus) { $SignatureStatus } else { "N/A" }
        Evidencias = $s.Reasons
        Detalhes   = $Details
    }) | Out-Null
}

function Send-ReportToWebhook {
    if ([string]::IsNullOrWhiteSpace($script:WebhookUrl) -or $script:WebhookUrl -eq "COLA_AQUI_O_TEU_WEBHOOK_URL") {
        return
    }

    try {
        $pcName = $env:COMPUTERNAME
        $userName = $env:USERNAME
        $osInfo = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
        if (-not $osInfo) { $osInfo = "Windows" }
        $dateStr = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

        $critCount = ($script:Findings | Where-Object { $_.Nivel -eq "CRÍTICO" }).Count
        $highCount = ($script:Findings | Where-Object { $_.Nivel -eq "ALTO" }).Count
        $totalCount = $script:Findings.Count

        $color = if ($critCount -gt 0) { 10181046 } elseif ($totalCount -gt 0) { 12320255 } else { 7419530 }

        $topSummary = ""
        if ($totalCount -eq 0) {
            $topSummary = "Nenhum indicador crítico detetado acima do limiar ($script:Threshold/100)."
        } else {
            $topItems = $script:Findings | Select-Object -First 12
            foreach ($f in $topItems) {
                $topSummary += "• **[$($f.Nivel) - $($f.Score)%]** ``$($f.Nome)`` ($($f.Area))`n"
            }
            if ($totalCount -gt 12) {
                $topSummary += "`n*...e mais $($totalCount - 12) achados no ficheiro CSV em anexo.*"
            }
        }

        $tempCsv = Join-Path $env:TEMP "MkChecks_${pcName}_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
        if ($totalCount -gt 0) {
            $script:Findings | Export-Csv -LiteralPath $tempCsv -NoTypeInformation -Encoding UTF8
        } else {
            "Nenhum achado critico encontrado em $pcName ($userName) em $dateStr" | Out-File -LiteralPath $tempCsv -Encoding UTF8
        }

        $payloadObj = @{
            username = "MkChecks"
            embeds   = @(
                @{
                    title       = "Relatório MkChecks — $pcName"
                    description = "**Utilizador:** ``$userName```n**Sistema:** $osInfo`n**Data:** $dateStr`n**Resumo:** $totalCount achados prioritários ($critCount Críticos | $highCount Altos)`n`n**Principais Deteções:**`n$topSummary"
                    color       = $color
                    footer      = @{ text = "MkChecks • Top $script:MaxResults resultados" }
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

function Scan-DirectorySafe {
    param([string]$DirPath, [int]$Depth = 0)
    if ($Depth -gt 6) { return }
    if (-not $DirPath -or ($DirPath -match $excludedPathPattern)) { return }

    $script:FileCounter++
    if (($script:FileCounter % 150) -eq 0) {
        $stepPct = [Math]::Min(64, 30 + [int](($script:FileCounter / 2500.0) * 34))
        Set-ProgressUI -Percent $stepPct -Text "A analisar ficheiros, scripts e Lixeira..."
    }

    try {
        $files = [System.IO.Directory]::GetFiles($DirPath)
        foreach ($path in $files) {
            if ($path -match $excludedPathPattern) { continue }
            $ext = [System.IO.Path]::GetExtension($path)
            if ($ext -notmatch $script:ExtRegex) { continue }

            $name = [System.IO.Path]::GetFileName($path)
            if ($name -notmatch $strongPattern -and $name -notmatch $mediumPattern) { continue }

            $key = $path.ToLowerInvariant()
            if ($script:SeenFiles.ContainsKey($key)) { continue }
            $script:SeenFiles[$key] = $true

            $areaName = if ($path -match '\$Recycle\.Bin') { "Lixeira (Apagado)" } else { "Ficheiro" }
            $isRunning = $script:RunningPaths.ContainsKey($key)
            $sigStatus = if ($ext -match '(?i)^\.(exe|dll|sys)$') { Get-SignatureStatus -Path $path } else { "N/A" }

            $lenKb = 0
            $lastWrite = ""
            try {
                $fi = New-Object System.IO.FileInfo($path)
                $lenKb = [Math]::Round($fi.Length / 1KB, 1)
                $lastWrite = $fi.LastWriteTime
            } catch {}

            Add-HighFinding -Area $areaName -Item $name -Path $path `
                -Details "Tamanho=$lenKb KB; Modificado=$lastWrite" `
                -IsRunning $isRunning -SignatureStatus $sigStatus
        }
    } catch {}

    try {
        $subDirs = [System.IO.Directory]::GetDirectories($DirPath)
        foreach ($sub in $subDirs) {
            if ($sub -match $excludedPathPattern) { continue }
            Scan-DirectorySafe -DirPath $sub -Depth ($Depth + 1)
        }
    } catch {}
}

function Run-Scan {
    try {
        $script:Findings.Clear()
        Set-ProgressUI -Percent 10 -Text "A verificar processos ativos e DLLs..."

        $script:RunningPaths = @{}
        try {
            $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
            foreach ($p in $procs) {
                if ($p.ExecutablePath) {
                    $script:RunningPaths[$p.ExecutablePath.ToLowerInvariant()] = $true
                    $sigStatus = Get-SignatureStatus -Path $p.ExecutablePath
                    Add-HighFinding -Area "Processo Ativo" -Item $p.Name -Path $p.ExecutablePath `
                        -Details "PID=$($p.ProcessId); Cmd=$($p.CommandLine)" `
                        -IsRunning $true -SignatureStatus $sigStatus
                }
                if ($p.CommandLine -and ($p.CommandLine -match $strongPattern -or $p.CommandLine -match $mediumPattern)) {
                    Add-HighFinding -Area "Linha de Comando" -Item $p.Name -Path $p.ExecutablePath `
                        -Details "PID=$($p.ProcessId); Cmd=$($p.CommandLine)" `
                        -IsRunning $true -SignatureStatus (Get-SignatureStatus -Path $p.ExecutablePath)
                }
            }
            Set-ProgressUI -Percent 22 -Text "A inspecionar módulos de processos..."

            $targetProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
                $_.ProcessName -match '(?i)(fivem|gta|five|cs2|valorant|r5apex|fortnite|minecraft|javaw|roblox|rust|overwolf|discord|cmd|powershell|pwsh)'
            }
            foreach ($tp in $targetProcs) {
                Pump-UI
                try {
                    foreach ($mod in $tp.Modules) {
                        if ($mod.ModuleName -match $strongPattern -or $mod.FileName -match $strongPattern) {
                            $sigMod = Get-SignatureStatus -Path $mod.FileName
                            Add-HighFinding -Area "DLL em Processo" -Item $mod.ModuleName -Path $mod.FileName `
                                -Details "Processo: $($tp.ProcessName) (PID=$($tp.Id))" `
                                -IsRunning $true -SignatureStatus $sigMod
                        }
                    }
                } catch {}
            }
        } catch {}

        Set-ProgressUI -Percent 30 -Text "A analisar ficheiros, scripts e Lixeira..."
        $script:SeenFiles = @{}
        $script:ExtRegex = '(?i)^\.(exe|dll|sys|bat|cmd|ps1|vbs|ahk|rar|zip)$'
        $script:FileCounter = 0

        $allTargets = @($scanRoots)
        if (Test-Path 'C:\$Recycle.Bin') { $allTargets += 'C:\$Recycle.Bin' }

        foreach ($root in $allTargets) {
            if (-not (Test-Path -LiteralPath $root)) { continue }
            Pump-UI
            Scan-DirectorySafe -DirPath $root -Depth 0
        }

        Set-ProgressUI -Percent 68 -Text "A analisar histórico de execução (Prefetch)..."
        $pf = "$env:SystemRoot\Prefetch"
        if (Test-Path -LiteralPath $pf) {
            try {
                Get-ChildItem -LiteralPath $pf -File -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match $strongPattern -or $_.Name -match $mediumPattern } |
                    ForEach-Object {
                        $cleanName = $_.Name -replace '-[A-F0-9]{8}\.pf$', ''
                        Add-HighFinding -Area "Prefetch" -Item $cleanName -Path $_.FullName `
                            -Details "Executado recentemente; Última execução=$($_.LastWriteTime)" `
                            -IsPrefetch $true
                    }
            } catch {}
        }

        Set-ProgressUI -Percent 82 -Text "A verificar rastos no Registo (BAM / MuiCache)..."
        $regPaths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings\*",
            "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
        )
        foreach ($rp in $regPaths) {
            try {
                Get-Item -Path $rp -ErrorAction SilentlyContinue | ForEach-Object {
                    foreach ($valName in $_.GetValueNames()) {
                        if ($valName -match $strongPattern -or $valName -match $mediumPattern) {
                            $exeName = [System.IO.Path]::GetFileName($valName)
                            if (-not $exeName) { $exeName = $valName }
                            Add-HighFinding -Area "Registo BAM/Cache" -Item $exeName -Path $valName `
                                -Details "Vestígio de execução registado no Windows" `
                                -IsPrefetch $true
                        }
                    }
                }
            } catch {}
        }

        Set-ProgressUI -Percent 92 -Text "A consolidar relatório prioritário..."
        $final = $script:Findings |
            Group-Object { $_.Nome.ToLowerInvariant() } |
            ForEach-Object {
                $best = $_.Group | Sort-Object Score -Descending | Select-Object -First 1
                $areas = ($_.Group.Area | Select-Object -Unique) -join " + "
                $best.Area = $areas
                $best.Detalhes = ($_.Group.Detalhes | Select-Object -Unique | Select-Object -First 2) -join " | "
                $best
            } |
            Sort-Object Score -Descending |
            Select-Object -First $script:MaxResults

        $script:Findings.Clear()
        foreach ($item in $final) { $script:Findings.Add($item) | Out-Null }

        Set-ProgressUI -Percent 97 -Text "A enviar relatório para o teu PC..."
        Send-ReportToWebhook

        Set-ProgressUI -Percent 100 -Text "Análise concluída"
        $lblSub.Text = "Verificação concluída — relatório enviado"
    } catch {
        $lblStatus.Text = "Erro na verificação"
        $lblSub.Text = "Ocorreu um erro inesperado"
    }
}

# ==============================================================================
# DESENHO DO LOGO "MkChecks" EM PRETO & ROXO (SEM DEPENDÊNCIA DE FICHEIRO EXTERNO)
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

$form.Add_Shown({
    Pump-UI
    if ($script:AutoRunAndSend) {
        Run-Scan
    }
})

[void]$form.ShowDialog()
