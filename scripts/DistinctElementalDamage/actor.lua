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

local SettingsCache = require("scripts.DistinctElementalDamage.utils.settingsCache")
local Shared = require("scripts.DistinctElementalDamage.shared")

local recalculateAllEffects
local settingsCommon = SettingsCache.new(
    storage.globalSection("SettingsDistinctElementalDamage_common"),
    async,
    recalculateAllEffects
)
local function newEffectSettings(effect)
    return SettingsCache.new(
        storage.globalSection("SettingsDistinctElementalDamage_" .. effect),
        async,
        recalculateAllEffects
    )
end
local settingsByEffect = {
    [core.magic.EFFECT_TYPE.FireDamage] = newEffectSettings("fire"),
    [core.magic.EFFECT_TYPE.FrostDamage] = newEffectSettings("frost"),
    [core.magic.EFFECT_TYPE.ShockDamage] = newEffectSettings("shock"),
    [core.magic.EFFECT_TYPE.Poison] = newEffectSettings("poison"),
}

local selfEffects = self.type.activeEffects(self)
local selfMagicka = self.type.stats.dynamic.magicka(self)
local selfHealth = self.type.stats.dynamic.health(self)
local selfFatigue = self.type.stats.dynamic.fatigue(self)
local selfSpeed = self.type.stats.attributes.speed(self)

local physicalWeaknessMult = {}
local drainSpeedApplied = {}
local totalPhysicalWeakness = 1
local drainSpeedTotalApplied = 0

local activeElementalEffects = {}
local elementalEffectsActive = true -- setting it to true so that the first update will check for active effects

local function log(msg, ...)
    if settingsCommon.log then
        print(msg:format(...))
    end
end

local function damageStat(magnitude, dt, stat, statLogPrefix)
    local damagedStat = stat.current - magnitude * dt
    stat.current = math.max(damagedStat, 0)
    log(statLogPrefix .. " %s: magnitude=%.2f current=%.2f", self.recordId, magnitude, stat.current)
end

local function recomputePhysicalWeakness()
    local total = 1
    for _, mult in pairs(physicalWeaknessMult) do
        total = total + mult
    end
    totalPhysicalWeakness = total
    log("PhysicalWeakness %s: totalPhysicalWeakness=%.3f", self.recordId, totalPhysicalWeakness)
end

local function recomputeDrainSpeed()
    local total = 0
    for _, dmg in pairs(drainSpeedApplied) do
        total = total + dmg
    end
    local delta = total - drainSpeedTotalApplied
    selfSpeed.damage = math.max(selfSpeed.damage + delta, 0)
    drainSpeedTotalApplied = total
    log("DrainSpeed %s: delta=%.2f speed.damage=%.2f", self.recordId, delta, selfSpeed.damage)
end

recalculateAllEffects = function()
    physicalWeaknessMult = {}
    drainSpeedApplied = {}
    local delta = 0 - drainSpeedTotalApplied
    selfSpeed.damage = math.max(selfSpeed.damage + delta, 0)
    drainSpeedTotalApplied = 0

    recomputePhysicalWeakness()

    activeElementalEffects = {}
    elementalEffectsActive = true
    log("recalculateAllEffects %s: all secondary effect state reset", self.recordId)
end


local function clearSecondaryEffectContribution(sourceEffect)
    local settings = settingsByEffect[sourceEffect]
    if settings.secondaryEffect == "Physical Weakness" then
        if physicalWeaknessMult[sourceEffect] then
            physicalWeaknessMult[sourceEffect] = nil
            recomputePhysicalWeakness()
        end
    elseif settings.secondaryEffect == "Drain Speed" then
        if drainSpeedApplied[sourceEffect] then
            drainSpeedApplied[sourceEffect] = nil
            recomputeDrainSpeed()
        end
    end
end

