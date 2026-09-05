-- Мобильный обозреватель плейса: дерево Workspace + подсветка и данные о коллизии
-- выбранного объекта. Только официальный Roblox API, без executor-функций
-- (hookmetamethod, firetouchinterest и т.п.) — обычный LocalScript для своего плейса.
--
-- Установка: StarterPlayer -> StarterPlayerScripts -> Insert Object -> LocalScript,
-- вставить содержимое файла. Впиши свой UserId в CONFIG.Admins, иначе панель
-- увидит только владелец плейса и ты в Studio.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local CONFIG = {
	Admins = {}, -- твой UserId, например { 123456789 }
	AllowPlaceOwner = true,
	AllowInStudio = true,
}

local LocalPlayer = Players.LocalPlayer

local function isAllowed()
	if CONFIG.AllowInStudio and RunService:IsStudio() then
		return true
	end

	for _, id in CONFIG.Admins do
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

local ROW_HEIGHT = 32
local INDENT = 18
local HEADER_HEIGHT = 48
local DIVIDER_HEIGHT = 1

local THEME = {
	Background = Color3.fromRGB(18, 20, 26),
	Panel = Color3.fromRGB(26, 29, 37),
	PanelLight = Color3.fromRGB(34, 38, 48),
	Accent = Color3.fromRGB(120, 170, 255),
	Text = Color3.fromRGB(235, 238, 245),
	TextDim = Color3.fromRGB(150, 158, 175),
	Highlight = Color3.fromRGB(255, 90, 90),
}

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
windowHolder.Size = UDim2.fromScale(0.92, 0.8)
windowHolder.BackgroundColor3 = THEME.Background
windowHolder.BorderSizePixel = 0
windowHolder.Visible = false
windowHolder.ClipsDescendants = true
windowHolder.ZIndex = 10
windowHolder.Parent = gui
corner(windowHolder, 16)

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
title.Size = UDim2.new(1, -96, 1, 0)
title.Position = UDim2.fromOffset(16, 0)
title.ZIndex = 12
title.Parent = header

local refreshButton = Instance.new("TextButton")
refreshButton.Text = "⟳"
refreshButton.Font = Enum.Font.GothamBold
refreshButton.TextSize = 18
refreshButton.TextColor3 = THEME.Text
refreshButton.BackgroundTransparency = 1
refreshButton.AutoButtonColor = false
refreshButton.Size = UDim2.fromOffset(40, 40)
refreshButton.Position = UDim2.new(1, -88, 0.5, -20)
refreshButton.ZIndex = 12
refreshButton.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Text = "✕"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 16
closeButton.TextColor3 = THEME.Text
closeButton.BackgroundTransparency = 1
closeButton.AutoButtonColor = false
closeButton.Size = UDim2.fromOffset(40, 40)
closeButton.Position = UDim2.new(1, -44, 0.5, -20)
closeButton.ZIndex = 12
closeButton.Parent = header

makeDraggable(header, windowHolder)

local treeScroll = Instance.new("ScrollingFrame")
treeScroll.Name = "Tree"
treeScroll.Position = UDim2.fromOffset(0, HEADER_HEIGHT)
treeScroll.Size = UDim2.new(1, 0, 0.6, -HEADER_HEIGHT)
treeScroll.BackgroundTransparency = 1
treeScroll.BorderSizePixel = 0
treeScroll.ScrollBarThickness = 4
treeScroll.ScrollBarImageColor3 = THEME.Accent
treeScroll.CanvasSize = UDim2.new()
treeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
treeScroll.ZIndex = 11
treeScroll.Parent = windowHolder
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
divider.Parent = windowHolder

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
infoPanel.Parent = windowHolder
padding(infoPanel, 12)

local infoLabel = Instance.new("TextLabel")
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Выбери объект в дереве выше"
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

local function formatBool(value)
	return value and "да" or "нет"
end

local function describe(instance)
	local lines = {
		"Имя: " .. instance.Name,
		"Класс: " .. instance.ClassName,
		"Путь: " .. instance:GetFullName(),
	}

	if instance:IsA("BasePart") then
		table.insert(lines, "")
		table.insert(lines, "CanCollide: " .. formatBool(instance.CanCollide))
		table.insert(lines, "CanTouch: " .. formatBool(instance.CanTouch))
		table.insert(lines, "CanQuery: " .. formatBool(instance.CanQuery))
		table.insert(lines, "CollisionGroup: " .. instance.CollisionGroup)
		table.insert(lines, "Size: " .. tostring(instance.Size))

		local ok, fidelity = pcall(function()
			return instance.CollisionFidelity
		end)
		if ok then
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
	infoLabel.Text = "Выбери объект в дереве выше"
	infoLabel.TextColor3 = THEME.TextDim
end

local function selectInstance(instance, row)
	if selectedRow then
		selectedRow.BackgroundTransparency = 1
	end

	selectedRow = row
	row.BackgroundColor3 = THEME.Accent
	row.BackgroundTransparency = 0.85

	highlight.Adornee = instance
	highlight.Enabled = true
	infoLabel.Text = describe(instance)
	infoLabel.TextColor3 = THEME.Text
end

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

	local hasChildren = #instance:GetChildren() > 0

	local arrow = Instance.new("TextButton")
	arrow.Size = UDim2.fromOffset(ROW_HEIGHT, ROW_HEIGHT)
	arrow.BackgroundTransparency = 1
	arrow.AutoButtonColor = false
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 12
	arrow.TextColor3 = THEME.TextDim
	arrow.Text = hasChildren and "▶" or "•"
	arrow.ZIndex = 13
	arrow.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, -ROW_HEIGHT, 1, 0)
	nameLabel.Position = UDim2.fromOffset(ROW_HEIGHT, 0)
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

	local function toggleExpand()
		if not hasChildren then
			return
		end

		expanded = not expanded
		childrenFrame.Visible = expanded
		arrow.Text = expanded and "▼" or "▶"

		if expanded and not built then
			built = true
			local children = instance:GetChildren()
			table.sort(children, function(a, b)
				return a.Name:lower() < b.Name:lower()
			end)
			for index, child in ipairs(children) do
				createNode(child, childrenFrame, index)
			end
		end
	end

	arrow.Activated:Connect(toggleExpand)
	row.Activated:Connect(function()
		selectInstance(instance, row)
	end)

	return node, toggleExpand
end

local rootNodeFrame, rootToggle = createNode(workspace, treeScroll, 1)
rootToggle()

local function rebuildTree()
	resetSelection()
	rootNodeFrame:Destroy()
	rootNodeFrame, rootToggle = createNode(workspace, treeScroll, 1)
	rootToggle()
end

refreshButton.Activated:Connect(rebuildTree)

local isOpen = false

local function setOpen(value)
	isOpen = value
	windowHolder.Visible = value
	if not value then
		highlight.Enabled = false
	elseif selectedRow then
		highlight.Enabled = true
	end
end

toggleButton.Activated:Connect(function()
	if toggleButton:GetAttribute("Dragged") then
		return
	end
	setOpen(not isOpen)
end)

closeButton.Activated:Connect(function()
	setOpen(false)
end)
