# 已知坑（务必先读）

## 1. 不要用 `adb reboot` ⚠️ 最严重

这台固件对 `adb reboot` 处理异常：执行后画面/背光不恢复，表现为**黑屏卡死**，只能遥控器关机再开机。

- 实测连续多次复现
- 需要重启时：**让用户手动关机再开机**
- 本仓库所有脚本都不调用重启

## 2. 「设置 → 系统更新」点击闪退

精简时卸载了 `com.heytap.tv.systemupgrade`，而设置里的入口硬编码指向它：

```
FATAL EXCEPTION: ActivityNotFoundException
{com.heytap.tv.systemupgrade/...SystemUpdateActivity}
```

- 只影响这一个菜单项，设置会自动重启，其他功能正常
- 想修：`adb shell cmd package install-existing com.heytap.tv.systemupgrade`

## 3. FlClash 无法开机自启

| 尝试 | 结果 |
|---|---|
| App 自身 `BOOT_COMPLETED` | ❌ APK 里没有这个接收器 |
| Android「始终开启的 VPN」（`always_on_vpn_app`） | ❌ 进程被拉起但 `tun0` 不建立，等待 60s 仍为 0 |

已撤销 `always_on_vpn_app`。**每次开机需手动打开 FlClash 并点播放。**

> 附注：设了 `always_on_vpn_app` 但 VPN 起不来时，可能导致电视「开着但断网」，这也是撤销它的原因。

## 4. 装不了 Google Play 商店

| 障碍 | 说明 |
|---|---|
| 无任何 Google 组件 | 没有 GSF / GMS，Play 商店无法登录 |
| 非认证设备 | 指纹不在 Google 白名单 |
| `/system` 只剩 56MB | 无法把 GMS 放进 priv-app |
| 无 root | 无法改只读分区 |

替代方案：**Aurora Store**（本仓库已包含），无需 GMS 下载 Play 应用。

## 5. 64 位 APK 装不上

设备是 32 位用户空间（`armeabi-v7a`）。`arm64-v8a`-only 的包会报
`INSTALL_FAILED_NO_MATCHING_ABIS`。

装前检查：

```sh
aapt2 dump badging app.apk | grep native-code
# 需要有 armeabi-v7a；只有 arm64-v8a 的装不上
```

实测装不上：哔哩哔哩HD 2.0.1、bilithings 2.10.2。

## 6. ColorOS 桌面包名白名单

只有 3 个包名允许声明 HOME：

```
com.heytap.tv.launcher
com.oneplus.tv.launcher2
com.oppo.tv.launcher2
```

其他包名装会报 `INSTALL_FAILED_DUPLICATE_PERMISSION: ... banned, because of launcher categories`。
另外开机还需要 `com.heytap.tv.launcher.category.MODERN_HOME` 类别，否则卡在开机动画。

## 7. 投屏 / 语音 / 智能家居已被精简

这些组件的包已卸载，相关功能**不可用**：

| 功能 | 涉及包 |
|---|---|
| 手机投屏 / 多屏 | `heycast`、`iot.castservice`、`optvmiracastservice`、`hpplay.happyplay.aw`、`iot.synergy` |
| 远场语音 | `speechassist.tv`、`tv.assistant.oppo` |
| 智能家居 | `smarthome.tv`、`tv.heythings`、`iot.relayplayer` |

恢复命令见 [restore.md](restore.md)。

## 8. 待机断网

电视待机（熄屏）会断开网络，ADB 和 Aurora 都会失效，唤醒后重连。

## 9. 写脚本时的两个坑

- **`adb shell` 会吞标准输入**：在 `while read` 循环里直接调用会只处理第一个元素。
  解决：`pm ... < /dev/null` 或改用 `for` 循环。
- **macOS bash 3.2 的多字节变量名 bug**：`"$p（中文）"` 会把中文首字节吞进变量名，
  报 `p?: unbound variable`。解决：一律写 `${p}`。

## 10. 系统分区几乎满

`/system` 98% 已用（剩 56MB）。任何需要写系统分区的方案（GMS 进 priv-app、Magisk、改系统 App）都不可行。

## 11. `pm disable-user` 不等于卸载

`disable-user` 后包仍 `installed=true`，会继续出现在应用列表和「安装未知应用」权限列表里。
要让它彻底消失，需 `pm uninstall --user 0`（仍可 `install-existing` 恢复）。
