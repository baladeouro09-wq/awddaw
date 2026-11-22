# ==============================================================================
# MkChecks - Windows Forensics & Anti-Cheat Scanner
# Apenas leitura. Não apaga ficheiros, não altera registo nem desativa segurança.
# ==============================================================================

# 1. CONFIGURAÇÃO DE ENVIO REMOTO (Cola aqui o teu Webhook do Discord)
$script:WebhookUrl = "https://discord.com/api/webhooks/1574173816098259054/P0wRGzaR-zlpIOvH6wqGy6z-nGU4fUFFR-d5sFfi26TGGoRL81Gz-2bS2L-U9wqkx-O6"
$script:AutoRunAndSend = $true  # Se $true, inicia o scan automaticamente ao abrir via link e envia para ti

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Findings = New-Object System.Collections.Generic.List[object]
$script:Threshold = 65
$script:MaxResults = 40 # Limita o relatório aos 40 achados mais críticos para evitar spam

# Padrões de deteção alargados (FiveM, GTA, CS2, Valorant, Rust, Roblox, Minecraft, Spoofers, Cleaners)
$strongPattern = '(?i)(fivem[-_ ]?external|aimbot|wallhack|wall[-_ ]?hack|spoofer|hwid[-_ ]?spoof|cheat|mod[-_ ]?menu|triggerbot|silent[-_ ]?aim|ragebot|redengine|eulen|skript\.gg|lynx|lumia|tz[-_ ]?project|hx[-_ ]?cheats|desudo|brutan|kekhack|interwebz|neverlose|onetap|gamesense|skeet|fatality|aimware|iniuria|vape[-_ ]?v4|lunar[-_ ]?client[-_ ]?crack|wurst|meteor[-_ ]?client|aristois|xenos|extreme[-_ ]?injector|process[-_ ]?hacker|kdmapper|drvmap|gdrv|capcom\.sys|iqvw64e\.sys|dsefix|winring0|anticheat[-_ ]?bypass|ac[-_ ]?bypass|cleaner[-_ ]?fivem|unban[-_ ]?fivem)'
$mediumPattern = '(?i)(injector|manual[-_ ]?map|reflective[-_ ]?dll|hollowing|syscall|spoof|bypass|dumper|offset[-_ ]?finder|memory[-_ ]?edit|cheat[-_ ]?engine|artmoney|wemod|autoclicker|recoil[-_ ]?script|no[-_ ]?recoil|macro[-_ ]?pro|ahk[-_ ]?script)'

# Exclusões rigorosas para evitar falsos positivos do sistema e programas legítimos
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
    param([string]$StatusLabelText)

    if ([string]::IsNullOrWhiteSpace($script:WebhookUrl) -or $script:WebhookUrl -eq "COLA_AQUI_O_TEU_WEBHOOK_URL") {
        return
    }

    try {
        $pcName = $env:COMPUTERNAME
        $userName = $env:USERNAME
        $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption
        $dateStr = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

        $critCount = ($script:Findings | Where-Object { $_.Nivel -eq "CRÍTICO" }).Count
        $highCount = ($script:Findings | Where-Object { $_.Nivel -eq "ALTO" }).Count
        $totalCount = $script:Findings.Count

        $color = if ($critCount -gt 0) { 15548997 } elseif ($totalCount -gt 0) { 16753920 } else { 5763719 }

        $topSummary = ""
        if ($totalCount -eq 0) {
            $topSummary = "✅ Nenhum indicador crítico detetado acima do limiar ($script:Threshold/100)."
        } else {
            $topItems = $script:Findings | Select-Object -First 12
            foreach ($f in $topItems) {
                $topSummary += "• **[$($f.Nivel) - $($f.Score)%]** ``$($f.Nome)`` ($($f.Area))`n"
            }
            if ($totalCount -gt 12) {
                $topSummary += "`n*...e mais $($totalCount - 12) achados no ficheiro CSV em anexo.*"
            }
        }

        # Enviar Embed + Ficheiro CSV em memória (sem deixar rastros no PC analisado)
        $tempCsv = Join-Path $env:TEMP "MkChecks_${pcName}_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
        if ($totalCount -gt 0) {
            $script:Findings | Export-Csv -LiteralPath $tempCsv -NoTypeInformation -Encoding UTF8
        } else {
            "Nenhum achado critico encontrado em $pcName ($userName) em $dateStr" | Out-File -LiteralPath $tempCsv -Encoding UTF8
        }

        $payloadObj = @{
            username = "MkChecks Forensics"
            embeds   = @(
                @{
                    title       = "🛡️ Relatório MkChecks — $pcName"
                    description = "**Utilizador:** ``$userName```n**Sistema:** $osInfo`n**Data:** $dateStr`n**Resumo:** $totalCount achados prioritários ($critCount Críticos | $highCount Altos)`n`n**Principais Deteções:**`n$topSummary"
                    color       = $color
                    footer      = @{ text = "MkChecks Remote Forensics • Máx. Top $script:MaxResults resultados" }
                }
            )
        }
        $jsonPayload = $payloadObj | ConvertTo-Json -Depth 6 -Compress

        # Envio via HttpClient para suportar ficheiro + JSON
        Add-Type -AssemblyName System.Net.Http
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
        $lblStatus.Text = "Concluído e enviado! ($totalCount achados prioritários)"
    } catch {
        $lblStatus.Text = "Concluído (erro ao enviar relatório remoto)."
    }
}

