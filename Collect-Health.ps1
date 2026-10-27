param([int]$Days = 7)
$ErrorActionPreference = 'Stop'
$warnings = New-Object System.Collections.Generic.List[string]
$since = (Get-Date).AddDays(-$Days)
$now = Get-Date
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$os = $null; $volume = $null; $disks = @(); $events = @(); $updates = @(); $apps = @(); $integrity = @()
$coverage = [ordered]@{}
try {
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $os = [ordered]@{ Name=$osInfo.Caption; Version=$osInfo.Version; Build=$osInfo.BuildNumber; LastBoot=$osInfo.LastBootUpTime.ToString('o'); MemoryGB=[math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 1) }
    $coverage.OS = 'Read'
} catch { $coverage.OS='Unavailable'; $warnings.Add('Windows version and uptime could not be read.') }
try {
    $drive = $env:SystemDrive.TrimEnd(':')
    $vol = Get-Volume -DriveLetter $drive
    $volume = [ordered]@{ Drive=$env:SystemDrive; Health=[string]$vol.HealthStatus; FreeGB=[math]::Round($vol.SizeRemaining / 1GB, 1); SizeGB=[math]::Round($vol.Size / 1GB, 1); FreePercent=[math]::Round(100 * $vol.SizeRemaining / $vol.Size, 1) }
    $coverage.SystemDrive='Read'
} catch { $coverage.SystemDrive='Unavailable'; $warnings.Add('System drive health and space could not be read.') }
try {
    $disks = @(Get-PhysicalDisk | ForEach-Object { [pscustomobject]@{ Name=$_.FriendlyName; Type=[string]$_.MediaType; Health=[string]$_.HealthStatus; Status=($_.OperationalStatus -join ', '); SizeGB=[math]::Round($_.Size / 1GB, 1) } })
    $coverage.PhysicalDisks='Read'
} catch { $coverage.PhysicalDisks='Unavailable'; $warnings.Add('Physical drive health could not be read. Detailed SMART and temperature checks are not included.') }
try {
    # A bounded query prevents very noisy event logs from slowing down the desktop.
    $rawEvents = @(Get-WinEvent -FilterHashtable @{LogName='System'; Level=@(1,2); StartTime=$since} -MaxEvents 501 -ErrorAction Stop)
    $coverage.SystemEvents='Read'
} catch {
    $rawEvents=@()
    if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') { $coverage.SystemEvents='Read' }
    else { $coverage.SystemEvents='Unavailable'; $warnings.Add('System events could not be read. Try reopening the app as administrator for greater coverage.') }
}
$truncated = $rawEvents.Count -gt 500
if ($truncated) { $warnings.Add('Only the newest 500 system errors and critical events are shown. Counts cover this sample, not the entire period.') }
$events = @($rawEvents | Select-Object -First 500 | ForEach-Object {
    $meaning='A Windows component reported a failure. Review the details and check whether the same problem repeats.'
    $next='If you noticed a matching symptom, record what you were doing at this time.'
    $priority='Review'
    if ($_.Level -eq 1) { $priority='Important'; $meaning='Windows recorded an event at its critical severity level. This alone does not identify the cause.' }
    if ($_.ProviderName -eq 'Microsoft-Windows-Kernel-Power' -and $_.Id -eq 41) { $meaning='Windows detected that the previous shutdown was not clean. Power loss, a forced shutdown, or a crash can all cause this.'; $next='Check whether the PC lost power or froze. Repeated unexplained restarts deserve investigation.' }
    elseif ($_.ProviderName -match 'BTH|Bluetooth') { $meaning='The Bluetooth driver reported a communication problem. If Bluetooth works normally, this may not need immediate action.'; $next='If devices disconnect repeatedly, check Windows Update and the PC maker for Bluetooth driver updates.' }
    elseif ($_.ProviderName -eq 'Microsoft-Windows-DistributedCOM') { $meaning='A Windows component failed to start or respond as expected. This event alone does not prove damaged system files.'; $next='Investigate if an app fails at the same time. Avoid changing registry permissions based only on this entry.' }
    elseif ($_.ProviderName -match 'WHEA') { $meaning='Windows recorded a hardware error report. The event details and recurrence determine its significance.'; $next='If this repeats or accompanies crashes, investigate hardware, temperatures, and firmware.'; $priority='Important' }
    elseif ($_.ProviderName -match '^(disk|Ntfs|Microsoft-Windows-Ntfs|storahci|stornvme)$') { $meaning='The storage system reported an error. This can involve a drive, connection, or driver.'; $next='Back up important files and investigate repeated storage errors.'; $priority='Important' }
    [pscustomobject]@{ Time=$_.TimeCreated.ToString('o'); Priority=$priority; Source=$_.ProviderName; EventId=$_.Id; LevelNumber=$_.Level; WindowsLevel=$_.LevelDisplayName; Explanation=$meaning; NextStep=$next; Details=$_.Message; RecordId=$_.RecordId }
})
try {
    $updates = @(Get-HotFix | Where-Object { $_.InstalledOn -and $_.InstalledOn -ge $since } | Sort-Object InstalledOn -Descending | ForEach-Object { [pscustomobject]@{ Date=$_.InstalledOn.ToString('yyyy-MM-dd'); Name=$_.HotFixID; Type=$_.Description } })
    $coverage.Updates='Read'
} catch { $coverage.Updates='Unavailable'; $warnings.Add('Recent Windows hotfix history could not be read.') }
try {
    $registryRoots=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
    $apps = @(Get-ItemProperty $registryRoots -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $_.InstallDate -match '^\d{8}$' } | ForEach-Object {
        $date=[datetime]::MinValue
        if ([datetime]::TryParseExact([string]$_.InstallDate,'yyyyMMdd',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$date) -and $date -ge $since.Date -and $date -le $now.Date) {
            [pscustomobject]@{ Date=$date.ToString('yyyy-MM-dd'); Name=$_.DisplayName; Type='App recorded install/update date' }
        }
    } | Sort-Object Date,Name -Unique | Sort-Object Date -Descending)
    $coverage.AppDates='Read'
} catch { $coverage.AppDates='Unavailable'; $warnings.Add('Recorded app installation dates could not be read.') }
try {
    $cbs=Join-Path $env:windir 'Logs\CBS\CBS.log'
    $hits=@(Get-Content -LiteralPath $cbs -Tail 30000 | Select-String -Pattern 'Corrupt file:|Cannot repair member file|Repairing corrupted file')
    $integrity=@($hits | Select-Object -Last 12 | ForEach-Object { [string]$_.Line })
    $coverage.IntegrityHistory='Read'
} catch { $coverage.IntegrityHistory='Unavailable'; $warnings.Add('Windows repair history could not be read. Administrator access may be needed.') }
$important=@($events | Where-Object { $_.Priority -eq 'Important' }).Count
$critical=@($events | Where-Object { $_.LevelNumber -eq 1 }).Count
$status='No urgent findings in available checks'
if ($volume -and ($volume.Health -ne 'Healthy' -or $volume.FreePercent -lt 10)) { $status='Needs attention' }
if (@($disks | Where-Object { $_.Health -ne 'Healthy' }).Count -gt 0 -or $important -gt 0) { $status='Needs attention' }
if ($integrity.Count -gt 0 -and $status -ne 'Needs attention') { $status='Review Windows integrity history' }
if (@($coverage.Values | Where-Object { $_ -eq 'Unavailable' }).Count -gt 0) {
    if ($status -eq 'Needs attention') { $status='Needs attention / some checks incomplete' }
    else { $status='Checks incomplete' }
}
[ordered]@{
    SchemaVersion=1; ScannedAt=$now.ToString('o'); ComputerName=$env:COMPUTERNAME; Days=$Days; Administrator=$isAdmin
    Status=$status; OS=$os; SystemDrive=$volume; PhysicalDisks=@($disks); Events=@($events); ImportantCount=$important; CriticalCount=$critical; EventsTruncated=$truncated
    RecentChanges=@(@($updates)+@($apps) | Sort-Object @{Expression='Date';Descending=$true},Name); IntegrityHistory=@($integrity); Coverage=$coverage; Warnings=@($warnings.ToArray())
    Limitations=@('This is an on-demand, read-only report, not a complete diagnosis or malware scan.','System-event counts exclude application logs and include at most 500 records.','CBS entries are historical clues; this app does not run a new system-file verification or determine whether past corruption was repaired.','Hotfix history and recorded app dates are partial; driver changes, Store apps, removals, and all Windows updates are not fully tracked.','Timing alone does not prove that an update or application caused a failure.','Basic drive status cannot rule out hardware failure. Deleted personal files cannot be reconstructed from this report.')
} | ConvertTo-Json -Depth 8
