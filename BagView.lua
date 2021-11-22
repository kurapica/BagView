--========================================================--
--                BagView                                 --
--                                                        --
-- Author      :  kurapica125@outlook.com                 --
-- Create Date :  2021/06/25                              --
--========================================================--

--========================================================--
Scorpio           "BagView"                          "1.0.0"
--========================================================--

namespace "BagView"

import "Scorpio.Secure"
import "System.Reactive"
import "System.Text"

LE_ITEM_QUALITY_COMMON          = _G.LE_ITEM_QUALITY_COMMON or _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Common or 1

DEFAULT_CONTAINER_CONFIG        = {
    Name                        = _G.BACKPACK_TOOLTIP,
    ContainerRules              = {
        { {100001} }, -- Any
    },
}

export { tinsert = table.insert, tremove = table.remove }

-------------------------------------------
-- Logger
-------------------------------------------
local logger                    = Logger()
logger:AddHandler(print)

logger:SetPrefix(Logger.LogLevel.Trace, Color.GRAY .. "")
logger:SetPrefix(Logger.LogLevel.Debug, Color.WHITE .. "")
logger:SetPrefix(Logger.LogLevel.Info,  Color.GREEN .. "")
logger:SetPrefix(Logger.LogLevel.Warn,  Color.ORANGE .. "")
logger:SetPrefix(Logger.LogLevel.Error, Color.RED .. "")
logger:SetPrefix(Logger.LogLevel.Fatal, Color.DIMRED .. "")

Trace                           = logger[Logger.LogLevel.Trace]
Debug                           = logger[Logger.LogLevel.Debug]
Info                            = logger[Logger.LogLevel.Info]
Warn                            = logger[Logger.LogLevel.Warn]
Error                           = logger[Logger.LogLevel.Error]
Fatal                           = logger[Logger.LogLevel.Fatal]

-----------------------------------------------------------
-- Addon Event Handler
-----------------------------------------------------------
function OnLoad()
    _SVDB                       = SVManager("BagView_DB", "BagView_CharDB")

    _SVDB:SetDefault            {
        LogLevel                = Logger.LogLevel.Info,

        ContainerConfigs        = {},

        BankViewConfigs         = {}
    }

    _SVDB.Char:SetDefault       {
        AutoRepair              = true,
        AutoRepairCheckRep      = 1,
        AutoSell                = true,
        Location                = {},
        DontSell                = {},
        NeedSell                = {},
    }

    if #_SVDB.ContainerConfigs == 0 then
        _SVDB.ContainerConfigs[1] = {
            Name            = _Locale["Default"],
            ContainerRules  = {
                { {100002} }, -- Backpack
                { {100003} }, -- Container1
                { {100004} }, -- Container2
                { {100005} }, -- Container3
                { {100006} }, -- Container4
            },
        }
    end

    if #_SVDB.BankViewConfigs < 2 then
        _SVDB.BankViewConfigs[1] = {
            Name            = _Locale["Default"],
            ContainerRules  = {
                { {-110002} },
            },
        }

        if Scorpio.IsRetail then
            _SVDB.BankViewConfigs[2] = {
                Name            = _Locale["Reagent"],
                ContainerRules  = {
                    { {110002} }, -- ReagentBank
                },
            }
        end
    end

    logger.LogLevel             = _SVDB.LogLevel


    for i = 1, 13 do
        if _G["ContainerFrame" .. i] then
            _G["ContainerFrame" .. i]:UnregisterAllEvents()
        end
    end

    BankFrame:UnregisterAllEvents()
    BankSlotsFrame:UnregisterAllEvents()
    if _G.ReagentBankFrame then ReagentBankFrame:UnregisterAllEvents() end
end

