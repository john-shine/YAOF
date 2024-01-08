#!/bin/bash
clear

### 基础部分 ###
# 使用 O3 级别的优化
sed -i 's/Os/O3 -funsafe-math-optimizations -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections/g' include/target.mk
# 更新 Feeds
./scripts/feeds update -a
./scripts/feeds install -a
# 默认开启 Irqbalance
sed -i "s/enabled '0'/enabled '1'/g" feeds/packages/utils/irqbalance/files/irqbalance.config
# 移除 SNAPSHOT 标签
sed -i 's,-SNAPSHOT,,g' include/version.mk
sed -i 's,-SNAPSHOT,,g' package/base-files/image-config.in
# 维多利亚的秘密
rm -rf ./scripts/download.pl
rm -rf ./include/download.mk
wget -P scripts/ https://git.glan.space/github/immortalwrt.git/raw/openwrt-21.02/scripts/download.pl
wget -P include/ https://git.glan.space/github/immortalwrt.git/raw/openwrt-21.02/include/download.mk
sed -i '/unshift/d' scripts/download.pl
sed -i '/mirror02/d' scripts/download.pl
echo "net.netfilter.nf_conntrack_helper = 1" >>./package/kernel/linux/files/sysctl-nf-conntrack.conf

### 必要的 Patches ###
# offload bug fix
wget -qO - https://git.glan.space/github/openwrt-openwrt.git/pull/4849.patch | patch -p1
# TCP performance optimizations backport from linux/net-next
cp -f ../PATCH/backport/695-tcp-optimizations.patch ./target/linux/generic/backport-5.4/695-tcp-optimizations.patch
# introduce "le9" Linux kernel patches
cp -f ../PATCH/backport/695-le9i.patch ./target/linux/generic/hack-5.4/695-le9i.patch
# Patch arm64 型号名称
wget -P target/linux/generic/hack-5.4/ https://git.glan.space/github/immortalwrt.git/raw/openwrt-21.02/target/linux/generic/hack-5.4/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch
# Patch jsonc
patch -p1 <../PATCH/jsonc/use_json_object_new_int64.patch
# Patch dnsmasq
patch -p1 <../PATCH/dnsmasq/dnsmasq-add-filter-aaaa-option.patch
patch -p1 <../PATCH/dnsmasq/luci-add-filter-aaaa-option.patch
cp -f ../PATCH/dnsmasq/900-add-filter-aaaa-option.patch ./package/network/services/dnsmasq/patches/900-add-filter-aaaa-option.patch
# BBRv2
patch -p1 <../PATCH/BBRv2/openwrt-kmod-bbr2.patch
cp -f ../PATCH/BBRv2/693-Add_BBRv2_congestion_control_for_Linux_TCP.patch ./target/linux/generic/hack-5.4/693-Add_BBRv2_congestion_control_for_Linux_TCP.patch
wget -qO - https://git.glan.space/github/openwrt-openwrt.git/commit/cfaf039.patch | patch -p1
# CacULE
#wget -qO - https://git.glan.space/github/openwrt-NoTengoBattery.git/commit/7d44cab.patch | patch -p1
#wget https://git.glan.space/github/cacule-cpu-scheduler.git/raw/master/patches/CacULE/v5.4/cacule-5.4.patch -O ./target/linux/generic/hack-5.4/694-cacule-5.4.patch
# MuQSS
#cp -f ../PATCH/MuQSS/0001-MultiQueue-Skiplist-Scheduler-v0.196.patch ./target/linux/generic/hack-5.4/694-0001-MultiQueue-Skiplist-Scheduler-v0.196.patch
#cp -f ../PATCH/MuQSS/0002-MuQSS-Fix-build-error-on-config-leak.patch ./target/linux/generic/hack-5.4/694-0002-MuQSS-Fix-build-error-on-config-leak.patch
#cp -f ../PATCH/MuQSS/0003-Work-around-x86-only-llc-stuff.patch ./target/linux/generic/hack-5.4/694-0003-Work-around-x86-only-llc-stuff.patch
# BMQ
#cp -f ../PATCH/BMQ/01-bmq_v5.4-r2.patch ./target/linux/generic/hack-5.4/694-01-bmq_v5.4-r2.patch
# PDS
#cp -f ../PATCH/PDS/v5.4_undead-pds099o.patch ./target/linux/generic/hack-5.4/694-v5.4_undead-pds099o.patch
#wget https://git.glan.space/github/linux-tkg.git/raw/master/linux-tkg-patches/5.4/0005-glitched-pds.patch -O ./target/linux/generic/hack-5.4/694-0005-02-glitched-pds.patch
# UKSM
#cp -f ../PATCH/UKSM/695-uksm-5.4.patch ./target/linux/generic/hack-5.4/695-uksm-5.4.patch
# LRNG
cp -rf ../PATCH/LRNG/* ./target/linux/generic/hack-5.4/
echo '
CONFIG_LRNG=y
CONFIG_LRNG_JENT=y
' >>./target/linux/generic/config-5.4
# Grub 2
wget -qO - https://git.glan.space/github/openwrt-NoTengoBattery.git/commit/afed16a.patch | patch -p1
# Haproxy
rm -rf ./feeds/packages/net/haproxy
svn export https://git.glan.space/github/openwrt-packages.git/trunk/net/haproxy feeds/packages/net/haproxy
pushd feeds/packages
wget -qO - https://git.glan.space/github/QiuSimons-packages.git/commit/7ffbfbe.patch | patch -p1
popd
# OPENSSL
wget -P package/libs/openssl/patches/ https://git.glan.space/github/openssl.git/pull/11895.patch
wget -P package/libs/openssl/patches/ https://git.glan.space/github/openssl.git/pull/14578.patch
wget -P package/libs/openssl/patches/ https://git.glan.space/github/openssl.git/pull/16575.patch

### Fullcone-NAT 部分 ###
# Patch Kernel 以解决 FullCone 冲突
pushd target/linux/generic/hack-5.4
wget https://git.glan.space/github/coolsnowwolf-lede.git/raw/master/target/linux/generic/hack-5.4/952-net-conntrack-events-support-multiple-registrant.patch
popd
# Patch FireWall 以增添 FullCone 功能
mkdir package/network/config/firewall/patches
wget -P package/network/config/firewall/patches/ https://git.glan.space/github/immortalwrt.git/raw/master/package/network/config/firewall/patches/fullconenat.patch
wget -qO- https://git.glan.space/github/R2S-R4S-OpenWrt.git/raw/21.02/PATCHES/001-fix-firewall-flock.patch | patch -p1
# Patch LuCI 以增添 FullCone 开关
patch -p1 <../PATCH/firewall/luci-app-firewall_add_fullcone.patch
# FullCone 相关组件
svn export https://git.glan.space/github/coolsnowwolf-lede.git/trunk/package/lean/openwrt-fullconenat package/lean/openwrt-fullconenat
pushd package/lean/openwrt-fullconenat
patch -p2 <../../../../PATCH/firewall/fullcone6.patch
popd

### 获取额外的基础软件包 ###
# 更换为 ImmortalWrt Uboot 以及 Target
rm -rf ./target/linux/rockchip
svn export https://git.glan.space/github/immortalwrt.git/branches/openwrt-21.02/target/linux/rockchip target/linux/rockchip
rm -rf ./package/boot/uboot-rockchip
svn export https://git.glan.space/github/immortalwrt.git/branches/openwrt-21.02/package/boot/uboot-rockchip package/boot/uboot-rockchip
svn export https://git.glan.space/github/immortalwrt.git/branches/openwrt-21.02/package/boot/arm-trusted-firmware-rockchip-vendor package/boot/arm-trusted-firmware-rockchip-vendor
rm -rf ./package/kernel/linux/modules/video.mk
wget -P package/kernel/linux/modules/ https://git.glan.space/github/immortalwrt.git/raw/openwrt-21.02/package/kernel/linux/modules/video.mk
# ImmortalWrt Uboot TMP Fix
wget -qO- https://git.glan.space/github/immortalwrt.git/commit/433c93e.patch | patch -REp1
# Disable Mitigations
sed -i 's,rootwait,rootwait mitigations=off,g' target/linux/rockchip/image/mmc.bootscript
sed -i 's,rootwait,rootwait mitigations=off,g' target/linux/rockchip/image/nanopi-r2s.bootscript
sed -i 's,rootwait,rootwait mitigations=off,g' target/linux/rockchip/image/nanopi-r4s.bootscript
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-efi.cfg
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-iso.cfg
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-pc.cfg
# AutoCore
svn export https://git.glan.space/github/immortalwrt.git/branches/openwrt-21.02/package/emortal/autocore package/lean/autocore
sed -i 's/"getTempInfo" /"getTempInfo", "getCPUBench", "getCPUUsage" /g' package/lean/autocore/files/generic/luci-mod-status-autocore.json
rm -rf ./feeds/packages/utils/coremark
svn export https://git.glan.space/github/immortalwrt-packages.git/trunk/utils/coremark feeds/packages/utils/coremark
# DPDK
svn export https://git.glan.space/github/OpenWrt-Add.git/trunk/dpdk package/new/dpdk
# 更换 Nodejs 版本
rm -rf ./feeds/packages/lang/node
svn export https://git.glan.space/github/openwrt-node-packages.git/trunk/node feeds/packages/lang/node
sed -i '\/bin\/node/a\\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(1)/usr/bin/node' feeds/packages/lang/node/Makefile
rm -rf ./feeds/packages/lang/node-arduino-firmata
svn export https://git.glan.space/github/openwrt-node-packages.git/trunk/node-arduino-firmata feeds/packages/lang/node-arduino-firmata
rm -rf ./feeds/packages/lang/node-cylon
svn export https://git.glan.space/github/openwrt-node-packages.git/trunk/node-cylon feeds/packages/lang/node-cylon
rm -rf ./feeds/packages/lang/node-hid
svn export https://git.glan.space/github/openwrt-node-packages.git/trunk/node-hid feeds/packages/lang/node-hid
rm -rf ./feeds/packages/lang/node-homebridge
svn export https://git.glan.space/github/openwrt-node-packages.git/trunk/node-homebridge feeds/packages/lang/node-homebridge
rm -rf ./feeds/packages/lang/node-serialport
svn export https://git.glan.space/github/openwrt-node-packages.git/trunk/node-serialport feeds/packages/lang/node-serialport
rm -rf ./feeds/packages/lang/node-serialport-bindings
svn export https://git.glan.space/github/openwrt-node-packages.git/trunk/node-serialport-bindings feeds/packages/lang/node-serialport-bindings
rm -rf ./feeds/packages/lang/node-yarn
svn export https://git.glan.space/github/openwrt-node-packages.git/trunk/node-yarn feeds/packages/lang/node-yarn
ln -sf ../../../feeds/packages/lang/node-yarn ./package/feeds/packages/node-yarn
svn export https://git.glan.space/github/openwrt-node-packages.git/trunk/node-serialport-bindings-cpp feeds/packages/lang/node-serialport-bindings-cpp
ln -sf ../../../feeds/packages/lang/node-serialport-bindings-cpp ./package/feeds/packages/node-serialport-bindings-cpp
# R8168驱动
git clone -b master --depth 1 https://git.glan.space/github/openwrt-r8168.git package/new/r8168
patch -p1 <../PATCH/r8168/r8168-fix_LAN_led-for_r4s-from_TL.patch
# R8152驱动
svn export https://git.glan.space/github/immortalwrt.git/branches/master/package/kernel/r8152 package/new/r8152
sed -i 's,kmod-usb-net-rtl8152,kmod-usb-net-rtl8152-vendor,g' target/linux/rockchip/image/armv8.mk
# UPX 可执行软件压缩
sed -i '/patchelf pkgconf/i\tools-y += ucl upx' ./tools/Makefile
sed -i '\/autoconf\/compile :=/i\$(curdir)/upx/compile := $(curdir)/ucl/compile' ./tools/Makefile
svn export https://git.glan.space/github/coolsnowwolf-openwrt.git/branches/lede-17.01/tools/ucl tools/ucl
svn export https://git.glan.space/github/coolsnowwolf-openwrt.git/branches/lede-17.01/tools/upx tools/upx

### 获取额外的 LuCI 应用、主题和依赖 ###
# 更换 golang 版本
rm -rf ./feeds/packages/lang/golang
svn export https://git.glan.space/github/openwrt-packages.git/trunk/lang/golang feeds/packages/lang/golang
# 访问控制
svn export https://git.glan.space/github/coolsnowwolf-luci.git/trunk/applications/luci-app-accesscontrol package/lean/luci-app-accesscontrol
svn export https://git.glan.space/github/OpenWrt-Add.git/trunk/luci-app-control-weburl package/new/luci-app-control-weburl
# 广告过滤 Adbyby
svn export https://git.glan.space/github/coolsnowwolf-luci.git/trunk/applications/luci-app-adbyby-plus package/lean/luci-app-adbyby-plus
svn export https://git.glan.space/github/coolsnowwolf-lede.git/trunk/package/lean/adbyby package/lean/adbyby
# 广告过滤 AdGuard
#svn export https://git.glan.space/github/Lienol-openwrt.git/trunk/package/diy/luci-app-adguardhome package/new/luci-app-adguardhome
git clone https://git.glan.space/github/luci-app-adguardhome.git package/new/luci-app-adguardhome
rm -rf ./feeds/packages/net/adguardhome
svn export https://git.glan.space/github/openwrt-packages.git/trunk/net/adguardhome feeds/packages/net/adguardhome
sed -i '/\t)/a\\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(GO_PKG_BUILD_BIN_DIR)/AdGuardHome' ./feeds/packages/net/adguardhome/Makefile
sed -i '/init/d' feeds/packages/net/adguardhome/Makefile
# Argon 主题
git clone https://git.glan.space/github/luci-theme-argon.git package/new/luci-theme-argon
wget -P package/new/luci-theme-argon/htdocs/luci-static/argon/background/ https://git.glan.space/github/OpenWrt-Add.git/raw/master/5808303.jpg
rm -rf ./package/new/luci-theme-argon/htdocs/luci-static/argon/background/README.md
#pushd package/new/luci-theme-argon
#git checkout 3b15d06
#popd
git clone -b master --depth 1 https://git.glan.space/github/luci-app-argon-config.git package/new/luci-app-argon-config
# MAC 地址与 IP 绑定
svn export https://git.glan.space/github/immortalwrt-luci.git/trunk/applications/luci-app-arpbind feeds/luci/applications/luci-app-arpbind
ln -sf ../../../feeds/luci/applications/luci-app-arpbind ./package/feeds/luci/luci-app-arpbind
# 定时重启
svn export https://git.glan.space/github/coolsnowwolf-luci.git/trunk/applications/luci-app-autoreboot package/lean/luci-app-autoreboot
# Boost 通用即插即用
svn export https://git.glan.space/github/luci-app-boostupnp.git package/new/luci-app-boostupnp
rm -rf ./feeds/packages/net/miniupnpd
svn export https://git.glan.space/github/coolsnowwolf-packages.git/trunk/net/miniupnpd feeds/packages/net/miniupnpd
# ChinaDNS
git clone -b luci --depth 1 https://git.glan.space/github/openwrt-chinadns-ng.git package/new/luci-app-chinadns-ng
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/chinadns-ng package/new/chinadns-ng
# CPU 控制相关
svn export https://git.glan.space/github/immortalwrt-luci.git/trunk/applications/luci-app-cpufreq feeds/luci/applications/luci-app-cpufreq
ln -sf ../../../feeds/luci/applications/luci-app-cpufreq ./package/feeds/luci/luci-app-cpufreq
sed -i 's,1608,1800,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/cpufreq
sed -i 's,2016,2208,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/cpufreq
sed -i 's,1512,1608,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/cpufreq
svn export https://git.glan.space/github/OpenWrt-Add.git/trunk/luci-app-cpulimit package/lean/luci-app-cpulimit
svn export https://git.glan.space/github/immortalwrt-packages.git/trunk/utils/cpulimit feeds/packages/utils/cpulimit
ln -sf ../../../feeds/packages/utils/cpulimit ./package/feeds/packages/cpulimit
# 动态DNS
sed -i '/boot()/,+2d' feeds/packages/net/ddns-scripts/files/etc/init.d/ddns
svn export https://git.glan.space/github/kiddin9-packages/trunk/ddns-scripts-aliyun package/lean/ddns-scripts_dnspod
svn export https://git.glan.space/github/kiddin9-packages/trunk/ddns-scripts-dnspod package/lean/ddns-scripts_aliyun
svn export https://git.glan.space/github/OpenWrt_luci-app.git/trunk/luci-app-tencentddns package/lean/luci-app-tencentddns
svn export https://git.glan.space/github/kenzok8-packages.git/trunk/luci-app-aliddns feeds/luci/applications/luci-app-aliddns
ln -sf ../../../feeds/luci/applications/luci-app-aliddns ./package/feeds/luci/luci-app-aliddns
# Docker 容器（会导致 OpenWrt 出现 UDP 转发问题，慎用）
rm -rf ./feeds/luci/applications/luci-app-dockerman
svn export https://git.glan.space/github/luci-app-dockerman.git/trunk/applications/luci-app-dockerman feeds/luci/applications/luci-app-dockerman
rm -rf ./feeds/luci/collections/luci-lib-docker
svn export https://git.glan.space/github/luci-lib-docker.git/trunk/collections/luci-lib-docker feeds/luci/collections/luci-lib-docker
#sed -i 's/+docker/+docker \\\n\t+dockerd/g' ./feeds/luci/applications/luci-app-dockerman/Makefile
sed -i '/sysctl.d/d' feeds/packages/utils/dockerd/Makefile
# DiskMan
mkdir -p package/new/luci-app-diskman && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/applications/luci-app-diskman/Makefile -O package/new/luci-app-diskman/Makefile
mkdir -p package/new/parted && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/Parted.Makefile -O package/new/parted/Makefile
# Dnsfilter
git clone --depth 1 https://git.glan.space/github/luci-app-dnsfilter.git package/new/luci-app-dnsfilter
# Dnsproxy
svn export https://git.glan.space/github/immortalwrt-packages.git/trunk/net/dnsproxy feeds/packages/net/dnsproxy
ln -sf ../../../feeds/packages/net/dnsproxy ./package/feeds/packages/dnsproxy
sed -i '/CURDIR/d' feeds/packages/net/dnsproxy/Makefile
svn export https://git.glan.space/github/OpenWrt-Add.git/trunk/luci-app-dnsproxy package/new/luci-app-dnsproxy
# Edge 主题
git clone -b master --depth 1 https://git.glan.space/github/luci-theme-edge.git package/new/luci-theme-edge
# FRP 内网穿透
rm -rf ./feeds/luci/applications/luci-app-frps
rm -rf ./feeds/luci/applications/luci-app-frpc
rm -rf ./feeds/packages/net/frp
rm -f ./package/feeds/packages/frp
svn export https://git.glan.space/github/coolsnowwolf-luci.git/trunk/applications/luci-app-frps package/lean/luci-app-frps
svn export https://git.glan.space/github/coolsnowwolf-luci.git/trunk/applications/luci-app-frpc package/lean/luci-app-frpc
svn export https://git.glan.space/github/coolsnowwolf-packages.git/trunk/net/frp package/lean/frp
# IPSec
svn export https://git.glan.space/github/coolsnowwolf-luci.git/trunk/applications/luci-app-ipsec-server package/lean/luci-app-ipsec-server
# IPv6 兼容助手
svn export https://git.glan.space/github/coolsnowwolf-lede.git/trunk/package/lean/ipv6-helper package/lean/ipv6-helper
# Mosdns
#svn export https://git.glan.space/github/immortalwrt-packages.git/trunk/net/mosdns feeds/packages/net/mosdns
#ln -sf ../../../feeds/packages/net/mosdns ./package/feeds/packages/mosdns
#sed -i '/config.yaml/d' feeds/packages/net/mosdns/Makefile
#sed -i '/mosdns-init-openwrt/d' feeds/packages/net/mosdns/Makefile
svn export https://git.glan.space/github/openwrt-mos.git/trunk/mosdns package/new/mosdns
svn export https://git.glan.space/github/openwrt-mos.git/trunk/luci-app-mosdns package/new/luci-app-mosdns
svn export https://git.glan.space/github/openwrt-mos.git/trunk/v2ray-geodata package/new/v2ray-geodata
# 流量监管
svn export https://git.glan.space/github/coolsnowwolf-luci.git/trunk/applications/luci-app-netdata package/lean/luci-app-netdata
# 上网 APP 过滤
git clone -b master --depth 1 https://git.glan.space/github/OpenAppFilter.git package/new/OpenAppFilter
pushd package/new/OpenAppFilter
wget -qO - https://git.glan.space/github/OpenAppFilter-destan19.git/commit/9088cc2.patch | patch -p1
wget https://destan19.github.io/assets/oaf/open_feature/feature-06-18.cfg -O ./open-app-filter/files/feature.cfg
popd
# OLED 驱动程序
git clone -b master --depth 1 https://git.glan.space/github/luci-app-oled.git package/new/luci-app-oled
wget -qO - https://git.glan.space/github/openwrt-openwrt.git/commit/efc8aff.patch | patch -p1
# 花生壳内网穿透
svn export https://git.glan.space/github/dragino2.git/trunk/devices/common/diy/package/teasiu/luci-app-phtunnel package/new/luci-app-phtunnel
svn export https://git.glan.space/github/dragino2.git/trunk/devices/common/diy/package/teasiu/phtunnel package/new/phtunnel
svn export https://git.glan.space/github/dragino2-teasiu.git/trunk/package/teasiu/luci-app-oray package/new/luci-app-oray
# Passwall
#svn export https://git.glan.space/github/immortalwrt-luci.git/trunk/applications/luci-app-passwall package/new/luci-app-passwall
svn export https://git.glan.space/github/openwrt-passwall.git/branches/luci/luci-app-passwall package/new/luci-app-passwall
pushd package/new/luci-app-passwall
sed -i 's,default n,default y,g' Makefile
sed -i '/trojan-go/d' Makefile
sed -i '/v2ray-core/d' Makefile
sed -i '/v2ray-plugin/d' Makefile
sed -i '/xray-plugin/d' Makefile
sed -i '/shadowsocks-libev-ss-redir/d' Makefile
sed -i '/shadowsocks-libev-ss-server/d' Makefile
sed -i '/shadowsocks-libev-ss-local/d' Makefile
popd
wget -P package/new/luci-app-passwall/ https://git.glan.space/github/OpenWrt-Add.git/raw/master/move_2_services.sh
chmod -R 755 ./package/new/luci-app-passwall/move_2_services.sh
pushd package/new/luci-app-passwall
bash move_2_services.sh
popd
rm -rf ./feeds/packages/net/https-dns-proxy
svn export https://git.glan.space/github/Lienol-packages.git/trunk/net/https-dns-proxy feeds/packages/net/https-dns-proxy
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/tcping package/new/tcping
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/trojan-go package/new/trojan-go
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/brook package/new/brook
svn export https://git.glan.space/github/OpenWrt-Add.git/trunk/trojan-plus package/new/trojan-plus
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/ssocks package/new/ssocks
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/hysteria package/new/hysteria
# passwall2
svn export https://git.glan.space/github/openwrt-passwall2.git/trunk/luci-app-passwall2 package/new/luci-app-passwall2
wget -P package/new/luci-app-passwall2/ https://git.glan.space/github/OpenWrt-Add.git/raw/master/move_2_services.sh
chmod -R 755 ./package/new/luci-app-passwall2/move_2_services.sh
pushd package/new/luci-app-passwall2
bash move_2_services.sh
popd
pushd package/new/luci-app-passwall2
sed -i 's,default n,default y,g' Makefile
sed -i 's,+v2ray-core ,,g' Makefile
sed -i '/v2ray-plugin/d' Makefile
sed -i '/shadowsocks-libev-ss-redir/d' Makefile
sed -i '/shadowsocks-libev-ss-server/d' Makefile
sed -i '/shadowsocks-libev-ss-local/d' Makefile
popd
# qBittorrent 下载
svn export https://git.glan.space/github/coolsnowwolf-luci.git/trunk/applications/luci-app-qbittorrent package/lean/luci-app-qbittorrent
svn export https://git.glan.space/github/coolsnowwolf-packages.git/trunk/net/qBittorrent-static package/lean/qBittorrent-static
svn export https://git.glan.space/github/coolsnowwolf-packages.git/trunk/net/qBittorrent package/lean/qBittorrent
svn export https://git.glan.space/github/coolsnowwolf-packages.git/trunk/libs/qtbase package/lean/qtbase
svn export https://git.glan.space/github/coolsnowwolf-packages.git/trunk/libs/qttools package/lean/qttools
svn export https://git.glan.space/github/coolsnowwolf-packages.git/trunk/libs/rblibtorrent package/lean/rblibtorrent
# 清理内存
svn export https://git.glan.space/github/coolsnowwolf-luci.git/trunk/applications/luci-app-ramfree package/lean/luci-app-ramfree
# ServerChan 微信推送
git clone -b master --depth 1 https://git.glan.space/github/luci-app-serverchan.git package/new/luci-app-serverchan
# SmartDNS
rm -rf ./feeds/packages/net/smartdns
svn export https://git.glan.space/github/Lienol-packages.git/trunk/net/smartdns feeds/packages/net/smartdns
rm -rf ./feeds/luci/applications/luci-app-smartdns
svn export https://git.glan.space/github/immortalwrt-luci.git/branches/openwrt-18.06/applications/luci-app-smartdns feeds/luci/applications/luci-app-smartdns
# ShadowsocksR Plus+ 依赖
rm -rf ./feeds/packages/net/kcptun
rm -rf ./feeds/packages/net/shadowsocks-libev
rm -rf ./feeds/packages/net/xray-core
svn export https://git.glan.space/github/coolsnowwolf-packages.git/trunk/net/shadowsocks-libev package/lean/shadowsocks-libev
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/shadowsocksr-libev package/lean/shadowsocksr-libev
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/pdnsd-alt package/lean/pdnsd
svn export https://git.glan.space/github/coolsnowwolf-lede.git/trunk/package/lean/srelay package/lean/srelay
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/microsocks package/lean/microsocks
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/dns2socks package/lean/dns2socks
svn export https://git.glan.space/github/coolsnowwolf-packages.git/trunk/net/redsocks2 package/lean/redsocks2
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/ipt2socks package/lean/ipt2socks
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/trojan package/lean/trojan
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/tcping package/lean/tcping
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/trojan-go package/lean/trojan-go
svn export https://git.glan.space/github/helloworld.git/trunk/simple-obfs package/lean/simple-obfs
svn export https://git.glan.space/github/helloworld.git/trunk/naiveproxy package/lean/naiveproxy
svn export https://git.glan.space/github/helloworld.git/trunk/v2ray-core package/lean/v2ray-core
svn export https://git.glan.space/github/helloworld.git/trunk/xray-core package/lean/xray-core
svn export https://git.glan.space/github/helloworld.git/trunk/v2ray-plugin package/lean/v2ray-plugin
svn export https://git.glan.space/github/helloworld.git/trunk/xray-plugin package/lean/xray-plugin
svn export https://git.glan.space/github/openwrt-passwall.git/trunk/shadowsocks-rust feeds/packages/net/shadowsocks-rust
#svn export https://git.glan.space/github/immortalwrt-packages.git/trunk/net/shadowsocks-rust feeds/packages/net/shadowsocks-rust
sed -i '/Build\/Compile/a\\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $$(PKG_BUILD_DIR)/$(component)' feeds/packages/net/shadowsocks-rust/Makefile
ln -sf ../../../feeds/packages/net/shadowsocks-rust ./package/feeds/packages/shadowsocks-rust
svn export https://git.glan.space/github/immortalwrt-packages.git/trunk/net/kcptun feeds/packages/net/kcptun
ln -sf ../../../feeds/packages/net/kcptun ./package/feeds/packages/kcptun
# ShadowsocksR Plus+
svn export https://git.glan.space/github/helloworld.git/trunk/luci-app-ssr-plus package/lean/luci-app-ssr-plus
rm -rf ./package/lean/luci-app-ssr-plus/po/zh_Hans
pushd package/lean
#wget -qO - https://git.glan.space/github/helloworld.git/pull/656.patch | patch -p1
wget -qO - https://git.glan.space/github/helloworld.git/commit/5bbf6e7.patch | patch -p1
wget -qO - https://git.glan.space/github/helloworld.git/commit/ea3b4bd.patch | patch -p1
popd
pushd package/lean/luci-app-ssr-plus
sed -i 's,default n,default y,g' Makefile
sed -i '/trojan-go/d' Makefile
sed -i '/v2ray-core/d' Makefile
sed -i '/v2ray-plugin/d' Makefile
sed -i '/xray-plugin/d' Makefile
sed -i '/shadowsocks-libev-ss-redir/d' Makefile
sed -i '/shadowsocks-libev-ss-server/d' Makefile
sed -i '/shadowsocks-libev-ss-local/d' Makefile
sed -i '/result.encrypt_method/a\result.fast_open = "1"' root/usr/share/shadowsocksr/subscribe.lua
sed -i 's,ispip.clang.cn/all_cn,gh.404delivr.workers.dev/https://git.glan.space/github/Chnroute.git/raw/master/dist/chnroute/chnroute,' root/etc/init.d/shadowsocksr
sed -i 's,YW5vbnltb3Vz/domain-list-community/release/gfwlist.txt,Loyalsoldier/v2ray-rules-dat/release/gfw.txt,' root/etc/init.d/shadowsocksr
sed -i '/Clang.CN.CIDR/a\o:value("https://gh.404delivr.workers.dev/https://git.glan.space/github/Chnroute.git/raw/master/dist/chnroute/chnroute.txt", translate("QiuSimons/Chnroute"))' luasrc/model/cbi/shadowsocksr/advanced.lua
popd
# v2raya
git clone --depth 1 https://git.glan.space/github/luci-app-v2raya.git package/new/luci-app-v2raya
svn export https://git.glan.space/github/openwrt-packages.git/trunk/net/v2raya feeds/packages/net/v2raya
ln -sf ../../../feeds/packages/net/v2raya ./package/feeds/packages/v2raya
# socat
svn export https://git.glan.space/github/Lienol-package.git/trunk/luci-app-socat package/new/luci-app-socat
# 订阅转换
svn export https://git.glan.space/github/immortalwrt-packages.git/trunk/net/subconverter feeds/packages/net/subconverter
wget https://git.glan.space/github/immortalwrt-packages.git/raw/b7b4499/net/subconverter/Makefile -O feeds/packages/net/subconverter/Makefile
mkdir -p ./feeds/packages/net/subconverter/patches
wget https://git.glan.space/github/immortalwrt-packages.git/raw/b7b4499/net/subconverter/patches/100-stdcxxfs.patch -O feeds/packages/net/subconverter/patches/100-stdcxxfs.patch
sed -i '\/bin\/subconverter/a\\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(1)/usr/bin/subconverter' feeds/packages/net/subconverter/Makefile
ln -sf ../../../feeds/packages/net/subconverter ./package/feeds/packages/subconverter
svn export https://git.glan.space/github/immortalwrt-packages.git/trunk/libs/jpcre2 feeds/packages/libs/jpcre2
ln -sf ../../../feeds/packages/libs/jpcre2 ./package/feeds/packages/jpcre2
svn export https://git.glan.space/github/immortalwrt-packages.git/trunk/libs/rapidjson feeds/packages/libs/rapidjson
ln -sf ../../../feeds/packages/libs/rapidjson ./package/feeds/packages/rapidjson
svn export https://git.glan.space/github/immortalwrt-packages.git/trunk/libs/libcron feeds/packages/libs/libcron
wget https://git.glan.space/github/immortalwrt-packages.git/raw/b7b4499/libs/libcron/Makefile -O feeds/packages/libs/libcron/Makefile
ln -sf ../../../feeds/packages/libs/libcron ./package/feeds/packages/libcron
svn export https://git.glan.space/github/immortalwrt-packages.git/trunk/libs/quickjspp feeds/packages/libs/quickjspp
wget https://git.glan.space/github/immortalwrt-packages.git/raw/b7b4499/libs/quickjspp/Makefile -O feeds/packages/libs/quickjspp/Makefile
ln -sf ../../../feeds/packages/libs/quickjspp ./package/feeds/packages/quickjspp
svn export https://git.glan.space/github/immortalwrt-packages.git/trunk/libs/toml11 feeds/packages/libs/toml11
ln -sf ../../../feeds/packages/libs/toml11 ./package/feeds/packages/toml11
# 网易云音乐解锁
git clone --depth 1 https://git.glan.space/github/luci-app-unblockneteasemusic.git package/new/UnblockNeteaseMusic
# ucode
svn export https://git.glan.space/github/openwrt-openwrt.git/trunk/package/utils/ucode package/utils/ucode
# USB 打印机
svn export https://git.glan.space/github/coolsnowwolf-luci.git/trunk/applications/luci-app-usb-printer package/lean/luci-app-usb-printer
# UU加速器
svn export https://git.glan.space/github/coolsnowwolf-luci.git/trunk/applications/luci-app-uugamebooster package/lean/luci-app-uugamebooster
svn export https://git.glan.space/github/coolsnowwolf-packages.git/trunk/net/uugamebooster package/lean/uugamebooster
# KMS 激活助手
svn export https://git.glan.space/github/coolsnowwolf-luci.git/trunk/applications/luci-app-vlmcsd package/lean/luci-app-vlmcsd
svn export https://git.glan.space/github/coolsnowwolf-packages.git/trunk/net/vlmcsd package/lean/vlmcsd
# VSSR
git clone -b master --depth 1 https://git.glan.space/github/luci-app-vssr.git package/lean/luci-app-vssr
git clone -b master --depth 1 https://git.glan.space/github/lua-maxminddb.git package/lean/lua-maxminddb
pushd package/lean/luci-app-vssr
sed -i 's,default n,default y,g' Makefile
sed -i '/trojan-go/d' Makefile
sed -i '/v2ray-core/d' Makefile
sed -i '/v2ray-plugin/d' Makefile
sed -i '/xray-plugin/d' Makefile
sed -i 's,+shadowsocks-libev-ss-local ,,g' Makefile
popd
sed -i '/result.encrypt_method/a\result.fast_open = "1"' package/lean/luci-app-vssr/root/usr/share/vssr/subscribe.lua
sed -i 's,ispip.clang.cn/all_cn.txt,raw.sevencdn.com/QiuSimons/Chnroute/master/dist/chnroute/chnroute.txt,g' package/lean/luci-app-vssr/luasrc/controller/vssr.lua
sed -i 's,ispip.clang.cn/all_cn.txt,raw.sevencdn.com/QiuSimons/Chnroute/master/dist/chnroute/chnroute.txt,g' package/lean/luci-app-vssr/root/usr/share/vssr/update.lua
# 网络唤醒
svn export https://git.glan.space/github/bf-package-master.git/trunk/zxlhhyccc/luci-app-services-wolplus package/new/luci-app-services-wolplus
# 流量监视
git clone -b master --depth 1 https://git.glan.space/github/wrtbwmon.git package/new/wrtbwmon
git clone -b master --depth 1 https://git.glan.space/github/luci-app-wrtbwmon.git package/new/luci-app-wrtbwmon
# 迅雷快鸟宽带加速
git clone --depth 1 https://git.glan.space/github/luci-app-xlnetacc.git package/lean/luci-app-xlnetacc
# Zerotier
svn export https://git.glan.space/github/immortalwrt-luci.git/trunk/applications/luci-app-zerotier feeds/luci/applications/luci-app-zerotier
wget -P feeds/luci/applications/luci-app-zerotier/ https://git.glan.space/github/OpenWrt-Add.git/raw/master/move_2_services.sh
chmod -R 755 ./feeds/luci/applications/luci-app-zerotier/move_2_services.sh
pushd feeds/luci/applications/luci-app-zerotier
bash move_2_services.sh
popd
ln -sf ../../../feeds/luci/applications/luci-app-zerotier ./package/feeds/luci/luci-app-zerotier
rm -rf ./feeds/packages/net/zerotier
svn export https://git.glan.space/github/openwrt-packages.git/trunk/net/zerotier feeds/packages/net/zerotier
rm -rf ./feeds/packages/net/zerotier/files/etc/init.d/zerotier
sed -i '/Default,one/a\\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(PKG_BUILD_DIR)/zerotier-one' feeds/packages/net/zerotier/Makefile
# 翻译及部分功能优化
svn export https://git.glan.space/github/OpenWrt-Add.git/trunk/addition-trans-zh package/lean/lean-translate

### 最后的收尾工作 ###
# Lets Fuck
mkdir package/base-files/files/usr/bin
wget -P package/base-files/files/usr/bin/ https://git.glan.space/github/OpenWrt-Add.git/raw/master/fuck
# 最大连接数
sed -i 's/16384/65535/g' package/kernel/linux/files/sysctl-nf-conntrack.conf
# 生成默认配置及缓存
rm -rf .config

### Shortcut-FE 部分 ###
# Patch Kernel 以支持 Shortcut-FE
#pushd target/linux/generic/hack-5.4
#wget https://git.glan.space/github/immortalwrt.git/raw/master/target/linux/generic/hack-5.4/953-net-patch-linux-kernel-to-support-shortcut-fe.patch
#popd
# Patch LuCI 以增添 Shortcut-FE 开关
#patch -p1 < ../PATCH/firewall/luci-app-firewall_add_sfe_switch.patch
# Shortcut-FE 相关组件
#svn export https://git.glan.space/github/coolsnowwolf-lede.git/trunk/package/lean/shortcut-fe package/lean/shortcut-fe
#svn export https://git.glan.space/github/coolsnowwolf-lede.git/trunk/package/lean/fast-classifier package/lean/fast-classifier
#wget -P package/base-files/files/etc/init.d/ https://git.glan.space/github/OpenWrt-Add.git/raw/master/shortcut-fe

# 回滚通用即插即用
#rm -rf ./feeds/packages/net/miniupnpd
#svn export https://git.glan.space/github/coolsnowwolf-packages.git/trunk/net/miniupnpd feeds/packages/net/miniupnpd

#exit 0