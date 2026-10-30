// v1.0.0 Stable. Deferred/autosave lanes are opt-in.
// Engine native saving-unlocked state is the release gate; this does not
// guarantee that a quest or phone conversation serializes correctly.
@addField(PlayerPuppet) public let nlsDeferredEnabled: Bool = false;
@addField(PlayerPuppet) public let nlsAutosaveEnabled: Bool = false;
@addField(PlayerPuppet) private let nlsStatusNotificationsEnabled: Bool = false;
@addMethod(PlayerPuppet)
public final func NLSRebornSetStatusNotificationsEnabled(enabled: Bool) -> Void { this.nlsStatusNotificationsEnabled = enabled; }
@addMethod(PlayerPuppet)
public final func NLSRebornGetStatusNotificationsEnabled() -> Bool { return this.nlsStatusNotificationsEnabled; }
@addMethod(PlayerPuppet)
public final func NLSRebornStatusNotify(message: String) -> Bool {
  if !this.nlsStatusNotificationsEnabled || !this.NLSRebornGetNotificationsEnabled() || Equals(message, "") { return false; };
  if !IsDefined(GameInstance.GetUISystem(this.GetGame())) { return false; };
  PauseMenuGameController.NLSRebornNotify(this.GetGame(), message);
  return true; // accepted by UI event bridge, not confirmation of display or save completion
}

@addMethod(PlayerPuppet)
public final func NLSRebornCompletionNotify(success: Bool) -> Bool {
  if !this.NLSRebornGetNotificationsEnabled() { return false; };
  if !IsDefined(GameInstance.GetUISystem(this.GetGame())) { return false; };
  if success {
    PauseMenuGameController.NLSRebornNotify(this.GetGame(), "Game saved.");
  } else {
    PauseMenuGameController.NLSRebornNotify(this.GetGame(), "Could not save the game.");
  };
  return true;
}

@addField(PlayerPuppet) public let nlsDeferredPending: Bool = false;
@addField(PlayerPuppet) public let nlsDeferredSerial: Int32 = 0;
@addField(PlayerPuppet) public let nlsDeferredSource: Int32 = 0;
// Runtime-only field: bridge-owned identity, independent of CET userdata wrappers.
@addField(PlayerPuppet) private let nlsDeferredSession: Int32 = 0;
@addMethod(PlayerPuppet)
public final func NLSRebornDeferredSession(candidate: Int32) -> Int32 {
  if this.nlsDeferredSession == 0 && candidate > 0 { this.nlsDeferredSession = candidate; };
  return this.nlsDeferredSession;
}
@addMethod(PlayerPuppet)
public final func NLSRebornDeferredIntroComplete() -> Bool {
  // q001_started is not a reliable post-introduction prerequisite.
  let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  return IsDefined(quests) && quests.GetFact(n"q000_done") > 0;
}

