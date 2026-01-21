# PieMenu.spoon

A simple **Pie Menu** for Hammerspoon.

## How to Install

1. **Download:** Click the green **[Code]** button above → **[Download ZIP]**.
2. **Rename:** Unzip the file and rename the folder to `PieMenu.spoon`.
3. **Move:**
   - Open **Hammerspoon**.
   - Click the icon in the menu bar → **Open Config**.
   - Open the `Spoons` folder.
   - Drag and drop your `PieMenu.spoon` folder into it.

## How to Use

If you want to use your own icons and commands, setup like this:

```lua
hs.loadSpoon("PieMenu")

spoon.PieMenu:setup({
    -- 1. (Optional) Path to your custom icons folder
    iconPath = os.getenv("HOME") .. "/.hammerspoon/icons",
    
    -- 2. Define your menu items
    items = {
        -- Example A: System App (Icon auto-detected)
        { label = "Safari", icon = "com.apple.Safari", action = function() hs.application.launchOrFocus("Safari") end },
        
        -- Example B: Custom Icon (Filename from iconPath)
        { label = "My Script", icon = "my-icon.png", action = function() hs.alert.show("Running Script...") end },
        
        -- Example C: System Built-in Icon
        { label = "Trash", icon = "NSTrashFull", action = function() hs.execute("open ~/.Trash") end }
    }
})

-- 3. Bind Hotkey
spoon.PieMenu:bindHotkeys({
    toggle = {{"cmd", "alt", "ctrl"}, "return"}
})
