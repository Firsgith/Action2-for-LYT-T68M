#!/bin/bash

# 导入统一反馈函数
source ./init.sh

# 统一格式验证模块
info_msg "正在执行配置文件格式预检..."
blocking_errors=0
warnings=0

# 校验config目录文件命名规范
if [ -d "../config" ]; then
  find "../config" -name "*.config" | while read -r config_file; do
    filename=$(basename "$config_file")
    if [[ ! "$filename" =~ ^[a-zA-Z]+_([0-9]{8}|branch)\.config$ ]]; then
      error_msg "config文件命名不规范: $filename 必须符合<分支>_<日期/分支标识>.config格式"
      blocking_errors=$((blocking_errors+1))
    fi
  done
fi

# 校验clinks_of_packages文件格式
if [ -f "../customization/clinks_of_packages" ]; then
  line_num=0
  while IFS= read -r line; do
    line_num=$((line_num+1))
    # 基础URL格式校验
    if [[ ! "$line" =~ ^https?://.+ ]]; then
      warning_msg "clinks_of_packages第${line_num}行格式错误: $line"
      warnings=$((warnings+1))
    fi
  done < "../customization/clinks_of_packages"
fi

# 校验packages-excluded文件格式
if [ -f "../customization/packages-excluded" ]; then
  line_num=0
  while IFS= read -r pkg; do
    line_num=$((line_num+1))
    if [[ ! "$pkg" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      warning_msg "packages-excluded第${line_num}行包含非法字符: $pkg"
      warnings=$((warnings+1))
    fi
  done < "../customization/packages-excluded"
fi

# 校验packages-included文件格式
if [ -f "../customization/packages-included" ]; then
  line_num=0
  while IFS= read -r pkg; do
    line_num=$((line_num+1))
    # 包名格式校验（字母、数字、下划线、短横线）
    if [[ ! "$pkg" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      warning_msg "packages-included第${line_num}行包含非法字符: $pkg"
      warnings=$((warnings+1))
    fi
  done < "../customization/packages-included"
fi

# 校验设备树文件命名规范
if [ -d "../dts_for_T68M" ]; then
  find "../dts_for_T68M" -name "*.dts" | while read -r dts_file; do
    filename=$(basename "$dts_file")
    # 增强正则表达式支持分支标识格式
    if [[ ! "$filename" =~ ^[a-zA-Z0-9_]+_([0-9]{8}|[a-zA-Z0-9_-]+)\.dts$ ]]; then
      warning_msg "设备树文件格式错误: $filename 必须符合<分支>_<日期/标识>.dts格式"
      warnings=$((warnings+1))
    fi
    # 检测Windows换行符
    if file "$dts_file" | grep -q CRLF; then
      error_msg "发现Windows换行符: $dts_file"
      blocking_errors=$((blocking_errors+1))
    fi
  done
fi

# 验证.config平台标识
if [ -f "../config/*.config" ]; then
  if ! grep -q "CONFIG_TARGET_rockchip" ../config/*.config; then
    error_msg "缺少必要的平台标识配置"
    blocking_errors=$((blocking_errors+1))
  fi
fi

# 新增配置文件格式校验
check_tweak_options() {
  if [ -f "../customization/tweak_options" ]; then
    # 转换Windows换行符
    dos2unix "../customization/tweak_options" 2>/dev/null
    
    # 校验source_branch格式
    if grep -q 'source_branch=' "../customization/tweak_options"; then
      branch_value=$(grep -oP 'source_branch=\K.*' "../customization/tweak_options")
      if [[ ! "$branch_value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error_msg "tweak_options中source_branch格式错误: $branch_value"
        blocking_errors=$((blocking_errors+1))
      fi
    fi
    
    # 校验ccache_enable值范围
    if grep -q 'ccache_enable=' "../customization/tweak_options"; then
      ccache_value=$(grep -oP 'ccache_enable=\K.*' "../customization/tweak_options")
      if [[ ! "$ccache_value" =~ ^[01]$ ]]; then
        warning_msg "tweak_options中ccache_enable值无效: $ccache_value (应为0或1)"
        warnings=$((warnings+1))
      fi
    fi
  fi
}

# 校验cfeeds文件格式
check_cfeeds() {
  if [ -f "../customization/cfeeds" ]; then
    line_num=0
    while IFS= read -r line; do
      line_num=$((line_num+1))
      if [[ ! "$line" =~ ^src-git\s+[a-zA-Z0-9_-]+\s+https://.+(\.git)?$ ]]; then
        warning_msg "cfeeds第${line_num}行格式错误: $line"
        warnings=$((warnings+1))
      fi
    done < "../customization/cfeeds"
  fi
}

# 定义处理用户选择的函数
handle_errors() {
  local error_type=$1
  local count=$2
  local timeout=30

  if [ "$error_type" = "blocking" ]; then
    warning_msg "预检发现 $count 个阻断性错误。"
  else
    warning_msg "预检发现 $count 个警告。"
  fi

  # 增强错误定位信息
  if [ "$error_type" = "blocking" ]; then
    tail -n 10 ../logs/precheck.log 2>/dev/null || true
  fi
  
  info_msg "请在 $timeout 秒内选择操作："
  info_msg "1) 修正错误后继续 (打开日志文件: ../logs/precheck.log)"
  info_msg "2) 忽略错误继续执行 (记录到日志)"
  info_msg "3) 终止执行"

  read -t $timeout -p "请输入选项 (默认: 2): " choice
  
  # 处理超时或回车（默认选项）
  if [ $? -gt 128 ] || [ -z "$choice" ]; then
    warning_msg "超时或未选择，默认继续执行"
    return 0
  fi

  case $choice in
    1)
      warning_msg "请修正错误后重新运行预检"
      exit 1
      ;;
    2)
      info_msg "继续执行"
      return 0
      ;;
    3)
      warning_msg "终止执行"
      exit 1
      ;;
    *)
      warning_msg "无效选项，默认继续执行"
      return 0
      ;;
  esac
}

# 执行新增校验
check_tweak_options
check_cfeeds

# 最终检查结果
if [ $blocking_errors -gt 0 ]; then
  handle_errors "blocking" $blocking_errors
  echo "$(date) - 阻断性错误: $blocking_errors 个" >> ../logs/precheck.log
elif [ $warnings -gt 0 ]; then
  handle_errors "warning" $warnings
  echo "$(date) - 警告: $warnings 个" >> ../logs/precheck.log
else
  success_msg "预检通过，所有配置格式合规"
  echo "$(date) - 预检通过" >> ../logs/precheck.log
fi