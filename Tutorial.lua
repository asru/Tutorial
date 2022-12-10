--Tutorial.lua by Rouneq
--Based on Tutorial.mac by Chatwiththisname and Cannonballdex
--v0.99.1
--
--Purpose:  Will conduct the tutorial for the current character
--			from immediately after character creation
--			to completing all steps (required and optional)
--			in both "Basic Training" and "The Revolt of Gloomingdeep"
--
--Usage: /lua run Tutorial [option]
--
--       where option can be "nopause" (sans double-quotes)

---@type Mq
local mq = require("mq")
---@type Note
local Note = require("lib.Note")
---@type ImGui
require("ImGui")
local ICON = require("lib.icons")
---@type Stack
local Stack = require("lib.Stack")

Note.prefix = "tutorial"
Note.outfile = string.format("Tutorial_%s.log", mq.TLO.Me.CleanName())

Note.useOutfile = true
Note.appendToOutfile = false
Note.Info("Begin logging")
Note.appendToOutfile = true
Note.useOutfile = false

local TLO = mq.TLO
local Me = TLO.Me
local Cursor = TLO.Cursor
local Spawn = TLO.Spawn
local Target = TLO.Target
local Merchant = TLO.Merchant
local Ground = TLO.Ground
local Group = TLO.Group
local Window = TLO.Window
local Navigation = TLO.Navigation
local MoveTo = TLO.MoveTo
local Zone = TLO.Zone
local Mercenary = TLO.Mercenary
local Pet = TLO.Pet
local Math = TLO.Math
local EQ = TLO.EverQuest

require("lib.ICaseTable")

---@enum DebuggingRanks
local DebuggingRanks = {
	None = 0,
	Basic = 1,
	Task = 2,
	Detail = 3,
	Function = 4,
	Deep = 5,
}
local DebuggingText = {
	[DebuggingRanks.None] = "None",
	[DebuggingRanks.Basic] = "Basic",
	[DebuggingRanks.Task] = "Task",
	[DebuggingRanks.Detail] = "Detail",
	[DebuggingRanks.Function] = "Function",
	[DebuggingRanks.Deep] = "Deep",
}

local debuggingValues = {
	---@type DebuggingRanks
	DebugLevel = DebuggingRanks.Basic,
	---@type boolean|nil
	StepProcessing = false,
	---@type boolean|nil
	SkipRemainingSteps = false,
	LockStep = true,
	WaitingForStep = false,
	ActionTaken = false,
	---@type boolean|nil
	ShowTimingInConsole = Note.useTimestampConsole,
	---@type boolean|nil
	LogOutput = Note.useOutfile,
	CallStack = Stack:Create(),
}
local currentDebugLevel = debuggingValues.DebugLevel

local workSet = {
	---@type boolean|nil
	ResumeProcessing = true,
	---@type boolean
	LockContinue = true,
	WaitingForResume = false,

	---@type boolean|nil
    UseGui = true,
	---@type boolean|nil
    DrawGui = true,

	-- Edit Do you want to temporarily move away from mobs when hp gets lower than 50% true OR false
	---@type boolean
	MoveAway = true,
	-- Edit At what pct HP do you want to move away
	---@type integer
	MoveAwayHP = 50,

	---@type string[]
	Targets = {},
	---@type spawnType
	TargetType = "NPC",
	---@type integer
	PullRange = 1000,
	---@type integer
	ZRadius = 1000,
	---@type integer
	HealAt = 70,
	---@type integer
	HealTill = 100,
	---@type integer
	MedAt = 30,
	---@type integer
	MedTill = 100,
	---@type integer
	DpsLImiter = 0,
	---@type integer
	MyTargetID = 0,
	---@type string
	FarmMob = "",
	---@type integer
	ReportTarget = os.time() + 5,
	---@type string
	Location = "",
	---@type integer
	TopInvSlot = 22 + Me.NumBagSlots(),
	---@type string
	MyClass = Me.Class.Name(),
	---@type string
	MyDeity = Me.Deity(),
	---@type boolean
	Scribing = false,
	---@type integer
	PetGem = 8,
	---@type string
	ChatTitle = "",
	---@type string
	Task = "",
}

---@class Location
---@field Y number
---@field X number
---@field Z number

---@type table<string, Location>
local navLocs = {
	RatBat = {Y = -520, X = -378, Z = -38 },
	SpiderRoom = { Y = -658, X = -367, Z = -58 },
	QueenRoom = { Y = -1046, X = -482, Z = 1 },
	PitTop = { Y = -463, X = -812, Z = 2 },
}

---@type table<string, Location>
local safeSpace = {
	SpiderRoom = { Y = -955, X = -658, Z = -23 },
	QueenRoom = { Y = -1163, X = -536, Z = -8 },
	PitTop = { Y = -226, X = -834, Z = 2 },
	PitSteps = { Y = -226, X = -834, Z = 2 },
	SlaveHall1 = { Y = -226, X = -834, Z = 2 },
	SlaveHall2 = { Y = -87, X = -626, Z = 12 },
	SlaveArea = { Y = -87, X = -626, Z = 12 },
	JailEntry = { Y = -87, X = -626, Z = 12 },
	JailHall1 = { Y = -87, X = -626, Z = 12 },
	Jail1 = { Y = -201, X = -805, Z = 24 },
	LocksmithHall = { Y = 598, X = -259, Z = -10 },
	Jail2 = { Y = 598, X = -259, Z = -10 },
	JailHall2 = { Y = 598, X = -259, Z = -10 },
	SlaveMaster = { Y = 598, X = -259, Z = -10 },
}

---@type table<string, TargetInfo>
local knownTargets = {
	infiltrator = {
		Name = "Infiltrator",
		Type = "NPC",
	},
	rufus = {
		Name = "Rufus",
		Type = "NPC",
		Priority = 1
	},
	caveRat = {
		Name = "a_cave_rat",
		Type = "NPC",
	},
	caveBat = {
		Name = "a_cave_bat",
		Type = "NPC",
	},
	verminNest = {
		Name = "a_vermin_nest",
		Type = "Object",
	},
	venomfang = {
		Name = "Venomfang",
		Type = "NPC",
		Priority = 1
	},
	gloomSpider = {
		Name = "a_gloom_spider",
		Type = "NPC",
	},
	lurkerSpider = {
		Name = "a_gloomfang_lurker",
		Type = "NPC",
	},
	spiderCocoon = {
		Name = "a_spider_cocoon_cluster",
		Type = "NPC",
	},
	gugan = {
		Name = "Spider_Tamer_Gugan",
		Type = "NPC",
	},
	gloomfang = {
		Name = "Queen_Gloomfang",
		Type = "NPC",
	},
	barrel = {
		Name = "a_kobold_barrel",
		Type = "Object",
	},
	goblinSlave = {
		Name = "a_goblin_slave",
		Type = "NPC",
	},
	rookfynn = {
		Name = "Rookfynn",
		Type = "NPC",
	},
	grunt = {
		Name = "a_Gloomingdeep_grunt",
		Type = "NPC",
	},
	warrior = {
		Name = "a_Gloomingdeep_warrior",
		Type = "NPC",
	},
	slaveWarden = {
		Name = "a_Gloomingdeep_slave_warden",
		Type = "NPC",
		Priority = 14
	},
	spiritweaver = {
		Name = "a_Gloomingdeep_spiritweaver",
		Type = "NPC",
	},
	brokenclaw = {
		Name = "Brokenclaw",
		Type = "NPC",
		Priority = 13
	},
	captain = {
		Name = "a_Gloomingdeep_captain",
		Type = "NPC",
	},
	selandoor = {
		Name = "Selandoor",
		Type = "NPC",
		Priority = 1
	},
	silver = {
		Name = "Silver",
		Type = "NPC",
		Priority = 1
	},
	diseasedRat = {
		Name = "a_diseased_rat",
		Type = "NPC",
	},
	ratasaurus = {
		Name = "Ratasaurus",
		Type = "NPC",
		Priority = 1
	},
	gnikan = {
		Name = "Overlord_Gnikan",
		Type = "NPC",
	},
	locksmith = {
		Name = "The_Gloomingdeep_Locksmith",
		Type = "NPC",
	},
	plaguebearer = {
		Name = "a_Gloomingdeep_plaguebearer",
		Type = "NPC",
	},
	guard = {
		Name = "Guard_of_Gloomingdeep",
		Type = "NPC",
	},
	ruga = {
		Name = "Slavemaster_Ruga",
		Type = "NPC",
		Priority = 1
	},
	pox = {
		Name = "Pox",
		Type = "NPC",
		Priority = 2
	},
	krenshin = {
		Name = "Krenshin",
		Type = "NPC",
		Priority = 2
	},
}

local lootedItems = {}
local destroyList = {}

---@type table<integer, true>
local noPathList = {}

local function delay(timeout, condition)
    if ((not timeout and not condition) or type(timeout) ~= "number") then
        return
    end

    if (not condition) then
        mq.delay(timeout)

        return
    end

    local predicate = function ()
        mq.doevents()

        return condition()
    end

    mq.delay(timeout, predicate)
end

---@param minLevel DebuggingRanks
---@param message string
---@vararg any
local function printDebugMessage(minLevel, message, ...)
	if (debuggingValues.DebugLevel >= minLevel) then
		Note.Info(message, ...)
	end
end

local function setChatTitle(text)
	mq.cmd.setchattitle(text)
	workSet.ChatTitle = text
end

---@param minLevel? DebuggingRanks
local function functionEnter(minLevel)
	if (not minLevel) then
		minLevel = DebuggingRanks.Function
	end

	local callerName = debug.getinfo(2, "n").name
	printDebugMessage(minLevel, "\at%s enter", callerName)
	debuggingValues.CallStack:push(callerName)

	if (minLevel == DebuggingRanks.Task) then
		workSet.Task = callerName
	end
end

---@param minLevel? DebuggingRanks
local function functionDepart(minLevel)
	if (not minLevel) then
		minLevel = DebuggingRanks.Function
	end

	local callerName = debug.getinfo(2, "n").name
	printDebugMessage(minLevel, "\at%s depart", callerName)
	debuggingValues.CallStack:pop()

	if (minLevel == DebuggingRanks.Task) then
		workSet.Task = ""
	end
end

local function checkPlugin(plugin)
	if (not TLO.Plugin(plugin)()) then
        printDebugMessage(DebuggingRanks.Deep, "\aw%s\ar not detected! \aw This script requires it! Loading ...", plugin)
        mq.cmdf("/squelch /plugin %s noauto", plugin)
		delay(1000, function()
			return TLO.Plugin(plugin)()
		end)
		if (not TLO.Plugin(plugin)()) then
			Note.Info("Required plugin \aw%s\ax did not load! \ar Ending the script", plugin)
			mq.exit()
		end
	end
end

local function checkStep()
	debuggingValues.DebugLevel = currentDebugLevel
	Note.useTimestampConsole = false

	if (debuggingValues.StepProcessing and debuggingValues.ActionTaken) then
		printDebugMessage(DebuggingRanks.None, "Pause before the next step, use \aw/step\ax to continue")

		while (debuggingValues.LockStep) do
			debuggingValues.WaitingForStep = true
			mq.doevents()
			delay(100)
		end

		debuggingValues.LockStep = true
		debuggingValues.WaitingForStep = false
	end

	debuggingValues.ActionTaken = false
end

local function checkContinue()
	if (workSet.ResumeProcessing) then
		printDebugMessage(DebuggingRanks.None, "Tutorial paused for spell/skill updates. Visit the approprate merchant to buy, scribe, and load or replace spells/skills. Use \aw/resume\ax to continue")

		while (workSet.LockContinue) do
			workSet.WaitingForResume = true
			mq.doevents()
			delay(100)
		end

		workSet.LockContinue = true
		workSet.WaitingForResume = false
	end
end

---@param classes string[]
---@return boolean
local function isClassMatch(classes)
	for _, class in ipairs(classes) do
		if (Me.Class.ShortName() == class) then
			return true
		end
	end

	return false
end

---@param spawn spawn
local function targetSpawn(spawn)
	functionEnter()

	if (spawn.ID() > 0) then
		spawn.DoTarget()

		delay(2000, function ()
			return Target.ID() == spawn.ID()
		end)

		delay(250)
	end

	functionDepart()
end

---@param targetId integer
local function targetSpawnById(targetId)
	functionEnter()
	printDebugMessage(DebuggingRanks.Detail, "Target spawn: \ay%s", targetId)

	local spawn = Spawn("id " .. targetId)

	targetSpawn(spawn)

	functionDepart()
end

---@param targetName string
local function targetSpawnByName(targetName)
	functionEnter()
	printDebugMessage(DebuggingRanks.Detail, "Target spawn: \ay%s", targetName)

	local spawn = Spawn(targetName)

	targetSpawn(spawn)

	functionDepart()
end

local function casting()
	functionEnter()

	delay(1000, function ()
		return Window("CastingWindow").Open()
	end)

	while ((Me.Casting.ID() and not isClassMatch({"BRD"})) or Window("CastingWindow").Open()) do
		delay(100)
	end

	functionDepart()
end

local function checkZone()
	functionEnter()

	if (Zone.ID() ~= 188 and Zone.ID() ~= 189) then
		Note.Info("\arYou're not in the tutorial. Ending the macro!")
		mq.exit()
	end

	functionDepart()
end

local function openTaskWnd()
	functionEnter()

	if (not Window("TaskWnd").Open()) then
		mq.cmd.keypress("ALT+Q")
		delay(1000, function()
			return Window("TaskWnd").Open()
		end)
		delay(100)
	end

	functionDepart()
end

---@param itemName string
---@param action string
local function grabItem(itemName, action)
	functionEnter()

	---@type string
	local keypress = ""
	if (action == "left") then
		keypress = "leftmouseup"
	else
		keypress = "rightmouseup"
	end

	local item = TLO.FindItem(itemName)
	local baseCmd = "/squelch /nomodkey /ctrl /itemnotify"
	local itemDetail

	if (item.ItemSlot() < 23 or item.ItemSlot2() == nil or item.ItemSlot2() == -1) then
		itemDetail = string.format("\"%s\"", item.Name())
	else
		itemDetail = string.format("in pack%s %s", item.ItemSlot() - 22, item.ItemSlot2() + 1)
	end

	mq.cmdf("%s %s %s", baseCmd, itemDetail, keypress)

	functionDepart()
end

---@param itemName string
local function destroyItem(itemName)
	functionEnter()

	while (TLO.FindItemCount(itemName)() > 0) do
		grabItem(itemName, "left")

		mq.cmd.destroy()

		delay(1000, function ()
			return not Cursor.ID()
		end)
	end

	functionDepart()
end

--- Determine which top-level inventory slot is available for placing an item
---@return integer
local function getAvailableTopInvSlot()
	functionEnter()

    -- Find the first top-level inventory slot without anything in it
    for i = 1, Me.NumBagSlots() do
        local inv = TLO.InvSlot("pack" .. i).Item

        if (not inv.Container() and not inv.ID()) then
            return i
        end
    end

    -- Find the first top-level inventory slot without a container in it
    for i = 1, Me.NumBagSlots() do
        local inv = TLO.InvSlot("pack" .. i).Item

        if (not inv.Container()) then
            return i
        end
    end

	functionDepart()
    return 0
end

--- Determine which bag has an available inventory slot for the size specified
---@param size integer
---@return integer
local function getAvailableBagInvSlot(size)
	functionEnter()

    -- Find the first container which can hold an item of the specified size
    for i = 1, Me.NumBagSlots() do
        local inv = TLO.InvSlot("pack" .. i).Item

        if (inv.Container() and inv.SizeCapacity() >= size) then
            return i
        end
    end

	functionDepart()
    return 0
end

--- Determine which inventory slot is available for placing items
---@param size integer
---@return integer
local function GetAvailableInvSlot(size)
	functionEnter()

    local slot = getAvailableTopInvSlot()

    if (slot > 0) then
        return slot
    end

	functionDepart()
    return getAvailableBagInvSlot(size)
end

--- Either place the item in a specific location in inventory (if specified) or auto place it
---@param packname? string @Location in inventory to receive the item on the cursor
local function invItem(packname)
	functionEnter()

    printDebugMessage(DebuggingRanks.Detail, "packname: %s", packname)
	printDebugMessage(DebuggingRanks.Deep, "Put %s in %s", Cursor.Name(), packname)

    delay(500, function ()
		mq.cmdf("/ctrlkey /itemnotify %s leftmouseup", packname)

        return Cursor.ID() == nil
    end)

	functionDepart()
end

---@param ItemToCast string
local function castItem(ItemToCast)
	functionEnter()

	mq.cmdf("/casting \"%s\"|Item", ItemToCast)
	delay(1000, function()
		return Me.Casting.ID()
	end)
	delay(TLO.FindItem("=" .. ItemToCast).CastTime.TotalSeconds() * 1000, function()
		return not Me.Casting.ID()
	end)

	functionDepart()
end

---@param gem integer
local function castSpell(gem)
	functionEnter()

	if (not Me.Moving()) then
		mq.cmd.cast(gem)
		casting()
	end

	functionDepart()
end

---@param gem integer
local function castThenRetarget(gem)
	functionEnter()

	if (not Me.Moving()) then
		local currentTarget = Target.ID()
		mq.cmd.target(Me.CleanName())
		mq.cmd.cast(gem)
		casting()
		targetSpawnById(currentTarget)
	end

	functionDepart()
end

---@return xtarget|nil
local function getNextXTarget()
	functionEnter()

	-- Pause to give the XTarget window a chance to update
	delay(250)

	for i = 1, Me.XTarget() do
		if (Me.XTarget(i).ID() > 0 and Me.XTarget(i).Type() ~= nil and Me.XTarget(i).Type() ~= "Corpse") then
			printDebugMessage(DebuggingRanks.Detail, "Me.XTarget(%s) ID: %s, Name: %s, Type: %s", i, Me.XTarget(i).ID(), Me.XTarget(i).Name(), Me.XTarget(i).Type())
			functionDepart()

			return Me.XTarget(i)
		end
	end

	functionDepart()
	return nil
end

