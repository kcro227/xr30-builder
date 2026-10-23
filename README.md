# XR30 Firmware Builder

CMCC XR30（MT7981B / NAND / MTK U-Boot 分区）OpenWrt 固件的 GitHub Actions 自动编译仓库，
一次构建产出 **三个插件组合版本**。

源码来自 [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) 的 `25.12` 分支，
该分支已内置 `Device/cmcc_xr30-nand-mtkuboot`（`target/linux/mediatek/image/filogic-ext.mk`），
因此**无需任何补丁**。

## 三个版本

| 版本 | 自定义插件 | 说明 |
| --- | --- | --- |
| `daed-qmodem` | daed + QModem | 精简：科学上网用 daed，移动网络用 QModem |
| `openclash-qmodem` | OpenClash + QModem | 精简：科学上网用 OpenClash，移动网络用 QModem |
| `full` | daed + OpenClash + QModem + 常用插件 | 全量：三个插件 + 15 个常用 LuCI 插件 |

三个版本共用同一份系统基线（`config/xr30.defconfig`，308 个包），差异只在追加的配置片段。

### 各版本的插件来源

| 组件 | 仓库 | 提供的主要包 |
| --- | --- | --- |
| daed | [kenzok8/openwrt-daede](https://github.com/kenzok8/openwrt-daede) | `daed`、`luci-app-daede` |
| OpenClash | [vernesong/OpenClash](https://github.com/vernesong/OpenClash) | `luci-app-openclash` |
| QModem | [FuJr/QModem](https://github.com/FuJr/QModem) | `luci-app-qmodem`（依赖 `qmodem`、`luci-compat`） |

### full 版本的常用插件

`luci-app-ttyd`、`luci-app-filetransfer`、`luci-app-nlbwmon`、`luci-app-wol`、
`luci-app-ddns`、`luci-app-sqm`、`luci-app-statistics`、`luci-app-upnp`、
`luci-app-zerotier`、`luci-app-frpc`、`luci-app-uhttpd`、`luci-app-samba4`、
`luci-app-argon-config`、`luci-app-netdata`、`luci-app-aria2`

> 若某个包在当前 feeds 中不存在，`make defconfig` 会自动丢弃它，**不会导致构建失败**；
> 但如果**核心插件**（daed / openclash / qmodem）被丢弃，工作流会直接报错退出。

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
| 手动 | Actions → **Build XR30 Firmware** → Run workflow，可选只构建某一档（`variants` 参数） |
| 推送 | 修改 `config/` 或 workflow 后推送到 `main`，三档全部重建 |
| 定时 | 每周五 18:00 UTC（北京时间周六 02:00） |
| Tag | 打 `v*` 标签时，三档产物合并发布到一个 GitHub Release |

`variants` 参数取值：`all`（默认）、`daed-qmodem`、`openclash-qmodem`、`full`。

## 产物

每个版本各自产出，Artifacts 名称分别为：

- `xr30-daed-qmodem-run<N>`
- `xr30-openclash-qmodem-run<N>`
- `xr30-full-run<N>`

每个 artifact 内含：

- `*cmcc_xr30-nand-mtkuboot-squashfs-factory.bin` — U-Boot / 首次刷机用
- `*cmcc_xr30-nand-mtkuboot-squashfs-sysupgrade.bin` — 系统内升级用
- `profiles.json` / `config.buildinfo` / `feeds.buildinfo` / `version.buildinfo`

## 仓库结构

```
.
├── .github/workflows/build.yml      # 三档矩阵构建
├── config/
│   ├── xr30.defconfig               # 系统基线（308 包，不含三个自定义插件）
│   └── fragments/
│       ├── qmodem.config            # 三档共用
│       ├── daed.config              # 第 1、3 档
│       ├── openclash.config         # 第 2、3 档
│       └── common-apps.config       # 仅第 3 档
└── scripts/build-local.sh           # 本地一键复现（默认 full）
```

## 调整插件选择

改 `config/fragments/*.config` 即可，工作流会自动叠加：

- 想让某一档加包 → 在对应 `fragments` 文件里加一行 `CONFIG_PACKAGE_xxx=y`
- 想改三档共用的基础系统 → 重新从 owbm 的 `srcs/xr30/.config` 导出 `config/xr30.defconfig`

## 构建流程关键点

1. **先装自定义包，再 defconfig**。三个仓库都在 `make defconfig` 之前克隆进 `package/custom/`，
   否则对应包会被判为无效符号而从配置中丢弃。
2. `make download` 失败会自动退化为单线程重试。
3. `openwrt/dl` 按版本分别缓存（`dl-xr30-<variant>-`），重复构建可大幅缩短下载时间。
4. 三档并行走 `fail-fast: false`，某一档失败不影响其他档。

## 本地构建

```bash
# 默认构建 full 档
./scripts/build-local.sh

# 指定档位
VARIANT=daed-qmodem ./scripts/build-local.sh
VARIANT=openclash-qmodem ./scripts/build-local.sh
```

需要约 50GB 磁盘空间；首次全量编译在 4 核机器上约 1.5–3 小时。
