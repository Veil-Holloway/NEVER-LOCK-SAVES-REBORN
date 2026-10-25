"""Bounded source translator reused from the project v0.9.3 validation utility.
This evaluates a constrained REDscript subset against doubles; it is NOT a compiler.
"""
import re
from types import SimpleNamespace as Object
HOOKS = ('HandlePressToSaveGame', 'HandlePressToQuickSaveGame', 'HandleQuickSave')
LEXER = re.compile(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*.*?\*/|&&|\|\||==|!=|<=|>=|\+=|\w+|[^\s]', re.S)

def lex(source):
    return [m.group() for m in LEXER.finditer(source) if not m.group().startswith(('//', '/*'))]

def function_range(source, name):
    match = re.search(r'\bfunc\s+' + re.escape(name) + r'\s*\(', source)
    if match is None:
        raise ValueError('missing function: ' + name)
    depth = 0
    for token in LEXER.finditer(source, source.index('{', match.end())):
        if token.group() == '{':
            depth += 1
        elif token.group() == '}':
            depth -= 1
            if depth == 0:
                return match.start(), token.end()
    raise ValueError('unclosed function: ' + name)

def body(source, name):
    start, end = function_range(source, name)
    return source[start:end]

def compile_subset(source, name, namespace, *, instance=False):
    function = body(source, name)
    params = function[function.index('(') + 1:function.index(')')]
    args = re.findall(r'(\w+)\s*:', params)
    if instance:
        args.insert(0, 'this')
    lines = ['def actual_' + name + '(' + ', '.join(args) + '):']
    depth = 1
    pending = []

    def expression(parts):
        result = []
        for index, part in enumerate(parts):
            if part == 'as':
                if parts[index + 1:] != ['PlayerPuppet']:
                    raise ValueError('unsupported cast in ' + name)
                break  # Game types have no meaning in the external boundary doubles.
            result.append({'true': 'True', 'false': 'False', '&&': 'and', '||': 'or', '!': 'not'}.get(part, part))
        return ' '.join(result)

    def statement(parts):
        if not parts:
            return
        if parts[0] == 'let':
            if len(parts) < 4 or parts[2] != ':':
                raise ValueError('unsupported declaration in ' + name)
            rhs = expression(parts[parts.index('=') + 1:]) if '=' in parts else '[]' if parts[3:4] == ['array'] else 'None'
            value = parts[1] + ' = ' + rhs
        elif parts[0] == 'return':
            value = 'return ' + expression(parts[1:])
        else:
            value = expression(parts)
        lines.append('    ' * depth + value)

    content = function[function.index('{') + 1:function.rfind('}')]
    for token in lex(content):
        if token == '{':
            if pending[:1] == ['if']:
                header = 'if ' + expression(pending[1:]) + ':'
            elif pending[:2] == ['else', 'if']:
                header = 'elif ' + expression(pending[2:]) + ':'
            elif pending[:1] == ['while']:
                header = 'while ' + expression(pending[1:]) + ':'
            elif pending == ['else']:
                header = 'else:'
            else:
                raise ValueError('unsupported block in ' + name + ': ' + repr(pending))
            lines.append('    ' * depth + header)
            pending = []
            depth += 1
        elif token == '}':
            statement(pending)
            pending = []
            depth -= 1
            if depth < 1:
                raise ValueError('unbalanced blocks in ' + name)
        elif token == ';':
            statement(pending)
            pending = []
        else:
            pending.append(token)
    statement(pending)
    if depth != 1:
        raise ValueError('unclosed block in ' + name)
    code = '\n'.join(lines) + '\n'
    exec(compile(code, '<actual REDscript constrained subset: ' + name + '>', 'exec'), namespace)
    return namespace['actual_' + name]

class Runtime:
    """Shared external boundaries; helpers and route branches are actual source."""
    def __init__(self, source, current=True):
        self.state = {}
        self.game = Object()
        self.namespace = {'__builtins__': {}, 'IsDefined': lambda value: value is not None,
                          'ArraySize':len,'NotEquals':lambda a,b:a!=b,'Equals':lambda a,b:a==b,
                          'gameSaveLockReason':Object(Combat=1),
                          'VehicleComponent':Object(IsMountedToVehicle=lambda game,player:False)}
        self.namespace['GameInstance'] = Object(
            GetPlayerSystem=lambda game: Object(GetLocalPlayerControlledGameObject=lambda: self.state['player']),
            IsSavingLocked=self.locked,
            GetAutoSaveSystem=lambda game: Object(RequestForcedCheckpoint=self.force),
        )
        self.namespace['NLSRebornDFPolicy'] = Object(Read=self.read)
        self.namespace['NLSRebornDFMessages'] = Object(Message=lambda game, context, checkpoint: f'DF:{context}:{checkpoint}')
        self.namespace['PauseMenuGameController'] = Object(NLSRebornNotify=self.notify)
        self.namespace['wrappedMethod'] = self.wrapped
        self.controller = Object(
            m_gameInstance=self.game, m_quickSaveInProgress=False,
            IsSaveFailedNotificationActive=lambda: self.state['failed'],
            IsGameSavedNotificationActive=lambda: self.state['saved'],
            GetPlayerControlledObject=lambda: self.state['player'] if self.state['controlled'] else None,
        )
        self.namespace['this'] = self.controller
        policy = Object()
        self.namespace['NLSRebornPolicy'] = policy
        for method in ('AllowForcedCheckpointFallback', 'IsProtectedIntroduction'):
            setattr(policy, method, compile_subset(source, method, self.namespace))
        if 'func SmartCombatFallback(' in source:
            policy.SmartCombatFallback=compile_subset(source,'SmartCombatFallback',self.namespace)
        policy.CheckpointMessage = lambda game, context: f'legacy:{context}' if self.state['notifications'] else ''
        self.context = None
        self.set_notifications = None
        if current:
            self.context = compile_subset(source, 'GetImmersionSaveContext', self.namespace)
            policy.GetImmersionSaveContext = self.context
            policy.NotifyImmersionSaveRequest = compile_subset(source, 'NotifyImmersionSaveRequest', self.namespace)
            self.notification_context = compile_subset(source, 'NLSRebornGetDFNotificationContext', self.namespace, instance=True)
            self.set_notifications = compile_subset(source, 'NLSRebornSetDFNotifications', self.namespace, instance=True)
            self.notification_mask = compile_subset(source, 'NLSRebornGetDFNotificationMask', self.namespace, instance=True)
        self.hooks = {name: compile_subset(source, name, self.namespace) for name in HOOKS}
        self.checkpoint_request = self.checkpoint_failure = None
        if 'func NLSRebornRequestCheckpoint(' in source:
            self.checkpoint_request = compile_subset(source, 'NLSRebornRequestCheckpoint', self.namespace, instance=True)
            self.checkpoint_failure = compile_subset(source, 'NLSRebornCheckpointFailure', self.namespace, instance=True)

    def locked(self, game, locks):
        if self.state['locked'] and isinstance(locks,list):
            locks.extend([Object(reason=1)])
        return self.state['locked']

    def force(self):
        self.state['forced'] += 1
        self.state['events'].append('forced')
        return True  # Native boundary double: acceptance, not a file write.

    def wrapped(self, *args):
        self.state['wrapped'] += 1
        self.state['events'].append('wrapped')

    def notify(self, game, message):
        if message:
            self.state['notices'].append(message)
            self.state['events'].append('notice')

    def read(self, player):
        self.state['reads'] += 1
        return self.state['snapshot']

    def prepare(self, mode=1, protected=False, locked=True, mask=15, notifications=True,
                states=(1, 0, 0, 0), quick=False, failed=False, saved=False, no_player=False, controlled=True):
        player = Object(
            NLSRebornGetMode=lambda: mode, nlsRebornSafetyBlock=protected,
            NLSRebornGetCombat=lambda:True,NLSRebornGetVehicle=lambda:False,IsInCombat=lambda:True,
            NLSRebornGetNotificationsEnabled=lambda: notifications,
            NLSRebornGetStatusNotificationsEnabled=lambda:False,
            nlsRebornDFNotifyVehicleSleep=bool(mask & 1), nlsRebornDFNotifyAddiction=bool(mask & 2),
            nlsRebornDFNotifyStarvation=bool(mask & 4), nlsRebornDFNotifyDehydration=bool(mask & 8),
            nlsRebornDFVehicleSleepState=-1, nlsRebornDFAddictionState=-1,
            nlsRebornDFStarvationState=-1, nlsRebornDFDehydrationState=-1,
            nlsRebornDFLastReason=-99, nlsRebornDFLastNotificationContext=-99,
            GetGame=lambda: self.game,
            NLSRebornGetTone=lambda: 0,
            NLSRebornSaveLockSummary=lambda: 'locked|Combat' if locked else 'unlocked',
            NLSRebornMountedState=lambda: 0,
            nlsCheckpointSerial=0, nlsCheckpointSource=0, nlsCheckpointResult=0,
            nlsCheckpointLocks='unknown', nlsCheckpointCombat=-1, nlsCheckpointMounted=-1,
        )
        if self.checkpoint_request is not None:
            player.NLSRebornRequestCheckpoint = lambda source: self.checkpoint_request(player, source)
            player.NLSRebornCheckpointFailure = lambda: self.checkpoint_failure(player)
        if self.context:
            self.set_notifications(player, *(bool(mask & (1 << index)) for index in range(4)))
            player.NLSRebornGetDFNotificationContext = lambda: self.notification_context(player)
        self.state = dict(player=None if no_player else player, locked=locked, notifications=notifications,
                          snapshot=Object(vehicleSleep=states[0], addiction=states[1], starvation=states[2], dehydration=states[3], status='boundary fixture'),
                          reads=0, forced=0, wrapped=0, notices=[], events=[], failed=failed, saved=saved, controlled=controlled)
        self.controller.m_quickSaveInProgress = quick
        return player

    def invoke(self, hook):
        if hook == 'HandlePressToSaveGame':
            self.hooks[hook](None)
        else:
            self.hooks[hook]()
        return self.state
