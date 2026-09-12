#!/bin/bash
sh_v="0.0.3"

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
permission_granted="true"
ENABLE_STATS="false"

send_stats() {
    return 0
}

CheckFirstRun_true() {
    return 0
}

CheckFirstRun_false() {
    return 0
}

install_add_docker_cn() {
    country=$(curl -s --max-time 3 ipinfo.io/country 2>/dev/null)
    if [ "$country" = "CN" ]; then
        mkdir -p /etc/docker
        cat > /etc/docker/daemon.json << EOF
{
    "registry-mirrors": ["https://docker.kejilion.pro"]
}
EOF
    fi
}

k() {
    "$0" "$@"
}


# 提示用户同意条款
UserLicenseAgreement() {
	clear
	echo -e "${gl_kjlan}欢迎使用科技lion脚本工具箱${gl_bai}"
	echo "首次使用脚本，请先阅读并同意用户许可协议。"
	echo "用户许可协议: https://www.bing.com/"
	echo -e "----------------------"
	read -r -p "是否同意以上条款？(y/n): " user_input


	if [ "$user_input" = "y" ] || [ "$user_input" = "Y" ]; then
		send_stats "许可同意"
		sed -i 's/^permission_granted="false"/permission_granted="true"/' ./kejilion.sh
		sed -i 's/^permission_granted="false"/permission_granted="true"/' /usr/local/bin/k
	else
		send_stats "许可拒绝"
		clear
		exit
	fi
}









CheckFirstRun_false





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
country=$(curl -s ipinfo.io/country)
if [ "$country" = "CN" ]; then
	cd ~
	curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/docker/main/install && chmod +x install
	sh install --mirror Aliyun
	rm -f install

else
	curl -fsSL https://get.docker.com | sh
fi
install_add_docker_cn
k enable docker
k start docker

}



install_add_docker() {
	echo -e "${gl_huang}正在安装docker环境...${gl_bai}"
	if  [ -f /etc/os-release ] && grep -q "Fedora" /etc/os-release; then
		install_add_docker_guanfang
	elif command -v dnf &>/dev/null; then
		dnf update -y
		dnf install -y yum-utils device-mapper-persistent-data lvm2
		rm -f /etc/yum.repos.d/docker*.repo > /dev/null
		country=$(curl -s ipinfo.io/country)
		arch=$(uname -m)
		if [ "$country" = "CN" ]; then
			if [ "$arch" = "x86_64" ]; then
				curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo | tee /etc/yum.repos.d/docker-ce.repo > /dev/null
			elif [ "$arch" = "aarch64" ]; then
				curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/centos/arm64/docker-ce.repo | tee /etc/yum.repos.d/docker-ce.repo > /dev/null
			fi
		else
			if [ "$arch" = "x86_64" ]; then
				yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
			elif [ "$arch" = "aarch64" ]; then
				yum-config-manager --add-repo https://download.docker.com/linux/centos/arm64/docker-ce.repo > /dev/null
			fi
		fi
		dnf install -y docker-ce docker-ce-cli containerd.io
		install_add_docker_cn
		k enable docker
		k start docker

	elif [ -f /etc/os-release ] && grep -q "Kali" /etc/os-release; then
		apt update
		apt upgrade -y
		apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
		rm -f /usr/share/keyrings/docker-archive-keyring.gpg
		country=$(curl -s ipinfo.io/country)
		arch=$(uname -m)
		if [ "$country" = "CN" ]; then
			if [ "$arch" = "x86_64" ]; then
				sed -i '/^deb \[arch=amd64 signed-by=\/etc\/apt\/keyrings\/docker-archive-keyring.gpg\] https:\/\/mirrors.aliyun.com\/docker-ce\/linux\/debian bullseye stable/d' /etc/apt/sources.list.d/docker.list > /dev/null
				mkdir -p /etc/apt/keyrings
				curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg > /dev/null
				echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
			elif [ "$arch" = "aarch64" ]; then
				sed -i '/^deb \[arch=arm64 signed-by=\/etc\/apt\/keyrings\/docker-archive-keyring.gpg\] https:\/\/mirrors.aliyun.com\/docker-ce\/linux\/debian bullseye stable/d' /etc/apt/sources.list.d/docker.list > /dev/null
				mkdir -p /etc/apt/keyrings
				curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg > /dev/null
				echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
			fi
		else
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
		fi
		apt update
		apt install -y docker-ce docker-ce-cli containerd.io
		install_add_docker_cn
		k enable docker
		k start docker

	elif command -v apt &>/dev/null || command -v yum &>/dev/null; then
		install_add_docker_guanfang
	else
		k install docker docker-compose
		install_add_docker_cn
		k enable docker
		k start docker
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
	  echo ""

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
	shiqu="$1"
	if grep -q 'Alpine' /etc/issue; then
		install tzdata
		cp /usr/share/zoneinfo/${shiqu} /etc/localtime
		hwclock --systohc
	else
		timedatectl set-timezone ${shiqu}
	fi
}


wait_for_lock() {
	while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
		echo "等待dpkg锁释放..."
		sleep 1
	done
}

# 修复dpkg中断问题
fix_dpkg() {
	DEBIAN_FRONTEND=noninteractive dpkg --configure -a
}



linux_update() {
	echo -e "${gl_huang}正在系统更新...${gl_bai}"
	if command -v dnf &>/dev/null; then
		dnf -y update
	elif command -v yum &>/dev/null; then
		yum -y update
	elif command -v apt &>/dev/null; then
		wait_for_lock
		fix_dpkg
		DEBIAN_FRONTEND=noninteractive apt update -y
		DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
	elif command -v apk &>/dev/null; then
		apk update && apk upgrade
	elif command -v pacman &>/dev/null; then
		pacman -Syu --noconfirm
	elif command -v zypper &>/dev/null; then
		zypper refresh
		zypper update
	elif command -v opkg &>/dev/null; then
		opkg update
	else
		echo "未知的包管理器!"
		return
	fi
}



