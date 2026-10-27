--[[
    QQ Fun GUI  -  Version: hello world
    Tabs: Movement | Body | World | Theme | Settings
    RightShift hides / shows the window. Re-executing cleans up the previous run.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local env = getgenv()

if env.QQFunUnload then
	pcall(env.QQFunUnload)
end

local conns = {}
local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(conns, c)
	return c
end

----------------------------------------------------------------
-- Theme system (every themed instance is registered, so the
-- theme editor can recolor the whole GUI instantly)
----------------------------------------------------------------
local C = {
	text = Color3.fromRGB(235, 235, 235),
	dim = Color3.fromRGB(125, 125, 125),
	accent = Color3.fromRGB(255, 105, 150),
	accentDark = Color3.fromRGB(120, 50, 75),
	line = Color3.fromRGB(60, 36, 46),
	bg = Color3.fromRGB(13, 13, 13),
	panel = Color3.fromRGB(22, 22, 22),
	panel2 = Color3.fromRGB(28, 28, 28),
	off = Color3.fromRGB(38, 38, 38),
}
local THEME_KEYS = { "accent", "accentDark", "line", "bg", "panel", "panel2", "off" }
local FONT = Enum.Font.Code

local bound = {}      -- { instance, property, key }
local refreshers = {} -- functions re-run after a theme change

local function new(class, props, parent, noTheme)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
		if not noTheme and typeof(v) == "Color3" then
			for _, key in ipairs(THEME_KEYS) do
				if C[key] == v then
					table.insert(bound, { o, k, key })
					break
				end
			end
		end
	end
	o.Parent = parent
	return o
end

local function applyTheme(accent, shade)
	local h, s = accent:ToHSV()
	local function g(v) return Color3.fromRGB(math.min(v, 255), math.min(v, 255), math.min(v, 255)) end
	C.accent = accent
	C.accentDark = Color3.fromHSV(h, s * 0.6, 0.45)
	C.line = Color3.fromHSV(h, 0.35, 0.26)
	C.bg = g(shade)
	C.panel = g(shade + 9)
	C.panel2 = g(shade + 15)
	C.off = g(shade + 25)

	for _, b in ipairs(bound) do
		local inst, prop, key = b[1], b[2], b[3]
		if inst.Parent then
			inst[prop] = C[key]
		end
	end
	for _, fn in ipairs(refreshers) do
		pcall(fn)
	end
end

local function label(parent, text, size, color, pos, sz, align)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		Text = text,
		TextSize = size or 13,
		TextColor3 = color or C.text,
		Position = pos or UDim2.new(),
		Size = sz or UDim2.new(1, 0, 1, 0),
		TextXAlignment = align or Enum.TextXAlignment.Left,
	}, parent)
end

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local S = {
	Ice = false, IceGrip = 0.8,
	Moon = false, GravityVal = 30,
	SuperJump = false, JumpVal = 150,
	InfJump = false,
	Bouncy = false, BounceVal = 0.8,
	Bhop = false,
	Speed = false, SpeedVal = 60,
	Fly = false, FlySpeed = 60,
	Size = false, SizeVal = 3,
	BigHead = false, HeadVal = 3,
	Rainbow = false,
	Spin = false, SpinSpeed = 720,
	Moonwalk = false,
	Disco = false,
	Drunk = false, DrunkVal = 1,
	FOV = false, FOVVal = 100,
	RainbowTheme = false, RainbowSpeed = 0.15,
}

env.QQFunGravity = env.QQFunGravity or workspace.Gravity
local origGravity = env.QQFunGravity

local function getChar() return LocalPlayer.Character end
local function getHum()
	local c = getChar()
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
	local c = getChar()
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- original humanoid values (captured per character)
local O = {}
local function captureOriginals()
	local hum = getHum()
	if hum then
		O.WalkSpeed = hum.WalkSpeed
		O.JumpPower = hum.JumpPower
		O.JumpHeight = hum.JumpHeight
	end
end
captureOriginals()

----------------------------------------------------------------
-- Root GUI
----------------------------------------------------------------
local parentGui = (gethui and gethui()) or CoreGui
local gui = new("ScreenGui", {
	Name = "QQFunGUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
}, parentGui)

