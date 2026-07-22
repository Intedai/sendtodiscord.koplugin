local util = require("util")

local DiscordWebhook = {}

DiscordWebhook.LIMITS = {
    MAX_TOTAL_CHARS = 6000,
    MAX_TEXT_CHARS = 4096,
    MAX_FOOTER_TEXT_CHARS = 2048,
    MAX_AUTHOR_CHARS = 256,
    MAX_TITLE_CHARS = 256
}

--[[--
Verifies that a url is a Discord webhook url

@tparam string url
@treturn bool true if url is a Discord webhook url
]]
function DiscordWebhook.verifyWebhookUrl(url)
    local socket_url = require("socket.url")

    local parsed = socket_url.parse(url)

    if url == "" then return false end
    
    if parsed.scheme == "https"
       and parsed.host == "discord.com"
       and util.stringStartsWith(parsed.path, "/api/webhooks/")
       then
        return true
    end

    return false
end

--[[--
Builds the request body of the request sent to the webhook

@tparam table options (options are authors, title, color, text, footer_text)
@treturn string json of the request body
]]
function DiscordWebhook.build_request_body(options)
    local JSON = require("json")

    return JSON.encode{
        embeds = {
            {
                author = {
                    name = options.authors
                },
                title = options.title,
                color = options.color,
                description = options.text,
                footer = {
                    text = options.footer_text
                }
            }
        }
    }
end

return DiscordWebhook