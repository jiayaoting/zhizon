#!/bin/bash
# 智子 - 应用图标同步脚本
# 根据用户在设置中选择的应用图标 ID，将对应的图标资源复制覆盖到 app_icon.jpg
# 用法：
#   1. 先在应用设置中选好应用图标
#   2. 打包前在工程根目录执行：bash sync_app_icon.sh
#   3. 重新用 DevEco Studio 打包

set -e

MEDIA_DIR="entry/src/main/resources/base/media"
PREFS_FILE="entry/build/default/outputs/default/resolve_dependencies.json"

# 图标 ID 到资源文件名的映射（与 AppIconManager.ets 保持一致）
get_resource_name() {
  case "$1" in
    classic)         echo "app_icon_classic" ;;
    bright_gradient) echo "app_icon_bright_gradient" ;;
    glass)           echo "app_icon_glass" ;;
    flat)            echo "app_icon_flat" ;;
    3d_cartoon)      echo "app_icon_3d_cartoon" ;;
    liquid)          echo "app_icon_liquid" ;;
    *)               echo "app_icon_classic" ;;
  esac
}

# 读取用户选择的图标 ID（从持久化偏好，这里简化为参数或默认值）
ICON_ID="${1:-liquid}"
RESOURCE=$(get_resource_name "$ICON_ID")
SOURCE_FILE="${MEDIA_DIR}/${RESOURCE}.jpg"
TARGET_FILE="${MEDIA_DIR}/app_icon.jpg"

if [ ! -f "$SOURCE_FILE" ]; then
  echo "错误：图标资源文件不存在 $SOURCE_FILE"
  exit 1
fi

cp "$SOURCE_FILE" "$TARGET_FILE"
echo "已将应用图标同步为：$ICON_ID ($RESOURCE)"
echo "源文件：$SOURCE_FILE"
echo "目标文件：$TARGET_FILE"
echo "请重新打包以使桌面图标生效。"