@addMethod(PlayerPuppet)
public final func NLSRebornDeferredSetEnabled(enabled: Bool) -> Void {
  this.nlsDeferredEnabled = enabled;
  if !enabled && this.nlsDeferredSource != 3 { this.nlsDeferredPending = false; };
}
@addMethod(PlayerPuppet)
public final func NLSRebornDeferredQueue(source: Int32) -> Bool {
  if (source != 1 && source != 2) || this.nlsRebornSafetyBlock || !this.NLSRebornDeferredIntroComplete() { return false; };
  if this.NLSRebornGetMode() == 0 || !this.nlsDeferredEnabled { return false; };
  this.nlsDeferredSerial += 1;
  this.nlsDeferredSource = source;
  this.nlsDeferredPending = true;
  return true;
}
// Explicit diagnostic reads do not alter save policy or cached DF context.
@addMethod(PlayerPuppet)
public final func NLSRebornDiagnosticDFState() -> ref<NLSRebornDFState> { return NLSRebornDFPolicy.Read(this); }
@addMethod(PlayerPuppet)
public final func NLSRebornSaveLockSummary() -> String {
  let locks: array<gameSaveLock>;
  let locked: Bool = GameInstance.IsSavingLocked(this.GetGame(), locks);
  if ArraySize(locks) > 16 { return "overflow"; };
  if !locked && ArraySize(locks) == 0 { return "unlocked"; };
  if !locked || ArraySize(locks) == 0 { return "unknown"; };
  let result: String = "locked";
  let index: Int32 = 0;
  while index < ArraySize(locks) {
    if Equals(locks[index].reason, gameSaveLockReason.Nothing) { result = result + "|Nothing"; }
    else if Equals(locks[index].reason, gameSaveLockReason.Combat) { result = result + "|Combat"; }
    else if Equals(locks[index].reason, gameSaveLockReason.Scene) { result = result + "|Scene"; }
    else if Equals(locks[index].reason, gameSaveLockReason.Quest) { result = result + "|Quest"; }
    else if Equals(locks[index].reason, gameSaveLockReason.Script) { result = result + "|Script"; }
    else if Equals(locks[index].reason, gameSaveLockReason.Boundary) { result = result + "|Boundary"; }
    else if Equals(locks[index].reason, gameSaveLockReason.MainMenu) { result = result + "|MainMenu"; }
    else if Equals(locks[index].reason, gameSaveLockReason.LoadingScreen) { result = result + "|LoadingScreen"; }
    else if Equals(locks[index].reason, gameSaveLockReason.PlayerStateMachine) { result = result + "|PlayerStateMachine"; }
    else if Equals(locks[index].reason, gameSaveLockReason.PlayerState) { result = result + "|PlayerState"; }
    else if Equals(locks[index].reason, gameSaveLockReason.Tier) { result = result + "|Tier"; }
    else if Equals(locks[index].reason, gameSaveLockReason.NotEnoughSlots) { result = result + "|NotEnoughSlots"; }
    else if Equals(locks[index].reason, gameSaveLockReason.NotEnoughSpace) { result = result + "|NotEnoughSpace"; }
    else if Equals(locks[index].reason, gameSaveLockReason.PlayerOnMovingPlatform) { result = result + "|PlayerOnMovingPlatform"; }
    else { result = result + "|Unknown"; };
    index += 1;
  };
  return result;
}
// Bounded last-attempt diagnostics. Native acceptance is not save completion.
@addField(PlayerPuppet) private let nlsCheckpointSerial: Int32 = 0;
@addField(PlayerPuppet) private let nlsCheckpointSource: Int32 = 0;
@addField(PlayerPuppet) private let nlsCheckpointResult: Int32 = 0;
@addField(PlayerPuppet) private let nlsCheckpointLocks: String = "unknown";
@addField(PlayerPuppet) private let nlsCheckpointCombat: Int32;
@addField(PlayerPuppet) private let nlsCheckpointMounted: Int32;
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointGetSerial() -> Int32 { return this.nlsCheckpointSerial; }
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointGetSource() -> Int32 { return this.nlsCheckpointSource; }
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointGetResult() -> Int32 { return this.nlsCheckpointResult; }
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointGetLocks() -> String { return this.nlsCheckpointLocks; }
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointGetCombat() -> Int32 {
  if this.nlsCheckpointSerial == 0 { return -1; };
  return this.nlsCheckpointCombat;
}
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointGetMounted() -> Int32 {
  if this.nlsCheckpointSerial == 0 { return -1; };
  return this.nlsCheckpointMounted;
}
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointFailure() -> Void {
  if !this.NLSRebornGetNotificationsEnabled() { return; };
  let message: String = "Could not start saving. Please try again.";
  if this.nlsCheckpointResult == 3 {
    message = "Saving is unavailable. Please try again later.";
  };
  if this.nlsCheckpointResult == 4 {
    message = "Saving is not available right now.";
  };
  PauseMenuGameController.NLSRebornNotify(this.GetGame(), message);
}
@addMethod(PlayerPuppet)
public final func NLSRebornRequestCheckpoint(source: Int32) -> Bool {
  if this.nlsCheckpointSerial < 2147483647 { this.nlsCheckpointSerial += 1; }
  else { this.nlsCheckpointSerial = 1; };
  this.nlsCheckpointSource = source;
  this.nlsCheckpointResult = 0;
  this.nlsCheckpointLocks = this.NLSRebornSaveLockSummary();
  this.nlsCheckpointCombat = 0;
  if this.IsInCombat() { this.nlsCheckpointCombat = 1; };
  this.nlsCheckpointMounted = this.NLSRebornMountedState();
  if (source != 1 && source != 2 && source != 3) || !this.NLSRebornDeferredNativeUnlocked() {
    this.nlsCheckpointResult = 4;
    this.NLSRebornCheckpointFailure();
    return false;
  };
  let autosave: ref<gameAutoSaveSystem> = GameInstance.GetAutoSaveSystem(this.GetGame());
  if !IsDefined(autosave) {
    this.nlsCheckpointResult = 3;
    this.NLSRebornCheckpointFailure();
    return false;
  };
  if !autosave.RequestForcedCheckpoint() {
    this.nlsCheckpointResult = 2;
    this.NLSRebornCheckpointFailure();
    return false;
  };
  this.nlsCheckpointResult = 1;
  return true; // native accepted a request; written/reload status remains unknown
}

