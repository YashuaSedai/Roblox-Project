-- LinkData   (ModuleScript, SHARED: the server and the clients both require it)
-- Everything about linking that BOTH sides need to agree on: the numbers, how a link shows up on a character,
-- the "does this weaver have enough links" rule, and the weave-key -> elements -> colors lookup the link VFX uses.
-- (The link STATE itself is owned by the server: ServerScriptService/SYSTEM/LinkService.)
--
-- LINK ATTRIBUTES (set by LinkService on the CHARACTER, read by anything)
--   Link             number  linkers connected BELOW this weaver (direct + indirect). The end weaver's Link counts the whole chain.
--   Linked           bool    this weaver is part of a link (as the leader or as a linker)
--   LinkLeader       bool    this weaver is the END of a chain and has at least one linker
--   LinkLeaderId     number  UserId of the end weaver of the chain this weaver belongs to (nil when not linked)
--   LinkWeave        string  the link weave the LEADER is casting right now, e.g. "FireTornado" (nil when idle).
--                            THE LINK VFX LISTENS TO THIS.
--   LinkSourceBonus  number  bookkeeping: how much MaxSource the links currently add to this weaver

local Players = game:GetService("Players")

local LinkData = {}

-- TUNING ------------------------------------------------------------------------------------------------
LinkData.SOURCE_BONUS_BASE = 100        -- every linker adds (SOURCE_BONUS_BASE + that linker's level) to the leader's MaxSource
LinkData.REGEN_BONUS_PER_LINK = 0.5     -- the leader's Source regeneration is multiplied by (1 + this * number of linkers)
LinkData.LINGER = 1.5                   -- seconds LinkWeave stays set after the leader lets go (so the color is visible)

-- WEAVE KEY DIGITS -> ELEMENT NAMES (the same mapping WeavingModule uses; "0" is an empty slot)
LinkData.ELEMENT_BY_DIGIT = {
	["1"] = "Fire", ["2"] = "Water", ["3"] = "Earth", ["4"] = "Air", ["5"] = "Spirit",
}
LinkData.ALL_ELEMENTS = { "Fire", "Water", "Earth", "Air", "Spirit" }

-- THE ELEMENT COLORS (the link beams read these, so this is the only place to change them)
LinkData.ELEMENT_COLORS = {
	Fire   = Color3.fromRGB(255, 66, 33),
	Water  = Color3.fromRGB(105, 158, 255),
	Earth  = Color3.fromRGB(120, 255, 99),
	Air    = Color3.fromRGB(255, 184, 134),
	Spirit = Color3.fromRGB(255, 255, 255),
}

-- STATE READERS (work on the server and on clients, they only read attributes) --------------------------
function LinkData.IsLinked(char: Model?): boolean
	return char ~= nil and char:GetAttribute("Linked") == true
end

function LinkData.GetLinkCount(char: Model?): number
	return char and tonumber(char:GetAttribute("Link")) or 0
end

function LinkData.IsLeader(char: Model?): boolean
	return char ~= nil and char:GetAttribute("LinkLeader") == true
end

-- the leader's Source regeneration multiplier
function LinkData.RegenMultiplier(linkCount: number): number
	return 1 + LinkData.REGEN_BONUS_PER_LINK * math.max(linkCount, 0)
end

-- how much MaxSource ONE linker adds to the leader
function LinkData.SourceBonusFor(linkerLevel: number): number
	return LinkData.SOURCE_BONUS_BASE + linkerLevel
end

-- THE REQUIREMENT: can this character cast this weave right now?
-- Dictionary fields:  RequiresLink = true   and (optional)  LinksRequired = number  (default 1)
-- Only the LEADER (the end of the chain) can cast link weaves, and they need at least LinksRequired links.
-- Returns  ok, reasonText
function LinkData.CheckRequirement(char: Model?, weaveData): (boolean, string?)
	if not weaveData or not weaveData.RequiresLink then
		return true
	end
	if not char or not LinkData.IsLeader(char) then
		return false, "You must be the leader of a link to cast this"
	end
	local needed = weaveData.LinksRequired or 1
	local have = LinkData.GetLinkCount(char)
	if have < needed then
		return false, `This weave needs {needed} link(s), you have {have}`
	end
	return true
end

-- LINK VFX HELPERS --------------------------------------------------------------------------------------
local function getDictionary()
	local weaving = script.Parent:WaitForChild("WeavingModule")
	return require(weaving:WaitForChild("Dictionary"))
end

-- The elements in a weave, in slot order (duplicates kept): "41414" -> { "Air", "Fire", "Air", "Fire", "Air" }
-- Pass the weave NAME (that's what the leader's LinkWeave attribute holds). Unknown / nil / "" gives ALL five elements,
-- which is the link's idle look.
function LinkData.GetElements(weaveName: string?): { string }
	local data = weaveName and weaveName ~= "" and getDictionary()[weaveName]
	local key = data and data.WeaveKey
	if type(key) ~= "string" then
		return table.clone(LinkData.ALL_ELEMENTS)
	end
	local elements = {}
	for i = 1, #key do
		local element = LinkData.ELEMENT_BY_DIGIT[key:sub(i, i)]
		if element then
			table.insert(elements, element)
		end
	end
	if #elements == 0 then
		return table.clone(LinkData.ALL_ELEMENTS)
	end
	return elements
end

-- Same as GetElements but without repeats, in first-seen order: "41414" -> { "Air", "Fire" }
function LinkData.GetUniqueElements(weaveName: string?): { string }
	local seen, unique = {}, {}
	for _, element in LinkData.GetElements(weaveName) do
		if not seen[element] then
			seen[element] = true
			table.insert(unique, element)
		end
	end
	return unique
end

-- Colors for a weave, one per element (duplicates kept, so "41414" gives air, fire, air, fire, air)
function LinkData.GetColors(weaveName: string?): { Color3 }
	local colors = {}
	for _, element in LinkData.GetElements(weaveName) do
		table.insert(colors, LinkData.ELEMENT_COLORS[element])
	end
	return colors
end

-- A ColorSequence ready to drop into a Beam / Trail / ParticleEmitter
function LinkData.GetColorSequence(weaveName: string?): ColorSequence
	local colors = LinkData.GetColors(weaveName)
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

return LinkData
