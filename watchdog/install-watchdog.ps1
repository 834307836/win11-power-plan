# ============================================================
#  安装「电源方案看门狗」计划任务（SYSTEM 权限）
#
#  需要管理员权限。可重复运行（会先删除同名任务再重建）。
#  用法：
#    install-watchdog.ps1 -TargetGuid <GUID> [-TargetName <名称>] [-TaskName <任务名>]
#  或直接双击 install-watchdog.cmd（会自动提权并提示输入 GUID）。
# ============================================================

param(
    [Parameter(Mandatory = $true)][string]$TargetGuid,
    [string]$TargetName = '',
    [string]$TaskName   = 'PowerPlanWatchdog'
)

$ErrorActionPreference = 'Continue'

# ---- 定位脚本所在目录 ----
$Here = $PSScriptRoot
if (-not $Here) { $Here = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $Here) { $Here = (Get-Location).Path }

$Watchdog = Join-Path $Here 'powerplan-watchdog.ps1'
$CfgFile  = Join-Path $Here 'watchdog-config.json'
$LogFile  = Join-Path $Here 'watchdog-install-log.txt'

function Log([string]$m) {
    $l = "$(Get-Date -f 'HH:mm:ss')  $m"
    Write-Host $l
    Add-Content -LiteralPath $LogFile -Value $l -Encoding utf8
}
Set-Content -LiteralPath $LogFile -Value "=== 安装看门狗任务 $(Get-Date -f 'yyyy-MM-dd HH:mm:ss') ===" -Encoding utf8

# ---- 0. 管理员检查 ----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Log '错误：未以管理员身份运行（请双击 install-watchdog.cmd）'; exit 1 }
Log '管理员权限：OK'

if (-not (Test-Path -LiteralPath $Watchdog)) { Log "错误：找不到看门狗本体 $Watchdog"; exit 1 }

# ---- 1. 校验 GUID 在本机存在，并取回显示名 ----
$TargetGuid = $TargetGuid.Trim().ToLower()
$list = (powercfg /list 2>&1 | Out-String)
Log '本机电源方案：'
foreach ($l in ($list -split "`r?`n" | Where-Object { $_.Trim() })) { Log ('    ' + $l.Trim()) }

if ($list -notmatch [regex]::Escape($TargetGuid)) {
    Log "错误：本机找不到 GUID 为 $TargetGuid 的电源方案。"
    Log '      请先导入 .pow（见 README 第二节），再重新运行本脚本。'
    exit 1
}
Log "目标方案存在：$TargetGuid"

if ([string]::IsNullOrWhiteSpace($TargetName)) {
    $m = [regex]::Match($list, [regex]::Escape($TargetGuid) + '\s*\(([^)]*)\)')
    if ($m.Success) { $TargetName = ($m.Groups[1].Value -replace '\*', '').Trim() }
    if ([string]::IsNullOrWhiteSpace($TargetName)) { $TargetName = '自定义电源方案' }
}
Log "目标方案名称：$TargetName"

# ---- 2. 写入看门狗配置 ----
$cfg = [pscustomobject]@{ targetGuid = $TargetGuid; targetName = $TargetName }
$cfg | ConvertTo-Json | Set-Content -LiteralPath $CfgFile -Encoding UTF8
Log "已写入配置：$CfgFile"

# ---- 3. 注册计划任务（先删同名）----
$old = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($old) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false; Log "已删除旧的同名任务：$TaskName" }

$Action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Watchdog`""

$TStartup = New-ScheduledTaskTrigger -AtStartup
try { $TStartup.Delay = 'PT1M'; Log '开机触发器已设置 1 分钟延迟' }
catch { Log "开机触发器延迟设置失败（不影响使用）：$($_.Exception.Message)" }
$TLogon  = New-ScheduledTaskTrigger -AtLogOn
$TRepeat = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)

$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 3)
$Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger @($TStartup, $TLogon, $TRepeat) `
    -Settings $Settings -Principal $Principal `
    -Description "当前活动电源方案不是 $TargetGuid 时自动切回；临时放行可创建 watchdog-hold.txt" | Out-Null
Log "任务已注册：$TaskName"

$t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($t) { Log "任务状态：$($t.State)；触发器数：$($t.Triggers.Count)；身份 $($t.Principal.UserId) / RunLevel=$($t.Principal.RunLevel)" }

# ---- 4. 实测：故意切到别的方案，再跑一次看是否被拉回 ----
$others = @(powercfg /list 2>&1 | Select-String -Pattern '([0-9a-fA-F-]{36})' -AllMatches |
    ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value.ToLower() } |
    Where-Object { $_ -ne $TargetGuid } | Select-Object -Unique)

if ($others.Count -gt 0) {
    $probe = $others[0]
    Log "实测：先切到 $probe ..."
    powercfg /setactive $probe 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    Log ('    切换后当前方案：' + (powercfg /getactivescheme 2>&1 | Out-String).Trim())

    Log '运行看门狗任务...'
    Start-ScheduledTask -TaskName $TaskName
    Start-Sleep -Seconds 8
    $after = (powercfg /getactivescheme 2>&1 | Out-String).Trim()
    Log "    看门狗运行后：$after"

    if ($after -match [regex]::Escape($TargetGuid)) {
        Log '结论：OK 看门狗有效，被切走的方案已被自动拉回'
    } else {
        Log '结论：FAIL 看门狗未生效，已手动切回目标方案'
        powercfg /setactive $TargetGuid 2>&1 | Out-Null
    }
} else {
    Log '跳过实测：本机只有目标这一个电源方案'
}

$info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
if ($info) { Log "任务最近一次运行：LastRunTime=$($info.LastRunTime)  LastTaskResult=$($info.LastTaskResult)  NextRunTime=$($info.NextRunTime)" }
Log ('当前活动方案：' + (powercfg /getactivescheme 2>&1 | Out-String).Trim())
Log '安装完成。暂停看门狗请双击 watchdog-pause.cmd，恢复请双击 watchdog-resume.cmd。'
