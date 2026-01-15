#!/bin/bash

# 颜色定义
RED_COLOR='\e[1;31m'     # 红色
GREEN_COLOR='\e[1;32m'   # 绿色
YELLOW_COLOR='\e[1;33m'  # 黄色
BLUE_COLOR='\e[1;34m'    # 蓝色
PINK_COLOR='\e[1;35m'    # 粉色
SHAN='\e[1;33;5m'        # 闪烁效果
RES='\e[0m'              # 重置颜色

# 帮助函数
HELP() {
  echo -e "\r\n${GREEN_COLOR}EasyTier 安装脚本帮助${RES}\r\n"
  echo "用法: ./install.sh [命令] [选项]"
  echo
  echo "命令:"
  echo "  install    安装 EasyTier"
  echo "  uninstall  卸载 EasyTier"
  echo "  update     更新 EasyTier 到最新版本"
  echo "  help       显示此帮助信息"
  echo
  echo "选项:"
  echo "  --skip-folder-verify  安装时跳过文件夹验证"
  echo "  --skip-folder-fix     跳过自动文件夹路径修复"
  echo "  --no-gh-proxy        禁用 GitHub 代理"
  echo "  --gh-proxy URL       设置自定义 GitHub 代理 URL"
  echo
  echo "示例:"
  echo "  ./install.sh install /opt/easytier"
  echo "  ./install.sh install --skip-folder-verify"
  echo "  ./install.sh install --no-gh-proxy"
  echo "  ./install.sh install --gh-proxy https://your-proxy.com/"
  echo "  ./install.sh update"
  echo "  ./install.sh uninstall"
}

# 如果没有参数或使用了 help 命令，则显示帮助信息
if [ $# -eq 0 ] || [ "$1" = "help" ]; then
  HELP
  exit 0
fi

# 此脚本基于 alist 的脚本修改，感谢原作者！

# 初始化变量
SKIP_FOLDER_VERIFY=false    # 是否跳过文件夹验证
SKIP_FOLDER_FIX=false       # 是否跳过文件夹路径修复
NO_GH_PROXY=false           # 是否禁用 GitHub 代理
GH_PROXY='https://ghfast.top/'  # 默认 GitHub 代理地址

COMMEND=$1  # 第一个参数是命令（install/uninstall/update）
shift       # 移除第一个参数，后续参数用于选项处理

# 检查安装路径参数（如果第一个非选项参数是路径）
if [[ "$#" -ge 1 && ! "$1" == --* ]]; then
    INSTALL_PATH=$1  # 设置安装路径
    shift
fi

# 解析其他选项参数
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skip-folder-verify) SKIP_FOLDER_VERIFY=true ;;
        --skip-folder-fix) SKIP_FOLDER_FIX=true ;;
        --no-gh-proxy) NO_GH_PROXY=true ;;
        --gh-proxy) 
            if [ -n "$2" ]; then
                GH_PROXY=$2  # 设置自定义代理地址
                shift
            else
                echo "错误: --gh-proxy 需要一个 URL 参数"
                exit 1
            fi
            ;;
        *) echo "未知选项: $1"; exit 1 ;;
    esac
    shift
done

# 如果没有指定安装路径，则使用默认路径
if [ -z "$INSTALL_PATH" ]; then
    INSTALL_PATH='/opt/easytier'
fi

# 移除路径末尾的斜杠（如果有）
if [[ "$INSTALL_PATH" == */ ]]; then
    INSTALL_PATH=${INSTALL_PATH%?}
fi

# 自动添加 easytier 子目录（除非用户明确跳过）
if ! $SKIP_FOLDER_FIX && ! [[ "$INSTALL_PATH" == */easytier ]]; then
    INSTALL_PATH="$INSTALL_PATH/easytier"
fi

echo 安装路径: $INSTALL_PATH
echo 跳过文件夹修复: $SKIP_FOLDER_FIX
echo 跳过文件夹验证: $SKIP_FOLDER_VERIFY

