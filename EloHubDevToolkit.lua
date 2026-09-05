local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CONFIG = {
	Admins = {},
	AllowPlaceOwner = true,
	MinGroupRank = 0,
	AllowEveryoneInStudio = true,

	Title = "ELO HUB",
	Subtitle = "Dead Rails · Dev Toolkit",
	BackgroundImage = "",
	ToggleKey = Enum.KeyCode.RightShift,

	EnemyTag = "Enemy",
	ItemTag = "Loot",
	UseFallbackDetection = true,

	MaxTeleportRadius = 25000,
	TeleportCooldown = 0.2,
	RequestsPerSecond = 25,

	Flags = {
		Godmode = "DevGodmode",
		Noclip = "DevNoclip",
		InfiniteItems = "DevInfiniteItems",
		NoReload = "DevNoReload",
	},

	Limits = {
		WalkSpeed = { min = 0, max = 250, default = 16 },
		JumpPower = { min = 0, max = 350, default = 50 },
		FlySpeed = { min = 10, max = 400, default = 70 },
		EspDistance = { min = 50, max = 5000, default = 1000 },
	},

	Locations = {
		{ Name = "Спавн", Position = Vector3.new(0, 10, 0) },
		{ Name = "Точка A", Position = Vector3.new(0, 10, -500) },
		{ Name = "Точка B", Position = Vector3.new(0, 10, -1000) },
		{ Name = "Точка C", Position = Vector3.new(0, 10, -1500) },
		{ Name = "Финал", Position = Vector3.new(0, 10, -2000) },
	},
}

local THEME = {
	Void = Color3.fromRGB(6, 9, 17),
	Abyss = Color3.fromRGB(11, 17, 32),
	Navy = Color3.fromRGB(23, 40, 74),
	NavyLit = Color3.fromRGB(38, 62, 106),
	Steel = Color3.fromRGB(122, 145, 176),
	SteelSoft = Color3.fromRGB(92, 116, 150),
	Accent = Color3.fromRGB(150, 184, 255),
	AccentDeep = Color3.fromRGB(72, 118, 214),
	Text = Color3.fromRGB(238, 243, 252),
	TextDim = Color3.fromRGB(168, 182, 205),
	TextFaint = Color3.fromRGB(118, 133, 158),
	Stroke = Color3.fromRGB(255, 255, 255),
	Warn = Color3.fromRGB(255, 196, 112),
	EspPlayers = Color3.fromRGB(150, 184, 255),
	EspEnemies = Color3.fromRGB(255, 122, 122),
	EspItems = Color3.fromRGB(126, 224, 168),
}

local FONT_DISPLAY = Enum.Font.GothamBold
local FONT_BODY = Enum.Font.GothamMedium
local FONT_MONO = Enum.Font.Code

local TWEEN_FAST = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_BASE = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_PANEL = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local REMOTE_FOLDER = "DevToolkitRemotes"
local NOCLIP_GROUP = "DevToolkitNoclip"
local GUI_NAME = "EloHubDevToolkit"
local ESP_FOLDER = "DevToolkitEsp"

local ACTION = {
	SetToggle = "SetToggle",
	SetNumber = "SetNumber",
	Teleport = "Teleport",
	TeleportToPlayer = "TeleportToPlayer",
	TeleportToLocation = "TeleportToLocation",
	Respawn = "Respawn",
}

local TOGGLE = {
	Godmode = "Godmode",
	Noclip = "Noclip",
	Fly = "Fly",
	FreezeEnemies = "FreezeEnemies",
	InfiniteItems = "InfiniteItems",
	NoReload = "NoReload",
}

local NUMBER = {
	WalkSpeed = "WalkSpeed",
	JumpPower = "JumpPower",
	FlySpeed = "FlySpeed",
}

local function clampLimit(key, value)
	local limit = CONFIG.Limits[key]
	if not limit then
		return nil
	end
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	if value == math.huge or value == -math.huge then
		return nil
	end
	return math.clamp(value, limit.min, limit.max)
end

local function isKnown(set, key)
	for _, name in set do
		if name == key then
			return true
		end
	end
	return false
end

