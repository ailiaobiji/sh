#!/usr/bin/env bash
set -Eeuo pipefail

# Agent AI 远程备份上传工具
# 用途：调用 /root/hermes_manager.sh 的 18→1 备份包、/root/Openclaw.sh 的 188→1 备份包，上传到一个或多个远程服务器。

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

CONFIG_DIR='/root/agent-ai.d'
LEGACY_CONFIG_FILE='/root/agent-ai.conf'
HERMES_SCRIPT='/root/hermes_manager.sh'
OPENCLAW_SCRIPT='/root/Openclaw.sh'
HERMES_BACKUP_DIR="${HOME}/hermes_memory_backups"
OPENCLAW_BACKUP_DIR="${HOME}/openclaw_custom_backups"
LOCAL_KEEP_DEFAULT=3

# 当前远程配置变量；由 load_target_config 加载
PROFILE_NAME=''
ENABLED='1'
REMOTE_USER=''
REMOTE_HOST=''
REMOTE_PORT='22'
REMOTE_DIR='/root/agent-ai-backups'
REMOTE_KEEP='0'
AUTH_METHOD='key'   # key=密钥/默认SSH；password=密码(sshpass)
SSH_KEY=''
SSH_PASSWORD=''
SCP_EXTRA_OPTS=''
LOCAL_KEEP='3'

pause() {
    read -r -p "按回车键继续..." _ || true
}

safe_name() {
    local name="$1"
    name="${name// /_}"
    name="$(printf '%s' "$name" | tr -cd 'A-Za-z0-9._-')"
    [ -n "$name" ] || name="default"
    printf '%s' "$name"
}

config_path_for_name() {
    local name
    name="$(safe_name "$1")"
    printf '%s/%s.conf' "$CONFIG_DIR" "$name"
}

ensure_config_dir() {
    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR" 2>/dev/null || true

    # 兼容旧版本：如果存在 /root/agent-ai.conf，则自动迁移为 default.conf。
    if [ -f "$LEGACY_CONFIG_FILE" ] && [ ! -f "$CONFIG_DIR/default.conf" ]; then
        mv "$LEGACY_CONFIG_FILE" "$CONFIG_DIR/default.conf"
        chmod 600 "$CONFIG_DIR/default.conf"
        echo -e "${YELLOW}已将旧配置迁移到：$CONFIG_DIR/default.conf${NC}"
    fi
}

write_target_config() {
    local file="$1"
    mkdir -p "$(dirname "$file")"
    cat > "$file" <<EOF
# Agent AI 远程备份配置
# 配置名
PROFILE_NAME='$PROFILE_NAME'

# 是否启用：1=启用，0=禁用。备份 1/2/3 会上传到所有启用的配置。
ENABLED='$ENABLED'

# 远程服务器 SSH 信息
REMOTE_USER='$REMOTE_USER'
REMOTE_HOST='$REMOTE_HOST'
REMOTE_PORT='$REMOTE_PORT'
REMOTE_DIR='$REMOTE_DIR'

# 本地每类备份保留数量；默认 3 个
LOCAL_KEEP='$LOCAL_KEEP'

# 远程每类备份保留数量：0 表示不自动删除远程备份
REMOTE_KEEP='$REMOTE_KEEP'

# 认证方式：key=SSH密钥/默认SSH；password=密码(依赖 sshpass)
AUTH_METHOD='$AUTH_METHOD'

# key 模式可选：SSH 私钥路径，例如 /root/.ssh/id_rsa；留空则使用 ssh 默认配置
SSH_KEY='$SSH_KEY'

# password 模式：远程 SSH 密码。注意：会明文保存在本文件，请保护好权限。
SSH_PASSWORD='$SSH_PASSWORD'

# 可选：额外 ssh/scp 参数，例如 -o StrictHostKeyChecking=accept-new
SCP_EXTRA_OPTS='$SCP_EXTRA_OPTS'
EOF
    chmod 600 "$file"
    echo -e "${GREEN}✅ 配置已保存：$file${NC}"
}

load_target_config() {
    local file="$1"
    PROFILE_NAME=''
    ENABLED='1'
    REMOTE_USER=''
    REMOTE_HOST=''
    REMOTE_PORT='22'
    REMOTE_DIR='/root/agent-ai-backups'
    REMOTE_KEEP='0'
    AUTH_METHOD='key'
    SSH_KEY=''
    SSH_PASSWORD=''
    SCP_EXTRA_OPTS=''
    LOCAL_KEEP="$LOCAL_KEEP_DEFAULT"

    # shellcheck disable=SC1090
    source "$file"

    PROFILE_NAME="${PROFILE_NAME:-$(basename "$file" .conf)}"
    ENABLED="${ENABLED:-1}"
    REMOTE_PORT="${REMOTE_PORT:-22}"
    REMOTE_DIR="${REMOTE_DIR:-/root/agent-ai-backups}"
    REMOTE_KEEP="${REMOTE_KEEP:-0}"
    AUTH_METHOD="${AUTH_METHOD:-key}"
    SSH_KEY="${SSH_KEY:-}"
    SSH_PASSWORD="${SSH_PASSWORD:-}"
    SCP_EXTRA_OPTS="${SCP_EXTRA_OPTS:-}"
    LOCAL_KEEP="${LOCAL_KEEP:-$LOCAL_KEEP_DEFAULT}"
}

