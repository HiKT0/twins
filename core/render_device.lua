local component = require("component")

local renderDevice = {}

function renderDevice.getDefault()
  local gpu = component.gpu
  return {
    set = gpu.set,
    fill = gpu.fill,
    render = function() end,
    setBackground = gpu.setBackground,
    setForeground = gpu.setForeground,
    getBackground = gpu.getBackground,
    getForeground = gpu.getForeground,
    setResolution = gpu.setResolution,
    getResolution = gpu.getResolution,
    get = gpu.get
  }
end

return renderDevice