local function checkSwiftness()
	functionEnter()

	if (not TLO.InvSlot(19).Item.ID() and TLO.FindItemCount(67109)() == 1) then
		grabItem("67109", "left")
		delay(1000)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
	elseif (not TLO.InvSlot(19).Item.ID() and TLO.FindItemCount(67123)() == 1) then
		grabItem("67123", "left")
		delay(1000)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
	elseif (not TLO.InvSlot(19).Item.ID() and TLO.FindItemCount(67116)() == 1) then
		grabItem("67116", "left")
		delay(1000)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
	elseif (not TLO.InvSlot(19).Item.ID() and TLO.FindItemCount(67102)() == 1) then
		grabItem("67102", "left")
		delay(1000)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
	end

	local xtarget = getNextXTarget()

	if (not Me.Buff("Blessing of Swiftness").ID() and xtarget == nil) then
		if (TLO.FindItemCount("=Worn Totem")() > 0 and Me.Buff(TLO.FindItem("=Worn Totem").Spell())() == nil and
			TLO.FindItem("=Worn Totem").TimerReady() == 0 and not Me.Buff("Spirit of Wolf").ID()) then
			if (Navigation.Active()) then
				mq.cmd.nav("stop")
			end

			delay(1500, function()
				return not Me.Moving()
			end)

			castItem("Worn Totem")
		end
	end

	if (isClassMatch({"BRD"}) and not Me.Buff("Selo's Accelerando").ID()) then
		local seloGem = Me.Gem("Selo's Accelerando")()

		if (seloGem) then
			mq.cmd.stopsong()
			mq.cmd.cast(seloGem)
			casting()
		end
	elseif (isClassMatch({"SHM", "DRU"}) and not Me.Buff("Spirit of Wolf").ID() and xtarget == nil) then
		local sowGem = Me.Gem("Spirit of Wolf")()

		if (sowGem) then
			if (Navigation.Active()) then
				mq.cmd.nav("stop")
			end

			delay(1500, function()
				return not Me.Moving()
			end)

			castThenRetarget(sowGem)
		end
	end

	functionDepart()
end

local function whereAmI()
	functionEnter()

	delay(1000)

	if (Zone.ID() == 188) then
		if (workSet.Location ~= "JailBreak") then
			workSet.Location = "JailBreak"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end

		functionDepart()

		return
	end

	local y = Me.Y()
	local x = Me.X()
	local z = Me.Z()

	if ((y >= -298 and y <= 154) and (x >= -309 and x <= 63)) then
		if (workSet.Location ~= "StartArea") then
			workSet.Location = "StartArea"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -447 and y <= -299) and (x >= -386 and x <= -99)) then
		if (workSet.Location ~= "Hall1") then
			workSet.Location = "Hall1"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -614 and y <= -448) and (x >= -430 and x <= -325)) then
		if (workSet.Location ~= "RatBat") then
			workSet.Location = "RatBat"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -685 and y <= -498) and (x >= -384 and x <= -361)) then
		if (workSet.Location ~= "SpiderHall") then
			workSet.Location = "SpiderHall"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -1025 and y <= -685) and (x >= -672 and x <= -204)) then
		if (workSet.Location ~= "SpiderRoom") then
			workSet.Location = "SpiderRoom"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -1238 and y <= -1025) and (x >= -586 and x <= -421)) then
		if (workSet.Location ~= "QueenRoom") then
			workSet.Location = "QueenRoom"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -552 and y <= -497) and (x >= -598 and x <= -431) and (z >= -40 and z <= 5)) then
		if (workSet.Location ~= "Hall2") then
			workSet.Location = "Hall2"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -572 and y <= -420) and (x >= -711 and x <= -598) and (z >= -3 and z <= 10)) then
		if (workSet.Location ~= "RatBat2") then
			workSet.Location = "RatBat2"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -491 and y <= -421) and (x >= -819 and x <= -711) and (z >= -3 and z <= 10)) then
		if (workSet.Location ~= "Hall3") then
			workSet.Location = "Hall3"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -640 and y <= -210) and (x >= -1079 and x <= -820) and (z >= -3 and z <= 10)) then
		if (workSet.Location ~= "PitTop") then
			workSet.Location = "PitTop"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -570 and y <= -444) and (x >= -994 and x <= -884) and (z >= -60 and z <= -2)) then
		if (workSet.Location ~= "PitSteps") then
			workSet.Location = "PitSteps"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -567 and y <= -383) and (x >= -889 and x <= -661) and (z >= -93 and z <= -54)) then
		if (workSet.Location ~= "PitTunnel1") then
			workSet.Location = "PitTunnel1"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -490 and y <= -322) and (x >= -797 and x <= -645) and (z >= -86 and z <= -69)) then
		if (workSet.Location ~= "Rookfynn") then
			workSet.Location = "Rookfynn"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -708 and y <= -563) and (x >= -971 and x <= -750) and (z >= -86 and z <= -53)) then
		if (workSet.Location ~= "PitTunnel2") then
			workSet.Location = "PitTunnel2"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -857 and y <= -613) and (x >= -757 and x <= -628) and (z >= -81 and z <= -77)) then
		if (workSet.Location ~= "PitMine") then
			workSet.Location = "PitMine"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -456 and y <= -306) and (x >= -1166 and x <= -993) and (z >= -146 and z <= -114)) then
		if (workSet.Location ~= "PitTunnel3") then
			workSet.Location = "PitTunnel3"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -579 and y <= -415) and (x >= -1234 and x <= -1087) and (z >= -133 and z <= -116)) then
		if (workSet.Location ~= "Krenshin") then
			workSet.Location = "Krenshin"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -648 and y <= -446) and (x >= -1487 and x <= -1078) and (z >= -32 and z <= 4)) then
		if (workSet.Location ~= "GloomingdeepMines") then
			workSet.Location = "GloomingdeepMines"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -498 and y <= -231) and (x >= -1574 and x <= -1260) and (z >= -105 and z <= -26)) then
		if (workSet.Location ~= "MiningHall") then
			workSet.Location = "MiningHall"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -445 and y <= -79) and (x >= -1941 and x <= -1573)) then
		if (workSet.Location ~= "GloomingdeepFort") then
			workSet.Location = "GloomingdeepFort"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -217 and y <= -77) and (x >= -899 and x <= -857)) then
		if (workSet.Location ~= "SlaveHall1") then
			workSet.Location = "SlaveHall1"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -77 and y <= 68) and (x >= -960 and x <= -853)) then
		if (workSet.Location ~= "SlaveArea") then
			workSet.Location = "SlaveArea"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -58 and y <= -38) and (x >= -853 and x <= -739)) then
		if (workSet.Location ~= "SlaveHall2") then
			workSet.Location = "SlaveHall2"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -61 and y <= -19) and (x >= -739 and x <= -658)) then
		if (workSet.Location ~= "JailEntry") then
			workSet.Location = "JailEntry"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -110 and y <= 12) and (x >= -658 and x <= -523)) then
		if (workSet.Location ~= "ScoutArea") then
			workSet.Location = "ScoutArea"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= -21 and y <= 77) and (x >= -712 and x <= -693)) then
		if (workSet.Location ~= "JailHall1") then
			workSet.Location = "JailHall1"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= 76 and y <= 326) and (x >= -812 and x <= -511)) then
		if (workSet.Location ~= "Jail1") then
			workSet.Location = "Jail1"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= 190 and y <= 417) and (x >= -512 and x <= -326)) then
		if (workSet.Location ~= "LocksmithHall") then
			workSet.Location = "LocksmithHall"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= 413 and y <= 522) and (x >= -491 and x <= -195)) then
		if (workSet.Location ~= "Jail2") then
			workSet.Location = "Jail2"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= 413 and y <= 585) and (x >= -323 and x <= -361)) then
		if (workSet.Location ~= "JailHall2") then
			workSet.Location = "JailHall2"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	elseif ((y >= 582 and y <= 868) and (x >= -516 and x <= -170)) then
		if (workSet.Location ~= "SlaveMaster") then
			workSet.Location = "SlaveMaster"
			Note.Info("\awLocation:\ag%s", workSet.Location)
		end
	else
		if (workSet.Location ~= "Unknown") then
			workSet.Location = "Unknown"
			Note.Info("\awLocation:\ag%s (%.2f,%.2f,%.2f)", workSet.Location, y, x, z)
		end
	end

	functionDepart()
end

local function checkSelfBuffs()
	functionEnter()

	if (Me.Gem(1).ID() and Me.GemTimer(1)() == 0) then
		if (isClassMatch({ "NEC", "WIZ" }) and not Me.Buff("Shielding").ID() and Me.PctMana() > 20) then
			castSpell(1)
		elseif (isClassMatch({ "DRU" }) and not Me.Buff("Gloomingdeep Guard").ID() and not Me.Buff("Skin like Wood").ID() and
			not Me.Buff("Inner Fire").ID() and Me.PctMana() > 20) then
			castThenRetarget(1)
		elseif (isClassMatch({ "CLR", "RNG", "PAL", "BST", "SHM" }) and Me.PctHPs() < 30 and Me.PctMana() > 20) then
			castThenRetarget(1)
		end
	end

	if (Me.Gem(2).ID() and Me.GemTimer(2)() == 0) then
		if (isClassMatch({ "MAG", "ENC" }) and not Me.Buff("Shielding").ID() and Me.PctMana() > 20) then
			castSpell(2)
		elseif (isClassMatch({ "SHM" }) and not Me.Buff("Gloomingdeep Guard").ID() and not Me.Buff("Skin like Wood").ID() and
			not Me.Buff("Inner Fire").ID() and Me.PctMana() > 20) then
			castThenRetarget(2)
		elseif (isClassMatch({ "CLR" }) and not Me.Buff("Gloomingdeep Guard").ID() and not Me.Buff("Courage").ID()) then
			castThenRetarget(2)
		end
	end

	functionDepart()
end

local function checkCombatCasting()
	functionEnter()

	if (Me.Gem(1).ID() and Me.GemTimer(1)() == 0) then
		if (isClassMatch({ "MAG", "ENC", "SHD" }) and Target.ID() > 0 and Target.Type() ~= "Object" and Target.Distance() < 30 and Me.PctMana() > 20 and os.time() > workSet.DpsLImiter) then
			castSpell(1)
			workSet.DpsLImiter = os.time() + 10
		elseif (isClassMatch({ "CLR", "RNG", "PAL", "BST", "SHM" }) and Me.PctHPs() < 30 and Me.PctMana() > 20) then
			castThenRetarget(1)
		elseif (isClassMatch({ "BRD" }) and not Me.Song("Chant of Battle").ID()) then
			mq.cmd.stopsong()
			mq.cmd.cast(1)
			casting()
		end
	end

	if (Me.Gem(2).ID() and Me.GemTimer(2)() == 0) then
		if (isClassMatch({ "WIZ" }) and Target.ID() > 0 and Target.Type() ~= "Object"  and Target.Distance() < 30 and Me.PctMana() > 20 and os.time() > workSet.DpsLImiter) then
			castSpell(2)
			workSet.DpsLImiter = os.time() + 10
		elseif (isClassMatch({ "NEC" }) and Target.ID() > 0 and Target.Type() ~= "Object"  and Target.Distance() < 30 and Me.PctMana() > 20 and os.time() > workSet.DpsLImiter) then
			castSpell(2)
			workSet.DpsLImiter = os.time() + 10
		elseif (isClassMatch({ "DRU" }) and Me.PctHPs() < 30 and Me.PctMana() > 20) then
			castThenRetarget(2)
		end
	end

	if (Me.Gem(3).ID() and Me.GemTimer(3)() == 0) then
		if (isClassMatch({ "CLR" }) and not Me.Buff("Yaulp").ID() and Me.PctMana() > 20) then
			castSpell(3)
		end
	end

	functionDepart()
end

local function closeDialog()
	functionEnter()

	delay(1000, function()
		return Window("LargeDialogWindow").Open()
	end)

	if (Window("LargeDialogWindow").Open()) then
		Window("LargeDialogWindow").Child("LDW_OkButton").LeftMouseUp()
		delay(1000, function()
			return not Window("LargeDialogWindow").Open()
		end)
		delay(100)
	end

	functionDepart()
end

---@param checkFor string
---@return boolean
local function tutorialCheck(checkFor)
	printDebugMessage(DebuggingRanks.Function, "\attutorialCheck enter")
	printDebugMessage(DebuggingRanks.Function, "checkFor: \ag%s", checkFor)

	local returnValue = false
	local taskList = Window("TaskWND").Child("Task_TaskList")

	printDebugMessage(DebuggingRanks.Deep, "Number of tasks: %s", taskList.Items())

	for i = 1, taskList.Items() do
		printDebugMessage(DebuggingRanks.Deep, "Checking task: \at%s", taskList.List(i, 3)())
		printDebugMessage(DebuggingRanks.Deep, "Task = checkFor: \ay%s", taskList.List(i, 3)() == checkFor)

		if (taskList.List(i, 3)() == checkFor) then
			returnValue = true
			break
		end
	end

	printDebugMessage(DebuggingRanks.Function, "\attutorialCheck depart")
	return returnValue
end

---@param checkFor string
---@return boolean
local function tutorialSelect(checkFor)
	printDebugMessage(DebuggingRanks.Function, "\attutorialSelect enter")
	printDebugMessage(DebuggingRanks.Function, "checkFor: \ag%s", checkFor)

	local returnValue = false
	local taskList = Window("TaskWND").Child("Task_TaskList")

	printDebugMessage(DebuggingRanks.Deep, "Number of tasks: %s", taskList.Items())

	for i = 1, taskList.Items() do
		printDebugMessage(DebuggingRanks.Deep, "Checking task: \at%s", taskList.List(i, 3)())
		printDebugMessage(DebuggingRanks.Deep, "Task = checkFor: \ay%s", taskList.List(i, 3)() == checkFor)

		if (taskList.List(i, 3)() == checkFor) then
			taskList.Select(i)
			delay(2000, function ()
				return taskList.GetCurSel() == i
			end)

			returnValue = true

			break
		end
	end

	printDebugMessage(DebuggingRanks.Function, "\attutorialSelect depart")
	return returnValue
end

---@param y number
---@param x number
---@param z number
local function basicNavToLoc(y, x, z)
	functionEnter()

	local destLoc = string.format("%s,%s,%s", y, x, z)

	if (Navigation.PathExists(string.format("locyxz %s", destLoc))) then
		printDebugMessage(DebuggingRanks.Function, "Nav to Y: %s, X: %s, Z: %s", y, x, z)

		while (Math.Distance(destLoc)() > 15) do
			checkSwiftness()
			checkSelfBuffs()
			whereAmI()

			if (Navigation.Active()) then
				delay(100)
			else
				mq.cmdf("/squelch /nav locyxz %s %s %s", y, x, z)
			end
		end

		if (Navigation.Active()) then
			mq.cmd.nav("stop")
		end
	end

	functionDepart()
end

local function basicNavToSpawn(spawnId)
	functionEnter()
	printDebugMessage(DebuggingRanks.Function, "spawnId: %s", spawnId)

	checkSwiftness()
	checkSelfBuffs()

	local navSpawn = Spawn("id " .. spawnId)

	if (navSpawn.ID() == 0 or (navSpawn.Type() == "Corpse" or navSpawn.Type() == nil)) then
		functionDepart()

		return
	end

	mq.cmdf("/squelch /nav id %s", spawnId)
	setChatTitle("Navigating to add " .. navSpawn.CleanName())

	while (navSpawn.ID() > 0 and navSpawn.Distance() > 30) do
		delay(100)

		if (not Navigation.Active()) then
			mq.cmdf("/squelch /nav id %s", spawnId)
		end
	end
end

local function gotoSpiderHall()
	functionEnter(DebuggingRanks.Task)

	basicNavToLoc(-670, -374, -65)
	mq.cmd.face("loc -595,-373,-40")
	mq.cmd.keypress("forward hold")
	delay(1000)
	mq.cmd.keypress("forward")

	functionDepart(DebuggingRanks.Task)
end

local function basicBlessing()
	functionEnter()

	if (not Me.Buff("Gloomingdeep Guard").ID()) then
		local rytan = Spawn("Rytan")

		basicNavToSpawn(rytan.ID())
		targetSpawnById(rytan.ID())

		mq.cmd.say("Blessed")
		delay(100)

		closeDialog()
		closeDialog()
		closeDialog()

		delay(1000, function()
			return Me.Buff("Gloomingdeep Guard").ID()
		end)

		mq.cmd("/squelch /target clear")
	end

	functionDepart()
end

local function amIDead()
	functionEnter()

	local optionsList = Window("RespawnWnd").Child("RW_OptionsList")

	if (Me.Dead() and optionsList.List(1, 2) == "Bind Location") then
		Note.Info("\arYOU~ have died! Waiting for YOU to get off your face.")
		setChatTitle("You died, get back up")

		optionsList.Select(1)
		delay(2000, function ()
			return optionsList.GetCurSel() == 1
		end)

		Window("RespawnWnd").Child("RW_SelectButton").LeftMouseUp()

		delay(1000, function()
			return not Me.Hovering()
		end)

		mq.cmd("/squelch /target clear")
		basicBlessing()
		mq.cmd("/squelch /target clear")
	end

	functionDepart()
end

local function findSafeSpot()
	printDebugMessage(DebuggingRanks.Task, "Look for safe spot to rest in the \ag%s\ax area", workSet.Location)

	if (workSet.Location == "SpiderRoom" or workSet.Location == "QueenRoom") then
		gotoSpiderHall()
	else
		local safeSpot = safeSpace[workSet.Location]

		printDebugMessage(DebuggingRanks.Task, "%s", safeSpot)

		if (safeSpot ~= nil) then
			printDebugMessage(DebuggingRanks.None, "Moving to a safe place to regain health")
			printDebugMessage(DebuggingRanks.Basic, "PathExists: %s", Navigation.PathExists(string.format("loc %s %s %s", safeSpot.Y, safeSpot.X, safeSpot.Z)))
			basicNavToLoc(safeSpot.Y, safeSpot.X, safeSpot.Z)
		else
			printDebugMessage(DebuggingRanks.Task, "No safe spot found, rest here")
		end
	end
end

local function medToFull()
	functionEnter()

	if (Zone.ID() == 188) then
		return
	end

	setChatTitle("Waiting on YOUR health to reach " .. workSet.HealTill .. "%")

	while ((Me.PctHPs() < workSet.HealTill or (Me.PctMana() < workSet.MedTill and Me.Class.CanCast())) and getNextXTarget() == nil) do
		if (Me.PctHPs() < workSet.HealTill and isClassMatch({ "CLR", "RNG", "PAL", "BST", "SHM" }) and Me.GemTimer(1)() == 0 and Me.PctMana() > 20) then
			mq.cmd.target(Me.CleanName())
			mq.cmd.cast(1)
			casting()
			mq.cmd("/squelch /target clear")
		elseif (Me.PctHPs() < workSet.HealTill and isClassMatch({ "DRU" }) and Me.GemTimer(2)() == 0 and Me.PctMana() > 20) then
			mq.cmd.target(Me.CleanName())
			mq.cmd.cast(2)
			casting()
			mq.cmd("/squelch /target clear")
		elseif (Me.PctHPs() < workSet.HealTill and isClassMatch({ "BRD" }) and not Me.Song("Hymn of Restoration")() and Me.Gem("Hymn of Restoration")()) then
			mq.cmd.stopsong()
			mq.cmd.cast(Me.Gem("Hymn of Restoration")())
			casting()
		elseif ((Me.Standing()) and (not Me.Casting.ID() or isClassMatch({"BRD"})) and (not Me.Mount.ID())) then
			Me.Sit()
		end

		delay(100)
	end

	functionDepart()