function OnEnable()
    _ToolDontSell               = _SVDB.Char.DontSell
    _ToolNeedSell               = _SVDB.Char.NeedSell

    --------------------------
    -- Container
    --------------------------
    _ContainerHeader            = ContainerHeader("BagViewContainerHeader")
    _ContainerHeader:ClearAllPoints()
    _ContainerHeader:SetPoint("TOPRIGHT", -140, -100)

    if _SVDB.Char.Location.BagViewContainerHeader then
        _ContainerHeader:SetLocation(_SVDB.Char.Location.BagViewContainerHeader)
    end

    _ToggleButton               = CreateFrame("CheckButton", "BagViewContainerToggle", UIParent, "SecureActionButtonTemplate")
    _ToggleButton:Hide()

    SecureHandlerSetFrameRef(_ToggleButton, "ContainerHeader", Scorpio.UI.GetRawUI(_ContainerHeader))
    SecureHandlerExecute(_ToggleButton, [[ContainerHeader = self:GetFrameRef("ContainerHeader")]])

    _ToggleButton:SetAttribute("type", "toggle")
    _ToggleButton:SetAttribute("_toggle", [[if ContainerHeader:IsShown() then ContainerHeader:Hide() self:CallMethod("OpenBag") else ContainerHeader:Show() self:CallMethod("CloseBag") end]])
    _ToggleButton.OpenBag       = function() PlaySound(SOUNDKIT.IG_BACKPACK_OPEN) end
    _ToggleButton.CloseBag      = function() PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE) end

    SetOverrideBindingClick(_ToggleButton, true, GetBindingKey("OPENALLBAGS") or "B", "BagViewContainerToggle", "LeftButton")
    SetOverrideBindingClick(_ToggleButton, true, GetBindingKey("TOGGLEBACKPACK") or "B", "BagViewContainerToggle", "LeftButton")

    _ContainerHeader:SetFrameRef("ToggleButton", _ToggleButton)
    _ContainerHeader:RegisterStateDriver("autobind", "[combat]enable;disable")
    _ContainerHeader:SetAttribute("_onstate-autobind", [[
        self:SetAttribute("autobindescape", newstate == "enable")
        if newstate == "enable" and self:IsShown() then
            self:GetFrameRef("ToggleButton"):SetBindingClick(true, "ESCAPE", "BagViewContainerToggle", "LeftButton")
        else
            self:GetFrameRef("ToggleButton"):ClearBinding("ESCAPE")
        end
    ]])
    _ContainerHeader:SetAttribute("_onshow", [[
        if self:GetAttribute("autobindescape") then
            self:GetFrameRef("ToggleButton"):SetBindingClick(true, "ESCAPE", "BagViewContainerToggle", "LeftButton")
        end
    ]])
    _ContainerHeader:SetAttribute("_onhide", [[
        self:GetFrameRef("ToggleButton"):ClearBinding("ESCAPE")
    ]])

    --------------------------
    -- Bank
    --------------------------
    _BankHeader                 = BankHeader("BagViewBankHeader", UIParent)
    _BankHeader:ClearAllPoints()
    _BankHeader:SetPoint("TOPLEFT", 10, -100)

    if _SVDB.Char.Location.BagViewBankHeader then
        _BankHeader:SetLocation(_SVDB.Char.Location.BagViewBankHeader)
    end

    _BankHeader:RegisterStateDriver("autohide", "[combat]hide;nohide")
    _BankHeader:SetAttribute("_onstate-autohide", [[
        if newstate == "hide" then self:Hide() end
    ]])

    --------------------------
    -- Apply Configs
    --------------------------
    local configs               = Toolset.clone(_SVDB.ContainerConfigs)
    tinsert(configs, 1, DEFAULT_CONTAINER_CONFIG)

    _ContainerHeader:ApplyConfig(configs)

    _ContainerHeader.Elements[1].ContainerView:Show()
    _ContainerHeader.Elements[1]:SetAttribute("viewactive", true)
    _ContainerHeader.Elements[1].ContainerView.LoadInstant = true
    _ContainerHeader.Elements[1].ContainerView:StartRefresh()

    Next(function()
        local i = 1

        while i <= _ContainerHeader.Count do
            Delay(1)
            NoCombat()

            while i <= _ContainerHeader.Count and _ContainerHeader.Elements[i].ContainerView.TaskMark do
                i = i + 1
            end

            if i <= _ContainerHeader.Count then
                Debug("[Container]Wakeup container %d", i)

                _ContainerHeader.Elements[i].ContainerView:StartRefresh()
            end

            i = i + 1
        end

        Debug("[Container]Auto wakeup finished")
    end)

    _BankHeader:ApplyConfig(_SVDB.BankViewConfigs)

    _BankHeader.Elements[1].ContainerView:Show()
    _BankHeader.Elements[1]:SetAttribute("viewactive", true)
    _BankHeader.Elements[1].ContainerView.LoadInstant = true
    _BankHeader.Elements[1].ContainerView:StartRefresh()

    tinsert(UISpecialFrames, "BagViewContainerHeader")
    tinsert(UISpecialFrames, "BagViewBankHeader")

    function _BankHeader:OnHide()
        if not InCombatLockdown() then
            CloseBankFrame()
        end
    end
end

__SystemEvent__()
function PLAYER_REGEN_DISABLED()
    viewRuleManager:Hide()
end

__SecureHook__()
function OpenAllBags()
    if not InCombatLockdown() then
        CloseBackpack()
        for i=1, NUM_BAG_FRAMES, 1 do
            CloseBag(i)
        end
        _ContainerHeader:Show()
    end
end

__SecureHook__()
function CloseAllBags()
    if not InCombatLockdown() then
        _ContainerHeader:Hide()
        _BankHeader:Hide()
    end
end

__SystemEvent__()
function BANKFRAME_OPENED(self)
    _BankHeader:Show()
end

__SystemEvent__()
function BANKFRAME_CLOSED(self)
    _BankHeader:Hide()
end

local _MERCHANT_SHOW = false

__SystemEvent__()
function MERCHANT_SHOW(self)
    _MERCHANT_SHOW = true

    if _SVDB.Char.AutoRepair then DoAutoRepair() end
    if _SVDB.Char.AutoSell   then DoAutoSell() end
end

__SystemEvent__()
function MERCHANT_CLOSED(self)
    _MERCHANT_SHOW = false
end

-----------------------------------------------------------
-- Addon Slash Commands
-----------------------------------------------------------
__SlashCmd__ ("bagview", "log", "lvl - " .. _Locale["set the log level of the bag view"])
function ToggleLogLevel(info)
    info                        = info and tonumber(info)

    if info and Logger.LogLevel(info) then
        Info(_Locale["BagView's log level is turn to %s"], Logger.LogLevel(info))
        logger.LogLevel         = info
        _SVDB.LogLevel          = info
    end
end

-----------------------------------------------------------
-- Helper
-----------------------------------------------------------
function showMenu(header)
    local repList               = XList(8):Map(function(i) return { checkvalue = i, text = _G["FACTION_STANDING_LABEL"..i] } end):ToTable()
    repList.check               = {
        get                     = function() return _SVDB.Char.AutoRepairCheckRep end,
        set                     = function(val) _SVDB.Char.AutoRepairCheckRep = val or 1 end,
    }

    ShowDropDownMenu            {
        {
            text                = _Locale["Open View Rule Manager"],
            click               = function() ShowRuleForHeader(header) end,
        },
        {
            text                = _Locale["Auto Sell"],
            check               = {
                get             = function() return _SVDB.Char.AutoSell end,
                set             = function(val) _SVDB.Char.AutoSell = val or false end,
            },
        },
        {
            text                = _Locale["Auto Repair"],
            submenu             = {
                {
                    text        = _Locale["Enable"],
                    check       = {
                        get     = function() return _SVDB.Char.AutoRepair end,
                        set     = function(val) _SVDB.Char.AutoRepair = val or false end,
                    },
                },
                {
                    text        = _Locale["Check Reputation"],
                    submenu     = repList,
                },
            },
        },
    }
end

