---@diagnostic disable: missing-parameter
---@omw-context local
local self = require("openmw.self")
local core = require("openmw.core")
local I = require("openmw.interfaces")
local storage = require("openmw.storage")
local async = require("openmw.async")

if self.type.isDead(self) then
    return
elseif core.API_REVISION < 144 then
    local msg = "[Distinct Elemental Damage]\nThis mod requires the latest OpenMW Dev Build to work."
    self:sendEvent("ShowMessage", { message = msg })
    error(msg)
    return
end

local settingsCache = require("scripts.DistinctElementalDamage.util.settingsCache")

local settings = settingsCache.new(
    storage.globalSection("SettingsDistinctElementalDamage"),
    async
)

local selfEffects = self.type.activeEffects(self)
local selfMagicka = self.type.stats.dynamic.magicka(self)
local selfHealth = self.type.stats.dynamic.health(self)
local selfSpeed = self.type.stats.attributes.speed(self)

local fireDamageMult = 1
local frostSpeedDamageApplied = 0
local activeElementalEffects = {}
local elementalEffectsActive = true -- setting it to true so that the first update will check for active effects

local function log(msg, ...)
    if settings.log then
        print(msg:format(...))
    end
end

local elementalEffects = {
    [core.magic.EFFECT_TYPE.FireDamage] = function(magnitude, dt)
        fireDamageMult = 1 + magnitude * settings.fireEffectiveness
        log("FireDamage: magnitude=%.2f -> fireDamageMult=%.3f", magnitude, fireDamageMult)
    end,
    [core.magic.EFFECT_TYPE.FrostDamage] = function(magnitude, dt)
        local desiredDamage = magnitude * settings.frostEffectiveness
        local delta = desiredDamage - frostSpeedDamageApplied
        selfSpeed.damage = math.max(selfSpeed.damage + delta, 0)
        frostSpeedDamageApplied = desiredDamage
        log("FrostDamage: magnitude=%.2f delta=%.2f speed.damage=%.2f", magnitude, delta, selfSpeed.damage)
    end,
    [core.magic.EFFECT_TYPE.ShockDamage] = function(magnitude, dt)
        local damagedStat = selfMagicka.current - magnitude * settings.shockEffectiveness * dt
        selfMagicka.current = math.max(damagedStat, 0)
        log("ShockDamage: magnitude=%.2f magicka.current=%.2f", magnitude, selfMagicka.current)
    end,
    [core.magic.EFFECT_TYPE.Poison] = function(magnitude, dt)
        local damagedStat = selfHealth.current - magnitude * settings.poisonEffectiveness * dt
        selfHealth.current = math.max(damagedStat, 0)
        log("Poison: magnitude=%.2f health.current=%.2f", magnitude, selfHealth.current)
    end,
}

local function checkElementalEffects()
    elementalEffectsActive = false
    fireDamageMult = 1
    for effect, _ in pairs(elementalEffects) do
        local magnitude = selfEffects:getEffect(effect).magnitude
        print(effect, magnitude)
        if magnitude > 0 then
            activeElementalEffects[effect] = magnitude
            elementalEffectsActive = true
        else
            activeElementalEffects[effect] = nil
            if effect == core.magic.EFFECT_TYPE.FrostDamage and frostSpeedDamageApplied > 0 then
                selfSpeed.damage = math.max(selfSpeed.damage - frostSpeedDamageApplied, 0)
                frostSpeedDamageApplied = 0
                log("FrostDamage effect ended, speed.damage reset")
            end
        end
    end
    log("checkElementalEffects: elementalEffectsActive=%s", tostring(elementalEffectsActive))
end

local function onUpdate(dt)
    if not elementalEffectsActive then
        return
    end

    checkElementalEffects()

    for effect, magnitude in pairs(activeElementalEffects) do
        elementalEffects[effect](magnitude, dt)
    end
end

---@param attack openmw.interfaces.Combat.AttackInfo
---@return table
I.Combat.addOnHitHandler(function(attack)
    if not attack.successful or not attack.damage.health or fireDamageMult == 1 then
        return
    end
    
    local before = attack.damage.health
    attack.damage.health = attack.damage.health * fireDamageMult
    log("onHit: health damage %.2f -> %.2f (fireDamageMult=%.3f)", before, attack.damage.health, fireDamageMult)
end)

return {
    engineHandlers = {
        onUpdate = onUpdate,
        onSave = function()
            return {
                frostSpeedDamageApplied = frostSpeedDamageApplied
            }
        end,
        onLoad = function(data)
            data = data or {}
            frostSpeedDamageApplied = data.frostSpeedDamageApplied or frostSpeedDamageApplied
        end
    },
    eventHandlers = {
        ApplyMagicEffects = function()
            self:sendEvent("DistinctElementalDamage_delayedCheckEffects")
        end,
        DistinctElementalDamage_delayedCheckEffects = checkElementalEffects
    },
}