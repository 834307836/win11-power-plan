# ============================================================
#  导入 .pow 电源计划并逐项校验（换机 / 换 CPU 部署用）
#
#  需要管理员权限（写电源方案在 HKLM）。
#
#  用法：
#    import-plan.ps1 -PlanFile <路径.pow> -TargetGuid <GUID> [-TargetName <名称>] [-SkipSetActive]
#    或直接双击 import-plan.cmd（会自动提权并交互提示）
#
#  行为：
#    1) 备份本机现有全部电源方案到 tools\backup\
#    2) powercfg /import <文件> <GUID>
#    3) 若 powercfg 不接受该文件（部分方案是注册表配置单元格式），
#       则以「均衡」为模板新建同 GUID 方案，再按 XML 逐项写入
#    4) 逐项读回校验
#    5) 设为当前方案（可用 -SkipSetActive 跳过）
#    6) 不删除任何原有方案
#
#  可移植性：所有路径从脚本自身位置推导，换机器/换目录不用改代码。
# ============================================================

param(
    [Parameter(Mandatory = $true)][string]$PlanFile,
    [Parameter(Mandatory = $true)][string]$TargetGuid,
    [string]$TargetName = '',
    [switch]$SkipSetActive
)

$ErrorActionPreference = 'Continue'

# ---- 定位脚本所在目录 ----
$Here = $PSScriptRoot
if (-not $Here) { $Here = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $Here) { $Here = (Get-Location).Path }

$BackupDir = Join-Path $Here 'backup'
$LogFile   = Join-Path $Here 'import-log.txt'

function Log([string]$msg) {
    $line = "$(Get-Date -f 'HH:mm:ss')  $msg"
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding utf8
}

function Get-Schemes {
    $out = powercfg /list 2>&1 | Out-String
    $res = @()
    foreach ($m in [regex]::Matches($out, '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\s+\(([^)]*)\)')) {
        $res += [pscustomobject]@{ Guid = $m.Groups[1].Value.ToLower(); Name = ($m.Groups[2].Value -replace '\*', '').Trim() }
    }
    return $res
}

Set-Content -LiteralPath $LogFile -Value "=== 导入电源方案 $(Get-Date -f 'yyyy-MM-dd HH:mm:ss') ===" -Encoding utf8

# ---------- 0. 环境检查 ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Log '错误：未以管理员身份运行（请双击 import-plan.cmd）'; exit 1 }
Log '管理员权限：OK'

$PlanFile   = (Resolve-Path -LiteralPath $PlanFile -ErrorAction SilentlyContinue).Path
if (-not $PlanFile -or -not (Test-Path -LiteralPath $PlanFile)) { Log "错误：找不到文件 $PlanFile"; exit 1 }
$TargetGuid = $TargetGuid.Trim().ToLower()
Log "源文件：$PlanFile"
Log "目标 GUID：$TargetGuid"

# 检测格式：powercfg 导出的 XML 以 UTF-8 BOM + '<?xml' 开头；
# 两个「致郁专辑」是注册表配置单元，文件头为 ASCII 'regf'，本脚本无法处理。
$head = [System.IO.File]::ReadAllBytes($PlanFile)[0..3]
$headAscii = -join ($head | ForEach-Object { [char]$_ })
$isRegHive = ($headAscii -eq 'regf')
$isXml = $false
try { [xml]$null = Get-Content -LiteralPath $PlanFile -Raw -Encoding UTF8; $isXml = $true } catch { $isXml = $false }

if ($isRegHive) {
    Log ''
    Log '错误：这个文件是【注册表配置单元】格式（文件头 regf），不是 powercfg 导出的 XML。'
    Log '      powercfg /import 对本文件不适用，请按原作者视频里的方式导入。'
    exit 1
}
if (-not $isXml) {
    Log ''
    Log '错误：无法按 XML 解析该文件，且它不是已知的注册表配置单元格式。已中止，本机方案未被改动。'
    exit 1
}
Log '格式检查：XML，OK'

# ---------- 1. 备份现有方案 ----------
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
$before = Get-Schemes
Log "现有方案 $($before.Count) 个，开始备份到 $BackupDir ..."
foreach ($s in $before) {
    $safe = ($s.Name -replace '[\\/:*?"<>|]', '_')
    $dest = Join-Path $BackupDir ("{0}_{1}.pow" -f $safe, $s.Guid)
    powercfg /export "$dest" $s.Guid 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0 -and (Test-Path $dest) -and (Get-Item $dest).Length -gt 0) {
        Log ("    已备份 {0} ({1} 字节)" -f (Split-Path $dest -Leaf), (Get-Item $dest).Length)
    } else {
        Log ("    备份失败：{0}" -f $s.Name)
    }
}

# ---------- 2. 尝试 powercfg /import ----------
$importOk = $false
$method   = '未知'
Log "尝试 powercfg /import（含 GUID）..."
$r = (powercfg /import "$PlanFile" $TargetGuid 2>&1 | Out-String).Trim()
Log "    exit=$LASTEXITCODE  $r"
if ((Get-Schemes).Guid -contains $TargetGuid) { $importOk = $true; $method = 'powercfg /import <文件> <GUID>' }

