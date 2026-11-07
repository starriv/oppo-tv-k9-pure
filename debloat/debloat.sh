#!/bin/sh
# ============================================================
# OPPO 电视（ColorOS TV）预装精简脚本
#
#   ./debloat.sh list                 查看清单
#   ./debloat.sh check                只读检查（默认，不动电视）
#   ./debloat.sh apply                执行卸载/停用（自动备份）
#   ./debloat.sh restore [备份目录]   恢复（默认最新备份）
#
# 选项：
#   --connect <IP[:PORT]>   先 adb connect（默认 5555）
#   --serial <SERIAL>       指定设备
#   --dry-run               只打印不执行（apply / restore 均支持）
#   --force                 跳过机型校验
#   -y                      跳过确认
# ============================================================
set -eu

VERSION="1.0"
HERE=$(cd "$(dirname "$0")" && pwd)
LISTS="${HERE}/lists"
BACKUPS="${HERE}/backups"
UNINSTALL_LIST="${LISTS}/uninstall.txt"
DISABLE_LIST="${LISTS}/disable.txt"

ADB=""
SERIAL=""
CONNECT=""
DRY=0
FORCE=0
YES=0
CMD="check"
ARG=""

# ---------- 输出 ----------
say()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
hr()   { printf '%s\n' "------------------------------------------------------------"; }

usage() {
  sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# ---------- 参数 ----------
while [ $# -gt 0 ]; do
  case "$1" in
    list|check|apply|restore) CMD="$1" ;;
    --connect) shift; CONNECT="${1:?--connect 需要参数}" ;;
    --serial)  shift; SERIAL="${1:?--serial 需要参数}" ;;
    --dry-run) DRY=1 ;;
    --force)   FORCE=1 ;;
    -y|--yes)  YES=1 ;;
    -h|--help) usage 0 ;;
    -*) die "未知选项: $1" ;;
    *)
      case "${CMD}" in
        restore) ARG="$1" ;;
        *) die "未知参数: $1" ;;
      esac
      ;;
  esac
  shift
done

# ---------- adb ----------
find_adb() {
  if [ -n "${ADB_BIN:-}" ]; then ADB="${ADB_BIN}"; fi
  if [ -z "${ADB}" ] && command -v adb >/dev/null 2>&1; then ADB=$(command -v adb); fi
  if [ -z "${ADB}" ]; then
    for c in "${ANDROID_HOME:-}/platform-tools/adb" "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
             "${HOME}/Library/Android/sdk/platform-tools/adb" "${HOME}/Android/Sdk/platform-tools/adb"; do
      [ -x "${c}" ] && { ADB="${c}"; break; }
    done
  fi
  [ -n "${ADB}" ] || die "找不到 adb。请安装 Android platform-tools，或用 ADB_BIN=/path/to/adb 指定"
  [ -x "${ADB}" ] || die "adb 不可执行: ${ADB}"
}

dev() { "${ADB}" -s "${SERIAL}" "$@"; }

pick_serial() {
  if [ -n "${CONNECT}" ]; then
    say "连接 ${CONNECT} ..."
    "${ADB}" connect "${CONNECT}" >/dev/null 2>&1 || true
  fi
  if [ -z "${SERIAL}" ]; then
    list=$("${ADB}" devices | awk 'NR>1 && $2=="device"{print $1}')
    n=$(printf '%s\n' "${list}" | grep -c . || true)
    if [ "${n}" -eq 0 ]; then
      die "没有已授权的设备。
  1) 电视：设置 → 系统 → 关于本机 → 设备型号，遥控器按 上、上、右、右、确认
  2) 开发者选项里打开 USB 调试
  3) 电脑执行：adb connect <电视IP>:5555  （或本脚本加 --connect <电视IP>）
  4) 电视上弹窗选「允许」"
    elif [ "${n}" -gt 1 ]; then
      die "检测到多个设备，请用 --serial 指定：
$(printf '%s\n' "${list}" | sed 's/^/  /')"
    fi
    SERIAL=${list}
  fi
}

# ---------- 设备信息 ----------
prop() { dev shell getprop "$1" 2>/dev/null | tr -d '\r' | head -1; }

device_check() {
  MODEL=$(prop ro.product.model)
  BRAND=$(prop ro.product.brand)
  REL=$(prop ro.build.version.release)
  SDK=$(prop ro.build.version.sdk)
  say "设备: ${BRAND} ${MODEL}  |  Android ${REL} (SDK ${SDK})"
  if [ "${FORCE}" -eq 0 ]; then
    case "${MODEL}" in
      OPPOCNM*|OPPO*) : ;;
      *) warn "机型不是 OPPO（${MODEL}）。清单按 ColorOS TV 生成，其他机型请先 check 确认，或加 --force" ;;
    esac
    case "${REL}" in
      9*) : ;;
      *) warn "Android 版本是 ${REL}，清单验证于 Android 9；不同版本包名可能不同，建议先 check" ;;
    esac
  fi
}

