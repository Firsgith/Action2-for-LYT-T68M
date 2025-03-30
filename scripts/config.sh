#!/bin/bash

# 导入统一反馈函数
source "$(dirname "$0")/init.sh" "$1"

# 检查源码目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
  error_msg "源码目录不存在：$SOURCE_DIR"
fi

# 进入源码目录
cd "$SOURCE_DIR" || error_msg "无法进入源码目录"

# 检查并加载配置文件
# 如果存在自定义配置文件，则使用它
# 否则生成默认配置
# 处理多个配置文件
config_files=$(find ../config -name '*.config' -printf '%T@ %p\n' | sort -n | cut -d' ' -f2-)

if [ -n "$config_files" ]; then
  # 获取最新修改的有效配置文件
  valid_config=""
  for cfg in $config_files; do
    if grep -q "CONFIG_TARGET_rockchip" "$cfg"; then
      valid_config="$cfg"
      break
    fi
  done
  
  if [ -n "$valid_config" ]; then
    cp -f "$valid_config" .config
    info_msg "使用配置文件: $(basename $valid_config)"
    # 加载tweak_options配置
    if [ -f "../customization/tweak_options" ]; then
      source "../customization/tweak_options"
      # 只在ccache_enable=1时调用ccache.sh脚本处理ccache配置
      if [ "$ccache_enable" = "1" ]; then
        chmod +x ../scripts/ccache.sh
        ../scripts/ccache.sh config
      fi
    fi
    # 使用make defconfig和make oldconfig生成配置
    make defconfig > /dev/null 2>&1
    make oldconfig > /dev/null 2>&1
    success_msg "配置文件应用成功，共修改了$(grep -v '^#' .config | wc -l)项配置"
  else
    info_msg "未找到有效配置文件，使用默认配置"
    make defconfig > /dev/null 2>&1
    success_msg "默认配置生成成功，共包含$(grep -v '^#' .config | wc -l)项配置"
  fi
else
  make defconfig > /dev/null 2>&1
  # 设置默认机型为T68M
  # 检查并启用T68M相关配置
  if grep -q "DEVICE.*t68m" .config; then
    sed -i 's/# CONFIG_TARGET_rockchip is not set/CONFIG_TARGET_rockchip=y/g' .config
    sed -i 's/# CONFIG_TARGET_rockchip_armv8 is not set/CONFIG_TARGET_rockchip_armv8=y/g' .config
    sed -i 's/# CONFIG_TARGET_rockchip_armv8_DEVICE_lyt_t68m is not set/CONFIG_TARGET_rockchip_armv8_DEVICE_lyt_t68m=y/g' .config
  else
    # 如果配置不存在，则添加新配置
    echo "CONFIG_TARGET_rockchip=y" >> .config
    echo "CONFIG_TARGET_rockchip_armv8=y" >> .config
    echo "CONFIG_TARGET_rockchip_armv8_DEVICE_lyt_t68m=y" >> .config
    # 加载tweak_options配置并处理ccache
    if [ -f "../customization/tweak_options" ]; then
      source "../customization/tweak_options"
      if [ "$ccache_enable" = "1" ]; then
        chmod +x ../scripts/ccache.sh
        ../scripts/ccache.sh config
      fi
    fi
  fi
fi

# 处理自定义插件源码
# 检查customization/clinks_of_packages目录是否存在且非空
# 如果存在，则克隆每个插件的源码到package/diy目录
if [ -d "../customization/clinks_of_packages" ] && [ -n "$(ls -A ../customization/clinks_of_packages)" ]; then
  mkdir -p package/diy
  cd package/diy
  error_count=0
  while IFS= read -r line; do
    # 跳过空行和注释行，确保只处理有效的仓库地址
    # 格式校验：必须是有效的git地址
    if [ -z "$line" ] || [[ "$line" =~ ^[[:space:]]*# ]] || ! [[ "$line" =~ ^https?://.+ ]]; then
      error_count=$((error_count+1))
      continue
    fi
    git clone "$line"
  done < ../../../customization/clinks_of_packages
  cd ../..
fi

# 处理需要包含的软件包
# 从packages-included文件中读取包名
# 将对应的包配置设置为y（启用）
if [ -f "../customization/packages-included" ]; then
    pkg_error_count=0
  valid_pkgs=()
  while IFS= read -r pkg; do
    # 跳过空行和注释行
    if [ -z "$pkg" ] || [[ "$pkg" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    # 包名有效性校验（字母、数字、下划线和连字符）
    if [[ ! "$pkg" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      pkg_error_count=$((pkg_error_count+1))
      warning_msg "检测到无效包名: ${pkg}，已跳过"
      continue
    fi
    valid_pkgs+=("$pkg")
    sed -i "/CONFIG_PACKAGE_${pkg}/d" .config
    echo "CONFIG_PACKAGE_${pkg}=y" >> .config
  done < ../customization/packages-included

  # 二次验证配置写入
  missing_count=0
  for pkg in "${valid_pkgs[@]}"; do
    if ! grep -q "^CONFIG_PACKAGE_${pkg}=y" .config; then
      missing_count=$((missing_count+1))
    fi
  done

  # 错误提示整合
  if [ $error_count -gt 0 ]; then
    warning_msg "插件仓库配置发现${error_count}个格式错误项"
  fi
  if [ $pkg_error_count -gt 0 ]; then
    warning_msg "packages-included中发现${pkg_error_count}个无效包名"
  fi
  if [ $missing_count -gt 0 ]; then
    warning_msg "${missing_count}个合法包名未成功写入配置"
  fi
fi

# 处理需要排除的软件包
# 从packages_excluded文件中读取包名
# 将对应的包配置设置为n（禁用）
if [ -f "../customization/packages_excluded" ]; then
    pkg_error_count=0
  valid_pkgs=()
  while IFS= read -r pkg; do
    # 跳过空行和注释行
    if [ -z "$pkg" ] || [[ "$pkg" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    if [[ ! "$pkg" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      pkg_error_count=$((pkg_error_count+1))
      warning_msg "检测到无效包名: ${pkg}，已跳过"
      continue
    fi
    valid_pkgs+=("$pkg")
    sed -i "/CONFIG_PACKAGE_${pkg}/d" .config
    echo "CONFIG_PACKAGE_${pkg}=n" >> .config
  done < ../customization/packages_excluded

  if [ $pkg_error_count -gt 0 ]; then
    warning_msg "packages_excluded中发现${pkg_error_count}个无效包名"
  fi
fi