local function runServer()
	local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = REMOTE_FOLDER
		folder.Parent = ReplicatedStorage
	end

	local function ensure(className, name)
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end

	local actionRemote = ensure("RemoteEvent", "Action")
	local stateRemote = ensure("RemoteEvent", "State")
	local queryRemote = ensure("RemoteFunction", "Query")

	local accessCache = {}

	local function isAuthorized(player)
		local cached = accessCache[player.UserId]
		if cached ~= nil then
			return cached
		end

		local allowed = false

		if CONFIG.AllowEveryoneInStudio and RunService:IsStudio() then
			allowed = true
		else
			for _, id in CONFIG.Admins do
				if id == player.UserId then
					allowed = true
					break
				end
			end

			if not allowed and CONFIG.AllowPlaceOwner then
				if game.CreatorType == Enum.CreatorType.User then
					allowed = player.UserId == game.CreatorId
				elseif game.CreatorType == Enum.CreatorType.Group then
					local ok, rank = pcall(function()
						return player:GetRankInGroup(game.CreatorId)
					end)
					allowed = ok and rank == 255
				end
			end

			if not allowed and CONFIG.MinGroupRank > 0 and game.CreatorType == Enum.CreatorType.Group then
				local ok, rank = pcall(function()
					return player:GetRankInGroup(game.CreatorId)
				end)
				allowed = ok and rank >= CONFIG.MinGroupRank
			end
		end

		accessCache[player.UserId] = allowed
		return allowed
	end

	local states = {}

	local function getState(player)
		local state = states[player]
		if not state then
			state = {
				toggles = {},
				numbers = {
					[NUMBER.WalkSpeed] = CONFIG.Limits.WalkSpeed.default,
					[NUMBER.JumpPower] = CONFIG.Limits.JumpPower.default,
					[NUMBER.FlySpeed] = CONFIG.Limits.FlySpeed.default,
				},
				connections = {},
				originalGroups = {},
			}
			states[player] = state
		end
		return state
	end

	local noclipGroupReady = false

	local function ensureNoclipGroup()
		if noclipGroupReady then
			return
		end

		local ok = pcall(function()
			if not PhysicsService:IsCollisionGroupRegistered(NOCLIP_GROUP) then
				PhysicsService:RegisterCollisionGroup(NOCLIP_GROUP)
			end
		end)

		if not ok then
			warn("[DevToolkit] Не удалось зарегистрировать группу коллизий, noclip недоступен")
			return
		end

		for _, group in PhysicsService:GetRegisteredCollisionGroups() do
			pcall(function()
				PhysicsService:CollisionGroupSetCollidable(NOCLIP_GROUP, group.name, false)
			end)
		end

		noclipGroupReady = true
	end

	local function getHumanoid(player)
		local character = player.Character
		if not character then
			return nil
		end
		return character:FindFirstChildOfClass("Humanoid")
	end

	local function applyGodmode(player, on)
		local humanoid = getHumanoid(player)
		if not humanoid then
			return
		end

		player:SetAttribute(CONFIG.Flags.Godmode, on or nil)

		if on then
			humanoid.BreakJointsOnDeath = false
			local state = getState(player)
			local connection = humanoid.HealthChanged:Connect(function(health)
				if not state.toggles[TOGGLE.Godmode] then
					return
				end
				if health < humanoid.MaxHealth then
					humanoid.Health = humanoid.MaxHealth
				end
			end)
			table.insert(state.connections, connection)
			humanoid.Health = humanoid.MaxHealth
		else
			humanoid.BreakJointsOnDeath = true
		end
	end

	local function applyNoclip(player, on)
		local character = player.Character
		if not character then
			return
		end

		player:SetAttribute(CONFIG.Flags.Noclip, on or nil)

		local state = getState(player)

		if on then
			ensureNoclipGroup()
			if not noclipGroupReady then
				return
			end
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					state.originalGroups[part] = part.CollisionGroup
					part.CollisionGroup = NOCLIP_GROUP
				end
			end
		else
			for part, group in state.originalGroups do
				if part.Parent then
					part.CollisionGroup = group
				end
			end
			table.clear(state.originalGroups)
		end
	end

	local function applyMovementNumbers(player)
		local humanoid = getHumanoid(player)
		if not humanoid then
			return
		end

		local state = getState(player)
		humanoid.WalkSpeed = state.numbers[NUMBER.WalkSpeed]

		if humanoid.UseJumpPower then
			humanoid.JumpPower = state.numbers[NUMBER.JumpPower]
		else
			humanoid.JumpHeight = state.numbers[NUMBER.JumpPower] / 10
		end
	end

	local frozen = {}
	local freezeHolders = {}
	local enemiesFrozen = false
	local freezeAddedConnection = nil

	local function listEnemies()
		local result = {}
		local seen = {}

		for _, instance in CollectionService:GetTagged(CONFIG.EnemyTag) do
			if instance:IsA("Model") and instance:IsDescendantOf(workspace) and not seen[instance] then
				seen[instance] = true
				table.insert(result, instance)
			end
		end

		if #result == 0 and CONFIG.UseFallbackDetection then
			for _, instance in workspace:GetDescendants() do
				if instance:IsA("Humanoid") then
					local model = instance.Parent
					if model and model:IsA("Model") and not seen[model] and not Players:GetPlayerFromCharacter(model) then
						seen[model] = true
						table.insert(result, model)
					end
				end
			end
		end

		return result
	end

	local function freezeOne(model)
		if frozen[model] then
			return
		end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		local record = {
			walkSpeed = humanoid.WalkSpeed,
			jumpPower = humanoid.JumpPower,
		}

		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0

		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			record.anchored = root.Anchored
			root.Anchored = true
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end

		frozen[model] = record
	end

	local function unfreezeOne(model)
		local record = frozen[model]
		if not record then
			return
		end
		frozen[model] = nil

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = record.walkSpeed
			humanoid.JumpPower = record.jumpPower
		end

		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and record.anchored ~= nil then
			root.Anchored = record.anchored
		end
	end

	local function setEnemiesFrozen(on)
		if enemiesFrozen == on then
			return
		end
		enemiesFrozen = on

		if on then
			for _, model in listEnemies() do
				freezeOne(model)
			end
			freezeAddedConnection = CollectionService:GetInstanceAddedSignal(CONFIG.EnemyTag):Connect(function(instance)
				if enemiesFrozen and instance:IsA("Model") then
					task.wait(0.1)
					if enemiesFrozen then
						freezeOne(instance)
					end
				end
			end)
		else
			if freezeAddedConnection then
				freezeAddedConnection:Disconnect()
				freezeAddedConnection = nil
			end
			for model in frozen do
				unfreezeOne(model)
			end
		end
	end

	local function setToggle(player, key, on)
		local state = getState(player)
		state.toggles[key] = on or nil

		if key == TOGGLE.Godmode then
			applyGodmode(player, on)
		elseif key == TOGGLE.Noclip then
			applyNoclip(player, on)
		elseif key == TOGGLE.Fly then
			player:SetAttribute("DevFlyAllowed", on or nil)
			player:SetAttribute("DevFlySpeed", state.numbers[NUMBER.FlySpeed])
		elseif key == TOGGLE.InfiniteItems then
			player:SetAttribute(CONFIG.Flags.InfiniteItems, on or nil)
		elseif key == TOGGLE.NoReload then
			player:SetAttribute(CONFIG.Flags.NoReload, on or nil)
		end
	end

	local function reapply(player)
		local state = states[player]
		if not state then
			return
		end

		for _, connection in state.connections do
			connection:Disconnect()
		end
		table.clear(state.connections)
		table.clear(state.originalGroups)

		applyMovementNumbers(player)

		for key, on in state.toggles do
			if on then
				setToggle(player, key, true)
			end
		end
	end

	local lastTeleport = {}

	local function isFiniteVector(value)
		if typeof(value) ~= "Vector3" then
			return false
		end
		for _, component in { value.X, value.Y, value.Z } do
			if component ~= component or component == math.huge or component == -math.huge then
				return false
			end
		end
		return true
	end

	local function teleportTo(player, position)
		if not isFiniteVector(position) then
			return false
		end
		if position.Magnitude > CONFIG.MaxTeleportRadius then
			return false
		end

		local now = os.clock()
		local last = lastTeleport[player]
		if last and now - last < CONFIG.TeleportCooldown then
			return false
		end

		local character = player.Character
		if not character then
			return false
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return false
		end

		lastTeleport[player] = now

		local target = position + Vector3.new(0, 3.5, 0)
		character:PivotTo(CFrame.new(target, target + root.CFrame.LookVector))
		root.AssemblyLinearVelocity = Vector3.zero

		return true
	end

	local budget = {}

	local function allowRequest(player)
		local now = os.clock()
		local entry = budget[player]

		if not entry then
			entry = { tokens = CONFIG.RequestsPerSecond, updated = now }
			budget[player] = entry
		end

		entry.tokens = math.min(CONFIG.RequestsPerSecond, entry.tokens + (now - entry.updated) * CONFIG.RequestsPerSecond)
		entry.updated = now

		if entry.tokens < 1 then
			return false
		end

		entry.tokens -= 1
		return true
	end

	local function pushState(player)
		local state = getState(player)
		stateRemote:FireClient(player, {
			toggles = state.toggles,
			numbers = state.numbers,
			enemiesFrozen = enemiesFrozen,
		})
	end

	local handlers = {}

	handlers[ACTION.SetToggle] = function(player, payload)
		if typeof(payload) ~= "table" then
			return
		end

		local key = payload.key
		local value = payload.value

		if typeof(key) ~= "string" or typeof(value) ~= "boolean" then
			return
		end
		if not isKnown(TOGGLE, key) then
			return
		end

		if key == TOGGLE.FreezeEnemies then
			getState(player).toggles[key] = value or nil
			freezeHolders[player] = value or nil
			setEnemiesFrozen(next(freezeHolders) ~= nil)

			for _, other in Players:GetPlayers() do
				if isAuthorized(other) then
					pushState(other)
				end
			end
			return
		end

		setToggle(player, key, value)
		pushState(player)
	end

	handlers[ACTION.SetNumber] = function(player, payload)
		if typeof(payload) ~= "table" then
			return
		end

		local key = payload.key
		if typeof(key) ~= "string" or not isKnown(NUMBER, key) then
			return
		end

		local value = clampLimit(key, payload.value)
		if not value then
			return
		end

		local state = getState(player)
		state.numbers[key] = value

		if key == NUMBER.FlySpeed then
			if state.toggles[TOGGLE.Fly] then
				player:SetAttribute("DevFlySpeed", value)
			end
		else
			applyMovementNumbers(player)
		end

		pushState(player)
	end

	handlers[ACTION.Teleport] = function(player, payload)
		if typeof(payload) ~= "table" then
			return
		end
		teleportTo(player, payload.position)
	end

	handlers[ACTION.TeleportToPlayer] = function(player, payload)
		if typeof(payload) ~= "table" or typeof(payload.userId) ~= "number" then
			return
		end

		local target = Players:GetPlayerByUserId(payload.userId)
		if not target or target == player then
			return
		end

		local character = target.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end

		teleportTo(player, (root.CFrame * CFrame.new(0, 0, 4)).Position)
	end

	handlers[ACTION.TeleportToLocation] = function(player, payload)
		if typeof(payload) ~= "table" or typeof(payload.name) ~= "string" then
			return
		end
		for _, location in CONFIG.Locations do
			if location.Name == payload.name then
				teleportTo(player, location.Position)
				return
			end
		end
	end

	handlers[ACTION.Respawn] = function(player)
		player:LoadCharacter()
	end

	actionRemote.OnServerEvent:Connect(function(player, action, payload)
		if typeof(action) ~= "string" then
			return
		end
		if not isAuthorized(player) then
			return
		end
		if not allowRequest(player) then
			return
		end

		local handler = handlers[action]
		if handler then
			handler(player, payload)
		end
	end)

	queryRemote.OnServerInvoke = function(player, query)
		if typeof(query) ~= "string" then
			return nil
		end

		if query == "IsAuthorized" then
			return isAuthorized(player)
		end

		if not isAuthorized(player) then
			return nil
		end

		if query == "GetState" then
			local state = getState(player)
			return {
				toggles = state.toggles,
				numbers = state.numbers,
				enemiesFrozen = enemiesFrozen,
			}
		end

		return nil
	end

	local function watch(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.25)
			reapply(player)
		end)
	end

	for _, player in Players:GetPlayers() do
		watch(player)
	end

	Players.PlayerAdded:Connect(watch)

	Players.PlayerRemoving:Connect(function(player)
		freezeHolders[player] = nil
		setEnemiesFrozen(next(freezeHolders) ~= nil)

		local state = states[player]
		if state then
			for _, connection in state.connections do
				connection:Disconnect()
			end
			states[player] = nil
		end

		lastTeleport[player] = nil
		budget[player] = nil
		accessCache[player.UserId] = nil
	end)

	if #CONFIG.Admins == 0 and not CONFIG.AllowPlaceOwner then
		warn("[DevToolkit] Список админов пуст и владелец плейса не разрешён, панель не откроется")
	end
