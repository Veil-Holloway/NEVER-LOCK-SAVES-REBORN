"""Constrained evaluation of actual journal bridge source; not REDscript compilation."""
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text()
name = "NLSRebornQuestMilestoneState"
match = re.search(r"public final func " + name + r"\(hash: Uint32\) -> Int32 \{", source)
assert match, "actual supported bridge signature"
start = match.end()
depth = 1
index = start
while depth:
    if source[index] == "{": depth += 1
    if source[index] == "}": depth -= 1
    index += 1
body = source[start:index-1]


def translate(text):
    lines = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line: continue
        line = re.sub(r"^let (\w+): (?:ref|wref)<\w+> = ", r"\1 = ", line)
        line = re.sub(r"entry as (JournalQuest(?:Objective)?)", r"cast(entry, \1)", line)
        line = line.replace("!IsDefined", "not IsDefined")
        statement = re.fullmatch(r"if (.+) \{ return (-?\d+); \};", line)
        if statement:
            lines.append("    if " + statement[1] + ": return " + statement[2])
        elif line.endswith(";") and (" = " in line or re.fullmatch(r"return -?\d+;", line)):
            lines.append("    " + line[:-1])
        else:
            raise AssertionError("Unsupported constrained source statement: " + line)
    namespace = dict(GameInstance=GameInstance, IsDefined=lambda x: x is not None,
                     NotEquals=lambda a,b: a != b, cast=lambda value, kind: value if isinstance(value,kind) else None,
                     JournalQuest=JournalQuest, JournalQuestObjective=JournalQuestObjective,
                     gameJournalEntryState=gameJournalEntryState)
    exec("def bridge(this, hash):\n" + "\n".join(lines), namespace)
    return namespace["bridge"]


class JournalQuest: pass
class JournalQuestObjective: pass
class OtherEntry: pass
class gameJournalEntryState:
    Succeeded = "Succeeded"
    Active = "Active"
class Journal:
    def __init__(self, entry, state): self.entry,self.state = entry,state
    def GetEntry(self, hash): return self.entry
    def GetEntryState(self, entry):
        assert entry is self.entry
        return self.state
class GameInstance:
    @staticmethod
    def GetJournalManager(game): return game
class Player:
    def __init__(self, journal): self.journal=journal
    def GetGame(self): return self.journal


cases = [(None, -1)]
for entry,expected_type in [(None,-1),(JournalQuest(),1),(JournalQuestObjective(),2),(OtherEntry(),0)]:
    for state in ("Active", "Inactive", "Failed", "Succeeded", "unknown"):
        expected = -1 if entry is None else expected_type if state == "Succeeded" else 0
        cases.append((Journal(entry,state),expected))
bridge=translate(body)
for journal,expected in cases:
    assert bridge(Player(journal),7) == expected
mutations = [body.replace("gameJournalEntryState.Succeeded", "gameJournalEntryState.Active"),
             body.replace("entry as JournalQuestObjective", "entry as JournalQuest")]
for mutated in mutations:
    changed=translate(mutated)
    assert any(changed(Player(journal),7) != expected for journal,expected in cases), "mutation must be detected"
assert not re.search(r"SetFact|SetEntryState|RequestSave|RequestCheckpoint|\.Save\(", body)
print(f"PASS independent journal bridge: {len(cases)} constrained actual-source cases; two mutation controls; no compiler/game evidence")
