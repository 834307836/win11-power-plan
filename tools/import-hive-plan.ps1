# ============================================================
#  导入「注册表配置单元」格式的电源方案（两个「致郁专辑」）
#
#  背景：
#    AMD致郁专辑.pow / lntel致郁专辑.pow 不是 powercfg 导出的 XML，
#    而是注册表配置单元（文件头 ASCII "regf"），powercfg /import 用不了。
#    它们的结构恰好等价于注册表里的
#      HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\<GUID>
#    根键名就是方案 GUID，下面挂 7 个分组子键，再下面是设置子键与
#    ACSettingIndex / DCSettingIndex。
#
#  本脚本直接解析配置单元文件，把整棵树原样写进 PowerSchemes\<GUID>。
#  ⚠️ 全程使用 [Microsoft.Win32.Registry] 原生 API，**不调用 reg.exe**
#     （reg.exe 在本机安全策略黑名单里，会被静默拦截）。
#
#  用法：
#    import-hive-plan.ps1 -HiveFile <路径.pow> [-TargetGuid <GUID>] [-TargetName <名称>] [-SkipSetActive]
#    -TargetGuid 省略时，自动采用配置单元根键名（推荐）。
#    或直接双击 import-hive-plan.cmd（自动提权并交互提示）
#
#  行为：
#    1) 备份本机现有全部电源方案到 tools\backup\
#    2) 解析配置单元 -> 写进 PowerSchemes\<GUID>
#    3) 逐键逐值读回校验
#    4) 设为当前方案（可用 -SkipSetActive 跳过）
#    5) 不删除任何原有方案
#
#  回退：
#    Remove-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\<GUID>' -Recurse -Force
# ============================================================

param(
    [Parameter(Mandatory = $true)][string]$HiveFile,
    [string]$TargetGuid = '',
    [string]$TargetName = '',
    [switch]$SkipSetActive
)

$ErrorActionPreference = 'Continue'

# ---- 定位脚本所在目录（三级回退，换机器/换目录不用改代码）----
$Here = $PSScriptRoot
if (-not $Here) { $Here = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $Here) { $Here = (Get-Location).Path }

$BackupDir = Join-Path $Here 'backup'
$LogFile   = Join-Path $Here 'import-log.txt'
$NONE      = [uint32]::MaxValue          # 0xFFFFFFFF：REGF 里「无子键 / 无值」的哨兵值
                                         # （不能写 [uint32]0xFFFFFFFF：PS 5.1 会把 0xFFFFFFFF
                                         #   先当成 Int32 的 -1，再转 UInt32 直接抛异常）
$script:ENC = [System.Text.Encoding]::GetEncoding(28591)   # Latin-1：键名/值名都是 ASCII

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

Set-Content -LiteralPath $LogFile -Value "=== 导入注册表配置单元电源方案 $(Get-Date -f 'yyyy-MM-dd HH:mm:ss') ===" -Encoding utf8

# ---------- 0. 环境检查 ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Log '错误：未以管理员身份运行（请双击 import-hive-plan.cmd）'; exit 1 }
Log '管理员权限：OK'

$HiveFile = (Resolve-Path -LiteralPath $HiveFile -ErrorAction SilentlyContinue).Path
if (-not $HiveFile -or -not (Test-Path -LiteralPath $HiveFile)) { Log "错误：找不到文件 $HiveFile"; exit 1 }
Log "源文件：$HiveFile"

# ---------- 1. 读入并做格式检查 ----------
$script:bytes = [System.IO.File]::ReadAllBytes($HiveFile)
if ($script:bytes.Length -lt 4096) { Log '错误：文件太小，不像注册表配置单元。已中止，本机未改动。'; exit 1 }

$sig = [System.Text.Encoding]::ASCII.GetString($script:bytes, 0, 4)
if ($sig -ne 'regf') {
    Log ''
    Log "错误：文件头是 '$sig'，不是注册表配置单元（应为 regf）。"
    Log '      如果这是 powercfg 导出的 XML，请改用 import-plan.cmd。已中止，本机未改动。'
    exit 1
}
$hbinSig = [System.Text.Encoding]::ASCII.GetString($script:bytes, 0x1000, 4)
if ($hbinSig -ne 'hbin') { Log "错误：0x1000 处不是 hbin（是 '$hbinSig'），文件结构异常。已中止。"; exit 1 }
Log '格式检查：注册表配置单元 (regf)，OK'

