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
    return self
end

function DropDownWindows:start(config)
    logger.d("start")
    local appMappings = config.apps
    local appSpec = {}
    for key, _ in pairs(appMappings) do
        appSpec[key] = hs.fnutils.partial(self.dropDownApp, self, key)
    end
    hs.spoons.bindHotkeysToSpec(appSpec, appMappings)

    self.windowFilter =
        hs.window.filter.default:subscribe(
        hs.window.filter.windowFocused,
        function(window, appName)
            logger.d("window focused", appName, window:id())
            hs.fnutils.each(
                self.dropDownWindows,
                function(w)
                    if w.window:id() ~= window:id() and not w.window:isMinimized() then
                        logger.d("hiding window", w.window:application(), w.window:id())
                        self:hideWindow(w.window)
                    end
                end
            )
        end
    )

    return self
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
        logger.d("toggling", appName, existingWindow.window:id(), "off")
        hs.alert.show("drop down off")
        self.dropDownWindows[appName] = nil
    else
        logger.d("toggling", appName, window:id(), "on")

        hs.alert.show("drop down on")
        self.dropDownWindows[appName] = {window = window}
        self:showWindow(window)
    end
end

function DropDownWindows:dropDownApp(appName)
    logger.d("dropDownApp", appName)
    local windowEntry = self.dropDownWindows[appName]
    if windowEntry == nil then
        logger.i("no window toggled for app", appName)
        return
    end

    local window = windowEntry.window
    local frontWindow = hs.window.frontmostWindow()

    if frontWindow ~= nil and window:id() == frontWindow:id() then
        self:hideWindow(window)
    else
        self:showWindow(window)
    end
end

function DropDownWindows:hideWindow(win)
    win:minimize()
end

function DropDownWindows:showWindow(win)
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

return DropDownWindows
