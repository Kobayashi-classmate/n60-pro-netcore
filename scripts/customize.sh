#!/bin/bash
#
# File: scripts/customize.sh
# Description: 根据仓库中的纯文本清单定制固件
#
#   packages/feeds.txt        额外 feeds（所有固件共用）
#   packages/common.txt       所有固件都安装的软件包
#   packages/<profile>.txt    单个固件额外安装 / 移除（"-包名"）的软件包，优先级高于 common.txt
#   settings.txt              默认 IP、主机名、主题等设置
#
# 用法（在 openwrt 源码目录中执行）：
#   customize.sh feeds              # feeds 更新前：追加 feeds
#   customize.sh apply <profile>    # 配置载入后、make defconfig 前：写入设置和软件包
#   customize.sh check <profile>    # make defconfig 后：核对软件包，输出报告
#

set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
PKG_DIR="$ROOT/packages"
SETTINGS="$ROOT/settings.txt"
STATE="$ROOT/.customize.state"     # apply 生成、check 读取：每行 "<+|-|~> 包名"（~ 为自动附加的语言包）
REPORT="$ROOT/customize-report.md" # check 生成，供 Release 说明使用

warn() { echo "::warning::$*"; }

# 读取清单：去掉注释和空白，每行输出一个条目
read_list() {
	[ -f "$1" ] || return 0
	sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$' || true
}

valid_pkg() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]; }

cmd_feeds() {
	local line n=0
	while IFS= read -r line; do
		if [[ ! "$line" =~ ^src-(git|git-full|link|svn|cpy)[[:space:]] ]]; then
			warn "feeds.txt 中忽略无效行：$line"
			continue
		fi
		echo "$line" >> feeds.conf.default
		echo "添加 feed：$line"
		n=$((n + 1))
	done < <(read_list "$PKG_DIR/feeds.txt")
	echo "共添加 $n 个 feed"
}

# 读取 settings.txt 中的某个键
setting() {
	read_list "$SETTINGS" | sed -n "s/^$1[[:space:]]*=[[:space:]]*//p" | tail -n1
}