end

local function runClient()
	local LocalPlayer = Players.LocalPlayer

	local remotes = ReplicatedStorage:WaitForChild(REMOTE_FOLDER, 30)
	if not remotes then
		return
	end

	local actionRemote = remotes:WaitForChild("Action")
	local stateRemote = remotes:WaitForChild("State")
	local queryRemote = remotes:WaitForChild("Query")

	local ok, authorized = pcall(function()
		return queryRemote:InvokeServer("IsAuthorized")
	end)

	if not ok or authorized ~= true then
		return
	end

	local function send(action, payload)
		actionRemote:FireServer(action, payload)
	end

	local lastSent = {}
	local pendingSend = {}

	local function sendNumber(key, value)
		local now = os.clock()
		if now - (lastSent[key] or 0) >= 0.1 then
			lastSent[key] = now
			pendingSend[key] = nil
			send(ACTION.SetNumber, { key = key, value = value })
			return
		end

		pendingSend[key] = value
		task.delay(0.12, function()
			local queued = pendingSend[key]
			if queued then
				pendingSend[key] = nil
				lastSent[key] = os.clock()
				send(ACTION.SetNumber, { key = key, value = queued })
			end
		end)
	end

	local function corner(parent, radius)
		local instance = Instance.new("UICorner")
		instance.CornerRadius = radius
		instance.Parent = parent
		return instance
	end

	local function stroke(parent, transparency, thickness)
		local instance = Instance.new("UIStroke")
		instance.Color = THEME.Stroke
		instance.Thickness = thickness or 1.5
		instance.Transparency = transparency or 0.55
		instance.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		instance.Parent = parent
		return instance
	end

	local function padding(parent, top, right, bottom, left)
		local instance = Instance.new("UIPadding")
		instance.PaddingTop = UDim.new(0, top)
		instance.PaddingRight = UDim.new(0, right)
		instance.PaddingBottom = UDim.new(0, bottom)
		instance.PaddingLeft = UDim.new(0, left)
		instance.Parent = parent
		return instance
	end

	local function label(parent, text, size, font, color)
		local instance = Instance.new("TextLabel")
		instance.BackgroundTransparency = 1
		instance.Text = text
		instance.TextSize = size
		instance.Font = font
		instance.TextColor3 = color
		instance.TextXAlignment = Enum.TextXAlignment.Left
		instance.TextYAlignment = Enum.TextYAlignment.Center
		instance.RichText = true
		instance.Parent = parent
		return instance
	end

	local function ellipse(name, parent)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BorderSizePixel = 0
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Parent = parent
		corner(frame, UDim.new(1, 0))
		return frame
	end

	local function buildBackground(parent)
		local root = Instance.new("Frame")
		root.Name = "Background"
		root.Size = UDim2.fromScale(1, 1)
		root.BackgroundColor3 = THEME.Void
		root.BorderSizePixel = 0
		root.ZIndex = 0
		root.Parent = parent

		local base = Instance.new("UIGradient")
		base.Rotation = 24
		base.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, THEME.Void),
			ColorSequenceKeypoint.new(0.42, THEME.Abyss),
			ColorSequenceKeypoint.new(0.78, THEME.Navy),
			ColorSequenceKeypoint.new(1.00, THEME.NavyLit),
		})
		base.Parent = root

		if CONFIG.BackgroundImage ~= "" then
			local image = Instance.new("ImageLabel")
			image.Size = UDim2.fromScale(1, 1)
			image.BackgroundTransparency = 1
			image.Image = CONFIG.BackgroundImage
			image.ScaleType = Enum.ScaleType.Crop
			image.ZIndex = 1
			image.Parent = root

			local scrim = Instance.new("Frame")
			scrim.Size = UDim2.fromScale(1, 1)
			scrim.BackgroundColor3 = THEME.Void
			scrim.BackgroundTransparency = 0.45
			scrim.BorderSizePixel = 0
			scrim.ZIndex = 2
			scrim.Parent = root

			return root
		end

		local wave = ellipse("Wave", root)
		wave.Size = UDim2.fromScale(1.9, 1.3)
		wave.Position = UDim2.fromScale(0.28, 0.92)
		wave.Rotation = -14
		wave.BackgroundColor3 = THEME.Navy
		wave.ZIndex = 1

		local waveGradient = Instance.new("UIGradient")
		waveGradient.Rotation = 70
		waveGradient.Color = ColorSequence.new(THEME.NavyLit, THEME.Abyss)
		waveGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.00, 0.15),
			NumberSequenceKeypoint.new(0.55, 0.55),
			NumberSequenceKeypoint.new(1.00, 1.00),
		})
		waveGradient.Parent = wave

		local crest = ellipse("Crest", root)
		crest.Size = UDim2.fromScale(1.5, 1.05)
		crest.Position = UDim2.fromScale(0.88, 0.52)
		crest.Rotation = -22
		crest.BackgroundColor3 = THEME.Steel
		crest.ZIndex = 2

		local crestGradient = Instance.new("UIGradient")
		crestGradient.Rotation = 118
		crestGradient.Color = ColorSequence.new(THEME.Steel, THEME.SteelSoft)
		crestGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.00, 0.62),
			NumberSequenceKeypoint.new(0.45, 0.80),
			NumberSequenceKeypoint.new(1.00, 1.00),
		})
		crestGradient.Parent = crest

		local sheen = ellipse("Sheen", root)
		sheen.Size = UDim2.fromScale(1.1, 0.5)
		sheen.Position = UDim2.fromScale(0.62, 0.06)
		sheen.Rotation = -8
		sheen.BackgroundColor3 = THEME.SteelSoft
		sheen.ZIndex = 3

		local sheenGradient = Instance.new("UIGradient")
		sheenGradient.Rotation = 90
		sheenGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.00, 0.86),
			NumberSequenceKeypoint.new(1.00, 1.00),
		})
		sheenGradient.Parent = sheen

		local vignette = Instance.new("Frame")
		vignette.Size = UDim2.fromScale(1, 1)
		vignette.BackgroundColor3 = THEME.Void
		vignette.BorderSizePixel = 0
		vignette.ZIndex = 4
		vignette.Parent = root

		local vignetteGradient = Instance.new("UIGradient")
		vignetteGradient.Rotation = 32
		vignetteGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.00, 0.30),
			NumberSequenceKeypoint.new(0.35, 0.85),
			NumberSequenceKeypoint.new(0.70, 0.92),
			NumberSequenceKeypoint.new(1.00, 0.45),
		})
		vignetteGradient.Parent = vignette

		return root
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 100
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local function makeDraggable(handle, target)
		local dragging = false
		local dragStart = Vector3.zero
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
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	end

	local inset = GuiService:GetGuiInset()

	local launcherHolder = Instance.new("Frame")
	launcherHolder.Name = "LauncherHolder"
	launcherHolder.Size = UDim2.fromOffset(56, 56)
	launcherHolder.Position = UDim2.new(0, 16, 0, inset.Y + 16)
	launcherHolder.BackgroundTransparency = 1
	launcherHolder.ZIndex = 20
	launcherHolder.Parent = gui

	local launcher = Instance.new("TextButton")
	launcher.Name = "Launcher"
	launcher.Size = UDim2.fromScale(1, 1)
	launcher.BackgroundColor3 = THEME.Navy
	launcher.BorderSizePixel = 0
	launcher.AutoButtonColor = false
	launcher.Text = ""
	launcher.ZIndex = 21
	launcher.Parent = launcherHolder

	corner(launcher, UDim.new(0, 18))
	stroke(launcher, 0.45, 1.5)

	local launcherGradient = Instance.new("UIGradient")
	launcherGradient.Rotation = 40
	launcherGradient.Color = ColorSequence.new(THEME.NavyLit, THEME.Abyss)
	launcherGradient.Parent = launcher

	local launcherGlyph = label(launcher, "E", 24, FONT_DISPLAY, THEME.Text)
	launcherGlyph.Size = UDim2.fromScale(1, 1)
	launcherGlyph.TextXAlignment = Enum.TextXAlignment.Center
	launcherGlyph.ZIndex = 22

	makeDraggable(launcher, launcherHolder)

	local holder = Instance.new("Frame")
	holder.Name = "WindowHolder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.ZIndex = 10
	holder.Parent = gui

	for index = 1, 5 do
		local spread = index * 6
		local shadow = Instance.new("Frame")
		shadow.AnchorPoint = Vector2.new(0.5, 0.5)
		shadow.Position = UDim2.fromScale(0.5, 0.5)
		shadow.Size = UDim2.new(1, spread * 2, 1, spread * 2)
		shadow.BackgroundColor3 = THEME.Void
		shadow.BackgroundTransparency = 0.72 + (index / 5) * 0.26
		shadow.BorderSizePixel = 0
		shadow.ZIndex = 4 + index
		shadow.Parent = holder
		corner(shadow, UDim.new(0, 22 + spread))
	end

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.Size = UDim2.fromScale(1, 1)
	window.BackgroundColor3 = THEME.Void
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.ZIndex = 10
	window.Parent = holder

	corner(window, UDim.new(0, 22))

	local windowStroke = stroke(window, 0.55, 1.5)
	local windowStrokeGradient = Instance.new("UIGradient")
	windowStrokeGradient.Rotation = 90
	windowStrokeGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.75),
	})
	windowStrokeGradient.Parent = windowStroke

	buildBackground(window)

	local windowScale = Instance.new("UIScale")
	windowScale.Parent = window

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 66)
	header.BackgroundTransparency = 1
	header.ZIndex = 12
	header.Parent = window

	padding(header, 0, 18, 0, 20)

	local titleLabel = label(header, CONFIG.Title, 20, FONT_DISPLAY, THEME.Text)
	titleLabel.Size = UDim2.new(1, -60, 0, 24)
	titleLabel.Position = UDim2.fromOffset(0, 14)
	titleLabel.ZIndex = 13

	local subtitleLabel = label(header, CONFIG.Subtitle, 12, FONT_BODY, THEME.TextFaint)
	subtitleLabel.Size = UDim2.new(1, -60, 0, 16)
	subtitleLabel.Position = UDim2.fromOffset(0, 36)
	subtitleLabel.ZIndex = 13

	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, 0, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(38, 38)
	closeButton.BackgroundColor3 = THEME.Abyss
	closeButton.BackgroundTransparency = 0.4
	closeButton.BorderSizePixel = 0
	closeButton.AutoButtonColor = false
	closeButton.Text = "✕"
	closeButton.TextSize = 16
	closeButton.Font = FONT_BODY
	closeButton.TextColor3 = THEME.TextDim
	closeButton.ZIndex = 13
	closeButton.Parent = header

	corner(closeButton, UDim.new(0, 12))
	stroke(closeButton, 0.8, 1)

	local divider = Instance.new("Frame")
	divider.AnchorPoint = Vector2.new(0.5, 1)
	divider.Position = UDim2.new(0.5, 0, 1, 0)
	divider.Size = UDim2.new(1, -36, 0, 1)
	divider.BackgroundColor3 = THEME.Stroke
	divider.BackgroundTransparency = 0.85
	divider.BorderSizePixel = 0
	divider.ZIndex = 13
	divider.Parent = header

	makeDraggable(header, holder)

	local tabBar = Instance.new("ScrollingFrame")
	tabBar.Name = "TabBar"
	tabBar.Position = UDim2.fromOffset(0, 66)
	tabBar.Size = UDim2.new(1, 0, 0, 52)
	tabBar.BackgroundTransparency = 1
	tabBar.BorderSizePixel = 0
	tabBar.ScrollBarThickness = 0
	tabBar.ScrollingDirection = Enum.ScrollingDirection.X
	tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabBar.CanvasSize = UDim2.new()
	tabBar.ZIndex = 12
	tabBar.Parent = window

	padding(tabBar, 10, 18, 6, 18)

	local tabBarLayout = Instance.new("UIListLayout")
	tabBarLayout.FillDirection = Enum.FillDirection.Horizontal
	tabBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabBarLayout.Padding = UDim.new(0, 8)
	tabBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tabBarLayout.Parent = tabBar

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(0, 118)
	content.Size = UDim2.new(1, 0, 1, -158)
	content.BackgroundTransparency = 1
	content.ZIndex = 12
	content.Parent = window

	local footer = Instance.new("Frame")
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 0, 1, 0)
	footer.Size = UDim2.new(1, 0, 0, 40)
	footer.BackgroundTransparency = 1
	footer.ZIndex = 12
	footer.Parent = window

	padding(footer, 0, 20, 8, 20)

	local statusLabel = label(footer, "", 12, FONT_BODY, THEME.TextFaint)
	statusLabel.Size = UDim2.new(1, 0, 1, 0)
	statusLabel.ZIndex = 13

	local statusToken = 0

	local function setStatus(text, isWarning)
		statusToken += 1
		local token = statusToken
		statusLabel.Text = text
		statusLabel.TextColor3 = if isWarning then THEME.Warn else THEME.TextFaint

		task.delay(3, function()
			if statusToken == token then
				statusLabel.Text = ""
			end
		end)
	end

	local tabs = {}
	local tabButtons = {}
	local tabCount = 0
	local activeTab = nil

	local function selectTab(name)
		if not tabs[name] then
			return
		end

		activeTab = name

		for tabName, page in tabs do
			page.Visible = tabName == name
		end

		for tabName, entry in tabButtons do
			local isActive = tabName == name
			TweenService:Create(entry.button, TWEEN_BASE, {
				BackgroundColor3 = if isActive then THEME.AccentDeep else THEME.Abyss,
				BackgroundTransparency = if isActive then 0.1 else 0.5,
				TextColor3 = if isActive then THEME.Text else THEME.TextDim,
			}):Play()
			TweenService:Create(entry.stroke, TWEEN_BASE, {
				Transparency = if isActive then 0.5 else 0.85,
			}):Play()
		end
	end

	local function addTab(name)
		tabCount += 1

		local button = Instance.new("TextButton")
		button.Name = "Tab_" .. name
		button.Size = UDim2.fromOffset(0, 34)
		button.AutomaticSize = Enum.AutomaticSize.X
		button.BackgroundColor3 = THEME.Abyss
		button.BackgroundTransparency = 0.5
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Text = name
		button.TextSize = 13
		button.Font = FONT_BODY
		button.TextColor3 = THEME.TextDim
		button.LayoutOrder = tabCount
		button.ZIndex = 13
		button.Parent = tabBar

		corner(button, UDim.new(1, 0))
		padding(button, 0, 16, 0, 16)
		local buttonStroke = stroke(button, 0.85, 1)

		local page = Instance.new("ScrollingFrame")
		page.Name = "Page_" .. name
		page.Size = UDim2.fromScale(1, 1)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 3
		page.ScrollBarImageColor3 = THEME.Steel
		page.ScrollBarImageTransparency = 0.5
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.CanvasSize = UDim2.new()
		page.ScrollingDirection = Enum.ScrollingDirection.Y
		page.Visible = false
		page.ZIndex = 12
		page.Parent = content

		padding(page, 6, 18, 18, 18)

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		layout.Parent = page

		tabs[name] = page
		tabButtons[name] = { button = button, stroke = buttonStroke }

		button.Activated:Connect(function()
			selectTab(name)
		end)

		if not activeTab then
			selectTab(name)
		end

		return page
	end

	local function card(parent, order)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.BackgroundColor3 = THEME.Abyss
		frame.BackgroundTransparency = 0.35
		frame.BorderSizePixel = 0
		frame.LayoutOrder = order
		frame.Parent = parent

		corner(frame, UDim.new(0, 14))
		stroke(frame, 0.88)
		padding(frame, 8, 10, 8, 10)

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 4)
		layout.Parent = frame

		return frame
	end

	local function sectionLabel(parent, text, order)
		local instance = label(parent, string.upper(text), 12, FONT_DISPLAY, THEME.TextFaint)
		instance.Size = UDim2.new(1, 0, 0, 26)
		instance.LayoutOrder = order
		return instance
	end

	local function toggleRow(parent, options)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 54)
		row.BackgroundTransparency = 1
		row.LayoutOrder = options.order or 0
		row.Parent = parent

		padding(row, 0, 4, 0, 6)

		local title = label(row, options.title, 15, FONT_BODY, THEME.Text)
		title.Size = UDim2.new(1, -70, 0, 20)
		title.Position = UDim2.fromOffset(0, if options.subtitle then 9 else 17)

		if options.subtitle then
			local subtitle = label(row, options.subtitle, 12, FONT_BODY, THEME.TextFaint)
			subtitle.Size = UDim2.new(1, -70, 0, 16)
			subtitle.Position = UDim2.fromOffset(0, 29)
		end

		local track = Instance.new("TextButton")
		track.AnchorPoint = Vector2.new(1, 0.5)
		track.Position = UDim2.new(1, 0, 0.5, 0)
		track.Size = UDim2.fromOffset(52, 30)
		track.BackgroundColor3 = THEME.Abyss
		track.BorderSizePixel = 0
		track.AutoButtonColor = false
		track.Text = ""
		track.Parent = row

		corner(track, UDim.new(1, 0))
		local trackStroke = stroke(track, 0.7, 1)

		local knob = Instance.new("Frame")
		knob.AnchorPoint = Vector2.new(0, 0.5)
		knob.Position = UDim2.new(0, 3, 0.5, 0)
		knob.Size = UDim2.fromOffset(24, 24)
		knob.BackgroundColor3 = THEME.TextDim
		knob.BorderSizePixel = 0
		knob.Parent = track

		corner(knob, UDim.new(1, 0))

		local value = options.value == true
		local api = {}

		function api.set(newValue, silent)
			value = newValue

			TweenService:Create(knob, TWEEN_BASE, {
				Position = if value then UDim2.new(1, -27, 0.5, 0) else UDim2.new(0, 3, 0.5, 0),
				BackgroundColor3 = if value then THEME.Text else THEME.TextDim,
			}):Play()

			TweenService:Create(track, TWEEN_BASE, {
				BackgroundColor3 = if value then THEME.AccentDeep else THEME.Abyss,
			}):Play()

			TweenService:Create(trackStroke, TWEEN_BASE, {
				Transparency = if value then 0.35 else 0.7,
			}):Play()

			TweenService:Create(title, TWEEN_BASE, {
				TextColor3 = if value then THEME.Accent else THEME.Text,
			}):Play()

			if not silent and options.onChanged then
				options.onChanged(value)
			end
		end

		function api.get()
			return value
		end

		track.Activated:Connect(function()
			api.set(not value)
		end)

		api.set(value, true)
		return api
	end

	local function sliderRow(parent, options)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 62)
		row.BackgroundTransparency = 1
		row.LayoutOrder = options.order or 0
		row.Parent = parent

		padding(row, 0, 4, 0, 6)

		local title = label(row, options.title, 15, FONT_BODY, THEME.Text)
		title.Size = UDim2.new(1, -80, 0, 20)
		title.Position = UDim2.fromOffset(0, 6)

		local readout = label(row, "", 14, FONT_MONO, THEME.Accent)
		readout.Size = UDim2.fromOffset(80, 20)
		readout.Position = UDim2.new(1, -80, 0, 6)
		readout.TextXAlignment = Enum.TextXAlignment.Right

		local track = Instance.new("TextButton")
		track.Position = UDim2.fromOffset(0, 38)
		track.Size = UDim2.new(1, 0, 0, 8)
		track.BackgroundColor3 = THEME.Abyss
		track.BorderSizePixel = 0
		track.AutoButtonColor = false
		track.Text = ""
		track.Parent = row

		corner(track, UDim.new(1, 0))
		stroke(track, 0.85, 1)

		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = THEME.Accent
		fill.BorderSizePixel = 0
		fill.Parent = track

		corner(fill, UDim.new(1, 0))

		local knob = Instance.new("Frame")
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.Position = UDim2.fromScale(0, 0.5)
		knob.Size = UDim2.fromOffset(22, 22)
		knob.BackgroundColor3 = THEME.Text
		knob.BorderSizePixel = 0
		knob.ZIndex = 2
		knob.Parent = track

		corner(knob, UDim.new(1, 0))
		stroke(knob, 0.4, 1.5)

		local step = options.step or 1
		local value = options.value
		local api = {}

		function api.set(newValue, silent)
			value = math.clamp(newValue, options.min, options.max)
			value = math.floor(value / step + 0.5) * step

			local alpha = if options.max > options.min then (value - options.min) / (options.max - options.min) else 0

			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
			readout.Text = string.format("%d%s", value, options.suffix or "")

			if not silent and options.onChanged then
				options.onChanged(value)
			end
		end

		local dragging = false

		local function updateFromInput(position)
			local width = track.AbsoluteSize.X
			if width <= 0 then
				return
			end
			local alpha = math.clamp((position.X - track.AbsolutePosition.X) / width, 0, 1)
			api.set(options.min + alpha * (options.max - options.min))
		end

		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				TweenService:Create(knob, TWEEN_FAST, { Size = UDim2.fromOffset(26, 26) }):Play()
				updateFromInput(input.Position)
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				updateFromInput(input.Position)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if not dragging then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
				TweenService:Create(knob, TWEEN_FAST, { Size = UDim2.fromOffset(22, 22) }):Play()
			end
		end)

		api.set(value, true)
		return api
	end

	local function buttonRow(parent, options)
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, 0, 0, 54)
		button.BackgroundColor3 = if options.accent then THEME.AccentDeep else THEME.Abyss
		button.BackgroundTransparency = if options.accent then 0.15 else 0.45
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Text = ""
		button.LayoutOrder = options.order or 0
		button.Parent = parent

		corner(button, UDim.new(0, 12))
		stroke(button, if options.accent then 0.5 else 0.85)
		padding(button, 0, 14, 0, 14)

		local title = label(button, options.title, 15, FONT_BODY, THEME.Text)
		title.Size = UDim2.new(1, -20, 0, 20)
		title.Position = UDim2.fromOffset(0, if options.subtitle then 9 else 17)

		if options.subtitle then
			local subtitle = label(button, options.subtitle, 12, FONT_BODY, THEME.TextFaint)
			subtitle.Size = UDim2.new(1, -20, 0, 16)
			subtitle.Position = UDim2.fromOffset(0, 29)
		end

		local chevron = label(button, "›", 22, FONT_DISPLAY, THEME.TextFaint)
		chevron.AnchorPoint = Vector2.new(1, 0.5)
		chevron.Position = UDim2.new(1, 0, 0.5, 0)
		chevron.Size = UDim2.fromOffset(14, 24)
		chevron.TextXAlignment = Enum.TextXAlignment.Right

		local baseTransparency = button.BackgroundTransparency

		local function release()
			TweenService:Create(button, TWEEN_BASE, { BackgroundTransparency = baseTransparency }):Play()
		end

		button.MouseButton1Down:Connect(function()
			TweenService:Create(button, TWEEN_FAST, {
				BackgroundTransparency = math.max(0, baseTransparency - 0.25),
			}):Play()
		end)

		button.MouseButton1Up:Connect(release)
		button.MouseLeave:Connect(release)
		button.Activated:Connect(function()
			release()
			options.onClick()
		end)

		return button
	end

	local isOpen = false

	local function targetSize()
		local viewport = gui.AbsoluteSize
		if viewport.X < 700 then
			return UDim2.new(0.94, 0, 0.82, 0)
		end
		local width = math.clamp(viewport.X * 0.42, 460, 620)
		local height = math.clamp(viewport.Y * 0.72, 420, 640)
		return UDim2.fromOffset(width, height)
	end

	local function applyLayout()
		holder.Size = targetSize()
		local viewport = gui.AbsoluteSize
		windowScale.Scale = if viewport.X < 700 then math.clamp(viewport.X / 420, 0.85, 1.05) else 1
	end

	local function openPanel()
		if isOpen then
			return
		end
		isOpen = true

		applyLayout()

		local target = holder.Size
		holder.Visible = true
		holder.Size = UDim2.new(target.X.Scale * 0.9, target.X.Offset * 0.9, target.Y.Scale * 0.9, target.Y.Offset * 0.9)

		TweenService:Create(holder, TWEEN_PANEL, { Size = target }):Play()
		TweenService:Create(launcher, TWEEN_BASE, { BackgroundTransparency = 0.4 }):Play()
	end

	local function closePanel()
		if not isOpen then
			return
		end
		isOpen = false

		local size = holder.Size
		local shrunk = UDim2.new(size.X.Scale * 0.92, size.X.Offset * 0.92, size.Y.Scale * 0.92, size.Y.Offset * 0.92)

		local tween = TweenService:Create(holder, TWEEN_BASE, { Size = shrunk })
		tween.Completed:Connect(function()
			if not isOpen then
				holder.Visible = false
				applyLayout()
			end
		end)
		tween:Play()

		TweenService:Create(launcher, TWEEN_BASE, { BackgroundTransparency = 0 }):Play()
	end

	local function togglePanel()
		if isOpen then
			closePanel()
		else
			openPanel()
		end
	end

	applyLayout()

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
	closeButton.Activated:Connect(closePanel)

	launcher.Activated:Connect(function()
		if launcher:GetAttribute("Dragged") then
			return
		end
		togglePanel()
	end)

	local espCategories = { "Players", "Enemies", "Items" }
	local espColors = {
		Players = THEME.EspPlayers,
		Enemies = THEME.EspEnemies,
		Items = THEME.EspItems,
	}
	local espEnabled = { Players = false, Enemies = false, Items = false }
	local espMaxDistance = CONFIG.Limits.EspDistance.default
	local espMarkers = {}
	local espCategoryOf = {}
	local espContainer = nil
	local espHeartbeat = nil
	local espRebuildTimer = 0
	local espUpdateTimer = 0

	local function espGetContainer()
		if espContainer and espContainer.Parent then
			return espContainer
		end
		local folder = Instance.new("Folder")
		folder.Name = ESP_FOLDER
		folder.Parent = LocalPlayer:WaitForChild("PlayerGui")
		espContainer = folder
		return folder
	end

	local function espAnchorPart(target)
		if target:IsA("BasePart") then
			return target
		end
		if target:IsA("Model") then
			local root = target:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				return root
			end
			return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
		end
		if target:IsA("Tool") then
			local handle = target:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				return handle
			end
			return target:FindFirstChildWhichIsA("BasePart")
		end
		return nil
	end

	local function espCreateMarker(target, category)
		local anchor = espAnchorPart(target)
		if not anchor then
			return nil
		end

		local color = espColors[category]
		local highlight = nil

		if target:IsA("Model") then
			highlight = Instance.new("Highlight")
			highlight.FillColor = color
			highlight.FillTransparency = 0.75
			highlight.OutlineColor = color
			highlight.OutlineTransparency = 0.1
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Adornee = target
			highlight.Parent = espGetContainer()
		end

		local billboard = Instance.new("BillboardGui")
		billboard.Adornee = anchor
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.fromOffset(180, 34)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.MaxDistance = espMaxDistance
		billboard.Parent = espGetContainer()

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = FONT_BODY
		text.TextSize = 13
		text.TextColor3 = color
		text.TextStrokeColor3 = THEME.Void
		text.TextStrokeTransparency = 0.2
		text.RichText = true
		text.Text = target.Name
		text.Parent = billboard

		return { highlight = highlight, billboard = billboard, label = text, adornee = anchor }
	end

	local function espRemoveMarker(target)
		local marker = espMarkers[target]
		if not marker then
			return
		end
		if marker.highlight then
			marker.highlight:Destroy()
		end
		marker.billboard:Destroy()
		espMarkers[target] = nil
		espCategoryOf[target] = nil
	end

	local function espCollect(category)
		local result = {}
		local seen = {}

		if category == "Players" then
			for _, player in Players:GetPlayers() do
				if player ~= LocalPlayer and player.Character then
					table.insert(result, player.Character)
				end
			end
			return result
		end

		local tag = if category == "Enemies" then CONFIG.EnemyTag else CONFIG.ItemTag

		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsDescendantOf(workspace) and not seen[instance] then
				seen[instance] = true
				table.insert(result, instance)
			end
		end

		if #result > 0 or not CONFIG.UseFallbackDetection then
			return result
		end

		if category == "Enemies" then
			for _, instance in workspace:GetDescendants() do
				if instance:IsA("Humanoid") then
					local model = instance.Parent
					if model and model:IsA("Model") and not seen[model] and not Players:GetPlayerFromCharacter(model) then
						seen[model] = true
						table.insert(result, model)
					end
				end
			end
		else
			for _, instance in workspace:GetChildren() do
				if instance:IsA("Tool") and not seen[instance] then
					seen[instance] = true
					table.insert(result, instance)
				end
			end
		end

		return result
	end

	local function espRebuild()
		for _, category in espCategories do
			if not espEnabled[category] then
				continue
			end

			local current = {}

			for _, target in espCollect(category) do
				current[target] = true
				if not espMarkers[target] then
					local marker = espCreateMarker(target, category)
					if marker then
						espMarkers[target] = marker
						espCategoryOf[target] = category
					end
				end
			end

			for target, targetCategory in espCategoryOf do
				if targetCategory == category and not current[target] then
					espRemoveMarker(target)
				end
			end
		end
	end

	local function espRefreshLabels()
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end

		local origin = root.Position

		for target, marker in espMarkers do
			if not target.Parent or not marker.adornee.Parent then
				espRemoveMarker(target)
				continue
			end

			local studs = math.floor((marker.adornee.Position - origin).Magnitude)

			if studs > espMaxDistance then
				marker.billboard.Enabled = false
				if marker.highlight then
					marker.highlight.Enabled = false
				end
				continue
			end

			marker.billboard.Enabled = true
			if marker.highlight then
				marker.highlight.Enabled = true
			end

			local health = ""
			if target:IsA("Model") then
				local humanoid = target:FindFirstChildOfClass("Humanoid")
				if humanoid then
					health = string.format("  ·  %d hp", math.floor(humanoid.Health))
				end
			end

			marker.label.Text = string.format('%s\n<font size="11">%d studs%s</font>', target.Name, studs, health)
		end
	end

	local function espEnsureLoop()
		local anyEnabled = false
		for _, category in espCategories do
			if espEnabled[category] then
				anyEnabled = true
				break
			end
		end

		if anyEnabled then
			if espHeartbeat then
				return
			end
			espHeartbeat = RunService.Heartbeat:Connect(function(delta)
				espRebuildTimer += delta
				espUpdateTimer += delta

				if espRebuildTimer >= 0.5 then
					espRebuildTimer = 0
					espRebuild()
				end

				if espUpdateTimer >= 0.1 then
					espUpdateTimer = 0
					espRefreshLabels()
				end
			end)
			espRebuild()
		elseif espHeartbeat then
			espHeartbeat:Disconnect()
			espHeartbeat = nil
		end
	end

	local function espSet(category, on)
		if espEnabled[category] == on then
			return
		end
		espEnabled[category] = on

		if not on then
			for target, targetCategory in espCategoryOf do
				if targetCategory == category then
					espRemoveMarker(target)
				end
			end
		end

		espEnsureLoop()
	end

	local flyActive = false
	local flySpeed = CONFIG.Limits.FlySpeed.default
	local flyVertical = 0
	local flyAttachment = nil
	local flyVelocity = nil
	local flyStep = nil
	local flyPad = nil

	local function flyGetParts()
		local character = LocalPlayer.Character
		if not character then
			return nil, nil
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and not root:IsA("BasePart") then
			root = nil
		end
		return humanoid, root
	end

	local function flyDetach()
		if flyStep then
			flyStep:Disconnect()
			flyStep = nil
		end
		if flyVelocity then
			flyVelocity:Destroy()
			flyVelocity = nil
		end
		if flyAttachment then
			flyAttachment:Destroy()
			flyAttachment = nil
		end
	end

	local function flyAttach()
		local humanoid, root = flyGetParts()
		if not humanoid or not root then
			return
		end

		flyDetach()

		flyAttachment = Instance.new("Attachment")
		flyAttachment.Name = "DevFlyAttachment"
		flyAttachment.Parent = root

		flyVelocity = Instance.new("LinearVelocity")
		flyVelocity.Name = "DevFlyVelocity"
		flyVelocity.Attachment0 = flyAttachment
		flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		flyVelocity.MaxForce = math.huge
		flyVelocity.VectorVelocity = Vector3.zero
		flyVelocity.Parent = root

		local velocity = flyVelocity

		flyStep = RunService.RenderStepped:Connect(function()
			if not flyActive or not velocity.Parent then
				return
			end

			local currentHumanoid = flyGetParts()
			if not currentHumanoid then
				return
			end

			local horizontal = currentHumanoid.MoveDirection * flySpeed
			velocity.VectorVelocity = Vector3.new(horizontal.X, flyVertical * flySpeed, horizontal.Z)
		end)
	end

	local function flyBuildPad()
		if flyPad or not UserInputService.TouchEnabled then
			return
		end

		local pad = Instance.new("Frame")
		pad.Name = "FlyPad"
		pad.AnchorPoint = Vector2.new(1, 1)
		pad.Position = UDim2.new(1, -24, 1, -140)
		pad.Size = UDim2.fromOffset(64, 140)
		pad.BackgroundTransparency = 1
		pad.ZIndex = 15
		pad.Parent = gui

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 12)
		layout.Parent = pad

		local function makeButton(glyph, direction, order)
			local button = Instance.new("TextButton")
			button.Size = UDim2.fromOffset(64, 64)
			button.BackgroundColor3 = THEME.Navy
			button.BackgroundTransparency = 0.15
			button.BorderSizePixel = 0
			button.AutoButtonColor = false
			button.Text = glyph
			button.TextSize = 24
			button.Font = FONT_DISPLAY
			button.TextColor3 = THEME.Text
			button.LayoutOrder = order
			button.ZIndex = 16
			button.Parent = pad

			corner(button, UDim.new(0, 20))
			stroke(button, 0.5, 1.5)

			button.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					flyVertical = direction
					button.BackgroundTransparency = 0
				end
			end)

			button.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					if flyVertical == direction then
						flyVertical = 0
					end
					button.BackgroundTransparency = 0.15
				end
			end)
		end

		makeButton("▲", 1, 1)
		makeButton("▼", -1, 2)

		flyPad = pad
	end

	local function flySetActive(on)
		if on and not LocalPlayer:GetAttribute("DevFlyAllowed") then
			return false
		end

		if flyActive == on then
			return true
		end

		flyActive = on
		flyVertical = 0

		if on then
			flyAttach()
			flyBuildPad()
		else
			flyDetach()
			if flyPad then
				flyPad:Destroy()
				flyPad = nil
			end
		end

		return true
	end

	local clickTeleportActive = false
	local clickTeleportPending = {}

	local function clickTeleportPing(position)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Neon
		part.Color = THEME.Accent
		part.Size = Vector3.new(1.5, 1.5, 1.5)
		part.Position = position
		part.Transparency = 0.2
		part.Parent = workspace

		local tween = TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(6, 6, 6),
			Transparency = 1,
		})
		tween.Completed:Connect(function()
			part:Destroy()
		end)
		tween:Play()
	end

	local function clickTeleportTry(position)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		local ray = camera:ViewportPointToRay(position.X, position.Y)

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = false
		params.FilterDescendantsInstances = if LocalPlayer.Character then { LocalPlayer.Character } else {}

		local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
		if not result then
			return
		end

		clickTeleportPing(result.Position)
		send(ACTION.Teleport, { position = result.Position })
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if clickTeleportActive and not processed and input.UserInputType == Enum.UserInputType.Touch then
			clickTeleportPending[input] = input.Position
		end

		if not processed and input.KeyCode == CONFIG.ToggleKey then
			togglePanel()
		end

		if flyActive and not processed then
			if input.KeyCode == Enum.KeyCode.Space then
				flyVertical = 1
			elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.LeftShift then
				flyVertical = -1
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, processed)
		if flyActive then
			if input.KeyCode == Enum.KeyCode.Space and flyVertical == 1 then
				flyVertical = 0
			elseif (input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.LeftShift) and flyVertical == -1 then
				flyVertical = 0
			end
		end

		if not clickTeleportActive then
			return
		end

		if input.UserInputType == Enum.UserInputType.Touch then
			local start = clickTeleportPending[input]
			clickTeleportPending[input] = nil

			if processed or not start then
				return
			end

			local moved = (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(start.X, start.Y)).Magnitude
			if moved <= 12 then
				clickTeleportTry(input.Position)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			clickTeleportTry(input.Position)
		end
	end)

	LocalPlayer.CharacterAdded:Connect(function()
		if flyActive then
			task.wait(0.4)
			if flyActive then
				flyAttach()
			end
		end
	end)

	LocalPlayer:GetAttributeChangedSignal("DevFlyAllowed"):Connect(function()
		if flyActive and not LocalPlayer:GetAttribute("DevFlyAllowed") then
			flySetActive(false)
		end
	end)

	LocalPlayer:GetAttributeChangedSignal("DevFlySpeed"):Connect(function()
		local value = LocalPlayer:GetAttribute("DevFlySpeed")
		if typeof(value) == "number" then
			flySpeed = value
		end
	end)

	stateRemote.OnClientEvent:Connect(function(state)
		if typeof(state) ~= "table" then
			return
		end
		if state.numbers and typeof(state.numbers.FlySpeed) == "number" then
			flySpeed = state.numbers.FlySpeed
		end
	end)

	local movementTab = addTab("Движение")
	local playerTab = addTab("Игрок")
	local worldTab = addTab("Мир")
	local espTab = addTab("ESP")
	local teleportTab = addTab("Телепорт")
	local playersTab = addTab("Игроки")

	sectionLabel(movementTab, "Перемещение", 1)

	local movementCard = card(movementTab, 2)

	local flyToggle
	flyToggle = toggleRow(movementCard, {
		title = "Полёт",
		subtitle = "Реальная физика, видят все игроки",
		order = 1,
		onChanged = function(on)
			send(ACTION.SetToggle, { key = TOGGLE.Fly, value = on })

			if not on then
				flySetActive(false)
				return
			end

			task.spawn(function()
				local deadline = os.clock() + 2
				while os.clock() < deadline and not LocalPlayer:GetAttribute("DevFlyAllowed") do
					task.wait(0.05)
				end

				if LocalPlayer:GetAttribute("DevFlyAllowed") then
					flySetActive(true)
					setStatus("Полёт включён, стик и кнопки вверх/вниз")
				else
					flyToggle.set(false, true)
					setStatus("Сервер не выдал разрешение на полёт", true)
				end
			end)
		end,
	})

	toggleRow(movementCard, {
		title = "Проход сквозь стены",
		subtitle = "Включайте вместе с полётом",
		order = 2,
		onChanged = function(on)
			send(ACTION.SetToggle, { key = TOGGLE.Noclip, value = on })
			if on and not flyActive then
				setStatus("Без полёта вы провалитесь сквозь пол", true)
			end
		end,
	})

	sectionLabel(movementTab, "Параметры", 3)

	local speedCard = card(movementTab, 4)

	sliderRow(speedCard, {
		title = "Скорость бега",
		min = CONFIG.Limits.WalkSpeed.min,
		max = CONFIG.Limits.WalkSpeed.max,
		value = CONFIG.Limits.WalkSpeed.default,
		order = 1,
		onChanged = function(value)
			sendNumber(NUMBER.WalkSpeed, value)
		end,
	})

	sliderRow(speedCard, {
		title = "Сила прыжка",
		min = CONFIG.Limits.JumpPower.min,
		max = CONFIG.Limits.JumpPower.max,
		value = CONFIG.Limits.JumpPower.default,
		order = 2,
		onChanged = function(value)
			sendNumber(NUMBER.JumpPower, value)
		end,
	})

	sliderRow(speedCard, {
		title = "Скорость полёта",
		min = CONFIG.Limits.FlySpeed.min,
		max = CONFIG.Limits.FlySpeed.max,
		value = CONFIG.Limits.FlySpeed.default,
		order = 3,
		onChanged = function(value)
			flySpeed = value
			sendNumber(NUMBER.FlySpeed, value)
		end,
	})

	sectionLabel(playerTab, "Состояние", 1)

	local playerCard = card(playerTab, 2)

	toggleRow(playerCard, {
		title = "Бессмертие",
		subtitle = "Здоровье восстанавливается сервером",
		order = 1,
		onChanged = function(on)
			send(ACTION.SetToggle, { key = TOGGLE.Godmode, value = on })
		end,
	})

	toggleRow(playerCard, {
		title = "Бесконечные предметы",
		subtitle = "Флаг " .. CONFIG.Flags.InfiniteItems .. ", применяет ваш код",
		order = 2,
		onChanged = function(on)
			send(ACTION.SetToggle, { key = TOGGLE.InfiniteItems, value = on })
		end,
	})

	toggleRow(playerCard, {
		title = "Без перезарядки",
		subtitle = "Флаг " .. CONFIG.Flags.NoReload .. ", применяет ваш код",
		order = 3,
		onChanged = function(on)
			send(ACTION.SetToggle, { key = TOGGLE.NoReload, value = on })
		end,
	})

	sectionLabel(playerTab, "Действия", 3)

	buttonRow(playerTab, {
		title = "Респавн",
		subtitle = "Пересобрать персонажа с текущими настройками",
		order = 4,
		onClick = function()
			send(ACTION.Respawn)
			setStatus("Респавн отправлен")
		end,
	})

	sectionLabel(worldTab, "NPC", 1)

	local worldCard = card(worldTab, 2)

	toggleRow(worldCard, {
		title = "Заморозить всех NPC",
		subtitle = "Общее на сервер, тег " .. CONFIG.EnemyTag,
		order = 1,
		onChanged = function(on)
			send(ACTION.SetToggle, { key = TOGGLE.FreezeEnemies, value = on })
			setStatus(if on then "NPC остановлены" else "NPC отпущены")
		end,
	})

	local worldHint = label(
		worldTab,
		"Повесьте тег <b>" .. CONFIG.EnemyTag .. "</b> на модели NPC через Tag Editor в Studio, тогда заморозка и ESP найдут их точно, а не эвристикой.",
		12,
		FONT_BODY,
		THEME.TextFaint
	)
	worldHint.Size = UDim2.new(1, 0, 0, 54)
	worldHint.TextWrapped = true
	worldHint.TextYAlignment = Enum.TextYAlignment.Top
	worldHint.LayoutOrder = 3

	sectionLabel(espTab, "Подсветка", 1)

	local espCard = card(espTab, 2)

	toggleRow(espCard, {
		title = "Игроки",
		subtitle = "Имя, дистанция, здоровье",
		order = 1,
		onChanged = function(on)
			espSet("Players", on)
		end,
	})

	toggleRow(espCard, {
		title = "NPC",
		subtitle = "Тег " .. CONFIG.EnemyTag,
		order = 2,
		onChanged = function(on)
			espSet("Enemies", on)
		end,
	})

	toggleRow(espCard, {
		title = "Предметы",
		subtitle = "Тег " .. CONFIG.ItemTag,
		order = 3,
		onChanged = function(on)
			espSet("Items", on)
		end,
	})

	local espRangeCard = card(espTab, 3)

	sliderRow(espRangeCard, {
		title = "Дальность",
		min = CONFIG.Limits.EspDistance.min,
		max = CONFIG.Limits.EspDistance.max,
		value = CONFIG.Limits.EspDistance.default,
		step = 50,
		suffix = " st",
		order = 1,
		onChanged = function(value)
			espMaxDistance = value
			for _, marker in espMarkers do
				marker.billboard.MaxDistance = value
			end
		end,
	})

	sectionLabel(teleportTab, "По тапу", 1)

	local clickCard = card(teleportTab, 2)

	toggleRow(clickCard, {
		title = "Телепорт по тапу",
		subtitle = "Тапните по точке мира, окажетесь там",
		order = 1,
		onChanged = function(on)
			clickTeleportActive = on
			table.clear(clickTeleportPending)
			if on then
				setStatus("Закройте панель и тапните по карте")
			end
		end,
	})

	sectionLabel(teleportTab, "Локации", 3)

	local locationsList = Instance.new("Frame")
	locationsList.Size = UDim2.new(1, 0, 0, 0)
	locationsList.AutomaticSize = Enum.AutomaticSize.Y
	locationsList.BackgroundTransparency = 1
	locationsList.LayoutOrder = 4
	locationsList.Parent = teleportTab

	local locationsLayout = Instance.new("UIListLayout")
	locationsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	locationsLayout.Padding = UDim.new(0, 8)
	locationsLayout.Parent = locationsList

	local sessionSpots = {}

	local function rebuildLocations()
		for _, child in locationsList:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local order = 0

		for _, location in CONFIG.Locations do
			order += 1
			buttonRow(locationsList, {
				title = location.Name,
				subtitle = string.format("%d, %d, %d", location.Position.X, location.Position.Y, location.Position.Z),
				order = order,
				onClick = function()
					send(ACTION.TeleportToLocation, { name = location.Name })
					setStatus("Телепорт: " .. location.Name)
				end,
			})
		end

		for _, spot in sessionSpots do
			order += 1
			buttonRow(locationsList, {
				title = spot.Name,
				subtitle = "Точка этой сессии",
				order = order,
				onClick = function()
					send(ACTION.Teleport, { position = spot.Position })
					setStatus("Телепорт: " .. spot.Name)
				end,
			})
		end
	end

	rebuildLocations()

	buttonRow(teleportTab, {
		title = "Запомнить точку",
		subtitle = "Добавит текущую позицию в список и напечатает её в Output",
		accent = true,
		order = 5,
		onClick = function()
			local character = LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")

			if not root or not root:IsA("BasePart") then
				setStatus("Персонаж не готов", true)
				return
			end

			local position = root.Position
			local name = string.format("Точка %d", #sessionSpots + 1)
			table.insert(sessionSpots, { Name = name, Position = position })
			rebuildLocations()

			print(string.format(
				'[DevToolkit] { Name = "%s", Position = Vector3.new(%.1f, %.1f, %.1f) },',
				name,
				position.X,
				position.Y,
				position.Z
			))

			setStatus(name .. " сохранена, строка в Output")
		end,
	})

	local playersHeader = sectionLabel(playersTab, "В сервере", 1)

	local playersList = Instance.new("Frame")
	playersList.Size = UDim2.new(1, 0, 0, 0)
	playersList.AutomaticSize = Enum.AutomaticSize.Y
	playersList.BackgroundTransparency = 1
	playersList.LayoutOrder = 2
	playersList.Parent = playersTab

	local playersLayout = Instance.new("UIListLayout")
	playersLayout.SortOrder = Enum.SortOrder.LayoutOrder
	playersLayout.Padding = UDim.new(0, 8)
	playersLayout.Parent = playersList

	local function rebuildPlayers()
		for _, child in playersList:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local others = {}
		for _, player in Players:GetPlayers() do
			if player ~= LocalPlayer then
				table.insert(others, player)
			end
		end

		playersHeader.Text = string.upper(string.format("В сервере · %d", #others))

		if #others == 0 then
			local empty = label(playersList, "Кроме вас никого нет.", 13, FONT_BODY, THEME.TextFaint)
			empty.Size = UDim2.new(1, 0, 0, 40)
			return
		end

		for index, player in others do
			buttonRow(playersList, {
				title = player.DisplayName,
				subtitle = "@" .. player.Name,
				order = index,
				onClick = function()
					send(ACTION.TeleportToPlayer, { userId = player.UserId })
					setStatus("Телепорт к " .. player.DisplayName)
				end,
			})
		end
	end

	rebuildPlayers()

	Players.PlayerAdded:Connect(rebuildPlayers)
	Players.PlayerRemoving:Connect(function()
		task.defer(rebuildPlayers)
	end)

	setStatus("Панель готова")
end

if RunService:IsServer() then
	runServer()
else
	runClient()
end