linux_clean() {
	echo -e "${gl_huang}正在系统清理...${gl_bai}"
	if command -v dnf &>/dev/null; then
		dnf autoremove -y
		dnf clean all
		dnf makecache
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v yum &>/dev/null; then
		yum autoremove -y
		yum clean all
		yum makecache
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v apt &>/dev/null; then
		wait_for_lock
		fix_dpkg
		apt autoremove --purge -y
		apt clean -y
		apt autoclean -y
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v apk &>/dev/null; then
		echo "清理包管理器缓存..."
		apk cache clean
		echo "删除系统日志..."
		rm -rf /var/log/*
		echo "删除APK缓存..."
		rm -rf /var/cache/apk/*
		echo "删除临时文件..."
		rm -rf /tmp/*

	elif command -v pacman &>/dev/null; then
		pacman -Rns $(pacman -Qdtq) --noconfirm
		pacman -Scc --noconfirm
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v zypper &>/dev/null; then
		zypper clean --all
		zypper refresh
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v opkg &>/dev/null; then
		echo "删除系统日志..."
		rm -rf /var/log/*
		echo "删除临时文件..."
		rm -rf /tmp/*

	else
		echo "未知的包管理器!"
		return
	fi
	return
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

					  container_name=$(echo "$container_info" | awk '{print $1}')
					  network_info=$(echo "$container_info" | cut -d' ' -f2-)

					  while IFS= read -r line; do
						  network_name=$(echo "$line" | awk '{print $1}')
						  ip_address=$(echo "$line" | awk '{print $2}')

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
	  install_ldnmp

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
	  echo "可用的站点备份"
	  echo "-------------------------"
	  ls -lt /home/*.gz | awk '{print $NF}'
	  echo ""
	  read -e -p  "回车键还原最新的备份，输入备份文件名还原指定的备份，输入0退出：" filename

	  if [ "$filename" == "0" ]; then
		  break_end
		  linux_ldnmp
	  fi

	  # 如果用户没有输入文件名，使用最新的压缩包
	  if [ -z "$filename" ]; then
		  filename=$(ls -t /home/*.tar.gz | head -1)
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
		  install_ldnmp
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
			  read -e -p "请输入${ldnmp_pods}版本号 （如: 8.0 8.3 8.4 9.0 9.5）（回车获取最新版）: " version
			  version=${version:-latest}

			  cd /home/web/
			  cp /home/web/docker-compose.yml /home/web/docker-compose1.yml
			  sed -i "s/image: mysql/image: mysql:${version}/" /home/web/docker-compose.yml
			  docker rm -f $ldnmp_pods
			  docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
			  docker compose up -d --force-recreate $ldnmp_pods
			  docker restart $ldnmp_pods
			  cp /home/web/docker-compose1.yml /home/web/docker-compose.yml
			  send_stats "更新$ldnmp_pods"
			  echo "更新${ldnmp_pods}完成"

				  ;;
			  3)
			  ldnmp_pods="php"
			  read -e -p "请输入${ldnmp_pods}版本号 （如: 7.4 8.0 8.1 8.2 8.3 8.4 8.5）（回车获取最新版）: " version
			  version=${version:-8.3}
			  cd /home/web/
			  cp /home/web/docker-compose.yml /home/web/docker-compose1.yml
			  sed -i "s/image: php:fpm-alpine/image: php:${version}-fpm-alpine/" /home/web/docker-compose.yml
			  docker rm -f $ldnmp_pods
			  docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
			  docker compose up -d --force-recreate $ldnmp_pods
			  docker exec $ldnmp_pods chmod -R 777 /var/www/html

			  run_command docker exec php sed -i "s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g" /etc/apk/repositories > /dev/null 2>&1

			  docker exec php apk update
			  curl -sL ${gh_proxy}https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o /usr/local/bin/install-php-extensions
			  docker exec php mkdir -p /usr/local/bin/
			  docker cp /usr/local/bin/install-php-extensions php:/usr/local/bin/
			  docker exec php chmod +x /usr/local/bin/install-php-extensions

			  docker exec php sh -c "\
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
							&& rm -rf /tmp/imagick"


			  docker exec php install-php-extensions mysqli pdo_mysql gd intl zip exif bcmath opcache redis


			  docker exec php sh -c 'echo "upload_max_filesize=50M " > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1
			  docker exec php sh -c 'echo "post_max_size=50M " > /usr/local/etc/php/conf.d/post.ini' > /dev/null 2>&1
			  docker exec php sh -c 'echo "memory_limit=256M" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1
			  docker exec php sh -c 'echo "max_execution_time=1200" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1
			  docker exec php sh -c 'echo "max_input_time=600" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1
			  docker exec php sh -c 'echo "max_input_vars=3000" > /usr/local/etc/php/conf.d/max_input_vars.ini' > /dev/null 2>&1


			  docker restart $ldnmp_pods > /dev/null 2>&1
			  cp /home/web/docker-compose1.yml /home/web/docker-compose.yml
			  send_stats "更新$ldnmp_pods"
			  echo "更新${ldnmp_pods}完成"

				  ;;
			  4)
			  ldnmp_pods="redis"
			  cd /home/web/
			  docker rm -f $ldnmp_pods
			  docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
			  docker compose up -d --force-recreate $ldnmp_pods
			  docker exec -it redis redis-cli CONFIG SET maxmemory 512mb
			  docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru
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
					install_ldnmp
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



# ===== Hermes: 已安装应用端口管理（990） =====
kj_app_label() {
	local key="$1"
	case "$key" in
		bt|baota) echo "1|宝塔面板官方版" ;;
		aapanel) echo "2|aaPanel宝塔国际版" ;;
		1panel|1pctl) echo "3|1Panel新一代管理面板" ;;
		npm) echo "4|NginxProxyManager可视化面板" ;;
		nezha|nezha-dashboard) echo "7|哪吒探针VPS监控面板" ;;
		webtop-ubuntu) echo "6|Ubuntu远程桌面网页版3006端口" ;;
		qbittorrent) echo "8|QB离线BT磁力下载面板" ;;
		mailserver|poste) echo "9|Poste.io邮件服务器程序" ;;
		rocketchat) echo "10|RocketChat多人在线聊天系统" ;;
		zentao-server|zentao) echo "11|禅道项目管理软件" ;;
		qinglong) echo "12|青龙面板定时任务管理平台" ;;
		cloudreve) echo "13|Cloudreve网盘" ;;
		easyimage) echo "14|简单图床图片管理程序" ;;
		emby) echo "15|emby多媒体管理系统" ;;
		looking-glass) echo "16|Speedtest测速面板" ;;
		adguardhome) echo "17|AdGuardHome去广告软件" ;;
		onlyoffice) echo "18|onlyoffice在线办公OFFICE" ;;
		safeline-mgt|safeline) echo "19|雷池WAF防火墙面板" ;;
		portainer) echo "20|portainer容器管理面板" ;;
		vscode-web) echo "21|VScode网页版" ;;
		uptime-kuma) echo "22|UptimeKuma监控工具" ;;
		memos) echo "23|Memos网页备忘录" ;;
		webtop) echo "24|Webtop远程桌面" ;;
		nextcloud-aio|nextcloud) echo "25|Nextcloud网盘" ;;
		qd) echo "26|QD-Today定时任务管理框架" ;;
		dockge) echo "27|Dockge容器堆栈管理面板" ;;
		speedtest) echo "28|LibreSpeed测速工具" ;;
		searxng) echo "29|searxng聚合搜索站" ;;
		photoprism) echo "30|PhotoPrism私有相册系统" ;;
		s-pdf|stirling-pdf) echo "31|StirlingPDF工具大全" ;;
		drawio) echo "32|drawio免费的在线图表软件" ;;
		sun-panel) echo "33|Sun-Panel导航面板" ;;
		pingvin-share) echo "34|Pingvin-Share文件分享平台" ;;
		moments) echo "35|极简朋友圈" ;;
		lobe-chat) echo "36|LobeChatAI聊天聚合网站" ;;
		myip) echo "37|MyIP工具箱" ;;
		alist) echo "38|小雅alist全家桶" ;;
		bililive-go) echo "39|Bililive直播录制工具" ;;
		windows) echo "40|远程Windows11" ;;
		vaultwarden) echo "42|vaultwarden" ;;
		aria2-pro) echo "46|Aria2离线下载" ;;
		nexterm) echo "53|NextermSSH链接" ;;
		webssh) echo "54|webssh" ;;
		openlist) echo "55|openlist4.0.8" ;;
		umami) echo "56|umami网站流量统计系统" ;;
		dify) echo "57|dify安装" ;;
		caddy) echo "100|caddy官方docker安装" ;;
		hbbs) echo "59|docker安装rustdesk服务端" ;;
		hbbr) echo "60|docker安装rustdesk中继端" ;;
		x-ui|xui) echo "62|安装x-ui" ;;
		rclone) echo "63|安装rclone" ;;
		r2beifen) echo "64|安装r2beifen备份" ;;
		owncloud) echo "67|ownCloud网盘安装" ;;
		m38u8) echo "68|安装M38u8" ;;
		it-tools) echo "69|it-tools工具箱" ;;
		pansou) echo "70|安装盘搜" ;;
		zfile) echo "71|安装zfile网盘" ;;
		discourse) echo "72|安装Discourse论坛" ;;
		minio) echo "73|安装minio对象存储" ;;
		mailcow) echo "78|Caddy安装mailcow邮箱" ;;
		hitokoto) echo "84|Hitokoto API" ;;
		backrest) echo "86|Backrest 资源备份" ;;
		certimate) echo "87|Certimate 证书管理" ;;
		btc) echo "90|BTC安装" ;;
		chrome) echo "91|自动进行谷歌浏览" ;;
		cli-proxy-api) echo "92|CLIProxyAPI" ;;
		sub2api) echo "93|Sub2API" ;;
		openclaw) echo "94|Openclaw" ;;
		open-webui) echo "95|Open WebUI" ;;
		chromium) echo "98|安装Google" ;;
		hermes) echo "99|Hermes机器人爱马仕" ;;
		edge-admin) echo "996|CDN安装" ;;
		*) echo "-|$key" ;;
	esac
}

kj_app_domains_for_ports() {
	local ports="$1"
	local target="$2"
	local type="$3"
	local domains=""
	local docker_ips=""
	local internal_ports=""
	local port conf domain proxy_line proxy_host proxy_port

	[ -d /home/web/conf.d ] || { echo "-"; return; }

	if [ "$type" = "docker" ] && command -v docker >/dev/null 2>&1; then
		docker_ips=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$target" 2>/dev/null)
		for port in ${ports//,/ }; do
			[ -z "$port" ] && continue
			local ipt
			ipt=$(docker port "$target" 2>/dev/null | awk -v hp="$port" '$0 ~ ":"hp"$" {split($1,a,"/"); print a[1]; exit}')
			[ -n "$ipt" ] && internal_ports="$internal_ports $ipt"
		done
	fi

	for conf in /home/web/conf.d/*.conf; do
		[ -f "$conf" ] || continue
		while IFS= read -r proxy_line; do
			proxy_host=$(echo "$proxy_line" | sed -E 's#^[[:space:]]*proxy_pass[[:space:]]+https?://([^/:;]+).*#\1#')
			proxy_port=$(echo "$proxy_line" | sed -nE 's#^[[:space:]]*proxy_pass[[:space:]]+https?://[^/:;]+:([0-9]+).*#\1#p')
			[ -z "$proxy_port" ] && proxy_port="80"

			local matched="false"
			for port in ${ports//,/ }; do
				[ "$proxy_port" = "$port" ] && matched="true"
			done
			if [ "$type" = "docker" ]; then
				[ "$proxy_host" = "$target" ] && matched="true"
				for port in $internal_ports; do
					[ "$proxy_port" = "$port" ] && matched="true"
				done
				for ip in $docker_ips; do
					[ "$proxy_host" = "$ip" ] && matched="true"
				done
			fi

			if [ "$matched" = "true" ]; then
				domain=$(grep -m1 -E "^[[:space:]]*server_name[[:space:]]+" "$conf" 2>/dev/null | sed -E 's/^[[:space:]]*server_name[[:space:]]+//; s/;.*$//' | awk '{print $1}')
				domain=${domain:-$(basename "$conf" .conf)}
				case " $domains " in *" $domain "*) ;; *) domains="$domains $domain" ;; esac
			fi
		done < <(grep -E "^[[:space:]]*proxy_pass[[:space:]]+https?://" "$conf" 2>/dev/null)
	done

	# 同时识别本地 Caddy 与 Docker Caddy 的 Caddyfile：domain { reverse_proxy host:PORT }
	local caddyfile
	for caddyfile in /etc/caddy/Caddyfile /home/docker/caddy/Caddyfile; do
		[ -f "$caddyfile" ] || continue
		local current_domains line rp_host rp_port matched d
		current_domains=""
		while IFS= read -r line; do
			# Caddy 站点块开头：example.com, www.example.com {
			if echo "$line" | grep -Eq '^[^#[:space:]][^{}]*[[:space:]]*\{[[:space:]]*$'; then
				current_domains=$(echo "$line" | sed -E 's/[[:space:]]*\{[[:space:]]*$//' | tr ',' ' ' | xargs 2>/dev/null)
			fi
			if echo "$line" | grep -Eq '^[[:space:]]*reverse_proxy[[:space:]]+'; then
				rp_host=$(echo "$line" | sed -E 's#^[[:space:]]*reverse_proxy[[:space:]]+(https?://)?([^/:[:space:]]+).*#\2#')
				rp_port=$(echo "$line" | sed -nE 's#^[[:space:]]*reverse_proxy[[:space:]]+(https?://)?[^/:[:space:]]+:([0-9]+).*#\2#p')
				[ -z "$rp_port" ] && rp_port="80"
				matched="false"
				for port in ${ports//,/ }; do
					[ "$rp_port" = "$port" ] && matched="true"
				done
				if [ "$type" = "docker" ]; then
					[ "$rp_host" = "$target" ] && matched="true"
					for port in $internal_ports; do [ "$rp_port" = "$port" ] && matched="true"; done
					for ip in $docker_ips; do [ "$rp_host" = "$ip" ] && matched="true"; done
				fi
				if [ "$matched" = "true" ]; then
					for d in $current_domains; do
						case " $domains " in *" $d "*) ;; *) domains="$domains $d" ;; esac
					done
				fi
			fi
		done < "$caddyfile"
	done

	domains=$(echo "$domains" | xargs 2>/dev/null)
	[ -n "$domains" ] && echo "$domains" || echo "-"
}

kj_app_install_method_label() {
	local app_type="$1"
	case "$app_type" in
		docker) echo -e "${gl_lv}容器${gl_bai}" ;;
		*) echo -e "${gl_hong}本地${gl_bai}" ;;
	esac
}

kj_app_docker_container_ports() {
	local cname="$1"
	docker port "$cname" 2>/dev/null | awk '{split($1,a,"/"); if (a[1] ~ /^[0-9]+$/) print a[1]}' | sort -n -u | tr '
' ',' | sed 's/,$//'
}

kj_app_add_row() {
	local app_id="$1"
	local app_name="$2"
	local app_ports="$3"
	local app_target="$4"
	local app_type="$5"
	local app_container_ports="$6"
	local app_domains
	[ -z "$app_ports" ] && return
	[ -z "$app_container_ports" ] && app_container_ports="-"
	app_domains=$(kj_app_domains_for_ports "$app_ports" "$app_target" "$app_type")
	KJ_APP_IDS+=("$app_id")
	KJ_APP_NAMES+=("$app_name")
	KJ_APP_PORTS+=("$app_ports")
	KJ_APP_CONTAINER_PORTS+=("$app_container_ports")
	KJ_APP_DOMAINS+=("$app_domains")
	KJ_APP_TARGETS+=("$app_target")
	KJ_APP_TYPES+=("$app_type")
}

kj_app_collect_ports() {
	KJ_APP_IDS=()
	KJ_APP_NAMES=()
	KJ_APP_PORTS=()
	KJ_APP_CONTAINER_PORTS=()
	KJ_APP_DOMAINS=()
	KJ_APP_TARGETS=()
	KJ_APP_TYPES=()
	local used_ports=" "

	if command -v docker >/dev/null 2>&1; then
		while IFS='|' read -r cname cports; do
			[ -z "$cname" ] && continue
			local ports
			ports=$(echo "$cports" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]+|\[::\]:[0-9]+|:::[0-9]+|127\.0\.0\.1:[0-9]+' | awk -F: '{print $NF}' | sort -n -u | tr '\n' ',' | sed 's/,$//')
			if [ -z "$ports" ]; then
				ports=$(docker port "$cname" 2>/dev/null | awk -F: '/->/ {print $NF}' | sort -n -u | tr '\n' ',' | sed 's/,$//')
			fi
			[ -z "$ports" ] && continue
			local label app_id app_name container_ports
			label=$(kj_app_label "$cname")
			app_id=${label%%|*}
			app_name=${label#*|}
			container_ports=$(kj_app_docker_container_ports "$cname")
			[ -z "$container_ports" ] && container_ports="-"
			kj_app_add_row "$app_id" "$app_name" "$ports" "$cname" "docker" "$container_ports"
			local p
			for p in ${ports//,/ }; do used_ports="$used_ports$p "; done
		done < <(docker ps --format '{{.Names}}|{{.Ports}}' 2>/dev/null)
	fi

	if command -v ss >/dev/null 2>&1; then
		while read -r port proc; do
			[ -z "$port" ] && continue
			case " $used_ports " in *" $port "*) continue ;; esac
			[ -z "$proc" ] && proc="unknown"
			case "$proc" in docker-proxy|containerd-shim*) continue ;; esac
			local label app_id app_name
			label=$(kj_app_label "$proc")
			app_id=${label%%|*}
			app_name=${label#*|}
			kj_app_add_row "$app_id" "$app_name" "$port" "$proc" "binary" "-"
			used_ports="$used_ports$port "
		done < <(ss -H -tulnp 2>/dev/null | awk '
			{
				addr=$5; port=addr; sub(/^.*:/,"",port);
				proc="";
				if (match($0,/users:\(\("[^"]+"/)) { proc=substr($0,RSTART+9,RLENGTH-9); gsub(/"/,"",proc); }
				if (port ~ /^[0-9]+$/) print port, proc;
			}' | sort -n -u)
	fi
}

kj_app_save_iptables_rules() {
	mkdir -p /etc/iptables
	iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
	if command -v crontab >/dev/null 2>&1; then
		(crontab -l 2>/dev/null | grep -v 'iptables-restore < /etc/iptables/rules.v4'; echo '@reboot iptables-restore < /etc/iptables/rules.v4') | crontab - 2>/dev/null || true
	fi
}

kj_app_docker_ip() {
	local cname="$1"
	docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$cname" 2>/dev/null | awk '{print $1}'
}

kj_app_port_is_blocked() {
	local port="$1"
	local target="$2"
	local type="$3"
	if [ "$type" = "docker" ]; then
		# Docker 发布端口走 PREROUTING/FORWARD/DOCKER-USER，不走 INPUT。
		# 必须同时满足：FORWARD 已跳转 DOCKER-USER，并且 DOCKER-USER 有该容器IP的 DROP。
		local container_ip
		container_ip=$(kj_app_docker_ip "$target")
		if [ -n "$container_ip" ] 			&& iptables -C FORWARD -j DOCKER-USER 2>/dev/null 			&& iptables -C DOCKER-USER -d "$container_ip" -j DROP 2>/dev/null; then
			return 0
		fi
		return 1
	fi
	if iptables -C KJ_APP_PORT_BLOCK -p tcp --dport "$port" -j DROP 2>/dev/null || iptables -C INPUT -p tcp --dport "$port" -j DROP 2>/dev/null; then
		return 0
	fi
	return 1
}

kj_app_access_status() {
	local ports="$1"
	local target="$2"
	local type="$3"
	local total=0
	local blocked=0
	local p
	for p in ${ports//,/ }; do
		[ -z "$p" ] && continue
		total=$((total + 1))
		if kj_app_port_is_blocked "$p" "$target" "$type"; then
			blocked=$((blocked + 1))
		fi
	done
	if [ "$total" -eq 0 ]; then
		echo "未知"
	elif [ "$blocked" -eq 0 ]; then
		echo "允许"
	elif [ "$blocked" -eq "$total" ]; then
		echo "阻止"
	else
		echo "部分阻止"
	fi
} 

kj_app_access_status_color() {
	local status="$1"
	case "$status" in
		允许) echo -e "${gl_lv}允许${gl_bai}" ;;
		阻止) echo -e "${gl_hong}阻止${gl_bai}" ;;
		部分阻止) echo -e "${gl_huang}部分阻止${gl_bai}" ;;
		*) echo "$status" ;;
	esac
}

kj_app_block_host_port() {
	local port="$1"
	[ -z "$port" ] && return 1
	install iptables
	iptables -N KJ_APP_PORT_BLOCK 2>/dev/null || true
	iptables -C INPUT -j KJ_APP_PORT_BLOCK 2>/dev/null || iptables -I INPUT -j KJ_APP_PORT_BLOCK

	# 本机服务的“阻止 IP+端口访问”只阻止公网/外部来源。
	# Docker 容器访问宿主机 host.docker.internal:端口 时，来源会是 docker0/br-* 网桥上的 172.* 容器 IP，
	# 这里必须放行，否则 nginx/caddy 等容器反代宿主机端口会被误判为外部访问并 DROP。
	iptables -C KJ_APP_PORT_BLOCK -p tcp --dport "$port" -s 127.0.0.0/8 -j ACCEPT 2>/dev/null || iptables -I KJ_APP_PORT_BLOCK -p tcp --dport "$port" -s 127.0.0.0/8 -j ACCEPT
	iptables -C KJ_APP_PORT_BLOCK -p udp --dport "$port" -s 127.0.0.0/8 -j ACCEPT 2>/dev/null || iptables -I KJ_APP_PORT_BLOCK -p udp --dport "$port" -s 127.0.0.0/8 -j ACCEPT
	iptables -C KJ_APP_PORT_BLOCK -p tcp --dport "$port" -i docker0 -j ACCEPT 2>/dev/null || iptables -I KJ_APP_PORT_BLOCK -p tcp --dport "$port" -i docker0 -j ACCEPT
	iptables -C KJ_APP_PORT_BLOCK -p udp --dport "$port" -i docker0 -j ACCEPT 2>/dev/null || iptables -I KJ_APP_PORT_BLOCK -p udp --dport "$port" -i docker0 -j ACCEPT
	iptables -C KJ_APP_PORT_BLOCK -p tcp --dport "$port" -i br+ -j ACCEPT 2>/dev/null || iptables -I KJ_APP_PORT_BLOCK -p tcp --dport "$port" -i br+ -j ACCEPT
	iptables -C KJ_APP_PORT_BLOCK -p udp --dport "$port" -i br+ -j ACCEPT 2>/dev/null || iptables -I KJ_APP_PORT_BLOCK -p udp --dport "$port" -i br+ -j ACCEPT
	iptables -C KJ_APP_PORT_BLOCK -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || iptables -I KJ_APP_PORT_BLOCK -m state --state ESTABLISHED,RELATED -j ACCEPT
	iptables -C KJ_APP_PORT_BLOCK -p tcp --dport "$port" -j DROP 2>/dev/null || iptables -A KJ_APP_PORT_BLOCK -p tcp --dport "$port" -j DROP
	iptables -C KJ_APP_PORT_BLOCK -p udp --dport "$port" -j DROP 2>/dev/null || iptables -A KJ_APP_PORT_BLOCK -p udp --dport "$port" -j DROP
}

kj_app_allow_host_port() {
	local port="$1"
	[ -z "$port" ] && return 1
	install iptables
	while iptables -C KJ_APP_PORT_BLOCK -p tcp --dport "$port" -j DROP 2>/dev/null; do iptables -D KJ_APP_PORT_BLOCK -p tcp --dport "$port" -j DROP; done
	while iptables -C KJ_APP_PORT_BLOCK -p udp --dport "$port" -j DROP 2>/dev/null; do iptables -D KJ_APP_PORT_BLOCK -p udp --dport "$port" -j DROP; done
	while iptables -C KJ_APP_PORT_BLOCK -p tcp --dport "$port" -s 127.0.0.0/8 -j ACCEPT 2>/dev/null; do iptables -D KJ_APP_PORT_BLOCK -p tcp --dport "$port" -s 127.0.0.0/8 -j ACCEPT; done
	while iptables -C KJ_APP_PORT_BLOCK -p udp --dport "$port" -s 127.0.0.0/8 -j ACCEPT 2>/dev/null; do iptables -D KJ_APP_PORT_BLOCK -p udp --dport "$port" -s 127.0.0.0/8 -j ACCEPT; done
	while iptables -C KJ_APP_PORT_BLOCK -p tcp --dport "$port" -i docker0 -j ACCEPT 2>/dev/null; do iptables -D KJ_APP_PORT_BLOCK -p tcp --dport "$port" -i docker0 -j ACCEPT; done
	while iptables -C KJ_APP_PORT_BLOCK -p udp --dport "$port" -i docker0 -j ACCEPT 2>/dev/null; do iptables -D KJ_APP_PORT_BLOCK -p udp --dport "$port" -i docker0 -j ACCEPT; done
	while iptables -C KJ_APP_PORT_BLOCK -p tcp --dport "$port" -i br+ -j ACCEPT 2>/dev/null; do iptables -D KJ_APP_PORT_BLOCK -p tcp --dport "$port" -i br+ -j ACCEPT; done
	while iptables -C KJ_APP_PORT_BLOCK -p udp --dport "$port" -i br+ -j ACCEPT 2>/dev/null; do iptables -D KJ_APP_PORT_BLOCK -p udp --dport "$port" -i br+ -j ACCEPT; done
}

kj_app_block_docker() {
	local cname="$1"
	local container_ip
	container_ip=$(kj_app_docker_ip "$cname")
	if [ -z "$container_ip" ]; then
		echo "未找到容器IP: $cname"
		return 1
	fi
	install iptables
	iptables -N DOCKER-USER 2>/dev/null || true
	# 有些系统/重载后 FORWARD 链没有跳到 DOCKER-USER，导致显示“阻止”但仍可访问；这里强制补上。
	iptables -C FORWARD -j DOCKER-USER 2>/dev/null || iptables -I FORWARD 1 -j DOCKER-USER

	# 先清理这个容器IP的旧规则，避免旧的 10/172/192 私网放行导致局域网 IP+端口仍能访问。
	while iptables -C DOCKER-USER -d "$container_ip" -j DROP 2>/dev/null; do iptables -D DOCKER-USER -d "$container_ip" -j DROP; done
	while iptables -C DOCKER-USER -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT 2>/dev/null; do iptables -D DOCKER-USER -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT; done
	while iptables -C DOCKER-USER -s 10.0.0.0/8 -d "$container_ip" -j ACCEPT 2>/dev/null; do iptables -D DOCKER-USER -s 10.0.0.0/8 -d "$container_ip" -j ACCEPT; done
	while iptables -C DOCKER-USER -s 172.16.0.0/12 -d "$container_ip" -j ACCEPT 2>/dev/null; do iptables -D DOCKER-USER -s 172.16.0.0/12 -d "$container_ip" -j ACCEPT; done
	while iptables -C DOCKER-USER -s 192.168.0.0/16 -d "$container_ip" -j ACCEPT 2>/dev/null; do iptables -D DOCKER-USER -s 192.168.0.0/16 -d "$container_ip" -j ACCEPT; done
	while iptables -C DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT 2>/dev/null; do iptables -D DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT; done

	# 放行已建立连接和 Docker 网桥来源，阻止其它来源直接 IP+端口访问容器。
	iptables -I DOCKER-USER 1 -d "$container_ip" -j DROP
	iptables -I DOCKER-USER 1 -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT
	iptables -I DOCKER-USER 1 -i br+ -d "$container_ip" -j ACCEPT
	iptables -I DOCKER-USER 1 -i docker0 -d "$container_ip" -j ACCEPT

	# Docker 可能同时发布 IPv6（如 [::]:18080）。IPv6 多数走 docker-proxy/INPUT，补 ip6tables 端口阻止。
	if command -v ip6tables >/dev/null 2>&1; then
		ip6tables -N KJ_APP_PORT_BLOCK 2>/dev/null || true
		ip6tables -C INPUT -j KJ_APP_PORT_BLOCK 2>/dev/null || ip6tables -I INPUT -j KJ_APP_PORT_BLOCK
		local hp
		for hp in $(docker port "$cname" 2>/dev/null | awk -F: '/->/ {print $NF}' | sort -n -u); do
			ip6tables -C KJ_APP_PORT_BLOCK -p tcp --dport "$hp" -s ::1/128 -j ACCEPT 2>/dev/null || ip6tables -I KJ_APP_PORT_BLOCK -p tcp --dport "$hp" -s ::1/128 -j ACCEPT
			ip6tables -C KJ_APP_PORT_BLOCK -p tcp --dport "$hp" -j DROP 2>/dev/null || ip6tables -A KJ_APP_PORT_BLOCK -p tcp --dport "$hp" -j DROP
		done
	fi
}

kj_app_allow_docker() {
	local cname="$1"
	local container_ip
	container_ip=$(kj_app_docker_ip "$cname")
	[ -z "$container_ip" ] && return 0
	while iptables -C DOCKER-USER -d "$container_ip" -j DROP 2>/dev/null; do iptables -D DOCKER-USER -d "$container_ip" -j DROP; done
	while iptables -C DOCKER-USER -i br+ -d "$container_ip" -j ACCEPT 2>/dev/null; do iptables -D DOCKER-USER -i br+ -d "$container_ip" -j ACCEPT; done
	while iptables -C DOCKER-USER -i docker0 -d "$container_ip" -j ACCEPT 2>/dev/null; do iptables -D DOCKER-USER -i docker0 -d "$container_ip" -j ACCEPT; done
	while iptables -C DOCKER-USER -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT 2>/dev/null; do iptables -D DOCKER-USER -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT; done
	while iptables -C DOCKER-USER -s 10.0.0.0/8 -d "$container_ip" -j ACCEPT 2>/dev/null; do iptables -D DOCKER-USER -s 10.0.0.0/8 -d "$container_ip" -j ACCEPT; done
	while iptables -C DOCKER-USER -s 172.16.0.0/12 -d "$container_ip" -j ACCEPT 2>/dev/null; do iptables -D DOCKER-USER -s 172.16.0.0/12 -d "$container_ip" -j ACCEPT; done
	while iptables -C DOCKER-USER -s 192.168.0.0/16 -d "$container_ip" -j ACCEPT 2>/dev/null; do iptables -D DOCKER-USER -s 192.168.0.0/16 -d "$container_ip" -j ACCEPT; done
	while iptables -C DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT 2>/dev/null; do iptables -D DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT; done
	if command -v ip6tables >/dev/null 2>&1; then
		local hp
		for hp in $(docker port "$cname" 2>/dev/null | awk -F: '/->/ {print $NF}' | sort -n -u); do
			while ip6tables -C KJ_APP_PORT_BLOCK -p tcp --dport "$hp" -j DROP 2>/dev/null; do ip6tables -D KJ_APP_PORT_BLOCK -p tcp --dport "$hp" -j DROP; done
			while ip6tables -C KJ_APP_PORT_BLOCK -p tcp --dport "$hp" -s ::1/128 -j ACCEPT 2>/dev/null; do ip6tables -D KJ_APP_PORT_BLOCK -p tcp --dport "$hp" -s ::1/128 -j ACCEPT; done
		done
	fi
}

kj_app_block_port() {
	local port="$1"
	local target="$2"
	local type="$3"
	if [ "$type" = "docker" ]; then
		kj_app_block_docker "$target"
	else
		kj_app_block_host_port "$port"
	fi
	kj_app_save_iptables_rules
	echo "已阻止 IP+端口 直接访问: $port"
}

kj_app_allow_port() {
	local port="$1"
	local target="$2"
	local type="$3"
	if [ "$type" = "docker" ]; then
		kj_app_allow_docker "$target"
	else
		kj_app_allow_host_port "$port"
	fi
	kj_app_save_iptables_rules
	echo "已允许 IP+端口 直接访问: $port"
}

kj_app_nginx_running() {
	if docker inspect -f '{{.State.Running}}' nginx 2>/dev/null | grep -q true; then
		return 0
	fi
	systemctl is-active --quiet nginx 2>/dev/null
}

kj_app_caddy_running() {
	# 本地安装的 Caddy 按 58 号配置检测；Docker Caddy 按容器运行状态检测。
	[ "$(systemctl is-active caddy 2>/dev/null)" = "active" ] && return 0
	docker inspect -f '{{.State.Running}}' caddy 2>/dev/null | grep -q true
}

kj_app_running_proxy_name() {
	local names=""
	kj_app_nginx_running && names="nginx"
	kj_app_caddy_running && names="${names:+$names、}caddy"
	[ -n "$names" ] && echo "$names" || echo "无"
}

kj_app_default_proxy() {
	# 如果只有一个服务运行，用正在运行的；两个都运行时优先 caddy。
	if kj_app_caddy_running; then
		echo "caddy"
	elif kj_app_nginx_running; then
		echo "nginx"
	else
		echo "nginx"
	fi
}

kj_app_select_proxy() {
	local running default_proxy choice
	running=$(kj_app_running_proxy_name)
	default_proxy=$(kj_app_default_proxy)
	echo "------------------------" >&2
	echo "1. 使用 nginx" >&2
	echo "2. 使用 caddy" >&2
	echo "现在运行的是：$running" >&2
	echo "0. 退出" >&2
	echo "------------------------" >&2
	read -e -p "请输入你的选择回车默认选择正在运行的: " choice
	case "$choice" in
		1) echo "nginx" ;;
		2) echo "caddy" ;;
		0) echo "" ;;
		"") echo "$default_proxy" ;;
		*) echo "$default_proxy" ;;
	esac
}

kj_app_reload_proxy_after_network_fix() {
	local proxy_type="$1"
	case "$proxy_type" in
		nginx)
			if docker inspect -f '{{.State.Running}}' nginx 2>/dev/null | grep -q true; then
				echo "正在检测 Docker nginx 配置..."
				if docker exec nginx nginx -t >/dev/null 2>&1; then
					docker exec nginx nginx -s reload >/dev/null 2>&1 || docker restart nginx
					echo "Docker nginx 检查通过，已重载/重启。"
				else
					echo "nginx 配置检测失败，已跳过重启，避免 nginx 启动不了。"
					docker exec nginx nginx -t 2>&1 || true
				fi
			elif systemctl is-active --quiet nginx 2>/dev/null; then
				echo "正在重载本地 nginx..."
				systemctl reload nginx || systemctl restart nginx
			else
				echo "未检测到正在运行的 nginx，跳过重启。"
			fi
			;;
		caddy)
			if [ "$(systemctl is-active caddy 2>/dev/null)" = "active" ]; then
				echo "正在重载本地 Caddy..."
				systemctl reload caddy || systemctl restart caddy
			elif docker inspect -f '{{.State.Running}}' caddy 2>/dev/null | grep -q true; then
				echo "正在重启 Docker caddy..."
				docker restart caddy
			else
				echo "未检测到正在运行的 caddy，跳过重载。"
			fi
			;;
	esac
}

kj_app_check_reload_proxy_menu() {
	local proxy_type
	proxy_type=$(kj_app_select_proxy)
	[ -z "$proxy_type" ] && return 0
	kj_app_reload_proxy_after_network_fix "$proxy_type"
}

kj_app_add_domain_nginx() {
	local port="$1"
	local target="$2"
	local type="$3"
	# Docker nginx 统一反代到宿主机映射端口；nginx 容器需已配置 host.docker.internal:host-gateway。
	local backend_host="host.docker.internal"
	local backend_port="$port"
	nginx_install_status
	add_yuming
	install_ssltls
	certs_status
	mkdir -p /home/web/conf.d
	wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/nginx/main/reverse-proxy.conf
	sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	sed -i "s/0.0.0.0/$backend_host/g" /home/web/conf.d/$yuming.conf
	sed -i "s/0000/$backend_port/g" /home/web/conf.d/$yuming.conf
	if docker exec nginx nginx -t >/dev/null 2>&1; then
		docker exec nginx nginx -s reload >/dev/null 2>&1 || docker restart nginx >/dev/null 2>&1
		echo "已使用 nginx 添加域名访问: https://$yuming -> $backend_host:$backend_port"
	else
		echo "nginx 配置检测失败，请检查: /home/web/conf.d/$yuming.conf"
		docker exec nginx nginx -t 2>&1 || true
	fi
}

kj_app_add_domain_caddy() {
	local port="$1"
	local target="$2"
	local type="$3"
	local backend_host="127.0.0.1"
	local backend_port="$port"
	local caddyfile="/etc/caddy/Caddyfile"
	local caddy_mode="local"
	# 本地 Caddy 参考 58 号配置，使用 127.0.0.1:本地端口；Docker Caddy 使用 host.docker.internal:本地端口。
	if [ "$(systemctl is-active caddy 2>/dev/null)" = "active" ]; then
		caddy_mode="local"
		backend_host="127.0.0.1"
		caddyfile="/etc/caddy/Caddyfile"
	elif docker inspect -f '{{.State.Running}}' caddy 2>/dev/null | grep -q true; then
		caddy_mode="docker"
		backend_host="host.docker.internal"
		caddyfile="$caddy_docker_caddyfile"
	else
		echo "未检测到正在运行的本地 Caddy 或 Docker Caddy。"
		return 1
	fi
	add_yuming
	mkdir -p "$(dirname "$caddyfile")"
	[ -f "$caddyfile" ] || touch "$caddyfile"
	if grep -qE "^[[:space:]]*$yuming[[:space:]]*\{" "$caddyfile" 2>/dev/null; then
		echo "域名 $yuming 已存在于 Caddyfile，请勿重复添加。"
		return 1
	fi
	cat >> "$caddyfile" <<EOF

# TAG: $yuming
$yuming {
    reverse_proxy $backend_host:$backend_port {
        header_up X-Real-IP {http.request.header.CF-Connecting-IP}
        header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
    }
}
EOF
	if [ "$caddy_mode" = "docker" ]; then
		docker run --rm -v "$caddyfile:/etc/caddy/Caddyfile" caddy:latest caddy fmt --overwrite /etc/caddy/Caddyfile >/dev/null 2>&1 || true
		caddy_docker_reload
		echo "已使用 Docker caddy 添加域名访问: https://$yuming -> $backend_host:$backend_port"
	else
		if ! command -v caddy >/dev/null 2>&1; then
			echo "未检测到 caddy 命令，请检查本地 Caddy 安装。"
			return 1
		fi
		caddy fmt --overwrite "$caddyfile" >/dev/null 2>&1 || true
		if caddy validate --config "$caddyfile" --adapter caddyfile >/dev/null 2>&1; then
			systemctl reload caddy >/dev/null 2>&1 || systemctl restart caddy >/dev/null 2>&1
			echo "已使用本地 caddy 添加域名访问: https://$yuming -> $backend_host:$backend_port"
		else
			echo "Caddyfile 配置有误，请手动检查: $caddyfile"
			caddy validate --config "$caddyfile" --adapter caddyfile
		fi
	fi
}

kj_app_add_domain() {
	local port="$1"
	local target="$2"
	local type="$3"
	local proxy_type
	[ -z "$port" ] && return 1
	proxy_type=$(kj_app_select_proxy)
	[ -z "$proxy_type" ] && return 0
	case "$proxy_type" in
		nginx) kj_app_add_domain_nginx "$port" "$target" "$type" ;;
		caddy) kj_app_add_domain_caddy "$port" "$target" "$type" ;;
	esac
}

kj_app_del_domain() {
	read -e -p "请输入要删除访问配置的域名（不带 https://）: " yuming
	[ -z "$yuming" ] && return
	rm -f "/home/web/conf.d/$yuming.conf"
	rm -f "/home/web/certs/${yuming}_key.pem" "/home/web/certs/${yuming}_cert.pem"
	docker exec nginx nginx -s reload >/dev/null 2>&1 || docker restart nginx >/dev/null 2>&1
	echo "已删除域名访问配置: $yuming"
}

kj_app_select_port() {
	local ports="$1"
	local port_count
	port_count=$(echo "$ports" | tr ',' '\n' | sed '/^$/d' | wc -l)
	if [ "$port_count" -le 1 ]; then
		echo "$ports" | cut -d',' -f1
		return
	fi
	echo "该应用有多个端口: $ports" >&2
	read -e -p "请输入要操作的端口: " chosen_port
	echo "$chosen_port"
}

kj_app_port_detail_menu() {
	local idx="$1"
	local app_id="${KJ_APP_IDS[$idx]}"
	local app_name="${KJ_APP_NAMES[$idx]}"
	local app_ports="${KJ_APP_PORTS[$idx]}"
	local app_container_ports="${KJ_APP_CONTAINER_PORTS[$idx]}"
	local app_domains="${KJ_APP_DOMAINS[$idx]}"
	local app_target="${KJ_APP_TARGETS[$idx]}"
	local app_type="${KJ_APP_TYPES[$idx]}"
	local local_ports_display container_ports_display
	if [ "$app_type" = "docker" ]; then
		local_ports_display="$app_ports"
		container_ports_display="${app_container_ports:-}"; [ -z "$container_ports_display" ] && container_ports_display="-"
	else
		local_ports_display="$app_ports"
		container_ports_display="-"
	fi
	while true; do
		clear
		echo "应用: $app_id  $app_name"
		echo "本地端口: $local_ports_display"
		echo "容器端口: $container_ports_display"
		echo -e "安装方法：$(kj_app_install_method_label "$app_type")"
		echo "域名: $app_domains"
		local status_plain
		status_plain=$(kj_app_access_status "$app_ports" "$app_target" "$app_type")
		echo -e "是否允许: $(kj_app_access_status_color "$status_plain")"
		echo "------------------------"
		echo "1. 添加域名访问     2. 删除域名访问"
		echo "3. 允许IP+端口访问  4. 阻止IP+端口访问"
		echo "5. nginx或caddy检查重启"
		echo "------------------------"
		echo "0. 返回上一级"
		echo "------------------------"
		read -e -p "请输入你的选择: " choice
		case "$choice" in
			1)
				local port
				port=$(kj_app_select_port "$app_ports")
				kj_app_add_domain "$port" "$app_target" "$app_type"
				;;
			2)
				kj_app_del_domain
				;;
			3)
				local port
				port=$(kj_app_select_port "$app_ports")
				kj_app_allow_port "$port" "$app_target" "$app_type"
				;;
			4)
				local port
				port=$(kj_app_select_port "$app_ports")
				kj_app_block_port "$port" "$app_target" "$app_type"
				;;
			5)
				kj_app_check_reload_proxy_menu
				;;
			0)
				break
				;;
			*)
				echo "无效的输入!"
				;;
		esac
		break_end
	done
}

linux_app_ports() {
	while true; do
		clear
		send_stats "安装的应用以及应用端口"
		kj_app_collect_ports
		echo -e "${gl_kjlan}安装的应用以及应用端口${gl_bai}"
		printf "%-6s %-6s %-12s %-12s %-10s\n" "序号" "编号" "本地端口" "容器端口" "是否允许"
		echo "------------------------"
		local i
		for i in "${!KJ_APP_NAMES[@]}"; do
			local status status_color local_ports_display container_ports_display method_color
			status=$(kj_app_access_status "${KJ_APP_PORTS[$i]}" "${KJ_APP_TARGETS[$i]}" "${KJ_APP_TYPES[$i]}")
			status_color=$(kj_app_access_status_color "$status")
			if [ "${KJ_APP_TYPES[$i]}" = "docker" ]; then
				local_ports_display="${KJ_APP_PORTS[$i]}"
				container_ports_display="${KJ_APP_CONTAINER_PORTS[$i]}"; [ -z "$container_ports_display" ] && container_ports_display="-"
			else
				local_ports_display="${KJ_APP_PORTS[$i]}"
				container_ports_display="-"
			fi
			method_color=$(kj_app_install_method_label "${KJ_APP_TYPES[$i]}")
			printf "%-6s %-6s %-12s %-12s %-10b\n" "$((i+1))." "${KJ_APP_IDS[$i]}" "$local_ports_display" "$container_ports_display" "$status_color"
			echo -e "安装方法：$method_color"
			echo -e "名称：${gl_bai}${KJ_APP_NAMES[$i]}"
			echo -e "域名：${gl_huang}${KJ_APP_DOMAINS[$i]}${gl_bai}"
			echo "------------------------"
		done
		echo "0. 返回上一级"
		echo "------------------------"
		read -e -p "请输入序号进入应用管理: " app_choice
		if [ "$app_choice" = "0" ]; then
			break
		fi
		if [[ "$app_choice" =~ ^[0-9]+$ ]] && [ "$app_choice" -ge 1 ] && [ "$app_choice" -le "${#KJ_APP_NAMES[@]}" ]; then
			kj_app_port_detail_menu "$((app_choice-1))"
		else
			echo "无效的输入!"
			break_end
		fi
	done
}
# ===== Hermes: 已安装应用端口管理（990）结束 =====


# ===== Hermes: Caddy 官方 Docker 管理（100） =====
caddy_docker_dir="/home/docker/caddy"
caddy_docker_backup_dir="/home/caddy"
caddy_docker_compose_file="$caddy_docker_dir/docker-compose.yml"
caddy_docker_caddyfile="$caddy_docker_dir/Caddyfile"

caddy_docker_ensure_installed() {
	install docker docker-compose-plugin
	mkdir -p "$caddy_docker_dir/data" "$caddy_docker_dir/config" "$caddy_docker_backup_dir"
	if [ ! -f "$caddy_docker_caddyfile" ]; then
		cat > "$caddy_docker_caddyfile" <<'EOF'
:80 {
    respond "Caddy Docker is running"
}
EOF
	fi
	cat > "$caddy_docker_compose_file" <<'EOF'
services:
  caddy:
    image: caddy:latest
    container_name: caddy
    restart: always
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./data:/data
      - ./config:/config
EOF
	cd "$caddy_docker_dir" || return 1
	docker compose up -d
}

caddy_docker_reload() {
	cd "$caddy_docker_dir" || return 1
	if ! docker ps --format '{{.Names}}' | grep -Fxq caddy; then
		docker compose up -d
	fi
	if docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1; then
		docker exec caddy caddy reload --config /etc/caddy/Caddyfile --force >/dev/null 2>&1 || docker compose restart caddy
		echo "✅ Caddy Docker 配置已生效"
	else
		echo "❌ Caddyfile 配置有误："
		docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
	fi
}

caddy_docker_list_config_internal() {
	if [ ! -s "$caddy_docker_caddyfile" ]; then
		echo "⚠️ 无配置。"
		return
	fi
	awk '
	BEGIN { tag = ""; block = ""; inside = 0 }
	/^# TAG: / { tag = substr($0, 8); next }
	/^[^# \t].*\{$/ { inside = 1; block = $0; next }
	inside == 1 {
		block = block "\n" $0
		if ($0 ~ /^}/) {
			printf "[\033[36m%s\033[0m] %s\n\n", (tag==""?"无备注":tag), block
			tag = ""; block = ""; inside = 0
		}
	}' "$caddy_docker_caddyfile"
}

caddy_docker_add_site() {
	caddy_docker_ensure_installed
	local DOMAIN PORT COMMENT
	while true; do
		read -e -p "请输入你的域名（例如 www.123.com）: " DOMAIN
		[ -n "$DOMAIN" ] && break
		echo "❌ 域名不能为空"
	done
	while true; do
		read -e -p "请输入反向代理端口（例如 18080）: " PORT
		[[ "$PORT" =~ ^[0-9]+$ ]] && break
		echo "❌ 端口必须是纯数字"
	done
	read -e -p "请输入该网站的备注（可留空，默认域名）: " COMMENT
	COMMENT=${COMMENT:-$DOMAIN}
	if grep -qE "^[[:space:]]*$DOMAIN[[:space:]]*\{" "$caddy_docker_caddyfile" 2>/dev/null; then
		echo "⚠️ 域名 $DOMAIN 已存在，请勿重复添加。"
		return
	fi
	cat >> "$caddy_docker_caddyfile" <<EOF

# TAG: $COMMENT
$DOMAIN {
    reverse_proxy host.docker.internal:$PORT {
        header_up X-Real-IP {http.request.header.CF-Connecting-IP}
        header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
    }
}
EOF
	docker run --rm -v "$caddy_docker_caddyfile:/etc/caddy/Caddyfile" caddy:latest caddy fmt --overwrite /etc/caddy/Caddyfile >/dev/null 2>&1 || true
	caddy_docker_reload
}

caddy_docker_delete_site() {
	[ -f "$caddy_docker_caddyfile" ] || { echo "❌ 配置文件不存在"; return; }
	mapfile -t INDEX_LIST < <(awk '/^# TAG: / { tag = substr($0, 8); next } /^[^# \t].*\{$/ { d=$1; gsub(/,/, "", d); printf "[%s] %s\n", (tag==""?"无备注":tag), d; tag="" }' "$caddy_docker_caddyfile")
	if [ ${#INDEX_LIST[@]} -eq 0 ]; then
		echo "⚠️ 未发现可删除的网站配置"
		return
	fi
	echo "请选择要删除的网站配置："
	for i in "${!INDEX_LIST[@]}"; do
		echo "$((i+1)). ${INDEX_LIST[$i]}"
	done
	echo "0. 退出"
	read -e -p "请输入序号: " SELECTED
	[ "$SELECTED" = "0" ] && return
	if [[ ! "$SELECTED" =~ ^[0-9]+$ ]] || [ "$SELECTED" -lt 1 ] || [ "$SELECTED" -gt "${#INDEX_LIST[@]}" ]; then
		echo "❌ 无效选择"
		return
	fi
	TARGET_INFO="${INDEX_LIST[$((SELECTED-1))]}"
	TARGET_DOMAIN=$(echo "$TARGET_INFO" | awk '{print $2}')
	TARGET_TAG=$(echo "$TARGET_INFO" | cut -d']' -f1 | sed 's/\[//')
	read -e -p "确定删除 $TARGET_DOMAIN 吗？(y/n): " CONFIRM
	if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
		awk -v domain="$TARGET_DOMAIN" -v tag="$TARGET_TAG" '
		BEGIN { skip=0; brace=0 }
		$0 == "# TAG: " tag { pending=1; next }
		pending && $0 ~ "^" domain "[[:space:]]*\\{" { skip=1; pending=0; brace=1; next }
		pending { print "# TAG: " tag; pending=0 }
		skip {
			if ($0 ~ /^}/) { skip=0; brace=0 }
			next
		}
		{ print }
		' "$caddy_docker_caddyfile" > "$caddy_docker_caddyfile.tmp" && mv "$caddy_docker_caddyfile.tmp" "$caddy_docker_caddyfile"
		caddy_docker_reload
		 echo "🗑 已删除 $TARGET_DOMAIN"
	fi
}

caddy_docker_backup() {
	mkdir -p "$caddy_docker_backup_dir"
	local ts backup_file
	ts=$(date +%Y-%m%d-%H%M)
	backup_file="$caddy_docker_backup_dir/caddy-$ts.tar.gz"
	if [ ! -d "$caddy_docker_dir" ]; then
		echo "❌ 未找到 $caddy_docker_dir，无法备份"
		return 1
	fi
	tar -czf "$backup_file" -C /home/docker caddy
	echo "✅ 备份完成：$backup_file"
}

caddy_docker_restore_from_dir() {
	local src_dir="$1"
	mapfile -t backups < <(ls -t "$src_dir"/caddy-*.tar.gz "$src_dir"/caddy*.tar.gz 2>/dev/null | awk '!seen[$0]++')
	if [ ${#backups[@]} -eq 0 ]; then
		echo "❌ $src_dir 没有找到 caddy 备份包"
		return
	fi
	echo "请选择恢复包："
	for i in "${!backups[@]}"; do
		echo "$((i+1)). $(basename "${backups[$i]}")"
	done
	echo "0. 退出"
	read -e -p "请输入序号（回车默认最新）: " sel
	[ "$sel" = "0" ] && return
	if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#backups[@]}" ]; then
		restore_file="${backups[$((sel-1))]}"
	else
		restore_file="${backups[0]}"
	fi
	if [ -d "$caddy_docker_dir" ]; then
		cd "$caddy_docker_dir" && docker compose down >/dev/null 2>&1 || true
		mv "$caddy_docker_dir" "${caddy_docker_dir}.before_restore_$(date +%Y%m%d%H%M%S)"
	fi
	mkdir -p /home/docker
	tar -xzf "$restore_file" -C /home/docker
	echo "✅ 已恢复：$restore_file"
	caddy_docker_ensure_installed
}

caddy_docker_restore_menu() {
	caddy_docker_ensure_installed
	echo "1. 从 /home/ 恢复"
	echo "2. 从 /home/caddy 恢复"
	echo "0. 退出"
	read -e -p "请输入你的选择: " src_choice
	case "$src_choice" in
		1) caddy_docker_restore_from_dir "/home" ;;
		2|"") caddy_docker_restore_from_dir "/home/caddy" ;;
		0) return ;;
		*) echo "无效选择" ;;
	esac
}

caddy_docker_update() {
	caddy_docker_ensure_installed
	cd "$caddy_docker_dir" || return 1
	docker compose pull
	docker compose up -d
	echo "✅ Caddy Docker 已更新"
}

caddy_docker_start_restart() {
	caddy_docker_ensure_installed
	cd "$caddy_docker_dir" || return 1
	docker compose up -d
	docker compose restart caddy >/dev/null 2>&1 || true
	caddy_docker_reload
	echo "✅ Caddy Docker 已启动/重启"
}

caddy_docker_stop() {
	if [ ! -d "$caddy_docker_dir" ]; then
		echo "❌ 未找到 $caddy_docker_dir"
		return 1
	fi
	cd "$caddy_docker_dir" || return 1
	docker compose down
	echo "✅ Caddy Docker 已停止"
}

caddy_docker_uninstall() {
	if [ ! -d "$caddy_docker_dir" ]; then
		echo "❌ 未找到 $caddy_docker_dir，无需卸载"
		return 1
	fi
	echo "⚠️ 将停止并删除 Caddy Docker：$caddy_docker_dir"
	echo "   备份目录 $caddy_docker_backup_dir 不会删除。"
	read -e -p "卸载前是否先备份？(Y/n): " backup_confirm
	if [[ ! "$backup_confirm" =~ ^[Nn]$ ]]; then
		caddy_docker_backup || return 1
	fi
	read -e -p "确认卸载并删除 $caddy_docker_dir 吗？(y/N): " confirm
	if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
		echo "已取消卸载"
		return
	fi
	cd "$caddy_docker_dir" && docker compose down >/dev/null 2>&1 || true
	rm -rf "$caddy_docker_dir"
	echo "✅ Caddy Docker 已卸载，备份保留在：$caddy_docker_backup_dir"
}

caddy_docker_manager() {
	while true; do
		clear
		echo "=============================="
		echo "      🛠 Caddy Docker 管理脚本"
		echo "📄 当前配置内容："
		echo "=============================="
		caddy_docker_list_config_internal
		echo "1. 安装到 /home/docker/caddy（可备注，端口 80/443/443udp）"
		echo "2. 添加网站配置"
		echo "3. 删除网站配置"
		echo "4. 备份到 /home/caddy/caddy-时间.tar.gz"
		echo "5. 恢复（从 /home 或 /home/caddy 选择）"
		echo "6. 更新"
		echo "7. 启动或重启"
		echo "8. 停止"
		echo "9. 卸载"
		echo "0. 退出"
		echo "=============================="
		read -e -p "请输入你的选择: " choice
		case "$choice" in
			1) caddy_docker_ensure_installed ;;
			2) caddy_docker_ensure_installed; caddy_docker_add_site ;;
			3) caddy_docker_delete_site ;;
			4) caddy_docker_backup ;;
			5) caddy_docker_restore_menu ;;
			6) caddy_docker_update ;;
			7) caddy_docker_start_restart ;;
			8) caddy_docker_stop ;;
			9) caddy_docker_uninstall ;;
			0) break ;;
			*) echo "无效选择" ;;
		esac
		break_end
	done
}
# ===== Hermes: Caddy 官方 Docker 管理（100）结束 =====

# ===== 哪吒远程定时备份配置（11 -> 5 -> 1000） =====
nezha_remote_backup_base_dir="/home/nezha/remote_backup"
nezha_remote_backup_job_dir="$nezha_remote_backup_base_dir/jobs"
nezha_remote_backup_state_dir="$nezha_remote_backup_base_dir/state"

nezha_remote_backup_safe_name() {
    local name="$1"
    [[ "$name" =~ ^[A-Za-z0-9_.-]+$ ]]
}

nezha_remote_backup_config_path() {
    echo "$nezha_remote_backup_job_dir/$1.conf"
}

nezha_remote_backup_script_path() {
    echo "$nezha_remote_backup_job_dir/$1.sh"
}

nezha_remote_backup_ensure_dirs() {
    mkdir -p "$nezha_remote_backup_job_dir" "$nezha_remote_backup_state_dir"
    if [ -d /root/.config/nezha_remote_backup/jobs ]; then
        cp -an /root/.config/nezha_remote_backup/jobs/. "$nezha_remote_backup_job_dir"/ 2>/dev/null || true
    fi
    if [ -d /root/.config/nezha_remote_backup/state ]; then
        cp -an /root/.config/nezha_remote_backup/state/. "$nezha_remote_backup_state_dir"/ 2>/dev/null || true
    fi
    chmod 700 "$nezha_remote_backup_base_dir" "$nezha_remote_backup_job_dir" "$nezha_remote_backup_state_dir" 2>/dev/null || true
}

nezha_remote_backup_write_runner() {
    local name="$1"
    local script_file
    script_file="$(nezha_remote_backup_script_path "$name")"
    cat > "$script_file" <<'EOF'
#!/bin/bash
set -euo pipefail

CONFIG_FILE="__CONFIG_FILE__"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 配置文件不存在: $CONFIG_FILE"
    exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"

BACKUP_DIR="/home/nezha"
STATE_DIR="/home/nezha/remote_backup/state"
LOG_PREFIX="[$(date '+%F %T')] [$JOB_NAME]"
mkdir -p "$BACKUP_DIR" "$STATE_DIR"
STATE_FILE="$STATE_DIR/${JOB_NAME}.last_success"

interval_seconds=$((INTERVAL_DAYS * 86400))
now_ts=$(date +%s)
if [ "${FORCE_RUN:-0}" != "1" ] && [ -f "$STATE_FILE" ]; then
    last_ts=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    if [ "$last_ts" -gt 0 ] && [ $((now_ts - last_ts)) -lt "$interval_seconds" ]; then
        next_ts=$((last_ts + interval_seconds))
        echo "$LOG_PREFIX 距离上次成功备份不足 ${INTERVAL_DAYS} 天，跳过。本次应在 $(date -d "@$next_ts" '+%F %T' 2>/dev/null || date -r "$next_ts" '+%F %T' 2>/dev/null || echo "$next_ts") 后运行。"
        exit 0
    fi
fi

start_nezha() {
    echo "[$(date '+%F %T')] [$JOB_NAME] 🚀 正在启动哪吒服务..."
    systemctl start nezha-dashboard 2>/dev/null || {
        if [ -x /opt/nezha/dashboard/app ]; then
            cd /opt/nezha/dashboard
            nohup ./app > /dev/null 2>&1 &
        fi
    }
}

stopped=0
cleanup() {
    if [ "$stopped" = "1" ]; then
        start_nezha || true
    fi
}
trap cleanup EXIT

echo "$LOG_PREFIX 🛑 正在停止哪吒服务..."
systemctl stop nezha-dashboard 2>/dev/null || true
pkill app 2>/dev/null || true
stopped=1

echo "[$(date '+%F %T')] [$JOB_NAME] ⏳ 等待数据落盘..."
sleep 3

if [ ! -f /opt/nezha/dashboard/data/sqlite.db ]; then
    echo "[$(date '+%F %T')] [$JOB_NAME] ❌ 数据库不存在，备份终止"
    exit 1
fi

DATE_STR=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/nezha_full_backup_${JOB_NAME}_${DATE_STR}.tar.gz"
LATEST_FILE="$BACKUP_DIR/nezha_full_backup_${JOB_NAME}_latest.tar.gz"

echo "[$(date '+%F %T')] [$JOB_NAME] 📦 开始打包备份..."
tar czf "$BACKUP_FILE" \
    /opt/nezha/dashboard/data \
    /opt/nezha/dashboard/app \
    /opt/nezha/dashboard/resource
cp -f "$BACKUP_FILE" "$LATEST_FILE"

echo "[$(date '+%F %T')] [$JOB_NAME] 📤 正在上传到远程服务器 ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR} ..."
SSH_OPTS=(-p "$REMOTE_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/root/.ssh/known_hosts)
if [ "$AUTH_TYPE" = "key" ]; then
    if [ ! -f "$SSH_KEY" ]; then
        echo "[$(date '+%F %T')] [$JOB_NAME] ❌ 密钥文件不存在: $SSH_KEY"
        exit 1
    fi
    SSH_CMD=(ssh -i "$SSH_KEY" "${SSH_OPTS[@]}")
    SCP_CMD=(scp -i "$SSH_KEY" -P "$REMOTE_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/root/.ssh/known_hosts)
else
    if ! command -v sshpass >/dev/null 2>&1; then
        echo "[$(date '+%F %T')] [$JOB_NAME] ❌ sshpass 未安装，密码登录无法上传"
        exit 1
    fi
    export SSHPASS="$REMOTE_PASSWORD"
    SSH_CMD=(sshpass -e ssh "${SSH_OPTS[@]}")
    SCP_CMD=(sshpass -e scp -P "$REMOTE_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/root/.ssh/known_hosts)
fi

"${SSH_CMD[@]}" "$REMOTE_USER@$REMOTE_HOST" "mkdir -p '$REMOTE_DIR'"
"${SCP_CMD[@]}" "$BACKUP_FILE" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
"${SCP_CMD[@]}" "$LATEST_FILE" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"

echo "[$(date '+%F %T')] [$JOB_NAME] 🧹 清理本地旧备份，只保留最近 ${LOCAL_KEEP} 份..."
ls -t "$BACKUP_DIR"/nezha_full_backup_${JOB_NAME}_*.tar.gz 2>/dev/null | grep -v '_latest.tar.gz$' | tail -n +$((LOCAL_KEEP + 1)) | xargs -r rm -f

echo "[$(date '+%F %T')] [$JOB_NAME] 🧹 清理远程旧备份，只保留最近 ${REMOTE_KEEP} 份..."
"${SSH_CMD[@]}" "$REMOTE_USER@$REMOTE_HOST" "ls -t '$REMOTE_DIR'/nezha_full_backup_${JOB_NAME}_*.tar.gz 2>/dev/null | grep -v '_latest.tar.gz$' | tail -n +$((REMOTE_KEEP + 1)) | xargs -r rm -f" || true

date +%s > "$STATE_FILE"
echo "[$(date '+%F %T')] [$JOB_NAME] ✅ 哪吒远程备份完成: $BACKUP_FILE"
EOF
    sed -i "s#__CONFIG_FILE__#$(nezha_remote_backup_config_path "$name")#g" "$script_file"
    chmod 700 "$script_file"
}

nezha_remote_backup_add_cron() {
    local name="$1" hour="$2" minute="$3" script_file
    script_file="$(nezha_remote_backup_script_path "$name")"
    check_crontab_installed
    (crontab -l 2>/dev/null | grep -Fv "$script_file"; echo "$minute $hour * * * /bin/bash $script_file") | crontab -
}

nezha_remote_backup_delete_cron() {
    local name="$1" script_file
    script_file="$(nezha_remote_backup_script_path "$name")"
    if command -v crontab >/dev/null 2>&1; then
        crontab -l 2>/dev/null | grep -Fv "$script_file" | crontab - 2>/dev/null || true
    fi
}

nezha_remote_backup_list() {
    nezha_remote_backup_ensure_dirs
    echo "已配置的哪吒远程备份："
    echo "------------------------"
    local found=0 conf name cron_line
    for conf in "$nezha_remote_backup_job_dir"/*.conf; do
        [ -f "$conf" ] || continue
        found=1
        # shellcheck disable=SC1090
        source "$conf"
        name="$JOB_NAME"
        cron_line=$(crontab -l 2>/dev/null | grep -F "$(nezha_remote_backup_script_path "$name")" || true)
        echo "名称：$JOB_NAME"
        echo "远程：$REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT 目录：$REMOTE_DIR"
        echo "登录：$AUTH_TYPE"
        echo "周期：每 $INTERVAL_DAYS 天，$HOUR 点 $MINUTE 分检查运行"
        if [ -n "$cron_line" ]; then
            echo "定时：$cron_line"
        else
            echo "定时：未添加"
        fi
        echo "------------------------"
    done
    if [ "$found" = "0" ]; then
        echo "暂无配置"
        echo "------------------------"
    fi
}

nezha_remote_backup_add_config() {
    nezha_remote_backup_ensure_dirs
    local name remote_host remote_user remote_port remote_dir auth_type ssh_key remote_password interval_days hour minute local_keep remote_keep conf_file
    read -e -p "配置名称（英文/数字/点/横线/下划线，例如 hk1）: " name
    if ! nezha_remote_backup_safe_name "$name"; then
        echo "❌ 名称不合法，只能使用英文、数字、点、横线、下划线"
        return 1
    fi
    read -e -p "远程服务器IP/域名: " remote_host
    [ -n "$remote_host" ] || { echo "❌ 远程服务器不能为空"; return 1; }
    read -e -p "远程用户名 [root]: " remote_user
    remote_user=${remote_user:-root}
    read -e -p "SSH端口 [22]: " remote_port
    remote_port=${remote_port:-22}
    read -e -p "远程保存目录 [/home/nezha-backup/$name]: " remote_dir
    remote_dir=${remote_dir:-/home/nezha-backup/$name}
    echo "登录方式：1. 密钥登录  2. 密码登录"
    read -e -p "请选择 [1]: " auth_choice
    auth_choice=${auth_choice:-1}
    ssh_key=""
    remote_password=""
    case "$auth_choice" in
        1)
            auth_type="key"
            read -e -p "本机SSH私钥路径 [/root/.ssh/id_rsa]: " ssh_key
            ssh_key=${ssh_key:-/root/.ssh/id_rsa}
            if [ ! -f "$ssh_key" ]; then
                echo "⚠️ 密钥文件当前不存在：$ssh_key"
                echo "   请先配置免密，或改用密码登录。"
            fi
            ;;
        2)
            auth_type="password"
            read -s -p "远程服务器密码: " remote_password
            echo ""
            [ -n "$remote_password" ] || { echo "❌ 密码不能为空"; return 1; }
            install sshpass
            ;;
        *)
            echo "❌ 无效登录方式"
            return 1
            ;;
    esac
    read -e -p "每几天运行一次 [1]: " interval_days
    interval_days=${interval_days:-1}
    [[ "$interval_days" =~ ^[0-9]+$ ]] && [ "$interval_days" -ge 1 ] || { echo "❌ 天数必须是大于0的数字"; return 1; }
    read -e -p "几点运行，小时 0-23 [3]: " hour
    hour=${hour:-3}
    [[ "$hour" =~ ^[0-9]+$ ]] && [ "$hour" -ge 0 ] && [ "$hour" -le 23 ] || { echo "❌ 小时必须是0-23"; return 1; }
    read -e -p "几分运行，分钟 0-59 [0]: " minute
    minute=${minute:-0}
    [[ "$minute" =~ ^[0-9]+$ ]] && [ "$minute" -ge 0 ] && [ "$minute" -le 59 ] || { echo "❌ 分钟必须是0-59"; return 1; }
    read -e -p "本地保留几份备份 [7]: " local_keep
    local_keep=${local_keep:-7}
    read -e -p "远程保留几份备份 [14]: " remote_keep
    remote_keep=${remote_keep:-14}
    [[ "$local_keep" =~ ^[0-9]+$ ]] && [ "$local_keep" -ge 1 ] || local_keep=7
    [[ "$remote_keep" =~ ^[0-9]+$ ]] && [ "$remote_keep" -ge 1 ] || remote_keep=14

    conf_file="$(nezha_remote_backup_config_path "$name")"
    {
        printf 'JOB_NAME=%q\n' "$name"
        printf 'REMOTE_HOST=%q\n' "$remote_host"
        printf 'REMOTE_USER=%q\n' "$remote_user"
        printf 'REMOTE_PORT=%q\n' "$remote_port"
        printf 'REMOTE_DIR=%q\n' "$remote_dir"
        printf 'AUTH_TYPE=%q\n' "$auth_type"
        printf 'SSH_KEY=%q\n' "$ssh_key"
        printf 'REMOTE_PASSWORD=%q\n' "$remote_password"
        printf 'INTERVAL_DAYS=%q\n' "$interval_days"
        printf 'HOUR=%q\n' "$hour"
        printf 'MINUTE=%q\n' "$minute"
        printf 'LOCAL_KEEP=%q\n' "$local_keep"
        printf 'REMOTE_KEEP=%q\n' "$remote_keep"
    } > "$conf_file"
    chmod 600 "$conf_file"

    nezha_remote_backup_write_runner "$name"
    nezha_remote_backup_add_cron "$name" "$hour" "$minute"

    echo "✅ 配置已保存：$conf_file"
    echo "✅ 定时任务已添加：每 $interval_days 天，$hour 点 $minute 分运行检查"
    echo "✅ 执行脚本：$(nezha_remote_backup_script_path "$name")"
    echo "⚠️ 如果使用密码登录，密码会明文保存到本机配置文件（chmod 600），请保护 root 权限。"
    echo "📁 配置/脚本/日志目录：$nezha_remote_backup_base_dir"
}

nezha_remote_backup_delete_config() {
    nezha_remote_backup_ensure_dirs
    nezha_remote_backup_list
    local name conf_file script_file
    read -e -p "请输入要删除的配置名称，输入0返回: " name
    [ "$name" = "0" ] && return 0
    if ! nezha_remote_backup_safe_name "$name"; then
        echo "❌ 名称不合法"
        return 1
    fi
    conf_file="$(nezha_remote_backup_config_path "$name")"
    script_file="$(nezha_remote_backup_script_path "$name")"
    if [ ! -f "$conf_file" ]; then
        echo "❌ 未找到配置：$name"
        return 1
    fi
    read -e -p "确认删除配置 $name 并删除对应定时任务？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "已取消"
        return 0
    fi
    nezha_remote_backup_delete_cron "$name"
    rm -f "$conf_file" "$script_file"
    echo "✅ 已删除配置和定时任务：$name"
}

nezha_remote_backup_run_now() {
    nezha_remote_backup_ensure_dirs
    nezha_remote_backup_list
    local name script_file
    read -e -p "请输入要立即执行的配置名称，输入0返回: " name
    [ "$name" = "0" ] && return 0
    if ! nezha_remote_backup_safe_name "$name"; then
        echo "❌ 名称不合法"
        return 1
    fi
    script_file="$(nezha_remote_backup_script_path "$name")"
    if [ ! -f "$script_file" ]; then
        echo "❌ 未找到执行脚本：$script_file"
        return 1
    fi
    echo "▶️ 开始执行"
    FORCE_RUN=1 /bin/bash "$script_file"
}


nezha_remote_backup_print_menu_summary() {
    nezha_remote_backup_ensure_dirs
    local found=0 conf name cron_line show_minute
    for conf in "$nezha_remote_backup_job_dir"/*.conf; do
        [ -f "$conf" ] || continue
        # shellcheck disable=SC1090
        source "$conf"
        name="$JOB_NAME"
        cron_line=$(crontab -l 2>/dev/null | grep -F "$(nezha_remote_backup_script_path "$name")" || true)
        [ -n "$cron_line" ] || continue
        if [ "$found" = "0" ]; then
            echo "如果有定时任务在这里显示"
            found=1
        fi
        show_minute="$MINUTE"
        if [[ "$show_minute" =~ ^[0-9]$ ]]; then
            show_minute="0$show_minute"
        fi
        echo "名称：$JOB_NAME  远程：$REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT"
        echo "每 $INTERVAL_DAYS 天，$HOUR 点 $show_minute 分运行"
        echo "crontab -e：$cron_line"
        echo "配置目录：$nezha_remote_backup_base_dir"
        echo "------------------------"
    done
}

nezha_remote_backup_menu() {
    while true; do
        clear
        echo "哪吒远程定时备份配置"
        echo "------------------------"
        echo "1. 添加/修改远程备份配置"
        echo "2. 查看配置和定时任务"
        echo "3. 删除远程配置并删除定时任务"
        echo "4. 立即执行某个远程备份配置"
        echo "------------------------"
        echo "0. 返回"
        echo "------------------------"
        read -e -p "请输入你的选择: " rb_choice
        case "$rb_choice" in
            1) nezha_remote_backup_add_config ;;
            2) nezha_remote_backup_list ;;
            3) nezha_remote_backup_delete_config ;;
            4) nezha_remote_backup_run_now ;;
            0) break ;;
            *) echo "无效选项" ;;
        esac
        read -n 1 -s -r -p "按任意键继续..."
    done
}







linux_panel() {
  while true; do
    clear
    # send_stats "面板工具"
    echo -e "▶ 面板工具"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}1.   ${gl_bai}宝塔面板官方版                      ${gl_kjlan}2.   ${gl_bai}aaPanel宝塔国际版"
    echo -e "${gl_kjlan}3.   ${gl_bai}1Panel新一代管理面板                ${gl_kjlan}4.   ${gl_bai}NginxProxyManager可视化面板"
    echo -e "${gl_kjlan}5.   ${gl_bai}哪吒探针备份与恢复                    ${gl_kjlan}6.   ${gl_bai}Ubuntu远程桌面网页版3006端口"
    echo -e "${gl_kjlan}7.   ${gl_bai}哪吒探针VPS监控面板                 ${gl_kjlan}8.   ${gl_bai}QB离线BT磁力下载面板"
    echo -e "${gl_kjlan}9.   ${gl_bai}Poste.io邮件服务器程序              ${gl_kjlan}10.  ${gl_bai}RocketChat多人在线聊天系统"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}11.  ${gl_bai}禅道项目管理软件                    ${gl_kjlan}12.  ${gl_bai}青龙面板定时任务管理平台"
    echo -e "${gl_kjlan}13.  ${gl_bai}Cloudreve网盘 ${gl_huang}★${gl_bai}                     ${gl_kjlan}14.  ${gl_bai}简单图床图片管理程序"
    echo -e "${gl_kjlan}15.  ${gl_bai}emby多媒体管理系统                  ${gl_kjlan}16.  ${gl_bai}Speedtest测速面板"
    echo -e "${gl_kjlan}17.  ${gl_bai}AdGuardHome去广告软件               ${gl_kjlan}18.  ${gl_bai}onlyoffice在线办公OFFICE"
    echo -e "${gl_kjlan}19.  ${gl_bai}雷池WAF防火墙面板                   ${gl_kjlan}20.  ${gl_bai}portainer容器管理面板"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}21.  ${gl_bai}VScode网页版                        ${gl_kjlan}22.  ${gl_bai}UptimeKuma监控工具"
    echo -e "${gl_kjlan}23.  ${gl_bai}Memos网页备忘录                     ${gl_kjlan}24.  ${gl_bai}Webtop远程桌面   用6号或者99 ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}25.  ${gl_bai}Nextcloud网盘                       ${gl_kjlan}26.  ${gl_bai}QD-Today定时任务管理框架"
    echo -e "${gl_kjlan}27.  ${gl_bai}Dockge容器堆栈管理面板              ${gl_kjlan}28.  ${gl_bai}LibreSpeed测速工具"
    echo -e "${gl_kjlan}29.  ${gl_bai}searxng聚合搜索站 ${gl_huang}★${gl_bai}                 ${gl_kjlan}30.  ${gl_bai}PhotoPrism私有相册系统"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}31.  ${gl_bai}StirlingPDF工具大全                 ${gl_kjlan}32.  ${gl_bai}drawio免费的在线图表软件 ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}33.  ${gl_bai}Sun-Panel导航面板                   ${gl_kjlan}34.  ${gl_bai}Pingvin-Share文件分享平台"
    echo -e "${gl_kjlan}35.  ${gl_bai}极简朋友圈                          ${gl_kjlan}36.  ${gl_bai}LobeChatAI聊天聚合网站"
    echo -e "${gl_kjlan}37.  ${gl_bai}MyIP工具箱 ${gl_huang}★${gl_bai}                        ${gl_kjlan}38.  ${gl_bai}小雅alist全家桶"
    echo -e "${gl_kjlan}39.  ${gl_bai}Bililive直播录制工具                ${gl_kjlan}40.  ${gl_bai}远程Windows11"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}41.  ${gl_bai}耗子管理面板                        ${gl_kjlan}42.  ${gl_bai}vaultwarden(可以注册)"
       echo -e "${gl_kjlan}43.  ${gl_bai}vaultwarden(禁止注册SMTP设置)       ${gl_kjlan}44.  ${gl_bai}vaultwarden(禁止注册)"
       echo -e "${gl_kjlan}45.  ${gl_bai}vaultwarden(注册SMTP设置)          ${gl_kjlan}46.  ${gl_bai}Aria2离线下载"
       echo -e "${gl_kjlan}47.  ${gl_bai}Cloudreve网盘                      ${gl_kjlan}48.  ${gl_bai}编译部署ssh Nexterm  53 79"
    echo -e "${gl_kjlan}49.  ${gl_bai}LibreTV                            ${gl_kjlan}50.  ${gl_bai}MoonTV"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}51.  ${gl_bai}极光面板                            ${gl_kjlan}52.  ${gl_bai}emby安装"
    echo -e "${gl_kjlan}53.  ${gl_bai}NextermSSH链接 48 79${gl_huang}★${gl_bai}                   ${gl_kjlan}54.  ${gl_bai}webssh ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}55.  ${gl_bai}openlist4.0.8 ${gl_huang}★${gl_bai}                    ${gl_kjlan}56.  ${gl_bai}umami网站流量统计系统"
    echo -e "${gl_kjlan}57.  ${gl_bai}dify安装 ${gl_huang}★${gl_bai}                         ${gl_kjlan}58.  ${gl_bai}安装caddy"
       echo -e "${gl_kjlan}------------------------"
       echo -e "${gl_kjlan}59.  ${gl_bai}docker安装rustdesk服务端 ${gl_huang}★${gl_bai}           ${gl_kjlan}60.  ${gl_bai}docker安装rustdesk中继端"
    echo -e "${gl_kjlan}61.  ${gl_bai}安装rustdesk远程桌面 ${gl_huang}★${gl_bai}               ${gl_kjlan}62.  ${gl_bai}安装x-ui"
    echo -e "${gl_kjlan}63.  ${gl_bai}安装rclone搭配64使用（82.86） ${gl_huang}★${gl_bai}      ${gl_kjlan}64.  ${gl_bai}安装r2beifen备份（82.86）"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}65.  ${gl_bai}安装caddy DNS版使用66配置反代 ${gl_huang}★${gl_bai}        ${gl_kjlan}66.  ${gl_bai}安装65caddy DNS配置版"
    echo -e "${gl_kjlan}67.  ${gl_bai}ownCloud网盘安装 ${gl_huang}★${gl_bai}                    ${gl_kjlan}68.  ${gl_bai}安装M38u8安装完成使用58添加反代"
    echo -e "${gl_kjlan}69.  ${gl_bai}it-tools工具箱 ${gl_huang}★${gl_bai}                      ${gl_kjlan}70.  ${gl_bai}安装盘搜"
    echo -e "${gl_kjlan}71.  ${gl_bai}安装zfile网盘 ${gl_huang}★${gl_bai}                      ${gl_kjlan}72.  ${gl_bai}安装Discourse论坛"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}73.  ${gl_bai}安装minio对象存储（74.88） ${gl_huang}★${gl_bai}           ${gl_kjlan}74.  ${gl_bai}添加对象存储api（73.88）"
    echo -e "${gl_kjlan}75.  ${gl_bai}docker安装openliat ${gl_huang}★${gl_bai}                 ${gl_kjlan}76.  ${gl_bai}vaultwarden管理员禁止注册 ${gl_huang}★${gl_bai} "
    echo -e "${gl_kjlan}77.  ${gl_bai}邮箱caddy与nginx都可用 ${gl_huang}★${gl_bai}              ${gl_kjlan}78.  ${gl_bai}Caddy安装mailcow邮箱 ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}79.  ${gl_bai}自编译ssh Nexterm 48 53${gl_huang}★${gl_bai}                  ${gl_kjlan}80.  ${gl_bai}自编译导航Sun-Panel ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}81.  ${gl_bai}Sun-Panel压缩包安装33docker ${gl_huang}★${gl_bai}         ${gl_kjlan}82.  ${gl_bai}s3自动备份安装包（63.64.86） ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}83.  ${gl_bai}自编译caddy-dns ${gl_huang}★${gl_bai}                    ${gl_kjlan}84.  ${gl_bai}Hitokoto API (一言)  ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}85.  ${gl_bai}自编译openlist ${gl_huang}★${gl_bai}                     ${gl_kjlan}86.  ${gl_bai}Backrest 资源备份（63.64.82） ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}87.  ${gl_bai}Certimate 证书管理 ${gl_huang}★${gl_bai}                  ${gl_kjlan}88.  ${gl_bai}自编译minio（73.74） ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}89.  ${gl_bai}自编译docker安装哪吒v2官方7号 ${gl_huang}★${gl_bai}         ${gl_kjlan}90.  ${gl_bai}BTC安装 ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}91.  ${gl_bai}自动进行谷歌浏览 ${gl_huang}★${gl_bai}                      ${gl_kjlan}92.  ${gl_bai}CLIProxyAPI ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}93.  ${gl_bai}Sub2API ${gl_huang}★${gl_bai}                             ${gl_kjlan}94.  ${gl_bai}Openclaw ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}95.  ${gl_bai}Open WebUI ${gl_huang}★${gl_bai}                          ${gl_kjlan}96.  ${gl_bai}Google检测${gl_huang}"
    echo -e "${gl_kjlan}97.  ${gl_bai}IP白名单模式                           ${gl_kjlan}98.  ${gl_bai}安装Google${gl_huang}"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}99.  ${gl_bai}Hermes机器人爱马仕                     ${gl_kjlan}100. ${gl_bai}caddy官方docker安装"
    echo -e "${gl_kjlan}101.  ${gl_bai}agent-ai备份                        ${gl_kjlan}102. ${gl_bai}lobehub安装webai"
    echo -e "${gl_kjlan}103. ${gl_bai}Fail2Ban SSH防暴力破解 ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}990.  ${gl_bai}安装的应用以及应用端口"
    echo -e "${gl_kjlan}996.  ${gl_bai}CDN安装 ${gl_huang}★${gl_bai}                           ${gl_kjlan}997.  ${gl_bai}PVE开小鸡面板"
       echo -e "${gl_kjlan}998.  ${gl_bai}CDN迁移恢复 ${gl_huang}★${gl_bai}                        ${gl_kjlan}999.  ${gl_bai}Webtop镜像版本管理 ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}1000.  ${gl_bai}网站自动备份 ${gl_huang}★${gl_bai}                       ${gl_kjlan}1001.  ${gl_bai}密码自动备份与恢复 ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}1002.  ${gl_bai}win10长期服务版 ${gl_huang}★${gl_bai}                    ${gl_kjlan}1003.  ${gl_bai}传送文件 ${gl_huang}★${gl_bai}"
       echo -e "${gl_kjlan}1004.  ${gl_bai}用105必装脚本 ${gl_huang}★${gl_bai}                      ${gl_kjlan}1005.  ${gl_bai}网站密码论坛备份合并 ${gl_huang}★${gl_bai}"
    echo -e "${gl_kjlan}------------------------"
    echo -e "${gl_kjlan}91自编译有48.80.83.84.85.86.87.88.89"
    echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    
    # ================= 动态检测已安装面板服务 =================
    declare -a installed_items=()
    # Docker 检测提速：原来每一项都 docker inspect 一次，几十个项目会很慢。
    # 现在只执行一次 docker ps -a，把所有容器名缓存起来，后面用 grep 精确匹配。
    local docker_container_list=""
    if command -v docker &>/dev/null; then
        docker_container_list="$(docker ps -a --format '{{.Names}}' 2>/dev/null || true)"
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
    check_docker "42" "vaultwarden"
    check_docker "46" "aria2-pro"
    check_docker "48" "nexterm"
    check_docker "49" "libretv"
    check_docker "50" "moontv"
    check_path "51" "/home/docker/jiguang"
    check_docker "54" "webssh"
    check_docker "55" "openlist"
    check_docker "56" "umami"
    check_docker "57" "dify"
    check_cmd "58" "caddy"
    check_docker "59" "hbbs"
    check_docker "60" "hbbr"
    check_path "62" "/usr/local/x-ui"
    check_cmd "63" "rclone"
    check_docker "64" "r2beifen"
    check_docker "67" "owncloud"
    check_docker "68" "m38u8"
    check_docker "69" "it-tools"
    check_docker "70" "pansou"
    check_docker "71" "zfile"
    check_docker "72" "discourse"
    check_docker "73" "minio"
    check_docker "78" "mailcow"
    check_docker "84" "hitokoto"
    check_docker "86" "backrest"
    check_docker "87" "certimate"
    check_docker "89" "nezha-dashboard"
    check_docker "90" "btc"
    check_docker "91" "chrome"
    check_docker "92" "cli-proxy-api"
    check_docker "93" "sub2api"
    check_path "94" "/root/.openclaw"
    check_docker "95" "open-webui"
    check_docker "98" "chromium"
    check_path "99" "/root/.hermes"
    check_docker "100" "caddy"
	check_path "101" "/root/agent-ai.sh"
	check_path "102" "lobehub.sh"
    check_docker "102" "windows"
    check_docker "103" "fail2ban"

    # 打印已安装的项目列表并自动折行输出
    if [ ${#installed_items[@]} -eq 0 ]; then
        echo -e "${gl_kjlan}已安装：无${gl_bai}"
    else
        echo -e -n "${gl_kjlan}已安装：${gl_bai}"
        local line=""
        local count=0
        for item in "${installed_items[@]}"; do
            if [ $count -eq 0 ]; then
                line="$item"
            else
                line="$line $item"
            fi
            count=$((count + 1))
            if [ $((count % 12)) -eq 0 ]; then
                echo -e "${gl_lv}$line${gl_bai}"
                line=""
                count=0
            fi
        done
        if [ -n "$line" ]; then
            echo -e "${gl_lv}$line${gl_bai}"
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
    echo "哪吒监控管理"
    echo "开源、轻量、易用的服务器监控与运维工具"
    echo "视频介绍: https://www.bilibili.com/video/BV1wv421C71t?t=0.1"
    echo "------------------------"
    nezha_remote_backup_print_menu_summary
    echo "1. 安装 / 更新哪吒"
    echo "恢复前先使用1号配置的4停止在使用3号启动"
    echo "------------------------"
    echo "2. 恢复哪吒面板"
    echo "恢复前先使用1号配置的4停止在使用3号启动"
    echo "------------------------"
    echo "------------------------"
    echo "9. docker安装面板"
    echo "------------------------"
    echo "------------------------"
    echo "999. 备份哪吒面板"
    echo "备份前先使用1号配置的4停止"
    echo "1000. 远程定时备份配置"
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
        # 恢复（稳定安全版）
        read -e -p "确认恢复？会覆盖当前数据 (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
          echo "已取消"
          sleep 1
          continue
        fi

        if [ ! -f /home/nezha/nezha_full_backup.tar.gz ]; then
          echo "❌ 未找到备份文件"
          sleep 2
          continue
        fi

echo "🛑 停止服务..."
systemctl stop nezha-dashboard 2>/dev/null
pkill app 2>/dev/null

echo "📦 恢复数据..."
tar xzvf /home/nezha/nezha_full_backup.tar.gz -C /

echo "🔐 修复权限..."
chmod 600 /opt/nezha/dashboard/data/sqlite.db
chmod 600 /opt/nezha/dashboard/data/config.yaml

echo "🚀 启动服务..."
systemctl start nezha-dashboard 2>/dev/null || {
    cd /opt/nezha/dashboard
    nohup ./app > /dev/null 2>&1 &
}

        sleep 2
        ss -lntp | grep app

        echo "✅ 恢复完成"
        ;;

      9)
        clear
        echo "▶️ 正在启动哪吒docker安装..."
        bash <(curl -sS https://raw.githubusercontent.com/zaixiangjian/sh/main/ai/dockernezhav0.sh)
        echo "✅ 哪吒docker安装完成。"
        ;;

      999)
        # 备份（生产级安全版）

        echo "🛑 正在优雅停止服务..."
        systemctl stop nezha-dashboard 2>/dev/null
        pkill app 2>/dev/null

        echo "⏳ 等待数据落盘..."
        sleep 3

        if [ ! -f /opt/nezha/dashboard/data/sqlite.db ]; then
          echo "❌ 数据库不存在，备份终止"
          sleep 2
          continue
        fi

        mkdir -p /home/nezha

        echo "📦 开始备份..."

        tar czvf /home/nezha/nezha_full_backup.tar.gz \
          /opt/nezha/dashboard/data \
          /opt/nezha/dashboard/app \
          /opt/nezha/dashboard/resource

        if [ $? -eq 0 ]; then
          echo "✅ 备份成功: /home/nezha/nezha_full_backup.tar.gz"
        else
          echo "❌ 备份失败"
        fi

        echo "🚀 正在重新启动哪吒服务..."
        systemctl start nezha-dashboard 2>/dev/null || {
          cd /opt/nezha/dashboard
          nohup ./app > /dev/null 2>&1 &
        }

        sleep 2
        if pgrep -f "/opt/nezha/dashboard/app" >/dev/null 2>&1 || systemctl is-active --quiet nezha-dashboard 2>/dev/null; then
          echo "✅ 哪吒服务已重新启动"
        else
          echo "⚠️ 哪吒服务可能未启动，请手动检查：systemctl status nezha-dashboard"
        fi
        ;;

      1000)
        nezha_remote_backup_menu
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
            cd /home/ && mkdir -p docker/cloud && cd docker/cloud && mkdir temp_data && mkdir -vp cloudreve/{uploads,avatar} && touch cloudreve/conf.ini && touch cloudreve/cloudreve.db && mkdir -p aria2/config && mkdir -p data/aria2 && chmod -R 777 data/aria2
            curl -o /home/docker/cloud/docker-compose.yml ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/docker/main/cloudreve-docker-compose.yml
            cd /home/docker/cloud/ && docker compose up -d

            clear
            echo "cloudreve已经安装完成"
            check_docker_app_ip
            sleep 3
            docker logs cloudreve
            echo ""


            ;;

          2)
            docker rm -f cloudreve
            docker rmi -f cloudreve/cloudreve:latest
            docker rm -f aria2
            docker rmi -f p3terx/aria2-pro
            cd /home/ && mkdir -p docker/cloud && cd docker/cloud && mkdir temp_data && mkdir -vp cloudreve/{uploads,avatar} && touch cloudreve/conf.ini && touch cloudreve/cloudreve.db && mkdir -p aria2/config && mkdir -p data/aria2 && chmod -R 777 data/aria2
            curl -o /home/docker/cloud/docker-compose.yml ${gh_proxy}https://raw.githubusercontent.com/zaixiangjian/docker/main/cloudreve-docker-compose.yml
            cd /home/docker/cloud/ && docker compose up -d
            clear
            echo "cloudreve已经安装完成"
            check_docker_app_ip
            sleep 3
            docker logs cloudreve
            echo ""
            ;;
          3)

            docker rm -f cloudreve
            docker rmi -f cloudreve/cloudreve:latest
            docker rm -f aria2
            docker rmi -f p3terx/aria2-pro
            rm -rf /home/docker/cloud
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
        
        ADMINPASSWORD="admin123456789"
        PASSWORD="111111"
    
        docker_name="libretv"
        docker_img="bestzwei/libretv:latest"
        docker_port=8899
        docker_rum="docker run -d \
          --name libretv \
          --restart unless-stopped \
          -p 8899:8080 \
          -e PASSWORD=$PASSWORD \
          -e ADMINPASSWORD=$ADMINPASSWORD \
          $docker_img"
        docker_describe="LibreTV 是一个 IPTV 媒体播放器，支持直播电视流媒体播放"
        docker_url="项目地址: https://hub.docker.com/r/bestzwei/libretv"
        docker_use="echo \"✅ 设置密码: $ADMINPASSWORD\" && echo \"🌐 访问地址: http://localhost:$docker_port\""
        docker_passwd=""
        docker_app
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
      docker_name="emby"
      docker_img="emby/embyserver:latest"
      docker_port=8096
      docker_rum="docker run -d \
              --name emby \
              --restart=unless-stopped \
              -v /home/docker/emby/config:/config \
              -v /home/docker/emby/电影:/mnt/embydianying \
              -v /home/docker/emby/电视剧:/mnt/embydianshiju \

              -v /home/挂载/电视剧:/mnt/dianshiju \
              -v /home/挂载/电影:/mnt/dianying \

              -p 8096:8096 \
              -p 8920:8920 \
              emby/embyserver:latest"
      docker_describe="Emby 媒体服务器，支持电影和电视剧挂载"
      docker_url="官网介绍: https://emby.media/"
      docker_use=""
      docker_passwd=""
      docker_app
        ;;


      53)

      clear
      echo "Nexterm - 基于 Web 的终端访问工具"
      echo "GitHub 地址"
      echo "https://github.com/gnmyt/Nexterm"
      echo "功能介绍: 使用浏览器远程访问主机终端，支持加密会话与多用户协作"
      echo
      echo "1. 安装 Nexterm"
      echo "2. 备份 Nexterm"
      echo "3. 卸载 Nexterm"
      echo "4. 恢复 Nexterm"
      read -p "请输入操作编号: " sub_choice

      nexterm_dir="/home/docker/nexterm"
      backup_dir="/home/docker"
      backup_prefix="nexterm"
      backup_limit=3
      docker_name="nexterm"
      docker_img="germannewsmaker/nexterm:1.0.5-OPEN-PREVIEW"
      docker_port=6989

      local_ip=$(hostname -I | awk '{print $1}')
      ipv6_addr=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n 1)

      case "$sub_choice" in
        1)
          if docker ps -a --format '{{.Names}}' | grep -qw $docker_name; then
            echo "$docker_name 已经安装完成"
            echo "------------------------"
            echo "访问地址:"
            echo "http://${local_ip}:${docker_port}"
            [ -n "$ipv6_addr" ] && echo "http://[${ipv6_addr}]:${docker_port}"
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

            echo "$docker_name 已经安装完成"
            echo "------------------------"
            echo "https://github.com/gnmyt/Nexterm"
            echo "通过 SSH、VNC 和 RDP 远程连接，通过 SFTP 管理文件"
            echo "访问地址:"
            echo "http://${local_ip}:${docker_port}"
            [ -n "$ipv6_addr" ] && echo "http://[${ipv6_addr}]:${docker_port}"
            echo "加密密钥为: $encryption_key"
          fi
          ;;
        2)
          timestamp=$(date +%Y%m%d%H%M%S)
          backup_file="${backup_prefix}-${timestamp}.tar.gz"
          tar -czf "${backup_dir}/${backup_file}" -C "$nexterm_dir" .
          echo "备份已保存为: ${backup_dir}/${backup_file}"

          # 删除多余的旧备份，保留最新3个
          find "$backup_dir" -name "${backup_prefix}-*.tar.gz" | sort -r | sed -n '4,$p' | xargs -r rm -f
          ;;
        3)
          read -p "确认卸载 Nexterm？将删除容器和 $nexterm_dir 目录 [y/N]: " confirm
          if [[ "$confirm" =~ ^[Yy]$ ]]; then
            docker rm -f $docker_name 2>/dev/null
            rm -rf "$nexterm_dir"
            echo "Nexterm 已卸载完成"
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
          read -p "请输入备份编号（留空则恢复最新）: " sel

          if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -le "${#backups[@]}" ]; then
            restore_file="${backups[$((sel-1))]}"
          else
            restore_file="${backups[0]}"
          fi

          echo "恢复自: $(basename $restore_file)"
          read -p "请输入原始加密密钥（必填，恢复后用于重新启动服务）: " encryption_key
          if [ -z "$encryption_key" ]; then
            echo "未输入密钥，操作取消。"
            break
          fi

          docker rm -f $docker_name 2>/dev/null
          rm -rf "$nexterm_dir"
          mkdir -p "$nexterm_dir"
          tar -xzf "$restore_file" -C "$nexterm_dir"

          echo "恢复完成。正在重新运行安装启动服务。"

          docker run -d \
            --name $docker_name \
            -e ENCRYPTION_KEY=$encryption_key \
            --restart always \
            -p ${docker_port}:6989 \
            -v $nexterm_dir:/app/data \
            $docker_img

          echo "------------------------"
          echo "$docker_name 已重新启动"
          echo "访问地址:"
          echo "http://${local_ip}:${docker_port}"
          [ -n "$ipv6_addr" ] && echo "http://[${ipv6_addr}]:${docker_port}"
          echo "加密密钥为: $encryption_key"
          ;;
        *)
          echo "无效选项"
          ;;
      esac

      read -p "按任意键继续..." -n1
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
          systemctl daemon-reload
          systemctl enable openlist > /dev/null 2>&1
          systemctl restart openlist

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
          echo "服务状态：$(systemctl is-active openlist)"
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
          systemctl stop openlist > /dev/null 2>&1
          systemctl disable openlist > /dev/null 2>&1
          rm -f $SERVICE_FILE
          systemctl daemon-reload
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

      # 自动创建目录
      [ ! -d /home/docker/umami ] && mkdir -p /home/docker/umami
      cd /home/docker/umami || exit 1

      # 写入 docker-compose.yml
      cat > docker-compose.yml <<EOF
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
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://umami:umami123@umami-db:5432/umami
      APP_SECRET: $(openssl rand -hex 16)
    depends_on:
      - umami-db
EOF

      # 启动容器
      docker compose up -d

      echo "------------------------"
      echo "访问地址:"
      echo "http://$(hostname -I | awk '{print $1}'):3000"
      echo "http://$(curl -s ifconfig.me):${docker_port}"
      echo "账号：admin 密码：umami"
      echo "默认密码：umami123"
      echo "------------------------"

      docker_describe="Umami 网站流量统计系统，轻量、隐私友好"
      docker_url="GitHub: https://github.com/umami-software/umami"
      docker_use="默认访问地址：http://服务器IP:3000，账号：admin 密码：umami"
      docker_passwd="umami123"
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
    # =======================
    # Rclone 管理脚本
    # =======================
    # 显示当前 Rclone 定时任务
    show_cron_jobs() {
        echo "======================================"
        echo "Rclone 定时任务："
        crontab -l 2>/dev/null | grep "s3beifen" >/dev/null
        if [[ $? -ne 0 ]]; then
            echo "无"
        else
            crontab -l | grep "s3beifen"
        fi
        echo "======================================"
    }

    # 创建备份任务（5/6/7通用）
    create_backup_job() {
        script_name="$1"
        echo "======== 添加 Rclone 备份任务 ($script_name) ========"
        read -p "请输入要备份的目录名（默认：home）: " in_dir
        if [[ -z "$in_dir" ]]; then
            in_dir="home"
        fi
        local_dir="/${in_dir%/}/"
        if [[ "$local_dir" == "/" ]]; then
            echo "❌ 不允许备份系统根目录 /"
            return
        fi
        dir_name="${in_dir}"
        echo "目录名称成功识别：$dir_name"
        echo
        echo "当前 Rclone 远程："
        rclone listremotes
        echo
        read -p "Rclone名称输入上方已连接名称: " remote_name
        read -p "请输入存储桶名称（S3或者R2起的名称）: " bucket_name
        backup_cmd="rclone copy ${local_dir} ${remote_name}:${bucket_name}/服务器备份/${dir_name}"
        echo
        echo "生成的命令："
        echo "$backup_cmd"
        echo
        echo "#!/bin/bash" > /root/${script_name}
        echo "$backup_cmd" >> /root/${script_name}
        chmod +x /root/${script_name}
        echo "备份脚本已创建：/root/${script_name}"
        echo "先执行一次备份……"
        bash /root/${script_name}
        echo
        echo "======== 设置定时任务 ========"
        read -p "每几天运行一次（0 = 每小时模式）: " period
        if [[ "$period" == "0" ]]; then
            read -p "每几小时运行一次（例如 4）: " hours
            read -p "几分执行（0-59）: " minute
            cron_rule="$minute */$hours * * * /bin/bash /root/${script_name}"
        else
            read -p "几点执行（0-23）: " hour
            read -p "几分执行（0-59）: " minute
            cron_rule="$minute $hour */$period * * /bin/bash /root/${script_name}"
        fi
        (crontab -l 2>/dev/null | grep -v "/root/${script_name}"; echo "$cron_rule") | crontab -
        echo
        echo "定时任务已添加："
        echo "$cron_rule"
        echo
    }

    # 删除定时任务
    delete_backup_jobs() {
        echo "======= 当前 Rclone 定时任务 ======="
        crontab -l | grep "s3beifen"
        echo "===================================="
        read -p "是否删除所有 s3beifen 相关任务？(y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
            crontab -l | grep -v "s3beifen" | crontab -
            echo "定时任务已删除。"
        else
            echo "取消删除。"
        fi
    }

    # 主菜单循环
    while true; do
        clear
        show_cron_jobs
        echo "官网: https://rclone.org/"
        echo
        echo "1. 安装 Rclone"
        echo "2. 获取配置文件路径"
        echo "3号配置填写如下r2为名称"
        echo "[r2]
