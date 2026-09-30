
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService       = game:GetService("GuiService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local AirFlow = {}
AirFlow.Flags   = {}
AirFlow.Windows = {}

local function merge(opts, defaults)
    local result = {}

    if type(opts) == "string" then
        result.Name = opts
    elseif type(opts) == "table" then
        for k, v in pairs(opts) do
            result[k] = v
        end
    end

    for k, v in pairs(defaults or {}) do
        if result[v] == nil and result[k] ~= nil then
            result[v] = result[k]
        end
    end

    if result.Range then
        result.Min = result.Min or result.Range[1]
        result.Max = result.Max or result.Range[2]
    end

    return result
end

local function registerControl(parent, opts, control, frame, typeName)
    control._type      = typeName
    control._frame     = frame
    control._listeners = control._listeners or {}

    local window = parent and parent.Window

    if opts.Flag then
        AirFlow.Flags[opts.Flag] = control

        if window then
            local original = opts.Callback
            opts.Callback = function(...)
                if type(original) == "function" then
                    original(...)
                end
                window:_autoSave()
            end
        end
    end

    function control:Destroy()
        if control._destroyed then return end
        control._destroyed = true

        for _, fn in ipairs(control._listeners) do
            fn()
        end
        control._listeners = {}

        if opts.Flag and AirFlow.Flags[opts.Flag] == control then
            AirFlow.Flags[opts.Flag] = nil
        end

        if window then
            window._controlsDirty = true
        end

        if frame then
            frame:Destroy()
        end
    end

    return control
end

AirFlow.Theme = {
    Background   = Color3.fromRGB(20, 16, 20),
    Surface      = Color3.fromRGB(24, 19, 24),
    Surface2     = Color3.fromRGB(28, 22, 28),
    Surface3     = Color3.fromRGB(42, 36, 43),
    Stroke       = Color3.fromRGB(40, 32, 41),
    StrokeHover  = Color3.fromRGB(88, 70, 90),
    Accent       = Color3.fromRGB(235, 199, 246),
    AccentDark   = Color3.fromRGB(24, 18, 26),
    Text         = Color3.fromRGB(233, 229, 234),
    Muted        = Color3.fromRGB(125, 115, 126),
    Warning      = Color3.fromRGB(240, 176, 108),
    Success      = Color3.fromRGB(150, 220, 170),
    Error        = Color3.fromRGB(240, 120, 120),
}

AirFlow.Assets = {
    Shadow = "rbxassetid://6014261993",
    Glow   = "rbxassetid://8992230677",
    Logo   = "rbxassetid://103859712365480",
}

local lucideCache

local function loadLucide()
    if lucideCache ~= nil then
        return lucideCache
    end

    local ok, result = pcall(function()
        local src = game:HttpGet("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua")
        return loadstring(src)()
    end)

    if ok and type(result) == "table" then
        lucideCache = result
    else
        lucideCache = false
        warn("[AirFlow] lucide icons unavailable: " .. tostring(result))
    end

    return lucideCache
end

local fontSources = {
    ValleySans = {
        Regular  = "https://raw.githubusercontent.com/HelsinkiTypeStudio/valley-sans/main/fonts/ttf/ValleySans-Regular.ttf",
        Medium   = "https://raw.githubusercontent.com/HelsinkiTypeStudio/valley-sans/main/fonts/ttf/ValleySans-Medium.ttf",
        SemiBold = "https://raw.githubusercontent.com/HelsinkiTypeStudio/valley-sans/main/fonts/ttf/ValleySans-SemiBold.ttf",
    },
}

local weightMap = {
    Regular  = { 400, Enum.FontWeight.Regular },
    Medium   = { 500, Enum.FontWeight.Medium },
    SemiBold = { 600, Enum.FontWeight.SemiBold },
    Bold     = { 700, Enum.FontWeight.Bold },
}

function AirFlow:LoadFont(opts)
    opts = merge(opts, {})

    if type(writefile) ~= "function" or type(isfile) ~= "function" or typeof(getcustomasset) ~= "function" then
        warn("[AirFlow] custom fonts need writefile, isfile and getcustomasset")
        return false
    end

    local name    = opts.Name or "CustomFont"
    local weights = opts.Weights or fontSources[name]

    if type(weights) ~= "table" then
        warn("[AirFlow] no font weights for " .. name)
        return false
    end

    local folder = opts.Folder or "AirFlowFonts"

    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then
            makefolder(folder)
        end
    end)

    local faces = {}

    for weightName, url in pairs(weights) do
        local info = weightMap[weightName]
        if info then
            local path = folder .. "/" .. name .. "-" .. weightName .. ".ttf"
            local ok = true

            if not isfile(path) then
                ok = pcall(function()
                    writefile(path, game:HttpGet(url))
                end)
            end

            if ok then
                table.insert(faces, {
                    name    = weightName,
                    weight  = info[1],
                    style   = "normal",
                    assetId = getcustomasset(path),
                })
            else
                warn("[AirFlow] could not download " .. weightName .. " weight of " .. name)
            end
        end
    end

    if #faces == 0 then
        return false
    end

    local jsonPath = folder .. "/" .. name .. ".json"
    local ok = pcall(function()
        writefile(jsonPath, HttpService:JSONEncode({
            name  = name,
            faces = faces,
        }))
    end)

    if not ok then
        return false
    end

    local asset = getcustomasset(jsonPath)

    local function make(weightName, fallback)
        local info = weightMap[weightName]
        if info and weights[weightName] then
            return Font.new(asset, info[2])
        end
        return fallback
    end

    AirFlow.Fonts.Regular = make("Regular", AirFlow.Fonts.Regular)
    AirFlow.Fonts.Medium  = make("Medium",  make("Regular", AirFlow.Fonts.Medium))
    AirFlow.Fonts.Bold    = make("SemiBold", make("Bold", AirFlow.Fonts.Bold))

    return true
end

function AirFlow:PreloadIcons()
    return loadLucide() ~= false
end

local function resolveIcon(icon)
    if typeof(icon) == "table" then
        return icon.Image, icon.RectOffset, icon.RectSize
    end

    if type(icon) ~= "string" then
        return nil
    end

    if icon:find("^rbxassetid://") or icon:find("^rbxasset://") or icon:find("^http") then
        return icon
    end

    local name = icon:gsub("^lucide:", "")
    local lib  = loadLucide()

    if not lib then
        return nil
    end

    local entry = (lib.Icons and lib.Icons[name]) or lib[name]

    if type(entry) == "table" then
        local image = entry.Image
        if type(image) == "number" then
            image = "rbxassetid://" .. tostring(image)
        end

        local sheet = (lib.Spritesheets and lib.Spritesheets[tostring(image)]) or image
        return sheet, entry.ImageRectPosition, entry.ImageRectSize
    elseif type(entry) == "string" then
        return entry
    end

    warn("[AirFlow] unknown lucide icon: " .. name)
    return nil
end

local builderSans = "rbxasset://fonts/families/BuilderSans.json"

AirFlow.Fonts = {
    Regular = Font.new(builderSans, Enum.FontWeight.Regular),
    Medium  = Font.new(builderSans, Enum.FontWeight.Medium),
    Bold    = Font.new(builderSans, Enum.FontWeight.SemiBold),
}

local Theme  = AirFlow.Theme
local Assets = AirFlow.Assets
local Fonts  = AirFlow.Fonts

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
AirFlow.Touch = isTouch

local ROW_H      = isTouch and 54 or 48
local ROW_H_DESC = isTouch and 70 or 64
local ITEM_H     = isTouch and 40 or 34
local CHIP_H     = isTouch and 34 or 28

local tweenCache = {}

local function tween(inst, props, duration, style, direction)
    duration = duration or 0.2

    if duration <= 0 then
        for k, v in pairs(props) do
            inst[k] = v
        end
        return nil
    end

    style     = style or Enum.EasingStyle.Quart
    direction = direction or Enum.EasingDirection.Out

    local key = duration .. style.Name .. direction.Name
    local info = tweenCache[key]

    if not info then
        info = TweenInfo.new(duration, style, direction)
        tweenCache[key] = info
    end

    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

local function create(className, props, children)
    local inst = Instance.new(className)

    for k, v in pairs(props) do
        if k ~= "Parent" then
            inst[k] = v
        end
    end

    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    if props.Parent ~= nil and typeof(props.Parent) ~= "Instance" then
        warn("[AirFlow] c() got non-Instance Parent:", props.Parent)
        warn(debug.traceback())
    elseif props.Parent then
        inst.Parent = props.Parent
    end

    return inst
end

local function corner(parent, radius)
    return create("UICorner", {
        CornerRadius = radius or UDim.new(0, 8),
        Parent = parent,
    })
end

local function stroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Color            = color or Theme.Stroke,
        Transparency     = transparency or 0,
        Thickness        = thickness or 1,
        ApplyStrokeMode  = Enum.ApplyStrokeMode.Border,
        Parent           = parent,
    })
end

local function padding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft   = UDim.new(0, left or 0),
        PaddingRight  = UDim.new(0, right or 0),
        PaddingTop    = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        Parent        = parent,
    })
end

local function textLabel(props)
    local defaults = {
        BackgroundTransparency = 1,
        TextColor3             = Theme.Text,
        TextSize               = 14,
        FontFace               = Fonts.Medium,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextYAlignment         = Enum.TextYAlignment.Center,
        TextTruncate           = Enum.TextTruncate.AtEnd,
    }

    for k, v in pairs(props) do
        defaults[k] = v
    end

    return create("TextLabel", defaults)
end

local function glow(parent, size, position, transparency, rotation)
    local img = create("ImageLabel", {
        AnchorPoint        = Vector2.new(0.5, 0.5),
        Position           = position,
        Size               = size,
        BackgroundTransparency = 1,
        Image              = Assets.Glow,
        ImageColor3        = Color3.fromRGB(226, 218, 230),
        ImageTransparency  = transparency,
        ZIndex             = 0,
        Parent             = parent,
    })

    create("UIGradient", {
        Color    = ColorSequence.new(Color3.fromRGB(255, 255, 255), Theme.Accent),
        Rotation = rotation or 90,
        Parent   = img,
    })

    return img
end

local function dividerLine(parent)
    return create("Frame", {
        Position               = UDim2.fromOffset(0, 0),
        Size                   = UDim2.new(1, 0, 0, 1),
        BackgroundColor3       = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.93,
        BorderSizePixel        = 0,
        ZIndex                 = 0,
        Parent                 = parent,
    })
end

local function applyIcon(imageLabel, icon)
    local image, offset, size = resolveIcon(icon)
    if not image then return end

    imageLabel.Image          = image
    imageLabel.ImageRectOffset = offset or Vector2.zero
    imageLabel.ImageRectSize   = size or Vector2.zero
end

local function getUIParent()
    local hui

    pcall(function()
        if typeof(gethui) == "function" then
            hui = gethui()
        end
    end)

    if typeof(hui) == "Instance" then
        return hui
    end

    local coreGui
    pcall(function()
        coreGui = game:GetService("CoreGui")
        local test = Instance.new("Folder")
        test.Parent = coreGui
        test:Destroy()
    end)

    if coreGui then
        return coreGui
    end

    return LocalPlayer:WaitForChild("PlayerGui")
end

local lastMouseTick, lastMousePos = nil, Vector2.zero

local function mousePos()
    local now = time()
    if lastMouseTick ~= now then
        lastMouseTick = now
        lastMousePos  = GuiService:GetGuiInset()
    end
    return UserInputService:GetMouseLocation() - lastMousePos
end

local function isPrimary(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local function iconButton(parent, icon, color, position)
    local holder = create("Frame", {
        AnchorPoint            = Vector2.new(0, 0.5),
        Position               = position,
        Size                   = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        Parent                 = parent,
    })

    local img = create("ImageLabel", {
        Size                   = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ImageColor3            = color,
        ScaleType              = Enum.ScaleType.Fit,
        Parent                 = holder,
    })

    applyIcon(img, icon)
    return holder, img
end

local function chevron(parent, anchorX, offsetX)
    local holder = create("Frame", {
        AnchorPoint            = Vector2.new(anchorX, 0.5),
        Position               = UDim2.new(anchorX, offsetX, 0.5, 0),
        Size                   = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1,
        Parent                 = parent,
    })

    local api = {}

    local img = create("ImageLabel", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.fromScale(0.5, 0.5),
        Size                   = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        ImageColor3            = Theme.Muted,
        ScaleType              = Enum.ScaleType.Fit,
        Parent                 = holder,
    })

    applyIcon(img, "chevron-down")

    if img.Image ~= "" then
        function api:Set(open)
            tween(img, {
                Rotation     = open and 180 or 0,
                ImageColor3  = open and Theme.Accent or Theme.Muted,
            }, 0.3, Enum.EasingStyle.Quint)
        end
        return api
    end

    img:Destroy()

    local function makeArrow(rotation, transparency)
        return textLabel({
            AnchorPoint    = Vector2.new(0.5, 0.5),
            Position       = UDim2.fromScale(0.5, 0.5),
            Size           = UDim2.fromOffset(18, 18),
            Text           = "›",
            TextSize       = 22,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextColor3     = Theme.Muted,
            TextTransparency = transparency,
            Rotation       = rotation,
            Parent         = holder,
        })
    end

    local down = makeArrow(90, 0)
    local up   = makeArrow(270, 1)

    function api:Set(open)
        tween(down, { TextTransparency = open and 1 or 0 }, 0.2)
        tween(up, {
            TextTransparency = open and 0 or 1,
            TextColor3       = open and Theme.Accent or Theme.Muted,
        }, 0.2)
    end

    return api
end

local ripplePool = {}

local function ripple(parent)
    local pos  = mousePos()
    local size = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2.2

    local circle = table.remove(ripplePool)
    if not circle then
        circle = create("Frame", {
            AnchorPoint      = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel  = 0,
        })
        corner(circle, UDim.new(1, 0))
    end

    circle.Position               = UDim2.fromOffset(pos.X - parent.AbsolutePosition.X, pos.Y - parent.AbsolutePosition.Y)
    circle.Size                   = UDim2.fromOffset(0, 0)
    circle.BackgroundTransparency = 0.82
    circle.ZIndex                 = parent.ZIndex + 1
    circle.Parent                 = parent

    tween(circle, {
        Size                   = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
    }, 0.55)

    task.delay(0.55, function()
        circle.Parent = nil
        if #ripplePool < 4 then
            table.insert(ripplePool, circle)
        else
            circle:Destroy()
        end
    end)
end

local function flashStroke(s)
    if not s then return end
    tween(s, { Color = Theme.Accent, Transparency = 0.2 }, 0.08)
    task.delay(0.12, function()
        tween(s, { Color = Theme.Stroke, Transparency = 0 }, 0.35)
    end)
end

local function hoverStroke(button, strokeInst)
    button.MouseEnter:Connect(function()
        tween(strokeInst, { Color = Theme.StrokeHover }, 0.12)
    end)
    button.MouseLeave:Connect(function()
        tween(strokeInst, { Color = Theme.Stroke }, 0.25)
    end)
end

local keyNames = {
    [Enum.KeyCode.LeftControl]  = "LCtrl",
    [Enum.KeyCode.RightControl] = "RCtrl",
    [Enum.KeyCode.LeftShift]    = "LShift",
    [Enum.KeyCode.RightShift]   = "RShift",
    [Enum.KeyCode.LeftAlt]      = "LAlt",
    [Enum.KeyCode.RightAlt]     = "RAlt",
    [Enum.KeyCode.Return]       = "Enter",
    [Enum.KeyCode.Escape]       = "Esc",
    [Enum.KeyCode.Backspace]    = "Backspace",
}

local function keyName(key)
    if key == nil then return "None" end
    return keyNames[key] or key.Name
end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[AirFlow] callback error: " .. tostring(err))
    end
end

local function numberHelper(min, max, step)
    local decimals = 0
    local str = tostring(step)
    local dot = str:find("%.")
    if dot then
        decimals = #str - dot
    end

    local fmt = "%." .. decimals .. "f"

    return {
        snap = function(v)
            v = math.floor(v / step + 0.5) * step
            return math.clamp(v, min, max)
        end,
        format = function(v)
            return string.format(fmt, v)
        end,
    }
end

local function makeRow(tab, className, height, opts)
    local props = {
        Size             = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel  = 0,
        LayoutOrder      = tab:_nextOrder(),
        Parent           = tab.List,
    }

    if className == "TextButton" then
        props.AutoButtonColor = false
        props.Text            = ""
    end

    local row = create(className, props)
    row:SetAttribute("NoDrag", true)
    corner(row)

    local s = stroke(row, Theme.Stroke)
    return row, s
end

local function makeTitleDesc(row, title, desc, rightPad)
    local titleLabel, descLabel

    if desc then
        local y = (ROW_H_DESC - 38) / 2
        titleLabel = textLabel({
            Position = UDim2.fromOffset(14, y),
            Size     = UDim2.new(1, -(14 + rightPad), 0, 18),
            Text     = title,
            Parent   = row,
        })
        descLabel = textLabel({
            Position   = UDim2.fromOffset(14, y + 20),
            Size       = UDim2.new(1, -(14 + rightPad), 0, 17),
            Text       = desc,
            TextSize   = 13,
            FontFace   = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent     = row,
        })
    else
        titleLabel = textLabel({
            Position = UDim2.fromOffset(14, 0),
            Size     = UDim2.new(1, -(14 + rightPad), 1, 0),
            Text     = title,
            Parent   = row,
        })
    end

    return titleLabel, descLabel
end

local function baseControl(tab, opts, defaults, className, rightPad, fallbackName)
    opts = merge(opts, defaults)

    local height = opts.Desc and ROW_H_DESC or ROW_H
    local row, s = makeRow(tab, className or "Frame", height, opts)
    hoverStroke(row, s)

    local titleLabel, descLabel
    if rightPad then
        titleLabel, descLabel = makeTitleDesc(row, opts.Name or fallbackName, opts.Desc, rightPad)
    end

    return opts, row, s, height, titleLabel, descLabel
end

local function adjustTitleWidth(titleLabel, descLabel, rightPad)
    if titleLabel then
        titleLabel.Size = UDim2.new(1, -(14 + rightPad), titleLabel.Size.Y.Scale, titleLabel.Size.Y.Offset)
    end
    if descLabel then
        descLabel.Size = UDim2.new(1, -(14 + rightPad), 0, descLabel.Size.Y.Offset)
    end
