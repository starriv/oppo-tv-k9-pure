#!/bin/sh
# 一键回滚：恢复被「对用户卸载」的包 + 启用被停用的包 + 桌面还给原生桌面 + 重启
ADB=${ADB:-adb}
D=$(dirname "$0")
# 1) 恢复卸载的 46 个（对系统应用会自动回落到 /system 出厂版本）
while read -r p; do
  "$ADB" shell cmd package install-existing "$p" >/dev/null 2>&1 && echo "restored $p"
done < "$D/uninstalled-for-user.txt"
# 2) 启用仍停用的（原桌面、mcs）
while read -r p; do
  "$ADB" shell pm enable "$p" >/dev/null 2>&1 && echo "enabled $p"
done < "$D/disabled-after.txt"
# 3) 桌面交还原生桌面
"$ADB" shell cmd package set-home-activity com.heytap.tv.launcher/com.oneplus.tv.launcher2.HomeLauncher >/dev/null 2>&1
"$ADB" reboot
