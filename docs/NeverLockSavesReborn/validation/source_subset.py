"""Strict bounded REDscript-to-Python evaluator for independent policy checks.

This executes only scalar declarations/calls/if/while/assignments/returns from
the supplied source against external boundary doubles. It is NOT REDscript
compilation, native ABI validation, or game/save evidence.
"""
import re

TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*.*?\*/|&&|\|\||==|!=|<=|>=|\+=|-=|\w+|[^\s]', re.S)

def tokens(text):
    return [m.group() for m in TOKEN.finditer(text) if not m.group().startswith(('//','/*'))]

def body(source, name):
    m = re.search(r'\bfunc\s+' + re.escape(name) + r'\s*\(', source)
    if not m:
        raise ValueError('Missing source function: ' + name)
    start = source.index('{', m.end())
    depth = 0
    for t in TOKEN.finditer(source,start):
        if t.group() == '{': depth += 1
        elif t.group() == '}':
            depth -= 1
            if depth == 0:
                return source[m.start():t.end()]
    raise ValueError('Unclosed source function: ' + name)

def compile_function(source,name,namespace,instance=False):
    fn = body(source,name)
    params=fn[fn.index('(')+1:fn.index(')')]
    args=re.findall(r'(\w+)\s*:',params)
    if instance: args.insert(0,'this')
    output=['def source_'+name+'('+','.join(args)+'):']
    indent=1
    pending=[]
    def expr(parts):
        result=[]
        for i,t in enumerate(parts):
            if t=='as':
                if parts[i+1:] != ['PlayerPuppet']:
                    raise ValueError('Unsupported cast in '+name)
                break
            if t in ('new','switch','case','for','foreach'):
                raise ValueError('Unsupported expression token '+t+' in '+name)
            if t=='n' and i+1<len(parts) and parts[i+1].startswith('"'):
                continue # The name literal is only a key at the doubled boundary.
            result.append({'true':'True','false':'False','!':'not','&&':'and','||':'or'}.get(t,t))
        return ' '.join(result)
    def statement(parts):
        if not parts:return
        if parts[0]=='let':
            if len(parts)<4 or parts[2]!=':':raise ValueError('Unsupported declaration '+name)
            rhs=expr(parts[parts.index('=')+1:]) if '=' in parts else ('[]' if parts[3]=='array' else 'None')
            code=parts[1]+' = '+rhs
        elif parts[0]=='return':code='return '+expr(parts[1:])
        else:code=expr(parts)
        output.append('    '*indent+code)
    content=fn[fn.index('{')+1:fn.rfind('}')]
    for t in tokens(content):
        if t=='{':
            if pending[:1] in (['if'],['while']):header=pending[0]+' '+expr(pending[1:])+':'
            elif pending[:2]==['else','if']:header='elif '+expr(pending[2:])+':'
            elif pending==['else']:header='else:'
            else:raise ValueError('Unsupported block '+repr(pending)+' in '+name)
            output.append('    '*indent+header);pending=[];indent+=1
        elif t=='}':
            statement(pending);pending=[];indent-=1
            if indent<1:raise ValueError('Unbalanced block '+name)
        elif t==';':statement(pending);pending=[]
        else:pending.append(t)
    statement(pending)
    if indent!=1:raise ValueError('Unbalanced function '+name)
    code='\n'.join(output)+'\n'
    exec(compile(code,'<independent bounded actual-source '+name+'>','exec'),namespace)
    return namespace['source_'+name]