-----------------------------------------------------------
-- Item Conditions
-----------------------------------------------------------
do
    _ItemConditions             = {
        {
            ID                  = 100000,
            Name                = _Locale["InItemList"],
            Desc                = _Locale[100000],
            Condition           = "(itemID and itemList[itemID])",
        },
        {
            ID                  = 100001,
            Name                = _Locale["Any"],
            Desc                = _Locale[100001],
            Condition           = "true",
        },
        {
            ID                  = 100002,
            Name                = _Locale["Backpack"],
            Desc                = _Locale[100002],
            BagOnly             = true,
            Condition           = "(bag == 0)",
            RequireBag          = { 0 },
            DenyBag             = { 1, 2, 3, 4 },
        },
        {
            ID                  = 100003,
            Name                = _Locale["Container1"],
            Desc                = _Locale[100003],
            BagOnly             = true,
            Condition           = "(bag == 1)",
            RequireBag          = { 1 },
            DenyBag             = { 0, 2, 3, 4 },
        },
        {
            ID                  = 100004,
            Name                = _Locale["Container2"],
            Desc                = _Locale[100004],
            BagOnly             = true,
            Condition           = "(bag == 2)",
            RequireBag          = { 2 },
            DenyBag             = { 0, 1, 3, 4 },
        },
        {
            ID                  = 100005,
            Name                = _Locale["Container3"],
            Desc                = _Locale[100005],
            BagOnly             = true,
            Condition           = "(bag == 3)",
            RequireBag          = { 3 },
            DenyBag             = { 0, 1, 2, 4 },
        },
        {
            ID                  = 100006,
            Name                = _Locale["Container4"],
            Desc                = _Locale[100006],
            BagOnly             = true,
            Condition           = "(bag == 4)",
            RequireBag          = { 4 },
            DenyBag             = { 0, 1, 2, 3 },
        },
        {
            ID                  = 110001,
            Name                = _Locale["Bank"],
            Desc                = _Locale[110001],
            BankOnly            = true,
            Condition           = ("(bag == %d)"):format(_G.BANK_CONTAINER),
            RequireBag          = { _G.BANK_CONTAINER },
            DenyBag             = { _G.REAGENTBANK_CONTAINER, 5, 6, 7, 8, 9, 10, 11 },
        },
        {
            ID                  = 110002,
            Name                = _Locale["ReagentBank"],
            Desc                = _Locale[110002],
            BankOnly            = true,
            Condition           = ("(bag == %d)"):format(_G.REAGENTBANK_CONTAINER),
            RequireBag          = { _G.REAGENTBANK_CONTAINER },
            DenyBag             = { _G.BANK_CONTAINER, 5, 6, 7, 8, 9, 10, 11 },
        },
        {
            ID                  = 110003,
            Name                = _Locale["BankBag1"],
            Desc                = _Locale[110003],
            BankOnly            = true,
            Condition           = "(bag == 5)",
            RequireBag          = { 5 },
            DenyBag             = { _G.BANK_CONTAINER, _G.REAGENTBANK_CONTAINER, 6, 7, 8, 9, 10, 11 },
        },
        {
            ID                  = 110004,
            Name                = _Locale["BankBag2"],
            Desc                = _Locale[110004],
            BankOnly            = true,
            Condition           = "(bag == 6)",
            RequireBag          = { 6 },
            DenyBag             = { _G.BANK_CONTAINER, _G.REAGENTBANK_CONTAINER, 5, 7, 8, 9, 10, 11 },
        },
        {
            ID                  = 110005,
            Name                = _Locale["BankBag3"],
            Desc                = _Locale[110005],
            BankOnly            = true,
            Condition           = "(bag == 7)",
            RequireBag          = { 7 },
            DenyBag             = { _G.BANK_CONTAINER, _G.REAGENTBANK_CONTAINER, 5, 6, 8, 9, 10, 11 },
        },
        {
            ID                  = 110006,
            Name                = _Locale["BankBag4"],
            Desc                = _Locale[110006],
            BankOnly            = true,
            Condition           = "(bag == 8)",
            RequireBag          = { 8 },
            DenyBag             = { _G.BANK_CONTAINER, _G.REAGENTBANK_CONTAINER, 5, 6, 7, 9, 10, 11 },
        },
        {
            ID                  = 110007,
            Name                = _Locale["BankBag5"],
            Desc                = _Locale[110007],
            BankOnly            = true,
            Condition           = "(bag == 9)",
            RequireBag          = { 9 },
            DenyBag             = { _G.BANK_CONTAINER, _G.REAGENTBANK_CONTAINER, 5, 6, 7, 8, 10, 11 },
        },
        {
            ID                  = 110008,
            Name                = _Locale["BankBag6"],
            Desc                = _Locale[110008],
            BankOnly            = true,
            Condition           = "(bag == 10)",
            RequireBag          = { 10 },
            DenyBag             = { _G.BANK_CONTAINER, _G.REAGENTBANK_CONTAINER, 5, 6, 7, 8, 9, 11 },
        },
        {
            ID                  = 110009,
            Name                = _Locale["BankBag7"],
            Desc                = _Locale[110009],
            BankOnly            = true,
            Condition           = "(bag == 11)",
            RequireBag          = { 11 },
            DenyBag             = { _G.BANK_CONTAINER, _G.REAGENTBANK_CONTAINER, 5, 6, 7, 8, 9, 10 },
        },
        {
            ID                  = 100007,
            Name                = _Locale["HasItem"],
            Desc                = _Locale[100007],
            Condition           = "itemID",
        },
        {
            ID                  = 100008,
            Name                = _Locale["Readable"],
            Desc                = _Locale[100008],
            Condition           = "readable",
        },
        {
            ID                  = 100009,
            Name                = _Locale["Lootable"],
            Desc                = _Locale[100009],
            Condition           = "lootable",
        },
        {
            ID                  = 100010,
            Name                = _Locale["HasNoValue"],
            Desc                = _Locale[100010],
            Condition           = "hasNoValue",
        },
        {
            ID                  = 100011,
            Name                = _Locale["IsQuestItem"],
            Desc                = _Locale[100011],
            Condition           = "(questId or isQuest)",
        },
        {
            ID                  = 100012,
            Name                = _Locale["IsEquipItem"],
            Desc                = _Locale[100012],
            Condition           = "(equipSlot and equipSlot~='' and equipSlot~='INVTYPE_BAG')",
        },
        {
            ID                  = 100013,
            Name                = _Locale["IsStackableItem"],
            Desc                = _Locale[100013],
            Condition           = "(maxStack and maxStack > 1)",
        },
        {
            ID                  = 100014,
            Name                = _Locale["IsUsableItem"],
            Desc                = _Locale[100014],
            Condition           = "itemSpell",
        },
        {
            ID                  = 100015,
            Name                = _Locale["IsNewItem"],
            Desc                = _Locale[100015],
            BagOnly             = true,
            Condition           = "isNewItem",
        },
        {
            ID                  = 100016,
            Name                = _Locale["IsEquipSet"],
            Desc                = _Locale[100016],
            BagOnly             = true,
            Condition           = "GetContainerItemEquipmentSetInfo(bag, slot)",
            RequireEvent        = { "EQUIPMENT_SETS_CHANGED" },
        },
        --[[{
            ID                  = 100017,
            Name                = _G.TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN,
            Desc                = _Locale[100017],
            Condition           = "(equipSlot and equipSlot~='' and equipSlot~='INVTYPE_BAG')",
            TooltipFilter       = _G.TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN,
        },
        {
            ID                  = 100018,
            Name                = _G.ITEM_BIND_ON_EQUIP,
            Desc                = _Locale[100018],
            Condition           = "(equipSlot and equipSlot~='' and equipSlot~='INVTYPE_BAG')",
            TooltipFilter       = _G.ITEM_BIND_ON_EQUIP,
        },
        {
            ID                  = 100019,
            Name                = _G.ARTIFACT_POWER,
            Desc                = _Locale[100019],
            Condition           = ("(cls == %q and subclass == %q)"):format(GetItemClassInfo(_G.LE_ITEM_CLASS_CONSUMABLE), GetItemSubClassInfo(_G.LE_ITEM_CLASS_CONSUMABLE, tremove({GetAuctionItemSubClasses(_G.LE_ITEM_CLASS_CONSUMABLE)}))),
            TooltipFilter       = _G.ARTIFACT_POWER,
        },--]]
        {
            ID                  = 200001,
            Name                = _G["RARITY"] .. "-" .. _G["ITEM_QUALITY0_DESC"],
            Desc                = _Locale[200001],
            Condition           = "(quality == " .. (_G.LE_ITEM_QUALITY_POOR or _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Poor) .. ")",
        },
        {
            ID                  = 200002,
            Name                = _G["RARITY"] .. "-" .. _G["ITEM_QUALITY1_DESC"],
            Desc                = _Locale[200002],
            Condition           = "(quality == " .. (_G.LE_ITEM_QUALITY_COMMON or _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Common) .. ")",
        },
        {
            ID                  = 200003,
            Name                = _G["RARITY"] .. "-" .. _G["ITEM_QUALITY2_DESC"],
            Desc                = _Locale[200003],
            Condition           = "(quality == " .. (_G.LE_ITEM_QUALITY_UNCOMMON or _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Uncommon) .. ")",
        },
        {
            ID                  = 200004,
            Name                = _G["RARITY"] .. "-" .. _G["ITEM_QUALITY3_DESC"],
            Desc                = _Locale[200004],
            Condition           = "(quality == " .. (_G.LE_ITEM_QUALITY_RARE or _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Rare) .. ")",
        },
        {
            ID                  = 200005,
            Name                = _G["RARITY"] .. "-" .. _G["ITEM_QUALITY4_DESC"],
            Desc                = _Locale[200005],
            Condition           = "(quality == " .. (_G.LE_ITEM_QUALITY_EPIC or _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Epic) .. ")",
        },
        {
            ID                  = 200006,
            Name                = _G["RARITY"] .. "-" .. _G["ITEM_QUALITY5_DESC"],
            Desc                = _Locale[200006],
            Condition           = "(quality == " .. (_G.LE_ITEM_QUALITY_LEGENDARY or _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Legendary) .. ")",
        },
        {
            ID                  = 200007,
            Name                = _G["RARITY"] .. "-" .. _G["ITEM_QUALITY6_DESC"],
            Desc                = _Locale[200007],
            Condition           = "(quality == " .. (_G.LE_ITEM_QUALITY_ARTIFACT or _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Artifact) .. ")",
        },
        {
            ID                  = 200008,
            Name                = _G["RARITY"] .. "-" .. _G["ITEM_QUALITY7_DESC"],
            Desc                = _Locale[200008],
            Condition           = "(quality == " .. (_G.LE_ITEM_QUALITY_HEIRLOOM or _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Heirloom) .. ")",
        },
        {
            ID                  = 200009,
            Name                = _G["RARITY"] .. "-" .. _G["ITEM_QUALITY8_DESC"],
            Desc                = _Locale[200009],
            Condition           = "(quality == " .. (_G.LE_ITEM_QUALITY_WOW_TOKEN or _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.WoWToken) .. ")",
        },
    }

    local i                     = 0
    local itemCls               = GetItemClassInfo(i)
    local _ID

    while itemCls and #itemCls > 0 do
        _ID                     = 300000 + i * 1000
        tinsert(_ItemConditions,    {
            ID                  = _ID,
            Name                = itemCls,
            Desc                = _Locale[300000] .. itemCls,
            Condition           = ("(cls == %q)"):format(itemCls),
        })

        local j                 = 0
        local itemSubCls        = GetItemSubClassInfo(i, j)

        while itemSubCls and #itemSubCls > 0 do
            _ID                 = _ID + 1
            tinsert(_ItemConditions, {
                ID              = _ID,
                Name            = itemCls .. "-" .. itemSubCls,
                Desc            = _Locale[300001] .. itemSubCls,
                Condition = ("(cls == %q and subclass == %q)"):format(itemCls, itemSubCls),
            })

            j                   = j + 1
            itemSubCls          = GetItemSubClassInfo(i, j)
        end

        i                       = i + 1
        itemCls                 = GetItemClassInfo(i)
    end

    for i, v in ipairs(_ItemConditions) do
        _ItemConditions[v.ID]   = v
    end