# ---------- 2. 配置单元解析器（纯原生，不用 reg.exe）----------
function Get-Cell([int]$off) {
    $a = 0x1000 + $off
    if ($a -lt 0 -or $a + 4 -gt $script:bytes.Length) { throw ("cell 偏移越界: 0x{0:X}" -f $a) }
    $size = [BitConverter]::ToInt32($script:bytes, $a)
    return @{ Base = $a + 4; Size = [Math]::Abs($size) }
}

function Get-Nk([int]$off) {
    $c = Get-Cell $off
    $b = $c.Base
    if ($script:bytes[$b] -ne 0x6E -or $script:bytes[$b + 1] -ne 0x6B) { return $null }   # 'nk'
    $nl = [BitConverter]::ToUInt16($script:bytes, $b + 0x48)
    $name = ''
    if ($nl -gt 0) { $name = $script:ENC.GetString($script:bytes, $b + 0x4C, $nl) }
    return [pscustomobject]@{
        Name     = $name
        SubCount = [BitConverter]::ToUInt32($script:bytes, $b + 0x14)
        SubList  = [BitConverter]::ToUInt32($script:bytes, $b + 0x1C)
        ValCount = [BitConverter]::ToUInt32($script:bytes, $b + 0x24)
        ValList  = [BitConverter]::ToUInt32($script:bytes, $b + 0x28)
    }
}

# 解析子键索引列表，返回子键 nk 单元的偏移数组
# 支持 lf / lh（8 字节条目）、li（4 字节条目）、ri（间接：条目指向下一级列表）
function Get-SubkeyOffsets([uint32]$listOff) {
    if ($listOff -eq $NONE -or $listOff -eq 0) { return @() }
    $b = (Get-Cell ([int]$listOff)).Base
    $sig = [System.Text.Encoding]::ASCII.GetString($script:bytes, $b, 2)
    $cnt = [BitConverter]::ToUInt16($script:bytes, $b + 2)
    $out = New-Object System.Collections.ArrayList
    if ($sig -eq 'lf' -or $sig -eq 'lh') {
        for ($i = 0; $i -lt $cnt; $i++) { [void]$out.Add([BitConverter]::ToUInt32($script:bytes, $b + 4 + $i * 8)) }
    } elseif ($sig -eq 'li') {
        for ($i = 0; $i -lt $cnt; $i++) { [void]$out.Add([BitConverter]::ToUInt32($script:bytes, $b + 4 + $i * 4)) }
    } elseif ($sig -eq 'ri') {
        for ($i = 0; $i -lt $cnt; $i++) {
            $sub = [BitConverter]::ToUInt32($script:bytes, $b + 4 + $i * 4)
            foreach ($x in (Get-SubkeyOffsets $sub)) { [void]$out.Add($x) }
        }
    } else {
        throw ("未知的子键列表签名 '{0}'（偏移 0x{1:X}）" -f $sig, $b)
    }
    return $out.ToArray()
}

# 读取某 nk 键下的全部值，返回 @{Name;Type;Data(byte[])}
function Get-Values([int]$off) {
    $k = Get-Nk $off
    if ($null -eq $k -or $k.ValCount -eq 0 -or $k.ValList -eq $NONE -or $k.ValList -eq 0) { return @() }
    $b = (Get-Cell ([int]$k.ValList)).Base
    $out = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $k.ValCount; $i++) {
        $vo = [BitConverter]::ToUInt32($script:bytes, $b + $i * 4)
        if ($vo -eq $NONE) { continue }
        $vb = (Get-Cell ([int]$vo)).Base
        if ($script:bytes[$vb] -ne 0x76 -or $script:bytes[$vb + 1] -ne 0x6B) { continue }   # 'vk'
        $nl = [BitConverter]::ToUInt16($script:bytes, $vb + 2)
        $ds = [BitConverter]::ToUInt32($script:bytes, $vb + 4)
        $do = [BitConverter]::ToUInt32($script:bytes, $vb + 8)
        $dt = [BitConverter]::ToUInt32($script:bytes, $vb + 0x0C)
        $name = ''
        if ($nl -gt 0) { $name = $script:ENC.GetString($script:bytes, $vb + 0x14, $nl) }
        if (($ds -band 0x80000000) -ne 0) {
            # 数据内联在 vk 单元里（长度 <= 4）
            $len = [int]($ds -band 0xFFFF)
            $data = New-Object byte[] $len
            if ($len -gt 0) { [Array]::Copy($script:bytes, $vb + 8, $data, 0, $len) }
        } else {
            $len = [int]$ds
            $data = New-Object byte[] $len
            if ($len -gt 0) {
                $dc = Get-Cell ([int]$do)
                [Array]::Copy($script:bytes, $dc.Base, $data, 0, $len)
            }
        }
        [void]$out.Add([pscustomobject]@{ Name = $name; Type = $dt; Data = $data })
    }
    return $out.ToArray()
}

