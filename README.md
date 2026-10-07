# Win11 电源计划合集（AMD / Intel · 台式 / 笔记本）

> ## 原作者与来源
>
> - **原作者**：B站博主「**秋**」
> - **原视频**：<https://www.bilibili.com/video/BV1G3t96kEEr/>
> - 视频与博主频道里还有**导入教程、延迟优化**等其他内容，动手前建议先完整看一遍视频。
>
> 本仓库只是**整理归档**，4 个电源计划的版权与功劳**全部归原作者所有**。
> 仓库里唯一由本仓库新增的东西是 `watchdog/`（电源方案看门狗）与 `tools/`（换机部署脚本）。

---

## 一、仓库内容

```
plans/                          4 个电源计划（原样收录，未做任何修改）
  ├─ amd笔记本.pow              笔记本 AMD
  ├─ lntel笔记本.pow            笔记本 Intel
  ├─ AMD致郁专辑.pow            台式 AMD（注册表配置单元格式）
  └─ lntel新.pow                台式 Intel
watchdog/                       电源方案看门狗（本仓库自己写的配套工具）
  ├─ powerplan-watchdog.ps1     看门狗本体
  ├─ install-watchdog.cmd       一键安装（双击，自动提权）
  ├─ install-watchdog.ps1       安装脚本
  ├─ watchdog-config.json       看门狗配置（目标方案 GUID）
  ├─ watchdog-pause.cmd         暂停看门狗（双击）
  └─ watchdog-resume.cmd        恢复看门狗（双击）
tools/                          换机部署用（本仓库自己写的配套工具）
  ├─ import-plan.cmd            XML 格式 .pow 一键导入（双击，自动提权）
  ├─ import-plan.ps1            XML：导入 + 逐项写入 + 逐项校验
  ├─ import-hive-plan.cmd       注册表配置单元格式 .pow 一键导入（双击，自动提权）
  └─ import-hive-plan.ps1       配置单元：直接解析并写入注册表 + 逐项校验
```

### 4 个方案的对应关系

| 文件 | 适用平台 | 格式 | 方案 GUID |
|---|---|---|---|
| `amd笔记本.pow` | 笔记本 AMD | UTF-8 XML | `a4720da6-34e3-4ad1-ba2c-b7cece8f506b` |
| `lntel笔记本.pow` | 笔记本 Intel | UTF-8 XML | `64877623-6e57-4bf4-8229-224ab01ed9f5` |
| `AMD致郁专辑.pow` | 台式 AMD | **注册表配置单元** | `d301d1cd-43d3-41ca-be87-b5859eab3cff` |
| `lntel新.pow` | 台式 Intel | UTF-8 XML | `ff1f4777-af38-40e7-80be-1664c5a71f34` |

> ⚠️ 三点提醒（文件都是原样保留，未做任何改动）：
>
> 1. 文件名里的 `lntel` 是博主原文写法（小写 L），不是 `Intel`，**未做改名**，以免和你手上的文件对不上。
> 2. `amd笔记本.pow` 与 `lntel笔记本.pow` 的 **MD5 完全相同**（`3efb417f26d0093ea4c4a07c06884894`），
>    即两份文件内容一模一样，只是文件名对应不同设备。仓库按博主原样保留两个文件名。
> 3. `lntel新.pow` 是**多方案合并导出**：一个文件里含 **7 个**方案 —— 其中 4 个正是上表这 4 台设备的方案，
>    另外 3 个是教程里没提的 GUID（`16f4b071` / `473f9451` / `f71f75f9`）。
>    **导入时务必带上 GUID 参数**，否则可能把多余方案一起建出来（用本仓库的 `tools/import-plan.cmd`
>    会自动把顺带建出来的多余方案清掉，只删本次新建的，不碰你原有的方案），见第二节。

### 整理记录：删掉了哪些重复

原始来源一共 5 个文件，其中存在重复，已按「每台设备只留一个」整理：

| 文件 | 判定依据 | 处理 |
|---|---|---|
| `lntel致郁专辑.pow` | 20 项设置与 `AMD致郁专辑.pow` **逐项完全相同**（只是根 GUID 不同 `ca9b706f` / `d301d1cd`），且博主教程里没有它 | 已移除 |
| `lntel新.pow` 里的 `16f4b071` / `473f9451` / `f71f75f9` | 教程之外的残留方案，其中后两个内容还彼此相同 | 文件保留不动，导入时**不要**选这三个 GUID |
| `lntel.pow`（另在桌面找到的 hive 文件，GUID `6a909681`） | 14 项设置与 `lntel新.pow` 里的台式 Intel（`ff1f4777`）**逐项完全相同**，属同一套设置换个 GUID | 未收录 |

判定方法不是比文件名，而是**逐项拆开数值比对**（XML 解析 `acindex`/`dcindex`，配置单元解析 `ACSettingIndex`/`DCSettingIndex`，再交叉比较）。

