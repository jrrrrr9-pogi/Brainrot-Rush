-- Builds a brainrot character Model out of plain Parts (no external assets).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))

local Factory = {}

local function makePart(parent, name, shape, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeLabel(parent, text, color, yScale, heightScale)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, heightScale)
	l.Position = UDim2.fromScale(0, yScale)
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.TextStrokeTransparency = 0
	l.Parent = parent
	return l
end

-- mode: "shop" (on the conveyor, shows price) or "owned" (in a base, shows income)
function Factory.build(spec, mode)
	local rarity = BrainrotData.getRarity(spec.Rarity)
	local mutation = BrainrotData.getMutation(spec.Mutation)
	local rng = Random.new(spec.Seed)
	local s = rarity.Scale

	local model = Instance.new("Model")
	model.Name = spec.Name

	local bodyColor = Color3.fromHSV(rng:NextNumber(), 0.55, 0.95)
	local material = Enum.Material.SmoothPlastic
	if spec.Mutation == "Golden" then
		bodyColor = Color3.fromRGB(255, 200, 40)
		material = Enum.Material.Metal
	elseif spec.Mutation == "Rainbow" then
		bodyColor = Color3.fromRGB(255, 80, 80)
		material = Enum.Material.Neon
	end

	local d = 3.4 * s
	local body = makePart(model, "Body", Enum.PartType.Ball, Vector3.new(d, d, d), bodyColor, material)
	body.CFrame = CFrame.new(0, 0, 0)
	model.PrimaryPart = body

	-- Eyes (front is -Z)
	local eyeSize = 0.95 * s
	local pupilSize = 0.4 * s
	local crossEyed = rng:NextNumber() < 0.4
	for _, side in ipairs({ -1, 1 }) do
		local eye = makePart(
			model, "Eye", Enum.PartType.Ball,
			Vector3.new(eyeSize, eyeSize, eyeSize), Color3.new(1, 1, 1)
		)
		eye.CFrame = CFrame.new(side * 0.6 * s, 0.45 * s, -1.45 * s)
		local px = side * 0.6 * s
		if crossEyed then
			px = side * 0.3 * s
		end
		local pupil = makePart(
			model, "Pupil", Enum.PartType.Ball,
			Vector3.new(pupilSize, pupilSize, pupilSize), Color3.new(0, 0, 0)
		)
		pupil.CFrame = CFrame.new(px, 0.45 * s, -1.82 * s)
	end

	-- Mouth
	local mouth = makePart(
		model, "Mouth", Enum.PartType.Block,
		Vector3.new(1.1 * s, 0.25 * s, 0.2 * s), Color3.fromRGB(40, 20, 20)
	)
	mouth.CFrame = CFrame.new(0, -0.5 * s, -1.6 * s)

	-- Random accessory
	local accessory = rng:NextInteger(1, 3)
	if accessory == 1 then
		local antenna = makePart(
			model, "Antenna", Enum.PartType.Block,
			Vector3.new(0.15 * s, 1.2 * s, 0.15 * s), Color3.fromRGB(60, 60, 60)
		)
		antenna.CFrame = CFrame.new(0, 1.7 * s + 0.5 * s, 0)
		local tip = makePart(
			model, "Tip", Enum.PartType.Ball,
			Vector3.new(0.5 * s, 0.5 * s, 0.5 * s), Color3.fromRGB(255, 60, 60), Enum.Material.Neon
		)
		tip.CFrame = CFrame.new(0, 1.7 * s + 1.15 * s, 0)
	elseif accessory == 2 then
		for _, side in ipairs({ -1, 1 }) do
			local horn = makePart(
				model, "Horn", Enum.PartType.Block,
				Vector3.new(0.3 * s, 1 * s, 0.3 * s), Color3.fromRGB(245, 235, 210)
			)
			horn.CFrame = CFrame.new(side * 0.8 * s, 1.6 * s, 0) * CFrame.Angles(0, 0, -side * 0.5)
		end
	end

	-- Name / info billboard
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 66)
	gui.StudsOffset = Vector3.new(0, d / 2 + 2.4, 0)
	gui.MaxDistance = 80
	gui.Adornee = body
	gui.Parent = body

	makeLabel(gui, spec.Name, rarity.Color, 0, 0.38)

	local rarityText = rarity.Name
	if spec.Mutation ~= "Normal" then
		rarityText = spec.Mutation .. " " .. rarityText
	end
	makeLabel(gui, rarityText, rarity.Color, 0.38, 0.28)

	local income = BrainrotData.incomeOf(spec)
	local infoText = "+$" .. BrainrotData.format(income) .. "/s"
	if mode == "shop" then
		infoText = "$" .. BrainrotData.format(BrainrotData.priceOf(spec)) .. "  |  " .. infoText
	end
	makeLabel(gui, infoText, Color3.fromRGB(255, 240, 150), 0.66, 0.34)

	model:SetAttribute("Height", d)
	model:SetAttribute("Rarity", spec.Rarity)
	model:SetAttribute("Mutation", spec.Mutation)
	CollectionService:AddTag(model, "Brainrot")

	return model
end

return Factory
