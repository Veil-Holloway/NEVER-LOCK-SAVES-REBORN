"""One explicit Lua command for parent and nested offline checks."""
import json
import os
import shutil

def lua_command():
    value=os.environ.get('NLSR_LUA_COMMAND')
    if value:
        command=json.loads(value)
        if not isinstance(command,list) or not command or not all(isinstance(x,str) and x for x in command):
            raise ValueError('NLSR_LUA_COMMAND must be a nonempty JSON string array')
        return command
    for name in ('texlua','lua5.3','lua53','lua'):
        executable=shutil.which(name)
        if executable:return [executable]
    raise RuntimeError('Lua test host missing; use the release runner --lua or --lupa option')
