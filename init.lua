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
    self.configurableWindows = {}
    return self
end

function DropDownWindows:start(config)
    logger.d("start")

    self:bindAppKeys(config.apps)
    self:bindConfigurableWindowsKeys(config.configurableWindows)
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
                self:hideUnfocusedDropDowns(window, appName)
            end
        }
    )

    return self
end

function DropDownWindows:hideUnfocusedDropDowns(window, appName)
    local appDropDownWindow = self.dropDownWindows[appName]
    if appDropDownWindow ~= nil and appDropDownWindow:id() == window:id() then
        logger.d("window unfocused", appName, window:id())
        self:hideDropDownWindow(window)
        return
    end

    local configurableWindow =
        hs.fnutils.find(
        self.configurableWindows,
        function(w)
            return w:id() == window:id()
        end
    )
    if configurableWindow ~= nil then
        logger.d("window unfocused", appName, window:id())
        self:hideDropDownWindow(window)
    end
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
    local windowToAssign = hs.window.frontmostWindow()
    self.configurableWindows[configIndex] = windowToAssign
end

function DropDownWindows:selectConfigurableWindow(configIndex)
    local windowToSelect = self.configurableWindows[configIndex]
    self:showOrHideWindow(windowToSelect)
end

-- function DropDownWindows:hideUnfocusedDropdowns(focusedWindow)
--     local maybeHideWindow = function(w)
--         if w:id() ~= focusedWindow:id() and not w:isMinimized() then
--             logger.d("hiding unfocused window", w:application(), w:id())
--             self:hideDropDownWindow(w)
--         end
--     end

--     hs.fnutils.each(self.dropDownWindows, maybeHideWindow)
--     hs.fnutils.each(self.configurableWindows, maybeHideWindow)
-- end

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

function DropDownWindows:showOrHideWindow(window)
    local frontWindow = hs.window.frontmostWindow()
    local windowAlreadyShowing = window ~= nil and frontWindow:id() == window:id()

    if windowAlreadyShowing then
        logger.d("hiding drop down", window:application(), window:id())
        self:hideDropDownWindow(window)
    else
        self:showDropDownWindow(window)
    end
end

function DropDownWindows:showOrHideDropDown(appName)
    local appDropDownWindow = self:dropDownWindowByApp(appName)
    self:showOrHideWindow(appDropDownWindow)
end

function DropDownWindows:hideDropDownWindow(win)
    local app = win:application()
    local appWindows = self:windowsByApp(app:name())

    if #appWindows > 1 then
        win:minimize()
    else
        win:application():hide()
    end
end

function DropDownWindows:showDropDownWindow(win)
    local space = spaces.activeSpace()
    local mainScreen = hs.screen.find(spaces.mainScreenUUID())

    local scrFrame = mainScreen:fullFrame()

    local newFrame = hs.geometry.copy(scrFrame)
    newFrame:scale(0.8)
    win:setFrame(newFrame, 0)
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
        if w:id() == window:id() then
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

function Window:new(window)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.window = window
    o.attrs = {}
    return o
end

function Window:equals(w)
    if getmetatable(w) == Window then
        return w.window:id() == self.window:id()
    else
        return w:id() == self.window:id()
    end
end

function Window:setAttribute(name, value)
    self.attrs[name] = value
end

function Window:attribute(name)
    return self.attrs[name]
end

return DropDownWindows
