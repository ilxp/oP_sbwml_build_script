#注意md5的标签
#!/bin/bash -e
export RED_COLOR='\e[1;31m'
export GREEN_COLOR='\e[1;32m'
export YELLOW_COLOR='\e[1;33m'
export BLUE_COLOR='\e[1;34m'
export PINK_COLOR='\e[1;35m'
export SHAN='\e[1;33;5m'
export RES='\e[0m'

GROUP=
group() {
    endgroup
    echo "::group::  $1"
    GROUP=1
}
endgroup() {
    if [ -n "$GROUP" ]; then
        echo "::endgroup::"
    fi
    GROUP=
}

#####################################
#  NanoPi R4S OpenWrt Build Script  #
#####################################

# IP Location
ip_info=`curl -sk https://ip.cooluc.com`;
[ -n "$ip_info" ] && export isCN=`echo $ip_info | grep -Po 'country_code\":"\K[^"]+'` || export isCN=US


# script url
if [ "$isCN" = "CN" ]; then
    #export mirror=https://init.cooluc.com
	export mirror=https://raw.githubusercontent.com/ilxp/oP_sbwml_build_script/main
else
    #export mirror=https://init2.cooluc.com
    export mirror=https://raw.githubusercontent.com/ilxp/oP_sbwml_build_script/main
fi

# github actions - automatically retrieve `github raw` links
if [ "$(whoami)" = "runner" ] && [ -n "$GITHUB_REPO" ]; then
    export mirror=raw.githubusercontent.com/$GITHUB_REPO/main
fi

# github actions - caddy server
#if [ "$(whoami)" = "runner" ] && [ -z "$git_password" ]; then
    #export mirror=http://127.0.0.1:8080
#fi

# private gitea
export gitea=git.cooluc.com

# github mirror
if [ "$isCN" = "CN" ]; then
	#export github="gh-proxy.com/github.com"
	export github="github.com"
	code_mirror="git.cooluc.com"
else
    export github="github.com"
	code_mirror="github.com"
fi

# Check root
if [ "$(id -u)" = "0" ]; then
    echo -e "${RED_COLOR}Building with root user is not supported.${RES}"
    exit 1
fi

# Start time
starttime=`date +'%Y-%m-%d %H:%M:%S'`
CURRENT_DATE=$(date +%s)
#CURRENT_DATE2=$(date +%Y%m%d)
#CURRENT_DATE2=$(date +%m.%d.%Y)
CURRENT_DATE2=$(TZ=UTC-8 date +'%m.%d.%Y')

# Cpus
cores=`expr $(nproc --all) + 1`

# $CURL_BAR
if curl --help | grep progress-bar >/dev/null 2>&1; then
    CURL_BAR="--progress-bar";
fi

if [ -z "$1" ] || [ "$2" != "nanopi-r4s" -a "$2" != "nanopi-r5s" -a "$2" != "x86_64" -a "$2" != "netgear_r8500" -a "$2" != "armv8" ]; then
    echo -e "\n${RED_COLOR}Building type not specified.${RES}\n"
    echo -e "Usage:\n"
    echo -e "nanopi-r4s releases: ${GREEN_COLOR}bash build.sh rc2 nanopi-r4s${RES}"
    echo -e "nanopi-r4s snapshots: ${GREEN_COLOR}bash build.sh dev nanopi-r4s${RES}"
    echo -e "nanopi-r5s releases: ${GREEN_COLOR}bash build.sh rc2 nanopi-r5s${RES}"
    echo -e "nanopi-r5s snapshots: ${GREEN_COLOR}bash build.sh dev nanopi-r5s${RES}"
    echo -e "x86_64 releases: ${GREEN_COLOR}bash build.sh rc2 x86_64${RES}"
    echo -e "x86_64 snapshots: ${GREEN_COLOR}bash build.sh dev x86_64${RES}"
    echo -e "netgear-r8500 releases: ${GREEN_COLOR}bash build.sh rc2 netgear_r8500${RES}"
    echo -e "netgear-r8500 snapshots: ${GREEN_COLOR}bash build.sh dev netgear_r8500${RES}"
    echo -e "armsr-armv8 releases: ${GREEN_COLOR}bash build.sh rc2 armv8${RES}"
    echo -e "armsr-armv8 snapshots: ${GREEN_COLOR}bash build.sh dev armv8${RES}\n"
    exit 1
fi

# Source branch
if [ "$1" = "dev" ]; then
    export branch=openwrt-25.12
	#export branch=master
    export version=dev
elif [ "$1" = "rc2" ]; then
    latest_release="v$(curl -s $mirror/tags/v25)"
    export branch=$latest_release
    export version=rc2
fi

# lan
[ -n "$LAN" ] && export LAN=$LAN || export LAN=192.168.8.1

