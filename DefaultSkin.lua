--========================================================--
--                BagView Skin                            --
--                                                        --
-- Author      :  kurapica125@outlook.com                 --
-- Create Date :  2021/06/25                              --
--========================================================--

--========================================================--
Scorpio           "BagView.Skin"                     "1.0.0"
--========================================================--

BAG_ITEM_QUALITY_COLORS         = XDictionary(BAG_ITEM_QUALITY_COLORS):Map(function(k, v) return Color(v.r, v.g, v.b) end):ToTable()
BAG_ITEM_QUALITY_COLORS[0]      = Color(0.4, 0.4, 0.4)
BAG_ITEM_QUALITY_COLORS[1]      = Color(1, 1, 1)

BORDER_TEXTURE_PATH             = [[Interface\Addons\BagView\resource\border.tga]]

PUSH_COLOR                      = Color(1 - Color.PLAYER.r, 1-Color.PLAYER.g, 1-Color.PLAYER.b)

__ChildProperty__(ContainerButton, "ItemLevel")
class "ItemLevel"               { FontString }

Style.UpdateSkin("Default",     {
    [BagButton]                 = {
        alpha                   = 1,

        NormalTexture           = {
            file                = BORDER_TEXTURE_PATH,
            setAllPoints        = true,
            vertexColor         = Color.PLAYER,
        },
        PushedTexture           = {
            file                = BORDER_TEXTURE_PATH,
            setAllPoints        = true,
            vertexColor         = PUSH_COLOR,
        },
        IconTexture             = {
            location            = { Anchor("TOPLEFT", 2, -2), Anchor("BOTTOMRIGHT", -2, 2) },
            texCoords           = RectType(0.06, 0.94, 0.06, 0.94),
        },
    },
    [ContainerButton]           = {
        ItemLevel               = Scorpio.IsRetail and {
            drawLayer           = "OVERLAY",
            fontObject          = NumberFontNormal,
            justifyH            = "LEFT",
            location            = { Anchor("BOTTOMLEFT", 4, 4) },
            text                = Wow.FromUIProperty("ItemLevel"),
            vertexColor         = Wow.FromUIProperty("ItemQuality"):Map(function(v) return v and BAG_ITEM_QUALITY_COLORS[v] or Color.WHITE end),
        } or nil,

        NormalTexture           = {
            file                = BORDER_TEXTURE_PATH,
            setAllPoints        = true,
            vertexColor         = Color.PLAYER,
        },
        PushedTexture           = {
            file                = BORDER_TEXTURE_PATH,
            setAllPoints        = true,
            vertexColor         = PUSH_COLOR,
        },
        IconTexture             = {
            location            = { Anchor("TOPLEFT", 2, -2), Anchor("BOTTOMRIGHT", -2, 2) },
            texCoords           = RectType(0.06, 0.94, 0.06, 0.94),
        },

    },
    [Container]                 = {
        label                   = {
            drawLayer           = "OVERLAY",
            fontObject          = GameFontHighlight,
            location            = { Anchor("TOPLEFT") },
            text                = Wow.FromUIProperty("Name"),
        },

        rowCount                = Wow.FromUIProperty("IsBank"):Map(function(isbank) return isbank and 27 or 20 end),
        columnCount             = Wow.FromUIProperty("IsBank"):Map(function(isbank) return isbank and 14 or 12 end),

        elementWidth            = 36,
        elementHeight           = 36,
        orientation             = "HORIZONTAL",
        topToBottom             = true,
        leftToRight             = true,
        hSpacing                = 2,
        vSpacing                = 2,
        keepColumnSize          = true,
        keepRowSize             = false,
        autoSize                = true,
        autoPosition            = false,
        marginTop               = Wow.FromUIProperty("Name"):Map(function(name) return name and name ~= "" and 26 or 1 end),
        marginBottom            = 1,
        marginLeft              = 1,
        marginRight             = 1,
    },
    [ContainerView]             = {
        frameLevel              = 1,
        backdrop                = {
            bgFile              = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile            = "Interface\\Buttons\\WHITE8x8",
            tile                = true, tileSize = 16, edgeSize = 1,
        },
        backdropBorderColor     = Color.PLAYER,
        backdropColor           = Color.BLACK,
    },
    [ViewButton]                = {
        buttonText              = {
            drawLayer           = "OVERLAY",
            fontObject          = GameFontHighlight,
            setAllPoints        = true,
        },
        checkedTexture          = {
            file                = [[Interface\Buttons\WHITE8x8]],
            vertexColor         = Color(0, 0.4, 0.8),
            setAllPoints        = true,
        },
    },
    [ContainerHeader]           = {
        backdrop                = {
            bgFile              = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile            = "Interface\\Buttons\\WHITE8x8",
            tile                = true, tileSize = 16, edgeSize = 1,
        },
        backdropBorderColor     = Color.PLAYER,
        backdropColor           = Color.BLACK,
    },
})