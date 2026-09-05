-- Мобильный обозреватель плейса: полное дерево DataModel, поиск, выбор объекта
-- тапом по игровому миру, настройки интерфейса. Только официальный Roblox API,
-- без executor-функций (hookmetamethod, firetouchinterest и т.п.).
--
-- Запуск через executor (телефон и ПК одинаково):
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/hoykoS/Dex/main/Dex.lua"))()
--
-- Тот же файл можно вставить как обычный LocalScript в StarterPlayerScripts —
-- тогда, если хочешь ограничить доступ другим игрокам своего плейса, впиши
-- свои UserId в CONFIG.Admins (по умолчанию список пуст — панель открыта всем).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local CONFIG = {
	Admins = {},
	AllowPlaceOwner = true,
	AllowInStudio = true,
}

local LocalPlayer = Players.LocalPlayer

local function isAllowed()
	if CONFIG.AllowInStudio and RunService:IsStudio() then
		return true
	end

	if #CONFIG.Admins == 0 then
		return true
	end

	for _, id in ipairs(CONFIG.Admins) do
		if id == LocalPlayer.UserId then
			return true
		end
	end

	if CONFIG.AllowPlaceOwner and game.CreatorType == Enum.CreatorType.User then
		return LocalPlayer.UserId == game.CreatorId
	end

	return false
end

if not isAllowed() then
	return
end

local ROW_HEIGHT = 40
local INDENT = 18
local HEADER_HEIGHT = 48
local TABBAR_HEIGHT = 44
local TOOLBAR_HEIGHT = 92
local DIVIDER_HEIGHT = 1
local MIN_SCALE = 0.7
local MAX_SCALE = 1.6

local THEME = {
	Background = Color3.fromRGB(18, 20, 26),
	Panel = Color3.fromRGB(26, 29, 37),
	PanelLight = Color3.fromRGB(34, 38, 48),
	Accent = Color3.fromRGB(120, 170, 255),
	Text = Color3.fromRGB(235, 238, 245),
	TextDim = Color3.fromRGB(150, 158, 175),
	Highlight = Color3.fromRGB(255, 90, 90),
}

local CLASS_COLORS = {
	Folder = Color3.fromRGB(240, 196, 90),
	Model = Color3.fromRGB(120, 170, 255),
	Part = Color3.fromRGB(150, 200, 130),
	MeshPart = Color3.fromRGB(150, 200, 130),
	UnionOperation = Color3.fromRGB(150, 200, 130),
	Script = Color3.fromRGB(120, 220, 150),
	LocalScript = Color3.fromRGB(120, 220, 150),
	ModuleScript = Color3.fromRGB(120, 220, 150),
	Sound = Color3.fromRGB(220, 140, 220),
	Tool = Color3.fromRGB(230, 150, 90),
	Workspace = Color3.fromRGB(120, 170, 255),
	Players = Color3.fromRGB(120, 170, 255),
}
local DEFAULT_CLASS_COLOR = Color3.fromRGB(140, 148, 168)

local function classColor(className)
	return CLASS_COLORS[className] or DEFAULT_CLASS_COLOR
end

local SETTINGS = {
	classColors = true,
}

-- Форвард-декларации: заполняются позже, но уже используются в колбэках
-- элементов настроек, которые строятся раньше по тексту файла.
local rebuildTree
local selectTab
local revealAndSelect

local function corner(parent, radius)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius or 10)
	instance.Parent = parent
	return instance
end

local function padding(parent, amount)
	local instance = Instance.new("UIPadding")
	instance.PaddingTop = UDim.new(0, amount)
	instance.PaddingBottom = UDim.new(0, amount)
	instance.PaddingLeft = UDim.new(0, amount)
	instance.PaddingRight = UDim.new(0, amount)
	instance.Parent = parent
	return instance
end

local function makeDraggable(handle, target)
	local dragging = false
	local dragStart = Vector2.zero
	local startPosition = target.Position

	handle:SetAttribute("Dragged", false)

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPosition = target.Position
			handle:SetAttribute("Dragged", false)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local delta = input.Position - dragStart

		if not handle:GetAttribute("Dragged") then
			if math.abs(delta.X) + math.abs(delta.Y) < 8 then
				return
			end
			handle:SetAttribute("Dragged", true)
		end

		target.Position = UDim2.new(
			startPosition.X.Scale, startPosition.X.Offset + delta.X,
			startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
		)
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

