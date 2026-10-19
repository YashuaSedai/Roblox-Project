-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- GENERIC
local ElementalMixing = ReplicatedStorage:WaitForChild("ElementalMixing")
local DrawEvent = ElementalMixing:WaitForChild("Drawing"):WaitForChild("Draw")
local RemoveEvent = ElementalMixing:WaitForChild("Drawing"):WaitForChild("Remove")

-- MODULES
local DrawHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ElementalHandler"):WaitForChild("DrawHandler"))

-- BEZIER MODULE
local Bezier = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Bezier"))

-- ASSETS
local Assets = ReplicatedStorage:WaitForChild("Assets")
local ElementalFolder = Assets:WaitForChild("Elements")
-- BEAMS
local Beams = ElementalFolder:WaitForChild("Beams")
-- PARTICLES
local Particles = ElementalFolder:WaitForChild("Particles")
-- TRAILS
local Trails = ElementalFolder:WaitForChild("Trails")

RemoveEvent.OnClientEvent:Connect(function(name)
	DrawHandler.ClearElementalFx(name)
end)

DrawEvent.OnClientEvent:Connect(function(char, name, element, slot, slotNo)
	DrawHandler.SetupElementalFx(char, name, element, slot, slotNo)
end)

-- SLOT RECONCILER ----------------------------------------------------------------------------------------------
-- The draw / remove events above are one-shot messages. If one is lost (rate limit, arrives before the character has
-- loaded, happened before this client joined, an error half way through a setup) that slot's visual stays wrong forever.
-- The Slot1..Slot5 attributes on a character are STATE: they always replicate and are always right. So every
-- CHECK_INTERVAL seconds each player's slots are compared with what is drawn on them, and a mismatch that lasts for
-- CONFIRM_CHECKS checks in a row (so a normal draw / clear that is still in flight is left alone) gets repaired.
local CHECK_INTERVAL = 0.5
local CONFIRM_CHECKS = 2
local MAX_RETRIES = 5 -- per slot and per wanted element, so a slot that keeps erroring can't spam forever
local mismatch = {}   -- [player name .. slot] = { want, count, tries }

Players.PlayerRemoving:Connect(function(plr)
	for key in mismatch do
		if string.sub(key, 1, #plr.Name) == plr.Name then mismatch[key] = nil end
	end
end)

task.spawn(function()
	while true do
		task.wait(CHECK_INTERVAL)

		for _, plr in Players:GetPlayers() do
			local char = plr.Character
			if not char or not char:FindFirstChild("UpperTorso") or not char:FindFirstChild("HumanoidRootPart") then continue end

			local name = plr.Name
			local fx = DrawHandler.PlayerFx[name]

			for i = 1, 5 do
				local slot = "Slot" .. i
				local want = char:GetAttribute(slot)
				if want == "Default" then want = nil end
				local have = fx and fx.Slots[slot] and fx.Slots[slot].Element or nil
				local key = name .. slot

				if want == have then
					mismatch[key] = nil
				else
					local entry = mismatch[key]
					if not entry or entry.want ~= want then
						entry = { want = want, count = 0, tries = 0 } -- a different target: start counting again
						mismatch[key] = entry
					end
					entry.count += 1

					if entry.count >= CONFIRM_CHECKS and entry.tries < MAX_RETRIES then
						entry.tries += 1
						local ok, err = pcall(function()
							if want then
								DrawHandler.SetupElementalFx(char, name, want, slot, i)
							else
								DrawHandler.RemoveElementalFx(name, plr.UserId, slot)
							end
						end)
						if not ok then
							warn(`Slot reconcile failed for {name} {slot} (try {entry.tries}/{MAX_RETRIES}): {err}`)
						end
					end
				end
			end
		end
	end
end)
