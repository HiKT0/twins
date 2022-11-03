local fs = require("filesystem")
local pkg = { ["/lib/twins/init.lua"]="local event = require(\"event\")\nlocal computer = require(\"computer\")\n\ntwins = {}\ntwins.container = require(\"component\").gpu\n\ntwins.scw, twins.sch = twins.container.getResolution()\n\ntwins.document = {}\ntwins.elements = {}\ntwins.named_elements = {}\ntwins.focus = -1\n\ntwins.storage = {}\ntwins.sps = require(\"twins.core.sps\")\n\nfunction twins.wake()\n	twins.scw, twins.sch = twins.container.getResolution()\nend\n\nlocal function invoke(element, method, ...)\n	if type(element[method]) == \"function\" then\n		element[method](element, ...)\n	end\nend\n\nfunction twins.get_focus()\n	return twins.elements[twins.focus]\nend\n\nfunction twins.render(force)\n	for k, v in pairs(twins.elements) do\n		if rawget(v, \"changed\") or force then\n			invoke(v, \"render\")\n			rawset(v, \"changed\", false)\n		end\n	end\n	if twins.document.title then twins.title(twins.document.title) end\nend\n\n\nfunction twins.add_element(element)\n	for i=1, #twins.elements+1 do\n		if twins.elements[i] == nil then\n			element = setmetatable({\n				internal=element,\n				render=element.render,\n				getxywh = function(t)\n					return rawget(t.internal, \"x\"), rawget(t.internal, \"y\"), \n					rawget(t.internal, \"w\"), rawget(t.internal, \"h\")\n				end\n			}, {\n				__index = function(t, i)\n					rawset(t, \"changed\", true)\n					return rawget(t.internal, i)\n				end,\n				__newindex = function(t, i, v)\n					rawset(t, \"changed\", true)\n					rawset(t.internal, i, v)\n				end,\n				__pairs = function(t) return pairs(rawget(t, \"internal\")) end,\n				__ipairs = function(t) return ipairs(rawget(t, \"internal\")) end\n			})\n			twins.elements[i] = element\n			twins.elements[i]._id = i\n			if twins.elements[i].clickable == nil then twins.elements[i].clickable = true end\n			if twins.elements[i].visible == nil then twins.elements[i].visible = true end\n			invoke(twins.elements[i], \"oncreate\")\n			return twins.elements[i]\n		end\n	end\nend\n\nlocal function deep_copy(t)\n	if type(t) ~= \"table\" then\n		return t\n	end\n\n	local new_t = {}\n	for k, v in pairs(t) do\n		new_t[k] = deep_copy(v)\n	end\n	return new_t\nend\n\nlocal function load_from_file(module_name)\n	local succ, mod\n	if not load_only then\n		succ, mod = pcall(require, module_name)\n		local err\n		if not succ then\n			succ, mod = pcall(function()\n				local code, err = loadfile(module_name)\n				assert(code, err)\n				return code()\n			end)\n		end\n	else\n		succ, mod = pcall(function()\n			local code, err = loadfile(module_name)\n			assert(code, err)\n			return code()\n		end)\n	end\n\n	if not mod then error(\"Файл не может быть найден.\") end\n	if type(mod) == \"string\" then\n		error(mod)\n	end\n	return mod\nend\n\n\nfunction twins.load_elements(module_name, load_as, load_only)\n	local mod\n	local mod_type = type(module_name)\n	if mod_type == \"string\" then\n		mod = load_from_file(module_name)\n	elseif mod_type == \"table\" then\n		mod = module_name\n	else\n		error(\"Аргумент типа \" .. mod_type .. \" не поддерживается\")\n	end\n\n	twins[load_as] = {}\n	for elem_name, elem_content in pairs(mod) do\n		if elem_content.render then\n			local _render = elem_content.render\n			local function wrapped_render(self)\n				if twins.running then\n					_render(self)\n				end\n			end\n		end\n		twins[load_as][elem_name] = \n		function(t)\n			t = t or {}\n			for k, v in pairs(elem_content) do\n				if not t[k] then t[k] = deep_copy(v) end\n			end\n			local prepared_element = twins.add_element(t)\n			if t.key ~= nil then\n				assert(\n					twins.named_elements[prepared_element.key] == nil, \n					\"Ошибка при создании элемента с ключом: \\\"\"..prepared_element.key .. \"\\\" уже существует\"\n				)\n				twins.named_elements[prepared_element.key] = prepared_element\n			end\n			prepared_element.render = wrapped_render\n			return prepared_element\n		end\n	end\nend\n\nfunction twins.get_element_by_key(key)\n	return twins.named_elements[key]\nend\n\nfunction twins.draw_frame(elem)\n	local vl = (\"│\"):rep(elem.h-2)\n	local hl = (\"─\"):rep(elem.w-2)\n\n	twins.container.set(elem.x, elem.y, \"┌\"..vl..\"└\", true)\n	twins.container.set(elem.x+elem.w-1, elem.y, \"┐\"..vl..\"┘\", true)\n	twins.container.set(elem.x+1, elem.y, hl)\n	twins.container.set(elem.x+1, elem.y+elem.h-1, hl)\nend\n\nlocal function touch_listener(e_name, addr, x, y, button)\n	local offx, offy = 0, 0\n	if twins.container.type == \"tornado_vs\" then\n		offx = twins.container.internal.x\n		offy = twins.container.internal.y\n	end\n	for k, v in pairs(twins.elements) do\n		local ex, ey, ew, eh = v.getxywh(v)\n		if x-offx >= ex and x-offx < ex + ew and y-offy >= ey and y-offy < ey + eh and v.clickable then\n			if v.visible and twins.focus ~= k then\n				local foc_elem = twins.get_focus()\n				if foc_elem then\n					invoke(foc_elem, \"onfocus\", x-v.x, y-v.y)\n				end\n\n				twins.focus = k\n				invoke(twins.get_focus(), \"onfocusloss\")\n			end\n			invoke(v, \"onclick\", {x=x, y=y}, {x=x-v.x, y=y-v.y}, button)\n		end\n	end\nend\n\nlocal function key_down_listener(e_name, addr, letter, key)\n	local focus = twins.get_focus()\n	invoke(twins.document, \"onkeydown\", letter, key)\n	if focus then\n		if focus.visible then\n			invoke(focus, \"onkeydown\", letter, key)\n		end\n	end\nend\n\nlocal function scroll_listener(e_name, addr, x, y, size)\n	local offx, offy = 0, 0\n	if twins.container.type == \"tornado_vs\" then\n		offx = twins.container.internal.x\n		offy = twins.container.internal.y\n	end\n	for k, v in pairs(twins.elements) do\n		local ex, ey, ew, eh = v.getxywh(v)\n		if x-offx >= ex and x-offx < ex + ew and y-offy >= ey and y-offy < ey + eh then\n			invoke(v, \"onscroll\", {x=x, y=y}, {x=x-v.x, y=y-v.y}, size)\n		end\n	end\nend\n\n\nfunction twins.clear_screen(color)\n	twins.container.setForeground(twins.document.fgcolor or 0xffffff)\n	twins.container.setBackground(color or twins.document.bgcolor or 0x000000)\n	twins.container.fill(1, 1, twins.scw, twins.sch, \" \")\nend\n\ntwins.load_elements(\"/lib/twins/core/elem_base.lua\", \"base\", true)\n\nfunction twins.clear_elements()\n	twins.elements = {}\n	twins.named_elements = {}\nend\n\nfunction twins.use_macros(container)\n	if type(container) ~= \"table\" then\n		container = _G\n	end\n\n	function container.group(props)\n		return function(items)\n			props.items = items\n			return twins.base.group(props)\n		end\n	end\n\n	container.button = twins.base.button\n	container.text = twins.base.text\n	container.input = twins.base.input\nend\n\nfunction twins.title(title)\n	twins.container.set(3, 1, \"[\"..title..\"]\")\nend\n\nlocal function shutdown_sequence()\n	for k, v in pairs(twins.elements) do\n		invoke(v, \"ondestroy\")\n		twins.elements[k] = nil\n	end\nend\n\nlocal kdid, t_id, scr_id\n\nfunction twins.connect_listeners()\n	kdid = event.listen(\"key_down\", key_down_listener)\n	t_id = event.listen(\"touch\", touch_listener)\n	scr_id = event.listen(\"scroll\", scroll_listener)\nend\n\nfunction twins.disconnect_listeners()\n	event.cancel(kdid)\n	event.cancel(t_id)\n	event.cancel(scr_id)\nend\n\nfunction twins.euthanize()\n	twins.running = false\n	computer.pushSignal(\"twins_term\", 1)\nend\n\nfunction twins.sleep(timeout)\n	local deadline = computer.uptime() + (timeout or 0)\n	repeat\n		local sig = event.pull(deadline - computer.uptime())\n	until computer.uptime() >= deadline or sig == \"twins_term\"\nend\n\nfunction twins.main()\n	local init_bg = twins.container.getBackground()\n	local init_fg = twins.container.getForeground()\n	twins.running = true\n	twins.connect_listeners()\n	local succ = xpcall(function()\n		twins.clear_screen()\n		twins.render()\n		while twins.running do\n			for k, v in ipairs(twins.elements) do\n				twins.sleep(10)\n				v:render()\n				if not twins.running then break end\n			end\n			twins.sleep(1)\n		end\n	end, function(...) err = debug.traceback(...) end)\n	twins.disconnect_listeners()\n	shutdown_sequence()\n	twins.container.setForeground(init_fg)\n	twins.container.setBackground(init_bg)\n	twins.clear_elements()\n	if not succ then error(err, 3) end\nend\n\nfunction twins.main_coroutine()\n	local init_bg = twins.container.getBackground()\n	local init_fg = twins.container.getForeground()\n	twins.running = true\n	twins.connect_listeners()\n	local succ, err = xpcall(function()\n		twins.clear_screen()\n		while twins.running do\n			twins.render()\n			coroutine.yield()\n		end\n	end, function(...) err = debug.traceback(...) end)\n	twins.disconnect_listeners()\n	twins.clear_screen(twins.document.destroy_color)\n	shutdown_sequence()\n	twins.container.setForeground(init_fg)\n	twins.container.setBackground(init_bg)\n	twins.clear_elements()\n	if not succ then error(err, 3) end\nend\n\nreturn twins\n",["/lib/twins/core/elem_base.lua"]="local unicode = require \"unicode\"\nlocal event = require \"event\"\nlocal serialization = require \"serialization\"\nlocal elem_base = {\n	button = {\n		x = 1, y = 1,\n		w = 10, h = 3,\n		bgcolor = 0x222222,\n		fgcolor = 0xffffff,\n		text = \"button\",\n		render = function(self)\n			twins.container.setBackground(self.bgcolor)\n			twins.container.setForeground(self.fgcolor)\n			twins.container.fill(self.x, self.y, self.w, self.h, \" \")\n			twins.draw_frame(self)\n			twins.container.set(self.x+self.w/2-unicode.len(self.text)/2, self.y+self.h/2, self.text)\n		end\n	},\n	text = {\n		x = 1, y = 1,\n		h = 1,\n		text = \"text\",\n		fgcolor = 0xffffff,\n		bgcolor = 0x000000,\n		render = function(self)\n			twins.container.setForeground(self.fgcolor)\n			twins.container.setBackground(self.bgcolor)\n			local text = unicode.sub(tostring(self.text), 1, self.w)\n			text = text .. string.rep(\" \", self.w-unicode.len(text))\n			twins.container.set(self.x, self.y, text)\n		end,\n		oncreate = function(self)\n			if not self.w then\n				self.w = unicode.len(self.text)\n			end\n		end\n	},\n	checkbox = {\n		x = 1, y = 1,\n		w = 4, h = 3,\n		active_color = 0xcccccc,\n		active = false,\n		bgcolor = 0x000000,\n		fgcolor = 0xffffff,\n		render = function(self)\n			twins.container.setForeground(self.fgcolor)\n			twins.container.setBackground(self.bgcolor)\n			twins.draw_frame(self)\n			if self.active then \n				twins.container.setBackground(self.active_color)\n			end\n			twins.container.set(self.x+1, self.y+1, \"  \")\n		end,\n		onclick = function(self)\n			self.active = not self.active\n			self.render(self)\n		end\n	},\n	input = {\n		x=1, y=1,\n		w=10, h=2,\n		bgcolor = 0x222222,\n		fgcolor = 0xffffff,\n		cursor = 1, view = 1,\n		blinker_t = \"not_init\",\n		blinker_state = 0,\n		allowed_chars = \"\",\n		text=\"\",\n		password=false,\n		render = function(self)\n			while self.cursor-self.view > self.w-1 do\n				self.view = self.view + 1\n			end\n			while self.cursor-self.view < 0 do\n				self.view = self.view - 1\n			end\n			if self.view < 1 then self.view = 1 end\n			twins.container.setBackground(self.bgcolor)\n			twins.container.setForeground(self.fgcolor)\n			twins.container.set(self.x, self.y+self.h-1, string.rep(\"─\", self.w))\n			local text = unicode.sub(tostring(self.text), self.view, self.view+self.w-1)\n\n			if self.password then\n				text = string.rep(\"*\", unicode.len(text))\n			end\n\n			text = text .. string.rep(\" \", self.w - unicode.len(text))\n			twins.container.set(self.x, self.y, text)\n		end,\n		draw_cursor = function(self)\n			self.blinker_state = (self.blinker_state + 1) % 2\n			local glob_cur_pos = self.cursor-self.view+self.x\n			if self.blinker_state == 0 then\n				local cur_char = twins.container.get(glob_cur_pos, self.y)\n				twins.container.setBackground(self.bgcolor)\n				twins.container.setForeground(self.fgcolor)\n				twins.container.set(glob_cur_pos, self.y, cur_char)\n			else\n				if twins.focus == self._id then\n					local cur_char = twins.container.get(glob_cur_pos, self.y)\n					twins.container.setBackground(self.fgcolor)\n					twins.container.setForeground(self.bgcolor)\n					twins.container.set(glob_cur_pos, self.y, cur_char)\n				end\n			end\n		end,\n		onclick = function(self)\n			if self.cursor > unicode.len(self.text) + 1 then\n				self.cursor = unicode.len(self.text) + 1\n			end\n			if self.cursor < 1 then\n				self.cursor = 1\n			end\n			self.draw_cursor(self) \n		end,\n		oncreate = function(self)\n			self.blinker_t = event.timer(0.5, \n				function()\n					self.draw_cursor(self)\n				end,\n				math.huge)\n			self.cursor = unicode.len(self.text) + 1\n		end,\n		ondestroy = function(self)\n			event.cancel(self.blinker_t)\n		end,\n		ovr_lets = {\n			[8] = \n			function(self, let, key)\n				self.text = unicode.sub(self.text, 1, self.cursor-2) .. unicode.sub(self.text, self.cursor, unicode.len(self.text))\n				self.cursor = self.cursor - 1\n				if self.cursor < 1 then\n					self.cursor = 1\n				end\n				while self.cursor-self.view < 1 do\n					self.view = self.view - 1\n				end\n				self.render(self)\n			end,\n			[13] =\n			function(self, let, key)\n				if self.onconfirm then\n					self.onconfirm(self)\n				end\n			end\n		},\n		ovr_keys = {\n			[203] =\n			function(self, let, key)\n				self.cursor = self.cursor - 1\n				if self.cursor < 1 then\n					self.cursor = 1\n				end\n				self.render(self)\n			end,\n			[205] =\n			function(self, let, key)\n				self.cursor = self.cursor + 1\n				if self.cursor > unicode.len(self.text) + 1 then\n					self.cursor = unicode.len(self.text) + 1\n				end\n				self.render(self)\n			end\n		},\n		typechar = function(self, let, key)\n			self.text = (unicode.sub(self.text, 1, self.cursor-1) ..\n				unicode.char(let) .. \n				unicode.sub(self.text, self.cursor, unicode.len(self.text))\n				)\n			self.cursor = self.cursor + 1\n			self.render(self)\n\n			if self.onmodify then self.onmodify(self) end\n		end,\n		onkeydown = function(self, let, key)\n			if self.ovr_lets[let] then\n				self.ovr_lets[let](self, let, key)\n				if self.onmodify then self.onmodify(self) end\n			elseif self.ovr_keys[key] then\n				self.ovr_keys[key](self, let, key)\n				if self.onmodify then self.onmodify(self) end\n			else\n				if let > 31 then\n					if self.allowed_chars:len() == 0 or self.allowed_chars:find(string.char(let)) then\n						self.typechar(self, let, key)\n					end\n				end\n			end\n			if self.cursor < 1 then self.cursor = 1 end\n			self.blinker_state = 0\n			self.draw_cursor(self)\n		end\n	},\n	frame = {\n		x = 1, y = 1,\n		w = 10, h = 10,\n		bgcolor = 0x000000,\n		fgcolor = 0xffffff,\n		render = function(self)\n			twins.container.setBackground(self.bgcolor)\n			twins.container.setForeground(self.fgcolor)\n			twins.draw_frame(self)\n		end\n	},\n	list = {\n		x = 1, y = 1,\n		w = 10, h = 10,\n		bgcolor = 0x000000,\n		fgcolor = 0xffffff,\n		sel_color = 0x666666,\n		selection = -1,\n		items = {},\n		scroll_size = 3,\n		scroll = 0,\n		get_value = function(self) return self.items[self.selection] end,\n		render = function(self)\n			twins.container.setBackground(self.bgcolor)\n			twins.container.setForeground(self.fgcolor)\n			local line = 0\n			if self.scroll > 0 then\n				twins.container.set(self.x, self.y+line, \"...\"..(\" \"):rep(self.w-3))\n				line = line + 1\n			end\n			for k=self.scroll+1, #self.items do\n				local i = self.items[k]\n				local wspace = (\" \"):rep(self.w-unicode.len(i))\n				if self.selection-self.scroll == line+1 then\n					twins.container.setBackground(self.sel_color)\n					twins.container.set(self.x, self.y+line, tostring(i)..wspace)\n					twins.container.setBackground(self.bgcolor)\n				else\n					twins.container.set(self.x, self.y+line, tostring(i)..wspace)\n				end\n				line = line + 1\n				if line == self.h then\n					twins.container.set(self.x, self.y+line, \"...\"..(\" \"):rep(self.w-3))\n					return\n				end\n			end\n			local wspace = (\" \"):rep(self.w)\n			for i=line, self.h-1 do\n				twins.container.set(self.x, self.y+i, wspace)\n			end\n		end,\n		onclick = function(self, pabs, prel, button)\n			if prel.y+self.scroll+1 <= #self.items+1 then\n				self.selection = prel.y+self.scroll+1\n				if self.onmodify then\n					self.onmodify(self)\n				end\n			end\n			self.render(self)\n		end,\n		onscroll = function(self, pabs, prel, size)\n			self.scroll = self.scroll - size*self.scroll_size\n			if self.scroll > #self.items-self.scroll_size then self.scroll = #self.items-self.scroll_size end\n			if self.scroll < 0 then self.scroll = 0 end\n			self.render(self)\n		end\n	},\n	group = {\n		x = 1, y = 1,\n		w = 10, h = 0,\n		bgcolor = 0x000000,\n		fgcolor = 0xffffff,\n		clickable = false,\n		visible = false,\n		linked_frame = nil,\n		framed = false,\n		gap = 1,\n		direction = \"horizontal\",\n		items={},\n		padding = {left=0, right=0, up=0, down=0},\n		calculate_positions = function(self)\n			if self.direction == \"horizontal\" or self.direction == \"h\" then\n				local dx = self.padding.left\n				local h_max = 0\n				for k, v in ipairs(self.items) do\n					assert(type(v) == \"table\", \"[\"..k..\"] не является элементом.\")\n					v.y = self.y + (v.off_y or 0) + self.padding.up\n					v.x = self.x + dx + (v.off_x or 0)\n					if v.calculate_positions then\n						v:calculate_positions()\n					end\n					h_max = math.max(h_max, v.h)\n					dx = dx + v.w + self.gap\n				end\n				self.w = dx - self.gap + self.padding.right\n				self.h = h_max + self.padding.down + self.padding.up\n			elseif self.direction == \"vertical\" or self.direction == \"v\" then\n				local dy = self.padding.up\n				local w_max = 0\n				for k, v in ipairs(self.items) do\n					assert(type(v) == \"table\", \"[\"..k..\"] не является элементом.\")\n					v.y = self.y + dy + (v.off_y or 0)\n					v.x = self.x + self.padding.right + (v.off_x or 0)\n					if v.calculate_positions then\n						v:calculate_positions()\n					end\n					w_max = math.max(w_max, v.w)\n					dy = dy + v.h + self.gap\n					\n				end\n				self.w = w_max + self.padding.right + self.padding.left\n				self.h = dy - self.gap + self.padding.down\n			end\n			if self.linked_frame then\n				self.linked_frame.x = self.x\n				self.linked_frame.y = self.y\n				self.linked_frame.w = self.w\n				self.linked_frame.h = self.h\n			end\n		end,\n		render = function(self) end,\n		oncreate = function(self)\n			if self.framed then\n				self.padding = {left=1, right=1, up=1, down=1}\n			end\n			self:calculate_positions()\n			if self.align then\n				twins.sps.position(self.align, self)\n				self:calculate_positions()\n			end\n			if self.framed and self.linked_frame == nil then\n					self.linked_frame = twins.base.frame({\n					x=self.x, \n					y=self.y, \n					w=self.w, \n					h=self.h, \n					fgcolor=self.fgcolor, \n					bgcolor=self.bgcolor,\n					clickable=false\n				})\n			end\n		end\n	},\n	radio_button = {\n		x = 1, y = 1,\n		w = 10, h = 3,\n		bgcolor = 0x222222,\n		active_bgcolor = 0x666666,\n		active_fgcolor = 0xffffff,\n		fgcolor = 0xffffff,\n		active = false,\n		radio_channel = 1,\n		text = \"button\",\n		set_channel = function(self, channel)\n			local channel_arr = twins.radio_channel[self.radio_channel]\n			for i = 1, #channel_arr do\n				if channel_arr[i] == self then\n					table.remove(channel_arr, i)\n				end\n			end\n			self.radio_channel = channel\n			self:oncreate()\n		end,\n		render = function(self)\n			if self.active then\n				twins.container.setBackground(self.active_bgcolor)\n				twins.container.setForeground(self.active_fgcolor)\n			else\n				twins.container.setBackground(self.bgcolor)\n				twins.container.setForeground(self.fgcolor)\n			end\n			twins.container.fill(self.x, self.y, self.w, self.h, \" \")\n			twins.draw_frame(self)\n			twins.container.set(self.x+self.w/2-unicode.len(self.text)/2, self.y+self.h/2, self.text)\n		end,\n		oncreate = function(self)\n			twins.radio_channel = twins.radio_channel or {}\n			if twins.radio_channel[self.radio_channel] == nil then\n				twins.radio_channel[self.radio_channel] = {self}\n			else\n				table.insert(twins.radio_channel[self.radio_channel], self)\n			end\n		end,\n		onclick = function(self)\n			local channel = twins.radio_channel[self.radio_channel]\n			for k, v in ipairs(channel) do\n				if v.active then\n					v.active = false\n					v:render()\n				end\n			end\n			self.active = true\n			self:render()\n		end,\n		ondestroy = function(self)\n			local channel = twins.radio_channel[self.radio_channel]\n			for k, v in ipairs(channel) do\n				if v == self then\n					table.remove(channel, k)\n					break\n				end\n			end\n		end\n	},\n	spacing = {\n		visible = false,\n		clickable = false,\n		w = 1, h = 1\n	}\n}\nreturn elem_base",["/lib/twins/core/sps.lua"]="local sps = {}\n\nfunction sps.center(e, mode)\n	local cx = math.floor((twins.scw-e.w)/2)\n	local cy = math.floor((twins.sch-e.h)/2)\n	if mode == \'x\' then\n		e.x = cx\n	elseif mode == \'y\' then\n		e.y = cy\n	else\n		e.x = cx\n		e.y = cy\n	end\n	if e.calculate_positions then\n		e:calculate_positions()\n	end\n	return e, {x=cx, y=cy}\nend\n\nfunction sps.right(e)\n	local rx = twins.scw-e.w-1\n	e.x = rx\n	if e.calculate_positions then\n		e:calculate_positions()\n	end\n	return e, rx\nend\n\nfunction sps.left(e)\n	local lx = 1\n	e.x = lx\n	if e.calculate_positions then\n		e:calculate_positions()\n	end\n	return e, lx\nend\n\nfunction sps.up(e)\n	local uy = 1\n	e.y = uy\n	if e.calculate_positions then\n		e:calculate_positions()\n	end\n	return e, uy\nend\n\nfunction sps.down(e)\n	local dy = twins.sch-e.h\n	e.y = dy\n	if e.calculate_positions then\n		e:calculate_positions()\n	end\n	return e, dy\nend\n\nlocal function pos_list(list, dir, fun)\n	dir = dir or \"down\"\n	if dir == \"down\" then\n		local ly = 1\n		for k, e in pairs(list) do\n			fun(e)\n			e.y = ly\n			ly = ly + e.h\n			if e.calculate_positions then\n				e:calculate_positions()\n			end\n		end\n	else\n		local ly = twins.sch\n		for k, e in pairs(list) do\n			ly = ly - e.h\n			fun(e)\n			e.y = ly\n			if e.calculate_positions then\n				e:calculate_positions()\n			end\n		end\n	end\n	return list\nend\n\nfunction sps.right_list(list, dir)\n	return pos_list(list, dir, sps.right)\nend\n\nfunction sps.left_list(list, dir)\n	return pos_list(list, dir, sps.left)\nend\n\nfunction sps.center_list(list, dir)\n	return pos_list(list, dir, sps.center)\nend\n\nfunction sps.position(attr, e)\n	for fun in attr:gmatch(\"[%w_]+\") do\n		if type(sps[fun]) == \"function\" then sps[fun](e) end\n	end\n	if e.calculate_positions then\n		e:calculate_positions()\n	end\n	return e\nend\n\nreturn sps"}

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
