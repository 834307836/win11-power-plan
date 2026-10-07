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
tools/                          换机部署用（本仓库自己写的配套工具）
  ├─ import-plan.cmd            一键导入 .pow（双击，自动提权）
  └─ import-plan.ps1            导入 + 逐项写入 + 逐项校验
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

## 四、换机部署（新电脑 / 换 CPU）

换电脑、换 CPU 之后想原样复刻这套配置，按下面四步走。

### 第 1 步：导入电源方案

双击 `tools/import-plan.cmd`（自动提权），按提示：

1. 粘贴 `.pow` 的完整路径（例如 `D:\win11-power-plan\plans\amd笔记本.pow`）
2. 粘贴对应的 GUID（见上面第二节的 GUID 表）

脚本会依次做这些事，**不会删除你原有的任何方案**：

- 先把本机现有方案**全部备份**到 `tools\backup\`
- `powercfg /import` 导入
- 若 `powercfg` 不接受该文件，则以「均衡」为模板新建同 GUID 方案，再按 XML **逐项写入**
- **逐项读回校验**，把不一致的项全部列出来
- 设为当前方案

> `tools\backup\` 与 `tools\import-log.txt` 是运行时产物，已在 `.gitignore` 里排除。

### 第 2 步：装看门狗

双击 `watchdog/install-watchdog.cmd`，粘贴上一步那个 GUID。
装完脚本会自动做一次实测（故意切走 → 看是否被拉回）。

### 第 3 步：确认生效

`win + r` → `cmd` → `powercfg /list`，带 `*` 的那一行应该是你导入的方案。
控制面板 → 电源选项 里也能看到。

### 第 4 步（可选）：用组策略彻底锁死

`win + r` → `gpedit.msc` → 计算机配置 → 管理模板 → 系统 → 电源管理 →
**指定自定义活动电源方案** → 已启用 → 填入 GUID → 确定。

这条比看门狗更硬：其他程序调 `powercfg /setactive` 会被**直接忽略**。

> ⚠️ 两个「致郁专辑」是**注册表配置单元**格式，`tools/import-plan.cmd` 处理不了 ——
> 它会明确报错并中止（**不会动你现有的方案**）。请按原作者视频里的方式导入。

---

## 五、其他小技巧

**锁定电源方案（组策略方式）**：`win + r` → `gpedit.msc` →
计算机配置 → 管理模板 → 系统 → 电源管理 → 指定自定义活动电源方案 → 已启用 → 填入方案 GUID。

**查询当前方案 GUID**：`win + r` → `cmd` → `powercfg /list`

**删除电源方案**：`powercfg /delete <GUID>`（注意 `delete` 后面要有空格）

---

## 六、版权与免责声明

### 版权

- 本仓库收录的 **5 个电源计划文件（`plans/` 目录）版权归原作者所有**。
  - **原作者：B站博主「秋」**
  - **原视频**：<https://www.bilibili.com/video/BV1G3t96kEEr/>
- 本仓库仅做**整理归档**：文件未做任何修改，仓库**不从中获利**，也不声称拥有这些内容的任何权利。
- 本仓库**自行编写**的部分（`watchdog/`、`tools/`、`README.md`）以 **MIT 许可**发布，可自由使用、修改、再分发。
- **若原作者认为本仓库侵犯了您的权益，请通过 Issue 或 GitHub 联系我，我会立即下架相关内容。**

### 免责

- 电源方案会改动 CPU 频率、功耗墙、散热策略等底层行为，**可能影响稳定性、温度与续航**。
  请自行判断风险，重要工作场景慎用。
- 使用前请务必确认已备份原有电源方案（`tools/import-plan.cmd` 会自动备份）。
- 本仓库不对因使用这些配置而造成的任何直接或间接损失负责。
