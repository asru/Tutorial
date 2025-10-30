local mq = require('mq')
local ImGui = require 'ImGui'

local arg = { ... }

local running = true
local myName = mq.TLO.Me.DisplayName()
local CheckItemName = ''
local CheckItemQuantity = 0
local StartAmount = 0
local ItemSlot = 0
local ItemSlot2 = 0
local window_flags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize)
local openGUI, drawGUI = true, true
local combo_selected = 1
local connected_list = {}
local cchheader = "\ay[\agMYCCH\ay]"
local action = "WAIT"
local DEBUG = false
local SHOW_UI = false  -- Toggle: show item detail window (bags will open during collect for reliability)
-- Remote action scheduler (to avoid blocking ImGui callbacks)
local remote_task = nil -- {peer=string, oneshot=string, cooldown=integer}


if mq.TLO.Plugin('mq2dannet').IsLoaded() == false then
    printf("%s \aoDanNet is required for this plugin.  \arExiting", cchheader)
    mq.exit()
end

local function realestate_window_open()
    return mq.TLO.Window('RealEstateItemsWnd').Open()
end

local function item_moved_to_inventory()
    if mq.TLO.FindItem("=" .. CheckItemName) ~= nil then return true end
    return false
end

local function display_window_open()
    if mq.TLO.Window("ItemDisplayWindow").Child("IDW_ItemInfo1").Text() == CheckItemName then return true end
    return false
end

local function check_item_count()
    if tonumber(mq.TLO.FindItemCount("=" .. CheckItemName)() or 0) ~= StartAmount then return true end
    return false
end

local function closet_button_ready()
    return mq.TLO.Window("REIW_ItemsPage").Child("REIW_Move_Closet_Button").Enabled()
end

local function inventory_button_ready()
    return mq.TLO.Window("REIW_ItemsPage").Child("REIW_Move_Inventory_Button").Enabled()
end

local function check_item_returned()
    if not (tonumber(mq.TLO.FindItemCount("=" .. CheckItemName)() or 0) > 0) then return true end
    return false
end

-- Wait for item count to change from a starting value within a timeout
local function wait_for_count_change(start_count, timeout_ms)
    local waited = 0
    local step = 50
    while waited < timeout_ms do
        local current = tonumber(mq.TLO.FindItemCount("=" .. CheckItemName)() or 0)
        if current ~= start_count then return true end
        mq.delay(step)
        waited = waited + step
    end
    return tonumber(mq.TLO.FindItemCount("=" .. CheckItemName)() or 0) ~= start_count
end

-- Find first empty slot in bags that can accept the item on cursor; returns {pack, slot} or nil
local function find_empty_slot()
    local cursorItem = mq.TLO.Cursor()
    if not cursorItem or cursorItem.ID() == nil then return nil end
    
    -- Blacklist: tradeskill-only containers that reject regular items
    local tradeskillOnlyContainers = {
        [67633] = true,  -- Extraplanar Trade Satchel
        -- Add Trademaster's Component Satchel ID when available
    }
    
    for i = 1, 10 do
        local container = mq.TLO.InvSlot('pack' .. i).Item
        if container.Container() and container.Container() > 0 then
            local containerID = container.ID()
            -- Skip tradeskill-only containers
            if not tradeskillOnlyContainers[containerID] then
                local sizeCapacity = container.SizeCapacity()
                for j = 1, container.Container() do
                    if mq.TLO.InvSlot('pack' .. i).Item.Item(j).ID() == nil then
                        -- Slot is empty; verify size fits (0 = no size restriction)
                        if sizeCapacity == 0 or cursorItem.Size() <= sizeCapacity then
                            return {pack = i, slot = j}
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Place cursor item directly into specified pack/slot; returns true on success
local function place_cursor_in_slot(pack, slot)
    if not (mq.TLO.Cursor() and mq.TLO.Cursor.ID() ~= nil) then return false end
    mq.cmdf("/nomodkey /itemnotify in pack%s %s leftmouseup", pack, slot)
    mq.delay(300)
    return mq.TLO.Cursor() == nil or mq.TLO.Cursor.ID() == nil
end

