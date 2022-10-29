local event = require("event")
local computer = require("computer")

twins = {}
twins.container = require("component").gpu

twins.scw, twins.sch = twins.container.getResolution()

twins.document = {}
twins.elements = {}
twins.named_elements = {}
twins.focus = -1

twins.storage = {}
twins.sps = require("twins.base.sps")

function twins.wake()
	twins.scw, twins.sch = twins.container.getResolution()
end

local function invoke(element, method, ...)
	if type(element[method]) == "function" then
		element[method](element, ...)
	end
end

function twins.get_focus()
	return twins.elements[twins.focus]
end

function twins.render(force)
	for k, v in pairs(twins.elements) do
		if rawget(v, "changed") or force then
			invoke(v, "render")
			rawset(v, "changed", false)
		end
	end
	if twins.document.title then twins.title(twins.document.title) end
end


function twins.add_element(element)
	for i=1, #twins.elements+1 do
		if twins.elements[i] == nil then
			element = setmetatable({
				internal=element,
				render=element.render,
				getxywh = function(t)
					return rawget(t.internal, "x"), rawget(t.internal, "y"), 
					rawget(t.internal, "w"), rawget(t.internal, "h")
				end
			}, {
				__index = function(t, i)
					rawset(t, "changed", true)
					return rawget(t.internal, i)
				end,
				__newindex = function(t, i, v)
					rawset(t, "changed", true)
					rawset(t.internal, i, v)
				end,
				__pairs = function(t) return pairs(rawget(t, "internal")) end,
				__ipairs = function(t) return ipairs(rawget(t, "internal")) end
			})
			twins.elements[i] = element
			twins.elements[i]._id = i
			if twins.elements[i].clickable == nil then twins.elements[i].clickable = true end
			if twins.elements[i].visible == nil then twins.elements[i].visible = true end
			invoke(twins.elements[i], "oncreate")
			return twins.elements[i]
		end
	end
end

local function deep_copy(t)
	if type(t) ~= "table" then
		return t
	end

	local new_t = {}
	for k, v in pairs(t) do
		new_t[k] = deep_copy(v)
	end
	return new_t
end


function twins.load_elements(module_name, load_as, load_only)
	local succ, mod
	if not load_only then
		succ, mod = pcall(require, module_name)
		local err
		if not succ then
			succ, mod = pcall(function()
				local code, err = loadfile(module_name)
				assert(code, err)
				return code()
			end)
		end
	else
		succ, mod = pcall(function()
			local code, err = loadfile(module_name)
			assert(code, err)
			return code()
		end)
	end

	if not mod then error("Файл не может быть найден.") end
	if type(mod) == "string" then
		error(mod)
	end
	twins[load_as] = {}
	for elem_name, elem_content in pairs(mod) do
		if elem_content.render then
			local _render = elem_content.render
			local function wrapped_render(self)
				if twins.running then
					_render(self)
				end
			end
		end
		twins[load_as][elem_name] = 
		function(t)
			t = t or {}
			for k, v in pairs(elem_content) do
				if not t[k] then t[k] = deep_copy(v) end
			end
			local prepared_element = twins.add_element(t)
			if t.key ~= nil then
				assert(
					twins.named_elements[prepared_element.key] == nil, 
					"Ошибка при создании элемента с ключом: \""..prepared_element.key .. "\" уже существует"
				)
				twins.named_elements[prepared_element.key] = prepared_element
			end
			prepared_element.render = wrapped_render
			return prepared_element
		end
	end
end

function twins.get_element_by_key(key)
	return twins.named_elements[key]
end

function twins.draw_frame(elem)
	local vl = ("│"):rep(elem.h-2)
	local hl = ("─"):rep(elem.w-2)

	twins.container.set(elem.x, elem.y, "┌"..vl.."└", true)
	twins.container.set(elem.x+elem.w-1, elem.y, "┐"..vl.."┘", true)
	twins.container.set(elem.x+1, elem.y, hl)
	twins.container.set(elem.x+1, elem.y+elem.h-1, hl)
end

