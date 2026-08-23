#!/bin/bash

# ===== OpenClaw.sh compatibility/bootstrap helpers =====
# These helpers make this script usable as a standalone script on fresh VPSes.
# They intentionally stay quiet unless something is missing or fails.
: "${ENABLE_STATS:=false}"
: "${sh_v:=unknown}"
: "${gh_proxy:=}"
: "${gl_bai:=}"
: "${gl_hui:=}"
: "${gl_lv:=}"
: "${gl_huang:=}"
: "${gl_hong:=}"
: "${gl_kjlan:=}"
: "${gl_zi:=}"

openclaw_have_command() {
	command -v "$1" >/dev/null 2>&1
}

openclaw_pkg_install() {
	[ "$#" -eq 0 ] && return 0

	local missing=() pkg
	for pkg in "$@"; do
		openclaw_have_command "$pkg" || missing+=("$pkg")
	done
	[ "${#missing[@]}" -eq 0 ] && return 0

	echo "🔧 正在安装缺失依赖: ${missing[*]}"
	if openclaw_have_command apt; then
		apt update && apt install -y "${missing[@]}"
	elif openclaw_have_command apt-get; then
		apt-get update && apt-get install -y "${missing[@]}"
	else
		echo "❌ 未检测到 apt，请手动安装: ${missing[*]}"
		return 1
	fi
}

openclaw_ensure_runtime_deps() {
	# Fresh VPS runtime requirements. Equivalent to:
	# apt update && apt install -y jq curl python3 git
	openclaw_pkg_install jq curl python3 git
}

# The original online runner may provide these functions. Define safe fallbacks
# so local /dev/fd/63 execution will not crash when that wrapper is absent.
send_stats() {
	[ "${ENABLE_STATS}" = "true" ] || return 0
	local action="$1"
	openclaw_have_command curl || return 0
	curl -fsS -m 3 -H 'Content-Type: application/json' \
		-d "{\"action\":\"${action}\",\"version\":\"${sh_v}\"}" \
		'https://api.kejilion.pro/api/log' >/dev/null 2>&1 || true
}

break_end() {
	echo
	if [ -t 0 ]; then
		read -r -p "按回车继续..." _
	fi
}

press_enter() {
	break_end
}

add_app_id() {
	return 0
}

web_del() {
	echo "⚠️ web_del 未在当前脚本中定义，已跳过。"
	return 0
}

# Avoid GNU coreutils install being accidentally used as a package installer in
# older parts of this script (for example: install jq / install git jq).
install() {
	openclaw_pkg_install "$@"
}

openclaw_ensure_runtime_deps
# ===== end compatibility/bootstrap helpers =====

check_openclaw_update() {
		if ! command -v npm >/dev/null 2>&1; then
			return 1
		fi

		# 加上 --no-update-notifier，并确保错误重定向位置正确
		local_version=$(npm list -g openclaw --depth=0 --no-update-notifier 2>/dev/null | grep openclaw | awk '{print $NF}' | sed 's/^.*@//')

		if [ -z "$local_version" ]; then
			return 1
		fi

		remote_version=$(npm view openclaw version --no-update-notifier 2>/dev/null)

		if [ -z "$remote_version" ]; then
			return 1
		fi

		if [ "$local_version" != "$remote_version" ]; then
			echo "${gl_huang}检测到新版本:$remote_version${gl_bai}"
		else
			echo "${gl_lv}当前版本已是最新:$local_version${gl_bai}"
		fi
	}


	get_install_status() {
		if command -v openclaw >/dev/null 2>&1; then
			echo "${gl_lv}已安装${gl_bai}"
		else
			echo "${gl_hui}未安装${gl_bai}"
		fi
	}

	get_running_status() {		
		if pgrep -f "openclaw.*gateway" >/dev/null 2>&1; then
			echo "${gl_lv}运行中${gl_bai}"
		else
			echo "${gl_hui}未运行${gl_bai}"
		fi
	}


	show_menu() {


		clear

		local install_status=$(get_install_status)
		local running_status=$(get_running_status)
		local update_message=$(check_openclaw_update)

		echo "======================================="
		echo -e "🦞 OPENCLAW 管理工具 by KEJILION 🦞"
		echo -e "💡 终端执行 \033[1;33mk claw\033[0m 快速进入菜单"
		echo -e "$install_status $running_status $update_message"
		echo "======================================="
		echo "1.  安装"
		echo "2.  启动"
		echo "3.  停止"
		echo "--------------------"
		echo "4.  状态日志查看"
		echo "5.  换模型"
		echo "6.  API管理"
		echo "7.  机器人连接对接"
		echo "8.  插件管理（安装/删除）"
		echo "9.  技能管理（安装/删除）"
		echo "10. 编辑主配置文件"
		echo "11. 配置向导"
		echo "12. 健康检测与修复"
		echo "13. WebUI访问与设置"
		echo "14. TUI命令行对话窗口"
		echo "15. 记忆/Memory"
		echo "16. 权限管理"
		echo "17. 多智能体管理"
		echo "--------------------"
		echo "18. 备份与还原"
		echo "19. 更新"
		echo "20. 卸载"
		echo "188. 备份与还原自制版本"
		echo "--------------------"
		echo "0. 返回上一级选单"
		echo "--------------------"
		printf "请输入选项并回车: "
	}


	start_gateway() {
		if ! command -v openclaw >/dev/null 2>&1; then
			echo "❌ 未检测到 openclaw，请先安装。"
			return 1
		fi

		# 恢复后服务可能不存在/disabled。这里不要先 stop，
		# 因为 openclaw gateway stop 可能会让刚装好的服务再次变成 disabled。
		echo "正在安装/修复并启动 OpenClaw Gateway systemd 服务..."
		local install_log install_rc
		install_log=$(mktemp)
		timeout 90 openclaw gateway install >"$install_log" 2>&1
		install_rc=$?
		cat "$install_log"

		# 如果服务不存在或 install 返回失败，尝试 --force 重装一次。
		if [ "$install_rc" -ne 0 ] || ! systemctl --user status openclaw-gateway.service >/dev/null 2>&1; then
			echo "正在强制重装 OpenClaw Gateway 服务..."
			timeout 90 openclaw gateway install --force || {
				rm -f "$install_log"
				echo "❌ Gateway 服务安装/启动失败。"
				return 1
			}
		fi
		rm -f "$install_log"

		# install 通常会直接启动；这里再用 systemctl 兜底启动。
		systemctl --user start openclaw-gateway.service >/dev/null 2>&1 || true
		sleep 10
		if timeout 25 openclaw gateway status 2>/dev/null | grep -q "Connectivity probe: ok"; then
			echo "✅ OpenClaw Gateway 已启动并连通。"
			return 0
		fi

		echo "⚠️ Gateway 服务已安装，但暂未探测到连通，当前状态如下："
		openclaw gateway status 2>&1 | sed -n '1,100p'
		return 1
	}


	install_node_and_tools() {
		if command -v dnf &>/dev/null; then
			curl -fsSL https://rpm.nodesource.com/setup_24.x | sudo bash -
			dnf update -y
			dnf group install -y "Development Tools" "Development Libraries"
			dnf install -y cmake libatomic nodejs
		fi

		if command -v apt &>/dev/null; then
			curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
			apt update -y
			apt install build-essential python3 libatomic1 nodejs -y
		fi
	}

	sync_openclaw_api_models() {
		local config_file
		config_file=$(openclaw_get_config_file)

		[ ! -f "$config_file" ] && return 0

		install jq curl >/dev/null 2>&1

		python3 - "$config_file" "$ENABLE_STATS" "$sh_v" <<'PY'
import copy
import json
import os
import platform
import sys
import time
import urllib.request
from datetime import datetime, timezone

path = sys.argv[1]
stats_enabled = (sys.argv[2].lower() == "true") if len(sys.argv) > 2 else True
script_version = sys.argv[3] if len(sys.argv) > 3 else ""

def send_stat(action):
    if not stats_enabled:
        return
    payload = {
        "action": action,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
        "country": "",
        "os_info": platform.platform(),
        "cpu_arch": platform.machine(),
        "version": script_version,
    }
    try:
        req = urllib.request.Request(
            "https://api.kejilion.pro/api/log",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=3):
            pass
    except Exception:
        pass

with open(path, 'r', encoding='utf-8') as f:
    obj = json.load(f)

work = copy.deepcopy(obj)
models_cfg = work.setdefault('models', {})
providers = models_cfg.get('providers', {})
if not isinstance(providers, dict) or not providers:
    print('ℹ️ 未检测到 API providers，跳过模型同步')
    raise SystemExit(0)

agents = work.setdefault('agents', {})
defaults = agents.setdefault('defaults', {})
defaults_models_raw = defaults.get('models')
if isinstance(defaults_models_raw, dict):
    defaults_models = defaults_models_raw
elif isinstance(defaults_models_raw, list):
    defaults_models = {str(x): {} for x in defaults_models_raw if isinstance(x, str)}
else:
    defaults_models = {}
defaults['models'] = defaults_models

SUPPORTED_APIS = {'openai-completions', 'openai-responses'}

changed = False
fatal_errors = []
summary = []


def model_ref(provider_name, model_id):
    return f"{provider_name}/{model_id}"


def get_primary_ref(defaults_obj):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        return model_obj
    if isinstance(model_obj, dict):
        primary = model_obj.get('primary')
        if isinstance(primary, str):
            return primary
    return None


def set_primary_ref(defaults_obj, new_ref):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        defaults_obj['model'] = new_ref
    elif isinstance(model_obj, dict):
        model_obj['primary'] = new_ref
    else:
        defaults_obj['model'] = {'primary': new_ref}


def ref_provider(ref):
    if not isinstance(ref, str) or '/' not in ref:
        return None
    return ref.split('/', 1)[0]


def collect_available_refs(exclude_provider=None):
    refs = []
    if not isinstance(providers, dict):
        return refs
    for pname, p in providers.items():
        if exclude_provider and pname == exclude_provider:
            continue
        if not isinstance(p, dict):
            continue
        for m in p.get('models', []) or []:
            if isinstance(m, dict) and m.get('id'):
                refs.append(model_ref(pname, str(m['id'])))
    return refs


def prompt_delete_provider(name):
    prompt = f"⚠️ {name} /models 探测连续失败 3 次。是否删除该 API 供应商及其全部相关模型？[y/N]: "
    try:
        ans = input(prompt).strip().lower()
    except EOFError:
        return False
    return ans in ('y', 'yes')


def rebind_defaults_before_delete(name):
    global changed

    replacement = None

    def get_replacement():
        nonlocal replacement
        if replacement is None:
            candidates = collect_available_refs(exclude_provider=name)
            replacement = candidates[0] if candidates else None
        return replacement

    primary_ref = get_primary_ref(defaults)
    if ref_provider(primary_ref) == name:
        repl = get_replacement()
        if not repl:
            summary.append(f'❌ {name}: 默认主模型指向该 provider，但无可用替代模型，已中止删除')
            return False
        set_primary_ref(defaults, repl)
        changed = True
        summary.append(f'🔁 删除前已切换默认主模型: {primary_ref} -> {repl}')

    for fk in ('modelFallback', 'imageModelFallback'):
        val = defaults.get(fk)
        if ref_provider(val) == name:
            repl = get_replacement()
            if not repl:
                summary.append(f'❌ {name}: {fk} 指向该 provider，但无可用替代模型，已中止删除')
                return False
            defaults[fk] = repl
            changed = True
            summary.append(f'🔁 删除前已切换 {fk}: {val} -> {repl}')

    return True


def delete_provider_and_refs(name):
    global changed

    if not rebind_defaults_before_delete(name):
        return False

    removed_refs = [r for r in list(defaults_models.keys()) if r.startswith(name + '/')]
    for r in removed_refs:
        defaults_models.pop(r, None)
    if removed_refs:
        changed = True

    if name in providers:
        providers.pop(name, None)
        changed = True

    summary.append(f'🗑️ 已删除 provider {name}，并移除 defaults.models 下 {len(removed_refs)} 个模型引用')
    return True


def fetch_remote_models_with_retry(name, base_url, api_key, retries=3):
    last_error = None
    for attempt in range(1, retries + 1):
        req = urllib.request.Request(
            base_url.rstrip('/') + '/models',
            headers={
                'Authorization': f'Bearer {api_key}',
                'User-Agent': 'Mozilla/5.0',
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                payload = resp.read().decode('utf-8', 'ignore')
            data = json.loads(payload)
            return data, None, attempt
        except Exception as e:
            last_error = e
            if attempt < retries:
                time.sleep(1)
    return None, last_error, retries


for name, provider in list(providers.items()):
    if not isinstance(provider, dict):
        summary.append(f'ℹ️ 跳过 {name}: provider 结构非法')
        continue

    api = provider.get('api', '')
    base_url = provider.get('baseUrl')
    api_key = provider.get('apiKey')
    model_list = provider.get('models', [])

    if not base_url or not api_key or not isinstance(model_list, list) or not model_list:
        summary.append(f'ℹ️ 跳过 {name}: 无 baseUrl/apiKey/models')
        continue

    if api not in SUPPORTED_APIS:
        summary.append(f'🔁 {name}: 发现非法协议 {api or "(unset)"}，将重新探测')
        provider['api'] = ''
        api = ''
        changed = True

    data, err, attempts = fetch_remote_models_with_retry(name, base_url, api_key, retries=3)
    if err is not None:
        summary.append(f'⚠️ {name}: /models 探测失败，已重试 {attempts} 次 ({type(err).__name__}: {err})')
        send_stat('OpenClaw API确认介入')
        if prompt_delete_provider(name):
            deleted = delete_provider_and_refs(name)
            if deleted:
                send_stat('OpenClaw API删失败Provider-确认')
                summary.append(f'✅ {name}: 用户已确认删除该 provider 及全部相关模型引用')
        else:
            send_stat('OpenClaw API删失败Provider-拒绝')
            summary.append(f'ℹ️ {name}: 用户未确认删除，保留现有 provider 配置')
        continue

    if attempts > 1:
        summary.append(f'🔁 {name}: /models 第 {attempts} 次重试后成功')

    if not (isinstance(data, dict) and isinstance(data.get('data'), list)):
        summary.append(f'⚠️ 跳过 {name}: /models 返回结构不可识别')
        continue

    remote_ids = []
    for item in data['data']:
        if isinstance(item, dict) and item.get('id'):
            remote_ids.append(str(item['id']))
    remote_set = set(remote_ids)

    if not remote_set:
        fatal_errors.append(f'❌ {name} 上游 /models 为空，无法为该 provider 提供兜底模型')
        continue

    local_models = [m for m in model_list if isinstance(m, dict) and m.get('id')]
    local_ids = [str(m['id']) for m in local_models]
    local_set = set(local_ids)

    template = None
    for m in local_models:
        template = copy.deepcopy(m)
        break
    if template is None:
        summary.append(f'⚠️ 跳过 {name}: 本地 models 无有效模板模型')
        continue

    removed_ids = [mid for mid in local_ids if mid not in remote_set]
    added_ids = [mid for mid in remote_ids if mid not in local_set]

    kept_models = [copy.deepcopy(m) for m in local_models if str(m['id']) in remote_set]
    new_models = kept_models[:]

    for mid in added_ids:
        nm = copy.deepcopy(template)
        nm['id'] = mid
        if isinstance(nm.get('name'), str):
            nm['name'] = f'{name} / {mid}'
        new_models.append(nm)

    if not new_models:
        fatal_errors.append(f'❌ {name} 同步后无可用模型，无法保障默认模型/回退模型兜底')
        continue

    expected_refs = {model_ref(name, str(m['id'])) for m in new_models if isinstance(m, dict) and m.get('id')}
    local_refs = {model_ref(name, mid) for mid in local_ids}

    first_ref = model_ref(name, str(new_models[0]['id']))

    primary_ref = get_primary_ref(defaults)
    if isinstance(primary_ref, str) and primary_ref in (local_refs - expected_refs):
        set_primary_ref(defaults, first_ref)
        changed = True
        summary.append(f'🔁 默认模型已兜底替换: {primary_ref} -> {first_ref}')

    for fk in ('modelFallback', 'imageModelFallback'):
        val = defaults.get(fk)
        if isinstance(val, str) and val in (local_refs - expected_refs):
            defaults[fk] = first_ref
            changed = True
            summary.append(f'🔁 {fk} 已兜底替换: {val} -> {first_ref}')

    stale_refs = [r for r in list(defaults_models.keys()) if r.startswith(name + '/') and r not in expected_refs]
    for r in stale_refs:
        defaults_models.pop(r, None)
        changed = True

    for r in sorted(expected_refs):
        if r not in defaults_models:
            defaults_models[r] = {}
            changed = True

    if removed_ids or added_ids or len(local_models) != len(new_models):
        provider['models'] = new_models
        changed = True

    summary.append(f'✅ {name}: 新增 {len(added_ids)} 个，删除 {len(removed_ids)} 个，当前 {len(new_models)} 个')

    if added_ids:
        summary.append(f'➕ 新增模型({len(added_ids)}):')
        for mid in added_ids:
            summary.append(f'  + {mid}')
    if removed_ids:
        summary.append(f'➖ 删除模型({len(removed_ids)}):')
        for mid in removed_ids:
            summary.append(f'  - {mid}')


if fatal_errors:
    for line in summary:
        print(line)
    for err in fatal_errors:
        print(err)
    print('❌ 模型同步失败：存在 provider 同步后无可用模型，已中止写入')
    raise SystemExit(2)

if changed:
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(work, f, ensure_ascii=False, indent=2)
        f.write('\n')
    for line in summary:
        print(line)
    print('✅ OpenClaw API 模型一致性同步完成并已写入配置')
else:
    for line in summary:
        print(line)
    print('ℹ️ 无需同步：配置已与上游 /models 保持一致')
PY
	}



	install_moltbot() {
		echo "开始安装 OpenClaw..."
		send_stats "开始安装 OpenClaw..."
		install git jq

		install_node_and_tools

		country=$(curl -s ipinfo.io/country)
		if [[ "$country" == "CN" || "$country" == "HK" ]]; then
			npm config set registry https://registry.npmmirror.com
		fi

		git config --global url."${gh_proxy}github.com/".insteadOf ssh://git@github.com/
		git config --global url."${gh_proxy}github.com/".insteadOf git@github.com:

		npm install -g openclaw@latest
		openclaw onboard --install-daemon
		start_gateway
		add_app_id
		break_end

	}


	start_bot() {
		echo "启动 OpenClaw..."
		send_stats "启动 OpenClaw..."
		start_gateway
		break_end
	}

	stop_bot() {
		echo "停止 OpenClaw..."
		send_stats "停止 OpenClaw..."
		tmux kill-session -t gateway > /dev/null 2>&1
		openclaw gateway stop
		break_end
	}

	view_logs() {
		echo "查看 OpenClaw 状态日志"
		send_stats "查看 OpenClaw 日志"
		openclaw status
		openclaw gateway status
		openclaw logs
		break_end
	}





	# OpenClaw API 协议探测逻辑已移除：不再自动探测/判定 API 类型。
	# 说明：API 类型由用户显式配置（models.providers.<name>.api），脚本不再尝试调用 /responses 做推断。

	# 构造模型配置 JSON
	build-openclaw-provider-models-json() {
		local provider_name="$1"
		local model_ids="$2"
		local models_array="["
		local first=true

		while read -r model_id; do
			[ -z "$model_id" ] && continue
			[[ $first == false ]] && models_array+=","
			first=false

			local context_window=1048576
			local max_tokens=128000
			local input_cost=0.15
			local output_cost=0.60

			case "$model_id" in
				*opus*|*pro*|*preview*|*thinking*|*sonnet*)
					input_cost=2.00
					output_cost=12.00
					;;
				*gpt-5*|*codex*)
					input_cost=1.25
					output_cost=10.00
					;;
				*flash*|*lite*|*haiku*|*mini*|*nano*)
					input_cost=0.10
					output_cost=0.40
					;;
			esac

			models_array+=$(cat <<EOF
{
	"id": "$model_id",
	"name": "$provider_name / $model_id",
	"input": ["text", "image"],
	"contextWindow": $context_window,
	"maxTokens": $max_tokens,
	"cost": {
		"input": $input_cost,
		"output": $output_cost,
		"cacheRead": 0,
		"cacheWrite": 0
	}
}
EOF
)
		done <<< "$model_ids"

		models_array+="]"
		echo "$models_array"
	}

	# 写入 provider 与模型配置
	write-openclaw-provider-models() {
		local provider_name="$1"
		local base_url="$2"
		local api_key="$3"
		local models_array="$4"
		local config_file
		config_file=$(openclaw_get_config_file)

		# 不再自动探测/纠正 API 协议；保持用户配置为准
		DETECTED_API="openai-completions"

		[[ -f "$config_file" ]] && cp "$config_file" "${config_file}.bak.$(date +%s)"

		jq --arg prov "$provider_name" \
		   --arg url "$base_url" \
		   --arg key "$api_key" \
		   --arg api "$DETECTED_API" \
		   --argjson models "$models_array" \
		'
		.models |= (
			(. // { mode: "merge", providers: {} })
			| .mode = "merge"
			| .providers[$prov] = {
				baseUrl: $url,
				apiKey: $key,
				api: $api,
				models: $models
			}
		)
		| .agents |= (. // {})
		| .agents.defaults |= (. // {})
		| .agents.defaults.models |= (
			(if type == "object" then .
			 elif type == "array" then reduce .[] as $m ({}; if ($m|type) == "string" then .[$m] = {} else . end)
			 else {}
			 end) as $existing
			| reduce ($models[]? | .id? // empty | tostring) as $mid (
				$existing;
				if ($mid | length) > 0 then
					.["\($prov)/\($mid)"] //= {}
				else
					.
				end
			)
		)
		' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
	}

	# 核心函数：获取并添加所有模型
	add-all-models-from-provider() {
		local provider_name="$1"
		local base_url="$2"
		local api_key="$3"

		echo "🔍 正在获取 $provider_name 的所有可用模型..."

		local models_json=$(curl -s -m 10 \
			-H "Authorization: Bearer $api_key" \
			"${base_url}/models")

		if [[ -z "$models_json" ]]; then
			echo "❌ 无法获取模型列表"
			return 1
		fi

		local model_ids=$(echo "$models_json" | grep -oP '"id":\s*"\K[^"]+')

		if [[ -z "$model_ids" ]]; then
			echo "❌ 未找到任何模型"
			return 1
		fi

		local model_count=$(echo "$model_ids" | wc -l)
		echo "✅ 发现 $model_count 个模型"

		local models_array
		models_array=$(build-openclaw-provider-models-json "$provider_name" "$model_ids")

		write-openclaw-provider-models "$provider_name" "$base_url" "$api_key" "$models_array"

		if [[ $? -eq 0 ]]; then
			echo "✅ 成功添加 $model_count 个模型到 $provider_name"
			echo "📦 模型引用格式: $provider_name/<model-id>"
			return 0
		else
			echo "❌ 配置注入失败"
			return 1
		fi
	}

	# 仅添加默认模型并保留 provider
	add-default-model-only-to-provider() {
		local provider_name="$1"
		local base_url="$2"
		local api_key="$3"
		local default_model="$4"

		if [[ -z "$default_model" ]]; then
			echo "❌ 默认模型不能为空"
			return 1
		fi

		local models_array
		models_array=$(build-openclaw-provider-models-json "$provider_name" "$default_model")

		write-openclaw-provider-models "$provider_name" "$base_url" "$api_key" "$models_array"

		if [[ $? -eq 0 ]]; then
			echo "✅ 已添加 provider：$provider_name"
			echo "✅ 仅写入默认模型：$default_model"
			return 0
		else
			echo "❌ 配置注入失败"
			return 1
		fi
	}

	add-openclaw-provider-interactive() {
		send_stats "OpenClaw API添加"
		echo "=== 交互式添加 OpenClaw Provider (全量模型) ==="

		# 1. Provider 名称
		read -erp "请输入 Provider 名称 (如: deepseek): " provider_name
		while [[ -z "$provider_name" ]]; do
			echo "❌ Provider 名称不能为空"
			read -erp "请输入 Provider 名称: " provider_name
		done

		# 2. Base URL
		read -erp "请输入 Base URL (如: https://api.xxx.com/v1): " base_url
		while [[ -z "$base_url" ]]; do
			echo "❌ Base URL 不能为空"
			read -erp "请输入 Base URL: " base_url
		done
		base_url="${base_url%/}"

		# 3. API Key
		read -rsp "请输入 API Key (输入不显示): " api_key
		echo
		while [[ -z "$api_key" ]]; do
			echo "❌ API Key 不能为空"
			read -rsp "请输入 API Key: " api_key
			echo
		done

		# 4. 不再探测/判断 API 类型；协议由用户自行选择与维护

		# 5. 获取模型列表
		echo "🔍 正在获取可用模型列表..."
		models_json=$(curl -s -m 10 \
			-H "Authorization: Bearer $api_key" \
			"${base_url}/models")

		if [[ -n "$models_json" ]]; then
			available_models=$(echo "$models_json" | grep -oP '"id":\s*"\K[^"]+' | sort)

			if [[ -n "$available_models" ]]; then
				model_count=$(echo "$available_models" | wc -l)
				echo "✅ 发现 $model_count 个可用模型："
				echo "--------------------------------"
				# 全部显示，带序号
				i=1
				model_list=()
				while read -r model; do
					echo "[$i] $model"
					model_list+=("$model")
					((i++))
				done <<< "$available_models"
				echo "--------------------------------"
			fi
		fi

		# 5. 选择默认模型
		echo
		read -erp "请输入默认 Model ID (或序号，留空则使用第一个): " input_model

		if [[ -z "$input_model" && -n "$available_models" ]]; then
			default_model=$(echo "$available_models" | head -1)
			echo "🎯 使用第一个模型: $default_model"
		elif [[ "$input_model" =~ ^[0-9]+$ ]] && [ "${#model_list[@]}" -gt 0 ] && [ "$input_model" -ge 1 ] && [ "$input_model" -le "${#model_list[@]}" ]; then
			default_model="${model_list[$((input_model-1))]}"
			echo "🎯 已选择模型: $default_model"
		else
			default_model="$input_model"
		fi

		# 6. 确认信息
		echo
		echo "====== 确认信息 ======"
		echo "Provider    : $provider_name"
		echo "Base URL    : $base_url"
		echo "API Key     : ${api_key:0:8}****"
		echo "默认模型    : $default_model"
		echo "模型总数    : $model_count"
		echo "======================"

		read -erp "是否同时添加其他所有可用模型？(y/N): " confirm

		install jq
		if [[ "$confirm" =~ ^[Yy]$ ]]; then
			add-all-models-from-provider "$provider_name" "$base_url" "$api_key"
			add_result=$?
			finish_msg="✅ 完成！所有 $model_count 个模型已加载"
		else
			add-default-model-only-to-provider "$provider_name" "$base_url" "$api_key" "$default_model"
			add_result=$?
			finish_msg="✅ 完成！已保留 provider，并仅加载默认模型：$default_model"
		fi

		if [[ $add_result -eq 0 ]]; then
			echo
			echo "🔄 设置默认模型并重启网关..."
			openclaw models set "$provider_name/$default_model"
			openclaw_sync_sessions_model "$provider_name/$default_model"
			start_gateway
			echo "$finish_msg"
			echo "✅ 当前 API 协议类型: $DETECTED_API"
		fi

		break_end
	}



openclaw_api_manage_list() {
	local config_file="${HOME}/.openclaw/openclaw.json"
	send_stats "OpenClaw API列表"

	while IFS=$'\t' read -r rec_type idx name base_url model_count api_type latency_txt latency_level; do
		case "$rec_type" in
			MSG)
				echo "$idx"
				;;
			ROW)
				local latency_color="$gl_bai"
				case "$latency_level" in
					low) latency_color="$gl_lv" ;;
					medium) latency_color="$gl_huang" ;;
					high|unavailable) latency_color="$gl_hong" ;;
					unchecked) latency_color="$gl_bai" ;;
				esac

				printf '%b\n' "[$idx] ${name} | API: ${base_url} | 协议: ${api_type} | 模型数量: ${gl_huang}${model_count}${gl_bai} | 延迟/状态: ${latency_color}${latency_txt}${gl_bai}"
				;;
		esac
	done < <(python3 - "$config_file" <<-'PY'
import json
import sys
import time
import urllib.request

path = sys.argv[1]
SUPPORTED_APIS = {'openai-completions', 'openai-responses'}


def ping_models(base_url, api_key):
    req = urllib.request.Request(
        base_url.rstrip('/') + '/models',
        headers={
            'Authorization': f'Bearer {api_key}',
            'User-Agent': 'OpenClaw-API-Manage/1.0',
        },
    )
    start = time.perf_counter()
    with urllib.request.urlopen(req, timeout=4) as resp:
        resp.read(2048)
    return int((time.perf_counter() - start) * 1000)


def classify_latency(latency):
    if latency == '不可用':
        return '不可用', 'unavailable'
    if latency == '未检测':
        return '未检测', 'unchecked'
    if isinstance(latency, int):
        if latency <= 800:
            level = 'low'
        elif latency <= 2000:
            level = 'medium'
        else:
            level = 'high'
        return f'{latency}ms', level
    return str(latency), 'unchecked'


try:
    with open(path, 'r', encoding='utf-8') as f:
        obj = json.load(f)
except FileNotFoundError:
    print('MSG\tℹ️ 未找到 openclaw.json，请先完成安装/初始化。')
    raise SystemExit(0)
except Exception as e:
    print(f'MSG\t❌ 读取配置失败: {type(e).__name__}: {e}')
    raise SystemExit(0)

providers = ((obj.get('models') or {}).get('providers') or {})
if not isinstance(providers, dict) or not providers:
    print('MSG\tℹ️ 当前未配置任何 API provider。')
    raise SystemExit(0)

print('MSG\t--- 已配置 API 列表 ---')

for idx, name in enumerate(sorted(providers.keys()), start=1):
    provider = providers.get(name)
    if not isinstance(provider, dict):
        base_url = '-'
        model_count = 0
        latency_raw = '不可用'
    else:
        base_url = provider.get('baseUrl') or provider.get('url') or provider.get('endpoint') or '-'
        models = provider.get('models') if isinstance(provider.get('models'), list) else []
        model_count = sum(1 for m in models if isinstance(m, dict) and m.get('id'))
        api = provider.get('api', '')
        api_key = provider.get('apiKey')

        latency_raw = '未检测'
        if api in SUPPORTED_APIS:
            if isinstance(base_url, str) and base_url != '-' and isinstance(api_key, str) and api_key:
                try:
                    latency_raw = ping_models(base_url, api_key)
                except Exception:
                    latency_raw = '不可用'
            else:
                latency_raw = '不可用'

    latency_text, latency_level = classify_latency(latency_raw)
    api_label = api if api in SUPPORTED_APIS else '-'
    print(
        'ROW\t' + '\t'.join([
            str(idx),
            str(name),
            str(base_url),
            str(model_count),
            str(api_label),
            str(latency_text),
            str(latency_level),
        ])
    )
PY
)
}
sync-openclaw-provider-interactive() {
	local config_file="${HOME}/.openclaw/openclaw.json"
	send_stats "OpenClaw API按Provider同步"

	if [ ! -f "$config_file" ]; then
		echo "❌ 未找到配置文件: $config_file"
		break_end
		return 1
	fi

	read -erp "请输入要同步的 API 名称(provider)，直接回车同步全部: " provider_name
	if [ -z "$provider_name" ]; then
		if sync_openclaw_api_models; then
			start_gateway
		else
			echo "❌ API 模型同步失败，已中止重启网关。请检查 provider /models 返回后重试。"
			return 1
		fi
		break_end
		return 0
	fi

	install jq curl >/dev/null 2>&1

	python3 - "$config_file" "$provider_name" <<'PY2'
import copy
import json
import sys
import time
import urllib.request

path = sys.argv[1]
target = sys.argv[2]
SUPPORTED_APIS = {'openai-completions', 'openai-responses'}

with open(path, 'r', encoding='utf-8') as f:
    obj = json.load(f)

work = copy.deepcopy(obj)
models_cfg = work.setdefault('models', {})
providers = models_cfg.get('providers', {})
if not isinstance(providers, dict) or not providers:
    print('❌ 未检测到 API providers，无法同步')
    raise SystemExit(2)

provider = providers.get(target)
if not isinstance(provider, dict):
    print(f'❌ 未找到 provider: {target}')
    raise SystemExit(2)

agents = work.setdefault('agents', {})
defaults = agents.setdefault('defaults', {})
defaults_models_raw = defaults.get('models')
if isinstance(defaults_models_raw, dict):
    defaults_models = defaults_models_raw
elif isinstance(defaults_models_raw, list):
    defaults_models = {str(x): {} for x in defaults_models_raw if isinstance(x, str)}
else:
    defaults_models = {}
defaults['models'] = defaults_models


def model_ref(provider_name, model_id):
    return f"{provider_name}/{model_id}"


def get_primary_ref(defaults_obj):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        return model_obj
    if isinstance(model_obj, dict):
        primary = model_obj.get('primary')
        if isinstance(primary, str):
            return primary
    return None


def set_primary_ref(defaults_obj, new_ref):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        defaults_obj['model'] = new_ref
    elif isinstance(model_obj, dict):
        model_obj['primary'] = new_ref
    else:
        defaults_obj['model'] = {'primary': new_ref}


def fetch_remote_models_with_retry(base_url, api_key, retries=3):
    last_error = None
    for attempt in range(1, retries + 1):
        req = urllib.request.Request(
            base_url.rstrip('/') + '/models',
            headers={
                'Authorization': f'Bearer {api_key}',
                'User-Agent': 'Mozilla/5.0',
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                payload = resp.read().decode('utf-8', 'ignore')
            return json.loads(payload), None, attempt
        except Exception as e:
            last_error = e
            if attempt < retries:
                time.sleep(1)
    return None, last_error, retries


api = provider.get('api', '')
base_url = provider.get('baseUrl')
api_key = provider.get('apiKey')
model_list = provider.get('models', [])

if not base_url or not api_key or not isinstance(model_list, list) or not model_list:
    print(f'❌ provider {target} 缺少 baseUrl/apiKey/models，无法执行同步')
    raise SystemExit(3)

if api not in SUPPORTED_APIS:
    print(f'ℹ️ provider {target} 当前 api={api}，但脚本已不再探测/纠正协议；请手动设置为 openai-completions 或 openai-responses')

protocol_msg = None

data, err, attempts = fetch_remote_models_with_retry(base_url, api_key, retries=3)
if err is not None:
    print(f'❌ {target}: /models 探测失败，已重试 {attempts} 次 ({type(err).__name__}: {err})')
    raise SystemExit(4)

if not (isinstance(data, dict) and isinstance(data.get('data'), list)):
    print(f'❌ {target}: /models 返回结构不可识别')
    raise SystemExit(4)

remote_ids = []
for item in data['data']:
    if isinstance(item, dict) and item.get('id'):
        remote_ids.append(str(item['id']))
remote_set = set(remote_ids)
if not remote_set:
    print(f'❌ {target}: 上游 /models 为空，已中止同步')
    raise SystemExit(5)

local_models = [m for m in model_list if isinstance(m, dict) and m.get('id')]
local_ids = [str(m['id']) for m in local_models]
local_set = set(local_ids)

template = copy.deepcopy(local_models[0]) if local_models else None
if template is None:
    print(f'❌ {target}: 本地 models 无有效模板模型，无法补全新增模型')
    raise SystemExit(3)

removed_ids = [mid for mid in local_ids if mid not in remote_set]
added_ids = [mid for mid in remote_ids if mid not in local_set]

kept_models = [copy.deepcopy(m) for m in local_models if str(m['id']) in remote_set]
new_models = kept_models[:]
for mid in added_ids:
    nm = copy.deepcopy(template)
    nm['id'] = mid
    if isinstance(nm.get('name'), str):
        nm['name'] = f'{target} / {mid}'
    new_models.append(nm)

if not new_models:
    print(f'❌ {target}: 同步后无可用模型，已中止写入')
    raise SystemExit(5)

expected_refs = {model_ref(target, str(m['id'])) for m in new_models if isinstance(m, dict) and m.get('id')}
local_refs = {model_ref(target, mid) for mid in local_ids}
removed_refs = local_refs - expected_refs
first_ref = model_ref(target, str(new_models[0]['id']))

changed = False
primary_ref = get_primary_ref(defaults)
if isinstance(primary_ref, str) and primary_ref in removed_refs:
    set_primary_ref(defaults, first_ref)
    changed = True
    print(f'🔁 默认模型已兜底替换: {primary_ref} -> {first_ref}')

for fk in ('modelFallback', 'imageModelFallback'):
    val = defaults.get(fk)
    if isinstance(val, str) and val in removed_refs:
        defaults[fk] = first_ref
        changed = True
        print(f'🔁 {fk} 已兜底替换: {val} -> {first_ref}')

stale_refs = [r for r in list(defaults_models.keys()) if r.startswith(target + '/') and r not in expected_refs]
for r in stale_refs:
    defaults_models.pop(r, None)
    changed = True

for r in sorted(expected_refs):
    if r not in defaults_models:
        defaults_models[r] = {}
        changed = True

if removed_ids or added_ids or len(local_models) != len(new_models):
    provider['models'] = new_models
    changed = True


if changed:
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(work, f, ensure_ascii=False, indent=2)
        f.write('\n')

print(f'✅ {target}: 新增 {len(added_ids)} 个，删除 {len(removed_ids)} 个，当前 {len(new_models)} 个')

if added_ids:
    print(f'➕ 新增模型({len(added_ids)}):')
    for mid in added_ids:
        print(f'  + {mid}')
if removed_ids:
    print(f'➖ 删除模型({len(removed_ids)}):')
    for mid in removed_ids:
        print(f'  - {mid}')

if changed:
    print('✅ 指定 provider 模型一致性同步完成并已写入配置')
else:
    print('ℹ️ 无需同步：该 provider 配置已与上游 /models 保持一致')
PY2
	local rc=$?
	case "$rc" in
		0)
			echo "✅ 同步执行完成"
			start_gateway
			;;
		2)
			echo "❌ 同步失败：provider 不存在或未配置"
			;;
		3)
			echo "❌ 同步失败：provider 配置不完整或类型不支持"
			;;
		4)
			echo "❌ 同步失败：上游 /models 请求失败"
			;;
		5)
			echo "❌ 同步失败：上游模型为空或同步后无可用模型"
			;;
		*)
			echo "❌ 同步失败：请检查配置文件结构或日志输出"
			;;
	esac

	break_end
}

