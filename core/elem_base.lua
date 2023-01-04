local unicode = require "unicode"
local event = require "event"
local serialization = require "serialization"
local elem_base = {
	button = {
		x = 1, y = 1,
		w = 10, h = 3,
		bgcolor = 0x222222,
		fgcolor = 0xffffff,
		text = "button",
		render = function(self)
			twins.container.setBackground(self.bgcolor)
			twins.container.setForeground(self.fgcolor)
			twins.container.fill(self.x, self.y, self.w, self.h, " ")
			twins.draw_frame(self)
			twins.container.set(self.x+self.w/2-unicode.len(self.text)/2, self.y+self.h/2, self.text)
		end
	},
	text = {
		x = 1, y = 1,
		h = 1,
		text = "text",
		align = "left",
		fgcolor = 0xffffff,
		bgcolor = 0x000000,
		render = function(self)
			twins.container.setForeground(self.fgcolor)
			twins.container.setBackground(self.bgcolor)
			
			if self.align == "left" then
				local text = unicode.sub(tostring(self.text), 1, self.w)
				text = text .. string.rep(" ", self.w-unicode.len(text))
				twins.container.set(self.x, self.y, text)
			elseif self.align == "center" then

				local rel_x = math.floor(self.w/2-unicode.len(self.text)/2)
				local rel_h = math.floor(self.h/2)
				local left_pad = string.rep(" ", rel_x - 1)
				local right_pad = string.rep(" ", self.w - rel_x - 1)

				local text = left_pad .. self.text .. right_pad

				twins.container.set(self.x, self.y, text)
			elseif self.align == "right" then
				local text = unicode.sub(tostring(self.text), 1, self.w)
				text = string.rep(" ", self.w-unicode.len(text)) .. text
				twins.container.set(self.x, self.y, text)
			end
		end,
		oncreate = function(self)
			self:adjust_width()
		end,
		adjust_width = function(self)
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
			twins.container.set(self.x+1, self.y+1, "  ")
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
		blinker_t = "not_init",
		blinker_state = 0,
		allowed_chars = "",
		text="",
		password=false,
		creation_ctx = -1,
		render = function(self)
			while self.cursor-self.view > self.w-1 do
				self.view = self.view + 1
			end
			if self.cursor-self.view < 0 then
				self.view = self.cursor
			end
			if self.view < 1 then self.view = 1 end
			twins.container.setBackground(self.bgcolor)
			twins.container.setForeground(self.fgcolor)
			twins.container.set(self.x, self.y+self.h-1, string.rep("─", self.w))
			local text = unicode.sub(tostring(self.text), self.view, self.view+self.w-1)

			if self.password then
				text = string.rep("*", unicode.len(text))
			end

			text = text .. string.rep(" ", self.w - unicode.len(text))
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
			self.creation_ctx = twins.active_context
			self.blinker_t = event.timer(0.5, 
				function()
					if twins.active_context == self.creation_ctx then
						self:draw_cursor()
					end
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
				if self.cursor > 1 then
					self.text = unicode.sub(self.text, 1, self.cursor-2) .. unicode.sub(self.text, self.cursor, unicode.len(self.text))
					self.cursor = self.cursor - 1
					if self.cursor < 1 then
						self.cursor = 1
					end
					if self.cursor-self.view < 2 then
						self.view = self.cursor - 2
					end
					self.render(self)
				end
			end,
			[13] =
			function(self, let, key)
				if self.onconfirm then
					self.onconfirm(self)
				end
			end,
			[127] = 
			function(self, let, key)
				self.text = unicode.sub(self.text, 1, self.cursor-1) .. unicode.sub(self.text, self.cursor+1, unicode.len(self.text))
				self.render(self)
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
				twins.container.set(self.x, self.y+line, "..."..(" "):rep(self.w-3))
				line = line + 1
			end
			for k=self.scroll+1, #self.items do
				local i = self.items[k]
				local wspace = (" "):rep(self.w-unicode.len(i))
				if self.selection-self.scroll == line+1 then
					twins.container.setBackground(self.sel_color)
					twins.container.set(self.x, self.y+line, tostring(i)..wspace)
					twins.container.setBackground(self.bgcolor)
				else
					twins.container.set(self.x, self.y+line, tostring(i)..wspace)
				end
				line = line + 1
				if line == self.h then
					twins.container.set(self.x, self.y+line, "..."..(" "):rep(self.w-3))
					return
				end
			end
			local wspace = (" "):rep(self.w)
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
		direction = "horizontal",
		items={},
		padding = {left=0, right=0, up=0, down=0},
		calculate_positions = function(self)
			if self.direction == "horizontal" or self.direction == "h" then
				local dx = self.padding.left
				local h_max = 0
				for k, v in ipairs(self.items) do
					assert(type(v) == "table", "["..k.."] не является элементом.")
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
			elseif self.direction == "vertical" or self.direction == "v" then
				local dy = self.padding.up
				local w_max = 0
				for k, v in ipairs(self.items) do
					assert(type(v) == "table", "["..k.."] не является элементом.")
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
		text = "button",
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
			twins.container.fill(self.x, self.y, self.w, self.h, " ")
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
return elem_base