local main = new("Frame", {
	Name = "Main", BackgroundColor3 = C.bg, BorderSizePixel = 0,
	Size = UDim2.fromOffset(640, 440), Position = UDim2.new(0.5, -320, 0.5, -220),
}, gui)
new("UIStroke", { Color = Color3.fromRGB(45, 45, 45), Thickness = 1 }, main)

local titleBar = new("Frame", { BackgroundColor3 = C.bg, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 30) }, main)
label(titleBar, "QQ Fun GUI", 13, C.accent, UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0))
new("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1) }, titleBar)

do -- dragging
	local dragging, dragStart, startPos
	connect(titleBar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, input.Position, main.Position
		end
	end)
	connect(UIS.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	connect(UIS.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

local tabBar = new("Frame", { BackgroundColor3 = C.bg, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 32) }, main)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, tabBar)
new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, tabBar)
new("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 61), Size = UDim2.new(1, 0, 0, 1) }, main)

local footer = new("Frame", { BackgroundColor3 = C.bg, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 20) }, main)
label(footer, "Version: hello world", 11, C.dim, UDim2.fromOffset(10, 0), UDim2.new(0.6, -10, 1, 0))
label(footer, "RightShift = toggle", 11, C.dim, UDim2.new(0.6, 0, 0, 0), UDim2.new(0.4, -10, 1, 0), Enum.TextXAlignment.Right)

local content = new("Frame", {
	BackgroundColor3 = C.panel, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 70), Size = UDim2.new(1, -16, 1, -98),
}, main)

----------------------------------------------------------------
-- Tabs
----------------------------------------------------------------
local pages, tabButtons, currentTab = {}, {}, nil

local function selectTab(name)
	currentTab = name
	for n, page in pairs(pages) do
		page.Visible = (n == name)
	end
	for n, b in pairs(tabButtons) do
		local active = (n == name)
		b.btn.TextColor3 = active and C.accent or C.dim
		b.line.Visible = active
	end
end
table.insert(refreshers, function() if currentTab then selectTab(currentTab) end end)

local function addTab(name)
	local btn = new("TextButton", {
		BackgroundTransparency = 1, Font = FONT, Text = name, TextSize = 13, TextColor3 = C.dim,
		Size = UDim2.fromOffset(#name * 8 + 28, 32), AutoButtonColor = false,
	}, tabBar)
	local line = new("Frame", {
		BackgroundColor3 = C.accent, BorderSizePixel = 0, Position = UDim2.new(0, 8, 1, -2), Size = UDim2.new(1, -16, 0, 2), Visible = false,
	}, btn)
	tabButtons[name] = { btn = btn, line = line }
	connect(btn.MouseButton1Click, function() selectTab(name) end)

	local page = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Visible = false }, content)
	pages[name] = page
	return page
end

local function scrollPage(parent, pos, size)
	local sf = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = pos or UDim2.new(), Size = size or UDim2.new(1, 0, 1, 0),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
	}, parent)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, sf)
	return sf
end

----------------------------------------------------------------
-- Components
----------------------------------------------------------------
local function Section(parent, text)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24) }, parent)
	label(row, text, 13, C.accent, UDim2.new(), UDim2.new(1, 0, 0, 20))
	new("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 1) }, row)
	return row
end

local function Toggle(parent, text, default, cb)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26) }, parent)
	new("Frame", { BackgroundColor3 = C.accent, BorderSizePixel = 0, Size = UDim2.fromOffset(4, 4), Position = UDim2.new(0, 2, 0.5, -2) }, row)
	label(row, text, 13, C.text, UDim2.fromOffset(12, 0), UDim2.new(1, -60, 1, 0))

	local track = new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundColor3 = C.off, BorderSizePixel = 0,
		Size = UDim2.fromOffset(34, 16), Position = UDim2.new(1, -38, 0.5, -8),
	}, row, true)
	local knob = new("Frame", {
		BackgroundColor3 = C.dim, BorderSizePixel = 0, Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(3, 3),
	}, track, true)

	local state = false
	local function paint(animate)
		local goalT = { BackgroundColor3 = state and C.accentDark or C.off }
		local goalK = {
			Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3),
			BackgroundColor3 = state and C.accent or C.dim,
		}
		if animate then
			local ti = TweenInfo.new(0.12)
			TweenService:Create(track, ti, goalT):Play()
			TweenService:Create(knob, ti, goalK):Play()
		else
			for k, v in pairs(goalT) do track[k] = v end
			for k, v in pairs(goalK) do knob[k] = v end
		end
	end
	local function set(v, silent)
		state = v
		paint(true)
		if not silent and cb then cb(v) end
	end
	connect(track.MouseButton1Click, function() set(not state) end)
	table.insert(refreshers, function() paint(false) end)
	set(default, true)
	return { Set = set, Get = function() return state end }