openclaw_detect_api_protocol_by_provider() {
	# 协议探测逻辑已移除：脚本不再自动探测/判定 API 类型。
	# 保留函数以兼容菜单调用，但不做任何改写。
	echo "ℹ️ 已关闭协议探测：请手动在 ${HOME}/.openclaw/openclaw.json 中设置 provider.api 为 openai-completions 或 openai-responses"
	return 0
}

fix-openclaw-provider-protocol-interactive() {
	local config_file="${HOME}/.openclaw/openclaw.json"
	send_stats "OpenClaw API协议切换"

	if [ ! -f "$config_file" ]; then
		echo "❌ 未找到配置文件: $config_file"
		break_end
		return 1
	fi

	read -erp "请输入要切换协议的 API 名称(provider): " provider_name
	if [ -z "$provider_name" ]; then
		echo "❌ provider 名称不能为空"
		break_end
		return 1
	fi

	echo "请选择要设置的 API 类型："
	echo "1. openai-completions"
	echo "2. openai-responses"
	read -erp "请输入你的选择 (1/2): " proto_choice

	local new_api=""
	case "$proto_choice" in
		1) new_api="openai-completions" ;;
		2) new_api="openai-responses" ;;
		*)
			echo "❌ 无效选择"
			break_end
			return 1
			;;
	esac

	install python3 >/dev/null 2>&1

	python3 - "$config_file" "$provider_name" "$new_api" <<'PY'
import copy
import json
import sys

path = sys.argv[1]
name = sys.argv[2]
new_api = sys.argv[3]

SUPPORTED_APIS = {'openai-completions', 'openai-responses'}
if new_api not in SUPPORTED_APIS:
    print('❌ 非法协议值')
    raise SystemExit(3)

with open(path, 'r', encoding='utf-8') as f:
    obj = json.load(f)

work = copy.deepcopy(obj)
providers = ((work.get('models') or {}).get('providers') or {})
if not isinstance(providers, dict) or name not in providers or not isinstance(providers.get(name), dict):
    print(f'❌ 未找到 provider: {name}')
    raise SystemExit(2)

providers[name]['api'] = new_api

with open(path, 'w', encoding='utf-8') as f:
    json.dump(work, f, ensure_ascii=False, indent=2)
    f.write('\n')

