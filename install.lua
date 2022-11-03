local fs = require("filesystem")
local pkg = { ["/lib/twins/init.lua"]="local event = require(\"event\")
local computer = require(\"computer\")

twins = {}
twins.container = require(\"component\").gpu

twins.scw, twins.sch = twins.container.getResolution()

twins.document = {}
twins.elements = {}
twins.named_elements = {}
twins.focus = -1

twins.storage = {}
twins.sps = require(\"twins.core.sps\")

function twins.wake()
	twins.scw, twins.sch = twins.container.getResolution()
end

local function invoke(element, method, ...)
	if type(element[method]) == \"function\" then
		element[method](element, ...)
	end
end

function twins.get_focus()
	return twins.elements[twins.focus]
end

function twins.render(force)
	for k, v in pairs(twins.elements) do
		if rawget(v, \"changed\") or force then
			invoke(v, \"render\")
			rawset(v, \"changed\", false)
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
					return rawget(t.internal, \"x\"), rawget(t.internal, \"y\"), 
					rawget(t.internal, \"w\"), rawget(t.internal, \"h\")
				end
			}, {
				__index = function(t, i)
					rawset(t, \"changed\", true)
					return rawget(t.internal, i)
				end,
				__newindex = function(t, i, v)
					rawset(t, \"changed\", true)
					rawset(t.internal, i, v)
				end,
				__pairs = function(t) return pairs(rawget(t, \"internal\")) end,
				__ipairs = function(t) return ipairs(rawget(t, \"internal\")) end
			})
			twins.elements[i] = element
			twins.elements[i]._id = i
			if twins.elements[i].clickable == nil then twins.elements[i].clickable = true end
			if twins.elements[i].visible == nil then twins.elements[i].visible = true end
			invoke(twins.elements[i], \"oncreate\")
			return twins.elements[i]
		end
	end
end

local function deep_copy(t)
	if type(t) ~= \"table\" then
		return t
	end

	local new_t = {}
	for k, v in pairs(t) do
		new_t[k] = deep_copy(v)
	end
	return new_t
end

local function load_from_file(module_name)
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

	if not mod then error(\"Файл не может быть найден.\") end
	if type(mod) == \"string\" then
		error(mod)
	end
	return mod
end


function twins.load_elements(module_name, load_as, load_only)
	local mod
	local mod_type = type(module_name)
	if mod_type == \"string\" then
		mod = load_from_file(module_name)
	elseif mod_type == \"table\" then
		mod = module_name
	else
		error(\"Аргумент типа \" .. mod_type .. \" не поддерживается\")
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
					\"Ошибка при создании элемента с ключом: \\\"\"..prepared_element.key .. \"\\\" уже существует\"
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
	local vl = (\"│\"):rep(elem.h-2)
	local hl = (\"─\"):rep(elem.w-2)

	twins.container.set(elem.x, elem.y, \"┌\"..vl..\"└\", true)
	twins.container.set(elem.x+elem.w-1, elem.y, \"┐\"..vl..\"┘\", true)
	twins.container.set(elem.x+1, elem.y, hl)
	twins.container.set(elem.x+1, elem.y+elem.h-1, hl)
end

local function touch_listener(e_name, addr, x, y, button)
	local offx, offy = 0, 0
	if twins.container.type == \"tornado_vs\" then
		offx = twins.container.internal.x
		offy = twins.container.internal.y
	end
	for k, v in pairs(twins.elements) do
		local ex, ey, ew, eh = v.getxywh(v)
		if x-offx >= ex and x-offx < ex + ew and y-offy >= ey and y-offy < ey + eh and v.clickable then
			if v.visible and twins.focus ~= k then
				local foc_elem = twins.get_focus()
				if foc_elem then
					invoke(foc_elem, \"onfocus\", x-v.x, y-v.y)
				end

				twins.focus = k
				invoke(twins.get_focus(), \"onfocusloss\")
			end
			invoke(v, \"onclick\", {x=x, y=y}, {x=x-v.x, y=y-v.y}, button)
		end
	end
end

local function key_down_listener(e_name, addr, letter, key)
	local focus = twins.get_focus()
	invoke(twins.document, \"onkeydown\", letter, key)
	if focus then
		if focus.visible then
			invoke(focus, \"onkeydown\", letter, key)
		end
	end
end

local function scroll_listener(e_name, addr, x, y, size)
	local offx, offy = 0, 0
	if twins.container.type == \"tornado_vs\" then
		offx = twins.container.internal.x
		offy = twins.container.internal.y
	end
	for k, v in pairs(twins.elements) do
		local ex, ey, ew, eh = v.getxywh(v)
		if x-offx >= ex and x-offx < ex + ew and y-offy >= ey and y-offy < ey + eh then
			invoke(v, \"onscroll\", {x=x, y=y}, {x=x-v.x, y=y-v.y}, size)
		end
	end
end


function twins.clear_screen(color)
	twins.container.setForeground(twins.document.fgcolor or 0xffffff)
	twins.container.setBackground(color or twins.document.bgcolor or 0x000000)
	twins.container.fill(1, 1, twins.scw, twins.sch, \" \")
end

twins.load_elements(\"/lib/twins/core/elem_base.lua\", \"base\", true)

function twins.clear_elements()
	twins.elements = {}
	twins.named_elements = {}
end

function twins.use_macros(container)
	if type(container) ~= \"table\" then
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
	twins.container.set(3, 1, \"[\"..title..\"]\")
end

local function shutdown_sequence()
	for k, v in pairs(twins.elements) do
		invoke(v, \"ondestroy\")
		twins.elements[k] = nil
	end
end

local kdid, t_id, scr_id

function twins.connect_listeners()
	kdid = event.listen(\"key_down\", key_down_listener)
	t_id = event.listen(\"touch\", touch_listener)
	scr_id = event.listen(\"scroll\", scroll_listener)
end

function twins.disconnect_listeners()
	event.cancel(kdid)
	event.cancel(t_id)
	event.cancel(scr_id)
end

function twins.euthanize()
	twins.running = false
	computer.pushSignal(\"twins_term\", 1)
end

function twins.sleep(timeout)
	local deadline = computer.uptime() + (timeout or 0)
	repeat
		local sig = event.pull(deadline - computer.uptime())
	until computer.uptime() >= deadline or sig == \"twins_term\"
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
",["/lib/twins/core/elem_base.lua"]="local unicode = require \"unicode\"
local event = require \"event\"
local serialization = require \"serialization\"
local elem_base = {
	button = {
		x = 1, y = 1,
		w = 10, h = 3,
		bgcolor = 0x222222,
		fgcolor = 0xffffff,
		text = \"button\",
		render = function(self)
			twins.container.setBackground(self.bgcolor)
			twins.container.setForeground(self.fgcolor)
			twins.container.fill(self.x, self.y, self.w, self.h, \" \")
			twins.draw_frame(self)
			twins.container.set(self.x+self.w/2-unicode.len(self.text)/2, self.y+self.h/2, self.text)
		end
	},
	text = {
		x = 1, y = 1,
		h = 1,
		text = \"text\",
		fgcolor = 0xffffff,
		bgcolor = 0x000000,
		render = function(self)
			twins.container.setForeground(self.fgcolor)
			twins.container.setBackground(self.bgcolor)
			local text = unicode.sub(tostring(self.text), 1, self.w)
			text = text .. string.rep(\" \", self.w-unicode.len(text))
			twins.container.set(self.x, self.y, text)
		end,
		oncreate = function(self)
			if not self.w then
				self.w = unicode.len(self.text)
			end
		end
	},
	checkbox = {
		x = 1, y = 1,
		w = 4, h = 3,
		active_color = 0xcccccc,
		active = false,
		bgcolor = 0x000000,
		fgcolor = 0xffffff,
		render = function(self)
			twins.container.setForeground(self.fgcolor)
			twins.container.setBackground(self.bgcolor)
			twins.draw_frame(self)
			if self.active then 
				twins.container.setBackground(self.active_color)
			end
			twins.container.set(self.x+1, self.y+1, \"  \")
		end,
		onclick = function(self)
			self.active = not self.active
			self.render(self)
		end
	},
	input = {
		x=1, y=1,
		w=10, h=2,
		bgcolor = 0x222222,
		fgcolor = 0xffffff,
		cursor = 1, view = 1,
		blinker_t = \"not_init\",
		blinker_state = 0,
		allowed_chars = \"\",
		text=\"\",
		password=false,
		render = function(self)
			while self.cursor-self.view > self.w-1 do
				self.view = self.view + 1
			end
			while self.cursor-self.view < 0 do
				self.view = self.view - 1
			end
			if self.view < 1 then self.view = 1 end
			twins.container.setBackground(self.bgcolor)
			twins.container.setForeground(self.fgcolor)
			twins.container.set(self.x, self.y+self.h-1, string.rep(\"─\", self.w))
			local text = unicode.sub(tostring(self.text), self.view, self.view+self.w-1)

			if self.password then
				text = string.rep(\"*\", unicode.len(text))
			end

			text = text .. string.rep(\" \", self.w - unicode.len(text))
			twins.container.set(self.x, self.y, text)
		end,
		draw_cursor = function(self)
			self.blinker_state = (self.blinker_state + 1) % 2
			local glob_cur_pos = self.cursor-self.view+self.x
			if self.blinker_state == 0 then
				local cur_char = twins.container.get(glob_cur_pos, self.y)
				twins.container.setBackground(self.bgcolor)
				twins.container.setForeground(self.fgcolor)
				twins.container.set(glob_cur_pos, self.y, cur_char)
			else
				if twins.focus == self._id then
					local cur_char = twins.container.get(glob_cur_pos, self.y)
					twins.container.setBackground(self.fgcolor)
					twins.container.setForeground(self.bgcolor)
					twins.container.set(glob_cur_pos, self.y, cur_char)
				end
			end
		end,
		onclick = function(self)
			if self.cursor > unicode.len(self.text) + 1 then
				self.cursor = unicode.len(self.text) + 1
			end
			if self.cursor < 1 then
				self.cursor = 1
			end
			self.draw_cursor(self) 
		end,
		oncreate = function(self)
			self.blinker_t = event.timer(0.5, 
				function()
					self.draw_cursor(self)
				end,
				math.huge)
			self.cursor = unicode.len(self.text) + 1
		end,
		ondestroy = function(self)
			event.cancel(self.blinker_t)
		end,
		ovr_lets = {
			[8] = 
			function(self, let, key)
				self.text = unicode.sub(self.text, 1, self.cursor-2) .. unicode.sub(self.text, self.cursor, unicode.len(self.text))
				self.cursor = self.cursor - 1
				if self.cursor < 1 then
					self.cursor = 1
				end
				while self.cursor-self.view < 1 do
					self.view = self.view - 1
				end
				self.render(self)
			end,
			[13] =
			function(self, let, key)
				if self.onconfirm then
					self.onconfirm(self)
				end
			end
		},
		ovr_keys = {
			[203] =
			function(self, let, key)
				self.cursor = self.cursor - 1
				if self.cursor < 1 then
					self.cursor = 1
				end
				self.render(self)
			end,
			[205] =
			function(self, let, key)
				self.cursor = self.cursor + 1
				if self.cursor > unicode.len(self.text) + 1 then
					self.cursor = unicode.len(self.text) + 1
				end
				self.render(self)
			end
		},
		typechar = function(self, let, key)
			self.text = (unicode.sub(self.text, 1, self.cursor-1) ..
				unicode.char(let) .. 
				unicode.sub(self.text, self.cursor, unicode.len(self.text))
				)
			self.cursor = self.cursor + 1
			self.render(self)

			if self.onmodify then self.onmodify(self) end
		end,
		onkeydown = function(self, let, key)
			if self.ovr_lets[let] then
				self.ovr_lets[let](self, let, key)
				if self.onmodify then self.onmodify(self) end
			elseif self.ovr_keys[key] then
				self.ovr_keys[key](self, let, key)
				if self.onmodify then self.onmodify(self) end
			else
				if let > 31 then
					if self.allowed_chars:len() == 0 or self.allowed_chars:find(string.char(let)) then
						self.typechar(self, let, key)
					end
				end
			end
			if self.cursor < 1 then self.cursor = 1 end
			self.blinker_state = 0
			self.draw_cursor(self)
		end
	},
	frame = {
		x = 1, y = 1,
		w = 10, h = 10,
		bgcolor = 0x000000,
		fgcolor = 0xffffff,
		render = function(self)
			twins.container.setBackground(self.bgcolor)
			twins.container.setForeground(self.fgcolor)
			twins.draw_frame(self)
		end
	},
	list = {
		x = 1, y = 1,
		w = 10, h = 10,
		bgcolor = 0x000000,
		fgcolor = 0xffffff,
		sel_color = 0x666666,
		selection = -1,
		items = {},
		scroll_size = 3,
		scroll = 0,
		get_value = function(self) return self.items[self.selection] end,
		render = function(self)
			twins.container.setBackground(self.bgcolor)
			twins.container.setForeground(self.fgcolor)
			local line = 0
			if self.scroll > 0 then
				twins.container.set(self.x, self.y+line, \"...\"..(\" \"):rep(self.w-3))
				line = line + 1
			end
			for k=self.scroll+1, #self.items do
				local i = self.items[k]
				local wspace = (\" \"):rep(self.w-unicode.len(i))
				if self.selection-self.scroll == line+1 then
					twins.container.setBackground(self.sel_color)
					twins.container.set(self.x, self.y+line, tostring(i)..wspace)
					twins.container.setBackground(self.bgcolor)
				else
					twins.container.set(self.x, self.y+line, tostring(i)..wspace)
				end
				line = line + 1
				if line == self.h then
					twins.container.set(self.x, self.y+line, \"...\"..(\" \"):rep(self.w-3))
					return
				end
			end
			local wspace = (\" \"):rep(self.w)
			for i=line, self.h-1 do
				twins.container.set(self.x, self.y+i, wspace)
			end
		end,
		onclick = function(self, pabs, prel, button)
			if prel.y+self.scroll+1 <= #self.items+1 then
				self.selection = prel.y+self.scroll+1
				if self.onmodify then
					self.onmodify(self)
				end
			end
			self.render(self)
		end,
		onscroll = function(self, pabs, prel, size)
			self.scroll = self.scroll - size*self.scroll_size
			if self.scroll > #self.items-self.scroll_size then self.scroll = #self.items-self.scroll_size end
			if self.scroll < 0 then self.scroll = 0 end
			self.render(self)
		end
	},
	group = {
		x = 1, y = 1,
		w = 10, h = 0,
		bgcolor = 0x000000,
		fgcolor = 0xffffff,
		clickable = false,
		visible = false,
		linked_frame = nil,
		framed = false,
		gap = 1,
		direction = \"horizontal\",
		items={},
		padding = {left=0, right=0, up=0, down=0},
		calculate_positions = function(self)
			if self.direction == \"horizontal\" or self.direction == \"h\" then
				local dx = self.padding.left
				local h_max = 0
				for k, v in ipairs(self.items) do
					assert(type(v) == \"table\", \"[\"..k..\"] не является элементом.\")
					v.y = self.y + (v.off_y or 0) + self.padding.up
					v.x = self.x + dx + (v.off_x or 0)
					if v.calculate_positions then
						v:calculate_positions()
					end
					h_max = math.max(h_max, v.h)
					dx = dx + v.w + self.gap
				end
				self.w = dx - self.gap + self.padding.right
				self.h = h_max + self.padding.down + self.padding.up
			elseif self.direction == \"vertical\" or self.direction == \"v\" then
				local dy = self.padding.up
				local w_max = 0
				for k, v in ipairs(self.items) do
					assert(type(v) == \"table\", \"[\"..k..\"] не является элементом.\")
					v.y = self.y + dy + (v.off_y or 0)
					v.x = self.x + self.padding.right + (v.off_x or 0)
					if v.calculate_positions then
						v:calculate_positions()
					end
					w_max = math.max(w_max, v.w)
					dy = dy + v.h + self.gap
					
				end
				self.w = w_max + self.padding.right + self.padding.left
				self.h = dy - self.gap + self.padding.down
			end
			if self.linked_frame then
				self.linked_frame.x = self.x
				self.linked_frame.y = self.y
				self.linked_frame.w = self.w
				self.linked_frame.h = self.h
			end
		end,
		render = function(self) end,
		oncreate = function(self)
			if self.framed then
				self.padding = {left=1, right=1, up=1, down=1}
			end
			self:calculate_positions()
			if self.align then
				twins.sps.position(self.align, self)
				self:calculate_positions()
			end
			if self.framed and self.linked_frame == nil then
					self.linked_frame = twins.base.frame({
					x=self.x, 
					y=self.y, 
					w=self.w, 
					h=self.h, 
					fgcolor=self.fgcolor, 
					bgcolor=self.bgcolor,
					clickable=false
				})
			end
		end
	},
	radio_button = {
		x = 1, y = 1,
		w = 10, h = 3,
		bgcolor = 0x222222,
		active_bgcolor = 0x666666,
		active_fgcolor = 0xffffff,
		fgcolor = 0xffffff,
		active = false,
		radio_channel = 1,
		text = \"button\",
		set_channel = function(self, channel)
			local channel_arr = twins.radio_channel[self.radio_channel]
			for i = 1, #channel_arr do
				if channel_arr[i] == self then
					table.remove(channel_arr, i)
				end
			end
			self.radio_channel = channel
			self:oncreate()
		end,
		render = function(self)
			if self.active then
				twins.container.setBackground(self.active_bgcolor)
				twins.container.setForeground(self.active_fgcolor)
			else
				twins.container.setBackground(self.bgcolor)
				twins.container.setForeground(self.fgcolor)
			end
			twins.container.fill(self.x, self.y, self.w, self.h, \" \")
			twins.draw_frame(self)
			twins.container.set(self.x+self.w/2-unicode.len(self.text)/2, self.y+self.h/2, self.text)
		end,
		oncreate = function(self)
			twins.radio_channel = twins.radio_channel or {}
			if twins.radio_channel[self.radio_channel] == nil then
				twins.radio_channel[self.radio_channel] = {self}
			else
				table.insert(twins.radio_channel[self.radio_channel], self)
			end
		end,
		onclick = function(self)
			local channel = twins.radio_channel[self.radio_channel]
			for k, v in ipairs(channel) do
				if v.active then
					v.active = false
					v:render()
				end
			end
			self.active = true
			self:render()
		end,
		ondestroy = function(self)
			local channel = twins.radio_channel[self.radio_channel]
			for k, v in ipairs(channel) do
				if v == self then
					table.remove(channel, k)
					break
				end
			end
		end
	},
	spacing = {
		visible = false,
		clickable = false,
		w = 1, h = 1
	}
}
return elem_base",["/lib/twins/core/sps.lua"]="local sps = {}

function sps.center(e, mode)
	local cx = math.floor((twins.scw-e.w)/2)
	local cy = math.floor((twins.sch-e.h)/2)
	if mode == \'x\' then
		e.x = cx
	elseif mode == \'y\' then
		e.y = cy
	else
		e.x = cx
		e.y = cy
	end
	if e.calculate_positions then
		e:calculate_positions()
	end
	return e, {x=cx, y=cy}
end

function sps.right(e)
	local rx = twins.scw-e.w-1
	e.x = rx
	if e.calculate_positions then
		e:calculate_positions()
	end
	return e, rx
end

function sps.left(e)
	local lx = 1
	e.x = lx
	if e.calculate_positions then
		e:calculate_positions()
	end
	return e, lx
end

function sps.up(e)
	local uy = 1
	e.y = uy
	if e.calculate_positions then
		e:calculate_positions()
	end
	return e, uy
end

function sps.down(e)
	local dy = twins.sch-e.h
	e.y = dy
	if e.calculate_positions then
		e:calculate_positions()
	end
	return e, dy
end

local function pos_list(list, dir, fun)
	dir = dir or \"down\"
	if dir == \"down\" then
		local ly = 1
		for k, e in pairs(list) do
			fun(e)
			e.y = ly
			ly = ly + e.h
			if e.calculate_positions then
				e:calculate_positions()
			end
		end
	else
		local ly = twins.sch
		for k, e in pairs(list) do
			ly = ly - e.h
			fun(e)
			e.y = ly
			if e.calculate_positions then
				e:calculate_positions()
			end
		end
	end
	return list
end

function sps.right_list(list, dir)
	return pos_list(list, dir, sps.right)
end

function sps.left_list(list, dir)
	return pos_list(list, dir, sps.left)
end

function sps.center_list(list, dir)
	return pos_list(list, dir, sps.center)
end

function sps.position(attr, e)
	for fun in attr:gmatch(\"[%w_]+\") do
		if type(sps[fun]) == \"function\" then sps[fun](e) end
	end
	if e.calculate_positions then
		e:calculate_positions()
	end
	return e
end

return sps"}

for k, v in pairs(pkg) do
    local dir = fs.path(k)
    if (not fs.isDirectory(dir)) or (not fs.exists(dir)) then
        print("Создание папки: "..dir)
        fs.makeDirectory(dir)
    end
    print("Распаковка: "..k)
    local f, e = io.open(k, "w")
    if not f then error(e) end
    f:write(v)
    f:flush()
    f:close()
end
