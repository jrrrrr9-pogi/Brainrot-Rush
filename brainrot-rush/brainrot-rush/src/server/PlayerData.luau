-- DataStore persistence with retries. If loading fails we never overwrite
-- the player's real save with fresh defaults.

local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("BrainrotRushV1")

local PlayerData = {}
local loadFailed = {}

local function defaults()
	return { Coins = 100, Rebirths = 0, Slots = {} }
end

local function keyOf(player)
	return "P_" .. player.UserId
end

function PlayerData.load(player)
	local data
	local ok = false
	for attempt = 1, 3 do
		local success, result = pcall(function()
			return store:GetAsync(keyOf(player))
		end)
		if success then
			ok = true
			data = result
			break
		end
		warn("[PlayerData] load failed (attempt " .. attempt .. "): " .. tostring(result))
		task.wait(1)
	end

	if not ok then
		loadFailed[player.UserId] = true
		return defaults()
	end

	local merged = defaults()
	if type(data) == "table" then
		if type(data.Coins) == "number" then
			merged.Coins = data.Coins
		end
		if type(data.Rebirths) == "number" then
			merged.Rebirths = data.Rebirths
		end
		if type(data.Slots) == "table" then
			merged.Slots = data.Slots
		end
	end
	return merged
end

function PlayerData.save(player, data)
	if loadFailed[player.UserId] then
		return
	end
	for attempt = 1, 3 do
		local success, err = pcall(function()
			store:SetAsync(keyOf(player), {
				Coins = data.Coins,
				Rebirths = data.Rebirths,
				Slots = data.Slots,
			})
		end)
		if success then
			return
		end
		warn("[PlayerData] save failed (attempt " .. attempt .. "): " .. tostring(err))
		task.wait(1)
	end
end

return PlayerData
