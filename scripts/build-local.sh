#!/usr/bin/env bash
# 本地复现 GitHub Actions 的构建流程
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."
ROOT="$(pwd)"

SOURCE_URL="${SOURCE_URL:-https://github.com/chasey-dev/immortalwrt-mt798x-rebase.git}"
SOURCE_REF="${SOURCE_REF:-25.12}"
FEED_REPO="${FEED_REPO:-https://github.com/kenzok8/openwrt-daede.git}"
JOBS="${JOBS:-$(nproc)}"
OPENWRT_DIR="${OPENWRT_DIR:-$ROOT/openwrt}"

echo "==> 源码: $SOURCE_URL ($SOURCE_REF)"
echo "==> 目标目录: $OPENWRT_DIR"
echo "==> 并行: $JOBS"

if [[ ! -d "$OPENWRT_DIR/.git" ]]; then
  git clone --depth 1 --branch "$SOURCE_REF" "$SOURCE_URL" "$OPENWRT_DIR"
fi

echo "==> 附加自定义包"
mkdir -p "$OPENWRT_DIR/package/custom"
if [[ ! -d "$OPENWRT_DIR/package/custom/kenzok-daed/.git" ]]; then
  git clone --depth 1 "$FEED_REPO" "$OPENWRT_DIR/package/custom/kenzok-daed"
fi

echo "==> feeds"
cd "$OPENWRT_DIR"
[[ -f feeds.conf.default ]] && cp -f feeds.conf.default feeds.conf
./scripts/feeds update -a
./scripts/feeds install -a

echo "==> 应用配置"
cp "$ROOT/config/xr30.defconfig" .config
make defconfig
grep -E '^CONFIG_TARGET_PROFILE=' .config

echo "==> 下载依赖"
make download -j"$JOBS" V=s || make download -j1 V=s

echo "==> 编译"
make -j"$JOBS" V=s

echo
echo "==> 完成，产物："
find bin/targets -name '*xr30*' -type f -exec ls -lh {} \;
