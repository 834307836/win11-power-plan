# ============================================================
#  电源方案看门狗（可移植版）
#
#  作用：只要当前活动电源方案不是目标方案，就立刻切回去。
#        由计划任务以 SYSTEM 权限运行（开机 + 登录 + 每 5 分钟）。
#
#  配置：同目录 watchdog-config.json
#        { "targetGuid": "<GUID>", "targetName": "<显示名>" }
#        由 install-watchdog.cmd / install-watchdog.ps1 自动写入。
#
#  临时放行：同目录下存在 watchdog-hold.txt 时跳过
#            （也可双击 watchdog-pause.cmd / watchdog-resume.cmd）。
#
#  可移植性：所有路径都从脚本自身所在目录推导，换机器/换目录都不用改代码。
# ============================================================

$ErrorActionPreference = 'Continue'

# ---- 定位脚本所在目录（三级回退）----
$Here = $PSScriptRoot
if (-not $Here) { $Here = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $Here) { $Here = (Get-Location).Path }

$CfgFile   = Join-Path $Here 'watchdog-config.json'
$LogFile   = Join-Path $Here 'watchdog-log.txt'
$HoldFile  = Join-Path $Here 'watchdog-hold.txt'
$HeartFile = Join-Path $Here 'watchdog-heartbeat.txt'

# ---- 读配置；没有配置就静默退出，不做任何事 ----
if (-not (Test-Path -LiteralPath $CfgFile)) { exit 0 }
try {
    $cfg = Get-Content -LiteralPath $CfgFile -Raw -Encoding UTF8 | ConvertFrom-Json
} catch { exit 0 }

$TargetGuid = $cfg.targetGuid
if ([string]::IsNullOrWhiteSpace($TargetGuid)) { exit 0 }
$TargetGuid = $TargetGuid.Trim().ToLower()

# ---- 当前状态 ----
$active = (powercfg /getactivescheme 2>&1 | Out-String)
$hold   = Test-Path -LiteralPath $HoldFile

# 心跳：每次运行都刷新，用来确认任务确实在按计划跑（单行覆盖，不会堆积）
$hb = "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')  hold=$hold  active=$($active -replace '\s+',' ')"
Set-Content -LiteralPath $HeartFile -Value $hb -Encoding utf8

if ($hold) { exit 0 }   # 处于放行状态，只留心跳不动方案

# ---- 不在目标方案上 -> 切回 ----
if ($active -notmatch [regex]::Escape($TargetGuid)) {
    powercfg /setactive $TargetGuid 2>&1 | Out-Null
    $after = (powercfg /getactivescheme 2>&1 | Out-String).Trim()
    $line  = "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')  检测到被切走 -> 已切回 $TargetGuid ; 当前=$($after -replace '\s+',' ')"
    Add-Content -LiteralPath $LogFile -Value $line -Encoding utf8

    # 日志最多保留 300 行
    $lines = @(Get-Content -LiteralPath $LogFile -ErrorAction SilentlyContinue)
    if ($lines.Count -gt 300) {
        $lines | Select-Object -Last 150 | Set-Content -LiteralPath $LogFile -Encoding utf8
    }
}
