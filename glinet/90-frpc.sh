#!/bin/sh
# ImageBuilder 首次启动初始化脚本
# 生成 /etc/config/frpc 并启用开机自启。
# 本文件会被 OpenWrt 执行后自动删除，配置本身保留在 /etc/config/frpc。

# 已存在配置则不覆盖，避免升级/重复刷机丢失用户设置
if [ -f /etc/config/frpc ]; then
	/etc/init.d/frpc enable >/dev/null 2>&1
	exit 0
fi

cat > /etc/config/frpc <<'EOF'

config common 'common'
	option enabled '1'
	option server_addr ''
	option server_port '7000'
	option protocol 'tcp'
	option auth_token ''
	option user ''
	option log_level 'info'
	option tls_enable '1'
	option use_encryption '0'
	option use_compression '0'
	option web_enable '0'
	option web_addr '0.0.0.0'
	option web_port '7400'
	option web_user ''
	option web_password ''

config proxy 'ssh'
	option enabled '0'
	option name 'ssh'
	option type 'tcp'
	option local_ip '127.0.0.1'
	option local_port '22'
	option remote_port '6000'
	option custom_domains ''
	option domain ''
	option subdomain ''
	option use_encryption '0'
	option use_compression '0'
EOF

chmod 644 /etc/config/frpc
/etc/init.d/frpc enable >/dev/null 2>&1

exit 0
