# 恢复指南

## 全部恢复（推荐）

```sh
./debloat/debloat.sh restore            # 用最新备份
./debloat/debloat.sh restore 20260101-120000
```

会按备份把「对用户卸载」的包 `install-existing`、把停用的包 `pm enable`。
完成后**手动关机再开机**（不要 `adb reboot`）。

## 单项恢复

### 系统更新菜单（修复设置闪退）

```sh
adb shell cmd package install-existing com.heytap.tv.systemupgrade
```

### 自带应用商店

```sh
adb shell cmd package install-existing com.heytap.tv.market
```

### 原桌面

```sh
adb shell pm enable com.heytap.tv.launcher
adb shell cmd package set-home-activity com.heytap.tv.launcher/com.oneplus.tv.launcher2.HomeLauncher
```

### 手机投屏 / 多屏互动

```sh
for p in com.heytap.tv.heycast com.heytap.iot.castservice com.heytap.optvmiracastservice \
         com.hpplay.happyplay.aw com.heytap.iot.synergy; do
  adb shell cmd package install-existing "$p"
done
```

### 远场语音

```sh
adb shell cmd package install-existing com.heytap.speechassist.tv
adb shell cmd package install-existing com.heytap.tv.assistant.oppo
```

### 智能家居

```sh
for p in com.heytap.smarthome.tv com.heytap.tv.heythings com.heytap.tv.iot.relayplayer; do
  adb shell cmd package install-existing "$p"
done
```

### 某个影视 App

```sh
adb shell cmd package install-existing com.xiaodianshi.tv.yst   # 云视听小电视
adb shell cmd package install-existing com.gitvvideo.oppo       # 银河奇异果
adb shell cmd package install-existing com.mgtv.tv              # 芒果 TV
```

## 恢复出厂设置

**最后手段**，会清空所有改动（含桌面、应用、代理配置）。恢复后电视回到出厂状态，
本仓库的所有精简也会一并还原。

## 注意

- 恢复系统包后回落到的是 `/system` 里的**出厂版本**，不是被卸载前的那份更新版本
- 恢复后请手动关机再开机，让 PackageManager 完整重扫
