-- Native Settings is a view over the same settings/actions as the CET overlay.
-- No game calls, file IO, queue state or second configuration owner lives here.
local M = {}
function M.new(catalog, read, change, log)
  local self = {api=nil, handles={}, syncing=false, registered=false, numericKinds={}, status='Native Settings UI not detected'}
  function self:sync()
    if not self.api or self.syncing then return end
    self.syncing = true
    local readOK, values = pcall(read)
    if not readOK or type(values) ~= 'table' then
      self.syncing=false;self.status='Native Settings read failed; runtime unchanged';return
    end
    for _, option in ipairs(catalog.options) do
      local value = values[option.key]
      if option.kind == 'enum' then value = value + 1 end
      if self.numericKinds[option.key] == 'selector' then value = value - option.min + 1 end
      local handle = self.handles[option.key]
      if handle then
        local ok, err = pcall(self.api.setOption, handle, value)
        if not ok then log('Native option sync failed ('..option.key..'): '..tostring(err)) end
      end
    end
    self.syncing = false
  end
  function self:register(getMod)
    if self.registered or type(getMod) ~= 'function' then return end
    local found, api = pcall(getMod, 'nativeSettings')
    if not found or not api then return end
    -- Register once per Lua lifetime; never append duplicate controls on repeated onInit.
    self.registered = true
    self.syncing = true
    local ok, err = pcall(function()
      self.api = api
      api.addTab('/nlsreborn', 'Never Lock Saves: Reborn')
      for _, section in ipairs(catalog.sections) do
        api.addSubcategory('/nlsreborn/'..section.id, section.label)
      end
      local values = read()
      for _, descriptor in ipairs(catalog.options) do
        local option = descriptor
        local path = '/nlsreborn/'..option.section
        local function update(value)
          if self.syncing or self.failed then return end
          if option.kind == 'enum' then
            if type(value) ~= 'number' then return end
            value = value - 1
          elseif self.numericKinds[option.key] == 'selector' then
            if type(value) ~= 'number' then return end
            value = value + option.min - 1
          end
          if catalog.valid(option.key, value) then change(option.key, value) end
        end
        if option.kind == 'bool' then
          self.handles[option.key] = api.addSwitch(path,option.label,option.help,values[option.key],option.default,update)
        elseif option.kind == 'enum' then
          self.handles[option.key] = api.addSelectorString(path,option.label,option.help,option.choices,values[option.key]+1,option.default+1,update)
        elseif type(api.addRangeInt) == 'function' then
          self.numericKinds[option.key] = 'range'
          self.handles[option.key] = api.addRangeInt(path,option.label,option.help,option.min,option.max,1,values[option.key],option.default,update)
        else
          -- Older/minimal integrations retain the documented selector convention.
          self.numericKinds[option.key] = 'selector'
          local labels = {}
          for value = option.min, option.max do labels[#labels+1] = tostring(value) end
          self.handles[option.key] = api.addSelectorString(path,option.label,option.help,labels,values[option.key]-option.min+1,option.default-option.min+1,update)
        end
        assert(self.handles[option.key] ~= nil and self.handles[option.key] ~= false, 'Native Settings did not return a handle for '..option.key)
      end
      self.status = 'Native Settings UI connected'
    end)
    self.syncing = false
    if not ok then
      self.failed = true
      self.status = 'Native Settings UI setup failed; restart after checking the dependency: '..tostring(err)
      self.api = nil
      self.handles = {}
      log(self.status)
    end
  end
  return self
end
return M