# ---------- 包状态 ----------
# 输出: installed | disabled | uninstalled | absent | unknown
state_of() {
  line=$(dev shell dumpsys package "$1" </dev/null 2>/dev/null | tr -d '\r' | grep -m1 'User 0:' || true)
  if [ -z "${line}" ]; then echo absent; return; fi
  case "${line}" in
    *installed=false*)              echo uninstalled ;;
    *enabled=2*|*enabled=3*|*enabled=4*) echo disabled ;;
    *installed=true*)               echo installed ;;
    *)                              echo unknown ;;
  esac
}

# 从清单文件读取包名
list_pkgs() {
  sed 's/\r$//' "$1" | grep -vE '^[[:space:]]*(#|$)' | sed -E 's/[[:space:]]+#.*$//' | awk '{print $1}'
}

# 危险包：无论如何都不许卸载
protected() {
  case "$1" in
    android|android.ext.*|com.android.*|com.mediatek.*) return 0 ;;
    com.heytap.tv.remote|com.heytap.tv.launcher|com.heytap.network|com.heytap.rom.service|\
    com.heytap.tvapiservice|com.heytap.msp.tv|com.heytap.tv.livetv|com.heytap.tv.market|\
    com.heytap.tv.search|com.heytap.tv.filebrowser|com.heytap.tv.videoplayer|\
    com.heytap.tv.musicplayer|com.sohu.inputmethod.sogou.tv) return 0 ;;
  esac
  return 1
}

# ---------- 命令 ----------
cmd_list() {
  say "== 卸载清单 ($(list_pkgs "${UNINSTALL_LIST}" | wc -l | tr -d ' ') 个) =="
  list_pkgs "${UNINSTALL_LIST}" | sed 's/^/  /'
  say ""
  say "== 停用清单 ($(list_pkgs "${DISABLE_LIST}" | wc -l | tr -d ' ') 个) =="
  list_pkgs "${DISABLE_LIST}" | sed 's/^/  /'
}

cmd_check() {
  device_check
  hr
  say "包状态（只读）："
  printf '  %-42s %s\n' "包名" "状态"
  for f in "${UNINSTALL_LIST}" "${DISABLE_LIST}"; do
    for p in $(list_pkgs "${f}"); do
      printf '  %-42s %s\n' "${p}" "$(state_of "${p}")"
    done
  done
  hr
  say "说明：check 不会改动电视。确认无误后执行 apply。"
}

