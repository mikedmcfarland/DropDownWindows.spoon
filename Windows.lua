--- @class Windows
--- @field private _toggledDropdowns table<string,table>
--- @field private _configuredDropdowns table<string,table>
--- @field private _windowLastFocusedAt table<string,number>
--- @field private _windows hs.window[]
--- @field private _onChange fun(event:WindowsFocusEvent)
local Windows = {}
Windows.__index = Windows

--- @class WindowsFocusEvent
--- @field focus WindowRecord
--- @field previousFocus WindowRecord|nil
local WindowsFocusEvent = {}
WindowsFocusEvent.__index = WindowsFocusEvent

---@param focus WindowRecord
---@param previousFocus WindowRecord|nil
---@return WindowsFocusEvent
function WindowsFocusEvent:new(focus, previousFocus)
    local e = {}
    self.__index = self
    setmetatable(e, self)
    e.focus = focus
    e.previousFocus = previousFocus
    return e
end

local logger = hs.logger.new("Windows", "error")
Windows.logger = logger

---@type WindowRecord
local WindowRecord = dofile(hs.spoons.resourcePath("WindowRecord.lua"))

---@param windowFilter hs.window.filter
---@param onChange fun(event:WindowsFocusEvent)
---@returns Windows
function Windows:new(windowFilter, onChange)
    local o = {}
    self.__index = self
    setmetatable(o, self)
    o._onChange = onChange
    o._windows = {}
    o._focus = nil
    o._previousFocus = nil
    o._configuredDropdowns = {}
    o._toggledDropdowns = {}
    o._windowLastFocusedAt = {}

    local updateFocus = function()
        --using frontmost window because the window from the event is sometimes unexpected
        local frontmost = hs.window.frontmostWindow()

        local record = o:_ensureRecord(frontmost)
        o:_makeTheFocus(record)
    end

    o.windowFilter =
        windowFilter:subscribe(
        {
            [hs.window.filter.windowCreated] = function(window)
                o:_ensureRecord(window)
            end,
            [hs.window.filter.windowFocused] = function(_)
                updateFocus()
            end,
            [hs.window.filter.windowDestroyed] = function(window)
                o:_removeRecord(window)
            end,
            -- sometimes windows don't trigger a focus after being focused after minimizing
            -- this is the only event I could find that was triggered in those cases
            [hs.window.filter.windowVisible] = function(_)
                updateFocus()
            end,
            [hs.window.filter.windowUnfocused] = function(_)
                updateFocus()
            end
        }
    )

    return o
end

---@param id number
---@return WindowRecord | nil
function Windows:recordById(id)
    return hs.fnutils.find(
        self:allRecords(),
        function(r)
            return r:id() == id
        end
    )
end

--@param window hs.window
--@return WindowRecord
function Windows:_createRecord(window)
    local id = window:id()
    local isFocused = self._focus and self._focus:equals(window)
    local toggle = self._toggledDropdowns[id]
    local config = self._configuredDropdowns[id]
    local lastFocused = self._windowLastFocusedAt[id]
    local record = WindowRecord:new(window, isFocused, toggle, config, lastFocused)
    return record
end

function Windows:_ensureRecord(window)
    local existingRecord = self:recordById(window:id())
    if existingRecord then
        return existingRecord
    else
        table.insert(self._windows, 1, window)
        local record = self:_createRecord(window)
        return record
    end
end

function Windows:_removeRecord(window)
    local id = window:id()
    for i, r in ipairs(self._windows) do
        if r:id() == id then
            table.remove(self._windows, i)
        end
    end

    self._toggledDropdowns[id] = nil
    self._configuredDropdowns[id] = nil
    self._windowLastFocusedAt[id] = nil
end

---@param appName string
---@return WindowRecord[]
function Windows:appRecords(appName)
    local records = {}
    for _, r in ipairs(self:allRecords()) do
        if r:app():name() == appName then
            table.insert(records, 1, r)
        end
    end
    return records
end

---@return WindowRecord | nil
function Windows:previousFocus()
    return self._previousFocus
end

---@return WindowRecord
function Windows:frontmost()
    return self:_ensureRecord(hs.window.frontmostWindow())
end

function Windows:_makeTheFocus(record)
    local now = hs.timer.absoluteTime()
    self._windowLastFocusedAt[record:id()] = now

    if self._focus == nil or self._focus:equals(record) then
        self._previousFocus = self._focus
        self._focus = record

        local event = WindowsFocusEvent.new(self._focus, self._previousFocus)
        self._onChange(event)
    end
end

function Windows:_cleanupWindows()
    self._windows =
        hs.fnutils.ifilter(
        self._windows,
        function(win)
            -- local windowExists = pcall( function() return v.app() end )
            return win:application() ~= nil
        end
    )
end

--@return WindowRecord[]
function Windows:allRecords()
    self:_cleanupWindows()
    local records = {}
    for index, win in ipairs(self._windows) do
        local record = self:_createRecord(win)
        table.insert(records, index, record)
    end
    return records
end

--@param windowId number
--@param config table
function Windows:setConfig(windowId, config)
    self._configuredDropdowns[windowId] = config
end

--@param id number
function Windows:enableDropdown(id)
    self._toggledDropdowns[id] = {}
end

--@param id number
function Windows:disableDropdown(id)
    self._toggledDropdowns[id] = nil
end

return Windows
