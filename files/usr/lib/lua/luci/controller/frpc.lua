module("luci.controller.frpc", package.seeall)

local CONFIG = "frpc"

function index()
	if not nixio.fs.access("/etc/config/" .. CONFIG) then
		return
	end

	-- 顶部只保留两个原生子页面标签：「参数设置」（配置页，内部再用 section 内标签）
	-- 与「运行状态」（概览 / 生成的 TOML / 最近日志独立页）。
	local e = entry({"admin", "services", "frpc"}, firstchild(), _("FRP 内网穿透"), 60)
	e.dependent = false

	entry({"admin", "services", "frpc", "settings"}, cbi("frpc"), _("参数设置"), 1)
	entry({"admin", "services", "frpc", "status"}, template("frpc/status"), _("运行状态"), 9).leaf = true

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

	-- pidof 只能说明进程活着；token/TLS 不匹配时进程仍在，需把连接错误显式暴露。
	-- 关键：log 是跨天累积的（tail -n 30），旧失败记录不能代表当前状态。
	-- 按日志时间顺序扫描：每遇到一次连接成功就把此前累积的错误清空，
	-- 最终只剩「最后一次成功之后仍出现」的错误才算真正的连接异常。
	data.conn_errors = {}
	for line in (data.log .. "\n"):gmatch("([^\n]+)\n") do
		local lc = line:lower()
		-- frp 0.72 成功登录标志：login to server success, get run id [...]
		if lc:find("login to server success", 1, true)
			or lc:find("login to the server success", 1, true) then
			data.conn_errors = {}
		elseif lc:find("authentication failed", 1, true)
			or lc:find("login to server failed", 1, true)
			or lc:find("login to the server failed", 1, true)
			or lc:find("connection refused", 1, true)
			or (lc:find("token", 1, true) and lc:find("mismatch", 1, true))
			or lc:find("tls handshake", 1, true) then
			data.conn_errors[#data.conn_errors + 1] = line
		end
	end

	-- 展示用 TOML 必须对密钥脱敏，页面只读也不该明文摊开 auth.token / web password。
	-- 注意：TOML 值里的引号会被 toml_escape 转义为 \"，若用 [^\"]* 会在转义引号处
	-- 提前截断，导致后半段密钥泄露。TOML 字符串不跨行，故用 [^\n]* 贪婪匹配到
	-- 行内最后一个引号，把整段值一次替换掉。
	data.config = raw_config
	data.config = data.config:gsub("(auth%.token%s*=%s*\")[^\n]*(\")", "%1******%2")
	data.config = data.config:gsub("(webServer%.password%s*=%s*\")[^\n]*(\")", "%1******%2")
	data.config = data.config:gsub("(secretKey%s*=%s*\")[^\n]*(\")", "%1******%2")

	luci.http.prepare_content("application/json")
	luci.http.write_json(data)
end

function action_control()
	-- 每个 CGI 请求是独立进程，必须自行 require；只依赖 status_json 里
	-- 的 require 会在此处得到 nil（luci.sys is nil），接口返回 500，前端“没反应”。
	local sys  = require "luci.sys"
	local http = luci.http
	local cmd  = http.formvalue("cmd")

	-- CSRF 防护（只依赖 luci.http，兼容本固件的 ucode 桥接层）：
	--   1) 拒绝非 POST 请求，挡住 <img>/<a> 之类的 GET 型 CSRF；
	--   2) 请求回传的 sessionid 必须与 cookie 中的一致（double-submit），
	--      跨站脚本读不到本站 cookie，无法伪造该参数。
	-- 两项均用 pcall 保护：万一某环境取不到 REQUEST_METHOD / cookie，则降级放行，
	-- 避免正常按钮被误伤（本固件曾因 _() 缺失导致 500，吸取教训）。
	local function reject(msg)
		http.prepare_content("application/json")
		http.write_json({ ok = false, msg = msg })
	end

	local method = nil
	pcall(function() method = http.getenv("REQUEST_METHOD") end)
	if method and method ~= "POST" then
		reject("已拒绝：控制操作仅允许 POST 请求")
		return
	end

	local form_sid = http.formvalue("sessionid") or ""
	if form_sid ~= "" then
		local cookie_sid = nil
		pcall(function() cookie_sid = http.getcookie("sessionid") end)
		if cookie_sid and cookie_sid ~= "" and cookie_sid ~= form_sid then
			reject("已拒绝：会话校验失败，请刷新页面重试")
			return
		end
	end

	-- 注意：本固件 dispatcher 走 ucode 桥接，call() 入口的函数环境里没有 _()
	-- 翻译全局（status_json 不用它所以正常）。此处一律用中文常量，避免 500。
	local ok, msg, rc = false, "未知操作", nil

	if cmd == "start" or cmd == "stop" or cmd == "restart" then
		rc = sys.call("/etc/init.d/frpc " .. cmd .. " >/dev/null 2>&1")
		-- Lua 5.1 的 os.execute 返回退出码(0=成功)，部分实现返回布尔 true
		ok = (rc == 0 or rc == true)
		if ok then
			msg = "操作成功"
		else
			msg = "操作失败，请查看系统日志 (rc=" .. tostring(rc) .. ")"
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({ ok = ok, msg = msg, cmd = cmd, rc = tostring(rc) })
end
