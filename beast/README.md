Please add this crontab entry as root

```shell
# run homelab2.0 sync script everyday at 9AM
0 9 * * * /opt/homelab2.0/beast/sync.sh >> /var/log/homelab2.0-sync.log 2>&1
```
