
#!/usr/bin/env bash
# 自包含分发入口：内嵌全部离线框架源码，不下载业务模块。
set -u
umask 077
[[ ${BASH_SOURCE[0]} == "$0" ]] || return 0
self=$(readlink -f -- "${BASH_SOURCE[0]}") || exit 1
if [[ $EUID != 0 ]]; then printf '错误：初始化/运行需要 root 权限。\n' >&2; exit 1; fi
missing=()
for cmd in python3 flock sha256sum stat bash; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if [[ ! -r /etc/os-release ]]; then printf '无法检测发行版\n' >&2; exit 1; fi
# 系统可信元数据，不读取用户配置为代码。
# shellcheck source=/dev/null
source /etc/os-release
if [[ ${ID:-} != debian || ( ${VERSION_ID:-} != 12 && ${VERSION_ID:-} != 13 ) ]]; then
    printf '当前仅支持 Debian 12/13。\n' >&2; exit 1
fi
if (( ${#missing[@]} )); then
    printf '必要工具缺失：%s\n' "${missing[*]}"
    for arg in "$@"; do
        [[ $arg != --dry-run ]] || { printf 'Dry-run：不安装依赖。\n'; exit 1; }
    done
    printf '允许安装运行依赖 python3/util-linux/coreutils？输入小写 yes：'
    IFS= read -r answer || exit 1
    [[ $answer == yes ]] || exit 1
    apt-get update && apt-get install -y --no-install-recommends python3 util-linux coreutils || exit 1
fi
printf '系统检测：Debian %s；root 权限及必要工具可用。\n' "$VERSION_ID"
# FD 3 保留交互输入，Python 源码来自 heredoc。
python3 - "$self" "$@" 3<&0 <<'ABC_BOOTSTRAP_PY'
import fcntl
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

sys.stdin = os.fdopen(3)
SELF = Path(sys.argv[1]).resolve()
ARGS = sys.argv[2:]
DEFAULT = Path('/home/a-b-c-MySQL')
POINTER = SELF.with_name(SELF.name + '.install-path')

def fail(message):
    raise SystemExit('错误：' + message)

def protected(path, directory=False):
    st = path.lstat()
    if stat.S_ISLNK(st.st_mode) or st.st_uid != os.geteuid() or st.st_mode & 0o022:
        fail('路径所有者、权限或符号链接不安全：' + str(path))
    if directory and not stat.S_ISDIR(st.st_mode):
        fail('不是目录：' + str(path))
    if not directory and (not stat.S_ISREG(st.st_mode) or st.st_nlink != 1):
        fail('不是独立普通文件：' + str(path))

def safe_parents(path):
    for part in reversed((path, *path.parents)):
        if part.exists() or part.is_symlink():
            protected(part, True)

def atomic(path, content, mode):
    if path.exists() or path.is_symlink():
        protected(path)
        if path.read_bytes() == content and stat.S_IMODE(path.stat().st_mode) == mode:
            return
    fd, name = tempfile.mkstemp(prefix='.abc-publish-', dir=path.parent)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, 'wb') as stream:
            stream.write(content); stream.flush(); os.fsync(stream.fileno())
        os.replace(name, path)
        dfd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try: os.fsync(dfd)
        finally: os.close(dfd)
    finally:
        if os.path.exists(name): os.unlink(name)

raw = SELF.read_text()
payload = raw.split('\n# === ABC EMBEDDED FILES ===\n', 1)[1]
files = {}
for block in payload.split('\n@@ABC_FILE ')[1:]:
    header, body = block.split('\n', 1)
    name, mode, expected = header.split(' ')
    body = body.split('\n@@ABC_END\n', 1)[0]
    content = body.encode()
    if hashlib.sha256(content).hexdigest() != expected:
        fail('内嵌文件损坏：' + name)
    if name.startswith('/') or '..' in Path(name).parts or name in files:
        fail('内嵌路径不合法')
    files[name] = (content, int(mode, 8))
if not files: fail('没有内嵌程序')

root = None
mode = 'run'
forward = []
no_menu = False
dry = False
while ARGS:
    arg = ARGS.pop(0)
    if arg == '--project-dir':
        if not ARGS: fail('--project-dir 缺少路径')
        root = Path(ARGS.pop(0))
        if not root.is_absolute(): fail('安装目录必须为绝对路径')
    elif arg in ('--repair', '--upgrade', '--verify', '--initialize'):
        if mode != 'run': fail('不能同时选择多个管理动作')
        mode = arg[2:]
    elif arg == '--no-menu': no_menu = True
    elif arg == '--dry-run': dry = True; forward.append(arg)
    elif arg == '--distribution-help':
        print('自包含入口：--project-dir /绝对目录 --initialize|--verify|--repair|--upgrade --no-menu --dry-run；其他参数传给已安装程序。')
        raise SystemExit(0)
    else: forward.append(arg)
if root is None:
    if (SELF.parent / 'config/config.env').is_file(): root = SELF.parent
    elif POINTER.exists() or POINTER.is_symlink():
        protected(POINTER)
        root = Path(POINTER.read_text().strip())
        if not root.is_absolute(): fail('安装位置记录不合法')
    elif (DEFAULT / 'config/config.env').is_file(): root = DEFAULT
if root is None:
    if mode == 'verify': fail('尚未安装；请指定 --project-dir')
    print('========================================\n       A-B-C 系统初始化\n========================================')
    print('仅部署离线程序框架；不部署业务服务。')
    try: choice = input('项目安装目录 [默认 /home/a-b-c-MySQL]：').strip()
    except EOFError: fail('初始化已取消')
    root = Path(choice or str(DEFAULT))
if not root.is_absolute() or root == Path('/') or any(c in str(root) for c in '\n\r"'):
    fail('项目安装路径不安全')
safe_parents(root)
root = root.resolve()
if not (root / 'config/config.env').is_file() and mode == 'run': mode = 'initialize'
if mode in ('initialize', 'repair', 'upgrade'):
    print('计划：' + mode + ' → ' + str(root) + '；保留已有 config.env、状态及日志。')
    if dry:
        print('[Dry-run] 未创建目录、锁、配置、位置记录或安装文件。')
        raise SystemExit(0)
    try: answer = input('请输入小写 yes 确认：')
    except EOFError: fail('操作已取消')
    if answer != 'yes': fail('操作已取消')
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    protected(root, True)
    lock = root / '.distribution.lock'
    if lock.exists() or lock.is_symlink(): protected(lock)
    fd = os.open(lock, os.O_CREAT | os.O_APPEND | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
    fcntl.flock(fd, fcntl.LOCK_EX)
    try:
        for folder in ('config', 'scripts', 'modules', 'logs', 'data', 'tmp', 'systemd', 'tests', 'docs'):
            (root / folder).mkdir(mode=0o700, exist_ok=True)
            protected(root / folder, True)
        # 完整预检后再发布；现有配置只校验，不覆盖。
        for name in files:
            target = root / name
            safe_parents(target.parent)
            if target.exists() or target.is_symlink(): protected(target)
        config = root / 'config/config.env'
        if config.exists() or config.is_symlink(): protected(config)
        with tempfile.TemporaryDirectory(prefix='.abc-validate-', dir=root) as temp:
            for name, (content, permissions) in files.items():
                candidate = Path(temp) / name
                candidate.parent.mkdir(parents=True, exist_ok=True)
                candidate.write_bytes(content)
                if name.endswith('.sh'):
                    subprocess.run(['bash', '-n', str(candidate)], check=True)
                if name.endswith('.py'):
                    compile(content, name, 'exec')
        for name, (content, permissions) in files.items():
            atomic(root / name, content, permissions)
        if not config.exists():
            template = files['config/config.env.example'][0].decode().split('# 恢复/切回扩展', 1)[0]
            # 可选扩展由统一解析器提供安全默认，避免与旧版配置编辑/测试重复字段。
            template = template.replace('PROJECT_DIR="/home/a-b-c-MySQL"', 'PROJECT_DIR="' + str(root) + '"')
            atomic(config, template.encode(), 0o600)
        manifest = {name: hashlib.sha256(value[0]).hexdigest() for name, value in files.items()}
        atomic(root / 'data/distribution-manifest.json', json.dumps(manifest, sort_keys=True).encode(), 0o600)
        if SELF.parent != root:
            safe_parents(POINTER.parent)
            atomic(POINTER, str(root).encode(), 0o600)
    finally:
        os.close(fd)
    print('程序文件部署完成；配置未覆盖，业务操作未启用。')

# 每次运行与 --verify 均对照此分发文件内的真实校验值，不信任可编辑 manifest。
errors = []
for name, (content, permissions) in files.items():
    path = root / name
    try:
        protected(path)
        if path.read_bytes() != content or stat.S_IMODE(path.stat().st_mode) != permissions:
            errors.append(name)
    except (OSError, SystemExit): errors.append(name)
if errors:
    fail('项目文件缺失或与此分发版本不符：' + ', '.join(errors) + '；使用 --repair/--upgrade 修复（保留配置）')
if not (root / 'config/config.env').is_file(): fail('配置缺失，需 --initialize')
if mode == 'verify':
    print('完整性检查通过：' + str(root)); raise SystemExit(0)
if no_menu: raise SystemExit(0)
os.chdir(root)
# Python 源码经 heredoc 占用 fd0；恢复保留的用户终端输入再启动菜单。
os.dup2(3, 0)
os.execvp('bash', ['bash', str(root / 'a-b-c-MySQL.sh'), *forward])

ABC_BOOTSTRAP_PY
result=$?
: <<'ABC_ALL_PAYLOAD'
# === ABC EMBEDDED FILES ===

@@ABC_FILE README.md 600 8838ed63dde32f9066a07d96177a33c57f7914347e9fb9d9021cf7aa5e6038c1
# A-B-C MySQL 主备容灾管理系统 — 基础框架与第二阶段离线设计

## C 节点监控（第四阶段）

现有第 7 项已实现只读采集菜单，详见 [docs/MONITORING.md](docs/MONITORING.md)。必须配置 C 角色及已核验的 SSH/节点身份后才能远程采集。后台服务通过 `bash scripts/monitor.sh --enable` 明确确认启用；当前项目未配置 C，不自动启用。其他编号与状态机不变。数据库/复制/同步未配置时显示未配置，监控正常不是一致性或切换许可。

## 手动切换与计划维护扩展

新增主菜单 9，详见 [docs/MANUAL-MAINTENANCE.md](docs/MANUAL-MAINTENANCE.md)。主菜单和维护菜单每次显示时只读 C 状态快照；当前未部署采集器，真实界面显示“暂无”，不静态假定 A 正常。所有手动选项仅预览，不提交、执行或取消真实任务。运行方式不变：`bash /root/yingyong/a-b-c-MySQL.sh`。

新增回归：`python3 /home/a-b-c-MySQL/tests/test_manual.py`。不使用真实项目状态文件放测试数据，真实 DB、Rsync、DNS 和 Fencing 仍未接入。

## 第二阶段架构优化

当前权威设计见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)：最终目标已更新为 B 接管、自动恢复 A、观察稳定后自动安全切回 A。没有生产执行器或活动协调状态。

现有 config/config.env 保持不变；新增可选配置使用安全默认值并记录于 config.env.example。自动接管/恢复/切回默认 false，当前即使改为 true 也会被拒绝，直到后续执行器和部署验收完成。原 20 项测试文件保留原文。

新增只读入口（不调用远程工具，不持久化活动状态）：

```bash
bash /home/a-b-c-MySQL/scripts/coordinator_plan.sh --policy
bash /home/a-b-c-MySQL/scripts/coordinator_plan.sh --edge A_STABLE
bash /home/a-b-c-MySQL/scripts/coordinator_plan.sh --direction NORMAL_A
bash /home/a-b-c-MySQL/scripts/coordinator_plan.sh --simulate NORMAL_A
python3 /home/a-b-c-MySQL/tests/test_architecture.py
```

--simulate 缺条件返回 4 并输出 MANUAL_REQUIRED；事实只是离线模拟，不能用作生产隔离证据。恢复配置 POLICY_DRY_RUN 与 CLI --dry-run 分开，前者是未来策略闸门，后者保留原框架行为。第二阶段证据见 data/STAGE2-REPORT.md、data/stage2-verification.txt。


## 当前交付范围

基础框架已实现；不是可用于接管生产网站的完整容灾系统。模块框架在普通调用时返回 3（未实现），Dry-run 返回 0 仅代表计划展示成功，不代表业务通过验收。

没有修改 MySQL、Cloudflare、S3；没有启动同步、初始化数据库、重启服务、注册定时任务或执行故障切换。systemd/ 目前为空，后续才提供和安装业务单元。卸载也是受阻框架，不会删除项目或业务数据。

## 本机使用

```bash
bash /home/a-b-c-MySQL/a-b-c-MySQL.sh
bash /home/a-b-c-MySQL/a-b-c-MySQL.sh --help
bash /home/a-b-c-MySQL/a-b-c-MySQL.sh --install
bash /home/a-b-c-MySQL/a-b-c-MySQL.sh --status
bash /home/a-b-c-MySQL/a-b-c-MySQL.sh --check
bash /home/a-b-c-MySQL/a-b-c-MySQL.sh --diagnose
bash /home/a-b-c-MySQL/a-b-c-MySQL.sh --logs
bash /home/a-b-c-MySQL/a-b-c-MySQL.sh --dry-run
bash /home/a-b-c-MySQL/scripts/sync_files.sh --dry-run
```

--install 仅登记第一阶段框架版本，不安装软件。重复调用保留配置与现有状态。主菜单 1—8 对应模块框架，第 4 项提供 SSH/WireGuard 二级菜单。操作完成按回车返回；0 返回/退出；EOF 安全退出。未知参数返回 2，配置/存储错误返回 1。环境缺失与业务未配置以明确提示报告，--check 成功仅意味着本地检测完成。

Dry-run 不写日志、锁、状态或配置，不创建目录，不调用任何业务动作；缺少运行目录时会报告而不是创建。普通运行可自动重建缺少的 logs/data/tmp，模式 700。根目录或配置缺失则停止，避免用默认配置代替丢失的生产配置。

## 目录与配置

主配置：config/config.env，权限 600；模板 config/config.env.example。项目和私有运行目录权限 700，脚本由项目所有者执行。建议以 root 管理；不会自动调整业务目录权限。

所有入口实际读取同一配置。配置不是可执行 Shell 文件，只支持 KEY="字面值"、空行和整行注释；不做变量替换、命令替换、转义解码，不允许双引号嵌入值、重复键、未知键或内联注释。不要 source 配置，不把该解析器用于其他格式的 dotenv。

目前没有交互配置编辑器；可用受信任编辑器修改 config.env，保持 600 并运行 --status/--check。配置值、密码与 Token 不打印；错误也不显示原始配置行。PROJECT_DIR 必须匹配入口所在真实目录，搬迁时需一并修改；不能用环境变量指向未经验证的目录。

检查包括必需字段存在、数值范围、角色、权限、固定同步规则与第一阶段安全开关。A/B/C 地址、数据库兼容性、凭据有效性和供应商 API 等语义检查留待对应阶段。本阶段故意允许业务字段为空，但逐项报告不完整，业务模块不可执行。

## 文件同步规则（已保存；尚未启用实际同步）

递归监控并同步 /home/web/ 的全部现有及未来新增普通文件和文件夹，包括 /home/web/beifen/。指定排除仅为以下三棵目录树：

- /home/web/log/
- /home/web/mysql/
- /home/web/redis/

不按 beifen/backup 名字推断排除。Redis 假设为可重建缓存，部署时必须核实；如承载 Session、队列或持久业务则告警并制定独立方案。未来真实挂载检查若发现其他活跃数据库目录或节点配置冲突，必须阻止不安全同步并向管理员说明，不静默扩大普通目录排除列表。默认不传播删除，约 5 秒防抖、递归监听、事件溢出补偿与周期扫描均为后续阶段功能。

## 日志与轮转

logs/framework.log 使用固定事件代码，拒绝记录任意输入、凭据和外部命令原文。每次写日志前使用 data/log.lock 的 flock 串行化写入/轮转。

默认 LOG_MAX_BYTES=1048576、LOG_KEEP=5：超过预留记录空间时将当前日志轮转为 .1，旧日志向后移动，最多保留 .1—.5。新文件权限 600。按写入触发，无 systemd/cron/logrotate 安装，不改 /etc/logrotate.d。日志只含事件代码，不适用于后续业务审计的全部要求；后续会增加经过脱敏的结构化上下文。

轮转在隔离测试中验证，未为了测试而填满实际生产目录。框架初始化锁与日志锁独立；不对整个菜单加独占锁。锁文件不得靠删除方式解锁。

## 检测与测试

运行依赖 Bash、GNU coreutils、util-linux flock。--check 只读取本机发行版、内核、CPU、内存、磁盘，检查工具存在性和有界的 Docker Compose 版本查询；不会查看容器环境变量、读取站点配置或连接业务数据库。

测试依赖 Python 3 标准库，无需 pip。测试复制项目到 TMPDIR（建议 /root/.hermes/cache/scratch），禁止工具用桩拦截，清理仅限本次临时测试目录：

```bash
python3 /home/a-b-c-MySQL/tests/test_framework.py
```

静态检查（在项目目录运行；ShellCheck 需另行提供，本项目不会自动安装）：

```bash
for f in a-b-c-MySQL.sh modules/*.sh scripts/*.sh; do bash -n "$f" || exit; done
shellcheck -x -P SCRIPTDIR a-b-c-MySQL.sh modules/*.sh scripts/*.sh
```

交付实测使用临时下载的 ShellCheck 0.10.0，未安装系统软件。查看 data/TEST-REPORT.md、data/verification.txt、data/menu-output.txt 与 data/FILES.txt。当前只验证本机 Debian 13；不宣称已实测 Debian 12 或真实三节点容灾。

## 第二阶段前需要提供

- A/B/C 的系统版本、地址、SSH 端口/用户名、访问方式，是否有独立私网。
- MySQL 或 MariaDB 的准确版本、Docker/原生部署、Compose 文件位置、服务名与真实挂载。
- B 是否已有业务和数据库、可用磁盘，允许的维护窗口。
- WordPress 域名、路径、数据库位置、后台写入任务、Redis 实际用途。
- 计划采用 WireGuard、现有私网还是 SSH 隧道。
- Cloudflare 管理域名、A/AAAA/代理状态；Token 不要发到普通聊天中。
- 云厂商隔离能力、防自动重启策略、可接受 RPO/RTO 与告警方式。

下一阶段只在用户确认后进行。数据库复制、Rsync/inotify、C 后台监控、Fencing、Cloudflare API、自动接管、恢复切回及真正卸载尚未实现，不能投入生产容灾。

@@ABC_END

@@ABC_FILE a-b-c-MySQL.sh 700 9299e8f12a51ce6d2b6713c7a343d15ede1fa881f9fdead0af7a06e08d06ea74
#!/usr/bin/env bash
# shellcheck source=modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/modules/common.sh"
action=--menu
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --menu|--help|--install|--check|--status|--diagnose|--logs|--uninstall) action=$arg ;;
        *) die '未知参数；使用 --help'; exit 2 ;;
    esac
done
bootstrap || exit 1
args=()
$DRY_RUN && args+=(--dry-run)
case "$action" in
    --help)
        echo '用法：bash a-b-c-MySQL.sh [--menu|--install|--check|--status|--diagnose|--logs|--uninstall] [--dry-run]'
        echo '第一阶段仅支持本地框架；不会部署业务或安装依赖。'
        ;;
    --menu) exec bash "$PROJECT_DIR/scripts/main.sh" "${args[@]}" ;;
    --install) exec bash "$PROJECT_DIR/scripts/install.sh" "${args[@]}" ;;
    --check|--diagnose)
        if $DRY_RUN; then exec bash "$PROJECT_DIR/scripts/check.sh" --dry-run
        else exec bash "$PROJECT_DIR/scripts/check.sh" "$action"; fi ;;
    --status) config_status; log_event STATUS ;;
    --logs)
        validate_private_file "$PROJECT_DIR/logs/framework.log" || { die '日志文件不安全'; exit 1; }
        if [[ -f $PROJECT_DIR/logs/framework.log ]]; then
            while IFS= read -r line; do printf '%s\n' "$line"; done < "$PROJECT_DIR/logs/framework.log"
        else echo '暂无框架日志'; fi ;;
    --uninstall) exec bash "$PROJECT_DIR/scripts/uninstall.sh" "${args[@]}" ;;
esac

@@ABC_END

@@ABC_FILE config/config.env.example 600 b4eb6a561d398a306cb5e772584ccae540fde2236ce308e52f09bf075d6ba0ec
# 第一阶段配置：仅支持 KEY="字面值"；不执行 Shell 展开，不支持内联注释。
PROJECT_DIR="/home/a-b-c-MySQL"
CONFIG_VERSION="1"
NODE_ROLE="UNASSIGNED"
A_PUBLIC_IP=""
B_PUBLIC_IP=""
C_PUBLIC_IP=""
A_PRIVATE_IP=""
B_PRIVATE_IP=""
C_PRIVATE_IP=""
SSH_USER="root"
SSH_PORT="22"
SSH_TIMEOUT="10"
MYSQL_PORT="3306"
MYSQL_USER=""
MYSQL_PASSWORD=""
MYSQL_REPLICATION_MODE=""
COMMUNICATION_MODE=""
CF_API_TOKEN=""
CF_ZONE_ID=""
CF_DOMAIN=""
WEB_ROOT="/home/web/"
RSYNC_SOURCE="/home/web/"
RSYNC_DEST="/home/web/"
SYNC_EXCLUDES="log,mysql,redis"
REDIS_USAGE="UNCONFIRMED"
RSYNC_DELETE="false"
SYNC_DEBOUNCE_SECONDS="5"
MONITOR_INTERVAL="30"
FAILURE_THRESHOLD="3"
AUTO_FAILOVER="false"
AUTO_FAILBACK="false"
LOG_MAX_BYTES="1048576"
LOG_KEEP="5"

# 恢复/切回扩展；旧 config.env 缺失这些项时读取下列默认值，不自动迁移。
AUTO_FAILOVER_ENABLED="false"
AUTO_RECOVERY_ENABLED="false"
AUTO_FAILBACK_ENABLED="false"
RECOVERY_STABLE_MINUTES="20"
RECOVERY_SYNC_RETRY="3"
RECOVERY_SYNC_INTERVAL="30"
SYNC_DIRECTION_LOCK="true"
SINGLE_PRIMARY_ENFORCED="true"
POLICY_DRY_RUN="true"

