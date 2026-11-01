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
if [[ ${ID:-} != debian && ${ID:-} != ubuntu ]]; then
    printf '当前仅支持 Debian / Ubuntu；不支持发行版阻断。\n' >&2; exit 1
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
printf '系统检测：%s %s；root 权限及必要工具可用。\n' "$ID" "$VERSION_ID"
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
DEFAULT = Path('/home/a-b-c-d-MySQL')
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
    try: choice = input('项目安装目录 [默认 /home/a-b-c-d-MySQL]：').strip()
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
            template = template.replace('PROJECT_DIR="/home/a-b-c-d-MySQL"', 'PROJECT_DIR="' + str(root) + '"')
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
os.execvp('bash', ['bash', str(root / 'a-b-c-d-MySQL.sh'), *forward])

ABC_BOOTSTRAP_PY
result=$?
: <<'ABC_ALL_PAYLOAD'
# === ABC EMBEDDED FILES ===

@@ABC_FILE README.md 600 6ba2433b243357184734c9530ea2580db9f02172674c5607f028d05142a4d39c
# A-B-C-D MySQL 四节点主备容灾管理系统

默认安装目录 `/home/a-b-c-d-MySQL`，独立分发入口 `/root/yingyong/a-b-c-d-MySQL.sh`。本次从既有项目原位迁移，历史报告和冻结基线中的旧路径作为原始证据保留，不用于运行。旧入口保存为不可直接执行的 `.pre-abcd` 回滚文件；不要用它重新初始化旧目录。

## A/B/C/D 升级阶段二

新增主菜单10“节点角色与动态拓扑管理（离线模型）”。见 docs/ABCD-STAGE2.md。模型仅在显式确认后创建于data/offline-topology，不是生产Primary或协调授权，不修改活动配置和真实快照。测试：`python3 tests/test_topology.py`。模型已初始化时，监控入口禁止依据离线模型执行真实SSH；不会把退役节点交给旧固定目标采集。


## C 节点监控（第四阶段）

现有第 7 项已实现只读采集菜单，详见 [docs/MONITORING.md](docs/MONITORING.md)。必须配置 C 角色及已核验的 SSH/节点身份后才能远程采集。后台服务通过 `bash scripts/monitor.sh --enable` 明确确认启用；当前项目未配置 C，不自动启用。其他编号与状态机不变。数据库/复制/同步未配置时显示未配置，监控正常不是一致性或切换许可。

## 手动切换与计划维护扩展

新增主菜单 9，详见 [docs/MANUAL-MAINTENANCE.md](docs/MANUAL-MAINTENANCE.md)。主菜单和维护菜单每次显示时只读 C 状态快照；当前未部署采集器，真实界面显示“暂无”，不静态假定 A 正常。所有手动选项仅预览，不提交、执行或取消真实任务。运行方式不变：`bash /root/yingyong/a-b-c-d-MySQL.sh`。

新增回归：`python3 /home/a-b-c-d-MySQL/tests/test_manual.py`。不使用真实项目状态文件放测试数据，真实 DB、Rsync、DNS 和 Fencing 仍未接入。

## 第二阶段架构优化

当前权威设计见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)：最终目标已更新为 B 接管、自动恢复 A、观察稳定后自动安全切回 A。没有生产执行器或活动协调状态。

现有 config/config.env 保持不变；新增可选配置使用安全默认值并记录于 config.env.example。自动接管/恢复/切回默认 false，当前即使改为 true 也会被拒绝，直到后续执行器和部署验收完成。原 20 项测试文件保留原文。

新增只读入口（不调用远程工具，不持久化活动状态）：

```bash
bash /home/a-b-c-d-MySQL/scripts/coordinator_plan.sh --policy
bash /home/a-b-c-d-MySQL/scripts/coordinator_plan.sh --edge A_STABLE
bash /home/a-b-c-d-MySQL/scripts/coordinator_plan.sh --direction NORMAL_A
bash /home/a-b-c-d-MySQL/scripts/coordinator_plan.sh --simulate NORMAL_A
python3 /home/a-b-c-d-MySQL/tests/test_architecture.py
```

--simulate 缺条件返回 4 并输出 MANUAL_REQUIRED；事实只是离线模拟，不能用作生产隔离证据。恢复配置 POLICY_DRY_RUN 与 CLI --dry-run 分开，前者是未来策略闸门，后者保留原框架行为。第二阶段证据见 data/STAGE2-REPORT.md、data/stage2-verification.txt。


## 当前交付范围

基础框架已实现；不是可用于接管生产网站的完整容灾系统。模块框架在普通调用时返回 3（未实现），Dry-run 返回 0 仅代表计划展示成功，不代表业务通过验收。

没有修改 MySQL、Cloudflare、S3；没有启动同步、初始化数据库、重启服务、注册定时任务或执行故障切换。systemd/ 目前为空，后续才提供和安装业务单元。卸载也是受阻框架，不会删除项目或业务数据。

## 本机使用

```bash
bash /home/a-b-c-d-MySQL/a-b-c-d-MySQL.sh
bash /home/a-b-c-d-MySQL/a-b-c-d-MySQL.sh --help
bash /home/a-b-c-d-MySQL/a-b-c-d-MySQL.sh --install
bash /home/a-b-c-d-MySQL/a-b-c-d-MySQL.sh --status
bash /home/a-b-c-d-MySQL/a-b-c-d-MySQL.sh --check
bash /home/a-b-c-d-MySQL/a-b-c-d-MySQL.sh --diagnose
bash /home/a-b-c-d-MySQL/a-b-c-d-MySQL.sh --logs
bash /home/a-b-c-d-MySQL/a-b-c-d-MySQL.sh --dry-run
bash /home/a-b-c-d-MySQL/scripts/sync_files.sh --dry-run
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
python3 /home/a-b-c-d-MySQL/tests/test_framework.py
```

静态检查（在项目目录运行；ShellCheck 需另行提供，本项目不会自动安装）：

