#!/bin/bash

set -e

APP_NAME="CLIProxyAPI"
APP_DIR="/home/docker/CLIProxyAPI"
BACKUP_DIR="/home"
PORT="8317"

install_app() {

    echo
    echo "开始安装 ${APP_NAME}"
    echo

    mkdir -p "$APP_DIR"

    cd "$APP_DIR"

    if [ ! -f docker-compose.yml ]; then
        git clone https://github.com/router-for-me/CLIProxyAPI.git .
    fi

    cp -n config.example.yaml config.yaml
    cp -n .env.example .env

    read -s -p "请输入管理密钥: " KEY
    echo

    sed -i -E '
    s/^(\s*)allow-remote:\s*false\s*$/\1allow-remote: true/
    s/^(\s*)secret-key:\s*""\s*$/\1secret-key: "'"$KEY"'"/
    ' config.yaml

    docker compose up -d

    echo
    echo "=================================="
    echo "安装完成"
    echo "WebUI:"
    echo "http://你的IP:${PORT}/management.html"
    echo "=================================="
    echo
}

update_app() {

    echo
    echo "更新 ${APP_NAME}"
    echo

    if [ ! -d "$APP_DIR" ]; then
        echo "未安装"
        return
    fi

    cd "$APP_DIR"

    docker compose down || true

    git pull

    docker compose pull

    docker compose up -d

    echo
    echo "更新完成"
    echo
}

uninstall_app() {

    echo
    echo "卸载 ${APP_NAME}"
    echo

    if [ ! -d "$APP_DIR" ]; then
        echo "未安装"
        return
    fi

    cd "$APP_DIR"

    docker compose down --rmi all --volumes || true

    cd /home/docker

    rm -rf "$APP_DIR"

    echo
    echo "已删除:"
    echo "- 容器"
    echo "- 网络"
    echo "- 卷"
    echo "- ${APP_DIR}"
    echo
}

backup_app() {

    echo

    if [ ! -d "$APP_DIR" ]; then
        echo "未安装"
        return
    fi

    BACKUP_FILE="${BACKUP_DIR}/CPA-$(date +%Y%m%d%H%M%S).tar.gz"

    echo "开始备份..."
    echo

    tar -czf "$BACKUP_FILE" -C /home/docker CLIProxyAPI

    echo "备份完成:"
    echo "$BACKUP_FILE"
    echo
}

restore_app() {

    echo
    echo "当前备份文件:"
    echo

    ls -1t ${BACKUP_DIR}/CPA-*.tar.gz 2>/dev/null || true

    echo

    read -p "输入备份文件名（直接回车恢复最新）: " FILE

    if [ -z "$FILE" ]; then
        FILE=$(ls -1t ${BACKUP_DIR}/CPA-*.tar.gz 2>/dev/null | head -n 1)
    else
        FILE="${BACKUP_DIR}/${FILE}"
    fi

    if [ ! -f "$FILE" ]; then
        echo
        echo "备份文件不存在"
        echo
        return
    fi

    echo
    echo "开始恢复:"
    echo "$FILE"
    echo

    # 如果已安装
    if [ -d "$APP_DIR" ]; then

        echo "检测到已安装"

        cd "$APP_DIR"

        echo "停止容器..."

        docker compose down || true

        echo "删除旧目录..."

        rm -rf "$APP_DIR"
    fi

    echo
    echo "恢复备份文件..."
    echo

    mkdir -p /home/docker

    tar -xzf "$FILE" -C /home/docker

    if [ ! -f "$APP_DIR/docker-compose.yml" ]; then
        echo "恢复失败"
        return
    fi

    echo "启动容器..."

    cd "$APP_DIR"

    docker compose up -d

    echo
    echo "=================================="
    echo "恢复完成"
    echo "WebUI:"
    echo "http://你的IP:${PORT}/management.html"
    echo "=================================="
    echo
}

show_menu() {

    clear

    echo "=================================="
    echo "     CLIProxyAPI 管理脚本"
    echo "=================================="
    echo
    echo "1. 安装"
    echo "2. 更新"
    echo "3. 卸载"
    echo "4. 备份（home目录）"
    echo "5. 恢复（从home/目录获取）"
    echo "0. 退出"
    echo
}

while true; do

    show_menu

    read -p "请输入选项: " CHOICE

    case $CHOICE in

        1)
            install_app
            ;;

        2)
            update_app
            ;;

        3)
            uninstall_app
            ;;

        4)
            backup_app
            ;;

        5)
            restore_app
            ;;

        0)
            echo
            echo "已退出"
            echo
            exit 0
            ;;

        *)
            echo
            echo "无效选项"
            echo
            ;;
    esac

    read -p "按回车继续..."

done
