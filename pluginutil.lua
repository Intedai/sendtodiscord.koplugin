local util = require("util")
local Math = require("optmath")
local bit = require("bit")

local PluginUtil = {}

--[[--
Turns a line new lines into a single line seperated by commas
but the last line is seperated by "and"

@tparam string lines_str
@treturn string line seperated by commas, last line is seperated by "and"
]]
function PluginUtil:linesToSingleLine(lines_str)
    local lines = util.splitToArray(lines_str, "\n")
    if #lines == 1 then
        return lines_str
    else
        local lines_without_last = table.concat(lines, ", ", 1, #lines - 1)
        return lines_without_last .. " and " .. lines[#lines] 
    end
end

--[[--
Rounds a percentage to a percentage from 0% to 100%

@tparam float percent
@treturn int rounded percentage from 0% to 100%
]]
function PluginUtil:myRoundPercent(percent)
    return  Math.round(Math.roundPercent(percent) * 100)
end

--[[--
Converts rgb to single int

@tparam int r
@tparam int g
@tparam int b
@treturn int rgb
]]
function PluginUtil:rgbToInt(r, g, b)
    return bit.bor(bit.lshift(r, 16), bit.lshift(g, 8), b)
end

return PluginUtil