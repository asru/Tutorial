---@type Mq
local mq = require("mq")

local TLO = mq.TLO
local Me = TLO.Me
local Cursor = TLO.Cursor
local Window = TLO.Window

---@class Scribing
Scribing = {}

local TopInvSlot = 22 + Me.NumBagSlots()
local MyClass = Me.Class.Name()
local MyDeity = Me.Deity()
local isScribing = false

-- --------------------------------------------------------------------------------------------
-- SUB: Event_FinishedScribing
-- --------------------------------------------------------------------------------------------
local function Event_FinishedScribing(_, spell)
	isScribing = false
	PrintDebugMessage(DebuggingRanks.Detail, "finished scribing/learning: %s", spell)
end

mq.event("FinishedScribing", "#*#You have finished scribing #1#", Event_FinishedScribing)
mq.event("FinishedLearning", "#*#You have learned #1#!#*#", Event_FinishedScribing)

local scribing = {}

local function isUsableByClass(item)
    FunctionEnter()

    local isUsable = false

	for i = 1, item.Classes() do
		if (item.Class(i)() == MyClass) then
			isUsable = true

			break
		end
	end

    PrintDebugMessage(DebuggingRanks.Deep, "isUsable: %s", isUsable)
    FunctionDepart()
	return isUsable
end

local function isUsableByDiety(item)
    FunctionEnter()

	local isUsable = item.Deities() == 0

	for i = 1, item.Deities() do
		if (item.Deity(i)() == MyDeity) then
			isUsable = true

			break
		end
	end

    PrintDebugMessage(DebuggingRanks.Deep, "isUsable: %s", isUsable)
    FunctionDepart()
	return isUsable
end

local function isScribed(spellName, spellId)
    FunctionEnter()

	local bookId = Me.Book(spellName)()

	if (not bookId) then
		bookId = Me.CombatAbility(spellName)()
	end

	if (not bookId) then
        PrintDebugMessage(DebuggingRanks.Deep, "is scribed: false - no book id")
        FunctionDepart()
        return false
	end

	if (bookId and not spellId) then
        PrintDebugMessage(DebuggingRanks.Deep, "is scribed: false - no spell id")
        FunctionDepart()
		return true
	end

    PrintDebugMessage(DebuggingRanks.Deep, "bookId: %s", bookId)
    PrintDebugMessage(DebuggingRanks.Deep, "spellId: %s", spellId)
    PrintDebugMessage(DebuggingRanks.Deep, "Me.Book(bookId).ID() == spellId or Me.CombatAbility(bookId).ID() == spellId: %s", Me.Book(bookId).ID() == spellId or Me.CombatAbility(bookId).ID() == spellId)
    FunctionDepart()
	return Me.Book(bookId).ID() == spellId or Me.CombatAbility(bookId).ID() == spellId
end

local function usableInvetoryCount()
    FunctionEnter()

	local count = Me.FreeInventory()

	-- See if there's an empty top inventory slot
	for pack = 23, TopInvSlot do
		local item = Me.Inventory(pack)

		if (item.ID() and item.Container() > 0 and
			(item.Type() == "Quiver" or item.Type() == "Tradeskill Bag" or item.Type() == "Collectible Bag")) then
			count = count - item.Container() + item.Items()
		end
	end

    PrintDebugMessage(DebuggingRanks.Deep, "count: %s", count)
    FunctionDepart()
	return count
end

local function getItem(pack, slot)
    FunctionEnter()

	PrintDebugMessage(DebuggingRanks.Deep, "GetItem pack: %s", pack)
	PrintDebugMessage(DebuggingRanks.Deep, "GetItem slot: %s", slot)
	local item = nil

    if (pack) then
        item = Me.Inventory(pack)
		PrintDebugMessage(DebuggingRanks.Deep, "item (pack): %s", tostring(item))
    end

    if (slot and slot > -1) then
        item = item.Item(slot + 1)
		PrintDebugMessage(DebuggingRanks.Deep, "item (pack/slot): %s", tostring(item))
    end

    FunctionDepart()
	return item
end

