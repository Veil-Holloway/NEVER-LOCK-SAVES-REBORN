-- CET presentation only. The coordinator supplies snapshots and named actions.
-- This module must never call Game, register hooks, write files or own save state.
local M = {}
local tabs = {'Overview','Saving','Autosave','Messages','Presets','Diagnostics'}
local function text(ui, label, value)
  ui.TextWrapped(label..': '..tostring(value == nil and 'Unknown' or value))
end
local function heading(ui, label)
  ui.Separator()
  ui.Text(label)
end
local function group(ui, label, draw)
  if type(ui.CollapsingHeader) ~= 'function' or ui.CollapsingHeader(label) then draw() end
end
function M.new(catalog, actions)
  local self = {showHelp=false, error=nil, drafts={}}
  local function control(ui, view, key)
    local option = assert(catalog.get(key), 'unknown UI option')
    local current = view.settings[key]
    local id = '##nls_setting_'..key
    if option.kind == 'bool' and type(ui.Checkbox) == 'function' then
      local value, changed = ui.Checkbox(option.label..id, current)
      if changed and catalog.valid(key,value) then actions.change(key,value) end
    elseif option.kind == 'int' and type(ui.SliderInt) == 'function' then
      local draft = self.drafts[key]
      -- A Native Settings/preset change invalidates a stale overlay edit.
      if draft and draft.base ~= current then self.drafts[key]=nil;draft=nil end
      local value,changed = ui.SliderInt(option.label..id,draft and draft.value or current,option.min,option.max)
      if changed and catalog.valid(key,value) then
        draft={base=current,value=value};self.drafts[key]=draft
      end
      local commit=type(ui.IsItemDeactivatedAfterEdit)=='function' and ui.IsItemDeactivatedAfterEdit()
      if draft then
        if commit or ui.Button('Apply##nls_apply_'..key) then
          actions.change(key,draft.value);self.drafts[key]=nil
        elseif ui.Button('Discard edit##nls_discard_'..key) then self.drafts[key]=nil end
      end
    elseif option.kind == 'enum' then
      ui.Text(option.label)
      for index, label in ipairs(option.choices) do
        if ui.RadioButton(label..id..'_'..index, current == index-1) then actions.change(key,index-1) end
      end
    elseif option.kind == 'bool' then
      if ui.Button(option.label..': '..(current and 'ON' or 'OFF')..id) then actions.change(key,not current) end
    else
      -- No unknown widget call on reduced/older ImGui bindings.
      text(ui,option.label,current)
      ui.TextWrapped('Edit this numeric setting through Native Settings; SliderInt is unavailable.')
    end
    if self.showHelp then ui.TextWrapped(option.help) end
  end
  local function controls(ui,view,section)
    for _,option in ipairs(catalog.options) do
      if option.section == section then control(ui,view,option.key) end
    end
  end
  local function queue(ui,view,suffix)
    text(ui,'Queue',view.queueStatus)
    text(ui,'Waiting for',view.queueGate)
    if view.queuePending then
      text(ui,'Retention',view.queueRetention=='session' and 'No expiry (current session)' or view.queueRemaining..' seconds')
      if ui.Button('Cancel queued request##nls_cancel_'..suffix) then actions.cancel() end
    end
  end
  local pages = {}
  pages.Overview = function(ui,view)
    text(ui,'Mode',catalog.modeNames[view.settings.mode+1])
    text(ui,'Runtime bridge',view.bridge)
    text(ui,'Introduction',view.intro)
    heading(ui,'Current request')
    queue(ui,view,'overview')
    text(ui,'Last request outcome',view.queueLastOutcomeState..' | '..view.queueLastOutcome)
    text(ui,'Last queue event',view.queueEvent)
    heading(ui,'Services')
    text(ui,'Smart Autosave',view.autosave)
    text(ui,'Dark Future',view.darkFuture)
    text(ui,'Native Settings',view.nativeStatus)
    ui.TextWrapped('Queued is not saved. A submitted checkpoint still needs independent save-file, reload and progression evidence.')
  end
  pages.Saving = function(ui,view)
    controls(ui,view,'save')
    ui.TextWrapped('Player requests wait for combat to end and native saving permission to return. You do not need to exit the vehicle.')
    ui.TextWrapped('Vanilla retains the original save path. Deferred Save must be enabled for Reborn to keep a blocked player request; there is no combat-lock bypass when it is off.')
    ui.TextWrapped('Unrestricted is a retained preset name. It no longer means permission to ignore native locks.')
    heading(ui,'Queue status')
    queue(ui,view,'saving')
    ui.TextWrapped('Player requests have no expiry. Combat events wake eligibility checks, with a one-second native-lock fallback and a short stabilization window. Automatic/test expiry affects only new automatic and dry-run requests. Cancellation never claims an in-flight save was undone.')
  end
  pages.Autosave = function(ui,view)
    controls(ui,view,'autosave')
    text(ui,'Scheduler',view.autosave)
    text(ui,'Quest observer',view.questObserver)
    ui.TextWrapped('These are optional automatic triggers, not the player-requested combat queue. The existing automatic scheduler still requires its stricter on-foot readiness checks.')
    ui.TextWrapped('Player requests have priority. Native autosave slots remain game-managed; the mod does not prove a save completed.')
  end
  pages.Messages = function(ui,view)
    controls(ui,view,'notifications')
    text(ui,'Queue message channel',view.statusRuntime)
    heading(ui,'Dark Future context messages')
    controls(ui,view,'immersion')
    text(ui,'Detected context',view.darkFuture)
    ui.TextWrapped('All four Dark Future switches change messages only. Survival mechanics, all contexts use neutral wording.')
  end
  pages.Presets = function(ui,view)
    ui.TextWrapped('Named settings presets are selected manually and apply only when you choose them.')
    if type(ui.InputText) == 'function' then
      local value,changed = ui.InputText('Preset name##nls_profile_name',view.profileLabel,33)
      if changed and type(value) == 'string' then actions.setProfileLabel(value:sub(1,32)) end
    end
    if ui.Button('Save current preset##nls_profile_save') then actions.saveProfile() end
    if ui.Button('Load named preset##nls_profile_load') then actions.loadProfile() end
    if ui.Button('Refresh preset list##nls_profile_refresh') then actions.refreshProfiles() end
    text(ui,'Preset',view.profileStatus)
    group(ui,'Saved presets##nls_saved_presets',function()
      for index=1,16 do
        local label = view.profileLabels[index]
        if type(label) == 'string' and ui.Button('Load '..label..'##nls_profile_'..index) then actions.loadProfile(label) end
      end
    end)
    ui.TextWrapped('Loading a preset cancels pending work only after the validated configuration is written successfully.')
  end
  pages.Diagnostics = function(ui,view)
    controls(ui,view,'diagnostics')
    if ui.Button('Export support report##nls_support_export') then actions.exportSupport() end
    text(ui,'Support report',view.reportStatus)
    if ui.Button('Retry bridge##nls_bridge_retry') then actions.retryBridge() end
    text(ui,'Bridge',view.bridge)
    group(ui,'Queue test (no save)##nls_queue_test',function()
      ui.TextWrapped('This is a dry run. It never creates a checkpoint and cannot replace a pending real request.')
      if view.settings.deferredEnabled then
        if ui.Button('Queue dry-run test##nls_queue') then actions.preview() end
      else ui.TextWrapped('Enable Deferred Save in Saving before running the dry-run test.') end
      queue(ui,view,'diagnostics')
    end)
    group(ui,'Save Guardian ledger##nls_guardian_details',function()
      local guardian = actions.guardianDetails()
      text(ui,'Guardian',guardian.status)
      text(ui,'Observers',guardian.observers)
      text(ui,'Summary',guardian.summary)
      for _,row in ipairs(guardian.rows or {}) do ui.TextWrapped(row) end
      if guardian.available and ui.Button('Export Guardian report##nls_guardian_export') then actions.exportGuardian() end
      ui.TextWrapped('Written and reloaded remain unknown without independently correlated evidence. This ledger is not a live save backup.')
    end)
    if view.settings.diagnosticDetails then
      group(ui,'Advanced bridge and context##nls_advanced_details',function()
        local details = actions.diagnostics()
        for _,row in ipairs(details) do text(ui,row[1],row[2]) end
        if ui.Button('Log compatibility snapshot##nls_darkfuture') then actions.logSnapshot() end
      end)
    end
    ui.TextWrapped('Exports stay local. Review reports before sharing. No saves or logs are uploaded by these controls.')
  end
  function self:draw(ui,view)
    if type(ui.SetNextWindowSize) == 'function' and ImGuiCond and ImGuiCond.FirstUseEver then
      ui.SetNextWindowSize(760,620,ImGuiCond.FirstUseEver)
    end
    local visible = ui.Begin(view.title)
    -- Always close a begun window, including collapsed/error frames.
    local ok,err = pcall(function()
      if not visible then return end
      ui.Text(view.version..' | Stable')
      text(ui,'Configuration',view.configStatus)
      if type(ui.Checkbox) == 'function' then
        local value,changed = ui.Checkbox('Show setting explanations##nls_help',self.showHelp)
        if changed then self.showHelp = value end
      end
      if type(ui.BeginTabBar) == 'function' and type(ui.BeginTabItem) == 'function' and
          type(ui.EndTabBar) == 'function' and type(ui.EndTabItem) == 'function' then
        if ui.BeginTabBar('nls_sections') then
          local tabsOK,tabsError = pcall(function()
            for _,name in ipairs(tabs) do
              if ui.BeginTabItem(name) then
                local pageOK,pageError = pcall(pages[name],ui,view)
                ui.EndTabItem()
                if not pageOK then error(pageError) end
              end
            end
          end)
          ui.EndTabBar()
          if not tabsOK then error(tabsError) end
        end
      else
        -- Same grouped contents on reduced bindings; no unverified tab API call.
        for _,name in ipairs(tabs) do group(ui,name..'##nls_section',function() pages[name](ui,view) end) end
      end
    end)
    if not ok then
      ui.TextWrapped('This panel could not finish drawing. Runtime save policy is unchanged; see the Reborn log.')
      if self.error ~= tostring(err) then self.error=tostring(err);actions.uiError(self.error) end
    else self.error=nil end
    ui.End()
  end
  return self
end
return M