function Pump-UI {
    try { [System.Windows.Forms.Application]::DoEvents() } catch {}
}

function Run-Scan {
    $btnScan.Enabled = $false
    $btnExport.Enabled = $false
    $script:Findings.Clear()
    $grid.Rows.Clear()
    $lblCountCrit.Text = "0"
    $lblCountHigh.Text = "0"
    $lblCountTotal.Text = "0"

    # 1. Processos e Módulos (DLLs) em execução
    $progress.Value = 15
    $lblStatus.Text = "1/5 A verificar processos ativos e DLLs..."
    Pump-UI

    $runningPaths = @{}
    try {
        $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
        foreach ($p in $procs) {
            if ($p.ExecutablePath) {
                $runningPaths[$p.ExecutablePath.ToLowerInvariant()] = $true
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
        Pump-UI

        # Verificar módulos apenas em processos de jogos/utilizadores não-sistema para não bloquear a UI
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

    # 2. Ficheiros em pastas críticas e Lixeira (enumeração rápida com DoEvents)
    $progress.Value = 40
    $lblStatus.Text = "2/5 A analisar ficheiros, scripts e Lixeira..."
    Pump-UI

    $seen = @{}
    $allTargets = @($scanRoots)
    if (Test-Path 'C:\$Recycle.Bin') { $allTargets += 'C:\$Recycle.Bin' }

    $extRegex = '(?i)^\.(exe|dll|sys|bat|cmd|ps1|vbs|ahk|rar|zip)$'
    $fileCounter = 0

    foreach ($root in $allTargets) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Pump-UI
        try {
            $enum = [System.IO.Directory]::EnumerateFiles($root, "*", [System.IO.SearchOption]::AllDirectories)
            foreach ($path in $enum) {
                $fileCounter++
                if (($fileCounter % 250) -eq 0) { Pump-UI }

                if ($path -match $excludedPathPattern) { continue }
                $ext = [System.IO.Path]::GetExtension($path)
                if ($ext -notmatch $extRegex) { continue }

                $name = [System.IO.Path]::GetFileName($path)
                if ($name -notmatch $strongPattern -and $name -notmatch $mediumPattern) { continue }

                $key = $path.ToLowerInvariant()
                if ($seen.ContainsKey($key)) { continue }
                $seen[$key] = $true

                $areaName = if ($path -match '\$Recycle\.Bin') { "Lixeira (Apagado)" } else { "Ficheiro" }
                $isRunning = $runningPaths.ContainsKey($key)
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
    }

    # 3. Prefetch (Histórico de execução do Windows)
    $progress.Value = 65
    $lblStatus.Text = "3/5 A analisar histórico de execução (Prefetch)..."
    Pump-UI

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

    # 4. Registo do Windows (BAM / AppCompatCache / MuiCache - Execuções passadas mesmo após apagar)
    $progress.Value = 85
    $lblStatus.Text = "4/5 A verificar rastos no Registo (BAM / MuiCache)..."
    Pump-UI

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

    # 5. Consolidação, Filtragem e Ordenação (Top 40 mais críticos)
    $progress.Value = 95
    $lblStatus.Text = "5/5 A filtrar e consolidar resultados prioritários..."
    Pump-UI

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
    foreach ($item in $final) {
        $script:Findings.Add($item) | Out-Null
        $rowIdx = $grid.Rows.Add($item.Score, $item.Nivel, $item.Area, $item.Nome, $item.Caminho, $item.Evidencias)
        if ($item.Nivel -eq "CRÍTICO") {
            $grid.Rows[$rowIdx].Cells[1].Style.ForeColor = [System.Drawing.Color]::FromArgb(248, 113, 113)
            $grid.Rows[$rowIdx].Cells[1].Style.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        } elseif ($item.Nivel -eq "ALTO") {
            $grid.Rows[$rowIdx].Cells[1].Style.ForeColor = [System.Drawing.Color]::FromArgb(251, 191, 36)
        }
    }

    $critTotal = ($script:Findings | Where-Object { $_.Nivel -eq "CRÍTICO" }).Count
    $highTotal = ($script:Findings | Where-Object { $_.Nivel -eq "ALTO" }).Count

    $lblCountCrit.Text = "$critTotal"
    $lblCountHigh.Text = "$highTotal"
    $lblCountTotal.Text = "$($script:Findings.Count)"

    $progress.Value = 100
    $lblStatus.Text = "Análise concluída: $($script:Findings.Count) achados prioritários."
    $btnScan.Enabled = $true
    $btnExport.Enabled = ($script:Findings.Count -gt 0)

    # Envia automaticamente para o teu Discord se configurado
    Send-ReportToWebhook
}

# ==============================================================================
# INTERFACE GRÁFICA MODERNA (DARK MODE - MkChecks)
# ==============================================================================
$bgDark      = [System.Drawing.Color]::FromArgb(18, 20, 26)
$bgCard      = [System.Drawing.Color]::FromArgb(28, 31, 40)
$bgGridAlt   = [System.Drawing.Color]::FromArgb(23, 26, 34)
$accentColor = [System.Drawing.Color]::FromArgb(59, 130, 246)
$textMain    = [System.Drawing.Color]::FromArgb(243, 244, 246)
$textMuted   = [System.Drawing.Color]::FromArgb(156, 163, 175)
$borderColor = [System.Drawing.Color]::FromArgb(45, 50, 65)

$form = New-Object System.Windows.Forms.Form
$form.Text = "MkChecks — Forensics & Anti-Cheat Scanner"
$form.Size = New-Object System.Drawing.Size(1240, 760)
$form.StartPosition = "CenterScreen"
$form.BackColor = $bgDark
$form.ForeColor = $textMain
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

# Cabeçalho
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(1240, 75)
$headerPanel.BackColor = $bgCard
$form.Controls.Add($headerPanel)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "MkChecks"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $accentColor
$lblTitle.Location = New-Object System.Drawing.Point(24, 14)
$lblTitle.AutoSize = $true
$headerPanel.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "PC Forensics & Cheat Detection • Triagem Inteligente (Top $script:MaxResults Críticos | Limiar >= $script:Threshold%)"
$lblSub.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblSub.ForeColor = $textMuted
$lblSub.Location = New-Object System.Drawing.Point(26, 47)
$lblSub.AutoSize = $true
$headerPanel.Controls.Add($lblSub)

# Cartões de Estatísticas (KPIs)
function New-StatCard {
    param([int]$X, [string]$Title, [System.Drawing.Color]$ValColor)
    $card = New-Object System.Windows.Forms.Panel
    $card.Location = New-Object System.Drawing.Point($X, 92)
    $card.Size = New-Object System.Drawing.Size(190, 72)
    $card.BackColor = $bgCard

    $lblT = New-Object System.Windows.Forms.Label
    $lblT.Text = $Title
    $lblT.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $lblT.ForeColor = $textMuted
    $lblT.Location = New-Object System.Drawing.Point(14, 10)
    $lblT.AutoSize = $true
    $card.Controls.Add($lblT)

    $lblV = New-Object System.Windows.Forms.Label
    $lblV.Text = "0"
    $lblV.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $lblV.ForeColor = $ValColor
    $lblV.Location = New-Object System.Drawing.Point(14, 30)
    $lblV.AutoSize = $true
    $card.Controls.Add($lblV)

    $form.Controls.Add($card)
    return $lblV
}

$lblCountCrit  = New-StatCard -X 24  -Title "AMEAÇAS CRÍTICAS (>=90%)" -ValColor ([System.Drawing.Color]::FromArgb(248, 113, 113))
$lblCountHigh  = New-StatCard -X 228 -Title "RISCO ELEVADO (75-89%)"   -ValColor ([System.Drawing.Color]::FromArgb(251, 191, 36))
$lblCountTotal = New-StatCard -X 432 -Title "TOTAL FILTRADO"           -ValColor $accentColor

# Botões e Barra de Progresso
$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "▶ Iniciar Análise"
$btnScan.Location = New-Object System.Drawing.Point(650, 92)
$btnScan.Size = New-Object System.Drawing.Size(165, 42)
$btnScan.BackColor = $accentColor
$btnScan.ForeColor = [System.Drawing.Color]::White
$btnScan.FlatStyle = "Flat"
$btnScan.FlatAppearance.BorderSize = 0
$btnScan.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnScan.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnScan)

$btnExport = New-Object System.Windows.Forms.Button
$btnExport.Text = "💾 Exportar CSV"
$btnExport.Location = New-Object System.Drawing.Point(825, 92)
$btnExport.Size = New-Object System.Drawing.Size(145, 42)
$btnExport.BackColor = $bgCard
$btnExport.ForeColor = $textMain
$btnExport.FlatStyle = "Flat"
$btnExport.FlatAppearance.BorderColor = $borderColor
$btnExport.Enabled = $false
$btnExport.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnExport)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(650, 144)
$progress.Size = New-Object System.Drawing.Size(320, 8)
$progress.Style = "Continuous"
$form.Controls.Add($progress)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Pronto para iniciar."
$lblStatus.Location = New-Object System.Drawing.Point(650, 155)
$lblStatus.Size = New-Object System.Drawing.Size(550, 20)
$lblStatus.ForeColor = $textMuted
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$form.Controls.Add($lblStatus)

# Tabela de Resultados (DataGridView Estilizada)
$grid = New-Object System.Windows.Forms.DataGridView
$grid.Location = New-Object System.Drawing.Point(24, 185)
$grid.Size = New-Object System.Drawing.Size(1176, 515)
$grid.BackgroundColor = $bgCard
$grid.BorderStyle = "None"
$grid.CellBorderStyle = "SingleHorizontal"
$grid.GridColor = $borderColor
$grid.EnableHeadersVisualStyles = $false
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.RowHeadersVisible = $false
$grid.SelectionMode = "FullRowSelect"
$grid.AutoSizeColumnsMode = "Fill"
$grid.RowTemplate.Height = 32

$grid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(35, 39, 50)
$grid.ColumnHeadersDefaultCellStyle.ForeColor = $textMain
$grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$grid.ColumnHeadersHeight = 36

$grid.DefaultCellStyle.BackColor = $bgCard
$grid.DefaultCellStyle.ForeColor = $textMain
$grid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(45, 65, 105)
$grid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
$grid.AlternatingRowsDefaultCellStyle.BackColor = $bgGridAlt

$null = $grid.Columns.Add("Score", "Score %")
$null = $grid.Columns.Add("Nivel", "Risco")
$null = $grid.Columns.Add("Area", "Origem / Vestígio")
$null = $grid.Columns.Add("Nome", "Ficheiro / Processo")
$null = $grid.Columns.Add("Caminho", "Localização")
$null = $grid.Columns.Add("Evidencias", "Motivo da Deteção")

$grid.Columns[0].FillWeight = 8
$grid.Columns[1].FillWeight = 10
$grid.Columns[2].FillWeight = 16
$grid.Columns[3].FillWeight = 18
$grid.Columns[4].FillWeight = 26
$grid.Columns[5].FillWeight = 22

$form.Controls.Add($grid)

# Eventos
$btnScan.Add_Click({ Run-Scan })
$btnExport.Add_Click({
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = "CSV (*.csv)|*.csv"
    $dialog.FileName = "MkChecks_Relatorio_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:Findings | Export-Csv -LiteralPath $dialog.FileName -NoTypeInformation -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Relatório guardado em:`n$($dialog.FileName)", "MkChecks")
    }
})

# Execução automática ao abrir via link remoto
$form.Add_Shown({
    Pump-UI
    if ($script:AutoRunAndSend) {
        Run-Scan
    }
})

[void]$form.ShowDialog()
