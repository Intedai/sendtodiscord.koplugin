--[[--
This plugin lets you send highlighted text and text from your clipboard to Discord in beautiful embeds using webhooks.

@module koplugin.SendToDiscord
--]]--

local Device = require("device")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local util = require("util")
local PluginUtil = require("pluginutil")
local _ = require("gettext")
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
    self.settings:readSetting("prefix_text", "")
    self.settings:readSetting("suffix_text", "")

    self.settings:readSetting("space_encoding", " ")

    -- Embed's RGB
    self.default_rgb = {0, 0, 128} -- Lua's color
    self.settings:readSetting("red", self.default_rgb[1])
    self.settings:readSetting("green", self.default_rgb[2])
    self.settings:readSetting("blue", self.default_rgb[3])
end

function SendToDiscord:warn(text)
    logger.warn(text)

    local warning_msg = InfoMessage:new{
        icon = "notice-warning",
        text = text,
    }

    UIManager:show(warning_msg)

    return warning_msg
end

function SendToDiscord:send(authors, title, text, percent_progress, page_progress)
    local max_total_chars = 6000
    local max_text_chars = 4096
    local max_footer_text_chars = 2048
    local max_author_and_title_chars = 256

    local text_len = PluginUtil:utf8Len(text)

    if text_len > 4096 then
        self:warn(T(_("Text's length must be less than or equal to %1"), max_chars))
        return
    end
    
    -- If page_progress is nil only show percent_progress
    local footer_text = percent_progress and page_progress .. "  •  " .. percent_progress
    local footer_len = PluginUtil:utf8Len(footer_text)

    local authors_len, title_len

    authors, authors_len = PluginUtil:truncateString(authors, max_author_and_title_chars)
    title, title_len = PluginUtil:truncateString(title, max_author_and_title_chars)

    local remaining_for_footer = max_total_chars - text_len - authors_len - title_len

    -- Works because percent_progress is max 4 chars (100%) and the sum of 4 and all max chars is less than 6000 
    if page_progress ~= nil and (footer_len > 2048 or footer_len > remaining_for_footer) then
        footer_text = percent_progress
    end

    local http = require("socket.http")
    local ltn12 = require("ltn12")
    local socketutil = require("socketutil")

    local data = JSON.encode({
        embeds = {
            {
                author = {
                    name = authors
                },
                title = title,
                color = PluginUtil:rgbToInt(
                    self.settings:readSetting("red"),
                    self.settings:readSetting("green"),
                    self.settings:readSetting("blue")
                ),
                description = text,
                footer = {
                    text = footer_text
                }
            }
        }
    })

    local timeout = 10
    local maxtime = 30

    socketutil:set_timeout(timeout, maxtime)
    local function webhookReq()        

        local try_again = false
        local response = {}

        local result, code, headers, status = http.request {
            method = "POST",
            url = self.settings:readSetting("webhook_url"),
            headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = #data
            },
            source = ltn12.source.string(data),
            sink = socketutil.table_sink(response)
        }
        local response = table.concat(response)
        
        if result ~= 1 then
            self:warn(T(_("Failed to send request: %1"), code))
        elseif code == 204 or code == 200 then
            logger.info(_("Sent highlighted text to Discord successfuly"))
        elseif code ~= 429 then
            self:warn(T(_("Failed, HTTP status code: %1"), code))
        else
            try_again = true
        end

        return try_again, response
    end

    local try_again, response = webhookReq()

    if try_again then
        local ok, result = pcall(JSON.decode, response)
        if ok and result and result.retry_after and type(result.retry_after) == "number" then
            local retry_after = result.retry_after

            local warnning_msg = self:warn(T(_("You are being rate limited, trying again in %1 seconds"), retry_after))
            -- Make the warning show before sleep
            UIManager:forceRePaint()
            ffiUtil.sleep(retry_after)
            UIManager:close(warnning_msg)

            local try_again = webhookReq()
            if try_again then
                self:warn(T(_("Failed to send after waiting %1 seconds and sending a request again"), retry_after))
            end
        else
            self:warn(_("You are being rate limited, couldn't fetch the wait time until you can retry sending the request"))
        end
    end

    socketutil:reset_timeout()