end

local function Slider(parent, text, min, max, default, decimals, cb)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38) }, parent)
	label(row, text, 13, C.dim, UDim2.fromOffset(2, 0), UDim2.new(0.7, 0, 0, 18))
	local valueLabel = label(row, "", 12, C.dim, UDim2.new(0.7, 0, 0, 0), UDim2.new(0.3, 0, 0, 18), Enum.TextXAlignment.Right)

	local bar = new("Frame", { BackgroundColor3 = C.off, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 6) }, row)
	local fill = new("Frame", { BackgroundColor3 = C.accent, BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0) }, bar)
	local marker = new("Frame", {
		BackgroundColor3 = C.accent, BorderSizePixel = 0, Size = UDim2.fromOffset(3, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
	}, bar)
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 22) }, row)

	local fmt = "%." .. decimals .. "f"
	local value = default
	local function update(v, silent)
		value = math.clamp(v, min, max)
		local a = (value - min) / (max - min)
		fill.Size = UDim2.new(a, 0, 1, 0)
		marker.Position = UDim2.new(a, 0, 0.5, 0)
		valueLabel.Text = string.format(fmt, value)
		if not silent and cb then cb(value) end
	end
	local function fromX(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		local mult = 10 ^ decimals
		update(math.floor((min + (max - min) * a) * mult + 0.5) / mult)
	end

	local dragging = false
	connect(hit.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	connect(UIS.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)
	connect(UIS.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	update(default, true)
	return { Set = update, Get = function() return value end }
end

local function Button(parent, text, cb)
	local b = new("TextButton", {
		BackgroundColor3 = C.panel2, BorderSizePixel = 0, Font = FONT, Text = text, TextSize = 13, TextColor3 = C.text,
		AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 28),
	}, parent)
	new("UIStroke", { Color = C.accentDark, Thickness = 1 }, b)
	connect(b.MouseEnter, function() b.BackgroundColor3 = C.off end)
	connect(b.MouseLeave, function() b.BackgroundColor3 = C.panel2 end)
	connect(b.MouseButton1Click, function() if cb then cb() end end)
	return b
end

local function Note(parent, text, height)
	local l = label(parent, text, 12, C.dim, nil, UDim2.new(1, 0, 0, height or 30))
	l.TextWrapped = true
	l.TextYAlignment = Enum.TextYAlignment.Top
	return l
end

-- effect toggle: sets S[key], runs onChange, and is registered so "Disable All" can switch it off
local effectToggles = {}
local function FX(parent, text, key, onChange)
	local t = Toggle(parent, text, false, function(v)
		S[key] = v
		if onChange then onChange(v) end
	end)
	table.insert(effectToggles, t)
	return t
end

----------------------------------------------------------------
-- Effect helpers (restore things when switched off)
----------------------------------------------------------------
local function setScales()
	local hum = getHum()
	if not hum then return end
	local size = S.Size and S.SizeVal or 1
	for _, n in ipairs({ "BodyHeightScale", "BodyWidthScale", "BodyDepthScale" }) do
		local v = hum:FindFirstChild(n)
		if v then v.Value = size end
	end
	local hs = hum:FindFirstChild("HeadScale")
	if hs then hs.Value = S.BigHead and S.HeadVal or 1 end
end

local rainbowOrig = {}
local function restoreRainbow()
	for part, col in pairs(rainbowOrig) do
		if part.Parent then part.Color = col end
	end
	table.clear(rainbowOrig)
end

local lightOrig
local function restoreLighting()
	if lightOrig then
		Lighting.Ambient = lightOrig.Ambient
		Lighting.OutdoorAmbient = lightOrig.OutdoorAmbient
		Lighting.ColorShift_Top = lightOrig.ColorShift_Top
		lightOrig = nil
	end
end

local fovOrig
local function restoreFOV()
	if fovOrig and workspace.CurrentCamera then
		workspace.CurrentCamera.FieldOfView = fovOrig
	end
	fovOrig = nil
end

----------------------------------------------------------------
-- MOVEMENT TAB
----------------------------------------------------------------
local movePage = addTab("Movement")
local moveScroll = scrollPage(movePage)

Section(moveScroll, "Ice Mode")
FX(moveScroll, "Ice Skating (feel like you're on ice)", "Ice")
Slider(moveScroll, "Grip (lower = slipperier)", 0.2, 6, 0.8, 1, function(v) S.IceGrip = v end)

Section(moveScroll, "Gravity & Jumping")
FX(moveScroll, "Moon Gravity", "Moon", function(v)
	if not v then workspace.Gravity = origGravity end
end)
Slider(moveScroll, "Gravity", 0, 196, 30, 0, function(v) S.GravityVal = v end)
FX(moveScroll, "Super Jump", "SuperJump", function(v)
	if not v then
		local hum = getHum()
		if hum then
			hum.JumpPower = O.JumpPower or 50
			hum.JumpHeight = O.JumpHeight or 7.2
		end
	end
end)
Slider(moveScroll, "Jump Power", 50, 500, 150, 0, function(v) S.JumpVal = v end)
FX(moveScroll, "Infinite Jump", "InfJump")
FX(moveScroll, "Bouncy Landings", "Bouncy")
Slider(moveScroll, "Bounciness", 0.3, 1.5, 0.8, 2, function(v) S.BounceVal = v end)
FX(moveScroll, "Auto Bunnyhop", "Bhop")

Section(moveScroll, "Speed & Flight")
FX(moveScroll, "Speed Boost", "Speed", function(v)
	if not v then
		local hum = getHum()
		if hum then hum.WalkSpeed = O.WalkSpeed or 16 end
	end
end)
Slider(moveScroll, "Walk Speed", 16, 250, 60, 0, function(v) S.SpeedVal = v end)
FX(moveScroll, "Fly (WASD + Space / Shift)", "Fly")
Slider(moveScroll, "Fly Speed", 10, 200, 60, 0, function(v) S.FlySpeed = v end)

----------------------------------------------------------------
-- BODY TAB
----------------------------------------------------------------
local bodyPage = addTab("Body")
local bodyScroll = scrollPage(bodyPage)

Section(bodyScroll, "Silly Bodies")
FX(bodyScroll, "Giant / Tiny Mode", "Size", function() setScales() end)
Slider(bodyScroll, "Body Size", 0.25, 6, 3, 2, function(v) S.SizeVal = v; if S.Size then setScales() end end)
FX(bodyScroll, "Big Head", "BigHead", function() setScales() end)
Slider(bodyScroll, "Head Size", 0.5, 8, 3, 2, function(v) S.HeadVal = v; if S.BigHead then setScales() end end)
Note(bodyScroll, "Body / head sizes need an R15 character (local only, other players won't see it).", 30)

Section(bodyScroll, "Style")
FX(bodyScroll, "Rainbow Character", "Rainbow", function(v) if not v then restoreRainbow() end end)
FX(bodyScroll, "Spin", "Spin")
Slider(bodyScroll, "Spin Speed (deg/s)", 60, 3000, 720, 0, function(v) S.SpinSpeed = v end)
FX(bodyScroll, "Moonwalk (walk backwards)", "Moonwalk", function(v)
	local hum = getHum()
	if hum then hum.AutoRotate = not v end
end)

----------------------------------------------------------------
-- WORLD TAB
----------------------------------------------------------------
local worldPage = addTab("World")
local worldScroll = scrollPage(worldPage)

Section(worldScroll, "Atmosphere")
FX(worldScroll, "Disco Lighting", "Disco", function(v)
	if v then
		lightOrig = lightOrig or {
			Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, ColorShift_Top = Lighting.ColorShift_Top,
		}
	else
		restoreLighting()
	end
end)

Section(worldScroll, "Camera")
FX(worldScroll, "Drunk Camera", "Drunk")
Slider(worldScroll, "Wobble Amount", 0.1, 3, 1, 1, function(v) S.DrunkVal = v end)
FX(worldScroll, "Custom Field of View", "FOV", function(v)
	local cam = workspace.CurrentCamera
	if v then
		fovOrig = fovOrig or (cam and cam.FieldOfView)
	else
		restoreFOV()
	end
end)
Slider(worldScroll, "FOV", 30, 120, 100, 0, function(v) S.FOVVal = v end)

----------------------------------------------------------------
-- THEME TAB (presets + editor)
----------------------------------------------------------------
local THEMES = {
	-- name, accent, window shade
	{ "Hot Pink",     Color3.fromRGB(255, 105, 150), 13 },
	{ "Slime",        Color3.fromRGB(120, 255, 60),  13 },
	{ "Bubblegum",    Color3.fromRGB(255, 150, 220), 14 },
	{ "Lava Lamp",    Color3.fromRGB(255, 90, 40),   12 },
	{ "Deep Sea",     Color3.fromRGB(40, 140, 255),  10 },
	{ "Grape Soda",   Color3.fromRGB(170, 90, 255),  12 },
	{ "Sunburn",      Color3.fromRGB(255, 170, 50),  13 },
	{ "Mint Choc",    Color3.fromRGB(90, 230, 170),  11 },
	{ "Frostbite",    Color3.fromRGB(130, 210, 255), 16 },
	{ "Banana",       Color3.fromRGB(255, 225, 70),  13 },
	{ "Cherry Cola",  Color3.fromRGB(220, 40, 70),   10 },
	{ "Toxic Waste",  Color3.fromRGB(160, 255, 0),   8 },
	{ "Ghost",        Color3.fromRGB(225, 225, 240), 22 },
	{ "Midnight",     Color3.fromRGB(90, 90, 230),   6 },
	{ "Orange Crush", Color3.fromRGB(255, 130, 0),   13 },
	{ "Seafoam",      Color3.fromRGB(100, 240, 210), 17 },
}

local themePage = addTab("Theme")
local currentPreset = 1

local themeList = new("ScrollingFrame", {
	BackgroundColor3 = C.bg, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(0, 170, 1, -12),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
}, themePage)
new("UIListLayout", { Padding = UDim.new(0, 0) }, themeList)

local themeScroll = scrollPage(themePage, UDim2.fromOffset(184, 0), UDim2.new(1, -184, 1, 0))

local rS, gS, bS, shadeS

local function pushTheme()
	applyTheme(Color3.new(rS.Get() / 255, gS.Get() / 255, bS.Get() / 255), shadeS.Get())
end

local themeButtons = {}
local function paintThemeList()
	for i, b in ipairs(themeButtons) do
		local on = i == currentPreset
		b.BackgroundColor3 = on and C.panel2 or C.bg
		b.TextColor3 = on and C.accent or C.dim
	end
end
table.insert(refreshers, paintThemeList)

local function selectThemePreset(i)
	local t = THEMES[i]
	currentPreset = i
	rS.Set(math.floor(t[2].R * 255 + 0.5), true)
	gS.Set(math.floor(t[2].G * 255 + 0.5), true)
	bS.Set(math.floor(t[2].B * 255 + 0.5), true)
	shadeS.Set(t[3], true)
	applyTheme(t[2], t[3])
end

for i, t in ipairs(THEMES) do
	local b = new("TextButton", {
		BackgroundColor3 = C.bg, BorderSizePixel = 0, Font = FONT, TextSize = 13, TextColor3 = C.dim, Text = t[1],
		TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 26),
	}, themeList, true)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, b)
	new("Frame", {
		BackgroundColor3 = t[2], BorderSizePixel = 0, Size = UDim2.fromOffset(10, 10), Position = UDim2.new(1, -20, 0.5, -5),
	}, b, true)
	themeButtons[i] = b
	connect(b.MouseButton1Click, function() selectThemePreset(i) end)
