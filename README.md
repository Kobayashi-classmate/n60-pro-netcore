# 磊科 Netcore N60 Pro 固件编译仓库

[![LICENSE](https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square&label=LICENSE)](LICENSE)

基于 [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) 模板，专为 **磊科 Netcore N60 Pro（MT7986 / Filogic）** 定制的 GitHub Actions 自动化编译仓库。

## 推荐固件优先级

| 优先级 | 固件 | 源码 | 说明 |
|--------|------|------|------|
| ⭐⭐⭐ | **237（padavanonly）6.6 内核** | [padavanonly/immortalwrt-mt798x-6.6](https://github.com/padavanonly/immortalwrt-mt798x-6.6) (`openwrt-24.10-6.6`) | **首选**，MTK 闭源无线驱动，无线表现最好 |
| ⭐⭐ | 237（padavanonly）5.4 内核 | [padavanonly/immortalwrt-mt798x-6.6](https://github.com/padavanonly/immortalwrt-mt798x-6.6) (`2410`) | 备用，部分情况下更稳定 |
| ⭐ | ImmortalWrt 官方 | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) (`openwrt-25.12`) | 开源驱动，干净稳定，长期维护 |
| - | LEDE | [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) (`master`) | 插件丰富，维护性一般 |

> 已移除 dailook-hanwckf（基于 OpenWrt 21.02，已过时）。

## 默认集成插件

所有固件默认只集成以下内容，保持精简：

- 定时重启
- ttyd 终端
- omcproxy（组播代理）
- msd_lite（组播转换）
- AdGuardHome（仅 LuCI，核心需手动下载，见下文）

此外，各源码会保留其平台自带的基础功能（如 UPnP，以及 237 源码的 MTK 无线配置、Turbo ACC 硬件加速、eQoS 等）。

**未预装** OpenClash、PassWall 等科学上网插件，需要的话请自行在对应 `.config` 中勾选，并在前置脚本中添加相应 feeds。

## 使用方法

1. Fork 本仓库
2. 进入 **Actions** 页面
3. 在左侧选择对应固件的 workflow：`237 mt798x 6.6`、`237 mt798x 2410 (5.4)`、`ImmortalWrt` 或 `LEDE`
4. 点击右侧 **Run workflow** 开始编译
5. 编译完成后在 **Releases** 或 Artifacts 中下载固件

编译时间大约 1–2 小时。

### 自动跟随上游更新

运行 **check-update** workflow 会检查 4 个上游源码的最新提交，**只触发有更新的固件**编译。
如需定时检查，取消 `.github/workflows/check-update.yml` 中 `schedule` 的注释即可。

### 产物说明

- **Releases**：标签格式为 `日期-固件标识`，说明中附带源码仓库、提交链接和编译时间。每个固件独立保留最近 3 个 Release（可在入口文件中通过 `keep_releases` 调整）。
- **Artifacts**：
  - `OpenWrt_firmware_*`：固件文件
  - `config_*`：`make defconfig` 后的完整配置 `full.config` 和精简配置 `seed.config`，便于核对和维护配置文件

## 仓库结构

### 配置文件与脚本对应关系

| 固件 | 配置文件 | 前置脚本 | 后置脚本 | Workflow 入口 |
|------|----------|----------|----------|---------------|
| 237 6.6 | `padavanonly-immortalwrt-mt798x-6.6.config` | `diy-part1.sh` | `diy-part5-6.6.sh` | `build-237-6.6.yml` |
| 237 5.4 | `padavanonly-immortalwrt-mt798x-2410.config` | `diy-part1.sh` | `diy-part5-2410.sh` | `build-237-2410.yml` |
| ImmortalWrt | `immortalwrt.config` | `diy-part1.sh` | `diy-part4.sh` | `build-immortalwrt.yml` |
| LEDE | `LEDE.config` | `diy-LEDE.sh` | `diy-part2.sh` | `build-lede.yml` |

- **前置脚本**在 feeds 更新前执行：`diy-part1.sh` 为共用脚本（添加 feeds 和 AdGuardHome 源码），LEDE 使用单独的 `diy-LEDE.sh`
- **后置脚本**在 feeds 安装后执行：移除不需要的默认软件包、添加组播（IPTV）防火墙规则等

### Workflow

| 文件 | 说明 |
|------|------|
| `.github/workflows/build.yml` | 公共编译流程（可复用 workflow），不直接运行 |
| `.github/workflows/build-*.yml` | 各固件入口，指定源码、分支、配置文件和脚本 |
| `.github/workflows/check-update.yml` | 上游更新检查，按固件分别触发编译 |

## AdGuardHome 使用说明

固件只包含 LuCI 界面，核心文件需手动安装（二选一）：

1. 在 LuCI 的 AdGuardHome 页面中在线下载 Linux_arm64 核心
2. 在 PC 上从 [AdGuardHome Releases](https://github.com/AdguardTeam/AdGuardHome/releases/) 下载 `linux_arm64` 版本，解压后将 `AdGuardHome` 上传至 `/usr/bin/AdGuardHome/`，权限设为 `0755`

## 自定义

如需添加插件或修改默认设置：

1. 修改对应的 `.config` 文件（建议在本地 `make menuconfig` 后用 `./scripts/diffconfig.sh` 导出差异）
2. 或在对应的前置 / 后置脚本中添加自定义命令（如修改默认 IP、主题、主机名，脚本中已附注释示例）
3. 重新运行对应的 workflow

如需新增一个固件：复制一个 `build-*.yml` 并修改其中参数，再在 `check-update.yml` 的 matrix 中添加对应条目。

## 注意事项

- 目标设备为 **磊科 N60 Pro（MT7986）**，请勿刷入其他设备
- 从原厂或其他固件刷入时，注意分区布局和引导（U-Boot）是否匹配，不同源码之间切换可能需要先刷对应的 U-Boot
- 建议优先使用 **237 6.6** 版本

## 致谢

- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
- [padavanonly/immortalwrt-mt798x-6.6](https://github.com/padavanonly/immortalwrt-mt798x-6.6)
- [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt)
- [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [GitHub Actions](https://github.com/features/actions)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [Mattraks/delete-workflow-runs](https://github.com/Mattraks/delete-workflow-runs)
- [dev-drprasad/delete-older-releases](https://github.com/dev-drprasad/delete-older-releases)
- [peter-evans/repository-dispatch](https://github.com/peter-evans/repository-dispatch)

## License

[MIT](LICENSE) © [**P3TERX**](https://p3terx.com)
