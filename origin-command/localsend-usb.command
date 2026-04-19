#!/bin/bash

set -u

PORT="53317"
APP_NAME="LocalSend"
ADB="$(command -v adb || true)"

print_line() {
  echo "=================================================="
}

pause_and_exit() {
  echo
  read -p "按回车退出..."
  exit 1
}

notify() {
  /usr/bin/osascript -e "display notification \"$1\" with title \"LocalSend USB\"" >/dev/null 2>&1 || true
}

dialog_continue() {
  /usr/bin/osascript <<EOF >/dev/null 2>&1
display dialog "$1" buttons {"继续"} default button "继续" with title "LocalSend USB"
EOF
}

print_line
echo "LocalSend USB 半自动启动"
print_line
echo

dialog_continue "请先手动关闭 Android 端 LocalSend，将传输两端的“加密”都关闭。并且不要立刻重新打开。准备好后点击“继续”。"

echo "[1/8] 关闭 Mac 端 LocalSend..."
/usr/bin/osascript -e 'tell application "LocalSend" to quit' >/dev/null 2>&1 || true
sleep 1

echo "[2/8] 检查并清理 Mac 上的 $PORT 端口占用..."
PIDS="$(/usr/sbin/lsof -ti tcp:$PORT 2>/dev/null || true)"

if [ -n "$PIDS" ]; then
  echo "发现以下进程仍占用端口 $PORT： $PIDS"
  echo "尝试结束这些进程..."
  kill -9 $PIDS >/dev/null 2>&1 || true
  sleep 1
else
  echo "端口 $PORT 当前未被占用。"
fi

echo "[3/8] 再次确认端口状态..."
if /usr/sbin/lsof -i tcp:$PORT >/dev/null 2>&1; then
  echo
  echo "错误：Mac 上端口 $PORT 仍被占用。"
  echo "请手动执行下面命令检查："
  echo "lsof -nP -iTCP:$PORT"
  pause_and_exit
else
  echo "端口 $PORT 已空闲。"
fi

echo "[4/8] 检查 adb..."
if [ -z "$ADB" ]; then
  echo "错误：找不到 adb。"
  echo "请先确认 adb 已安装，并且终端执行 which adb 能找到。"
  pause_and_exit
fi
echo "adb 路径：$ADB"

echo "[5/8] 检查 Android 设备连接..."
if ! "$ADB" get-state >/dev/null 2>&1; then
  echo "错误：没有检测到 Android 设备。"
  echo "请检查："
  echo "1. USB 线是否连接正常"
  echo "2. 手机是否已开启 USB 调试"
  echo "3. 手机上是否点了“允许此电脑调试”"
  echo "4. adb devices 是否能看到设备"
  pause_and_exit
fi
echo "Android 设备已连接。"

echo "[6/8] 重启 adb 并清理旧 reverse..."
"$ADB" kill-server >/dev/null 2>&1 || true
sleep 1
"$ADB" start-server >/dev/null 2>&1 || true
sleep 1
"$ADB" reverse --remove-all >/dev/null 2>&1 || true
sleep 1

echo "[7/8] 建立 reverse tcp:$PORT tcp:$PORT ..."
if ! "$ADB" reverse tcp:$PORT tcp:$PORT; then
  echo
  echo "错误：adb reverse 建立失败。"
  echo "大概率是 Android 端 LocalSend 还没真正关掉，或者 USB/ADB 状态不稳定。"
  echo "可以先手动确认 Android 端 LocalSend 已关闭，再重新运行本脚本。"
  pause_and_exit
fi

echo "当前 reverse 列表："
"$ADB" reverse --list || true

echo "[8/8] 启动 Mac 端 LocalSend..."
open -a "$APP_NAME" >/dev/null 2>&1 || {
  echo "错误：无法打开 Mac 端 LocalSend。"
  echo "请确认 App 名称确实是：$APP_NAME"
  pause_and_exit
}
sleep 2

notify "Reverse 已建立。现在请手动打开 Android 端 LocalSend。"

echo
print_line
echo "已完成"
print_line
echo
echo "下一步请手动操作："
echo "1. 打开 Android 端 LocalSend"
echo "2. 保持 USB 连接"
echo "3. 开始传图"
echo

read -p "按回车结束..."