apply_settings() {
	local gen=package/base-files/files/bin/config_generate
	local lan_ip hostname theme

	lan_ip="$(setting lan_ip)"
	if [ -n "$lan_ip" ]; then
		if [[ "$lan_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
			# LEDE/ImmortalWrt 默认 192.168.1.1，237 源码默认 192.168.6.1
			sed -i -E "s/(ipad=\\\$\\{ipaddr:-\")192\.168\.[16]\.1\"/\1${lan_ip}\"/" "$gen"
			if grep -q "ipaddr:-\"${lan_ip}\"" "$gen"; then
				echo "默认 IP：$lan_ip"
			else
				warn "未能修改默认 IP，源码的 config_generate 格式可能已变化"
			fi
		else
			warn "settings.txt 中 lan_ip 格式无效：$lan_ip"
		fi
	fi

	hostname="$(setting hostname)"
	if [ -n "$hostname" ]; then
		if [[ "$hostname" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]]; then
			sed -i "s/\(set system\.@system\[-1\]\.hostname=\)'[^']*'/\1'${hostname}'/" "$gen"
			if grep -q "hostname='${hostname}'" "$gen"; then
				echo "主机名：$hostname"
			else
				warn "未能修改主机名，源码的 config_generate 格式可能已变化"
			fi
		else
			warn "settings.txt 中 hostname 格式无效：$hostname"
		fi
	fi

	theme="$(setting theme)"
	if [ -n "$theme" ]; then
		if [[ "$theme" =~ ^[a-z0-9_-]+$ ]]; then
			mkdir -p files/etc/uci-defaults
			cat > files/etc/uci-defaults/99-custom-theme <<-EOF
			#!/bin/sh
			[ -d /www/luci-static/${theme} ] || exit 0
			uci -q set luci.main.mediaurlbase='/luci-static/${theme}'
			uci -q commit luci
			exit 0
			EOF
			echo "+ luci-theme-${theme}" >> "$STATE"
			echo "默认主题：$theme"
		else
			warn "settings.txt 中 theme 格式无效：$theme"
		fi
	fi
}

cmd_apply() {
	local profile="$1" entry pkg
	local -A want=()
	local -a order=()

	[ -f .config ] || { echo "::error::当前目录没有 .config"; exit 1; }
	[ -f "$PKG_DIR/$profile.txt" ] || warn "未找到 packages/$profile.txt，只使用 common.txt"
	: > "$STATE"

	apply_settings

	# 主题包等由设置附加的条目
	while read -r entry pkg; do
		if [ -z "${want[$pkg]:-}" ]; then order+=("$pkg"); fi
		want[$pkg]="$entry"
	done < "$STATE"
	: > "$STATE"

	# common.txt 在前，固件清单在后，后出现的覆盖先出现的
	while IFS= read -r entry; do
		if [[ "$entry" == -* ]]; then pkg="${entry#-}"; entry="-"; else pkg="$entry"; entry="+"; fi
		if ! valid_pkg "$pkg"; then
			warn "忽略无效的软件包名：$pkg"
			continue
		fi
		if [ -z "${want[$pkg]:-}" ]; then order+=("$pkg"); fi
		want[$pkg]="$entry"
	done < <(read_list "$PKG_DIR/common.txt"; read_list "$PKG_DIR/$profile.txt")

	{
		echo ""
		echo "# ---- 以下由 scripts/customize.sh 根据 packages/ 生成 ----"
		for pkg in "${order[@]}"; do
			if [ "${want[$pkg]}" = "+" ]; then
				echo "CONFIG_PACKAGE_${pkg}=y"
			else
				echo "# CONFIG_PACKAGE_${pkg} is not set"
			fi
		done
	} >> .config

	for pkg in "${order[@]}"; do
		echo "${want[$pkg]} $pkg" >> "$STATE"
		# luci 应用自动附加中文语言包（不存在时静默跳过）
		if [[ "$pkg" == luci-app-* ]]; then
			local i18n="luci-i18n-${pkg#luci-app-}-zh-cn"
			if [ -n "${want[$i18n]:-}" ]; then continue; fi
			if [ "${want[$pkg]}" = "+" ]; then
				echo "CONFIG_PACKAGE_${i18n}=y" >> .config
				echo "~ $i18n" >> "$STATE"
			else
				echo "# CONFIG_PACKAGE_${i18n} is not set" >> .config
			fi
		fi
	done

	echo "已写入 $(grep -c '^[+-]' "$STATE" || true) 个软件包设置："
	grep '^[+-]' "$STATE" || true
}

cmd_check() {
	local profile="$1" entry pkg ok=0 missing=0
	local -a lines=() problems=()

	[ -f "$STATE" ] || { echo "::error::未找到 $STATE，请先执行 apply"; exit 1; }

	while read -r entry pkg; do
		case "$entry" in
		+)
			if grep -q "^CONFIG_PACKAGE_${pkg}=y" .config; then
				lines+=("- ✅ \`$pkg\`")
				ok=$((ok + 1))
			else
				problems+=("- ⚠️ \`$pkg\`：此源码中不存在或依赖不满足，已跳过")
				warn "$pkg 在此源码中不可用，已跳过"
				missing=$((missing + 1))
			fi
			;;
		-)
			if grep -q "^CONFIG_PACKAGE_${pkg}=y" .config; then
				problems+=("- ⚠️ \`$pkg\`：被其他软件包依赖，无法移除")
				warn "$pkg 被其他软件包依赖，无法移除"
			else
				lines+=("- ➖ \`$pkg\`（已移除）")
			fi
			;;
		esac
	done < "$STATE"

	{
		echo "### 软件包（$profile）"
		echo ""
		echo "已安装 $ok 个，跳过 $missing 个"
		echo ""
		if [ ${#problems[@]} -gt 0 ]; then
			printf '%s\n' "${problems[@]}"
			echo ""
		fi
		printf '%s\n' "${lines[@]}"
	} > "$REPORT"

	cat "$REPORT"
	[ -n "${GITHUB_STEP_SUMMARY:-}" ] && cat "$REPORT" >> "$GITHUB_STEP_SUMMARY"
	return 0
}

case "${1:-}" in
feeds) cmd_feeds ;;
apply) cmd_apply "${2:?缺少 profile}" ;;
check) cmd_check "${2:?缺少 profile}" ;;
*) echo "用法：$0 {feeds|apply <profile>|check <profile>}" >&2; exit 1 ;;
esac
