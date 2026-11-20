-- Brainrot Rush: server entry point.
-- Builds the world (belt + 6 player bases), spawns brainrots on a conveyor,
-- handles buying/selling/rebirths, passive income, surge events and saving.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local Factory = require(script.Parent:WaitForChild("BrainrotFactory"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

Players.CharacterAutoLoads = false

local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(90, 255, 120)
local GOLD = Color3.fromRGB(255, 220, 80)

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local notifyRemote = makeRemote("Notify") -- server -> client (text, color)
local surgeRemote = makeRemote("Surge") -- server -> client (active, seconds)
local rebirthRemote = makeRemote("Rebirth") -- client -> server

local function notify(player, text, color)
	notifyRemote:FireClient(player, text, color or Color3.new(1, 1, 1))
end

local function notifyAll(text, color)
	notifyRemote:FireAllClients(text, color or Color3.new(1, 1, 1))
end

---------------------------------------------------------------------------
-- World
---------------------------------------------------------------------------
local world = Instance.new("Folder")
world.Name = "World"
world.Parent = Workspace

local function newPart(name, size, cframe, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

newPart("Ground", Vector3.new(460, 1, 340), CFrame.new(0, -0.5, 0), Color3.fromRGB(70, 160, 90), Enum.Material.Grass, world)

local BELT_START = -150
local BELT_END = 150
local BELT_SPEED = 9
local BELT_TOP = 0.6

newPart("Belt", Vector3.new(320, 0.6, 10), CFrame.new(0, 0.3, 0), Color3.fromRGB(45, 45, 50), Enum.Material.Metal, world)
for _, z in ipairs({ -5.2, 5.2 }) do
	newPart("BeltEdge", Vector3.new(320, 0.7, 0.4), CFrame.new(0, 0.35, z), Color3.fromRGB(255, 60, 200), Enum.Material.Neon, world)
end

local PLOT_COUNT = 6
local PLOT_SIZE = Vector3.new(64, 0.5, 46)
local plots = {}

for i = 1, PLOT_COUNT do
	local col = (i - 1) % 3
	local row = (i <= 3) and -1 or 1
	local center = Vector3.new((col - 1) * 100, 0, row * 70)

	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. i
	folder.Parent = world

	newPart("Base", PLOT_SIZE, CFrame.new(center + Vector3.new(0, 0.25, 0)), Color3.fromRGB(60, 60, 78), Enum.Material.Concrete, folder)

	local slotCFrames = {}
	for r = 1, 2 do
		for c = 1, 5 do
			local index = (r - 1) * 5 + c
			local pos = center + Vector3.new((c - 3) * 11, 0, (r == 1) and -9 or 9)
			newPart("SlotPad", Vector3.new(8, 0.2, 8), CFrame.new(pos.X, 0.6, pos.Z), Color3.fromRGB(30, 30, 40), Enum.Material.Neon, folder)
			slotCFrames[index] = CFrame.new(pos.X, 0.7, pos.Z)
		end
	end

	-- Brainrots face the belt.
	local facing = CFrame.Angles(0, (row == -1) and math.pi or 0, 0)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(center.X, 0.75, center.Z - row * 19)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 0.6
	spawn.Parent = folder

	local signPart = newPart("Sign", Vector3.new(12, 1, 1), CFrame.new(center.X, 9, center.Z + row * 22), Color3.new(1, 1, 1), nil, folder)
	signPart.Transparency = 1
	signPart.CanCollide = false
	local signGui = Instance.new("BillboardGui")
	signGui.Size = UDim2.fromOffset(300, 60)
	signGui.AlwaysOnTop = true
	signGui.MaxDistance = 200
	signGui.Adornee = signPart
	signGui.Parent = signPart
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.GothamBlack
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.new(1, 1, 1)
	signLabel.TextStrokeTransparency = 0
	signLabel.Text = "Free Base"
	signLabel.Parent = signGui

	plots[i] = {
		Folder = folder,
		Slots = slotCFrames,
		Facing = facing,
		Spawn = spawn,
		Sign = signLabel,
		Owner = nil,
	}
end

---------------------------------------------------------------------------
-- Player state
---------------------------------------------------------------------------
local states = {}

local function setCoins(player, st, amount)
	st.Data.Coins = amount
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Coins") then
		ls.Coins.Value = math.floor(amount)
	end
end

local function recalcIncome(player)
	local st = states[player]
	if not st then
		return
	end
	local total = 0
	for _, spec in pairs(st.Data.Slots) do
		total += BrainrotData.incomeOf(spec)
	end
	st.IncomePerSec = total * BrainrotData.multiplier(st.Data.Rebirths)
	player:SetAttribute("IncomePerSec", st.IncomePerSec)
end

local function sellBrainrot(player, index)
	local st = states[player]
	if not st then
		return
	end
	local key = tostring(index)
	local spec = st.Data.Slots[key]
	if not spec then
		return
	end
	st.Data.Slots[key] = nil
	local model = st.Models[index]
	if model then
		model:Destroy()
		st.Models[index] = nil
	end
	local value = BrainrotData.sellValue(spec)
	setCoins(player, st, st.Data.Coins + value)
	recalcIncome(player)
	notify(player, "Sold " .. spec.Name .. " for $" .. BrainrotData.format(value), GOLD)
end

local function placeBrainrot(player, st, index, spec)
	local model = Factory.build(spec, "owned")
	local cf = st.Plot.Slots[index] * st.Plot.Facing * CFrame.new(0, model:GetAttribute("Height") / 2, 0)
	model:PivotTo(cf)
	model:SetAttribute("BaseCFrame", cf)
	model:SetAttribute("Slot", index)
	model.Parent = st.Plot.Folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sell ($" .. BrainrotData.format(BrainrotData.sellValue(spec)) .. ")"
	prompt.ObjectText = spec.Name
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(who)
		if who == player then
			sellBrainrot(player, index)
		end
	end)

	st.Models[index] = model
end

---------------------------------------------------------------------------
-- Conveyor + buying
---------------------------------------------------------------------------
local rng = Random.new()
local items = {}
local surgeUntil = 0
local FACE_FORWARD = CFrame.Angles(0, -math.pi / 2, 0)

local function tryBuy(player, item)
	local st = states[player]
	if not st or item.Bought then
		return
	end

	local price = BrainrotData.priceOf(item.Spec)
	if st.Data.Coins < price then
		notify(player, "Not enough coins! Need $" .. BrainrotData.format(price), RED)
		return
	end

	local slot
	for i = 1, BrainrotData.MAX_SLOTS do
		if not st.Data.Slots[tostring(i)] then
			slot = i
			break
		end
	end
	if not slot then
		notify(player, "Your base is full! Sell one first (hold F).", RED)
		return
	end

	item.Bought = true
	setCoins(player, st, st.Data.Coins - price)
	st.Data.Slots[tostring(slot)] = item.Spec
	placeBrainrot(player, st, slot, item.Spec)
	recalcIncome(player)

	notify(player, "Bought " .. item.Spec.Name .. "!", GREEN)
	local fancy = BrainrotData.rarityIndex(item.Spec.Rarity) >= 4 or item.Spec.Mutation ~= "Normal"
	if fancy then
		local label = item.Spec.Rarity
		if item.Spec.Mutation ~= "Normal" then
			label = item.Spec.Mutation .. " " .. label
		end
		notifyAll(player.DisplayName .. " got a " .. label .. " " .. item.Spec.Name .. "!", GOLD)
	end
end

local function spawnItem()
	local luck = (os.clock() < surgeUntil) and 4 or 1
	local spec = BrainrotData.roll(rng, luck)
	local model = Factory.build(spec, "shop")
	local y = BELT_TOP + model:GetAttribute("Height") / 2

	local item = { Model = model, Spec = spec, X = BELT_START, Y = y, Bought = false }
	model:PivotTo(CFrame.new(item.X, y, 0) * FACE_FORWARD)
	model.Parent = world

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy ($" .. BrainrotData.format(BrainrotData.priceOf(spec)) .. ")"
	prompt.ObjectText = spec.Name
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		tryBuy(player, item)
	end)

	table.insert(items, item)
end

RunService.Heartbeat:Connect(function(dt)
	for i = #items, 1, -1 do
		local item = items[i]
		item.X += BELT_SPEED * dt
		if item.Bought or item.X > BELT_END then
			item.Model:Destroy()
			table.remove(items, i)
		else
			item.Model:PivotTo(CFrame.new(item.X, item.Y, 0) * FACE_FORWARD)
		end
	end
end)

task.spawn(function()
	while true do
		spawnItem()
		task.wait((os.clock() < surgeUntil) and 1.2 or 3)
	end
end)

-- Surge event: faster belt spawns and better odds for 30s every 2.5 minutes.
task.spawn(function()
	while true do
		task.wait(150)
		surgeUntil = os.clock() + 30
		surgeRemote:FireAllClients(true, 30)
		notifyAll("BRAINROT SURGE! Better odds for 30 seconds!", Color3.fromRGB(255, 100, 255))
		task.wait(30)
		surgeRemote:FireAllClients(false, 0)
	end
end)

-- Passive income
task.spawn(function()
	while true do
		task.wait(1)
		for player, st in pairs(states) do
			if st.IncomePerSec > 0 then
				setCoins(player, st, st.Data.Coins + st.IncomePerSec)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Rebirth
---------------------------------------------------------------------------
rebirthRemote.OnServerEvent:Connect(function(player)
	local st = states[player]
	if not st then
		return
	end
	local cost = BrainrotData.rebirthCost(st.Data.Rebirths)
	if st.Data.Coins < cost then
		notify(player, "Need $" .. BrainrotData.format(cost) .. " to rebirth!", RED)
		return
	end
	st.Data.Rebirths += 1
	setCoins(player, st, 0)
	player.leaderstats.Rebirths.Value = st.Data.Rebirths
	recalcIncome(player)
	notifyAll(player.DisplayName .. " REBIRTHED! (x" .. BrainrotData.multiplier(st.Data.Rebirths) .. " income)", Color3.fromRGB(255, 100, 255))
end)

---------------------------------------------------------------------------
-- Player lifecycle
---------------------------------------------------------------------------
local function claimPlot(player)
	for _, plot in ipairs(plots) do
		if not plot.Owner then
			plot.Owner = player
			return plot
		end
	end
	return nil
end

local function setupPlayer(player)
	local plot = claimPlot(player)
	if not plot then
		player:Kick("This server is full (6 players). Join another one!")
		return
	end

	local data = PlayerData.load(player)
	if not player.Parent then
		plot.Owner = nil
		return
	end

	local st = { Data = data, Plot = plot, Models = {}, IncomePerSec = 0 }
	states[player] = st

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("NumberValue")
	coins.Name = "Coins"
	coins.Value = math.floor(data.Coins)
	coins.Parent = ls
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.Rebirths
	rebirths.Parent = ls
	ls.Parent = player

	player.RespawnLocation = plot.Spawn
	plot.Sign.Text = player.DisplayName .. "'s Base"

	for key, spec in pairs(data.Slots) do
		local index = tonumber(key)
		if index and index >= 1 and index <= BrainrotData.MAX_SLOTS then
			placeBrainrot(player, st, index, spec)
		end
	end
	recalcIncome(player)

	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			task.wait(3)
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end)
	player:LoadCharacter()
end

local function cleanupPlayer(player)
	local st = states[player]
	if st then
		PlayerData.save(player, st.Data)
		for _, model in pairs(st.Models) do
			model:Destroy()
		end
		st.Plot.Owner = nil
		st.Plot.Sign.Text = "Free Base"
		states[player] = nil
	else
		for _, plot in ipairs(plots) do
			if plot.Owner == player then
				plot.Owner = nil
			end
		end
	end
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

-- Autosave
task.spawn(function()
	while true do
		task.wait(60)
		for player, st in pairs(states) do
			task.spawn(PlayerData.save, player, st.Data)
		end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() then
		return
	end
	local pending = 0
	for player, st in pairs(states) do
		pending += 1
		task.spawn(function()
			PlayerData.save(player, st.Data)
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait()
	end
end)
