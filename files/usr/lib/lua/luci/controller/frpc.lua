module("luci.controller.frpc", package.seeall)

local CONFIG = "frpc"

function index()
	if not nixio.fs.access("/etc/config/" .. CONFIG) then
		return
	end

	local e = entry({"admin", "services", "frpc"}, firstchild(), _("FRP 内网穿透"), 60)
	e.dependent = false

	-- 7 个配置分页：LuCI 主题据此在页面顶部原生渲染标签栏（与系统其它页面一致）。
	-- 每个入口指向同一个 CBI model，model 内部按 URL 末段只渲染对应区块。
	entry({"admin", "services", "frpc", "settings"},  cbi("frpc"), _("服务器与认证"), 1)
	entry({"admin", "services", "frpc", "transport"}, cbi("frpc"), _("传输层"), 2)
	entry({"admin", "services", "frpc", "log"},       cbi("frpc"), _("日志"), 3)
	entry({"admin", "services", "frpc", "web"},       cbi("frpc"), _("客户端面板"), 4)
	entry({"admin", "services", "frpc", "store"},     cbi("frpc"), _("状态存储"), 5)
	entry({"admin", "services", "frpc", "proxies"},   cbi("frpc"), _("隧道规则"), 6)
	entry({"admin", "services", "frpc", "visitors"},  cbi("frpc"), _("访问端配置"), 7)
	entry({"admin", "services", "frpc", "status"}, template("frpc/status"), _("运行状态"), 8).leaf = true

	entry({"admin", "services", "frpc", "status_json"}, call("action_status_json")).leaf = true
	entry({"admin", "services", "frpc", "control"}, call("action_control")).leaf = true
end

function action_status_json()
	local sys  = require "luci.sys"
	local uci  = require "luci.model.uci".cursor()
	local data = {}

	data.running  = (sys.call("pidof frpc >/dev/null 2>&1") == 0)
	data.enabled  = uci:get(CONFIG, "common", "enabled") or "0"
	local addr    = uci:get(CONFIG, "common", "server_addr") or ""
	local port    = uci:get(CONFIG, "common", "server_port") or ""
	data.server   = (addr ~= "" and port ~= "") and (addr .. ":" .. port) or addr
	data.tls      = uci:get(CONFIG, "common", "tls_enable") or "0"
	data.scopes   = uci:get(CONFIG, "common", "auth_additional_scopes") or ""

	-- 实际生成的 TOML 才能反映真实生效条数：remotePort 不在白名单的隧道
	-- 会在生成阶段被跳过，直接数 UCI 会虚高，误导排查。
	local f = io.open("/var/etc/frpc/frpc.toml", "r")
	local raw_config = ""
	if f then
		raw_config = f:read("*a") or ""
		f:close()
	end

	local function count_sections(text, pattern)
		local n = 0
		for _ in text:gmatch(pattern) do n = n + 1 end
		return n
	end
	data.proxies  = count_sections(raw_config, "%[%[proxies%]%]")
	data.visitors = count_sections(raw_config, "%[%[visitors%]%]")

	local uci_proxies = 0
	uci:foreach(CONFIG, "proxy", function(s)
		if s.enabled == "1" then uci_proxies = uci_proxies + 1 end
	end)
	data.uci_proxies = uci_proxies

	data.log = sys.exec("logread 2>/dev/null | grep -i frpc | tail -n 30") or ""

	-- pidof 只能说明进程活着；token/TLS 不匹配时进程仍在，需把连接错误显式暴露
	data.conn_errors = {}
	for line in (data.log .. "\n"):gmatch("([^\n]+)\n") do
		local lc = line:lower()
		if lc:find("authentication failed", 1, true)
			or lc:find("login to server failed", 1, true)
			or lc:find("connection refused", 1, true)
			or (lc:find("token", 1, true) and lc:find("mismatch", 1, true))
			or lc:find("tls handshake", 1, true) then
			data.conn_errors[#data.conn_errors + 1] = line
		end
	end

	-- 展示用 TOML 必须对密钥脱敏，页面只读也不该明文摊开 auth.token / web password
	data.config = raw_config
	data.config = data.config:gsub("(auth%.token%s*=%s*\")[^\"]*(\")", "%1******%2")
	data.config = data.config:gsub("(webServer%.password%s*=%s*\")[^\"]*(\")", "%1******%2")
	data.config = data.config:gsub("(secretKey%s*=%s*\")[^\"]*(\")", "%1******%2")

	luci.http.prepare_content("application/json")
	luci.http.write_json(data)
end

function action_control()
	-- 每个 CGI 请求是独立进程，必须自行 require；只依赖 status_json 里
	-- 的 require 会在此处得到 nil（luci.sys is nil），接口返回 500，前端“没反应”。
	local sys = require "luci.sys"
	local cmd = luci.http.formvalue("cmd")
	local ok, msg, rc = false, _("未知操作"), nil

	if cmd == "start" or cmd == "stop" or cmd == "restart" then
		rc = sys.call("/etc/init.d/frpc " .. cmd .. " >/dev/null 2>&1")
		-- Lua 5.1 的 os.execute 返回退出码(0=成功)，部分实现返回布尔 true
		ok = (rc == 0 or rc == true)
		if ok then
			msg = _("操作成功")
		else
			msg = _("操作失败，请查看系统日志") .. " (rc=" .. tostring(rc) .. ")"
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({ ok = ok, msg = msg, cmd = cmd, rc = rc })
end
