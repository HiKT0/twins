local sps = {}

function sps.center(e, mode)
	local cx = (twins.scw-e.w)/2
	local cy = (twins.sch-e.h)/2
	if mode == 'x' then
		e.x = cx
	elseif mode == 'y' then
		e.y = cy
	else
		e.x = cx
		e.y = cy
	end
	return e, {x=cx, y=cy}
end

function sps.right(e)
	local rx = twins.scw-e.w
	e.x = rx
	return e, rx
end

function sps.left(e)
	local lx = 1
	e.x = lx
	return e, lx
end

function sps.up(e)
	local uy = 1
	e.y = uy
	return e, uy
end

function sps.down(e)
	local dy = twins.sch-e.h
	e.y = dy
	return e, dy
end

local function pos_list(list, dir, fun)
	dir = dir or "down"
	if dir == "down" then
		local ly = 1
		for k, e in pairs(list) do
			fun(e)
			e.y = ly
			ly = ly + e.h
		end
	else
		local ly = twins.sch
		for k, e in pairs(list) do
			ly = ly - e.h
			fun(e)
			e.y = ly
		end
	end
	return list
end

function sps.right_list(list, dir)
	pos_list(list, dir, sps.right)
end

function sps.left_list(list, dir)
	pos_list(list, dir, sps.left)
end

function sps.position(attr, e)
	for fun in attr:gmatch("[%w_]+") do
		if type(sps[fun]) == "function" then sps[fun](e) end
	end
end

return sps