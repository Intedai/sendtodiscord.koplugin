--[[--
This plugin lets you send highlighted text to Discord using Webhooks.

@module koplugin.SendToDiscord
--]]--

-- TODOS:
-- Put discrod webhook url in settings (and maybe config file that will override settings) instead of var
-- Add a switch in settings to put an embed or not
-- Add an option to have the text enclosed in ```, also add a format textbox, for example: Explain this: %TEXT%
-- Use util.trim when needed, if ``` is used dont trim, in embeds without ``` trim and remove multiple spaces
-- Utilize footer and other embed fields that I didn't use
-- If embed enabled have a color settings

local Device = require("device")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local util = require("util")
local _ = require("gettext")
local http = require("socket.http")
local ltn12 = require("ltn12")
local logger = require("logger")
local JSON = require("json")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")

local WEBHOOK_URL = "URL-HERE"

local SendToDiscord = WidgetContainer:extend{
    name = "sendtodiscord"
} 

function SendToDiscord:init()
    if self.document then
        self:addToHighlightDialog()
    end
    if Device:hasClipboard() then
        self.ui.menu:registerToMainMenu(self)
    end
end

function SendToDiscord:warn(text)
    logger.warn(text)

    UIManager:show(InfoMessage:new{
        icon = "notice-warning",
        text = text
    })
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

    local response = {}
    local result, code, _headers, status = http.request {
        method = "POST",
        url = WEBHOOK_URL,
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = #data
        },
        source = ltn12.source.string(data),
        sink = ltn12.sink.table(response)
    }
    if result ~= 1 then
        self:warn(_("Failed to send request:") .. " " .. _(code)) -- Code is in english if result ~= 1, perhaps just show in english instead of adding translations
    elseif code == 204 or code == 200 then
        -- TODO: If text is more than 4096 characters loop until u send all of it
        logger.info(_("Sent highlighted text to Discord successfuly,"))
    elseif code == 429 then
        --TODO: Implement resend in time sent in response
        local response = table.concat(response)
        print(response)
        logger.warn("You are being rate limited, trying again in X seconds") -- TODO: add timeout to warn function when implementing this, timeout is optional
    else
        self:warn(_("Failed,") .. " " .. _("HTTP status code:") .. " " .. code)
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
                
                self:send(text)
                
                this:onClose(true)
            end,
        }
    end)
end

function SendToDiscord:addToMainMenu(menu_items)
    menu_items.sendtodiscord = {
        text = _("Send clipboard to Discord"),
        callback = function()
            self:send(Device.input.getClipboardText())
        end,
    }
end

return SendToDiscord