# C 监控扩展（缺失时采用安全默认，不改已有配置）
STATUS_EXPIRE_SECONDS="30"
MONITOR_TIMEOUT="8"
MONITOR_SSH_KEY=""
MONITOR_KNOWN_HOSTS=""
A_SSH_USER=""
B_SSH_USER=""
A_SSH_PORT=""
B_SSH_PORT=""
A_EXPECTED_MACHINE_ID=""
B_EXPECTED_MACHINE_ID=""
A_MYSQL_MONITOR_CNF=""
B_MYSQL_MONITOR_CNF=""
A_MYSQL_CONTAINER=""
B_MYSQL_CONTAINER=""
# 第五阶段：支持每节点独立 SSH 信任；为空时兼容原公共字段。
A_MONITOR_SSH_KEY=""
B_MONITOR_SSH_KEY=""
A_MONITOR_KNOWN_HOSTS=""
B_MONITOR_KNOWN_HOSTS=""
REPLICATION_WARN_SECONDS="30"

@@ABC_END

@@ABC_FILE docs/ARCHITECTURE.md 600 332efdb72722ec64b1844e2b5a06a6d174428c946fa94a806c421fb0b51a1cf7
# A/B/C 自动恢复与自动切回：当前权威设计（第二阶段离线架构）

手动计划切换、维护锁定、显式恢复请求和状态展示扩展见 [MANUAL-MAINTENANCE.md](MANUAL-MAINTENANCE.md)，与本文共享同一协调状态机和安全不变量。

本文件覆盖早期设计中“只能人工切回”的最终目标；自动切回仍默认关闭。用户最终目标是 NORMAL_A → 自动接管 B → B 服务期间恢复 A → 观察 → 自动安全切回 A → NORMAL_A。本次不含生产执行器、远程部署或后台任务。状态机脚本只是纯离线规则演算，不是已实现的容灾协调器。

## 1. 不变量与边界

- A 正常生产时，文件同步仅 A→B。A 是只读文件源；不能让源端工具 chmod/chown、移动、删除或覆盖 /home/web/，不能初始化 A 数据库，不能擅改生产配置。源读取可能改变文件系统 atime；“只读源”指项目不执行业务数据写入，不承诺文件系统自动元数据完全不变。
- B 为唯一生产主且 A 已恢复并保持业务隔离，C 才能授权 B→A 恢复。绝不把旧 A 数据反推 B。
- 单主是执行授权与可信隔离共同实现的安全条件，不由布尔配置、flock 或 DNS 提供。C 持锁不意味着 A 已不能写入。
- 无法证明旧主持久隔离、最终事务完整、所有写入者停用或真实数据一致时，停在当前安全阶段，告警。安全目标是最多一主，失败时可零主，不为可用性冒险开放两主。
- 本次仅更新模板和代码默认结构，现有 config/config.env 不写入、不替换；原 20 项测试保留原文。

## 2. 架构与执行信任边界

```text
访客 → Cloudflare A/AAAA → A（正常） / B（接管期间）
                               ↑          ↑
                       HTTP(S)/DB/文件/资源探针
                               └────C─────┘
                              唯一控制平面
                         角色 + 事务 + 策略引擎
                          /        |         \
                  Fencing适配   节点代理   DNS适配
                                  |
                      DB复制与文件同步独立验证
```

当前文件：modules/state_machine.sh 为纯函数，scripts/coordinator_plan.sh 为只读演算入口，使用统一配置，但不写活动状态、不调用 SSH/DB/Rsync/API。命令行 FACT 只是模拟输入，不能成为生产证据。

后续执行器必须独立分层：
- observation：采集签名身份、采样时间、实际节点实例 ID、启动 ID、配置摘要。
- fencing：fence/verify/hold/release，独立通道、持久防重启和业务隔离。
- role/direction：C 的 epoch、operation_id、期望主、允许方向、目标身份；节点代理校验并拒绝旧代次。
- recovery：lineage、attach/reseed、B→A 复制与文件通道。
- failback：维护写屏障、最终边界、提升与健康。
- journal：写前意图、后验结果、逐条 DNS 状态、崩溃对账。
- executor：只运行明确动作白名单，不接收任意 Shell。

flock 只在唯一 C 的本地进程间互斥，不是分布式租约。节点 epoch 也不能阻止被复制的第二套 C 同时下令；禁止双活 C，C 恢复/迁移需独立控制权隔离。失联任务必须由节点侧有效授权、服务门禁和可信隔离共同处理。

## 3. 状态机与同步方向

```text
NORMAL_A → SUSPECT_A → A_FENCED → B_DRAINED → B_PRIMARY
 → B_HEALTHY → ACTIVE_B
 → RECOVERY_PREFLIGHT → A_REPLICA → A_CATCHING_UP → A_STABLE
 → B_QUIESCED → FINAL_VERIFIED → B_FENCED
 → A_PRIMARY → A_HEALTHY → DNS_A_VERIFIED → B_REPLICA → NORMAL_A
```

任一证明缺失、过期、重启后不一致 → MANUAL_REQUIRED，保留原写入权限/隔离，不能从暂停状态自动释放双主保护。阶段未知时先冻结常规同步，再只读对账。

- NORMAL_A / SUSPECT_A：只允许 A→B；A 数据和配置不可作为目标。
- A_FENCED 到 ACTIVE_B：常规同步关闭，等待恢复授权。
- RECOVERY_PREFLIGHT：尚不能写 A。
- A_REPLICA / A_CATCHING_UP / A_STABLE：可授权 B→A，仅限业务隔离目标 A。
- B_QUIESCED / FINAL_VERIFIED：常规任务关闭，仅操作事务可执行一次最终 B→A 同步。
- B_FENCED 至 B_REPLICA：常规同步关闭。
- B_REPLICA 完成 B 只读、A→B 复制、旧 B→A 任务已停止后转 NORMAL_A，才重新授权 A→B。

模块中每条边列出必需模拟条件；实际执行时提升的写前预检与提升后的验证必须拆成日志子阶段，不能把 a_promote_verified 当成提前允许提升的凭据。

## 4. 文件范围及稳定性协议