end

-----------------------------------------------------------
-- View Rule Manager
-----------------------------------------------------------
viewRuleManager                 = Dialog("BagViewRuleManager")
viewRuleManager:Hide()

ruleViewerDlg                   = Dialog("RuleViewDialog", viewRuleManager)
ruleViewerDlg:Hide()

viewer                          = HtmlViewer("Viewer", viewRuleManager)
ruleViewer                      = HtmlViewer("Viewer",ruleViewerDlg)
confirmButton                   = UIPanelButton("Confirm", viewRuleManager)
applyButton                     = UIPanelButton("Apply", viewRuleManager)
cancelButton                    = UIPanelButton("Cancel", viewRuleManager)

viewer:RegisterForDrag("LeftButton")

Style[viewRuleManager]          = {
    Header                      = {
        text                    = _Locale["Bag View Rule Manager"]
    },

    size                        = Size(400, 400),
    clampedToScreen             = true,
    minResize                   = Size(300, 300),

    Confirm                     = {
        location                = { Anchor("BOTTOMLEFT", 24, 16 ) },
        text                    = _G.OKAY or "Okay",
    },
    Apply                       = {
        location                = { Anchor("LEFT", 8, 0, "Confirm", "RIGHT") },
        text                    = _G.APPLY or "Apply",
    },
    Cancel                      = {
        location                = { Anchor("LEFT", 8, 0, "Apply", "RIGHT") },
        text                    = _G.CANCEL or "Cancel",
    },
    Viewer                      = {
        location                = { Anchor("TOPLEFT", 24, -32), Anchor("BOTTOMRIGHT", -48, 48) },
        enableMouse             = true,
    },
    RuleViewDialog              = {
        location                = { Anchor("TOPLEFT", 0, 0, nil, "TOPRIGHT"), Anchor("BOTTOMLEFT", 0, 0, nil, "BOTTOMRIGHT") },
        width                   = 400,

        Viewer                  = {
            location            = { Anchor("TOPLEFT", 24, -32), Anchor("BOTTOMRIGHT", -48, 32) },
        }
    },
}

