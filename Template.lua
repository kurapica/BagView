--========================================================--
--                BagView Template                        --
--                                                        --
-- Author      :  kurapica125@outlook.com                 --
-- Create Date :  2021/06/25                              --
--========================================================--

--========================================================--
Scorpio           "BagView.Template"                 "1.0.0"
--========================================================--

_GameTooltip                    = CreateFrame("GameTooltip", "BagView_Container_Tooltip", UIParent, "GameTooltipTemplate")
IsReagentBankUnlocked           = _G.IsReagentBankUnlocked or Toolset.fakefunc

__Sealed__() __InstantApplyStyle__()
class "BagButton" { SecureActionButton }

__Sealed__()
class "BagPanel"  (function(_ENV)
    inherit "SecurePanel"

    function __ctor(self)
        super(self)

        -- The count is stable when using
        self.ElementType        = BagButton
        self.ElementPrefix      = self:GetName() .. "Button"

        self.RowCount           = 1
        self.ColumnCount        = 12
        self.ElementWidth       = 36
        self.ElementHeight      = 36

        self.Orientation        = Orientation.HORIZONTAL
        self.HSpacing           = 2
        self.VSpacing           = 2

        self.MarginTop          = 1
        self.MarginBottom       = 1
        self.MarginLeft         = 1
        self.MarginRight        = 1

        self.OnElementRemove    = self.OnElementRemove + function (self, btn) btn:SetAction(nil) end
    end
end)

__Sealed__()
class "ContainerButton" (function(_ENV)
    inherit "ContainerFrameItemButton"

    ------------------------------------------------------
    --                     Method                       --
    ------------------------------------------------------
    if Scorpio.IsRetail then
        function Refresh(self)
            local bag, slot     = self.ActionTarget, self.ActionDetail
            if bag and slot then
                local itemId    = GetContainerItemID(bag, slot)
                if itemId then
                    local _, _, _, iLevel, _, _, _, _, equipSlot = GetItemInfo(itemId)
                    if equipSlot and equipSlot ~= "" and equipSlot ~= "INVTYPE_BAG" then
                        for i, left in GetGameTooltipLines("BagItem", bag, slot) do
                            if i < 5 then
                                local lvl = tonumber(left:match("%d+$"))
                                if lvl then
                                    self.ItemLevel = lvl
                                    return
                                end
                            else
                                break
                            end
                        end

                        self.ItemLevel  = iLevel
                        return
                    end
                end
            end

            self.ItemLevel      = nil
        end
    end

    ------------------------------------------------------
    --               Observable Property                --
    ------------------------------------------------------
    --- Whether show the button grid
    __Observable__()
    property "ItemLevel"        { type = Number }
end)

__Sealed__() __InstantApplyStyle__()
class "Container" (function(_ENV)
    inherit "SecurePanel"

    RECYCLE_BUTTONS             = Recycle(ContainerButton, "BagViewContainerButton%d", UIParent)

    function RECYCLE_BUTTONS:OnPush(button)
        button:SetAction(nil)
        button:ClearAllPoints()
    end

    ------------------------------------------------------
    -- Property
    ------------------------------------------------------
    --- The Element Recycle
    property "ElementPool"      { default = RECYCLE_BUTTONS }

    --- The Element Type
    property "ElementType"      { default = ContainerButton }

    ------------------------------------------------------
    -- Observable Property
    ------------------------------------------------------
    __Observable__()
    property "Name"             { type = String }
end)