end


local Tab = {}
Tab.__index = Tab

function Tab:_nextOrder()
    self._order += 1
    return self._order
end

function Tab:Section(opts)
    if type(opts) == "table" then
        opts = opts.Name or opts.Title or ""
    end

    local holder = create("Frame", {
        Size                   = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder            = self:_nextOrder(),
        Parent                 = self.List,
    })

    local label = textLabel({
        Position               = UDim2.fromOffset(2, 8),
        Size                   = UDim2.new(0, 0, 0, 16),
        AutomaticSize          = Enum.AutomaticSize.X,
        Text                   = string.upper(opts),
        TextSize               = 12,
        TextColor3             = Theme.Muted,
        TextTruncate           = Enum.TextTruncate.None,
        Parent                 = holder,
    })

    local line = create("Frame", {
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, 0, 0, 16),
        Size             = UDim2.new(1, -12, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel  = 0,
        Parent           = holder,
    })

    label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        line.Size = UDim2.new(1, -(label.AbsoluteSize.X + 14), 0, 1)
    end)

    task.defer(function()
        line.Size = UDim2.new(1, -(label.AbsoluteSize.X + 14), 0, 1)
    end)

    return registerControl(self, {}, {
        Set = function(_, text)
            label.Text = string.upper(text)
        end,
    }, holder, "Section")
end

function Tab:Divider()
    local line = create("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel  = 0,
        LayoutOrder      = self:_nextOrder(),
        Parent           = self.List,
    })
    return registerControl(self, {}, {}, line, "Divider")
end

function Tab:Label(opts)
    opts = merge(opts, { Name = "Text", Title = "Text" })

    local label = textLabel({
        Size        = UDim2.new(1, 0, 0, 18),
        Text        = opts.Text or "",
        TextSize    = 13,
        FontFace    = Fonts.Regular,
        TextColor3  = opts.Color or Theme.Muted,
        LayoutOrder = self:_nextOrder(),
        Parent      = self.List,
    })
    padding(label, 2)

    local api = {
        Set = function(_, text)
            label.Text = tostring(text)
        end,
        Get = function()
            return label.Text
        end,
    }

    if type(opts.Update) == "function" then
        local rate = math.max(tonumber(opts.UpdateRate) or 1, 0.05)
        local alive = true

        api._listeners = api._listeners or {}
        table.insert(api._listeners, function()
            alive = false
        end)

        task.spawn(function()
            while alive and label.Parent do
                local ok, value = pcall(opts.Update)
                if ok and value ~= nil then
                    label.Text = tostring(value)
                elseif not ok then
                    warn("[AirFlow] label update error: " .. tostring(value))
                end
                task.wait(rate)
            end
        end)

        function api:SetUpdateRate(newRate)
            rate = math.max(tonumber(newRate) or rate, 0.05)
        end
    end

    return registerControl(self, opts, api, label, "Label")
end

function Tab:Paragraph(opts)
    opts = merge(opts, { Title = "Name" })

    local row = makeRow(self, "Frame", 0, opts)
    row.AutomaticSize = Enum.AutomaticSize.Y
    padding(row, 14, 14, 11, 12)

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 4),
        Parent    = row,
    })

    textLabel({
        Size        = UDim2.new(1, 0, 0, 14),
        Text        = opts.Name or "",
        LayoutOrder = 1,
        Parent      = row,
    })

    local content = textLabel({
        Size               = UDim2.new(1, 0, 0, 0),
        AutomaticSize      = Enum.AutomaticSize.Y,
        Text               = opts.Content or "",
        TextSize           = 13,
        FontFace           = Fonts.Regular,
        TextColor3         = Theme.Muted,
        TextWrapped        = true,
        TextTruncate       = Enum.TextTruncate.None,
        TextYAlignment     = Enum.TextYAlignment.Top,
        LayoutOrder        = 2,
        Parent             = row,
    })

    return registerControl(self, opts, {
        Set = function(_, text)
            content.Text = text
        end,
    }, row, "Paragraph")
end

function Tab:Button(opts)
    opts = merge(opts, { Title = "Name", Description = "Desc" })

    local primary = opts.Style == "Primary"
    local height  = opts.Desc and ROW_H_DESC or ROW_H

    local row, s = makeRow(self, "TextButton", height, opts)
    row.ClipsDescendants = true

    if primary then
        row.BackgroundColor3       = Theme.Accent
        row.BackgroundTransparency = 0.12
        s.Color                    = Theme.Accent
        s.Transparency             = 0.4

        row.MouseEnter:Connect(function()
            tween(row, { BackgroundTransparency = 0 }, 0.12)
            tween(s, { Transparency = 0 }, 0.12)
        end)
        row.MouseLeave:Connect(function()
            tween(row, { BackgroundTransparency = 0.12 }, 0.25)
            tween(s, { Transparency = 0.4 }, 0.25)
        end)
    else
        hoverStroke(row, s)
    end

    local textColor = primary and Theme.AccentDark or Theme.Text
    local iconPad   = 0

    if opts.Icon then
        iconButton(row, opts.Icon, primary and Theme.AccentDark or Theme.Accent, UDim2.new(0, 14, 0.5, 0))
        iconPad = 26
    end

    local titleLabel = makeTitleDesc(row, opts.Name or "Button", opts.Desc, 30)

    if iconPad > 0 then
        for _, child in ipairs(row:GetChildren()) do
            if child:IsA("TextLabel") then
                child.Position += UDim2.fromOffset(iconPad, 0)
                child.Size     -= UDim2.fromOffset(iconPad, 0)
            end
        end
    end

    if primary then
        for _, child in ipairs(row:GetChildren()) do
            if child:IsA("TextLabel") then
                child.TextColor3 = textColor
            end
        end
    end

    iconButton(row, "chevron-right", primary and Theme.AccentDark or Theme.Muted, UDim2.new(1, -30, 0.5, 0))

    row.MouseButton1Click:Connect(function()
        ripple(row)
        safeCall(opts.Callback)
    end)

    return registerControl(self, opts, {
        SetText = function(_, text)
            titleLabel.Text = text
        end,
    }, row, "Button")
end

