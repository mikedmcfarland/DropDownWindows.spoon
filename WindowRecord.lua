---@class WindowRecord
--- @field window hs.window
--- @field isFocused boolean
--- @field toggle table
--- @field config table
--- @field lastFocused number
local WindowRecord = {}
WindowRecord.__index = WindowRecord

---@param window hs.window
---@param isFocused boolean
---@param toggle table
---@param config table
---@param lastFocused number
---@returns WindowRecord
function WindowRecord:new(window, isFocused, toggle, config, lastFocused)
    local record = {}
    setmetatable(record, self)
    self.__index = self

    record.window = window
    record.isFocused = isFocused
    record.toggle = toggle
    record.config = config
    record.lastFocused = lastFocused
    return record
end

---@param index number
---@return boolean
function WindowRecord:configuredAtIndex(index)
    return self.config and self.config.index == index
end

---@return boolean
function WindowRecord:isConfigured()
    return self.config ~= nil
end

---@return boolean
function WindowRecord:isToggled()
    return self.toggle ~= nil
end

---@return boolean
function WindowRecord:isDropdown()
    return self:isConfigured() or self:isToggled()
end

---@param other WindowRecord | hs.window
---@return boolean
function WindowRecord:equals(other)
    return self.window:id() == other:id()
end

---@return hs.application
function WindowRecord:app()
    return self.window:application()
end

---@return number
function WindowRecord:id()
    return self.window:id()
end

---@return boolean
function WindowRecord:isFrontmost()
    return hs.window.frontmostWindow():id() == self:id()
end

function WindowRecord:__tostring()
    local repr = {
        window = self:app():name() .. ":" .. self.window:id(),
        isFocused = self.isFocused,
        toggle = self.toggle,
        config = self.config,
        lastFocused = self.lastFocused
    }
    return hs.json.encode(repr, true)
end

return WindowRecord