@addMethod(PlayerPuppet)
public final func NLSRebornApartmentState() -> Int32 {
  let systems: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(this.GetGame());
  if !IsDefined(systems) { return -1; };
  let prevention: ref<PreventionSystem> = systems.Get(n"PreventionSystem") as PreventionSystem;
  if !IsDefined(prevention) { return -1; };
  let district: wref<District> = prevention.GetCurrentDistrict();
  if !IsDefined(district) { return -1; };
  let record: ref<District_Record> = district.GetDistrictRecord();
  if !IsDefined(record) { return -1; };
  if Equals(record.Type(), gamedataDistrict.LittleChina_VApartment) { return 1; };
  return 0;
}

// Source-backed read-only readiness; unknown services fail closed.
@addMethod(PlayerPuppet)
public final func NLSRebornPausedState() -> Int32 {
  let time: ref<TimeSystem> = GameInstance.GetTimeSystem(this.GetGame());
  if !IsDefined(time) { return -1; };
  if time.IsPausedState() { return 1; };
  return 0;
}
@addMethod(PlayerPuppet)
public final func NLSRebornMenuState() -> Int32 {
  let boards: ref<BlackboardSystem> = GameInstance.GetBlackboardSystem(this.GetGame());
  if !IsDefined(boards) { return -1; };
  let board: ref<IBlackboard> = boards.Get(GetAllBlackboardDefs().UI_System);
  if !IsDefined(board) { return -1; };
  if board.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu) { return 1; };
  return 0;
}
@addMethod(PlayerPuppet)
public final func NLSRebornMountedState() -> Int32 {
  if VehicleComponent.IsMountedToVehicle(this.GetGame(), this) { return 1; };
  return 0;
}
// Journal completion evidence is request metadata, not save completion evidence.
@addMethod(PlayerPuppet)
public final func NLSRebornQuestMilestoneState(hash: Uint32) -> Int32 {
  let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGame());
  if !IsDefined(journal) { return -1; };
  let entry: wref<JournalEntry> = journal.GetEntry(hash);
  if !IsDefined(entry) { return -1; };
  if NotEquals(journal.GetEntryState(entry), gameJournalEntryState.Succeeded) { return 0; };
  if IsDefined(entry as JournalQuest) { return 1; };
  if IsDefined(entry as JournalQuestObjective) { return 2; };
  return 0;
}
@addMethod(PlayerPuppet)
public final func NLSRebornAutosaveSetEnabled(enabled: Bool) -> Void {
  this.nlsAutosaveEnabled = enabled;
  if !enabled && this.nlsDeferredSource == 3 { this.nlsDeferredPending = false; };
}
// Autosave uses the game phone manager rather than the notification-only
// PhoneCallInformation bridge. The manager answers whether any phone call is
// active; a missing manager remains UNKNOWN. Notification context below keeps
// its stricter StartCall semantics.
@addMethod(PlayerPuppet)
public final func NLSRebornAutosavePhoneState() -> Int32 {
  let phone: ref<questPhoneManager> = GameInstance.GetPhoneManager(this.GetGame());
  if !IsDefined(phone) { return -1; };
  if phone.IsPhoneCallActive() { return 1; };
  return 0;
}
@addMethod(PlayerPuppet)
public final func NLSRebornAutosaveReady() -> Bool {
  return this.nlsAutosaveEnabled && this.NLSRebornDeferredNativeUnlocked() &&
    this.NLSRebornPausedState() == 0 && this.NLSRebornMenuState() == 0 && this.NLSRebornAutosavePhoneState() == 0 &&
    !this.IsInCombat() && this.NLSRebornMountedState() == 0;
}
@addMethod(PlayerPuppet)
public final func NLSRebornAutosaveQueue() -> Bool {
  // A scheduled checkpoint never replaces a player's pending request.
  if this.nlsDeferredPending || !this.NLSRebornAutosaveReady() { return false; };
  this.nlsDeferredSerial += 1;
  this.nlsDeferredSource = 3;
  this.nlsDeferredPending = true;
  return true;
}
@addMethod(PlayerPuppet)
public final func NLSRebornDeferredGetSerial() -> Int32 { return this.nlsDeferredSerial; }
@addMethod(PlayerPuppet)
public final func NLSRebornDeferredIsPending() -> Bool { return this.nlsDeferredPending; }
@addMethod(PlayerPuppet)
public final func NLSRebornDeferredGetSource() -> Int32 { return this.nlsDeferredSource; }
@addMethod(PlayerPuppet)
public final func NLSRebornDeferredCancel() -> Void { this.nlsDeferredPending = false; }
@addMethod(PlayerPuppet)
public final func NLSRebornDeferredNativeUnlocked() -> Bool {
  let locks: array<gameSaveLock>;
  // Mounted state alone does not block a player-requested checkpoint.
  return !this.nlsRebornSafetyBlock && this.NLSRebornDeferredIntroComplete() && !this.IsInCombat() &&
    !GameInstance.IsSavingLocked(this.GetGame(), locks) && ArraySize(locks) == 0;
}
@addMethod(PlayerPuppet)
public final func NLSRebornDeferredDispatch(expectedSerial: Int32) -> Bool {
  if !this.nlsDeferredPending || this.nlsDeferredSerial != expectedSerial || !this.NLSRebornDeferredNativeUnlocked() { return false; };
  if this.nlsDeferredSource == 3 {
    if !this.NLSRebornAutosaveReady() { return false; };
  } else {
    if !this.nlsDeferredEnabled || (this.nlsDeferredSource != 1 && this.nlsDeferredSource != 2) { return false; };
  };
  let autosave: ref<gameAutoSaveSystem> = GameInstance.GetAutoSaveSystem(this.GetGame());
  if !IsDefined(autosave) { return false; };
  this.nlsDeferredPending = false; // clear before dispatch to prevent duplicates
  if !this.NLSRebornRequestCheckpoint(this.nlsDeferredSource) { return false; };
  let context: Int32 = NLSRebornPolicy.GetImmersionSaveContext(this.GetGame());
  if context > 0 {
    NLSRebornPolicy.NotifyImmersionSaveRequest(this.GetGame(), context, true);
  } else if this.NLSRebornGetNotificationsEnabled() {
    PauseMenuGameController.NLSRebornNotify(this.GetGame(), NLSRebornPolicy.CheckpointMessage(this.GetGame(), -1));
  };
  return true; // request submitted, NOT save completion
}

