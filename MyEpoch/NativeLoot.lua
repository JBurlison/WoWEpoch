local _, E = ...
local F = E.FloatingLoot

function E.FloatingLootView.RegisterSettings(ui, category)
    local function getMinutes()
        return F.Preferences(ui:Character()).minutes
    end
    local function setMinutes(value)
        return F.SetMinutes(ui:Character(), value)
    end
    ui:Check(category, 'floatingLootEnabled', E.L['Show floating loot'], false,
        function() return F.Preferences(ui:Character()).enabled end,
        function(enabled) return F.SetEnabled(ui:Character(), enabled) end)
    ui:Choice(category, 'floatingLootPeriod', E.L['Loot time window'], F.defaultMinutes,
        getMinutes, setMinutes, function()
            local values = {5, 15, 30, 60, 1440}
            local current = getMinutes()
            local options, included = {}, false
            for _, value in ipairs(values) do
                if current == value then included = true end
                options[#options + 1] = {value, F.PeriodLabel(value)}
            end
            if not included then
                options[#options + 1] = {current, F.PeriodLabel(current)}
                table.sort(options, function(a, b) return a[1] < b[1] end)
            end
            return options
        end)
    ui:Slider(category, 'floatingLootMinutes', E.L['Time window in minutes (1–1440)'], F.defaultMinutes,
        getMinutes, setMinutes, 1, 1440, 1, F.PeriodLabel)
end
