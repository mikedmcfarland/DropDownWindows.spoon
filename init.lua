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
            logger.i("focus change", record)
            if record.isDropdown() and not self.windows.isFocused(record) then
                self:hideWindow(record)
            end
        end,
        [DROPDOWN] = function(record)
            if record:isDropdown() then
                self:showWindow(record)
            end
        end,
        [CONFIG] = function(record)
            logger.i("config change", record)
            if record:isConfigured() then
                self:showWindow(record)
            end
        end
    }

    local actionI = 0
    self.windows =
        Windows:new(
        hs.window.filter.default,
        function(type, record)
            local action = actions[type]
            if action then
                action(record)
                actionI = actionI + 1
                logger.i("-------------", actionI, "-------------")
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

function DropDownWindows:bindHotkeys(mapping)
    logger.d("bindingHotkeys")

    local spec = {
        toggleWindow = hs.fnutils.partial(self.toggleWindow, self),
        cycle = hs.fnutils.partial(self.cycle, self)
    }

    hs.spoons.bindHotkeysToSpec(spec, mapping)

    return self
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

    if not alreadyConfiguredRecord then
        hs.alert.show("configured dropdown")
        frontmost.setConfig(configIndex)
        return
    end

    if alreadyConfiguredRecord:equals(frontmost) then
        hs.alert.show("unset configured dropdown")
        frontmost.setConfig(nil)
        return
    end

    hs.alert.show("switch configured dropdown")
    alreadyConfiguredRecord:setConfig(nil)
    frontmost.setConfig(configIndex)
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

function DropDownWindows:cycle()
    local frontmost = self.windows.frontmost()
    local appName = frontmost:app():name()

    local choices = {}

    for _, r in pairs(self.windows.appRecords(appName)) do
        if not r:isDropdown() or r:equals(frontmost) then
            table.insert(choices, 1, r)
        end
    end

    if #choices <= 1 then
        logger.i("no windows to switch to")
        return
    end

    local currentIndex = hs.fnutils.indexOf(choices, frontmost)

    local nextIndex = currentIndex + 1
    if nextIndex > #choices then
        nextIndex = 1
    end
    local nextChoice = choices[nextIndex]
    nextChoice.window():focus()
end

function DropDownWindows:stop()
    logger.d("stop")
    self.windowFilter.unsubscribeAll()
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

    if choice then
        self:chooseWindow(choice)
    else
        hs.application.launchOrFocus(appName)
    end
end

function DropDownWindows:hideWindow(record)
    logger.i("hiding", record:app():name())
    local window = record:window()

    local appWindowCount = 0
    local appPid = record:app():pid()
    for _, r in ipairs(self.windows.allRecords()) do
        if r:app():pid() == appPid then
            appWindowCount = appWindowCount + 1
        end
    end

    if appWindowCount > 1 then
        window:minimize()
    else
        window:application():hide()
    end

    -- TODO: this doesn't work consistenly on hide windows
    -- this is because when you minimize a window for an app, and there's another app window, it will become focused (sometimes).
    -- the previous focus gets written as that app window on repeat

    local previousFocus = self.windows.previousFocus()
    if previousFocus and not previousFocus:equals(record) then
        previousFocus.window():focus()
    end
end

function DropDownWindows:showWindow(record)
    local mainScreen = hs.screen.find(spaces.mainScreenUUID())
    local scrFrame = mainScreen:fullFrame()

    local newFrame = hs.geometry.copy(scrFrame)
    newFrame:scale(0.8)
    local win = record:window()
    win:setFrame(newFrame, 0)

    -- this doesn't actually work right now, maybe some day
    -- https://github.com/asmagill/hs._asm.undocumented.spaces/issues/26
    -- local spaceId = spaces.activeSpace()
    -- spaces.moveWindowToSpace(win:id(), spaceId)

    win:focus()
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

function Windows:new(windowFilter, onChange)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o._onChange = onChange

    local windows = {}

    local allRecords = function()
        windows =
            hs.fnutils.ifilter(
            windows,
            function(win)
                -- local windowExists = pcall( function() return v.app() end )
                return win:app() ~= nil
            end
        )
        -- hs.fnutils.ieach(
        --     windows,
        --     function(r)
        --         logger.i("entry", r)
        --     end
        -- )
        return windows
    end
    o.allRecords = allRecords

    local recordByWindow = function(window)
        return hs.fnutils.find(
            allRecords(),
            function(r)
                return r:id() == window:id()
            end
        )
    end

    local createRecord = function(window)
        local newRecord = nil
        newRecord =
            WindowRecord:new(
            window,
            function(type)
                onChange(type, newRecord)
            end
        )
        table.insert(windows, 1, newRecord)
        return newRecord
    end

    local focus = nil
    local isFocused = function(record)
        if focus == nil then
            return false
        else
            return record:equals(focus)
        end
    end
    o.isFocused = isFocused

    local ensureRecord = function(window)
        local existingRecord = recordByWindow(window)
        if existingRecord then
            return existingRecord
        else
            return createRecord(window)
        end
    end

    local removeRecord = function(window)
        for i, r in ipairs(windows) do
            if r:id() == window:id() then
                table.remove(windows, i)
            end
        end
    end

    o.frontmost = function()
        return ensureRecord(hs.window.frontmostWindow())
    end

    local appRecords = function(appName)
        local records = {}
        for _, r in ipairs(allRecords()) do
            if r:app():name() == appName then
                table.insert(records, 1, r)
            end
        end
        return records
    end

    o.appRecords = appRecords

    local previousFocus = nil
    o.previousFocus = function()
        return previousFocus
    end

    local makeTheFocus = function(record)
        -- logger.i("makeTheFocus", record:app():name())
        local now = hs.timer.absoluteTime()
        record._setLastFocused(now)

        if focus == nil then
            previousFocus = focus
            focus = record
            onChange(FOCUS, focus)
        elseif not focus:equals(record) then
            previousFocus = focus
            focus = record
            onChange(FOCUS, focus)
        end
    end

    o.windowFilter =
        windowFilter:subscribe(
        {
            [hs.window.filter.windowCreated] = function(window)
                ensureRecord(window)
            end,
            [hs.window.filter.windowFocused] = function(window)
                --frontmost window is more accurate, sometimes this parameter is just wrong and is the same app but different window
                local frontmost = hs.window.frontmostWindow()

                if frontmost:id() ~= window:id() or frontmost:application():pid() ~= window:application():pid() then
                    logger.i("windowFocused", "frontmost differs from window")
                end

                local record = ensureRecord(frontmost)
                -- local record = ensureRecord(window)
                makeTheFocus(record)
            end,
            [hs.window.filter.windowDestroyed] = function(window)
                removeRecord(window)
            end,
            -- sometimes windows don't trigger a focus after being focused after minimizing
            -- this is the only event I could find that was triggered in those cases
            [hs.window.filter.windowVisible] = function(window)
                local frontmost = hs.window.frontmostWindow()
                if frontmost:id() ~= window:id() or frontmost:application():pid() ~= window:application():pid() then
                    logger.i("windowVisible", "frontmost differs from window")
                end

                local record = ensureRecord(frontmost)
                -- local record = ensureRecord(window)
                makeTheFocus(record)
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

return DropDownWindows