# platform
[ "$2" = "armv8" ] && export platform="armv8" toolchain_arch="aarch64_generic"
[ "$2" = "nanopi-r4s" ] && export platform="rk3399" toolchain_arch="aarch64_generic"
[ "$2" = "nanopi-r5s" ] && export platform="rk3568" toolchain_arch="aarch64_generic"
[ "$2" = "netgear_r8500" ] && export platform="bcm53xx" toolchain_arch="arm_cortex-a9"
[ "$2" = "x86_64" ] && export platform="x86_64" toolchain_arch="x86_64"

# gcc14 & 15
if [ "$USE_GCC13" = y ]; then
    export USE_GCC13=y gcc_version=13
elif [ "$USE_GCC14" = y ]; then
    export USE_GCC14=y gcc_version=14
elif [ "$USE_GCC15" = y ]; then
    export USE_GCC15=y gcc_version=15
elif [ "$USE_GCC16" = y ]; then
    export USE_GCC16=y gcc_version=16
else
    export USE_GCC15=y gcc_version=15
fi
[ "$ENABLE_MOLD" = y ] && export ENABLE_MOLD=y

# build.sh flags
export \
    ENABLE_BPF=$ENABLE_BPF \
    ENABLE_DPDK=$ENABLE_DPDK \
    ENABLE_GLIBC=$ENABLE_GLIBC \
    ENABLE_LRNG=$ENABLE_LRNG \
    KERNEL_CLANG_LTO=$KERNEL_CLANG_LTO \
    ROOT_PASSWORD=$ROOT_PASSWORD
	
export kernel_version=6.18

# print version
echo -e "\r\n${GREEN_COLOR}Building $branch${RES}\r\n"
if [ "$platform" = "x86_64" ]; then
    echo -e "${GREEN_COLOR}Model: x86_64${RES}"
elif [ "$platform" = "armv8" ]; then
    echo -e "${GREEN_COLOR}Model: armsr/armv8${RES}"
    [ "$1" = "rc2" ] && model="armv8"
elif [ "$platform" = "bcm53xx" ]; then
    echo -e "${GREEN_COLOR}Model: netgear_r8500${RES}"
    [ "$LAN" = "10.0.0.1" ] && export LAN="192.168.1.1"
elif [ "$platform" = "rk3568" ]; then
    echo -e "${GREEN_COLOR}Model: nanopi-r5s/r5c${RES}"
    [ "$1" = "rc2" ] && model="nanopi-r5s"
else
    echo -e "${GREEN_COLOR}Model: nanopi-r4s${RES}"
    [ "$1" = "rc2" ] && model="nanopi-r4s"
fi

# print build opt
#get_kernel_version=$(curl -s $mirror/tags/kernel-$kernel_version)
#kmod_hash=$(echo -e "$get_kernel_version" | awk -F'HASH-' '{print $2}' | awk '{print $1}' | tail -1 | md5sum | awk '{print $1}')
#kmodpkg_name=$(echo $(echo -e "$get_kernel_version" | awk -F'HASH-' '{print $2}' | awk '{print $1}')~$(echo $kmod_hash)-r1)
#echo -e "${GREEN_COLOR}Kernel: $kmodpkg_name ${RES}"

#curl -s $mirror/tags/kernel-6.12 > kernel.txt  #有时获取不到
#curl -s https://github.com/coolsnowwolf/lede/raw/master/include/kernel-$kernel_version  >> kernel.txt
wget -qO- "https://github.com/coolsnowwolf/lede/raw/master/include/kernel-$kernel_version"  >> kernel.txt
#wget -qO- "https://github.com/openwrt/openwrt/raw/$branch/target/linux/generic/kernel-$kernel_version"  >> kernel.txt

kmod_hash=$(grep HASH kernel.txt | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}')
kmodpkg_name=$(echo $(grep HASH kernel.txt | awk -F'HASH-' '{print $2}' | awk '{print $1}')~$(echo $kmod_hash)-r1)
echo -e "${GREEN_COLOR}Kernel: $kmodpkg_name ${RES}"
rm -f kernel.txt

