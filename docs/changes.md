# 改动记录

## 1. 预装精简

分三批执行，先停用验证、后转「对用户卸载」。

| 批次 | 内容 | 数量 |
|---|---|---|
| Tier 1 | 广告/推送/统计/诊断/工厂菜单 | 15 |
| Tier 2 | 投屏/互联/语音/智能家居/未用影视/相册相机/OTA | 29 |
| Tier 3 | 手机遥控服务、AI 引擎、账号服务（其中遥控服务实测后**恢复**） | 4 |
| 追加 | 升级推送、OPPO 互联、未来电视登录 | 3 |
| **最终** | **对用户卸载 49 个** + 停用 2 个（原桌面、`com.heytap.mcs`） | 51 |

保留原则：
- **系统更新菜单会崩**（`com.heytap.tv.systemupgrade` 被卸载），已确认可接受
- **原桌面只停用不卸载**，作为 Aerial 的兜底
- `com.heytap.mcs` 是 system uid 常驻服务，卸载也杀不掉

### 实测数据

| 指标 | 改造前 | 改造后 |
|---|---|---|
| 已安装包 | 103 | **59** |
| `/data` 已用 | 2.3 GB | **1.3 GB**（释放 990 MB） |
| MemAvailable | 568 MB | **924 MB** |

## 2. 桌面替换：Aerial 1.87

ColorOS 只允许 3 个包名声明 HOME，因此需要改包名：

| 步骤 | 内容 |
|---|---|
| 反编译 | `apktool d aerial-standard.apk` |
| 改包名 | `app.orchard.tv` → `com.oneplus.tv.launcher2` |
| 改 4 处 | `package` 属性、`DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`、`files` authority、`androidx-startup` authority |
| 加类别 | HOME intent-filter 注入 `com.heytap.tv.launcher.category.MODERN_HOME`（OPPO 开机必需） |
| 重打包签名 | `apktool b` → `zipalign` → `apksigner`（自签名） |
| 安装 | `adb install -r -g` |
| 设为桌面 | `cmd package set-home-activity com.oneplus.tv.launcher2/app.orchard.tv.MainActivity` |
| 授权 | `WRITE_SECURE_SETTINGS`、`SYSTEM_ALERT_WINDOW`、`WRITE_SETTINGS`、通知监听 |

验证：手动关机再开机后直接进入 Aerial，`mCurrentFocus` 为 `app.orchard.tv.MainActivity`。
详见 [launcher/README.md](../launcher/README.md)。

## 3. 代理：FlClash 0.9.3

- 包：`FlClash-0.9.3-android-armeabi-v7a.apk`（SHA256 与官方 `SHA256SUMS` 一致）
- 订阅导入：用深度链接免去电视上打字
  ```sh
  adb shell am start -a android.intent.action.VIEW \
    -d "clash://install-config?url=<URL 编码后的订阅>" com.follow.clash
  ```
- 出站模式：**规则**（国内直连、国外走代理）
- VPN 验证：`tun0` 存在、`dumpsys connectivity` 出现 `type: VPN`、流量计数增长
- 内存：约 320–370 MB

## 4. 应用商店：Aurora Store 4.8.4

- 来源：F-Droid 官方仓库（`com.aurora.store_76.apk`）
- 匿名会话验证通过，可浏览/下载 Play 应用
- 依赖 FlClash（Google 域名需走代理），未开代理时连不上

## 5. 其他应用

| 应用 | 包名 | 结果 |
|---|---|---|
| 酷狗音乐 TV 2.1.2 | `com.kugou.android.tv` | ✅ 官方包，32 位兼容 |
| BiliTV 1.2.2 | `com.bili.tv.bili_tv_app` | ✅ 第三方开源，32 位构建 |
| 爱奇艺 Pad 17.10.5 | `com.qiyi.video.pad` | 试装后卸载（触屏布局 + 卡顿，不适配 TV） |
| 哔哩哔哩HD / bilithings | — | ❌ 仅 `arm64-v8a`，装不上 |

## 回滚

所有改动可用 `debloat/debloat.sh restore` 一键恢复；单项恢复见 [restore.md](restore.md)。
