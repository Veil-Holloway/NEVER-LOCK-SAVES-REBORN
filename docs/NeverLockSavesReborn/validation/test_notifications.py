#!/usr/bin/env python3
"""Fresh constrained actual-source notification tests, not REDscript compilation.

Game/DF boundaries are doubles. CName literals become strings, the one DF
ternary becomes Python's equivalent, and Int32 division becomes floor division.
No production source is changed. Source inventory is counted independently.
"""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import re
from types import SimpleNamespace as Obj
import subset_runner as subset


checks = 0


def equal(actual, expected, label):
    global checks
    checks += 1
    assert actual == expected, f"{label}: {actual!r} != {expected!r}"


def pools(source):
    result = {}
    pattern = r'if context == (\d+) && tone == (\d+) && voice == (\d+) \{\s*((?:\s*if slot == \d+ \{ return [^\n]+\n)+)\s*\}'
    for c, t, v, block in re.findall(pattern, source):
        entries = re.findall(r'if slot == (\d+) \{ return (?:prefix \+ )?("(?:\\.|[^"\\])*"); \};', block)
        key = tuple(map(int, (c, t, v)))
        assert key not in result
        result[key] = {int(i): json.loads(text) for i, text in entries}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", type=Path, required=True)
    args = parser.parse_args()
    main_path = args.release / "r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds"
    df_path = args.release / "r6/scripts/NeverLockSavesReborn/DarkFutureMessages.reds"
    source = main_path.read_text()
    df = df_path.read_text()
    equal('NLSRebornGetTone' in source + df, False, 'no tone bridge')
    equal('nlsRC2Index_' in source + df, False, 'no obsolete rotation banks')
    settings = Obj(tone=0, mode=1, notifications=True, context=0, phone=0, combat=False,
                   quest_available=True,
                   mounted=False, facts={"q000_started": 0, "q000_done": 1, "q001_started": 0,
                                       "q000_corpo_background": 0})
    player = Obj()
    for name in re.findall(r'\blet (nls\w+): (?:Int32|Bool|String)', source + df):
        setattr(player, name, 0)
    player.nlsRebornSafetyBlock = False
    player.NLSRebornGetMode = lambda: settings.mode
    player.NLSRebornGetTone = lambda: settings.tone
    player.NLSRebornGetNotificationsEnabled = lambda: settings.notifications
    player.NLSRebornNotificationPhoneState = lambda: settings.phone
    player.IsInCombat = lambda: settings.combat
    game = object()
    player.GetGame = lambda: game
    state = Obj(vehicleSleep=-1, addiction=-1, starvation=-1, dehydration=-1, status="test")
    ns = {
        "IsDefined": lambda x: x is not None,
        "ToString": str,
        "GameInstance": Obj(GetPlayerSystem=lambda g: Obj(GetLocalPlayerControlledGameObject=lambda: player),
                            GetQuestsSystem=lambda g: Obj(GetFact=lambda key: settings.facts[key]) if settings.quest_available else None),
        "VehicleComponent": Obj(IsMountedToVehicle=lambda g, p: settings.mounted),
        "NLSRebornDFPolicy": Obj(Read=lambda p: state),
    }
    policy = Obj()
    ns["NLSRebornPolicy"] = policy
    lowered = re.sub(r'\bn("(?:\\.|[^"\\])*")', r'\1', source)
    for name in ("NotificationContext", "NotificationCategoryName", "CheckpointMessage", "GetImmersionSaveContext"):
        setattr(policy, name, subset.compile_subset(lowered, name, ns))
    ensure = subset.compile_subset(lowered, "NLSRebornEnsureDFStateInitialized", ns, instance=True)
    player.NLSRebornEnsureDFStateInitialized = lambda: ensure(player)
    intro = subset.compile_subset(lowered, "NLSRebornDeferredIntroComplete", ns, instance=True)
    player.NLSRebornDeferredIntroComplete = lambda: intro(player)
    df_context = subset.compile_subset(lowered, "NLSRebornGetDFNotificationContext", ns, instance=True)
    player.NLSRebornGetDFNotificationContext = lambda: df_context(player)
    lowered_df = df.replace('checkpoint ? "Checkpoint request: " : "Save request: "',
                            '("Checkpoint request: " if checkpoint else "Save request: ")')
    df_message = subset.compile_subset(lowered_df, "Message", ns)

    # Actual context function: intro/call/combat/mounted/crouch precedence.
    for started, done, q001, corpo in itertools.product((0, 1), repeat=4):
        settings.facts = dict(q000_started=started, q000_done=done, q001_started=q001,
                              q000_corpo_background=corpo)
        for phone, combat, mounted, crouch in itertools.product((-1, 0, 1), (False, True), (False, True), (False, True)):
            settings.phone, settings.combat, settings.mounted = phone, combat, mounted
            player.nlsRebornContext = 4 if crouch else 0
            expected = ((12 if phone == 1 and corpo else 7) if started and not done and not q001 else
                        5 if phone == 1 else 3 if combat and mounted else 1 if combat else 2 if mounted else 4 if crouch else 0)
            equal(policy.NotificationContext(game), expected, "context priority")

    # Every body receives identical neutral wording, including unknown bodies.
    actual_context = policy.NotificationContext
    settings.notifications = True
    expected_core = {12: 'Saving is unavailable during the introduction call.',
        7: 'Saving is unavailable during the introduction.', 5: 'Saving game during a phone call...',
        3: 'Saving game during vehicle combat...', 1: 'Saving game during combat...',
        2: 'Saving game while in a vehicle...', 4: 'Saving game while in stealth...',
        0: 'Saving game...', 6: 'Saving game...'}
    for context, expected in expected_core.items():
        policy.NotificationContext = lambda g, c=context: c
        for body in (-1, 0, 1, 2, 3):
            player.nlsRebornVoice = body
            equal(policy.CheckpointMessage(game, -1), expected, 'body-neutral core context')
            settings.notifications = False
            equal(policy.CheckpointMessage(game, -1), '', 'core master switch')
            settings.notifications = True
    policy.NotificationContext = actual_context
    expected_df = {8: 'Vehicle sleep is active.', 9: 'Addiction is active.',
        10: 'You are starving.', 11: 'You are dehydrated.', 0: ''}
    for context, expected in expected_df.items():
        for checkpoint in (False, True):
            for body in (-1, 0, 1, 2, 3):
                player.nlsRebornVoice = body
                prefix = 'Saving game. '
                equal(df_message(game, context, checkpoint), prefix + expected, 'body-neutral DF context')
                settings.notifications = False
                equal(df_message(game, context, checkpoint), '', 'DF master switch')
                settings.notifications = True

    # All tri-state combinations and notification masks. Switches may affect
    # selection only; the actual save context remains unchanged.
    context_fields = (("vehicleSleep", "VehicleSleep", 8), ("dehydration", "Dehydration", 11),
                      ("starvation", "Starvation", 10), ("addiction", "Addiction", 9))
    for states in itertools.product((-1, 0, 1), repeat=4):
        for (name, _, _), value in zip(context_fields, states):
            setattr(state, name, value)
        for mask in itertools.product((False, True), repeat=4):
            for (_, suffix, _), enabled in zip(context_fields, mask):
                setattr(player, "nlsRebornDFNotify" + suffix, enabled)
            for mode, protected in itertools.product(range(4), (False, True)):
                settings.mode, player.nlsRebornSafetyBlock = mode, protected
                expected = next((context for value, (_, _, context) in zip(states, context_fields) if value == 1), 0) if mode == 1 and not protected else 0
                equal(policy.GetImmersionSaveContext(game), expected, "DF context independent of message switches")
                if mode == 1 and not protected:
                    notified = next((context for value, enabled, (_, _, context) in zip(states, mask, context_fields) if value == 1 and enabled), 0)
                    equal(player.NLSRebornGetDFNotificationContext(), notified, "DF enabled-context priority")

    # Fresh introduction facts override stale cached safety state in Immersion.
    # This regression must fail the old v0.10.4a source for completed -> unfinished
    # fact transitions even when the previous cached protection is false.
    settings.mode, player.nlsRebornSafetyBlock = 1, False
    state.vehicleSleep, state.dehydration, state.starvation, state.addiction = 1, 1, 1, 1
    for available, done, q001 in itertools.product((False, True), (-1, 0, 1, 2), (0, 1)):
        settings.quest_available = available
        settings.facts["q000_done"], settings.facts["q001_started"] = done, q001
        equal(policy.GetImmersionSaveContext(game), 8 if available and done > 0 else 0,
              "fresh introduction gate independent of diagnostic q001 or cached safety")
    settings.quest_available = True

    print(json.dumps({"result": "PASS", "assertions": checks,
                      "core_sha256": hashlib.sha256(main_path.read_bytes()).hexdigest(),
                      "df_sha256": hashlib.sha256(df_path.read_bytes()).hexdigest(),
                      "scope": "Constrained actual-source execution with explicit integer/CName/ternary lowering and external game doubles. No REDscript compiler, game, save-write or reload evidence."}, indent=2))


if __name__ == "__main__":
    main()
