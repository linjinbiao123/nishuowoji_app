#!/usr/bin/env bash
# Codespaces / Dev Container 环境初始化：安装 Flutter SDK 并拉取依赖
set -e

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.2}"
FLUTTER_DIR="$HOME/flutter"
WORKDIR="${containerWorkspaceFolder:-/workspaces/nishuowoji_app}"

# Flutter 依赖 git，容器里仓库 owner 可能不同，需标记为安全目录
git config --global --add safe.directory '*' || true

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo ">>> 正在安装 Flutter $FLUTTER_VERSION ..."
  curl -sSL --max-time 1800 -o /tmp/flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  rm -rf "$FLUTTER_DIR"
  tar -xf /tmp/flutter.tar.xz -C "$HOME"
  rm -f /tmp/flutter.tar.xz
else
  echo ">>> Flutter 已存在于 $FLUTTER_DIR，跳过下载"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo ">>> Flutter 版本："
flutter --version

# 容器内无 Android SDK / Xcode / 桌面端系统库，只保留 web 目标，
# 避免 flutter doctor 报一堆缺失工具链的错，同时加快 pub get
flutter config --no-analytics >/dev/null 2>&1 || true
flutter config --no-enable-android --no-enable-ios >/dev/null 2>&1 || true
flutter config --no-enable-linux-desktop --no-enable-macos-desktop --no-enable-windows-desktop >/dev/null 2>&1 || true
flutter config --enable-web >/dev/null 2>&1 || true

echo ">>> 拉取依赖："
cd "$WORKDIR"
flutter pub get

echo ">>> 环境就绪。之后可用：flutter analyze / flutter test / flutter build web"