end

function  SendToDiscord:getPercentProgress()
    if self.ui.document.info.has_pages then
        return PluginUtil:myRoundPercent(self.ui.paging:getLastPercent())
    else
        return PluginUtil:myRoundPercent(self.ui.rolling:getLastPercent())
    end
end

function SendToDiscord:addPrefixSuffix(text)
    return self.settings:readSetting("prefix_text") .. text .. self.settings:readSetting("suffix_text")
end

function SendToDiscord:finalText(text)
    local new_space = self.settings:readSetting("space_encoding")
    local wrap_code_block = self.settings:isTrue("wrap_code_block")

    -- Trim and turn consecutive whitespaces into a single space (not including new line)
    -- Exactly like Discord embeds when not in code block
    -- Do this on space encoded strings as well, use the code block option for keeping spaces unchanged
    if not wrap_code_block then
        text = util.cleanupSelectedText(text)
    end

    if new_space ~= " " then
        text = text:gsub(" ", new_space)
    end

    -- Intentionally does not encode spaces
    text = self:addPrefixSuffix(text)

    if wrap_code_block then
        text = "```" .. text .. "```"
    end

    return text
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
                
                local text = self:finalText(this.selected_text.text)

                local book_title = doc_metadata.title or _("Unknown Title")
                local book_author = PluginUtil:linesToSingleLine(doc_metadata.authors or _("Unknown Author"))
                
                local curr_page = self.ui:getCurrentPage()
                local total_pages = self.ui.document:getPageCount()
                
                local page_progress = nil

                if curr_page ~= nil and total_pages ~= nil then
                    page_progress = curr_page .. " / " .. total_pages
                end
                
                local percent_progress = self:getPercentProgress() .. "%"

                self:send(book_author, book_title, text, percent_progress, page_progress)
                
                this:onClose(true)
            end,
        }
    end)
end

function SendToDiscord:settingInputTable(setting, setting_title, dialog_description, add_separator)
    return {
        text_func = function()
            return T("%1: %2", setting_title, self.settings:readSetting(setting))
        end,
        separator = add_separator,
        keep_menu_open = true,
        callback = function(touchmenu_instance)            
            self.curr_dialog = InputDialog:new{
                title = setting_title,
                description = dialog_description,
                input = self.settings:readSetting(setting),
                buttons = {{
                    {
                        text = _("Cancel"),
                        callback = function()
                            UIManager:close(self.curr_dialog)
                        end
                    },
                    {
                        text = _("Save"),
                        callback = function()
                            local input_text = self.curr_dialog:getInputText()
                            self.settings:saveSetting(setting, input_text)
                            self.settings:flush()
                            UIManager:close(self.curr_dialog)
                            if touchmenu_instance then
                                touchmenu_instance:updateItems()
                            end
                        end
                    }
                }}
            }
        
            UIManager:show(self.curr_dialog)
            self.curr_dialog:onShowKeyboard()
        end
    }
end

function SendToDiscord:settingSpinTable(setting, setting_title, widget_title, min, max, default, add_separator)
    local SpinWidget = require("ui/widget/spinwidget")
    
    return {
        text_func = function()
            return T("%1: %2", setting_title, self.settings:readSetting(setting))
        end,
        separator = add_separator,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            UIManager:show(SpinWidget:new{
                title_text = widget_title,
                value = self.settings:readSetting(setting),
                value_min = min,
                value_max = max,
                default_value = default,
                callback = function(spin)
                    self.settings:saveSetting(setting, spin.value)
                    self.settings:flush()
                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end              
                end
            })         
        end
    }
end

function SendToDiscord:settingCheckboxTable(setting, setting_title)
    return {
        text = setting_title,
        checked_func = function()
            return self.settings:isTrue(setting)
        end,
        callback = function()
            self.settings:toggle(setting)
            self.settings:flush()
        end
    }