local function makeSlider(parent, order, label, min, max, default, decimals, onChange)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = THEME.Panel
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, 68)
	card.LayoutOrder = order
	card.Parent = parent
	corner(card, 10)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = label
	titleLabel.Font = Enum.Font.GothamMedium
	titleLabel.TextSize = 14
	titleLabel.TextColor3 = THEME.Text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Position = UDim2.fromOffset(14, 8)
	titleLabel.Size = UDim2.new(1, -90, 0, 20)
	titleLabel.Parent = card

	local valueLabel = Instance.new("TextLabel")
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextSize = 14
	valueLabel.TextColor3 = THEME.Accent
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Position = UDim2.new(1, -80, 0, 8)
	valueLabel.Size = UDim2.fromOffset(66, 20)
	valueLabel.Parent = card

	local track = Instance.new("Frame")
	track.BackgroundColor3 = THEME.PanelLight
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(14, 40)
	track.Size = UDim2.new(1, -28, 0, 8)
	track.Parent = card
	corner(track, 4)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = THEME.Accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	corner(fill, 4)

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3 = THEME.Text
	knob.BorderSizePixel = 0
	knob.Size = UDim2.fromOffset(20, 20)
	knob.Position = UDim2.fromScale(0, 0.5)
	knob.Parent = track
	corner(knob, 10)

	local hitZone = Instance.new("TextButton")
	hitZone.BackgroundTransparency = 1
	hitZone.AutoButtonColor = false
	hitZone.Text = ""
	hitZone.Position = UDim2.fromOffset(0, -14)
	hitZone.Size = UDim2.new(1, 0, 0, 36)
	hitZone.Parent = track

	local value = default

	local function apply(raw)
		local v = math.clamp(raw, min, max)
		if decimals and decimals > 0 then
			local mult = 10 ^ decimals
			v = math.floor(v * mult + 0.5) / mult
		else
			v = math.floor(v + 0.5)
		end
		value = v
		local alpha = 0
		if max - min ~= 0 then
			alpha = (v - min) / (max - min)
		end
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		valueLabel.Text = tostring(v)
		onChange(v)
	end

	local dragging = false

	local function fromX(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		apply(min + (max - min) * alpha)
	end

	hitZone.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	apply(default)

	return {
		set = apply,
		get = function() return value end,
	}
end

local function makeToggle(parent, order, label, default, onChange)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = THEME.Panel
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, 48)
	card.LayoutOrder = order
	card.Parent = parent
	corner(card, 10)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = label
	titleLabel.Font = Enum.Font.GothamMedium
	titleLabel.TextSize = 14
	titleLabel.TextColor3 = THEME.Text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Position = UDim2.fromOffset(14, 0)
	titleLabel.Size = UDim2.new(1, -80, 1, 0)
	titleLabel.Parent = card

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, -14, 0.5, 0)
	track.Size = UDim2.fromOffset(46, 26)
	track.BackgroundColor3 = THEME.PanelLight
	track.BorderSizePixel = 0
	track.Parent = card
	corner(track, 13)

	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = THEME.Text
	knob.BorderSizePixel = 0
	knob.Size = UDim2.fromOffset(20, 20)
	knob.Position = UDim2.fromOffset(3, 3)
	knob.Parent = track
	corner(knob, 10)

	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.AutoButtonColor = false
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.Parent = card

	local state = default and true or false

	local function render()
		track.BackgroundColor3 = state and THEME.Accent or THEME.PanelLight
		knob.Position = state and UDim2.new(1, -23, 0, 3) or UDim2.fromOffset(3, 3)
	end
	render()

	hit.Activated:Connect(function()
		state = not state
		render()
		onChange(state)
	end)

	return {
		set = function(v)
			state = v and true or false
			render()
		end,
		get = function() return state end,
	}
end

local gui = Instance.new("ScreenGui")
gui.Name = "DexExplorer"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 500
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local inset = GuiService:GetGuiInset()

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "Toggle"
toggleButton.Size = UDim2.fromOffset(56, 56)
toggleButton.Position = UDim2.new(1, -72, 0, inset.Y + 16)
toggleButton.BackgroundColor3 = THEME.Panel
toggleButton.AutoButtonColor = false
toggleButton.Text = "Dex"
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 14
toggleButton.TextColor3 = THEME.Text
toggleButton.ZIndex = 20
toggleButton.Parent = gui
corner(toggleButton, 28)
makeDraggable(toggleButton, toggleButton)

local windowHolder = Instance.new("Frame")
windowHolder.Name = "Window"
windowHolder.AnchorPoint = Vector2.new(0.5, 0.5)
windowHolder.Position = UDim2.fromScale(0.5, 0.48)
windowHolder.Size = UDim2.fromScale(0.92, 0.84)
windowHolder.BackgroundColor3 = THEME.Background
windowHolder.BorderSizePixel = 0
windowHolder.Visible = false
windowHolder.ClipsDescendants = true
windowHolder.ZIndex = 10
windowHolder.Parent = gui
corner(windowHolder, 16)

local windowScale = Instance.new("UIScale")
windowScale.Scale = 1
windowScale.Parent = windowHolder

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
header.BackgroundColor3 = THEME.Panel
header.BorderSizePixel = 0
header.ZIndex = 11
header.Parent = windowHolder
corner(header, 16)

local headerMask = Instance.new("Frame")
headerMask.Size = UDim2.new(1, 0, 0, 16)
headerMask.Position = UDim2.new(0, 0, 1, -16)
headerMask.BackgroundColor3 = THEME.Panel
headerMask.BorderSizePixel = 0
headerMask.ZIndex = 11
headerMask.Parent = header

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Text = "Dex Explorer"
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = THEME.Text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Size = UDim2.new(1, -56, 1, 0)
title.Position = UDim2.fromOffset(16, 0)
title.ZIndex = 12
title.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Text = "X"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 16
closeButton.TextColor3 = THEME.Text
closeButton.BackgroundTransparency = 1
closeButton.AutoButtonColor = false
closeButton.Size = UDim2.fromOffset(44, 44)
closeButton.Position = UDim2.new(1, -46, 0.5, -22)
closeButton.ZIndex = 12
closeButton.Parent = header

makeDraggable(header, windowHolder)

local resizeHandle = Instance.new("TextButton")
resizeHandle.Name = "Resize"
resizeHandle.AnchorPoint = Vector2.new(1, 1)
resizeHandle.Position = UDim2.new(1, -6, 1, -6)
resizeHandle.Size = UDim2.fromOffset(38, 38)
resizeHandle.BackgroundColor3 = THEME.PanelLight
resizeHandle.AutoButtonColor = false
resizeHandle.Text = ""
resizeHandle.ZIndex = 15
resizeHandle.Parent = windowHolder
corner(resizeHandle, 8)

