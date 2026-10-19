-- LinkSystem   (Script, server)
-- The always-on parts of linking that don't belong to any single weave:
--   1. WHAT THE LEADER IS CASTING. When a link LEADER casts ANY weave (link weave or not), the character gets a "LinkWeave"
--      attribute holding the weave's NAME. (Only leaders: linkers and unlinked weavers never set it. A weave that
--      RequiresLink must also pass its link requirement, or it never starts.) The link VFX listens to that attribute and looks the name up in the Dictionary
--      (WeaveKey digits -> elements -> colors, see LinkData.GetElements / GetColorSequence) to recolor the beams.
--      It is cleared a moment after the leader lets go, and whenever the link breaks.
--   2. CLEAN UP. Death, respawn and leaving cut every link going in or out of that weaver.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local WeavingFolder = Modules:WaitForChild("WeavingModule")
local Dictionary = require(WeavingFolder:WaitForChild("Dictionary"))
local LinkData = require(Modules:WaitForChild("LinkData"))
local LinkService = require(ServerScriptService:WaitForChild("SYSTEM"):WaitForChild("LinkService"))

local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")
local WeavingFxClear = WeavingFolder:WaitForChild("WeavingFxClear")

local castToken = {} -- [char] = number, so a late "clear" can't wipe a newer cast

-- 1a. A weave opens (the same remote every weave uses; clients can send anything, so everything is validated)
WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	if typeof(weaveName) ~= "string" or weaveName == "Linking" then return end -- (Linking itself isn't a weave the leader "casts")
	local weaveData = Dictionary[weaveName]
	if not weaveData then return end

	local char = player.Character
	if not char or not LinkData.IsLeader(char) then return end -- only the leader of a link colors it
	if not LinkData.CheckRequirement(char, weaveData) then return end -- a link weave without enough links never starts

	castToken[char] = (castToken[char] or 0) + 1
	char:SetAttribute("LinkWeave", weaveName)
end)

-- 1b. The leader lets go: keep the color for a moment, then go back to the idle look
WeavingFxClear.OnServerEvent:Connect(function(player: Player, weaveName)
	local char = player.Character
	if not char or char:GetAttribute("LinkWeave") ~= weaveName then return end
	local token = castToken[char]
	task.delay(LinkData.LINGER, function()
		if castToken[char] == token and char.Parent then
			char:SetAttribute("LinkWeave", nil)
		end
	end)
end)

-- 2. CLEAN UP
local function watchCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		hum.Died:Connect(function()
			LinkService.Purge(char)
		end)
	end
end

local function watchPlayer(player: Player)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		watchCharacter(player, char)
	end)
	player.CharacterRemoving:Connect(function(char)
		LinkService.Purge(char)
		castToken[char] = nil
	end)
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(watchPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		LinkService.Purge(player.Character)
		castToken[player.Character] = nil
	end
end)
