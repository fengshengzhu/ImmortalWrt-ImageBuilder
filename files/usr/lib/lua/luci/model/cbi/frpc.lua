local m, s, o

m = Map("frpc", "FRP 内网穿透 - 参数设置",
	"字段以生产 <code>frpc.toml</code> / <code>frps.toml</code> 为基准（frp 0.72.x）。<br />" ..
	"服务端端口、Token、<code>additionalScopes</code>、TLS 须与 frps 一致，否则连接会被拒绝。")

-- ==================== 服务器与认证 ====================
s = m:section(NamedSection, "common", "common", "服务器与认证")
s.addremove = false
s.anonymous = false

o = s:option(Flag, "enabled", "启用 frpc", "关闭后服务将完全停止")
o.default = "1"
o.rmempty = false

o = s:option(Value, "server_addr", "服务端地址", "frps 所在服务器的 IP 或域名，如 frp.bigfeng.top")
o.placeholder = "frp.example.com"
o.rmempty = false

o = s:option(Value, "server_port", "服务端端口", "对应 frps 的 bindPort")
o.datatype = "port"
o.default = "26566"
o.rmempty = false

o = s:option(ListValue, "auth_method", "认证方式", "需与 frps 的 auth.method 一致")
o:value("token", "token")
o.default = "token"
o.rmempty = false

o = s:option(Value, "auth_token", "认证 Token", "必须与 frps 的 auth.token 一致")
o.password = true

o = s:option(Value, "auth_additional_scopes", "附加鉴权范围",
	"与 frps 的 auth.additionalScopes 一致，多个用逗号分隔")
o.default = "HeartBeats,NewWorkConns"
o.placeholder = "HeartBeats,NewWorkConns"

o = s:option(Value, "user", "用户标识", "可选，用于在同一服务端区分不同客户端")

o = s:option(Value, "allowed_ports", "远端端口白名单",
	"对应 frps 的 allowPorts；remotePort 不在表内将被跳过。留空则不校验")
o.placeholder = "26566,46774,43545,64557,45768,58646,6000,7547"

-- ==================== 传输层 ====================
s = m:section(NamedSection, "common", "common", "传输层")
s.addremove = false
s.anonymous = false

o = s:option(Value, "connect_server_local_ip", "本地出口 IP", "transport.connectServerLocalIP")
o.default = "0.0.0.0"
o.datatype = "ip4addr"

o = s:option(ListValue, "protocol", "底层协议", "KCP / QUIC 需服务端开启对应端口")
o:value("tcp", "TCP（默认）")
o:value("kcp", "KCP")
o:value("quic", "QUIC")
o.default = "tcp"

o = s:option(Value, "dial_server_timeout", "连接超时(秒)", "transport.dialServerTimeout")
o.default = "10"
o.datatype = "uinteger"

o = s:option(Value, "dial_server_keepalive", "连接保活(秒)", "transport.dialServerKeepalive")
o.default = "7200"
o.datatype = "uinteger"

o = s:option(Value, "pool_count", "连接池大小", "transport.poolCount，不超过 frps 的 maxPoolCount")
o.default = "10"
o.datatype = "uinteger"

o = s:option(Value, "heartbeat_interval", "心跳间隔(秒)", "transport.heartbeatInterval")
o.default = "30"
o.datatype = "uinteger"

o = s:option(Value, "heartbeat_timeout", "心跳超时(秒)", "transport.heartbeatTimeout，须与 frps 一致")
o.default = "90"
o.datatype = "uinteger"

o = s:option(Flag, "tcp_mux", "启用 TCP 多路复用", "transport.tcpMux，须与 frps 一致")
o.default = "1"

o = s:option(Value, "tcp_mux_keepalive_interval", "多路复用保活(秒)", "transport.tcpMuxKeepaliveInterval")
o.default = "60"
o.datatype = "uinteger"

o = s:option(Flag, "tls_enable", "启用 TLS", "transport.tls.enable；frps 设置 tls.force=true 时必须开启")
o.default = "1"

o = s:option(Flag, "use_encryption", "全局加密", "对所有隧道启用 transport.useEncryption")
o.default = "0"

o = s:option(Flag, "use_compression", "全局压缩", "对所有隧道启用 transport.useCompression")
o.default = "0"

o = s:option(Value, "udp_packet_size", "UDP 包大小", "udpPacketSize，须与 frps 一致")
o.default = "1500"
o.datatype = "uinteger"

-- ==================== 日志 ====================
s = m:section(NamedSection, "common", "common", "日志")
s.addremove = false
s.anonymous = false

o = s:option(ListValue, "log_to", "输出目标", "console 由 procd/logread 接管；不要写 file 以免损耗 flash")
o:value("console", "console（推荐）")
o:value("file", "file")
o.default = "console"

o = s:option(ListValue, "log_level", "日志级别")
o:value("trace", "trace")
o:value("debug", "debug")
o:value("info", "info")
o:value("warn", "warn")
o:value("error", "error")
o.default = "info"

o = s:option(Value, "log_max_days", "保留天数", "log.maxDays，仅 file 模式有效")
o.default = "7"
o.datatype = "uinteger"

o = s:option(Flag, "log_disable_print_color", "禁用颜色", "log.disablePrintColor")
o.default = "1"

-- ==================== 状态存储 ====================
s = m:section(NamedSection, "common", "common", "状态存储")
s.addremove = false
s.anonymous = false

