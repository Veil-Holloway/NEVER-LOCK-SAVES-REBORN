// Optional live Dark Future reader. No third-party settings or state are changed.
// 1 = active condition, 0 = clear or disabled, -1 = unavailable/unknown.

@if(ModuleExists("DarkFuture.Services") && ModuleExists("DarkFuture.System") && ModuleExists("DarkFuture.Needs") && ModuleExists("DarkFuture.Addictions"))
import DarkFuture.Services.DFGameStateService

@if(ModuleExists("DarkFuture.Services") && ModuleExists("DarkFuture.System") && ModuleExists("DarkFuture.Needs") && ModuleExists("DarkFuture.Addictions"))
import DarkFuture.System.{DFSystem, DFSystemState}

@if(ModuleExists("DarkFuture.Services") && ModuleExists("DarkFuture.System") && ModuleExists("DarkFuture.Needs") && ModuleExists("DarkFuture.Addictions"))
import DarkFuture.Needs.{DFNeedSystemBase, DFNutritionSystem, DFHydrationSystem}

@if(ModuleExists("DarkFuture.Services") && ModuleExists("DarkFuture.System") && ModuleExists("DarkFuture.Needs") && ModuleExists("DarkFuture.Addictions"))
import DarkFuture.Addictions.{DFAddictionSystemBase, DFAlcoholAddictionSystem, DFNicotineAddictionSystem, DFNarcoticAddictionSystem}

public class NLSRebornDFState {
  public let vehicleSleep: Int32;
  public let addiction: Int32;
  public let starvation: Int32;
  public let dehydration: Int32;
  public let status: String = "Dark Future state unknown";
}

@if(ModuleExists("DarkFuture.Services") && ModuleExists("DarkFuture.System") && ModuleExists("DarkFuture.Needs") && ModuleExists("DarkFuture.Addictions"))
public class NLSRebornDFPolicy {
  // Check each system independently. Getter defaults are not readiness evidence.
  private static func Ready(system: ref<DFSystem>, player: ref<PlayerPuppet>) -> Int32 {
    if !IsDefined(system) || !IsDefined(player) {
      return -1;
    }
    if !IsDefined(system.Settings) {
      return -1;
    }
    if !system.Settings.mainSystemEnabled {
      return 0;
    }
    if !system.GetSystemToggleSettingValue() {
      return 0;
    }
    if NotEquals(system.state, DFSystemState.Running) {
      return -1;
    }
    if !IsDefined(system.player) || system.player != player {
      return -1;
    }
    return 1;
  }

  private static func ReadNeed(system: ref<DFNeedSystemBase>, player: ref<PlayerPuppet>) -> Int32 {
    let ready: Int32 = NLSRebornDFPolicy.Ready(system, player);
    if ready != 1 {
      return ready;
    }
    let stage: Int32 = system.GetNeedStage();
    if stage < 0 || stage > 4 {
      return -1;
    }
    // Stage 4 is localized by Dark Future as Starving / Dehydrated.
    // GetNeedStage respects the user's Dark Future threshold settings.
    if stage == 4 {
      return 1;
    }
    return 0;
  }

  private static func ReadAddiction(system: ref<DFAddictionSystemBase>, player: ref<PlayerPuppet>) -> Int32 {
    let ready: Int32 = NLSRebornDFPolicy.Ready(system, player);
    if ready != 1 {
      return ready;
    }
    let stage: Int32 = system.GetAddictionStage();
    if stage < 0 || stage > 4 {
      return -1;
    }
    // Established addiction is separate from current withdrawal or intoxication.
    if stage > 0 {
      return 1;
    }
    return 0;
  }

  public static func Read(player: ref<PlayerPuppet>) -> ref<NLSRebornDFState> {
    let snapshot: ref<NLSRebornDFState> = new NLSRebornDFState();
    // Runtime assignments preserve unknown (-1); negative field defaults are invalid.
    snapshot.vehicleSleep = -1;
    snapshot.addiction = -1;
    snapshot.starvation = -1;
    snapshot.dehydration = -1;
    if !IsDefined(player) {
      snapshot.status = "Dark Future live read unavailable: no player";
      return snapshot;
    }

    let game: GameInstance = GetGameInstance();
    let service: ref<DFGameStateService> = DFGameStateService.GetInstance(game);
    let sleepReady: Int32 = NLSRebornDFPolicy.Ready(service, player);
    if sleepReady == 1 {
      if service.GetSleepingInVehicle() {
        snapshot.vehicleSleep = 1;
      } else {
        snapshot.vehicleSleep = 0;
      }
    } else {
      snapshot.vehicleSleep = sleepReady;
    }

    snapshot.starvation = NLSRebornDFPolicy.ReadNeed(DFNutritionSystem.GetInstance(game), player);
    snapshot.dehydration = NLSRebornDFPolicy.ReadNeed(DFHydrationSystem.GetInstance(game), player);

    let alcohol: Int32 = NLSRebornDFPolicy.ReadAddiction(DFAlcoholAddictionSystem.GetInstance(game), player);
    let nicotine: Int32 = NLSRebornDFPolicy.ReadAddiction(DFNicotineAddictionSystem.GetInstance(game), player);
    let narcotic: Int32 = NLSRebornDFPolicy.ReadAddiction(DFNarcoticAddictionSystem.GetInstance(game), player);
    if alcohol == 1 || nicotine == 1 || narcotic == 1 {
      snapshot.addiction = 1;
    } else {
      if alcohol == -1 || nicotine == -1 || narcotic == -1 {
        snapshot.addiction = -1;
      } else {
        snapshot.addiction = 0;
      }
    }

    snapshot.status = "Dark Future live read: 1=active, 0=clear/disabled, -1=unknown";
    return snapshot;
  }
}

@if(!(ModuleExists("DarkFuture.Services") && ModuleExists("DarkFuture.System") && ModuleExists("DarkFuture.Needs") && ModuleExists("DarkFuture.Addictions")))
public class NLSRebornDFPolicy {
  public static func Read(player: ref<PlayerPuppet>) -> ref<NLSRebornDFState> {
    let snapshot: ref<NLSRebornDFState> = new NLSRebornDFState();
    // Runtime assignments preserve unknown (-1); negative field defaults are invalid.
    snapshot.vehicleSleep = -1;
    snapshot.addiction = -1;
    snapshot.starvation = -1;
    snapshot.dehydration = -1;
    snapshot.status = "Dark Future required modules not present: live state unknown";
    return snapshot;
  }
}
