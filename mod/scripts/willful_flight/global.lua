local world = require('openmw.world')
local core = require('openmw.core')
local player, records = nil, {}

return {
    eventHandlers={WillfulFlightRecord=function(data)
        if not player or not player:isValid() then return end
        local amount=tonumber(data.amount)
        if not amount or amount ~= amount or amount < 1 or amount > 5000 or amount%1 ~= 0 then return end
        local id=records[amount]
        if not id then
            local record=world.createRecord(core.magic.spells.createRecordDraft {
                name='Willful Flight lift', type=core.magic.SPELL_TYPE.Spell,
                cost=0, isAutocalc=false, alwaysSucceedFlag=true,
                effects={{id='levitate', range=core.magic.RANGE.Self, area=0, duration=1,
                    magnitudeMin=amount, magnitudeMax=amount}},
            })
            id=record.id; records[amount]=id
        end
        local catalogue={}
        for value, record in pairs(records) do catalogue[record]=value end
        player:sendEvent('WillfulFlightRecord', {records=catalogue})
    end},
    engineHandlers={onPlayerAdded=function(object) player=object end,
        onSave=function() return {records=records} end,
        onLoad=function(data) records=data and data.records or {}; player=nil end},
}