config_files_all() {
    ensure_config_dir >/dev/null 2>&1 || true
    find "$CONFIG_DIR" -maxdepth 1 -type f -name '*.conf' | sort
}

config_files_enabled() {
    local file enabled
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        enabled="$(grep -E '^ENABLED=' "$file" 2>/dev/null | tail -n1 | cut -d= -f2- | tr -d "'\"")"
        enabled="${enabled:-1}"
        [ "$enabled" = "1" ] && printf '%s\n' "$file"
    done < <(config_files_all)
}

has_any_config() {
    [ -n "$(config_files_all | head -n1)" ]
}

has_enabled_config() {
    [ -n "$(config_files_enabled | head -n1)" ]
}

create_or_edit_config() {
    ensure_config_dir
    local default_name name file auth_choice enabled_choice
    default_name="server$(date +%H%M%S)"
    read -r -p "配置名称 [${default_name}]: " name
    name="${name:-$default_name}"
    name="$(safe_name "$name")"
    file="$(config_path_for_name "$name")"

    if [ -f "$file" ]; then
        echo -e "${YELLOW}正在编辑已有配置：$file${NC}"
        load_target_config "$file"
    else
        PROFILE_NAME="$name"
        ENABLED='1'
        REMOTE_USER='root'
        REMOTE_HOST=''
        REMOTE_PORT='22'
        REMOTE_DIR='/root/agent-ai-backups'
        LOCAL_KEEP='3'
        REMOTE_KEEP='0'
        AUTH_METHOD='key'
        SSH_KEY=''
        SSH_PASSWORD=''
        SCP_EXTRA_OPTS=''
    fi

    read -r -p "启用这个配置？[Y/n]: " enabled_choice
    case "$enabled_choice" in
        n|N) ENABLED='0' ;;
        *) ENABLED='1' ;;
    esac

    read -r -p "远程服务器 IP/域名 REMOTE_HOST [${REMOTE_HOST}]: " input
    REMOTE_HOST="${input:-$REMOTE_HOST}"
    read -r -p "远程用户名 REMOTE_USER [${REMOTE_USER:-root}]: " input
    REMOTE_USER="${input:-${REMOTE_USER:-root}}"
    read -r -p "SSH 端口 REMOTE_PORT [${REMOTE_PORT:-22}]: " input
    REMOTE_PORT="${input:-${REMOTE_PORT:-22}}"
    read -r -p "远程保存目录 REMOTE_DIR [${REMOTE_DIR:-/root/agent-ai-backups}]: " input
    REMOTE_DIR="${input:-${REMOTE_DIR:-/root/agent-ai-backups}}"

    echo "认证方式："
    echo "  1. SSH 密钥/默认 SSH（推荐）"
    echo "  2. 密码登录 sshpass（会明文保存密码）"
    read -r -p "请选择认证方式 [1-2，当前 ${AUTH_METHOD:-key}]: " auth_choice
    case "$auth_choice" in
        2)
            AUTH_METHOD='password'
            SSH_KEY=''
            read -r -s -p "远程 SSH 密码 SSH_PASSWORD（留空保留原密码）: " input
            echo ""
            [ -n "$input" ] && SSH_PASSWORD="$input"
            ;;
        1)
            AUTH_METHOD='key'
            SSH_PASSWORD=''
            read -r -p "SSH 私钥路径 SSH_KEY（可留空，当前 ${SSH_KEY:-默认SSH配置}）: " input
            SSH_KEY="${input:-$SSH_KEY}"
            ;;
        *)
            if [ "${AUTH_METHOD:-key}" = "password" ]; then
                read -r -s -p "远程 SSH 密码 SSH_PASSWORD（留空保留原密码）: " input
                echo ""
                [ -n "$input" ] && SSH_PASSWORD="$input"
            else
                read -r -p "SSH 私钥路径 SSH_KEY（可留空，当前 ${SSH_KEY:-默认SSH配置}）: " input
                SSH_KEY="${input:-$SSH_KEY}"
            fi
            ;;
    esac

    read -r -p "本地每类保留几个备份 LOCAL_KEEP [${LOCAL_KEEP:-3}]: " input
    LOCAL_KEEP="${input:-${LOCAL_KEEP:-3}}"
    read -r -p "远程每类保留几个备份 REMOTE_KEEP [${REMOTE_KEEP:-3}，0=不清理远程]: " input
    REMOTE_KEEP="${input:-${REMOTE_KEEP:-3}}"
    read -r -p "额外 ssh/scp 参数 SCP_EXTRA_OPTS（可留空，当前 ${SCP_EXTRA_OPTS:-无}）: " input
    SCP_EXTRA_OPTS="${input:-$SCP_EXTRA_OPTS}"

    if [ -z "$REMOTE_HOST" ]; then
        echo -e "${RED}❌ REMOTE_HOST 不能为空，未保存。${NC}"
        return 1
    fi
    write_target_config "$file"
}

