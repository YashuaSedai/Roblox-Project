-- LinkService   (ModuleScript, SERVER ONLY)
-- Owns the link STATE. Every weaver has at most ONE parent (the weaver they linked to), so a chain is a tree:
--
--      leader  <--  B  <--  A        A linked to B, B linked to the leader.  The END of the chain is the leader.
--              \--  C                 C linked straight to the leader.
--
-- After every change the whole tree is rebuilt and the results are written onto the characters as attributes
-- (see LinkData for the list), so the clients, the VFX and the other scripts (Source, Burn, Shielding, Stilling) only
-- have to read an attribute. They never touch the tables in here.
--
-- WHAT A LINK DOES TO THE LEADER (the end weaver):
--   MaxSource  + (100 + the linker's level) for every linker           (applied here)
--   Regen      x (1 + 0.5 per linker), no passive cap, no natural drain  (applied in SourceSetup)
-- WHAT IT DOES TO EVERYONE IN THE LINK (leader and linkers):
--   Burn doesn't go up (WeavingModule + SourceSetup), immune to Shielding (ShieldingScript), immune to Stilling (next weave)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local LinkData = require(Modules:WaitForChild("LinkData"))

local LinkService = {}

local MAX_DEPTH = 32 -- safety net so a bug can never turn into an endless loop

local parentOf = {}  -- [linker char] = the char they linked to
local children = {}  -- [char] = { [linker char] = true }

local function getRoot(char)
	local node, guard = char, 0
	while parentOf[node] and guard < MAX_DEPTH do
		node = parentOf[node]
		guard += 1
	end
	return node
end

local function levelOf(char)
	local player = Players:GetPlayerFromCharacter(char)
	local stats = player and player:FindFirstChild("leaderstats")
	local level = stats and stats:FindFirstChild("Level")
	return level and level.Value or 1
end

-- keeps the MaxSource bonus in step with what the links say it should be
local function applySourceBonus(char, bonus)
	local applied = char:GetAttribute("LinkSourceBonus") or 0
	if applied == bonus then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local maxSource = hum and hum:FindFirstChild("MaxSource")
	if not maxSource then return end
	maxSource.Value += bonus - applied -- (SourceSetup clamps Source down if the max shrinks)
	char:SetAttribute("LinkSourceBonus", if bonus ~= 0 then bonus else nil)
end

-- recompute every number in ONE tree and write it onto the characters
local function rebuild(root)
	local order = {}   -- { { char, count } } in no particular order
	local bonus = 0

	local function walk(node, depth)
		local count = 0
		if children[node] and depth < MAX_DEPTH then
			for child in children[node] do
				if child.Parent then
					count += 1 + walk(child, depth + 1)
					bonus += LinkData.SourceBonusFor(levelOf(child))
				end
			end
		end
		table.insert(order, { char = node, count = count })
		return count
	end
	walk(root, 0)

	local leaderPlayer = Players:GetPlayerFromCharacter(root)
	local leaderId = leaderPlayer and leaderPlayer.UserId

	for _, entry in order do
		local node = entry.char
		local linked = entry.count > 0 or parentOf[node] ~= nil
		node:SetAttribute("Link", entry.count)
		node:SetAttribute("Linked", linked)
		node:SetAttribute("LinkLeader", node == root and entry.count > 0)
		node:SetAttribute("LinkLeaderId", if linked then leaderId else nil)
		applySourceBonus(node, if node == root then bonus else 0)
		if not linked then
			node:SetAttribute("LinkWeave", nil)
		end
	end
end

-- READERS ------------------------------------------------------------------------------------------------
function LinkService.GetParent(char)
	return parentOf[char]
end

-- the END of the chain this weaver belongs to (the weaver themselves if they aren't linked to anyone)
function LinkService.GetLeader(char)
	return getRoot(char)
end

-- every linker below this weaver (direct and indirect)
function LinkService.GetLinkers(char)
	local list = {}
	local function walk(node, depth)
		if not children[node] or depth >= MAX_DEPTH then return end
		for child in children[node] do
			table.insert(list, child)
			walk(child, depth + 1)
		end
	end
	walk(char, 0)
	return list
end

-- SERVER SIDE CAST GATE for link weaves: every weave with RequiresLink = true should start its server handler with
--     if not LinkService.CanCast(player.Character, Dictionary[WEAVE]) then return end
-- (the client checks too, but only this one can be trusted)
function LinkService.CanCast(char, weaveData)
	return LinkData.CheckRequirement(char, weaveData)
end

-- WRITERS ------------------------------------------------------------------------------------------------
-- `linker` links to `target`. A weaver can only have one link going out; they must let go before linking elsewhere.
-- Linking to somebody who is already linked just joins that chain, so the END weaver collects everyone.
function LinkService.Add(linker, target)
	if linker == target then return false, "You can't link to yourself" end
	if parentOf[linker] then return false, "Already linked" end

	-- no loops: the target must not be somebody who (directly or not) is linked to the linker
	local node, guard = target, 0
	while node and guard < MAX_DEPTH do
		if node == linker then return false, "That would make a loop" end
		node = parentOf[node]
		guard += 1
	end

	parentOf[linker] = target
	children[target] = children[target] or {}
	children[target][linker] = true
	rebuild(getRoot(target))
	return true
end

-- `linker` lets go. Whoever was linked to THEM stays linked to them, so a broken chain splits into two chains.
function LinkService.Remove(linker)
	local parent = parentOf[linker]
	if not parent then return false end

	parentOf[linker] = nil
	if children[parent] then
		children[parent][linker] = nil
		if next(children[parent]) == nil then
			children[parent] = nil
		end
	end

	rebuild(getRoot(parent)) -- the chain they left
	rebuild(linker)          -- and the chain that was hanging off them (or just them, alone)
	return true
end

-- a weaver died / left: cut every link going in or out of them
function LinkService.Purge(char)
	if not char then return end
	LinkService.Remove(char)
	if children[char] then
		local direct = {}
		for child in children[char] do
			table.insert(direct, child)
		end
		for _, child in direct do
			LinkService.Remove(child)
		end
	end
	children[char] = nil
	parentOf[char] = nil
	char:SetAttribute("LinkWeave", nil)
end

return LinkService
