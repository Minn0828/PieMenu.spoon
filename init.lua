--- === PieMenu ===
---
--- A customizable radial menu for Hammerspoon.
---
--- Download: https://github.com/Minn0828/PieMenu.spoon

local obj = {}
obj.__index = obj

-- --------------------------------------------------------------------------
-- Metadata
-- --------------------------------------------------------------------------
obj.name = "PieMenu"
obj.version = "2.0.0"
obj.author = "Minn0828"
obj.license = "MIT"
obj.homepage = "https://github.com/Minn0828/PieMenu.spoon"

-- --------------------------------------------------------------------------
-- Logger & Storage
-- --------------------------------------------------------------------------
local logger = hs.logger.new("PieMenu", "info")

-- Global Registry: Stores all menu instances as { ID = Object }
obj.menuRegistry = {}

-- Global Handler Storage: Stores custom handlers injected from config
obj.customHandlers = {}

-- --------------------------------------------------------------------------
-- Default Configuration
-- --------------------------------------------------------------------------
obj.radius = 180
obj.triggerDist = 100
obj.iconDist = 140
obj.iconSize = 60
obj.canvasLevel = hs.canvas.windowLevels.overlay
obj.showDelay = 0.1
obj.fadeDuration = 0.05

obj.colors = {
    bg = { white = 0, alpha = 0.5 },
    line = { white = 1, alpha = 0.3 },
    sep = { white = 1, alpha = 0.4 } 
}

obj.iconPath = nil
obj.activeInstance = nil

-- --------------------------------------------------------------------------
-- Demo Data (Default Items)
-- --------------------------------------------------------------------------
-- Main demo menu
obj.defaultItems = {
    { label = "Finder",   actionType = "app", appName = "Finder",       icon = "com.apple.finder" },
    { label = "Google",   actionType = "url", url = "https://google.com", icon = "com.apple.Safari" },
    nil, -- Spacer
    { label = "More...",  actionType = "sub", submenuId = "demo_sub",   icon = "NSActionTemplate" }
}

-- Submenu demo data (Internal use)
local demoSubItems = {
    { label = "Back",  actionType = "function", callback = function() obj.activeInstance:hide() end, icon = "NSGoBackTemplate" },
    { label = "Hello", actionType = "function", callback = function() hs.alert.show("Hello!") end, icon = "HSImage" },
}

-- --------------------------------------------------------------------------
-- Internal Helpers
-- --------------------------------------------------------------------------

-- Check if table is empty
local function isTableEmpty(t) 
    return next(t) == nil 
end

-- Expand path (convert ~ to /Users/xxx)
local function expandPath(path)
    if not path then return nil end
    if path:sub(1, 1) == "~" then return os.getenv("HOME") .. path:sub(2) end
    return path
end

-- Load icon from various sources
local function getIconImage(icon, instance)
    if not icon then return nil end
    if type(icon) == "userdata" then return icon end
    if instance and instance.iconCache[icon] then return instance.iconCache[icon] end

    local img = nil
    -- 1. Custom Path
    if instance and instance.iconPath then
        local customPath = instance.iconPath .. "/" .. icon
        if hs.fs.attributes(customPath) then img = hs.image.imageFromPath(customPath) end
    end
    -- 2. Spoon Icon Path
    if not img then
        local spoonIconPath = hs.spoons.scriptPath() .. "icons/" .. icon
        if hs.fs.attributes(spoonIconPath) then img = hs.image.imageFromPath(spoonIconPath) end
    end
    -- 3. System Name
    if not img then
        local sysImg = hs.image.imageFromName(icon)
        if sysImg then img = sysImg end
    end
    -- 4. App Bundle
    if not img then
        if string.find(icon, "%.") and not string.find(icon, "/") and not string.find(icon, "png") then
            local appImg = hs.image.imageFromAppBundle(icon)
            if appImg then img = appImg end
        end
    end
    -- 5. Full Path
    if not img then
        local expandedIcon = expandPath(icon)
        if expandedIcon:sub(1,1) == "/" then img = hs.image.imageFromPath(expandedIcon) end
    end
    -- 6. Fallback
    if not img then img = hs.image.imageFromName("NSActionTemplate") end
    
    if instance and img then instance.iconCache[icon] = img end
    return img
end