list_configs() {
    ensure_config_dir
    local file i=1 status auth pw
    echo -e "${CYAN}当前远程配置列表：${NC}$CONFIG_DIR"
    if ! has_any_config; then
        echo "暂无配置。"
        return 0
    fi
    while IFS= read -r file; do
        load_target_config "$file"
        [ "$ENABLED" = "1" ] && status="启用" || status="禁用"
        auth="$AUTH_METHOD"
        [ "$AUTH_METHOD" = "password" ] && pw="密码已保存" || pw="密钥/默认SSH"
        printf '%s. [%s] %s | %s@%s:%s | %s | 远程目录:%s | 文件:%s\n' \
            "$i" "$status" "$PROFILE_NAME" "${REMOTE_USER:-?}" "${REMOTE_HOST:-?}" "${REMOTE_PORT:-22}" "$pw" "${REMOTE_DIR:-/root/agent-ai-backups}" "$file"
        i=$((i+1))
    done < <(config_files_all)
}

select_config_file() {
    local prompt_text="$1"
    local files=() file i choice
    mapfile -t files < <(config_files_all)
    if [ "${#files[@]}" -eq 0 ]; then
        echo -e "${YELLOW}暂无配置。${NC}" >&2
        return 1
    fi
    list_configs >&2
    echo "" >&2
    read -r -p "$prompt_text" choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#files[@]}" ]; then
        echo -e "${RED}输入错误。${NC}" >&2
        return 1
    fi
    file="${files[$((choice-1))]}"
    printf '%s\n' "$file"
}

delete_config() {
    ensure_config_dir
    local file confirm
    file="$(select_config_file '请输入要删除的配置序号: ')" || return 1
    echo -e "${YELLOW}将删除配置文件：$file${NC}"
    read -r -p "确认删除？(y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -f -- "$file"
        echo -e "${GREEN}✅ 已删除配置。${NC}"
    else
        echo "已取消。"
    fi
}

toggle_config() {
    ensure_config_dir
    local file
    file="$(select_config_file '请输入要启用/禁用的配置序号: ')" || return 1
    load_target_config "$file"
    if [ "$ENABLED" = "1" ]; then
        ENABLED='0'
    else
        ENABLED='1'
    fi
    write_target_config "$file"
}

edit_config_raw() {
    ensure_config_dir
    local file
    file="$(select_config_file '请输入要手动编辑的配置序号: ')" || return 1
    ${EDITOR:-nano} "$file"
    chmod 600 "$file" 2>/dev/null || true
}

config_menu() {
    ensure_config_dir
    while true; do
        echo -e "${CYAN}=======================================${NC}"
        echo -e "${YELLOW}        Agent AI 远程配置管理${NC}"
        echo -e "${CYAN}=======================================${NC}"
        echo "1. 查看所有配置"
        echo "2. 新增/编辑配置"
        echo "3. 删除配置"
        echo "4. 启用/禁用配置"
        echo "5. 手动编辑配置文件"
        echo "6. 测试所有启用配置"
        echo "0. 返回主菜单"
        echo -e "${CYAN}=======================================${NC}"
        read -r -p "请输入选项并回车: " c || return 0
        echo ""
        case "$c" in
            1) list_configs; pause ;;
            2) create_or_edit_config; pause ;;
            3) delete_config; pause ;;
            4) toggle_config; pause ;;
            5) edit_config_raw; pause ;;
            6) test_all_enabled_remotes; pause ;;
            0) return 0 ;;
            *) echo -e "${RED}输入错误，请重新选择。${NC}"; sleep 1 ;;
        esac
    done
}

ensure_enabled_configs_or_configure() {
    ensure_config_dir
    if has_enabled_config; then
        return 0
    fi
    echo -e "${YELLOW}还没有启用的远程配置，请先添加/启用配置。${NC}"
    config_menu
    has_enabled_config
}

install_sshpass_if_needed() {
    [ "${AUTH_METHOD:-key}" = "password" ] || return 0
    if command -v sshpass >/dev/null 2>&1; then
        return 0
    fi
    echo -e "${YELLOW}未检测到 sshpass，密码模式需要安装 sshpass...${NC}"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y sshpass
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y sshpass
    elif command -v yum >/dev/null 2>&1; then
        yum install -y sshpass
    else
        echo -e "${RED}❌ 无法自动安装 sshpass，请手动安装后再使用密码模式。${NC}"
        return 1
    fi
}

