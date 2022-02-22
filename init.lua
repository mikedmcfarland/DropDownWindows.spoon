-- https://github.com/asmagill/hs._asm.undocumented.spaces
local spaces = require("hs._asm.undocumented.spaces")

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
    self.dropDownWindows = {}
    self.windows = {}
    return self
end

function DropDownWindows:start(config)
    logger.d("start")

    self:bindAppKeys(config.apps)
    self.windowFilter =
        hs.window.filter.default:subscribe(
        {
            [hs.window.filter.windowFocused] = function(window, appName)
                self:addWindow(appName, window)
            end,
            [hs.window.filter.windowDestroyed] = function(window, appName)
                self:removeWindow(appName, window)
                local appDropDownWindow = self.dropDownWindows[appName]
                if appDropDownWindow ~= nil and appDropDownWindow:id() == window:id() then
                    logger.d("remove drop down entry", appName, window:id())
                    self.dropDownWindows[appName] = nil
                end
            end,
            [hs.window.filter.windowUnfocused] = function(window, appName)
                local appDropDownWindow = self.dropDownWindows[appName]
                if appDropDownWindow == nil then
                    return
                end
                if appDropDownWindow:id() == window:id() then
                    logger.d("window unfocused", appName, window:id())
                    self:hideDropDownWindow(window)
                end
            end
        }
    )

    return self
end

function DropDownWindows:bindAppKeys(appMappings)
    local appSpec = {}
    for key, _ in pairs(appMappings) do
        appSpec[key] = hs.fnutils.partial(self.chooseApp, self, key)
    end
    hs.spoons.bindHotkeysToSpec(appSpec, appMappings)
end

function DropDownWindows:hideUnfocusedDropdowns(focusedWindow)
    hs.fnutils.each(
        self.dropDownWindows,
        function(w)
            if w:id() ~= focusedWindow:id() and not w:isMinimized() then
                logger.d("hiding unfocused window", w:application(), w:id())
                self:hideDropDownWindow(w)
            end
        end
    )
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

    local app = hs.application.frontmostApplication()
    local window = app:focusedWindow()
    local appName = app:name()

    local existingWindow = self.dropDownWindows[appName]
    if existingWindow then
        logger.d("toggling", appName, existingWindow:id(), "disabled")
        hs.alert.show("drop down disabled")
        self.dropDownWindows[appName] = nil
    else
        logger.d("toggling", appName, window:id(), "enabled")
        hs.alert.show("drop down enabled")
        self.dropDownWindows[appName] = window
        self:showDropDownWindow(window)
    end
end

function DropDownWindows:chooseApp(appName)
    local window = self.dropDownWindows[appName]

    if self:hasDropDown(appName) then
        self:showOrHideDropDown(appName)
    else
        hs.application.launchOrFocus(appName)
    end
end

function DropDownWindows:hasDropDown(appName)
    return self:dropDownWindowByApp(appName) ~= nil
end

function DropDownWindows:showOrHideDropDown(appName)
    local frontWindow = hs.window.frontmostWindow()
    local appDropDownWindow = self:dropDownWindowByApp(appName)

    local appIsAlreadyShowing = appDropDownWindow ~= nil and frontWindow:id() == appDropDownWindow:id()

    if appIsAlreadyShowing then
        logger.d("hiding drop down", appDropDownWindow:application(), appDropDownWindow:id())
        self:hideDropDownWindow(appDropDownWindow)
    else
        self:showDropDownWindow(appDropDownWindow)
    end
end

function DropDownWindows:hideDropDownWindow(win)
    local app = win:application()
    local appWindows = self:windowsByApp(app:name())

    logger.d("#appWindows", #appWindows)

    if #appWindows > 1 then
        win:minimize()
    else
        win:application():hide()
    end
end

function DropDownWindows:showDropDownWindow(win)
    local space = spaces.activeSpace()
    local mainScreen = hs.screen.find(spaces.mainScreenUUID())

    local winFrame = win:frame()
    local scrFrame = mainScreen:fullFrame()
    winFrame.w = scrFrame.w
    winFrame.y = scrFrame.y
    winFrame.x = scrFrame.x

    win:setFrame(winFrame, 0)
    win:spacesMoveTo(space)
    win:focus()
end

function DropDownWindows:windowsByApp(appName)
    if self.windows[appName] == nil then
        self.windows[appName] = {}
    end
    return self.windows[appName]
end

function DropDownWindows:dropDownWindowByApp(appName)
    return self.dropDownWindows[appName]
end

function DropDownWindows:addWindow(appName, window)
    local appWindows = self:windowsByApp(appName)

    for _, w in ipairs(appWindows) do
        if w == window then
            return
        end
    end

    table.insert(appWindows, window)
end

function DropDownWindows:removeWindow(appName, window)
    local appWindows = self:windowsByApp(appName)
    for i, a in ipairs(appWindows) do
        if a == window then
            table.remove(appWindows, i)
            return
        end
    end
end

return DropDownWindows
