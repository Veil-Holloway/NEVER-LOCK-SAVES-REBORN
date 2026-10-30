assert(#arg>0,'explicit runtime Lua inventory required')
for _,path in ipairs(arg)do assert(loadfile(path))end
print('PASS syntax: '..#arg..' runtime Lua files; '.._VERSION..' compiler host, not CET/LuaJIT')
