#!/bin/bash
sh_v="0.0.22"

bai='\033[0m'
hui='\e[37m'

gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_kjlan='\033[96m'


# 修复缺失的初始化/统计函数；本地版本默认关闭统计，避免调用不存在时报错或向外发送统计。
ENABLE_STATS="false"

send_stats() {
    return 0
}



ip_address() {
ipv4_address=$(curl -s ipv4.ip.sb)
ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)
}



install() {
	if [ $# -eq 0 ]; then
		echo "未提供软件包参数!"
		return
	fi

	for package in "$@"; do
		if ! command -v "$package" &>/dev/null; then
			echo -e "${gl_huang}正在安装 $package...${gl_bai}"
			if command -v dnf &>/dev/null; then
				dnf -y update
				dnf install -y epel-release
				dnf install -y "$package"
			elif command -v yum &>/dev/null; then
				yum -y update
				yum install -y epel-release
				yum -y install "$package"
			elif command -v apt &>/dev/null; then
				apt update -y
				apt install -y "$package"
			elif command -v apk &>/dev/null; then
				apk update
				apk add "$package"
			elif command -v pacman &>/dev/null; then
				pacman -Syu --noconfirm
				pacman -S --noconfirm "$package"
			elif command -v zypper &>/dev/null; then
				zypper refresh
				zypper install -y "$package"
			elif command -v opkg &>/dev/null; then
				opkg update
				opkg install "$package"
			else
				echo "未知的包管理器!"
				return
			fi
		else
			echo -e "${gl_lv}$package 已经安装${gl_bai}"
		fi
	done

	return
}


install_dependency() {
	  clear
	  install wget socat unzip tar
}


remove() {
	if [ $# -eq 0 ]; then
		echo "未提供软件包参数!"
		return
	fi

	for package in "$@"; do
		echo -e "${gl_huang}正在卸载 $package...${gl_bai}"
		if command -v dnf &>/dev/null; then
			dnf remove -y "${package}"*
		elif command -v yum &>/dev/null; then
			yum remove -y "${package}"*
		elif command -v apt &>/dev/null; then
			apt purge -y "${package}"*
		elif command -v apk &>/dev/null; then
			apk del "${package}*"
		elif command -v pacman &>/dev/null; then
			pacman -Rns --noconfirm "${package}"
		elif command -v zypper &>/dev/null; then
			zypper remove -y "${package}"
		elif command -v opkg &>/dev/null; then
			opkg remove "${package}"
		else
			echo "未知的包管理器!"
			return
		fi
	done

	return
}


# 通用 systemctl 函数，适用于各种发行版
systemctl() {
	COMMAND="$1"
	SERVICE_NAME="$2"

	if command -v apk &>/dev/null; then
		service "$SERVICE_NAME" "$COMMAND"
	else
		/bin/systemctl "$COMMAND" "$SERVICE_NAME"
	fi
}


# 重启服务
restart() {
	systemctl restart "$1"
	if [ $? -eq 0 ]; then
		echo "$1 服务已重启。"
	else
		echo "错误：重启 $1 服务失败。"
	fi
}

# 启动服务
start() {
	systemctl start "$1"
	if [ $? -eq 0 ]; then
		echo "$1 服务已启动。"
	else
		echo "错误：启动 $1 服务失败。"
	fi
}

# 停止服务
stop() {
	systemctl stop "$1"
	if [ $? -eq 0 ]; then
		echo "$1 服务已停止。"
	else
		echo "错误：停止 $1 服务失败。"
	fi
}

# 查看服务状态
status() {
	systemctl status "$1"
	if [ $? -eq 0 ]; then
		echo "$1 服务状态已显示。"
	else
		echo "错误：无法显示 $1 服务状态。"
	fi
}


enable() {
	SERVICE_NAME="$1"
	if command -v apk &>/dev/null; then
		rc-update add "$SERVICE_NAME" default
	else
	   /bin/systemctl enable "$SERVICE_NAME"
	fi

	echo "$SERVICE_NAME 已设置为开机自启。"
}



break_end() {
	  echo -e "${gl_lv}操作完成${gl_bai}"
	  echo "按任意键继续..."
	  read -n 1 -s -r -p ""
	  echo ""
	  clear
}

kejilion() {
			cd ~
			kejilion_sh
}



check_port() {

	docker rm -f nginx >/dev/null 2>&1

	# 定义要检测的端口
	PORT=80

	# 检查端口占用情况
	result=$(ss -tulpn | grep ":\b$PORT\b")

	# 判断结果并输出相应信息
	if [ -n "$result" ]; then
			clear
			echo -e "${gl_hong}注意: ${gl_bai}端口 ${gl_huang}$PORT${gl_bai} 已被占用，无法安装环境，卸载以下程序后重试！"
			echo "$result"
			send_stats "端口冲突无法安装建站环境"
			break_end
			linux_ldnmp

	fi
}





install_add_docker_guanfang() {
	curl -fsSL https://get.docker.com | sh
	enable docker
	start docker

}



install_add_docker() {
	echo -e "${gl_huang}正在安装docker环境...${gl_bai}"
	if  [ -f /etc/os-release ] && grep -q "Fedora" /etc/os-release; then
		install_add_docker_guanfang
	elif command -v dnf &>/dev/null; then
		dnf update -y
		dnf install -y yum-utils device-mapper-persistent-data lvm2
		rm -f /etc/yum.repos.d/docker*.repo > /dev/null
		arch=$(uname -m)
		if [ "$arch" = "x86_64" ]; then
			yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
		elif [ "$arch" = "aarch64" ]; then
			yum-config-manager --add-repo https://download.docker.com/linux/centos/arm64/docker-ce.repo > /dev/null
		fi
		dnf install -y docker-ce docker-ce-cli containerd.io
		enable docker
		start docker

	elif [ -f /etc/os-release ] && grep -q "Kali" /etc/os-release; then
		apt update
		apt upgrade -y
		apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
		rm -f /usr/share/keyrings/docker-archive-keyring.gpg
		arch=$(uname -m)
		if [ "$arch" = "x86_64" ]; then
			sed -i '/^deb \[arch=amd64 signed-by=\/usr\/share\/keyrings\/docker-archive-keyring.gpg\] https:\/\/download.docker.com\/linux\/debian bullseye stable/d' /etc/apt/sources.list.d/docker.list > /dev/null
			mkdir -p /etc/apt/keyrings
			curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg > /dev/null
			echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
		elif [ "$arch" = "aarch64" ]; then
			sed -i '/^deb \[arch=arm64 signed-by=\/usr\/share\/keyrings\/docker-archive-keyring.gpg\] https:\/\/download.docker.com\/linux\/debian bullseye stable/d' /etc/apt/sources.list.d/docker.list > /dev/null
			mkdir -p /etc/apt/keyrings
			curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg > /dev/null
			echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
		fi
		apt update
		apt install -y docker-ce docker-ce-cli containerd.io
		enable docker
		start docker

	elif command -v apt &>/dev/null || command -v yum &>/dev/null; then
		install_add_docker_guanfang
	else
		install docker docker-compose
		enable docker
		start docker
	fi
	sleep 2
}


install_docker() {
	if ! command -v docker &>/dev/null; then
		install_add_docker
	else
		echo -e "${gl_lv}Docker环境已经安装${gl_bai}"
	fi

	if ! command -v docker &>/dev/null; then
		echo -e "${gl_hong}Docker安装失败或docker命令不可用，已停止继续安装应用。${gl_bai}"
		return 1
	fi

	if ! docker info &>/dev/null; then
		echo -e "${gl_huang}Docker服务未运行，正在启动...${gl_bai}"
		start docker >/dev/null 2>&1 || /bin/systemctl start docker >/dev/null 2>&1
	fi

	if ! docker info &>/dev/null; then
		echo -e "${gl_hong}Docker服务启动失败，已停止继续安装应用。${gl_bai}"
		return 1
	fi
}


docker_ps() {
while true; do
	clear
	send_stats "Docker容器管理"
	echo "Docker容器列表"
	docker ps -a
	echo ""
	echo "容器操作"
	echo "------------------------"
	echo "1. 创建新的容器"
	echo "------------------------"
	echo "2. 启动指定容器             6. 启动所有容器"
	echo "3. 停止指定容器             7. 停止所有容器"
	echo "4. 删除指定容器             8. 删除所有容器"
	echo "5. 重启指定容器             9. 重启所有容器"
	echo "------------------------"
	echo "11. 进入指定容器           12. 查看容器日志"
	echo "13. 查看容器网络           14. 查看容器占用"
	echo "------------------------"
	echo "0. 返回上一级选单"
	echo "------------------------"
	read -e -p "请输入你的选择: " sub_choice
	case $sub_choice in
		1)
			send_stats "新建容器"
			read -e -p "请输入创建命令: " dockername
			$dockername
			;;
		2)
			send_stats "启动指定容器"
			read -e -p "请输入容器名（多个容器名请用空格分隔）: " dockername
			docker start $dockername
			;;
		3)
			send_stats "停止指定容器"
			read -e -p "请输入容器名（多个容器名请用空格分隔）: " dockername
			docker stop $dockername
			;;
		4)
			send_stats "删除指定容器"
			read -e -p "请输入容器名（多个容器名请用空格分隔）: " dockername
			docker rm -f $dockername
			;;
		5)
			send_stats "重启指定容器"
			read -e -p "请输入容器名（多个容器名请用空格分隔）: " dockername
			docker restart $dockername
			;;
		6)
			send_stats "启动所有容器"
			docker start $(docker ps -a -q)
			;;
		7)
			send_stats "停止所有容器"
			docker stop $(docker ps -q)
			;;
		8)
			send_stats "删除所有容器"
			read -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定删除所有容器吗？(Y/N): ")" choice
			case "$choice" in
			  [Yy])
				docker rm -f $(docker ps -a -q)
				;;
			  [Nn])
				;;
			  *)
				echo "无效的选择，请输入 Y 或 N。"
				;;
			esac
			;;
		9)
			send_stats "重启所有容器"
			docker restart $(docker ps -q)
			;;
		11)
			send_stats "进入容器"
			read -e -p "请输入容器名: " dockername
			docker exec -it $dockername /bin/sh
			break_end
			;;
		12)
			send_stats "查看容器日志"
			read -e -p "请输入容器名: " dockername
			docker logs $dockername
			break_end
			;;
		13)
			send_stats "查看容器网络"
			echo ""
			container_ids=$(docker ps -q)
			echo "------------------------------------------------------------"
			printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"
			for container_id in $container_ids; do
				container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")
				container_name=$(echo "$container_info" | awk '{print $1}')
				network_info=$(echo "$container_info" | cut -d' ' -f2-)
				while IFS= read -r line; do
					network_name=$(echo "$line" | awk '{print $1}')
					ip_address=$(echo "$line" | awk '{print $2}')
					printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
				done <<< "$network_info"
			done
			break_end
			;;
		14)
			send_stats "查看容器占用"
			docker stats --no-stream
			break_end
			;;
		0)
			break  # 跳出循环，退出菜单
			;;
		*)
			break  # 跳出循环，退出菜单
			;;
	esac
done
}


docker_image() {
while true; do
	clear
	send_stats "Docker镜像管理"
	echo "Docker镜像列表"
	docker image ls
	echo ""
	echo "镜像操作"
	echo "------------------------"
	echo "1. 获取指定镜像             3. 删除指定镜像"
	echo "2. 更新指定镜像             4. 删除所有镜像"
	echo "------------------------"
	echo "0. 返回上一级选单"
	echo "------------------------"
	read -e -p "请输入你的选择: " sub_choice
	case $sub_choice in
		1)
			send_stats "拉取镜像"
			read -e -p "请输入镜像名（多个镜像名请用空格分隔）: " imagenames
			for name in $imagenames; do
				echo -e "${gl_huang}正在获取镜像: $name${gl_bai}"
				docker pull $name
			done
			;;
		2)
			send_stats "更新镜像"
			read -e -p "请输入镜像名（多个镜像名请用空格分隔）: " imagenames
			for name in $imagenames; do
				echo -e "${gl_huang}正在更新镜像: $name${gl_bai}"
				docker pull $name
			done
			;;
		3)
			send_stats "删除镜像"
			read -e -p "请输入镜像名（多个镜像名请用空格分隔）: " imagenames
			for name in $imagenames; do
				docker rmi -f $name
			done
			;;
		4)
			send_stats "删除所有镜像"
			read -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定删除所有镜像吗？(Y/N): ")" choice
			case "$choice" in
			  [Yy])
				docker rmi -f $(docker images -q)
				;;
			  [Nn])
				;;
			  *)
				echo "无效的选择，请输入 Y 或 N。"
				;;
			esac
			;;
		0)
			break  # 跳出循环，退出菜单
			;;
		*)
			break  # 跳出循环，退出菜单
			;;
	esac
done


}





check_crontab_installed() {
	if command -v crontab >/dev/null 2>&1; then
		echo -e "${gl_lv}crontab 已经安装${gl_bai}"
		return
	else
		install_crontab
		return
	fi
}



install_crontab() {

	if [ -f /etc/os-release ]; then
		. /etc/os-release
		case "$ID" in
			ubuntu|debian|kali)
				apt update
				apt install -y cron
				systemctl enable cron
				systemctl start cron
				;;
			centos|rhel|almalinux|rocky|fedora)
				yum install -y cronie
				systemctl enable crond
				systemctl start crond
				;;
			alpine)
				apk add --no-cache cronie
				rc-update add crond
				rc-service crond start
				;;
			arch|manjaro)
				pacman -S --noconfirm cronie
				systemctl enable cronie
				systemctl start cronie
				;;
			opensuse|suse|opensuse-tumbleweed)
				zypper install -y cron
				systemctl enable cron
				systemctl start cron
				;;
			openwrt|lede)
				opkg update
				opkg install cron
				/etc/init.d/cron enable
				/etc/init.d/cron start
				;;
			*)
				echo "不支持的发行版: $ID"
				return
				;;
		esac
	else
		echo "无法确定操作系统。"
		return
	fi

	echo -e "${gl_lv}crontab 已安装且 cron 服务正在运行。${gl_bai}"
}



docker_ipv6_on() {
mkdir -p /etc/docker &>/dev/null

cat > /etc/docker/daemon.json << EOF

{
  "ipv6": true,
  "fixed-cidr-v6": "2001:db8:1::/64"
}

EOF

k restart docker

echo "Docker已开启v6访问"

}


docker_ipv6_off() {

rm -rf etc/docker/daemon.json &>/dev/null

k restart docker

echo "Docker已关闭v6访问"

}





iptables_open() {
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -F

	ip6tables -P INPUT ACCEPT
	ip6tables -P FORWARD ACCEPT
	ip6tables -P OUTPUT ACCEPT
	ip6tables -F

}



add_swap() {
	# 获取当前系统中所有的 swap 分区
	swap_partitions=$(grep -E '^/dev/' /proc/swaps | awk '{print $1}')

	# 遍历并删除所有的 swap 分区
	for partition in $swap_partitions; do
	  swapoff "$partition"
	  wipefs -a "$partition"  # 清除文件系统标识符
	  mkswap -f "$partition"
	done

	# 确保 /swapfile 不再被使用
	swapoff /swapfile

	# 删除旧的 /swapfile
	rm -f /swapfile

	# 创建新的 swap 分区
	dd if=/dev/zero of=/swapfile bs=1M count=$new_swap
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile

	if [ -f /etc/alpine-release ]; then
		echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
		echo "nohup swapon /swapfile" >> /etc/local.d/swap.start
		chmod +x /etc/local.d/swap.start
		rc-update add local
	else
		echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
	fi

	echo -e "虚拟内存大小已调整为${gl_huang}${new_swap}${gl_bai}MB"
}



check_swap() {

swap_total=$(free -m | awk 'NR==3{print $2}')

 # 判断是否需要创建虚拟内存
if [ "$swap_total" -gt 0 ]; then
	:
else
	new_swap=1024
	add_swap
fi

}









ldnmp_v() {

	  # 获取nginx版本
	  nginx_version=$(docker exec nginx nginx -v 2>&1)
	  nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
	  echo -n -e "nginx : ${gl_huang}v$nginx_version${gl_bai}"

	  # 获取mysql版本
	  dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	  mysql_version=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SELECT VERSION();" 2>/dev/null | tail -n 1)
	  echo -n -e "            mysql : ${gl_huang}v$mysql_version${gl_bai}"

	  # 获取php版本
	  php_version=$(docker exec php php -v 2>/dev/null | grep -oP "PHP \K[0-9]+\.[0-9]+\.[0-9]+")
	  echo -n -e "            php : ${gl_huang}v$php_version${gl_bai}"

	  # 获取redis版本
	  redis_version=$(docker exec redis redis-server -v 2>&1 | grep -oP "v=+\K[0-9]+\.[0-9]+")
	  echo -e "            redis : ${gl_huang}v$redis_version${gl_bai}"

	  echo "------------------------"

}






ldnmp_compose_set_image() {
  local service="$1"
  local image="$2"
  local compose_file="/home/web/docker-compose.yml"
  [ -f "$compose_file" ] || return 1
  python3 - "$compose_file" "$service" "$image" <<'PY'
import sys
path, service, image = sys.argv[1:4]
lines = open(path, encoding='utf-8').read().splitlines(True)
out = []
in_service = False
service_indent = None
changed = False
for line in lines:
    stripped = line.lstrip(' ')
    indent = len(line) - len(stripped)
    if stripped.startswith(service + ':') and indent >= 2:
        in_service = True
        service_indent = indent
        out.append(line)
        continue
    if in_service and stripped and not stripped.startswith('#') and indent <= service_indent and ':' in stripped:
        in_service = False
        service_indent = None
    if in_service and stripped.startswith('image:'):
        newline = '\n' if line.endswith('\n') else ''
        out.append(' ' * indent + 'image: ' + image + newline)
        changed = True
    else:
        out.append(line)
if not changed:
    sys.exit(1)
open(path, 'w', encoding='utf-8').write(''.join(out))
PY
}

ldnmp_wait_mysql_ready() {
  local dbrootpasswd="$1"
  local i
  for i in {1..60}; do
    if docker exec mysql mysqladmin ping -uroot -p"$dbrootpasswd" --silent >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

ldnmp_mysql_datadir_version() {
  local mysql_cnf="/home/web/mysql/auto.cnf"
  local dd_file="/home/web/mysql/mysql.ibd"
  [ -f "$dd_file" ] || return 1
  if [ -f "$mysql_cnf" ]; then
    grep -aoE 'mysql_server_version=[0-9]+|server_version=[0-9]+|[0-9]{6}' "$mysql_cnf" 2>/dev/null | grep -aoE '[0-9]{6}' | head -n1
  fi
}

ldnmp_mysql_image_major_code() {
  local image="$1"
  local ver
  ver=$(docker run --rm --entrypoint mysqld "$image" --version 2>/dev/null | grep -aoE 'Ver [0-9]+\.[0-9]+\.[0-9]+' | head -n1 | awk '{print $2}')
  [ -n "$ver" ] || return 1
  IFS=. read -r major minor patch <<EOF
$ver
EOF
  printf '%d%02d%02d
' "$major" "$minor" "$patch"
}

ldnmp_mysql_version_guard() {
  local image="$1"
  local current target
  current=$(ldnmp_mysql_datadir_version || true)
  [ -n "$current" ] || return 0
  target=$(ldnmp_mysql_image_major_code "$image" || true)
  [ -n "$target" ] || return 0
  if [ "$target" -lt "$current" ]; then
    echo "检测到 MySQL 数据目录版本高于目标镜像，禁止降级。"
    echo "当前数据目录版本代码：$current"
    echo "目标镜像版本代码：$target"
    echo "MySQL 不支持跨版本降级，只允许同一补丁线内降级。请使用不低于当前数据目录版本的镜像，或从低版本备份恢复到新的空数据目录。"
    return 1
  fi
  return 0
}

ldnmp_configure_php_container() {
  local php_container="$1"
  run_command docker exec "$php_container" sed -i "s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g" /etc/apk/repositories > /dev/null 2>&1 || true
  docker exec "$php_container" apk update || return 1
  curl -sL ${gh_proxy}https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o /usr/local/bin/install-php-extensions || return 1
  docker exec "$php_container" mkdir -p /usr/local/bin/ || return 1
  docker cp /usr/local/bin/install-php-extensions "$php_container":/usr/local/bin/ || return 1
  docker exec "$php_container" chmod +x /usr/local/bin/install-php-extensions || return 1
  docker exec "$php_container" sh -c "apk add --no-cache imagemagick imagemagick-dev && apk add --no-cache git autoconf gcc g++ make pkgconfig && rm -rf /tmp/imagick && git clone ${gh_proxy}https://github.com/Imagick/imagick /tmp/imagick && cd /tmp/imagick && phpize && ./configure && make && make install && echo 'extension=imagick.so' > /usr/local/etc/php/conf.d/imagick.ini && rm -rf /tmp/imagick" || return 1
  docker exec "$php_container" install-php-extensions mysqli pdo_mysql gd intl zip exif bcmath opcache redis || return 1
  docker exec "$php_container" sh -c 'echo "upload_max_filesize=50M " > /usr/local/etc/php/conf.d/uploads.ini' || return 1
  docker exec "$php_container" sh -c 'echo "post_max_size=50M " > /usr/local/etc/php/conf.d/post.ini' || return 1
  docker exec "$php_container" sh -c 'echo "memory_limit=256M" > /usr/local/etc/php/conf.d/memory.ini' || return 1
  docker exec "$php_container" sh -c 'echo "max_execution_time=1200" > /usr/local/etc/php/conf.d/max_execution_time.ini' || return 1
  docker exec "$php_container" sh -c 'echo "max_input_time=600" > /usr/local/etc/php/conf.d/max_input_time.ini' || return 1
  docker exec "$php_container" sh -c 'echo "max_input_vars=3000" > /usr/local/etc/php/conf.d/max_input_vars.ini' || return 1
  docker exec "$php_container" chmod -R 777 /var/www/html || return 1
  if [ "$php_container" = "php" ]; then
    ldnmp_apply_ioncube || return 1
  else
    docker restart "$php_container" > /dev/null 2>&1 || return 1
  fi
  return 0
}

ldnmp_set_redis_policy() {
  docker exec redis redis-cli CONFIG SET maxmemory 512mb >/dev/null 2>&1 || true
  docker exec redis redis-cli CONFIG SET maxmemory-policy allkeys-lru >/dev/null 2>&1 || true
}

ldnmp_default_mysql_version="9.7"
ldnmp_default_php_version="8.3"
ldnmp_selected_mysql_version="$ldnmp_default_mysql_version"
ldnmp_selected_php_version="$ldnmp_default_php_version"
ldnmp_selected_ioncube="n"

ldnmp_detect_current_versions() {
  local cur_mysql cur_php
  cur_mysql=$(docker exec mysql mysqld --version 2>/dev/null | grep -aoE 'Ver [0-9]+\.[0-9]+\.[0-9]+' | head -n1 | awk '{print $2}')
  cur_php=$(docker exec php php -r 'echo PHP_VERSION;' 2>/dev/null)
  [ -n "$cur_mysql" ] && echo "当前 MySQL：$cur_mysql"
  [ -n "$cur_php" ] && echo "当前 PHP：$cur_php"
}

# ionCube 只管理主 php 容器；n 表示最终不启用，不影响独立 php74。
ldnmp_select_ioncube() {
  local answer
  ldnmp_selected_ioncube="n"
  while true; do
    if ! read -e -p "是否安装ionCube Loader？（y/n，回车默认n）：" answer; then
      echo "已取消 ionCube 选择。"
      return 1
    fi
    case "$answer" in
      [Yy]) ldnmp_selected_ioncube="y"; return 0 ;;
      ""|[Nn]) ldnmp_selected_ioncube="n"; return 0 ;;
      *) echo "请输入 y 或 n。" ;;
    esac
  done
}

ldnmp_apply_ioncube() {
  local actual_php
  actual_php=$(docker exec php php -n -r 'echo PHP_MAJOR_VERSION,".",PHP_MINOR_VERSION;') || { echo "读取 PHP 实际版本失败。"; return 1; }
  [ -n "$actual_php" ] || { echo "PHP 实际版本为空。"; return 1; }
  # 先清理旧加载项，避免旧版本 Loader 阻止 PHP/扩展安装工具启动。
  # 仅删除 ionCube 的加载行和专属 .so，保留同一 ini 中的其他设置。
  if ! docker exec -i php sh -s <<'IONCUBE_CLEANUP'
set -eu
ini_dir="${PHP_INI_DIR:-/usr/local/etc/php}"
ext_dir=$(php -n -r 'echo ini_get("extension_dir");')
for file in "$ini_dir/php.ini" "$ini_dir"/conf.d/*.ini; do
  [ -f "$file" ] || continue
  if grep -Ei '^[[:space:]]*(zend_extension|extension)[[:space:]]*=.*ioncube' "$file" >/dev/null; then
    sed -i '/^[[:space:]]*[Zz][Ee][Nn][Dd]_[Ee][Xx][Tt][Ee][Nn][Ss][Ii][Oo][Nn][[:space:]]*=.*[Ii][Oo][Nn][Cc][Uu][Bb][Ee]/d; /^[[:space:]]*[Ee][Xx][Tt][Ee][Nn][Ss][Ii][Oo][Nn][[:space:]]*=.*[Ii][Oo][Nn][Cc][Uu][Bb][Ee]/d' "$file"
  fi
 done
for file in "$ext_dir"/ioncube*.so; do
  [ -f "$file" ] || continue
  rm -f "$file"
done
IONCUBE_CLEANUP
  then
    echo "清理旧 ionCube 失败，请检查只读挂载或文件权限。"
    return 1
  fi
  if [ "${ldnmp_selected_ioncube:-n}" = "y" ]; then
    echo "正在安装适配 PHP ${actual_php} 的 ionCube Loader……"
    docker exec php install-php-extensions ioncube_loader || { echo "ionCube 安装失败。"; return 1; }
    # Loader 必须在 OPcache 前加载，00 前缀优先于常规扩展配置。
    docker exec php sh -ec '
      dir="${PHP_INI_DIR:-/usr/local/etc/php}/conf.d"
      for file in "$dir"/*.ini; do
        [ -f "$file" ] || continue
        if grep -Ei "^[[:space:]]*zend_extension[[:space:]]*=.*ioncube" "$file" >/dev/null; then
          [ "$file" = "$dir/00-ioncube.ini" ] || mv "$file" "$dir/00-ioncube.ini"
        fi
      done
    ' || { echo "调整 ionCube 加载顺序失败。"; return 1; }
  fi
  docker exec php php-fpm -t || { echo "PHP-FPM 配置检查失败。"; return 1; }
  docker restart php >/dev/null || { echo "PHP 重启失败。"; return 1; }
  if [ "${ldnmp_selected_ioncube:-n}" = "y" ]; then
    docker exec php php -r 'exit(extension_loaded("ionCube Loader") && function_exists("ioncube_loader_version") ? 0 : 1);' || { echo "ionCube 未成功加载，不能确认配置完成。"; return 1; }
    echo "ionCube Loader 已启用（PHP ${actual_php}）。"
  else
    docker exec php php -r 'exit(extension_loaded("ionCube Loader") || function_exists("ioncube_loader_version") ? 1 : 0);' || { echo "ionCube 仍然加载或 PHP 检查失败。"; return 1; }
    echo "ionCube Loader 未启用（PHP ${actual_php}）。"
  fi
}

ldnmp_select_versions() {
  local mysql_prompt="${1:-请输入mysql版本号 （如: $ldnmp_default_mysql_version）（回车默认$ldnmp_default_mysql_version）: }"
  local php_prompt="${2:-请输入php版本号 （如: 7.4 8.0 8.1 8.2 8.3 8.4 8.5）（回车默认$ldnmp_default_php_version）: }"
  local mysql_version php_version
  ldnmp_detect_current_versions
  read -e -p "$mysql_prompt" mysql_version
  mysql_version=${mysql_version:-$ldnmp_default_mysql_version}
  read -e -p "$php_prompt" php_version
  php_version=${php_version:-$ldnmp_default_php_version}
  ldnmp_selected_mysql_version="$mysql_version"
  ldnmp_selected_php_version="$php_version"
  ldnmp_select_ioncube || return 1
}

ldnmp_apply_versions() {
  local mysql_version="${1:-$ldnmp_selected_mysql_version}"
  local php_version="${2:-$ldnmp_selected_php_version}"
  ldnmp_compose_set_image mysql "mysql:${mysql_version}"
  ldnmp_compose_set_image php "php:${php_version}-fpm-alpine"
  ldnmp_compose_set_image nginx "nginx:alpine"
  ldnmp_compose_set_image redis "redis:alpine"
}
ldnmp_show_default_versions() {
  echo -e "${gl_huang}默认版本策略 包括安装 还原全站数据 更新完整环境${gl_bai}"
  echo -e "1. nginx：${gl_lv}最新${gl_bai}"
  echo -e "2. mysql：${gl_hong}默认${ldnmp_default_mysql_version}${gl_bai}"
  echo -e "3. php：${gl_hong}默认${ldnmp_default_php_version}，可选 8.4/8.5${gl_bai}"
  echo -e "4. redis：${gl_lv}最新${gl_bai}"
  echo "------------------------"
}
# Nginx 文件日志按大小轮转：保留份数不含当前日志；修改后安装/更新 nginx 生效。
ldnmp_nginx_log_keep=7
ldnmp_nginx_log_size_mb=30
ldnmp_nginx_error_log_keep=7
ldnmp_nginx_error_log_size_mb=10
ldnmp_nginx_log_check_seconds=30

ldnmp_prepare_nginx_log_rotation() {
  local keep="$ldnmp_nginx_log_keep" size="$ldnmp_nginx_log_size_mb" interval="$ldnmp_nginx_log_check_seconds"
  local error_keep="$ldnmp_nginx_error_log_keep" error_size="$ldnmp_nginx_error_log_size_mb"
  local value
  for value in "$keep" "$size" "$error_keep" "$error_size" "$interval"; do
    case "$value" in ''|*[!0-9]*|0|0*) echo "Nginx 日志轮转参数必须为不带前导零的正整数。"; return 1 ;; esac
    [ "${#value}" -le 6 ] || { echo "Nginx 日志轮转参数过大。"; return 1; }
  done
  command -v python3 >/dev/null 2>&1 || install python3
  command -v python3 >/dev/null 2>&1 || return 1
  mkdir -p /home/web//log/nginx-log /home/web/log/nginx || return 1
  local hook=/home/web//log/nginx-log/40-size-rotate.sh
  {
    printf '#!/bin/sh\nACCESS_KEEP=%s\nACCESS_SIZE_MB=%s\nERROR_KEEP=%s\nERROR_SIZE_MB=%s\nCHECK_SECONDS=%s\n' "$keep" "$size" "$error_keep" "$error_size" "$interval"
    cat <<'NGINX_ROTATE'
# Executed by the official nginx entrypoint, not by host cron.
if [ "${1:-}" != "--worker" ]; then
    "$0" --worker &
    exit 0
fi
# Wait for nginx to start; container termination stops this worker as well.
while [ ! -s /var/run/nginx.pid ]; do sleep 1; done
while :; do
    pid=$(cat /var/run/nginx.pid 2>/dev/null) || exit 0
    kill -0 "$pid" 2>/dev/null || exit 0
    rotated=0
    for log in /var/log/nginx/access.log /var/log/nginx/error.log; do
        case "$log" in
            */access.log) KEEP=$ACCESS_KEEP; limit=$((ACCESS_SIZE_MB * 1024 * 1024)) ;;
            */error.log) KEEP=$ERROR_KEEP; limit=$((ERROR_SIZE_MB * 1024 * 1024)) ;;
        esac
        # Never follow a symlink (e.g. image defaults pointing to stdout).
        [ ! -L "$log" ] || continue
        if [ ! -f "$log" ]; then
            # Retry a previous reopen failure without shifting any archives.
            [ ! -f "$log.1" ] || rotated=1
            continue
        fi
        bytes=$(stat -c %s "$log" 2>/dev/null) || continue
        [ "$bytes" -ge "$limit" ] || continue
        # Drop only numeric archives outside the configured retention count.
        for archive in "$log".*; do
            suffix=${archive##*.}
            case "$suffix" in ''|*[!0-9]*) continue ;; esac
            [ "$suffix" -lt "$KEEP" ] 2>/dev/null || rm -f -- "$archive"
        done
        n=$((KEEP - 1))
        while [ "$n" -ge 1 ]; do
            if [ -f "$log.$n" ]; then
                mv -f -- "$log.$n" "$log.$((n + 1))" || exit 1
            fi
            n=$((n - 1))
        done
        # nginx keeps writing to this inode until USR1 reopens the active path.
        mv -f -- "$log" "$log.1" || exit 1
        rotated=1
    done
    if [ "$rotated" = 1 ]; then
        nginx -s reopen || printf '%s\n' 'Nginx log reopen failed; will retry.' >&2
    fi
    sleep "$CHECK_SECONDS"
done
NGINX_ROTATE
  } > "$hook" || return 1
  chmod 0755 "$hook" || return 1
  # Add a read-only entrypoint hook mount only; leave ports/images/other mounts intact.
  python3 - /home/web/docker-compose.yml <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
lines = path.read_text().splitlines(True)
start = next((i for i, line in enumerate(lines) if re.fullmatch(r'  nginx:\s*\n?', line)), None)
if start is None:
    raise SystemExit('未找到标准 nginx Compose 服务，未添加轮转挂载。')
end = next((i for i in range(start+1, len(lines)) if lines[i].strip() and not lines[i].lstrip().startswith('#') and len(lines[i])-len(lines[i].lstrip()) <= 2), len(lines))
mount = '      - ./log/nginx-log/40-size-rotate.sh:/docker-entrypoint.d/40-size-rotate.sh:ro\n'
block = lines[start:end]
existing = [i for i in range(start+1, end) if '/docker-entrypoint.d/40-size-rotate.sh' in lines[i]]
if existing:
    # 更新旧版挂载源路径，同时删除同一入口脚本的重复挂载。
    lines[existing[0]] = mount
    for i in reversed(existing[1:]):
        del lines[i]
    updated = ''.join(lines)
    if updated != path.read_text():
        path.write_text(updated)
    raise SystemExit(0)
vol = next((i for i in range(start+1, end) if re.fullmatch(r'    volumes:\s*\n?', lines[i])), None)
if vol is None:
    raise SystemExit('未找到 nginx volumes 列表，未添加轮转挂载。')
lines.insert(vol+1, mount)
path.write_text(''.join(lines))
PY
}

install_ldnmp_conf() {

  # 创建必要的目录和文件
  cd /home && mkdir -p web/html web/mysql web/certs web/conf.d web/redis web/log/nginx && touch web/docker-compose.yml
  wget -O /home/web/nginx.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/nginx10.conf
  wget -O /home/web/conf.d/default.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/default10.conf

  default_server_ssl

  # 下载 docker-compose.yml 文件并进行替换
  wget -O /home/web/docker-compose.yml ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/docker/main/LNMP-docker-compose-10.yml
  dbrootpasswd=$(openssl rand -base64 16) ; dbuse=$(openssl rand -hex 4) ; dbusepasswd=$(openssl rand -base64 8)

  # 在 docker-compose.yml 文件中进行替换
  sed -i "s#webroot#$dbrootpasswd#g" /home/web/docker-compose.yml
  sed -i "s#kejilionYYDS#$dbusepasswd#g" /home/web/docker-compose.yml
  sed -i "s#kejilion#$dbuse#g" /home/web/docker-compose.yml

}





install_ldnmp() {

	  check_swap
	  ldnmp_prepare_nginx_log_rotation || { echo "Nginx 日志轮转配置失败，已停止安装。"; return 1; }
	  cd /home/web && docker compose up -d
	  clear
	  echo "正在配置LDNMP环境，请耐心稍等……"

	  # 定义要执行的命令
	  commands=(
		  "docker exec nginx chmod -R 777 /var/www/html > /dev/null 2>&1"
		  "docker exec nginx mkdir -p /var/cache/nginx/proxy > /dev/null 2>&1"
		  "docker exec nginx chmod 777 /var/cache/nginx/proxy > /dev/null 2>&1"
		  "docker exec nginx mkdir -p /var/cache/nginx/fastcgi > /dev/null 2>&1"
		  "docker exec nginx chmod 777 /var/cache/nginx/fastcgi > /dev/null 2>&1"
		  "docker restart nginx > /dev/null 2>&1"

		  "run_command docker exec php sed -i \"s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g\" /etc/apk/repositories > /dev/null 2>&1"
		  "run_command docker exec php74 sed -i \"s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g\" /etc/apk/repositories > /dev/null 2>&1"

		  # "docker exec php sed -i "s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g" /etc/apk/repositories > /dev/null 2>&1"
		  # "docker exec php74 sed -i "s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g" /etc/apk/repositories > /dev/null 2>&1"

		  "docker exec php apk update > /dev/null 2>&1"
		  "docker exec php74 apk update > /dev/null 2>&1"

		  # php安装包管理
		  "curl -sL ${gh_proxy}https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o /usr/local/bin/install-php-extensions > /dev/null 2>&1"
		  "docker exec php mkdir -p /usr/local/bin/ > /dev/null 2>&1"
		  "docker exec php74 mkdir -p /usr/local/bin/ > /dev/null 2>&1"
		  "docker cp /usr/local/bin/install-php-extensions php:/usr/local/bin/ > /dev/null 2>&1"
		  "docker cp /usr/local/bin/install-php-extensions php74:/usr/local/bin/ > /dev/null 2>&1"
		  "docker exec php chmod +x /usr/local/bin/install-php-extensions > /dev/null 2>&1"
		  "docker exec php74 chmod +x /usr/local/bin/install-php-extensions > /dev/null 2>&1"

		  # php安装扩展
		  "docker exec php sh -c '\
					apk add --no-cache imagemagick imagemagick-dev \
					&& apk add --no-cache git autoconf gcc g++ make pkgconfig \
					&& rm -rf /tmp/imagick \
					&& git clone ${gh_proxy}https://github.com/Imagick/imagick /tmp/imagick \
					&& cd /tmp/imagick \
					&& phpize \
					&& ./configure \
					&& make \
					&& make install \
					&& echo 'extension=imagick.so' > /usr/local/etc/php/conf.d/imagick.ini \
					&& rm -rf /tmp/imagick' > /dev/null 2>&1"


		  "docker exec php install-php-extensions imagick > /dev/null 2>&1"
		  "docker exec php install-php-extensions mysqli > /dev/null 2>&1"
		  "docker exec php install-php-extensions pdo_mysql > /dev/null 2>&1"
		  "docker exec php install-php-extensions gd > /dev/null 2>&1"
		  "docker exec php install-php-extensions intl > /dev/null 2>&1"
		  "docker exec php install-php-extensions zip > /dev/null 2>&1"
		  "docker exec php install-php-extensions exif > /dev/null 2>&1"
		  "docker exec php install-php-extensions bcmath > /dev/null 2>&1"
		  "docker exec php install-php-extensions opcache > /dev/null 2>&1"
		  "docker exec php install-php-extensions redis > /dev/null 2>&1"


		  # php配置参数
		  "docker exec php sh -c 'echo \"upload_max_filesize=50M \" > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1"
		  "docker exec php sh -c 'echo \"post_max_size=50M \" > /usr/local/etc/php/conf.d/post.ini' > /dev/null 2>&1"
		  "docker exec php sh -c 'echo \"memory_limit=256M\" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1"
		  "docker exec php sh -c 'echo \"max_execution_time=1200\" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1"
		  "docker exec php sh -c 'echo \"max_input_time=600\" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1"
		  "docker exec php sh -c 'echo \"max_input_vars=3000\" > /usr/local/etc/php/conf.d/max_input_vars.ini' > /dev/null 2>&1"

		  # php重启
		  "docker exec php chmod -R 777 /var/www/html"
		  "docker restart php > /dev/null 2>&1"

		  # php7.4安装扩展
		  "docker exec php74 install-php-extensions imagick > /dev/null 2>&1"
		  "docker exec php74 install-php-extensions mysqli > /dev/null 2>&1"
		  "docker exec php74 install-php-extensions pdo_mysql > /dev/null 2>&1"
		  "docker exec php74 install-php-extensions gd > /dev/null 2>&1"
		  "docker exec php74 install-php-extensions intl > /dev/null 2>&1"
		  "docker exec php74 install-php-extensions zip > /dev/null 2>&1"
		  "docker exec php74 install-php-extensions exif > /dev/null 2>&1"
		  "docker exec php74 install-php-extensions bcmath > /dev/null 2>&1"
		  "docker exec php74 install-php-extensions opcache > /dev/null 2>&1"
		  "docker exec php74 install-php-extensions redis > /dev/null 2>&1"

		  # php7.4配置参数
		  "docker exec php74 sh -c 'echo \"upload_max_filesize=50M \" > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1"
		  "docker exec php74 sh -c 'echo \"post_max_size=50M \" > /usr/local/etc/php/conf.d/post.ini' > /dev/null 2>&1"
		  "docker exec php74 sh -c 'echo \"memory_limit=256M\" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1"
		  "docker exec php74 sh -c 'echo \"max_execution_time=1200\" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1"
		  "docker exec php74 sh -c 'echo \"max_input_time=600\" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1"
		  "docker exec php74 sh -c 'echo \"max_input_vars=3000\" > /usr/local/etc/php/conf.d/max_input_vars.ini' > /dev/null 2>&1"

		  # php7.4重启
		  "docker exec php74 chmod -R 777 /var/www/html"
		  "docker restart php74 > /dev/null 2>&1"

		  # redis调优
		  "docker exec -it redis redis-cli CONFIG SET maxmemory 512mb > /dev/null 2>&1"
		  "docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru > /dev/null 2>&1"

	  )

	  total_commands=${#commands[@]}  # 计算总命令数

	  for ((i = 0; i < total_commands; i++)); do
		  command="${commands[i]}"
		  eval $command  # 执行命令

		  # 打印百分比和进度条
		  percentage=$(( (i + 1) * 100 / total_commands ))
		  completed=$(( percentage / 2 ))
		  remaining=$(( 50 - completed ))
		  progressBar="["
		  for ((j = 0; j < completed; j++)); do
			  progressBar+="#"
		  done
		  for ((j = 0; j < remaining; j++)); do
			  progressBar+="."
		  done
		  progressBar+="]"
		  echo -ne "\r[${gl_lv}$percentage%${gl_bai}] $progressBar"
	  done

	  echo  # 打印换行，以便输出不被覆盖


	  ldnmp_apply_ioncube || { echo "LDNMP 的 PHP/ionCube 配置失败，未确认安装完成。"; return 1; }
	  clear
	  echo "LDNMP环境安装完毕"
	  echo "------------------------"
	  ldnmp_v

}


install_certbot() {

	install certbot

	cd ~

	# 下载并使脚本可执行
	curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/auto_cert_renewal.sh
	chmod +x auto_cert_renewal.sh

	# 设置定时任务字符串
	check_crontab_installed
	cron_job="0 0 * * * ~/auto_cert_renewal.sh"

	# 检查是否存在相同的定时任务
	existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

	# 如果不存在，则添加定时任务
	if [ -z "$existing_cron" ]; then
		(crontab -l 2>/dev/null; echo "$cron_job") | crontab -
		echo "续签任务已添加"
	fi
}


install_ssltls() {
	  docker stop nginx > /dev/null 2>&1
	  iptables_open > /dev/null 2>&1
	  cd ~

	  yes | certbot delete --cert-name $yuming > /dev/null 2>&1

	  certbot_version=$(certbot --version 2>&1 | grep -oP "\d+\.\d+\.\d+")

	  version_ge() {
		  [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$1" ]
	  }

	  if version_ge "$certbot_version" "1.17.0"; then
		  certbot certonly --standalone -d $yuming --email your@email.com --agree-tos --no-eff-email --force-renewal --key-type ecdsa
	  else
		  certbot certonly --standalone -d $yuming --email your@email.com --agree-tos --no-eff-email --force-renewal
	  fi

	  cp /etc/letsencrypt/live/$yuming/fullchain.pem /home/web/certs/${yuming}_cert.pem > /dev/null 2>&1
	  cp /etc/letsencrypt/live/$yuming/privkey.pem /home/web/certs/${yuming}_key.pem > /dev/null 2>&1
	  docker start nginx > /dev/null 2>&1
}



install_ssltls_text() {
	echo -e "${gl_huang}$yuming 公钥信息${gl_bai}"
	cat /etc/letsencrypt/live/$yuming/fullchain.pem
	echo ""
	echo -e "${gl_huang}$yuming 私钥信息${gl_bai}"
	cat /etc/letsencrypt/live/$yuming/privkey.pem
	echo ""
	echo -e "${gl_huang}证书存放路径${gl_bai}"
	echo "公钥: /etc/letsencrypt/live/$yuming/fullchain.pem"
	echo "私钥: /etc/letsencrypt/live/$yuming/privkey.pem"
	echo ""
}





add_ssl() {

add_yuming
install_certbot
install_ssltls
certs_status
install_ssltls_text
ssl_ps
}


ssl_ps() {
	echo -e "${gl_huang}已申请的证书到期情况${gl_bai}"
	echo "站点信息                      证书到期时间"
	echo "------------------------"
	for cert_dir in /etc/letsencrypt/live/*; do
	  cert_file="$cert_dir/fullchain.pem"
	  if [ -f "$cert_file" ]; then
		domain=$(basename "$cert_dir")
		expire_date=$(openssl x509 -noout -enddate -in "$cert_file" | awk -F'=' '{print $2}')
		formatted_date=$(date -d "$expire_date" '+%Y-%m-%d')
		printf "%-30s%s\n" "$domain" "$formatted_date"
	  fi
	done
	echo ""
}




default_server_ssl() {
install openssl

if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
	openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /home/web/certs/default_server.key -out /home/web/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
else
	openssl genpkey -algorithm Ed25519 -out /home/web/certs/default_server.key
	openssl req -x509 -key /home/web/certs/default_server.key -out /home/web/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
fi

openssl rand -out /home/web/certs/ticket12.key 48
openssl rand -out /home/web/certs/ticket13.key 80

}


certs_status() {

	sleep 1
	file_path="/etc/letsencrypt/live/$yuming/fullchain.pem"
	if [ -f "$file_path" ]; then
		send_stats "域名证书申请成功"
	else
		send_stats "域名证书申请失败"
		echo -e "${gl_hong}注意: ${gl_bai}检测到域名证书申请失败，请检测域名是否正确解析或更换域名重新尝试！"
		break_end
		linux_ldnmp
	fi

}

repeat_add_yuming() {

domain_regex="^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"
if [[ $yuming =~ $domain_regex ]]; then
  :
else
  send_stats "域名格式不正确"
  echo -e "${gl_huang}提示: ${gl_bai}域名格式不正确，请重新输入"
  break_end
  linux_ldnmp
fi

if [ -e /home/web/conf.d/$yuming.conf ]; then
  send_stats "域名重复使用"
  echo -e "${gl_huang}提示: ${gl_bai}当前 ${yuming} 域名已被使用，请前往31站点管理，删除站点，再部署 ${webname} ！"
  break_end
  linux_ldnmp
fi

}


add_yuming() {
	  ip_address
	  echo -e "先将域名解析到本机IP: ${gl_huang}$ipv4_address  $ipv6_address${gl_bai}"
	  read -e -p "请输入你解析的域名: " yuming
	  repeat_add_yuming

}


add_db() {
	  dbname=$(echo "$yuming" | sed -e 's/[^A-Za-z0-9]/_/g')
	  dbname="${dbname}"

	  dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	  dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	  dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	  docker exec mysql mysql -u root -p"$dbrootpasswd" -e "CREATE DATABASE $dbname; GRANT ALL PRIVILEGES ON $dbname.* TO \"$dbuse\"@\"%\";"
}

reverse_proxy() {
	  ip_address
	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/reverse-proxy.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  sed -i "s/0.0.0.0/$ipv4_address/g" /home/web/conf.d/$yuming.conf
	  sed -i "s/0000/$duankou/g" /home/web/conf.d/$yuming.conf
	  docker restart nginx
}

restart_ldnmp() {
	  docker exec nginx chmod -R 777 /var/www/html
	  docker exec php chmod -R 777 /var/www/html
	  docker exec php74 chmod -R 777 /var/www/html

	  cd /home/web && docker compose restart

}

nginx_upgrade() {

  ldnmp_pods="nginx"
  cd /home/web/ || return 1

  if [ ! -f /home/web/docker-compose.yml ]; then
    echo "错误：未找到 /home/web/docker-compose.yml，无法更新 nginx。"
    return 1
  fi

  ldnmp_prepare_nginx_log_rotation || { echo "Nginx 日志轮转配置失败，未重建容器。"; return 1; }
  echo "正在更新 nginx 镜像并重建容器..."
  docker rm -f $ldnmp_pods > /dev/null 2>&1

  local old_images
  old_images=$(docker images --filter=reference="$ldnmp_pods*" -q | sort -u)
  if [ -n "$old_images" ]; then
    echo "$old_images" | xargs -r docker rmi > /dev/null 2>&1 || true
  fi

  if ! docker compose up -d --pull always --force-recreate $ldnmp_pods; then
    echo "错误：nginx 容器重建失败。请检查上面的 Docker 输出。"
    return 1
  fi

  # 如果 nginx 配置里反代了其它 Docker 容器，重建 nginx 后会丢失手动连接的外部网络。
  # 自动把 nginx 重新加入这些后端容器所在的网络，避免出现：host not found in upstream "xxx"。
  local backend_hosts backend_host backend_networks backend_network
  backend_hosts=$(grep -RhoP 'proxy_pass\s+https?://\K[A-Za-z0-9_.-]+' /home/web/conf.d/*.conf 2>/dev/null | sort -u)
  for backend_host in $backend_hosts; do
    if docker inspect "$backend_host" > /dev/null 2>&1; then
      backend_networks=$(docker inspect "$backend_host" --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' 2>/dev/null)
      for backend_network in $backend_networks; do
        docker network connect "$backend_network" $ldnmp_pods > /dev/null 2>&1 || true
      done
    fi
  done

  docker exec $ldnmp_pods chmod -R 777 /var/www/html || true
  docker exec $ldnmp_pods mkdir -p /var/cache/nginx/proxy || true
  docker exec $ldnmp_pods chmod 777 /var/cache/nginx/proxy || true

  local nginx_test_output
  if ! nginx_test_output=$(docker exec $ldnmp_pods nginx -t 2>&1); then
    echo "$nginx_test_output"
    echo "错误：nginx 配置检测失败，请检查 /home/web/nginx.conf 和 /home/web/conf.d/*.conf。"
    return 1
  fi

  echo "nginx 配置检测通过。"
  docker restart $ldnmp_pods > /dev/null 2>&1

}

phpmyadmin_upgrade() {
  local ldnmp_pods="phpmyadmin"
  local docker_port=8877
  local dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
  local dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')

  cd /home/web/
  docker rm -f $ldnmp_pods > /dev/null 2>&1
  docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
  curl -sS -O https://raw.githubusercontent.com/zaixiangjian/docker/refs/heads/main/docker-compose.phpmyadmin.yml
  docker compose -f docker-compose.phpmyadmin.yml up -d
  clear
  ip_address
  has_ipv4_has_ipv6
  check_docker_app_ip
  echo "登录信息: "
  echo "用户名: $dbuse"
  echo "密码: $dbusepasswd"
  echo
  send_stats "更新$ldnmp_pods"
  echo "更新${ldnmp_pods}完成"
}


cf_purge_cache() {
  local CONFIG_FILE="/home/web/config/cf-purge-cache.txt"
  local API_TOKEN
  local EMAIL
  local ZONE_IDS

  # 检查配置文件是否存在
  if [ -f "$CONFIG_FILE" ]; then
	# 从配置文件读取 API_TOKEN 和 zone_id
	read API_TOKEN EMAIL ZONE_IDS < "$CONFIG_FILE"
	# 将 ZONE_IDS 转换为数组
	ZONE_IDS=($ZONE_IDS)
  else
	# 提示用户是否清理缓存
	read -p "需要清理 Cloudflare 的缓存吗？（y/n）: " answer
	if [[ "$answer" == "y" ]]; then
	  echo "CF信息保存在$CONFIG_FILE，可以后期修改CF信息"
	  read -p "请输入你的 API_TOKEN: " API_TOKEN
	  read -p "请输入你的CF用户名: " EMAIL
	  read -p "请输入 zone_id（多个用空格分隔）: " -a ZONE_IDS

	  mkdir -p /home/web/config/
	  echo "$API_TOKEN $EMAIL ${ZONE_IDS[*]}" > "$CONFIG_FILE"
	fi
  fi

  # 循环遍历每个 zone_id 并执行清除缓存命令
  for ZONE_ID in "${ZONE_IDS[@]}"; do
	echo "正在清除缓存 for zone_id: $ZONE_ID"
	curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
	-H "X-Auth-Email: $EMAIL" \
	-H "X-Auth-Key: $API_TOKEN" \
	-H "Content-Type: application/json" \
	--data '{"purge_everything":true}'
  done

  echo "缓存清除请求已发送完毕。"
}



# 定义缓存预热函数
preheat_cache() {
	local url_file="/home/web/config/urls.txt"

	# 检查文件是否存在
	if [[ ! -f "$url_file" ]]; then
		return
	fi

	# 从文件读取 URL 列表
	urls=()
	while IFS= read -r url; do
		urls+=("$url")
	done < "$url_file"

	# 遍历每个 URL 并进行缓存预热
	for url in "${urls[@]}"; do
		echo "预热缓存: $url"
		curl -s -o /dev/null \
			-H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
			-H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
			"$url"
	done

	echo "缓存预热完成！"
}



web_cache() {
  send_stats "清理站点缓存"
  # docker exec -it nginx rm -rf /var/cache/nginx
  cf_purge_cache
  docker exec php php -r 'opcache_reset();'
  docker exec php74 php -r 'opcache_reset();'
  docker restart nginx php php74 redis
  docker exec redis redis-cli FLUSHALL
  docker exec -it redis redis-cli CONFIG SET maxmemory 512mb
  docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru
  preheat_cache
}




has_ipv4_has_ipv6() {

ip_address
if [ -z "$ipv4_address" ]; then
	has_ipv4=false
else
	has_ipv4=true
fi

if [ -z "$ipv6_address" ]; then
	has_ipv6=false
else
	has_ipv6=true
fi


}



check_docker_app() {

if docker inspect "$docker_name" &>/dev/null; then
	check_docker="${gl_lv}已安装${gl_bai}"
else
	check_docker="${hui}未安装${gl_bai}"
fi

}


check_docker_app_ip() {
echo "------------------------"
echo "访问地址:"
if $has_ipv4; then
	echo "http://$ipv4_address:$docker_port"
fi
if $has_ipv6; then
	echo "http://[$ipv6_address]:$docker_port"
fi

}



docker_app() {
send_stats "${docker_name}管理"
has_ipv4_has_ipv6
while true; do
	clear
	check_docker_app
	echo -e "$docker_name $check_docker"
	echo "$docker_describe"
	echo "$docker_url"
	if docker inspect "$docker_name" &>/dev/null; then
		check_docker_app_ip
	fi
	echo ""
	echo "------------------------"
	echo "1. 安装            2. 更新            3. 卸载"
	echo "------------------------"
	echo "0. 返回上一级"
	echo "------------------------"
	read -e -p "请输入你的选择: " choice
	 case $choice in
		1)
			install_docker || { break_end; continue; }
			eval "$docker_rum"
			clear
			echo "$docker_name 已经安装完成"
			check_docker_app_ip
			echo ""
			$docker_use
			$docker_passwd
			send_stats "安装$docker_name"
			;;
		2)
			install_docker || { break_end; continue; }
			docker rm -f "$docker_name"
			docker rmi -f "$docker_img"

			eval "$docker_rum"
			clear
			echo "$docker_name 已经安装完成"
			check_docker_app_ip
			echo ""
			$docker_use
			$docker_passwd
			send_stats "更新$docker_name"
			;;
		3)
			docker rm -f "$docker_name"
			docker rmi -f "$docker_img"
			rm -rf "/home/docker/$docker_name"
			echo "应用已卸载"
			send_stats "卸载$docker_name"
			;;
		0)
			break
			;;
		*)
			break
			;;
	 esac
	 break_end
done


}



cluster_python3() {
	cd ~/cluster/
	curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/python-for-vps/main/cluster/$py_task
	python3 ~/cluster/$py_task
}


tmux_run() {
	# Check if the session already exists
	tmux has-session -t $SESSION_NAME 2>/dev/null
	# $? is a special variable that holds the exit status of the last executed command
	if [ $? != 0 ]; then
	  # Session doesn't exist, create a new one
	  tmux new -s $SESSION_NAME
	else
	  # Session exists, attach to it
	  tmux attach-session -t $SESSION_NAME
	fi
}


tmux_run_d() {

base_name="tmuxd"
tmuxd_ID=1

# 检查会话是否存在的函数
session_exists() {
  tmux has-session -t $1 2>/dev/null
}

# 循环直到找到一个不存在的会话名称
while session_exists "$base_name-$tmuxd_ID"; do
  tmuxd_ID=$((tmuxd_ID + 1))
done

# 创建新的 tmux 会话
tmux new -d -s "$base_name-$tmuxd_ID" "$tmuxd"


}



f2b_status() {
	 docker restart fail2ban
	 sleep 3
	 docker exec -it fail2ban fail2ban-client status
}

f2b_status_xxx() {
	docker exec -it fail2ban fail2ban-client status $xxx
}

f2b_install_sshd() {

	docker run -d \
		--name=fail2ban \
		--net=host \
		--cap-add=NET_ADMIN \
		--cap-add=NET_RAW \
		-e PUID=1000 \
		-e PGID=1000 \
		-e TZ=Etc/UTC \
		-e VERBOSITY=-vv \
		-v /path/to/fail2ban/config:/config \
		-v /var/log:/var/log:ro \
		-v /home/web/log/nginx/:/remotelogs/nginx:ro \
		--restart unless-stopped \
		lscr.io/linuxserver/fail2ban:latest

	sleep 3
	if grep -q 'Alpine' /etc/issue; then
		cd /path/to/fail2ban/config/fail2ban/filter.d
		curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/config/main/fail2ban/alpine-sshd.conf
		curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/config/main/fail2ban/alpine-sshd-ddos.conf
		cd /path/to/fail2ban/config/fail2ban/jail.d/
		curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/config/main/fail2ban/alpine-ssh.conf
	elif command -v dnf &>/dev/null; then
		cd /path/to/fail2ban/config/fail2ban/jail.d/
		curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/config/main/fail2ban/centos-ssh.conf
	else
		install rsyslog
		systemctl start rsyslog
		systemctl enable rsyslog
		cd /path/to/fail2ban/config/fail2ban/jail.d/
		curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/config/main/fail2ban/linux-ssh.conf
	fi
}

f2b_sshd() {
	if grep -q 'Alpine' /etc/issue; then
		xxx=alpine-sshd
		f2b_status_xxx
	elif command -v dnf &>/dev/null; then
		xxx=centos-sshd
		f2b_status_xxx
	else
		xxx=linux-sshd
		f2b_status_xxx
	fi
}






server_reboot() {

	read -e -p "$(echo -e "${gl_huang}提示: ${gl_bai}现在重启服务器吗？(Y/N): ")" rboot
	case "$rboot" in
	  [Yy])
		echo "已重启"
		reboot
		;;
	  *)
		echo "已取消"
		;;
	esac


}

output_status() {
	output=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
		NR > 2 { rx_total += $2; tx_total += $10 }
		END {
			rx_units = "Bytes";
			tx_units = "Bytes";
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "KB"; }
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "MB"; }
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "GB"; }

			if (tx_total > 1024) { tx_total /= 1024; tx_units = "KB"; }
			if (tx_total > 1024) { tx_total /= 1024; tx_units = "MB"; }
			if (tx_total > 1024) { tx_total /= 1024; tx_units = "GB"; }

			printf("总接收: %.2f %s\n总发送: %.2f %s\n", rx_total, rx_units, tx_total, tx_units);
		}' /proc/net/dev)

}


ldnmp_install_status_one() {

   if docker inspect "php" &>/dev/null; then
	send_stats "无法再次安装LDNMP环境"
	echo -e "${gl_huang}提示: ${gl_bai}完整LDNMP环境已安装。无需再次安装环境。"
	break_end
	linux_ldnmp
   else
	:
   fi

}





ldnmp_install_status() {

   if docker inspect "php" &>/dev/null; then
	echo "LDNMP环境已安装，开始部署 $webname"
   else
	send_stats "请先安装LDNMP环境"
	echo -e "${gl_huang}提示: ${gl_bai}LDNMP环境未安装，请先安装LDNMP环境，再部署网站"
	break_end
	linux_ldnmp

   fi

}


nginx_install_status() {

   if docker inspect "nginx" &>/dev/null; then
	echo "nginx环境已安装，开始部署 $webname"
   else
	send_stats "请先安装nginx环境"
	echo -e "${gl_huang}提示: ${gl_bai}nginx未安装，请先安装nginx环境，再部署网站"
	break_end
	linux_ldnmp

   fi

}


ldnmp_web_on() {
	  clear
	  echo "您的 $webname 搭建好了！"
	  echo "https://$yuming"
	  echo "------------------------"
	  echo "$webname 安装信息如下: "

}

nginx_web_on() {
	  clear
	  echo "您的 $webname 搭建好了！"
	  echo "https://$yuming"

}












check_panel_app() {

if $lujing ; then
	check_panel="${gl_lv}已安装${gl_bai}"
else
	check_panel="${hui}未安装${gl_bai}"
fi

}



install_panel() {
send_stats "${panelname}管理"
while true; do
	clear
	check_panel_app
	echo -e "$panelname $check_panel"
	echo "${panelname}是一款时下流行且强大的运维管理面板。"
	echo "官网介绍: $panelurl "

	echo ""
	echo "------------------------"
	echo "1. 安装            2. 管理            3. 卸载"
	echo "------------------------"
	echo "0. 返回上一级"
	echo "------------------------"
	read -e -p "请输入你的选择: " choice
	 case $choice in
		1)
			iptables_open
			install wget
			if grep -q 'Alpine' /etc/issue; then
				$ubuntu_mingling
				$ubuntu_mingling2
			elif command -v dnf &>/dev/null; then
				$centos_mingling
				$centos_mingling2
			elif grep -qi 'Ubuntu' /etc/os-release; then
				$ubuntu_mingling
				$ubuntu_mingling2
			elif grep -qi 'Debian' /etc/os-release; then
				$ubuntu_mingling
				$ubuntu_mingling2
			else
				echo "不支持的系统"
			fi
			send_stats "${panelname}安装"
			;;
		2)
			$gongneng1
			$gongneng1_1
			send_stats "${panelname}控制"
			;;
		3)
			$gongneng2
			$gongneng2_1
			$gongneng2_2
			send_stats "${panelname}卸载"
			;;
		0)
			break
			;;
		*)
			break
			;;
	 esac
	 break_end
done

}





current_timezone() {
	if grep -q 'Alpine' /etc/issue; then
	   date +"%Z %z"
	else
	   timedatectl | grep "Time zone" | awk '{print $3}'
	fi

}


set_timedate() {
  local shiqu="${1:-}"
  # 限定为 zoneinfo 相对名称，拒绝空值、选项、路径穿越和多余参数。
  if (( $# != 1 )) || [[ ! "$shiqu" =~ ^[A-Za-z0-9_][A-Za-z0-9_+-]*(/[A-Za-z0-9_][A-Za-z0-9_+-]*)*$ ]]; then
    echo "时区参数无效，例如：Asia/Shanghai 或 UTC。" >&2
    return 1
  fi
  if (( EUID != 0 )); then
    echo "请以 root 身份设置时区。" >&2
    return 1
  fi

  if [[ -f /etc/alpine-release ]]; then
    if ! command -v apk >/dev/null 2>&1; then
      echo "未找到 Alpine 包管理器 apk。" >&2
      return 1
    fi
    apk add --no-cache tzdata || return 1
    if [[ ! -f "/usr/share/zoneinfo/$shiqu" ]] ||
       [[ "$(LC_ALL=C head -c 4 "/usr/share/zoneinfo/$shiqu" 2>/dev/null)" != TZif ]]; then
      echo "不存在有效的时区数据：$shiqu" >&2
      return 1
    fi
    # 先移除 localtime 链接，避免 cp 沿旧链接覆盖其他时区数据。
    ln -sfn "/usr/share/zoneinfo/$shiqu" /etc/localtime || return 1
    printf '%s\n' "$shiqu" > /etc/timezone || return 1
    # 设置时区无需写硬件时钟，容器通常也没有 RTC。
  else
    if ! command -v timedatectl >/dev/null 2>&1; then
      echo "未找到 timedatectl，无法设置系统时区。" >&2
      return 1
    fi
    # 由 timedatectl 验证时区是否存在，并保留失败状态。
    timedatectl set-timezone "$shiqu" || return 1
  fi
  return 0
}


wait_for_lock() {
  local timeout="${1:-300}" start=$SECONDS
  local locks=(/var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
               /var/lib/apt/lists/lock /var/cache/apt/archives/lock)
  [[ "$timeout" =~ ^[0-9]+$ ]] || return 1
  if ! command -v fuser >/dev/null 2>&1; then
    echo "提示：未安装 fuser，由包管理器自行检查锁。" >&2
    return 0
  fi
  while fuser "${locks[@]}" >/dev/null 2>&1; do
    if (( SECONDS - start >= timeout )); then
      echo "等待软件包管理器锁超时，停止操作。" >&2
      return 1
    fi
    echo "等待软件包管理器释放锁..."
    sleep 2
  done
}

fix_dpkg() {
  DEBIAN_FRONTEND=noninteractive dpkg --configure -a
}

_linux_require_root() {
  if (( EUID != 0 )); then
    echo "请以 root 身份运行。" >&2
    return 1
  fi
}

linux_update() {
  _linux_require_root || return 1
  echo -e "${gl_huang}正在系统更新...${gl_bai}"
  if command -v dnf >/dev/null 2>&1; then
    dnf -y update || return 1
  elif command -v yum >/dev/null 2>&1; then
    yum -y update || return 1
  elif command -v apt-get >/dev/null 2>&1; then
    wait_for_lock 300 || return 1
    fix_dpkg || return 1
    DEBIAN_FRONTEND=noninteractive apt-get \
      -o DPkg::Lock::Timeout=300 -o APT::Update::Error-Mode=any update || return 1
    # 常规升级，不自动移除已安装软件包。
    DEBIAN_FRONTEND=noninteractive apt-get \
      -o DPkg::Lock::Timeout=300 -y upgrade || return 1
  elif command -v apk >/dev/null 2>&1; then
    apk update || return 1
    apk upgrade || return 1
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Syu --noconfirm || return 1
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive refresh || return 1
    zypper --non-interactive update || return 1
  elif command -v opkg >/dev/null 2>&1; then
    opkg update || return 1
    echo "软件包列表已刷新；未执行 OpenWrt 全量软件包升级。"
    return 0
  else
    echo "未知的包管理器！" >&2
    return 1
  fi
  echo "系统更新命令执行完成（可能仍有保留的软件包或需要重启）。"
  return 0
}

linux_clean() {
  _linux_require_root || return 1
  echo -e "${gl_huang}正在清理软件包缓存...${gl_bai}"
  # 只清包缓存，不卸载软件，不清日志和临时目录。
  if command -v dnf >/dev/null 2>&1; then
    dnf clean packages || return 1
  elif command -v yum >/dev/null 2>&1; then
    yum clean packages || return 1
  elif command -v apt-get >/dev/null 2>&1; then
    wait_for_lock 300 || return 1
    apt-get -o DPkg::Lock::Timeout=300 clean || return 1
  elif command -v apk >/dev/null 2>&1; then
    apk cache clean || return 1
  elif command -v pacman >/dev/null 2>&1; then
    if command -v paccache >/dev/null 2>&1; then
      paccache -rk2 || return 1
    else
      echo "未安装 paccache，跳过包缓存清理，保留回退所需的软件包。"
    fi
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive clean || return 1
  elif command -v opkg >/dev/null 2>&1; then
    echo "跳过 OpenWrt 缓存清理，不删除 /tmp 中的运行状态。"
  else
    echo "未知的包管理器！" >&2
    return 1
  fi
  echo "清理完成：未卸载软件，未清理系统日志或临时目录。"
  return 0
}



bbr_on() {

cat > /etc/sysctl.conf << EOF
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p

}


set_dns() {

rm /etc/resolv.conf

# 检查机器是否有IPv6地址
ipv6_available=0
if [[ $(ip -6 addr | grep -c "inet6") -gt 0 ]]; then
	ipv6_available=1
fi

echo "nameserver $dns1_ipv4" > /etc/resolv.conf
echo "nameserver $dns2_ipv4" >> /etc/resolv.conf


if [[ $ipv6_available -eq 1 ]]; then
	echo "nameserver $dns1_ipv6" >> /etc/resolv.conf
	echo "nameserver $dns2_ipv6" >> /etc/resolv.conf
fi

echo "DNS地址已更新"
echo "------------------------"
cat /etc/resolv.conf
echo "------------------------"

}


restart_ssh() {
	restart sshd ssh > /dev/null 2>&1

}


new_ssh_port() {


  # 备份 SSH 配置文件
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

  sed -i 's/^\s*#\?\s*Port/Port/' /etc/ssh/sshd_config

  # 替换 SSH 配置文件中的端口号
  sed -i "s/Port [0-9]\+/Port $new_port/g" /etc/ssh/sshd_config

  rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*

  # 重启 SSH 服务
  restart_ssh

  iptables_open
  remove iptables-persistent ufw firewalld iptables-services > /dev/null 2>&1

  echo "SSH 端口已修改为: $new_port"

  sleep 1

}



add_sshkey() {

# ssh-keygen -t rsa -b 4096 -C "xxxx@gmail.com" -f /root/.ssh/sshkey -N ""
ssh-keygen -t ed25519 -C "xxxx@gmail.com" -f /root/.ssh/sshkey -N ""

cat ~/.ssh/sshkey.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys


ip_address
echo -e "私钥信息已生成，务必复制保存，可保存成 ${gl_huang}${ipv4_address}_ssh.key${gl_bai} 文件，用于以后的SSH登录"

echo "--------------------------------"
cat ~/.ssh/sshkey
echo "--------------------------------"

sed -i -e 's/^\s*#\?\s*PermitRootLogin .*/PermitRootLogin prohibit-password/' \
	   -e 's/^\s*#\?\s*PasswordAuthentication .*/PasswordAuthentication no/' \
	   -e 's/^\s*#\?\s*PubkeyAuthentication .*/PubkeyAuthentication yes/' \
	   -e 's/^\s*#\?\s*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
echo -e "${gl_lv}ROOT私钥登录已开启，已关闭ROOT密码登录，重连将会生效${gl_bai}"

}


add_sshpasswd() {

echo "设置你的ROOT密码"
passwd
sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
restart_ssh
echo -e "${gl_lv}ROOT登录设置完毕！${gl_bai}"

}


root_use() {
clear
[ "$EUID" -ne 0 ] && echo -e "${gl_huang}提示: ${gl_bai}该功能需要root用户才能运行！" && break_end && kejilion
}



dd_xitong() {
		send_stats "重装系统"
		dd_xitong_MollyLau() {
			wget --no-check-certificate -qO InstallNET.sh "${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/Tools/master/Linux_reinstall/InstallNET.sh" && chmod a+x InstallNET.sh

		}

		dd_xitong_bin456789() {
			curl -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/reinstall/main/reinstall.sh
		}

		dd_xitong_1() {
		  echo -e "重装后初始用户名: ${gl_huang}root${gl_bai}  初始密码: ${gl_huang}LeitboGi0ro${gl_bai}  初始端口: ${gl_huang}22${gl_bai}"
		  echo -e "按任意键继续..."
		  read -n 1 -s -r -p ""
		  install wget
		  dd_xitong_MollyLau
		}

		dd_xitong_2() {
		  echo -e "重装后初始用户名: ${gl_huang}Administrator${gl_bai}  初始密码: ${gl_huang}Teddysun.com${gl_bai}  初始端口: ${gl_huang}3389${gl_bai}"
		  echo -e "按任意键继续..."
		  read -n 1 -s -r -p ""
		  install wget
		  dd_xitong_MollyLau
		}

		dd_xitong_3() {
		  echo -e "重装后初始用户名: ${gl_huang}root${gl_bai}  初始密码: ${gl_huang}123@@@${gl_bai}  初始端口: ${gl_huang}22${gl_bai}"
		  echo -e "按任意键继续..."
		  read -n 1 -s -r -p ""
		  dd_xitong_bin456789
		}

		dd_xitong_4() {
		  echo -e "重装后初始用户名: ${gl_huang}Administrator${gl_bai}  初始密码: ${gl_huang}123@@@${gl_bai}  初始端口: ${gl_huang}3389${gl_bai}"
		  echo -e "按任意键继续..."
		  read -n 1 -s -r -p ""
		  dd_xitong_bin456789
		}

		  while true; do
			root_use
			echo "重装系统"
			echo "--------------------------------"
			echo -e "${gl_hong}注意: ${gl_bai}重装有风险失联，不放心者慎用。重装预计花费15分钟，请提前备份数据。"
			echo -e "${hui}感谢MollyLau大佬和bin456789大佬的脚本支持！${gl_bai} "
			echo "------------------------"
			echo "原地址1"
			echo "			wget --no-check-certificate -qO InstallNET.sh "${gh_proxy}https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh" && chmod a+x InstallNET.sh"
			echo "原地址2"
			echo "			curl -O ${gh_proxy}https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"
   			echo "------------------------"
   			echo "133. Debian 13"
			echo "1. Debian 12                  2. Debian 11"
			echo "3. Debian 10                  4. Debian 9"
			echo "------------------------"
			echo "11. Ubuntu 24.04              12. Ubuntu 22.04"
			echo "13. Ubuntu 20.04              14. Ubuntu 18.04"
			echo "------------------------"
			echo "21. Rocky Linux 9             22. Rocky Linux 8"
			echo "23. Alma Linux 9              24. Alma Linux 8"
			echo "25. oracle Linux 9            26. oracle Linux 8"
			echo "27. Fedora Linux 41           28. Fedora Linux 40"
			echo "29. CentOS 7"
			echo "------------------------"
			echo "31. Alpine Linux              32. Arch Linux"
			echo "33. Kali Linux                34. openEuler"
			echo "35. openSUSE Tumbleweed"
			echo "------------------------"
			echo "41. Windows 11                42. Windows 10"
			echo "43. Windows 7                 44. Windows Server 2022"
			echo "45. Windows Server 2019       46. Windows Server 2016"
			echo "------------------------"
			echo "0. 返回上一级选单"
			echo "------------------------"
			read -e -p "请选择要重装的系统: " sys_choice
			case "$sys_choice" in
   			  133)
				send_stats "重装debian 13"
				dd_xitong_1
				bash InstallNET.sh -debian 13
				reboot
				exit
				;;
			  1)
				send_stats "重装debian 12"
				dd_xitong_1
				bash InstallNET.sh -debian 12
				reboot
				exit
				;;
			  2)
				send_stats "重装debian 11"
				dd_xitong_1
				bash InstallNET.sh -debian 11
				reboot
				exit
				;;
			  3)
				send_stats "重装debian 10"
				dd_xitong_1
				bash InstallNET.sh -debian 10
				reboot
				exit
				;;
			  4)
				send_stats "重装debian 9"
				dd_xitong_1
				bash InstallNET.sh -debian 9
				reboot
				exit
				;;
			  11)
				send_stats "重装ubuntu 24.04"
				dd_xitong_1
				bash InstallNET.sh -ubuntu 24.04
				reboot
				exit
				;;
			  12)
				send_stats "重装ubuntu 22.04"
				dd_xitong_1
				bash InstallNET.sh -ubuntu 22.04
				reboot
				exit
				;;
			  13)
				send_stats "重装ubuntu 20.04"
				dd_xitong_1
				bash InstallNET.sh -ubuntu 20.04
				reboot
				exit
				;;
			  14)
				send_stats "重装ubuntu 18.04"
				dd_xitong_1
				bash InstallNET.sh -ubuntu 18.04
				reboot
				exit
				;;


			  21)
				send_stats "重装rockylinux9"
				dd_xitong_3
				bash reinstall.sh rocky
				reboot
				exit
				;;

			  22)
				send_stats "重装rockylinux8"
				dd_xitong_3
				bash reinstall.sh rocky 8
				reboot
				exit
				;;

			  23)
				send_stats "重装alma9"
				dd_xitong_3
				bash reinstall.sh alma
				reboot
				exit
				;;

			  24)
				send_stats "重装alma8"
				dd_xitong_3
				bash reinstall.sh alma 8
				reboot
				exit
				;;

			  25)
				send_stats "重装oracle9"
				dd_xitong_3
				bash reinstall.sh oracle
				reboot
				exit
				;;

			  26)
				send_stats "重装oracle8"
				dd_xitong_3
				bash reinstall.sh oracle 8
				reboot
				exit
				;;

			  27)
				send_stats "重装fedora40"
				dd_xitong_3
				bash reinstall.sh fedora
				reboot
				exit
				;;

			  28)
				send_stats "重装fedora39"
				dd_xitong_3
				bash reinstall.sh fedora 40
				reboot
				exit
				;;

			  29)
				send_stats "重装centos 7"
				dd_xitong_1
				bash InstallNET.sh -centos 7
				reboot
				exit
				;;

			  31)
				send_stats "重装alpine"
				dd_xitong_1
				bash InstallNET.sh -alpine
				reboot
				exit
				;;

			  32)
				send_stats "重装arch"
				dd_xitong_3
				bash reinstall.sh arch
				reboot
				exit
				;;

			  33)
				send_stats "重装kali"
				dd_xitong_3
				bash reinstall.sh kali
				reboot
				exit
				;;

			  34)
				send_stats "重装openeuler"
				dd_xitong_3
				bash reinstall.sh openeuler
				reboot
				exit
				;;

			  35)
				send_stats "重装opensuse"
				dd_xitong_3
				bash reinstall.sh opensuse
				reboot
				exit
				;;

			  41)
				send_stats "重装windows11"
				dd_xitong_2
				bash InstallNET.sh -windows 11 -lang "cn"
				reboot
				exit
				;;
			  42)
				dd_xitong_2
				send_stats "重装windows10"
				bash InstallNET.sh -windows 10 -lang "cn"
				reboot
				exit
				;;
			  43)
				send_stats "重装windows7"
				dd_xitong_4
				URL="https://massgrave.dev/windows_7_links"
				web_content=$(wget -q -O - "$URL")
				iso_link=$(echo "$web_content" | grep -oP '(?<=href=")[^"]*cn[^"]*windows_7[^"]*professional[^"]*x64[^"]*\.iso')
				# bash reinstall.sh windows --image-name 'Windows 7 Professional' --lang zh-cn
				# bash reinstall.sh windows --iso='$iso_link' --image-name='Windows 7 PROFESSIONAL'
				bash reinstall.sh windows --iso="$iso_link" --image-name='Windows 7 PROFESSIONAL'
				reboot
				exit
				;;
			  44)
				send_stats "重装windows server 22"
				dd_xitong_4
				URL="https://massgrave.dev/windows_server_links"
				web_content=$(wget -q -O - "$URL")
				iso_link=$(echo "$web_content" | grep -oP '(?<=href=")[^"]*cn[^"]*windows_server[^"]*2022[^"]*x64[^"]*\.iso')
				bash reinstall.sh windows --iso="$iso_link" --image-name='Windows Server 2022 SERVERDATACENTER'
				reboot
				exit
				;;
			  45)
				send_stats "重装windows server 19"
				dd_xitong_2
				bash InstallNET.sh -windows 2019 -lang "cn"
				reboot
				exit
				;;
			  46)
				send_stats "重装windows server 16"
				dd_xitong_2
				bash InstallNET.sh -windows 2016 -lang "cn"
				reboot
				exit
				;;
			  0)
				break
				;;
			  *)
				echo "无效的选择，请重新输入。"
				break
				;;
			esac
		  done
}


bbrv3() {
		  root_use
		  send_stats "bbrv3管理"

		  cpu_arch=$(uname -m)
		  if [ "$cpu_arch" = "aarch64" ]; then
			bash <(curl -sL jhb.ovh/jb/bbrv3arm.sh)
			break_end
			linux_Settings
		  fi

		  if dpkg -l | grep -q 'linux-xanmod'; then
			while true; do
				  clear
				  kernel_version=$(uname -r)
				  echo "您已安装xanmod的BBRv3内核"
				  echo "当前内核版本: $kernel_version"

				  echo ""
				  echo "内核管理"
				  echo "------------------------"
				  echo "1. 更新BBRv3内核              2. 卸载BBRv3内核"
				  echo "------------------------"
				  echo "0. 返回上一级选单"
				  echo "------------------------"
				  read -e -p "请输入你的选择: " sub_choice

				  case $sub_choice in
					  1)
						apt purge -y 'linux-*xanmod1*'
						update-grub

						# wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
						wget -qO - ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes

						# 步骤3：添加存储库
						echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

						# version=$(wget -q https://dl.xanmod.org/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')
						version=$(wget -q ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')

						apt update -y
						apt install -y linux-xanmod-x64v$version

						echo "XanMod内核已更新。重启后生效"
						rm -f /etc/apt/sources.list.d/xanmod-release.list
						rm -f check_x86-64_psabi.sh*

						server_reboot

						  ;;
					  2)
						apt purge -y 'linux-*xanmod1*'
						update-grub
						echo "XanMod内核已卸载。重启后生效"
						server_reboot
						  ;;
					  0)
						  break  # 跳出循环，退出菜单
						  ;;

					  *)
						  break  # 跳出循环，退出菜单
						  ;;

				  esac
			done
		else

		  clear
		  echo "设置BBR3加速"
		  echo "视频介绍: https://www.bilibili.com/video/BV14K421x7BS?t=0.1"
		  echo "------------------------------------------------"
		  echo "仅支持Debian/Ubuntu"
		  echo "请备份数据，将为你升级Linux内核开启BBR3"
		  echo "VPS是512M内存的，请提前添加1G虚拟内存，防止因内存不足失联！"
		  echo "------------------------------------------------"
		  read -e -p "确定继续吗？(Y/N): " choice

		  case "$choice" in
			[Yy])
			if [ -r /etc/os-release ]; then
				. /etc/os-release
				if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
					echo "当前环境不支持，仅支持Debian和Ubuntu系统"
					break_end
					linux_Settings
				fi
			else
				echo "无法确定操作系统类型"
				break_end
				linux_Settings
			fi

			check_swap
			install wget gnupg

			# wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
			wget -qO - ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes

			# 步骤3：添加存储库
			echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

			# version=$(wget -q https://dl.xanmod.org/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')
			version=$(wget -q ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')

			apt update -y
			apt install -y linux-xanmod-x64v$version

			bbr_on

			echo "XanMod内核安装并BBR3启用成功。重启后生效"
			rm -f /etc/apt/sources.list.d/xanmod-release.list
			rm -f check_x86-64_psabi.sh*
			server_reboot

			  ;;
			[Nn])
			  echo "已取消"
			  ;;
			*)
			  echo "无效的选择，请输入 Y 或 N。"
			  ;;
		  esac
		fi

}


elrepo_install() {
	# 导入 ELRepo GPG 公钥
	echo "导入 ELRepo GPG 公钥..."
	rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
	# 检测系统版本
	os_version=$(rpm -q --qf "%{VERSION}" $(rpm -qf /etc/os-release) 2>/dev/null | awk -F '.' '{print $1}')
	os_name=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
	# 确保我们在一个支持的操作系统上运行
	if [[ "$os_name" != *"Red Hat"* && "$os_name" != *"AlmaLinux"* && "$os_name" != *"Rocky"* && "$os_name" != *"Oracle"* && "$os_name" != *"CentOS"* ]]; then
		echo "不支持的操作系统：$os_name"
		break_end
		linux_Settings
	fi
	# 打印检测到的操作系统信息
	echo "检测到的操作系统: $os_name $os_version"
	# 根据系统版本安装对应的 ELRepo 仓库配置
	if [[ "$os_version" == 8 ]]; then
		echo "安装 ELRepo 仓库配置 (版本 8)..."
		yum -y install https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm
	elif [[ "$os_version" == 9 ]]; then
		echo "安装 ELRepo 仓库配置 (版本 9)..."
		yum -y install https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm
	else
		echo "不支持的系统版本：$os_version"
		break_end
		linux_Settings
	fi
	# 启用 ELRepo 内核仓库并安装最新的主线内核
	echo "启用 ELRepo 内核仓库并安装最新的主线内核..."
	yum -y --enablerepo=elrepo-kernel install kernel-ml
	echo "已安装 ELRepo 仓库配置并更新到最新主线内核。"
	server_reboot

}


elrepo() {
		  root_use
		  send_stats "红帽内核管理"
		  if uname -r | grep -q 'elrepo'; then
			while true; do
				  clear
				  kernel_version=$(uname -r)
				  echo "您已安装elrepo内核"
				  echo "当前内核版本: $kernel_version"

				  echo ""
				  echo "内核管理"
				  echo "------------------------"
				  echo "1. 更新elrepo内核              2. 卸载elrepo内核"
				  echo "------------------------"
				  echo "0. 返回上一级选单"
				  echo "------------------------"
				  read -e -p "请输入你的选择: " sub_choice

				  case $sub_choice in
					  1)
						dnf remove -y elrepo-release
						rpm -qa | grep elrepo | grep kernel | xargs rpm -e --nodeps
						elrepo_install
						send_stats "更新红帽内核"
						server_reboot

						  ;;
					  2)
						dnf remove -y elrepo-release
						rpm -qa | grep elrepo | grep kernel | xargs rpm -e --nodeps
						echo "elrepo内核已卸载。重启后生效"
						send_stats "卸载红帽内核"
						server_reboot

						  ;;
					  0)
						  break  # 跳出循环，退出菜单
						  ;;

					  *)
						  break  # 跳出循环，退出菜单
						  ;;

				  esac
			done
		else

		  clear
		  echo "请备份数据，将为你升级Linux内核"
		  echo "视频介绍: https://www.bilibili.com/video/BV1mH4y1w7qA?t=529.2"
		  echo "------------------------------------------------"
		  echo "仅支持红帽系列发行版 CentOS/RedHat/Alma/Rocky/oracle "
		  echo "升级Linux内核可提升系统性能和安全，建议有条件的尝试，生产环境谨慎升级！"
		  echo "------------------------------------------------"
		  read -e -p "确定继续吗？(Y/N): " choice

		  case "$choice" in
			[Yy])
			  check_swap
			  elrepo_install
			  send_stats "升级红帽内核"
			  server_reboot
			  ;;
			[Nn])
			  echo "已取消"
			  ;;
			*)
			  echo "无效的选择，请输入 Y 或 N。"
			  ;;
		  esac
		fi

}




clamav_freshclam() {
	echo -e "${gl_huang}正在更新病毒库...${gl_bai}"
	docker run --rm \
		--name clamav \
		--mount source=clam_db,target=/var/lib/clamav \
		clamav/clamav-debian:latest \
		freshclam
}

clamav_scan() {
	if [ $# -eq 0 ]; then
		echo "请指定要扫描的目录。"
		return
	fi

	echo -e "${gl_huang}正在扫描目录$@... ${gl_bai}"

	# 构建 mount 参数
	MOUNT_PARAMS=""
	for dir in "$@"; do
		MOUNT_PARAMS+="--mount type=bind,source=${dir},target=/mnt/host${dir} "
	done

	# 构建 clamscan 命令参数
	SCAN_PARAMS=""
	for dir in "$@"; do
		SCAN_PARAMS+="/mnt/host${dir} "
	done

	mkdir -p /home/docker/clamav/log/ > /dev/null 2>&1
	> /home/docker/clamav/log/scan.log > /dev/null 2>&1

	# 执行 Docker 命令
	docker run -it --rm \
		--name clamav \
		--mount source=clam_db,target=/var/lib/clamav \
		$MOUNT_PARAMS \
		-v /home/docker/clamav/log/:/var/log/clamav/ \
		clamav/clamav-debian:latest \
		clamscan -r --log=/var/log/clamav/scan.log $SCAN_PARAMS

	echo -e "${gl_lv}$@ 扫描完成，病毒报告存放在${gl_huang}/home/docker/clamav/log/scan.log${gl_bai}"
	echo -e "${gl_lv}如果有病毒请在${gl_huang}scan.log${gl_lv}文件中搜索FOUND关键字确认病毒位置 ${gl_bai}"

}







clamav() {
		  root_use
		  send_stats "病毒扫描管理"
		  while true; do
				clear
				echo "clamav病毒扫描工具"
				echo "视频介绍: https://www.bilibili.com/video/BV1TqvZe4EQm?t=0.1"
				echo "------------------------"
				echo "是一个开源的防病毒软件工具，主要用于检测和删除各种类型的恶意软件。"
				echo "包括病毒、特洛伊木马、间谍软件、恶意脚本和其他有害软件。"
				echo "------------------------"
				echo -e "${gl_lv}1. 全盘扫描 ${gl_bai}             ${gl_huang}2. 重要目录扫描 ${gl_bai}            ${gl_kjlan} 3. 自定义目录扫描 ${gl_bai}"
				echo "------------------------"
				echo "0. 返回上一级选单"
				echo "------------------------"
				read -e -p "请输入你的选择: " sub_choice
				case $sub_choice in
					1)
					  send_stats "全盘扫描"
					  install_docker
					  docker volume create clam_db > /dev/null 2>&1
					  clamav_freshclam
					  clamav_scan /
					  break_end

						;;
					2)
					  send_stats "重要目录扫描"
					  install_docker
					  docker volume create clam_db > /dev/null 2>&1
					  clamav_freshclam
					  clamav_scan /etc /var /usr /home /root
					  break_end
						;;
					3)
					  send_stats "自定义目录扫描"
					  read -e -p "请输入要扫描的目录，用空格分隔（例如：/etc /var /usr /home /root）: " directories
					  install_docker
					  clamav_freshclam
					  clamav_scan $directories
					  break_end
						;;
					*)
					  break  # 跳出循环，退出菜单
						;;
				esac
		  done

}




# 高性能模式优化函数
optimize_high_performance() {
	echo -e "${gl_lv}切换到${tiaoyou_moshi}...${gl_bai}"

	echo -e "${gl_lv}优化文件描述符...${gl_bai}"
	ulimit -n 65535

	echo -e "${gl_lv}优化虚拟内存...${gl_bai}"
	sysctl -w vm.swappiness=10 2>/dev/null
	sysctl -w vm.dirty_ratio=15 2>/dev/null
	sysctl -w vm.dirty_background_ratio=5 2>/dev/null
	sysctl -w vm.overcommit_memory=1 2>/dev/null
	sysctl -w vm.min_free_kbytes=65536 2>/dev/null

	echo -e "${gl_lv}优化网络设置...${gl_bai}"
	sysctl -w net.core.rmem_max=16777216 2>/dev/null
	sysctl -w net.core.wmem_max=16777216 2>/dev/null
	sysctl -w net.core.netdev_max_backlog=250000 2>/dev/null
	sysctl -w net.core.somaxconn=4096 2>/dev/null
	sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216' 2>/dev/null
	sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216' 2>/dev/null
	sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null
	sysctl -w net.ipv4.tcp_max_syn_backlog=8192 2>/dev/null
	sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null
	sysctl -w net.ipv4.ip_local_port_range='1024 65535' 2>/dev/null

	echo -e "${gl_lv}优化缓存管理...${gl_bai}"
	sysctl -w vm.vfs_cache_pressure=50 2>/dev/null

	echo -e "${gl_lv}优化CPU设置...${gl_bai}"
	sysctl -w kernel.sched_autogroup_enabled=0 2>/dev/null

	echo -e "${gl_lv}其他优化...${gl_bai}"
	# 禁用透明大页面，减少延迟
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
	# 禁用 NUMA balancing
	sysctl -w kernel.numa_balancing=0 2>/dev/null


}

# 均衡模式优化函数
optimize_balanced() {
	echo -e "${gl_lv}切换到均衡模式...${gl_bai}"

	echo -e "${gl_lv}优化文件描述符...${gl_bai}"
	ulimit -n 32768

	echo -e "${gl_lv}优化虚拟内存...${gl_bai}"
	sysctl -w vm.swappiness=30 2>/dev/null
	sysctl -w vm.dirty_ratio=20 2>/dev/null
	sysctl -w vm.dirty_background_ratio=10 2>/dev/null
	sysctl -w vm.overcommit_memory=0 2>/dev/null
	sysctl -w vm.min_free_kbytes=32768 2>/dev/null

	echo -e "${gl_lv}优化网络设置...${gl_bai}"
	sysctl -w net.core.rmem_max=8388608 2>/dev/null
	sysctl -w net.core.wmem_max=8388608 2>/dev/null
	sysctl -w net.core.netdev_max_backlog=125000 2>/dev/null
	sysctl -w net.core.somaxconn=2048 2>/dev/null
	sysctl -w net.ipv4.tcp_rmem='4096 87380 8388608' 2>/dev/null
	sysctl -w net.ipv4.tcp_wmem='4096 32768 8388608' 2>/dev/null
	sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null
	sysctl -w net.ipv4.tcp_max_syn_backlog=4096 2>/dev/null
	sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null
	sysctl -w net.ipv4.ip_local_port_range='1024 49151' 2>/dev/null

	echo -e "${gl_lv}优化缓存管理...${gl_bai}"
	sysctl -w vm.vfs_cache_pressure=75 2>/dev/null

	echo -e "${gl_lv}优化CPU设置...${gl_bai}"
	sysctl -w kernel.sched_autogroup_enabled=1 2>/dev/null

	echo -e "${gl_lv}其他优化...${gl_bai}"
	# 还原透明大页面
	echo always > /sys/kernel/mm/transparent_hugepage/enabled
	# 还原 NUMA balancing
	sysctl -w kernel.numa_balancing=1 2>/dev/null


}

# 还原默认设置函数
restore_defaults() {
	echo -e "${gl_lv}还原到默认设置...${gl_bai}"

	echo -e "${gl_lv}还原文件描述符...${gl_bai}"
	ulimit -n 1024

	echo -e "${gl_lv}还原虚拟内存...${gl_bai}"
	sysctl -w vm.swappiness=60 2>/dev/null
	sysctl -w vm.dirty_ratio=20 2>/dev/null
	sysctl -w vm.dirty_background_ratio=10 2>/dev/null
	sysctl -w vm.overcommit_memory=0 2>/dev/null
	sysctl -w vm.min_free_kbytes=16384 2>/dev/null

	echo -e "${gl_lv}还原网络设置...${gl_bai}"
	sysctl -w net.core.rmem_max=212992 2>/dev/null
	sysctl -w net.core.wmem_max=212992 2>/dev/null
	sysctl -w net.core.netdev_max_backlog=1000 2>/dev/null
	sysctl -w net.core.somaxconn=128 2>/dev/null
	sysctl -w net.ipv4.tcp_rmem='4096 87380 6291456' 2>/dev/null
	sysctl -w net.ipv4.tcp_wmem='4096 16384 4194304' 2>/dev/null
	sysctl -w net.ipv4.tcp_congestion_control=cubic 2>/dev/null
	sysctl -w net.ipv4.tcp_max_syn_backlog=2048 2>/dev/null
	sysctl -w net.ipv4.tcp_tw_reuse=0 2>/dev/null
	sysctl -w net.ipv4.ip_local_port_range='32768 60999' 2>/dev/null

	echo -e "${gl_lv}还原缓存管理...${gl_bai}"
	sysctl -w vm.vfs_cache_pressure=100 2>/dev/null

	echo -e "${gl_lv}还原CPU设置...${gl_bai}"
	sysctl -w kernel.sched_autogroup_enabled=1 2>/dev/null

	echo -e "${gl_lv}还原其他优化...${gl_bai}"
	# 还原透明大页面
	echo always > /sys/kernel/mm/transparent_hugepage/enabled
	# 还原 NUMA balancing
	sysctl -w kernel.numa_balancing=1 2>/dev/null

}



# 网站搭建优化函数
optimize_web_server() {
	echo -e "${gl_lv}切换到网站搭建优化模式...${gl_bai}"

	echo -e "${gl_lv}优化文件描述符...${gl_bai}"
	ulimit -n 65536

	echo -e "${gl_lv}优化虚拟内存...${gl_bai}"
	sysctl -w vm.swappiness=10 2>/dev/null
	sysctl -w vm.dirty_ratio=20 2>/dev/null
	sysctl -w vm.dirty_background_ratio=10 2>/dev/null
	sysctl -w vm.overcommit_memory=1 2>/dev/null
	sysctl -w vm.min_free_kbytes=65536 2>/dev/null

	echo -e "${gl_lv}优化网络设置...${gl_bai}"
	sysctl -w net.core.rmem_max=16777216 2>/dev/null
	sysctl -w net.core.wmem_max=16777216 2>/dev/null
	sysctl -w net.core.netdev_max_backlog=5000 2>/dev/null
	sysctl -w net.core.somaxconn=4096 2>/dev/null
	sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216' 2>/dev/null
	sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216' 2>/dev/null
	sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null
	sysctl -w net.ipv4.tcp_max_syn_backlog=8192 2>/dev/null
	sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null
	sysctl -w net.ipv4.ip_local_port_range='1024 65535' 2>/dev/null

	echo -e "${gl_lv}优化缓存管理...${gl_bai}"
	sysctl -w vm.vfs_cache_pressure=50 2>/dev/null

	echo -e "${gl_lv}优化CPU设置...${gl_bai}"
	sysctl -w kernel.sched_autogroup_enabled=0 2>/dev/null

	echo -e "${gl_lv}其他优化...${gl_bai}"
	# 禁用透明大页面，减少延迟
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
	# 禁用 NUMA balancing
	sysctl -w kernel.numa_balancing=0 2>/dev/null


}


Kernel_optimize() {
	root_use
	while true; do
	  clear
	  send_stats "Linux内核调优管理"
	  echo "Linux系统内核参数优化"
	  echo "视频介绍: https://www.bilibili.com/video/BV1Kb421J7yg?t=0.1"
	  echo "------------------------------------------------"
	  echo "提供多种系统参数调优模式，用户可以根据自身使用场景进行选择切换。"
	  echo -e "${gl_huang}提示: ${gl_bai}生产环境请谨慎使用！"
	  echo "--------------------"
	  echo "1. 高性能优化模式：     最大化系统性能，优化文件描述符、虚拟内存、网络设置、缓存管理和CPU设置。"
	  echo "2. 均衡优化模式：       在性能与资源消耗之间取得平衡，适合日常使用。"
	  echo "3. 网站优化模式：       针对网站服务器进行优化，提高并发连接处理能力、响应速度和整体性能。"
	  echo "4. 直播优化模式：       针对直播推流的特殊需求进行优化，减少延迟，提高传输性能。"
	  echo "5. 游戏服优化模式：     针对游戏服务器进行优化，提高并发处理能力和响应速度。"
	  echo "6. 还原默认设置：       将系统设置还原为默认配置。"
	  echo "--------------------"
	  echo "0. 返回上一级"
	  echo "--------------------"
	  read -e -p "请输入你的选择: " sub_choice
	  case $sub_choice in
		  1)
			  cd ~
			  clear
			  tiaoyou_moshi="高性能优化模式"
			  optimize_high_performance
			  send_stats "高性能模式优化"
			  ;;
		  2)
			  cd ~
			  clear
			  optimize_balanced
			  send_stats "均衡模式优化"
			  ;;
		  3)
			  cd ~
			  clear
			  optimize_web_server
			  send_stats "网站优化模式"
			  ;;
		  4)
			  cd ~
			  clear
			  tiaoyou_moshi="直播优化模式"
			  optimize_high_performance
			  send_stats "直播推流优化"
			  ;;
		  5)
			  cd ~
			  clear
			  tiaoyou_moshi="游戏服优化模式"
			  optimize_high_performance
			  send_stats "游戏服优化"
			  ;;
		  6)
			  cd ~
			  clear
			  restore_defaults
			  send_stats "还原默认设置"
			  ;;
		  0)
			  break
			  ;;
		  *)
			  echo "无效的选择，请重新输入。"
			  ;;
	  esac
	  break_end
	done
}





update_locale() {
	local lang=$1
	local locale_file=$2

	if [ -f /etc/os-release ]; then
		. /etc/os-release
		case $ID in
			debian|ubuntu|kali)
				install locales
				sed -i "s/^\s*#\?\s*${locale_file}/${locale_file}/" /etc/locale.gen
				locale-gen
				echo "LANG=${lang}" > /etc/default/locale
				export LANG=${lang}
				echo -e "${gl_lv}系统语言已经修改为: $lang 重新连接SSH生效。${gl_bai}"
				break_end
				;;
			centos|rhel|almalinux|rocky|fedora)
				install glibc-langpack-zh
				localectl set-locale LANG=${lang}
				echo "LANG=${lang}" | tee /etc/locale.conf
				echo -e "${gl_lv}系统语言已经修改为: $lang 重新连接SSH生效。${gl_bai}"
				break_end
				;;
			*)
				echo "不支持的系统: $ID"
				break_end
				;;
		esac
	else
		echo "不支持的系统，无法识别系统类型。"
		break_end
	fi
}




linux_language() {
root_use
send_stats "切换系统语言"
while true; do
  clear
  echo "当前系统语言: $LANG"
  echo "------------------------"
  echo "1. 英文          2. 简体中文          3. 繁体中文"
  echo "------------------------"
  echo "0. 返回上一级"
  echo "------------------------"
  read -e -p "输入你的选择: " choice

  case $choice in
	  1)
		  update_locale "en_US.UTF-8" "en_US.UTF-8"
		  send_stats "切换到英文"
		  ;;
	  2)
		  update_locale "zh_CN.UTF-8" "zh_CN.UTF-8"
		  send_stats "切换到简体中文"
		  ;;
	  3)
		  update_locale "zh_TW.UTF-8" "zh_TW.UTF-8"
		  send_stats "切换到繁体中文"
		  ;;
	  *)
		  break
		  ;;
  esac
done
}



shell_bianse_profile() {

if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
	sed -i '/^PS1=/d' ~/.bashrc
	echo "${bianse}" >> ~/.bashrc
	# source ~/.bashrc
else
	sed -i '/^PS1=/d' ~/.profile
	echo "${bianse}" >> ~/.profile
	# source ~/.profile
fi
echo -e "${gl_lv}变更完成。重新连接SSH后可查看变化！${bai}"

break_end

}



shell_bianse() {
  root_use
  send_stats "命令行美化工具"
  while true; do
	clear
	echo "命令行美化工具"
	echo "------------------------"
	echo -e "1. \033[1;32mroot \033[1;34mlocalhost \033[1;31m~ \033[0m${bai}#"
	echo -e "2. \033[1;35mroot \033[1;36mlocalhost \033[1;33m~ \033[0m${bai}#"
	echo -e "3. \033[1;31mroot \033[1;32mlocalhost \033[1;34m~ \033[0m${bai}#"
	echo -e "4. \033[1;36mroot \033[1;33mlocalhost \033[1;37m~ \033[0m${bai}#"
	echo -e "5. \033[1;37mroot \033[1;31mlocalhost \033[1;32m~ \033[0m${bai}#"
	echo -e "6. \033[1;33mroot \033[1;34mlocalhost \033[1;35m~ \033[0m${bai}#"
	echo -e "7. root localhost ~ #"
	echo "------------------------"
	echo "0. 返回上一级"
	echo "------------------------"
	read -e -p "输入你的选择: " choice

	case $choice in
	  1)
		bianse="PS1='\[\033[1;32m\]\u\[\033[0m\]@\[\033[1;34m\]\h\[\033[0m\] \[\033[1;31m\]\w\[\033[0m\] # '"
		shell_bianse_profile

		;;
	  2)
		bianse="PS1='\[\033[1;35m\]\u\[\033[0m\]@\[\033[1;36m\]\h\[\033[0m\] \[\033[1;33m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  3)
		bianse="PS1='\[\033[1;31m\]\u\[\033[0m\]@\[\033[1;32m\]\h\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  4)
		bianse="PS1='\[\033[1;36m\]\u\[\033[0m\]@\[\033[1;33m\]\h\[\033[0m\] \[\033[1;37m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  5)
		bianse="PS1='\[\033[1;37m\]\u\[\033[0m\]@\[\033[1;31m\]\h\[\033[0m\] \[\033[1;32m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  6)
		bianse="PS1='\[\033[1;33m\]\u\[\033[0m\]@\[\033[1;34m\]\h\[\033[0m\] \[\033[1;35m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  7)
		bianse=""
		shell_bianse_profile
		;;
	  *)
		break
		;;
	esac

  done
}




linux_trash() {
  root_use
  send_stats "系统回收站"

  local bashrc_profile="/root/.bashrc"
  local TRASH_DIR="$HOME/.local/share/Trash/files"

  while true; do

	local trash_status
	if ! grep -q "trash-put" "$bashrc_profile"; then
		trash_status="${hui}未启用${gl_bai}"
	else
		trash_status="${gl_lv}已启用${gl_bai}"
	fi

	clear
	echo -e "当前回收站 ${trash_status}"
	echo -e "启用后rm删除的文件先进入回收站，防止误删重要文件！"
	echo "------------------------------------------------"
	ls -l --color=auto "$TRASH_DIR" 2>/dev/null || echo "回收站为空"
	echo "------------------------"
	echo "1. 启用回收站          2. 关闭回收站"
	echo "3. 还原内容            4. 清空回收站"
	echo "------------------------"
	echo "0. 返回上一级"
	echo "------------------------"
	read -e -p "输入你的选择: " choice

	case $choice in
	  1)
		k add trash-cli
		sed -i '/alias rm/d' "$bashrc_profile"
		echo "alias rm='trash-put'" >> "$bashrc_profile"
		source "$bashrc_profile"
		echo "回收站已启用，删除的文件将移至回收站。"
		sleep 2
		;;
	  2)
		k del trash-cli
		sed -i '/alias rm/d' "$bashrc_profile"
		echo "alias rm='rm -i'" >> "$bashrc_profile"
		source "$bashrc_profile"
		echo "回收站已关闭，文件将直接删除。"
		sleep 2
		;;
	  3)
		read -e -p "输入要还原的文件名: " file_to_restore
		if [ -e "$TRASH_DIR/$file_to_restore" ]; then
		  mv "$TRASH_DIR/$file_to_restore" "$HOME/"
		  echo "$file_to_restore 已还原到主目录。"
		else
		  echo "文件不存在。"
		fi
		;;
	  4)
		read -e -p "确认清空回收站？[y/n]: " confirm
		if [[ "$confirm" == "y" ]]; then
		  trash-empty
		  echo "回收站已清空。"
		fi
		;;
	  *)
		break
		;;
	esac
  done
}




linux_ps() {

	clear
	send_stats "系统信息查询"

	ip_address

	cpu_info=$(lscpu | awk -F': +' '/Model name:/ {print $2; exit}')

	cpu_usage_percent=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else printf "%.0f\n", (($2+$4-u1) * 100 / (t-t1))}' \
		<(grep 'cpu ' /proc/stat) <(sleep 1; grep 'cpu ' /proc/stat))

	cpu_cores=$(nproc)

	mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')

	disk_info=$(df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3, $2, $5}')

	ipinfo=$(curl -s ipinfo.io)
	country=$(echo "$ipinfo" | grep 'country' | awk -F': ' '{print $2}' | tr -d '",')
	city=$(echo "$ipinfo" | grep 'city' | awk -F': ' '{print $2}' | tr -d '",')
	isp_info=$(echo "$ipinfo" | grep 'org' | awk -F': ' '{print $2}' | tr -d '",')


	cpu_arch=$(uname -m)

	hostname=$(uname -n)

	kernel_version=$(uname -r)

	congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
	queue_algorithm=$(sysctl -n net.core.default_qdisc)

	# 尝试使用 lsb_release 获取系统信息
	os_info=$(grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | tr -d '"')

	output_status

	current_time=$(date "+%Y-%m-%d %I:%M %p")


	swap_info=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; printf "%dMB/%dMB (%d%%)", used, total, percentage}')

	runtime=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分\n", run_minutes)}')

	timezone=$(current_timezone)


	echo ""
	echo -e "系统信息查询"
	echo -e "${gl_kjlan}------------------------"
	echo -e "${gl_kjlan}主机名: ${gl_bai}$hostname"
	echo -e "${gl_kjlan}运营商: ${gl_bai}$isp_info"
	echo -e "${gl_kjlan}------------------------"
	echo -e "${gl_kjlan}系统版本: ${gl_bai}$os_info"
	echo -e "${gl_kjlan}Linux版本: ${gl_bai}$kernel_version"
	echo -e "${gl_kjlan}------------------------"
	echo -e "${gl_kjlan}CPU架构: ${gl_bai}$cpu_arch"
	echo -e "${gl_kjlan}CPU型号: ${gl_bai}$cpu_info"
	echo -e "${gl_kjlan}CPU核心数: ${gl_bai}$cpu_cores"
	echo -e "${gl_kjlan}------------------------"
	echo -e "${gl_kjlan}CPU占用: ${gl_bai}$cpu_usage_percent%"
	echo -e "${gl_kjlan}物理内存: ${gl_bai}$mem_info"
	echo -e "${gl_kjlan}虚拟内存: ${gl_bai}$swap_info"
	echo -e "${gl_kjlan}硬盘占用: ${gl_bai}$disk_info"
	echo -e "${gl_kjlan}------------------------"
	echo -e "${gl_kjlan}$output"
	echo -e "${gl_kjlan}------------------------"
	echo -e "${gl_kjlan}网络拥堵算法: ${gl_bai}$congestion_algorithm $queue_algorithm"
	echo -e "${gl_kjlan}------------------------"
	echo -e "${gl_kjlan}公网IPv4地址: ${gl_bai}$ipv4_address"
	echo -e "${gl_kjlan}公网IPv6地址: ${gl_bai}$ipv6_address"
	echo -e "${gl_kjlan}------------------------"
	echo -e "${gl_kjlan}地理位置: ${gl_bai}$country $city"
	echo -e "${gl_kjlan}系统时区: ${gl_bai}$timezone"
	echo -e "${gl_kjlan}系统时间: ${gl_bai}$current_time"
	echo -e "${gl_kjlan}------------------------"
	echo -e "${gl_kjlan}系统运行时长: ${gl_bai}$runtime"
	echo



}



linux_tools() {

  while true; do
	  clear
	  # send_stats "常用工具"
	  echo -e "▶ 常用工具"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}curl 下载工具 ${gl_huang}★${gl_bai}                   ${gl_kjlan}2.   ${gl_bai}wget 下载工具 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}3.   ${gl_bai}sudo 超级管理权限工具             ${gl_kjlan}4.   ${gl_bai}socat 通信连接工具"
	  echo -e "${gl_kjlan}5.   ${gl_bai}htop 系统监控工具                 ${gl_kjlan}6.   ${gl_bai}iftop 网络流量监控工具"
	  echo -e "${gl_kjlan}7.   ${gl_bai}unzip ZIP压缩解压工具             ${gl_kjlan}8.   ${gl_bai}tar GZ压缩解压工具"
	  echo -e "${gl_kjlan}9.   ${gl_bai}tmux 多路后台运行工具             ${gl_kjlan}10.  ${gl_bai}ffmpeg 视频编码直播推流工具"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}11.  ${gl_bai}btop 现代化监控工具 ${gl_huang}★${gl_bai}             ${gl_kjlan}12.  ${gl_bai}ranger 文件管理工具"
	  echo -e "${gl_kjlan}13.  ${gl_bai}ncdu 磁盘占用查看工具             ${gl_kjlan}14.  ${gl_bai}fzf 全局搜索工具"
	  echo -e "${gl_kjlan}15.  ${gl_bai}vim 文本编辑器                    ${gl_kjlan}16.  ${gl_bai}nano 文本编辑器 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}17.  ${gl_bai}git 版本控制系统"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}21.  ${gl_bai}黑客帝国屏保                      ${gl_kjlan}22.  ${gl_bai}跑火车屏保"
	  echo -e "${gl_kjlan}26.  ${gl_bai}俄罗斯方块小游戏                  ${gl_kjlan}27.  ${gl_bai}贪吃蛇小游戏"
	  echo -e "${gl_kjlan}28.  ${gl_bai}太空入侵者小游戏"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}31.  ${gl_bai}全部安装                          ${gl_kjlan}32.  ${gl_bai}全部安装（不含屏保和游戏）${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}33.  ${gl_bai}全部卸载"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}41.  ${gl_bai}安装指定工具                      ${gl_kjlan}42.  ${gl_bai}卸载指定工具"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "请输入你的选择: " sub_choice

	  case $sub_choice in
		  1)
			  clear
			  install curl
			  clear
			  echo "工具已安装，使用方法如下："
			  curl --help
			  send_stats "安装curl"
			  ;;
		  2)
			  clear
			  install wget
			  clear
			  echo "工具已安装，使用方法如下："
			  wget --help
			  send_stats "安装wget"
			  ;;
			3)
			  clear
			  install sudo
			  clear
			  echo "工具已安装，使用方法如下："
			  sudo --help
			  send_stats "安装sudo"
			  ;;
			4)
			  clear
			  install socat
			  clear
			  echo "工具已安装，使用方法如下："
			  socat -h
			  send_stats "安装socat"
			  ;;
			5)
			  clear
			  install htop
			  clear
			  htop
			  send_stats "安装htop"
			  ;;
			6)
			  clear
			  install iftop
			  clear
			  iftop
			  send_stats "安装iftop"
			  ;;
			7)
			  clear
			  install unzip
			  clear
			  echo "工具已安装，使用方法如下："
			  unzip
			  send_stats "安装unzip"
			  ;;
			8)
			  clear
			  install tar
			  clear
			  echo "工具已安装，使用方法如下："
			  tar --help
			  send_stats "安装tar"
			  ;;
			9)
			  clear
			  install tmux
			  clear
			  echo "工具已安装，使用方法如下："
			  tmux --help
			  send_stats "安装tmux"
			  ;;
			10)
			  clear
			  install ffmpeg
			  clear
			  echo "工具已安装，使用方法如下："
			  ffmpeg --help
			  send_stats "安装ffmpeg"
			  ;;

			11)
			  clear
			  install btop
			  clear
			  btop
			  send_stats "安装btop"
			  ;;
			12)
			  clear
			  install ranger
			  cd /
			  clear
			  ranger
			  cd ~
			  send_stats "安装ranger"
			  ;;
			13)
			  clear
			  install ncdu
			  cd /
			  clear
			  ncdu
			  cd ~
			  send_stats "安装ncdu"
			  ;;
			14)
			  clear
			  install fzf
			  cd /
			  clear
			  fzf
			  cd ~
			  send_stats "安装fzf"
			  ;;
			15)
			  clear
			  install vim
			  cd /
			  clear
			  vim -h
			  cd ~
			  send_stats "安装vim"
			  ;;
			16)
			  clear
			  install nano
			  cd /
			  clear
			  nano -h
			  cd ~
			  send_stats "安装nano"
			  ;;


			17)
			  clear
			  install git
			  cd /
			  clear
			  git --help
			  cd ~
			  send_stats "安装git"
			  ;;

			21)
			  clear
			  install cmatrix
			  clear
			  cmatrix
			  send_stats "安装cmatrix"
			  ;;
			22)
			  clear
			  install sl
			  clear
			  sl
			  send_stats "安装sl"
			  ;;
			26)
			  clear
			  install bastet
			  clear
			  bastet
			  send_stats "安装bastet"
			  ;;
			27)
			  clear
			  install nsnake
			  clear
			  nsnake
			  send_stats "安装nsnake"
			  ;;
			28)
			  clear
			  install ninvaders
			  clear
			  ninvaders
			  send_stats "安装ninvaders"
			  ;;

		  31)
			  clear
			  send_stats "全部安装"
			  install curl wget sudo socat htop iftop unzip tar tmux ffmpeg btop ranger ncdu fzf cmatrix sl bastet nsnake ninvaders vim nano git
			  ;;

		  32)
			  clear
			  send_stats "全部安装（不含游戏和屏保）"
			  install curl wget sudo socat htop iftop unzip tar tmux ffmpeg btop ranger ncdu fzf vim nano git
			  ;;


		  33)
			  clear
			  send_stats "全部卸载"
			  remove htop iftop unzip tmux ffmpeg btop ranger ncdu fzf cmatrix sl bastet nsnake ninvaders vim nano git
			  ;;

		  41)
			  clear
			  read -e -p "请输入安装的工具名（wget curl sudo htop）: " installname
			  install $installname
			  send_stats "安装指定软件"
			  ;;
		  42)
			  clear
			  read -e -p "请输入卸载的工具名（htop ufw tmux cmatrix）: " removename
			  remove $removename
			  send_stats "卸载指定软件"
			  ;;

		  0)
			  kejilion

			  ;;

		  *)
			  echo "无效的输入!"
			  ;;
	  esac
	  break_end
  done




}


linux_bbr() {
	clear
	send_stats "bbr管理"
	if [ -f "/etc/alpine-release" ]; then
		while true; do
			  clear
			  congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
			  queue_algorithm=$(sysctl -n net.core.default_qdisc)
			  echo "当前TCP阻塞算法: $congestion_algorithm $queue_algorithm"

			  echo ""
			  echo "BBR管理"
			  echo "------------------------"
			  echo "1. 开启BBRv3              2. 关闭BBRv3（会重启）"
			  echo "------------------------"
			  echo "0. 返回上一级选单"
			  echo "------------------------"
			  read -e -p "请输入你的选择: " sub_choice

			  case $sub_choice in
				  1)
					bbr_on
					send_stats "alpine开启bbr3"
					  ;;
				  2)
					sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
					sysctl -p
					server_reboot
					  ;;
				  0)
					  break  # 跳出循环，退出菜单
					  ;;

				  *)
					  break  # 跳出循环，退出菜单
					  ;;

			  esac
		done
	else
		install wget
		wget --no-check-certificate -O tcpx.sh ${gh_proxy}https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcpx.sh
		chmod +x tcpx.sh
		./tcpx.sh
	fi


}





linux_docker() {

	while true; do
	  clear
	  # send_stats "docker管理"
	  echo -e "▶ Docker管理"
	  echo -e "${gl_kjlan}------------------------"
	  if ! command -v docker >/dev/null 2>&1; then
		echo -e "${gl_hong}Docker未安装${gl_bai}"
	  elif ! docker info >/dev/null 2>&1; then
		echo -e "${gl_huang}Docker已安装但未运行${gl_bai}"
	  else
		local docker_container_count docker_image_count docker_network_count docker_volume_count
		docker_container_count="$(docker ps -a -q 2>/dev/null | wc -l | tr -d ' ')"
		docker_image_count="$(docker images -q 2>/dev/null | sort -u | wc -l | tr -d ' ')"
		docker_network_count="$(docker network ls -q 2>/dev/null | wc -l | tr -d ' ')"
		docker_volume_count="$(docker volume ls -q 2>/dev/null | wc -l | tr -d ' ')"
		echo -e "${gl_lv}Docker已安装${gl_bai}  容器：${gl_lv}${docker_container_count:-0}${gl_bai}  镜像：${gl_lv}${docker_image_count:-0}${gl_bai}  网络：${gl_lv}${docker_network_count:-0}${gl_bai}  卷：${gl_lv}${docker_volume_count:-0}${gl_bai}"
	  fi
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}安装更新Docker环境 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}2.   ${gl_bai}查看Docker全局状态 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}3.   ${gl_bai}Docker容器管理 ▶ ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}4.   ${gl_bai}Docker镜像管理 ▶"
	  echo -e "${gl_kjlan}5.   ${gl_bai}Docker网络管理 ▶"
	  echo -e "${gl_kjlan}6.   ${gl_bai}Docker卷管理 ▶"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}7.   ${gl_bai}清理无用的docker容器和镜像网络数据卷"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}8.   ${gl_bai}更换Docker源"
	  echo -e "${gl_kjlan}9.   ${gl_bai}编辑daemon.json文件"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}11.  ${gl_bai}开启Docker-ipv6访问"
	  echo -e "${gl_kjlan}12.  ${gl_bai}关闭Docker-ipv6访问"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}20.  ${gl_bai}卸载Docker环境"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "请输入你的选择: " sub_choice

	  case $sub_choice in
		  1)
			clear
			send_stats "安装docker环境"
			install_add_docker

			  ;;
		  2)
			  clear
			  send_stats "docker全局状态"
			  echo "Docker版本"
			  docker -v
			  docker compose version

			  echo ""
			  echo "Docker镜像列表"
			  docker image ls
			  echo ""
			  echo "Docker容器列表"
			  docker ps -a
			  echo ""
			  echo "Docker卷列表"
			  docker volume ls
			  echo ""
			  echo "Docker网络列表"
			  docker network ls
			  echo ""

			  ;;
		  3)
			  docker_ps
			  ;;
		  4)
			  docker_image
			  ;;

		  5)
			  while true; do
				  clear
				  send_stats "Docker网络管理"
				  echo "Docker网络列表"
				  echo "------------------------------------------------------------"
				  docker network ls
				  echo ""

				  echo "------------------------------------------------------------"
				  container_ids=$(docker ps -q)
				  printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"

				  for container_id in $container_ids; do
					  container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")

					  container_name=$(echo "$container_info" | awk '{print $1}' | sed 's#^/##')
					  network_info=$(echo "$container_info" | cut -d' ' -f2-)

					  while IFS= read -r line; do
						  network_name=$(echo "$line" | awk '{print $1}')
						  ip_address=$(echo "$line" | awk '{print $2}')
						  case "$network_name" in
							  host) ip_address="宿主机网络" ;;
							  none) ip_address="无网络" ;;
						  esac
						  if [ -z "$ip_address" ] || [ "$ip_address" = "<no" ] || [ "$ip_address" = "<no value>" ] || [ "$ip_address" = "invalid" ]; then
							  ip_address="-"
						  fi

						  printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
					  done <<< "$network_info"
				  done

				  echo ""
				  echo "网络操作"
				  echo "------------------------"
				  echo "1. 创建网络"
				  echo "2. 加入网络"
				  echo "3. 退出网络"
				  echo "4. 删除网络"
				  echo "------------------------"
				  echo "0. 返回上一级选单"
				  echo "------------------------"
				  read -e -p "请输入你的选择: " sub_choice

				  case $sub_choice in
					  1)
						  send_stats "创建网络"
						  read -e -p "设置新网络名: " dockernetwork
						  docker network create $dockernetwork
						  ;;
					  2)
						  send_stats "加入网络"
						  read -e -p "加入网络名: " dockernetwork
						  read -e -p "那些容器加入该网络（多个容器名请用空格分隔）: " dockernames

						  for dockername in $dockernames; do
							  docker network connect $dockernetwork $dockername
						  done
						  ;;
					  3)
						  send_stats "加入网络"
						  read -e -p "退出网络名: " dockernetwork
						  read -e -p "那些容器退出该网络（多个容器名请用空格分隔）: " dockernames

						  for dockername in $dockernames; do
							  docker network disconnect $dockernetwork $dockername
						  done

						  ;;

					  4)
						  send_stats "删除网络"
						  read -e -p "请输入要删除的网络名: " dockernetwork
						  docker network rm $dockernetwork
						  ;;
					  0)
						  break  # 跳出循环，退出菜单
						  ;;

					  *)
						  break  # 跳出循环，退出菜单
						  ;;
				  esac
			  done
			  ;;

		  6)
			  while true; do
				  clear
				  send_stats "Docker卷管理"
				  echo "Docker卷列表"
				  docker volume ls
				  echo ""
				  echo "卷操作"
				  echo "------------------------"
				  echo "1. 创建新卷"
				  echo "2. 删除指定卷"
				  echo "3. 删除所有卷"
				  echo "------------------------"
				  echo "0. 返回上一级选单"
				  echo "------------------------"
				  read -e -p "请输入你的选择: " sub_choice

				  case $sub_choice in
					  1)
						  send_stats "新建卷"
						  read -e -p "设置新卷名: " dockerjuan
						  docker volume create $dockerjuan

						  ;;
					  2)
						  read -e -p "输入删除卷名（多个卷名请用空格分隔）: " dockerjuans

						  for dockerjuan in $dockerjuans; do
							  docker volume rm $dockerjuan
						  done

						  ;;

					   3)
						  send_stats "删除所有卷"
						  read -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定删除所有未使用的卷吗？(Y/N): ")" choice
						  case "$choice" in
							[Yy])
							  docker volume prune -f
							  ;;
							[Nn])
							  ;;
							*)
							  echo "无效的选择，请输入 Y 或 N。"
							  ;;
						  esac
						  ;;
					  0)
						  break  # 跳出循环，退出菜单
						  ;;

					  *)
						  break  # 跳出循环，退出菜单
						  ;;
				  esac
			  done
			  ;;
		  7)
			  clear
			  send_stats "Docker清理"
			  read -e -p "$(echo -e "${gl_huang}提示: ${gl_bai}将清理无用的镜像容器网络，包括停止的容器，确定清理吗？(Y/N): ")" choice
			  case "$choice" in
				[Yy])
				  docker system prune -af --volumes
				  ;;
				[Nn])
				  ;;
				*)
				  echo "无效的选择，请输入 Y 或 N。"
				  ;;
			  esac
			  ;;
		  8)
			  clear
			  send_stats "Docker源"
			  bash <(curl -sSL https://linuxmirrors.cn/docker.sh)
			  ;;

		  9)
			  clear
			  install nano
			  mkdir -p /etc/docker && nano /etc/docker/daemon.json
			  restart docker
			  ;;

		  11)
			  clear
			  send_stats "Docker v6 开"
			  docker_ipv6_on
			  ;;

		  12)
			  clear
			  send_stats "Docker v6 关"
			  docker_ipv6_off
			  ;;

		  20)
			  clear
			  send_stats "Docker卸载"
			  read -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定卸载docker环境吗？(Y/N): ")" choice
			  case "$choice" in
				[Yy])
				  containers=$(docker ps -a -q 2>/dev/null)
				  images=$(docker images -q 2>/dev/null)
				  [ -n "$containers" ] && docker rm -f $containers
				  [ -n "$images" ] && docker rmi -f $images
				  docker network prune -f
				  remove docker docker-compose docker-ce docker-ce-cli containerd.io

				  ;;
				[Nn])
				  ;;
				*)
				  echo "无效的选择，请输入 Y 或 N。"
				  ;;
			  esac
			  ;;

		  0)
			  kejilion
			  ;;
		  *)
			  echo "无效的输入!"
			  ;;
	  esac
	  break_end


	done


}



linux_test() {

	while true; do
	  clear
	  # send_stats "测试脚本合集"
	  echo -e "▶ 测试脚本合集"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}IP及解锁状态检测"
	  echo -e "${gl_kjlan}1.   ${gl_bai}ChatGPT 解锁状态检测"
	  echo -e "${gl_kjlan}2.   ${gl_bai}Region 流媒体解锁测试"
	  echo -e "${gl_kjlan}3.   ${gl_bai}yeahwu 流媒体解锁检测"
	  echo -e "${gl_kjlan}4.   ${gl_bai}xykt IP质量体检脚本 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}网络线路测速"
	  echo -e "${gl_kjlan}11.  ${gl_bai}besttrace 三网回程延迟路由测试"
	  echo -e "${gl_kjlan}12.  ${gl_bai}mtr_trace 三网回程线路测试"
	  echo -e "${gl_kjlan}13.  ${gl_bai}Superspeed 三网测速"
	  echo -e "${gl_kjlan}14.  ${gl_bai}nxtrace 快速回程测试脚本"
	  echo -e "${gl_kjlan}15.  ${gl_bai}nxtrace 指定IP回程测试脚本"
	  echo -e "${gl_kjlan}16.  ${gl_bai}ludashi2020 三网线路测试"
	  echo -e "${gl_kjlan}17.  ${gl_bai}i-abc 多功能测速脚本"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}硬件性能测试"
	  echo -e "${gl_kjlan}21.  ${gl_bai}yabs 性能测试"
	  echo -e "${gl_kjlan}22.  ${gl_bai}icu/gb5 CPU性能测试脚本"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}综合性测试"
	  echo -e "${gl_kjlan}31.  ${gl_bai}bench 性能测试"
	  echo -e "${gl_kjlan}32.  ${gl_bai}spiritysdx 融合怪测评 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}33.  ${gl_bai}NodeSeek论坛脚本测试 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}99.  ${gl_bai}原始脚本IP质量体检脚本https://github.com/xykt/IPQuality ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}999.  ${gl_bai}IP质量体检脚本https://github.com/zaixiangjian/IPQuality/blob/main/ip.sh ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "请输入你的选择: " sub_choice

	  case $sub_choice in
		  1)
			  clear
			  send_stats "ChatGPT解锁状态检测"
			  bash <(curl -Ls https://cdn.jsdelivr.net/gh/missuo/OpenAI-Checker/openai.sh)
			  ;;
		  2)
			  clear
			  send_stats "Region流媒体解锁测试"
			  bash <(curl -L -s check.unlock.media)
			  ;;
		  3)
			  clear
			  send_stats "yeahwu流媒体解锁检测"
			  install wget
			  wget -qO- ${gh_proxy}https://github.com/yeahwu/check/raw/main/check.sh | bash
			  ;;
		  4)
			  clear
			  send_stats "xykt_IP质量体检脚本"
			  bash <(curl -Ls IP.Check.Place)
			  ;;
		  11)
			  clear
			  send_stats "besttrace三网回程延迟路由测试"
			  install wget
			  wget -qO- git.io/besttrace | bash
			  ;;
		  12)
			  clear
			  send_stats "mtr_trace三网回程线路测试"
			  curl ${gh_proxy}https://raw.githubusercontent.com/zhucaidan/mtr_trace/main/mtr_trace.sh | bash
			  ;;
		  13)
			  clear
			  send_stats "Superspeed三网测速"
			  bash <(curl -Lso- https://git.io/superspeed_uxh)
			  ;;
		  14)
			  clear
			  send_stats "nxtrace快速回程测试脚本"
			  curl nxtrace.org/nt |bash
			  nexttrace --fast-trace --tcp
			  ;;
		  15)
			  clear
			  send_stats "nxtrace指定IP回程测试脚本"
			  echo "可参考的IP列表"
			  echo "------------------------"
			  echo "北京电信: 219.141.136.12"
			  echo "北京联通: 202.106.50.1"
			  echo "北京移动: 221.179.155.161"
			  echo "上海电信: 202.96.209.133"
			  echo "上海联通: 210.22.97.1"
			  echo "上海移动: 211.136.112.200"
			  echo "广州电信: 58.60.188.222"
			  echo "广州联通: 210.21.196.6"
			  echo "广州移动: 120.196.165.24"
			  echo "成都电信: 61.139.2.69"
			  echo "成都联通: 119.6.6.6"
			  echo "成都移动: 211.137.96.205"
			  echo "湖南电信: 36.111.200.100"
			  echo "湖南联通: 42.48.16.100"
			  echo "湖南移动: 39.134.254.6"
			  echo "------------------------"

			  read -e -p "输入一个指定IP: " testip
			  curl nxtrace.org/nt |bash
			  nexttrace $testip
			  ;;

		  16)
			  clear
			  send_stats "ludashi2020三网线路测试"
			  curl ${gh_proxy}https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh -sSf | sh
			  ;;

		  17)
			  clear
			  send_stats "i-abc多功能测速脚本"
			  bash <(curl -sL ${gh_proxy}https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh)
			  ;;


		  21)
			  clear
			  send_stats "yabs性能测试"
			  check_swap
			  curl -sL yabs.sh | bash -s -- -i -5
			  ;;
		  22)
			  clear
			  send_stats "icu/gb5 CPU性能测试脚本"
			  check_swap
			  bash <(curl -sL bash.icu/gb5)
			  ;;

		  31)
			  clear
			  send_stats "bench性能测试"
			  curl -Lso- bench.sh | bash
			  ;;
		  32)
			  send_stats "spiritysdx融合怪测评"
			  clear
			  curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh
			  ;;
		  33)
			  send_stats "NodeSeek论坛脚本检测"
			  clear
			  bash <(curl -sL https://run.NodeQuality.com)
			  ;;
		  99)
			  send_stats "IP质量体检脚本https://github.com/xykt/IPQuality"
			  clear
			  bash <(curl -Ls https://Check.Place) -I
			  ;;

		  999)
			  send_stats "IP质量体检脚本https://github.com/zaixiangjian/IPQuality"
			  clear
			  bash <(curl -sS https://raw.githubusercontent.com/zaixiangjian/IPQuality/main/ip.sh) 
			  ;;

		  0)
			  kejilion

			  ;;
		  *)
			  echo "无效的输入!"
			  ;;
	  esac
	  break_end

	done


}


linux_Oracle() {


	 while true; do
	  clear
	  send_stats "甲骨文云脚本合集"
	  echo -e "▶ 甲骨文云脚本合集"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}安装闲置机器活跃脚本"
	  echo -e "${gl_kjlan}2.   ${gl_bai}卸载闲置机器活跃脚本"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}3.   ${gl_bai}DD重装系统脚本"
	  echo -e "${gl_kjlan}4.   ${gl_bai}R探长开机脚本"
	  echo -e "${gl_kjlan}5.   ${gl_bai}开启ROOT密码登录模式"
	  echo -e "${gl_kjlan}6.   ${gl_bai}IPV6恢复工具"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "请输入你的选择: " sub_choice

	  case $sub_choice in
		  1)
			  clear
			  echo "活跃脚本: CPU占用10-20% 内存占用20% "
			  read -e -p "确定安装吗？(Y/N): " choice
			  case "$choice" in
				[Yy])

				  install_docker

				  # 设置默认值
				  DEFAULT_CPU_CORE=1
				  DEFAULT_CPU_UTIL="10-20"
				  DEFAULT_MEM_UTIL=20
				  DEFAULT_SPEEDTEST_INTERVAL=120

				  # 提示用户输入CPU核心数和占用百分比，如果回车则使用默认值
				  read -e -p "请输入CPU核心数 [默认: $DEFAULT_CPU_CORE]: " cpu_core
				  cpu_core=${cpu_core:-$DEFAULT_CPU_CORE}

				  read -e -p "请输入CPU占用百分比范围（例如10-20） [默认: $DEFAULT_CPU_UTIL]: " cpu_util
				  cpu_util=${cpu_util:-$DEFAULT_CPU_UTIL}

				  read -e -p "请输入内存占用百分比 [默认: $DEFAULT_MEM_UTIL]: " mem_util
				  mem_util=${mem_util:-$DEFAULT_MEM_UTIL}

				  read -e -p "请输入Speedtest间隔时间（秒） [默认: $DEFAULT_SPEEDTEST_INTERVAL]: " speedtest_interval
				  speedtest_interval=${speedtest_interval:-$DEFAULT_SPEEDTEST_INTERVAL}

				  # 运行Docker容器
				  docker run -itd --name=lookbusy --restart=always \
					  -e TZ=Asia/Shanghai \
					  -e CPU_UTIL="$cpu_util" \
					  -e CPU_CORE="$cpu_core" \
					  -e MEM_UTIL="$mem_util" \
					  -e SPEEDTEST_INTERVAL="$speedtest_interval" \
					  fogforest/lookbusy
				  send_stats "甲骨文云安装活跃脚本"

				  ;;
				[Nn])

				  ;;
				*)
				  echo "无效的选择，请输入 Y 或 N。"
				  ;;
			  esac
			  ;;
		  2)
			  clear
			  docker rm -f lookbusy
			  docker rmi fogforest/lookbusy
			  send_stats "甲骨文云卸载活跃脚本"
			  ;;

		  3)
		  clear
		  echo "重装系统"
		  echo "--------------------------------"
    		  echo "原地址"
    		  echo "			  bash <(wget --no-check-certificate -qO- "${gh_proxy}https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh") $xitong -v 64 -p $vpspasswd -port 22"
    		  echo "--------------------------------"
		  echo -e "${gl_hong}注意: ${gl_bai}重装有风险失联，不放心者慎用。重装预计花费15分钟，请提前备份数据。"
		  read -e -p "确定继续吗？(Y/N): " choice

		  case "$choice" in
			[Yy])
			  while true; do
				read -e -p "请选择要重装的系统:  1. Debian12 | 2. Ubuntu20.04 : " sys_choice

				case "$sys_choice" in
				  1)
					xitong="-d 12"
					break  # 结束循环
					;;
				  2)
					xitong="-u 20.04"
					break  # 结束循环
					;;
				  *)
					echo "无效的选择，请重新输入。"
					;;
				esac
			  done

			  read -e -p "请输入你重装后的密码: " vpspasswd
			  install wget
			  bash <(wget --no-check-certificate -qO- "${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/Note/master/InstallNET.sh") $xitong -v 64 -p $vpspasswd -port 22
			  send_stats "甲骨文云重装系统脚本"
			  ;;
			[Nn])
			  echo "已取消"
			  ;;
			*)
			  echo "无效的选择，请输入 Y 或 N。"
			  ;;
		  esac
			  ;;

		  4)
			  clear
			  echo "该功能处于开发阶段，敬请期待！"
			  ;;
		  5)
			  clear
			  add_sshpasswd

			  ;;
		  6)
			  clear
			  bash <(curl -L -s jhb.ovh/jb/v6.sh)
			  echo "该功能由jhb大神提供，感谢他！"
			  send_stats "ipv6修复"
			  ;;
		  0)
			  kejilion

			  ;;
		  *)
			  echo "无效的输入!"
			  ;;
	  esac
	  break_end

	done



}






linux_ldnmp() {

  while true; do
	clear
	# send_stats "LDNMP建站"
	echo -e "${gl_huang}▶ LDNMP建站"
	echo -e "${gl_huang}------------------------"
	ldnmp_site_count="$(find /home/web/conf.d -maxdepth 1 -type f -name '*.conf' ! -name 'default.conf' 2>/dev/null | wc -l | tr -d ' ')"
	ldnmp_db_count="0"
	if docker inspect mysql >/dev/null 2>&1 && [ -f /home/web/docker-compose.yml ]; then
		dbrootpasswd="$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml 2>/dev/null | tr -d '[:space:]')"
		if [ -n "$dbrootpasswd" ]; then
			ldnmp_db_count="$(docker exec mysql mysql -u root -p"$dbrootpasswd" -N -e "SHOW DATABASES;" 2>/dev/null | grep -Ev '^(information_schema|mysql|performance_schema|sys)$' | wc -l | tr -d ' ')"
		fi
	fi

	if docker inspect php >/dev/null 2>&1 || docker inspect mysql >/dev/null 2>&1 || docker inspect redis >/dev/null 2>&1; then
		echo -e "${gl_lv}环境已安装${gl_bai}  站点：${gl_lv}${ldnmp_site_count:-0}${gl_bai}  数据库：${gl_lv}${ldnmp_db_count:-0}${gl_bai}"
	elif docker inspect nginx >/dev/null 2>&1; then
		echo -e "${gl_kjlan}仅安装nginx${gl_bai}  站点：${gl_lv}${ldnmp_site_count:-0}${gl_bai}  数据库：${gl_lv}${ldnmp_db_count:-0}${gl_bai}"
	else
		echo -e "${gl_hong}环境未安装${gl_bai}  站点：${gl_lv}0${gl_bai}  数据库：${gl_lv}0${gl_bai}"
	fi
	echo -e "${gl_huang}------------------------"
	echo -e "${gl_huang}1.   ${gl_bai}安装LDNMP环境 ${gl_huang}★${gl_bai}"
	echo -e "${gl_huang}2.   ${gl_bai}安装WordPress ${gl_huang}★${gl_bai}"
	echo -e "${gl_huang}3.   ${gl_bai}安装Discuz论坛"
	echo -e "${gl_huang}4.   ${gl_bai}安装可道云桌面"
	echo -e "${gl_huang}5.   ${gl_bai}安装苹果CMS网站"
	echo -e "${gl_huang}6.   ${gl_bai}安装独角数发卡网"
	echo -e "${gl_huang}7.   ${gl_bai}安装flarum论坛网站"
	echo -e "${gl_huang}8.   ${gl_bai}安装typecho轻量博客网站"
	echo -e "${gl_huang}20.  ${gl_bai}自定义动态站点"
	echo -e "${gl_huang}------------------------"
	echo -e "${gl_huang}21.  ${gl_bai}仅安装nginx ${gl_huang}★${gl_bai}"
	echo -e "${gl_huang}22.  ${gl_bai}站点重定向"
	echo -e "${gl_huang}23.  ${gl_bai}站点反向代理-IP+端口 ${gl_huang}★${gl_bai}"
	echo -e "${gl_huang}24.  ${gl_bai}站点反向代理-域名"
	echo -e "${gl_huang}25.  ${gl_bai}自定义静态站点"
	echo -e "${gl_huang}26.  ${gl_bai}安装Bitwarden密码管理平台"
	echo -e "${gl_huang}27.  ${gl_bai}安装Halo博客网站"
	echo -e "${gl_huang}------------------------"
	echo -e "${gl_huang}31.  ${gl_bai}站点数据管理 ${gl_huang}★${gl_bai}"
	echo -e "${gl_huang}32.  ${gl_bai}备份全站数据"
	echo -e "${gl_huang}33.  ${gl_bai}定时远程备份"
	echo -e "${gl_huang}34.  ${gl_bai}还原全站数据"
	echo -e "${gl_huang}------------------------"
	echo -e "${gl_huang}35.  ${gl_bai}站点防御程序"
	echo -e "${gl_huang}------------------------"
	echo -e "${gl_huang}36.  ${gl_bai}优化LDNMP环境"
	echo -e "${gl_huang}37.  ${gl_bai}更新LDNMP环境"
	echo -e "${gl_huang}38.  ${gl_bai}卸载LDNMP环境"
	echo -e "${gl_huang}------------------------"
	echo -e "${gl_huang}0.   ${gl_bai}返回主菜单"
	echo -e "${gl_huang}------------------------${gl_bai}"
	read -e -p "请输入你的选择: " sub_choice


	case $sub_choice in
	  1)
	  send_stats "安装LDNMP环境"
	  root_use
	  ldnmp_install_status_one
	  check_port
	  install_dependency
	  install_docker
	  install_certbot

	  install_ldnmp_conf
	  ldnmp_select_versions || { echo "已取消环境版本选择。"; break; }
	  ldnmp_apply_versions
	  install_ldnmp || { echo "环境配置失败，请检查上方错误。"; break; }
	  nginx_upgrade || echo "nginx 更新/检测失败，请稍后单独执行 37 → 1. 更新nginx 查看详细错误。"

		;;
	  2)
	  clear
	  # wordpress
	  webname="WordPress"
	  send_stats "安装$webname"

	  ldnmp_install_status
	  add_yuming
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/wordpress.com.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming
	  wget -O latest.zip https://cn.wordpress.org/latest-zh_CN.zip
	  unzip latest.zip
	  rm latest.zip

	  echo "define('FS_METHOD', 'direct'); define('WP_REDIS_HOST', 'redis'); define('WP_REDIS_PORT', '6379');" >> /home/web/html/$yuming/wordpress/wp-config-sample.php

	  restart_ldnmp

	  ldnmp_web_on
	  echo "数据库名: $dbname"
	  echo "用户名: $dbuse"
	  echo "密码: $dbusepasswd"
	  echo "数据库地址: mysql"
	  echo "表前缀: wp_"

		;;

	  3)
	  clear
	  # Discuz论坛
	  webname="Discuz论坛"
	  send_stats "安装$webname"
	  ldnmp_install_status
	  add_yuming
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/discuz.com.conf

	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming
	  wget -O latest.zip ${gh_proxy}https://github.com/zaixiangjian/Website_source_code/raw/main/Discuz_X3.5_SC_UTF8_20240520.zip
	  unzip latest.zip
	  rm latest.zip

	  restart_ldnmp


	  ldnmp_web_on
	  echo "数据库地址: mysql"
	  echo "数据库名: $dbname"
	  echo "用户名: $dbuse"
	  echo "密码: $dbusepasswd"
	  echo "表前缀: discuz_"


		;;

	  4)
	  clear
	  # 可道云桌面
	  webname="可道云桌面"
	  send_stats "安装$webname"
	  ldnmp_install_status
	  add_yuming
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/kdy.com.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming
	  wget -O latest.zip ${gh_proxy}https://github.com/kalcaddle/kodbox/archive/refs/tags/1.50.02.zip
	  unzip -o latest.zip
	  rm latest.zip
	  mv /home/web/html/$yuming/kodbox* /home/web/html/$yuming/kodbox
	  restart_ldnmp

	  ldnmp_web_on
	  echo "数据库地址: mysql"
	  echo "用户名: $dbuse"
	  echo "密码: $dbusepasswd"
	  echo "数据库名: $dbname"
	  echo "redis主机: redis"

		;;

	  5)
	  clear
	  # 苹果CMS
	  webname="苹果CMS"
	  send_stats "安装$webname"
	  ldnmp_install_status
	  add_yuming
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/maccms.com.conf

	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming
	  # wget ${gh_proxy}https://github.com/magicblack/maccms_down/raw/master/maccms10.zip && unzip maccms10.zip && rm maccms10.zip
	  wget ${gh_proxy}https://github.com/magicblack/maccms_down/raw/master/maccms10.zip && unzip maccms10.zip && mv maccms10-*/* . && rm -r maccms10-* && rm maccms10.zip
	  cd /home/web/html/$yuming/template/ && wget ${gh_proxy}https://github.com/zaixiangjian/Website_source_code/raw/main/DYXS2.zip && unzip DYXS2.zip && rm /home/web/html/$yuming/template/DYXS2.zip
	  cp /home/web/html/$yuming/template/DYXS2/asset/admin/Dyxs2.php /home/web/html/$yuming/application/admin/controller
	  cp /home/web/html/$yuming/template/DYXS2/asset/admin/dycms.html /home/web/html/$yuming/application/admin/view/system
	  mv /home/web/html/$yuming/admin.php /home/web/html/$yuming/vip.php && wget -O /home/web/html/$yuming/application/extra/maccms.php ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/Website_source_code/main/maccms.php

	  restart_ldnmp


	  ldnmp_web_on
	  echo "数据库地址: mysql"
	  echo "数据库端口: 3306"
	  echo "数据库名: $dbname"
	  echo "用户名: $dbuse"
	  echo "密码: $dbusepasswd"
	  echo "数据库前缀: mac_"
	  echo "------------------------"
	  echo "安装成功后登录后台地址"
	  echo "https://$yuming/vip.php"

		;;

	  6)
	  clear
	  # 独脚数卡
	  webname="独脚数卡"
	  send_stats "安装$webname"
	  ldnmp_install_status
	  add_yuming
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/dujiaoka.com.conf

	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming
	  wget ${gh_proxy}https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz && tar -zxvf 2.0.6-antibody.tar.gz && rm 2.0.6-antibody.tar.gz

	  restart_ldnmp


	  ldnmp_web_on
	  echo "数据库地址: mysql"
	  echo "数据库端口: 3306"
	  echo "数据库名: $dbname"
	  echo "用户名: $dbuse"
	  echo "密码: $dbusepasswd"
	  echo ""
	  echo "redis地址: redis"
	  echo "redis密码: 默认不填写"
	  echo "redis端口: 6379"
	  echo ""
	  echo "网站url: https://$yuming"
	  echo "后台登录路径: /admin"
	  echo "------------------------"
	  echo "用户名: admin"
	  echo "密码: admin"
	  echo "------------------------"
	  echo "登录时右上角如果出现红色error0请使用如下命令: "
	  echo "我也很气愤独角数卡为啥这么麻烦，会有这样的问题！"
	  echo "sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/g' /home/web/html/$yuming/dujiaoka/.env"

		;;

	  7)
	  clear
	  # flarum论坛
	  webname="flarum论坛"
	  send_stats "安装$webname"
	  ldnmp_install_status
	  add_yuming
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/flarum.com.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming

	  docker exec php sh -c "php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\""
	  docker exec php sh -c "php composer-setup.php"
	  docker exec php sh -c "php -r \"unlink('composer-setup.php');\""
	  docker exec php sh -c "mv composer.phar /usr/local/bin/composer"

	  docker exec php composer create-project flarum/flarum /var/www/html/$yuming
	  docker exec php sh -c "cd /var/www/html/$yuming && composer require flarum-lang/chinese-simplified"
	  docker exec php sh -c "cd /var/www/html/$yuming && composer require fof/polls"

	  restart_ldnmp


	  ldnmp_web_on
	  echo "数据库地址: mysql"
	  echo "数据库名: $dbname"
	  echo "用户名: $dbuse"
	  echo "密码: $dbusepasswd"
	  echo "表前缀: flarum_"
	  echo "管理员信息自行设置"

		;;

	  8)
	  clear
	  # typecho
	  webname="typecho"
	  send_stats "安装$webname"
	  ldnmp_install_status
	  add_yuming
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/typecho.com.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming
	  wget -O latest.zip ${gh_proxy}https://github.com/typecho/typecho/releases/latest/download/typecho.zip
	  unzip latest.zip
	  rm latest.zip

	  restart_ldnmp


	  clear
	  ldnmp_web_on
	  echo "数据库前缀: typecho_"
	  echo "数据库地址: mysql"
	  echo "用户名: $dbuse"
	  echo "密码: $dbusepasswd"
	  echo "数据库名: $dbname"

		;;

	  20)
	  clear
	  webname="PHP动态站点"
	  send_stats "安装$webname"
	  ldnmp_install_status
	  add_yuming
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/index_php.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming

	  clear
	  echo -e "[${gl_huang}1/6${gl_bai}] 上传PHP源码"
	  echo "-------------"
	  echo "目前只允许上传zip格式的源码包，请将源码包放到/home/web/html/${yuming}目录下"
	  read -e -p "也可以输入下载链接，远程下载源码包，直接回车将跳过远程下载： " url_download

	  if [ -n "$url_download" ]; then
		  wget "$url_download"
	  fi

	  unzip $(ls -t *.zip | head -n 1)
	  rm -f $(ls -t *.zip | head -n 1)

	  clear
	  echo -e "[${gl_huang}2/6${gl_bai}] index.php所在路径"
	  echo "-------------"
	  find "$(realpath .)" -name "index.php" -print

	  read -e -p "请输入index.php的路径，类似（/home/web/html/$yuming/wordpress/）： " index_lujing

	  sed -i "s#root /var/www/html/$yuming/#root $index_lujing#g" /home/web/conf.d/$yuming.conf
	  sed -i "s#/home/web/#/var/www/#g" /home/web/conf.d/$yuming.conf

	  clear
	  echo -e "[${gl_huang}3/6${gl_bai}] 请选择PHP版本"
	  echo "-------------"
	  read -e -p "1. php最新版 | 2. php7.4 : " pho_v
	  case "$pho_v" in
		1)
		  sed -i "s#php:9000#php:9000#g" /home/web/conf.d/$yuming.conf
		  PHP_Version="php"
		  ;;
		2)
		  sed -i "s#php:9000#php74:9000#g" /home/web/conf.d/$yuming.conf
		  PHP_Version="php74"
		  ;;
		*)
		  echo "无效的选择，请重新输入。"
		  ;;
	  esac


	  clear
	  echo -e "[${gl_huang}4/6${gl_bai}] 安装指定扩展"
	  echo "-------------"
	  echo "已经安装的扩展"
	  docker exec php php -m

	  read -e -p "$(echo -e "输入需要安装的扩展名称，如 ${gl_huang}SourceGuardian imap ftp${gl_bai} 等等。直接回车将跳过安装 ： ")" php_extensions
	  if [ -n "$php_extensions" ]; then
		  docker exec $PHP_Version install-php-extensions $php_extensions
	  fi


	  clear
	  echo -e "[${gl_huang}5/6${gl_bai}] 编辑站点配置"
	  echo "-------------"
	  echo "按任意键继续，可以详细设置站点配置，如伪静态等内容"
	  read -n 1 -s -r -p ""
	  install nano
	  nano /home/web/conf.d/$yuming.conf


	  clear
	  echo -e "[${gl_huang}6/6${gl_bai}] 数据库管理"
	  echo "-------------"
	  read -e -p "1. 我搭建新站        2. 我搭建老站有数据库备份： " use_db
	  case $use_db in
		  1)
			  echo
			  ;;
		  2)
			  echo "数据库备份必须是.gz结尾的压缩包。请放到/home/目录下，支持宝塔/1panel备份数据导入。"
			  read -e -p "也可以输入下载链接，远程下载备份数据，直接回车将跳过远程下载： " url_download_db

			  cd /home/
			  if [ -n "$url_download_db" ]; then
				  wget "$url_download_db"
			  fi
			  gunzip $(ls -t *.gz | head -n 1)
			  latest_sql=$(ls -t *.sql | head -n 1)
			  dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
			  docker exec -i mysql mysql -u root -p"$dbrootpasswd" $dbname < "/home/$latest_sql"
			  echo "数据库导入的表数据"
			  docker exec -i mysql mysql -u root -p"$dbrootpasswd" -e "USE $dbname; SHOW TABLES;"
			  rm -f *.sql
			  echo "数据库导入完成"
			  ;;
		  *)
			  echo
			  ;;
	  esac

	  restart_ldnmp

	  ldnmp_web_on
	  prefix="web$(shuf -i 10-99 -n 1)_"
	  echo "数据库地址: mysql"
	  echo "数据库名: $dbname"
	  echo "用户名: $dbuse"
	  echo "密码: $dbusepasswd"
	  echo "表前缀: $prefix"
	  echo "管理员登录信息自行设置"

		;;


	  21)
	  send_stats "安装nginx环境"
	  root_use
	  ldnmp_install_status_one
	  check_port
	  install_dependency
	  install_docker
	  install_certbot

	  install_ldnmp_conf
	  nginx_upgrade

	  clear
	  nginx_version=$(docker exec nginx nginx -v 2>&1)
	  nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
	  echo "nginx已安装完成"
	  echo -e "当前版本: ${gl_huang}v$nginx_version${gl_bai}"
	  echo ""
		;;

	  22)
	  clear
	  webname="站点重定向"
	  send_stats "安装$webname"
	  nginx_install_status
	  ip_address
	  add_yuming
	  read -e -p "请输入跳转域名: " reverseproxy

	  install_ssltls
	  certs_status

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/rewrite.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  sed -i "s/baidu.com/$reverseproxy/g" /home/web/conf.d/$yuming.conf

	  docker restart nginx

	  nginx_web_on


		;;

	  23)
	  clear
	  webname="反向代理-IP+端口"
	  send_stats "安装$webname"
	  nginx_install_status
	  ip_address
	  add_yuming
	  read -e -p "请输入你的反代IP（回车默认host.docker.internal）: " reverseproxy
	  reverseproxy=${reverseproxy:-host.docker.internal}
	  read -e -p "请输入你的反代端口（本地端口）: " port

	  install_ssltls
	  certs_status

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/reverse-proxy.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  sed -i "s/0.0.0.0/$reverseproxy/g" /home/web/conf.d/$yuming.conf
	  sed -i "s/0000/$port/g" /home/web/conf.d/$yuming.conf

	  docker restart nginx

	  nginx_web_on

		;;

	  24)
	  clear
	  webname="反向代理-域名"
	  send_stats "安装$webname"
	  nginx_install_status
	  ip_address
	  add_yuming
	  echo -e "域名格式: ${gl_huang}google.com${gl_bai}"
	  read -e -p "请输入你的反代域名: " fandai_yuming

	  install_ssltls
	  certs_status

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/reverse-proxy-domain.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  sed -i "s|fandaicom|$fandai_yuming|g" /home/web/conf.d/$yuming.conf

	  docker restart nginx

	  nginx_web_on

		;;


	  25)
	  clear
	  webname="静态站点"
	  send_stats "安装$webname"
	  nginx_install_status
	  add_yuming
	  install_ssltls
	  certs_status

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/html.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming


	  clear
	  echo -e "[${gl_huang}1/2${gl_bai}] 上传静态源码"
	  echo "-------------"
	  echo "目前只允许上传zip格式的源码包，请将源码包放到/home/web/html/${yuming}目录下"
	  read -e -p "也可以输入下载链接，远程下载源码包，直接回车将跳过远程下载： " url_download

	  if [ -n "$url_download" ]; then
		  wget "$url_download"
	  fi

	  unzip $(ls -t *.zip | head -n 1)
	  rm -f $(ls -t *.zip | head -n 1)

	  clear
	  echo -e "[${gl_huang}2/2${gl_bai}] index.html所在路径"
	  echo "-------------"
	  find "$(realpath .)" -name "index.html" -print

	  read -e -p "请输入index.html的路径，类似（/home/web/html/$yuming/index/）： " index_lujing

	  sed -i "s#root /var/www/html/$yuming/#root $index_lujing#g" /home/web/conf.d/$yuming.conf
	  sed -i "s#/home/web/#/var/www/#g" /home/web/conf.d/$yuming.conf

	  docker exec nginx chmod -R 777 /var/www/html
	  docker restart nginx

	  nginx_web_on

		;;


	  26)
	  clear
	  webname="Bitwarden"
	  send_stats "安装$webname"
	  nginx_install_status
	  add_yuming
	  install_ssltls
	  certs_status

	  docker run -d \
		--name bitwarden \
		--restart always \
		-p 3280:80 \
		-v /home/web/html/$yuming/bitwarden/data:/data \
		vaultwarden/server
	  duankou=3280
	  reverse_proxy

	  nginx_web_on

		;;

	  27)
	  clear
	  webname="halo"
	  send_stats "安装$webname"
	  nginx_install_status
	  add_yuming
	  install_ssltls
	  certs_status

	  docker run -d --name halo --restart always -p 8010:8090 -v /home/web/html/$yuming/.halo2:/root/.halo2 halohub/halo:2
	  duankou=8010
	  reverse_proxy

	  nginx_web_on

		;;



	31)
	root_use
	while true; do
		clear
		send_stats "LDNMP站点管理"
		echo "LDNMP环境"
		echo "------------------------"
		ldnmp_v

		# ls -t /home/web/conf.d | sed 's/\.[^.]*$//'
		echo "站点信息                      证书到期时间"
		echo "------------------------"
		for cert_file in /home/web/certs/*_cert.pem; do
		  domain=$(basename "$cert_file" | sed 's/_cert.pem//')
		  if [ -n "$domain" ]; then
			expire_date=$(openssl x509 -noout -enddate -in "$cert_file" | awk -F'=' '{print $2}')
			formatted_date=$(date -d "$expire_date" '+%Y-%m-%d')
			printf "%-30s%s\n" "$domain" "$formatted_date"
		  fi
		done

		echo "------------------------"
		echo ""
		echo "数据库信息"
		echo "------------------------"
		dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
		docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SHOW DATABASES;" 2> /dev/null | grep -Ev "Database|information_schema|mysql|performance_schema|sys"

		echo "------------------------"
		echo ""
		echo "站点目录"
		echo "------------------------"
		echo -e "数据 ${hui}/home/web/html${gl_bai}     证书 ${hui}/home/web/certs${gl_bai}     配置 ${hui}/home/web/conf.d${gl_bai}"
		echo "------------------------"
		echo ""
		echo "操作"
		echo "------------------------"
		echo "1. 申请/更新域名证书               2. 更换站点域名"
		echo "3. 清理站点缓存                    4. 查看站点分析报告"
		echo "5. 编辑全局配置                    6. 编辑站点配置"
		echo "------------------------"
		echo "7. 删除指定站点                    8. 删除指定数据库"
		echo "------------------------"
		echo "0. 返回上一级选单"
		echo "------------------------"
		read -e -p "请输入你的选择: " sub_choice
		case $sub_choice in
			1)
				send_stats "申请域名证书"
				read -e -p "请输入你的域名: " yuming
				install_certbot
				install_ssltls
				certs_status

				;;

			2)
				send_stats "更换站点域名"
				echo -e "${gl_hong}强烈建议: ${gl_bai}先备份好全站数据再更换站点域名！"
				read -e -p "请输入旧域名: " oddyuming
				read -e -p "请输入新域名: " yuming
				install_certbot
				install_ssltls
				certs_status

				# mysql替换
				add_db

				odd_dbname=$(echo "$oddyuming" | sed -e 's/[^A-Za-z0-9]/_/g')
				odd_dbname="${odd_dbname}"

				docker exec mysql mysqldump -u root -p"$dbrootpasswd" $odd_dbname | docker exec -i mysql mysql -u root -p"$dbrootpasswd" $dbname
				docker exec mysql mysql -u root -p"$dbrootpasswd" -e "DROP DATABASE $odd_dbname;"


				tables=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -D $dbname -e "SHOW TABLES;" | awk '{ if (NR>1) print $1 }')
				for table in $tables; do
					columns=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -D $dbname -e "SHOW COLUMNS FROM $table;" | awk '{ if (NR>1) print $1 }')
					for column in $columns; do
						docker exec mysql mysql -u root -p"$dbrootpasswd" -D $dbname -e "UPDATE $table SET $column = REPLACE($column, '$oddyuming', '$yuming') WHERE $column LIKE '%$oddyuming%';"
					done
				done

				# docker exec mysql mysql -u root -p"$dbrootpasswd" -D $dbname -e "
				# UPDATE wp_options SET option_value = replace(option_value, '$oddyuming', '$yuming') WHERE option_name = 'home' OR option_name = 'siteurl';
				# UPDATE wp_posts SET guid = replace(guid, '$oddyuming', '$yuming');
				# UPDATE wp_posts SET post_content = replace(post_content, '$oddyuming', '$yuming');
				# UPDATE wp_postmeta SET meta_value = replace(meta_value,'$oddyuming', '$yuming');
				# "


				# 网站目录替换
				mv /home/web/html/$oddyuming /home/web/html/$yuming
				# sed -i "s/$odd_dbname/$dbname/g" /home/web/html/$yuming/wordpress/wp-config.php
				# sed -i "s/$oddyuming/$yuming/g" /home/web/html/$yuming/wordpress/wp-config.php

				find /home/web/html/$yuming -type f -exec sed -i "s/$odd_dbname/$dbname/g" {} +
				find /home/web/html/$yuming -type f -exec sed -i "s/$oddyuming/$yuming/g" {} +

				mv /home/web/conf.d/$oddyuming.conf /home/web/conf.d/$yuming.conf
				sed -i "s/$oddyuming/$yuming/g" /home/web/conf.d/$yuming.conf

				rm /home/web/certs/${oddyuming}_key.pem
				rm /home/web/certs/${oddyuming}_cert.pem

				docker restart nginx

				;;


			3)
				web_cache
				;;
			4)
				send_stats "查看站点数据"
				install goaccess
				goaccess --log-format=COMBINED /home/web/log/nginx/access.log

				;;

			5)
				send_stats "编辑全局配置"
				install nano
				nano /home/web/nginx.conf
				docker restart nginx
				;;

			6)
				send_stats "编辑站点配置"
				read -e -p "编辑站点配置，请输入你要编辑的域名: " yuming
				install nano
				nano /home/web/conf.d/$yuming.conf
				docker restart nginx
				;;

			7)
				send_stats "删除站点数据目录"
				read -e -p "删除站点数据目录，请输入你的域名: " yuming
				rm -r /home/web/html/$yuming
				rm /home/web/conf.d/$yuming.conf
				rm /home/web/certs/${yuming}_key.pem
				rm /home/web/certs/${yuming}_cert.pem
				docker restart nginx
				;;
			8)
				send_stats "删除站点数据库"
				read -e -p "删除站点数据库，请输入数据库名: " shujuku
				dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
				docker exec mysql mysql -u root -p"$dbrootpasswd" -e "DROP DATABASE $shujuku;" 2> /dev/null
				;;
			0)
				break  # 跳出循环，退出菜单
				;;
			*)
				break  # 跳出循环，退出菜单
				;;
		esac
	done

	  ;;


	32)
	  clear
	  send_stats "LDNMP环境备份"

	  backup_filename="web_$(date +"%Y%m%d%H%M%S").tar.gz"
	  echo -e "${gl_huang}正在备份 $backup_filename ...${gl_bai}"
	  cd /home/ && tar czvf "$backup_filename" web

	  while true; do
		clear
		echo "备份文件已创建: /home/$backup_filename"
		read -e -p "要传送备份数据到远程服务器吗？(Y/N): " choice
		case "$choice" in
		  [Yy])
			read -e -p "请输入远端服务器IP:  " remote_ip
			if [ -z "$remote_ip" ]; then
			  echo "错误: 请输入远端服务器IP。"
			  continue
			fi
			latest_tar=$(ls -t /home/*.tar.gz | head -1)
			if [ -n "$latest_tar" ]; then
			  ssh-keygen -f "/root/.ssh/known_hosts" -R "$remote_ip"
			  sleep 2  # 添加等待时间
			  scp -o StrictHostKeyChecking=no "$latest_tar" "root@$remote_ip:/home/"
			  echo "文件已传送至远程服务器home目录。"
			else
			  echo "未找到要传送的文件。"
			fi
			break
			;;
		  [Nn])
			break
			;;
		  *)
			echo "无效的选择，请输入 Y 或 N。"
			;;
		esac
	  done
	  ;;

	33)
	  clear
	  send_stats "定时远程备份"
	  read -e -p "输入远程服务器IP: " useip
	  read -e -p "输入远程服务器密码: " usepasswd

	  cd ~
	  wget -O ${useip}_beifen.sh ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/beifen.sh > /dev/null 2>&1
	  chmod +x ${useip}_beifen.sh

	  sed -i "s/0.0.0.0/$useip/g" ${useip}_beifen.sh
	  sed -i "s/123456/$usepasswd/g" ${useip}_beifen.sh

	  echo "------------------------"
	  echo "1. 每周备份                 2. 每天备份"
	  read -e -p "请输入你的选择: " dingshi

	  case $dingshi in
		  1)
			  check_crontab_installed
			  read -e -p "选择每周备份的星期几 (0-6，0代表星期日): " weekday
			  (crontab -l ; echo "0 0 * * $weekday ./${useip}_beifen.sh") | crontab - > /dev/null 2>&1
			  ;;
		  2)
			  check_crontab_installed
			  read -e -p "选择每天备份的时间（小时，0-23）: " hour
			  (crontab -l ; echo "0 $hour * * * ./${useip}_beifen.sh") | crontab - > /dev/null 2>&1
			  ;;
		  *)
			  break  # 跳出
			  ;;
	  esac

	  install sshpass

	  ;;


	34)
	  root_use
	  send_stats "LDNMP环境还原"
	  local restore_mode
	  while true; do
		  if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then clear; fi
		  echo "=================================="
		  echo "        备份恢复管理"
		  echo "=================================="
		  echo "1. 还原数据并安装LDNMP环境"
		  echo "自动安装所需环境时间可能较长"
		  echo "=================================="
		  echo "2. 只解压不安装环境"
		  echo "直接解压不安装环境"
		  echo "=================================="
		  echo "0.   返回主菜单"
		  echo "------------------------"
		  if ! IFS= read -r -e -p "请输入你的选择: " restore_mode; then
			  restore_mode=0
			  break
		  fi
		  case "$restore_mode" in
			  1|2|0) break ;;
			  *) echo "输入无效，请输入 1、2 或 0。"; break_end ;;
		  esac
	  done
	  [ "$restore_mode" == "0" ] && continue
	  echo "可用的站点备份"
	  echo "-------------------------"
	  local -a ldnmp_backups=()
	  local backup_index backup_choice backup_count
	  mapfile -d '' -t ldnmp_backups < <(
		  find /home -maxdepth 1 -type f -name '*.tar.gz' -printf '%T@ %p\0' 2>/dev/null |
		  sort -z -nr | cut -z -d ' ' -f2-
	  )
	  backup_count=${#ldnmp_backups[@]}
	  if [ "$backup_count" -eq 0 ]; then
		  echo "没有找到压缩包。"
		  break_end
		  continue
	  fi
	  for ((backup_index=0; backup_index<backup_count; backup_index++)); do
		  printf '%d. %s\n' "$((backup_index + 1))" "${ldnmp_backups[backup_index]##*/}"
	  done
	  echo ""
	  filename=""
	  while true; do
		  if ! IFS= read -r -e -p "回车键还原最新的备份，请选择需要恢复的备份，输入0退出：" backup_choice; then
			  break
		  fi
		  [ "$backup_choice" == "0" ] && break
		  backup_choice=${backup_choice:-1}
		  if [[ "$backup_choice" =~ ^[1-9][0-9]*$ ]] &&
			 [ "${#backup_choice}" -le "${#backup_count}" ] &&
			 [ "$backup_choice" -le "$backup_count" ]; then
			  filename=${ldnmp_backups[backup_choice-1]}
			  break
		  fi
		  echo "输入无效，请输入 1-${backup_count} 之间的备份序号，或输入0退出。"
	  done
	  if [ -z "$filename" ]; then
		  continue
	  fi

	  if [ "$restore_mode" == "2" ]; then
		  echo "仅解压到 /home/，同名文件会被覆盖；不会停止容器或安装环境。"
		  echo -e "${gl_huang}正在解压 $filename ...${gl_bai}"
		  if (cd /home/ && tar -xzf "$filename"); then
			  echo "解压完成，未安装或启动LDNMP环境。"
		  else
			  echo "解压失败，请检查备份文件及上方错误。"
		  fi
		  break_end
		  continue
	  fi

	  if [ -n "$filename" ]; then
		  cd /home/web/ > /dev/null 2>&1
		  docker compose down > /dev/null 2>&1
		  rm -rf /home/web > /dev/null 2>&1

		  echo -e "${gl_huang}正在解压 $filename ...${gl_bai}"
		  cd /home/ && tar -xzf "$filename"

		  check_port
		  install_dependency
		  install_docker
		  install_certbot
		  echo "还原全站数据会使用备份中的 MySQL 数据目录，建议选择与备份创建时相同的 MySQL 主版本。"
		  ldnmp_select_versions || { echo "已取消环境版本选择。"; break; }
		  ldnmp_apply_versions
		  install_ldnmp || { echo "环境配置失败，请检查上方错误。"; break; }
		  nginx_upgrade || echo "nginx 更新/检测失败，请稍后单独执行 37 → 1. 更新nginx 查看详细错误。"
	  else
		  echo "没有找到压缩包。"
	  fi

	  ;;

	35)
	  send_stats "LDNMP环境防御"
	  while true; do
		if docker inspect fail2ban &>/dev/null ; then

			  clear
			  echo "服务器防御程序已启动"
			  echo "------------------------"
			  echo "1. 开启SSH防暴力破解              2. 关闭SSH防暴力破解"
			  echo "3. 开启网站保护                   4. 关闭网站保护"
			  echo "------------------------"
			  echo "5. 查看SSH拦截记录                6. 查看网站拦截记录"
			  echo "7. 查看防御规则列表               8. 查看日志实时监控"
			  echo "------------------------"
			  echo "11. 配置拦截参数"
			  echo "------------------------"
			  echo "21. cloudflare模式                22. 高负载开启5秒盾"
			  echo "------------------------"
			  echo "9. 卸载防御程序"
			  echo "------------------------"
			  echo "0. 退出"
			  echo "------------------------"
			  read -e -p "请输入你的选择: " sub_choice
			  case $sub_choice in
				  1)
					  sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf
					  sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/linux-ssh.conf
					  sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/centos-ssh.conf
					  f2b_status
					  ;;
				  2)
					  sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf
					  sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/linux-ssh.conf
					  sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/centos-ssh.conf
					  f2b_status
					  ;;
				  3)
					  sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
					  f2b_status
					  ;;
				  4)
					  sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
					  f2b_status
					  ;;
				  5)
					  echo "------------------------"
					  f2b_sshd
					  echo "------------------------"
					  ;;
				  6)

					  echo "------------------------"
					  xxx=fail2ban-nginx-cc
					  f2b_status_xxx
					  echo "------------------------"
					  xxx=docker-nginx-bad-request
					  f2b_status_xxx
					  echo "------------------------"
					  xxx=docker-nginx-botsearch
					  f2b_status_xxx
					  echo "------------------------"
					  xxx=docker-nginx-http-auth
					  f2b_status_xxx
					  echo "------------------------"
					  xxx=docker-nginx-limit-req
					  f2b_status_xxx
					  echo "------------------------"
					  xxx=docker-php-url-fopen
					  f2b_status_xxx
					  echo "------------------------"

					  ;;

				  7)
					  docker exec -it fail2ban fail2ban-client status
					  ;;
				  8)
					  tail -f /path/to/fail2ban/config/log/fail2ban/fail2ban.log

					  ;;
				  9)
					  docker rm -f fail2ban
					  rm -rf /path/to/fail2ban
					  crontab -l | grep -v "CF-Under-Attack.sh" | crontab - 2>/dev/null
					  echo "Fail2Ban防御程序已卸载"
					  break
					  ;;

				  11)
					  install nano
					  nano /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
					  f2b_status

					  break
					  ;;
				  21)
					  send_stats "cloudflare模式"
					  echo "到cf后台右上角我的个人资料，选择左侧API令牌，获取Global API Key"
					  echo "https://dash.cloudflare.com/login"
					  read -e -p "输入CF的账号: " cfuser
					  read -e -p "输入CF的Global API Key: " cftoken

					  wget -O /home/web/conf.d/default.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/default11.conf
					  docker restart nginx

					  cd /path/to/fail2ban/config/fail2ban/jail.d/
					  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/config/main/fail2ban/nginx-docker-cc.conf

					  cd /path/to/fail2ban/config/fail2ban/action.d
					  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/config/main/fail2ban/cloudflare-docker.conf

					  sed -i "@outlook.com/$cfuser/g" /path/to/fail2ban/config/fail2ban/action.d/cloudflare-docker.conf
					  sed -i "s/APIKEY00000/$cftoken/g" /path/to/fail2ban/config/fail2ban/action.d/cloudflare-docker.conf
					  f2b_status

					  echo "已配置cloudflare模式，可在cf后台，站点-安全性-事件中查看拦截记录"
					  ;;

				  22)
					  send_stats "高负载开启5秒盾"
					  echo -e "${gl_huang}网站每5分钟自动检测，当达检测到高负载会自动开盾，低负载也会自动关闭5秒盾。${gl_bai}"
					  echo "--------------"
					  echo "获取CF参数: "
					  echo -e "到cf后台右上角我的个人资料，选择左侧API令牌，获取${gl_huang}Global API Key${gl_bai}"
					  echo -e "到cf后台域名概要页面右下方获取${gl_huang}区域ID${gl_bai}"
					  echo "https://dash.cloudflare.com/login"
					  echo "--------------"
					  read -e -p "输入CF的账号: " cfuser
					  read -e -p "输入CF的Global API Key: " cftoken
					  read -e -p "输入CF中域名的区域ID: " cfzonID

					  cd ~
					  install jq bc
					  check_crontab_installed
					  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/CF-Under-Attack.sh
					  chmod +x CF-Under-Attack.sh
					  sed -i "s/AAAA/$cfuser/g" ~/CF-Under-Attack.sh
					  sed -i "s/BBBB/$cftoken/g" ~/CF-Under-Attack.sh
					  sed -i "s/CCCC/$cfzonID/g" ~/CF-Under-Attack.sh

					  cron_job="*/5 * * * * ~/CF-Under-Attack.sh"

					  existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

					  if [ -z "$existing_cron" ]; then
						  (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
						  echo "高负载自动开盾脚本已添加"
					  else
						  echo "自动开盾脚本已存在，无需添加"
					  fi

					  ;;
				  0)
					  break
					  ;;
				  *)
					  echo "无效的选择，请重新输入。"
					  ;;
			  esac
		elif [ -x "$(command -v fail2ban-client)" ] ; then
			clear
			echo "卸载旧版fail2ban"
			read -e -p "确定继续吗？(Y/N): " choice
			case "$choice" in
			  [Yy])
				remove fail2ban
				rm -rf /etc/fail2ban
				echo "Fail2Ban防御程序已卸载"
				;;
			  [Nn])
				echo "已取消"
				;;
			  *)
				echo "无效的选择，请输入 Y 或 N。"
				;;
			esac

		else
			clear
			install_docker


			wget -O /home/web/nginx.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/nginx10.conf
			wget -O /home/web/conf.d/default.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/default10.conf
			default_server_ssl
			nginx_upgrade

			f2b_install_sshd
			cd /path/to/fail2ban/config/fail2ban/filter.d
			curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/fail2ban-nginx-cc.conf
			cd /path/to/fail2ban/config/fail2ban/jail.d/
			curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/config/main/fail2ban/nginx-docker-cc.conf
			sed -i "/cloudflare/d" /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf

			f2b_status
			cd ~

			echo "防御程序已开启"
		fi
	  break_end
	  done

		;;

	36)
		  while true; do
			  clear
			  send_stats "优化LDNMP环境"
			  echo "优化LDNMP环境"
			  echo "------------------------"
			  echo "1. 标准模式              2. 高性能模式 (推荐2H2G以上)"
			  echo "------------------------"
			  echo "0. 退出"
			  echo "------------------------"
			  read -e -p "请输入你的选择: " sub_choice
			  case $sub_choice in
				  1)
				  send_stats "站点标准模式"
				  # nginx调优
				  sed -i 's/worker_connections.*/worker_connections 1024;/' /home/web/nginx.conf

				  # php调优
				  wget -O /home/optimized_php.ini ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/optimized_php.ini
				  docker cp /home/optimized_php.ini php:/usr/local/etc/php/conf.d/optimized_php.ini
				  docker cp /home/optimized_php.ini php74:/usr/local/etc/php/conf.d/optimized_php.ini
				  rm -rf /home/optimized_php.ini

				  # php调优
				  wget -O /home/www.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/www-1.conf
				  docker cp /home/www.conf php:/usr/local/etc/php-fpm.d/www.conf
				  docker cp /home/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
				  rm -rf /home/www.conf

				  # mysql调优
				  wget -O /home/custom_mysql_config.cnf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/custom_mysql_config-1.cnf
				  docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
				  rm -rf /home/custom_mysql_config.cnf


				  cd /home/web && docker compose restart
				  docker exec -it redis redis-cli CONFIG SET maxmemory 512mb
				  docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru

				  echo "LDNMP环境已设置成 标准模式"

					  ;;
				  2)
				  send_stats "站点高性能模式"
				  # nginx调优
				  sed -i 's/worker_connections.*/worker_connections 10240;/' /home/web/nginx.conf

				  # php调优
				  wget -O /home/optimized_php.ini ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/optimized_php.ini
				  docker cp /home/optimized_php.ini php:/usr/local/etc/php/conf.d/optimized_php.ini
				  docker cp /home/optimized_php.ini php74:/usr/local/etc/php/conf.d/optimized_php.ini
				  rm -rf /home/optimized_php.ini

				  # php调优
				  wget -O /home/www.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/www.conf
				  docker cp /home/www.conf php:/usr/local/etc/php-fpm.d/www.conf
				  docker cp /home/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
				  rm -rf /home/www.conf

				  # mysql调优
				  wget -O /home/custom_mysql_config.cnf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/custom_mysql_config.cnf
				  docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
				  rm -rf /home/custom_mysql_config.cnf

				  cd /home/web && docker compose restart

				  docker exec -it redis redis-cli CONFIG SET maxmemory 1024mb
				  docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru

				  echo "LDNMP环境已设置成 高性能模式"

					  ;;
				  0)
					  break
					  ;;
				  *)
					  echo "无效的选择，请重新输入。"
					  ;;
			  esac
			  break_end

		  done
		;;


	37)
	  root_use
	  while true; do
		  clear
		  send_stats "更新LDNMP环境"
		  echo "更新LDNMP环境"
		  echo "------------------------"
		  ldnmp_v
		  ldnmp_show_default_versions
		  echo "1. 更新nginx               2. 更新mysql              3. 更新php              4. 更新redis"
		  echo "------------------------"
		  echo "5. 更新完整环境            6. 更新phpmyadmin"
		  echo "------------------------"
		  echo "0. 返回上一级"
		  echo "------------------------"
		  read -e -p "请输入你的选择: " sub_choice
		  case $sub_choice in
			  1)
			  if nginx_upgrade; then
				send_stats "更新$ldnmp_pods"
				echo "更新${ldnmp_pods}完成"
			  else
				echo "更新${ldnmp_pods}失败，请根据上方错误处理。"
			  fi

				  ;;

			  2)
			  ldnmp_pods="mysql"
			  read -e -p "请输入${ldnmp_pods}版本号 （如: ${ldnmp_default_mysql_version}）（回车默认${ldnmp_default_mysql_version}）: " version
			  version=${version:-$ldnmp_default_mysql_version}

			  cd /home/web/ || break
			  cp /home/web/docker-compose.yml /home/web/docker-compose1.yml
			  ldnmp_compose_set_image mysql "mysql:${version}" || { echo "修改 mysql 镜像失败"; cp /home/web/docker-compose1.yml /home/web/docker-compose.yml; break; }
			  docker compose pull $ldnmp_pods || { echo "mysql 镜像拉取失败"; cp /home/web/docker-compose1.yml /home/web/docker-compose.yml; break; }
			  # 按用户要求暂不限制 MySQL 降级，允许手动测试 8.4/9.x；失败时下面会提示查看日志。
			  docker compose up -d --force-recreate $ldnmp_pods
			  dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
			  if ! ldnmp_wait_mysql_ready "$dbrootpasswd"; then
				echo "mysql 启动失败/超时，未确认更新成功。"
				echo "请查看日志：docker logs --tail 120 mysql"
				cp /home/web/docker-compose1.yml /home/web/docker-compose.yml
				break
			  fi
			  cp /home/web/docker-compose1.yml /home/web/docker-compose.yml
			  send_stats "更新$ldnmp_pods"
			  echo "更新${ldnmp_pods}完成"

				  ;;
			  3)
			  ldnmp_pods="php"
			  read -e -p "请输入${ldnmp_pods}版本号 （如: 7.4 8.0 8.1 8.2 8.3 8.4 8.5）（回车默认${ldnmp_default_php_version}）: " version
			  version=${version:-$ldnmp_default_php_version}
			  ldnmp_select_ioncube || break
			  cd /home/web/ || break
			  cp /home/web/docker-compose.yml /home/web/docker-compose1.yml
			  php_image="php:${version}-fpm-alpine"
			  ldnmp_compose_set_image php "$php_image" || { echo "修改 php 镜像失败"; cp /home/web/docker-compose1.yml /home/web/docker-compose.yml; break; }
			  docker compose pull "$ldnmp_pods" || { echo "php 镜像拉取失败"; cp /home/web/docker-compose1.yml /home/web/docker-compose.yml; break; }
			  docker compose up -d --force-recreate "$ldnmp_pods" || { echo "php 容器重建失败；恢复旧 Compose 配置，但未确认运行容器回滚。"; cp /home/web/docker-compose1.yml /home/web/docker-compose.yml; break; }
			  ldnmp_configure_php_container php || { echo "PHP/ionCube 配置失败；保留当前镜像配置供修复，未确认更新完成。"; break; }
			  # 成功保留新 PHP 镜像版本，避免下次重建退回旧版本。
			  send_stats "更新$ldnmp_pods"
			  echo "更新${ldnmp_pods}完成"

				  ;;
			  4)
			  ldnmp_pods="redis"
			  cd /home/web/ || break
			  docker compose pull $ldnmp_pods
			  docker compose up -d --force-recreate $ldnmp_pods
			  ldnmp_set_redis_policy
			  docker restart $ldnmp_pods > /dev/null 2>&1
			  send_stats "更新$ldnmp_pods"
			  echo "更新${ldnmp_pods}完成"

				  ;;
			  5)
				read -e -p "$(echo -e "${gl_huang}提示: ${gl_bai}长时间不更新环境的用户，请慎重更新LDNMP环境，会有数据库更新失败的风险。确定更新LDNMP环境吗？(Y/N): ")" choice
				case "$choice" in
				  [Yy])
					send_stats "完整更新LDNMP环境"
					cd /home/web/
					docker compose down
					docker compose down --rmi all

					check_port
					install_dependency
					install_docker
					install_certbot
					echo "mysql:${ldnmp_default_mysql_version} 会跟随官方同分支补丁版本，例如 ${ldnmp_default_mysql_version}.x；不建议跨版本升级或降级。"
					ldnmp_select_versions || { echo "已取消环境版本选择。"; break; }
					ldnmp_apply_versions
					install_ldnmp || { echo "环境配置失败，请检查上方错误。"; break; }
					nginx_upgrade || echo "nginx 更新/检测失败，请稍后单独执行 1. 更新nginx 查看详细错误。"
					;;
				  *)
					;;
				esac
				  ;;

			  6)
			  phpmyadmin_upgrade
				  ;;

			  0)
				  break
				  ;;
			  *)
				  echo "无效的选择，请重新输入。"
				  ;;
		  esac
		  break_end
	  done


	  ;;

	38)
		root_use
		send_stats "卸载LDNMP环境"
		read -e -p "$(echo -e "${gl_hong}强烈建议：${gl_bai}先备份全部网站数据，再卸载LDNMP环境。确定删除所有网站数据吗？(Y/N): ")" choice
		case "$choice" in
		  [Yy])
			cd /home/web/
			docker compose down
			docker compose down --rmi all
			docker compose -f docker-compose.phpmyadmin.yml down > /dev/null 2>&1
			docker compose -f docker-compose.phpmyadmin.yml down --rmi all > /dev/null 2>&1
			rm -rf /home/web
			;;
		  [Nn])

			;;
		  *)
			echo "无效的选择，请输入 Y 或 N。"
			;;
		esac
		;;

	0)
		kejilion
	  ;;

	*)
		echo "无效的输入!"
	esac
	break_end

  done

}




# ===== 本地应用脚本更新逻辑 开始 =====
run_local_first_app_script() {
  local title="$1"
  local local_script="$2"
  local github_script="$3"
  local fallback_func="${4:-}"
  local tmp_script local_hash remote_hash local_version remote_version has_update="false" check_failed="false"

  clear
  echo "$title"
  mkdir -p "$(dirname "$local_script")"

  if [ ! -f "$local_script" ]; then
    echo "未检测到本地应用脚本，正在下载到: $local_script"
    if ! curl -fsSL "$github_script" -o "$local_script"; then
      echo "❌ GitHub脚本下载失败，请检查网络。"
      if [ -n "$fallback_func" ] && declare -F "$fallback_func" >/dev/null 2>&1; then
        "$fallback_func"
      else
        break_end
      fi
      return
    fi
    chmod +x "$local_script"
    bash "$local_script"
    return
  fi

  tmp_script="$(mktemp)" || check_failed="true"
  if [ "$check_failed" != "true" ] && ! curl -fsSL --connect-timeout 3 --max-time 6 "$github_script" -o "$tmp_script"; then
    check_failed="true"
  fi

  if [ "$check_failed" = "true" ]; then
    rm -f "$tmp_script" 2>/dev/null || true
    echo "------------------------------------------------"
    echo "GitHub是否有更新，本地保存目录"
    echo -e "${gl_hong}GitHub更新检测失败${gl_bai}"
    echo -e "${gl_lv}$local_script${gl_bai}"
    echo "------------------------------------------------"
    chmod +x "$local_script"
    bash "$local_script"
    return
  fi

  local_version="$(grep -m1 -E '^[[:space:]]*sh_v="[^"]+"' "$local_script" 2>/dev/null | sed -E 's/^[[:space:]]*sh_v="([^"]+)".*/\1/')"
  remote_version="$(grep -m1 -E '^[[:space:]]*sh_v="[^"]+"' "$tmp_script" 2>/dev/null | sed -E 's/^[[:space:]]*sh_v="([^"]+)".*/\1/')"
  local_hash="$(sha256sum "$local_script" 2>/dev/null | awk '{print $1}')"
  remote_hash="$(sha256sum "$tmp_script" 2>/dev/null | awk '{print $1}')"
  rm -f "$tmp_script"

  if [ -n "$local_version" ] || [ -n "$remote_version" ]; then
    [ -n "$local_version" ] && [ -n "$remote_version" ] && [ "$local_version" != "$remote_version" ] && has_update="true"
  elif [ -n "$local_hash" ] && [ -n "$remote_hash" ] && [ "$local_hash" != "$remote_hash" ]; then
    has_update="true"
  fi

  if [ "$has_update" != "true" ]; then
    echo "------------------------------------------------"
    echo "GitHub是否有更新，本地保存目录"
    [ -n "$local_version" ] || [ -n "$remote_version" ] && echo "当前版本：${local_version:-未知}" && echo "最新版本：${remote_version:-未知}"
    echo -e "${gl_lv}已是最新${gl_bai}"
    echo -e "${gl_lv}$local_script${gl_bai}"
    echo "------------------------------------------------"
    chmod +x "$local_script"
    bash "$local_script"
    return
  fi

  echo "------------------------------------------------"
  echo "GitHub是否有更新，本地保存目录"
  [ -n "$local_version" ] || [ -n "$remote_version" ] && echo "当前版本：${local_version:-未知}" && echo "最新版本：${remote_version:-未知}"
  echo -e "${gl_hong}有新内容${gl_bai}"
  echo -e "${gl_lv}$local_script${gl_bai}"
  echo "------------------------------------------------"
  echo "1.使用本地应用脚本"
  echo "2.使用GitHub更新脚本"
  echo "0. 返回上一级选单"
  echo "------------------------------------------------"
  local script_choice update_confirm
  read -e -p "请输入选项并回车（回车默认 1 ）: " script_choice
  script_choice=${script_choice:-1}
  case "$script_choice" in
    1)
      chmod +x "$local_script"
      bash "$local_script"
      ;;
    2)
      echo "使用GitHub更新将会覆盖本地文件"
      read -e -p "更新覆盖谨慎操作 (Y/N) [默认: N]: " update_confirm
      case "$update_confirm" in
        [Yy])
          curl -fsSL "$github_script" -o "$local_script" && chmod +x "$local_script" && bash "$local_script"
          ;;
        *)
          echo "已取消GitHub更新。"
          ;;
      esac
      ;;
    0)
      ;;
    *)
      echo "无效选项，已返回上一级选单。"
      ;;
  esac
}
# ===== 本地应用脚本更新逻辑 结束 =====

# ===== kejilion 主脚本更新检测逻辑 开始 =====
show_kejilion_update_status() {
  local github_script="${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/kejilion.sh"
  local tmp_script remote_version
  echo -e "${gl_kjlan}------------------------${gl_bai}"
  echo "GitHub是否有更新"
  tmp_script="$(mktemp)" || {
    echo -e "${gl_hong}GitHub更新检测失败${gl_bai}"
    return 1
  }
  if ! curl -fsSL --connect-timeout 3 --max-time 6 "$github_script" -o "$tmp_script"; then
    rm -f "$tmp_script"
    echo -e "${gl_hong}GitHub更新检测失败${gl_bai}"
    return 1
  fi
  remote_version="$(grep -m1 -E '^[[:space:]]*sh_v="[^"]+"' "$tmp_script" 2>/dev/null | sed -E 's/^[[:space:]]*sh_v="([^"]+)".*/\1/')"
  rm -f "$tmp_script"

  if [ -n "$remote_version" ] && [ "$remote_version" != "$sh_v" ]; then
    echo -e "${gl_hong}有新内容 请使用 00 更新${gl_bai}"
    return 0
  fi
  echo -e "${gl_lv}已是最新${gl_bai}"
  return 1
}
# ===== kejilion 主脚本更新检测逻辑 结束 =====


linux_panel() {
  while true; do
    clear
    # Docker 项按运行中容器检测；非 Docker 项沿用各自的安装/配置检测。
    declare -a installed_items=()
    # 一次读取容器名和镜像，供所有 Docker 项复用。
    local docker_container_list="" docker_container_records=""
    if command -v docker &>/dev/null; then
        docker_container_records="$(docker ps --filter status=running --format '{{.Names}}\t{{.Image}}' 2>/dev/null || true)"
        docker_container_list="$(printf '%s\n' "$docker_container_records" | cut -f1)"
    fi
    check_docker() {
        local num="$1"
        local container_name="$2"
        if [ -n "$docker_container_list" ] && echo "$docker_container_list" | grep -Fxq "$container_name"; then
            installed_items+=("$num")
        fi
    }
    check_path() {
        local num="$1"
        local path="$2"
        if [ -d "$path" ] || [ -f "$path" ]; then
            installed_items+=("$num")
        fi
    }
    check_cmd() {
        local num="$1"
        local cmd="$2"
        if command -v "$cmd" &>/dev/null; then
            installed_items+=("$num")
        fi
    }

    # 检测各项服务
    check_path "1" "/www/server/panel"
    if [ -d "/www/server/panel" ] && grep -q "aapanel" /www/server/panel/class/common.py 2>/dev/null; then installed_items+=("2"); fi
    check_cmd "3" "1pctl"
    check_docker "4" "npm"
    check_path "5" "/opt/nezha"
    check_docker "6" "webtop-ubuntu"
    check_path "7" "/opt/nezha/dashboard"
    check_docker "8" "qbittorrent"
    check_docker "9" "mailserver"
    check_docker "10" "rocketchat"
    check_docker "11" "zentao-server"
    check_docker "12" "qinglong"
    check_docker "13" "cloudreve"
    check_docker "14" "easyimage"
    check_docker "15" "emby"
    check_docker "16" "looking-glass"
    check_docker "17" "adguardhome"
    check_docker "18" "onlyoffice"
    check_docker "19" "safeline-mgt"
    check_docker "20" "portainer"
    check_docker "21" "vscode-web"
    check_docker "22" "uptime-kuma"
    check_docker "23" "memos"
    check_docker "24" "webtop"
    check_docker "25" "nextcloud-aio"
    check_docker "26" "qd"
    check_docker "27" "dockge"
    check_docker "28" "speedtest"
    check_docker "29" "searxng"
    check_docker "30" "photoprism"
    check_docker "31" "s-pdf"
    check_docker "32" "drawio"
    check_docker "33" "sun-panel"
    check_docker "34" "pingvin-share"
    check_docker "35" "moments"
    check_docker "36" "lobe-chat"
    check_docker "37" "myip"
    check_docker "38" "alist"
    check_docker "39" "bililive-go"
    check_docker "40" "windows"
    check_path "41" "/www/server/panel-haozi"
    # Vaultwarden 42/43/44/45 共用同一个容器名，按容器环境变量区分安装类型
    if [ -n "$docker_container_list" ] && echo "$docker_container_list" | grep -Fxq "vaultwarden"; then
        vaultwarden_env="$(docker inspect vaultwarden --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null || true)"
        if echo "$vaultwarden_env" | grep -qx 'SIGNUPS_ALLOWED=false'; then
            if echo "$vaultwarden_env" | grep -q '^SMTP_HOST='; then
                installed_items+=("43")
            else
                installed_items+=("44")
            fi
        elif echo "$vaultwarden_env" | grep -q '^SMTP_HOST='; then
            installed_items+=("45")
        else
            installed_items+=("42")
        fi
    fi
    check_docker "46" "aria2-pro"
    check_docker "48" "nexterm"
    check_docker "49" "vaultwarden"
    check_docker "50" "moontv"
    check_path "51" "/home/docker/jiguang"
	check_docker "53" "nexterm"
    check_docker "54" "webssh"
    if /bin/systemctl list-unit-files openlist.service 2>/dev/null | grep -q '^openlist\.service'; then
        installed_items+=("55")
    fi
    check_docker "56" "umami"
    check_docker "57" "dify"
    check_cmd "58" "caddy"
    check_docker "59" "hbbs"
    check_docker "60" "hbbr"
    check_path "62" "/usr/local/x-ui"
    check_docker "63" "rustfs"
    check_docker "64" "seaweedfs"
    check_docker "67" "owncloud"
    check_docker "68" "m38u8"
    check_docker "69" "it-tools"
    check_docker "70" "pansou"
    check_docker "71" "zfile"
    # Discourse 官方 launcher 默认容器名为 app，按镜像识别，不能仅匹配通用名称 app。
    if printf '%s\n' "$docker_container_list" | grep -Fxq 'discourse' ||
       printf '%s\n' "$docker_container_records" | awk -F '\t' '
         $2 ~ /^local_discourse\/[^\/:@]+([:@].*)?$/ { found=1 }
         END { exit !found }
       '; then
        installed_items+=("72")
    fi
    check_docker "73" "matrix-synapse-1"
    check_docker "74" "mattermost-mattermost-1"
    check_docker "75" "certimate"
    # 77/78 共用 Mailcow 部署；仅运行中的容器标绿，兼容 Compose v1/v2 容器名。
    if [ -n "$docker_container_list" ] && printf '%s\n' "$docker_container_list" | grep -Eq '^(mailcow|(((mailcow-dockerized|mailcowdockerized)[-_])?((nginx|postfix|dovecot|sogo|mysql|redis|rspamd|acme|php-fpm|watchdog|unbound|clamd|olefy|memcached|netfilter|dockerapi)-mailcow))([-_][0-9]+)?)$'; then
        installed_items+=("77" "78")
    fi
	check_docker "79" "nexterm"
    check_docker "84" "hitokoto"
    check_docker "85" "openlist-api-server"
    check_docker "86" "backrest"
    check_docker "87" "openlist"
    check_docker "88" "minio"
    check_docker "89" "nezha-dashboard"
    check_docker "90" "btc"
    check_docker "91" "chrome"
    check_docker "92" "cli-proxy-api"
    check_docker "93" "sub2api"
    check_path "94" "/root/.openclaw"
    check_docker "95" "open-webui"
    if [ -f "/home/myip.sh" ] || [ -f "/home/myip_db.txt" ] || crontab -l 2>/dev/null | grep -Fq "/home/myip.sh"; then
        installed_items+=("97")
    fi
    if [ -f "/home/jiancegoogle-telegram.sh" ] ||        [ -f "/home/jiancegoogle-Resend-email.sh" ] ||        [ -f "/home/jiancegoogle-smtp-email.sh" ] ||        [ -f "/home/jiancegoogle-qita-email.sh" ] ||        [ -f "/home/jiancegoogle-jingweidu-telegram.sh" ] ||        [ -f "/home/jiancegoogle-jingweidu-Resend-email.sh" ] ||        [ -f "/home/jiancegoogle-jingweidu-smtp-email.sh" ] ||        [ -f "/home/jiancegoogle-jingweidu-qita-email.sh" ] ||        crontab -l 2>/dev/null | grep -Eq 'jiancegoogle-(telegram|Resend-email|smtp-email|qita-email|jingweidu-telegram|jingweidu-Resend-email|jingweidu-smtp-email|jingweidu-qita-email)\.sh'; then
        installed_items+=("96")
    fi
    check_docker "98" "chromium"
    check_path "99" "/root/.hermes"
    check_docker "100" "lobehub"
    # agent-ai 是备份工具：仅下载脚本不算安装，至少配置一个远程目标才标记。
    if [ -f "/root/yingyong/agent-ai.d/agent-ai.sh" ]; then
        local agent_ai_config
        for agent_ai_config in /root/yingyong/agent-ai.d/*.conf; do
            [ -f "$agent_ai_config" ] || continue
            if grep -Eq "^REMOTE_HOST=['\"]?[^'\"[:space:]]+" "$agent_ai_config" && \
               grep -Eq "^REMOTE_USER=['\"]?[^'\"[:space:]]+" "$agent_ai_config"; then
                installed_items+=("101")
                break
            fi
        done
    fi
    check_docker "102" "epusdt"
    if { [ -n "$docker_container_list" ] && echo "$docker_container_list" | grep -Eq '^(epay-nginx|epay-php|epay-mysql)$'; }; then
        installed_items+=("103")
    fi
    check_docker "104" "acg-faka-app"
    check_docker "105" "dujiao-next"
    check_docker "106" "bepusdt"

    # 990 只按真实启用证据标记已安装：live 规则已生效，或 systemd 持久化恢复服务已启用且规则文件存在。
    # 不再仅凭 crontab 标记，避免旧 @reboot 残留导致菜单显示已安装但实际未启用。
    if { iptables -S KJ_APP_ALLOW >/dev/null 2>&1 && iptables -S INPUT 2>/dev/null | grep -q -- '-j KJ_APP_ALLOW'; } || \
       { command -v systemctl >/dev/null 2>&1 && \
         systemctl is-enabled kj-990-port-whitelist.service >/dev/null 2>&1 && \
         [ -x /usr/local/sbin/kj-990-port-whitelist-restore.sh ] && \
         [ -s /etc/iptables/rules.v4 ] && grep -q 'KJ_APP_ALLOW' /etc/iptables/rules.v4 2>/dev/null; }; then
        installed_items+=("990")
    fi
    check_docker "991" "fail2ban"
    if ! printf '%s
' "${installed_items[@]}" | grep -qx "991"; then
        if [ -f "/home/docker/fail2ban/notify/ssh-login-telegram.sh" ] ||            [ -f "/home/docker/fail2ban/notify/ssh-Resend-email-smtp.sh" ] ||            [ -f "/home/docker/fail2ban/notify/ssh-smtp-email-smtp.sh" ] ||            [ -f "/home/docker/fail2ban/notify/ssh-login-pam-alert.sh" ] ||            crontab -l 2>/dev/null | grep -Eq 'ssh-login-telegram|ssh-Resend-email-smtp|ssh-smtp-email-smtp|ssh-qita-email-smtp|ssh-login-pam-alert'; then
            installed_items+=("991")
        fi
    fi

    # 1004/1005 按编号接在 991 后；仅检测真实定时任务，不以下载文件/启用标记代替。
    local backup_menu_cron
    backup_menu_cron="$(crontab -l 2>/dev/null | LC_ALL=C grep -Ev '^[[:space:]]*(#|$)' | LC_ALL=C grep -E '^([[:space:]]*[^#[:space:]]+[[:space:]]+){5}|^[[:space:]]*@(reboot|yearly|annually|monthly|weekly|daily|midnight|hourly)[[:space:]]+' || true)"
    if [ -f '/home/备份/beifen.sh' ] && printf '%s\n' "$backup_menu_cron" | grep -Eq '(^|[[:space:]])(/bin/bash[[:space:]]+|bash[[:space:]]+)?/home/备份/beifen\.sh([[:space:]]|$)'; then
        installed_items+=("1004")
    fi
    if printf '%s\n' "$backup_menu_cron" | grep -Eq '(^|[[:space:]])/root/yingyong/beifenhebing-(web|forum|generated|local-sync|local-keep)\.py[[:space:]]+(check|scheduled-run)([[:space:]]|$)'; then
        installed_items+=("1005")
    fi

    panel_item_installed() {
        local num="$1"
        printf '%s
' "${installed_items[@]}" | grep -qx "$num"
    }
    # 命中检测条件时整项变绿，否则保留原样；不设置黄色停止状态。
    panel_menu_item_green_if_installed() {
        local num="$1"
        local normal_text="$2"
        local installed_text="$3"
        if panel_item_installed "$num"; then
            printf "%b" "${gl_lv}${installed_text}${gl_bai}"
        else
            printf "%b" "$normal_text"
        fi
    }

    echo -e "▶ 面板工具"
    echo -e "${gl_kjlan}------------------------"
    echo -e "$(panel_menu_item_green_if_installed 1 "${gl_kjlan}1. ${gl_bai}宝塔面板官方版" "1. 宝塔面板官方版")\033[48G$(panel_menu_item_green_if_installed 2 "${gl_kjlan}2. ${gl_bai}aaPanel宝塔国际版" "2. aaPanel宝塔国际版")"
    echo -e "$(panel_menu_item_green_if_installed 3 "${gl_kjlan}3. ${gl_bai}1Panel新一代管理面板" "3. 1Panel新一代管理面板")\033[48G$(panel_menu_item_green_if_installed 4 "${gl_kjlan}4. ${gl_bai}NginxProxyManager可视化面板" "4. NginxProxyManager可视化面板")"
    echo -e "$(panel_menu_item_green_if_installed 5 "${gl_kjlan}5. ${gl_bai}哪吒探针备份与恢复" "5. 哪吒探针备份与恢复")\033[48G$(panel_menu_item_green_if_installed 6 "${gl_kjlan}6. ${gl_bai}Ubuntu远程桌面网页版3006端口" "6. Ubuntu远程桌面网页版3006端口")"
    echo -e "$(panel_menu_item_green_if_installed 7 "${gl_kjlan}7. ${gl_bai}哪吒探针VPS监控面板" "7. 哪吒探针VPS监控面板")\033[48G$(panel_menu_item_green_if_installed 8 "${gl_kjlan}8. ${gl_bai}QB离线BT磁力下载面板" "8. QB离线BT磁力下载面板")"
    echo -e "$(panel_menu_item_green_if_installed 9 "${gl_kjlan}9. ${gl_bai}Poste.io邮件服务器程序" "9. Poste.io邮件服务器程序")\033[48G$(panel_menu_item_green_if_installed 10 "${gl_kjlan}10. ${gl_bai}RocketChat多人在线聊天系统" "10. RocketChat多人在线聊天系统")"
    echo -e "${gl_kjlan}------------------------"
    echo -e "$(panel_menu_item_green_if_installed 11 "${gl_kjlan}11. ${gl_bai}禅道项目管理软件" "11. 禅道项目管理软件")\033[48G$(panel_menu_item_green_if_installed 12 "${gl_kjlan}12. ${gl_bai}青龙面板定时任务管理平台" "12. 青龙面板定时任务管理平台")"
    echo -e "$(panel_menu_item_green_if_installed 13 "${gl_kjlan}13. ${gl_bai}Cloudreve网盘 ${gl_huang}★${gl_bai}" "13. Cloudreve网盘 ★")\033[48G$(panel_menu_item_green_if_installed 14 "${gl_kjlan}14. ${gl_bai}简单图床图片管理程序" "14. 简单图床图片管理程序")"
    echo -e "$(panel_menu_item_green_if_installed 15 "${gl_kjlan}15. ${gl_bai}emby多媒体管理系统" "15. emby多媒体管理系统")\033[48G$(panel_menu_item_green_if_installed 16 "${gl_kjlan}16. ${gl_bai}Speedtest测速面板" "16. Speedtest测速面板")"
    echo -e "$(panel_menu_item_green_if_installed 17 "${gl_kjlan}17. ${gl_bai}AdGuardHome去广告软件" "17. AdGuardHome去广告软件")\033[48G$(panel_menu_item_green_if_installed 18 "${gl_kjlan}18. ${gl_bai}onlyoffice在线办公OFFICE" "18. onlyoffice在线办公OFFICE")"
    echo -e "$(panel_menu_item_green_if_installed 19 "${gl_kjlan}19. ${gl_bai}雷池WAF防火墙面板" "19. 雷池WAF防火墙面板")\033[48G$(panel_menu_item_green_if_installed 20 "${gl_kjlan}20. ${gl_bai}portainer容器管理面板" "20. portainer容器管理面板")"
    echo -e "${gl_kjlan}------------------------"
    echo -e "$(panel_menu_item_green_if_installed 21 "${gl_kjlan}21. ${gl_bai}VScode网页版" "21. VScode网页版")\033[48G$(panel_menu_item_green_if_installed 22 "${gl_kjlan}22. ${gl_bai}UptimeKuma监控工具" "22. UptimeKuma监控工具")"
    echo -e "$(panel_menu_item_green_if_installed 23 "${gl_kjlan}23. ${gl_bai}Memos网页备忘录" "23. Memos网页备忘录")\033[48G$(panel_menu_item_green_if_installed 24 "${gl_kjlan}24. ${gl_bai}Webtop远程桌面   用6号或者99 ${gl_huang}★${gl_bai}" "24. Webtop远程桌面   用6号或者99 ★")"
    echo -e "$(panel_menu_item_green_if_installed 25 "${gl_kjlan}25. ${gl_bai}Nextcloud网盘" "25. Nextcloud网盘")\033[48G$(panel_menu_item_green_if_installed 26 "${gl_kjlan}26. ${gl_bai}QD-Today定时任务管理框架" "26. QD-Today定时任务管理框架")"
    echo -e "$(panel_menu_item_green_if_installed 27 "${gl_kjlan}27. ${gl_bai}Dockge容器堆栈管理面板" "27. Dockge容器堆栈管理面板")\033[48G$(panel_menu_item_green_if_installed 28 "${gl_kjlan}28. ${gl_bai}LibreSpeed测速工具" "28. LibreSpeed测速工具")"
    echo -e "$(panel_menu_item_green_if_installed 29 "${gl_kjlan}29. ${gl_bai}searxng聚合搜索站 ${gl_huang}★${gl_bai}" "29. searxng聚合搜索站 ★")\033[48G$(panel_menu_item_green_if_installed 30 "${gl_kjlan}30. ${gl_bai}PhotoPrism私有相册系统" "30. PhotoPrism私有相册系统")"
    echo -e "${gl_kjlan}------------------------"
    echo -e "$(panel_menu_item_green_if_installed 31 "${gl_kjlan}31. ${gl_bai}StirlingPDF工具大全" "31. StirlingPDF工具大全")\033[48G$(panel_menu_item_green_if_installed 32 "${gl_kjlan}32. ${gl_bai}drawio免费的在线图表软件 ${gl_huang}★${gl_bai}" "32. drawio免费的在线图表软件 ★")"
    echo -e "$(panel_menu_item_green_if_installed 33 "${gl_kjlan}33. ${gl_bai}Sun-Panel导航面板" "33. Sun-Panel导航面板")\033[48G$(panel_menu_item_green_if_installed 34 "${gl_kjlan}34. ${gl_bai}Pingvin-Share文件分享平台" "34. Pingvin-Share文件分享平台")"
    echo -e "$(panel_menu_item_green_if_installed 35 "${gl_kjlan}35. ${gl_bai}极简朋友圈" "35. 极简朋友圈")\033[48G$(panel_menu_item_green_if_installed 36 "${gl_kjlan}36. ${gl_bai}LobeChatAI聊天聚合网站" "36. LobeChatAI聊天聚合网站")"
    echo -e "$(panel_menu_item_green_if_installed 37 "${gl_kjlan}37. ${gl_bai}MyIP工具箱 ${gl_huang}★${gl_bai}" "37. MyIP工具箱 ★")\033[48G$(panel_menu_item_green_if_installed 38 "${gl_kjlan}38. ${gl_bai}小雅alist全家桶" "38. 小雅alist全家桶")"
    echo -e "$(panel_menu_item_green_if_installed 39 "${gl_kjlan}39. ${gl_bai}Bililive直播录制工具" "39. Bililive直播录制工具")\033[48G$(panel_menu_item_green_if_installed 40 "${gl_kjlan}40. ${gl_bai}远程Windows11" "40. 远程Windows11")"
    echo -e "${gl_kjlan}------------------------"
    echo -e "$(panel_menu_item_green_if_installed 41 "${gl_kjlan}41. ${gl_bai}耗子管理面板" "41. 耗子管理面板")\033[48G$(panel_menu_item_green_if_installed 42 "${gl_kjlan}42. ${gl_bai}vaultwarden(可以注册)" "42. vaultwarden(可以注册)")"
    echo -e "$(panel_menu_item_green_if_installed 43 "${gl_kjlan}43. ${gl_bai}vaultwarden(禁止注册SMTP设置)" "43. vaultwarden(禁止注册SMTP设置)")\033[48G$(panel_menu_item_green_if_installed 44 "${gl_kjlan}44. ${gl_bai}vaultwarden(禁止注册)" "44. vaultwarden(禁止注册)")"
    echo -e "$(panel_menu_item_green_if_installed 45 "${gl_kjlan}45. ${gl_bai}vaultwarden(注册SMTP设置)" "45. vaultwarden(注册SMTP设置)")\033[48G$(panel_menu_item_green_if_installed 46 "${gl_kjlan}46. ${gl_bai}Aria2离线下载" "46. Aria2离线下载")"
    echo -e "$(panel_menu_item_green_if_installed 47 "${gl_kjlan}47. ${gl_bai}Cloudreve网盘" "47. Cloudreve网盘")\033[48G$(panel_menu_item_green_if_installed 48 "${gl_kjlan}48. ${gl_bai}编译部署ssh Nexterm  用53 79" "48. 编译部署ssh Nexterm  用53 79")"
    echo -e "$(panel_menu_item_green_if_installed 49 "${gl_kjlan}49. ${gl_bai}vaultwarden完整脚本 ${gl_huang}★${gl_bai}" "49. vaultwarden完整脚本★")\033[48G$(panel_menu_item_green_if_installed 50 "${gl_kjlan}50. ${gl_bai}MoonTV" "50. MoonTV")"
    echo -e "${gl_kjlan}------------------------"
    echo -e "$(panel_menu_item_green_if_installed 51 "${gl_kjlan}51. ${gl_bai}极光面板" "51. 极光面板")\033[48G$(panel_menu_item_green_if_installed 52 "${gl_kjlan}52. ${gl_bai}emby安装" "52. emby安装")"
    echo -e "$(panel_menu_item_green_if_installed 53 "${gl_kjlan}53. ${gl_bai}NextermSSH链接 48 79${gl_huang}★${gl_bai}" "53. NextermSSH链接 48 79★")\033[48G$(panel_menu_item_green_if_installed 54 "${gl_kjlan}54. ${gl_bai}webssh ${gl_huang}★${gl_bai}" "54. webssh ★")"
    echo -e "$(panel_menu_item_green_if_installed 55 "${gl_kjlan}55. ${gl_bai}安装包openlist4.0.8 87 号" "55. 安装包openlist4.0.8 ★")\033[48G$(panel_menu_item_green_if_installed 56 "${gl_kjlan}56. ${gl_bai}umami网站流量统计系统" "56. umami网站流量统计系统")"
    echo -e "$(panel_menu_item_green_if_installed 57 "${gl_kjlan}57. ${gl_bai}dify安装 ${gl_huang}★${gl_bai}" "57. dify安装 ★")\033[48G$(panel_menu_item_green_if_installed 58 "${gl_kjlan}58. ${gl_bai}安装caddy" "58. 安装caddy")"
    echo -e "$(panel_menu_item_green_if_installed 59 "${gl_kjlan}59. ${gl_bai}docker安装rustdesk服务端 ${gl_huang}★${gl_bai}" "59. docker安装rustdesk服务端 ★")\033[48G$(panel_menu_item_green_if_installed 60 "${gl_kjlan}60. ${gl_bai}docker安装rustdesk中继端" "60. docker安装rustdesk中继端")"
    echo -e "${gl_kjlan}------------------------"
    echo -e "$(panel_menu_item_green_if_installed 61 "${gl_kjlan}61. ${gl_bai}安装rustdesk远程桌面 ${gl_huang}★${gl_bai}" "61. 安装rustdesk远程桌面 ★")\033[48G$(panel_menu_item_green_if_installed 62 "${gl_kjlan}62. ${gl_bai}安装x-ui" "62. 安装x-ui")"
    echo -e "$(panel_menu_item_green_if_installed 63 "${gl_kjlan}63. ${gl_bai}安装rustfs对象存储推荐 ${gl_huang}★${gl_bai}" "63. 安装rustfs对象存储推荐 ★")\033[48G$(panel_menu_item_green_if_installed 64 "${gl_kjlan}64. ${gl_bai}安装seaweedfs对象存储" "64. 安装seaweedfs对象存储")"
    echo -e "$(panel_menu_item_green_if_installed 65 "${gl_kjlan}65. ${gl_bai}安装caddy DNS版使用66配置反代 ${gl_huang}★${gl_bai}" "65. 安装caddy DNS版使用66配置反代 ★")\033[48G$(panel_menu_item_green_if_installed 66 "${gl_kjlan}66. ${gl_bai}安装65caddy DNS配置版" "66. 安装65caddy DNS配置版")"
    echo -e "$(panel_menu_item_green_if_installed 67 "${gl_kjlan}67. ${gl_bai}ownCloud网盘安装 ${gl_huang}★${gl_bai}" "67. ownCloud网盘安装 ★")\033[48G$(panel_menu_item_green_if_installed 68 "${gl_kjlan}68. ${gl_bai}安装M38u8安装完成使用58添加反代" "68. 安装M38u8安装完成使用58添加反代")"
    echo -e "$(panel_menu_item_green_if_installed 69 "${gl_kjlan}69. ${gl_bai}it-tools工具箱 ${gl_huang}★${gl_bai}" "69. it-tools工具箱 ★")\033[48G$(panel_menu_item_green_if_installed 70 "${gl_kjlan}70. ${gl_bai}安装盘搜" "70. 安装盘搜")"
    echo -e "${gl_kjlan}------------------------"
    echo -e "$(panel_menu_item_green_if_installed 71 "${gl_kjlan}71. ${gl_bai}安装zfile网盘 ${gl_huang}★${gl_bai}" "71. 安装zfile网盘 ★")\033[48G$(panel_menu_item_green_if_installed 72 "${gl_kjlan}72. ${gl_bai}安装Discourse论坛" "72. 安装Discourse论坛")"
    echo -e "$(panel_menu_item_green_if_installed 73 "${gl_kjlan}73. ${gl_bai}安装Matrix加密聊天 ${gl_huang}★${gl_bai}" "73. 安装Matrix加密聊天 ★")\033[48G$(panel_menu_item_green_if_installed 74 "${gl_kjlan}74. ${gl_bai}Mattermost团队协作聊天" "74. Mattermost团队协作聊天")"
    echo -e "$(panel_menu_item_green_if_installed 75 "${gl_kjlan}75. ${gl_bai}Certimate 证书管理 ${gl_huang}★${gl_bai}" "75. Certimate 证书管理 ★")\033[48G$(panel_menu_item_green_if_installed 76 "${gl_kjlan}76. ${gl_bai}vaultwarden管理员禁止注册 ${gl_huang}★${gl_bai}" "76. vaultwarden管理员禁止注册 ★")"
    echo -e "$(panel_menu_item_green_if_installed 77 "${gl_kjlan}77. ${gl_bai}邮箱caddy与nginx都可用 ${gl_huang}★${gl_bai}" "77. 邮箱caddy与nginx都可用 ★")\033[48G$(panel_menu_item_green_if_installed 78 "${gl_kjlan}78. ${gl_bai}Caddy安装mailcow邮箱 ${gl_huang}★${gl_bai}" "78. Caddy安装mailcow邮箱 ★")"
    echo -e "$(panel_menu_item_green_if_installed 79 "${gl_kjlan}79. ${gl_bai}自编译ssh Nexterm 48 用53${gl_huang}★${gl_bai}" "79. 自编译ssh Nexterm 48 用53★")\033[48G$(panel_menu_item_green_if_installed 80 "${gl_kjlan}80. ${gl_bai}自编译导航Sun-Panel ${gl_huang}★${gl_bai}" "80. 自编译导航Sun-Panel ★")"
    echo -e "${gl_kjlan}------------------------"
    echo -e "$(panel_menu_item_green_if_installed 81 "${gl_kjlan}81. ${gl_bai}Sun-Panel压缩包安装33docker ${gl_huang}★${gl_bai}" "81. Sun-Panel压缩包安装33docker ★")\033[48G$(panel_menu_item_green_if_installed 82 "${gl_kjlan}82. ${gl_bai}Backrest安装包 86 docker安装 ${gl_huang}★${gl_bai}" "82. Backrest安装包 86 docker安装 ★")"
    echo -e "$(panel_menu_item_green_if_installed 83 "${gl_kjlan}83. ${gl_bai}自编译caddy-dns ${gl_huang}★${gl_bai}" "83. 自编译caddy-dns ★")\033[48G$(panel_menu_item_green_if_installed 84 "${gl_kjlan}84. ${gl_bai}Hitokoto API (一言)  ${gl_huang}★${gl_bai}" "84. Hitokoto API (一言)  ★")"
    echo -e "$(panel_menu_item_green_if_installed 85 "${gl_kjlan}85. ${gl_bai}OpenList网盘授权 ${gl_huang}★${gl_bai}" "85. OpenList网盘授权 ★")\033[48G$(panel_menu_item_green_if_installed 86 "${gl_kjlan}86. ${gl_bai}docker安装Backrest 资源备份 ${gl_huang}★${gl_bai}" "86. docker安装Backrest 资源备份 ★")"
    echo -e "$(panel_menu_item_green_if_installed 87 "${gl_kjlan}87. ${gl_bai}docker安装openlist ${gl_huang}★${gl_bai}" "87. docker安装openlist ★")\033[48G$(panel_menu_item_green_if_installed 88 "${gl_kjlan}88. ${gl_bai}自编译minio ${gl_huang}★${gl_bai}" "88. 自编译minio ★")"
    echo -e "$(panel_menu_item_green_if_installed 89 "${gl_kjlan}89. ${gl_bai}自编译docker安装哪吒v2官方7号 ${gl_huang}★${gl_bai}" "89. 自编译docker安装哪吒v2官方7号 ★")\033[48G$(panel_menu_item_green_if_installed 90 "${gl_kjlan}90. ${gl_bai}BTC安装 ${gl_huang}★${gl_bai}" "90. BTC安装 ★")"
    echo -e "${gl_kjlan}------------------------"
    echo -e "$(panel_menu_item_green_if_installed 91 "${gl_kjlan}91. ${gl_bai}自动进行谷歌浏览 ${gl_huang}★${gl_bai}" "91. 自动进行谷歌浏览 ★")\033[48G$(panel_menu_item_green_if_installed 92 "${gl_kjlan}92. ${gl_bai}CLIProxyAPI ${gl_huang}★${gl_bai}" "92. CLIProxyAPI ★")"
    echo -e "$(panel_menu_item_green_if_installed 93 "${gl_kjlan}93. ${gl_bai}Sub2API ${gl_huang}★${gl_bai}" "93. Sub2API ★")\033[48G$(panel_menu_item_green_if_installed 94 "${gl_kjlan}94. ${gl_bai}Openclaw ${gl_huang}★${gl_bai}" "94. Openclaw ★")"
    echo -e "$(panel_menu_item_green_if_installed 95 "${gl_kjlan}95. ${gl_bai}Open WebUI ${gl_huang}★${gl_bai}" "95. Open WebUI ★")\033[48G$(panel_menu_item_green_if_installed 96 "${gl_kjlan}96. ${gl_bai}Google检测" "96. Google检测")"
    echo -e "$(panel_menu_item_green_if_installed 97 "${gl_kjlan}97. ${gl_bai}IP白名单模式配置列表" "97. IP白名单模式配置列表")\033[48G$(panel_menu_item_green_if_installed 98 "${gl_kjlan}98. ${gl_bai}安装Google" "98. 安装Google")"
    echo -e "$(panel_menu_item_green_if_installed 99 "${gl_kjlan}99. ${gl_bai}Hermes机器人爱马仕" "99. Hermes机器人爱马仕")\033[48G$(panel_menu_item_green_if_installed 100 "${gl_kjlan}100. ${gl_bai}lobehub安装webai" "100. lobehub安装webai")"
    echo -e "${gl_kjlan}------------------------"
    echo -e "$(panel_menu_item_green_if_installed 101 "${gl_kjlan}101. ${gl_bai}agent-ai备份" "101. agent-ai备份")\033[48G$(panel_menu_item_green_if_installed 102 "${gl_kjlan}102. ${gl_bai}加密支付GMPay 又名 epusdt ${gl_huang}★${gl_bai}" "102. 加密支付GMPay 又名 epusdt ★")"
    echo -e "$(panel_menu_item_green_if_installed 103 "${gl_kjlan}103. ${gl_bai}易支付Epay ${gl_huang}★${gl_bai}" "103. 易支付Epay ★")\033[48G$(panel_menu_item_green_if_installed 104 "${gl_kjlan}104. ${gl_bai}异次元发卡" "104. 异次元发卡")"
    echo -e "$(panel_menu_item_green_if_installed 105 "${gl_kjlan}105. ${gl_bai}独角兽发卡 ${gl_huang}★${gl_bai}" "105. 独角兽发卡 ★")\033[48G$(panel_menu_item_green_if_installed 106 "${gl_kjlan}106. ${gl_bai}加密支付bepusdt" "106. 加密支付bepusdt")"
    echo -e "${gl_kjlan}------------------------"
    echo -e "$(panel_menu_item_green_if_installed 990 "${gl_kjlan}990. ${gl_bai}安装的应用以及应用端口" "990. 安装的应用以及应用端口")\033[48G$(panel_menu_item_green_if_installed 991 "${gl_kjlan}991. ${gl_bai}Fail2Ban SSH防暴力破解 ${gl_huang}★${gl_bai}" "991. Fail2Ban SSH防暴力破解 ★")"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}996. ${gl_bai}CDN安装 ${gl_huang}★${gl_bai}\033[48G${gl_kjlan}997. ${gl_bai}PVE开小鸡面板"
    echo -e "${gl_kjlan}998. ${gl_bai}CDN迁移恢复 ${gl_huang}★${gl_bai}\033[48G${gl_kjlan}999. ${gl_bai}Webtop镜像版本管理 ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}1000. ${gl_bai}fnOS 系统重装 ${gl_huang}★${gl_bai}\033[48G${gl_kjlan}1001. ${gl_bai}主备容灾管理系统 ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}1002. ${gl_bai}win10长期服务版 ${gl_huang}★${gl_bai}\033[48G${gl_kjlan}1003. ${gl_bai}传送文件 ${gl_huang}★${gl_bai}"
    echo -e "$(panel_menu_item_green_if_installed 1004 "${gl_kjlan}1004. ${gl_bai}下载备份清理脚本 ${gl_huang}★${gl_bai}" "1004. 下载备份清理脚本 ★")\033[48G$(panel_menu_item_green_if_installed 1005 "${gl_kjlan}1005. ${gl_bai}网站论坛与其他备份合并 ${gl_huang}★${gl_bai}" "1005. 网站论坛与其他备份合并 ★")"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}91自编译有48.80.83.84.85.86.87.88.89"
    echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    
    # 打印重要项目固定提醒：已安装黄色，未安装红色
    local important_line=""
    local important_item=""
    local important_colored=""
    for important_item in 96 990 991; do
        if printf '%s
' "${installed_items[@]}" | grep -qx "$important_item"; then
            important_colored="${gl_huang}${important_item}${gl_bai}"
        else
            important_colored="${gl_hong}${important_item}${gl_bai}"
        fi
        if [ -z "$important_line" ]; then
            important_line="$important_colored"
        else
            important_line="$important_line $important_colored"
        fi
    done
    echo -e "${gl_kjlan}重要项目长显示（已安装显示为黄色）：${gl_bai}${important_line}"
    echo -e "${gl_kjlan}------------------------${gl_bai}"

    # 打印已安装的项目列表并自动折行输出
    if [ ${#installed_items[@]} -eq 0 ]; then
        echo -e "${gl_kjlan}已安装：无${gl_bai}"
    else
        echo -e -n "${gl_kjlan}已安装：${gl_bai}"
        local line=""
        local count=0
        local colored_item=""
        for item in "${installed_items[@]}"; do
            case "$item" in
                5|96|990|991)
                    colored_item="${gl_huang}${item}${gl_bai}"
                    ;;
                *)
                    colored_item="${gl_lv}${item}${gl_bai}"
                    ;;
            esac
            if [ $count -eq 0 ]; then
                line="$colored_item"
            else
                line="$line $colored_item"
            fi
            count=$((count + 1))
            if [ $((count % 12)) -eq 0 ]; then
                echo -e "$line"
                line=""
                count=0
            fi
        done
        if [ -n "$line" ]; then
            echo -e "$line"
        fi
    fi
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    read -e -p "请输入你的选择: " sub_choice

    case $sub_choice in
      1)

      lujing="[ -d "/www/server/panel" ]"
      panelname="宝塔面板"

      gongneng1="bt"
      gongneng1_1=""
      gongneng2="curl -o bt-uninstall.sh http://download.bt.cn/install/bt-uninstall.sh > /dev/null 2>&1 && chmod +x bt-uninstall.sh && ./bt-uninstall.sh"
      gongneng2_1="chmod +x bt-uninstall.sh"
      gongneng2_2="./bt-uninstall.sh"

      panelurl="https://www.bt.cn/new/index.html"


      centos_mingling="wget -O install.sh https://download.bt.cn/install/install_6.0.sh"
      centos_mingling2="sh install.sh ed8484bec"

      ubuntu_mingling="wget -O install.sh https://download.bt.cn/install/install-ubuntu_6.0.sh"
      ubuntu_mingling2="bash install.sh ed8484bec"

      install_panel



        ;;
      2)

      lujing="[ -d "/www/server/panel" ]"
      panelname="aapanel"

      gongneng1="bt"
      gongneng1_1=""
      gongneng2="curl -o bt-uninstall.sh http://download.bt.cn/install/bt-uninstall.sh > /dev/null 2>&1 && chmod +x bt-uninstall.sh && ./bt-uninstall.sh"
      gongneng2_1="chmod +x bt-uninstall.sh"
      gongneng2_2="./bt-uninstall.sh"

      panelurl="https://www.aapanel.com/new/index.html"

      centos_mingling="wget -O install.sh http://www.aapanel.com/script/install_6.0_en.sh"
      centos_mingling2="bash install.sh aapanel"

      ubuntu_mingling="wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh"
      ubuntu_mingling2="bash install.sh aapanel"

      install_panel

        ;;
      3)

      lujing="command -v 1pctl > /dev/null 2>&1 "
      panelname="1Panel"

      gongneng1="1pctl user-info"
      gongneng1_1="1pctl update password"
      gongneng2="1pctl uninstall"
      gongneng2_1=""
      gongneng2_2=""

      panelurl="https://1panel.cn/"


      centos_mingling="curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh"
      centos_mingling2="sh quick_start.sh"

      ubuntu_mingling="curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh"
      ubuntu_mingling2="bash quick_start.sh"

      install_panel

        ;;
      4)

      docker_name="npm"
      docker_img="jc21/nginx-proxy-manager:latest"
      docker_port=81
      docker_rum="docker run -d \
              --name=$docker_name \
              -p 80:80 \
              -p 81:$docker_port \
              -p 443:443 \
              -v /home/docker/npm/data:/data \
              -v /home/docker/npm/letsencrypt:/etc/letsencrypt \
              --restart=always \
              $docker_img"
      docker_describe="如果您已经安装了其他面板工具或者LDNMP建站环境，建议先卸载，再安装npm！"
      docker_url="官网介绍: https://nginxproxymanager.com/"
      docker_use="echo \"初始用户名: admin@example.com\""
      docker_passwd="echo \"初始密码: changeme\""

      docker_app

        ;;


5)
  clear
  send_stats "哪吒监控管理"

  while true; do
    clear
    echo -e "${CYAN}=================================================${NC}"
    echo "哪吒监控管理"
    echo "开源、轻量、易用的服务器监控与运维工具"
    echo "开源地址"
    echo "https://github.com/nezhahq/nezha"
    echo -e "${CYAN}=================================================${NC}"
    echo "1. 安装 / 更新哪吒"
    echo "2. 二进制备份与恢复"
    echo "------------------------"
    echo "3. docker安装面板"
    echo "------------------------"
    echo "0. 退出"
    echo "------------------------"

    read -e -p "输入你的选择: " choice

    case $choice in

      1)
        # 安装 / 更新
        curl -L https://raw.githubusercontent.com/zaixiangjian/nezhav0/refs/heads/v0/install.sh -o nezha.sh
        chmod +x nezha.sh
        sudo bash ./nezha.sh
        ;;

      2)
        echo "▶️ 二进制哪吒面板安装..."
        run_local_first_app_script "▶️ 安装二进制哪吒面板..." "/root/yingyong/erjinzhinezhav0.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/erjinzhinezhav0.sh"
        echo "✅ 二进制哪吒面板安装完成..."
        ;;

      3)
        echo "▶️ 正在启动哪吒docker安装..."
        run_local_first_app_script "▶️ 安装哪吒docker版..." "/root/yingyong/dockernezhav0.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/dockernezhav0.sh"
        echo "✅ 哪吒docker安装完成..."
        ;;

      0)
        break
        ;;

      *)
        echo "无效选项"
        sleep 1
        ;;
    esac

    read -n 1 -s -r -p "按任意键继续..."
  done
  ;;


    6)
      docker_name="webtop-ubuntu"
      docker_img="lscr.io/linuxserver/webtop:ubuntu-kde"
      docker_port=3006
      docker_dir="/home/docker/webtop"

      clear
      echo "------------------------"
      echo "1. 安装"
      echo "2. 备份"
      echo "3. 卸载"
      echo "4. 恢复最新备份"
      echo "------------------------"
      echo "0. 返回上一级"
      echo "------------------------"
      echo -n "请输入你的选择: "
      read sub_choice

      case "$sub_choice" in
        1)
          # 生成随机18位密码
          random_passwd=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 18)

          docker_rum="docker run -d \
              --name=webtop-ubuntu \
              --security-opt seccomp=unconfined \
              -e PUID=1000 \
              -e PGID=1000 \
              -e TZ=Asia/Shanghai \
              -e LC_ALL=zh_CN.UTF-8 \
              -e CUSTOM_USER=admin \
              -e PASSWORD=$random_passwd \
              -e SUBFOLDER=/ \
              -e TITLE=我的网站目录 \
              -p $docker_port:3000 \
              -v $docker_dir/data:/config \
              -v $docker_dir/Downloads:/home/abc/Downloads \
              --shm-size=\"1gb\" \
              --restart unless-stopped \
              $docker_img"

          # 启动容器
          eval "$docker_rum"

          echo ""
          echo "$docker_name 已安装 ✅"
          echo "webtop基于Ubuntu的容器，包含官方支持的完整桌面环境，可通过任何现代 Web 浏览器访问"
          echo "官网介绍: https://docs.linuxserver.io/images/docker-webtop/"
          echo ""
          echo "访问地址:"
          echo "http://$(curl -s ipv4.ip.sb):$docker_port"
          echo "http://[$(curl -s ipv6.ip.sb)]:$docker_port"
          echo ""
          echo "用户名: admin"
          echo "密码: $random_passwd"
          echo "⚠️ 此密码仅显示一次，请妥善保存！"
          ;;
        2)
          echo "正在备份 Webtop 数据..."
          backup_file="/home/docker/webtop_backup_$(date +%F_%H%M%S).tar.gz"
          tar -czvf "$backup_file" -C /home/docker webtop
          if [ $? -eq 0 ]; then
            echo "备份完成 ✅"
            echo "备份文件: $backup_file"
          else
            echo "⚠️ 备份失败"
          fi
          ;;
        3)
          echo "正在停止并删除容器 $docker_name ..."
          docker stop $docker_name >/dev/null 2>&1
          docker rm $docker_name >/dev/null 2>&1

          if [ $? -eq 0 ]; then
            echo "容器已成功删除 ✅"
          else
            echo "⚠️ 容器不存在或删除失败"
          fi

          echo "正在删除本地目录 $docker_dir ..."
          if [ -d "$docker_dir" ]; then
            rm -rf "$docker_dir"
            echo "目录已删除 ✅"
          else
            echo "⚠️ 本地目录不存在或已被删除"
          fi

          echo "Webtop 容器及数据已卸载完成 ✅"
          ;;
        4)
          echo "正在查找最新的备份文件..."
          latest_backup=$(ls -t /home/docker/webtop_backup_*.tar.gz 2>/dev/null | head -n 1)

          if [ -z "$latest_backup" ]; then
            echo "⚠️ 未找到任何备份文件"
          else
            echo "找到备份文件: $latest_backup"
            echo "正在恢复备份..."

            # 停止容器
            docker stop $docker_name >/dev/null 2>&1

            # 删除原数据
            rm -rf "$docker_dir"

            # 解压备份
            tar -xzvf "$latest_backup" -C /home/docker

            # 重启容器
            docker restart $docker_name >/dev/null 2>&1

            if [ $? -eq 0 ]; then
              echo "恢复并重启容器成功 ✅"
            else
              echo "⚠️ 恢复失败或容器启动失败"
            fi
          fi
          ;;
        0)
          echo "返回上一级菜单..."
          ;;
        *)
          echo "无效选项，请重新输入！"
          ;;
      esac
      ;;




      7)
      clear
      send_stats "搭建哪吒"
      while true; do
        clear
        echo "哪吒监控管理"
        echo "开源、轻量、易用的服务器监控与运维工具"
        echo "视频介绍: https://www.bilibili.com/video/BV1wv421C71t?t=0.1"
        echo "------------------------"
        echo "1. 使用           0. 返回上一级"
        echo "=============================="
        echo "⚠️ 使用5号配置进行备份与恢复配置 ⚠️"
        echo "=============================="
        read -e -p "输入你的选择: " choice

        case $choice in
          1)
            curl -L https://raw.githubusercontent.com/zaixiangjian/nezhav0/refs/heads/v0/install.sh -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh
            ;;
          0)
            break
            ;;
          *)
            break
            ;;

        esac
        break_end
      done
        ;;

      8)

      docker_name="qbittorrent"
      docker_img="lscr.io/linuxserver/qbittorrent:latest"
      docker_port=8081
      docker_rum="docker run -d \
                  --name=qbittorrent \
                  -e PUID=1000 \
                  -e PGID=1000 \
                  -e TZ=Etc/UTC \
                  -e WEBUI_PORT=8081 \
                  -p 8081:8081 \
                  -p 6881:6881 \
                  -p 6881:6881/udp \
                  -v /home/docker/qbittorrent/config:/config \
                  -v /home/docker/qbittorrent/downloads:/downloads \
                  --restart unless-stopped \
                  lscr.io/linuxserver/qbittorrent:latest"
      docker_describe="qbittorrent离线BT磁力下载服务"
      docker_url="官网介绍: https://hub.docker.com/r/linuxserver/qbittorrent"
      docker_use="sleep 3"
      docker_passwd="docker logs qbittorrent"

      docker_app

        ;;

      9)
      send_stats "搭建邮局"
      clear
      install telnet
      docker_name="mailserver"
      while true; do
        check_docker_app

        clear
        echo -e "邮局服务 $check_docker"
        echo "poste.io 是一个开源的邮件服务器解决方案，"
        echo "视频介绍: https://www.bilibili.com/video/BV1wv421C71t?t=0.1"

        echo ""
        echo "端口检测"
        port=25
        timeout=3
        if echo "quit" | timeout $timeout telnet smtp.qq.com $port | grep 'Connected'; then
          echo -e "${gl_lv}端口 $port 当前可用${gl_bai}"
        else
          echo -e "${gl_hong}端口 $port 当前不可用${gl_bai}"
        fi
        echo ""

        if docker inspect "$docker_name" &>/dev/null; then
          yuming=$(cat /home/docker/mail/mail.txt)
          echo "访问地址: "
          echo "https://$yuming"
        fi

        echo "------------------------"
        echo "1. 安装           2. 更新           3. 卸载"
        echo "------------------------"
        echo "0. 返回上一级"
        echo "------------------------"
        read -e -p "输入你的选择: " choice

        case $choice in
          1)
            read -e -p "请设置邮箱域名 例如 mail.yuming.com : " yuming
            mkdir -p /home/docker/mail
            echo "$yuming" > /home/docker/mail/mail.txt
            echo "------------------------"
            ip_address
            echo "先解析这些DNS记录"
            echo "A           mail            $ipv4_address"
            echo "CNAME       imap            $yuming"
            echo "CNAME       pop             $yuming"
            echo "CNAME       smtp            $yuming"
            echo "MX          @               $yuming"
            echo "TXT         @               v=spf1 mx ~all"
            echo ""
            echo "------------------------"
            echo "按任意键继续..."
            read -n 1 -s -r -p ""

            install_docker

            docker run -d \
              --name mailserver \
              --hostname "$yuming" \
              -e TZ=Asia/Shanghai \
              -v /home/docker/mail/data:/data \
              -p 80:80 \
              -p 443:443 \
              -p 25:25 \
              -p 587:587 \
              -p 993:993 \
              -p 110:110 \
              -p 995:995 \
              -p 143:143 \
              -p 465:465 \
              -p 4190:4190 \
              --restart=always \
              analogic/poste.io

            clear
            echo "poste.io已经安装完成"
            echo "------------------------"
            echo "您可以使用以下地址访问poste.io:"
            echo "https://$yuming"
            echo ""
            ;;

          2)
            docker rm -f mailserver
            docker rmi -f analogic/poste.io
            yuming=$(cat /home/docker/mail/mail.txt)
            docker run -d \
              --name mailserver \
              --hostname "$yuming" \
              -e TZ=Asia/Shanghai \
              -v /home/docker/mail/data:/data \
              -p 80:80 \
              -p 443:443 \
              -p 25:25 \
              -p 587:587 \
              -p 993:993 \
              -p 110:110 \
              -p 995:995 \
              -p 143:143 \
              -p 465:465 \
              -p 4190:4190 \
              --restart=always \
              analogic/poste.io
            clear
            echo "poste.io已经安装完成"
            echo "------------------------"
            echo "您可以使用以下地址访问poste.io:"
            echo "https://$yuming"
            echo ""
            ;;

          3)
            docker rm -f mailserver
            docker rmi -f analogic/poste.io
            rm /home/docker/mail/mail.txt
            rm -rf /home/docker/mail/data
            echo "应用已卸载"
            ;;

          0)
            break
            ;;

          *)
            echo "无效选项"
            ;;

        esac
        break_end
      done
      ;;



      10)
      send_stats "搭建聊天"
      has_ipv4_has_ipv6
      docker_name=rocketchat
      docker_port=3897
      while true; do
        check_docker_app
        clear
        echo -e "聊天服务 $check_docker"
        echo "Rocket.Chat 是一个开源的团队通讯平台，支持实时聊天、音视频通话、文件共享等多种功能，"
        echo "官网介绍: https://www.rocket.chat"
        if docker inspect "$docker_name" &>/dev/null; then
          check_docker_app_ip
        fi
        echo ""

        echo "------------------------"
        echo "1. 安装           2. 更新           3. 卸载"
        echo "------------------------"
        echo "0. 返回上一级"
        echo "------------------------"
        read -e -p "输入你的选择: " choice

        case $choice in
          1)
            install_docker
            docker run --name db -d --restart=always \
              -v /home/docker/mongo/dump:/dump \
              mongo:latest --replSet rs5 --oplogSize 256
            sleep 1
            docker exec -it db mongosh --eval "printjson(rs.initiate())"
            sleep 5
            docker run --name rocketchat --restart=always -p 3897:3000 --link db --env ROOT_URL=http://localhost --env MONGO_OPLOG_URL=mongodb://db:27017/rs5 -d rocket.chat

            clear

            ip_address
            echo "rocket.chat已经安装完成"
            check_docker_app_ip
            echo ""

            ;;

          2)
            docker rm -f rocketchat
            docker rmi -f rocket.chat:6.3
            docker run --name rocketchat --restart=always -p 3897:3000 --link db --env ROOT_URL=http://localhost --env MONGO_OPLOG_URL=mongodb://db:27017/rs5 -d rocket.chat
            clear
            ip_address
            echo "rocket.chat已经安装完成"
            check_docker_app_ip
            echo ""
            ;;
          3)
            docker rm -f rocketchat
            docker rmi -f rocket.chat
            docker rm -f db
            docker rmi -f mongo:latest
            rm -rf /home/docker/mongo
            echo "应用已卸载"

            ;;

          0)
            break
            ;;
          *)
            break
            ;;

        esac
        break_end
      done
        ;;



      11)
      echo "正在安装: 禅道项目管理软件"
      docker_name="zentao-server"
      docker_img="idoop/zentao:latest"
      docker_port=82
      docker_rum="docker run -d -p 82:80 -p 3308:3306 \
                -e ADMINER_USER=\"root\" -e ADMINER_PASSWD=\"password\" \
                -e BIND_ADDRESS=\"false\" \
                -v /home/docker/zentao-server/:/opt/zbox/ \
                --add-host smtp.exmail.qq.com:163.177.90.125 \
                --name zentao-server \
                --restart=always \
                idoop/zentao:latest"
      docker_describe="禅道是通用的项目管理软件"
      docker_url="官网介绍: https://www.zentao.net/"
      docker_use="echo \"初始用户名: admin\""
      docker_passwd="echo \"初始密码: 123456\""
      docker_app

        ;;

      12)
      docker_name="qinglong"
      docker_img="whyour/qinglong:latest"
      docker_port=5700
      docker_rum="docker run -d \
            -v /home/docker/qinglong/data:/ql/data \
            -p 5700:5700 \
            --name qinglong \
            --hostname qinglong \
            --restart unless-stopped \
            whyour/qinglong:latest"
      docker_describe="青龙面板是一个定时任务管理平台"
      docker_url="官网介绍: ${gh_proxy}https://github.com/whyour/qinglong"
      docker_use=""
      docker_passwd=""
      docker_app

        ;;

      13)
        run_local_first_app_script "▶️ 安装 cloudreve 网盘..." "/root/yingyong/13cloudreve.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/13cloudreve.sh"
        echo "✅ cloudreve 网盘安装成功..."
        ;;

      14)
      docker_name="easyimage"
      docker_img="ddsderek/easyimage:latest"
      docker_port=85
      docker_rum="docker run -d \
            --name easyimage \
            -p 85:80 \
            -e TZ=Asia/Shanghai \
            -e PUID=1000 \
            -e PGID=1000 \
            -v /home/docker/easyimage/config:/app/web/config \
            -v /home/docker/easyimage/i:/app/web/i \
            --restart unless-stopped \
            ddsderek/easyimage:latest"
      docker_describe="简单图床是一个简单的图床程序"
      docker_url="官网介绍: ${gh_proxy}https://github.com/icret/EasyImages2.0"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;

      15)
      docker_name="emby"
      docker_img="linuxserver/emby:latest"
      docker_port=8096
      docker_rum="docker run -d --name=emby --restart=always \
            -v /homeo/docker/emby/config:/config \
            -v /homeo/docker/emby/share1:/mnt/share1 \
            -v /homeo/docker/emby/share2:/mnt/share2 \
            -v /mnt/notify:/mnt/notify \
            -p 8096:8096 -p 8920:8920 \
            -e UID=1000 -e GID=100 -e GIDLIST=100 \
            linuxserver/emby:latest"
      docker_describe="emby是一个主从式架构的媒体服务器软件，可以用来整理服务器上的视频和音频，并将音频和视频流式传输到客户端设备"
      docker_url="官网介绍: https://emby.media/"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;

      16)
      docker_name="looking-glass"
      docker_img="wikihostinc/looking-glass-server"
      docker_port=89
      docker_rum="docker run -d --name looking-glass --restart always -p 89:80 wikihostinc/looking-glass-server"
      docker_describe="Speedtest测速面板是一个VPS网速测试工具，多项测试功能，还可以实时监控VPS进出站流量"
      docker_url="官网介绍: ${gh_proxy}https://github.com/wikihost-opensource/als"
      docker_use=""
      docker_passwd=""
      docker_app

        ;;
      17)

      docker_name="adguardhome"
      docker_img="adguard/adguardhome"
      docker_port=3000
      docker_rum="docker run -d \
              --name adguardhome \
              -v /home/docker/adguardhome/work:/opt/adguardhome/work \
              -v /home/docker/adguardhome/conf:/opt/adguardhome/conf \
              -p 53:53/tcp \
              -p 53:53/udp \
              -p 3000:3000/tcp \
              --restart always \
              adguard/adguardhome"
      docker_describe="AdGuardHome是一款全网广告拦截与反跟踪软件，未来将不止是一个DNS服务器。"
      docker_url="官网介绍: https://hub.docker.com/r/adguard/adguardhome"
      docker_use=""
      docker_passwd=""
      docker_app

        ;;


      18)

      docker_name="onlyoffice"
      docker_img="onlyoffice/documentserver"
      docker_port=8082
      docker_rum="docker run -d -p 8082:80 \
            --restart=always \
            --name onlyoffice \
            -v /home/docker/onlyoffice/DocumentServer/logs:/var/log/onlyoffice  \
            -v /home/docker/onlyoffice/DocumentServer/data:/var/www/onlyoffice/Data  \
             onlyoffice/documentserver"
      docker_describe="onlyoffice是一款开源的在线office工具，太强大了！"
      docker_url="官网介绍: https://www.onlyoffice.com/"
      docker_use=""
      docker_passwd=""
      docker_app

        ;;

      19)
      send_stats "搭建雷池"

      has_ipv4_has_ipv6
      docker_name=safeline-mgt
      docker_port=9443
      while true; do
        check_docker_app
        clear
        echo -e "雷池服务 $check_docker"
        echo "雷池是长亭科技开发的WAF站点防火墙程序面板，可以反代站点进行自动化防御"
        echo "视频介绍: https://www.bilibili.com/video/BV1mZ421T74c?t=0.1"
        if docker inspect "$docker_name" &>/dev/null; then
          check_docker_app_ip
        fi
        echo ""

        echo "------------------------"
        echo "1. 安装           2. 更新           3. 重置密码           4. 卸载"
        echo "------------------------"
        echo "0. 返回上一级"
        echo "------------------------"
        read -e -p "输入你的选择: " choice

        case $choice in
          1)
            install_docker
            bash -c "$(curl -fsSLk https://waf-ce.chaitin.cn/release/latest/setup.sh)"
            clear
            echo "雷池WAF面板已经安装完成"
            check_docker_app_ip
            docker exec safeline-mgt resetadmin

            ;;

          2)
            bash -c "$(curl -fsSLk https://waf-ce.chaitin.cn/release/latest/upgrade.sh)"
            docker rmi $(docker images | grep "safeline" | grep "none" | awk '{print $3}')
            echo ""
            clear
            echo "雷池WAF面板已经更新完成"
            check_docker_app_ip
            ;;
          3)
            docker exec safeline-mgt resetadmin
            ;;
          4)
            cd /data/safeline
            docker compose down
            docker compose down --rmi all
            echo "如果你是默认安装目录那现在项目已经卸载。如果你是自定义安装目录你需要到安装目录下自行执行:"
            echo "docker compose down && docker compose down --rmi all"
            ;;

          0)
            break
            ;;
          *)
            break
            ;;

        esac
        break_end
      done

        ;;

      20)
      docker_name="portainer"
      docker_img="portainer/portainer"
      docker_port=9050
      docker_rum="docker run -d \
          --name portainer \
          -p 9050:9000 \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v /home/docker/portainer:/data \
          --restart always \
          portainer/portainer"
      docker_describe="portainer是一个轻量级的docker容器管理面板"
      docker_url="官网介绍: https://www.portainer.io/"
      docker_use=""
      docker_passwd=""
      docker_app

        ;;

      21)
      docker_name="vscode-web"
      docker_img="codercom/code-server"
      docker_port=8180
      docker_rum="docker run -d -p 8180:8080 -v /home/docker/vscode-web:/home/coder/.local/share/code-server --name vscode-web --restart always codercom/code-server"
      docker_describe="VScode是一款强大的在线代码编写工具"
      docker_url="官网介绍: ${gh_proxy}https://github.com/coder/code-server"
      docker_use="sleep 3"
      docker_passwd="docker exec vscode-web cat /home/coder/.config/code-server/config.yaml"
      docker_app
        ;;
      22)
      docker_name="uptime-kuma"
      docker_img="louislam/uptime-kuma:latest"
      docker_port=3003
      docker_rum="docker run -d \
              --name=uptime-kuma \
              -p 3003:3001 \
              -v /home/docker/uptime-kuma/uptime-kuma-data:/app/data \
              --restart=always \
              louislam/uptime-kuma:latest"
      docker_describe="Uptime Kuma 易于使用的自托管监控工具"
      docker_url="官网介绍: ${gh_proxy}https://github.com/louislam/uptime-kuma"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;

      23)
      docker_name="memos"
      docker_img="ghcr.io/usememos/memos:latest"
      docker_port=5230
      docker_rum="docker run -d --name memos -p 5230:5230 -v /home/docker/memos:/var/opt/memos --restart always ghcr.io/usememos/memos:latest"
      docker_describe="Memos是一款轻量级、自托管的备忘录中心"
      docker_url="官网介绍: ${gh_proxy}https://github.com/usememos/memos"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;

    24)
      docker_name="webtop"
      docker_img="lscr.io/linuxserver/webtop:latest"
      docker_port=3083
      docker_dir="/home/docker/webtop"

      clear
      echo "------------------------"
      echo "1. 安装"
      echo "2. 备份"
      echo "3. 卸载"
      echo "4. 恢复最新备份"
      echo "------------------------"
      echo "0. 返回上一级"
      echo "------------------------"
      echo -n "请输入你的选择: "
      read sub_choice

      case "$sub_choice" in
        1)
          # 生成随机18位密码
          random_passwd=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 18)

          docker_rum="docker run -d \
            --name=webtop \
            --security-opt seccomp=unconfined \
            -e PUID=1000 \
            -e PGID=1000 \
            -e TZ=Asia/Shanghai \
            -e LC_ALL=zh_CN.UTF-8 \
            -e DOCKER_MODS=linuxserver/mods:universal-package-install \
            -e INSTALL_PACKAGES=font-noto-cjk \
            -e CUSTOM_USER=admin \
            -e PASSWORD=$random_passwd \
            -e SUBFOLDER=/ \
            -e TITLE=我的网站目录 \
            -p $docker_port:3000 \
            -v $docker_dir/data:/config \
            -v $docker_dir/Downloads:/home/abc/Downloads \
            --shm-size=\"1gb\" \
            --restart unless-stopped \
            $docker_img"

          # 启动容器
          eval "$docker_rum"

          echo ""
          echo "安装完成"
          echo ""
          echo "$docker_name 已安装"
          echo "webtop基于 Alpine、Ubuntu、Fedora 和 Arch 的容器，包含官方支持的完整桌面环境，可通过任何现代 Web 浏览器访问"
          echo "官网介绍: https://docs.linuxserver.io/images/docker-webtop/"
          echo "------------------------"
          echo "Webtop 容器已安装完成 ✅"
          echo ""
          echo "访问地址:"
          echo "http://$(curl -s ipv4.ip.sb):$docker_port"
          echo "http://[$(curl -s ipv6.ip.sb)]:$docker_port"
          echo ""
          echo "用户名: admin"
          echo "密码: $random_passwd"
          echo "⚠️ 此密码仅显示一次，请妥善保存！"
          ;;
        2)
          echo "正在备份 Webtop 数据..."
          backup_file="/home/docker/webtop_backup_$(date +%F_%H%M%S).tar.gz"
          tar -czvf "$backup_file" -C /home/docker webtop
          if [ $? -eq 0 ]; then
            echo "备份完成 ✅"
            echo "备份文件: $backup_file"
          else
            echo "⚠️ 备份失败"
          fi
          ;;
        3)
          echo "正在停止并删除容器 $docker_name ..."
          docker stop $docker_name >/dev/null 2>&1
          docker rm $docker_name >/dev/null 2>&1

          if [ $? -eq 0 ]; then
            echo "容器已成功删除 ✅"
          else
            echo "⚠️ 容器不存在或删除失败"
          fi

          echo "正在删除本地目录 $docker_dir ..."
          if [ -d "$docker_dir" ]; then
            rm -rf "$docker_dir"
            echo "目录已删除 ✅"
          else
            echo "⚠️ 本地目录不存在或已被删除"
          fi

          echo "Webtop 容器及数据已卸载完成 ✅"
          ;;
        4)
          echo "正在查找最新的备份文件..."
          latest_backup=$(ls -t /home/docker/webtop_backup_*.tar.gz 2>/dev/null | head -n 1)

          if [ -z "$latest_backup" ]; then
            echo "⚠️ 未找到任何备份文件"
          else
            echo "找到备份文件: $latest_backup"
            echo "正在恢复备份..."

            # 停止容器
            docker stop $docker_name >/dev/null 2>&1

            # 删除原数据
            rm -rf "$docker_dir"

            # 解压备份
            tar -xzvf "$latest_backup" -C /home/docker

            # 重启容器
            docker restart $docker_name >/dev/null 2>&1

            if [ $? -eq 0 ]; then
              echo "恢复并重启容器成功 ✅"
            else
              echo "⚠️ 恢复失败或容器启动失败"
            fi
          fi
          ;;
        0)
          echo "返回上一级菜单..."
          ;;
        *)
          echo "无效选项，请重新输入！"
          ;;
      esac
      ;;


      25)
      docker_name="nextcloud-aio"
      docker_img="nextcloud/all-in-one:latest"
      docker_port="80 8080 8443"
      docker_rum="docker run \
--init \
--sig-proxy=false \
--name nextcloud-aio-mastercontainer \
--restart always \
--publish 80:80 \
--publish 8080:8080 \
--publish 8443:8443 \
--volume nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
--volume /var/run/docker.sock:/var/run/docker.sock:ro \
nextcloud/all-in-one:latest"
      docker_describe="Nextcloud AIO 是官方推荐的多合一部署方式，简化了 Nextcloud 的部署和维护"
      docker_url="官网介绍: https://nextcloud.com/"
      docker_use="echo '容器已部署，请访问 https://<你的服务器IP>:8443 进行安装配置'"
      docker_passwd=""
      docker_app
        ;;



      26)
      docker_name="qd"
      docker_img="qdtoday/qd:latest"
      docker_port=8923
      docker_rum="docker run -d --name qd -p 8923:80 -v /home/docker/qd/config:/usr/src/app/config qdtoday/qd"
      docker_describe="QD-Today是一个HTTP请求定时任务自动执行框架"
      docker_url="官网介绍: https://qd-today.github.io/qd/zh_CN/"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;
      27)
      docker_name="dockge"
      docker_img="louislam/dockge:latest"
      docker_port=5003
      docker_rum="docker run -d --name dockge --restart unless-stopped -p 5003:5001 -v /var/run/docker.sock:/var/run/docker.sock -v /home/docker/dockge/data:/app/data -v  /home/docker/dockge/stacks:/home/docker/dockge/stacks -e DOCKGE_STACKS_DIR=/home/docker/dockge/stacks louislam/dockge"
      docker_describe="dockge是一个可视化的docker-compose容器管理面板"
      docker_url="官网介绍: ${gh_proxy}https://github.com/louislam/dockge"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;

      28)
      docker_name="speedtest"
      docker_img="ghcr.io/librespeed/speedtest:latest"
      docker_port=6681
      docker_rum="docker run -d \
              --name speedtest \
              --restart always \
              -e MODE=standalone \
              -p 6681:80 \
              ghcr.io/librespeed/speedtest:latest"
      docker_describe="librespeed是用Javascript实现的轻量级速度测试工具，即开即用"
      docker_url="官网介绍: ${gh_proxy}https://github.com/librespeed/speedtest"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;

      29)
      docker_name="searxng"
      docker_img="alandoyle/searxng:latest"
      docker_port=8700
      docker_rum="docker run --name=searxng \
              -d --init \
              --restart=unless-stopped \
              -v /home/docker/searxng/config:/etc/searxng \
              -v /home/docker/searxng/templates:/usr/local/searxng/searx/templates/simple \
              -v /home/docker/searxng/theme:/usr/local/searxng/searx/static/themes/simple \
              -p 8700:8080/tcp \
              alandoyle/searxng:latest"
      docker_describe="searxng是一个私有且隐私的搜索引擎站点"
      docker_url="官网介绍: https://hub.docker.com/r/alandoyle/searxng"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;

      30)
      docker_name="photoprism"
      docker_img="photoprism/photoprism:latest"
      docker_port=2342
      rootpasswd=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16)
      docker_rum="docker run -d \
              --name photoprism \
              --restart always \
              --security-opt seccomp=unconfined \
              --security-opt apparmor=unconfined \
              -p 2342:2342 \
              -e PHOTOPRISM_UPLOAD_NSFW="true" \
              -e PHOTOPRISM_ADMIN_PASSWORD="$rootpasswd" \
              -v /home/docker/photoprism/storage:/photoprism/storage \
              -v /home/docker/photoprism/Pictures:/photoprism/originals \
              photoprism/photoprism"
      docker_describe="photoprism非常强大的私有相册系统"
      docker_url="官网介绍: https://www.photoprism.app/"
      docker_use="echo \"账号: admin  密码: $rootpasswd\""
      docker_passwd=""
      docker_app
        ;;


      31)
      docker_name="s-pdf"
      docker_img="frooodle/s-pdf:latest"
      docker_port=8020
      docker_rum="docker run -d \
              --name s-pdf \
              --restart=always \
               -p 8020:8080 \
               -v /home/docker/s-pdf/trainingData:/usr/share/tesseract-ocr/5/tessdata \
               -v /home/docker/s-pdf/extraConfigs:/configs \
               -v /home/docker/s-pdf/logs:/logs \
               -e DOCKER_ENABLE_SECURITY=false \
               frooodle/s-pdf:latest"
      docker_describe="这是一个强大的本地托管基于 Web 的 PDF 操作工具，使用 docker，允许您对 PDF 文件执行各种操作，例如拆分合并、转换、重新组织、添加图像、旋转、压缩等。"
      docker_url="官网介绍: ${gh_proxy}https://github.com/Stirling-Tools/Stirling-PDF"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;

      32)
      docker_name="drawio"
      docker_img="jgraph/drawio"
      docker_port=7080
      docker_rum="docker run -d --restart=always --name drawio -p 7080:8080 -v /home/docker/drawio:/var/lib/drawio jgraph/drawio"
      docker_describe="这是一个强大图表绘制软件。思维导图，拓扑图，流程图，都能画"
      docker_url="官网介绍: https://www.drawio.com/"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;

      33)
      docker_name="sun-panel"
      docker_img="hslr/sun-panel"
      docker_port=3009
      docker_rum="docker run -d --restart=always -p 3009:3002 \
              -v /home/docker/sun-panel/conf:/app/conf \
              -v /home/docker/sun-panel/uploads:/app/uploads \
              -v /home/docker/sun-panel/database:/app/database \
              --name sun-panel \
              hslr/sun-panel"
      docker_describe="Sun-Panel服务器、NAS导航面板、Homepage、浏览器首页"
      docker_url="官网介绍: https://doc.sun-panel.top/zh_cn/"
      docker_use="echo \"账号: admin@sun.cc  密码: 12345678\""
      docker_passwd=""
      docker_app
        ;;

      34)
      docker_name="pingvin-share"
      docker_img="stonith404/pingvin-share"
      docker_port=3060
      docker_rum="docker run -d \
              --name pingvin-share \
              --restart always \
              -p 3060:3000 \
              -v /home/docker/pingvin-share/data:/opt/app/backend/data \
              stonith404/pingvin-share"
      docker_describe="Pingvin Share 是一个可自建的文件分享平台，是 WeTransfer 的一个替代品"
      docker_url="官网介绍: ${gh_proxy}https://github.com/stonith404/pingvin-share"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;


      35)
      docker_name="moments"
      docker_img="kingwrcy/moments:latest"
      docker_port=8035
      docker_rum="docker run -d --restart unless-stopped \
              -p 8035:3000 \
              -v /home/docker/moments/data:/app/data \
              -v /etc/localtime:/etc/localtime:ro \
              -v /etc/timezone:/etc/timezone:ro \
              --name moments \
              kingwrcy/moments:latest"
      docker_describe="极简朋友圈，高仿微信朋友圈，记录你的美好生活"
      docker_url="官网介绍: ${gh_proxy}https://github.com/kingwrcy/moments?tab=readme-ov-file"
      docker_use="echo \"账号: admin  密码: a123456\""
      docker_passwd=""
      docker_app
        ;;



      36)
      docker_name="lobe-chat"
      docker_img="lobehub/lobe-chat:latest"
      docker_port=8036
      docker_rum="docker run -d -p 8036:3210 \
              --name lobe-chat \
              --restart=always \
              lobehub/lobe-chat"
      docker_describe="LobeChat聚合市面上主流的AI大模型，ChatGPT/Claude/Gemini/Groq/Ollama"
      docker_url="官网介绍: ${gh_proxy}https://github.com/lobehub/lobe-chat"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;

      37)
      docker_name="myip"
      docker_img="ghcr.io/jason5ng32/myip:latest"
      docker_port=8037
      docker_rum="docker run -d -p 8037:18966 --name myip --restart always ghcr.io/jason5ng32/myip:latest"
      docker_describe="是一个多功能IP工具箱，可以查看自己IP信息及连通性，用网页面板呈现"
      docker_url="官网介绍: ${gh_proxy}https://github.com/jason5ng32/MyIP/blob/main/README_ZH.md"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;

      38)
      send_stats "小雅全家桶"
      clear
      install_docker
      bash -c "$(curl --insecure -fsSL https://ddsrem.com/xiaoya_install.sh)"
        ;;

      39)

      if [ ! -d /home/docker/bililive-go/ ]; then
        mkdir -p /home/docker/bililive-go/ > /dev/null 2>&1
        wget -O /home/docker/bililive-go/config.yml ${gh_proxy}https://raw.githubusercontent.com/hr3lxphr6j/bililive-go/master/config.yml > /dev/null 2>&1
      fi

      docker_name="bililive-go"
      docker_img="chigusa/bililive-go"
      docker_port=8039
      docker_rum="docker run --restart=always --name bililive-go -v /home/docker/bililive-go/config.yml:/etc/bililive-go/config.yml -v /home/docker/bililive-go/Videos:/srv/bililive -p 8039:8080 -d chigusa/bililive-go"
      docker_describe="Bililive-go是一个支持多种直播平台的直播录制工具"
      docker_url="官网介绍: ${gh_proxy}https://github.com/hr3lxphr6j/bililive-go"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;

      40)

      docker_name="windows"
      docker_img="dockurr/windows"
      docker_port=8040
      docker_rum="docker run -d \
              --name windows \
              --cap-add=NET_ADMIN \
              -e VERSION=win11 \
              -e KVM=N \
              -p 8040:8006 \
              -p 3389:3389/tcp \
              -p 3389:3389/udp \
              --restart unless-stopped \
              dockurr/windows"
      docker_describe="一款虚拟化远程Windows11 要求2核心2G内存及以上"
      docker_url="官网介绍: ${gh_proxy}https://github.com/dockur/windows"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;

      41)
      send_stats "耗子面板"
      while true; do
        clear
        echo "耗子管理面板"
        echo "使用 Golang + Vue 开发的开源轻量 Linux 服务器运维管理面板。"
        echo "官方地址: ${gh_proxy}https://github.com/TheTNB/panel"
        echo "------------------------"
        echo "1. 安装            2. 管理            3. 卸载"
        echo "------------------------"
        echo "0. 返回上一级"
        echo "------------------------"
        read -e -p "输入你的选择: " choice

        case $choice in
          1)
            HAOZI_DL_URL="https://dl.cdn.haozi.net/panel"; curl -sSL -O ${HAOZI_DL_URL}/install_panel.sh && curl -sSL -O ${HAOZI_DL_URL}/install_panel.sh.checksum.txt && sha256sum -c install_panel.sh.checksum.txt && bash install_panel.sh || echo "Checksum 验证失败，文件可能被篡改，已终止操作"
            ;;
          2)
            panel
            ;;
          3)
            HAOZI_DL_URL="https://dl.cdn.haozi.net/panel"; curl -sSL -O ${HAOZI_DL_URL}/uninstall_panel.sh && curl -sSL -O ${HAOZI_DL_URL}/uninstall_panel.sh.checksum.txt && sha256sum -c uninstall_panel.sh.checksum.txt && bash uninstall_panel.sh || echo "Checksum 验证失败，文件可能被篡改，已终止操作"
            ;;
          0)
            break
            ;;
          *)
            break
            ;;

        esac
        break_end
      done
        ;;



42)

docker_name="vaultwarden"
docker_img="vaultwarden/server"
docker_port=3280

# 安装目录改为 /home/web/vaultwarden
install_dir="/home/web/vaultwarden"
mkdir -p "$install_dir"

docker_rum="docker run -d \
        --name vaultwarden \
        --restart always \
        -p 3280:80 \
        -v $install_dir/data:/data \
        vaultwarden/server"

docker_describe="一个开源的 Bitwarden 服务端实现，注册功能已开启"
docker_url="官网介绍: https://github.com/dani-garcia/vaultwarden"
docker_use=""
docker_passwd=""
docker_app
;;

43)
    # 交互式输入
    read -p "请输入 Vaultwarden 访问域名（如 https://mima.123.com）: " user_domain
    read -p "请输入 SMTP 邮件服务器（如 smtp.zoho.com）: " smtp_host
    read -p "请输入发件邮箱地址（如 admin@123.com）: " smtp_user
    read -p "请输入发件邮箱密码: " smtp_pass

    docker_name="vaultwarden"
    docker_img="vaultwarden/server"
    docker_port=3280

    # 安装目录改为 /home/web/vaultwarden
    install_dir="/home/web/vaultwarden"
    mkdir -p "$install_dir"

    docker_rum="docker run -d \
        --name vaultwarden \
        --restart always \
        -p 3280:80 \
        -e SIGNUPS_ALLOWED=false \
        -e SIGNUPS_VERIFY=true \
        -e DOMAIN=${user_domain} \
        -e SMTP_HOST=${smtp_host} \
        -e SMTP_FROM=${smtp_user} \
        -e SMTP_PORT=587 \
        -e SMTP_SECURITY=starttls \
        -e SMTP_USERNAME=${smtp_user} \
        -e SMTP_PASSWORD=${smtp_pass} \
        -v $install_dir/data:/data \
        vaultwarden/server"

    docker_describe="Vaultwarden 禁止注册 + SMTP 邮件设置（支持自定义域名和发信配置）"
    docker_url="官网介绍: https://github.com/dani-garcia/vaultwarden"
    docker_use="echo -e '\033[32m访问地址：$user_domain\033[0m\n邮箱发件人：$smtp_user（SMTP 启用）'"
    docker_passwd=""

    docker_app
    ;;


44)

docker_name="vaultwarden"
docker_img="vaultwarden/server"
docker_port=3280

# 安装目录改为 /home/web/vaultwarden
install_dir="/home/web/vaultwarden"
mkdir -p "$install_dir"

docker_rum="docker run -d \
        --name vaultwarden \
        -e SIGNUPS_ALLOWED=false \
        --restart always \
        -p 3280:80 \
        -v $install_dir/data:/data \
        vaultwarden/server"

docker_describe="一个开源的 Bitwarden 服务端实现（禁止注册，无 SMTP 设置）"
docker_url="官网介绍: https://github.com/dani-garcia/vaultwarden"
docker_use=""
docker_passwd=""
docker_app
;;

45)
    # 交互式输入
    read -p "请输入 Vaultwarden 访问域名（如 https://mima.123.com）: " user_domain
    read -p "请输入 SMTP 邮件服务器（如 smtp.zoho.com）: " smtp_host
    read -p "请输入发件邮箱地址（如 admin@123.com）: " smtp_user
    read -p "请输入发件邮箱密码: " smtp_pass

    docker_name="vaultwarden"
    docker_img="vaultwarden/server"
    docker_port=3280

    # 安装目录改为 /home/web/vaultwarden
    install_dir="/home/web/vaultwarden"
    mkdir -p "$install_dir"

    docker_rum="docker run -d \
        --name vaultwarden \
        --restart always \
        -p 3280:80 \
        -e SIGNUPS_VERIFY=true \
        -e DOMAIN=${user_domain} \
        -e SMTP_HOST=${smtp_host} \
        -e SMTP_FROM=${smtp_user} \
        -e SMTP_PORT=587 \
        -e SMTP_SECURITY=starttls \
        -e SMTP_USERNAME=${smtp_user} \
        -e SMTP_PASSWORD=${smtp_pass} \
        -v $install_dir/data:/data \
        vaultwarden/server"

    docker_describe="Vaultwarden 可以注册 + SMTP 邮件设置（支持自定义域名和发信配置）"
    docker_url="官网介绍: https://github.com/dani-garcia/vaultwarden"
    docker_use="echo -e '\033[32m访问地址：$user_domain\033[0m\n邮箱发件人：$smtp_user（SMTP 启用）'"
    docker_passwd=""

    docker_app
;;


      46)


      RPC_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c16)

      docker_name="aria2-pro"
      docker_img="p3terx/aria2-pro"
      docker_port=6800
      docker_rum="docker run -d --restart=always \
              --name aria2-pro \
              -p 6800:6800 \
              -p 6888:6888 \
              -p 6888:6888/udp \
              -e RPC_SECRET=$RPC_SECRET \
              -e UPDATE_TRACKERS=true \
              -v /home/docker/aria2/config:/config \
              -v /home/docker/aria2/downloads:/downloads \
              p3terx/aria2-pro"
      docker_describe="Aria2 下载神器，支持 BT、磁力、百度网盘，配套 AriaNg 使用，自动更新 Tracker"
      docker_url="访问地址: http://ariang.js.org        项目地址: https://hub.docker.com/r/p3terx/aria2-pro"
      docker_use="echo \"✅ 默认 RPC 密钥: $RPC_SECRET\" && echo \"🌐 AriaNg 访问地址：http://ariang.js.org/\""
      docker_passwd=""
      docker_app
        ;;


          47)
            send_stats "搭建网盘"
            has_ipv4_has_ipv6

            docker_name=cloudreve
            docker_port=5212
            while true; do
              check_docker_app
              clear
              echo -e "网盘服务 $check_docker"
              echo "cloudreve是一个支持多家云存储的网盘系统"
              echo "视频介绍: https://www.bilibili.com/video/BV13F4m1c7h7?t=0.1"
              if docker inspect "$docker_name" &>/dev/null; then
                check_docker_app_ip
              fi
              echo ""

              echo "------------------------"
              echo "1. 安装           2. 更新           3. 卸载"
              echo "------------------------"
              echo "0. 返回上一级"
              echo "------------------------"
              read -e -p "输入你的选择: " choice

              case $choice in
                1)
                  install_docker

      [ ! -d /home/docker ] && mkdir -p /home/docker

      cd /home/docker && mkdir -p wangpan/cloudreve/{uploads,avatar} wangpan/aria2/config wangpan/data/aria2
                  touch /home/docker/wangpan/cloudreve/conf.ini

                  chmod -R 777 /home/docker/wangpan/data/aria2

                  cat > /home/docker/wangpan/aria2/config/aria2.conf <<EOF
enable-rpc=true
rpc-listen-port=6800
rpc-secret=cloudreve
continue=true
max-concurrent-downloads=10
max-connection-per-server=5
split=5
min-split-size=10M
bt-enable-lpd=true
bt-require-crypto=false
bt-enable-dht=true
bt-enable-trackers=true
EOF

                  cat > /home/docker/wangpan/docker-compose.yml <<EOF
version: '3'
services:
  cloudreve:
    image: cloudreve/cloudreve:4.10.1
    container_name: cloudreve
    restart: always
    ports:
      - "5212:5212"
    volumes:
      - /home/docker/wangpan/cloudreve/uploads:/cloudreve/uploads
      - /home/docker/wangpan/cloudreve/avatar:/cloudreve/avatar
      - /home/docker/wangpan/cloudreve/conf.ini:/cloudreve/conf.ini
      - /home/docker/wangpan/cloudreve/data:/cloudreve/data

  aria2:
    image: p3terx/aria2-pro
    container_name: aria2
    restart: always
    environment:
      - RPC_SECRET=cloudreve
      - UPDATE_TRACKERS=true
    ports:
      - "6800:6800"
    volumes:
      - /home/docker/wangpan/aria2/config:/config
      - /home/docker/wangpan/data/aria2:/downloads
EOF

                  cd /home/docker/wangpan && docker compose up -d

                  clear
                  echo "cloudreve已经安装完成"
                  check_docker_app_ip
                  sleep 3
                  docker logs cloudreve
                  echo ""
                  ;;
                2)
                  docker rm -f cloudreve aria2
                  docker rmi -f cloudreve/cloudreve:4.10.1 p3terx/aria2-pro

                  cd /home/docker && mkdir -p wangpan/cloudreve/{uploads,avatar} wangpan/aria2/config wangpan/data/aria2
                  touch /home/docker/wangpan/cloudreve/conf.ini

                  chmod -R 777 /home/docker/wangpan/data/aria2

                  cat > /home/docker/wangpan/aria2/config/aria2.conf <<EOF
enable-rpc=true
rpc-listen-port=6800
rpc-secret=cloudreve
continue=true
max-concurrent-downloads=10
max-connection-per-server=5
split=5
min-split-size=10M
bt-enable-lpd=true
bt-require-crypto=false
bt-enable-dht=true
bt-enable-trackers=true
EOF

                  cat > /home/docker/wangpan/docker-compose.yml <<EOF
version: '3'
services:
  cloudreve:
    image: cloudreve/cloudreve:4.10.1
    container_name: cloudreve
    restart: always
    ports:
      - "5212:5212"
    volumes:
      - /home/docker/wangpan/cloudreve/uploads:/cloudreve/uploads
      - /home/docker/wangpan/cloudreve/avatar:/cloudreve/avatar
      - /home/docker/wangpan/cloudreve/conf.ini:/cloudreve/conf.ini
      - /home/docker/wangpan/cloudreve/data:/cloudreve/data

  aria2:
    image: p3terx/aria2-pro
    container_name: aria2
    restart: always
    environment:
      - RPC_SECRET=cloudreve
      - UPDATE_TRACKERS=true
    ports:
      - "6800:6800"
    volumes:
      - /home/docker/wangpan/aria2/config:/config
      - /home/docker/wangpan/data/aria2:/downloads
EOF

                  cd /home/docker/wangpan && docker compose up -d
                  clear
                  echo "cloudreve已经更新完成"
                  check_docker_app_ip
                  sleep 3
                  docker logs cloudreve
                  echo ""
                  ;;
                3)
                  docker rm -f cloudreve aria2
                  docker rmi -f cloudreve/cloudreve:4.10.1 p3terx/aria2-pro
                  rm -rf /home/docker/wangpan
                  echo "应用已卸载"
                  ;;
                0)
                  break
                  ;;
                *)
                  break
                  ;;
              esac
              break_end
            done
            ;;




48)
            while true; do
              clear
              echo -e "------------------------------------------------"
              echo -e "         Nexterm 维护者编译与发布工具"
              echo -e "------------------------------------------------"
              echo -e "21) 自动检测并安装构建环境 (Node, pnpm, Docker)"
              echo -e "22) 克隆源码并编译 Docker 镜像"
              echo -e "23) 登录 Docker Hub"
              echo -e "24) 推送镜像到 Docker Hub (zaixiangjian/nexterm)"
              echo -e "------------------------------------------------"
              echo -e "5) 安装并运行本地容器 (测试用)"
              echo -e "6) 更新已安装容器"
              echo -e "7) 卸载并删除目录"
              echo -e "8) 备份 Nexterm"
              echo -e "9) 恢复 Nexterm"
              echo -e "------------------------------------------------"
              echo -e "0) 返回主菜单"
              echo -e "------------------------------------------------"
              read -p "请输入操作编号: " dev_choice

              # 共享配置变量
              base_dir="/home/docker/nexterm"
              nexterm_dir="/home/docker/nexterm/data"
              docker_name="nexterm"
              docker_img="zaixiangjian/nexterm:latest"
              docker_port=6989

              case $dev_choice in
                21)
                    echo "开始环境自检..."
                    
                    # 1. 检查 Docker
                    if ! command -v docker &> /dev/null; then
                        echo "未检测到 Docker，正在安装..."
                        curl -fsSL https://get.docker.com | bash -
                        systemctl enable --now docker
                    else
                        echo "✅ Docker 已安装"
                    fi

                    # 2. 检查 Node.js
                    if ! command -v node &> /dev/null; then
                        echo "未检测到 Node.js，正在安装 (NodeSource v20)..."
                        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
                        apt-get install -y nodejs
                    else
                        echo "✅ Node.js 已安装: $(node -v)"
                    fi

                    # 3. 检查 pnpm
                    if ! command -v pnpm &> /dev/null; then
                        echo "未检测到 pnpm，正在安装..."
                        npm install -g pnpm
                    else
                        echo "✅ pnpm 已安装: $(pnpm -v)"
                    fi

                    # 4. 开放防火墙端口 6989
                    echo "正在检查防火墙并放行端口 ${docker_port}..."
                    if command -v ufw &> /dev/null; then
                        ufw allow ${docker_port}/tcp
                    elif command -v firewall-cmd &> /dev/null; then
                        firewall-cmd --permanent --add-port=${docker_port}/tcp
                        firewall-cmd --reload
                    fi

                    echo "✅ 环境准备就绪！"
                    sleep 2
                    read -n1 -r -p "回车继续..." key
                    ;;
                22)
                    echo "正在克隆并编译镜像..."
                    # 检查是否安装了 git
                    if ! command -v git &> /dev/null; then apt-get install -y git; fi
                    
                    mkdir -p /home/docker/build_temp
                    cd /home/docker/build_temp
                    rm -rf Nexterm
                    git clone https://github.com/zaixiangjian/Nexterm.git
                    cd Nexterm
                    
                    echo "开始构建 Docker 镜像，这可能需要几分钟..."
                    docker build -t $docker_img .
                    
                    if [ $? -eq 0 ]; then
                        echo "✅ 镜像构建完成: $docker_img"
                    else
                        echo "❌ 镜像构建失败，请检查源码或 Dockerfile"
                    fi
                    sleep 2
                    read -n1 -r -p "回车继续..." key
                    ;;
                23)
                    echo "正在登录 Docker Hub..."
                    docker login
                    read -n1 -r -p "回车继续..." key
                    ;;
                24)
                    echo "正在推送镜像至云端..."
                    docker push $docker_img
                    [ $? -eq 0 ] && echo "✅ 推送成功！" || echo "❌ 推送失败"
                    sleep 2
                    read -n1 -r -p "回车继续..." key
                    ;;
                5)
                    if docker ps -a --format '{{.Names}}' | grep -qw $docker_name; then
                        echo "❌ 容器 $docker_name 已经存在"
                    else
                        encryption_key=$(openssl rand -hex 32)
                        mkdir -p $nexterm_dir
                        docker run -d --name $docker_name -e ENCRYPTION_KEY=$encryption_key --restart always -p ${docker_port}:6989 -v $nexterm_dir:/app/data $docker_img
                        echo "✅ 运行成功！"
                        echo "本地访问地址: http://$(hostname -I | awk '{print $1}'):${docker_port}"
                        echo "初始化密钥: $encryption_key"
                    fi
                    sleep 3
                    read -n1 -r -p "回车继续..." key
                    ;;
                6)
                    # 自动获取密钥更新
                    old_key=$(docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' $docker_name 2>/dev/null | grep ENCRYPTION_KEY | cut -d'=' -f2)
                    if [ -z "$old_key" ]; then
                        echo "❌ 容器未运行，无法自动获取密钥升级"
                    else
                        echo "同步镜像并重启容器..."
                        docker pull $docker_img
                        docker rm -f $docker_name
                        docker run -d --name $docker_name -e ENCRYPTION_KEY=$old_key --restart always -p ${docker_port}:6989 -v $nexterm_dir:/app/data $docker_img
                        echo "✅ 更新完成"
                    fi
                    sleep 2
                    read -n1 -r -p "回车继续..." key
                    ;;
                7)
                    read -p "🚨 危险操作：确认卸载并彻底删除本地目录 $base_dir？[y/N]: " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        docker rm -f $docker_name 2>/dev/null
                        rm -rf "$base_dir"
                        echo "✅ 容器已删除，目录已彻底清理。"
                    fi
                    sleep 2
                    read -n1 -r -p "回车继续..." key
                    ;;
                8)
                    echo "正在执行备份..."
                    timestamp=$(date +%Y%m%d%H%M%S)
                    [ ! -d "$nexterm_dir" ] && echo "❌ 数据目录不存在" && break
                    tar -czf "/home/docker/nexterm-${timestamp}.tar.gz" -C "$base_dir" data
                    echo "✅ 备份成功: /home/docker/nexterm-${timestamp}.tar.gz"
                    sleep 2
                    ;;
                9)
                    backups=($(ls -1t /home/docker/nexterm-*.tar.gz 2>/dev/null))
                    if [ ${#backups[@]} -eq 0 ]; then
                        echo "❌ 目录下未发现备份文件"
                    else
                        for i in "${!backups[@]}"; do echo "$((i+1)). $(basename ${backups[$i]})"; done
                        read -p "请选择恢复编号: " sel
                        restore_file="${backups[$((sel-1))]}"
                        read -p "请输入对应的原始加密密钥: " e_key
                        
                        docker rm -f $docker_name 2>/dev/null
                        rm -rf "$base_dir" && mkdir -p "$nexterm_dir"
                        tar -xzf "$restore_file" -C "$base_dir"
                        
                        docker run -d --name $docker_name -e ENCRYPTION_KEY=$e_key --restart always -p ${docker_port}:6989 -v $nexterm_dir:/app/data $docker_img
                        echo "✅ 恢复完成！"
                    fi
                    sleep 2
                    read -n1 -r -p "回车继续..." key
                    ;;
                0) break ;;
                *) echo "无效选择"; sleep 1 ;;
              esac
            done
            ;;

      49)
        echo "▶️ 正在启动 vaultwarden 安装..."
        run_local_first_app_script "▶️ 安装vaultwarden..." "/root/yingyong/vaultwarden.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/vaultwarden.sh"
        echo "✅ vaultwarden 安装成功..."
        ;;

      50)

        PASSWORD="111111"

        docker_name="moontv"
        docker_img="ghcr.io/senshinya/moontv:latest"
        docker_port=3000
        docker_rum="docker run -d \
          --name moontv \
          --restart unless-stopped \
          -p 3000:3000 \
          -e PASSWORD=$PASSWORD \
          $docker_img"
        docker_describe="MoonTV 是一个 IPTV 播放平台，支持多种源解析"
        docker_url="项目地址: https://github.com/Senshinya/MoonTV"
        docker_use="echo \"✅ 设置密码: $PASSWORD\" && echo \"🌐 访问地址: http://localhost:$docker_port\""
        docker_passwd=""
        docker_app
          ;;

      51)
        clear
        echo "▶️ 正在运行极光面板一键脚本..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/deploy/main/install.sh)
        echo "✅ 极光面板脚本运行完成，若你选择了安装，请访问 http://服务器IP:8000"
        ;;

      52)
        run_local_first_app_script "▶️ 安装Emby..." "/root/yingyong/52Emby.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/52Emby.sh"
        echo "✅ Emby 安装成功..."
        ;;

      53)
        run_local_first_app_script "▶️ 安装nextermSSH..." "/root/yingyong/nexterm.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/nexterm.sh"
        echo "✅ nextermSSH 安装成功..."
        ;;

      54)
      while true; do
        clear
        echo "----------------------------"
        echo " 1. 安装并启动 webssh"
        echo " 2. 重设密码并重启服务"
        echo " 3. 卸载 webssh"
        echo " 0. 退出"
        echo "----------------------------"
        echo -n "请输入你的选择: "
        read choice

        case $choice in
          1)
            # 安装
            if [ ! -d /home/docker/webssh ]; then
              mkdir -p /home/docker/webssh > /dev/null 2>&1
            fi

            wget -O /home/docker/webssh/webssh_linux_amd64 https://github.com/zaixiangjian/ziyongcdn/releases/download/1.29/webssh_linux_amd64 > /dev/null 2>&1
            chmod +x /home/docker/webssh/webssh_linux_amd64

            password=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 18)

            pkill -f /home/docker/webssh/webssh_linux_amd64 > /dev/null 2>&1 || true

            nohup /home/docker/webssh/webssh_linux_amd64 -p 5032 -a admin:$password >/dev/null 2>&1 &

            crontab -l 2>/dev/null | grep -v '/home/docker/webssh/webssh_linux_amd64' > /tmp/crontab.$$
            echo "@reboot sleep 10 && nohup /home/docker/webssh/webssh_linux_amd64 -p 5032 -a admin:$password >/dev/null 2>&1 &" >> /tmp/crontab.$$
            crontab /tmp/crontab.$$
            rm -f /tmp/crontab.$$

            echo
            echo "安装完成"
            echo "访问地址: http://$(hostname -I | awk '{print $1}'):5032"
            echo "账号: admin"
            echo "密码: $password"
            echo "密码只显示一次，请妥善保存！"
            read -p "按任意键返回菜单..."

            ;;
          2)
            # 重设密码
            if [ ! -x /home/docker/webssh/webssh_linux_amd64 ]; then
              echo "未检测到 webssh 服务，请先安装！"
              read -p "按任意键返回菜单..."
              continue
            fi

            password=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 18)

            pkill -f /home/docker/webssh/webssh_linux_amd64 > /dev/null 2>&1 || true

            nohup /home/docker/webssh/webssh_linux_amd64 -p 5032 -a admin:$password >/dev/null 2>&1 &

            echo
            echo "密码已重置"
            echo "访问地址: http://$(hostname -I | awk '{print $1}'):5032"
            echo "账号: admin"
            echo "新密码: $password"
            echo "密码只显示一次，请妥善保存！"
            read -p "按任意键返回菜单..."

            ;;
          3)
            # 卸载
            echo "正在卸载 webssh..."
            pkill -f /home/docker/webssh/webssh_linux_amd64 > /dev/null 2>&1 || true
            crontab -l 2>/dev/null | grep -v '/home/docker/webssh/webssh_linux_amd64' | crontab -
            rm -rf /home/docker/webssh
            echo "卸载完成！"
            read -p "按任意键返回菜单..."
            ;;
          0)
            exit 0
            ;;
          *)
            echo "无效输入，请重新选择"
            read -p "按任意键继续..."
            ;;
        esac
      done
      ;;

55)
      INSTALL_PATH="/home/docker/openlist"
      SERVICE_FILE="/etc/systemd/system/openlist.service"
      
      echo "------------------------"
      echo "  OpenList 系统服务管理"
      echo "------------------------"
      echo " 1. 安装 OpenList (Systemd 守护运行)"
      echo " 2. 卸载 OpenList (完全清理)"
      echo " 0. 返回上一级"
      echo "------------------------"
      read -p "请输入选择 [0-2]: " sub_opt

      case $sub_opt in
        1)
          # --- 1. 下载与安装 ---
          mkdir -p "$INSTALL_PATH" > /dev/null 2>&1
          ARCH="amd64"
          [[ "$(uname -m)" == "aarch64" ]] && ARCH="arm64"
          
          echo "正在下载 OpenList ($ARCH)..."
          wget -O "$INSTALL_PATH/openlist.tar.gz" "https://github.com/zaixiangjian/ziyongcdn/releases/download/4.0.8/openlist-linux-$ARCH.tar.gz" > /dev/null 2>&1
          
          if [ ! -s "$INSTALL_PATH/openlist.tar.gz" ]; then
            echo "错误：下载失败！"
            return 1
          fi

          tar -xzf "$INSTALL_PATH/openlist.tar.gz" -C "$INSTALL_PATH/" > /dev/null 2>&1
          chmod +x "$INSTALL_PATH/openlist"

          # --- 2. 创建 Systemd 服务文件 ---
          echo "正在配置 Systemd 服务..."
          cat <<EOF > $SERVICE_FILE
[Unit]
Description=OpenList Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/openlist server
Restart=on-failure
RestartSec=5
StandardOutput=append:$INSTALL_PATH/openlist.log
StandardError=append:$INSTALL_PATH/openlist.log

[Install]
WantedBy=multi-user.target
EOF

          # --- 3. 启动服务 ---
          /bin/systemctl daemon-reload
          /bin/systemctl enable openlist > /dev/null 2>&1
          /bin/systemctl restart openlist

          echo "等待程序初始化并获取密码..."
          password=""
          for i in {1..15}; do
            sleep 1
            password=$(grep "initial password is:" "$INSTALL_PATH/openlist.log" | tail -n 1 | awk '{print $NF}')
            [ -n "$password" ] && break
          done

          ipv4=$(curl -s4 --max-time 3 ifconfig.me)

          clear
          echo "✅ OpenList 已通过 Systemd 安装成功"
          echo "------------------------------------------------"
          echo "服务状态：$(/bin/systemctl is-active openlist)"
          [ -n "$ipv4" ] && echo "访问地址：http://$ipv4:5244"
          [ -n "$password" ] && echo "初始密码：$password"
          echo "------------------------------------------------"
          echo "常用命令："
          echo "查看状态: systemctl status openlist"
          echo "停止服务: systemctl stop openlist"
          echo "查看日志: journalctl -u openlist -f"
          echo "------------------------------------------------"
          ;;

        2)
          # --- 卸载逻辑 ---
          echo "正在停止服务并清理残留..."
          /bin/systemctl stop openlist > /dev/null 2>&1
          /bin/systemctl disable openlist > /dev/null 2>&1
          rm -f "$SERVICE_FILE"
          /bin/systemctl daemon-reload
          /bin/systemctl reset-failed openlist > /dev/null 2>&1 || true
          docker rm -f openlist > /dev/null 2>&1 || true
          rm -rf "$INSTALL_PATH"
          
          # 清理旧的 crontab 防止冲突
          crontab -l 2>/dev/null | grep -v "$INSTALL_PATH/openlist" | crontab -
          
          echo "✅ 卸载完成！所有文件和服务已移除。"
          ;;
        *)
          return 0
          ;;
      esac
      
      echo ""
      read -p "按回车键继续..."
      ;;



      56)
      docker_name="umami"
      docker_img="docker.umami.is/umami-software/umami:postgresql-latest"
      docker_port=3000

      install_dir="/home/docker/umami"
      mkdir -p "$install_dir"

      umami_app_secret=$(openssl rand -hex 16)
      docker_rum="mkdir -p $install_dir && cd $install_dir && cat > docker-compose.yml <<UMAMI_EOF
version: '3.8'

services:
  umami-db:
    image: postgres:15
    container_name: umami-db
    restart: always
    environment:
      POSTGRES_DB: umami
      POSTGRES_USER: umami
      POSTGRES_PASSWORD: umami123
    volumes:
      - ./postgres:/var/lib/postgresql/data

  umami:
    image: docker.umami.is/umami-software/umami:postgresql-latest
    container_name: umami
    restart: always
    ports:
      - \"3000:3000\"
    environment:
      DATABASE_URL: postgres://umami:umami123@umami-db:5432/umami
      APP_SECRET: ${umami_app_secret}
    depends_on:
      - umami-db
UMAMI_EOF
docker compose up -d"

      docker_describe="Umami 网站流量统计系统，轻量、隐私友好"
      docker_url="GitHub: https://github.com/umami-software/umami"
      docker_use="echo -e '\033[32m访问地址：http://服务器IP:3000，默认账号：admin 默认密码：umami\033[0m'"
      docker_passwd=""
      docker_app
        ;;
    57)

      clear
      echo "Dify - 开源 AIGC 应用开发平台"
      echo "GitHub 项目地址: https://github.com/langgenius/dify"
      echo "功能介绍: 快速搭建属于自己的类 ChatGPT 平台，支持模型调用和 API 应用开发"
      echo
      echo "1. 安装 Dify"
      echo "2. 备份 Dify 数据"
      echo "3. 卸载 Dify"
      echo "4. 恢复 Dify 数据"
      read -p "请输入操作编号: " sub_choice

      dify_dir="/home/docker/dify"
      backup_dir="/home/docker"
      backup_prefix="dify"
      docker_compose_dir="${dify_dir}/docker"
      docker_compose_file="${docker_compose_dir}/docker-compose.yaml"  # 注意是 .yaml 不是 .yml
      docker_compose_env="${docker_compose_dir}/.env"
      local_ip=$(hostname -I | awk '{print $1}')
      ipv6_addr=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n 1)

      case "$sub_choice" in
        1)
          mkdir -p /home/docker
          cd /home/docker || exit

          if [ -d "$dify_dir" ]; then
            echo "检测到已有 Dify 目录，正在更新代码..."
            cd "$dify_dir" || exit
            git pull
          else
            echo "正在克隆 Dify 仓库..."
            git clone https://github.com/langgenius/dify.git
            cd "$dify_dir" || exit
          fi

          cd "$docker_compose_dir" || exit

          # 复制 .env 配置文件（如果不存在就复制示例）
          if [ ! -f "$docker_compose_env" ]; then
            cp -f .env.example "$docker_compose_env"
          fi

          # 修改 .env 文件，设置端口变量为 8058 和 8443
          sed -i "s/^NGINX_PORT=.*/NGINX_PORT=8058/" "$docker_compose_env"
          sed -i "s/^NGINX_SSL_PORT=.*/NGINX_SSL_PORT=8443/" "$docker_compose_env"
          sed -i "s/^EXPOSE_NGINX_PORT=.*/EXPOSE_NGINX_PORT=8058/" "$docker_compose_env"
          sed -i "s/^EXPOSE_NGINX_SSL_PORT=.*/EXPOSE_NGINX_SSL_PORT=8443/" "$docker_compose_env"

          # 确认docker-compose.yaml中ports字段是使用变量映射端口
          # 这里不修改docker-compose.yaml的端口映射，默认使用环境变量

          echo "启动 Dify 容器..."
          if docker compose up -d; then
            echo "------------------------"
            echo "Dify 安装完成"
            echo "访问地址: http://${local_ip}:8058"
            [ -n "$ipv6_addr" ] && echo "http://[${ipv6_addr}]:8058"
          else
            echo "Dify 启动失败，请检查 Docker 和网络配置"
          fi
          ;;

        2)
          if [ -d "$dify_dir" ]; then
            timestamp=$(date +%Y%m%d%H%M%S)
            backup_file="${backup_prefix}-${timestamp}.tar.gz"
            tar -czf "${backup_dir}/${backup_file}" -C "$dify_dir" .
            echo "备份完成: ${backup_dir}/${backup_file}"
          else
            echo "未检测到安装目录，无法备份"
          fi
          ;;

        3)
          read -p "确认卸载 Dify？将删除 /home/docker/dify 目录及所有数据，且停止所有相关容器 [y/N]: " confirm
          if [[ "$confirm" =~ ^[Yy]$ ]]; then
            if [ -f "$docker_compose_file" ]; then
              docker compose -f "$docker_compose_file" down
            else
              echo "docker-compose.yaml 文件不存在，跳过停止容器"
            fi
            rm -rf "$dify_dir"
            echo "Dify 已卸载完成"
          else
            echo "操作已取消"
          fi
          ;;

        4)
          echo "可用备份文件："
          backups=($(ls -1t $backup_dir/${backup_prefix}-*.tar.gz 2>/dev/null))
          if [ ${#backups[@]} -eq 0 ]; then
            echo "无可用备份"
            break
          fi

          for i in "${!backups[@]}"; do
            echo "$((i+1)). $(basename ${backups[$i]})"
          done
          read -p "请输入备份编号（留空恢复最新）: " sel

          if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -le "${#backups[@]}" ]; then
            restore_file="${backups[$((sel-1))]}"
          else
            restore_file="${backups[0]}"
          fi

          echo "恢复自: $(basename $restore_file)"

          if [ -f "$docker_compose_file" ]; then
            docker compose -f "$docker_compose_file" down
          else
            echo "docker-compose.yaml 文件不存在，跳过停止容器"
          fi

          rm -rf "$dify_dir"
          mkdir -p "$dify_dir"

          tar -xzf "$restore_file" -C "$dify_dir"

          cd "$docker_compose_dir" || exit

          echo "启动 Dify 容器..."
          if docker compose up -d; then
            echo "------------------------"
            echo "Dify 已恢复"
            echo "访问地址: http://${local_ip}:8058"
            [ -n "$ipv6_addr" ] && echo "http://[${ipv6_addr}]:8058"
          else
            echo "Dify 启动失败，请检查 Docker 和网络配置"
          fi
          ;;

        *)
          echo "无效选项"
          ;;
      esac

      read -p "按任意键继续..." -n1
      ;;
      58)
        clear
        echo "▶️ 正在下载并启动 caddy 安装脚本..."
        caddy_script="/root/caddy.sh"
        caddy_script_url="https://raw.githubusercontent.com/zaixiangjian/sh/main/anzhuangcaddy.sh"
        if curl -fsSL "$caddy_script_url" -o "$caddy_script"; then
          chmod +x "$caddy_script"
          bash "$caddy_script"
          echo "✅ caddy安装完成，脚本已保存到：$caddy_script"
        else
          echo "❌ 下载失败：$caddy_script_url"
          return 1
        fi
        ;;


  59)
  
    # 放行端口规则
    ufw allow 21115:21119/tcp
    ufw allow 21116/udp
    ufw reload



    docker_name="hbbs"
    docker_img="rustdesk/rustdesk-server"
    docker_port=21116
    docker_rum="docker run --name hbbs -v /root/rustdesk/amd64:/root -td --net=host --restart=always rustdesk/rustdesk-server hbbs"

    docker_describe="rustdesk开源的远程桌面(服务端)，类似自己的向日葵私服。"
    docker_url="官网介绍: https://rustdesk.com/zh-cn/"
    docker_use="docker logs hbbs"
    docker_passwd="echo \"把你的IP和key记录下，会在远程桌面客户端中用到。去44选项装中继端吧！\""
    docker_app
      ;;
  
  60)

    # 放行端口规则
    ufw allow 21115:21119/tcp
    ufw allow 21116/udp
    ufw reload



    docker_name="hbbr"
    docker_img="rustdesk/rustdesk-server"
    docker_port=21116
    docker_rum="docker run --name hbbr -v /root/rustdesk/amd64:/root -td --net=host --restart=always rustdesk/rustdesk-server hbbr"

    docker_describe="rustdesk开源的远程桌面(中继端)，类似自己的向日葵私服。"
    docker_url="官网介绍: https://rustdesk.com/zh-cn/"
    docker_use="echo \"前往官网下载远程桌面的客户端: https://rustdesk.com/zh-cn/\""
    docker_passwd=""
    docker_app
      ;;




      61) 
      clear
      echo "🔄 更新系统..."
      apt update -y && apt upgrade -y

      echo "📦 安装 unzip 和 npm..."
      apt install -y unzip npm

      INSTALL_DIR="/root/rustdesk"
      DOWNLOAD_URL="https://github.com/rustdesk/rustdesk-server/releases/download/1.1.14/rustdesk-server-linux-amd64.zip"
      TMP_DIR="/root/rustdesk"

      echo "🗑 删除旧版本目录..."
      rm -rf $INSTALL_DIR
      mkdir -p $INSTALL_DIR

      echo "🌐 下载 RustDesk Server..."
      wget -O $TMP_DIR/rustdesk.zip "$DOWNLOAD_URL" || { echo "❌ 下载失败，检查链接或网络。"; exit 1; }

      echo "📂 解压到 $INSTALL_DIR ..."
      unzip -o $TMP_DIR/rustdesk.zip -d $INSTALL_DIR || { echo "❌ 解压失败。"; exit 1; }

      # 检查解压后的目录结构
      if [ ! -d "$INSTALL_DIR/amd64" ]; then
        echo "❌ 解压后的目录结构不正确，未找到 /root/rustdesk/amd64"
        exit 1
      fi

      echo "📦 安装 PM2..."
      npm install -g pm2 || { echo "❌ 安装 PM2 失败。"; exit 1; }

      echo "🚀 启动 hbbs / hbbr ..."
      cd $INSTALL_DIR/amd64 || { echo "❌ 进入 RustDesk 目录失败。"; exit 1; }

      pm2 delete hbbs >/dev/null 2>&1 || true
      pm2 delete hbbr >/dev/null 2>&1 || true

      pm2 start hbbs || { echo "❌ 启动 hbbs 失败。"; exit 1; }
      pm2 start hbbr || { echo "❌ 启动 hbbr 失败。"; exit 1; }

      echo "🧷 设置 PM2 开机启动..."
      pm2 startup || { echo "❌ 设置 PM2 开机启动失败。"; exit 1; }
      pm2 save || { echo "❌ 保存 PM2 配置失败。"; exit 1; }

      echo "====================================="
      echo "🎉 RustDesk Server 安装成功！"
      echo "📌 安装目录：$INSTALL_DIR"
      echo "📌 程序目录：$INSTALL_DIR/amd64"
      echo "🚀 hbbs / hbbr 已启动并开机自启"
      echo "====================================="

      # 放行端口 21115-21119/tcp 和 21116/udp
      echo "🔓 放行 RustDesk 所需的端口..."
      sudo ufw allow 21115:21119/tcp
      sudo ufw allow 21116/udp
      sudo ufw reload

      echo "⚡ 防火墙规则已更新，允许 RustDesk 所需的端口。"
      ;;


62)
        while true; do
            clear
            echo "--- X-UI 安装管理界面 ---"
            echo " 1. 安装原版 x-ui (vaxilu)"
            echo " 2. 安装增强版 3x-ui (mhsanaei)"
            echo " 0. 返回上一级菜单"
            echo "------------------------"
            echo "删除程序目录"
            echo "------------------------"
            echo "rm -rf /usr/local/x-ui
rm -rf /etc/x-ui"
            echo "------------------------"
            read -p "请输入选项 [0-2]: " sub_num

            case $sub_num in
                1)
                    echo "▶️ 开始安装原版 x-ui..."
                    bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
                    break # 安装完退出子循环，回到主菜单
                    ;;
                2)
                    echo "▶️ 开始安装增强版 3x-ui..."
                    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
                    break
                    ;;
                0)
                    break # 跳出当前循环，返回主菜单
                    ;;
                *)
                    echo "❌ 输入错误，请重新选择"
                    sleep 1
                    ;;
            esac
        done
        ;;

      63)
        run_local_first_app_script "▶️ 安装RustFS..." "/root/yingyong/63RustFS.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/63RustFS.sh"
        echo "✅ RustFS安装成功..."
        ;;

      64)
        run_local_first_app_script "▶️ 安装SeaweedFS..." "/root/yingyong/64SeaweedFS.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/64SeaweedFS.sh"
        echo "✅ SeaweedFS安装成功..."
        ;;

      65)
        clear
        echo "▶️ 正在启动caddy DNS版 安装..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/anzhuangcaddydnspeizhi.sh)
        echo "✅ caddy DNS版 安装完成。"
        ;;

      66)
        clear
        echo "▶️ 正在启动caddy DNS配置版..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/anzhuangcaddydnspeizhipeizhiwenjian.sh)
        echo "✅ caddy DNS配置版 。"
        ;;



        67)
            # 交互式输入
            read -p "请输入 ownCloud 访问 IP（回车自动获取公网IP）: " user_ip
            if [ -z "$user_ip" ]; then
                user_ip=$(curl -s https://api.ipify.org)
                echo "自动获取公网IP: $user_ip"
            fi

            read -p "请输入访问域名（回车使用默认 www.wangpan.dev）: " user_domain
            if [ -z "$user_domain" ]; then
                user_domain="www.wangpan.dev"
                echo "使用默认域名: $user_domain"
            fi

            docker_name="owncloud"
            docker_img="owncloud/server:latest"
            docker_port=5210
            docker_rum="docker run -d \
                --name owncloud \
                --restart=unless-stopped \
                -p 5210:8080 \
                -v /home/docker/owncloud/data:/mnt/data \
                -e OWNCLOUD_DOMAIN=${user_ip},${user_domain} \
                -e OWNCLOUD_TRUSTED_DOMAINS=${user_ip},${user_domain} \
                -e OWNCLOUD_ADMIN_USERNAME=admin \
                -e OWNCLOUD_ADMIN_PASSWORD=admin123 \
                -e OWNCLOUD_DB_TYPE=sqlite \
                owncloud/server:latest"

            docker_describe="ownCloud 私有云文件存储，支持网页访问，SQLite 轻量版"
            docker_url="官网介绍: https://owncloud.com/"
            docker_use="echo -e '\033[32m访问地址：http://${user_ip}:5210 或 http://${user_domain}:5210\033[0m\n默认账号：admin 默认密码：admin'"

            docker_passwd=""

            docker_app
        ;;



      68)
        clear
        echo "▶️ 安装M38u8..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/m3u8xiazai.sh)
        echo "✅ 安装M38u8完成 。"
        ;;

    69)
        docker_name="it-tools"
        docker_img="corentinth/it-tools:latest"
        docker_port=8064
        docker_rum="docker run -d \
                        --name it-tools \
                        --restart always \
                        -p ${docker_port}:80 \
                        -v /home/docker/it-tools/data:/data \
                        ${docker_img}"
        docker_describe="对开发人员和 IT 工作者来说非常有用的工具"
        docker_url="官网介绍: https://github.com/CorentinTh/it-tools"
        docker_use=""
        docker_passwd=""
        docker_app
    ;;



    70)
        docker_name="pansou"
        docker_img="ghcr.io/fish2018/pansou-web"
        docker_port=8107
        docker_rum="docker run -d \
                        --name pansou \
                        --restart always \
                        -p ${docker_port}:80 \
                        -v /home/docker/pansou/data:/app/data \
                        -v /home/docker/pansou/logs:/app/logs \
                        -e ENABLED_PLUGINS=hunhepan,jikepan,panwiki,pansearch,panta,qupansou,susu,thepiratebay,wanou,xuexizhinan,panyq,zhizhen,labi,muou,ouge,shandian,duoduo,huban,cyg,erxiao,miaoso,fox4k,pianku,clmao,wuji,cldi,xiaozhang,libvio,leijing,xb6v,xys,ddys,hdmoli,yuhuage,u3c3,javdb,clxiong,jutoushe,sdso,xiaoji,xdyh,haisou,bixin,djgou,nyaa,xinjuc,aikanzy,qupanshe,xdpan,discourse,yunsou,ahhhhfs,nsgame,gying \
                        ${docker_img}"
        docker_describe="PanSou 是一个高性能的网盘资源搜索 API 服务。"
        docker_url="官网介绍: https://github.com/fish2018/pansou"
        docker_use=""
        docker_passwd=""
        docker_app
    ;;



    71)
        docker_name="zfile"
        docker_img="zhaojun1998/zfile:latest"
        docker_port=8109
        docker_rum="docker run -d \
                        --name zfile \
                        --restart always \
                        -p ${docker_port}:8080 \
                        -v /home/docker/zfile/db:/root/.zfile-v4/db \
                        -v /home/docker/zfile/logs:/root/.zfile-v4/logs \
                        -v /home/docker/zfile/file:/data/file \
                        -v /home/docker/zfile/application.properties:/root/.zfile-v4/application.properties \
                        ${docker_img}"
        docker_describe="是一个适用于个人或小团队的在线网盘程序。"
        docker_url="官网介绍: https://github.com/zfile-dev/zfile"
        docker_use=""
        docker_passwd=""
        docker_app
    ;;

      72)
        clear
        echo "▶️ 安装discourse论坛..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/discourse.sh)
        echo "✅ 安装discourse论坛 。"
        ;;

      73)
        run_local_first_app_script "▶️ 安装Matrix..." "/root/yingyong/73Matrix.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/73Matrix.sh"
        echo "✅ Matrix安装成功..."
        ;;

      74)
        run_local_first_app_script "▶️ 安装Mattermost..." "/root/yingyong/74Mattermost.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/74Mattermost.sh"
        echo "✅ Mattermost安装成功..."
        ;;

75)
while true; do
    clear
    echo "------------------------------------------------"
    echo "      Certimate SSL 证书管理工具 编译脚本"
    echo "------------------------------------------------"
    echo "【源码与镜像管理】"
    echo "1) 安装环境并修复 Docker"
    echo "2) 一键克隆源码并构建镜像"
    echo "3) 登录 Docker Hub"
    echo "4) 推送镜像到 Docker Hub"
    echo "------------------------------------------------"
    echo "【容器部署管理】"
    echo "11) 部署/启动 Certimate (/home/docker/certimate)"
    echo "12) 更新镜像到最新版本"
    echo "13) 卸载 Certimate"
    echo "0) 返回主菜单"
    echo "------------------------------------------------"
    read -p "请输入操作编号: " ct_choice

    # 核心变量配置
    my_github_url="https://github.com/zaixiangjian/certimate.git"
    my_docker_img="zaixiangjian/certimate:latest"


    case $ct_choice in
            1)
                echo -e "\n--- [1/3] 正在修复系统基础环境 ---"
                sudo rm /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock &>/dev/null
                sudo dpkg --configure -a
                sudo apt --fix-broken install -y
                
                echo -e "\n--- [2/3] 更新基础工具 ---"
                sudo apt update && sudo apt install -y git curl ca-certificates
                
                echo -e "\n--- [3/3] 检查并启动 Docker ---"
                if ! command -v docker &> /dev/null; then
                    curl -fsSL https://get.docker.com | bash -
                fi
                sudo systemctl enable --now docker
                sudo chmod 666 /var/run/docker.sock
                echo -e "\n✅ 环境准备就绪！"
                read -n1 -r -p "回车继续..." key
                ;;

            2)
                echo -e "\n--- 正在同步 Certimate 最新源码 ---"
                mkdir -p "$build_dir" && cd "$build_dir"
                [ -d "certimate" ] && rm -rf certimate
                
                git clone --depth 1 "$my_github_url"
                cd certimate
                
                echo -e "\n--- 开始执行 Docker 编译 (使用项目默认配置) ---"
                # 直接使用源码中的 Dockerfile 进行构建
                sudo docker build -t "$my_docker_img" .
                
                if [ $? -eq 0 ]; then
                    echo -e "\n✅ Certimate 镜像构建成功！"
                else
                    echo -e "\n❌ 编译失败，请检查 Dockerfile 内容或网络环境。"
                fi
                read -n1 -r -p "回车继续..." key
                ;;

            3)
                sudo docker login
                read -n1 -r -p "回车继续..." key
                ;;

            4)
                echo "正在推送镜像到 Docker Hub..."
                sudo docker push "$my_docker_img"
                read -n1 -r -p "回车继续..." key
                ;;

        11)
            echo "--- 部署/启动 Certimate ---"
            sudo docker rm -f certimate &>/dev/null
            mkdir -p "$install_dir/data"
            sudo chmod -R 777 "$install_dir/data"
            sudo docker run -d \
                --name certimate \
                --restart unless-stopped \
                -p 8090:8090 \
                -v /etc/localtime:/etc/localtime:ro \
                -v /etc/timezone:/etc/timezone:ro \
                -v "$install_dir/data:/app/pb_data" \
                "$my_docker_img"
            if [ $? -eq 0 ]; then
                loc_v4=$(hostname -I | awk '{print $1}')
                echo "✅ 启动成功！访问 http://$loc_v4:8090"
            else
                echo "❌ 启动失败"
            fi
                echo "账号"
                echo "admin@certimate.fun"
                echo "密码"
                echo "1234567890"
            read -n1 -r -p "回车继续..." key
            ;;

        12)
            echo "--- 拉取最新镜像 ---"
            sudo docker pull "$my_docker_img"
            echo "✅ 镜像已更新"
            read -n1 -r -p "回车继续..." key
            ;;


        13)
            echo "--- 卸载 Certimate ---"
            sudo docker rm -f certimate &>/dev/null
            sudo docker rmi "$my_docker_img" &>/dev/null
            sudo rm -rf "$install_dir"
            echo "✅ 已卸载完成"
            read -n1 -r -p "回车继续..." key
            ;;

            0) break ;;
            *) echo "无效选择"; sleep 1 ;;
        esac
    done
    ;;


76)

# 随机生成 ADMIN_TOKEN
ADMIN_TOKEN=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c20)

# 自动获取本机 IP（取第一个非 127.0.0.1 的 IP）
HOST_IP=$(hostname -I | awk '{print $1}')

docker_name="vaultwarden"
docker_img="vaultwarden/server"
docker_port=3280

# 安装目录改为 /home/web/vaultwarden
install_dir="/home/web/vaultwarden"
mkdir -p "$install_dir"

docker_rum="docker run -d \
                --name vaultwarden \
                -e SIGNUPS_ALLOWED=false \
                -e ADMIN_TOKEN=$ADMIN_TOKEN \
                --restart always \
                -p 3280:80 \
                -v $install_dir/data:/data \
                vaultwarden/server"

docker_describe="更改false改为true可注册，一个开源的 Bitwarden 服务端实现（禁止注册，自动生成管理员 Token，无 SMTP 设置）"
docker_url="官网介绍: https://github.com/dani-garcia/vaultwarden"
docker_use="echo \"✅ Vaultwarden 管理员 Token: $ADMIN_TOKEN\" && echo \"🌐 Web 访问: http://$HOST_IP:3280\""
docker_passwd=""
docker_app
;;





      77)
        clear
        echo "▶️ 全部caddy与nginx邮箱安装..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/mailnginxcaddy.sh)
        echo "✅ caddy与nginx邮箱安装完成..."
        ;;




      78)
        clear
        echo "▶️ mailcow-dockerized邮箱安装..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/mailcaddy.sh)
        echo "✅ mailcow-dockerized邮箱安装完成..."
        ;;






79)
            clear
            echo "Nexterm - 基于 Web 的终端访问工具 (zaixiangjian 编译版)"
            echo "官方 GitHub: https://github.com/gnmyt/Nexterm"
            echo "功能介绍: 使用浏览器远程访问主机终端，支持 SSH、VNC、RDP 及 SFTP"
            echo "------------------------------------------------"
            echo "1. 安装 Nexterm"
            echo "2. 备份 Nexterm"
            echo "------------------------------------------------"
            echo "3. 卸载 Nexterm (彻底删除本地数据)"
            echo "------------------------------------------------"
            echo "4. 恢复 Nexterm"
            echo "99. 更新 Nexterm 镜像 (自动继承配置)"
            echo "0. 返回主菜单"
            echo "------------------------------------------------"
            read -p "请输入操作编号: " sub_choice

            # 配置信息
            base_dir="/home/docker/nexterm"
            nexterm_dir="/home/docker/nexterm/data"
            backup_dir="/home/docker"
            backup_prefix="nexterm"
            docker_name="nexterm"
            docker_img="zaixiangjian/nexterm:latest"
            docker_port=6989

            local_ip=$(hostname -I | awk '{print $1}')
            ipv6_addr=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n 1)

            case "$sub_choice" in
                1)
                    if docker ps -a --format '{{.Names}}' | grep -qw $docker_name; then
                        echo "$docker_name 已经安装完成"
                    else
                        encryption_key=$(openssl rand -hex 32)
                        mkdir -p $nexterm_dir
                        docker run -d \
                            --name $docker_name \
                            -e ENCRYPTION_KEY=$encryption_key \
                            --restart always \
                            -p ${docker_port}:6989 \
                            -v $nexterm_dir:/app/data \
                            $docker_img
                        echo "------------------------------------------------"
                        echo "✅ $docker_name 安装成功"
                        echo "加密密钥为: $encryption_key (请务必保存)"
                    fi
                    ;;
                2)
                    echo "正在备份..."
                    timestamp=$(date +%Y%m%d%H%M%S)
                    backup_file="${backup_prefix}-${timestamp}.tar.gz"
                    [ ! -d "$nexterm_dir" ] && echo "错误: 目录不存在" && break
                    tar -czf "${backup_dir}/${backup_file}" -C "$base_dir" data
                    echo "✅ 备份成功！保存为: ${backup_dir}/${backup_file}"
                    ls -t ${backup_dir}/${backup_prefix}-*.tar.gz | sed -n '4,$p' | xargs -r rm -f
                    ;;
                3)
                    read -p "🚨 确认卸载并彻底删除数据？将执行 [rm -rf $base_dir] [y/N]: " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        echo "正在停止并删除容器..."
                        docker rm -f $docker_name 2>/dev/null
                        echo "正在清理本地文件夹..."
                        rm -rf "$base_dir"
                        echo "✅ Nexterm 已彻底卸载，数据已清空。"
                    else
                        echo "操作已取消。"
                    fi
                    ;;
                4)
                    echo "可用备份清单："
                    backups=($(ls -1t $backup_dir/${backup_prefix}-*.tar.gz 2>/dev/null))
                    [ ${#backups[@]} -eq 0 ] && echo "❌ 无备份" && break
                    for i in "${!backups[@]}"; do echo "$((i+1)). $(basename ${backups[$i]})"; done
                    read -p "选择编号: " sel
                    restore_file="${backups[$((sel-1))]:-${backups[0]}}"
                    
                    read -p "请输入原始加密密钥: " encryption_key
                    [ -z "$encryption_key" ] && echo "密钥不能为空" && break

                    docker rm -f $docker_name 2>/dev/null
                    rm -rf "$base_dir"
                    mkdir -p "$nexterm_dir"
                    tar -xzf "$restore_file" -C "$base_dir"
                    
                    docker run -d --name $docker_name -e ENCRYPTION_KEY=$encryption_key --restart always -p ${docker_port}:6989 -v $nexterm_dir:/app/data $docker_img
                    echo "✅ 数据已恢复。"
                    ;;
                99)
                    echo "检查更新中..."
                    old_key=$(docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' $docker_name 2>/dev/null | grep ENCRYPTION_KEY | cut -d'=' -f2)
                    if [ -z "$old_key" ]; then
                        echo "❌ 容器未运行，无法自动获取密钥。"
                    else
                        docker pull $docker_img
                        docker rm -f $docker_name 2>/dev/null
                        docker run -d --name $docker_name -e ENCRYPTION_KEY=$old_key --restart always -p ${docker_port}:6989 -v $nexterm_dir:/app/data $docker_img
                        echo "✅ 更新完成！"
                    fi
                    ;;
                0) break ;;
                *) echo "无效选项" ;;
            esac
            read -p "按任意键继续..." -n1
            ;;


80)
while true; do

  clear
  echo -e "------------------------------------------------"
  echo -e "         Sun-Panel 镜像维护工具"
  echo -e "------------------------------------------------"
  echo -e "21) 安装依赖环境 (Node.js, pnpm, Docker)"
  echo -e "22) 克隆源码并编译 Docker 镜像"
  echo -e "23) 登录 Docker Hub"
  echo -e "24) 推送镜像到 Docker Hub (zaixiangjian/sun-panel:latest)"
  echo -e "5) 安装并运行 sun-panel 容器 (/home/docker/sun-panel)"
  echo -e "6) 更新已安装容器"
  echo -e "7) 卸载 sun-panel 并删除 /home/docker/sun-panel"
  echo -e "8) 备份 sun-panel 数据到 /home/docker"
  echo -e "9) 恢复 sun-panel 数据并自动启动"
  echo -e "0) 返回主菜单"
  echo -e "------------------------------------------------"
  read -e -p "请输入选择: " choice

  case $choice in
    21)
      echo -e "\n🚀 安装依赖环境..."
      apt update && apt install -y curl git build-essential lsb-release ca-certificates gnupg
      curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
      apt install -y nodejs
      npm install -g pnpm

      if ! command -v docker &>/dev/null; then
        echo "安装 Docker..."
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      else
        echo "Docker 已安装，跳过。"
      fi
      sleep 2
      read -n1 -r -p "回车继续..." key
      ;;

    22)
      echo -e "\n📂 克隆源码并编译 Docker 镜像..."
      mkdir -p /home/docker
      cd /home/docker
      rm -rf sun-panel
      git clone https://github.com/zaixiangjian/sun-panel.git
      cd sun-panel
      git checkout dev
      git pull

      echo -e "\n📝 修改 package.json build 脚本..."
      sed -i 's/"build": "run-p add-version type-check build-only"/"build": "run-p add-version build-only"/' package.json

      echo -e "\n📦 安装依赖..."
      pnpm install

      echo -e "\n🏗️ 编译前端..."
      pnpm build

      echo -e "\n📦 安装 go-bindata 工具..."
      go install github.com/elazarl/go-bindata-assetfs/...@latest

      echo -e "\n🏗️ 生成 Go 绑定资源..."
      cd service
      go-bindata-assetfs -o assets/bindata.go -pkg assets ../dist/assets/...

      echo -e "\n🏗️ 编译 Go 后端..."
      go build -o /home/docker/sun-panel/sun-panel main.go

      echo -e "\n🐳 构建 Docker 镜像 sun-panel:latest ..."
      cd /home/docker/sun-panel
      docker build -t sun-panel .

      echo -e "\n✅ 编译和 Docker 构建完成！"
      sleep 2
      read -n1 -r -p "回车继续..." key
      ;;

    23)
      echo -e "\n🔑 登录 Docker Hub ..."
      docker login
      read -n1 -r -p "回车继续..." key
      ;;

    24)
      echo -e "\n📤 推送镜像到 Docker Hub ..."
      docker tag sun-panel zaixiangjian/sun-panel:latest
      docker push zaixiangjian/sun-panel:latest
      if [ $? -eq 0 ]; then
        echo -e "✅ 镜像上传成功！"
      else
        echo -e "❌ 上传失败，请先登录 Docker Hub"
      fi
      sleep 2
      read -n1 -r -p "回车继续..." key
      ;;


5)
  echo -e "\n📦 安装并运行 sun-panel 容器..."

  DEFAULT_DIR="/home/docker/sun-panel"
  DEFAULT_PORT="3002"

  read -e -p "请输入宿主机目录 [默认: $DEFAULT_DIR]: " HOST_DIR
  HOST_DIR=${HOST_DIR:-$DEFAULT_DIR}

  read -e -p "请输入宿主机端口 [默认: $DEFAULT_PORT]: " HOST_PORT
  HOST_PORT=${HOST_PORT:-$DEFAULT_PORT}

  # 创建必要的子目录
  mkdir -p "$HOST_DIR"/{conf,data,database,lang,runtime}

  # 停止并删除已有容器
  docker stop sun-panel 2>/dev/null || true
  docker rm sun-panel 2>/dev/null || true

  # 启动容器，挂载全部目录
  docker run -d \
    --name sun-panel \
    --restart unless-stopped \
    -v "$HOST_DIR/conf":/app/conf \
    -v "$HOST_DIR/data":/app/data \
    -v "$HOST_DIR/database":/app/database \
    -v "$HOST_DIR/lang":/app/lang \
    -v "$HOST_DIR/runtime":/app/runtime \
    -p "$HOST_PORT":3002 \
    zaixiangjian/sun-panel:latest

  # 获取本机 IP
  HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
  [ -z "$HOST_IP" ] && HOST_IP=$(hostname -I | awk '{print $1}')

  echo -e "\n✅ 安装完成！"
  echo -e "👉 访问地址: http://${HOST_IP}:${HOST_PORT}"
  echo -e "账号: admin@sun.cc"
  echo -e "密码: 12345678"
  read -n1 -r -p "回车继续..." key
  ;;

6)
  echo -e "\n🔄 更新已安装容器..."
  DEFAULT_DIR="/home/docker/sun-panel"
  DEFAULT_PORT="3002"

  # 停止并删除旧容器
  docker stop sun-panel 2>/dev/null || true
  docker rm sun-panel 2>/dev/null || true

  # 拉取最新镜像
  docker pull zaixiangjian/sun-panel:latest

  # 重新运行容器，挂载完整目录
  docker run -d \
    --name sun-panel \
    --restart unless-stopped \
    -v "$DEFAULT_DIR/conf":/app/conf \
    -v "$DEFAULT_DIR/data":/app/data \
    -v "$DEFAULT_DIR/database":/app/database \
    -v "$DEFAULT_DIR/lang":/app/lang \
    -v "$DEFAULT_DIR/runtime":/app/runtime \
    -p "$DEFAULT_PORT":3002 \
    zaixiangjian/sun-panel:latest

  # 获取本机 IP
  HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
  [ -z "$HOST_IP" ] && HOST_IP=$(hostname -I | awk '{print $1}')

  echo -e "\n✅ 更新完成！访问地址: http://${HOST_IP}:${DEFAULT_PORT}"
  read -n1 -r -p "回车继续..." key
  ;;


    7)
      echo -e "\n🗑️ 卸载 sun-panel 并删除目录..."
      docker stop sun-panel 2>/dev/null || true
      docker rm sun-panel 2>/dev/null || true
      rm -rf /home/docker/sun-panel
      echo -e "\n✅ 已卸载并删除 /home/docker/sun-panel"
      read -n1 -r -p "回车继续..." key
      ;;

8)
  echo -e "\n📦 备份 sun-panel 数据..."

  BACKUP_DIR="/home/docker"
  BACKUP_NAME="sun-panel-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
  CONTAINER_DATA="/home/docker/sun-panel"

  if [ ! -d "$CONTAINER_DATA" ]; then
    echo -e "❌ 数据目录不存在：$CONTAINER_DATA"
    read -n1 -r -p "回车继续..." key
    break
  fi

  tar -czf "$BACKUP_DIR/$BACKUP_NAME" -C "$CONTAINER_DATA" .

  if [ $? -eq 0 ]; then
    echo -e "✅ 备份成功：$BACKUP_DIR/$BACKUP_NAME"
  else
    echo -e "❌ 备份失败"
  fi

  read -n1 -r -p "回车继续..." key
  ;;


9)
  echo -e "\n♻️ 恢复 sun-panel 数据并启动容器..."

  DEFAULT_DIR="/home/docker/sun-panel"
  DEFAULT_PORT="3002"
  BACKUP_DIR="/home/docker"

  # 获取最新备份文件
  LATEST_BACKUP=$(ls -t $BACKUP_DIR/sun-panel-backup-*.tar.gz 2>/dev/null | head -n1)

  if [ -z "$LATEST_BACKUP" ]; then
    echo -e "❌ 没有找到任何备份文件"
    read -n1 -r -p "回车继续..." key
    break
  fi

  echo -e "\n📂 可用备份文件："
  ls -lh $BACKUP_DIR/sun-panel-backup-*.tar.gz 2>/dev/null
  echo -e "最新备份: $(basename "$LATEST_BACKUP")"

  read -e -p "请输入要恢复的备份文件名 [回车使用最新]: " BACKUP_FILE
  BACKUP_FILE=${BACKUP_FILE:-$(basename "$LATEST_BACKUP")}

  if [ ! -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    echo -e "❌ 备份文件不存在"
    read -n1 -r -p "回车继续..." key
    break
  fi

  read -e -p "恢复目录 [默认: $DEFAULT_DIR]: " HOST_DIR
  HOST_DIR=${HOST_DIR:-$DEFAULT_DIR}

  read -e -p "宿主机端口 [默认: $DEFAULT_PORT]: " HOST_PORT
  HOST_PORT=${HOST_PORT:-$DEFAULT_PORT}

  # 停止并删除旧容器
  docker stop sun-panel 2>/dev/null || true
  docker rm sun-panel 2>/dev/null || true

  # 清空并恢复数据
  rm -rf "$HOST_DIR"
  mkdir -p "$HOST_DIR"
  tar -xzf "$BACKUP_DIR/$BACKUP_FILE" -C "$HOST_DIR"

  # 确保挂载所有子目录
  mkdir -p "$HOST_DIR"/{conf,data,database,lang,runtime}

  # 启动容器
  docker run -d \
    --name sun-panel \
    --restart unless-stopped \
    -v "$HOST_DIR/conf":/app/conf \
    -v "$HOST_DIR/data":/app/data \
    -v "$HOST_DIR/database":/app/database \
    -v "$HOST_DIR/lang":/app/lang \
    -v "$HOST_DIR/runtime":/app/runtime \
    -p "$HOST_PORT":3002 \
    zaixiangjian/sun-panel:latest

  # 获取本机 IP
  HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
  [ -z "$HOST_IP" ] && HOST_IP=$(hostname -I | awk '{print $1}')

  echo -e "\n✅ 恢复完成并已启动"
  echo -e "👉 访问地址: http://${HOST_IP}:${HOST_PORT}"
  read -n1 -r -p "回车继续..." key
  ;;

    0)
      break
      ;;

    *)
      echo "输入错误"
      read -n1 -r -p "回车继续..." key
      ;;
  esac
done
;;


81)
        # 内部函数：更新 Hosts 回流
        update_sun_panel_hosts() {
            echo "🌐 正在配置本地回环地址 (Hosts)..."
            local domains=("api.sun-panel.top" "www.sun-panel.top" "pro.sun-panel.top" "sun-panel.top")
            for dom in "${domains[@]}"; do
                if ! grep -qE "127.0.0.1[[:space:]]+$dom" /etc/hosts; then
                    echo "127.0.0.1    $dom" >> /etc/hosts
                fi
                if ! grep -qE "::1[[:space:]]+$dom" /etc/hosts; then
                    echo "::1          $dom" >> /etc/hosts
                fi
            done
        }

        while true; do
            clear
            echo "------------------------------------------------"
            echo "          Sun-Panel 管理工具 (v1.8.1)"
            echo "------------------------------------------------"
            echo "1. 安装 Sun-Panel"
            echo "2. 卸载 Sun-Panel (含启动任务与目录)"
            echo "3. 备份 Sun-Panel (.tar.gz)"
            echo "4. 恢复 Sun-Panel (智能检索/默认最新)"
            echo "0. 返回上一级"
            echo "------------------------------------------------"
            read -e -p "请输入你的选择: " sub_choice

            PANEL_DIR="/home/docker/sun-panel"
            BACKUP_DIR="/home/docker"
            SERVICE_FILE="/etc/systemd/system/sun-panel.service"

            case $sub_choice in
                1)
                    echo "📦 正在安装 Sun-Panel..."
                    # 强力清理旧环境
                    systemctl stop sun-panel 2>/dev/null
                    systemctl disable sun-panel 2>/dev/null
                    fuser -k 3002/tcp 2>/dev/null 
                    pkill -f "sun-panel" 2>/dev/null
                    
                    mkdir -p "$PANEL_DIR"
                    cd "$PANEL_DIR" || continue
                    
                    echo "📥 正在下载资源包..."
                    wget -q --show-progress -O sun-panel.tar.gz https://github.com/zaixiangjian/ziyongcdn/releases/download/1.8.1/sun-panel_v1.8.1_linux_amd64.tar.gz
                    
                    echo "📦 正在解压并整理环境..."
                    tar -xzf sun-panel.tar.gz
                    if [ -d "sun-panel_v1.8.1_linux_amd64" ]; then
                        cp -rn sun-panel_v1.8.1_linux_amd64/* ./
                        rm -rf sun-panel_v1.8.1_linux_amd64
                    fi
                    rm -f sun-panel.tar.gz
                    chmod +x sun-panel
                    
                    update_sun_panel_hosts
                    
                    echo "⚙️ 写入服务配置..."
                    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Sun-Panel Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PANEL_DIR
ExecStart=$PANEL_DIR/sun-panel
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

                    echo "🚀 启动服务..."
                    systemctl daemon-reload
                    systemctl enable sun-panel
                    systemctl start sun-panel
                    
                    echo "⏳ 正在验证端口 (3002)..."
                    sleep 5
                    if ss -tuln | grep -q ":3002 "; then
                        echo "✅ 安装完成！服务已在端口 3002 成功运行。"
                        echo "------------------------------------------------"
                        echo "账号: admin@sun.cc | 密码: 12345678"
                        echo "------------------------------------------------"
                    else
                        echo "⚠️ 服务已启动但端口未监听，请稍后检查。"
                        journalctl -u sun-panel -n 10 --no-pager
                    fi
                    read -n1 -r -p "回车返回菜单..."
                    ;;

                2)
                    echo "🗑️ 正在彻底卸载 Sun-Panel..."
                    # 1. 停止服务
                    echo "🛑 停止并禁用启动任务..."
                    systemctl stop sun-panel 2>/dev/null
                    systemctl disable sun-panel 2>/dev/null
                    
                    # 2. 删除服务文件
                    echo "📄 移除服务配置文件..."
                    rm -f "$SERVICE_FILE"
                    systemctl daemon-reload
                    systemctl reset-failed
                    
                    # 3. 清理残留进程
                    fuser -k 3002/tcp 2>/dev/null
                    pkill -f "sun-panel" 2>/dev/null
                    
                    # 4. 删除本地目录
                    echo "📂 删除程序目录: $PANEL_DIR"
                    rm -rf "$PANEL_DIR"
                    
                    echo "✅ 卸载完成！所有启动任务及本地目录已清除。"
                    read -n1 -r -p "回车返回菜单..."
                    ;;

                3)
                    echo "💾 正在压缩备份至 $BACKUP_DIR..."
                    BACKUP_FILE="sun-panel-backup-$(date +%Y%m%d%H%M%S).tar.gz"
                    tar -czf "$BACKUP_DIR/$BACKUP_FILE" --exclude="*.tar.gz" -C "$PANEL_DIR" .
                    echo "✅ 备份成功: $BACKUP_FILE"
                    read -n1 -r -p "回车返回菜单..."
                    ;;

                4)
                    echo "♻️ 恢复 Sun-Panel..."
                    mapfile -t backups < <(ls -t $BACKUP_DIR/sun-panel-backup-*.tar.gz 2>/dev/null)

                    if [ ${#backups[@]} -eq 0 ]; then
                        echo "❌ 未找到备份文件。"; read -n1 -r -p "回车返回..."; continue
                    fi

                    echo "💡 请选择备份（回车默认最新备份）:"
                    for i in "${!backups[@]}"; do
                        echo "  $((i+1)). $(basename "${backups[$i]}")"
                    done

                    read -p "选择序号: " b_idx
                    b_idx=${b_idx:-1}
                    SELECTED_BACKUP="${backups[$((b_idx-1))]}"

                    echo "🔄 正在恢复环境..."
                    systemctl stop sun-panel 2>/dev/null
                    fuser -k 3002/tcp 2>/dev/null
                    pkill -f "sun-panel" 2>/dev/null
                    
                    rm -rf "$PANEL_DIR"
                    mkdir -p "$PANEL_DIR"

                    echo "📦 正在解压备份数据..."
                    tar -xzf "$SELECTED_BACKUP" -C "$PANEL_DIR"
                    chmod +x "$PANEL_DIR/sun-panel"
                    update_sun_panel_hosts

                    echo "⚙️ 重构服务配置..."
                    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Sun-Panel Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PANEL_DIR
ExecStart=$PANEL_DIR/sun-panel
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
                    systemctl daemon-reload
                    systemctl enable sun-panel
                    systemctl start sun-panel
                    
                    echo "⏳ 正在验证恢复状态..."
                    sleep 5
                    if ss -tuln | grep -q ":3002 "; then
                        echo "✅ 恢复完成且启动成功！"
                    else
                        echo "⚠️ 恢复完成，但端口响应较慢，请稍后确认。"
                    fi
                    read -n1 -r -p "回车返回菜单..."
                    ;;

                0)
                    break
                    ;;
            esac
        done
        ;;

82)
        # --- 内部函数：显示定时任务 ---
        show_cron_jobs() {
            echo "======================================"
            echo "📅 当前 Rclone 定时任务状态："
            if crontab -l 2>/dev/null | grep -q "s3beifen"; then
                crontab -l | grep "s3beifen"
            else
                echo "暂无定时备份任务"
            fi
            echo "======================================"
        }

        # --- 内部函数：创建 Rclone 备份脚本 ---
        create_backup_job() {
            script_name="$1"
            echo "======== 添加 Rclone 备份任务 ($script_name) ========"
            read -p "请输入要备份的本地目录全路径（例如 /home/docker）: " local_dir
            if [ ! -d "$local_dir" ]; then echo "❌ 目录不存在！"; return; fi
            
            in_dir=$(basename "$local_dir")
            echo "当前 Rclone 远程列表："
            rclone listremotes
            read -p "请输入远程名称 (例如 r2): " remote_name
            read -p "请输入存储桶名称 (Bucket): " bucket_name
            
            backup_cmd="rclone copy ${local_dir} ${remote_name}:${bucket_name}/服务器备份/${in_dir}"
            
            echo "#!/bin/bash" > "/root/${script_name}"
            echo "$backup_cmd" >> "/root/${script_name}"
            chmod +x "/root/${script_name}"
            
            echo "🚀 尝试首次运行备份..."
            bash "/root/${script_name}"
            
            echo "📅 设置定时执行："
            read -p "每几天运行一次 (输入数字，0表示每小时模式): " period
            if [[ "$period" == "0" ]]; then
                read -p "每几小时运行一次 (1-23): " hours
                cron_rule="0 */$hours * * * /bin/bash /root/${script_name}"
            else
                read -p "每天几点执行 (0-23): " hour
                cron_rule="0 $hour */$period * * /bin/bash /root/${script_name}"
            fi

            (crontab -l 2>/dev/null | grep -v "/root/${script_name}"; echo "$cron_rule") | crontab -
            echo "✅ 定时任务已更新。"
        }

        while true; do
            clear
            show_cron_jobs
            echo "------------------------------------------------"
            echo "      Backrest & Rclone 综合管理 (备份专题)"
            echo "------------------------------------------------"
            echo " [ Backrest 网页备份 (端口 9898) ]"
            echo " 1. 安装 Backrest (1.10.1)"
            echo " 2. 卸载 Backrest (完全清理)"
            echo " 3. 重启 Backrest 服务"
            echo " 4. 查看服务状态/日志"
            echo "============================================================"
            echo "Backrest后台添加对象存储的配置路径"
            echo "例如"
            echo "rclone:r2:cunchu/全部备份"
            echo "============================================================"
            echo " [ Rclone 命令行/S3 备份 ]"
            echo " 20. 安装 Rclone (v1.72.1)"
            echo " 21. 获取配置文件路径"
            echo " 22. 交互式添加 Rclone 远程配置 (S3)"
            echo " 23. 修改配置文件 (nano)"
            echo " 24. 查看已添加的 Rclone 远程"
            echo " 25. 目录备份 -> s3beifen.sh"
            echo " 26. 目录备份 -> s3beifen1.sh"
            echo " 27. 目录备份 -> s3beifen2.sh"
            echo " 28. 删除所有 Rclone 定时任务"
            echo " 29. 卸载 Rclone"
            echo "------------------------------------------------"
            echo " [ 系统全量备份与恢复 ]"
            echo " 88. 备份全部内容 (Backrest + Rclone)"
            echo " 99. 自动恢复并启用 (从 /home/backrclone)"
            echo "------------------------------------------------"
            echo " 100. 完全卸载 (清理目录/服务/残留/环境)"
            echo "------------------------------------------------"
            echo " 0. 返回上一级菜单"
            echo "------------------------------------------------"
            read -e -p "请输入选择: " sub_choice

            BASE_DIR="/home/docker/BackyuRclone"
            BR_DIR="$BASE_DIR/backrest"
            RC_DIR="$BASE_DIR/Rclone"
            BR_SERVICE="/etc/systemd/system/backrest.service"
            BACKUP_SAVE_DIR="/home/backrclone"

            case $sub_choice in
                1)
                    echo "📦 正在安装 Backrest..."
                    systemctl stop backrest 2>/dev/null
                    mkdir -p "$BR_DIR" && cd "$BR_DIR"
                    wget -q --show-progress -O br.tar.gz https://github.com/zaixiangjian/ziyongcdn/releases/download/1.10.1/backrest_Linux_x86_64.tar.gz
                    tar -xzf br.tar.gz
                    find . -maxdepth 1 -type f -name "backrest*" ! -name "*.tar.gz" -exec mv {} backrest \;
                    chmod +x backrest
                    rm -f br.tar.gz
                    cat <<EOF > "$BR_SERVICE"
[Unit]
Description=Backrest Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$BR_DIR
ExecStart=$BR_DIR/backrest
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
                    systemctl daemon-reload
                    systemctl enable backrest
                    systemctl start backrest
                    sleep 2
                    if systemctl is-active --quiet backrest; then
                        echo "✅ 安装成功！访问地址: http://$(curl -s ipv4.icanhazip.com):9898"
                    else
                        echo "❌ 启动失败，请检查端口 9898 是否被占用。"
                        journalctl -u backrest --no-pager -n 10
                    fi
                    read -p "回车继续..." ;;

                2)
                    systemctl stop backrest 2>/dev/null
                    systemctl disable backrest 2>/dev/null
                    rm -f "$BR_SERVICE"
                    rm -rf "$BR_DIR"
                    echo "✅ 已完全卸载。"
                    read -p "回车继续..." ;;

                3)
                    systemctl restart backrest
                    echo "✅ 已发出重启指令。"
                    read -p "回车继续..." ;;

                4)
                    journalctl -u backrest --no-pager -n 20
                    read -p "回车继续..." ;;

                20)
                    echo "📦 正在安装 Rclone v1.72.1..."
                    mkdir -p "$RC_DIR" && cd "$RC_DIR"
                    apt-get install -y unzip || yum install -y unzip
                    wget -q --show-progress -O rc.zip https://github.com/zaixiangjian/ziyongcdn/releases/download/1.10.1/rclone-v1.72.1-linux-amd64.zip
                    unzip -o rc.zip
                    RBIN_TMP=$(find . -name "rclone" -type f)
                    cp "$RBIN_TMP" /usr/bin/rclone
                    chmod +x /usr/bin/rclone
                    rm -rf rc.zip rclone-v1.72.1-linux-amd64
                    echo "✅ Rclone 安装完成！"
                    read -p "回车继续..." ;;

                21) rclone config file; read -p "回车继续..." ;;


                22)
                    echo "📝 --- 添加 Rclone S3 配置文件 ---"
                    read -p "请输入名称 (例如 r2): " rc_name
                    read -p "提供商或者备注 (例如 Cloudflare): " rc_provider
                    read -p "请输入 Access Key ID: " rc_id
                    read -p "请输入 Secret Access Key: " rc_key
                    read -p "请输入 Endpoint (例如 s3.ap-southeast-1.idrivee2.com): " rc_endpoint

                    mkdir -p /root/.config/rclone
                    cat >> /root/.config/rclone/rclone.conf <<EOF
[$rc_name]
type = s3
provider = $rc_provider
access_key_id = $rc_id
secret_access_key = $rc_key
endpoint = $rc_endpoint
EOF
                    echo "✅ 配置已写入 /root/.config/rclone/rclone.conf"
                    read -p "回车继续..." ;;
        23) nano /root/.config/rclone/rclone.conf ;;
                24) rclone listremotes; read -p "回车继续..." ;;
                25) create_backup_job "s3beifen.sh" ;;
                26) create_backup_job "s3beifen1.sh" ;;
                27) create_backup_job "s3beifen2.sh" ;;
                28)
                    crontab -l | grep -v "s3beifen" | crontab -
                    echo "✅ 已清理所有 Rclone 定时任务。"
                    read -p "回车继续..." ;;
                29)
                    rm -f /usr/bin/rclone
                    echo "✅ Rclone 已卸载。"
                    read -p "回车继续..." ;;



88)
                    echo "🗄️ 正在执行【深度全量】备份 (程序 + 数据库 + 账户配置)..."
                    mkdir -p "$BACKUP_SAVE_DIR"
                    BACKUP_FILE="$BACKUP_SAVE_DIR/backrclone-$(date +%Y%m%d%H%M%S).tar.gz"
                    
                    # 定义 Backrest 的三个核心路径
                    BR_BIN_DIR="/home/docker/BackyuRclone"        # 自定义安装目录
                    BR_DATA="/root/.local/share/backrest"    # 运行数据/restic路径
                    BR_CONF="/root/.config/backrest"         # ⚠️ 账户/面板设置/config.json
                    RC_CONF="/root/.config/rclone"           # Rclone配置
                    
                    echo "📦 正在全量压缩..."
                    # 确保这些目录存在，否则 tar 会报错
                    mkdir -p "$BR_DATA" "$BR_CONF" "$RC_CONF"
                    
                    tar -czf "$BACKUP_FILE" --absolute-names \
                        "$BR_BIN_DIR" \
                        "$BR_DATA" \
                        "$BR_CONF" \
                        "$RC_CONF" \
                        $(ls /root/s3beifen*.sh 2>/dev/null) 2>/dev/null
                    
                    if [ -f "$BACKUP_FILE" ]; then
                        echo "✅ 全量备份完成：$BACKUP_FILE"
                        echo "💡 已包含账户、密码、面板设置及所有任务。"
                    else
                        echo "❌ 备份失败！"
                    fi
                    read -p "回车继续..." ;;

99)
    echo "♻️ 正在执行全环境自动恢复..."
    LATEST_PKG=$(ls -t $BACKUP_SAVE_DIR/backrclone-*.tar.gz 2>/dev/null | head -n 1)
    if [ -z "$LATEST_PKG" ]; then
        echo "❌ /home/backrclone 下未发现备份文件"; read -p "回车继续..."; continue
    fi
    
    echo "🛑 停止旧服务并清理冲突配置..."
    systemctl stop backrest 2>/dev/null
    rm -rf /root/.config/backrest

    echo "📂 还原物理文件..."
    tar -xzf "$LATEST_PKG" -P --overwrite -C /

    echo "⚙️ 权限校准与服务重建..."
    chmod +x "$BR_DIR/backrest" 2>/dev/null
    [ -f "/root/.local/share/backrest/restic" ] && chmod +x "/root/.local/share/backrest/restic"
    # 如果备份里有 rclone，还原它
    [ -f "$RC_DIR/rclone" ] && cp -f "$RC_DIR/rclone" /usr/bin/rclone && chmod +x /usr/bin/rclone
    chmod +x /root/s3beifen*.sh 2>/dev/null

    cat > "$BR_SERVICE" <<EOF
[Unit]
Description=Backrest Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$BR_DIR
ExecStart=$BR_DIR/backrest -bind-address :9898
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable backrest >/dev/null 2>&1
    systemctl start backrest
    
    echo "⏳ 等待服务初始化 (5s)..."
    sleep 5
    
    # 使用稳健的判断逻辑
    BR_STATUS=$(systemctl is-active backrest)
    if [ "$BR_STATUS" = "active" ]; then
        echo "✅ Backrest 核心服务恢复成功！"
        echo "🌍 访问地址: http://$(curl -s ipv4.icanhazip.com):9898"
        
        echo "------------------------------------------------"
        echo "📦 正在自动为您安装 Rclone 环境..."
        # 直接复用 20 号的安装逻辑
        mkdir -p "$RC_DIR" && cd "$RC_DIR"
        apt-get update && apt-get install -y unzip || yum install -y unzip
        wget -q --show-progress -O rc.zip https://github.com/zaixiangjian/ziyongcdn/releases/download/1.10.1/rclone-v1.72.1-linux-amd64.zip
        unzip -o rc.zip >/dev/null
        RBIN_TMP=$(find . -name "rclone" -type f)
        cp -f "$RBIN_TMP" /usr/bin/rclone
        chmod +x /usr/bin/rclone
        echo "✅ Rclone 环境已自动就绪！"
        echo "------------------------------------------------"
        echo "💡 恢复流程已完成。"
        echo "👉 请接下来手动输入 [ 21 ] 获取配置文件路径，确认 Rclone 配置是否生效。"
    else
        echo "❌ 服务启动状态异常 ($BR_STATUS)，请检查选项 4 日志。"
    fi
    read -p "回车继续..." ;;

100)
                    echo "⚠️  正在准备完全卸载 Backrest & Rclone 环境..."
                    read -p "此操作将删除所有配置、备份任务及程序文件，确定吗？(y/n): " confirm
                    if [[ "$confirm" != "y" ]]; then echo "已取消。"; read -p "回车继续..."; continue; fi

                    echo "🛑 正在停止并禁用 Backrest 服务..."
                    systemctl stop backrest 2>/dev/null
                    systemctl disable backrest 2>/dev/null
                    rm -f /etc/systemd/system/backrest.service
                    systemctl daemon-reload

                    echo "🗑️  正在删除程序目录: $BASE_DIR ..."
                    # $BASE_DIR 即 /home/docker/BackyuRclone
                    rm -rf "$BASE_DIR"

                    echo "🗑️  正在清理 Backrest 系统残留 (配置与运行数据)..."
                    rm -rf "/root/.config/backrest"
                    rm -rf "/root/.local/share/backrest"

                    echo "🗑️  正在清理 Rclone 系统残留 (程序与配置)..."
                    rm -f /usr/bin/rclone
                    rm -rf "/root/.config/rclone"

                    echo "🗑️  正在清理定时任务 (Cron Jobs)..."
                    crontab -l 2>/dev/null | grep -v "s3beifen" | crontab -

                    echo "------------------------------------------------"
                    echo "✅ 卸载完成！"
                    echo "已清理清单："
                    echo "1. 安装目录: $BASE_DIR"
                    echo "2. 系统服务: backrest.service"
                    echo "3. Backrest配置: /root/.config/backrest"
                    echo "4. Rclone程序与配置: /usr/bin/rclone & .config/rclone"
                    echo "5. 所有相关的定时备份任务"
                    echo "------------------------------------------------"
                    read -p "回车继续..." ;;

                0) break ;;
            esac
        done
        ;;

83)
    while true; do
        clear
        echo -e "------------------------------------------------"
        echo -e "     Caddy & Cloudflare 自动化编译与安装工具"
        echo -e "------------------------------------------------"
        echo -e "【开发编译与推送】"
        echo -e "1)  一键安装环境并编译 Caddy (含 Cloudflare 插件)"
        echo -e "2)  登录 Docker Hub"
        echo -e "3)  推送镜像到 Docker Hub"
        echo -e "------------------------------------------------"
        echo -e "【Docker-Compose 管理 (推荐)】"
        echo -e "11) 安装/启动 Caddy (可自定义目录与 Token)"
        echo -e "12) 更新 Caddy 镜像 (latest)"
        echo -e "13) 查看 DNS 模块 (验证插件)"
        echo -e "14) 重载 Caddy 配置 (热更新)"
        echo -e "15) 卸载 Caddy (Compose 模式)"
        echo -e "------------------------------------------------"
        echo -e "【Docker Run 手动管理 (自定义路径)】"
        echo -e "21) 手动路径安装 (可自定义挂载目录)"
        echo -e "22) 更新 Caddy 镜像 (latest)"
        echo -e "23) 卸载 Caddy (Run 模式)"
        echo -e "------------------------------------------------"
        echo -e "0)  返回主菜单"
        echo -e "------------------------------------------------"
        read -p "请输入操作编号: " dev_choice

        # 基础变量配置
        build_base="/home/docker/build_temp"
        github_prefix="https://github.com/zaixiangjian"
        docker_img="zaixiangjian/caddy:latest"

        case $dev_choice in
            1)
                echo -e "\n--- 开始全自动构建环境与编译 ---"
                apt update && apt install -y git curl
                if ! command -v docker &> /dev/null; then
                    curl -fsSL https://get.docker.com | bash -
                    systemctl enable --now docker
                fi
                mkdir -p "$build_base" && cd "$build_base"
                rm -rf caddy
                echo "正在克隆源码并开始构建..."
                git clone "$github_prefix/caddy.git"
                cd caddy
                # 注意：此处依赖你仓库里的 Dockerfile 是否为多阶段插件编译版
                docker build --pull -t "$docker_img" .
                [ $? -eq 0 ] && echo "✅ 编译成功！" || echo "❌ 编译失败"
                read -n1 -r -p "回车继续..." key
                ;;

            2)
                docker login
                read -n1 -r -p "回车继续..." key
                ;;

            3)
                docker push "$docker_img"
                [ $? -eq 0 ] && echo "✅ 推送成功！" || echo "❌ 推送失败"
                read -n1 -r -p "回车继续..." key
                ;;

            11)
                echo -e "\n--- Compose 安装模式 ---"
                read -p "请输入安装根目录 (默认 /home/docker/caddy/): " caddy_path
                caddy_path=${caddy_path:-/home/docker/caddy/}
                mkdir -p "$caddy_path/data" "$caddy_path/config"
                cd "$caddy_path" || exit

                if [ ! -f "Caddyfile" ]; then
                    echo "创建默认 Caddyfile..."
                    echo -e ":80 {\n    respond \"Hello Caddy\"\n}" > Caddyfile
                fi

                if [ ! -f "docker-compose.yml" ]; then
                    read -p "请输入 Cloudflare Token (CF_API_TOKEN): " cf_token
                    cat <<EOF > docker-compose.yml
services:
  caddy:
    image: $docker_img
    container_name: caddy
    restart: always
    ports:
      - "8080:80"
      - "2053:443"
      - "2053:443/udp"
    environment:
      - CF_API_TOKEN=$cf_token
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./data:/data
      - ./config:/config
EOF
                fi
                docker compose up -d
                echo "✅ Compose 在 $caddy_path 启动完成"
                read -n1 -r -p "回车继续..." key
                ;;

            12|22)
                echo "正在强制拉取最新镜像..."
                docker pull "$docker_img"
                docker restart caddy
                echo "✅ 更新完毕（已尝试重启容器）"
                read -n1 -r -p "回车继续..." key
                ;;

            13)
                echo "--- 检查 DNS 模块状态 ---"
                if docker ps | grep -q caddy; then
                    docker exec -it caddy caddy list-modules | grep cloudflare
                else
                    echo "❌ Caddy 容器未运行"
                fi
                read -n1 -r -p "回车继续..." key
                ;;

            14)
                echo "正在平滑重载配置..."
                docker exec -it caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
                read -n1 -r -p "回车继续..." key
                ;;

            15)
                echo "正在通过 Compose 停止并卸载..."
                read -p "请输入安装根目录 (默认 /home/docker/caddy/): " del_path
                del_path=${del_path:-/home/docker/caddy/}
                if [ -d "$del_path" ]; then
                    cd "$del_path" && docker compose down
                    echo "✅ 容器已停止并移除"
                else
                    echo "❌ 找不到目录: $del_path"
                fi
                read -n1 -r -p "回车继续..." key
                ;;

            21)
                read -p "请输入安装根目录 (默认 /home/docker/caddy/): " run_path
                run_path=${run_path:-/home/docker/caddy/}
                mkdir -p "$run_path/data" "$run_path/config"
                [ ! -f "$run_path/Caddyfile" ] && echo ":80 { respond \"Hello\" }" > "$run_path/Caddyfile"
                
                read -p "请输入 Cloudflare API Token: " cf_token
                docker run -d \
                  --name caddy \
                  -p 8080:80 -p 2053:443 -p 2053:443/udp \
                  -v "$run_path/Caddyfile":/etc/caddy/Caddyfile \
                  -v "$run_path/data":/data \
                  -v "$run_path/config":/config \
                  -e CF_API_TOKEN="$cf_token" \
                  --restart always \
                  "$docker_img"
                echo "✅ Run 模式安装完成 (路径: $run_path)"
                read -n1 -r -p "回车继续..." key
                ;;

            23)
                echo "正在强制卸载 Caddy 容器..."
                docker rm -f caddy
                echo "✅ 容器 caddy 已被移除"
                read -n1 -r -p "回车继续..." key
                ;;

            0) break ;;
            *) echo "无效选择"; sleep 1 ;;
        esac
    done
    ;;

84)
        while true; do
            clear
            echo -e "------------------------------------------------"
            echo -e "      Hitokoto API (一言) 自动化管理工具"
            echo -e "------------------------------------------------"
            echo -e "【源码编译与推送】"
            echo -e "1)  一键安装环境并编译 Hitokoto API 镜像"
            echo -e "2)  登录 Docker Hub"
            echo -e "3)  推送镜像到 Docker Hub"
            echo -e "------------------------------------------------"
            echo -e "【部署与管理】"
            echo -e "11) 快速部署 (Docker Compose 模式)"
            echo -e "12) 查看 API 运行日志"
            echo -e "13) 检查 API 健康状态 (Curl 测试)"
            echo -e "14) 停止并卸载 API 容器"
            echo -e "------------------------------------------------"
            echo -e "0)  返回主菜单"
            echo -e "------------------------------------------------"
            read -p "请输入操作编号: " hito_choice

            # 基础变量配置
            build_base="/home/docker/build_hito"
            github_url="https://github.com/zaixiangjian/hitokoto-api.git"
            docker_img="zaixiangjian/hitokoto-api:latest"

            case $hito_choice in
                1)
                    echo -e "\n--- 开始全自动构建环境与编译 ---"
                    apt update && apt install -y git curl
                    if ! command -v docker &> /dev/null; then
                        curl -fsSL https://get.docker.com | bash -
                        systemctl enable --now docker
                    fi

                    mkdir -p "$build_base" && cd "$build_base"
                    rm -rf hitokoto-api

                    echo "正在从 $github_url 克隆源码..."
                    git clone "$github_url"
                    cd hitokoto-api || exit 1

                    echo "写入 Docker 专用 Dockerfile（禁用 husky）..."

cat > Dockerfile <<'EOF'
FROM node:20-slim

WORKDIR /app

ENV NODE_ENV=production

COPY package.json package-lock.json* ./

# 关键：彻底禁用 husky / postinstall
RUN npm install --legacy-peer-deps --omit=dev --ignore-scripts

COPY . .

EXPOSE 8000
CMD ["npm", "run", "start"]
EOF

                    echo "正在构建 Docker 镜像: $docker_img"
                    docker build --pull -t "$docker_img" .

                    if [ $? -eq 0 ]; then
                        echo "✅ 镜像编译成功！"
                    else
                        echo "❌ 编译失败"
                    fi

                    read -n1 -r -p "回车继续..." key
                    ;;

                2)
                    docker login
                    read -n1 -r -p "回车继续..." key
                    ;;

                3)
                    echo "正在推送镜像到仓库..."
                    docker push "$docker_img"
                    [ $? -eq 0 ] && echo "✅ 推送成功！" || echo "❌ 推送失败"
                    read -n1 -r -p "回车继续..." key
                    ;;

11)
    echo -e "\n--- Hitokoto API + Redis 强制配置部署 ---"
    read -p "请输入部署目录 (默认 /home/docker/hitokoto): " hito_path
    hito_path=${hito_path:-/home/docker/hitokoto}
    mkdir -p "$hito_path" && cd "$hito_path"

    # 创建一个强制配置文件
    echo "正在生成生产环境配置..."
    cat <<EOF > data.yml
# Hitokoto API 运行时配置
server:
  host: 0.0.0.0
  port: 8000
redis:
  host: hitokoto-redis
  port: 6379
  password: 
  database: 0
EOF

    echo "正在写入 docker-compose.yml..."
    cat <<EOF > docker-compose.yml
services:
  hitokoto-redis:
    image: redis:7-alpine
    container_name: hitokoto-redis
    restart: always
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  hitokoto:
    image: $docker_img
    container_name: hitokoto-api
    restart: always
    ports:
      - "8000:8000"
    volumes:
      # 将外部配置强制覆盖到容器内的配置目录
      # 假设项目配置路径为 /app/data/config.yml 或类似的，这里根据源码调整
      - ./data.yml:/app/data/config.yml
    depends_on:
      hitokoto-redis:
        condition: service_healthy
    environment:
      - NODE_ENV=production
      - REDIS_HOST=hitokoto-redis
EOF

    echo "正在重启服务..."
    docker compose down
    docker compose up -d
    echo "✅ 部署更新完成！"
    read -n1 -r -p "回车继续..." key
    ;;



                12)
                    echo "--- 正在查看容器日志 (Ctrl+C 退出) ---"
                    docker logs -f hitokoto-api
                    ;;

                13)
                    echo "--- 正在测试接口响应 ---"
                    curl -s http://127.0.0.1:8000 | jq . 2>/dev/null || curl -s http://127.0.0.1:8000
                    echo -e "\n------------------------"
                    read -n1 -r -p "回车继续..." key
                    ;;

                14)
                    echo "正在停止并移除容器..."
                    read -p "请输入部署目录 (默认 /home/docker/hitokoto): " del_path
                    del_path=${del_path:-/home/docker/hitokoto}
                    if [ -d "$del_path" ]; then
                        cd "$del_path" && docker compose down
                        echo "✅ 容器已移除"
                    else
                        echo "❌ 找不到目录: $del_path"
                    fi
                    read -n1 -r -p "回车继续..." key
                    ;;

                0) break ;;
                *) echo "无效选择"; sleep 1 ;;
            esac
        done
        ;;


      85)
        run_local_first_app_script "▶️ 安装OpenList网盘授权..." "/root/yingyong/85openlist-api-server.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/85openlist-api-server.sh"
        echo "✅ OpenList网盘授权安装成功..."
        ;;

      86)
        run_local_first_app_script "▶️ 安装Backrest..." "/root/yingyong/86Backrest.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/86Backrest.sh"
        echo "✅ Backrest安装成功..."
        ;;

      87)
        run_local_first_app_script "▶️ 安装openlist..." "/root/yingyong/87openlist.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/87openlist.sh"
        echo "✅ openlist安装成功..."
        ;;

      88)
        run_local_first_app_script "▶️ 安装MinIO..." "/root/yingyong/88minio.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/88minio.sh"
        echo "✅ minio安装成功..."
        ;;


89)
while true; do
    clear
    echo "------------------------------------------------"
    echo "        Nezha 面板 Docker 管理脚本"

    echo "如果官方删除了可以使用这个版本"
    echo "Linux"
    echo "curl -L https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.sh -o agent.sh && chmod +x agent.sh && env NZ_SERVER=Agent对接地址:8008 NZ_TLS=false NZ_CLIENT_SECRET=hkQ9g4oFkA5qrdfeLQTaHY0AA6BHqfFX NZ_UUID=54180658-5d44-a82c-cdfe-7ef48ec1f864 ./agent.sh"
    echo "只需要把nezhahq改成zaixiangjian"
    echo "和更改Agent对接地址:8008"
    echo "------------------------------------------------"
    echo "Windows与macOS通用"
    echo "$env:NZ_SERVER="Agent对接地址:8008";$env:NZ_TLS="false";$env:NZ_CLIENT_SECRET="hkQ9g4oFkA5qrdfeLQTaHY0AA6BHqfFX";$env:NZ_UUID="54180658-5d44-a82c-cdfe-7ef48ec1f864"; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3 -bor [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12;set-ExecutionPolicy RemoteSigned;Invoke-WebRequest https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.ps1 -OutFile C:install.ps1;powershell.exe C:install.ps1"
    echo "只需要把nezhahq改成zaixiangjian"
    echo "和更改Agent对接地址:8008"
    echo "------------------------------------------------"
    echo "【安装与更新】"
    echo "1) 安装 Nezha 面板"
    echo "2) 更新镜像到最新版本"
    echo "------------------------------------------------"
    echo "【数据备份与恢复】"
    echo "3) 备份数据 (/home/nezhav2-时间)"
    echo "4) 从 /home/ 恢复数据"
    echo "------------------------------------------------"
    echo "5) 卸载 Nezha 面板（含 /home/docker/nezha 和 /opt/agent）"
    echo "6) 只卸载/opt/agent"
    echo "0) 返回上一级"
    echo "------------------------------------------------"
    read -p "请输入操作编号: " choice

    install_dir="/home/docker/nezha"
    container_name="nezha-dashboard"
    docker_img="zaixiangjian/nezha:latest"
    agent_dir="/opt/nezha/agent"

    case $choice in
        1)
            echo "--- 安装 Nezha 面板 ---"

            DEFAULT_PORT="8008"
            read -e -p "请输入宿主机端口 [默认: $DEFAULT_PORT]: " HOST_PORT
            HOST_PORT=${HOST_PORT:-$DEFAULT_PORT}

            mkdir -p "$install_dir/data"

            docker stop $container_name 2>/dev/null || true
            docker rm $container_name 2>/dev/null || true

            docker run -d \
                --name $container_name \
                --restart unless-stopped \
                -v "$install_dir/data":/dashboard/data \
                -p "$HOST_PORT":8008 \
                -e ADMIN_USERNAME=admin \
                -e ADMIN_PASSWORD=admin \
                $docker_img

            HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
            [ -z "$HOST_IP" ] && HOST_IP=$(hostname -I | awk '{print $1}')

            echo "✅ 安装完成！访问 http://${HOST_IP}:${HOST_PORT} 账号:admin 密码:admin"
            read -n1 -r -p "回车继续..." key
            ;;

        2)
            echo "--- 更新镜像 ---"
            docker pull $docker_img
            echo "✅ 镜像已更新"
            read -n1 -r -p "回车继续..." key
            ;;

        3)
            timestamp=$(date +"%Y%m%d%H%M%S")
            backup_file="/home/nezhav2-$timestamp.tar.gz"
            
            if [ -d "$install_dir" ]; then
                tar -czf "$backup_file" -C "$install_dir" .
                echo "✅ 数据已备份到 $backup_file"
            else
                echo "❌ 安装目录 $install_dir 不存在，无法备份"
            fi

            read -n1 -r -p "回车继续..." key
            ;;

4)
    echo "可用备份文件："
    ls -1 /home/nezhav2-*.tar.gz 2>/dev/null
    latest_backup=$(ls -1 /home/nezhav2-*.tar.gz 2>/dev/null | sort | tail -n1)

    if [ -z "$latest_backup" ]; then
        echo "❌ 没有找到备份文件"
        read -n1 -r -p "回车继续..." key
        continue
    fi

    read -e -p "请输入要恢复的备份文件全路径 [回车使用最新: $latest_backup]: " restore_file
    restore_file=${restore_file:-$latest_backup}

    if [ ! -f "$restore_file" ]; then
        echo "❌ 文件不存在: $restore_file"
        read -n1 -r -p "回车继续..." key
        continue
    fi

    # 如果容器已存在，先停止
    if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
        echo "--- 停止已有容器 ---"
        docker stop $container_name
        docker rm $container_name
    else
        # 容器不存在，先确保安装镜像可用
        docker pull $docker_img
    fi

    mkdir -p "$install_dir"
    tar -xzf "$restore_file" -C "$install_dir"
    echo "✅ 数据已恢复到 $install_dir"

    # 重新启动容器
    DEFAULT_PORT="8008"
    read -e -p "请输入宿主机端口 [默认: $DEFAULT_PORT]: " HOST_PORT
    HOST_PORT=${HOST_PORT:-$DEFAULT_PORT}

    docker run -d \
        --name $container_name \
        --restart unless-stopped \
        -v "$install_dir/data":/dashboard/data \
        -p "$HOST_PORT":8008 \
        -e ADMIN_USERNAME=admin \
        -e ADMIN_PASSWORD=admin \
        $docker_img

    HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    [ -z "$HOST_IP" ] && HOST_IP=$(hostname -I | awk '{print $1}')

    echo "✅ 恢复并启动完成！"
    echo "http://${HOST_IP}:${HOST_PORT}"
    echo "账号"
    echo "admin"
    echo "密码"
    echo "admin"
    read -n1 -r -p "回车继续..." key
    ;;

        5)
            echo "--- 卸载 Nezha 面板 ---"
            docker stop $container_name 2>/dev/null || true
            docker rm $container_name 2>/dev/null || true
            docker rmi -f $docker_img 2>/dev/null || true
            rm -rf "$install_dir"
            rm -rf "$agent_dir"
            echo "✅ 卸载完成，已删除容器、镜像和目录"
            read -n1 -r -p "回车继续..." key
            ;;

6)
    echo "--- 彻底卸载 Nezha Agent ---"

    # 查找并停止正在运行的 Agent
    pid=$(pgrep -f 'nezha-agent|nezha/agent|agent' | head -n1)
    if [ -n "$pid" ]; then
        kill -9 $pid
        echo "✅ Agent 已停止 (PID: $pid)"
    else
        echo "ℹ️ 没有正在运行的 Agent"
    fi

    # 删除本地 Agent 目录
    if [ -d "$agent_dir" ]; then
        rm -rf "$agent_dir"
        echo "✅ 本地 Agent 目录已删除: $agent_dir"
    else
        echo "ℹ️ 本地 Agent 目录不存在"
    fi

    read -n1 -r -p "回车继续..." key
    ;;


        0) break ;;
        *) echo "无效选择"; sleep 1 ;;
    esac
done
;;

      90)
        clear
        echo "▶️ 正在启动btcpayserver-docker安装..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/btcpayserver-docker.sh)
        echo "✅ btcpayserver-docker安装完成。"
        ;;

      91)
        clear
        echo "▶️ 正在启动谷歌自动浏览..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/zidongliulan.sh)
        echo "✅ 谷歌自动浏览安装完成。"
        ;;

      92)
        clear
        echo "▶️ 正在启动CLIProxyAPI安装..."
		run_local_first_app_script "▶️ 正在启动CLIProxyAPI安装..." "/root/yingyong/CLIProxyAPI.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/CLIProxyAPI.sh"
        echo "✅ CLIProxyAPI安装完成。"
        ;;

      93)
        clear
        echo "▶️ 正在启动Sub2API安装..."
		run_local_first_app_script "▶️ 正在启动Sub2API安装..." "/root/yingyong/Sub2API.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/Sub2API.sh"
        echo "✅ Sub2API安装完成。"
        ;;


      94)
        run_local_first_app_script "▶️ 正在启动Openclaw安装..." "/root/yingyong/Openclaw.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/Openclaw.sh"
        echo "✅ Openclaw安装完成。"
        ;;

      95)
        run_local_first_app_script "▶️ 安装open-webui..." "/root/yingyong/95open-webui.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/95open-webui.sh"
        echo "✅ open-webui安装完成。"
        ;;


      96)
        clear
        echo "▶️ 安装谷歌地区检测..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/96jiecegoogle.sh)
        echo "✅ 谷歌地区检测安装成功..."
        ;;

      97)
        clear
        echo "▶️ 安装IP白名单模式..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/k/myip.sh)
        echo "✅ 安装IP白名单模式..."
        ;;

      98)
        clear
        echo "▶️ 安装谷歌浏览器..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/98chromium.sh)
        echo "✅ 谷歌浏览器安装成功..."
        ;;

      99)
        run_local_first_app_script "▶️ 安装hermes-agent..." "/root/yingyong/hermes_manager.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/hermes_manager.sh"
        echo "✅ hermes-agent安装成功..."
        ;;

      100)
        clear
        echo "▶️ 安装lobehub网页版本..."
		curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/lobehub.sh -o /root/lobehub.sh && chmod +x /root/lobehub.sh && /root/lobehub.sh
        echo "✅ lobehub安装成功..."
        ;;

      101)
        run_local_first_app_script "▶️ 正在启动agent-ai备份管理脚本..." "/root/yingyong/agent-ai.d/agent-ai.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/agent-ai.sh"
        echo "✅ agent-ai备份管理脚本执行完成..."
        ;;

      102)
        run_local_first_app_script "▶️ 正在启动加密支付GMPay 又名 epusdt管理脚本..." "/root/yingyong/102GMPay.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/102GMPay.sh"
        echo "✅ 加密支付GMPay 又名 epusdt管理脚本执行完成..."
        ;;


      103)
        run_local_first_app_script "▶️ 正在启动易支付Epay管理脚本..." "/root/yingyong/103Epay.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/103Epay.sh"
        echo "✅ 易支付Epay管理脚本执行完成..."
        ;;

      104)
        run_local_first_app_script "▶️ 正在启动异次元发卡管理脚本..." "/root/yingyong/104acg-faka.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/104acg-faka.sh"
        echo "✅ 异次元发卡管理脚本执行完成..."
        ;;

      105)
        run_local_first_app_script "▶️ 正在启动独角兽发卡管理脚本..." "/root/yingyong/105dujiao-next.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/105dujiao-next.sh"
        echo "✅ 独角兽发卡管理脚本执行完成..."
        ;;

      106)
        run_local_first_app_script "▶️ 正在启动加密支付bepusdt管理脚本..." "/root/yingyong/106bepusdt.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/106bepusdt.sh"
        echo "✅ 加密支付bepusdt管理脚本执行完成..."
        ;;

      990)
        run_local_first_app_script "▶️ 正在启动990端口白名单管理..." "/root/yingyong/990-port-whitelist.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/main/yingyong/990-port-whitelist.sh" "linux_app_ports"
        echo "✅ 990端口白名单管理完成。"
        ;;

      991)
        run_local_first_app_script "▶️ 安装Fail2Ban SSH防暴力破解..." "/root/yingyong/991docker-Fail2Ban.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/991docker-Fail2Ban.sh"
        echo "✅ Fail2Ban SSH防暴力破解安装成功..."
        ;;

      996)

      grep -q '127.0.0.1 goedge.cloud' /etc/hosts || echo "127.0.0.1 goedge.cloud" >> /etc/hosts
      grep -q '127.0.0.1 goedge.cn' /etc/hosts || echo "127.0.0.1 goedge.cn" >> /etc/hosts
      grep -q '127.0.0.1 dl.goedge.cloud' /etc/hosts || echo "127.0.0.1 dl.goedge.cloud" >> /etc/hosts
      grep -q '127.0.0.1 dl.goedge.cn' /etc/hosts || echo "127.0.0.1 dl.goedge.cn" >> /etc/hosts
      grep -q '127.0.0.1 global.dl.goedge.cloud' /etc/hosts || echo "127.0.0.1 global.dl.goedge.cloud" >> /etc/hosts
      grep -q '127.0.0.1 global.dl.goedge.cn' /etc/hosts || echo "127.0.0.1 global.dl.goedge.cn" >> /etc/hosts
      grep -q '::1 goedge.cloud' /etc/hosts || echo "::1 goedge.cloud" >> /etc/hosts
      grep -q '::1 goedge.cn' /etc/hosts || echo "::1 goedge.cn" >> /etc/hosts
      grep -q '::1 dl.goedge.cloud' /etc/hosts || echo "::1 dl.goedge.cloud" >> /etc/hosts
      grep -q '::1 dl.goedge.cn' /etc/hosts || echo "::1 dl.goedge.cn" >> /etc/hosts
      grep -q '::1 global.dl.goedge.cloud' /etc/hosts || echo "::1 global.dl.goedge.cloud" >> /etc/hosts
      grep -q '::1 global.dl.goedge.cn' /etc/hosts || echo "::1 global.dl.goedge.cn" >> /etc/hosts

      # 创建安装目录
      if [ ! -d /home/cdn ]; then
        mkdir -p /home/cdn > /dev/null 2>&1
      fi
   
      if [ ! -d /home/cdn/备份 ]; then
        mkdir -p /home/cdn/备份 > /dev/null 2>&1
      fi

      # 下载并解压 edge-admin 到 /home/cdn
      wget -O /home/cdn/edge-admin.zip https://github.com/zaixiangjian/ziyongcdn/releases/download/1.3.9/edge-admin-linux-amd64-plus-v1.3.9.zip > /dev/null 2>&1
      unzip -o /home/cdn/edge-admin.zip -d /home/cdn/ > /dev/null 2>&1


      # 赋予执行权限
      chmod +x /home/cdn/edge-admin/bin/edge-admin

      # 启动 edge-admin 后台服务（无日志输出）
      nohup /home/cdn/edge-admin/bin/edge-admin start > /dev/null 2>&1 &

      # 添加开机自启
      crontab -l 2>/dev/null | grep -q '@reboot sleep 10 && nohup /home/cdn/edge-admin/bin/edge-admin start > /dev/null 2>&1 &' || (
        (crontab -l 2>/dev/null; echo '@reboot sleep 10 && nohup /home/cdn/edge-admin/bin/edge-admin start > /dev/null 2>&1 &') | crontab -
      )

      # 安装 MariaDB
      apt update > /dev/null 2>&1
      DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server > /dev/null 2>&1

      # 修改 MariaDB 配置，监听 7789 端口
      sed -i '/^\[mysqld\]/a port=7789' /etc/mysql/mariadb.conf.d/50-server.cnf

      # 重启并设置开机启动
      systemctl restart mariadb
      systemctl enable mariadb

      # 生成随机 root 密码
      root_pass="RootPass$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 18)"

      # 设置 root 密码
      mysql -uroot <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${root_pass}';
FLUSH PRIVILEGES;
EOF

      # 创建数据库名和用户及密码
      db_name="edge_admin"
      db_user="edge_admin"
      db_pass="EdgePass$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 18)"

      # 创建数据库及用户
      mysql -uroot -p"${root_pass}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${db_name}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';
GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'localhost';
FLUSH PRIVILEGES;
EOF

      # 输出安装信息
      clear
      echo "edge-admin 已安装完成"
      echo "-----------------------------------"
      echo "MySQL root密码: $root_pass"
      echo "数据库名称: $db_name"
      echo "数据库用户名: $db_user"
      echo "数据库密码: $db_pass"
      echo "数据库端口: 7789"

      local_ip=$(hostname -I | awk '{print $1}')
      echo "edge-admin 访问地址: http://$local_ip:7788"
      echo "-----------------------------------"
      echo "请使用以上数据库信息完成 edge-admin 安装配置页面填写"
      echo "-----------------------------------"
      echo "激活商业版"
      echo "F4BuVYEKSDWV+I13ISd5NUyBcWOlH0af4/ow9obzYBS3XvYC9IsK86k5UDyyBv9vqJWN2/FQTDbPyuAO0zxYlkLDC0c8rrShs+7PAkqM0O8wBIGknzForgidDZahky5Lo/ZWaPZ1dVFUxmV29ykb0I0b4tv7Q3OtnTylOuzf//MYrlvyw6VJQMGnsttmeHzsNL/r0yDONOEXZoGoLZsuBKnkfXt+qt6bZF+kM1ncbh+sY42BrPTWQ12sXqJS3qHlzU0FFl9lTNzLGYYhq5vi/4sJuPVE50/uLCtslTJdb9zOGR915hnM+jHYsR+jUk0QxOqtreaHpsvNuLkexXbkmA=="
      echo "------------------------"
      echo "1. 安装            2. 更新            3. 卸载"
      echo "------------------------"
      echo "0. 返回上一级"
      echo "------------------------"
      echo -n "请输入你的选择: "

      exit 0
      ;;


      997)
      clear
      send_stats "PVE开小鸡"
      curl -L ${gh_proxy}https://raw.githubusercontent.com/oneclickvirt/pve/main/scripts/install_pve.sh -o install_pve.sh && chmod +x install_pve.sh && bash install_pve.sh
      ;;


      998)
      echo "正在添加本地 hosts 解析..."
      grep -q '127.0.0.1 goedge.cloud' /etc/hosts || echo "127.0.0.1 goedge.cloud" >> /etc/hosts
      grep -q '127.0.0.1 goedge.cn' /etc/hosts || echo "127.0.0.1 goedge.cn" >> /etc/hosts
      grep -q '127.0.0.1 dl.goedge.cloud' /etc/hosts || echo "127.0.0.1 dl.goedge.cloud" >> /etc/hosts
      grep -q '127.0.0.1 dl.goedge.cn' /etc/hosts || echo "127.0.0.1 dl.goedge.cn" >> /etc/hosts
      grep -q '127.0.0.1 global.dl.goedge.cloud' /etc/hosts || echo "127.0.0.1 global.dl.goedge.cloud" >> /etc/hosts
      grep -q '127.0.0.1 global.dl.goedge.cn' /etc/hosts || echo "127.0.0.1 global.dl.goedge.cn" >> /etc/hosts
      grep -q '::1 goedge.cloud' /etc/hosts || echo "::1 goedge.cloud" >> /etc/hosts
      grep -q '::1 goedge.cn' /etc/hosts || echo "::1 goedge.cn" >> /etc/hosts
      grep -q '::1 dl.goedge.cloud' /etc/hosts || echo "::1 dl.goedge.cloud" >> /etc/hosts
      grep -q '::1 dl.goedge.cn' /etc/hosts || echo "::1 dl.goedge.cn" >> /etc/hosts
      grep -q '::1 global.dl.goedge.cloud' /etc/hosts || echo "::1 global.dl.goedge.cloud" >> /etc/hosts
      grep -q '::1 global.dl.goedge.cn' /etc/hosts || echo "::1 global.dl.goedge.cn" >> /etc/hosts
      echo "=== /etc/hosts 当前内容 ==="
      cat /etc/hosts

      echo ""
      echo "请选择操作："
      echo "1. 备份 edge-admin 和数据库"
      echo "2. 恢复 edge-admin 和数据库（可选版本）"
      echo "3. 卸载 edge-admin 和数据库"
         echo "-----------------------------------"
      echo "激活商业版"
      echo "F4BuVYEKSDWV+I13ISd5NUyBcWOlH0af4/ow9obzYBS3XvYC9IsK86k5UDyyBv9vqJWN2/FQTDbPyuAO0zxYlkLDC0c8rrShs+7PAkqM0O8wBIGknzForgidDZahky5Lo/ZWaPZ1dVFUxmV29ykb0I0b4tv7Q3OtnTylOuzf//MYrlvyw6VJQMGnsttmeHzsNL/r0yDONOEXZoGoLZsuBKnkfXt+qt6bZF+kM1ncbh+sY42BrPTWQ12sXqJS3qHlzU0FFl9lTNzLGYYhq5vi/4sJuPVE50/uLCtslTJdb9zOGR915hnM+jHYsR+jUk0QxOqtreaHpsvNuLkexXbkmA=="
      echo "------------------------"
      read -p "请输入选项 [1-3]: " action

      base_dir="/home/cdn"
      backup_dir="${base_dir}/备份"
      mkdir -p "$backup_dir"

      if [ "$action" = "1" ]; then
        timestamp=$(date +"%Y%m%d%H%M%S")
        program_tar="${backup_dir}/edge-${timestamp}.tar.gz"
        db_tar="${backup_dir}/mariadb-${timestamp}.tar.gz"

        echo "📦 开始备份 edge-admin 程序..."
        tar czf "$program_tar" -C /home/cdn edge-admin

        echo "📦 开始备份 MariaDB 数据库..."
        systemctl stop mariadb
        tar czf "$db_tar" -C /var/lib mysql
        systemctl start mariadb

        echo "🧹 保留最新的 3 个程序和数据库备份..."
        ls -tp "$backup_dir"/edge-*.tar.gz 2>/dev/null | grep -v '/$' | tail -n +4 | xargs -r rm -f
        ls -tp "$backup_dir"/mariadb-*.tar.gz 2>/dev/null | grep -v '/$' | tail -n +4 | xargs -r rm -f

        echo "✅ 已完成备份："
        echo "程序：$program_tar"
        echo "数据库：$db_tar"
        exit 0

      elif [ "$action" = "2" ]; then
        # edge-admin 备份选择
        echo ""
        echo "📂 当前可用 edge-admin 备份："
        ls "$backup_dir"/edge-*.tar.gz 2>/dev/null | nl
        echo ""
        read -p "请输入要恢复的 edge-admin 版本编号（回车恢复最新）: " edge_index

        edge_list=( $(ls -t "$backup_dir"/edge-*.tar.gz 2>/dev/null) )
        if [ -z "${edge_list[0]}" ]; then
          echo "❌ 找不到 edge-admin 备份文件"
          exit 1
        fi
        if [[ -z "$edge_index" ]]; then
          program_tar="${edge_list[0]}"
        else
          index=$((edge_index - 1))
          program_tar="${edge_list[$index]}"
        fi

        # mariadb 备份选择
        echo ""
        echo "📂 当前可用 mysql 备份："
        ls "$backup_dir"/mariadb-*.tar.gz 2>/dev/null | nl
        echo ""
        read -p "请输入要恢复的 mysql 版本编号（回车恢复最新）: " db_index

        db_list=( $(ls -t "$backup_dir"/mariadb-*.tar.gz 2>/dev/null) )
        if [ -z "${db_list[0]}" ]; then
          echo "❌ 找不到 mysql 备份文件"
          exit 1
        fi
        if [[ -z "$db_index" ]]; then
          db_tar="${db_list[0]}"
        else
          index=$((db_index - 1))
          db_tar="${db_list[$index]}"
        fi

        echo "🔄 正在恢复："
        echo "程序备份：$program_tar"
        echo "数据库备份：$db_tar"

        apt update > /dev/null 2>&1
        DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server > /dev/null 2>&1
        sed -i '/^\[mysqld\]/a port=7789' /etc/mysql/mariadb.conf.d/50-server.cnf

        systemctl stop mariadb
        rm -rf /var/lib/mysql
        tar xzf "$db_tar" -C /var/lib
        chown -R mysql:mysql /var/lib/mysql

        # 恢复完毕后重启数据库
        systemctl restart mariadb
        systemctl enable mariadb

        rm -rf "$base_dir/edge-admin"
        tar xzf "$program_tar" -C "$base_dir"

        # 启动 edge-admin
        nohup "$base_dir/edge-admin/bin/edge-admin" start > /dev/null 2>&1 &

        # 设置开机自启
        crontab -l 2>/dev/null | grep -q "edge-admin/bin/edge-admin start" || (
          (crontab -l 2>/dev/null; echo "@reboot sleep 10 && nohup $base_dir/edge-admin/bin/edge-admin start > /dev/null 2>&1 &") | crontab -
        )

        clear
        echo "✅ 恢复完成"
        local_ip=$(hostname -I | awk '{print $1}')
        echo "edge-admin 访问地址: http://$local_ip:7788"
        exit 0

      elif [ "$action" = "3" ]; then
        systemctl stop mariadb
        systemctl disable mariadb
        apt purge -y mariadb-server mariadb-common > /dev/null 2>&1
        apt autoremove -y > /dev/null 2>&1
        rm -rf /var/lib/mysql /etc/mysql
        rm -rf "$base_dir/edge-admin"
        crontab -l | grep -v 'edge-admin' | crontab -
        echo "✅ edge-admin 与数据库已卸载"
        exit 0

      else
        echo "❌ 输入无效"
        exit 1
      fi
      ;;



    999)
      show_installed_webtop(){
        local installed=0
        echo "---------------------------------------------"
        for i in {1..24}; do
          case $i in
            1) name="webtop-ubuntu-kde";  img="lscr.io/linuxserver/webtop:ubuntu-kde"; port=3001; intro="资源占用高，KDE桌面，完整桌面体验";;
            2) name="webtop-latest";      img="lscr.io/linuxserver/webtop:latest";     port=3002; intro="轻量 Alpine + XFCE，资源占用低，基础桌面";;
            3) name="webtop-arch-kde";    img="lscr.io/linuxserver/webtop:arch-kde";   port=3003; intro="Arch Linux，KDE桌面，前沿软件，资源占用高";;
            4) name="webtop-ubuntu-gnome";img="lscr.io/linuxserver/webtop:ubuntu-gnome"; port=3004; intro="Ubuntu，GNOME桌面，现代风格，资源中等";;
            5) name="webtop-fedora-xfce"; img="lscr.io/linuxserver/webtop:fedora-xfce";  port=3005; intro="Fedora，XFCE桌面，轻量且稳定";;
            6) name="webtop-ubuntu-xfce"; img="lscr.io/linuxserver/webtop:ubuntu-xfce";  port=3006; intro="Ubuntu，XFCE桌面，轻量，资源低";;
            7) name="webtop-ubuntu-mate"; img="lscr.io/linuxserver/webtop:ubuntu-mate";  port=3007; intro="Ubuntu，MATE桌面，传统界面，中等资源";;
            8) name="webtop-ubuntu-i3";   img="lscr.io/linuxserver/webtop:ubuntu-i3";    port=3008; intro="Ubuntu，i3窗口管理器，极简，高效";;
            9) name="webtop-arch-xfce";   img="lscr.io/linuxserver/webtop:arch-xfce";    port=3009; intro="Arch，XFCE，轻量，滚动更新";;
            10) name="webtop-arch-mate";  img="lscr.io/linuxserver/webtop:arch-mate";   port=3010; intro="Arch，MATE，传统桌面，较轻量";;
            11) name="webtop-arch-i3";    img="lscr.io/linuxserver/webtop:arch-i3";     port=3011; intro="Arch，i3，极简窗口管理";;
            12) name="webtop-debian-xfce";img="lscr.io/linuxserver/webtop:debian-xfce"; port=3012; intro="Debian，XFCE，稳定，轻量";;
            13) name="webtop-debian-mate";img="lscr.io/linuxserver/webtop:debian-mate"; port=3013; intro="Debian，MATE，传统桌面，稳定";;
            14) name="webtop-debian-i3";  img="lscr.io/linuxserver/webtop:debian-i3";   port=3014; intro="Debian，i3，极简，稳定";;
            15) name="webtop-debian-kde"; img="lscr.io/linuxserver/webtop:debian-kde";  port=3015; intro="Debian，KDE，稳定，资源较高";;
            16) name="webtop-fedora-mate";img="lscr.io/linuxserver/webtop:fedora-mate"; port=3016; intro="Fedora，MATE，轻量且现代";;
            17) name="webtop-fedora-kde"; img="lscr.io/linuxserver/webtop:fedora-kde";  port=3017; intro="Fedora，KDE，现代桌面，资源中高";;
            18) name="webtop-fedora-i3";  img="lscr.io/linuxserver/webtop:fedora-i3";   port=3018; intro="Fedora，i3，极简，高效";;
            19) name="webtop-el-xfce";    img="lscr.io/linuxserver/webtop:el-xfce";     port=3019; intro="Enterprise Linux，XFCE，稳定";;
            20) name="webtop-el-mate";    img="lscr.io/linuxserver/webtop:el-mate";     port=3020; intro="Enterprise Linux，MATE，稳定";;
            21) name="webtop-el-i3";      img="lscr.io/linuxserver/webtop:el-i3";       port=3021; intro="Enterprise Linux，i3，极简";;
            22) name="webtop-alpine-xfce";img="lscr.io/linuxserver/webtop:alpine-xfce"; port=3022; intro="Alpine，XFCE，极轻量，基础桌面";;
            23) name="webtop-alpine-mate";img="lscr.io/linuxserver/webtop:alpine-mate"; port=3023; intro="Alpine，MATE，轻量桌面";;
            24) name="webtop-alpine-i3";  img="lscr.io/linuxserver/webtop:alpine-i3";   port=3024; intro="Alpine，i3，极简窗口管理器";;
          esac

          if docker ps -a --format '{{.Names}}' | grep -qw "$name"; then
            echo "已安装$i. $name"
            echo "访问地址: http://$(curl -s ipv4.ip.sb):$port"
            echo "访问地址: http://$(curl -s ipv6.ip.sb):$port"
            echo "介绍: $intro"
            echo "---------------------------------------------"
          fi
        done
      }

      clear
      show_installed_webtop

      echo "==== Webtop 镜像版本管理 ===="
      echo "请选择镜像版本："
      echo " 1. ubuntu-kde      【资源占用高，KDE桌面，完整桌面体验】"
      echo " 2. latest          【轻量 Alpine + XFCE，资源占用低，基础桌面】"
      echo " 3. arch-kde        【Arch Linux，KDE桌面，前沿软件，资源占用高】"
      echo " 4. ubuntu-gnome    【Ubuntu，GNOME桌面，现代风格，资源中等】"
      echo " 5. fedora-xfce     【Fedora，XFCE桌面，轻量且稳定】"
      echo " 6. ubuntu-xfce     【Ubuntu，XFCE桌面，轻量，资源低】"
      echo " 7. ubuntu-mate     【Ubuntu，MATE桌面，传统界面，中等资源】"
      echo " 8. ubuntu-i3       【Ubuntu，i3窗口管理器，极简，高效】"
      echo " 9. arch-xfce       【Arch，XFCE，轻量，滚动更新】"
      echo "10. arch-mate       【Arch，MATE，传统桌面，较轻量】"
      echo "11. arch-i3         【Arch，i3，极简窗口管理】"
      echo "12. debian-xfce     【Debian，XFCE，稳定，轻量】"
      echo "13. debian-mate     【Debian，MATE，传统桌面，稳定】"
      echo "14. debian-i3       【Debian，i3，极简，稳定】"
      echo "15. debian-kde      【Debian，KDE，稳定，资源较高】"
      echo "16. fedora-mate     【Fedora，MATE，轻量且现代】"
      echo "17. fedora-kde      【Fedora，KDE，现代桌面，资源中高】"
      echo "18. fedora-i3       【Fedora，i3，极简，高效】"
      echo "19. el-xfce         【Enterprise Linux，XFCE，稳定】"
      echo "20. el-mate         【Enterprise Linux，MATE，稳定】"
      echo "21. el-i3           【Enterprise Linux，i3，极简】"
      echo "22. alpine-xfce     【Alpine，XFCE，极轻量，基础桌面】"
      echo "23. alpine-mate     【Alpine，MATE，轻量桌面】"
      echo "24. alpine-i3       【Alpine，i3，极简窗口管理器】"
      echo "0. 返回上一级"
      echo -n "请输入你的选择(数字): "
      read img_choice

      case "$img_choice" in
        1) docker_img="lscr.io/linuxserver/webtop:ubuntu-kde"; docker_name="webtop-ubuntu-kde"; docker_port=3331;;
        2) docker_img="lscr.io/linuxserver/webtop:latest"; docker_name="webtop-latest"; docker_port=3332;;
        3) docker_img="lscr.io/linuxserver/webtop:arch-kde"; docker_name="webtop-arch-kde"; docker_port=3333;;
        4) docker_img="lscr.io/linuxserver/webtop:ubuntu-gnome"; docker_name="webtop-ubuntu-gnome"; docker_port=3334;;
        5) docker_img="lscr.io/linuxserver/webtop:fedora-xfce"; docker_name="webtop-fedora-xfce"; docker_port=3335;;
        6) docker_img="lscr.io/linuxserver/webtop:ubuntu-xfce"; docker_name="webtop-ubuntu-xfce"; docker_port=3336;;
        7) docker_img="lscr.io/linuxserver/webtop:ubuntu-mate"; docker_name="webtop-ubuntu-mate"; docker_port=3337;;
        8) docker_img="lscr.io/linuxserver/webtop:ubuntu-i3"; docker_name="webtop-ubuntu-i3"; docker_port=3338;;
        9) docker_img="lscr.io/linuxserver/webtop:arch-xfce"; docker_name="webtop-arch-xfce"; docker_port=3339;;
        10) docker_img="lscr.io/linuxserver/webtop:arch-mate"; docker_name="webtop-arch-mate"; docker_port=3340;;
        11) docker_img="lscr.io/linuxserver/webtop:arch-i3"; docker_name="webtop-arch-i3"; docker_port=33341;;
        12) docker_img="lscr.io/linuxserver/webtop:debian-xfce"; docker_name="webtop-debian-xfce"; docker_port=3342;;
        13) docker_img="lscr.io/linuxserver/webtop:debian-mate"; docker_name="webtop-debian-mate"; docker_port=3343;;
        14) docker_img="lscr.io/linuxserver/webtop:debian-i3"; docker_name="webtop-debian-i3"; docker_port=3344;;
        15) docker_img="lscr.io/linuxserver/webtop:debian-kde"; docker_name="webtop-debian-kde"; docker_port=3345;;
        16) docker_img="lscr.io/linuxserver/webtop:fedora-mate"; docker_name="webtop-fedora-mate"; docker_port=3346;;
        17) docker_img="lscr.io/linuxserver/webtop:fedora-kde"; docker_name="webtop-fedora-kde"; docker_port=3347;;
        18) docker_img="lscr.io/linuxserver/webtop:fedora-i3"; docker_name="webtop-fedora-i3"; docker_port=3348;;
        19) docker_img="lscr.io/linuxserver/webtop:el-xfce"; docker_name="webtop-el-xfce"; docker_port=3349;;
        20) docker_img="lscr.io/linuxserver/webtop:el-mate"; docker_name="webtop-el-mate"; docker_port=3350;;
        21) docker_img="lscr.io/linuxserver/webtop:el-i3"; docker_name="webtop-el-i3"; docker_port=3351;;
        22) docker_img="lscr.io/linuxserver/webtop:alpine-xfce"; docker_name="webtop-alpine-xfce"; docker_port=3352;;
        23) docker_img="lscr.io/linuxserver/webtop:alpine-mate"; docker_name="webtop-alpine-mate"; docker_port=3353;;
        24) docker_img="lscr.io/linuxserver/webtop:alpine-i3"; docker_name="webtop-alpine-i3"; docker_port=3354;;
        0)
          echo "返回上一级"
          ;;
        *)
          echo "无效输入"
          ;;
      esac

      if [[ "$img_choice" =~ ^[1-9][0-9]*$ ]] && [ "$img_choice" -ge 1 ] && [ "$img_choice" -le 24 ]; then
        clear
        echo "选择镜像：$docker_img"
        echo "容器名：$docker_name"
        echo "端口号：$docker_port"
        echo "操作："
        echo " 1. 安装"
        echo " 2. 备份"
        echo " 3. 卸载"
        echo " 4. 恢复最新备份"
        echo " 0. 返回上一级"
        echo -n "请输入操作编号: "
        read op_choice

        case "$op_choice" in
          1)
            if docker ps -a --format '{{.Names}}' | grep -qw "$docker_name"; then
              echo "---------------------------------------------"
              echo "容器 $docker_name 已安装，跳过安装"
              echo "访问地址: http://$(curl -s ipv4.ip.sb):$docker_port"
                     echo "访问地址: http://$(curl -s ipv6.ip.sb):$docker_port"
              echo "---------------------------------------------"
            else
              random_passwd=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 18)
              docker run -d \
                --name=$docker_name \
                --security-opt seccomp=unconfined \
                -e PUID=1000 \
                -e PGID=1000 \
                -e TZ=Asia/Shanghai \
                -e LC_ALL=zh_CN.UTF-8 \
                -e CUSTOM_USER=admin \
                -e PASSWORD=$random_passwd \
                -e SUBFOLDER=/ \
                -e TITLE=我的网站目录 \
                -p $docker_port:3000 \
                -v /home/docker/$docker_name/data:/config \
                -v /home/docker/$docker_name/Downloads:/home/abc/Downloads \
                --shm-size="1gb" \
                --restart unless-stopped \
                $docker_img
              echo "安装完成"
              echo "访问地址: http://$(curl -s ipv4.ip.sb):$docker_port"
              echo "访问地址: http://$(curl -s ipv6.ip.sb):$docker_port"
              echo "用户名: admin"
              echo "密码: $random_passwd"
            fi
            ;;
          2)
            backup_file="/home/docker/${docker_name}_backup_$(date +%F_%H%M%S).tar.gz"
            tar -czvf "$backup_file" -C /home/docker "$docker_name"
            echo "备份完成，文件: $backup_file"
            ;;
          3)
            docker stop $docker_name >/dev/null 2>&1
            docker rm $docker_name >/dev/null 2>&1
            rm -rf /home/docker/$docker_name
            echo "容器和数据已删除"
            ;;
          4)
            latest_backup=$(ls -t /home/docker/${docker_name}_backup_*.tar.gz 2>/dev/null | head -n 1)
            if [ -z "$latest_backup" ]; then
              echo "未找到备份文件"
            else
              echo "恢复备份文件: $latest_backup"
              docker stop $docker_name >/dev/null 2>&1
              rm -rf /home/docker/$docker_name
              tar -xzvf "$latest_backup" -C /home/docker
              docker restart $docker_name >/dev/null 2>&1
              echo "恢复完成并重启容器"
            fi
            ;;
          0)
            echo "返回上一级"
            ;;
          *)
            echo "无效操作"
            ;;
        esac
      fi
      ;;

      1000)
        (
        FNOS_SCRIPT=/root/reinstall.sh
        FNOS_DOWNLOAD_URL=https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
        while true; do
          [[ ! -t 1 || ${TERM:-dumb} == dumb ]] || clear
          echo '=================================='
          echo '        fnOS 系统重装'
          echo '警告：重装涉及系统盘数据清除，请先备份。'
          echo "脚本路径：$FNOS_SCRIPT"
          echo '=================================='
          echo '1. 下载脚本'
          echo '2. 执行安装（使用官方地址）'
          echo '3. 指定地址安装（执行时手动输入地址）'
          echo '0. 返回'
          IFS= read -r -p '请输入选项：' fnos_choice || break
          case "$fnos_choice" in
            1)
              if [[ -L $FNOS_SCRIPT ]]; then
                echo '目标脚本为符号链接，拒绝覆盖。'
              else
                fnos_tmp=$(mktemp /root/.reinstall-download.XXXXXX) || break
                if { curl -fL "$FNOS_DOWNLOAD_URL" -o "$fnos_tmp" || wget -O "$fnos_tmp" "$FNOS_DOWNLOAD_URL"; } && [[ -s $fnos_tmp ]] && bash -n "$fnos_tmp"; then
                  chmod 600 "$fnos_tmp" && mv -f -- "$fnos_tmp" "$FNOS_SCRIPT" && echo '脚本下载及语法检查完成；未执行重装。'
                else
                  echo '下载或语法检查失败，原脚本保留。'
                fi
                rm -f -- "$fnos_tmp"
              fi
              ;;
            2|3)
              if [[ ! -f $FNOS_SCRIPT || -L $FNOS_SCRIPT ]]; then
                echo '请先选择1下载脚本。'
              else
                ISO_URL=
                if [[ $fnos_choice == 3 ]]; then
                  IFS= read -r -p '请输入 fnOS ISO 下载地址：' ISO_URL || break
                  if [[ -z $ISO_URL ]]; then
                    echo '地址为空，已取消。'
                    continue
                  fi
                  case "$ISO_URL" in
                    http://*|https://*) ;;
                    *) echo '请输入完整HTTP/HTTPS下载地址。'; continue ;;
                  esac
                fi
                echo '警告：即将执行系统重装脚本，可能清除系统盘数据！'
                IFS= read -r -p '输入小写yes确认执行（其他取消）：' fnos_confirm || break
                if [[ $fnos_confirm == yes ]]; then
                  if [[ $fnos_choice == 3 ]]; then
                    bash "$FNOS_SCRIPT" fnos --iso "$ISO_URL"
                  else
                    bash "$FNOS_SCRIPT" fnos
                  fi
                  fnos_rc=$?
                  echo "重装脚本已退出，返回码：$fnos_rc（不代表系统已安装完成）。"
                else
                  echo '已取消。'
                fi
              fi
              ;;
            0) break ;;
            *) echo '无效选项' ;;
          esac
          IFS= read -r -p '按回车继续...' _ || break
        done
        )
        ;;



      1001)
        echo "▶️ 正在启动A-B-C MySQL 主备容灾管理系统..."
        run_local_first_app_script "▶️ 安装A-B-C MySQL 主备容灾管理系统..." "/root/yingyong/a-b-c-MySQL.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/a-b-c-MySQL.sh"
        echo "✅ A-B-C MySQL 主备容灾管理系统安装完成。"
        ;;

      1002)
        clear
        echo "▶️ 正在启动win10ltls模块..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/win10ltls.sh)
        echo "✅ 远程备份与传送模块执行完成。"
        ;;

      1003)
        (
        clear
        echo "▶️ 正在准备使用 rsync 手动传送文件夹..."

        # 检查并安装 rsync
        if ! command -v rsync > /dev/null 2>&1; then
            echo "⏳ 未检测到 rsync，正在安装中..."
            apt update > /dev/null 2>&1
            apt install -y rsync > /dev/null 2>&1
            echo "✅ rsync 安装完成。"
        else
            echo "✅ rsync 已安装，跳过安装步骤。"

        fi
        echo "------------------------"

        # 读取用户输入
        read -e -p "请输入本地目录路径（默认 /home/备份/，回车使用默认）: " local_path || exit 0
        local_path=${local_path:-/home/备份/}
        if [[ ! -d "$local_path" ]]; then
            echo "❌ 本地目录不存在：$local_path"
            exit 1
        fi
        if [[ $(readlink -f -- "$local_path") == / ]]; then
            echo "❌ 禁止传送整个根目录 /，请指定需要传送的文件夹。"
            exit 1
        fi
        # 如果本地路径末尾没有 /，则自动添加
        [[ "$local_path" != */ ]] && local_path="${local_path}/"

        read -e -p "远程 VPS 的 IP 地址（例如 1.1.1.1）: " remote_ip

        while true; do
            read -e -p "远程 VPS 的端口（默认22）: " remote_port || { remote_port=22; break; }
            remote_port=${remote_port:-22}
            if [[ "$remote_port" =~ ^[0-9]{1,5}$ ]] &&
               (( 10#$remote_port >= 1 && 10#$remote_port <= 65535 )); then
                remote_port=$((10#$remote_port))
                break
            fi
            echo "❌ 端口无效，请输入 1–65535。"
        done

        read -e -p "远程 VPS 的用户名（默认root）: " remote_user
        remote_user=${remote_user:-root}

        # SSH参数同时用于远端检查、安装和rsync传送。
        ssh_options=(-p "$remote_port")
        rsync_ssh="ssh -p $remote_port"
        while true; do
            read -e -p "登录方式默认1（1. 密码 2. SSH密钥 ）: " login_method || { login_method=1; break; }
            login_method=${login_method:-1}
            case "$login_method" in
                1|2) break ;;
                *) echo "❌ 请选择1或2。" ;;
            esac
        done
        if [[ "$login_method" == 2 ]]; then
            while true; do
                read -e -p "SSH私钥文件路径（默认 /root/.ssh/id_ed25519）: " ssh_key_path || { ssh_key_path=""; break; }
                ssh_key_path=${ssh_key_path:-/root/.ssh/id_ed25519}
                if [[ -f "$ssh_key_path" && -r "$ssh_key_path" && "$ssh_key_path" != *$'\n'* && "$ssh_key_path" != *$'\r'* ]]; then
                    break
                fi
                echo "❌ 私钥文件不存在、不可读或路径无效，请重新输入。"
            done
            if [[ -n "$ssh_key_path" ]]; then
                ssh_options+=(-i "$ssh_key_path" -o IdentitiesOnly=yes -o PreferredAuthentications=publickey)
                # rsync自行解析-e参数；引用路径以支持空格和中文。
                ssh_key_escaped=${ssh_key_path//\\/\\\\}
                ssh_key_escaped=${ssh_key_escaped//\"/\\\"}
                rsync_ssh+=" -i \"$ssh_key_escaped\" -o IdentitiesOnly=yes -o PreferredAuthentications=publickey"
            else
                echo "已取消。"
                exit 0
            fi
        else
            ssh_options+=(-o PubkeyAuthentication=no -o PreferredAuthentications=keyboard-interactive,password)
            rsync_ssh+=" -o PubkeyAuthentication=no -o PreferredAuthentications=keyboard-interactive,password"
        fi

        read -e -p "请输入远程目录路径（默认与本地一致，直接回车即可）: " remote_path
        if [ -z "$remote_path" ]; then
            remote_path="$local_path"
            echo "📂 未输入远程路径，已自动设置为与本地路径一致：$remote_path"
        fi


        # 仅复用本次操作的连接；目录内只保存控制socket，不保存密码。
        umask 077
        ssh_control_base=${TMPDIR:-/root/.cache}
        mkdir -p "$ssh_control_base" || exit 1
        ssh_control_dir=$(mktemp -d "$ssh_control_base/rsync-ssh.XXXXXX") || exit 1
        ssh_control_socket="$ssh_control_dir/control"
        cleanup_rsync_ssh() {
            ssh -p "$remote_port" -S "$ssh_control_socket" -O exit \
                "$remote_user@$remote_ip" </dev/null >/dev/null 2>&1 || true
            rm -rf -- "$ssh_control_dir"
        }
        trap cleanup_rsync_ssh EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM

        echo "🔐 建立SSH复用连接（密码/密钥口令仅由SSH交互读取，不保存）..."
        if ! ssh "${ssh_options[@]}" -o ControlMaster=yes \
            -o ControlPath="$ssh_control_socket" -o ControlPersist=60 \
            -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
            -Nf "$remote_user@$remote_ip"; then
            echo "❌ SSH连接失败，取消传送。"
            exit 1
        fi
        # 禁止连接丢失后重新认证；失败则明确退出，不再次索要密码。
        ssh_options+=(-o ControlMaster=no -o ControlPath="$ssh_control_socket" -o BatchMode=yes -o ProxyCommand=false)
        ssh_socket_escaped=${ssh_control_socket//\\/\\\\}
        ssh_socket_escaped=${ssh_socket_escaped//\"/\\\"}
        rsync_ssh+=" -o ControlMaster=no -o ControlPath=\"$ssh_socket_escaped\" -o BatchMode=yes -o ProxyCommand=false"

        # 先创建目标目录；使用远端shell单引号转义，防止空格/中文/引号被拆分或执行。
        if [[ "$remote_path" == *$'\n'* || "$remote_path" == *$'\r'* ]]; then
            echo "❌ 远程目录不能包含换行或回车。"
            exit 1
        fi
        remote_path_quoted="'${remote_path//\'/\'\\\'\'}'"
        echo "📂 正在准备远程目录：$remote_path"
        if ! ssh "${ssh_options[@]}" "$remote_user@$remote_ip" \
            "mkdir -p -- $remote_path_quoted && test -d $remote_path_quoted && test -w $remote_path_quoted"; then
            echo "❌ 无法创建远程目录或目录不可写，取消传送：$remote_path"
            exit 1
        fi
        echo "✅ 远程目录已准备完成。"

        # 检查远程 VPS 是否安装 rsync
        echo "🕵️ 正在检查远程 VPS 是否已安装 rsync..."
        ssh "${ssh_options[@]}" "$remote_user@$remote_ip" "command -v rsync > /dev/null 2>&1"
        remote_rsync_status=$?
        if [[ "$remote_rsync_status" == 255 ]]; then
            echo "❌ SSH复用会话失败，无法判断远端是否安装rsync，取消传送。"
            exit 1
        fi
        if [ "$remote_rsync_status" -ne 0 ]; then
            echo "⚙️ 远程 VPS 未安装 rsync，正在安装..."
            if ! ssh "${ssh_options[@]}" "$remote_user@$remote_ip" "apt update > /dev/null 2>&1 && apt install -y rsync > /dev/null 2>&1 && command -v rsync > /dev/null 2>&1"; then
                echo "❌ 远端rsync安装或SSH连接失败，取消传送。"
                exit 1
            fi
            echo "✅ 远程 VPS 的 rsync 安装完成。"
        else
            echo "✅ 远程 VPS 已安装 rsync，跳过安装。"
        fi


        echo ""
        echo "🚀 开始传送："
        echo "从：$local_path"
        echo "到：$remote_user@$remote_ip:$remote_path（SSH端口：$remote_port）"
        echo ""


        if ! rsync -avz -e "$rsync_ssh" "$local_path" "$remote_user@$remote_ip:$remote_path"; then
            echo "❌ 文件传送失败，请检查连接、路径和权限。"
            exit 1
        fi

        echo ""
        echo "✅ 文件传送完成。"
        echo "------------------------"
        echo ""
        )
        ;;


      1004)
        (
          # 仅安装/管理定时任务，不在打开此选项时执行删除备份。
          local_script='/home/备份/beifen.sh'
          github_script='https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/beifen/beifen.sh'
          if [[ $EUID -ne 0 ]]; then echo '请使用root操作。'; exit 1; fi
          if ! command -v python3 >/dev/null 2>&1; then echo '需先安装python3，未作修改。'; exit 1; fi
          mkdir -p '/home/备份' || exit 1
          if [[ -L "$local_script" ]]; then echo '脚本路径是符号链接，拒绝操作。'; exit 1; fi
          if [[ ! -f "$local_script" ]]; then
            echo '▶️ 正在下载备份清理脚本...'
            tmp_script=$(mktemp '/home/备份/.beifen-download.XXXXXXXX') || exit 1
            trap 'rm -f -- "$tmp_script"' EXIT
            if ! curl -fsSL --connect-timeout 10 --max-time 60 "$github_script" -o "$tmp_script" ||
               [[ ! -s "$tmp_script" ]] || ! bash -n "$tmp_script"; then
              echo '❌ 下载失败或脚本语法错误，未安装、未添加任务。'; exit 1
            fi
            chmod 700 "$tmp_script" && mv -f -- "$tmp_script" "$local_script" || exit 1
            echo '✅ 备份清理脚本安装完成（未执行清理）。'
          else
            echo "本地脚本：$local_script（不执行清理）"
            tmp_script=$(mktemp '/home/备份/.beifen-check.XXXXXXXX') || exit 1
            trap 'rm -f -- "$tmp_script"' EXIT
            if ! curl -fsSL --connect-timeout 3 --max-time 10 "$github_script" -o "$tmp_script" ||
               [[ ! -s "$tmp_script" ]] || ! bash -n "$tmp_script"; then
              echo '远程更新检测失败或远程脚本语法异常，继续使用本地文件。'
            elif cmp -s -- "$local_script" "$tmp_script"; then
              echo '本地与远程内容一致，无需更新。'
            else
              echo '检测到远程与本地内容不同。更新会覆盖本地清理规则。'
              echo '远程文件在/beifen/beifen.sh'
              echo '1. 继续使用本地文件（默认）'
              echo '2. 更新为远程文件'
              echo '0. 返回上一级'
              IFS= read -r -p '请选择 [默认1]：' script_choice || exit 0
              case "${script_choice:-1}" in
                1) echo '保留本地文件，继续检查定时任务。' ;;
                2)
                  IFS= read -r -p '确认使用远程文件覆盖本地清理规则？[y/N]：' update_confirm || exit 0
                  case "$update_confirm" in
                    [Yy]|[Yy][Ee][Ss])
                      chmod 700 "$tmp_script" && mv -f -- "$tmp_script" "$local_script" || exit 1
                      echo '✅ 远程文件已更新，本地原文件未备份（未执行清理）。'
                      ;;
                    *) echo '已取消更新，继续使用本地文件。' ;;
                  esac
                  ;;
                0) exit 0 ;;
                *) echo '无效选项，未更新或修改定时任务。'; exit 1 ;;
              esac
            fi
          fi
          if ! bash -n "$local_script"; then echo '脚本语法错误，未配置定时任务。'; exit 1; fi
          if ! command -v crontab >/dev/null 2>&1; then
            echo '未安装crontab，请先安装cron/cronie后重新进入此选项。'; exit 1
          fi
          python3 - 3<&0 <<'PY_BE清理'
import fcntl,os,pathlib,re,subprocess,sys,tempfile,time
start='# 备份清理';end='# 备份清理结束'
job='*/5 * * * * /bin/bash /home/备份/beifen.sh >/dev/null 2>&1'
state=pathlib.Path('/home/备份/.beifen-cron-enabled')
def readcron():
    p=subprocess.run(['crontab','-l'],capture_output=True,text=True,env={**os.environ,'LC_ALL':'C'})
    if p.returncode==0:return p.stdout
    if p.returncode==1 and 'no crontab for' in p.stderr.lower():return ''
    raise ValueError('无法读取crontab，拒绝覆盖现有任务')
def task(line):
    s=line.strip()
    return bool(s and not s.startswith('#') and re.search(r'(?<![\w/])/home/备份/beifen\.sh(?=[\s\"\x27;]|$)',s))
def ask():
    print('是否添加每5分钟执行一次的备份清理任务？将按脚本规则自动删除旧备份。[y/N]：',end='',flush=True)
    with os.fdopen(os.dup(3)) as inp:return inp.readline().strip().lower() in ('y','yes')
try:
    with open('/run/lock/kejilion-beifen-cron.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        if state.is_symlink():raise ValueError('启用状态文件是符号链接，拒绝操作')
        original=readcron();lines=original.splitlines()
        enabled=state.exists() or any(task(line) for line in lines)
        if not enabled and not ask():
            print('未启用定时清理；下次进入仍会询问。');sys.exit(0)
        # Remove only this task and its markers, leaving unrelated cron lines untouched.
        kept=[line for line in lines if line.strip() not in (start,end) and not task(line)]
        desired='\n'.join(kept+[start,job,end])+'\n'
        if original!=desired:
            backup=pathlib.Path('/home/备份')/('crontab.before-beifen-'+str(time.time_ns())+'.bak')
            fd=os.open(backup,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
            with os.fdopen(fd,'w') as out:out.write(original)
            if readcron()!=original:raise ValueError('其他程序修改了crontab，本次取消，请重试')
            subprocess.run(['crontab','-'],input=desired,text=True,check=True)
            print('原定时任务已备份：'+str(backup))
        if readcron()!=desired:raise ValueError('定时任务读回不一致，未确认成功，请检查crontab')
        fd,tmp=tempfile.mkstemp(prefix='.beifen-enabled-',dir=state.parent)
        try:
            with os.fdopen(fd,'w') as out:out.write('enabled\n')
            os.replace(tmp,state)
        finally:
            if os.path.exists(tmp):os.unlink(tmp)
        print('✅ 备份清理定时任务已启用并校验（每5分钟，已去重/修复）。')
        print(start+'\n'+job+'\n'+end)
        print('任务被意外删除后，再次进入此选项会自动恢复。')
        print('若要彻底停用，请同时删除此任务块和 /home/备份/.beifen-cron-enabled 状态文件。')
except BlockingIOError:print('另一窗口正在配置备份清理任务，请稍后重试。');sys.exit(1)
except (OSError,ValueError,subprocess.SubprocessError) as e:print('❌ 定时任务配置失败：'+str(e));sys.exit(1)
PY_BE清理
        )
        ;;
		
      1005)
        echo "▶️ 正在启动备份合并脚本..."
        run_local_first_app_script "▶️ 安装beifenhebing..." "/root/yingyong/beifenhebing.sh" "https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/beifenhebing.sh"
        echo "✅ 备份合并脚本安装完成。"
        ;;




      0)
        kejilion
        ;;
      *)
        echo "无效的输入!"
        ;;
    esac
    break_end

  done
}


linux_work() {

	while true; do
	  clear
	  send_stats "我的工作区"
	  echo -e "▶ 我的工作区"
	  echo -e "系统将为你提供可以后台常驻运行的工作区，你可以用来执行长时间的任务"
	  echo -e "即使你断开SSH，工作区中的任务也不会中断，后台常驻任务。"
	  echo -e "${gl_huang}提示: ${gl_bai}进入工作区后使用Ctrl+b再单独按d，退出工作区！"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}1号工作区"
	  echo -e "${gl_kjlan}2.   ${gl_bai}2号工作区"
	  echo -e "${gl_kjlan}3.   ${gl_bai}3号工作区"
	  echo -e "${gl_kjlan}4.   ${gl_bai}4号工作区"
	  echo -e "${gl_kjlan}5.   ${gl_bai}5号工作区"
	  echo -e "${gl_kjlan}6.   ${gl_bai}6号工作区"
	  echo -e "${gl_kjlan}7.   ${gl_bai}7号工作区"
	  echo -e "${gl_kjlan}8.   ${gl_bai}8号工作区"
	  echo -e "${gl_kjlan}9.   ${gl_bai}9号工作区"
	  echo -e "${gl_kjlan}10.  ${gl_bai}10号工作区"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}99.  ${gl_bai}工作区管理 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "请输入你的选择: " sub_choice

	  case $sub_choice in

		  1)
			  clear
			  install tmux
			  SESSION_NAME="work1"
			  send_stats "启动工作区$SESSION_NAME"
			  tmux_run

			  ;;
		  2)
			  clear
			  install tmux
			  SESSION_NAME="work2"
			  send_stats "启动工作区$SESSION_NAME"
			  tmux_run
			  ;;
		  3)
			  clear
			  install tmux
			  SESSION_NAME="work3"
			  send_stats "启动工作区$SESSION_NAME"
			  tmux_run
			  ;;
		  4)
			  clear
			  install tmux
			  SESSION_NAME="work4"
			  send_stats "启动工作区$SESSION_NAME"
			  tmux_run
			  ;;
		  5)
			  clear
			  install tmux
			  SESSION_NAME="work5"
			  send_stats "启动工作区$SESSION_NAME"
			  tmux_run
			  ;;
		  6)
			  clear
			  install tmux
			  SESSION_NAME="work6"
			  send_stats "启动工作区$SESSION_NAME"
			  tmux_run
			  ;;
		  7)
			  clear
			  install tmux
			  SESSION_NAME="work7"
			  send_stats "启动工作区$SESSION_NAME"
			  tmux_run
			  ;;
		  8)
			  clear
			  install tmux
			  SESSION_NAME="work8"
			  send_stats "启动工作区$SESSION_NAME"
			  tmux_run
			  ;;
		  9)
			  clear
			  install tmux
			  SESSION_NAME="work9"
			  send_stats "启动工作区$SESSION_NAME"
			  tmux_run
			  ;;
		  10)
			  clear
			  install tmux
			  SESSION_NAME="work10"
			  send_stats "启动工作区$SESSION_NAME"
			  tmux_run
			  ;;

		  99)
			while true; do
			  clear
			  send_stats "工作区管理"
			  echo "当前已存在的工作区列表"
			  echo "------------------------"
			  tmux list-sessions
			  echo "------------------------"
			  echo "1. 创建/进入工作区"
			  echo "2. 注入命令到后台工作区"
			  echo "3. 删除指定工作区"
			  echo "------------------------"
			  echo "0. 返回上一级"
			  echo "------------------------"
			  read -e -p "请输入你的选择: " gongzuoqu_del
			  case "$gongzuoqu_del" in
				1)
				  read -e -p "请输入你创建或进入的工作区名称，如1001 kj001 work1: " SESSION_NAME
				  tmux_run
				  send_stats "自定义工作区"
				  ;;

				2)
				  read -e -p "请输入你要后台执行的命令，如:curl -fsSL https://get.docker.com | sh: " tmuxd
				  tmux_run_d
				  send_stats "注入命令到后台工作区"
				  ;;

				3)
				  read -e -p "请输入要删除的工作区名称: " gongzuoqu_name
				  tmux kill-window -t $gongzuoqu_name
				  send_stats "删除工作区"
				  ;;
				0)
				  break
				  ;;
				*)
				  echo "无效的选择，请输入 Y 或 N。"
				  ;;
			  esac
			done

			  ;;
		  0)
			  kejilion
			  ;;
		  *)
			  echo "无效的输入!"
			  ;;
	  esac
	  break_end

	done


}












linux_Settings() {

	while true; do
	  clear
	  # send_stats "系统工具"
	  echo -e "▶ 系统工具"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}设置脚本启动快捷键                 ${gl_kjlan}2.   ${gl_bai}修改登录密码 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}3.   ${gl_bai}ROOT密码登录模式                   ${gl_kjlan}4.   ${gl_bai}安装Python指定版本"
	  echo -e "${gl_kjlan}5.   ${gl_bai}开放所有端口                       ${gl_kjlan}6.   ${gl_bai}修改SSH连接端口"
	  echo -e "${gl_kjlan}7.   ${gl_bai}优化DNS地址                        ${gl_kjlan}8.   ${gl_bai}一键重装系统 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}9.   ${gl_bai}禁用ROOT账户创建新账户             ${gl_kjlan}10.  ${gl_bai}切换优先ipv4/ipv6"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}11.  ${gl_bai}查看端口占用状态                   ${gl_kjlan}12.  ${gl_bai}修改虚拟内存大小"
	  echo -e "${gl_kjlan}13.  ${gl_bai}用户管理                           ${gl_kjlan}14.  ${gl_bai}用户/密码生成器"
	  echo -e "${gl_kjlan}15.  ${gl_bai}系统时区调整 ${gl_huang}★${gl_bai}                       ${gl_kjlan}16.  ${gl_bai}设置BBR3加速"
	  echo -e "${gl_kjlan}17.  ${gl_bai}防火墙高级管理器                   ${gl_kjlan}18.  ${gl_bai}修改主机名"
	  echo -e "${gl_kjlan}19.  ${gl_bai}切换系统更新源                     ${gl_kjlan}20.  ${gl_bai}定时任务管理"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}21.  ${gl_bai}本机host解析                       ${gl_kjlan}22.  ${gl_bai}fail2banSSH防御程序"
	  echo -e "${gl_kjlan}23.  ${gl_bai}限流自动关机                       ${gl_kjlan}24.  ${gl_bai}ROOT私钥登录模式"
	  echo -e "${gl_kjlan}25.  ${gl_bai}TG-bot系统监控预警                 ${gl_kjlan}26.  ${gl_bai}修复OpenSSH高危漏洞（岫源）"
	  echo -e "${gl_kjlan}27.  ${gl_bai}红帽系Linux内核升级                ${gl_kjlan}28.  ${gl_bai}Linux系统内核参数优化 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}29.  ${gl_bai}病毒扫描工具 ${gl_huang}★${gl_bai}                     ${gl_kjlan}30.  ${gl_bai}文件管理器"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}31.  ${gl_bai}切换系统语言                       ${gl_kjlan}32.  ${gl_bai}命令行美化工具"
	  echo -e "${gl_kjlan}33.  ${gl_bai}设置系统回收站"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}41.  ${gl_bai}留言板                             ${gl_kjlan}66.  ${gl_bai}一条龙系统调优 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}99.  ${gl_bai}重启服务器                         ${gl_kjlan}100. ${gl_bai}隐私与安全"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}101. ${gl_bai}卸载科技lion脚本"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "请输入你的选择: " sub_choice

	  case $sub_choice in
		  1)
			  while true; do
				  clear
				  read -e -p "请输入你的快捷按键（输入0退出）: " kuaijiejian
				  if [ "$kuaijiejian" == "0" ]; then
					   break_end
					   linux_Settings
				  fi

				  sed -i '/alias .*='\''k'\''$/d' ~/.bashrc

				  echo "alias $kuaijiejian='k'" >> ~/.bashrc
				  sleep 1
				  source ~/.bashrc

				  echo "快捷键已设置"
				  send_stats "脚本快捷键已设置"
				  break_end
				  linux_Settings
			  done
			  ;;

		  2)
			  clear
			  send_stats "设置你的登录密码"
			  echo "设置你的登录密码"
			  passwd
			  ;;
		  3)
			  root_use
			  send_stats "root密码模式"
			  add_sshpasswd
			  ;;

		  4)
			root_use
			send_stats "py版本管理"
			echo "python版本管理"
			echo "视频介绍: https://www.bilibili.com/video/BV1Pm42157cK?t=0.1"
			echo "---------------------------------------"
			echo "该功能可无缝安装python官方支持的任何版本！"
			VERSION=$(python3 -V 2>&1 | awk '{print $2}')
			echo -e "当前python版本号: ${gl_huang}$VERSION${gl_bai}"
			echo "------------"
			echo "推荐版本:  3.12    3.11    3.10    3.9    3.8    2.7"
			echo "查询更多版本: https://www.python.org/downloads/"
			echo "------------"
			read -e -p "输入你要安装的python版本号（输入0退出）: " py_new_v


			if [[ "$py_new_v" == "0" ]]; then
				send_stats "脚本PY管理"
				break_end
				linux_Settings
			fi


			if ! grep -q 'export PYENV_ROOT="\$HOME/.pyenv"' ~/.bashrc; then
				if command -v yum &>/dev/null; then
					yum update -y && yum install git -y
					yum groupinstall "Development Tools" -y
					yum install openssl-devel bzip2-devel libffi-devel ncurses-devel zlib-devel readline-devel sqlite-devel xz-devel findutils -y

					curl -O https://www.openssl.org/source/openssl-1.1.1u.tar.gz
					tar -xzf openssl-1.1.1u.tar.gz
					cd openssl-1.1.1u
					./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib
					make
					make install
					echo "/usr/local/openssl/lib" > /etc/ld.so.conf.d/openssl-1.1.1u.conf
					ldconfig -v
					cd ..

					export LDFLAGS="-L/usr/local/openssl/lib"
					export CPPFLAGS="-I/usr/local/openssl/include"
					export PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig"

				elif command -v apt &>/dev/null; then
					apt update -y && apt install git -y
					apt install build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev libgdbm-dev libnss3-dev libedit-dev -y
				elif command -v apk &>/dev/null; then
					apk update && apk add git
					apk add --no-cache bash gcc musl-dev libffi-dev openssl-dev bzip2-dev zlib-dev readline-dev sqlite-dev libc6-compat linux-headers make xz-dev build-base  ncurses-dev
				else
					echo "未知的包管理器!"
					return
				fi

				curl https://pyenv.run | bash
				cat << EOF >> ~/.bashrc

export PYENV_ROOT="\$HOME/.pyenv"
if [[ -d "\$PYENV_ROOT/bin" ]]; then
  export PATH="\$PYENV_ROOT/bin:\$PATH"
fi
eval "\$(pyenv init --path)"
eval "\$(pyenv init -)"
eval "\$(pyenv virtualenv-init -)"

EOF

			fi

			sleep 1
			source ~/.bashrc
			sleep 1
			pyenv install $py_new_v
			pyenv global $py_new_v

			rm -rf /tmp/python-build.*
			rm -rf $(pyenv root)/cache/*

			VERSION=$(python -V 2>&1 | awk '{print $2}')
			echo -e "当前python版本号: ${gl_huang}$VERSION${gl_bai}"
			send_stats "脚本PY版本切换"

			  ;;

		  5)
			  root_use
			  send_stats "开放端口"
			  iptables_open
			  remove iptables-persistent ufw firewalld iptables-services > /dev/null 2>&1
			  echo "端口已全部开放"

			  ;;
		  6)
			root_use
			send_stats "修改SSH端口"

			while true; do
				clear
				sed -i 's/#Port/Port/' /etc/ssh/sshd_config

				# 读取当前的 SSH 端口号
				current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

				# 打印当前的 SSH 端口号
				echo -e "当前的 SSH 端口号是:  ${gl_huang}$current_port ${gl_bai}"

				echo "------------------------"
				echo "端口号范围1到65535之间的数字。（输入0退出）"

				# 提示用户输入新的 SSH 端口号
				read -e -p "请输入新的 SSH 端口号: " new_port

				# 判断端口号是否在有效范围内
				if [[ $new_port =~ ^[0-9]+$ ]]; then  # 检查输入是否为数字
					if [[ $new_port -ge 1 && $new_port -le 65535 ]]; then
						send_stats "SSH端口已修改"
						new_ssh_port
					elif [[ $new_port -eq 0 ]]; then
						send_stats "退出SSH端口修改"
						break
					else
						echo "端口号无效，请输入1到65535之间的数字。"
						send_stats "输入无效SSH端口"
						break_end
					fi
				else
					echo "输入无效，请输入数字。"
					send_stats "输入无效SSH端口"
					break_end
				fi
			done


			  ;;


		  7)
			root_use
			send_stats "优化DNS"

			while true; do
				clear
				echo "优化DNS地址"
				echo "------------------------"
				echo "当前DNS地址"
				cat /etc/resolv.conf
				echo "------------------------"
				echo ""
				echo "1. 国外DNS优化: "
				echo " v4: 1.1.1.1 8.8.8.8"
				echo " v6: 2606:4700:4700::1111 2001:4860:4860::8888"
				echo "2. 国内DNS优化: "
				echo " v4: 223.5.5.5 183.60.83.19"
				echo " v6: 2400:3200::1 2400:da00::6666"
				echo "3. 手动编辑DNS配置"
				echo "------------------------"
				echo "0. 返回上一级"
				echo "------------------------"
				read -e -p "请输入你的选择: " Limiting
				case "$Limiting" in
				  1)
					dns1_ipv4="1.1.1.1"
					dns2_ipv4="8.8.8.8"
					dns1_ipv6="2606:4700:4700::1111"
					dns2_ipv6="2001:4860:4860::8888"
					set_dns
					send_stats "国外DNS优化"
					;;
				  2)
					dns1_ipv4="223.5.5.5"
					dns2_ipv4="183.60.83.19"
					dns1_ipv6="2400:3200::1"
					dns2_ipv6="2400:da00::6666"
					set_dns
					send_stats "国内DNS优化"
					;;
				  3)
					install nano
					nano /etc/resolv.conf
					send_stats "手动编辑DNS配置"
					;;
				  *)
					break
					;;
				esac
			done
			  ;;

		  8)

			dd_xitong
			  ;;
		  9)
			root_use
			send_stats "新用户禁用root"
			read -e -p "请输入新用户名（输入0退出）: " new_username
			if [ "$new_username" == "0" ]; then
				break_end
				linux_Settings
			fi

			useradd -m -s /bin/bash "$new_username"
			passwd "$new_username"

			echo "$new_username ALL=(ALL:ALL) ALL" | tee -a /etc/sudoers

			passwd -l root

			echo "操作已完成。"
			;;


		  10)
			root_use
			send_stats "设置v4/v6优先级"
			while true; do
				clear
				echo "设置v4/v6优先级"
				echo "------------------------"
				ipv6_disabled=$(sysctl -n net.ipv6.conf.all.disable_ipv6)

				if [ "$ipv6_disabled" -eq 1 ]; then
					echo -e "当前网络优先级设置: ${gl_huang}IPv4${gl_bai} 优先"
				else
					echo -e "当前网络优先级设置: ${gl_huang}IPv6${gl_bai} 优先"
				fi
				echo ""
				echo "------------------------"
				echo "1. IPv4 优先          2. IPv6 优先          3. IPv6 修复工具          0. 退出"
				echo "------------------------"
				read -e -p "选择优先的网络: " choice

				case $choice in
					1)
						sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null 2>&1
						echo "已切换为 IPv4 优先"
						send_stats "已切换为 IPv4 优先"
						;;
					2)
						sysctl -w net.ipv6.conf.all.disable_ipv6=0 > /dev/null 2>&1
						echo "已切换为 IPv6 优先"
						send_stats "已切换为 IPv6 优先"
						;;

					3)
						clear
						bash <(curl -L -s jhb.ovh/jb/v6.sh)
						echo "该功能由jhb大神提供，感谢他！"
						send_stats "ipv6修复"
						;;

					*)
						break
						;;

				esac
			done
			;;

		  11)
			clear
			ss -tulnape
			;;

		  12)
			root_use
			send_stats "设置虚拟内存"
			while true; do
				clear
				echo "设置虚拟内存"
				swap_used=$(free -m | awk 'NR==3{print $3}')
				swap_total=$(free -m | awk 'NR==3{print $2}')
				swap_info=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; printf "%dMB/%dMB (%d%%)", used, total, percentage}')

				echo -e "当前虚拟内存: ${gl_huang}$swap_info${gl_bai}"
				echo "------------------------"
				echo "1. 分配1024MB         2. 分配2048MB         3. 自定义大小         0. 退出"
				echo "------------------------"
				read -e -p "请输入你的选择: " choice

				case "$choice" in
				  1)
					send_stats "已设置1G虚拟内存"
					new_swap=1024
					add_swap

					;;
				  2)
					send_stats "已设置2G虚拟内存"
					new_swap=2048
					add_swap

					;;
				  3)
					read -e -p "请输入虚拟内存大小MB: " new_swap
					add_swap
					send_stats "已设置自定义虚拟内存"
					;;

				  *)
					break
					;;
				esac
			done
			;;

		  13)
			  while true; do
				root_use
				send_stats "用户管理"
				echo "用户列表"
				echo "----------------------------------------------------------------------------"
				printf "%-24s %-34s %-20s %-10s\n" "用户名" "用户权限" "用户组" "sudo权限"
				while IFS=: read -r username _ userid groupid _ _ homedir shell; do
					groups=$(groups "$username" | cut -d : -f 2)
					sudo_status=$(sudo -n -lU "$username" 2>/dev/null | grep -q '(ALL : ALL)' && echo "Yes" || echo "No")
					printf "%-20s %-30s %-20s %-10s\n" "$username" "$homedir" "$groups" "$sudo_status"
				done < /etc/passwd


				  echo ""
				  echo "账户操作"
				  echo "------------------------"
				  echo "1. 创建普通账户             2. 创建高级账户"
				  echo "------------------------"
				  echo "3. 赋予最高权限             4. 取消最高权限"
				  echo "------------------------"
				  echo "5. 删除账号"
				  echo "------------------------"
				  echo "0. 返回上一级选单"
				  echo "------------------------"
				  read -e -p "请输入你的选择: " sub_choice

				  case $sub_choice in
					  1)
					   # 提示用户输入新用户名
					   read -e -p "请输入新用户名: " new_username

					   # 创建新用户并设置密码
					   useradd -m -s /bin/bash "$new_username"
					   passwd "$new_username"

					   echo "操作已完成。"
						  ;;

					  2)
					   # 提示用户输入新用户名
					   read -e -p "请输入新用户名: " new_username

					   # 创建新用户并设置密码
					   useradd -m -s /bin/bash "$new_username"
					   passwd "$new_username"

					   # 赋予新用户sudo权限
					   echo "$new_username ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers

					   echo "操作已完成。"

						  ;;
					  3)
					   read -e -p "请输入用户名: " username
					   # 赋予新用户sudo权限
					   echo "$username ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers
						  ;;
					  4)
					   read -e -p "请输入用户名: " username
					   # 从sudoers文件中移除用户的sudo权限
					   sed -i "/^$username\sALL=(ALL:ALL)\sALL/d" /etc/sudoers

						  ;;
					  5)
					   read -e -p "请输入要删除的用户名: " username
					   # 删除用户及其主目录
					   userdel -r "$username"
						  ;;

					  0)
						  break  # 跳出循环，退出菜单
						  ;;

					  *)
						  break  # 跳出循环，退出菜单
						  ;;
				  esac
			  done
			  ;;

		  14)
			clear
			send_stats "用户信息生成器"
			echo "随机用户名"
			echo "------------------------"
			for i in {1..5}; do
				username="user$(< /dev/urandom tr -dc _a-z0-9 | head -c6)"
				echo "随机用户名 $i: $username"
			done

			echo ""
			echo "随机姓名"
			echo "------------------------"
			first_names=("John" "Jane" "Michael" "Emily" "David" "Sophia" "William" "Olivia" "James" "Emma" "Ava" "Liam" "Mia" "Noah" "Isabella")
			last_names=("Smith" "Johnson" "Brown" "Davis" "Wilson" "Miller" "Jones" "Garcia" "Martinez" "Williams" "Lee" "Gonzalez" "Rodriguez" "Hernandez")

			# 生成5个随机用户姓名
			for i in {1..5}; do
				first_name_index=$((RANDOM % ${#first_names[@]}))
				last_name_index=$((RANDOM % ${#last_names[@]}))
				user_name="${first_names[$first_name_index]} ${last_names[$last_name_index]}"
				echo "随机用户姓名 $i: $user_name"
			done

			echo ""
			echo "随机UUID"
			echo "------------------------"
			for i in {1..5}; do
				uuid=$(cat /proc/sys/kernel/random/uuid)
				echo "随机UUID $i: $uuid"
			done

			echo ""
			echo "16位随机密码"
			echo "------------------------"
			for i in {1..5}; do
				password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16)
				echo "随机密码 $i: $password"
			done

			echo ""
			echo "32位随机密码"
			echo "------------------------"
			for i in {1..5}; do
				password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
				echo "随机密码 $i: $password"
			done
			echo ""

			  ;;

		  15)
			root_use
			send_stats "换时区"
			while true; do
				clear
				echo "系统时间信息"

				# 获取当前系统时区
				timezone=$(current_timezone)

				# 获取当前系统时间
				current_time=$(date +"%Y-%m-%d %H:%M:%S")

				# 显示时区和时间
				echo "当前系统时区：$timezone"
				echo "当前系统时间：$current_time"

				echo ""
				echo "时区切换"
				echo "------------------------"
				echo "亚洲"
				echo "1.  中国上海时间             2.  中国香港时间"
				echo "3.  日本东京时间             4.  韩国首尔时间"
				echo "5.  新加坡时间               6.  印度加尔各答时间"
				echo "7.  阿联酋迪拜时间           8.  澳大利亚悉尼时间"
				echo "9.  泰国曼谷时间"
				echo "------------------------"
				echo "欧洲"
				echo "11. 英国伦敦时间             12. 法国巴黎时间"
				echo "13. 德国柏林时间             14. 俄罗斯莫斯科时间"
				echo "15. 荷兰尤特赖赫特时间       16. 西班牙马德里时间"
				echo "------------------------"
				echo "美洲"
				echo "21. 美国西部时间             22. 美国东部时间"
				echo "23. 加拿大时间               24. 墨西哥时间"
				echo "25. 巴西时间                 26. 阿根廷时间"
				echo "------------------------"
				echo "0. 返回上一级选单"
				echo "------------------------"
				read -e -p "请输入你的选择: " sub_choice


				case $sub_choice in
					1) set_timedate Asia/Shanghai ;;
					2) set_timedate Asia/Hong_Kong ;;
					3) set_timedate Asia/Tokyo ;;
					4) set_timedate Asia/Seoul ;;
					5) set_timedate Asia/Singapore ;;
					6) set_timedate Asia/Kolkata ;;
					7) set_timedate Asia/Dubai ;;
					8) set_timedate Australia/Sydney ;;
					9) set_timedate Asia/Bangkok ;;
					11) set_timedate Europe/London ;;
					12) set_timedate Europe/Paris ;;
					13) set_timedate Europe/Berlin ;;
					14) set_timedate Europe/Moscow ;;
					15) set_timedate Europe/Amsterdam ;;
					16) set_timedate Europe/Madrid ;;
					21) set_timedate America/Los_Angeles ;;
					22) set_timedate America/New_York ;;
					23) set_timedate America/Vancouver ;;
					24) set_timedate America/Mexico_City ;;
					25) set_timedate America/Sao_Paulo ;;
					26) set_timedate America/Argentina/Buenos_Aires ;;
					0) break ;; # 跳出循环，退出菜单
					*) break ;; # 跳出循环，退出菜单
				esac
			done
			  ;;

		  16)

			bbrv3
			  ;;

		  17)
		  root_use
		  while true; do
			if dpkg -l | grep -q iptables-persistent; then
				  clear
				  echo "高级防火墙管理"
				  send_stats "高级防火墙管理"
				  echo "------------------------"
				  iptables -L INPUT

				  echo ""
				  echo "防火墙管理"
				  echo "------------------------"
				  echo "1. 开放指定端口              2. 关闭指定端口"
				  echo "3. 开放所有端口              4. 关闭所有端口"
				  echo "------------------------"
				  echo "5. IP白名单                  6. IP黑名单"
				  echo "7. 清除指定IP"
				  echo "------------------------"
				  echo "9. 卸载防火墙"
				  echo "------------------------"
				  echo "0. 返回上一级选单"
				  echo "------------------------"
				  read -e -p "请输入你的选择: " sub_choice

				  case $sub_choice in
					  1)
						   read -e -p "请输入开放的端口号: " o_port
						   sed -i "/COMMIT/i -A INPUT -p tcp --dport $o_port -j ACCEPT" /etc/iptables/rules.v4
						   sed -i "/COMMIT/i -A INPUT -p udp --dport $o_port -j ACCEPT" /etc/iptables/rules.v4
						   iptables-restore < /etc/iptables/rules.v4
						   send_stats "开放指定端口"

						  ;;
					  2)
						  read -e -p "请输入关闭的端口号: " c_port
						  sed -i "/--dport $c_port/d" /etc/iptables/rules.v4
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "关闭指定端口"
						  ;;

					  3)
						  current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

						  cat > /etc/iptables/rules.v4 << EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A FORWARD -i lo -j ACCEPT
-A INPUT -p tcp --dport $current_port -j ACCEPT
COMMIT
EOF
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "开放所有端口"
						  ;;
					  4)
						  current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

						  cat > /etc/iptables/rules.v4 << EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A FORWARD -i lo -j ACCEPT
-A INPUT -p tcp --dport $current_port -j ACCEPT
COMMIT
EOF
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "关闭所有端口"
						  ;;

					  5)
						  read -e -p "请输入放行的IP: " o_ip
						  sed -i "/COMMIT/i -A INPUT -s $o_ip -j ACCEPT" /etc/iptables/rules.v4
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "IP白名单"
						  ;;

					  6)
						  read -e -p "请输入封锁的IP: " c_ip
						  sed -i "/COMMIT/i -A INPUT -s $c_ip -j DROP" /etc/iptables/rules.v4
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "IP黑名单"
						  ;;

					  7)
						  read -e -p "请输入清除的IP: " d_ip
						  sed -i "/-A INPUT -s $d_ip/d" /etc/iptables/rules.v4
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "清除指定IP"
						  ;;

					  9)
						  remove iptables-persistent
						  rm /etc/iptables/rules.v4
						  send_stats "卸载防火墙"
						  break

						  ;;

					  *)
						  break  # 跳出循环，退出菜单
						  ;;

				  esac
			else

				clear
				echo "将为你安装防火墙，该防火墙仅支持Debian/Ubuntu"
				echo "------------------------------------------------"
				read -e -p "确定继续吗？(Y/N): " choice

				case "$choice" in
				  [Yy])
					if [ -r /etc/os-release ]; then
						. /etc/os-release
						if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
							echo "当前环境不支持，仅支持Debian和Ubuntu系统"
							break_end
							linux_Settings
						fi
					else
						echo "无法确定操作系统类型"
						break
					fi

					clear
					iptables_open
					remove iptables-persistent ufw
					rm /etc/iptables/rules.v4

					apt update -y && apt install -y iptables-persistent

					current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

					cat > /etc/iptables/rules.v4 << EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A FORWARD -i lo -j ACCEPT
-A INPUT -p tcp --dport $current_port -j ACCEPT
COMMIT
EOF

					iptables-restore < /etc/iptables/rules.v4
					systemctl enable netfilter-persistent
					echo "防火墙安装完成"
					break_end
					;;
				  *)
					echo "已取消"
					break
					;;
				esac
			fi
		  done
			  ;;

		  18)
		  root_use
		  send_stats "修改主机名"

		  while true; do
			  clear
			  current_hostname=$(uname -n)
			  echo -e "当前主机名: ${gl_huang}$current_hostname${gl_bai}"
			  echo "------------------------"
			  read -e -p "请输入新的主机名（输入0退出）: " new_hostname
			  if [ -n "$new_hostname" ] && [ "$new_hostname" != "0" ]; then
				  if [ -f /etc/alpine-release ]; then
					  # Alpine
					  echo "$new_hostname" > /etc/hostname
					  hostname "$new_hostname"
				  else
					  # 其他系统，如 Debian, Ubuntu, CentOS 等
					  hostnamectl set-hostname "$new_hostname"
					  sed -i "s/$current_hostname/$new_hostname/g" /etc/hostname
					  systemctl restart systemd-hostnamed
				  fi

				  if grep -q "127.0.0.1" /etc/hosts; then
					  sed -i "s/127.0.0.1 .*/127.0.0.1       $new_hostname localhost localhost.localdomain/g" /etc/hosts
				  else
					  echo "127.0.0.1       $new_hostname localhost localhost.localdomain" >> /etc/hosts
				  fi

				  if grep -q "^::1" /etc/hosts; then
					  sed -i "s/^::1 .*/::1             $new_hostname localhost localhost.localdomain ipv6-localhost ipv6-loopback/g" /etc/hosts
				  else
					  echo "::1             $new_hostname localhost localhost.localdomain ipv6-localhost ipv6-loopback" >> /etc/hosts
				  fi

				  echo "主机名已更改为: $new_hostname"
				  send_stats "主机名已更改"
				  sleep 1
			  else
				  echo "已退出，未更改主机名。"
				  break
			  fi
		  done
			  ;;

		  19)
		  root_use
		  send_stats "换系统更新源"
		  clear
		  echo "选择更新源区域"
		  echo "接入LinuxMirrors切换系统更新源"
		  echo "------------------------"
		  echo "1. 中国大陆【默认】          2. 中国大陆【教育网】          3. 海外地区"
		  echo "------------------------"
		  echo "0. 返回上一级"
		  echo "------------------------"
		  read -e -p "输入你的选择: " choice

		  case $choice in
			  1)
				  send_stats "中国大陆默认源"
				  bash <(curl -sSL https://linuxmirrors.cn/main.sh)
				  ;;
			  2)
				  send_stats "中国大陆教育源"
				  bash <(curl -sSL https://linuxmirrors.cn/main.sh) --edu
				  ;;
			  3)
				  send_stats "海外源"
				  bash <(curl -sSL https://linuxmirrors.cn/main.sh) --abroad
				  ;;
			  *)
				  echo "已取消"
				  ;;

		  esac

			  ;;

		  20)
		  send_stats "定时任务管理"
			  while true; do
				  clear
				  check_crontab_installed
				  clear
				  echo "定时任务列表"
				  crontab -l
				  echo ""
				  echo "操作"
				  echo "------------------------"
				  echo "1. 添加定时任务              2. 删除定时任务              3. 编辑定时任务"
				  echo "------------------------"
				  echo "0. 返回上一级选单"
				  echo "------------------------"
				  read -e -p "请输入你的选择: " sub_choice

				  case $sub_choice in
					  1)
						  read -e -p "请输入新任务的执行命令: " newquest
						  echo "------------------------"
						  echo "1. 每月任务                 2. 每周任务"
						  echo "3. 每天任务                 4. 每小时任务"
						  echo "------------------------"
						  read -e -p "请输入你的选择: " dingshi

						  case $dingshi in
							  1)
								  read -e -p "选择每月的几号执行任务？ (1-30): " day
								  (crontab -l ; echo "0 0 $day * * $newquest") | crontab - > /dev/null 2>&1
								  ;;
							  2)
								  read -e -p "选择周几执行任务？ (0-6，0代表星期日): " weekday
								  (crontab -l ; echo "0 0 * * $weekday $newquest") | crontab - > /dev/null 2>&1
								  ;;
							  3)
								  read -e -p "选择每天几点执行任务？（小时，0-23）: " hour
								  (crontab -l ; echo "0 $hour * * * $newquest") | crontab - > /dev/null 2>&1
								  ;;
							  4)
								  read -e -p "输入每小时的第几分钟执行任务？（分钟，0-60）: " minute
								  (crontab -l ; echo "$minute * * * * $newquest") | crontab - > /dev/null 2>&1
								  ;;
							  *)
								  break  # 跳出
								  ;;
						  esac
						  send_stats "添加定时任务"
						  ;;
					  2)
						  read -e -p "请输入需要删除任务的关键字: " kquest
						  crontab -l | grep -v "$kquest" | crontab -
						  send_stats "删除定时任务"
						  ;;
					  3)
						  crontab -e
						  send_stats "编辑定时任务"
						  ;;
					  0)
						  break  # 跳出循环，退出菜单
						  ;;

					  *)
						  break  # 跳出循环，退出菜单
						  ;;
				  esac
			  done

			  ;;

		  21)
			  root_use
			  send_stats "本地host解析"
			  while true; do
				  clear
				  echo "本机host解析列表"
				  echo "如果你在这里添加解析匹配，将不再使用动态解析了"
				  cat /etc/hosts
				  echo ""
				  echo "操作"
				  echo "------------------------"
				  echo "1. 添加新的解析              2. 删除解析地址"
				  echo "------------------------"
				  echo "0. 返回上一级选单"
				  echo "------------------------"
				  read -e -p "请输入你的选择: " host_dns

				  case $host_dns in
					  1)
						  read -e -p "请输入新的解析记录 格式: 8.8.8.8 bing.com : " addhost
						  echo "$addhost" >> /etc/hosts
						  send_stats "本地host解析新增"

						  ;;
					  2)
						  read -e -p "请输入需要删除的解析内容关键字: " delhost
						  sed -i "/$delhost/d" /etc/hosts
						  send_stats "本地host解析删除"
						  ;;
					  0)
						  break  # 跳出循环，退出菜单
						  ;;

					  *)
						  break  # 跳出循环，退出菜单
						  ;;
				  esac
			  done
			  ;;

		  22)
		  root_use
		  send_stats "ssh防御"
		  while true; do
			if docker inspect fail2ban &>/dev/null ; then
					clear
					echo "SSH防御程序已启动"
					echo "------------------------"
					echo "1. 查看SSH拦截记录"
					echo "2. 日志实时监控"
					echo "------------------------"
					echo "9. 卸载防御程序"
					echo "------------------------"
					echo "0. 退出"
					echo "------------------------"
					read -e -p "请输入你的选择: " sub_choice
					case $sub_choice in

						1)
							echo "------------------------"
							f2b_sshd
							echo "------------------------"
							break_end
							;;
						2)
							tail -f /path/to/fail2ban/config/log/fail2ban/fail2ban.log
							break
							;;
						9)
							docker rm -f fail2ban
							rm -rf /path/to/fail2ban
							echo "Fail2Ban防御程序已卸载"
							break
							;;
						*)
							echo "已取消"
							break
							;;
					esac

			elif [ -x "$(command -v fail2ban-client)" ] ; then
				clear
				echo "卸载旧版fail2ban"
				read -e -p "确定继续吗？(Y/N): " choice
				case "$choice" in
				  [Yy])
					remove fail2ban
					rm -rf /etc/fail2ban
					echo "Fail2Ban防御程序已卸载"
					break_end
					;;
				  *)
					echo "已取消"
					break
					;;
				esac

			else

			  clear
			  echo "fail2ban是一个SSH防止暴力破解工具"
			  echo "官网介绍: ${gh_proxy}https://github.com/fail2ban/fail2ban"
			  echo "------------------------------------------------"
			  echo "工作原理：研判非法IP恶意高频访问SSH端口，自动进行IP封锁"
			  echo "------------------------------------------------"
			  read -e -p "确定继续吗？(Y/N): " choice

			  case "$choice" in
				[Yy])
				  clear
				  install_docker
				  f2b_install_sshd

				  cd ~
				  f2b_status
				  echo "Fail2Ban防御程序已开启"
				  send_stats "ssh防御安装完成"
				  break_end
				  ;;
				*)
				  echo "已取消"
				  break
				  ;;
			  esac
			fi
		  done
			  ;;


		  23)
			root_use
			send_stats "限流关机功能"
			while true; do
				clear
				echo "限流关机功能"
				echo "视频介绍: https://www.bilibili.com/video/BV1mC411j7Qd?t=0.1"
				echo "------------------------------------------------"
				echo "当前流量使用情况，重启服务器流量计算会清零！"
				output_status
				echo "$output"

				# 检查是否存在 Limiting_Shut_down.sh 文件
				if [ -f ~/Limiting_Shut_down.sh ]; then
					# 获取 threshold_gb 的值
					rx_threshold_gb=$(grep -oP 'rx_threshold_gb=\K\d+' ~/Limiting_Shut_down.sh)
					tx_threshold_gb=$(grep -oP 'tx_threshold_gb=\K\d+' ~/Limiting_Shut_down.sh)
					echo -e "${gl_lv}当前设置的进站限流阈值为: ${gl_huang}${rx_threshold_gb}${gl_lv}GB${gl_bai}"
					echo -e "${gl_lv}当前设置的出站限流阈值为: ${gl_huang}${tx_threshold_gb}${gl_lv}GB${gl_bai}"
				else
					echo -e "${hui}当前未启用限流关机功能${gl_bai}"
				fi

				echo
				echo "------------------------------------------------"
				echo "系统每分钟会检测实际流量是否到达阈值，到达后会自动关闭服务器！"
				read -e -p "1. 开启限流关机功能    2. 停用限流关机功能    0. 退出  : " Limiting

				case "$Limiting" in
				  1)
					# 输入新的虚拟内存大小
					echo "如果实际服务器就100G流量，可设置阈值为95G，提前关机，以免出现流量误差或溢出."
					read -e -p "请输入进站流量阈值（单位为GB）: " rx_threshold_gb
					read -e -p "请输入出站流量阈值（单位为GB）: " tx_threshold_gb
					read -e -p "请输入流量重置日期（默认每月1日重置）: " cz_day
					cz_day=${cz_day:-1}

					cd ~
					curl -Ss -o ~/Limiting_Shut_down.sh ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/Limiting_Shut_down1.sh
					chmod +x ~/Limiting_Shut_down.sh
					sed -i "s/110/$rx_threshold_gb/g" ~/Limiting_Shut_down.sh
					sed -i "s/120/$tx_threshold_gb/g" ~/Limiting_Shut_down.sh
					check_crontab_installed
					crontab -l | grep -v '~/Limiting_Shut_down.sh' | crontab -
					(crontab -l ; echo "* * * * * ~/Limiting_Shut_down.sh") | crontab - > /dev/null 2>&1
					crontab -l | grep -v 'reboot' | crontab -
					(crontab -l ; echo "0 1 $cz_day * * reboot") | crontab - > /dev/null 2>&1
					echo "限流关机已设置"
					send_stats "限流关机已设置"
					;;
				  2)
					check_crontab_installed
					crontab -l | grep -v '~/Limiting_Shut_down.sh' | crontab -
					crontab -l | grep -v 'reboot' | crontab -
					rm ~/Limiting_Shut_down.sh
					echo "已关闭限流关机功能"
					;;
				  *)
					break
					;;
				esac
			done
			  ;;


		  24)
			  root_use
			  send_stats "私钥登录"
			  echo "ROOT私钥登录模式"
			  echo "视频介绍: https://www.bilibili.com/video/BV1Q4421X78n?t=209.4"
			  echo "------------------------------------------------"
			  echo "将会生成密钥对，更安全的方式SSH登录"
			  read -e -p "确定继续吗？(Y/N): " choice

			  case "$choice" in
				[Yy])
				  clear
				  send_stats "私钥登录使用"
				  add_sshkey
				  ;;
				[Nn])
				  echo "已取消"
				  ;;
				*)
				  echo "无效的选择，请输入 Y 或 N。"
				  ;;
			  esac

			  ;;

		  25)
			  root_use
			  send_stats "电报预警"
			  echo "TG-bot监控预警功能"
			  echo "视频介绍: https://youtu.be/vLL-eb3Z_TY"
			  echo "------------------------------------------------"
			  echo "您需要配置tg机器人API和接收预警的用户ID，即可实现本机CPU，内存，硬盘，流量，SSH登录的实时监控预警"
			  echo "到达阈值后会向用户发预警消息"
			  echo -e "${hui}-关于流量，重启服务器将重新计算-${gl_bai}"
			  read -e -p "确定继续吗？(Y/N): " choice

			  case "$choice" in
				[Yy])
				  send_stats "电报预警启用"
				  cd ~
				  install nano tmux bc jq
				  check_crontab_installed
				  if [ -f ~/TG-check-notify.sh ]; then
					  chmod +x ~/TG-check-notify.sh
					  nano ~/TG-check-notify.sh
				  else
					  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/TG-check-notify.sh
					  chmod +x ~/TG-check-notify.sh
					  nano ~/TG-check-notify.sh
				  fi
				  tmux kill-session -t TG-check-notify > /dev/null 2>&1
				  tmux new -d -s TG-check-notify "~/TG-check-notify.sh"
				  crontab -l | grep -v '~/TG-check-notify.sh' | crontab - > /dev/null 2>&1
				  (crontab -l ; echo "@reboot tmux new -d -s TG-check-notify '~/TG-check-notify.sh'") | crontab - > /dev/null 2>&1

				  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/TG-SSH-check-notify.sh > /dev/null 2>&1
				  sed -i "3i$(grep '^TELEGRAM_BOT_TOKEN=' ~/TG-check-notify.sh)" TG-SSH-check-notify.sh > /dev/null 2>&1
				  sed -i "4i$(grep '^CHAT_ID=' ~/TG-check-notify.sh)" TG-SSH-check-notify.sh
				  chmod +x ~/TG-SSH-check-notify.sh

				  # 添加到 ~/.profile 文件中
				  if ! grep -q 'bash ~/TG-SSH-check-notify.sh' ~/.profile > /dev/null 2>&1; then
					  echo 'bash ~/TG-SSH-check-notify.sh' >> ~/.profile
					  if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
						 echo 'source ~/.profile' >> ~/.bashrc
					  fi
				  fi

				  source ~/.profile

				  clear
				  echo "TG-bot预警系统已启动"
				  echo -e "${hui}你还可以将root目录中的TG-check-notify.sh预警文件放到其他机器上直接使用！${gl_bai}"
				  ;;
				[Nn])
				  echo "已取消"
				  ;;
				*)
				  echo "无效的选择，请输入 Y 或 N。"
				  ;;
			  esac
			  ;;

		  26)
			  root_use
			  send_stats "修复SSH高危漏洞"
			  cd ~
			  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/upgrade_openssh9.8p1.sh
			  chmod +x ~/upgrade_openssh9.8p1.sh
			  ~/upgrade_openssh9.8p1.sh
			  rm -f ~/upgrade_openssh9.8p1.sh
			  ;;

		  27)
			  elrepo
			  ;;
		  28)
			  Kernel_optimize
			  ;;

		  29)
			  clamav
			  ;;

		  30)
			  linux_file
			  ;;

		  31)
			  linux_language
			  ;;

		  32)
			  shell_bianse
			  ;;
		  33)
			  linux_trash
			  ;;
		  41)
			clear
			send_stats "留言板"
			install sshpass
			while true; do
			  remote_ip="66.42.61.110"
			  remote_user="liaotian123"
			  remote_file="/home/liaotian123/liaotian.txt"
			  password="kejilionYYDS"  # 替换为您的密码

			  clear
			  echo "科技lion留言板"
			  echo "------------------------"
			  # 显示已有的留言内容
			  sshpass -p "${password}" ssh -o StrictHostKeyChecking=no "${remote_user}@${remote_ip}" "cat '${remote_file}'"
			  echo ""
			  echo "------------------------"

			  # 判断是否要留言
			  read -e -p "是否要留言？(y/n): " leave_message

			  if [ "$leave_message" == "y" ] || [ "$leave_message" == "Y" ]; then
				  # 输入新的留言内容
				  read -e -p "输入你的昵称: " nicheng
				  read -e -p "输入你的聊天内容: " neirong

				  # 添加新留言到远程文件
				  sshpass -p "${password}" ssh -o StrictHostKeyChecking=no "${remote_user}@${remote_ip}" "echo -e '${nicheng}: ${neirong}' >> '${remote_file}'"
				  echo "已添加留言: "
				  echo "${nicheng}: ${neirong}"
			  else
				  echo "退出留言板"
				  break
			  fi
			break_end
			done
			  ;;

		  66)

			  root_use
			  send_stats "一条龙调优"
			  echo "一条龙系统调优"
			  echo "------------------------------------------------"
			  echo "将对以下内容进行操作与优化"
			  echo "1. 更新系统到最新"
			  echo "2. 清理系统垃圾文件"
			  echo -e "3. 设置虚拟内存${gl_huang}1G${gl_bai}"
			  echo -e "4. 设置SSH端口号为${gl_huang}5522${gl_bai}"
			  echo -e "5. 开放所有端口"
			  echo -e "6. 开启${gl_huang}BBR${gl_bai}加速"
			  echo -e "7. 设置时区到${gl_huang}上海${gl_bai}"
			  echo -e "8. 自动优化DNS地址${gl_huang}海外: 1.1.1.1 8.8.8.8  国内: 223.5.5.5 ${gl_bai}"
			  echo -e "9. 安装常用工具${gl_huang}docker wget sudo tar unzip socat btop nano vim${gl_bai}"
			  echo -e "10. Linux系统内核参数优化切换到${gl_huang}均衡优化模式${gl_bai}"
			  echo "------------------------------------------------"
			  read -e -p "确定一键保养吗？(Y/N): " choice

			  case "$choice" in
				[Yy])
				  clear
				  send_stats "一条龙调优启动"
				  echo "------------------------------------------------"
				  linux_update
				  echo -e "[${gl_lv}OK${gl_bai}] 1/10. 更新系统到最新"

				  echo "------------------------------------------------"
				  linux_clean
				  echo -e "[${gl_lv}OK${gl_bai}] 2/10. 清理系统垃圾文件"

				  echo "------------------------------------------------"
				  new_swap=1024
				  add_swap
				  echo -e "[${gl_lv}OK${gl_bai}] 3/10. 设置虚拟内存${gl_huang}1G${gl_bai}"

				  echo "------------------------------------------------"
				  new_port=5522
				  new_ssh_port
				  echo -e "[${gl_lv}OK${gl_bai}] 4/10. 设置SSH端口号为${gl_huang}5522${gl_bai}"
				  echo "------------------------------------------------"
				  echo -e "[${gl_lv}OK${gl_bai}] 5/10. 开放所有端口"

				  echo "------------------------------------------------"
				  bbr_on
				  echo -e "[${gl_lv}OK${gl_bai}] 6/10. 开启${gl_huang}BBR${gl_bai}加速"

				  echo "------------------------------------------------"
				  set_timedate Asia/Shanghai
				  echo -e "[${gl_lv}OK${gl_bai}] 7/10. 设置时区到${gl_huang}上海${gl_bai}"

				  echo "------------------------------------------------"
				  country=$(curl -s ipinfo.io/country)
				  if [ "$country" = "CN" ]; then
					  dns1_ipv4="223.5.5.5"
					  dns2_ipv4="183.60.83.19"
					  dns1_ipv6="2400:3200::1"
					  dns2_ipv6="2400:da00::6666"
				  else
					  dns1_ipv4="1.1.1.1"
					  dns2_ipv4="8.8.8.8"
					  dns1_ipv6="2606:4700:4700::1111"
					  dns2_ipv6="2001:4860:4860::8888"
				  fi

				  set_dns
				  echo -e "[${gl_lv}OK${gl_bai}] 8/10. 自动优化DNS地址${gl_huang}${gl_bai}"

				  echo "------------------------------------------------"
				  install_docker
				  install wget sudo tar unzip socat btop nano vim
				  echo -e "[${gl_lv}OK${gl_bai}] 9/10. 安装常用工具${gl_huang}docker wget sudo tar unzip socat btop${gl_bai}"
				  echo "------------------------------------------------"

				  echo "------------------------------------------------"
				  optimize_balanced
				  echo -e "[${gl_lv}OK${gl_bai}] 10/10. Linux系统内核参数优化"
				  echo -e "${gl_lv}一条龙系统调优已完成${gl_bai}"

				  ;;
				[Nn])
				  echo "已取消"
				  ;;
				*)
				  echo "无效的选择，请输入 Y 或 N。"
				  ;;
			  esac

			  ;;

		  99)
			  clear
			  send_stats "重启系统"
			  server_reboot
			  ;;
		  100)

			root_use
			while true; do
			  clear
			  status_message="${gl_lv}采集已关闭（本地版本不采集）${gl_bai}"
			  echo "隐私与安全"
			  echo "脚本将收集用户使用功能的数据，优化脚本体验，制作更多好玩好用的功能"
			  echo "将收集脚本版本号，使用的时间，系统版本，CPU架构，机器所属国家和使用的功能的名称，"
			  echo "------------------------------------------------"
			  echo -e "当前状态: $status_message"
			  echo "--------------------"
			  echo "1. 开启采集"
			  echo "2. 关闭采集"
			  echo "--------------------"
			  echo "0. 返回上一级"
			  echo "--------------------"
			  read -e -p "请输入你的选择: " sub_choice
			  case $sub_choice in
				  1)
					  cd ~
					  sed -i 's/^ENABLE_STATS="false"/ENABLE_STATS="true"/' /usr/local/bin/k
					  sed -i 's/^ENABLE_STATS="false"/ENABLE_STATS="true"/' ./kejilion.sh
					  echo "已开启采集"
					  send_stats "隐私与安全已开启采集"
					  ;;
				  2)
					  cd ~
					  sed -i 's/^ENABLE_STATS="true"/ENABLE_STATS="false"/' /usr/local/bin/k
					  sed -i 's/^ENABLE_STATS="true"/ENABLE_STATS="false"/' ./kejilion.sh
					  echo "已关闭采集"
					  send_stats "隐私与安全已关闭采集"
					  ;;
				  0)
					  break
					  ;;
				  *)
					  echo "无效的选择，请重新输入。"
					  ;;
			  esac
			done
			  ;;

		  101)
			  clear
			  send_stats "卸载科技lion脚本"
			  echo "卸载科技lion脚本"
			  echo "------------------------------------------------"
			  echo "将彻底卸载kejilion脚本，不影响你其他功能"
			  read -e -p "确定继续吗？(Y/N): " choice

			  case "$choice" in
				[Yy])
				  clear
				  rm -f /usr/local/bin/k
				  rm ./kejilion.sh
				  echo "脚本已卸载，再见！"
				  break_end
				  clear
				  exit
				  ;;
				[Nn])
				  echo "已取消"
				  ;;
				*)
				  echo "无效的选择，请输入 Y 或 N。"
				  ;;
			  esac
			  ;;

		  0)
			  kejilion

			  ;;
		  *)
			  echo "无效的输入!"
			  ;;
	  esac
	  break_end

	done



}


linux_cluster() {

	clear
	send_stats "集群控制"
	while true; do
	  clear
	  echo -e "▶ 服务器集群控制"
	  echo -e "视频介绍: https://www.bilibili.com/video/BV1hH4y1j74M?t=0.1"
	  echo -e "你可以远程操控多台VPS一起执行任务（仅支持Ubuntu/Debian）"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}安装集群环境"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}2.   ${gl_bai}集群控制中心 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}7.   ${gl_bai}备份集群环境"
	  echo -e "${gl_kjlan}8.   ${gl_bai}还原集群环境"
	  echo -e "${gl_kjlan}9.   ${gl_bai}卸载集群环境"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "请输入你的选择: " sub_choice

	  case $sub_choice in
		  1)
			clear
			send_stats "安装集群环境"
			install python3 python3-paramiko speedtest-cli lrzsz
			mkdir cluster && cd cluster
			touch servers.py

			cat > ./servers.py << EOF
servers = [

]
EOF

			  ;;
		  2)

			  while true; do
				  clear
				  send_stats "集群控制中心"
				  echo "集群服务器列表"
				  cat ~/cluster/servers.py

				  echo ""
				  echo "操作"
				  echo "------------------------"
				  echo "1. 添加服务器                2. 删除服务器             3. 编辑服务器"
				  echo "------------------------"
				  echo "11. 安装科技lion脚本         12. 更新系统              13. 清理系统"
				  echo "14. 安装docker               15. 安装BBR3              16. 设置1G虚拟内存"
				  echo "17. 设置时区到上海           18. 开放所有端口"
				  echo "------------------------"
				  echo "51. 自定义指令"
				  echo "------------------------"
				  echo "0. 返回上一级选单"
				  echo "------------------------"
				  read -e -p "请输入你的选择: " sub_choice

				  case $sub_choice in
					  1)
						  send_stats "添加集群服务器"
						  read -e -p "服务器名称: " server_name
						  read -e -p "服务器IP: " server_ip
						  read -e -p "服务器端口（22）: " server_port
						  server_port=${server_port:-22}
						  read -e -p "服务器用户名（root）: " server_username
						  server_username=${server_username:-root}
						  read -e -p "服务器用户密码: " server_password

						  sed -i "/servers = \[/a\    {\"name\": \"$server_name\", \"hostname\": \"$server_ip\", \"port\": $server_port, \"username\": \"$server_username\", \"password\": \"$server_password\", \"remote_path\": \"/home/\"}," ~/cluster/servers.py

						  ;;
					  2)
						  send_stats "删除集群服务器"
						  read -e -p "请输入需要删除的关键字: " rmserver
						  sed -i "/$rmserver/d" ~/cluster/servers.py
						  ;;
					  3)
						  send_stats "编辑集群服务器"
						  install nano
						  nano ~/cluster/servers.py
						  ;;
					  11)
						  py_task=install_kejilion.py
						  cluster_python3
						  ;;
					  12)
						  py_task=update.py
						  cluster_python3
						  ;;
					  13)
						  py_task=clean.py
						  cluster_python3
						  ;;
					  14)
						  py_task=install_docker.py
						  cluster_python3
						  ;;
					  15)
						  py_task=install_bbr3.py
						  cluster_python3
						  ;;
					  16)
						  py_task=swap1024.py
						  cluster_python3
						  ;;
					  17)
						  py_task=time_shanghai.py
						  cluster_python3
						  ;;
					  18)
						  py_task=firewall_close.py
						  cluster_python3
						  ;;
					  51)
						  send_stats "自定义执行命令"
						  read -e -p "请输入批量执行的命令: " mingling
						  py_task=custom_tasks.py
						  cd ~/cluster/
						  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/python-for-vps/main/cluster/$py_task
						  sed -i "s#Customtasks#$mingling#g" ~/cluster/$py_task
						  python3 ~/cluster/$py_task
						  ;;
					  0)
						  break  # 跳出循环，退出菜单
						  ;;
					  0)
						  break  # 跳出循环，退出菜单
						  ;;

					  *)
						  break  # 跳出循环，退出菜单
						  ;;
				  esac
			  done

			  ;;
		  7)
			clear
			send_stats "备份集群"
			echo "将下载服务器列表数据，按任意键下载！"
			read -n 1 -s -r -p ""
			sz -y ~/cluster/servers.py

			  ;;

		  8)
			clear
			send_stats "还原集群"
			echo "请上传您的servers.py，按任意键开始上传！"
			read -n 1 -s -r -p ""
			cd ~/cluster/
			rz -y
			  ;;

		  9)

			clear
			send_stats "卸载集群"
			read -e -p "请先备份环境，确定要卸载集群控制环境吗？(Y/N): " choice
			case "$choice" in
			  [Yy])
				remove python3-paramiko speedtest-cli lrzsz
				rm -rf ~/cluster/
				;;
			  [Nn])
				echo "已取消"
				;;
			  *)
				echo "无效的选择，请输入 Y 或 N。"
				;;
			esac

			  ;;

		  0)
			  kejilion
			  ;;
		  *)
			  echo "无效的输入!"
			  ;;
	  esac
	  break_end

	done



}




linux_file() {
	root_use
	send_stats "文件管理器"
	while true; do
		clear
		echo "文件管理器"
		echo "------------------------"
		echo "当前路径"
		pwd
		echo "------------------------"
		ls --color=auto -x
		echo "------------------------"
		echo "1.  进入目录           2.  创建目录             3.  修改目录权限         4.  重命名目录"
		echo "5.  删除目录           6.  返回上一级目录"
		echo "------------------------"
		echo "11. 创建文件           12. 编辑文件             13. 修改文件权限         14. 重命名文件"
		echo "15. 删除文件"
		echo "------------------------"
		echo "21. 压缩文件目录       22. 解压文件目录         23. 移动文件目录         24. 复制文件目录"
		echo "25. 传文件至其他服务器"
		echo "------------------------"
		echo "0.  返回上一级"
		echo "------------------------"
		read -e -p "请输入你的选择: " Limiting

		case "$Limiting" in
			1)  # 进入目录
				read -e -p "请输入目录名: " dirname
				cd "$dirname" 2>/dev/null || echo "无法进入目录"
				send_stats "进入目录"
				;;
			2)  # 创建目录
				read -e -p "请输入要创建的目录名: " dirname
				mkdir -p "$dirname" && echo "目录已创建" || echo "创建失败"
				send_stats "创建目录"
				;;
			3)  # 修改目录权限
				read -e -p "请输入目录名: " dirname
				read -e -p "请输入权限 (如 755): " perm
				chmod "$perm" "$dirname" && echo "权限已修改" || echo "修改失败"
				send_stats "修改目录权限"
				;;
			4)  # 重命名目录
				read -e -p "请输入当前目录名: " current_name
				read -e -p "请输入新目录名: " new_name
				mv "$current_name" "$new_name" && echo "目录已重命名" || echo "重命名失败"
				send_stats "重命名目录"
				;;
			5)  # 删除目录
				read -e -p "请输入要删除的目录名: " dirname
				rm -rf "$dirname" && echo "目录已删除" || echo "删除失败"
				send_stats "删除目录"
				;;
			6)  # 返回上一级目录
				cd ..
				send_stats "返回上一级目录"
				;;
			11) # 创建文件
				read -e -p "请输入要创建的文件名: " filename
				touch "$filename" && echo "文件已创建" || echo "创建失败"
				send_stats "创建文件"
				;;
			12) # 编辑文件
				read -e -p "请输入要编辑的文件名: " filename
				install nano
				nano "$filename"
				send_stats "编辑文件"
				;;
			13) # 修改文件权限
				read -e -p "请输入文件名: " filename
				read -e -p "请输入权限 (如 755): " perm
				chmod "$perm" "$filename" && echo "权限已修改" || echo "修改失败"
				send_stats "修改文件权限"
				;;
			14) # 重命名文件
				read -e -p "请输入当前文件名: " current_name
				read -e -p "请输入新文件名: " new_name
				mv "$current_name" "$new_name" && echo "文件已重命名" || echo "重命名失败"
				send_stats "重命名文件"
				;;
			15) # 删除文件
				read -e -p "请输入要删除的文件名: " filename
				rm -f "$filename" && echo "文件已删除" || echo "删除失败"
				send_stats "删除文件"
				;;
			21) # 压缩文件/目录
				read -e -p "请输入要压缩的文件/目录名: " name
				install tar
				tar -czvf "$name.tar.gz" "$name" && echo "已压缩为 $name.tar.gz" || echo "压缩失败"
				send_stats "压缩文件/目录"
				;;
			22) # 解压文件/目录
				read -e -p "请输入要解压的文件名 (.tar.gz): " filename
				install tar
				tar -xzvf "$filename" && echo "已解压 $filename" || echo "解压失败"
				send_stats "解压文件/目录"
				;;

			23) # 移动文件或目录
				read -e -p "请输入要移动的文件或目录路径: " src_path
				if [ ! -e "$src_path" ]; then
					echo "错误: 文件或目录不存在。"
					send_stats "移动文件或目录失败: 文件或目录不存在"
					continue
				fi

				read -e -p "请输入目标路径 (包括新文件名或目录名): " dest_path
				if [ -z "$dest_path" ]; then
					echo "错误: 请输入目标路径。"
					send_stats "移动文件或目录失败: 目标路径未指定"
					continue
				fi

				mv "$src_path" "$dest_path" && echo "文件或目录已移动到 $dest_path" || echo "移动文件或目录失败"
				send_stats "移动文件或目录"
				;;


		   24) # 复制文件目录
				read -e -p "请输入要复制的文件或目录路径: " src_path
				if [ ! -e "$src_path" ]; then
					echo "错误: 文件或目录不存在。"
					send_stats "复制文件或目录失败: 文件或目录不存在"
					continue
				fi

				read -e -p "请输入目标路径 (包括新文件名或目录名): " dest_path
				if [ -z "$dest_path" ]; then
					echo "错误: 请输入目标路径。"
					send_stats "复制文件或目录失败: 目标路径未指定"
					continue
				fi

				# 使用 -r 选项以递归方式复制目录
				cp -r "$src_path" "$dest_path" && echo "文件或目录已复制到 $dest_path" || echo "复制文件或目录失败"
				send_stats "复制文件或目录"
				;;


			 25) # 传送文件至远端服务器
				read -e -p "请输入要传送的文件路径: " file_to_transfer
				if [ ! -f "$file_to_transfer" ]; then
					echo "错误: 文件不存在。"
					send_stats "传送文件失败: 文件不存在"
					continue
				fi

				read -e -p "请输入远端服务器IP: " remote_ip
				if [ -z "$remote_ip" ]; then
					echo "错误: 请输入远端服务器IP。"
					send_stats "传送文件失败: 未输入远端服务器IP"
					continue
				fi

				read -e -p "请输入远端服务器用户名 (默认root): " remote_user
				remote_user=${remote_user:-root}

				read -e -p "请输入远端服务器密码: " -s remote_password
				echo
				if [ -z "$remote_password" ]; then
					echo "错误: 请输入远端服务器密码。"
					send_stats "传送文件失败: 未输入远端服务器密码"
					continue
				fi

				read -e -p "请输入登录端口 (默认22): " remote_port
				remote_port=${remote_port:-22}

				# 清除已知主机的旧条目
				ssh-keygen -f "/root/.ssh/known_hosts" -R "$remote_ip"
				sleep 2  # 等待时间

				# 使用scp传输文件
				scp -P "$remote_port" -o StrictHostKeyChecking=no "$file_to_transfer" "$remote_user@$remote_ip:/home/" <<EOF
$remote_password
EOF

				if [ $? -eq 0 ]; then
					echo "文件已传送至远程服务器home目录。"
					send_stats "文件传送成功"
				else
					echo "文件传送失败。"
					send_stats "文件传送失败"
				fi

				break_end
				;;



			0)  # 返回上一级
				send_stats "返回上一级菜单"
				break
				;;
			*)  # 处理无效输入
				echo "无效的选择，请重新输入"
				send_stats "无效选择"
				;;
		esac
	done
}


kejilion_update() {

	send_stats "脚本更新"
	cd ~
	clear
	echo "更新日志"
	echo "------------------------"
	echo "全部日志: ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/kejilion_sh_log.txt"
	echo "------------------------"

	curl -s ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/kejilion_sh_log.txt | tail -n 35
	sh_v_new=$(curl -s ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/kejilion.sh | grep -o 'sh_v="[0-9.]*"' | cut -d '"' -f 2)

	if [ "$sh_v" = "$sh_v_new" ]; then
		echo -e "${gl_lv}你已经是最新版本！${gl_huang}v$sh_v${gl_bai}"
		send_stats "脚本已经最新了，无需更新"
	else
		echo "发现新版本！"
		echo -e "当前版本 v$sh_v        最新版本 ${gl_huang}v$sh_v_new${gl_bai}"
		echo "------------------------"
		read -e -p "确定更新脚本吗？(Y/N): " choice
		case "$choice" in
			[Yy])
				clear
				country=$(curl -s ipinfo.io/country)
				if [ "$country" = "CN" ]; then
					curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/cn/kejilion.sh && chmod +x kejilion.sh
				else
					curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/kejilion.sh && chmod +x kejilion.sh
				fi
				if declare -F yinsiyuanquan2 >/dev/null 2>&1; then
					yinsiyuanquan2
				fi
				cp -f ./kejilion.sh /usr/local/bin/k > /dev/null 2>&1
				echo -e "${gl_lv}脚本已更新到最新版本！${gl_huang}v$sh_v_new${gl_bai}"
				send_stats "脚本已经最新$sh_v_new"
				break_end
				./kejilion.sh
				exit
				;;
			[Nn])
				echo "已取消"
				;;
			*)
				;;
		esac
	fi
}


kejilion_Affiliates() {

clear
send_stats "广告专栏"
echo "广告专栏"
echo "------------------------"
echo "将为用户提供更简单优雅的推广与购买体验！"
echo ""
echo -e "服务器优惠"
echo "------------------------"
echo -e "${gl_lan}RackNerd 10.18刀每年 美国 1核心 768M内存 15G硬盘 1T流量每月${gl_bai}"
echo -e "${gl_bai}网址: https://my.racknerd.com/aff.php?aff=5501&pid=792${gl_bai}"
echo "------------------------"
echo -e "${gl_lv}Cloudcone 10刀每年 美国 1核心 768M内存 5G硬盘 3T流量每月${gl_bai}"
echo -e "${gl_bai}网址: https://app.cloudcone.com.cn/vps/261/create?ref=8355&token=cloudcone.cc-24-vps-2${gl_bai}"
echo "------------------------"
echo -e "${gl_huang}搬瓦工 49刀每季 美国CN2GIA 日本软银 2核心 1G内存 20G硬盘 1T流量每月${gl_bai}"
echo -e "${gl_bai}网址: https://bandwagonhost.com/aff.php?aff=69004&pid=87${gl_bai}"
echo "------------------------"
echo -e "${gl_lan}DMIT 28刀每季 美国CN2GIA 1核心 2G内存 20G硬盘 800G流量每月${gl_bai}"
echo -e "${gl_bai}网址: https://www.dmit.io/aff.php?aff=4966&pid=100${gl_bai}"
echo "------------------------"
echo -e "${gl_zi}V.PS 6.9刀每月 东京软银 2核心 1G内存 20G硬盘 1T流量每月${gl_bai}"
echo -e "${gl_bai}网址: https://vps.hosting/cart/tokyo-cloud-kvm-vps/?id=148&?affid=1355&?affid=1355${gl_bai}"
echo "------------------------"
echo -e "${gl_kjlan}VPS更多热门优惠${gl_bai}"
echo -e "${gl_bai}网址: https://kejilion.pro/topvps/${gl_bai}"
echo "------------------------"
echo ""
echo -e "域名优惠"
echo "------------------------"
echo -e "${gl_lan}GNAME 8.8刀首年COM域名 6.68刀首年CC域名${gl_bai}"
echo -e "${gl_bai}网址: https://www.gname.com/register?tt=86836&ttcode=KEJILION86836&ttbj=sh${gl_bai}"
echo "------------------------"
echo ""
echo -e "科技lion周边"
echo "------------------------"
echo -e "${gl_kjlan}B站:   ${gl_bai}https://b23.tv/2mqnQyh              ${gl_kjlan}油管:     ${gl_bai}https://www.youtube.com/@kejilion${gl_bai}"
echo -e "${gl_kjlan}官网:  ${gl_bai}https://kejilion.pro/               ${gl_kjlan}导航:     ${gl_bai}https://dh.kejilion.pro/${gl_bai}"
echo -e "${gl_kjlan}博客:  ${gl_bai}https://blog.kejilion.pro/          ${gl_kjlan}软件中心: ${gl_bai}https://app.kejilion.pro/${gl_bai}"
echo "------------------------"
echo ""
}


kejilion_sh() {
while true; do
clear
echo -e "${gl_kjlan}_  _ ____  _ _ _    _ ____ _  _ "
echo "|_/  |___  | | |    | |  | |\ | "
echo "| \_ |___ _| | |___ | |__| | \| "
echo "                                "
echo -e "脚本工具箱 v$sh_v 只为更简单的Linux的使用！"
echo -e "适配Ubuntu/Debian/CentOS/Alpine/Kali/Arch/RedHat/Fedora/Alma/Rocky系统"
echo -e "-输入${gl_huang}k${gl_kjlan}可快速启动此脚本-${gl_bai}"
show_kejilion_update_status
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}1.   ${gl_bai}系统信息查询"
echo -e "${gl_kjlan}2.   ${gl_bai}系统更新"
echo -e "${gl_kjlan}3.   ${gl_bai}系统清理"
echo -e "${gl_kjlan}4.   ${gl_bai}常用工具 ▶"
echo -e "${gl_kjlan}5.   ${gl_bai}BBR管理 ▶"
echo -e "${gl_kjlan}6.   ${gl_bai}Docker管理 ▶ "
echo -e "${gl_kjlan}7.   ${gl_bai}WARP管理 ▶ "
echo -e "${gl_kjlan}8.   ${gl_bai}测试脚本合集 ▶ "
echo -e "${gl_kjlan}9.   ${gl_bai}甲骨文云脚本合集 ▶ "
echo -e "${gl_huang}10.  ${gl_bai}LDNMP建站 ▶ "
echo -e "${gl_kjlan}11.  ${gl_bai}面板工具 ▶ "
echo -e "${gl_kjlan}12.  ${gl_bai}我的工作区 ▶ "
echo -e "${gl_kjlan}13.  ${gl_bai}系统工具 ▶ "
echo -e "${gl_kjlan}14.  ${gl_bai}服务器集群控制 ▶ "
echo -e "${gl_kjlan}15.  ${gl_bai}广告专栏"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}p.   ${gl_bai}幻兽帕鲁开服脚本 ▶"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}00.  ${gl_bai}脚本更新"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}0.   ${gl_bai}退出脚本"
echo -e "${gl_kjlan}------------------------${gl_bai}"
read -e -p "请输入你的选择: " choice

case $choice in
  1) linux_ps ;;
  2) clear ; send_stats "系统更新" ; linux_update ;;
  3) clear ; send_stats "系统清理" ; linux_clean ;;
  4) linux_tools ;;
  5) linux_bbr ;;
  6) linux_docker ;;
  7) clear ; send_stats "warp管理" ; install wget
	wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh ; bash menu.sh [option] [lisence/url/token]
	;;
  8) linux_test ;;
  9) linux_Oracle ;;
  10) linux_ldnmp ;;
  11) linux_panel ;;
  12) linux_work ;;
  13) linux_Settings ;;
  14) linux_cluster ;;
  15) kejilion_Affiliates ;;
  p) send_stats "幻兽帕鲁开服脚本" ; cd ~
	 curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/sh/main/palworld.sh ; chmod +x palworld.sh ; ./palworld.sh
	 exit
	 ;;
  00) kejilion_update ;;
  0) clear ; exit ;;
  *) echo "无效的输入!" ;;
esac
	break_end
done
}


k_info() {
send_stats "k命令参考用例"
echo "无效参数"
echo "-------------------"
echo "视频介绍: https://www.bilibili.com/video/BV1ib421E7it?t=0.1"
echo "以下是k命令参考用例："
echo "启动脚本            k"
echo "安装软件包          k install nano wget | k add nano wget | k 安装 nano wget"
echo "卸载软件包          k remove nano wget | k del nano wget | k uninstall nano wget | k 卸载 nano wget"
echo "更新系统            k update | k 更新"
echo "清理系统垃圾        k clean | k 清理"
echo "打开重装系统面板    k dd | k 重装"
echo "打开bbr3控制面板    k bbr3 | k bbrv3"
echo "打开内核调优面膜    k nhyh | k 内核优化"
echo "打开系统回收站      k trash | k hsz | k 回收站"
echo "软件启动            k start sshd | k 启动 sshd "
echo "软件停止            k stop sshd | k 停止 sshd "
echo "软件重启            k restart sshd | k 重启 sshd "
echo "软件状态查看        k status sshd | k 状态 sshd "
echo "软件开机启动        k enable docker | k autostart docke | k 开机启动 docker "
echo "域名证书申请        k ssl"
echo "域名证书到期查询    k ssl ps"
echo "docker环境安装      k docker install |k docker 安装"
echo "docker容器管理      k docker ps |k docker 容器"
echo "docker镜像管理      k docker img |k docker 镜像"
echo "LDNMP缓存清理       k web cache"

}







if [ "$#" -eq 0 ]; then
	# 如果没有参数，运行交互式逻辑
	kejilion_sh
else
	# 如果有参数，执行相应函数
	case $1 in
		install|add|安装)
			shift
			send_stats "安装软件"
			install "$@"
			;;
		remove|del|uninstall|卸载)
			shift
			send_stats "卸载软件"
			remove "$@"
			;;
		update|更新)
			linux_update
			;;
		clean|清理)
			linux_clean
			;;
		dd|重装)
			dd_xitong
			;;
		bbr3|bbrv3)
			bbrv3
			;;
		nhyh|内核优化)
			Kernel_optimize
			;;
		trash|hsz|回收站)
			linux_trash
			;;
		status|状态)
			shift
			send_stats "软件状态查看"
			status "$@"
			;;
		start|启动)
			shift
			send_stats "软件启动"
			start "$@"
			;;
		stop|停止)
			shift
			send_stats "软件暂停"
			stop "$@"
			;;
		restart|重启)
			shift
			send_stats "软件重启"
			restart "$@"
			;;

		enable|autostart|开机启动)
			shift
			send_stats "软件开机自启"
			enable "$@"
			;;

		ssl)
		   shift
			if [ "$1" = "ps" ]; then
				send_stats "查看证书状态"
				ssl_ps
			elif [ -z "$1" ]; then
				add_ssl
				send_stats "快速申请证书"
			else
				k_info
			fi
			;;

		docker)
			shift
			case $1 in
				install|安装)
					send_stats "快捷安装docker"
					install_docker
					;;
				ps|容器)
					send_stats "快捷容器管理"
					docker_ps
					;;
				img|镜像)
					send_stats "快捷镜像管理"
					docker_image
					;;
				*)
					k_info
					;;
			esac
			;;

		web)
			shift
			case $1 in
				cache) web_cache ;;
				*) k_info ;;
			esac
			;;
		*)
			k_info
			;;
	esac
fi
