#备份删除示例
#crontab -e
#示例
#*/5 * * * * /home/备份/beifen.sh" >/dev/null 2>&1

# 要删除的备份
cd /home/备份/vaultwarden/ && ls -t *.tar.gz | tail -n +100 | xargs -I {} rm {}

cd /home/备份/博客/ && ls -t *.tar.gz | tail -n +5 | xargs -I {} rm {}

cd /home/备份/图床/ && ls -t *.tar.gz | tail -n +5 | xargs -I {} rm {}

cd /home/备份/whmcs/ && ls -t *.tar.gz | tail -n +4 | xargs -I {} rm {}

cd /home/备份/J/ && ls -t *.tar.gz | tail -n +5 | xargs -I {} rm {}

cd /home/备份/V/ && ls -t *.tar.gz | tail -n +5 | xargs -I {} rm {}

cd /home/备份/论坛传送J/ && ls -t *.tar.gz | tail -n +5 | xargs -I {} rm {}

cd /home/备份/论坛传送V/ && ls -t *.tar.gz | tail -n +5 | xargs -I {} rm {}

cd /home/备份/hermes/ && ls -t *.tar.gz | tail -n +4 | xargs -I {} rm {}

cd /home/备份/Openclaw/ && ls -t *.tar.gz | tail -n +4 | xargs -I {} rm {}

cd /home/备份/CLIProxyAPI/ && ls -t *.tar.gz | tail -n +10 | xargs -I {} rm {}

cd /home/备份/Sub2API/ && ls -t *.tar.gz | tail -n +10 | xargs -I {} rm {}

cd /home/备份/Sub2APIboon/ && ls -t *.tar.gz | tail -n +10 | xargs -I {} rm {}

cd /home/备份/nexterm/ && ls -t *.tar.gz | tail -n +10 | xargs -I {} rm {}

cd /home/备份/nezhav0/ && ls -t *.tar.gz | tail -n +5 | xargs -I {} rm {}

cd /home/备份/open-webui/ && ls -t *.tar.gz | tail -n +10 | xargs -I {} rm {}

cd /home/备份/backrest/ && ls -t *.tar.gz | tail -n +10 | xargs -r -I {} rm -- {}

cd /home/备份/无限流量爱马仕/ && ls -t *.tar.gz | tail -n +5 | xargs -r -I {} rm -- {}

cd /home/备份/无限流量龙虾/ && ls -t *.tar.gz | tail -n +5 | xargs -r -I {} rm -- {}

cd /home/备份/爱马仕小说/ && ls -t *.tar.gz | tail -n +5 | xargs -r -I {} rm -- {}