end

Section(themeScroll, "Theme Editor")
rS = Slider(themeScroll, "Accent Red", 0, 255, 255, 0, function() currentPreset = 0; pushTheme() end)
gS = Slider(themeScroll, "Accent Green", 0, 255, 105, 0, function() currentPreset = 0; pushTheme() end)
bS = Slider(themeScroll, "Accent Blue", 0, 255, 150, 0, function() currentPreset = 0; pushTheme() end)
shadeS = Slider(themeScroll, "Window Shade (dark to lighter)", 0, 60, 13, 0, function() currentPreset = 0; pushTheme() end)

Toggle(themeScroll, "Rainbow Theme", false, function(v) S.RainbowTheme = v end)
Slider(themeScroll, "Rainbow Speed", 0.02, 1, 0.15, 2, function(v) S.RainbowSpeed = v end)

Button(themeScroll, "Randomize Colors", function()
	S.RainbowTheme = false
	currentPreset = 0
	local c = Color3.fromHSV(math.random(), 0.55 + math.random() * 0.35, 1)
	rS.Set(math.floor(c.R * 255 + 0.5), true)
	gS.Set(math.floor(c.G * 255 + 0.5), true)
	bS.Set(math.floor(c.B * 255 + 0.5), true)
	pushTheme()
end)
Button(themeScroll, "Reset to Hot Pink", function() selectThemePreset(1) end)