local function diagLine(offsetX, offsetY, length)
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BackgroundColor3 = THEME.TextDim
	line.BorderSizePixel = 0
	line.Size = UDim2.fromOffset(length, 2)
	line.Position = UDim2.fromOffset(offsetX, offsetY)
	line.Rotation = -45
	line.ZIndex = 16
	line.Parent = resizeHandle
	corner(line, 1)
end
diagLine(15, 23, 10)
diagLine(23, 15, 10)
diagLine(23, 31, 18)
diagLine(31, 23, 18)

local resizing = false
local resizeStartScale = 1
local resizeStartDistance = 1

local function toVector2(position)
	return Vector2.new(position.X, position.Y)
end

local function windowCenter()
	return toVector2(windowHolder.AbsolutePosition) + windowHolder.AbsoluteSize / 2
end

resizeHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resizing = true
		resizeStartScale = windowScale.Scale
		resizeStartDistance = math.max((toVector2(input.Position) - windowCenter()).Magnitude, 1)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not resizing then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	local distance = (toVector2(input.Position) - windowCenter()).Magnitude
	windowScale.Scale = math.clamp(resizeStartScale * (distance / resizeStartDistance), MIN_SCALE, MAX_SCALE)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resizing = false
	end
end)

local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Position = UDim2.fromOffset(0, HEADER_HEIGHT)
tabBar.Size = UDim2.new(1, 0, 0, TABBAR_HEIGHT)
tabBar.BackgroundColor3 = THEME.Panel
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 11
tabBar.Parent = windowHolder

local tabBarLayout = Instance.new("UIListLayout")
tabBarLayout.FillDirection = Enum.FillDirection.Horizontal
tabBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabBarLayout.Parent = tabBar

