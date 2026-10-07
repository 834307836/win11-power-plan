# Win11 电源计划合集（AMD / Intel · 台式 / 笔记本）

> ## 原作者与来源
>
> - **原作者**：B站博主「**秋**」
> - **原视频**：<https://www.bilibili.com/video/BV1G3t96kEEr/>
> - 视频与博主频道里还有**导入教程、延迟优化**等其他内容，动手前建议先完整看一遍视频。
>
> 本仓库只是**整理归档**，5 个电源计划的版权与功劳**全部归原作者所有**。
> 仓库里唯一由本仓库新增的东西是 `watchdog/`（电源方案看门狗），用途是换机时能一键部署。

---

## 一、仓库内容

```
plans/                          5 个电源计划（原样收录，未做任何修改）
  ├─ amd笔记本.pow              AMD 笔记本
  ├─ lntel笔记本.pow            Intel 笔记本
  ├─ lntel新.pow                Intel 台式机
  ├─ AMD致郁专辑.pow            AMD 台式机（注册表配置单元格式）
  └─ lntel致郁专辑.pow          Intel 台式机（注册表配置单元格式）
watchdog/                       电源方案看门狗（本仓库自己写的配套工具）
  ├─ powerplan-watchdog.ps1     看门狗本体
  ├─ install-watchdog.cmd       一键安装（双击，自动提权）
  ├─ install-watchdog.ps1       安装脚本
  ├─ watchdog-config.json       看门狗配置（目标方案 GUID）
  ├─ watchdog-pause.cmd         暂停看门狗（双击）
  └─ watchdog-resume.cmd        恢复看门狗（双击）
```

### 5 个方案的对应关系

| 文件 | 适用平台 | 格式 | 备注 |
|---|---|---|---|
| `amd笔记本.pow` | AMD 笔记本 | UTF-8 XML | 日常主力方案 |
| `lntel笔记本.pow` | Intel 笔记本 | UTF-8 XML | 与 `amd笔记本.pow` **内容完全相同**（MD5 一致） |
| `lntel新.pow` | Intel 台式机 | UTF-8 XML | 设置项最全（2276 行） |
| `AMD致郁专辑.pow` | AMD 台式机 | **注册表配置单元** | 文件头为 `regf`，**不是** XML |
| `lntel致郁专辑.pow` | Intel 台式机 | **注册表配置单元** | 同上 |

> ⚠️ 两点提醒（都是原样保留，未改动）：
> 1. `amd笔记本.pow` 与 `lntel笔记本.pow` 的 **MD5 完全相同**（`3efb417f26d0093ea4c4a07c06884894`），
>    即两份文件内容一模一样。仓库仍按博主原样保留两个文件名。
> 2. 文件名里的 `lntel` 是博主原文写法（小写 L），不是 `Intel`，**未做改名**，以免与你手上的文件对不上。

---

## 二、怎么导入

### 方式 A：XML 格式的三个（`amd笔记本` / `lntel笔记本` / `lntel新`）

管理员身份打开 CMD，把 `.pow` 放到任意路径后执行：

```cmd
powercfg /import "C:\amd笔记本.pow" a4720da6-34e3-4ad1-ba2c-b7cece8f506b
```

不同方案的 GUID（来自博主教程）：

| 方案 | GUID |
|---|---|
| Intel 台式机（`lntel新.pow`） | `ff1f4777-af38-40e7-80be-1664c5a71f34` |
| AMD 台式机（`AMD致郁专辑.pow`） | `d301d1cd-43d3-41ca-be87-b5859eab3cff` |
| Intel 笔记本（`lntel笔记本.pow`） | `64877623-6e57-4bf4-8229-224ab01ed9f5` |
| AMD 笔记本（`amd笔记本.pow`） | `a4720da6-34e3-4ad1-ba2c-b7cece8f506b` |

导入后执行 `powercfg /list` 核对，带 `*` 号的是当前正在使用的方案。

### 方式 B：注册表配置单元格式的两个（`*致郁专辑`）

这两个文件的文件头是 `regf`（注册表配置单元），**不能**用 `powercfg /import`。
请按博主视频里的教程导入。

### 方式 C：可视化导入

博主配套提供了 `电源计划导入器.exe` 与 `PowerSettingsExplorer.exe`，
**本仓库未收录这两个 exe**（第三方可执行文件，请从博主处获取）。

---

## 三、看门狗：把电源方案锁住

### 为什么需要

联想电脑管家、`Fn+Q`、部分第三方优化工具会**偷偷把电源方案切走**，导致你导入的方案只生效几分钟。
看门狗每 5 分钟检查一次当前活动方案，只要不是目标方案就立刻切回去。

### 安装

1. 先按上面的方式把 `.pow` 导入系统。
2. 双击 `watchdog/install-watchdog.cmd`（会弹 UAC，点"是"）。
3. 脚本会列出本机所有电源方案，按提示粘贴**目标方案的 GUID** 并回车。
4. 安装完成后脚本会自动做一次实测：故意切到别的方案，再跑一次看门狗，验证能否被拉回。

安装后会自动注册计划任务 `PowerPlanWatchdog`，触发条件：

- 开机后 1 分钟
- 用户登录时
- 每 5 分钟重复一次

以 `SYSTEM` 身份、最高权限运行。

### 临时放行 / 恢复

| 想做什么 | 双击哪个 |
|---|---|
| 暂停看门狗（可以自由切换方案） | `watchdog/watchdog-pause.cmd` |
| 恢复看门狗（重新强制锁定） | `watchdog/watchdog-resume.cmd` |

原理：暂停 = 在看门狗目录下建一个 `watchdog-hold.txt`；恢复 = 删掉它。

### 查看运行情况

| 文件 | 作用 |
|---|---|
| `watchdog/watchdog-heartbeat.txt` | 每次运行都刷新一行，用来确认任务确实在跑 |
| `watchdog/watchdog-log.txt` | 每次"检测到被切走并切回"记一行（最多保留 300 行） |
| `watchdog/watchdog-install-log.txt` | 安装过程日志 |

### 卸载

```powershell
# 管理员 PowerShell
Unregister-ScheduledTask -TaskName 'PowerPlanWatchdog' -Confirm:$false
```

同时删掉 `watchdog/watchdog-hold.txt` 即可。

---

## 四、其他小技巧

**锁定电源方案（组策略方式）**：`win + r` → `gpedit.msc` →
计算机配置 → 管理模板 → 系统 → 电源管理 → 指定自定义活动电源方案 → 已启用 → 填入方案 GUID。

**查询当前方案 GUID**：`win + r` → `cmd` → `powercfg /list`

**删除电源方案**：`powercfg /delete <GUID>`（注意 `delete` 后面要有空格）

---

## 五、免责声明

- 本仓库仅做**归档整理**，5 个电源计划文件的版权归原作者（B站博主「秋」）所有。
- 电源方案会改动 CPU 频率、功耗墙、散热策略等底层行为，**可能影响稳定性、温度与续航**。
  请自行判断风险，重要工作场景慎用。
- 看门狗脚本为本仓库自行编写，MIT 许可，可自由修改。
