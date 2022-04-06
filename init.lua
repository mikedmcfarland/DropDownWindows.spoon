-- https://github.com/asmagill/hs._asm.undocumented.spaces
local spaces = require("hs._asm.undocumented.spaces")

---@type Windows
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

function DropDownWindows:init()
    logger.d("init")
    return self
end

---@param event WindowsFocusEvent
function DropDownWindows:focusHandler(event)
    local previous = event.previousFocus

    if previous and previous:isDropdown() then
        self:hideWindow(previous)
    end
end

function DropDownWindows:start(config)
    logger.d("start")

    Windows.logger.setLogLevel(logger.getLogLevel())

    self:bindAppKeys(config.apps)
    self:bindConfigurableWindowsKeys(config.configurableWindows)

    self.windows =
        Windows:new(
        hs.window.filter.default,
        function(event)
            self:focusHandler(event)
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
            return r.config and r.config.index == configIndex
        end
    )

    if not alreadyConfiguredRecord then
        hs.alert.show("configured dropdown")
        self:makeConfiguredDropdown(frontmost, configIndex)
        return
    end

    if alreadyConfiguredRecord:equals(frontmost) then
        hs.alert.show("unset configured dropdown")
        self:unsetConfiguredDropdown(frontmost)
        return
    end

    hs.alert.show("switch configured dropdown")
    self:unsetConfiguredDropdown(alreadyConfiguredRecord)
    self:makeConfiguredDropdown(frontmost, configIndex)
end

function DropDownWindows:unsetConfiguredDropdown(record)
    self.windows:setConfig(record:id(), nil)
end

function DropDownWindows:makeConfiguredDropdown(record, index)
    self.windows:setConfig(record:id(), {index = index})
    self:showWindow(record)
end

function DropDownWindows:selectConfigurableWindow(configIndex)
    local allRecords = self.windows:allRecords()

    local selected =
        hs.fnutils.find(
        allRecords,
        function(r)
            return r:configuredAtIndex(configIndex)
        end
    )

    if selected then
        self:chooseWindow(selected)
    end
end

function DropDownWindows:cycle()
    local frontmostWindow = hs.window.frontmostWindow()
    local appName = frontmostWindow:application():name()

    local choices = {}

    local frontmost = nil
    for _, r in pairs(self.windows:appRecords(appName)) do
        if r:equals(frontmostWindow) then
            frontmost = r
            table.insert(choices, 1, r)
        elseif not r:isDropdown() then
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
    nextChoice.window:focus()
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
        self:enableDropdown(frontmost)
    elseif dropdown:equals(frontmost) then
        hs.alert.show("app dropdown disabled")
        self:disableDropdown(frontmost)
    else
        hs.alert.show("switching app dropdown window")
        self:disableDropdown(dropdown)
        self:enableDropdown(frontmost)
    end
end

function DropDownWindows:enableDropdown(record)
    self.windows:enableDropdown(record:id())
    self:showWindow(record)
end

---@param record WindowRecord
function DropDownWindows:disableDropdown(record)
    self.windows:disableDropdown(record:id())
    if record:isConfigured() then
        self.windows:setConfig(nil)
    end
end

---@param record WindowRecord
function DropDownWindows:chooseWindow(record)
    if record:isDropdown() then
        if record:isFrontmost() then
            self:hideWindow(record)
        else
            self:showWindow(record)
        end
        return
    else
        record.window:focus()
    end
end

function DropDownWindows:chooseApp(appName)
    local choice = nil
    for _, r in pairs(self.windows:appRecords(appName)) do
        local rFocusedMoreRecently = (not choice or choice.lastFocused < r.lastFocused)
        if not r:isConfigured() and (r:isDropdown() or rFocusedMoreRecently) then
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
    if not record:app() then
        logger.i("app is missing, cannot hide window")
        return
    end
    logger.i("hiding", record:app():name())

    local window = record.window

    if not window:isVisible() then
        logger.i("already not visible", record)
        return
    end

    local appWindowCount = 0
    for _, r in ipairs(self.windows:allRecords()) do
        if r:samePid(record) then
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

    -- local previousFocus = self.windows:previousFocus()
    -- if previousFocus ~= nil and not record:equals(previousFocus) then
    --     previousFocus.window:focus()
    -- end
end

function DropDownWindows:showWindow(record)
    logger.i("showWindow", record.window:application():name())
    local activeSpaceID = spaces.activeSpace()
    logger.i("activeSpaceID", activeSpaceID)

    local activeScreenUUIDs = {}

    for screenUUID, spacesOnDisplay in pairs(spaces.spacesByScreenUUID()) do
        logger.i("screenUUID", screenUUID)
        for _, spaceOnDisplay in pairs(spacesOnDisplay) do
            logger.i("spaceOnDisplay", spaceOnDisplay)
            if spaceOnDisplay == activeSpaceID then
                table.insert(activeScreenUUIDs, #activeScreenUUIDs + 1, screenUUID)
            end
        end
    end

    hs.fnutils.each(
        activeScreenUUIDs,
        function(activeScreen)
            logger.i("activeScreen", activeScreen)
        end
    )

    local activeScreenUUID = activeScreenUUIDs[1]

    -- local currentSpaces = spaces.query(spaces.masks.currentSpaces)
    -- for _, value in ipairs(currentSpaces) do
    --     logger.i("space", value)
    -- end
    -- local currentSpace = currentSpaces[1]
    --

    local activeScreen =
        hs.fnutils.find(
        hs.screen.allScreens(),
        function(s)
            return s:spacesUUID() == activeScreenUUID
        end
    )

    logger.i("activeScreen", activeScreen)
    logger.i("activeScreen:id()", activeScreen:id())

    local scrFrame = activeScreen:fullFrame()

    local newFrame = hs.geometry.copy(scrFrame)
    newFrame:scale(0.8)
    local win = record.window
    win:setFrame(newFrame, 0)

    -- this doesn't actually work right now, maybe some day
    -- https://github.com/asmagill/hs._asm.undocumented.spaces/issues/26
    -- local spaceId = spaces.activeSpace()
    spaces.moveWindowToSpace(win:id(), activeSpaceID)

    win:focus()
end

return DropDownWindows