ssh_base_array() {
    # -n 防止 ssh 读取 while 循环的标准输入，否则多配置循环会被 ssh 吃掉后续配置，只上传/测试第一台。
    SSH_CMD=(ssh -n -p "$REMOTE_PORT" -o ServerAliveInterval=20 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=accept-new)
    if [ "${AUTH_METHOD:-key}" = "password" ]; then
        install_sshpass_if_needed || return 1
        [ -n "${SSH_PASSWORD:-}" ] || { echo -e "${RED}❌ [$PROFILE_NAME] 密码模式下 SSH_PASSWORD 不能为空，请重新配置。${NC}"; return 1; }
        SSH_CMD=(sshpass -e "${SSH_CMD[@]}")
    elif [ -n "${SSH_KEY:-}" ]; then
        SSH_CMD+=(-i "$SSH_KEY")
    fi
    if [ -n "${SCP_EXTRA_OPTS:-}" ]; then
        # shellcheck disable=SC2206
        local extra=( $SCP_EXTRA_OPTS )
        SSH_CMD+=("${extra[@]}")
    fi
}

scp_base_array() {
    SCP_CMD=(scp -P "$REMOTE_PORT" -o StrictHostKeyChecking=accept-new)
    if [ "${AUTH_METHOD:-key}" = "password" ]; then
        install_sshpass_if_needed || return 1
        [ -n "${SSH_PASSWORD:-}" ] || { echo -e "${RED}❌ [$PROFILE_NAME] 密码模式下 SSH_PASSWORD 不能为空，请重新配置。${NC}"; return 1; }
        SCP_CMD=(sshpass -e "${SCP_CMD[@]}")
    elif [ -n "${SSH_KEY:-}" ]; then
        SCP_CMD+=(-i "$SSH_KEY")
    fi
    if [ -n "${SCP_EXTRA_OPTS:-}" ]; then
        # shellcheck disable=SC2206
        local extra=( $SCP_EXTRA_OPTS )
        SCP_CMD+=("${extra[@]}")
    fi
}

remote_target() {
    printf '%s@%s' "$REMOTE_USER" "$REMOTE_HOST"
}

remote_quote() {
    printf '%q' "$1"
}

remote_mkdir() {
    local subdir="$1"
    local target
    target="$(remote_target)"
    ssh_base_array || return 1
    SSHPASS="${SSH_PASSWORD:-}" "${SSH_CMD[@]}" "$target" "mkdir -p $(remote_quote "$REMOTE_DIR/$subdir")"
}

test_loaded_remote() {
    local target
    target="$(remote_target)"
    echo -e "${CYAN}[$PROFILE_NAME] 测试 SSH：$target:$REMOTE_PORT${NC}"
    ssh_base_array || return 1
    if SSHPASS="${SSH_PASSWORD:-}" "${SSH_CMD[@]}" "$target" "echo SSH_OK && mkdir -p $(remote_quote "$REMOTE_DIR/hermes") $(remote_quote "$REMOTE_DIR/openclaw")"; then
        echo -e "${GREEN}✅ [$PROFILE_NAME] SSH 连接和远程目录测试成功。${NC}"
    else
        echo -e "${RED}❌ [$PROFILE_NAME] SSH 连接失败，请检查认证方式、密钥/密码、防火墙或远程 SSH 设置。${NC}"
        return 1
    fi
}

test_all_enabled_remotes() {
    ensure_enabled_configs_or_configure || return 1
    local file failed=0
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        load_target_config "$file"
        test_loaded_remote || failed=1
        echo ""
    done < <(config_files_enabled)
    return "$failed"
}

find_newest_backup() {
    local dir="$1"
    local pattern="$2"
    [ -d "$dir" ] || return 1
    find "$dir" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1 {sub(/^[^ ]+ /, ""); print; exit}'
}

extract_backup_path_from_output() {
    local output="$1"
    local dir="$2"
    local regex="$3"
    printf '%s\n' "$output" | grep -oE "$dir/$regex" | tail -n 1
}

count_backups() {
    local dir="$1"
    local pattern="$2"
    [ -d "$dir" ] || { echo 0; return 0; }
    find "$dir" -maxdepth 1 -type f -name "$pattern" | wc -l | tr -d ' '
}

get_effective_local_keep() {
    local keep="$LOCAL_KEEP_DEFAULT" file k
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        k="$(grep -E '^LOCAL_KEEP=' "$file" 2>/dev/null | tail -n1 | cut -d= -f2- | tr -d "'\"")"
        if [[ "$k" =~ ^[0-9]+$ ]] && [ "$k" -gt "$keep" ]; then
            keep="$k"
        fi
    done < <(config_files_enabled)
    printf '%s' "$keep"
}