function Tab:Toggle(opts)
    local row, s
    opts, row, s = baseControl(self, opts, {
        Title = "Name", Description = "Desc",
        CurrentValue = "Default", Value = "Default",
    }, "TextButton", 56, "Toggle")

    local track = create("Frame", {
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, -14, 0.5, 0),
        Size             = isTouch and UDim2.fromOffset(44, 24) or UDim2.fromOffset(36, 20),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel  = 0,
        Parent           = row,
    })
    corner(track, UDim.new(1, 0))
    stroke(track, Theme.Stroke)

    local knob = create("Frame", {
        AnchorPoint      = Vector2.new(0, 0.5),
        Position         = UDim2.new(0, 3, 0.5, 0),
        Size             = isTouch and UDim2.fromOffset(18, 18) or UDim2.fromOffset(14, 14),
        BackgroundColor3 = Theme.Muted,
        BorderSizePixel  = 0,
        Parent           = track,
    })
    corner(knob, UDim.new(1, 0))

    local glowImg = create("ImageLabel", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.fromScale(0.5, 0.5),
        Size                   = UDim2.new(1, 24, 1, 24),
        BackgroundTransparency = 1,
        Image                  = Assets.Glow,
        ImageColor3            = Theme.Accent,
        ImageTransparency      = 1,
        ZIndex                 = 0,
        Parent                 = track,
    })

    local api = { Value = opts.Default == true }

    local function visual(animate)
        local on = api.Value
        local t  = animate and 0.25 or 0

        tween(track, { BackgroundColor3 = on and Theme.Accent or Theme.Surface3 }, t)
        tween(glowImg, { ImageTransparency = on and 0.75 or 1 }, t)

        local knobSize = isTouch and 18 or 14
        tween(knob, {
            Position         = on and UDim2.new(0, (isTouch and 44 or 36) - 3 - knobSize, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = on and Theme.AccentDark or Theme.Muted,
        }, t, Enum.EasingStyle.Back)

        if animate then
            tween(knob, { Size = UDim2.fromOffset(knobSize + 4, knobSize - 2) }, 0.08)
            task.delay(0.08, function()
                tween(knob, { Size = UDim2.fromOffset(knobSize, knobSize) }, 0.2, Enum.EasingStyle.Back)
            end)
        end
    end

    local suppressFlash = false

    function api:Set(value, silent)
        value = value == true
        if value == api.Value then return end

        api.Value = value
        visual(true)

        if not suppressFlash then
            flashStroke(s)
        end

        if not silent then
            safeCall(opts.Callback, value)
        end
    end

    function api:Get()
        return api.Value
    end

    visual(false)

    row.MouseButton1Click:Connect(function()
        suppressFlash = true
        api:Set(not api.Value)
        suppressFlash = false
    end)

    local control = registerControl(self, opts, api, row, "Toggle")

    if api.Value then
        safeCall(opts.Callback, true)
    end

    return control
end

function Tab:Slider(opts)
    opts = merge(opts, {
        Title = "Name", Description = "Desc",
        CurrentValue = "Default", Value = "Default",
        Increment = "Step",
    })

    local min    = opts.Min or 0
    local max    = opts.Max or 100
    local step   = opts.Step or 1
    local suffix = opts.Suffix or ""
    local helper = numberHelper(min, max, step)

    local row, s = makeRow(self, "Frame", ROW_H_DESC, opts)
    hoverStroke(row, s)

    textLabel({
        Position = UDim2.fromOffset(14, 12),
        Size     = UDim2.new(1, -120, 0, 18),
        Text     = opts.Name or "Slider",
        Parent   = row,
    })

    local valueBox = create("Frame", {
        AnchorPoint      = Vector2.new(1, 0),
        Position         = UDim2.new(1, -10, 0, 9),
        Size             = UDim2.fromOffset(40, 24),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        Parent           = row,
    })
    corner(valueBox, UDim.new(0, 6))
    local valueStroke = stroke(valueBox)

    local valueLabel = textLabel({
        Size           = UDim2.new(1, 0, 1, 0),
        TextSize       = 13,
        TextColor3     = Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate   = Enum.TextTruncate.None,
        Parent         = valueBox,
    })

    local valueInput = create("TextBox", {
        Position               = UDim2.fromOffset(9, 0),
        Size                   = UDim2.new(0, 0, 1, 0),
        AutomaticSize          = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text                   = "",
        TextColor3             = Theme.Text,
        TextSize               = 13,
        FontFace               = Fonts.Medium,
        TextXAlignment         = Enum.TextXAlignment.Left,
        ClearTextOnFocus       = false,
        Visible                = false,
        Parent                 = valueBox,
    })
    create("UISizeConstraint", { MinSize = Vector2.new(14, 0), Parent = valueInput })

    local suffixLabel = textLabel({
        Size           = UDim2.new(0, 0, 1, 0),
        AutomaticSize  = Enum.AutomaticSize.X,
        Text           = suffix,
        TextSize       = 13,
        TextColor3     = Theme.Accent,
        TextTruncate   = Enum.TextTruncate.None,
        Visible        = false,
        Parent         = valueBox,
    })

    local valueHit = create("TextButton", {
        Size             = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text             = "",
        AutoButtonColor  = false,
        ZIndex           = 2,
        Parent           = valueBox,
    })

    local editing = false

    local function resizeValueBox(instant)
        local w
        if editing then
            w = 9 + valueInput.AbsoluteSize.X / self.Window.Scale.Scale + suffixLabel.TextBounds.X + 9
            suffixLabel.Position = UDim2.fromOffset(9 + valueInput.AbsoluteSize.X / self.Window.Scale.Scale, 0)
        else
            w = valueLabel.TextBounds.X + 18
        end

        w = math.max(w, 36)

        if instant then
            valueBox.Size = UDim2.fromOffset(w, 24)
        else
            tween(valueBox, { Size = UDim2.fromOffset(w, 24) }, 0.2)
        end
    end

    valueLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        if not editing then resizeValueBox(false) end
    end)
    valueInput:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if editing then resizeValueBox(false) end
    end)

    local track = create("Frame", {
        Position         = UDim2.new(0, 14, 0, ROW_H_DESC - 18),
        Size             = UDim2.new(1, -28, 0, 5),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel  = 0,
        Parent           = row,
    })
    corner(track, UDim.new(1, 0))

    local fill = create("Frame", {
        Size             = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        Parent           = track,
    })
    corner(fill, UDim.new(1, 0))

    local glowKnob = create("ImageLabel", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0, 0, 0.5, 0),
        Size                   = UDim2.fromOffset(28, 28),
        BackgroundTransparency = 1,
        Image                  = Assets.Glow,
        ImageColor3            = Theme.Accent,
        ImageTransparency      = 0.85,
        ZIndex                 = 2,
        Parent                 = track,
    })

    local knob = create("Frame", {
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0, 0, 0.5, 0),
        Size             = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        ZIndex           = 3,
        Parent           = track,
    })
    corner(knob, UDim.new(1, 0))

    local hit = create("TextButton", {
        Position             = UDim2.new(0, 8, 0, ROW_H_DESC - (isTouch and 37 or 31)),
        Size                 = UDim2.new(1, -16, 0, isTouch and 40 or 28),
        BackgroundTransparency = 1,
        Text                 = "",
        AutoButtonColor      = false,
        ZIndex               = 4,
        Parent               = row,
    })

    local api = {
        Value = math.clamp(opts.Default or min, min, max),
    }
    local dragging = false

    valueHit.MouseEnter:Connect(function()
        tween(valueStroke, { Color = Theme.StrokeHover }, 0.12)
    end)
    valueHit.MouseLeave:Connect(function()
        if not valueInput:IsFocused() then
            tween(valueStroke, { Color = Theme.Stroke }, 0.2)
        end
    end)

    valueHit.MouseButton1Click:Connect(function()
        editing = true
        valueInput.Text = helper.format(api.Value)
        valueLabel.Visible = false
        valueInput.Visible = true
        suffixLabel.Visible = suffix ~= ""
        valueHit.Visible = false
        tween(valueStroke, { Color = Theme.StrokeHover }, 0.12)
        valueInput:CaptureFocus()
        task.defer(resizeValueBox, false)
    end)

    valueInput.FocusLost:Connect(function()
        local num = tonumber(valueInput.Text)
        editing = false
        valueInput.Visible = false
        suffixLabel.Visible = false
        valueLabel.Visible = true
        valueHit.Visible = true
        tween(valueStroke, { Color = Theme.Stroke }, 0.2)

        if num then
            api:Set(num)
        end
        resizeValueBox(false)
    end)

    hit.MouseEnter:Connect(function()
        if not dragging then
            tween(glowKnob, { ImageTransparency = 0.78, Size = UDim2.fromOffset(34, 34) }, 0.15)
        end
    end)
    hit.MouseLeave:Connect(function()
        if not dragging then
            tween(glowKnob, { ImageTransparency = 0.85, Size = UDim2.fromOffset(28, 28) }, 0.2)
        end
    end)

    local snap = helper.snap

    local function alpha()
        return (max - min == 0) and 0 or (api.Value - min) / (max - min)
    end

    local function move(a, duration, style)
        style = style or Enum.EasingStyle.Linear
        tween(fill, { Size = UDim2.new(a, 0, 1, 0) }, duration, style)
        tween(knob, { Position = UDim2.new(a, 0, 0.5, 0) }, duration, style)
        tween(glowKnob, { Position = UDim2.new(a, 0, 0.5, 0) }, duration, style)
    end

    local function refresh(duration, style)
        move(alpha(), duration, style)
        valueLabel.Text = helper.format(api.Value) .. suffix
    end

    local function bounce(from)
        local a = alpha()
        local trackW = math.max(track.AbsoluteSize.X, 1)
        local delta = (a >= from and 1 or -1) * (5 / trackW)

        move(math.clamp(a + delta, 0, 1), 0.22, Enum.EasingStyle.Quint)
        task.delay(0.22, function()
            if not dragging then
                move(alpha(), 0.18, Enum.EasingStyle.Quint)
            end
        end)
        valueLabel.Text = helper.format(api.Value) .. suffix
    end

    local function pulse()
        tween(knob, { Size = UDim2.fromOffset(14, 12) }, 0.08)
        tween(glowKnob, { Size = UDim2.fromOffset(32, 32), ImageTransparency = 0.78 }, 0.12)
        task.delay(0.1, function()
            tween(knob, { Size = UDim2.fromOffset(12, 12) }, 0.25, Enum.EasingStyle.Quint)
            tween(glowKnob, { Size = UDim2.fromOffset(28, 28), ImageTransparency = 0.85 }, 0.25)
        end)
    end

    function api:Set(value, silent)
        value = snap(tonumber(value) or min)
        if value == api.Value then return end

        local prev = alpha()
        api.Value = value

        if dragging then
            refresh(0.05)
        else
            bounce(prev)
            pulse()
            flashStroke(s)
        end

        if not silent then
            safeCall(opts.Callback, value)
        end
    end

    function api:Get()
        return api.Value
    end

    local function setFromX(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        api:Set(min + (max - min) * a)
    end

    hit.InputBegan:Connect(function(input)
        if isPrimary(input) then
            dragging = true
            tween(knob, { Size = UDim2.fromOffset(16, 16) }, 0.15, Enum.EasingStyle.Back)
            tween(glowKnob, { Size = UDim2.fromOffset(44, 44), ImageTransparency = 0.7 }, 0.15)
            setFromX(mousePos().X)
        end
    end)

    self.Window:_listen("Changed", function(input)
        if dragging and isMove(input) then
            setFromX(mousePos().X)
        end
    end, api)

    self.Window:_listen("Ended", function(input)
        if dragging and isPrimary(input) then
            dragging = false
            tween(knob, { Size = UDim2.fromOffset(12, 12) }, 0.2)
            tween(glowKnob, { Size = UDim2.fromOffset(28, 28), ImageTransparency = 0.85 }, 0.2)
        end
    end, api)

    api.Value = snap(api.Value)
    refresh(0)
    task.defer(resizeValueBox, true)

    return registerControl(self, opts, api, row, "Slider")
end

function Tab:Dropdown(opts)
    opts = merge(opts, {
        Title = "Name", Description = "Desc",
        CurrentOption = "Default", Value = "Default",
        MultipleOptions = "Multi", Values = "Options",
    })

    if opts.Multi and type(opts.Default) ~= "table" and opts.Default ~= nil then
        opts.Default = { opts.Default }
    elseif not opts.Multi and type(opts.Default) == "table" then
        opts.Default = opts.Default[1]
    end

    local multi   = opts.Multi == true
    local options = opts.Options or {}

    local row, s, height
    opts, row, s, height = baseControl(self, opts, {}, "Frame")
    row.ClipsDescendants = true

    local header = create("TextButton", {
        Size             = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        Text             = "",
        AutoButtonColor  = false,
        Parent           = row,
    })

    local titleLabel, descLabel = makeTitleDesc(header, opts.Name or "Dropdown", opts.Desc, 180)

    local chip = create("Frame", {
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, -10, 0.5, 0),
        Size             = UDim2.fromOffset(60, CHIP_H),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        Parent           = header,
    })
    corner(chip, UDim.new(0, 6))
    local chipStroke = stroke(chip)

    local valueLabel = textLabel({
        Position         = UDim2.fromOffset(10, 0),
        Size             = UDim2.new(1, -34, 1, 0),
        TextColor3       = Theme.Muted,
        TextSize         = 13,
        TextTruncate     = Enum.TextTruncate.None,
        ClipsDescendants = true,
        Parent           = chip,
    })

    local arrow = chevron(chip, 1, -6)

    local measureLabel = textLabel({
        Size          = UDim2.fromOffset(0, CHIP_H),
        AutomaticSize = Enum.AutomaticSize.X,
        TextSize      = 13,
        Visible       = false,
        Parent        = chip,
    })

    local displayText = ""

    local function truncated()
        measureLabel.Text = displayText
        if measureLabel.TextBounds.X <= 146 then
            return displayText
        end

        local str = displayText
        while #str > 1 do
            str = str:sub(1, -2)
            measureLabel.Text = str .. ".."
            if measureLabel.TextBounds.X <= 146 then
                return str .. ".."
            end
        end
        return ".."
    end

    local function resizeChip(instant)
        local w = math.clamp(valueLabel.TextBounds.X + 10 + 34, 60, 190)
        adjustTitleWidth(titleLabel, descLabel, w + 20)

        if instant then
            chip.Size = UDim2.fromOffset(w, CHIP_H)
        else
            tween(chip, { Size = UDim2.fromOffset(w, CHIP_H) }, 0.2)
        end
    end

    valueLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        resizeChip(false)
    end)

    local list = create("Frame", {
        Position               = UDim2.new(0, 10, 0, height),
        Size                   = UDim2.new(1, -20, 0, 0),
        BackgroundTransparency = 1,
        Parent                 = row,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 4),
        Parent    = list,
    })

    local api = { Open = false }
    local selected = {}
    local items = {}
    local searchQuery = ""

    local searchAfter = opts.SearchAfter or 6

    local searchBox = create("Frame", {
        Size                   = UDim2.new(1, 0, 0, ITEM_H),
        BackgroundColor3       = Theme.Surface,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        LayoutOrder            = 0,
        Visible                = false,
        Parent                 = list,
    })
    corner(searchBox, UDim.new(0, 6))
    local searchStroke = stroke(searchBox, Theme.Stroke, 1)

    local searchInput = create("TextBox", {
        Position               = UDim2.fromOffset(12, 0),
        Size                   = UDim2.new(1, -20, 1, 0),
        BackgroundTransparency = 1,
        Text                   = "",
        PlaceholderText        = "Search",
        PlaceholderColor3      = Theme.Muted,
        TextColor3             = Theme.Text,
        TextSize               = 13,
        FontFace               = Fonts.Regular,
        TextXAlignment         = Enum.TextXAlignment.Left,
        ClearTextOnFocus       = false,
        TextTransparency       = 1,
        Parent                 = searchBox,
    })

    local function matches(name)
        return searchQuery == "" or string.find(string.lower(tostring(name)), searchQuery, 1, true) ~= nil
    end

    if multi then
        for _, v in ipairs(opts.Default or {}) do
            selected[v] = true
        end
    elseif opts.Default ~= nil then
        selected[opts.Default] = true
    end

    local function currentValue()
        if multi then
            local list = {}
            for _, name in ipairs(options) do
                if selected[name] then
                    table.insert(list, name)
                end
            end
            return list
        end

        for _, name in ipairs(options) do
            if selected[name] then
                return name
            end
        end
        return nil
    end

    local function refreshDisplay()
        local value = currentValue()

        if multi then
            displayText = #value > 0 and table.concat(value, ", ") or "None"
        else
            displayText = value ~= nil and tostring(value) or "None"
        end

        valueLabel.Text = truncated()

        for name, item in pairs(items) do
            local on = selected[name] == true
            if item.On ~= on then
                item.On = on
                tween(item.Label, { TextColor3 = on and Theme.Text or Theme.Muted }, 0.15)

                if api.Open then
                    tween(item.Check, { ImageTransparency = on and 0 or 1 }, 0.15)
                    tween(item.CheckScale, {
                        Scale = on and 1 or 0.6,
                    }, on and 0.3 or 0.15, on and Enum.EasingStyle.Back or Enum.EasingStyle.Quint)
                end
            end
        end
    end

    local showAll = false

    local seeMoreBtn = create("TextButton", {
        Size                   = UDim2.new(1, 0, 0, ITEM_H),
        BackgroundColor3       = Theme.Surface,
        BackgroundTransparency = 1,
        Text                   = "See More  (Recommended: Use Search)",
        TextColor3             = Theme.Accent,
        TextSize               = 13,
        FontFace               = Fonts.Regular,
        AutoButtonColor        = false,
        LayoutOrder            = 999999,
        Visible                = false,
        Parent                 = list,
    })
    corner(seeMoreBtn, UDim.new(0, 6))

    local function visibleCount()
        local count = 0
        for _, name in ipairs(options) do
            local item = items[name]
            if item and item.Frame.Visible then
                count += 1
            end
        end
        if seeMoreBtn.Visible then
            count += 1
        end
        return count
    end


    local buildItem
    local revealing = false

    local function updateVisibility()
        local visible = 0
        local searching = (searchQuery ~= "")
        local open = api.Open
        local cap = showAll and math.huge or (searching and 60 or 10)

        for idx, name in ipairs(options) do
            local item = items[name]

            if not open then
                if item then
                    item.Frame.Visible = false
                end
            else
                local show = matches(name) and visible < cap

                if show then
                    visible += 1

                    if not item and not revealing then
                        item = buildItem(name, idx)
                    end

                    if item then
                        item.Frame.Visible = true
                        item.Frame.LayoutOrder = idx
                        item.Frame.BackgroundTransparency = 0

                        if not item.Stroke then
                            item.Stroke = stroke(item.Frame, Theme.Stroke, 0)
                        end

                        item.Check.ImageTransparency = item.On and 0 or 1
                        item.CheckScale.Scale = item.On and 1 or 0.6
                    end
                elseif item then
                    item.Frame.Visible = false
                end
            end
        end

        seeMoreBtn.Visible = open and not searching and not showAll and #options > 10
    end

    local function listHeight()
        local count = visibleCount() + (searchBox.Visible and 1 or 0)
        return height + count * (ITEM_H + 4) + 8
    end

    local function destroyItems()
        for _, name in ipairs(options) do
            local item = items[name]
            if item then
                item.Frame:Destroy()
            end
        end
        items = {}
    end

    local function setOpen(state)
        api.Open = state
        searchBox.Visible = #options > searchAfter

        if not state then
            searchQuery = ""
            searchInput.Text = ""
            showAll = false
        end

        updateVisibility()

        tween(row, { Size = UDim2.new(1, 0, 0, state and listHeight() or height) }, 0.3, Enum.EasingStyle.Quint)
        tween(searchBox, { BackgroundTransparency = state and 0 or 1 }, 0.2)
        tween(searchStroke, { Transparency = state and 0 or 1 }, 0.2)
        tween(searchInput, { TextTransparency = state and 0 or 1 }, 0.2)
        arrow:Set(state)
        tween(chipStroke, { Color = state and Theme.StrokeHover or Theme.Stroke }, 0.2)
    end

    local function revealAll()
        showAll = true
        seeMoreBtn.Visible = false

        if revealing then return end
        revealing = true

        task.spawn(function()
            local built = 0
            for idx, name in ipairs(options) do
                if matches(name) and not items[name] then
                    buildItem(name, idx)
                    built += 1
                    if built % 25 == 0 then
                        task.wait()
                    end
                end
            end

            revealing = false

            if api.Open then
                updateVisibility()
                tween(row, { Size = UDim2.new(1, 0, 0, listHeight()) }, 0.3, Enum.EasingStyle.Quint)
            end
        end)
    end

    buildItem = function(name, order)
        local rowBtn = create("TextButton", {
            Size                   = UDim2.new(1, 0, 0, ITEM_H),
            BackgroundColor3       = Theme.Surface,
            BackgroundTransparency = 1,
            Text                   = "",
            AutoButtonColor        = false,
            LayoutOrder            = order,
            Visible                = false,
            Parent                 = list,
        })
        corner(rowBtn, UDim.new(0, 6))

        local check = create("ImageLabel", {
            AnchorPoint            = Vector2.new(1, 0.5),
            Position               = UDim2.new(1, -10, 0.5, 0),
            Size                   = UDim2.fromOffset(14, 14),
            BackgroundTransparency = 1,
            ImageColor3            = Theme.Accent,
            ImageTransparency      = 1,
            ScaleType              = Enum.ScaleType.Fit,
            Parent                 = rowBtn,
        })
        applyIcon(check, "check")

        local scale = create("UIScale", { Scale = 0.6, Parent = check })

        local label = textLabel({
            Position   = UDim2.fromOffset(12, -1),
            Size       = UDim2.new(1, -36, 1, 0),
            Text       = tostring(name),
            TextSize   = 13,
            TextColor3 = selected[name] and Theme.Text or Theme.Muted,
            Parent     = rowBtn,
        })

        rowBtn.MouseEnter:Connect(function()
            tween(label, { TextColor3 = Theme.Text }, 0.15)
            local item = items[name]
            if item and item.Stroke then
                tween(item.Stroke, { Color = Theme.StrokeHover }, 0.12)
            end
        end)

        rowBtn.MouseLeave:Connect(function()
            tween(label, { TextColor3 = selected[name] and Theme.Text or Theme.Muted }, 0.2)
            local item = items[name]
            if item and item.Stroke then
                tween(item.Stroke, { Color = Theme.Stroke }, 0.2)
            end
        end)

        rowBtn.MouseButton1Click:Connect(function()
            if selected[name] then
                selected[name] = nil
            else
                if not multi then
                    selected = {}
                end
                selected[name] = true
            end

            refreshDisplay()
            safeCall(opts.Callback, currentValue())

            if not multi and selected[name] then
                setOpen(false)
            end
        end)

        local item = {
            Frame      = rowBtn,
            Label      = label,
            Check      = check,
            CheckScale = scale,
            Stroke     = nil,
            On         = selected[name] == true,
        }
        items[name] = item
        return item
    end

    local function reconcile()
        local have = {}
        for idx, name in ipairs(options) do
            have[name] = idx
        end

        for name, item in pairs(items) do
            if have[name] == nil then
                item.Frame:Destroy()
                items[name] = nil
            end
        end

        if api.Open then
            updateVisibility()
            row.Size = UDim2.new(1, 0, 0, listHeight())
        end
    end

    seeMoreBtn.MouseButton1Click:Connect(revealAll)

    function api:Set(value, silent)
        selected = {}

        if multi then
            for _, v in ipairs(type(value) == "table" and value or { value }) do
                selected[v] = true
            end
        elseif value ~= nil then
            selected[value] = true
        end

        refreshDisplay()
        flashStroke(s)

        if not silent then
            safeCall(opts.Callback, currentValue())
        end
    end

    function api:Get()
        return currentValue()
    end

    function api:Refresh(newOptions, keepSelection)
        options = newOptions or {}
        if not keepSelection then
            selected = {}
        end

        if api.Open then
            reconcile()
        end

        refreshDisplay()

        if api.Open then
            setOpen(true)
        end
    end

    function api:SetOpen(state)
        if state == true and not api.Open then
            reconcile()
            refreshDisplay()
        end
        setOpen(state == true)
    end

    header.MouseButton1Click:Connect(function()
        if not api.Open then
            reconcile()
            refreshDisplay()
        end
        setOpen(not api.Open)
    end)

    searchInput:GetPropertyChangedSignal("Text"):Connect(function()
        searchQuery = string.lower(searchInput.Text)
        updateVisibility()

        if api.Open then
            tween(row, { Size = UDim2.new(1, 0, 0, listHeight()) }, 0.2, Enum.EasingStyle.Quint)
        end
    end)

    refreshDisplay()
    task.defer(resizeChip, true)

    row.AncestryChanged:Connect(function()
        if api.Open and row.Parent then
            api.Open = false
            showAll = false
            searchQuery = ""
            searchInput.Text = ""
            updateVisibility()
            destroyItems()
            row.Size = UDim2.new(1, 0, 0, height)
            searchBox.BackgroundTransparency = 1
            searchStroke.Transparency = 1
            searchInput.TextTransparency = 1
            arrow:Set(false)
            chipStroke.Color = Theme.Stroke
            seeMoreBtn.Visible = false
        end
    end)

    return registerControl(self, opts, api, row, "Dropdown")
end

function Tab:Input(opts)
    local row, s, height, titleLabel, descLabel
    opts, row, s, height, titleLabel, descLabel = baseControl(self, opts, {
        Title = "Name", Description = "Desc",
        PlaceholderText = "Placeholder",
        CurrentValue = "Default", Value = "Default",
    }, "Frame", 160, "Input")

    local box = create("Frame", {
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, -10, 0.5, 0),
        Size             = UDim2.fromOffset(170, 30),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel  = 0,
        Parent           = row,
    })
    corner(box, UDim.new(0, 6))
    local boxStroke = stroke(box)

    local hasIcon = opts.Icon
    if hasIcon then
        iconButton(box, hasIcon, Theme.Muted, UDim2.new(0, 8, 0.5, 0))
    end

    local input = create("TextBox", {
        Position               = UDim2.fromOffset(hasIcon and 30 or 8, 0),
        Size                   = UDim2.new(1, hasIcon and -38 or -16, 1, 0),
        BackgroundTransparency = 1,
        Text                   = opts.Default or "",
        PlaceholderText        = opts.Placeholder or "",
        PlaceholderColor3      = Theme.Muted,
        TextColor3             = Theme.Text,
        TextSize               = 14,
        FontFace               = Fonts.Regular,
        TextXAlignment         = Enum.TextXAlignment.Left,
        ClearTextOnFocus       = false,
        TextTruncate           = Enum.TextTruncate.None,
        ClipsDescendants       = true,
        Parent                 = box,
    })
    box.ClipsDescendants = true

    local focused = false
    local leftPad = (hasIcon and 30 or 8) + 8

    local function resize(instant)
        local avail = row.AbsoluteSize.X / self.Window.Scale.Scale
        local maxW  = math.clamp(avail - 14 - 110 - 20, 100, 200)
        local textW = input.TextBounds.X

        if #input.Text == 0 then
            textW = math.min(textW, 90)
        end

        local w = math.clamp(textW + leftPad + 12, 90, maxW) + (focused and 8 or 0)
        w = math.min(w, maxW + 8)

        adjustTitleWidth(titleLabel, descLabel, w + 20)

        if instant then
            box.Size = UDim2.fromOffset(w, 30)
        else
            tween(box, { Size = UDim2.fromOffset(w, 30) }, 0.18)
        end
    end

    row:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        resize(true)
    end)
    input:GetPropertyChangedSignal("Text"):Connect(function()
        resize(false)
    end)
    input:GetPropertyChangedSignal("TextBounds"):Connect(function()
        resize(false)
    end)

    task.defer(resize, true)

    input.Focused:Connect(function()
        focused = true
        tween(boxStroke, { Color = Theme.StrokeHover }, 0.15)
        resize(false)
    end)

    input.FocusLost:Connect(function(enter)
        focused = false
        tween(boxStroke, { Color = Theme.Stroke }, 0.15)
        resize(false)

        if opts.Numeric then
            local num = tonumber(input.Text)
            if not num then
                input.Text = ""
                return
            end
        end

        safeCall(opts.Callback, input.Text, enter)
    end)

    return registerControl(self, opts, {
        Set = function(_, text)
            input.Text = tostring(text)
            flashStroke(s)
        end,
        Get = function()
            return input.Text
        end,
    }, row, "Input")
end

function Tab:Keybind(opts)
    local row, s, height, titleLabel, descLabel
    opts, row, s, height, titleLabel, descLabel = baseControl(self, opts, {
        Title = "Name", Description = "Desc",
        CurrentKeybind = "Default", Value = "Default",
    }, "Frame", 110, "Keybind")

    if type(opts.Default) == "string" then
        opts.Default = Enum.KeyCode[opts.Default]
    end

    local chip = create("TextButton", {
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, -10, 0.5, 0),
        Size             = UDim2.fromOffset(44, CHIP_H),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel  = 0,
        Text             = "",
        AutoButtonColor  = false,
        ClipsDescendants = true,
        Parent           = row,
    })
    corner(chip, UDim.new(0, 6))
    local chipStroke = stroke(chip)

    local label = textLabel({
        Size           = UDim2.new(1, 0, 1, 0),
        TextSize       = 13,
        TextColor3     = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate   = Enum.TextTruncate.None,
        Parent         = chip,
    })

    local api = {
        Value     = opts.Default,
        Listening = false,
    }

    local function resize(instant)
        local w = math.max(label.TextBounds.X + 20, isTouch and 44 or 36)
        adjustTitleWidth(titleLabel, descLabel, w + 20)

        if instant then
            chip.Size = UDim2.fromOffset(w, CHIP_H)
        else
            tween(chip, { Size = UDim2.fromOffset(w, CHIP_H) }, 0.2)
        end
    end

    label:GetPropertyChangedSignal("TextBounds"):Connect(function()
        resize(false)
    end)

    local function refresh()
        label.Text = api.Listening and "..." or keyName(api.Value)
        tween(chipStroke, { Color = api.Listening and Theme.StrokeHover or Theme.Stroke }, 0.15)
        tween(label, { TextColor3 = api.Listening and Theme.Accent or Theme.Muted }, 0.15)
    end

    function api:Set(key, silent)
        local wasListening = api.Listening
        api.Value     = key
        api.Listening = false
        refresh()

        if not wasListening then
            flashStroke(s)
        end

        if not silent then
            safeCall(opts.OnChanged, key)
        end
    end

    chip.MouseButton1Click:Connect(function()
        api.Listening = not api.Listening
        refresh()
    end)

    self.Window:_listen("Began", function(input, gameProcessed)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        if api.Listening then
            self.Window._consumedKey = input.KeyCode
            self.Window._consumedAt  = os.clock()

            if input.KeyCode == Enum.KeyCode.Escape then
                api.Listening = false
                refresh()
            else
                api:Set(input.KeyCode)
            end
            return
        end

        if not gameProcessed and api.Value ~= nil and input.KeyCode == api.Value then
            safeCall(opts.Callback, input.KeyCode)
        end
    end, api)

    refresh()
    task.defer(resize, true)

    function api:Get()
        return api.Value
    end

    return registerControl(self, opts, api, row, "Keybind")
