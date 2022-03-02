-- https://github.com/asmagill/hs._asm.undocumented.spaces
local spaces = require("hs._asm.undocumented.spaces")

local DropDownWindows = {}
DropDownWindows.__index = DropDownWindows

local Windows = {}
Windows.__index = Windows

local WindowRecord = {}
WindowRecord.__index = WindowRecord

local logger = hs.logger.new("DropDownWindows", "error")
DropDownWindows.logger = logger

-- metadata
DropDownWindows.name = "dropDownWindows"
DropDownWindows.version = "0.1"
DropDownWindows.author = "mikedmcfarland <mikedmcfarland@gmail.com>"
DropDownWindows.homepage = "https://github.com/mikedmcfarland/DropDownWindows.spoon"

local FOCUS = "focus"
local DROPDOWN = "dropdown"
local CONFIG = "config"

function DropDownWindows:init()
    logger.d("init")
    return self
end

function DropDownWindows:start(config)
    logger.d("start")

    self:bindAppKeys(config.apps)
    self:bindConfigurableWindowsKeys(config.configurableWindows)

    local actions = {
        [FOCUS] = function(record)
            if record:isDropdown() and not record:isFocused() then
                self:hideWindow(record)
            end
        end,
        [DROPDOWN] = function(record)
            if record:isDropdown() and not record:isFocused() then
                self:showWindow(record)
            end
        end,
        [CONFIG] = function(record)
        end
    }

    self.windows =
        Windows:new(
        hs.window.filter.default,
        function(type, record)
            local action = actions[type]
            if action then
                action(record)
            end
        end
    )

    return self
end

function DropDownWindows:bindAppKeys(mappings)
    local spec = {}
    for key, _ in pairs(mappings) do
        spec[key] = hs.fnutils.partial(self.chooseApp, self, key)
    end
    hs.spoons.bindHotkeysToSpec(spec, mappings)
end

function DropDownWindows:bindConfigurableWindowsKeys(configs)
    local spec = {}
    local mappings = {}
    for i, value in ipairs(configs) do
        spec[i .. "_assign"] = hs.fnutils.partial(self.assignConfigurableWindow, self, i)
        spec[i .. "_select"] = hs.fnutils.partial(self.selectConfigurableWindow, self, i)

        mappings[i .. "_assign"] = value.assign
        mappings[i .. "_select"] = value.select
    end
    hs.spoons.bindHotkeysToSpec(spec, mappings)
end

function DropDownWindows:assignConfigurableWindow(configIndex)
    local frontmost = self.windows.frontmost()

    local alreadyConfiguredAtIndex =
        hs.fnutils.find(
        self.windows.allRecords(),
        function(r)
            return r:config() and r:config().index == configIndex
        end
    )

    local config = {index = configIndex}

    if not alreadyConfiguredAtIndex then
        frontmost.setConfig(config)
        return
    end

    if alreadyConfiguredAtIndex.equals(frontmost) then
        frontmost.setConfig(nil)
        return
    end

    alreadyConfiguredAtIndex:setConfig(nil)
    frontmost.setConfig(config)
end

function DropDownWindows:selectConfigurableWindow(configIndex)
    local selected =
        hs.fnutils.find(
        self.windows.allRecords(),
        function(r)
            return r:config() and r:config().index == configIndex
        end
    )
    if selected then
        self:chooseWindow(selected)
    end
end

function DropDownWindows:stop()
    logger.d("stop")
    self.windowFilter.unsubscribeAll()
    return self
end

function DropDownWindows:bindHotkeys(mapping)
    logger.d("bindingHotkeys")

    local spec = {
        toggleWindow = hs.fnutils.partial(self.toggleWindow, self)
    }

    hs.spoons.bindHotkeysToSpec(spec, mapping)

    return self
end

function DropDownWindows:toggleWindow()
    logger.d("toggleWindow")

    local frontmost = self.windows:frontmost()
    local appName = frontmost:app():name()

    local dropdown =
        hs.fnutils.find(
        self.windows.appRecords(appName),
        function(r)
            return r:isDropdown()
        end
    )

    if not dropdown then
        hs.alert.show("app dropdown enabled")
        frontmost:enableDropdown()
    end

    if dropdown.equals(frontmost) then
        hs.alert.show("app dropdown disabled")
        frontmost:disableDropdown()
    end

    hs.alert.show("switching app dropdown window")
    dropdown:disableDropdown()
    frontmost:enableDropdown()
end

