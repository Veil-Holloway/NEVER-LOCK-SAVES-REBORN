-- Shared presentation metadata. Persisted values and game policy remain in init.lua.
-- Native option identifiers and all configuration keys retain their existing meanings.
local M = {}
M.modeNames = {'Vanilla', 'Immersion', 'Unrestricted', 'Smart'}
M.sections = {
  {id='save', label='Saving'}, {id='autosave', label='Smart Autosave'},
  {id='notifications', label='Notifications'}, {id='immersion', label='Dark Future'},
  {id='diagnostics', label='Diagnostics'}
}
M.options = {
  {key='mode', nativeId='mode', section='save', label='Save Mode', kind='enum', default=1,
    choices=M.modeNames, help='Vanilla uses the original save path. Reborn modes respect combat and native locks; Unrestricted is a retained legacy name, not a lock bypass.'},
  {key='deferredEnabled', nativeId='deferred', section='save', label='Deferred Save', kind='bool', default=false,
    help='Remember one blocked player request for this session without expiry. Combat changes wake a live readiness check; native restrictions remain authoritative. Remaining inside a vehicle is allowed.'},
  {key='deferredTTL', nativeId='deferredTTL', section='save', label='Automatic / test expiry (seconds)', kind='int', min=1, max=120, default=30,
    help='Applies only to automatic requests and dry-run tests. Player save requests have no expiry and wait until cancelled or their session ends. Existing saved values are retained.'},
  {key='deferredCooldownSeconds', nativeId='deferredCooldownSeconds', section='save', label='Queue dispatch cooldown (seconds)', kind='int', min=0, max=600, default=0,
    help='Minimum spacing between queued checkpoint submissions. A two-second stable eligibility window is also required.'},
  {key='autosaveEnabled', nativeId='autosave', section='autosave', label='Smart Autosave', kind='bool', default=false,
    help='Optional automatic requests, separate from Deferred Save. Native autosaves are unchanged. Turn this off to test only player-requested queuing.'},
  {key='autosaveExploration', nativeId='autosaveExploration', section='autosave', label='Exploration interval', kind='bool', default=true,
    help='Request a checkpoint after the selected interval of eligible exploration. Missed time is not replayed after a pause or load.'},
  {key='autosavePostCombat', nativeId='autosavePostCombat', section='autosave', label='After combat', kind='bool', default=true,
    help='Automatic trigger for a newly observed combat-end transition. This is distinct from releasing a player-requested combat save.'},
  {key='autosaveVehicleExit', nativeId='autosaveVehicleExit', section='autosave', label='After vehicle exit', kind='bool', default=true,
    help='Optional automatic trigger on exiting a vehicle. This switch does not require player-requested queued saves to wait for vehicle exit.'},
  {key='autosaveQuestMilestone', nativeId='autosaveQuestMilestone', section='autosave', label='Verified quest milestone', kind='bool', default=false,
    help='Use supported journal-completion observations. A journal event is not proof that every quest transition has settled.'},
  {key='autosaveApartmentEntry', nativeId='autosaveApartmentEntry', section='autosave', label="V's original apartment area entry", kind='bool', default=false,
    help='Original Little China apartment area only, not every safehouse or owned apartment.'},
  {key='autosaveIntervalSeconds', nativeId='autosaveIntervalSeconds', section='autosave', label='Autosave interval (seconds)', kind='int', min=60, max=1800, default=300,
    help='Eligible exploration time between interval requests. Saving still depends on all readiness checks.'},
  {key='autosaveCooldownSeconds', nativeId='autosaveCooldownSeconds', section='autosave', label='Autosave cooldown (seconds)', kind='int', min=30, max=600, default=60,
    help='Minimum spacing between accepted automatic queue requests.'},
  {key='notificationsEnabled', nativeId='notifications', section='notifications', label='Enable notifications', kind='bool', default=true,
    help='Master switch for Reborn request messages. A message never grants save permission or confirms a file write.'},
  {key='statusNotificationsEnabled', nativeId='statusNotifications', section='notifications', label='Queue status notifications', kind='bool', default=false,
    help='Optional queued, submitted, expired, cancelled and error messages. Submitted does not mean written or successfully reloaded.'},
  {key='dfNotifyVehicleSleep', nativeId='dfNotifyVehicleSleep', section='immersion', label='Notify: vehicle sleep', kind='bool', default=true,
    help='Read-only Dark Future vehicle-sleep context. Changes messages only; never overrides native saving restrictions.'},
  {key='dfNotifyAddiction', nativeId='dfNotifyAddiction', section='immersion', label='Notify: addiction', kind='bool', default=true,
    help='Read-only enabled addiction-stage context. This switch does not change survival mechanics or save permission.'},
  {key='dfNotifyStarvation', nativeId='dfNotifyStarvation', section='immersion', label='Notify: starvation', kind='bool', default=true,
    help='Read-only Dark Future nutrition stage 4 context. Changes messages only.'},
  {key='dfNotifyDehydration', nativeId='dfNotifyDehydration', section='immersion', label='Notify: dehydration', kind='bool', default=true,
    help='Read-only Dark Future hydration stage 4 context. Changes messages only.'},
  {key='guardianEnabled', nativeId='guardian', section='diagnostics', label='Save Guardian request ledger', kind='bool', default=false,
    help='Optional bounded request tracking. Unassociated engine callbacks do not establish a written or reloadable save.'},
  {key='diagnosticDetails', nativeId='diagnostics', section='diagnostics', label='Detailed diagnostics', kind='bool', default=true,
    help='Show advanced bridge, sensor and notification details inside the Diagnostics tab, not on every settings page.'}
}
local byKey = {}
for _, option in ipairs(M.options) do
  assert(not byKey[option.key], 'duplicate UI setting')
  byKey[option.key] = option
end
function M.get(key) return byKey[key] end
function M.valid(key, value)
  local option = byKey[key]
  if not option then return false end
  if option.kind == 'bool' then return type(value) == 'boolean' end
  if type(value) ~= 'number' or value ~= value or value ~= math.floor(value) then return false end
  if option.kind == 'enum' then return value >= 0 and value < #option.choices end
  return value >= option.min and value <= option.max
end
return M
