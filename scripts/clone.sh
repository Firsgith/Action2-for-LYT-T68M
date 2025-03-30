#!/bin/bash

# 导入统一反馈函数
source "$(dirname "$0")/init.sh"

# 增强错误处理
set -eo pipefail

# 根据传入的参数选择要克隆的源码分支
if [ "$1" == "lede" ]; then
  max_retries=3
  retry_count=0
  while [ $retry_count -lt $max_retries ]; do
    if git clone -c advice.detachedHead=false --progress $REPO_URL_LEDE $SOURCE_DIR; then
      success_msg "成功克隆lede分支源码到$SOURCE_DIR目录"
      break
    else
      retry_count=$((retry_count + 1))
      warning_msg "克隆lede分支失败 (尝试 $retry_count/$max_retries)"
      [ -d "$SOURCE_DIR" ] && rm -rf "$SOURCE_DIR"
      sleep $((retry_count * 2))
    fi
  done || error_msg "克隆lede分支源码失败，已重试${max_retries}次"
else
  max_retries=3
  retry_count=0
  while [ $retry_count -lt $max_retries ]; do
    if git clone $REPO_URL_IMMORTALWRT $SOURCE_DIR; then
      success_msg "成功克隆immortalwrt分支源码到$SOURCE_DIR目录"
      break
    else
      retry_count=$((retry_count + 1))
      warning_msg "克隆immortalwrt分支失败 (尝试 $retry_count/$max_retries)"
      [ -d "$SOURCE_DIR" ] && rm -rf "$SOURCE_DIR"
      sleep $((retry_count * 2))
    fi
  done || error_msg "克隆immortalwrt分支源码失败，已重试${max_retries}次"
fi

# 优化软链接创建
openwrt_dir="${GITHUB_WORKSPACE}/openwrt"

mkdir -p "$(dirname "$openwrt_dir")"
if [ ! -L "$openwrt_dir" ]; then
  ln -sf "$SOURCE_DIR" "$openwrt_dir" || error_msg "软链接创建失败"
  success_msg "已创建跨平台源码目录软链接：$openwrt_dir"
fi

# 创建diy目录用于存放自定义插件源码
mkdir -p ./package/diy

# 处理自定义插件源配置文件
if [ -f "customization/clinks_of_packages" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    # 跳过空行和注释行
    if [ -z "$line" ] || [[ "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    # 支持带目录名的格式：URL:目录名
    repo_url="${line%%:*}"
    custom_dir="${line##*:}"
    
    # 验证git仓库地址格式
    if ! [[ "$repo_url" =~ ^https?://.+\.git$ ]]; then
      warning_msg "无效的git仓库地址格式：'${repo_url}' 必须包含协议头并以.git结尾"
      continue
    fi
    
    # 目录处理逻辑
    target_dir="./package/diy/${custom_dir:-$(basename "$repo_url" .git)}"
    if [ -d "$target_dir" ]; then
      warning_msg "目录已存在：$target_dir，跳过克隆"
      continue
    fi
    
    # 带重试机制的克隆
    max_retries=3
    retry_count=0
    while [ $retry_count -lt $max_retries ]; do
      if git clone "$repo_url" "$target_dir"; then
        success_msg "成功克隆插件源码: $repo_url"
        break
      else
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
          warning_msg "克隆 $repo_url 失败，${retry_count}次重试..."
          sleep 3
        else
          error_msg "克隆 $repo_url 失败，已重试${retry_count}次"
        fi
      fi
    done
  done < "customization/clinks_of_packages"
fi
