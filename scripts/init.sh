#!/bin/bash

# 统一反馈函数定义
success_msg() {
  echo "✅ $1"
}

error_msg() {
  echo "❌ $1"
  exit 1
}

warning_msg() {
  echo "⚠️  $1"
}

info_msg() {
  echo "ℹ️  $1"
}

# 导出函数，使其他脚本可以调用
export -f success_msg
export -f error_msg
export -f warning_msg
export -f info_msg

# 设置源码目录名称变量
# 优先读取配置文件中的分支设置
if [ -f "../customization/tweak_options" ]; then
  source "${BASH_SOURCE%/*}/../customization/tweak_options"
  
  # 参数有效性校验
  if [ -n "$source_branch" ]; then
    # 分支名合法性检查
    if [[ ! "$source_branch" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      error_msg "非法分支名称: '$source_branch' 只允许字母、数字、下划线和连字符"
    fi
    
    # 参数冲突检测
    if [ $# -gt 0 ]; then
      warning_msg "检测到配置文件与命令行参数同时存在，优先使用配置文件设置的分支: $source_branch"
    fi
    
    export SOURCE_DIR="$source_branch"
    success_msg "使用配置文件设置源码分支：$source_branch"
  else
    warning_msg "配置文件中source_branch参数为空，自动回退到传统参数模式"
  fi
fi

# 保留下游参数兼容处理
if [ -z "$SOURCE_DIR" ]; then
  if [ "$1" == "lede" ]; then
    export SOURCE_DIR="lede"
  else
    export SOURCE_DIR="immortalwrt"
  fi
  success_msg "使用传统参数设置源码分支：$SOURCE_DIR"
fi