type = s3
provider = Cloudflare
access_key_id =密钥id
secret_access_key =密钥
endpoint =存储桶访问地址"


        echo "3. 修改配置文件"
        echo "4. 查看已添加的 Rclone 远程"
        echo "5. 添加目录备份任务 (生成 s3beifen.sh)"
        echo "6. 添加目录备份任务 (生成 s3beifen1.sh)"
        echo "7. 添加目录备份任务 (生成 s3beifen2.sh)"
        echo "8. 删除定时任务"
        echo "9. 卸载 Rclone"
        echo "0. 返回上一级菜单"
        echo
        read -p "请输入操作编号: " choice
        case $choice in
            1)
                sudo -v
                curl https://rclone.org/install.sh | sudo bash
                ;;
            2)
                rclone config file
                ;;
            3)
                nano /root/.config/rclone/rclone.conf
                ;;
            4)
                rclone listremotes
                ;;
            5)
                create_backup_job "s3beifen.sh"
                ;;
            6)
                create_backup_job "s3beifen1.sh"
                ;;
            7)
                create_backup_job "s3beifen2.sh"
                ;;
            8)
                delete_backup_jobs
                ;;
            9)
                sudo rm -f /usr/bin/rclone
                sudo rm -rf /root/.config/rclone
                echo "Rclone 已卸载"
                ;;
            0)
                break
                ;;
            *)
                echo "无效输入"
                ;;
        esac
        read -p "按回车键继续……"
    done
    ;;


