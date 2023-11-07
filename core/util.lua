local util = {}

function util.deep_copy(t)
  if type(t) ~= "table" then
    return t
  end

  local new_t = {}
  for k, v in pairs(t) do
    new_t[k] = util.deep_copy(v)
  end
  return new_t
end



return util