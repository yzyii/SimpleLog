--[[
* Addons - Copyright (c) 2021 Ashita Development Team
* Contact: https://www.ashitaxi.com/
* Contact: https://discord.gg/Ashita
*
* This file is part of Ashita.
*
* Ashita is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Ashita is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with Ashita.  If not, see <https://www.gnu.org/licenses/>.
--]]

addon.name      = 'simplelog'
addon.author    = 'Created by Byrth, Ported by Spiken'
addon.version   = '0.1.1'
addon.desc      = 'Combat log Parser'
addon.link      = 'https://github.com/Spike2D/SimpleLog'

require('common')
require('lib\\constants')
chat                  = require('chat')
UTF8toSJIS            = require('lib.shift_jis')

res_actmsg            = require('lib.res.action_messages')
res_igramm            = require('lib.res.items_grammar')
res_skills            = require('lib.res.skills')

gDefaultSettings      = require('configuration')
gStatus               = require('lib.profilehandler')
gFuncs                = require('lib.functions')
gFileTools            = require('lib.filetools')
gCommandHandlers      = require('lib.commandhandlers')
gTextHandlers         = require('lib.texthandlers')
gPacketHandlers       = require('lib.packethandlers')
gActionHandlers       = require('lib.actionhandlers')
gConfig               = require('lib.ui')

gProfileSettings      = nil
gProfileFilter        = nil
gProfileColor         = nil

gPriority             = require('configuration_priority')

local gdi             = require('gdifonts.include')
local settings        = require('settings')
local scaling         = require('scaling')

local screenCenter = {
    x = scaling.window.w / 2,
    y = scaling.window.h / 2,
}

local defaultSettings = T{
    fade_after = 4,
    fade_duration = 1,
    font_spacing = 1.5,
    font_color_priority = 0xFFFFD700,
    font_color_priority_alt = 0xFF3F00FF,
    font_color_default = 0xFFFFFFFF,
    display_priority_only = false,
    use_alt_priority_font_color = false,
    font = {
        font_alignment = gdi.Alignment.Center,
        font_family = 'Consolas',
        font_flags = gdi.FontFlags.Bold,
        font_height = 36,
        outline_color = 0xFF000000,
        outline_width = 2,
    },
    x_offset = 0,
    y_offset = 50,
}

gLoadedSettings = nil

local messages = {
    [1] = nil,
    [2] = nil,
    [3] = nil,
    [4] = nil,
    [5] = nil,
}

local function copy(t)
  local t2 = {}
  for k,v in pairs(t) do
    t2[k] = v
  end
  return t2
end

local function initialise()
    for i = 1,5 do
        local font = copy(gLoadedSettings.font)
        font.position_x = screenCenter.x + gLoadedSettings.x_offset
        font.position_y = screenCenter.y - gLoadedSettings.y_offset + (i - 1) * font.font_height * gLoadedSettings.font_spacing
        messages[i] = { fontobj = gdi:create_object(font), text = nil, expiry = nil }
    end
end

local function updateFade(obj)
    local maxAlpha = 1
    local minAlpha = 0
    local fadeDuration = gLoadedSettings.fade_duration
    local fadeAfter = gLoadedSettings.fade_after

    local elapsed = math.max(0, os.clock() - obj.expiry)
    local alpha = math.max(minAlpha, maxAlpha - (maxAlpha * (elapsed / fadeDuration)))

    obj.fontobj:set_opacity(alpha)

    if alpha == minAlpha then
        obj.expiry = nil
        obj.text = nil
    end
end

ashita.events.register('load', 'load_cb', function ()
    gStatus.Init()
    gLoadedSettings = settings.load(defaultSettings)
    initialise()
end)

ashita.events.register('unload', 'unload_cb', function()
    gdi:destroy_interface()
    settings.save()
end)

ashita.events.register('text_in', 'text_in_cb', function (e)
    if (gProfileSettings and gProfileSettings.mode.disable) then
        return
    end

    gTextHandlers.HandleIncomingText(e)
end)

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    gPacketHandlers.HandleIncomingPacket(e , messages)
end)

ashita.events.register('packet_out', 'packet_out_cb', function (e)
    if (gProfileSettings and gProfileSettings.mode.disable) then
        return
    end

    gPacketHandlers.HandleOutgoingPacket(e)
end)

ashita.events.register('command', 'command_cb', function (e)
    gCommandHandlers.HandleCommand(e)

    local args = e.command:args()
    if (#args == 0 or args[1] ~= '/swarnings') then
        return
    end

    e.blocked = true

    if (#args == 4 and args[2]:any('pos')) then
        local x = tonumber(args[3])
        local y = tonumber(args[4])
        if (x and y) then
            gLoadedSettings.x_offset = x
            gLoadedSettings.y_offset = y
            for i = 1,5 do
                local position_x = screenCenter.x + x
                local position_y = screenCenter.y - y + (i - 1) * gLoadedSettings.font.font_height * gLoadedSettings.font_spacing
                messages[i].fontobj:set_position_x(position_x)
                messages[i].fontobj:set_position_y(position_y)
            end

            local expiry = os.clock() + gLoadedSettings.fade_after
            messages[1].fontobj:set_font_color(gLoadedSettings.font_color_priority)
            messages[1].fontobj:set_text('Messages will be displayed here')
            messages[1].expiry = expiry
            messages[5].fontobj:set_font_color(gLoadedSettings.font_color_priority)
            messages[5].fontobj:set_text('Have Fun!')
            messages[5].expiry = expiry
        end
        return
    end

    if (#args == 2 and args[2]:any('font')) then
        gLoadedSettings.use_alt_priority_font_color = not gLoadedSettings.use_alt_priority_font_color
        print(chat.header('sWarnings') .. chat.message('Use Alternate Priority Font Colour: ' .. tostring(gLoadedSettings.use_alt_priority_font_color)))
        return
    end

    if (#args == 2 and args[2]:any('prio')) then
        gLoadedSettings.display_priority_only = not gLoadedSettings.display_priority_only
        print(chat.header('sWarnings') .. chat.message('Display Priority Actions Only: ' .. tostring(gLoadedSettings.display_priority_only)))
        return
    end

    print(chat.header('sWarnings') .. chat.message('Note: Edit your list of priority actions in configuration_priority.lua'))
    print(chat.header('sWarnings') .. chat.message('/swarnings font - Toggle the colour of priority actions'))
    print(chat.header('sWarnings') .. chat.message('/swarnings prio - Toggle displaying priority messages only'))
    print(chat.header('sWarnings') .. chat.message('/swarnings pos [x_offset] [y_offset] - Reposition UI text (default is 0 50)'))
end)

local lastXDist = nil
local lastClock = nil

ashita.events.register('d3d_present', 'd3d_present_callback1', function ()
    gConfig.render_config(gConfig.state.toggle_menu)
    gConfig.toggle_menu(0)

    for i = 1,5 do
        if (messages[i].expiry ~= nil) then
            updateFade(messages[i])
        end
    end
end)

