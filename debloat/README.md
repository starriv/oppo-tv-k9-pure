# OPPO 电视（ColorOS TV）预装精简脚本

> 本工具是 [oppo-tv-k9-pure](../README.md) 项目的一部分。
> 从**项目根目录**运行：`./debloat/debloat.sh check`（或 `make check`）。
> 在 `debloat/` 目录内运行时才用 `./debloat.sh`。

一键卸载 / 停用 OPPO 智能电视的预装臃肿应用，**不需要 root**，全程可回滚。

> 实测机型：**OPPO 智能电视 K9 55 英寸（A55U1B01 / OPPOCNM632）**
> 系统：ColorOS TV 2.4（Android 9 / SDK 28，`PPR2.180905.006.A1`）
> 其他 OPPO 电视（K9 系列、R1/S1 等 ColorOS TV 机型）大概率通用，但请先跑 `check` 确认包名。

## 效果

- 卸载 **49** 个预装包（广告 / 推送 / 统计 / 诊断 / 工厂菜单 / 投屏 / 语音 / 智能家居 / 未用影视 App）
- 停用 **2** 个（原桌面兜底、system uid 推送服务）
- 实测收益：`/data` 释放约 **990 MB**，可用内存 +300 MB 量级，开机更快
- 包会从「应用列表」「权限列表」「安装未知应用」中彻底消失

## 前置条件

1. 电脑有 `adb`（Android platform-tools），或者用 `ADB_BIN=/path/to/adb` 指定

   ```sh
   # macOS
   brew install --cask android-platform-tools
   # Debian/Ubuntu
   sudo apt install android-tools-adb
   # Windows / 其他：https://developer.android.com/tools/releases/platform-tools
   ```
2. 电视开启 ADB：
   - 设置 → 系统 → 关于本机 → **设备型号**，遥控器按 **上、上、右、右、确认**
   - 设置 → 系统 → **开发者选项** → 打开 **USB 调试**
   - IP 在 设置 → 网络 → 已连接的网络 → 最下面
3. `adb connect <电视IP>:5555`，电视弹窗选「允许」

## 用法

```sh
# 1. 查看清单
./debloat.sh list

# 2. 只读检查（不动电视，推荐先跑）
./debloat.sh check
# 也可以一步连上再检查：
./debloat.sh check --connect 192.168.1.20

# 3. 执行（会先备份，并让你确认）
./debloat.sh apply

# 4. 回滚
./debloat.sh restore            # 用最新备份
./debloat.sh restore 20260101-120000   # 指定备份
```

常用选项：

| 选项 | 说明 |
|---|---|
| `--connect IP[:PORT]` | 先 `adb connect`，默认端口 5555 |
| `--serial SERIAL` | 多设备时指定 |
| `--dry-run` | 只打印不执行（apply / restore 都支持） |
| `--force` | 跳过机型 / 版本校验 |
| `-y` | 跳过确认 |

## 它做了什么

- 对 `lists/uninstall.txt` 里的包执行 `pm uninstall --user 0`
  - 只有「对当前用户卸载」，`/system` 里的 APK 不会被删（没有 root 删不掉）
  - 效果等同于卸载：不加载、不占内存、从所有列表消失
- 对 `lists/disable.txt` 里的包执行 `pm disable-user --user 0`
  - 原桌面保留做兜底；system uid 常驻服务卸载也杀不掉
- 执行前把每台设备的包状态写入 `backups/<时间戳>/states.tsv`

## 安全设计

- **默认只读**：`check` 不改任何东西；`apply` 前要求确认（`-y` 可跳过）
- **自动备份**：记录每个包改动前的状态（installed / disabled / uninstalled / absent）
- **受保护包拒删**：脚本内置黑名单（`android`、`com.android.*`、`com.mediatek.*`、遥控服务、应用商店、输入法等），即使你手改清单也会被拦下
- **幂等**：重复执行只处理需要处理的包，已卸载的直接跳过
- **不写分区、不解锁、不重启**：所有改动都在 `/data`，恢复出厂设置会自动还原

## 重要：不要用 `adb reboot`

这台 OPPO 固件对 `adb reboot` 处理异常——重启后画面/背光不恢复（黑屏卡死），**只能遥控器关机再开机**。
脚本从不调用重启；恢复后请手动关机再开机。

## 恢复原理

| 改动 | 恢复方式 |
|---|---|
| `pm uninstall --user 0` | `cmd package install-existing <包名>` |
| `pm disable-user` | `pm enable <包名>` |

`restore` 会自动按备份区分处理；部分 `/data` 预装包恢复后会回落到 `/system` 的出厂版本。

## 自定义清单

直接编辑 `lists/` 下的两个文件即可：

- 每行一个包名，`#` 开头是注释，行尾可跟注释
- 想保留某个 App（比如你要用芒果 TV），把对应行删掉或注释掉
- 不确定包名：打开目标 App，在电脑执行 `adb shell dumpsys activity top | grep TASK`

常见调整：

| 想保留的功能 | 在 `uninstall.txt` 里注释掉 |
|---|---|
| 手机投屏 / 多屏互动 | 「投屏 / 互联 / 配件」整段（含 `heycast`、`catchservice`、`mirrorcastservice`、`hpplay`） |
| 远场语音 / 语音搜片 | 「语音助手」段（`speechassist`、`assistant.oppo`） |
| 智能家居联动 | 「智能家居」段 |
| 某个影视 App（奇异果/芒果/云视听） | 「未使用的影视预装」段对应行 |

## 注意

脚本**不联网**、不下载任何东西、不需要 root、不写系统分区，只通过 `adb` 执行包管理命令。

## 免责声明

仅用于**你本人持有**的设备。改动可回滚，但请先跑 `check`、先读清单，理解每条的作用再执行。
不同机型/固件的包名可能不同，脚本会自动跳过不存在的包。