local function makeTabButton(text, order)
	local button = Instance.new("TextButton")
	button.Name = "Tab_" .. text
	button.Size = UDim2.new(1 / 3, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 13
	button.TextColor3 = THEME.TextDim
	button.Text = text
	button.LayoutOrder = order
	button.ZIndex = 12
	button.Parent = tabBar

	local underline = Instance.new("Frame")
	underline.AnchorPoint = Vector2.new(0.5, 1)
	underline.Position = UDim2.new(0.5, 0, 1, 0)
	underline.Size = UDim2.new(0, 0, 0, 3)
	underline.BackgroundColor3 = THEME.Accent
	underline.BorderSizePixel = 0
	underline.ZIndex = 13
	underline.Parent = button
	corner(underline, 2)

	return button, underline
end

local tabTreeBtn, tabTreeLine = makeTabButton("Дерево", 1)
local tabPickBtn, tabPickLine = makeTabButton("Выбрать", 2)
local tabSettingsBtn, tabSettingsLine = makeTabButton("Настройки UI", 3)

local CONTENT_TOP = HEADER_HEIGHT + TABBAR_HEIGHT

local treePage = Instance.new("Frame")
treePage.Name = "TreePage"
treePage.Position = UDim2.fromOffset(0, CONTENT_TOP)
treePage.Size = UDim2.new(1, 0, 1, -CONTENT_TOP)
treePage.BackgroundTransparency = 1
treePage.Visible = true
treePage.ZIndex = 11
treePage.Parent = windowHolder

local searchBox = Instance.new("TextBox")
searchBox.Name = "Search"
searchBox.Position = UDim2.fromOffset(8, 6)
searchBox.Size = UDim2.new(1, -60, 0, 34)
searchBox.BackgroundColor3 = THEME.PanelLight
searchBox.BorderSizePixel = 0
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 14
searchBox.TextColor3 = THEME.Text
searchBox.PlaceholderText = "Поиск по имени..."
searchBox.PlaceholderColor3 = THEME.TextDim
searchBox.Text = ""
searchBox.ClearTextOnFocus = false
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ZIndex = 12
searchBox.Parent = treePage
corner(searchBox, 8)
padding(searchBox, 8)

local refreshButton = Instance.new("TextButton")
refreshButton.Text = "Обновить"
refreshButton.Font = Enum.Font.GothamBold
refreshButton.TextSize = 11
refreshButton.TextColor3 = THEME.Text
refreshButton.BackgroundColor3 = THEME.PanelLight
refreshButton.BorderSizePixel = 0
refreshButton.AutoButtonColor = false
refreshButton.Position = UDim2.new(1, -48, 0, 6)
refreshButton.Size = UDim2.fromOffset(40, 34)
refreshButton.TextWrapped = true
refreshButton.ZIndex = 12
refreshButton.Parent = treePage
corner(refreshButton, 8)

local expandAllButton = Instance.new("TextButton")
expandAllButton.Text = "Развернуть всё"
expandAllButton.Font = Enum.Font.Gotham
expandAllButton.TextSize = 12
expandAllButton.TextColor3 = THEME.TextDim
expandAllButton.BackgroundColor3 = THEME.PanelLight
expandAllButton.BorderSizePixel = 0
expandAllButton.AutoButtonColor = false
expandAllButton.Position = UDim2.fromOffset(8, 46)
expandAllButton.Size = UDim2.new(0.5, -12, 0, 30)
expandAllButton.ZIndex = 12
expandAllButton.Parent = treePage
corner(expandAllButton, 8)

local collapseAllButton = Instance.new("TextButton")
collapseAllButton.Text = "Свернуть всё"
collapseAllButton.Font = Enum.Font.Gotham
collapseAllButton.TextSize = 12
collapseAllButton.TextColor3 = THEME.TextDim
collapseAllButton.BackgroundColor3 = THEME.PanelLight
collapseAllButton.BorderSizePixel = 0
collapseAllButton.AutoButtonColor = false
collapseAllButton.Position = UDim2.new(0.5, 4, 0, 46)
collapseAllButton.Size = UDim2.new(0.5, -12, 0, 30)
collapseAllButton.ZIndex = 12
collapseAllButton.Parent = treePage
corner(collapseAllButton, 8)

local statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextColor3 = THEME.TextDim
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Все папки DataModel"
statusLabel.Position = UDim2.fromOffset(10, 78)
statusLabel.Size = UDim2.new(1, -20, 0, 14)
statusLabel.ZIndex = 12
statusLabel.Parent = treePage

local treeScroll = Instance.new("ScrollingFrame")
treeScroll.Name = "Tree"
treeScroll.Position = UDim2.fromOffset(0, TOOLBAR_HEIGHT)
treeScroll.Size = UDim2.new(1, 0, 0.6, -TOOLBAR_HEIGHT)
treeScroll.BackgroundTransparency = 1
treeScroll.BorderSizePixel = 0
treeScroll.ScrollBarThickness = 4
treeScroll.ScrollBarImageColor3 = THEME.Accent
treeScroll.CanvasSize = UDim2.new()
treeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
treeScroll.ZIndex = 11
treeScroll.Parent = treePage
padding(treeScroll, 8)

local treeLayout = Instance.new("UIListLayout")
treeLayout.SortOrder = Enum.SortOrder.LayoutOrder
treeLayout.Parent = treeScroll

local divider = Instance.new("Frame")
divider.Position = UDim2.new(0, 0, 0.6, 0)
divider.Size = UDim2.new(1, 0, 0, DIVIDER_HEIGHT)
divider.BackgroundColor3 = THEME.PanelLight
divider.BorderSizePixel = 0
divider.ZIndex = 11
divider.Parent = treePage

local infoPanel = Instance.new("ScrollingFrame")
infoPanel.Name = "Info"
infoPanel.Position = UDim2.new(0, 0, 0.6, DIVIDER_HEIGHT)
infoPanel.Size = UDim2.new(1, 0, 0.4, -DIVIDER_HEIGHT)
infoPanel.BackgroundColor3 = THEME.Panel
infoPanel.BorderSizePixel = 0
infoPanel.ScrollBarThickness = 4
infoPanel.CanvasSize = UDim2.new()
infoPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
infoPanel.ZIndex = 11
infoPanel.Parent = treePage
padding(infoPanel, 12)

local infoLabel = Instance.new("TextLabel")
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Выбери объект в дереве или на вкладке Выбрать"
infoLabel.Font = Enum.Font.Code
infoLabel.TextSize = 14
infoLabel.TextColor3 = THEME.TextDim
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.TextWrapped = true
infoLabel.Size = UDim2.new(1, 0, 0, 0)
infoLabel.AutomaticSize = Enum.AutomaticSize.Y
infoLabel.ZIndex = 12
infoLabel.Parent = infoPanel

local highlight = Instance.new("Highlight")
highlight.Name = "DexExplorerHighlight"
highlight.FillColor = THEME.Highlight
highlight.OutlineColor = THEME.Highlight
highlight.FillTransparency = 0.65
highlight.OutlineTransparency = 0
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.Enabled = false
highlight.Parent = workspace

local pickPage = Instance.new("Frame")
pickPage.Name = "PickPage"
pickPage.Position = UDim2.fromOffset(0, CONTENT_TOP)
pickPage.Size = UDim2.new(1, 0, 1, -CONTENT_TOP)
pickPage.BackgroundTransparency = 1
pickPage.Visible = false
pickPage.ZIndex = 11
pickPage.Parent = windowHolder
padding(pickPage, 14)

local pickLayout = Instance.new("UIListLayout")
pickLayout.SortOrder = Enum.SortOrder.LayoutOrder
pickLayout.Padding = UDim.new(0, 12)
pickLayout.Parent = pickPage

local pickDesc = Instance.new("TextLabel")
pickDesc.BackgroundTransparency = 1
pickDesc.Font = Enum.Font.Gotham
pickDesc.TextSize = 14
pickDesc.TextColor3 = THEME.TextDim
pickDesc.TextXAlignment = Enum.TextXAlignment.Left
pickDesc.TextYAlignment = Enum.TextYAlignment.Top
pickDesc.TextWrapped = true
pickDesc.Text = "Нажми кнопку ниже - окно свернётся. Тапни по любому объекту в игровом мире (камеру можно спокойно вращать и двигаться - сработает только короткий тап без движения), и панель снова откроется на вкладке Дерево, автоматически развернув все папки до этого объекта."
pickDesc.Size = UDim2.new(1, 0, 0, 96)
pickDesc.LayoutOrder = 1
pickDesc.ZIndex = 12
pickDesc.Parent = pickPage

local pickButton = Instance.new("TextButton")
pickButton.Text = "Выбрать объект в игре"
pickButton.Font = Enum.Font.GothamBold
pickButton.TextSize = 15
pickButton.TextColor3 = THEME.Text
pickButton.BackgroundColor3 = THEME.Accent
pickButton.BorderSizePixel = 0
pickButton.AutoButtonColor = false
pickButton.Size = UDim2.new(1, 0, 0, 52)
pickButton.LayoutOrder = 2
pickButton.ZIndex = 12
pickButton.Parent = pickPage
corner(pickButton, 12)

local pickStatusLabel = Instance.new("TextLabel")
pickStatusLabel.BackgroundTransparency = 1
pickStatusLabel.Font = Enum.Font.Gotham
pickStatusLabel.TextSize = 13
pickStatusLabel.TextColor3 = THEME.TextDim
pickStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
pickStatusLabel.TextYAlignment = Enum.TextYAlignment.Top
pickStatusLabel.TextWrapped = true
pickStatusLabel.Text = "Пока ничего не выбрано."
pickStatusLabel.Size = UDim2.new(1, 0, 0, 60)
pickStatusLabel.LayoutOrder = 3
pickStatusLabel.ZIndex = 12
pickStatusLabel.Parent = pickPage

local pickHint = Instance.new("Frame")
pickHint.Name = "PickHint"
pickHint.AnchorPoint = Vector2.new(0.5, 0)
pickHint.Position = UDim2.new(0.5, 0, 0, inset.Y + 16)
pickHint.Size = UDim2.fromOffset(280, 56)
pickHint.BackgroundColor3 = THEME.Panel
pickHint.BorderSizePixel = 0
pickHint.Visible = false
pickHint.ZIndex = 25
pickHint.Parent = gui
corner(pickHint, 14)

local pickHintLabel = Instance.new("TextLabel")
pickHintLabel.BackgroundTransparency = 1
pickHintLabel.Font = Enum.Font.GothamMedium
pickHintLabel.TextSize = 13
pickHintLabel.TextColor3 = THEME.Text
pickHintLabel.TextWrapped = true
pickHintLabel.Text = "Тапни по объекту в игре"
pickHintLabel.Position = UDim2.fromOffset(14, 6)
pickHintLabel.Size = UDim2.new(1, -90, 1, -12)
pickHintLabel.TextXAlignment = Enum.TextXAlignment.Left
pickHintLabel.ZIndex = 26
pickHintLabel.Parent = pickHint

local pickCancelButton = Instance.new("TextButton")
pickCancelButton.Text = "Отмена"
pickCancelButton.Font = Enum.Font.GothamBold
pickCancelButton.TextSize = 12
pickCancelButton.TextColor3 = THEME.Text
pickCancelButton.BackgroundColor3 = THEME.PanelLight
pickCancelButton.BorderSizePixel = 0
pickCancelButton.AutoButtonColor = false
pickCancelButton.AnchorPoint = Vector2.new(1, 0.5)
pickCancelButton.Position = UDim2.new(1, -10, 0.5, 0)
pickCancelButton.Size = UDim2.fromOffset(66, 36)
pickCancelButton.ZIndex = 26
pickCancelButton.Parent = pickHint
corner(pickCancelButton, 8)

local settingsPage = Instance.new("Frame")
settingsPage.Name = "SettingsPage"
settingsPage.Position = UDim2.fromOffset(0, CONTENT_TOP)
settingsPage.Size = UDim2.new(1, 0, 1, -CONTENT_TOP)
settingsPage.BackgroundTransparency = 1
settingsPage.Visible = false
settingsPage.ZIndex = 11
settingsPage.Parent = windowHolder
padding(settingsPage, 14)

local settingsLayout = Instance.new("UIListLayout")
settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
settingsLayout.Padding = UDim.new(0, 10)
settingsLayout.Parent = settingsPage

local scaleSlider = makeSlider(settingsPage, 1, "Масштаб интерфейса", 70, 160, 100, 0, function(v)
	windowScale.Scale = v / 100
end)

local compactToggle
compactToggle = makeToggle(settingsPage, 2, "Компактные строки дерева", false, function(v)
	ROW_HEIGHT = v and 32 or 40
	rebuildTree()
end)

local classColorToggle
classColorToggle = makeToggle(settingsPage, 3, "Цвета классов в дереве", true, function(v)
	SETTINGS.classColors = v
	rebuildTree()
end)

local resetButton = Instance.new("TextButton")
resetButton.Text = "Сбросить окно (позиция, размер)"
resetButton.Font = Enum.Font.GothamMedium
resetButton.TextSize = 13
resetButton.TextColor3 = THEME.Text
resetButton.BackgroundColor3 = THEME.Panel
resetButton.BorderSizePixel = 0
resetButton.AutoButtonColor = false
resetButton.Size = UDim2.new(1, 0, 0, 48)
resetButton.LayoutOrder = 4
resetButton.ZIndex = 12
resetButton.Parent = settingsPage
corner(resetButton, 10)

local settingsHint = Instance.new("TextLabel")
settingsHint.BackgroundTransparency = 1
settingsHint.Font = Enum.Font.Gotham
settingsHint.TextSize = 12
settingsHint.TextColor3 = THEME.TextDim
settingsHint.TextWrapped = true
settingsHint.TextXAlignment = Enum.TextXAlignment.Left
settingsHint.TextYAlignment = Enum.TextYAlignment.Top
settingsHint.Text = "Масштаб также можно менять щипком за значок в правом нижнем углу окна."
settingsHint.Size = UDim2.new(1, 0, 0, 40)
settingsHint.LayoutOrder = 5
settingsHint.ZIndex = 12
settingsHint.Parent = settingsPage

local function formatBool(value)
	return value and "да" or "нет"
end

local function describe(instance)
	local lines = {
		"Имя: " .. instance.Name,
		"Класс: " .. instance.ClassName,
		"Путь: " .. instance:GetFullName(),
		"Родитель: " .. (instance.Parent and instance.Parent.Name or "нет"),
	}

	local ok, childCount = pcall(function() return #instance:GetChildren() end)
	table.insert(lines, "Детей: " .. (ok and tostring(childCount) or "?"))

	if instance:IsA("BasePart") then
		table.insert(lines, "")
		table.insert(lines, "CanCollide: " .. formatBool(instance.CanCollide))
		table.insert(lines, "CanTouch: " .. formatBool(instance.CanTouch))
		table.insert(lines, "CanQuery: " .. formatBool(instance.CanQuery))
		table.insert(lines, "CollisionGroup: " .. instance.CollisionGroup)
		table.insert(lines, "Size: " .. tostring(instance.Size))
		table.insert(lines, "Material: " .. tostring(instance.Material))
		table.insert(lines, "Anchored: " .. formatBool(instance.Anchored))

		local fidelityOk, fidelity = pcall(function()
			return instance.CollisionFidelity
		end)
		if fidelityOk then
			table.insert(lines, "CollisionFidelity: " .. tostring(fidelity))
		end
	elseif instance:IsA("Model") then
		table.insert(lines, "")
		local primary = instance.PrimaryPart
		table.insert(lines, "PrimaryPart: " .. (primary and primary.Name or "не задан"))
		if primary then
			table.insert(lines, "CanCollide (PrimaryPart): " .. formatBool(primary.CanCollide))
		end
	else
		table.insert(lines, "")
		table.insert(lines, "У объекта нет физической коллизии")
	end

	return table.concat(lines, "\n")
end

local selectedRow = nil

local function resetSelection()
	if selectedRow then
		selectedRow.BackgroundTransparency = 1
		selectedRow = nil
	end
	highlight.Enabled = false
	infoLabel.Text = "Выбери объект в дереве или на вкладке Выбрать"
	infoLabel.TextColor3 = THEME.TextDim
end

local function selectInstance(instance, row)
	if selectedRow then
		selectedRow.BackgroundTransparency = 1
	end

	selectedRow = row
	row.BackgroundColor3 = THEME.Accent
	row.BackgroundTransparency = 0.85

	local ok = pcall(function()
		highlight.Adornee = instance
	end)
	highlight.Enabled = ok
	infoLabel.Text = describe(instance)
	infoLabel.TextColor3 = THEME.Text
end

local nodeByInstance = setmetatable({}, { __mode = "k" })
local treeRootFrames = {}

local function createNode(instance, parent, order)
	local node = Instance.new("Frame")
	node.Name = instance.Name
	node.BackgroundTransparency = 1
	node.Size = UDim2.new(1, 0, 0, 0)
	node.AutomaticSize = Enum.AutomaticSize.Y
	node.LayoutOrder = order
	node.Parent = parent

	local nodeLayout = Instance.new("UIListLayout")
	nodeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	nodeLayout.Parent = node

	local row = Instance.new("TextButton")
	row.Name = "Row"
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundTransparency = 1
	row.AutoButtonColor = false
	row.Text = ""
	row.LayoutOrder = 1
	row.ZIndex = 12
	row.Parent = node
	corner(row, 6)

	local okChildren, rawChildren = pcall(function() return instance:GetChildren() end)
	local hasChildren = okChildren and #rawChildren > 0

	local arrow = Instance.new("TextButton")
	arrow.Size = UDim2.fromOffset(ROW_HEIGHT, ROW_HEIGHT)
	arrow.BackgroundTransparency = 1
	arrow.AutoButtonColor = false
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 16
	arrow.TextColor3 = THEME.TextDim
	arrow.Text = hasChildren and "+" or ""
	arrow.ZIndex = 13
	arrow.Parent = row

	local classDot = Instance.new("Frame")
	classDot.AnchorPoint = Vector2.new(0, 0.5)
	classDot.Position = UDim2.new(0, ROW_HEIGHT + 2, 0.5, 0)
	classDot.Size = UDim2.fromOffset(8, 8)
	classDot.BackgroundColor3 = classColor(instance.ClassName)
	classDot.BorderSizePixel = 0
	classDot.Visible = SETTINGS.classColors
	classDot.ZIndex = 13
	classDot.Parent = row
	corner(classDot, 4)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, -(ROW_HEIGHT + 18), 1, 0)
	nameLabel.Position = UDim2.fromOffset(ROW_HEIGHT + 18, 0)
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 14
	nameLabel.TextColor3 = THEME.Text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.RichText = true
	nameLabel.Text = string.format('%s  <font color="#8b93a8">%s</font>', instance.Name, instance.ClassName)
	nameLabel.ZIndex = 13
	nameLabel.Parent = row

	local childrenFrame = Instance.new("Frame")
	childrenFrame.Name = "Children"
	childrenFrame.BackgroundTransparency = 1
	childrenFrame.Size = UDim2.new(1, 0, 0, 0)
	childrenFrame.AutomaticSize = Enum.AutomaticSize.Y
	childrenFrame.Visible = false
	childrenFrame.LayoutOrder = 2
	childrenFrame.Parent = node

	local childPadding = Instance.new("UIPadding")
	childPadding.PaddingLeft = UDim.new(0, INDENT)
	childPadding.Parent = childrenFrame

	local childLayout = Instance.new("UIListLayout")
	childLayout.SortOrder = Enum.SortOrder.LayoutOrder
	childLayout.Parent = childrenFrame

	local expanded = false
	local built = false

	local function build()
		if built then
			return
		end
		built = true
		local ok, children = pcall(function() return instance:GetChildren() end)
		if not ok then
			children = {}
		end
		table.sort(children, function(a, b)
			return a.Name:lower() < b.Name:lower()
		end)
		for index, child in ipairs(children) do
			createNode(child, childrenFrame, index)
		end
	end

	local function setExpanded(value)
		if not hasChildren then
			return
		end
		if value and not built then
			build()
		end
		expanded = value and true or false
		childrenFrame.Visible = expanded
		arrow.Text = expanded and "-" or "+"
	end

	local function toggleExpand()
		setExpanded(not expanded)
	end

	arrow.Activated:Connect(toggleExpand)
	row.Activated:Connect(function()
		selectInstance(instance, row)
	end)

	local entry = {
		row = row,
		node = node,
		setExpanded = setExpanded,
		isExpanded = function() return expanded end,
	}
	nodeByInstance[instance] = entry

	return entry
end

local treeRootInstances = {}

local function clearRoots()
	for _, frame in ipairs(treeRootFrames) do
		frame:Destroy()
	end
	treeRootFrames = {}
	treeRootInstances = {}
end

local function buildRoots()
	clearRoots()
	nodeByInstance = setmetatable({}, { __mode = "k" })
	local ok, children = pcall(function() return game:GetChildren() end)
	if not ok then
		children = {}
	end
	table.sort(children, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)
	for index, child in ipairs(children) do
		local entry = createNode(child, treeScroll, index)
		table.insert(treeRootFrames, entry.node)
		table.insert(treeRootInstances, child)
	end
end

local function expandAllFrom(rootInstances, budget)
	local stack = {}
	for i = #rootInstances, 1, -1 do
		table.insert(stack, rootInstances[i])
	end

	local count = 0
	while #stack > 0 and budget > 0 do
		local instance = table.remove(stack)
		local entry = nodeByInstance[instance]
		if entry then
			entry.setExpanded(true)
			budget = budget - 1
			count = count + 1
			if count % 150 == 0 then
				task.wait()
			end
			local ok, children = pcall(function() return instance:GetChildren() end)
			if ok then
				for i = #children, 1, -1 do
					table.insert(stack, children[i])
				end
			end
		end
	end

	return count
end

rebuildTree = function()
	resetSelection()
	buildRoots()
end

revealAndSelect = function(instance)
	local chain = {}
	local cur = instance
	while cur and cur ~= game do
		table.insert(chain, 1, cur)
		cur = cur.Parent
	end
	if #chain == 0 then
		return false
	end

	for i = 1, #chain - 1 do
		local entry = nodeByInstance[chain[i]]
		if not entry then
			return false
		end
		entry.setExpanded(true)
	end

	task.wait()

	local finalEntry = nodeByInstance[instance]
	if not finalEntry then
		return false
	end

	selectInstance(instance, finalEntry.row)

	local rowPos = finalEntry.row.AbsolutePosition.Y
	local scrollPos = treeScroll.AbsolutePosition.Y
	local currentCanvasY = treeScroll.CanvasPosition.Y
	local targetY = (rowPos - scrollPos) + currentCanvasY - (treeScroll.AbsoluteSize.Y / 2)
	local maxY = math.max(treeScroll.CanvasSize.Y.Offset - treeScroll.AbsoluteSize.Y, 0)
	treeScroll.CanvasPosition = Vector2.new(0, math.clamp(targetY, 0, maxY))

	return true
end

buildRoots()

local searchRowFrames = {}
local searchActive = false
local searchGeneration = 0

local function setSearchMode(active)
	searchActive = active
	for _, frame in ipairs(treeRootFrames) do
		frame.Visible = not active
	end
	for _, frame in ipairs(searchRowFrames) do
		frame.Visible = active
	end
end

local function clearSearchResults()
	for _, frame in ipairs(searchRowFrames) do
		frame:Destroy()
	end
	searchRowFrames = {}
end

local function createSearchRow(instance, order)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT + 16)
	row.BackgroundTransparency = 1
	row.AutoButtonColor = false
	row.Text = ""
	row.LayoutOrder = order
	row.ZIndex = 12
	row.Parent = treeScroll
	corner(row, 6)

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.fromOffset(12, 18)
	dot.Size = UDim2.fromOffset(8, 8)
	dot.BackgroundColor3 = classColor(instance.ClassName)
	dot.BorderSizePixel = 0
	dot.ZIndex = 13
	dot.Parent = row
	corner(dot, 4)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(28, 4)
	nameLabel.Size = UDim2.new(1, -36, 0, 20)
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 14
	nameLabel.TextColor3 = THEME.Text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.RichText = true
	nameLabel.Text = string.format('%s  <font color="#8b93a8">%s</font>', instance.Name, instance.ClassName)
	nameLabel.ZIndex = 13
	nameLabel.Parent = row

	local pathLabel = Instance.new("TextLabel")
	pathLabel.BackgroundTransparency = 1
	pathLabel.Position = UDim2.fromOffset(28, 24)
	pathLabel.Size = UDim2.new(1, -36, 0, 16)
	pathLabel.Font = Enum.Font.Gotham
	pathLabel.TextSize = 11
	pathLabel.TextColor3 = THEME.TextDim
	pathLabel.TextXAlignment = Enum.TextXAlignment.Left
	pathLabel.TextTruncate = Enum.TextTruncate.AtEnd
	local fullNameOk, fullName = pcall(function() return instance:GetFullName() end)
	pathLabel.Text = fullNameOk and fullName or instance.Name
	pathLabel.ZIndex = 13
	pathLabel.Parent = row

	row.Activated:Connect(function()
		searchGeneration = searchGeneration + 1
		clearSearchResults()
		setSearchMode(false)
		searchBox.Text = ""
		task.wait()
		local ok = revealAndSelect(instance)
		if not ok then
			statusLabel.Text = "Не удалось показать объект в дереве"
		end
	end)

	return row
