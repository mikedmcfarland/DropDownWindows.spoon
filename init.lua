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

function DropDownWindows:init()
    logger.d("init")
    return self
end

function DropDownWindows:start(config)
    logger.d("start")

    self:bindAppKeys(config.apps)
    self:bindConfigurableWindowsKeys(config.configurableWindows)
    self.windows =
        Windows:new(
        hs.window.filter.default,
        function(record)
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
    local frontmost = self.windows.frontmostWindow()

    local alreadyConfiguredAtIndex =
        hs.fnutils.find(
        self.windows:allRecords(),
        function(r)
            return r:config() and r:config().index == configIndex
        end
    )

    local config = {index = configIndex}

    if not alreadyConfiguredAtIndex then
        frontmost:setConfig(config)
    end

    if alreadyConfiguredAtIndex.isEqual(frontmost) then
        frontmost:setConfig(nil)
    end

    alreadyConfiguredAtIndex:setConfig(nil)
    frontmost:setConfig(config)
end

function DropDownWindows:selectConfigurableWindow(configIndex)
    local selected =
        hs.fnutils.find(
        self.windows:allRecords(),
        function(r)
            return r:config() and r:config().index == configIndex
        end
    )
    self:chooseWindow(selected)
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

    local dropdown =
        hs.fnutils.find(
        self.windows:appRecords(frontmost:app():name()),
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
    if record.isDropDown() then
        if record.isFrontmost() then
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
        self.windowRecords(appName),
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
    local appRecords = self.windowRecords(record.appName())
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

function WindowRecord:new(window, notifyChange)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    local config = nil
    o.config = function()
        return config
    end

    o.setConfig = function(newConfig)
        config = newConfig
        notifyChange()
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
        notifyChange()
    end

    o.disableDropdown = function()
        isDropdown = false
        notifyChange()
    end

    o.isDropdown = function()
        return isDropdown
    end

    local isFocused = false
    o.isFocused = function()
        return isFocused
    end

    o._setIsFocused = function(value)
        isFocused = value
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
    return self:window():app()
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
            function()
                onChange(newRecord)
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

    local removeRecord = function(window)
        local id = window:id()
        local appName = window:application():name()

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
        return hs.fnutils.reduce(
            appRecords,
            function(a, b)
                return hs.fnutils.concat(a, b)
            end
        )
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
                onChange(record)
            end,
            [hs.window.filter.windowDestroyed] = function(window)
                removeRecord(window)
            end,
            [hs.window.filter.windowUnfocused] = function(window)
                logger.i("window", window)
                local record = ensureRecord(window)
                record._setIsFocused(false)
                onChange(record)
            end
        }
    )

    return o
end

return DropDownWindows