end

local function checkPersonalHealth()
	functionEnter()

	if (Me.PctHPs() < workSet.HealAt) then
		Note.Info("\arYOU are low on Health!")

		if (TLO.FindItemCount("=Distillate of Celestial Healing II")() > 0 and
			not Me.Buff(TLO.FindItem("=Elixir of Healing II").Spell())() == nil and
			TLO.FindItem("=Distillate of Celestial Healing II").TimerReady() == 0) then
			mq.cmd.useitem("Distillate of Celestial Healing II")
		end

		findSafeSpot()

		medToFull()
	end

	functionDepart()
end

local function checkPersonalMana()
	if (Me.PctMana() < workSet.MedAt and Me.Class.CanCast()) then
		Note.Info("\arYOU are low on mana!")
		setChatTitle("Waiting on YOUR mana to reach " .. workSet.MedTill .. "%")

		findSafeSpot()

		medToFull()
	end
end

-- --------------------------------------------------------------------------------------------
-- SUB: GroupDeathChk
-- --------------------------------------------------------------------------------------------
local function checkGroupDeath()
	functionEnter()
	amIDead()

	local xtarget = getNextXTarget()

	if (xtarget ~= nil) then
		functionDepart()

		return
	end

	if (Me.Grouped()) then
		for i = 1, Group.Members() do
			if (Group.Member(i).State == "Hovering") then
				Note.Info("%s has died. Waiting for them to get off their face.", Group.Member(i).Name())
				setChatTitle(Group.Member(i).Name() .. " has died. Waiting for Rez")

				if (xtarget == nil) then
					while (Group.Member(i).State == "Hovering" and xtarget == nil) do
						if ((Me.Standing()) and (not Me.Casting.ID()) and (not Me.Mount.ID())) then
							Me.Sit()
						end

						for j = 1, Group.Members() do
							if (Group.Member(j).Standing() and Group.Member(j).Type() ~= "Mercenary") then
								mq.cmdf("/dex %s /sit", Group.Member(j).Name())
							end
						end

						delay(100)

						xtarget = getNextXTarget()
					end
				end
			end
		end
	end
	functionDepart()
end

-- --------------------------------------------------------------------------------------------
-- SUB: GroupManaChk
-- --------------------------------------------------------------------------------------------
local function checkGroupMana()
	functionEnter()

	local xtarget = getNextXTarget()

	if (xtarget ~= nil) then
		functionDepart()

		return
	end

	amIDead()

	if (not Me.Combat()) then
		setChatTitle("Group Mana Check")
		checkPersonalMana()

		if (Me.Grouped()) then
			for i = 1, Group.Members() do
				if ((not Group.Member(i).Dead() and not Group.Member(i).OtherZone() and Group.Member(i).PctMana() < workSet.MedAt) and (Group.Member(i).Class.CanCast())) then
					Note.Info("\ar%s is low on mana!", Group.Member(i).Name())
					setChatTitle("Waiting on " .. Group.Member(i).Name() .. "'s mana to reach " .. workSet.MedTill .. "%")

					if (xtarget == nil) then
						while (not Group.Member(i).Dead() and Group.Member(i).PctMana() < workSet.MedTill and xtarget == nil) do
							if (Me.Standing() and not Me.Casting.ID() and not Me.Mount.ID()) then
								Me.Sit()
							end

							delay(100)

							xtarget = getNextXTarget()
						end
					end
				end
			end
		end
	end

	functionDepart()
end

-- --------------------------------------------------------------------------------------------
-- SUB: GroupHealthChk
-- --------------------------------------------------------------------------------------------
local function checkGroupHealth()
	functionEnter()

	local xtarget = getNextXTarget()

	if (xtarget ~= nil) then
		functionDepart()

		return
	end

	amIDead()

	setChatTitle("Group Health Check")

	if (not Me.Combat()) then
		checkPersonalHealth()

		if (Me.Grouped()) then
			for i = 1, Group.Members() do
				if (Group.Member(i).ID() and not Group.Member(i).Dead()) then
					if (not Group.Member(i).OtherZone() and Group.Member(i).PctHPs() < workSet.HealAt) then
						Note.Info("%s is low on Health!", Group.Member(i).Name())
						setChatTitle("Waiting on " .. Group.Member(i).Name() .. " health to reach " .. workSet.HealTill .. "%")
						if (xtarget == nil) then
							while (not Group.Member(i).Dead() and Group.Member(i).PctHPs() < workSet.HealTill and xtarget == nil) do
								if ((Me.Standing()) and (not Me.Casting.ID()) and (not Me.Mount.ID())) then
									Me.Sit()
								end

								for j = 1, Group.Members() do
									if (Group.Member(j).Standing() and Group.Member(j).Type() ~= "Mercenary") then
										mq.cmdf("/dex %s /sit", Group.Member(j).Name())
									end
								end

								delay(100)

								xtarget = getNextXTarget()
							end
						end
					end
				end
			end
		end
	end

	functionDepart()
end

local function checkMerc()
	functionEnter()

	if (Mercenary.State() ~= "ACTIVE") then
		if (Me.Grouped() and Window("MMGW_ManageWnd").Child("MMGW_SuspendButton").Tooltip() == "Revive your current mercenary." and
				Window("MMGW_ManageWnd").Child("MMGW_SuspendButton").Enabled()) then
			Window("MMGW_ManageWnd").Child("MMGW_SuspendButton").LeftMouseUp()
		end
	end

	if (Mercenary.State() == "ACTIVE" and Mercenary.Stance() == "Passive") then
		mq.cmd("/stance Aggressive")
		Note.Info("Setting Mercenary to Aggressive")
	end

	functionDepart()
end

local function checkPet()
	functionEnter()

	if (Me.Pet.ID() == 0 and Me.Gem(workSet.PetGem).ID()) then
		local needPet = false

		if (isClassMatch({"MAG"}) and Me.Level() >= 4) then
			needPet = true
		elseif (isClassMatch({"NEC"}) and Me.Level() >= 4) then
			needPet = true
		elseif (isClassMatch({"BST"}) and Me.Level() >= 8) then
			needPet = true
		end

		if (needPet) then
			if (Navigation.Active()) then
				mq.cmd.nav("stop")
			end

			delay(1500, function()
				return not Me.Moving()
			end)

			delay(350)

			mq.cmd.cast(workSet.PetGem)
			casting()
		end
	end

	functionDepart()
end

local function checkAllAccessNag()
	if (Window("AlertWnd")) then
		Window("AlertWnd").Child("ALW_Dismiss_Button").LeftMouseUp()
	end

	if (Window("AlertStackWnd") and not Window("AlertWnd")) then
		Window("ALSW_Alerts_Box").Child("ALSW_AlertTemplate_Button").LeftMouseUp()
	end
end

---@param spawnId integer
---@param combatRoutine? fun(spawnId: integer)
local function navToSpawn(spawnId, combatRoutine)
	functionEnter()
	printDebugMessage(DebuggingRanks.Function, "spawnId: %s", spawnId)

	checkSwiftness()
	checkSelfBuffs()

	local navSpawn = Spawn("id " .. spawnId)

	if (navSpawn.ID() == 0 or (navSpawn.Type() == "Corpse" or navSpawn.Type() == nil)) then
		functionDepart()

		return
	end

	mq.cmdf("/squelch /nav id %s", spawnId)
	setChatTitle("Navigating to spawn " .. navSpawn.CleanName())
	printDebugMessage(DebuggingRanks.Function, "navSpawn ID: %s", navSpawn.ID())
	printDebugMessage(DebuggingRanks.Function, "navSpawn Distance: %s", navSpawn.Distance())

	while (navSpawn.ID() > 0 and navSpawn.Distance() > 30) do
		amIDead()
		whereAmI()
		delay(100)
		local xtarget = getNextXTarget()

		if (xtarget == nil) then
			checkMerc()
			checkPet()
			checkAllAccessNag()
		else
			if (Navigation.Active()) then
				mq.cmd.nav("stop")
			end

			if (combatRoutine) then
				local holdTargetType = workSet.TargetType
				local holdTarget = workSet.MyTargetID
				workSet.TargetType = xtarget.Type()

				combatRoutine(xtarget.ID())

				workSet.MyTargetID = holdTarget
				workSet.TargetType = holdTargetType
			end

			if (Me.Combat() and xtarget == nil) then
				mq.cmd("/squelch /target clear")
			end

			delay(100)
		end

		if (not Navigation.Active()) then
			mq.cmdf("/squelch /nav id %s", spawnId)
		end
	end

	functionDepart()
end

---@param spawnId integer
local function findAndKill(spawnId)
	functionEnter()
	printDebugMessage(DebuggingRanks.Function, "spawnId: %s", spawnId)
	workSet.MyTargetID = spawnId

	amIDead()

	local killSpawn = Spawn(workSet.MyTargetID)
	local xtarget

	while (killSpawn() and killSpawn.ID() > 0 and killSpawn.Distance() > 30) do
		if (killSpawn.TargetOfTarget.ID() > 0 or killSpawn.Type() == "Corpse") then
			functionDepart()

			return
		end

		xtarget = getNextXTarget()

		if (xtarget and xtarget.ID() ~= spawnId) then
			local holdTarget = workSet.MyTargetID
			local holdTargetType = workSet.TargetType
			workSet.TargetType = xtarget.Type()

			findAndKill(xtarget.ID())

			workSet.MyTargetID = holdTarget
			workSet.TargetType = holdTargetType
		end

		navToSpawn(workSet.MyTargetID, findAndKill)
	end

	if ((Target.ID() == 0 or Target.ID() ~= workSet.MyTargetID) and workSet.MyTargetID ~= 0 and xtarget == nil) then
		printDebugMessage(DebuggingRanks.Basic, "I'm targeting %s, ID: %s", killSpawn.CleanName(), workSet.MyTargetID)
		targetSpawnById(workSet.MyTargetID)
	end

	delay(100)

	local waitingOnDeadMob = true

	while (waitingOnDeadMob) do
		if ((Target.ID() > 0 and Target.Type() == workSet.TargetType)) then
			if (waitingOnDeadMob and Target.Distance() < 30) then
				if (Navigation.Active()) then
					mq.cmd("/squelch /nav stop")
				end

				if (isClassMatch({"WAR","PAL","SHD"}) or (Me.Grouped() and Group.Member(0).MainTank()) or
					workSet.TargetType == "Object" or Target.CleanName() == knownTargets.spiderCocoon.Name) then
					mq.cmd.stick("8 uw loose moveback")
				end

				setChatTitle("Killing " .. Target.CleanName())
				mq.cmd.attack("on")
				mq.cmd("/mercassist")

				if (Pet.ID() > 0 and Pet.Target.ID() ~= Target.ID()) then
					mq.cmd.pet("attack")
				end

				delay(1000)
			elseif (waitingOnDeadMob and Target.Distance() >= 30) then
				navToSpawn(workSet.MyTargetID, findAndKill)
			end

			checkCombatCasting()

			local targetSpawn = Spawn("id " .. Target.ID())
			printDebugMessage(DebuggingRanks.Detail, "targetSpawn ID: %s", targetSpawn.ID())
			printDebugMessage(DebuggingRanks.Detail, "targetSpawn Name: %s", targetSpawn.Name())

			printDebugMessage(DebuggingRanks.Deep, "targetSpawn.ID == 0: %s", targetSpawn.ID() == 0)
			printDebugMessage(DebuggingRanks.Deep, "targetSpawn.Type == \"Corpse\": %s", targetSpawn.Type() == "Corpse")
			if (targetSpawn.ID() == 0 or targetSpawn.Type() == "Corpse") then
				mq.cmd("/squelch /target clear")
				waitingOnDeadMob = false
			else
				printDebugMessage(DebuggingRanks.Deep, "targetSpawn.Distance < 30: %s", targetSpawn.Distance() and targetSpawn.Distance() < 30)
				printDebugMessage(DebuggingRanks.Deep, "Me.PctHPs < workSet.moveawayhp: %s", Me.PctHPs() < workSet.MoveAwayHP)
				printDebugMessage(DebuggingRanks.Deep, "workSet.moveaway: %s", workSet.MoveAway)
				printDebugMessage(DebuggingRanks.Deep, "Mercenary.State == \"ACTIVE\": %s", Mercenary.State() == "ACTIVE")
				printDebugMessage(DebuggingRanks.Deep, "Target.PctAggro > 99: %s", Target.ID() > 0 and Target.PctAggro() > 99)
				if ((targetSpawn.Distance() < 30 and Me.PctHPs() < workSet.MoveAwayHP and workSet.MoveAway and Mercenary.State() == "ACTIVE") and Target.ID() > 0 and Target.PctAggro() > 99) then
					mq.cmd.attack("off")
					delay(100)
					mq.cmd.keypress("backward hold")
					delay(1000)
					mq.cmd.keypress("forward")
				end
			end
		else
			waitingOnDeadMob = false
		end

		xtarget = getNextXTarget()

		if (not waitingOnDeadMob and xtarget) then
			printDebugMessage(DebuggingRanks.Detail, "Have \aw%s\ax on XTarget", xtarget.Name())

			findAndKill(xtarget.ID())
		end

		delay(100)
	end

	checkGroupHealth()
	checkGroupMana()

	functionDepart()
end

---@param y number
---@param x number
---@param z number
local function navToLoc(y, x, z)
	functionEnter()
	local destLoc = string.format("%s,%s,%s", y, x, z)

	if (Navigation.PathExists(string.format("locyxz %s", destLoc))) then
		printDebugMessage(DebuggingRanks.Function, "Nav to Y: %s, X: %s, Z: %s", y, x, z)
		setChatTitle("Navigating to loc " .. destLoc)

		while (Math.Distance(destLoc)() > 15) do
			checkSwiftness()
			checkSelfBuffs()
			whereAmI()

			local xtarget = getNextXTarget()

			if (xtarget == nil) then
				checkMerc()
				checkPet()
				checkAllAccessNag()
			else
				if (Navigation.Active()) then
					mq.cmd.nav("stop")
				end

				workSet.TargetType = xtarget.Type()
				findAndKill(xtarget.ID())

				if (Me.Combat() and xtarget == nil) then
					mq.cmd("/squelch /target clear")
				end

				delay(100)
			end

			if (not Navigation.Active()) then
				mq.cmdf("/squelch /nav locyxz %s %s %s", y, x, z)
			end
		end

		if (Navigation.Active()) then
			mq.cmd.nav("stop")
		end
	end


	functionDepart()
end

---@param y integer
---@param x integer
---@param z integer
local function moveToWait(y, x, z)
	functionEnter()

	checkSwiftness()
	checkSelfBuffs()

	local loc = string.format("loc %s %s %s", y, x, z)
	mq.cmd.moveto(loc)

	while (MoveTo.Moving()) do
		whereAmI()
		checkMerc()
		checkPet()
		checkAllAccessNag()

		delay(100)
	end

	functionDepart()
end

---@param loc Location
local function navToKnownLoc(loc)
	functionEnter()

	if (loc) then
		navToLoc(loc.Y, loc.X, loc.Z)
	end

	functionDepart()
end

local function checkBlessing()
	functionEnter()

	if (not Me.Buff("Gloomingdeep Guard").ID()) then
		local rytan = Spawn("Rytan")

		navToSpawn(rytan.ID(), findAndKill)
		targetSpawnById(rytan.ID())

		mq.cmd.say("Blessed")
		delay(100)

		closeDialog()
		closeDialog()
		closeDialog()

		delay(1000, function()
			return Me.Buff("Gloomingdeep Guard").ID()
		end)

		mq.cmd("/squelch /target clear")
	end

	functionDepart()
end

---@class TargetInfo
---@field Name string
---@field Type spawnType
---@field Priority integer

---@class MobInfo
---@field Distance number
---@field Type spawnType
---@field Priority integer

---@param spawn spawn
---@return boolean
local function targetValidate(spawn)
    local search = string.format("loc %s %s radius 30 pc notid %s", spawn.X(), spawn.Y(), Me.ID())
    local pcCount = TLO.SpawnCount(search)()
    local groupCount = TLO.SpawnCount(search .. " group")()
    pcCount = pcCount - groupCount;

    if (pcCount > 0) then
        printDebugMessage(DebuggingRanks.Deep, "Players close to target: %s (%s)", spawn.CleanName(), spawn.ID())

        delay(400)

        return false
    end

    return true
end

---@param target TargetInfo
---@param mobList table<integer, MobInfo>
local function findMobsInRange(target, mobList)
	functionEnter()

	local spawnPattern = string.format("noalert 1 targetable radius %s zradius %s", workSet.PullRange, workSet.ZRadius)
	local searchExpression = string.format("%s %s \"%s\"", spawnPattern, target.Type, target.Name)

	if (not mobList) then
		printDebugMessage(DebuggingRanks.Task, "mobList must be initialized")

		return
	end

	local mobsInRange = TLO.SpawnCount(searchExpression)()

	for i = 1, mobsInRange do
		local nearest = TLO.NearestSpawn(i, searchExpression)

		--just in case something dies, ignore mobs without a name
		if (nearest.Name() ~= nil and (nearest.TargetOfTarget.ID() == 0 or nearest.TargetOfTarget.Name() == Me.Mercenary.Name()) and nearest.ConColor() ~= "GREY" and not noPathList[nearest.ID()] and targetValidate(nearest)) then
			printDebugMessage(DebuggingRanks.Deep, "\atFound one — maybe, lets see if it has a path")

			--If there is a path and only if there is a path will I enter the following block statement. This is done to avoid adding mobs to the array that don't have a path.
			if (Navigation.PathExists("id " .. nearest.ID())()) then

				--Now that it's a good mob, add it to the list
				---@type MobInfo
				local mobInfo = {
					Distance = Navigation.PathLength("id " .. nearest.ID())(),
					Type = target.Type,
					Priority = target.Priority or 10
				}
				mobList[nearest.ID()] = mobInfo
				printDebugMessage(DebuggingRanks.Deep, "Found path to \aw%s\ax (\aw%s\ax): %s", nearest.Name(), nearest.ID(), mobInfo)
			else
				noPathList[nearest.ID()] = true

				printDebugMessage(DebuggingRanks.Detail, "\at%s was not a valid pull target.", nearest.Name())
				printDebugMessage(DebuggingRanks.Detail, "\arPathExists: %s, Distance3D: %s, PathLength: %s", Navigation.PathExists("id " .. nearest.ID())(),
					nearest.Distance3D(), Navigation.PathLength("id " .. nearest.ID())())
			end
		end
	end

	functionDepart()
