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

local settingsCache = require("scripts.DistinctElementalDamage.utils.settingsCache")

local settingsCommon = settingsCache.new(
    storage.globalSection("SettingsDistinctElementalDamage_common"),
    async
)
local settingsFire = settingsCache.new(
    storage.globalSection("SettingsDistinctElementalDamage_fire"),
    async
)
local settingsFrost = settingsCache.new(
    storage.globalSection("SettingsDistinctElementalDamage_frost"),
    async
)
local settingsShock = settingsCache.new(
    storage.globalSection("SettingsDistinctElementalDamage_shock"),
    async
)
local settingsPoison = settingsCache.new(
    storage.globalSection("SettingsDistinctElementalDamage_poison"),
    async
)

local selfEffects = self.type.activeEffects(self)
local selfMagicka = self.type.stats.dynamic.magicka(self)
local selfHealth = self.type.stats.dynamic.health(self)
local selfFatigue = self.type.stats.dynamic.fatigue(self)
local selfSpeed = self.type.stats.attributes.speed(self)

local fireDamageMult = 1    -- TODO allow overlapping effect support
local frostSpeedDamageApplied = 0    -- TODO allow overlapping effect support
local activeElementalEffects = {}
local elementalEffectsActive = true -- setting it to true so that the first update will check for active effects

local function log(msg, ...)
    if settingsCommon.log then
        print(msg:format(...))
    end
end

local function damageStat(magnitude, dt, stat)
    local damagedStat = stat.current - magnitude * dt
    stat.current = math.max(damagedStat, 0)
    log("ShockDamage: magnitude=%.2f magicka.current=%.2f", magnitude, stat.current)    -- TODO rewrite logging
end

local secondaryEffects = {
    ["Physical Weakness"] = function(magnitude, dt)
        fireDamageMult = 1 + magnitude
        log("FireDamage: magnitude=%.2f -> fireDamageMult=%.3f", magnitude, fireDamageMult)
    end,
    ["Drain Speed"] = function(magnitude, dt)
        local delta = magnitude - frostSpeedDamageApplied
        selfSpeed.damage = math.max(selfSpeed.damage + delta, 0)
        frostSpeedDamageApplied = magnitude
        log("FrostDamage: magnitude=%.2f delta=%.2f speed.damage=%.2f", magnitude, delta, selfSpeed.damage)
    end,
    ["Damage Health"] = function(magnitude, dt)
        damageStat(magnitude, dt, selfHealth)
    end,
    ["Damage Magicka"] = function(magnitude, dt)
        damageStat(magnitude, dt, selfMagicka)
    end,
    ["Damage Fatigue"] = function(magnitude, dt)
        damageStat(magnitude, dt, selfFatigue)
    end,
}

local function callSecondaryEffect(settings, magnitude, dt)
    secondaryEffects[settings.secondaryEffect](magnitude * settings.magnitudeScale, dt)
end

local elementalEffects = {
    [core.magic.EFFECT_TYPE.FireDamage] = function(magnitude, dt)
        if not settingsCommon.enable.fire then return end
        callSecondaryEffect(settingsFire, magnitude, dt)
    end,
    [core.magic.EFFECT_TYPE.FrostDamage] = function(magnitude, dt)
        if not settingsCommon.enable.frost then return end
        callSecondaryEffect(settingsFrost, magnitude, dt)
    end,
    [core.magic.EFFECT_TYPE.ShockDamage] = function(magnitude, dt)
        if not settingsCommon.enable.shock then return end
        callSecondaryEffect(settingsShock, magnitude, dt)
    end,
    [core.magic.EFFECT_TYPE.Poison] = function(magnitude, dt)
        if not settingsCommon.enable.poison then return end
        callSecondaryEffect(settingsPoison, magnitude, dt)
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
            if effect == core.magic.EFFECT_TYPE.FrostDamage and frostSpeedDamageApplied > 0 then -- TODO
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
