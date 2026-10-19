local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local storage = require('openmw.storage')
local I = require('openmw.interfaces')
local policy = require('scripts.willful_flight.policy')
local group = 'SettingsPlayerWillfulFlight'
I.Settings.registerPage {key='WillfulFlight', l10n='WillfulFlight', name='Page'}
I.Settings.registerGroup {
    key=group, page='WillfulFlight', l10n='WillfulFlight', name='Group', permanentStorage=false,
    settings={{key='enabled', renderer='checkbox', name='Enabled', default=true}},
}
local settings = storage.playerSection(group)
local helpers, wanted, nextRefresh, lastFactor = {}, nil, 0, 0
local diagnostic = {ratio=1, original=0, helper=0, applied=false}

local function scan()
    local magnitude, instances = 0, {}
    for _, spell in pairs(types.Actor.activeSpells(self)) do
        if helpers[spell.id] then
            instances[#instances+1] = spell.activeSpellId
            for _, effect in ipairs(spell.effects) do
                if effect.id == 'levitate' then magnitude=magnitude+(effect.magnitudeThisFrame or 0) end
            end
        end
    end
    return magnitude, instances
end

local function clear()
    local _, instances = scan()
    for _, id in ipairs(instances) do types.Actor.activeSpells(self):remove(id) end
    wanted, nextRefresh = nil, 0
end

local function values()
    local helper = scan()
    local total = types.Actor.activeEffects(self):getEffect('levitate').magnitude
    local original = math.max(0,total-helper)
    local capacity = types.Actor.getCapacity(self)
    local load = capacity > 0 and types.Actor.getEncumbrance(self)/capacity or 2
    local speed = types.Actor.stats.attributes.speed(self).modified
    local willpower = types.Actor.stats.attributes.willpower(self).modified
    local minimum, maximum = core.getGMST('fMinFlySpeed'), core.getGMST('fMaxFlySpeed')
    local penalty = core.getGMST('fEncumberedMoveEffect')
    return speed, willpower, original, helper, minimum, maximum, load, penalty
end

local function allowed(original, maximum, minimum, load)
    return policy.enabled(settings:get('enabled')) and original > 0 and maximum > minimum
        and load <= 1 and not types.Actor.isDead(self) and not self.controls.jump
        and not types.Player.isWerewolf(self)
end

local function update()
    local speed, willpower, original, _, minimum, maximum, load = values()
    if not allowed(original,maximum,minimum,load) then clear(); return end
    local amount = policy.lift(speed,willpower)
    if amount == 0 then clear(); return end
    if wanted ~= amount then
        wanted = amount
        core.sendGlobalEvent('WillfulFlightRecord', {amount=amount})
        nextRefresh = 0
    end
    local record
    for id, value in pairs(helpers) do if value == amount then record=id; break end end
    if not record or core.getSimulationTime() < nextRefresh then return end
    local _, instances = scan()
    for _, id in ipairs(instances) do types.Actor.activeSpells(self):remove(id) end
    types.Actor.activeSpells(self):add({id=record, effects={0}, stackable=false,
        ignoreResistances=true, ignoreReflect=true, ignoreSpellAbsorption=true})
    nextRefresh = core.getSimulationTime()+.3
end

local function frame()
    if core.isWorldPaused() then return end
    local forward, side = self.controls.movement, self.controls.sideMovement
    local speed, willpower, original, helper, minimum, maximum, load, penalty = values()
    local ratio = 1
    local native = policy.speed(speed,original+helper,minimum,maximum,load,penalty)
    -- Do not attenuate ground/swimming movement when the engine has blocked levitation.
    local flying = allowed(original,maximum,minimum,load)
        and policy.matchesFlight(types.Actor.getCurrentSpeed(self),native,lastFactor)
    if flying then ratio=policy.ratio(speed,willpower,original,helper,minimum,maximum,load,penalty) end
    local scaledForward, scaledSide, factor = policy.inputs(forward,side,ratio)
    if flying then self.controls.movement, self.controls.sideMovement=scaledForward,scaledSide end
    lastFactor = flying and factor or math.min(1,math.sqrt(forward*forward+side*side))
    diagnostic={ratio=ratio, original=original, helper=helper, applied=flying, native=native}
end

return {
    interfaceName='WillfulFlight',
    interface={diagnostics=function() return diagnostic end},
    eventHandlers={WillfulFlightRecord=function(data)
        for id, amount in pairs(data.records) do helpers[id]=amount end
    end},
    engineHandlers={onUpdate=update, onFrame=frame,
        onSave=function() return {helpers=helpers, enabled=policy.enabled(settings:get('enabled'))} end,
        onLoad=function(data)
            helpers=data and data.helpers or {}; lastFactor=0; wanted=nil; nextRefresh=0
            if data then settings:set('enabled',data.enabled ~= false) end
        end,
    },
}