-- Execute action based on actionType
local function triggerAction(item)
    if not item then return end
    
    local actType = item.actionType
    
    -- 0. Custom Handler (Highest Priority)
    if actType and obj.customHandlers[actType] then
        obj.customHandlers[actType](item)
        return
    end

    -- 1. URL
    if actType == "url" then
        local path = expandPath(item.url or item.path)
        if path then hs.urlevent.openURL(path) end
        return
    end

    -- 2. Folder
    if actType == "folder" then
        local path = expandPath(item.path)
        if path and hs.fs.attributes(path) then
            hs.task.new("/usr/bin/open", nil, { path }):start()
        else
            hs.alert.show("PieMenu Error: Path not found\n" .. (path or "nil"))
        end
        return
    end
    
    -- 3. App Launch
    if actType == "app" and item.appName then
        hs.application.launchOrFocus(item.appName)
        return
    end

    -- 4. Submenu (Registry Lookup)
    if actType == "sub" and item.submenuId then
        local targetObj = obj.menuRegistry[item.submenuId]
        if targetObj then
            hs.timer.doAfter(0.1, function() targetObj:show() end)
        else
            hs.alert.show("PieMenu Error: Menu ID not found: " .. item.submenuId)
        end
        return
    end

    -- 5. Direct Callback
    if actType == "function" and item.callback then
        item.callback()
        return
    end
end

-- --------------------------------------------------------------------------
-- Core Methods
-- --------------------------------------------------------------------------

-- Constructor
function obj:new()
    local newObj = setmetatable({}, self)
    newObj.radius = self.radius
    newObj.triggerDist = self.triggerDist
    newObj.iconDist = self.iconDist
    newObj.iconSize = self.iconSize
    newObj.canvasLevel = self.canvasLevel
    newObj.showDelay = self.showDelay
    newObj.fadeDuration = self.fadeDuration
    newObj.colors = { bg = self.colors.bg, line = self.colors.line, sep = self.colors.sep }
    
    newObj.canvas = nil
    newObj.tap = nil
    newObj.showTimer = nil
    newObj.fadeTimer = nil
    newObj.items = {}
    newObj.activeItems = {}
    newObj.center = {x=0, y=0}
    newObj.iconCache = {}
    
    return newObj
end

-- Register instance to global registry
function obj:register(id)
    if id then
        obj.menuRegistry[id] = self
    end
    return self
end

-- Setup configuration
function obj:setup(args)
    if not args then return self end
    self.iconCache = {}
    
    local s = args.style or args
    local keys = {"radius", "triggerDist", "iconDist", "iconSize", "canvasLevel", "showDelay", "fadeDuration"}
    
    for _, k in ipairs(keys) do 
        if s[k] then self[k] = s[k] end 
    end
    
    if s.colors then 
        for k, v in pairs(s.colors) do 
            if self.colors[k] then self.colors[k] = v end 
        end 
    end
    
    if args.items then self.items = args.items end
    if args.iconPath then self.iconPath = args.iconPath end
    
    return self
end