prune_local_backups() {
    local dir="$1"
    local pattern="$2"
    local keep="${3:-3}"
    [ -d "$dir" ] || return 0
    [[ "$keep" =~ ^[0-9]+$ ]] || keep=3
    [ "$keep" -gt 0 ] || return 0

    mapfile -t old_files < <(find "$dir" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk -v keep="$keep" 'NR>keep {sub(/^[^ ]+ /, ""); print}')
    if [ "${#old_files[@]}" -gt 0 ]; then
        echo -e "${YELLOW}清理本地旧备份，只保留最新 $keep 个：${NC}"
        printf '  %s\n' "${old_files[@]}"
        rm -f -- "${old_files[@]}"
    fi
}

prune_remote_backups_loaded() {
    local subdir="$1"
    local pattern="$2"
    local keep="${REMOTE_KEEP:-0}"
    [[ "$keep" =~ ^[0-9]+$ ]] || keep=0
    [ "$keep" -gt 0 ] || return 0

    local target rdir remote_cmd
    target="$(remote_target)"
    rdir="$REMOTE_DIR/$subdir"
    echo -e "${YELLOW}[$PROFILE_NAME] 清理远程旧备份，远程每类保留最新 $keep 个...${NC}"
    ssh_base_array || return 0
    remote_cmd="cd $(remote_quote "$rdir") 2>/dev/null && ls -1t $pattern 2>/dev/null | awk 'NR>${keep}' | while IFS= read -r f; do rm -f -- \"\$f\"; done"
    SSHPASS="${SSH_PASSWORD:-}" "${SSH_CMD[@]}" "$target" "$remote_cmd" || true
}

upload_backup_loaded() {
    local file="$1"
    local subdir="$2"
    [ -f "$file" ] || { echo -e "${RED}❌ 备份文件不存在：$file${NC}"; return 1; }
    if ! remote_mkdir "$subdir"; then
        echo -e "${RED}❌ [$PROFILE_NAME] 创建远程目录失败，跳过此配置，继续上传下一个配置。${NC}"
        return 1
    fi
    scp_base_array || return 1
    local target
    target="$(remote_target)"
    echo -e "${CYAN}[$PROFILE_NAME] 正在上传：$file${NC}"
    echo -e "${CYAN}[$PROFILE_NAME] 远程位置：$target:$REMOTE_DIR/$subdir/${NC}"
    if SSHPASS="${SSH_PASSWORD:-}" "${SCP_CMD[@]}" "$file" "$target:$REMOTE_DIR/$subdir/"; then
        echo -e "${GREEN}✅ [$PROFILE_NAME] 上传成功。${NC}"
    else
        echo -e "${RED}❌ [$PROFILE_NAME] 上传失败。${NC}"
        return 1
    fi
}

upload_backup_to_all_enabled() {
    local file="$1"
    local subdir="$2"
    local pattern="$3"
    local cfg failed=0 total=0 ok=0
    ensure_enabled_configs_or_configure || return 1
    while IFS= read -r cfg; do
        [ -n "$cfg" ] || continue
        total=$((total+1))
        load_target_config "$cfg"
        echo ""
        if upload_backup_loaded "$file" "$subdir"; then
            prune_remote_backups_loaded "$subdir" "$pattern"
            ok=$((ok+1))
        else
            failed=1
        fi
    done < <(config_files_enabled)
    echo ""
    echo -e "${CYAN}上传汇总：成功 $ok / 共 $total 个启用配置${NC}"
    return "$failed"
}

run_hermes_manager_backup() {
    [ -f "$HERMES_SCRIPT" ] || { echo -e "${RED}❌ 未找到 $HERMES_SCRIPT${NC}"; return 1; }
    chmod +x "$HERMES_SCRIPT" || true
    mkdir -p "$HERMES_BACKUP_DIR"

    local before_count after_count newest
    before_count=$(count_backups "$HERMES_BACKUP_DIR" 'hermes_memory_full_*.tar.gz')
    echo -e "${CYAN}调用 Hermes 管理脚本执行：18 → 1 → y${NC}"

    # 输入顺序：主菜单18、子菜单1、确认y、子菜单暂停回车、子菜单0、主菜单暂停回车、主菜单0退出。
    if ! timeout 900 bash "$HERMES_SCRIPT" <<'EOF'
18
1
y

0

0
EOF
    then
        echo -e "${RED}❌ Hermes 管理脚本备份执行失败或超时。${NC}"
        return 1
    fi

    after_count=$(count_backups "$HERMES_BACKUP_DIR" 'hermes_memory_full_*.tar.gz')
    newest=$(find_newest_backup "$HERMES_BACKUP_DIR" 'hermes_memory_full_*.tar.gz' || true)
    if [ -z "$newest" ] || [ "$after_count" -le "$before_count" ]; then
        echo -e "${YELLOW}⚠️ 未检测到新增 Hermes 备份包，将尝试上传目录中最新备份：${NC}${newest:-无}"
    fi
    [ -n "$newest" ] || { echo -e "${RED}❌ Hermes 备份目录没有可上传的备份包。${NC}"; return 1; }
    printf '%s\n' "$newest"
}

