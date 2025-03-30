#!/bin/bash

# 导入统一反馈函数
source ./init.sh

# 设置源码目录名称变量
# 使用init.sh中导出的SOURCE_DIR变量

# 进入源码目录
cd $SOURCE_DIR

# 根据分支类型设置默认的feeds源配置
# 如果feeds.conf.default文件不存在，则创建它
if [ ! -f "./feeds.conf.default" ]; then
  # lede分支使用coolsnowwolf的源
  if [ "$1" = "lede" ]; then
    cat > ./feeds.conf.default << 'EOF'
src-git packages https://github.com/coolsnowwolf/packages
src-git luci https://github.com/coolsnowwolf/luci
src-git routing https://github.com/coolsnowwolf/routing
src-git telephony https://git.openwrt.org/feed/telephony.git
EOF
  # immortalwrt分支使用immortalwrt的源
  elif [ "$1" = "immortalwrt" ]; then
    cat > ./feeds.conf.default << 'EOF'
src-git packages https://github.com/immortalwrt/packages
src-git luci https://github.com/immortalwrt/luci
src-git routing https://github.com/immortalwrt/routing
src-git telephony https://github.com/openwrt/telephony
EOF
  fi
fi

# 检查是否存在自定义feeds源配置
# 如果存在，则处理冲突并追加到feeds.conf.default文件中
if [ -f "../customization/cfeeds" ]; then
  info_msg "检测到自定义feeds源配置文件，开始处理..."
  # 转换Windows换行符为LF格式
  if command -v dos2unix >/dev/null 2>&1; then
    dos2unix "../customization/cfeeds" || error_msg "换行符转换失败"
  else
    sed -i 's/\r$//' "../customization/cfeeds" || error_msg "换行符转换失败"
  fi
  # 读取并处理自定义feeds源
  while IFS= read -r line; do
    # 跳过空行和注释行
    if [ -z "$line" ] || [[ "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    # 使用正则表达式严格匹配src-git格式
    if [[ "$line" =~ ^src-git[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
        feed_name="${BASH_REMATCH[1]}"
        feed_url="${BASH_REMATCH[2]}"
    else
        warning_msg "无效的feed格式: $line"
        continue
    fi
    # 注释同名源的所有行
    sed -i "s/^src-git $feed_name /#src-git $feed_name /" ./feeds.conf.default
    echo "$line" >> ./feeds.conf.default
  done < "../customization/cfeeds"
fi

info_msg "开始更新feeds (详细日志见feeds_update.log)..."
./scripts/feeds update -a 2>&1 | tee feeds_update.log
if [ ${PIPESTATUS[0]} -eq 0 ]; then
  success_msg "更新feeds成功，开始安装..."
else
  error_msg "更新feeds失败，请查看日志文件feeds_update.log"
  exit 1
fi

info_msg "开始安装feeds (详细日志见feeds_install.log)..."
./scripts/feeds install -a 2>&1 | tee feeds_install.log
if [ ${PIPESTATUS[0]} -eq 0 ]; then
  success_msg "安装feeds成功"
else
  error_msg "安装feeds失败，请查看日志文件feeds_install.log"
  exit 1
fi