-- Ensure cursor is clear by placing into first available slot
-- Returns true if cleared, false if item still on cursor
local function ensure_cursor_clear(timeout_ms)
    local waited = 0
    local step = 50
    while waited < timeout_ms do
        local hasCursor = mq.TLO.Cursor() and mq.TLO.Cursor.ID() ~= nil
        if not hasCursor then return true end
        -- Try direct placement first
        local emptySlot = find_empty_slot()
        if emptySlot then
            if place_cursor_in_slot(emptySlot.pack, emptySlot.slot) then
                return true
            end
        end
        -- Fallback to /autoinventory if direct placement fails
        mq.cmd('/autoinventory')
        mq.delay(step)
        waited = waited + step
    end
    return mq.TLO.Cursor() == nil or mq.TLO.Cursor.ID() == nil
end

-- Force cursor item to housing storage (for when bags are full)
local function cursor_to_storage()
    if not (mq.TLO.Cursor() and mq.TLO.Cursor.ID() ~= nil) then return end
    local cursorName = mq.TLO.Cursor.Name()
    if mq.TLO.Window("REIW_ItemsPage").Child("REIW_Move_Closet_Button").Enabled() then
        mq.cmd("/nomodkey /shift /notify RealEstateItemsWnd REIW_Move_Closet_Button leftmouseup")
    elseif mq.TLO.Window("REIW_ItemsPage").Child("REIW_Move_Crate_Button").Enabled() then
        mq.cmd("/nomodkey /shift /notify RealEstateItemsWnd REIW_Move_Crate_Button leftmouseup")
    end
    mq.delay(1000)
    if DEBUG then printf("%s \aoForced cursor item to storage: \at%s", cchheader, cursorName) end
end

-- Wait for current CheckItemName to appear in inventory; returns true if present before timeout_ms
local function wait_for_item_in_inventory(timeout_ms)
    local waited = 0
    local step = 50
    while waited < timeout_ms do
        -- If the item is on the cursor, stash it, then continue waiting for it to appear in inventory
        if mq.TLO.Cursor() and mq.TLO.Cursor.Name() == CheckItemName then
            mq.cmd('/autoinventory')
            mq.delay(step)
        end
        if mq.TLO.FindItem("=" .. CheckItemName)() ~= nil then return true end
        mq.delay(step)
        waited = waited + step
    end
    return mq.TLO.FindItem("=" .. CheckItemName)() ~= nil
end

-- Resolve ItemSlot/ItemSlot2 for current CheckItemName with a timeout; returns true on success
local function resolve_item_slot_with_timeout(timeout_ms)
    local waited = 0
    local step = 50
    while waited < timeout_ms do
        local item = mq.TLO.FindItem("=" .. CheckItemName)
        if item() ~= nil and item.ItemSlot() ~= nil then
            ItemSlot = item.ItemSlot() - 22
            ItemSlot2 = item.ItemSlot2() + 1
            return true
        end
        mq.delay(step)
        waited = waited + step
    end
    return false
end

local function return_item_to_storage(fast)
    local loopcount = 1
    local waitShort = fast and "0.8s" or "5s"
    mq.cmdf("/nomodkey /itemnotify in pack%s %s leftmouseup", ItemSlot, ItemSlot2)
    mq.delay(waitShort, closet_button_ready)
    while tonumber(mq.TLO.FindItemCount("=" .. CheckItemName)() or 0) > 0 do
        if mq.TLO.Window("REIW_ItemsPage").Child("REIW_Move_Closet_Button").Enabled() then
            mq.cmd(
                "/nomodkey /shift /notify RealEstateItemsWnd REIW_Move_Closet_Button leftmouseup")
        elseif mq.TLO.Window("REIW_ItemsPage").Child("REIW_Move_Crate_Button").Enabled() then
            mq.cmd(
                "/nomodkey /shift /notify RealEstateItemsWnd REIW_Move_Crate_Button leftmouseup")
        end
        if loopcount == 5 then
            mq.cmdf("/nomodkey /itemnotify in pack%s %s leftmouseup", ItemSlot, ItemSlot2)
            loopcount = 1
        else
            loopcount = loopcount + 1
        end
    end
    mq.delay(waitShort, check_item_returned)
    mq.delay(waitShort, inventory_button_ready)
end