# clear  # 清屏命令（当前被注释）

# 检查是否安装了 unzip
if ! command -v unzip >/dev/null 2>&1; then
  echo -e "\r\n${RED_COLOR}错误: 未安装 unzip${RES}\r\n"
  exit 1
fi

# 检查是否安装了 curl
if ! command -v curl >/dev/null 2>&1; then
  echo -e "\r\n${RED_COLOR}错误: 未安装 curl${RES}\r\n"
  exit 1
fi

# 显示免责声明
echo -e "\r\n${RED_COLOR}----------------------注意事项----------------------${RES}\r\n"
echo " 这是一个临时安装 EasyTier 的脚本"
echo " EasyTier 需要专用的空文件夹进行安装"
echo " EasyTier 是正在开发的产品，可能存在一些问题"
echo " 使用 EasyTier 需要一些基本技能"
echo " 您需要自行承担使用 EasyTier 所带来的风险"
echo -e "\r\n${RED_COLOR}-------------------------------------------------${RES}\r\n"

# 获取系统架构
if command -v arch >/dev/null 2>&1; then
  platform=$(arch)  # 使用 arch 命令获取架构
else
  platform=$(uname -m)  # 使用 uname 命令获取架构
fi

# 将常见架构名称标准化
case "$platform" in
  amd64 | x86_64)
    ARCH="x86_64"
    ;;
  arm64 | aarch64 | *armv8*)
    ARCH="aarch64"
    ;;
  *armv7*)
    ARCH="armv7"
    ;;
  *arm*)
    ARCH="arm"
    ;;
  mips)
    ARCH="mips"
    ;;
  mipsel)
    ARCH="mipsel"
    ;;
  *)
    ARCH="UNKNOWN"  # 未知架构
    ;;
esac

# 检查 ARM 架构是否支持硬件浮点运算（hf）
if [[ "$ARCH" == "armv7" || "$ARCH" == "arm" ]]; then
  if cat /proc/cpuinfo | grep Features | grep -i 'half' >/dev/null 2>&1; then
    ARCH=${ARCH}hf  # 添加 hf 后缀
  fi
fi

echo -e "\r\n${GREEN_COLOR}您的平台: ${ARCH} (${platform}) ${RES}\r\n" 1>&2

# 检查是否以 root 身份运行
if [ "$(id -u)" != "0" ]; then
  echo -e "\r\n${RED_COLOR}此脚本需要以 Root 权限运行！${RES}\r\n" 1>&2
  exit 1
elif [ "$ARCH" == "UNKNOWN" ]; then
  echo -e "\r\n${RED_COLOR}糟糕${RES}，此脚本不支持您的平台\r\n尝试 ${GREEN_COLOR}手动安装${RES}\r\n"
  exit 1
fi

# 检测初始化系统
if command -v systemctl >/dev/null 2>&1; then
  INIT_SYSTEM="systemd"
elif command -v rc-update >/dev/null 2>&1; then
  INIT_SYSTEM="openrc"
else
  echo -e "\r\n${RED_COLOR}错误: 不支持的初始化系统（未找到 systemd 或 OpenRC）${RES}\r\n"
  exit 1
fi

# 检查安装条件
CHECK() {
  # 检查是否已存在 EasyTier（除非跳过验证）
  if ! $SKIP_FOLDER_VERIFY; then
    if [ -f "$INSTALL_PATH/easytier-core" ]; then
      echo "在 $INSTALL_PATH 中已存在 EasyTier。请选择其他路径或使用 \"update\" 命令"
      echo -e "或者使用 ${GREEN_COLOR}--skip-folder-verify${RES} 选项跳过验证"
      exit 0
    fi
  fi

  # 如果目录不存在，则创建
  if [ ! -d "$INSTALL_PATH/" ]; then
    mkdir -p $INSTALL_PATH
  else
    # 检查目录是否为空（除非跳过验证）
    if ! $SKIP_FOLDER_VERIFY; then
      if [ -n "$(ls -A $INSTALL_PATH)" ]; then
        echo "EasyTier 需要安装在空目录中。请选择一个空路径"
        echo -e "或者使用 ${GREEN_COLOR}--skip-folder-verify${RES} 选项跳过验证"
        echo -e "当前路径: $INSTALL_PATH (使用 ${GREEN_COLOR}--skip-folder-fix${RES} 禁用文件夹修复)"
        exit 1
      fi
    fi
  fi
}

