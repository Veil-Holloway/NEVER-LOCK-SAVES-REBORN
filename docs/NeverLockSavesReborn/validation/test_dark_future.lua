-- Execute the real adapter; only the external game/CET boundary is replaced.
local root = arg[1] or 'work/release'
local path = root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/dark_future.lua'
local adapter = assert(loadfile(path))()
local count = 0
local player = {}
local calls = 0
local service
Game = {GetScriptableSystemsContainer = function()
  return {Get = function(_, name)
    assert(name == 'DarkFuture.Services.DFGameStateService', 'wrong RTTI name')
    return service
  end}
end}
local function check(name, test)
  local ok, err = pcall(test)
  assert(ok, name..': '..tostring(err))
  count = count + 1
  print('PASS: '..name)
end
local function makeService(state, enabled)
  return {
    state = {value = state or 'Running'}, Settings = {mainSystemEnabled = enabled ~= false}, player = player,
    IsValidGameState = function(_, caller, ignoreTemporary, allowLimited)
      calls = calls + 1
      assert(caller == player and ignoreTemporary == false and allowLimited == false)
      return true
    end,
    GetSleepingInVehicle = function() return false end,
    IsInAnyMenu = function() return false end
  }
end
check('no player never queries the game', function()
  local previous = Game
  Game = nil
  assert(adapter.sample(nil).status:find('WAITING', 1, true))
  Game = previous
end)
check('missing Dark Future is explicitly not detected', function()
  service = nil
  local s = adapter.sample(player)
  assert(s.status:find('NOT DETECTED', 1, true) and s.valid == nil)
end)
check('lookup exception becomes UNKNOWN', function()
  local previous = Game
  Game = {GetScriptableSystemsContainer = function() error('lookup fault') end}
  local s = adapter.sample(player)
  assert(s.status:find('UNKNOWN', 1, true) and s.error:find('lookup fault', 1, true))
  Game = previous
end)
check('running service returns strict read-only gameplay snapshot', function()
  service = makeService()
  local s = adapter.sample(player)
  assert(s.valid == true and s.sleepingInVehicle == false and s.inMenu == false)
  assert(s.enabled == true and s.lifecycle == 'Running')
end)
check('invalid gameplay remains information, never a save permission', function()
  service = makeService()
  service.IsValidGameState = function() return false end
  local s = adapter.sample(player)
  assert(s.valid == false and s.status:find('READABLE', 1, true))
  assert(s.allowSave == nil and s.blockSave == nil)
end)
check('vehicle sleep and menu state are preserved without coercion', function()
  service = makeService()
  service.GetSleepingInVehicle = function() return true end
  service.IsInAnyMenu = function() return true end
  local s = adapter.sample(player)
  assert(s.sleepingInVehicle == true and s.inMenu == true)
end)
check('disabled mod is not reported as running gameplay', function()
  service = makeService('Running', false)
  local before = calls
  local s = adapter.sample(player)
  assert(s.enabled == false and s.valid == nil and calls == before)
end)
for _, state in ipairs({'Uninitialized', 'Suspended'}) do
  check(state..' service is not queried for gameplay', function()
    service = makeService(state)
    local before = calls
    local s = adapter.sample(player)
    assert(s.status:find('WAITING', 1, true) and s.valid == nil and calls == before)
  end)
end
check('unknown lifecycle is not assumed Running', function()
  service = makeService('FutureState')
  local before = calls
  local s = adapter.sample(player)
  assert(s.status:find('UNKNOWN', 1, true) and calls == before)
end)
check('missing player attachment defers gameplay query', function()
  service = makeService()
  service.player = nil
  local before = calls
  local s = adapter.sample(player)
  assert(s.status:find('WAITING', 1, true) and s.valid == nil and calls == before)
end)
check('stale player attachment defers gameplay query', function()
  service = makeService()
  service.player = {}
  local before = calls
  local s = adapter.sample(player)
  assert(s.status:find('WAITING', 1, true) and s.valid == nil and calls == before)
end)
check('uninitialized settings defer gameplay query', function()
  service = makeService()
  service.Settings = nil
  local before = calls
  local s = adapter.sample(player)
  assert(s.status:find('WAITING', 1, true) and calls == before)
end)
check('lifecycle getter fault is contained', function()
  service = setmetatable({}, {__index = function() error('lifecycle fault') end})
  local s = adapter.sample(player)
  assert(s.status:find('UNKNOWN', 1, true) and s.error:find('lifecycle fault', 1, true))
end)
check('non-boolean master switch defers gameplay query', function()
  service = makeService()
  service.Settings.mainSystemEnabled = 'true'
  local before = calls
  local s = adapter.sample(player)
  assert(s.status:find('WAITING', 1, true) and calls == before)
end)
check('missing verified getter becomes UNKNOWN', function()
  service = makeService()
  service.GetSleepingInVehicle = nil
  local s = adapter.sample(player)
  assert(s.status:find('UNKNOWN', 1, true) and s.valid == nil)
end)
check('unexpected getter types remain UNKNOWN', function()
  service = makeService()
  service.IsInAnyMenu = function() return 0 end
  local s = adapter.sample(player)
  assert(s.status:find('UNKNOWN', 1, true) and s.inMenu == nil)
end)
check('session reload resolves fresh services and clears old state', function()
  service = makeService()
  assert(adapter.sample(player).valid == true)
  service = nil
  local s = adapter.sample(player)
  assert(s.valid == nil and s.enabled == nil and s.lifecycle == nil)
end)
check('diagnostics distinguish false from UNKNOWN', function()
  local s = adapter.describe({status = 'TEST', enabled = false, valid = false})
  assert(s:find('enabled=false', 1, true) and s:find('gameplayValid=false', 1, true))
  assert(s:find('sleepingInVehicle=UNKNOWN', 1, true))
end)
check('adapter does not mutate any external service property', function()
  local reads = makeService()
  service = setmetatable({}, {
    __index = reads,
    __newindex = function() error('unexpected write to Dark Future') end
  })
  assert(adapter.sample(player).valid == true)
end)
print('RESULT: '..count..' adapter boundary tests passed; no game runtime exercised')