-- Find all pack/slot pairs in inventory that contain items matching the given name
local function find_item_slots_by_name(itemName)
    local slots = {}
    for i = 1, 10 do
        local container = mq.TLO.InvSlot('pack' .. i).Item
        if container.Container() and container.Container() > 0 then
            for j = 1, container.Container() do
                local slotItem = mq.TLO.InvSlot('pack' .. i).Item.Item(j)
                if slotItem() ~= nil and slotItem.Name() == itemName then
                    table.insert(slots, {pack = i, slot = j})
                end
            end
        end
    end
    return slots
end

-- Combine multiple stacks of the same item in inventory into as few stacks as possible
local function consolidate_stacks_in_inventory(itemName)
    local safety = 0
    while true do
        local slots = find_item_slots_by_name(itemName)
        if #slots <= 1 then return end
        -- Pick up from last and drop onto first to merge
        local source = slots[#slots]
        local target = slots[1]
        -- Pick up source stack to cursor
        mq.cmdf("/nomodkey /itemnotify in pack%s %s leftmouseup", source.pack, source.slot)
        mq.delay(200)
        -- If nothing on cursor, break to avoid infinite loop
        if not (mq.TLO.Cursor() and mq.TLO.Cursor.ID() ~= nil) then return end
        -- Drop onto target to merge
        mq.cmdf("/nomodkey /itemnotify in pack%s %s leftmouseup", target.pack, target.slot)
        mq.delay(300)
        ensure_cursor_clear(500)
        safety = safety + 1
        if safety > 20 then return end
    end
end

-- Return all stacks of itemName currently in inventory back to Real Estate storage
local function return_all_stacks_to_storage(itemName, fast)
    local safety = 0
    while tonumber(mq.TLO.FindItemCount("=" .. itemName)() or 0) > 0 do
        local slots = find_item_slots_by_name(itemName)
        if #slots == 0 then break end
        local s = slots[1]
        CheckItemName = itemName
        ItemSlot = s.pack
        ItemSlot2 = s.slot
        return_item_to_storage(fast)
        safety = safety + 1
        if safety > 40 then break end
    end
end

local function open_windows()
    -- Always open inventory and bags for reliable /itemnotify on pack slots
    if not mq.TLO.Window('InventoryWindow').Open() then
        mq.cmd("/squelch /windowstate InventoryWindow open")
    end
    mq.cmd("/keypress OPEN_INV_BAGS")
    if not mq.TLO.Window('RealEstateItemsWnd').Open() then
        mq.cmd("/squelch /windowstate RealEstateItemsWnd open")
        mq.delay('2s', realestate_window_open)
    end
end

local function close_windows()
    -- Close bags and inventory after work
    mq.cmd("/keypress CLOSE_INV_BAGS")
    if mq.TLO.Window('InventoryWindow').Open() then
        mq.cmd("/squelch /windowstate InventoryWindow close")
    end
    if mq.TLO.Window('RealEstateItemsWnd').Open() then
        mq.cmd("/squelch /windowstate RealEstateItemsWnd close")
        mq.delay('2s', realestate_window_open)
    end
end

-- Build a snapshot of visible items (names, IDs, and quantities) to process
-- Only includes items with 'V' tag (collectibles/tradeskill items)
local function build_visible_item_list()
    local items = {}
    local i = 1
    local list = mq.TLO.Window('RealEstateItemsWnd').Child('REIW_ItemList')
    while list.List(i, 2).Length() do
        if list.List(i, 3)() == 'V' then
            local itemName = list.List(i, 2)()
            local itemQty = list.List(i, 4)()
            -- Try to get item ID from the list (column 1 might be ID, or we use name as fallback)
            local itemID = list.List(i, 1)()
            if itemName and itemName ~= '' then
                table.insert(items, {name = itemName, id = itemID, quantity = itemQty})
            end
        end
        i = i + 1
    end
    return items
end

-- Find the row number for a specific item by ID or name in the current list
-- Uses ID for fast numeric comparison when available, falls back to name
local function find_item_row(itemID, itemName)
    local i = 1
    local list = mq.TLO.Window('RealEstateItemsWnd').Child('REIW_ItemList')
    while list.List(i, 2).Length() do
        if list.List(i, 3)() == 'V' then
            -- Try ID match first (faster than string comparison)
            if itemID and tonumber(itemID) and list.List(i, 1)() == itemID then
                return i
            end
            -- Fallback to name match if ID not available or didn't match
            if list.List(i, 2)() == itemName then
                return i
            end
        end
        i = i + 1
    end
    return nil
end

local function collect_from_house()
    local count = 0
    open_windows()
    mq.delay('1s')
    
    -- Build a snapshot of all visible items at the start
    local itemsToProcess = build_visible_item_list()
    printf("%s \aoFound %d visible items to process", cchheader, #itemsToProcess)
    
    -- Group snapshot by item name (preserving first-seen order of names)
    local groups = {}
    local nameOrder = {}
    for _, it in ipairs(itemsToProcess) do
        if not groups[it.name] then
            groups[it.name] = {entries = {it}}
            table.insert(nameOrder, it.name)
        else
            table.insert(groups[it.name].entries, it)
        end
    end
    
    local processedItems = {}  -- Track names we've successfully handled to avoid reprocessing
    
    -- TODO: Handle open top-level inventory slots (pack1-pack10 without bags)
    --       When EQ places items into empty top-level slots, we should detect and relocate
    --       them into the first available bag slot for consistent processing. Need to add
    --       loop guards and Real Estate window ready-checks before attempting cursor_to_storage
    --       to avoid infinite loops if bags are full or storage window isn't ready.
    
    -- Process each name-group (list may re-sort dynamically)
    for _, name in ipairs(nameOrder) do
        if not processedItems[name] then
        local group = groups[name]
        local entries = group.entries
        CheckItemName = name
        
        -- Pull and consolidate all stacks for this name into inventory (as few stacks as possible)
        for idx, entry in ipairs(entries) do
            -- Find current row in case of resorting
            local targetRow = find_item_row(entry.id, entry.name)
            if not targetRow then
                if DEBUG then printf("%s \ayItem no longer visible: \at%s\ay, skipping.", cchheader, entry.name) end
            else
                mq.cmdf('/notify RealEstateItemsWnd REIW_ItemList Listselect %s', targetRow)
                ensure_cursor_clear(300)
                mq.delay(200, inventory_button_ready)
                if mq.TLO.Window("REIW_ItemsPage").Child("REIW_Move_Inventory_Button").Enabled() then
                    mq.cmd('/nomodkey /shift /notify RealEstateItemsWnd REIW_Move_Inventory_Button leftmouseup')
                end
                local moved = wait_for_item_in_inventory(1200)
                if not moved and mq.TLO.Window("REIW_ItemsPage").Child("REIW_Move_Inventory_Button").Enabled() then
                    mq.cmd('/nomodkey /shift /notify RealEstateItemsWnd REIW_Move_Inventory_Button leftmouseup')
                    moved = wait_for_item_in_inventory(1500)
                end
                if moved then
                    -- Keep only minimal stacks by merging duplicates in inventory
                    consolidate_stacks_in_inventory(name)
                    -- Ensure we don't leave anything on cursor
                    if not ensure_cursor_clear(800) then
                        -- Bags full; return cursor item to storage and continue with next
                        cursor_to_storage()
                        if DEBUG then printf("%s \ayBags full, returned to storage while consolidating: \at%s", cchheader, name) end
                    end
                else
                    if DEBUG then printf("%s \aySkipping non-movable or restricted item in housing: \at%s", cchheader, entry.name) end
                end
            end
        end
        
        -- With stacks consolidated, attempt to collect 1 if not already collected
        -- Note: In fast mode, we right-click without checking collection status first.
        --       If already collected, the count won't change and we return everything to storage.
        --       This avoids opening ItemDisplayWindow for every item (much faster).
        local totalBefore = tonumber(mq.TLO.FindItemCount("=" .. name)() or 0)
        if totalBefore > 0 then
            -- Resolve a slot to interact with
            CheckItemName = name
            if resolve_item_slot_with_timeout(1500) then
                -- Fast path collect check
                ensure_cursor_clear(500)
                local beforeCount = tonumber(mq.TLO.FindItemCount("=" .. name)() or 0)
                mq.cmdf("/nomodkey /itemnotify in pack%s %s rightmouseup", ItemSlot, ItemSlot2)
                if wait_for_count_change(beforeCount, 700) then
                    local afterCount = tonumber(mq.TLO.FindItemCount("=" .. name)() or 0)
                    if afterCount < beforeCount then
                        count = count + 1
                    end
                end
            end
        end
        
        -- Return any remaining stacks back to storage
        return_all_stacks_to_storage(name, true)
        ensure_cursor_clear(500)
        processedItems[name] = true
        end
        mq.delay(10)
    end
    
    -- Legacy per-item loop end label remains for compatibility
        -- (No-op)
    -- end grouped processing
    
    printf("%s \aoDone! I have collected: \ap%s", cchheader, count)
    mq.cmdf("/dgt %s \aoI'm done with my collectibles master! I have collected: \ap%s", cchheader, count)
    close_windows()
end

local function store_in_house()
    open_windows()
    for i = 1, 12 do
        if mq.TLO.InvSlot('pack' .. i).Item.Container() then
            for j = 1, mq.TLO.InvSlot('pack' .. i).Item.Container() do
                if mq.TLO.InvSlot('pack' .. i).Item.Item(j).Collectible() then
                    CheckItemName = mq.TLO.InvSlot('pack' .. i).Item.Item(j).Name()
                    ItemSlot = i
                    ItemSlot2 = j
                    return_item_to_storage()
                end
            end
        end
    end
    ItemSlot = 0
    ItemSlot2 = 0
    CheckItemName = ''
    close_windows()
end

local function collect_inventory_all()
    local count = 0
    if not mq.TLO.Window('InventoryWindow').Open() then
        mq.cmd("/squelch /windowstate InventoryWindow open")
    end
    mq.cmd("/keypress OPEN_INV_BAGS")
    for i = 1, 12 do
        if mq.TLO.InvSlot('pack' .. i).Item.Container() then
            for j = 1, mq.TLO.InvSlot('pack' .. i).Item.Container() do
                if mq.TLO.InvSlot('pack' .. i).Item.Item(j).Collectible() then
                    StartAmount = mq.TLO.FindItemCount("=" .. CheckItemName)()
                    CheckItemName = mq.TLO.InvSlot('pack' .. i).Item.Item(j).Name()
                    mq.cmdf("/nomodkey /altkey /itemnotify in pack%s %s leftmouseup", i, j)
                    mq.delay("2s", display_window_open)
                    mq.delay(500)
                    if mq.TLO.Window("ItemDisplayWindow").Child("IDW_ItemInfo1").Text() ~= CheckItemName then
                        printf(
                            "\arYou maybe bugged, \ao the ItemDisplayWIndow text is showing \ar%s \ao instead of \ay%s",
                            mq.TLO.Window("ItemDisplayWindow").Child("IDW_ItemInfo1").Text(), CheckItemName)
                        print("It is recomended you relog.")
                    else
                        if mq.TLO.Window("ItemDisplayWindow").Child("IDW_CollectedLabel").Text() == "Not Collected" then
                            printf("\ap>>> %s <<< \ag hasn't been collected yet. Doing that now.", CheckItemName)
                            mq.cmd("/invoke ${Window[ItemDisplayWindow].DoClose}")
                            mq.cmdf("/nomodkey /itemnotify in pack%s %s rightmouseup", i, j)
                            mq.delay("3s", check_item_count)
                            count = count + 1
                        else
                            printf("\ap>>> %s <<< \arhas been collected. Ignoring.", CheckItemName)
                            mq.cmd("/invoke ${Window[ItemDisplayWindow].DoClose}")
                        end
                    end
                end
            end
        end
    end
    printf("%s \aoDone! I have collected: \ap%s", cchheader, count)
    mq.cmdf("/dgt %s \aoI'm done with my collectibles master! I have collected: \ap%s", cchheader, count)
end

local function get_all_from_house()
    open_windows()
    
    -- Build a snapshot of all visible items at the start
    local itemsToProcess = build_visible_item_list()
    printf("%s \aoFound %d visible items to retrieve", cchheader, #itemsToProcess)
    
    -- Process each item by ID/name (list may re-sort dynamically)
    for idx, item in ipairs(itemsToProcess) do
        local moved = false  -- Declare here to avoid goto scope issues
        CheckItemName = item.name
        
        -- Find the current row for this item (may have moved due to sorting)
        -- Uses ID for fast lookup, falls back to name if needed
        local targetRow = find_item_row(item.id, item.name)
        if not targetRow then
            printf("%s \ayItem no longer visible: \at%s\ay, skipping.", cchheader, CheckItemName)
            goto continue_get
        end
        
        mq.cmdf('/notify RealEstateItemsWnd REIW_ItemList Listselect %s', targetRow)
        ensure_cursor_clear(300)
        mq.delay(200, inventory_button_ready)
        if mq.TLO.Window("REIW_ItemsPage").Child("REIW_Move_Inventory_Button").Enabled() then
            mq.cmd('/nomodkey /shift /notify RealEstateItemsWnd REIW_Move_Inventory_Button leftmouseup')
        end
        if not wait_for_item_in_inventory(1200) and mq.TLO.Window("REIW_ItemsPage").Child("REIW_Move_Inventory_Button").Enabled() then
            mq.cmd('/nomodkey /shift /notify RealEstateItemsWnd REIW_Move_Inventory_Button leftmouseup')
            moved = wait_for_item_in_inventory(1200)
        else
            moved = true  -- first attempt succeeded
        end
        -- If still not in inventory, try one last select+click cycle before skipping
        if not moved then
            mq.cmdf('/notify RealEstateItemsWnd REIW_ItemList Listselect %s', targetRow)
            mq.delay(200, inventory_button_ready)
            if mq.TLO.Window("REIW_ItemsPage").Child("REIW_Move_Inventory_Button").Enabled() then
                mq.cmd('/nomodkey /shift /notify RealEstateItemsWnd REIW_Move_Inventory_Button leftmouseup')
            end
            moved = wait_for_item_in_inventory(2000)
        end
        if not moved then
            printf("%s \aySkipping non-movable or restricted item in housing: \at%s", cchheader, CheckItemName)
        else
            -- Ensure the item is in a bag slot (not on cursor) before proceeding
            if not ensure_cursor_clear(800) then
                -- Bags full; cursor item won't autoinventory. Return it to storage.
                cursor_to_storage()
                printf("%s \ayBags full, returned to storage: \at%s", cchheader, CheckItemName)
                mq.delay(10)
                goto continue_get
            end
            if mq.TLO.FindItem("=" .. CheckItemName).Collectible() then
                printf("\ap>>> %s <<< \ag moved to inventory.", CheckItemName)
            else
                if resolve_item_slot_with_timeout(3000) then
                    return_item_to_storage()
                else
                    printf("%s \arUnable to resolve inventory slot for: \at%s\ar. Skipping.", cchheader, CheckItemName)
                end
            end
        end
        ::continue_get::
        mq.delay(10)
    end  -- end for loop over items
    close_windows()
end

local function dannet_connected()
    connected_list = {}
    -- Always include self first (plain character name)
    table.insert(connected_list, myName:lower())
    -- Then add DanNet peers, excluding any that match self
    local peers_list = mq.TLO.DanNet.Peers()
    for word in string.gmatch(peers_list, '([^|]+)') do
        -- Extract character name from "server_character" format
        local charName = word:match("_(.+)$") or word
        -- Skip if this peer is the same character (with or without server prefix)
        if charName:lower() ~= myName:lower() and word:lower() ~= myName:lower() then
            table.insert(connected_list, word)
        end
    end
end

local function cmd_mycch(cmd)
    if cmd == nil or cmd == 'help' then
    printf("%s \ar/mycch exit \ao--- Exit script", cchheader)
    printf("%s \ar/mycchhide \ao--- Hide GUI", cchheader)
    printf("%s \ar/mycch show \ao--- Show GUI", cchheader)
    elseif cmd == 'exit' or cmd == 'quit' or cmd == 'stop' then
        running = false
    elseif cmd == 'show' then
        openGUI = true
    elseif cmd == 'hide' then
        openGUI = false
    else
    printf("%s \arUnrecognized command.", cchheader)
    end
end

local function displayGUI()
    if not openGUI then return end
    openGUI, drawGUI = ImGui.Begin("Collector's Clearing House##" .. myName, openGUI, window_flags)
    if drawGUI then
        dannet_connected()
        local comboWidth = 150
        local endWidth = 60
        local spacing = ImGui.GetStyle().ItemSpacing.x
        local rowWidth = comboWidth + spacing + endWidth
        ImGui.PushItemWidth(comboWidth)
        combo_selected = ImGui.Combo('##Combo', combo_selected, connected_list)
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip('Character to perform action')
        end
        ImGui.PopItemWidth()
        ImGui.SameLine()
        if ImGui.Button("End", ImVec2(endWidth, 22)) then
            running = false
        end
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip('End mycch (exit)')
        end
        -- SHOW_UI variable remains for future dev; UI checkbox hidden for daily use
        if ImGui.Button("Store All Collectibles", ImVec2(rowWidth, 22)) then
            if connected_list[combo_selected] == myName:lower() then
                action = 'CALL_STORE'
            else
                -- Queue remote stop->run sequence (no blocking delay in ImGui)
                mq.cmdf("/squelch /dex %s /lua stop mycch", connected_list[combo_selected])
                remote_task = {peer = connected_list[combo_selected], oneshot = "store", cooldown = 3}
                if DEBUG then printf("%s queued remote: %s -> %s", cchheader, connected_list[combo_selected], "store") end
            end
        end
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip('Store all collectibles in housing storage')
        end
    if ImGui.Button("Retrieve All Collectibles", ImVec2(rowWidth, 22)) then
            if connected_list[combo_selected] == myName:lower() then
                action = 'CALL_GET'
            else
                mq.cmdf("/squelch /dex %s /lua stop mycch", connected_list[combo_selected])
                remote_task = {peer = connected_list[combo_selected], oneshot = "grab", cooldown = 3}
                if DEBUG then printf("%s queued remote: %s -> %s", cchheader, connected_list[combo_selected], "grab") end
            end
        end
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip('Retrieve all collectibles from housing storage')
        end
    if ImGui.Button("Collect and Return", ImVec2(rowWidth, 22)) then
            if connected_list[combo_selected] == myName:lower() then
                action = 'CALL_COLLECTH'
            else
                mq.cmdf("/squelch /dex %s /lua stop mycch", connected_list[combo_selected])
                remote_task = {peer = connected_list[combo_selected], oneshot = "collecth", cooldown = 3}
                if DEBUG then printf("%s queued remote: %s -> %s", cchheader, connected_list[combo_selected], "collecth") end
            end
        end
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip('Collect items in housing storage (and return to storage)')
        end
    if ImGui.Button("Collect in Inventory", ImVec2(rowWidth, 22)) then
            if connected_list[combo_selected] == myName:lower() then
                action = 'CALL_COLLECTI'
            else
                mq.cmdf("/squelch /dex %s /lua stop mycch", connected_list[combo_selected])
                remote_task = {peer = connected_list[combo_selected], oneshot = "collecti", cooldown = 3}
                if DEBUG then printf("%s queued remote: %s -> %s", cchheader, connected_list[combo_selected], "collecti") end
            end
        end
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip('Collect collectibles in inventory')
        end
    end
    ImGui.End()
end

local function main()
    dannet_connected()
    for i, name in pairs(connected_list) do
        if name == string.lower(mq.TLO.Me.DisplayName()) then combo_selected = i end
    end
    while running == true do
        mq.delay(200)
        -- Remote scheduler: after a few ticks, send the oneshot to target
        if remote_task ~= nil then
            if remote_task.cooldown > 0 then
                remote_task.cooldown = remote_task.cooldown - 1
            else
                if DEBUG then printf("%s running remote oneshot: %s -> %s", cchheader, remote_task.peer, remote_task.oneshot) end
                mq.cmdf("/squelch /dex %s /lua run mycch oneshot %s", remote_task.peer, remote_task.oneshot)
                remote_task = nil
            end
        end
        if action == "WAIT" then
        elseif action == "CALL_STORE" then
            store_in_house()
            action = 'WAIT'
        elseif action == "CALL_GET" then
            get_all_from_house()
            action = 'WAIT'
        elseif action == "CALL_COLLECTH" then
            collect_from_house()
            action = 'WAIT'
        elseif action == "CALL_COLLECTI" then
            collect_inventory_all()
            action = 'WAIT'
        end
    end
end

if #arg == 0 then
    mq.imgui.init('displayGUI', displayGUI)
    mq.bind('/mycch', cmd_mycch)
    main()
elseif arg[1]:lower() == 'oneshot' then
    if arg[2]:lower() == "collecth" then
        collect_from_house()
    elseif arg[2]:lower() == "collecti" then
        collect_inventory_all()
    elseif arg[2]:lower() == "store" then
        store_in_house()
    elseif arg[2]:lower() == "grab" then
        get_all_from_house()
    end
    -- Ensure oneshot invocations always terminate, even if no work was found
    mq.delay(200)
    mq.exit()
end