# 安装函数
INSTALL() {
  # 获取最新版本号
  RESPONSE=$(curl -s "https://api.github.com/repos/EasyTier/EasyTier/releases/latest")
  LATEST_VERSION=$(echo "$RESPONSE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  LATEST_VERSION=$(echo -e "$LATEST_VERSION" | tr -d '[:space:]')  # 移除空格

  if [ -z "$LATEST_VERSION" ]; then
    echo -e "\r\n${RED_COLOR}糟糕${RES}，无法获取最新版本。请检查您的网络\r\n或尝试 ${GREEN_COLOR}手动安装${RES}\r\n"
    exit 1
  fi

  # 下载 EasyTier
  echo -e "\r\n${GREEN_COLOR}正在下载 EasyTier $LATEST_VERSION ...${RES}"
  rm -rf /tmp/easytier_tmp_install.zip
  BASE_URL="https://github.com/EasyTier/EasyTier/releases/latest/download/easytier-linux-${ARCH}-${LATEST_VERSION}.zip"
  DOWNLOAD_URL=$($NO_GH_PROXY && echo "$BASE_URL" || echo "${GH_PROXY}${BASE_URL}")
  echo -e "下载地址: ${GREEN_COLOR}${DOWNLOAD_URL}${RES}"
  curl -L ${DOWNLOAD_URL} -o /tmp/easytier_tmp_install.zip $CURL_BAR

  # 解压资源文件
  echo -e "\r\n${GREEN_COLOR}正在解压资源文件 ...${RES}"
  unzip -o /tmp/easytier_tmp_install.zip -d $INSTALL_PATH/
  mkdir $INSTALL_PATH/config  # 创建配置目录
  mv $INSTALL_PATH/easytier-linux-${ARCH}/* $INSTALL_PATH/  # 移动文件
  rm -rf $INSTALL_PATH/easytier-linux-${ARCH}/  # 清理临时目录
  chmod +x $INSTALL_PATH/easytier-core $INSTALL_PATH/easytier-cli  # 添加执行权限
  
  # 验证下载是否成功
  if [ -f $INSTALL_PATH/easytier-core ] || [ -f $INSTALL_PATH/easytier-cli ]; then
    echo -e "${GREEN_COLOR} 下载成功! ${RES}"
  else
    echo -e "${RED_COLOR} 下载失败! ${RES}"
    exit 1
  fi
}

# 初始化函数
INIT() {
  if [ ! -f "$INSTALL_PATH/easytier-core" ]; then
    echo -e "\r\n${RED_COLOR}糟糕${RES}，无法找到 EasyTier\r\n"
    exit 1
  fi

  # 创建默认配置文件
  cat >$INSTALL_PATH/config/default.conf <<EOF
instance_name = "洛杉矶"
ipv4 = ""
dhcp = false
listeners = [
    "tcp://0.0.0.0:11010",
    "udp://0.0.0.0:11010",
]
exit_nodes = []
rpc_portal = "0.0.0.0:0"

# [[peer]]
# uri = "tcp://public.easytier.top:11010"

[network_identity]
network_name = "default"
network_secret = "default"

[flags]
default_protocol = "udp"
dev_name = ""
enable_encryption = true
enable_ipv6 = true
mtu = 1380
latency_first = true
enable_exit_node = false
no_tun = false
use_smoltcp = false
foreign_network_whitelist = "*"
disable_p2p = false
p2p_only = false
relay_all_peer_rpc = false
disable_tcp_hole_punching = false
disable_udp_hole_punching = false

EOF

  # 根据初始化系统创建服务脚本
  if [ "$INIT_SYSTEM" = "openrc" ]; then
    cat >/etc/init.d/easytier <<EOF
#!/sbin/openrc-run

name="EasyTier"
description="EasyTier Service"
command="$INSTALL_PATH/easytier-core"
command_args="-c $INSTALL_PATH/config/default.conf"
command_user="nobody:nobody"
command_background=true

pidfile="/run/\${RC_SVCNAME}.pid"

depend() {
  need net
}


EOF
    chmod +x /etc/init.d/easytier
  fi

  # 创建 systemd 服务文件
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    cat >/etc/systemd/system/easytier@.service <<EOF
[Unit]
Description=EasyTier Service
Wants=network.target
After=network.target network.service
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/easytier-core -c $INSTALL_PATH/config/%i.conf
Restart=always
RestartSec=1s

[Install]
WantedBy=multi-user.target
EOF
  fi

#   # 创建运行脚本（当前被注释）
#   cat >$INSTALL_PATH/run.sh <<EOF
# $INSTALL_PATH/easytier-core
# EOF

  # 启动服务
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    systemctl daemon-reload  # 重新加载 systemd 配置
    systemctl enable easytier@default >/dev/null 2>&1  # 设置开机自启
    systemctl start easytier@default  # 启动服务
  else
    rc-update add easytier default  # 添加到 OpenRC 默认运行级别
    rc-service easytier start  # 启动服务
  fi

  # 清理旧版本可能遗留的文件
  rm -rf /etc/systemd/system/easytier.service
  rm -rf /usr/bin/easytier-core
  rm -rf /usr/bin/easytier-cli

  # 创建符号链接
  ln -s $INSTALL_PATH/easytier-core /usr/sbin/easytier-core
  ln -s $INSTALL_PATH/easytier-cli /usr/sbin/easytier-cli
}

# 安装成功提示
SUCCESS() {
  clear
  echo " EasyTier 安装成功!"
  echo -e "\r\n默认端口: ${GREEN_COLOR}11010(UDP+TCP)${RES}，请注意在防火墙中允许此端口！\r\n"
  echo -e "默认网络名称: ${GREEN_COLOR}default${RES}，请将其更改为您自己的网络名称！\r\n"

  echo -e "现在 EasyTier 支持多个配置文件。您可以在 ${GREEN_COLOR}${INSTALL_PATH}/config/${RES} 文件夹中创建配置文件"
  echo -e "更多信息，请查看官方网站的文档"
  echo -e "单个配置文件的管理示例如下"

  echo
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    echo -e "查看状态: ${GREEN_COLOR}systemctl status easytier@default${RES}"
    echo -e "启动服务: ${GREEN_COLOR}systemctl start easytier@default${RES}"
    echo -e "重启服务: ${GREEN_COLOR}systemctl restart easytier@default${RES}"
    echo -e "停止服务: ${GREEN_COLOR}systemctl stop easytier@default${RES}"
  else
    echo -e "查看状态: ${GREEN_COLOR}rc-service easytier status${RES}"
    echo -e "启动服务: ${GREEN_COLOR}rc-service easytier start${RES}"
    echo -e "重启服务: ${GREEN_COLOR}rc-service easytier restart${RES}"
    echo -e "停止服务: ${GREEN_COLOR}rc-service easytier stop${RES}"
  fi
  echo
}

# 卸载函数
UNINSTALL() {
  echo -e "\r\n${GREEN_COLOR}正在卸载 EasyTier ...${RES}\r\n"
  echo -e "${GREEN_COLOR}停止进程 ...${RES}"
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    systemctl disable "easytier@*" >/dev/null 2>&1  # 禁用所有实例
    systemctl stop "easytier@*" >/dev/null 2>&1  # 停止所有实例
  else
    rc-update del easytier  # 从 OpenRC 移除
    rc-service easytier stop  # 停止服务
  fi
  echo -e "${GREEN_COLOR}删除文件 ...${RES}"
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    rm -rf $INSTALL_PATH /etc/systemd/system/easytier.service /usr/bin/easytier-core /usr/bin/easytier-cli /etc/systemd/system/easytier@.service /usr/sbin/easytier-core /usr/sbin/easytier-cli
    systemctl daemon-reload  # 重新加载 systemd 配置
  else
    rm -rf $INSTALL_PATH /etc/init.d/easytier /usr/bin/easytier-core /usr/bin/easytier-cli /usr/sbin/easytier-core /usr/sbin/easytier-cli
  fi
  echo -e "\r\n${GREEN_COLOR}EasyTier 已成功移除！${RES}\r\n"
}

# Minimizes downtime by preparing new files before stopping the service.
# Correctly handles restarting multiple systemd service instances.
# 更新函数（最小化停机时间）
UPDATE() {
  if [ ! -f "$INSTALL_PATH/easytier-core" ]; then
    echo -e "\r\n${RED_COLOR}错误${RES}: 在 $INSTALL_PATH 中未找到 EasyTier，无法执行更新。\r\n"
    exit 1
  fi

  # 1. 获取最新版本信息（服务仍在运行时）
  echo -e "${GREEN_COLOR}正在检查最新版本...${RES}"
  RESPONSE=$(curl -s "https://api.github.com/repos/EasyTier/EasyTier/releases/latest")
  LATEST_VERSION=$(echo "$RESPONSE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  LATEST_VERSION=$(echo -e "$LATEST_VERSION" | tr -d '[:space:]')

  if [ -z "$LATEST_VERSION" ]; then
    echo -e "\r\n${RED_COLOR}错误${RES}: 无法获取最新版本。请检查您的网络连接。\r\n"
    exit 1
  fi

  echo -e "发现最新版本: ${GREEN_COLOR}$LATEST_VERSION${RES}"

  # 2. 下载新版本到临时目录（服务仍在运行时）
  TEMP_UPDATE_DIR=$(mktemp -d /tmp/easytier_update_XXXXXX)
  echo -e "${GREEN_COLOR}正在下载新版本到临时目录: $TEMP_UPDATE_DIR${RES}"
  
  BASE_URL="https://github.com/EasyTier/EasyTier/releases/latest/download/easytier-linux-${ARCH}-${LATEST_VERSION}.zip"
  DOWNLOAD_URL=$($NO_GH_PROXY && echo "$BASE_URL" || echo "${GH_PROXY}${BASE_URL}")
  
  echo -e "下载地址: ${GREEN_COLOR}${DOWNLOAD_URL}${RES}"
  curl -L ${DOWNLOAD_URL} -o "$TEMP_UPDATE_DIR/easytier.zip" $CURL_BAR
  if [ $? -ne 0 ]; then
      echo -e "${RED_COLOR}下载失败!${RES}"
      rm -rf "$TEMP_UPDATE_DIR"
      exit 1
  fi
  
  unzip -o "$TEMP_UPDATE_DIR/easytier.zip" -d "$TEMP_UPDATE_DIR/"
  
  NEW_CORE_FILE="$TEMP_UPDATE_DIR/easytier-linux-${ARCH}/easytier-core"
  if [ ! -f "$NEW_CORE_FILE" ]; then
      echo -e "${RED_COLOR}解压失败或下载的压缩包无效。${RES}"
      rm -rf "$TEMP_UPDATE_DIR"
      exit 1
  fi
  
  echo -e "${GREEN_COLOR}新版本已准备就绪。开始更新过程...${RES}"
  
  # 3. 进入最小化停机时间窗口
  
  # 在停止服务前记录当前运行的实例
  ACTIVE_SERVICES=()
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    # 获取活动实例列表并存储到数组中
    mapfile -t ACTIVE_SERVICES < <(systemctl list-units --type=service --state=active | grep "easytier@" | awk '{print $1}')
    if [ ${#ACTIVE_SERVICES[@]} -gt 0 ]; then
        echo -e "\r\n${YELLOW_COLOR}发现正在运行的服务: ${ACTIVE_SERVICES[*]}${RES}"
        echo -e "${YELLOW_COLOR}正在停止 EasyTier 服务...${RES}"
        systemctl stop "${ACTIVE_SERVICES[@]}"
    else
        echo -e "\r\n${YELLOW_COLOR}未找到正在运行的 EasyTier 服务。无需停止。${RES}"
    fi
  else # openrc
    # openrc 脚本似乎处理单个服务，保持简单
    echo -e "\r\n${YELLOW_COLOR}正在停止 EasyTier 服务...${RES}"
    rc-service easytier stop
  fi

  # 备份关键文件，主要是配置文件
  echo "正在备份配置..."
  BACKUP_CONFIG_DIR=$(mktemp -d /tmp/easytier_config_backup_XXXXXX)
  if [ -d "$INSTALL_PATH/config" ]; then
      cp -a "$INSTALL_PATH/config" "$BACKUP_CONFIG_DIR/"
  fi
  
  echo "正在替换文件..."
  # 删除旧的可执行文件和文档，但不删除配置目录
  rm -f "$INSTALL_PATH/easytier-core" "$INSTALL_PATH/easytier-cli" "$INSTALL_PATH/LICENSE" "$INSTALL_PATH/README.md"
  
  # 将新文件移动到安装目录
  mv "$TEMP_UPDATE_DIR/easytier-linux-${ARCH}"/* "$INSTALL_PATH/"
  chmod +x "$INSTALL_PATH/easytier-core" "$INSTALL_PATH/easytier-cli"

  # 恢复配置，防止用户自定义设置被覆盖
  if [ -d "$BACKUP_CONFIG_DIR/config" ]; then
      cp -af "$BACKUP_CONFIG_DIR/config/." "$INSTALL_PATH/config/"
  fi
 
  # 4. 启动服务，恢复运行
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    if [ ${#ACTIVE_SERVICES[@]} -gt 0 ]; then
        echo -e "${GREEN_COLOR}正在启动新版本的 EasyTier 服务: ${ACTIVE_SERVICES[*]}${RES}"
        systemctl start "${ACTIVE_SERVICES[@]}"
    else
        echo -e "${GREEN_COLOR}更新前没有服务在运行。更新完成。${RES}"
    fi
  else # openrc
    echo -e "${GREEN_COLOR}正在启动新版本的 EasyTier 服务...${RES}"
    rc-service easytier start
  fi
  
  # 5. 清理临时文件
  echo "正在清理临时文件..."
  rm -rf "$TEMP_UPDATE_DIR"
  rm -rf "$BACKUP_CONFIG_DIR"
  
  echo -e "\r\n${GREEN_COLOR}EasyTier 已成功更新到版本 $LATEST_VERSION！${RES}\r\n"
}

# 设置 curl 进度条选项
if curl --help | grep progress-bar >/dev/null 2>&1; then
  CURL_BAR="--progress-bar"  # 如果 curl 支持进度条，则启用它
fi

# 确保临时目录存在
if [ ! -d "/tmp" ]; then
  mkdir -p /tmp
fi

echo $COMMEND  # 显示当前命令

# 根据命令执行相应操作
if [ "$COMMEND" = "uninstall" ]; then
  UNINSTALL
elif [ "$COMMEND" = "update" ]; then
  UPDATE
elif [ "$COMMEND" = "install" ]; then
  CHECK      # 检查安装条件
  INSTALL    # 下载安装
  INIT       # 初始化配置
  if [ -f "$INSTALL_PATH/easytier-core" ]; then
    SUCCESS  # 显示成功信息
  else
    echo -e "${RED_COLOR} 安装失败，请尝试手动安装${RES}"
  fi
else
  echo -e "${RED_COLOR} 错误命令 ${RES}\n\r"
  echo " 允许的命令:"
  echo -e "\n\r${GREEN_COLOR} install, uninstall, update, help ${RES}"
fi

# 清理临时文件
rm -rf /tmp/easytier_tmp_*
