# Run-Dashboard.ps1

$ErrorActionPreference = "SilentlyContinue"

function Write-Log {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
}

Write-Log "Initializing Professional Diagnostic Suite..." -Color Yellow

# 1. Retrieve TPM Data
Write-Log "Scanning TPM Module..."
$tpmRaw = Get-Tpm
$tpmJson = @{
    TpmPresent          = $tpmRaw.TpmPresent
    TpmReady            = $tpmRaw.TpmReady
    TpmEnabled          = $tpmRaw.TpmEnabled
    TpmActivated        = $tpmRaw.TpmActivated
    TpmOwned            = $tpmRaw.TpmOwned
    RestartPending      = $tpmRaw.RestartPending
    ManufacturerId      = $tpmRaw.ManufacturerId
    ManufacturerVersion = ($tpmRaw.ManufacturerVersion -replace '\p{C}', '')
} | ConvertTo-Json -Depth 5 -Compress

# 2. Retrieve MeasuredBoot Data
Write-Log "Parsing Measured Boot Telemetry..."
$logsPath = "C:\Windows\Logs\MeasuredBoot"
$latestLog = Get-ChildItem -Path $logsPath -Filter "*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($latestLog) {
    $rawJson = [System.IO.File]::ReadAllText($latestLog.FullName)
    $rawJson = $rawJson.Replace("`0", "").Trim()
    $fixedJson = [System.Text.RegularExpressions.Regex]::Replace($rawJson, '}(\s*){', '},$1{')
} else {
    $fixedJson = '{"Error": "No logs found."}'
}

# 3. Extract Hardware & Host Identity
Write-Log "Auditing System Hardware & Host Identity..."
$hostName = $env:COMPUTERNAME
$userName = $env:USERNAME
$cpu = (Get-CimInstance Win32_Processor).Name -join ' | '
$mobo = (Get-CimInstance Win32_BaseBoard).Product -join ' | '
$bios = (Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion

# Detailed RAM Extraction (Amount, Estimated Type, and Clock Speed)
$ramChips = Get-CimInstance Win32_PhysicalMemory
$ramBytes = ($ramChips | Measure-Object -Property Capacity -Sum).Sum
$ramGb = [Math]::Round($ramBytes / 1GB)
$ramClock = ($ramChips | Select-Object -First 1).ConfiguredClockSpeed

# Safe DDR detection
$ramType = "DDR4"
if ($ramClock -gt 4000) { $ramType = "DDR5" }
elseif ($ramClock -lt 2133 -and $ramClock -gt 0) { $ramType = "DDR3" }

$ramString = "${ramGb}GB $ramType ${ramClock}mhz"
$gpuList = foreach ($g in (Get-CimInstance Win32_VideoController)) { "$($g.Name) (v. $($g.DriverVersion))" }
$gpuString = $gpuList -join ' + '

$sysJson = @{
    HostName    = $hostName
    UserName    = $userName
    Cpu         = $cpu.Trim()
    Motherboard = $mobo.Trim()
    BiosVersion = $bios.Trim()
    RamDetails  = $ramString
    Gpu         = $gpuString
} | ConvertTo-Json -Compress

# 4. Extract Security Parameters
Write-Log "Checking Security Environment..."
$secureBoot = try { (Confirm-SecureBootUEFI -ErrorAction Stop) ? "Enabled" : "Disabled" } catch { "Unsupported" }
$bitlocker = try { $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop; ($bl.ProtectionStatus -eq 1 -or $bl.ProtectionStatus -eq 'On') ? "Enabled" : "Disabled" } catch { "N/A" }
$os = Get-CimInstance Win32_OperatingSystem
$uptime = (Get-Date) - $os.LastBootUpTime
$uptimeString = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
$fastStartupVal = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -ErrorAction SilentlyContinue).HiberbootEnabled
$fastStartup = ($null -ne $fastStartupVal -and $fastStartupVal -eq 1) ? "Enabled" : "Disabled"

$secStatusJson = @{
    SecureBoot = $secureBoot; BitLocker_C = $bitlocker; Uptime = $uptimeString; FastStartup = $fastStartup
} | ConvertTo-Json -Compress

# 5. Extract Event Logs (Only Criticals & Errors over the last 7 Days)
Write-Log "Extracting Critical System Event Logs (Last 7 Days)..."
$startTime = (Get-Date).AddDays(-7)

# Filtering strictly: Level 1 (Critical) and Level 2 (Error)
$events = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$startTime} -ErrorAction SilentlyContinue -MaxEvents 30

$eventLogsList = @()
if ($events) {
    foreach ($e in $events) {
        $eventLogsList += @{
            Time = $e.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
            Source = $e.ProviderName
            EventId = $e.Id
            Level = if ($e.LevelDisplayName) { $e.LevelDisplayName } else { "Error" }
            Message = if ($e.Message) { $e.Message.Replace("`n", " ").Replace("`r", "").Trim() } else { "No description provided." }
        }
    }
}
$eventLogsJson = if ($eventLogsList.Count -gt 0) { $eventLogsList | ConvertTo-Json -Compress -Depth 3 } else { "[]" }

# 6. Final Payload Assembly
Write-Log "Rendering Dashboard Data..."
$masterPayload = "{ `"SystemInfo`": $sysJson, `"SecurityStatus`": $secStatusJson, `"Tpm`": $tpmJson, `"MeasuredBoot`": $fixedJson, `"EventLogs`": $eventLogsJson }"

# 7. Auto-Archiving (Historical snapshots)
$archivePath = Join-Path -Path $PSScriptRoot -ChildPath "Archive"
if (-not (Test-Path $archivePath)) { New-Item -ItemType Directory -Path $archivePath | Out-Null }
$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$archiveFile = Join-Path -Path $archivePath -ChildPath "Diagnostic_$timestamp.json"
Set-Content -Path $archiveFile -Value (ConvertTo-Json (ConvertFrom-Json $masterPayload) -Depth 10) -Encoding UTF8

# 8. HTML Creation, Local Dependencies Copy, and Launch
$templatePath = Join-Path -Path $PSScriptRoot -ChildPath "template.html"
$outputPath = Join-Path -Path $env:TEMP -ChildPath "TpmMonitor.html"

# Define local JS file paths
$vueLocal = Join-Path -Path $PSScriptRoot -ChildPath "vue.global.js"
$tailwindLocal = Join-Path -Path $PSScriptRoot -ChildPath "tailwind.js"

if (Test-Path $templatePath) {
    # Copy JS dependencies to the TEMP folder so HTML can resolve them locally
    if (Test-Path $vueLocal) { Copy-Item -Path $vueLocal -Destination $env:TEMP -Force }
    if (Test-Path $tailwindLocal) { Copy-Item -Path $tailwindLocal -Destination $env:TEMP -Force }

    # Generate the HTML file
    (Get-Content -Path $templatePath -Raw).Replace('%%DATA_PAYLOAD%%', $masterPayload) | Set-Content -Path $outputPath -Encoding UTF8
    
    Start-Process $outputPath
    Write-Log "Diagnostic generated successfully. Engine closing." -Color Green
    Start-Sleep -Seconds 1
} else {
    Write-Log "Error: template.html not found!" -Color Red
    Start-Sleep -Seconds 3
}