local function findFreeInventory()
    FunctionEnter()

	local location = { pack = nil, slot = nil }

	-- See if there's an empty top inventory slot
	for pack = 23, TopInvSlot do
		PrintDebugMessage(DebuggingRanks.Deep, "top pack: %s", tostring(location.pack))
		if (not Me.Inventory(pack).ID()) then
			location.pack = pack

			PrintDebugMessage(DebuggingRanks.Deep, "top pack: %s", tostring(location.pack))
            PrintDebugMessage(DebuggingRanks.Deep, "location - top inventory: %s", location)
            FunctionDepart()
            return location
		end
	end

	-- See if there's an empty bag slot
	for pack = 23, TopInvSlot do
        if (Me.Inventory(pack).Container() > 0) then
			for slot = 1, Me.Inventory(pack).Container() do
				if (not Me.Inventory(pack).Item(slot).ID()) then
					location.pack = pack
					location.slot = slot - 1
		
					PrintDebugMessage(DebuggingRanks.Deep, "bag pack: %s", tostring(location.pack))
					PrintDebugMessage(DebuggingRanks.Deep, "bag slot: %s", tostring(location.slot))
                    PrintDebugMessage(DebuggingRanks.Deep, "location - bag: %s", location)
                    FunctionDepart()
                    return location
				end
			end
        end
	end

    PrintDebugMessage(DebuggingRanks.Deep, "location: nil")
    FunctionDepart()
	return nil
end

local function formatPackLocation(pack, slot)
    FunctionEnter()

	local packLocation = ""

	if (slot and slot > -1) then
		packLocation = "in "
	end

	packLocation = packLocation .. "pack" .. (pack - 22)

	if (slot and slot > -1) then
		packLocation = packLocation .. " " .. (slot + 1)
	end

    PrintDebugMessage(DebuggingRanks.Deep, "packLocation: %s", packLocation)
    FunctionDepart()
	return packLocation
end

local function separateOutSingleItem(itemStack)
    FunctionEnter()

	if (usableInvetoryCount() == 0) then
        PrintDebugMessage(DebuggingRanks.Deep, "item: nil - no usable inventory")
        FunctionDepart()
        return nil
	end

	local location = findFreeInventory()

	if (not location) then
        PrintDebugMessage(DebuggingRanks.Deep, "item: nil - no where to put it")
        FunctionDepart()
        return nil
	end

	local pickupCmd = "/ctrlkey /itemnotify " .. formatPackLocation(itemStack.ItemSlot(), itemStack.ItemSlot2()) .. " leftmouseup"
	local dropCmd = "/itemnotify " .. formatPackLocation(location.pack, location.slot) .. " leftmouseup"

	mq.cmd(pickupCmd)

	Delay(3000, function ()
		return Cursor.ID()
	end)

	mq.cmd(dropCmd)

	Delay(3000, function ()
		return not Cursor.ID()
	end)

    local slot = location.slot

    if (slot) then
        slot = slot + 1
    end

	local item = getItem(location.pack, slot)
	PrintDebugMessage(DebuggingRanks.Deep, "location: %s", location)
	PrintDebugMessage(DebuggingRanks.Deep, "new item from pack: %s, slot: %s", item.ItemSlot(), item.ItemSlot2())

    PrintDebugMessage(DebuggingRanks.Deep, "item: %s", item)
    FunctionDepart()
	return item
end

local function openPack(item)
    FunctionEnter()

	PrintDebugMessage(DebuggingRanks.Deep, "open pack")
	PrintDebugMessage(DebuggingRanks.Deep, "item.ID: %s", item.ID())
	PrintDebugMessage(DebuggingRanks.Deep, "item.ItemSlot2: %s", item.ItemSlot2())
	if (item.ID() and item.ItemSlot2() ~= nil and item.ItemSlot2() > -1) then
		PrintDebugMessage(DebuggingRanks.Deep, "get pack to open in slot: %s", item.ItemSlot())
        local pack = getItem(item.ItemSlot())

		PrintDebugMessage(DebuggingRanks.Deep, "pack open state: %s", pack.Open())
        if (pack.Open() == 0) then
            PrintDebugMessage(DebuggingRanks.Deep, "try to open pack in slot %s", pack.ItemSlot())
            local openCmd = "/itemnotify " .. formatPackLocation(pack.ItemSlot()) .. " rightmouseup"

			mq.cmd(openCmd)

			Delay(3000, function ()
				return pack.Open() == 1
			end)
		end
	end

    FunctionDepart()