// v0.9.2: DF conditions permit Immersion save attempts; options control messages only.
@addField(PlayerPuppet) public let nlsRebornDFNotifyVehicleSleep: Bool = true;
@addField(PlayerPuppet) public let nlsRebornDFNotifyAddiction: Bool = true;
@addField(PlayerPuppet) public let nlsRebornDFNotifyStarvation: Bool = true;
@addField(PlayerPuppet) public let nlsRebornDFNotifyDehydration: Bool = true;
@addField(PlayerPuppet) public let nlsRebornDFVehicleSleepState: Int32;
@addField(PlayerPuppet) public let nlsRebornDFAddictionState: Int32;
@addField(PlayerPuppet) public let nlsRebornDFStarvationState: Int32;
@addField(PlayerPuppet) public let nlsRebornDFDehydrationState: Int32;
@addField(PlayerPuppet) public let nlsRebornDFLastReason: Int32 = 0;
@addField(PlayerPuppet) public let nlsRebornDFLastNotificationContext: Int32 = 0;
@addField(PlayerPuppet) public let nlsRebornDFPolicyStatus: String = "Not checked this session";

// Initialize cached unknown states before either public diagnostic reader is used.
@addField(PlayerPuppet) private let nlsRebornDFStateInitialized: Bool = false;

@addMethod(PlayerPuppet)
public final func NLSRebornEnsureDFStateInitialized() -> Void {
  if this.nlsRebornDFStateInitialized { return; };
  this.nlsRebornDFVehicleSleepState = -1;
  this.nlsRebornDFAddictionState = -1;
  this.nlsRebornDFStarvationState = -1;
  this.nlsRebornDFDehydrationState = -1;
  this.nlsRebornDFStateInitialized = true;
}

@addMethod(PlayerPuppet)
public final func NLSRebornSetDFNotifications(vehicleSleep: Bool, addiction: Bool, starvation: Bool, dehydration: Bool) -> Void {
  this.nlsRebornDFNotifyVehicleSleep = vehicleSleep;
  this.nlsRebornDFNotifyAddiction = addiction;
  this.nlsRebornDFNotifyStarvation = starvation;
  this.nlsRebornDFNotifyDehydration = dehydration;
}

@addMethod(PlayerPuppet)
public final func NLSRebornGetDFNotificationMask() -> Int32 {
  let mask: Int32 = 0;
  if this.nlsRebornDFNotifyVehicleSleep { mask += 1; };
  if this.nlsRebornDFNotifyAddiction { mask += 2; };
  if this.nlsRebornDFNotifyStarvation { mask += 4; };
  if this.nlsRebornDFNotifyDehydration { mask += 8; };
  return mask;
}

