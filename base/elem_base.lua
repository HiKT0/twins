local unicode = require "unicode"
local event = require "event"
local elem_base = {
	button = {
		x = 1, y = 1,
		w = 10, h = 3,
		bgcolor = 0x222222,
		fgcolor = 0xffffff,
		text = "button",
		render = function(v)
			twins.container.setBackground(v.bgcolor)
			twins.container.setForeground(v.fgcolor)
			twins.container.fill(v.x, v.y, v.w, v.h, " ")
			twins.draw_frame(v)
			twins.container.set(v.x+v.w/2-unicode.len(v.text)/2, v.y+v.h/2, v.text)
			twins.container.setBackground(0x000000)
		end
	},
	text = {
		x = 1, y = 1,
		w = 10, h = 1,
		text = "text",
		fgcolor = 0xffffff,
		render = function(v)
			twins.container.setForeground(v.fgcolor)
			local text = unicode.sub(tostring(v.text), 1, v.w)
			text = text .. string.rep(" ", v.w-unicode.len(text))
			twins.container.set(v.x, v.y, text)
		end
	},
	checkbox = {
		x = 1, y = 1,
		w = 4, h = 3,
		active_color = 0x00ff48,
		active = false,
		bgcolor = 0x000000,
		render = function(v)
			twins.container.setBackground(v.bgcolor)
			twins.draw_frame(v)
			if v.active then 
				twins.container.setBackground(v.active_color)
			end
			twins.container.set(v.x+1, v.y+1, "  ")
		end,
		onclick = function(v)
			v.active = not v.active
			v.render(v)
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
		render = function(v)
			while v.cursor-v.view > v.w-1 do
				v.view = v.view + 1
			end
			while v.cursor-v.view < 0 do
				v.view = v.view - 1
			end
			if v.view < 1 then v.view = 1 end
			twins.container.setBackground(v.bgcolor)
			twins.container.setForeground(v.fgcolor)
			twins.container.set(v.x, v.y+v.h-1, string.rep("─", v.w))
			local text = unicode.sub(tostring(v.text), v.view, v.view+v.w-1)

			if v.password then
				text = string.rep("*", unicode.len(text))
			end

			text = text .. string.rep(" ", v.w - unicode.len(text))
			twins.container.set(v.x, v.y, text)
		end,
		draw_cursor = function(v)
			v.blinker_state = (v.blinker_state + 1) % 2
			local glob_cur_pos = v.cursor-v.view+v.x

			if v.blinker_state == 0 then
				local cur_char = twins.container.get(glob_cur_pos, v.y)
				twins.container.setBackground(v.bgcolor)
				twins.container.setForeground(v.fgcolor)
				twins.container.set(glob_cur_pos, v.y, cur_char)
			else
				if twins.focus == v._id then
					local cur_char = twins.container.get(glob_cur_pos, v.y)
					twins.container.setBackground(v.fgcolor)
					twins.container.setForeground(v.bgcolor)
					twins.container.set(glob_cur_pos, v.y, cur_char)
				end
			end
		end,
		onclick = function(v)
			if v.cursor > unicode.len(v.text) + 1 then
				v.cursor = unicode.len(v.text) + 1
			end
			if v.cursor < 1 then
				v.cursor = 1
			end
			v.draw_cursor(v) 
		end,
		oncreate = function(v)
			v.blinker_t = event.timer(0.5, 
				function()
					v.draw_cursor(v)
				end,
				math.huge)
		end,
		ondestroy = function(v)
			event.cancel(v.blinker_t)
		end,
		ovr_lets = {
			[8] = 
			function(v, let, key)
				v.text = unicode.sub(v.text, 1, v.cursor-2) .. unicode.sub(v.text, v.cursor, unicode.len(v.text))
				v.cursor = v.cursor - 1
				while v.cursor-v.view < 1 do
					v.view = v.view - 1
				end
				v.render(v)
			end
		},
		ovr_keys = {
			[203] =
			function(v, let, key)
				v.cursor = v.cursor - 1
				if v.cursor < 1 then
					v.cursor = 1
				end
				v.render(v)
			end,
			[205] =
			function(v, let, key)
				v.cursor = v.cursor + 1
				if v.cursor > unicode.len(v.text) + 1 then
					v.cursor = unicode.len(v.text) + 1
				end
				v.render(v)
			end
		},
		onmodify = function(v) end,
		typechar = function(v, let, key)
			v.text = (unicode.sub(v.text, 1, v.cursor-1) ..
				unicode.char(let) .. 
				unicode.sub(v.text, v.cursor, unicode.len(v.text))
				)
			v.cursor = v.cursor + 1
			v.render(v)

			if v.onmodify then v.onmodify(v) end
		end,
		onkeydown = function(v, let, key)
			if v.ovr_lets[let] then
				v.ovr_lets[let](v, let, key)
				if v.onmodify then v.onmodify(v) end
			elseif v.ovr_keys[key] then
				v.ovr_keys[key](v, let, key)
				if v.onmodify then v.onmodify(v) end
			else
				if let > 31 then
					if v.allowed_chars:len() == 0 or v.allowed_chars:find(string.char(let)) then
						v.typechar(v, let, key)
					end
				end
			end
			if v.cursor < 1 then v.cursor = 1 end
			v.blinker_state = 0
			v.draw_cursor(v)
		end
	},
	frame = {
		x = 1, y = 1,
		w = 10, h = 10,
		bgcolor = 0x000000,
		fgcolor = 0xffffff,
		render = function(v)
			twins.container.setBackground(v.bgcolor)
			twins.container.setForeground(v.fgcolor)
			twins.draw_frame(v)
		end
	}
}
return elem_base