end

local function runSearch(query)
	searchGeneration = searchGeneration + 1
	local myGeneration = searchGeneration

	task.wait(0.15)
	if myGeneration ~= searchGeneration then
		return
	end

	local needle = query:lower()

	if #needle < 2 then
		clearSearchResults()
		setSearchMode(false)
		statusLabel.Text = "Все папки DataModel"
		return
	end

	setSearchMode(true)
	statusLabel.Text = "Ищу..."

	local matches = {}
	local scanned = 0
	local ok = pcall(function()
		for _, inst in ipairs(game:GetDescendants()) do
			scanned = scanned + 1
			if scanned % 1500 == 0 then
				task.wait()
				if myGeneration ~= searchGeneration then
					return
				end
			end
			if string.find(inst.Name:lower(), needle, 1, true) then
				table.insert(matches, inst)
				if #matches >= 200 then
					return
				end
			end
		end
	end)

	if myGeneration ~= searchGeneration then
		return
	end
	if not ok then
		statusLabel.Text = "Ошибка поиска"
		return
	end

	clearSearchResults()

	if #matches == 0 then
		statusLabel.Text = "Ничего не найдено"
		return
	end

	if #matches >= 200 then
		statusLabel.Text = "Найдено 200+ (показаны первые 200)"
	else
		statusLabel.Text = "Найдено: " .. tostring(#matches)
	end

	for index, inst in ipairs(matches) do
		local row = createSearchRow(inst, index)
		table.insert(searchRowFrames, row)
	end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	runSearch(searchBox.Text)
end)