@addMethod(PlayerPuppet)
public final func NLSRebornGetDFPolicyStatus() -> String {
  this.NLSRebornEnsureDFStateInitialized();
  return this.nlsRebornDFPolicyStatus + " | sleep=" + ToString(this.nlsRebornDFVehicleSleepState) +
    " | addiction=" + ToString(this.nlsRebornDFAddictionState) +
    " | starving=" + ToString(this.nlsRebornDFStarvationState) +
    " | dehydrated=" + ToString(this.nlsRebornDFDehydrationState) +
    " | saveContext=" + ToString(this.nlsRebornDFLastReason) +
    " | notificationContext=" + ToString(this.nlsRebornDFLastNotificationContext);
}

@addMethod(PlayerPuppet)
public final func NLSRebornGetDFNotificationContext() -> Int32 {
  this.NLSRebornEnsureDFStateInitialized();
  if this.nlsRebornDFNotifyVehicleSleep && this.nlsRebornDFVehicleSleepState == 1 { return 8; };
  if this.nlsRebornDFNotifyDehydration && this.nlsRebornDFDehydrationState == 1 { return 11; };
  if this.nlsRebornDFNotifyStarvation && this.nlsRebornDFStarvationState == 1 { return 10; };
  if this.nlsRebornDFNotifyAddiction && this.nlsRebornDFAddictionState == 1 { return 9; };
  return 0;
}

// Never Lock Saves Reborn v0.8.1 experimental
// Based on user-provided Never Lock Saves v2.2.1.0.
// The fallback requests a forced checkpoint; it DOES NOT bypass engine save locks.
// Leave Immersion Mode enabled by default. Validate on a throwaway save.

// v0.3 experimental: runtime bridge via PlayerPuppet, reset on load/restart.
// 0 = Vanilla, 1 = Immersion, 2 = Unrestricted (experimental)
@addField(PlayerPuppet)
public let nlsRebornMode: Int32;

@addField(PlayerPuppet)
public let nlsRebornAllowCombat: Bool;

@addField(PlayerPuppet)
public let nlsRebornAllowVehicle: Bool;

// Smart Mode: runtime observations are tri-state, unknown is fail-closed.
@addField(PlayerPuppet)
public let nlsRebornCombatKnown: Bool;
@addField(PlayerPuppet)
public let nlsRebornCombatActive: Bool;
@addField(PlayerPuppet)
public let nlsRebornVehicleKnown: Bool;
@addField(PlayerPuppet)
public let nlsRebornVehicleActive: Bool;

@addMethod(PlayerPuppet)
public final func NLSRebornSetObservedState(combatKnown: Bool, combatActive: Bool, vehicleKnown: Bool, vehicleActive: Bool) -> Void {
  this.nlsRebornCombatKnown = combatKnown;
  this.nlsRebornCombatActive = combatActive;
  this.nlsRebornVehicleKnown = vehicleKnown;
  this.nlsRebornVehicleActive = vehicleActive;
}


// Context is supplied by CET when sensors are available. Unknown contexts use general messages.
// 0 general, 1 combat, 2 vehicle, 3 vehicle combat, 4 stealth, 5 phone-blocked.
@addField(PlayerPuppet)
public let nlsRebornContext: Int32;
// 0 unknown, 1 feminine body, 2 masculine body. Internal field name retained for ABI.
@addField(PlayerPuppet)
public let nlsRebornVoice: Int32;
@addField(PlayerPuppet)
public let nlsRebornSafetyBlock: Bool;


@addMethod(PlayerPuppet)
public final func NLSRebornSetContext(context: Int32, voice: Int32, safetyBlock: Bool) -> Void {
  this.nlsRebornContext = context;
  this.nlsRebornVoice = voice;
  this.nlsRebornSafetyBlock = safetyBlock;
}


@addMethod(PlayerPuppet)
public final func NLSRebornSetMode(mode: Int32) -> Void {
  // Changing a preset does not erase explicit queued intent. Cancel/disable do.
  if mode >= 0 && mode <= 3 { this.nlsRebornMode = mode; };
}

@addMethod(PlayerPuppet)
public final func NLSRebornSetOptions(combat: Bool, vehicle: Bool) -> Void {
  this.nlsRebornAllowCombat = combat;
  this.nlsRebornAllowVehicle = vehicle;
}

@addMethod(PlayerPuppet)
public final func NLSRebornGetCombat() -> Bool { return this.nlsRebornAllowCombat; }

@addMethod(PlayerPuppet)
public final func NLSRebornGetVehicle() -> Bool { return this.nlsRebornAllowVehicle; }

@addField(PlayerPuppet)
public let nlsRebornNotificationsEnabled: Bool;

@addMethod(PlayerPuppet)
public final func NLSRebornSetNotificationsEnabled(enabled: Bool) -> Void { this.nlsRebornNotificationsEnabled = enabled; }

