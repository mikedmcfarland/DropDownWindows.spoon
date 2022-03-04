local Windows = {}
Windows.__index = Windows

local WindowRecord = {}
WindowRecord.__index = WindowRecord

local logger = hs.logger.new("Windows", "error")
Windows.logger = logger

function Windows:new(windowFilter, onChange)
    local o = {}
    self.__index = self
    setmetatable(o, self)
    o._onChange = onChange
    o._windows = {}
    o._focus = nil
    o._previousFocus = nil

    o.windowFilter =
        windowFilter:subscribe(
        {
            [hs.window.filter.windowCreated] = function(window)
                o:_ensureRecord(window)
            end,
            [hs.window.filter.windowFocused] = function(window)
                --frontmost window is more accurate, sometimes this parameter is just wrong and is the same app but different window
                local frontmost = hs.window.frontmostWindow()

                if frontmost:id() ~= window:id() or frontmost:application():pid() ~= window:application():pid() then
                    logger.i("windowFocused", "frontmost differs from window")
                end

                local record = o:_ensureRecord(frontmost)
                -- local record = ensureRecord(window)
                o:_makeTheFocus(record)
            end,
            [hs.window.filter.windowDestroyed] = function(window)
                o:_removeRecord(window)
            end,
            -- sometimes windows don't trigger a focus after being focused after minimizing
            -- this is the only event I could find that was triggered in those cases
            [hs.window.filter.windowVisible] = function(window)
                local frontmost = hs.window.frontmostWindow()
                if frontmost:id() ~= window:id() or frontmost:application():pid() ~= window:application():pid() then
                    logger.i("windowVisible", "frontmost differs from window")
                end

                local record = o:_ensureRecord(frontmost)
                -- local record = ensureRecord(window)
                o:_makeTheFocus(record)
            end
            -- ,
            -- [hs.window.filter.windowUnfocused] = function(window)
            --     -- logger.i("windowUnfocused", window:application():name(), window:id())
            --     local record = ensureRecord(window)
            --     record._setIsFocused(false)
            --     -- logger.i("\n-----\n")
            -- end
        }
    )

    return o
end

function Windows:recordByWindow(window)
    return hs.fnutils.find(
        self:allRecords(),
        function(r)
            return r:id() == window:id()
        end
    )
end

function Windows:_createRecord(window)
    local newRecord = nil
    newRecord =
        WindowRecord:new(
        window,
        function(type)
            self._onChange(type, newRecord)
        end
    )
    table.insert(self._windows, 1, newRecord)
    return newRecord
end

function Windows:isFocused(record)
    if self._focus == nil then
        return false
    end

    return record:equals(focus)
end

function Windows:_ensureRecord(window)
    local existingRecord = self:recordByWindow(window)
    if existingRecord then
        return existingRecord
    else
        return self:_createRecord(window)
    end
end

function Windows:_removeRecord(window)
    for i, r in ipairs(self._windows) do
        if r:id() == window:id() then
            table.remove(self._windows, i)
        end
    end
end

function Windows:appRecords(appName)
    local records = {}
    for _, r in ipairs(self:allRecords()) do
        if r:app():name() == appName then
            table.insert(records, 1, r)
        end
    end
    return records
end
function Windows:previousFocus()
    return self._previousFocus
end

function Windows:frontmost()
    return self:_ensureRecord(hs.window.frontmostWindow())
end

function Windows:_makeTheFocus(record)
    -- logger.i("makeTheFocus", record:app():name())
    local now = hs.timer.absoluteTime()
    record._setLastFocused(now)

    if self._focus == nil or self._focus:equals(record) then
        self._previousFocus = self._focus
        self._focus = record
        self._onChange(FOCUS, self._focus)
    end
end

function Windows:allRecords()
    self._windows =
        hs.fnutils.ifilter(
        self._windows,
        function(win)
            -- local windowExists = pcall( function() return v.app() end )
            return win:app() ~= nil
        end
    )
    return self._windows
end

function WindowRecord:new(window, signalChange)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    local config = {index = nil}
    o.config = function()
        return config
    end

    o.setConfig = function(index)
        config.index = index
        signalChange(CONFIG)
    end

    o.window = function()
        return window
    end

    local lastFocused = 0
    o._setLastFocused = function(value)
        lastFocused = value
    end

    o.lastFocused = function()
        return lastFocused
    end

    local isDropdown = false
    o.enableDropdown = function()
        isDropdown = true
        signalChange(DROPDOWN)
    end

    o.disableDropdown = function()
        isDropdown = false
        signalChange(DROPDOWN)
    end

    o.isDropdown = function()
        return isDropdown or config.index ~= nil
    end

    return o
end
function WindowRecord:isConfigured()
    return self:config().index ~= nil
end

function WindowRecord:equals(other)
    -- return self.window():id() == other.window():id() and self:app():pid() == self:app():pid()
    return self.window():id() == other.window():id()
end

function WindowRecord:app()
    return self:window():application()
end

function WindowRecord:id()
    return self:window():id()
end

function WindowRecord:isFrontmost()
    return hs.window.frontmostWindow():id() == self:id()
end

function WindowRecord:__tostring()
    local result = {
        id = self:id(),
        isConfigured = self:isConfigured(),
        app = self:app():name(),
        isDropdown = self.isDropdown(),
        -- isFocused = self.isFocused(),
        title = self.window():title()
    }

    return hs.json.encode(result, true)
end

return Windows
