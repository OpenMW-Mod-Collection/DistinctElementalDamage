---@omw-context global
local I = require('openmw.interfaces')

local secondaryEffectsList = {
    "Physical Weakness",
    "Drain Speed",
    "Damage Health",
    "Damage Magicka",
    "Damage Fatigue",
}
local secondaryEffectsTable = {
    ["Physical Weakness"] = "Physical Weakness",
    ["Drain Speed"]       = "Drain Speed",
    ["Damage Health"]     = "Damage Health",
    ["Damage Magicka"]    = "Damage Magicka",
    ["Damage Fatigue"]    = "Damage Fatigue",
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
                items = {
                    "Default",
                    "Natural",
                    "Custom"
                },
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

newElementSection("fire", 1, secondaryEffectsTable["Physical Weakness"], 0.02)
newElementSection("frost", 2, secondaryEffectsTable["Drain Speed"], 1)
newElementSection("shock", 3, secondaryEffectsTable["Damage Magicka"], 0.75)
newElementSection("poison", 4, secondaryEffectsTable["Damage Health"], 0.5)