paintThemeList()

----------------------------------------------------------------
-- SETTINGS TAB
----------------------------------------------------------------
local setPage = addTab("Settings")
local setScroll = scrollPage(setPage)

local function disableAll()
	for _, t in ipairs(effectToggles) do
		if t.Get() then t.Set(false) end
	end
end

Section(setScroll, "Interface")
Note(setScroll, "RightShift hides / shows this window. Drag the title bar to move it.", 30)
Button(setScroll, "Disable All Effects", disableAll)

local function unload()
	disableAll()
	workspace.Gravity = origGravity
	env.QQFunGravity = nil
	restoreRainbow()
	restoreLighting()
	restoreFOV()
	local hum = getHum()
	if hum then hum.AutoRotate = true end
	for _, c in ipairs(conns) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(conns)
	pcall(function() RunService:UnbindFromRenderStep("QQFunCam") end)
	gui:Destroy()
	env.QQFunUnload = nil
end
env.QQFunUnload = unload
Button(setScroll, "Unload GUI", unload)

----------------------------------------------------------------
-- MAIN LOOPS
----------------------------------------------------------------
local iceVel = Vector3.zero
local prevGrounded, lastY = true, 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function keyDown(k)
	return UIS:IsKeyDown(k) and not UIS:GetFocusedTextBox()