-- Draw the menu on canvas
function obj:draw()
    if self.canvas then self.canvas:delete() end
    
    local mouse = hs.mouse.absolutePosition()
    local currentScreen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    local screenFrame = currentScreen:fullFrame()
    
    local cx = math.max(screenFrame.x + self.radius, math.min(mouse.x, screenFrame.x + screenFrame.w - self.radius))
    local cy = math.max(screenFrame.y + self.radius, math.min(mouse.y, screenFrame.y + screenFrame.h - self.radius))
    
    if cx ~= mouse.x or cy ~= mouse.y then
        hs.mouse.absolutePosition({x = cx, y = cy})
    end
    
    self.center = {x = cx, y = cy}
    
    local frame = { x = cx - self.radius, y = cy - self.radius, w = self.radius * 2, h = self.radius * 2 }
    self.canvas = hs.canvas.new(frame)
    self.canvas:level(self.canvasLevel)

    -- Background
    self.canvas[1] = { type = "circle", action = "fill", fillColor = self.colors.bg, radius = self.triggerDist }
    
    -- Sectors
    for i = 1, 6 do
        local angleRad = math.rad((i - 1) * 60 - 120) 
        local sx, sy = self.radius + self.triggerDist * math.cos(angleRad), self.radius + self.triggerDist * math.sin(angleRad)
        local ex, ey = self.radius + self.radius * math.cos(angleRad), self.radius + self.radius * math.sin(angleRad)
        
        self.canvas[#self.canvas + 1] = { type = "segments", coordinates = {{x=sx, y=sy}, {x=ex, y=ey}}, strokeColor = {black=1, alpha=0.3}, strokeWidth = 3 }
        self.canvas[#self.canvas + 1] = { type = "segments", coordinates = {{x=sx, y=sy}, {x=ex, y=ey}}, strokeColor = self.colors.sep, strokeWidth = 1 }
    end
    self.canvas[#self.canvas + 1] = { type = "circle", action = "stroke", strokeColor = self.colors.line, radius = self.triggerDist, strokeWidth = 2 }

    -- Icons
    for i = 1, 6 do
        local item = self.activeItems[i]
        if item then
            local angleRad = math.rad((i - 1) * 60 - 90)
            local tx, ty = self.radius + self.iconDist * math.cos(angleRad), self.radius + self.iconDist * math.sin(angleRad)
            local imgObj = getIconImage(item.icon, self)
            
            if imgObj then
                self.canvas[#self.canvas + 1] = { type = "image", image = imgObj, frame = { x = tx - (self.iconSize/2), y = ty - (self.iconSize/2), w = self.iconSize, h = self.iconSize } }
            else
                self.canvas[#self.canvas + 1] = { type = "text", text = item.label or "?", textColor = {white=1}, textAlignment = "center", textSize = 12, shadow = { blurRadius = 2, color = { alpha = 0.7, black = 1 }, offset = { h = 1, w = 1 } }, frame = { x = tx - 30, y = ty - 10, w = 60, h = 20 } }
            end
        end
    end
    
    -- Fade In Animation
    if self.fadeTimer then self.fadeTimer:stop() end
    self.canvas:alpha(0)
    self.canvas:show()
    local steps, stepTime, currentStep = 5, self.fadeDuration / 5, 0
    self.fadeTimer = hs.timer.doWhile(function() return currentStep < steps end, function() currentStep = currentStep + 1; if self.canvas then self.canvas:alpha(currentStep / steps) end end, stepTime)
end

-- Hide Menu
function obj:hide()
    if self.showTimer then self.showTimer:stop(); self.showTimer = nil end
    if self.fadeTimer then self.fadeTimer:stop(); self.fadeTimer = nil end
    if self.tap then self.tap:stop() end
    if self.canvas then self.canvas:delete(); self.canvas = nil end
    if obj.activeInstance == self then obj.activeInstance = nil end
end

-- Show Menu
function obj:show(customItems)
    if obj.activeInstance and obj.activeInstance ~= self then obj.activeInstance:hide() end
    self:hide()
    obj.activeInstance = self
    
    local sourceItems = customItems or self.items
    if type(sourceItems) ~= "table" then sourceItems = {} end
    
    -- Load default demo items if empty
    if isTableEmpty(sourceItems) then
        sourceItems = self.defaultItems
        
        -- Register demo submenu if not exists
        if not obj.menuRegistry["demo_sub"] then
            local demoInstance = obj:new()
            demoInstance:setup({ items = demoSubItems })
            demoInstance:register("demo_sub")
        end
    end
    
    self.activeItems = sourceItems
    self:draw()
    
    if not self.tap then
        local events = hs.eventtap.event.types
        self.tap = hs.eventtap.new({
            events.mouseMoved, events.keyDown, events.leftMouseDown, events.leftMouseUp, events.rightMouseDown, events.rightMouseUp
        }, function(e)
            local type = e:getType()
            if type == events.keyDown then if e:getKeyCode() == 53 then self:hide(); return true end return false end
            if type == events.rightMouseDown or type == events.rightMouseUp then if type == events.rightMouseDown then self:hide() end return true end
            if type == events.leftMouseDown then
                local curr = hs.mouse.absolutePosition()
                local dist = math.sqrt((curr.x - self.center.x)^2 + (curr.y - self.center.y)^2)
                if dist <= self.triggerDist then self:hide(); return true elseif dist <= self.radius then return true end
                return nil
            end
            if type == events.leftMouseUp then
                local curr = hs.mouse.absolutePosition()
                local dist = math.sqrt((curr.x - self.center.x)^2 + (curr.y - self.center.y)^2)
                if dist <= self.radius then return true end
                return nil
            end
            if type == events.mouseMoved then
                local curr = hs.mouse.absolutePosition()
                local dist = math.sqrt((curr.x - self.center.x)^2 + (curr.y - self.center.y)^2)
                if dist > self.triggerDist then
                    local angle = math.deg(math.atan2(curr.y - self.center.y, curr.x - self.center.x))
                    local index = math.floor(((angle + 90 + 30) % 360) / 60) + 1
                    self:hide()
                    local item = self.activeItems[index]
                    if item then hs.timer.doAfter(0.01, function() triggerAction(item) end) end
                end
            end
            return nil
        end)
    end
    self.showTimer = hs.timer.doAfter(self.showDelay, function() self.showTimer = nil; if obj.activeInstance == self and self.canvas then self.tap:start() end end)
end

-- Toggle Menu
function obj:toggle() 
    if self.canvas then self:hide() else self:show() end 
end

return obj