end

-- If a value must be chosen a default value corresponding to one of the values must be set in the init func
function SendToDiscord:radioButtonTable(setting, title, value)
    return {
        text = title,
        checked_func = function()
            return self.settings:readSetting(setting) == value
        end,
        radio = true,
        callback = function()
            self.settings:saveSetting(setting, value)
            self.settings:flush()
        end
    }
end

function SendToDiscord:addToMainMenu(menu_items)
    menu_items.sendtodiscord = {
        text = _("SendToDiscord"),
        sub_item_table = {
            {
                text = _("Send clipboard to Discord"),
                callback = function()
                    if not Device:hasClipboard() then
                        self:warn(_("This device does not have a clipboard"))
                        return
                    end
                    
                    local clipboard_text = self:finalText(Device.input.getClipboardText())

                    if clipboard_text == nil or clipboard_text == "" then
                        self:warn(_("Clipboard is empty, did not send anything to Discord"))
                    else
                        self:send("KOReader", _("Clipboard"), clipboard_text, _("Last copied text"))
                    end
                end,
            },
            {
                text = _("Settings"),
                sub_item_table = {
                    self:settingInputTable(
                        "webhook_url",
                        _("Webhook URL"),
                        _("Enter your webhook url:"),
                        true
                    ),
                    {
                        text = _("Text manipulation"),
                        sub_item_table = {
                            {
                                text = _("Space encoding (usually for urls)"),
                                separator = true,
                                sub_item_table = {
                                    self:radioButtonTable("space_encoding", "None", " "),
                                    self:radioButtonTable("space_encoding", "%20", "%%20"),
                                    self:radioButtonTable("space_encoding", "- (dash)", "-"),
                                    self:radioButtonTable("space_encoding", "_ (underscore)", "_"),
                                    self:radioButtonTable("space_encoding", "+", "+"),
                                }
                            },
                            self:settingInputTable(
                                "prefix_text",
                                _("Prefix text"),
                                _("Enter text that will be added before the copied text:"),
                                false
                            ),
                            self:settingInputTable(
                                "suffix_text",
                                _("Suffix text"),
                                _("Enter text that will be added after the copied text:"),
                                true
                            ),
                            self:settingCheckboxTable(
                                "wrap_code_block",
                                _("Wrap text in code block (whitespaces stay the exact same, doesn't matter for spaces if encoded)")
                            )
                        }
                    },
                    {
                        text = _("Embed color"),
                        sub_item_table = {
                            self:settingSpinTable("red", "R", _("Red value"), 0, 255, self.default_rgb[1], false),
                            self:settingSpinTable("green", "G", _("Green value"), 0, 255, self.default_rgb[2], false),
                            self:settingSpinTable("blue", "B", _("Blue value"), 0, 255, self.default_rgb[3], true),
                            {
                                text = _("Reset to default"),
                                keep_menu_open = true,
                                callback = function(touchmenu_instance)
                                    self.settings:saveSetting("red", self.default_rgb[1])
                                    self.settings:saveSetting("green", self.default_rgb[2])
                                    self.settings:saveSetting("blue", self.default_rgb[3])
                                    self.settings:flush()
                                    if touchmenu_instance then
                                        touchmenu_instance:updateItems()
                                    end 
                                end
                            }
                        }
                    }
                },
                separator = true
            },
            {
                text = _("About SendToDiscord"),
                keep_menu_open = true,
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = _("SendToDiscord lets you send highlighted text and text from your clipboard to Discord in beautiful embeds using webhooks.\n\nSendToDiscord adds the book's title, author and progress to the embed, it also lets you change the embed's color, add a suffix and a prefix to your text, encode spaces incase you want to put the text inside a link and wrap it inside a code block.\n\nStart by adding your Discord webhook url in the settings.")
                    })
                end
            }
        }
    }
end

return SendToDiscord