---

## 二、怎么导入

### 方式 A：双击脚本导入（推荐）

两个脚本都会自动提权、**先把本机现有方案全部备份**到 `tools\backup\`，并且**不删除任何原有方案**。

| 文件格式 | 双击哪个 |
|---|---|
| XML（`amd笔记本` / `lntel笔记本` / `lntel新`） | `tools/import-plan.cmd` |
| 注册表配置单元（`AMD致郁专辑`） | `tools/import-hive-plan.cmd` |

按提示粘贴 `.pow` 的完整路径，再粘贴对应 GUID（配置单元那个脚本可以直接回车，它会自己从文件里读出 GUID）。

导入后执行 `powercfg /list` 核对，带 `*` 号的是当前正在使用的方案。

### 方式 B：原生命令（仅限 XML 格式）

管理员身份打开 CMD：

```cmd
powercfg /import "C:\amd笔记本.pow" a4720da6-34e3-4ad1-ba2c-b7cece8f506b
```

博主教程里写的四条：

```cmd
powercfg /import "C:\lntel新.pow"  ff1f4777-af38-40e7-80be-1664c5a71f34
powercfg /import "C:\amd笔记本.pow" a4720da6-34e3-4ad1-ba2c-b7cece8f506b
powercfg /import "C:\lntel笔记本.pow" 64877623-6e57-4bf4-8229-224ab01ed9f5
```

> ⚠️ `AMD致郁专辑.pow` 的文件头是 `regf`（注册表配置单元），**`powercfg /import` 读不了**。
> 必须用 `tools/import-hive-plan.cmd`，或博主的 `电源计划导入器.exe`。

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

按文件格式双击对应的脚本（都会自动提权）：

| 文件 | 双击哪个 |
|---|---|
| `amd笔记本.pow` / `lntel笔记本.pow` / `lntel新.pow` | `tools/import-plan.cmd` |
| `AMD致郁专辑.pow` | `tools/import-hive-plan.cmd` |

按提示粘贴 `.pow` 的完整路径（例如 `D:\win11-power-plan\plans\amd笔记本.pow`）和对应的 GUID。

两个脚本都会做这些事，**不会删除你原有的任何方案**：

- 先把本机现有方案**全部备份**到 `tools\backup\`
- 把方案建出来（XML 走 `powercfg /import`；配置单元走原生注册表写入）
- 若 `powercfg` 不接受该文件，则以「均衡」为模板新建同 GUID 方案，再按 XML **逐项写入**
- **自动清掉本次导入顺带建出来的非目标方案**（有的 `.pow` 是多方案合并导出，`powercfg /import`
  可能把其它方案也建出来；只删本次新建的，原有方案一律不动）
- **逐项读回校验**，把不一致的项全部列出来
- 设为当前方案

> `tools\backup\` 与 `tools\import-log.txt` 是运行时产物，已在 `.gitignore` 里排除。
>
> ⚠️ 第一次用建议先在**非主力机器**上跑一遍，确认方案出现在 `powercfg /list` 里，再上主力机。

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

---

## 五、其他小技巧

**锁定电源方案（组策略方式）**：`win + r` → `gpedit.msc` →
计算机配置 → 管理模板 → 系统 → 电源管理 → 指定自定义活动电源方案 → 已启用 → 填入方案 GUID。

**查询当前方案 GUID**：`win + r` → `cmd` → `powercfg /list`

**删除电源方案**：`powercfg /delete <GUID>`（注意 `delete` 后面要有空格）

**导入前先看文件是什么格式**：文件头是 `<?xml` 的就是 XML；文件头是 `regf` 的就是注册表配置单元。

---

## 六、版权与免责声明

### 版权

- 本仓库收录的 **4 个电源计划文件（`plans/` 目录）版权归原作者所有**。
  - **原作者：B站博主「秋」**
  - **原视频**：<https://www.bilibili.com/video/BV1G3t96kEEr/>
- 本仓库仅做**整理归档**：文件未做任何修改，仓库**不从中获利**，也不声称拥有这些内容的任何权利。
- 本仓库**自行编写**的部分（`watchdog/`、`tools/`、`README.md`）以 **MIT 许可**发布，可自由使用、修改、再分发。
  - 许可全文见仓库根目录的 [`LICENSE`](LICENSE)。该文件开头写明了适用范围：**MIT 只管自行编写的部分，不覆盖 `plans/`**。
- **若原作者认为本仓库侵犯了您的权益，请通过 Issue 或 GitHub 联系我，我会立即下架相关内容。**

### 免责

- 电源方案会改动 CPU 频率、功耗墙、散热策略等底层行为，**可能影响稳定性、温度与续航**。
  请自行判断风险，重要工作场景慎用。
- 使用前请务必确认已备份原有电源方案（`tools/` 下的两个脚本都会自动备份）。
- 本仓库不对因使用这些配置而造成的任何直接或间接损失负责。