function DropDownWindows:chooseWindow(record)
    if record.isDropdown() then
        if record:isFrontmost() then
            self:hideWindow(record)
        else
            self:showWindow(record)
        end
        return
    else
        self:focusWindow(record)
    end
end

function DropDownWindows:chooseApp(appName)
    local appRecord =
        hs.fnutils.reduce(
        self.windows.appRecords(appName),
        function(a, b)
            if a.lastFocused() > b.lastFocused() then
                return a
            else
                return b
            end
        end
    )

    if appRecord then
        self:chooseWindow(appRecord)
    else
        hs.application.launchOrFocus(appName)
    end
end

function DropDownWindows:hideWindow(record)
    local appName = record:app():name()
    local appRecords = self.windows.appRecords(appName)
    local window = record:window()

    if #appRecords > 1 then
        window:minimize()
    else
        window:application():hide()
    end
end

function DropDownWindows:showWindow(record)
    local space = spaces.activeSpace()
    local mainScreen = hs.screen.find(spaces.mainScreenUUID())

    local scrFrame = mainScreen:fullFrame()

    local newFrame = hs.geometry.copy(scrFrame)
    newFrame:scale(0.8)
    local win = record:window()
    win:setFrame(newFrame, 0)
    win:spacesMoveTo(space)
    win:focus()
end

function WindowRecord:new(window, signalChange)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    local config = nil
    o.config = function()
        return config
    end

    o.setConfig = function(newConfig)
        config = newConfig
        signalChange("config")
    end

    o.window = function()
        return window
    end

    local lastFocused = nil
    o._setLastFocused = function(value)
        lastFocused = value
    end

    o.lastFocused = function()
        return lastFocused
    end

    local isDropdown = false
    o.enableDropdown = function()
        isDropdown = true
        signalChange("dropdown")
    end

    o.disableDropdown = function()
        isDropdown = false
        signalChange()
    end

    o.isDropdown = function()
        return isDropdown or config ~= nil
    end

    local isFocused = false
    o.isFocused = function()
        return isFocused
    end

    o._setIsFocused = function(value)
        local hasChanged = lastFocused ~= value
        isFocused = value
        if hasChanged then
            signalChange("focus")
        end
    end

    return o
end
function WindowRecord:isConfigured()
    return self:config() ~= nil
end

function WindowRecord:equals(other)
    return self:window() == other:window()
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

function Windows:new(windowFilter, onChange)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o._onChange = onChange

    local windowRecordsByApp = {}

    local recordByWindow = function(window)
        local appName = window:application():name()
        windowRecordsByApp[appName] = windowRecordsByApp[appName] or {}
        local appRecords = windowRecordsByApp[appName]
        return hs.fnutils.find(
            appRecords,
            function(r)
                return r:id() == window:id()
            end
        )
    end

    local createRecord = function(window)
        local appName = window:application():name()

        local newRecord = nil
        newRecord =
            WindowRecord:new(
            window,
            function(type)
                onChange(type, newRecord)
            end
        )
        local id = window:id()
        windowRecordsByApp[appName][id] = newRecord
        return newRecord
    end

    local ensureRecord = function(window)
        local existingRecord = recordByWindow(window)
        if existingRecord then
            return existingRecord
        else
            return createRecord(window)
        end
    end

    local removeRecord = function(window, appName)
        local id = window:id()

        windowRecordsByApp[appName][id] = nil
    end

    o.frontmost = function()
        return ensureRecord(hs.window.frontmostWindow())
    end

    local appRecords = function(appName)
        windowRecordsByApp[appName] = windowRecordsByApp[appName] or {}
        return windowRecordsByApp[appName]
    end

    o.appRecords = appRecords

    o.allRecords = function()
        local results = {}
        for _, v in pairs(windowRecordsByApp) do
            for _, r in pairs(v) do
                table.insert(results, 1, r)
            end
        end

        return results
    end

    o.windowFilter =
        windowFilter:subscribe(
        {
            [hs.window.filter.windowCreated] = function(window)
                ensureRecord(window)
            end,
            [hs.window.filter.windowFocused] = function(window)
                local record = ensureRecord(window)
                local now = hs.timer.absoluteTime()
                record._setLastFocused(now)
                record._setIsFocused(true)
            end,
            [hs.window.filter.windowDestroyed] = function(window, appName)
                removeRecord(window, appName)
            end,
            [hs.window.filter.windowUnfocused] = function(window)
                local record = ensureRecord(window)
                record._setIsFocused(false)
            end
        }
    )

    return o
end

return DropDownWindows
