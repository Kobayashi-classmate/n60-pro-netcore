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

所有固件默认只集成以下内容，保持精简（见 `packages/common.txt`）：

- 定时重启
- ttyd 终端
- omcproxy（组播代理）
- msd_lite（组播转换）
- UPnP
- AdGuardHome（仅 LuCI，核心需手动下载，见下文）

另外还包含 nano、tcpdump、SFTP、zram 等常用工具和 iptables 兼容扩展（见 `packages/common.txt`，不需要可直接删除）。

237 源码额外集成 MTK 闭源无线配置、Turbo ACC 硬件加速、eQoS 等平台插件；LEDE 和 ImmortalWrt 官方源码的 N60 Pro 使用开源 mt76 无线驱动，没有这些插件（见各固件清单）。

**未预装** OpenClash、PassWall 等科学上网插件，需要的话参考下方「定制固件内容」自行添加。

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

- **Releases**：标签格式为 `日期-固件标识`，说明中只附带源码仓库、提交链接、编译时间和软件包数量。每个固件独立保留最近 3 个 Release（可在入口文件中通过 `keep_releases` 调整）。
- **软件包清单 `<固件标识>-packages.md`**：随固件一起放在 Release 附件和 Artifact 中，包含清单中各软件包的安装结果（✅ 已安装 / ⚠️ 跳过或无法移除）以及固件中的全部软件包
- **Artifacts**：
  - `OpenWrt_firmware_*`：固件文件和软件包清单
  - `config_*`：`make defconfig` 后的完整配置 `full.config` 和精简配置 `seed.config`，便于核对和维护配置文件
- **编译摘要**：每次运行的 Summary 页面会列出各软件包是否安装成功

## 仓库结构

### 配置文件与脚本对应关系

| 固件 | 软件包清单 | 配置文件 | 前置脚本 | 后置脚本 | Workflow 入口 |
|------|------------|----------|----------|----------|---------------|
| 237 6.6 | `packages/237-6.6.txt` | `padavanonly-immortalwrt-mt798x-6.6.config` | `diy-part1.sh` | `diy-part5-6.6.sh` | `build-237-6.6.yml` |
| 237 5.4 | `packages/237-2410.txt` | `padavanonly-immortalwrt-mt798x-2410.config` | `diy-part1.sh` | `diy-part5-2410.sh` | `build-237-2410.yml` |
| ImmortalWrt | `packages/immortalwrt.txt` | `immortalwrt.config` | `diy-part1.sh` | `diy-part4.sh` | `build-immortalwrt.yml` |
| LEDE | `packages/lede.txt` | `LEDE.config` | `diy-LEDE.sh` | `diy-part2.sh` | `build-lede.yml` |

- **前置脚本**在 feeds 更新前执行：`diy-part1.sh` 为共用脚本（添加 AdGuardHome 源码），LEDE 使用单独的 `diy-LEDE.sh`
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

## 定制固件内容

**无需修改代码**，在 GitHub 网页上直接编辑以下文本文件并保存，然后重新运行对应的 workflow 即可。

### 软件包清单 `packages/`

| 文件 | 作用 |
|------|------|
| `packages/common.txt` | 所有固件都安装的软件包 |
| `packages/237-6.6.txt` | 仅 237 6.6 |
| `packages/237-2410.txt` | 仅 237 5.4 |
| `packages/immortalwrt.txt` | 仅 ImmortalWrt |
| `packages/lede.txt` | 仅 LEDE |
| `packages/feeds.txt` | 额外的软件源（第三方插件需要） |

规则：

- 一行一个包名，`#` 后为注释
- 包名前加 `-` 表示移除，例如 `-luci-app-upnp`
- 固件清单优先于 `common.txt`，可以在固件清单里去掉公共清单中的包
- `luci-app-*` 会自动附带中文语言包，无需单独填写
- 依赖会自动安装，只需填写插件本身（如只写 `luci-app-openclash`，不用写它依赖的核心和库）
- 某个源码里不存在的包会被跳过，并在编译摘要和软件包清单附件中提示，不会导致编译失败

### 增删软件包步骤

1. 在 GitHub 仓库页面打开要修改的清单文件（如 `packages/237-6.6.txt`），点击右上角铅笔图标进入编辑
2. 按需修改：

   | 想要 | 怎么改 | 示例 |
   |------|--------|------|
   | 安装清单里已注释的软件 | 删掉行首的 `#` | `#luci-app-homeproxy` → `luci-app-homeproxy` |
   | 不再安装某个软件 | 在行首加 `#`，或直接删掉这一行 | `luci-app-smartdns` → `#luci-app-smartdns` |
   | 安装清单里没有的软件 | 新增一行包名 | `luci-app-samba4` |
   | 去掉源码默认自带的软件 | 新增一行 `-包名` | `-luci-app-upnp` |
   | 某个固件不要公共清单里的软件 | 在该固件清单里加 `-包名` | 在 `lede.txt` 里加 `-luci-app-adguardhome` |
   | 所有固件都装 | 写在 `common.txt` 里 | |

