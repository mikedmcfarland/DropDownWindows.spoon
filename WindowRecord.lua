---@class WindowRecord
--- @field window hs.window
--- @field isFocused boolean
--- @field isToggledDropdown boolean
--- @field config table
--- @field lastFocused number
local WindowRecord = {}
WindowRecord.__index = WindowRecord

---@param window hs.window
---@param isFocused boolean
---@param isToggledDropdown boolean
---@param config table
---@param lastFocused number
---@returns WindowRecord
function WindowRecord:new(window, isFocused, isToggledDropdown, config, lastFocused)
    local record = {}
    setmetatable(record, self)
    self.__index = self

    record.window = window
    record.isFocused = isFocused
    record.isToggledDropdown = isToggledDropdown
    record.config = config
    record.lastFocused = lastFocused
    return record
end

---@return boolean
function WindowRecord:isConfigured()
    return self.config ~= nil
end

---@return boolean
function WindowRecord:isDropdown()
    return self:isConfigured() or self.isToggledDropdown
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

return WindowRecord