run_openclaw_custom_backup() {
    [ -f "$OPENCLAW_SCRIPT" ] || { echo -e "${RED}❌ 未找到 $OPENCLAW_SCRIPT${NC}"; return 1; }
    chmod +x "$OPENCLAW_SCRIPT" || true
    mkdir -p "$OPENCLAW_BACKUP_DIR"

    local before_count after_count newest
    before_count=$(count_backups "$OPENCLAW_BACKUP_DIR" 'openclaw_custom_full_*.tar.gz')
    echo -e "${CYAN}调用 OpenClaw 管理脚本执行：188 → 1 → y${NC}"
    echo -e "${YELLOW}注意：OpenClaw.sh 188 会在备份完成后自动重新启动 Gateway；agent-ai 只负责上传和清理备份。${NC}"

    # 输入顺序：主菜单188、子菜单1、确认y、break_end回车、子菜单0、主菜单0返回/退出。
    if ! timeout 900 bash "$OPENCLAW_SCRIPT" <<'EOF'
188
1
y

0
0
EOF
    then
        echo -e "${RED}❌ OpenClaw 管理脚本备份执行失败或超时。${NC}"
        return 1
    fi

    after_count=$(count_backups "$OPENCLAW_BACKUP_DIR" 'openclaw_custom_full_*.tar.gz')
    newest=$(find_newest_backup "$OPENCLAW_BACKUP_DIR" 'openclaw_custom_full_*.tar.gz' || true)
    if [ -z "$newest" ] || [ "$after_count" -le "$before_count" ]; then
        echo -e "${YELLOW}⚠️ 未检测到新增 OpenClaw 备份包，将尝试上传目录中最新备份：${NC}${newest:-无}"
    fi
    [ -n "$newest" ] || { echo -e "${RED}❌ OpenClaw 备份目录没有可上传的备份包。${NC}"; return 1; }
    printf '%s\n' "$newest"
}

backup_hermes() {
    ensure_enabled_configs_or_configure || return 1
    local backup_file keep output rc
    output=$(run_hermes_manager_backup 2>&1)
    rc=$?
    printf '%s\n' "$output"
    [ "$rc" -eq 0 ] || return "$rc"
    backup_file=$(extract_backup_path_from_output "$output" "$HERMES_BACKUP_DIR" 'hermes_memory_full_[0-9_]+\.tar\.gz')
    [ -f "$backup_file" ] || { echo -e "${RED}❌ Hermes 备份包路径异常：${backup_file:-未识别到备份包路径}${NC}"; return 1; }
    upload_backup_to_all_enabled "$backup_file" 'hermes' 'hermes_memory_full_*.tar.gz'
    keep="$(get_effective_local_keep)"
    prune_local_backups "$HERMES_BACKUP_DIR" 'hermes_memory_full_*.tar.gz' "$keep"
    echo -e "${GREEN}✅ Hermes 备份完成：已上传到所有启用配置，本地保留 $keep 个。${NC}"
}

backup_openclaw() {
    ensure_enabled_configs_or_configure || return 1
    local backup_file keep output rc
    output=$(run_openclaw_custom_backup 2>&1)
    rc=$?
    printf '%s\n' "$output"
    [ "$rc" -eq 0 ] || return "$rc"
    backup_file=$(extract_backup_path_from_output "$output" "$OPENCLAW_BACKUP_DIR" 'openclaw_custom_full_[0-9_]+\.tar\.gz')
    [ -f "$backup_file" ] || { echo -e "${RED}❌ OpenClaw 备份包路径异常：${backup_file:-未识别到备份包路径}${NC}"; return 1; }
    upload_backup_to_all_enabled "$backup_file" 'openclaw' 'openclaw_custom_full_*.tar.gz'
    keep="$(get_effective_local_keep)"
    prune_local_backups "$OPENCLAW_BACKUP_DIR" 'openclaw_custom_full_*.tar.gz' "$keep"
    echo -e "${GREEN}✅ OpenClaw 备份完成：已上传到所有启用配置，本地保留 $keep 个。${NC}"
}

backup_all() {
    local failed=0
    backup_hermes || failed=1
    echo ""
    backup_openclaw || failed=1
    return "$failed"
}


ensure_cron_available() {
    if command -v crontab >/dev/null 2>&1; then
        return 0
    fi
    echo -e "${YELLOW}未检测到 crontab，正在安装 cron...${NC}"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y cron
        systemctl enable --now cron >/dev/null 2>&1 || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y cronie
        systemctl enable --now crond >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
        yum install -y cronie
        systemctl enable --now crond >/dev/null 2>&1 || true
    else
        echo -e "${RED}❌ 无法自动安装 cron，请手动安装 crontab/cron 后再配置定时任务。${NC}"
        return 1
    fi
}

