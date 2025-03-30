#!/bin/bash

# 导入统一反馈函数
source "$(dirname "$0")/init.sh"

# 增强错误处理
set -eo pipefail

# 清理并重建源码目录
if [ -d "$SOURCE_DIR" ]; then
  rm -rf "$SOURCE_DIR" || error_msg "清理源码目录失败"
fi
mkdir -p "$SOURCE_DIR" || error_msg "无法创建源码目录 '$SOURCE_DIR'"

# 定义克隆函数，统一处理重试逻辑
clone_with_retry() {
  local repo_url=$1
  local branch_name=$2
  local target_dir=${3:-"$SOURCE_DIR"}
  local max_retries=3
  local retry_count=0

  while [ $retry_count -lt $max_retries ]; do
    if git clone -c advice.detachedHead=false --progress "$repo_url" "$target_dir"; then
      success_msg "成功克隆${branch_name}源码到$target_dir目录"
      return 0
    else
      retry_count=$((retry_count + 1))
      warning_msg "克隆${branch_name}失败 (尝试 $retry_count/$max_retries)"
      if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"/* || error_msg "清理目录失败: $target_dir"
      fi
      if [ $retry_count -lt $max_retries ]; then
        sleep $((retry_count * 2))
      fi
    fi
  done

  error_msg "克隆${branch_name}源码失败，已重试${max_retries}次"
  return 1
}

# 根据传入的参数选择要克隆的源码分支
if [ "$1" == "lede" ]; then
  clone_with_retry "$REPO_URL_LEDE" "lede"
else
  clone_with_retry "$REPO_URL_IMMORTALWRT" "immortalwrt"
fi

# 优化软链接创建
openwrt_dir="${GITHUB_WORKSPACE}/openwrt"

# 确保目标目录的父目录存在
mkdir -p "$(dirname "$openwrt_dir")"

# 处理已存在的软链接或目录
if [ -L "$openwrt_dir" ]; then
  rm -f "$openwrt_dir" || error_msg "删除已存在的软链接失败"
elif [ -d "$openwrt_dir" ]; then
  rm -rf "$openwrt_dir" || error_msg "删除已存在的目录失败"
fi

# 创建新的软链接
ln -sf "$SOURCE_DIR" "$openwrt_dir" || error_msg "软链接创建失败"
success_msg "已创建跨平台源码目录软链接：$openwrt_dir"

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
    
    # 使用统一的克隆函数处理插件源码
    clone_with_retry "$repo_url" "$(basename "$target_dir")" "$target_dir"
  done < "customization/clinks_of_packages"
fi
