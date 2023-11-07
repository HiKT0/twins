twins = {}

setmetatable(twins, {
  __index = function(self, index)
    return twins.sem[index]
  end
})

local event = require("event")
local util = require("twins.core.util")
local computer = require("computer")
local renderDevice = require("twins.core.render_device")

twins.container = renderDevice.getDefault()

twins.sps = require("twins.core.sps")
twins.sem = require("twins.core.sem")
local elements_helper = require("twins.core.elements_helper")
local graphics_helper = require("twins.core.graphics_helper")

twins.sem.scw, twins.sem.sch = twins.container.getResolution()

function twins.wake()
  twins.sem.scw, twins.sem.sch = twins.container.getResolution()
end

twins.get_element_by_key = twins.sem.get_element_by_key

function twins.set_context(context_id, silent)
  if twins.sem.contexts[context_id] == nil then
    twins.sem.contexts[context_id] = {
      document={},
      elements={},
      named_elements={},
      element_templates={},
      focus=-1
    }
  end

  local ctx = twins.sem.contexts[context_id]
  twins.sem.document = ctx.document
  twins.sem.elements = ctx.elements
  twins.sem.named_elements = ctx.named_elements
  twins.sem.focus = ctx.focus
  twins.sem.element_templates = ctx.element_templates

  twins.sem.active_context = context_id
end

function twins.show_context(context_id)
  twins.sem.invoke(twins.sem.document, "onctxinactive")
  twins.set_context(context_id)
  twins.sem.invoke(twins.sem.document, "onctxactive")
  twins.render(true)
end

twins.set_context(twins.sem.active_context)


twins.get_focus = twins.sem.get_focus
twins.render = twins.sem.render
twins.title = twins.sem.title
twins.draw_frame = graphics_helper.draw_frame
twins.clear_screen = graphics_helper.clear_screen
twins.add_template = elements_helper.add_template

local function load_from_file(module_name, load_only)
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
  return mod
end

function twins.load_elements(module_name, load_as, load_only)
  local mod
  local mod_type = type(module_name)
  if mod_type == "string" then
    mod = load_from_file(module_name, load_only)
  elseif mod_type == "table" then
    mod = module_name
  else
    error("Аргумент типа " .. mod_type .. " не поддерживается")
  end

  twins[load_as] = {}
  for elem_name, elem_content in pairs(mod) do
    if elem_content.render then
      local _render = elem_content.render
      local function wrapped_render(self, no_update)
        if sem.running then
          _render(self)
        end
        if not no_update then
          twins.container.render()
        end
      end
    end
    twins[load_as][elem_name] = 
    function(t)
      t = t or {}
      return elements_helper.build_element(t, elem_content)
    end
  end
end

local function touch_listener(e_name, addr, x, y, button)
  local offx, offy = 0, 0

  for k, v in pairs(twins.sem.elements) do
    local ex, ey, ew, eh = v.getxywh(v)
    if x-offx >= ex and x-offx < ex + ew and y-offy >= ey and y-offy < ey + eh and v.clickable then
      if v.visible and twins.sem.focus ~= k then
        local foc_elem = twins.get_focus()
        if foc_elem then
          twins.sem.invoke(foc_elem, "onfocus", x-v.x, y-v.y)
        end

        twins.sem.focus = k
        twins.sem.invoke(twins.get_focus(), "onfocusloss")
      end
      twins.sem.invoke(v, "onclick", {x=x, y=y}, {x=x-v.x, y=y-v.y}, button)
    end
  end
end

local function key_down_listener(e_name, addr, letter, key)
  local focus = twins.get_focus()
  twins.sem.invoke(twins.sem.document, "onkeydown", letter, key)
  if focus then
    if focus.visible then
      twins.sem.invoke(focus, "onkeydown", letter, key)
    end
  end
end

local function scroll_listener(e_name, addr, x, y, size)
  local offx, offy = 0, 0
  if twins.container.type == "tornado_vs" then
    offx = twins.container.internal.x
    offy = twins.container.internal.y
  end
  for k, v in pairs(twins.sem.elements) do
    local ex, ey, ew, eh = v.getxywh(v)
    if x-offx >= ex and x-offx < ex + ew and y-offy >= ey and y-offy < ey + eh then
      twins.sem.invoke(v, "onscroll", {x=x, y=y}, {x=x-v.x, y=y-v.y}, size)
    end
  end
end


twins.load_elements("/lib/twins/core/elem_base.lua", "base", true)


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

local function shutdown_sequence()
  for ctx_id, ctx in pairs(twins.sem.contexts) do
    twins.set_context(ctx_id)
    for k, v in pairs(twins.sem.elements) do
      twins.sem.invoke(v, "ondestroy")
      twins.sem.elements[k] = nil
    end
    twins.sem.element_templates = {}
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
  twins.set_context(1)
  local init_bg = twins.container.getBackground()
  local init_fg = twins.container.getForeground()
  twins.running = true
  twins.connect_listeners()
  local succ = xpcall(function()
    twins.clear_screen()
    twins.render()
    while twins.running do
      twins.sleep(math.huge)
      if not twins.running then break end
    end
  end, function(...) err = debug.traceback(...) end)
  twins.disconnect_listeners()
  shutdown_sequence()
  twins.container.setForeground(init_fg)
  twins.container.setBackground(init_bg)

  for k, v in pairs(twins.sem.contexts) do
    twins.set_context(k)
    elements_helper.clear_elements()
  end
  twins.sem.contexts = {}
  twins.set_context(1)

  if not succ then error(err, 3) end
end

function twins.main_coroutine()
  twins.set_context(1)
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
  twins.clear_screen(twins.sem.document.destroy_color)
  shutdown_sequence()
  twins.container.setForeground(init_fg)
  twins.container.setBackground(init_bg)

  for k, v in pairs(twins.sem.contexts) do
    twins.set_context(k)
    elements_helper.clear_elements()
  end
  twins.sem.contexts = {}
  twins.set_context(1)

  if not succ then error(err, 3) end
end

return twins
