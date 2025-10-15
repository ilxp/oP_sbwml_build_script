#!/bin/bash

#######OprX的相关优化#######
#一、定义克隆功能函数
#第一种
#git clone -b 分支 --single-branch 仓库地址 到本地目录（如：package/文件名 #文件名不能相同）
#cd  package/文件名  #主注意目录级别（此处为二级，退出为cd ../..  一级：./diydata  退出为 cd ..  三级 package/文件名1/文件名2 退出为cd ../../..）
#git sparse-checkout init --cone 
#git sparse-checkout set 目标文件  #可以一级或者二级，三级，多个目录用空格隔开。注意是连上级目录一起。
#cd ../..  #退出本地目录（）
#例如1
#git clone -b main --single-branch https://github.com/ilxp/eS_lede_build_script.git ./diydata
#cd  ./diydata
#git sparse-checkout init --cone 
#git sparse-checkout set openwrt/data
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ..

#例如2
#git clone -b master --single-branch https://github.com/QiuSimons/OpenWrt-Add.git package/add
#cd  package/add
#git sparse-checkout init --cone 
#git sparse-checkout set addition-trans-zh
#rm -rf .git
#rm -rf .github
#rm -rf .gitignore
#rm -rf *.md
#rm -rf .gitattributes
#rm -rf LICENSE
#cd ../..
#复制default-settings文件
#cp -f ./diydata/openwrt/data/default-settings-oR package/add/addition-trans-zh/files/zzz-default-settings


