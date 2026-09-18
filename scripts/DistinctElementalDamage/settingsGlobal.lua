---@omw-context global
local I = require('openmw.interfaces')

I.Settings.registerGroup {
    key = 'SettingsDistinctElementalDamage',
    page = 'DistinctElementalDamage',
    l10n = 'DistinctElementalDamage',
    name = 'settings_groupName',
    description = 'settings_groupDesc',
    permanentStorage = true,
    order = 1,
    settings = {
        {
            key = 'fireEffectiveness',
            name = 'fireEffectiveness_name',
            description = 'fireEffectiveness_desc',
            renderer = "number",
            default = 0.02,
        },
        {
            key = 'frostEffectiveness',
            name = 'frostEffectiveness_name',
            description = 'frostEffectiveness_desc',
            renderer = "number",
            default = 1,
        },
        {
            key = 'shockEffectiveness',
            name = 'shockEffectiveness_name',
            description = 'shockEffectiveness_desc',
            renderer = "number",
            default = 0.75,
        },
        {
            key = 'poisonEffectiveness',
            name = 'poisonEffectiveness_name',
            description = 'poisonEffectiveness_desc',
            renderer = "number",
            default = 0.5,
        },
        {
            key = 'log',
            name = 'log_name',
            renderer = "checkbox",
            default = false,
        },
    }
}