local function touch_listener(e_name, addr, x, y, button)
	local offx, offy = 0, 0
	if twins.container.type == "tornado_vs" then
		offx = twins.container.internal.x
		offy = twins.container.internal.y
	end
	for k, v in pairs(twins.elements) do
		local ex, ey, ew, eh = v.getxywh(v)
		if x-offx >= ex and x-offx < ex + ew and y-offy >= ey and y-offy < ey + eh and v.clickable then
			if v.visible and twins.focus ~= k then
				local foc_elem = twins.get_focus()
				if foc_elem then
					invoke(foc_elem, "onfocus", x-v.x, y-v.y)
				end

				twins.focus = k
				invoke(twins.get_focus(), "onfocusloss")
			end
			invoke(v, "onclick", {x=x, y=y}, {x=x-v.x, y=y-v.y}, button)
		end
	end
end

local function key_down_listener(e_name, addr, letter, key)
	local focus = twins.get_focus()
	invoke(twins.document, "onkeydown", letter, key)
	if focus then
		if focus.visible then
			invoke(focus, "onkeydown", letter, key)
		end
	end
end

local function scroll_listener(e_name, addr, x, y, size)
	local offx, offy = 0, 0
	if twins.container.type == "tornado_vs" then
		offx = twins.container.internal.x
		offy = twins.container.internal.y
	end
	for k, v in pairs(twins.elements) do
		local ex, ey, ew, eh = v.getxywh(v)
		if x-offx >= ex and x-offx < ex + ew and y-offy >= ey and y-offy < ey + eh then
			invoke(v, "onscroll", {x=x, y=y}, {x=x-v.x, y=y-v.y}, size)
		end
	end
end


function twins.clear_screen(color)
	print(twins.scw, twins.sch)
	twins.container.setForeground(twins.document.fgcolor or 0xffffff)
	twins.container.setBackground(color or twins.document.bgcolor or 0x000000)
	twins.container.fill(1, 1, twins.scw, twins.sch, " ")
end

twins.load_elements("/lib/twins/base/elem_base.lua", "base", true)

function twins.clear_elements()
	twins.elements = {}
	twins.named_elements = {}
end

function twins.use_macros(container)
	if type(container) ~= "table" then
		container = _G
	end

	function container.group(props)
		return function(items)
			props.items = items
			return twins.base.group(props)
		end
	end

	container.button = twins.base.button
	container.text = twins.base.text
	container.input = twins.base.input
end

function twins.title(title)
	twins.container.set(3, 1, "["..title.."]")
end

local function shutdown_sequence()
	for k, v in pairs(twins.elements) do
		invoke(v, "ondestroy")
		twins.elements[k] = nil
	end
end

local kdid, t_id, scr_id

function twins.connect_listeners()
	kdid = event.listen("key_down", key_down_listener)
	t_id = event.listen("touch", touch_listener)
	scr_id = event.listen("scroll", scroll_listener)
end

function twins.disconnect_listeners()
	event.cancel(kdid)
	event.cancel(t_id)
	event.cancel(scr_id)
end

function twins.euthanize()
	twins.running = false
	computer.pushSignal("twins_term", 1)
end

function twins.sleep(timeout)
	local deadline = computer.uptime() + (timeout or 0)
	repeat
		local sig = event.pull(deadline - computer.uptime())
	until computer.uptime() >= deadline or sig == "twins_term"
end

function twins.main()
	local init_bg = twins.container.getBackground()
	local init_fg = twins.container.getForeground()
	twins.running = true
	twins.connect_listeners()
	local succ = xpcall(function()
		twins.clear_screen()
		twins.render()
		while twins.running do
			for k, v in ipairs(twins.elements) do
				twins.sleep(10)
				v:render()
				if not twins.running then break end
			end
			twins.sleep(1)
		end
	end, function(...) err = debug.traceback(...) end)
	twins.disconnect_listeners()
	shutdown_sequence()
	twins.container.setForeground(init_fg)
	twins.container.setBackground(init_bg)
	twins.clear_elements()
	if not succ then error(err, 3) end
end

function twins.main_coroutine()
	local init_bg = twins.container.getBackground()
	local init_fg = twins.container.getForeground()
	twins.running = true
	twins.connect_listeners()
	local succ, err = xpcall(function()
		twins.clear_screen()
		while twins.running do
			twins.render()
			coroutine.yield()
		end
	end, function(...) err = debug.traceback(...) end)
	twins.disconnect_listeners()
	twins.clear_screen(twins.document.destroy_color)
	shutdown_sequence()
	twins.container.setForeground(init_fg)
	twins.container.setBackground(init_bg)
	twins.clear_elements()
	if not succ then error(err, 3) end
end

return twins
