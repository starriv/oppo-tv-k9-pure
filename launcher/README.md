# Aerial 桌面（改包名版）构建说明

OPPO K9 用的是 ColorOS TV，它只允许下面 3 个包名声明 HOME：

```
com.heytap.tv.launcher
com.oneplus.tv.launcher2
com.oppo.tv.launcher2
```

官方 Aerial 的包名是 `app.orchard.tv`，直接装会被拒绝：

```
INSTALL_FAILED_DUPLICATE_PERMISSION: App installation is banned, because of launcher categories
```

所以需要改包名并重新签名。本目录的 `aerial-oppo-signed.apk` 就是成品。

| 项 | 值 |
|---|---|
| 基于 | Aerial 1.87 `aerial-standard.apk`（MIT） |
| 新包名 | `com.oneplus.tv.launcher2` |
| 启动 Activity | `app.orchard.tv.MainActivity`（类名保持不变） |
| SHA256 | `53fca64114776cbff006f59e44410cbe19db42163e3c0cfd5d71711eadf256cf` |
| 签名 | 本目录 `aerial.keystore`（storepass/keypass 均为 `android`） |

## 复刻步骤

### 1. 反编译

```sh
apktool d aerial-standard.apk -o std-src
# 若报 "Could not create framework directory"，把 framework 指到可写目录：
apktool d aerial-standard.apk -o std-src -p ./framework
```

### 2. 改 `AndroidManifest.xml`（4 处 + 1 处新增）

```xml
<!-- ① 包名 -->
<manifest package="com.oneplus.tv.launcher2" ...>

<!-- ② 自定义权限（不改会一打开就闪退：Permission ... is required） -->
<permission android:name="com.oneplus.tv.launcher2.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" .../>
<uses-permission android:name="com.oneplus.tv.launcher2.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"/>

<!-- ③④ 两个 ContentProvider authority（不改会装不进去：CONFLICTING_PROVIDER） -->
<provider android:authorities="com.oneplus.tv.launcher2.files" .../>
<provider android:authorities="com.oneplus.tv.launcher2.androidx-startup" .../>

<!-- ⑤ 新增：OPPO 开机认这个类别，缺了会卡在开机动画 -->
<intent-filter>
  <action android:name="android.intent.action.MAIN"/>
  <category android:name="android.intent.category.HOME"/>
  <category android:name="com.heytap.tv.launcher.category.MODERN_HOME"/>
  ...
```

> 组件类名是**绝对名**（`app.orchard.tv.MainActivity`），只改 `package` 属性不会破坏类解析。
> 但如果你用 apktool 的 `--rename-manifest-package`，要把相对名 `.Xxx` 一并处理，否则找不到类。

### 3. 重打包 + 签名

```sh
apktool b std-src -o aerial-oppo-unsigned.apk -p ./framework
zipalign -f -p 4 aerial-oppo-unsigned.apk aerial-oppo-aligned.apk
apksigner sign --ks aerial.keystore --ks-pass pass:android --key-pass pass:android \
  --out aerial-oppo-signed.apk aerial-oppo-aligned.apk
apksigner verify --print-certs aerial-oppo-signed.apk
```

### 4. 安装并设为桌面

```sh
adb install -r -g aerial-oppo-signed.apk
adb shell pm grant com.oneplus.tv.launcher2 android.permission.WRITE_SECURE_SETTINGS
adb shell appops set com.oneplus.tv.launcher2 SYSTEM_ALERT_WINDOW allow
adb shell appops set com.oneplus.tv.launcher2 WRITE_SETTINGS allow
adb shell cmd notification allow_listener \
  com.oneplus.tv.launcher2/app.orchard.tv.guard.RevivalListener
adb shell cmd package set-home-activity \
  com.oneplus.tv.launcher2/app.orchard.tv.MainActivity
```

### 5. 验证

```sh
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
# 期望：com.oneplus.tv.launcher2/app.orchard.tv.MainActivity

adb shell dumpsys window | grep mCurrentFocus
# 按主页键后应显示 app.orchard.tv.MainActivity
```

**必须手动关机再开机验证一次**，确认开机直接进 Aerial（不要用 `adb reboot`）。

## 建议：保留原桌面做兜底

不要卸载 `com.heytap.tv.launcher`，只停用：

```sh
adb shell pm disable-user --user 0 com.heytap.tv.launcher
```

万一 Aerial 出问题，`pm enable` + `set-home-activity` 就能切回去。

## 备选方案：guard 版

Aerial 还有一个 `guard` 版（不声明 HOME，用无障碍服务接管主页键）。它能用原包名直接装，
但**不是真正的 HOME**，也无法卸载原桌面，体验不如改包名方案。

## 许可

Aerial 为 MIT 许可，版权归 pengchujin 所有，见 [LICENSE-Aerial](LICENSE-Aerial)。
本目录的 APK 是基于其官方发布物的修改版（改包名 + 加类别 + 重新签名），遵守 MIT 条款分发。