end

function Tab:ColorPicker(opts)
    local row, s, height
    opts, row, s, height = baseControl(self, opts, {
        Title = "Name", Description = "Desc",
        Color = "Default", CurrentValue = "Default", Value = "Default",
    }, "Frame")

    row.ClipsDescendants = true

    local header = create("TextButton", {
        Size             = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        Text             = "",
        AutoButtonColor  = false,
        Parent           = row,
    })
    makeTitleDesc(header, opts.Name or "Color", opts.Desc, 90)

    local preview = create("Frame", {
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, -34, 0.5, 0),
        Size             = UDim2.fromOffset(36, 20),
        BorderSizePixel  = 0,
        Parent           = header,
    })
    corner(preview, UDim.new(0, 6))
    stroke(preview, Theme.Stroke)

    local arrow = chevron(header, 1, -12)

    local panel = create("Frame", {
        Position               = UDim2.fromOffset(14, height + 2),
        Size                   = UDim2.new(1, -28, 0, 156),
        BackgroundTransparency = 1,
        Visible                = false,
        Parent                 = row,
    })

    local sv = create("TextButton", {
        Size             = UDim2.new(1, -30, 0, 110),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
        Text             = "",
        AutoButtonColor  = false,
        ClipsDescendants = true,
        Parent           = panel,
    })
    corner(sv, UDim.new(0, 6))

    local hueGrad = create("UIGradient", {
        Color  = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 0, 0)),
        Parent = sv,
    })

    local valueOverlay = create("Frame", {
        Size             = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel  = 0,
        Parent           = sv,
    })
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Rotation = 90,
        Parent   = valueOverlay,
    })

    local cursor = create("Frame", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Size                   = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        ZIndex                 = 3,
        Parent                 = sv,
    })
    corner(cursor, UDim.new(1, 0))
    stroke(cursor, Color3.new(1, 1, 1), 0, 2)

    local hueBar = create("TextButton", {
        AnchorPoint      = Vector2.new(1, 0),
        Position         = UDim2.new(1, 0, 0, 0),
        Size             = UDim2.fromOffset(14, 110),
        BorderSizePixel  = 0,
        Text             = "",
        AutoButtonColor  = false,
        Parent           = panel,
    })
    corner(hueBar, UDim.new(0, 6))

    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,                   Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(1/6,                 Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(2/6,                 Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.5,                 Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(4/6,                 Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(5/6,                 Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1,                   Color3.fromRGB(255, 0, 0)),
        }),
        Rotation = 90,
        Parent   = hueBar,
    })

    local hueCursor = create("Frame", {
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0.5, 0, 0, 0),
        Size             = UDim2.fromOffset(18, 5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
        ZIndex           = 3,
        Parent           = hueBar,
    })
    corner(hueCursor, UDim.new(1, 0))
    stroke(hueCursor, Theme.AccentDark, 0.4)

    local hexBox = create("Frame", {
        Position         = UDim2.fromOffset(6, 122),
        Size             = UDim2.fromOffset(118, 28),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel  = 0,
        Parent           = panel,
    })
    corner(hexBox, UDim.new(0, 6))
    local hexStroke = stroke(hexBox)

    local hexInput = create("TextBox", {
        Position               = UDim2.fromOffset(14, 0),
        Size                   = UDim2.new(1, -24, 1, 0),
        BackgroundTransparency = 1,
        Text                   = "",
        TextTruncate           = Enum.TextTruncate.None,
        ClipsDescendants       = false,
        TextColor3             = Theme.Text,
        TextSize               = 13,
        FontFace               = Fonts.Regular,
        TextXAlignment         = Enum.TextXAlignment.Left,
        ClearTextOnFocus       = false,
        Parent                 = hexBox,
    })

    local rgbLabel = textLabel({
        Position       = UDim2.fromOffset(134, 122),
        Size           = UDim2.new(1, -134, 0, 28),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize       = 13,
        FontFace       = Fonts.Regular,
        TextColor3     = Theme.Muted,
        Parent         = panel,
    })

    local api = { Open = false }
    local h, sVal, v = Color3.toHSV(opts.Default or Theme.Accent)
    local dragMode

    local function toHex(color)
        return string.format("#%02X%02X%02X",
            math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5))
    end

    local function refresh(duration)
        local color = Color3.fromHSV(h, sVal, v)
        api.Value = color
        preview.BackgroundColor3 = color
        hueGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(h, 1, 1))

        tween(cursor, { Position = UDim2.fromScale(sVal, 1 - v) }, duration, Enum.EasingStyle.Linear)
        tween(hueCursor, { Position = UDim2.new(0.5, 0, h, 0) }, duration, Enum.EasingStyle.Linear)

        if not hexInput:IsFocused() then
            hexInput.Text = toHex(color)
        end

        rgbLabel.Text = string.format("RGB %d, %d, %d",
            math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5))
    end

    local function apply(duration, silent)
        refresh(duration)
        if not silent then
            safeCall(opts.Callback, api.Value)
        end
    end

    function api:Set(color, silent)
        h, sVal, v = Color3.toHSV(color)
        apply(0.25, silent)
        flashStroke(s)
    end

    function api:Get()
        return api.Value
    end

    local function setOpen(state)
        api.Open = state
        tween(row, { Size = UDim2.new(1, 0, 0, state and height + 168 or height) }, 0.35, Enum.EasingStyle.Quint)
        arrow:Set(state)

        if state then
            panel.Visible = true
        else
            task.delay(0.35, function()
                if not api.Open then
                    panel.Visible = false
                end
            end)
        end
    end

    function api:SetOpen(state)
        setOpen(state == true)
    end

    header.MouseButton1Click:Connect(function()
        setOpen(not api.Open)
    end)

    local function setSV(pos)
        sVal = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
        v    = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
        apply(0.04)
    end

    local function setHue(pos)
        h = math.clamp((pos.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 0.999)
        apply(0.04)
    end

    sv.InputBegan:Connect(function(input)
        if isPrimary(input) then
            dragMode = "sv"
            tween(cursor, { Size = UDim2.fromOffset(14, 14) }, 0.15, Enum.EasingStyle.Back)
            setSV(mousePos())
        end
    end)

    hueBar.InputBegan:Connect(function(input)
        if isPrimary(input) then
            dragMode = "hue"
            tween(hueCursor, { Size = UDim2.fromOffset(20, 7) }, 0.15, Enum.EasingStyle.Back)
            setHue(mousePos())
        end
    end)

    self.Window:_listen("Changed", function(input)
        if not dragMode or not isMove(input) then return end
        local pos = mousePos()
        if dragMode == "sv" then
            setSV(pos)
        else
            setHue(pos)
        end
    end, api)

    self.Window:_listen("Ended", function(input)
        if dragMode and isPrimary(input) then
            dragMode = nil
            tween(cursor, { Size = UDim2.fromOffset(10, 10) }, 0.2)
            tween(hueCursor, { Size = UDim2.fromOffset(18, 5) }, 0.2)
        end
    end, api)

    hexInput.Focused:Connect(function()
        tween(hexStroke, { Color = Theme.StrokeHover }, 0.15)
    end)

    hexInput.FocusLost:Connect(function()
        tween(hexStroke, { Color = Theme.Stroke }, 0.15)

        local r, g, b = hexInput.Text:match("^%s*#?(%x%x)(%x%x)(%x%x)%s*$")
        if r then
            api:Set(Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)))
        else
            hexInput.Text = toHex(api.Value)
        end
    end)

    refresh(0)
    return registerControl(self, opts, api, row, "ColorPicker")
end

function Tab:Stepper(opts)
    local row, s, height, titleLabel, descLabel
    opts, row, s, height, titleLabel, descLabel = baseControl(self, opts, {
        Title = "Name", Description = "Desc",
        CurrentValue = "Default", Value = "Default",
        Increment = "Step",
    }, "Frame", 150, "Stepper")

    local min    = opts.Min or 0
    local max    = opts.Max or 100
    local step   = opts.Step or 1
    local suffix = opts.Suffix or ""
    local helper = numberHelper(min, max, step)

    local chip = create("Frame", {
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, -10, 0.5, 0),
        Size             = UDim2.fromOffset(0, CHIP_H),
        AutomaticSize    = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel  = 0,
        Parent           = row,
    })
    corner(chip, UDim.new(0, 6))
    local chipStroke = stroke(chip)

    create("UIListLayout", {
        FillDirection      = Enum.FillDirection.Horizontal,
        SortOrder          = Enum.SortOrder.LayoutOrder,
        VerticalAlignment  = Enum.VerticalAlignment.Center,
        Parent             = chip,
    })

    local function makeBtn(text, order)
        local btn = create("TextButton", {
            Size            = UDim2.fromOffset(CHIP_H, CHIP_H),
            BackgroundTransparency = 1,
            Text            = text,
            TextColor3      = Theme.Muted,
            TextSize        = 18,
            FontFace        = Fonts.Medium,
            AutoButtonColor = false,
            LayoutOrder     = order,
            Parent          = chip,
        })

        btn.MouseEnter:Connect(function()
            tween(btn, { TextColor3 = Theme.Accent }, 0.12)
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, { TextColor3 = Theme.Muted }, 0.2)
        end)

        return btn
    end

    local minusBtn = makeBtn("−", 1)

    local valueLabel = textLabel({
        Size           = UDim2.new(0, 30, 1, 0),
        TextSize       = 13,
        TextColor3     = Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate   = Enum.TextTruncate.None,
        LayoutOrder    = 2,
        Parent         = chip,
    })

    local plusBtn = makeBtn("+", 3)

    local function resizeValue(instant)
        local w = math.max(valueLabel.TextBounds.X + 12, 30)
        if instant then
            valueLabel.Size = UDim2.new(0, w, 1, 0)
        else
            tween(valueLabel, { Size = UDim2.new(0, w, 1, 0) }, 0.2)
        end
    end

    valueLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        resizeValue(false)
    end)

    chip:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        adjustTitleWidth(titleLabel, descLabel, chip.AbsoluteSize.X / self.Window.Scale.Scale + 20)
    end)

    local api = {
        Value = math.clamp(opts.Default or min, min, max),
    }
    local suppressFlash = false
    local snap = helper.snap

    local function refresh()
        valueLabel.Text = helper.format(api.Value) .. suffix
        tween(minusBtn, { TextTransparency = api.Value <= min and 0.6 or 0 }, 0.15)
        tween(plusBtn, { TextTransparency = api.Value >= max and 0.6 or 0 }, 0.15)
    end

    function api:Set(value, silent)
        value = snap(tonumber(value) or min)
        if value == api.Value then return end

        api.Value = value
        refresh()

        if not suppressFlash then
            flashStroke(s)
        end

        if not silent then
            safeCall(opts.Callback, value)
        end
    end

    function api:Get()
        return api.Value
    end

    local function stepBy(dir)
        suppressFlash = true
        api:Set(api.Value + dir * step)
        suppressFlash = false

        tween(chipStroke, { Color = Theme.StrokeHover }, 0.08)
        task.delay(0.12, function()
            tween(chipStroke, { Color = Theme.Stroke }, 0.2)
        end)
    end

    local function hold(btn, dir)
        local holding = false

        btn.InputBegan:Connect(function(input)
            if not isPrimary(input) then return end
            holding = true
            stepBy(dir)

            task.delay(0.4, function()
                while holding do
                    stepBy(dir)
                    task.wait(0.07)
                end
            end)
        end)

        btn.InputEnded:Connect(function(input)
            if isPrimary(input) then
                holding = false
            end
        end)

        btn.MouseLeave:Connect(function()
            holding = false
        end)
    end

    hold(minusBtn, -1)
    hold(plusBtn, 1)

    refresh()
    task.defer(resizeValue, true)

    return registerControl(self, opts, api, row, "Stepper")
end