end

local function tableCount(tbl)
	local count = 0
  	for _ in pairs(tbl) do count = count + 1 end
  	return count
end

---@param mobList table<integer, MobInfo>
local function sortMobIds(mobList)
	local keys = {}

	for key in pairs(mobList) do
	  table.insert(keys, key)
	end

	table.sort(keys, function(a, b)
		if (mobList[a].Priority ~= mobList[b].Priority) then
			return mobList[a].Priority < mobList[b].Priority
		end

		return mobList[a].Distance < mobList[b].Distance
	end)

	return keys
end

---@param preferenceMobs? TargetInfo[]
local function targetShortest(preferenceMobs)
	functionEnter()

	local xtarget = getNextXTarget()

	if (xtarget == nil) then
		---@type table<integer, MobInfo>
		local mobList = {}

		if (not preferenceMobs or tableCount(preferenceMobs) == 0) then
			printDebugMessage(DebuggingRanks.Deep, "No preference mobs given, find %s %s in radius of %s and ZRad: %s", workSet.TargetType, workSet.FarmMob, workSet.PullRange, workSet.ZRadius)
			---@type TargetInfo
			local target = {
				Name = workSet.FarmMob,
				Type = workSet.TargetType,
			}
			findMobsInRange(target, mobList)
		else
			printDebugMessage(DebuggingRanks.Deep, "Search list %s in radius of %s and ZRad: %s", preferenceMobs, workSet.PullRange, workSet.ZRadius)
			for _, target in pairs(preferenceMobs) do
				findMobsInRange(target, mobList)
			end
		end

		printDebugMessage(DebuggingRanks.Deep, "There were %s mobs in radius of %s and ZRad: %s", tableCount(mobList), workSet.PullRange, workSet.ZRadius)

		if (tableCount(mobList) > 0) then
			local sortedKeys = sortMobIds(mobList)

			workSet.MyTargetID = sortedKeys[1]
			workSet.TargetType = mobList[workSet.MyTargetID].Type

			--Set the chattitle of the MQ2 window to the macro's status (Suggestion by Kaen01)
			setChatTitle("Going to kill " .. Spawn("id " .. workSet.MyTargetID).CleanName() .. "!")
		else
			workSet.MyTargetID = 0
			workSet.TargetType = "NPC"
		end
	else
		workSet.MyTargetID = xtarget.ID()
		workSet.TargetType = xtarget.Type()
	end

	printDebugMessage(DebuggingRanks.Deep, "targetId: %s", workSet.MyTargetID)
	printDebugMessage(DebuggingRanks.Deep, "targetType: %s", workSet.TargetType)
	functionDepart()
end

---@param enemy? TargetInfo
local function farmStuff(enemy)
	functionEnter()

	if (enemy) then
		workSet.FarmMob = enemy.Name
		workSet.TargetType = enemy.Type

		if (debuggingValues.DebugLevel > DebuggingRanks.None and workSet.ReportTarget < os.time()) then
			Note.Info("Looking for: %s", workSet.FarmMob)
			workSet.ReportTarget = os.time() + 5
		end

		targetShortest({enemy})
		printDebugMessage(DebuggingRanks.Deep, "spawn: %s", Spawn("id " .. workSet.MyTargetID .. " " .. workSet.TargetType).Name())
		Spawn("id " .. workSet.MyTargetID .. " " .. workSet.TargetType).DoTarget()

		delay(3000, function ()
			return Target.ID() == workSet.MyTargetID
		end)
	else
		Note.Info("Attacking anything I can get my grubby paws on.")
	end

	if (Target.Type() == "Corpse") then
		mq.cmd("/squelch /target clear")
	end

	if (Window("RespawnWnd").Open()) then
		checkGroupDeath()
	end

	local xtarget = getNextXTarget()

	if (xtarget == nil or Window("RespawnWnd").Open()) then
		checkGroupDeath()
		checkGroupHealth()
		checkGroupMana()
		checkMerc()
		checkPet()
		checkAllAccessNag()
	end

	local targetSpawn = Spawn("id " .. workSet.MyTargetID)

	if ((targetSpawn.ID() == 0 or targetSpawn.Type() == "Corpse") and xtarget == nil) then
		printDebugMessage(DebuggingRanks.Task, "Getting a target!")

		workSet.MyTargetID = 0

		targetShortest()

		if (debuggingValues.DebugLevel > DebuggingRanks.Basic and workSet.MyTargetID > 0) then
			Note.Info("Target is %s", Spawn("id " .. workSet.MyTargetID))
		end
	end

	findAndKill(workSet.MyTargetID)

	functionDepart()
end

local function navHail(navTargetID)
	functionEnter()
	printDebugMessage(DebuggingRanks.Deep, "Nav and hail spawn id: %s", navTargetID)

	local navSpawn = Spawn("id " .. navTargetID)
	printDebugMessage(DebuggingRanks.Deep, "    spawn name: %s", navSpawn.Name())
	setChatTitle("Navigating to spawn " .. navSpawn.CleanName())

	while (navSpawn.ID() > 0 and navSpawn.Distance() > 15) do
		checkSwiftness()
		checkSelfBuffs()
		whereAmI()

		local xtarget = getNextXTarget()

		if (xtarget == nil) then
			checkMerc()
			checkPet()
			checkAllAccessNag()
		else
			if (Navigation.Active()) then
				mq.cmd.nav("stop")
			end

			workSet.TargetType = xtarget.Type()
			findAndKill(xtarget.ID())

			if (Me.Combat() and xtarget == nil) then
				mq.cmd("/squelch /target clear")
			end

			delay(100)
		end

		if (not Navigation.Active()) then
			mq.cmdf("/squelch /nav id %s", navTargetID)
		end
	end

	if (Navigation.Active()) then
		mq.cmd("/squelch /nav stop")
	end

	targetSpawnById(navTargetID)

	mq.cmd.hail()
	delay(250)

	functionDepart()
end

local function waitNavGround(groundItemName)
	functionEnter()

	local groundItem = Ground.Search(groundItemName)
	local groundLoc = string.format("loc %s %s %s", groundItem.Y(), groundItem.X(), groundItem.Z())
	Note.Info("GroundItemName: %s Distance: %s", groundItemName, groundItem.Distance3D())
	while (groundItem.Distance3D() > 15) do
		if (Navigation.Active()) then
			delay(100)
		else
			mq.cmd.nav(groundLoc)
		end
	end
	if (Navigation.Active()) then
		mq.cmd.nav("stop")
	end
	Note.Info("GroundItemName: %s Distance: %s", groundItemName, groundItem.Distance3D())
	Ground.Search(groundItemName).DoTarget()
	delay(100)
	Ground.Search(groundItemName).Grab()
	delay(1000, function()
		return Cursor.ID() ~= nil
	end)
	delay(100)
	mq.cmd.autoinventory()
	delay(100)

	functionDepart()
end

---@param taskName string
local function acceptTask(taskName)
	functionEnter()

	delay(15000, function()
		return Window("TaskSelectWnd").Open()
	end)

	local taskList = Window("TaskSelectWnd").Child("TSEL_TaskList")

	printDebugMessage(DebuggingRanks.Deep, "Number of available tasks: %s", taskList.Items())

	for i = 1, taskList.Items() do
		printDebugMessage(DebuggingRanks.Deep, "Checking task: \at%s", taskList.List(i, 1)())
		printDebugMessage(DebuggingRanks.Deep, "Task = taskName: \ay%s", taskList.List(i, 1)() == taskName)

		if (taskList.List(i, 1)() == taskName) then
			taskList.Select(i)
			delay(5000, function ()
				return taskList.GetCurSel() == i
			end)

			break
		end
	end

	if (taskList.List(taskName, 1)() == taskList.GetCurSel()) then
		Window("TaskSelectWnd").Child("TSEL_AcceptButton").LeftMouseUp()

		delay(5000, function()
			return not Window("TaskSelectWnd").Open()
		end)

		delay(5000, function ()
			return tutorialCheck(taskName)
		end)
	end

	functionDepart()
end

local function getReward()
	functionEnter()

	delay(15000, function()
		return Window("RewardSelectionWnd").Open()
	end)
	delay(1000)

	local giveUpTime = os.time() + (Window("RewardSelectionWnd/RewardPageTabWindow").TabCount() * 5)

	while (Window("RewardSelectionWnd").Open() and os.time() < giveUpTime) do
		Window("RewardSelectionWnd/RewardPageTabWindow").Tab(1).Child("RewardSelectionChooseButton").LeftMouseUp()
		delay(1000, function()
			return Cursor.ID()
		end)

		if (Cursor.ID()) then
			mq.cmd.autoinventory()
			delay(1000, function()
				return not Cursor.ID()
			end)
			delay(100)
		end
	end

	functionDepart()
end

local function Lyndroh()
	functionEnter(DebuggingRanks.Task)

	if (TLO.FindItemCount(32601)() < 2) then
		navHail(Spawn("Lyndroh").ID())

		Target.RightClick()
		delay(100, function()
			return Window("bigbankwnd").Open()
		end)

		mq.cmd("/nomodkey /itemnotify bank1 leftmouseup")
		delay(100, function()
			return TLO.FindItemCount(32601)() == 2
		end)
		delay(1000)

		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end

		closeDialog()
		closeDialog()

		grabItem("Crescent Reach Guild Summons", "left")

		mq.cmd("/autobank")

		delay(1500, function ()
			return not Cursor.ID()
		end)
	end

	functionDepart(DebuggingRanks.Task)
end

local function Poxan()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(21, 2)() ~= "Done") then
		navHail(Spawn("Poxan").ID())

		closeDialog()
		closeDialog()

		waitNavGround("Defiance")
		navHail(Spawn("Poxan").ID())
		delay(500)

		grabItem("Poxan's Sword", "left")
		delay(1000, function()
			return Cursor.ID()
		end)
		mq.cmd.usetarget()
		delay(1000, function()
			return not Cursor.ID()
		end)

		Window("GiveWnd").Child("GVW_Give_Button").LeftMouseUp()
		delay(1000, function()
			return not Window("GiveWnd").Open()
		end)
		delay(100)

		if (Cursor.ID()) then
			mq.cmd.autoinventory()
			delay(100)
		end

		closeDialog()
		closeDialog()
	end

	functionDepart(DebuggingRanks.Task)
end

local function Farquard()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(17, 2)() ~= "Done") then
		if (not tutorialCheck("Achievements")) then
			navHail(Spawn("Scribe Farquard").ID())
			closeDialog()
			acceptTask("Achievements")
		end

		if (tutorialSelect("Achievements")) then
			mq.cmd.hail()
			delay(100)
			closeDialog()
			closeDialog()
			closeDialog()
			closeDialog()
			closeDialog()
			delay(200)
			mq.cmd("/achievement")
			getReward()
		end

		tutorialSelect("Basic Training")
	end

	functionDepart(DebuggingRanks.Task)
end

---@param itemName string
---@param containerSlot integer
local function placeItemInContainer(itemName, containerSlot)
	functionEnter()

	grabItem(itemName, "left")
	delay(1000, function ()
		return Cursor.ID()
	end)
	mq.cmdf("/nomodkey /itemnotify enviro%s leftmouseup", containerSlot)
	delay(1000, function ()
		return not Cursor.ID()
	end)

	functionDepart()
end

local function makeRatSteaks()
	functionEnter()

	mq.cmd.say("rat steaks")
	delay(2000, function ()
		mq.cmd.autoinventory()
		return not Cursor.ID()
	end)
	mq.cmd("/squelch /ItemTarget \"Oven\"")
	delay(100)
	mq.cmd("/squelch /click left item")
	delay(5000, function ()
		return Window("TradeSkillWnd").Open()
	end)
	mq.cmd("/notify TradeskillWnd COMBW_ExperimentButton leftmouseup")
	delay(250)
	placeItemInContainer("Rat Meat", 1)
	placeItemInContainer("Cooking Sauce", 2)
	mq.cmd("/notify ContainerCombine_Items Container_Combine leftmouseup")
	delay(2000, function ()
		return Cursor.ID()
	end)
	mq.cmd.autoinventory()
	delay(2000, function ()
		return not Cursor.ID()
	end)

	functionDepart()
end

local function Frizznik()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(11, 2)() ~= "Done") then
		navHail(Spawn("Frizznik").ID())
		closeDialog()
		makeRatSteaks()
		closeDialog()
		closeDialog()
		closeDialog()
		closeDialog()

		grabItem("Rat Steak", "right")
	end

	functionDepart(DebuggingRanks.Task)
end

local function LuclinPriest()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(23, 2)() ~= "Done") then
		navHail(Spawn("Priest of Luclin").ID())
	end

	functionDepart(DebuggingRanks.Task)
end

local function Wijdan()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(13, 2)() ~= "Done") then
		navHail(Spawn("Wijdan").ID())
		closeDialog()
	end

	functionDepart(DebuggingRanks.Task)
end

local function Rashere()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(19, 2)() ~= "Done") then
		navHail(Spawn("Rashere").ID())
		mq.cmd.say("bind my soul")
		closeDialog()
		delay(400)
	end

	functionDepart(DebuggingRanks.Task)
end

-- --------------------------------------------------------------------------------------------
-- SUB: Event_FinishedScribing
-- --------------------------------------------------------------------------------------------
local function Event_FinishedScribing(_, spell)
	workSet.Scribing = false
	printDebugMessage(DebuggingRanks.Detail, "finished scribing/learning: %s", spell)
end

mq.event("FinishedScribing", "#*#You have finished scribing #1#", Event_FinishedScribing)
mq.event("FinishedLearning", "#*#You have learned #1#!#*#", Event_FinishedScribing)

local scribing = {}

function scribing.isUsableByClass(item)
    functionEnter()

    local isUsable = false

	for i = 1, item.Classes() do
		if (item.Class(i)() == workSet.MyClass) then
			isUsable = true

			break
		end
	end

    printDebugMessage(DebuggingRanks.Deep, "isUsable: %s", isUsable)
    functionDepart()
	return isUsable
end

function scribing.isUsableByDiety(item)
    functionEnter()

	local isUsable = item.Deities() == 0

	for i = 1, item.Deities() do
		if (item.Deity(i)() == workSet.MyDeity) then
			isUsable = true

			break
		end
	end

    printDebugMessage(DebuggingRanks.Deep, "isUsable: %s", isUsable)
    functionDepart()
	return isUsable
end

function scribing.isScribed(spellName, spellId)
    functionEnter()

	local bookId = Me.Book(spellName)()

	if (not bookId) then
		bookId = Me.CombatAbility(spellName)()
	end

	if (not bookId) then
        printDebugMessage(DebuggingRanks.Deep, "is scribed: false - no book id")
        functionDepart()
        return false
	end

	if (bookId and not spellId) then
        printDebugMessage(DebuggingRanks.Deep, "is scribed: false - no spell id")
        functionDepart()
		return true
	end

    printDebugMessage(DebuggingRanks.Deep, "bookId: %s", bookId)
    printDebugMessage(DebuggingRanks.Deep, "spellId: %s", spellId)
    printDebugMessage(DebuggingRanks.Deep, "Me.Book(bookId).ID() == spellId or Me.CombatAbility(bookId).ID() == spellId: %s", Me.Book(bookId).ID() == spellId or Me.CombatAbility(bookId).ID() == spellId)
    functionDepart()
	return Me.Book(bookId).ID() == spellId or Me.CombatAbility(bookId).ID() == spellId
end

function scribing.usableInvetoryCount()
    functionEnter()

	local count = Me.FreeInventory()

	-- See if there's an empty top inventory slot
	for pack = 23, workSet.TopInvSlot do
		local item = Me.Inventory(pack)

		if (item.ID() and item.Container() > 0 and
			(item.Type() == "Quiver" or item.Type() == "Tradeskill Bag" or item.Type() == "Collectible Bag")) then
			count = count - item.Container() + item.Items()
		end
	end

    printDebugMessage(DebuggingRanks.Deep, "count: %s", count)
    functionDepart()
	return count
end

function scribing.getItem(pack, slot)
    functionEnter()

	printDebugMessage(DebuggingRanks.Deep, "GetItem pack: %s", pack)
	printDebugMessage(DebuggingRanks.Deep, "GetItem slot: %s", slot)
	local item = nil

    if (pack) then
        item = Me.Inventory(pack)
		printDebugMessage(DebuggingRanks.Deep, "item (pack): %s", tostring(item))
    end

    if (slot and slot > -1) then
        item = item.Item(slot + 1)
		printDebugMessage(DebuggingRanks.Deep, "item (pack/slot): %s", tostring(item))
    end

    functionDepart()
	return item
end

function scribing.findFreeInventory()
    functionEnter()

	local location = { pack = nil, slot = nil }

	-- See if there's an empty top inventory slot
	for pack = 23, workSet.TopInvSlot do
		printDebugMessage(DebuggingRanks.Deep, "top pack: %s", tostring(location.pack))
		if (not Me.Inventory(pack).ID()) then
			location.pack = pack

			printDebugMessage(DebuggingRanks.Deep, "top pack: %s", tostring(location.pack))
            printDebugMessage(DebuggingRanks.Deep, "location - top inventory: %s", location)
            functionDepart()
            return location
		end
	end

	-- See if there's an empty bag slot
	for pack = 23, workSet.TopInvSlot do
        if (Me.Inventory(pack).Container() > 0) then
			for slot = 1, Me.Inventory(pack).Container() do
				if (not Me.Inventory(pack).Item(slot).ID()) then
					location.pack = pack
					location.slot = slot - 1
		
					printDebugMessage(DebuggingRanks.Deep, "bag pack: %s", tostring(location.pack))
					printDebugMessage(DebuggingRanks.Deep, "bag slot: %s", tostring(location.slot))
                    printDebugMessage(DebuggingRanks.Deep, "location - bag: %s", location)
                    functionDepart()
                    return location
				end
			end
        end
	end

    printDebugMessage(DebuggingRanks.Deep, "location: nil")
    functionDepart()
	return nil
end

function scribing.formatPackLocation(pack, slot)
    functionEnter()

	local packLocation = ""

	if (slot and slot > -1) then
		packLocation = "in "
	end

	packLocation = packLocation .. "pack" .. (pack - 22)

	if (slot and slot > -1) then
		packLocation = packLocation .. " " .. (slot + 1)
	end

    printDebugMessage(DebuggingRanks.Deep, "packLocation: %s", packLocation)
    functionDepart()
	return packLocation