function ShowRuleForHeader(header)
    local configs               = Toolset.clone(header == _ContainerHeader and _SVDB.ContainerConfigs or _SVDB.BankViewConfigs, true)
    viewer.Configs              = configs
    viewer.Header               = header

    viewer:SetText(TEMPLATE_VIEW {
        configs                 = configs,
        _Locale                 = _Locale,
    })

    viewer.Config               = nil
    viewer.Container            = nil
    viewer.Rules                = nil
    viewer.ItemList             = nil
    ruleViewerDlg:Hide()

    viewRuleManager:Show()

    if not ruleViewer.Generated then
        ruleViewer:SetText(TEMPLATE_CONDITION{
            _ItemConditions     = _ItemConditions,
            _Locale             = _Locale,
        })
        ruleViewer.Generated    = true
    end
end

function applyButton:OnClick()
    local configs               = Toolset.clone(viewer.Configs, true)
    if viewer.Header == _ContainerHeader then
        _SVDB.ContainerConfigs  = configs

        configs                 = Toolset.clone(configs)
        tinsert(configs, 1, DEFAULT_CONTAINER_CONFIG)

        _ContainerHeader:ApplyConfig(configs, true)
    elseif viewer.Header == _BankHeader then
        _SVDB.BankViewConfigs   = configs
        _BankHeader:ApplyConfig(configs, true)
    end
end

function confirmButton:OnClick()
    applyButton:OnClick()
    viewRuleManager:Hide()
end

function cancelButton:OnClick()
    viewRuleManager:Hide()
end