64)
    docker_name="r2beifen"
    docker_img="garethgeorge/backrest:latest"
    docker_port=9898

    # 获取宿主机时区
    if [ -f /etc/timezone ]; then
        host_tz=$(cat /etc/timezone)
    else
        host_tz=$(timedatectl show --property=Timezone --value)
    fi

    docker_rum="docker run -d \
        --name $docker_name \
        --hostname $docker_name \
        --restart unless-stopped \
        -v /root/backrest/data:/data \
        -v /root/backrest/config:/config \
        -v /root/backrest/cache:/cache \
        -v /root/backrest/tmp:/tmp \
        -v /root/.config/rclone:/root/.config/rclone \
        -v /home:/userdata/home \
        -e BACKREST_DATA=/data \
        -e BACKREST_CONFIG=/config/config.json \
        -e XDG_CACHE_HOME=/cache \
        -e TMPDIR=/tmp \
        -e TZ=$host_tz \
        -p $docker_port:$docker_port \
        $docker_img"

    docker_describe="BackRest 数据备份容器，支持用户 home 目录挂载，自动跟随宿主机时区"
    docker_url="项目地址: https://hub.docker.com/r/garethgeorge/backrest
  添加仓库Repository URI具体如下
  rclone:添加的名称:存储桶名称
  rclone:r2:beifen"

    docker_use=""
    docker_passwd=""
    docker_app
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
    docker_name="minio"
    docker_img="minio/minio:latest"
    docker_port=9000
    docker_console_port=9001
    # 自动生成 20 位随机强密码（只包含大小写字母和数字）
    MINIO_ROOT_USER=$(tr -dc 'A-Z0-9' </dev/urandom | head -c 20)
    MINIO_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 40)
    
    docker_rum="docker run -d \
                    --name ${docker_name} \
                    --restart always \
                    -p 127.0.0.1:${docker_port}:9000 \
                    -p 127.0.0.1:${docker_console_port}:9001 \
                    -v /home/docker/minio/data:/data \
                    -e MINIO_ROOT_USER=${MINIO_ROOT_USER} \
                    -e MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD} \
                    ${docker_img} server /data --console-address :${docker_console_port}"
    
    docker_describe="MinIO 是一个高性能的分布式对象存储服务，兼容 S3 API，适合个人或团队使用。"
    docker_url="官网介绍: https://min.io"
    docker_use=""
    docker_passwd="${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}"
    docker_app
