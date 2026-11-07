# 备用安装包

这里放电视上要用的 APK。**APK 不入库**（`.gitignore` 已排除），用脚本下载：

```sh
./tools/fetch-apks.sh
```

| 文件 | 说明 | 能否自动下载 |
|---|---|---|
| `FlClash-0.9.3-android-armeabi-v7a.apk` | 代理客户端，32 位 | ✅ GitHub Release |
| `AuroraStore-4.8.4-fdroid.apk` | 免 GMS 的 Play 客户端 | ✅ F-Droid 官方源 |
| `BiliTV-v1.2.2-v7a.apk` | 第三方 B 站 TV 客户端，32 位 | ✅ GitHub Release |
| 酷狗音乐 TV | 官方包，32 位 | ❌ 需自行从应用商店/官网下载 |
| 爱奇艺 | Pad 版不适配 TV，实测已卸载 | ❌ |

校验值见 [SHA256SUMS.txt](SHA256SUMS.txt)。

## 装 APK 前必查 ABI

这台是 32 位（`armeabi-v7a`），只有 `arm64-v8a` 的包装不上：

```sh
aapt2 dump badging xxx.apk | grep native-code
```