cron_tag_for_type() {
    case "$1" in
        hermes) echo "agent-ai-hermes" ;;
        openclaw) echo "agent-ai-openclaw" ;;
        all) echo "agent-ai-all" ;;
        *) echo "agent-ai-$1" ;;
    esac
}

cron_cmd_for_type() {
    case "$1" in
        hermes) echo "/bin/bash /root/agent-ai.sh --backup-hermes" ;;
        openclaw) echo "/bin/bash /root/agent-ai.sh --backup-openclaw" ;;
        all) echo "/bin/bash /root/agent-ai.sh --backup-all" ;;
        *) return 1 ;;
    esac
}

show_cron_jobs() {
    ensure_cron_available || return 1
    echo -e "${CYAN}Agent AI 当前定时任务：${NC}"
    local jobs
    jobs="$(crontab -l 2>/dev/null | grep '# agent-ai-' || true)"
    if [ -z "$jobs" ]; then
        echo "暂无 Agent AI 定时任务。"
    else
        echo "$jobs"
    fi
}

remove_cron_job() {
    ensure_cron_available || return 1
    local type="$1" tag tmp
    tmp=$(mktemp)
    crontab -l 2>/dev/null > "$tmp" || true
    case "$type" in
        hermes|openclaw|all)
            tag="$(cron_tag_for_type "$type")"
            grep -v "# $tag" "$tmp" > "${tmp}.new" || true
            ;;
        every)
            grep -v '# agent-ai-' "$tmp" > "${tmp}.new" || true
            ;;
        *)
            rm -f "$tmp" "${tmp}.new"
            return 1
            ;;
    esac
    crontab "${tmp}.new"
    rm -f "$tmp" "${tmp}.new"
    echo -e "${GREEN}✅ 已删除定时任务：$type${NC}"
}

add_or_update_cron_job() {
    ensure_cron_available || return 1
    local type="$1" label="$2" days hour minute tag cmd tmp cron_line
    read -r -p "$label 每几天运行一次？[默认 1]: " days
    days="${days:-1}"
    if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -lt 1 ] || [ "$days" -gt 31 ]; then
        echo -e "${RED}❌ 天数请输入 1-31 的整数。${NC}"
        return 1
    fi
    read -r -p "$label 几点运行？小时 0-23 [默认 3]: " hour
    hour="${hour:-3}"
    if ! [[ "$hour" =~ ^[0-9]+$ ]] || [ "$hour" -lt 0 ] || [ "$hour" -gt 23 ]; then
        echo -e "${RED}❌ 小时请输入 0-23 的整数。${NC}"
        return 1
    fi
    read -r -p "$label 第几分钟运行？0-59 [默认 0]: " minute
    minute="${minute:-0}"
    if ! [[ "$minute" =~ ^[0-9]+$ ]] || [ "$minute" -lt 0 ] || [ "$minute" -gt 59 ]; then
        echo -e "${RED}❌ 分钟请输入 0-59 的整数。${NC}"
        return 1
    fi

    tag="$(cron_tag_for_type "$type")"
    cmd="$(cron_cmd_for_type "$type")" || return 1
    mkdir -p "$CONFIG_DIR"
    # cron 的 */N 是按每月日期步进；适合“每 N 天某个时间”这类轻量定时备份。
    cron_line="$minute $hour */$days * * $cmd # $tag every-${days}-days-at-${hour}:${minute}"

    tmp=$(mktemp)
    crontab -l 2>/dev/null | grep -v "# $tag" > "$tmp" || true
    echo "$cron_line" >> "$tmp"
    crontab "$tmp"
    rm -f "$tmp"
    echo -e "${GREEN}✅ 已设置 $label 定时任务：每 $days 天 ${hour}:$(printf '%02d' "$minute") 运行一次。${NC}"
    echo "$cron_line"
}

cron_menu() {
    while true; do
        echo -e "${CYAN}=======================================${NC}"
        echo -e "${YELLOW}        Agent AI 定时任务管理${NC}"
        echo -e "${CYAN}=======================================${NC}"
        echo "1. 设置 Hermes 定时备份"
        echo "2. 设置 OpenClaw 定时备份"
        echo "3. 设置全部定时备份（Hermes + OpenClaw）"
        echo "4. 查看当前定时任务"
        echo "5. 删除 Hermes 定时任务"
        echo "6. 删除 OpenClaw 定时任务"
        echo "7. 删除全部 Agent AI 定时任务"
        echo "0. 返回主菜单"
        echo -e "${CYAN}=======================================${NC}"
        read -r -p "请输入选项并回车: " c || return 0
        echo ""
        case "$c" in
            1) add_or_update_cron_job hermes "Hermes"; pause ;;
            2) add_or_update_cron_job openclaw "OpenClaw"; pause ;;
            3) add_or_update_cron_job all "全部备份"; pause ;;
            4) show_cron_jobs; pause ;;
            5) remove_cron_job hermes; pause ;;
            6) remove_cron_job openclaw; pause ;;
            7) remove_cron_job every; pause ;;
            0) return 0 ;;
            *) echo -e "${RED}输入错误，请重新选择。${NC}"; sleep 1 ;;
        esac
    done
}