end

-- physics-affecting effects (run before each physics step)
connect(RunService.PreSimulation, function(dt)
	local char = getChar()
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then return end
	rayParams.FilterDescendantsInstances = { char }

	if S.Moon then workspace.Gravity = S.GravityVal end
	if S.Speed then hum.WalkSpeed = S.SpeedVal end
	if S.SuperJump then
		if hum.UseJumpPower then
			hum.JumpPower = S.JumpVal
		else
			hum.JumpHeight = 7.2 * (S.JumpVal / 50) ^ 2
		end
	end

	local vel = root.AssemblyLinearVelocity
	local grounded = hum.FloorMaterial ~= Enum.Material.Air

	if S.Bhop and grounded and hum.MoveDirection.Magnitude > 0 then
		hum.Jump = true
	end

	-- bouncy landings
	if S.Bouncy and grounded and not prevGrounded and lastY < -25 then
		root.AssemblyLinearVelocity = Vector3.new(vel.X, math.min(-lastY * S.BounceVal, 200), vel.Z)
		vel = root.AssemblyLinearVelocity
	end

	if S.Fly then
		local cam = workspace.CurrentCamera
		local dir = Vector3.zero
		if keyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
		if keyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
		if keyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
		if keyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
		if keyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
		if keyDown(Enum.KeyCode.LeftShift) or keyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
		if dir.Magnitude == 0 then dir = hum.MoveDirection end -- mobile / gamepad fallback
		if dir.Magnitude > 0 then dir = dir.Unit end
		root.AssemblyLinearVelocity = dir * S.FlySpeed + Vector3.new(0, workspace.Gravity * dt * 0.5, 0)
		iceVel = Vector3.zero
	elseif S.Ice then
		local target = hum.MoveDirection * hum.WalkSpeed
		local rate = grounded and S.IceGrip or S.IceGrip * 0.25
		iceVel = iceVel:Lerp(target, 1 - math.exp(-dt * rate))

		-- slide along walls instead of through them
		if iceVel.Magnitude > 2 then
			local hit = workspace:Raycast(root.Position, iceVel.Unit * 2.5, rayParams)
			if hit then
				local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
				if n.Magnitude > 0.01 then
					n = n.Unit
					local d = iceVel:Dot(n)
					if d < 0 then iceVel -= n * d end
				end
			end
		end
		root.AssemblyLinearVelocity = Vector3.new(iceVel.X, vel.Y, iceVel.Z)
	else
		iceVel = Vector3.new(vel.X, 0, vel.Z)
	end

	prevGrounded = grounded
	lastY = root.AssemblyLinearVelocity.Y
end)

