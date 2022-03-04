-- https://github.com/asmagill/hs._asm.undocumented.spaces
local spaces = require("hs._asm.undocumented.spaces")
local Windows = dofile(hs.spoons.resourcePath("Windows.lua"))

local DropDownWindows = {}
DropDownWindows.__index = DropDownWindows

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

    Windows.logger.setLogLevel(logger.getLogLevel())

    self:bindAppKeys(config.apps)
    self:bindConfigurableWindowsKeys(config.configurableWindows)

    local actions = {
        [FOCUS] = function(record)
            logger.i("focus change", record)
            if record.isDropdown() and not self.windows:isFocused(record) then
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
    local frontmost = self.windows:frontmost()

    local alreadyConfiguredRecord =
        hs.fnutils.find(
        self.windows:allRecords(),
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
        self.windows:allRecords(),
        function(r)
            return r:config() and r:config().index == configIndex
        end
    )
    if selected then
        self:chooseWindow(selected)
    end
end

function DropDownWindows:cycle()
    local frontmost = self.windows:frontmost()
    local appName = frontmost:app():name()

    local choices = {}

    for _, r in pairs(self.windows:appRecords(appName)) do
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
        self.windows:appRecords(appName),
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
    for _, r in pairs(self.windows:appRecords(appName)) do
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
    for _, r in ipairs(self.windows:allRecords()) do
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

    local previousFocus = self.windows:previousFocus()
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

return DropDownWindows