local picking = false
local pickStart = nil
local lastPicked = nil

local function startPicking()
	if picking then
		return
	end
	picking = true
	windowHolder.Visible = false
	toggleButton.Visible = false
	pickHint.Visible = true
end

local function stopPicking()
	picking = false
	pickHint.Visible = false
	toggleButton.Visible = true
end

local function cancelPicking()
	stopPicking()
	windowHolder.Visible = true
end

local function doPick(position)
	local camera = workspace.CurrentCamera
	stopPicking()
	windowHolder.Visible = true

	if not camera then
		pickStatusLabel.Text = "Камера недоступна, попробуй ещё раз"
		return
	end

	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}

	local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)

	if result and result.Instance then
		lastPicked = result.Instance
		local fullNameOk, fullName = pcall(function() return result.Instance:GetFullName() end)
		local label = fullNameOk and fullName or result.Instance.Name
		pickStatusLabel.Text = "Найдено: " .. label

		selectTab("tree")
		local ok = revealAndSelect(result.Instance)
		if not ok then
			selectTab("pick")
			pickStatusLabel.Text = "Нашёл объект, но не смог показать его в дереве: " .. label
		end
	else
		pickStatusLabel.Text = "Под тапом ничего нет - попробуй ещё раз"
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not picking or processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pickStart = input.Position
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if not picking or not pickStart then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local began = pickStart
	pickStart = nil
	if processed then
		return
	end
	local delta = (input.Position - began).Magnitude
	if delta > 10 then
		return
	end
	doPick(began)
