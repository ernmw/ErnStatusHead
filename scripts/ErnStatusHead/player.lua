--[[
ErnStatusHead for OpenMW.
Copyright (C) 2026 Erin Pentecost

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]
local MOD_NAME = require("scripts.ErnStatusHead.ns")
local core = require("openmw.core")
local pself = require("openmw.self")
local camera = require('openmw.camera')
local util = require('openmw.util')
local async = require("openmw.async")
local types = require('openmw.types')
local input = require('openmw.input')
local controls = require('openmw.interfaces').Controls
local nearby = require('openmw.nearby')
local ui = require('openmw.ui')
local interfaces = require("openmw.interfaces")
local settings = require("scripts.ErnStatusHead.settings")

local baseSize = 64

local attacking = false

local attackGroups = {
    weapononehand = true,
    weapontwohand = true,
    bowandarrow = true,
    handtohand = true,
    -- darts? crossbow?
}

local castKeyStart = {
    ["target start"] = true,
    ["touch start"] = true,
}
local castKeyEnd = {
    ["target release"] = true,
    ["touch release"] = true,
}

local function hasSuffix(str, suffix)
    return suffix == "" or str:sub(- #suffix) == suffix
end
local function hasPrefix(str, prefix)
    return prefix == "" or str:sub(1, #prefix) == prefix
end

interfaces.AnimationController.addTextKeyHandler("", function(groupname, key)
    if attackGroups[groupname] then
        print(key)
        if hasPrefix(key, "unequip") or hasPrefix(key, "equip") then
            attacking = false
        elseif hasSuffix(key, "start") then
            attacking = true
        elseif hasSuffix(key, "stop") then
            attacking = false
        end
    elseif groupname == "spellcast" then
        if castKeyStart[key] then
            attacking = true
        elseif castKeyEnd[key] then
            attacking = false
        end
    end
end)


local function layerElem(path)
    return ui.create {
        type = ui.TYPE.Image,
        props = {
            resource = ui.texture { path = path },
            relativePosition = util.vector2(0, 0),
            size = util.vector2(baseSize * settings.main.scale, baseSize * settings.main.scale)
        },
        events = {},
    }
end

local function updateSize(elem)
    elem.layout.props.size = util.vector2(baseSize * settings.main.scale, baseSize * settings.main.scale)
    elem:update()
end

local heads = {
    hurt = layerElem("Textures/ErnStatusHead/hurt.png"),
    malice = layerElem("Textures/ErnStatusHead/malice.png"),
    malice_hurt = layerElem("Textures/ErnStatusHead/malice_hurt.png"),
    neutral = layerElem("Textures/ErnStatusHead/neutral.png"),
    tired = layerElem("Textures/ErnStatusHead/tired.png"),
    very_hurt = layerElem("Textures/ErnStatusHead/very_hurt.png"),
}

local fatigueStat = pself.type.stats.dynamic.fatigue(pself)
local healthStat = pself.type.stats.dynamic.health(pself)
local magickaStat = pself.type.stats.dynamic.magicka(pself)

local function selectHead()
    if healthStat.current * 4 < healthStat.base then
        return "very_hurt"
    elseif healthStat.current * 2 < healthStat.base then
        if attacking then
            return "malice_hurt"
        end
        return "hurt"
    elseif attacking then
        return "malice"
    elseif fatigueStat.current * 2 < fatigueStat.base then
        return "tired"
    end
    return "neutral"
end

local earings = {
    left = layerElem("Textures/ErnStatusHead/earings_left.png"),
    down = layerElem("Textures/ErnStatusHead/earings_down.png"),
    right = layerElem("Textures/ErnStatusHead/earings_right.png"),
}

local function selectEarings()
    if pself.controls.sideMovement > 0.5 then
        return "left"
    elseif pself.controls.sideMovement < -0.5 then
        return "right"
    else
        return "down"
    end
end

local gem = layerElem("Textures/ErnStatusHead/gem.png")

local function lerpColor(a, b, t)
    return util.color.rgba(
        a.r + (b.r - a.r) * t,
        a.g + (b.g - a.g) * t,
        a.b + (b.b - a.b) * t,
        a.a + (b.a - a.a) * t
    )
end


local noMagickaColor = util.color.hex("173e56")
local maxMagickaColor = util.color.hex("fedf63")

local function setGemColor()
    gem.layout.props.color = lerpColor(noMagickaColor, maxMagickaColor, magickaStat.current / magickaStat.base)
    gem:update()
end

local rootElement = ui.create {
    name = "rootStatusHead",
    layer = 'HUD',
    type = ui.TYPE.Widget,
    props = {
        relativePosition = util.vector2(settings.main.positionX, settings.main.positionY),
        size = util.vector2(baseSize * settings.main.scale, baseSize * settings.main.scale),
        anchor = util.vector2(0.5, 0.5),
        visible = true,
        autoSize = false,
    },
    content = ui.content {}
}

settings.main.subscribe(async:callback(function(_, key)
    for k, v in pairs(heads) do
        updateSize(v)
    end
    for k, v in pairs(earings) do
        updateSize(v)
    end
    updateSize(gem)

    rootElement.layout.props.relativePosition = util.vector2(settings.main.positionX, settings.main.positionY)
    updateSize(rootElement)
end))

local function onUpdate(dt)
    setGemColor()
    rootElement.layout.content = ui.content({
        heads[selectHead()],
        earings[selectEarings()],
        gem
    })
    rootElement:update()
end

return {
    engineHandlers = {
        onUpdate = onUpdate,
    }
}
