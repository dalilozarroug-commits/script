
    local Players = game:GetService("Players")

     local RunService = game:GetService("RunService")

    local HttpService = game:GetService("HttpService")
    local CollectorModule = require(game.ServerScriptService.setupmoneyyy)
    local setupCollector = CollectorModule.setupCollector

    local function setTransparency(model, value)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = value
		end
	end
    end


    local function discoverPet(player, petName)
	 
	 local discoveredFolder = player:WaitForChild("DiscoveredPets")

	if not discoveredFolder:FindFirstChild(petName) then
		local tag = Instance.new("BoolValue")
		tag.Name = petName
		tag.Value = true
		tag.Parent = discoveredFolder
	end
    end

    local function moveToTarget(mob, target)
	local humanoid = mob:FindFirstChildWhichIsA("Humanoid")
	if not humanoid or not mob.PrimaryPart then return end

	if target:IsA("Model") and target.PrimaryPart then
		target = target.PrimaryPart
	end

	-- Ensure the mob can move
	for _, part in ipairs(mob:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end

	humanoid:MoveTo(target.Position)
    end

    local function isBaseFull(base)
	    for i = 1, 25 do
	    	local maker = base:FindFirstChild("maker"..i)
	    	if maker and not maker:GetAttribute("Occupied") then
	    		return false
	    	end
	    end
	    return true

    end


    local function onBuyPrompt(prompt, player)

	local mob = prompt.Parent.Parent
	
	if not mob then return end  

	local costValue = mob:FindFirstChild("Cost")

	if not costValue then return end

	local cost = costValue.Value

	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then return end

	local chachmult = player:FindFirstChild("Chachmult")
	
	if not chachmult then return end
	
	local cash = leaderstats:FindFirstChild("Money")
	
	if not cash then return end
	
	local baseName = player:GetAttribute("OwnedBase")
	
	local base = workspace.bases:FindFirstChild(baseName)
	if not base then return end
	-- Stop if base is full
	if isBaseFull(base) then
		warn(player.Name .. " tried to buy but their base is full.")
		return
	end
	
	-- Stop if not enough money
	if cash.Value < cost then return end
	-- Take money
	cash.Value -= cost
	prompt.Enabled = false
	local claimer = base:FindFirstChild("claimer")
	if claimer then
		mob:SetAttribute("BeingClaimed", true)
		-- Stop any previous movement
		local humanoid = mob:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:MoveTo(mob.PrimaryPart.Position)
	
		end
		
		-- LOOP movement until touching claimer
		
		local touching = false
	
		local touchConnection
	
		touchConnection = claimer.Touched:Connect(function(hit)
		
			if hit:IsDescendantOf(mob) then
		
				touchConnection:Disconnect()
		
				touching = true
		
			end
	
		end)
	
		task.spawn(function()
	
			while mob.Parent and mob.PrimaryPart and not touching do

				moveToTarget(mob, claimer)
	
				task.wait(0.2) -- keep reissuing movement
	
			end

		end)
	
		-- Wait until touching claimer
	
		spawn(function()
	
			while not touching do
		
				task.wait(0.1)
		
			end
		
			-- Stop movement
		
			if humanoid then
		
				humanoid:MoveTo(mob.PrimaryPart.Position)
		
			end
	
			-- Find free maker
	
			local maker
	
			for i = 1, 25 do
	
				local m = base:FindFirstChild("maker"..i)
	
				if m and not m:GetAttribute("Occupied") then
	
					maker = m
			
					break
			
				end
		
			end
		
			if not maker then return end
		
			local uniqueId = HttpService:GenerateGUID(false)
	
			mob:SetAttribute("MobId", uniqueId)
		
			maker:SetAttribute("MobId", uniqueId)
		
			maker:SetAttribute("Occupied", true)
		
			local mobNameValue = maker:FindFirstChild("mobname")
		
			if mobNameValue then
		
				mobNameValue.Value = mob.Name
			
			end
		
			-- Snap to maker
			
			mob:SetPrimaryPartCFrame(maker.CFrame + Vector3.new(0, 5, 0))
		
			print("✅", mob.Name, "reached claimer and snapped to maker for", player.Name)
		
			mob:SetAttribute("OwnedByPlayer", true)
	
			mob:SetAttribute("OwnerName", player.Name)

			mob:SetAttribute("OwnerBase", base.Name)
		
			local makerGui = maker:FindFirstChild("collecttor")
		
			local guiii = makerGui:FindFirstChild("BillboardGui")
		
			if guiii then
			
				guiii.Enabled = true
			
			end
			
			discoverPet(player, mob.Name)
		
			-- Collector logic
		
			local storage = setupCollector(maker)
			
			local makeing = mob:FindFirstChild("make")
			
			if not storage then return end
		
			task.spawn(function()
				
				while mob.Parent and (not mob:GetAttribute("OwnedByPlayer") or mob:GetAttribute("BeingClaimed")) do
					
					storage.Value += makeing.Value 
					
					task.wait(1)
				
				end
				
				maker:SetAttribute("Occupied", false)
				
				maker:SetAttribute("MobId", nil)
				
				local mobNameValue = maker:FindFirstChild("mobname")
				
				if mobNameValue then mobNameValue.Value = "" end
			
			end)
			
			-- Enable prompts
			
			local hrp = mob:FindFirstChild("HumanoidRootPart")
			
			if hrp then
				
				local sellPrompt = hrp:FindFirstChild("ProximityPromptsell")
				
				local stailPrompt = hrp:FindFirstChild("ProximityPromptstail")
				
				if sellPrompt then sellPrompt.Enabled = true end
				
				if stailPrompt then stailPrompt.Enabled = true end
			    end
		    end)
	    end
    end

    local function onSellPrompt(prompt, player)
	    local mob = prompt.Parent.Parent
	    if not mob then return end
	    if mob:GetAttribute("OwnerName") ~= player.Name then return end
	    local costValue = mob:FindFirstChild("Cost")
	    if not costValue then return end
	    local cost = costValue.Value
	    local leaderstats = player:FindFirstChild("leaderstats")
	    if not leaderstats then return end
	    local chachmult = player:FindFirstChild("Chachmult")
	    if not chachmult then print("ninja is gay") end
	    if not chachmult then  return end
	    local cash = leaderstats:FindFirstChild("Money")
	    if not cash then return end
	    cash.Value += (math.floor(cost / 2)) * chachmult.value
	    local baseName = mob:GetAttribute("OwnerBase")
	    local mobId = mob:GetAttribute("MobId")
	    local base = workspace.bases:FindFirstChild(baseName)
    	if base and mobId then
	    	for i = 1, 25 do
		    	local m = base:FindFirstChild("maker"..i)
			    if m and m:GetAttribute("Occupied") and m:GetAttribute("MobId") == mobId then
				    m:SetAttribute("Occupied", false)
				    m:SetAttribute("MobId", nil)

				-- keep collector visible, only hide its text labels
				for _, part in ipairs(m:GetDescendants()) do
					if part:IsA("BillboardGui") then
						part.Enabled = false
					end
				end

				local mobNameValue = m:FindFirstChild("mobname")
				if mobNameValue then
					mobNameValue.Value = ""
				end
				local collecttor = m:FindFirstChild("collecttor")
				if collecttor then
					print(collecttor)
					local cashhhh = collecttor :FindFirstChild("cashhhhhhhh")
					if cashhhh then
						print(cashhhh)
						if cashhhh:IsA("IntValue") then
							cash.Value += cashhhh.Value * chachmult.value
							cashhhh.Value = 0
							print("done")
						end
					end
				end
				break
			end
		end
	end

	mob:Destroy()
    end


    local function removePromptsFromModel(mob)
	    local hrp = mob:FindFirstChild("HumanoidRootPart")
	    if not hrp then return end
	    for _, child in ipairs(hrp:GetChildren()) do
		    if child:IsA("ProximityPrompt") then
			    child.Enabled = false
		    end
	    end
    end

    local function enablePromptsOnModel(mob)
	    local hrp = mob:FindFirstChild("HumanoidRootPart")
	    if not hrp then return end
	    for _, child in ipairs(hrp:GetChildren()) do
		    if child:IsA("ProximityPrompt") then
			    child.Enabled = true
		    end
	    end
    end

    local function ensurePrimaryPart(model)
	if model.PrimaryPart then return true end
	    local hrp = model:FindFirstChild("HumanoidRootPart")
	    if hrp then
		model.PrimaryPart = hrp
		return true
	    end
	    return false
    end

    local carryingMap = {}

    local function onStailPrompt(prompt, player)

	if not player or not player.Parent then return end
	
	local mob = prompt.Parent.Parent
	if not mob then return end
	
	local ownerName = mob:GetAttribute("OwnerName")
	if not ownerName or ownerName == player.Name then return end

	if player:GetAttribute("CarryingMob") then return end

	player:SetAttribute("CarryingMob", true)

	removePromptsFromModel(mob)
	setTransparency(mob, 0.5)
	mob:SetAttribute("BeingStolen", true)

	local char = player.Character
	local hrpPlayer = char and char:FindFirstChild("HumanoidRootPart")
	if not hrpPlayer then
		setTransparency(mob, 0)
		enablePromptsOnModel(mob)
		player:SetAttribute("CarryingMob", false)
		mob:SetAttribute("BeingStolen", false)
		return
	end

	local copy = mob:Clone()
	local copyHRP = copy:FindFirstChild("HumanoidRootPart")
	if copyHRP then
		for _, c in ipairs(copyHRP:GetChildren()) do
			if c:IsA("ProximityPrompt") then
				c:Destroy()
			end
		end
	end

	-- ensure primarypart for the copy
	if not copy.PrimaryPart and copyHRP then
		copy.PrimaryPart = copyHRP
	end

	copy.Parent = workspace
	-- position above head
	if copy.PrimaryPart then
		copy:SetPrimaryPartCFrame(hrpPlayer.CFrame * CFrame.new(0, 3.5, 0))
	end
	setTransparency(copy, 0) -- fully visible

	-- weld copy to player's HRP so it moves with them
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = copy.PrimaryPart
	weld.Part1 = hrpPlayer
	weld.Parent = copy.PrimaryPart

	-- mark copy for identification and remove interaction
	copy:SetAttribute("StolenBy", player.UserId)
	copy:SetAttribute("IsCarryCopy", true)

	-- store state so we can cleanup later
	local state = { copy = copy, original = mob, connections = {} }
	carryingMap[player.UserId] = state

	local function finalizeSteal()
		function cleanupFailure()
			-- destroy copy
			if state and state.copy and state.copy.Parent then
				state.copy:Destroy()
			end
			-- restore original visuals and prompts
			if state and state.original and state.original.Parent then
				setTransparency(state.original, 0)
				enablePromptsOnModel(state.original)
				state.original:SetAttribute("BeingStolen", false)
			end
			if player then
				player:SetAttribute("CarryingMob", false)
			end
			carryingMap[player.UserId] = nil
		end
		if not state.copy or not state.copy.Parent then
			cleanupFailure()
			return
		end
		if not state.original or not state.original.Parent then
			state.copy:Destroy()
			player:SetAttribute("CarryingMob", false)
			carryingMap[player.UserId] = nil
			return
		end

		-- get thief’s base
		local newBaseName = player:GetAttribute("OwnedBase")
		local newBase = workspace.bases:FindFirstChild(newBaseName)
		if not newBase or isBaseFull(newBase) then
			-- no space → destroy mob & copy
			state.copy:Destroy()
			state.original:Destroy()
			player:SetAttribute("CarryingMob", false)
			carryingMap[player.UserId] = nil
			return
		end

		-- free old maker
		local oldBaseName = state.original:GetAttribute("OwnerBase")
		local oldMobId = state.original:GetAttribute("MobId")
		local oldBase = workspace.bases:FindFirstChild(oldBaseName)
		discoverPet(player, mob.Name)
		if oldBase and oldMobId then
			for i = 1, 25 do
				local m = oldBase:FindFirstChild("maker"..i)
				if m and m:GetAttribute("MobId") == oldMobId then
					m:SetAttribute("Occupied", false)
					m:SetAttribute("MobId", nil)
					local mobNameValue = m:FindFirstChild("mobname")
					if mobNameValue then
						mobNameValue.Value = ""
					end
					local collecttor = m:FindFirstChild("collecttor")
					if collecttor then
						print(collecttor)
						local cashhhh = collecttor :FindFirstChild("cashhhhhhhh")
						if cashhhh then
							if cashhhh:IsA("IntValue") then
								cashhhh.Value = 0
							end
						end
					end
					break
				end
			end
		end

		-- find free maker in new base
		local newMaker
		for i = 1, 25 do
			local m = newBase:FindFirstChild("maker"..i)
			if m and not m:GetAttribute("Occupied") then
				newMaker = m
				break
			end
		end
		if not newMaker then
			state.copy:Destroy()
			player:SetAttribute("CarryingMob", false)
			carryingMap[player.UserId] = nil
			return
		end

		-- assign new ownership
		local uniqueId = HttpService:GenerateGUID(false)
		state.original:SetAttribute("MobId", uniqueId)
		state.original:SetAttribute("OwnedByPlayer", true)
		state.original:SetAttribute("OwnerName", player.Name)
		state.original:SetAttribute("OwnerBase", newBase.Name)

		newMaker:SetAttribute("MobId", uniqueId)
		newMaker:SetAttribute("Occupied", true)

		-- store mob's name into the maker
		local mobNameValue = newMaker:FindFirstChild("mobname")
		if mobNameValue then
			mobNameValue.Value = state.original.Name
		end

		-- teleport mob
		if ensurePrimaryPart(state.original) then
			state.original:SetPrimaryPartCFrame(newMaker.CFrame + Vector3.new(0, 5, 0))
		end

		-- restore visuals
		setTransparency(state.original, 0)

		-- re-enable prompts (Sell + Stail only for new owner)
		enablePromptsOnModel(state.original)

		-- setup collector like a bought mob
		local storage = setupCollector(newMaker)
		local makeing = mob:FindFirstChild("make")
		if storage then
			task.spawn(function()
				while state.original.Parent and state.original:GetAttribute("OwnedByPlayer") do
					storage.Value += makeing.value
					task.wait(1)
				end
				newMaker:SetAttribute("Occupied", false)
				newMaker:SetAttribute("MobId", nil)
				local mobNameValue = newMaker:FindFirstChild("mobname")
				if mobNameValue then
					mobNameValue.Value = ""
				end
			end)
		end

		-- cleanup: destroy copy + clear state
		if state.copy and state.copy.Parent then
			state.copy:Destroy()
		end
		player:SetAttribute("CarryingMob", false)
		carryingMap[player.UserId] = nil
	end

	-- connect claimer touch (finalize when thief touches their claimer)
	local baseName = player:GetAttribute("OwnedBase")
	local base = workspace.bases:FindFirstChild(baseName)
	local claimer = base and base:FindFirstChild("claimer")
	if claimer and claimer:IsA("BasePart") then
		local conn
		conn = claimer.Touched:Connect(function(hit)
			-- only finalize if the toucher is this player's character
			local toucherPlayer = Players:GetPlayerFromCharacter(hit.Parent)
			if toucherPlayer == player and carryingMap[player.UserId] and carryingMap[player.UserId].copy then
				-- disconnect and finalize
				conn:Disconnect()
				finalizeSteal()
			end
		end)
		table.insert(state.connections, conn)
	end

	-- also finalize if player's character touches claimer by proximity check as fallback (in case Touched isn't reliable)
	local proximityConn
	proximityConn = game:GetService("RunService").Heartbeat:Connect(function()
		if not carryingMap[player.UserId] then
			proximityConn:Disconnect()
			return
		end
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
		if claimer and player.Character.HumanoidRootPart then
			if (player.Character.HumanoidRootPart.Position - claimer.Position).Magnitude < 4 then
				-- finalize
				if proximityConn then proximityConn:Disconnect() end
				for _, c in ipairs(state.connections) do
					if c and c.Connected then pcall(function() c:Disconnect() end) end
				end
				finalizeSteal()
			end
		end
	end)
	table.insert(state.connections, proximityConn)

	-- listen for player death / character removing -> cancel steal and restore original
	local charConn
	charConn = player.CharacterRemoving:Connect(function()
		-- cleanup
		if carryingMap[player.UserId] then
			cleanupFailure()
		end
		if charConn then charConn:Disconnect() end
	end)
	table.insert(state.connections, charConn)

	-- also listen for humanoid died in case CharacterRemoving doesn't fire in time
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local diedConn
	if hum then
		diedConn = hum.Died:Connect(function()
			if carryingMap[player.UserId] then
				cleanupFailure()
			end
			if diedConn then diedConn:Disconnect() end
		end)
		table.insert(state.connections, diedConn)
	end
end



-- 🔹 Connect prompts
local function connectPrompt(prompt)
	if prompt:GetAttribute("Connected") then return end

	if prompt.Name == "ProximityPromptbuy" then
		prompt.Triggered:Connect(function(player) onBuyPrompt(prompt, player) end)
	elseif prompt.Name == "ProximityPromptsell" then
		prompt.Triggered:Connect(function(player) onSellPrompt(prompt, player) end)
	elseif prompt.Name == "ProximityPromptstail" then
		prompt.Triggered:Connect(function(player) onStailPrompt(prompt, player) end)
	end

	prompt:SetAttribute("Connected", true)
end

for _, prompt in ipairs(workspace:GetDescendants()) do
	if prompt:IsA("ProximityPrompt") then
		connectPrompt(prompt)
	end
end -- close the for loop that scanned workspace:GetDescendants()

-- also connect new prompts that appear later
workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("ProximityPrompt") then
		connectPrompt(desc)
	end
end)
