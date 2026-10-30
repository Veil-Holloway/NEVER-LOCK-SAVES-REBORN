"""Optional Python test host. Requires Lupa with its Lua 5.3 module."""
import sys
from lupa.lua53 import LuaRuntime

runtime=LuaRuntime(unpack_returned_tuples=True)
arguments=runtime.table()
for index,value in enumerate(sys.argv[1:]):arguments[index]=value.replace('\\','/')
runtime.globals().arg=arguments
try:
    runtime.execute('dofile(arg[0])')
except Exception as exc:
    print(exc,file=sys.stderr)
    sys.exit(1)
