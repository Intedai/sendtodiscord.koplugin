--[[--
This plugin lets you send highlighted text to Discord using Webhooks.

@module koplugin.SendToDiscord
--]]--

-- TODOS:
-- Put discrod webhook url in settings (and maybe config file that will override settings) instead of var
-- Send data in chunks to avoid ratelimits (figure out a good way)
-- Add a switch in settings to put an embed or not
-- Add an option to have the text enclosed in ```, also add a format textbox, for example: Explain this: %TEXT%
-- Use util.trim when needed, if ``` is used dont trim, in embeds without ``` trim and remove multiple spaces
-- Utilize footer and other embed fields that I didn't use
-- If embed enabled have a color settings

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local util = require("util")
local _ = require("gettext")
local http = require("socket.http")
local ltn12 = require("ltn12")
local JSON = require("json")

local WEBHOOK_URL = "URL-HERE"

local SendToDiscord = WidgetContainer:extend{
    name = "sendtodiscord"
} 

function SendToDiscord:init()
    if self.document then
        self:addToHighlightDialog()
    end
end

function SendToDiscord:send(text)
    local data = JSON.encode({
        embeds = {
            {
                title = "sendtodiscord.koplugin", -- TODO: put in settings with: %BOOK_NAME% and %AUTHOR% %PAGE% and everything.
                color = 128, -- Lua color
                description = text
            }
        }
    })

    local result, code = http.request {
        method = "POST",
        url = WEBHOOK_URL,
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = #data
        },
        source = ltn12.source.string(data),
        sink = nil
    }
    -- TODO: Add a check: if result diff than 1 (check in docs to make sure)
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
                
                self:send(text)
                
                this:onClose(true)
            end,
        }
    end)
end

return SendToDiscord