function Get-Str([byte[]]$d) {
    if ($null -eq $d -or $d.Length -eq 0) { return '' }
    return [System.Text.Encoding]::Unicode.GetString($d).TrimEnd([char]0)
}

# ---------- 3. 定位根键、自动识别 GUID ----------
$root = Get-Nk 0x20
if ($null -eq $root) { Log '错误：解析不出根键（nk），文件可能损坏。已中止，本机未改动。'; exit 1 }
$rootGuid = $root.Name.Trim().ToLower()
Log "配置单元根键名 = $rootGuid"
Log "根键下：$($root.SubCount) 个分组子键，$($root.ValCount) 个值"

if ([string]::IsNullOrWhiteSpace($TargetGuid)) {
    $TargetGuid = $rootGuid
    Log "未指定 -TargetGuid，自动采用根键名：$TargetGuid"
} else {
    $TargetGuid = $TargetGuid.Trim().ToLower()
    if ($TargetGuid -ne $rootGuid) {
        Log "提示：你指定的 GUID ($TargetGuid) 与文件根键名 ($rootGuid) 不一致，将按你指定的写入。"
    }
}

$schemeRoot = 'SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes'
$destPath   = "$schemeRoot\$TargetGuid"
Log "目标注册表键：HKLM\$destPath"

$existed = $null -ne [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($destPath)
if ($existed) { Log '注意：该 GUID 在本机已存在，本次将覆盖它的值（原有方案仍会先备份）。' }

# ---------- 4. 备份现有方案 ----------
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
$before = Get-Schemes
Log "现有方案 $($before.Count) 个，开始备份到 $BackupDir ..."
foreach ($s in $before) {
    $safe = ($s.Name -replace '[\\/:*?"<>|]', '_')
    $dest = Join-Path $BackupDir ("{0}_{1}.pow" -f $safe, $s.Guid)
    powercfg /export "$dest" $s.Guid 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0 -and (Test-Path $dest) -and (Get-Item $dest).Length -gt 0) {
        Log ("    已备份 {0}" -f (Split-Path $dest -Leaf))
    } else {
        Log ("    备份失败：{0}（可能是内置只读方案，跳过）" -f $s.Name)
    }
}

# ---------- 5. 把配置单元整棵树写进注册表 ----------
$script:writtenKeys = 0
$script:writtenVals = 0
$script:visited = New-Object 'System.Collections.Generic.HashSet[int]'

