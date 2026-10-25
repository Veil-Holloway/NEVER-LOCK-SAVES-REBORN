#!/usr/bin/env python3
"""Execute delivered REDscript reader bodies through the existing subset runner.

External game/DF getters are doubles. Constructor defaults are parsed from the
actual NLSRebornDFState declaration. Only REDscript's `new` keyword is lowered
before using the existing expression/statement translator. This does not compile
REDscript, resolve real imports, or run Cyberpunk 2077.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import importlib.util
import itertools
import json
from pathlib import Path
import re
from types import SimpleNamespace as Obj


MODULES = ("DarkFuture.Services", "DarkFuture.System", "DarkFuture.Needs", "DarkFuture.Addictions")
FIELDS = ("vehicleSleep", "addiction", "starvation", "dehydration")
SCRIPT = Path("r6/scripts/NeverLockSavesReborn/DarkFutureSavePolicy.reds")


def load_runner(release):
    path = Path(__file__).with_name("subset_runner.py")
    spec = importlib.util.spec_from_file_location("existing_subset", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.compile_subset


def condition(expression, available):
    lowered = re.sub(r'ModuleExists\("([^"]+)"\)', lambda m: str(m[1] in available), expression)
    lowered = lowered.replace("&&", " and ").replace("||", " or ").replace("!", " not ").strip()
    tree = ast.parse(lowered, mode="eval")
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp, ast.Not, ast.Constant)
    if any(not isinstance(node, allowed) for node in ast.walk(tree)):
        raise ValueError("Unsupported conditional syntax")
    return eval(compile(tree, "<module condition>", "eval"), {"__builtins__": {}})


def initializers(source):
    match = re.search(r'public class NLSRebornDFState\s*\{(.*?)^\}', source, re.M | re.S)
    if not match:
        raise ValueError("State declaration missing")
    fields = {}
    for name, typename, literal in re.findall(r'public let (\w+): (Int32|String)(?: = ([^;]+))?;', match[1]):
        value = ast.literal_eval(literal) if literal else (0 if typename == "Int32" else "")
        if typename == "Int32" and type(value) is not int:
            raise ValueError("Unsupported integer default")
        if typename == "String" and type(value) is not str:
            raise ValueError("Unsupported string default")
        fields[name] = value
    if set(fields) != set(FIELDS) | {"status"}:
        raise ValueError("Unsupported state schema")
    return fields


class BoundarySystem:
    def __init__(self, player, stage=0, *, lifecycle="Running", enabled=True,
                 master=True, settings=True, sleeping=False, forbid_getter=False):
        self.player = player
        self.state = lifecycle
        self.Settings = Obj(mainSystemEnabled=master) if settings else None
        self.stage = stage
        self.enabled = enabled
        self.sleeping = sleeping
        self.forbid_getter = forbid_getter
        self.getters = 0
        self.toggle_reads = 0

    def GetSystemToggleSettingValue(self):
        self.toggle_reads += 1
        if self.Settings is None:
            raise AssertionError("toggle accessed without initialized settings")
        return self.enabled

    def _read(self, value):
        self.getters += 1
        if self.forbid_getter:
            raise AssertionError("unready/disabled system getter was called")
        return value

    def GetNeedStage(self):
        return self._read(self.stage)

    def GetAddictionStage(self):
        return self._read(self.stage)

    def GetSleepingInVehicle(self):
        return self._read(self.sleeping)

    def IsValidGameState(self, *args):
        raise AssertionError("reader must not gate vehicle sleep on gameplay validity")


class Runtime:
    def __init__(self, source, compile_subset, available=MODULES):
        self.player = object()
        self.game = object()
        self.lookups = []
        self.game_reads = 0
        self.systems = {name: BoundarySystem(self.player) for name in
                        ("sleep", "nutrition", "hydration", "alcohol", "nicotine", "narcotic")}
        defaults = initializers(source)
        namespace = {
            "IsDefined": lambda value: value is not None,
            "NotEquals": lambda a, b: a != b,
            "DFSystemState": Obj(Running="Running"),
            "NLSRebornDFState": lambda: Obj(**defaults),
            "GetGameInstance": self.get_game,
        }
        for class_name, key in (("DFGameStateService", "sleep"), ("DFNutritionSystem", "nutrition"),
                                ("DFHydrationSystem", "hydration"), ("DFAlcoholAddictionSystem", "alcohol"),
                                ("DFNicotineAddictionSystem", "nicotine"), ("DFNarcoticAddictionSystem", "narcotic")):
            namespace[class_name] = Obj(GetInstance=lambda game, key=key: self.lookup(key, game))
        predicates = re.findall(r'^@if\((.*)\)\npublic class NLSRebornDFPolicy', source, re.M)
        if len(predicates) != 2:
            raise ValueError("Expected live and fallback class conditions")
        live, fallback = (condition(p, set(available)) for p in predicates)
        if live == fallback:
            raise AssertionError("Exactly one conditional policy must exist")
        self.live = live
        # Lower only the two allocation expressions, preserving all function bodies.
        lowered, count = re.subn(r'\bnew\s+NLSRebornDFState\(\)', 'NLSRebornDFState()', source)
        if count != 2:
            raise ValueError("Unsupported constructor surface")
        policy = Obj()
        namespace["NLSRebornDFPolicy"] = policy
        if live:
            for name in ("Ready", "ReadNeed", "ReadAddiction", "Read"):
                setattr(policy, name, compile_subset(lowered, name, namespace))
        else:
            fallback_start = lowered.index("public class NLSRebornDFPolicy", lowered.index("public class NLSRebornDFPolicy") + 1)
            policy.Read = compile_subset(lowered[fallback_start:], "Read", namespace)
        self.read = policy.Read

    def lookup(self, key, game):
        if game is not self.game:
            raise AssertionError("wrong game instance")
        self.lookups.append(key)
        return self.systems[key]

    def get_game(self):
        self.game_reads += 1
        return self.game


def verify(source, compile_subset):
    checks = 0

    def equal(actual, expected, label):
        nonlocal checks
        checks += 1
        if actual != expected:
            raise AssertionError(f"{label}: {actual!r} != {expected!r}")

    def values(snapshot):
        return tuple(getattr(snapshot, field) for field in FIELDS)

    predicates = re.findall(r'^@if\((.*)\)\n(?:import |public class NLSRebornDFPolicy)', source, re.M)
    equal(len(predicates), 6, "conditional import/class surface")
    for bits in itertools.product((False, True), repeat=4):
        available = {name for name, present in zip(MODULES, bits) if present}
        expected_live = all(bits)
        for predicate in predicates[:5]:
            equal(condition(predicate, available), expected_live, "all required modules must exist")
        equal(condition(predicates[5], available), not expected_live, "fallback must be exact complement")
        runtime = Runtime(source, compile_subset, available)
        equal(runtime.live, expected_live, "conditional branch selection")
        if not expected_live:
            equal(values(runtime.read(runtime.player)), (-1, -1, -1, -1), "partial/absent modules unknown")
            equal(runtime.lookups, [], "fallback performs no DF lookup")
            equal(runtime.game_reads, 0, "fallback does not enter game")

    runtime = Runtime(source, compile_subset)
    equal(values(runtime.read(None)), (-1, -1, -1, -1), "undefined player")
    equal(runtime.game_reads, 0, "undefined player skips lookup")
    for key, field in (("sleep", "vehicleSleep"), ("nutrition", "starvation"), ("hydration", "dehydration")):
        for options, expected in (({"master": False}, 0), ({"enabled": False}, 0),
                                  ({"settings": False}, -1), ({"lifecycle": "Uninitialized"}, -1),
                                  ({"lifecycle": "Suspended"}, -1)):
            runtime = Runtime(source, compile_subset)
            system = BoundarySystem(runtime.player, stage=4, sleeping=True, forbid_getter=True, **options)
            runtime.systems[key] = system
            equal(getattr(runtime.read(runtime.player), field), expected, f"{key} readiness {options}")
            equal(system.getters, 0, "guarded getter not called")
        runtime = Runtime(source, compile_subset)
        stale = BoundarySystem(object(), stage=4, sleeping=True, forbid_getter=True)
        runtime.systems[key] = stale
        equal(getattr(runtime.read(runtime.player), field), -1, f"{key} stale player")
        equal(stale.getters, 0, "stale attachment skipped")
        runtime.systems[key] = None
        equal(getattr(runtime.read(runtime.player), field), -1, f"{key} absent system")

    for key, field in (("nutrition", "starvation"), ("hydration", "dehydration")):
        for stage in (-2, -1, 0, 1, 2, 3, 4, 5, 10):
            runtime = Runtime(source, compile_subset)
            runtime.systems[key].stage = stage
            expected = 1 if stage == 4 else 0 if 0 <= stage <= 3 else -1
            equal(getattr(runtime.read(runtime.player), field), expected, f"{key} stage {stage}")
            equal(runtime.systems[key].getters, 1, "ready need sampled once")

    for key in ("alcohol", "nicotine", "narcotic"):
        for stage in (-1, 0, 1, 2, 3, 4, 5):
            runtime = Runtime(source, compile_subset)
            runtime.systems[key].stage = stage
            expected = 1 if 1 <= stage <= 4 else 0 if stage == 0 else -1
            equal(runtime.read(runtime.player).addiction, expected, f"{key} addiction stage {stage}")
        for options, expected in (({"master": False}, 0), ({"enabled": False}, 0),
                                  ({"settings": False}, -1), ({"lifecycle": "Suspended"}, -1),
                                  ({"lifecycle": "Uninitialized"}, -1)):
            runtime = Runtime(source, compile_subset)
            system = BoundarySystem(runtime.player, stage=4, forbid_getter=True, **options)
            runtime.systems[key] = system
            equal(runtime.read(runtime.player).addiction, expected, f"{key} readiness {options}")
            equal(system.getters, 0, "addiction getter guarded")
        runtime = Runtime(source, compile_subset)
        runtime.systems[key] = BoundarySystem(object(), stage=4, forbid_getter=True)
        equal(runtime.read(runtime.player).addiction, -1, f"{key} stale player")

    for states in itertools.product((-1, 0, 1), repeat=3):
        runtime = Runtime(source, compile_subset)
        for key, value in zip(("alcohol", "nicotine", "narcotic"), states):
            runtime.systems[key] = None if value == -1 else BoundarySystem(runtime.player, stage=value)
        expected = 1 if 1 in states else -1 if -1 in states else 0
        equal(runtime.read(runtime.player).addiction, expected, f"addiction aggregate {states}")

    runtime = Runtime(source, compile_subset)
    for key in ("alcohol", "nicotine", "narcotic"):
        runtime.systems[key] = BoundarySystem(runtime.player, stage=4, enabled=False, forbid_getter=True)
    equal(runtime.read(runtime.player).addiction, 0, "all addiction systems disabled")

    runtime = Runtime(source, compile_subset)
    runtime.systems["sleep"].sleeping = True
    equal(runtime.read(runtime.player).vehicleSleep, 1, "sleep remains readable when DF gameplay invalid")
    old = runtime.systems["nutrition"]
    old.stage = 4
    equal(runtime.read(runtime.player).starvation, 1, "first live sample")
    previous_getter_calls = old.getters
    runtime.systems["nutrition"] = BoundarySystem(runtime.player, stage=0)
    equal(runtime.read(runtime.player).starvation, 0, "next request resolves fresh system")
    equal(old.getters, previous_getter_calls, "old system not read after replacement")
    equal(runtime.game_reads, 3, "fresh game instance for each request")
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", type=Path, required=True)
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    source_path = args.release / SCRIPT
    source = source_path.read_text()
    runner = load_runner(args.release)
    checks = verify(source, runner)
    killed = []
    if args.self_check:
        replacements = (
            ("stage4 misclassified", "if stage == 4 {", "if stage == 3 {"),
            ("active loses to unknown", "if alcohol == 1 || nicotine == 1 || narcotic == 1 {",
             "if alcohol == 1 && nicotine == 1 && narcotic == 1 {"),
            ("missing modules activate live reader", 'ModuleExists("DarkFuture.Services") &&',
             'ModuleExists("DarkFuture.Services") ||'),
            ("sleep incorrectly gated on validity", "if sleepReady == 1 {",
             "if sleepReady == 1 && service.IsValidGameState(player, false, false) {"),
            ("unknown default promoted to active", "snapshot.vehicleSleep = -1;",
             "snapshot.vehicleSleep = 1;"),
        )
        for label, before, after in replacements:
            if before not in source:
                raise AssertionError("negative control anchor missing: " + label)
            try:
                verify(source.replace(before, after, 1), runner)
            except (AssertionError, ValueError, AttributeError):
                killed.append(label)
            else:
                raise AssertionError("negative control escaped detection: " + label)
    print(json.dumps({"source": str(source_path), "sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
                      "checks": checks, "module_combinations": 16, "negative_controls_detected": killed,
                      "result": "PASS", "scope": "Actual-source subset execution with external game/DF doubles; no real import resolution, REDscript compile, game, or save-file validation."}, indent=2))


if __name__ == "__main__":
    main()