show_status() {
    ensure_config_dir
    echo -e "${CYAN}当前状态${NC}"
    echo "配置目录：$CONFIG_DIR"
    echo "旧配置兼容路径：$LEGACY_CONFIG_FILE（存在时会自动迁移到配置目录）"
    echo "Hermes 备份目录：$HERMES_BACKUP_DIR"
    echo "OpenClaw 备份目录：$OPENCLAW_BACKUP_DIR"
    echo ""
    list_configs
}


cron_human_desc() {
    local minute="$1" hour="$2" dom="$3"
    local day_text
    case "$dom" in
        "*/1"|"*") day_text="每天" ;;
        "*/"*) day_text="每${dom#*/}天" ;;
        *) day_text="每月${dom}号" ;;
    esac
    printf '%s，%s点' "$day_text" "$hour"
    if [ "$minute" != "0" ]; then
        printf '%s分' "$minute"
    fi
    printf '运行'
}

show_cron_summary_on_main() {
    command -v crontab >/dev/null 2>&1 || return 0
    local jobs line minute hour dom type label desc shown=0
    jobs="$(crontab -l 2>/dev/null | grep '# agent-ai-' || true)"
    [ -z "$jobs" ] && return 0

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        case "$line" in
            *"# agent-ai-hermes"*) type="hermes"; label="Hermes定时任务" ;;
            *"# agent-ai-openclaw"*) type="openclaw"; label="OpenClaw定时任务" ;;
            *"# agent-ai-all"*) type="all"; label="全部备份定时任务" ;;
            *) continue ;;
        esac
        minute="$(printf '%s\n' "$line" | awk '{print $1}')"
        hour="$(printf '%s\n' "$line" | awk '{print $2}')"
        dom="$(printf '%s\n' "$line" | awk '{print $3}')"
        desc="$(cron_human_desc "$minute" "$hour" "$dom")"
        echo -e "${gl_kjlan:-$CYAN}${label}${NC}"
        echo -e "${gl_lv:-$GREEN}${desc}${NC}"
        echo "$line"
        echo -e "${CYAN}=======================================${NC}"
        shown=1
    done <<< "$jobs"
    [ "$shown" -eq 1 ] && return 0
}

migrate_agent_ai_cron_no_logs() {
    command -v crontab >/dev/null 2>&1 || return 0
    local current migrated
    current="$(crontab -l 2>/dev/null || true)"
    [ -z "$current" ] && return 0
    migrated="$(printf '%s\n' "$current" | sed 's# >> /root/agent-ai\.d/cron\.log 2>&1 # #')"
    if [ "$current" != "$migrated" ]; then
        printf '%s\n' "$migrated" | crontab -
    fi
}

show_menu() {
    if [ -t 1 ] && [ -n "${TERM:-}" ]; then
        clear || true
    fi
    echo -e "${CYAN}=======================================${NC}"
    echo -e "${YELLOW}        Agent AI 远程备份上传工具${NC}"
    echo -e "${CYAN}=======================================${NC}"
    show_cron_summary_on_main
    echo "1. 备份 Hermes 并上传到所有启用配置"
    echo "2. 备份 OpenClaw 并上传到所有启用配置"
    echo "3. 全部备份并上传到所有启用配置"
    echo "4. 远程配置管理（新增/编辑/删除/启用/禁用）"
    echo "5. 测试所有启用远程配置"
    echo "6. 查看当前配置与状态"
    echo "7. 定时任务管理（Hermes/OpenClaw 每几天几点备份）"
    echo "0. 退出"
    echo -e "${CYAN}=======================================${NC}"
}

main() {
    ensure_config_dir
    migrate_agent_ai_cron_no_logs
    while true; do
        show_menu
        read -r -p "请输入选项并回车: " choice || exit 0
        echo ""
        case "$choice" in
            1) backup_hermes; pause ;;
            2) backup_openclaw; pause ;;
            3) backup_all; pause ;;
            4) config_menu ;;
            5) test_all_enabled_remotes; pause ;;
            6) show_status; pause ;;
            7) cron_menu ;;
            0) echo -e "${GREEN}已退出。${NC}"; exit 0 ;;
            *) echo -e "${RED}输入错误，请重新选择。${NC}"; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    --backup-hermes)
        ensure_config_dir
        backup_hermes
        exit $?
        ;;
    --backup-openclaw)
        ensure_config_dir
        backup_openclaw
        exit $?
        ;;
    --backup-all)
        ensure_config_dir
        backup_all
        exit $?
        ;;
    --cron-list)
        show_cron_jobs
        exit $?
        ;;
    --help|-h)
        echo "用法: /root/agent-ai.sh [--backup-hermes|--backup-openclaw|--backup-all|--cron-list]"
        exit 0
        ;;
esac

main "$@"