end)

local pages = { tree = treePage, pick = pickPage, settings = settingsPage }
local tabButtons = { tree = tabTreeBtn, pick = tabPickBtn, settings = tabSettingsBtn }
local tabLines = { tree = tabTreeLine, pick = tabPickLine, settings = tabSettingsLine }

selectTab = function(name)
	for key, page in pairs(pages) do
		page.Visible = (key == name)
	end
	for key, button in pairs(tabButtons) do
		local active = key == name
		button.TextColor3 = active and THEME.Text or THEME.TextDim
		tabLines[key].Size = active and UDim2.new(0, 28, 0, 3) or UDim2.new(0, 0, 0, 3)
	end
end

selectTab("tree")

tabTreeBtn.Activated:Connect(function() selectTab("tree") end)
tabPickBtn.Activated:Connect(function() selectTab("pick") end)
tabSettingsBtn.Activated:Connect(function() selectTab("settings") end)

refreshButton.Activated:Connect(function()
	searchBox.Text = ""
	rebuildTree()
end)

expandAllButton.Activated:Connect(function()
	if searchActive then
		return
	end
	statusLabel.Text = "Разворачиваю..."
	task.spawn(function()
		local count = expandAllFrom(treeRootInstances, 3000)
		if not searchActive then
			statusLabel.Text = "Развёрнуто узлов: " .. tostring(count)
		end
	end)
end)

collapseAllButton.Activated:Connect(function()
	if searchActive then
		return
	end
	for _, instance in ipairs(treeRootInstances) do
		local entry = nodeByInstance[instance]
		if entry then
			entry.setExpanded(false)
		end
	end
	statusLabel.Text = "Все папки DataModel"
end)

closeButton.Activated:Connect(function()
	windowHolder.Visible = false
end)

pickButton.Activated:Connect(startPicking)
pickCancelButton.Activated:Connect(cancelPicking)

resetButton.Activated:Connect(function()
	windowHolder.Position = UDim2.fromScale(0.5, 0.48)
	windowHolder.Size = UDim2.fromScale(0.92, 0.84)
	windowScale.Scale = 1
	scaleSlider.set(100)
end)

toggleButton.Activated:Connect(function()
	if toggleButton:GetAttribute("Dragged") then
		return
	end
	windowHolder.Visible = not windowHolder.Visible
end)