@addMethod(PlayerPuppet)
public final func NLSRebornGetNotificationsEnabled() -> Bool { return this.nlsRebornNotificationsEnabled; }


@addMethod(PlayerPuppet)
public final func NLSRebornGetMode() -> Int32 { return this.nlsRebornMode; }

// NLSR-003: message selection only. No save permission changes.
@addField(PlayerPuppet) private let nlsRebornNotificationPool: String = "No checkpoint notification selected";
// The supplied DFVehicleSleepSystem reads this exact blackboard/struct/enum.
// Only StartCall qualifies; missing data is UNKNOWN, ringing/ended phases do not.
@addMethod(PlayerPuppet)
public final func NLSRebornNotificationPhoneState() -> Int32 {
  let boards: ref<BlackboardSystem> = GameInstance.GetBlackboardSystem(this.GetGame());
  if !IsDefined(boards) { return -1; };
  let board: ref<IBlackboard> = boards.Get(GetAllBlackboardDefs().UI_ComDevice);
  if !IsDefined(board) { return -1; };
  let infoVariant: Variant = board.GetVariant(GetAllBlackboardDefs().UI_ComDevice.PhoneCallInformation);
  if !IsDefined(infoVariant) { return -1; };
  let info: PhoneCallInformation = FromVariant<PhoneCallInformation>(infoVariant);
  if Equals(info.callPhase, questPhoneCallPhase.StartCall) { return 1; };
  return 0;
}
@addMethod(PlayerPuppet)
public final func NLSRebornGetNotificationDiagnostics() -> String { return this.nlsRebornNotificationPool; }
@addMethod(PlayerPuppet)
public final func NLSRebornGetNotificationCategory() -> Int32 { return NLSRebornPolicy.NotificationContext(this.GetGame()); }

