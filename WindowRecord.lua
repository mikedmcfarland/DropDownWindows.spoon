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

---@param other WindowRecord | hs.window | nil
---@return boolean
function WindowRecord:equals(other)
    if other == nil then
        return false
    end

    return self.window:id() == other:id()
end

---@return hs.application|nil
function WindowRecord:app()
    local _, application =
        pcall(
        function()
            return self.window:application()
        end
    )
    return application
end

---@param other WindowRecord
---@return boolean
function WindowRecord:samePid(other)
    local _, result =
        pcall(
        function()
            local selfPid = self.window:application():pid()
            local otherPid = other.window:application():pid()
            return selfPid == otherPid
        end
    )
    return result
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
