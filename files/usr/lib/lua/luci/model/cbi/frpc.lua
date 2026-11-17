local m, s, o

m = Map("frpc", "FRP 内网穿透 - 参数设置",
	"配置 frpc 客户端；保存后会自动应用到运行中的服务。<br />" ..
	"服务端请使用 frp 0.72.x，并保证下方 Token 与 frps 的 <code>auth.token</code> 一致。")

-- ==================== 通用设置 ====================
s = m:section(NamedSection, "common", "common", "服务器与通用设置")
s.addremove = false
s.anonymous = false

o = s:option(Flag, "enabled", "启用 frpc", "关闭后服务将完全停止")
o.default = "1"
o.rmempty = false

o = s:option(Value, "server_addr", "服务端地址", "frps 所在服务器的 IP 或域名")
o.placeholder = "例如 1.2.3.4 或 frp.example.com"
o.rmempty = false

o = s:option(Value, "server_port", "服务端端口", "对应 frps 的 bindPort")
o.datatype = "port"
o.default = "7000"
o.rmempty = false

o = s:option(ListValue, "protocol", "底层协议", "KCP / QUIC 需服务端开启对应端口")
o:value("tcp", "TCP（默认）")
o:value("kcp", "KCP")
o:value("quic", "QUIC")
o.default = "tcp"

o = s:option(Value, "auth_token", "认证 Token", "必须与 frps 的 auth.token 一致")
o.password = true

o = s:option(Value, "user", "用户标识", "可选，用于在同一服务端区分不同客户端")

o = s:option(ListValue, "log_level", "日志级别")
o:value("trace", "trace")
o:value("debug", "debug")
o:value("info", "info")
o:value("warn", "warn")
o:value("error", "error")
o.default = "info"

o = s:option(Flag, "tls_enable", "启用 TLS", "0.50 起默认开启，一般保持开启")
o.default = "1"

o = s:option(Flag, "use_encryption", "全局加密", "对所有隧道启用 transport.useEncryption")
o.default = "0"

o = s:option(Flag, "use_compression", "全局压缩", "对所有隧道启用 transport.useCompression")
o.default = "0"

o = s:option(Flag, "web_enable", "启用客户端面板", "开启 frpc 自带 webServer 管理面板")
o.default = "0"

o = s:option(Value, "web_addr", "面板监听地址")
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

-- ==================== 隧道规则 ====================
s = m:section(TypedSection, "proxy", "隧道规则",
	"每条规则生成一个 <code>[[proxies]]</code>；点击「添加」可新建多条。")
s.template = "cbi/tblsection"
s.anonymous = false
s.addremove = true
s.sortable = true

o = s:option(Flag, "enabled", "启用")
o.default = "1"
o.rmempty = false
o.width = "7%"

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
o.rmempty = false

o = s:option(Value, "local_port", "本地端口")
o.datatype = "port"
o.rmempty = false

o = s:option(Value, "remote_port", "远端端口", "TCP / UDP 类型使用")
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

o = s:option(Flag, "use_encryption", "加密", "单独为该隧道开启")
o.default = "0"

o = s:option(Flag, "use_compression", "压缩", "单独为该隧道开启")
o.default = "0"

return m