end

function scribing.separateOutSingleItem(itemStack)
    functionEnter()

	if (scribing.usableInvetoryCount() == 0) then
        printDebugMessage(DebuggingRanks.Deep, "item: nil - no usable inventory")
        functionDepart()
        return nil
	end

	local location = scribing.findFreeInventory()

	if (not location) then
        printDebugMessage(DebuggingRanks.Deep, "item: nil - no where to put it")
        functionDepart()
        return nil
	end

	local pickupCmd = "/ctrlkey /itemnotify " .. scribing.formatPackLocation(itemStack.ItemSlot(), itemStack.ItemSlot2()) .. " leftmouseup"
	local dropCmd = "/itemnotify " .. scribing.formatPackLocation(location.pack, location.slot) .. " leftmouseup"

	mq.cmd(pickupCmd)

	delay(3000, function ()
		return Cursor.ID()
	end)

	mq.cmd(dropCmd)

	delay(3000, function ()
		return not Cursor.ID()
	end)

    local slot = location.slot

    if (slot) then
        slot = slot + 1
    end

	local item = scribing.getItem(location.pack, slot)
	printDebugMessage(DebuggingRanks.Deep, "location: %s", location)
	printDebugMessage(DebuggingRanks.Deep, "new item from pack: %s, slot: %s", item.ItemSlot(), item.ItemSlot2())

    printDebugMessage(DebuggingRanks.Deep, "item: %s", item)
    functionDepart()
	return item
end

function scribing.openPack(item)
    functionEnter()

	printDebugMessage(DebuggingRanks.Deep, "open pack")
	printDebugMessage(DebuggingRanks.Deep, "item.ID: %s", item.ID())
	printDebugMessage(DebuggingRanks.Deep, "item.ItemSlot2: %s", item.ItemSlot2())
	if (item.ID() and item.ItemSlot2() ~= nil and item.ItemSlot2() > -1) then
		printDebugMessage(DebuggingRanks.Deep, "get pack to open in slot: %s", item.ItemSlot())
        local pack = scribing.getItem(item.ItemSlot())

		printDebugMessage(DebuggingRanks.Deep, "pack open state: %s", pack.Open())
        if (pack.Open() == 0) then
            printDebugMessage(DebuggingRanks.Deep, "try to open pack in slot %s", pack.ItemSlot())
            local openCmd = "/itemnotify " .. scribing.formatPackLocation(pack.ItemSlot()) .. " rightmouseup"

			mq.cmd(openCmd)

			delay(3000, function ()
				return pack.Open() == 1
			end)
		end
	end

    functionDepart()
end

function scribing.closePack(pack)
    functionEnter()

	printDebugMessage(DebuggingRanks.Deep, "close pack")
	if (Me.Inventory(pack).Open() == 1) then
		local closeCmd = "/itemnotify " .. scribing.formatPackLocation(pack) .. " rightmouseup"

		mq.cmd(closeCmd)

		delay(3000, function ()
			return Me.Inventory(pack).Open() ~= 0
		end)
	end

    functionDepart()
end

function scribing.openBook()
    functionEnter()

	--checkPlugin("MQ2Boxr")

	--mq.cmd("/squelch /boxr pause")

	Window("SpellBookWnd").DoOpen()

    functionDepart()
end

function scribing.closeBook()
    functionEnter()

	if (Window("SpellBookWnd").Open()) then
		Window("SpellBookWnd").DoClose()
	end

	--mq.cmd("/squelch /boxr unpause")

    functionDepart()
end

-- --------------------------------------------------------------------------------------------
-- SUB: ScribeItem
-- --------------------------------------------------------------------------------------------
function scribing.scribeItem(item)
    functionEnter()

	local spellName = item.Spell.Name()
	local spellId = item.Spell.ID()
	printDebugMessage(DebuggingRanks.Deep, "Scribing %s", spellName)

	scribing.openPack(item)
	scribing.openBook()

	delay(200)

	local scribeCmd = "/itemnotify " .. scribing.formatPackLocation(item.ItemSlot(), item.ItemSlot2()) .. " rightmouseup"
	printDebugMessage(DebuggingRanks.Deep, scribeCmd)

	workSet.Scribing = true

	mq.cmd(scribeCmd)

	delay(3000, function ()
        return (Cursor.ID() or Window("ConfirmationDialogBox").Open() or scribing.isScribed(spellName, spellId) or not workSet.Scribing)
	end)

    printDebugMessage(DebuggingRanks.Deep, "check for open confirmation dialog")
	if (Window("ConfirmationDialogBox").Open() and 
		Window("ConfirmationDialogBox").Child("CD_TextOutput").Text():find(Cursor.Spell.Name().." will replace")) then
        printDebugMessage(DebuggingRanks.Deep, "click yes to confirm")
        Window("ConfirmationDialogBox").Child("Yes_Button").LeftMouseUp()
    end

    delay(15000, function ()
        printDebugMessage(DebuggingRanks.Deep, "item is still scribing: %s", workSet.Scribing)

        return not workSet.Scribing
	end)

	if (Cursor.ID()) then
        mq.cmd("/autoinv")
        delay(200)
        mq.cmd("/autoinv")
    end

    functionDepart()
end

function scribing.checkAndScribe(pack, slot)
    functionEnter()

	local item = scribing.getItem(pack, slot)

    if (item == nil) then
		printDebugMessage(DebuggingRanks.Deep, "Didn't find item in pack: %s, slot: %s", pack, slot)

        printDebugMessage(DebuggingRanks.Deep, "is scribed: false - item == nil")
        functionDepart()
		return false
	end

	printDebugMessage(DebuggingRanks.Deep, "item.Name(): %s", item.Name())
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
		scribing.isScribed(item.Spell.Name(), item.Spell.ID())) then
		printDebugMessage(DebuggingRanks.Deep, "failed basic checks")

        printDebugMessage(DebuggingRanks.Deep, "is scribed: false - not scroll or tome")
        functionDepart()
		return false
	end

	if (not scribing.isUsableByClass(item)) then
		printDebugMessage(DebuggingRanks.Deep, "not usable by class")

        printDebugMessage(DebuggingRanks.Deep, "is scribed: false - not usable by class")
        functionDepart()
        return false
	end

	if (not scribing.isUsableByDiety(item)) then
		printDebugMessage(DebuggingRanks.Deep, "not usable by diety")

        printDebugMessage(DebuggingRanks.Deep, "is scribed: false - not usable by diety")
        functionDepart()
        return false
	end

	local spellName = item.Spell.Name()
	local spellRank = item.Spell.Rank()

	if (spellRank == 2 and
		(scribing.isScribed(spellName .. " Rk. III"))) then
		printDebugMessage(DebuggingRanks.Deep, "already have a higher rank spell scribed")

        printDebugMessage(DebuggingRanks.Deep, "is scribed: false - already have higher")
        functionDepart()
		return false
	elseif (spellRank < 2 and
		(scribing.isScribed(spellName .. " Rk. II") or
		scribing.isScribed(spellName .. " Rk. III"))) then
		printDebugMessage(DebuggingRanks.Deep, "already have a higher rank spell scribed")

        printDebugMessage(DebuggingRanks.Deep, "is scribed: false - already have higher")
        functionDepart()
		return false
	end

	if (item.StackCount() > 1) then
		item = scribing.separateOutSingleItem(item)
---@diagnostic disable-next-line: need-check-nil
		printDebugMessage(DebuggingRanks.Deep, "split item from pack: %s, slot: %s", item.ItemSlot(), item.ItemSlot2())
	end

	if (not item) then
		printDebugMessage(DebuggingRanks.Deep, "no item to scribe")

        printDebugMessage(DebuggingRanks.Deep, "is scribed: false - nothing to scribe")
        functionDepart()
        return false
	end

	scribing.scribeItem(item)

    printDebugMessage(DebuggingRanks.Deep, "is scribed: true")
    functionDepart()
	return true
end

-- --------------------------------------------------------------------------------------------
-- SUB: ScribeSpells
-- --------------------------------------------------------------------------------------------
function scribing.scribeSpells()
    functionEnter()

	if (Cursor.ID()) then
		mq.cmd("/autoinv")
	end

	--|** Opening your inventory for access bag slots **|
	if (not Window("InventoryWindow").Open()) then
		Window("InventoryWindow").DoOpen()
	end

	local scribeCount = 0

	-- Main inventory pack numers are 23-34. 33 & 34 come from add-on perks and may be active for the particular user
	for pack = 23, workSet.TopInvSlot do
		--|** Check Top Level Inventory Slot to see if it has something in it **|
		if (Me.Inventory(pack).ID()) then
			--|** Check Top Level Inventory Slot for bag/no bag **|
			if (Me.Inventory(pack).Container() == 0) then
				--|** If it's not a bag do this **|
				if (scribing.checkAndScribe(pack)) then
					scribeCount = scribeCount + 1
				end
			else
				--|** If it's a bag do this **|
				for slot = 1, Me.Inventory(pack).Container() do
					if (scribing.checkAndScribe(pack, slot - 1)) then
						scribeCount = scribeCount + 1
					end
				end

				scribing.closePack(pack)
			end
		end
	end

	scribing.closeBook()

    functionDepart()
end

---@param gem integer
local function clearGem(gem)
	functionEnter()

	if (gem < 1 or gem > Me.NumGems()) then
		return
	end

	if (Me.Gem(gem).ID()) then
		Window("CastSpellWnd").Child("CSPW_Spell" .. gem).RightMouseUp()

		delay(250, function ()
			return not Me.Gem(gem).ID()
		end)
	end

	functionDepart()
end

local function memSpell(gem, spellName)
	functionEnter()

	printDebugMessage(DebuggingRanks.Basic, "Load spell '\at%s\ax' into slot %s", spellName, gem)
	mq.cmdf("/memspell %s \"%s\"", gem, spellName)

	delay(2000, function()
		return Window("SpellBookWnd").Open()
	end)

	delay(15000, function()
		return Me.Gem(gem).Name() == spellName or not Window("SpellBookWnd").Open()
	end)

	if (Window("SpellBookWnd").Open()) then
		Window("SpellBookWnd").DoClose()
	end

	functionDepart()
end

local function exchangeSpells()
	functionEnter()

	local spell1 = Me.Gem(1).Name()
	local spell2 = Me.Gem(2).Name()

	clearGem(1)
	clearGem(2)

	memSpell(1, spell2)
	memSpell(2, spell1)

	functionDepart()
end

local function leaveItem()
	functionEnter()
	printDebugMessage(DebuggingRanks.Detail, "Leave \a-w%s", Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Tooltip())

	if (Window("AdvancedLootWnd").Child("ADLW_LeaveBtnTemplate").Enabled()) then
		Window("AdvancedLootWnd").Child("ADLW_LeaveBtnTemplate").LeftMouseUp()
		delay(100)
	end

	functionDepart()
end

local function lootItem()
	functionEnter()

	local itemName = Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Tooltip()
	local invItem = TLO.FindItem("=" .. itemName)

	if (invItem() and invItem.Lore()) then
		leaveItem()
	else
		printDebugMessage(DebuggingRanks.Detail, "Loot \ay%s", itemName)

		if (Window("AdvancedLootWnd").Child("ADLW_LootBtnTemplate").Enabled()) then
			Window("AdvancedLootWnd").Child("ADLW_LootBtnTemplate").LeftMouseUp()
			delay(100)

			if (Window("ConfirmationDialogBox").Open()) then
				Window("ConfirmationDialogBox").Child("CD_Yes_Button").LeftMouseUp()
				delay(2000, function ()
					return not Window("ConfirmationDialogBox").Open()
				end)

				printDebugMessage(DebuggingRanks.Deep, "Total \ay%s\ax in inventory: \aw%s", itemName, TLO.FindItemCount("=" .. itemName))
			end
		end
	end

	functionDepart()
end

---@param itemNeeded string
local function checkLoot(itemNeeded)
	functionEnter()

	local xtarget = getNextXTarget()

	printDebugMessage(DebuggingRanks.Function, "AdvancedLootWnd Open: %s, Child ADLW_ItemBtnTemplate Open: %s, xtarget == nil: %s", Window("AdvancedLootWnd").Open(), Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Open(), xtarget == nil)
	printDebugMessage(DebuggingRanks.Detail, "Check to loot item '\ag%s\ax'", itemNeeded)

	while (Window("AdvancedLootWnd").Open() and Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Open() and xtarget == nil) do
		printDebugMessage(DebuggingRanks.Function, "Current item: '\aw%s\ax'", Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Tooltip())

		if (itemNeeded == "all" or Window("AdvancedLootWnd").Open() and Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Tooltip() == itemNeeded) then
			if (itemNeeded == "all") then
				table.insert(lootedItems, Window("AdvancedLootWnd").Open() and Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Tooltip())
			end

			lootItem()
		else
			leaveItem()
		end

		xtarget = getNextXTarget()
	end

	functionDepart()
end

---@param itemName string
local function sellItem(itemName)
	functionEnter()

	local item = TLO.FindItem(itemName)

	if (item.Stack() and not item.NoTrade()) then
		printDebugMessage(DebuggingRanks.Deep, "Sell %s %s to %s", item.Stack(), item.Name(), Target.CleanName())
		mq.cmdf("/selectitem \"%s\"", item.Name())
		delay(250)

		Merchant.Sell(item.Stack())

		delay(1500, function ()
			return not item.Stack()
		end)
	elseif (item.NoTrade()) then
		printDebugMessage(DebuggingRanks.Deep, "Add %s to destroy list", item.Name())
		table.insert(destroyList, item.Name())
	end

	functionDepart()
end

local function sellLoot()
	functionEnter()

	if (#lootedItems > 0) then
		local wijdan = Spawn("Wijdan")
		navHail(wijdan.ID())
		closeDialog()

		delay(150)

		--Target.RightClick()
		Merchant.OpenWindow()

		delay(5000, function ()
			return Merchant.Open()
		end)

		delay(10000, function ()
			return Merchant.ItemsReceived()
		end)

		if (Merchant.Open()) then
			for _, name in ipairs(lootedItems) do
				if (isClassMatch({"NEC", "SHD"}) and name == "Bone Chips") then
					printDebugMessage(DebuggingRanks.Basic, "Keeping bone chips for Necro pet")
				else
					sellItem(name)
				end
			end

			lootedItems = {}
		else
			printDebugMessage(DebuggingRanks.Basic, "Could not establish merchant mode")
		end
	end

	functionDepart()
end

local function sellInventory()
	functionEnter()

	for pack=23, 22 + Me.NumBagSlots() do
		--|** Check Top Level Inventory Slot to see if it has something in it **|
		local item = Me.Inventory(pack)

		if (item.ID()) then
			--|** Check Top Level Inventory Slot for bag/no bag **|
			if (item.Container() == 0) then
				--|** If it's not a bag do this **|
				if (not item.NoDrop()) then
					table.insert(lootedItems, item.Name())
				end
			else
				--|** If it's a bag do this **|
				for slot=1,Me.Inventory(pack).Container() do
					local packItem = item.Item(slot)

					if (not packItem.NoDrop()) then
						table.insert(lootedItems, packItem.Name())
					end
				end
			end
		end
	end

	sellLoot()

	functionDepart()
end

local function buyPetReagent()
	functionEnter()

	local reagent

	if (isClassMatch({"MAG"})) then
		reagent = "Malachite"
	elseif (isClassMatch({"NEC"})) then
		reagent = "Bone Chips"
	end

	if (reagent) then
		printDebugMessage(DebuggingRanks.Deep, "Buy reagent: \ay%s", reagent)
		Merchant.SelectItem("=" .. reagent)

		delay(3500, function ()
			return Merchant.SelectedItem() and Merchant.SelectedItem.Name() == reagent
		end)

		printDebugMessage(DebuggingRanks.Deep, "SelectedItem: \ag%s", Merchant.SelectedItem.Name())
		printDebugMessage(DebuggingRanks.Deep, "Found reagent: \ag%s", Merchant.SelectedItem.Name() == reagent)
		if (Merchant.SelectedItem.Name() == reagent) then
			printDebugMessage(DebuggingRanks.Deep, "Figure out how many %s to buy", reagent)
			local maxQuantity = 5
			local reagentListItem = Window("MerchantWnd").Child("MW_ItemList")

			if (reagentListItem.List(reagentListItem.GetCurSel(), 3)() ~= "--") then
				maxQuantity = tonumber(reagentListItem.List(reagentListItem.GetCurSel(), 3)()) --[[@as integer]]

				if (maxQuantity > 5) then
					maxQuantity = 5
				end
			end

			local quantity = maxQuantity - TLO.FindItemCount(reagent)()
			printDebugMessage(DebuggingRanks.Deep, "Buy %s %s", quantity, reagent)

			Merchant.Buy(quantity)

			delay(1500, function ()
				printDebugMessage(DebuggingRanks.Deep, "wait for reagent in inv")
				return TLO.FindItemCount("=" .. reagent)() >= quantity
			end)
		end
	end

	functionDepart()
end

local function buyClassPet()
	functionEnter()

	local merchantName
	local spellName
	if (isClassMatch({"MAG"}) and Me.Level() >= 4 and Me.Pet.ID() == 0) then
		merchantName = "Tinkerer Gordish"
		spellName = "Elementalkin: Air"
	elseif (isClassMatch({"NEC"}) and Me.Level() >= 4 and Me.Pet.ID() == 0) then
		merchantName = "Tinkerer Oshran"
		spellName = "Leering Corpse"
	elseif (isClassMatch({"BST"}) and Me.Level() >= 8 and Me.Pet.ID() == 0) then
		merchantName = "Celrak"
		spellName = "Spirit of Sharik"
	end

	if (merchantName and not Me.Book(spellName)()) then
		local merchant = Spawn(merchantName)

		navToSpawn(merchant.ID(), findAndKill)
		targetSpawnById(merchant.ID())

		Merchant.OpenWindow()

		delay(5000, function ()
			return Window("MerchantWnd").Open()
		end)

		delay(10000, function ()
			return Merchant.ItemsReceived()
		end)

		if (Merchant.Open()) then
			local buySpellName = "Spell: " .. spellName
			Merchant.SelectItem(buySpellName)

			delay(3500, function ()
				return Merchant.SelectedItem() and Merchant.SelectedItem.Name() == buySpellName
			end)
	
			Merchant.Buy(1)

			delay(1500, function ()
				printDebugMessage(DebuggingRanks.Deep, "wait for spell in inv")
				printDebugMessage(DebuggingRanks.Deep, "spellName: %s", buySpellName)
				return TLO.FindItemCount(buySpellName)() > 0
			end)

			printDebugMessage(DebuggingRanks.Deep, "'\ag%s\ax' inv count: %s", buySpellName, TLO.FindItemCount(buySpellName))
			if (TLO.FindItemCount(buySpellName)() > 0) then
				-- debuggingValues.DebugLevel = DebuggingRanks.Deep
				-- currentDebugLevel = DebuggingRanks.Deep
				scribing.scribeSpells()
				-- debuggingValues.DebugLevel = DebuggingRanks.Basic
				-- currentDebugLevel = DebuggingRanks.Basic

				if (not Me.Gem(workSet.PetGem).ID()) then
					memSpell(workSet.PetGem, spellName)

					delay(5000, function ()
						return Me.GemTimer(workSet.PetGem)() == 0
					end)
			
					checkPet()
				end
			end
		else
			printDebugMessage(DebuggingRanks.Basic, "Could not establish merchant mode")
		end
	end

	functionDepart()
end

---@param buyReagent boolean
local function handleLoot(buyReagent)
	functionEnter()

	sellLoot()

	if (buyReagent) then
		buyPetReagent()
	end

	if (Merchant.Open()) then
		Window("MerchantWnd").DoClose()

		delay(1500, function ()
			return not Merchant.Open()
		end)
	end

	for _, name in ipairs(destroyList) do
		destroyItem(name)
	end

	functionDepart()
end

---@param itemToGive string
---@param amount? integer
local function giveItems(itemToGive, amount)
	functionEnter()

	if (not amount) then
		amount = 1
	end

	printDebugMessage(DebuggingRanks.Basic, "\aoGiving \ay%s \aox \ap%s \aoto \ag%s", amount, itemToGive, Target.CleanName())

	mq.cmd.keypress("OPEN_INV_BAGS")

	if (not Window("InventoryWindow").Open()) then
		Window("InventoryWindow").DoOpen()
	end

	delay(1000, function()
		return Window("InventoryWindow").Open()
	end)
	delay(100)

	for _ = 1, amount do
		grabItem(itemToGive, "left")
		delay(1000, function()
			return Cursor.ID()
		end)
		mq.cmd.usetarget()
		delay(1000, function()
			return not Cursor.ID()
		end)
	end

	Window("GiveWnd").Child("GVW_Give_Button").LeftMouseUp()
	delay(1000, function()
		return not Window("GiveWnd").Open()
	end)

	mq.cmd.keypress("CLOSE_INV_BAGS")
	delay(100)

	functionDepart()
end

---@param conditions fun(): boolean
---@param initialization fun()
---@param targetList TargetInfo[]
local function levelUp(conditions, initialization, targetList)
	functionEnter()

	if (conditions()) then
		printDebugMessage(DebuggingRanks.None, "\ayYou need to be a higher level before proceeding")
		setChatTitle("Leveleing up a bit before proceeding")
		workSet.Task = "Level up"

		initialization()

		while (conditions()) do
			targetShortest(targetList)
			findAndKill(workSet.MyTargetID)
			delay(100)
		end

		checkLoot("")
	end

	functionDepart()
end

local function ClearNests()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done" and
		tutorialSelect("Clearing the Vermin Nests")) then
		workSet.Targets = { "a_cave_rat", "a_cave_bat", "vermin" }
		local tasksToComplete = true
		knownTargets.caveRat.Priority = 2
		knownTargets.caveBat.Priority = 2
		knownTargets.verminNest.Priority = 2

		while (Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() == "") do
			---@type TargetInfo[]
			local targetList = {}

			if (TLO.SpawnCount("npc " .. knownTargets.rufus.Name)() > 0) then
				table.insert(targetList, knownTargets.rufus)
			end

			table.insert(targetList, knownTargets.caveRat)

			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() == "Done") then
				knownTargets.caveRat.Priority = 3
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.caveBat)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.verminNest)
			end

			targetShortest(targetList)
			findAndKill(workSet.MyTargetID)
		end

		checkLoot("all")

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function gotoSpiders()
	functionEnter(DebuggingRanks.Task)

	navToLoc(-1007, -482, -3)
	navToLoc(-1016.50, -483.21, -3)
	mq.cmd.keypress("forward hold")
	delay(1000)
	mq.cmd.keypress("forward")

	functionDepart()
