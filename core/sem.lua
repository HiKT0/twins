local sem = {}

sem.document = nil

sem.elements = nil
sem.named_elements = nil
sem.focus = -1
sem.element_templates = nil

sem.contexts = {}
sem.active_context = 1

function sem.invoke(element, method, ...)
  if not element then
    error(debug.traceback())
  end
  if type(element[method]) == "function" then
    element[method](element, ...)
  end
end

function sem.add_element(element)
  for i=1, #sem.elements+1 do
    if sem.elements[i] == nil then
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
      sem.elements[i] = element
      sem.elements[i]._id = i
      if sem.elements[i].clickable == nil then sem.elements[i].clickable = true end
      if sem.elements[i].visible == nil then sem.elements[i].visible = true end
      sem.invoke(sem.elements[i], "oncreate")
      return sem.elements[i]
    end
  end
end

function sem.get_element_by_key(key)
  return sem.named_elements[key]
end

function sem.get_focus()
  return twins.sem.elements[twins.sem.focus]
end

local function intersects(a, b)
  return (a.x < (b.x + b.w))
     and (b.x < (a.x + a.w))
     and (a.y < (b.y + b.h))
     and (b.y < (a.y + a.h))
end

local function findCoverage(element, output)
  for k, v in pairs(element._covered_by) do
    output[v] = true
    findCoverage(v, output)
  end
end

function sem.render(force)
  if type(force) == "table" then
    local affected = {}
    for k, v in pairs(twins.sem.elements) do
      
    end
  else
    twins.clear_screen()
    for k, v in pairs(twins.sem.elements) do
      if rawget(v, "changed") or force then
        twins.sem.invoke(v, "render", true)
        rawset(v, "changed", false)
      end
    end
    twins.container.render()
  end
  if twins.sem.document.title then twins.title(twins.sem.document.title) end
end

function sem.title(title)
  twins.container.set(3, 1, "["..title.."]")
end

return sem