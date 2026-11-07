#!/bin/sh
# 下载本项目用到的 APK 到 apks/ 并校验 SHA256
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
APKS="$HERE/apks"
SUMS="$APKS/SHA256SUMS.txt"
mkdir -p "$APKS"

fetch() {
  name=$1; url=$2
  [ -f "$APKS/$name" ] && { echo "已存在: $name"; return 0; }
  echo "下载 $name ..."
  curl -fL --retry 3 --max-time 600 -o "$APKS/$name.part" "$url"
  mv "$APKS/$name.part" "$APKS/$name"
}

fetch FlClash-0.9.3-android-armeabi-v7a.apk \
  "https://github.com/chen08209/FlClash/releases/download/v0.9.3/FlClash-0.9.3-android-armeabi-v7a.apk"
fetch AuroraStore-4.8.4-fdroid.apk \
  "https://f-droid.org/repo/com.aurora.store_76.apk"
fetch BiliTV-v1.2.2-v7a.apk \
  "https://github.com/Hyper-Beast/BiliTV/releases/download/v1.2.2/v7a-1.2.2.apk"

echo
echo "== 校验 =="
fail=0
while read -r hash name; do
  [ -f "$APKS/$name" ] || { echo "  缺失 $name"; continue; }
  actual=$(shasum -a 256 "$APKS/$name" | awk '{print $1}')
  if [ "$actual" = "$hash" ]; then
    echo "  OK   $name"
  else
    echo "  FAIL $name"; fail=1
  fi
done < "$SUMS"
[ "$fail" -eq 0 ] || { echo "校验失败，请重下"; exit 1; }
echo
echo "完成。安装：adb install -r -g apks/<文件>"
