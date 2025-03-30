#!/bin/bash

# 导入统一反馈函数
source ./init.sh

# 设置源码目录名称变量
# 使用init.sh中导出的SOURCE_DIR变量
if [ -z "$SOURCE_DIR" ]; then
  error_msg "SOURCE_DIR变量未设置，请确保init.sh脚本正确执行"
fi

# 进入源码目录
if [ ! -d "$SOURCE_DIR" ]; then
  error_msg "源码目录 '$SOURCE_DIR' 不存在，请先运行clone.sh脚本克隆源码"
fi

cd $SOURCE_DIR || error_msg "无法进入源码目录 '$SOURCE_DIR'"

info_msg "开始进行自定义配置调整..."

# 加载自定义配置文件
[ -f "../customization/tweak_options" ] && source "../customization/tweak_options"

# 查找OpenWrt源码中默认的管理页面IP
find ./ -type f -exec grep -l "192.168" {} \;

# 修改源码中的默认管理页面IP为192.168.2.1
#@lan_ip_mod@管理页面IP修改模块
if [ "$lan_ip_mod" = "1" ]; then
    find ./ -type f -exec grep -l "192.168" {} \;
    find ./ -type f -exec sed -i "s/192.168.[0-9]\\{1,3\\}.1/${lan_ip_address}/g" {} \;
fi

# 检查package/base-files/files/bin/config_generate文件
if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i "s/192.168.[0-9]\\{1,3\\}.1/${lan_ip_address}/g" package/base-files/files/bin/config_generate
    success_msg "已修改config_generate中的默认IP地址"
fi

# 检查package/network/config/firewall/files/firewall.config文件
if [ -f package/network/config/firewall/files/firewall.config ]; then
    sed -i "s/192.168.[0-9]\\{1,3\\}.1/${lan_ip_address}/g" package/network/config/firewall/files/firewall.config
    success_msg "已修改firewall.config中的默认IP地址"
fi
# 修改ttyd配置，注释掉interface相关配置
# 效果：注释后ttyd服务将不再绑定到特定网络接口，而是监听所有可用接口，如修改了lan IP，而下列的内容没有被注释，将导致ttyd服务无法启动。
#@ttyd_interface@ttyd接口配置修改模块
if [ "$ttyd_interface" = "1" ]; then
    if [ -f /etc/init.d/ttyd ]; then
        sed -i 's/${interface:+-i $interface}/#${interface:+-i $interface}/g' /etc/init.d/ttyd
        success_msg "已注释ttyd中的interface配置"
    fi
fi

# 调整rootfs分区大小
#@rootfs_size@rootfs分区大小修改模块
if [ "$rootfs_size" -gt 0 ] 2>/dev/null; then
    if [ -f target/linux/*/image/Makefile ]; then
        sed -i "s/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=$rootfs_size/g" target/linux/*/image/Makefile
        success_msg "已将rootfs分区大小设置为${rootfs_size}MB"
    fi
fi

# 控制是否编译toolchain、SDK和image builder
#@build_options@编译选项控制模块
if [ -f .config ]; then
    # 设置toolchain编译选项
    if [ "$toolchain_build" = "1" ]; then
        sed -i 's/# CONFIG_MAKE_TOOLCHAIN is not set/CONFIG_MAKE_TOOLCHAIN=y/' .config
        success_msg "已启用toolchain编译"
    else
        sed -i 's/CONFIG_MAKE_TOOLCHAIN=y/# CONFIG_MAKE_TOOLCHAIN is not set/' .config
        info_msg "已禁用toolchain编译"
    fi

    # 设置SDK编译选项
    if [ "$sdk_build" = "1" ]; then
        sed -i 's/# CONFIG_SDK is not set/CONFIG_SDK=y/' .config
        success_msg "已启用SDK编译"
    else
        sed -i 's/CONFIG_SDK=y/# CONFIG_SDK is not set/' .config
        info_msg "已禁用SDK编译"
    fi

    # 设置image builder编译选项
    if [ "$image_builder_build" = "1" ]; then
        sed -i 's/# CONFIG_IB is not set/CONFIG_IB=y/' .config
        success_msg "已启用image builder编译"
    else
        sed -i 's/CONFIG_IB=y/# CONFIG_IB is not set/' .config
        info_msg "已禁用image builder编译"
    fi
fi
