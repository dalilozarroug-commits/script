local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local CollectorModule = require(game.ServerScriptService.setupmoneyyy)
local setupCollector = CollectorModule.setupCollector

-- ======= Utility helpers =======

-- Set transparency for all BaseParts in a model (fast: iterate children)
local function setTransparency(model, value)
	if not model then return end
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Transparency = value
		end
	end
end

-- Ensure model.PrimaryPart is set to HumanoidRootPart if present
local function ensurePrimaryPart(model)
	if not model then return false end
	if model.PrimaryPart then return true end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		model.PrimaryPart = hrp
		return true
	end
	return false
end

-- Enable or disable all ProximityPrompts in a model's HRP safely
local function setPromptsEnabled(model, enabled)
	if not model then return end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	for _, child in ipairs(hrp:GetChildren()) do
		if child:IsA("ProximityPrompt") then
			child.Enabled = enabled
		end
	end
end

-- Get player's leaderstats Money (fast-safe)
local function getPlayerMoneyValue(player)
	if not player then return nil end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return nil end
	return leaderstats:FindFirstChild("Money")
end

-- Get player's chach multiplier (fix casing & .Value)
local function getPlayerMultiplier(player)
	if not player then return 1 end
	local mult = player:FindFirstChild("Chachmult")
	-- safe fallback if attribute or object missing
	if mult and mult.Value ~= nil then
		return mult.Value
	end
	-- try attribute fallback
	local attr = player:GetAttribute("Chachmult")
	if type(attr) == "number" then return attr end
	return 1
end

-- Check whether a base is full (returns true if all makers occupied)
local function isBaseFull(base)
	if not base then return true end
	for i = 1, 25 do
		local maker = base:FindFirstChild("maker" .. i)
		if maker and not maker:GetAttribute("Occupied") then
			return false
		end
	end
	return true
end

-- Find first free maker in a base
local function findFreeMaker(base)
	if not base then return nil end
	for i = 1, 25 do
		local m = base:FindFirstChild("maker" .. i)
		if m and not m:GetAttribute("Occupied") then
			return m
		end
	end
	return nil
end

-- Free a maker by mobId in a base (used when selling / stealing)
local function freeMakerByMobId(base, mobId)
	if not base or not mobId then return end
	for i = 1, 25 do
		local m = base:FindFirstChild("maker" .. i)
		if m and m:GetAttribute("Occupied") and m:GetAttribute("MobId") == mobId then
			m:SetAttribute("Occupied", false)
			m:SetAttribute("MobId", nil)
			local nameVal = m:FindFirstChild("mobname")
			if nameVal then nameVal.Value = "" end
			-- hide any BillboardGui children but keep container
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BillboardGui") then
					d.Enabled = false
				end
			end
			-- reset collector stored cash if present
			local collector = m:FindFirstChild("collecttor")
			if collector then
				local cashVal = collector:FindFirstChild("cashhhhhhhh")
				if cashVal and cashVal:IsA("IntValue") then
					cashVal.Value = 0
				end
			end
			break
		end
	end
end

-- Add pet discovery tag to player's DiscoveredPets folder
local function discoverPet(player, petName)
	if not player or not petName then return end
	local discovered = player:FindFirstChild("DiscoveredPets")
	if not discovered then
		-- fail safe: create folder if it doesn't exist
		discovered = Instance.new("Folder")
		discovered.Name = "DiscoveredPets"
		discovered.Parent = player
	end
	if not discovered:FindFirstChild(petName) then
		local tag = Instance.new("BoolValue")
		tag.Name = petName
		tag.Value = true
		tag.Parent = discovered
	end
end

