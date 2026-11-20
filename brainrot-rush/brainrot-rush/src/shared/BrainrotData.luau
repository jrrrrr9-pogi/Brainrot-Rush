-- Shared game data: rarities, mutations, name generator, economy formulas.
-- All characters are original creations (random combos of silly words).

local BrainrotData = {}

BrainrotData.MAX_SLOTS = 10
BrainrotData.REBIRTH_BONUS = 0.5 -- +50% income per rebirth
BrainrotData.SELL_RATIO = 0.5

BrainrotData.Rarities = {
	{ Name = "Common", Weight = 60, Price = 25, Income = 1, Color = Color3.fromRGB(190, 190, 190), Scale = 1 },
	{ Name = "Uncommon", Weight = 25, Price = 150, Income = 6, Color = Color3.fromRGB(90, 210, 90), Scale = 1.1 },
	{ Name = "Rare", Weight = 10, Price = 800, Income = 30, Color = Color3.fromRGB(70, 130, 255), Scale = 1.25 },
	{ Name = "Epic", Weight = 4, Price = 4000, Income = 150, Color = Color3.fromRGB(175, 85, 255), Scale = 1.4 },
	{ Name = "Legendary", Weight = 1, Price = 25000, Income = 800, Color = Color3.fromRGB(255, 170, 30), Scale = 1.6 },
}

BrainrotData.Mutations = {
	{ Name = "Normal", Chance = 0.87, Mult = 1 },
	{ Name = "Golden", Chance = 0.10, Mult = 2 },
	{ Name = "Rainbow", Chance = 0.03, Mult = 5 },
}

local ADJECTIVES = {
	"Skibbly", "Sussy", "Rizzy", "Gyatty", "Glorpy", "Zesty", "Wobbly", "Crunchy",
	"Cursed", "Mewing", "Sigma", "Soggy", "Bonkers", "Ohio", "Fanum", "Goofy",
}
local NOUNS = {
	"Toaster", "Crocodile", "Cactus", "Penguin", "Banana", "Frog", "Sneaker", "Donut",
	"Goose", "Lamp", "Pickle", "Walrus", "Meatball", "Traffic Cone", "Spatula", "Moth",
}
local SUFFIXES = { "", "", "", " Jr.", " the Third", " of Ohio", " Deluxe", " 9000", " Supreme" }

local rarityByName = {}
for _, r in ipairs(BrainrotData.Rarities) do
	rarityByName[r.Name] = r
end
local mutationByName = {}
for _, m in ipairs(BrainrotData.Mutations) do
	mutationByName[m.Name] = m
end

function BrainrotData.getRarity(name)
	return rarityByName[name] or BrainrotData.Rarities[1]
end

function BrainrotData.getMutation(name)
	return mutationByName[name] or BrainrotData.Mutations[1]
end

function BrainrotData.rarityIndex(name)
	for i, r in ipairs(BrainrotData.Rarities) do
		if r.Name == name then
			return i
		end
	end
	return 1
end

-- Rolls a brainrot spec. `luck` multiplies the odds of Rare and above.
function BrainrotData.roll(rng, luck)
	luck = luck or 1

	local weights = {}
	local total = 0
	for i, r in ipairs(BrainrotData.Rarities) do
		local w = r.Weight
		if i >= 3 then
			w = w * luck
		end
		weights[i] = w
		total += w
	end

	local pick = rng:NextNumber() * total
	local rarityIndex = #BrainrotData.Rarities
	for i, w in ipairs(weights) do
		pick -= w
		if pick <= 0 then
			rarityIndex = i
			break
		end
	end

	local mutationRoll = rng:NextNumber()
	local mutation = BrainrotData.Mutations[1]
	local acc = 0
	for _, m in ipairs(BrainrotData.Mutations) do
		acc += m.Chance
		if mutationRoll <= acc then
			mutation = m
			break
		end
	end

	local name = ADJECTIVES[rng:NextInteger(1, #ADJECTIVES)]
		.. " "
		.. NOUNS[rng:NextInteger(1, #NOUNS)]
		.. SUFFIXES[rng:NextInteger(1, #SUFFIXES)]

	return {
		Name = name,
		Rarity = BrainrotData.Rarities[rarityIndex].Name,
		Mutation = mutation.Name,
		Seed = rng:NextInteger(1, 1000000000),
	}
end

function BrainrotData.priceOf(spec)
	return BrainrotData.getRarity(spec.Rarity).Price
end

function BrainrotData.incomeOf(spec)
	return BrainrotData.getRarity(spec.Rarity).Income * BrainrotData.getMutation(spec.Mutation).Mult
end

function BrainrotData.sellValue(spec)
	local value = BrainrotData.getRarity(spec.Rarity).Price * BrainrotData.getMutation(spec.Mutation).Mult
	return math.floor(value * BrainrotData.SELL_RATIO)
end

function BrainrotData.multiplier(rebirths)
	return 1 + BrainrotData.REBIRTH_BONUS * rebirths
end

function BrainrotData.rebirthCost(rebirths)
	return math.floor(25000 * (2 ^ rebirths))
end

function BrainrotData.format(n)
	local suffixes = { "", "K", "M", "B", "T" }
	local i = 1
	while n >= 1000 and i < #suffixes do
		n = n / 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(n))
	end
	return string.format("%.1f%s", n, suffixes[i])
end

return BrainrotData
