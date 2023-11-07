local sem = require("twins.core.sem")
local util = require("twins.core.util")

local api = {}

local function apply_class(element, classname)
  local class_props = sem.element_templates[classname]
  for k, v in pairs(class_props) do
    if not element[k] then element[k] = util.deep_copy(v) end
  end
end

function api.add_template(name, template, parent)
  if not parent then parent = "*" end
  if type(twins.sem.element_templates[parent]) == "table" then
    for k, v in pairs(twins.sem.element_templates[parent]) do
      if template[k] == nil then template[k] = util.deep_copy(v) end
    end
  end
  twins.element_templates[name] = template
end

function api.build_element(element, template)
  if element.class ~= nil and sem.element_templates[element.class] then
    apply_class(element, element.class)
  elseif sem.element_templates["*"] then
    apply_class(element, "*")
  end

  for k, v in pairs(template) do
    if not element[k] then element[k] = util.deep_copy(v) end
  end

  local prepared_element = sem.add_element(element)
  if element.key ~= nil then
    assert(
      sem.named_elements[prepared_element.key] == nil, 
      "Ошибка при создании элемента с ключом: \""..prepared_element.key .. "\" уже существует"
    )
    sem.named_elements[prepared_element.key] = prepared_element
  end
  prepared_element.render = wrapped_render
  prepared_element._covered_by = {}
  return prepared_element
end

function api.clear_elements()
  twins.sem.elements = {}
  twins.sem.named_elements = {}
end

return api