function Tab:Progress(opts)
    opts = merge(opts, {
        Title = "Name", Description = "Desc",
        CurrentValue = "Default", Value = "Default",
    })

    local row, s = makeRow(self, "Frame", opts.Desc and ROW_H_DESC + 10 or ROW_H + 10, opts)
    hoverStroke(row, s)

    local titleY = opts.Desc and (ROW_H_DESC - 38) / 2 - 2 or 12

    textLabel({
        Position = UDim2.fromOffset(14, titleY),
        Size     = UDim2.new(1, -110, 0, 18),
        Text     = opts.Name or "Progress",
        Parent   = row,
    })

    if opts.Desc then
        textLabel({
            Position   = UDim2.fromOffset(14, titleY + 20),
            Size       = UDim2.new(1, -110, 0, 17),
            Text       = opts.Desc,
            TextSize   = 13,
            FontFace   = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent     = row,
        })
    end

    local percentLabel = textLabel({
        AnchorPoint    = Vector2.new(1, 0),
        Position       = UDim2.new(1, -14, 0, titleY),
        Size           = UDim2.fromOffset(90, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize       = 13,
        TextColor3     = Theme.Accent,
        Parent         = row,
    })

    local track = create("Frame", {
        Position         = UDim2.new(0, 14, 1, -16),
        Size             = UDim2.new(1, -28, 0, 5),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel  = 0,
        Parent           = row,
    })
    corner(track, UDim.new(1, 0))

    local fill = create("Frame", {
        Size             = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = opts.Color or Theme.Accent,
        BorderSizePixel  = 0,
        Parent           = track,
    })
    corner(fill, UDim.new(1, 0))

    local api = {
        Value = math.clamp(opts.Default or 0, 0, 1),
    }
    local format = opts.Format

    local function refresh(duration)
        local v = api.Value
        tween(fill, { Size = UDim2.new(v, 0, 1, 0) }, duration, Enum.EasingStyle.Quint)

        if type(format) == "function" then
            percentLabel.Text = tostring(format(v))
        else
            percentLabel.Text = string.format("%d%%", math.floor(v * 100 + 0.5))
        end
    end

    function api:Set(value, silent)
        value = math.clamp(tonumber(value) or 0, 0, 1)
        if value == api.Value then return end

        api.Value = value
        refresh(0.35)

        if not silent then
            safeCall(opts.Callback, value)
        end
    end

    function api:Get()
        return api.Value
    end

    function api:SetColor(color)
        fill.BackgroundColor3 = color
    end

    refresh(0)
    return registerControl(self, opts, api, row, "Progress")
end

function Tab:ConfigManager(opts)
    opts = merge(opts, {})
    local window = self.Window
    local api = {}

    self:Section(opts.Name or "Configs")

    local nameInput = self:Input({
        Name = "Config name",
        Placeholder = window.ConfigName,
        Callback = function(text, enter)
            if enter and #text > 0 then
                api:Save(text)
            end
        end,
    })

    local configList = self:Dropdown({
        Name = "Saved configs",
        Options = window:ListConfigs(),
        Default = window.ConfigName,
        Callback = function(name)
            if name then
                nameInput:Set(name)
            end
        end,
    })

    function api:Refresh()
        configList:Refresh(window:ListConfigs(), true)
    end

    function api:Save(name)
        name = name or configList:Get() or window.ConfigName
        local ok, err = window:SaveConfig(name)
        api:Refresh()
        configList:Set(name, true)

        window:Notify({
            Title   = ok and "Config saved" or "Save failed",
            Content = ok and name or tostring(err),
            Type    = ok and "Success" or "Error",
            Duration = 3,
        })
    end

    function api:Load(name)
        name = name or configList:Get()
        if not name then return end

        local ok, err = window:LoadConfig(name)
        window:Notify({
            Title   = ok and "Config loaded" or "Load failed",
            Content = ok and name or tostring(err),
            Type    = ok and "Success" or "Error",
            Duration = 3,
        })
    end

    function api:Delete(name)
        name = name or configList:Get()
        if not name then return end

        local ok, err = window:DeleteConfig(name)
        api:Refresh()

        window:Notify({
            Title   = ok and "Config deleted" or "Delete failed",
            Content = ok and name or tostring(err),
            Type    = ok and "Info" or "Error",
            Duration = 3,
        })
    end

    self:Button({
        Name  = "Save",
        Desc  = "Writes every flagged element to the selected name",
        Icon  = "save",
        Style = "Primary",
        Callback = function()
            local name = nameInput:Get()
            api:Save(#name > 0 and name or nil)
        end,
    })

    self:Button({
        Name = "Load",
        Icon = "folder-open",
        Callback = function()
            api:Load()
        end,
    })

    self:Button({
        Name = "Delete",
        Icon = "trash-2",
        Callback = function()
            local name = configList:Get()
            if not name then return end

            window:Confirm({
                Title       = "Delete config",
                Content     = "Remove " .. name .. "? This cannot be undone.",
                Icon        = "trash-2",
                ConfirmText = "Delete",
                Callback    = function()
                    api:Delete(name)
                end,
            })
        end,
    })

    self:Toggle({
        Name    = "Auto save",
        Desc    = "Save whenever a flagged element changes",
        Default = window._autoSaveEnabled,
        Callback = function(on)
            window._autoSaveEnabled = on
        end,
    })

    return api
end

for name, fn in pairs(table.clone(Tab)) do
    if type(fn) == "function" and name:sub(1, 1) ~= "_" and name:sub(1, 6) ~= "Create" then
        Tab["Create" .. name] = fn
    end
end

local function getExecutor()
    local name
    pcall(function()
        if typeof(identifyexecutor) == "function" then
            name = identifyexecutor()
        elseif typeof(getexecutorname) == "function" then
            name = getexecutorname()
        end
    end)

    if type(name) == "string" and #name > 0 then
        return name
    end

    return RunService:IsStudio() and "Studio" or "Unknown"
end

local function getGameName()
    local ok, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)

    if ok and type(info) == "table" and info.Name then
        return info.Name
    end

    return "Unknown game"
end

local countryNames = {
    US = "United States", GB = "United Kingdom", DE = "Germany",
    FR = "France", NL = "Netherlands", SG = "Singapore",
    JP = "Japan", AU = "Australia", BR = "Brazil",
    IN = "India", HK = "Hong Kong", CA = "Canada",
}

local function getRegion(callback)
    task.spawn(function()
        local requestFn = request or http_request or (syn and syn.request) or (http and http.request)
        local region

        if type(requestFn) == "function" then
            pcall(function()
                local res = requestFn({
                    Url    = "https://ipinfo.io/json",
                    Method = "GET",
                })

                local body = type(res) == "table" and (res.Body or res.body) or nil
                if type(body) == "string" then
                    local data = HttpService:JSONDecode(body)
                    if type(data) == "table" and data.country then
                        local country = countryNames[data.country] or data.country
                        region = data.city and (data.city .. ", " .. country) or country
                    end
                end
            end)
        end

        callback(region or "Unavailable")
    end)
end

local typeColors = {
    Success = Theme.Success,
    Warning = Theme.Warning,
    Error   = Theme.Error,
}

local Window = {}
Window.__index = Window

function AirFlow.Window(_, opts)
    opts = merge(opts, {
        Name = "Title",
        LoadingSubtitle = "Subtitle",
        ToggleUIKeybind = "Keybind",
    })

    if type(opts.Keybind) == "string" then
        opts.Keybind = Enum.KeyCode[opts.Keybind]
    end

    local size    = opts.Size or UDim2.fromOffset(640, 480)
    local keybind = opts.Keybind or Enum.KeyCode.RightControl

    local win = setmetatable({
        Tabs            = {},
        CurrentTab      = nil,
        Open            = true,
        Keybind         = keybind,
        _connections    = {},
        _controls       = {},
        _inputListeners = {
            Began   = {},
            Changed = {},
            Ended   = {},
            Render  = {},
        },
        _frameSteps     = {},
        _destroyed      = false,
    }, Window)

    local function makeListener(kind)
        return function(...)
            for _, fn in ipairs(win._inputListeners[kind]) do
                fn(...)
            end
        end
    end

    local onRender = makeListener("Render")

    table.insert(win._connections, RunService.RenderStepped:Connect(function(dt)
        onRender(dt)
        for _, fn in ipairs(win._frameSteps) do
            fn(dt)
        end
    end))

    table.insert(win._connections, UserInputService.InputBegan:Connect(makeListener("Began")))
    table.insert(win._connections, UserInputService.InputChanged:Connect(makeListener("Changed")))
    table.insert(win._connections, UserInputService.InputEnded:Connect(makeListener("Ended")))

    local gui = create("ScreenGui", {
        Name           = opts.Name or "AirflowUI",
        IgnoreGuiInset = true,
        ResetOnSpawn   = false,
        DisplayOrder   = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    win.Gui = gui

    local root = create("Frame", {
        Name                   = "Window",
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.fromScale(0.5, 0.5),
        Size                   = size,
        BackgroundTransparency = 1,
        Parent                 = gui,
    })
    win.Root = root

    local scale = create("UIScale", { Parent = root })
    win.Scale = scale

    local shadow = create("ImageLabel", {
        Position               = UDim2.fromOffset(-25, -25),
        Size                   = UDim2.new(1, 50, 1, 50),
        BackgroundTransparency = 1,
        Image                  = Assets.Shadow,
        ImageColor3            = Color3.new(0, 0, 0),
        ImageTransparency      = 0.6,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(49, 49, 450, 450),
        Parent                 = root,
    })
    win.Shadow = shadow

    local body = create("CanvasGroup", {
        Name             = "Body",
        Size             = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel  = 0,
        Parent           = root,
    })
    win.Body = body
    corner(body, UDim.new(0, 10))
    win.BodyStroke = stroke(body, Theme.Stroke)
    dividerLine(body)

    glow(body, UDim2.fromOffset(500, 180), UDim2.new(0.5, 0, 1, 8), 0.86, 270)
    glow(body, UDim2.fromOffset(130, 60), UDim2.new(0, -10, 1, -10), 0.75, 90)
    glow(body, UDim2.fromOffset(520, 240), UDim2.new(1, -14, 0, 10), 0.92, 90)

    local sidebar = create("Frame", {
        Name                   = "Sidebar",
        Size                   = UDim2.new(0, 170, 1, 0),
        BackgroundTransparency = 1,
        Parent                 = body,
    })

    create("Frame", {
        Position         = UDim2.new(0, 170, 0, 28),
        Size             = UDim2.new(0, 1, 1, -56),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel  = 0,
        Parent           = body,
    })

    local header = create("Frame", {
        Name                   = "Header",
        Size                   = UDim2.new(1, 0, 0, 72),
        BackgroundTransparency = 1,
        Parent                 = sidebar,
    })

    local logo = create("ImageLabel", {
        Position               = UDim2.fromOffset(22, 27),
        Size                   = UDim2.fromOffset(30, 28),
        BackgroundTransparency = 1,
        Image                  = "",
        ImageColor3            = Theme.Accent,
        ScaleType              = Enum.ScaleType.Fit,
        Parent                 = header,
    })
    applyIcon(logo, opts.Icon or Assets.Logo)

    textLabel({
        Position = UDim2.fromOffset(60, 25),
        Size     = UDim2.new(1, -70, 0, 20),
        Text     = opts.Title or "Airflow",
        TextSize = 20,
        Parent   = header,
    })

    textLabel({
        Position   = UDim2.fromOffset(60, 45),
        Size       = UDim2.new(1, -70, 0, 14),
        Text       = opts.Subtitle or "",
        TextSize   = 13,
        FontFace   = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent     = header,
    })

    local tabList = create("ScrollingFrame", {
        Name                   = "Tabs",
        Position               = UDim2.fromOffset(0, 80),
        Size                   = UDim2.new(1, 0, 1, -116),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ScrollBarThickness     = 0,
        AutomaticCanvasSize    = Enum.AutomaticSize.Y,
        CanvasSize             = UDim2.new(),
        Parent                 = sidebar,
    })
    win.TabList = tabList
    padding(tabList, 16, 16, 4, 4)

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 4),
        Parent    = tabList,
    })

    local indicator = create("Frame", {
        AnchorPoint      = Vector2.new(0, 0.5),
        Position         = UDim2.fromOffset(6, 0),
        Size             = UDim2.fromOffset(3, 18),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        Visible          = false,
        ZIndex           = 2,
        Parent           = sidebar,
    })
    corner(indicator, UDim.new(1, 0))
    win.Indicator = indicator

    local lastScrollY = tabList.CanvasPosition.Y

    table.insert(win._frameSteps, function()
        local y = tabList.CanvasPosition.Y
        if y == lastScrollY or not win.CurrentTab or not win._introDone then
            return
        end
        lastScrollY = y

        local indY = win:_indicatorY(win.CurrentTab)
        local top  = tabList.Position.Y.Offset
        local bot  = top + tabList.AbsoluteSize.Y / win.Scale.Scale

        indicator.Visible = indY > top and indY < bot
        indicator.Position = UDim2.fromOffset(6, indY)
    end)

    local keyHint = create("Frame", {
        Position               = UDim2.new(0, 22, 1, -36),
        Size                   = UDim2.new(1, -44, 0, 22),
        BackgroundTransparency = 1,
        Parent                 = sidebar,
    })

    local keyChip = create("Frame", {
        Size             = UDim2.fromOffset(0, 22),
        AutomaticSize    = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel  = 0,
        Parent           = keyHint,
    })
    corner(keyChip, UDim.new(0, 5))
    stroke(keyChip)
    padding(keyChip, 7, 7)

    local keyChipLabel = textLabel({
        Size          = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text          = keyName(keybind),
        TextSize      = 11,
        TextColor3    = Theme.Muted,
        TextTruncate  = Enum.TextTruncate.None,
        Parent        = keyChip,
    })
    win._keyChipLabel = keyChipLabel

    local keyHintText = textLabel({
        Size       = UDim2.new(1, 0, 1, 0),
        Text       = isTouch and "or tap the pill" or "to hide",
        TextSize   = 12,
        FontFace   = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent     = keyHint,
    })

    local function layoutKeyHint()
        keyHintText.Position = UDim2.fromOffset(keyChip.AbsoluteSize.X / win.Scale.Scale + 8, 0)
    end
    keyChip:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutKeyHint)
    task.defer(layoutKeyHint)

    local content = create("Frame", {
        Name                   = "Content",
        Position               = UDim2.fromOffset(171, 0),
        Size                   = UDim2.new(1, -171, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants       = true,
        Parent                 = body,
    })
    win.Content = content

    win._outLayer = create("CanvasGroup", {
        Name                   = "TransitionOut",
        Size                   = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible                = false,
        ZIndex                 = 2,
        Parent                 = content,
    })

    win._inLayer = create("CanvasGroup", {
        Name                   = "TransitionIn",
        Size                   = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible                = false,
        ZIndex                 = 3,
        Parent                 = content,
    })

    local closeBtn = create("TextButton", {
        AnchorPoint            = Vector2.new(1, 0),
        Position               = UDim2.new(1, -14, 0, 14),
        Size                   = UDim2.fromOffset(34, 34),
        BackgroundColor3       = Theme.Surface2,
        BackgroundTransparency = 1,
        Text                   = "×",
        TextColor3             = Theme.Muted,
        TextSize               = 28,
        FontFace               = Fonts.Bold,
        AutoButtonColor        = false,
        ZIndex                 = 5,
        Parent                 = content,
    })
    padding(closeBtn, 0, 0, 1, 0)
    corner(closeBtn, UDim.new(0, 8))

    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, { BackgroundTransparency = 0, TextColor3 = Theme.Text }, 0.15)
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, { BackgroundTransparency = 1, TextColor3 = Theme.Muted }, 0.2)
    end)
    closeBtn.MouseButton1Click:Connect(function()
        win:Toggle(false)
    end)

    local notifyHolder = create("Frame", {
        Name                   = "Notifications",
        AnchorPoint            = Vector2.new(1, 1),
        Position               = UDim2.new(1, -20, 1, -20),
        Size                   = UDim2.new(0, 280, 1, -40),
        BackgroundTransparency = 1,
        Parent                 = gui,
    })

    local function layoutNotify()
        notifyHolder.Size = UDim2.new(0, math.min(280, gui.AbsoluteSize.X - 40), 1, -40)
    end
    table.insert(win._connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutNotify))

    create("UIListLayout", {
        SortOrder          = Enum.SortOrder.LayoutOrder,
        VerticalAlignment  = Enum.VerticalAlignment.Bottom,
        Padding            = UDim.new(0, 4),
        Parent             = notifyHolder,
    })

    win.NotifyHolder     = notifyHolder
    win._notifyOrder     = 0
    win._toasts          = {}
    win.MaxNotifications = opts.MaxNotifications or 4
    win._controlsDirty   = true

    table.insert(win._connections, body.DescendantAdded:Connect(function()
        win._controlsDirty = true
    end))
    table.insert(win._connections, body.DescendantRemoving:Connect(function()
        win._controlsDirty = true
    end))

    win:_enableDrag()
    win.MaxSize      = opts.MaxSize
    win.KeepOnScreen = opts.KeepOnScreen ~= false
    win:_enableResize(opts.MinSize or Vector2.new(480, 360))

    local config = opts.ConfigurationSaving
    if type(config) == "table" and config.Enabled ~= false then
        win.ConfigFolder      = config.FolderName or "AirflowUI"
        win.ConfigName        = config.FileName or "default"
        win._autoSaveEnabled  = true
    else
        win.ConfigFolder      = "AirflowUI"
        win.ConfigName        = "default"
        win._autoSaveEnabled  = false
    end

    table.insert(win._connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == win.Keybind then
            task.defer(function()
                local consumed = win._consumedKey == input.KeyCode
                    and os.clock() - (win._consumedAt or 0) < 0.2

                win._consumedKey = nil

                if not consumed and not win._destroyed then
                    win:Toggle(not win.Open)
                end
            end)
        end
    end))

    pcall(function()
        if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
            syn.protect_gui(gui)
        end
    end)

    gui.Parent = opts.Parent or getUIParent()

    scale.Scale = 0.9
    body.GroupTransparency = 1
    shadow.ImageTransparency = 1
    win.BodyStroke.Transparency = 1
    root.Visible = false

    win:_fitToScreen(true)

    table.insert(win._connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        win:_fitToScreen()
        win:_clampToScreen()
    end))

    if (opts.OpenButton ~= nil and opts.OpenButton ~= false)
        or (opts.OpenButton == nil and isTouch) then
        win:_createOpenButton(type(opts.OpenButton) == "table" and opts.OpenButton or {})
    end

    win._introDone = false
    table.insert(AirFlow.Windows, win)

    if opts.Home then
        win:_buildHome(type(opts.Home) == "table" and opts.Home or {})
    end

    local loading = opts.Loading
    if type(loading) == "table" then
        opts.LoadingDuration = loading.Duration or opts.LoadingDuration
        opts.LoadingText     = loading.Text or loading.Subtitle or opts.LoadingText
        opts.LoadingSteps    = loading.Steps or opts.LoadingSteps
        opts.LoadingTitle    = loading.Title or opts.LoadingTitle
        loading = loading.Enabled ~= false
    end

    if loading == false then
        task.defer(function()
            win:_playIntro()
        end)
    else
        win:_showLoader(opts)
    end

    return win
end

AirFlow.CreateWindow = AirFlow.Window

function AirFlow:Notify(opts)
    local win = AirFlow.Windows[#AirFlow.Windows]
    if win then
        return win:Notify(opts)
    end
end

function AirFlow:Confirm(opts)
    local win = AirFlow.Windows[#AirFlow.Windows]
    if win then
        return win:Confirm(opts)
    end
end

function AirFlow:Dialog(opts)
    local win = AirFlow.Windows[#AirFlow.Windows]
    if win then
        return win:Dialog(opts)
    end
end


local function pointIn(pos, gui)
    local absPos  = gui.AbsolutePosition
    local absSize = gui.AbsoluteSize
    return pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
       and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
end

local function isVisibleInClip(gui, root, pos)
    local current = gui
    while current and current ~= root and current:IsA("GuiObject") do
        if not current.Visible then
            return false
        end

        local parent = current.Parent
        if parent and parent ~= root and parent:IsA("GuiObject")
            and (parent.ClipsDescendants or parent:IsA("ScrollingFrame"))
            and not pointIn(pos, parent) then
            return false
        end

        current = parent
    end
    return true
end

function Window:_refreshControls()
    local list = {}
    for _, child in ipairs(self.Body:GetDescendants()) do
        if child:IsA("GuiButton") or child:IsA("TextBox") or child:GetAttribute("NoDrag") then
            table.insert(list, child)
        end
    end
    self._controls = list
    self._controlsDirty = false
end

function Window:_overControl(pos)
    if self._dialog then return true end
    if self._controlsDirty then
        self:_refreshControls()
    end

    for _, ctrl in ipairs(self._controls) do
        if ctrl.Parent and pointIn(pos, ctrl) and isVisibleInClip(ctrl, self.Body, pos) then
            return true
        end
    end
    return false
end

function Window:_enableDrag()
    local dragging = false
    local offset   = Vector2.zero
    local target

    local function center()
        local root = self.Root
        return root.AbsolutePosition + root.AbsoluteSize * root.AnchorPoint - self.Gui.AbsolutePosition
    end

    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input)
        if not isPrimary(input) then return end
        if not self.Open or not self.Root.Visible then return end

        local pos = mousePos()
        if not pointIn(pos, self.Body) or self:_overControl(pos) then return end

        dragging = true
        offset   = pos - center()
    end))

    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if isPrimary(input) then
            dragging = false
            target   = nil
            self:_clampToScreen()
        end
    end))

    table.insert(self._frameSteps, function(dt)
        if not dragging then return end

        target = mousePos() - offset
        local current = center()
        local alpha = 1 - math.exp(-dt * 45)
        local next = current:Lerp(target, alpha)

        self.Root.Position = UDim2.fromOffset(next.X, next.Y)
    end)
end

local function revealCard(card, delay, force)
    if not card.Visible and not force then return end

    card.Visible = false
    task.delay(delay, function()
        if not card.Parent then return end

        local scale = create("UIScale", { Scale = 0.94, Parent = card })
        card.Visible = true
        tween(scale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)

        task.delay(0.4, function()
            scale:Destroy()
        end)
    end)
end

function Window:_revealCards(tab, baseDelay)
    if tab._revealed then return end
    tab._revealed = true

    local i = 0
    for _, child in ipairs(tab.List:GetChildren()) do
        if child:IsA("GuiObject") then
            revealCard(child, (baseDelay or 0) + i * 0.035)
            i += 1
        end
    end
end

function Window:_playIntro(fromLoader)
    if self._introDone then return end
    self._introDone = true

    task.delay(1, function()
        self._autoSaveReady = true
    end)

    local root   = self.Root
    local body   = self.Body
    local shadow = self.Shadow
    local scale  = self.Scale

    if self.CurrentTab then
        self:_revealCards(self.CurrentTab, fromLoader and 0.15 or 0.25)
    end

    root.Visible = true

    if fromLoader then
        scale.Scale = self._fitScale or 1
        root.Position = UDim2.fromScale(0.5, 0.5)
        tween(body, { GroupTransparency = 0 }, 0.3)
        tween(self.BodyStroke, { Transparency = 0 }, 0.3)
        tween(shadow, { ImageTransparency = 0.6 }, 0.3)
    else
        root.Position = UDim2.new(0.5, 0, 0.5, 24)
        tween(scale, { Scale = self._fitScale or 1 }, 0.5, Enum.EasingStyle.Back)
        tween(root, { Position = UDim2.fromScale(0.5, 0.5) }, 0.5, Enum.EasingStyle.Quint)
        tween(body, { GroupTransparency = 0 }, 0.35)
        tween(self.BodyStroke, { Transparency = 0 }, 0.35)
        tween(shadow, { ImageTransparency = 0.6 }, 0.5)
    end

    for i, tab in ipairs(self.Tabs) do
        revealCard(tab._button, 0.1 + i * 0.05, true)
    end

    self.Indicator.Visible = false

    task.delay(0.15 + #self.Tabs * 0.05, function()
        if self.CurrentTab then
            self:_placeIndicator(self.CurrentTab)
        end
    end)