public class NLSRebornPolicy {
  public static func Version() -> String { return "1.0.0"; }
  public static func NotificationContext(game: GameInstance) -> Int32 {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(game).GetLocalPlayerControlledGameObject() as PlayerPuppet;
    if !IsDefined(player) { return 0; };
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    let activeCall: Bool = player.NLSRebornNotificationPhoneState() == 1;
    // Known active q000 only. Unknown/uninitialized or completed facts cannot
    // select introduction text, even if an old cached save guard remains true.
    if IsDefined(quests) && quests.GetFact(n"q000_started") > 0 &&
      quests.GetFact(n"q000_done") == 0 && quests.GetFact(n"q001_started") == 0 {
      if activeCall && quests.GetFact(n"q000_corpo_background") > 0 { return 12; };
      return 7;
    };
    if activeCall { return 5; };
    let combat: Bool = player.IsInCombat();
    let vehicle: Bool = VehicleComponent.IsMountedToVehicle(game, player);
    if combat && vehicle { return 3; };
    if combat { return 1; };
    if vehicle { return 2; };
    // Retain the existing protected CET crouch sample; unknown stays exploration.
    if player.nlsRebornContext == 4 { return 4; };
    return 0;
  }
  public static func NotificationCategoryName(context: Int32) -> String {
    if context == 12 { return "Prologue Protection / Corpo call"; };
    if context == 7 { return "Prologue Protection"; };
    if context == 5 { return "Phone call"; };
    if context == 3 { return "Vehicle combat"; };
    if context == 1 { return "Combat"; };
    if context == 2 { return "Vehicle"; };
    if context == 4 { return "Stealth"; };
    return "Exploration";
  }
  public static func CheckpointMessage(game: GameInstance, overrideContext: Int32) -> String {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(game).GetLocalPlayerControlledGameObject() as PlayerPuppet;
    if !IsDefined(player) || !player.NLSRebornGetNotificationsEnabled() { return ""; };
    let context: Int32 = NLSRebornPolicy.NotificationContext(game);
    // Reserved middle pool component stays zero for support-report compatibility.
    player.nlsRebornNotificationPool = NLSRebornPolicy.NotificationCategoryName(context) +
      " | pool=" + ToString(context) + "/0/" + ToString(player.nlsRebornVoice) +
      " | mode=" + ToString(player.NLSRebornGetMode()) + " | saveProtection=" + ToString(player.nlsRebornSafetyBlock);
    if context == 12 { return "Saving is unavailable during the introduction call."; };
    if context == 7 { return "Saving is unavailable during the introduction."; };
    if context == 5 { return "Saving game during a phone call..."; };
    if context == 3 { return "Saving game during vehicle combat..."; };
    if context == 1 { return "Saving game during combat..."; };
    if context == 2 { return "Saving game while in a vehicle..."; };
    if context == 4 { return "Saving game while in stealth..."; };
    return "Saving game...";
  }
  // A fresh DF context selects Immersion notifications; it never grants save permission.
  // Notification switches and notification availability never decide save routing.
  public static func GetImmersionSaveContext(game: GameInstance) -> Int32 {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(game).GetLocalPlayerControlledGameObject() as PlayerPuppet;
    if !IsDefined(player) { return 0; };
    if player.NLSRebornGetMode() != 1 || player.nlsRebornSafetyBlock || !player.NLSRebornDeferredIntroComplete() { return 0; };
    let state: ref<NLSRebornDFState> = NLSRebornDFPolicy.Read(player);
    player.NLSRebornEnsureDFStateInitialized();
    player.nlsRebornDFVehicleSleepState = state.vehicleSleep;
    player.nlsRebornDFAddictionState = state.addiction;
    player.nlsRebornDFStarvationState = state.starvation;
    player.nlsRebornDFDehydrationState = state.dehydration;
    player.nlsRebornDFPolicyStatus = state.status;
    player.nlsRebornDFLastNotificationContext = 0;
    let context: Int32 = 0;
    if state.vehicleSleep == 1 { context = 8; };
    if context == 0 && state.dehydration == 1 { context = 11; };
    if context == 0 && state.starvation == 1 { context = 10; };
    if context == 0 && state.addiction == 1 { context = 9; };
    player.nlsRebornDFLastReason = context;
    return context;
  }
  public static func NotifyImmersionSaveRequest(game: GameInstance, context: Int32, checkpoint: Bool) -> Void {
    if context <= 0 { return; };
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(game).GetLocalPlayerControlledGameObject() as PlayerPuppet;
    if !IsDefined(player) || !player.NLSRebornGetNotificationsEnabled() { return; };
    let notificationContext: Int32 = player.NLSRebornGetDFNotificationContext();
    player.nlsRebornDFLastNotificationContext = notificationContext;
    if notificationContext <= 0 { return; };
    let message: String = NLSRebornDFMessages.Message(game, notificationContext, checkpoint);
    PauseMenuGameController.NLSRebornNotify(game, message);
  }
  public static func IsProtectedIntroduction(game: GameInstance) -> Bool {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(game).GetLocalPlayerControlledGameObject() as PlayerPuppet;
    return IsDefined(player) && player.nlsRebornSafetyBlock;
  }
  // Smart queue admission is independent of permission to force a checkpoint.
  // Called for combat or native-locked user requests, after quicksave busy guards.
  public static func HandleSmartBlockedSave(game: GameInstance, source: Int32) -> Bool {
    // Historical public name retained. All Reborn modes share blocked-request policy.
    let players: ref<PlayerSystem> = GameInstance.GetPlayerSystem(game);
    if !IsDefined(players) { return false; };
    let player: ref<PlayerPuppet> = players.GetLocalPlayerControlledGameObject() as PlayerPuppet;
    if !IsDefined(player) || player.NLSRebornGetMode() == 0 || player.nlsRebornSafetyBlock || !player.NLSRebornDeferredIntroComplete() { return false; };
    if player.NLSRebornDeferredQueue(source) {
      if player.NLSRebornGetNotificationsEnabled() && !player.NLSRebornGetStatusNotificationsEnabled() {
        PauseMenuGameController.NLSRebornNotify(game, "Save queued. Waiting until saving is available.");
      };
      return true;
    };
    if player.NLSRebornGetNotificationsEnabled() {
      let message: String = "Saving is blocked by the current game state. No save was queued.";
      PauseMenuGameController.NLSRebornNotify(game, message);
    };
    return true;
  }
  // Legacy exception entry points are retained as disabled compatibility shims.
  public static func SmartCombatFallback(game: GameInstance) -> Bool {
    // Compatibility shim. Legacy settings no longer permit a combat-lock exception.
    return false;
  }
  public static func AllowForcedCheckpointFallback(game: GameInstance) -> Bool {
    // Compatibility shim. Blocked requests must queue or remain blocked.
    return false;
  }
  public static func IsRequestBlocked(game: GameInstance) -> Bool {
    let locks: array<gameSaveLock>;
    if GameInstance.IsSavingLocked(game, locks) || ArraySize(locks) > 0 { return true; };
    let players: ref<PlayerSystem> = GameInstance.GetPlayerSystem(game);
    if !IsDefined(players) { return true; };
    let player: ref<PlayerPuppet> = players.GetLocalPlayerControlledGameObject() as PlayerPuppet;
    if !IsDefined(player) { return true; };
    return player.IsInCombat();
  }
}

@addMethod(PlayerPuppet)
public final func NLSRebornShowActivation() -> Void {
  PauseMenuGameController.NLSRebornNotify(this.GetGame(), "Never Lock Saves: Reborn is now active.");
}