print(f'✅ 已更新 provider {name} 协议为: {new_api}')
PY
	local rc=$?
	case "$rc" in
		0)
			start_gateway
			;;
		2)
			echo "❌ 切换失败：provider 不存在或未配置"
			;;
		3)
			echo "❌ 切换失败：协议值非法"
			;;
		*)
			echo "❌ 切换失败：请检查配置文件结构或日志输出"
			;;
	esac

	break_end
}

	delete-openclaw-provider-interactive() {
		local config_file
		config_file=$(openclaw_get_config_file)
		send_stats "OpenClaw API删除入口"

		if [ ! -f "$config_file" ]; then
			echo "❌ 未找到配置文件: $config_file"
			break_end
			return 1
		fi

		read -erp "请输入要删除的 API 名称(provider): " provider_name
		if [ -z "$provider_name" ]; then
			send_stats "OpenClaw API删除取消"
			echo "❌ provider 名称不能为空"
			break_end
			return 1
		fi

		python3 - "$config_file" "$provider_name" <<'PY'
import copy
import json
import sys

path = sys.argv[1]
name = sys.argv[2]

with open(path, 'r', encoding='utf-8') as f:
    obj = json.load(f)

work = copy.deepcopy(obj)
models_cfg = work.setdefault('models', {})
providers = models_cfg.get('providers', {})
if not isinstance(providers, dict) or name not in providers:
    print(f'❌ 未找到 provider: {name}')
    raise SystemExit(2)

agents = work.setdefault('agents', {})
defaults = agents.setdefault('defaults', {})
defaults_models_raw = defaults.get('models')
if isinstance(defaults_models_raw, dict):
    defaults_models = defaults_models_raw
elif isinstance(defaults_models_raw, list):
    defaults_models = {str(x): {} for x in defaults_models_raw if isinstance(x, str)}
else:
    defaults_models = {}
defaults['models'] = defaults_models


def model_ref(provider_name, model_id):
    return f"{provider_name}/{model_id}"


def ref_provider(ref):
    if not isinstance(ref, str) or '/' not in ref:
        return None
    return ref.split('/', 1)[0]


def get_primary_ref(defaults_obj):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        return model_obj
    if isinstance(model_obj, dict):
        primary = model_obj.get('primary')
        if isinstance(primary, str):
            return primary
    return None


def set_primary_ref(defaults_obj, new_ref):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        defaults_obj['model'] = new_ref
    elif isinstance(model_obj, dict):
        model_obj['primary'] = new_ref
    else:
        defaults_obj['model'] = {'primary': new_ref}


def collect_available_refs(exclude_provider=None):
    refs = []
    if not isinstance(providers, dict):
        return refs
    for pname, p in providers.items():
        if exclude_provider and pname == exclude_provider:
            continue
        if not isinstance(p, dict):
            continue
        for m in p.get('models', []) or []:
            if isinstance(m, dict) and m.get('id'):
                refs.append(model_ref(pname, str(m['id'])))
    return refs


replacement_candidates = collect_available_refs(exclude_provider=name)
replacement = replacement_candidates[0] if replacement_candidates else None

primary_ref = get_primary_ref(defaults)
if ref_provider(primary_ref) == name:
    if not replacement:
        print('❌ 删除中止：默认主模型指向该 provider，且无可用替代模型')
        raise SystemExit(3)
    set_primary_ref(defaults, replacement)
    print(f'🔁 默认主模型切换: {primary_ref} -> {replacement}')

for fk in ('modelFallback', 'imageModelFallback'):
    val = defaults.get(fk)
    if ref_provider(val) == name:
        if not replacement:
            print(f'❌ 删除中止：{fk} 指向该 provider，且无可用替代模型')
            raise SystemExit(3)
        defaults[fk] = replacement
        print(f'🔁 {fk} 切换: {val} -> {replacement}')

removed_refs = [r for r in list(defaults_models.keys()) if r.startswith(name + '/')]
for r in removed_refs:
    defaults_models.pop(r, None)

providers.pop(name, None)

with open(path, 'w', encoding='utf-8') as f:
    json.dump(work, f, ensure_ascii=False, indent=2)
    f.write('\n')

print(f'🗑️ 已删除 provider: {name}')
print(f'🧹 已清理 defaults.models 中 {len(removed_refs)} 个关联模型引用')
PY
		local rc=$?
		case "$rc" in
			0)
				send_stats "OpenClaw API删除确认"
				echo "✅ 删除完成"
				start_gateway
				;;
			2)
				echo "❌ 删除失败：provider 不存在"
				;;
			3)
				send_stats "OpenClaw API删除取消"
				echo "❌ 删除失败：无可用替代模型，已保持原配置"
				;;
			*)
				echo "❌ 删除失败：请检查配置文件结构或日志输出"
				;;
		esac

		break_end
	}

	openclaw_api_providers_showcase() {
		send_stats "OpenClaw API厂商推荐"

		clear
		echo ""
		echo -e "${gl_kjlan}╔════════════════════════════════════════════════════════════╗${gl_bai}"
		echo -e "${gl_kjlan}║${gl_bai}            ${gl_huang}🌟 API 厂商推荐列表${gl_bai}                          ${gl_kjlan}║${gl_bai}"
		echo -e "${gl_kjlan}║${gl_bai}            ${gl_zi}部分入口含 AFF${gl_bai}                            ${gl_kjlan}║${gl_bai}"
		echo -e "${gl_kjlan}╚════════════════════════════════════════════════════════════╝${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● DeepSeek${gl_bai}"
		echo -e "    ${gl_kjlan}https://api-docs.deepseek.com/${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● OpenRouter${gl_bai}"
		echo -e "    ${gl_kjlan}https://openrouter.ai/${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● Kimi${gl_bai}"
		echo -e "    ${gl_kjlan}https://platform.moonshot.cn/docs/guide/start-using-kimi-api${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● 超算互联网${gl_bai}"
		echo -e "    ${gl_kjlan}https://www.scnet.cn/${gl_bai}"
		echo ""
		echo -e "  ${gl_huang}● 优云智算${gl_bai} ${gl_zi}[AFF]${gl_bai}"
		echo -e "    ${gl_kjlan}https://passport.compshare.cn/register?referral_code=4mscFZXfutfFi8swMVsPuf${gl_bai}"
		echo ""
		echo -e "  ${gl_huang}● 硅基流动${gl_bai} ${gl_zi}[AFF]${gl_bai}"
		echo -e "    ${gl_kjlan}https://cloud.siliconflow.cn/i/irWVdPic${gl_bai}"
		echo ""
		echo -e "  ${gl_huang}● 智谱 GLM${gl_bai} ${gl_zi}[AFF]${gl_bai}"
		echo -e "    ${gl_kjlan}https://www.bigmodel.cn/glm-coding?ic=HYOTDOAJMR${gl_bai}"
		echo ""
		echo -e "  ${gl_huang}● PackyAPI${gl_bai} ${gl_zi}[AFF]${gl_bai}"
		echo -e "    ${gl_kjlan}https://www.packyapi.com/register?aff=wHri${gl_bai}"
		echo ""
		echo -e "  ${gl_huang}● 云雾 API${gl_bai} ${gl_zi}[AFF]${gl_bai}"
		echo -e "    ${gl_kjlan}https://yunwu.ai/register?aff=ZuyK${gl_bai}"
		echo ""
		echo -e "  ${gl_huang}● 柏拉图AI${gl_bai} ${gl_zi}[AFF]${gl_bai}"
		echo -e "    ${gl_kjlan}https://api.bltcy.ai/register?aff=TBzb114019${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● MiniMax${gl_bai}"
		echo -e "    ${gl_kjlan}https://www.minimaxi.com/${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● NVIDIA${gl_bai}"
		echo -e "    ${gl_kjlan}https://build.nvidia.com/settings/api-keys${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● Ollama${gl_bai}"
		echo -e "    ${gl_kjlan}https://ollama.com/${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● 白山云${gl_bai}"
		echo -e "    ${gl_kjlan}https://ai.baishan.com/${gl_bai}"
		echo ""
		echo -e "${gl_kjlan}────────────────────────────────────────────────────────────${gl_bai}"
		echo -e "  ${gl_zi}图例：${gl_lv}● 官方入口${gl_bai}  ${gl_huang}● AFF 推荐入口${gl_bai}"
		echo ""
		echo -e "${gl_huang}提示：复制链接到浏览器打开即可访问${gl_bai}"
		echo ""
		read -erp "按回车键返回..." dummy
	}

	openclaw_api_manage_menu() {
		send_stats "OpenClaw API入口"
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw API 管理"
			echo "======================================="
			openclaw_api_manage_list
			echo "---------------------------------------"
			echo "1. 添加API"
			echo "2. 同步API供应商模型列表"
			echo "3. 切换 API 类型（completions / responses）"
			echo "4. 删除API"
			echo "5. API 厂商推荐"
			echo "0. 退出"
			echo "---------------------------------------"
			read -erp "请输入你的选择: " api_choice

			case "$api_choice" in
				1)
					add-openclaw-provider-interactive
					;;
				2)
					sync-openclaw-provider-interactive
					;;
				3)
					fix-openclaw-provider-protocol-interactive
					;;
				4)
					delete-openclaw-provider-interactive
					;;
				5)
					openclaw_api_providers_showcase
					;;
				0)
					return 0
					;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}



	install_gum() {
	    if command -v gum >/dev/null 2>&1; then
	        return 0
	    fi

 		if command -v apt >/dev/null 2>&1; then
	        mkdir -p /etc/apt/keyrings
	        curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
	        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list > /dev/null
	        apt update && apt install -y gum
	    elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
	        cat > /etc/yum.repos.d/charm.repo <<'REPO'
[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key
REPO
	        rpm --import https://repo.charm.sh/yum/gpg.key
	        if command -v dnf >/dev/null 2>&1; then
	            dnf install -y gum
	        else
	            yum install -y gum
	        fi
	    elif command -v zypper >/dev/null 2>&1; then
	        zypper --non-interactive refresh
	        zypper --non-interactive install gum
	    fi
	}



	change_model() {
		send_stats "换模型"

		local orange="#FF8C00"

		openclaw_probe_status_line() {
			local status_text="$1"
			local status_color_ok='[32m'
			local status_color_fail='[31m'
			local status_color_reset='[0m'
			if [ "$status_text" = "可用" ]; then
				printf "%b最小检测结果：%s%b
" "$status_color_ok" "$status_text" "$status_color_reset"
			else
				printf "%b最小检测结果：%s%b
" "$status_color_fail" "$status_text" "$status_color_reset"
			fi
		}

		openclaw_model_probe() {
			local target_model="$1"
			local probe_timeout=25
			local tmp_payload tmp_response probe_result probe_status reply_preview reply_trimmed
			local oc_config provider_name base_url api_key request_model
			local first_endpoint second_endpoint
			local first_exit first_http first_latency second_exit second_http second_latency
			local first_reply second_reply

			oc_config=$(openclaw_get_config_file)
			[ ! -f "$oc_config" ] && {
				OPENCLAW_PROBE_STATUS="ERROR"
				OPENCLAW_PROBE_MESSAGE="未找到 openclaw 配置文件"
				OPENCLAW_PROBE_LATENCY="-"
				OPENCLAW_PROBE_REPLY="-"
				return 1
			}

			provider_name="${target_model%%/*}"
			request_model="${target_model#*/}"
			base_url=$(jq -r --arg provider "$provider_name" '.models.providers[$provider].baseUrl // empty' "$oc_config" 2>/dev/null)
			api_key=$(jq -r --arg provider "$provider_name" '.models.providers[$provider].apiKey // empty' "$oc_config" 2>/dev/null)
			if [ -z "$provider_name" ] || [ -z "$base_url" ] || [ -z "$api_key" ]; then
				OPENCLAW_PROBE_STATUS="ERROR"
				OPENCLAW_PROBE_MESSAGE="未读取到 provider/baseUrl/apiKey"
				OPENCLAW_PROBE_LATENCY="-"
				OPENCLAW_PROBE_REPLY="-"
				return 1
			fi

			base_url="${base_url%/}"
			first_endpoint="/responses"
			second_endpoint="/chat/completions"

			openclaw_extract_probe_reply() {
				python3 - "$1" <<'PYTHON_EOF'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
raw = path.read_text(encoding='utf-8', errors='replace').strip()
reply = ''
if raw:
    try:
        data = json.loads(raw)
        if isinstance(data, dict):
            choices = data.get('choices') or []
            if choices and isinstance(choices[0], dict):
                message = choices[0].get('message') or {}
                if isinstance(message, dict):
                    reply = message.get('content') or ''
            if not reply:
                output = data.get('output') or []
                if isinstance(output, list):
                    texts = []
                    for item in output:
                        if not isinstance(item, dict):
                            continue
                        for content in item.get('content') or []:
                            if not isinstance(content, dict):
                                continue
                            text = content.get('text')
                            if isinstance(text, str) and text.strip():
                                texts.append(text.strip())
                        if texts:
                            break
                    if texts:
                        reply = ' '.join(texts)
            if not reply:
                for key in ('error', 'message', 'detail'):
                    value = data.get(key)
                    if isinstance(value, str) and value.strip():
                        reply = value.strip()
                        break
                    if isinstance(value, dict):
                        nested = value.get('message')
                        if isinstance(nested, str) and nested.strip():
                            reply = nested.strip()
                            break
    except Exception:
        reply = raw
reply = ' '.join(str(reply).split())
print(reply)
PYTHON_EOF
			}

			openclaw_run_probe() {
				local endpoint="$1"
				tmp_payload=$(mktemp)
				tmp_response=$(mktemp)
				if [ "$endpoint" = "/responses" ]; then
					printf '{"model":"%s","input":"hi","temperature":0,"max_output_tokens":16}' "$request_model" > "$tmp_payload"
				else
					printf '{"model":"%s","messages":[{"role":"user","content":"hi"}],"temperature":0,"max_tokens":16}' "$request_model" > "$tmp_payload"
				fi

				probe_result=$(python3 - "$base_url" "$api_key" "$tmp_payload" "$tmp_response" "$probe_timeout" "$endpoint" <<'PYTHON_EOF'
import sys
import time
import urllib.error
import urllib.request

base_url, api_key, payload_path, response_path, timeout, endpoint = sys.argv[1:7]
timeout = int(timeout)
url = base_url + endpoint
payload = open(payload_path, 'rb').read()
req = urllib.request.Request(
    url,
    data=payload,
    headers={
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {api_key}',
    },
    method='POST',
)
start = time.time()
body = b''
status = 0
exit_code = 0
try:
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        status = getattr(resp, 'status', 200)
        body = resp.read()
except urllib.error.HTTPError as e:
    status = getattr(e, 'code', 0) or 0
    body = e.read()
    exit_code = 22
except Exception as e:
    body = str(e).encode('utf-8', errors='replace')
    exit_code = 1
elapsed = int((time.time() - start) * 1000)
with open(response_path, 'wb') as f:
    f.write(body)
print(f"{exit_code}|{status}|{elapsed}")
PYTHON_EOF
)
				probe_status=$?
				reply_preview=$(openclaw_extract_probe_reply "$tmp_response")
				rm -f "$tmp_payload" "$tmp_response"
				return $probe_status
			}

			openclaw_run_probe "$first_endpoint"
			first_exit=${probe_result%%|*}
			first_http=${probe_result#*|}
			first_http=${first_http%%|*}
			first_latency=${probe_result##*|}
			first_reply="$reply_preview"

			reply_trimmed=$(printf '%s' "$first_reply" | cut -c1-120)
			[ -z "$reply_trimmed" ] && reply_trimmed="(空返回)"

			if [ "$first_exit" = "0" ] && [ "$first_http" -ge 200 ] && [ "$first_http" -lt 300 ]; then
				OPENCLAW_PROBE_STATUS="OK"
				OPENCLAW_PROBE_MESSAGE="${first_endpoint} -> HTTP ${first_http}"
				OPENCLAW_PROBE_LATENCY="${first_latency}ms"
				OPENCLAW_PROBE_REPLY="$reply_trimmed"
				return 0
			fi

			openclaw_run_probe "$second_endpoint"
			second_exit=${probe_result%%|*}
			second_http=${probe_result#*|}
			second_http=${second_http%%|*}
			second_latency=${probe_result##*|}
			second_reply="$reply_preview"

			reply_trimmed=$(printf '%s' "$second_reply" | cut -c1-120)
			[ -z "$reply_trimmed" ] && reply_trimmed="(空返回)"

			if [ "$second_exit" = "0" ] && [ "$second_http" -ge 200 ] && [ "$second_http" -lt 300 ]; then
				OPENCLAW_PROBE_STATUS="OK"
				OPENCLAW_PROBE_MESSAGE="${first_endpoint} -> HTTP ${first_http:-0}，切换 ${second_endpoint} -> HTTP ${second_http}"
				OPENCLAW_PROBE_LATENCY="${second_latency}ms"
				OPENCLAW_PROBE_REPLY="$reply_trimmed"
				return 0
			fi

			reply_trimmed=$(printf '%s' "$first_reply" | cut -c1-120)
			[ -z "$reply_trimmed" ] && reply_trimmed=$(printf '%s' "$second_reply" | cut -c1-120)
			[ -z "$reply_trimmed" ] && reply_trimmed="(空返回)"

			OPENCLAW_PROBE_STATUS="FAIL"
			OPENCLAW_PROBE_MESSAGE="${first_endpoint} -> HTTP ${first_http:-0} / exit ${first_exit:-1}；${second_endpoint} -> HTTP ${second_http:-0} / exit ${second_exit:-1}"
			OPENCLAW_PROBE_LATENCY="${first_latency:-?}ms -> ${second_latency:-?}ms"
			OPENCLAW_PROBE_REPLY="$reply_trimmed"
			return 1
		}

		clear

		while true; do
			local models_raw models_list default_model model_count selected_model confirm_switch

			# 从配置文件读取模型键（不调用 openclaw models list）
			local oc_config
			oc_config=$(openclaw_get_config_file)

			models_raw=$(jq -r '[.models.providers // {} | to_entries[] | .key as $p | .value.models // [] | .[] | "\($p)/\(.id)"] | sort[] // empty' "$oc_config" 2>/dev/null | sed '/^\s*$/d')
			if [ -z "$models_raw" ]; then
				echo "获取模型列表失败：配置文件中未找到 models.providers。"
				break_end
				return 1
			fi

			# 为每个模型加编号，便于快速定位（例如："(10) or-api/...:free"）
			models_list=$(echo "$models_raw" | awk '{print "(" NR ") " $0}')
			model_count=$(echo "$models_list" | sed '/^\s*$/d' | wc -l | tr -d ' ')

			# 从配置文件读取默认模型（更快）；失败再回退到 openclaw 命令
			default_model=$(jq -r '.agents.defaults.model.primary // empty' "$oc_config" 2>/dev/null)
			[ -z "$default_model" ] && default_model="(unknown)"

			clear

			install_gum
			install gum

			# 若 gum 不存在，降级为原始手动输入流程
			if ! command -v gum >/dev/null 2>&1 || ! gum --version >/dev/null 2>&1; then
				echo "--- 模型管理 ---"
				echo "当前可用模型:"
				jq -r '[.models.providers // {} | to_entries[] | .key as $p | .value.models // [] | .[] | "\($p)/\(.id)"] | sort[] // empty' "$oc_config" 2>/dev/null | sed '/^\s*$/d'
				echo "----------------"
				read -e -p "请输入要设置的模型名称 (例如 openrouter/openai/gpt-4o)（输入 0 退出）： " selected_model

				if [ "$selected_model" = "0" ]; then
					echo "操作已取消，正在退出..."
					break
				fi

				if [ -z "$selected_model" ]; then
					echo "错误：模型名称不能为空。请重试。"
					echo ""
					continue
				fi

				echo "正在切换模型为: $selected_model ..."
				if ! openclaw models set "$selected_model"; then
					echo "切换失败：openclaw models set 返回错误。"
					break_end
					return 1
				fi
				openclaw_sync_sessions_model "$selected_model"
				start_gateway

				break_end
				return 0
			else
				if ! command -v gum >/dev/null 2>&1 || ! gum --version >/dev/null 2>&1; then
					echo "gum 不可用，返回旧版输入模式。"
					sleep 1
					continue
				fi
				gum style --foreground "$orange" --bold "模型管理"
				gum style --foreground "$orange" "可用模型（Auth=yes）：${model_count}"
				gum style --foreground "$orange" "当前默认：${default_model}"
				echo ""
				gum style --faint "↑↓ 选择 / Enter 测试 / Esc 退出"
				echo ""

				selected_model=$(echo "$models_list" | gum filter 					--placeholder "搜索模型（如 cli-api/gpt-5.2）" 					--prompt "选择模型 > " 					--indicator "➜ " 					--prompt.foreground "$orange" 					--indicator.foreground "$orange" 					--cursor-text.foreground "$orange" 					--match.foreground "$orange" 					--header "" 					--height 35)

				if [ -z "$selected_model" ] || echo "$selected_model" | head -n 1 | grep -iqE '^(error|usage|gum:)'; then
					echo "操作已取消，正在退出..."
					break
				fi
			fi

			selected_model=$(echo "$selected_model" | sed -E 's/^\([0-9]+\)[[:space:]]+//')

			echo ""
			echo "正在检测模型: $selected_model"
			if openclaw_model_probe "$selected_model"; then
				openclaw_probe_status_line "可用"
			else
				openclaw_probe_status_line "不可用"
			fi
			echo "状态：$OPENCLAW_PROBE_MESSAGE"
			echo "延迟：$OPENCLAW_PROBE_LATENCY"
			echo "摘要：$OPENCLAW_PROBE_REPLY"
			echo ""

			printf "是否切换到该模型？[y/N，Esc 返回列表]: "
			IFS= read -rsn1 confirm_switch
			echo ""
			if [ "$confirm_switch" = $'' ]; then
				confirm_switch="no"
			else
				case "$confirm_switch" in
					[yY])
						IFS= read -rsn1 -t 5 _enter_key
						confirm_switch="yes"
						;;
					[nN]|"") confirm_switch="no" ;;
					*) confirm_switch="no" ;;
				esac
			fi

			if [ "$confirm_switch" != "yes" ]; then
				echo "已返回模型选择列表。"
				sleep 1
				continue
			fi

			echo "正在切换模型为: $selected_model ..."
			if ! openclaw models set "$selected_model"; then
				echo "切换失败：openclaw models set 返回错误。"
				break_end
				return 1
			fi
			openclaw_sync_sessions_model "$selected_model"
			start_gateway

			break_end
			done
		}


		openclaw_get_config_file() {
			local user_config="${HOME}/.openclaw/openclaw.json"
			local root_config="/root/.openclaw/openclaw.json"
			if [ -f "$user_config" ]; then
				echo "$user_config"
			elif [ "$HOME" = "/root" ] && [ -f "$root_config" ]; then
				echo "$root_config"
			else
				echo "$user_config"
			fi
		}

		openclaw_get_agents_dir() {
			local user_agents="${HOME}/.openclaw/agents"
			local root_agents="/root/.openclaw/agents"
			if [ -d "$user_agents" ]; then
				echo "$user_agents"
			elif [ "$HOME" = "/root" ] && [ -d "$root_agents" ]; then
				echo "$root_agents"
			else
				echo "$user_agents"
			fi
		}

		openclaw_sync_sessions_model() {
			local model_ref="$1"
			[ -z "$model_ref" ] && return 1

			local agents_dir
			agents_dir=$(openclaw_get_agents_dir)
			[ ! -d "$agents_dir" ] && return 0

			local provider="${model_ref%%/*}"
			local model="${model_ref#*/}"
			[ "$provider" = "$model_ref" ] && { provider=""; model="$model_ref"; }

			local count=0
			local agent_dir sessions_file backup_file

			for agent_dir in "$agents_dir"/*/; do
				[ ! -d "$agent_dir" ] && continue
				sessions_file="$agent_dir/sessions/sessions.json"
				[ ! -f "$sessions_file" ] && continue

				backup_file="${sessions_file}.bak"
				cp "$sessions_file" "$backup_file" 2>/dev/null || continue

				if command -v jq >/dev/null 2>&1; then
					local tmp_json
					tmp_json=$(mktemp)
					if [ -n "$provider" ]; then
						jq --arg model "$model" --arg provider "$provider" \
							'to_entries | map(.value.modelOverride = $model | .value.providerOverride = $provider) | from_entries' \
							"$sessions_file" > "$tmp_json" 2>/dev/null && \
							mv "$tmp_json" "$sessions_file" && \
							count=$((count + 1))
					else
						jq --arg model "$model" \
							'to_entries | map(.value.modelOverride = $model | del(.value.providerOverride)) | from_entries' \
							"$sessions_file" > "$tmp_json" 2>/dev/null && \
							mv "$tmp_json" "$sessions_file" && \
							count=$((count + 1))
					fi
				fi
			done

			[ "$count" -gt 0 ] && echo "✅ 已同步 $count 个 agent 的会话模型为 $model_ref"
			return 0
		}

		resolve_openclaw_plugin_id() {
			local raw_input="$1"
			local plugin_id="$raw_input"

			plugin_id="${plugin_id#@openclaw/}"
			if [[ "$plugin_id" == @*/* ]]; then
				plugin_id="${plugin_id##*/}"
			fi
			plugin_id="${plugin_id%%@*}"
			echo "$plugin_id"
		}

		sync_openclaw_plugin_allowlist() {
			local plugin_id="$1"
			[ -z "$plugin_id" ] && return 1

			local config_file
			config_file=$(openclaw_get_config_file)

			mkdir -p "$(dirname "$config_file")"
			if [ ! -s "$config_file" ]; then
				echo '{}' > "$config_file"
			fi

			if command -v jq >/dev/null 2>&1; then
				local tmp_json
				tmp_json=$(mktemp)
				if jq --arg pid "$plugin_id" '
					.plugins = (if (.plugins | type) == "object" then .plugins else {} end)
					| .plugins.allow = (if (.plugins.allow | type) == "array" then .plugins.allow else [] end)
					| if (.plugins.allow | index($pid)) == null then .plugins.allow += [$pid] else . end
				' "$config_file" > "$tmp_json" 2>/dev/null && mv "$tmp_json" "$config_file"; then
					echo "✅ 已同步 plugins.allow 白名单: $plugin_id"
					return 0
				fi
				rm -f "$tmp_json"
			fi

			if command -v python3 >/dev/null 2>&1; then
				if python3 - "$config_file" "$plugin_id" <<'PYTHON_EOF'
import json
import sys
from pathlib import Path

config_file = Path(sys.argv[1])
plugin_id = sys.argv[2]

try:
    data = json.loads(config_file.read_text(encoding='utf-8')) if config_file.exists() else {}
    if not isinstance(data, dict):
        data = {}
except Exception:
    data = {}

plugins = data.get('plugins')
if not isinstance(plugins, dict):
    plugins = {}

a = plugins.get('allow')
if not isinstance(a, list):
    a = []

if plugin_id not in a:
    a.append(plugin_id)

plugins['allow'] = a
data['plugins'] = plugins
config_file.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding='utf-8')
PYTHON_EOF
				then
					echo "✅ 已同步 plugins.allow 白名单: $plugin_id"
					return 0
				fi
			fi

			echo "⚠️ 已安装插件，但同步 plugins.allow 失败，请手动检查: $config_file"
			return 1
		}

		sync_openclaw_plugin_denylist() {
			local plugin_id="$1"
			[ -z "$plugin_id" ] && return 1

			local config_file
			config_file=$(openclaw_get_config_file)

			mkdir -p "$(dirname "$config_file")"
			if [ ! -s "$config_file" ]; then
				echo '{}' > "$config_file"
			fi

			if command -v jq >/dev/null 2>&1; then
				local tmp_json
				tmp_json=$(mktemp)
				if jq --arg pid "$plugin_id" '
					.plugins = (if (.plugins | type) == "object" then .plugins else {} end)
					| .plugins.allow = (if (.plugins.allow | type) == "array" then .plugins.allow else [] end)
					| .plugins.allow = (.plugins.allow | map(select(. != $pid)))
				' "$config_file" > "$tmp_json" 2>/dev/null && mv "$tmp_json" "$config_file"; then
					echo "✅ 已从 plugins.allow 移除: $plugin_id"
					return 0
				fi
				rm -f "$tmp_json"
			fi

			if command -v python3 >/dev/null 2>&1; then
				if python3 - "$config_file" "$plugin_id" <<'PYTHON_EOF'
import json
import sys
from pathlib import Path

config_file = Path(sys.argv[1])
plugin_id = sys.argv[2]

try:
    data = json.loads(config_file.read_text(encoding='utf-8')) if config_file.exists() else {}
    if not isinstance(data, dict):
        data = {}
except Exception:
    data = {}

plugins = data.get('plugins')
if not isinstance(plugins, dict):
    plugins = {}

a = plugins.get('allow')
if not isinstance(a, list):
    a = []

a = [x for x in a if x != plugin_id]
plugins['allow'] = a
data['plugins'] = plugins
config_file.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding='utf-8')
PYTHON_EOF
				then
					echo "✅ 已从 plugins.allow 移除: $plugin_id"
					return 0
				fi
			fi

			echo "⚠️ plugins.allow 移除失败，请手动检查: $config_file"
			return 1
		}






		install_plugin() {
		send_stats "插件管理"
		while true; do
			clear
			echo "========================================"
			echo "            插件管理 (安装/删除)            "
			echo "========================================"
			echo "当前插件列表:"
			openclaw plugins list
			echo "--------------------------------------------------------"
			echo "推荐的常用插件 ID (直接复制括号内的 ID 即可):"
			echo "--------------------------------------------------------"
			echo "📱 通讯渠道:"
			echo "  - [feishu]       	# 飞书/Lark 集成"
			echo "  - [telegram]     	# Telegram 机器人"
			echo "  - [slack]        	# Slack 企业通讯"
			echo "  - [msteams]      	# Microsoft Teams"
			echo "  - [discord]      	# Discord 社区管理"
			echo "  - [whatsapp]     	# WhatsApp 自动化"
			echo ""
			echo "🧠 记忆与 AI:"
			echo "  - [memory-core]  	# 基础记忆 (文件检索)"
			echo "  - [memory-lancedb]	# 增强记忆 (向量数据库)"
			echo "  - [copilot-proxy]	# Copilot 接口转发"
			echo ""
			echo "⚙️ 功能扩展:"
			echo "  - [lobster]      	# 审批流 (带人工确认)"
			echo "  - [voice-call]   	# 语音通话能力"
			echo "  - [nostr]        	# 加密隐私聊天"
			echo "--------------------------------------------------------"

			echo "1) 安装/启用插件"
			echo "2) 删除/禁用插件"
			echo "0) 返回"
			read -e -p "请选择操作：" plugin_action

			[ "$plugin_action" = "0" ] && break
			[ -z "$plugin_action" ] && continue

			read -e -p "请输入插件 ID（空格分隔，输入 0 退出）： " raw_input
			[ "$raw_input" = "0" ] && break
			[ -z "$raw_input" ] && continue

			local success_list=""
			local failed_list=""
			local skipped_list=""
			local changed=false
			local token

			for token in $raw_input; do
				local plugin_id
				local plugin_full
				plugin_id=$(resolve_openclaw_plugin_id "$token")
				plugin_full="$token"
				[ -z "$plugin_id" ] && continue

				if [ "$plugin_action" = "1" ]; then
					echo "🔍 正在检查插件状态: $plugin_id"
					local plugin_list
					plugin_list=$(openclaw plugins list 2>/dev/null)

					if echo "$plugin_list" | grep -qw "$plugin_id" && echo "$plugin_list" | grep "$plugin_id" | grep -q "disabled"; then
						echo "💡 插件 [$plugin_id] 已预装，正在激活..."
						if openclaw plugins enable "$plugin_id"; then
							sync_openclaw_plugin_allowlist "$plugin_id"
							success_list="$success_list $plugin_id"
							changed=true
						else
							failed_list="$failed_list $plugin_id"
						fi
						continue
					fi

					if [ -d "/usr/lib/node_modules/openclaw/extensions/$plugin_id" ]; then
						echo "💡 发现系统内置目录存在该插件，尝试直接启用..."
						if openclaw plugins enable "$plugin_id"; then
							sync_openclaw_plugin_allowlist "$plugin_id"
							success_list="$success_list $plugin_id"
							changed=true
						else
							failed_list="$failed_list $plugin_id"
						fi
						continue
					fi

					echo "📥 本地未发现，尝试下载安装: $plugin_full"
					rm -rf "${HOME}/.openclaw/extensions/$plugin_id"
					[ "$HOME" != "/root" ] && rm -rf "/root/.openclaw/extensions/$plugin_id"
					if openclaw plugins install "$plugin_full"; then
						echo "✅ 下载成功，正在启用..."
						if openclaw plugins enable "$plugin_id"; then
							sync_openclaw_plugin_allowlist "$plugin_id"
							success_list="$success_list $plugin_id"
							changed=true
						else
							failed_list="$failed_list $plugin_id"
						fi
					else
						echo "❌ 安装失败：$plugin_full"
						failed_list="$failed_list $plugin_id"
					fi
				else
					echo "🗑️ 正在删除/禁用插件: $plugin_id"
					openclaw plugins disable "$plugin_id" >/dev/null 2>&1
					if openclaw plugins uninstall "$plugin_id"; then
						echo "✅ 已卸载: $plugin_id"
					else
						echo "⚠️ 卸载失败，可能为预装插件，仅禁用: $plugin_id"
					fi
					sync_openclaw_plugin_denylist "$plugin_id" >/dev/null 2>&1
					success_list="$success_list $plugin_id"
					changed=true
				fi
			done

			echo ""
			echo "====== 操作汇总 ======"
			echo "✅ 成功:$success_list"
			[ -n "$failed_list" ] && echo "❌ 失败:$failed_list"
			[ -n "$skipped_list" ] && echo "⏭️ 跳过:$skipped_list"

			if [ "$changed" = true ]; then
				echo "🔄 正在重启 OpenClaw 服务以加载变更..."
				start_gateway
			fi
			break_end
		done
	}


	install_skill() {
		send_stats "技能管理"
		while true; do
			clear
			echo "========================================"
			echo "            技能管理 (安装/删除)            "
			echo "========================================"
			echo "当前已安装技能:"
			openclaw skills list
			echo "----------------------------------------"

			# 输出推荐的实用技能列表
			echo "推荐的实用技能（可直接复制名称输入）："
			echo "github             # 管理 GitHub Issues/PR/CI (gh CLI)"
			echo "notion             # 操作 Notion 页面、数据库和块"
			echo "apple-notes        # macOS 原生笔记管理 (创建/编辑/搜索)"
			echo "apple-reminders    # macOS 提醒事项管理 (待办清单)"
			echo "1password          # 自动化读取和注入 1Password 密钥"
			echo "gog                # Google Workspace (Gmail/云盘/文档) 全能助手"
			echo "things-mac         # 深度整合 Things 3 任务管理"
			echo "bluebubbles        # 通过 BlueBubbles 完美收发 iMessage"
			echo "himalaya           # 终端邮件管理 (IMAP/SMTP 强力工具)"
			echo "summarize          # 网页/播客/YouTube 视频内容一键总结"
			echo "openhue            # 控制 Philips Hue 智能灯光场景"
			echo "video-frames       # 视频抽帧与短片剪辑 (ffmpeg 驱动)"
			echo "openai-whisper     # 本地音频转文字 (离线隐私保护)"
			echo "coding-agent       # 自动运行 Claude Code/Codex 等编程助手"
			echo "----------------------------------------"

			echo "1) 安装技能"
			echo "2) 删除技能"
			echo "0) 返回"
			read -e -p "请选择操作：" skill_action

			[ "$skill_action" = "0" ] && break
			[ -z "$skill_action" ] && continue

			read -e -p "请输入技能名称（空格分隔，输入 0 退出）： " skill_input
			[ "$skill_input" = "0" ] && break
			[ -z "$skill_input" ] && continue

			local success_list=""
			local failed_list=""
			local skipped_list=""
			local changed=false
			local token

			if [ "$skill_action" = "2" ]; then
				read -e -p "二次确认：删除仅影响用户目录 ~/.openclaw/workspace/skills，确认继续？(y/N): " confirm_del
				if [[ ! "$confirm_del" =~ ^[Yy]$ ]]; then
					echo "已取消删除。"
					break_end
					continue
				fi
			fi

			for token in $skill_input; do
				local skill_name
				skill_name="$token"
				[ -z "$skill_name" ] && continue

				if [ "$skill_action" = "1" ]; then
					local skill_found=false
					if [ -d "${HOME}/.openclaw/workspace/skills/${skill_name}" ]; then
						echo "💡 技能 [$skill_name] 已在用户目录安装。"
						skill_found=true
					elif [ -d "/usr/lib/node_modules/openclaw/skills/${skill_name}" ]; then
						echo "💡 技能 [$skill_name] 已在系统目录安装。"
						skill_found=true
					fi

					if [ "$skill_found" = true ]; then
						read -e -p "技能 [$skill_name] 已安装，是否重新安装？(y/N): " reinstall
						if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
							skipped_list="$skipped_list $skill_name"
							continue
						fi
					fi

					echo "正在安装技能：$skill_name ..."
					if npx clawhub install "$skill_name" --yes --no-input 2>/dev/null || npx clawhub install "$skill_name"; then
						echo "✅ 技能 $skill_name 安装成功。"
						success_list="$success_list $skill_name"
						changed=true
					else
						echo "❌ 安装失败：$skill_name"
						failed_list="$failed_list $skill_name"
					fi
				else
					echo "🗑️ 正在删除技能: $skill_name"
					npx clawhub uninstall "$skill_name" --yes --no-input 2>/dev/null || npx clawhub uninstall "$skill_name" >/dev/null 2>&1
					if [ -d "${HOME}/.openclaw/workspace/skills/${skill_name}" ]; then
						rm -rf "${HOME}/.openclaw/workspace/skills/${skill_name}"
						echo "✅ 已删除用户技能目录: $skill_name"
						success_list="$success_list $skill_name"
						changed=true
					else
						echo "⏭️ 未发现用户技能目录: $skill_name"
						skipped_list="$skipped_list $skill_name"
					fi
				fi
			done

			echo ""
			echo "====== 操作汇总 ======"
			echo "✅ 成功:$success_list"
			[ -n "$failed_list" ] && echo "❌ 失败:$failed_list"
			[ -n "$skipped_list" ] && echo "⏭️ 跳过:$skipped_list"

			if [ "$changed" = true ]; then
				echo "🔄 正在重启 OpenClaw 服务以加载变更..."
				start_gateway
			fi
			break_end
		done
	}