connect(UIS.JumpRequest, function()
	if S.InfJump then
		local hum = getHum()
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

-- body effects
connect(RunService.Heartbeat, function(dt)
	local hum = getHum()
	local root = getRoot()
	if not hum or not root then return end

	if S.Spin then
		root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(S.SpinSpeed) * dt, 0)
	elseif S.Moonwalk then
		hum.AutoRotate = false
		local md = hum.MoveDirection
		if md.Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position - Vector3.new(md.X, 0, md.Z))
		end
	end
end)

-- visual effects
local rbAcc = 0
connect(RunService.RenderStepped, function(dt)
	local t = os.clock()

	if S.Rainbow then
		local char = getChar()
		if char then
			local hue, i = (t * 0.4) % 1, 0
			for _, d in ipairs(char:GetDescendants()) do
				if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
					if not rainbowOrig[d] then rainbowOrig[d] = d.Color end
					i += 1
					d.Color = Color3.fromHSV((hue + i * 0.04) % 1, 0.8, 1)
				end
			end
		end
	end

	if S.Disco and lightOrig then
		local h = (t * 0.5) % 1
		Lighting.Ambient = Color3.fromHSV(h, 0.8, 0.8)
		Lighting.OutdoorAmbient = Color3.fromHSV((h + 0.33) % 1, 0.8, 0.8)
		Lighting.ColorShift_Top = Color3.fromHSV((h + 0.66) % 1, 0.8, 1)
	end

	if S.FOV and workspace.CurrentCamera then
		workspace.CurrentCamera.FieldOfView = S.FOVVal
	end

	if S.RainbowTheme then
		rbAcc += dt
		if rbAcc > 1 / 15 then
			rbAcc = 0
			local c = Color3.fromHSV((t * S.RainbowSpeed) % 1, 0.7, 1)
			currentPreset = 0
			rS.Set(math.floor(c.R * 255 + 0.5), true)
			gS.Set(math.floor(c.G * 255 + 0.5), true)
			bS.Set(math.floor(c.B * 255 + 0.5), true)
			applyTheme(c, shadeS.Get())
		end
	end
end)

-- drunk camera (runs right after the default camera)
RunService:BindToRenderStep("QQFunCam", Enum.RenderPriority.Camera.Value + 1, function()
	if not S.Drunk then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local t, k = os.clock(), S.DrunkVal
	cam.CFrame = cam.CFrame * CFrame.Angles(
		math.sin(t * 0.9) * math.rad(4 * k),
		math.sin(t * 0.7) * math.rad(4 * k),
		math.sin(t * 1.3) * math.rad(12 * k)
	)
end)

-- respawn handling
connect(LocalPlayer.CharacterAdded, function(char)
	table.clear(rainbowOrig)
	iceVel = Vector3.zero
	prevGrounded, lastY = true, 0
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		task.wait(0.5)
		captureOriginals()
		setScales()
		if S.Moonwalk then hum.AutoRotate = false end
	end
end)

connect(UIS.InputBegan, function(input)
	if input.KeyCode == Enum.KeyCode.RightShift then
		main.Visible = not main.Visible
	end
end)

selectTab("Movement")
