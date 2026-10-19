# XR30 Firmware Builder

CMCC XR30（MT7981B / NAND / MTK U-Boot 分区）OpenWrt 固件的 GitHub Actions 自动编译仓库。

源码来自 [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) 的 `25.12` 分支，
该分支已内置 `Device/cmcc_xr30-nand-mtkuboot`（`target/linux/mediatek/image/filogic-ext.mk`），
因此**无需任何补丁**即可编译。

## 设备信息

| 项 | 值 |
| --- | --- |
| 设备 ID | `cmcc_xr30-nand-mtkuboot` |
| 厂商 / 型号 | CMCC XR30 NAND |
| 变体 | MTK U-Boot layout |
| SoC | MediaTek MT7981B |
| 分区 | 128k block / 2048 page，UBI 布局 |
| 镜像大小上限 | 116736k |

## 触发方式

| 方式 | 说明 |
| --- | --- |
| 手动 | Actions → **Build XR30 Firmware** → Run workflow，可临时改源码地址/分支 |
| 推送 | 修改 `config/` 或 workflow 后推送到 `main` |
| 定时 | 每周五 18:00 UTC（即北京时间周六 02:00）自动构建 |
| Tag | 打 `v*` 标签时额外发布 GitHub Release |

## 产物

构建完成后在 Actions 运行的 **Artifacts** 中下载 `xr30-firmware-run<N>`，内含：

- `*cmcc_xr30-nand-mtkuboot-squashfs-factory.bin` — U-Boot / 首次刷机用
- `*cmcc_xr30-nand-mtkuboot-squashfs-sysupgrade.bin` — 系统内升级用
- `profiles.json` / `config.buildinfo` / `feeds.buildinfo` / `version.buildinfo` — 构建元数据

## 仓库结构

```
.
├── .github/workflows/build.yml   # 构建流程
├── config/xr30.defconfig         # 编译配置基线（来自 owbm 的 xr30 target）
└── scripts/build-local.sh        # 本地一键复现
```

## 配置来源

`config/xr30.defconfig` 导出自 owbm 框架中的 `targets/xr30` 实际编译配置
（`srcs/xr30/.config`，9334 行 / 311 个包）。修改包选择的推荐做法：

1. 在本地 owbm 工作区切到 xr30：`owbm change` → 选 `xr30`
2. `owbm target config`（menuconfig）调整
3. 把 `srcs/xr30/.config` 覆盖到本仓库的 `config/xr30.defconfig`
4. 提交推送，CI 自动重建

## 构建流程关键点

1. **先装自定义包，再 defconfig**。`kenzok-daed`（提供 `daed` / `luci-app-daede`）
   必须在 `make defconfig` 之前克隆进 `package/custom/`，否则这些包会被判为无效符号而从配置中丢弃。
2. `make download` 失败会自动退化为单线程重试。
3. `openwrt/dl` 走 Actions 缓存，重复构建可大幅缩短下载时间。

## 本地构建

```bash
./scripts/build-local.sh
```

可用环境变量覆盖：

```bash
SOURCE_URL=https://github.com/chasey-dev/immortalwrt-mt798x-rebase.git \
SOURCE_REF=25.12 \
JOBS=8 \
./scripts/build-local.sh
```

需要约 50GB 磁盘空间；首次全量编译在 4 核机器上约 1.5–3 小时。