---@type table<string, function>
local secondaryEffects = {
    [Shared.secondaryEffects.physicalWeakness] = function(sourceEffect, magnitude, dt)
        physicalWeaknessMult[sourceEffect] = magnitude
        recomputePhysicalWeakness()
    end,
    [Shared.secondaryEffects.drainSpeed] = function(sourceEffect, magnitude, dt)
        drainSpeedApplied[sourceEffect] = magnitude
        recomputeDrainSpeed()
    end,
    [Shared.secondaryEffects.damageHealth] = function(sourceEffect, magnitude, dt)
        damageStat(magnitude, dt, selfHealth, "DamageHealth")
    end,
    [Shared.secondaryEffects.damageMagicka] = function(sourceEffect, magnitude, dt)
        damageStat(magnitude, dt, selfMagicka, "DamageMagicka")
    end,
    [Shared.secondaryEffects.damageFatigue] = function(sourceEffect, magnitude, dt)
        damageStat(magnitude, dt, selfFatigue, "DamageFatigue")
    end,
}

local function callSecondaryEffect(sourceEffect, magnitude, dt)
    local settings = settingsByEffect[sourceEffect]
    local secondaryEffectApplyer = secondaryEffects[settings.secondaryEffect]
    local scaledMagnitude = magnitude * settings.magnitudeScale
    secondaryEffectApplyer(sourceEffect, scaledMagnitude, dt)
end

local elementalEffects = {
    [core.magic.EFFECT_TYPE.FireDamage] = function(magnitude, dt)
        if not settingsCommon.enable.fire then return end
        callSecondaryEffect(core.magic.EFFECT_TYPE.FireDamage, magnitude, dt)
    end,
    [core.magic.EFFECT_TYPE.FrostDamage] = function(magnitude, dt)
        if not settingsCommon.enable.frost then return end
        callSecondaryEffect(core.magic.EFFECT_TYPE.FrostDamage, magnitude, dt)
    end,
    [core.magic.EFFECT_TYPE.ShockDamage] = function(magnitude, dt)
        if not settingsCommon.enable.shock then return end
        callSecondaryEffect(core.magic.EFFECT_TYPE.ShockDamage, magnitude, dt)
    end,
    [core.magic.EFFECT_TYPE.Poison] = function(magnitude, dt)
        if not settingsCommon.enable.poison then return end
        callSecondaryEffect(core.magic.EFFECT_TYPE.Poison, magnitude, dt)
    end,
}

local function checkElementalEffects()
    elementalEffectsActive = false
    for effect, _ in pairs(elementalEffects) do
        local magnitude = selfEffects:getEffect(effect).magnitude
        if magnitude > 0 then
            activeElementalEffects[effect] = magnitude
            elementalEffectsActive = true
        else
            if activeElementalEffects[effect] then
                clearSecondaryEffectContribution(effect)
            end
            activeElementalEffects[effect] = nil
        end
    end
    log("checkElementalEffects %s: elementalEffectsActive=%s", self.recordId, tostring(elementalEffectsActive))
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
    if not attack.successful or not attack.damage.health or totalPhysicalWeakness == 1 then
        return
    end

    local before = attack.damage.health
    attack.damage.health = attack.damage.health * totalPhysicalWeakness
    log("onHit %s: health damage %.2f -> %.2f (totalPhysicalWeakness=%.3f)", self.recordId, before, attack.damage.health, totalPhysicalWeakness)
end)

return {
    engineHandlers = {
        onUpdate = onUpdate,
        onSave = function()
            return {
                drainSpeedApplied = drainSpeedApplied
            }
        end,
        onLoad = function(data)
            data = data or {}
            drainSpeedApplied = data.drainSpeedApplied or drainSpeedApplied
            local total = 0
            for _, dmg in pairs(drainSpeedApplied) do
                total = total + dmg
            end
            drainSpeedTotalApplied = total
        end
    },
    eventHandlers = {
        ApplyMagicEffects = function()
            self:sendEvent("DistinctElementalDamage_delayedCheckEffects")
        end,
        DistinctElementalDamage_delayedCheckEffects = checkElementalEffects
    },
}