__Async__()
function viewer:OnHyperlinkClick(path)
    if path == "/" then
        viewer.Config           = nil
        viewer.Container        = nil
        viewer.Rules            = nil
        viewer.ItemList         = nil
        ruleViewerDlg:Hide()

        viewer:SetText(TEMPLATE_VIEW {
            configs             = self.Configs,
            _Locale             = _Locale,
        })
    elseif path == "aview" then
        local name              = Input(_Locale["Please input the new name"])
        if name then
            self.Configs[#self.Configs + 1] = {
                Name            = name,
                ContainerRules  = {},
            }

            viewer:SetText(TEMPLATE_VIEW {
                configs         = self.Configs,
                _Locale         = _Locale,
            })
        end
    elseif path:match("^view:") then
        path                    = tonumber(path:match("%d+"))
        if path and self.Configs[path] then
            self.Config         = self.Configs[path]
        end

        viewer.Container        = nil
        viewer.Rules            = nil
        viewer.ItemList         = nil
        ruleViewerDlg:Hide()

        viewer:SetText(TEMPLATE_CONFIG {
            config              = self.Config,
            _Locale             = _Locale,
        })
    elseif path:match("^dview:") then
        path                    = tonumber(path:match("%d+"))
        if path and self.Configs[path] then
            tremove(self.Configs, path)

            viewer:SetText(TEMPLATE_VIEW {
                configs         = self.Configs,
                _Locale         = _Locale,
            })
        end
    elseif path:match("^rview:") then
        path                    = tonumber(path:match("%d+"))
        if path and self.Configs[path] then
            local name          = Input(_Locale["Please input the replace name"])
            if not name then return end

            self.Configs[path].Name = name

            viewer:SetText(TEMPLATE_VIEW {
                configs         = self.Configs,
                _Locale         = _Locale,
            })
        end
    elseif path:match("^upview:") then
        path                    = tonumber(path:match("%d+"))
        if path and self.Configs[path] and path > 1 then
            self.Configs[path], self.Configs[path - 1] = self.Configs[path - 1], self.Configs[path]

            viewer:SetText(TEMPLATE_VIEW {
                configs         = self.Configs,
                _Locale         = _Locale,
            })
        end
    elseif path:match("^downview:") then
        path                    = tonumber(path:match("%d+"))
        if path and self.Configs[path] and path < #self.Configs then
            self.Configs[path], self.Configs[path + 1] = self.Configs[path + 1], self.Configs[path]

            viewer:SetText(TEMPLATE_VIEW {
                configs         = self.Configs,
                _Locale         = _Locale,
            })
        end
    elseif path == "acon" then
        local name              = Input(_Locale["Please input the new name"])

        self.Config.ContainerRules = self.Config.ContainerRules or {}
        self.Config.ContainerRules[#self.Config.ContainerRules + 1] = { Name = name }

        viewer:SetText(TEMPLATE_CONFIG {
            config              = self.Config,
            _Locale             = _Locale,
        })
    elseif path:match("^con:") then
        path                    = tonumber(path:match("%d+"))
        if path and self.Config.ContainerRules[path] then
            self.Container      = self.Config.ContainerRules[path]
        end

        viewer.Rules            = nil
        viewer.ItemList         = nil
        ruleViewerDlg:Hide()

        viewer:SetText(TEMPLATE_CONTAINER {
            config              = self.Config,
            container           = self.Container,
            _Locale             = _Locale,
            _ItemConditions     = _ItemConditions,
        })
    elseif path:match("^dcon:") then
        path                    = tonumber(path:match("%d+"))
        if path and self.Config.ContainerRules[path] then
            tremove(self.Config.ContainerRules, path)

            viewer:SetText(TEMPLATE_CONFIG {
                config          = self.Config,
                _Locale         = _Locale,
            })
        end
    elseif path:match("^rcon:") then
        path                    = tonumber(path:match("%d+"))
        if path and self.Config.ContainerRules[path] then
            local name          = Input(_Locale["Please input the replace name"])
            if not name then return end

            self.Config.ContainerRules[path].Name = name

            viewer:SetText(TEMPLATE_CONFIG {
                config          = self.Config,
                _Locale         = _Locale,
            })
        end
    elseif path:match("^upcon:") then
        path                    = tonumber(path:match("%d+"))
        if path and self.Config.ContainerRules[path] and path > 1 then
            self.Config.ContainerRules[path], self.Config.ContainerRules[path - 1] = self.Config.ContainerRules[path - 1], self.Config.ContainerRules[path]

            viewer:SetText(TEMPLATE_CONFIG {
                config          = self.Config,
                _Locale         = _Locale,
            })
        end
    elseif path:match("^downcon:") then
        path                    = tonumber(path:match("%d+"))
        if path and self.Config.ContainerRules[path] and path < #self.Config.ContainerRules then
            self.Config.ContainerRules[path], self.Config.ContainerRules[path + 1] = self.Config.ContainerRules[path + 1], self.Config.ContainerRules[path]

            viewer:SetText(TEMPLATE_CONFIG {
                config          = self.Config,
                _Locale         = _Locale,
            })
        end
    elseif path == "arules" then
        self.Container[#self.Container + 1] = {}

        viewer:SetText(TEMPLATE_CONTAINER {
            config              = self.Config,
            container           = self.Container,
            _Locale             = _Locale,
            _ItemConditions     = _ItemConditions,
        })
    elseif path:match("^rules:") then
        path                    = tonumber(path:match("%d+"))
        if path and self.Container[path] then
            self.Rules          = self.Container[path]
            self.Config.ItemList= self.Config.ItemList or {}
            self.ItemList       = self.Config.ItemList
            ruleViewerDlg:Hide()

            viewer:SetText(TEMPLATE_RULES {
                config          = self.Config,
                container       = self.Container,
                rules           = self.Rules,
                itemList        = self.ItemList,
                _Locale         = _Locale,
                _ItemConditions = _ItemConditions,
            })
        end
    elseif path:match("^drules:") then
        path                    = tonumber(path:match("%d+"))
        if path and self.Container[path] then
            tremove(self.Container, path)

            viewer:SetText(TEMPLATE_CONTAINER {
                config          = self.Config,
                container       = self.Container,
                _Locale         = _Locale,
                _ItemConditions = _ItemConditions,
            })
        end
    elseif path == "arule" then
        ruleViewerDlg:Show()
    elseif path:match("^drule:") then
        path                    = tonumber(path:match("%d+"))
        if path and self.Rules[path] then
            tremove(self.Rules, path)

            viewer:SetText(TEMPLATE_RULES {
                config          = self.Config,
                container       = self.Container,
                rules           = self.Rules,
                itemList        = self.ItemList,
                _Locale         = _Locale,
                _ItemConditions = _ItemConditions,
            })
        end
    elseif path:match("^item:") then
        GameTooltip:Hide()

        path                    = tonumber(path:match("%d+"))
        if path and self.ItemList then
            self.ItemList[path] = nil

            viewer:SetText(TEMPLATE_RULES {
                config          = self.Config,
                container       = self.Container,
                rules           = self.Rules,
                itemList        = self.ItemList,
                _Locale         = _Locale,
                _ItemConditions = _ItemConditions,
            })
        end
    elseif path == "filter" then
        self.Rules.TooltipFilter= Input(_Locale["Tooltip Filter(Use ';' to seperate)"])

        viewer:SetText(TEMPLATE_RULES {
            config              = self.Config,
            container           = self.Container,
            rules               = self.Rules,
            itemList            = self.ItemList,
            _Locale             = _Locale,
            _ItemConditions     = _ItemConditions,
        })
    end
end

function viewer:OnReceiveDrag()
    local type, index, subType, data = GetCursorInfo()
    ClearCursor()

    if type == "item" and tonumber(index) then
        index                   = tonumber(index)

        if self.ItemList then
            self.ItemList[index]= true

            viewer:SetText(TEMPLATE_RULES {
                config          = self.Config,
                container       = self.Container,
                rules           = self.Rules,
                itemList        = self.ItemList,
                _Locale         = _Locale,
                _ItemConditions = _ItemConditions,
            })
        end
    end
end

function viewer:OnHyperlinkEnter(path)
    if path:match("^item:") then
        path                    = tonumber(path:match("%d+"))
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(select(2, GetItemInfo(path)))
        GameTooltip:Show()
    end
end

function viewer:OnHyperlinkLeave()
    GameTooltip:Hide()
end

function ruleViewer:OnHyperlinkClick(path)
    ruleViewerDlg:Hide()

    path                        = tonumber(path)

    if path and viewer.Rules then
        local a                 = math.abs(path)

        for i, v in ipairs(viewer.Rules) do
            if math.abs(v) == a then
                if v == path then
                    return
                else
                    viewer.Rules[i] = path
                    path        = nil
                end
            end
        end

        if path then
            viewer.Rules[#viewer.Rules + 1] = path
        end

        viewer:SetText(TEMPLATE_RULES {
            config              = viewer.Config,
            container           = viewer.Container,
            rules               = viewer.Rules,
            itemList            = viewer.ItemList,
            _Locale             = _Locale,
            _ItemConditions     = _ItemConditions,
        })
    end
end

TEMPLATE_VIEW                   = TemplateString[[
    <html>
        <body>
            <h1><cyan>@\_Locale["Views"]</cyan></h1>
            <br/>
            @for i, config in ipairs(configs) do
                <p>
                    <a href="view:@i">@\config.Name</a>
                    [<a href="rview:@i"><red>@\_Locale["Rename"]</red></a>]
                    [<a href="dview:@i"><red>@\_Locale["Delete"]</red></a>]
                    @if i > 1 then
                    [<a href="upview:@i"><cyan>@\_Locale["Up"]</cyan></a>]
                    @end
                    @if i < #configs then
                    [<a href="downview:@i"><cyan>@\_Locale["Down"]</cyan></a>]
                    @end
                </p>
            <br/>
            @end
            <p>[<a href="aview"><lightblue>@\_Locale["Add View"]</lightblue></a>]</p>
        </body>
    </html>
]]

TEMPLATE_CONFIG                 = TemplateString[[
    <html>
        <body>
            <h1><a href="/">/</a>@\config.Name</h1>
            <br/>
            <h1><cyan>@\_Locale["Containers"]</cyan></h1>
            <br/>
            @for i, con in ipairs(config.ContainerRules) do
                <p>
                    <a href="con:@i">@\(con.Name or (_Locale["Container"] .. " " .. i))</a>
                    [<a href="rcon:@i"><red>@\_Locale["Rename"]</red></a>]
                    [<a href="dcon:@i"><red>@\_Locale["Delete"]</red></a>]
                    @if i > 1 then
                    [<a href="upcon:@i"><cyan>@\_Locale["Up"]</cyan></a>]
                    @end
                    @if i < #config.ContainerRules then
                    [<a href="downcon:@i"><cyan>@\_Locale["Down"]</cyan></a>]
                    @end
                </p>
            <br/>
            @end
            <p>[<a href="acon"><lightblue>@\_Locale["Add Container"]</lightblue></a>]</p>
        </body>
    </html>
]]

TEMPLATE_CONTAINER              = TemplateString[[
    <html>
        <body>
            <h1>
                <a href="/">/</a>
                <a href="view:">@\config.Name</a>
                / @\(container.Name or _Locale["Containers"])
            </h1>
            <br/>
            <h1><cyan>@\_Locale["Rules"]</cyan></h1>
            <br/>
            @for i, rules in ipairs(container) do
                <p>
                    @{
                        local name
                        for i, id in ipairs(rules) do
                            local r = _ItemConditions[id]
                            if r then
                                if name then
                                    name = name .. _Locale[" And "] .. r.Name
                                else
                                    name = r.Name
                                end
                            else
                                r = _ItemConditions[-id]
                                if r then
                                    if name then
                                        name = name .. _Locale[" And "] .. "[" .. _Locale["NOT"] .. "]" .. r.Name
                                    else
                                        name = "[" .. _Locale["NOT"] .. "]" .. r.Name
                                    end
                                end
                            end
                        end
                    }
                    <a href="rules:@i">@\(name or (_Locale["Rules"] .. " " .. i))</a>
                    [<a href="drules:@i"><red>@\_Locale["Delete"]</red></a>]
                </p>
            <br/>
            @end
            <p>[<a href="arules"><lightblue>@\_Locale["Add Rules"]</lightblue></a>]</p>
        </body>
    </html>
]]

TEMPLATE_RULES                  = TemplateString[[
    <html>
        <body>
            <h1>
                <a href="/">/</a>
                <a href="view:">@\config.Name</a> /
                <a href="con:">@\(container.Name or _Locale["Containers"])</a>
                / @\_Locale["Rules"]
            </h1>
            <br/>
            <h2><cyan>@\_Locale["Tooltip Filter(Use ';' to seperate)"]</cyan></h2>
            <br/>
            <p><a href="filter">@\(rules.TooltipFilter or _Locale["Click to set"])</a></p>
            <br/>
            <br/>
            <h2><cyan>@\_Locale["Rule List"]</cyan></h2>
            <p>
                @for i, rule in ipairs(rules) do
                    @{
                        local r = _ItemConditions[rule]
                        local n = not r
                        if n then r = _ItemConditions[-rule] end
                    }
                    <a href="drule:@i">
                        @if n then
                        [@\(_Locale["NOT"])]
                        @end
                        @\r.Name
                    </a>
                    @if i < #rules then
                    @\_Locale[" And "]
                    @end
                @end
            </p>
            <br/>
            <p><a href="arule"><lightblue>[@\(_Locale["Add Rule"])]</lightblue></a></p>
            <br/>
            <br/>
            <h2><cyan>@\_Locale["Item List - drag item here to add"]</cyan></h2>
            <br/>
            <p>
                @for item in pairs(itemList) do
                    @{
                        local name, _, quality = GetItemInfo(item)
                        if not name then name, quality = item, 1 end
                    }
                    <a href="item:@item">
                        @if quality == 1 then
                        <common>[@\(name)]</common>
                        @elseif quality == 2 then
                        <uncommon>[@\(name)]</uncommon>
                        @elseif quality == 3 then
                        <rare>[@\(name)]</rare>
                        @elseif quality == 4 then
                        <epic>[@\(name)]</epic>
                        @elseif quality == 5 then
                        <legendary>[@\(name)]</legendary>
                        @elseif quality == 6 then
                        <artifact>[@\(name)]</artifact>
                        @elseif quality == 7 then
                        <heirloom>[@\(name)]</heirloom>
                        @elseif quality == 8 then
                        <wowtoken>[@\(name)]</wowtoken>
                        @end
                    </a>
                @end
            </p>
        </body>
    </html>
]]

TEMPLATE_CONDITION              = TemplateString[[
    <html>
        <body>
            @for _, cond in ipairs(_ItemConditions) do
            <p>
                <a href="-@cond.ID">[@\(_Locale["NOT"])]</a>
                <a href="@cond.ID">[@\cond.Name]</a> - @\cond.Desc
            </p>
            <br/>
            @end
        </body>
    </html>
]]

-------------------------------
-- Auto Repair
-------------------------------
function DoAutoRepair(self)
    if not CanMerchantRepair() then return end

    if (UnitReaction("target", "player") or 4) < _SVDB.Char.AutoRepairCheckRep then return end

    local repairByGuild         = false

    local allcost, canRepair    = GetRepairAllCost()
    if allcost == 0 or not canRepair then return end

    --See if can guildbank repair
    if false and CanGuildBankRepair() then
        local guildName, _, guildRankIndex = GetGuildInfo("player")

        GuildControlSetRank(guildRankIndex)

        if GetGuildBankWithdrawGoldLimit()*10000 >= allcost then
            repairByGuild = true
            RepairAllItems(true)
        else
            if allcost > GetMoney() then
                return Warn(_Locale["[AutoRepair] No enough money to repair."])
            end

            RepairAllItems()
        end
        PlaySound(SOUNDKIT.ITEM_REPAIR)
    else
        if allcost > GetMoney() then
            return Warn(_Locale["[AutoRepair] No enough money to repair."])
        end

        RepairAllItems()
        PlaySound(SOUNDKIT.ITEM_REPAIR)
    end

    Debug("-----------------------------")
    if repairByGuild then
        Debug(_Locale["[AutoRepair] Cost [Guild] %s."], FormatMoney(allcost))
    else
        Debug(_Locale["[AutoRepair] Cost %s."], FormatMoney(allcost))
    end
    Debug("-----------------------------")
end

-------------------------------
-- Auto Sell
-------------------------------
_SelledList                     = {}
_SelledCount                    = {}
_SelledMoney                    = {}

function DoAutoSell()
    wipe(_SelledList)
    wipe(_SelledCount)
    wipe(_SelledMoney)

    local selled                = false

    for bag = 0, NUM_BAG_FRAMES do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemId        = GetContainerItemID(bag, slot)
            if itemId then
                local _, _, itemRarity, _, _, _, _, _, _, _, money = GetItemInfo(itemId)

                if money and money > 0 and (_ToolNeedSell[itemId] or (itemRarity == 0 and not _ToolDontSell[itemId])) then
                    local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
                    UseContainerItem(bag, slot)
                    selled = true
                    Add2List(link, count, money)
                end
            end
        end
    end

    if selled then
        Debug("-----------------------------")
        Trace(_Locale["[AutoSell] Item List:"])
        local money             = 0
        for _, link in ipairs(_SelledList) do
            money               = money + _SelledMoney[link]
            icon                = select(10, GetItemInfo(link)) or ""

            if _SelledCount[link] > 1 then
                Trace("\124T%s:0\124t %s (%d) => %s.", icon, link, _SelledCount[link], FormatMoney(_SelledMoney[link]))
            else
                Trace("\124T%s:0\124t %s => %s.", icon, link, FormatMoney(_SelledMoney[link]))
            end
        end
        Debug(_Locale["[AutoSell] Total : %s."], FormatMoney(money))
        Debug(_Locale["[AutoSell] Buy back item if you don't want auto sell it."])
        Debug(_Locale["[AutoSell] Alt+Right-Click to mark item as auto sell."])
        Debug("-----------------------------")
    end
end

function Add2List(link, count, money)
    count                       = count or 1
    money                       = money * count

    if _SelledCount[link] then
        _SelledCount[link]      = _SelledCount[link] + (count or 1)
        _SelledMoney[link]      = _SelledMoney[link] + money
    else
        tinsert(_SelledList, link)
        _SelledCount[link]      = count or 1
        _SelledMoney[link]      = money
    end
end

function GetItemId(link)
    local _, link               = GetItemInfo(link)
    if link then return tonumber(link:match":(%d+):") end
end

-------------------------------
-- Auto Sell
-------------------------------
__SecureHook__()
function ContainerFrameItemButton_OnClick(self, button)
    if _MERCHANT_SHOW and _SVDB.Char.AutoSell and button == "RightButton" and IsModifiedClick("Alt") then
        local itemId            = GetContainerItemID(self:GetParent():GetID(), self:GetID())

        if itemId then
            _ToolDontSell[itemId] = nil
            _ToolNeedSell[itemId] = true
            DoAutoSell()
        end
    end
end

__SecureHook__()
function ContainerFrameItemButton_OnModifiedClick(self, button)
    if _MERCHANT_SHOW and _SVDB.Char.AutoSell and button == "RightButton" and IsModifiedClick("Alt") then
        local itemId            = GetContainerItemID(self:GetParent():GetID(), self:GetID())

        if itemId then
            _ToolDontSell[itemId] = nil
            _ToolNeedSell[itemId] = true
            DoAutoSell()
        end
    end
end

-------------------------------
-- Rollback auto sell
-------------------------------
__SecureHook__()
function BuybackItem(index)
    local link                  = GetBuybackItemLink(index)

    if link then
        local itemId            = GetItemId(link)

        if itemId then
            _ToolNeedSell[itemId] = nil
            local _, _, itemRarity = GetItemInfo(itemId)
            if itemRarity == 0 then
                _ToolDontSell[itemId] = true
            end
        end
    end
end

__SecureHook__()
function BuyMerchantItem(index, quantity)
    local link                  = GetMerchantItemLink(index)

    if link then
        local itemId            = GetItemId(link)

        if itemId then
            _ToolNeedSell[itemId] = nil
        end
    end
end

function FormatMoney(money)
    if money >= 10000 then
        return (GOLD_AMOUNT_TEXTURE.." "..SILVER_AMOUNT_TEXTURE.." "..COPPER_AMOUNT_TEXTURE):format(math.floor(money / 10000), 0, 0, math.floor(money % 10000 / 100), 0, 0, money % 100, 0, 0)
    elseif money >= 100 then
        return (SILVER_AMOUNT_TEXTURE.." "..COPPER_AMOUNT_TEXTURE):format(math.floor(money % 10000 / 100), 0, 0, money % 100, 0, 0)
    else
        return (COPPER_AMOUNT_TEXTURE):format(money % 100, 0, 0)
    end
end