-- Move mob toward target position using Humanoid:MoveTo. This just issues the command (non-blocking).
local function moveToTarget(mob, targetPart)
	if not mob or not mob.PrimaryPart then return end
	local humanoid = mob:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if targetPart:IsA("Model") and targetPart.PrimaryPart then
		targetPart = targetPart.PrimaryPart
	end
	if not targetPart or not targetPart.Position then return end

	-- make sure mob parts aren't anchored so physics work
	for _, p in ipairs(mob:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
		end
	end

	humanoid:MoveTo(targetPart.Position)
end

-- Safely start a collector loop on a maker (returns the Value container or nil)
local function startCollectorForMaker(maker, mob)
	local storage = setupCollector(maker)
	local making = mob and mob:FindFirstChild("make")
	if not storage or not making or type(making.Value) ~= "number" then
		return storage
	end

	-- run in background; will end when maker OR mob is removed or when mob is no longer owned
	task.spawn(function()
		while maker.Parent and mob.Parent and mob:GetAttribute("OwnedByPlayer") do
			-- add safely
			local success, err = pcall(function()
				storage.Value = storage.Value + making.Value
			end)
			if not success then
				warn("Collector add failed:", err)
			end
			task.wait(1)
		end

		-- cleanup maker attributes when loop ends
		if maker and maker.Parent then
			maker:SetAttribute("Occupied", false)
			maker:SetAttribute("MobId", nil)
			local mobNameValue = maker:FindFirstChild("mobname")
			if mobNameValue then mobNameValue.Value = "" end
		end
	end)

	return storage
end

-- ======= Buy handler =======

local function finalizeClaimToMaker(player, mob, claimer, base)
	-- This function assumes claimer touch detection already happened.
	-- Find free maker, assign and snap mob to it, enable sell/stail prompts, start collector.
	if not (player and mob and base) then return end

	local maker = findFreeMaker(base)
	if not maker then
		warn("No free maker found while finalizing claim for", player.Name)
		return
	end

	-- assign id and attributes
	local uniqueId = HttpService:GenerateGUID(false)
	mob:SetAttribute("MobId", uniqueId)
	maker:SetAttribute("MobId", uniqueId)
	maker:SetAttribute("Occupied", true)

	local mobNameValue = maker:FindFirstChild("mobname")
	if mobNameValue then mobNameValue.Value = mob.Name end

	-- snap the mob to the maker (ensure primary part exists)
	if ensurePrimaryPart(mob) then
		mob:SetPrimaryPartCFrame(maker.CFrame + Vector3.new(0, 5, 0))
	end

	mob:SetAttribute("OwnedByPlayer", true)
	mob:SetAttribute("OwnerName", player.Name)
	mob:SetAttribute("OwnerBase", base.Name)

	-- show maker GUI text if present
	local makerGui = maker:FindFirstChild("collecttor")
	if makerGui then
		local billboard = makerGui:FindFirstChildWhichIsA("BillboardGui", true)
		if billboard then billboard.Enabled = true end
	end

	-- discover pet for player
	discoverPet(player, mob.Name)

	-- enable sale/tail prompts (if present)
	setPromptsEnabled(mob, true)

	-- start collector loop
	startCollectorForMaker(maker, mob)
end

local function onBuyPrompt(prompt, player)
	if not prompt or not player then return end
	local mob = prompt.Parent and prompt.Parent.Parent
	if not mob then return end

	local costValue = mob:FindFirstChild("Cost")
	if not costValue or type(costValue.Value) ~= "number" then return end
	local cost = costValue.Value

	local money = getPlayerMoneyValue(player)
	if not money then return end
	if money.Value < cost then return end

	local baseName = player:GetAttribute("OwnedBase")
	local base = workspace:FindFirstChild("bases") and workspace.bases:FindFirstChild(baseName)
	if not base then return end

	if isBaseFull(base) then
		warn(player.Name .. " tried to buy but their base is full.")
		return
	end

	-- take money and disable prompt
	money.Value = money.Value - cost
	prompt.Enabled = false

	-- if base has a claimer part, move mob to claimer then finalize
	local claimer = base:FindFirstChild("claimer")
	if not claimer or not claimer:IsA("BasePart") then
		-- immediate finalize if no claimer
		finalizeClaimToMaker(player, mob, nil, base)
		return
	end

	-- Prevent multiple claim processes for same mob
	if mob:GetAttribute("BeingClaimed") then return end
	mob:SetAttribute("BeingClaimed", true)

	-- try to stop humanoid movement and then move toward claimer
	local humanoid = mob:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- stop movement gently
		pcall(function() humanoid:MoveTo(mob.PrimaryPart and mob.PrimaryPart.Position or mob:GetModelCFrame().p) end)
	end

	-- wait until the mob touches the claimer (with timeout safety)
	local touching = false
	local touchConn
	touchConn = claimer.Touched:Connect(function(hit)
		if hit and hit:IsDescendantOf(mob) then
			touchConn:Disconnect()
			touching = true
		end
	end)

	-- repeatedly issue MoveTo until we detect touching or until mob removed
	task.spawn(function()
		while mob.Parent and not touching do
			moveToTarget(mob, claimer)
			task.wait(0.2)
		end
	end)

	-- wait for touch then finalize
	task.spawn(function()
		-- Wait loop
		local tries = 0
		while mob.Parent and not touching and tries < 300 do -- ~30s safety timeout
			task.wait(0.1)
			tries = tries + 1
		end

		-- if we timed out, unset BeingClaimed and re-enable prompt
		if not touching then
			mob:SetAttribute("BeingClaimed", false)
			prompt.Enabled = true
			return
		end

		-- stop humanoid movement and finalize assignment
		if humanoid then
			pcall(function() humanoid:MoveTo(mob.PrimaryPart and mob.PrimaryPart.Position or mob:GetModelCFrame().p) end)
		end

		finalizeClaimToMaker(player, mob, claimer, base)
		mob:SetAttribute("BeingClaimed", false)
	end)
end

-- ======= Sell handler =======

local function onSellPrompt(prompt, player)
	if not prompt or not player then return end
	local mob = prompt.Parent and prompt.Parent.Parent
	if not mob then return end

	-- only owner can sell
	if mob:GetAttribute("OwnerName") ~= player.Name then return end

	local costValue = mob:FindFirstChild("Cost")
	if not costValue or type(costValue.Value) ~= "number" then return end
	local cost = costValue.Value

	local money = getPlayerMoneyValue(player)
	if not money then return end
	local mult = getPlayerMultiplier(player)

	-- give half cost * multiplier
	money.Value = money.Value + math.floor(cost / 2) * (mult or 1)

	-- free old maker if exists
	local baseName = mob:GetAttribute("OwnerBase")
	local mobId = mob:GetAttribute("MobId")
	local base = workspace:FindFirstChild("bases") and workspace.bases:FindFirstChild(baseName)
	if base and mobId then
		freeMakerByMobId(base, mobId)
	end

	-- destroy the mob
	mob:Destroy()
end

-- ======= Steal (stail) handler =======

-- Table storing currently-carrying state by userId
local carryingMap = {}

-- Cleanup helper for failed steal attempt
local function cleanupStealState(playerId)
	local state = carryingMap[playerId]
	if not state then return end

	-- destroy copy if exists
	if state.copy and state.copy.Parent then
		state.copy:Destroy()
	end

	-- restore original mob visuals and prompts
	if state.original and state.original.Parent then
		setTransparency(state.original, 0)
		setPromptsEnabled(state.original, true)
		state.original:SetAttribute("BeingStolen", false)
	end

	-- clear carrying flag on player if possible
	local player = Players:GetPlayerByUserId(playerId)
	if player then
		player:SetAttribute("CarryingMob", false)
	end

	-- disconnect saved connections
	if state.connections then
		for _, c in ipairs(state.connections) do
			if c and c.Connected then
				pcall(function() c:Disconnect() end)
			end
		end
	end

	carryingMap[playerId] = nil
end

-- Finalize a successful steal: assign to thief's base and start collector
local function finalizeStealForState(player, state)
	if not (player and state and state.original) then return end

	local newBaseName = player:GetAttribute("OwnedBase")
	local newBase = workspace:FindFirstChild("bases") and workspace.bases:FindFirstChild(newBaseName)
	if not newBase or isBaseFull(newBase) then
		-- no space; destroy mob & copy and abort
		if state.copy and state.copy.Parent then state.copy:Destroy() end
		if state.original and state.original.Parent then state.original:Destroy() end
		player:SetAttribute("CarryingMob", false)
		carryingMap[player.UserId] = nil
		return
	end

	-- free old maker in original owner base
	local oldBaseName = state.original:GetAttribute("OwnerBase")
	local oldMobId = state.original:GetAttribute("MobId")
	local oldBase = workspace:FindFirstChild("bases") and workspace.bases:FindFirstChild(oldBaseName)

	discoverPet(player, state.original.Name)

	if oldBase and oldMobId then
		freeMakerByMobId(oldBase, oldMobId)
	end

	-- find free maker in new base
	local newMaker = findFreeMaker(newBase)
	if not newMaker then
		-- shouldn't happen because we checked isBaseFull, but be safe
		if state.copy and state.copy.Parent then state.copy:Destroy() end
		player:SetAttribute("CarryingMob", false)
		carryingMap[player.UserId] = nil
		return
	end

	-- assign new ID and attributes
	local uniqueId = HttpService:GenerateGUID(false)
	state.original:SetAttribute("MobId", uniqueId)
	state.original:SetAttribute("OwnedByPlayer", true)
	state.original:SetAttribute("OwnerName", player.Name)
	state.original:SetAttribute("OwnerBase", newBase.Name)

	newMaker:SetAttribute("MobId", uniqueId)
	newMaker:SetAttribute("Occupied", true)
	local mobNameValue = newMaker:FindFirstChild("mobname")
	if mobNameValue then mobNameValue.Value = state.original.Name end

	-- move original mob to new maker
	if ensurePrimaryPart(state.original) then
		state.original:SetPrimaryPartCFrame(newMaker.CFrame + Vector3.new(0, 5, 0))
	end

	-- restore visuals and prompts
	setTransparency(state.original, 0)
	setPromptsEnabled(state.original, true)

	-- start collector
	startCollectorForMaker(newMaker, state.original)

	-- destroy the copy and cleanup
	if state.copy and state.copy.Parent then state.copy:Destroy() end
	player:SetAttribute("CarryingMob", false)
	carryingMap[player.UserId] = nil
end

local function onStailPrompt(prompt, player)
	if not prompt or not player then return end
	if not player.Parent then return end

	local mob = prompt.Parent and prompt.Parent.Parent
	if not mob then return end

	-- ignore if owner or already carrying
	if mob:GetAttribute("OwnerName") == player.Name then return end
	if player:GetAttribute("CarryingMob") then return end

	-- set flag early
	player:SetAttribute("CarryingMob", true)

	-- disable interactions on original mob
	setPromptsEnabled(mob, false)
	setTransparency(mob, 0.5)
	mob:SetAttribute("BeingStolen", true)

	-- get player's HRP
	local char = player.Character
	if not char then
		-- restore if can't carry
		setTransparency(mob, 0)
		setPromptsEnabled(mob, true)
		player:SetAttribute("CarryingMob", false)
		mob:SetAttribute("BeingStolen", false)
		return
	end
	local hrpPlayer = char:FindFirstChild("HumanoidRootPart")
	if not hrpPlayer then
		setTransparency(mob, 0)
		setPromptsEnabled(mob, true)
		player:SetAttribute("CarryingMob", false)
		mob:SetAttribute("BeingStolen", false)
		return
	end

	-- clone mob to be carried (remove prompts on the clone)
	local copy = mob:Clone()
	local copyHRP = copy:FindFirstChild("HumanoidRootPart")
	if copyHRP then
		for _, c in ipairs(copyHRP:GetChildren()) do
			if c:IsA("ProximityPrompt") then
				c:Destroy()
			end
		end
	end

	if not copy.PrimaryPart and copyHRP then
		copy.PrimaryPart = copyHRP
	end

	-- parent copy to workspace and position above player's head
	copy.Parent = workspace
	if copy.PrimaryPart then
		copy:SetPrimaryPartCFrame(hrpPlayer.CFrame * CFrame.new(0, 3.5, 0))
	end
	setTransparency(copy, 0)

	-- weld copy to player HRP so it follows
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = copy.PrimaryPart
	weld.Part1 = hrpPlayer
	weld.Parent = copy.PrimaryPart

	-- mark copy & original
	copy:SetAttribute("StolenBy", player.UserId)
	copy:SetAttribute("IsCarryCopy", true)

	-- store state for later finalization or cleanup
	local state = {
		copy = copy,
		original = mob,
		connections = {}
	}
	carryingMap[player.UserId] = state

	-- helper to handle failure / cleanup
	local function cleanupFailure()
		cleanupStealState(player.UserId)
	end

	-- If original no longer exists at any point, fail
	if not state.original or not state.original.Parent then
		cleanupFailure()
		return
	end

	-- get target claimer for this thief
	local baseName = player:GetAttribute("OwnedBase")
	local base = workspace:FindFirstChild("bases") and workspace.bases:FindFirstChild(baseName)
	local claimer = base and base:FindFirstChild("claimer")

	-- Conn: finalize when thief touches their claimer
	if claimer and claimer:IsA("BasePart") then
		local conn
		conn = claimer.Touched:Connect(function(hit)
			local toucherPlayer = Players:GetPlayerFromCharacter(hit.Parent)
			if toucherPlayer == player and carryingMap[player.UserId] and carryingMap[player.UserId].copy then
				pcall(function() conn:Disconnect() end)
				finalizeStealForState(player, carryingMap[player.UserId])
			end
		end)
		table.insert(state.connections, conn)
	end

	-- Fallback proximity check each heartbeat (distance check)
	local proximityConn
	proximityConn = RunService.Heartbeat:Connect(function()
		if not carryingMap[player.UserId] then
			if proximityConn and proximityConn.Connected then pcall(function() proximityConn:Disconnect() end) end
			return
		end
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
		if claimer and player.Character.HumanoidRootPart then
			if (player.Character.HumanoidRootPart.Position - claimer.Position).Magnitude < 4 then
				-- finalize
				if proximityConn and proximityConn.Connected then pcall(function() proximityConn:Disconnect() end) end
				for _, c in ipairs(state.connections) do
					if c and c.Connected then pcall(function() c:Disconnect() end) end
				end
				finalizeStealForState(player, state)
			end
		end
	end)
	table.insert(state.connections, proximityConn)

	-- listen for player character removing -> cancel steal
	local charConn
	charConn = player.CharacterRemoving:Connect(function()
		cleanupFailure()
		if charConn and charConn.Connected then pcall(function() charConn:Disconnect() end) end
	end)
	table.insert(state.connections, charConn)

	-- also listen for humanoid death to cancel
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local diedConn = hum.Died:Connect(function()
			cleanupFailure()
			if diedConn and diedConn.Connected then pcall(function() diedConn:Disconnect() end) end
		end)
		table.insert(state.connections, diedConn)
	end
end

-- ======= Prompt connection logic =======

local function connectPrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then return end
	if prompt:GetAttribute("Connected") then return end

	-- Connect correct trigger handler based on prompt name
	local name = prompt.Name
	if name == "ProximityPromptbuy" then
		prompt.Triggered:Connect(function(player) onBuyPrompt(prompt, player) end)
	elseif name == "ProximityPromptsell" then
		prompt.Triggered:Connect(function(player) onSellPrompt(prompt, player) end)
	elseif name == "ProximityPromptstail" then
		prompt.Triggered:Connect(function(player) onStailPrompt(prompt, player) end)
	else
		-- unknown prompt type: ignore
	end

	prompt:SetAttribute("Connected", true)
end

-- Initial scan: connect existing prompts once
for _, desc in ipairs(workspace:GetDescendants()) do
	if desc:IsA("ProximityPrompt") then
		connectPrompt(desc)
	end
end

-- Connect future prompts as they are added
workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("ProximityPrompt") then
		connectPrompt(desc)
	end
end)
