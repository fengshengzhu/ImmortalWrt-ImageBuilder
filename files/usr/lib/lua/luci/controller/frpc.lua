module("luci.controller.frpc", package.seeall)

local CONFIG = "frpc"

function index()
	-- 不因配置文件缺失而隐藏菜单，便于首次进入页面时排查问题
	local e = entry({"admin", "services", "frpc"}, firstchild(), _("FRP 内网穿透"), 60)
	e.dependent = false

	entry({"admin", "services", "frpc", "settings"}, cbi("frpc"), _("参数设置"), 1)
	entry({"admin", "services", "frpc", "status"}, template("frpc/status"), _("运行状态"), 2).leaf = true

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

	local enabled_proxies = 0
	uci:foreach(CONFIG, "proxy", function(s)
		if s.enabled == "1" then
			enabled_proxies = enabled_proxies + 1
		end
	end)
	data.proxies = enabled_proxies

	local enabled_visitors = 0
	uci:foreach(CONFIG, "visitor", function(s)
		if s.enabled == "1" then
			enabled_visitors = enabled_visitors + 1
		end
	end)
	data.visitors = enabled_visitors

	local f = io.open("/var/etc/frpc/frpc.toml", "r")
	data.config = ""
	if f then
		data.config = f:read("*a") or ""
		f:close()
	end

	data.log = sys.exec("logread 2>/dev/null | grep -i frpc | tail -n 30") or ""

	luci.http.prepare_content("application/json")
	luci.http.write_json(data)
end

function action_control()
	local cmd = luci.http.formvalue("cmd")
	local ok, msg = false, _("未知操作")

	if cmd == "start" or cmd == "stop" or cmd == "restart" then
		ok = (luci.sys.call("/etc/init.d/frpc " .. cmd .. " >/dev/null 2>&1") == 0)
		if ok then
			msg = _("操作成功")
		else
			msg = _("操作失败，请查看系统日志")
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({ ok = ok, msg = msg })
end