end

local function leaveSpiders()
	functionEnter(DebuggingRanks.Task)

	navToLoc(-670, -374, -65)
	mq.cmd.face("loc -595,-373,-40")
	mq.cmd.keypress("forward hold")
	delay(1000)
	mq.cmd.keypress("forward")

	functionDepart(DebuggingRanks.Task)
end

local function SpiderCaves()
	functionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Spider Caves")) then
		while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
			farmStuff(knownTargets.spiderCocoon)
			checkLoot("all")
			tutorialSelect("Spider Caves")
		end

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function SpiderCavesFinish()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("Spider Caves")

	if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
		if (workSet.Location == "SpiderRoom") then
			leaveSpiders()
		end

		navHail(Spawn("Vahlara").ID())
		giveItems("Gloomingdeep Cocoon Silk", 4)
		getReward()
		delay(1000, function()
			return Cursor.ID()
		end)
		mq.cmd.autoinventory()
		delay(1000, function()
			return not Cursor.ID()
		end)

		destroyItem("Gloomingdeep Cocoon Silk")

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function SpiderTamer()
	functionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Spider Tamer Gugan")) then
		while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
			if (workSet.Location ~= "SpiderRoom") then
				gotoSpiders()
			end

			farmStuff(knownTargets.gugan)
			checkLoot("Gloomingdeep Violet")
			tutorialSelect("Spider Tamer Gugan")
		end

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function SpiderTamerFinish()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("Spider Tamer Gugan")

	if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
		if (workSet.Location == "SpiderRoom") then
			leaveSpiders()
		end

		navHail(Spawn("Xenaida").ID())
		giveItems("Gloomingdeep Violet", 1)
		closeDialog()
		closeDialog()

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function Arachnida()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(15, 2)() ~= "Done" and
		tutorialSelect("Arachnida")) then
		workSet.Targets = { "a_gloom_spider", "a_gloomfang_lurker" }
		local tasksToComplete = true

		while (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() == "") do
			---@type TargetInfo[]
			local targetList = {}

			if (TLO.SpawnCount("npc " .. knownTargets.venomfang.Name)() > 0) then
				table.insert(targetList, knownTargets.venomfang)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.gloomSpider)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.lurkerSpider)
			end

			targetShortest(targetList)
			findAndKill(workSet.MyTargetID)
		end

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function FinishArachnida()
	functionEnter(DebuggingRanks.Task)

	checkLoot("")

	if (tutorialSelect("Arachnida")) then
		navHail(Spawn("Guard Rahtiz").ID())
		mq.cmd("/squelch /target clear")
		closeDialog()

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function gotoQueen()
	functionEnter(DebuggingRanks.Task)

	navToLoc(-1007, -482, -3)
	navToLoc(-1016.50, -483.21, -3)
	mq.cmd.keypress("forward hold")
	delay(1000)
	mq.cmd.keypress("forward")
	navToLoc(-1186, -446, 19)
	navToLoc(-1201, -467, 19)
	navToLoc(-1188, -444, 19)

	functionDepart(DebuggingRanks.Task)
end

local function leaveQueen()
	functionEnter(DebuggingRanks.Task)

	gotoSpiders()
	leaveSpiders()

	functionDepart(DebuggingRanks.Task)
end

local function Arachnophobia()
	functionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Arachnophobia (Group)")) then
		if (workSet.Location ~= "SpiderRoom") then
			gotoSpiders()
		end

		gotoQueen()

		while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
			navToLoc(-1201, -467, 19)
			farmStuff(knownTargets.gloomfang)
		end

		if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() == "Done") then
			leaveQueen()

			navHail(Spawn("Guard Hobart").ID())

			delay(1000, function()
				return Cursor.ID()
			end)
			mq.cmd.autoinventory()

			if (Cursor.ID()) then
				mq.cmd.autoinventory()
			end

			getReward()

			delay(1000, function()
				return Cursor.ID()
			end)

			mq.cmd.autoinventory()
			if (Cursor.ID()) then
				mq.cmd.autoinventory()
			end
			delay(1000, function()
				return not Cursor.ID()
			end)

			mq.cmd("/squelch /target clear")
		end

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function EnterPit()
	functionEnter(DebuggingRanks.Task)

	if (Me.Z() > -29) then
		navToLoc(-479, -1051, -1)
		moveToWait(-483, -965, -19)
		moveToWait(-486, -897, -42)
		moveToWait(-418, -893, -61)
	end

	functionDepart(DebuggingRanks.Task)
end

local function ExitPit()
	functionEnter(DebuggingRanks.Task)

	navToLoc(-436, -899, -63)
	navToLoc(-485, -897, -42)
	navToLoc(-479.66, -1036.44, 2.74)
	mq.cmd.face("loc -480,-1024,-1")

	functionDepart(DebuggingRanks.Task)
end

local function FreedomStand()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(10, 2)() ~= "Done") then
		if (tutorialSelect("Freedom's Stand (Group)")) then
			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
				navToLoc(-262, -1723, -99)
				delay(250)
				workSet.PullRange = 250

				local targetList = {
					knownTargets.warrior,
					knownTargets.spiritweaver,
					knownTargets.gnikan,
				}

				while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
					targetShortest(targetList)
					findAndKill(workSet.MyTargetID)
					checkLoot("")
	
					debuggingValues.ActionTaken = true
				end
			end
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function FreedomStandFinish()
	functionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Freedom's Stand (Group)")) then
		if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() == "Done") then
			navHail(Spawn("Guard Hobart").ID())

			local newWeapon = Window("RewardSelectionWnd/RewardPageTabWindow").Tab(1).Child("RewardSelectionItemList").List(2)()
			printDebugMessage(DebuggingRanks.Detail, "New weapon: \aw%s", newWeapon)

			local mainhand = TLO.InvSlot("mainhand").Item
			local availableSlot = GetAvailableInvSlot(mainhand.Size())
			local packname = "pack" .. availableSlot
			grabItem(mainhand.Name(), "left")
			invItem(packname)

			getReward()

			mq.cmd("/squelch /target clear	")

			debuggingValues.ActionTaken = true
		end
	end

	medToFull()
	checkBlessing()

	functionDepart(DebuggingRanks.Task)
end

local function BustedLocks()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(19, 2)() ~= "Done") then
		if (tutorialSelect("Busted Locks")) then
			checkLoot("Gloomingdeep Master Key")

			while (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") do
				workSet.TargetType = "NPC"
				navToLoc(219, -419, 24)
				farmStuff(knownTargets.locksmith)
				checkLoot("Gloomingdeep Master Key")

				debuggingValues.ActionTaken = true
			end
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function BustedLocksB()
	functionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Busted Locks")) then
		tutorialSelect("The Revolt of Gloomingdeep")
		if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() == "Done") then
			navHail(Spawn("Kaikachi").ID())
			giveItems("Gloomingdeep Master Key", 1)
			getReward()
			mq.cmd("/squelch /target clear")
			delay(1000, function()
				return Cursor.ID()
			end)

			mq.cmd.autoinventory()

			if (Cursor.ID()) then
				mq.cmd.autoinventory()
			end
			delay(1000, function()
				return not Cursor.ID()
			end)

			destroyItem("Gloomingdeep Master Key")

			debuggingValues.ActionTaken = true
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function PitFiend()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(25, 2)() ~= "Done") then
		if (tutorialSelect("Pit Fiend (Group)")) then
			workSet.ZRadius = 1200
			navToLoc(-479, -1051, -1)
			EnterPit()
			navToLoc(-318, -1109, -147)
			local krenshin = Spawn("Krenshin")

			while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
				while (krenshin.ID() == 0 or krenshin.TargetOfTarget.ID() > 0) do
					delay(250)
					mq.doevents()
				end
				farmStuff(knownTargets.krenshin)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() == "Done") then
				ExitPit()
			end

			mq.cmd("/squelch /target clear")

			debuggingValues.ActionTaken = true
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function AriasA()
	functionEnter(DebuggingRanks.Task)

	local arias = Spawn("Arias")
	navHail(arias.ID())
	mq.cmd.say("Escape")
	acceptTask("Jail Break!")

	---@type spawn
	local jailer
	delay(500, function ()
		jailer = Spawn("The Gloomingdeep Jailor")
		return jailer.ID() > 0
	end)

	findAndKill(jailer.ID())

	delay(1000, function()
		return Window("AdvancedLootWnd").Open()
	end)

	if (Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Tooltip() == "The Gloomingdeep Jailor's Key") then
		Window("AdvancedLootWnd").Child("ADLW_LootBtnTemplate").LeftMouseUp()
		delay(1000, function()
			return not Window("AdvancedLootWnd").Open()
		end)
	end

	targetSpawnById(arias.ID())

	mq.cmd.keypress("OPEN_INV_BAGS")
	if (not Window("InventoryWindow").Open()) then
		Window("InventoryWindow").DoOpen()
	end
	delay(1000, function()
		return Window("InventoryWindow").Open()
	end)

	grabItem("The Gloomingdeep Jailor's Key", "left")
	Target.LeftClick()
	delay(1000, function()
		return not Cursor.ID()
	end)

	Window("GiveWnd").Child("GVW_Give_Button").LeftMouseUp()
	delay(1000, function()
		return not Window("GiveWnd").Open()
	end)

	closeDialog()

	functionDepart(DebuggingRanks.Task)
end

local function AriasB()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
		navHail(Spawn("Arias").ID())
		closeDialog()
		mq.cmd("/squelch /target clear")
	end

	functionDepart(DebuggingRanks.Task)
end

local function AriasC()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(9, 2)() ~= "Done") then
		navHail(Spawn("Arias").ID())
		closeDialog()
		navHail(Spawn("Arias").ID())
		delay(1000, function()
			return Cursor.ID()
		end)
		mq.cmd.hail()
		delay(1000, function()
			return Cursor.Name() == "Kobold Skull Charm"
		end)
		delay(100)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
		delay(1000, function()
			return not Cursor.ID()
		end)
		mq.cmd("/squelch /target clear")
	end

	functionDepart(DebuggingRanks.Task)
end

local function AriasD()
	functionEnter(DebuggingRanks.Task)

	navHail(Spawn("Arias").ID())
	mq.cmd("/squelch /target clear")

	functionDepart(DebuggingRanks.Task)
end

local function Absor()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done") then
		navHail(Spawn("Absor").ID())

		if (TLO.InvSlot("mainhand").Item.Name()) then
			local myWeapon = TLO.InvSlot("mainhand").Item.Name():gsub("%*", "")
			local myWeaponType = myWeapon:match("%w+$")
			printDebugMessage(DebuggingRanks.Function, "Hand \ag%s\ax to Absor", myWeapon)
			mq.cmd.keypress("OPEN_INV_BAGS")
			if (not Window("InventoryWindow").Open()) then
				Window("InventoryWindow").DoOpen()
			end
			delay(1000, function()
				return Window("InventoryWindow").Open()
			end)
			Window("InventoryWindow").Child("InvSlot13").LeftMouseUp()
			delay(1000, function()
				return Cursor.ID()
			end)
			mq.cmd.usetarget()
			delay(1000, function()
				return not Cursor.ID()
			end)
			Window("GiveWnd").Child("GVW_Give_Button").LeftMouseUp()
			delay(1000, function()
				return not Window("GiveWnd").Open()
			end)
			delay(1000, function()
				return TLO.FindItemCount(myWeaponType)()
			end)
			myWeapon = TLO.FindItem(myWeaponType).Name()
			printDebugMessage(DebuggingRanks.Function, "Equip \ag%s", myWeapon)
			mq.cmdf("/exchange \"%s\" mainhand", myWeapon)
			mq.cmd.keypress("CLOSE_INV_BAGS")
		else
			delay(1000)
		end

		closeDialog()
	end

	functionDepart(DebuggingRanks.Task)
end

local function VahlaraA()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() ~= "Done") then
		navHail(Spawn("Vahlara").ID())
		delay(1000, function()
			return Cursor.ID()
		end)
		delay(100)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
		closeDialog()
		mq.cmd.say("others")
		closeDialog()
	end

	functionDepart(DebuggingRanks.Task)
end

local function VahlaraB()
	functionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Clearing the Vermin Nests") and
		Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() ~= "Done") then
		navHail(Spawn("Vahlara").ID())

		getReward()
		delay(1000, function()
			return Cursor.ID()
		end)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
		delay(1000, function()
			return not Cursor.ID()
		end)

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function Xenaida()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(5, 2)() ~= "Done") then
		local xenaida = Spawn("Xenaida")

		navHail(xenaida.ID())

		closeDialog()
		closeDialog()

		waitNavGround("mushroom")

		navToSpawn(xenaida.ID())
		targetSpawnById(xenaida.ID())

		grabItem("Gloomingdeep Mushrooms", "left")
		delay(1000, function()
			return Cursor.ID()
		end)

		mq.cmd.usetarget()
		delay(1000, function()
			return not Cursor.ID()
		end)

		Window("GiveWnd").Child("GVW_Give_Button").LeftMouseUp()
		delay(1000, function()
			return not Window("GiveWnd").Open()
		end)

		closeDialog()
	end

	functionDepart(DebuggingRanks.Task)
end

local function Rytan()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(6, 2)() ~= "Done") then
		navHail(Spawn("Rytan").ID())
		mq.cmd.say("Blessed")
		delay(1000, function()
			return Cursor.ID()
		end)

		delay(250)

		local spellName = ""

		if (Cursor.ID()) then
			local givenSpell = Cursor.Name()

			mq.cmd.autoinventory()
			delay(1000, function()
				return not Cursor.ID()
			end)

			spellName = TLO.FindItem(givenSpell).Spell.Name()
			printDebugMessage(DebuggingRanks.Basic, "Rytan gave us spell %s", spellName)

			if (not Window("InventoryWindow").Open()) then
				Window("InventoryWindow").DoOpen()
			end
			mq.cmd.keypress("OPEN_INV_BAGS")
			delay(1000, function()
				return Window("InventoryWindow").Open()
			end)
			scribing.scribeSpells()
		end
		closeDialog()
		closeDialog()
		closeDialog()
		delay(1000)

		if (spellName ~= "") then
			local gem = 1

			if (isClassMatch({"CLR"})) then
				gem = 3
			end

			if (not Me.Gem(gem).ID()) then
				memSpell(gem, spellName)
			end
		end

		mq.cmd.keypress("CLOSE_INV_BAGS")
	end

	functionDepart(DebuggingRanks.Task)