3. 点击 **Commit changes** 保存
4. 到 **Actions** 页面运行对应固件的 workflow
5. 编译完成后检查结果：运行页面的 **Summary**，或 Release 附件 `<固件标识>-packages.md` 中会列出每个软件包是否安装成功（✅ 已安装 / ⚠️ 被跳过或无法移除）

> 注意：「在行首加 `#`」只是不再由清单安装。如果该软件是源码默认自带的，需要用 `-包名` 才能真正去掉。

### 如何查找包名

- 优先参考各固件清单中已注释的「可选软件」，包名均已核对
- 在 **Actions** 运行的 Artifacts 中下载 `config_<固件标识>`，其中 `full.config` 列出了该源码所有可选的软件包：`CONFIG_PACKAGE_包名=y` 为已安装，`# CONFIG_PACKAGE_包名 is not set` 为可选未安装；在 `full.config` 中搜不到的包，说明该源码中不存在
- 也可以到源码的 feeds 仓库中搜索，如 [immortalwrt/luci](https://github.com/immortalwrt/luci)、[immortalwrt/packages](https://github.com/immortalwrt/packages)；注意不同源码、不同分支的包名可能不同（如 `luci-app-alist` 已改名为 `luci-app-openlist`）

### 添加第三方插件

源码里没有的插件（如 PassWall2、Nikki、MosDNS）需要先添加软件源：

1. 在 `packages/feeds.txt` 中删掉对应源前面的 `#`，或按 `src-git 名称 仓库地址;分支` 的格式新增一行
2. 在固件清单中加入插件名
3. 运行编译，并在软件包清单中确认插件已安装

> `feeds.txt` 对所有固件生效，第三方源可能与部分源码不兼容，建议先单独编译一个固件验证。

### 默认设置 `settings.txt`

| 设置 | 说明 |
|------|------|
| `lan_ip` | 默认管理 IP（源码默认：LEDE/ImmortalWrt 为 192.168.1.1，237 为 192.168.6.1） |
| `hostname` | 主机名 |
| `theme` | 默认 LuCI 主题，如 `argon`，会自动安装对应主题包 |

默认 IP 和主机名只在首次刷机或恢复出厂时生效，保留配置升级不会覆盖已有设置。

### 进阶

- `.config` 配置文件：只包含设备、内核、编译选项和平台驱动等基础配置，一般无需修改（建议在本地 `make menuconfig` 后用 `./scripts/diffconfig.sh` 导出差异）
- 前置 / 后置脚本：需要执行自定义命令时修改
- 新增固件：复制一个 `build-*.yml` 并修改其中参数（含 `profile`），新建 `packages/<profile>.txt`，再在 `check-update.yml` 的 matrix 中添加对应条目

## 注意事项

- 目标设备为 **磊科 N60 Pro（MT7986）**，请勿刷入其他设备
- 从原厂或其他固件刷入时，注意分区布局和引导（U-Boot）是否匹配，不同源码之间切换可能需要先刷对应的 U-Boot
- 建议优先使用 **237 6.6** 版本

### 软件选择

- **闪存空间**：N60 Pro 为 128MB 闪存。Docker、qBittorrent、Transmission、Aria2、OpenList 等大型插件同时安装可能导致固件过大或刷机后剩余空间不足，这类插件也通常需要外接 USB 存储；下载工具建议只选一个
- **代理插件只选一个**：OpenClash、PassWall、HomeProxy、SSR Plus 等功能重复且会争抢防火墙规则和 DNS，不要同时启用
- **与硬件加速的冲突**：开启 Turbo ACC 硬件加速（237 源码）时，SQM 智能队列不生效，nlbwmon 流量统计不完整；SQM、nft-qos 和 eQoS 都是限速 / QoS 功能，一般只开一个
- **内核版本变化**：上游升级内核后，个别旧内核模块可能被移除。例如 LEDE 升级到 6.18 内核后，旧 NTFS 驱动 `kmod-fs-ntfs` 已无法编译，需改用 `kmod-fs-ntfs3`
- 部分插件需要第三方软件源（见各清单中的注释），需先在 `packages/feeds.txt` 中启用对应的源

### OpenClash 使用说明（237 6.6 默认集成）

- 与 AdGuardHome 相同，固件中不含 OpenClash 核心，首次使用需在 LuCI 的 OpenClash 页面中下载（Meta / mihomo 内核）
- 237 6.6 同时集成了 SmartDNS（作为上游 DNS，国内外分流并测速优选 IP）和 tcping（测试节点延迟）
- OpenClash、SmartDNS、AdGuardHome 都会处理 DNS，需要规划好转发顺序，避免端口冲突或解析环路。常见做法：dnsmasq → OpenClash → SmartDNS（或 AdGuardHome）；不使用的服务请关闭，或确保监听端口互不冲突

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
