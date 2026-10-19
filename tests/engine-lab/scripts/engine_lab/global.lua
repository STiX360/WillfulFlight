local world = require('openmw.world')
local core = require('openmw.core')
local types = require('openmw.types')
local util = require('openmw.util')
local config = require('scripts.engine_lab.config')
local log = require('scripts.engine_lab.log')
local player, pending, ready, spawned = nil, nil, false, false
local objects, owners, casters = {}, {}, {}
local paused = true

local function valid(object) return object and object:isValid() end

local function cleanup()
    for _, object in ipairs(objects) do if valid(object) then object:remove() end end
    objects, owners, casters = {}, {}, {}
    ready, pending, paused, spawned = false, nil, true, false
    log.emit('global', 'cleanup')
end

local function place(record, x, y)
    local object = world.createObject(record)
    objects[#objects + 1] = object
    object:teleport(config.cell, util.vector3(x, y, 80), {onGround=true})
    return object
end

local function npc(name, x, y)
    local record = world.createRecord(types.NPC.createRecordDraft {
        template=types.NPC.records['fargoth'], name=name, mwscript='',
        isEssential=false, isRespawning=false,
    })
    local object = place(record.id, x, y)
    object:sendEvent('StartAIPackage', {type='Wander', distance=0, duration=0, isRepeat=true})
    return object, record.id
end

local function spawn()
    for _, spec in ipairs(config.owners) do
        local owner, id = npc(spec.name .. ' Owner', spec.x, 15)
        local record = world.createRecord(types.Activator.createRecordDraft {
            template=types.Activator.records['active_de_bedroll'], name=spec.name .. " Owner's Bed",
        })
        local bed = place(record.id, spec.x, -130)
        bed.owner.recordId = id
        owners[#owners + 1] = {object=owner, bed=bed, target=spec.disposition, name=spec.name}
    end
    for index, spec in ipairs(config.casters) do
        local spell = world.createRecord(core.magic.spells.createRecordDraft {
            name='Engine Lab: ' .. spec.name, type=core.magic.SPELL_TYPE.Spell,
            cost=spec.cost, isAutocalc=false, alwaysSucceedFlag=true,
            effects={{id=spec.effect, range=core.magic.RANGE[spec.range], area=0,
                duration=2, magnitudeMin=1, magnitudeMax=1}},
        })
        local actor = npc(spec.name, (index-1)*120, 400)
        actor:addScript('scripts/engine_lab/caster.lua', {spell=spell.id, player=player, paused=true})
        casters[#casters + 1] = actor
    end
    for index, spec in ipairs(config.items) do
        local object = world.createObject(spec.record, spec.count)
        objects[#objects + 1] = object
        object:teleport(config.cell, util.vector3(spec.x or (index-1)*60, -80, 90), {onGround=true})
    end
    spawned = true
    pending = core.getSimulationTime() + 0.5
end

local function finish()
    local flightSpell = world.createRecord(core.magic.spells.createRecordDraft {
        name='Willful Flight Lab Levitate', type=core.magic.SPELL_TYPE.Spell,
        cost=0, isAutocalc=false, alwaysSucceedFlag=true,
        effects={{id='levitate', range=core.magic.RANGE.Self, area=0,
            duration=3600, magnitudeMin=10, magnitudeMax=10}},
    })
    for _, entry in ipairs(owners) do
        types.NPC.setBaseDisposition(entry.object, player, 50)
        local current = types.NPC.getDisposition(entry.object, player)
        types.NPC.setBaseDisposition(entry.object, player, 50 + entry.target-current)
        local actual = types.NPC.getDisposition(entry.object, player)
        if math.abs(actual-entry.target) > 1 then error('Disposition calibration failed: ' .. entry.name) end
    end
    ready, pending = true, nil
    player:sendEvent('EngineLabReady', {owners=#owners, casters=#casters, items=#config.items, spell=flightSpell.id})
    log.emit('global', 'fixtures', {owners=#owners, casters=#casters, items=#config.items})
end

return {
    eventHandlers={EngineLabPosition=function()
        if valid(player) then player:teleport(config.cell,util.vector3(0,-280,80),{onGround=true}) end
    end, EngineLabControl=function(data)
        if data.action == 'cleanup' then cleanup()
        elseif data.action == 'reset' then cleanup(); pending=core.getSimulationTime()+0.5
        elseif data.action == 'pause' then
            paused = not paused
            for _, actor in ipairs(casters) do if valid(actor) then actor:sendEvent('EngineLabPause', paused) end end
            log.emit('global', 'casting', {paused=paused})
        end
    end},
    engineHandlers={
        onPlayerAdded=function(object)
            player = object
            if ready then
                paused = true
                for _, actor in ipairs(casters) do if valid(actor) then actor:sendEvent('EngineLabPause', true) end end
                player:sendEvent('EngineLabReady', {owners=#owners, casters=#casters, items=#config.items})
            else pending=core.getSimulationTime()+0.5 end
        end,
        onUpdate=function()
            if not valid(player) or not pending or core.getSimulationTime() < pending then return end
            local ok, err = pcall(function() if not spawned then spawn() else finish() end end)
            if not ok then
                cleanup()
                log.emit('global', 'error', {detail=tostring(err)})
                player:sendEvent('EngineLabError', tostring(err))
            end
        end,
        onSave=function() return {objects=objects, owners=owners, casters=casters, ready=ready, spawned=spawned} end,
        onLoad=function(data)
            data = data or {}
            objects, owners, casters = data.objects or {}, data.owners or {}, data.casters or {}
            ready, spawned = data.ready == true, data.spawned == true
            paused, player, pending = true, nil, nil
        end,
    },
}
