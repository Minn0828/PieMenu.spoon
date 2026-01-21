--- === PieMenu ===
---
--- A customizable radial menu for Hammerspoon.
---
--- Download: https://github.com/Minn0828/PieMenu.spoon

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "PieMenu"
obj.version = "1.6"
obj.author = "User"
obj.license = "MIT"
obj.homepage = "https://github.com/Minn0828/PieMenu.spoon"

-- Internal Variables
obj.canvas = nil
obj.tap = nil
obj.escBind = nil
obj.center = {x=0, y=0}

-- Default Configuration
obj.radius = 180        -- Radius of the menu circle
obj.triggerDist = 100   -- Distance from center to trigger action
obj.iconDist = 140      -- Distance of icons from center
obj.iconSize = 60       -- Size of icons
obj.colors = {
    bg = { white = 0, alpha = 0.5 },
    line = { white = 1, alpha = 0.3 }
}

-- Custom Icon Path (Optional, set via setup())
obj.iconPath = nil 

-- User Items Container
obj.items = {} 

-- [Demo Data] Sub-menu Example
local demoSubItems = {
    { 
        label = "Back", 
        icon = "NSGoBackTemplate", 
        action = function() obj:show(obj.defaultItems) end 
    },
    { label = "Music", icon = "com.apple.Music", action = function() hs.alert.show("🎵 Music") end },
    { label = "Mail", icon = "com.apple.mail", action = function() hs.alert.show("📧 Mail") end },
    { label = "Maps", icon = "com.apple.Maps", action = function() hs.alert.show("🗺️ Maps") end }
}

-- [Demo Data] Default Main Menu
-- Uses system icons/bundles to ensure it works out-of-the-box.
obj.defaultItems = {
    { label = "Finder", icon = "com.apple.finder", action = function() hs.application.launchOrFocus("Finder") end },
    { label = "Safari", icon = "com.apple.Safari", action = function() hs.application.launchOrFocus("Safari") end },
    { 
        label = "Extras", 
        icon = "NSFolder", 
        action = function() 
            hs.alert.show("📂 Opening Sub Menu...")
            obj:show(demoSubItems) 
        end 
    },
    { 
        label = "Settings", 
        icon = "NSAdvanced", 
        action = function() hs.application.launchOrFocus("System Settings") end 
    }
}

-- Helper: Icon Loader
-- Priority: Custom Path > Spoon Path > System Named > App Bundle > Absolute Path
local function getIconImage(icon)
    if not icon then return nil end
    if type(icon) == "userdata" then return icon end

    -- 1. Check custom user path
    if obj.iconPath then
        local customPath = obj.iconPath .. "/" .. icon
        if hs.fs.attributes(customPath) then return hs.image.imageFromPath(customPath) end
    end

    -- 2. Check Spoon's internal icons folder
    local spoonIconPath = hs.spoons.scriptPath() .. "icons/" .. icon
    if hs.fs.attributes(spoonIconPath) then return hs.image.imageFromPath(spoonIconPath) end
    
    -- 3. Check System Image Names (e.g., NSFolder)
    local sysImg = hs.image.imageFromName(icon)
    if sysImg then return sysImg end

    -- 4. Check App Bundle IDs (e.g., com.apple.Safari)
    if string.find(icon, "%.") and not string.find(icon, "/") and not string.find(icon, "png") then
        local appImg = hs.image.imageFromAppBundle(icon)
        if appImg then return appImg end
    end
    
    -- 5. Check Absolute Path
    if icon:sub(1,1) == "/" or icon:sub(1,1) == "~" then return hs.image.imageFromPath(icon) end
    
    -- Fallback
    return hs.image.imageFromName("NSActionTemplate")
end