cmd_apply() {
  device_check

  # 安全检查
  protected_hit=""
  for p in $(list_pkgs "${UNINSTALL_LIST}"); do
    if protected "${p}"; then protected_hit="${protected_hit} ${p}"; fi
  done
  [ -z "${protected_hit}" ] || die "卸载清单里含受保护的核心包，已中止:${protected_hit}"

  if [ "${DRY}" -eq 0 ] && [ "${YES}" -eq 0 ]; then
    say ""
    say "即将对电视执行："
    say "  卸载 $(list_pkgs "${UNINSTALL_LIST}" | wc -l | tr -d ' ') 个包（对当前用户）"
    say "  停用 $(list_pkgs "${DISABLE_LIST}" | wc -l | tr -d ' ') 个包"
    say "会自动先备份，可随时 restore。"
    printf '继续？[y/N] '
    read -r ans || ans=""
    case "${ans}" in y|Y|yes|YES) : ;; *) say "已取消"; exit 0 ;; esac
  fi

  # 备份（dry-run 不写）
  if [ "${DRY}" -eq 0 ]; then
  ts=$(date +%Y%m%d-%H%M%S)
  bdir="${BACKUPS}/${ts}"
  mkdir -p "${bdir}"
  {
    echo "model=$(prop ro.product.model)"
    echo "brand=$(prop ro.product.brand)"
    echo "android=$(prop ro.build.version.release)"
    echo "sdk=$(prop ro.build.version.sdk)"
    echo "build=$(prop ro.build.display.id)"
    echo "serial=${SERIAL}"
    echo "time=${ts}"
    echo "script_version=${VERSION}"
  } > "${bdir}/device.txt"
  dev shell pm list packages -u 2>/dev/null | sed 's/^package://' | tr -d '\r' | sort > "${bdir}/packages-all.txt"
  dev shell pm list packages -d 2>/dev/null | sed 's/^package://' | tr -d '\r' | sort > "${bdir}/packages-disabled-before.txt"
  : > "${bdir}/states.tsv"
  for p in $(list_pkgs "${UNINSTALL_LIST}") $(list_pkgs "${DISABLE_LIST}"); do
    s=$(state_of "${p}")
    printf '%s|%s\n' "${p}" "${s}" >> "${bdir}/states.tsv"
  done
  say "备份: ${bdir}"
  fi

  un_ok=0; un_skip=0; dis_ok=0; dis_skip=0; fail=0
  hr
  say "卸载（--user 0）："
  for p in $(list_pkgs "${UNINSTALL_LIST}"); do
    s=$(state_of "${p}")
    case "${s}" in
      installed|disabled)
        if [ "${DRY}" -eq 1 ]; then say "  [dry] uninstall ${p}"; un_ok=$((un_ok+1)); continue; fi
        out=$(printf 'pm uninstall --user 0 %s 2>&1\n' "${p}" | dev shell 2>&1 | tr -d '\r' || true)
        case "${out}" in
          Success*) printf '  OK   %s\n' "${p}"; un_ok=$((un_ok+1)) ;;
          *)        printf '  FAIL %-40s %s\n' "${p}" "${out}"; fail=$((fail+1)) ;;
        esac
        ;;
      uninstalled|absent)
        printf '  --   %s（已是 %s，跳过）\n' "${p}" "${s}"; un_skip=$((un_skip+1)) ;;
      *)
        printf '  ??   %s（状态未知，跳过）\n' "${p}"; un_skip=$((un_skip+1)) ;;
    esac
  done

  hr
  say "停用（--user 0）："
  for p in $(list_pkgs "${DISABLE_LIST}"); do
    s=$(state_of "${p}")
    case "${s}" in
      installed)
        if [ "${DRY}" -eq 1 ]; then say "  [dry] disable ${p}"; dis_ok=$((dis_ok+1)); continue; fi
        out=$(printf 'pm disable-user --user 0 %s 2>&1\n' "${p}" | dev shell 2>&1 | tr -d '\r' || true)
        case "${out}" in
          *disabled*) printf '  OK   %s\n' "${p}"; dis_ok=$((dis_ok+1)) ;;
          *)          printf '  FAIL %-40s %s\n' "${p}" "${out}"; fail=$((fail+1)) ;;
        esac
        ;;
      *) printf '  --   %s（%s，跳过）\n' "${p}" "${s}"; dis_skip=$((dis_skip+1)) ;;
    esac
  done

  hr
  say "完成：卸载 ${un_ok} / 跳过 ${un_skip} / 停用 ${dis_ok} / 跳过 ${dis_skip} / 失败 ${fail}"
  [ "${fail}" -eq 0 ] || warn "有失败项，请查看上方输出"
  if [ "${DRY}" -eq 1 ]; then
    say "（dry-run，未改动电视）"
  else
    say "回滚：./debloat.sh restore ${ts}"
  fi
}

cmd_restore() {
  if [ -n "${ARG}" ]; then
    bdir="${BACKUPS}/${ARG}"
    [ -d "${bdir}" ] || bdir="${ARG}"
  else
    bdir=$(ls -1 "${BACKUPS}" 2>/dev/null | sort | tail -1 || true)
    [ -n "${bdir}" ] && bdir="${BACKUPS}/${bdir}"
  fi
  [ -n "${bdir}" ] && [ -f "${bdir}/states.tsv" ] || die "找不到备份（${BACKUPS}）"

  say "使用备份: ${bdir}"
  [ -f "${bdir}/device.txt" ] && sed 's/^/  /' "${bdir}/device.txt"
  say ""

  n=0
  while IFS='|' read -r p s; do
    [ -n "${p}" ] || continue
    case "${s}" in
      installed|disabled)
        if [ "${DRY}" -eq 1 ]; then say "  [dry] restore ${p}（原状态 ${s}）"; continue; fi
        printf 'cmd package install-existing %s\n' "${p}" | dev shell >/dev/null 2>&1 || true
        if [ "${s}" = "disabled" ]; then
          printf 'pm disable-user --user 0 %s\n' "${p}" | dev shell >/dev/null 2>&1 || true
        fi
        say "  restored ${p}（${s}）"
        n=$((n+1))
        ;;
    esac
  done < "${bdir}/states.tsv"
  hr
  say "恢复完成：${n} 个"
  say "请手动关机再开机一次以完全生效（不要用 adb reboot，本机型会黑屏）"
}

# ---------- 入口 ----------
find_adb
pick_serial
case "${CMD}" in
  list)    cmd_list ;;
  check)   cmd_check ;;
  apply)   cmd_apply ;;
  restore) cmd_restore ;;
esac
