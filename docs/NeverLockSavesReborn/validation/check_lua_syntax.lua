-- Compile only: never execute the mod or access the game's settings/save files.
local root=assert(arg[1], 'release root required')
local base=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
for _,name in ipairs({'init.lua','config_store.lua','deferred_save.lua','dark_future.lua','guardian.lua','guardian_bridge.lua','autosave_policy.lua','profiles.lua','support_report.lua','quest_milestones.lua','status_messages.lua','status_message_library.lua','dependency_versions.lua'}) do
  assert(loadfile(base..name))
end
print('PASS syntax: thirteen Lua files; interpreter '.._VERSION..'. This is not CET/LuaJIT validation.')
