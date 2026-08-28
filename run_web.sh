#!/usr/bin/env bash
# 启动 Web 预览服务。
#
# 用法：
#   ./run_web.sh              # 默认 8080 端口
#   PORT=9000 ./run_web.sh    # 换端口
#
# 启动后在 VS Code 底部「端口/PORTS」面板里，
# 找到对应端口的转发地址（Forwarded Address），用平板或本机浏览器打开即可。
#
# 运行中可用快捷键：
#   r  热重载（改完代码按一下，浏览器刷新即生效）
#   R  热重启
#   q  退出

set -e

# Flutter 可能装在 ~/flutter（devcontainer 脚本默认）或系统 PATH 里
if [ -x "$HOME/flutter/bin/flutter" ]; then
  FLUTTER="$HOME/flutter/bin/flutter"
else
  FLUTTER="$(command -v flutter || true)"
fi

if [ -z "$FLUTTER" ]; then
  echo "错误：找不到 flutter 命令。" >&2
  echo "请先安装 Flutter SDK，或运行 bash .devcontainer/setup-flutter.sh" >&2
  exit 1
fi

PORT="${PORT:-8080}"
cd "$(dirname "$0")"

echo ">>> Flutter: $FLUTTER"
echo ">>> 启动 Web 预览，端口 $PORT"
echo ">>> 打开方式：VS Code 底部 PORTS 面板 → 端口 $PORT 的转发地址"
echo ""

exec "$FLUTTER" run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port "$PORT"
