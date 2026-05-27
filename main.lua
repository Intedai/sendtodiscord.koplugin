--[[--
This plugin lets you send highlighted text to Discord using Webhooks.

@module koplugin.SendToDiscord
--]]--

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local util = require("util")
local _ = require("gettext")

local SendToDiscord = WidgetContainer:extend{
    name = "sendtodiscord"
} 

function SendToDiscord:init()
    if self.document then
        self:addToHighlightDialog()
    end
end

function SendToDiscord:addToHighlightDialog()
    -- Naming the button 12_discord_send makes the button appear before the QR code generator button
    -- because it's called 12_generate_qr_code, and the buttons are sorted alphabetically
    self.ui.highlight:addToHighlightDialog("12_discord_send", function(this)
        return {
            text = _("Send To Discord"),
            callback = function()
                this:highlightFromHoldPos()
                if not (this.selected_text and this.selected_text.text) then
                    return end

                local text = util.cleanupSelectedText(this.selected_text.text)
                -- LOGIC HERE!! (TODO: Make a seperate func)
                this:onClose(true)
            end,
        }
    end)
end

return SendToDiscord