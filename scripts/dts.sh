#!/bin/bash

# 进入源码目录
cd $SOURCE_DIR

# 检查dts_for_T68M目录是否存在且非空
# 如果存在自定义设备树文件，则根据分支类型进行替换
if [ -d "../dts_for_T68M" ]; then
  # 查找目录中所有.dts文件并按修改时间排序
  dts_files=$(find "../dts_for_T68M" -name "*_${1}.dts" -printf '%T@ %p\n' | sort -r | cut -d' ' -f2-)
# 如果没有分支匹配则查找通用文件
[ -z "$dts_files" ] && dts_files=$(find "../dts_for_T68M" -name '????????-????.dts' -printf '%T@ %p\n' | sort -r | cut -d' ' -f2-)
  
  if [ -n "$dts_files" ]; then
    # 获取最新修改的文件
    latest_dts=$(echo "$dts_files" | head -n1)
    target_dir="./target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/"
    mkdir -p "${target_dir}"
    file_count=$(echo "$dts_files" | wc -l)
    
    # 当存在多个文件时发出警告
    if [ $file_count -gt 1 ]; then
      warning_msg "发现多个设备树文件，将使用最后修改的: $(basename $latest_dts)"
    fi
    
    # 根据分支类型选择目标文件名
    if [ "$1" == "lede" ]; then
      if cp -f "$latest_dts" "${target_dir}/rk3568-t68m.dts"; then
        success_msg "成功替换lede分支设备树文件"
      else
        error_msg "替换lede分支设备树文件失败"
        exit 1
      fi
    else
      if cp -f "$latest_dts" "${target_dir}/rk3568-lyt-t68m.dts"; then
        success_msg "成功替换immortalwrt分支设备树文件"
      else
        error_msg "替换immortalwrt分支设备树文件失败"
        exit 1
      fi
    fi
  else
    info_msg "未找到有效的.dts设备树文件，跳过替换操作"
  fi
fi