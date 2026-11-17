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
# frpc 配置
# 由 LuCI -> 服务 -> FRP 内网穿透 管理，也可手工 uci set
# 字段基准：DESIGN.md / 生产 frpc.toml + frps.toml

config common 'common'
	option enabled '1'
	# 服务端（对齐 frps bindPort 26566）
	option server_addr ''
	option server_port '26566'
	option auth_method 'token'
	option auth_token ''
	option auth_additional_scopes 'HeartBeats,NewWorkConns'
	option user ''
	# 传输层（与 frps.toml 的 tcpMux/heartbeat/tls.force 匹配）
	option connect_server_local_ip '0.0.0.0'
	option protocol 'tcp'
	option dial_server_timeout '10'
	option dial_server_keepalive '7200'
	option pool_count '10'
	option heartbeat_interval '30'
	option heartbeat_timeout '90'
	option tcp_mux '1'
	option tcp_mux_keepalive_interval '60'
	option tls_enable '1'
	option use_encryption '0'
	option use_compression '0'
	option udp_packet_size '1500'
	# 日志（console 由 procd/logread 接管，不写 flash）
	option log_to 'console'
	option log_level 'info'
	option log_max_days '7'
	option log_disable_print_color '1'
	# 状态存储（tmpfs；默认关闭，仅 NAT 打洞场景需要）
	option store_enable '0'
	option store_path '/var/etc/frpc/frpc_store.json'
	# 客户端面板（默认关闭，减少攻击面）
	option web_enable '0'
	option web_addr '0.0.0.0'
	option web_port '7400'
	option web_user ''
	option web_password ''
	option web_pprof_enable '0'
	# frps allowPorts 白名单：remotePort 只能取这些值，留空则不做校验
	option allowed_ports '26566,46774,43545,64557,45768,58646,6000,7547'

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
	option role 'server'
	option secret_key ''
	option allow_users ''
EOF

chmod 644 /etc/config/frpc
/etc/init.d/frpc enable >/dev/null 2>&1

exit 0