#第二种  来源https://github.com/Jejz168/OpenWrt
mkdir package/new
function merge_package() {
	# 参数1是分支名,参数2是库地址,参数3是所有文件下载到指定路径。
	# 同一个仓库下载多个文件夹直接在后面跟文件名或路径，空格分开。
	# 示例:
	# merge_package 分支 仓库地址 下载到指定路径(已存在或者自定义) 目标文件（多个空格分开）
	# 下载到不存在的目录时: rm -rf package/new; mkdir package/new
	# merge_package master https://github.com/WYC-2020/openwrt-packages package/openwrt-packages luci-app-eqos luci-app-openclash luci-app-ddnsto ddnsto 
	# merge_package master https://github.com/lisaac/luci-app-dockerman package/lean applications/luci-app-dockerman #结果是将luci-app-dockerman放在package/lean下
	# merge_package main https://github.com/linkease/nas-packages-luci package/new luci/luci-app-ddnsto  #结果是package/new/luci-app-ddnsto
	# merge_package master https://github.com/linkease/nas-packages package/new network/services/ddnsto  #结果是package/new/ddnsto 
	# merge_package master https://github.com/coolsnowwolf/lede package/kernel package/kernel/mac80211  #将目标仓库的package/kernel/mac80211克隆到本地package/kernel下
	#merge_package main https://github.com/Lienol/openwrt.git  ./tools tools/ucl tools/upx  #表示在根目录生成一个tools文件夹。本来就会有，所以报错。
    #merge_package main https://github.com/Lienol/openwrt.git tools tools/ucl tools/upx  #表示目标目录tool下的ucl和upx移动到根目录已经存在的tools文件夹。
	if [[ $# -lt 3 ]]; then
		echo "Syntax error: [$#] [$*]" >&2
		return 1
	fi
	trap 'rm -rf "$tmpdir"' EXIT
	branch="$1" curl="$2" target_dir="$3" && shift 3
	rootdir="$PWD"
	localdir="$target_dir"
	[ -d "$localdir" ] || mkdir -p "$localdir"
	tmpdir="$(mktemp -d)" || exit 1
        echo "开始下载：$(echo $curl | awk -F '/' '{print $(NF)}')"
	git clone -b "$branch" --depth 1 --filter=blob:none --sparse "$curl" "$tmpdir"
	cd "$tmpdir"
	git sparse-checkout init --cone
	git sparse-checkout set "$@"
	# 使用循环逐个移动文件夹
	for folder in "$@"; do
		mv -f "$folder" "$rootdir/$localdir"
	done
	cd "$rootdir"
}
###################

#二、导入自己data目录数据配置 （注意结果是./diydata/openwrt/data）

#配置文件	
#采用本地复制
#cp -rf ./diydata/openwrt/data/files ./package/base-files/
#cp -rf ./diydata/openwrt/data/files  files
#自定义app
#cp -rf ./diydata/openwrt/data/app/*  ./

#采用网络复制
merge_package main https://github.com/ilxp/oP_sbwml_build_script ./diydata openwrt/data   #注意结果是./diydata/data）
cp -rf ./diydata/data/files ./package/base-files/
#cp -rf ./diydata/data/files  files
#自定义app
cp -rf ./diydata/data/app/*  ./

#Default-settings系统配置
#克隆default-settings  【采用sbwml的默认的default-settings】
#cp -f ./diydata/data/default-settings-oR package/new/default-settings/default/zzz-default-settings  #死活cp不成，只能拉去下面的addition-trans-zh。
#【采用QiuSimons的addition-trans-zh】
merge_package master https://github.com/QiuSimons/OpenWrt-Add.git package/new addition-trans-zh
#复制default-settings文件
cp -f ./diydata/data/default-settings-oP-sbwml package/new/addition-trans-zh/files/zzz-default-settings

#三、编译出错的########
rm -rf package/kernel/rtl8812au-ct

rm -rf target/linux/generic/hack-6.12/952-net-conntrack-events-support-multiple-registrant.patch
rm -rf target/linux/generic/hack-6.12/982-add-bcm-fullconenat-support.patch

###################

#四、系统优化########
# BBRv3 【用sbwml的00-prepare_base】

# Modules  （package/kernel/linux/modules） 【用sbwml的00-prepare_base】

# kenrel Vermagic   sbwml已经在mainline
#sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
#grep HASH include/kernel-6.12 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic
#grep HASH include/kernel-$kernel_version | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic

# Optimization level -Ofast 【已经在target-modify_for_x86_64.patch】
#sed -i 's/Os/O2/g' include/target.mk
#sed -i 's/Os/O2 -march=x86-64-v2/g' include/target.mk
#sed -i 's/Os/O3 -mtune=generic/g' include/target.mk  #sbwml的target-modify_for_x86_64.patch代码

# All-komd -Fix x86 - CONFIG_ALL_KMODS（已经失效，已经改在data/hwmon.mk）
#sed -i 's/hwmon, +PACKAGE_kmod-thermal:kmod-thermal/hwmon/g' package/kernel/linux/modules/hwmon.mk

# 固件版本号(21.3.2 %y : 年份的最后两位数字)
#date=`TZ=UTC-8 date +%m.%d.%Y`  #升级用，统一这样
#R$(TZ=UTC-8 date +'%y.%-m.%-d')
ReV_Date=`TZ=UTC-8 date +%y.%-m.%-d`  #24年1月1日：24.1.1
#ReV_Date=$(TZ=UTC-8 date +'%y.%-m.%-d')  #这个引用要带{}，即${ReV_Date}
sed -i -e "/\(# \)\?REVISION:=/c\REVISION:=$ReV_Date" -e '/VERSION_CODE:=/c\VERSION_CODE:=$(REVISION)' include/version.mk
sed -i "s/DISTRIB_DESCRIPTION.*/DISTRIB_DESCRIPTION='OprX oP%C'/g" package/base-files/files/etc/openwrt_release

#sbmwl大佬现实的在usr/lib/os-release中的PRETTY_NAME="OpenWrt SNAPSHOT"
#sed -i "/PRETTY_NAME/d" package/base-files/files/usr/lib/os-release
#sed -i "/ID_LIKE/aPRETTY_NAME=\"OprX oP$ReV_Date\"" package/base-files/files/usr/lib/os-release

sed -i "/OPENWRT_RELEASE/d" package/base-files/files/usr/lib/os-release
sed -i "/OPENWRT_DEVICE_REVISION/aOPENWRT_RELEASE=\"OprX oP$ReV_Date\"" package/base-files/files/usr/lib/os-release
	
# 固件的命名格式：。
#去掉版本号 openwrt-23.05.2-x86-64或者openwrt-23.05-snapshot-r0-60e49cf-x86-64改为openwrt-x86-64
sed -i 's/IMG_PREFIX:=$(VERSION_DIST_SANITIZED)-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)/IMG_PREFIX:=$(VERSION_DIST_SANITIZED)-/g' include/image.mk

#采用kiddin9大神的gpsysupgrade升级方式：https://github.com/ilxp/openwrt-gpsysupgrade-kiddin9：
#格式：10.23.2024-oprx-oP-x86-64-generic-squashfs-combined-efi.img.gz   #oD是固件分类标签
#sed -i 's/IMG_PREFIX:=$(VERSION_DIST_SANITIZED)/IMG_PREFIX:=$(shell date +%m.%d.%Y)-oprx-oP/g' include/image.mk  #在bulid.sh统一命名

# 登陆ip以及主机名【在default-setting中配置】
#sed -i "s/192.168.1.1/192.168.8.1/" package/base-files/files/bin/config_generate
#sed -i "s/OpenWrt/OprX/g" package/base-files/files/bin/config_generate
# 修改主机名openwrt为OprX （将系统所有包含openwrt改为oprx，慎用）
#sed -i "s/OpenWrt/OprX/g" package/base-files/files/bin/config_generate package/base-files/image-config.in config/Config-images.in Config.in include/u-boot.mk include/version.mk package/network/config/wifi-scripts/files/lib/wifi/mac80211.sh || true

# 内核版本【尽量不要修改，好komd】
#sed -i 's/KERNEL_PATCHVER:=5.15/KERNEL_PATCHVER:=6.1/g' target/linux/x86/Makefile

# 网络连接数
#sed -i 's/net.netfilter.nf_conntrack_max=16384/net.netfilter.nf_conntrack_max=65535/g' package/kernel/linux/files/sysctl-nf-conntrack.conf
echo -e "\nnet.netfilter.nf_conntrack_max=65535" >> package/kernel/linux/files/sysctl-nf-conntrack.conf

# 修复依赖
sed -i 's/PKG_HASH.*/PKG_HASH:=skip/' feeds/packages/utils/containerd/Makefile

# Fix mt76 wireless driver
pushd package/kernel/mt76
sed -i '/mt7662u_rom_patch.bin/a\\techo mt76-usb disable_usb_sg=1 > $\(1\)\/etc\/modules.d\/mt76-usb' Makefile
popd

# Kiddin9大神的####for openwrt
#sed -i 's/Os/O2/g' include/target.mk
#sed -i 's/=bbr/=cubic/' package/kernel/linux/files/sysctl-tcp-bbr.conf
#for X—86
sed -i 's/kmod-r8169/kmod-r8168/' target/linux/x86/image/64.mk

# ===Jejz168大神优化===for openwrt  https://github.com/Jejz168/OpenWrt
# 设置ttyd免帐号登录
sed -i 's/\/bin\/login/\/bin\/login -f root/' feeds/packages/utils/ttyd/files/ttyd.config

# 默认 shell 为 bash 【在zsh中统一修改】
#sed -i 's/\/bin\/ash/\/bin\/bash/g' package/base-files/files/etc/passwd

# 优化socat中英翻译
sed -i 's/仅IPv6/仅 IPv6/g' package/feeds/luci/luci-app-socat/po/zh_Hans/socat.po 

#samba解除root限制
sed -i 's/invalid users = root/#&/g' feeds/packages/net/samba4/files/smb.conf.template

# 修复上移下移按钮翻译
sed -i 's/<%:Up%>/<%:Move up%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm
sed -i 's/<%:Down%>/<%:Move down%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm

# ddns - fix boot
sed -i '/boot()/,+2d' feeds/packages/net/ddns-scripts/files/etc/init.d/ddns

# nlbwmon - disable syslog
sed -i 's/stderr 1/stderr 0/g' feeds/packages/net/nlbwmon/files/nlbwmon.init

# nlbwmon
sed -i 's/services/network/g' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json
sed -i 's/services/network/g' feeds/luci/applications/luci-app-nlbwmon/htdocs/luci-static/resources/view/nlbw/config.js

# 修复procps-ng-top导致首页cpu使用率无法获取
sed -i 's#top -n1#\/bin\/busybox top -n1#g' feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci

# 最大连接数修改为65535
#sed -i '/customized in this file/a net.netfilter.nf_conntrack_max=65535' package/base-files/files/etc/sysctl.conf

# 报错修复
#sed -i 's/+libpcre/+libpcre2/g' package/feeds/telephony/freeswitch/Makefile

# 补充 firewall4 luci 中文翻译
cat >> "feeds/luci/applications/luci-app-firewall/po/zh_Hans/firewall.po" <<-EOF
	
	msgid ""
	"Custom rules allow you to execute arbitrary nft commands which are not "
	"otherwise covered by the firewall framework. The rules are executed after "
	"each firewall restart, right after the default ruleset has been loaded."
	msgstr ""
	"自定义规则允许您执行不属于防火墙框架的任意 nft 命令。每次重启防火墙时，"
	"这些规则在默认的规则运行后立即执行。"
	
	msgid ""
	"Applicable to internet environments where the router is not assigned an IPv6 prefix, "
	"such as when using an upstream optical modem for dial-up."
	msgstr ""
	"适用于路由器未分配 IPv6 前缀的互联网环境，例如上游使用光猫拨号时。"

	msgid "NFtables Firewall"
	msgstr "NFtables 防火墙"

	msgid "IPtables Firewall"
	msgstr "IPtables 防火墙"
EOF

# 修正部分从第三方仓库拉取的软件 Makefile 路径问题
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHREPO/PKG_SOURCE_URL:=https:\/\/github.com/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload.github.com/g' {}

# ===Ecrasy大神diy for offical openwrt：https://github.com/ecrasy/BuildOfficialOpenWrt ===
# Add model.sh to remove annoying board name for Intel J4125
cp -f ./diydata/data/model.sh package/base-files/files/etc/
chmod 0755 package/base-files/files/etc/model.sh
echo "Add model.sh"

# Add 92-ula-prefix, try to set up IPv6 ula prefix after wlan up
# and call model.sh
mkdir -p package/base-files/files/etc/hotplug.d/iface
cp -f ./diydata/data/92-ula-prefix package/base-files/files/etc/hotplug.d/iface/
chmod 0755 package/base-files/files/etc/hotplug.d/iface/92-ula-prefix
echo "Add 92-ula-prefix"

# Custom DDns zh_Hans translation
ddns_PATH="feeds/luci/applications/luci-app-ddns/po/zh_Hans"
sed -i 's/动态DNS 服务项/DDNS服务/g' ${ddns_PATH}/ddns.po
sed -i 's/动态 DNS 版本/DDNS版本/g' ${ddns_PATH}/ddns.po
sed -i 's/动态 DNS(DDNS)/DDNS/g' ${ddns_PATH}/ddns.po
sed -i 's/动态DNS/DDNS/g' ${ddns_PATH}/ddns.po
sed -i 's/动态 DNS/DDNS/g' ${ddns_PATH}/ddns.po
echo "Custom DDNS zh_Hans translation"

# Custom Shairplay zh_Hans translation
sp_PATH="feeds/luci/applications/luci-app-shairplay/po/zh_Hans"
sed -i 's/Shairplay(多媒体程序)/Shairplay/g' ${sp_PATH}/shairplay.po
echo "Custom Shairplay zh_Hans translation"

# Custom Samba4 zh_Hans translation
SB_PATH="feeds/luci/applications/luci-app-samba4/po/zh_Hans"
sed -i 's/网络共享/Samba4/g' ${SB_PATH}/samba4.po
echo "Custom Samba4 zh_Hans translation"

# Custom CloudShark zh_Hans translation
CShark_PATH="feeds/luci/applications/luci-app-cshark/po/zh_Hans"
sed -i 's/云鲨/CloudShark/g' ${CShark_PATH}/cshark.po
echo "Custom CloudShark zh_Hans translation"

# Add Port status zh_Hans translation
LB_PATH="feeds/luci/modules/luci-base/po/zh_Hans"
TLINE=$(grep -m1 -n '"Port status"' ${LB_PATH}/base.po |awk '{ print $1 }' |cut -d':' -f1)
if [ -n "$TLINE" ]; then
    DLINE=$((TLINE+1))
    sed -i "${DLINE}d" ${LB_PATH}/base.po
    sed -i "${TLINE}a msgstr \"网口状态\"" ${LB_PATH}/base.po
    echo "Add Port status zh_Hans translation"
fi

# fix error from https://github.com/openwrt/luci/issues/5373
# luci-app-statistics: misconfiguration shipped pointing to non-existent directory
str="^[^#]*option Include '/etc/collectd/conf.d'"
cmd="s@$str@#&@"
sed -ri "$cmd" feeds/luci/applications/luci-app-statistics/root/etc/config/luci_statistics
echo "Fix luci-app-statistics ref wrong path error"

# fix stupid coremark benchmark error
touch package/base-files/files/etc/bench.log
chmod 0666 package/base-files/files/etc/bench.log
echo "Touch coremark log file to fix uhttpd error!!!"

# make minidlna depends on libffmpeg-full instead of libffmpeg
# little bro ffmpeg mini custom be gone
sed -i "s/libffmpeg /libffmpeg-full /g" feeds/packages/multimedia/minidlna/Makefile
echo "Set minidlna depends on libffmpeg-full instead of libffmpeg"

# make cshark depends on libustream-openssl instead of libustream-mbedtls
# i fucking hate stupid mbedtls so much, be gone
sed -i "s/libustream-mbedtls/libustream-openssl/g" feeds/packages/net/cshark/Makefile
echo "Set cshark depends on libustream-openssl instead of libustream-mbedtls"

# remove hnetd depends on odhcpd*
sed -i "s/+odhcpd//g" feeds/routing/hnetd/Makefile
echo "Remove hnetd depends on odhcpd*"

# make shairplay depends on mdnsd instead of libavahi-compat-libdnssd
sed -i "s/+libavahi-compat-libdnssd/+mdnsd/g" feeds/packages/sound/shairplay/Makefile
echo "Set shairplay depends on mdnsd instead of libavahi-compat-libdnssd"

# set v2raya depends on v2ray-core
sed -i "s/xray-core/v2ray-core/g" feeds/packages/net/v2raya/Makefile
echo "set v2raya depends on v2ray-core"

# ===DHDAXCW骷髅头大神的 https://github.com/DHDAXCW/OpenWRT_x86_x64/blob/main/scripts/lean.sh ===
# 更换 libssh libmbim
#rm -rf packages/libs/libmbim
#rm -rf packages/libs/libssh
#merge_package master https://github.com/openwrt/packages.git package/new libs/libssh


###############二、相关luci应用#############################
#一）、主题
#1）argon主题（lede分支适合lean的lede是lu18）
rm -rf package/new/luci-theme-argon
rm -rf feeds/luci/themes/luci-theme-argon
git clone -b master https://github.com/jerrykuku/luci-theme-argon.git package/diy/luci-theme-argon

#2）修改 argon 为默认主题
sed -i '/set luci.main.mediaurlbase=\/luci-static\/bootstrap/d' feeds/luci/themes/luci-theme-bootstrap/root/etc/uci-defaults/30_luci-theme-bootstrap
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' ./feeds/luci/collections/luci/Makefile
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci-nginx/Makefile

#二）、翻墙系列（openwrt编译系统自带为passwall+nikki）
#1、ssr-plus
#rm -rf package/helloworld
#rm -rf feeds/luci/applications/luci-app-ssr-plus
#git clone https://github.com/fw876/helloworld.git package/helloworld

#采用kenzok8的small库
#git clone https://github.com/kenzok8/small.git package/helloworld

# sbwml的SSRP & Passwall
#rm -rf feeds/packages/net/{xray-core,v2ray-core,v2ray-geodata,sing-box}
#git clone https://github.com/sbwml/openwrt_helloworld package/helloworld -b v5

##FQ全部调到VPN菜单
#sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/controller/*.lua
#sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/model/cbi/shadowsocksr/*.lua
#sed -i 's/services/vpn/g' package/helloworld/luci-app-ssr-plus/luasrc/view/shadowsocksr/*.htm

#解决缺乏libopenssl-legacy依赖
#sed -i 's/ +libopenssl-legacy//g' package/helloworld/shadowsocksr-libev/Makefile

#2、passwall
#克隆官方的，以及删除sbwml的
rm -rf package/new/helloworld
rm -rf feeds/luci/applications/luci-app-passwall
#git clone -b main https://github.com/xiaorouji/openwrt-passwall-packages.git package/diy/openwrt-passwall-packages
#git clone -b main https://github.com/xiaorouji/openwrt-passwall.git  package/diy/openwrt-passwall
# passwall
#merge_package main https://github.com/xiaorouji/openwrt-passwall package/new luci-app-passwall

#采用kenzok8的small库
#git clone https://github.com/kenzok8/small.git package/diy/openwrt-passwall

# sbwml的SSRP & Passwall nikki
rm -rf feeds/packages/net/{xray-core,v2ray-core,v2ray-geodata,sing-box}
git clone https://github.com/sbwml/openwrt_helloworld package/helloworld -b v5

##FQ全部调到VPN菜单
sed -i 's/services/vpn/g' package/helloworld/luci-app-passwall/luasrc/controller/*.lua
sed -i 's/services/vpn/g' package/helloworld/luci-app-passwall/luasrc/passwall/*.lua
sed -i 's/services/vpn/g' package/helloworld/luci-app-passwall/luasrc/model/cbi/passwall/client/*.lua
sed -i 's/services/vpn/g' package/helloworld/luci-app-passwall/luasrc/model/cbi/passwall/server/*.lua
sed -i 's/services/vpn/g' package/helloworld/luci-app-passwall/luasrc/view/passwall/app_update/*.htm
sed -i 's/services/vpn/g' package/helloworld/luci-app-passwall/luasrc/view/passwall/socks_auto_switch/*.htm
sed -i 's/services/vpn/g' package/helloworld/luci-app-passwall/luasrc/view/passwall/global/*.htm
sed -i 's/services/vpn/g' package/helloworld/luci-app-passwall/luasrc/view/passwall/haproxy/*.htm
sed -i 's/services/vpn/g' package/helloworld/luci-app-passwall/luasrc/view/passwall/log/*.htm
sed -i 's/services/vpn/g' package/helloworld/luci-app-passwall/luasrc/view/passwall/node_list/*.htm
sed -i 's/services/vpn/g' package/helloworld/luci-app-passwall/luasrc/view/passwall/rule/*.htm
sed -i 's/services/vpn/g' package/helloworld/luci-app-passwall/luasrc/view/passwall/server/*.htm
# Passwall 白名单
echo '
teamviewer.com
epicgames.com
dangdang.com
account.synology.com
ddns.synology.com
checkip.synology.com
checkip.dyndns.org
checkipv6.synology.com
ntp.aliyun.com
cn.ntp.org.cn
ntp.ntsc.ac.cn
' >>./package/helloworld/luci-app-passwall/root/usr/share/passwall/rules/direct_host

#3、clash
#1）openclash
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf package/new/OpenClash
rm -rf package/helloworld/luci-app-openclash
#sed -i '$a src-git openclash https://github.com/vernesong/OpenClash.git' feeds.conf.default
#注意master对应core打分master的分支，dev对应core的dev，
git clone -b master --single-branch https://github.com/vernesong/OpenClash.git  package/diy/openclash
# 添加内核（新版只支持meta内核）
wget https://github.com/vernesong/OpenClash/raw/core/master/meta/clash-linux-amd64.tar.gz&&tar -zxvf *.tar.gz
chmod 0755 clash
rm -rf *.tar.gz&&mkdir -p package/base-files/files/etc/openclash/core&&mv clash package/base-files/files/etc/openclash/core/clash_meta
chmod +x package/base-files/files/etc/openclash/core/clash*
##FQ全部调到VPN菜单
sed -i 's/services/vpn/g' package/diy/openclash/luci-app-openclash/luasrc/controller/*.lua
sed -i 's/services/vpn/g' package/diy/openclash/luci-app-openclash/luasrc/*.lua
sed -i 's/services/vpn/g' package/diy/openclash/luci-app-openclash/luasrc/model/cbi/openclash/*.lua
sed -i 's/services/vpn/g' package/diy/openclash/luci-app-openclash/luasrc/view/openclash/*.htm

# DHDAXCW骷髅头的preset-clash-core.sh
#mkdir -p package/base-files/files/etc/openclash/core
#CLASH_DEV_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/dev/clash-linux-${1}.tar.gz"
#CLASH_TUN_URL=$(curl -fsSL https://api.github.com/repos/vernesong/OpenClash/contents/master/premium\?ref\=core | grep download_url | grep $1 | awk -F '"' '{print $4}' | grep -v "v3" )
#CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-${1}.tar.gz"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
#wget -qO- $CLASH_DEV_URL | tar xOvz > package/base-files/files/etc/openclash/core/clash
#wget -qO- $CLASH_TUN_URL | gunzip -c > package/base-files/files/etc/openclash/core/clash_tun
#wget -qO- $CLASH_META_URL | tar xOvz > package/base-files/files/etc/openclash/core/clash_meta
#wget -qO- $GEOIP_URL > package/base-files/files/etc/openclash/GeoIP.dat
#wget -qO- $GEOSITE_URL > package/base-files/files/etc/openclash/GeoSite.dat
#chmod +x package/base-files/files/etc/openclash/core/clash*

# 4、mihomo nikki（只支持firewall4.lede无望）
rm -rf package/helloworld/luci-app-nikki
rm -rf package/helloworld/nikki
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki package/diy/OpenWrt-nikki
sed -i 's/services/vpn/g' package/diy/OpenWrt-nikki/luci-app-nikki/root/usr/share/luci/menu.d/luci-app-nikki.json

# 5、homeproxy（只支持firewall4.lede无望）
#git clone --depth=1 https://github.com/muink/luci-app-homeproxy.git package/diy/luci-app-homeproxy
#git clone --depth=1 https://github.com/immortalwrt/homeproxy.git package/diy/luci-app-homeproxy
#rm -rf ./feeds/packages/net/sing-box
#依赖组件
#merge_package v5 https://github.com/sbwml/openwrt_helloworld.git package/new chinadns-ng sing-box

#移动到VPN栏目
sed -i 's/services/vpn/g' package/diy/luci-app-homeproxy/root/usr/share/luci/menu.d/luci-app-homeproxy.json

#三）、应用商店
#git clone https://github.com/linkease/nas-packages.git  package/diy/nas-packages
#git clone https://github.com/linkease/nas-packages-luci.git  package/diy/nas-packages-luci
git clone https://github.com/linkease/istore.git  package/diy/istore
git clone https://github.com/linkease/istore-ui.git  package/diy/istore-ui
rm -rf package/diy/istore-ui/app-store-ui/src/dist/luci-static/istore/i18n/en.json

#四）、sirpdboy大神的相关插件
#中文netdata
rm -rf feeds/luci/applications/luci-app-netdata
git clone https://github.com/sirpdboy/luci-app-netdata.git package/diy/luci-app-netdata

#网络设置向导
git clone https://github.com/sirpdboy/luci-app-netwizard.git package/diy/luci-app-netwizard
sed -i 's/Netwizard/设置向导/g' package/diy/luci-app-netwizard/luci-app-netwizard/luasrc/controller/netwizard.lua
#sed -i 's/wan_interface 'eth1'/wan_interface 'eth0'/g' package/diy/luci-app-netwizard/root/etc/init.d/netwizard
#sed -i 's/eth1/eth0/g' package/diy/luci-app-netwizard/root/etc/init.d/netwizard

#网络速度测试
git clone https://github.com/sirpdboy/netspeedtest.git package/diy/netspeedtest
sed -i 's/Net Speedtest/网络测速/g' package/diy/netspeedtest/luci-app-netspeedtest/luasrc/controller/netspeedtest.lua

#定时设置（会产生一个control管控栏目）
rm -rf package/sirpdboy/luci-app-luci-app-taskplan
git clone https://github.com/sirpdboy/luci-app-taskplan package/diy/luci-app-taskplan
sed -i 's/Task Plan/定时设置/g' package/diy/luci-app-taskplan/luci-app-taskplan/luasrc/controller/taskplan.lua
sed -i 's/Control/管控/g' package/diy/luci-app-taskplan/luasrc/controller/taskplan.lua

#关机  编译不成功采用esir的
#git clone https://github.com/sirpdboy/luci-app-poweroffdevice package/diy/luci-app-poweroffdevice
#关机 poweroff（esir大神）
git clone https://github.com/esirplayground/luci-app-poweroff package/diy/luci-app-poweroff
sed -i 's/PowerOff/关机/g' package/diy/luci-app-poweroff/luasrc/controller/poweroff.lua

#家长控制（会生成Control管控栏目） #无法运行
#git clone https://github.com/sirpdboy/luci-app-parentcontrol package/diy/luci-app-parentcontrol
git clone https://github.com/ilxp/luci-app-parentcontrol package/diy/luci-app-parentcontrol
sed -i 's/Parent Control/家长控制/g' package/diy/luci-app-parentcontrol/luasrc/controller/parentcontrol.lua
sed -i 's/Control/管控/g' package/diy/luci-app-parentcontrol/luasrc/controller/parentcontrol.lua

#自动扩容分区
git clone https://github.com/sirpdboy/luci-app-partexp package/diy/luci-app-partexp
sed -i 's/Partition Expansion/分区扩容/g' package/diy/luci-app-partexp/luci-app-partexp/luasrc/controller/partexp.lua
#rm -rf package/diy/luci-app-partexp/po/zh_Hans  #sbwml上不能删除
#sed -i 's, - !, -o !,g' package/diy/luci-app-partexp/root/etc/init.d/partexp
#sed -i 's,expquit 1 ,#expquit 1 ,g' package/diy/luci-app-partexp/root/etc/init.d/partexp

#ddns-go
rm -rf feeds/packages/net/ddns-go
rm -rf feeds/luci/applications/luci-app-ddns-go
git clone https://github.com/sirpdboy/luci-app-ddns-go package/diy/luci-app-ddns-go

#luck
git clone https://github.com/gdy666/luci-app-lucky package/diy/luck

#高级设置
git clone https://github.com/sirpdboy/luci-app-advanced.git package/diy/luci-app-advanced
#rm -rf package/diy/luci-app-advanced/htdocs #不能删除

##五）QOS相关
#石像鬼qos采用我自己的，会有一个QOS栏目生成
#git clone -b openwrt-2305 https://github.com/ilxp/gargoyle-qos-openwrt.git  package/diy/gargoyle-qos-openwrt
#sed -i 's/Gargoyle QoS/石像鬼 QoS/g' package/diy/gargoyle-qos-openwrt/luci-app-qos-gargoyle/luasrc/controller/qos_gargoyle.lua
#sed -i 's/Download Settings/下载设置/g' package/diy/gargoyle-qos-openwrt/luci-app-qos-gargoyle/luasrc/controller/qos_gargoyle.lua
#sed -i 's/Upload Settings/上传设置/g' package/diy/gargoyle-qos-openwrt/luci-app-qos-gargoyle/luasrc/controller/qos_gargoyle.lua
#wget -qO - https://raw.gitmirror.com/ilxp/gargoyle-qos-openwrt/openwrt-2203/010-revert_to_iptables.patch | patch -p1  #去除firwall4，用3

#2）eqos，采用luci自带的即可。把eqos放在管控下。不在列入Qos目录下
#rm -rf feeds/luci/applications/luci-app-eqos #lean库里没有eqos
#sed -i 's/network/QOS/g' feeds/luci/applications/luci-app-eqos/luasrc/controller/eqos.lua #将其移动到QOS或者control管控下
#git clone https://github.com/ilxp/luci-app-eqos.git  package/diy/luci-app-eqos  #我的会产生一个QOS栏目
#sed -i 's/network/control/g' package/diy/luci-app-eqos/luasrc/controller/eqos.lua
#sed -i 's/EQoS/网速控制/g' package/diy/luci-app-eqos/luasrc/controller/eqos.lua
git clone https://github.com/sirpdboy/luci-app-eqosplus  package/diy/luci-app-eqosplus

#nft-qos
#rm -rf feeds/packages/net/nft-qos
#rm -rf feeds/luci/applications/luci-app-nft-qos
#git clone https://github.com/ilxp/openwrt-nft-qos.git  package/diy/openwrt-nft-qos
#merge_package master https://github.com/ilxp/openwrt-nft-qos.gi package/new luci-app-nft-qos nft-qos
#sed -i 's/services/qos/g' feeds/luci/applications/luci-app-nft-qos/luasrc/controller/nft-qos.lua   #将其移动到QOS目录下

#3)SQM
#sed -i 's/network/qos/g' feeds/luci/applications/luci-app-sqm/luasrc/controller/sqm.lua #将其移动到QOS下,2122系列此法不行
#把sqm放在qos栏目下（/network 改为/QOS）
#sed -i 's/\/network/\/qos/g' feeds/luci/applications/luci-app-sqm/root/usr/share/luci/menu.d/luci-app-sqm.json #没有nft-qos产生的QOS栏目。
# SQM Translation
mkdir -p feeds/packages/net/sqm-scripts/patches
#curl -s https://init2.cooluc.com/openwrt/patch/sqm/001-help-translation.patch > feeds/packages/net/sqm-scripts/patches/001-help-translation.patch
cp -f ./diydata/data/sqm/001-help-translation.patch  feeds/packages/net/sqm-scripts/patches/001-help-translation.patch

#六）、DNS相关（openwrt带mosdns）
#1）smartdns（lede是lede的luci18-branch，master分支是js，lede的luci-23.05分支是js）
#rm -rf feeds/packages/net/smartdns
#rm -rf feeds/luci/applications/luci-app-smartdns
#git clone -b master https://github.com/pymumu/luci-app-smartdns.git package/diy/luci-app-smartdns  #官方的smartdns安装不上，只用luci库里的
#git clone https://github.com/pymumu/openwrt-smartdns.git package/diy/smartdns

mkdir -p package/base-files/files/etc/smartdns
#中国域名列表
#下载三个最新列表合并到cn.conf
wget -qO- "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/direct-list.txt"  >> package/base-files/files/etc/smartdns/cn.conf
wget -qO- "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-datt@release/apple-cn.txt"    >> package/base-files/files/etc/smartdns/cn.conf
wget -qO- "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/google-cn.txt"   >> package/base-files/files/etc/smartdns/cn.conf
#去除full regexp并指定china组解析
sed "s/^full://g;s/^regexp:.*$//g;s/^/nameserver \//g;s/$/\/cn/g" -i package/base-files/files/etc/smartdns/cn.conf
chmod +x package/base-files/files/etc/smartdns/cn.conf

#广告域名列表
wget -qO- "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/reject-list.txt"  >> package/base-files/files/etc/smartdns/block.conf
wget -qO- "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/win-spy.txt"  >> package/base-files/files/etc/smartdns/block.conf
wget -qO- "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/win-extra.txt"  >> package/base-files/files/etc/smartdns/block.conf
sed "s/^full://g;s/^regexp:.*$//g;s/^/address \//g;s/$/\/#/g" -i package/base-files/files/etc/smartdns/block.conf
chmod +x package/base-files/files/etc/smartdns/block.conf

#2）mosdns
rm -rf feeds/packages/net/mosdns
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/packages/net/v2ray-geodata
#git clone -b v5 --single-branch https://github.com/sbwml/luci-app-mosdns package/diy/luci-app-mosdns #需要v2ray-geodata依赖
git clone -b master --single-branch https://github.com/QiuSimons/openwrt-mos  package/diy/openwrt-mos  #自带mosdns以及v2ray-geodata

#七、广告过滤
#1）adguardhome带核心安装。
rm -rf feeds/packages/net/adguardhome
rm -rf feeds/luci/applications/luci-app-adguardhome
rm -rf package/new/luci-app-adguardhome
#可以选择版本的luci-app-adguardhome
merge_package master https://github.com/Hyy2001X/AutoBuild-Packages.git package/new luci-app-adguardhome
#kiddin9的luci-app-adguardhome
#merge_package main https://github.com/kiddin9/kwrt-packages.gitt package/new adguardhome r8101 luci-app-openvpn-server
#sed -i 's/services/vpn/g' package/kiddin/luci-app-openvpn-server/luasrc/controller/openvpn-server.lua
#git clone -b master --single-branch https://github.com/kiddin9/openwrt-adguardhome package/diy/openwrt-adguardhome #编译不成功

# 添加内核
#v0.107.X内核
latest_version="$(curl -s https://github.com/AdguardTeam/AdGuardHome/tags | grep -Eo "v[0-9\.]+\-*r*c*[0-9]*.tar.gz" | sed -n '/[0-9][0-9]/p' | sed -n 1p | sed 's/.tar.gz//g')"

#v0.108.X内核，api里面没有v0.107.
#latest_version="$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/tags | grep -Eo "v0.108.0-b.+[0-9\.]" | head -n 1)"
#解压缩
wget https://github.com/AdguardTeam/AdGuardHome/releases/download/${latest_version}/AdGuardHome_linux_amd64.tar.gz&&tar -zxvf *.tar.gz
chmod 0755 AdGuardHome
chmod 0755 AdGuardHome/AdGuardHome
rm -rf *.tar.gz&&mkdir -p package/base-files/files/usr/bin&&mv AdGuardHome/AdGuardHome package/base-files/files/usr/bin/ #软件包安装，不能带核心0.108，否则不能成功

#2）ikoolproxy与openssl
#由于openssl从1.1.1升级到了3.0.10导致ikoolproxy无法下载证书。故只能退回。https://github.com/coolsnowwolf/lede/commit/7494eb16185a176de226f55e842cadf94f1c5a11
#rm -rf package/libs/openssl
#rm -rf include/openssl-module.mk
#w版本
#git clone -b main --single-branch https://github.com/ilxp/opensslw.git  package/libs/openssl

#merge_package main https://github.com/ilxp/luci-app-ikoolproxy.git package/new luci-app-ikoolproxy
git clone -b main --single-branch https://github.com/ilxp/luci-app-ikoolproxy.git package/diy/luci-app-ikoolproxy

#3）dnsfilter去广告广告kiddin9大神
#git clone --depth 1 https://github.com/kiddin9/luci-app-dnsfilter package/diy/luci-app-dnsfilter

#七、管控相关
#1） APP 过滤
rm -rf package/new/OpenAppFilter

git clone -b master --depth 1 https://github.com/destan19/OpenAppFilter.git package/diy/OpenAppFilter
sed -i 's/services/control/g' package/diy/OpenAppFilter/luci-app-oaf/luasrc/controller/appfilter.lua

#git clone -b master --depth 1 https://github.com/sbwml/OpenAppFilter.git  package/diy/OpenAppFilter
#sed -i 's/network/control/g' package/diy/OpenAppFilter/luci-app-oaf/luasrc/controller/appfilter.lua

#git clone -b master --depth 1 https://github.com/QiuSimons/OpenAppFilter-destan19  package/diy/OpenAppFilter
#sed -i 's/services/control/g' package/diy/OpenAppFilter/luci-app-oaf/luasrc/controller/appfilter.lua

#更新特征库
pushd package/diy/OpenAppFilter
#wget -qO - https://github.com/QiuSimons/OpenAppFilter-destan19/commit/9088cc2.patch | patch -p1 #失败
#wget https://www.openappfilter.com/assets/feature/feature2.0_cn_23.07.29.cfg -O ./open-app-filter/files/feature.cfg
wget https://github.com/ilxp/oaf/raw/main/feature.cfg -O ./open-app-filter/files/feature.cfg
popd
#翻译应用过滤
sed -i 's/App Filter/应用过滤/g' package/diy/OpenAppFilter/luci-app-oaf/luasrc/controller/appfilter.lua

#2、管控
rm -rf feeds/luci/applications/luci-app-control-webrestriction
rm -rf feeds/luci/applications/luci-app-accesscontrol
rm -rf feeds/luci/applications/luci-app-control-timewol
rm -rf feeds/luci/applications//luci-app-wol
rm -rf feeds/luci/applications/luci-app-control-weburl
rm -rf feeds/luci/applications/luci-app-timecontrol
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf package/new/custom/luci-app-wolplus

rm -rf feeds/luci/applications/luci-app-openvpn-server  #采用lienol的，会生成一个vpn的栏目
merge_package main https://github.com/Lienol/openwrt-package.git package/new luci-app-openvpn-server

#采用我自己的control
git clone -b main --depth 1 https://github.com/ilxp/openwrt-control  package/diy/openwrt-control

#zxlhhyccc大佬的 修复无法运行问题。
#时间控制accesscontrol,timecontrol网络唤醒wolplus，访问限制webrestriction， 过滤控制weburl
#merge_package master https://github.com/zxlhhyccc/bf-package-master.git package/new zxlhhyccc/luci-app-wolplus lean/luci-app-accesscontrol zxlhhyccc/luci-app-control-webrestriction
#sed -i 's/services/control/g' package/new/luci-app-accesscontrol/luasrc/controller/mia.lua
#sed -i 's/Internet Access Schedule Control/上网时间控制/g' package/new/luci-app-accesscontrol/luasrc/controller/mia.lua

#sed -i 's/Control/管控/g' package/lienol/luci-app-control-webrestriction/luasrc/controller/webrestriction.lua
#sed -i 's/Control/管控/g' package/lienol/luci-app-control-weburl/luasrc/controller/weburl.lua
#sed -i 's/Internet Time Control/上网时间控制/g' package/lienol/luci-app-timecontrol/luasrc/controller/timecontrol.lua
#sed -i 's/Control/管控/g' package/lienol/luci-app-timecontrol/luasrc/controller/timecontrol.lua
#sed -i 's/Control/管控/g' package/lienol/luci-app-control-timewol/luasrc/controller/timewol.lua
#sed -i 's/File Browser/文件浏览器/g' package/lienol/luci-app-filebrowser/luasrc/controller/filebrowser.lua

#Lienol大佬的，无法运行
#merge_package main https://github.com/Lienol/openwrt-package.git package/new luci-app-control-webrestriction luci-app-control-weburl luci-app-timecontrol luci-app-control-timewol luci-app-filebrowser
#sed -i 's/Access Control/访问限制/g' package/new/luci-app-control-webrestriction/luasrc/controller/webrestriction.lua
#sed -i 's/Control/管控/g' package/new/luci-app-control-webrestriction/luasrc/controller/webrestriction.lua
#sed -i 's/Control/管控/g' package/new/luci-app-control-weburl/luasrc/controller/weburl.lua
#sed -i 's/Internet Time Control/上网时间控制/g' package/new/luci-app-timecontrol/luasrc/controller/timecontrol.lua
#sed -i 's/Control/管控/g' package/new/luci-app-timecontrol/luasrc/controller/timecontrol.lua
#sed -i 's/Control/管控/g' package/new/luci-app-control-timewol/luasrc/controller/timewol.lua
#sed -i 's/File Browser/文件浏览器/g' package/new/luci-app-filebrowser/luasrc/controller/filebrowser.lua

#采用lean的上网时间控制（23.05分支luci一直显示收集信息） 采用timecontrol
#rm -rf feeds/luci/applications/luci-app-accesscontrol
#sed -i 's/services/control/g' feeds/luci/applications/luci-app-accesscontrol/luasrc/controller/mia.lua
#merge_package openwrt-23.05 https://github.com/coolsnowwolf/luci.git  package/new applications/luci-app-accesscontrol
#sed -i 's/services/control/g' package/new/luci-app-accesscontrol/luasrc/controller/mia.lua
#sed -i 's/Internet Access Schedule Control/上网时间控制/g' package/new/luci-app-accesscontrol/luasrc/controller/mia.lua

#八、其他luci-app
#1、turboacc去dns
rm -rf feeds/luci/applications/luci-app-turboacc
#merge_package master https://github.com/xiangfeidexiaohuo/openwrt-packages.git package/new patch/luci-app-turboacc

#适配官方openwrt(22.03/23.05/24.10) firewall4的turboacc 【lede不能使用】
merge_package luci https://github.com/chenmozhijin/turboacc.git package/turboacc luci-app-turboacc
#修改 bbr为bbr3
sed -i 's/kmod-tcp-bbr/kmod-tcp-bbr3/g' package/turboacc/luci-app-turboacc/Makefile

#2、京东签到 By Jerrykuku 作者已关闭了
#git clone --depth 1 https://github.com/jerrykuku/node-request.git package/new/node-request
#git clone --depth 1 https://github.com/jerrykuku/luci-app-jd-dailybonus.git package/new/luci-app-jd-dailybonus

#3、网易云音乐解锁 js
rm -rf feeds/applications/luci-app-unblockmusic
rm -rf package/new/luci-app-unblockneteasemusic
git clone -b js https://github.com/UnblockNeteaseMusic/luci-app-unblockneteasemusic package/new/luci-app-unblockneteasemusic
sed -i 's/解除网易云音乐播放限制/网易云音乐解锁/g' package/new/luci-app-unblockneteasemusic/root/usr/share/luci/menu.d/luci-app-unblockneteasemusic.json
sed -i 's, +node,,g' package/new/luci-app-unblockneteasemusic/Makefile
pushd package/new/luci-app-unblockneteasemusic
    wget -qO - https://github.com/UnblockNeteaseMusic/luci-app-unblockneteasemusic/commit/a880428.patch | patch -p1
popd

#4、filebrowser文件浏览器
#rm -rf feeds/luci/applications/luci-app-filebrowser
# filebrowser 文件浏览器
#merge_package main https://github.com/Lienol/openwrt-package package/custom luci-app-filebrowser
#sed -i 's/File Browser/文件浏览器/g' package/diy/luci-app-filebrowser/luasrc/controller/filebrowser.lua

#5、流量监视
git clone -b master --depth 1 https://github.com/brvphoenix/wrtbwmon.git package/new/wrtbwmon
git clone -b master --depth 1 https://github.com/brvphoenix/luci-app-wrtbwmon.git package/new/luci-app-wrtbwmon

#6、zerotier #lede自带的已经是在vpn栏目
rm -Rf feeds/luci/applications/luci-app-zerotier
rm -Rf feeds/packages/net/zerotier  #lede的版本新
merge_package master https://github.com/coolsnowwolf/packages.git feeds/packages/net net/zerotier
rm -Rf package/new/custom/luci-app-zerotier
rm -Rf package/new/luci-app-zerotier
merge_package main https://github.com/sbwml/openwrt_pkgs.git package/new luci-app-zerotier
#移动搭配vpn栏目
sed -i 's/services/vpn/g' package/new/luci-app-zerotier/root/usr/share/luci/menu.d/luci-app-zerotier.json

#sed -i 's/services/vpn/g' package/new/custom/luci-app-zerotier/root/usr/share/luci/menu.d/luci-app-zerotier.json

#7、终端ZSH工具
# DHDAXCW骷髅头的preset-terminal-tools.sh
mkdir -p files/root
pushd files/root
## Install oh-my-zsh
# Clone oh-my-zsh repository
git clone https://github.com/ohmyzsh/ohmyzsh ./.oh-my-zsh
# Install extra plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ./.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ./.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions ./.oh-my-zsh/custom/plugins/zsh-completions
# Get .zshrc dotfile
cp ../.././diydata/data/zsh/.zshrc .
popd
# Change default shell to zsh将系统/bin/ash/改为/usr/bin/zsh
sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd 
sed -i 's/\/bin\/bash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

#sbwml大神已经改成bash了。所以将bash改为zsh
sed -i 's/\/bin\/bash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

#8、Docker 容器
## QiuSimons大神
#rm -rf feeds/luci/applications/luci-app-dockerman
#rm -rf feeds/luci/collections/luci-lib-docker
#merge_package master https://github.com/lisaac/luci-app-dockerman.git feeds/luci/applications applications/luci-app-dockerman
#sed -i '/auto_start/d' feeds/luci/applications/luci-app-dockerman/root/etc/uci-defaults/luci-app-dockerman
#pushd feeds/packages
#wget -qO- https://github.com/openwrt/packages/commit/e2e5ee69.patch | patch -p1
#wget -qO- https://github.com/openwrt/packages/pull/20054.patch | patch -p1
#popd
#sed -i '/sysctl.d/d' feeds/packages/utils/dockerd/Makefile
#rm -rf ./feeds/luci/collections/luci-lib-docker
#merge_package master https://github.com/lisaac/luci-lib-docker.git package/new collections/luci-lib-docker

# sbwml大神 【00-prepare_base-6.6已经有了】
#rm -rf feeds/luci/applications/luci-app-dockerman
#git clone https://git.cooluc.com/sbwml/luci-app-dockerman -b openwrt-23.05 feeds/luci/applications/luci-app-dockerman
#rm -rf feeds/packages/utils/{docker,dockerd,containerd,runc}
#git clone https://github.com/sbwml/packages_utils_docker feeds/packages/utils/docker
#git clone https://github.com/sbwml/packages_utils_dockerd feeds/packages/utils/dockerd
#git clone https://github.com/sbwml/packages_utils_containerd feeds/packages/utils/containerd
#git clone https://github.com/sbwml/packages_utils_runc feeds/packages/utils/runc
#sed -i '/sysctl.d/d' feeds/packages/utils/dockerd/Makefile
#pushd feeds/packages
#patch -p1 <../.././diydata/data/patches/docker/0001-dockerd-fix-bridge-network.patch
#patch -p1 <../.././diydata/data/patches/docker/0002-docker-add-buildkit-experimental-support.patch
#patch -p1 <../.././diydata/data/patches/docker/0003-dockerd-disable-ip6tables-for-bridge-network-by-defa.patch
#popd

#9、全能推送（商店自己安装）
#rm -rf feeds/luci/applications/luci-app-pushbot
#git clone https://github.com/zzsj0928/luci-app-pushbot.git package/diy/luci-app-pushbot

#10、NIC driver - R8168 & R8125 & R8152 & R8101
git clone https://github.com/sbwml/package_kernel_r8168 package/kernel/r8168
git clone https://github.com/sbwml/package_kernel_r8152 package/kernel/r8152
git clone https://github.com/sbwml/package_kernel_r8101 package/kernel/r8101
git clone https://github.com/sbwml/package_kernel_r8125 package/kernel/r8125

#11、golang以及alist
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 24.x feeds/packages/lang/golang

rm -rf feeds/luci/applications/luci-app-alist
rm -rf feeds/packages/net/alist
git clone https://github.com/sbwml/luci-app-alist package/alist

#12、diskman
merge_package master https://github.com/lisaac/luci-app-diskman.git package/new applications/luci-app-diskman

#13、lan口设置  不能在workflow上打。（只能打成功lede的patch）（新版采用default-setting配置）
#rm -rf target/linux/x86/base-files/etc/board.d/02_network  #清除系统自带的02，需要lede的才能patche成功。
#wget -N https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/x86/base-files/etc/board.d/02_network -P target/linux/x86/base-files/etc/board.d/
#patch -p1 <./diydata/data/patches/def_set_interfaces_lan_wan.patch

#14、chatgpt
#git clone --depth=1 https://github.com/sirpdboy/luci-app-chatgpt-web package/luci-app-chatgpt

#15、在线升级（通过对链接的前缀10.16.2024进行比较大小进行升级）
 #原地址：https://github.com/ilxp/builder/releases/download/标签名/10.16.2024-oprx-x86-64-generic-squashfs-combined-efi.img.gz
 #原地址：https://github.com/ilxp/builder/releases/download/标签名/vermd5.txt  其中firmware为固定的tag名称。在Release发布的时候注意。
git clone https://github.com/ilxp/openwrt-gpsysupgrade-kiddin9  package/diy/openwrt-gpsysupgrade
#改固件（要先改）
sed -i "s/oprx/oprx-oP/g" package/diy/openwrt-gpsysupgrade/luci-app-gpsysupgrade/luasrc/model/cbi/gpsysupgrade/sysupgrade.lua
#改仓库名builder
sed -i "s/builder/oprx-builder/g" package/diy/openwrt-gpsysupgrade/luci-app-gpsysupgrade/luasrc/model/cbi/gpsysupgrade/sysupgrade.lua
#改vermd5名称：
sed -i "s/vermd5/vermd5-oP/g" package/diy/openwrt-gpsysupgrade/luci-app-gpsysupgrade/luasrc/model/cbi/gpsysupgrade/sysupgrade.lua
##全部调到系统菜单
sed -i 's/services/system/g' package/diy/openwrt-gpsysupgrade/luci-app-gpsysupgrade/luasrc/controller/*.lua
sed -i 's/services/system/g' package/diy/openwrt-gpsysupgrade/luci-app-gpsysupgrade/luasrc/view/admin_status/index/*.htm
sed -i 's/services/system/g' package/diy/openwrt-gpsysupgrade/luci-app-gpsysupgrade/luasrc/view/gpsysupgrade/*.htm

#2）autoupdate
git clone -b main --single-branch https://github.com/ilxp/openwrt-autoupdate.git  package/diy/openwrt-autoupdate
#将版本号以及固件的相关信息写入默认配置文件。
#cat >> package/diy/openwrt-autoupdate/autoupdate/files/etc/autoupdate/default <<EOF
#Author=ilxp
#Github=https://github.com/ilxp/oprx-builder
#TARGET_PROFILE=x86_64
#TARGET_BOARD=x86
#TARGET_SUBTARGET=64
#TARGET_FLAG=${TARGET_FLAG}
#OP_VERSION=${OP_VERSION}
#OP_AUTHOR=openwrt  
#OP_REPO=openwrt
#OP_BRANCH=openwrt-23.05

#EOF

#修改内容
#1）固件标签
sed -i "s/TARGET_FLAG=Full/TARGET_FLAG=oP/g" package/diy/openwrt-autoupdate/autoupdate/files/etc/autoupdate/default
#2）版本号：需要固定成：R24.1.1-20240101
#Build_DATE=$(date +%Y%m%d%H)  #日期+小时
#Short_Date=`TZ=UTC-8 date +%y.%-m.%-d`  #24年1月1日：24.1.1
Short_Date=$(TZ=UTC-8 date +'%y.%-m.%-d') #24年1月1日：24.1.1
Compile_Date=$(TZ=UTC-8 date +'%Y%m%d')
OP_VERSION="R${Short_Date}-${Compile_Date}"
sed -i "s/OP_VERSION=R24.1.1-20240101/OP_VERSION=$OP_VERSION/g" package/diy/openwrt-autoupdate/autoupdate/files/etc/autoupdate/default  #使用双引号
#3）源码作者
#sed -i 's/OP_AUTHOR=openwrt/OP_AUTHOR=openwrt/g' package/diy/openwrt-autoupdate/autoupdate/files/etc/autoupdate/default
#4）项目
#sed -i 's/OP_REPO=openwrt/OP_REPO=openwrt/g' package/diy/openwrt-autoupdate/autoupdate/files/etc/autoupdate/default
#5）分支
sed -i 's/OP_BRANCH=main/OP_BRANCH=openwrt-24.10/g' package/diy/openwrt-autoupdate/autoupdate/files/etc/autoupdate/default

#17、更换 Nodejs 版本
rm -rf feeds/packages/lang/node
git clone https://github.com/sbwml/feeds_packages_lang_node-prebuilt -b packages-24.10 feeds/packages/lang/node
#rm -rf ./feeds/packages/lang/node
#merge_package master https://github.com/QiuSimons/OpenWrt-Add  package/custom  feeds_packages_lang_node-prebuilt
#cp -rf ../package/custom/feeds_packages_lang_node-prebuilt ./feeds/packages/lang/node

#18、相关引擎
# Shortcut Forwarding Engine
git clone https://git.cooluc.com/sbwml/shortcut-fe package/new/shortcut-fe
# FullCone module
git clone https://git.cooluc.com/sbwml/nft-fullcone package/new/nft-fullcone
# IPv6 NAT
git clone https://github.com/sbwml/packages_new_nat6 package/new/nat6
# natflow
git clone https://github.com/sbwml/package_new_natflow package/new/natflow

#19、sbwml大神的优化
# x86 - disable intel_pstate & mitigations
sed -i 's/noinitrd/noinitrd intel_pstate=disable mitigations=off/g' target/linux/x86/image/grub-efi.cfg
# openssl -Ofast
sed -i "s/-O3/-Ofast/g" package/libs/openssl/Makefile
# procps-ng - top
sed -i 's/enable-skill/enable-skill --disable-modern-top/g' feeds/packages/utils/procps-ng/Makefile
# opkg  无法使用
#mkdir -p package/system/opkg/patches
#cp -rf ./diydata/data/patches/900-opkg-download-disable-hsts.patch ./package/system/opkg/patches/

# TTYD
sed -i 's/services/system/g' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
sed -i '3 a\\t\t"order": 50,' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
sed -i 's/procd_set_param stdout 1/procd_set_param stdout 0/g' feeds/packages/utils/ttyd/files/ttyd.init
sed -i 's/procd_set_param stderr 1/procd_set_param stderr 0/g' feeds/packages/utils/ttyd/files/ttyd.init

#20、autocore
rm -rf package/system/autocore  #sbwml的cpu使用率有问题。
git clone -b openwrt-24.10 --depth 1 https://github.com/sbwml/autocore-arm  package/system/autocore
sed -i '/init/d' package/system/autocore/Makefile
sed -i '/autocore.json/a\\	$(INSTALL_BIN) ./files/x86/autocore $(1)/etc/init.d/' package/system/autocore/Makefile
sed -i '/autocore.json/a\\	$(INSTALL_DIR) $(1)/etc/init.d' package/system/autocore/Makefile
cp -rf ./diydata/data/autocore  package/system/autocore/files/x86/  ##sbwml的cpu使用率有问题。采用yaof的

#采用immortalwrt的
# AutoCore
#merge_package openwrt-23.05 https://github.com/immortalwrt/immortalwrt.git package/new package/emortal/autocore
#sed -i 's/"getTempInfo" /"getTempInfo", "getCPUBench", "getCPUUsage" /g' package/new/autocore/files/luci-mod-status-autocore.json
#rm -rf ./package/new/autocore/files/autocore
#wget https://raw.githubusercontent.com/QiuSimons/OpenWrt-Add/master/autocore -O package/new/autocore/files/autocore
#sed -i '/i386 i686 x86_64/{n;n;n;d;}' package/new/autocore/Makefile
#sed -i '/i386 i686 x86_64/d' package/new/autocore/Makefile
#rm -rf ./feeds/luci/modules/luci-base
#merge_package openwrt-23.05 https://github.com/immortalwrt/luci.git feeds/luci/modules modules/luci-base
#sed -i "s,(br-lan),,g" feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci
#rm -rf ./feeds/luci/modules/luci-mod-status
#merge_package openwrt-23.05 https://github.com/immortalwrt/luci.git feeds/luci/modules modules/luci-mod-status
#rm -rf ./feeds/packages/utils/coremark
#merge_package master https://github.com/immortalwrt/packages.git feeds/packages/utils utils/coremark
#sed -i "s,-O3,-Ofast -funroll-loops -fpeel-loops -fgcse-sm -fgcse-las,g" feeds/packages/utils/coremark/Makefile
#merge_package openwrt-23.05 https://github.com/immortalwrt/immortalwrt.git package/utils package/utils/mhz

#17、samba4-luci
rm -rf feeds/luci/applications/luci-app-samba4
merge_package master https://github.com/openwrt/luci.git feeds/luci/applications applications/luci-app-samba4

# 17、移动栏目
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-hd-idle/root/usr/share/luci/menu.d/luci-app-hd-idle.json
sed -i 's/services/nas/g' feeds/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/luci-app-samba4.json
#for ledede luci18.06
#sed -i 's/services/nas/g' feeds/luci/applications/luci-app-samba4/luasrc/controller/samba4.lua

#21、 samba4 - bump version
rm -rf feeds/packages/net/samba4
git clone https://github.com/sbwml/feeds_packages_net_samba4 feeds/packages/net/samba4
# liburing - 2.7 (samba-4.21.0)
rm -rf feeds/packages/libs/liburing
git clone https://github.com/sbwml/feeds_packages_libs_liburing feeds/packages/libs/liburing
# enable multi-channel
sed -i '/workgroup/a \\n\t## enable multi-channel' feeds/packages/net/samba4/files/smb.conf.template
sed -i '/enable multi-channel/a \\tserver multi channel support = yes' feeds/packages/net/samba4/files/smb.conf.template
# default config
sed -i 's/#aio read size = 0/aio read size = 0/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/#aio write size = 0/aio write size = 0/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/invalid users = root/#invalid users = root/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/bind interfaces only = yes/bind interfaces only = no/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/#create mask/create mask/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/#directory mask/directory mask/g' feeds/packages/net/samba4/files/smb.conf.template
sed -i 's/0666/0644/g;s/0744/0755/g;s/0777/0755/g' feeds/luci/applications/luci-app-samba4/htdocs/luci-static/resources/view/samba4.js
sed -i 's/0666/0644/g;s/0777/0755/g' feeds/packages/net/samba4/files/samba.config
sed -i 's/0666/0644/g;s/0777/0755/g' feeds/packages/net/samba4/files/smb.conf.template

#22、USB 打印机与KMS 激活助手  #USB 打印机 会产生一个nas项目
merge_package master https://github.com/QiuSimons/OpenWrt-Add.git package/new openwrt_pkgs/luci-app-usb-printer

#23、KMS 激活助手
merge_package master https://github.com/QiuSimons/OpenWrt-Add.git package/new  openwrt_pkgs/luci-app-vlmcsd
merge_package master https://github.com/QiuSimons/OpenWrt-Add.git package/new  openwrt_pkgs/vlmcsd

#24、 清理内存
merge_package master https://github.com/QiuSimons/OpenWrt-Add.git package/new  openwrt_pkgs/luci-app-ramfree

#25、 OLED 驱动程序
git clone -b master --depth 1 https://github.com/NateLol/luci-app-oled.git package/new/luci-app-oled

#26、 natmap
git clone --depth 1 --branch master --single-branch --no-checkout https://github.com/muink/luci-app-natmapt.git package/luci-app-natmapt
pushd package/luci-app-natmapt
umask 022
git checkout
popd
git clone --depth 1 --branch master --single-branch --no-checkout https://github.com/muink/openwrt-natmapt.git package/natmapt
pushd package/natmapt
umask 022
git checkout
popd
git clone --depth 1 --branch master --single-branch --no-checkout https://github.com/muink/openwrt-stuntman.git package/stuntman
pushd package/stuntman
umask 022
git checkout
popd

# 22、UPX 可执行软件压缩  sbwml已经在mainline
#sed -i '/patchelf pkgconf/i\tools-y += ucl upx' ./tools/Makefile
#sed -i '\/autoconf\/compile :=/i\$(curdir)/upx/compile := $(curdir)/ucl/compile' ./tools/Makefile
##merge_package main https://github.com/Lienol/openwrt.git  ./tools tools/ucl tools/upx  #表示在根目录生成一个tools文件夹。本来就会有，所以报错。
##merge_package main https://github.com/Lienol/openwrt.git tools tools/ucl tools/upx  #表示在移动到根目录已经存在的tools文件夹。lienol版本有点旧3.95。
#merge_package main https://github.com/Lienol/openwrt.git tools tools/ucl
#merge_package main https://github.com/ilxp/upx-openwrt.git tools upx   #最新版4.2.4

#23 v2raya
git clone --depth 1 https://github.com/zxlhhyccc/luci-app-v2raya.git package/new/luci-app-v2raya
rm -rf ./feeds/packages/net/v2raya
merge_package master https://github.com/openwrt/packages.git package/new net/v2raya

#sbwml的Upnp 移动以及翻译
sed -i "s/network/services/g" feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json
# 精简 UPnP 菜单名称
#sed -i 's#\"title\": \"UPnP IGD \& PCP/NAT-PMP\"#\"title\": \"UPnP\"#g' feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json

##########################################################################

chmod -R 755 ./
find ./ -name *.orig | xargs rm -f
find ./ -name *.rej | xargs rm -f

exit 0