echo -e "${GREEN_COLOR}Date: $CURRENT_DATE${RES}\r\n"
echo -e "${GREEN_COLOR}SCRIPT_URL:${RES} ${BLUE_COLOR}$mirror${RES}\r\n"
echo -e "${GREEN_COLOR}GCC VERSION: $gcc_version${RES}"
[ -n "$LAN" ] && echo -e "${GREEN_COLOR}LAN: $LAN${RES}" || echo -e "${GREEN_COLOR}LAN: 10.0.0.1${RES}"
[ "$ENABLE_GLIBC" = "y" ] && echo -e "${GREEN_COLOR}Standard C Library:${RES} ${BLUE_COLOR}glibc${RES}" || echo -e "${GREEN_COLOR}Standard C Library:${RES} ${BLUE_COLOR}musl${RES}"
[ "$ENABLE_OTA" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_OTA: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_OTA:${RES} ${YELLOW_COLOR}false${RES}"
[ "$ENABLE_DPDK" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_DPDK: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_DPDK:${RES} ${YELLOW_COLOR}false${RES}"
[ "$ENABLE_MOLD" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_MOLD: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_MOLD:${RES} ${YELLOW_COLOR}false${RES}"
[ "$ENABLE_BPF" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_BPF: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_BPF:${RES} ${RED_COLOR}false${RES}"
[ "$ENABLE_LTO" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_LTO: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_LTO:${RES} ${RED_COLOR}false${RES}"
[ "$ENABLE_LRNG" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_LRNG: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_LRNG:${RES} ${RED_COLOR}false${RES}"
[ "$ENABLE_LOCAL_KMOD" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_LOCAL_KMOD: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_LOCAL_KMOD: false${RES}"
[ "$BUILD_FAST" = "y" ] && echo -e "${GREEN_COLOR}BUILD_FAST: true${RES}" || echo -e "${GREEN_COLOR}BUILD_FAST:${RES} ${YELLOW_COLOR}false${RES}"
[ "$ENABLE_CCACHE" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_CCACHE: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_CCACHE:${RES} ${YELLOW_COLOR}false${RES}"
[ "$MINIMAL_BUILD" = "y" ] && echo -e "${GREEN_COLOR}MINIMAL_BUILD: true${RES}" || echo -e "${GREEN_COLOR}MINIMAL_BUILD: false${RES}"
[ "$KERNEL_CLANG_LTO" = "y" ] && echo -e "${GREEN_COLOR}KERNEL_CLANG_LTO: true${RES}\r\n" || echo -e "${GREEN_COLOR}KERNEL_CLANG_LTO:${RES} ${YELLOW_COLOR}false${RES}\r\n"

# clean old files
rm -rf openwrt master

# openwrt - releases
[ "$(whoami)" = "runner" ] && group "source code"
git clone --depth=1 https://$github/openwrt/openwrt -b $branch

#git clone --depth=1  https://$github/mj22226/openwrt -b linux-6.6

# immortalwrt master
git clone https://$github/immortalwrt/packages master/immortalwrt_packages --depth=1
[ "$(whoami)" = "runner" ] && endgroup

if [ -d openwrt ]; then
    cd openwrt
    curl -Os $mirror/openwrt/patch/key2.tar.gz && tar zxf key2.tar.gz && rm -f key2.tar.gz
	# upx压缩列表：【squashfs格式固件不需要造成双层压缩】
    #curl -s $mirror/openwrt/generic/upx_list.txt -o upx_list.txt
else
    echo -e "${RED_COLOR}Failed to download source code${RES}"
    exit 1
fi

# tags
if [ "$1" = "rc2" ]; then
    git describe --abbrev=0 --tags > version.txt
else
    git branch | awk '{print $2}' > version.txt
fi

# feeds mirror
if [ "$1" = "rc2" ]; then
    packages="^$(grep packages feeds.conf.default | awk -F^ '{print $2}')"
    luci="^$(grep luci feeds.conf.default | awk -F^ '{print $2}')"
    routing="^$(grep routing feeds.conf.default | awk -F^ '{print $2}')"
    telephony="^$(grep telephony feeds.conf.default | awk -F^ '{print $2}')"
else
    packages=";$branch"
    luci=";$branch"
    routing=";$branch"
    telephony=";$branch"
fi
cat > feeds.conf <<EOF
src-git packages https://$github/openwrt/packages.git$packages
src-git luci https://$github/openwrt/luci.git$luci
src-git routing https://$github/openwrt/routing.git$routing
src-git telephony https://$github/openwrt/telephony.git$telephony
EOF

# Init feeds
[ "$(whoami)" = "runner" ] && group "feeds update -a"
./scripts/feeds update -a
[ "$(whoami)" = "runner" ] && endgroup

[ "$(whoami)" = "runner" ] && group "feeds install -a"
./scripts/feeds install -a
[ "$(whoami)" = "runner" ] && endgroup

# loader dl
if [ -f ../dl.gz ]; then
    tar xf ../dl.gz -C .
fi

###############################################
echo -e "\n${GREEN_COLOR}Patching ...${RES}\n"

# scripts
curl -sO $mirror/openwrt/scripts/00-prepare_base-oprx.sh
curl -sO $mirror/openwrt/scripts/01-prepare_base-mainline-oprx-$kernel_version.sh
curl -sO $mirror/openwrt/scripts/02-prepare_package-oprx.sh
curl -sO $mirror/openwrt/scripts/03-convert_translation.sh
curl -sO $mirror/openwrt/scripts/04-fix_kmod.sh
curl -sO $mirror/openwrt/scripts/05-fix-source.sh
curl -sO $mirror/openwrt/scripts/99_clean_build_cache.sh
if [ -n "$git_password" ] && [ -n "$private_url" ]; then
    curl -u openwrt:$git_password -sO "$private_url"
else
    curl -sO $mirror/openwrt/scripts/10-custom.sh
	curl -sO $mirror/openwrt/scripts/10-custom-oprx-oP.sh
fi
chmod 0755 *sh
[ "$(whoami)" = "runner" ] && group "patching openwrt"
bash 00-prepare_base-oprx.sh
bash 01-prepare_base-mainline-oprx-$kernel_version.sh
bash 02-prepare_package-oprx.sh
bash 03-convert_translation.sh
bash 04-fix_kmod.sh
bash 05-fix-source.sh
[ -f "10-custom.sh" ] && bash 10-custom.sh
[ -f "10-custom-oprx-oP.sh" ] && bash 10-custom-oprx-oP.sh
find feeds -type f -name "*.orig" -exec rm -f {} \;
[ "$(whoami)" = "runner" ] && endgroup

rm -f 0*-*.sh 10-custom.sh 10-custom-oprx-oP.sh
rm -rf ../master

# Load devices Config
if [ "$platform" = "x86_64" ]; then
    curl -s $mirror/openwrt/configs/25-config-musl-x86-oprx > .config
elif [ "$platform" = "bcm53xx" ]; then
    if [ "$MINIMAL_BUILD" = "y" ]; then
        curl -s $mirror/openwrt/configs/24-config-musl-r8500-minimal > .config
    else
        curl -s $mirror/openwrt/configs/24-config-musl-r8500 > .config
    fi
    sed -i '1i\# CONFIG_PACKAGE_kselftests-bpf is not set\n# CONFIG_PACKAGE_perf is not set\n' .config
elif [ "$platform" = "rk3568" ]; then
    curl -s $mirror/openwrt/configs/24-config-musl-r5s > .config
elif [ "$platform" = "armv8" ]; then
    curl -s $mirror/openwrt/configs/24-config-musl-armsr-armv8 > .config
else
    curl -s $mirror/openwrt/configs/24-config-musl-r4s > .config
fi

# config-common
if [ "$MINIMAL_BUILD" = "y" ]; then
    curl -s $mirror/openwrt/configs/25-config-minimal-common >> .config
    echo 'VERSION_TYPE="minimal"' >> package/base-files/files/usr/lib/os-release
elif [ "$STD_BUILD" = "y" ]; then
    curl -s $mirror/openwrt/configs/25-config-std-common >> .config
    echo 'VERSION_TYPE="standard"' >> package/base-files/files/usr/lib/os-release
else
    curl -s $mirror/openwrt/configs/25-config-common-oprx >> .config
    [ "$platform" = "armv8" ] && sed -i '/DOCKER/Id' .config
fi

# ota
[ "$ENABLE_OTA" = "y" ] && [ "$version" = "rc2" ] && echo 'CONFIG_PACKAGE_luci-app-ota=y' >> .config

# bpf
curl -s $mirror/openwrt/generic/config-bpf >> .config
[ "$ENABLE_BPF" != "y" ] && sed -i '/KERNEL_DEBUG_INFO\|KERNEL_MODULE_ALLOW_BTF/d' .config

# LTO
export ENABLE_LTO=$ENABLE_LTO
[ "$ENABLE_LTO" = "y" ] && curl -s $mirror/openwrt/generic/config-lto >> .config

# glibc
[ "$ENABLE_GLIBC" = "y" ] && {
    curl -s $mirror/openwrt/generic/config-glibc >> .config
    sed -i '/NaiveProxy/d' .config
}

# DPDK
[ "$ENABLE_DPDK" = "y" ] && {
    echo 'CONFIG_PACKAGE_dpdk-tools=y' >> .config
    echo 'CONFIG_PACKAGE_numactl=y' >> .config
}

# istore
[ "$ENABLE_ISTORE" = "y" ] && {
    echo 'CONFIG_PACKAGE_luci-app-store=y' >> .config
    echo 'CONFIG_PACKAGE_luci-app-quickstart=y' >> .config
}

# mold
[ "$ENABLE_MOLD" = "y" ] && echo 'CONFIG_USE_MOLD=y' >> .config

# kernel - CLANG + LTO; Allow CONFIG_KERNEL_CC=clang / clang-18 / clang-xx
if [ "$KERNEL_CLANG_LTO" = "y" ]; then
    echo '# Kernel - CLANG LTO' >> .config
    if [ "$USE_GCC15" = "y" ] || [ "$USE_GCC16" = "y" ] && [ "$ENABLE_CCACHE" = "y" ]; then
        echo 'CONFIG_KERNEL_CC="ccache clang"' >> .config
    else
        echo 'CONFIG_KERNEL_CC="clang"' >> .config
    fi
    echo 'CONFIG_EXTRA_OPTIMIZATION=""' >> .config
    echo '# CONFIG_PACKAGE_kselftests-bpf is not set' >> .config
fi

# kernel - enable LRNG
if [ "$ENABLE_LRNG" = "y" ]; then
    echo -e "\n# Kernel - LRNG" >> .config
    echo "CONFIG_KERNEL_LRNG=y" >> .config
    echo "# CONFIG_PACKAGE_urandom-seed is not set" >> .config
    echo "# CONFIG_PACKAGE_urngd is not set" >> .config
fi

# local kmod
if [ "$ENABLE_LOCAL_KMOD" = "y" ]; then
    echo -e "\n# local kmod" >> .config
    echo "CONFIG_TARGET_ROOTFS_LOCAL_PACKAGES=y" >> .config
fi

# gcc config
echo -e "\n# gcc ${gcc_version}" >> .config
echo -e "CONFIG_DEVEL=y" >> .config
echo -e "CONFIG_TOOLCHAINOPTS=y" >> .config
echo -e "CONFIG_GCC_USE_VERSION_${gcc_version}=y\n" >> .config

# uhttpd
[ "$ENABLE_UHTTPD" = "y" ] && sed -i '/nginx/d' .config && echo 'CONFIG_PACKAGE_ariang=y' >> .config

# not all kmod
[ "$NO_KMOD" = "y" ] && sed -i '/CONFIG_ALL_KMODS=y/d; /CONFIG_ALL_NONSHARED=y/d' .config

# build wwan pkgs for openwrt_core
[ "$OPENWRT_CORE" = "y" ] && curl -s $mirror/openwrt/generic/config-wwan >> .config

# build mt7927-firmware pkgs for openwrt_core
[ "$OPENWRT_CORE" = "y" ] && echo 'CONFIG_PACKAGE_kmod-mt7927-firmware=m' >> .config

# ccache
if [ "$ENABLE_CCACHE" = "y" ]; then
    echo "CONFIG_CCACHE=y" >> .config
    [ "$(whoami)" = "runner" ] && echo "CONFIG_CCACHE_DIR=\"/builder/.ccache\"" >> .config
    [ "$(whoami)" = "sbwml" ] && echo "CONFIG_CCACHE_DIR=\"/home/sbwml/.ccache\"" >> .config
    tools_suffix="_ccache"
fi

# nanopi-r76s
[ "$platform" = "rk3576" ] && {
    sed -i '/samba4/d' .config
    sed -i '/qbittorrent/d' .config
}

# add to core
[ "$OPENWRT_CORE" = "y" ] && curl -s $mirror/openwrt/generic/config-build-only >> .config

# Toolchain Cache
if [ "$BUILD_FAST" = "y" ]; then
    [ "$ENABLE_GLIBC" = "y" ] && LIBC=glibc || LIBC=musl
    echo -e "\n${GREEN_COLOR}Download Toolchain ...${RES}"
    PLATFORM_ID=""
    [ -f /etc/os-release ] && source /etc/os-release
    if [ "$PLATFORM_ID" = "platform:el10" ]; then
        TOOLCHAIN_URL="http://127.0.0.1:8080"
    else
        TOOLCHAIN_URL=https://"$github_proxy"github.com/sbwml/openwrt_caches/releases/download/openwrt-25.12
    fi
    curl -L ${TOOLCHAIN_URL}/toolchain_${LIBC}_${toolchain_arch}_gcc-${gcc_version}${tools_suffix}.tar.zst -o toolchain.tar.zst $CURL_BAR
    echo -e "\n${GREEN_COLOR}Process Toolchain ...${RES}"
    tar -I "zstd" -xf toolchain.tar.zst
    rm -f toolchain.tar.zst
    mkdir bin
    find ./staging_dir/ -name '*' -exec touch {} \; >/dev/null 2>&1
    find ./tmp/ -name '*' -exec touch {} \; >/dev/null 2>&1
fi

# init openwrt config
rm -rf tmp/*
if [ "$BUILD" = "n" ]; then
    exit 0
else
    make defconfig
fi

# Compile
if [ "$BUILD_TOOLCHAIN" = "y" ]; then
    echo -e "\r\n${GREEN_COLOR}Building Toolchain ...${RES}\r\n"
    make -j$cores toolchain/compile || make -j$cores toolchain/compile V=s || exit 1
    mkdir -p toolchain-cache
    [ "$ENABLE_GLIBC" = "y" ] && LIBC=glibc || LIBC=musl
    tar -I "zstd -19 -T$(nproc --all)" -cf toolchain-cache/toolchain_${LIBC}_${toolchain_arch}_gcc-${gcc_version}${tools_suffix}.tar.zst ./{build_dir,dl,staging_dir,tmp}
    echo -e "\n${GREEN_COLOR} Build success! ${RES}"
    exit 0
else
    echo -e "\r\n${GREEN_COLOR}Building OpenWrt ...${RES}\r\n"
    sed -i "/BUILD_DATE/d" package/base-files/files/usr/lib/os-release
    sed -i "/BUILD_ID/aBUILD_DATE=\"$CURRENT_DATE\"" package/base-files/files/usr/lib/os-release
    make -j$cores IGNORE_ERRORS="n m"
fi

# Compile time
endtime=`date +'%Y-%m-%d %H:%M:%S'`
start_seconds=$(date --date="$starttime" +%s);
end_seconds=$(date --date="$endtime" +%s);
SEC=$((end_seconds-start_seconds));


if [ -f bin/targets/*/*/sha256sums ]; then
    echo -e "${GREEN_COLOR} Build success! ${RES}"
    echo -e " Build time: $(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s"
else
    echo -e "\n${RED_COLOR} Build error... ${RES}"
    echo -e " Build time: $(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s"
    echo
    exit 1
fi

#####SOUP系统升级工具需要API相关函数（json格式）###########

# ============================================================
# soup JSON 辅助函数
# ============================================================
# ---- 转义字符串供 JSON 使用(含首尾引号) ----
# 用法: JSON_ESC "字符串"
JSON_ESC()  { printf '%s' "$1" | jq -Rs .; }

# ---- 从 markdown 文件生成 JSON 字符串(带引号) ----
# 用法: JSON_LOGS "logs.md"
JSON_LOGS() { if [ -f "$1" ]; then jq -Rs . < "$1"; else printf '""'; fi; }

# ============================================================
# 变量定义
# ============================================================
Build_DATE=$(TZ=UTC-8 date +'%Y%m%d%H')

if [ "$1" = "dev" ]; then
    Short_Date=$(TZ=UTC-8 date +'%y.%-m.%-d')
    OP_VERSION="${Short_Date}-${Build_DATE}"    # 如 26.10.1-2026100112

elif [ "$1" = "rc2" ]; then
    VERSION=$(sed 's/v//g' version.txt)
    OP_VERSION="${VERSION}-${Build_DATE}"       # 如 25.12.5-2026100112
fi

Soup_TAG="oP"
Soup_PREFIX="OprX"
Soup_DATE="${Build_DATE}"
Soup_URL="https://github.com/ilxp/oprx-release/releases/download/firmware"

### 日志logs.md的存放目录 ########
# ============================================================
# 从 mirror 远端拉取 logs.md
#   适用场景: build-oprx.sh 通过 bash <(curl ...) 执行,
#             $0 = /dev/fd/63,无法推断本地路径。
#   前提: 脚本仓库是 public,raw URL 可直接访问。
#   logs.md 位置: eS_lede_build_script/logs.md (仓库根)
# ============================================================
LOGS_URL="${mirror}/logs.md"
Soup_LOGS_JSON='""'
if curl -fsSL "$LOGS_URL" -o /tmp/.soup_logs.md 2>/dev/null && [ -s /tmp/.soup_logs.md ]; then
    Soup_LOGS_JSON=$(JSON_LOGS /tmp/.soup_logs.md)
    echo "[soup] 已从远端加载日志: ($(wc -c < /tmp/.soup_logs.md) 字节)"
    rm -f /tmp/.soup_logs.md
else
    echo "[soup] 警告: 无法加载日志: $LOGS_URL" >&2
fi

# ============================================================
# 固件更名:mv + 打印提示
#   _rename_fw <src> <dst>
#   成功返回 0(并打印),失败返回 1(源文件不存在)
# ============================================================
_rename_fw() {
    local src="$1" dst="$2"
    [ -f "$src" ] || return 1
    mv -f "$src" "$dst"
    echo "[soup] 固件已更名为: $(basename "$dst")"
    return 0
}

# ============================================================
# JSON 条目累积器(跨平台共用)
#   _add_json_item <profile> <file>   添加一条(文件不存在则静默跳过)
#   _emit_json      <outfile>         输出所有 profile 的 JSON
# ============================================================
declare -a _JSON_KEYS=()
declare -A _JSON_DATA=()

_add_json_item() {
    local profile="$1" file="$2"
    [ -f "$file" ] || return 0

    local size sha item
    size=$(wc -c < "$file")
    sha=$(sha256sum "$file" | awk '{print $1}')
    item=$(printf '    {\n      "build_date": "%s",\n      "name": "%s",\n      "re_url": "%s",\n      "size": %s,\n      "sha256sum": "%s",\n      "logs": %s\n    }' \
        "$Soup_DATE" "$(basename "$file")" "$Soup_URL" "$size" "$sha" "$Soup_LOGS_JSON")

    if [ -z "${_JSON_DATA[$profile]+x}" ]; then
        _JSON_KEYS+=("$profile")
        _JSON_DATA[$profile]="$item"
    else
        _JSON_DATA[$profile]="${_JSON_DATA[$profile]},
${item}"
    fi
}

_emit_json() {
    local outfile="$1"
    if [ ${#_JSON_KEYS[@]} -eq 0 ]; then
        echo "[soup] 警告: 无固件条目,跳过 $outfile" >&2
        return 1
    fi
    mkdir -p "$(dirname "$outfile")"

    {
        echo "{"
        local i key body
        for i in "${!_JSON_KEYS[@]}"; do
            key="${_JSON_KEYS[$i]}"
            body="${_JSON_DATA[$key]}"
            [ "$i" -gt 0 ] && echo ","
            printf '  "%s": [\n%s\n  ]' "$key" "$body"
        done
        echo
        echo "}"
    } > "$outfile"

    echo "[soup] JSON 文件已生成: $outfile"
}

#####################################################

# ============================================================
# x86_64
# ============================================================
if [ "$platform" = "x86_64" ]; then
    if [ "$NO_KMOD" != "y" ]; then
        cp -a bin/targets/x86/*/packages $kmodpkg_name
        rm -f $kmodpkg_name/Packages*
        cp -a bin/packages/x86_64/base/*firmware*.ipk $kmodpkg_name/
        bash kmod-sign $kmodpkg_name
        tar zcf x86_64-$kmodpkg_name.tar.gz $kmodpkg_name
        rm -rf $kmodpkg_name
    fi

    # ---- OTA JSON ----
    X86_DIR=$(ls -d bin/targets/x86/64* 2>/dev/null | head -1)

    EFI_NEW="$X86_DIR/$Soup_PREFIX-openwrt-${Soup_TAG}${OP_VERSION}-x86_64-squashfs-combined-uefi.img.gz"
    BIOS_NEW="$X86_DIR/$Soup_PREFIX-openwrt-${Soup_TAG}${OP_VERSION}-x86_64-squashfs-combined-bios.img.gz"

    EFI_SRC="$X86_DIR/openwrt-x86-64-generic-squashfs-combined-efi.img.gz"
    BIOS_SRC="$X86_DIR/openwrt-x86-64-generic-squashfs-combined.img.gz"

    # 重命名固件
    _rename_fw "$EFI_SRC"  "$EFI_NEW"
    _rename_fw "$BIOS_SRC" "$BIOS_NEW"

    _add_json_item "x86_64" "$EFI_NEW"
    _add_json_item "x86_64" "$BIOS_NEW"
    _emit_json "soup/${Soup_TAG}.json"

    # Backup download cache
    if [ "$isCN" = "CN" ] && [ "$1" = "rc2" ]; then
        rm -rf dl/geo* dl/go-mod-cache
        tar cf ../dl.gz dl
    fi
    exit 0
fi

# ============================================================
# armv8
# ============================================================
if [ "$platform" = "armv8" ]; then
    if [ "$NO_KMOD" != "y" ]; then
        cp -a bin/targets/armsr/armv8*/packages $kmodpkg_name
        rm -f $kmodpkg_name/Packages*
        cp -a bin/packages/aarch64_generic/base/*firmware*.ipk $kmodpkg_name/
        cp -a bin/packages/aarch64_generic/base/*natflow*.ipk $kmodpkg_name/
        bash kmod-sign $kmodpkg_name
        tar zcf armv8-$kmodpkg_name.tar.gz $kmodpkg_name
        rm -rf $kmodpkg_name
    fi

    # ---- OTA JSON ----
    if [ "$1" = "rc2" ]; then
        ARMV8_DIR=$(ls -d bin/targets/armsr/armv8* 2>/dev/null | head -1)
        NEW="$ARMV8_DIR/$Soup_PREFIX-openwrt-${Soup_TAG}${OP_VERSION}-armsr-armv8-squashfs-combined-efi.img.gz"
        SRC="$ARMV8_DIR/openwrt-armsr-armv8-generic-squashfs-combined-efi.img.gz"

        _rename_fw "$SRC" "$NEW"

        _add_json_item "armsr,armv8" "$NEW"
        _emit_json "soup/${Soup_TAG}.json"
    fi
    exit 0
fi

# ============================================================
# bcm53xx (netgear r8500)
# ============================================================
if [ "$platform" = "bcm53xx" ]; then
    if [ "$NO_KMOD" != "y" ]; then
        cp -fp bin/targets/bcm53xx/generic/packages $kmodpkg_name
        rm -f $kmodpkg_name/Packages*
        cp -fp bin/packages/arm_cortex-a9/base/*firmware*.ipk $kmodpkg_name/
        cp -fp bin/packages/arm_cortex-a9/base/*natflow*.ipk $kmodpkg_name/
        bash kmod-sign $kmodpkg_name
        tar zcf bcm53xx-$kmodpkg_name.tar.gz $kmodpkg_name
        rm -rf $kmodpkg_name
    fi

    # ---- OTA JSON ----
    if [ "$1" = "dev" ]; then
        CHK_SRC=$(ls bin/targets/bcm53xx/generic/*-bcm53xx-generic-netgear_r8500-squashfs.chk 2>/dev/null | head -1)
        if [ -n "$CHK_SRC" ]; then
            CHK_DIR=$(dirname "$CHK_SRC")
            NEW="$CHK_DIR/$Soup_PREFIX-openwrt-${Soup_TAG}${OP_VERSION}-netgear_r8500-squashfs.chk"
            _rename_fw "$CHK_SRC" "$NEW"

            _add_json_item "netgear,r8500" "$NEW"
            _emit_json "soup/${Soup_TAG}.json"
        fi
    fi
    exit 0
fi

# ============================================================
# rockchip (nanopi 系列)
# ============================================================
if [ "$NO_KMOD" != "y" ] && [ "$platform" != "rk3399" ]; then
    cp -a bin/targets/rockchip/armv8*/packages $kmodpkg_name
    rm -f $kmodpkg_name/Packages*
    cp -a bin/packages/aarch64_generic/base/*firmware*.ipk $kmodpkg_name/
    cp -a bin/packages/aarch64_generic/base/*natflow*.ipk $kmodpkg_name/
    bash kmod-sign $kmodpkg_name
    tar zcf aarch64-$kmodpkg_name.tar.gz $kmodpkg_name
    rm -rf $kmodpkg_name
fi

# ---- OTA JSON ----
if [ "$1" = "rc2" ]; then
    R_DIR=$(ls -d bin/targets/rockchip/armv8* 2>/dev/null | head -1)

    case "$model" in
        nanopi-r4s)
            NEW="$R_DIR/$Soup_PREFIX-openwrt-${Soup_TAG}${OP_VERSION}-nanopi-r4s-squashfs-sysupgrade.img.gz"
            SRC="$R_DIR/openwrt-rockchip-armv8-friendlyarm_nanopi-r4s-squashfs-sysupgrade.img.gz"
            _rename_fw "$SRC" "$NEW"
            _add_json_item "friendlyarm,nanopi-r4s" "$NEW"
        ;;
        nanopi-r5s)
            NEW_C="$R_DIR/$Soup_PREFIX-openwrt-${Soup_TAG}${OP_VERSION}-nanopi-r5c-squashfs-sysupgrade.img.gz"
            NEW_S="$R_DIR/$Soup_PREFIX-openwrt-${Soup_TAG}${OP_VERSION}-nanopi-r5s-squashfs-sysupgrade.img.gz"
            SRC_C="$R_DIR/openwrt-rockchip-armv8-friendlyarm_nanopi-r5c-squashfs-sysupgrade.img.gz"
            SRC_S="$R_DIR/openwrt-rockchip-armv8-friendlyarm_nanopi-r5s-squashfs-sysupgrade.img.gz"
            _rename_fw "$SRC_C" "$NEW_C"
            _rename_fw "$SRC_S" "$NEW_S"
            _add_json_item "friendlyarm,nanopi-r5c" "$NEW_C"
            _add_json_item "friendlyarm,nanopi-r5s" "$NEW_S"
        ;;
        nanopi-r76s)
            NEW="$R_DIR/$Soup_PREFIX-openwrt-${Soup_TAG}${OP_VERSION}-nanopi-r76s-squashfs-sysupgrade.img.gz"
            SRC="$R_DIR/openwrt-rockchip-armv8-friendlyarm_nanopi-r76s-squashfs-sysupgrade.img.gz"
            _rename_fw "$SRC" "$NEW"
            _add_json_item "friendlyarm,nanopi-r76s" "$NEW"
        ;;
    esac

    _emit_json "soup/${Soup_TAG}.json"
fi

# Backup download cache
if [ "$isCN" = "CN" ] && [ "$1" = "rc2" ]; then
    rm -rf dl/geo* dl/go-mod-cache
    tar -cf ../dl.gz dl
fi
exit 0

# 很少有人会告诉你为什么要这样做，而是会要求你必须要这样做。