o = s:option(Flag, "store_enable", "启用状态存储", "仅 NAT 打洞（stcp/xtcp）场景需要；普通 tcp 隧道可关闭")
o.default = "0"

o = s:option(Value, "store_path", "存储路径", "[store] path；使用 /var 下的 tmpfs，重启自动清空不写 flash")
o.default = "/var/etc/frpc/frpc_store.json"
o:depends("store_enable", "1")

-- ==================== 客户端面板 ====================
s = m:section(NamedSection, "common", "common", "客户端面板")
s.addremove = false
s.anonymous = false

o = s:option(Flag, "web_enable", "启用客户端面板", "开启 frpc 自带 webServer；默认关闭以减少路由器攻击面")
o.default = "0"

o = s:option(Value, "web_addr", "面板监听地址", "建议仅本地回环 127.0.0.1，避免对公网暴露")
o.default = "0.0.0.0"
o:depends("web_enable", "1")

o = s:option(Value, "web_port", "面板端口")
o.datatype = "port"
o.default = "7400"
o:depends("web_enable", "1")

o = s:option(Value, "web_user", "面板用户名")
o:depends("web_enable", "1")

o = s:option(Value, "web_password", "面板密码")
o.password = true
o:depends("web_enable", "1")

o = s:option(Flag, "web_pprof_enable", "启用 pprof", "webServer.pprofEnable，调试用，生产建议关闭")
o.default = "0"
o:depends("web_enable", "1")

-- ==================== 隧道规则（proxies） ====================
s = m:section(TypedSection, "proxy", "隧道规则",
	"每条规则生成一个 <code>[[proxies]]</code>；点击「添加」可新建多条。")
s.template = "cbi/tblsection"
s.anonymous = false
s.addremove = true
s.sortable = true

o = s:option(Flag, "enabled", "启用")
o.default = "1"
o.rmempty = false
o.width = "6%"

o = s:option(Value, "name", "名称")
o.placeholder = "ssh"
o.rmempty = false

o = s:option(ListValue, "type", "类型")
o:value("tcp", "TCP")
o:value("udp", "UDP")
o:value("http", "HTTP")
o:value("https", "HTTPS")
o:value("stcp", "STCP")
o:value("xtcp", "XTCP")
o.default = "tcp"
o.rmempty = false

o = s:option(Value, "local_ip", "本地 IP")
o.default = "127.0.0.1"
o:depends("type", "tcp")
o:depends("type", "udp")
o:depends("type", "http")
o:depends("type", "https")

o = s:option(Value, "local_port", "本地端口")
o.datatype = "port"
o.rmempty = false
o:depends("type", "tcp")
o:depends("type", "udp")
o:depends("type", "http")
o:depends("type", "https")

o = s:option(Value, "remote_port", "远端端口", "须在上方「远端端口白名单」内，否则会被跳过")
o.datatype = "port"
o:depends("type", "tcp")
o:depends("type", "udp")

o = s:option(Value, "custom_domains", "自定义域名", "HTTP / HTTPS 使用，多个用逗号分隔")
o:depends("type", "http")
o:depends("type", "https")

o = s:option(Value, "domain", "主域名", "HTTP / HTTPS 可选")
o:depends("type", "http")
o:depends("type", "https")

o = s:option(Value, "subdomain", "子域名", "HTTP / HTTPS 可选")
o:depends("type", "http")
o:depends("type", "https")

o = s:option(ListValue, "role", "角色", "stcp/xtcp：本客户端作被访问端时选 server")
o:value("server", "server（被访问端）")
o:value("visitor", "visitor（访问端，见下方访问端配置）")
o.default = "server"
o:depends("type", "stcp")
o:depends("type", "xtcp")

o = s:option(Value, "secret_key", "密钥", "stcp/xtcp 的 secretKey，两端必须一致")
o.password = true
o:depends("type", "stcp")
o:depends("type", "xtcp")

o = s:option(Value, "allow_users", "允许的访问者", "可选，多个用户用逗号分隔，对应 allowUsers")
o:depends("type", "stcp")
o:depends("type", "xtcp")

o = s:option(Flag, "use_encryption", "加密", "单独为该隧道开启")
o.default = "0"

o = s:option(Flag, "use_compression", "压缩", "单独为该隧道开启")
o.default = "0"

-- ==================== 访问端（visitors） ====================
s = m:section(TypedSection, "visitor", "访问端配置 (visitors)",
	"stcp/xtcp 的访问端单独生成 <code>[[visitors]]</code>；serverName 填对端 proxy 的名称。")
s.template = "cbi/tblsection"
s.anonymous = false
s.addremove = true
s.sortable = true

o = s:option(Flag, "enabled", "启用")
o.default = "1"
o.rmempty = false
o.width = "6%"

o = s:option(Value, "name", "名称", "本访问端的唯一名称")
o.rmempty = false

o = s:option(ListValue, "type", "类型")
o:value("stcp", "STCP")
o:value("xtcp", "XTCP")
o.default = "stcp"
o.rmempty = false

o = s:option(Value, "server_name", "对端名称", "serverName：对端 proxy 的 name")
o.rmempty = false

o = s:option(Value, "secret_key", "密钥", "secretKey：须与对端 proxy 一致")
o.password = true

o = s:option(Value, "bind_addr", "本地监听地址", "bindAddr")
o.default = "127.0.0.1"

o = s:option(Value, "bind_port", "本地监听端口", "bindPort")
o.datatype = "port"

return m
