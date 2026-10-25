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
    core_pools, df_pools = pools(source), pools(df)
    equal(len(core_pools), 54, "core gender/tone pools")
    equal(len(df_pools), 24, "DF gender/tone pools")
    for key, values in list(core_pools.items()) + list(df_pools.items()):
        equal(set(values), set(range(20)), f"complete slots {key}")
        equal(len(set(values.values())), 20, f"unique messages {key}")
    fixture = json.loads(Path(__file__).with_name("fixtures").joinpath("rc5_pools.json").read_text())
    old_pools = {tuple(item["key"]): {int(i): text for i, text in item["entries"].items()} for item in fixture["pools"]}
    equal(len(old_pools), 48, "original RC5 pools")
    for key, entries in old_pools.items():
        # NLSR-003 intentionally rewrote ordinary phone and generic intro text.
        # Other original pools should remain byte-text identical.
        if key[0] not in (5, 7):
            equal(core_pools[key], entries, f"preserved non-phone/non-intro RC5 pool {key}")

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
    for name in ("ShuffleSlot", "NotificationContext", "NotificationCategoryName", "CheckpointMessage", "GetImmersionSaveContext"):
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

    # The exact integer algorithm: permutations and adjacent cycle boundaries.
    for seed in range(32):
        previous = None
        for cycle in range(64):
            selected = [policy.ShuffleSlot(cycle * 20 + turn, seed) for turn in range(20)]
            equal(set(selected), set(range(20)), "shuffle permutation")
            if previous is not None:
                equal(selected[0] != previous, True, "cycle boundary non-repeat")
            previous = selected[-1]

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

    # Run every delivered gender/tone pool via actual selection code, maintaining
    # the independent per-pool counter across four cycles and disabled calls.
    actual_context = policy.NotificationContext
    policy.NotificationContext = lambda g: settings.context
    settings.facts["q000_done"] = 1
    for family, inventory, message in (("core", core_pools, lambda: policy.CheckpointMessage(game, -1)),
                                        ("df", df_pools, lambda: df_message(game, settings.context, False))):
        for key, expected in inventory.items():
            settings.context, settings.tone, player.nlsRebornVoice = key
            player.nlsRebornShuffleSeed = 17
            field = ("nlsRC2Index_" if family == "core" else "nlsDFIndex_") + "_".join(map(str, key))
            setattr(player, field, 0)
            prefix = "Save request: " if family == "df" else ""
            previous = None
            for cycle in range(4):
                texts = [message() for _ in range(20)]
                equal(set(texts), {prefix + text for text in expected.values()}, f"selected full pool {family} {key}")
                equal(len(set(texts)), 20, "no cycle repeats")
                if previous is not None:
                    equal(texts[0] != previous, True, "message cycle boundary")
                previous = texts[-1]
            equal(getattr(player, field), 80, "independent counter")
            settings.notifications = False
            equal(message(), "", "notification off")
            equal(getattr(player, field), 80, "disabled does not advance")
            settings.notifications = True
    policy.NotificationContext = actual_context

    # Neutral introduction fallback has three independent 20-message tone pools.
    policy.NotificationContext = lambda g: settings.context
    player.nlsRebornVoice = 0
    for context, field_prefix in ((7, "nlsNeutralPrologue"), (12, "nlsNeutralIntroCall")):
        settings.context = context
        for tone in range(3):
            settings.tone = tone
            field = field_prefix + str(tone)
            setattr(player, field, 0)
            previous = None
            for cycle in range(4):
                texts = [policy.CheckpointMessage(game, -1) for _ in range(20)]
                equal(len(set(texts)), 20, "neutral intro complete cycle")
                if previous is not None:
                    equal(texts[0] != previous, True, "neutral intro boundary")
                previous = texts[-1]
            equal(getattr(player, field), 80, "independent neutral intro counter")
            settings.notifications = False
            equal(policy.CheckpointMessage(game, -1), "", "neutral disabled notification")
            equal(getattr(player, field), 80, "neutral disabled non-advancement")
            settings.notifications = True
    policy.NotificationContext = actual_context

    # Unknown body retains neutral fallback rather than male/female wording.
    player.nlsRebornVoice = 0
    for context in (8, 9, 10, 11):
        for tone in range(3):
            settings.tone = tone
            text = df_message(game, context, True)
            equal(text.startswith("Checkpoint request: "), True, "neutral DF request prefix")
            equal("ma'am" not in text and "sir" not in text, True, "neutral DF body fallback")

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
                      "core_gender_tone_pools": len(core_pools), "core_entries": sum(map(len, core_pools.values())),
                      "df_gender_tone_pools": len(df_pools), "df_entries": sum(map(len, df_pools.values())),
                      "neutral_introduction_tone_pools": 3, "neutral_introduction_entries": 60,
                      "core_sha256": hashlib.sha256(main_path.read_bytes()).hexdigest(),
                      "df_sha256": hashlib.sha256(df_path.read_bytes()).hexdigest(),
                      "scope": "Constrained actual-source execution with explicit integer/CName/ternary lowering and external game doubles. No REDscript compiler, game, save-write or reload evidence."}, indent=2))


if __name__ == "__main__":
    main()