__Sealed__()
class "ContainerView" (function(_ENV)
    inherit "SecureFrame"

    export { tinsert = table.insert, tremove = table.remove, tconcat = table.concat }

    local function tpairs(...)
        return ThreadPool.Default:GetIterator(...)
    end

    local function matchText(txt, lst)
        for _, v in ipairs(lst) do if txt:match(v) then return true end end
        return false
    end

    local function buildContainerRules(containerRules, itemList, isBank)
        if not containerRules or #containerRules == 0 then return nil end

        local defines           = {}
        local codes             = {}
        local scanConds         = {}
        local scanCodes         = {}

        local bags              = {}
        local evts              = {}

        local groupCnt          = 0
        local ruleCnt           = 0
        local filterList        = {}

        for i, containerRule in ipairs(containerRules) do
            if containerRule and #containerRule > 0 then
                groupCnt        = groupCnt + 1

                for j, rules in ipairs(containerRule) do
                    if rules and (#rules > 0 or rules.TooltipFilter) then
                        ruleCnt                 = ruleCnt + 1

                        local cond              = {}
                        local requireBag        = false

                        if rules.TooltipFilter then
                            local filter        = {}
                            rules.TooltipFilter:gsub("[^;]+", function(w)
                                w = strtrim(w)
                                if w ~= "" then
                                    tinsert(filter, w)
                                end
                            end)
                            filterList[ruleCnt] = filter
                        else
                            filterList[ruleCnt] = false
                        end

                        for k, rule in ipairs(rules) do
                            if _ItemConditions[math.abs(rule)] then
                                if _ItemConditions[math.abs(rule)].RequireEvent then
                                    for i, v in ipairs(_ItemConditions[math.abs(rule)].RequireEvent) do
                                        if not evts[v] then
                                            tinsert(evts, v)
                                            evts[v] = true
                                        end
                                    end
                                end
                                if rule > 0 then
                                    if not bags.RequireAll and _ItemConditions[rule].RequireBag then
                                        requireBag  = true
                                        for i, v in ipairs(_ItemConditions[rule].RequireBag) do
                                            bags[v] = true
                                        end
                                    end

                                    tinsert(cond, _ItemConditions[rule].Condition)
                                else
                                    if not bags.RequireAll and _ItemConditions[math.abs(rule)].DenyBag then
                                        requireBag = true
                                        for i, v in ipairs(_ItemConditions[math.abs(rule)].DenyBag) do
                                            bags[v] = true
                                        end
                                    end

                                    tinsert(cond, "not " .. _ItemConditions[math.abs(rule)].Condition)
                                end
                            end
                        end

                        if not requireBag then
                            bags.RequireAll     = true
                        end

                        if #cond > 0 then
                            cond                = tconcat(cond, " and ")
                        elseif filterList[ruleCnt] then
                            cond                = "true"
                        else
                            cond                = "false"
                        end

                        tinsert(defines, ("local isRule%d = %s\nlocal ruleFilterMatch%d = %s"):format(ruleCnt, cond, ruleCnt, filterList[ruleCnt] and "false" or "true"))

                        if filterList[ruleCnt] then
                            tinsert(scanConds, ("(isRule%d and filterList[%d])"):format(ruleCnt, ruleCnt))
                            tinsert(scanCodes, ("ruleFilterMatch%d = ruleFilterMatch%d or matchText(tipText, filterList[%d])"):format(ruleCnt, ruleCnt, ruleCnt))
                        end

                        tinsert(codes, ("if isRule%d and ruleFilterMatch%d then yield(%d, bag, slot) else"):format(ruleCnt, ruleCnt, groupCnt))
                    end
                end
            end
        end

        if #codes == 0 then
            return function() end
        else
            tinsert(codes, " end")
        end

        codes                   = tconcat(codes, "") or "if true then return end"

        local containerList

        if bags.RequireAll then
            if isBank then
                if Scorpio.IsRetail then
                    containerList   = { BANK_CONTAINER, 5, 6, 7, 8, 9, 10, 11 }
                else
                    containerList   = { BANK_CONTAINER, REAGENTBANK_CONTAINER, 5, 6, 7, 8, 9, 10, 11 }
                end
            else
                containerList   = { 0, 1, 2, 3, 4 }
            end
        else
            containerList       = {}
            for k in pairs(bags) do if tonumber(k) then tinsert(containerList, k) end end
            table.sort(containerList)
        end

        for k in pairs(evts) do
            if type(k) == "string" then
                evts[k]         = nil
            end
        end

        if #evts == 0 then evts = nil end

        codes                   = ([[
            local containerList, itemList, filterList, matchText = ...
            local yield                     = coroutine.yield
            local GetContainerItemInfo      = GetContainerItemInfo
            local GetContainerItemQuestInfo = GetContainerItemQuestInfo or PLoop.System.Toolset.fakefunc
            local GetItemInfo               = GetItemInfo
            local GetItemSpell              = GetItemSpell
            local IsNewItem                 = C_NewItems and C_NewItems.IsNewItem or PLoop.System.Toolset.fakefunc
            local BANK_CONTAINER            = BANK_CONTAINER
            local REAGENTBANK_CONTAINER     = REAGENTBANK_CONTAINER or 99999
            local GameTooltip               = BagView_Container_Tooltip
            local BankButtonIDToInvSlotID   = BankButtonIDToInvSlotID
            local ReagentBankButtonIDToInvSlotID = ReagentBankButtonIDToInvSlotID or PLoop.System.Toolset.fakefunc
            local pcall                     = pcall
            local SetInventoryItem          = GameTooltip.SetInventoryItem
            local SetBagItem                = GameTooltip.SetBagItem

            return function()
                for _, bag in ipairs(containerList) do
                    for slot = 1, GetContainerNumSlots(bag) do
                        local _, count, _, quality, readable, lootable, link, _, hasNoValue, itemID = GetContainerItemInfo(bag, slot)
                        local isQuest, questId, isActive = GetContainerItemQuestInfo(bag, slot)
                        local name, iLevel, reqLevel, cls, subclass, maxStack, equipSlot, vendorPrice
                        local itemSpell, isNewItem

                        if itemID then
                            name, _, _, iLevel, reqLevel, cls, subclass, maxStack, equipSlot, _, vendorPrice = GetItemInfo(itemID)
                            itemSpell = GetItemSpell(itemID)
                            isNewItem = (bag >= 0 and bag <= 4) and IsNewItem(bag, slot)
                        end

                        %s

                        if %s then
                            local ok, msg

                            GameTooltip:SetOwner(UIParent)
                            if bag == BANK_CONTAINER then
                                ok, msg = pcall(SetInventoryItem, GameTooltip,"player", BankButtonIDToInvSlotID(slot))
                            elseif bag == REAGENTBANK_CONTAINER then
                                ok, msg = pcall(SetInventoryItem, GameTooltip, "player", ReagentBankButtonIDToInvSlotID(slot))
                            else
                                ok, msg = pcall(SetBagItem, GameTooltip, bag, slot)
                            end

                            if ok then
                                local i = 1
                                local t = _G["BagView_Container_TooltipTextLeft"..i]

                                while t and t:IsShown() do
                                    local tipText = t:GetText()
                                    if tipText and tipText ~= "" then
                                        %s
                                    end

                                    i = i + 1
                                    t = _G["BagView_Container_TooltipTextLeft"..i]
                                end
                            end
                            GameTooltip:Hide()
                        end

                        %s
                    end
                end
            end
        ]]):format(tconcat(defines, "\n"), #scanConds>0 and tconcat(scanConds, " or ") or "false", tconcat(scanCodes, "\n"), codes)

        return loadstring(codes)(containerList, itemList or {}, filterList, matchText), evts
    end

    local function OnShow(self)
        self.OnShow             = self.OnShow - OnShow
        return self.Dispatch and not self.TaskMark and self:StartRefresh()
    end

    local function refreshContainer(self, ...)
        self.TaskMark           = (self.TaskMark or 0) + 1

        local taskMark          = self.TaskMark
        local dispatch          = self.Dispatch
        local count             = self.RuleCount or 0
        local containerCnt      = {}
        local configName        = self.ConfigName
        if not dispatch or count == 0 then return end

        while self.TaskMark == taskMark do
            NoCombat()

            if self.TaskMark ~= taskMark then break end

            for i = 1, count do containerCnt[i] = 0 end

            local replaceCnt    = 0
            local chkCount      = self.LoadInstant and 999 or self.FirstLoaded and 4 or 10
            local restartGen    = false
            local st            = GetTime()

            -- Debug("Process refreshContainer @pid %d for %s step %d", taskMark, configName, chkCount)

            for id, bag, slot in tpairs(dispatch) do
                containerCnt[id]= containerCnt[id] + 1
                local ele       = self[id].Elements[containerCnt[id]]
                if ele.ActionTarget ~= bag or ele.ActionDetail ~= slot then
                    ele:SetAction("bagslot", bag, slot)

                    replaceCnt  = replaceCnt + 1
                    if replaceCnt % chkCount == 0 then
                        Next()

                        while InCombatLockdown() do
                            -- well, bad luck
                            local ret = Wait(0.5, "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", ...)
                            if ret and ret ~= "PLAYER_REGEN_ENABLED" then
                                restartGen = true
                                break
                            end
                        end
                    end
                end
            end

            -- Debug("Finish refreshContainer @pid %d for %s cost %.2f", taskMark, configName, GetTime() - st)

            if not restartGen then
                self.FirstLoaded    = false

                for i = 1, count do
                    self[i].Count   = containerCnt[i]
                end

                Wait("BAG_UPDATE_DELAYED", ...)
                Next()
            end
        end

        -- Debug("Stop refreshContainer @pid %d for %s", taskMark, configName)
    end

    local function refreshBank(self, ...)
        self.TaskMark           = (self.TaskMark or 0) + 1

        local taskMark          = self.TaskMark
        local dispatch          = self.Dispatch
        local count             = self.RuleCount or 0
        local containerCnt      = {}
        local firstRun          = true
        local configName        = self.ConfigName
        if not dispatch or count == 0 then return end

        while self.TaskMark == taskMark do
            if firstRun then
                firstRun        = true
                if not self:GetParent():IsVisible() then
                    NextEvent("BANKFRAME_OPENED")
                end
            else
                NextEvent("BANKFRAME_OPENED")
            end

            while self.TaskMark == taskMark do
                -- should hide the bank frame if in combat
                if InCombatLockdown() then break end
                if self.TaskMark ~= taskMark then break end

                for i = 1, count do containerCnt[i] = 0 end

                local replaceCnt= 0
                local chkCount  = 14
                local st        = GetTime()

                -- Debug("Process refreshBank @pid %d for %s step %d", taskMark, configName, chkCount)

                for id, bag, slot in tpairs(dispatch) do
                    containerCnt[id]    = containerCnt[id] + 1
                    local ele           = self[id].Elements[containerCnt[id]]
                    if ele.ActionTarget ~= bag or ele.ActionDetail ~= slot then
                        ele:SetAction("bagslot", bag, slot)

                        replaceCnt      = replaceCnt + 1
                        if replaceCnt % chkCount == 0 then
                            Next()

                            -- should hide the bank frame if in combat
                            if InCombatLockdown() then break end
                            if self.TaskMark ~= taskMark then break end
                        end
                    end
                end

                -- Debug("Finish refreshBank @pid %d for %s cost %.2f", taskMark, configName, GetTime() - st)

                -- should hide the bank frame if in combat
                if InCombatLockdown() then break end
                if self.TaskMark ~= taskMark then break end

                self.FirstLoaded = true

                for i = 1, count do
                    self[i].Count = containerCnt[i]
                end

                local ret = Wait("BANKFRAME_CLOSED", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED", "PLAYERREAGENTBANKSLOTS_CHANGED", ...)
                if ret == "BANKFRAME_CLOSED" then break end

                local startSort = self:GetParent().StartSort
                if startSort and math.abs(startSort - GetTime()) < 1 then
                    while self.TaskMark == taskMark do
                        ret = Wait(2.5, "BANKFRAME_CLOSED", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "PLAYERREAGENTBANKSLOTS_CHANGED")
                        if ret == "BANKFRAME_CLOSED" then break end
                        if not ret then break end
                    end
                end
                if ret == "BANKFRAME_CLOSED" then break end
                Next() -- Skip more events in the same time
            end
            if self.TaskMark ~= taskMark then break end
        end

        -- Debug("Stop refreshBank @pid %d for %s", taskMark, configName)
    end

    __NoCombat__()
    function ApplyContainerRules(self, containerRules, itemList, isBank, force)
        self.IsBank             = isBank or false  -- Observable, the container in it will receive it for layout

        local dispatch, evts    = buildContainerRules(containerRules, itemList, isBank)
        local count             = containerRules and #containerRules or 0
        local i                 = 1
        local container

        while i <= count do
            container           = self:GetChild(self.ElementPrefix .. i)

            if not container then
                container       = Container(self.ElementPrefix .. i, self)
                self[i]         = container
                container:SetID(i)

                if i == 1 then
                    container:SetPoint("TOPLEFT", self:GetParent(), "BOTTOMLEFT", 2, -8)
                else
                    container:SetPoint("TOPLEFT", self:GetChild(self.ElementPrefix .. (i-1)), "BOTTOMLEFT", 0, -8)
                end
            end

            container:Show()
            container.Name      = containerRules[i].Name -- observable property

            i                   = i + 1
        end

        self:ClearAllPoints()
        self:SetPoint("TOPLEFT",  self:GetParent(), "BOTTOMLEFT", 0, -4)
        self:SetPoint("TOPRIGHT", self:GetParent(), "BOTTOMRIGHT", 0, -4)

        if container then
            self:SetPoint("BOTTOM", container, "BOTTOM", 0, -4)
        else
            self:SetHeight(10)
        end

        local container         = self:GetChild(self.ElementPrefix .. i)
        while container do
            container.Count     = 0
            container:Hide()

            i                   = i + 1
            container           = self:GetChild(self.ElementPrefix .. i)
        end

        self.RuleCount          = count
        self.Dispatch           = dispatch
        self.RequireEvents      = evts


        if dispatch and force then
            self:StartRefresh()
        end
    end

    function StopRefresh(self)
        self.TaskMark           = (self.TaskMark or 0) + 1
    end

    function StartRefresh(self)
        if self.RequireEvents then
            if self.IsBank then
                return Continue(refreshBank, self, unpack(self.RequireEvents))
            else
                return Continue(refreshContainer, self, unpack(self.RequireEvents))
            end
        else
            if self.IsBank then
                return Continue(refreshBank, self)
            else
                return Continue(refreshContainer, self)
            end
        end
    end

    ------------------------------------------------------
    --                     Property                     --
    ------------------------------------------------------
    property "LoadInstant"      { Type = Boolean }
    property "FirstLoaded"      { Type = Boolean, Default = true }

    ------------------------------------------------------
    --               Observable Property                --
    ------------------------------------------------------
    --- Whether show the button grid
    __Observable__()
    property "IsBank"           { type = Boolean }

    ------------------------------------------------------
    --                   Constructor                    --
    ------------------------------------------------------
    function __ctor(self)
        self:Hide()

        self.ElementPrefix      = self:GetName() .. "Container"
        self:SetSize(1, 1)

        self.OnShow             = self.OnShow + OnShow
    end
end)

__Sealed__()
class "ViewButton" (function(_ENV)
    inherit "SecureCheckButton"

    local function OnAttributeChanged(self, name, value)
        if name == "viewactive" then
            self:SetChecked(value)
        end
    end

    __InstantApplyStyle__()
    function __ctor(self)
        self.ContainerView      = ContainerView(self:GetName() .. "View", self:GetParent())
        self.ContainerView:SetPoint("TOPLEFT", self:GetParent(), "BOTTOMLEFT")
        self.ContainerView:SetPoint("TOPRIGHT",self:GetParent(), "BOTTOMRIGHT")

        self:SetFrameRef("ContainerView", self.ContainerView)
        self:SetFrameRef("ViewManager", self:GetParent())

        self:SetAttribute("type", "viewchange")
        self:SetAttribute("_viewchange", [[self:GetFrameRef("ViewManager"):RunFor(self, "ViewManager:RunFor(self, ActiveView)")]])

        self.OnAttributeChanged = self.OnAttributeChanged + OnAttributeChanged
    end
end)

__Sealed__() __SecureTemplate__ "SecureHandlerStateTemplate,SecureHandlerShowHideTemplate"
class "ContainerHeader" (function(_ENV)
    inherit "SecurePanel"

    ANCHORS                     = XList(Enum.GetEnumValues(FramePoint)):Map(function(x) return { Anchor(x, 0, 0) } end):ToList()

    local function OnElementRemove(self, viewBtn)
        viewBtn.ContainerView:StopRefresh()
        viewBtn.ContainerView:ApplyContainerRules(nil)
        viewBtn:Hide()
        self:SetFrameRef("ViewBtn", viewBtn)
        self:Execute[[
            ViewButton[self:GetFrameRef("ViewBtn")] = nil
            self:GetFrameRef("ViewBtn"):GetFrameRef("ContainerView"):Hide()
            self:GetFrameRef("ViewBtn"):SetAttribute("viewactive", false)
        ]]
    end

    local function OnElementAdd(self, viewBtn)
        self:SetFrameRef("ViewBtn", viewBtn)
        viewBtn:Show()
        self:Execute[[
            ViewButton[self:GetFrameRef("ViewBtn")] = true
        ]]
    end

    local function GenerateBankSlots(bagPanel)
        local num           = GetNumBankSlots()
        local cnt           = num
        for i = 1, num do bagPanel.Elements[i]:SetAction("bag", i + 4) end
        if num < NUM_BANKBAGSLOTS then
            _G.BankFrame.nextSlotCost = GetBankSlotCost(num)

            cnt             = cnt + 1

            bagPanel.Elements[cnt]:SetAction("macrotext", "/click BankFramePurchaseButton")
            bagPanel.Elements[cnt].CustomTooltip= _G.BANKSLOTPURCHASE
            bagPanel.Elements[cnt].CustomTexture= [[Interface\PaperDollInfoFrame\Character-Plus]]
        end

        if Scorpio.IsRetail and not IsReagentBankUnlocked() then
            cnt             = cnt + 1

            bagPanel.Elements[cnt]:SetAction("macrotext", "/click ReagentBankFrameUnlockInfoPurchaseButton")
            bagPanel.Elements[cnt].CustomTooltip= _G.BANKSLOTPURCHASE
            bagPanel.Elements[cnt].CustomTexture= [[Interface\PaperDollInfoFrame\Character-Plus]]
        else
            bagPanel.Count  = cnt
        end

        if num < NUM_BANKBAGSLOTS or (Scorpio.IsRetail and not IsReagentBankUnlocked()) then
            Continue(function()
                if Wait("REAGENTBANK_PURCHASED", "PLAYERBANKBAGSLOTS_CHANGED") then
                    return NoCombat(GenerateBankSlots, bagPanel)
                end
            end)
        end
    end

    -----------------------------------------------------------
    --                        method                         --
    -----------------------------------------------------------
    function ApplyConfig(self, configs, force)
        self.Count              = #configs

        for i, config in ipairs(configs) do
            self.Elements[i]:SetText(config.Name)

            self.Elements[i].ContainerView.ConfigName = config.Name
            self.Elements[i].ContainerView:ApplyContainerRules(config.ContainerRules, config.ItemList, self.IsBank, force)
        end
    end

    -----------------------------------------------------------
    --                       property                        --
    -----------------------------------------------------------
    property "IsBank"           { default = false }

    -----------------------------------------------------------
    --                      constructor                      --
    -----------------------------------------------------------
    function __ctor(self)
        super(self)
        self:Hide()

        local name              = self:GetName()

        self:Execute[[
            ViewManager         = self

            ViewButton          = newtable()

            ActiveView          = [=[
                for btn in pairs(ViewButton) do
                    if btn ~= self then
                        btn:GetFrameRef("ContainerView"):Hide()
                        btn:SetAttribute("viewactive", false)
                    else
                        btn:GetFrameRef("ContainerView"):Show()
                        btn:SetAttribute("viewactive", true)
                    end
                end
            ]=]
        ]]

        self:SetMovable(true)
        self:SetClampedToScreen(true)

        self.ElementType        = ViewButton
        self.ElementPrefix      = name .. "View"

        self.RowCount           = 6
        self.ColumnCount        = 4
        self.ElementWidth       = 100
        self.ElementHeight      = 24

        self.Orientation        = Orientation.HORIZONTAL
        self.TopToBottom        = true
        self.HSpacing           = 2
        self.VSpacing           = 2
        self.AutoSize           = true
        self.KeepColumnSize     = true

        self.MarginTop          = 2
        self.MarginBottom       = 30
        self.MarginLeft         = 4
        self.MarginRight        = 52

        self:SetToplevel(true)

        self.OnElementAdd       = self.OnElementAdd + OnElementAdd
        self.OnElementRemove    = self.OnElementRemove + OnElementRemove

        self.Mover              = Mover("Mover", self)

        Style[self.Mover]       = {
            setAllPoints        = true,
            frameStrata         = "LOW"
        }
        self.Mover.OnMouseDown  = self.Mover.OnMouseDown + function() return InCombatLockdown() or nil end
        self.Mover.OnStopMoving = function(self)
            NoCombat(function(self)
                local minrange, anchors = 9999999

                for _, loc in ipairs(ANCHORS) do
                    local new           = self:GetLocation(loc)
                    local range         = math.sqrt( new[1].x ^ 2 + new[1].y ^ 2 )
                    if range < minrange then
                        minrange        = range
                        anchors         = new
                    end
                end

                self:SetLocation(anchors)
                _SVDB.Char.Location[self:GetName()] = anchors
            end, self:GetParent())
        end--]]

        self:SetLocation{ Anchor("TOPRIGHT", -100, - 100) }

        -- Search Box
        local searchBox         = CreateFrame("Editbox", nil, self, "BagSearchBoxTemplate")
        self.SearchBox          = searchBox
        searchBox:SetPoint("BOTTOMLEFT", 8, 4)
        searchBox:SetSize(160, 24)
        searchBox.Left:Hide()
        searchBox.Right:Hide()
        searchBox.Middle:Hide()

        -- Sort btn
        local sortBtn           = SecureButton(name .. "SortButton", self)
        sortBtn:SetSize(28, 26)
        sortBtn:SetPoint("BOTTOMRIGHT", -2, 4)

        Style[sortBtn]          = {
            NormalTexture       = {
                setAllPoints    = true,
                atlas           = AtlasType("bags-button-autosort-up"),
            },
            pushedTexture       = {
                setAllPoints    = true,
                atlas           = AtlasType("bags-button-autosort-down"),
            },
            highlightTexture    = {
                setAllPoints    = true,
                alphaMode       = "ADD",
                file            = [[Interface\Buttons\ButtonHilight-Square]],
            }
        }

        if not self.IsBank then
            sortBtn.PreClick    = function()
                self.StartSort  = GetTime()
            end

            sortBtn.OnEnter     = function(self)
                _GameTooltip:SetOwner(self)
                _GameTooltip:SetText(_G.BAG_CLEANUP_BAGS)
                _GameTooltip:Show()
            end

            sortBtn.OnLeave     = function(self)
                _GameTooltip:Hide()
            end

            sortBtn:SetAttribute("type", "macro")
            sortBtn:SetAttribute("macrotext", "/click BagItemAutoSortButton")
        end

        -- money frame
        local moneyFrame        = CreateFrame("Frame", name .. "_MoneyFrame", self, "SmallMoneyFrameTemplate")
        moneyFrame:SetPoint("BOTTOMRIGHT", sortBtn, "BOTTOMLEFT", -4, 4)
        self.moneyFrame         = moneyFrame

        -- Setting
        local btnContainerSetting = Button("Setting", self)
        btnContainerSetting:SetPoint("TOPRIGHT", -2, -2)
        btnContainerSetting:SetSize(50, 24)

        btnContainerSetting.OnClick = function() return not InCombatLockdown() and showMenu(self) end

        local lblContainerSetting = FontString("Label", btnContainerSetting)
        lblContainerSetting:SetText("?")
        lblContainerSetting:SetFontObject(GameFontHighlight)
        lblContainerSetting:SetPoint("RIGHT", -4, 0)

        local animContainerSetting = AnimationGroup("AutoSwap", btnContainerSetting)
        animContainerSetting:SetToFinalAlpha(false)
        animContainerSetting:SetLooping("REPEAT")

        local alphaContainer = Alpha("Alpha", animContainerSetting)

        alphaContainer:SetOrder(1)
        alphaContainer:SetStartDelay(2)
        alphaContainer:SetDuration(1)
        alphaContainer:SetFromAlpha(1)
        alphaContainer:SetToAlpha(0)

        -- Toggle Container Bag
        local btnToggleContainer = Button("Toggle", self)
        btnToggleContainer:SetPoint("CENTER", self, "BOTTOM")
        btnToggleContainer:SetSize(32, 32)

        Style[btnToggleContainer] = {
            frameStrata         = "HIGH",
            NormalTexture       = {
                file            = [[Interface\PaperDollInfoFrame\StatSortArrows]],
                vertexColor     = Color.WHITE,
                texCoords       = RectType(0, 1, 0.5, 1),
                location        = { Anchor("CENTER") },
                size            = Size(16, 16),
            },
        }

        local bagPanel          = BagPanel(name .. "BagPanel", self)
        bagPanel:SetPoint("BOTTOMLEFT", 4, 32)
        bagPanel:Hide()

        local animToggleContainer = AnimationGroup("AnimAlert", btnToggleContainer)
        animToggleContainer:SetLooping("REPEAT")

        local transToggleContainer1 = Translation("Trans1", animToggleContainer)
        transToggleContainer1:SetOrder(1)
        transToggleContainer1:SetDuration(0.1)
        transToggleContainer1:SetOffset(0, 8)

        local transToggleContainer2 = Translation("Trans2", animToggleContainer)
        transToggleContainer2:SetOrder(2)
        transToggleContainer2:SetDuration(1)
        transToggleContainer2:SetOffset(0, -8)

        self.OnShow                 = self.OnShow + function()
            animContainerSetting:Play()
            animToggleContainer:Play()
            animToggleContainer.Count = 0
        end

        self.OnHide                 = self.OnHide + function()
            animContainerSetting:Stop()
            animToggleContainer:Stop()
        end

        alphaContainer.OnFinished   = function(self, requested)
            if not requested then
                if lblContainerSetting:GetText() == "?" then
                    lblContainerSetting:SetText(lblContainerSetting.OldText or "?")
                else
                    lblContainerSetting.OldText = lblContainerSetting:GetText()
                    lblContainerSetting:SetText("?")
                end
            end
        end

        transToggleContainer2.OnFinished = function()
            animToggleContainer.Count = (animToggleContainer.Count or 0) + 1

            if animToggleContainer.Count >= 5 then
                animToggleContainer:Stop()
            end
        end

        btnToggleContainer.OnClick  = function()
            if not InCombatLockdown() then
                if bagPanel:IsShown() then
                    bagPanel:Hide()
                    self.MarginBottom = 30
                    btnToggleContainer:GetNormalTexture():SetPoint("CENTER", 0, 0)
                    btnToggleContainer:GetNormalTexture():SetTexCoord(0, 1, 0.5, 1)
                    transToggleContainer1:SetOffset(0, 8)
                    transToggleContainer2:SetOffset(0, -8)
                else
                    self.MarginBottom = 72
                    if not self.IsFirstTimeToggled then
                        self.IsFirstTimeToggled = true

                        if self.IsBank then
                            GenerateBankSlots(bagPanel)
                        else
                            for i = 0, 4 do bagPanel.Elements[i+1]:SetAction("bag", i) end
                        end
                    end
                    btnToggleContainer:GetNormalTexture():SetPoint("CENTER", 0, 4)
                    btnToggleContainer:GetNormalTexture():SetTexCoord(0, 1, 0, 0.5)
                    transToggleContainer1:SetOffset(0, -8)
                    transToggleContainer2:SetOffset(0, 8)

                    Delay(0.1, bagPanel.Show, bagPanel)
                end
            end
        end

        if not self.IsBank then
            Next(function()
                while true do
                    if not self:IsShown() then Next(Observable.From(self.OnShow)) end

                    local _, tarFamily  = GetContainerNumFreeSlots(0)
                    local sFree, sTotal, free, total, bagFamily = 0, 0
                    for i = 0, 4 do
                        free, bagFamily = GetContainerNumFreeSlots(i)
                        total           = GetContainerNumSlots(i)
                        if bagFamily == tarFamily then
                            sFree       = sFree + free
                            sTotal      = sTotal + total
                        end
                    end

                    if sFree < math.min(10, sTotal/4) then
                        lblContainerSetting:SetText(("(%s/%s)"):format(Color.RED .. (sTotal-sFree) .. Color.CLOSE, sTotal))
                    else
                        lblContainerSetting:SetText(("(%s/%s)"):format(sTotal-sFree, sTotal))
                    end

                    NextEvent("BAG_UPDATE_DELAYED")
                end
            end)
        end
    end
end)

__Sealed__()
class "BankHeader" (function(_ENV)
    inherit "ContainerHeader"

    property "IsBank" { default = true }

    -----------------------------------------------------------
    --                      constructor                      --
    -----------------------------------------------------------
    function __ctor(self)
        super(self)

        local name              = self:GetName()

        self.RowCount           = 6
        self.ColumnCount        = 5
        self.ElementWidth       = 95
        self.ElementHeight      = 24

        -- Sort btn
        local sortBtn           = SecureButton(name .. "SortButton", self)

        sortBtn.PreClick        = function()
            _G.BankFrame.activeTabIndex = 1
            self.StartSort      = GetTime()
        end
        sortBtn.OnEnter         = function(self)
            _GameTooltip:SetOwner(self)
            _GameTooltip:SetText(_G.BAG_CLEANUP_BANK)
            _GameTooltip:Show()
        end
        sortBtn.OnLeave         = function(self)
            _GameTooltip:Hide()
        end

        sortBtn:SetAttribute("type", "macro")
        sortBtn:SetAttribute("macrotext", "/click BankItemAutoSortButton")

        if Scorpio.IsRetail then
            sortBtn             = SecureButton(name .. "SortButton2", self)
            sortBtn:SetSize(28, 26)
            sortBtn:SetPoint("BOTTOMRIGHT", -30, 4)

            Style[sortBtn]      = {
                NormalTexture   = {
                    setAllPoints= true,
                    atlas       = AtlasType("bags-button-autosort-up"),
                },
                pushedTexture   = {
                    setAllPoints= true,
                    atlas       = AtlasType("bags-button-autosort-down"),
                },
                highlightTexture= {
                    setAllPoints= true,
                    alphaMode   = "ADD",
                    file        = [[Interface\Buttons\ButtonHilight-Square]],
                }
            }

            sortBtn.PreClick    = function()
                _G.BankFrame.activeTabIndex = 2
                self.StartSort  = GetTime()
            end
            sortBtn.OnEnter     = function(self)
                _GameTooltip:SetOwner(self)
                _GameTooltip:SetText(_G.BAG_CLEANUP_REAGENT_BANK)
                _GameTooltip:Show()
            end
            sortBtn.OnLeave     = function(self)
                _GameTooltip:Hide()
            end

            sortBtn:SetAttribute("type", "macro")
            sortBtn:SetAttribute("macrotext", "/click BankItemAutoSortButton")

            sortBtn             = BagButton(name .. "DepositButton", self)
            Style[sortBtn]      = {
                size            = Size(28, 28),
                location        = { Anchor("BOTTOMRIGHT", -58, 4) },
            }

            sortBtn:SetAction("custom", function()
                if not InCombatLockdown() and IsReagentBankUnlocked() then
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
                    DepositReagentBank()
                end
            end)
            sortBtn.CustomTooltip   = _G.REAGENTBANK_DEPOSIT
            sortBtn.CustomTexture   = 644387
        end

        self.moneyFrame:ClearAllPoints()
        self.moneyFrame:SetPoint("BOTTOMRIGHT", sortBtn, "BOTTOMLEFT", -4, 4)

        local btnContainerSetting = Button("Setting", self)
        local lblContainerSetting = FontString("Label", btnContainerSetting)

        Continue(function()
            while true do
                NextEvent("BANKFRAME_OPENED")

                while true do
                    local _, tarFamily  = GetContainerNumFreeSlots(0)
                    local sFree, sTotal, free, total, bagFamily = 0, 0

                    sFree               = sFree + GetContainerNumFreeSlots(BANK_CONTAINER)
                    sTotal              = sTotal + GetContainerNumSlots(BANK_CONTAINER)

                    local numSlots      = GetNumBankSlots()

                    for i = 1, numSlots do
                        free, bagFamily = GetContainerNumFreeSlots(i + 4)
                        total           = GetContainerNumSlots(i + 4)

                        if bagFamily == tarFamily then
                            sFree       = sFree + free
                            sTotal      = sTotal + total
                        end
                    end
                    if sFree < math.min(10, sTotal/4) then
                        lblContainerSetting:SetText(("(%s/%s)"):format(Color.RED .. (sTotal-sFree) .. Color.CLOSE, sTotal))
                    else
                        lblContainerSetting:SetText(("(%s/%s)"):format(sTotal-sFree, sTotal))
                    end

                    if Wait("BANKFRAME_CLOSED", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED") == "BANKFRAME_CLOSED" then break end
                end
            end
        end)
    end
end)