end

local function closePack(pack)
    FunctionEnter()

	PrintDebugMessage(DebuggingRanks.Deep, "close pack")
	if (Me.Inventory(pack).Open() == 1) then
		local closeCmd = "/itemnotify " .. formatPackLocation(pack) .. " rightmouseup"

		mq.cmd(closeCmd)

		Delay(3000, function ()
			return Me.Inventory(pack).Open() ~= 0
		end)
	end

    FunctionDepart()
end

local function openBook()
    FunctionEnter()

	--checkPlugin("MQ2Boxr")

	--mq.cmd("/squelch /boxr pause")

	Window("SpellBookWnd").DoOpen()

    FunctionDepart()
end

local function closeBook()
    FunctionEnter()

	if (Window("SpellBookWnd").Open()) then
		Window("SpellBookWnd").DoClose()
	end

	--mq.cmd("/squelch /boxr unpause")

    FunctionDepart()
end

-- --------------------------------------------------------------------------------------------
-- SUB: ScribeItem
-- --------------------------------------------------------------------------------------------
local function scribeItem(item)
    FunctionEnter()

	local spellName = item.Spell.Name()
	local spellId = item.Spell.ID()
	PrintDebugMessage(DebuggingRanks.Deep, "Scribing %s", spellName)

	openPack(item)
	openBook()

	Delay(200)

	local scribeCmd = "/itemnotify " .. formatPackLocation(item.ItemSlot(), item.ItemSlot2()) .. " rightmouseup"
	PrintDebugMessage(DebuggingRanks.Deep, scribeCmd)

	isScribing = true

	mq.cmd(scribeCmd)

	Delay(3000, function ()
        return (Cursor.ID() or Window("ConfirmationDialogBox").Open() or isScribed(spellName, spellId) or not isScribing)
	end)

    PrintDebugMessage(DebuggingRanks.Deep, "check for open confirmation dialog")
	if (Window("ConfirmationDialogBox").Open() and 
		Window("ConfirmationDialogBox").Child("CD_TextOutput").Text():find(Cursor.Spell.Name().." will replace")) then
        PrintDebugMessage(DebuggingRanks.Deep, "click yes to confirm")
        Window("ConfirmationDialogBox").Child("Yes_Button").LeftMouseUp()
    end

    Delay(15000, function ()
        PrintDebugMessage(DebuggingRanks.Deep, "item is still scribing: %s", isScribing)

        return not isScribing
	end)

	if (Cursor.ID()) then
        mq.cmd("/autoinv")
        Delay(200)
        mq.cmd("/autoinv")
    end

    FunctionDepart()
end

