-- Brainrot Rush: client UI, toasts, surge banner and brainrot animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function round(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = obj
end

---------------------------------------------------------------------------
-- Stats panel
---------------------------------------------------------------------------
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(250, 84)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
panel.BackgroundTransparency = 0.2
panel.Parent = gui
round(panel, 12)

local coinsLabel = Instance.new("TextLabel")
coinsLabel.Size = UDim2.new(1, -16, 0, 44)
coinsLabel.Position = UDim2.fromOffset(8, 4)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Font = Enum.Font.GothamBlack
coinsLabel.TextScaled = true
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.TextColor3 = Color3.fromRGB(255, 225, 90)
coinsLabel.Text = "$0"
coinsLabel.Parent = panel

local incomeLabel = Instance.new("TextLabel")
incomeLabel.Size = UDim2.new(1, -16, 0, 28)
incomeLabel.Position = UDim2.fromOffset(8, 48)
incomeLabel.BackgroundTransparency = 1
incomeLabel.Font = Enum.Font.GothamBold
incomeLabel.TextScaled = true
incomeLabel.TextXAlignment = Enum.TextXAlignment.Left
incomeLabel.TextColor3 = Color3.fromRGB(150, 255, 170)
incomeLabel.Text = "+$0/s"
incomeLabel.Parent = panel

---------------------------------------------------------------------------
-- Rebirth button
---------------------------------------------------------------------------
local rebirthButton = Instance.new("TextButton")
rebirthButton.Size = UDim2.fromOffset(300, 54)
rebirthButton.AnchorPoint = Vector2.new(0.5, 1)
rebirthButton.Position = UDim2.new(0.5, 0, 1, -16)
rebirthButton.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
rebirthButton.Font = Enum.Font.GothamBlack
rebirthButton.TextScaled = true
rebirthButton.TextColor3 = Color3.new(1, 1, 1)
rebirthButton.Text = "REBIRTH"
rebirthButton.Parent = gui
round(rebirthButton, 12)

rebirthButton.MouseButton1Click:Connect(function()
	remotes.Rebirth:FireServer()
end)

---------------------------------------------------------------------------
-- Toasts + surge banner
---------------------------------------------------------------------------
local toastHolder = Instance.new("Frame")
toastHolder.Size = UDim2.fromOffset(460, 200)
toastHolder.AnchorPoint = Vector2.new(0.5, 0)
toastHolder.Position = UDim2.new(0.5, 0, 0, 12)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = toastHolder

local toastCount = 0
local function toast(text, color)
	toastCount += 1
	local label = Instance.new("TextLabel")
	label.LayoutOrder = toastCount
	label.Size = UDim2.new(1, 0, 0, 32)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = toastHolder
	round(label, 8)

	task.delay(3.5, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.5), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

remotes.Notify.OnClientEvent:Connect(toast)

local banner = Instance.new("TextLabel")
banner.Size = UDim2.fromOffset(420, 40)
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 220)
banner.BackgroundColor3 = Color3.fromRGB(180, 40, 200)
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.TextColor3 = Color3.new(1, 1, 1)
banner.Visible = false
banner.Parent = gui
round(banner, 10)

local surgeEndsAt = 0
remotes.Surge.OnClientEvent:Connect(function(active, seconds)
	if active then
		surgeEndsAt = os.clock() + seconds
		banner.Visible = true
	else
		surgeEndsAt = 0
		banner.Visible = false
	end
end)

---------------------------------------------------------------------------
-- Live stat bindings
---------------------------------------------------------------------------
local leaderstats = player:WaitForChild("leaderstats")
local coinsValue = leaderstats:WaitForChild("Coins")
local rebirthsValue = leaderstats:WaitForChild("Rebirths")

local function refresh()
	coinsLabel.Text = "$" .. BrainrotData.format(coinsValue.Value)
	local income = player:GetAttribute("IncomePerSec") or 0
	incomeLabel.Text = "+$" .. BrainrotData.format(income) .. "/s"

	local cost = BrainrotData.rebirthCost(rebirthsValue.Value)
	local nextMult = BrainrotData.multiplier(rebirthsValue.Value + 1)
	rebirthButton.Text = "REBIRTH  $" .. BrainrotData.format(cost) .. "  (x" .. nextMult .. ")"
	if coinsValue.Value >= cost then
		rebirthButton.BackgroundColor3 = Color3.fromRGB(60, 190, 90)
	else
		rebirthButton.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
	end
end

coinsValue:GetPropertyChangedSignal("Value"):Connect(refresh)
rebirthsValue:GetPropertyChangedSignal("Value"):Connect(refresh)
player:GetAttributeChangedSignal("IncomePerSec"):Connect(refresh)
refresh()

---------------------------------------------------------------------------
-- Animation: owned brainrots bob and sway; Rainbow ones cycle colour.
---------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local t = os.clock()

	if surgeEndsAt > 0 then
		local left = math.max(0, math.ceil(surgeEndsAt - t))
		banner.Text = "BRAINROT SURGE  " .. left .. "s"
	end

	for _, model in ipairs(CollectionService:GetTagged("Brainrot")) do
		local body = model.PrimaryPart
		if body then
			local base = model:GetAttribute("BaseCFrame")
			if base then
				local phase = (model:GetAttribute("Slot") or 0) * 0.7
				model:PivotTo(
					base
						* CFrame.new(0, math.sin(t * 2 + phase) * 0.35, 0)
						* CFrame.Angles(0, math.sin(t + phase) * 0.5, 0)
				)
			end
			if model:GetAttribute("Mutation") == "Rainbow" then
				body.Color = Color3.fromHSV((t * 0.25) % 1, 0.9, 1)
			end
		end
	end
end)