-- Core: Draw the Menu
function obj:draw(itemsToDraw)
    if self.canvas then self.canvas:delete() end
    
    -- Update center position
    local mouse = hs.mouse.getAbsolutePosition()
    self.center = mouse
    
    local frame = { x = mouse.x - self.radius, y = mouse.y - self.radius, w = self.radius * 2, h = self.radius * 2 }
    self.canvas = hs.canvas.new(frame)

    -- Draw Background
    self.canvas[1] = { type = "circle", action = "fill", fillColor = self.colors.bg, radius = self.triggerDist }
    self.canvas[2] = { type = "circle", action = "stroke", strokeColor = self.colors.line, radius = self.triggerDist, strokeWidth = 2 }

    -- Draw Items
    for i, item in ipairs(itemsToDraw) do
        if i > 6 then break end -- Max 6 items supported
        
        local angleRad = math.rad((i - 1) * 60 - 90) -- Start from 12 o'clock
        local tx = self.radius + self.iconDist * math.cos(angleRad)
        local ty = self.radius + self.iconDist * math.sin(angleRad)

        local imgObj = getIconImage(item.icon)
        if imgObj then
            self.canvas[#self.canvas + 1] = {
                type = "image",
                image = imgObj,
                frame = { 
                    x = tx - (self.iconSize / 2), 
                    y = ty - (self.iconSize / 2), 
                    w = self.iconSize, 
                    h = self.iconSize 
                }
            }
        else
             -- Text Fallback for missing icons
             self.canvas[#self.canvas + 1] = {
                type = "text",
                text = "?",
                textColor = {white=1},
                frame = { x = tx - 10, y = ty - 10, w = 20, h = 20 }
            }
        end
    end
    self.canvas:show()
end

-- Helper: Hide Menu & Cleanup
function obj:hide()
    if self.tap then self.tap:stop(); self.tap = nil end
    if self.escBind then self.escBind:delete(); self.escBind = nil end
    if self.canvas then self.canvas:delete(); self.canvas = nil end
end

-- Core: Show Menu
function obj:show(customItems)
    self:hide() 
    
    -- Determine which items to show (User items, Sub-menu items, or Default Demo)
    local itemsToUse = customItems or self.items
    if #itemsToUse == 0 then itemsToUse = self.defaultItems end
    
    -- Draw the determined items
    self:draw(itemsToUse)
    
    -- Bind Escape to close
    self.escBind = hs.hotkey.bind({}, "escape", function() self:hide() end)

    -- Delay event tap to prevent accidental triggering due to mouse inertia
    hs.timer.doAfter(0.1, function()
        if not self.canvas then return end

        self.tap = hs.eventtap.new({hs.eventtap.event.types.mouseMoved}, function(e)
            local curr = hs.mouse.getAbsolutePosition()
            local dist = math.sqrt((curr.x - self.center.x)^2 + (curr.y - self.center.y)^2)

            -- Check trigger distance
            if dist > self.triggerDist then
                local angle = math.deg(math.atan2(curr.y - self.center.y, curr.x - self.center.x))
                local index = math.floor(((angle + 90 + 30) % 360) / 60) + 1
                
                self:hide() -- Close menu before action

                local item = itemsToUse[index]
                if item and item.action then
                    if type(item.action) == "function" then
                        -- Execute action asynchronously
                        hs.timer.doAfter(0.01, function() item.action() end)
                    end
                end
            end
            return nil
        end)
        self.tap:start()
    end)
end

-- Toggle Menu
function obj:toggle()
    if self.canvas then self:hide() else self:show() end
end

-- Setup Spoon
function obj:setup(args)
    if not args then return self end
    
    if args.radius then self.radius = args.radius end
    if args.triggerDist then self.triggerDist = args.triggerDist end
    if args.items then self.items = args.items end
    if args.iconDist then self.iconDist = args.iconDist end
    if args.iconSize then self.iconSize = args.iconSize end
    if args.colors then self.colors = args.colors end
    
    -- Set custom icon path
    if args.iconPath then self.iconPath = args.iconPath end
    
    return self
end

return obj