;;


      74)
        clear
        echo "▶️ 安装minio..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/minlo.sh)
        echo "✅ 安装minio..."
        ;;





75)
    docker_name="openlist"
    docker_img="openlistteam/openlist:v4.1.9"
    docker_port=5244
    docker_describe="OpenList：Alist 分支的开源网盘聚合程序（支持多存储）"
    docker_url="官网介绍: https://github.com/OpenListTeam/OpenList

查看密码使用
在本机输入代码

docker logs openlist
"
    # 创建数据目录并设置权限
    mkdir -p /home/docker/openlist/data
    chown -R 1000:1000 /home/docker/openlist/data
    chmod -R 755 /home/docker/openlist/data

    # 启动容器
    docker run -d \
      --name openlist \
      --restart always \
      -p ${docker_port}:5244 \
      -v /home/docker/openlist/data:/opt/openlist/data \
      --user 1000:1000 \
      ${docker_img}

    # 输出访问地址和首次密码提示
    docker_use="访问地址：http://$(hostname -I | awk '{print $1}'):${docker_port}"
    docker_passwd="首次启动后使用：docker logs openlist 查看管理员密码"

    echo "$docker_use"
    echo "$docker_passwd"

    docker_app
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
    while true; do
        clear
        echo -e "------------------------------------------------"
        echo -e "      OpenList 最新版 (AList Fork) 编译工具"
        echo -e "------------------------------------------------"
        echo -e "【源码与镜像管理】"
        echo -e "1)  安装环境并修复 Docker (解决 Dpkg/Sock 错误)"
        echo -e "2)  一键克隆源码并开始 Docker 编译 (本地构建)"
        echo -e "3)  登录 Docker Hub"
        echo -e "4)  推送镜像到 Docker Hub"
        echo -e "------------------------------------------------"
        echo -e "【容器部署管理】"
        echo -e "11) 部署/启动 容器 (使用本地最新镜像)"
        echo -e "12) 查看运行日志 (获取初始密码)"
        echo -e "13) 停止并彻底卸载 OpenList"
        echo -e "------------------------------------------------"
        echo -e "0)  返回主菜单"
        echo -e "------------------------------------------------"
        read -p "请输入操作编号: " ol_choice

        # 核心变量配置 - 已更新为最新版 OpenList 地址
        my_github_url="https://github.com/zaixiangjian/OpenList.git"
        my_docker_img="zaixiangjian/openlist:latest"
        build_dir="/home/docker/openlist_latest"

        case $ol_choice in
            1)
                echo -e "\n--- [1/3] 正在强制修复系统基础环境 ---"
                sudo rm /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock &>/dev/null
                sudo dpkg --configure -a
                sudo apt --fix-broken install -y
                
                echo -e "\n--- [2/3] 更新基础工具 ---"
                sudo apt update && sudo apt install -y git curl ca-certificates gnupg
                
                echo -e "\n--- [3/3] 修复 Docker 服务权限 ---"
                if ! command -v docker &> /dev/null; then
                    curl -fsSL https://get.docker.com | bash -
                fi
                sudo systemctl enable --now docker
                sudo systemctl start docker
                sudo chmod 666 /var/run/docker.sock
                echo -e "\n✅ 环境修复完成！"
                read -n1 -r -p "回车继续..." key
                ;;

            2)
                echo -e "\n--- 正在同步 OpenList 最新源码 ---"
                mkdir -p "$build_dir" && cd "$build_dir"
                [ -d "OpenList" ] && rm -rf OpenList
                
                git clone --depth 1 "$my_github_url"
                cd OpenList

                # 核心修复：针对 BASE_IMAGE_TAG 报错的暴力替换
                echo "正在优化 Dockerfile 变量兼容性..."
                sed -i 's/${BASE_IMAGE_TAG}/base/g' Dockerfile
                
                echo -e "\n--- 开始执行 Docker 多阶段编译 ---"
                # 显式传入 build-arg 以防万一
                sudo docker build --pull \
                    --build-arg BASE_IMAGE_TAG=base \
                    -t "$my_docker_img" .
                
                if [ $? -eq 0 ]; then
                    echo -e "\n✅ OpenList 编译成功！"
                else
                    echo -e "\n❌ 编译失败，请检查上方日志。"
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
                [ "$ol_choice" == "12" ] && echo -e "\n--- 正在尝试拉取远程镜像 ---" && sudo docker pull "$my_docker_img"
                
                echo -e "\n--- 正在清理旧容器并优化启动环境 ---"
                sudo docker rm -f openlist &>/dev/null
                
                # 确保数据目录存在并权限正确
                mkdir -p "$build_dir/data"
                sudo chmod -R 777 "$build_dir/data"
                
                echo "正在启动 OpenList 容器 (端口 5244)..."
                sudo docker run -d \
                    --name openlist \
                    -p 5244:5244 \
                    -v "$build_dir/data:/opt/openlist/data" \
                    --restart always \
                    "$my_docker_img"
                
                if [ $? -eq 0 ]; then
                    echo -e "\n✅ 启动成功！"
                    echo "------------------------------------------------"
                    echo "🔗 访问地址 (根据网络环境选择):"
                    
                    # 获取公网 IPv4
                    pub_v4=$(curl -s4 --connect-timeout 2 ifconfig.me)
                    [ -n "$pub_v4" ] && echo -e "   - 公网访问: \033[36mhttp://$pub_v4:5244\033[0m"
                    
                    # 获取内网 IPv4
                    loc_v4=$(hostname -I | awk '{print $1}')
                    echo -e "   - 局域网访问: \033[36mhttp://$loc_v4:5244\033[0m"
                    
                    # 获取全局 IPv6 (过滤 fe80)
                    loc_v6=$(ip -6 addr show | grep -E 'inet6 [23]' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
                    if [ -n "$loc_v6" ]; then
                        echo -e "   - IPv6 访问: \033[36mhttp:[$loc_v6]:5244\033[0m"
                    fi
                    
                    echo "------------------------------------------------"
                    echo "正在提取管理员凭据..."
                    sleep 5  # 等待容器内服务启动
                    
                    # 尝试从两个途径获取密码
                    # 途径1: 容器日志
                    password=$(sudo docker logs openlist 2>&1 | grep -E "password is:|Successfully generated password:" | awk -F': ' '{print $2}' | xargs)
                    
                    # 途径2: 如果日志没有，直接执行内部命令查询
                    if [ -z "$password" ]; then
                        password=$(sudo docker exec openlist ./alist admin 2>&1 | grep "admin password:" | awk -F': ' '{print $2}' | xargs)
                    fi

                    if [ -n "$password" ]; then
                        echo -e "👤 默认账号: admin"
                        echo -e "🔑 初始密码: \033[32m$password\033[0m"
                    else
                        echo -e "⚠️  提示: 未能自动抓取密码。可能已手动修改或数据库已存在。"
                        echo -e "请执行选项 14 或输入 \033[33mdocker exec openlist ./alist admin\033[0m 查看。"
                    fi
                    echo "------------------------------------------------"
                else
                    echo -e "\n❌ 启动失败，请检查 Docker 环境。"
                fi
                read -n1 -r -p "回车继续..." key
                ;;

            12)
                echo -e "--- 容器运行日志 (Ctrl+C 退出) ---"
                sudo docker logs -f --tail 100 openlist
                ;;

            13)
                echo "正在停止并移除 OpenList 相关资源..."
                sudo docker rm -f openlist &>/dev/null
                sudo docker rmi "$my_docker_img" &>/dev/null
                echo "✅ 已清理完成。"
                read -n1 -r -p "回车继续..." key
                ;;

            0) break ;;
            *) echo "无效选择"; sleep 1 ;;
        esac
    done
    ;;

