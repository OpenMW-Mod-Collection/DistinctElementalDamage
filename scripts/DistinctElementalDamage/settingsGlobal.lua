---@omw-context global
local I = require('openmw.interfaces')

local SettingsPresets = require('scripts.DistinctElementalDamage.utils.presetManager')
local Shared = require("scripts.DistinctElementalDamage.shared")

local presets = SettingsPresets.register {
    selector = {
        section  = 'SettingsDistinctElementalDamage_common',
        key      = 'presets',
        isGlobal = true,
    },
    sections = {
        SettingsDistinctElementalDamage_fire   = { isGlobal = true },
        SettingsDistinctElementalDamage_frost  = { isGlobal = true },
        SettingsDistinctElementalDamage_shock  = { isGlobal = true },
        SettingsDistinctElementalDamage_poison = { isGlobal = true },
    },
    presets = {
        Default = {
            SettingsDistinctElementalDamage_fire   = { secondaryEffect = Shared.secondaryEffects.physicalWeakness, magnitudeScale = 0.02 },
            SettingsDistinctElementalDamage_frost  = { secondaryEffect = Shared.secondaryEffects.drainSpeed, magnitudeScale = 1 },
            SettingsDistinctElementalDamage_shock  = { secondaryEffect = Shared.secondaryEffects.damageMagicka, magnitudeScale = 0.75 },
            SettingsDistinctElementalDamage_poison = { secondaryEffect = Shared.secondaryEffects.damageHealth, magnitudeScale = 0.5 },
        },
        Natural = {
            SettingsDistinctElementalDamage_fire   = { secondaryEffect = Shared.secondaryEffects.damageHealth, magnitudeScale = 0.5 },
            SettingsDistinctElementalDamage_frost  = { secondaryEffect = Shared.secondaryEffects.damageFatigue, magnitudeScale = 3 },
            SettingsDistinctElementalDamage_shock  = { secondaryEffect = Shared.secondaryEffects.damageMagicka, magnitudeScale = 0.75 },
            SettingsDistinctElementalDamage_poison = { secondaryEffect = Shared.secondaryEffects.physicalWeakness, magnitudeScale = 0.04 },
        },
    },
}

I.Settings.registerGroup {
    key = 'SettingsDistinctElementalDamage_common',
    page = 'DistinctElementalDamage',
    l10n = 'DistinctElementalDamage',
    name = 'common_groupName',
    permanentStorage = true,
    order = 0,
    settings = {
        {
            key = 'enable',
            name = 'enable_name',
            renderer = 'multiCheckbox',
            default = {
                fire = true,
                frost = true,
                shock = true,
                poison = true,
            },
            argument = {
                l10n = 'DistinctElementalDamage',
                keys = {
                    'fire',
                    'frost',
                    'shock',
                    'poison',
                },
                colorful = true,
            },
        },
        {
            key = "presets",
            name = "presets_name",
            description = "presets_desc",
            renderer = "SuperSelect3",
            default = "Default",
            argument = {
                items = presets.names(),
                width = 100,
            },
        },
        {
            key = 'log',
            name = 'log_name',
            renderer = "checkbox",
            default = false,
        },
    }
}


local secondaryEffectsList = {
    Shared.secondaryEffects.physicalWeakness,
    Shared.secondaryEffects.drainSpeed,
    Shared.secondaryEffects.damageHealth,
    Shared.secondaryEffects.damageMagicka,
    Shared.secondaryEffects.damageFatigue,
}
local function newElementSection(effectName, order, secondaryEffect, magnitudeScale)
    I.Settings.registerGroup {
        key = 'SettingsDistinctElementalDamage_' .. effectName,
        page = 'DistinctElementalDamage',
        l10n = 'DistinctElementalDamage',
        name = effectName .. '_groupName',
        permanentStorage = true,
        order = 10 + order,
        settings = {
            {
                key = "secondaryEffect",
                name = "secondaryEffect_name",
                renderer = "SuperSelect3",
                default = secondaryEffect,
                argument = {
                    items = secondaryEffectsList,
                    width = 175,
                },
            },
            {
                key = 'magnitudeScale',
                name = 'magnitudeScale_name',
                description = 'magnitudeScale_desc',
                renderer = "number",
                default = magnitudeScale,
            },
        }
    }
end

newElementSection("fire", 1, "Physical Weakness", 0.02)
newElementSection("frost", 2, "Drain Speed", 1)
newElementSection("shock", 3, "Damage Magicka", 0.75)
newElementSection("poison", 4, "Damage Health", 0.5)