openclaw_json_get_bool() {
		local expr="$1"
		local config_file
		config_file=$(openclaw_get_config_file)
		if [ ! -s "$config_file" ]; then
			echo "false"
			return
		fi
		jq -r "$expr" "$config_file" 2>/dev/null || echo "false"
	}

	openclaw_channel_has_cfg() {
		local channel="$1"
		local config_file
		config_file=$(openclaw_get_config_file)
		if [ ! -s "$config_file" ]; then
			echo "false"
			return
		fi
		jq -r --arg c "$channel" '
			(.channels[$c] // null) as $v
			| if ($v | type) != "object" then
				false
			  else
				([ $v
				   | to_entries[]
				   | select((.key == "enabled" or .key == "dmPolicy" or .key == "groupPolicy" or .key == "streaming") | not)
				   | .value
				   | select(. != null and . != "" and . != false)
				 ] | length) > 0
			  end
		' "$config_file" 2>/dev/null || echo "false"
	}

	openclaw_dir_has_files() {
		local dir="$1"
		[ -d "$dir" ] && find "$dir" -type f -print -quit 2>/dev/null | grep -q .
	}

	openclaw_plugin_local_installed() {
		local plugin="$1"
		local config_file
		config_file=$(openclaw_get_config_file)
		if [ -s "$config_file" ] && jq -e --arg p "$plugin" '.plugins.installs[$p]' "$config_file" >/dev/null 2>&1; then
			return 0
		fi

		# 兼容两种常见目录命名：
		# - ~/.openclaw/extensions/qqbot
		# - ~/.openclaw/extensions/openclaw-qqbot
		# 避免无脑 substring，优先精确匹配与 openclaw- 前缀匹配。
		[ -d "${HOME}/.openclaw/extensions/${plugin}" ] \
			|| [ -d "${HOME}/.openclaw/extensions/openclaw-${plugin}" ] \
			|| [ -d "/usr/lib/node_modules/openclaw/extensions/${plugin}" ] \
			|| [ -d "/usr/lib/node_modules/openclaw/extensions/openclaw-${plugin}" ]
	}

	openclaw_bot_status_text() {
		local enabled="$1"
		local configured="$2"
		local connected="$3"
		local abnormal="$4"
		if [ "$abnormal" = "true" ]; then
			echo "异常"
		elif [ "$enabled" != "true" ]; then
			echo "未启用"
		elif [ "$connected" = "true" ]; then
			echo "已连接"
		elif [ "$configured" = "true" ]; then
			echo "已配置"
		else
			echo "未配置"
		fi
	}

	openclaw_colorize_bot_status() {
		local status="$1"
		case "$status" in
			已连接) echo -e "${gl_lv}${status}${gl_bai}" ;;
			已配置) echo -e "${gl_huang}${status}${gl_bai}" ;;
			异常) echo -e "${gl_hong}${status}${gl_bai}" ;;
			*) echo "$status" ;;
		esac
	}

	openclaw_print_bot_status_line() {
		local label="$1"
		local status="$2"
		echo -e "- ${label}: $(openclaw_colorize_bot_status "$status")"
	}

	openclaw_show_bot_local_status_block() {
		local config_file
		config_file=$(openclaw_get_config_file)
		local json_ok="false"
		if [ -s "$config_file" ] && jq empty "$config_file" >/dev/null 2>&1; then
			json_ok="true"
		fi

		local tg_enabled tg_cfg tg_connected tg_abnormal tg_status
		tg_enabled=$(openclaw_json_get_bool '.channels.telegram.enabled // .plugins.entries.telegram.enabled // false')
		tg_cfg=$(openclaw_channel_has_cfg "telegram")
		tg_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/telegram"; then
			tg_connected="true"
		fi
		tg_abnormal="false"
		if [ "$tg_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			tg_abnormal="true"
		fi
		tg_status=$(openclaw_bot_status_text "$tg_enabled" "$tg_cfg" "$tg_connected" "$tg_abnormal")

		local feishu_enabled feishu_cfg feishu_connected feishu_abnormal feishu_status
		feishu_enabled=$(openclaw_json_get_bool '.plugins.entries.feishu.enabled // .plugins.entries["openclaw-lark"].enabled // .channels.feishu.enabled // .channels.lark.enabled // false')
		feishu_cfg=$(openclaw_channel_has_cfg "feishu")
		if [ "$feishu_cfg" != "true" ]; then
			feishu_cfg=$(openclaw_channel_has_cfg "lark")
		fi
		feishu_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/feishu" || openclaw_dir_has_files "${HOME}/.openclaw/lark" || openclaw_dir_has_files "${HOME}/.openclaw/openclaw-lark"; then
			feishu_connected="true"
		fi
		feishu_abnormal="false"
		if [ "$feishu_enabled" = "true" ] && ! openclaw_plugin_local_installed "feishu" && ! openclaw_plugin_local_installed "lark" && ! openclaw_plugin_local_installed "openclaw-lark"; then
			feishu_abnormal="true"
		fi
		if [ "$feishu_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			feishu_abnormal="true"
		fi
		if [ "$feishu_connected" != "true" ] && [ "$feishu_enabled" = "true" ] && [ "$feishu_cfg" = "true" ] && { openclaw_plugin_local_installed "feishu" || openclaw_plugin_local_installed "lark" || openclaw_plugin_local_installed "openclaw-lark"; }; then
			feishu_connected="true"
		fi
		feishu_status=$(openclaw_bot_status_text "$feishu_enabled" "$feishu_cfg" "$feishu_connected" "$feishu_abnormal")

		local wa_enabled wa_cfg wa_connected wa_abnormal wa_status
		wa_enabled=$(openclaw_json_get_bool '.plugins.entries.whatsapp.enabled // .channels.whatsapp.enabled // false')
		wa_cfg=$(openclaw_channel_has_cfg "whatsapp")
		wa_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/whatsapp"; then
			wa_connected="true"
		fi
		wa_abnormal="false"
		if [ "$wa_enabled" = "true" ] && ! openclaw_plugin_local_installed "whatsapp"; then
			wa_abnormal="true"
		fi
		if [ "$wa_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			wa_abnormal="true"
		fi
		wa_status=$(openclaw_bot_status_text "$wa_enabled" "$wa_cfg" "$wa_connected" "$wa_abnormal")

		local dc_enabled dc_cfg dc_connected dc_abnormal dc_status
		dc_enabled=$(openclaw_json_get_bool '.channels.discord.enabled // .plugins.entries.discord.enabled // false')
		dc_cfg=$(openclaw_channel_has_cfg "discord")
		dc_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/discord"; then
			dc_connected="true"
		fi
		dc_abnormal="false"
		if [ "$dc_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			dc_abnormal="true"
		fi
		dc_status=$(openclaw_bot_status_text "$dc_enabled" "$dc_cfg" "$dc_connected" "$dc_abnormal")

		local slack_enabled slack_cfg slack_connected slack_abnormal slack_status
		slack_enabled=$(openclaw_json_get_bool '.plugins.entries.slack.enabled // .channels.slack.enabled // false')
		slack_cfg=$(openclaw_channel_has_cfg "slack")
		slack_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/slack"; then
			slack_connected="true"
		fi
		slack_abnormal="false"
		if [ "$slack_enabled" = "true" ] && ! openclaw_plugin_local_installed "slack"; then
			slack_abnormal="true"
		fi
		if [ "$slack_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			slack_abnormal="true"
		fi
		slack_status=$(openclaw_bot_status_text "$slack_enabled" "$slack_cfg" "$slack_connected" "$slack_abnormal")

		local qq_enabled qq_cfg qq_connected qq_abnormal qq_status
		qq_enabled=$(openclaw_json_get_bool '.plugins.entries.qqbot.enabled // .channels.qqbot.enabled // false')
		qq_cfg=$(openclaw_channel_has_cfg "qqbot")
		qq_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/qqbot/sessions" || openclaw_dir_has_files "${HOME}/.openclaw/qqbot/data"; then
			qq_connected="true"
		fi
		qq_abnormal="false"
		if [ "$qq_enabled" = "true" ] && ! openclaw_plugin_local_installed "qqbot"; then
			qq_abnormal="true"
		fi
		if [ "$qq_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			qq_abnormal="true"
		fi
		qq_status=$(openclaw_bot_status_text "$qq_enabled" "$qq_cfg" "$qq_connected" "$qq_abnormal")

		local wx_enabled wx_cfg wx_connected wx_abnormal wx_status
		wx_enabled=$(openclaw_json_get_bool '.plugins.entries.weixin.enabled // .plugins.entries["openclaw-weixin"].enabled // .channels.weixin.enabled // .channels["openclaw-weixin"].enabled // false')
		wx_cfg=$(openclaw_channel_has_cfg "weixin")
		if [ "$wx_cfg" != "true" ]; then
			wx_cfg=$(openclaw_channel_has_cfg "openclaw-weixin")
		fi
		wx_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/weixin" || openclaw_dir_has_files "${HOME}/.openclaw/openclaw-weixin"; then
			wx_connected="true"
		fi
		wx_abnormal="false"
		if [ "$wx_enabled" = "true" ] && ! openclaw_plugin_local_installed "weixin" && ! openclaw_plugin_local_installed "openclaw-weixin"; then
			wx_abnormal="true"
		fi
		if [ "$wx_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			wx_abnormal="true"
		fi
		wx_status=$(openclaw_bot_status_text "$wx_enabled" "$wx_cfg" "$wx_connected" "$wx_abnormal")

		echo "本地状态（仅本机配置/缓存，不做网络探测）："
		openclaw_print_bot_status_line "Telegram" "$tg_status"
		openclaw_print_bot_status_line "飞书(Lark)" "$feishu_status"
		openclaw_print_bot_status_line "WhatsApp" "$wa_status"
		openclaw_print_bot_status_line "Discord" "$dc_status"
		openclaw_print_bot_status_line "Slack" "$slack_status"
		openclaw_print_bot_status_line "QQ Bot" "$qq_status"
		openclaw_print_bot_status_line "微信 (Weixin)" "$wx_status"
	}

	change_tg_bot_code() {
		send_stats "机器人对接"
		while true; do
			clear
			echo "========================================"
			echo "            机器人连接对接            "
			echo "========================================"
			openclaw_show_bot_local_status_block
			echo "----------------------------------------"
			echo "1. Telegram 机器人对接"
			echo "2. 飞书 (Lark) 机器人对接"
			echo "3. WhatsApp 机器人对接"
			echo "4. QQ 机器人对接"
			echo "5. 微信机器人对接"
			echo "----------------------------------------"
			echo "0. 返回上一级选单"
			echo "----------------------------------------"
			read -e -p "请输入你的选择: " bot_choice

			case $bot_choice in
				1)
					read -e -p "请输入TG机器人收到的连接码 (例如 NYA99R2F)（输入 0 退出）： " code
					if [ "$code" = "0" ]; then continue; fi
					if [ -z "$code" ]; then echo "错误：连接码不能为空。"; sleep 1; continue; fi
					openclaw pairing approve telegram "$code"
					break_end
					;;
				2)
					npx -y @larksuite/openclaw-lark install
					openclaw config set channels.feishu.streaming true
					openclaw config set channels.feishu.requireMention true --json
					break_end
					;;
				3)
					read -e -p "请输入WhatsApp收到的连接码 (例如 NYA99R2F)（输入 0 退出）： " code
					if [ "$code" = "0" ]; then continue; fi
					if [ -z "$code" ]; then echo "错误：连接码不能为空。"; sleep 1; continue; fi
					openclaw pairing approve whatsapp "$code"
					break_end
					;;
				4)
					echo "QQ 官方对接地址："
					echo "https://q.qq.com/qqbot/openclaw/login.html"
					break_end
					;;
				5)
					npx -y @tencent-weixin/openclaw-weixin-cli@latest install
					break_end
					;;
				0)
					return 0
					;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}


	openclaw_backup_root() {
		echo "${HOME}/.openclaw/backups"
	}

	openclaw_is_interactive_terminal() {
		[ -t 0 ] && [ -t 1 ]
	}

	openclaw_has_command() {
		command -v "$1" >/dev/null 2>&1
	}


	openclaw_is_safe_relpath() {
		local rel="$1"
		[ -z "$rel" ] && return 1
		[[ "$rel" = /* ]] && return 1
		[[ "$rel" == *"//"* ]] && return 1
		[[ "$rel" == *$'\n'* ]] && return 1
		[[ "$rel" == *$'\r'* ]] && return 1
		case "$rel" in
			../*|*/../*|*/..|..)
				return 1
				;;
		esac
		return 0
	}

	openclaw_restore_path_allowed() {
		local mode="$1"
		local rel="$2"
		case "$mode" in
			memory)
				case "$rel" in
					MEMORY.md|AGENTS.md|USER.md|SOUL.md|TOOLS.md|memory/*) return 0 ;;
					*) return 1 ;;
				esac
				;;
			project)
				case "$rel" in
					openclaw.json|workspace/*|extensions/*|skills/*|prompts/*|tools/*|telegram/*|feishu/*|whatsapp/*|discord/*|slack/*|qqbot/*|logs/*) return 0 ;;
					*) return 1 ;;
				esac
				;;
			*)
				return 1
				;;
		esac
	}

	openclaw_pack_backup_archive() {
		local backup_type="$1"
		local export_mode="$2"
		local payload_dir="$3"
		local output_file="$4"

		local tmp_root
		tmp_root=$(mktemp -d) || return 1
		local pack_dir="$tmp_root/package"
		mkdir -p "$pack_dir"

		cp -a "$payload_dir" "$pack_dir/payload"

		(
			cd "$pack_dir/payload" || exit 1
			find . -type f | sed 's|^\./||' | sort > "$pack_dir/manifest.files"
			: > "$pack_dir/manifest.sha256"
			while IFS= read -r f; do
				[ -z "$f" ] && continue
				sha256sum "$f" >> "$pack_dir/manifest.sha256"
			done < "$pack_dir/manifest.files"
		) || { rm -rf "$tmp_root"; return 1; }

		cat > "$pack_dir/backup.meta" <<EOF
TYPE=$backup_type
MODE=$export_mode
CREATED_AT=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
HOST=$(hostname)
EOF

		mkdir -p "$(dirname "$output_file")"
		tar -C "$pack_dir" -czf "$output_file" backup.meta manifest.files manifest.sha256 payload
		local rc=$?
		rm -rf "$tmp_root"
		return $rc
	}

	openclaw_offer_transfer_hint() {
		local file_path="$1"

		echo "可使用以下方式下载备份文件："
		echo "- 本地路径: $file_path"
		echo "- scp 示例: scp root@你的服务器:$file_path ./"
		echo "- 或使用 SFTP 客户端下载"
	}

	openclaw_read_import_path() {
		local prompt_text="$1"
		local backup_root user_input target_path backup_root_real
		backup_root=$(openclaw_backup_root)

		printf "%s\n" "${prompt_text:-请输入备份包路径}" >&2
		printf "可输入完整路径，或输入备份目录里的文件名；输入 0 取消。\n" >&2
		read -e -p "备份包路径/文件名: " user_input

		if [ -z "$user_input" ] || [ "$user_input" = "0" ]; then
			return 1
		fi

		if [[ "$user_input" == /* ]]; then
			target_path="$user_input"
		else
			target_path="$backup_root/$user_input"
		fi

		backup_root_real=$(realpath -m "$backup_root" 2>/dev/null || printf "%s" "$backup_root")
		target_path=$(realpath -m "$target_path" 2>/dev/null || printf "%s" "$target_path")

		if [[ "$target_path" != "$backup_root_real"/* ]]; then
			printf "❌ 路径越界：仅允许还原备份目录内的文件: %s\n" "$backup_root" >&2
			return 1
		fi

		if [ ! -f "$target_path" ]; then
			printf "❌ 文件不存在: %s\n" "$target_path" >&2
			return 1
		fi

		printf "%s\n" "$target_path"
		return 0
	}

	openclaw_prepare_import_archive() {
		local expected_type="$1"
		local archive_path="$2"
		local unpack_root="$3"

		[ ! -f "$archive_path" ] && { echo "❌ 文件不存在: $archive_path"; return 1; }
		mkdir -p "$unpack_root"
		tar -xzf "$archive_path" -C "$unpack_root" || { echo "❌ 备份包解压失败"; return 1; }

		local pkg_dir="$unpack_root/package"
		if [ -f "$unpack_root/backup.meta" ]; then
			pkg_dir="$unpack_root"
		fi

		for required in backup.meta manifest.files manifest.sha256 payload; do
			[ -e "$pkg_dir/$required" ] || { echo "❌ 备份包缺少必要文件: $required"; return 1; }
		done

		local real_type
		real_type=$(grep '^TYPE=' "$pkg_dir/backup.meta" | head -n1 | cut -d'=' -f2-)
		if [ "$real_type" != "$expected_type" ]; then
			echo "❌ 备份类型不匹配，期望: $expected_type，实际: ${real_type:-未知}"
			return 1
		fi

		(
			cd "$pkg_dir/payload" || exit 1
			sha256sum -c ../manifest.sha256 >/dev/null
		) || { echo "❌ sha256 校验失败，拒绝还原"; return 1; }

		echo "$pkg_dir"
		return 0
	}

	openclaw_get_all_agent_workspaces() {
		local config_file
		config_file=$(openclaw_get_config_file)
		if [ -f "$config_file" ]; then
			python3 - "$config_file" <<'PY'
import json, sys, os
try:
    with open(sys.argv[1]) as f: data = json.load(f)
    agents = data.get("agents", {}).get("list", [])
    results = [{"id": "main", "ws": os.path.expanduser("~/.openclaw/workspace")}]
    for a in agents:
        aid = a.get("id"); ws = a.get("workspace")
        if aid and ws and aid != "main": results.append({"id": aid, "ws": os.path.expanduser(ws)})
    print(json.dumps(results))
except: print("[]")
PY
		else
			echo '[{"id": "main", "ws": "'"${HOME}"'/.openclaw/workspace"}]'
		fi
	}

	openclaw_memory_backup_export() {
		send_stats "OpenClaw记忆全量备份"
		local backup_root=$(openclaw_backup_root)
		local ts=$(date +%Y%m%d-%H%M%S)
		local out_file="$backup_root/openclaw-memory-full-${ts}.tar.gz"
		mkdir -p "$backup_root"
		local tmp_payload=$(mktemp -d) || return 1
		local workspaces_json=$(openclaw_get_all_agent_workspaces)
		python3 -c "import json, sys, os, shutil;
workspaces = json.loads(sys.argv[1]); tmp_payload = sys.argv[2]
for item in workspaces:
    aid = item['id']; ws = item['ws']
    if not os.path.isdir(ws): continue
    target_dir = os.path.join(tmp_payload, 'agents', aid)
    os.makedirs(target_dir, exist_ok=True)
    for f in ['MEMORY.md', 'memory']:
        src = os.path.join(ws, f)
        if os.path.exists(src):
            if os.path.isfile(src): shutil.copy2(src, target_dir)
            else: shutil.copytree(src, os.path.join(target_dir, f), dirs_exist_ok=True)
" "$workspaces_json" "$tmp_payload"
		if ! find "$tmp_payload" -mindepth 1 -print -quit | grep -q .; then
			echo "❌ 未找到可备份的记忆文件"; rm -rf "$tmp_payload"; break_end; return 1
		fi
		if openclaw_pack_backup_archive "memory-full" "multi-agent" "$tmp_payload" "$out_file"; then
			echo "✅ 记忆全量备份完成 (含多智能体): $out_file"; openclaw_offer_transfer_hint "$out_file"
		else
			echo "❌ 记忆全量备份失败"
		fi
		rm -rf "$tmp_payload"; break_end
	}

	openclaw_memory_backup_import() {
		send_stats "OpenClaw记忆全量还原"
		local archive_path=$(openclaw_read_import_path "还原记忆全量 (支持多智能体)")
		[ -z "$archive_path" ] && { echo "❌ 未输入路径"; break_end; return 1; }
		local tmp_unpack=$(mktemp -d) || return 1
		local pkg_dir=$(openclaw_prepare_import_archive "memory-full" "$archive_path" "$tmp_unpack") || { rm -rf "$tmp_unpack"; break_end; return 1; }
		local workspaces_json=$(openclaw_get_all_agent_workspaces)
		python3 -c 'import json, sys, os, shutil;
workspaces = {item["id"]: item["ws"] for item in json.loads(sys.argv[1])};
payload_dir = sys.argv[2]; agents_root = os.path.join(payload_dir, "agents")
if os.path.isdir(agents_root):
    for aid in os.listdir(agents_root):
        if aid in workspaces:
            src_agent_dir = os.path.join(agents_root, aid); dest_ws = workspaces[aid]
            os.makedirs(dest_ws, exist_ok=True)
            for f in os.listdir(src_agent_dir):
                src = os.path.join(src_agent_dir, f); dest = os.path.join(dest_ws, f)
                if os.path.isfile(src): shutil.copy2(src, dest)
                else: shutil.copytree(src, dest, dirs_exist_ok=True)
            print(f"✅ 已还原智能体记忆: {aid}")' "$workspaces_json" "$pkg_dir/payload"
		rm -rf "$tmp_unpack"; echo "✅ 记忆全量还原完成"; break_end
	}


	openclaw_project_backup_export() {
		send_stats "OpenClaw项目备份"
		local config_file
		config_file=$(openclaw_get_config_file)
		local openclaw_root
		openclaw_root=$(dirname "$config_file")
		if [ ! -d "$openclaw_root" ]; then
			echo "❌ 未找到 OpenClaw 根目录: $openclaw_root"
			break_end
			return 1
		fi

		echo "备份模式："
		echo "1. 安全模式（默认，推荐）：workspace + openclaw.json + extensions/skills/prompts/tools（如存在）"
		echo "2. 完整模式（含更多状态，敏感风险更高）"
		read -e -p "请选择备份模式（默认 1）: " export_mode
		[ -z "$export_mode" ] && export_mode="1"

		local mode_label="safe"
		local tmp_payload
		tmp_payload=$(mktemp -d) || return 1

		if [ "$export_mode" = "2" ]; then
			mode_label="full"
			for d in workspace extensions skills prompts tools; do
				[ -e "$openclaw_root/$d" ] && cp -a "$openclaw_root/$d" "$tmp_payload/"
			done
			[ -f "$openclaw_root/openclaw.json" ] && cp -a "$openclaw_root/openclaw.json" "$tmp_payload/"
			for d in telegram feishu whatsapp discord slack qqbot logs; do
				[ -e "$openclaw_root/$d" ] && cp -a "$openclaw_root/$d" "$tmp_payload/"
			done
		else
			[ -d "$openclaw_root/workspace" ] && cp -a "$openclaw_root/workspace" "$tmp_payload/"
			[ -f "$openclaw_root/openclaw.json" ] && cp -a "$openclaw_root/openclaw.json" "$tmp_payload/"
			for d in extensions skills prompts tools; do
				[ -e "$openclaw_root/$d" ] && cp -a "$openclaw_root/$d" "$tmp_payload/"
			done
		fi

		if ! find "$tmp_payload" -mindepth 1 -print -quit | grep -q .; then
			echo "❌ 未找到可备份的 OpenClaw 项目内容"
			rm -rf "$tmp_payload"
			break_end
			return 1
		fi

		local backup_root
		backup_root=$(openclaw_backup_root)
		mkdir -p "$backup_root"
		local out_file="$backup_root/openclaw-project-${mode_label}-$(date +%Y%m%d-%H%M%S).tar.gz"

		if openclaw_pack_backup_archive "openclaw-project" "$mode_label" "$tmp_payload" "$out_file"; then
			echo "✅ OpenClaw 项目备份完成 (${mode_label}): $out_file"
			openclaw_offer_transfer_hint "$out_file"
		else
			echo "❌ OpenClaw 项目备份失败"
		fi

		rm -rf "$tmp_payload"
		break_end
	}

	openclaw_project_backup_import() {
		send_stats "OpenClaw项目还原"
		local config_file
		config_file=$(openclaw_get_config_file)
		local openclaw_root
		openclaw_root=$(dirname "$config_file")
		mkdir -p "$openclaw_root"

		echo "⚠️ 高风险操作：项目还原会覆盖 OpenClaw 配置与工作区内容。"
		echo "⚠️ 还原前将执行 manifest/sha256 校验、白名单恢复、gateway 停启与健康检查。"
		read -e -p "请输入确认词【我已知晓高风险并继续还原】后继续: " confirm_text
		if [ "$confirm_text" != "我已知晓高风险并继续还原" ]; then
			echo "❌ 确认词不匹配，已取消还原"
			break_end
			return 1
		fi

		local archive_path
		archive_path=$(openclaw_read_import_path "请输入 OpenClaw 项目备份包路径")
		[ -z "$archive_path" ] && { echo "❌ 未输入备份路径"; break_end; return 1; }

		local tmp_unpack
		tmp_unpack=$(mktemp -d) || return 1
		local pkg_dir
		pkg_dir=$(openclaw_prepare_import_archive "openclaw-project" "$archive_path" "$tmp_unpack") || { rm -rf "$tmp_unpack"; break_end; return 1; }

		local invalid=0
		local valid_list
		valid_list=$(mktemp)
		while IFS= read -r rel; do
			[ -z "$rel" ] && continue
			if ! openclaw_is_safe_relpath "$rel" || ! openclaw_restore_path_allowed project "$rel"; then
				echo "❌ 检测到非法或越权路径: $rel"
				invalid=1
				break
			fi
			echo "$rel" >> "$valid_list"
		done < "$pkg_dir/manifest.files"

		if [ "$invalid" -ne 0 ]; then
			rm -f "$valid_list"
			rm -rf "$tmp_unpack"
			echo "❌ 还原中止：存在不安全路径"
			break_end
			return 1
		fi


		if command -v openclaw >/dev/null 2>&1; then
			echo "⏸️ 还原前停止 OpenClaw gateway..."
			openclaw gateway stop >/dev/null 2>&1
		fi

		while IFS= read -r rel; do
			mkdir -p "$openclaw_root/$(dirname "$rel")"
			cp -a "$pkg_dir/payload/$rel" "$openclaw_root/$rel"
		done < "$valid_list"

		if command -v openclaw >/dev/null 2>&1; then
			echo "▶️ 还原后启动 OpenClaw gateway..."
			openclaw gateway start >/dev/null 2>&1
			sleep 2
			echo "🩺 gateway 健康检查："
			openclaw gateway status || true
		fi

		rm -f "$valid_list"
		rm -rf "$tmp_unpack"
		echo "✅ OpenClaw 项目还原完成"
		break_end
	}

	openclaw_backup_detect_type() {
		local file_name="$1"
		if [[ "$file_name" == openclaw-memory-full-*.tar.gz ]]; then
			echo "记忆备份文件"
		elif [[ "$file_name" == openclaw-project-*.tar.gz ]]; then
			echo "项目备份文件"
		else
			echo "其他备份文件"
		fi
	}

	openclaw_backup_collect_files() {
		local backup_root
		backup_root=$(openclaw_backup_root)
		mkdir -p "$backup_root"
		mapfile -t OPENCLAW_BACKUP_FILES < <(find "$backup_root" -maxdepth 1 -type f -name '*.tar.gz' -printf '%f\n' | sort -r)
	}


	openclaw_backup_render_file_list() {
		local backup_root i file_name file_path file_type file_size file_time
		local has_memory=0 has_project=0 has_other=0
		backup_root=$(openclaw_backup_root)
		openclaw_backup_collect_files

		echo "备份目录: $backup_root"
		if [ ${#OPENCLAW_BACKUP_FILES[@]} -eq 0 ]; then
			echo "暂无备份文件"
			return 0
		fi

		for i in "${!OPENCLAW_BACKUP_FILES[@]}"; do
			file_type=$(openclaw_backup_detect_type "${OPENCLAW_BACKUP_FILES[$i]}")
			case "$file_type" in
				"记忆备份文件") has_memory=1 ;;
				"项目备份文件") has_project=1 ;;
				"其他备份文件") has_other=1 ;;
			esac
		done

		if [ "$has_memory" -eq 1 ]; then
			echo "记忆备份文件"
			for i in "${!OPENCLAW_BACKUP_FILES[@]}"; do
				file_name="${OPENCLAW_BACKUP_FILES[$i]}"
				file_type=$(openclaw_backup_detect_type "$file_name")
				[ "$file_type" != "记忆备份文件" ] && continue
				file_path="$backup_root/$file_name"
				file_size=$(ls -lh "$file_path" | awk '{print $5}')
				file_time=$(date -d "$(stat -c %y "$file_path")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$file_path" | awk '{print $1" "$2}')
				printf "%s | %s | %s\n" "$file_name" "$file_size" "$file_time"
			done
		fi

		if [ "$has_project" -eq 1 ]; then
			echo "项目备份文件"
			for i in "${!OPENCLAW_BACKUP_FILES[@]}"; do
				file_name="${OPENCLAW_BACKUP_FILES[$i]}"
				file_type=$(openclaw_backup_detect_type "$file_name")
				[ "$file_type" != "项目备份文件" ] && continue
				file_path="$backup_root/$file_name"
				file_size=$(ls -lh "$file_path" | awk '{print $5}')
				file_time=$(date -d "$(stat -c %y "$file_path")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$file_path" | awk '{print $1" "$2}')
				printf "%s | %s | %s\n" "$file_name" "$file_size" "$file_time"
			done
		fi

		if [ "$has_other" -eq 1 ]; then
			echo "其他备份文件"
			for i in "${!OPENCLAW_BACKUP_FILES[@]}"; do
				file_name="${OPENCLAW_BACKUP_FILES[$i]}"
				file_type=$(openclaw_backup_detect_type "$file_name")
				[ "$file_type" != "其他备份文件" ] && continue
				file_path="$backup_root/$file_name"
				file_size=$(ls -lh "$file_path" | awk '{print $5}')
				file_time=$(date -d "$(stat -c %y "$file_path")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$file_path" | awk '{print $1" "$2}')
				printf "%s | %s | %s\n" "$file_name" "$file_size" "$file_time"
			done
		fi
	}

	openclaw_backup_file_exists_in_list() {
		local target_file="$1"
		local item
		for item in "${OPENCLAW_BACKUP_FILES[@]}"; do
			[ "$item" = "$target_file" ] && return 0
		done
		return 1
	}

	openclaw_backup_delete_file() {
		send_stats "OpenClaw删除备份文件"
		local backup_root backup_root_real user_input target_file target_path target_type
		backup_root=$(openclaw_backup_root)

		openclaw_backup_render_file_list
		if [ ${#OPENCLAW_BACKUP_FILES[@]} -eq 0 ]; then
			break_end
			return 0
		fi

		read -e -p "请输入要删除的文件名或完整路径（0 取消）: " user_input
		if [ "$user_input" = "0" ]; then
			echo "已取消删除。"
			break_end
			return 0
		fi
		if [ -z "$user_input" ]; then
			echo "❌ 输入不能为空。"
			break_end
			return 1
		fi

		backup_root_real=$(realpath -m "$backup_root")
		if [[ "$user_input" == /* ]]; then
			target_path=$(realpath -m "$user_input")
			case "$target_path" in
				"$backup_root_real"/*) ;;
				*)
					echo "❌ 路径越界：仅允许删除备份根目录内的文件。"
					break_end
					return 1
					;;
			esac
			target_file=$(basename "$target_path")
		else
			target_file=$(basename -- "$user_input")
			target_path="$backup_root/$target_file"
		fi

		if [ ! -f "$target_path" ]; then
			echo "❌ 目标文件不存在: $target_path"
			break_end
			return 1
		fi

		if ! openclaw_backup_file_exists_in_list "$target_file"; then
			echo "❌ 目标文件不在当前备份列表中。"
			break_end
			return 1
		fi

		target_type=$(openclaw_backup_detect_type "$target_file")

		echo "即将删除: [$target_type] $target_path"
		read -e -p "第一次确认：输入 yes 确认继续: " confirm_step1
		if [ "$confirm_step1" != "yes" ]; then
			echo "已取消删除。"
			break_end
			return 0
		fi
		read -e -p "二次确认：输入 DELETE 执行删除: " confirm_step2
		if [ "$confirm_step2" != "DELETE" ]; then
			echo "已取消删除。"
			break_end
			return 0
		fi

		if rm -f -- "$target_path"; then
			echo "✅ 删除成功: $target_file"
		else
			echo "❌ 删除失败: $target_file"
		fi
		break_end
	}

	openclaw_backup_list_files() {
		openclaw_backup_render_file_list
		break_end
	}

	openclaw_memory_config_file() {
		local user_config="${HOME}/.openclaw/openclaw.json"
		local root_config="/root/.openclaw/openclaw.json"
		if [ -f "$user_config" ]; then
			echo "$user_config"
		elif [ "$HOME" = "/root" ] && [ -f "$root_config" ]; then
			echo "$root_config"
		else
			echo "$user_config"
		fi
	}

	openclaw_memory_config_get() {
		local key="$1"
		local default_value="${2:-}"
		local value
		value=$(openclaw config get "$key" 2>/dev/null | head -n 1 | sed -e 's/^"//' -e 's/"$//')
		if [ -z "$value" ] || [ "$value" = "null" ] || [ "$value" = "undefined" ]; then
			echo "$default_value"
			return 0
		fi
		echo "$value"
	}

	openclaw_memory_config_set() {
		local key="$1"
		shift
		openclaw config set "$key" "$@" >/dev/null 2>&1
	}

	openclaw_memory_config_unset() {
		local key="$1"
		openclaw config unset "$key" >/dev/null 2>&1
	}

	openclaw_memory_cleanup_legacy_keys() {
		openclaw_memory_config_unset "memory.local"
	}

	openclaw_memory_list_agents() {
		if command -v openclaw >/dev/null 2>&1; then
			local agents_json
			agents_json=$(openclaw agents list --json 2>/dev/null || true)
			if [ -n "$agents_json" ]; then
				python3 - "$agents_json" <<'PY'
import json, os, sys
raw = sys.argv[1]
try:
    data = json.loads(raw)
except Exception:
    data = None
seen = set()
results = []
if isinstance(data, list):
    for item in data:
        if not isinstance(item, dict):
            continue
        aid = item.get('id')
        if not aid or aid in seen:
            continue
        ws = item.get('workspace') or ("~/.openclaw/workspace" if aid == 'main' else f"~/.openclaw/workspace-{aid}")
        results.append((aid, os.path.expanduser(ws)))
        seen.add(aid)
if results:
    for aid, ws in results:
        print(f"{aid}\t{ws}")
    raise SystemExit(0)
raise SystemExit(1)
PY
				[ $? -eq 0 ] && return 0
			fi
		fi
		local config_path
		config_path=$(openclaw_memory_config_file)
		python3 - "$config_path" <<'PY'
import json, os, sys
config_path = sys.argv[1]
results = [("main", os.path.expanduser("~/.openclaw/workspace"))]
seen = {"main"}
try:
    if os.path.exists(config_path):
        with open(config_path, encoding='utf-8') as f:
            data = json.load(f)
        agents = data.get('agents', {}).get('list', [])
        if isinstance(agents, list):
            for item in agents:
                if not isinstance(item, dict):
                    continue
                aid = item.get('id')
                ws = item.get('workspace')
                if not aid or aid in seen:
                    continue
                if not ws:
                    ws = f"~/.openclaw/workspace-{aid}"
                results.append((aid, os.path.expanduser(ws)))
                seen.add(aid)
except Exception:
    pass
for aid, ws in results:
    print(f"{aid}\t{ws}")
PY
	}

	openclaw_memory_status_value() {
		local key="$1"
		local agent_id="${2:-}"
		if [ -n "$agent_id" ]; then
			openclaw memory status --agent "$agent_id" 2>/dev/null | awk -F': ' -v k="$key" '$1==k {print $2; exit}'
		else
			openclaw memory status 2>/dev/null | awk -F': ' -v k="$key" '$1==k {print $2; exit}'
		fi
	}

	openclaw_memory_expand_path() {
		local raw_path="$1"
		if [ -z "$raw_path" ]; then
			echo ""
			return 0
		fi
		raw_path=$(echo "$raw_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
		if [[ "$raw_path" == ~* ]]; then
			echo "${raw_path/#\~/$HOME}"
		else
			echo "$raw_path"
		fi
	}

	openclaw_memory_rebuild_index_single() {
		local agent_id="${1:-main}"
		local store_raw store_file ts backup_file
		store_raw=$(openclaw_memory_status_value "Store" "$agent_id")
		store_file=$(openclaw_memory_expand_path "$store_raw")
		if [ -z "$store_file" ] || [ ! -f "$store_file" ]; then
			echo "⚠️ [$agent_id] 未找到索引库文件，可能为空或不存在。"
			echo "   Store 原始值: ${store_raw:-<空>}"
			echo "   仍将执行重建索引。"
		else
			ts=$(date +%Y%m%d_%H%M%S)
			backup_file="${store_file}.bak.${ts}"
			if mv "$store_file" "$backup_file"; then
				echo "✅ [$agent_id] 已备份索引: $backup_file"
			else
				echo "⚠️ [$agent_id] 索引备份失败，继续重建。"
			fi
		fi
		openclaw memory index --agent "$agent_id" --force
	}

	openclaw_memory_rebuild_index_safe() {
		local agent_id="${1:-main}"
		openclaw_memory_rebuild_index_single "$agent_id"
		openclaw gateway restart
		echo "✅ 索引已重建并自动重启网关"
		echo ""
		openclaw_memory_render_status
	}

	openclaw_memory_rebuild_index_all() {
		local count=0
		local agent_lines agent_id workspace
		agent_lines=$(openclaw_memory_list_agents)
		while IFS=$'\t' read -r agent_id workspace; do
			[ -z "$agent_id" ] && continue
			openclaw_memory_rebuild_index_single "$agent_id"
			count=$((count+1))
		done <<EOF
$agent_lines
EOF
		openclaw gateway restart
		echo "✅ 索引已重建并自动重启网关"
		echo "✅ 已为 ${count} 个智能体重建索引"
		echo ""
		openclaw_memory_render_status
	}

	openclaw_memory_prepare_workspace() {
		local agent_id="${1:-main}"
		local workspace memory_dir
		workspace=$(openclaw_memory_status_value "Workspace" "$agent_id")
		if [ -z "$workspace" ]; then
			workspace="$HOME/.openclaw/workspace"
			[ "$agent_id" != "main" ] && workspace="$HOME/.openclaw/workspace-$agent_id"
		fi
		memory_dir="$workspace/memory"
		if [ ! -d "$memory_dir" ]; then
			echo "🔧 [$agent_id] 记忆目录不存在，已自动创建: $memory_dir"
			mkdir -p "$memory_dir"
		fi
		return 0
	}

	openclaw_memory_prepare_workspace_all() {
		local count=0
		local agent_lines agent_id workspace
		agent_lines=$(openclaw_memory_list_agents)
		echo "检查并准备 $(printf '%s\n' "$agent_lines" | sed '/^\s*$/d' | wc -l | tr -d ' ') 个智能体工作区"
		while IFS=$'\t' read -r agent_id workspace; do
			[ -z "$agent_id" ] && continue
			openclaw_memory_prepare_workspace "$agent_id"
			count=$((count+1))
		done <<EOF
$agent_lines
EOF
		return 0
	}

	openclaw_memory_render_status() {
		local json_output
		json_output=$(openclaw memory status --json 2>/dev/null)
		if [ -z "$json_output" ]; then
			echo "获取记忆状态失败（openclaw memory status --json 无输出）"
			return 1
		fi
		python3 - "$json_output" <<'PY'
import json, sys
raw = sys.argv[1]
try:
    data = json.loads(raw)
except Exception:
    print("获取记忆状态失败（JSON 解析错误）")
    raise SystemExit(1)
if not isinstance(data, list) or len(data) == 0:
    print("未检测到任何智能体记忆状态。")
    raise SystemExit(0)
first = True
for entry in data:
    if not isinstance(entry, dict):
        continue
    agent_id = entry.get("agentId", "?")
    s = entry.get("status", {})
    if not isinstance(s, dict):
        s = {}
    if not first:
        print("")
    first = False
    print("Agent: %s" % agent_id)
    backend = s.get("backend") or s.get("provider") or "-"
    print("  底层方案: %s" % backend)
    files = s.get("files", 0)
    chunks = s.get("chunks", 0)
    print("  已收录: %s 文件 / %s 块" % (files, chunks))
    dirty = s.get("dirty")
    dirty_str = "是" if dirty else "否"
    print("  待刷新: %s" % dirty_str)
    vec = s.get("vector", {})
    if isinstance(vec, dict) and vec.get("enabled"):
        vec_str = "就绪" if vec.get("available") else "已启用(不可用)"
    else:
        vec_str = "未启用"
    print("  向量库: %s" % vec_str)
    ws = s.get("workspaceDir") or "-"
    print("  工作区: %s" % ws)
    db = s.get("dbPath") or "-"
    print("  索引库: %s" % db)
    scan = entry.get("scan", {})
    if isinstance(scan, dict):
        issues = scan.get("issues", [])
        if issues:
            for issue in issues[:3]:
                print("  ⚠️ %s" % issue)
PY
	}

	openclaw_memory_get_backend() {
		local backend
		backend=$(openclaw_memory_config_get "memory.backend")
		if [ "$backend" = "local" ]; then
			echo "builtin"
		else
			echo "$backend"
		fi
	}

	openclaw_memory_get_local_model_path() {
		openclaw_memory_config_get "agents.defaults.memorySearch.local.modelPath"
	}

	openclaw_memory_local_model_status() {
		local model_path="$1"
		if [ -z "$model_path" ]; then
			echo "missing"
			return
		fi
		if [[ "$model_path" == hf:* ]]; then
			echo "hf"
			return
		fi
		if [ -f "$model_path" ]; then
			echo "ok"
		else
			echo "missing"
		fi
	}

	openclaw_memory_qmd_available() {
		if command -v qmd >/dev/null 2>&1; then
			echo "true"
			return
		fi
		local backend
		backend=$(openclaw_memory_config_get "memory.backend")
		if [ "$backend" = "qmd" ]; then
			echo "true"
			return
		fi
		echo "false"
	}

	openclaw_memory_probe_url() {
		local url="$1"
		if ! command -v curl >/dev/null 2>&1; then
			echo "unknown"
			return
		fi
		if [ -z "$url" ]; then
			echo "unknown"
			return
		fi
		if curl -I -m 2 -s "$url" >/dev/null 2>&1; then
			echo "ok"
		else
			echo "fail"
		fi
	}

	openclaw_memory_recommend() {
		local qmd_ok model_path model_status hf_ok mirror_ok
		qmd_ok=$(openclaw_memory_qmd_available)
		model_path=$(openclaw_memory_get_local_model_path)
		model_status=$(openclaw_memory_local_model_status "$model_path")
		hf_ok=$(openclaw_memory_probe_url "https://huggingface.co")
		mirror_ok=$(openclaw_memory_probe_url "https://hf-mirror.com")

		OPENCLAW_MEMORY_RECOMMEND_REASON=()
		if [ "$qmd_ok" = "true" ]; then
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("QMD 可用")
		else
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("未检测到 QMD")
		fi
		if [ -n "$model_path" ]; then
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("本地模型路径: $model_path")
		else
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("未配置本地模型路径")
		fi
		case "$model_status" in
			ok) OPENCLAW_MEMORY_RECOMMEND_REASON+=("本地模型文件存在") ;;
			hf) OPENCLAW_MEMORY_RECOMMEND_REASON+=("模型来自 HF 下载源（国内可能慢/失败）") ;;
			*) OPENCLAW_MEMORY_RECOMMEND_REASON+=("本地模型文件不存在或不可用") ;;
		esac
		if [ "$hf_ok" = "ok" ]; then
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("huggingface.co 可访问")
		elif [ "$mirror_ok" = "ok" ]; then
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("hf-mirror.com 可访问")
		else
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("huggingface.co / hf-mirror.com 可能不可达（疑似国内/受限网络）")
		fi

		if [ "$qmd_ok" = "true" ]; then
			if [ "$model_status" = "ok" ]; then
				OPENCLAW_MEMORY_RECOMMEND="local"
			elif [ "$model_status" = "hf" ] && { [ "$hf_ok" = "ok" ] || [ "$mirror_ok" = "ok" ]; }; then
				OPENCLAW_MEMORY_RECOMMEND="local"
			elif [ "$model_status" = "hf" ] && [ "$hf_ok" = "fail" ] && [ "$mirror_ok" = "fail" ]; then
				OPENCLAW_MEMORY_RECOMMEND="qmd"
			else
				OPENCLAW_MEMORY_RECOMMEND="qmd"
			fi
		else
			if [ "$model_status" = "ok" ]; then
				OPENCLAW_MEMORY_RECOMMEND="local"
			else
				OPENCLAW_MEMORY_RECOMMEND="qmd"
			fi
		fi
	}


	openclaw_memory_detect_region() {
		OPENCLAW_MEMORY_COUNTRY="unknown"
		OPENCLAW_MEMORY_USE_MIRROR="false"
		if command -v curl >/dev/null 2>&1; then
			OPENCLAW_MEMORY_COUNTRY=$(curl -s -m 2 ipinfo.io/country | tr -d '
' | tr -d '
')
		fi
		case "$OPENCLAW_MEMORY_COUNTRY" in
			CN|HK)
				OPENCLAW_MEMORY_USE_MIRROR="true"
				;;
		esac
	}

	openclaw_memory_select_sources() {
		local hf_ok mirror_ok
		hf_ok=$(openclaw_memory_probe_url "https://huggingface.co")
		mirror_ok=$(openclaw_memory_probe_url "https://hf-mirror.com")
		OPENCLAW_MEMORY_HF_OK="$hf_ok"
		OPENCLAW_MEMORY_MIRROR_OK="$mirror_ok"
		if [ "$OPENCLAW_MEMORY_USE_MIRROR" = "true" ]; then
			if [ "$mirror_ok" = "ok" ]; then
				OPENCLAW_MEMORY_HF_BASE="https://hf-mirror.com"
			elif [ "$hf_ok" = "ok" ]; then
				OPENCLAW_MEMORY_HF_BASE="https://huggingface.co"
			else
				OPENCLAW_MEMORY_HF_BASE="https://hf-mirror.com"
			fi
			OPENCLAW_MEMORY_GH_PROXY="https://gh.kejilion.pro/"
		else
			if [ "$hf_ok" = "ok" ]; then
				OPENCLAW_MEMORY_HF_BASE="https://huggingface.co"
			elif [ "$mirror_ok" = "ok" ]; then
				OPENCLAW_MEMORY_HF_BASE="https://hf-mirror.com"
			else
				OPENCLAW_MEMORY_HF_BASE="https://huggingface.co"
			fi
			OPENCLAW_MEMORY_GH_PROXY="https://"
		fi
	}

	openclaw_memory_download_file() {
		local url="$1"
		local dest="$2"
		mkdir -p "$(dirname "$dest")"
		if command -v curl >/dev/null 2>&1; then
			curl -L --fail --retry 2 -o "$dest" "$url"
			return $?
		fi
		if command -v wget >/dev/null 2>&1; then
			wget -O "$dest" "$url"
			return $?
		fi
		echo "❌ 未检测到 curl 或 wget，无法下载。"
		return 1
	}

	openclaw_memory_check_sqlite() {
		if ! command -v sqlite3 >/dev/null 2>&1; then
			echo "⚠️ 未检测到 sqlite3，QMD 可能无法正常运行。"
			return 1
		fi
		local ver
		ver=$(sqlite3 --version 2>/dev/null | awk '{print $1}')
		echo "✅ sqlite3 可用: ${ver:-unknown}"
		echo "ℹ️ sqlite 扩展支持无法可靠检测，将继续。"
		return 0
	}

	openclaw_memory_ensure_bun() {
		if [ -x "$HOME/.bun/bin/bun" ]; then
			export PATH="$HOME/.bun/bin:$PATH"
		fi
		if command -v bun >/dev/null 2>&1; then
			echo "✅ bun 已存在"
			return 0
		fi
		echo "⬇️ 安装 bun..."
		if command -v curl >/dev/null 2>&1; then
			curl -fsSL https://bun.sh/install | bash
		elif command -v wget >/dev/null 2>&1; then
			wget -qO- https://bun.sh/install | bash
		else
			echo "❌ 未检测到 curl 或 wget，无法安装 bun。"
			return 1
		fi
		if [ -d "$HOME/.bun/bin" ]; then
			export PATH="$HOME/.bun/bin:$PATH"
		fi
		if command -v bun >/dev/null 2>&1; then
			echo "✅ bun 安装完成"
			return 0
		fi
		echo "❌ bun 安装失败"
		return 1
	}

	openclaw_memory_ensure_qmd() {
		local qmd_path
		qmd_path=$(command -v qmd 2>/dev/null || true)
		if [ -n "$qmd_path" ]; then
			if qmd --version >/dev/null 2>&1; then
				echo "✅ qmd 已存在且可用: $qmd_path"
				OPENCLAW_MEMORY_QMD_PATH="$qmd_path"
				return 0
			else
				echo "⚠️ qmd 命令存在但模块损坏，重新安装..."
			fi
		fi
		echo "⬇️ 通过 npm 安装 qmd: @tobilu/qmd"
		npm install -g @tobilu/qmd
		qmd_path=$(command -v qmd 2>/dev/null || true)
		if [ -z "$qmd_path" ]; then
			echo "❌ qmd 安装失败"
			return 1
		fi
		if ! qmd --version >/dev/null 2>&1; then
			echo "❌ qmd 安装后仍无法运行"
			return 1
		fi
		OPENCLAW_MEMORY_QMD_PATH="$qmd_path"
		echo "✅ qmd 安装完成: $qmd_path"
		return 0
	}

	openclaw_memory_render_auto_summary() {
		echo "---------------------------------------"
		echo "✅ 环境就绪"
		echo "方案: ${OPENCLAW_MEMORY_AUTO_SCHEME:-unknown}"
		if [ "$OPENCLAW_MEMORY_CONFIG_ONLY" = "true" ]; then
			echo "模式: 仅写配置（未安装/未下载）"
		fi
		if [ "$OPENCLAW_MEMORY_PREHEAT" = "true" ]; then
			echo "索引: 已执行"
		else
			echo "索引: 已跳过"
		fi
		if [ "$OPENCLAW_MEMORY_RESTARTED" = "true" ]; then
			echo "重启: 已执行"
		else
			echo "重启: 已跳过"
		fi
		if [ -n "$OPENCLAW_MEMORY_QMD_PATH" ]; then
			echo "qmd: $OPENCLAW_MEMORY_QMD_PATH"
		fi
		if [ -n "$OPENCLAW_MEMORY_MODEL_PATH" ]; then
			echo "模型: $OPENCLAW_MEMORY_MODEL_PATH"
		fi
		if [ -n "$OPENCLAW_MEMORY_COUNTRY" ]; then
			echo "地区: $OPENCLAW_MEMORY_COUNTRY"
		fi
		if [ -n "$OPENCLAW_MEMORY_HF_BASE" ]; then
			echo "下载源: $OPENCLAW_MEMORY_HF_BASE"
		fi
		echo "最终状态:"
		openclaw_memory_render_status
		echo "---------------------------------------"
	}

	openclaw_memory_auto_confirm() {
		local scheme_label="$1"
		OPENCLAW_MEMORY_PREHEAT="true"
		OPENCLAW_MEMORY_RESTARTED="false"
		OPENCLAW_MEMORY_CONFIG_ONLY="false"
		echo "即将执行自动部署（详细模式）"
		echo "目标方案: $scheme_label"
		echo "地区: ${OPENCLAW_MEMORY_COUNTRY:-unknown}"
		echo "镜像源探测: huggingface.co=${OPENCLAW_MEMORY_HF_OK:-unknown} hf-mirror.com=${OPENCLAW_MEMORY_MIRROR_OK:-unknown}"
		echo "下载源: ${OPENCLAW_MEMORY_HF_BASE:-unknown}"
		if [ -n "$OPENCLAW_MEMORY_EXPECT_PATH" ]; then
			echo "预计下载路径: $OPENCLAW_MEMORY_EXPECT_PATH"
		fi
		if [ -n "$OPENCLAW_MEMORY_EXPECT_SIZE" ]; then
			echo "可能流量/磁盘占用: $OPENCLAW_MEMORY_EXPECT_SIZE"
		else
			echo "可能流量/磁盘占用: 视实际情况而定"
		fi
		echo "确认后将自动安装/下载、写入配置、构建索引并重启网关"
		echo "高级选项: 输入 config 仅写配置（不安装不下载、不索引、不重启）"
		read -e -p "输入 yes 确认继续（默认 N）: " confirm_step
		case "$confirm_step" in
			yes|YES)
				OPENCLAW_MEMORY_PREHEAT="true"
				;;
			config|CONFIG)
				OPENCLAW_MEMORY_CONFIG_ONLY="true"
				OPENCLAW_MEMORY_PREHEAT="false"
				;;
			*)
				echo "已取消自动部署。"
				return 1
				;;
		esac
		if [ "$OPENCLAW_MEMORY_CONFIG_ONLY" = "true" ]; then
			echo "⚠️ 已选择仅写配置，不安装不下载"
		else
			echo "✅ 将自动构建索引并重启网关"
		fi
		return 0
	}

	openclaw_memory_auto_setup_qmd() {
		echo "🔍 检测 QMD 环境"
		openclaw_memory_cleanup_legacy_keys
		openclaw_memory_check_sqlite || true
		if [ "$OPENCLAW_MEMORY_CONFIG_ONLY" = "true" ]; then
			if command -v qmd >/dev/null 2>&1; then
				OPENCLAW_MEMORY_QMD_PATH=$(command -v qmd)
			else
				OPENCLAW_MEMORY_QMD_PATH="qmd"
			fi
		else
			openclaw_memory_ensure_qmd || return 1
		fi
		local backend
		backend=$(openclaw_memory_get_backend)
		if [ "$backend" = "qmd" ]; then
			echo "✅ memory.backend 已是 qmd"
		else
			openclaw_memory_config_set "memory.backend" "qmd"
			echo "✅ 已设置 memory.backend=qmd"
		fi
		local qmd_cmd
		qmd_cmd=$(openclaw_memory_config_get "memory.qmd.command")
		if [ -z "$qmd_cmd" ] || [[ "$qmd_cmd" != /* ]] || [ "$qmd_cmd" != "$OPENCLAW_MEMORY_QMD_PATH" ]; then
			openclaw_memory_config_set "memory.qmd.command" "$OPENCLAW_MEMORY_QMD_PATH"
			echo "✅ 已写入 memory.qmd.command: $OPENCLAW_MEMORY_QMD_PATH"
		else
			echo "✅ memory.qmd.command 已正确"
		fi
		if [ "$OPENCLAW_MEMORY_PREHEAT" = "true" ]; then
			echo "🔥 预热索引（可能下载模型）"
			openclaw_memory_prepare_workspace_all
			local preh_agent_lines preh_agent_id preh_workspace
			preh_agent_lines=$(openclaw_memory_list_agents)
			while IFS=$'\t' read -r preh_agent_id preh_workspace; do
				[ -z "$preh_agent_id" ] && continue
				openclaw memory index --agent "$preh_agent_id" --force
			done <<EOF
$preh_agent_lines
EOF
		else
			echo "⏭️ 已跳过预热"
		fi
		echo "✅ QMD 自动部署完成"
	}

	openclaw_memory_auto_setup_local() {
		echo "🔍 检测 Local 环境"
		openclaw_memory_cleanup_legacy_keys
		local backend provider
		backend=$(openclaw_memory_get_backend)
		if [ "$backend" = "builtin" ] || [ "$backend" = "local" ]; then
			echo "✅ memory.backend 已是 builtin"
		else
			openclaw_memory_config_set "memory.backend" "builtin"
			echo "✅ 已设置 memory.backend=builtin"
		fi
		provider=$(openclaw_memory_config_get "agents.defaults.memorySearch.provider")
		if [ "$provider" = "local" ]; then
			echo "✅ memorySearch.provider 已是 local"
		else
			openclaw_memory_config_set "agents.defaults.memorySearch.provider" "local"
			echo "✅ 已设置 agents.defaults.memorySearch.provider=local"
		fi

		local model_path model_status
		model_path=$(openclaw_memory_get_local_model_path)
		model_path=$(openclaw_memory_expand_path "$model_path")
		model_status=$(openclaw_memory_local_model_status "$model_path")
		if [ "$model_status" = "ok" ]; then
			echo "✅ 模型文件已存在: $model_path"
			OPENCLAW_MEMORY_MODEL_PATH="$model_path"
		else
			local model_name="embeddinggemma-300M-Q8_0.gguf"
			local model_dir="$HOME/.openclaw/models/embedding"
			local model_dest="$model_dir/$model_name"
			local model_url="${OPENCLAW_MEMORY_HF_BASE}/ggml-org/embeddinggemma-300M-GGUF/resolve/main/$model_name"
			if [ "$OPENCLAW_MEMORY_CONFIG_ONLY" = "true" ]; then
				echo "ℹ️ 仅写配置模式：跳过模型下载"
				OPENCLAW_MEMORY_MODEL_PATH="$model_dest"
			else
				if [ -f "$model_dest" ]; then
					echo "✅ 已发现默认模型文件: $model_dest"
				else
					echo "⬇️ 下载模型: $model_url"
					openclaw_memory_download_file "$model_url" "$model_dest" || return 1
					echo "✅ 模型已下载: $model_dest"
				fi
				OPENCLAW_MEMORY_MODEL_PATH="$model_dest"
			fi
			openclaw_memory_config_set "agents.defaults.memorySearch.local.modelPath" "$model_dest"
			echo "✅ 已写入模型路径"
		fi
		if [ "$OPENCLAW_MEMORY_PREHEAT" = "true" ]; then
			echo "🔥 预热索引（可能下载模型）"
			openclaw_memory_prepare_workspace_all
			local preh_agent_lines preh_agent_id preh_workspace
			preh_agent_lines=$(openclaw_memory_list_agents)
			while IFS=$'\t' read -r preh_agent_id preh_workspace; do
				[ -z "$preh_agent_id" ] && continue
				openclaw memory index --agent "$preh_agent_id" --force
			done <<EOF
$preh_agent_lines
EOF
		else
			echo "⏭️ 已跳过预热"
		fi
		echo "✅ Local 自动部署完成"
	}

	openclaw_memory_auto_setup_run() {
		local scheme="$1"
		local scheme_label
		OPENCLAW_MEMORY_QMD_PATH=""
		OPENCLAW_MEMORY_MODEL_PATH=""
		OPENCLAW_MEMORY_EXPECT_PATH=""
		OPENCLAW_MEMORY_EXPECT_SIZE=""
		openclaw_memory_detect_region
		openclaw_memory_select_sources
		if [ "$scheme" = "auto" ]; then
			openclaw_memory_recommend
			scheme="$OPENCLAW_MEMORY_RECOMMEND"
		fi
		case "$scheme" in
			qmd)
				scheme_label="QMD"
				OPENCLAW_MEMORY_EXPECT_PATH="$HOME/.bun (qmd 安装目录)"
				OPENCLAW_MEMORY_EXPECT_SIZE="约 20-50MB"
				;;
			local)
				scheme_label="Local"
				OPENCLAW_MEMORY_EXPECT_PATH="$HOME/.openclaw/models/embedding/embeddinggemma-300M-Q8_0.gguf"
				OPENCLAW_MEMORY_EXPECT_SIZE="约 350-600MB"
				;;
			*)
				echo "❌ 未知方案: $scheme"
				return 1
				;;
		esac
		OPENCLAW_MEMORY_AUTO_SCHEME="$scheme_label"
		openclaw_memory_auto_confirm "$scheme_label" || return 0
		case "$scheme" in
			qmd) openclaw_memory_auto_setup_qmd || return 1 ;;
			local) openclaw_memory_auto_setup_local || return 1 ;;
			*) return 1 ;;
		esac
		if [ "$OPENCLAW_MEMORY_CONFIG_ONLY" = "true" ]; then
			OPENCLAW_MEMORY_RESTARTED="false"
			openclaw_memory_render_auto_summary
			return 0
		fi
		echo "♻️ 重启 OpenClaw 网关"
		if declare -F start_gateway >/dev/null 2>&1; then
			start_gateway
		else
			openclaw gateway restart
		fi
		OPENCLAW_MEMORY_RESTARTED="true"
		openclaw_memory_render_auto_summary
		return 0
	}

	openclaw_memory_auto_setup_menu() {
		while true; do
			clear
			echo "======================================="
			echo "记忆方案自动部署"
			echo "======================================="
			echo "1. QMD"
			echo "2. Local"
			echo "3. Auto（自动选择）"
			echo "0. 返回上一级"
			echo "---------------------------------------"
			read -e -p "请输入你的选择: " auto_choice
			case "$auto_choice" in
				1)
					openclaw_memory_auto_setup_run "qmd"
					break_end
					;;
				2)
					openclaw_memory_auto_setup_run "local"
					break_end
					;;
				3)
					openclaw_memory_auto_setup_run "auto"
					break_end
					;;
				0)
					return 0
					;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}

	openclaw_memory_apply_scheme() {
		local scheme="$1"
		openclaw_memory_cleanup_legacy_keys
		case "$scheme" in
			qmd)
				openclaw_memory_config_set "memory.backend" "qmd"
				if [ $? -ne 0 ]; then
					echo "❌ 写入配置失败"
					return 1
				fi
				openclaw_memory_config_set "memory.qmd.command" "qmd" >/dev/null 2>&1
				;;
			local)
				openclaw_memory_config_set "memory.backend" "builtin"
				if [ $? -ne 0 ]; then
					echo "❌ 写入配置失败"
					return 1
				fi
				openclaw_memory_config_set "agents.defaults.memorySearch.provider" "local" >/dev/null 2>&1
				;;
			*)
				echo "❌ 未知方案: $scheme"
				return 1
			esac
		echo "✅ 已更新记忆方案配置"
		return 0
	}

	openclaw_memory_offer_restart() {
		echo "配置已写入，需要重启 OpenClaw 网关后生效。"
		read -e -p "是否立即重启 OpenClaw 网关？(Y/n): " restart_choice
		if [[ "$restart_choice" =~ ^[Nn]$ ]]; then
			echo "已跳过重启，可稍后执行: openclaw gateway restart"
			return 0
		fi
		if declare -F start_gateway >/dev/null 2>&1; then
			start_gateway
		else
			openclaw gateway restart
		fi
	}

	openclaw_memory_fix_index() {
		local backend include_dm
		backend=$(openclaw_memory_get_backend)
		if [ "$backend" = "qmd" ] && ! command -v qmd >/dev/null 2>&1; then
			echo "⚠️ 检测到当前方案为 QMD，但未安装 qmd 命令。"
			echo "   可切换 Local，或安装 bun + qmd 后再试。"
		fi
		include_dm=$(openclaw config get memory.qmd.includeDefaultMemory 2>/dev/null)
		echo "======================================="
		echo "索引修复诊断"
		echo "======================================="
		echo "当前 includeDefaultMemory: ${include_dm:-未设置}"
		echo ""
		if [ "$include_dm" = "false" ]; then
			echo "⚠️ 检测到 includeDefaultMemory=false"
			echo "   这会导致默认记忆文件（MEMORY.md + memory/*.md）不被索引"
			echo "   所以 Indexed 会一直显示 0/N"
			echo ""
			read -e -p "是否恢复为 true 并重建索引？(Y/n): " fix_choice
			if [[ ! "$fix_choice" =~ ^[Nn]$ ]]; then
				openclaw_memory_config_set "memory.qmd.includeDefaultMemory" true
				if [ $? -ne 0 ]; then
					echo "❌ 写入配置失败"
					break_end
					return 1
				fi
				echo "✅ 已恢复 includeDefaultMemory=true"
				openclaw_memory_rebuild_index_all
			else
				echo "已取消。"
			fi
		else
			echo "includeDefaultMemory 配置正常。"
			echo "将执行：清理旧索引 → 全量重建所有智能体索引"
			echo ""
			read -e -p "确认执行？(Y/n): " confirm_fix
			if [[ ! "$confirm_fix" =~ ^[Nn]$ ]]; then
				openclaw_memory_rebuild_index_all
			else
				echo "已取消。"
			fi
		fi
		break_end
	}

	openclaw_memory_scheme_menu() {
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 记忆方案"
			echo "======================================="
			local backend current_label
			backend=$(openclaw_memory_get_backend)
			case "$backend" in
				qmd) current_label="QMD" ;;
				builtin|local) current_label="Local" ;;
				*) current_label="未配置" ;;
			esac
			echo "当前方案: $current_label"
			echo ""
			echo "QMD  : 轻量索引，依赖 qmd 命令（适合网络受限）"
			echo "Local: 本地向量检索，依赖 embedding 模型文件"
			echo "Auto : 自动推荐（基于可用性 + 网络探测）"
			echo "---------------------------------------"
			echo "1. 切换 QMD（自动部署/已装则跳过）"
			echo "2. 切换 Local（自动部署/已装则跳过）"
			echo "3. Auto（自动推荐并自动部署）"
			echo "0. 返回上一级"
			echo "---------------------------------------"
			read -e -p "请输入你的选择: " scheme_choice
			case "$scheme_choice" in
				1)
					openclaw_memory_auto_setup_run "qmd"
					break_end
					;;
				2)
					openclaw_memory_auto_setup_run "local"
					break_end
					;;
				3)
					openclaw_memory_auto_setup_run "auto"
					break_end
					;;
				0)
					return 0
					;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}

	openclaw_memory_file_collect() {
		OPENCLAW_MEMORY_FILES=()
		OPENCLAW_MEMORY_FILE_LABELS=()
		local agent_lines agent_id base_dir memory_dir memory_file rel
		agent_lines=$(openclaw_memory_list_agents)
		while IFS=$'\t' read -r agent_id base_dir; do
			[ -z "$agent_id" ] && continue
			memory_dir="$base_dir/memory"
			memory_file="$base_dir/MEMORY.md"
			if [ -f "$memory_file" ]; then
				OPENCLAW_MEMORY_FILES+=("$memory_file")
				OPENCLAW_MEMORY_FILE_LABELS+=("$agent_id/MEMORY.md")
			fi
			if [ -d "$memory_dir" ]; then
				while IFS= read -r file; do
					[ -f "$file" ] || continue
					rel="${file#$base_dir/}"
					OPENCLAW_MEMORY_FILES+=("$file")
					OPENCLAW_MEMORY_FILE_LABELS+=("$agent_id/$rel")
				done < <(find "$memory_dir" -type f -name '*.md' | sort)
			fi
		done <<EOF
$agent_lines
EOF
	}

	openclaw_memory_file_render_list() {
		openclaw_memory_file_collect
		if [ ${#OPENCLAW_MEMORY_FILES[@]} -eq 0 ]; then
			echo "未找到记忆文件。"
			return 0
		fi
		echo "编号 | 归属 | 大小 | 修改时间"
		echo "---------------------------------------"
		local i file rel size mtime
		for i in "${!OPENCLAW_MEMORY_FILES[@]}"; do
			file="${OPENCLAW_MEMORY_FILES[$i]}"
			rel="${OPENCLAW_MEMORY_FILE_LABELS[$i]}"
			size=$(ls -lh "$file" | awk '{print $5}')
			mtime=$(date -d "$(stat -c %y "$file")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$file" | awk '{print $1" "$2}')
			printf "%s | %s | %s | %s\\n" "$((i+1))" "$rel" "$size" "$mtime"
		done
	}

	openclaw_memory_view_file() {
		local file="$1"
		[ -f "$file" ] || {
			echo "❌ 文件不存在: $file"
			return 1
		}
		local total_lines
		total_lines=$(wc -l < "$file" 2>/dev/null || echo 0)
		local default_lines=120
		local start_line count
		echo "文件: $file"
		echo "总行数: $total_lines"
		read -e -p "请输入起始行（回车默认末尾 $default_lines 行）: " start_line
		read -e -p "请输入显示行数（回车默认 $default_lines）: " count
		[ -z "$count" ] && count=$default_lines
		if [ -z "$start_line" ]; then
			if [ "$total_lines" -le "$count" ]; then
				start_line=1
			else
				start_line=$((total_lines - count + 1))
			fi
		fi
		if ! [[ "$start_line" =~ ^[0-9]+$ ]] || ! [[ "$count" =~ ^[0-9]+$ ]]; then
			echo "❌ 请输入有效的数字。"
			return 1
		fi
		if [ "$start_line" -lt 1 ]; then
			start_line=1
		fi
		if [ "$count" -le 0 ]; then
			echo "❌ 行数必须大于 0。"
			return 1
		fi
		local end_line=$((start_line + count - 1))
		if [ "$end_line" -gt "$total_lines" ]; then
			end_line=$total_lines
		fi
		if [ "$total_lines" -eq 0 ]; then
			echo "(空文件)"
			return 0
		fi
		echo "---------------------------------------"
		sed -n "${start_line},${end_line}p" "$file"
		echo "---------------------------------------"
	}

	openclaw_memory_files_menu() {
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 记忆文件"
			echo "======================================="
			openclaw_memory_file_render_list
			echo "---------------------------------------"
			read -e -p "请输入文件编号查看（0 返回）: " file_choice
			if [ "$file_choice" = "0" ]; then
				return 0
			fi
			if ! [[ "$file_choice" =~ ^[0-9]+$ ]]; then
				echo "无效的选择，请重试。"
				sleep 1
				continue
			fi
			openclaw_memory_file_collect
			if [ ${#OPENCLAW_MEMORY_FILES[@]} -eq 0 ]; then
				read -p "未找到记忆文件，按回车返回..."
				return 0
			fi
			local idx=$((file_choice-1))
			if [ "$idx" -lt 0 ] || [ "$idx" -ge ${#OPENCLAW_MEMORY_FILES[@]} ]; then
				echo "无效的编号，请重试。"
				sleep 1
				continue
			fi
			openclaw_memory_view_file "${OPENCLAW_MEMORY_FILES[$idx]}"
			read -p "按回车返回列表..."
			done
	}


	openclaw_memory_search_test() {
		read -e -p "输入搜索关键词: " query
		if [ -z "$query" ]; then
			echo "关键词不能为空。"
			return 1
		fi
		echo "正在搜索记忆..."
		openclaw memory search "$query" --max-results 5
	}

	openclaw_memory_deep_status() {
		echo "正在探测嵌入模型就绪状态..."
		openclaw memory status --deep
	}

	openclaw_memory_menu() {
		send_stats "OpenClaw记忆管理"
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 记忆管理"
			echo "======================================="
			openclaw_memory_render_status
			echo "1. 更新记忆索引"
			echo "2. 查看记忆文件"
			echo "3. 索引修复（Indexed 异常）"
			echo "4. 记忆方案（QMD/Local/Auto）"
			echo "5. 搜索测试（验证索引是否工作）"
			echo "6. 深度状态探测（检查嵌入模型）"
			echo "0. 返回上一级"
			echo "---------------------------------------"
			read -e -p "请输入你的选择: " memory_choice
			case "$memory_choice" in
				1)
					echo "即将更新记忆索引。"
					read -e -p "第一次确认：输入 yes 继续: " confirm_step1
					if [ "$confirm_step1" != "yes" ]; then
						echo "已取消。"
						break_end
						continue
					fi
				openclaw_memory_prepare_workspace_all
				read -e -p "二次确认：输入 force 使用全量（留空为增量）: " confirm_step2
				if [ "$confirm_step2" = "force" ]; then
					echo "⚠️ 全量重建更彻底，但耗时更长。"
					echo "推荐：输入 rebuild 进行安全重建（先备份索引库）。"
					read -e -p "第三次确认：输入 rebuild 执行安全重建；直接回车继续普通 force: " confirm_step3
					if [ "$confirm_step3" = "rebuild" ]; then
						openclaw_memory_rebuild_index_all
					else
						local fl_agent_lines fl_agent_id fl_workspace
						fl_agent_lines=$(openclaw_memory_list_agents)
						while IFS=$'\t' read -r fl_agent_id fl_workspace; do
							[ -z "$fl_agent_id" ] && continue
							openclaw memory index --agent "$fl_agent_id" --force
						done <<EOF
$fl_agent_lines
EOF
						openclaw gateway restart
						echo "✅ 已对所有智能体执行 force 重建并自动重启网关"
					fi
				else
					openclaw memory index
				fi
				break_end
					;;
				2)
					openclaw_memory_files_menu
					;;
				3)
					openclaw_memory_fix_index
					;;
				4)
					openclaw_memory_scheme_menu
					;;
				5)
					openclaw_memory_search_test
					break_end
					;;
				6)
					openclaw_memory_deep_status
					break_end
					;;
				0)
					return 0
					;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}

	openclaw_permission_config_file() {
		echo "$(openclaw_get_config_file)"
	}

	openclaw_permission_backup_file() {
		local backup_root
		backup_root=$(openclaw_backup_root)
		echo "${backup_root}/openclaw-permission-last.json"
	}

	openclaw_permission_require_openclaw() {
		if ! openclaw_has_command openclaw; then
			echo "❌ 未检测到 openclaw 命令，请先安装或初始化 OpenClaw。"
			return 1
		fi
		return 0
	}

	openclaw_permission_backup_current() {
		local config_file backup_file
		config_file=$(openclaw_permission_config_file)
		backup_file=$(openclaw_permission_backup_file)
		if [ ! -s "$config_file" ]; then
			echo "⚠️ 未找到 OpenClaw 配置文件，跳过权限备份。"
			return 1
		fi
		mkdir -p "$(dirname "$backup_file")"
		cp -f "$config_file" "$backup_file" >/dev/null 2>&1 || {
			echo "⚠️ 权限备份失败：$backup_file"
			return 1
		}
		echo "✅ 已备份当前权限配置: $backup_file"
		return 0
	}

	openclaw_permission_restore_backup() {
		local config_file backup_file
		config_file=$(openclaw_permission_config_file)
		backup_file=$(openclaw_permission_backup_file)
		if [ ! -s "$backup_file" ]; then
			echo "❌ 未找到可恢复的权限备份文件。"
			return 1
		fi
		cp -f "$backup_file" "$config_file" >/dev/null 2>&1 || {
			echo "❌ 权限恢复失败：$backup_file"
			return 1
		}
		echo "✅ 已恢复切换前权限配置"
		openclaw_permission_restart_gateway || true
		return 0
	}

	openclaw_permission_restart_gateway() {
		if ! openclaw_has_command openclaw; then
			echo "❌ 未检测到 openclaw，无法重启 OpenClaw Gateway。"
			return 1
		fi
		echo "正在重启 OpenClaw Gateway..."
		openclaw gateway restart >/dev/null 2>&1 || {
			openclaw gateway stop >/dev/null 2>&1
			openclaw gateway start >/dev/null 2>&1
		}
	}

	openclaw_permission_get_value() {
		local path="$1"
		local config_file
		config_file=$(openclaw_permission_config_file)

		if openclaw_has_command openclaw; then
			local value
			value=$(openclaw config get "$path" 2>&1 | head -n 1)
			if [ -n "$value" ]; then
				if echo "$value" | grep -qi "config path not found"; then
					echo "(unset)"
					return 0
				fi
				if [ "$value" = "null" ]; then
					echo "(unset)"
				else
					if echo "$value" | grep -q '^".*"$'; then
						value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//')
					fi
					echo "$value"
				fi
				return 0
			fi
		fi

		[ -f "$config_file" ] || { echo "(unset)"; return 0; }

		if openclaw_has_command jq; then
			local jq_value
			jq_value=$(jq -r --arg p "$path" 'getpath($p|split(".")) // "(unset)"' "$config_file" 2>/dev/null) || jq_value="(unset)"
			[ "$jq_value" = "null" ] && jq_value="(unset)"
			echo "$jq_value"
			return 0
		fi

		if openclaw_has_command python3; then
			python3 - "$config_file" "$path" <<'PY'
import json, sys
path = sys.argv[2]
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    obj = json.load(f)
cur = obj
for part in path.split('.'):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        print('(unset)')
        raise SystemExit(0)
if isinstance(cur, bool):
    print('true' if cur else 'false')
elif cur is None:
    print('(unset)')
else:
    print(json.dumps(cur, ensure_ascii=False) if isinstance(cur, (dict, list)) else str(cur))
PY
			return 0
		fi

		echo "(unset)"
		return 0
	}

	openclaw_permission_unset_optional() {
		local key="$1"
		local probe
		if ! openclaw_has_command openclaw; then
			return 1
		fi
		if openclaw config unset "$key" >/dev/null 2>&1; then
			return 0
		fi
		probe=$(openclaw config get "$key" 2>&1 | head -n 1)
		if [ -z "$probe" ] || [ "$probe" = "null" ] || [ "$probe" = "(unset)" ] || echo "$probe" | grep -qi "config path not found"; then
			return 0
		fi
		return 1
	}

	openclaw_permission_detect_mode() {
		local config_file
		config_file=$(openclaw_permission_config_file)
		[ ! -f "$config_file" ] && { echo "未知模式"; return; }

		python3 - "$config_file" <<'PY'
import json, sys

def get_v(o, p):
    for k in p.split('.'):
        if isinstance(o, dict) and k in o:
            o = o[k]
        else:
            return "(unset)"
    return str(o).lower()

try:
    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        d = json.load(f)
    p = get_v(d, "tools.profile")
    s = get_v(d, "tools.exec.security")
    a = get_v(d, "tools.exec.ask")
    e = get_v(d, "tools.elevated.enabled")
    b = get_v(d, "commands.bash")
    ap = get_v(d, "tools.exec.applyPatch.enabled")
    w = get_v(d, "tools.exec.applyPatch.workspaceOnly")

    if p == "coding" and s == "allowlist" and a == "on-miss" and e == "false" and b == "false" and ap == "false":
        print("标准安全模式")
    elif p == "coding" and s == "allowlist" and a == "on-miss" and e == "true" and b == "true" and ap == "true" and w == "true":
        print("开发增强模式")
    elif (p == "full" or p == "(unset)") and s == "full" and a == "off" and e == "true" and b == "true" and ap == "true":
        print("完全开放模式")
    else:
        print("自定义模式")
except Exception:
    print("自定义模式")
PY
	}

		openclaw_permission_update_exec_approvals() {
		local sec="$1"
		local ask="$2"
		local fallback="$3"
		local approvals_file="$HOME/.openclaw/exec-approvals.json"

		mkdir -p "$HOME/.openclaw"

		# 生成 JSON 并通过 openclaw approvals set --stdin 写入（优先）
		# 若 CLI 不支持则回退直接写文件
		local json_payload
		json_payload=$(python3 -c '
import json, sys, os
path = sys.argv[1]
try:
    if os.path.exists(path):
        with open(path, "r") as f:
            data = json.load(f)
    else:
        data = {"version": 1, "defaults": {}}
except Exception:
    data = {"version": 1, "defaults": {}}
if "defaults" not in data:
    data["defaults"] = {}
data["defaults"]["security"] = sys.argv[2]
data["defaults"]["ask"] = sys.argv[3]
data["defaults"]["askFallback"] = sys.argv[4]
data["defaults"]["autoAllowSkills"] = True
print(json.dumps(data, indent=2))
' "$approvals_file" "$sec" "$ask" "$fallback")

		if openclaw_has_command openclaw && echo "$json_payload" | openclaw approvals set --stdin >/dev/null 2>&1; then
			return 0
		fi
		# 回退：直接写文件
		echo "$json_payload" > "$approvals_file"
	}

	openclaw_permission_render_status() {
		echo "应用层配置: ~/.openclaw/openclaw.json"
		echo "宿主机审批: ~/.openclaw/exec-approvals.json"
		echo "---------------------------------------"
		local current_profile current_sec current_ask current_elevated
		current_profile=$(openclaw config get tools.profile 2>/dev/null | head -n 1 | sed 's/^"//;s/"$//')
		current_sec=$(openclaw config get tools.exec.security 2>/dev/null | head -n 1 | sed 's/^"//;s/"$//')
		current_ask=$(openclaw config get tools.exec.ask 2>/dev/null | head -n 1 | sed 's/^"//;s/"$//')
		current_elevated=$(openclaw config get tools.elevated.enabled 2>/dev/null | head -n 1 | sed 's/^"//;s/"$//')
		# 清理空值
		[ -z "$current_profile" ] || echo "$current_profile" | grep -qi "config path not found" && current_profile=""
		[ -z "$current_sec" ] || echo "$current_sec" | grep -qi "config path not found" && current_sec=""
		[ -z "$current_ask" ] || echo "$current_ask" | grep -qi "config path not found" && current_ask=""
		[ -z "$current_elevated" ] || echo "$current_elevated" | grep -qi "config path not found" && current_elevated=""

		local current_mode="未知 / 自定义"
		if [ "$current_profile" = "full" ] && [ "$current_sec" = "full" ] && [ "$current_ask" = "off" ]; then
			current_mode="\033[1;31m完全开放模式\033[0m"
		elif [ "$current_profile" = "coding" ] && [ "$current_sec" = "allowlist" ] && [ "$current_ask" = "on-miss" ] && [ "$current_elevated" = "true" ]; then
			current_mode="\033[1;33m开发增强模式\033[0m"
		elif [ "$current_profile" = "coding" ] && [ "$current_sec" = "allowlist" ] && [ "$current_ask" = "on-miss" ] && [ "$current_elevated" != "true" ]; then
			current_mode="\033[1;32m标准安全模式\033[0m"
		elif [ -z "$current_profile" ] && [ -z "$current_sec" ]; then
			current_mode="\033[1;36m官方沙盒兜底\033[0m"
		fi
		echo -e "  当前综合安全等级: ${current_mode}"
		echo "---------------------------------------"
		echo -e "${gl_huang}[应用层 Tool Policy 状态]${gl_bai}"
		echo "  Profile (预设): ${current_profile:-(unset)}"
		echo "  Exec 限制: ${current_sec:-(unset)}"
		echo "  审批提示: ${current_ask:-(unset)}"
		echo "  提权开关: ${current_elevated:-(unset)}"

		echo -e "\n${gl_huang}[底层 Exec Approvals 状态]${gl_bai}"
		if openclaw_has_command openclaw; then
			local approvals_json
			approvals_json=$(openclaw approvals get --json 2>/dev/null)
			if [ -n "$approvals_json" ]; then
				python3 -c '
import json, sys
try:
    d = json.loads(sys.argv[1])
    defaults = d.get("file", {}).get("defaults", {})
    if not defaults:
        defaults = d.get("defaults", {})
    sec = defaults.get("security", "(unset)")
    ask = defaults.get("ask", "(unset)")
    fb = defaults.get("askFallback", "(unset)")
    auto = defaults.get("autoAllowSkills", False)
    print("  拦截策略 (Security): " + str(sec))
    print("  提示策略 (Ask): " + str(ask))
    print("  无UI兜底 (AskFallback): " + str(fb))
    print("  自动放行技能 (autoAllowSkills): " + ("on" if auto else "off"))
    exists = d.get("exists", True)
    if not exists:
        print("  (审批文件不存在，使用系统内置安全兜底)")
except Exception as e:
    print("  (解析失败: " + str(e) + ")")
' "$approvals_json"
			else
				echo "  (openclaw approvals get --json 无输出)"
			fi
		elif [ -f "$HOME/.openclaw/exec-approvals.json" ]; then
			python3 -c '
import json, os
path = os.path.expanduser("~/.openclaw/exec-approvals.json")
try:
    with open(path) as f:
        d = json.load(f).get("defaults", {})
    print("  拦截策略 (Security): " + str(d.get("security", "(unset)")))
    print("  提示策略 (Ask): " + str(d.get("ask", "(unset)")))
    print("  无UI兜底 (AskFallback): " + str(d.get("askFallback", "(unset)")))
except Exception:
    print("  (配置文件解析失败)")
'
		else
			echo "  (未配置，强制使用系统内置安全兜底策略)"
		fi
	}

	openclaw_permission_apply_standard() {
		send_stats "OpenClaw权限-标准安全模式"
		openclaw_permission_require_openclaw || return 1

		echo "正在配置应用层策略..."
		openclaw config set tools.profile coding >/dev/null 2>&1
		openclaw config set tools.exec.security allowlist >/dev/null 2>&1
		openclaw config set tools.exec.ask on-miss >/dev/null 2>&1
		openclaw config set tools.elevated.enabled false >/dev/null 2>&1
		openclaw config set tools.exec.strictInlineEval true >/dev/null 2>&1  # 拦截危险的内联代码
		openclaw config unset commands.bash >/dev/null 2>&1 # 废弃旧版参数

		echo "正在配置宿主机审批拦截..."
		openclaw_permission_update_exec_approvals "allowlist" "on-miss" "deny"

		openclaw_permission_restart_gateway
		echo -e "${gl_lv}✅ 已切换为标准安全模式 (所有危险命令将通过UI/TG请求你的审批)${gl_bai}"
	}

	openclaw_permission_apply_developer() {
		send_stats "OpenClaw权限-开发增强模式"
		openclaw_permission_require_openclaw || return 1

		echo "正在配置应用层策略..."
		openclaw config set tools.profile coding >/dev/null 2>&1
		openclaw config set tools.exec.security allowlist >/dev/null 2>&1
		openclaw config set tools.exec.ask on-miss >/dev/null 2>&1
		openclaw config set tools.elevated.enabled true >/dev/null 2>&1 # 允许智能体申请提权
		openclaw config set tools.exec.strictInlineEval false >/dev/null 2>&1

		echo "正在配置宿主机审批拦截..."
		openclaw_permission_update_exec_approvals "allowlist" "on-miss" "deny"

		openclaw_permission_restart_gateway
		echo -e "${gl_lv}✅ 已切换为开发增强模式 (允许提权，但常规危险命令依然需要审批)${gl_bai}"
	}

	openclaw_permission_apply_full() {
		send_stats "OpenClaw权限-完全开放模式"
		openclaw_permission_require_openclaw || return 1

		echo "正在配置应用层策略..."
		openclaw config set tools.profile full >/dev/null 2>&1
		openclaw config set tools.exec.security full >/dev/null 2>&1
		openclaw config set tools.exec.ask off >/dev/null 2>&1
		openclaw config set tools.elevated.enabled true >/dev/null 2>&1
		openclaw config set tools.exec.strictInlineEval false >/dev/null 2>&1

		echo "正在瓦解宿主机拦截防御..."
		# 这里的 full 和 off 将彻底绕过底层宿主机的 exec 审批系统
		openclaw_permission_update_exec_approvals "full" "off" "full"

		openclaw_permission_restart_gateway
		echo -e "${gl_lv}✅ 已切换为完全开放模式 (警告：所有宿主机命令拦截已失效，智能体具有最高权限)${gl_bai}"
	}

	openclaw_permission_restore_official_defaults() {
		send_stats "OpenClaw权限-恢复官方默认"
		openclaw_permission_require_openclaw || return 1

		echo "清理应用层强制覆盖..."
		openclaw config unset tools.profile >/dev/null 2>&1
		openclaw config unset tools.exec.security >/dev/null 2>&1
		openclaw config unset tools.exec.ask >/dev/null 2>&1
		openclaw config unset tools.elevated.enabled >/dev/null 2>&1
		openclaw config unset tools.exec.strictInlineEval >/dev/null 2>&1

		echo "清理宿主机拦截配置..."
		# 优先通过 CLI 清空审批配置，回退直接删文件
		if echo '{"version":1,"defaults":{}}' | openclaw approvals set --stdin >/dev/null 2>&1; then
			true
		else
			rm -f "$HOME/.openclaw/exec-approvals.json"
		fi

		openclaw_permission_restart_gateway
		echo -e "${gl_lv}✅ 已恢复到 OpenClaw 官方安全沙盒防御机制${gl_bai}"
	}

	openclaw_permission_run_audit() {
		echo "======================================="
		echo "运行 OpenClaw 官方安全审计与体检..."
		echo "======================================="
		openclaw security audit
		echo "---------------------------------------"
		read -e -p "是否尝试自动修复发现的安全隐患？(y/n): " fix_choice
		if [[ "$fix_choice" == "y" || "$fix_choice" == "Y" || "$fix_choice" == "yes" ]]; then
			openclaw security audit --fix
			echo -e "${gl_lv}✅ 自动修复完成。${gl_bai}"
		fi
		echo "按任意键返回..."
		read -n 1 -s
	}


	openclaw_permission_manage_allowlist() {
		while true; do
			clear
			echo "======================================="
			echo " Exec 命令白名单管理"
			echo "======================================="
			echo "当前白名单："
			local allowlist_json
			allowlist_json=$(openclaw approvals get --json 2>/dev/null)
			if [ -n "$allowlist_json" ]; then
				python3 -c '
import json, sys
try:
    d = json.loads(sys.argv[1])
    f = d.get("file", {})
    agents = f.get("agents", {})
    found = False
    for agent_id, agent_data in agents.items():
        al = agent_data.get("allowlist", [])
        if al:
            found = True
            print("  智能体 [%s]:" % agent_id)
            for item in al:
                print("    - %s" % item)
    if not found:
        print("  (空，未配置任何白名单规则)")
except Exception as e:
    print("  (解析失败: " + str(e) + ")")
' "$allowlist_json"
			else
				echo "  (无法获取)"
			fi
			echo "---------------------------------------"
			echo "1. 添加白名单规则"
			echo "2. 移除白名单规则"
			echo "0. 返回"
			echo "---------------------------------------"
			read -e -p "请选择: " al_choice
			case "$al_choice" in
				1)
					read -e -p "输入要放行的命令路径 (支持 glob，如 /usr/bin/git): " pattern
					[ -z "$pattern" ] && { echo "不能为空"; break_end; continue; }
					read -e -p "指定智能体ID (留空=所有智能体 *): " agent_id
					agent_id="${agent_id:-*}"
					openclaw approvals allowlist add --agent "$agent_id" "$pattern"
					break_end
					;;
				2)
					read -e -p "输入要移除的命令路径: " pattern
					[ -z "$pattern" ] && { echo "不能为空"; break_end; continue; }
					openclaw approvals allowlist remove "$pattern"
					break_end
					;;
				0) return 0 ;;
				*) echo "无效选择"; sleep 1 ;;
			esac
		done
	}

	openclaw_permission_menu() {
		send_stats "OpenClaw权限管理"
		while true; do
			clear
			echo "======================================="
			echo " OpenClaw 权限管理 (双层架构深度适配)"
			echo "======================================="
			openclaw_permission_render_status
			echo "---------------------------------------"
			echo -e "${gl_kjlan}1.${gl_bai} 切换为标准安全模式（日常推荐，弹卡片审批）"
			echo -e "${gl_kjlan}2.${gl_bai} 切换为开发增强模式（允许智能体申请提权）"
			echo -e "${gl_kjlan}3.${gl_bai} 切换为完全开放模式（${gl_hong}高风险！彻底解除所有宿主机拦截${gl_bai}）"
			echo -e "${gl_kjlan}4.${gl_bai} 恢复官方默认沙盒防御策略"
			echo -e "${gl_kjlan}5.${gl_bai} 运行底层安全审计与自动修复"
			echo -e "${gl_kjlan}6.${gl_bai} 管理 Exec 命令白名单"
			echo -e "${gl_kjlan}0.${gl_bai} 返回上一级"
			echo "---------------------------------------"
			read -e -p "请输入你的选择: " perm_choice
			case "$perm_choice" in
				1)
					echo "准备应用：标准安全模式"
					read -e -p "输入 yes 确认: " confirm
					if [ "$confirm" = "yes" ]; then openclaw_permission_apply_standard; else echo "已取消"; fi
					break_end
					;;
				2)
					echo "准备应用：开发增强模式"
					read -e -p "输入 yes 确认: " confirm
					if [ "$confirm" = "yes" ]; then openclaw_permission_apply_developer; else echo "已取消"; fi
					break_end
					;;
				3)
					echo -e "${gl_hong}⚠️ 完全开放模式会彻底瓦解 exec 审批并自动放行高危代码。${gl_bai}"
					read -e -p "输入 FULL 确认继续: " confirm
					if [ "$confirm" = "FULL" ]; then openclaw_permission_apply_full; else echo "已取消"; fi
					break_end
					;;
				4)
					echo "将清除所有定制覆盖，恢复 OpenClaw 刚安装时的严格沙盒状态。"
					read -e -p "输入 yes 确认: " confirm
					if [ "$confirm" = "yes" ]; then openclaw_permission_restore_official_defaults; else echo "已取消"; fi
					break_end
					;;
				5)
					openclaw_permission_run_audit
					;;
				6)
					openclaw_permission_manage_allowlist
					;;
				0)
					return 0
					;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}

	openclaw_multiagent_config_file() {
		local config_file
		config_file=$(openclaw_permission_config_file)
		if [ -s "$config_file" ]; then
			echo "$config_file"
			return 0
		fi
		openclaw config file 2>/dev/null | tail -n 1
	}

	openclaw_multiagent_default_agent() {
		local config_file
		config_file=$(openclaw_permission_config_file)
		if [ -s "$config_file" ]; then
			python3 - "$config_file" <<'PY'
import json,sys,os
path=sys.argv[1]
value="(unset)"
try:
    with open(path) as f:
        data=json.load(f)
    defaults=data.get("agents",{}).get("defaults",{}) if isinstance(data,dict) else {}
    value=defaults.get("agent") or None
    if not value:
        for item in data.get("agents",{}).get("list",[]) or []:
            if isinstance(item,dict) and (item.get("isDefault") or item.get("default")):
                value=item.get("id")
                break
    if not value:
        for item in data.get("agents",{}).get("list",[]) or []:
            if isinstance(item,dict) and item.get("id"):
                value=item.get("id")
                break
except Exception:
    value="(unset)"
print(value or "(unset)")
PY
			return 0
		fi
		local value
		value=$(openclaw config get agents.defaults.agent 2>&1 | head -n 1)
		if [ -z "$value" ] || echo "$value" | grep -qi "config path not found"; then
			value=$(openclaw agents list --json 2>/dev/null | python3 -c 'import json,sys
try:
 data=json.load(sys.stdin)
 print(next((x.get("id","(unset)") for x in data if x.get("isDefault")), "(unset)"))
except Exception:
 print("(unset)")' 2>/dev/null)
		fi
		[ -z "$value" ] && value="(unset)"
		if echo "$value" | grep -q '^".*"$'; then
			value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//')
		fi
		echo "$value"
	}

	openclaw_multiagent_require_openclaw() {
		if ! openclaw_has_command openclaw; then
			echo "❌ 未检测到 openclaw 命令，请先安装或初始化 OpenClaw。"
			return 1
		fi
		return 0
	}

	openclaw_multiagent_agents_json() {
		local result
		if openclaw_has_command openclaw; then
			result=$(openclaw agents list --json 2>/dev/null)
			if [ -n "$result" ] && python3 -c "import json,sys; json.loads(sys.argv[1])" "$result" 2>/dev/null; then
				echo "$result"
				return 0
			fi
		fi
		# 回退：从配置文件读取
		local config_file
		config_file=$(openclaw_permission_config_file)
		if [ -s "$config_file" ]; then
			python3 - "$config_file" <<'PY'
import json,sys,os
path=sys.argv[1]
try:
    with open(path) as f:
        data=json.load(f)
    agents=data.get("agents",{}).get("list",[])
    if not isinstance(agents,list):
        agents=[]
    print(json.dumps(agents, ensure_ascii=False))
except Exception:
    print("[]")
PY
			return 0
		fi
		echo '[]'
	}

	openclaw_multiagent_bindings_json() {
		local result
		if openclaw_has_command openclaw; then
			result=$(openclaw agents bindings --json 2>/dev/null)
			if [ -n "$result" ] && python3 -c "import json,sys; json.loads(sys.argv[1])" "$result" 2>/dev/null; then
				echo "$result"
				return 0
			fi
		fi
		# 回退：从配置文件读取
		local config_file
		config_file=$(openclaw_permission_config_file)
		if [ -s "$config_file" ]; then
			python3 - "$config_file" <<'PY'
import json,sys
path=sys.argv[1]
try:
    with open(path) as f:
        data=json.load(f)
    bindings=data.get("agents",{}).get("bindings",[])
    if not isinstance(bindings,list):
        bindings=[]
    results=[]
    for item in bindings:
        if not isinstance(item,dict):
            continue
        results.append({"agentId": item.get("agentId") or item.get("agent") or "?", "description": item.get("description") or "-"})
    print(json.dumps(results, ensure_ascii=False))
except Exception:
    print("[]")
PY
			return 0
		fi
		echo '[]'
	}

	openclaw_multiagent_sessions_json() {
		local result
		if openclaw_has_command openclaw; then
			result=$(openclaw sessions --json 2>/dev/null | grep -v '^\[')
			if [ -n "$result" ] && python3 -c "import json,sys; json.loads(sys.argv[1])" "$result" 2>/dev/null; then
				echo "$result"
				return 0
			fi
		fi
		# 回退：从文件系统读取
		python3 <<'PY'
import json,os
base=os.path.expanduser("~/.openclaw/agents")
sessions=[]
try:
    agent_dirs=[d for d in os.listdir(base) if os.path.isdir(os.path.join(base,d))]
except Exception:
    agent_dirs=[]
for agent_id in agent_dirs:
    path=os.path.join(base,agent_id,"sessions","sessions.json")
    if not os.path.exists(path):
        continue
    try:
        with open(path) as f:
            data=json.load(f)
    except Exception:
        continue
    if isinstance(data,dict):
        items=data.items()
    elif isinstance(data,list):
        items=[(item.get("key") or "?", item) for item in data if isinstance(item,dict)]
    else:
        continue
    for key,item in items:
        if not isinstance(item,dict):
            continue
        model=item.get("model") or "-"
        sessions.append({"agentId": agent_id, "key": key, "model": model})
print(json.dumps({"path":"(filesystem)","count":len(sessions),"sessions":sessions}, ensure_ascii=False))
PY
	}

	openclaw_multiagent_render_status() {
		local config_file default_agent
		config_file=$(openclaw_multiagent_config_file)
		default_agent=$(openclaw_multiagent_default_agent)
		echo "配置文件: ${config_file:-$(openclaw_permission_config_file)}"
		echo "默认智能体: $default_agent"
		python3 -c '
import json,sys
agents=json.loads(sys.argv[1] or "[]")
bindings=json.loads(sys.argv[2] or "[]")
sess_obj=json.loads(sys.argv[3] or "{}")
sessions=sess_obj.get("sessions",[]) if isinstance(sess_obj,dict) else []
print("已配置智能体数: %s" % len(agents))
print("路由绑定数: %s" % len(bindings))
print("会话总数: %s" % len(sessions))
print("---------------------------------------")
if not agents:
    print("当前未配置任何多智能体。")
else:
    for item in agents[:8]:
        aid = item.get("id","?")
        identity = item.get("identityName") or item.get("name") or "-"
        emoji = item.get("identityEmoji") or ""
        ws = item.get("workspace") or "-"
        model = item.get("model") or "-"
        is_default = item.get("isDefault", False)
        bcount = item.get("bindings", 0)
        default_tag = " [默认]" if is_default else ""
        print("- 智能体ID: \033[1;36m%s\033[0m%s" % (aid, default_tag))
        print("  身份名称: %s %s" % (identity, emoji))
        print("  模型: %s" % model)
        print("  工作目录: %s" % ws)
        print("  绑定数: %s" % bcount)
' "$(openclaw_multiagent_agents_json)" "$(openclaw_multiagent_bindings_json)" "$(openclaw_multiagent_sessions_json)"
	}

	openclaw_multiagent_list_agents() {
		send_stats "OpenClaw多智能体-列出Agent"
		python3 -c 'import json,sys; agents=json.loads(sys.argv[1] or "[]");
if not agents: print("暂无已配置 Agent。"); raise SystemExit(0)
for idx,item in enumerate(agents,1):
 print("%s. %s" % (idx, item.get("id","?"))); print("   workspace : %s" % item.get("workspace","-")); ident=(item.get("identityName") or "-") + ((" " + item.get("identityEmoji")) if item.get("identityEmoji") else ""); print("   identity  : %s" % ident.strip()); print("   model     : %s" % (item.get("model") or "-")); print("   bindings  : %s" % item.get("bindings",0)); print("   default   : %s" % ("yes" if item.get("isDefault") else "no"))' "$(openclaw_multiagent_agents_json)"
	}

	openclaw_multiagent_add_agent() {
		send_stats "OpenClaw多智能体-新增Agent"
		openclaw_multiagent_require_openclaw || return 1
		local agent_id workspace confirm
		read -e -p "请输入新的 Agent ID: " agent_id
		[ -z "$agent_id" ] && echo "已取消：Agent ID 不能为空。" && return 1
		read -e -p "请输入 workspace 路径（默认 ~/.openclaw/workspace-${agent_id}）: " workspace
		[ -z "$workspace" ] && workspace="~/.openclaw/workspace-${agent_id}"
		echo "将创建智能体: $agent_id"
		echo "工作目录: $workspace"
		read -e -p "输入 yes 确认继续: " confirm
		[ "$confirm" = "yes" ] || { echo "已取消"; return 1; }
		if openclaw agents add "$agent_id" --workspace "$workspace"; then
			echo "✅ 智能体创建成功: $agent_id"
			local name theme
			read -e -p "请输入智能体身份名称 (如: 代码专家): " name
			[ -z "$name" ] && name="$agent_id"
			read -e -p "请输入智能体性格主题 (如: 严谨、高效): " theme
			[ -z "$theme" ] && theme="助手"
			echo "正在配置智能体身份..."
			openclaw agents set-identity --agent "$agent_id" --name "$name" --theme "$theme"
		else
			echo "❌ 智能体创建失败"
			return 1
		fi
	}

	openclaw_multiagent_delete_agent() {
		send_stats "OpenClaw多智能体-删除Agent"
		openclaw_multiagent_require_openclaw || return 1
		local agent_id confirm
		read -e -p "请输入要删除的 Agent ID: " agent_id
		[ -z "$agent_id" ] && echo "已取消：Agent ID 不能为空。" && return 1
		echo "⚠️ 删除智能体可能影响其工作目录、路由绑定与会话路由。"
		read -e -p "输入 DELETE 确认删除 ${agent_id}: " confirm
		[ "$confirm" = "DELETE" ] || { echo "已取消"; return 1; }
		if openclaw agents delete "$agent_id"; then
			echo "✅ 智能体删除成功: $agent_id"
		else
			echo "❌ 智能体删除失败"
			return 1
		fi
	}

	openclaw_multiagent_list_bindings() {
		send_stats "OpenClaw多智能体-查看路由绑定"
		python3 -c '
import json,sys
bindings=json.loads(sys.argv[1] or "[]")
if not bindings:
    print("暂无路由绑定。")
    raise SystemExit(0)
for idx,item in enumerate(bindings,1):
    desc = item.get("description") or "-"
    print("%s. agent=%s | %s" % (idx, item.get("agentId","?"), desc))
' "$(openclaw_multiagent_bindings_json)"
	}

	openclaw_multiagent_add_binding() {
		send_stats "OpenClaw多智能体-新增路由绑定"
		openclaw_multiagent_require_openclaw || return 1
		local agent_id bind_value confirm
		read -e -p "请输入智能体 ID: " agent_id
		read -e -p "请输入路由绑定值（如 telegram:ops / discord:guild-a）: " bind_value
		{ [ -z "$agent_id" ] || [ -z "$bind_value" ]; } && echo "已取消：参数不能为空。" && return 1
		echo "将绑定智能体 [$agent_id] -> [$bind_value]"
		read -e -p "输入 yes 确认继续: " confirm
		[ "$confirm" = "yes" ] || { echo "已取消"; return 1; }
		if openclaw agents bind --agent "$agent_id" --bind "$bind_value"; then
			echo "✅ 路由绑定添加成功"
		else
			echo "❌ 路由绑定添加失败"
			return 1
		fi
	}

	openclaw_multiagent_remove_binding() {
		send_stats "OpenClaw多智能体-移除路由绑定"
		openclaw_multiagent_require_openclaw || return 1
		local agent_id bind_value confirm
		read -e -p "请输入智能体 ID: " agent_id
		read -e -p "请输入要移除的路由绑定值: " bind_value
		{ [ -z "$agent_id" ] || [ -z "$bind_value" ]; } && echo "已取消：参数不能为空。" && return 1
		echo "将移除智能体 [$agent_id] 的路由绑定 [$bind_value]"
		read -e -p "输入 yes 确认继续: " confirm
		[ "$confirm" = "yes" ] || { echo "已取消"; return 1; }
		if openclaw agents unbind --agent "$agent_id" --bind "$bind_value"; then
			echo "✅ 路由绑定移除成功"
		else
			echo "❌ 路由绑定移除失败"
			return 1
		fi
	}


	openclaw_multiagent_show_sessions() {
		send_stats "OpenClaw多智能体-会话概况"
		python3 -c '
import json,sys
sess_obj=json.loads(sys.argv[1] or "{}")
sessions=sess_obj.get("sessions",[]) if isinstance(sess_obj,dict) else []
if not sessions:
    print("暂无 session 数据。")
    raise SystemExit(0)
by_agent={}
for item in sessions:
    aid = item.get("agentId","?")
    by_agent[aid] = by_agent.get(aid, 0) + 1
print("会话汇总:")
for agent_id,count in sorted(by_agent.items()):
    print("- %s: %s" % (agent_id, count))
print("---------------------------------------")
for item in sessions[:10]:
    key = item.get("key","-")
    model = item.get("model") or "-"
    aid = item.get("agentId","?")
    tokens = ""
    it = item.get("inputTokens")
    ot = item.get("outputTokens")
    if it is not None:
        tokens = " | in=%s out=%s" % (it, ot or 0)
    print("%s | %s | %s%s" % (aid, key, model, tokens))
' "$(openclaw_multiagent_sessions_json)"
	}

	openclaw_multiagent_health_check() {
		send_stats "OpenClaw多智能体-健康检查"
		openclaw_multiagent_require_openclaw || return 1
		local config_file
		config_file=$(openclaw_multiagent_config_file)
		echo "检查配置文件: ${config_file:-$(openclaw_permission_config_file)}"
		openclaw config validate || echo "⚠️ 配置校验未通过，请检查上方输出。"
		python3 -c '
import json,sys,os
agents=json.loads(sys.argv[1] or "[]")
bindings=json.loads(sys.argv[2] or "[]")
print("---------------------------------------")
if not agents:
    print("⚠️ 未发现已配置智能体。")
else:
    for item in agents:
        ws = item.get("workspace") or ""
        aid = item.get("id","?")
        if ws and os.path.isdir(os.path.expanduser(ws)):
            state = "OK"
        elif aid == "main":
            state = "OK"
        else:
            state = "MISSING"
        model = item.get("model") or "-"
        bcount = item.get("bindings", 0)
        print("agent=%s workspace=%s model=%s bindings=%s [%s]" % (aid, ws or "-", model, bcount, state))
print("路由绑定数=%s" % len(bindings))
print("✅ 多智能体健康检查完成")
' "$(openclaw_multiagent_agents_json)" "$(openclaw_multiagent_bindings_json)"
		echo ""
		echo "运行安全审计..."
		openclaw security audit 2>/dev/null || echo "⚠️ 安全审计命令不可用"
	}


	openclaw_multiagent_set_identity() {
		openclaw_multiagent_require_openclaw || return 1
		openclaw_multiagent_list_agents
		read -e -p "输入要修改身份的智能体ID: " agent_id
		[ -z "$agent_id" ] && { echo "ID 不能为空"; return 1; }
		echo "修改选项（留空跳过）："
		read -e -p "  新名称: " new_name
		read -e -p "  新 Emoji: " new_emoji
		local cmd="openclaw agents set-identity --agent $agent_id"
		[ -n "$new_name" ] && cmd="$cmd --name $new_name"
		[ -n "$new_emoji" ] && cmd="$cmd --emoji $new_emoji"
		echo "也可以从 IDENTITY.md 自动读取身份信息。"
		read -e -p "是否从 IDENTITY.md 读取？(y/n): " from_id
		if [ "$from_id" = "y" ]; then
			cmd="openclaw agents set-identity --agent $agent_id --from-identity"
		fi
		eval "$cmd"
	}

	openclaw_multiagent_cleanup_sessions() {
		openclaw_multiagent_require_openclaw || return 1
		echo "即将清理过期/冗余会话数据..."
		read -e -p "输入 yes 确认: " confirm
		[ "$confirm" != "yes" ] && { echo "已取消"; return 0; }
		openclaw sessions cleanup
	}

	openclaw_multiagent_menu() {
		send_stats "OpenClaw多智能体管理"
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 多智能体管理"
			echo "======================================="
			openclaw_multiagent_render_status
			echo "---------------------------------------"
			echo "1. 新增智能体"
			echo "2. 删除智能体"
			echo "3. 查看路由绑定"
			echo "4. 新增路由绑定"
			echo "5. 移除路由绑定"
			echo "6. 查看会话概况"
			echo "7. 运行多智能体健康检查"
			echo "8. 修改智能体身份（名称/Emoji）"
			echo "9. 清理过期会话"
			echo "0. 返回上一级"
			echo "---------------------------------------"
			read -e -p "请输入你的选择: " multi_choice
			case "$multi_choice" in
				1) openclaw_multiagent_add_agent; break_end ;;
				2) openclaw_multiagent_delete_agent; break_end ;;
				3) openclaw_multiagent_list_bindings; break_end ;;
				4) openclaw_multiagent_add_binding; break_end ;;
				5) openclaw_multiagent_remove_binding; break_end ;;
				6) openclaw_multiagent_show_sessions; break_end ;;
				7) openclaw_multiagent_health_check; break_end ;;
				8) openclaw_multiagent_set_identity; break_end ;;
				9) openclaw_multiagent_cleanup_sessions; break_end ;;
				0) return 0 ;;
				*) echo "无效的选择，请重试。"; sleep 1 ;;
			esac
		done
	}


openclaw_backup_restore_menu() {

		send_stats "OpenClaw备份与还原"
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 备份与还原"
			echo "======================================="
			openclaw_backup_render_file_list
			echo "---------------------------------------"
			echo "1. 备份记忆全量"
			echo "2. 还原记忆全量"
			echo "3. 备份 OpenClaw 项目（默认安全模式）"
			echo "4. 还原 OpenClaw 项目（高级/高风险）"
			echo "5. 删除备份文件"
			echo "0. 返回上一级"
			echo "---------------------------------------"
			read -e -p "请输入你的选择: " backup_choice

			case "$backup_choice" in
				1) openclaw_memory_backup_export ;;
				2) openclaw_memory_backup_import ;;
				3) openclaw_project_backup_export ;;
				4) openclaw_project_backup_import ;;
				5) openclaw_backup_delete_file ;;
				0) return 0 ;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}



	openclaw_custom_backup_root() {
		echo "$HOME/openclaw_custom_backups"
	}

	openclaw_custom_data_dir() {
		local config_file
		config_file=$(openclaw_get_config_file)
		dirname "$config_file"
	}

	openclaw_custom_is_running() {
		pgrep -f "openclaw.*gateway" >/dev/null 2>&1
	}

	openclaw_custom_stop_for_backup() {
		echo "正在停止 OpenClaw Gateway..."
		tmux kill-session -t gateway >/dev/null 2>&1 || true
		if command -v openclaw >/dev/null 2>&1; then
			openclaw gateway stop >/dev/null 2>&1 || true
			openclaw gateway shutdown >/dev/null 2>&1 || true
		fi
		local i
		for i in {1..20}; do
			if ! openclaw_custom_is_running; then
				break
			fi
			sleep 1
		done
		sleep 2
		sync
	}

	openclaw_custom_install_or_update() {
		echo "正在安装/更新 OpenClaw..."
		install git jq curl python3
		install_node_and_tools
		git config --global url."${gh_proxy}github.com/".insteadOf ssh://git@github.com/ >/dev/null 2>&1 || true
		git config --global url."${gh_proxy}github.com/".insteadOf git@github.com: >/dev/null 2>&1 || true
		npm install -g openclaw@latest || return 1
		hash -r
		return 0
	}

	openclaw_custom_ensure_installed() {
		if command -v openclaw >/dev/null 2>&1; then
			return 0
		fi
		echo "未检测到 OpenClaw，正在自动安装..."
		openclaw_custom_install_or_update
	}

	openclaw_custom_start_after_restore() {
		if command -v openclaw >/dev/null 2>&1; then
			echo "正在启动 OpenClaw Gateway..."
			# 不再执行 openclaw onboard --install-daemon，避免恢复后卡在交互式 onboard。
			# 这里只做非交互启动，并加 timeout 防止长时间无输出卡住菜单。
			timeout 30 openclaw gateway stop >/dev/null 2>&1 || true
			if timeout 90 openclaw gateway start; then
				add_app_id
				return 0
			else
				echo "⚠️ OpenClaw Gateway 启动命令超时或失败，请回主菜单用 2 号手动启动/查看日志。"
				return 1
			fi
		fi
		echo "❌ 未检测到 openclaw 命令，无法启动 Gateway。"
		return 1
	}

	openclaw_custom_backup_full() {
		send_stats "OpenClaw自制全量备份"
		local data_dir backup_root ts archive parent base confirm tar_status was_running
		openclaw_custom_ensure_installed || {
			echo "❌ OpenClaw 自动安装失败，无法备份。"
			return 1
		}

		data_dir=$(openclaw_custom_data_dir)
		backup_root=$(openclaw_custom_backup_root)
		ts=$(date +%Y%m%d_%H%M%S)
		archive="$backup_root/openclaw_custom_full_${ts}.tar.gz"
		was_running=0

		if openclaw_custom_is_running; then
			was_running=1
		fi

		if [ ! -d "$data_dir" ]; then
			echo "❌ 未找到 OpenClaw 数据目录：$data_dir"
			return 1
		fi

		echo "即将备份 OpenClaw 自制全量数据：$data_dir"
		echo "备份前会先停止 Gateway，等待缓存/数据库落库，备份完成后不会自动启动，请手动启动。"
		echo "注意：备份可能包含 API Key、机器人 Token、会话、记忆等敏感信息，请妥善保管。"
		read -e -p "确认开始备份？(y/N): " confirm
		if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
			echo "已取消。"
			return 0
		fi

		openclaw_custom_stop_for_backup
		mkdir -p "$backup_root"
		parent=$(dirname "$data_dir")
		base=$(basename "$data_dir")

		tar \
			--exclude="$base/cache" \
			--exclude="$base/logs/*.log" \
			-czf "$archive" \
			-C "$parent" "$base"
		tar_status=$?

		echo "备份流程已结束，OpenClaw Gateway 保持停止状态；如需运行请回主菜单手动启动。"

		if [ "$tar_status" -eq 0 ]; then
			echo "✅ 备份完成：$archive"
		else
			echo "❌ 备份失败。"
			rm -f "$archive"
			return 1
		fi
	}

	openclaw_custom_restore_full() {
		send_stats "OpenClaw自制全量还原"
		local data_dir backup_root search_dir path_choice backups count i selected archive parent ts old_dir confirm
		data_dir=$(openclaw_custom_data_dir)
		backup_root=$(openclaw_custom_backup_root)

		echo "备份包查找路径："
		echo "  1) $backup_root"
		echo "  2) $HOME"
		echo ""
		read -e -p "请选择备份包查找路径 [1-2，默认 1]: " path_choice
		case "$path_choice" in
			""|1) search_dir="$backup_root" ;;
			2) search_dir="$HOME" ;;
			0) echo "已取消。"; return 0 ;;
			*) echo "输入错误。"; return 1 ;;
		esac

		if [ ! -d "$search_dir" ]; then
			echo "❌ 路径不存在：$search_dir"
			return 1
		fi

		mapfile -t backups < <(find "$search_dir" -maxdepth 1 -type f -name 'openclaw_custom_full_*.tar.gz' | sort -r)
		count="${#backups[@]}"
		echo ""
		echo "可用的备份"
		echo "-------------------------"
		if [ "$count" -eq 0 ]; then
			echo "未在 $search_dir 找到 openclaw_custom_full_*.tar.gz 备份包。"
			return 1
		fi
		for i in "${!backups[@]}"; do
			printf "  %s. %s\n" "$((i+1))" "${backups[$i]}"
		done
		echo ""
		read -e -p "回车键还原最新的备份，序号选择备份恢复。输入0退出：" selected
		[ -z "$selected" ] && selected=1
		if [ "$selected" = "0" ]; then
			echo "已取消。"
			return 0
		fi
		if ! [[ "$selected" =~ ^[0-9]+$ ]] || [ "$selected" -lt 1 ] || [ "$selected" -gt "$count" ]; then
			echo "输入错误。"
			return 1
		fi
		archive="${backups[$((selected-1))]}"

		if ! tar -tzf "$archive" >/dev/null 2>&1; then
			echo "❌ 备份包无法读取或已损坏：$archive"
			return 1
		fi
		if ! tar -tzf "$archive" 2>/dev/null | grep -qx '\.openclaw/'; then
			echo "❌ 备份包结构不正确：包内必须包含 .openclaw/ 目录。"
			return 1
		fi

		echo "将从以下备份还原：$archive"
		echo "警告：当前 $data_dir 会被移动为 .before_restore 备份，然后替换为所选备份。"
		echo "还原前会停止 OpenClaw；如果新机器没安装 OpenClaw，会自动安装/更新最新版，启动请回主菜单手动执行 2 号。"
		read -e -p "确认还原？(y/N): " confirm
		if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
			echo "已取消。"
			return 0
		fi

		openclaw_custom_stop_for_backup
		parent=$(dirname "$data_dir")
		ts=$(date +%Y%m%d_%H%M%S)
		old_dir="${data_dir}.before_restore_${ts}"
		mkdir -p "$parent"

		if [ -e "$data_dir" ]; then
			mv "$data_dir" "$old_dir" || {
				echo "❌ 无法移动当前数据目录。"
				return 1
			}
			echo "当前数据已保留为：$old_dir"
		fi

		if tar -xzf "$archive" -C "$parent"; then
			if [ ! -d "$data_dir" ]; then
				echo "❌ 备份包结构异常，未还原出 $data_dir。"
				[ -d "$old_dir" ] && [ ! -e "$data_dir" ] && mv "$old_dir" "$data_dir"
				return 1
			fi
			echo "✅ OpenClaw 数据还原完成。"
		else
			echo "❌ 解压还原失败，正在尝试回滚。"
			rm -rf "$data_dir"
			[ -d "$old_dir" ] && mv "$old_dir" "$data_dir"
			return 1
		fi

		openclaw_custom_install_or_update || {
			echo "❌ OpenClaw 安装/更新失败。数据已还原，但程序可能未安装成功。"
			return 1
		}
		if command -v openclaw >/dev/null 2>&1; then
			echo "正在安装/修复 OpenClaw Gateway systemd 服务..."
			timeout 60 openclaw gateway install || echo "⚠️ Gateway 服务安装失败，请回主菜单手动执行 2 号启动。"
		fi
		echo "✅ 还原完成。OpenClaw Gateway 服务已尝试安装/修复；如未运行，请回主菜单手动执行 2 号启动。"
	}

	openclaw_custom_backup_restore_menu() {
		send_stats "OpenClaw备份与还原自制版本"
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 备份与还原自制版本"
			echo "======================================="
			echo "备份目录：$(openclaw_custom_backup_root)"
			echo "数据目录：$(openclaw_custom_data_dir)"
			echo "---------------------------------------"
			echo "1. 备份 OpenClaw 自制全量"
			echo "2. 还原 OpenClaw 自制全量（自动安装/更新，手动启动）"
			echo "0. 返回上一级"
			echo "---------------------------------------"
			read -e -p "请输入你的选择: " custom_choice
			case "$custom_choice" in
				1) openclaw_custom_backup_full; break_end ;;
				2) openclaw_custom_restore_full; break_end ;;
				0) return 0 ;;
				*) echo "无效的选择，请重试。"; sleep 1 ;;
			esac
		done
	}

	update_moltbot() {
		echo "更新 OpenClaw..."
		send_stats "更新 OpenClaw..."
		install_node_and_tools
		git config --global url."${gh_proxy}github.com/".insteadOf ssh://git@github.com/
		git config --global url."${gh_proxy}github.com/".insteadOf git@github.com:
		npm install -g openclaw@latest
		crontab -l 2>/dev/null | grep -v "s gateway" | crontab -
		start_gateway
		hash -r
		add_app_id
		echo "更新完成"
		break_end
	}


	uninstall_moltbot() {
		echo "卸载 OpenClaw..."
		send_stats "卸载 OpenClaw..."
		openclaw uninstall
		npm uninstall -g openclaw
		crontab -l 2>/dev/null | grep -v "s gateway" | crontab -
		rm -rf "$HOME/.openclaw"
		[ "$HOME" != "/root" ] && [ -d /root/.openclaw ] && echo "⚠️ 检测到 root 目录下仍存在 /root/.openclaw，如需清理请手动处理"
		hash -r
		sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
		echo "卸载完成"
		break_end
	}

	nano_openclaw_json() {
		send_stats "编辑 OpenClaw 配置文件"
		install nano
		nano "$(openclaw_get_config_file)"
		start_gateway
	}






	openclaw_find_webui_domain() {
		local conf domain_list

		domain_list=$(
			grep -R "18789" /home/web/conf.d/*.conf 2>/dev/null \
			| awk -F: '{print $1}' \
			| sort -u \
			| while read conf; do
				basename "$conf" .conf
			done
		)

		if [ -n "$domain_list" ]; then
			echo "$domain_list"
		fi
	}



	openclaw_show_webui_addr() {
		local local_ip token domains

		echo "=================================="
		echo "OpenClaw WebUI 访问地址"
		local_ip="127.0.0.1"

		token=$(
			openclaw dashboard 2>/dev/null \
			| sed -n 's/.*:18789\/#token=\([a-f0-9]\+\).*/\1/p' \
			| head -n 1
		)
		echo
		echo "本机地址："
		echo "http://${local_ip}:18789/#token=${token}"

		domains=$(openclaw_find_webui_domain)
		if [ -n "$domains" ]; then
			echo "域名地址："
			echo "$domains" | while read d; do
				echo "https://${d}/#token=${token}"
			done
		fi

		echo "=================================="
	}



	# 添加域名（调用你给的函数）
	openclaw_domain_webui() {
		add_yuming
		ldnmp_Proxy ${yuming} 127.0.0.1 18789

		token=$(
			openclaw dashboard 2>/dev/null \
			| sed -n 's/.*:18789\/#token=\([a-f0-9]\+\).*/\1/p' \
			| head -n 1
		)

		clear
		echo "访问地址:"
		echo "https://${yuming}/#token=$token"
		echo "先访问URL触发设备ID，然后回车下一步进行配对。"
		read
		echo -e "${gl_kjlan}正在加载设备列表……${gl_bai}"
		# 自动添加域名到 allowedOrigins
		config_file=$(openclaw_get_config_file)
		if [ -f "$config_file" ]; then
			new_origin="https://${yuming}"
			# 使用 jq 安全修改 JSON，确保结构存在且不重复添加域名
			if command -v jq >/dev/null 2>&1; then
				tmp_json=$(mktemp)
				jq 'if .gateway.controlUi == null then .gateway.controlUi = {"allowedOrigins": ["http://127.0.0.1"]} else . end | if (.gateway.controlUi.allowedOrigins | contains([$origin]) | not) then .gateway.controlUi.allowedOrigins += [$origin] else . end' --arg origin "$new_origin" "$config_file" > "$tmp_json" && mv "$tmp_json" "$config_file"
				echo -e "${gl_kjlan}已将域名 ${yuming} 加入 allowedOrigins 配置${gl_bai}"
				openclaw gateway restart >/dev/null 2>&1
			fi
		fi

		openclaw devices list

		read -e -p "请输入 Request_Key: " Request_Key

		[ -z "$Request_Key" ] && {
			echo "Request_Key 不能为空"
			return 1
		}

		openclaw devices approve "$Request_Key"

	}

	# 删除域名
	openclaw_remove_domain() {
		echo "域名格式 example.com 不带https://"
		web_del
	}

	# 主菜单
	openclaw_webui_menu() {

		send_stats "WebUI访问与设置"
		while true; do
			clear
			openclaw_show_webui_addr
			echo
			echo "1. 添加域名访问"
			echo "2. 删除域名访问"
			echo "0. 退出"
			echo
			read -e -p "请选择: " choice

			case "$choice" in
				1)
					openclaw_domain_webui
					echo
					read -p "按回车返回菜单..."
					;;
				2)
					openclaw_remove_domain
					read -p "按回车返回菜单..."
					;;
				0)
					break
					;;
				*)
					echo "无效选项"
					sleep 1
					;;
			esac
		done
	}



	# 主循环
	while true; do
		show_menu
		read choice
		case $choice in
			1) install_moltbot ;;
			2) start_bot ;;
			3) stop_bot ;;
			4) view_logs ;;
			5) change_model ;;
			6) openclaw_api_manage_menu ;;
			7) change_tg_bot_code ;;
			8) install_plugin ;;
			9) install_skill ;;
			10) nano_openclaw_json ;;
			11) send_stats "初始化配置向导"
				openclaw onboard --install-daemon
				break_end
				;;
			12) send_stats "健康检测与修复"
				openclaw doctor --fix
				break_end
				;;
			13) openclaw_webui_menu ;;
			14) send_stats "TUI命令行对话"
				openclaw tui
				break_end
			 	;;
			15) openclaw_memory_menu ;;
			16) openclaw_permission_menu ;;
			17) openclaw_multiagent_menu ;;
			18) openclaw_backup_restore_menu ;;
			19) update_moltbot ;;
			20) uninstall_moltbot ;;
			188) openclaw_custom_backup_restore_menu ;;
			*) break ;;
		esac
	done
