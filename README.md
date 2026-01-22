# PieMenu.spoon 🥧

A customizable, highly extensible radial menu (pie menu) for [Hammerspoon](https://www.hammerspoon.org/).

![Version](https://img.shields.io/badge/Version-2.0.0-blue.svg) ![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ Features

* **Clean Visuals:** Smooth animations, icons, and text labels.
* **Various Action Types:** Launch apps, open URLs, open folders, run functions.
* **Nested Menus:** Infinite depth sub-menus using the Registry system.
* **Custom Handlers:** Define your own logic keys (e.g., system audio control).
* **Dynamic Layout:** Supports 6-sector layout (customizable).

## 📥 Installation

1.  Download the repository.
2.  Rename the folder to `PieMenu.spoon`.
3.  Move it to your Hammerspoon Spoons directory: `~/.hammerspoon/Spoons/`.
4.  Reload Hammerspoon.

## 🚀 Quick Start

Add this to your `~/.hammerspoon/init.lua`.
This example creates a main menu with an App, a URL, and a Sub-menu.

```lua
hs.loadSpoon("PieMenu")

-- 1. Define the Main Menu
local mainInstance = spoon.PieMenu:new()
mainInstance:setup({
    items = {
        { label = "Finder",  actionType = "app",      appName = "Finder",           icon = "com.apple.finder" },
        { label = "Google",  actionType = "url",      url = "[https://google.com](https://google.com)",   icon = "com.apple.Safari" },
        
        -- You can add 'nil' to create an empty space (spacer) and adjust the layout order.
        nil, 
        
        { label = "Home",    actionType = "folder",   path = "~/",                  icon = "NSHomeTemplate" },
        -- Link to a submenu (defined below)
        { label = "Tools",   actionType = "sub",      submenuId = "my_tools",       icon = "NSAdvanced" }
    }
})

-- 2. Define a Sub-menu and Register it
local toolsInstance = spoon.PieMenu:new()
toolsInstance:setup({
    items = {
        { label = "Hello",   actionType = "function", callback = function() hs.alert("Hello!") end },
        { label = "Back",    actionType = "function", callback = function() mainInstance:show() end }
    }
})
-- Register with the ID used in the main menu ("my_tools")
toolsInstance:register("my_tools")

-- 3. Bind Hotkey
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "return", function()
    mainInstance:toggle()
end)
```

## ⚙️ Configuration

### Item Properties
Each item in the `items` table requires an `actionType` and specific properties based on that type.

| actionType | Required Property | Description |
| :--- | :--- | :--- |
| **`"app"`** | `appName = "Name"` | Launches or focuses an application. |
| **`"url"`** | `url = "https://..."` | Opens a URL in the default browser. |
| **`"folder"`** | `path = "~/..."` | Opens a directory in Finder. |
| **`"sub"`** | `submenuId = "id"` | Opens a registered sub-menu instance. |
| **`"function"`**| `callback = func` | Executes a Lua function immediately. |

### Global Styling
You can customize the look and feel globally or per instance.

```lua
spoon.PieMenu.radius = 200
spoon.PieMenu.iconSize = 50
spoon.PieMenu.colors = {
    bg = { white = 0, alpha = 0.6 },
    line = { white = 1, alpha = 0.5 }
}
```

## 🛠 Advanced: Custom Handlers

You can define custom action types to separate logic from configuration.

```lua
-- 1. Register a custom handler
spoon.PieMenu.customHandlers["spotify"] = function(item)
    hs.spotify.displayCurrentTrack()
end

-- 2. Use it in your menu
local menu = spoon.PieMenu:new()
menu:setup({
    items = {
        { label = "Track Info", actionType = "spotify", icon = "com.spotify.client" }
    }
})
```

## 📜 License

MIT License
