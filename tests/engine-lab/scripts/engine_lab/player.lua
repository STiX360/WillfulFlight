local self = require('openmw.self')
local core = require('openmw.core')
local types = require('openmw.types')
local ui = require('openmw.ui')
local input = require('openmw.input')
local util = require('openmw.util')
local I = require('openmw.interfaces')
local storage = require('openmw.storage')
local async = require('openmw.async')
local config = require('scripts.engine_lab.config')
local log = require('scripts.engine_lab.log')
local spell, original, active, positioned = nil, nil, false, false
local index, due, running = 0, nil, false
input.bindAction('MoveForward', async:callback(function(_, value) return running and 1 or value end), {})
for _, key in ipairs({'MoveBackward','MoveLeft','MoveRight'}) do
    input.bindAction(key, async:callback(function(_, value) return running and 0 or value end), {})
end
input.bindAction('Run', async:callback(function(_, value) return running and false or value end), {})
local cases = {
    {name='weak Willpower slow Speed', speed=20, will=20},
    {name='weak Willpower fast Speed', speed=90, will=20},
    {name='strong Willpower fast Speed', speed=90, will=80},
    {name='strong Willpower slow Speed', speed=20, will=80},
    {name='fortified Willpower', speed=20, will=80, modifier=20},
    {name='damaged Willpower', speed=20, will=80, damage=40},
    {name='ground walking slow Speed', speed=20, will=80, ground=true},
    {name='ground walking fast Speed', speed=90, will=20, ground=true},
}

local function capture()
    original = original or {}
    for _, name in ipairs({'speed', 'willpower'}) do
        local stat = types.Actor.stats.attributes[name](self)
        original[name] = original[name] or {base=stat.base, modifier=stat.modifier, damage=stat.damage}
    end
end

local function removeFlight()
    if not spell then return end
    local spells = types.Actor.activeSpells(self)
    for _, effect in pairs(spells) do
        if effect.id == spell and effect.temporary then spells:remove(effect.activeSpellId) end
    end
end

local function restore()
    if not original then return end
    for name, values in pairs(original) do
        local stat = types.Actor.stats.attributes[name](self)
        for key, value in pairs(values) do stat[key] = value end
    end
    original = nil
    removeFlight()
    active = false
end

local function levitate(value)
    removeFlight()
    if value then
        types.Actor.activeSpells(self):add({id=spell, effects={0}, ignoreResistances=true,
            ignoreReflect=true, ignoreSpellAbsorption=true})
    end
    active = value
end

local function preset(speed, will, modifier, damage)
    capture()
    local s = types.Actor.stats.attributes.speed(self)
    local w = types.Actor.stats.attributes.willpower(self)
    s.base, s.modifier, s.damage = speed, 0, 0
    w.base, w.modifier, w.damage = will, modifier or 0, damage or 0
end

local function controls()
    -- Raw action bindings feed the normal controller before the production mod.
end

local function startCase()
    index = index + 1
    local case = cases[index]
    if not case then
        running = false
        self.controls.movement = 0
        restore()
        log.emit('player', 'flight_complete', {count=#cases, enabled=config.flight_enabled})
        if config.smoke then core.quit() end
        return
    end
    preset(case.speed, case.will, case.modifier, case.damage)
    levitate(not case.ground)
    core.sendGlobalEvent('EngineLabPosition', {})
    due = core.getSimulationTime() + 1.2
end

local function checkCase()
    local case = cases[index]
    local actual = types.Actor.getCurrentSpeed(self)
    local expected
    if case.ground then
        expected = types.Actor.getWalkSpeed(self)
    else
        local attribute = config.flight_enabled and types.Actor.stats.attributes.willpower(self).modified
            or types.Actor.stats.attributes.speed(self).modified
        local minimum, maximum = core.getGMST('fMinFlySpeed'), core.getGMST('fMaxFlySpeed')
        local load = types.Actor.getEncumbrance(self) / types.Actor.getCapacity(self)
        expected = math.max(0, (minimum + .01 * (attribute + 10) * (maximum-minimum))
            * (1 - core.getGMST('fEncumberedMoveEffect') * load))
    end
    local match = math.abs(actual-expected) <= math.max(.1, expected*.005)
    log.assertion({case=case.name, status=match and 'pass' or 'fail',
        actual=actual, expected=expected, enabled=config.flight_enabled,
        diagnostics=I.WillfulFlight.diagnostics()})
    startCase()
end

return {
    eventHandlers={
        EngineLabAssert=log.assertion,
        EngineLabError=function(detail)
            log.emit('player', 'error', {detail=detail})
            if config.smoke then core.quit() end
        end,
        EngineLabReady=function(data)
            storage.playerSection('SettingsPlayerWillfulFlight'):set('enabled',config.flight_enabled)
            spell = data.spell or spell
            log.emit('player', 'ready', data)
            if not spell then error('Flight lab spell is missing') end
            if config.smoke then running=true; index=0; startCase()
            else
                preset(40,20)
                levitate(true)
                ui.showMessage('Willful Flight: Ctrl+Shift+F1/F2 = Willpower 20/80; F3 restore; F4 levitate; F5 Speed 20/90.')
            end
        end,
    },
    engineHandlers={
        onFrame=controls,
        onUpdate=function()
            if not positioned then
                positioned=true
                core.sendGlobalEvent('EngineLabPosition', {})
            end
            controls()
            if running and core.getSimulationTime() >= due then checkCase() end
        end,
        onKeyPress=function(key)
            if running or not spell or not key.withCtrl or not key.withShift or key.withAlt
                or key.withSuper or I.UI.getMode() ~= nil then return end
            if key.code == input.KEY.F1 then preset(40,20); ui.showMessage('Willpower 20, Speed 40')
            elseif key.code == input.KEY.F2 then preset(40,80); ui.showMessage('Willpower 80, Speed 40')
            elseif key.code == input.KEY.F3 then restore(); ui.showMessage('Original stats restored; levitation removed')
            elseif key.code == input.KEY.F4 then levitate(not active)
            elseif key.code == input.KEY.F5 then
                capture()
                local s = types.Actor.stats.attributes.speed(self)
                s.base, s.modifier, s.damage = s.base == 20 and 90 or 20, 0, 0
                ui.showMessage('Speed ' .. s.base .. '; Willpower unchanged')
            end
        end,
        onSave=function() return {spell=spell, original=original} end,
        onLoad=function(data)
            spell=data and data.spell; original=data and data.original
            positioned=true; running=false
            restore()
        end,
    },
}