86)
while true; do
    clear
    echo "------------------------------------------------"
    echo "      Backrest 资源备份工具 管理脚本"
    echo "------------------------------------------------"
    echo "【源码与镜像管理】"
    echo "1) 安装环境并修复 Docker"
    echo "2) 一键克隆源码并完整编译 (前端+后端+Docker)"
    echo "3) 登录 Docker Hub"
    echo "4) 推送镜像到 Docker Hub"
    echo "------------------------------------------------"
    echo "【容器部署管理】"
    echo "11) 部署/启动 Backrest (/home/docker/backrest)"
    echo "12) 更新镜像"
    echo "13) 备份数据"
    echo "14) 恢复备份"
    echo "15) 卸载 Backrest"

    echo "------------------------------------------------"
    echo "在rclone目录创建"
    echo "rclone.conf"
    echo "添加下面s3代码"
    echo "唯一名称r2"
    echo "[r2]
type = s3
provider = 备注名
access_key_id = 访问id
secret_access_key = 访问密钥
endpoint = s3地址"

    echo "------------------------------------------------"
    echo "0) 返回上一级"
    echo "------------------------------------------------"
    read -p "请输入操作编号: " br_choice

    my_github_url="https://github.com/zaixiangjian/backrest.git"
    my_docker_img="zaixiangjian/backrest:latest"
    build_dir="/home/docker/backrest_build"
    app_base_dir="/home/docker/backrest"
    docker_name="backrest"
    host_tz=$(cat /etc/timezone)
    host_port="9898"
    container_port="9898"
    data_volume="/data"

    case $br_choice in

    1)
        echo "修复系统环境..."
        sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock
        sudo dpkg --configure -a
        sudo apt --fix-broken install -y
        sudo apt update
        sudo apt install -y git curl ca-certificates

        if ! command -v docker &>/dev/null; then
            curl -fsSL https://get.docker.com | bash -
        fi
        sudo systemctl enable --now docker
        sudo chmod 666 /var/run/docker.sock
        echo "✅ 环境准备完成"
        read -n1 -r -p "回车继续..."
        ;;

    2)
        echo "开始完整构建流程..."

        mkdir -p "$build_dir"
        cd "$build_dir"
        [ -d backrest ] && rm -rf backrest

        git clone --depth 1 "$my_github_url" || {
            echo "❌ Git 克隆失败"
            read -n1 -r -p "回车继续..."
            break
        }

        cd backrest

        # 安装 Node 20
        if ! command -v node &>/dev/null; then
            echo "安装 Node.js 20..."
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt install -y nodejs
        fi

        # 构建前端
        echo "构建 WebUI..."
        cd webui || { echo "找不到 webui 目录"; break; }
        npm install
        npm run build

        if [ ! -d dist ]; then
            echo "❌ 前端构建失败"
            read -n1 -r -p "回车继续..."
            break
        fi

        cd ..

        # 安装 Go
        if ! command -v go &>/dev/null; then
            echo "安装 Go..."
            sudo apt install -y golang
        fi

        # 编译后端
        echo "编译 Go 二进制..."
        CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -ldflags="-s -w" -o backrest ./cmd/backrest

        if [ ! -f backrest ]; then
            echo "❌ Go 编译失败"
            read -n1 -r -p "回车继续..."
            break
        fi

        # 构建 Docker
        echo "构建 Docker 镜像..."
        sudo docker build \
            --pull \
            --no-cache \
            -t "$my_docker_img" \
            -f Dockerfile.alpine \
            .

        if [ $? -eq 0 ]; then
            echo "✅ 镜像构建成功"
        else
            echo "❌ Docker 构建失败"
        fi

        read -n1 -r -p "回车继续..."
        ;;

    3)
        sudo docker login
        read -n1 -r -p "回车继续..."
        ;;

    4)
        sudo docker push "$my_docker_img"
        read -n1 -r -p "回车继续..."
        ;;

    11)
        echo "正在部署 Backrest..."
        sudo docker rm -f $docker_name &>/dev/null

        mkdir -p "$app_base_dir/data" \
                 "$app_base_dir/config" \
                 "$app_base_dir/cache" \
                 "$app_base_dir/tmp" \
                 "$app_base_dir/rclone"


        sudo docker run -d \
            --name $docker_name \
            --hostname $docker_name \
            --restart unless-stopped \
            -v "$app_base_dir/data:/data" \
            -v "$app_base_dir/config:/config" \
            -v "$app_base_dir/cache:/cache" \
            -v "$app_base_dir/tmp:/tmp" \
            -v "$app_base_dir/rclone:/root/.config/rclone" \
            -v /home:/userdata/home \
            -e BACKREST_DATA=/data \
            -e BACKREST_CONFIG=/config/config.json \
            -e XDG_CACHE_HOME=/cache \
            -e TMPDIR=/tmp \
            -e TZ=$host_tz \
            -p "$host_port:$container_port" \
            $my_docker_img

        if [ $? -eq 0 ]; then
            ip=$(hostname -I | awk '{print $1}')
            echo "✅ 启动成功"
            echo "访问地址: http://$ip:$host_port"
        else
            echo "❌ 启动失败"
        fi
        read -n1 -r -p "回车继续..."
        ;;
    12)
        echo "正在从 Docker Hub 拉取最新镜像..."
        sudo docker pull "$my_docker_img"
        echo "✅ 更新完成"
        read -n1 -r -p "回车继续..."
        ;;
    13)
        timestamp=$(date +%Y%m%d%H%M%S)
        backup_file="/home/backrest-backup-$timestamp.tar.gz"
        echo "正在备份 $app_base_dir 到 $backup_file ..."
        tar -czvf "$backup_file" -C /home docker/backrest
        echo "✅ 备份完成: $backup_file"
        read -n1 -r -p "回车继续..."
        ;;
14)
    echo "可用备份文件列表:"
    ls -1 /home/backrest-backup-*.tar.gz
    read -p "输入要恢复的备份文件 (回车默认最新): " restore_file
    restore_file=${restore_file:-$(ls -1t /home/backrest-backup-*.tar.gz | head -n1)}
    echo "恢复备份: $restore_file ..."

    # 停止容器
    sudo docker rm -f $docker_name &>/dev/null

    # 清空原目录并恢复
    sudo rm -rf "$app_base_dir"
    mkdir -p "$app_base_dir"
    tar -xzvf "$restore_file" -C /home

    # 恢复完成后重启容器
    echo "重启 Backrest 容器..."
    sudo docker run -d \
        --name $docker_name \
        --hostname $docker_name \
        --restart unless-stopped \
        -v "$app_base_dir/data:/data" \
        -v "$app_base_dir/config:/config" \
        -v "$app_base_dir/cache:/cache" \
        -v "$app_base_dir/tmp:/tmp" \
        -v "$app_base_dir/rclone:/root/.config/rclone" \
        -v /home:/userdata/home \
        -e BACKREST_DATA=/data \
        -e BACKREST_CONFIG=/config/config.json \
        -e XDG_CACHE_HOME=/cache \
        -e TMPDIR=/tmp \
        -e TZ=$host_tz \
        -p "$host_port:$container_port" \
        $my_docker_img

    if [ $? -eq 0 ]; then
        ip=$(hostname -I | awk '{print $1}')
        echo "✅ 恢复并重启完成"
        echo "访问地址: http://$ip:$host_port"
    else
        echo "❌ 恢复后启动失败"
    fi

    read -n1 -r -p "回车继续..."
    ;;
    15)
        echo "卸载 Backrest ..."
        sudo docker rm -f $docker_name &>/dev/null
        sudo docker rmi -f $my_docker_img &>/dev/null
        sudo rm -rf "$app_base_dir"
        echo "✅ 已卸载"
        read -n1 -r -p "回车继续..."
        ;;

    0) break ;;
    *) echo "无效选择"; sleep 1 ;;
    esac
done
;;

87)
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

88)
while true; do
    clear
    echo "------------------------------------------------"
    echo "      MinIO 自编译管理脚本 (自动下载二进制)"
    echo "------------------------------------------------"
    echo "【源码与镜像管理】"
    echo "1) 安装环境并修复 Docker"
    echo "2) 一键克隆源码并准备 Docker 镜像"
    echo "3) 登录 Docker Hub"
    echo "4) 推送镜像到 Docker Hub"
    echo "------------------------------------------------"
    echo "【容器部署管理】"
    echo "11) 部署/启动 MinIO (/home/docker/minio)"
    echo "12) 更新镜像到最新版本"
    echo "13) 卸载 MinIO"
    echo "0) 返回主菜单"
    echo "------------------------------------------------"
    read -p "请输入操作编号: " ct_choice

    build_dir="/home/docker/build"
    install_dir="/home/docker/minio"
    my_github_url="https://github.com/zaixiangjian/minio.git"
    my_docker_img="zaixiangjian/minio:latest"
    TARGETARCH=amd64
    RELEASE=latest

    case $ct_choice in
        1)
            echo -e "\n--- [1/3] 修复系统基础环境 ---"
            sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock &>/dev/null
            sudo dpkg --configure -a
            sudo apt --fix-broken install -y

            echo -e "\n--- [2/3] 安装基础工具 ---"
            sudo apt update
            sudo apt install -y git curl ca-certificates build-essential make golang

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
            echo -e "\n--- 正在同步 MinIO 源码 ---"
            mkdir -p "$build_dir" && cd "$build_dir"
            [ -d "minio" ] && rm -rf minio
            git clone --depth 1 "$my_github_url"
            cd minio

            echo "--- 准备 MinIO 二进制文件 ---"
            # 检查是否存在二进制文件，如果没有则从官方 release 下载
            if [ ! -f "minio-${TARGETARCH}.${RELEASE}" ]; then
                echo "--- 从官方 MinIO 下载二进制文件 ---"
                curl -L https://dl.min.io/server/minio/release/linux-amd64/minio -o minio-${TARGETARCH}.${RELEASE}
                curl -L https://dl.min.io/server/minio/release/linux-amd64/minio.minisig -o minio-${TARGETARCH}.${RELEASE}.minisig
                curl -L https://dl.min.io/server/minio/release/linux-amd64/minio.sha256sum -o minio-${TARGETARCH}.${RELEASE}.sha256sum
                chmod +x minio-${TARGETARCH}.${RELEASE}
            fi

            echo "--- 开始 Docker 构建镜像 ---"
            sudo docker build --build-arg TARGETARCH=$TARGETARCH --build-arg RELEASE=$RELEASE -t "$my_docker_img" .

            if [ $? -eq 0 ]; then
                echo -e "\n✅ MinIO 镜像构建成功！"
            else
                echo -e "\n❌ Docker 构建失败，请检查二进制文件或 Dockerfile"
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
            echo "--- 部署/启动 MinIO ---"
            
            # 1. 交互式获取账号
            read -p "请输入 MinIO 管理员账号 (直接回车将随机生成): " input_user
            if [ -z "$input_user" ]; then
                MINIO_ROOT_USER=$(tr -dc 'A-Z0-9' </dev/urandom | head -c 20)
                echo "-> 使用随机账号: $MINIO_ROOT_USER"
            else
                MINIO_ROOT_USER=$input_user
            fi

            # 2. 交互式获取密码
            read -p "请输入 MinIO 管理员密码 (直接回车将随机生成): " input_pass
            if [ -z "$input_pass" ]; then
                MINIO_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 40)
                echo "-> 使用随机密码: $MINIO_ROOT_PASSWORD"
            else
                MINIO_ROOT_PASSWORD=$input_pass
            fi

            # 3. 执行部署
            sudo docker rm -f minio &>/dev/null
            mkdir -p "$install_dir/data"
            sudo chmod -R 777 "$install_dir/data"

            sudo docker run -d \
                --name minio \
                --restart unless-stopped \
                -p 9000:9000 \
                -p 9001:9001 \
                -v "$install_dir/data:/data" \
                -e MINIO_ROOT_USER="$MINIO_ROOT_USER" \
                -e MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD" \
                "$my_docker_img" server /data --console-address ":9001"

            if [ $? -eq 0 ]; then
                loc_v4=$(hostname -I | awk '{print $1}')
                echo "------------------------------------------------"
                echo "✅ 启动成功！"
                echo "管理界面: http://$loc_v4:9001"
                echo "API 地址: http://$loc_v4:9000"
                echo "管理员账号: $MINIO_ROOT_USER"
                echo "管理员密码: $MINIO_ROOT_PASSWORD"
                echo "------------------------------------------------"
                echo "请务必妥善保存上述信息！"
            else
                echo "❌ 启动失败，请检查 Docker 日志"
            fi
            read -n1 -r -p "回车继续..." key
            ;;

        12)
            echo "--- 拉取最新镜像 ---"
            sudo docker pull "$my_docker_img"
            echo "✅ 镜像已更新"
            read -n1 -r -p "回车继续..." key
            ;;

        13)
            echo "--- 卸载 MinIO（删除容器与镜像，保留本地数据）---"

            # 删除容器（如果存在）
            if sudo docker ps -a --format '{{.Names}}' | grep -q '^minio$'; then
                sudo docker rm -f minio
                echo "✅ 容器已删除"
            else
                echo "ℹ️ 容器不存在"
            fi

            # 删除镜像（如果存在）
            if sudo docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$my_docker_img$"; then
                sudo docker rmi "$my_docker_img"
                echo "✅ 镜像已删除"
            else
                echo "ℹ️ 镜像不存在"
            fi

            echo "📦 本地数据目录已保留：$install_dir"
            read -n1 -r -p "回车继续..." key
            ;;

        0) break ;;
        *) echo "无效选择"; sleep 1 ;;
    esac
done
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
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/CLIProxyAPI.sh)
        echo "✅ CLIProxyAPI安装完成。"
        ;;

      93)
        clear
        echo "▶️ 正在启动Sub2API安装..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/Sub2API.sh)
        echo "✅ Sub2API安装完成。"
        ;;

      94)
        clear
        echo "▶️ 正在启动Openclaw安装..."
        curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/Openclaw.sh -o /root/Openclaw.sh && chmod +x /root/Openclaw.sh && /root/Openclaw.sh
        echo "✅ Openclaw安装完成。"
        ;;

95)
    docker_name="open-webui"
    docker_img="ghcr.io/open-webui/open-webui:main"
    docker_port=3000

    # 自动获取公网IP（稳定三重备用）
    IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || hostname -I | awk '{print $1}')

    docker_rum="docker run -d \
                    --name open-webui \
                    --restart always \
                    -p ${docker_port}:8080 \
                    -v /home/docker/open-webui:/app/backend/data \
                    ${docker_img}"

    docker_describe="一个类似ChatGPT的AI网页界面，支持多模型接入和API管理。"
    docker_url="官网: https://github.com/open-webui/open-webui"

    docker_use="浏览器访问: http://${IP}:${docker_port}"
    docker_passwd="首次进入需要创建管理员账号"

    docker_app
;;


96)
    clear
    echo "=================================="
    echo "▶️ Google监控系统安装"
    echo "=================================="
    echo "888) Resend 邮件通知（2小时一次）"
    echo "999) Telegram 通知（1小时一次）"
    echo "0) 返回"
    echo "=================================="

    read -p "请输入选项: " opt

    # ==========================================
    # 888 Resend邮件通知
    # ==========================================
    if [ "$opt" = "888" ]; then

        clear
        echo "=================================="
        echo "▶️ Resend 邮件通知安装"
        echo "=================================="

        read -p "请输入备注名称: " REMARK
        read -p "请输入 Resend API Key: " RESEND_KEY
        read -p "请输入发件邮箱(From): " FROM_EMAIL
        read -p "请输入收件邮箱(To): " TO_EMAIL

        cat > /home/jiancegoogleemail.sh <<EOF
#!/bin/bash

URL="https://www.youtube.com/red"
HTML=\$(curl -s -m 10 -A "Mozilla/5.0" "\$URL")

echo "\$HTML" | grep -qiE "not available in your country|在你所在的国家/地区尚未推出"

if [ \$? -eq 0 ]; then


BODY="🏷️ 节点：美国

⚠️ YouTube Premium 区域限制触发
https://www.youtube.com/red

❗可能送中了❌更多详情查看❌
https://www.google.com/search?q=家具"




curl -s https://api.resend.com/emails \
  -H "Authorization: Bearer ${RESEND_KEY}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "from=${FROM_EMAIL}" \
  --data-urlencode "to=${TO_EMAIL}" \
  --data-urlencode "subject=[${REMARK}] YouTube 区域监控告警" \
  --data-urlencode "text=\$BODY" >/dev/null 2>&1

fi

exit 0
EOF

        chmod +x /home/jiancegoogleemail.sh

        (
            crontab -l 2>/dev/null | grep -v "jiancegoogleemail.sh"
            echo "0 */2 * * * /bin/bash -c 'sleep \$((RANDOM % 300)); /bin/bash /home/jiancegoogleemail.sh' >/dev/null 2>&1"
        ) | crontab -

        echo ""
        echo "✅ 邮件通知安装完成"
        echo "📄 脚本路径: /home/jiancegoogleemail.sh"
        echo "🏷️ 备注: ${REMARK}"
        echo "⏰ 每2小时执行一次（随机延迟0-300秒）"
    fi


    # ==========================================
    # 999 Telegram通知
    # ==========================================
    if [ "$opt" = "999" ]; then

        clear
        echo "=================================="
        echo "▶️ Telegram 通知安装"
        echo "=================================="

        read -p "请输入备注名称: " REMARK
        read -p "请输入 Bot Token: " BOT_TOKEN
        # 自动清理错误输入
        BOT_TOKEN=$(echo "$BOT_TOKEN" | sed 's#https://api.telegram.org/bot##g')
        BOT_TOKEN=$(echo "$BOT_TOKEN" | sed 's#/sendMessage##g')
        read -p "请输入 Chat ID: " CHAT_ID

        cat > /home/jiancegoogle.sh <<EOF
#!/bin/bash

URL="https://www.youtube.com/red"
HTML=\$(curl -s -m 10 -A "Mozilla/5.0" "\$URL")

echo "\$HTML" | grep -qiE "not available in your country|在你所在的国家/地区尚未推出"

if [ \$? -eq 0 ]; then

TEXT="🏷️ 节点：${REMARK}

⚠️ YouTube Premium 区域限制触发
https://www.youtube.com/red

❗可能送中了❌更多详情查看❌
https://www.google.com/search?q=家具"

curl -s -m 10 "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  --data-urlencode text="\$TEXT" >/dev/null 2>&1

fi

exit 0
EOF

        chmod +x /home/jiancegoogle.sh

        (
            crontab -l 2>/dev/null | grep -v "jiancegoogle.sh"
            echo "0 * * * * /bin/bash -c 'sleep \$((RANDOM % 300)); /bin/bash /home/jiancegoogle.sh' >/dev/null 2>&1"
        ) | crontab -

        echo ""
        echo "✅ Telegram通知安装完成"
        echo "📄 脚本路径: /home/jiancegoogle.sh"
        echo "🏷️ 备注: ${REMARK}"
        echo "⏰ 每1小时执行一次（随机延迟0-300秒）"
    fi

    if [ "$opt" = "0" ]; then
        break
    fi
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
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/yingyong/chromium.sh)
        echo "✅ 谷歌浏览器安装成功..."
        ;;

      99)
        clear
        echo "▶️ 安装hermes-agent..."
        curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/hermes_manager.sh -o /root/hermes_manager.sh && chmod +x /root/hermes_manager.sh && /root/hermes_manager.sh
        echo "✅ hermes-agent安装成功..."
        ;;

      100)
        caddy_docker_manager
        ;;

      101)
        clear
        echo "▶️ 安装agent-ai备份..."
		curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/agent-ai.sh -o /root/agent-ai.sh && chmod +x /root/agent-ai.sh && /root/agent-ai.sh
        echo "✅ agent-ai备份安装成功..."
        ;;

      102)
        clear
        echo "▶️ 安装lobehub网页版本..."
		curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/refs/heads/main/ai/lobehub.sh -o /root/lobehub.sh && chmod +x /root/lobehub.sh && /root/lobehub.sh
        echo "✅ lobehub安装成功..."
        ;;