递归覆盖 /home/web/ 的全部现有及未来普通文件/目录，包含 beifen/；排除仅根相对路径 /log/**、/mysql/**、/redis/**，不能误排除 html/log/ 等普通同名子目录，不按 backup/beifen 名称判断。

不跟随外链；默认 -a 保留符号链接本身，不使用 -L。部署时检查目标祖先路径、目标端 symlink、嵌套挂载和真实 DB 数据。若发现其他活跃数据库目录，阻断同步并说明冲突，不静默新增排除以违背范围。节点专用配置先制定兼容策略，不能静默排除整个普通目录。

首次基线 + inotify 新建/修改/重命名 + 周期扫描。约 5 秒防抖且设最大等待，watch 溢出后补扫；新增目录立即纳入监听。默认不传递删除；重命名后新名同步、旧名保留并告警，最终一致性检查需明确处理多余文件，不能宣称两个目录完全相同。

大文件：CLOSE_WRITE 或生产者原子 rename 为优选完成信号，辅以多次 size/mtime 稳定观察；仅静默 5 秒无法证明写入结束。目标临时文件后原子替换，不用 --inplace、--append 或 --remove-source-files；传输后复核源标识/大小/mtime/摘要，变化则重试。无法证明稳定的持续写文件需应用协作或维护窗口，不无限阻塞全部小文件；单文件超时告警。

失败按 RECOVERY_SYNC_RETRY 次总尝试（包含首次）、RECOVERY_SYNC_INTERVAL 秒间隔，有界重试和单方向锁。每次执行前/完成前检查角色与授权代次。断联旧进程和在途同步必须停止并核验，不能只删除锁或修改状态变量。目录权限/时间属性同步仅作用目标，不修正源。

Redis 树既不监听也不传输。部署先核实缓存、Session、队列、持久写用途；CACHE 才允许目标重建目录和缓存，非缓存必须独立方案。当前没有任何 mkdir Redis 或清缓存动作。

## 5. 故障接管 B

连续故障 + C 自身网络与 B 可达性 → 唯一事务锁 → A 可信持久 Fencing → 停止并核验 A→B 任务 → 固定 B 已接收边界、排空 Relay Log → 风险策略判断 → 提升 B → 启动业务和写入者 → DB、HTTP、HTTPS 与业务健康 → 更新全部受管 A/AAAA 并 GET 精确读回。

A 的 Ping/SSH/HTTP 失败均非隔离证明。半同步或收到日志全部执行也不自动提供零丢失保证。需要配置已授权 RPO、样本最大年龄、复制/文件新鲜度和实际丢失风险；没有策略时拒绝自动提升。风险策略、隔离实例身份和时间证据绑定本事务。

## 6. B 在线生产期间恢复 A

1. B 始终唯一主，A Web/PHP/cron/队列/事件等业务写入禁止。
2. 如果最初 A 为断电 Fencing，不能保持断电又通过 SSH 恢复：先取得可信网络/启动维护隔离，屏蔽业务流量和写入启动，再受控上电；无安全隔离转换能力则自动恢复阻断。
3. 只读检查 A 系统、磁盘、MySQL 产品版本、状态、数据容量、权限和实例身份。
4. 产品专用方式比较 GTID lineage、缺失日志与 errant transactions；MySQL GTID 与 MariaDB 域语义分开。无法证明可接续，走一致性重新初始化，不合并数据分叉。
5. 自动 reseed 必须预先批准目标 A、确切站点数据库清单、覆盖预算、保全方式、工具、磁盘上限与快照来源。不具备部署级预授权时停下请求一次策略授权，而不是每步人工确认。
6. 保全 A 原始数据于独立受限暂存、不可由 Web 访问；不清空数据目录、不动 B 数据。使用独立导出/受支持物理工具，业务持续写入期间取得可靠快照边界。非事务表或无在线安全工具则阻断，不暗中停 B。
7. 配置 A 从 B 复制，A 仅允许恢复管理员/复制线程，业务账号持续只读且无绕过权限；恢复导入暂时放开管理写入不等于开放业务写入。
8. 独立 B→A 文件基线/增量同步，另行确认节点配置和缓存策略。B 的源端禁止变更。
9. 分别检查 I/O、SQL、错误、GTID、Relay Log、延迟、文件新鲜度/清单。Seconds_Behind 为 0 不等于严格追平；NULL 不算 0。
10. 连续 20 分钟健康观察，间断失败归零；观察期只是可配置门槛，不代替最终一致性边界。只读探针验证 A，不提前开放 A 业务写入。

## 7. 自动切回事务

只有 AUTO_RECOVERY_ENABLED、AUTO_FAILBACK_ENABLED 显式启用且经过测试/部署策略授权后自动运行。本次代码仍强制关闭。正常自动运行不逐步询问用户；缺证据直接安全暂停。

- 锁与写前日志：确认 C 唯一控制权，冻结普通同步，记录事务 epoch。
- 维护窗：B 网站进入维护，停 PHP/应用写入、WP-Cron、系统 cron、队列消费者、第三方/API 写入、DB event_scheduler、DDL/管理任务；只停止预先确认的业务清单，不停止 S3 任务。若外部任务也会写数据库却不允许控制，则阻断自动切回。
- 写屏障：数据库只读/权限隔离和流量隔离结合，检查活跃事务、预备事务、会话和所有已登记写入者。Redis/文件生产者也需停止；不能仅停 Nginx。
- 固定最终 GTID/位置：在无业务写入条件取得 B 最终边界；等待 A 执行覆盖该边界、无 SQL 错误。保持 B 数据库可用于读取复制。
- 最终文件同步：B→A 最后一轮，源保持稳定，校验全部范围、权限、清单和必要摘要；默认无删除，多余文件必须判断其是否影响业务，未解决则拒绝通过。
- 数据一致性：同一静止边界下校验预先定义的全部业务数据库、表、关键对象/数据；抽样只能标记抽样，不可当成严格全量一致。校验规模决定维护时长，提前压测预算。
- 持久封闭 B 写入，重新核验 A/B 与证据新鲜度，再提升 A；所有提升须写前记录 intent、动作后读回，不先 RESET 复制或 GTID 信息。
- 启动 A 业务，检查本地 DB 写能力（经授权测试数据及清理策略）、HTTP/HTTPS Host/SNI、WordPress 实际业务；B 继续封闭。
- 逐条更新 Cloudflare A/AAAA，保留期望代理/TTL 属性，检查外部漂移；读回精确记录。API 成功不代表全网生效。
- A 保持唯一主，B 按产品安全流程成为 A Replica、只读且全部业务写入者关闭，再恢复 A→B 文件同步，停止 B→A。

旧 DNS 缓存仍指 B 时可暂时维护/拒绝请求；如要无中断代理到 A，须另行批准并验证防回环、TLS、Host 及只转发不本地写入方案，默认不实现。

## 8. 崩溃安全事务和失败矩阵

未来 data/transactions/<operation_id>.json 的单一权威记录包含 schema、epoch、配置摘要、旧/新主实例与 boot_id、每动作 intent/result、隔离证据引用和期限、接收/最终边界、同步清单摘要、写入者清单、维护状态、DNS 各记录进度、retry_count、最后可信观测时间。

持久性要求：同目录安全临时文件 600 → 完整序列化 → fsync 文件 → atomic rename → fsync 父目录；journal 失败必须阻断后续副作用。仅 mv 的原子性不等于断电持久性；后续可用最小 Python 标准库持久化助手，核心调度保持 Bash。本次没有创建活动事务。

命令发出但结果未记录属于 outcome_unknown，不代表失败未执行。C 重启先读记录、重新获取控制权，核验各端实际可写性/Fencing/复制/DNS；不能直接从本地阶段重播提升。操作幂等绑定 operation_id+epoch+目标实例，第三方超时必须读回。

- 追平/最终文件/一致性失败且尚未提升 A：A 保持业务隔离；只有验证 A 从未开放写入、B lineage 未变且解除写屏障安全时，才允许另一个授权恢复服务动作。不能无条件自动回滚。
- 已发出提升 A 但结果未知：A/B 均保持写门禁，先对账；禁止恢复 B 写入。
- A 已成为主后站点失败：B 保持封闭，修复 A 或走新受控切换事务，不直接恢复 B 写入。
- DNS 失败/部分失败：A 保持唯一主，逐记录有界重试、检测外部改动、告警。
- 网络中断、证据过期、C 重启：停止新副作用，保持现有隔离；稳定观察期保守归零，重新采集证明。

允许安全重试：只读采集、同事务校验后的健康检查、源/角色/目标未变的增量同步、读回确认未生效的单条 DNS 幂等更新。禁止盲重试：reseed 导入、提升、解除 Fencing、逆转复制、开启写入者。

## 9. 配置兼容

现有 config.env 保持逐字节不变，CONFIG_VERSION=1。新增可选项由 common.sh 内安全默认补齐、模板展示；旧 AUTO_FAILOVER/AUTO_FAILBACK 保留 false 并拒绝开启，未来迁移显式说明避免两个开关优先级歧义。

AUTO_FAILOVER_ENABLED=false / AUTO_RECOVERY_ENABLED=false / AUTO_FAILBACK_ENABLED=false；RECOVERY_STABLE_MINUTES=20；RECOVERY_SYNC_RETRY=3（总次数）/ RECOVERY_SYNC_INTERVAL=30；SYNC_DIRECTION_LOCK=true / SINGLE_PRIMARY_ENFORCED=true；POLICY_DRY_RUN=true。

POLICY_DRY_RUN 是恢复策略部署闸门，区别于 CLI --dry-run；后者控制现有框架日志/初始化只读行为。当前新开关 true 或 POLICY_DRY_RUN=false 一律拒绝，防止误以为配置就启用自动化。方向/单主保护不可关闭。实际自动化启用还必须验证完整写入者清单、隔离能力、版本兼容、重建预算、一致性策略与故障演练通过。

## 10. 代码审查与安全修复

已审查统一配置/存储/日志/安装入口和原测试：
- 配置未执行 Shell，白名单键、重复拒绝、防敏感原文输出设计保留。
- 旧锁文件用 > 打开会在持锁前截断，且仅拒绝 symlink，无法防硬链接/特殊文件。改为追加打开，验证普通文件、当前所有者、600、link count=1；配置、日志轮转文件和状态同样校验。
- --logs 原先没有私有普通文件校验，现补齐。
- 原子前检查不能抗拥有同 UID/root 的恶意并发篡改；私有目录是信任边界，不宣称具备对抗 root 的安全性。未来开放远程代理前需无跟链打开和 FD 校验。
- 现有初始化状态仅用于框架登记，非容灾事务；现有日志没有崩溃耐久 journal，不得用于恢复决策。
- 现有配置地址/路径字段语义检查有限，但所有远程业务执行器缺席，当前不执行不可信远端命令。

## 11. 实验环境与故障模拟

当前：原 20 项测试不改，新增离线状态边测试；逐边删去任一条件必须拒绝，未知事实/重复事实拒绝，方向约束和暂停状态不能越权恢复。哈希检查现有 config.env 与原测试文件保持不变。原 18 个脚本与新增脚本一起 bash -n、ShellCheck。

后续：独立 Debian 12/13 A/B/C 测试 VM（不能用生产 /home/web）；同产品同大版本 MySQL/MariaDB 分别矩阵；虚拟电源/网络隔离+防重启模拟；Cloudflare 仅专用测试 Zone/记录；WordPress 多站点测试数据与明确写入者清单。

故障注入覆盖：仅 C 网络故障、A 失联仍写入、Fencing 超时/失效、A 自动重启、C 每个 intent/result 间崩溃、双 C、GTID 分叉/日志过期/SQL 错误、长事务/未知写入者、磁盘满/journal fsync 失败、大文件持续写入/rename/inotify 溢出/同步失败、B→A 时旧 A 推回 B、最终校验不一致、A 提升成功但 SSH 超时、站点启动失败、DNS 429/部分 A/AAAA 更新/外部漂移。

验收必须真实查询两端可写性、插入带序列业务数据核验单写者与丢失、比较数据库最终边界与文件摘要、记录维护窗口和 DNS 传播时间。纯规则模拟不能证明真实数据库、Fencing、RPO/RTO 或断电恢复达标。

@@ABC_END

@@ABC_FILE docs/DISTRIBUTION.md 600 4f1ab04e314cd910a2a74d9a4ee224086b6906fcdb1cf5d5fc852e7ef3eda779
# 自包含分发入口

/root/yingyong/a-b-c-MySQL.sh 是完整单文件分发物，内嵌模块、文档、配置模板和测试的可读源码，不下载业务源码，不包含现有 config.env、密码、日志或运行状态。可复制并改名至其他 Debian 12/13 主机，以 bash 文件名运行。

首次运行检测 root、Debian 和必要工具。缺 Python 等工具时明确询问 yes 后仅安装运行依赖（需要 Debian 软件源网络）；拒绝时停止，--dry-run 不安装依赖。首次提示安装目录，默认 /home/a-b-c-MySQL；确认 yes 后部署离线框架并进入菜单。

--project-dir /绝对路径 可显式选择安装；--initialize --no-menu 只初始化；--verify 检查与当前分发版本一致；--repair/--upgrade 经确认恢复内嵌程序文件，不覆盖已有 config.env、日志和状态。修复会覆盖已修改的受管源码，执行前应自行保留定制版本；没有版本联网检测，upgrade 表示发布本分发版本，不声称最新。

安装位置记录在分发入口旁的 <入口名>.install-path。查找优先级：--project-dir、入口同目录配置、位置记录、默认目录现有配置、首次交互。换名或迁移后可显式指定项目目录。位置记录不是项目凭据或主要配置，权限 600。不能从 CWD 猜项目。

每次启动校验内嵌文件 SHA256、文件内容和权限；缺失/损坏时拒绝启动并提示 repair。单文件内部 SHA256 用于损坏检测，不代替可信来源签名。项目 a-b-c-MySQL.sh 作为内部调度入口，分发文件独立包含它；不是旧式仅跳转启动器。

发布使用稳定锁和同目录临时文件+fsync+replace，不跟随不安全路径，源码预检后发布，配置不执行为 Shell。单文件逐项原子更新并非整个目录断电原子事务；中断后完整性检查阻止误启动，需重新 repair。安装目录路径不可包含双引号和换行；自定义目录应为新建或项目专用的 700 目录。已有配置与目录权限不符时保留并报错，不自动 chmod 业务目录。

本分发仅部署当前离线功能；不启动 MySQL、Rsync、监控后台、DNS、切换或恢复，不读写 S3。生产执行仍未实现。

@@ABC_END

@@ABC_FILE docs/MANUAL-MAINTENANCE.md 600 7e591684e187517bb85d3a0f229240efa1231d7ba662d6c91a7f014be2df619a
# 手动切换与计划维护扩展（离线设计）

本文件扩展 ARCHITECTURE.md，保留其全部单主、生产 A 保护、文件范围和失败安全约束。当前没有生产执行器，不提交任务、不取消任务、不修改 DNS/DB/同步/服务/S3。

## 触发原因与统一事务

trigger 取 AUTO_FAILURE、MANUAL_PLANNED、AUTO_RECOVERY、MANUAL_RECOVERY。所有触发共用 C 的独占切换锁、epoch、operation_id、节点身份、写入者清单、Fencing 和写前日志协议；手动不能跳过检查。新请求以期望拓扑版本进行 compare-and-set，已有非终态事务或同意图重复请求只返回已有 operation_id/冲突，不再开启任务。AUTO_FAILURE 遇到计划任务也不得并行提升：先进入同一事务重新观测、暂停，必要时通过明确可审计的 supersede 协议处理，禁止擅自抢锁改角色。

未来请求只可在 C NODE_ROLE 和真实控制权确认后提交；本地菜单不直接发提升命令。计划切换需一次目标、影响范围、维护窗、预计中断、重建策略的授权，后续后台安全步骤不逐项询问。--dry-run 只查询和预览，不创建 operation_id 活动记录。

## 新增分支

NORMAL_A 在无活动操作、明确授权和真实状态符合时创建 REQUEST_PENDING（请求生命周期，不是生产角色）。取消仅该请求尚无任何副作用 intent/result、worker 尚未开始，且同一锁下与 operation_id/epoch 对账时允许；取消不触碰生产拓扑。

计划执行：PLAN_REQUESTED → PLAN_PREFLIGHT → PLAN_A_QUIESCED → PLAN_FINAL_VERIFIED → A_FENCED，然后复用 B_DRAINED → B_PRIMARY → B_HEALTHY → ACTIVE_B。

计划分支先检查版本/磁盘/复制线程/GTID/文件/站点配置/只读探针、节点身份、DNS 基线；进入维护后停全部 A 写入者，等待事务和文件生产者停止，固定最终边界，B 精确执行、最终文件同步并校验全部业务数据，然后持久隔离 A 并停止旧方向任务。共用 A_FENCED 后的排空步骤是补充核验，不能以故障风险容忍替代计划切换的“最终边界完整”要求。trigger=MANUAL_PLANNED 的最终证明必须持续绑定事务，后续不得丢失。

ACTIVE_B 是拓扑角色；maintenance_hold=true 是独立的持久维护策略属性。显示/演算的 MAINTENANCE_B 对应 ACTIVE_B+maintenance_hold，不是第二套独立复制状态。计划成功保留 parent_operation_id 并进入维护，自动恢复检测可以提示 A 返回，但没有显式手动恢复请求时不得初始化 A 或自动切回。重装/迁移 A 后旧实例身份证据失效，必须安全登记新实例并重新授权隔离/恢复范围，不能仅凭同 IP 信任。

手动恢复：MAINTENANCE_B → RECOVERY_PREFLIGHT，需 no_active_operation（此前维护切换已完成）、身份验证、B 唯一主、A 业务隔离和恢复请求授权；后续复用 A_REPLICA → A_CATCHING_UP → A_STABLE → B_QUIESCED → FINAL_VERIFIED → B_FENCED → A_PRIMARY → A_HEALTHY → DNS_A_VERIFIED → B_REPLICA → NORMAL_A。稳定期默认 20 分钟、异常归零。数据库/文件两通道分别验证；分叉或重装按预授权受控初始化，不盲目合并。

手动恢复请求可单独授权后台追平和最终切回，不依赖“无人请求自动发现”的 AUTO_RECOVERY_ENABLED 开关。未来需独立 request_scope=recover_and_failback 和部署能力闸门；不允许借手动请求绕过默认关闭的部署执行能力。本阶段所有执行能力均不存在。

## 失败、取消与恢复

复制未追平、文件缺失、磁盘不足、SQL/IO 错误、写入者无法停、Fencing/身份/DNS 异常全部阻断。写屏障前可安全拒绝请求；已经登记副作用意图后不能普通取消。失败保留单主/隔离，查询 last_confirmed_stage、pending_action 和 outcome_unknown。提升命令结果未知先读回，不重发；新主已可能写入后禁止开放旧主。DNS 部分失败只对账逐条重试，不反转数据库。

C 重启按照原设计 journal 原子落盘/fsync、intent/result 和各节点真实状态重新对账；本次纯状态机与预览界面不具备真实持久化恢复能力。模拟缺条件返回 MANUAL_REQUIRED 不表示已经把集群置为安全状态。

## 状态展示契约

菜单每次重绘只读 data/c-status.json；不使用静态配置、历史测试数据或日志猜主节点。当前无采集器所以真实界面应为红色“暂无”。文件由未来 C 采集器经受认证通道发布，600、单硬链接、当前用户所有、普通文件、拒绝 symlink、限制 64 KiB、拒绝重复 JSON 键；源身份字段本身不是密码学认证。只有 root/C 受信发布链完成才可投入生产；手动编辑 JSON 不成为操作授权。

schema=1，source=C，identity_verified、collector_ok；checked_at 与各 nodes.A/B/C、database、files 的 checked_at 使用 Unix 秒。全局和分项超过 30 秒或来自未来则不显示绿色。全局不可用隐藏全部角色/进度；各节点单独区分 online/business，数据库与文件分开显示 health/integrity，lag_seconds 不能 NULL 当 0。primary 必须有 single_primary_verified；direction 与 primary 不匹配显示冲突；operation_id 仅允许有限安全字符以避免终端控制序列注入。last_success_at、同步时间可显示历史时间但不作为绿色依据。

绿色仅新鲜、明确 ok 的独立观测；维护/检查中黄色；缺失/错误/过期/无法确认安全红色。非 TTY 不输出 ANSI，真实 TTY 使用绿32、黄33、红31。Python 不存在/异常时 Bash 降级为“暂无”，绝不回退到配置中的 A 主角色。

示意 JSON 字段仅在文档与测试内，不创建实际快照。未来增加事务进度、已完成/总步骤、阶段、错误码、边界摘要和文件校验时间；采集器需将它们与活动事务关联，而不是菜单解析日志。当前 operation_id 仅显示任务标识，完整进度采集尚未实现。

## 实验方案

保留原 20+7 测试原文；新测计划每条边缺少任一条件、手动/自动冲突拒绝、取消边界、暂停不能越权恢复、缺失/错误/过期/未来/分项过期状态、DB与文件区分、非TTY及TTY颜色、子菜单所有分支、返回和 EOF、不创建任务和不调用禁止命令。模拟数据只在隔离测试中生成，绝不放真实 data/c-status.json。

后续 VM 实验验证 A/B 全部写入者、长事务、迁移后身份变化、最后一轮文件失败、提升超时但成功、DNS 部分成功、C 各阶段崩溃、并发手动/自动任务；实际查询双端写入权限、最终 GTID 和文件摘要，测试缓存仍到旧主。纯离线通过不等于这些生产条件通过。

@@ABC_END

@@ABC_FILE docs/MONITORING.md 600 07ac489cf31bc8583f244f58f6d387a429f2ab96223ac3289a1dea29231dc687
# C 节点只读监控

第 7 项为唯一菜单入口。监控脚本支持 --once、--show [A/B/mysql/replication/files/all]、--history [all/A/B/mysql/replication/files/worker]、--interval 秒、--enable、--disable、--service-status。--dry-run 不联网、不写状态、不启动任务。

NODE_ROLE 必须为 C 才能采集/启动服务；当前实际项目未设置 C 和 A/B 地址，不自动部署本机监控。首次部署先确认 C 身份，再由用户显式启用：bash scripts/monitor.sh --enable（精确 yes）。systemd 服务按项目根目录摘要唯一命名，Restart=on-failure，开机自启；锁避免重复 worker/采集。--disable 只停本项目监控。

config/config.env 是唯一配置。可选新增字段：STATUS_EXPIRE_SECONDS=30、MONITOR_TIMEOUT=8、MONITOR_SSH_KEY、MONITOR_KNOWN_HOSTS、A/B_SSH_USER、A/B_SSH_PORT、A/B_EXPECTED_MACHINE_ID、A/B_MYSQL_MONITOR_CNF、A/B_MYSQL_CONTAINER。主机地址优先 PRIVATE_IP，回退 PUBLIC_IP。每个主机 SSH 用户/端口可覆盖原 SSH_USER/PORT；必须有核验过的 machine-id、私有密钥和可信 known_hosts。不会自动 accept-new/跳过主机密钥，不修改 A/B authorized_keys 或部署探针文件；探针经 SSH stdin 执行只读 Python，目标需要 Python3/procps/iproute2。

默认新模板 MONITOR_INTERVAL=30。现有值（包括原 10 秒）保留。有效期实际取 max(配置有效期, interval+timeout+2)，避免正常周期加采集耗时使状态持续过期；30 秒周期通常为 40 秒有效期，不虚称默认 30/30 能覆盖完整周期。菜单 8 原子只修改 interval/expiry 两项并确认，后台每轮重读。前一轮睡眠按其原周期完成，新值最迟下一轮生效，不重建进程；修改后明确显示实际有效期。

远程采集不依赖 Ping：SSH成功及 machine-id 验证才标在线；读取 CPU短采样、内存、/home 文件系统容量/可用、负载和 ss 网络摘要。SSH不可达不能区分主机断电和网络/认证失败，统一明确异常，不能宣称物理离线。网站业务健康未部署 HTTP 探针，所以独立显示暂无，不由服务器在线推断。

MySQL/MariaDB 客户端凭据应由管理员提前放在目标机或目标容器的私有 defaults-extra-file。字段只保存其绝对路径，不读取/传输内容、不在进程参数传密码、不使用现有 MYSQL_PASSWORD。需现有只读监控账号（SELECT相关变量/状态、REPLICATION CLIENT权限）；本阶段不创建账号。原生自动发现 mysql/mariadb 客户端；容器模式指定容器，探针检查 docker inspect Running 并 docker exec mysql，MariaDB容器需提供 mysql兼容客户端；不猜任意容器。查询仅 SELECT、SHOW GLOBAL STATUS、按产品版本选择 SHOW REPLICA STATUS 或 SHOW SLAVE STATUS；MariaDB GTID单独查询。连接失败、权限不足、客户端缺失都报异常，不把“状态查不到”当正常。错误消息只报分类/错误码，避免数据库错误原文泄露秘密。

复制显示线程、延迟、接收/执行位置、GTID、relay、错误码。NULL 延迟不等于0。正延迟即使线程正常也不证明追平。SHOW无记录显示未配置，不能推断当前主。多源复制当前不支持，必须阻断/标需专用适配；监控正常不是数据一致或安全接管证明。

文件同步不执行。进程存在仅作为独立观测；需要未来同步worker发布 data/sync-status.json（producer=abc-sync-worker-v1、root=/home/web/、excludes恰好log/mysql/redis、includes_beifen=true、时间、方向、result、pending、backlog、process_running、last_success_at）。无记录显示未配置；错误范围/过期/失败/积压标异常。该私有状态契约不是密码学认证，管理员/root为信任边界。root全树含beifen和未来目录；不启动监听或rsync。真正文件完整性保持未知。

快照 data/monitor-detail.json 与 data/c-status.json 原子写、fsync；每项 checked_at、最后成功时间独立。boot_id使C重启前快照无效；错误不续用旧正常。采集完成不代表A/B健康。当前无生产事务执行器，生产主、备用、全局方向、任务继续暂无，不从read_only、静态配置、SQL线程推断唯一主。

历史 logs/monitor-history.jsonl 保存time/object/category/result/reason/recovered_at，大小轮转沿用LOG_MAX_BYTES/LOG_KEEP。轮转按周期有界；每轮记录7条。recover只代表从已记录error到ok，不是数据库恢复操作。systemd异常退出由journal记录并自动重启；SIGTERM记录worker stopped，SIGKILL无法trap，依靠systemd退出记录与后续重启；系统宕机由boot-id/过期判定，不能声称死机时仍能写日志。

状态与日志仅项目内。现有config不自动改写；systemd仅在显式确认后链接项目unit到/etc/systemd/system。生产MySQL、复制、Rsync、DNS、Fencing、S3全部不操作。

@@ABC_END

@@ABC_FILE modules/colors.sh 700 0f817e6a8700c337f9d3797d0cd9b37140511c3f7f464b48cb9db3c55239d7c6
#!/usr/bin/env bash
# shellcheck shell=bash
init_colors() {
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' GRAY='' RESET=''
    if [[ -t 1 && ${TERM:-dumb} != dumb && ! -v NO_COLOR ]]; then
        RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
        BLUE=$'\033[34m'; CYAN=$'\033[36m'; GRAY=$'\033[90m'; RESET=$'\033[0m'
    fi
    # 供其他显示函数使用，明确这是统一的公共颜色接口。
    export RED GREEN YELLOW BLUE CYAN GRAY RESET
}
print_unknown() {
    printf '%s：%s暂无%s%s\n' "$1" "$RED" "$RESET" "${2:-}"
}
init_colors

@@ABC_END

@@ABC_FILE modules/common.sh 700 1bb8588534a26cd430a691727264f70373fff3be1427686c8cdcc4a5f585312f
#!/usr/bin/env bash
# shellcheck shell=bash
# 所有模块共用；只接受项目内配置，不 source 配置中的代码。
set -u
set -o pipefail
umask 077
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
DRY_RUN=false

die() { printf '错误：%s\n' "$*" >&2; return 1; }
require_commands() {
    local cmd missing=0
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            printf '缺少依赖：%s（本阶段不会自动安装）\n' "$cmd" >&2
            missing=1
        fi
    done
    return "$missing"
}
validate_private_file() {
    local file=$1
    [[ ! -L $file ]] || return 1
    if [[ -e $file ]]; then
        [[ -f $file && $(stat -c %u "$file") == "$EUID" && $(stat -c %a "$file") == 600 && $(stat -c %h "$file") == 1 ]] || return 1
    fi
}
validate_storage() {
    local path
    for path in "$PROJECT_DIR" "$PROJECT_DIR/config" "$PROJECT_DIR/logs" "$PROJECT_DIR/data" "$PROJECT_DIR/tmp"; do
        [[ -d $path && ! -L $path ]] || { die '项目目录缺失或存在不安全链接'; return 1; }
        [[ $(stat -c %u "$path") == "$EUID" ]] || { die '项目目录所有者不匹配'; return 1; }
        [[ $(stat -c %a "$path") == 700 ]] || { die '项目私有目录权限必须为 700'; return 1; }
    done
}
load_config() {
    local file="$PROJECT_DIR/config/config.env" line key value mode
    local -A seen=()
    # 向后兼容扩展：不改写现有 config.env；缺失的新字段采用安全默认值。
    AUTO_FAILOVER_ENABLED=false
    AUTO_RECOVERY_ENABLED=false
    AUTO_FAILBACK_ENABLED=false
    RECOVERY_STABLE_MINUTES=20
    RECOVERY_SYNC_RETRY=3
    RECOVERY_SYNC_INTERVAL=30
    SYNC_DIRECTION_LOCK=true
    SINGLE_PRIMARY_ENFORCED=true
    POLICY_DRY_RUN=true
    STATUS_EXPIRE_SECONDS=30
    MONITOR_TIMEOUT=8
    MONITOR_SSH_KEY=""
    MONITOR_KNOWN_HOSTS=""
    A_MONITOR_SSH_KEY=""
    B_MONITOR_SSH_KEY=""
    A_MONITOR_KNOWN_HOSTS=""
    B_MONITOR_KNOWN_HOSTS=""
    REPLICATION_WARN_SECONDS=30
    A_SSH_USER=""
    B_SSH_USER=""
    A_SSH_PORT=""
    B_SSH_PORT=""
    A_EXPECTED_MACHINE_ID=""
    B_EXPECTED_MACHINE_ID=""
    A_MYSQL_MONITOR_CNF=""
    B_MYSQL_MONITOR_CNF=""
    A_MYSQL_CONTAINER=""
    B_MYSQL_CONTAINER=""
    [[ -f $file && ! -L $file ]] || { die '统一配置不存在或是符号链接'; return 1; }
    validate_private_file "$file" || { die '配置不是安全的单链接私有普通文件'; return 1; }
    mode=$(stat -c %a "$file") || return 1
    [[ $mode == 600 && $(stat -c %u "$file") == "$EUID" ]] || { die '配置必须属于当前用户且权限为 600'; return 1; }
    while IFS= read -r line || [[ -n $line ]]; do
        [[ -z $line || $line == \#* ]] && continue
        if [[ $line =~ ^([A-Z][A-Z0-9_]*)=\"([^\"]*)\"$ ]]; then
            key=${BASH_REMATCH[1]}; value=${BASH_REMATCH[2]}
        else
            die '配置语法不合法（不输出原文以保护凭据）'; return 1
        fi
        case "$key" in
            PROJECT_DIR|CONFIG_VERSION|NODE_ROLE|A_PUBLIC_IP|B_PUBLIC_IP|C_PUBLIC_IP|A_PRIVATE_IP|B_PRIVATE_IP|C_PRIVATE_IP|SSH_USER|SSH_PORT|SSH_TIMEOUT|MYSQL_PORT|MYSQL_USER|MYSQL_PASSWORD|MYSQL_REPLICATION_MODE|COMMUNICATION_MODE|CF_API_TOKEN|CF_ZONE_ID|CF_DOMAIN|WEB_ROOT|RSYNC_SOURCE|RSYNC_DEST|SYNC_EXCLUDES|REDIS_USAGE|RSYNC_DELETE|SYNC_DEBOUNCE_SECONDS|MONITOR_INTERVAL|FAILURE_THRESHOLD|AUTO_FAILOVER|AUTO_FAILBACK|LOG_MAX_BYTES|LOG_KEEP|AUTO_FAILOVER_ENABLED|AUTO_RECOVERY_ENABLED|AUTO_FAILBACK_ENABLED|RECOVERY_STABLE_MINUTES|RECOVERY_SYNC_RETRY|RECOVERY_SYNC_INTERVAL|SYNC_DIRECTION_LOCK|SINGLE_PRIMARY_ENFORCED|POLICY_DRY_RUN|STATUS_EXPIRE_SECONDS|MONITOR_TIMEOUT|MONITOR_SSH_KEY|MONITOR_KNOWN_HOSTS|A_SSH_USER|B_SSH_USER|A_SSH_PORT|B_SSH_PORT|A_EXPECTED_MACHINE_ID|B_EXPECTED_MACHINE_ID|A_MYSQL_MONITOR_CNF|B_MYSQL_MONITOR_CNF|A_MYSQL_CONTAINER|B_MYSQL_CONTAINER|A_MONITOR_SSH_KEY|B_MONITOR_SSH_KEY|A_MONITOR_KNOWN_HOSTS|B_MONITOR_KNOWN_HOSTS|REPLICATION_WARN_SECONDS) ;;
            *) die '配置含未知字段'; return 1 ;;
        esac
        [[ ! -v seen[$key] ]] || { die '配置字段重复'; return 1; }
        seen[$key]=1
        if [[ $key == PROJECT_DIR ]]; then
            [[ $value == "$PROJECT_DIR" ]] || { die '配置项目路径与入口位置不符'; return 1; }
        else
            printf -v "$key" '%s' "$value"
        fi
    done < "$file"
    local required
    for required in PROJECT_DIR CONFIG_VERSION NODE_ROLE A_PUBLIC_IP B_PUBLIC_IP C_PUBLIC_IP A_PRIVATE_IP B_PRIVATE_IP C_PRIVATE_IP SSH_USER SSH_PORT SSH_TIMEOUT MYSQL_PORT MYSQL_USER MYSQL_PASSWORD MYSQL_REPLICATION_MODE COMMUNICATION_MODE CF_API_TOKEN CF_ZONE_ID CF_DOMAIN WEB_ROOT RSYNC_SOURCE RSYNC_DEST SYNC_EXCLUDES REDIS_USAGE RSYNC_DELETE SYNC_DEBOUNCE_SECONDS MONITOR_INTERVAL FAILURE_THRESHOLD AUTO_FAILOVER AUTO_FAILBACK LOG_MAX_BYTES LOG_KEEP; do
        [[ -v seen[$required] ]] || { die "配置缺少字段：$required"; return 1; }
    done
    [[ $CONFIG_VERSION == 1 ]] || { die '不支持的配置版本'; return 1; }
    [[ $NODE_ROLE =~ ^(A|B|C|UNASSIGNED)$ ]] || { die '节点角色不合法'; return 1; }
    [[ $REDIS_USAGE =~ ^(UNCONFIRMED|CACHE|PERSISTENT)$ ]] || { die 'Redis 用途不合法'; return 1; }
    local name number
    for name in SSH_PORT MYSQL_PORT SSH_TIMEOUT SYNC_DEBOUNCE_SECONDS MONITOR_INTERVAL FAILURE_THRESHOLD LOG_MAX_BYTES LOG_KEEP; do
        number=${!name}
        [[ $number =~ ^[1-9][0-9]{0,8}$ ]] || { die "数值配置不合法：$name"; return 1; }
        case "$name" in
            SSH_PORT|MYSQL_PORT) (( number <= 65535 )) || { die '端口越界'; return 1; } ;;
            LOG_KEEP) (( number <= 20 )) || { die '日志保留份数不能超过 20'; return 1; } ;;
        esac
    done
    for name in STATUS_EXPIRE_SECONDS MONITOR_TIMEOUT; do
        number=${!name}
        [[ $number =~ ^[1-9][0-9]{0,3}$ ]] || { die '监控时间配置不合法'; return 1; }
    done
    (( MONITOR_INTERVAL <= 3600 && MONITOR_TIMEOUT <= 120 && STATUS_EXPIRE_SECONDS <= 7200 )) || { die '监控时间越界'; return 1; }
    # 对旧配置自动扩大有效期下限；保持原 config.env 不变。
    (( STATUS_EXPIRE_SECONDS >= MONITOR_INTERVAL + MONITOR_TIMEOUT + 2 )) || STATUS_EXPIRE_SECONDS=$((MONITOR_INTERVAL + MONITOR_TIMEOUT + 2))
    [[ $REPLICATION_WARN_SECONDS =~ ^[1-9][0-9]{0,4}$ ]] || { die '复制延迟阈值不合法'; return 1; }
    export A_MONITOR_SSH_KEY B_MONITOR_SSH_KEY A_MONITOR_KNOWN_HOSTS B_MONITOR_KNOWN_HOSTS REPLICATION_WARN_SECONDS
    export STATUS_EXPIRE_SECONDS MONITOR_TIMEOUT MONITOR_SSH_KEY MONITOR_KNOWN_HOSTS
    export A_SSH_USER B_SSH_USER A_SSH_PORT B_SSH_PORT A_EXPECTED_MACHINE_ID B_EXPECTED_MACHINE_ID
    export A_MYSQL_MONITOR_CNF B_MYSQL_MONITOR_CNF A_MYSQL_CONTAINER B_MYSQL_CONTAINER
    export PROJECT_DIR NODE_ROLE A_PUBLIC_IP B_PUBLIC_IP A_PRIVATE_IP B_PRIVATE_IP SSH_USER SSH_PORT MONITOR_INTERVAL
    export LOG_MAX_BYTES LOG_KEEP
    [[ $SYNC_EXCLUDES == log,mysql,redis && $WEB_ROOT == /home/web/ && $RSYNC_SOURCE == /home/web/ && $RSYNC_DEST == /home/web/ ]] || { die '同步规则与已确认范围不符'; return 1; }
    [[ $RSYNC_DELETE == false && $AUTO_FAILOVER == false && $AUTO_FAILBACK == false ]] || { die '旧版开关不得启用；须后续显式迁移'; return 1; }
    for name in AUTO_FAILOVER_ENABLED AUTO_RECOVERY_ENABLED AUTO_FAILBACK_ENABLED POLICY_DRY_RUN; do
        [[ ${!name} == false || ${!name} == true ]] || { die '自动化配置必须为 true/false'; return 1; }
    done
    [[ $SYNC_DIRECTION_LOCK == true && $SINGLE_PRIMARY_ENFORCED == true ]] || { die '方向锁及单主保护禁止关闭'; return 1; }
    for name in RECOVERY_STABLE_MINUTES RECOVERY_SYNC_RETRY RECOVERY_SYNC_INTERVAL; do
        number=${!name}
        [[ $number =~ ^[1-9][0-9]{0,4}$ ]] || { die '恢复策略数值不合法'; return 1; }
    done
    (( RECOVERY_STABLE_MINUTES <= 10080 && RECOVERY_SYNC_RETRY <= 100 && RECOVERY_SYNC_INTERVAL <= 86400 )) || {
        die '恢复观察期/重试次数/间隔超过安全上限'; return 1;
    }
    # 此阶段只允许记录意向，不允许实际开启自动化或取消演练模式。
    [[ $AUTO_FAILOVER_ENABLED == false && $AUTO_RECOVERY_ENABLED == false && $AUTO_FAILBACK_ENABLED == false && $POLICY_DRY_RUN == true ]] || {
        die '当前无生产执行器，禁止启用自动化或关闭策略演练'; return 1;
    }
}
bootstrap() {
    require_commands stat flock date mv wc mkdir || return 1
    # 根目录和配置必须已存在；可重建的运行目录按需恢复，不覆盖配置。
    local dir
    for dir in "$PROJECT_DIR" "$PROJECT_DIR/config"; do
        [[ -d $dir && ! -L $dir && $(stat -c %u "$dir") == "$EUID" && $(stat -c %a "$dir") == 700 ]] || {
            die '项目根目录或配置目录不安全'; return 1;
        }
    done
    for dir in logs data tmp; do
        if [[ ! -e $PROJECT_DIR/$dir && ! -L $PROJECT_DIR/$dir ]]; then
            if $DRY_RUN; then
                die "Dry-run：运行目录缺失，未创建 $dir"; return 1
            fi
            mkdir -m 700 -- "$PROJECT_DIR/$dir" || return 1
        fi
    done
    validate_storage && load_config
}
# 日志仅接受固定事件代码，不接收配置、异常原文、密码、Token 或外部输出。
log_event() {
    local event=$1 file="$PROJECT_DIR/logs/framework.log" size i
    case "$event" in INIT|CHECK|STATUS|DIAGNOSE|MODULE_BLOCKED|ERROR|ROTATION_TEST) ;;
        *) die '拒绝非白名单日志事件'; return 1 ;;
    esac
    $DRY_RUN && return 0
    (
        validate_private_file "$PROJECT_DIR/data/log.lock" || exit 1
        exec 9>>"$PROJECT_DIR/data/log.lock" || exit 1
        flock -x 9 || exit 1
        for ((i=0; i<=LOG_KEEP; i++)); do
            if (( i == 0 )); then
                validate_private_file "$file" || exit 1
            else
                validate_private_file "$file.$i" || exit 1
            fi
        done
        size=0
        if [[ -f $file ]]; then size=$(wc -c < "$file") || exit 1; fi
        if (( size + 64 > LOG_MAX_BYTES )); then
            for ((i=LOG_KEEP; i>1; i--)); do
                [[ ! -f $file.$((i-1)) ]] || mv -f -- "$file.$((i-1))" "$file.$i" || exit 1
            done
            [[ ! -f $file ]] || mv -f -- "$file" "$file.1" || exit 1
        fi
        printf '%s event=%s\n' "$(date -u '+%FT%TZ')" "$event" >> "$file"
    )
}
config_status() {
    local name pending=0
    echo '配置结构、权限和第一阶段安全策略：通过'
    for name in A_PUBLIC_IP B_PUBLIC_IP C_PUBLIC_IP MYSQL_USER MYSQL_PASSWORD COMMUNICATION_MODE MYSQL_REPLICATION_MODE CF_API_TOKEN CF_ZONE_ID CF_DOMAIN; do
        if [[ -z ${!name} ]]; then printf '待配置：%s\n' "$name"; pending=1; fi
    done
    [[ $NODE_ROLE != UNASSIGNED ]] || { echo '待配置：NODE_ROLE'; pending=1; }
    case "$REDIS_USAGE" in
        UNCONFIRMED) echo '提示：Redis 用途待部署时核实；Session/队列/持久化业务须单独制定方案。' ;;
        PERSISTENT) echo '阻塞：Redis 非纯缓存，必须制定独立容灾方案。'; pending=1 ;;
        CACHE) echo 'Redis：声明为缓存，部署时仍需核实，可由 B 重建。' ;;
    esac
    echo '同步范围：/home/web/，包含 beifen/ 和未来新增普通目录。'
    echo '唯一指定排除：/home/web/log/ /home/web/mysql/ /home/web/redis/'
    echo '数据库真实挂载异常、节点专用配置冲突：后续检测时提示并阻止不安全同步。'
    (( pending == 0 )) || echo '业务配置尚未完整；不允许部署或接管。'
}
blocked_module() {
    local name=$1
    printf '模块：%s\n' "$name"
    config_status
    if $DRY_RUN; then
        echo '[Dry-run] 仅展示规划；不会执行安装、配置、同步、初始化、DNS 或切换。'
        return 0
    fi
    log_event MODULE_BLOCKED || return 1
    echo '未实现：第一阶段仅提供模块框架；未执行任何业务操作。'
    return 3
}
handle_error() { printf '操作未完成，返回菜单（退出码 %s）。\n' "$1" >&2; }

@@ABC_END

@@ABC_FILE modules/monitor_engine.py 600 2dcb83e12451a1efaf17daa7b23686836960f7e663a4956529ec3018ea2c45bc
#!/usr/bin/env python3
"""C-only monitoring: bounded read-only SSH, private snapshots/history, no data-plane writes."""
from concurrent.futures import ThreadPoolExecutor
import fcntl
import ipaddress
import json
import os
from pathlib import Path
import re
import shlex
import signal
import stat
import subprocess
import sys
import tempfile
import time
from status_view import private_json

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'data'
LOGS = ROOT / 'logs'


def boot_id(): return Path('/proc/sys/kernel/random/boot_id').read_text().strip()


def atomic(path, value):
    if path.exists() or path.is_symlink():
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o600:
            raise ValueError('不安全状态文件')
    fd, name = tempfile.mkstemp(prefix='.monitor-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream, ensure_ascii=False); stream.flush(); os.fsync(stream.fileno())
        os.replace(name, path)
        fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try: os.fsync(fd)
        finally: os.close(fd)
    finally:
        if os.path.exists(name): os.unlink(name)


def lock(name, nonblock=True):
    path = DATA / name
    fd = os.open(path, os.O_CREAT | os.O_APPEND | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
    info = os.fstat(fd)
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o600:
        os.close(fd); raise ValueError('不安全监控锁')
    try: fcntl.flock(fd, fcntl.LOCK_EX | (fcntl.LOCK_NB if nonblock else 0))
    except BaseException: os.close(fd); raise
    return fd


def load(path):
    try: return private_json(path)
    except (OSError, ValueError, TypeError, RecursionError): return None


def entry(status, reason, **values):
    return dict(status=status, reason=reason, checked_at=int(time.time()), **values)


def safe_text(value):
    return ''.join(c for c in str(value) if c >= ' ' and c != '\x7f')[:4096]


def collect_node(node):
    host = os.environ.get(node + '_PRIVATE_IP') or os.environ.get(node + '_PUBLIC_IP', '')
    expected = os.environ.get(node + '_EXPECTED_MACHINE_ID', '')
    key = os.environ.get(node + '_MONITOR_SSH_KEY') or os.environ.get('MONITOR_SSH_KEY', '')
    known = os.environ.get(node + '_MONITOR_KNOWN_HOSTS') or os.environ.get('MONITOR_KNOWN_HOSTS', '')
    missing = entry('unconfigured', '未配置地址、主机身份、SSH 密钥或可信 known_hosts')
    if not all((host, expected, key, known)):
        return dict(server=missing, mysql=missing, replication=missing, rsync_process='unknown')
    try:
        ipaddress.ip_address(host)
        if not re.fullmatch(r'[a-f0-9]{32}', expected): raise ValueError()
        for path in (key, known):
            info = Path(path).lstat()
            if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_uid != os.geteuid() or info.st_mode & 0o077: raise ValueError()
        user = os.environ.get(node + '_SSH_USER') or os.environ.get('SSH_USER', 'root')
        port = os.environ.get(node + '_SSH_PORT') or os.environ.get('SSH_PORT', '22')
        if not re.fullmatch(r'[a-z_][a-z0-9_-]{0,31}', user) or not port.isdigit() or not 1 <= int(port) <= 65535: raise ValueError()
        cnf = os.environ.get(node + '_MYSQL_MONITOR_CNF', '')
        container = os.environ.get(node + '_MYSQL_CONTAINER', '')
        if cnf and not re.fullmatch(r'/[A-Za-z0-9_./-]+', cnf): raise ValueError()
        if container and not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,127}', container): raise ValueError()
        args = ['ssh', '-F', '/dev/null', '-i', key, '-p', port,
                '-o', 'BatchMode=yes', '-o', 'IdentitiesOnly=yes', '-o', 'StrictHostKeyChecking=yes',
                '-o', 'UserKnownHostsFile=' + known, '-o', 'ConnectTimeout=3',
                '-o', 'ServerAliveInterval=2', '-o', 'ServerAliveCountMax=1', user + '@' + host,
                shlex.join(['python3', '-', cnf, container])]
        probe_source = (ROOT / 'modules/monitor_probe.py').read_text()
        # 在同一个受 host-key 验证的 SSH 会话内先核验身份，再执行任何资源/数据库探针。
        probe_source = probe_source.replace('def main():', "def main():\n    if Path('/etc/machine-id').read_text().strip() != " + repr(expected) + ":\n        print(json.dumps({'identity_rejected': True})); return")
        result = subprocess.run(args, input=probe_source,
                                text=True, capture_output=True, timeout=int(os.environ['MONITOR_TIMEOUT']))
        if result.returncode != 0:
            raise ConnectionError('SSH连接、认证、主机密钥或远程只读探针失败')
        if len(result.stdout) > 65536: raise ValueError()
        data = json.loads(result.stdout)
        if data.get('machine_id') != expected: raise ConnectionError('节点身份不匹配，拒绝使用采集数据')
        for item in ('server', 'mysql', 'replication'):
            if not isinstance(data.get(item), dict): raise ValueError()
            if item == 'replication':
                lag = data[item].get('lag_seconds')
                if data[item].get('status') == 'ok' and type(lag) is int and lag > int(os.environ.get('REPLICATION_WARN_SECONDS', '30')):
                    data[item].update(status='warning', reason='复制延迟超过阈值，不能视为已追平')
            data[item]['checked_at'] = int(time.time())
        return data
    except (subprocess.TimeoutExpired, OSError, ValueError, TypeError, KeyError, ConnectionError) as exc:
        reason = ('检查超时：SSH或远程探针超过时限' if isinstance(exc, subprocess.TimeoutExpired) else str(exc) if isinstance(exc, ConnectionError) else 'SSH依赖缺失、配置不合法或探针数据异常')
        failure = entry('error', reason)
        return dict(server=failure, mysql=failure, replication=failure, rsync_process='unknown')


def append_history(rows):
    fd = lock('monitor-history.lock', nonblock=False)
    try:
        _append_history(rows)
    finally:
        os.close(fd)


def _append_history(rows):
    path = LOGS / 'monitor-history.jsonl'
    maximum = int(os.environ.get('LOG_MAX_BYTES', '1048576'))
    keep = int(os.environ.get('LOG_KEEP', '5'))
    blob = ''.join(json.dumps(row, ensure_ascii=False) + '\n' for row in rows).encode()
    for i in range(keep + 1):
        target = path if i == 0 else Path(str(path) + '.' + str(i))
        if target.exists() or target.is_symlink():
            info = target.lstat()
            if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o600:
                raise ValueError('历史文件不安全')
    if path.exists() and path.stat().st_size + len(blob) > maximum:
        for i in range(keep, 1, -1):
            old = Path(str(path) + '.' + str(i-1))
            if old.exists(): os.replace(old, str(path) + '.' + str(i))
        os.replace(path, str(path) + '.1')
    fd = os.open(path, os.O_CREAT | os.O_APPEND | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'ab') as stream:
        stream.write(blob); stream.flush(); os.fsync(stream.fileno())


def files_status(now):
    raw = load(DATA / 'sync-status.json')
    if not isinstance(raw, dict) or raw.get('producer') != 'abc-sync-worker-v1': return entry('unconfigured', '未配置同步执行器或未发布可信同步记录')
    if raw.get('root') != '/home/web/' or raw.get('excludes') != ['log', 'mysql', 'redis'] or raw.get('includes_beifen') is not True:
        return entry('error', '同步范围不符合约定')
    if not isinstance(raw.get('checked_at'), int) or not 0 <= now - raw['checked_at'] <= int(os.environ['STATUS_EXPIRE_SECONDS']):
        return entry('error', '同步记录过期或时间异常')
    # 没有可信进程/积压/结果的独立证据，绝不从任意 rsync 进程推断成功。
    required = ('direction', 'result', 'pending', 'backlog', 'process_running', 'last_success_at')
    if not all(k in raw for k in required): return entry('error', '同步记录字段不完整')
    if not isinstance(raw['pending'], int) or not isinstance(raw['backlog'], int) or raw['pending'] < 0 or raw['backlog'] < 0 or type(raw['process_running']) is not bool or raw['direction'] not in ('A_TO_B', 'B_TO_A', 'NONE'):
        return entry('error', '同步状态字段非法')
    ok = raw['result'] == 'success' and raw['pending'] == 0 and raw['backlog'] == 0
    return entry('ok' if ok else 'error', '' if ok else '同步失败、任务未完成或存在积压', **{k: raw[k] for k in required})


def collect():
    if os.environ.get('NODE_ROLE') != 'C':
        raise ValueError('仅 NODE_ROLE=C 可执行远程采集；未配置 C 身份')
    fd = lock('monitor-check.lock')
    try:
        old = load(DATA / 'monitor-detail.json')
        if not isinstance(old, dict) or not isinstance(old.get('nodes', {}), dict): old = {}
        with ThreadPoolExecutor(max_workers=2) as pool:
            values = dict(zip(('A', 'B'), pool.map(collect_node, ('A', 'B'))))
        now = int(time.time())
        filedata = files_status(now)
        detail = dict(schema=1, checked_at=now, boot_id=boot_id(), nodes=values, files=filedata)
        rows = []
        for node, observations in values.items():
            for category in ('server', 'mysql', 'replication'):
                observation = observations[category]
                previous = old.get('nodes', {}).get(node, {}).get(category, {})
                recovered = now if observation['status'] == 'ok' and previous.get('status') == 'error' else None
                if observation['status'] == 'ok': observation['last_success_at'] = now
                else: observation['last_success_at'] = previous.get('last_success_at')
                rows.append(dict(time=now, object=node, category=category, result=observation['status'],
                                 reason=observation.get('reason', ''), recovered_at=recovered))
        rows.append(dict(time=now, object='C', category='files', result=filedata['status'], reason=filedata['reason'], recovered_at=None))
        nodes = {n: dict(checked_at=values[n]['server']['checked_at'], online='ok' if values[n]['server']['status'] == 'ok' else 'error',
                         business='unknown', status=values[n]['server']['status'], reason=values[n]['server'].get('reason')) for n in ('A', 'B')}
        nodes['C'] = dict(checked_at=now, online='ok', business='checking')
        replicas = [v['replication'] for v in values.values()]
        dbs = [v['mysql'] for v in values.values()]
        health = 'ok' if all(v['status'] == 'ok' for v in dbs) else 'unconfigured' if all(v['status'] == 'unconfigured' for v in dbs) else 'error'
        snapshot = dict(schema=1, source='C', checked_at=now, identity_verified=True, collector_ok=True,
                        collector_boot_id=boot_id(), nodes=nodes, primary=None, single_primary_verified=False,
                        direction=None, operation_id=None,
                        database=dict(checked_at=now, health=health, integrity='unknown',
                                      lag_seconds=next((v.get('lag_seconds') for v in replicas if v.get('role') == 'Replica'), None)),
                        files=dict(checked_at=now, health=filedata['status'], integrity='unknown', last_success_at=filedata.get('last_success_at')),
                        last_success_at=now if all(v['status'] == 'ok' for v in dbs) else None)
        # No live topology executor exists: never infer Primary from read_only or config.
        append_history(rows)
        atomic(DATA / 'monitor-detail.json', detail)
        atomic(DATA / 'c-status.json', snapshot)
        return detail
    finally: os.close(fd)


def show(category='all'):
    data = load(DATA / 'monitor-detail.json')
    if not isinstance(data, dict): print('暂无（未采集、状态文件缺失或损坏）'); return
    now = int(time.time())
    expired = data.get('boot_id') != boot_id() or not 0 <= now - data.get('checked_at', 0) <= int(os.environ['STATUS_EXPIRE_SECONDS'])
    if expired: print('状态已过期或 C 已重启，以下仅为历史，不可视为正常。')
    for node in ('A', 'B'):
        if category in ('A', 'B') and category != node: continue
        for item in ('server', 'mysql', 'replication'):
            if category in ('mysql', 'replication') and item != category: continue
            if category in ('A', 'B') and item != 'server': continue
            if category == 'files': continue
            print(node + ' / ' + item + '：' + safe_text(json.dumps(data.get('nodes', {}).get(node, {}).get(item, {}), ensure_ascii=False)))
    if category in ('all', 'files'):
        print('文件同步：' + safe_text(json.dumps(data.get('files'), ensure_ascii=False)))
        print('范围：/home/web/ 全部递归（含 beifen/ 和未来新增目录）；仅排除 log/ mysql/ redis/。本功能不启动同步。')
    print('复制方向与主节点：暂无（未部署可信拓扑事务发布器，不能由复制线程推断唯一主）')
    print('监控成功不证明数据完整一致，也不代表可安全切换。')


def history(category):
    for path in reversed([LOGS / 'monitor-history.jsonl'] + [LOGS / ('monitor-history.jsonl.' + str(i)) for i in range(1, int(os.environ['LOG_KEEP'])+1)]):
        if not path.exists(): continue
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        try:
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1: raise ValueError('历史文件不安全')
            with os.fdopen(fd, closefd=False) as stream:
                for line in stream:
                    row = json.loads(line)
                    if category == 'all' or row.get('object') == category or row.get('category') == category:
                        print(safe_text(json.dumps(row, ensure_ascii=False)))
        finally: os.close(fd)


def interval(value):
    if not re.fullmatch(r'[1-9][0-9]{0,3}', value) or not 5 <= int(value) <= 3600:
        raise ValueError('检查间隔需为 5—3600 秒整数')
    timeout = int(os.environ['MONITOR_TIMEOUT'])
    expiry = max(30, int(value) + timeout + 2)
    fd = lock('monitor-config.lock')
    try:
        path = ROOT / 'config/config.env'
        text = path.read_text()
        for key, val in (('MONITOR_INTERVAL', value), ('STATUS_EXPIRE_SECONDS', str(expiry))):
            pattern = r'^' + key + r'="[^"\n]*"$'
            if re.search(pattern, text, re.M): text = re.sub(pattern, key + '="' + val + '"', text, flags=re.M)
            else: text += '\n' + key + '="' + val + '"\n'
        # Validate staged configuration using the exact shared parser in a subprocess.
        temporary = ROOT / 'tmp' / ('config-check-' + str(os.getpid()))
        temporary.mkdir(mode=0o700)
        try:
            (temporary / 'config').mkdir(mode=0o700)
            (temporary / 'config/config.env').write_text(text.replace(str(ROOT), str(temporary)))
            (temporary / 'config/config.env').chmod(0o600)
            check = subprocess.run(['bash', '-c', 'source "$1"; PROJECT_DIR=$2; load_config', '_', str(ROOT/'modules/common.sh'), str(temporary)], capture_output=True)
            if check.returncode: raise ValueError('新配置未通过统一校验')
        finally:
            (temporary/'config/config.env').unlink(); (temporary/'config').rmdir(); temporary.rmdir()
        # atomic expects a JSON value; config publication is separately byte-oriented.
        fd2, name = tempfile.mkstemp(prefix='.config-monitor-', dir=path.parent)
        try:
            with os.fdopen(fd2, 'w') as stream: stream.write(text); stream.flush(); os.fsync(stream.fileno())
            os.replace(name, path)
            fd_dir = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
            try: os.fsync(fd_dir)
            finally: os.close(fd_dir)
        finally:
            if os.path.exists(name): os.unlink(name)
        print('已保存间隔 ' + value + ' 秒；有效期 ' + str(expiry) + ' 秒。后台每轮重新加载配置，无需重复创建任务。')
    finally: os.close(fd)


def worker():
    if os.environ.get('NODE_ROLE') != 'C': raise ValueError('未配置 C 角色，拒绝启动后台采集')
    fd = lock('monitor-worker.lock')
    stopped = False
    def stop(_signum, _frame):
        nonlocal stopped
        stopped = True
    signal.signal(signal.SIGTERM, stop); signal.signal(signal.SIGINT, stop)
    try:
        while not stopped:
            begin = time.monotonic()
            result = subprocess.run(['bash', str(ROOT / 'scripts/monitor.sh'), '--once'], capture_output=True, timeout=150)
            if result.returncode:
                append_history([dict(time=int(time.time()), object='C', category='worker', result='error', reason='采集子进程失败', recovered_at=None)])
            # Re-read only literal numeric interval; next collection uses full config validator.
            match = re.search(r'^MONITOR_INTERVAL="([1-9][0-9]{0,8})"$', (ROOT/'config/config.env').read_text(), re.M)
            delay = int(match.group(1)) if match else 30
            while not stopped and time.monotonic() - begin < max(5, min(delay, 3600)):
                time.sleep(0.25)
    finally:
        append_history([dict(time=int(time.time()), object='C', category='worker', result='stopped', reason='监控任务停止', recovered_at=None)])
        os.close(fd)


def main():
    os.umask(0o077)
    action = sys.argv[1] if len(sys.argv)>1 else '--show'
    if action == '--once': collect(); show()
    elif action == '--worker': worker()
    elif action == '--show': show(sys.argv[2] if len(sys.argv)>2 else 'all')
    elif action == '--history': history(sys.argv[2] if len(sys.argv)>2 else 'all')
    elif action == '--interval': interval(sys.argv[2])
    else: raise ValueError('未知监控动作')


if __name__ == '__main__':
    try: main()
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as exc:
        print('监控操作失败：' + safe_text(exc), file=sys.stderr); raise SystemExit(1)

@@ABC_END

@@ABC_FILE modules/monitor_probe.py 600 3d657f72d66f03142bb5cf056837fdf4d80020dfe77544cbff043ff16e728f3c
#!/usr/bin/env python3
"""Read-only remote probe. Parameters contain paths/identities, never passwords."""
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import time


def command(args, stdin=None):
    global LAST_ERROR
    LAST_ERROR = ''
    try:
        p = subprocess.run(args, input=stdin, text=True, capture_output=True, timeout=4)
        match = re.search(r'ERROR\s+(\d+)', p.stderr)
        if p.returncode:
            LAST_ERROR = {'1045': '认证失败', '1044': '权限不足', '1227': '权限不足', '1142': '权限不足', '2002': '无法连接', '2003': '无法连接'}.get(match.group(1) if match else '', '查询失败')
        return p.returncode, p.stdout[:65536]
    except subprocess.TimeoutExpired:
        LAST_ERROR = '检查超时'
        return 1, ''
    except OSError:
        LAST_ERROR = '客户端或工具缺失'
        return 1, ''


def cpu():
    row = Path('/proc/stat').read_text().splitlines()[0].split()[1:9]
    values = list(map(int, row))
    return sum(values), values[3] + values[4]


def parse_vertical(text):
    result = {}
    for line in text.splitlines():
        if ':' in line and not line.startswith('*'):
            key, value = line.strip().split(':', 1)
            if re.fullmatch(r'[A-Za-z0-9_]+', key):
                result[key] = value.strip()[:4096]
    return result


def main():
    cnf, container = sys.argv[1:3]
    result = {'machine_id': Path('/etc/machine-id').read_text().strip(),
              'boot_id': Path('/proc/sys/kernel/random/boot_id').read_text().strip()}
    first = cpu(); time.sleep(0.15); second = cpu()
    total = second[0] - first[0]
    memory = {}
    for row in Path('/proc/meminfo').read_text().splitlines():
        key, value = row.split(':', 1)
        if key in ('MemTotal', 'MemAvailable'): memory[key] = int(value.split()[0])
    fs = os.statvfs('/home' if Path('/home').is_dir() else '/')
    rc, connections = command(['ss', '-s'])
    result['server'] = {'status': 'ok', 'ssh': 'ok', 'online': 'ok',
                        'cpu_percent': round(100 * (1 - (second[1]-first[1])/total), 2) if total else None,
                        'memory_kib': memory, 'disk_total': fs.f_blocks * fs.f_frsize,
                        'disk_available': fs.f_bavail * fs.f_frsize,
                        'load': list(os.getloadavg()), 'network_summary': connections if rc == 0 else '无法查询 ss'}
    client = shutil.which('mariadb') or shutil.which('mysql')
    prefix = []
    if container:
        rc, running = command(['docker', 'inspect', '--format', '{{.State.Running}}', container])
        service = 'running' if rc == 0 and running.strip() == 'true' else 'stopped_or_unknown'
        prefix = ['docker', 'exec', container]
        client = 'mysql'
    else:
        rc, _ = command(['pgrep', '-x', 'mysqld'])
        rc2, _ = command(['pgrep', '-x', 'mariadbd'])
        service = 'running' if rc == 0 or rc2 == 0 else 'stopped_or_unknown'
    db = {'status': 'unconfigured', 'reason': '未配置专用只读客户端凭据路径', 'service': service}
    replica = {'status': 'unconfigured', 'reason': '未配置数据库只读连接'}
    if cnf and client:
        # cnf exists on target/container; never read or transmit its content.
        base = prefix + [client, '--defaults-extra-file=' + cnf, '--connect-timeout=3', '--batch', '--raw']
        query = "SELECT VERSION(), @@version_comment, @@read_only; SHOW GLOBAL STATUS WHERE Variable_name IN ('Uptime','Threads_connected','Aborted_connects');"
        db = None
        if not container:
            try:
                info = Path(cnf).lstat()
                safe_cnf = stat.S_ISREG(info.st_mode) and info.st_nlink == 1 and not info.st_mode & 0o077 and info.st_uid == os.geteuid()
            except OSError:
                safe_cnf = False
            if not safe_cnf:
                result.update(mysql={'status': 'error', 'reason': '数据库凭据文件缺失或权限不安全', 'service': service}, replication={'status': 'error', 'reason': '凭据权限检查失败'}, rsync_process='unknown')
                print(json.dumps(result)); return
        rc, output = command(base, query)
        if rc:
            db = {'status': 'error', 'reason': LAST_ERROR or '数据库只读查询失败', 'service': service}
            replica = {'status': 'error', 'reason': '数据库连接失败，无法检查复制'}
        else:
            rows = output.splitlines()
            version = rows[1].split('\t') if len(rows) > 1 else []
            if len(version) < 3:
                db = {'status': 'error', 'reason': '数据库返回格式异常', 'service': service}
            else:
                product = 'MariaDB' if 'mariadb' in (' '.join(version)).lower() else 'MySQL'
                db = {'status': 'ok', 'reason': '', 'service': 'reachable (remote SQL; local process state independent)', 'product': product,
                      'version': version[0], 'read_only': version[2], 'runtime': rows[2:12],
                      'errors_scope': '连接和只读查询无错误；未读取业务日志，不证明无其他错误'}
                variables_sql = "SHOW GLOBAL VARIABLES WHERE Variable_name IN ('log_bin','gtid_mode','gtid_executed','gtid_strict_mode','gtid_binlog_pos','gtid_slave_pos');\n"
                vr, variables = command(base, variables_sql)
                db['binlog_gtid_variables'] = variables.splitlines()[1:] if vr == 0 else []
                major_version = re.match(r'(\d+)\.(\d+)\.(\d+)', version[0])
                binlog_sql = 'SHOW BINARY LOG STATUS;\n' if product == 'MySQL' and major_version and int(major_version.group(1)) >= 8 and int(major_version.group(2)) >= 4 else 'SHOW MASTER STATUS;\n'
                br, binary = command(base, binlog_sql)
                db['binlog_position'] = binary.splitlines() if br == 0 else []
                db['binlog_query_status'] = 'ok' if br == 0 else LAST_ERROR
                if br != 0:
                    db['status'] = 'error'
                    db['reason'] = 'Binlog状态检查未完成：' + LAST_ERROR
                major = re.match(r'(\d+)\.(\d+)\.(\d+)', version[0])
                modern = product == 'MySQL' and major and tuple(map(int, major.groups())) >= (8, 0, 22)
                sql = 'SHOW REPLICA STATUS\\G' if modern else 'SHOW SLAVE STATUS\\G'
                rc, rep = command(base, sql + '\n')
                status = parse_vertical(rep)
                if rc:
                    replica = {'status': 'error', 'reason': '复制状态查询失败（权限或产品不支持）'}
                elif rep.count('***************************') > 1:
                    replica = {'status': 'error', 'reason': '发现多源复制，当前只读适配器不支持逐通道验证'}
                elif not status:
                    replica = {'status': 'unconfigured', 'reason': '未配置 Replica；不能据此推断为 Primary'}
                else:
                    def get(new, old): return status.get(new, status.get(old))
                    io = get('Replica_IO_Running', 'Slave_IO_Running')
                    sql_thread = get('Replica_SQL_Running', 'Slave_SQL_Running')
                    lag = get('Seconds_Behind_Source', 'Seconds_Behind_Master')
                    last_io = status.get('Last_IO_Error', '')
                    last_sql = status.get('Last_SQL_Error', '')
                    replica = {'status': 'ok' if io == 'Yes' and sql_thread == 'Yes' and not last_io and not last_sql and lag and lag.isdigit() else 'error',
                               'reason': '' if io == 'Yes' and sql_thread == 'Yes' and not last_io and not last_sql and lag and lag.isdigit() else '复制线程停止、延迟未知或存在错误',
                               'role': 'Replica', 'io': io, 'sql': sql_thread,
                               'lag_seconds': int(lag) if lag and lag.isdigit() else None,
                               'received_file': get('Source_Log_File', 'Master_Log_File'),
                               'received_position': get('Read_Source_Log_Pos', 'Read_Master_Log_Pos'),
                               'applied_file': get('Relay_Source_Log_File', 'Relay_Master_Log_File'),
                               'applied_position': get('Exec_Source_Log_Pos', 'Exec_Master_Log_Pos'),
                               'relay_log': status.get('Relay_Log_File'),
                               'received_gtid': status.get('Retrieved_Gtid_Set', status.get('Gtid_IO_Pos')),
                               'applied_gtid': status.get('Executed_Gtid_Set'),
                               'io_error_code': status.get('Last_IO_Errno'), 'sql_error_code': status.get('Last_SQL_Errno'),
                               'error_information': 'IO错误存在' if last_io else 'SQL错误存在' if last_sql else '无已报告的复制错误'}
                    error_text = (last_io or last_sql)
                    error_text = re.sub(r"'[^']*'", "'[redacted]'", error_text)
                    error_text = re.sub(r'(?i)(password|token|secret)\\s*[=:]\\s*\\S+', r'\1=[redacted]', error_text)
                    error_text = ''.join(c for c in error_text if c >= ' ' and c != '\x7f')[:512]
                    replica['error_detail_redacted'] = ('详细错误文本已抑制以避免泄漏凭据或业务数据；请在源端授权诊断' if error_text else '')
                    # MariaDB execution GTID is a product-specific global variable.
                    if product == 'MariaDB':
                        rc, gtid = command(base, 'SELECT @@global.gtid_slave_pos;\n')
                        if rc == 0: replica['applied_gtid'] = gtid.splitlines()[-1] if gtid.splitlines() else None
    elif cnf:
        db = {'status': 'error', 'reason': '未发现数据库客户端', 'service': service}
    rc, _ = command(['pgrep', '-x', 'rsync'])
    result.update(mysql=db, replication=replica, rsync_process='present' if rc == 0 else 'absent')
    print(json.dumps(result))


if __name__ == '__main__':
    main()

@@ABC_END

@@ABC_FILE modules/state_machine.sh 700 479b4f1117508fb186a4fd034026b830edab201c9c7040bea8223d7f48a31831
#!/usr/bin/env bash
# shellcheck shell=bash
# 离线纯函数：事实由测试输入，不是可信生产证据；绝不调用执行器或保存活动状态。
policy_edge() {
    local state=$1
    case "$state" in
        NORMAL_A) NEXT=SUSPECT_A; REQUIRED='a_failed_repeated c_network_ok b_reachable' ;;
        SUSPECT_A) NEXT=A_FENCED; REQUIRED='lock_owned epoch_valid a_fenced_persistent' ;;
        A_FENCED) NEXT=B_DRAINED; REQUIRED='a_fenced_persistent sync_a_b_stopped received_boundary_fixed relay_applied b_no_sql_error risk_accepted files_fresh' ;;
        B_DRAINED) NEXT=B_PRIMARY; REQUIRED='lock_owned epoch_valid a_fenced_persistent b_promote_verified' ;;
        B_PRIMARY) NEXT=B_HEALTHY; REQUIRED='a_fenced_persistent b_only_writer b_services_started b_business_healthy' ;;
        B_HEALTHY) NEXT=ACTIVE_B; REQUIRED='b_only_writer a_fenced_persistent dns_b_readback_all' ;;
        ACTIVE_B) NEXT=RECOVERY_PREFLIGHT; REQUIRED='b_only_writer a_returned a_business_fenced a_control_reachable' ;;
        RECOVERY_PREFLIGHT) NEXT=A_REPLICA; REQUIRED='b_only_writer a_business_fenced a_environment_ok lineage_checked recovery_method_authorized a_reseed_or_attach_verified redis_plan_ok' ;;
        A_REPLICA) NEXT=A_CATCHING_UP; REQUIRED='b_only_writer a_business_fenced b_a_replication_running b_a_sync_authorized' ;;
        A_CATCHING_UP) NEXT=A_STABLE; REQUIRED='b_only_writer a_business_fenced db_channel_healthy file_channel_healthy a_caught_sample stable_period_elapsed a_readonly_health_ok' ;;
        A_STABLE) NEXT=B_QUIESCED; REQUIRED='lock_owned epoch_valid b_only_writer a_business_fenced all_b_writers_stopped b_write_sessions_drained ddl_events_stopped maintenance_active' ;;
        B_QUIESCED) NEXT=FINAL_VERIFIED; REQUIRED='lock_owned epoch_valid all_b_writers_stopped b_final_boundary_fixed a_final_boundary_applied final_files_verified db_consistency_verified' ;;
        FINAL_VERIFIED) NEXT=B_FENCED; REQUIRED='lock_owned epoch_valid a_business_fenced b_fenced_persistent no_writers final_proofs_fresh' ;;
        B_FENCED) NEXT=A_PRIMARY; REQUIRED='lock_owned epoch_valid b_fenced_persistent final_proofs_fresh a_promote_verified' ;;
        A_PRIMARY) NEXT=A_HEALTHY; REQUIRED='b_fenced_persistent a_only_writer a_services_started a_business_healthy' ;;
        A_HEALTHY) NEXT=DNS_A_VERIFIED; REQUIRED='a_only_writer b_fenced_persistent dns_a_readback_all' ;;
        DNS_A_VERIFIED) NEXT=B_REPLICA; REQUIRED='a_only_writer b_business_fenced a_b_replication_verified b_readonly_verified b_web_writers_disabled' ;;
        B_REPLICA) NEXT=NORMAL_A; REQUIRED='a_only_writer b_readonly_verified a_b_sync_authorized b_a_sync_stopped final_topology_verified' ;;
        PLAN_REQUESTED) NEXT=PLAN_PREFLIGHT; REQUIRED='lock_owned epoch_valid no_active_operation identities_verified c_network_ok a_only_writer dns_baseline_ok request_authorized' ;;
        PLAN_PREFLIGHT) NEXT=PLAN_A_QUIESCED; REQUIRED='lock_owned epoch_valid a_only_writer b_version_ok b_replication_ok b_caught_sample b_disk_ok file_channel_healthy b_config_ok b_readonly_health_ok all_a_writers_stopped a_transactions_drained maintenance_active' ;;
        PLAN_A_QUIESCED) NEXT=PLAN_FINAL_VERIFIED; REQUIRED='lock_owned epoch_valid all_a_writers_stopped a_final_boundary_fixed b_final_boundary_applied final_files_verified db_consistency_verified' ;;
        PLAN_FINAL_VERIFIED) NEXT=A_FENCED; REQUIRED='lock_owned epoch_valid final_proofs_fresh a_fenced_persistent sync_a_b_stopped planned_boundary_preserved' ;;
        MAINTENANCE_B) NEXT=RECOVERY_PREFLIGHT; REQUIRED='lock_owned epoch_valid no_active_operation identities_verified b_only_writer a_returned a_business_fenced a_control_reachable manual_recovery_authorized' ;;
        REQUEST_PENDING) NEXT=CANCELLED; REQUIRED='lock_owned epoch_valid request_matches no_side_effect_intent no_side_effect_result worker_not_started' ;;
        MANUAL_REQUIRED) NEXT=MANUAL_REQUIRED; REQUIRED='operator_reconcile_required' ;;
        *) printf '未知状态，拒绝推导。\n' >&2; return 2 ;;
    esac
}
policy_transition() {
    local state=$1 fact missing=0
    shift
    local -A facts=()
    policy_edge "$state" || return 2
    for fact in "$@"; do
        [[ $fact =~ ^[a-z][a-z0-9_]*$ && ! -v facts[$fact] ]] || { echo '事实格式不合法或重复' >&2; return 2; }
        # 每条边仅允许自身声明的事实，拒绝拼写错误和无效的“额外证明”。
        [[ " $REQUIRED " == *" $fact "* ]] || { echo '本边不接受该事实' >&2; return 2; }
        facts[$fact]=1
    done
    for fact in $REQUIRED; do
        if [[ ! -v facts[$fact] ]]; then printf '缺少模拟条件：%s\n' "$fact"; missing=1; fi
    done
    if (( missing )); then
        echo 'next=MANUAL_REQUIRED'
        echo '保持既有写入权限和隔离；禁止自动回滚或提升。'
        return 4
    fi
    [[ $state != MANUAL_REQUIRED ]] || { echo '需要可信证据对账和管理员重新授权，模拟不能解除暂停。'; return 4; }
    printf 'next=%s\n' "$NEXT"
}
policy_direction() {
    case "$1" in
        NORMAL_A|SUSPECT_A|PLAN_REQUESTED|PLAN_PREFLIGHT) echo 'A_TO_B; A 为只读文件源，禁止写入 A' ;;
        A_REPLICA|A_CATCHING_UP|A_STABLE) echo 'B_TO_A; 仅限 A 业务隔离、B 唯一主、C 有效事务授权' ;;
        DNS_A_VERIFIED|B_REPLICA) echo 'NONE; 待 B 只读与复制验证、旧方向停止后恢复 A_TO_B' ;;
        ACTIVE_B|MAINTENANCE_B|RECOVERY_PREFLIGHT) echo 'NONE; 尚未批准对 A 的恢复写入' ;;
        PLAN_A_QUIESCED|PLAN_FINAL_VERIFIED|REQUEST_PENDING|CANCELLED) echo 'NONE; 常规任务冻结，仅授权事务可执行最终同步' ;;
        A_FENCED|B_DRAINED|B_PRIMARY|B_HEALTHY|B_QUIESCED|FINAL_VERIFIED|B_FENCED|A_PRIMARY|A_HEALTHY|MANUAL_REQUIRED) echo 'NONE; 切换屏障或未知状态，常规同步禁止' ;;
        *) echo '未知状态，拒绝方向授权' >&2; return 2 ;;
    esac
}

@@ABC_END

@@ABC_FILE modules/status_view.py 600 4cf3d477e73f0472bb6fb8e0595bc20614e7d564969df5659b32debc5a1d656b
#!/usr/bin/env python3
"""Read-only C snapshot renderer. No collection, networking or fixture fallback."""
import json
import os
from pathlib import Path
import re
import stat
import sys
import time

TTL = int(os.environ.get('STATUS_EXPIRE_SECONDS', '30'))
MAX_SIZE = 65536


def private_json(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1 or info.st_size > MAX_SIZE:
            raise ValueError('unsafe file')
        raw = os.read(fd, MAX_SIZE + 1)
        if len(raw) > MAX_SIZE:
            raise ValueError('oversized')
        def pairs(items):
            result = {}
            for key, value in items:
                if key in result:
                    raise ValueError('duplicate key')
                result[key] = value
            return result
        return json.loads(raw, object_pairs_hook=pairs)
    finally:
        os.close(fd)


def fresh(value, now):
    return type(value) is int and 0 <= now - value <= TTL


def render(data, now, color=False):
    lines = []
    def emit(text, severity='red'):
        # 仅修饰冒号后的值；字段名、标题和括号原因保持默认颜色。
        enabled = color and 'NO_COLOR' not in os.environ
        if not enabled or '：' not in text:
            lines.append(text)
            return
        label, value = text.split('：', 1)
        if not value:
            lines.append(text)
            return
        main, separator, reason = value.partition('（')
        statuses = {'暂无': 31, '正常': 32, '警告': 33, '异常': 31,
                    '错误': 31, '失败': 31, '维护中': 33, '检查中': 34,
                    '待检查': 34, '未配置': 90, '同步完成': 32,
                    '同步中': 34, '延迟较高': 33, '暂无或异常': 31}
        code = statuses.get(main)
        if main != '暂无' and label == '当前生产主站': code = 32
        elif main != '暂无' and label == '当前备用节点': code = 33
        elif main != '暂无' and label == '当前同步方向': code = 34
        elif label == '当前切换任务' and main != '暂无': code = 34
        painted = f'\033[{code}m{main}\033[0m' if code is not None else main
        lines.append(label + '：' + painted + (separator + reason if separator else ''))
    valid = (isinstance(data, dict) and data.get('schema') == 1 and
             data.get('source') == 'C' and data.get('collector_ok') is True and
             fresh(data.get('checked_at'), now) and data.get('identity_verified') is True)
    emit('实时节点状态：', 'yellow')
    if not valid:
        for label in ('节点 A', '节点 B', '监控 C'):
            emit(f'{label}：暂无（状态缺失、过期或无法确认）')
        lines.append('========================================')
        for label in ('当前生产主站', '当前备用节点', '当前同步方向', '当前切换任务',
                      '数据库状态', '文件同步状态', '数据同步时间', '复制延迟', '最后一次成功检查时间'):
            emit(f'{label}：暂无')
        return '\n'.join(lines)
    nodes = data.get('nodes', {})
    for name, label in (('A', '节点 A'), ('B', '节点 B'), ('C', '监控 C')):
        node = nodes.get(name, {}) if isinstance(nodes, dict) else {}
        if not isinstance(node, dict) or not fresh(node.get('checked_at'), now):
            emit(f'{label}：暂无（未检测或过期）'); continue
        if node.get('status') == 'unconfigured':
            emit(f'{label}：未配置（地址、身份或SSH信任未完成）'); continue
        if node.get('reason'):
            reason = ''.join(c for c in str(node['reason']) if c >= ' ' and c != '\x7f')[:160]
            emit(f'{label}异常原因：{reason}')
        for field, title in (('online', '服务器在线'), ('business', '业务健康')):
            value = node.get(field)
            if not isinstance(value, str):
                value = 'unknown'
            severity = 'green' if value == 'ok' else 'yellow' if value in ('checking', 'maintenance') else 'red'
            text = {'ok': '正常', 'checking': '待检查', 'maintenance': '维护中', 'error': '错误'}.get(value, '暂无')
            emit(f'{label} / {title}：{text}', severity)
    lines.append('========================================')
    primary = data.get('primary')
    role_ok = primary in ('A', 'B') and data.get('single_primary_verified') is True
    emit(f'当前生产主站：{primary if role_ok else "暂无"}', 'yellow' if role_ok else 'red')
    emit(f'当前备用节点：{("B" if primary == "A" else "A") if role_ok else "暂无"}', 'yellow' if role_ok else 'red')
    direction = data.get('direction')
    allowed = {'A_TO_B': 'A → B', 'B_TO_A': 'B → A', 'NONE': '暂停'}
    direction_ok = role_ok and ((primary == 'A' and direction == 'A_TO_B') or (primary == 'B' and direction == 'B_TO_A') or direction == 'NONE')
    emit(f'当前同步方向：{allowed[direction] if direction_ok else "暂无（方向冲突）"}', 'yellow' if direction_ok else 'red')
    operation = data.get('operation_id')
    if operation is None:
        emit('当前切换任务：暂无', 'red')
    elif isinstance(operation, str) and re.fullmatch(r'[A-Za-z0-9_-]{1,64}', operation):
        emit(f'当前切换任务：{operation}', 'yellow')
    else:
        emit('当前切换任务：暂无（数据非法）')
    for key, title in (('database', '数据库'), ('files', '文件同步')):
        channel = data.get(key, {})
        if not isinstance(channel, dict) or not fresh(channel.get('checked_at'), now):
            emit(f'{title}状态：暂无（未检测或过期）'); continue
        if channel.get('health') == 'unconfigured':
            emit(f'{title}状态：未配置'); continue
        for field, title2 in (('health', '通道状态'), ('integrity', '数据完整性')):
            good = channel.get(field) == 'ok'
            emit(f'{title} / {title2}：{"正常" if good else "暂无或异常"}', 'green' if good else 'red')
        if key == 'database':
            lag = channel.get('lag_seconds')
            emit(f'复制延迟：{str(lag) + " 秒" if type(lag) is int and lag >= 0 else "暂无"}', 'yellow' if type(lag) is int and lag >= 0 else 'red')
        else:
            stamp = channel.get('last_success_at')
            valid_stamp = type(stamp) is int and 0 < stamp <= now
            emit(f'数据同步时间：{stamp if valid_stamp else "暂无"}（Unix 秒）', 'yellow' if valid_stamp else 'red')
    stamp = data.get('last_success_at')
    valid_stamp = type(stamp) is int and 0 < stamp <= now
    emit(f'最后一次成功检查时间：{stamp if valid_stamp else "暂无"}（Unix 秒）', 'yellow' if valid_stamp else 'red')
    return '\n'.join(lines)


def main():
    path = Path(__file__).resolve().parents[1] / 'data/c-status.json'
    try:
        data = private_json(path)
    except (OSError, ValueError, TypeError, RecursionError):
        data = None
    if isinstance(data, dict) and 'collector_boot_id' in data:
        if data['collector_boot_id'] != Path('/proc/sys/kernel/random/boot_id').read_text().strip():
            data = None
    print(render(data, int(time.time()), sys.stdout.isatty() and os.environ.get('TERM', 'dumb') != 'dumb'))


if __name__ == '__main__':
    main()

@@ABC_END

@@ABC_FILE modules/status_view.sh 700 ef7c2b07296a00129fe03e023fdf9cb8b8fc65bbe0a683db76a9b8065d43d5fc
#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source=colors.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/colors.sh"
# 仅识别本地实现能力；文件存在不表示已经部署或获准启用。
show_project_stage() {
    if [[ -e $PROJECT_DIR/modules/executor.sh || -e $PROJECT_DIR/data/deployment.json ]]; then
        echo '部署阶段待核验：业务启用状态无法确认'
    elif [[ -f $PROJECT_DIR/modules/state_machine.sh && -f $PROJECT_DIR/scripts/coordinator_plan.sh ]]; then
        echo '离线架构阶段：业务操作未启用'
    else
        echo '项目阶段：暂无（实现文件缺失或无法确认）'
    fi
}
show_c_status() {
    if command -v python3 >/dev/null 2>&1; then
        python3 "$PROJECT_DIR/modules/status_view.py" && return 0
    fi
    echo '实时节点状态：'
    local label
    for label in '节点 A' '节点 B' '监控 C'; do
        print_unknown "$label" '（状态缺失、过期或无法确认）'
    done
    echo '========================================'
    for label in '当前生产主站' '当前备用节点' '当前同步方向' '当前切换任务' '数据库状态' '文件同步状态' '数据同步时间' '复制延迟' '最后一次成功检查时间'; do
        print_unknown "$label"
    done
}

@@ABC_END

@@ABC_FILE scripts/check.sh 700 81806942c118bfa04c8e11bbad62fe693fc6b12367f4193d500e1fdd56d780de
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
case "${1:---check}" in
    --check|--dry-run|--diagnose|--status) ;;
    *) die '未知检查参数'; exit 2 ;;
esac
config_status
echo '--- 本机只读环境检测（不连接 A/B/C、不检测业务凭据）---'
if [[ -r /etc/os-release ]]; then
    while IFS= read -r line; do
        case "$line" in PRETTY_NAME=*|VERSION_ID=*) printf '%s\n' "$line" ;; esac
    done < /etc/os-release
fi
printf '内核：'; uname -sr
printf 'CPU 核数：'; getconf _NPROCESSORS_ONLN
if [[ -r /proc/meminfo ]]; then
    while IFS= read -r line; do
        case "$line" in MemTotal:*|MemAvailable:*) printf '%s\n' "$line" ;; esac
    done < /proc/meminfo
fi
df -h -- "$PROJECT_DIR"
for cmd in bash flock stat timeout curl jq ssh rsync inotifywait docker mysql mariadb wg systemctl shellcheck; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '工具 %-12s 已存在\n' "$cmd"
    else
        printf '工具 %-12s 未发现（不会自动安装）\n' "$cmd"
    fi
done
# 只检查可执行文件，不查询可能携带生产秘密的容器详情。
if command -v docker >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
    timeout 5 docker compose version 2>/dev/null || echo 'Docker Compose：无法确认'
fi
if [[ -d $WEB_ROOT ]]; then echo '网站根目录：存在（未遍历、未同步）'; else echo '网站根目录：未发现（不会创建）'; fi
echo '业务服务运行状态、容器映射、数据库版本、Redis 用途：第二阶段授权检测。'
log_event CHECK || exit 1

@@ABC_END

@@ABC_FILE scripts/cloudflare.sh 700 be46669c8c0ee917866728f7a212c518b340eb1b453e677897ceb21141de9533
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知模块参数'; exit 2; }
blocked_module 'Cloudflare 免费 DNS 配置'

@@ABC_END

@@ABC_FILE scripts/communication.sh 700 10622501d4ef98ed9c45f893ee4d9226fb15326af96dcc039565a6d44448c287
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || exit 2
while true; do
    if [[ -t 1 && ${TERM:-dumb} != dumb ]]; then printf '\033[2J\033[H'; fi
    echo '========================================'
    echo '       MySQL 主从复制通信方式'
    echo '========================================'
    echo
    echo '请选择节点之间的通信方式：'
    echo
    echo '1. Rsync + SSH'
    echo '2. WireGuard 建立私有网络'
    echo
    echo '0. 返回主菜单'
    echo '========================================'
    printf '请输入编号：'
    IFS= read -r choice || exit 0
    case "$choice" in
        1) blocked_module 'Rsync + SSH（Binlog 另需安全数据库通道）' || handle_error "$?" ;;
        2) blocked_module 'WireGuard + SSH' || handle_error "$?" ;;
        0) exit 0 ;;
        *) echo '输入错误，请输入 0—2。'; continue ;;
    esac
    printf '按回车继续...'
    IFS= read -r choice || exit 0
done

@@ABC_END

@@ABC_FILE scripts/coordinator_plan.sh 700 52719f1d5af4f78525a38093e9d4b00b2d5385bbb1401eb4d459a8c7bacab3be
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
# shellcheck source=../modules/state_machine.sh
source "$PROJECT_DIR/modules/state_machine.sh"
DRY_RUN=true
bootstrap || exit 1
case "${1:---help}" in
    --help)
        echo '离线状态机，不是生产协调器，不保存状态，不执行远程动作。'
        echo '用法：--edge STATE | --direction STATE | --simulate STATE FACT... | --policy'
        echo '输入事实仅用于演算，不可用作生产隔离或一致性证明。'
        ;;
    --edge)
        [[ $# == 2 ]] || exit 2
        policy_edge "$2" || exit "$?"
        printf 'state=%s next=%s\nrequired=%s\n' "$2" "$NEXT" "$REQUIRED"
        ;;
    --direction) [[ $# == 2 ]] || exit 2; policy_direction "$2" ;;
    --simulate)
        [[ $# -ge 2 ]] || exit 2
        shift; policy_transition "$@" ;;
    --policy)
        [[ $# == 1 ]] || exit 2
        printf 'AUTO_FAILOVER_ENABLED=%s\nAUTO_RECOVERY_ENABLED=%s\nAUTO_FAILBACK_ENABLED=%s\n' "$AUTO_FAILOVER_ENABLED" "$AUTO_RECOVERY_ENABLED" "$AUTO_FAILBACK_ENABLED"
        printf 'RECOVERY_STABLE_MINUTES=%s\nRECOVERY_SYNC_RETRY=%s\nRECOVERY_SYNC_INTERVAL=%s\n' "$RECOVERY_STABLE_MINUTES" "$RECOVERY_SYNC_RETRY" "$RECOVERY_SYNC_INTERVAL"
        printf 'SYNC_DIRECTION_LOCK=%s\nSINGLE_PRIMARY_ENFORCED=%s\nPOLICY_DRY_RUN=%s\n' "$SYNC_DIRECTION_LOCK" "$SINGLE_PRIMARY_ENFORCED" "$POLICY_DRY_RUN"
        ;;
    *) die '拒绝动作：只允许离线查询和模拟'; exit 2 ;;
esac

@@ABC_END

@@ABC_FILE scripts/dns_switch.sh 700 d7a4827a8428eea57787701f6e430a10adedff3f7dbb39e541ab6d0e1016a5fe
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知模块参数'; exit 2; }
blocked_module 'DNS 切换'

@@ABC_END

@@ABC_FILE scripts/failover.sh 700 7c36e50150443b6b9d263d93200eae3ef498c175568b1256f1a32444dc924852
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知模块参数'; exit 2; }
blocked_module '故障切换管理'

@@ABC_END

@@ABC_FILE scripts/install.sh 700 d0dae9adace6117608b6d51c645f1686d601c10c295958e4c1980efdd5d97e5e
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知安装参数'; exit 2; }
if $DRY_RUN; then
    echo '[Dry-run] 校验项目框架；不创建状态、不改配置、不安装依赖、不注册任务。'
    exit 0
fi
validate_private_file "$PROJECT_DIR/data/install.lock" && validate_private_file "$PROJECT_DIR/data/framework.version" || exit 1
exec 8>>"$PROJECT_DIR/data/install.lock" || exit 1
flock -n 8 || { die '框架初始化正在运行'; exit 1; }
if [[ -e $PROJECT_DIR/data/framework.version ]]; then
    [[ $(< "$PROJECT_DIR/data/framework.version") == 1 ]] || { die '已有状态版本不兼容，拒绝覆盖'; exit 1; }
    echo '基础框架已初始化；保留现有配置和状态，不重复创建任务。'
else
    printf '1\n' > "$PROJECT_DIR/data/framework.version" || exit 1
    log_event INIT || exit 1
    echo '基础框架初始化完成；未安装任何业务服务、定时器或后台任务。'
fi

@@ABC_END

@@ABC_FILE scripts/main.sh 700 d6665856d350be02c168f9e5973aad31e3a51cfb659c8e522cf21c723c828db6
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
# shellcheck source=../modules/status_view.sh
source "$PROJECT_DIR/modules/status_view.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知菜单参数'; exit 2; }
show_menu() {
    if [[ -t 1 && ${TERM:-dumb} != dumb ]]; then printf '\033[2J\033[H'; fi
    echo '========================================'
    echo '       A-B-C MySQL 主备容灾管理系统'
    echo '========================================'
    show_c_status
    echo '------------------------'
    echo "项目目录：$PROJECT_DIR"
    show_project_stage
    echo '========================================'
    echo '1. Cloudflare 免费 DNS 配置'
    echo '2. A VPS 主服务器配置'
    echo '3. B VPS 备用服务器配置'
    echo '4. MySQL 主从复制通信方式'
    echo '5. MySQL Binlog 主从复制配置'
    echo '6. SSH + Rsync 网站文件同步'
    echo '7. C 节点独立监控 A、B'
    echo '8. 自动故障切换与恢复脚本'
    echo '9. 手动切换与计划维护'
    echo '------------------------'
    echo '0. 退出程序'
    echo '------------------------'
}
run_module() {
    local args=()
    $DRY_RUN && args+=(--dry-run)
    bash "$PROJECT_DIR/scripts/$1.sh" "${args[@]}" || handle_error "$?"
}
main() {
    local choice
    while true; do
        show_menu
        printf '请输入编号：'
        IFS= read -r choice || { echo; echo '已退出'; return 0; }
        case "$choice" in
            1) run_module cloudflare ;;
            2) run_module server_a ;;
            3) run_module server_b ;;
            4) run_module communication; continue ;;
            5) run_module mysql_primary ;;
            6) run_module sync_files ;;
            7) run_module monitor ;;
            8) run_module failover ;;
            9) run_module manual_maintenance; continue ;;
            0) echo '已退出'; return 0 ;;
            *) echo '输入错误，请输入 0—9。'; continue ;;
        esac
        printf '按回车继续...'
        IFS= read -r choice || return 0
    done
}
main

@@ABC_END

@@ABC_FILE scripts/manual_maintenance.sh 700 c3fe6b0c66ee8a47e37eb0bfdfef2934ae57c95c76f4d7243e1c818ba90f63bc
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
# shellcheck source=../modules/status_view.sh
source "$PROJECT_DIR/modules/status_view.sh"
# 本阶段无条件只读：菜单点击不创建、取消或执行任何真实任务。
DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || exit 2
while true; do
    if [[ -t 1 && ${TERM:-dumb} != dumb ]]; then printf '\033[2J\033[H'; fi
    echo '========================================'
    echo '        手动切换与计划维护'
    echo '========================================'
    show_c_status
    echo
    echo '1. 手动切换生产业务到 B'
    echo '2. A 服务器计划维护 / 迁移'
    echo '3. 手动恢复生产业务到 A'
    echo '4. 查看当前切换进度'
    echo '5. 查看数据同步与一致性检查'
    echo '6. 取消尚未执行的切换任务'
    echo
    echo '0. 返回主菜单'
    echo '========================================'
    printf '请输入编号：'
    IFS= read -r choice || exit 0
    case "$choice" in
        1|2)
            echo '[预览] 身份/冲突/复制/磁盘/文件/配置/DNS 检查 → A 写屏障 → 最终边界和文件校验 → 隔离 A → 提升 B → 健康 → DNS 读回。'
            echo '维护模式：B 接管后保留 A 业务隔离，禁止旧 A→B 任务；须显式恢复请求才允许切回。'
            ;;
        3)
            echo '[预览] B 继续生产 → A 隔离恢复 → B→A 两通道追平 → 连续健康观察 → B 写屏障 → 最终一致性 → 隔离 B → 提升 A → 健康/DNS → B 热备。'
            ;;
        4|5) show_c_status; echo '仅显示 C 快照；无可信数据不推断进度或一致性。' ;;
        6) echo '[预览] 仅 REQUEST_PENDING 且无任何副作用意图/执行记录、worker 未启动时可取消；其他阶段必须安全暂停、对账，不能直接回滚。' ;;
        0) exit 0 ;;
        *) echo '输入错误，请输入 0—6。'; continue ;;
    esac
    echo '当前只提供离线预览，未创建、执行或取消任何真实任务。'
    printf '按回车继续...'
    IFS= read -r choice || exit 0
done

@@ABC_END

@@ABC_FILE scripts/monitor.sh 700 bf6b7c55c94054e782a0ca8634f3b609d0811ad4b61ad26ec8c0c0aad29b95b5
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
require_commands python3 || exit 1
case "${1:-}" in
    --dry-run) echo '[Dry-run] 只读监控计划；未执行任何业务操作，不采集、不写快照、不启动任务。'; exit 0 ;;
    --once|--worker|--show|--history|--interval)
        [[ $# -le 2 ]] || exit 2
        if [[ $1 == --interval && $# != 2 ]]; then die '请提供间隔秒数'; exit 2; fi
        exec python3 "$PROJECT_DIR/modules/monitor_engine.py" "$@" ;;
    --enable|--disable|--service-status)
        [[ $# == 1 ]] || exit 2
        exec bash "$PROJECT_DIR/scripts/monitor_service.sh" "$1" ;;
    '') ;;
    *) die '未知模块参数'; exit 2 ;;
esac
while true; do
    if [[ -t 1 && ${TERM:-dumb} != dumb ]]; then printf '\033[2J\033[H'; fi
    echo '========================================'
    echo '       C 节点独立监控 A、B'
    echo '========================================'
    echo
    echo '1. 检查 A 服务器状态'
    echo '2. 检查 B 服务器状态'
    echo '3. 检查 A/B MySQL 状态'
    echo '4. 检查 MySQL 主从复制状态'
    echo '5. 检查网站文件同步状态'
    echo '6. 查看全部监控结果'
    echo '7. 查看监控历史记录'
    echo '8. 配置监控检查间隔'
    echo '------------------------'
    echo '0. 返回主菜单'
    echo '------------------------'
    printf '请输入编号：'
    IFS= read -r choice || { echo '未执行任何业务操作。'; exit 3; }
    category=all
    case "$choice" in
        1|2|3|4|5|6)
            case "$choice" in 1) category=A ;; 2) category=B ;; 3) category=mysql ;; 4) category=replication ;; 5) category=files ;; esac
            # 一次完整采集保持统一快照；展示时只选本项，A/B 不相互推断。
            python3 "$PROJECT_DIR/modules/monitor_engine.py" --once >/dev/null || handle_error "$?"
            python3 "$PROJECT_DIR/modules/monitor_engine.py" --show "$category" || handle_error "$?"
            ;;
        7)
            printf '历史分类 [all/A/B/mysql/replication/files/worker，回车 all]：'
            IFS= read -r category || exit 0
            category=${category:-all}
            case "$category" in all|A|B|mysql|replication|files|worker) python3 "$PROJECT_DIR/modules/monitor_engine.py" --history "$category" || handle_error "$?" ;; *) echo '分类不合法' ;; esac
            ;;
        8)
            printf '检查间隔（5—3600 秒，0 取消）：'
            IFS= read -r seconds || exit 0
            if [[ $seconds != 0 ]]; then
                printf '将仅更新监控间隔与有效期，不改其他配置。输入小写 yes 确认：'
                IFS= read -r answer || exit 0
                if [[ $answer == yes ]]; then
                    python3 "$PROJECT_DIR/modules/monitor_engine.py" --interval "$seconds" || handle_error "$?"
                    echo 'C 角色已配置后，可用 scripts/monitor.sh --enable 显式启用唯一 systemd 后台任务。'
                else echo '已取消'; fi
            fi
            ;;
        0) echo '未执行任何业务操作。'; exit 0 ;;
        *) echo '输入错误，请输入 0—8。'; continue ;;
    esac
    printf '按回车继续...'
    IFS= read -r choice || exit 0
done

@@ABC_END

@@ABC_FILE scripts/monitor_service.sh 700 1d5aad1313cd65472cdb9c238cca520e8ebec517be9fc49faade2e9d3a23ea2c
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
bootstrap || exit 1
require_commands python3 systemctl || exit 1
[[ $NODE_ROLE == C ]] || { die '仅已配置 C 节点允许管理后台监控'; exit 1; }
[[ $PROJECT_DIR =~ ^/[A-Za-z0-9_./-]+$ ]] || { die 'systemd 项目路径暂不支持空格和特殊字符'; exit 1; }
unit="abc-monitor-$(printf '%s' "$PROJECT_DIR" | sha256sum | cut -c1-12).service"
case "${1:-}" in
    --service-status) exec systemctl status "$unit" --no-pager ;;
    --enable|--disable)
        printf '仅%s项目只读监控服务 %s，不操作业务服务。输入小写 yes 确认：' "$1" "$unit"
        IFS= read -r answer || exit 1
        [[ $answer == yes ]] || exit 1
        ;;
    *) exit 2 ;;
esac
if [[ $1 == --disable ]]; then systemctl disable --now "$unit"; exit "$?"; fi
python3 - "$PROJECT_DIR" "$unit" <<'PY' || exit 1
from pathlib import Path
import os
import sys
root=Path(sys.argv[1]); name=sys.argv[2]
target=root/'systemd'/name
text='''[Unit]
Description=A-B-C read-only C monitor
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=5
[Service]
Type=simple
ExecStart=/bin/bash ROOT/scripts/monitor.sh --worker
WorkingDirectory=ROOT
Restart=on-failure
RestartSec=5
UMask=0077
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=ROOT
PrivateTmp=true
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=multi-user.target
'''.replace('ROOT',str(root))
if target.is_symlink(): raise SystemExit('不安全 unit 链接')
if not target.exists() or target.read_text()!=text:
    fd=os.open(target,os.O_CREAT|os.O_WRONLY|os.O_TRUNC|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'w') as f: f.write(text)
PY
systemd-analyze verify "$PROJECT_DIR/systemd/$unit" || exit 1
systemctl link "$PROJECT_DIR/systemd/$unit" || exit 1
systemctl daemon-reload || exit 1
systemctl enable --now "$unit" || exit 1
systemctl is-enabled "$unit" && systemctl is-active "$unit"

@@ABC_END

@@ABC_FILE scripts/mysql_primary.sh 700 f3d2a7b905219a52174b1b1ce6a1782a0c7b587aa0dd9cdc95fd663f783a0f3e
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知模块参数'; exit 2; }
blocked_module 'MySQL Binlog Primary 配置'

@@ABC_END

@@ABC_FILE scripts/mysql_replica.sh 700 7f9b30f5e9b3b152d033263025060bc8db9a7c85087f3f60e591d29fa39681df
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知模块参数'; exit 2; }
blocked_module 'MySQL Replica 初始化'

@@ABC_END

@@ABC_FILE scripts/mysql_status.sh 700 c812c7d1d8910d0fca609040f19103022b13a0810ead663c00a53cf4ea5fe316
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知模块参数'; exit 2; }
blocked_module 'MySQL 实时复制状态查询'

@@ABC_END

@@ABC_FILE scripts/recovery.sh 700 a779a7af27f4053580596e3b353156499ed895d26ab3060273f3dedf49b472f5
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知模块参数'; exit 2; }
blocked_module '恢复与人工切回'

@@ABC_END

@@ABC_FILE scripts/server_a.sh 700 b7df1498d97e8f320f61cf604493cea90693de950114a0dde8d0260b326525ed
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知模块参数'; exit 2; }
blocked_module 'A VPS 主服务器配置'

@@ABC_END

@@ABC_FILE scripts/server_b.sh 700 d6881669213d2f323b22c156216f7d52667789fbe9e1725fac4407a9b78da26a
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知模块参数'; exit 2; }
blocked_module 'B VPS 备用服务器配置'

@@ABC_END

@@ABC_FILE scripts/sync_files.sh 700 9db7d0d8c2a233ba02698e8f64fa6f3b07b56dda27dead2a6fefbb26af0d9baa
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知模块参数'; exit 2; }
blocked_module 'SSH + Rsync 网站文件同步'

@@ABC_END

@@ABC_FILE scripts/uninstall.sh 700 6a01d14f2ceeac9a38d5bc57952c19489610b91414f3ce5ea4103b9161ae1a58
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知模块参数'; exit 2; }
blocked_module '安全卸载（第一阶段禁止自动删除；后续实现依赖检查与精确确认）'

@@ABC_END

@@ABC_FILE tests/test_architecture.py 600 a9bd08ec0174aa9d2bc1f17f8fd4a387236173d3200e0beac9d2d7db2376402d
#!/usr/bin/env python3
"""Offline state policy and security regressions; reuse unmodified isolation harness."""
import subprocess
import unittest
from test_framework import FrameworkTests


class ArchitectureTests(FrameworkTests):
    def plan(self, *args):
        return self.run_cli(*args, script='scripts/coordinator_plan.sh')

    def test_all_edges_and_each_missing_guard(self):
        states = ('NORMAL_A SUSPECT_A A_FENCED B_DRAINED B_PRIMARY B_HEALTHY ACTIVE_B '
                  'RECOVERY_PREFLIGHT A_REPLICA A_CATCHING_UP A_STABLE B_QUIESCED '
                  'FINAL_VERIFIED B_FENCED A_PRIMARY A_HEALTHY DNS_A_VERIFIED B_REPLICA').split()
        for state in states:
            edge = self.plan('--edge', state)
            self.assertEqual(edge.returncode, 0, edge.stderr)
            facts = edge.stdout.split('required=')[1].strip().split()
            result = self.plan('--simulate', state, *facts)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertNotIn('MANUAL_REQUIRED', result.stdout)
            for missing in facts:
                result = self.plan('--simulate', state, *(f for f in facts if f != missing))
                self.assertEqual(result.returncode, 4, f'{state}: {missing}')
                self.assertIn('MANUAL_REQUIRED', result.stdout)

    def test_direction_guards(self):
        self.assertIn('A_TO_B', self.plan('--direction', 'NORMAL_A').stdout)
        self.assertIn('禁止写入 A', self.plan('--direction', 'NORMAL_A').stdout)
        for state in ('A_REPLICA', 'A_CATCHING_UP', 'A_STABLE'):
            self.assertIn('B_TO_A', self.plan('--direction', state).stdout)
        for state in ('ACTIVE_B', 'RECOVERY_PREFLIGHT', 'B_QUIESCED', 'A_PRIMARY', 'MANUAL_REQUIRED'):
            self.assertIn('NONE', self.plan('--direction', state).stdout)

    def test_unknown_duplicate_and_manual_pause(self):
        self.assertEqual(self.plan('--simulate', 'UNKNOWN').returncode, 2)
        self.assertEqual(self.plan('--simulate', 'NORMAL_A', 'fake').returncode, 2)
        self.assertEqual(self.plan('--simulate', 'NORMAL_A', 'a_failed_repeated', 'a_failed_repeated').returncode, 2)
        self.assertEqual(self.plan('--simulate', 'MANUAL_REQUIRED', 'operator_reconcile_required').returncode, 4)
        self.assertEqual(self.plan('--execute').returncode, 2)

    def test_policy_no_writes_and_safe_defaults(self):
        before = self.snapshot()
        result = self.plan('--policy')
        for value in ('AUTO_FAILOVER_ENABLED=false', 'AUTO_RECOVERY_ENABLED=false',
                      'AUTO_FAILBACK_ENABLED=false', 'RECOVERY_STABLE_MINUTES=20',
                      'SYNC_DIRECTION_LOCK=true', 'SINGLE_PRIMARY_ENFORCED=true', 'POLICY_DRY_RUN=true'):
            self.assertIn(value, result.stdout)
        self.plan('--simulate', 'NORMAL_A')
        self.assertEqual(before, self.snapshot())

    def test_optional_config_values_block_activation(self):
        original = self.conf.read_text()
        for text in ('AUTO_FAILOVER_ENABLED="true"', 'AUTO_RECOVERY_ENABLED="true"',
                     'AUTO_FAILBACK_ENABLED="true"', 'POLICY_DRY_RUN="false"',
                     'SYNC_DIRECTION_LOCK="false"', 'SINGLE_PRIMARY_ENFORCED="false"',
                     'RECOVERY_SYNC_RETRY="0"', 'RECOVERY_STABLE_MINUTES="-1"'):
            self.conf.write_text(original + '\n' + text + '\n')
            self.assertNotEqual(self.plan('--policy').returncode, 0)
        self.conf.write_text(original + '\nRECOVERY_STABLE_MINUTES="25"\n')
        self.assertIn('RECOVERY_STABLE_MINUTES=25', self.plan('--policy').stdout)

    def test_hardlink_and_fifo_log_rejected(self):
        import os
        target = self.base / 'external'
        target.write_text('protected')
        target.chmod(0o600)
        log = self.root / 'logs/framework.log'
        os.link(target, log)
        self.assertNotEqual(self.run_cli('--status').returncode, 0)
        self.assertEqual(target.read_text(), 'protected')
        log.unlink()
        os.mkfifo(log, 0o600)
        self.assertNotEqual(self.run_cli('--status').returncode, 0)
        self.assertNotEqual(self.run_cli('--logs').returncode, 0)

    def test_install_hardlink_lock_not_truncated(self):
        import os
        target = self.base / 'external'
        target.write_text('protected')
        target.chmod(0o600)
        os.link(target, self.root / 'data/install.lock')
        self.assertNotEqual(self.run_cli('--install').returncode, 0)
        self.assertEqual(target.read_text(), 'protected')


if __name__ == '__main__':
    # Only new tests here; original suite is executed separately without modification.
    names = [name for name in ArchitectureTests.__dict__ if name.startswith('test_')]
    suite = unittest.TestSuite(ArchitectureTests(name) for name in sorted(names))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(not result.wasSuccessful())

@@ABC_END

@@ABC_FILE tests/test_colors.py 600 55fdca32ae39cce2a9bbc992939f15b2d740c958ffb3ae5c80f521ec5d67f2d1
#!/usr/bin/env python3
import importlib.util
import os
from pathlib import Path
import pty
import subprocess
import unittest
from unittest.mock import patch
from test_manual import sample, view
ROOT=Path(__file__).resolve().parents[1]

class ColorTests(unittest.TestCase):
    def test_values_and_reset(self):
        with patch.dict(os.environ, {}, clear=True):
            unknown=view.render(None,1000,True)
            self.assertIn('节点 A：\033[31m暂无\033[0m（状态缺失、过期或无法确认）',unknown)
            self.assertNotIn('\033[31m节点',unknown)
            text=view.render(sample(),1000,True)
            for expected in ('当前生产主站：\033[32mA\033[0m','当前备用节点：\033[33mB\033[0m','当前同步方向：\033[34mA → B\033[0m','服务器在线：\033[32m正常\033[0m'):
                self.assertIn(expected,text)
            self.assertIn('复制延迟：0 秒',text)
            data=sample();data['nodes']['A']['status']='unconfigured'
            self.assertIn('节点 A：\033[90m未配置\033[0m（',view.render(data,1000,True))
    def test_no_color_and_redirect(self):
        with patch.dict(os.environ,NO_COLOR=''):
            self.assertNotIn('\033',view.render(sample(),1000,True))
        result=subprocess.run(['python3',str(ROOT/'modules/status_view.py')],capture_output=True,text=True)
        self.assertNotIn('\033',result.stdout)
    def test_real_pty_and_no_color(self):
        for disabled in (False,True):
            master,slave=pty.openpty()
            env=dict(os.environ,TERM='xterm');env.pop('NO_COLOR',None)
            if disabled:env['NO_COLOR']='1'
            process=subprocess.Popen(['python3',str(ROOT/'modules/status_view.py')],stdout=slave,env=env)
            os.close(slave);output=b''
            try:
                while True:
                    try:chunk=os.read(master,4096)
                    except OSError:break
                    if not chunk:break
                    output+=chunk
            finally:os.close(master)
            self.assertEqual(process.wait(),0)
            self.assertEqual(b'\033[31m' in output,not disabled)
            if not disabled:self.assertIn('节点 A：\033[31m暂无\033[0m（'.encode(),output)

if __name__=='__main__':unittest.main(verbosity=2)

@@ABC_END

@@ABC_FILE tests/test_distribution.py 600 c0c56db1edb4a95c6aeb9acd3f31a9f47311bf7586b16b51cae8e4d636da780f
import subprocess
from pathlib import Path
import uuid
root=Path('/home/a-b-c-MySQL')
logs=[]
def run(cmd, text=None):
    p=subprocess.run(cmd,input=text,text=True,capture_output=True,timeout=300)
    logs.append('$ '+' '.join(cmd)+'\n'+p.stdout+p.stderr+f'\nexit={p.returncode}')
    if p.returncode:
        (root/'data/distribution-verification.txt').write_text('\n'.join(logs))
        raise RuntimeError(logs[-1])
    return p.stdout
for version in ('12','13'):
    name='abc-bootstrap-'+version+'-'+uuid.uuid4().hex[:8]
    run(['docker','create','--name',name,'-i','debian:'+version+'-slim','sleep','infinity'])
    try:
        run(['docker','start',name])
        run(['docker','cp','/root/yingyong/a-b-c-MySQL.sh',name+':/root/portable.sh'])
        # Fresh official slim container: no /home project, no mounted host directories.
        run(['docker','exec',name,'bash','-c','test ! -e /home/a-b-c-MySQL; test ! -e /root/yingyong; mkdir -m 700 /root/scratch; command -v python3 || true'])
        run(['docker','exec','-i',name,'bash','/root/portable.sh','--project-dir','/opt/abc-custom','--initialize','--no-menu'], 'yes\nyes\n')
        run(['docker','exec',name,'bash','-c','cd /; bash /root/portable.sh --verify'])
        run(['docker','exec','-i',name,'bash','-c','cd /var; bash /root/portable.sh --dry-run'], '0\n')
        run(['docker','exec',name,'bash','-c','cp /root/portable.sh /root/renamed.sh; cd /; bash /root/renamed.sh --project-dir /opt/abc-custom --verify'])
        run(['docker','exec',name,'bash','-c','sha256sum /opt/abc-custom/config/config.env > /root/before; printf "broken" > /opt/abc-custom/scripts/server_a.sh; if bash /root/portable.sh --verify; then exit 8; fi'])
        run(['docker','exec','-i',name,'bash','/root/portable.sh','--repair','--no-menu'], 'yes\n')
        run(['docker','exec',name,'bash','-c','sha256sum /opt/abc-custom/config/config.env > /root/after; cmp /root/before /root/after; bash /root/portable.sh --verify'])
        # Tests use private scratch inside each container, not system /tmp.
        for test in ('test_framework.py','test_architecture.py','test_manual.py','test_menu_layout.py'):
            run(['docker','exec','-e','TMPDIR=/root/scratch',name,'python3','/opt/abc-custom/tests/'+test])
        run(['docker','exec',name,'bash','-c','bash /root/portable.sh --project-dir /opt/no-create --initialize --dry-run; test ! -e /opt/no-create'])
        print('Debian',version,'PASS: fresh install, arbitrary CWD, renamed entry, verify, corruption refusal, repair preserving config, all existing tests, dry-run')
    finally:
        run(['docker','rm','-f',name])
(root/'data/distribution-verification.txt').write_text('\n'.join(logs))

@@ABC_END

@@ABC_FILE tests/test_framework.py 600 70c31b79eadaae8c656e6a9ba54e57167539c1747c855da842666ad5c3c6219c
#!/usr/bin/env python3
"""Stage-one tests: isolated copy, no network or business operations."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]
SCRATCH = Path(os.environ.get('TMPDIR', '/root/.hermes/cache/scratch'))


class FrameworkTests(unittest.TestCase):
    def setUp(self):
        self.base = Path(tempfile.mkdtemp(prefix='abc-test-', dir=SCRATCH))
        self.root = self.base / 'project'
        shutil.copytree(SOURCE, self.root)
        for folder in ('data', 'logs', 'tmp'):
            shutil.rmtree(self.root / folder)
            (self.root / folder).mkdir(mode=0o700)
        self.conf = self.root / 'config/config.env'
        self.conf.write_text(self.conf.read_text().replace(str(SOURCE), str(self.root)))
        self.conf.chmod(0o600)
        self.spy = self.base / 'spy'
        self.spy.mkdir()
        # Mutating integration tools must never be called in stage one.
        for cmd in ('rsync', 'mysql', 'mariadb', 'wg', 'wg-quick', 'ssh', 'curl',
                    'systemctl', 'crontab', 'service', 'apt', 'apt-get'):
            script = self.spy / cmd
            script.write_text('#!/bin/sh\nprintf "%s\\n" "$0" >> "$ABC_CALLS"\nexit 97\n')
            script.chmod(0o700)
        self.calls = self.base / 'calls'
        self.env = dict(os.environ, PATH=f'{self.spy}:{os.environ["PATH"]}',
                        ABC_CALLS=str(self.calls), TERM='dumb')

    def tearDown(self):
        try:
            self.assertFalse(self.calls.exists(), 'unexpected business/network tool call')
        finally:
            shutil.rmtree(self.base)

    def run_cli(self, *args, text='', script='a-b-c-MySQL.sh'):
        return subprocess.run(['bash', str(self.root / script), *args], input=text,
                              text=True, capture_output=True, env=self.env, timeout=15)

    def config_replace(self, old, new):
        data = self.conf.read_text()
        self.assertIn(old, data)
        self.conf.write_text(data.replace(old, new))

    def snapshot(self):
        return {str(p.relative_to(self.root)): (p.stat().st_mode, hashlib.sha256(p.read_bytes()).hexdigest())
                for p in self.root.rglob('*') if p.is_file()}

    def test_menu_and_exit(self):
        result = self.run_cli(text='0\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        for row in ('1. Cloudflare', '2. A VPS', '3. B VPS', '4. MySQL',
                    '5. MySQL', '6. SSH', '7. C 节点', '8. 自动', '0. 退出'):
            self.assertIn(row, result.stdout)
        self.assertIn('已退出', result.stdout)

    def test_submenu_return_no_pause(self):
        result = self.run_cli(text='4\n0\n0\n')
        self.assertEqual(result.returncode, 0)
        self.assertIn('1. Rsync + SSH', result.stdout)
        self.assertIn('2. WireGuard', result.stdout)
        self.assertNotIn('按回车继续', result.stdout)

    def test_invalid_and_eof(self):
        for text in ('bad\n0\n', '', '4\nwrong\n0\n0\n'):
            self.assertEqual(self.run_cli(text=text).returncode, 0)

    def test_all_menu_branches(self):
        for number in (1, 2, 3, 5, 6, 7, 8):
            result = self.run_cli(text=f'{number}\n\n0\n')
            self.assertEqual(result.returncode, 0)
            self.assertIn('未执行任何业务操作', result.stdout)
        for number in (1, 2):
            result = self.run_cli(text=f'4\n{number}\n\n0\n0\n')
            self.assertIn('未执行任何业务操作', result.stdout)

    def test_wrappers_and_unknown_parameters(self):
        for name in ('cloudflare', 'server_a', 'server_b', 'mysql_primary', 'mysql_replica',
                     'mysql_status', 'sync_files', 'monitor', 'failover', 'recovery',
                     'dns_switch', 'uninstall'):
            self.assertEqual(self.run_cli(script=f'scripts/{name}.sh').returncode, 3)
            self.assertEqual(self.run_cli('--dry-run', script=f'scripts/{name}.sh').returncode, 0)
            self.assertEqual(self.run_cli('--unsafe', script=f'scripts/{name}.sh').returncode, 2)
        self.assertEqual(self.run_cli('--unsafe').returncode, 2)

    def test_dry_run_no_project_writes(self):
        before = self.snapshot()
        for args in (('--install', '--dry-run'), ('--status', '--dry-run'),
                     ('--uninstall', '--dry-run'), ('--dry-run',)):
            result = self.run_cli(*args, text='6\n\n0\n')
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(before, self.snapshot())

    def test_repeated_install_preserves_config(self):
        before = self.conf.read_bytes()
        self.assertEqual(self.run_cli('--install').returncode, 0)
        state = (self.root / 'data/framework.version').read_bytes()
        result = self.run_cli('--install')
        self.assertEqual(result.returncode, 0)
        self.assertIn('不重复创建任务', result.stdout)
        self.assertEqual(before, self.conf.read_bytes())
        self.assertEqual(state, (self.root / 'data/framework.version').read_bytes())

    def test_config_not_executed(self):
        sentinel = self.base / 'injected'
        self.config_replace('MYSQL_PASSWORD=""', f'MYSQL_PASSWORD="$(touch {sentinel})"')
        result = self.run_cli('--status')
        self.assertEqual(result.returncode, 0)
        self.assertFalse(sentinel.exists())
        self.assertNotIn('touch', result.stdout + result.stderr)

    def test_config_mode_rejected(self):
        self.conf.chmod(0o644)
        self.assertNotEqual(self.run_cli('--status').returncode, 0)

    def test_config_missing_duplicate_unknown_and_syntax(self):
        original = self.conf.read_text()
        for text in (original.replace('MYSQL_PORT="3306"\n', ''),
                     original + 'MYSQL_PORT="3306"\n',
                     original + 'UNTRUSTED="x"\n',
                     original + 'touch /not-allowed\n'):
            self.conf.write_text(text)
            self.assertNotEqual(self.run_cli('--status').returncode, 0)

    def test_invalid_values(self):
        original = self.conf.read_text()
        for old, new in (('SSH_PORT="22"', 'SSH_PORT="99999"'),
                         ('LOG_KEEP="5"', 'LOG_KEEP="21"'),
                         ('AUTO_FAILOVER="false"', 'AUTO_FAILOVER="true"'),
                         ('SYNC_EXCLUDES="log,mysql,redis"', 'SYNC_EXCLUDES="log,mysql,redis,beifen"')):
            self.conf.write_text(original.replace(old, new))
            self.assertNotEqual(self.run_cli('--status').returncode, 0)

    def test_persistent_redis_warning(self):
        self.config_replace('REDIS_USAGE="UNCONFIRMED"', 'REDIS_USAGE="PERSISTENT"')
        result = self.run_cli('--status')
        self.assertIn('必须制定独立容灾方案', result.stdout)

    def test_sync_scope(self):
        result = self.run_cli('--status')
        self.assertIn('包含 beifen/ 和未来新增普通目录', result.stdout)
        self.assertIn('唯一指定排除：/home/web/log/ /home/web/mysql/ /home/web/redis/', result.stdout)

    def test_runtime_directory_recreation(self):
        shutil.rmtree(self.root / 'logs')
        self.assertEqual(self.run_cli('--status').returncode, 0)
        self.assertTrue((self.root / 'logs').is_dir())
        self.assertEqual((self.root / 'logs').stat().st_mode & 0o777, 0o700)

    def test_dry_run_missing_directory_does_not_create(self):
        shutil.rmtree(self.root / 'tmp')
        self.assertNotEqual(self.run_cli('--status', '--dry-run').returncode, 0)
        self.assertFalse((self.root / 'tmp').exists())

    def test_symlinks_rejected(self):
        self.conf.unlink()
        self.conf.symlink_to(SOURCE / 'config/config.env')
        self.assertNotEqual(self.run_cli('--status').returncode, 0)

    def test_logging_rotation_and_secret_absence(self):
        self.config_replace('LOG_MAX_BYTES="1048576"', 'LOG_MAX_BYTES="128"')
        self.config_replace('LOG_KEEP="5"', 'LOG_KEEP="2"')
        self.config_replace('MYSQL_PASSWORD=""', 'MYSQL_PASSWORD="SENSITIVE_SENTINEL"')
        for _ in range(12):
            self.assertEqual(self.run_cli('--status').returncode, 0)
        logs = list((self.root / 'logs').glob('framework.log*'))
        self.assertEqual(len(logs), 3)
        for path in logs:
            self.assertNotIn('SENSITIVE_SENTINEL', path.read_text())
            self.assertLessEqual(path.stat().st_size, 128)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_concurrent_logging(self):
        processes = [subprocess.Popen(['bash', str(self.root / 'a-b-c-MySQL.sh'), '--status'],
                     stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, env=self.env) for _ in range(8)]
        for process in processes:
            _, err = process.communicate(timeout=15)
            self.assertEqual(process.returncode, 0, err)
        self.assertEqual(len((self.root / 'logs/framework.log').read_text().splitlines()), 8)

    def test_install_lock_and_state_version(self):
        lock = open(self.root / 'data/install.lock', 'w')
        import fcntl
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            self.assertNotEqual(self.run_cli('--install').returncode, 0)
        finally:
            lock.close()
        (self.root / 'data/framework.version').write_text('unknown\n')
        self.assertNotEqual(self.run_cli('--install').returncode, 0)
        self.assertEqual((self.root / 'data/framework.version').read_text(), 'unknown\n')

    def test_log_symlink_rejected(self):
        target = self.base / 'protected'
        target.write_text('unchanged')
        (self.root / 'logs/framework.log').symlink_to(target)
        self.assertNotEqual(self.run_cli('--status').returncode, 0)
        self.assertEqual(target.read_text(), 'unchanged')


if __name__ == '__main__':
    unittest.main(verbosity=2)

@@ABC_END

@@ABC_FILE tests/test_manual.py 600 6c8ab9ded76d0289700cc4406dd7f9cde327568a27bfd115af89ca8d37746848
#!/usr/bin/env python3
"""Manual maintenance offline regressions; no real C snapshot is written."""
import importlib.util
import unittest
import re

def plain(text):
    return re.sub(r'\x1b\[[0-9;]*m', '', text)
from test_framework import FrameworkTests, SOURCE
spec = importlib.util.spec_from_file_location('status_view', SOURCE / 'modules/status_view.py')
view = importlib.util.module_from_spec(spec)
spec.loader.exec_module(view)


def sample(now=1000):
    return dict(schema=1, source='C', collector_ok=True, identity_verified=True,
                checked_at=now, last_success_at=now, primary='A', single_primary_verified=True,
                direction='A_TO_B', operation_id=None,
                nodes={k: dict(checked_at=now, online='ok', business='ok') for k in 'ABC'},
                database=dict(checked_at=now, health='ok', integrity='ok', lag_seconds=0),
                files=dict(checked_at=now, health='ok', integrity='ok', last_success_at=now))


class ManualTests(FrameworkTests):
    def plan(self, *args):
        return self.run_cli(*args, script='scripts/coordinator_plan.sh')

    def test_manual_edges_missing_conditions(self):
        for state in ('PLAN_REQUESTED', 'PLAN_PREFLIGHT', 'PLAN_A_QUIESCED',
                      'PLAN_FINAL_VERIFIED', 'MAINTENANCE_B', 'REQUEST_PENDING'):
            facts = self.plan('--edge', state).stdout.split('required=')[1].strip().split()
            self.assertEqual(self.plan('--simulate', state, *facts).returncode, 0)
            for fact in facts:
                self.assertEqual(self.plan('--simulate', state, *(f for f in facts if f != fact)).returncode, 4)

    def test_conflict_cancel_and_unknown_outcome(self):
        facts = self.plan('--edge', 'PLAN_REQUESTED').stdout.split('required=')[1].split()
        self.assertEqual(self.plan('--simulate', 'PLAN_REQUESTED', *(f for f in facts if f != 'no_active_operation')).returncode, 4)
        facts = self.plan('--edge', 'REQUEST_PENDING').stdout.split('required=')[1].split()
        for guard in ('no_side_effect_intent', 'no_side_effect_result', 'worker_not_started'):
            self.assertEqual(self.plan('--simulate', 'REQUEST_PENDING', *(f for f in facts if f != guard)).returncode, 4)
        self.assertEqual(self.plan('--simulate', 'MANUAL_REQUIRED', 'operator_reconcile_required').returncode, 4)
        self.assertEqual(self.plan('--simulate', 'A_PRIMARY').returncode, 4)

    def test_menu_nine_and_all_actions_no_writes(self):
        before = self.snapshot()
        for choice in range(1, 7):
            result = self.run_cli('--dry-run', text=f'9\n{choice}\n\n0\n0\n')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('未创建、执行或取消任何真实任务', result.stdout)
        result = self.run_cli('--dry-run', text='9\n0\n0\n')
        self.assertNotIn('按回车继续', result.stdout)
        self.assertIn('9. 手动切换与计划维护', result.stdout)
        self.assertIn('当前生产主站：暂无', result.stdout)
        self.assertEqual(before, self.snapshot())

    def test_absent_stale_and_future_never_green(self):
        for data in (None, {}, sample(900), sample(1001)):
            text = view.render(data, 1000, True)
            self.assertNotIn('\033[32m', text)
            self.assertIn('当前生产主站：暂无', plain(text))
        data = sample(); data['collector_ok'] = False
        self.assertNotIn('\033[32m', view.render(data, 1000, True))

    def test_independent_channel_and_node_expiry(self):
        data = sample()
        data['nodes']['B']['checked_at'] = 900
        data['files']['checked_at'] = 900
        data['database']['lag_seconds'] = None
        text = view.render(data, 1000, True)
        self.assertIn('节点 B：暂无', plain(text))
        self.assertIn('文件同步状态：暂无', plain(text))
        self.assertIn('数据库 / 通道状态：正常', plain(text))
        self.assertIn('复制延迟：暂无', plain(text))
        self.assertIn('\033[32m', text)
        self.assertIn('\033[31m', text)

    def test_direction_identity_and_terminal_safety(self):
        data = sample(); data['direction'] = 'B_TO_A'
        data['operation_id'] = '\033[2J'
        text = view.render(data, 1000)
        self.assertIn('方向冲突', text)
        self.assertNotIn('\033', text)
        data['identity_verified'] = False
        self.assertNotIn('正常', view.render(data, 1000))

    def test_color_and_plain_output(self):
        self.assertNotIn('\033', view.render(sample(), 1000))
        text = view.render(sample(), 1000, True)
        for code in ('\033[31m', '\033[32m', '\033[33m'):
            self.assertIn(code, text)


if __name__ == '__main__':
    suite = unittest.TestSuite(ManualTests(name) for name in sorted(ManualTests.__dict__) if name.startswith('test_'))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(not result.wasSuccessful())

@@ABC_END

@@ABC_FILE tests/test_menu_layout.py 600 2c0f50267244ecafc9f35b1a0621b82039d2a7a8fc3378d7996bde71bbb00711
#!/usr/bin/env python3
"""Exact missing-snapshot main-menu layout, isolated from business services."""
import unittest
from test_framework import FrameworkTests


class LayoutTests(FrameworkTests):
    def expected(self):
        return f'''========================================
       A-B-C MySQL 主备容灾管理系统
========================================
实时节点状态：
节点 A：暂无（状态缺失、过期或无法确认）
节点 B：暂无（状态缺失、过期或无法确认）
监控 C：暂无（状态缺失、过期或无法确认）
========================================
当前生产主站：暂无
当前备用节点：暂无
当前同步方向：暂无
当前切换任务：暂无
数据库状态：暂无
文件同步状态：暂无
数据同步时间：暂无
复制延迟：暂无
最后一次成功检查时间：暂无
------------------------
项目目录：{self.root}
离线架构阶段：业务操作未启用
========================================
1. Cloudflare 免费 DNS 配置
2. A VPS 主服务器配置
3. B VPS 备用服务器配置
4. MySQL 主从复制通信方式
5. MySQL Binlog 主从复制配置
6. SSH + Rsync 网站文件同步
7. C 节点独立监控 A、B
8. 自动故障切换与恢复脚本
9. 手动切换与计划维护
------------------------
0. 退出程序
------------------------
请输入编号：'''

    def test_exact_layout_and_dry_run(self):
        for args in ((), ('--dry-run',)):
            result = self.run_cli(*args, text='0\n')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, self.expected() + '已退出\n')
            self.assertNotIn('\033', result.stdout)

    def test_stage_not_static_when_capabilities_change(self):
        (self.root / 'data/deployment.json').write_text('{}')
        result = self.run_cli('--dry-run', text='0\n')
        self.assertIn('部署阶段待核验：业务启用状态无法确认', result.stdout)
        self.assertNotIn('离线架构阶段：业务操作未启用', result.stdout)
        self.assertNotIn('：正常', result.stdout)

    def test_missing_stage_files_not_offline_claim(self):
        (self.root / 'scripts/coordinator_plan.sh').unlink()
        result = self.run_cli('--dry-run', text='0\n')
        self.assertIn('项目阶段：暂无', result.stdout)
        self.assertNotIn('离线架构阶段：业务操作未启用', result.stdout)


if __name__ == '__main__':
    suite = unittest.TestSuite(LayoutTests(name) for name in sorted(LayoutTests.__dict__) if name.startswith('test_'))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(not result.wasSuccessful())

@@ABC_END

@@ABC_FILE tests/test_monitor.py 600 1fcb948dc22c91af4b8e11f4afe4a58a4b3a201f18589d6ebe83570131038ee8
#!/usr/bin/env python3
"""Monitor fault tests: isolated C copy, SSH transport boundary stub, no production writes."""
import json
import os
import subprocess
import time
import unittest
from test_framework import FrameworkTests


class MonitorTests(FrameworkTests):
    def setup_c(self):
        self.config_replace('NODE_ROLE="UNASSIGNED"', 'NODE_ROLE="C"')
        for name in ('key', 'known'):
            (self.base/name).write_text('test'); (self.base/name).chmod(0o600)
        with self.conf.open('a') as f:
            f.write(f'\nMONITOR_SSH_KEY="{self.base}/key"\nMONITOR_KNOWN_HOSTS="{self.base}/known"\n')
            for n, ip in (('A','192.0.2.1'),('B','192.0.2.2')):
                f.write(f'{n}_EXPECTED_MACHINE_ID="{"a"*32}"\n')
        self.config_replace('A_PUBLIC_IP=""','A_PUBLIC_IP="192.0.2.1"')
        self.config_replace('B_PUBLIC_IP=""','B_PUBLIC_IP="192.0.2.2"')
        self.mode = self.base/'mode'; self.mode.write_text('normal')
        ssh = self.spy/'ssh'
        ssh.write_text('''#!/usr/bin/env python3
import json,os,sys
mode=open(os.environ['ABC_MODE']).read()
is_a=any('192.0.2.1' in s for s in sys.argv)
if mode=='ssh' or mode=='A_off' and is_a or mode=='B_off' and not is_a: sys.exit(255)
r=dict(machine_id='a'*32,server=dict(status='ok',reason='',cpu_percent=12,memory_kib={'MemTotal':1000},load=[0.1],network_summary='ss'),mysql=dict(status='error' if mode=='mysql_stop' else 'ok',reason='服务停止' if mode=='mysql_stop' else '',product='MariaDB',version='10.11'),replication=dict(status='error' if mode=='sql_error' else 'ok',reason='SQL错误' if mode=='sql_error' else '',role='Replica',io='Yes',sql='No' if mode=='sql_error' else 'Yes',lag_seconds=12 if mode=='lag' else 0),rsync_process='absent')
print(json.dumps(r))
''')
        ssh.chmod(0o700)
        self.env['ABC_MODE']=str(self.mode)

    def monitor(self,*args, **kwargs):
        return self.run_cli(*args,script='scripts/monitor.sh', **kwargs)

    def test_menu_format(self):
        result=self.monitor(text='0\n')
        self.assertEqual(result.returncode,0)
        for row in ('1. 检查 A 服务器状态','8. 配置监控检查间隔','------------------------','0. 返回主菜单'):
            self.assertIn(row,result.stdout)

    def test_unconfigured_and_no_c(self):
        self.assertNotEqual(self.monitor('--once').returncode,0)
        self.config_replace('NODE_ROLE="UNASSIGNED"','NODE_ROLE="C"')
        self.assertEqual(self.monitor('--once').returncode,0)
        data=json.loads((self.root/'data/monitor-detail.json').read_text())
        self.assertEqual(data['nodes']['A']['server']['status'],'unconfigured')
        self.assertEqual(data['files']['status'],'unconfigured')

    def test_fault_matrix_and_recovery_history(self):
        self.setup_c()
        for mode in ('normal','A_off','B_off','ssh','mysql_stop','sql_error','lag'):
            self.mode.write_text(mode)
            result=self.monitor('--once'); self.assertEqual(result.returncode,0,result.stderr)
            data=json.loads((self.root/'data/monitor-detail.json').read_text())
            a=data['nodes']['A']; b=data['nodes']['B']
            if mode=='A_off': self.assertEqual(a['server']['status'],'error'); self.assertEqual(b['server']['status'],'ok')
            if mode=='B_off': self.assertEqual(b['server']['status'],'error'); self.assertEqual(a['server']['status'],'ok')
            if mode=='ssh': self.assertEqual(a['server']['status'],'error')
            if mode=='mysql_stop': self.assertEqual(a['mysql']['status'],'error')
            if mode=='sql_error': self.assertEqual(a['replication']['sql'],'No')
            if mode=='lag': self.assertEqual(a['replication']['lag_seconds'],12)
        self.mode.write_text('A_off'); self.monitor('--once')
        self.mode.write_text('normal'); self.monitor('--once')
        self.assertIn('"recovered_at": 1',self.monitor('--history','A').stdout)
        menu=self.run_cli('--dry-run',text='0\n').stdout
        self.assertIn('节点 A / 服务器在线：正常',menu)
        self.assertIn('当前生产主站：暂无',menu)

    def test_files_backlog_and_scope(self):
        self.setup_c()
        sync=dict(producer='abc-sync-worker-v1',root='/home/web/',excludes=['log','mysql','redis'],includes_beifen=True,checked_at=int(time.time()),direction='A_TO_B',result='failed',pending=1,backlog=3,process_running=False,last_success_at=None)
        p=self.root/'data/sync-status.json'; p.write_text(json.dumps(sync)); p.chmod(0o600)
        self.monitor('--once')
        self.assertIn('同步失败',self.monitor('--show','files').stdout)
        sync['excludes'].append('beifen'); p.write_text(json.dumps(sync)); self.monitor('--once')
        self.assertIn('同步范围不符合约定',self.monitor('--show','files').stdout)

    def test_corruption_expiry_and_boot(self):
        self.setup_c(); self.monitor('--once')
        path=self.root/'data/c-status.json'
        data=json.loads(path.read_text()); data['checked_at']=1; path.write_text(json.dumps(data))
        self.assertNotIn('：正常',self.run_cli('--dry-run',text='0\n').stdout)
        data['checked_at']=int(time.time()); data['collector_boot_id']='old-boot'; path.write_text(json.dumps(data))
        self.assertNotIn('：正常',self.run_cli('--dry-run',text='0\n').stdout)
        path.write_text('{invalid')
        self.assertIn('当前生产主站：暂无',self.run_cli('--dry-run',text='0\n').stdout)
        self.assertEqual(self.monitor('--once').returncode,0)

    def test_interval_preserves_config_and_lock(self):
        before=self.conf.read_text()
        for bad in ('0','-1','4','3601','x'):
            self.assertNotEqual(self.monitor('--interval',bad).returncode,0)
        self.assertEqual(self.conf.read_text(),before)
        result=self.monitor('--interval','30'); self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('MONITOR_INTERVAL="30"',self.conf.read_text())
        self.assertIn('STATUS_EXPIRE_SECONDS="40"',self.conf.read_text())
        self.assertIn('MYSQL_PASSWORD=""',self.conf.read_text())

    def test_worker_duplicate_restart_stop(self):
        self.setup_c()
        args=['bash',str(self.root/'scripts/monitor.sh'),'--worker']
        p=subprocess.Popen(args,env=self.env,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        try:
            for _ in range(60):
                if (self.root/'data/c-status.json').exists(): break
                time.sleep(0.05)
            other=subprocess.run(args,env=self.env,capture_output=True,timeout=5)
            self.assertNotEqual(other.returncode,0)
        finally:
            p.terminate(); p.communicate(timeout=5)
        self.assertIn('监控任务停止',self.monitor('--history','worker').stdout)
        p=subprocess.Popen(args,env=self.env,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        time.sleep(0.4); p.terminate(); p.communicate(timeout=5)
        self.assertEqual(self.monitor('--once').returncode,0)


if __name__=='__main__':
    names=[n for n in MonitorTests.__dict__ if n.startswith('test_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(MonitorTests(n) for n in sorted(names)))
    raise SystemExit(not result.wasSuccessful())

@@ABC_END

@@ABC_FILE tests/test_phase5_real.py 600 03085a67896c8d82fca9165abe5e20b8cda4ba5e302638bc4d4a46561cc91266
#!/usr/bin/env python3
"""Isolated real DB + two independent SSH hosts; no production target or replication setup."""
import importlib.util
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile
import time

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'modules'))
import monitor_engine as engine


def main():
    scratch=Path(tempfile.mkdtemp(prefix='abc-phase5-',dir=os.environ.get('TMPDIR','/root/.hermes/cache/scratch')))
    scratch.chmod(0o700)
    suffix=secrets.token_hex(3); network='abc-p5-'+suffix
    names=[]; evidence=[]
    password=secrets.token_hex(20)
    def run(args,stdin=None,check=True):
        p=subprocess.run(args,input=stdin,text=True,capture_output=True,timeout=180)
        if check and p.returncode: raise RuntimeError('test command failed: '+args[0]+' '+p.stderr[-500:])
        return p
    def record(name,value):
        evidence.append(dict(test=name,result=value));print(name, json.dumps(value,ensure_ascii=False))
    try:
        run(['docker','network','create',network])
        dbnames={}
        for product,image in (('MySQL','mysql:8.0'),('MariaDB','mariadb:11.4')):
            name='abc-p5-db-'+product.lower()+'-'+suffix;names.append(name);dbnames[product]=name
            envfile=scratch/(product+'.env');envfile.write_text('MYSQL_ROOT_PASSWORD='+password+'\n');envfile.chmod(0o600)
            run(['docker','run','-d','--name',name,'--network',network,'--memory','512m','--env-file',str(envfile),image])
            client='mysql' if product=='MySQL' else 'mariadb'
            admin=scratch/(product+'.cnf');admin.write_text('[client]\nuser=root\npassword='+password+'\n');admin.chmod(0o600)
            run(['docker','cp',str(admin),name+':/root/admin.cnf'])
            for _ in range(90):
                p=run(['docker','exec',name,client,'--defaults-extra-file=/root/admin.cnf','-Nse','SELECT 1'],check=False)
                if p.returncode==0:break
                time.sleep(1)
            else:raise RuntimeError('DB initialization timeout '+product)
            # Test-fixture setup only; never executed by monitor. No business database or replication.
            sql="CREATE USER 'abc_monitor'@'%' IDENTIFIED BY '"+password+"'; GRANT REPLICATION CLIENT ON *.* TO 'abc_monitor'@'%'; " + ("GRANT SLAVE MONITOR ON *.* TO 'abc_monitor'@'%'; " if product=='MariaDB' else '') + "CREATE USER 'abc_limited'@'%' IDENTIFIED BY '"+password+"';"
            run(['docker','exec','-i',name,client,'--defaults-extra-file=/root/admin.cnf'],sql)
        results={}
        for node,product in (('A','MySQL'),('B','MariaDB')):
            name='abc-p5-ssh-'+node.lower()+'-'+suffix;names.append(name)
            run(['docker','run','-d','--name',name,'--network',network,'-p','127.0.0.1::22','--memory','192m','debian:13-slim','sleep','infinity'])
            setup="apt-get update -qq && apt-get install -y -qq --no-install-recommends openssh-server python3 procps iproute2 mariadb-client; mkdir -p /run/sshd /root/.ssh; chmod 700 /root/.ssh; cat /proc/sys/kernel/random/uuid | tr -d '-' > /etc/machine-id; /usr/sbin/sshd"
            run(['docker','exec',name,'bash','-c',setup])
            key=scratch/(node+'.key');run(['ssh-keygen','-q','-t','ed25519','-N','','-f',str(key)])
            run(['docker','cp',str(key)+'.pub',name+':/root/.ssh/authorized_keys']);run(['docker','exec',name,'chmod','600','/root/.ssh/authorized_keys'])
            port=run(['docker','port',name,'22/tcp']).stdout.strip().split(':')[-1]
            hk=run(['docker','exec',name,'cat','/etc/ssh/ssh_host_ed25519_key.pub']).stdout.split()
            known=scratch/(node+'.known');known.write_text('[127.0.0.1]:'+port+' '+hk[0]+' '+hk[1]+'\n');known.chmod(0o600)
            identity=run(['docker','exec',name,'cat','/etc/machine-id']).stdout.strip()
            cnf=scratch/(node+'.cnf');cnf.write_text('[client]\nhost='+dbnames[product]+'\nuser=abc_monitor\npassword='+password+'\nskip-ssl\n');cnf.chmod(0o600)
            run(['docker','cp',str(cnf),name+':/root/monitor.cnf']);run(['docker','exec',name,'chmod','600','/root/monitor.cnf'])
            os.environ.update({node+'_PUBLIC_IP':'127.0.0.1',node+'_PRIVATE_IP':'',node+'_EXPECTED_MACHINE_ID':identity,node+'_MONITOR_SSH_KEY':str(key),node+'_MONITOR_KNOWN_HOSTS':str(known),node+'_SSH_PORT':port,node+'_SSH_USER':'root',node+'_MYSQL_MONITOR_CNF':'/root/monitor.cnf','MONITOR_TIMEOUT':'20'})
            before=time.monotonic();data=engine.collect_node(node);elapsed=time.monotonic()-before
            assert data['server']['status']=='ok',data
            assert data['mysql']['status']=='ok',data
            assert data['mysql']['product']==product,data
            assert data['replication']['status']=='unconfigured',data
            record(node+'_real_connection',dict(product=product,version=data['mysql']['version'],seconds=round(elapsed,3),binlog=data['mysql'].get('binlog_gtid_variables'),replication='未配置'))
            results[node]=(name,known,identity,cnf)
        # Independent identity mismatch rejects before DB probe; no mysql section from remote is accepted.
        old=os.environ['A_EXPECTED_MACHINE_ID'];os.environ['A_EXPECTED_MACHINE_ID']='0'*32
        assert engine.collect_node('A')['server']['status']=='error';os.environ['A_EXPECTED_MACHINE_ID']=old
        record('machine_id_rejection','PASS')
        known=results['A'][1];original=known.read_text();known.write_text(results['B'][1].read_text().replace(os.environ['B_SSH_PORT'],os.environ['A_SSH_PORT']))
        assert engine.collect_node('A')['server']['status']=='error';assert engine.collect_node('B')['server']['status']=='ok';known.write_text(original)
        record('wrong_host_key_independent_B','PASS')
        for node in ('A','B'):
            port=os.environ[node+'_SSH_PORT'];os.environ[node+'_SSH_PORT']='1'
            assert engine.collect_node(node)['server']['status']=='error'
            assert engine.collect_node('B' if node=='A' else 'A')['server']['status']=='ok'
            os.environ[node+'_SSH_PORT']=port
        record('independent_connection_refused','PASS')
        for node in ('A','B'):
            name,known,identity,cnf=results[node];original=cnf.read_text()
            for case,content in (('wrong_password',original.replace(password,'incorrect')),('wrong_user',original.replace('abc_monitor','nonexistent')),('limited',original.replace('abc_monitor','abc_limited'))):
                cnf.write_text(content);run(['docker','cp',str(cnf),name+':/root/monitor.cnf']);run(['docker','exec',name,'chmod','600','/root/monitor.cnf'])
                data=engine.collect_node(node)
                if case=='limited':assert data['replication']['status']=='error',data
                else:assert data['mysql']['status']=='error',data
                assert password not in json.dumps(data)
                record(node+'_'+case,dict(mysql=data['mysql']['status'],reason=data['mysql'].get('reason'),replication=data['replication']['status']))
            cnf.write_text(original);run(['docker','cp',str(cnf),name+':/root/monitor.cnf'])
            run(['docker','stop',dbnames['MySQL' if node=='A' else 'MariaDB']])
            assert engine.collect_node(node)['mysql']['status']=='error'
            record(node+'_database_stopped','PASS')
        (ROOT/'data/PHASE5-REAL-RESULTS.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2))
    finally:
        for name in reversed(names):run(['docker','rm','-f',name],check=False)
        run(['docker','network','rm',network],check=False)
        # Secrets remain private scratch only; remove fixture credentials.
        for p in scratch.iterdir():p.unlink()
        scratch.rmdir()

if __name__=='__main__':main()

@@ABC_END
ABC_ALL_PAYLOAD
exit "$result"