```bash
for f in a-b-c-d-MySQL.sh modules/*.sh scripts/*.sh; do bash -n "$f" || exit; done
shellcheck -x -P SCRIPTDIR a-b-c-d-MySQL.sh modules/*.sh scripts/*.sh
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

@@ABC_FILE a-b-c-d-MySQL.sh 700 22a24a202e959406e6071e791794126a33762eada4218447412e0a39ead6bd08
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
        echo '用法：bash a-b-c-d-MySQL.sh [--menu|--install|--check|--status|--diagnose|--logs|--uninstall] [--dry-run]'
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

@@ABC_FILE config/config.env.example 600 583d52c67793d0644f30eb0baf244d812f9e1ba862d38dff4e1d70437942878e
# 第一阶段配置：仅支持 KEY="字面值"；不执行 Shell 展开，不支持内联注释。
PROJECT_DIR="/home/a-b-c-d-MySQL"
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

@@ABC_FILE docs/ABCD-STAGE2.md 600 8304f2a593e44f91b28828c83de6b7a6c801059f491540051d5a75d85031ae5a
# A/B/C/D 阶段二：离线拓扑模型

模型不是生产角色声明。schema=2、mode=OFFLINE_MODEL；保存在当前项目 data/offline-topology/，未初始化时不自动生成、不从配置推断Primary。实际项目本次未初始化模型。当前config.env原样读取，未迁移或覆盖；物理身份统一固定A/B/C/D，初始全部Joining且Primary=null，C为模型Coordinator、D为Standby Coordinator（均不授予执行租约）。

节点：physical_id、instance_id、address、production_role、coordination_role、lifecycle、database.product/version、last_checked_at。C生产角色None；A/B/D允许Primary/Replica/Retired；生命周期Active/Maintenance/Joining/Unreachable/Retired。注册表不物理删除节点，退役是逻辑删除，保留资料及audit。重新加入到Joining，身份和数据验证场景完成前不成为生产候选。

状态：Joining→Active需离线身份/数据验证和完整资料；Active可Maintenance/Unreachable（当前Primary需先迁移）；非主生产节点→Retired；Retired→Joining；Active候选promote原子将原Primary变Replica并改两类同步边。直接demote唯一Primary被拒绝，必须作为promote另一个合格目标的同一事务完成。所有验证输入是测试场景，不是GTID/隔离的真实证据。

动态边：currentPrimary→各未退役生产节点，两条独立直连；Joining的边是待建立的模型意图，不表示链路已连接。数据库和文件边独立存储并验证，当前实现要求二者同源同目标；两通道健康/边界与执行待阶段三后实现。默认无Primary时两类边为空。/home/web/含beifen和未来目录，仅log/mysql/redis排除规则不变。

C目标由节点注册表筛选有效生产节点；D目标由注册表筛选其他有效生产节点及C；不探测自身、过滤Retired。Joining允许只读重新认证观察，不成为生产候选。退役A后C目标B,D；D目标B,C。该函数无SSH动作。监控模块检测到离线拓扑时使用派生目标提示并拒绝真实采集，避免退役节点落入旧硬编码A/B分支。未初始化离线模型时原ABC监控兼容路径保留；因此本阶段没有把旧生产监控升级成四节点生产采集器。

存储事务：operation.lock跨进程非阻塞flock（仅本机离线模型，不是协调租约）；expected_version做CAS；operation_id绑定请求摘要，重复同请求返回现状不增版本，不同请求复用ID拒绝。所有审计与操作索引和拓扑在同一JSON原子发布。PREPARED记录完整after镜像→发布topology→COMMITTED，文件和父目录fsync。恢复先校验版本/内容，只有原版本或已发布且内容一致才完成同一离线事务；未知/损坏/冲突停止，不重置为空、不涉及基础设施重播。单调版本，单Primary。存储目录700、文件600、拒绝链接/不同所有者；私有root目录为信任前提。

主菜单只增加10节点角色与动态拓扑（离线），保留1—9编号和业务功能；不提前生成完整13项最终菜单。真实节点管理菜单包括查看角色、同步边、动态监控列表、审计、初始化离线模型、显式确认模型变更。当前低层JSON输入仅面向离线验收，不承诺完成生产迁移向导。

限制：审计/请求索引当前随模型增长，长期归档和容量配额待后续；无C/D分布式租约、见证/Fencing、数据库/文件执行器、限时迁移/调度执行器。schema1活动配置和真实监控快照不改写。现有基线归档不修改。

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

@@ABC_FILE docs/CLOUDFLARE-TRANSACTIONS.md 600 5163d3acdf52959289fe3da65028d38a3c9472828fbc930b06283192996432d1
# Cloudflare本地配置事务（第二批第二项）

只处理本地配置，不访问Cloudflare API，不修改DNS。

## 唯一发布器
modules/config_transaction.py：Cloudflare.update及旧monitor --interval均经过config/config-write.lock，使用完整config.env摘要CAS、operation_id+受保护HMAC请求指纹、单调账本版本。旧Cloudflare无参数入口仍为阻断预览，不存在旧真实DNS写能力。旧脚本新增--recover，只在两次严格yes后恢复本地事务。

配置唯一活动来源仍为config/config.env。config/config-pending.env为0600受控恢复候选，不是独立活动配置；候选含凭据，仅存私有config目录，不能当作普通日志或公开证据。config-request.key为0600随机HMAC密钥，账本不保存Token/密码/私钥。原cloudflare-history.json仅保留读取，不删除、不迁移；新历史从config-ledger.json读取，两种记录合并展示。

## 协议
1. 固定字段/格式校验，持唯一配置锁，先恢复既有事务。
2. 同operation_id同完整请求返回已记录结果，异请求同ID拒绝；未指定ID的旧Python调用兼容生成随机ID，调用方必须保存返回ID及原请求才能可靠重试。
3. 在私有暂存目录调用原common.sh load_config验证完整候选，原文不输出；然后核对原配置SHA256版本。
4. 候选配置原子写/fsync，写PREPARED意图：前后配置摘要、前后账本摘要、完整脱敏目标账本。
5. 恢复器仅在当前配置和账本分别匹配before/after时继续，原子发布配置，再原子发布账本，再COMMITTED。未知外部更新一律拒绝，不盲目覆盖。
6. 读取状态/历史不自动恢复；已有锁采用共享锁，PREPARED明确报未完成。物理上多个文件不是一次原子替换，逻辑上只有COMMITTED才能报告完成。

恢复命令：bash scripts/cloudflare.sh --recover。配置已发布但账本失败时可运行此命令；如果非合作外部写者更新了配置，保留材料等待人工核对，不自动强制回滚。

## 已知边界
- 普通Shell bootstrap和worker仍直接读config.env：会读到原子完整的旧/新配置，但不是配置+审计跨文件快照；不能把它描述为所有读者都受同一锁保护。
- 旧monitor interval调用生成随机operation_id；需显式稳定ID重试时使用ConfigTransaction接口，本批未新增监控UI协议。
- 读取前首次尚无锁时不创建锁，存在首次写者竞态；配置单文件原子但完整历史快照仍可拒绝/稍后重试，不承诺读取跨文件强串行。
- 本地flock不能防root手工修改；恢复按摘要拒绝外部更新。HMAC不是加密或防篡改审计能力，文件权限不隔绝root。
- 重要旧历史不重写。新账本按整体JSON原子更新，长期增长和失败拒绝审计另需后续设计；不在本批实施日志轮转。
- 保留私有候选以便故障恢复，提交后不清空；删除配置后候选为删除后的配置，历史/账本不保存旧Token。不能承诺安全擦除磁盘旧块。
- 测试中的SIGKILL/ENOSPC注入不是生产通信、真实磁盘耗尽或整机断电证明。

@@ABC_END

@@ABC_FILE docs/DISTRIBUTION.md 600 2449173ff9b3c918f0d0c87c73d15d8d064dadd59769b3969557329dee5b3cee
# 自包含分发入口

/root/yingyong/a-b-c-d-MySQL.sh 是完整单文件分发物，内嵌模块、文档、配置模板和测试的可读源码，不下载业务源码，不包含现有 config.env、密码、日志或运行状态。可复制并改名至其他 Debian 12/13 主机，以 bash 文件名运行。

首次运行检测 root、Debian 和必要工具。缺 Python 等工具时明确询问 yes 后仅安装运行依赖（需要 Debian 软件源网络）；拒绝时停止，--dry-run 不安装依赖。首次提示安装目录，默认 /home/a-b-c-d-MySQL；确认 yes 后部署离线框架并进入菜单。

--project-dir /绝对路径 可显式选择安装；--initialize --no-menu 只初始化；--verify 检查与当前分发版本一致；--repair/--upgrade 经确认恢复内嵌程序文件，不覆盖已有 config.env、日志和状态。修复会覆盖已修改的受管源码，执行前应自行保留定制版本；没有版本联网检测，upgrade 表示发布本分发版本，不声称最新。

安装位置记录在分发入口旁的 <入口名>.install-path。查找优先级：--project-dir、入口同目录配置、位置记录、默认目录现有配置、首次交互。换名或迁移后可显式指定项目目录。位置记录不是项目凭据或主要配置，权限 600。不能从 CWD 猜项目。

每次启动校验内嵌文件 SHA256、文件内容和权限；缺失/损坏时拒绝启动并提示 repair。单文件内部 SHA256 用于损坏检测，不代替可信来源签名。项目 a-b-c-d-MySQL.sh 作为内部调度入口，分发文件独立包含它；不是旧式仅跳转启动器。

发布使用稳定锁和同目录临时文件+fsync+replace，不跟随不安全路径，源码预检后发布，配置不执行为 Shell。单文件逐项原子更新并非整个目录断电原子事务；中断后完整性检查阻止误启动，需重新 repair。安装目录路径不可包含双引号和换行；自定义目录应为新建或项目专用的 700 目录。已有配置与目录权限不符时保留并报错，不自动 chmod 业务目录。

本分发仅部署当前离线功能；不启动 MySQL、Rsync、监控后台、DNS、切换或恢复，不读写 S3。生产执行仍未实现。

@@ABC_END

@@ABC_FILE docs/DOMAIN-TRANSACTIONS.md 600 8f8b895bee1f79fbd359488cbc969b8cba51c233e4db01c9004148adaa5a5272
# 第二批第一项：分域离线事务

## 本次范围
仅生产/监控/物理登记事务域隔离；不开展CF、报告导出、日志模块或后续模型整改，不执行基础设施动作。

## 存储
显式初始化后的data/domain-model/包含：
- registry.lock、registry/state.json、registry/transaction.json：共享物理身份/资源/兼任策略。
- production.lock、production/state.json、production/transaction.json：生产角色、复制/文件/专用配置及迁移任务。
- monitoring.lock、monitoring/state.json、monitoring/transaction.json：逻辑监控、环境、优先级与监控任期。
- enabled.json：只在初始化完成后发布。

每域独立version、generation、operation_id索引、audit及PREPARED恢复记录；审计属于该域原子状态，不是普通日志，不自动轮转/删除。DomainStore.audit(domain)独立查询。目录0700、文件0600。

## 兼容
新菜单首次明确双确认提交且没有旧模型时，显式创建分域模型；打开菜单不初始化。旧schema3保留原事务实现及已有文件，不自动迁移；启用分域后旧Store写入通过同一个域路由，旧整数版本请求拒绝。旧schema2写入及真实采集在分域模型存在时阻断。旧离线策略适配属于下一项，不在本次修改。

生产和监控不再读改写同一个整拓扑JSON。只读resolver组合三个域形成schema3兼容视图；版本为production版本并另有完整domain_versions。请求必须携带版本向量：本域与物理登记CAS，不因对侧域版本独立增加而误拒绝；所有操作依最新组合状态做跨职能约束校验。

生产Fencing只改变production_isolated，不改共享物理lifecycle或监控角色。旧schema3仍保留原行为，避免静默重解释原文件。

## 锁与限制（必须披露）
各业务域锁独立，长迁移意图不持锁，可交错推进监控事务。另有commit.lock短时共享提交门，用于一致组合/跨域资源检查及单域发布；该门内含本地fsync，会有短时等待。**这不是“任何情况下完全不共享锁、不阻塞”的实现**。持production.lock不阻止monitor事务，反之亦然；但持commit.lock仍会阻塞两者。若验收要求禁止任何共同提交门，本项仍属部分完成，需另行设计不可变共享登记和跨域资源预留协议，不能删门导致覆盖/资格竞态。

同域PREPARED/发布中断由同请求重试恢复；只读菜单发现未提交事务明确拒绝，不自动改状态；其他域可独立提交，恢复只发布目标域，不覆盖另一域更新。初始化marker前中断保留材料，拒绝重新初始化，需人工处理。

本次不提供旧状态自动迁移，不宣称断电持久化、分布式锁/租约、真实监控权威、真实Fencing或MySQL切换。

## 第一项续审结论
保留commit.lock。跨域colocation、物理生命周期和PREPARED意图需要共同线性化校验，否则两个独立快照各自合法、合并后可能非法。简单按动作放行或CAS两次读后各自写会发生write skew；按节点资源预留或不可变版本快照协议可替代，但属于重大协议设计，不在本次直接引入。

阻塞范围包括本地组合读取、schema/资格校验、日志意图及状态发布的fsync；不包含用户输入、远程操作或整个迁移任务。不能保证磁盘卡顿时等待有上限。真实子进程持门测试证明对侧提交等待、释放后完成。依然不是完全无共享锁实现。

续审修复：公开recover统一获取域锁→提交锁；读取审计拒绝PREPARED及版本不匹配；恢复重验跨域兼任约束；新提交同时验证对侧PREPARED after镜像，避免登记退役/资源策略变化破坏稍后恢复。域审计与状态同文件原子发布，尚未独立追加存储。

新增test_domain_crashes.py：实际子进程分别在生产/监控PREPARED及状态发布完成后停住，再SIGKILL；对侧提交后重启恢复并比对对侧文件摘要。另测ENOSPC、恢复拒绝冲突状态、挂起监控绑定阻止物理退役和共享锁阻塞。进程崩溃测试不代表主机断电或生产容灾验收。

@@ABC_END

@@ABC_FILE docs/FORMAL-MENU-STAGE2.md 600 30bc6d938de7186f2baf609e7e83f24329f77d012ab56a9a8e35e6922bd0dba8
# 正式菜单阶段二使用与限制

本文件优先于旧文档中的旧菜单说明。唯一活动项目不变，原有配置不自动迁移。主菜单定义在 modules/menu_spec.py；脚本入口 scripts/main.sh，实际UI modules/management_ui.py。

- 节点登记后是Joining。第2项→12可申请join或提交qualify离线身份/数据/资源证据；不会自动获得生产或监控职能。
- 第3项生产添加绑定可输入priority修改完整生产优先级；第4项监控添加绑定可输入priority修改逻辑监控优先级、handoff进行离线协调权交接。两套优先级和任期独立；同物理节点不伪装多个独立监控投票者。
- 监控绑定仅提交离线环境资料，缺依赖时标记环境缺失。第8项生成计划并可模拟成功/失败；本机OS识别明确标识不代表远端。
- 第5项配置仅保存凭据引用。第7项SSH与MySQL通信互不覆盖。三通道状态分别显示，全部为离线模型或待检查，不能作为生产健康证据。
- 第6项→9可初始化首个离线Primary（要求完整离线预检）；已有Primary必须走第9项持久化迁移状态机，不允许旧兼容菜单直接改角色。
- 第9项子菜单提交迁移任务后不自动运行。手动切换→12可推进已有任务单步模拟，每步独立确认并落盘。第10项→11只允许在离线自动策略启用、到维护时间且目标一致时创建自动任务；没有后台自动调度器。
- 临时期限从SIMULATED_COMPLETED开始；到期只保存WAITING_SAFE_WINDOW评估。永久任务不生成到期回切。
- 配置操作均预览并双确认。:quit/:cancel/退出配置向导及EOF取消暂存。--dry-run不提交模型、配置、报告或锁。
- Cloudflare仅复用config/config.env中的CF_API_TOKEN/CF_ZONE_ID/CF_DOMAIN，隐藏Token，历史只存字段名与事件。离线格式检查不验证真实权限，不读取真实DNS记录，不执行DNS切换。CF写入采用独立锁和原子文件替换，PREPARED审计并非可自动重放的凭据事务，断电中断需管理员核对，绝不推断成功。

## 尚未完成的能力，不能视为已验收

- 真实MySQL/SSH/Rsync/DNS/远程安装与业务写屏障、Fencing、分布式租约执行器全部未实现且禁止执行。
- 专用配置当前实现公共/节点专属/敏感引用隔离和覆盖阻断；真实语法、版本兼容、权限检查、备份/受控发布/回滚未接入，界面显示尚未检查。
- 网站同步当前实现离线清单、范围/符号链接/防抖/删除保护与任务模型；真实事件检测、重命名、大文件稳定探测、断点恢复、传输校验与重试执行器未实现。预览中的流程文字不是已执行证明。
- 迁移证据由离线资料提供，不解析真实GTID集合、Binlog血缘、复制边界和额外事务；不能将管理员填写true当成真实证据。
- 已有旧schema2模型时拒绝自动建立schema3竞争注册表；显式数据迁移需要另行审核。本次实际活动目录未写入任何测试节点或模拟任务。
- 自动任务仅为可持久化、可恢复的单步离线状态机；尚无后台触发器和任务专属状态锁，使用现有全局拓扑事务锁保守串行化。监控职能不受迁移改变，但生产/监控锁尚未做到完全独立，应继续阶段二完善。
- 未验证真实分布式互斥、重启/断电恢复、生产回滚和长期稳定性。当前只能接受离线开发成果，不能生产上线。

完成后暂停阶段二，等待管理员审核；未经授权不得进入阶段三。

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

@@ABC_FILE docs/MENU-STAGE2-PLAN.md 600 4acaf368f811389321f7ebd216239a035a8cd6695100399c52ed51a9985ade99
# 正式菜单阶段二增量实施计划

## 已检查的现状
- 唯一活动目录 /home/a-b-c-d-MySQL，独立入口 /root/yingyong/a-b-c-d-MySQL.sh；非 Git 仓库。
- scripts/main.sh 为旧 11 项菜单；cloudflare.sh 为阻断占位；communication.sh 为旧两项通信预览。
- modules/node_functions.py schema3 已支持四物理节点、独立生产/监控职能、资源兼任限制、CAS、operation_id、PREPARED/原子发布恢复。
- modules/topology_model.py schema2 为旧兼容模型；schema3 存在时旧写入已阻止。
- offline_policy.py 已有独立优先级/临时期限原型，不具备真实迁移执行能力。
- 原测试包含旧菜单精确断言；保留原文件，另建正式菜单验收，旧合同冲突必须单独报告，不隐藏失败。

## 边界
不得远程连接、执行 MySQL/SSH/Rsync/DNS、安装远程环境或改定时任务；保留 config、日志、历史、审计、回滚和 baselines 字节。测试仅使用 scratch 下有所有权标记的隔离副本。实际项目不写模拟节点、健康快照或迁移数据。

## 增量步骤
1. 在 data/menu-stage2-20261031T205646Z 保存修改前清单、SHA256、权限和私有源码归档。
2. 扩展现有 schema3 的可选管理字段，不新建竞争注册表；旧状态按只读默认解析。所有新事务复用原有安全 IO、flock、CAS、幂等和发布协议。独立生产/逻辑监控优先级及通信/文件/配置三通道。
3. 增加正式十项菜单与逐层子菜单，原能力保留在原模块；新 UI 不进入旧危险流程。配置向导有预览和严格双确认。阶段二只持久化离线模型。
4. 增加迁移预检、每阶段持久化的离线自动迁移、写屏障/最终 GTID/Fencing/提交/恢复写入守卫、维护及期限模型；失败粘滞人工处理。
5. 添加隔离正负测试、菜单遍历、D 动态方向、事务中断与进程锁测试。原回归独立计数；不执行真实集成测试。
6. 重打包可读单文件，验证内嵌内容/权限及独立安装。报告 Bash、ShellCheck、所有测试计数、保护文件差异和生产未实现项。
7. 阶段二结束暂停，等待管理员审核；本计划不授权阶段三。

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

@@ABC_FILE docs/NODE-FUNCTIONS.md 600 0f0c6cf687ed1db97bf2dc0848beab4fef24832128a4948c3af1aada9cc8578c
# 四节点对称功能模型（阶段二离线）

最新模型schema3/mode OFFLINE_FUNCTIONS，保存data/offline-functions。物理A/B/C/D对称，每节点production=null/Primary/Replica，monitor=null/Primary Monitor/Backup Monitor，lifecycle独立。默认Joining且两项null。旧schema2文件保持原样不自动迁移；新模型存在时新面板优先读取它，损坏不回退旧角色。原10菜单保留为旧版模型兼容工具，新11菜单为功能模型；不要将两套模型视为同时有效的生产授权。

全局最多一个生产Primary、一个Primary Monitor。多个Backup Monitor允许，effective_backup记录当前有效备份（按ID确定性选首个，后续用户选择策略待补）。生产变更只改生产职能/边；主监控变更只改监控职能，旧主监控变Backup。删除Replica不影响监控，删除Backup不影响生产/边；删除当前Primary或Primary Monitor被拒绝，需先交接。退役拒绝任一主职能未交接者，然后清两功能；重新加入两功能null且不进入边/监控候选。加入Active后仍无功能，逐项分配。

同节点兼任默认禁止；模型policy允许后仍要求最近300秒资源证据：CPU/内存/磁盘阈值、CPU/磁盘IO/网络利用率、进程隔离、可靠协调状态。证据由离线fixture/管理员提供，不是真实采集，不授权执行。当前UI可调整allow_colocation；其余阈值在模型policy中定义，完整策略编辑向导待后续。

独立PRODUCTION和MONITOR状态机：REQUESTED/PREFLIGHT/LOCKED/VALIDATED/COMMIT/COMPLETED，失败MANUAL_REQUIRED；这些是纯离线转换，不是逐阶段持久执行器。功能分配及删除通过同一私有flock、CAS、operation_id摘要、PREPARED/原子发布/COMMITTED事务完成，角色/边/审计共同提交，中断可对账。监控服务安装/卸载、分布式协调权、Fencing均未实现。

新功能菜单1—11项实际运行；所有动作选择任意A/B/C/D。第7/9预览有新模型时读取新模型，无模型兼容旧拓扑。旧ABC/ABCD兼容模块保留历史限制，明确不代表新模型能力。监控引擎若新模型存在直接拒绝真实采集，不可用模拟职能突破门禁。

测试含四节点分别任生产/监控主、A兼任双主、B/D生产副本与监控备用、D删除监控保留数据库边、C兼任、单功能删除、退役加入、资源冲突、CAS/锁/幂等/中断恢复。均为项目外隔离模型，不是生产验证。

@@ABC_END

@@ABC_FILE docs/OFFLINE-PRIORITY.md 600 9859546a32c48d1fe28c36a19263332946be595a9c6b075a361d73f58a8731e8
# 生产/监控优先级与到期评估（阶段二离线）

保留schema3功能模型；新增独立data/offline-policy策略/任务存储，不改活动配置。默认production_priority=A,B,D，monitor_priority=B,D；production_candidates与monitor_candidates独立，C可显式加入生产优先级/候选，不因身份限制。新模型存在时旧schema2 transaction禁止写入；不自动迁移已有状态。

迁移记录仅由migration_completed离线场景创建，要求模型当前主等于目标且offline_completed=true；默认temporary300秒，存source/target/effective_at/expires_at/operation_id/topology_version。永久需second_confirmation=true，expires_at=null且expiry拒绝。到期每次重新选最高优先级合格节点，证据包含身份/血缘/追平/健康/写屏障/Fencing/文件/两拓扑/耐久事务，失败WAITING_SAFE_WINDOW。选中仅EVALUATED，不调用功能角色提交，不执行真实切回。

FAILBACK阶段按需求持久保存stage/trace/error；每步verified由离线fixture提供，不是真实证据。PREPARED/发布/COMMITTED日志与CAS/幂等锁支持每阶段中断恢复；这是本地模拟任务持久化，不是具有租约和Fencing执行能力的生产协调器。当前MANUAL_REQUIRED后的自动继续未实现严格重授权协议，交付前应视为待完善，不用于生产。

monitor_evaluate要求旧不可用明确模拟证据，候选按B,D选，有独立identity/health/authority/old_revoked/state_transfer/quorum/resources证据及兼任冲突检查，失败DEGRADED。只输出候选，不改生产/监控角色。monitor_term字段已单独保存，但当前不递增、不发有效租约；监控阶段序列存在，但未实现完整持久监控接替/交还执行流程。不得声称C故障后已自动提升B/D。监控恢复实际可通过schema3显式离线primary_monitor事务模拟；自动抢占未实现。

菜单11→12提供策略查看/修改和低层JSON离线场景提交。生产/监控分别配置，资源阈值编辑仍不完整（沿用模型阈值和allow_colocation），不是完整迁移期限向导或后台调度器。本轮没有后台任务自动到期执行，必须显式离线评估。

新增5项测试包含A→B/D临时、D永久、重载/幂等、血缘/追平/Fencing/文件拒绝、优先级重算、每个生产恢复阶段prepared/published交替中断、监控B/D/降级候选、schema3发布后恢复及旧模型写阻断。永久到B、真实多进程竞争、监控每阶段恢复/独立锁任期/完整C恢复交还尚未新增专测；不将已有模拟结果扩写为24场景全部通过。

@@ABC_END

@@ABC_FILE docs/ROLE-FIXES.md 600 e677911269a62bacb6fe78b26240dbe34817934994c02848a6212e463552f2ea
# 阶段二角色与子菜单修正

Joining角色改为JSON null（包括C无生产角色）；activate经离线身份/数据验证后赋予生产节点Replica，C仍null。有效边只连接非Joining/Retired且角色Replica节点。重新加入不产生有效边，不进入生产候选。旧模型Joining+Replica会校验拒绝，不自动修改已有模型或历史，需单独批准迁移。

A/B/D物理ID不变，promote任一Active候选在同一事务把旧Primary变Replica、重建两通道边、增加version和审计before/after_roles。退役不再进入边/目标。直接demote当前Primary仍拒绝，必须选择接替节点后同事务转换。

新增ROLE_CHANGE_REQUESTED→PREFLIGHT→TOPOLOGY_LOCKED→CONSISTENCY_CHECK→ROLE_ASSIGNMENT→REPLICATION_RECONFIGURATION→HEALTH_CHECK→TOPOLOGY_COMMIT→COMPLETED纯离线状态转换（每段均ROLE_CHANGE_前缀），条件失败返回MANUAL_REQUIRED。当前role_stages审计是模拟完成轨迹，不是逐阶段执行器或独立阶段持久化；底层仍用PREPARED/发布/COMMITTED本地事务、CAS、flock、operation_id恢复。不得将此轨迹当成真实重配证明。

第7/9默认菜单改为动态只读预览，无模型显示未初始化；目标来自同一有效注册表，退役节点不显示在目标列表。菜单不会触发采集或切换。旧CLI --once/--worker/--enable等兼容入口仍保留并单独标注，不属于四节点菜单，也未在本轮执行；实际动态采集集成仍待后续授权。

本轮不修改活动配置/拓扑/历史/冻结基线。旧监控测试只调整菜单文字期望为动态只读菜单，原认证/故障/并发等安全断言保留。新增3项角色修正测试覆盖B/D相互升降、Joining null及边排除、阶段失败、退役动态预览及只读文件不变。全部均隔离模型，不是数据库验收。

@@ABC_END

@@ABC_FILE modules/cloudflare_config.py 600 39679efd1fc110ecf51c65c4c6c5b15525777369330fe2d8d7da52a03e4d6d95
"""One protected CF configuration: existing config.env; offline checks only."""
import re
from topology_model import Store

class Cloudflare:
    def __init__(self,root):
        self.io=Store(root);self.io.folder=self.io.root/'config'
    def read(self):
        from config_transaction import ConfigTransaction
        tx=ConfigTransaction(self.io.root)
        with tx.locked(readonly=True):
            tx.pending()
            return self._read()
    def _read(self):
        p=self.io.folder/'config.env';self.io.private(p)
        raw=p.read_text();values={}
        for line in raw.splitlines():
            if not line or line.startswith('#'):continue
            match=re.fullmatch(r'([A-Z][A-Z0-9_]*)="([^"\n]*)"',line)
            if not match or match[1] in values:raise ValueError('统一配置格式错误')
            values[match[1]]=match[2]
        return raw,values
    def status(self):
        _,v=self.read()
        return dict(token='已配置（隐藏）' if v.get('CF_API_TOKEN') else '未配置',zone=v.get('CF_ZONE_ID') or '未配置',domain=v.get('CF_DOMAIN') or '未配置',connection='尚未检查；阶段二不联网',dns_records='状态未知；未获取真实DNS记录')
    def check(self):
        _,v=self.read();t=v.get('CF_API_TOKEN','');z=v.get('CF_ZONE_ID','');d=v.get('CF_DOMAIN','')
        return dict(mode='OFFLINE_MODEL',token_format=bool(re.fullmatch(r'[A-Za-z0-9_-]{20,256}',t)),zone_format=bool(re.fullmatch(r'[a-fA-F0-9]{32}',z)),domain_format=bool(re.fullmatch(r'(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}',d)),permissions='无法确认；需未来只读API权限实测',modified_dns=False)
    def history(self):
        from config_transaction import ConfigTransaction
        tx=ConfigTransaction(self.io.root)
        with tx.locked(readonly=True):
            tx.pending()
            p=self.io.folder/'cloudflare-history.json'
            old=self.io.read(p.name) if p.exists() or p.is_symlink() else []
            return old+[x for x in tx.ledger()['operations'] if x['domain']=='cloudflare']
    def recover(self):
        from config_transaction import ConfigTransaction
        ConfigTransaction(self.io.root).recover()
    def update(self,changes,expected,operation_id=None):
        if not set(changes)<={'CF_API_TOKEN','CF_ZONE_ID','CF_DOMAIN'}:raise ValueError('禁止修改非CF字段')
        for k,v in changes.items():
            if not isinstance(v,str) or any(ord(c)<32 or ord(c)==127 or c in '"\\' for c in v):raise ValueError('配置输入非法')
            if v and not re.fullmatch({'CF_API_TOKEN':r'[A-Za-z0-9_-]{20,256}','CF_ZONE_ID':r'[a-fA-F0-9]{32}','CF_DOMAIN':r'(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}'}[k],v):raise ValueError('CF字段格式不符合要求（不显示原文）')
        from config_transaction import ConfigTransaction
        return ConfigTransaction(self.io.root).update(changes,expected,operation_id,'cloudflare')

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

@@ABC_FILE modules/config_transaction.py 600 a5aac7ed8750b5e3a344a3dd5b0ea00d2a503bcc6a75891300a78ca9fcbb4596
"""One private config.env publisher. Offline local transactions, no network."""
from contextlib import contextmanager
from pathlib import Path
import fcntl
import hashlib
import hmac
import json
import os
import re
import secrets
import subprocess
import tempfile
import time
from topology_model import Store


def digest(data):return hashlib.sha256(data).hexdigest()

class ConfigTransaction:
    def __init__(self,root):
        self.io=Store(root);self.io.folder=self.io.root/'config'
    @contextmanager
    def locked(self,readonly=False):
        self.io.private(self.io.root,True);self.io.private(self.io.folder,True)
        p=self.io.folder/'config-write.lock'
        if readonly and not p.exists() and not p.is_symlink():
            yield
            return
        fd=os.open(p,(0 if readonly else os.O_CREAT)|os.O_APPEND|os.O_WRONLY|os.O_NOFOLLOW,0o600)
        try:
            self.io.private(p);fcntl.flock(fd,(fcntl.LOCK_SH if readonly else fcntl.LOCK_EX)|fcntl.LOCK_NB);yield
        finally:os.close(fd)
    def raw(self):
        p=self.io.folder/'config.env';self.io.private(p);return p.read_bytes()
    def atomic(self,name,content):
        p=self.io.folder/name
        if p.exists() or p.is_symlink():self.io.private(p)
        fd,tmp=tempfile.mkstemp(prefix='.config-',dir=self.io.folder)
        try:
            with os.fdopen(fd,'wb') as f:f.write(content);f.flush();os.fsync(f.fileno())
            os.replace(tmp,p);self.sync()
        finally:
            if os.path.exists(tmp):os.unlink(tmp)
    def sync(self):
        fd=os.open(self.io.folder,os.O_RDONLY|os.O_DIRECTORY)
        try:os.fsync(fd)
        finally:os.close(fd)
    def ledger(self):
        p=self.io.folder/'config-ledger.json'
        d=self.io.read(p.name) if p.exists() or p.is_symlink() else dict(schema=1,version=0,operations=[])
        return self.validate_ledger(d)
    def validate_ledger(self,d):
        if not isinstance(d,dict) or set(d)!={'schema','version','operations'} or d['schema']!=1 or type(d['version']) is not int or not isinstance(d['operations'],list) or len(d['operations'])!=d['version']:raise ValueError('配置账本损坏')
        ids=[]
        for i,x in enumerate(d['operations'],1):
            if not isinstance(x,dict) or set(x)!={'operation_id','fingerprint','domain','fields','timestamp','before_version','after_version','event'} or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}',x.get('operation_id','')) or not re.fullmatch(r'[a-f0-9]{64}',x.get('fingerprint','')) or x['domain'] not in ('cloudflare','monitor') or x['before_version']!=i-1 or x['after_version']!=i or x['event']!='COMMITTED' or not isinstance(x['fields'],list):raise ValueError('配置审计损坏')
            ids.append(x['operation_id'])
        if len(ids)!=len(set(ids)):raise ValueError('配置请求ID重复')
        return d
    def pending(self):
        p=self.io.folder/'config-transaction.json'
        if p.exists() or p.is_symlink():
            j=self.io.read(p.name)
            if not isinstance(j,dict) or set(j)!={'status','version'} or j.get('status')!='COMMITTED' or j.get('version')!=self.ledger()['version']:raise ValueError('配置事务未完成；需显式恢复，不报告成功')
    def validate(self,raw):
        # Exact common parser, bounded private staging; never source config as code.
        with tempfile.TemporaryDirectory(prefix='config-validation-',dir=self.io.root/'tmp') as temp:
            p=Path(temp);(p/'config').mkdir(mode=0o700)
            data=raw.decode().replace(str(self.io.root),str(p));(p/'config/config.env').write_text(data);(p/'config/config.env').chmod(0o600)
            result=subprocess.run(['bash','-c','source "$1"; PROJECT_DIR=$2; load_config','_',str(self.io.root/'modules/common.sh'),str(p)],capture_output=True,timeout=15)
            if result.returncode:raise ValueError('候选配置未通过统一校验（原文隐藏）')
    def key(self):
        p=self.io.folder/'config-request.key'
        if not p.exists():self.atomic(p.name,secrets.token_bytes(32))
        self.io.private(p);key=p.read_bytes()
        if len(key)!=32:raise ValueError('请求指纹密钥损坏')
        return key
    def recover(self):
        with self.locked():self._recover()
    def _recover(self):
        p=self.io.folder/'config-transaction.json'
        if not p.exists() and not p.is_symlink():return
        j=self.io.read(p.name)
        if not isinstance(j,dict):raise ValueError('配置事务损坏')
        if j.get('status')=='COMMITTED':
            if set(j)!={'status','version'} or self.ledger()['version']!=j['version']:raise ValueError('提交版本不一致')
            return
        if set(j)!={'status','before','after','ledger_before','ledger_after','ledger'} or j['status']!='PREPARED':raise ValueError('配置恢复意图损坏')
        now=digest(self.raw());ledger=self.ledger()
        if now not in (j['before'],j['after']):raise ValueError('配置已被其他写者更新，禁止恢复覆盖')
        if digest(json.dumps(ledger,sort_keys=True).encode()) not in (j['ledger_before'],j['ledger_after']):raise ValueError('配置历史已更新，禁止恢复覆盖')
        desired=j['ledger']
        if digest(json.dumps(desired,sort_keys=True).encode())!=j['ledger_after'] or desired['version']!=ledger['version']+(0 if ledger==desired else 1):raise ValueError('恢复账本摘要/版本不一致')
        # Validate desired through the same ledger schema before changing config.
        self.validate_ledger(desired)
        if ledger!=desired and desired['operations'][:-1]!=ledger['operations']:raise ValueError('恢复禁止重写既有历史')
        candidate=self.io.folder/'config-pending.env';self.io.private(candidate);data=candidate.read_bytes()
        if digest(data)!=j['after']:raise ValueError('候选配置损坏')
        self.validate(data)
        if now!=j['after']:self.atomic('config.env',data)
        self.io.write('config-ledger.json',desired)
        self.io.write('config-transaction.json',dict(status='COMMITTED',version=desired['version']))
        # Candidate kept private until next transaction overwrites it; never a second live config.

    def update(self,changes,expected,operation_id=None,domain='cloudflare'):
        request=operation_id or secrets.token_hex(16)
        if not isinstance(request,str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}',request):raise ValueError('operation_id非法')
        allowed={'CF_API_TOKEN','CF_ZONE_ID','CF_DOMAIN'} if domain=='cloudflare' else {'MONITOR_INTERVAL','STATUS_EXPIRE_SECONDS'} if domain=='monitor' else set()
        if not isinstance(changes,dict) or not changes or not set(changes)<=allowed:raise ValueError('配置字段越界')
        for value in changes.values():
            if not isinstance(value,str) or any(ord(c)<32 or c in '"\\' or ord(c)==127 for c in value):raise ValueError('配置输入非法')
        if domain=='cloudflare':
            patterns={'CF_API_TOKEN':r'[A-Za-z0-9_-]{20,256}','CF_ZONE_ID':r'[a-fA-F0-9]{32}','CF_DOMAIN':r'(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}'}
            if any(v and not re.fullmatch(patterns[k],v) for k,v in changes.items()):raise ValueError('CF字段格式非法（原文隐藏）')
        with self.locked():
            self._recover();raw=self.raw();ledger=self.ledger()
            payload=json.dumps(dict(changes=changes,expected=expected,domain=domain),sort_keys=True).encode();fp=hmac.new(self.key(),payload,hashlib.sha256).hexdigest()
            prior=next((x for x in ledger['operations'] if x['operation_id']==request),None)
            if prior:
                if prior['fingerprint']!=fp:raise ValueError('operation_id已用于不同配置请求')
                return dict(operation_id=request,version=prior['after_version'],event='COMMITTED')
            lines=raw.decode().splitlines(keepends=True);seen=set()
            for k,v in changes.items():
                for i,line in enumerate(lines):
                    if line.startswith(k+'='):lines[i]=k+'="'+v+'"\n';seen.add(k)
                if k not in seen:
                    if domain!='monitor':raise ValueError('统一CF字段缺失')
                    lines.append('\n'+k+'="'+v+'"\n')
            data=''.join(lines).encode();self.validate(data)
            if digest(raw)!=expected:raise ValueError('配置版本冲突')
            new=json.loads(json.dumps(ledger));new['version']+=1
            new['operations'].append(dict(operation_id=request,fingerprint=fp,domain=domain,fields=sorted(changes),timestamp=time.strftime('%Y-%m-%dT%H:%M:%S+00:00',time.gmtime()),before_version=ledger['version'],after_version=new['version'],event='COMMITTED'))
            self.atomic('config-pending.env',data)
            self.io.write('config-transaction.json',dict(status='PREPARED',before=digest(raw),after=digest(data),ledger_before=digest(json.dumps(ledger,sort_keys=True).encode()),ledger_after=digest(json.dumps(new,sort_keys=True).encode()),ledger=new))
            self._recover()
            return dict(operation_id=request,version=new['version'],event='COMMITTED')


if __name__=='__main__':
    import sys
    if sys.argv[1:]!=['--recover']:raise SystemExit('仅支持 --recover；不执行DNS操作')
    try:
        ConfigTransaction(Path(__file__).resolve().parents[1]).recover()
        print('本地配置事务恢复完成；未连接Cloudflare或修改DNS。')
    except (ValueError,OSError,KeyError,TypeError):raise SystemExit('配置恢复安全拒绝；保留材料，错误原文隐藏。')

@@ABC_END

@@ABC_FILE modules/dashboard.py 600 36e7996f0e8e9f8ee5fd7327da7310684a774f0141fb02c9f230d4de31fff0c5
"""ABCD status panel: live observations and offline roles are never conflated."""
from pathlib import Path
import os
import sys
import time
from status_view import private_json, fresh
from topology_model import Store


def panel(root, color=False):
    lines=[]
    def emit(label,value,reason='',code=None):
        if color and 'NO_COLOR' not in os.environ and code:
            value=f'\033[{code}m{value}\033[0m'
        lines.append(label+'：'+value+reason)
    try:
        snapshot=private_json(root/'data/c-status.json')
        now=int(time.time())
        good=isinstance(snapshot,dict) and snapshot.get('collector_ok') is True and snapshot.get('identity_verified') is True and fresh(snapshot.get('checked_at'),now)
        if 'collector_boot_id' in snapshot:good=good and snapshot['collector_boot_id']==Path('/proc/sys/kernel/random/boot_id').read_text().strip()
    except (OSError,ValueError,TypeError):snapshot={};good=False
    lines.append('实时节点状态：')
    for node in 'ABCD':
        item=snapshot.get('nodes',{}).get(node,{}) if good else {}
        value='暂无';reason='（状态缺失、过期或无法确认）';code=31
        if good and isinstance(item,dict) and fresh(item.get('checked_at'),now):
            if item.get('status')=='unconfigured':value='未配置';code=90;reason=''
            elif item.get('online')=='ok':value='正常';code=32;reason='（仅服务器在线，业务健康独立验证）'
            elif item.get('online')=='error':value='异常';reason='（连接或检查失败）'
        emit('节点 '+node,value,reason,code)
    lines.append('========================================')
    model=None;version='未初始化'
    modelpath=root/'data/offline-topology/topology.json'
    if modelpath.exists() or modelpath.is_symlink():
        try:model=Store(root).load();version=str(model['version'])+'（离线模型）'
        except (OSError,ValueError,KeyError):version='暂无（拓扑损坏或不可读取）'
    function_path=root/'data/offline-functions/topology.json'
    if function_path.exists() or function_path.is_symlink() or (root/'data/domain-model/enabled.json').exists():
        try:
            from node_functions import Store as FunctionStore
            f=FunctionStore(root).load()
            model=dict(version=f['version'],primary=f['primary'],database_edges=f['database_edges'],file_edges=f['file_edges'],nodes={n:dict(production_role=x['production'],coordination_role=x['monitor'],lifecycle=x['lifecycle']) for n,x in f['nodes'].items()})
            version=str(f['version'])+'（离线独立功能模型）'
        except (OSError,ValueError,KeyError):
            model=None;version='暂无（功能模型损坏，禁止回退旧角色）'
    lines.append('拓扑来源：离线模型（不代表真实生产状态）' if model else '拓扑来源：未初始化或无法确认')
    for node in 'ABCD':
        item=model['nodes'][node] if model else None
        if item:
            emit('节点 '+node+' / 生产角色',str(item['production_role'])+'（离线模型）')
            emit('节点 '+node+' / 协调角色',str(item['coordination_role'])+'（离线模型）')
            emit('节点 '+node+' / 生命周期',item['lifecycle'],code=90 if item['lifecycle']=='Retired' else 33)
    primary=model.get('primary') if model else None
    emit('当前生产主节点',primary or '暂无','（离线模型）' if primary else '',32 if primary else 31)
    standby=[n for n in 'ABCD' if model and n!=primary and model['nodes'][n]['production_role']=='Replica']
    emit('当前备用节点','、'.join(standby) if primary else '暂无','（离线模型）' if primary else '',33 if primary else 31)
    for field,key in (('当前数据库同步方向','database_edges'),('当前文件同步方向','file_edges')):
        edges=model[key] if model else []
        emit(field,'；'.join(a+' → '+b for a,b in edges) or '暂无','（离线模型意图，未执行）' if edges else '',34 if edges else 31)
    for label,role in (('当前协调者','Coordinator'),('备用协调者','Standby Coordinator')):
        found=[n for n in 'ABCD' if model and model['nodes'][n]['coordination_role'] in ((role,'Primary Monitor') if role=='Coordinator' else (role,'Backup Monitor'))]
        emit(label,'、'.join(found) or '暂无','（离线模型，无执行租约）' if found else '',34 if found else 31)
    emit('当前拓扑版本',version)
    emit('当前切换任务','暂无',code=31)
    for label,key in (('数据库状态','database'),('文件同步状态','files')):
        item=snapshot.get(key,{}) if good else {}
        value='未配置' if item.get('health')=='unconfigured' else '暂无'
        if good and fresh(item.get('checked_at'),now) and item.get('health')=='ok':value='正常'
        emit(label,value,'（仅通道，未证明数据一致）' if value=='正常' else '',32 if value=='正常' else 90 if value=='未配置' else 31)
    emit('最后一次成功检查时间',str(snapshot.get('last_success_at') or '暂无') if good else '暂无')
    return '\n'.join(lines)


if __name__=='__main__':
    print(panel(Path(__file__).resolve().parents[1],sys.stdout.isatty() and os.environ.get('TERM','dumb')!='dumb'))

@@ABC_END

@@ABC_FILE modules/domain_store.py 600 8d22f3bd6743a4414bedcfd429b3125c59efcad0f86953e84ccba5b4adefaa57
"""Independent local offline transaction domains; no infrastructure executors.

A read-only composed schema3 view preserves existing pure safety decisions.
Only the selected domain's state is published. A brief metadata commit lock
serializes cross-domain invariant checks, never an entire migration task.
"""
import copy
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
import re
import time
from topology_model import Store as PrivateIO

DOMAINS=('registry','production','monitoring')
MONITOR_ACTIONS={'monitor_bind','monitor_unbind','monitor_handoff','primary_monitor','backup_monitor','remove_monitor','environment','environment_simulate'}
REGISTRY_ACTIONS={'register','remark','qualify','lifecycle','join','activate','retire','policy','resources'}
PRODUCTION_ACTIONS={'primary','replica','remove_production','production_bind','production_unbind','mysql','mysql_remove','ssh','ssh_remove','sync','sync_job','sync_pause','mysql_config','auto_policy','maintenance','maintenance_cancel','migration_create','migration_step','migration_cancel','migration_deadline','expiry_assess'}
MONITOR_KEYS={'monitor_priority','monitor_bindings','environment','monitor_term'}


def classify(action,fields):
    if action=='initialize':return 'registry'
    if action in MONITOR_ACTIONS:return 'monitoring'
    if action in REGISTRY_ACTIONS:return 'registry'
    if action in PRODUCTION_ACTIONS:return 'production'
    if action=='priorities':
        keys=set(fields)
        if keys=={'production_priority'}:return 'production'
        if keys=={'monitor_priority'}:return 'monitoring'
        raise ValueError('优先级必须分功能域单独提交')
    raise ValueError('动作未登记，禁止猜测功能域')


def fingerprint(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()


class DomainStore(PrivateIO):
    def __init__(self,root):
        super().__init__(root);self.folder=self.root/'data/domain-model'
    @property
    def enabled(self):
        return (self.folder/'enabled.json').exists() or (self.folder/'enabled.json').is_symlink()
    def prepare(self):
        super().prepare()
        for name in DOMAINS:
            path=self.folder/name;path.mkdir(mode=0o700,exist_ok=True);self.private(path,True)
    def io(self,domain):
        if domain not in DOMAINS:raise ValueError('未知功能域')
        io=PrivateIO(self.root);io.folder=self.folder/domain;return io
    @contextmanager
    def locked(self,name,exclusive=True,nonblock=True):
        path=self.folder/(name+'.lock')
        flags=os.O_APPEND|os.O_WRONLY|os.O_NOFOLLOW
        if exclusive:flags|=os.O_CREAT
        fd=os.open(path,flags,0o600)
        try:
            self.private(path)
            fcntl.flock(fd,(fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH)|(fcntl.LOCK_NB if nonblock else 0))
            yield
        finally:os.close(fd)
    def enable(self):
        self.prepare()
        with self.locked('bootstrap'):
            if self.enabled:
                self.marker();return
            if any((self.root/p).exists() or (self.root/p).is_symlink() for p in ('data/offline-functions/topology.json','data/offline-topology/topology.json')):
                raise ValueError('已有旧模型；禁止自动迁移或覆盖，需单独审核迁移')
            for name in DOMAINS:
                io=self.io(name)
                if any(io.folder.iterdir()):raise ValueError('发现未完成初始化材料，需人工核对，不覆盖')
            from node_functions import initial
            model=initial()
            from management_model import defaults
            model['management']=defaults()
            for name in DOMAINS:
                self.io(name).write('state.json',dict(schema=1,mode='OFFLINE_DOMAIN',domain=name,version=0,generation=0,state=self.project(model,name),operations=[],audit=[]))
            for name in (*DOMAINS,'commit'):
                with self.locked(name):pass
            # Marker last. Crash before marker leaves evidence and safely refuses reinitialization.
            self.write('enabled.json',dict(schema=1,mode='OFFLINE_DOMAINS',domains=list(DOMAINS)))
    def marker(self):
        if self.read('enabled.json')!=dict(schema=1,mode='OFFLINE_DOMAINS',domains=list(DOMAINS)):raise ValueError('分域标识损坏')
    def project(self,d,domain):
        from management_model import settings
        m=settings(d)
        if domain=='registry':
            return dict(nodes={n:{k:copy.deepcopy(v) for k,v in x.items() if k not in ('production','monitor')} for n,x in d['nodes'].items()},policy=copy.deepcopy(d['policy']))
        if domain=='production':
            # Fenced production eligibility is not the physical/monitor lifecycle.
            return dict(roles={n:x['production'] for n,x in d['nodes'].items()},isolated=copy.deepcopy(d.get('production_isolated',[])),management={k:v for k,v in m.items() if k not in MONITOR_KEYS})
        return dict(roles={n:x['monitor'] for n,x in d['nodes'].items()},effective_backup=d['effective_backup'],management={k:m[k] for k in MONITOR_KEYS})
    def validate_record(self,r,domain):
        if not isinstance(r,dict) or set(r)!={'schema','mode','domain','version','generation','state','operations','audit'} or r['schema']!=1 or r['mode']!='OFFLINE_DOMAIN' or r['domain']!=domain:raise ValueError('分域记录结构损坏')
        if any(type(r[k]) is not int or r[k]<0 for k in ('version','generation')) or r['generation']!=r['version']:raise ValueError('分域版本/世代损坏')
        if not isinstance(r['operations'],list) or not isinstance(r['audit'],list) or len(r['operations'])!=r['version'] or len(r['audit'])!=r['version']:raise ValueError('分域幂等/审计数量不一致')
        ids=[]
        for index,(op,audit) in enumerate(zip(r['operations'],r['audit']),1):
            if not isinstance(op,dict) or set(op)!={'operation_id','fingerprint'} or not isinstance(op['operation_id'],str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}',op['operation_id']) or not re.fullmatch(r'[a-f0-9]{64}',op.get('fingerprint','')):raise ValueError('分域请求标识损坏')
            if not isinstance(audit,dict) or set(audit)!={'timestamp','operation_id','domain','action','before_version','after_version','result','reason_code','source'} or audit['operation_id']!=op['operation_id'] or audit['domain']!=domain or audit['before_version']!=index-1 or audit['after_version']!=index or audit['result']!='OFFLINE_COMMITTED' or audit['reason_code'] is not None or audit['source']!='local-offline-model' or not isinstance(audit['timestamp'],str):raise ValueError('分域审计结构损坏')
            ids.append(op['operation_id'])
        if len(ids)!=len(set(ids)):raise ValueError('分域请求ID重复')
        s=r['state']
        if not isinstance(s,dict):raise ValueError('分域状态不是对象')
        if domain=='registry':
            if set(s)!={'nodes','policy'} or set(s['nodes'])!=set('ABCD'):raise ValueError('物理登记结构损坏')
            for n,x in s['nodes'].items():
                if not isinstance(x,dict) or x.get('physical_id')!=n or 'production' in x or 'monitor' in x:raise ValueError('登记状态混入功能角色')
        else:
            expected={'roles','isolated','management'} if domain=='production' else {'roles','effective_backup','management'}
            if set(s)!=expected or set(s['roles'])!=set('ABCD') or not isinstance(s['management'],dict):raise ValueError('功能域状态键损坏')
            allowed=(None,'Primary','Replica') if domain=='production' else (None,'Primary Monitor','Backup Monitor')
            if any(v not in allowed for v in s['roles'].values()):raise ValueError('功能域角色非法')
            from management_model import defaults
            keys=set(defaults())-MONITOR_KEYS if domain=='production' else MONITOR_KEYS
            if set(s['management'])!=keys:raise ValueError('功能域配置越界')
            if domain=='production' and (not isinstance(s['isolated'],list) or len(s['isolated'])!=len(set(s['isolated'])) or any(n not in 'ABCD' or len(n)!=1 for n in s['isolated'])):raise ValueError('生产隔离清单损坏')
        return r
    def records(self):
        self.marker();return {n:self.validate_record(self.io(n).read('state.json'),n) for n in DOMAINS}
    def compose(self,records):
        from node_functions import initial,rebuild,validate
        d=initial();d['nodes']=copy.deepcopy(records['registry']['state']['nodes']);d['policy']=copy.deepcopy(records['registry']['state']['policy'])
        for n in 'ABCD':
            d['nodes'][n]['production']=records['production']['state']['roles'][n]
            d['nodes'][n]['monitor']=records['monitoring']['state']['roles'][n]
        d['effective_backup']=records['monitoring']['state']['effective_backup']
        d['management']=copy.deepcopy(records['production']['state']['management']);d['management'].update(copy.deepcopy(records['monitoring']['state']['management']))
        d['production_isolated']=copy.deepcopy(records['production']['state']['isolated'])
        d['domain_versions']={n:r['version'] for n,r in records.items()};d['version']=records['production']['version']
        d['domain_generations']={n:r['generation'] for n,r in records.items()}
        d['operations']=[];d['audit']=[a for name in DOMAINS for a in records[name]['audit']]
        rebuild(d);return validate(d)
    def load(self):
        # No prepare/recovery on views. Refuse an uncommitted domain rather than
        # silently treating a mixed checkpoint as operationally healthy.
        with self.locked('commit',exclusive=False,nonblock=False):
            records=self.records()
            for name in DOMAINS:
                self.pending(name)
            return self.compose(records)
    def audit(self,domain):
        if domain not in DOMAINS:raise ValueError('未知审计功能域')
        with self.locked('commit',exclusive=False,nonblock=False):
            self.pending(domain)
            return copy.deepcopy(self.records()[domain]['audit'])
    def pending(self,domain):
        io=self.io(domain)
        if (io.folder/'transaction.json').exists():
            j=io.read('transaction.json')
            if not isinstance(j,dict) or j.get('domain')!=domain:raise ValueError('事务功能域损坏')
            if j.get('status')!='COMMITTED':raise ValueError('功能域事务待恢复，禁止作为已提交审计读取')
            if set(j)!={'status','domain','version'} or type(j.get('version')) is not int or self.validate_record(io.read('state.json'),domain)['version']!=j['version']:raise ValueError('提交标记与状态版本不一致')
    def recover(self,domain):
        # Public recovery obeys the same lock order as a transaction.
        with self.locked(domain):
            with self.locked('commit',nonblock=False):self._recover_locked(domain)
    def _recover_locked(self,domain):
        io=self.io(domain);p=io.folder/'transaction.json'
        if not p.exists():return
        j=io.read('transaction.json')
        if not isinstance(j,dict) or j.get('domain')!=domain:raise ValueError('跨功能域或损坏事务，拒绝恢复')
        if j.get('status')=='COMMITTED':
            if set(j)!={'status','domain','version'} or type(j['version']) is not int:raise ValueError('提交标记损坏')
            if self.validate_record(io.read('state.json'),domain)['version']!=j['version']:raise ValueError('提交标记与状态版本不一致')
            return
        if set(j)!={'status','domain','before','before_digest','after','after_digest'} or j['status']!='PREPARED':raise ValueError('未知分域事务')
        after=self.validate_record(j['after'],domain)
        if type(j['before']) is not int or after['version']!=j['before']+1 or fingerprint(after)!=j['after_digest']:raise ValueError('恢复版本/内容不匹配')
        records=self.records();current=records[domain]
        if current['version']==after['version']:
            if current!=after:raise ValueError('同版本状态不一致')
        elif current['version']!=j['before'] or fingerprint(current)!=j['before_digest']:raise ValueError('恢复禁止覆盖已更新状态')
        candidate=copy.deepcopy(records);candidate[domain]=after;self.check_combination(candidate)
        io.write('state.json',after);io.write('transaction.json',dict(status='COMMITTED',domain=domain,version=after['version']))
    def transaction(self,request,expected,action,node,fields=None,interrupt=None):
        fields=copy.deepcopy(fields or {});domain=classify(action,fields)
        if not isinstance(request,str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}',request):raise ValueError('operation_id非法')
        if not isinstance(expected,dict) or set(expected)!=set(DOMAINS) or any(type(v) is not int or v<0 for v in expected.values()):raise ValueError('分域请求必须携带完整版本向量')
        if not self.enabled:raise ValueError('尚未显式初始化分域模型')
        self.prepare()
        with self.locked(domain):
            # Brief cross-domain validation/publication gate; no migration phase
            # execution or user interaction ever takes place inside this gate.
            with self.locked('commit',nonblock=False):
                self._recover_locked(domain);records=self.records();old=records[domain]
                payload=dict(domain=domain,expected=expected,action=action,node=node,fields=fields)
                fp=fingerprint(payload);prior=next((p for p in old['operations'] if p['operation_id']==request),None)
                if prior:
                    if prior['fingerprint']!=fp:raise ValueError('同域operation_id请求冲突')
                    return self.compose(records)
                if old['version']!=expected[domain] or records['registry']['version']!=expected['registry']:raise ValueError('功能域/物理登记CAS版本冲突')
                before=self.compose(records)
                from node_functions import change
                supplied=copy.deepcopy(fields)
                if action=='migration_step':supplied['operation_id']=request
                updated=change(before,action,node,supplied) if action!='initialize' else copy.deepcopy(before)
                if domain=='registry':
                    # Physical lifecycle changes cannot silently unload roles.
                    if any(before['nodes'][n]['production']!=updated['nodes'][n]['production'] or before['nodes'][n]['monitor']!=updated['nodes'][n]['monitor'] for n in 'ABCD'):raise ValueError('先分别卸载职能再调整物理生命周期')
                for other in DOMAINS:
                    if other!=domain and self.project(updated,other)!=self.project(before,other):raise ValueError('动作试图跨功能域写入，拒绝提交')
                new=copy.deepcopy(old);new['state']=self.project(updated,domain);new['version']+=1;new['generation']+=1
                new['operations'].append(dict(operation_id=request,fingerprint=fp))
                new['audit'].append(dict(timestamp=time.strftime('%Y-%m-%dT%H:%M:%S+00:00',time.gmtime()),operation_id=request,domain=domain,action=action,before_version=old['version'],after_version=new['version'],result='OFFLINE_COMMITTED',reason_code=None,source='local-offline-model'))
                self.validate_record(new,domain);records[domain]=new;result=self.check_combination(records)
                # A PREPARED opposite-domain intent reserves its safety result.
                # Check all pending after-images before publishing this domain,
                # so later recovery cannot violate colocation/lifecycle rules.
                pending_records=copy.deepcopy(records)
                for other in DOMAINS:
                    if other==domain:continue
                    other_io=self.io(other)
                    if (other_io.folder/'transaction.json').exists():
                        journal=other_io.read('transaction.json')
                        if not isinstance(journal,dict) or journal.get('domain')!=other:raise ValueError('对侧事务损坏')
                        if journal.get('status')=='PREPARED':
                            after=self.validate_record(journal['after'],other)
                            if fingerprint(after)!=journal.get('after_digest'):raise ValueError('对侧恢复镜像摘要损坏')
                            pending_records[other]=after
                        elif journal.get('status')!='COMMITTED':raise ValueError('对侧事务状态未知')
                self.check_combination(pending_records)
                io=self.io(domain);io.write('transaction.json',dict(status='PREPARED',domain=domain,before=old['version'],before_digest=fingerprint(old),after=new,after_digest=fingerprint(new)))
                if interrupt=='prepared':raise InterruptedError('分域PREPARED中断')
                io.write('state.json',new)
                if interrupt=='published':raise InterruptedError('分域发布后中断')
                io.write('transaction.json',dict(status='COMMITTED',domain=domain,version=new['version']))
                return result
    def check_combination(self,records):
        from node_functions import conflicts
        d=self.compose(records)
        problems=conflicts(d)
        if problems:raise ValueError('跨域组合资格冲突：'+';'.join(problems))
        return d

@@ABC_END

@@ABC_FILE modules/dynamic_preview.py 600 ceb376b214edb795f23f6b873ce040883fa1fca22c79d7975a77eaf2d84a684d
"""Read-only dynamic previews; all role/switch execution remains disabled."""
import json
from pathlib import Path
from topology_model import Store,targets,candidates
ROOT=Path(__file__).resolve().parents[1]

def summary(kind):
    functions_path=ROOT/'data/offline-functions/topology.json'
    if functions_path.exists() or functions_path.is_symlink() or (ROOT/'data/domain-model/enabled.json').exists():
        try:
            from node_functions import Store as FStore,targets as ftargets
            f=FStore(ROOT).load()
            return json.dumps(dict(mode='OFFLINE_FUNCTIONS',primary=f['primary'],primary_monitor=f['primary_monitor'],effective_backup=f['effective_backup'],nodes=f['nodes'],targets={n:ftargets(f,n) for n in f['nodes']},database=f['database_edges'],files=f['file_edges'],version=f['version']),ensure_ascii=False)
        except (OSError,ValueError,KeyError):return '功能模型损坏；禁止回退旧拓扑。'
    try:data=Store(ROOT).load()
    except (OSError,ValueError,KeyError):return '拓扑未初始化或无法确认；真实采集与生产切换未启用。'
    if kind=='monitor':return json.dumps(dict(mode='OFFLINE_MODEL',C=targets(data,'C'),D=targets(data,'D'),version=data['version']),ensure_ascii=False)
    return json.dumps(dict(mode='OFFLINE_MODEL',primary=data['primary'],targets=candidates(data),database=data['database_edges'],files=data['file_edges'],version=data['version']),ensure_ascii=False)

def main(kind):
    while True:
        print('========================================')
        print('C/D 节点独立监控与动态目标管理' if kind=='monitor' else '手动生产迁移与计划维护')
        print('========================================')
        print(summary(kind))
        print('仅离线只读预览；旧版真实采集未启用。兼容命令行采集不属于四节点菜单。' if kind=='monitor' else '仅动态预览；真实迁移待后续阶段开发。')
        if kind=='monitor':print('1. 查看 C 动态目标\n2. 查看 D 动态目标\n3. 查看已有状态（不采集）\n0. 返回主菜单')
        else:print('1. 查看合法目标及生产角色\n2. 查看数据库/文件同步方向\n3. 查看角色变更历史\n0. 返回主菜单')
        try:choice=input('请输入编号：')
        except EOFError:
            raise SystemExit(3 if kind=='monitor' else 0)
        if choice=='0':return
        if choice in ('1','2','3'):
            print(summary(kind))
            print('未创建、执行或取消任何真实任务。未执行任何业务操作。')
        else:print('输入错误；未创建、执行或取消任何真实任务。未执行任何业务操作。')

if __name__=='__main__':
    import sys
    print('未执行任何业务操作。')
    main(sys.argv[1])

@@ABC_END

@@ABC_FILE modules/functions_ui.py 600 f64c6dad96844c243c2f89a41ef2e6274904dfb871c737f3826c3114eebd384f
"""Symmetric offline function UI; never manages real services."""
from pathlib import Path
import json
from node_functions import Store,conflicts,targets
ROOT=Path(__file__).resolve().parents[1]

def main():
 s=Store(ROOT)
 while True:
  print('========================================\n             节点功能管理\n========================================')
  print('离线模型；生产/监控职能独立。真实安装、卸载、协调授权未启用。')
  print('1. 查看 A/B/C/D 全部功能\n2. 添加节点功能\n3. 删除节点功能\n4. 设置生产 Primary\n5. 设置生产 Replica\n6. 设置 Primary Monitor\n7. 设置 Backup Monitor\n8. 卸载指定节点的监控功能\n9. 卸载指定节点的生产功能\n10. 查看功能冲突及资源检查\n11. 查看功能变更历史\n12. 生产/监控优先级与迁移策略（离线）\n0. 返回主菜单')
  try:
   c=input('请输入编号：')
   if c=='0':return
   if c=='12':
    from policy_ui import main as policy_menu
    policy_menu();continue
   if c in ('1','10','11'):
    d=s.load();print(json.dumps(d['nodes'] if c=='1' else dict(policy=d['policy'],conflicts=conflicts(d),targets={n:targets(d,n) for n in d['nodes']}) if c=='10' else d['audit'],ensure_ascii=False,indent=2));continue
   if c not in ('2','3','4','5','6','7','8','9'):print('无效编号');continue
   print('旧版兼容菜单仅保留只读查看；写入请使用正式主菜单2/3/4/6/9，禁止绕过新拓扑预检。')
   continue
  except EOFError:return
  except (OSError,ValueError,KeyError) as e:print('未配置或安全拒绝：'+str(e))

if __name__=='__main__':main()

@@ABC_END

@@ABC_FILE modules/management_model.py 600 f3bb53c24e6c9cc534285ce83c981d52edf6ffbbfb788826ba1a356a4daa2c30
"""Stage-two extensions of schema3. Pure offline decisions, never an executor.
Optional fields live in the existing functions topology, not a second registry.
"""
import copy
import ipaddress
import re
import time
from pathlib import PurePosixPath

AUTO_STAGES=tuple('AUTO_MIGRATION_TRIGGER TARGET_PRECHECK TARGET_READY_CHECK MYSQL_VERSION_CHECK GTID_CONSISTENCY_CHECK REPLICATION_CATCHUP FILE_SYNC_CHECK MYSQL_CONFIG_CHECK WRITE_BARRIER FINAL_DATA_CONSISTENCY_CHECK OLD_PRIMARY_FENCING NEW_PRIMARY_ACTIVATION REPLICATION_RECONFIGURATION FILE_SYNC_DIRECTION_RECONFIGURATION MYSQL_CONFIG_DIRECTION_RECONFIGURATION HEALTH_CHECK TOPOLOGY_COMMIT RESUME_APPLICATION_WRITES AUTO_MIGRATION_COMPLETED'.split())
CHECKS=('identity','production_eligible','mysql_version','gtid_lineage','caught_up','files','mysql_config','resources','fencing_possible','no_conflict')
STAGE_PROOF=dict(TARGET_PRECHECK='identity',TARGET_READY_CHECK='production_eligible',MYSQL_VERSION_CHECK='mysql_version',GTID_CONSISTENCY_CHECK='gtid_lineage',REPLICATION_CATCHUP='caught_up',FILE_SYNC_CHECK='files',MYSQL_CONFIG_CHECK='mysql_config',WRITE_BARRIER='write_barrier',FINAL_DATA_CONSISTENCY_CHECK='final_gtid',OLD_PRIMARY_FENCING='fenced',NEW_PRIMARY_ACTIVATION='activation',REPLICATION_RECONFIGURATION='database_topology',FILE_SYNC_DIRECTION_RECONFIGURATION='file_topology',MYSQL_CONFIG_DIRECTION_RECONFIGURATION='config_topology',HEALTH_CHECK='health',TOPOLOGY_COMMIT='durable_commit',RESUME_APPLICATION_WRITES='resume_writes')
EXCLUDES=['/home/web/log/','/home/web/mysql/','/home/web/redis/']
NODE_KEYS={'server_id','address','datadir','socket','port','bind-address'}
SENSITIVE=re.compile(r'password|token|secret|private_key',re.I)


def defaults():
    return dict(production_priority=list('ABCD'),monitor_priority=list('ABC'),monitor_bindings={},mysql={},ssh={},environment={},mysql_config=dict(public={},nodes={},sensitive_ref=None,files=[]),sync=dict(root='/home/web/',excludes=EXCLUDES.copy(),include_beifen=True,delete=False,follow_external_symlinks=False,debounce_seconds=5,retry=3,redis_usage='UNCONFIRMED',jobs={}),migration_tasks={},maintenance={},auto_policy=dict(enabled=False,target=None,start_at=None),production_term=0,monitor_term=0)


def settings(d):
    return copy.deepcopy(d.get('management',defaults()))


def text(value,limit=256):
    if not isinstance(value,str) or not value or len(value)>limit or any(ord(c)<32 or ord(c)==127 for c in value):raise ValueError('文本为空、过长或包含控制字符')
    return value


def reference(value):
    text(value)
    if not re.fullmatch(r'[A-Za-z0-9_./:-]{1,256}',value):raise ValueError('认证引用格式非法；仅填写受控凭据引用，不提交密码')
    return value


def clean(value):
    if isinstance(value,dict):
        for k,v in value.items():
            if not isinstance(k,str) or (SENSITIVE.search(k) and k not in ('sensitive_ref',)):raise ValueError('禁止在离线模型提交明文敏感字段')
            clean(v)
    elif isinstance(value,list):
        for v in value:clean(v)
    elif value is not None and type(value) not in (str,int,float,bool):raise ValueError('JSON字段类型不支持')


def registered(d):
    return [n for n,x in d['nodes'].items() if x.get('identity') and x['lifecycle']!='Retired']


def active(d,n):
    if n not in registered(d) or d['nodes'][n]['lifecycle']!='Active':raise ValueError('节点未登记、Joining、维护、隔离或退役；禁止绑定/迁移')


def resource_ok(n):
    r=n.get('resources') or {}
    return all(type(r.get(k)) in (int,float) and r[k]>=v for k,v in (('cpu',2),('memory_mib',1024),('disk_mib',1024))) and type(r.get('checked_at')) is int and 0<=int(time.time())-r['checked_at']<=300 and r.get('reliable_state') is True and r.get('isolated_processes') is True and all(type(r.get(k)) in (int,float) and 0<=r[k]<=80 for k in ('cpu_percent','io_percent','network_percent'))


def mysql_validate(v):
    required={'address','port','product','version','server_id','gtid','binlog','user','auth_ref','sources'}
    if not isinstance(v,dict) or not required<=v.keys():raise ValueError('MySQL通信字段不完整')
    text(v['address']);text(v['version'])
    if v['product'] not in ('MySQL','MariaDB') or type(v['port']) is not int or not 1<=v['port']<=65535 or type(v['server_id']) is not int or not 1<=v['server_id']<=4294967295:raise ValueError('MySQL类型/端口/server_id非法')
    if type(v['gtid']) is not bool or type(v['binlog']) is not bool or v['user'].lower()=='root':raise ValueError('禁止root复制账号，GTID/Binlog必须bool')
    text(v['user'],64);reference(v['auth_ref'])
    if v.get('least_privilege') is not True or v.get('protected_network') is not True:raise ValueError('必须声明最小权限和受保护网络（离线声明非实测）')
    if not isinstance(v['sources'],list) or not v['sources']:raise ValueError('复制来源白名单不能为空')
    for s in v['sources']:
        net=ipaddress.ip_network(s,strict=False)
        if net.prefixlen==0:raise ValueError('禁止全网来源')


def environment_plan(profile):
    if not isinstance(profile,dict):raise ValueError('环境资料必须JSON对象')
    distro=profile.get('id');version=profile.get('version');installed=profile.get('installed',[])
    if distro not in ('debian','ubuntu') or not isinstance(version,str) or not re.fullmatch(r'\d+(?:\.\d+)*',version):raise ValueError('不支持或未知发行版，阻止安装计划')
    major=int(version.split('.')[0])
    if (distro=='debian' and major<11) or (distro=='ubuntu' and major<20):raise ValueError('系统版本不兼容')
    if not isinstance(installed,list) or not all(isinstance(x,str) for x in installed):raise ValueError('组件清单非法')
    missing=[p for p in ('python3','bash','util-linux','coreutils','openssh-client','rsync') if p not in installed]
    issues=[k for k,minv in (('cpu',2),('memory_mib',1024),('disk_mib',1024)) if type(profile.get(k)) not in (int,float) or profile[k]<minv]
    if profile.get('network') is not True:issues.append('network')
    if profile.get('permissions') is not True:issues.append('permissions')
    if profile.get('runtime_compatible') is not True:issues.append('runtime_compatible')
    return dict(mode='OFFLINE_MODEL',id=distro,version=version,missing=missing,blocked=issues,packages=missing,services=['监控服务定义预览；不创建/启动'],directories=['/home/a-b-c-d-MySQL:0700','data:0700','logs:0700'],permissions='程序0700 / 配置0600',status='环境缺失' if missing or issues else '离线模型',profile=copy.deepcopy(profile),checked_at=int(time.time()))


def local_environment():
    """Read this host only; never pretend it describes a remote bound node."""
    from pathlib import Path
    import os,shutil
    release={}
    for line in Path('/etc/os-release').read_text().splitlines():
        if '=' in line:
            k,v=line.split('=',1);release[k]=v.strip('"')
    mem=next(int(x.split()[1])//1024 for x in Path('/proc/meminfo').read_text().splitlines() if x.startswith('MemTotal:'))
    return dict(scope='本机只读检测；不代表远程节点',id=release.get('ID'),version=release.get('VERSION_ID'),cpu=os.cpu_count(),memory_mib=mem,disk_mib=shutil.disk_usage('/home').free//1048576,installed=[p for p in ('python3','bash','util-linux','coreutils','openssh-client','rsync') if shutil.which({'util-linux':'flock','coreutils':'stat','openssh-client':'ssh'}.get(p,p))],network='尚未主动探测',permissions='需按目标节点单独检查',runtime_compatible='尚未核验')


def edges(d,primary=None):
    source=primary or d['primary']
    if not source:return []
    if d['nodes'][source]['lifecycle']!='Active' or source in d.get('production_isolated',[]):raise ValueError('隔离/非Active节点不能作为有效同步源')
    return [[source,n] for n in settings(d)['production_priority'] if n!=source and d['nodes'][n]['lifecycle']=='Active' and n not in d.get('production_isolated',[]) and d['nodes'][n]['production'] in ('Replica','Primary')]


def channels(d,primary=None):
    e=edges(d,primary);m=settings(d)
    return dict(mode='OFFLINE_MODEL',primary=primary or d['primary'],database=[dict(source_node=a,target_node=b,edge_id=a+'-'+b,topology_version=d['version'],replication_status='离线模型',gtid_status='尚未检查',last_checked_at=None,error=None,history=[]) for a,b in e],files=[dict(source=a,target=b,status='尚未检查',root='/home/web/') for a,b in e],mysql_config=[dict(source=a,target=b,status='尚未检查',public=m['mysql_config']['public'],node_specific=m['mysql_config']['nodes'].get(b,{}),sensitive_ref=m['mysql_config']['sensitive_ref']) for a,b in e],overall='不完整；离线模型未证明三通道健康')


def precheck(d,target,proof):
    problems=[];m=settings(d)
    if d['primary'] is None:problems.append('当前Primary身份不明确')
    if target not in registered(d) or d['nodes'][target]['lifecycle']!='Active' or target in d.get('production_isolated',[]) or not d['nodes'][target]['production'] or target==d['primary']:problems.append('目标生产资格/身份无效')
    if not resource_ok(d['nodes'][target]):problems.append('目标资源证据不足或过期')
    for k in CHECKS:
        if proof.get(k) is not True:problems.append(k+'未通过')
    if any(t['status'] not in ('SIMULATED_COMPLETED','CANCELLED','PERMANENT') for t in m['migration_tasks'].values()):problems.append('存在冲突迁移任务')
    return dict(mode='OFFLINE_MODEL',passed=not problems,problems=problems,topology_version=d['version'],channels=channels(d,target))


def sync_preview(sync,manifest):
    if sync['redis_usage'] not in ('CACHE','SEPARATE_PROTECTION'):raise ValueError('必须先检查Redis Session/队列/持久状态并制定保护方案')
    if not isinstance(manifest,dict):raise ValueError('文件清单必须对象')
    files=manifest.get('files',[])
    if not files:raise ValueError('空源保护')
    result=[]
    for f in files:
        p=PurePosixPath(f['path'])
        if not p.is_absolute() or '..' in p.parts or not str(p).startswith('/home/web/'):raise ValueError('同步路径越界')
        if f.get('external_symlink'):raise ValueError('禁止跟随外部符号链接')
        if any(str(p)==e.rstrip('/') or str(p).startswith(e) for e in EXCLUDES):continue
        if f.get('stable') is not True or f.get('quiet_seconds',0)<5:raise ValueError('文件尚未写入完成或未达到5秒防抖')
        result.append(dict(path=str(p),transfer='临时文件→完整性校验→原子替换',retry=sync['retry'],resume='校验源版本，源变化补跑；周期扫描补偿'))
    deletes=manifest.get('deletions',[])
    if deletes:
        if not sync['delete'] or manifest.get('second_confirmation') is not True:raise ValueError('删除同步默认关闭，需独立预览和二次确认')
        if len(deletes)/max(len(files),1)>0.1:raise ValueError('删除比例保护')
        for path in deletes:
            if not isinstance(path,str) or '..' in PurePosixPath(path).parts or not path.startswith('/home/web/') or any(path==e.rstrip('/') or path.startswith(e) for e in EXCLUDES):raise ValueError('删除路径保护')
    return dict(mode='OFFLINE_MODEL',files=result,deletions=deletes,executed=False)


def validate_management(d):
    if 'management' not in d:return
    m=d['management']
    if not isinstance(m,dict) or set(m)!=set(defaults()):raise ValueError('管理模型结构损坏')
    for key,ids in (('production_priority','ABCD'),('monitor_priority','ABC')):
        if not isinstance(m[key],list) or len(m[key])!=len(ids) or set(m[key])!=set(ids):raise ValueError('优先级必须完整且不重复')
    for key in ('mysql','ssh','environment','monitor_bindings','migration_tasks','maintenance'):
        if not isinstance(m[key],dict):raise ValueError('嵌套管理结构损坏')
    if any(n not in 'ABCD' or len(n)!=1 for n in (*m['mysql'],*m['ssh'],*m['environment'])):raise ValueError('通信/环境节点非法')
    for v in m['mysql'].values():mysql_validate(v)
    ids=[v['server_id'] for v in m['mysql'].values()]
    if len(ids)!=len(set(ids)):raise ValueError('server_id冲突')
    bound=[]
    for slot,v in m['monitor_bindings'].items():
        if slot not in 'ABC' or len(slot)!=1 or not isinstance(v,dict) or v.get('node') not in registered(d) or not d['nodes'][v['node']]['monitor']:raise ValueError('逻辑监控绑定损坏')
        bound.append(v['node'])
    if len(bound)!=len(set(bound)):raise ValueError('同物理节点不能伪装多个独立监控主控')
    s=m['sync']
    if not isinstance(s,dict) or set(s)!=set(defaults()['sync']) or s['root']!='/home/web/' or s['excludes']!=EXCLUDES or s['include_beifen'] is not True or s['follow_external_symlinks'] is not False or type(s['delete']) is not bool or s['debounce_seconds']!=5 or type(s['retry']) is not int or not 1<=s['retry']<=100 or not isinstance(s['jobs'],dict):raise ValueError('同步范围或安全策略损坏')
    c=m['mysql_config']
    if not isinstance(c,dict) or set(c)!=set(defaults()['mysql_config']) or not isinstance(c['public'],dict) or not isinstance(c['nodes'],dict) or not isinstance(c['files'],list):raise ValueError('专用配置结构损坏')
    if NODE_KEYS & set(c['public']):raise ValueError('节点专属参数不得进入公共模板')
    if c['sensitive_ref'] is not None:reference(c['sensitive_ref'])
    for n,v in c['nodes'].items():
        if n not in 'ABCD' or len(n)!=1 or not isinstance(v,dict):raise ValueError('节点专属配置非法')
    for path in c['files']:
        if not isinstance(path,str) or not path.startswith('/etc/mysql/') or '..' in PurePosixPath(path).parts:raise ValueError('MySQL配置路径非法')
    for t in m['migration_tasks'].values():
        if not isinstance(t,dict) or t.get('stage') not in AUTO_STAGES or t.get('status') not in ('SIMULATING','MANUAL_REQUIRED','SIMULATED_COMPLETED','CANCELLED','PERMANENT') or not isinstance(t.get('trace'),list) or t.get('target') not in 'ABCD' or t.get('source') not in 'ABCD' or type(t.get('topology_version')) is not int or t.get('kind') not in ('manual','temporary','permanent','automatic','failback'):raise ValueError('迁移任务结构损坏')
        if t.get('mode')!='OFFLINE_MODEL' or type(t.get('duration')) is not int or t['duration']<=0 or type(t.get('write_barrier')) is not bool or type(t.get('fenced')) is not bool:raise ValueError('迁移安全字段损坏')
        if not isinstance(t.get('operation_id'),str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}',t['operation_id']):raise ValueError('任务operation_id非法')
        stages=[x.get('stage') for x in t['trace']]
        if stages!=list(AUTO_STAGES[:len(stages)]) or not stages or t['stage']!=stages[-1]:raise ValueError('阶段跳跃或历史损坏')
        for x in t['trace']:
            if not isinstance(x,dict) or type(x.get('at')) is not int or not isinstance(x.get('operation_id'),str):raise ValueError('检查点记录损坏')
    if any(type(m[k]) is not int or m[k]<0 for k in ('production_term','monitor_term')):raise ValueError('任期非法')
    if not isinstance(m['auto_policy'],dict) or set(m['auto_policy'])!=set(defaults()['auto_policy']) or type(m['auto_policy']['enabled']) is not bool or m['auto_policy']['target'] not in (None,*'ABCD'):raise ValueError('自动策略非法')
    clean(m)


def change(d,action,node,f):
    from node_functions import change as base_change
    m=d.setdefault('management',defaults());n=d['nodes'][node];now=int(time.time());clean(f)
    if action=='register':
        if n.get('identity'):raise ValueError('物理节点已登记，不能重复登记')
        identity=text(f['identity']);address=text(f['address'])
        if any(x.get('identity')==identity or x.get('address')==address for x in d['nodes'].values()):raise ValueError('相同物理身份/连接地址重复登记')
        n.update(identity=identity,address=address,remark=text(f['remark']),lifecycle='Joining')
    elif action=='remark':
        if node not in registered(d):raise ValueError('节点未登记')
        n['remark']=text(f['remark'])
    elif action=='qualify':
        if n['lifecycle']!='Joining' or not n.get('identity') or f.get('identity_verified') is not True or f.get('data_verified') is not True:raise ValueError('Joining身份/数据验证不完整')
        n['resources']=copy.deepcopy(f['resources'])
        if not resource_ok(n):raise ValueError('资源/隔离证据不完整')
        n['lifecycle']='Active'
    elif action=='lifecycle':
        if n['production']=='Primary' or n['monitor']=='Primary Monitor':raise ValueError('先安全交接Primary职能')
        if f.get('lifecycle') not in ('Maintenance','Unreachable','Active'):raise ValueError('生命周期非法')
        if n['lifecycle'] in ('Joining','Retired'):raise ValueError('必须重新完成加入资格检查')
        n['lifecycle']=f['lifecycle']
    elif action=='production_bind':
        active(d,node)
        if n['production']:raise ValueError('已绑定生产功能')
        if not resource_ok(n) or node not in m['mysql']:raise ValueError('资源/通信配置未满足资格')
        d=base_change(d,'replica',node,{});m=d['management']
    elif action=='production_unbind':
        if not n['production']:raise ValueError('不存在生产绑定')
        d=base_change(d,'remove_production',node,{});m=d['management']
    elif action=='monitor_bind':
        active(d,node);slot=f['slot']
        if slot not in 'ABC' or len(slot)!=1 or slot in m['monitor_bindings'] or any(v['node']==node for v in m['monitor_bindings'].values()):raise ValueError('监控槽位/物理节点重复绑定')
        plan=environment_plan(f['profile']);m['environment'][node]=plan
        if plan['blocked']:raise ValueError('环境资源/权限不满足，不能绑定')
        if not resource_ok(n):raise ValueError('监控资源检查未通过')
        d=base_change(d,'backup_monitor',node,{});m=d['management'];m['monitor_bindings'][slot]=dict(node=node,environment='环境缺失' if plan['missing'] else '离线模型',ready=not plan['missing'])
    elif action=='monitor_unbind':
        slot=f['slot'];v=m['monitor_bindings'].get(slot)
        if not v or v['node']!=node:raise ValueError('监控绑定不存在')
        if n['monitor']=='Primary Monitor':raise ValueError('先安全交接Primary Monitor')
        del m['monitor_bindings'][slot]
        d=base_change(d,'remove_monitor',node,{});m=d['management']
    elif action=='monitor_handoff':
        slot=f['slot'];v=m['monitor_bindings'].get(slot)
        if not v or v['node']!=node or not v['ready']:raise ValueError('监控绑定/环境不就绪')
        if not all(f.get(k) is True for k in ('quorum','old_revoked','state_transfer','health','resources')):raise ValueError('协调权交接条件不足')
        d=base_change(d,'primary_monitor',node,dict(offline_handoff_verified=True));m=d['management'];m['monitor_term']+=1
    elif action=='priorities':
        for key in ('production_priority','monitor_priority'):
            if key in f:m[key]=copy.deepcopy(f[key])
    elif action=='mysql':
        if node not in registered(d):raise ValueError('请先登记节点')
        mysql_validate(f);m['mysql'][node]=copy.deepcopy(f)
    elif action=='mysql_remove':
        if n['production']:raise ValueError('先解除生产绑定再删除通信')
        m['mysql'].pop(node,None)
    elif action=='ssh':
        if node not in registered(d):raise ValueError('请先登记节点')
        if set(f)!={'address','port','user','key_ref','known_hosts_ref'} or type(f['port']) is not int or not 1<=f['port']<=65535:raise ValueError('SSH字段/端口非法')
        for k in ('address','user'):text(f[k])
        reference(f['key_ref']);reference(f['known_hosts_ref']);m['ssh'][node]=copy.deepcopy(f)
    elif action=='ssh_remove':m['ssh'].pop(node,None)
    elif action=='sync':
        if 'root' in f and f['root']!='/home/web/':raise ValueError('网站根目录固定')
        m['sync'].update(copy.deepcopy(f))
    elif action=='sync_job':
        preview=sync_preview(m['sync'],f['manifest']);job=text(f['job'],64)
        m['sync']['jobs'][job]=dict(status='离线模型待执行',preview=preview,progress=0,attempts=0,source_version=d['version'],paused=False)
    elif action=='sync_pause':
        job=m['sync']['jobs'][f['job']]
        if type(f['paused']) is not bool:raise ValueError('暂停必须bool')
        job['paused']=f['paused']
    elif action=='mysql_config':m['mysql_config'].update(copy.deepcopy(f))
    elif action=='environment':m['environment'][node]=environment_plan(f)
    elif action=='environment_simulate':
        plan=m['environment'][node]
        if type(f.get('success')) is not bool:raise ValueError('模拟结果必须bool')
        plan['status']='离线模型' if f['success'] and not plan['blocked'] else '检查失败'
        # Simulated package installation never proves a real host ready.
        for v in m['monitor_bindings'].values():
            if v['node']==node:v.update(ready=f['success'] and not plan['blocked'],environment=plan['status'])
    elif action=='auto_policy':m['auto_policy'].update(copy.deepcopy(f))
    elif action=='maintenance':
        if not isinstance(f.get('start_at'),int) or not isinstance(f.get('end_at'),int) or f['start_at']>=f['end_at']:raise ValueError('维护时间范围非法')
        if f.get('target') not in 'ABCD' or node!=d['primary']:raise ValueError('维护源/接管目标无效')
        pre=precheck(d,f['target'],f.get('proof',{}))
        m['maintenance'][f.get('id','maintenance')]=dict(source=node,target=f['target'],start_at=f['start_at'],end_at=f['end_at'],status='PLANNED' if pre['passed'] else 'WAITING_SAFE_WINDOW',precheck=pre)
    elif action=='maintenance_cancel':
        task=m['maintenance'][f['id']]
        if task['start_at']<=now or task['status'] not in ('PLANNED','WAITING_SAFE_WINDOW'):raise ValueError('仅可取消尚未开始维护')
        task['status']='CANCELLED'
    elif action=='migration_create':
        target=node;kind=f.get('kind','temporary');pre=precheck(d,target,f.get('proof',{}))
        if kind not in ('manual','temporary','permanent','automatic','failback') or not pre['passed']:raise ValueError('迁移预检拒绝：'+'；'.join(pre['problems']))
        if kind=='automatic' and (not m['auto_policy']['enabled'] or m['auto_policy']['target']!=target or type(m['auto_policy']['start_at']) is not int or now<m['auto_policy']['start_at']):raise ValueError('自动策略未启用、目标不一致或未到维护时间')
        if kind=='permanent' and f.get('second_confirmation') is not True:raise ValueError('永久迁移必须二次确认')
        duration=f.get('duration',300)
        if type(duration) is not int or not 1<=duration<=31536000:raise ValueError('临时期限越界')
        tid=text(f['task'],64)
        if tid in m['migration_tasks']:raise ValueError('迁移任务已存在')
        m['migration_tasks'][tid]=dict(operation_id=tid,mode='OFFLINE_MODEL',source=d['primary'],target=target,kind=kind,duration=duration,effective_at=None,expires_at=None,stage=AUTO_STAGES[0],status='SIMULATING',error=None,topology_version=d['version']+1,write_barrier=False,fenced=False,trace=[dict(stage=AUTO_STAGES[0],operation_id=tid,at=now,error=None)])
    elif action in ('migration_step','migration_cancel','migration_deadline','expiry_assess'):
        t=m['migration_tasks'][f['task']]
        if action=='migration_cancel':
            if t['stage']!=AUTO_STAGES[0] or t['status']!='SIMULATING':raise ValueError('已有执行意图，需人工对账，不可取消')
            t['status']='CANCELLED'
        elif action=='migration_deadline':
            if t['kind']!='temporary' or t['effective_at'] is not None or t['stage']!=AUTO_STAGES[0]:raise ValueError('仅修改尚未生效临时期限')
            if type(f.get('duration')) is not int or not 1<=f['duration']<=31536000:raise ValueError('期限非法')
            t['duration']=f['duration']
        elif action=='expiry_assess':
            if t['kind']!='temporary' or t['expires_at'] is None or now<t['expires_at'] or t['status']!='SIMULATED_COMPLETED':raise ValueError('尚未到期、非临时或需人工处理')
            # Assessment only; never changes roles or clears a failure.
            t['return_assessment']=dict(at=now,result='WAITING_SAFE_WINDOW',reason='到期仅评估；需独立三通道/隔离证据及手动回切任务')
        else:
            if t['status']!='SIMULATING':raise ValueError('任务已结束或粘滞安全暂停，禁止自动继续')
            if t['topology_version']!=d['version']:raise ValueError('任务拓扑版本漂移，需人工对账')
            stage=AUTO_STAGES[AUTO_STAGES.index(t['stage'])+1];key=STAGE_PROOF.get(stage)
            proof=f.get('proof',{})
            failed=key and proof.get(key) is not True
            if stage=='NEW_PRIMARY_ACTIVATION' and not (t['write_barrier'] and t['fenced']):failed=True
            if stage=='RESUME_APPLICATION_WRITES' and d['primary']!=t['target']:failed=True
            if failed:
                t.update(status='MANUAL_REQUIRED',error=stage+'检查失败；不提升、不恢复写入')
            else:
                t['stage']=stage
                if stage=='WRITE_BARRIER':t['write_barrier']=True
                if stage=='OLD_PRIMARY_FENCING':t['fenced']=True
                if stage=='TOPOLOGY_COMMIT':
                    old=d['nodes'][t['source']];old['production']='Replica'
                    if 'domain_versions' in d:
                        d['production_isolated']=list(dict.fromkeys(d.get('production_isolated',[])+[t['source']]))
                    else:old['lifecycle']='Unreachable'
                    d['nodes'][t['target']]['production']='Primary';d['primary']=t['target'];m['production_term']+=1
                if stage==AUTO_STAGES[-1]:
                    t.update(status='SIMULATED_COMPLETED',effective_at=now,expires_at=now+t['duration'] if t['kind']=='temporary' else None)
            t['trace'].append(dict(stage=stage,operation_id=f['operation_id'],at=now,error=t['error'])) if not failed else None
            t['topology_version']=d['version']+1
    else:raise ValueError('未知管理动作')
    return d

@@ABC_END

@@ABC_FILE modules/management_ui.py 600 f4efe8efc744e73a0f5e9abf31d775c1ac89a05feefb60a1ed98c761d074fe1a
"""Formal stage-two UI. All observations and submissions explicitly offline.
No subprocess/network executors. Ctrl-D/:quit cancels without staged writes.
"""
import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import uuid
import getpass
from node_functions import Store,initial,validate,conflicts
from management_model import settings,registered,channels,precheck,environment_plan,sync_preview,CHECKS,AUTO_STAGES
from menu_spec import MAIN,MENUS,CHILDREN
ROOT=Path(__file__).resolve().parents[1]

class Cancel(Exception):pass

def ask(prompt):
    value=input(prompt)
    if value in (':quit',':cancel','退出配置向导'):raise Cancel()
    return value


def pairs(items):
    d={}
    for k,v in items:
        if k in d:raise ValueError('重复JSON键')
        d[k]=v
    return d


def obj(prompt='请输入离线JSON（仅凭据引用，不含密码；:quit取消）：'):
    d=json.loads(ask(prompt),object_pairs_hook=pairs,parse_constant=lambda _:(_ for _ in ()).throw(ValueError('非有限数字')))
    if not isinstance(d,dict):raise ValueError('必须输入JSON对象')
    return d


def show(d):print(json.dumps(d,ensure_ascii=False,indent=2))


def clear():
    if sys.stdout.isatty() and os.environ.get('TERM','dumb')!='dumb':print('\033[2J\033[H',end='')


def health_status(value):
    colors={'暂无（状态缺失、过期或无法确认）':'31','正常':'32','异常':'33'}
    if value in colors and sys.stdout.isatty() and os.environ.get('TERM','dumb')!='dumb' and 'NO_COLOR' not in os.environ:
        return '\033['+colors[value]+'m'+value+'\033[0m'
    return value


def unknown_status():
    return health_status('暂无（状态缺失、过期或无法确认）')


class UI:
    def __init__(self,root=ROOT,dry=False):
        self.root=Path(root);self.store=Store(root);self.dry=dry;self.target=None;self.duration=300;self.maintenance={}
    def load(self):
        from domain_store import DomainStore
        if DomainStore(self.root).enabled:return self.store.load()
        if (self.store.folder/'topology.json').exists() or (self.store.folder/'topology.json').is_symlink():return self.store.load()
        legacy=self.root/'data/offline-topology/topology.json'
        if legacy.exists() or legacy.is_symlink():raise ValueError('旧拓扑已存在：保留原数据，不自动创建竞争模型；需管理员审核显式迁移')
        return initial()
    def submit(self,action,node,fields):
        d=self.load();request=ask('operation_id（留空生成）：') or uuid.uuid4().hex
        from node_functions import change
        supplied=copy.deepcopy(fields)
        if action=='migration_step':supplied['operation_id']=request
        preview=change(d,action,node,supplied)
        show(dict(mode='OFFLINE_MODEL',action=action,node=node,before_version=d['version'],preview=preview))
        print('预览仅修改本地离线模型；不安装/卸载真实服务，不修改相反职能。')
        if self.dry:print('Dry-run：不创建锁、审计或配置。');return
        if ask('第一次确认，输入精确小写 yes：')!='yes':raise Cancel()
        if ask('第二次确认，输入精确小写 yes：')!='yes':raise Cancel()
        from domain_store import DomainStore
        domains=DomainStore(self.root)
        if not domains.enabled and not (self.store.folder/'topology.json').exists():
            domains.enable()
            expected=domains.load()['domain_versions']
        else:expected=d.get('domain_versions',d['version'])
        result=self.store.transaction(request,expected,action,node,fields)
        print('离线模型已提交；version='+str(result['version'])+'；不代表真实运行正常。')
    def pick(self,kind='registered'):
        d=self.load();m=settings(d)
        nodes=[n for n,x in d['nodes'].items() if x.get('identity')] if kind=='rejoin' else registered(d)
        if kind=='production':nodes=[n for n in nodes if d['nodes'][n]['production']]
        elif kind=='eligible':nodes=[n for n in nodes if d['nodes'][n]['lifecycle']=='Active' and d['nodes'][n]['production']]
        elif kind=='mysql':nodes=[n for n in nodes if n in m['mysql']]
        elif kind=='ssh':nodes=[n for n in nodes if n in m['ssh']]
        print('当前已登记节点：' if kind=='registered' else '当前已存在/符合条件的配置：')
        for i,n in enumerate(nodes,1):
            x=d['nodes'][n];print(f"{i}. 物理节点 {n}：{x.get('remark','未设置备注')} / {x['lifecycle']} / 生产={x['production']} / 监控={x['monitor']}（离线模型）")
        print('0. 返回')
        v=ask('请选择节点编号：')
        if v=='0':raise Cancel()
        if not v.isascii() or not v.isdigit() or len(v)>2 or not 1<=int(v)<=len(nodes):raise ValueError('无效节点编号；不接受不存在节点')
        return nodes[int(v)-1]
    def panel(self):
        try:model=self.load();management=settings(model)
        except (ValueError,OSError,KeyError,TypeError):model=None;management=None
        clear();print('========================================');print('      A-B-C-D MySQL 四节点主备容灾管理系统');print('========================================');print('实时节点状态：')
        for label in ('生产 A','备份 B','备份 C','备份 D'):
            node=model['nodes'][label[-1]] if model else None
            status=unknown_status()
            if node and node.get('identity'):status='离线模型（'+str(node['production'])+' / '+node['lifecycle']+'；真实状态未知）' if node['production'] else '未绑定（'+node['lifecycle']+'；真实状态未知）'
            print(label+'：'+status)
        print('------------------------');print('逻辑主控状态：')
        for n in 'ABC':
            binding=management['monitor_bindings'].get(n) if management else None
            print('监控 '+n+'：'+(binding['environment']+'（绑定物理'+binding['node']+'；真实状态未知）' if binding else unknown_status()))
        print('------------------------');print('项目目录：'+str(self.root))
        if any((self.root/'data'/name).exists() for name in ('deployment.json','active-state.json','executor-state.json')):print('部署阶段待核验：业务启用状态无法确认')
        elif not (self.root/'scripts/coordinator_plan.sh').is_file():print('项目阶段：暂无')
        else:print('离线架构阶段：业务操作未启用')
        print('========================================')
        for i,name in enumerate(MAIN,1):print(str(i)+'. '+name)
        print('------------------------');print('0. 退出程序');print('------------------------')
    def loop(self,key=None):
        while True:
            if key is None:self.panel()
            else:
                clear();title,items=MENUS[key];print('【'+title+'】');print('阶段二离线模型；未执行任何业务操作。:quit 取消向导。')
                if key.startswith('9') or key=='10':print('未创建、执行或取消任何真实任务。')
                for i,name in enumerate(items,1):print(str(i)+'. '+name)
                print('0. '+('返回第7项' if key=='7c' else '返回第9项' if key.startswith('9') and key!='9' else '返回主菜单'))
            try:
                v=ask('请输入编号：')
                if v=='0':
                    if key is None:print('已退出')
                    return
                if key is None:
                    if v not in tuple(str(i) for i in range(1,11)):print('输入错误，请输入 0—10。');continue
                    self.loop(v);continue
                if not v.isascii() or not v.isdigit() or len(v)>2 or not 1<=int(v)<=len(MENUS[key][1]):print('无效编号');continue
                choice=int(v)
                if (key,choice) in CHILDREN:self.loop(CHILDREN[key,choice]);continue
                self.action(key,choice)
                ask('按回车继续...')
            except EOFError:return
            except Cancel:print('已取消；未提交本次暂存。')
            except (ValueError,OSError,KeyError,TypeError,IndexError) as e:print('安全拒绝 / 状态未知：'+str(e))
    def cf(self,c):
        from cloudflare_config import Cloudflare
        cf=Cloudflare(self.root)
        if c==1:show(cf.status());return
        if c==4:show(cf.check());return
        if c==7:print('状态未知：阶段二未获取真实DNS记录；不联网、不修改DNS。');return
        if c==8:show(cf.history());return
        raw,values=cf.read();changes={}
        if c in (2,3):
            if c==2 and values.get('CF_API_TOKEN'):raise ValueError('Token已存在，请编辑；不建立第二份配置')
            token=getpass.getpass('Cloudflare API Token（隐藏输入；:quit取消）：')
            if token in (':quit',':cancel','退出配置向导'):raise Cancel()
            changes['CF_API_TOKEN']=token
        elif c==5:changes['CF_ZONE_ID']=ask('DNS Zone ID：')
        elif c==6:changes['CF_DOMAIN']=ask('域名：')
        elif c==9:changes={'CF_API_TOKEN':'','CF_ZONE_ID':'','CF_DOMAIN':''}
        show(dict(fields=sorted(changes),token='隐藏；不输出',impact='仅统一受保护配置；不修改DNS'))
        if self.dry:print('Dry-run：未写配置。');return
        if ask('第一次确认，输入yes：')!='yes' or ask('第二次确认，输入yes：')!='yes':raise Cancel()
        request=ask('Cloudflare operation_id（留空生成）：') or uuid.uuid4().hex
        cf.update(changes,hashlib.sha256(raw.encode()).hexdigest(),request);print('受保护配置已更新；未修改真实DNS。operation_id='+request)
    def bindings(self,key,c):
        d=self.load();m=settings(d)
        if key=='3':
            print('【添加生产节点绑定】' if c==1 else '【删除 / 卸载生产与备用配置】')
            print('生产优先级：'+' ≥ '.join(m['production_priority']))
            if c==1 and ask('修改生产优先级？输入priority；回车继续绑定：')=='priority':
                self.submit('priorities','A',dict(production_priority=list(ask('输入完整A-D优先级，如ABCD：'))));return
            n=self.pick('registered' if c==1 else 'production')
            self.submit('production_bind' if c==1 else 'production_unbind',n,{})
        else:
            print('【添加监控主控绑定】' if c==1 else '【删除 / 卸载监控配置】');print('监控优先级：'+' > '.join(m['monitor_priority']))
            if c==1:
                mode=ask('回车添加绑定；priority修改监控优先级；handoff离线协调权交接：')
                if mode=='priority':self.submit('priorities','A',dict(monitor_priority=list(ask('完整监控优先级，如ABC：'))));return
                if mode=='handoff':
                    slot=ask('已绑定监控槽位A/B/C：');node=m['monitor_bindings'][slot]['node'];f=obj('quorum/old_revoked/state_transfer/health/resources 离线证据JSON：');f['slot']=slot;self.submit('monitor_handoff',node,f);return
            slots=list('ABC') if c==1 else list(m['monitor_bindings'])
            for i,slot in enumerate(slots,1):print(f"{i}. 监控 {slot}：{m['monitor_bindings'].get(slot,'未绑定')}")
            print('0. 返回');v=ask('选择监控主控编号：')
            if v=='0':raise Cancel()
            if not v.isascii() or not v.isdigit() or len(v)>1 or not 1<=int(v)<=len(slots):raise ValueError('监控主控编号无效')
            slot=slots[int(v)-1]
            if c==2:self.submit('monitor_unbind',m['monitor_bindings'][slot]['node'],dict(slot=slot));return
            if slot in m['monitor_bindings']:raise ValueError('该监控已绑定，禁止覆盖')
            n=self.pick();print('需目标环境离线资料：id/version/installed/cpu/memory_mib/disk_mib/network/permissions/runtime_compatible；不连接远端。')
            profile=obj();show(environment_plan(profile));self.submit('monitor_bind',n,dict(slot=slot,profile=profile))
    def migrations(self,key,c):
        d=self.load();m=settings(d)
        if key=='9':
            if c in (1,13):show(dict(primary=d['primary'],replica=[n for n,x in d['nodes'].items() if x['production']=='Replica' and x['lifecycle']=='Active'],channels=channels(d)));return
            if c==6:
                target=self.pick('eligible');show(precheck(d,target,obj('离线预检证据JSON：')));return
            if c==8:show([a for a in d['audit'] if a['action'].startswith(('migration','maintenance'))]);return
            if c in (7,14):show(m['migration_tasks']);return
            if c in (9,10,11):
                task=ask('迁移任务ID：');fields=dict(task=task)
                if c==10:fields['duration']=int(ask('尚未生效期限（秒）：'))
                self.submit({9:'migration_cancel',10:'migration_deadline',11:'expiry_assess'}[c],'A',fields);return
        if key=='9m':
            if c in (1,2):self.maintenance['source' if c==1 else 'target']=self.pick('eligible');return
            if c in (3,4):self.maintenance['start_at' if c==3 else 'end_at']=int(ask('UTC Unix时间戳：'));return
            if c in (5,6):show(precheck(d,self.maintenance.get('target') or self.pick('eligible'),obj()));return
            if c in (7,9):show(dict(staged=self.maintenance,persisted=m['maintenance']));return
            if c==8:
                if not {'source','target','start_at','end_at'} <= self.maintenance.keys():raise ValueError('维护计划尚未配置完整：先选择维护源、接管目标及开始/结束时间')
                f=copy.deepcopy(self.maintenance);n=f.pop('source');f['proof']=obj('维护离线预检证据JSON：');self.submit('maintenance',n,f);return
            if c==10:self.submit('maintenance_cancel','A',dict(id=ask('维护计划ID：')));return
        if key=='9s' and c<=4:self.target='ABCD'[c-1];print('暂存目标：'+self.target+'；未改变角色');return
        if key in ('9t','9p') and c==1:self.target=self.pick('eligible');return
        if key=='9t' and c==2:self.duration=int(ask('期限秒数（仅离线完成唯一Primary+健康检查后计时）：'));return
        if key=='9t' and c in (7,8):
            f=dict(task=ask('任务ID：'))
            if c==7:f['duration']=int(ask('期限秒数：'))
            self.submit('migration_deadline' if c==7 else 'migration_cancel','A',f);return
        if key=='10':
            if c in (1,12,14,15):show(dict(policy=m['auto_policy'],tasks=m['migration_tasks'],mode='OFFLINE_MODEL'));return
            if c in (2,3,4):
                f={'enabled':ask('仅启用离线策略？输入true或false：')=='true'} if c==2 else {'target':self.pick('eligible')} if c==3 else {'start_at':int(ask('计划维护UTC Unix时间戳：'))}
                self.submit('auto_policy','A',f);return
            if c==13:show([a for a in d['audit'] if a['action'].startswith('migration')]);return
            self.target=m['auto_policy']['target'] or self.target
            if c==11:
                target=self.target or self.pick('eligible');proof=obj('自动迁移全部预检JSON：');show(precheck(d,target,proof));print('状态机：'+' → '.join(AUTO_STAGES))
                if ask('创建自动迁移离线任务？yes继续，其他仅预览：')=='yes':self.submit('migration_create',target,dict(kind='automatic',task=ask('任务ID：'),proof=proof))
                return
        completion=(key=='9s' and c==13) or (key=='9t' and c==5) or (key=='9p' and c==8)
        if completion:
            target=self.target or self.pick('eligible');proof=obj('预检JSON（identity/production_eligible/mysql_version/gtid_lineage/caught_up/files/mysql_config/resources/fencing_possible/no_conflict=true）：')
            kind={'9s':'manual','9t':'temporary','9p':'permanent'}[key]
            self.submit('migration_create',target,dict(kind=kind,task=ask('任务ID：'),duration=self.duration,proof=proof,second_confirmation=kind=='permanent'));return
        if (key=='9t' and c==6) or (key=='9p' and c==9):show(m['migration_tasks']);return
        target=self.target or self.pick('eligible')
        show(precheck(d,target,{}));print('目标方向预览：');show(channels(d,target));print('离线预检无真实数据证据，不能显示通过。')
        if key=='9s' and c==12:
            print('已有任务可单步模拟，每步持久化；失败粘滞MANUAL_REQUIRED。')
            if ask('执行已有离线任务下一步？输入yes：')=='yes':self.submit('migration_step',target,dict(task=ask('任务ID：'),proof=obj('本阶段离线证据JSON：')))
    def action(self,key,c):
        if key=='1':self.cf(c);return
        if key in ('3','4'):self.bindings(key,c);return
        if key.startswith('9') or key=='10':self.migrations(key,c);return
        d=self.load();m=settings(d)
        if key=='2':
            if c<=4:
                n='ABCD'[c-1];print('登记后为Joining；不自动加入生产拓扑。')
                self.submit('register',n,dict(identity=ask('唯一机器身份标识：'),address=ask('连接地址：'),remark=ask('显示备注：')))
            elif c<=8:self.submit('remark','ABCD'[c-5],dict(remark=ask('新备注（不改变身份）：')))
            elif c==9:show(d['nodes'])
            elif c==10:show({n:x['lifecycle'] for n,x in d['nodes'].items()})
            elif c==11:self.submit('lifecycle',self.pick(),dict(lifecycle=ask('Maintenance/Unreachable/Active：')))
            elif c==12:
                n=self.pick('rejoin');print('重新加入仅登记Joining，不授权任何功能。若需资格审核输入qualify。')
                if ask('动作 join/qualify：')=='qualify':self.submit('qualify',n,obj('identity_verified/data_verified/resources JSON：'))
                else:self.submit('join',n,dict(identity=d['nodes'][n]['identity']))
            elif c==13:self.submit('retire',self.pick(),{})
            elif c==14:show([a for a in d['audit'] if a['action'] in ('register','remark','join','qualify','retire','lifecycle')])
            return
        if key=='5':
            if c in (2,3,7,8,9,10,11,12):
                n=self.pick();print('完整配置字段：address/port/product/version/server_id/gtid/binlog/user/auth_ref/sources/least_privilege/protected_network。仅保存模型。')
                f=obj();v=copy.deepcopy(m['mysql'].get(n,{}));v.update(f);self.submit('mysql',n,v)
            elif c==18:self.submit('mysql_remove',self.pick('mysql'),{})
            elif c==17:show([a for a in d['audit'] if a['action'].startswith('mysql')])
            elif c==1:show(m['mysql'])
            elif c in (4,5,6,13):
                from management_model import mysql_validate
                n=self.pick('mysql');mysql_validate(m['mysql'][n]);show(dict(node=n,model='格式校验通过（离线）',network='尚未检查',port='尚未检查',version=m['mysql'][n]['version'],security='仅声明最小权限/保护网络；未验证真实服务，网络不通不等于Fencing'))
            else:show(dict(status='尚未检查',thread_status='状态未知',lag=None,last_checked_at=None,mode='OFFLINE_MODEL'))
            return
        if key=='6':
            if c in (7,8):self.submit('production_bind' if c==7 else 'production_unbind',self.pick('registered' if c==7 else 'production'),{});return
            if c==9:
                if d['primary'] is None:
                    n=self.pick('eligible');self.submit('primary',n,dict(offline_verified=True,proof=obj('初始Primary完整离线预检证据JSON：')))
                else:self.loop('9s')
                return
            if c==2:show({n:x['production'] for n,x in d['nodes'].items()})
            elif c==3:show(dict(primary=d['primary'],mode='OFFLINE_MODEL'))
            elif c==4:show([n for n,x in d['nodes'].items() if x['production']=='Replica' and x['lifecycle']=='Active'])
            elif c==14:show(dict(conflicts=conflicts(d),mode='OFFLINE_MODEL'))
            elif c==15:show(dict(version=d['version']))
            elif c==16:show(d['audit'])
            elif c in (11,12,13):show(dict(status='尚未检查',gtid='不得清空GTID掩盖分叉',binlog='需验证血缘/保留；禁止直接清空数据目录',lag=None,mode='OFFLINE_MODEL'))
            else:
                report=channels(d);show(report)
                if c==18:self.export('topology-report',report)
            return
        if key=='7':
            if c in (2,3):self.submit('ssh',self.pick(),obj('SSH JSON：address/port/user/key_ref/known_hosts_ref：'))
            elif c==21:self.submit('ssh_remove',self.pick('ssh'),{})
            elif c==1:show(m['ssh'])
            elif c in (4,5):print('尚未检查；阶段二不执行SSH，密钥/known_hosts仅受控引用。')
            elif c in (6,8,11,12,14,15):
                print('仅同步/home/web/；排除log/mysql/redis；包含beifen；默认禁止删除、不跟随外部链接。')
                self.submit('sync','A',obj('同步策略JSON（固定范围不能更改）：'))
            elif c in (7,9):show(channels(d)['files'])
            elif c in (10,13):
                manifest=obj('离线清单JSON files:[{path,stable,quiet_seconds}]；Redis用途需先审核：');show(sync_preview(m['sync'],manifest))
                if c==10 and ask('保存离线基线任务？yes：')=='yes':self.submit('sync_job','A',dict(job=ask('任务ID：'),manifest=manifest))
            elif c in (16,17):show(m['sync']['jobs'])
            elif c==18:show([a for a in d['audit'] if a['action'].startswith(('sync','ssh'))])
            elif c==19:self.export('file-sync-report',dict(sync=m['sync'],ssh=m['ssh'],directions=channels(d)['files']))
            elif c==20:self.submit('sync_pause','A',dict(job=ask('同步任务ID：'),paused=ask('暂停true / 恢复false：')=='true'))
            return
        if key=='7c':
            if c==2:self.submit('mysql_config','A',obj('配置JSON files列表，仅允许/etc/mysql/下文件；不读取真实文件：'))
            elif c==10:self.submit('mysql_config','A',obj('public/nodes/sensitive_ref JSON；版本与历史由模型事务保留：'))
            elif c==12:show([a for a in d['audit'] if a['action']=='mysql_config'])
            elif c in (4,11):show(channels(d)['mysql_config'])
            elif c==3:show(dict(public=m['mysql_config']['public'],node_specific=m['mysql_config']['nodes'],difference='逐节点展示，不覆盖专属参数'))
            else:show(dict(config=m['mysql_config'],compatibility='尚未检查；未授权发布',server_ids={n:v['server_id'] for n,v in m['mysql'].items()},gtid_binlog={n:[v['gtid'],v['binlog']] for n,v in m['mysql'].items()},permissions='尚未检查；敏感凭据独立引用',status='离线模型'))
            return
        if key=='8':
            if c==3:
                from management_model import local_environment
                show(local_environment());print('远程绑定节点仍需离线资料；不会把本机检测当成远程正常。');return
            if c in (2,3,4,5,6,7,8,9,10):
                n=self.pick();print('离线环境检查，不连接远程；id/version/installed/cpu/memory_mib/disk_mib/network/permissions/runtime_compatible。')
                if ask('输入新离线资料？yes；其他查看已有计划：')=='yes':
                    profile=obj();show(environment_plan(profile));self.submit('environment',n,profile)
                else:show(m['environment'].get(n,'尚未检查'))
                if c==8 and ask('模拟环境安装结果？yes继续：')=='yes':self.submit('environment_simulate',n,dict(success=ask('模拟成功true / 失败false：')=='true'))
            elif c==11:show([a for a in d['audit'] if a['action'].startswith('environment')])
            elif c==12:show({n:v for n,v in m['environment'].items() if v['status']=='检查失败'})
            else:show(dict(bindings=m['monitor_bindings'],environment=m['environment'],state='尚未检查；真实服务未启用'))
    def export(self,name,report):
        show(dict(report=report,mode='OFFLINE_MODEL'))
        if self.dry:print('Dry-run：未导出文件');return
        if ask('仅导出本地报告，第一次确认yes：')!='yes' or ask('第二次确认yes：')!='yes':raise Cancel()
        # Same stable model lock and private atomic IO; no business mutation.
        import fcntl
        self.store.prepare();fd=os.open(self.store.folder/'operation.lock',os.O_CREAT|os.O_APPEND|os.O_WRONLY|os.O_NOFOLLOW,0o600)
        try:
            self.store.private(self.store.folder/'operation.lock');fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
            filename=name+'-'+uuid.uuid4().hex+'.json';self.store.write(filename,report);print(str(self.store.folder/filename))
        finally:os.close(fd)

if __name__=='__main__':
    sys.dont_write_bytecode=True
    ui=UI(dry='--dry-run' in sys.argv)
    ui.loop(next((x for x in sys.argv[1:] if x in MENUS),None))

@@ABC_END

@@ABC_FILE modules/menu_spec.py 600 8daf70776e4f1cb0dd5bf576260cdfbffc4f9f6ec3309f59ff5d8b30fad5d684
"""Formal menu specification. Rendered and exercised by stage-two UI/tests."""
MAIN=['Cloudflare 免费 DNS 配置','添加节点 / 编辑节点备注','生产 A-D 绑定选择','监控 A-C 绑定选择','MySQL 主从复制通信方式','MySQL 动态复制拓扑（离线模型；真实配置未启用）','SSH + Rsync 网站文件同步（未启用）','主控运行环境检查与安装管理','手动生产迁移与计划维护','自动生产迁移']
MENUS={
'1':('1. '+MAIN[0],['查看 DNS 配置状态','添加 Cloudflare API 配置','编辑 Cloudflare API 配置','测试 API 连接与权限','配置 DNS 区域','配置域名','查看现有 DNS 记录','查看 DNS 配置历史','删除 Cloudflare API 配置']),
'2':('2. '+MAIN[1],['添加物理节点 A','添加物理节点 B','添加物理节点 C','添加物理节点 D','编辑节点 A 备注','编辑节点 B 备注','编辑节点 C 备注','编辑节点 D 备注','查看全部节点信息','查看节点生命周期状态','设置节点维护状态','申请节点重新加入','退役指定节点','查看节点登记历史']),
'3':('3. '+MAIN[2],['添加绑定','删除 / 卸载生产与备用配置']),
'4':('4. '+MAIN[3],['添加绑定','删除 / 卸载监控配置']),
'5':('5. '+MAIN[4],['查看 A/B/C/D MySQL 通信配置','添加 MySQL 节点通信配置','编辑 MySQL 节点通信配置','测试节点网络连通性','检查 MySQL 服务端口','检查 MySQL / MariaDB 类型和版本','配置 MySQL 复制用户','配置复制认证信息','配置 GTID 复制参数','配置 Binlog 参数','配置 server_id','配置复制来源白名单','检查复制通信安全','查看节点通信状态','查看复制线程状态','查看复制延迟','查看通信配置历史','删除指定节点通信配置']),
'6':('6. '+MAIN[5],['查看当前生产拓扑','查看 A/B/C/D 节点角色','查看当前 Primary','查看全部 Replica','自动计算复制方向','查看每条复制边状态','添加 Replica','移除 Replica','修改当前 Primary（离线模型）','重新生成复制拓扑','检查 GTID 数据一致性','检查 Binlog 血缘及保留情况','检查复制延迟','检查拓扑冲突','查看拓扑版本','查看拓扑变更历史','生成拓扑配置预览','导出拓扑检查报告']),
'7':('7. '+MAIN[6],['查看 A/B/C/D SSH 配置','添加 SSH 节点连接配置','编辑 SSH 节点连接配置','测试 SSH 连接','检查 SSH 密钥认证','配置文件同步源目录','配置文件同步目标节点','配置同步排除规则','查看当前同步方向','首次文件基线同步预览','文件变化检测设置','大文件同步策略','文件传输完整性检查','同步失败重试策略','文件删除保护策略','查看同步任务及进度','查看同步错误日志','查看文件同步历史','生成文件同步配置报告','暂停或恢复指定同步任务','删除指定同步配置','MySQL 专用配置同步管理']),
'7c':('MySQL 专用配置同步管理',['查看 A/B/C/D MySQL 配置状态','选择需要管理的 MySQL 配置文件','查看 MySQL 配置差异','生成配置同步预览','检查目标节点版本兼容性','检查 server_id 冲突','检查节点专属参数','检查 GTID 与 Binlog 参数','检查配置文件权限','配置备份与版本记录','查看配置同步任务','查看配置同步历史']),
'8':('8. '+MAIN[7],['查看监控 A-C 运行环境','检查指定主控绑定节点','自动识别操作系统','检查系统版本及兼容性','检查 CPU、内存、磁盘及网络','检查所需软件和依赖','生成环境安装清单','生成环境安装计划','检查已安装组件','检查服务目录和权限','查看环境安装历史','检查安装失败原因','查看主控运行状态']),
'9':('9. '+MAIN[8],['查看当前生产拓扑','手动切换生产节点','临时迁移到指定节点','永久迁移到指定节点','计划维护当前生产节点','查看迁移前安全检查','查看迁移任务及执行进度','查看迁移历史和审计记录','取消尚未执行的迁移任务','临时迁移期限管理','到期回切安全评估','手动执行安全回切','查看当前生产主节点和全部备用节点','查看迁移失败原因']),
'9s':('手动切换生产节点',['选择生产节点 A','选择生产节点 B','选择生产节点 C','选择生产节点 D','执行切换前安全检查','检查 GTID 和数据一致性','检查旧 Primary 写入隔离','检查 MySQL 复制状态','检查网站文件同步状态','检查 MySQL 专用配置兼容性','查看新旧节点传输方向','生成切换预览','确认并提交切换任务（阶段二仅模拟）']),
'9t':('临时生产迁移',['选择临时目标节点','设置临时迁移期限','查看迁移前安全检查','查看迁移预览','确认临时迁移','查看临时迁移状态','修改尚未生效的迁移期限','取消尚未执行的迁移任务']),
'9p':('永久生产迁移',['选择永久目标节点','检查目标节点资格','检查 GTID 和数据一致性','检查旧 Primary 隔离条件','检查网站文件同步状态','检查 MySQL 专用配置兼容性','查看迁移预览','二次确认永久迁移','查看迁移结果']),
'9m':('生产节点计划维护',['选择需要维护的生产节点','选择接管目标','设置维护开始时间','设置维护结束时间','检查接管条件','检查新节点准备情况','查看维护计划','确认维护计划','查看维护状态','取消尚未开始的维护']),
'10':('10. '+MAIN[9],['查看自动生产迁移状态','启用 / 停用自动迁移策略','配置自动迁移目标','配置计划维护时间','检查新生产节点准备情况','检查 MySQL 数据一致性','检查 GTID 和复制追平状态','检查网站文件同步状态','检查 MySQL 专用配置兼容性','检查旧生产节点隔离条件','生成自动迁移预览','查看自动迁移执行进度','查看自动迁移历史','查看自动迁移失败原因','查看维护完成后的生产恢复状态'])}

CHILDREN={('7',22):'7c',('9',2):'9s',('9',3):'9t',('9',4):'9p',('9',5):'9m',('9',12):'9s'}

@@ABC_END

@@ABC_FILE modules/monitor_engine.py 600 f2bcb2186a741e07afce5e5765dd986d6ff2dacd1b2e1077c6f1c2facd825000
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
    if (DATA/'domain-model/enabled.json').exists() or (DATA/'domain-model/enabled.json').is_symlink():
        raise ValueError('分域离线模型存在；禁止用模拟角色执行真实采集')
    functions_path=DATA/'offline-functions/topology.json'
    if functions_path.exists() or functions_path.is_symlink():
        raise ValueError('独立功能离线模型存在；禁止将模拟职能用作真实SSH或协调授权')
    model_path = DATA / 'offline-topology/topology.json'
    if model_path.exists() or model_path.is_symlink():
        from topology_model import Store, targets
        model = Store(ROOT).load()
        observer = os.environ.get('NODE_ROLE')
        if observer not in ('C', 'D'):
            raise ValueError('未配置协调观察者身份')
        planned = targets(model, observer)
        raise ValueError('离线拓扑监控目标=' + ','.join(planned) + '；禁止以模型授权真实SSH采集')
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
    from config_transaction import ConfigTransaction,digest
    tx=ConfigTransaction(ROOT)
    tx.update({'MONITOR_INTERVAL':value,'STATUS_EXPIRE_SECONDS':str(expiry)},digest(tx.raw()),domain='monitor')
    print('已保存间隔 ' + value + ' 秒；有效期 ' + str(expiry) + ' 秒。后台每轮重新加载配置，无需重复创建任务。')


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

@@ABC_FILE modules/node_functions.py 600 08a779032b0aebc751207803e22de1fab702607c45eba83265d7c3493bdfd5cc
"""Symmetric node functions, offline schema3; no infrastructure executor."""
import copy
import time
import re
from topology_model import Store as LegacyStore

IDS=tuple('ABCD')
PRODUCTION=(None,'Primary','Replica')
MONITOR=(None,'Primary Monitor','Backup Monitor')
STAGES={kind:tuple(kind+'_'+s for s in ('REQUESTED','PREFLIGHT','LOCKED','VALIDATED','COMMIT','COMPLETED')) for kind in ('PRODUCTION','MONITOR')}


def transition(kind,state,proof):
    if kind not in STAGES or state not in STAGES[kind]:raise ValueError('无效独立状态机')
    if proof is not True:return 'MANUAL_REQUIRED'
    index=STAGES[kind].index(state)
    return STAGES[kind][min(index+1,len(STAGES[kind])-1)]


def initial():
    return dict(schema=3,mode='OFFLINE_FUNCTIONS',version=0,primary=None,primary_monitor=None,effective_backup=None,
                policy=dict(allow_colocation=False,min_cpu=2,min_memory_mib=1024,min_disk_mib=1024,max_cpu_percent=80,max_io_percent=80,max_network_percent=80),
                nodes={n:dict(physical_id=n,lifecycle='Joining',production=None,monitor=None,resources=None,identity=None) for n in IDS},
                database_edges=[],file_edges=[],operations=[],audit=[])


def conflicts(data):
    problems=[];policy=data['policy']
    for name,node in data['nodes'].items():
        if node['production'] and node['monitor']:
            r=node.get('resources')
            if not policy['allow_colocation']:problems.append(name+':兼任策略禁止')
            elif not isinstance(r,dict) or not r.get('reliable_state') or not r.get('isolated_processes') or type(r.get('checked_at')) is not int or not 0<=int(time.time())-r['checked_at']<=300:problems.append(name+':资源/协调状态证据缺失或过期')
            else:
                for key,minimum in (('cpu','min_cpu'),('memory_mib','min_memory_mib'),('disk_mib','min_disk_mib')):
                    if type(r.get(key)) not in (int,float) or r[key]<policy[minimum]:problems.append(name+':'+key+'不足')
                for key,maximum in (('cpu_percent','max_cpu_percent'),('io_percent','max_io_percent'),('network_percent','max_network_percent')):
                    if type(r.get(key)) not in (int,float) or not 0<=r[key]<=policy[maximum]:problems.append(name+':'+key+'负载过高或未知')
    return problems


def rebuild(data):
    data['primary']=next((n for n in IDS if data['nodes'][n]['production']=='Primary'),None)
    data['primary_monitor']=next((n for n in IDS if data['nodes'][n]['monitor']=='Primary Monitor'),None)
    data['database_edges']=[[data['primary'],n] for n in IDS if data['primary'] and data['nodes'][data['primary']]['lifecycle']=='Active' and data['primary'] not in data.get('production_isolated',[]) and data['nodes'][n]['production']=='Replica' and data['nodes'][n]['lifecycle']=='Active' and n not in data.get('production_isolated',[])]
    data['file_edges']=copy.deepcopy(data['database_edges'])
    backups=[n for n in IDS if data['nodes'][n]['monitor']=='Backup Monitor']
    if data.get('effective_backup') not in backups:data['effective_backup']=backups[0] if backups else None


def validate(data):
    if not isinstance(data,dict) or data.get('schema')!=3 or data.get('mode')!='OFFLINE_FUNCTIONS':raise ValueError('功能模型schema不支持；不自动迁移旧拓扑')
    if type(data.get('version')) is not int or data['version']<0 or set(data.get('nodes',{}))!=set(IDS):raise ValueError('版本/身份损坏')
    for name,node in data['nodes'].items():
        if node.get('physical_id')!=name or node.get('production') not in PRODUCTION or node.get('monitor') not in MONITOR:raise ValueError('功能映射非法')
        if node.get('lifecycle') not in ('Joining','Active','Maintenance','Unreachable','Retired'):raise ValueError('生命周期非法')
        if node['lifecycle'] in ('Joining','Retired') and (node['production'] or node['monitor']):raise ValueError('Joining/Retired不得有有效功能')
    if sum(n['production']=='Primary' for n in data['nodes'].values())>1:raise ValueError('两个生产Primary')
    if sum(n['monitor']=='Primary Monitor' for n in data['nodes'].values())>1:raise ValueError('两个Primary Monitor')
    expected=copy.deepcopy(data);rebuild(expected)
    for key in ('primary','primary_monitor','effective_backup','database_edges','file_edges'):
        if data.get(key)!=expected[key]:raise ValueError('派生拓扑不一致')
    from management_model import validate_management
    validate_management(data)
    return data


def targets(data,observer):
    validate(data)
    if observer not in IDS or not data['nodes'][observer]['monitor']:return []
    return [n for n in IDS if n!=observer and data['nodes'][n]['lifecycle']=='Active' and (data['nodes'][n]['production'] or data['nodes'][n]['monitor'])]


def change(data,action,node,fields):
    d=copy.deepcopy(validate(data));n=d['nodes'].get(node)
    if n is None:raise ValueError('节点必须A/B/C/D')
    if 'management' in d:
        from management_model import clean,resource_ok,CHECKS
        clean(fields)
        if action in ('join','retire','remove_monitor') and any(v['node']==node for v in d['management']['monitor_bindings'].values()):raise ValueError('先解除逻辑监控绑定，不得绕过绑定检查')
        if action=='join' and (n['production'] or n['monitor']):raise ValueError('先安全卸载职能，再重新加入')
        if action=='primary':
            if d['primary'] is not None:raise ValueError('正式管理模型必须通过持久化迁移状态机切换Primary；旧兼容入口禁止绕过')
            if not resource_ok(n) or node not in d['management']['mysql'] or not all(fields.get('proof',{}).get(k) is True for k in CHECKS):raise ValueError('初始离线Primary必须完整预检；不代表真实授权')
    if action=='join':
        if n['lifecycle'] not in ('Joining','Retired'):raise ValueError('仅未加入/退役节点可重新加入')
        n.update(lifecycle='Joining',production=None,monitor=None,identity=fields.get('identity'))
    elif action=='activate':
        if n['lifecycle']!='Joining' or fields.get('identity_verified') is not True or fields.get('data_verified') is not True or not n['identity']:raise ValueError('加入验证/批准不足')
        n['lifecycle']='Active'
    elif action=='policy':
        if type(fields.get('allow_colocation')) is not bool:raise ValueError('策略必须显式bool')
        d['policy']['allow_colocation']=fields['allow_colocation']
    elif action=='resources':n['resources']=copy.deepcopy(fields)
    elif action in ('primary','replica','remove_production','primary_monitor','backup_monitor','remove_monitor','retire'):
        if n['lifecycle']!='Active':raise ValueError('仅Active可分配/卸载功能')
        if action=='primary':
            if fields.get('offline_verified') is not True:raise ValueError('缺离线生产转换验证')
            for other in d['nodes'].values():
                if other['production']=='Primary':other['production']='Replica'
            n['production']='Primary'
        elif action=='replica':
            if n['production']=='Primary':raise ValueError('先选择新Primary，不能直接降级当前主')
            n['production']='Replica'
        elif action=='remove_production':
            if n['production']=='Primary':raise ValueError('不能卸载当前Primary，先迁移')
            n['production']=None
        elif action=='primary_monitor':
            if fields.get('offline_handoff_verified') is not True:raise ValueError('缺离线监控交接验证')
            for other in d['nodes'].values():
                if other['monitor']=='Primary Monitor':other['monitor']='Backup Monitor'
            n['monitor']='Primary Monitor'
        elif action=='backup_monitor':
            if n['monitor']=='Primary Monitor':raise ValueError('先交接主监控')
            n['monitor']='Backup Monitor'
        elif action=='remove_monitor':
            if n['monitor']=='Primary Monitor':raise ValueError('先交接Primary Monitor；不能直接卸载协调权')
            n['monitor']=None
        elif action=='retire':
            if n['production']=='Primary' or n['monitor']=='Primary Monitor':raise ValueError('先交接生产/监控主职能')
            n.update(lifecycle='Retired',production=None,monitor=None)
    else:
        from management_model import change as management_change
        d=management_change(d,action,node,fields)
    rebuild(d)
    errors=conflicts(d)
    if errors:raise ValueError(';'.join(errors))
    return validate(d)


class Store(LegacyStore):
    def __init__(self,project):
        super().__init__(project);self.folder=self.root/'data/offline-functions'
    def load(self):
        from domain_store import DomainStore
        domains=DomainStore(self.root)
        return domains.load() if domains.enabled else validate(self.read('topology.json'))
    def transaction(self,request,expected,action,node,fields=None,interrupt=None):
        from domain_store import DomainStore
        domains=DomainStore(self.root)
        if domains.enabled:return domains.transaction(request,expected,action,node,fields,interrupt)
        if isinstance(expected,dict):raise ValueError('分域模型未初始化；禁止回退旧事务')
        # Reuse private IO/locking but supply schema3 semantics through generic transaction implementation.
        import fcntl,os,json,hashlib,re,time
        if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}',request):raise ValueError('operation_id非法')
        self.prepare();fd=os.open(self.folder/'operation.lock',os.O_CREAT|os.O_APPEND|os.O_WRONLY|os.O_NOFOLLOW,0o600)
        try:
            self.private(self.folder/'operation.lock');fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB);self.reconcile()
            old=self.load() if (self.folder/'topology.json').exists() else initial()
            fp=hashlib.sha256(json.dumps(dict(expected=expected,action=action,node=node,fields=fields or {}),sort_keys=True).encode()).hexdigest()
            prior=next((x for x in old['operations'] if x['operation_id']==request),None)
            if prior:
                if prior['fingerprint']!=fp:raise ValueError('重复ID内容冲突')
                return old
            if old['version']!=expected:raise ValueError('CAS版本冲突')
            supplied=copy.deepcopy(fields or {})
            if action=='migration_step':supplied['operation_id']=request
            new=change(old,action,node,supplied) if action!='initialize' else copy.deepcopy(old)
            new['version']=old['version']+1;new['operations'].append(dict(operation_id=request,fingerprint=fp))
            new['audit'].append(dict(operation_id=request,at=int(time.time()),action=action,node=node,before_version=old['version'],after_version=new['version'],before_functions=old['nodes'],after_functions=copy.deepcopy(new['nodes']),mode='OFFLINE_FUNCTIONS'))
            validate(new);self.write('transaction.json',dict(status='PREPARED',before=old['version'],after=new))
            if interrupt=='prepared':raise InterruptedError('离线prepared中断')
            self.write('topology.json',new)
            if interrupt=='published':raise InterruptedError('离线published中断')
            self.write('transaction.json',dict(status='COMMITTED',version=new['version']));return new
        finally:os.close(fd)
    def reconcile(self):
        if not (self.folder/'transaction.json').exists():return
        j=self.read('transaction.json')
        if j.get('status')=='COMMITTED':
            if type(j.get('version')) is not int:raise ValueError('已提交事务版本损坏')
            return
        if j.get('status')!='PREPARED':raise ValueError('未知事务')
        after=validate(j['after'])
        if type(j.get('before')) is not int or after['version']!=j['before']+1 or not after['operations'] or not after['audit']:raise ValueError('恢复请求/版本不完整')
        op=after['operations'][-1];audit=after['audit'][-1]
        if not isinstance(op,dict) or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}',op.get('operation_id','')) or not re.fullmatch(r'[a-f0-9]{64}',op.get('fingerprint','')) or audit.get('operation_id')!=op['operation_id'] or audit.get('after_version')!=after['version'] or audit.get('before_version')!=j['before']:raise ValueError('恢复事务身份/审计损坏')
        if (self.folder/'topology.json').exists():
            old=self.load()
            if old['version']==after['version']:
                if old!=after:raise ValueError('恢复内容冲突')
            elif old['version']!=j['before']:raise ValueError('恢复版本冲突')
        elif j['before']!=0:raise ValueError('丢失原状态')
        self.write('topology.json',after);self.write('transaction.json',dict(status='COMMITTED',version=after['version']))

@@ABC_END

@@ABC_FILE modules/offline_policy.py 600 00ae913ab71cf8aa2a59e87a171e2229acb2eb4fec751b7810e004a656b338eb
"""Persisted offline policy evaluator; never commits node functions or remote actions."""
import copy
import hashlib
import json
import os
import re
import time
import fcntl
from topology_model import Store as PrivateIO
from node_functions import validate as validate_functions,conflicts

FAILBACK=tuple('MIGRATION_EXPIRY FAILBACK_PREFLIGHT TARGET_IDENTITY_CHECK DATA_CONSISTENCY_CHECK WRITE_BARRIER REPLICATION_CATCHUP FINAL_CONSISTENCY_CHECK OLD_PRIMARY_FENCING PRIMARY_SWITCH REPLICATION_RECONFIGURATION FILE_SYNC_RECONFIGURATION HEALTH_CHECK TOPOLOGY_COMMIT FAILBACK_COMPLETED'.split())
MONITOR=tuple('MONITOR_FAILURE_CONFIRMED MONITOR_AUTHORITY_CHECK MONITOR_CANDIDATE_CHECK MONITOR_STATE_TRANSFER MONITOR_OLD_AUTHORITY_REVOKED MONITOR_ROLE_COMMIT MONITOR_HANDOFF_COMPLETED'.split())
PROOFS=('identity','lineage','caught_up','health','barrier','fencing','files','database_topology','file_topology','durable_transaction')

def initial():
 return dict(schema=1,mode='OFFLINE_POLICY',version=0,production_priority=['A','B','D'],monitor_priority=['B','D'],production_candidates=list('ABD'),monitor_candidates=list('BD'),monitor_term=0,tasks={},requests=[],audit=[])

def validate(d):
 if not isinstance(d,dict) or d.get('schema')!=1 or d.get('mode')!='OFFLINE_POLICY' or type(d.get('version')) is not int:raise ValueError('策略文件损坏')
 for key in ('production_priority','monitor_priority','production_candidates','monitor_candidates'):
  value=d.get(key)
  if not isinstance(value,list) or len(value)!=len(set(value)) or any(n not in 'ABCD' or len(n)!=1 for n in value):raise ValueError('候选/优先级非法')
 if not isinstance(d.get('tasks'),dict) or not isinstance(d.get('requests'),list):raise ValueError('任务结构损坏')
 return d

def eligible(model,node,kind,proof):
 n=model['nodes'][node]
 if n['lifecycle']!='Active':return False
 if kind=='production':return bool(n['production']) and all(proof.get(k) is True for k in PROOFS)
 return bool(n['monitor']) and all(proof.get(k) is True for k in ('identity','health','authority','old_revoked','state_transfer','quorum','resources')) and not conflicts(model)

def choose(policy,model,kind,evidence):
 validate(policy);validate_functions(model)
 return next((n for n in policy[kind+'_priority'] if n in policy[kind+'_candidates'] and eligible(model,n,kind,evidence.get(n,{}))),None)

class Store(PrivateIO):
 def __init__(self,root):
  super().__init__(root);self.folder=self.root/'data/offline-policy'
 def load(self):return validate(self.read('policy.json'))
 def recover(self):
  if not (self.folder/'transaction.json').exists():return
  j=self.read('transaction.json')
  if j.get('status')=='COMMITTED':return
  if j.get('status')!='PREPARED':raise ValueError('未知策略事务')
  after=validate(j['after'])
  if (self.folder/'policy.json').exists():
   old=self.load()
   if old['version']==after['version'] and old!=after:raise ValueError('恢复内容冲突')
   if old['version'] not in (j['before'],after['version']):raise ValueError('恢复版本冲突')
  elif j['before']!=0:raise ValueError('原策略丢失')
  self.write('policy.json',after);self.write('transaction.json',dict(status='COMMITTED',version=after['version']))
 def transaction(self,request,expected,action,params,interrupt=None):
  if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}',request):raise ValueError('operation_id非法')
  self.prepare();fd=os.open(self.folder/'policy.lock',os.O_CREAT|os.O_APPEND|os.O_WRONLY|os.O_NOFOLLOW,0o600)
  try:
   self.private(self.folder/'policy.lock');fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB);self.recover()
   old=self.load() if (self.folder/'policy.json').exists() else initial()
   fp=hashlib.sha256(json.dumps(dict(expected=expected,action=action,params=params),sort_keys=True).encode()).hexdigest()
   prior=next((x for x in old['requests'] if x['id']==request),None)
   if prior:
    if prior['fingerprint']!=fp:raise ValueError('重复请求冲突')
    return old
   if old['version']!=expected:raise ValueError('CAS冲突')
   d=copy.deepcopy(old);now=params.get('now',int(time.time()))
   if action=='configure':
    for key in ('production_priority','monitor_priority','production_candidates','monitor_candidates'):
     if key in params:d[key]=params[key]
   elif action=='migration_completed':
    # Called only by an offline fixture describing an already-completed simulated migration.
    model=validate_functions(params['model']);source=params['source'];target=params['target']
    if source not in 'ABCD' or target not in 'ABCD' or source==target or model['primary']!=target:raise ValueError('迁移完成映射不符')
    if params.get('offline_completed') is not True:raise ValueError('不能从点击时开始期限')
    permanent=params.get('permanent',False)
    if type(permanent) is not bool:raise ValueError('迁移模式非法')
    if permanent and params.get('second_confirmation') is not True:raise ValueError('永久迁移需二次确认')
    duration=params.get('duration_seconds',300)
    if type(duration) is not int or duration<=0:raise ValueError('期限非法')
    if any(t['status'] not in ('COMPLETED','PERMANENT') for t in d['tasks'].values()):raise ValueError('已有活动迁移任务')
    d['tasks'][request]=dict(operation_id=request,source=source,target=target,effective_at=now,expires_at=None if permanent else now+duration,permanent=permanent,status='PERMANENT' if permanent else 'ACTIVE',topology_version=model['version'],stage=None,error=None,trace=[])
   elif action=='expiry':
    task=d['tasks'][params['task']]
    if task['permanent']:raise ValueError('永久迁移不自动切回')
    if now<task['expires_at']:raise ValueError('尚未到期')
    model=validate_functions(params['model'])
    if model['primary']!=task['target']:raise ValueError('生产拓扑已漂移，需人工对账')
    selected=choose(d,model,'production',params['evidence'])
    task.update(selected=selected,status='WAITING_SAFE_WINDOW' if selected is None else 'COMPLETED' if selected==model['primary'] else 'EVALUATED',stage='MIGRATION_EXPIRY',error='无合格候选，当前主保持' if selected is None else None)
   elif action=='monitor_evaluate':
    model=validate_functions(params['model'])
    if params.get('old_unavailable_verified') is not True:raise ValueError('旧监控不可用证据不足')
    selected=choose(d,model,'monitor',params['evidence'])
    # A selected candidate does not receive a lease or actually become monitor.
    d['monitor_evaluation']=dict(selected=selected,status='DEGRADED' if not selected else 'EVALUATED',production_primary=model['primary'],old_monitor=model['primary_monitor'],term=d['monitor_term'],error='无监控候选' if not selected else None)
   elif action=='stage':
    task=d['tasks'][params['task']];kind=params.get('kind','production');stages=FAILBACK if kind=='production' else MONITOR
    if task.get('status')=='MANUAL_REQUIRED':raise ValueError('安全暂停禁止自动继续，需单独对账授权')
    if task.get('permanent'):raise ValueError('永久迁移不能进入自动回切')
    if task.get('stage') is None:raise ValueError('先执行到期评估，禁止跳过预检')
    current=task.get('stage') or stages[0]
    if current not in stages:raise ValueError('阶段不属于此状态机')
    if params.get('verified') is not True:task.update(status='MANUAL_REQUIRED',error=params.get('reason','离线条件失败'))
    else:
     i=stages.index(current);next_stage=stages[min(i+1,len(stages)-1)]
     task.update(stage=next_stage,status='SIMULATED_COMPLETED' if next_stage==stages[-1] else 'SIMULATING',error=None)
     task['trace'].append(dict(stage=next_stage,operation_id=request,at=now,mode='SIMULATED'))
   else:raise ValueError('未知离线策略动作')
   d['version']=old['version']+1;d['requests'].append(dict(id=request,fingerprint=fp));d['audit'].append(dict(id=request,action=action,before=old['version'],after=d['version'],mode='OFFLINE_POLICY'))
   validate(d);self.write('transaction.json',dict(status='PREPARED',before=old['version'],after=d))
   if interrupt=='prepared':raise InterruptedError('prepared中断')
   self.write('policy.json',d)
   if interrupt=='published':raise InterruptedError('published中断')
   self.write('transaction.json',dict(status='COMMITTED',version=d['version']));return d
  finally:os.close(fd)

@@ABC_END

@@ABC_FILE modules/policy_ui.py 600 6750dba7d6803d91d2552fcc46431d2472322d4253c1f615f3a6c801b47eb350
"""Explicit offline policy editor, never auto-executes due tasks."""
import json
from pathlib import Path
from offline_policy import Store,initial
ROOT=Path(__file__).resolve().parents[1]

def main():
 s=Store(ROOT)
 while True:
  print('========================================\n生产/监控优先级与迁移策略（离线）\n========================================')
  print('1. 查看独立优先级/候选资格\n2. 修改生产或监控策略\n3. 查看临时/永久迁移任务\n4. 提交离线评估/阶段场景\n0. 返回')
  try:
   c=input('请输入编号：')
   if c=='0':return
   d=s.load() if (s.folder/'policy.json').exists() else initial()
   if c in ('1','3'):print(json.dumps(d if c=='3' else {k:v for k,v in d.items() if 'priority' in k or 'candidates' in k},ensure_ascii=False,indent=2))
   elif c in ('2','4'):
    action='configure' if c=='2' else input('动作 migration_completed/expiry/monitor_evaluate/stage：')
    params=json.loads(input('仅离线输入JSON，不包含凭据：'));request=input('operation_id：')
    if input('不执行生产动作，输入yes确认：')=='yes':print(json.dumps(s.transaction(request,d['version'],action,params),ensure_ascii=False))
   else:print('无效编号')
  except EOFError:return
  except (OSError,ValueError,KeyError) as e:print('安全拒绝：'+str(e))
if __name__=='__main__':main()

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

@@ABC_FILE modules/status_view.py 600 58a5d61e72062cfb5228b214257e3efa97066be0d46528fd0291f97462fc4857
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
        if main != '暂无' and label == '当前生产主节点': code = 32
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
        for label in ('当前生产主节点', '当前备用节点', '当前同步方向', '当前切换任务',
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
    emit(f'当前生产主节点：{primary if role_ok else "暂无"}', 'yellow' if role_ok else 'red')
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

@@ABC_FILE modules/status_view.sh 700 a6ff0aff45301fc33202d2f6725af0a4fc30a590bfbd2cc7e680b09513ef2d20
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
        python3 -B "$PROJECT_DIR/modules/dashboard.py" && return 0
    fi
    echo '实时节点状态：'
    local label
    for label in '节点 A' '节点 B' '节点 C' '节点 D'; do
        print_unknown "$label" '（状态缺失、过期或无法确认）'
    done
    echo '========================================'
    for label in '当前生产主站' '当前备用节点' '当前同步方向' '当前切换任务' '数据库状态' '文件同步状态' '数据同步时间' '复制延迟' '最后一次成功检查时间'; do
        print_unknown "$label"
    done
}

@@ABC_END

@@ABC_FILE modules/topology_model.py 600 423850a4068affd6d7d345f5f35421e0eba718fd6dec732e8e6433c7906a3db7
"""Offline topology only. No SSH, SQL, DNS, sync or operational authority."""
from pathlib import Path
import copy
import fcntl
import hashlib
import json
import os
import re
import stat
import tempfile

PRODUCERS=('A','B','D')
LIFECYCLES=('Active','Maintenance','Joining','Unreachable','Retired')
ROLE_STAGES=tuple('ROLE_CHANGE_'+name for name in ('REQUESTED','PREFLIGHT','TOPOLOGY_LOCKED','CONSISTENCY_CHECK','ROLE_ASSIGNMENT','REPLICATION_RECONFIGURATION','HEALTH_CHECK','TOPOLOGY_COMMIT','COMPLETED'))


def role_transition(state,verified):
    if state not in ROLE_STAGES:raise ValueError('未知角色事务阶段')
    if verified is not True:return 'MANUAL_REQUIRED'
    index=ROLE_STAGES.index(state)
    return ROLE_STAGES[min(index+1,len(ROLE_STAGES)-1)]


def initial():
    nodes={}
    for name in 'ABCD':
        nodes[name]=dict(physical_id=name,instance_id=None,address=None,production_role=None,coordination_role='Coordinator' if name=='C' else 'Standby Coordinator' if name=='D' else 'Observer',lifecycle='Joining',database=dict(product=None,version=None),last_checked_at=None)
    return dict(schema=2,mode='OFFLINE_MODEL',version=0,nodes=nodes,primary=None,database_edges=[],file_edges=[],operations=[],audit=[])


def rebuild(data):
    primary=data['primary']
    edges=[[primary,n] for n in PRODUCERS if n!=primary and data['nodes'][n]['production_role']=='Replica' and data['nodes'][n]['lifecycle'] not in ('Joining','Retired')] if primary else []
    data['database_edges']=edges
    data['file_edges']=copy.deepcopy(edges)


def validate(data):
    if not isinstance(data,dict) or data.get('schema')!=2 or data.get('mode')!='OFFLINE_MODEL':raise ValueError('不是受支持的离线拓扑')
    if type(data.get('version')) is not int or data['version']<0:raise ValueError('拓扑版本非法')
    if set(data.get('nodes',{}))!=set('ABCD'):raise ValueError('物理身份清单损坏')
    for name,node in data['nodes'].items():
        if node.get('physical_id')!=name or node.get('lifecycle') not in LIFECYCLES:raise ValueError('节点身份或生命周期非法')
        if node.get('production_role') not in (None,'Primary','Replica','Retired'):raise ValueError('生产角色非法')
        if node.get('coordination_role') not in ('Coordinator','Standby Coordinator','Observer'):raise ValueError('协调角色非法')
        if name=='C' and node['production_role'] is not None:raise ValueError('C不可成为生产节点')
        if node['lifecycle']=='Joining' and node['production_role'] is not None:raise ValueError('Joining不能拥有生产角色')
        if name in PRODUCERS and (node['lifecycle']=='Retired')!=(node['production_role']=='Retired'):raise ValueError('退役角色不一致')
        if name in ('A','B') and node['coordination_role']!='Observer':raise ValueError('A/B不可协调')
        if not isinstance(node.get('database'),dict):raise ValueError('数据库描述损坏')
    primaries=[n for n in PRODUCERS if data['nodes'][n]['production_role']=='Primary']
    if primaries!=([data['primary']] if data.get('primary') else []):raise ValueError('单主映射冲突')
    if data.get('primary') and data['nodes'][data['primary']]['lifecycle']!='Active':raise ValueError('Primary必须Active')
    controllers=[n for n in 'CD' if data['nodes'][n]['coordination_role']=='Coordinator']
    if len(controllers)>1:raise ValueError('协调角色冲突')
    expected=copy.deepcopy(data);rebuild(expected)
    if data.get('database_edges')!=expected['database_edges'] or data.get('file_edges')!=expected['file_edges']:raise ValueError('同步边不是当前主的独立直连')
    if not isinstance(data.get('operations'),list) or not isinstance(data.get('audit'),list):raise ValueError('审计结构损坏')
    return data


def targets(data,observer):
    validate(data)
    if observer not in ('C','D'):raise ValueError('观察者必须C或D')
    # C observes producers, D observes peer producers and C; always derived from registry.
    return [n for n in data['nodes'] if n!=observer and data['nodes'][n]['lifecycle']!='Retired' and (n in PRODUCERS or observer=='D')]


def candidates(data):
    return [n for n in PRODUCERS if data['nodes'][n]['lifecycle']=='Active' and n!=data['primary']]


def change(data,action,node,fields):
    result=copy.deepcopy(data);record=result['nodes'].get(node)
    if record is None:raise ValueError('未知物理节点')
    if action=='join':
        if node not in PRODUCERS or record['lifecycle'] not in ('Joining','Retired'):raise ValueError('节点不可进入加入流程')
        record.update(lifecycle='Joining',production_role=None)
        for key in ('instance_id','address','database'):
            if key in fields:record[key]=fields[key]
    elif action=='activate':
        if record['lifecycle']!='Joining' or fields.get('offline_identity_validated') is not True or fields.get('offline_data_validated') is not True:raise ValueError('加入验证不完整')
        if not record.get('instance_id') or not record.get('address') or not record['database'].get('product') or not record['database'].get('version'):raise ValueError('节点资料不完整')
        record.update(lifecycle='Active',production_role='Replica' if node in PRODUCERS else None)
    elif action=='promote':
        if node not in PRODUCERS or record['lifecycle']!='Active':raise ValueError('目标不是Active生产候选')
        if fields.get('offline_safety_verified') is not True:raise ValueError('离线安全场景未验证')
        old=result['primary']
        if old:result['nodes'][old]['production_role']='Replica'
        record['production_role']='Primary';result['primary']=node
    elif action=='retire':
        if node not in PRODUCERS or node==result['primary']:raise ValueError('不能退役当前Primary或C')
        record.update(lifecycle='Retired',production_role='Retired')
    elif action=='lifecycle':
        value=fields.get('lifecycle')
        if value not in ('Maintenance','Unreachable','Active') or record['lifecycle'] in ('Joining','Retired'):raise ValueError('生命周期转换不合法')
        if node==result['primary'] and value!='Active':raise ValueError('先受控迁移Primary，不能直接降级')
        record['lifecycle']=value
    else:raise ValueError('未知模型动作')
    rebuild(result);validate(result);return result


class Store:
    def __init__(self,project):
        self.root=Path(project).resolve(strict=True)
        self.folder=self.root/'data/offline-topology'
    def private(self,path,directory=False):
        s=path.lstat()
        if s.st_uid!=os.geteuid() or stat.S_IMODE(s.st_mode)!=(0o700 if directory else 0o600) or (not stat.S_ISDIR(s.st_mode) if directory else not stat.S_ISREG(s.st_mode) or s.st_nlink!=1):raise ValueError('模型存储路径不安全')
    def prepare(self):
        self.private(self.root,True);self.private(self.root/'data',True)
        self.folder.mkdir(mode=0o700,exist_ok=True);self.private(self.folder,True)
    def read(self,name):
        p=self.folder/name;self.private(p)
        def pairs(items):
            value={}
            for k,v in items:
                if k in value:raise ValueError('重复JSON键')
                value[k]=v
            return value
        with p.open() as f:return json.load(f,object_pairs_hook=pairs)
    def write(self,name,value):
        p=self.folder/name
        if p.exists() or p.is_symlink():self.private(p)
        fd,tmp=tempfile.mkstemp(prefix='.topology-',dir=self.folder)
        try:
            with os.fdopen(fd,'w') as f:json.dump(value,f,sort_keys=True);f.flush();os.fsync(f.fileno())
            os.replace(tmp,p);d=os.open(self.folder,os.O_RDONLY|os.O_DIRECTORY)
            try:os.fsync(d)
            finally:os.close(d)
        finally:
            if os.path.exists(tmp):os.unlink(tmp)
    def load(self):return validate(self.read('topology.json'))
    def transaction(self,request,expected,action,node,fields=None,interrupt=None):
        if (self.root/'data/domain-model/enabled.json').exists():raise ValueError('分域模型已启用；旧schema2禁止写入')
        if (self.root/'data/offline-functions/topology.json').exists():
            raise ValueError('新功能模型已存在；旧版模型禁止写入')
        if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}',request):raise ValueError('operation_id非法')
        self.prepare();lock=self.folder/'operation.lock'
        fd=os.open(lock,os.O_CREAT|os.O_APPEND|os.O_WRONLY|os.O_NOFOLLOW,0o600)
        try:
            self.private(lock);fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
            self.reconcile()
            current=self.load() if (self.folder/'topology.json').exists() else initial()
            payload=dict(action=action,node=node,fields=fields or {},expected=expected)
            fingerprint=hashlib.sha256(json.dumps(payload,sort_keys=True).encode()).hexdigest()
            previous=next((x for x in current['operations'] if x['operation_id']==request),None)
            if previous:
                if previous['fingerprint']!=fingerprint:raise ValueError('operation_id已用于不同请求')
                return current
            if current['version']!=expected:raise ValueError('拓扑版本冲突')
            result=change(current,action,node,fields or {}) if action!='initialize' else current
            result['version']=current['version']+1
            result['operations'].append(dict(operation_id=request,fingerprint=fingerprint))
            result['audit'].append(dict(operation_id=request,action=action,node=node,before=current['version'],after=result['version'],mode='OFFLINE_MODEL',role_stages=list(ROLE_STAGES) if action=='promote' else [],before_roles={n:x['production_role'] for n,x in current['nodes'].items()},after_roles={n:x['production_role'] for n,x in result['nodes'].items()}))
            validate(result)
            self.write('transaction.json',dict(status='PREPARED',before=current['version'],after=result))
            if interrupt=='prepared':raise InterruptedError('模拟PREPARED后中断')
            self.write('topology.json',result)
            if interrupt=='published':raise InterruptedError('模拟发布后中断')
            self.write('transaction.json',dict(status='COMMITTED',version=result['version']))
            return result
        finally:os.close(fd)
    def reconcile(self):
        p=self.folder/'transaction.json'
        if not p.exists():return
        journal=self.read('transaction.json')
        if journal.get('status')=='COMMITTED':return
        if journal.get('status')!='PREPARED':raise ValueError('事务状态未知，拒绝恢复')
        after=validate(journal['after']);path=self.folder/'topology.json'
        if path.exists():
            now=self.load()
            if now['version']==after['version']:
                if now!=after:raise ValueError('同版本内容冲突')
            elif now['version']!=journal['before']:raise ValueError('恢复版本冲突')
        elif journal['before']!=0:raise ValueError('原拓扑缺失')
        # Only finish a local offline model transaction; never replay infrastructure actions.
        self.write('topology.json',after)
        self.write('transaction.json',dict(status='COMMITTED',version=after['version']))

@@ABC_END

@@ABC_FILE modules/topology_ui.py 600 170bce59c0be23ca756ef37aa706504a0480977e67ef9d09c3d9c10a4ae24258
#!/usr/bin/env python3
"""Local offline registry UI; never creates operational topology."""
import json
from pathlib import Path
from topology_model import Store,targets,candidates

ROOT=Path(__file__).resolve().parents[1]

def main():
    store=Store(ROOT)
    while True:
        print('========================================\n             节点角色管理\n========================================')
        print('A/B/C/D 离线模型；不代表真实数据库角色或协调授权。')
        print('1. 查看全部节点角色\n2. 查看动态数据库/文件拓扑\n3. 查看 C/D 动态监控目标\n4. 查看角色变更历史\n5. 初始化离线模型\n6. 变更离线节点模型\n0. 返回主菜单')
        try:choice=input('请输入编号：')
        except EOFError:return
        if choice=='0':return
        try:
            if choice in ('5','6'):
                print('旧版兼容菜单禁止写入；请使用正式主菜单节点登记/绑定/迁移及新拓扑安全检查。')
                continue
            if choice in ('1','2','3','4'):
                data=store.load()
                value=data['nodes'] if choice=='1' else dict(database=data['database_edges'],files=data['file_edges'],version=data['version']) if choice=='2' else dict(C=targets(data,'C'),D=targets(data,'D'),candidates=candidates(data)) if choice=='3' else data['audit']
                print(json.dumps(value,ensure_ascii=False,indent=2))
            else:print('输入错误')
        except (OSError,ValueError,KeyError) as exc:print('未配置或操作拒绝：'+str(exc))

if __name__=='__main__':main()

@@ABC_END

@@ABC_FILE scripts/build_distribution.py 600 9f04ab1dde8af315f645723caa374b2fa7710d31080a0701694bc31c38333e84
#!/usr/bin/env python3
"""Rebuild readable standalone from existing bootstrap plus managed closure."""
from pathlib import Path
import hashlib,stat
root=Path(__file__).resolve().parents[1]
entry=Path('/root/yingyong/a-b-c-d-MySQL.sh')
raw=entry.read_text();header=raw.split('\n# === ABC EMBEDDED FILES ===\n',1)[0]
header=header.replace("if [[ ${ID:-} != debian || ( ${VERSION_ID:-} != 12 && ${VERSION_ID:-} != 13 ) ]]; then", "if [[ ${ID:-} != debian && ${ID:-} != ubuntu ]]; then")
header=header.replace('当前仅支持 Debian 12/13。','当前仅支持 Debian / Ubuntu；不支持发行版阻断。').replace("printf '系统检测：Debian %s；root 权限及必要工具可用。\\n' \"$VERSION_ID\"", "printf '系统检测：%s %s；root 权限及必要工具可用。\\n' \"$ID\" \"$VERSION_ID\"")
files=[root/'README.md',root/'a-b-c-d-MySQL.sh',root/'config/config.env.example']
for folder in ('scripts','modules','tests','docs'):
 files.extend(p for p in (root/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
blocks=[]
for p in sorted(files):
 name=str(p.relative_to(root));content=p.read_bytes();mode=0o700 if p.suffix=='.sh' else 0o600
 p.chmod(mode)
 blocks.append('\n@@ABC_FILE '+name+' '+format(mode,'o')+' '+hashlib.sha256(content).hexdigest()+'\n'+content.decode()+'\n@@ABC_END\n')
entry.write_text(header+'\n# === ABC EMBEDDED FILES ===\n'+''.join(blocks)+'ABC_ALL_PAYLOAD\nexit "$result"\n');entry.chmod(0o700)
print('embedded files',len(blocks),'sha256',hashlib.sha256(entry.read_bytes()).hexdigest())

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

@@ABC_FILE scripts/cloudflare.sh 700 c4f655055eb3ad79b72eade446f2477a3d9cf6a172644ecce4753a4ed07ffac1
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
if [[ $# == 1 && $1 == --recover ]]; then
    echo '仅恢复本地统一配置事务，不连接Cloudflare或修改DNS。'
    printf '第一次确认，输入yes：'
    IFS= read -r answer || exit 1
    [[ $answer == yes ]] || exit 1
    printf '第二次确认，输入yes：'
    IFS= read -r answer || exit 1
    [[ $answer == yes ]] || exit 1
    exec python3 -B "$PROJECT_DIR/modules/config_transaction.py" --recover
fi
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

@@ABC_FILE scripts/main.sh 700 b64d96ec48925d1304b18a5556da826c83a24ce983b1740f122cd8bd59214edb
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
[[ ${1:-} != --dry-run ]] || DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || { die '未知菜单参数'; exit 2; }
export PYTHONDONTWRITEBYTECODE=1
args=()
$DRY_RUN && args+=(--dry-run)
exec python3 -B "$PROJECT_DIR/modules/management_ui.py" "${args[@]}"

@@ABC_END

@@ABC_FILE scripts/manual_maintenance.sh 700 a12afd334887163575df65f70c2bb0e8b5f9a894c9bde42308132cd60e203e79
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
DRY_RUN=true
bootstrap || exit 1
[[ $# -eq 0 || ( $# -eq 1 && $1 == --dry-run ) ]] || exit 2
exec python3 -B "$PROJECT_DIR/modules/dynamic_preview.py" manual

@@ABC_END

@@ABC_FILE scripts/monitor.sh 700 74739baa504662688d9233114d64941c9d59095ffdad977e38b7489144da635b
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
    '') exec python3 -B "$PROJECT_DIR/modules/dynamic_preview.py" monitor ;;
    *) die '未知模块参数'; exit 2 ;;
esac

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

@@ABC_FILE scripts/node_functions.sh 700 043f2dd368f3492dddd9151340b1b655d9a4a7ac1d941f58c38b893cba5a6cc6
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
DRY_RUN=true
bootstrap || exit 1
[[ $# == 0 || ( $# == 1 && $1 == --dry-run ) ]] || exit 2
if [[ ${1:-} == --dry-run ]]; then
    echo '节点功能管理（离线只读预览）：四节点生产和监控功能独立；真实执行未启用。'
    exit 0
fi
exec python3 -B "$PROJECT_DIR/modules/functions_ui.py"

@@ABC_END

@@ABC_FILE scripts/node_roles.sh 700 50619222c20137650b71cc8e611c548e271601bf70d625cc2c65fa1a987ed9e7
#!/usr/bin/env bash
# shellcheck source=../modules/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../modules/common.sh"
DRY_RUN=true
bootstrap || exit 1
require_commands python3 || exit 1
# --dry-run displays the same read-only menu; mutations require explicit UI confirmation.
if [[ ${1:-} == --dry-run ]]; then
    echo '[Dry-run] 节点角色管理：仅预览，不写离线模型。'
    printf '1. 查看全部节点角色\n2. 查看动态数据库/文件拓扑\n3. 查看 C/D 动态监控目标\n4. 查看角色变更历史\n0. 返回主菜单\n'
    exit 0
fi
[[ $# == 0 ]] || exit 2
exec python3 -B "$PROJECT_DIR/modules/topology_ui.py"

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

@@ABC_FILE tests/formal-menu-contract.json 600 852f8ac2c79bf73d7e9d6e7177314eb2f6c4d9fdac2b6b28b55c1cd34116da70
{
  "1": [
    "1. Cloudflare 免费 DNS 配置",
    [
      "查看 DNS 配置状态",
      "添加 Cloudflare API 配置",
      "编辑 Cloudflare API 配置",
      "测试 API 连接与权限",
      "配置 DNS 区域",
      "配置域名",
      "查看现有 DNS 记录",
      "查看 DNS 配置历史",
      "删除 Cloudflare API 配置"
    ]
  ],
  "2": [
    "2. 添加节点 / 编辑节点备注",
    [
      "添加物理节点 A",
      "添加物理节点 B",
      "添加物理节点 C",
      "添加物理节点 D",
      "编辑节点 A 备注",
      "编辑节点 B 备注",
      "编辑节点 C 备注",
      "编辑节点 D 备注",
      "查看全部节点信息",
      "查看节点生命周期状态",
      "设置节点维护状态",
      "申请节点重新加入",
      "退役指定节点",
      "查看节点登记历史"
    ]
  ],
  "3": [
    "3. 生产 A-D 绑定选择",
    [
      "添加绑定",
      "删除 / 卸载生产与备用配置"
    ]
  ],
  "4": [
    "4. 监控 A-C 绑定选择",
    [
      "添加绑定",
      "删除 / 卸载监控配置"
    ]
  ],
  "5": [
    "5. MySQL 主从复制通信方式",
    [
      "查看 A/B/C/D MySQL 通信配置",
      "添加 MySQL 节点通信配置",
      "编辑 MySQL 节点通信配置",
      "测试节点网络连通性",
      "检查 MySQL 服务端口",
      "检查 MySQL / MariaDB 类型和版本",
      "配置 MySQL 复制用户",
      "配置复制认证信息",
      "配置 GTID 复制参数",
      "配置 Binlog 参数",
      "配置 server_id",
      "配置复制来源白名单",
      "检查复制通信安全",
      "查看节点通信状态",
      "查看复制线程状态",
      "查看复制延迟",
      "查看通信配置历史",
      "删除指定节点通信配置"
    ]
  ],
  "6": [
    "6. MySQL 动态复制拓扑（离线模型；真实配置未启用）",
    [
      "查看当前生产拓扑",
      "查看 A/B/C/D 节点角色",
      "查看当前 Primary",
      "查看全部 Replica",
      "自动计算复制方向",
      "查看每条复制边状态",
      "添加 Replica",
      "移除 Replica",
      "修改当前 Primary（离线模型）",
      "重新生成复制拓扑",
      "检查 GTID 数据一致性",
      "检查 Binlog 血缘及保留情况",
      "检查复制延迟",
      "检查拓扑冲突",
      "查看拓扑版本",
      "查看拓扑变更历史",
      "生成拓扑配置预览",
      "导出拓扑检查报告"
    ]
  ],
  "7": [
    "7. SSH + Rsync 网站文件同步（未启用）",
    [
      "查看 A/B/C/D SSH 配置",
      "添加 SSH 节点连接配置",
      "编辑 SSH 节点连接配置",
      "测试 SSH 连接",
      "检查 SSH 密钥认证",
      "配置文件同步源目录",
      "配置文件同步目标节点",
      "配置同步排除规则",
      "查看当前同步方向",
      "首次文件基线同步预览",
      "文件变化检测设置",
      "大文件同步策略",
      "文件传输完整性检查",
      "同步失败重试策略",
      "文件删除保护策略",
      "查看同步任务及进度",
      "查看同步错误日志",
      "查看文件同步历史",
      "生成文件同步配置报告",
      "暂停或恢复指定同步任务",
      "删除指定同步配置",
      "MySQL 专用配置同步管理"
    ]
  ],
  "7c": [
    "MySQL 专用配置同步管理",
    [
      "查看 A/B/C/D MySQL 配置状态",
      "选择需要管理的 MySQL 配置文件",
      "查看 MySQL 配置差异",
      "生成配置同步预览",
      "检查目标节点版本兼容性",
      "检查 server_id 冲突",
      "检查节点专属参数",
      "检查 GTID 与 Binlog 参数",
      "检查配置文件权限",
      "配置备份与版本记录",
      "查看配置同步任务",
      "查看配置同步历史"
    ]
  ],
  "8": [
    "8. 主控运行环境检查与安装管理",
    [
      "查看监控 A-C 运行环境",
      "检查指定主控绑定节点",
      "自动识别操作系统",
      "检查系统版本及兼容性",
      "检查 CPU、内存、磁盘及网络",
      "检查所需软件和依赖",
      "生成环境安装清单",
      "生成环境安装计划",
      "检查已安装组件",
      "检查服务目录和权限",
      "查看环境安装历史",
      "检查安装失败原因",
      "查看主控运行状态"
    ]
  ],
  "9": [
    "9. 手动生产迁移与计划维护",
    [
      "查看当前生产拓扑",
      "手动切换生产节点",
      "临时迁移到指定节点",
      "永久迁移到指定节点",
      "计划维护当前生产节点",
      "查看迁移前安全检查",
      "查看迁移任务及执行进度",
      "查看迁移历史和审计记录",
      "取消尚未执行的迁移任务",
      "临时迁移期限管理",
      "到期回切安全评估",
      "手动执行安全回切",
      "查看当前生产主节点和全部备用节点",
      "查看迁移失败原因"
    ]
  ],
  "9s": [
    "手动切换生产节点",
    [
      "选择生产节点 A",
      "选择生产节点 B",
      "选择生产节点 C",
      "选择生产节点 D",
      "执行切换前安全检查",
      "检查 GTID 和数据一致性",
      "检查旧 Primary 写入隔离",
      "检查 MySQL 复制状态",
      "检查网站文件同步状态",
      "检查 MySQL 专用配置兼容性",
      "查看新旧节点传输方向",
      "生成切换预览",
      "确认并提交切换任务（阶段二仅模拟）"
    ]
  ],
  "9t": [
    "临时生产迁移",
    [
      "选择临时目标节点",
      "设置临时迁移期限",
      "查看迁移前安全检查",
      "查看迁移预览",
      "确认临时迁移",
      "查看临时迁移状态",
      "修改尚未生效的迁移期限",
      "取消尚未执行的迁移任务"
    ]
  ],
  "9p": [
    "永久生产迁移",
    [
      "选择永久目标节点",
      "检查目标节点资格",
      "检查 GTID 和数据一致性",
      "检查旧 Primary 隔离条件",
      "检查网站文件同步状态",
      "检查 MySQL 专用配置兼容性",
      "查看迁移预览",
      "二次确认永久迁移",
      "查看迁移结果"
    ]
  ],
  "9m": [
    "生产节点计划维护",
    [
      "选择需要维护的生产节点",
      "选择接管目标",
      "设置维护开始时间",
      "设置维护结束时间",
      "检查接管条件",
      "检查新节点准备情况",
      "查看维护计划",
      "确认维护计划",
      "查看维护状态",
      "取消尚未开始的维护"
    ]
  ],
  "10": [
    "10. 自动生产迁移",
    [
      "查看自动生产迁移状态",
      "启用 / 停用自动迁移策略",
      "配置自动迁移目标",
      "配置计划维护时间",
      "检查新生产节点准备情况",
      "检查 MySQL 数据一致性",
      "检查 GTID 和复制追平状态",
      "检查网站文件同步状态",
      "检查 MySQL 专用配置兼容性",
      "检查旧生产节点隔离条件",
      "生成自动迁移预览",
      "查看自动迁移执行进度",
      "查看自动迁移历史",
      "查看自动迁移失败原因",
      "查看维护完成后的生产恢复状态"
    ]
  ]
}
@@ABC_END

@@ABC_FILE tests/safe_fixture.py 600 26d8a2d89cf18d6b41c5b3c03f4d8fd3893b723605604214721e62a830b0100a
"""Owned, bounded test fixtures; never copy runtime trees or delete failed fixtures."""
from pathlib import Path
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import uuid

DEFAULT = Path('/var/tmp/a-b-c-d-MySQL-tests')


def external(source, destination):
    src = Path(source).resolve(strict=True)
    dst = Path(destination).resolve()
    if dst == src or src in dst.parents:
        raise ValueError('测试目录位于项目内部，拒绝复制')
    return src, dst


def create(source):
    base = Path(os.environ.get('TMPDIR', str(DEFAULT)))
    external(source, base)
    if base.is_symlink(): raise ValueError('测试基目录不可是符号链接')
    base.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = base.stat()
    if info.st_uid != os.geteuid() or info.st_mode & 0o022:
        raise ValueError('测试目录所有者或权限不安全')
    path = Path(tempfile.mkdtemp(prefix='abc-test-', dir=base))
    token = uuid.uuid4().hex
    (path/'.abc-test-owner').write_text(token)
    (path/'.abc-test-owner').chmod(0o600)
    return path, token


def copy_project(source, destination, timeout=30):
    src, dst = external(source, destination)
    subprocess.run([sys.executable, str(Path(__file__).resolve()), '--copy', str(src), str(dst)],
                   check=True, timeout=timeout)


def copy_impl(source, destination):
    src, dst = external(source, destination)
    dst.mkdir(mode=0o700)
    # Only code/docs/tests/config; never walk source data/logs/tmp.
    allowed = ('scripts', 'modules', 'tests', 'docs', 'config')
    count = 0
    total = 0
    for folder in allowed:
        start = src/folder
        if not start.is_dir() or start.is_symlink(): raise ValueError('源目录不安全')
        for root, dirs, files in os.walk(start, followlinks=False):
            dirs[:] = [d for d in dirs if d != '__pycache__']
            for d in dirs:
                if (Path(root)/d).is_symlink(): raise ValueError('源码目录链接拒绝')
            relative = Path(root).relative_to(src)
            (dst/relative).mkdir(mode=0o700, parents=True, exist_ok=True)
            for name in files:
                p = Path(root)/name
                if p.is_symlink() or not p.is_file(): raise ValueError('源码文件类型不安全')
                count += 1; total += p.stat().st_size
                if count > 1000 or total > 20*1024*1024: raise ValueError('复制预算超过上限')
                shutil.copy2(p, dst/p.relative_to(src))
    for name in ('a-b-c-d-MySQL.sh', 'README.md'):
        p=src/name
        if p.is_symlink(): raise ValueError('入口链接拒绝')
        shutil.copy2(p,dst/name)
    for folder in ('data','logs','tmp','systemd'):(dst/folder).mkdir(mode=0o700)


def cleanup(source, path, token):
    _, path = external(source, path)
    info=path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode)!=0o700:
        raise ValueError('拒绝清理不可信测试目录')
    marker=path/'.abc-test-owner'
    if marker.is_symlink() or marker.read_text()!=token: raise ValueError('测试所有权标记不匹配')
    shutil.rmtree(path)


if __name__=='__main__':
    if len(sys.argv)!=4 or sys.argv[1]!='--copy': raise SystemExit(2)
    copy_impl(sys.argv[2],sys.argv[3])

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

@@ABC_FILE tests/test_batch1.py 600 9888d002715461085d7ba98ac01561e1b2170a47930233ecc0d4c890f3ec8eca
"""Batch-one menu and write-entry audit. No production executors."""
import ast
import contextlib
import io
import json
import os
import re
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
from test_framework import FrameworkTests,SOURCE
sys.path.insert(0,str(SOURCE/'modules'))
from management_ui import UI,Cancel
from menu_spec import MENUS,CHILDREN

# Reviewed formal contract independent of menu_spec at test runtime.
CONTRACT=Path(__file__).with_name('formal-menu-contract.json')

class BatchOneTests(FrameworkTests):
 def contract(self):return json.loads(CONTRACT.read_text())
 def test_all_submenu_exact_names_order_and_offline_status(self):
  before=self.snapshot()
  for key,(title,items) in self.contract().items():
   with self.subTest(menu=key):
    import subprocess
    p=subprocess.run([sys.executable,'-B',str(self.root/'modules/management_ui.py'),key],input='0\n',capture_output=True,text=True,env=self.env,timeout=10)
    self.assertEqual(p.returncode,0,p.stderr)
    self.assertIn('【'+title+'】',p.stdout)
    actual=[x for x in p.stdout.splitlines() if re.match(r'^\d+\. ',x)]
    parent='返回第7项' if key=='7c' else '返回第9项' if key in ('9s','9t','9p','9m') else '返回主菜单'
    self.assertEqual(actual,[f'{i}. {name}' for i,name in enumerate(items,1)]+['0. '+parent])
    self.assertIn('阶段二离线模型；未执行任何业务操作。',p.stdout)
    self.assertNotIn('真实服务正常',p.stdout);self.assertNotIn('按回车继续',p.stdout)
  self.assertEqual(before,self.snapshot())
 def test_main_and_all_nested_paths_return_without_pause(self):
  paths=[[str(i)] for i in range(1,11)]+[['7','22'],['9','2'],['9','3'],['9','4'],['9','5'],['9','12']]
  for path in paths:
   with self.subTest(path=path):
    result=self.run_cli(text='\n'.join(path+['0']*(len(path)+1))+'\n')
    self.assertEqual(result.returncode,0,result.stderr);self.assertTrue(result.stdout.endswith('已退出\n'));self.assertNotIn('按回车继续',result.stdout)
 def test_every_menu_option_dispatches_exact_choice(self):
  # Test loop routing separately from handlers so a mislabeled case is visible.
  for key,(_,items) in self.contract().items():
   for c in range(1,len(items)+1):
    ui=UI(self.root,dry=True)
    with self.subTest(menu=key,choice=c),contextlib.redirect_stdout(io.StringIO()),patch('builtins.input',side_effect=[str(c),'','0']),patch.object(ui,'action') as call:
     # A child loop is tested by the previous real-CLI path cases.
     if (key,c) in CHILDREN:continue
     ui.loop(key);call.assert_called_once_with(key,c)
 def test_every_handler_reachable_or_cancels_without_writes(self):
  before=self.snapshot();statuses=[]
  for key,(_,items) in self.contract().items():
   for c in range(1,len(items)+1):
    if (key,c) in CHILDREN:continue
    ui=UI(self.root,dry=True);output=io.StringIO()
    with self.subTest(menu=key,choice=c),contextlib.redirect_stdout(output),patch('builtins.input',side_effect=Cancel),patch('getpass.getpass',side_effect=Cancel):
     try:ui.action(key,c);status='returned'
     except Cancel:status='cancelled'
     except ValueError as e:
      # A missing maintenance draft must fail explicitly, not leak KeyError.
      self.assertEqual((key,c),('9m',8));self.assertIn('维护计划尚未配置完整',str(e));status='blocked_missing_draft'
     statuses.append((key,c,status))
     self.assertNotIn('真实服务正常',output.getvalue())
  self.assertEqual(before,self.snapshot());self.assertGreater(len(statuses),150)
 def test_all_model_ui_mutations_share_transaction_gateway(self):
  tree=ast.parse((SOURCE/'modules/management_ui.py').read_text())
  methods={n.name:n for n in ast.walk(tree) if isinstance(n,ast.FunctionDef)}
  callers=[]
  for method,node in methods.items():
   for call in ast.walk(node):
    if isinstance(call,ast.Call) and isinstance(call.func,ast.Attribute) and call.func.attr=='transaction':callers.append(method)
  self.assertEqual(callers,['submit'])
  s=ast.get_source_segment((SOURCE/'modules/management_ui.py').read_text(),methods['submit'])
  self.assertIn("d['version']",s);self.assertIn("request",s);self.assertEqual(s.count("!='yes'"),2)
 def test_transaction_stale_id_conflict_audit_recovery(self):
  from node_functions import Store
  store=Store(self.root)
  for phase in ('prepared','published'):
   d=store.load() if (store.folder/'topology.json').exists() else {'version':0}
   request='batch1-'+phase;fields={'identity':phase,'address':phase,'remark':phase};node='A' if phase=='prepared' else 'B'
   with self.assertRaises(InterruptedError):store.transaction(request,d['version'],'register',node,fields,phase)
   after=store.transaction(request,d['version'],'register',node,fields)
   self.assertEqual(after['version'],d['version']+1);self.assertEqual(after['audit'][-1]['operation_id'],request)
   self.assertEqual(store.transaction(request,d['version'],'register',node,fields),after)
   with self.assertRaises(ValueError):store.transaction(request,d['version'],'register','D',fields)
   with self.assertRaises(ValueError):store.transaction(request+'stale',0,'remark',node,{'remark':'stale'})
 def test_cf_stale_config_guard_and_token_free_audit(self):
  from cloudflare_config import Cloudflare
  import hashlib
  cf=Cloudflare(self.root);raw,_=cf.read();digest=hashlib.sha256(raw.encode()).hexdigest()
  cf.update({'CF_DOMAIN':'example.com'},digest)
  with self.assertRaises(ValueError):cf.update({'CF_DOMAIN':'other.example.com'},digest)
  self.assertEqual(cf.history()[-1]['event'],'COMMITTED')
  self.assertEqual(cf.status()['domain'],'example.com')
 def test_unknown_state_preserves_no_health_claim(self):
  before=self.snapshot();result=self.run_cli(text='5\n14\n\n0\n0\n')
  self.assertIn('尚未检查',result.stdout);self.assertIn('状态未知',result.stdout);self.assertNotIn('真实服务正常',result.stdout);self.assertEqual(before,self.snapshot())
 def test_incomplete_maintenance_submit_fails_safe(self):
  before=self.snapshot();p=self.run_cli(text='9\n5\n8\n0\n0\n0\n')
  self.assertEqual(p.returncode,0,p.stderr);self.assertIn('维护计划尚未配置完整',p.stdout);self.assertNotIn('Traceback',p.stdout+p.stderr);self.assertEqual(before,self.snapshot())

if __name__=='__main__':
 r=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(BatchOneTests(n) for n in BatchOneTests.__dict__ if n.startswith('test_')))
 raise SystemExit(not r.wasSuccessful())

@@ABC_END

@@ABC_FILE tests/test_cf_transactions.py 600 a00b9942dd2a7f043efe554a67c71e8ed45c47104292add8495e9848acf77840
"""CF config transactions: real local races/crashes and fault injection."""
import sys,os,json,subprocess,select,errno
from unittest.mock import patch
import unittest
from test_framework import FrameworkTests,SOURCE
sys.path.insert(0,str(SOURCE/'modules'))
from cloudflare_config import Cloudflare
from config_transaction import ConfigTransaction,digest

class CFTests(FrameworkTests):
 def tx(self):return ConfigTransaction(self.root)
 def version(self):return digest(self.tx().raw())
 def test_idempotency_and_conflict(self):
  cf=Cloudflare(self.root);v=self.version();a=cf.update({'CF_DOMAIN':'example.com'},v,'same');self.assertEqual(cf.update({'CF_DOMAIN':'example.com'},v,'same'),a);self.assertEqual(len(cf.history()),1)
  with self.assertRaises(ValueError):cf.update({'CF_DOMAIN':'other.com'},v,'same')
  with self.assertRaises(ValueError):cf.update({'CF_DOMAIN':'other.com'},v,'different')
 def test_real_two_process_same_version(self):
  v=self.version();code="from cloudflare_config import Cloudflare;import sys;Cloudflare(sys.argv[1]).update({'CF_DOMAIN':sys.argv[2]},sys.argv[3],sys.argv[4])"
  ps=[subprocess.Popen([sys.executable,'-B','-c',code,str(self.root),domain,v,'op'+str(i)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=dict(self.env,PYTHONPATH=str(SOURCE/'modules'))) for i,domain in enumerate(('one.com','two.com'))]
  codes=[]
  for p in ps:p.communicate(timeout=20);codes.append(p.returncode)
  self.assertEqual(sum(c==0 for c in codes),1);self.assertEqual(len(Cloudflare(self.root).history()),1)
 def crash(self,phase,recover=False):
  code="""from config_transaction import ConfigTransaction
from cloudflare_config import Cloudflare
import sys
s=ConfigTransaction(sys.argv[1]);phase=sys.argv[2];original=s.io.write;atomic=s.atomic
# Durable checkpoints on real filesystem.
def write(name,value):
 original(name,value)
 if (phase=='prepared' and name=='config-transaction.json' and value.get('status')=='PREPARED') or (phase=='audit' and name=='config-ledger.json'):
  print('READY',flush=True);sys.stdin.readline()
def publish(name,value):
 atomic(name,value)
 if phase=='published' and name=='config.env':print('READY',flush=True);sys.stdin.readline()
s.io.write=write;s.atomic=publish
if sys.argv[3]=='recover':s.recover()
else:s.update({'CF_DOMAIN':'example.com'},sys.argv[4],'crash')
"""
  p=subprocess.Popen([sys.executable,'-B','-c',code,str(self.root),phase,'recover' if recover else 'update',self.version()],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=dict(self.env,PYTHONPATH=str(SOURCE/'modules')))
  self.assertTrue(select.select([p.stdout],[],[],20)[0]);line=p.stdout.readline().strip();self.assertEqual(line,'READY');p.kill();p.communicate(timeout=10);self.assertEqual(p.returncode,-9)
 def test_kill_prepared_and_recovery_killed_again(self):
  self.crash('prepared');self.crash('published',True);self.tx().recover();self.assertEqual(Cloudflare(self.root).status()['domain'],'example.com');self.assertEqual(len(Cloudflare(self.root).history()),1)
 def test_kill_after_config_before_audit(self):
  self.crash('published');self.tx().recover();self.assertEqual(len(Cloudflare(self.root).history()),1)
 def test_kill_after_audit_before_commit(self):
  self.crash('audit');self.tx().recover();self.assertEqual(len(Cloudflare(self.root).history()),1)
 def test_history_failure_then_recovery(self):
  tx=self.tx();old=tx.io.write
  def fail(name,v):
   if name=='config-ledger.json':raise OSError(errno.ENOSPC,'injected')
   old(name,v)
  with patch.object(tx.io,'write',side_effect=fail):
   with self.assertRaises(OSError):tx.update({'CF_DOMAIN':'example.com'},self.version(),'disk')
  with self.assertRaises(ValueError):Cloudflare(self.root).status()
  tx.recover();self.assertEqual(len(Cloudflare(self.root).history()),1)
 def test_no_overwrite_external_change(self):
  self.crash('prepared');p=self.root/'config/config.env';p.write_text(p.read_text().replace('CF_DOMAIN=""','CF_DOMAIN="external.com"'));before=p.read_bytes()
  with self.assertRaises(ValueError):self.tx().recover()
  self.assertEqual(before,p.read_bytes())
 def test_permissions_and_disk_failure(self):
  p=self.root/'config/config.env';p.chmod(0o644)
  with self.assertRaises(ValueError):Cloudflare(self.root).update({'CF_DOMAIN':'example.com'},'x','bad')
  p.chmod(0o600);before=p.read_bytes();tx=self.tx()
  with patch.object(tx,'atomic',side_effect=OSError(errno.ENOSPC,'injected')):
   with self.assertRaises(OSError):tx.update({'CF_DOMAIN':'example.com'},self.version(),'full')
  self.assertEqual(before,p.read_bytes())
 def test_monitor_and_cf_shared_publisher(self):
  cf=Cloudflare(self.root);cf.update({'CF_DOMAIN':'example.com'},self.version(),'cf');tx=self.tx();tx.update({'MONITOR_INTERVAL':'40','STATUS_EXPIRE_SECONDS':'60'},self.version(),'monitor','monitor');self.assertEqual(cf.status()['domain'],'example.com');self.assertEqual(len(tx.ledger()['operations']),2)
  p=self.run_cli('--interval','45',script='scripts/monitor.sh');self.assertEqual(p.returncode,0,p.stderr);self.assertEqual(cf.status()['domain'],'example.com')
 def test_delete_and_secret_free_audit(self):
  cf=Cloudflare(self.root);cf.update({'CF_API_TOKEN':'SENSITIVE_SENTINEL_123456789'},self.version(),'token');self.assertNotIn('SENSITIVE_SENTINEL',json.dumps(cf.history())+json.dumps(cf.status()));cf.update({'CF_API_TOKEN':'','CF_ZONE_ID':'','CF_DOMAIN':''},self.version(),'delete');self.assertEqual(cf.status()['token'],'未配置')
 def test_old_cli_no_config_change(self):
  before=self.conf.read_bytes();p=self.run_cli(script='scripts/cloudflare.sh');self.assertEqual(p.returncode,3);self.assertEqual(before,self.conf.read_bytes())
 def test_recovery_cli_double_confirmation(self):
  self.crash('published');p=self.run_cli('--recover',script='scripts/cloudflare.sh',text='yes\nyes\n');self.assertEqual(p.returncode,0,p.stderr);self.assertEqual(Cloudflare(self.root).status()['domain'],'example.com')
 def test_old_monitor_cli_racing_new_cf(self):
  code="from cloudflare_config import Cloudflare;from config_transaction import ConfigTransaction,digest;import sys;c=Cloudflare(sys.argv[1]);c.update({'CF_DOMAIN':'example.com'},digest(ConfigTransaction(sys.argv[1]).raw()),'race-cf')"
  p=subprocess.Popen([sys.executable,'-B','-c',code,str(self.root)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=dict(self.env,PYTHONPATH=str(SOURCE/'modules')))
  monitor=self.run_cli('--interval','50',script='scripts/monitor.sh');p.communicate(timeout=20)
  # A losing request may be refused; retry from latest state must preserve both.
  if p.returncode:Cloudflare(self.root).update({'CF_DOMAIN':'example.com'},self.version(),'retry-cf')
  if monitor.returncode:self.assertEqual(self.run_cli('--interval','50',script='scripts/monitor.sh').returncode,0)
  self.assertEqual(Cloudflare(self.root).status()['domain'],'example.com');self.assertIn('MONITOR_INTERVAL="50"',self.conf.read_text())

if __name__=='__main__':
 r=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(CFTests(n) for n in CFTests.__dict__ if n.startswith('test_')));raise SystemExit(not r.wasSuccessful())

@@ABC_END

@@ABC_FILE tests/test_colors.py 600 6194e8b00c35d9d16052922feec7c04ad55907ac89af07e7f5d57f1a445365f9
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
            for expected in ('当前生产主节点：\033[32mA\033[0m','当前备用节点：\033[33mB\033[0m','当前同步方向：\033[34mA → B\033[0m','服务器在线：\033[32m正常\033[0m'):
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

@@ABC_FILE tests/test_distribution.py 600 c8cdced1a8e1ebf0f16a9640236877bf4593d1c22f35b19925afa83d8f7ae21f
import subprocess
from pathlib import Path
import uuid
root=Path('/home/a-b-c-d-MySQL')
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
        run(['docker','cp','/root/yingyong/a-b-c-d-MySQL.sh',name+':/root/portable.sh'])
        # Fresh official slim container: no /home project, no mounted host directories.
        run(['docker','exec',name,'bash','-c','test ! -e /home/a-b-c-d-MySQL; test ! -e /root/yingyong; mkdir -m 700 /root/scratch; command -v python3 || true'])
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

@@ABC_FILE tests/test_domain_crashes.py 600 5e7706c502ec56758171fe92d1077f123d06f18fc8d9f540d4d61c1df0dd5ee9
"""Real local subprocess crashes and offline fault injection, never production."""
import errno
import json
import os
import subprocess
import sys
import unittest
from unittest.mock import patch
from test_domains import DomainTests,SOURCE
from domain_store import DOMAINS

class CrashTests(DomainTests):
 def worker(self,domain,phase):
  version={n:r['version'] for n,r in self.ds.records().items()}
  code="""import sys,json,time
from domain_store import DomainStore
s=DomainStore(sys.argv[1]);domain=sys.argv[2];phase=sys.argv[3];original=s.io
# Inject a checkpoint after durable real filesystem publication, not before it.
def factory(name):
 io=original(name);write=io.write
 def wrapped(path,value):
  write(path,value)
  if name==domain and ((phase=='prepared' and path=='transaction.json' and value.get('status')=='PREPARED') or (phase=='published' and path=='state.json')):
   print('CHECKPOINT',flush=True);sys.stdin.readline()
 io.write=wrapped;return io
s.io=factory
fields={'production_priority':list('DCBA')} if domain=='production' else {'monitor_priority':list('CBA')}
s.transaction('kill-'+domain+'-'+phase,json.loads(sys.argv[4]),'priorities','A',fields)
"""
  p=subprocess.Popen([sys.executable,'-B','-c',code,str(self.root),domain,phase,json.dumps(version)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=dict(self.env,PYTHONPATH=str(SOURCE/'modules')))
  import select
  self.assertTrue(select.select([p.stdout],[],[],10)[0],'checkpoint timeout')
  self.assertEqual(p.stdout.readline().strip(),'CHECKPOINT');p.kill();stdout,stderr=p.communicate(timeout=10);self.assertEqual(p.returncode,-9)
  return version
 def test_process_kill_all_domain_publication_boundaries(self):
  self.ready()
  for domain in ('production','monitoring'):
   for phase in ('prepared','published'):
    with self.subTest(domain=domain,phase=phase):
     v=self.worker(domain,phase);other='monitoring' if domain=='production' else 'production'
     fields={'monitor_priority':list('ABC')} if other=='monitoring' else {'production_priority':list('ABCD')}
     self.ds.transaction('opposite-'+domain+'-'+phase,v,'priorities','A',fields)
     digest=self.digest(other);self.ds.recover(domain);self.assertEqual(digest,self.digest(other));d=self.ds.load()
     self.assertEqual(d['domain_versions'][domain],v[domain]+1)
     intended={'production_priority':list('DCBA')} if domain=='production' else {'monitor_priority':list('CBA')}
     before=self.digest(domain);self.ds.transaction('kill-'+domain+'-'+phase,v,'priorities','A',intended);self.assertEqual(before,self.digest(domain))
 def test_prepared_audit_not_reported_committed(self):
  self.ready();v=self.ds.load()['domain_versions']
  with self.assertRaises(InterruptedError):self.ds.transaction('pending',v,'priorities','A',{'monitor_priority':list('CBA')},'published')
  with self.assertRaises(ValueError):self.ds.audit('monitoring')
  self.ds.recover('monitoring');self.assertEqual(self.ds.audit('monitoring')[-1]['operation_id'],'pending')
 def test_pending_intent_blocks_conflicting_registry_policy(self):
  self.setup_domains()
  self.tx('register','C',dict(identity='id-C',address='host-C',remark='C'))
  self.tx('qualify','C',dict(identity_verified=True,data_verified=True,resources=self.resources()))
  # No production function: a pending monitor binding must still reserve Active.
  v=self.ds.load()['domain_versions']
  with self.assertRaises(InterruptedError):self.ds.transaction('monitor-intent',v,'monitor_bind','C',dict(slot='A',profile=self.profile()),'prepared')
  old=self.digest('registry')
  with self.assertRaises(ValueError):self.ds.transaction('retire',v,'retire','C',{})
  self.assertEqual(old,self.digest('registry'));self.ds.recover('monitoring');self.assertEqual(self.ds.load()['nodes']['C']['monitor'],'Backup Monitor')
 def test_enospc_before_intent_keeps_domains(self):
  self.ready();before={n:self.digest(n) for n in DOMAINS};version=self.ds.load()['domain_versions']
  from topology_model import Store
  with patch.object(Store,'write',side_effect=OSError(errno.ENOSPC,'injected disk full')):
   with self.assertRaises(OSError):self.ds.transaction('full',version,'priorities','A',{'production_priority':list('DCBA')})
  self.assertEqual(before,{n:self.digest(n) for n in DOMAINS})
 def test_commit_gate_blocks_then_releases(self):
  self.ready();v=self.ds.load()['domain_versions']
  code="from domain_store import DomainStore;import sys,json;s=DomainStore(sys.argv[1]);print('START',flush=True);s.transaction('wait',json.loads(sys.argv[2]),'priorities','A',{'monitor_priority':list('CBA')});print('DONE',flush=True)"
  with self.ds.locked('commit'):
   p=subprocess.Popen([sys.executable,'-B','-c',code,str(self.root),json.dumps(v)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=dict(self.env,PYTHONPATH=str(SOURCE/'modules')))
   self.assertEqual(p.stdout.readline().strip(),'START')
   import select
   self.assertFalse(select.select([p.stdout],[],[],0.2)[0]);self.assertIsNone(p.poll())
  stdout,stderr=p.communicate(timeout=10);self.assertEqual(p.returncode,0,stderr);self.assertIn('DONE',stdout)
 def test_recovery_refuses_newer_or_mismatched_state(self):
  self.ready();v=self.ds.load()['domain_versions']
  with self.assertRaises(InterruptedError):self.ds.transaction('bad-recover',v,'priorities','A',{'production_priority':list('DCBA')},'prepared')
  io=self.ds.io('production');r=io.read('state.json');r['state']['management']['production_priority']=list('BACD');io.write('state.json',r)
  other=self.digest('monitoring');current=self.digest('production')
  with self.assertRaises(ValueError):self.ds.recover('production')
  self.assertEqual(other,self.digest('monitoring'));self.assertEqual(current,self.digest('production'))

if __name__=='__main__':
 result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(CrashTests(n) for n in CrashTests.__dict__ if n.startswith('test_')))
 raise SystemExit(not result.wasSuccessful())

@@ABC_END

@@ABC_FILE tests/test_domains.py 600 71a03f57e6b3bee0a17050acc097724fa4e731750957943bbab09049b56a0464
"""Second-batch item1, independent domain acceptance; offline fixtures only."""
import copy
import hashlib
import json
import os
import subprocess
import sys
import time
import unittest
from pathlib import Path
from test_framework import FrameworkTests,SOURCE
sys.path.insert(0,str(SOURCE/'modules'))
from domain_store import DomainStore,DOMAINS
from management_model import CHECKS,AUTO_STAGES,STAGE_PROOF,channels
from node_functions import Store

class DomainTests(FrameworkTests):
 def setup_domains(self):
  self.ds=DomainStore(self.root);self.ds.enable();self.serial=0
 def tx(self,action,node='A',fields=None,request=None,expected=None,interrupt=None):
  self.serial+=1
  return self.ds.transaction(request or 'd'+str(self.serial),expected or self.ds.load()['domain_versions'],action,node,fields or {},interrupt)
 def resources(self):return dict(cpu=4,memory_mib=4096,disk_mib=10000,cpu_percent=10,io_percent=10,network_percent=10,reliable_state=True,isolated_processes=True,checked_at=int(time.time()))
 def profile(self):return dict(id='ubuntu',version='24.04',installed=['python3','bash','util-linux','coreutils','openssh-client','rsync'],cpu=4,memory_mib=4096,disk_mib=10000,network=True,permissions=True,runtime_compatible=True)
 def ready(self):
  self.setup_domains();self.tx('policy',fields=dict(allow_colocation=True))
  for n in 'ABCD':
   self.tx('register',n,dict(identity='id-'+n,address='host-'+n,remark='备注'+n))
   self.tx('qualify',n,dict(identity_verified=True,data_verified=True,resources=self.resources()))
   self.tx('mysql',n,dict(address='10.0.0.'+str(ord(n)-64),port=3306,product='MySQL',version='8.4',server_id=ord(n),gtid=True,binlog=True,user='replicator',auth_ref='vault:mysql/'+n,sources=['10.0.0.0/24'],least_privilege=True,protected_network=True))
   self.tx('production_bind',n)
  self.tx('primary','A',dict(offline_verified=True,proof={k:True for k in CHECKS}))
  self.tx('monitor_bind','A',dict(slot='A',profile=self.profile()))
  self.tx('monitor_bind','C',dict(slot='B',profile=self.profile()))
  self.tx('monitor_handoff','A',dict(slot='A',quorum=True,old_revoked=True,state_transfer=True,health=True,resources=True))
 def digest(self,domain):
  io=self.ds.io(domain)
  return {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in io.folder.iterdir() if p.is_file()}
 def test_01_separate_state_locks_versions_generation_and_audit(self):
  self.ready();d=self.ds.load()
  self.assertEqual(d['primary'],'A');self.assertEqual(d['primary_monitor'],'A')
  for name in DOMAINS:
   self.assertTrue((self.ds.folder/(name+'.lock')).exists());r=self.ds.records()[name];self.assertEqual(r['generation'],r['version']);self.assertTrue(self.ds.audit(name));self.assertTrue(all(a['domain']==name for a in self.ds.audit(name)))
  self.assertNotEqual(self.ds.io('production').folder,self.ds.io('monitoring').folder)
 def test_02_holding_production_lock_allows_monitor_write(self):
  self.ready();prod=self.digest('production')
  with self.ds.locked('production'):
   d=self.tx('environment','C',self.profile());self.assertEqual(d['primary'],'A')
  self.assertEqual(prod,self.digest('production'))
 def test_03_holding_monitor_lock_allows_production_write(self):
  self.ready();mon=self.digest('monitoring')
  with self.ds.locked('monitoring'):
   d=self.tx('auto_policy',fields=dict(enabled=False,target='D',start_at=None))
  self.assertEqual(mon,self.digest('monitoring'));self.assertEqual(d['primary_monitor'],'A')
 def test_04_real_process_concurrent_writes_no_lost_update(self):
  self.ready();v=self.ds.load()['domain_versions'];env=dict(self.env,PYTHONPATH=str(SOURCE/'modules'),PYTHONDONTWRITEBYTECODE='1')
  code="from domain_store import DomainStore;import json,sys;s=DomainStore(sys.argv[1]);s.transaction(sys.argv[2],json.loads(sys.argv[3]),'priorities','A',json.loads(sys.argv[4]))"
  processes=[subprocess.Popen([sys.executable,'-B','-c',code,str(self.root),'same-id',json.dumps(v),json.dumps(f)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=env) for f in (dict(production_priority=list('DCBA')),dict(monitor_priority=list('CBA')))]
  for p in processes:
   stdout,stderr=p.communicate(timeout=10);self.assertEqual(p.returncode,0,stderr)
  d=self.ds.load();self.assertEqual(d['management']['production_priority'],list('DCBA'));self.assertEqual(d['management']['monitor_priority'],list('CBA'))
  self.assertEqual(d['domain_versions']['production'],v['production']+1);self.assertEqual(d['domain_versions']['monitoring'],v['monitoring']+1)
 def test_05_same_domain_idempotent_conflict_and_stale(self):
  self.ready();v=self.ds.load()['domain_versions'];f=dict(production_priority=list('DCBA'));self.tx('priorities',fields=f,request='idem',expected=v);d=self.ds.load();digest=self.digest('production')
  self.tx('priorities',fields=f,request='idem',expected=v);self.assertEqual(digest,self.digest('production'))
  with self.assertRaises(ValueError):self.tx('priorities',fields=dict(production_priority=list('ABCD')),request='idem',expected=v)
  with self.assertRaises(ValueError):self.tx('priorities',fields=f,expected=v)
 def test_06_prepared_recovery_preserves_other_domain(self):
  self.ready();v=self.ds.load()['domain_versions'];f=dict(monitor_priority=list('CBA'))
  with self.assertRaises(InterruptedError):self.tx('priorities',fields=f,request='recover-mon',expected=v,interrupt='prepared')
  production=self.digest('production');self.ds.transaction('recover-mon',v,'priorities','A',f);self.assertEqual(production,self.digest('production'));self.assertEqual(self.ds.load()['management']['monitor_priority'],list('CBA'))
 def test_07_published_recovery_preserves_other_domain(self):
  self.ready();v=self.ds.load()['domain_versions'];f=dict(production_priority=list('DCBA'))
  with self.assertRaises(InterruptedError):self.tx('priorities',fields=f,request='recover-prod',expected=v,interrupt='published')
  monitor=self.digest('monitoring');self.ds.transaction('recover-prod',v,'priorities','A',f);self.assertEqual(monitor,self.digest('monitoring'))
 def test_08_migration_monitor_handoff_interleaved(self):
  self.ready();self.tx('migration_create','D',dict(kind='temporary',task='move-D',proof={k:True for k in CHECKS},duration=300))
  for index,stage in enumerate(AUTO_STAGES[1:]):
   if index==4:
    self.tx('monitor_handoff','C',dict(slot='B',quorum=True,old_revoked=True,state_transfer=True,health=True,resources=True));self.assertEqual(self.ds.load()['primary'],'A')
   self.tx('migration_step','D',dict(task='move-D',proof={v:True for v in STAGE_PROOF.values()}))
  d=self.ds.load();self.assertEqual(d['primary'],'D');self.assertEqual(d['primary_monitor'],'C');self.assertEqual(d['nodes']['A']['lifecycle'],'Active');self.assertIn('A',d['production_isolated']);self.assertNotIn(['D','A'],d['database_edges']);self.assertEqual(d['management']['migration_tasks']['move-D']['status'],'SIMULATED_COMPLETED')
 def test_09_cross_domain_journal_corruption_rejected(self):
  self.ready();io=self.ds.io('production');io.write('transaction.json',dict(status='PREPARED',domain='monitoring'))
  before=self.digest('monitoring')
  with self.assertRaises(ValueError):self.ds.transaction('bad',{n:r['version'] for n,r in self.ds.records().items()},'auto_policy','A',dict(enabled=False))
  self.assertEqual(before,self.digest('monitoring'))
 def test_10_old_models_not_migrated_or_overwritten(self):
  s=Store(self.root);s.transaction('legacy',0,'initialize','A');p=s.folder/'topology.json';old=p.read_bytes();d=DomainStore(self.root)
  with self.assertRaises(ValueError):d.enable()
  self.assertEqual(old,p.read_bytes());self.assertFalse(d.enabled)
 def test_11_no_write_on_views_and_ui_uses_domains(self):
  self.ready();before=self.snapshot();p=self.run_cli(text='3\n0\n4\n0\n9\n0\n0\n');self.assertEqual(p.returncode,0,p.stderr);self.assertEqual(before,self.snapshot());self.assertEqual(Store(self.root).load()['primary'],'A')
 def test_12_audit_fields_and_no_sensitive_content(self):
  self.ready()
  for name in ('production','monitoring'):
   for row in self.ds.audit(name):
    self.assertEqual(set(row),{'timestamp','operation_id','domain','action','before_version','after_version','result','reason_code','source'});self.assertIn('+00:00',row['timestamp']);self.assertNotIn('auth_ref',json.dumps(row));self.assertEqual(row['result'],'OFFLINE_COMMITTED')
 def test_13_permissions_and_unsafe_paths(self):
  self.ready()
  for p in self.ds.folder.rglob('*'):
   self.assertEqual(p.stat().st_mode&0o777,0o700 if p.is_dir() else 0o600)
  io=self.ds.io('monitoring');p=io.folder/'state.json';p.chmod(0o644)
  with self.assertRaises(ValueError):self.ds.load()
 def test_14_old_schema2_write_blocked(self):
  self.setup_domains();from topology_model import Store as OldStore
  with self.assertRaises(ValueError):OldStore(self.root).transaction('old',0,'initialize','A')
 def test_15_registry_change_does_not_drop_bound_roles(self):
  self.ready();old=self.ds.load()
  with self.assertRaises(ValueError):self.tx('retire','C')
  self.assertEqual(old,self.ds.load())
 def test_16_recovery_after_opposite_domain_commit(self):
  self.ready();v=self.ds.load()['domain_versions'];f=dict(production_priority=list('DCBA'))
  with self.assertRaises(InterruptedError):self.ds.transaction('pending',v,'priorities','A',f,'prepared')
  self.ds.transaction('other',v,'priorities','A',dict(monitor_priority=list('CBA')))
  other=self.digest('monitoring');self.ds.transaction('pending',v,'priorities','A',f)
  self.assertEqual(other,self.digest('monitoring'));d=self.ds.load();self.assertEqual(d['management']['monitor_priority'],list('CBA'));self.assertEqual(d['management']['production_priority'],list('DCBA'))
 def test_17_process_holding_domain_lock_does_not_block_other(self):
  self.ready();env=dict(self.env,PYTHONPATH=str(SOURCE/'modules'))
  code="from domain_store import DomainStore;import sys;s=DomainStore(sys.argv[1]);ctx=s.locked('production');ctx.__enter__();print('locked',flush=True);sys.stdin.readline();ctx.__exit__(None,None,None)"
  p=subprocess.Popen([sys.executable,'-B','-c',code,str(self.root)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=env)
  try:
   self.assertEqual(p.stdout.readline().strip(),'locked');d=self.tx('environment','C',self.profile());self.assertEqual(d['primary'],'A')
   with self.assertRaises(BlockingIOError):self.tx('auto_policy',fields=dict(enabled=False))
  finally:
   p.communicate('\n',timeout=10)
  self.assertEqual(p.returncode,0)
 def test_18_first_actual_menu_write_initializes_domains(self):
  p=self.run_cli(text='2\n1\nphysical-A\nhost-A\n备注A\nfirst-register\nyes\nyes\n\n0\n0\n')
  self.assertEqual(p.returncode,0,p.stderr);self.ds=DomainStore(self.root);self.assertTrue(self.ds.enabled);d=self.ds.load();self.assertEqual(d['nodes']['A']['identity'],'physical-A');self.assertIsNone(d['primary']);self.assertFalse((self.root/'data/offline-functions/topology.json').exists())

if __name__=='__main__':
 r=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(DomainTests(n) for n in DomainTests.__dict__ if n.startswith('test_')))
 raise SystemExit(not r.wasSuccessful())

@@ABC_END

@@ABC_FILE tests/test_framework.py 600 d0101d96c437db0708406cd0b93430d81fe753722beec823085cf17d778c0884
#!/usr/bin/env python3
"""Stage-one tests: isolated copy, no network or business operations."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from safe_fixture import create, copy_project, cleanup

SOURCE = Path(__file__).resolve().parents[1]
SCRATCH = Path(os.environ.get('TMPDIR', '/root/.hermes/cache/scratch'))


class FrameworkTests(unittest.TestCase):
    def setUp(self):
        self.base, self.fixture_token = create(SOURCE)
        self.root = self.base / 'project'
        try:
            copy_project(SOURCE, self.root)
        except BaseException:
            print('复制失败，现场保留：' + str(self.base))
            raise
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
            outcome = self._outcome.result
            failed = any(test is self for test, _ in outcome.failures + outcome.errors)
            if failed:
                print('失败测试现场保留：' + str(self.base))
            else:
                cleanup(SOURCE, self.base, self.fixture_token)

    def run_cli(self, *args, text='', script='a-b-c-d-MySQL.sh'):
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
        # Explicit administrator-approved formal contract; do not derive expected
        # labels from implementation constants (that would hide matching drift).
        expected = [
            '1. Cloudflare 免费 DNS 配置',
            '2. 添加节点 / 编辑节点备注',
            '3. 生产 A-D 绑定选择',
            '4. 监控 A-C 绑定选择',
            '5. MySQL 主从复制通信方式',
            '6. MySQL 动态复制拓扑（离线模型；真实配置未启用）',
            '7. SSH + Rsync 网站文件同步（未启用）',
            '8. 主控运行环境检查与安装管理',
            '9. 手动生产迁移与计划维护',
            '10. 自动生产迁移',
            '0. 退出程序',
        ]
        import re
        actual = [line for line in result.stdout.splitlines() if re.match(r'^\d+\. ', line)]
        self.assertEqual(actual, expected)
        self.assertIn('已退出', result.stdout)
        self.assertNotIn('真实服务正常', result.stdout)

    def test_submenu_return_no_pause(self):
        # Formal slot 4 is monitoring; MySQL communication moved to slot 5.
        for number, title, options in (
            (4, '监控 A-C 绑定选择', ('1. 添加绑定', '2. 删除 / 卸载监控配置')),
            (5, 'MySQL 主从复制通信方式', ('1. 查看 A/B/C/D MySQL 通信配置', '18. 删除指定节点通信配置')),
        ):
            with self.subTest(menu=number):
                result = self.run_cli(text=f'{number}\n0\n0\n')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f'【{number}. {title}】', result.stdout)
                for option in options:self.assertIn(option, result.stdout)
                self.assertNotIn('按回车继续', result.stdout)
                self.assertTrue(result.stdout.endswith('已退出\n'))
        # Preserve legacy communication preview capability as a separate direct
        # entry; its old options no longer define the formal main-menu slot.
        result = self.run_cli(text='0\n', script='scripts/communication.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('1. Rsync + SSH', result.stdout)
        self.assertIn('2. WireGuard', result.stdout)
        self.assertNotIn('按回车继续', result.stdout)

    def test_invalid_and_eof(self):
        for text in ('bad\n0\n', '', '4\nwrong\n0\n0\n'):
            self.assertEqual(self.run_cli(text=text).returncode, 0)

    def test_all_menu_branches(self):
        for number in (1, 2, 3, 6, 7, 8):
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
        processes = [subprocess.Popen(['bash', str(self.root / 'a-b-c-d-MySQL.sh'), '--status'],
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

@@ABC_FILE tests/test_management.py 600 3edd2b2b81af504b8d1775bbc19ddf03f153187fefca1eccbb55f70cda183deb
"""Formal stage-two acceptance: isolated fixtures, no real executors."""
import sys,copy,time,json,os,subprocess,hashlib,unittest
from pathlib import Path
from test_framework import FrameworkTests,SOURCE
sys.path.insert(0,str(SOURCE/'modules'))
from node_functions import Store,initial,validate
from management_model import defaults,settings,channels,precheck,environment_plan,sync_preview,CHECKS,AUTO_STAGES,STAGE_PROOF,EXCLUDES
from menu_spec import MAIN,MENUS

class ManagementTests(FrameworkTests):
 def tx(self,action,node='A',fields=None,request=None,interrupt=None):
  s=Store(self.root);d=s.load() if (s.folder/'topology.json').exists() else initial()
  return s.transaction(request or 'op'+str(d['version']),d['version'],action,node,fields or {},interrupt)
 def resources(self):return dict(cpu=4,memory_mib=4096,disk_mib=10000,cpu_percent=10,io_percent=10,network_percent=10,reliable_state=True,isolated_processes=True,checked_at=int(time.time()))
 def mysql(self,n):return dict(address='10.0.0.'+str(ord(n)-64),port=3306,product='MySQL',version='8.4',server_id=ord(n),gtid=True,binlog=True,user='replicator',auth_ref='vault:mysql/'+n,sources=['10.0.0.0/24'],least_privilege=True,protected_network=True)
 def profile(self):return dict(id='debian',version='13',installed=['python3','bash','util-linux','coreutils','openssh-client','rsync'],cpu=4,memory_mib=4096,disk_mib=10000,network=True,permissions=True,runtime_compatible=True)
 def ready(self):
  self.tx('policy',fields=dict(allow_colocation=True))
  for n in 'ABCD':
   self.tx('register',n,dict(identity='id-'+n,address='10.0.0.'+str(ord(n)-64),remark='备注'+n))
   self.tx('qualify',n,dict(identity_verified=True,data_verified=True,resources=self.resources()))
   self.tx('mysql',n,self.mysql(n));self.tx('production_bind',n)
  self.tx('primary',fields=dict(offline_verified=True,proof={k:True for k in CHECKS}))
 def test_formal_menu_contract(self):
  p=self.run_cli(text='0\n');self.assertEqual(p.returncode,0,p.stderr)
  lines=[f'{i}. {v}' for i,v in enumerate(MAIN,1)]
  self.assertEqual([x for x in p.stdout.splitlines() if x in lines],lines)
  self.assertNotIn('11. ',p.stdout);self.assertIn('生产 A：暂无',p.stdout);self.assertIn('监控 C：暂无',p.stdout)
  self.assertNotIn('真实服务正常',p.stdout)
 def test_all_submenus_enter_return(self):
  before=self.snapshot()
  for key in MENUS:
   p=subprocess.run(['python3','-B',str(self.root/'modules/management_ui.py'),key],input='0\n',text=True,capture_output=True,env=self.env,timeout=10)
   self.assertEqual(p.returncode,0,p.stderr)
   for i,name in enumerate(MENUS[key][1],1):self.assertIn(f'{i}. {name}',p.stdout)
  for n in range(1,11):
   p=self.run_cli(text=f'{n}\n0\n0\n');self.assertEqual(p.returncode,0);self.assertIn('已退出',p.stdout);self.assertNotIn('按回车继续',p.stdout)
  self.assertEqual(before,self.snapshot())
 def test_node_registration_and_identity(self):
  for n in 'ABCD':self.tx('register',n,dict(identity='id'+n,address='host'+n,remark='备注'+n))
  d=self.tx('remark','D',dict(remark='美国备用服务器'));self.assertEqual(d['nodes']['D']['identity'],'idD');self.assertEqual(d['database_edges'],[])
  with self.assertRaises(ValueError):self.tx('register','D',dict(identity='other',address='new',remark='重复'))
  with self.assertRaises(ValueError):self.tx('production_bind','A')
 def test_production_monitor_independence_priorities(self):
  self.ready()
  for slot,node in zip('ABC','CDB'):self.tx('monitor_bind',node,dict(slot=slot,profile=self.profile()))
  d=self.tx('production_unbind','B');self.assertEqual(d['nodes']['B']['monitor'],'Backup Monitor')
  d=self.tx('monitor_unbind','D',dict(slot='B'));self.assertEqual(d['nodes']['D']['production'],'Replica')
  m=settings(d);self.assertEqual(m['production_priority'],list('ABCD'));self.assertEqual(m['monitor_priority'],list('ABC'))
  d=self.tx('priorities',fields=dict(production_priority=list('DCBA')));self.assertEqual(settings(d)['monitor_priority'],list('ABC'))
  before=d['primary'];d=self.tx('monitor_handoff','C',dict(slot='A',quorum=True,old_revoked=True,state_transfer=True,health=True,resources=True));self.assertEqual(d['primary'],before)
  with self.assertRaises(ValueError):self.tx('monitor_unbind','C',dict(slot='A'))
  with self.assertRaises(ValueError):self.tx('production_unbind','A')
 def test_directions_all_four_primaries(self):
  self.ready()
  for n in 'ABCD':
   d=Store(self.root).load();e=channels(d,n)
   self.assertEqual({(x['source_node'],x['target_node']) for x in e['database']},{(n,t) for t in 'ABCD' if t!=n})
   self.assertEqual({(x['source'],x['target']) for x in e['files']},{(n,t) for t in 'ABCD' if t!=n})
  self.assertEqual([(x['source_node'],x['target_node']) for x in channels(d,'D')['database']],[('D','A'),('D','B'),('D','C')])
  with self.assertRaises(ValueError):self.tx('primary','D',dict(offline_verified=True))
  d=self.tx('lifecycle','B',dict(lifecycle='Unreachable'));self.assertNotIn(['A','B'],d['database_edges'])
 def test_mysql_security_validation(self):
  self.ready()
  for k,v in [('user','root'),('port',65536),('sources',['0.0.0.0/0']),('server_id',ord('B')),('protected_network',False)]:
   f=self.mysql('A');f[k]=v
   with self.assertRaises(ValueError):self.tx('mysql','A',f)
  f=self.mysql('A');f['password']='SENSITIVE_SENTINEL'
  with self.assertRaises(ValueError):self.tx('mysql','A',f)
 def test_sync_scope_and_guards(self):
  s=defaults()['sync'];s['redis_usage']='CACHE'
  files=[dict(path=p,stable=True,quiet_seconds=5) for p in ['/home/web/beifen/a','/home/web/new/file','/home/web/log/a','/home/web/mysql/a','/home/web/redis/a']]
  out=sync_preview(s,dict(files=files));self.assertEqual([f['path'] for f in out['files']],['/home/web/beifen/a','/home/web/new/file'])
  for f in (dict(files=[]),dict(files=[dict(path='/home/web/big',stable=False,quiet_seconds=0)]),dict(files=files,deletions=['/home/web/a']),dict(files=[dict(path='/home/web/../etc/x',stable=True,quiet_seconds=5)])):
   with self.assertRaises(ValueError):sync_preview(s,f)
  s['delete']=True
  with self.assertRaises(ValueError):sync_preview(s,dict(files=files,deletions=['/home/web/a'],second_confirmation=True))
  self.assertIn('源变化补跑',out['files'][0]['resume']);self.assertFalse(defaults()['sync']['delete'])
 def test_mysql_config_separation(self):
  self.ready();d=self.tx('mysql_config',fields=dict(public={'max_connections':100},nodes={'B':{'server_id':66,'socket':'/b.sock'},'A':{'server_id':65,'socket':'/a.sock'}},sensitive_ref='vault:tls'))
  cfg=channels(d,'D')['mysql_config'];self.assertEqual(next(x for x in cfg if x['target']=='B')['node_specific']['server_id'],66)
  with self.assertRaises(ValueError):self.tx('mysql_config',fields=dict(public={'server_id':65}))
 def test_environment_distros_and_failure(self):
  for distro,version in [('debian','12'),('debian','13'),('ubuntu','22.04'),('ubuntu','24.04')]:
   p=self.profile();p.update(id=distro,version=version);self.assertFalse(environment_plan(p)['missing'])
  p=self.profile();p['id']='unknown'
  with self.assertRaises(ValueError):environment_plan(p)
  self.ready();self.tx('environment','C',self.profile());d=self.tx('environment_simulate','C',dict(success=False));self.assertEqual(settings(d)['environment']['C']['status'],'检查失败')
 def create_task(self,kind='temporary'):
  return self.tx('migration_create','D',dict(kind=kind,task='move-D',proof={k:True for k in CHECKS},duration=300,second_confirmation=kind=='permanent'))
 def finish(self,fail=None):
  d=self.create_task()
  for stage in AUTO_STAGES[1:]:
   proof={v:True for v in STAGE_PROOF.values()}
   if stage==fail:proof[STAGE_PROOF[stage]]=False
   d=self.tx('migration_step','D',dict(task='move-D',proof=proof))
   if stage==fail:return d
  return d
 def test_migration_state_machine_and_deadline(self):
  self.ready();d=self.finish();t=settings(d)['migration_tasks']['move-D'];self.assertEqual(t['status'],'SIMULATED_COMPLETED');self.assertEqual(d['primary'],'D');self.assertIsNotNone(t['expires_at']);self.assertEqual(t['expires_at']-t['effective_at'],300)
  self.assertEqual(d['nodes']['A']['lifecycle'],'Unreachable');self.assertNotIn(['A','D'],d['database_edges']);self.assertEqual([x['stage'] for x in t['trace']],list(AUTO_STAGES))
 def test_barrier_final_gtid_fencing_failure(self):
  self.ready();d=self.finish('WRITE_BARRIER');self.assertEqual(d['primary'],'A');self.assertEqual(settings(d)['migration_tasks']['move-D']['status'],'MANUAL_REQUIRED')
  with self.assertRaises(ValueError):self.tx('migration_step','D',dict(task='move-D',proof={v:True for v in STAGE_PROOF.values()}))
 def test_final_gtid_failure(self):
  self.ready();d=self.finish('FINAL_DATA_CONSISTENCY_CHECK');self.assertEqual(d['primary'],'A');self.assertEqual(settings(d)['migration_tasks']['move-D']['status'],'MANUAL_REQUIRED')
 def test_fencing_failure(self):
  self.ready();d=self.finish('OLD_PRIMARY_FENCING');self.assertEqual(d['primary'],'A')
 def test_commit_failure_never_resume(self):
  self.ready();d=self.finish('TOPOLOGY_COMMIT');t=settings(d)['migration_tasks']['move-D'];self.assertEqual(d['primary'],'A');self.assertFalse(any(x['stage']=='RESUME_APPLICATION_WRITES' for x in t['trace']))
 def test_permanent_no_expiry(self):
  self.ready();d=self.create_task('permanent');self.assertIsNone(settings(d)['migration_tasks']['move-D']['expires_at'])
 def test_auto_policy_guards(self):
  self.ready()
  with self.assertRaises(ValueError):self.create_task('automatic')
  self.tx('auto_policy',fields=dict(enabled=True,target='D',start_at=int(time.time())-1));d=self.create_task('automatic');self.assertEqual(settings(d)['migration_tasks']['move-D']['kind'],'automatic')
 def test_transaction_recovery_idempotence_and_process_lock(self):
  self.ready();s=Store(self.root)
  for marker in ('prepared','published'):
   old=s.load();fields=dict(remark=marker);req='recover-'+marker
   with self.assertRaises(InterruptedError):s.transaction(req,old['version'],'remark','A',fields,marker)
   d=s.transaction(req,old['version'],'remark','A',fields);self.assertEqual(d['version'],old['version']+1)
   self.assertEqual(s.transaction(req,old['version'],'remark','A',fields)['version'],d['version'])
   with self.assertRaises(ValueError):s.transaction(req,old['version'],'remark','B',fields)
  import fcntl
  fd=os.open(s.folder/'operation.lock',os.O_WRONLY);fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
  try:
   code="from node_functions import Store;Store("+repr(str(self.root))+").transaction('parallel',0,'initialize','A')"
   p=subprocess.run([sys.executable,'-B','-c',code],env=dict(self.env,PYTHONPATH=str(SOURCE/'modules')),capture_output=True,text=True,timeout=10);self.assertNotEqual(p.returncode,0);self.assertIn('BlockingIOError',p.stderr)
  finally:os.close(fd)
 def test_nested_json_rejected(self):
  self.ready();d=Store(self.root).load();d['management']['migration_tasks']={'bad':{'stage':'WRONG'}}
  with self.assertRaises(ValueError):validate(d)
 def test_cf_one_config_secret_absence(self):
  from cloudflare_config import Cloudflare
  cf=Cloudflare(self.root);raw,_=cf.read();cf.update(dict(CF_API_TOKEN='SENSITIVE_SENTINEL_123456789'),hashlib.sha256(raw.encode()).hexdigest());self.assertNotIn('SENSITIVE_SENTINEL',json.dumps(cf.status())+json.dumps(cf.history())+json.dumps(cf.check()))
  self.assertEqual((self.root/'config/config.env').stat().st_mode&0o777,0o600)
 def test_dynamic_registered_picker(self):
  self.tx('register','B',dict(identity='idB',address='hostB',remark='美国'))
  p=self.run_cli(text='3\n1\n\n0\n0\n0\n');self.assertIn('物理节点 B：美国',p.stdout);self.assertNotIn('物理节点 A：',p.stdout)
 def test_no_remote_tools_all_views(self):
  for key,choice in [('1',1),('1',4),('1',7),('2',9),('5',14),('6',1),('7',9),('8',1),('9',1),('10',1)]:
   p=self.run_cli(text=f'{key}\n{choice}\n\n0\n0\n');self.assertEqual(p.returncode,0,p.stderr)
 def test_monitor_environment_missing_failure_and_independent_unbind(self):
  self.ready();p=self.profile();p['installed']=[]
  d=self.tx('monitor_bind','D',dict(slot='A',profile=p));self.assertFalse(settings(d)['monitor_bindings']['A']['ready'])
  d=self.tx('environment_simulate','D',dict(success=False));self.assertEqual(settings(d)['monitor_bindings']['A']['environment'],'检查失败')
  with self.assertRaises(ValueError):self.tx('monitor_handoff','D',dict(slot='A',quorum=True,old_revoked=True,state_transfer=True,health=True,resources=True))
  d=self.tx('monitor_unbind','D',dict(slot='A'));self.assertEqual(d['nodes']['D']['production'],'Replica')
 def test_three_channels_each_required(self):
  self.ready()
  for key in ('files','mysql_config','caught_up','gtid_lineage','fencing_possible'):
   proof={k:True for k in CHECKS};proof[key]=False
   self.assertFalse(precheck(Store(self.root).load(),'D',proof)['passed'])
   with self.assertRaises(ValueError):self.tx('migration_create','D',dict(kind='temporary',task='fail-'+key,proof=proof))
 def test_pending_cancel_and_deadline(self):
  self.ready();self.create_task();d=self.tx('migration_deadline',fields=dict(task='move-D',duration=600));self.assertIsNone(settings(d)['migration_tasks']['move-D']['effective_at'])
  d=self.tx('migration_cancel',fields=dict(task='move-D'));self.assertEqual(settings(d)['migration_tasks']['move-D']['status'],'CANCELLED');self.assertEqual(d['primary'],'A')
 def test_automatic_complete_offline_and_monitor_unchanged(self):
  self.ready();self.tx('monitor_bind','C',dict(slot='A',profile=self.profile()));self.tx('monitor_handoff','C',dict(slot='A',quorum=True,old_revoked=True,state_transfer=True,health=True,resources=True))
  self.tx('auto_policy',fields=dict(enabled=True,target='D',start_at=int(time.time())-1));d=self.create_task('automatic')
  for _ in AUTO_STAGES[1:]:d=self.tx('migration_step','D',dict(task='move-D',proof={v:True for v in STAGE_PROOF.values()}))
  self.assertEqual(d['primary'],'D');self.assertEqual(d['primary_monitor'],'C');self.assertEqual(settings(d)['migration_tasks']['move-D']['status'],'SIMULATED_COMPLETED')
 def test_maintenance_plan_and_cancel(self):
  self.ready();now=int(time.time());d=self.tx('maintenance',fields=dict(target='D',start_at=now+600,end_at=now+1200,proof={k:True for k in CHECKS}));self.assertEqual(settings(d)['maintenance']['maintenance']['status'],'PLANNED')
  d=self.tx('maintenance_cancel',fields=dict(id='maintenance'));self.assertEqual(settings(d)['maintenance']['maintenance']['status'],'CANCELLED')
 def test_ssh_mysql_independence(self):
  self.ready();before=settings(Store(self.root).load())['mysql'];d=self.tx('ssh','B',dict(address='10.0.0.2',port=22,user='sync',key_ref='vault:ssh/B',known_hosts_ref='vault:hosts/B'));self.assertEqual(settings(d)['mysql'],before)
  d=self.tx('ssh_remove','B');self.assertEqual(settings(d)['mysql'],before);self.assertEqual(d['nodes']['B']['production'],'Replica')

if __name__=='__main__':
 suite=unittest.TestSuite(ManagementTests(n) for n in ManagementTests.__dict__ if n.startswith('test_'))
 r=unittest.TextTestRunner(verbosity=2).run(suite);raise SystemExit(not r.wasSuccessful())

@@ABC_END

@@ABC_FILE tests/test_manual.py 600 43971b7fb484ceabcac4cf190205b5507fd0162b49531cfedaacb6b960565f39
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
        # Cover all 14 formal actions, not just the old six preview choices.
        for choice in range(1, 15):
            result = self.run_cli('--dry-run', text=f'9\n{choice}\n\n0\n0\n')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('未创建、执行或取消任何真实任务', result.stdout)
            self.assertNotIn('真实服务正常', result.stdout)
            self.assertEqual(before, self.snapshot())
        result = self.run_cli('--dry-run', text='9\n0\n0\n')
        self.assertNotIn('按回车继续', result.stdout)
        self.assertIn('9. 手动生产迁移与计划维护', result.stdout)
        for label in ('生产 A', '备份 B', '备份 C', '备份 D', '监控 A', '监控 B', '监控 C'):
            self.assertIn(label + '：暂无（状态缺失、过期或无法确认）', result.stdout)
        # The formal home panel no longer has the old current-primary label;
        # preserve the actual unknown-primary invariant in its topology view.
        result = self.run_cli('--dry-run', text='9\n1\n\n0\n0\n')
        self.assertIn('"primary": null', result.stdout)
        self.assertIn('"replica": []', result.stdout)
        self.assertEqual(before, self.snapshot())

    def test_absent_stale_and_future_never_green(self):
        for data in (None, {}, sample(900), sample(1001)):
            text = view.render(data, 1000, True)
            self.assertNotIn('\033[32m', text)
            self.assertIn('当前生产主节点：暂无', plain(text))
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

@@ABC_FILE tests/test_menu_layout.py 600 e7658f33a73e117934e6436f76431551060755c45f8c56cbe3b5129c3a34bb79
#!/usr/bin/env python3
"""Exact missing-snapshot main-menu layout, isolated from business services."""
import unittest
from test_framework import FrameworkTests


class LayoutTests(FrameworkTests):
    def expected(self):
        return f'''========================================
      A-B-C-D MySQL 四节点主备容灾管理系统
========================================
实时节点状态：
生产 A：暂无（状态缺失、过期或无法确认）
备份 B：暂无（状态缺失、过期或无法确认）
备份 C：暂无（状态缺失、过期或无法确认）
备份 D：暂无（状态缺失、过期或无法确认）
------------------------
逻辑主控状态：
监控 A：暂无（状态缺失、过期或无法确认）
监控 B：暂无（状态缺失、过期或无法确认）
监控 C：暂无（状态缺失、过期或无法确认）
------------------------
项目目录：{self.root}
离线架构阶段：业务操作未启用
========================================
1. Cloudflare 免费 DNS 配置
2. 添加节点 / 编辑节点备注
3. 生产 A-D 绑定选择
4. 监控 A-C 绑定选择
5. MySQL 主从复制通信方式
6. MySQL 动态复制拓扑（离线模型；真实配置未启用）
7. SSH + Rsync 网站文件同步（未启用）
8. 主控运行环境检查与安装管理
9. 手动生产迁移与计划维护
10. 自动生产迁移
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

@@ABC_FILE tests/test_monitor.py 600 1c5b489508d11b20462c81f5329cd4797b1266c75a2588583577ff43dbac246b
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
        for row in ('1. 查看 C 动态目标','2. 查看 D 动态目标','真实采集未启用','0. 返回主菜单'):
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
        self.assertIn('节点 A：正常',menu)
        self.assertIn('当前生产主节点：暂无',menu)

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
        self.assertIn('当前生产主节点：暂无',self.run_cli('--dry-run',text='0\n').stdout)
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

@@ABC_FILE tests/test_node_functions.py 600 4af75c287f3c26dc418c9fcbf033ffc1cbeba138f2da0d971cf9954e1bab7711
import sys,time,copy,os,fcntl
from pathlib import Path
import unittest
from test_framework import FrameworkTests,SOURCE
sys.path.insert(0,str(SOURCE/'modules'))
from node_functions import Store,targets,conflicts,transition,STAGES

class FunctionTests(FrameworkTests):
 def ready(self):
  s=Store(self.root);d=s.transaction('init',0,'initialize','A')
  def apply(action,node,fields=None):
   nonlocal d
   d=s.transaction('op'+str(d['version']),d['version'],action,node,fields or {});return d
  apply('policy','A',dict(allow_colocation=True))
  for n in 'ABCD':
   apply('join',n,dict(identity='fixture-'+n));apply('activate',n,dict(identity_verified=True,data_verified=True))
   apply('resources',n,dict(cpu=4,memory_mib=4096,disk_mib=10000,cpu_percent=10,io_percent=10,network_percent=10,reliable_state=True,isolated_processes=True,checked_at=int(time.time())))
   apply('replica',n)
  return s,apply
 def test_symmetric_assignments_and_independent_removal(self):
  s,apply=self.ready();apply('primary','A',dict(offline_verified=True));apply('primary_monitor','A',dict(offline_handoff_verified=True))
  apply('backup_monitor','B');apply('backup_monitor','D');d=s.load();edges=copy.deepcopy(d['database_edges'])
  d=apply('remove_monitor','D');self.assertEqual(d['nodes']['D']['production'],'Replica');self.assertEqual(d['database_edges'],edges)
  d=apply('primary_monitor','D',dict(offline_handoff_verified=True));self.assertEqual(d['primary'],'A')
  d=apply('primary','B',dict(offline_verified=True));self.assertEqual(d['nodes']['B']['monitor'],'Backup Monitor');self.assertEqual(d['primary_monitor'],'D')
  d=apply('primary_monitor','C',dict(offline_handoff_verified=True));self.assertEqual(d['nodes']['C']['production'],'Replica')
  for n in 'ABCD':
   before=s.load()['primary_monitor'];d=apply('primary',n,dict(offline_verified=True));self.assertEqual(d['primary_monitor'],before)
  for n in 'ABCD':
   before=s.load()['primary'];d=apply('primary_monitor',n,dict(offline_handoff_verified=True));self.assertEqual(d['primary'],before)
  # A is neither current production nor monitor primary after final D assignments.
  d=apply('remove_production','A');self.assertEqual(d['nodes']['A']['monitor'],'Backup Monitor')
  apply('remove_monitor','A');d=apply('retire','A');self.assertNotIn('A',targets(d,'D'))
  d=apply('join','A',dict(identity='new-A'));self.assertIsNone(d['nodes']['A']['production']);self.assertIsNone(d['nodes']['A']['monitor'])
 def test_conflicts_and_transaction_recovery(self):
  s,apply=self.ready();apply('primary','A',dict(offline_verified=True))
  d=s.load();v=d['version']
  with self.assertRaises(ValueError):s.transaction('resource-fail',v,'resources','A',dict(cpu=1)) if d['nodes']['A']['monitor'] else s.transaction('monitor-fail',v,'primary_monitor','A',dict(offline_handoff_verified=False))
  d=apply('primary_monitor','A',dict(offline_handoff_verified=True));v=d['version']
  with self.assertRaises(ValueError):s.transaction('bad-policy',v,'policy','A',dict(allow_colocation=False))
  with self.assertRaises(ValueError):s.transaction('low-resource',v,'resources','A',dict(cpu=1))
  with self.assertRaises(ValueError):s.transaction('stale',0,'replica','B')
  fields=dict(offline_verified=True)
  with self.assertRaises(InterruptedError):s.transaction('interrupt',v,'primary','B',fields,interrupt='prepared')
  d=s.transaction('interrupt',v,'primary','B',fields);self.assertEqual(d['version'],v+1)
  self.assertEqual(s.transaction('interrupt',v,'primary','B',fields)['version'],v+1)
  with self.assertRaises(ValueError):s.transaction('interrupt',v,'primary','C',fields)
  fd=os.open(s.folder/'operation.lock',os.O_WRONLY);fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
  try:
   with self.assertRaises(BlockingIOError):s.transaction('parallel',d['version'],'replica','C')
  finally:os.close(fd)
 def test_independent_state_machines_and_menu(self):
  for kind,states in STAGES.items():
   for state in states:self.assertEqual(transition(kind,state,False),'MANUAL_REQUIRED')
  before=self.snapshot();p=self.run_cli(text='1\n10\n11\nwrong\n0\n',script='scripts/node_functions.sh')
  self.assertEqual(p.returncode,0);self.assertIn('节点功能管理',p.stdout);self.assertEqual(before,self.snapshot())

if __name__=='__main__':
 result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(FunctionTests(n) for n in FunctionTests.__dict__ if n.startswith('test_')))
 raise SystemExit(not result.wasSuccessful())

@@ABC_END

@@ABC_FILE tests/test_offline_policy.py 600 050c5e497f29a2dbbb8fec4d7f55e9dab2f4bd9177525d26b25c376935b2d2bc
import sys,copy,os,fcntl
from test_node_functions import FunctionTests
from test_framework import SOURCE
sys.path.insert(0,str(SOURCE/'modules'))
from offline_policy import Store,initial,choose,FAILBACK,MONITOR,PROOFS
from node_functions import Store as FStore
from topology_model import Store as OldStore
import unittest

class PolicyTests(FunctionTests):
 def scenario(self,target='B',permanent=False):
  f,apply=self.ready();apply('primary','A',dict(offline_verified=True));apply('primary_monitor','C',dict(offline_handoff_verified=True));apply('backup_monitor','B');apply('backup_monitor','D')
  model=apply('primary',target,dict(offline_verified=True));s=Store(self.root)
  p=s.transaction('migration',0,'migration_completed',dict(model=model,source='A',target=target,offline_completed=True,permanent=permanent,second_confirmation=permanent,duration_seconds=300,now=1000))
  return f,apply,model,s,p
 def evidence(self):return {n:{k:True for k in PROOFS} for n in 'ABCD'}
 def test_temporary_targets_expiry_safety_and_priority(self):
  for target in ('B','D'):
   f,apply,model,s,p=self.scenario(target)
   # separate store reset is only fixture-local between independent cases
   evidence=self.evidence()
   for key in ('lineage','caught_up','fencing','files'):
    ev=copy.deepcopy(evidence)
    for n in ev:ev[n][key]=False
    p=s.transaction('blocked-'+key,p['version'],'expiry',dict(task='migration',model=model,evidence=ev,now=1400))
    self.assertEqual(p['tasks']['migration']['status'],'WAITING_SAFE_WINDOW')
   p=s.transaction('due',p['version'],'expiry',dict(task='migration',model=model,evidence=evidence,now=1400));self.assertEqual(p['tasks']['migration']['selected'],'A')
   p=s.transaction('priority',p['version'],'configure',dict(production_priority=['D','B','A'],production_candidates=list('ABCD')))
   p=s.transaction('recalculate',p['version'],'expiry',dict(task='migration',model=model,evidence=evidence,now=1500));self.assertEqual(p['tasks']['migration']['selected'],'D')
   self.assertEqual(FStore(self.root).load()['primary'],target) # evaluation never executes return
   import shutil
   shutil.rmtree(s.folder);shutil.rmtree(f.folder)
 def test_permanent_restart_idempotency(self):
  f,apply,m,s,p=self.scenario('D',True)
  with self.assertRaises(ValueError):s.transaction('expiry',p['version'],'expiry',dict(task='migration',model=m,evidence=self.evidence(),now=9999))
  reloaded=Store(self.root).load();self.assertIsNone(reloaded['tasks']['migration']['expires_at'])
  args=dict(model=m,source='A',target='D',offline_completed=True,permanent=True,second_confirmation=True,duration_seconds=300,now=1000)
  self.assertEqual(s.transaction('migration',0,'migration_completed',args)['version'],1)
 def test_every_stage_before_after_interrupt_and_cas(self):
  f,apply,m,s,p=self.scenario()
  p=s.transaction('evaluate',p['version'],'expiry',dict(task='migration',model=m,evidence=self.evidence(),now=1400))
  for i,stage in enumerate(FAILBACK[:-1]):
   request='stage'+str(i);params=dict(task='migration',verified=True,now=1400+i);version=p['version']
   with self.assertRaises(InterruptedError):s.transaction(request,version,'stage',params,interrupt='prepared' if i%2==0 else 'published')
   p=Store(self.root).transaction(request,version,'stage',params)
   self.assertEqual(p['tasks']['migration']['stage'],FAILBACK[i+1])
  with self.assertRaises(ValueError):s.transaction('stale',0,'configure',{})
  fd=os.open(s.folder/'policy.lock',os.O_WRONLY);fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
  try:
   with self.assertRaises(BlockingIOError):s.transaction('parallel',p['version'],'configure',{})
  finally:os.close(fd)
 def test_monitor_priority_fail_closed_independence(self):
  f,apply,m,s,p=self.scenario()
  evidence={n:{k:True for k in ('identity','health','authority','old_revoked','state_transfer','quorum','resources')} for n in 'ABCD'}
  for expected in ('B','D',None):
   if expected=='D':evidence['B']['health']=False
   if expected is None:evidence['D']['health']=False
   p=s.transaction('monitor'+str(p['version']),p['version'],'monitor_evaluate',dict(model=m,evidence=evidence,old_unavailable_verified=True))
   self.assertEqual(p['monitor_evaluation']['selected'],expected);self.assertEqual(f.load()['primary'],'B');self.assertEqual(f.load()['primary_monitor'],'C')
  with self.assertRaises(ValueError):OldStore(self.root).transaction('old-write',0,'initialize','C')
  for stage in MONITOR:
   self.assertTrue(stage.startswith('MONITOR_'))
 def test_schema3_published_recovery(self):
  f,apply,m,s,p=self.scenario();v=m['version'];fields=dict(offline_handoff_verified=True)
  with self.assertRaises(InterruptedError):f.transaction('handoff',v,'primary_monitor','D',fields,interrupt='published')
  d=FStore(self.root).transaction('handoff',v,'primary_monitor','D',fields)
  self.assertEqual(d['primary_monitor'],'D');self.assertEqual(d['primary'],'B')

if __name__=='__main__':
 result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(PolicyTests(n) for n in PolicyTests.__dict__ if n.startswith('test_')))
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

@@ABC_FILE tests/test_rename.py 600 92582d12979eb321cf757ef0cf293f30adbaeb951c9497a9ef337e446f1ac5c8
import os,sys,json,subprocess,tempfile
from pathlib import Path
import unittest
from test_framework import FrameworkTests,SOURCE
sys.path.insert(0,str(SOURCE/'modules'))
from topology_model import Store
from dashboard import panel

class RenameTests(FrameworkTests):
 def test_model_panel_roles_and_lifecycle(self):
  s=Store(self.root);d=s.transaction('init',0,'initialize','C')
  for n in 'ABD':
   d=s.transaction('j'+n,d['version'],'join',n,dict(instance_id=n,address='192.0.2.1',database=dict(product='MySQL',version='8')))
   d=s.transaction('a'+n,d['version'],'activate',n,dict(offline_identity_validated=True,offline_data_validated=True))
  for n in 'BD':
   d=s.transaction('p'+n,d['version'],'promote',n,dict(offline_safety_verified=True))
   text=panel(self.root);self.assertIn('当前生产主节点：'+n+'（离线模型）',text)
   self.assertIn('当前协调者：C（离线模型，无执行租约）',text)
  d=s.transaction('r',d['version'],'retire','A');self.assertIn('节点 A / 生命周期：Retired',panel(self.root))
  d=s.transaction('jnew',d['version'],'join','A');self.assertIn('节点 A / 生命周期：Joining',panel(self.root))
 def test_rename_rollback_keeps_all_data(self):
  source=self.base/'old';source.mkdir();(source/'config').write_text('private');(source/'history').write_text('audit')
  target=self.base/'new'
  try:
   os.rename(source,target)
   raise RuntimeError('injected verification failure')
  except RuntimeError:os.rename(target,source)
  self.assertEqual((source/'config').read_text(),'private');self.assertEqual((source/'history').read_text(),'audit');self.assertFalse(target.exists())
 def test_four_nodes_unknown(self):
  text=panel(self.root)
  for n in 'ABCD':self.assertIn('节点 '+n+'：暂无',text)
  self.assertIn('当前拓扑版本：未初始化',text)

if __name__=='__main__':
 suite=unittest.TestSuite(RenameTests(n) for n in RenameTests.__dict__ if n.startswith('test_'))
 result=unittest.TextTestRunner(verbosity=2).run(suite);raise SystemExit(not result.wasSuccessful())

@@ABC_END

@@ABC_FILE tests/test_role_fixes.py 600 813e4938d2a87aee64239cab335347c8eb64ab361f90c172941171fa241d54f5
import unittest
from test_topology import TopologyTests
from topology_model import ROLE_STAGES,role_transition,targets,candidates

class RoleTests(TopologyTests):
 def test_promote_demote_all_and_join_null(self):
  s,d=self.ready()
  for i,node in enumerate(('A','B','D','B','D','B')):
   old=d['primary'];d=s.transaction('switch'+str(i),d['version'],'promote',node,dict(offline_safety_verified=True))
   self.assertEqual(d['primary'],node)
   if old and old!=node:self.assertEqual(d['nodes'][old]['production_role'],'Replica')
   self.assertEqual(d['database_edges'],d['file_edges'])
   self.assertEqual(d['audit'][-1]['role_stages'],list(ROLE_STAGES))
  d=s.transaction('retire',d['version'],'retire','A')
  d=s.transaction('join-again',d['version'],'join','A')
  self.assertIsNone(d['nodes']['A']['production_role'])
  self.assertEqual(d['nodes']['A']['lifecycle'],'Joining')
  self.assertNotIn('A',candidates(d))
  self.assertTrue(all('A' not in edge for edge in d['database_edges']+d['file_edges']))
  with self.assertRaises(ValueError):s.transaction('bad-promote',d['version'],'promote','A',dict(offline_safety_verified=True))
  d=s.transaction('approved',d['version'],'activate','A',dict(offline_identity_validated=True,offline_data_validated=True))
  self.assertEqual(d['nodes']['A']['production_role'],'Replica')
 def test_role_stage_fail_closed(self):
  for state in ROLE_STAGES:self.assertEqual(role_transition(state,False),'MANUAL_REQUIRED')
  state=ROLE_STAGES[0]
  for _ in ROLE_STAGES[1:]:state=role_transition(state,True)
  self.assertEqual(state,'ROLE_CHANGE_COMPLETED')
 def test_dynamic_preview_excludes_retired_and_no_writes(self):
  s,d=self.ready();d=s.transaction('primary',d['version'],'promote','D',dict(offline_safety_verified=True));s.transaction('retire',d['version'],'retire','A')
  before=self.snapshot()
  for script in ('scripts/manual_maintenance.sh','scripts/monitor.sh'):
   p=self.run_cli(text='1\n2\n3\n0\n',script=script)
   self.assertEqual(p.returncode,0,p.stderr)
   if 'manual' in script:self.assertIn('"targets": ["B"]',p.stdout)
   else:self.assertIn('"C": ["B", "D"]',p.stdout)
  self.assertEqual(before,self.snapshot())

if __name__=='__main__':
 result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(RoleTests(n) for n in RoleTests.__dict__ if n.startswith('test_')))
 raise SystemExit(not result.wasSuccessful())

@@ABC_END

@@ABC_FILE tests/test_safe_fixture.py 600 40e15771dff9f4e0cdb7c194ed6598815a998e5391d5d5a91b8d94d3d999b46e
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from safe_fixture import external, create, copy_project, cleanup

SOURCE=Path(__file__).resolve().parents[1]

class FixtureTests(unittest.TestCase):
    def test_internal_and_symlink_rejected_before_copy(self):
        for path in (SOURCE/'tmp/test-scratch',SOURCE/'tmp/new-not-created'):
            with self.assertRaises(ValueError):external(SOURCE,path)
        with tempfile.TemporaryDirectory(dir='/var/tmp') as folder:
            link=Path(folder)/'alias';link.symlink_to(SOURCE,target_is_directory=True)
            with self.assertRaises(ValueError):external(SOURCE,link/'tmp/test')
            with self.assertRaises(ValueError):external(link, SOURCE/'tmp/test')

    def test_invalid_environment_no_copy(self):
        with patch.dict(os.environ,TMPDIR=str(SOURCE/'tmp/test-scratch')):
            with self.assertRaises(ValueError):create(SOURCE)

    def test_copy_excludes_runtime_custom_path_cwd(self):
        with patch.dict(os.environ,{},clear=True):
            base,token=create(SOURCE)
        old=Path.cwd()
        try:
            os.chdir('/')
            copy_project(SOURCE,base/'custom')
            self.assertEqual(list((base/'custom/tmp').iterdir()),[])
            self.assertEqual(list((base/'custom/data').iterdir()),[])
            self.assertTrue((base/'custom/config/config.env').is_file())
            with self.assertRaises(ValueError):cleanup(SOURCE,base,'wrong-token')
            self.assertTrue((SOURCE/'config/config.env').exists())
        finally:
            os.chdir(old);cleanup(SOURCE,base,token)

    def test_copy_timeout_preserves_owned_fixture(self):
        base,token=create(SOURCE)
        try:
            with self.assertRaises(subprocess.TimeoutExpired):copy_project(SOURCE,base/'target',timeout=0.00001)
            self.assertTrue((base/'.abc-test-owner').exists())
            self.assertTrue((SOURCE/'config/config.env').exists())
        finally:cleanup(SOURCE,base,token)

if __name__=='__main__':unittest.main(verbosity=2)

@@ABC_END

@@ABC_FILE tests/test_topology.py 600 41bc98f8a1c6bb4886e911779f1abc29df001c94d3b4c506197abe58a42435f0
import copy
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import sys
import unittest
from test_framework import FrameworkTests,SOURCE
sys.path.insert(0,str(SOURCE/'modules'))
from topology_model import Store,initial,validate,targets,candidates,change


class TopologyTests(FrameworkTests):
    def model(self):return Store(self.root)
    def ready(self):
        s=self.model();data=s.transaction('init',0,'initialize','C')
        for n in ('A','B','D'):
            data=s.transaction('join-'+n,data['version'],'join',n,dict(instance_id=n+'-fixture',address='192.0.2.1',database=dict(product='MySQL',version='8.0')))
            data=s.transaction('activate-'+n,data['version'],'activate',n,dict(offline_identity_validated=True,offline_data_validated=True))
        return s,data
    def test_lifecycle_roles_targets_and_rejoin(self):
        s,data=self.ready()
        for n in ('A','B','D'):
            data=s.transaction('primary-'+n,data['version'],'promote',n,dict(offline_safety_verified=True))
            self.assertEqual(data['primary'],n)
            self.assertEqual(sum(x['production_role']=='Primary' for x in data['nodes'].values()),1)
            self.assertEqual(len(data['database_edges']),2)
        data=s.transaction('retire-A',data['version'],'retire','A')
        self.assertNotIn('A',targets(data,'C'));self.assertNotIn('A',targets(data,'D'))
        self.assertNotIn('A',candidates(data))
        self.assertTrue(all('A' not in edge for edge in data['file_edges']))
        data=s.transaction('rejoin-A',data['version'],'join','A',dict(instance_id='new-A'))
        self.assertEqual(data['nodes']['A']['lifecycle'],'Joining')
        self.assertNotIn('A',candidates(data))
        self.assertIn('A',targets(data,'C'))
        self.assertTrue(any(x['action']=='retire' for x in data['audit']))
    def test_idempotency_conflict_and_corruption(self):
        s,data=self.ready();v=data['version']
        duplicate=s.transaction('activate-D',v-1,'activate','D',dict(offline_identity_validated=True,offline_data_validated=True))
        self.assertEqual(v,duplicate['version'])
        with self.assertRaises(ValueError):s.transaction('activate-D',v,'retire','A')
        with self.assertRaises(ValueError):s.transaction('wrong-version',0,'retire','A')
        p=s.folder/'topology.json';p.write_text('{bad')
        with self.assertRaises(ValueError):s.load()
    def test_lock_and_interruption_reconcile(self):
        s,data=self.ready();version=data['version']
        fd=os.open(s.folder/'operation.lock',os.O_WRONLY)
        fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
        try:
            with self.assertRaises(BlockingIOError):s.transaction('blocked',version,'retire','A')
        finally:os.close(fd)
        for phase,node in (('prepared','A'),('published','B')):
            version=s.load()['version']
            with self.assertRaises(InterruptedError):s.transaction('interrupt-'+node,version,'retire',node,interrupt=phase)
            result=s.transaction('interrupt-'+node,version,'retire',node)
            self.assertEqual(result['version'],version+1)
            self.assertEqual(result['nodes'][node]['lifecycle'],'Retired')
    def test_invalid_primary_delete_and_path_protection(self):
        s,data=self.ready();data=s.transaction('p',data['version'],'promote','B',dict(offline_safety_verified=True))
        with self.assertRaises(ValueError):s.transaction('retire-primary',data['version'],'retire','B')
        with self.assertRaises(ValueError):s.transaction('remove-C',data['version'],'retire','C')
        broken=copy.deepcopy(data);del broken['nodes']['A']
        with self.assertRaises(ValueError):validate(broken)
        broken=copy.deepcopy(data);broken['nodes']['D']['production_role']='Primary'
        with self.assertRaises(ValueError):validate(broken)
        target=s.folder/'topology.json';target.unlink();target.symlink_to(self.conf)
        with self.assertRaises(ValueError):s.load()
    def test_menu_and_no_activity(self):
        before=self.snapshot()
        result=self.run_cli(text='1\n0\n',script='scripts/node_roles.sh')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('节点角色管理',result.stdout);self.assertIn('未配置',result.stdout)
        self.assertEqual(before,self.snapshot())
    def test_dynamic_monitor_guard_retired_no_ssh(self):
        s,data=self.ready();data=s.transaction('retire',data['version'],'retire','A')
        self.config_replace('NODE_ROLE="UNASSIGNED"','NODE_ROLE="C"')
        result=self.run_cli('--once',script='scripts/monitor.sh')
        self.assertNotEqual(result.returncode,0)
        self.assertIn('监控目标=B,D',result.stderr)
        self.assertFalse(self.calls.exists())

if __name__=='__main__':
    names=[n for n in TopologyTests.__dict__ if n.startswith('test_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(TopologyTests(n) for n in sorted(names)))
    raise SystemExit(not result.wasSuccessful())

@@ABC_END
ABC_ALL_PAYLOAD
exit "$result"
