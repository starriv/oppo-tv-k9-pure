# 设备事实

全部数据来自 `adb shell getprop` / `dumpsys` / `pm` 实测。

## 机型

| 项 | 值 |
|---|---|
| 零售型号 | OPPO 智能电视 K9 55 英寸（`A55U1B01`） |
| 产品码 | `OPPOCNM632` |
| 品牌 | OPPO |
| SoC | MediaTek **m7332**（MT9632 系列，4× Cortex-A55） |
| 内存 | 2 GB（`MemTotal 1,830,096 kB`） |
| 存储 | 16 GB（`/data` 可见 8.7 GB，`/system` 2.4 GB） |
| 上市 | 2021 年 5 月 |

## 系统

| 项 | 值 |
|---|---|
| 系统 | ColorOS TV 2.4 |
| Android | **9**（SDK 28） |
| 构建 | `PPR2.180905.006.A1` |
| 增量版本 | `2301131057`（2023-01-13） |
| 内核 | `4.9.118+` |
| ABI | **`armeabi-v7a`（仅 32 位用户空间）** |
| 安全补丁 | 2021-07-05 |
| 指纹 | `OPPO/OPPOCNM632/OPPOCNM632:9/PPR2.180905.006.A1/2301131057:user/release-keys` |
| verified boot | `orange` |
| `ro.adb.secure` | `1`（ADB 需授权弹窗） |

## 分区

```
/system  2.4G  已用 2.3G  剩 56M  (98%)   ← 无法再放东西，GMS 进不去
/data    8.7G  改造前已用 2.3G
```

## 电视特性

```
feature:android.hardware.type.television
feature:android.software.leanback
feature:android.software.leanback_only
```

## Google 服务状态

| 项 | 值 |
|---|---|
| `com.google.*` 包 | **一个都没有**（无 GSF / GMS / Play 商店） |
| ATV 底包残留 | `/system/etc/permissions/com.google.android.tv.installed.xml` 存在 |
| clientid | `ro.com.google.clientidbase = android-m7332-tv` |
| Play 认证 | 否（指纹不在白名单） |

结论：ROM 基于 Google 认证的 ATV 底包做国行裁剪，GMS 被整体移除。

## DRM

```
init.svc.vendor.drm-widevine-hal-1-1: running
init.svc.drm / mediadrm: running
```

Widevine HAL 在运行，但**安全等级（L1/L3）未确认**，Netflix 类应用未验证。

## ADB 开启方式（实测）

1. 设置 → 系统 → 关于本机 → **设备型号** → 遥控器按 **上、上、右、右、确定**
2. 设置 → 系统 → **开发者选项** → 打开 **USB 调试**
3. IP：设置 → 网络 → 已连接的网络 → 最下面
4. `adb connect <IP>:5555`，电视弹窗选「允许」

> 网络调试默认开启，无需配对码（Android 9）。
> **待机会断网**，ADB 随之中断，唤醒后重连即可。
