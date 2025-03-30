#!/bin/bash

# 导入统一反馈函数
source "$(dirname "$0")/init.sh"

# 编译错误分析函数
analyze_build_error() {
  LOG_FILE="${SOURCE_DIR}/logs/$(ls -t ${SOURCE_DIR}/logs | head -n1)"
  
  # 常见错误模式匹配
  declare -A ERROR_PATTERNS=(
    ["依赖缺失"]="package.*not found"
    ["权限问题"]="Permission denied"
    [「编译超时」]="Terminated.*timeout"
    [「哈希校验失败」]="Hash mismatch"
    [「内存不足」]="Cannot allocate memory"
  )

  for error_type in "${!ERROR_PATTERNS[@]}"; do
    if grep -qE "${ERROR_PATTERNS[$error_type]}" "$LOG_FILE"; then
      warning_msg "检测到常见错误类型: $error_type"
      case $error_type in
        "依赖缺失")
          echo "建议解决方案："
          echo "1. 运行 './scripts/feeds update -a && ./scripts/feeds install -a'"
          echo "2. 检查customization/packages-included中的包配置"
          ;;
        "权限问题")
          echo "建议解决方案："
          echo "1. 检查文件权限: ls -l $(grep 'Permission denied' "$LOG_FILE" | awk '{print $NF}')"
          echo "2. 尝试使用 'chmod +x' 修复执行权限"
          ;;
        *)
          echo "请查看日志文件: $LOG_FILE"
          ;;
      esac
      return
    fi
  done
  
  warning_msg "未识别到已知错误模式，完整日志见: $LOG_FILE"
}

# 进入源码目录
cd $SOURCE_DIR

info_msg "开始编译流程..."

# 下载所需的软件包
# -j8参数指定8个并发下载任务
make download -j8
if [ $? -eq 0 ]; then
  success_msg "软件包下载完成，共下载了$(find dl -type f | wc -l)个文件"
else
  error_msg "软件包下载失败，请检查网络连接"
fi
# 检查下载的文件大小，列出小于1024字节的文件（可能是下载失败的文件）
find dl -size -1024c -exec ls -l {} \;
# 删除这些可能下载失败的文件
find dl -size -1024c -exec rm -f {} \;

# 开始编译固件
# 显示编译使用的线程数
info_msg "使用$(nproc)线程进行编译..."
# 使用多线程编译，如果失败则降级到单线程编译
# V=s参数用于显示详细的编译信息，方便调试
make -j$(nproc) || make -j1 || make -j1 V=s
if [ $? -eq 0 ]; then
  success_msg "固件编译成功，输出文件位于bin/targets目录"
else
  error_msg "固件编译失败，正在分析错误日志..."
  analyze_build_error
  exit 1
fi

# 整理编译后的文件
# 进入目标文件目录并删除不需要的packages目录
# 获取源码绝对路径
SOURCE_ABS_PATH="$(pwd)"

# 多级目录存在性检查
check_path_exists() {
  if [ ! -e "$1" ]; then
    error_msg "路径不存在: $1 (绝对路径: ${SOURCE_ABS_PATH}/$1)"
    return 1
  fi
}

# 定位编译输出目录
BUILD_OUTPUT="${SOURCE_ABS_PATH}/bin/targets"
check_path_exists "$BUILD_OUTPUT" || exit 1

target_dir=$(find "$BUILD_OUTPUT" -mindepth 2 -maxdepth 2 -type d -print -quit)
if [ -n "$target_dir" ]; then
  check_path_exists "$target_dir" || exit 1
  cd "$target_dir" || { 
    error_msg "无法进入目标目录 (绝对路径: $target_dir)"; 
    exit 1 
  }
  rm -rf packages
  success_msg "成功清理冗余文件，当前工作目录: $(pwd)"
else
  error_msg "未找到有效目标目录，请检查编译输出路径: $BUILD_OUTPUT"
  exit 1
fi