end

local function Prathun()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(7, 2)() ~= "Done") then
		navHail(Spawn("Prathun").ID())
		closeDialog()
		closeDialog()
		closeDialog()
		closeDialog()
		closeDialog()
	end

	functionDepart(DebuggingRanks.Task)
end

local function Elegist()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(13, 2)() ~= "Done") then
		local elegist = Spawn("Elegist") 

		if (tutorialCheck("Mercenaries for Hire")) then
			navToSpawn(elegist.ID(), findAndKill)
			targetSpawnByName("Elegist")
		else
			navHail(elegist.ID())
			acceptTask("Mercenaries for Hire")
			closeDialog()
			closeDialog()
			closeDialog()
		end

		if (tutorialSelect("Mercenaries for Hire")) then
			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
				Target.RightClick()
				delay(2000, function()
					return Window("MMTW_MerchantWnd").Open()
				end)

				local mercWindow = Window("MMTW_MerchantWnd")
				delay(1500)

				printDebugMessage(DebuggingRanks.Function, "Subscription: %s", Me.Subscription())

				if (Me.Subscription() == "GOLD") then
					printDebugMessage(DebuggingRanks.Function, "Select Journeyman Merc")
					local typeDropdown = mercWindow.Child("MMTW_TypeComboBox")
					typeDropdown.Select(2)
					delay(2000, function ()
						return typeDropdown.GetCurSel() == 2
					end)

					printDebugMessage(DebuggingRanks.Function, "Selected Merc Type: '\ay%s\ax'", typeDropdown.List(typeDropdown.GetCurSel(), 1)())
					delay(250)
					printDebugMessage(DebuggingRanks.Function, "Select Journeyman Tank")
				else
					printDebugMessage(DebuggingRanks.Function, "Select Apprentice Tank")
				end

				local availableMercs = mercWindow.Child("MMTW_SubtypeListBox")
				availableMercs.Select(2)
				delay(2000, function ()
					return availableMercs.GetCurSel() == 2
				end)
				delay(250)

				local mercStance = mercWindow.Child("MMTW_StanceListBox")
				mercStance.Select(1)
				delay(2000, function ()
					return mercStance.GetCurSel() == 1
				end)
				delay(250)

				mercWindow.Child("MMTW_HireButton").LeftMouseUp()
				delay(2000, function ()
					return not mercWindow.Open()
				end)

				delay(5000, function ()
					return Me.Grouped() and Group.Member(1).Type() == "Mercenary"
				end)

				targetSpawn(elegist)
				mq.cmd.hail()
				delay(250)

				closeDialog()
				closeDialog()
				closeDialog()
				closeDialog()
				closeDialog()

				mq.cmdf("/grouproles set %s 2", Me.CleanName())
				delay(250)

				printDebugMessage(DebuggingRanks.Detail, "Is not tank: %s", not isClassMatch({"WAR","PAL","SHD"}))

				if (not isClassMatch({"WAR","PAL","SHD"})) then
					printDebugMessage(DebuggingRanks.Detail, "/grouproles set %s 1", Group.Member(1).Name())
					mq.cmdf("/grouproles set %s 1", Group.Member(1).Name())
					delay(250)
				end
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
				mq.cmd("/squelch /target clear")

				while (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") do
					farmStuff(knownTargets.infiltrator)
				end

				if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done") then
					navHail(Spawn("Elegist").ID())
				end
			end

			delay(100)
			mq.cmd("/stance aggressive")
			delay(100)

			closeDialog()
			closeDialog()
			closeDialog()

			debuggingValues.ActionTaken = true
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function BasherAlga()
	functionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(8, 2)() ~= "Done") then
		if (not tutorialCheck("Hotbars")) then
			navHail(Spawn("Basher Alga").ID())
			acceptTask("Hotbars")
		end

		if (tutorialSelect("Hotbars")) then
			mq.cmd.hail()
			closeDialog()
			closeDialog()
			closeDialog()
			closeDialog()
			closeDialog()
			getReward()
			checkSwiftness()
		end

		tutorialSelect("Basic Training")
	end

	functionDepart(DebuggingRanks.Task)
end

local function GuardRahtizA()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
		if (not tutorialCheck("Clearing the Vermin Nests")) then
			navHail(Spawn("Guard Rahtiz").ID())
			acceptTask("Clearing the Vermin Nests")
			mq.cmd("/squelch /target clear")
		end

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function GuardRahtizB()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() ~= "Done" and
		not tutorialCheck("Rebellion Reloaded")) then
		navHail(Spawn("Guard Rahtiz").ID())
		acceptTask("Rebellion Reloaded")
		mq.cmd("/squelch /target clear")

		debuggingValues.ActionTaken = true
	end

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(15, 2)() ~= "Done" and
		not tutorialCheck("Arachnida")) then
		navHail(Spawn("Guard Rahtiz").ID())
		acceptTask("Arachnida")
		mq.cmd("/squelch /target clear")

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function GuardRahtizC()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() ~= "Done") then
		if (not tutorialCheck("Rebellion Reloaded")) then
			navHail(Spawn("Guard Rahtiz").ID())
			acceptTask("Rebellion Reloaded")
			mq.cmd("/squelch /target clear")
		end

		if (tutorialSelect("Rebellion Reloaded")) then
			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
				workSet.ZRadius = 100
				workSet.PullRange = 200
				checkLoot("CLASS 1 Wood Point Arrow")

				if (TLO.FindItemCount("=CLASS 1 Wood Point Arrow")() == 0) then
					navToKnownLoc(navLocs.RatBat)
				end

				while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done" and
					TLO.FindItemCount("=CLASS 1 Wood Point Arrow")() == 0) do
					farmStuff(knownTargets.barrel)
					checkLoot("CLASS 1 Wood Point Arrow")
				end

				navHail(Spawn("Guard Rahtiz").ID())

				if (TLO.InvSlot("Ammo").Item.ID() == 8500) then
					mq.cmd("/nomodkey /ctrlkey /itemnotify ammo leftmouseup")
				end

				giveItems("CLASS 1 Wood Point Arrow", 1)
				closeDialog()
				closeDialog()
				closeDialog()
				mq.cmd("/squelch /target clear")

				if (TLO.FindItemCount("=CLASS 1 Wood Point Arrow")() > 0 and
					TLO.FindItem("=CLASS 1 Wood Point Arrow").ItemSlot() > 22) then
					destroyItem("CLASS 1 Wood Point Arrow")
				end

				if (workSet.MyTargetID) then
					workSet.MyTargetID = 0
				end
			end

			delay(100)
			closeDialog()
			workSet.ZRadius = 1000
		end

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function GuardVyrinn()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done" and
		not tutorialCheck("Spider Caves")) then
		navHail(Spawn("Guard Vyrinn").ID())
		acceptTask("Spider Caves")
		mq.cmd("/squelch /target clear")

		debuggingValues.ActionTaken = true
	end

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(5, 2)() ~= "Done" and
		not tutorialCheck("Spider Tamer Gugan")) then
		navHail(Spawn("Guard Vyrinn").ID())
		acceptTask("Spider Tamer Gugan")

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function GuardVyrinnB()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(17, 2)() ~= "Done") then
		navHail(Spawn("Guard Vyrinn").ID())
		acceptTask("Arachnophobia (Group)")
		mq.cmd("/squelch /target clear")
	end

	functionDepart(DebuggingRanks.Task)
end

local function GuardHobart()
	functionEnter(DebuggingRanks.Task)

	if (tutorialSelect("The Revolt of Gloomingdeep") and
		Window("TaskWND").Child("Task_TaskElementList").List(9, 2)() ~= "Done") then
		if (not tutorialCheck("The Battle of Gloomingdeep")) then
			navHail(Spawn("Hobart").ID())
			acceptTask("The Battle of Gloomingdeep")

			debuggingValues.ActionTaken = true
		end

		if (not tutorialCheck("Freedom's Stand (Group)")) then
			navHail(Spawn("Hobart").ID())
			acceptTask("Freedom's Stand (Group)")

			debuggingValues.ActionTaken = true
		end

		mq.cmd("/squelch /target clear")
	end

	functionDepart(DebuggingRanks.Task)
end

local function GloomingdeepBattle()
	functionEnter(DebuggingRanks.Task)

	if (tutorialSelect("The Battle of Gloomingdeep")) then
		mq.cmd("/squelch /target clear")

		workSet.PullRange = 500
		workSet.ZRadius = 500

		if (Math.Distance("-625, -1025, 1")() > (workSet.PullRange / 2)) then
			navToLoc(-625, -1025, 1)
		end

		while (Window("TaskWND").Child("Task_TaskElementList").List(5, 2)() == "") do
			if ((Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done" or
				Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") and
				Math.Distance("-625, -1025, 1")() > workSet.PullRange) then
				navToLoc(-625, -1025, 1)
			end

			local targetList = {}

			if (TLO.SpawnCount("npc " .. knownTargets.silver.Name)() > 0) then
				table.insert(targetList, knownTargets.silver)
			end

			if (TLO.SpawnCount("npc " .. knownTargets.selandoor.Name)() > 0) then
				table.insert(targetList, knownTargets.selandoor)
			end

			if (TLO.SpawnCount("npc " .. knownTargets.brokenclaw.Name)() > 0) then
				table.insert(targetList, knownTargets.brokenclaw)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.grunt)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.warrior)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.slaveWarden)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.spiritweaver)
			end

			if (#targetList > 0) then
				targetShortest(targetList)
				findAndKill(workSet.MyTargetID)
			end
		end

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function GloomingdeepBattleFinish()
	functionEnter(DebuggingRanks.Task)

	if (tutorialSelect("The Battle of Gloomingdeep")) then
		workSet.ZRadius = 1000
		navHail(Spawn("Hobart").ID())
		delay(1000)

		mq.cmd("/squelch /target clear")

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function GuardMaddocA()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(21, 2)() ~= "Done" and
		not tutorialCheck("Kobold Leadership")) then
		navHail(Spawn("Guard Maddoc").ID())
		acceptTask("Kobold Leadership")
		mq.cmd("/squelch /target clear")

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function GuardMaddocB()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(24, 2)() ~= "Done" and
		not tutorialCheck("Pit Fiend (Group)")) then
		navHail(Spawn("Guard Maddoc").ID())
		acceptTask("Pit Fiend (Group)")
		mq.cmd("/squelch /target clear")

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function KoboldLeadership()
	functionEnter(DebuggingRanks.Task)

	while (tutorialSelect("Kobold Leadership")) do
		local targetList = {
			knownTargets.captain,
		}

		if (TLO.SpawnCount("npc " .. knownTargets.silver.Name)() > 0) then
			table.insert(targetList, knownTargets.silver)
		end

		if (TLO.SpawnCount("npc " .. knownTargets.ratasaurus.Name)() > 0) then
			table.insert(targetList, knownTargets.ratasaurus)
		end

		targetShortest(targetList)
		findAndKill(workSet.MyTargetID)
		checkLoot("")

		debuggingValues.ActionTaken = true
	end

	functionDepart(DebuggingRanks.Task)
end

local function ScoutZajeer()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(6, 2)() ~= "Done") then
		if (not tutorialCheck("Scouting Gloomingdeep")) then
			navHail(Spawn("Zajeer").ID())
			acceptTask("Scouting Gloomingdeep")
			navHail(Spawn("Zajeer").ID())
			acceptTask("Sabotage")
			delay(1000, function ()
				return Cursor.ID()
			end)

			if (Cursor.ID()) then
				mq.cmd.autoinventory()
				delay(1000, function ()
					return not Cursor.ID()
				end)
			end
			mq.cmd("/squelch /target clear")

			debuggingValues.ActionTaken = true
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function ScoutKaikachiA()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(8, 2)() ~= "Done") then
		if (not tutorialCheck("Goblin Treachery")) then
			navHail(Spawn("Kaikachi").ID())
			acceptTask("Goblin Treachery")

			debuggingValues.ActionTaken = true
		end

		mq.cmd("/squelch /target clear")
	end

	functionDepart(DebuggingRanks.Task)
end

local function ScoutKaikachiB()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(19, 2)() ~= "Done") then
		if (not tutorialCheck("Busted Locks")) then
			navHail(Spawn("Kaikachi").ID())
			acceptTask("Busted Locks")
			mq.cmd("/squelch /target clear")

			debuggingValues.ActionTaken = true
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function GoblinTreachery()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(8, 2)() ~= "Done") then
		if (tutorialSelect("Goblin Treachery")) then
			while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
				workSet.PullRange = 2000
				workSet.ZRadius = 1500

				farmStuff(knownTargets.goblinSlave)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
				EnterPit()

				workSet.TargetType = "NPC"
				workSet.PullRange = 1000
			end

			while (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") do
				if (workSet.Location == "PitTop") then
					EnterPit()
				end

				if (workSet.Location == "PitSteps") then
					navToLoc(-418, -893, -61)
				end

				navToLoc(-387.67, -658.62, -77.56)
				farmStuff(knownTargets.rookfynn)
			end

			debuggingValues.ActionTaken = true
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function GoblinTreacheryFinish()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(8, 2)() ~= "Done") then
		if (tutorialSelect("Goblin Treachery")) then
			if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done") then
				navHail(Spawn("Kaikachi").ID())
				getReward()
				mq.cmd("/squelch /target clear")

				debuggingValues.ActionTaken = true
			end
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function Sabotage()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(7, 2)() ~= "Done") then
		if (tutorialSelect("Sabotage")) then
			local supplyBox = Spawn("kobold siege supplies")
			::sabotage::
			navToSpawn(supplyBox.ID())
			targetSpawnById(supplyBox.ID())
			giveItems("Makeshift Lantern Bomb", 1)
			mq.cmd("/squelch /target clear")
			navToLoc(-254, -1539, -105)
			if (TLO.FindItemCount("=Makeshift Lantern Bomb")() > 0) then
				goto sabotage
			end

			debuggingValues.ActionTaken = true
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function ScoutingGloomingdeepA()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(6, 2)() ~= "Done") then
		if (tutorialSelect("Scouting Gloomingdeep")) then
			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
				navToLoc(-47, -849, -29)

				debuggingValues.ActionTaken = true
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
				navToLoc(-226, -866, -1)

				debuggingValues.ActionTaken = true
			end
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function ScoutingGloomingdeepB()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(6, 2)() ~= "Done") then
		if (tutorialSelect("Scouting Gloomingdeep")) then
			if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done") then
				navToLoc(-519, -1101, 3)

				debuggingValues.ActionTaken = true
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() ~= "Done") then
				navToLoc(-254, -1539, -105)

				debuggingValues.ActionTaken = true
			end
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function ScoutingGloomingdeepC()
	functionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(6, 2)() ~= "Done") then
		if (tutorialSelect("Scouting Gloomingdeep")) then
			if (Window("TaskWND").Child("Task_TaskElementList").List(5, 2)() ~= "Done") then
				navHail(Spawn("Zajeer").ID())
				getReward()
				mq.cmd("/squelch /target clear")

				debuggingValues.ActionTaken = true
			end
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function FlutterwingA()
	functionEnter(DebuggingRanks.Task)

	if (not tutorialCheck("Flutterwing's Dilemma")) then
		tutorialSelect("The Revolt of Gloomingdeep")

		if (Window("TaskWND").Child("Task_TaskElementList").List(23, 2)() ~= "Done") then
			navHail(Spawn("Flutterwing").ID())
			mq.cmd.say("Siblings")
			acceptTask("Flutterwing's Dilemma")
			mq.cmd("/squelch /target clear")

			debuggingValues.ActionTaken = true
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function FlutterwingB()
	functionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Flutterwing's Dilemma")) then
		if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
			navToLoc(713, -259, -10)

			workSet.PullRange = 150
			knownTargets.plaguebearer.Priority = 2
			knownTargets.warrior.Priority = 3
			knownTargets.ruga.Priority = 4

			local targetList = {
				knownTargets.plaguebearer,
				knownTargets.warrior,
				knownTargets.ruga,
			}

			while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
				targetShortest(targetList)
				findAndKill(workSet.MyTargetID)

				checkLoot("Flutterwing's Unhatched Sibling")
			end

			debuggingValues.ActionTaken = true
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function FlutterwingC()
	functionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Flutterwing's Dilemma")) then
		tutorialSelect("The Revolt of Gloomingdeep")

		if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() == "Done") then
			navHail(Spawn("Flutterwing").ID())
			giveItems("Flutterwing's Unhatched Sibling", 1)
			mq.cmd("/squelch /target clear")

			debuggingValues.ActionTaken = true
		end
	end

	functionDepart(DebuggingRanks.Task)
end

local function zoning()
	while (Zone.ID() ~= 189) do
		delay(50)
	end

	while (Me.Zoning()) do
		delay(50)
	end

	delay(100)
end

local function checkMesh()
	if (not Navigation.MeshLoaded()) then
		mq.cmd.nav("reload")
		delay(1000, function()
			return Navigation.MeshLoaded()
		end)
		if (not Navigation.MeshLoaded()) then
			Note.Info("No navigational mesh could be found for this zone. Make one and try again")
			Note.Info("Ending script.")
			mq.exit()
		end
	end
end

local function closeAlert()
	if (Window("AlertWnd").Open()) then
		Window("AlertWnd").Child("ALW_Dismiss_Button").LeftMouseUp()
		delay(1000, function()
			return not Window("AlertWnd").Open()
		end)
	end
end

