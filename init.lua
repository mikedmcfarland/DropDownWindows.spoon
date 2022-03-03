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
            if record:isDropdown() then
                self:showWindow(record)
            end
        end,
        [CONFIG] = function(record)
            if record:isConfigured() then
                self:showWindow(record)
            end
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

    local alreadyConfiguredRecord =
        hs.fnutils.find(
        self.windows.allRecords(),
        function(r)
            return r:config() and r:config().index == configIndex
        end
    )

    local config = {index = configIndex}

    if not alreadyConfiguredRecord then
        hs.alert.show("configured dropdown")
        frontmost.setConfig(config)
        return
    end

    if alreadyConfiguredRecord:equals(frontmost) then
        hs.alert.show("unset configured dropdown")
        frontmost.setConfig(nil)
        return
    end

    hs.alert.show("switch configured dropdown")
    alreadyConfiguredRecord:setConfig(nil)
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
    elseif dropdown:equals(frontmost) then
        hs.alert.show("app dropdown disabled")
        frontmost:disableDropdown()
    else
        hs.alert.show("switching app dropdown window")
        dropdown:disableDropdown()
        frontmost:enableDropdown()
    end
end

function DropDownWindows:chooseWindow(record)
    logger.i("chooseWindow", "isDropdown", record.isDropdown(), "isFrontmost", record:isFrontmost())
    if record.isDropdown() then
        if record:isFrontmost() then
            self:hideWindow(record)
        else
            self:showWindow(record)
        end
        return
    else
        record.window():focus()
    end
end

function DropDownWindows:chooseApp(appName)
    local choice = nil
    for _, r in pairs(self.windows.appRecords(appName)) do
        local rFocusedMoreRecently = (not choice or choice.lastFocused() < r.lastFocused())
        if r:isDropdown() and not r:isConfigured() then
            choice = r
        elseif not r:isConfigured() and rFocusedMoreRecently then
            choice = r
        end
    end

    logger.i("appRecord", choice)

    if choice then
        self:chooseWindow(choice)
    else
        hs.application.launchOrFocus(appName)
    end
end

function DropDownWindows:hideWindow(record)
    local appName = record:app():name()
    local appRecords = self.windows.appRecords(appName)
    local window = record:window()

    local visibleAppWindowCount = 0
    for _, r in pairs(appRecords) do
        if r.window():isVisible() then
            visibleAppWindowCount = visibleAppWindowCount + 1
        end
    end

    if visibleAppWindowCount > 1 then
        window:minimize()
    else
        window:application():hide()
    end
end

function DropDownWindows:showWindow(record)
    local spaceId = spaces.activeSpace()
    local mainScreen = hs.screen.find(spaces.mainScreenUUID())
    local scrFrame = mainScreen:fullFrame()

    local newFrame = hs.geometry.copy(scrFrame)
    newFrame:scale(0.8)
    local win = record:window()
    win:setFrame(newFrame, 0)

    -- this doesn't actually work right now, maybe some day
    -- https://github.com/asmagill/hs._asm.undocumented.spaces/issues/26
    spaces.moveWindowToSpace(win:id(), spaceId)

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
        signalChange(CONFIG)
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
        signalChange(DROPDOWN)
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
            signalChange(FOCUS)
        end
    end

    return o
end
function WindowRecord:isConfigured()
    return self:config() ~= nil
end

function WindowRecord:equals(other)
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

    local allRecords = function()
        local results = {}
        for _, v in pairs(windowRecordsByApp) do
            for _, r in pairs(v) do
                table.insert(results, 1, r)
            end
        end

        return results
    end
    o.allRecords = allRecords

    o.windowFilter =
        windowFilter:subscribe(
        {
            [hs.window.filter.windowCreated] = function(window)
                ensureRecord(window)
            end,
            [hs.window.filter.windowFocused] = function(window, appName)
                for _, r in pairs(allRecords()) do
                    if r.isFocused() then
                        r._setIsFocused(false)
                    end
                end

                local record = ensureRecord(window)
                local now = hs.timer.absoluteTime()
                record._setLastFocused(now)
                record._setIsFocused(true)
            end,
            [hs.window.filter.windowDestroyed] = function(window, appName)
                removeRecord(window, appName)
            end
             -- ,
            -- [hs.window.filter.windowUnfocused] = function(window)
            --     local record = ensureRecord(window)
            --     record._setIsFocused(false)
            -- end
        }
    )

    return o
end

return DropDownWindows