end

function Window:_showLoader(opts)
    local duration = opts.LoadingDuration or 1.6
    local gui = self.Gui

    local loader = create("CanvasGroup", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.5, 16),
        Size                   = UDim2.fromOffset(300, 132),
        BackgroundColor3       = Theme.Background,
        BorderSizePixel        = 0,
        GroupTransparency      = 1,
        ZIndex                 = 10,
        Parent                 = gui,
    })

    local loaderCorner = corner(loader, UDim.new(0, 12))
    local loaderStroke = stroke(loader, Theme.Stroke, 1)
    dividerLine(loader)

    glow(loader, UDim2.fromOffset(320, 140), UDim2.new(1, -20, 0, -20), 0.85, 90)
    glow(loader, UDim2.fromOffset(240, 100), UDim2.new(0, 10, 1, 10), 0.9, 270)

    local loaderScale = create("UIScale", { Scale = 0.92, Parent = loader })

    local loaderShadow = create("ImageLabel", {
        Position               = UDim2.fromOffset(-25, -25),
        Size                   = UDim2.new(1, 50, 1, 50),
        BackgroundTransparency = 1,
        Image                  = Assets.Shadow,
        ImageColor3            = Color3.new(0, 0, 0),
        ImageTransparency      = 1,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(49, 49, 450, 450),
        ZIndex                 = 0,
        Parent                 = loader,
    })

    local iconHolder = create("Frame", {
        Position               = UDim2.fromOffset(24, 26),
        Size                   = UDim2.fromOffset(40, 40),
        BackgroundTransparency = 1,
        Parent                 = loader,
    })

    local icon = create("ImageLabel", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.fromScale(0.5, 0.5),
        Size                   = UDim2.fromScale(0.5, 0.5),
        Rotation               = -14,
        BackgroundTransparency = 1,
        ImageColor3            = Theme.Accent,
        ImageTransparency      = 1,
        ScaleType              = Enum.ScaleType.Fit,
        Parent                 = iconHolder,
    })
    applyIcon(icon, opts.Icon or Assets.Logo)

    task.delay(0.15, function()
        tween(icon, {
            Size              = UDim2.fromScale(0.85, 0.85),
            Rotation          = 0,
            ImageTransparency = 0,
        }, 0.6, Enum.EasingStyle.Back)
    end)

    textLabel({
        Position = UDim2.fromOffset(78, 30),
        Size     = UDim2.new(1, -100, 0, 22),
        Text     = opts.LoadingTitle or opts.Title or "Airflow",
        TextSize = 20,
        Parent   = loader,
    })

    local status = textLabel({
        Position   = UDim2.fromOffset(78, 52),
        Size       = UDim2.new(1, -100, 0, 16),
        Text       = opts.LoadingText or opts.Subtitle or "Loading",
        TextSize   = 13,
        FontFace   = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent     = loader,
    })

    local bar = create("Frame", {
        Position         = UDim2.new(0, 24, 1, -30),
        Size             = UDim2.new(1, -48, 0, 4),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        Parent           = loader,
    })
    corner(bar, UDim.new(1, 0))

    local fill = create("Frame", {
        Size             = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        Parent           = bar,
    })
    corner(fill, UDim.new(1, 0))

    local shimmer = create("Frame", {
        Position               = UDim2.fromScale(-0.4, 0),
        Size                   = UDim2.fromScale(0.4, 1),
        BackgroundColor3       = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.6,
        BorderSizePixel        = 0,
        ZIndex                 = 2,
        Parent                 = bar,
    })
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = shimmer,
    })

    tween(loader, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, 0.4, Enum.EasingStyle.Quint)
    tween(loaderScale, { Scale = 1 }, 0.5, Enum.EasingStyle.Back)
    tween(loaderShadow, { ImageTransparency = 0.6 }, 0.4)

    local shimmerTween = TweenService:Create(shimmer, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), {
        Position = UDim2.fromScale(1, 0),
    })
    shimmerTween:Play()

    tween(fill, { Size = UDim2.fromScale(0.85, 1) }, duration * 0.8, Enum.EasingStyle.Quart)

    task.spawn(loadLucide)

    local steps = opts.LoadingSteps or { "Preparing interface", "Loading icons", "Almost there" }
    for i, step in ipairs(steps) do
        task.delay(duration * (i - 1) / #steps, function()
            if loader.Parent then
                status.Text = step
            end
        end)
    end

    task.delay(duration, function()
        tween(fill, { Size = UDim2.fromScale(1, 1) }, 0.25, Enum.EasingStyle.Quint)

        task.delay(0.25, function()
            shimmerTween:Cancel()

            for _, child in ipairs(loader:GetChildren()) do
                if child:IsA("TextLabel") then
                    tween(child, { TextTransparency = 1 }, 0.15)
                end
            end

            for _, child in ipairs(iconHolder:GetChildren()) do
                tween(child, { ImageTransparency = 1 }, 0.15)
            end

            tween(bar, { BackgroundTransparency = 1 }, 0.15)
            tween(fill, { BackgroundTransparency = 1 }, 0.15)
            tween(shimmer, { BackgroundTransparency = 1 }, 0.1)

            local fit = self._fitScale or 1
            local rootSize = self.Root.Size

            tween(loader, {
                Size     = UDim2.fromOffset(rootSize.X.Offset * fit, rootSize.Y.Offset * fit),
                Position = UDim2.fromScale(0.5, 0.5),
            }, 0.5, Enum.EasingStyle.Quint)

            tween(loaderCorner, { CornerRadius = UDim.new(0, 10) }, 0.5, Enum.EasingStyle.Quint)
            tween(loaderScale, { Scale = 1 }, 0.5, Enum.EasingStyle.Quint)

            task.delay(0.28, function()
                self:_playIntro(true)
                tween(loader, { GroupTransparency = 1 }, 0.25)
                tween(loaderStroke, { Transparency = 1 }, 0.2)
                tween(loaderShadow, { ImageTransparency = 1 }, 0.2)
            end)

            task.delay(0.6, function()
                loader:Destroy()
            end)
        end)
    end)
end

function Window:_fitToScreen(instant)
    local size = self.Gui.AbsoluteSize
    if size.X == 0 or size.Y == 0 then return end

    local rootSize = self.Root.Size
    local scale = math.min(
        1,
        (size.X - 24) / math.max(rootSize.X.Offset, 1),
        (size.Y - 24) / math.max(rootSize.Y.Offset, 1)
    )

    self._fitScale = math.max(scale, 0.45)

    if self._introDone and self.Open then
        if instant then
            self.Scale.Scale = self._fitScale
        else
            tween(self.Scale, { Scale = self._fitScale }, 0.2)
        end
    end
end

function Window:_clampToScreen()
    if not self.KeepOnScreen then return end

    local guiSize = self.Gui.AbsoluteSize
    local root    = self.Root
    local half    = root.AbsoluteSize / 2
    local center  = root.AbsolutePosition + half - self.Gui.AbsolutePosition

    local clamped = Vector2.new(
        math.clamp(center.X, math.min(half.X, guiSize.X / 2), math.max(guiSize.X - half.X, guiSize.X / 2)),
        math.clamp(center.Y, math.min(half.Y, guiSize.Y / 2), math.max(guiSize.Y - half.Y, guiSize.Y / 2))
    )

    if (clamped - center).Magnitude > 0.5 then
        tween(root, { Position = UDim2.fromOffset(clamped.X, clamped.Y) }, 0.25, Enum.EasingStyle.Quint)
    end
end

function Window:_createOpenButton(opts)
    local gui = self.Gui

    local btn = create("TextButton", {
        AnchorPoint      = Vector2.new(0.5, 0),
        Position         = UDim2.new(0.5, 0, 0, 14),
        Size             = UDim2.fromOffset(0, 40),
        AutomaticSize    = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel  = 0,
        Text             = "",
        AutoButtonColor  = false,
        ZIndex           = 30,
        Parent           = gui,
    })
    corner(btn, UDim.new(1, 0))
    stroke(btn, Theme.Stroke)
    padding(btn, 12, 16)

    local icon = create("ImageLabel", {
        AnchorPoint            = Vector2.new(0, 0.5),
        Position               = UDim2.new(0, 0, 0.5, 0),
        Size                   = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1,
        ImageColor3            = Theme.Accent,
        ScaleType              = Enum.ScaleType.Fit,
        ZIndex                 = 31,
        Parent                 = btn,
    })
    applyIcon(icon, opts.Icon or Assets.Logo)

    textLabel({
        Position      = UDim2.fromOffset(28, 0),
        Size          = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text          = opts.Title or "Airflow",
        TextSize      = 13,
        TextTruncate  = Enum.TextTruncate.None,
        ZIndex        = 31,
        Parent        = btn,
    })

    self.OpenButton = btn

    local dragging, moved = false, false
    local offset = Vector2.zero

    btn.InputBegan:Connect(function(input)
        if isPrimary(input) then
            dragging = true
            moved    = false
            offset   = mousePos() - btn.AbsolutePosition
        end
    end)

    table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if isMove(input) then
            local pos = mousePos() - offset - gui.AbsolutePosition
            if (pos - (btn.AbsolutePosition - gui.AbsolutePosition)).Magnitude > 3 then
                moved = true
            end

            btn.AnchorPoint = Vector2.new(0, 0)
            btn.Position = UDim2.fromOffset(
                math.clamp(pos.X, 0, math.max(gui.AbsoluteSize.X - btn.AbsoluteSize.X, 0)),
                math.clamp(pos.Y, 0, math.max(gui.AbsoluteSize.Y - btn.AbsoluteSize.Y, 0))
            )
        end
    end))

    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if dragging and isPrimary(input) then
            dragging = false
            if not moved then
                self:Toggle()
            end
        end
    end))
end

function Window:_enableResize(minSize)
    local maxSize = self.MaxSize or Vector2.new(math.huge, math.huge)

    local handle = create("Frame", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(1, 4, 1, 4),
        Size                   = UDim2.fromOffset(32, 32),
        BackgroundTransparency = 1,
        Active                 = true,
        ZIndex                 = 20,
        Parent                 = self.Root,
    })

    local icon = create("ImageLabel", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, -16, 0.5, -16),
        Size                   = UDim2.fromOffset(96, 96),
        BackgroundTransparency = 1,
        Image                  = "rbxassetid://120997033468887",
        ImageColor3            = Theme.Accent,
        ImageTransparency      = 0.8,
        ZIndex                 = 20,
        Parent                 = handle,
    })

    local resizing = false
    local startSize = self.Root.Size
    local startPos  = Vector2.zero
    local targetSize

    handle.InputBegan:Connect(function(input)
        if isPrimary(input) then
            resizing  = true
            startSize = self.Root.Size
            startPos  = mousePos()
            tween(icon, { ImageTransparency = 0.35 }, 0.1)
        end
    end)

    handle.MouseEnter:Connect(function()
        if not resizing then
            tween(icon, { ImageTransparency = 0.35 }, 0.1)
        end
    end)
    handle.MouseLeave:Connect(function()
        if not resizing then
            tween(icon, { ImageTransparency = 0.8 }, 0.17)
        end
    end)

    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if resizing and isPrimary(input) then
            resizing = false
            tween(icon, { ImageTransparency = 0.8 }, 0.17)

            if targetSize then
                self.Root.Size = UDim2.fromOffset(targetSize.X, targetSize.Y)
                targetSize = nil
            end

            self:_fitToScreen()
            self:_clampToScreen()
        end
    end))

    table.insert(self._frameSteps, function(dt)
        if not resizing then return end

        local delta = (mousePos() - startPos) / self.Scale.Scale
        targetSize = Vector2.new(
            math.clamp(startSize.X.Offset + delta.X * 2, minSize.X, maxSize.X),
            math.clamp(startSize.Y.Offset + delta.Y * 2, minSize.Y, maxSize.Y)
        )

        local current = Vector2.new(self.Root.Size.X.Offset, self.Root.Size.Y.Offset)
        local alpha = 1 - math.exp(-dt * 35)
        local next = current:Lerp(targetSize, alpha)
        next = Vector2.new(math.floor(next.X + 0.5), math.floor(next.Y + 0.5))

        if next ~= current then
            self.Root.Size = UDim2.fromOffset(next.X, next.Y)
        end
    end)
end


local function configPath(win, name)
    return win.ConfigFolder .. "/" .. name .. ".json"
end

local function hasFileAPI()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
end

local function ensureFolder(path)
    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(path) then
        makefolder(path)
    end
end

local function serialize(control)
    local typeName = control._type
    local value    = control:Get()

    if typeName == "Keybind" then
        return { Type = typeName, Value = value and value.Name or nil }
    elseif typeName == "ColorPicker" then
        return { Type = typeName, Value = { value.R, value.G, value.B } }
    end

    return { Type = typeName, Value = value }
end

local function deserialize(control, data, silent)
    local typeName = control._type
    local value    = data.Value

    if typeName == "Keybind" then
        control:Set(value and Enum.KeyCode[value] or nil, silent)
    elseif typeName == "ColorPicker" then
        if type(value) == "table" then
            control:Set(Color3.new(value[1], value[2], value[3]), silent)
        end
    elseif value ~= nil then
        control:Set(value, silent)
    end
end

function Window:SaveConfig(name)
    name = name or self.ConfigName
    if not hasFileAPI() then
        return false, "file API unavailable"
    end

    ensureFolder(self.ConfigFolder)

    local data = {}
    for flag, control in pairs(AirFlow.Flags) do
        if control._type and type(control.Get) == "function" then
            data[flag] = serialize(control)
        end
    end

    local ok, err = pcall(function()
        writefile(configPath(self, name), HttpService:JSONEncode(data))
    end)

    if ok then
        self.ConfigName = name
    end

    return ok, err
end

function Window:LoadConfig(name, silent)
    name = name or self.ConfigName
    if not hasFileAPI() then
        return false, "file API unavailable"
    end

    local path = configPath(self, name)
    if not isfile(path) then
        return false, "no config named " .. name
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    if not ok or type(data) ~= "table" then
        return false, "config is not valid JSON"
    end

    local wasAuto = self._autoSaveEnabled
    self._autoSaveEnabled = false

    for flag, entry in pairs(data) do
        local control = AirFlow.Flags[flag]
        if control and type(control.Set) == "function"
            and type(entry) == "table" and entry.Type == control._type then
            pcall(deserialize, control, entry, silent == true)
        end
    end

    self._autoSaveEnabled = wasAuto
    self._autoSaveReady   = true
    self.ConfigName       = name

    return true
end

function Window:DeleteConfig(name)
    if not hasFileAPI() or type(delfile) ~= "function" then
        return false, "file API unavailable"
    end

    local path = configPath(self, name)
    if not isfile(path) then
        return false, "no config named " .. name
    end

    delfile(path)
    return true
end

function Window:ListConfigs()
    local list = {}

    if type(listfiles) ~= "function"
        or type(isfolder) ~= "function"
        or not isfolder(self.ConfigFolder) then
        return list
    end

    for _, path in ipairs(listfiles(self.ConfigFolder)) do
        local name = path:match("([^/\\]+)%.json$")
        if name then
            table.insert(list, name)
        end
    end

    table.sort(list)
    return list
end

function Window:_autoSave()
    if not self._autoSaveEnabled or self._destroyed or not self._autoSaveReady then
        return
    end

    if self._autoSavePending then return end
    self._autoSavePending = true

    task.delay(0.5, function()
        self._autoSavePending = false
        if not self._destroyed then
            self:SaveConfig(self.ConfigName)
        end
    end)
end

local function emptyState(parent, icon, text)
    local holder = create("Frame", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.5, -10),
        Size                   = UDim2.fromOffset(200, 70),
        BackgroundTransparency = 1,
        Parent                 = parent,
    })

    local img = create("ImageLabel", {
        AnchorPoint            = Vector2.new(0.5, 0),
        Position               = UDim2.new(0.5, 0, 0, 0),
        Size                   = UDim2.fromOffset(26, 26),
        BackgroundTransparency = 1,
        ImageColor3            = Theme.Muted,
        ImageTransparency      = 0.15,
        ScaleType              = Enum.ScaleType.Fit,
        Parent                 = holder,
    })
    applyIcon(img, icon)

    local label = textLabel({
        Position       = UDim2.fromOffset(0, 36),
        Size           = UDim2.new(1, 0, 0, 16),
        Text           = text,
        TextSize       = 13,
        FontFace       = Fonts.Regular,
        TextColor3     = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent         = holder,
    })

    return holder, label, img
end

local function statCard(parent, order, icon, title)
    local card = create("Frame", {
        Size             = UDim2.new(0.5, -4, 0, 62),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel  = 0,
        LayoutOrder      = order,
        Parent           = parent,
    })
    corner(card)
    stroke(card)
    card:SetAttribute("NoDrag", true)

    if icon then
        iconButton(card, icon, Theme.Muted, UDim2.new(0, 14, 0, 21))
    end

    textLabel({
        Position   = UDim2.fromOffset(icon and 36 or 14, 12),
        Size       = UDim2.new(1, -(icon and 50 or 28), 0, 16),
        Text       = title,
        TextSize   = 12,
        TextColor3 = Theme.Muted,
        Parent     = card,
    })

    return textLabel({
        Position = UDim2.fromOffset(14, 34),
        Size     = UDim2.new(1, -28, 0, 18),
        Text     = "…",
        TextSize = 15,
        Parent   = card,
    })
end

