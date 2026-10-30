#!/usr/bin/env python3
from pathlib import Path
import re,sys
root=Path(sys.argv[1]).resolve()
reds=(root/'r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds').read_text()
init=(root/'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/init.lua').read_text()
report=(root/'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/support_report.lua').read_text()
def body(name):
    m=re.search(r'public final func '+re.escape(name)+r'\([^)]*\) -> \w+ \{(.*?)\n\}',reds,re.S)
    assert m, name+' missing'
    return m.group(1)
phone=body('NLSRebornAutosavePhoneState')
assert 'GameInstance.GetPhoneManager(this.GetGame())' in phone
assert 'ref<questPhoneManager>' in phone
assert 'if !IsDefined(phone) { return -1; };' in phone
assert 'if phone.IsPhoneCallActive() { return 1; };' in phone
assert 'return 0;' in phone
ready=body('NLSRebornAutosaveReady')
assert 'this.NLSRebornAutosavePhoneState() == 0' in ready
assert 'this.NLSRebornNotificationPhoneState() == 0' not in ready
notify=body('NLSRebornNotificationPhoneState')
assert 'PhoneCallInformation' in notify and 'questPhoneCallPhase.StartCall' in notify
assert 'local function readAutosavePhone(player)' in init
assert "'phone_manager'" in init and "'notification_active_fallback'" in init
helper=init.split('local function readAutosavePhone(player)',1)[1].split('\nend',1)[0]
assert 'fallback==1' in helper
assert 'fallback==0' not in helper
assert 'phoneOK and not phoneActiveNow' in init
assert 'autosavePhoneSource=autosavePhoneSource' in init
assert 'autosave_source=member(sensors.autosavePhoneSource,phoneEvidenceSources)' in report
print('PASS phone bridge source regression: manager primary, active-only fallback, unknown fail-closed, notification StartCall semantics preserved')
