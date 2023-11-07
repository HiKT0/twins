local api = {}

function api.clear_screen(color)
  twins.container.setForeground(twins.sem.document.fgcolor or 0xffffff)
  twins.container.setBackground(color or twins.sem.document.bgcolor or 0x000000)
  twins.container.fill(1, 1, twins.sem.scw, twins.sem.sch, " ")
end

function api.draw_frame(elem)
  local vl = ("│"):rep(elem.h-2)
  local hl = ("─"):rep(elem.w-2)

  twins.container.set(elem.x, elem.y, "┌"..vl.."└", true)
  twins.container.set(elem.x+elem.w-1, elem.y, "┐"..vl.."┘", true)
  twins.container.set(elem.x+1, elem.y, hl)
  twins.container.set(elem.x+1, elem.y+elem.h-1, hl)
end

return api