local function fadeInChildren(parent)
    local list = {}

    local function collect(node)
        for _, child in ipairs(node:GetChildren()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                table.insert(list, { child, "TextTransparency", child.TextTransparency })
            elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
                table.insert(list, { child, "ImageTransparency", child.ImageTransparency })
            elseif child:IsA("UIStroke") then
                table.insert(list, { child, "Transparency", child.Transparency })
            elseif child:IsA("Frame") then
                table.insert(list, { child, "BackgroundTransparency", child.BackgroundTransparency })
            end
            collect(child)
        end
    end

    if parent:IsA("Frame") then
        table.insert(list, { parent, "BackgroundTransparency", parent.BackgroundTransparency })
    end

    collect(parent)

    for _, entry in ipairs(list) do
        entry[1][entry[2]] = 1
        tween(entry[1], { [entry[2]] = entry[3] }, 0.28)
    end
end

local function slideIn(layer, offset)
    offset = offset or 0
    layer.GroupTransparency = 1
    layer.Position = UDim2.fromOffset(0, offset + 14)
    layer.Visible = true
    tween(layer, {
        GroupTransparency = 0,
        Position          = UDim2.fromOffset(0, offset),
    }, 0.32, Enum.EasingStyle.Quint)
end

function Window:_buildHome(opts)
    local tab = self:Tab({
        Name = opts.Name or "Home",
        Desc = opts.Desc,
        Icon = opts.Icon or "house",
    })

    local list = tab.List
    local pages = opts.Pages or opts.Tabs
    local pageFrames = {}
    local tabBar

    if type(pages) == "table" and #pages > 0 then
        tabBar = create("Frame", {
            Size                   = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            LayoutOrder            = 1,
            Parent                 = list,
        })
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder     = Enum.SortOrder.LayoutOrder,
            Padding       = UDim.new(0, 6),
            Parent        = tabBar,
        })
    end

    local greeting = opts.Greeting
    if greeting == nil then
        local hour = tonumber(os.date("%H")) or 12
        local part = hour < 12 and "morning" or (hour < 18 and "afternoon" or "evening")
        greeting = "Good " .. part .. "."
    end

    local welcome = create("Frame", {
        Size             = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel  = 0,
        LayoutOrder      = 2,
        Parent           = list,
    })
    welcome:SetAttribute("NoDrag", true)
    corner(welcome)
    stroke(welcome)

    local avatar = create("ImageLabel", {
        Position         = UDim2.fromOffset(12, 11),
        Size             = UDim2.fromOffset(36, 36),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel  = 0,
        Parent           = welcome,
    })
    corner(avatar, UDim.new(0, 8))
    stroke(avatar)

    task.spawn(function()
        local ok, url = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size100x100
            )
        end)
        if ok and url then
            avatar.Image = url
        end
    end)

    textLabel({
        Position = UDim2.fromOffset(58, 11),
        Size     = UDim2.new(1, -72, 0, 18),
        Text     = (opts.Welcome or "Hello, ") .. LocalPlayer.DisplayName,
        TextSize = 15,
        Parent   = welcome,
    })

    textLabel({
        Position   = UDim2.fromOffset(58, 30),
        Size       = UDim2.new(1, -72, 0, 16),
        Text       = greeting,
        TextSize   = 13,
        FontFace   = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent     = welcome,
    })

    local details = create("Frame", {
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder            = 3,
        Parent                 = list,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 8),
        Parent    = details,
    })

    if opts.Sections ~= false then
        local section = create("Frame", {
            Size                   = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            LayoutOrder            = 1,
            Parent                 = details,
        })

        local label = textLabel({
            Position      = UDim2.fromOffset(2, 6),
            Size          = UDim2.new(0, 0, 0, 16),
            AutomaticSize = Enum.AutomaticSize.X,
            Text          = string.upper(opts.SectionName or "System info"),
            TextSize      = 12,
            TextColor3    = Theme.Muted,
            TextTruncate  = Enum.TextTruncate.None,
            Parent        = section,
        })

        local line = create("Frame", {
            AnchorPoint      = Vector2.new(1, 0.5),
            Position         = UDim2.new(1, 0, 0, 14),
            Size             = UDim2.new(1, -12, 0, 1),
            BackgroundColor3 = Theme.Stroke,
            BorderSizePixel  = 0,
            Parent           = section,
        })

        local function layout()
            line.Size = UDim2.new(1, -(label.AbsoluteSize.X + 14), 0, 1)
        end
        label:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
        task.defer(layout)
    end

    local grid = create("Frame", {
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder            = 2,
        Parent                 = details,
    })
    create("UIGridLayout", {
        CellSize    = UDim2.new(0.5, -4, 0, 62),
        CellPadding = UDim2.fromOffset(8, 8),
        SortOrder   = Enum.SortOrder.LayoutOrder,
        Parent      = grid,
    })

    local wanted = opts.Stats or { "FPS", "Ping", "Executor", "Game", "Region", "Time" }
    local set = {}
    for _, name in ipairs(wanted) do
        set[name] = true
    end

    local order = 0
    local function addStat(key, icon, title)
        if not set[key] then return nil end
        order += 1
        return statCard(grid, order, icon, title)
    end

    local fpsLabel      = addStat("FPS",      "activity",  "FPS")
    local pingLabel     = addStat("Ping",     "wifi",      "Ping")
    local executorLabel = addStat("Executor", "terminal",  "Executor")
    local gameLabel     = addStat("Game",     "gamepad-2", "Game")
    local regionLabel   = addStat("Region",   "globe",     "Server region")
    local timeLabel     = addStat("Time",     "clock",     "Time of day")
    local playersLabel  = addStat("Players",  "users",     "Players")
    local uptimeLabel   = addStat("Uptime",   "timer",     "Session")

    if executorLabel then
        executorLabel.Text = getExecutor()
    end

    if gameLabel then
        gameLabel.Text = "Loading"
        task.spawn(function()
            gameLabel.Text = getGameName()
        end)
    end

    if regionLabel then
        regionLabel.Text = "Loading"
        getRegion(function(text)
            regionLabel.Text = text
        end)
    end

    local frames = 0
    local startTime = os.clock()

    self:_listen("Render", function()
        frames += 1
    end)

    task.spawn(function()
        while not self._destroyed and tab.List.Parent and tab._page.Parent do
            if not self.Open or self.CurrentTab ~= tab then
                frames = 0
                task.wait(1)
                continue
            end

            if fpsLabel then
                fpsLabel.Text = tostring(frames)
            end
            frames = 0

            if pingLabel then
                local ok, ping = pcall(function()
                    return math.floor(LocalPlayer:GetNetworkPing() * 1e3)
                end)
                pingLabel.Text = (ok and ping or 0) .. " ms"
            end

            if timeLabel then
                timeLabel.Text = os.date(opts.TimeFormat or "%H:%M")
            end

            if playersLabel then
                playersLabel.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers
            end

            if uptimeLabel then
                local secs = math.floor(os.clock() - startTime)
                uptimeLabel.Text = string.format("%d:%02d", math.floor(secs / 60), secs % 60)
            end

            task.wait(1)
        end
    end)

    table.insert(pageFrames, {
        Title = opts.SectionName or "Details",
        Icon  = opts.TabIcon or "layout-grid",
        Frame = details,
    })

    if tabBar then
        for _, page in ipairs(pages) do
            local frame = create("Frame", {
                Size                   = UDim2.new(1, 0, 0, 0),
                AutomaticSize          = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Visible                = false,
                LayoutOrder            = 3,
                Parent                 = list,
            })
            create("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding   = UDim.new(0, 8),
                Parent    = frame,
            })

            if type(page.Content) == "string" then
                local card = create("Frame", {
                    Size             = UDim2.new(1, 0, 0, 0),
                    AutomaticSize    = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Theme.Surface2,
                    BorderSizePixel  = 0,
                    LayoutOrder      = 1,
                    Parent           = frame,
                })
                card:SetAttribute("NoDrag", true)
                corner(card)
                stroke(card)
                padding(card, 14, 14, 12, 14)

                textLabel({
                    Size           = UDim2.new(1, 0, 0, 0),
                    AutomaticSize  = Enum.AutomaticSize.Y,
                    Text           = page.Content,
                    TextSize       = 13,
                    FontFace       = Fonts.Regular,
                    TextColor3     = Theme.Muted,
                    TextWrapped    = true,
                    TextTruncate   = Enum.TextTruncate.None,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    Parent         = card,
                })
            end

            if type(page.Entries) == "table" then
                for i, entry in ipairs(page.Entries) do
                    local card = create("Frame", {
                        Size             = UDim2.new(1, 0, 0, 0),
                        AutomaticSize    = Enum.AutomaticSize.Y,
                        BackgroundColor3 = Theme.Surface2,
                        BorderSizePixel  = 0,
                        LayoutOrder      = i,
                        Parent           = frame,
                    })
                    card:SetAttribute("NoDrag", true)
                    corner(card)
                    stroke(card)
                    padding(card, 14, 14, 12, 14)

                    create("UIListLayout", {
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding   = UDim.new(0, 4),
                        Parent    = card,
                    })

                    local head = create("Frame", {
                        Size                   = UDim2.new(1, 0, 0, 18),
                        BackgroundTransparency = 1,
                        LayoutOrder            = 1,
                        Parent                 = card,
                    })

                    textLabel({
                        Size   = UDim2.new(1, -70, 1, 0),
                        Text   = entry.Title or entry.Version or "Update",
                        TextSize = 14,
                        Parent = head,
                    })

                    if entry.Date or entry.Tag then
                        local tag = create("Frame", {
                            AnchorPoint      = Vector2.new(1, 0.5),
                            Position         = UDim2.new(1, 0, 0.5, 0),
                            Size             = UDim2.fromOffset(0, 20),
                            AutomaticSize    = Enum.AutomaticSize.X,
                            BackgroundColor3 = Theme.Surface,
                            BorderSizePixel  = 0,
                            Parent           = head,
                        })
                        corner(tag, UDim.new(0, 5))
                        stroke(tag)
                        padding(tag, 8, 8)

                        textLabel({
                            Size          = UDim2.new(0, 0, 1, 0),
                            AutomaticSize = Enum.AutomaticSize.X,
                            Text          = entry.Tag or entry.Date,
                            TextSize      = 11,
                            TextColor3    = Theme.Muted,
                            TextTruncate  = Enum.TextTruncate.None,
                            Parent        = tag,
                        })
                    end

                    local bodyText = entry.Content or entry.Body
                    if type(entry.Changes) == "table" then
                        bodyText = "• " .. table.concat(entry.Changes, "\n• ")
                    end

                    if bodyText then
                        textLabel({
                            Size           = UDim2.new(1, 0, 0, 0),
                            AutomaticSize  = Enum.AutomaticSize.Y,
                            Text           = bodyText,
                            TextSize       = 13,
                            FontFace       = Fonts.Regular,
                            TextColor3     = Theme.Muted,
                            TextWrapped    = true,
                            TextTruncate   = Enum.TextTruncate.None,
                            TextYAlignment = Enum.TextYAlignment.Top,
                            LayoutOrder    = 2,
                            Parent         = card,
                        })
                    end
                end
            end

            if type(page.Build) == "function" then
                safeCall(page.Build, frame)
                for _, child in ipairs(frame:GetChildren()) do
                    if child:IsA("GuiObject") then
                        child:SetAttribute("NoDrag", true)
                    end
                end
            end

            table.insert(pageFrames, {
                Title = page.Name or page.Title or "Page",
                Icon  = page.Icon,
                Frame = frame,
            })
        end

        local buttons = {}

        local function selectPage(index, instant)
            local changed = self._homeIndex ~= index
            self._homeIndex = index

            welcome.Visible = index == 1
            if index == 1 and changed and not instant then
                fadeInChildren(welcome)
            end

            for i, page in ipairs(pageFrames) do
                local active = i == index
                local frame  = page.Frame
                frame.Visible = active

                if active and changed and not instant then
                    for _, child in ipairs(frame:GetChildren()) do
                        if child:IsA("GuiObject") then
                            fadeInChildren(child)
                        end
                    end
                end

                local btn = buttons[i]
                if btn then
                    tween(btn.Frame, { BackgroundTransparency = active and 0 or 1 }, 0.15)
                    tween(btn.Stroke, { Transparency = active and 0 or 1 }, 0.15)
                    tween(btn.Label, { TextColor3 = active and Theme.Text or Theme.Muted }, 0.15)
                    if btn.Icon then
                        tween(btn.Icon, { ImageColor3 = active and Theme.Accent or Theme.Muted }, 0.15)
                    end
                end
            end
        end

        for i, page in ipairs(pageFrames) do
            local btn = create("TextButton", {
                Size                   = UDim2.fromOffset(0, 32),
                AutomaticSize          = Enum.AutomaticSize.X,
                BackgroundColor3       = Theme.Surface2,
                BackgroundTransparency = 1,
                Text                   = "",
                AutoButtonColor        = false,
                LayoutOrder            = i,
                Parent                 = tabBar,
            })
            corner(btn, UDim.new(0, 7))
            local btnStroke = stroke(btn, Theme.Stroke, 1)
            padding(btn, 12, 12)

            local icon
            if page.Icon then
                icon = create("ImageLabel", {
                    AnchorPoint            = Vector2.new(0, 0.5),
                    Position               = UDim2.new(0, 0, 0.5, 0),
                    Size                   = UDim2.fromOffset(14, 14),
                    BackgroundTransparency = 1,
                    ImageColor3            = Theme.Muted,
                    ScaleType              = Enum.ScaleType.Fit,
                    Parent                 = btn,
                })
                applyIcon(icon, page.Icon)
            end

            local label = textLabel({
                Position      = UDim2.fromOffset(icon and 20 or 0, 0),
                Size          = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                Text          = page.Title,
                TextSize      = 13,
                TextColor3    = Theme.Muted,
                TextTruncate  = Enum.TextTruncate.None,
                Parent        = btn,
            })

            buttons[i] = {
                Frame  = btn,
                Stroke = btnStroke,
                Label  = label,
                Icon   = icon,
            }

            btn.MouseEnter:Connect(function()
                if self._homeIndex ~= i then
                    tween(btn, { BackgroundTransparency = 0.4 }, 0.12)
                    tween(btnStroke, { Transparency = 0.5 }, 0.12)
                end
            end)
            btn.MouseLeave:Connect(function()
                if self._homeIndex ~= i then
                    tween(btn, { BackgroundTransparency = 1 }, 0.2)
                    tween(btnStroke, { Transparency = 1 }, 0.2)
                end
            end)
            btn.MouseButton1Click:Connect(function()
                selectPage(i)
            end)
        end

        selectPage(1)
    end

    tab._order = 10
    self.Home = tab
    return tab
end

function Window:Tab(opts, iconOverride)
    opts = merge(opts, { Title = "Name", Description = "Desc" })

    if iconOverride ~= nil and opts.Icon == nil then
        opts.Icon = iconOverride
    end

    local tab = setmetatable({
        Name   = opts.Name or "Tab",
        Window = self,
        _order = 0,
    }, Tab)

    local btn = create("TextButton", {
        Size                   = UDim2.new(1, 0, 0, 38),
        BackgroundColor3       = Theme.Surface2,
        BackgroundTransparency = 1,
        Text                   = "",
        AutoButtonColor        = false,
        LayoutOrder            = #self.Tabs + 1,
        Parent                 = self.TabList,
    })
    corner(btn)
    local btnStroke = stroke(btn, Theme.Stroke, 1)
    tab._button = btn

    local hasIcon = opts.Icon ~= nil
    if hasIcon then
        local icon = create("ImageLabel", {
            AnchorPoint            = Vector2.new(0, 0.5),
            Position               = UDim2.new(0, 12, 0.5, 0),
            Size                   = UDim2.fromOffset(16, 16),
            BackgroundTransparency = 1,
            ImageColor3            = Theme.Muted,
            ScaleType              = Enum.ScaleType.Fit,
            Parent                 = btn,
        })
        applyIcon(icon, opts.Icon)
        tab._icon = icon
    end

    tab._label = textLabel({
        Position   = UDim2.fromOffset(hasIcon and 36 or 14, 0),
        Size       = UDim2.new(1, -(hasIcon and 44 or 22), 1, 0),
        Text       = tab.Name,
        TextColor3 = Theme.Muted,
        Parent     = btn,
    })

    local page = create("Frame", {
        Name                   = tab.Name,
        Size                   = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible                = false,
        Parent                 = self.Content,
    })
    tab._page = page

    textLabel({
        Position = UDim2.fromOffset(24, 20),
        Size     = UDim2.new(1, -72, 0, 24),
        Text     = tab.Name,
        TextSize = 22,
        Parent   = page,
    })

    if opts.Desc then
        textLabel({
            Position   = UDim2.fromOffset(24, 44),
            Size       = UDim2.new(1, -72, 0, 16),
            Text       = opts.Desc,
            TextSize   = 13,
            FontFace   = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent     = page,
        })
    end

    local top = opts.Desc and 70 or 58

    local scroll = create("ScrollingFrame", {
        Position               = UDim2.fromOffset(0, top),
        Size                   = UDim2.new(1, 0, 1, -top),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ScrollBarThickness     = 2,
        ScrollBarImageColor3   = Theme.Accent,
        ScrollBarImageTransparency = 0.5,
        AutomaticCanvasSize    = Enum.AutomaticSize.Y,
        CanvasSize             = UDim2.new(),
        Parent                 = page,
    })
    padding(scroll, 24, 24, 2, 24)

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 8),
        Parent    = scroll,
    })

    tab.List = scroll

    local empty, childCount = emptyState(page, opts.Icon or "layout-grid", opts.EmptyText or "Nothing here yet"), 0

    scroll.ChildAdded:Connect(function(child)
        if child:IsA("GuiObject") then
            childCount += 1
            empty.Visible = false
        end
    end)
    scroll.ChildRemoved:Connect(function(child)
        if child:IsA("GuiObject") then
            childCount = math.max(childCount - 1, 0)
            empty.Visible = childCount <= 0
        end
    end)
    empty.Visible = true

    btn.MouseEnter:Connect(function()
        if self.CurrentTab ~= tab then
            tween(btn, { BackgroundTransparency = 0.4 }, 0.12)
            tween(btnStroke, { Transparency = 0.5 }, 0.12)
        end
    end)
    btn.MouseLeave:Connect(function()
        if self.CurrentTab ~= tab then
            tween(btn, { BackgroundTransparency = 1 }, 0.2)
            tween(btnStroke, { Transparency = 1 }, 0.2)
        end
    end)
    btn.MouseButton1Click:Connect(function()
        self:SelectTab(tab)
    end)

    tab._stroke = btnStroke

    if not self._introDone then
        btn.Visible = false
    end

    table.insert(self.Tabs, tab)

    if #self.Tabs == 1 then
        task.defer(function()
            self:SelectTab(tab)
        end)
    end

    return tab