local function checkAndScribe(pack, slot)
    FunctionEnter()

	local item = getItem(pack, slot)

    if (item == nil) then
		PrintDebugMessage(DebuggingRanks.Deep, "Didn't find item in pack: %s, slot: %s", pack, slot)

        PrintDebugMessage(DebuggingRanks.Deep, "is scribed: false - item == nil")
        FunctionDepart()
		return false
	end

	PrintDebugMessage(DebuggingRanks.Deep, "item.Name(): %s", item.Name())
	-- printDebugMessage(DebuggingRanks.Deep, "item.Type(): %s", item.Type())
	-- printDebugMessage(DebuggingRanks.Deep, "item.Type() ~= "Scroll": %s", item.Type() ~= "Scroll")
	-- printDebugMessage(DebuggingRanks.Deep, "item.Type() ~= "Tome": %s", item.Type() ~= "Tome")
	-- printDebugMessage(DebuggingRanks.Deep, "(item.Type() ~= "Scroll" and item.Type() ~= "Tome"): %s", (item.Type() ~= "Scroll" and item.Type() ~= "Tome"))
	-- if ((item.Type() == "Scroll" or item.Type() == "Tome")) then
	-- 	printDebugMessage(DebuggingRanks.Deep, "item.Spell.Level(): %d", item.Spell.Level())
	-- 	printDebugMessage(DebuggingRanks.Deep, "MyLevel: %d", MyLevel)
	-- 	printDebugMessage(DebuggingRanks.Deep, "item.Spell.Level() > MyLevel: %s", item.Spell.Level() > MyLevel)
		-- printDebugMessage(DebuggingRanks.Deep, "item.Spell.ID(): %s", item.Spell.ID())
	-- 	printDebugMessage(DebuggingRanks.Deep, "Me.Book(item.Spell.ID()): %s", Me.Book(item.Spell.ID())())
	-- 	printDebugMessage(DebuggingRanks.Deep, "Me.CombatAbility(item.Spell.ID()): %s", Me.CombatAbility(item.Spell.ID())())
	-- end
	if ((item.Type() ~= "Scroll" and item.Type() ~= "Tome") or
		item.Spell.Level() > Me.Level() or
		isScribed(item.Spell.Name(), item.Spell.ID())) then
		PrintDebugMessage(DebuggingRanks.Deep, "failed basic checks")

        PrintDebugMessage(DebuggingRanks.Deep, "is scribed: false - not scroll or tome")
        FunctionDepart()
		return false
	end

	if (not isUsableByClass(item)) then
		PrintDebugMessage(DebuggingRanks.Deep, "not usable by class")

        PrintDebugMessage(DebuggingRanks.Deep, "is scribed: false - not usable by class")
        FunctionDepart()
        return false
	end

	if (not isUsableByDiety(item)) then
		PrintDebugMessage(DebuggingRanks.Deep, "not usable by diety")

        PrintDebugMessage(DebuggingRanks.Deep, "is scribed: false - not usable by diety")
        FunctionDepart()
        return false
	end

	local spellName = item.Spell.Name()
	local spellRank = item.Spell.Rank()

	if (spellRank == 2 and
		(isScribed(spellName .. " Rk. III"))) then
		PrintDebugMessage(DebuggingRanks.Deep, "already have a higher rank spell scribed")

        PrintDebugMessage(DebuggingRanks.Deep, "is scribed: false - already have higher")
        FunctionDepart()
		return false
	elseif (spellRank < 2 and
		(isScribed(spellName .. " Rk. II") or
		isScribed(spellName .. " Rk. III"))) then
		PrintDebugMessage(DebuggingRanks.Deep, "already have a higher rank spell scribed")

        PrintDebugMessage(DebuggingRanks.Deep, "is scribed: false - already have higher")
        FunctionDepart()
		return false
	end

	if (item.StackCount() > 1) then
		item = separateOutSingleItem(item)
---@diagnostic disable-next-line: need-check-nil
		PrintDebugMessage(DebuggingRanks.Deep, "split item from pack: %s, slot: %s", item.ItemSlot(), item.ItemSlot2())
	end

	if (not item) then
		PrintDebugMessage(DebuggingRanks.Deep, "no item to scribe")

        PrintDebugMessage(DebuggingRanks.Deep, "is scribed: false - nothing to scribe")
        FunctionDepart()
        return false
	end

	scribeItem(item)

    PrintDebugMessage(DebuggingRanks.Deep, "is scribed: true")
    FunctionDepart()
	return true
end

--- Scribe any spells that exist on the character
function Scribing.ScribeSpells()
    FunctionEnter()

	if (Cursor.ID()) then
		mq.cmd("/autoinv")
	end

	--|** Opening your inventory for access bag slots **|
	if (not Window("InventoryWindow").Open()) then
		Window("InventoryWindow").DoOpen()
	end

	local scribeCount = 0

	-- Main inventory pack numers are 23-34. 33 & 34 come from add-on perks and may be active for the particular user
	for pack = 23, TopInvSlot do
		--|** Check Top Level Inventory Slot to see if it has something in it **|
		if (Me.Inventory(pack).ID()) then
			--|** Check Top Level Inventory Slot for bag/no bag **|
			if (Me.Inventory(pack).Container() == 0) then
				--|** If it's not a bag do this **|
				if (checkAndScribe(pack)) then
					scribeCount = scribeCount + 1
				end
			else
				--|** If it's a bag do this **|
				for slot = 1, Me.Inventory(pack).Container() do
					if (checkAndScribe(pack, slot - 1)) then
						scribeCount = scribeCount + 1
					end
				end

				closePack(pack)
			end
		end
	end

	closeBook()

    FunctionDepart()
end

return Scribing