if (-not $importOk) {
    Log "尝试 powercfg /import（不指定 GUID）..."
    $beforeGuids = (Get-Schemes).Guid
    $r = (powercfg /import "$PlanFile" 2>&1 | Out-String).Trim()
    Log "    exit=$LASTEXITCODE  $r"
    $new = (Get-Schemes) | Where-Object { $beforeGuids -notcontains $_.Guid }
    if ($new) {
        Log "    新方案：$($new.Guid -join ',')（不是目标 GUID，删除后走模板路线）"
        foreach ($n in $new) { powercfg /delete $n.Guid 2>&1 | Out-Null }
    }
    if ((Get-Schemes).Guid -contains $TargetGuid) { $importOk = $true; $method = 'powercfg /import <文件>（自动 GUID）' }
}

# ---------- 3. 回退：模板复制 + 逐项写入 ----------
if (-not $importOk) {
    Log "powercfg 不直接接受该文件，改用模板新建方案..."
    $method = '模板复制 + 逐项写入'
    $tpl = (Get-Schemes) | Where-Object { $_.Guid -eq '85d583c5-cf2e-4197-80fd-3789a227a72c' }   # 均衡
    if (-not $tpl) { $tpl = (Get-Schemes) | Where-Object { $_.Guid -eq '381b4222-f694-41f0-9685-ff5bb260df2e' } }
    if (-not $tpl) { Log '错误：找不到可用的模板方案（均衡），已中止。'; exit 1 }
    Log "    模板：$($tpl.Name)  $($tpl.Guid)"
    $tplFile = Join-Path $Here 'template.pow'
    powercfg /export "$tplFile" $tpl.Guid 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Log '错误：模板导出失败，已中止。'; exit 1 }
    $r = (powercfg /import "$tplFile" $TargetGuid 2>&1 | Out-String).Trim()
    Log "    模板导入 exit=$LASTEXITCODE  $r"
    Remove-Item -LiteralPath $tplFile -Force -ErrorAction SilentlyContinue
    $importOk = (Get-Schemes).Guid -contains $TargetGuid
}
if (-not $importOk) { Log '错误：新方案创建失败，已中止（原有方案未被改动）。'; exit 1 }
Log "方案已创建：$TargetGuid"

# ---------- 4. 按 XML 逐项写入并校验 ----------
[xml]$xml = Get-Content -LiteralPath $PlanFile -Raw -Encoding UTF8
$items = @()
foreach ($sg in $xml.root.subgroup) {
    foreach ($st in $sg.setting) {
        $ac = ($st.acindex | Where-Object { $_.scheme -eq $TargetGuid }).value
        $dc = ($st.dcindex | Where-Object { $_.scheme -eq $TargetGuid }).value
        if ($null -ne $ac -and $null -ne $dc) {
            $items += [pscustomobject]@{
                Subgroup = $sg.guid; Setting = $st.guid; Name = $st.name
                AC = [int]$ac; DC = [int]$dc
            }
        }
    }
}
Log "从 XML 解析到 $($items.Count) 项设置（属于 GUID $TargetGuid），开始写入..."

$failAc = 0; $failDc = 0
foreach ($it in $items) {
    powercfg /setacvalueindex $TargetGuid $it.Subgroup $it.Setting $it.AC 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { $failAc++; Log ("    AC 写入失败 [{0}] = {1}" -f $it.Name, $it.AC) }
    powercfg /setdcvalueindex $TargetGuid $it.Subgroup $it.Setting $it.DC 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { $failDc++; Log ("    DC 写入失败 [{0}] = {1}" -f $it.Name, $it.DC) }
}
Log "写入完成：AC 失败 $failAc 项，DC 失败 $failDc 项"

Log "逐项读回校验..."
$okAc = 0; $okDc = 0; $bad = @()
foreach ($it in $items) {
    $q = powercfg /query $TargetGuid $it.Subgroup $it.Setting 2>&1 | Out-String
    $mac = [regex]::Match($q, '当前交流电源设置索引:\s*0x([0-9a-fA-F]+)')
    $mdc = [regex]::Match($q, '当前直流电源设置索引:\s*0x([0-9a-fA-F]+)')
    $gotAc = if ($mac.Success) { [Convert]::ToInt64($mac.Groups[1].Value, 16) } else { $null }
    $gotDc = if ($mdc.Success) { [Convert]::ToInt64($mdc.Groups[1].Value, 16) } else { $null }
    if ($gotAc -eq $it.AC) { $okAc++ } else { $bad += "AC [{0}] 期望 {1} 实际 {2}" -f $it.Name, $it.AC, $gotAc }
    if ($gotDc -eq $it.DC) { $okDc++ } else { $bad += "DC [{0}] 期望 {1} 实际 {2}" -f $it.Name, $it.DC, $gotDc }
}
Log "校验结果：AC 一致 $okAc/$($items.Count)，DC 一致 $okDc/$($items.Count)"
foreach ($b in $bad) { Log "    不一致：$b" }

# ---------- 5. 改名 / 设为当前 ----------
if (-not [string]::IsNullOrWhiteSpace($TargetName)) {
    powercfg /changename $TargetGuid $TargetName 2>&1 | Out-Null
    Log "已重命名为「$TargetName」(exit=$LASTEXITCODE)"
}

if (-not $SkipSetActive) {
    powercfg /setactive $TargetGuid 2>&1 | Out-Null
    Log "已设为当前方案 (exit=$LASTEXITCODE)"
}

# ---------- 6. 汇总 ----------
Log '---------- 完成 ----------'
Log (powercfg /list 2>&1 | Out-String)
Log ('当前活动方案：' + (powercfg /getactivescheme 2>&1 | Out-String).Trim())
Log "导入方式：$method；共 $($items.Count) 项；AC 一致 $okAc，DC 一致 $okDc"
Log "回退：原有方案已备份在 $BackupDir，可 powercfg /import 逐个恢复。"
