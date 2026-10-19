local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local state, nextCast = {}, 0
local atan2 = math.atan2 or function(y,x) return math.atan(y,x) end
local function wrap(angle) return (angle+math.pi) % (2*math.pi)-math.pi end

local function setup(data)
    state = data or {}
    self:enableAI(false)
    types.Actor.spells(self):clear()
    types.Actor.spells(self):add(state.spell)
    types.Actor.setSelectedSpell(self, core.magic.spells.records[state.spell])
    types.Actor.stats.dynamic.magicka(self).base = 1000
    types.Actor.stats.attributes.willpower(self).base = 100
    types.Actor.stats.attributes.luck(self).base = 100
    nextCast = core.getSimulationTime()+2
end

return {
    eventHandlers={EngineLabPause=function(value) state.paused=value; nextCast=core.getSimulationTime()+2 end},
    engineHandlers={
        onInit=setup,
        onLoad=function(data) setup(data); state.paused=true end,
        onSave=function() return state end,
        onUpdate=function()
            self.controls.use = self.ATTACK_TYPE.NoAttack
            self.controls.movement, self.controls.sideMovement = 0, 0
            local target = state.player
            if state.paused or not target or not target:isValid() or not self.cell
                or not self.cell:isInSameSpace(target) or types.Actor.isDead(self) then return end
            local delta = target.position-self.position
            self.controls.yawChange = wrap(atan2(delta.x,delta.y)-self.rotation:getYaw())
            self.controls.pitchChange = -atan2(delta.z,math.sqrt(delta.x*delta.x+delta.y*delta.y))-self.rotation:getPitch()
            types.Actor.stats.dynamic.magicka(self).current = 1000
            local fatigue = types.Actor.stats.dynamic.fatigue(self)
            fatigue.current = fatigue.base+fatigue.modifier
            if core.getSimulationTime() >= nextCast then
                types.Actor.setSelectedSpell(self, core.magic.spells.records[state.spell])
                types.Actor.setStance(self, types.Actor.STANCE.Spell)
                self.controls.use = self.ATTACK_TYPE.Any
                target:sendEvent('EngineLabCastAttempt', {actor=self.id, spell=state.spell})
                nextCast = core.getSimulationTime()+8
            end
        end,
    },
}