local function loadIgnores()
	mq.cmd.squelch("/alert clear 1")
	mq.cmd.squelch("/alert add 1 McKenzie_the_Younger")
	mq.cmd.squelch("/alert add 1 Prathun")
	mq.cmd.squelch("/alert add 1 Guard")
	mq.cmd.squelch("/alert add 1 Rashere")
	mq.cmd.squelch("/alert add 1 Basher_Alga")
	mq.cmd.squelch("/alert add 1 Flutterwing")
	mq.cmd.squelch("/alert add 1 Poxan")
	mq.cmd.squelch("/alert add 1 Vahlara")
	mq.cmd.squelch("/alert add 1 Nura")
	mq.cmd.squelch("/alert add 1 Rowyl")
	mq.cmd.squelch("/alert add 1 Gordish")
	mq.cmd.squelch("/alert add 1 Klide")
	mq.cmd.squelch("/alert add 1 Keridon")
	mq.cmd.squelch("/alert add 1 Oshran")
	mq.cmd.squelch("/alert add 1 Clockwork_War_Machine")
	mq.cmd.squelch("/alert add 1 Celrak")
	mq.cmd.squelch("/alert add 1 A Priest_of_Luclin")
	mq.cmd.squelch("/alert add 1 Elegist")
	mq.cmd.squelch("/alert add 1 Absor")
	mq.cmd.squelch("/alert add 1 Xenaida")
	mq.cmd.squelch("/alert add 1 Scribe_Farquard")
	mq.cmd.squelch("/alert add 1 Wijdan")
	mq.cmd.squelch("/alert add 1 Lyndroh")
	mq.cmd.squelch("/alert add 1 Rytan")
	mq.cmd.squelch("/alert add 1 Guard_Rahtiz")
	mq.cmd.squelch("/alert add 1 Guard_Vyrinn")
	mq.cmd.squelch("/alert add 1 Frizznik")
	mq.cmd.squelch("/alert add 1 Arias")
	mq.cmd.squelch("/alert add 1 Guard_Hobart")
	mq.cmd.squelch("/alert add 1 Guard_Maddoc")
	mq.cmd.squelch("/alert add 1 Revolt_Scout_Kaikachi")
	mq.cmd.squelch("/alert add 1 Revolt_Scout_Zajeer")
	mq.cmd.squelch("/alert add 1 a_garroted_kobold")
	mq.cmd.squelch("/alert add 1 a_dark_elf_slave")
	mq.cmd.squelch("/alert add 1 a_dwarven_slave")
	mq.cmd.squelch("/alert add 1 a_human_slave")
	mq.cmd.squelch("/alert add 1 an_iksar_slave")
end

local function insertAug()
	functionEnter()

	grabItem("Steatite Fragment", "left")

	mq.cmd("/insertaug " .. Me.Inventory(13).ID())
	delay(1000, function()
		return not Cursor.ID()
	end)
	if (Cursor.ID()) then
		mq.cmd.autoinventory()
		Note.Info("\arFailed to insert Seatite Fragment! \awDo it manually!")
	end
	delay(100)

	functionDepart()
end

local function McKenzie()
	functionEnter(DebuggingRanks.Task)

	if (TLO.FindItemCount("=Steatite Fragment")() > 0) then
		Note.Info("\ayYou already have the augment Steatite Fragment")

		return
	end

	if (not tutorialSelect("Kickin' Things Up A Notch - Augmentation")) then
		Note.Info("\agHeaded to get that aug for the KICK ASS WEAPON YOU JUST RECEIVED!!! Hang tight...")

		local mckenzie = Spawn("McKenzie")
		navHail(mckenzie.ID())
		mq.cmd.say("lesson")
		delay(1000)
		mq.cmd.say("listenin")
		delay(1000, function()
			return Cursor.ID()
		end)

		while (Cursor.ID()) do
			mq.cmd.autoinventory()
			delay(250)
		end
		closeDialog()
		closeDialog()
		insertAug()
		mckenzie.DoTarget()
		delay(100)
		mq.cmd.hail()
		delay(100)
		closeDialog()
		closeDialog()
		closeDialog()
	end
	functionDepart(DebuggingRanks.Task)
end

local function JailBreak()
	closeAlert()
	AriasA()
	zoning()
end

local function BasicTraining()
	if (tutorialSelect("Basic Training")) then
		closeDialog()

		AriasB()
		Absor()
		Xenaida()
		Farquard()
		LuclinPriest()
		Wijdan()
		Lyndroh()
		Rytan()
		Prathun()
		Rashere()
		BasherAlga()
		Poxan()
		VahlaraA()
		McKenzie()
		Frizznik()
		AriasC()

		debuggingValues.ActionTaken = true
	end
end

local function GloomingdeepRevolt()
	if (tutorialSelect("The Revolt of Gloomingdeep")) then
		checkStep()
		Elegist()
		medToFull()
		checkStep()
		GuardRahtizA()
		checkStep()

		if (Me.AltAbilityReady(481)) then
			mq.cmd.alt("act 481")
			delay(1000, function ()
				return Me.Casting.ID()
			end)
			delay(5000, function ()
				return not Me.Casting.ID()
			end)
		end

		ClearNests()

		if (#lootedItems > 0) then
			handleLoot(true)
		end

		checkStep()
		VahlaraB()

		checkStep()
		GuardRahtizB()
		GuardVyrinn()
		checkStep()
		Arachnida()
		checkStep()
		SpiderCaves()
		checkStep()

		levelUp(function ()
			return Me.Subscription() == "FREE" and Me.Level() < 6 or Me.Subscription() == "SILVER" and Me.Level() < 5 or Me.Level() < 4
		end,
		function ()
			workSet.PullRange = 300
		end,
		{
			knownTargets.gloomSpider,
			knownTargets.lurkerSpider,
		})

		SpiderTamer()
		checkStep()

		FinishArachnida()
		SpiderCavesFinish()
		SpiderTamerFinish()
		checkStep()

		if (#lootedItems > 0) then
			handleLoot(false)
		end

		buyClassPet()

		checkStep()
		GuardRahtizC()

		checkLoot("")

		checkContinue()

		checkBlessing()

		FlutterwingA()
		GuardVyrinnB()
		checkStep()

		levelUp(function ()
			return Me.Subscription() == "FREE" and Me.Level() < 8 or Me.Subscription() == "SILVER" and Me.Level() < 6 or Me.Level() < 5
		end,
		function ()
			workSet.PullRange = 500
			workSet.ZRadius = 1000
		end,
		{
			knownTargets.gloomSpider,
			knownTargets.lurkerSpider,
		})

		Arachnophobia()
		checkStep()

		levelUp(function ()
			return Me.Level() < 6
		end,
		function ()
			workSet.PullRange = 500
			workSet.ZRadius = 1000
			knownTargets.gloomSpider.Priority = 11
		end,
		{
			knownTargets.gloomSpider,
			knownTargets.lurkerSpider,
		})

		GuardHobart()
		GuardMaddocA()
		checkStep()
		ScoutZajeer()
		ScoutKaikachiA()
		checkStep()
		ScoutingGloomingdeepA()
		checkStep()
		GloomingdeepBattle()
		checkStep()
		GoblinTreachery()
		checkStep()
		ScoutingGloomingdeepB()
		checkStep()
		Sabotage()
		checkStep()
		KoboldLeadership()
		checkStep()
		GloomingdeepBattleFinish()
		checkStep()
		GuardMaddocB()
		checkStep()

		buyClassPet()

		checkContinue()

		checkBlessing()

		checkStep()
		ScoutingGloomingdeepC()
		checkStep()
		GoblinTreacheryFinish()
		checkStep()
		ScoutKaikachiB()
		checkStep()
		BustedLocks()
		checkStep()

		levelUp(function ()
			return Me.Subscription() == "FREE" and Me.Level() < 13 or Me.Subscription() == "SILVER" and Me.Level() < 12 or Me.Level() < 10
		end,
		function ()
			workSet.PullRange = 500
			workSet.ZRadius = 1000

			knownTargets.slaveWarden.Priority = 10
			knownTargets.goblinSlave.Priority = 11
			knownTargets.diseasedRat.Priority = 11

			navToLoc(219, -419, 24)
		end,
		{
			knownTargets.warrior,
			knownTargets.spiritweaver,
			knownTargets.goblinSlave,
			knownTargets.diseasedRat,
			knownTargets.slaveWarden,
			knownTargets.locksmith,
		})

		FlutterwingB()
		checkStep()
		BustedLocksB()
		FlutterwingC()
		checkStep()

		checkContinue()

		checkBlessing()

		levelUp(function ()
			return Me.Subscription() == "FREE" and Me.Level() < 13 or Me.Subscription() == "SILVER" and Me.Level() < 12 or Me.Level() < 11
		end,
		function ()
			workSet.PullRange = 350
			workSet.ZRadius = 1000

			knownTargets.goblinSlave.Priority = 11
			knownTargets.diseasedRat.Priority = 11

			navToLoc(752, -344, -13)
		end,
		{
			knownTargets.ruga,
			knownTargets.warrior,
			knownTargets.diseasedRat,
			knownTargets.goblinSlave,
			knownTargets.spiritweaver,
			knownTargets.slaveWarden,
			knownTargets.plaguebearer,
			knownTargets.pox,
		})

		FreedomStand()
		checkStep()
		FreedomStandFinish()
		checkStep()

		levelUp(function ()
			return Me.Subscription() == "FREE" and Me.Level() < 13 or Me.Subscription() == "SILVER" and Me.Level() < 13 or Me.Level() < 12
		end,
		function ()
			workSet.PullRange = 250
			workSet.ZRadius = 250

			navToLoc(-262, -1723, -99)
		end,
		{
			knownTargets.warrior,
			knownTargets.captain,
			knownTargets.spiritweaver,
			knownTargets.gnikan,
		})

		PitFiend()
		checkStep()
		AriasD()
	end
end

local function basicSetup()
	if (TLO.Plugin("MQ2AutoForage")()) then
		mq.cmd.stopforage()
	end

	if (TLO.Plugin("MQ2AutoLoot")()) then
		mq.cmd.autoloot("turn off")
	end

	checkPlugin("MQ2Nav")
	checkPlugin("MQ2MoveUtils")
	checkPlugin("MQ2Melee")
	checkPlugin("MQ2Cast")

	mq.cmd("/squelch /melee taunt=off")
	checkZone()
	openTaskWnd()
	mq.cmd("/squelch /melee melee=1")
	loadIgnores()
	checkMesh()
	whereAmI()
end

---@param debug? string
local function bindStep(debug, timed)
	if (debug == "debug") then
		currentDebugLevel = debuggingValues.DebugLevel
		debuggingValues.DebugLevel = DebuggingRanks.Deep

		if (timed == "timed") then
			Note.useTimestampConsole = true
		end
	elseif (debug == "continue") then
		debuggingValues.StepProcessing = false
	end

	debuggingValues.LockStep = false
end
mq.bind("/step", bindStep)

local function bindResume()
	workSet.LockContinue = false
end
mq.bind("/resume", bindResume)

local function makeTooltip(desc)
    ImGui.SameLine(0, 0)
	ImGui.SetWindowFontScale(0.75)
    ImGui.TextDisabled(ICON.FA_QUESTION_CIRCLE)
	ImGui.SetWindowFontScale(1.0)

	if (ImGui.IsItemHovered()) then
        ImGui.BeginTooltip()
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
        ImGui.Text(desc)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

local function tutorialUi()
    ImGui.SetNextWindowPos((EQ.ViewportXMax() - 450) / 2, 150, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(450, 155, ImGuiCond.FirstUseEver)
    workSet.UseGui, workSet.DrawGui = ImGui.Begin("Tutorial", workSet.UseGui)

    if (workSet.DrawGui) then
        ImGui.Text("Location: ")
        ImGui.SameLine()
        ImGui.TextColored(0, 1, 0, 1, workSet.Location)
        ImGui.Text("Task: ")
        ImGui.SameLine()
        ImGui.TextColored(1, 1, 0, 1, workSet.Task)

		ImGui.Separator()
        ImGui.Text("Status:")
        ImGui.SameLine()
        ImGui.Text(workSet.ChatTitle)
		ImGui.Separator()

		workSet.ResumeProcessing = ImGui.Checkbox("Break For Spells/Skills", workSet.ResumeProcessing)
		makeTooltip("Pauses the tutorial at specific points to provide an opportunity to purchase/scribe new spells/tomes")

		if (workSet.WaitingForResume) then
            ImGui.SameLine()
			if (ImGui.Button("Resume")) then
				bindResume()
			end
		end

		if (ImGui.CollapsingHeader("Debug")) then
			ImGui.Text("Debugging Level:")
			ImGui.SameLine()
			local previewValue = DebuggingText[debuggingValues.DebugLevel]  -- Pass in the preview value visible before opening the combo (it could be anything)
			ImGui.SetNextItemWidth(100)

			if (ImGui.BeginCombo("##DebuggingLevels", previewValue)) then
				for i = 0, #DebuggingText do
					local isSelected = debuggingValues.DebugLevel == i

					if (ImGui.Selectable(DebuggingText[i], isSelected)) then
						debuggingValues.DebugLevel = i
						currentDebugLevel = i
					end

					if (isSelected) then
						ImGui.SetItemDefaultFocus()
					end
				end

				ImGui.EndCombo()
			end

			ImGui.SameLine()
            ImGui.SetCursorPosX(235)
			debuggingValues.ShowTimingInConsole = ImGui.Checkbox("Show Timing in Console", debuggingValues.ShowTimingInConsole)

			if (debuggingValues.ShowTimingInConsole ~= nil) then
				Note.useTimestampConsole = debuggingValues.ShowTimingInConsole --[[@as boolean]]
			end

            ImGui.SetCursorPosX(235)
			debuggingValues.LogOutput = ImGui.Checkbox("Log Output", debuggingValues.LogOutput)
			makeTooltip(string.format("Output will go to %s", Note.outfile))

			if (debuggingValues.LogOutput ~= nil) then
				Note.useOutfile = debuggingValues.LogOutput --[[@as boolean]]
			end

			debuggingValues.StepProcessing = ImGui.Checkbox("Step Through Tutorial", debuggingValues.StepProcessing)
			makeTooltip("Enable/Disable task stepping (pauses after most tasks)")

			if (debuggingValues.StepProcessing) then
				workSet.ResumeProcessing = false
			else
				workSet.ResumeProcessing = true
			end

			if (debuggingValues.WaitingForStep) then
				ImGui.SameLine()
				if (ImGui.Button("Step")) then
					bindStep()
				end

				ImGui.SameLine()
				ImGui.SetCursorPosX(235)
				debuggingValues.SkipRemainingSteps = ImGui.Checkbox("Continue", debuggingValues.SkipRemainingSteps)
				makeTooltip("Skip any remaining steps")
			end

			if (ImGui.CollapsingHeader("Call Stack")) then
				ImGui.Text(debuggingValues.CallStack:tostring())
			end
		end
    end

	ImGui.End()
end

local function Main()
	basicSetup()

	ImGui.Register('TutorialGUI', tutorialUi)

	if (Zone.ID() == 188) then
		checkMesh()
		JailBreak()
	end

	checkZone()

	if (Zone.ID() == 189) then
		delay(1000)
		Note.Info("Let's get this party started!")
		whereAmI()
		openTaskWnd()

		BasicTraining()

		checkBlessing()

		GloomingdeepRevolt()

		Note.Info("The Tutorial Quest is now complete.")
	else
		Note.Info("\arYou can't use this here! This is for the tutorial!")
	end
end

local function Event_LevelUp()
	closeDialog()
end

mq.event("LevelUp", "#*#You have gained a level!#*#", Event_LevelUp)

local args = {...}
local steps = CreateIcaseTable({
	JailBreak = JailBreak,
	BasicTraining = BasicTraining,
	Hotbars = BasherAlga,
	AriasB = AriasB,
	Lyndroh = Lyndroh,
	Absor = Absor,
	Rytan = Rytan,
	Elegist = Elegist,
	Guard_RahtizA = GuardRahtizA,
	ClearNests = ClearNests,
	VahlaraB = VahlaraB,
	Guard_Vyrinn = GuardVyrinn,
	Guard_RahtizB = GuardRahtizB,
	Guard_RahtizC = GuardRahtizC,
	Arachnida = Arachnida,
	SpiderCaves = SpiderCaves,
	SpiderTamer = SpiderTamer,
	WhereAmI = whereAmI,
	SellLoot = sellInventory,
	ScribeSpells = scribing.scribeSpells,
})

local function processArgs()
	if (#args == 0) then
		return
	end

	local index = 1
	local action = tostring(args[index]):lower()

	if (action == "step") then
		debuggingValues.StepProcessing = true
		workSet.ResumeProcessing = false

		return
	end

	if (action == "nopause") then
		workSet.ResumeProcessing = false

		return
	end

	basicSetup()

	if (action == "debug") then
		debuggingValues.DebugLevel = DebuggingRanks.Deep
		index = index + 1
	end

	action = tostring(args[index]):lower()
	index = index + 1

	if (action == "tutorialcheck") then
		local checkFor = table.concat(args, ' ', index)
		Note.Info("TutorialCheck \ag%s\ax: \ay%s", checkFor, tutorialCheck(checkFor))
	elseif (action == "tutorialselect") then
		local checkFor = table.concat(args, ' ', index)
		Note.Info("TutorialSelect \ag%s\ax: \ay%s", checkFor, tutorialSelect(checkFor))
	elseif (action == "navspawn") then
		navToSpawn(Spawn(args[index]).ID(), findAndKill)
	elseif (action == "navloc") then
		navToLoc(args[index], args[index + 1], args[index + 2])
	elseif (action == "farmstuff") then
		---@type TargetInfo
		local enemy = {
			Name = table.concat(args, ' ', index + 1),
			Type = tostring(args[index])
		}
		farmStuff(enemy)
	elseif (action == "targetshortest") then
		---@type TargetInfo
		local target = {
			Name = table.concat(args, ' ', index + 1),
			Type = tostring(args[index])
		}
		local mobList = {}
		local spawnPattern = string.format("noalert 1 targetable radius %s zradius %s", 1500, 1500)
		local searchExpression = string.format("%s %s \"%s\"", spawnPattern, target.Type, target.Name)

		local mobsInRange = TLO.SpawnCount(searchExpression)()
		printDebugMessage(DebuggingRanks.None, "# mobs in range: %s", mobsInRange)

		for i = 1, mobsInRange do
			local nearest = TLO.NearestSpawn(i, searchExpression)

			--just in case something dies, ignore mobs without a name
			if (nearest.Name() ~= nil and (nearest.TargetOfTarget.ID() == 0 or nearest.TargetOfTarget.Type() == "NPC")) then
				printDebugMessage(DebuggingRanks.None, "\atFound %s — maybe, lets see if it has a path", nearest.Name())

				--If there is a path and only if there is a path will I enter the following block statement. This is done to avoid adding mobs to the array that don't have a path.
				if (Navigation.PathExists("id " .. nearest.ID())()) then

					--Now that it's a good mob, add it to the list
					---@type MobInfo
					local mobInfo = {
						Distance = Navigation.PathLength("id " .. nearest.ID())(),
						Type = target.Type,
						Priority = target.Priority or 10
					}
					mobList[nearest.ID()] = mobInfo
					printDebugMessage(DebuggingRanks.None, "Found path to \aw%s\ax (\aw%s\ax): %s", nearest.Name(), nearest.ID(), mobInfo)
				end
			end
		end

		local sortedKeys = sortMobIds(mobList)
		printDebugMessage(DebuggingRanks.None, "Sorted (by path lengt asc) mob list")

		for _, key in ipairs(sortedKeys) do
			printDebugMessage(DebuggingRanks.None, "%s: %s", key, mobList[key])
		end
	elseif (steps[action]) then
		steps[action]()
	end

	mq.exit()
end

processArgs()

Main()
