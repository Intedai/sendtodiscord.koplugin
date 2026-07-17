--[[--
This plugin lets you send highlighted text to Discord using Webhooks.

@module koplugin.SendToDiscord
--]]--

-- TODOS:
-- Add prefix and suffix in options
-- Add color option
-- Use util.trim when needed, if ``` is used dont trim, in embeds without ``` trim and remove multiple spaces

local Device = require("device")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local util = require("util")
local PluginUtil = require("pluginutil")
local _ = require("gettext")
local http = require("socket.http")
local ltn12 = require("ltn12")
local logger = require("logger")
local JSON = require("json")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local DataStorage = require("datastorage")
local ffiUtil = require("ffi/util")
local InputDialog = require("ui/widget/inputdialog")

local T = ffiUtil.template

local SendToDiscord = WidgetContainer:extend{
    name = "sendtodiscord",
    settings = nil,
    settings_file = "sendtodiscord_settings.lua"
} 

function SendToDiscord:init()
    if self.document then
        self:addToHighlightDialog()
    end
    self.ui.menu:registerToMainMenu(self)

    self.settings = LuaSettings:open(("%s/%s"):format(DataStorage:getSettingsDir(), self.settings_file))
    self.settings:readSetting("webhook_url", "")
end

function SendToDiscord:warn(text)
    logger.warn(text)

    UIManager:show(InfoMessage:new{
        icon = "notice-warning",
        text = text
    })
end

function SendToDiscord:send(authors, title, text, footer_text)
    local data = JSON.encode({
        embeds = {
            {
                author = {
                    name = authors
                },
                title = title,
                color = 128, -- Lua color
                description = text,
                footer = {
                    text = footer_text
                }
            }
        }
    })

    local response = {}
    local result, code, _headers, status = http.request {
        method = "POST",
        url = self.settings:readSetting("webhook_url"),
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = #data
        },
        source = ltn12.source.string(data),
        sink = ltn12.sink.table(response)
    }
    if result ~= 1 then
        self:warn(T(_("Failed to send request: %1"), code))
    elseif code == 204 or code == 200 then
        -- TODO: If text is more than 4096 characters loop until u send all of it
        logger.info(_("Sent highlighted text to Discord successfuly"))
    elseif code == 429 then
        --TODO: Implement resend in time sent in response
        local response = table.concat(response)
        print(response)
        logger.warn(T(_("You are being rate limited, trying again in %1 seconds"), "X")) -- TODO: add timeout to warn function when implementing this, timeout is optional
    else
        self:warn(T(_("Failed, HTTP status code: %1"), code))
    end
end

function  SendToDiscord:getPercentProgress()
    if self.ui.document.info.has_pages then
        return PluginUtil:myRoundPercent(self.ui.paging:getLastPercent())
    else
        return PluginUtil:myRoundPercent(self.ui.rolling:getLastPercent())
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
                
                local doc_metadata = self.document:getProps()
                
                local wrap_code_block = self.settings:isTrue("wrap_code_block")
                
                local text = this.selected_text.text
                if wrap_code_block then
                    text = "```" .. text .. "```"
                else
                    text = util.cleanupSelectedText(text)
                end

                local book_title = doc_metadata.title or _("Unknown Title")
                local book_author = PluginUtil:linesToSingleLine(doc_metadata.authors or _("Unknown Author"))
                
                local curr_page = self.ui:getCurrentPage()
                local total_pages = self.ui.document:getPageCount()
                
                local page_progress = nil

                if curr_page ~= nil and total_pages ~= nil then
                    page_progress = curr_page .. " / " .. total_pages
                end
                
                local percent_progress = self:getPercentProgress() .. "%"

                -- If page_progress is nill only show percent_progress
                local footer = percent_progress and page_progress .. "  •  " .. percent_progress

                self:send(book_author, book_title, text, footer)
                
                this:onClose(true)
            end,
        }
    end)
end

function SendToDiscord:addToMainMenu(menu_items)
    menu_items.sendtodiscord = {
        text = _("SendToDiscord"),
        sub_item_table = {
            {
                text = _("Send clipboard to Discord"),
                callback = function()
                    local clipboard_text = util.cleanupSelectedText(Device.input.getClipboardText())
                    if not Device:hasClipboard() then
                        self:warn(_("This device does not have a clipboard"))
                    elseif clipboard_text == nil or clipboard_text == "" then
                        self:warn(_("Clipboard is empty, did not send anything to Discord"))
                    else
                        self:send("KOReader", _("Clipboard"), clipboard_text, _("Last copied text"))
                    end
                end,
            },
            {
                text = _("Settings"),
                sub_item_table = {
                    {
                        text_func =  function()
                            return T(_("Webhook URL: %1"), self.settings:readSetting("webhook_url"))
                        end,
                        callback = function(touchmenu_instance)
                            self.webhook_dialog = InputDialog:new{
                                title = _("Webhook URL"),
                                description = _("Enter your webhook url:"),
                                input = self.settings:readSetting("webhook_url"),
                                buttons = {{
                                    {
                                        text = _("Cancel"),
                                        callback = function()
                                            UIManager:close(self.webhook_dialog)
                                        end
                                    },
                                    {
                                        text = _("Save"),
                                        callback = function()
                                            local new_webhook = self.webhook_dialog:getInputText()
                                            self.settings:saveSetting("webhook_url", new_webhook)
                                            self.settings:flush()
                                            UIManager:close(self.webhook_dialog)
                                            if touchmenu_instance then
                                                touchmenu_instance:updateItems()
                                            end
                                        end
                                    }
                                }}
                            }

                            UIManager:show(self.webhook_dialog)
                            self.webhook_dialog:onShowKeyboard()

                        end
                    },
                    {
                        text = _("Wrap text in code block (whitespaces stay the exact same)"),
                        checked_func = function()
                            return self.settings:isTrue("wrap_code_block")
                        end,
                        callback = function()
                            self.settings:toggle("wrap_code_block")
                            self.settings:flush()
                        end
                    },

                }
            }
        }
    }
end

return SendToDiscord