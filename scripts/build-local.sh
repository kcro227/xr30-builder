#!/usr/bin/env bash
# 本地复现 GitHub Actions 的构建流程
# 用法:
#   ./scripts/build-local.sh                       # 默认 full 档
#   VARIANT=daed-qmodem ./scripts/build-local.sh
#   VARIANT=openclash-qmodem ./scripts/build-local.sh
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."
ROOT="$(pwd)"

VARIANT="${VARIANT:-full}"

case "$VARIANT" in
  daed-qmodem)
    FEEDS="kenzok-daed qmodem"
    FRAGMENTS="qmodem daed"
    ;;
  openclash-qmodem)
    FEEDS="openclash qmodem"
    FRAGMENTS="qmodem openclash"
    ;;
  full)
    FEEDS="kenzok-daed openclash qmodem"
    FRAGMENTS="qmodem daed openclash common-apps"
    ;;
  *)
    echo "未知 VARIANT: $VARIANT" >&2
    echo "可选: daed-qmodem | openclash-qmodem | full" >&2
    exit 1
    ;;
esac

SOURCE_URL="${SOURCE_URL:-https://github.com/chasey-dev/immortalwrt-mt798x-rebase.git}"
SOURCE_REF="${SOURCE_REF:-25.12}"
JOBS="${JOBS:-$(nproc)}"
OPENWRT_DIR="${OPENWRT_DIR:-$ROOT/openwrt}"

declare -A URLS=(
  [kenzok-daed]="https://github.com/kenzok8/openwrt-daede.git"
  [openclash]="https://github.com/vernesong/OpenClash.git"
  [qmodem]="https://github.com/FuJr/QModem.git"
)

echo "==> 版本:   $VARIANT"
echo "==> 源码:   $SOURCE_URL ($SOURCE_REF)"
echo "==> 目录:   $OPENWRT_DIR"
echo "==> 并行:   $JOBS"

if [[ ! -d "$OPENWRT_DIR/.git" ]]; then
  git clone --depth 1 --branch "$SOURCE_REF" "$SOURCE_URL" "$OPENWRT_DIR"
fi

echo "==> 附加自定义包"
mkdir -p "$OPENWRT_DIR/package/custom"
for f in $FEEDS; do
  if [[ ! -d "$OPENWRT_DIR/package/custom/$f/.git" ]]; then
    echo "    clone $f -> ${URLS[$f]}"
    git clone --depth 1 "${URLS[$f]}" "$OPENWRT_DIR/package/custom/$f"
  fi
done

echo "==> feeds"
cd "$OPENWRT_DIR"
[[ -f feeds.conf.default ]] && cp -f feeds.conf.default feeds.conf
./scripts/feeds update -a
./scripts/feeds install -a

echo "==> 生成配置"
cp "$ROOT/config/xr30.defconfig" .config
for f in $FRAGMENTS; do
  echo "    叠加 $f"
  grep -vE '^[[:space:]]*#' "$ROOT/config/fragments/$f.config" | grep -vE '^[[:space:]]*$' >> .config
done
make defconfig
grep -E '^CONFIG_TARGET_PROFILE=' .config

echo "==> 下载依赖"
make download -j"$JOBS" V=s || make download -j1 V=s

echo "==> 编译"
make -j"$JOBS" V=s

echo
echo "==> 完成，产物："
find bin/targets -name '*xr30*' -type f -exec ls -lh {} \;