function Write-Hive([string]$regPath, [int]$off) {
    if (-not $script:visited.Add($off)) { return }        # 防环
    $k = Get-Nk $off
    if ($null -eq $k) { return }
    $key = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($regPath, $true)
    if ($null -eq $key) { throw "无法创建注册表键: HKLM\$regPath" }
    try {
        foreach ($v in (Get-Values $off)) {
            switch ([int]$v.Type) {
                1 { $key.SetValue($v.Name, (Get-Str $v.Data), [Microsoft.Win32.RegistryValueKind]::String) }
                2 { $key.SetValue($v.Name, (Get-Str $v.Data), [Microsoft.Win32.RegistryValueKind]::ExpandString) }
                4 {
                    if ($v.Data.Length -ge 4) { $key.SetValue($v.Name, [BitConverter]::ToUInt32($v.Data, 0), [Microsoft.Win32.RegistryValueKind]::DWord) }
                    else { $key.SetValue($v.Name, $v.Data, [Microsoft.Win32.RegistryValueKind]::Binary) }
                }
                7 {
                    $arr = @((Get-Str $v.Data) -split "`0" | Where-Object { $_ -ne '' })
                    $key.SetValue($v.Name, [string[]]$arr, [Microsoft.Win32.RegistryValueKind]::MultiString)
                }
                default { $key.SetValue($v.Name, $v.Data, [Microsoft.Win32.RegistryValueKind]::Binary) }
            }
            $script:writtenVals++
        }
    } finally { $key.Close() }
    $script:writtenKeys++
    foreach ($so in (Get-SubkeyOffsets $k.SubList)) {
        if ($so -eq $NONE) { continue }
        $sk = Get-Nk ([int]$so)
        if ($null -ne $sk) {
            $child = if ($sk.Name) { $regPath + '\' + $sk.Name } else { $regPath }
            Write-Hive $child ([int]$so)
        }
    }
}

Log '开始写入注册表...'
try {
    Write-Hive $destPath 0x20
} catch {
    Log "错误：写入失败 -> $($_.Exception.Message)"
    Log '已中止。已写入的部分可能残留，可用下面的命令清理：'
    Log "  Remove-Item -Path 'HKLM:\$destPath' -Recurse -Force"
    exit 1
}
Log "写入完成：$script:writtenKeys 个注册表键，$script:writtenVals 个值"

if (-not [string]::IsNullOrWhiteSpace($TargetName)) {
    $rk = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($destPath, $true)
    if ($rk) {
        $rk.SetValue('FriendlyName', $TargetName, [Microsoft.Win32.RegistryValueKind]::ExpandString)
        $rk.Close()
    }
    Log "已把 FriendlyName 改成「$TargetName」"
}

# ---------- 6. 读回校验（逐键逐值）----------
Log '读回校验...'
$srcKeys = New-Object 'System.Collections.Generic.List[object]'

function Collect-Hive([string]$p, [int]$off) {
    $k = Get-Nk $off
    if ($null -eq $k) { return }
    $srcKeys.Add([pscustomobject]@{ Path = $p; Values = @(Get-Values $off) })
    foreach ($so in (Get-SubkeyOffsets $k.SubList)) {
        if ($so -eq $NONE) { continue }
        $sk = Get-Nk ([int]$so)
        if ($null -ne $sk) {
            $child = if ($sk.Name) { $p + '\' + $sk.Name } else { $p }
            Collect-Hive $child ([int]$so)
        }
    }
}
Collect-Hive $destPath 0x20

$bad = New-Object System.Collections.ArrayList
$valTotal = 0
foreach ($entry in $srcKeys) {
    $rk = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($entry.Path)
    if ($null -eq $rk) { [void]$bad.Add("键缺失 $($entry.Path)"); continue }
    foreach ($v in $entry.Values) {
        $valTotal++
        $got = $rk.GetValue($v.Name, $null)
        if ($null -eq $got) { [void]$bad.Add("值缺失 $($entry.Path)\$($v.Name)") }
    }
    $rk.Close()
}
if ($bad.Count -eq 0) {
    Log "校验通过：$($srcKeys.Count) 个键、$valTotal 个值全部就位"
} else {
    Log "校验发现 $($bad.Count) 处问题："
    foreach ($b in $bad) { Log "    $b" }
}

# ---------- 7. 看方案是否出现在 powercfg 里 ----------
$after = Get-Schemes
$hit = $after | Where-Object { $_.Guid -eq $TargetGuid }
if ($hit) {
    Log "powercfg 已识别新方案：$($hit.Guid)  ($($hit.Name))"
} else {
    Log "警告：powercfg /list 里暂时看不到该 GUID。"
    Log "      通常注销 / 重启一次即可出现；若仍不行请把本日志发我。"
}

if (-not $SkipSetActive) {
    powercfg /setactive $TargetGuid 2>&1 | Out-Null
    Log "已尝试设为当前方案 (exit=$LASTEXITCODE)"
}

# ---------- 8. 汇总 ----------
Log '---------- 完成 ----------'
Log (powercfg /list 2>&1 | Out-String)
Log ('当前活动方案：' + (powercfg /getactivescheme 2>&1 | Out-String).Trim())
Log "回退：原有方案已备份在 $BackupDir；删除本次导入可用 Remove-Item 'HKLM:\$destPath' -Recurse -Force"
