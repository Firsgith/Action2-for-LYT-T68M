#!/bin/bash

# 导入统一反馈函数
source ./init.sh

# 设置源码目录名称变量
# 使用init.sh中导出的SOURCE_DIR变量

# 检查并加载tweak_options配置
if [ -f "../customization/tweak_options" ]; then
  source "../customization/tweak_options"
fi

# 处理ccache配置
handle_ccache_config() {
  # 使用官方配置工具安全修改
  CONFIG_TOOL="${SOURCE_DIR}/scripts/config"
  
  if [ "$ccache_enable" = "1" ]; then
    CCACHE_DIR="${CCACHE_DIR:-/tmp/ccache}"
    mkdir -p "$CCACHE_DIR"
    chmod 755 "$CCACHE_DIR" || {
      error_msg "无法创建缓存目录：$CCACHE_DIR"
      return 1
    }

    # 安全启用ccache配置
    "$CONFIG_TOOL" --enable CONFIG_CCACHE || {
      error_msg "CCACHE配置启用失败"
      return 1
    }
    "$CONFIG_TOOL" --set-str CONFIG_CCACHE_DIR "$CCACHE_DIR"
    "$CONFIG_TOOL" --set-str CONFIG_CCACHE_SIZE "${ccache_size:-2G}"
    
    # 验证配置结果
    if "$CONFIG_TOOL" -s CONFIG_CCACHE && \
       [ "$("$CONFIG_TOOL" -s CONFIG_CCACHE_DIR)" = "$CCACHE_DIR" ]; then
      success_msg "CCACHE配置成功 | 目录: $CCACHE_DIR | 大小: ${ccache_size:-2G}"
    else
      error_msg "CCACHE配置验证失败"
      return 1
    fi
  else
    "$CONFIG_TOOL" --disable CONFIG_CCACHE
    info_msg "已禁用CCACHE配置"
  fi
}

# 检查ccache状态
check_ccache_status() {
  if [ -f "../customization/tweak_options" ]; then
    if [ "$ccache_enable" = "1" ]; then
      echo "ccache_enabled=true" >> $GITHUB_OUTPUT
    else
      echo "ccache_enabled=false" >> $GITHUB_OUTPUT
    fi
  else
    echo "ccache_enabled=true" >> $GITHUB_OUTPUT
  fi
}

# 根据参数执行相应的功能
if [ "$1" = "config" ]; then
  handle_ccache_config
elif [ "$1" = "status" ]; then
  check_ccache_status
fi