@addMethod(PauseMenuGameController)
public final static func NLSRebornNotify(game: GameInstance, message: String) -> Void {
  if Equals(message, "") { return; };
  let event: ref<UIInGameNotificationEvent> = new UIInGameNotificationEvent();
  event.m_isNLSRebornNotification = true;
  event.m_title = message;
  GameInstance.GetUISystem(game).QueueEvent(event);
}

@addField(UIInGameNotificationEvent)
public let m_isNLSRebornNotification: Bool = false;

@wrapMethod(UIInGameNotificationQueue)
protected cb func OnUINotification(evt: ref<UIInGameNotificationEvent>) -> Bool {
  let newNotificationData: gameuiGenericNotificationData;
  let newUserData: ref<UIInGameNotificationViewData>;
  if evt.m_isNLSRebornNotification {
    newUserData = new UIInGameNotificationViewData();
    newUserData.title = evt.m_title;
    newUserData.soundEvent = n"QuestSuccessPopup";
    newUserData.soundAction = n"OnOpen";
    newNotificationData.time = this.m_duration;
    newNotificationData.widgetLibraryItemName = n"ingame_popups_side";
    newNotificationData.notificationData = newUserData;
    this.AddNewNotificationData(newNotificationData);
    return true;
  };
  return wrappedMethod(evt);
}

// Wrap instead of replace to preserve other mods' original behavior whenever possible.
@wrapMethod(PauseMenuGameController)
private final func HandlePressToSaveGame(target: wref<inkWidget>) -> Void {
  let dfContext: Int32 = NLSRebornPolicy.GetImmersionSaveContext(this.m_gameInstance);
  if NLSRebornPolicy.IsRequestBlocked(this.m_gameInstance) {
    if NLSRebornPolicy.HandleSmartBlockedSave(this.m_gameInstance, 1) { return; };
    if NLSRebornPolicy.IsProtectedIntroduction(this.m_gameInstance) {
      PauseMenuGameController.NLSRebornNotify(this.m_gameInstance, NLSRebornPolicy.CheckpointMessage(this.m_gameInstance, 7));
      return;
    };
    wrappedMethod(target);
    return;
  };
  wrappedMethod(target);
  if dfContext > 0 { NLSRebornPolicy.NotifyImmersionSaveRequest(this.m_gameInstance, dfContext, false); };
}

@wrapMethod(PauseMenuGameController)
private final func HandlePressToQuickSaveGame() -> Void {
  let dfContext: Int32 = NLSRebornPolicy.GetImmersionSaveContext(this.m_gameInstance);
  if NLSRebornPolicy.IsRequestBlocked(this.m_gameInstance) {
    if !this.m_quickSaveInProgress && !this.IsSaveFailedNotificationActive() && !this.IsGameSavedNotificationActive() {
      if NLSRebornPolicy.HandleSmartBlockedSave(this.m_gameInstance, 2) { return; };
    };
    if NLSRebornPolicy.IsProtectedIntroduction(this.m_gameInstance) {
      PauseMenuGameController.NLSRebornNotify(this.m_gameInstance, NLSRebornPolicy.CheckpointMessage(this.m_gameInstance, 7));
      return;
    };
    wrappedMethod();
    return;
  };
  let dfNotifyRequest: Bool = dfContext > 0 && !this.m_quickSaveInProgress && !this.IsSaveFailedNotificationActive() && !this.IsGameSavedNotificationActive();
  wrappedMethod();
  if dfNotifyRequest { NLSRebornPolicy.NotifyImmersionSaveRequest(this.m_gameInstance, dfContext, false); };
}

@wrapMethod(gameuiInGameMenuGameController)
private final func HandleQuickSave() -> Void {
  if !IsDefined(this.GetPlayerControlledObject()) { wrappedMethod(); return; };
  let game: GameInstance = this.GetPlayerControlledObject().GetGame();
  let dfContext: Int32 = NLSRebornPolicy.GetImmersionSaveContext(game);
  if NLSRebornPolicy.IsRequestBlocked(game) {
    if !this.m_quickSaveInProgress && NLSRebornPolicy.HandleSmartBlockedSave(game, 2) { return; };
    if NLSRebornPolicy.IsProtectedIntroduction(game) {
      PauseMenuGameController.NLSRebornNotify(game, NLSRebornPolicy.CheckpointMessage(game, 7));
      return;
    };
    wrappedMethod();
    return;
  };
  let dfNotifyRequest: Bool = dfContext > 0 && !this.m_quickSaveInProgress;
  wrappedMethod();
  if dfNotifyRequest { NLSRebornPolicy.NotifyImmersionSaveRequest(game, dfContext, false); };
}