103)
while true; do
    clear
    echo -e "▶️ Fail2Ban SSH防暴力破解"
    echo -e "${gl_kjlan}------------------------"

    fail2ban_conf="/home/docker/fail2ban/config/fail2ban/jail.d/sshd.local"

    if [ -f "$fail2ban_conf" ]; then
        echo -e "${gl_lv}已配置${gl_bai}"
        echo -e "${gl_lv}Fail2Ban SSH防暴力破解已配置完成${gl_bai}"

        conf_ssh_port=$(grep -E '^[[:space:]]*port[[:space:]]*=' "$fail2ban_conf" 2>/dev/null | tail -n1 | awk -F= '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
        conf_maxretry=$(grep -E '^[[:space:]]*maxretry[[:space:]]*=' "$fail2ban_conf" 2>/dev/null | tail -n1 | awk -F= '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
        conf_findtime=$(grep -E '^[[:space:]]*findtime[[:space:]]*=' "$fail2ban_conf" 2>/dev/null | tail -n1 | awk -F= '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
        conf_bantime=$(grep -E '^[[:space:]]*bantime[[:space:]]*=' "$fail2ban_conf" 2>/dev/null | tail -n1 | awk -F= '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')

        echo "SSH端口: ${conf_ssh_port:-未知}"
        echo "失败次数: ${conf_maxretry:-未知}"
        echo "统计窗口: ${conf_findtime:-未知}"
        echo "封禁时长: ${conf_bantime:-未知}"
        echo "配置文件: $fail2ban_conf"
        echo "查看状态: docker exec fail2ban fail2ban-client status sshd"

        if docker inspect fail2ban &>/dev/null; then
            container_status=$(docker inspect -f '{{.State.Status}}' fail2ban 2>/dev/null)

            if [ "$container_status" = "running" ]; then
                if docker exec fail2ban fail2ban-client status sshd &>/dev/null; then
                    echo -e "Fail2Ban状态: ${gl_lv}运行正常${gl_bai}"
                else
                    echo -e "Fail2Ban状态: ${gl_hong}异常${gl_bai}"
                fi
            else
                echo -e "Fail2Ban容器: ${gl_hong}${container_status:-不存在}${gl_bai}"
            fi
        fi

        echo -e "${gl_kjlan}------------------------${gl_bai}"
    fi

    echo -e "${gl_kjlan}1.   ${gl_bai}使用 Docker 安装到 /home/docker/fail2ban"
    echo -e "${gl_kjlan}2.   ${gl_bai}更新"
    echo -e "${gl_kjlan}3.   ${gl_bai}配置 SSH 防暴力破解"
    echo -e "${gl_kjlan}4.   ${gl_bai}查看成功统计 TOP50"
    echo -e "${gl_kjlan}5.   ${gl_bai}查看失败统计 TOP50"
    echo -e "${gl_kjlan}6.   ${gl_bai}卸载"
    echo -e "${gl_kjlan}7.   ${gl_bai}查看封禁的IP"
    echo -e "${gl_kjlan}8.   ${gl_bai}查看/管理白名单"
    echo -e "${gl_kjlan}9.   ${gl_bai}查看日志占用/手动清理"
    echo -e "${gl_kjlan}0.   ${gl_bai}返回上一级"
    echo -e "${gl_kjlan}------------------------${gl_bai}"

    read -e -p "请输入你的选择: " fail2ban_choice

    case $fail2ban_choice in

        1)
            clear

            if [ "$EUID" -ne 0 ]; then
                echo -e "${gl_hong}请使用 root 用户运行安装。${gl_bai}"
                read -n1 -r -p "按任意键继续..."
                continue
            fi

            echo "▶️ 使用 Docker 安装 Fail2Ban 到 /home/docker/fail2ban ..."
            install_docker

            # Debian/Ubuntu 启用 rsyslog，让 SSH 日志持续写入 /var/log/auth.log，并限制 auth.log 大小
            if command -v apt &>/dev/null; then
                install rsyslog logrotate
                systemctl start rsyslog >/dev/null 2>&1 || true
                systemctl enable rsyslog >/dev/null 2>&1 || true
                touch /var/log/auth.log
                cat > /etc/logrotate.d/authlog-ssh <<EOF
/var/log/auth.log {
    daily
    rotate 7
    size 20M
    missingok
    notifempty
    compress
    delaycompress
    create 0640 syslog adm
    sharedscripts
    postrotate
        systemctl reload rsyslog >/dev/null 2>&1 || true
    endscript
}
EOF
            fi

            mkdir -p /home/docker/fail2ban/config/fail2ban/jail.d
            mkdir -p /home/docker/fail2ban/config/fail2ban/filter.d
            mkdir -p /home/docker/fail2ban/config/fail2ban/action.d
            mkdir -p /home/docker/fail2ban/log

            install logrotate

            cat > /etc/logrotate.d/fail2ban-docker <<EOF
/home/docker/fail2ban/log/*.log /home/docker/fail2ban/log/*/*.log {
    daily
    rotate 7
    size 10M
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
}
EOF

            echo "清理可能导致配置冲突的旧自定义配置..."

            rm -f /home/docker/fail2ban/config/fail2ban/jail.d/sshd.conf
            rm -f /home/docker/fail2ban/config/fail2ban/jail.d/sshd.local

            if docker inspect fail2ban &>/dev/null; then
                echo -e "${gl_huang}检测到 fail2ban 容器已存在，删除旧容器后重新创建...${gl_bai}"
                docker rm -f fail2ban >/dev/null 2>&1 || true
            fi

            echo "创建 Fail2Ban Docker 容器..."

            docker run -d \
                --name=fail2ban \
                --net=host \
                --cap-add=NET_ADMIN \
                --cap-add=NET_RAW \
                -e PUID=0 \
                -e PGID=0 \
                -e TZ=Etc/UTC \
                -e VERBOSITY=-v \
                -v /home/docker/fail2ban/config:/config \
                -v /home/docker/fail2ban/log:/config/log/fail2ban \
                -v /var/log:/var/log:ro \
                -v /run/log/journal:/run/log/journal:ro \
                -v /var/log/journal:/var/log/journal:ro \
                -v /etc/machine-id:/etc/machine-id:ro \
                --restart unless-stopped \
                --log-opt max-size=10m \
                --log-opt max-file=3 \
                lscr.io/linuxserver/fail2ban:latest

            if [ $? -ne 0 ]; then
                echo -e "${gl_hong}Fail2Ban Docker 容器创建失败。${gl_bai}"
                read -n1 -r -p "按任意键继续..."
                continue
            fi

            sleep 5

            echo "------------------------"
            echo -e "${gl_lv}Docker Fail2Ban 安装完成${gl_bai}"
            echo "本地目录: /home/docker/fail2ban"
            echo "容器映射: /home/docker/fail2ban/config -> /config"
            echo "容器日志: /home/docker/fail2ban/log"
            echo "SSH日志: /var/log/auth.log 或 /var/log/secure（容器只读读取 /var/log）"
            echo "日志限制: auth.log 20M×7压缩，Fail2Ban日志 10M×7压缩，Docker日志 10M×3"
            echo "下一步: 进入 3 配置 SSH 防暴力破解"

            if docker exec fail2ban fail2ban-client ping &>/dev/null; then
                echo -e "Fail2Ban服务: ${gl_lv}正常${gl_bai}"
            else
                echo -e "Fail2Ban服务: ${gl_hong}尚未正常启动${gl_bai}"
                echo "可以查看:"
                echo "docker logs --tail 100 fail2ban"
            fi

            read -n1 -r -p "按任意键继续..."
            ;;

        2)
            clear

            if [ "$EUID" -ne 0 ]; then
                echo -e "${gl_hong}请使用 root 用户运行更新。${gl_bai}"
                read -n1 -r -p "按任意键继续..."
                continue
            fi

            echo "▶️ 更新 Fail2Ban Docker 镜像..."

            install_docker

            # Debian/Ubuntu 启用 rsyslog，让 SSH 日志持续写入 /var/log/auth.log，并限制 auth.log 大小
            if command -v apt &>/dev/null; then
                install rsyslog logrotate
                systemctl start rsyslog >/dev/null 2>&1 || true
                systemctl enable rsyslog >/dev/null 2>&1 || true
                touch /var/log/auth.log
                cat > /etc/logrotate.d/authlog-ssh <<EOF
/var/log/auth.log {
    daily
    rotate 7
    size 20M
    missingok
    notifempty
    compress
    delaycompress
    create 0640 syslog adm
    sharedscripts
    postrotate
        systemctl reload rsyslog >/dev/null 2>&1 || true
    endscript
}
EOF
            fi

            mkdir -p /home/docker/fail2ban/config/fail2ban/jail.d
            mkdir -p /home/docker/fail2ban/config/fail2ban/filter.d
            mkdir -p /home/docker/fail2ban/config/fail2ban/action.d
            mkdir -p /home/docker/fail2ban/log

            install logrotate

            cat > /etc/logrotate.d/fail2ban-docker <<EOF
/home/docker/fail2ban/log/*.log /home/docker/fail2ban/log/*/*.log {
    daily
    rotate 7
    size 10M
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
}
EOF

            echo "拉取最新 Fail2Ban 镜像..."

            docker pull lscr.io/linuxserver/fail2ban:latest

            echo "停止旧容器..."

            docker rm -f fail2ban >/dev/null 2>&1 || true

            echo "保留现有 SSH 防护配置，避免更新后需要重新配置..."

            echo "重新创建 Fail2Ban..."

            docker run -d \
                --name=fail2ban \
                --net=host \
                --cap-add=NET_ADMIN \
                --cap-add=NET_RAW \
                -e PUID=0 \
                -e PGID=0 \
                -e TZ=Etc/UTC \
                -e VERBOSITY=-v \
                -v /home/docker/fail2ban/config:/config \
                -v /home/docker/fail2ban/log:/config/log/fail2ban \
                -v /var/log:/var/log:ro \
                -v /run/log/journal:/run/log/journal:ro \
                -v /var/log/journal:/var/log/journal:ro \
                -v /etc/machine-id:/etc/machine-id:ro \
                --restart unless-stopped \
                --log-opt max-size=10m \
                --log-opt max-file=3 \
                lscr.io/linuxserver/fail2ban:latest

            sleep 5

            echo "------------------------"
            echo -e "${gl_lv}Fail2Ban 更新完成${gl_bai}"
            echo "原配置目录保留: /home/docker/fail2ban"

            if docker exec fail2ban fail2ban-client ping &>/dev/null; then
                echo -e "Fail2Ban服务: ${gl_lv}正常${gl_bai}"
            else
                echo -e "Fail2Ban服务: ${gl_hong}异常${gl_bai}"
                echo "查看日志:"
                echo "docker logs --tail 100 fail2ban"
            fi

            read -n1 -r -p "按任意键继续..."
            ;;

        3)
            clear

            if [ "$EUID" -ne 0 ]; then
                echo -e "${gl_hong}请使用 root 用户运行配置。${gl_bai}"
                read -n1 -r -p "按任意键继续..."
                continue
            fi

            if ! docker inspect fail2ban &>/dev/null; then
                echo -e "${gl_hong}未检测到 fail2ban 容器，请先选择 1 安装。${gl_bai}"
                read -n1 -r -p "按任意键继续..."
                continue
            fi

            echo "▶️ 配置 Fail2Ban SSH 防暴力破解..."
            echo "说明: SSH 登录失败次数过多会自动封禁来源 IP。"
            echo "------------------------"

            # 检测 SSH 端口
            detected_port=""

            if [ -f /etc/ssh/sshd_config ]; then
                detected_port=$(awk '
                    /^[[:space:]]*Port[[:space:]]+[0-9]+/ {
                        port=$2
                    }
                    END {
                        print port
                    }
                ' /etc/ssh/sshd_config 2>/dev/null)
            fi

            if [ -z "$detected_port" ]; then
                detected_port=$(ss -ltnp 2>/dev/null | awk '
                    /sshd/ {
                        split($4,a,":")
                        print a[length(a)]
                        exit
                    }
                ')
            fi

            detected_port=${detected_port:-22}

            read -e -p "请输入SSH端口 [默认: ${detected_port}]: " ssh_port
            ssh_port=${ssh_port:-$detected_port}

            if ! echo "$ssh_port" | grep -Eq '^[0-9]+$' || \
               [ "$ssh_port" -lt 1 ] || \
               [ "$ssh_port" -gt 65535 ]; then

                echo -e "${gl_hong}端口无效，请输入 1-65535。${gl_bai}"
                read -n1 -r -p "按任意键继续..."
                continue
            fi

            read -e -p "失败多少次后封禁 [默认: 5]: " maxretry
            maxretry=${maxretry:-5}

            if ! echo "$maxretry" | grep -Eq '^[0-9]+$' || [ "$maxretry" -lt 1 ]; then
                echo -e "${gl_hong}次数无效，已使用默认 5。${gl_bai}"
                maxretry=5
            fi

            read -e -p "统计时间窗口，例如 10m/1h [默认: 1h]: " findtime
            findtime=${findtime:-1h}

            read -e -p "封禁时长，例如 1d/12h/-1永久 [默认: 7d]: " bantime
            bantime=${bantime:-7d}

            # 获取当前服务器 IPv4
            current_ip=$(hostname -I 2>/dev/null | awk '{print $1}')

            echo
            echo "当前服务器IP: ${current_ip:-未知}"

            read -e -p "额外需要白名单的IP，可留空: " extra_ignoreip

            # 生成白名单
            ignoreip="127.0.0.1/8 ::1"

            if [ -n "$current_ip" ]; then
                ignoreip="$ignoreip $current_ip"
            fi

            if [ -n "$extra_ignoreip" ]; then
                ignoreip="$ignoreip $extra_ignoreip"
            fi

            mkdir -p /home/docker/fail2ban/config/fail2ban/jail.d
            mkdir -p /home/docker/fail2ban/config/fail2ban/filter.d
            mkdir -p /home/docker/fail2ban/config/fail2ban/action.d

            # Docker 容器内不稳定使用 backend=systemd，统一转成文件日志读取。
            # 如果系统没有 /var/log/auth.log 或 /var/log/secure，就把 journalctl -u ssh 最近7天导出到本地文件给容器读取。
            log_source_desc=""
            logpath_line=""
            if [ -f /var/log/auth.log ]; then
                logpath_line="logpath = /var/log/auth.log"
                log_source_desc="/var/log/auth.log"
            elif [ -f /var/log/secure ]; then
                logpath_line="logpath = /var/log/secure"
                log_source_desc="/var/log/secure"
            else
                echo -e "${gl_hong}未检测到 /var/log/auth.log 或 /var/log/secure。${gl_bai}"
                echo "Debian/Ubuntu 请先确认 rsyslog 是否已生成 /var/log/auth.log："
                echo "systemctl status rsyslog && ls -l /var/log/auth.log"
                read -n1 -r -p "按任意键继续..."
                continue
            fi

            cat > /home/docker/fail2ban/config/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = ${ignoreip}
bantime = ${bantime}
findtime = ${findtime}
maxretry = ${maxretry}
backend = auto
banaction = iptables-multiport
banaction_allports = iptables-allports
EOF

            # SSH Filter
            cat > /home/docker/fail2ban/config/fail2ban/filter.d/sshd.local <<'EOF'
[Definition]
failregex = ^.*sshd.*Failed password for .* from <HOST>(?: port \d+)?(?: ssh\d*)?.*$
            ^.*sshd.*Invalid user .* from <HOST>(?: port \d+)?.*$
            ^.*sshd.*authentication failure.*rhost=<HOST>.*$
ignoreregex =
EOF

            # 只启用 SSH
            cat > /home/docker/fail2ban/config/fail2ban/jail.d/sshd.local <<EOF
[sshd]
enabled = true
port = ${ssh_port}
filter = sshd
backend = auto
${logpath_line}
maxretry = ${maxretry}
findtime = ${findtime}
bantime = ${bantime}
ignoreip = ${ignoreip}
action = iptables-multiport[name=sshd, port="${ssh_port}", protocol=tcp]
EOF

            echo
            echo "正在重启 Fail2Ban..."

            docker restart fail2ban >/dev/null 2>&1

            sleep 5

            echo "------------------------"

            # 检查 Fail2Ban 主服务
            if ! docker exec fail2ban fail2ban-client ping &>/dev/null; then
                echo -e "${gl_hong}Fail2Ban 服务启动失败！${gl_bai}"
                echo
                echo "最近错误日志:"
                docker logs fail2ban 2>&1 | grep -iE "error|critical|failed|traceback|unable|permission" | tail -n 80
                echo "最近完整日志:"
                docker logs --tail 80 fail2ban
                echo
                echo "配置文件:"
                cat /home/docker/fail2ban/config/fail2ban/jail.d/sshd.local

                read -n1 -r -p "按任意键继续..."
                continue
            fi

            # 检查 SSH jail
            if docker exec fail2ban fail2ban-client status sshd &>/dev/null; then

                echo -e "${gl_lv}Fail2Ban SSH防暴力破解配置成功${gl_bai}"
                echo
                echo "SSH端口: ${ssh_port}"
                echo "失败次数: ${maxretry}"
                echo "统计窗口: ${findtime}"
                echo "封禁时长: ${bantime}"
                echo "白名单: ${ignoreip}"
                echo "日志来源: ${log_source_desc}"
                echo "配置文件: /home/docker/fail2ban/config/fail2ban/jail.d/sshd.local"
                echo
                echo "Fail2Ban状态:"
                docker exec fail2ban fail2ban-client status sshd

            else

                echo -e "${gl_hong}Fail2Ban服务运行，但 sshd jail 启动失败！${gl_bai}"
                echo
                docker logs --tail 50 fail2ban

            fi

            read -n1 -r -p "按任意键继续..."
            ;;

        4)
            clear

            echo "▶️ SSH 登录成功来源统计 TOP 50"
            echo "说明: 只统计最近7天 SSH 登录成功来源 IP，成功次数多的优先显示。"
            echo "------------------------"

            tmp_ssh_stats=$(mktemp)
            tmp_ssh_table=$(mktemp)

            if command -v journalctl &>/dev/null; then
                journalctl -u ssh --since "7 days ago" --no-pager 2>/dev/null \
                    | grep -E 'sshd.*(Accepted|Failed password|Invalid user|authentication failure)' \
                    > "$tmp_ssh_stats"
            fi

            if [ ! -s "$tmp_ssh_stats" ] && command -v journalctl &>/dev/null; then
                journalctl -u sshd --since "7 days ago" --no-pager 2>/dev/null \
                    | grep -E 'sshd.*(Accepted|Failed password|Invalid user|authentication failure)' \
                    > "$tmp_ssh_stats"
            fi

            fail2ban_conf="/home/docker/fail2ban/config/fail2ban/jail.d/sshd.local"
            whitelist=""
            if [ -f "$fail2ban_conf" ]; then
                whitelist=$(grep -E '^[[:space:]]*ignoreip[[:space:]]*=' "$fail2ban_conf" 2>/dev/null | tail -n1 | cut -d= -f2- | xargs)
            fi

            banned_ips=""
            if docker inspect fail2ban &>/dev/null && \
               docker exec fail2ban fail2ban-client ping &>/dev/null && \
               docker exec fail2ban fail2ban-client status sshd &>/dev/null; then
                banned_ips=$(docker exec fail2ban fail2ban-client get sshd banip 2>/dev/null || true)
                if [ -z "$banned_ips" ]; then
                    banned_ips=$(docker exec fail2ban fail2ban-client status sshd 2>/dev/null | sed -n 's/^.*Banned IP list:[[:space:]]*//p')
                fi
            fi

            awk '
            {
                ip=""; type=""
                if ($0 ~ /Accepted/) {
                    for (i=1; i<=NF; i++) if ($i == "from") { ip=$(i+1); type="ok"; break }
                } else if ($0 ~ /Failed password/ || $0 ~ /Invalid user/) {
                    for (i=1; i<=NF; i++) if ($i == "from") { ip=$(i+1); type="fail"; break }
                } else if ($0 ~ /authentication failure/) {
                    for (i=1; i<=NF; i++) if ($i ~ /^rhost=/) { ip=$i; sub(/^rhost=/, "", ip); type="fail"; break }
                }
                if (ip != "") {
                    gsub(/[^0-9A-Fa-f:.]/, "", ip)
                    if (type == "ok") success[ip]++
                    else if (type == "fail") failed[ip]++
                }
            }
            END {
                for (ip in success) {
                    if (success[ip] > 0) printf "%s %d %d %d\n", ip, success[ip]+0, failed[ip]+0, success[ip]+failed[ip]
                }
            }' "$tmp_ssh_stats" | sort -k2,2nr -k4,4nr | head -50 > "$tmp_ssh_table"

            printf "%-20s %-8s %-8s %-8s %s\n" "IP" "成功" "失败" "总计" "状态"
            echo "------------------------------------------------"

            if [ ! -s "$tmp_ssh_table" ]; then
                echo -e "${gl_huang}最近7天没有统计到 SSH 成功登录记录。${gl_bai}"
            else
                while read -r stat_ip stat_ok stat_fail stat_total; do
                    if echo " $whitelist " | grep -Fqw -- "$stat_ip"; then
                        stat_status="${gl_lv}白名单${gl_bai}"
                    elif echo " $banned_ips " | grep -Fqw -- "$stat_ip"; then
                        stat_status="${gl_hong}已封禁${gl_bai}"
                    else
                        stat_status="${gl_huang}未封禁${gl_bai}"
                    fi
                    printf "%-20s %-8s %-8s %-8s %b\n" "$stat_ip" "${stat_ok}次" "${stat_fail}次" "${stat_total}次" "$stat_status"
                done < "$tmp_ssh_table"
            fi

            rm -f "$tmp_ssh_stats" "$tmp_ssh_table"

            echo "------------------------------------------------"
            echo "说明: 这是日志统计，不会修改或清除日志。"
            echo "日志保留时间取决于 systemd-journald 策略。"

            if docker inspect fail2ban &>/dev/null; then
                if docker exec fail2ban fail2ban-client ping &>/dev/null; then
                    if docker exec fail2ban fail2ban-client status sshd &>/dev/null; then
                        echo "Fail2Ban容器状态:"
                        docker exec fail2ban fail2ban-client status sshd
                    else
                        echo -e "${gl_hong}Fail2Ban运行，但 sshd jail 未启动。${gl_bai}"
                    fi
                else
                    echo -e "${gl_hong}Fail2Ban服务未正常运行。${gl_bai}"
                fi
            fi

            read -n1 -r -p "按任意键继续..."
            ;;

        5)
            clear

            echo "▶️ SSH 登录来源统计 TOP 50"
            echo "说明: 统计最近7天 SSH 登录成功/失败来源 IP。"
            echo "------------------------"

            tmp_ssh_stats=$(mktemp)
            tmp_ssh_table=$(mktemp)

            if command -v journalctl &>/dev/null; then
                journalctl -u ssh --since "7 days ago" --no-pager 2>/dev/null \
                    | grep -E 'sshd.*(Accepted|Failed password|Invalid user|authentication failure)' \
                    > "$tmp_ssh_stats"
            fi

            if [ ! -s "$tmp_ssh_stats" ] && command -v journalctl &>/dev/null; then
                journalctl -u sshd --since "7 days ago" --no-pager 2>/dev/null \
                    | grep -E 'sshd.*(Accepted|Failed password|Invalid user|authentication failure)' \
                    > "$tmp_ssh_stats"
            fi

            fail2ban_conf="/home/docker/fail2ban/config/fail2ban/jail.d/sshd.local"
            whitelist=""
            if [ -f "$fail2ban_conf" ]; then
                whitelist=$(grep -E '^[[:space:]]*ignoreip[[:space:]]*=' "$fail2ban_conf" 2>/dev/null | tail -n1 | cut -d= -f2- | xargs)
            fi

            banned_ips=""
            if docker inspect fail2ban &>/dev/null && \
               docker exec fail2ban fail2ban-client ping &>/dev/null && \
               docker exec fail2ban fail2ban-client status sshd &>/dev/null; then
                banned_ips=$(docker exec fail2ban fail2ban-client get sshd banip 2>/dev/null || true)
                if [ -z "$banned_ips" ]; then
                    banned_ips=$(docker exec fail2ban fail2ban-client status sshd 2>/dev/null | sed -n 's/^.*Banned IP list:[[:space:]]*//p')
                fi
            fi

            awk '
            {
                ip=""; type=""
                if ($0 ~ /Accepted/) {
                    for (i=1; i<=NF; i++) if ($i == "from") { ip=$(i+1); type="ok"; break }
                } else if ($0 ~ /Failed password/ || $0 ~ /Invalid user/) {
                    for (i=1; i<=NF; i++) if ($i == "from") { ip=$(i+1); type="fail"; break }
                } else if ($0 ~ /authentication failure/) {
                    for (i=1; i<=NF; i++) if ($i ~ /^rhost=/) { ip=$i; sub(/^rhost=/, "", ip); type="fail"; break }
                }
                if (ip != "") {
                    gsub(/[^0-9A-Fa-f:.]/, "", ip)
                    if (type == "ok") success[ip]++
                    else if (type == "fail") failed[ip]++
                }
            }
            END {
                for (ip in failed) {
                    if (failed[ip] > 0) printf "%s %d %d %d\n", ip, success[ip]+0, failed[ip]+0, success[ip]+failed[ip]
                }
            }' "$tmp_ssh_stats" | sort -k3,3nr -k4,4nr | head -50 > "$tmp_ssh_table"

            printf "%-20s %-8s %-8s %-8s %s\n" "IP" "成功" "失败" "总计" "状态"
            echo "------------------------------------------------"

            if [ ! -s "$tmp_ssh_table" ]; then
                echo -e "${gl_huang}最近7天没有统计到 SSH 失败登录记录。${gl_bai}"
            else
                while read -r stat_ip stat_ok stat_fail stat_total; do
                    if echo " $whitelist " | grep -Fqw -- "$stat_ip"; then
                        stat_status="${gl_lv}白名单${gl_bai}"
                    elif echo " $banned_ips " | grep -Fqw -- "$stat_ip"; then
                        stat_status="${gl_hong}已封禁${gl_bai}"
                    else
                        stat_status="${gl_huang}未封禁${gl_bai}"
                    fi
                    printf "%-20s %-8s %-8s %-8s %b\n" "$stat_ip" "${stat_ok}次" "${stat_fail}次" "${stat_total}次" "$stat_status"
                done < "$tmp_ssh_table"
            fi

            rm -f "$tmp_ssh_stats" "$tmp_ssh_table"

            echo "------------------------------------------------"
            echo "说明: 这是日志统计，不会修改或清除日志。"
            echo "日志保留时间取决于 systemd-journald 策略。"

            if docker inspect fail2ban &>/dev/null; then
                if docker exec fail2ban fail2ban-client ping &>/dev/null; then
                    if docker exec fail2ban fail2ban-client status sshd &>/dev/null; then
                        echo "Fail2Ban容器状态:"
                        docker exec fail2ban fail2ban-client status sshd
                    else
                        echo -e "${gl_hong}Fail2Ban运行，但 sshd jail 未启动。${gl_bai}"
                    fi
                else
                    echo -e "${gl_hong}Fail2Ban服务未正常运行。${gl_bai}"
                fi
            fi

            read -n1 -r -p "按任意键继续..."
            ;;

        6)
            clear

            if [ "$EUID" -ne 0 ]; then
                echo -e "${gl_hong}请使用 root 用户运行卸载。${gl_bai}"
                read -n1 -r -p "按任意键继续..."
                continue
            fi

            read -e -p "确定卸载 Fail2Ban 并删除 /home/docker/fail2ban 吗？(Y/N): " confirm

            case "$confirm" in

                [Yy])
                    docker rm -f fail2ban >/dev/null 2>&1 || true
                    rm -rf /home/docker/fail2ban
                    rm -f /etc/logrotate.d/fail2ban-docker
                    rm -f /etc/logrotate.d/authlog-ssh

                    echo -e "${gl_lv}Fail2Ban 已卸载，配置目录已删除。${gl_bai}"
                    ;;

                *)
                    echo "已取消卸载"
                    ;;

            esac

            read -n1 -r -p "按任意键继续..."
            ;;

        7)
            while true; do
                clear
                echo "▶️ 当前封禁的 IP"
                echo "------------------------"
                echo "失败多优先显示"
                echo "------------------------"

                banned_ips=""
                banned_display_ips=""
                fail2ban_conf="/home/docker/fail2ban/config/fail2ban/jail.d/sshd.local"
                whitelist=""
                if [ -f "$fail2ban_conf" ]; then
                    whitelist=$(grep -E '^[[:space:]]*ignoreip[[:space:]]*=' "$fail2ban_conf" 2>/dev/null | tail -n1 | cut -d= -f2- | xargs)
                fi

                tmp_ssh_stats=$(mktemp)
                tmp_ip_stats=$(mktemp)
                tmp_banned_table=$(mktemp)
                tmp_banned_sorted=$(mktemp)

                if command -v journalctl &>/dev/null; then
                    journalctl -u ssh --since "7 days ago" --no-pager 2>/dev/null \
                        | grep -E 'sshd.*(Accepted|Failed password|Invalid user|authentication failure)' \
                        > "$tmp_ssh_stats"
                fi
                if [ ! -s "$tmp_ssh_stats" ] && command -v journalctl &>/dev/null; then
                    journalctl -u sshd --since "7 days ago" --no-pager 2>/dev/null \
                        | grep -E 'sshd.*(Accepted|Failed password|Invalid user|authentication failure)' \
                        > "$tmp_ssh_stats"
                fi

                awk '
                {
                    ip=""; type=""
                    if ($0 ~ /Accepted/) {
                        for (i=1; i<=NF; i++) if ($i == "from") { ip=$(i+1); type="ok"; break }
                    } else if ($0 ~ /Failed password/ || $0 ~ /Invalid user/) {
                        for (i=1; i<=NF; i++) if ($i == "from") { ip=$(i+1); type="fail"; break }
                    } else if ($0 ~ /authentication failure/) {
                        for (i=1; i<=NF; i++) if ($i ~ /^rhost=/) { ip=$i; sub(/^rhost=/, "", ip); type="fail"; break }
                    }
                    if (ip != "") {
                        gsub(/[^0-9A-Fa-f:.]/, "", ip)
                        if (type == "ok") success[ip]++
                        else if (type == "fail") failed[ip]++
                    }
                }
                END {
                    for (ip in success) seen[ip]=1
                    for (ip in failed) seen[ip]=1
                    for (ip in seen) printf "%s %d %d %d\n", ip, success[ip]+0, failed[ip]+0, success[ip]+failed[ip]
                }' "$tmp_ssh_stats" > "$tmp_ip_stats"

                if ! docker inspect fail2ban &>/dev/null; then
                    echo -e "${gl_hong}未检测到 fail2ban 容器。${gl_bai}"
                elif ! docker exec fail2ban fail2ban-client ping &>/dev/null; then
                    echo -e "${gl_hong}Fail2Ban 服务未正常运行。${gl_bai}"
                elif ! docker exec fail2ban fail2ban-client status sshd &>/dev/null; then
                    echo -e "${gl_hong}sshd jail 未启动，请先选择 3 配置。${gl_bai}"
                else
                    banned_ips=$(docker exec fail2ban fail2ban-client get sshd banip 2>/dev/null || true)
                    if [ -z "$banned_ips" ]; then
                        banned_ips=$(docker exec fail2ban fail2ban-client status sshd 2>/dev/null | sed -n 's/^.*Banned IP list:[[:space:]]*//p')
                    fi

                    printf "%-20s %-8s %-8s %-8s\n" "IP" "成功" "失败" "总计"
                    echo "------------------------------------------------"

                    if [ -z "$banned_ips" ]; then
                        echo "当前没有封禁IP"
                    else
                        for ip in $banned_ips; do
                            awk -v qip="$ip" '
                                $1 == qip { print $0; found=1 }
                                END { if (!found) print qip " 0 0 0" }
                            ' "$tmp_ip_stats" >> "$tmp_banned_table"
                        done
                        sort -k3,3nr -k4,4nr "$tmp_banned_table" > "$tmp_banned_sorted"
                        i=1
                        while read -r stat_ip stat_ok stat_fail stat_total; do
                            printf "%s. %-17s %-8s %-8s %-8s\n" "$i" "$stat_ip" "${stat_ok}次" "${stat_fail}次" "${stat_total}次"
                            banned_display_ips="$banned_display_ips $stat_ip"
                            i=$((i + 1))
                        done < "$tmp_banned_sorted"
                    fi
                fi

                rm -f "$tmp_ssh_stats" "$tmp_ip_stats" "$tmp_banned_table" "$tmp_banned_sorted"

                echo "------------------------"
                echo "1. 添加封禁IP"
                echo "2. 删除封禁IP"
                echo "0. 退出"
                echo "------------------------"
                read -e -p "请输入你的选择: " banned_choice
                case "$banned_choice" in
                    1)
                        if ! docker inspect fail2ban &>/dev/null || \
                           ! docker exec fail2ban fail2ban-client ping &>/dev/null || \
                           ! docker exec fail2ban fail2ban-client status sshd &>/dev/null; then
                            echo -e "${gl_hong}Fail2Ban 或 sshd jail 未正常运行，无法添加封禁。${gl_bai}"
                            read -n1 -r -p "按任意键继续..."
                            continue
                        fi
                        read -e -p "请输入要添加封禁的IP: " add_ban_ip
                        if [ -z "$add_ban_ip" ]; then
                            echo "未输入IP"
                        elif echo " $whitelist " | grep -Fqw -- "$add_ban_ip"; then
                            echo -e "${gl_huang}此IP在白名单配置中，白名单优先，无法添加封禁: $add_ban_ip${gl_bai}"
                        else
                            docker exec fail2ban fail2ban-client set sshd banip "$add_ban_ip" >/dev/null 2>&1
                            if [ $? -eq 0 ]; then
                                echo -e "${gl_lv}已添加封禁: $add_ban_ip${gl_bai}"
                            else
                                echo -e "${gl_hong}添加封禁失败: $add_ban_ip${gl_bai}"
                            fi
                        fi
                        read -n1 -r -p "按任意键继续..."
                        ;;
                    2)
                        if ! docker inspect fail2ban &>/dev/null || \
                           ! docker exec fail2ban fail2ban-client ping &>/dev/null || \
                           ! docker exec fail2ban fail2ban-client status sshd &>/dev/null; then
                            echo -e "${gl_hong}Fail2Ban 或 sshd jail 未正常运行，无法删除封禁。${gl_bai}"
                            read -n1 -r -p "按任意键继续..."
                            continue
                        fi
                        read -e -p "请输入要删除封禁的IP或序号: " del_ban_input
                        del_ban_ip=""
                        if echo "$del_ban_input" | grep -Eq '^[0-9]+$'; then
                            i=1
                            for ip in $banned_display_ips; do
                                if [ "$i" = "$del_ban_input" ]; then
                                    del_ban_ip="$ip"
                                    break
                                fi
                                i=$((i + 1))
                            done
                        else
                            del_ban_ip="$del_ban_input"
                        fi
                        if [ -z "$del_ban_ip" ]; then
                            echo "未找到该封禁IP"
                        else
                            docker exec fail2ban fail2ban-client set sshd unbanip "$del_ban_ip" >/dev/null 2>&1
                            if [ $? -eq 0 ]; then
                                echo -e "${gl_lv}已删除封禁: $del_ban_ip${gl_bai}"
                            else
                                echo -e "${gl_hong}删除封禁失败: $del_ban_ip${gl_bai}"
                            fi
                        fi
                        read -n1 -r -p "按任意键继续..."
                        ;;
                    0) break ;;
                    *) echo "无效选择"; read -n1 -r -p "按任意键继续..." ;;
                esac
            done
            ;;

        8)
            while true; do
                clear
                echo "▶️ Fail2Ban SSH 白名单"
                echo "------------------------"
                echo "成功多优先显示"
                echo "------------------------"
                fail2ban_conf="/home/docker/fail2ban/config/fail2ban/jail.d/sshd.local"
                fail2ban_default_conf="/home/docker/fail2ban/config/fail2ban/jail.local"
                if [ ! -f "$fail2ban_conf" ]; then
                    echo -e "${gl_hong}未找到配置文件，请先选择 3 配置 SSH 防暴力破解。${gl_bai}"
                    read -n1 -r -p "按任意键继续..."
                    break
                fi
                whitelist=$(grep -E '^[[:space:]]*ignoreip[[:space:]]*=' "$fail2ban_conf" 2>/dev/null | tail -n1 | cut -d= -f2- | xargs)
                whitelist=${whitelist:-127.0.0.1/8 ::1}
                whitelist_display_ips=""

                tmp_ssh_stats=$(mktemp)
                tmp_ip_stats=$(mktemp)
                tmp_whitelist_table=$(mktemp)
                tmp_whitelist_sorted=$(mktemp)

                if command -v journalctl &>/dev/null; then
                    journalctl -u ssh --since "7 days ago" --no-pager 2>/dev/null \
                        | grep -E 'sshd.*(Accepted|Failed password|Invalid user|authentication failure)' \
                        > "$tmp_ssh_stats"
                fi
                if [ ! -s "$tmp_ssh_stats" ] && command -v journalctl &>/dev/null; then
                    journalctl -u sshd --since "7 days ago" --no-pager 2>/dev/null \
                        | grep -E 'sshd.*(Accepted|Failed password|Invalid user|authentication failure)' \
                        > "$tmp_ssh_stats"
                fi

                awk '
                {
                    ip=""; type=""
                    if ($0 ~ /Accepted/) {
                        for (i=1; i<=NF; i++) if ($i == "from") { ip=$(i+1); type="ok"; break }
                    } else if ($0 ~ /Failed password/ || $0 ~ /Invalid user/) {
                        for (i=1; i<=NF; i++) if ($i == "from") { ip=$(i+1); type="fail"; break }
                    } else if ($0 ~ /authentication failure/) {
                        for (i=1; i<=NF; i++) if ($i ~ /^rhost=/) { ip=$i; sub(/^rhost=/, "", ip); type="fail"; break }
                    }
                    if (ip != "") {
                        gsub(/[^0-9A-Fa-f:.]/, "", ip)
                        if (type == "ok") success[ip]++
                        else if (type == "fail") failed[ip]++
                    }
                }
                END {
                    for (ip in success) seen[ip]=1
                    for (ip in failed) seen[ip]=1
                    for (ip in seen) printf "%s %d %d %d\n", ip, success[ip]+0, failed[ip]+0, success[ip]+failed[ip]
                }' "$tmp_ssh_stats" > "$tmp_ip_stats"

                for ip in $whitelist; do
                    awk -v qip="$ip" '
                        $1 == qip { print $0; found=1 }
                        END { if (!found) print qip " 0 0 0" }
                    ' "$tmp_ip_stats" >> "$tmp_whitelist_table"
                done
                sort -k2,2nr -k4,4nr "$tmp_whitelist_table" > "$tmp_whitelist_sorted"

                printf "%-20s %-8s %-8s %-8s\n" "IP" "成功" "失败" "总计"
                echo "------------------------------------------------"
                idx=1
                while read -r stat_ip stat_ok stat_fail stat_total; do
                    printf "%s. %-17s %-8s %-8s %-8s\n" "$idx" "$stat_ip" "${stat_ok}次" "${stat_fail}次" "${stat_total}次"
                    whitelist_display_ips="$whitelist_display_ips $stat_ip"
                    idx=$((idx + 1))
                done < "$tmp_whitelist_sorted"

                rm -f "$tmp_ssh_stats" "$tmp_ip_stats" "$tmp_whitelist_table" "$tmp_whitelist_sorted"

                echo "------------------------"
                echo "1. 添加白名单IP"
                echo "2. 删除白名单IP"
                echo "0. 退出"
                echo "------------------------"
                read -e -p "请输入你的选择: " whitelist_choice
                case "$whitelist_choice" in
                    1)
                        read -e -p "请输入要添加的白名单IP: " add_ip
                        if [ -z "$add_ip" ]; then
                            echo "未输入IP"
                        elif echo " $whitelist " | grep -Fqw -- "$add_ip"; then
                            echo "该IP已在白名单中"
                        else
                            whitelist="$whitelist $add_ip"
                            sed -i "s|^[[:space:]]*ignoreip[[:space:]]*=.*|ignoreip = $whitelist|" "$fail2ban_conf"
                            [ -f "$fail2ban_default_conf" ] && sed -i "s|^[[:space:]]*ignoreip[[:space:]]*=.*|ignoreip = $whitelist|" "$fail2ban_default_conf"
                            if docker inspect fail2ban &>/dev/null && docker exec fail2ban fail2ban-client ping &>/dev/null; then
                                docker exec fail2ban fail2ban-client set sshd unbanip "$add_ip" >/dev/null 2>&1 || true
                            fi
                            docker restart fail2ban >/dev/null 2>&1 || true
                            echo "已添加: $add_ip"
                            echo "如果该IP原来被封禁，已尝试自动解除封禁。"
                        fi
                        read -n1 -r -p "按任意键继续..."
                        ;;
                    2)
                        read -e -p "请输入要删除的序号: " del_idx
                        if ! echo "$del_idx" | grep -Eq '^[0-9]+$'; then
                            echo "序号无效"
                            read -n1 -r -p "按任意键继续..."
                            continue
                        fi
                        new_whitelist=""
                        idx=1
                        deleted_ip=""
                        for ip in $whitelist_display_ips; do
                            if [ "$idx" = "$del_idx" ]; then
                                deleted_ip="$ip"
                            else
                                new_whitelist="$new_whitelist $ip"
                            fi
                            idx=$((idx + 1))
                        done
                        new_whitelist=$(echo "$new_whitelist" | xargs)
                        if [ -z "$deleted_ip" ]; then
                            echo "未找到该序号"
                        elif [ -z "$new_whitelist" ]; then
                            echo "白名单不能为空，已取消删除"
                        else
                            sed -i "s|^[[:space:]]*ignoreip[[:space:]]*=.*|ignoreip = $new_whitelist|" "$fail2ban_conf"
                            [ -f "$fail2ban_default_conf" ] && sed -i "s|^[[:space:]]*ignoreip[[:space:]]*=.*|ignoreip = $new_whitelist|" "$fail2ban_default_conf"
                            docker restart fail2ban >/dev/null 2>&1 || true
                            echo "已删除: $deleted_ip"
                        fi
                        read -n1 -r -p "按任意键继续..."
                        ;;
                    0) break ;;
                    *) echo "无效选择"; read -n1 -r -p "按任意键继续..." ;;
                esac
            done
            ;;

        9)
            while true; do
                clear
                echo "▶️ 日志占用/手动清理"
                echo "------------------------"
                echo "1. 查看 systemd-journald 日志占用"
                echo "2. 查看 systemd-journald 启动日志列表"
                echo "3. 查看 Fail2Ban 本地目录大小"
                echo "4. 查看 SSH 登录日志文件大小"
                echo "9. 手动清理 systemd-journald 日志（不修改默认策略）"
                echo "0. 退出"
                echo "------------------------"
                read -e -p "请输入你的选择: " log_size_choice
                case "$log_size_choice" in
                    1)
                        clear
                        echo "▶️ systemd-journald 日志占用"
                        echo "------------------------"
                        if command -v journalctl &>/dev/null; then
                            journalctl --disk-usage
                        else
                            echo -e "${gl_hong}当前系统未找到 journalctl。${gl_bai}"
                        fi
                        echo "------------------------"
                        echo "说明: 这是 systemd-journald 系统日志占用，不是 Fail2Ban 专属日志。"
                        read -n1 -r -p "按任意键继续..."
                        ;;
                    2)
                        clear
                        echo "▶️ systemd-journald 启动日志列表"
                        echo "------------------------"
                        if command -v journalctl &>/dev/null; then
                            journalctl --list-boots
                        else
                            echo -e "${gl_hong}当前系统未找到 journalctl。${gl_bai}"
                        fi
                        echo "------------------------"
                        echo "说明: 显示系统保存了哪些开机周期的 journal 日志。"
                        read -n1 -r -p "按任意键继续..."
                        ;;
                    3)
                        clear
                        echo "▶️ Fail2Ban 本地目录大小"
                        echo "------------------------"
                        if [ -d /home/docker/fail2ban ]; then
                            du -sh /home/docker/fail2ban 2>/dev/null
                            echo "------------------------"
                            du -h --max-depth=2 /home/docker/fail2ban 2>/dev/null | sort -hr | head -30
                        else
                            echo -e "${gl_huang}未找到目录: /home/docker/fail2ban${gl_bai}"
                        fi
                        read -n1 -r -p "按任意键继续..."
                        ;;
                    4)
                        clear
                        echo "▶️ SSH 登录日志文件大小"
                        echo "------------------------"
                        found_log="false"
                        for log_file in /var/log/auth.log /var/log/auth.log.* /var/log/secure /var/log/secure.*; do
                            if [ -e "$log_file" ]; then
                                found_log="true"
                                du -h "$log_file" 2>/dev/null
                            fi
                        done
                        if [ "$found_log" != "true" ]; then
                            echo -e "${gl_huang}未找到 /var/log/auth.log 或 /var/log/secure 相关日志文件。${gl_bai}"
                        fi
                        echo "------------------------"
                        echo "说明: 这些是 SSH 登录成功/失败统计可能读取的本机日志文件。"
                        read -n1 -r -p "按任意键继续..."
                        ;;
                    9)
                        clear
                        echo "▶️ 手动清理 systemd-journald 日志"
                        echo "------------------------"
                        echo "说明: 只执行本次清理，不修改 /etc/systemd/journald.conf 默认策略。"
                        echo "清理目标: 保留最近7天，并尽量控制 journal 总占用不超过 200M。"
                        echo "影响范围: systemd-journald 系统日志，不是 Fail2Ban 专属日志。"
                        echo "------------------------"
                        if ! command -v journalctl &>/dev/null; then
                            echo -e "${gl_hong}当前系统未找到 journalctl。${gl_bai}"
                            read -n1 -r -p "按任意键继续..."
                            continue
                        fi
                        echo "清理前占用:"
                        journalctl --disk-usage
                        echo "------------------------"
                        read -e -p "确定执行本次 journal 日志清理吗？(Y/N): " clean_confirm
                        case "$clean_confirm" in
                            [Yy])
                                journalctl --vacuum-time=7d
                                journalctl --vacuum-size=200M
                                echo "------------------------"
                                echo "清理后占用:"
                                journalctl --disk-usage
                                echo -e "${gl_lv}清理完成，系统默认日志策略未修改。${gl_bai}"
                                ;;
                            *)
                                echo "已取消清理"
                                ;;
                        esac
                        read -n1 -r -p "按任意键继续..."
                        ;;
                    0) break ;;
                    *) echo "无效选择"; read -n1 -r -p "按任意键继续..." ;;
                esac
            done
            ;;

        0)
            break
            ;;

        *)
            echo "无效选择，请重新输入。"
            read -n1 -r -p "按任意键继续..."
            ;;

    esac

