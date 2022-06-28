local event = require("event")

twins = {}
twins.container = require("component").gpu

twins.scw, twins.sch = twins.container.getResolution()

twins.document = {}
twins.elements = {}
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
	if twins.container.type == "tornado_vs" then
		twins.draw_frame({x=1, y=1, w=twins.container.internal.width, h=twins.container.internal.height})
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
			twins.elements[i].visible = twins.elements[i].visible or true
			invoke(twins.elements[i], "oncreate")
			return twins.elements[i]
		end
	end
end

function twins.load_elements(module_name, load_as)
	local mod, err = require(module_name)
	twins[load_as] = {}
	for elem_name, elem_content in pairs(mod) do
		twins[load_as][elem_name] = 
		function(t)
			t = t or {}
			for k, v in pairs(elem_content) do
				if not t[k] then t[k] = v end
			end
			return twins.add_element(t)
		end
	end
end

function twins.get_element_by_key(key)
	for k, v in pairs(twins.elements) do
		if v.key == key then
			return v
		end
	end
end

function twins.draw_frame(elem)
	twins.container.set(elem.x, elem.y, "┌")
	twins.container.set(elem.x+elem.w-1, elem.y, "┐")
	twins.container.set(elem.x, elem.y+elem.h-1, "└")
	twins.container.set(elem.x+elem.w-1, elem.y+elem.h-1, "┘")

	twins.container.fill(elem.x, elem.y+1, 1, elem.h-2, "│")
	twins.container.fill(elem.x+elem.w-1, elem.y+1, 1, elem.h-2, "│")
	twins.container.fill(elem.x+1, elem.y, elem.w-2, 1, "─")
	twins.container.fill(elem.x+1, elem.y+elem.h-1, elem.w-2, 1, "─")
end

local function touch_listener(e_name, addr, x, y, button)
	local offx, offy = 0, 0
	if twins.container.type == "tornado_vs" then
		offx = twins.container.internal.x
		offy = twins.container.internal.y
	end
	for k, v in pairs(twins.elements) do
		local ex, ey, ew, eh = v.getxywh(v)
		if x-offx >= ex and x-offx < ex + ew and y-offy >= ey and y-offy < ey + eh then
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
	twins.container.setForeground(twins.document.fgcolor or 0xffffff)
	twins.container.setBackground(color or twins.document.bgcolor or 0x000000)
	twins.container.fill(1, 1, twins.scw, twins.sch, " ")
end

twins.load_elements("twins.base.elem_base", "base")

function twins.clear_elements()
	twins.elements = {}
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


function twins.main()
	twins.connect_listeners()
	local succ = xpcall(function()
		twins.clear_screen()
		while true do
			twins.render()
			os.sleep(60)
		end
	end, function(...) err = debug.traceback(...) end)
	twins.disconnect_listeners()
	shutdown_sequence()
	if not succ then error(err) end
end

function twins.main_coroutine()
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
	if not succ then error(err) end
end

return twins