end

Window.CreateTab = Window.Tab


function Window:Dialog(opts)
    opts = merge(opts, { Text = "Content", Message = "Content" })

    if self._dialog then
        self._dialog.Close()
    end

    local pad = 18

    local backdrop = create("TextButton", {
        Size                   = UDim2.fromScale(1, 1),
        BackgroundColor3       = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        Text                   = "",
        AutoButtonColor        = false,
        ZIndex                 = 40,
        Parent                 = self.Body,
    })

    local box = create("Frame", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.5, 10),
        Size                   = UDim2.fromOffset(300, 120),
        BackgroundColor3       = Theme.Background,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ZIndex                 = 41,
        Parent                 = backdrop,
    })
    corner(box, UDim.new(0, 10))
    local boxStroke = stroke(box, Theme.Stroke, 1)
    local boxScale  = create("UIScale", { Scale = 0.94, Parent = box })

    local tweens = {}
    local iconPad = 0

    if opts.Icon then
        local holder, img = iconButton(box, opts.Icon, Theme.Accent, UDim2.new(0, pad, 0, pad + 9))
        img.ImageTransparency = 1
        holder.ZIndex = 42
        img.ZIndex = 42
        table.insert(tweens, { img, "ImageTransparency", 0 })
        iconPad = 24
    end

    local title = textLabel({
        Position         = UDim2.fromOffset(pad + iconPad, pad),
        Size             = UDim2.new(1, -(pad * 2 + iconPad), 0, 18),
        Text             = opts.Title or "Are you sure?",
        TextSize         = 15,
        TextTransparency = 1,
        ZIndex           = 42,
        Parent           = box,
    })
    table.insert(tweens, { title, "TextTransparency", 0 })

    local contentH = 0
    if opts.Content then
        local content = textLabel({
            Position           = UDim2.fromOffset(pad, pad + 24),
            Size               = UDim2.new(1, -pad * 2, 0, 0),
            AutomaticSize      = Enum.AutomaticSize.Y,
            Text               = opts.Content,
            TextSize           = 13,
            FontFace           = Fonts.Regular,
            TextColor3         = Theme.Muted,
            TextWrapped        = true,
            TextTransparency   = 1,
            TextTruncate       = Enum.TextTruncate.None,
            TextYAlignment     = Enum.TextYAlignment.Top,
            ZIndex             = 42,
            Parent             = box,
        })
        table.insert(tweens, { content, "TextTransparency", 0 })

        contentH = math.max(content.TextBounds.Y, 16) + 6

        content:GetPropertyChangedSignal("TextBounds"):Connect(function()
            local h = math.max(content.TextBounds.Y, 16) + 6
            if h ~= contentH then
                contentH = h
                box.Size = UDim2.fromOffset(300, pad + 24 + contentH + 12 + 34 + pad)

                local row = box:FindFirstChild("ButtonRow")
                if row then
                    row.Position = UDim2.fromOffset(pad, pad + 24 + contentH + 12)
                end
            end
        end)
    end

    local buttonRow = create("Frame", {
        Name                   = "ButtonRow",
        Position               = UDim2.fromOffset(pad, pad + 24 + contentH + 12),
        Size                   = UDim2.new(1, -pad * 2, 0, 34),
        BackgroundTransparency = 1,
        ZIndex                 = 42,
        Parent                 = box,
    })
    create("UIListLayout", {
        FillDirection       = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder           = Enum.SortOrder.LayoutOrder,
        Padding             = UDim.new(0, 8),
        Parent              = buttonRow,
    })

    box.Size = UDim2.fromOffset(300, pad + 24 + contentH + 12 + 34 + pad)

    local api = {}
    local closed = false

    function api.Close()
        if closed then return end
        closed = true

        if self._dialog == api then
            self._dialog = nil
        end

        tween(backdrop, { BackgroundTransparency = 1 }, 0.18)
        tween(box, {
            BackgroundTransparency = 1,
            Position               = UDim2.new(0.5, 0, 0.5, 8),
        }, 0.18, Enum.EasingStyle.Quint)
        tween(boxScale, { Scale = 0.96 }, 0.18, Enum.EasingStyle.Quint)
        tween(boxStroke, { Transparency = 1 }, 0.12)

        for _, entry in ipairs(tweens) do
            tween(entry[1], { [entry[2]] = 1 }, 0.12)
        end

        task.delay(0.2, function()
            backdrop:Destroy()
        end)
    end

    for i, btnOpts in ipairs(opts.Buttons or {}) do
        local primary = btnOpts.Variant == "Primary"

        local btn = create("TextButton", {
            Size                   = UDim2.fromOffset(0, 34),
            AutomaticSize          = Enum.AutomaticSize.X,
            BackgroundColor3       = primary and Theme.Accent or Theme.Surface2,
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
            Text                   = "",
            AutoButtonColor        = false,
            ClipsDescendants       = true,
            LayoutOrder            = i,
            ZIndex                 = 43,
            Parent                 = buttonRow,
        })
        corner(btn, UDim.new(0, 7))
        local btnStroke = stroke(btn, primary and Theme.Accent or Theme.Stroke, 1)
        padding(btn, 14, 14)

        local label = textLabel({
            Size               = UDim2.new(0, 0, 1, 0),
            AutomaticSize      = Enum.AutomaticSize.X,
            Text               = btnOpts.Title or btnOpts.Name or "OK",
            TextSize           = 13,
            TextColor3         = primary and Theme.AccentDark or Theme.Text,
            TextXAlignment     = Enum.TextXAlignment.Center,
            TextTransparency   = 1,
            ZIndex             = 44,
            Parent             = btn,
        })

        local bgT  = primary and 0.12 or 0
        local stT  = primary and 0.4 or 0

        table.insert(tweens, { btn, "BackgroundTransparency", bgT })
        table.insert(tweens, { btnStroke, "Transparency", stT })
        table.insert(tweens, { label, "TextTransparency", 0 })

        btn.MouseEnter:Connect(function()
            if closed then return end
            if primary then
                tween(btn, { BackgroundTransparency = 0 }, 0.12)
                tween(btnStroke, { Transparency = 0 }, 0.12)
            else
                tween(btnStroke, { Color = Theme.StrokeHover }, 0.12)
            end
        end)
        btn.MouseLeave:Connect(function()
            if closed then return end
            if primary then
                tween(btn, { BackgroundTransparency = bgT }, 0.2)
                tween(btnStroke, { Transparency = stT }, 0.2)
            else
                tween(btnStroke, { Color = Theme.Stroke }, 0.2)
            end
        end)
        btn.MouseButton1Click:Connect(function()
            api.Close()
            safeCall(btnOpts.Callback)
        end)
    end

    if opts.CloseOnBackdrop ~= false then
        backdrop.MouseButton1Click:Connect(function()
            api.Close()
            safeCall(opts.OnCancel)
        end)
    end

    self._dialog = api

    tween(backdrop, { BackgroundTransparency = 0.45 }, 0.25)
    tween(box, {
        BackgroundTransparency = 0,
        Position               = UDim2.fromScale(0.5, 0.5),
    }, 0.3, Enum.EasingStyle.Quint)
    tween(boxStroke, { Transparency = 0 }, 0.25)
    tween(boxScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)

    for _, entry in ipairs(tweens) do
        tween(entry[1], { [entry[2]] = entry[3] }, 0.25)
    end

    return api
end

function Window:Confirm(opts)
    opts = merge(opts, { Text = "Content", Message = "Content" })

    return self:Dialog({
        Title   = opts.Title or "Are you sure?",
        Content = opts.Content,
        Icon    = opts.Icon,
        OnCancel = opts.OnCancel,
        Buttons = {
            { Title = opts.CancelText or "Cancel", Callback = opts.OnCancel },
            { Title = opts.ConfirmText or "Confirm", Variant = "Primary", Callback = opts.Callback },
        },
    })
end


local FONT_MED  = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local FONT_REG  = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular)
local FONT_BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

function Window:Notify(opts)
    opts = merge(opts, {
        Text = "Content",
        Message = "Content",
        Image = "Icon",
    })

    local duration = opts.Duration or 4
    local accent = typeColors[opts.Type] or Theme.Text

    self._notifyOrder += 1

    local outer = create("Frame", {
        Size                   = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        LayoutOrder            = self._notifyOrder,
        Parent                 = self.NotifyHolder,
    })

    local slide = create("Frame", {
        Position               = UDim2.fromOffset(320, 0),
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent                 = outer,
    })

    local shadow = create("ImageLabel", {
        Position               = UDim2.fromOffset(-20, -20),
        Size                   = UDim2.new(1, 40, 1, 40),
        BackgroundTransparency = 1,
        Image                  = Assets.Shadow,
        ImageColor3            = Color3.new(0, 0, 0),
        ImageTransparency      = 1,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(49, 49, 450, 450),
        ZIndex                 = 0,
        Parent                 = slide,
    })

    local card = create("CanvasGroup", {
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundColor3       = Theme.Background,
        BorderSizePixel        = 0,
        GroupTransparency      = 1,
        Parent                 = slide,
    })
    corner(card, UDim.new(0, 10))
    local cardStroke = stroke(card, Theme.Stroke)
    dividerLine(card)
    glow(card, UDim2.fromOffset(260, 120), UDim2.new(1, -10, 0, -10), 0.86, 90)

    local content = create("Frame", {
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent                 = card,
    })
    padding(content, 16, 16, 14, 24)

    local leftPad = 0
    if opts.Icon then
        iconButton(content, opts.Icon, accent == Theme.Text and Theme.Accent or accent, UDim2.new(0, 0, 0, 8))
        leftPad = 24
    end

    textLabel({
        Position   = UDim2.fromOffset(leftPad, 0),
        Size       = UDim2.new(1, -28 - leftPad, 0, 16),
        Text       = opts.Title or "Notification",
        TextSize   = 14,
        TextColor3 = accent,
        Parent     = content,
    })

    local closeBtn = create("TextButton", {
        AnchorPoint            = Vector2.new(1, 0),
        Position               = UDim2.new(1, 6, 0, -5),
        Size                   = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        Text                   = "×",
        TextColor3             = Theme.Muted,
        TextSize               = 22,
        FontFace               = Fonts.Bold,
        AutoButtonColor        = false,
        Parent                 = content,
    })
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, { TextColor3 = Theme.Text }, 0.15)
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, { TextColor3 = Theme.Muted }, 0.2)
    end)

    if opts.Content then
        textLabel({
            Position           = UDim2.fromOffset(leftPad, 21),
            Size               = UDim2.new(1, -leftPad, 0, 0),
            AutomaticSize      = Enum.AutomaticSize.Y,
            Text               = opts.Content,
            TextSize           = 13,
            FontFace           = Fonts.Regular,
            TextColor3         = Theme.Muted,
            TextWrapped        = true,
            TextTruncate       = Enum.TextTruncate.None,
            TextYAlignment     = Enum.TextYAlignment.Top,
            Parent             = content,
        })
    end

    local barBg = create("Frame", {
        AnchorPoint      = Vector2.new(0, 1),
        Position         = UDim2.new(0, 16, 1, -8),
        Size             = UDim2.new(1, -32, 0, 3),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel  = 0,
        Parent           = card,
    })
    corner(barBg, UDim.new(1, 0))

    local barFill = create("Frame", {
        Size             = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        Parent           = barBg,
    })
    corner(barFill, UDim.new(1, 0))

    task.defer(function()
        if outer.Parent then
            tween(outer, {
                Size = UDim2.new(1, 0, 0, card.AbsoluteSize.Y),
            }, 0.3, Enum.EasingStyle.Quint)
        end
    end)

    tween(slide, { Position = UDim2.fromOffset(0, 0) }, 0.5, Enum.EasingStyle.Back)
    tween(card, { GroupTransparency = 0 }, 0.3)
    tween(shadow, { ImageTransparency = 0.6 }, 0.4)
    tween(barFill, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear)

    local dismissed = false
    local function dismiss()
        if dismissed then return end
        dismissed = true

        for i, fn in ipairs(self._toasts) do
            if fn == dismiss then
                table.remove(self._toasts, i)
                break
            end
        end

        tween(slide, { Position = UDim2.fromOffset(320, 0) }, 0.3, Enum.EasingStyle.Quint)
        tween(card, { GroupTransparency = 1 }, 0.2)
        tween(cardStroke, { Transparency = 1 }, 0.15)
        tween(shadow, { ImageTransparency = 1 }, 0.2)

        task.delay(0.22, function()
            outer.ClipsDescendants = true
            tween(outer, { Size = UDim2.new(1, 0, 0, -4) }, 0.22, Enum.EasingStyle.Quint)
            task.delay(0.24, function()
                outer:Destroy()
            end)
        end)
    end

    task.delay(duration, dismiss)
    closeBtn.MouseButton1Click:Connect(dismiss)

    table.insert(self._toasts, dismiss)

    while #self._toasts > self.MaxNotifications do
        local oldest = table.remove(self._toasts, 1)
        oldest()
    end

    return { Dismiss = dismiss }
end

function Window:_listen(kind, fn, control)
    local list = self._inputListeners[kind]
    table.insert(list, fn)

    local function remove()
        for i, existing in ipairs(list) do
            if existing == fn then
                table.remove(list, i)
                break
            end
        end
    end

    if control then
        control._listeners = control._listeners or {}
        table.insert(control._listeners, remove)
    end

    return remove
end

function Window:_indicatorY(tab)
    local list  = self.TabList
    local scale = self.Scale.Scale
    return (tab._button.AbsolutePosition.Y - list.AbsolutePosition.Y + tab._button.AbsoluteSize.Y / 2) / scale
        + list.Position.Y.Offset
end

function Window:_placeIndicator(tab)
    local ind = self.Indicator
    local y   = self:_indicatorY(tab)

    if not ind.Visible then
        ind.Visible  = true
        ind.Position = UDim2.fromOffset(6, y)
        ind.Size     = UDim2.fromOffset(3, 0)
    end

    tween(ind, {
        Position = UDim2.fromOffset(6, y),
        Size     = UDim2.fromOffset(3, 18),
    }, 0.35, Enum.EasingStyle.Back)
end

function Window:SelectTab(tab)
    if self.CurrentTab == tab then return end

    local prev = self.CurrentTab
    self.CurrentTab = tab
    self:_settleTransition()

    local gen = (self._transitionGeneration or 0) + 1
    self._transitionGeneration = gen

    if prev then
        tween(prev._button, { BackgroundTransparency = 1 }, 0.2)
        tween(prev._stroke, { Transparency = 1 }, 0.2)
        tween(prev._label, { TextColor3 = Theme.Muted }, 0.2)
        if prev._icon then
            tween(prev._icon, { ImageColor3 = Theme.Muted }, 0.2)
        end

        local out = self._outLayer
        prev._page.Parent = out
        self._outPage = prev._page
        out.GroupTransparency = 0
        out.Position = UDim2.fromOffset(0, 0)
        out.Visible = true

        tween(out, {
            GroupTransparency = 1,
            Position          = UDim2.fromOffset(0, -10),
        }, 0.18)

        task.delay(0.18, function()
            if self._transitionGeneration == gen then
                self:_settleOut()
            end
        end)
    end

    tween(tab._button, { BackgroundTransparency = 0 }, 0.2)
    tween(tab._stroke, { Transparency = 0 }, 0.2)
    tween(tab._label, { TextColor3 = Theme.Text }, 0.2)
    if tab._icon then
        tween(tab._icon, { ImageColor3 = Theme.Accent }, 0.2)
    end

    self:_placeIndicator(tab)

    local page = tab._page
    page.Position = UDim2.fromOffset(0, 0)
    page.Visible  = true
    page.Parent   = self._inLayer
    self._inPage  = page

    slideIn(self._inLayer)

    task.delay(0.32, function()
        if self._transitionGeneration == gen then
            self:_settleIn()
        end
    end)
end

function Window:_settleOut()
    local page = self._outPage
    if page then
        page.Parent  = self.Content
        page.Visible = false
        self._outPage = nil
    end
    self._outLayer.Visible = false
end

function Window:_settleIn()
    local page = self._inPage
    if page then
        page.Parent   = self.Content
        page.Position = UDim2.fromOffset(0, 0)
        self._inPage  = nil
    end
    self._inLayer.Visible = false
end

function Window:_settleTransition()
    self:_settleOut()
    self:_settleIn()
end

function Window:Toggle(state)
    if not self._introDone then return end

    if state == nil then
        state = not self.Open
    end

    if state == self.Open then return end
    self.Open = state

    if state then
        self.Root.Visible = true
        tween(self.Scale, { Scale = self._fitScale or 1 }, 0.4, Enum.EasingStyle.Back)
        tween(self.Body, { GroupTransparency = 0 }, 0.25)
        tween(self.BodyStroke, { Transparency = 0 }, 0.25)
        tween(self.Shadow, { ImageTransparency = 0.6 }, 0.3)
    else
        tween(self.Scale, { Scale = (self._fitScale or 1) * 0.94 }, 0.2, Enum.EasingStyle.Quint)
        tween(self.Body, { GroupTransparency = 1 }, 0.16)
        tween(self.BodyStroke, { Transparency = 1 }, 0.12)
        tween(self.Shadow, { ImageTransparency = 1 }, 0.16)

        task.delay(0.2, function()
            if not self.Open then
                self.Root.Visible = false
            end
        end)
    end
end

function Window:SetKeepOnScreen(value)
    self.KeepOnScreen = value ~= false
    if self.KeepOnScreen then
        self:_clampToScreen()
    end
end

function Window:SetKeybind(key)
    self.Keybind = key
    self._keyChipLabel.Text = keyName(key)
end

function Window:Destroy()
    if self._destroyed then return end
    self._destroyed = true

    for i, win in ipairs(AirFlow.Windows) do
        if win == self then
            table.remove(AirFlow.Windows, i)
            break
        end
    end

    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    self._connections = {}

    tween(self.Scale, { Scale = 0.9 }, 0.2)
    tween(self.Body, { GroupTransparency = 1 }, 0.2)
    tween(self.BodyStroke, { Transparency = 1 }, 0.12)
    tween(self.Shadow, { ImageTransparency = 1 }, 0.2)

    task.delay(0.22, function()
        self.Gui:Destroy()
    end)
end

return AirFlow