done
;;



















      990)
      linux_app_ports
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
        clear
        echo "▶️ 正在启动定时远程备份与传送模块..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/zidongbeifen.sh)
        echo "✅ 远程备份与传送模块执行完成。"
        ;;



      1001)
        clear
        echo "▶️ 正在启动定时远程备份与传送模块..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/zidongmima.sh)
        echo "✅ 远程备份与传送模块执行完成。"
        ;;

      1002)
        clear
        echo "▶️ 正在启动win10ltls模块..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/win10ltls.sh)
        echo "✅ 远程备份与传送模块执行完成。"
        ;;

      1003)
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

        echo -e "\033[1;33m📌 说明：\033[0m"
        echo -e "\033[1;32m✔ 不带斜杠（如 /home/web/wangpan）表示复制整个文件夹\033[0m"
        echo -e "\033[1;32m✔ 带斜杠（如 /home/web/wangpan/）表示只复制该文件夹的内容\033[0m"

        echo "------------------------"
        # 读取用户输入
        read -e -p "请输入本地目录路径（如 /home/web/wangpan/）: " local_path
        # 如果本地路径末尾没有 /，则自动添加
        [[ "$local_path" != */ ]] && local_path="${local_path}/"

        read -e -p "请输入远程 VPS 的 IP 地址（例如 1.1.1.1）: " remote_ip

        read -e -p "请输入远程目录路径（默认与本地一致，直接回车即可）: " remote_path
        if [ -z "$remote_path" ]; then
            remote_path="$local_path"
            echo "📂 未输入远程路径，已自动设置为与本地路径一致：$remote_path"
        fi


        # 检查远程 VPS 是否安装 rsync
        echo "🕵️ 正在检查远程 VPS 是否已安装 rsync..."
        ssh root@"$remote_ip" "command -v rsync > /dev/null 2>&1"
        if [ $? -ne 0 ]; then
            echo "⚙️ 远程 VPS 未安装 rsync，正在安装..."
            ssh root@"$remote_ip" "apt update > /dev/null 2>&1 && apt install -y rsync > /dev/null 2>&1"
            echo "✅ 远程 VPS 的 rsync 安装完成。"
        else
            echo "✅ 远程 VPS 已安装 rsync，跳过安装。"
        fi


        echo ""
        echo "🚀 开始传送："
        echo "从：$local_path"
        echo "到：root@$remote_ip:$remote_path"
        echo ""


        rsync -avz "$local_path" root@"$remote_ip":"$remote_path"

        echo ""
        echo "✅ 文件传送完成。"
        echo "------------------------"
        echo ""
        ;;


      1004)
        clear
        echo "▶️ 正在启动105脚本必装模块..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/zidonghebinganzhuangjiaoben.sh)
        echo "✅ 动105脚本必装模块执行完成。"
        ;;
      1005)
        clear
        echo "▶️ 正在启动定时远程备份与传送模块..."
        bash <(curl -fsSL https://raw.githubusercontent.com/zaixiangjian/sh/main/zidonghebing.sh)
        echo "✅ 远程备份与传送模块执行完成。"
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
	  echo -e "${gl_kjlan}1.   ${gl_bai}设置脚本启动快捷键                 ${gl_kjlan}2.   ${gl_bai}修改登录密码"
	  echo -e "${gl_kjlan}3.   ${gl_bai}ROOT密码登录模式                   ${gl_kjlan}4.   ${gl_bai}安装Python指定版本"
	  echo -e "${gl_kjlan}5.   ${gl_bai}开放所有端口                       ${gl_kjlan}6.   ${gl_bai}修改SSH连接端口"
	  echo -e "${gl_kjlan}7.   ${gl_bai}优化DNS地址                        ${gl_kjlan}8.   ${gl_bai}一键重装系统 ${gl_huang}★${gl_bai}"
	  echo -e "${gl_kjlan}9.   ${gl_bai}禁用ROOT账户创建新账户             ${gl_kjlan}10.  ${gl_bai}切换优先ipv4/ipv6"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}11.  ${gl_bai}查看端口占用状态                   ${gl_kjlan}12.  ${gl_bai}修改虚拟内存大小"
	  echo -e "${gl_kjlan}13.  ${gl_bai}用户管理                           ${gl_kjlan}14.  ${gl_bai}用户/密码生成器"
	  echo -e "${gl_kjlan}15.  ${gl_bai}系统时区调整                       ${gl_kjlan}16.  ${gl_bai}设置BBR3加速"
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
			  yinsiyuanquan1
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
				CheckFirstRun_true
				yinsiyuanquan2
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
echo -e "科技lion脚本工具箱 v$sh_v 只为更简单的Linux的使用！"
echo -e "适配Ubuntu/Debian/CentOS/Alpine/Kali/Arch/RedHat/Fedora/Alma/Rocky系统"
echo -e "-输入${gl_huang}k${gl_kjlan}可快速启动此脚本-${gl_bai}"
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
