// v1.0.0-vehicle-diagnostic.1 Release Candidate. Deferred/autosave lanes are opt-in.
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
  // Unrestricted user requests attempt immediately; the manual queue must not intercept them.
  // A fresh user request also cancels older automatic/player work before that attempt.
  if this.NLSRebornGetMode() == 2 {
    this.nlsDeferredPending = false;
    return false;
  };
  if !this.nlsDeferredEnabled { return false; };
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
@addField(PlayerPuppet) private let nlsCheckpointCombat: Int32 = -1;
@addField(PlayerPuppet) private let nlsCheckpointMounted: Int32 = -1;
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointGetSerial() -> Int32 { return this.nlsCheckpointSerial; }
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointGetSource() -> Int32 { return this.nlsCheckpointSource; }
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointGetResult() -> Int32 { return this.nlsCheckpointResult; }
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointGetLocks() -> String { return this.nlsCheckpointLocks; }
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointGetCombat() -> Int32 { return this.nlsCheckpointCombat; }
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointGetMounted() -> Int32 { return this.nlsCheckpointMounted; }
@addMethod(PlayerPuppet)
public final func NLSRebornCheckpointFailure() -> Void {
  if !this.NLSRebornGetNotificationsEnabled() { return; };
  let message: String = "The game rejected the checkpoint request. No save confirmed.";
  let tone: Int32 = this.NLSRebornGetTone();
  if tone == 1 { message = "The game rejected the checkpoint request. Apparently a popup cannot save you."; };
  if tone == 2 { message = "The game rejected the fucking checkpoint request. No save confirmed."; };
  if this.nlsCheckpointResult == 3 {
    message = "Checkpoint service unavailable. No save requested.";
    if tone == 1 { message = "The checkpoint service did not show up for work. No save requested."; };
    if tone == 2 { message = "The checkpoint service is fucking unavailable. No save requested."; };
  };
  if this.nlsCheckpointResult == 4 {
    message = "Checkpoint request blocked by protection or invalid source. No save requested.";
    if tone == 1 { message = "Checkpoint protection still has the keys. No save requested."; };
    if tone == 2 { message = "Checkpoint protection blocked this damn request. No save requested."; };
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
  if (source != 1 && source != 2 && source != 3) || this.nlsRebornSafetyBlock || !this.NLSRebornDeferredIntroComplete() {
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
@addMethod(PlayerPuppet)
public final func NLSRebornAutosaveReady() -> Bool {
  return this.nlsAutosaveEnabled && this.NLSRebornDeferredNativeUnlocked() &&
    this.NLSRebornPausedState() == 0 && this.NLSRebornMenuState() == 0 && this.NLSRebornNotificationPhoneState() == 0 &&
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
  return !this.nlsRebornSafetyBlock && this.NLSRebornDeferredIntroComplete() && !GameInstance.IsSavingLocked(this.GetGame(), locks);
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
    PauseMenuGameController.NLSRebornNotify(this.GetGame(), NLSRebornPolicy.CheckpointMessage(this.GetGame(), -1) + " (Request accepted; save creation unconfirmed.)");
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
@addField(PlayerPuppet)
public let nlsRebornGeneralIndex: Int32;
@addField(PlayerPuppet) public let nlsRebornCombatIndex: Int32;
@addField(PlayerPuppet) public let nlsRebornVehicleIndex: Int32;
@addField(PlayerPuppet) public let nlsRebornVehicleCombatIndex: Int32;
@addField(PlayerPuppet) public let nlsRebornStealthIndex: Int32;
@addField(PlayerPuppet) public let nlsRebornPhoneIndex: Int32;
@addField(PlayerPuppet) public let nlsRebornBlockedIndex: Int32;

@addField(PlayerPuppet) public let nlsRC2Index_0_0_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_0_0_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_0_1_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_0_1_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_0_2_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_0_2_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_1_0_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_1_0_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_1_1_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_1_1_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_1_2_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_1_2_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_2_0_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_2_0_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_2_1_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_2_1_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_2_2_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_2_2_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_3_0_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_3_0_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_3_1_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_3_1_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_3_2_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_3_2_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_4_0_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_4_0_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_4_1_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_4_1_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_4_2_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_4_2_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_5_0_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_5_0_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_5_1_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_5_1_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_5_2_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_5_2_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_6_0_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_6_0_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_6_1_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_6_1_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_6_2_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_6_2_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_7_0_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_7_0_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_7_1_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_7_1_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_7_2_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_7_2_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_12_0_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_12_0_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_12_1_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_12_1_2: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_12_2_1: Int32;
@addField(PlayerPuppet) public let nlsRC2Index_12_2_2: Int32;
@addField(PlayerPuppet) public let nlsNeutralIntroCall0: Int32;
@addField(PlayerPuppet) public let nlsNeutralIntroCall1: Int32;
@addField(PlayerPuppet) public let nlsNeutralIntroCall2: Int32;

@addMethod(PlayerPuppet)
public final func NLSRebornSetContext(context: Int32, voice: Int32, safetyBlock: Bool) -> Void {
  this.nlsRebornContext = context;
  this.nlsRebornVoice = voice;
  this.nlsRebornSafetyBlock = safetyBlock;
}

@addField(PlayerPuppet)
public let nlsRebornShuffleSeed: Int32;
@addMethod(PlayerPuppet)
public final func NLSRebornSetShuffleSeed(seed: Int32) -> Void {
  this.nlsRebornShuffleSeed = seed;
}
@addField(PlayerPuppet) public let nlsNeutralPrologue0: Int32;
@addField(PlayerPuppet) public let nlsNeutralPrologue1: Int32;
@addField(PlayerPuppet) public let nlsNeutralPrologue2: Int32;
@addField(PlayerPuppet) public let nlsNeutralOther0: Int32;
@addField(PlayerPuppet) public let nlsNeutralOther1: Int32;
@addField(PlayerPuppet) public let nlsNeutralOther2: Int32;
@addField(PlayerPuppet)
public let nlsRebornTone: Int32;

@addMethod(PlayerPuppet)
public final func NLSRebornSetMode(mode: Int32) -> Void {
  if mode >= 0 && mode <= 3 {
    // Do not carry an old manual queue into Unrestricted and dispatch it later.
    // Source 3 belongs to the separately enabled, native-gated automatic lane.
    if mode == 2 && (this.nlsDeferredSource == 1 || this.nlsDeferredSource == 2) { this.nlsDeferredPending = false; };
    this.nlsRebornMode = mode;
  };
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
public final func NLSRebornSetTone(tone: Int32) -> Void {
  if tone >= 0 && tone <= 2 { this.nlsRebornTone = tone; };
}

@addMethod(PlayerPuppet)
public final func NLSRebornGetTone() -> Int32 { return this.nlsRebornTone; }

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
  public static func Version() -> String { return "1.0.0-vehicle-diagnostic.1"; }
  public static func ShuffleSlot(index: Int32, seed: Int32) -> Int32 {
    let cycle: Int32 = index / 20;
    let turn: Int32 = index % 20;
    let selector: Int32 = (seed + cycle * 17) % 8;
    let stride: Int32 = 1;
    if selector == 1 { stride = 3; };
    if selector == 2 { stride = 7; };
    if selector == 3 { stride = 9; };
    if selector == 4 { stride = 11; };
    if selector == 5 { stride = 13; };
    if selector == 6 { stride = 17; };
    if selector == 7 { stride = 19; };
    let offset: Int32 = (seed + cycle * 11 + cycle * cycle * 3) % 20;
    if cycle > 0 {
      let priorSelector: Int32 = (seed + (cycle - 1) * 17) % 8;
      let priorStride: Int32 = 1;
      if priorSelector == 1 { priorStride = 3; };
      if priorSelector == 2 { priorStride = 7; };
      if priorSelector == 3 { priorStride = 9; };
      if priorSelector == 4 { priorStride = 11; };
      if priorSelector == 5 { priorStride = 13; };
      if priorSelector == 6 { priorStride = 17; };
      if priorSelector == 7 { priorStride = 19; };
      let priorOffset: Int32 = (seed + (cycle - 1) * 11 + (cycle - 1) * (cycle - 1) * 3) % 20;
      if offset == (19 * priorStride + priorOffset) % 20 { offset = (offset + 1) % 20; };
    };
    return (turn * stride + offset) % 20;
  }
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
    let tone: Int32 = player.NLSRebornGetTone();
    let voice: Int32 = player.nlsRebornVoice;
    let index: Int32 = 0;
    player.nlsRebornNotificationPool = NLSRebornPolicy.NotificationCategoryName(context) +
      " | pool=" + ToString(context) + "/" + ToString(tone) + "/" + ToString(voice) +
      " | mode=" + ToString(player.NLSRebornGetMode()) + " | saveProtection=" + ToString(player.nlsRebornSafetyBlock);
    if voice != 1 && voice != 2 {
      if tone == 0 {
        if context == 12 { index = player.nlsNeutralIntroCall0; player.nlsNeutralIntroCall0 += 1; } else if context == 7 { index = player.nlsNeutralPrologue0; player.nlsNeutralPrologue0 += 1; } else { index = player.nlsNeutralOther0; player.nlsNeutralOther0 += 1; };
      };
      if tone == 1 {
        if context == 12 { index = player.nlsNeutralIntroCall1; player.nlsNeutralIntroCall1 += 1; } else if context == 7 { index = player.nlsNeutralPrologue1; player.nlsNeutralPrologue1 += 1; } else { index = player.nlsNeutralOther1; player.nlsNeutralOther1 += 1; };
      };
      if tone == 2 {
        if context == 12 { index = player.nlsNeutralIntroCall2; player.nlsNeutralIntroCall2 += 1; } else if context == 7 { index = player.nlsNeutralPrologue2; player.nlsNeutralPrologue2 += 1; } else { index = player.nlsNeutralOther2; player.nlsNeutralOther2 += 1; };
      };
      let neutralSlot: Int32 = NLSRebornPolicy.ShuffleSlot(index, player.nlsRebornShuffleSeed);
      if context == 7 || context == 12 {
        if tone == 0 {
          if neutralSlot == 0 { return "Saving is unavailable during the introduction."; };
          if neutralSlot == 1 { return "Complete the introduction before saving."; };
          if neutralSlot == 2 { return "The prologue currently uses standard save restrictions."; };
          if neutralSlot == 3 { return "Saving activates after the opening montage."; };
          if neutralSlot == 4 { return "This checkpoint is blocked until the prologue ends."; };
          if neutralSlot == 5 { return "Please finish the introduction first."; };
          if neutralSlot == 6 { return "Prologue Protection is active."; };
          if neutralSlot == 7 { return "This part of the story is protected."; };
          if neutralSlot == 8 { return "The opening quest must finish before forced saving."; };
          if neutralSlot == 9 { return "Continue to The Rescue to activate Reborn."; };
          if neutralSlot == 10 { return "This checkpoint request was blocked."; };
          if neutralSlot == 11 { return "Introductory saves follow the game defaults."; };
          if neutralSlot == 12 { return "Reborn saving is not yet active."; };
          if neutralSlot == 13 { return "The introduction does not permit this save."; };
          if neutralSlot == 14 { return "Saving remains restricted until the montage completes."; };
          if neutralSlot == 15 { return "The introductory save lock is preserved."; };
          if neutralSlot == 16 { return "Finish your lifepath introduction first."; };
          if neutralSlot == 17 { return "Reborn activates after the opening montage."; };
          if neutralSlot == 18 { return "This sequence is protected from forced checkpoints."; };
          if neutralSlot == 19 { return "Your save request was blocked to protect progression."; };
        };
        if tone == 1 {
          if neutralSlot == 0 { return "The story has barely started. Give it a minute."; };
          if neutralSlot == 1 { return "Saving already? The introduction would like to introduce itself."; };
          if neutralSlot == 2 { return "Try finishing the prologue before arguing with the save system."; };
          if neutralSlot == 3 { return "The prologue called. It says no."; };
          if neutralSlot == 4 { return "You cannot speedrun quest stability, genius."; };
          if neutralSlot == 5 { return "Jackie has not finished his paperwork. No saves yet."; };
          if neutralSlot == 6 { return "The opening credits are still warm. Patience."; };
          if neutralSlot == 7 { return "Your impatience has been noted. Your save has not."; };
          if neutralSlot == 8 { return "Apparently we have to finish the introduction first. Shocking."; };
          if neutralSlot == 9 { return "The game would prefer its opening quest in one piece."; };
          if neutralSlot == 10 { return "Nice try. The prologue still has the keys."; };
          if neutralSlot == 11 { return "This is the one part where the save mod says wait."; };
          if neutralSlot == 12 { return "You have discovered the ancient art of not saving yet."; };
          if neutralSlot == 13 { return "Prologue Protection says enjoy the story for once."; };
          if neutralSlot == 14 { return "The save button is not a skip-intro button."; };
          if neutralSlot == 15 { return "A bold request. The answer remains no."; };
          if neutralSlot == 16 { return "The Jackie montage is not optional paperwork."; };
          if neutralSlot == 17 { return "Please refrain from speedrunning quest corruption."; };
          if neutralSlot == 18 { return "No checkpoint for you. Try making it to The Rescue."; };
          if neutralSlot == 19 { return "Even Night City needs a moment to initialize."; };
        };
        if tone == 2 {
          if neutralSlot == 0 { return "FINISH THE FUCKING INTRODUCTION, YOU IMPATIENT MENACE."; };
          if neutralSlot == 1 { return "NO SAVE, DUMBASS. LET THE QUEST FUCKING START."; };
          if neutralSlot == 2 { return "KEEP YOUR HANDS OFF THE CHECKPOINT, YOU CHAOTIC SHIT."; };
          if neutralSlot == 3 { if context == 12 { return "JACKIE IS STILL TALKING. STOP BREAKING THE FUCKING TIMELINE."; }; return "THE INTRO IS STILL RUNNING. STOP BREAKING THE FUCKING TIMELINE."; };
          if neutralSlot == 4 { return "YOU WANT A SAVE? SURVIVE THE GODDAMN INTRO FIRST."; };
          if neutralSlot == 5 { return "FUCK OFF WITH THAT CHECKPOINT UNTIL THE MONTAGE ENDS."; };
          if neutralSlot == 6 { return "THIS QUEST IS HELD TOGETHER WITH HOPE. STOP POKING IT, ASSHOLE."; };
          if neutralSlot == 7 { return "NO, YOU SAVE-SPAMMING BASTARD."; };
          if neutralSlot == 8 { return "YOUR IMPATIENCE IS NOT A VALID FUCKING SAVE STATE."; };
          if neutralSlot == 9 { return "LET THE INTRO FINISH BEFORE YOU SHRED THE QUEST FLAGS."; };
          if neutralSlot == 10 { return "YOU ABSOLUTE GONK. THE FUCKING PROLOGUE IS PROTECTED."; };
          if neutralSlot == 11 { return "I AM NOT SAVING YOUR QUEST-BREAKING BULLSHIT."; };
          if neutralSlot == 12 { return "STOP CHECKPOINTING THE FIRST FIVE FUCKING MINUTES."; };
          if neutralSlot == 13 { return "YOU CAN WAIT FOR THE RESCUE, YOU UNHINGED FUCK."; };
          if neutralSlot == 14 { return "NOT TODAY, CHECKPOINT GREMLIN. FINISH THE GODDAMN INTRO."; };
          if neutralSlot == 15 { return "YOU BREAK JACKIE AGAIN AND I AM BILLING YOUR STUPID ASS."; };
          if neutralSlot == 16 { return "NO FUCKING SAVE. THE STORY HAS NOT EVEN PUT ITS SHOES ON."; };
          if neutralSlot == 17 { return "CALM YOUR SAVE-HAPPY ASS. THE MONTAGE COMES FIRST."; };
          if neutralSlot == 18 { return "THE PROLOGUE IS NOT YOUR CRASH-TEST DUMMY, DIPSHIT."; };
          if neutralSlot == 19 { return "YOU CAN HAVE YOUR FUCKING CHECKPOINT AFTER THE INTRO."; };
        };
      };
      if tone == 0 { return "Save request received."; };
      if tone == 1 { return "Another checkpoint? Ambitious."; };
      return "SAVING YOUR ASS AGAIN, YOU FUCKING MENACE.";
    };
    if context == 0 && tone == 0 && voice == 1 { index = player.nlsRC2Index_0_0_1; player.nlsRC2Index_0_0_1 += 1; };
    if context == 0 && tone == 0 && voice == 2 { index = player.nlsRC2Index_0_0_2; player.nlsRC2Index_0_0_2 += 1; };
    if context == 0 && tone == 1 && voice == 1 { index = player.nlsRC2Index_0_1_1; player.nlsRC2Index_0_1_1 += 1; };
    if context == 0 && tone == 1 && voice == 2 { index = player.nlsRC2Index_0_1_2; player.nlsRC2Index_0_1_2 += 1; };
    if context == 0 && tone == 2 && voice == 1 { index = player.nlsRC2Index_0_2_1; player.nlsRC2Index_0_2_1 += 1; };
    if context == 0 && tone == 2 && voice == 2 { index = player.nlsRC2Index_0_2_2; player.nlsRC2Index_0_2_2 += 1; };
    if context == 1 && tone == 0 && voice == 1 { index = player.nlsRC2Index_1_0_1; player.nlsRC2Index_1_0_1 += 1; };
    if context == 1 && tone == 0 && voice == 2 { index = player.nlsRC2Index_1_0_2; player.nlsRC2Index_1_0_2 += 1; };
    if context == 1 && tone == 1 && voice == 1 { index = player.nlsRC2Index_1_1_1; player.nlsRC2Index_1_1_1 += 1; };
    if context == 1 && tone == 1 && voice == 2 { index = player.nlsRC2Index_1_1_2; player.nlsRC2Index_1_1_2 += 1; };
    if context == 1 && tone == 2 && voice == 1 { index = player.nlsRC2Index_1_2_1; player.nlsRC2Index_1_2_1 += 1; };
    if context == 1 && tone == 2 && voice == 2 { index = player.nlsRC2Index_1_2_2; player.nlsRC2Index_1_2_2 += 1; };
    if context == 2 && tone == 0 && voice == 1 { index = player.nlsRC2Index_2_0_1; player.nlsRC2Index_2_0_1 += 1; };
    if context == 2 && tone == 0 && voice == 2 { index = player.nlsRC2Index_2_0_2; player.nlsRC2Index_2_0_2 += 1; };
    if context == 2 && tone == 1 && voice == 1 { index = player.nlsRC2Index_2_1_1; player.nlsRC2Index_2_1_1 += 1; };
    if context == 2 && tone == 1 && voice == 2 { index = player.nlsRC2Index_2_1_2; player.nlsRC2Index_2_1_2 += 1; };
    if context == 2 && tone == 2 && voice == 1 { index = player.nlsRC2Index_2_2_1; player.nlsRC2Index_2_2_1 += 1; };
    if context == 2 && tone == 2 && voice == 2 { index = player.nlsRC2Index_2_2_2; player.nlsRC2Index_2_2_2 += 1; };
    if context == 3 && tone == 0 && voice == 1 { index = player.nlsRC2Index_3_0_1; player.nlsRC2Index_3_0_1 += 1; };
    if context == 3 && tone == 0 && voice == 2 { index = player.nlsRC2Index_3_0_2; player.nlsRC2Index_3_0_2 += 1; };
    if context == 3 && tone == 1 && voice == 1 { index = player.nlsRC2Index_3_1_1; player.nlsRC2Index_3_1_1 += 1; };
    if context == 3 && tone == 1 && voice == 2 { index = player.nlsRC2Index_3_1_2; player.nlsRC2Index_3_1_2 += 1; };
    if context == 3 && tone == 2 && voice == 1 { index = player.nlsRC2Index_3_2_1; player.nlsRC2Index_3_2_1 += 1; };
    if context == 3 && tone == 2 && voice == 2 { index = player.nlsRC2Index_3_2_2; player.nlsRC2Index_3_2_2 += 1; };
    if context == 4 && tone == 0 && voice == 1 { index = player.nlsRC2Index_4_0_1; player.nlsRC2Index_4_0_1 += 1; };
    if context == 4 && tone == 0 && voice == 2 { index = player.nlsRC2Index_4_0_2; player.nlsRC2Index_4_0_2 += 1; };
    if context == 4 && tone == 1 && voice == 1 { index = player.nlsRC2Index_4_1_1; player.nlsRC2Index_4_1_1 += 1; };
    if context == 4 && tone == 1 && voice == 2 { index = player.nlsRC2Index_4_1_2; player.nlsRC2Index_4_1_2 += 1; };
    if context == 4 && tone == 2 && voice == 1 { index = player.nlsRC2Index_4_2_1; player.nlsRC2Index_4_2_1 += 1; };
    if context == 4 && tone == 2 && voice == 2 { index = player.nlsRC2Index_4_2_2; player.nlsRC2Index_4_2_2 += 1; };
    if context == 5 && tone == 0 && voice == 1 { index = player.nlsRC2Index_5_0_1; player.nlsRC2Index_5_0_1 += 1; };
    if context == 5 && tone == 0 && voice == 2 { index = player.nlsRC2Index_5_0_2; player.nlsRC2Index_5_0_2 += 1; };
    if context == 5 && tone == 1 && voice == 1 { index = player.nlsRC2Index_5_1_1; player.nlsRC2Index_5_1_1 += 1; };
    if context == 5 && tone == 1 && voice == 2 { index = player.nlsRC2Index_5_1_2; player.nlsRC2Index_5_1_2 += 1; };
    if context == 5 && tone == 2 && voice == 1 { index = player.nlsRC2Index_5_2_1; player.nlsRC2Index_5_2_1 += 1; };
    if context == 5 && tone == 2 && voice == 2 { index = player.nlsRC2Index_5_2_2; player.nlsRC2Index_5_2_2 += 1; };
    if context == 6 && tone == 0 && voice == 1 { index = player.nlsRC2Index_6_0_1; player.nlsRC2Index_6_0_1 += 1; };
    if context == 6 && tone == 0 && voice == 2 { index = player.nlsRC2Index_6_0_2; player.nlsRC2Index_6_0_2 += 1; };
    if context == 6 && tone == 1 && voice == 1 { index = player.nlsRC2Index_6_1_1; player.nlsRC2Index_6_1_1 += 1; };
    if context == 6 && tone == 1 && voice == 2 { index = player.nlsRC2Index_6_1_2; player.nlsRC2Index_6_1_2 += 1; };
    if context == 6 && tone == 2 && voice == 1 { index = player.nlsRC2Index_6_2_1; player.nlsRC2Index_6_2_1 += 1; };
    if context == 6 && tone == 2 && voice == 2 { index = player.nlsRC2Index_6_2_2; player.nlsRC2Index_6_2_2 += 1; };
    if context == 7 && tone == 0 && voice == 1 { index = player.nlsRC2Index_7_0_1; player.nlsRC2Index_7_0_1 += 1; };
    if context == 7 && tone == 0 && voice == 2 { index = player.nlsRC2Index_7_0_2; player.nlsRC2Index_7_0_2 += 1; };
    if context == 7 && tone == 1 && voice == 1 { index = player.nlsRC2Index_7_1_1; player.nlsRC2Index_7_1_1 += 1; };
    if context == 7 && tone == 1 && voice == 2 { index = player.nlsRC2Index_7_1_2; player.nlsRC2Index_7_1_2 += 1; };
    if context == 7 && tone == 2 && voice == 1 { index = player.nlsRC2Index_7_2_1; player.nlsRC2Index_7_2_1 += 1; };
    if context == 7 && tone == 2 && voice == 2 { index = player.nlsRC2Index_7_2_2; player.nlsRC2Index_7_2_2 += 1; };
    if context == 12 && tone == 0 && voice == 1 { index = player.nlsRC2Index_12_0_1; player.nlsRC2Index_12_0_1 += 1; };
    if context == 12 && tone == 0 && voice == 2 { index = player.nlsRC2Index_12_0_2; player.nlsRC2Index_12_0_2 += 1; };
    if context == 12 && tone == 1 && voice == 1 { index = player.nlsRC2Index_12_1_1; player.nlsRC2Index_12_1_1 += 1; };
    if context == 12 && tone == 1 && voice == 2 { index = player.nlsRC2Index_12_1_2; player.nlsRC2Index_12_1_2 += 1; };
    if context == 12 && tone == 2 && voice == 1 { index = player.nlsRC2Index_12_2_1; player.nlsRC2Index_12_2_1 += 1; };
    if context == 12 && tone == 2 && voice == 2 { index = player.nlsRC2Index_12_2_2; player.nlsRC2Index_12_2_2 += 1; };
    let slot: Int32 = NLSRebornPolicy.ShuffleSlot(index, player.nlsRebornShuffleSeed);
    if context == 12 && tone == 0 && voice == 1 {
      if slot == 0 { return "The protected introduction has been noted."; };
      if slot == 1 { return "The protected introduction has been recorded."; };
      if slot == 2 { return "The protected introduction is acknowledged."; };
      if slot == 3 { return "The protected introduction remains subject to game restrictions."; };
      if slot == 4 { return "Your lifepath prologue has been noted."; };
      if slot == 5 { return "Your lifepath prologue has been recorded."; };
      if slot == 6 { return "Your lifepath prologue is acknowledged."; };
      if slot == 7 { return "Your lifepath prologue remains subject to game restrictions."; };
      if slot == 8 { return "The introductory mission has been noted."; };
      if slot == 9 { return "The introductory mission has been recorded."; };
      if slot == 10 { return "The introductory mission is acknowledged."; };
      if slot == 11 { return "The introductory mission remains subject to game restrictions."; };
      if slot == 12 { return "This early save attempt has been noted."; };
      if slot == 13 { return "This early save attempt has been recorded."; };
      if slot == 14 { return "This early save attempt is acknowledged."; };
      if slot == 15 { return "This early save attempt remains subject to game restrictions."; };
      if slot == 16 { return "The opening sequence has been noted."; };
      if slot == 17 { return "The opening sequence has been recorded."; };
      if slot == 18 { return "The opening sequence is acknowledged."; };
      if slot == 19 { return "The opening sequence remains subject to game restrictions."; };
    };
    if context == 12 && tone == 0 && voice == 2 {
      if slot == 0 { return "The protected introduction has been noted."; };
      if slot == 1 { return "The protected introduction has been recorded."; };
      if slot == 2 { return "The protected introduction is acknowledged."; };
      if slot == 3 { return "The protected introduction remains subject to game restrictions."; };
      if slot == 4 { return "Your lifepath prologue has been noted."; };
      if slot == 5 { return "Your lifepath prologue has been recorded."; };
      if slot == 6 { return "Your lifepath prologue is acknowledged."; };
      if slot == 7 { return "Your lifepath prologue remains subject to game restrictions."; };
      if slot == 8 { return "The introductory mission has been noted."; };
      if slot == 9 { return "The introductory mission has been recorded."; };
      if slot == 10 { return "The introductory mission is acknowledged."; };
      if slot == 11 { return "The introductory mission remains subject to game restrictions."; };
      if slot == 12 { return "This early save attempt has been noted."; };
      if slot == 13 { return "This early save attempt has been recorded."; };
      if slot == 14 { return "This early save attempt is acknowledged."; };
      if slot == 15 { return "This early save attempt remains subject to game restrictions."; };
      if slot == 16 { return "The opening sequence has been noted."; };
      if slot == 17 { return "The opening sequence has been recorded."; };
      if slot == 18 { return "The opening sequence is acknowledged."; };
      if slot == 19 { return "The opening sequence remains subject to game restrictions."; };
    };
    if context == 12 && tone == 1 && voice == 1 {
      if slot == 0 { return "Finish the introduction first. Very ambitious, princess."; };
      if slot == 1 { return "Finish the introduction first. Excellent timing, princess."; };
      if slot == 2 { return "Finish the introduction first. Another masterstroke, princess."; };
      if slot == 3 { return "Finish the introduction first. Your judgment is legendary, princess."; };
      if slot == 4 { return "The prologue is not a save playground. Very ambitious, princess."; };
      if slot == 5 { return "The prologue is not a save playground. Excellent timing, princess."; };
      if slot == 6 { return "The prologue is not a save playground. Another masterstroke, princess."; };
      if slot == 7 { return "The prologue is not a save playground. Your judgment is legendary, princess."; };
      if slot == 8 { return "Jackie would like you to focus. Very ambitious, princess."; };
      if slot == 9 { return "Jackie would like you to focus. Excellent timing, princess."; };
      if slot == 10 { return "Jackie would like you to focus. Another masterstroke, princess."; };
      if slot == 11 { return "Jackie would like you to focus. Your judgment is legendary, princess."; };
      if slot == 12 { return "You have barely started the game. Very ambitious, princess."; };
      if slot == 13 { return "You have barely started the game. Excellent timing, princess."; };
      if slot == 14 { return "You have barely started the game. Another masterstroke, princess."; };
      if slot == 15 { return "You have barely started the game. Your judgment is legendary, princess."; };
      if slot == 16 { return "Your shortcut has been declined. Very ambitious, princess."; };
      if slot == 17 { return "Your shortcut has been declined. Excellent timing, princess."; };
      if slot == 18 { return "Your shortcut has been declined. Another masterstroke, princess."; };
      if slot == 19 { return "Your shortcut has been declined. Your judgment is legendary, princess."; };
    };
    if context == 12 && tone == 1 && voice == 2 {
      if slot == 0 { return "Finish the introduction first. Very ambitious, tough guy."; };
      if slot == 1 { return "Finish the introduction first. Excellent timing, tough guy."; };
      if slot == 2 { return "Finish the introduction first. Another masterstroke, tough guy."; };
      if slot == 3 { return "Finish the introduction first. Your judgment is legendary, tough guy."; };
      if slot == 4 { return "The prologue is not a save playground. Very ambitious, tough guy."; };
      if slot == 5 { return "The prologue is not a save playground. Excellent timing, tough guy."; };
      if slot == 6 { return "The prologue is not a save playground. Another masterstroke, tough guy."; };
      if slot == 7 { return "The prologue is not a save playground. Your judgment is legendary, tough guy."; };
      if slot == 8 { return "Jackie would like you to focus. Very ambitious, tough guy."; };
      if slot == 9 { return "Jackie would like you to focus. Excellent timing, tough guy."; };
      if slot == 10 { return "Jackie would like you to focus. Another masterstroke, tough guy."; };
      if slot == 11 { return "Jackie would like you to focus. Your judgment is legendary, tough guy."; };
      if slot == 12 { return "You have barely started the game. Very ambitious, tough guy."; };
      if slot == 13 { return "You have barely started the game. Excellent timing, tough guy."; };
      if slot == 14 { return "You have barely started the game. Another masterstroke, tough guy."; };
      if slot == 15 { return "You have barely started the game. Your judgment is legendary, tough guy."; };
      if slot == 16 { return "Your shortcut has been declined. Very ambitious, tough guy."; };
      if slot == 17 { return "Your shortcut has been declined. Excellent timing, tough guy."; };
      if slot == 18 { return "Your shortcut has been declined. Another masterstroke, tough guy."; };
      if slot == 19 { return "Your shortcut has been declined. Your judgment is legendary, tough guy."; };
    };
    if context == 12 && tone == 2 && voice == 1 {
      if slot == 0 { return "FINISH THE FUCKING INTRODUCTION. Fucking brilliant, bitch."; };
      if slot == 1 { return "FINISH THE FUCKING INTRODUCTION. What a goddamn mess, bitch."; };
      if slot == 2 { return "FINISH THE FUCKING INTRODUCTION. Try thinking, bitch."; };
      if slot == 3 { return "FINISH THE FUCKING INTRODUCTION. Congratulations on the bullshit, bitch."; };
      if slot == 4 { return "Stop trying to break the prologue. Fucking brilliant, bitch."; };
      if slot == 5 { return "Stop trying to break the prologue. What a goddamn mess, bitch."; };
      if slot == 6 { return "Stop trying to break the prologue. Try thinking, bitch."; };
      if slot == 7 { return "Stop trying to break the prologue. Congratulations on the bullshit, bitch."; };
      if slot == 8 { return "The opening quest is not your toy. Fucking brilliant, bitch."; };
      if slot == 9 { return "The opening quest is not your toy. What a goddamn mess, bitch."; };
      if slot == 10 { return "The opening quest is not your toy. Try thinking, bitch."; };
      if slot == 11 { return "The opening quest is not your toy. Congratulations on the bullshit, bitch."; };
      if slot == 12 { return "Your early save is a terrible idea. Fucking brilliant, bitch."; };
      if slot == 13 { return "Your early save is a terrible idea. What a goddamn mess, bitch."; };
      if slot == 14 { return "Your early save is a terrible idea. Try thinking, bitch."; };
      if slot == 15 { return "Your early save is a terrible idea. Congratulations on the bullshit, bitch."; };
      if slot == 16 { return "Jackie would tell you to shut up. Fucking brilliant, bitch."; };
      if slot == 17 { return "Jackie would tell you to shut up. What a goddamn mess, bitch."; };
      if slot == 18 { return "Jackie would tell you to shut up. Try thinking, bitch."; };
      if slot == 19 { return "Jackie would tell you to shut up. Congratulations on the bullshit, bitch."; };
    };
    if context == 12 && tone == 2 && voice == 2 {
      if slot == 0 { return "FINISH THE FUCKING INTRODUCTION. Fucking brilliant, dickhead."; };
      if slot == 1 { return "FINISH THE FUCKING INTRODUCTION. What a goddamn mess, dickhead."; };
      if slot == 2 { return "FINISH THE FUCKING INTRODUCTION. Try thinking, dickhead."; };
      if slot == 3 { return "FINISH THE FUCKING INTRODUCTION. Congratulations on the bullshit, dickhead."; };
      if slot == 4 { return "Stop trying to break the prologue. Fucking brilliant, dickhead."; };
      if slot == 5 { return "Stop trying to break the prologue. What a goddamn mess, dickhead."; };
      if slot == 6 { return "Stop trying to break the prologue. Try thinking, dickhead."; };
      if slot == 7 { return "Stop trying to break the prologue. Congratulations on the bullshit, dickhead."; };
      if slot == 8 { return "The opening quest is not your toy. Fucking brilliant, dickhead."; };
      if slot == 9 { return "The opening quest is not your toy. What a goddamn mess, dickhead."; };
      if slot == 10 { return "The opening quest is not your toy. Try thinking, dickhead."; };
      if slot == 11 { return "The opening quest is not your toy. Congratulations on the bullshit, dickhead."; };
      if slot == 12 { return "Your early save is a terrible idea. Fucking brilliant, dickhead."; };
      if slot == 13 { return "Your early save is a terrible idea. What a goddamn mess, dickhead."; };
      if slot == 14 { return "Your early save is a terrible idea. Try thinking, dickhead."; };
      if slot == 15 { return "Your early save is a terrible idea. Congratulations on the bullshit, dickhead."; };
      if slot == 16 { return "Jackie would tell you to shut up. Fucking brilliant, dickhead."; };
      if slot == 17 { return "Jackie would tell you to shut up. What a goddamn mess, dickhead."; };
      if slot == 18 { return "Jackie would tell you to shut up. Try thinking, dickhead."; };
      if slot == 19 { return "Jackie would tell you to shut up. Congratulations on the bullshit, dickhead."; };
    };
    if context == 0 && tone == 0 && voice == 1 {
      if slot == 0 { return "Your exploration checkpoint has been noted."; };
      if slot == 1 { return "Your exploration checkpoint has been recorded."; };
      if slot == 2 { return "Your exploration checkpoint is acknowledged."; };
      if slot == 3 { return "Your exploration checkpoint remains subject to game restrictions."; };
      if slot == 4 { return "The current position has been noted."; };
      if slot == 5 { return "The current position has been recorded."; };
      if slot == 6 { return "The current position is acknowledged."; };
      if slot == 7 { return "The current position remains subject to game restrictions."; };
      if slot == 8 { return "Your progress has been noted."; };
      if slot == 9 { return "Your progress has been recorded."; };
      if slot == 10 { return "Your progress is acknowledged."; };
      if slot == 11 { return "Your progress remains subject to game restrictions."; };
      if slot == 12 { return "This location has been noted."; };
      if slot == 13 { return "This location has been recorded."; };
      if slot == 14 { return "This location is acknowledged."; };
      if slot == 15 { return "This location remains subject to game restrictions."; };
      if slot == 16 { return "Your route has been noted."; };
      if slot == 17 { return "Your route has been recorded."; };
      if slot == 18 { return "Your route is acknowledged."; };
      if slot == 19 { return "Your route remains subject to game restrictions."; };
    };
    if context == 0 && tone == 0 && voice == 2 {
      if slot == 0 { return "Your exploration checkpoint has been noted."; };
      if slot == 1 { return "Your exploration checkpoint has been recorded."; };
      if slot == 2 { return "Your exploration checkpoint is acknowledged."; };
      if slot == 3 { return "Your exploration checkpoint remains subject to game restrictions."; };
      if slot == 4 { return "The current position has been noted."; };
      if slot == 5 { return "The current position has been recorded."; };
      if slot == 6 { return "The current position is acknowledged."; };
      if slot == 7 { return "The current position remains subject to game restrictions."; };
      if slot == 8 { return "Your progress has been noted."; };
      if slot == 9 { return "Your progress has been recorded."; };
      if slot == 10 { return "Your progress is acknowledged."; };
      if slot == 11 { return "Your progress remains subject to game restrictions."; };
      if slot == 12 { return "This location has been noted."; };
      if slot == 13 { return "This location has been recorded."; };
      if slot == 14 { return "This location is acknowledged."; };
      if slot == 15 { return "This location remains subject to game restrictions."; };
      if slot == 16 { return "Your route has been noted."; };
      if slot == 17 { return "Your route has been recorded."; };
      if slot == 18 { return "Your route is acknowledged."; };
      if slot == 19 { return "Your route remains subject to game restrictions."; };
    };
    if context == 0 && tone == 1 && voice == 1 {
      if slot == 0 { return "Saving your scenic wandering. Very ambitious, princess."; };
      if slot == 1 { return "Saving your scenic wandering. Excellent timing, princess."; };
      if slot == 2 { return "Saving your scenic wandering. Another masterstroke, princess."; };
      if slot == 3 { return "Saving your scenic wandering. Your judgment is legendary, princess."; };
      if slot == 4 { return "Another heroic checkpoint. Very ambitious, princess."; };
      if slot == 5 { return "Another heroic checkpoint. Excellent timing, princess."; };
      if slot == 6 { return "Another heroic checkpoint. Another masterstroke, princess."; };
      if slot == 7 { return "Another heroic checkpoint. Your judgment is legendary, princess."; };
      if slot == 8 { return "Documenting your questionable detour. Very ambitious, princess."; };
      if slot == 9 { return "Documenting your questionable detour. Excellent timing, princess."; };
      if slot == 10 { return "Documenting your questionable detour. Another masterstroke, princess."; };
      if slot == 11 { return "Documenting your questionable detour. Your judgment is legendary, princess."; };
      if slot == 12 { return "Preserving your grand adventure. Very ambitious, princess."; };
      if slot == 13 { return "Preserving your grand adventure. Excellent timing, princess."; };
      if slot == 14 { return "Preserving your grand adventure. Another masterstroke, princess."; };
      if slot == 15 { return "Preserving your grand adventure. Your judgment is legendary, princess."; };
      if slot == 16 { return "Archiving your aimless stroll. Very ambitious, princess."; };
      if slot == 17 { return "Archiving your aimless stroll. Excellent timing, princess."; };
      if slot == 18 { return "Archiving your aimless stroll. Another masterstroke, princess."; };
      if slot == 19 { return "Archiving your aimless stroll. Your judgment is legendary, princess."; };
    };
    if context == 0 && tone == 1 && voice == 2 {
      if slot == 0 { return "Saving your scenic wandering. Very ambitious, tough guy."; };
      if slot == 1 { return "Saving your scenic wandering. Excellent timing, tough guy."; };
      if slot == 2 { return "Saving your scenic wandering. Another masterstroke, tough guy."; };
      if slot == 3 { return "Saving your scenic wandering. Your judgment is legendary, tough guy."; };
      if slot == 4 { return "Another heroic checkpoint. Very ambitious, tough guy."; };
      if slot == 5 { return "Another heroic checkpoint. Excellent timing, tough guy."; };
      if slot == 6 { return "Another heroic checkpoint. Another masterstroke, tough guy."; };
      if slot == 7 { return "Another heroic checkpoint. Your judgment is legendary, tough guy."; };
      if slot == 8 { return "Documenting your questionable detour. Very ambitious, tough guy."; };
      if slot == 9 { return "Documenting your questionable detour. Excellent timing, tough guy."; };
      if slot == 10 { return "Documenting your questionable detour. Another masterstroke, tough guy."; };
      if slot == 11 { return "Documenting your questionable detour. Your judgment is legendary, tough guy."; };
      if slot == 12 { return "Preserving your grand adventure. Very ambitious, tough guy."; };
      if slot == 13 { return "Preserving your grand adventure. Excellent timing, tough guy."; };
      if slot == 14 { return "Preserving your grand adventure. Another masterstroke, tough guy."; };
      if slot == 15 { return "Preserving your grand adventure. Your judgment is legendary, tough guy."; };
      if slot == 16 { return "Archiving your aimless stroll. Very ambitious, tough guy."; };
      if slot == 17 { return "Archiving your aimless stroll. Excellent timing, tough guy."; };
      if slot == 18 { return "Archiving your aimless stroll. Another masterstroke, tough guy."; };
      if slot == 19 { return "Archiving your aimless stroll. Your judgment is legendary, tough guy."; };
    };
    if context == 0 && tone == 2 && voice == 1 {
      if slot == 0 { return "Saving your wandering ass. Fucking brilliant, bitch."; };
      if slot == 1 { return "Saving your wandering ass. What a goddamn mess, bitch."; };
      if slot == 2 { return "Saving your wandering ass. Try thinking, bitch."; };
      if slot == 3 { return "Saving your wandering ass. Congratulations on the bullshit, bitch."; };
      if slot == 4 { return "Another fucking checkpoint. Fucking brilliant, bitch."; };
      if slot == 5 { return "Another fucking checkpoint. What a goddamn mess, bitch."; };
      if slot == 6 { return "Another fucking checkpoint. Try thinking, bitch."; };
      if slot == 7 { return "Another fucking checkpoint. Congratulations on the bullshit, bitch."; };
      if slot == 8 { return "Your shitty detour is archived. Fucking brilliant, bitch."; };
      if slot == 9 { return "Your shitty detour is archived. What a goddamn mess, bitch."; };
      if slot == 10 { return "Your shitty detour is archived. Try thinking, bitch."; };
      if slot == 11 { return "Your shitty detour is archived. Congratulations on the bullshit, bitch."; };
      if slot == 12 { return "Johnny is tired of your bullshit. Fucking brilliant, bitch."; };
      if slot == 13 { return "Johnny is tired of your bullshit. What a goddamn mess, bitch."; };
      if slot == 14 { return "Johnny is tired of your bullshit. Try thinking, bitch."; };
      if slot == 15 { return "Johnny is tired of your bullshit. Congratulations on the bullshit, bitch."; };
      if slot == 16 { return "Your survival instincts are decorative. Fucking brilliant, bitch."; };
      if slot == 17 { return "Your survival instincts are decorative. What a goddamn mess, bitch."; };
      if slot == 18 { return "Your survival instincts are decorative. Try thinking, bitch."; };
      if slot == 19 { return "Your survival instincts are decorative. Congratulations on the bullshit, bitch."; };
    };
    if context == 0 && tone == 2 && voice == 2 {
      if slot == 0 { return "Saving your wandering ass. Fucking brilliant, dickhead."; };
      if slot == 1 { return "Saving your wandering ass. What a goddamn mess, dickhead."; };
      if slot == 2 { return "Saving your wandering ass. Try thinking, dickhead."; };
      if slot == 3 { return "Saving your wandering ass. Congratulations on the bullshit, dickhead."; };
      if slot == 4 { return "Another fucking checkpoint. Fucking brilliant, dickhead."; };
      if slot == 5 { return "Another fucking checkpoint. What a goddamn mess, dickhead."; };
      if slot == 6 { return "Another fucking checkpoint. Try thinking, dickhead."; };
      if slot == 7 { return "Another fucking checkpoint. Congratulations on the bullshit, dickhead."; };
      if slot == 8 { return "Your shitty detour is archived. Fucking brilliant, dickhead."; };
      if slot == 9 { return "Your shitty detour is archived. What a goddamn mess, dickhead."; };
      if slot == 10 { return "Your shitty detour is archived. Try thinking, dickhead."; };
      if slot == 11 { return "Your shitty detour is archived. Congratulations on the bullshit, dickhead."; };
      if slot == 12 { return "Johnny is tired of your bullshit. Fucking brilliant, dickhead."; };
      if slot == 13 { return "Johnny is tired of your bullshit. What a goddamn mess, dickhead."; };
      if slot == 14 { return "Johnny is tired of your bullshit. Try thinking, dickhead."; };
      if slot == 15 { return "Johnny is tired of your bullshit. Congratulations on the bullshit, dickhead."; };
      if slot == 16 { return "Your survival instincts are decorative. Fucking brilliant, dickhead."; };
      if slot == 17 { return "Your survival instincts are decorative. What a goddamn mess, dickhead."; };
      if slot == 18 { return "Your survival instincts are decorative. Try thinking, dickhead."; };
      if slot == 19 { return "Your survival instincts are decorative. Congratulations on the bullshit, dickhead."; };
    };
    if context == 1 && tone == 0 && voice == 1 {
      if slot == 0 { return "Combat checkpoint has been noted."; };
      if slot == 1 { return "Combat checkpoint has been recorded."; };
      if slot == 2 { return "Combat checkpoint is acknowledged."; };
      if slot == 3 { return "Combat checkpoint remains subject to game restrictions."; };
      if slot == 4 { return "Your firefight has been noted."; };
      if slot == 5 { return "Your firefight has been recorded."; };
      if slot == 6 { return "Your firefight is acknowledged."; };
      if slot == 7 { return "Your firefight remains subject to game restrictions."; };
      if slot == 8 { return "The combat situation has been noted."; };
      if slot == 9 { return "The combat situation has been recorded."; };
      if slot == 10 { return "The combat situation is acknowledged."; };
      if slot == 11 { return "The combat situation remains subject to game restrictions."; };
      if slot == 12 { return "Your current battle has been noted."; };
      if slot == 13 { return "Your current battle has been recorded."; };
      if slot == 14 { return "Your current battle is acknowledged."; };
      if slot == 15 { return "Your current battle remains subject to game restrictions."; };
      if slot == 16 { return "Your tactical position has been noted."; };
      if slot == 17 { return "Your tactical position has been recorded."; };
      if slot == 18 { return "Your tactical position is acknowledged."; };
      if slot == 19 { return "Your tactical position remains subject to game restrictions."; };
    };
    if context == 1 && tone == 0 && voice == 2 {
      if slot == 0 { return "Combat checkpoint has been noted."; };
      if slot == 1 { return "Combat checkpoint has been recorded."; };
      if slot == 2 { return "Combat checkpoint is acknowledged."; };
      if slot == 3 { return "Combat checkpoint remains subject to game restrictions."; };
      if slot == 4 { return "Your firefight has been noted."; };
      if slot == 5 { return "Your firefight has been recorded."; };
      if slot == 6 { return "Your firefight is acknowledged."; };
      if slot == 7 { return "Your firefight remains subject to game restrictions."; };
      if slot == 8 { return "The combat situation has been noted."; };
      if slot == 9 { return "The combat situation has been recorded."; };
      if slot == 10 { return "The combat situation is acknowledged."; };
      if slot == 11 { return "The combat situation remains subject to game restrictions."; };
      if slot == 12 { return "Your current battle has been noted."; };
      if slot == 13 { return "Your current battle has been recorded."; };
      if slot == 14 { return "Your current battle is acknowledged."; };
      if slot == 15 { return "Your current battle remains subject to game restrictions."; };
      if slot == 16 { return "Your tactical position has been noted."; };
      if slot == 17 { return "Your tactical position has been recorded."; };
      if slot == 18 { return "Your tactical position is acknowledged."; };
      if slot == 19 { return "Your tactical position remains subject to game restrictions."; };
    };
    if context == 1 && tone == 1 && voice == 1 {
      if slot == 0 { return "Saving your spectacular firefight. Very ambitious, princess."; };
      if slot == 1 { return "Saving your spectacular firefight. Excellent timing, princess."; };
      if slot == 2 { return "Saving your spectacular firefight. Another masterstroke, princess."; };
      if slot == 3 { return "Saving your spectacular firefight. Your judgment is legendary, princess."; };
      if slot == 4 { return "Bullets flying and you want paperwork. Very ambitious, princess."; };
      if slot == 5 { return "Bullets flying and you want paperwork. Excellent timing, princess."; };
      if slot == 6 { return "Bullets flying and you want paperwork. Another masterstroke, princess."; };
      if slot == 7 { return "Bullets flying and you want paperwork. Your judgment is legendary, princess."; };
      if slot == 8 { return "Recording your tactical disaster. Very ambitious, princess."; };
      if slot == 9 { return "Recording your tactical disaster. Excellent timing, princess."; };
      if slot == 10 { return "Recording your tactical disaster. Another masterstroke, princess."; };
      if slot == 11 { return "Recording your tactical disaster. Your judgment is legendary, princess."; };
      if slot == 12 { return "Preserving your last two health points. Very ambitious, princess."; };
      if slot == 13 { return "Preserving your last two health points. Excellent timing, princess."; };
      if slot == 14 { return "Preserving your last two health points. Another masterstroke, princess."; };
      if slot == 15 { return "Preserving your last two health points. Your judgment is legendary, princess."; };
      if slot == 16 { return "Saving while your enemies aim better. Very ambitious, princess."; };
      if slot == 17 { return "Saving while your enemies aim better. Excellent timing, princess."; };
      if slot == 18 { return "Saving while your enemies aim better. Another masterstroke, princess."; };
      if slot == 19 { return "Saving while your enemies aim better. Your judgment is legendary, princess."; };
    };
    if context == 1 && tone == 1 && voice == 2 {
      if slot == 0 { return "Saving your spectacular firefight. Very ambitious, tough guy."; };
      if slot == 1 { return "Saving your spectacular firefight. Excellent timing, tough guy."; };
      if slot == 2 { return "Saving your spectacular firefight. Another masterstroke, tough guy."; };
      if slot == 3 { return "Saving your spectacular firefight. Your judgment is legendary, tough guy."; };
      if slot == 4 { return "Bullets flying and you want paperwork. Very ambitious, tough guy."; };
      if slot == 5 { return "Bullets flying and you want paperwork. Excellent timing, tough guy."; };
      if slot == 6 { return "Bullets flying and you want paperwork. Another masterstroke, tough guy."; };
      if slot == 7 { return "Bullets flying and you want paperwork. Your judgment is legendary, tough guy."; };
      if slot == 8 { return "Recording your tactical disaster. Very ambitious, tough guy."; };
      if slot == 9 { return "Recording your tactical disaster. Excellent timing, tough guy."; };
      if slot == 10 { return "Recording your tactical disaster. Another masterstroke, tough guy."; };
      if slot == 11 { return "Recording your tactical disaster. Your judgment is legendary, tough guy."; };
      if slot == 12 { return "Preserving your last two health points. Very ambitious, tough guy."; };
      if slot == 13 { return "Preserving your last two health points. Excellent timing, tough guy."; };
      if slot == 14 { return "Preserving your last two health points. Another masterstroke, tough guy."; };
      if slot == 15 { return "Preserving your last two health points. Your judgment is legendary, tough guy."; };
      if slot == 16 { return "Saving while your enemies aim better. Very ambitious, tough guy."; };
      if slot == 17 { return "Saving while your enemies aim better. Excellent timing, tough guy."; };
      if slot == 18 { return "Saving while your enemies aim better. Another masterstroke, tough guy."; };
      if slot == 19 { return "Saving while your enemies aim better. Your judgment is legendary, tough guy."; };
    };
    if context == 1 && tone == 2 && voice == 1 {
      if slot == 0 { return "Saving before the scavs flatten you. Fucking brilliant, bitch."; };
      if slot == 1 { return "Saving before the scavs flatten you. What a goddamn mess, bitch."; };
      if slot == 2 { return "Saving before the scavs flatten you. Try thinking, bitch."; };
      if slot == 3 { return "Saving before the scavs flatten you. Congratulations on the bullshit, bitch."; };
      if slot == 4 { return "Your aim is fucking garbage. Fucking brilliant, bitch."; };
      if slot == 5 { return "Your aim is fucking garbage. What a goddamn mess, bitch."; };
      if slot == 6 { return "Your aim is fucking garbage. Try thinking, bitch."; };
      if slot == 7 { return "Your aim is fucking garbage. Congratulations on the bullshit, bitch."; };
      if slot == 8 { return "Your firefight is a disaster. Fucking brilliant, bitch."; };
      if slot == 9 { return "Your firefight is a disaster. What a goddamn mess, bitch."; };
      if slot == 10 { return "Your firefight is a disaster. Try thinking, bitch."; };
      if slot == 11 { return "Your firefight is a disaster. Congratulations on the bullshit, bitch."; };
      if slot == 12 { return "Your health bar is screaming. Fucking brilliant, bitch."; };
      if slot == 13 { return "Your health bar is screaming. What a goddamn mess, bitch."; };
      if slot == 14 { return "Your health bar is screaming. Try thinking, bitch."; };
      if slot == 15 { return "Your health bar is screaming. Congratulations on the bullshit, bitch."; };
      if slot == 16 { return "Your tactical skills are dogshit. Fucking brilliant, bitch."; };
      if slot == 17 { return "Your tactical skills are dogshit. What a goddamn mess, bitch."; };
      if slot == 18 { return "Your tactical skills are dogshit. Try thinking, bitch."; };
      if slot == 19 { return "Your tactical skills are dogshit. Congratulations on the bullshit, bitch."; };
    };
    if context == 1 && tone == 2 && voice == 2 {
      if slot == 0 { return "Saving before the scavs flatten you. Fucking brilliant, dickhead."; };
      if slot == 1 { return "Saving before the scavs flatten you. What a goddamn mess, dickhead."; };
      if slot == 2 { return "Saving before the scavs flatten you. Try thinking, dickhead."; };
      if slot == 3 { return "Saving before the scavs flatten you. Congratulations on the bullshit, dickhead."; };
      if slot == 4 { return "Your aim is fucking garbage. Fucking brilliant, dickhead."; };
      if slot == 5 { return "Your aim is fucking garbage. What a goddamn mess, dickhead."; };
      if slot == 6 { return "Your aim is fucking garbage. Try thinking, dickhead."; };
      if slot == 7 { return "Your aim is fucking garbage. Congratulations on the bullshit, dickhead."; };
      if slot == 8 { return "Your firefight is a disaster. Fucking brilliant, dickhead."; };
      if slot == 9 { return "Your firefight is a disaster. What a goddamn mess, dickhead."; };
      if slot == 10 { return "Your firefight is a disaster. Try thinking, dickhead."; };
      if slot == 11 { return "Your firefight is a disaster. Congratulations on the bullshit, dickhead."; };
      if slot == 12 { return "Your health bar is screaming. Fucking brilliant, dickhead."; };
      if slot == 13 { return "Your health bar is screaming. What a goddamn mess, dickhead."; };
      if slot == 14 { return "Your health bar is screaming. Try thinking, dickhead."; };
      if slot == 15 { return "Your health bar is screaming. Congratulations on the bullshit, dickhead."; };
      if slot == 16 { return "Your tactical skills are dogshit. Fucking brilliant, dickhead."; };
      if slot == 17 { return "Your tactical skills are dogshit. What a goddamn mess, dickhead."; };
      if slot == 18 { return "Your tactical skills are dogshit. Try thinking, dickhead."; };
      if slot == 19 { return "Your tactical skills are dogshit. Congratulations on the bullshit, dickhead."; };
    };
    if context == 2 && tone == 0 && voice == 1 {
      if slot == 0 { return "Vehicle checkpoint has been noted."; };
      if slot == 1 { return "Vehicle checkpoint has been recorded."; };
      if slot == 2 { return "Vehicle checkpoint is acknowledged."; };
      if slot == 3 { return "Vehicle checkpoint remains subject to game restrictions."; };
      if slot == 4 { return "Your vehicle position has been noted."; };
      if slot == 5 { return "Your vehicle position has been recorded."; };
      if slot == 6 { return "Your vehicle position is acknowledged."; };
      if slot == 7 { return "Your vehicle position remains subject to game restrictions."; };
      if slot == 8 { return "The driving session has been noted."; };
      if slot == 9 { return "The driving session has been recorded."; };
      if slot == 10 { return "The driving session is acknowledged."; };
      if slot == 11 { return "The driving session remains subject to game restrictions."; };
      if slot == 12 { return "Your road trip has been noted."; };
      if slot == 13 { return "Your road trip has been recorded."; };
      if slot == 14 { return "Your road trip is acknowledged."; };
      if slot == 15 { return "Your road trip remains subject to game restrictions."; };
      if slot == 16 { return "The current ride has been noted."; };
      if slot == 17 { return "The current ride has been recorded."; };
      if slot == 18 { return "The current ride is acknowledged."; };
      if slot == 19 { return "The current ride remains subject to game restrictions."; };
    };
    if context == 2 && tone == 0 && voice == 2 {
      if slot == 0 { return "Vehicle checkpoint has been noted."; };
      if slot == 1 { return "Vehicle checkpoint has been recorded."; };
      if slot == 2 { return "Vehicle checkpoint is acknowledged."; };
      if slot == 3 { return "Vehicle checkpoint remains subject to game restrictions."; };
      if slot == 4 { return "Your vehicle position has been noted."; };
      if slot == 5 { return "Your vehicle position has been recorded."; };
      if slot == 6 { return "Your vehicle position is acknowledged."; };
      if slot == 7 { return "Your vehicle position remains subject to game restrictions."; };
      if slot == 8 { return "The driving session has been noted."; };
      if slot == 9 { return "The driving session has been recorded."; };
      if slot == 10 { return "The driving session is acknowledged."; };
      if slot == 11 { return "The driving session remains subject to game restrictions."; };
      if slot == 12 { return "Your road trip has been noted."; };
      if slot == 13 { return "Your road trip has been recorded."; };
      if slot == 14 { return "Your road trip is acknowledged."; };
      if slot == 15 { return "Your road trip remains subject to game restrictions."; };
      if slot == 16 { return "The current ride has been noted."; };
      if slot == 17 { return "The current ride has been recorded."; };
      if slot == 18 { return "The current ride is acknowledged."; };
      if slot == 19 { return "The current ride remains subject to game restrictions."; };
    };
    if context == 2 && tone == 1 && voice == 1 {
      if slot == 0 { return "Saving before the next lamppost. Very ambitious, princess."; };
      if slot == 1 { return "Saving before the next lamppost. Excellent timing, princess."; };
      if slot == 2 { return "Saving before the next lamppost. Another masterstroke, princess."; };
      if slot == 3 { return "Saving before the next lamppost. Your judgment is legendary, princess."; };
      if slot == 4 { return "Delamain is questioning your driving. Very ambitious, princess."; };
      if slot == 5 { return "Delamain is questioning your driving. Excellent timing, princess."; };
      if slot == 6 { return "Delamain is questioning your driving. Another masterstroke, princess."; };
      if slot == 7 { return "Delamain is questioning your driving. Your judgment is legendary, princess."; };
      if slot == 8 { return "Preserving your traffic violations. Very ambitious, princess."; };
      if slot == 9 { return "Preserving your traffic violations. Excellent timing, princess."; };
      if slot == 10 { return "Preserving your traffic violations. Another masterstroke, princess."; };
      if slot == 11 { return "Preserving your traffic violations. Your judgment is legendary, princess."; };
      if slot == 12 { return "Archiving your terrible parking. Very ambitious, princess."; };
      if slot == 13 { return "Archiving your terrible parking. Excellent timing, princess."; };
      if slot == 14 { return "Archiving your terrible parking. Another masterstroke, princess."; };
      if slot == 15 { return "Archiving your terrible parking. Your judgment is legendary, princess."; };
      if slot == 16 { return "Your car has requested protection. Very ambitious, princess."; };
      if slot == 17 { return "Your car has requested protection. Excellent timing, princess."; };
      if slot == 18 { return "Your car has requested protection. Another masterstroke, princess."; };
      if slot == 19 { return "Your car has requested protection. Your judgment is legendary, princess."; };
    };
    if context == 2 && tone == 1 && voice == 2 {
      if slot == 0 { return "Saving before the next lamppost. Very ambitious, tough guy."; };
      if slot == 1 { return "Saving before the next lamppost. Excellent timing, tough guy."; };
      if slot == 2 { return "Saving before the next lamppost. Another masterstroke, tough guy."; };
      if slot == 3 { return "Saving before the next lamppost. Your judgment is legendary, tough guy."; };
      if slot == 4 { return "Delamain is questioning your driving. Very ambitious, tough guy."; };
      if slot == 5 { return "Delamain is questioning your driving. Excellent timing, tough guy."; };
      if slot == 6 { return "Delamain is questioning your driving. Another masterstroke, tough guy."; };
      if slot == 7 { return "Delamain is questioning your driving. Your judgment is legendary, tough guy."; };
      if slot == 8 { return "Preserving your traffic violations. Very ambitious, tough guy."; };
      if slot == 9 { return "Preserving your traffic violations. Excellent timing, tough guy."; };
      if slot == 10 { return "Preserving your traffic violations. Another masterstroke, tough guy."; };
      if slot == 11 { return "Preserving your traffic violations. Your judgment is legendary, tough guy."; };
      if slot == 12 { return "Archiving your terrible parking. Very ambitious, tough guy."; };
      if slot == 13 { return "Archiving your terrible parking. Excellent timing, tough guy."; };
      if slot == 14 { return "Archiving your terrible parking. Another masterstroke, tough guy."; };
      if slot == 15 { return "Archiving your terrible parking. Your judgment is legendary, tough guy."; };
      if slot == 16 { return "Your car has requested protection. Very ambitious, tough guy."; };
      if slot == 17 { return "Your car has requested protection. Excellent timing, tough guy."; };
      if slot == 18 { return "Your car has requested protection. Another masterstroke, tough guy."; };
      if slot == 19 { return "Your car has requested protection. Your judgment is legendary, tough guy."; };
    };
    if context == 2 && tone == 2 && voice == 1 {
      if slot == 0 { return "Saving before you wreck the car. Fucking brilliant, bitch."; };
      if slot == 1 { return "Saving before you wreck the car. What a goddamn mess, bitch."; };
      if slot == 2 { return "Saving before you wreck the car. Try thinking, bitch."; };
      if slot == 3 { return "Saving before you wreck the car. Congratulations on the bullshit, bitch."; };
      if slot == 4 { return "Delamain canceled your insurance. Fucking brilliant, bitch."; };
      if slot == 5 { return "Delamain canceled your insurance. What a goddamn mess, bitch."; };
      if slot == 6 { return "Delamain canceled your insurance. Try thinking, bitch."; };
      if slot == 7 { return "Delamain canceled your insurance. Congratulations on the bullshit, bitch."; };
      if slot == 8 { return "Your driving is fucking criminal. Fucking brilliant, bitch."; };
      if slot == 9 { return "Your driving is fucking criminal. What a goddamn mess, bitch."; };
      if slot == 10 { return "Your driving is fucking criminal. Try thinking, bitch."; };
      if slot == 11 { return "Your driving is fucking criminal. Congratulations on the bullshit, bitch."; };
      if slot == 12 { return "That lamppost will win. Fucking brilliant, bitch."; };
      if slot == 13 { return "That lamppost will win. What a goddamn mess, bitch."; };
      if slot == 14 { return "That lamppost will win. Try thinking, bitch."; };
      if slot == 15 { return "That lamppost will win. Congratulations on the bullshit, bitch."; };
      if slot == 16 { return "Your GPS wants to quit. Fucking brilliant, bitch."; };
      if slot == 17 { return "Your GPS wants to quit. What a goddamn mess, bitch."; };
      if slot == 18 { return "Your GPS wants to quit. Try thinking, bitch."; };
      if slot == 19 { return "Your GPS wants to quit. Congratulations on the bullshit, bitch."; };
    };
    if context == 2 && tone == 2 && voice == 2 {
      if slot == 0 { return "Saving before you wreck the car. Fucking brilliant, dickhead."; };
      if slot == 1 { return "Saving before you wreck the car. What a goddamn mess, dickhead."; };
      if slot == 2 { return "Saving before you wreck the car. Try thinking, dickhead."; };
      if slot == 3 { return "Saving before you wreck the car. Congratulations on the bullshit, dickhead."; };
      if slot == 4 { return "Delamain canceled your insurance. Fucking brilliant, dickhead."; };
      if slot == 5 { return "Delamain canceled your insurance. What a goddamn mess, dickhead."; };
      if slot == 6 { return "Delamain canceled your insurance. Try thinking, dickhead."; };
      if slot == 7 { return "Delamain canceled your insurance. Congratulations on the bullshit, dickhead."; };
      if slot == 8 { return "Your driving is fucking criminal. Fucking brilliant, dickhead."; };
      if slot == 9 { return "Your driving is fucking criminal. What a goddamn mess, dickhead."; };
      if slot == 10 { return "Your driving is fucking criminal. Try thinking, dickhead."; };
      if slot == 11 { return "Your driving is fucking criminal. Congratulations on the bullshit, dickhead."; };
      if slot == 12 { return "That lamppost will win. Fucking brilliant, dickhead."; };
      if slot == 13 { return "That lamppost will win. What a goddamn mess, dickhead."; };
      if slot == 14 { return "That lamppost will win. Try thinking, dickhead."; };
      if slot == 15 { return "That lamppost will win. Congratulations on the bullshit, dickhead."; };
      if slot == 16 { return "Your GPS wants to quit. Fucking brilliant, dickhead."; };
      if slot == 17 { return "Your GPS wants to quit. What a goddamn mess, dickhead."; };
      if slot == 18 { return "Your GPS wants to quit. Try thinking, dickhead."; };
      if slot == 19 { return "Your GPS wants to quit. Congratulations on the bullshit, dickhead."; };
    };
    if context == 3 && tone == 0 && voice == 1 {
      if slot == 0 { return "Vehicle-combat checkpoint has been noted."; };
      if slot == 1 { return "Vehicle-combat checkpoint has been recorded."; };
      if slot == 2 { return "Vehicle-combat checkpoint is acknowledged."; };
      if slot == 3 { return "Vehicle-combat checkpoint remains subject to game restrictions."; };
      if slot == 4 { return "The rolling firefight has been noted."; };
      if slot == 5 { return "The rolling firefight has been recorded."; };
      if slot == 6 { return "The rolling firefight is acknowledged."; };
      if slot == 7 { return "The rolling firefight remains subject to game restrictions."; };
      if slot == 8 { return "Your mobile engagement has been noted."; };
      if slot == 9 { return "Your mobile engagement has been recorded."; };
      if slot == 10 { return "Your mobile engagement is acknowledged."; };
      if slot == 11 { return "Your mobile engagement remains subject to game restrictions."; };
      if slot == 12 { return "The vehicle battle has been noted."; };
      if slot == 13 { return "The vehicle battle has been recorded."; };
      if slot == 14 { return "The vehicle battle is acknowledged."; };
      if slot == 15 { return "The vehicle battle remains subject to game restrictions."; };
      if slot == 16 { return "Your driving and shooting has been noted."; };
      if slot == 17 { return "Your driving and shooting has been recorded."; };
      if slot == 18 { return "Your driving and shooting is acknowledged."; };
      if slot == 19 { return "Your driving and shooting remains subject to game restrictions."; };
    };
    if context == 3 && tone == 0 && voice == 2 {
      if slot == 0 { return "Vehicle-combat checkpoint has been noted."; };
      if slot == 1 { return "Vehicle-combat checkpoint has been recorded."; };
      if slot == 2 { return "Vehicle-combat checkpoint is acknowledged."; };
      if slot == 3 { return "Vehicle-combat checkpoint remains subject to game restrictions."; };
      if slot == 4 { return "The rolling firefight has been noted."; };
      if slot == 5 { return "The rolling firefight has been recorded."; };
      if slot == 6 { return "The rolling firefight is acknowledged."; };
      if slot == 7 { return "The rolling firefight remains subject to game restrictions."; };
      if slot == 8 { return "Your mobile engagement has been noted."; };
      if slot == 9 { return "Your mobile engagement has been recorded."; };
      if slot == 10 { return "Your mobile engagement is acknowledged."; };
      if slot == 11 { return "Your mobile engagement remains subject to game restrictions."; };
      if slot == 12 { return "The vehicle battle has been noted."; };
      if slot == 13 { return "The vehicle battle has been recorded."; };
      if slot == 14 { return "The vehicle battle is acknowledged."; };
      if slot == 15 { return "The vehicle battle remains subject to game restrictions."; };
      if slot == 16 { return "Your driving and shooting has been noted."; };
      if slot == 17 { return "Your driving and shooting has been recorded."; };
      if slot == 18 { return "Your driving and shooting is acknowledged."; };
      if slot == 19 { return "Your driving and shooting remains subject to game restrictions."; };
    };
    if context == 3 && tone == 1 && voice == 1 {
      if slot == 0 { return "Driving and shooting at once. Very ambitious, princess."; };
      if slot == 1 { return "Driving and shooting at once. Excellent timing, princess."; };
      if slot == 2 { return "Driving and shooting at once. Another masterstroke, princess."; };
      if slot == 3 { return "Driving and shooting at once. Your judgment is legendary, princess."; };
      if slot == 4 { return "Your passengers are terrified. Very ambitious, princess."; };
      if slot == 5 { return "Your passengers are terrified. Excellent timing, princess."; };
      if slot == 6 { return "Your passengers are terrified. Another masterstroke, princess."; };
      if slot == 7 { return "Your passengers are terrified. Your judgment is legendary, princess."; };
      if slot == 8 { return "Your steering wheel wants help. Very ambitious, princess."; };
      if slot == 9 { return "Your steering wheel wants help. Excellent timing, princess."; };
      if slot == 10 { return "Your steering wheel wants help. Another masterstroke, princess."; };
      if slot == 11 { return "Your steering wheel wants help. Your judgment is legendary, princess."; };
      if slot == 12 { return "Saving this rolling disaster. Very ambitious, princess."; };
      if slot == 13 { return "Saving this rolling disaster. Excellent timing, princess."; };
      if slot == 14 { return "Saving this rolling disaster. Another masterstroke, princess."; };
      if slot == 15 { return "Saving this rolling disaster. Your judgment is legendary, princess."; };
      if slot == 16 { return "The insurance company is crying. Very ambitious, princess."; };
      if slot == 17 { return "The insurance company is crying. Excellent timing, princess."; };
      if slot == 18 { return "The insurance company is crying. Another masterstroke, princess."; };
      if slot == 19 { return "The insurance company is crying. Your judgment is legendary, princess."; };
    };
    if context == 3 && tone == 1 && voice == 2 {
      if slot == 0 { return "Driving and shooting at once. Very ambitious, tough guy."; };
      if slot == 1 { return "Driving and shooting at once. Excellent timing, tough guy."; };
      if slot == 2 { return "Driving and shooting at once. Another masterstroke, tough guy."; };
      if slot == 3 { return "Driving and shooting at once. Your judgment is legendary, tough guy."; };
      if slot == 4 { return "Your passengers are terrified. Very ambitious, tough guy."; };
      if slot == 5 { return "Your passengers are terrified. Excellent timing, tough guy."; };
      if slot == 6 { return "Your passengers are terrified. Another masterstroke, tough guy."; };
      if slot == 7 { return "Your passengers are terrified. Your judgment is legendary, tough guy."; };
      if slot == 8 { return "Your steering wheel wants help. Very ambitious, tough guy."; };
      if slot == 9 { return "Your steering wheel wants help. Excellent timing, tough guy."; };
      if slot == 10 { return "Your steering wheel wants help. Another masterstroke, tough guy."; };
      if slot == 11 { return "Your steering wheel wants help. Your judgment is legendary, tough guy."; };
      if slot == 12 { return "Saving this rolling disaster. Very ambitious, tough guy."; };
      if slot == 13 { return "Saving this rolling disaster. Excellent timing, tough guy."; };
      if slot == 14 { return "Saving this rolling disaster. Another masterstroke, tough guy."; };
      if slot == 15 { return "Saving this rolling disaster. Your judgment is legendary, tough guy."; };
      if slot == 16 { return "The insurance company is crying. Very ambitious, tough guy."; };
      if slot == 17 { return "The insurance company is crying. Excellent timing, tough guy."; };
      if slot == 18 { return "The insurance company is crying. Another masterstroke, tough guy."; };
      if slot == 19 { return "The insurance company is crying. Your judgment is legendary, tough guy."; };
    };
    if context == 3 && tone == 2 && voice == 1 {
      if slot == 0 { return "Driving and shooting is a shitshow. Fucking brilliant, bitch."; };
      if slot == 1 { return "Driving and shooting is a shitshow. What a goddamn mess, bitch."; };
      if slot == 2 { return "Driving and shooting is a shitshow. Try thinking, bitch."; };
      if slot == 3 { return "Driving and shooting is a shitshow. Congratulations on the bullshit, bitch."; };
      if slot == 4 { return "Your steering is fucking terrible. Fucking brilliant, bitch."; };
      if slot == 5 { return "Your steering is fucking terrible. What a goddamn mess, bitch."; };
      if slot == 6 { return "Your steering is fucking terrible. Try thinking, bitch."; };
      if slot == 7 { return "Your steering is fucking terrible. Congratulations on the bullshit, bitch."; };
      if slot == 8 { return "Physics is coming for your ass. Fucking brilliant, bitch."; };
      if slot == 9 { return "Physics is coming for your ass. What a goddamn mess, bitch."; };
      if slot == 10 { return "Physics is coming for your ass. Try thinking, bitch."; };
      if slot == 11 { return "Physics is coming for your ass. Congratulations on the bullshit, bitch."; };
      if slot == 12 { return "Your passengers are writing wills. Fucking brilliant, bitch."; };
      if slot == 13 { return "Your passengers are writing wills. What a goddamn mess, bitch."; };
      if slot == 14 { return "Your passengers are writing wills. Try thinking, bitch."; };
      if slot == 15 { return "Your passengers are writing wills. Congratulations on the bullshit, bitch."; };
      if slot == 16 { return "Even the enemy drivers pity you. Fucking brilliant, bitch."; };
      if slot == 17 { return "Even the enemy drivers pity you. What a goddamn mess, bitch."; };
      if slot == 18 { return "Even the enemy drivers pity you. Try thinking, bitch."; };
      if slot == 19 { return "Even the enemy drivers pity you. Congratulations on the bullshit, bitch."; };
    };
    if context == 3 && tone == 2 && voice == 2 {
      if slot == 0 { return "Driving and shooting is a shitshow. Fucking brilliant, dickhead."; };
      if slot == 1 { return "Driving and shooting is a shitshow. What a goddamn mess, dickhead."; };
      if slot == 2 { return "Driving and shooting is a shitshow. Try thinking, dickhead."; };
      if slot == 3 { return "Driving and shooting is a shitshow. Congratulations on the bullshit, dickhead."; };
      if slot == 4 { return "Your steering is fucking terrible. Fucking brilliant, dickhead."; };
      if slot == 5 { return "Your steering is fucking terrible. What a goddamn mess, dickhead."; };
      if slot == 6 { return "Your steering is fucking terrible. Try thinking, dickhead."; };
      if slot == 7 { return "Your steering is fucking terrible. Congratulations on the bullshit, dickhead."; };
      if slot == 8 { return "Physics is coming for your ass. Fucking brilliant, dickhead."; };
      if slot == 9 { return "Physics is coming for your ass. What a goddamn mess, dickhead."; };
      if slot == 10 { return "Physics is coming for your ass. Try thinking, dickhead."; };
      if slot == 11 { return "Physics is coming for your ass. Congratulations on the bullshit, dickhead."; };
      if slot == 12 { return "Your passengers are writing wills. Fucking brilliant, dickhead."; };
      if slot == 13 { return "Your passengers are writing wills. What a goddamn mess, dickhead."; };
      if slot == 14 { return "Your passengers are writing wills. Try thinking, dickhead."; };
      if slot == 15 { return "Your passengers are writing wills. Congratulations on the bullshit, dickhead."; };
      if slot == 16 { return "Even the enemy drivers pity you. Fucking brilliant, dickhead."; };
      if slot == 17 { return "Even the enemy drivers pity you. What a goddamn mess, dickhead."; };
      if slot == 18 { return "Even the enemy drivers pity you. Try thinking, dickhead."; };
      if slot == 19 { return "Even the enemy drivers pity you. Congratulations on the bullshit, dickhead."; };
    };
    if context == 4 && tone == 0 && voice == 1 {
      if slot == 0 { return "Stealth checkpoint has been noted."; };
      if slot == 1 { return "Stealth checkpoint has been recorded."; };
      if slot == 2 { return "Stealth checkpoint is acknowledged."; };
      if slot == 3 { return "Stealth checkpoint remains subject to game restrictions."; };
      if slot == 4 { return "Your infiltration has been noted."; };
      if slot == 5 { return "Your infiltration has been recorded."; };
      if slot == 6 { return "Your infiltration is acknowledged."; };
      if slot == 7 { return "Your infiltration remains subject to game restrictions."; };
      if slot == 8 { return "The stealth approach has been noted."; };
      if slot == 9 { return "The stealth approach has been recorded."; };
      if slot == 10 { return "The stealth approach is acknowledged."; };
      if slot == 11 { return "The stealth approach remains subject to game restrictions."; };
      if slot == 12 { return "Your quiet movement has been noted."; };
      if slot == 13 { return "Your quiet movement has been recorded."; };
      if slot == 14 { return "Your quiet movement is acknowledged."; };
      if slot == 15 { return "Your quiet movement remains subject to game restrictions."; };
      if slot == 16 { return "Your concealed position has been noted."; };
      if slot == 17 { return "Your concealed position has been recorded."; };
      if slot == 18 { return "Your concealed position is acknowledged."; };
      if slot == 19 { return "Your concealed position remains subject to game restrictions."; };
    };
    if context == 4 && tone == 0 && voice == 2 {
      if slot == 0 { return "Stealth checkpoint has been noted."; };
      if slot == 1 { return "Stealth checkpoint has been recorded."; };
      if slot == 2 { return "Stealth checkpoint is acknowledged."; };
      if slot == 3 { return "Stealth checkpoint remains subject to game restrictions."; };
      if slot == 4 { return "Your infiltration has been noted."; };
      if slot == 5 { return "Your infiltration has been recorded."; };
      if slot == 6 { return "Your infiltration is acknowledged."; };
      if slot == 7 { return "Your infiltration remains subject to game restrictions."; };
      if slot == 8 { return "The stealth approach has been noted."; };
      if slot == 9 { return "The stealth approach has been recorded."; };
      if slot == 10 { return "The stealth approach is acknowledged."; };
      if slot == 11 { return "The stealth approach remains subject to game restrictions."; };
      if slot == 12 { return "Your quiet movement has been noted."; };
      if slot == 13 { return "Your quiet movement has been recorded."; };
      if slot == 14 { return "Your quiet movement is acknowledged."; };
      if slot == 15 { return "Your quiet movement remains subject to game restrictions."; };
      if slot == 16 { return "Your concealed position has been noted."; };
      if slot == 17 { return "Your concealed position has been recorded."; };
      if slot == 18 { return "Your concealed position is acknowledged."; };
      if slot == 19 { return "Your concealed position remains subject to game restrictions."; };
    };
    if context == 4 && tone == 1 && voice == 1 {
      if slot == 0 { return "Saving your discount ninja act. Very ambitious, princess."; };
      if slot == 1 { return "Saving your discount ninja act. Excellent timing, princess."; };
      if slot == 2 { return "Saving your discount ninja act. Another masterstroke, princess."; };
      if slot == 3 { return "Saving your discount ninja act. Your judgment is legendary, princess."; };
      if slot == 4 { return "Crouching is apparently a strategy. Very ambitious, princess."; };
      if slot == 5 { return "Crouching is apparently a strategy. Excellent timing, princess."; };
      if slot == 6 { return "Crouching is apparently a strategy. Another masterstroke, princess."; };
      if slot == 7 { return "Crouching is apparently a strategy. Your judgment is legendary, princess."; };
      if slot == 8 { return "The cameras are entertained. Very ambitious, princess."; };
      if slot == 9 { return "The cameras are entertained. Excellent timing, princess."; };
      if slot == 10 { return "The cameras are entertained. Another masterstroke, princess."; };
      if slot == 11 { return "The cameras are entertained. Your judgment is legendary, princess."; };
      if slot == 12 { return "Your infiltration is fascinating. Very ambitious, princess."; };
      if slot == 13 { return "Your infiltration is fascinating. Excellent timing, princess."; };
      if slot == 14 { return "Your infiltration is fascinating. Another masterstroke, princess."; };
      if slot == 15 { return "Your infiltration is fascinating. Your judgment is legendary, princess."; };
      if slot == 16 { return "The shadows are embarrassed. Very ambitious, princess."; };
      if slot == 17 { return "The shadows are embarrassed. Excellent timing, princess."; };
      if slot == 18 { return "The shadows are embarrassed. Another masterstroke, princess."; };
      if slot == 19 { return "The shadows are embarrassed. Your judgment is legendary, princess."; };
    };
    if context == 4 && tone == 1 && voice == 2 {
      if slot == 0 { return "Saving your discount ninja act. Very ambitious, tough guy."; };
      if slot == 1 { return "Saving your discount ninja act. Excellent timing, tough guy."; };
      if slot == 2 { return "Saving your discount ninja act. Another masterstroke, tough guy."; };
      if slot == 3 { return "Saving your discount ninja act. Your judgment is legendary, tough guy."; };
      if slot == 4 { return "Crouching is apparently a strategy. Very ambitious, tough guy."; };
      if slot == 5 { return "Crouching is apparently a strategy. Excellent timing, tough guy."; };
      if slot == 6 { return "Crouching is apparently a strategy. Another masterstroke, tough guy."; };
      if slot == 7 { return "Crouching is apparently a strategy. Your judgment is legendary, tough guy."; };
      if slot == 8 { return "The cameras are entertained. Very ambitious, tough guy."; };
      if slot == 9 { return "The cameras are entertained. Excellent timing, tough guy."; };
      if slot == 10 { return "The cameras are entertained. Another masterstroke, tough guy."; };
      if slot == 11 { return "The cameras are entertained. Your judgment is legendary, tough guy."; };
      if slot == 12 { return "Your infiltration is fascinating. Very ambitious, tough guy."; };
      if slot == 13 { return "Your infiltration is fascinating. Excellent timing, tough guy."; };
      if slot == 14 { return "Your infiltration is fascinating. Another masterstroke, tough guy."; };
      if slot == 15 { return "Your infiltration is fascinating. Your judgment is legendary, tough guy."; };
      if slot == 16 { return "The shadows are embarrassed. Very ambitious, tough guy."; };
      if slot == 17 { return "The shadows are embarrassed. Excellent timing, tough guy."; };
      if slot == 18 { return "The shadows are embarrassed. Another masterstroke, tough guy."; };
      if slot == 19 { return "The shadows are embarrassed. Your judgment is legendary, tough guy."; };
    };
    if context == 4 && tone == 2 && voice == 1 {
      if slot == 0 { return "Sneaking like a bargain-bin ninja. Fucking brilliant, bitch."; };
      if slot == 1 { return "Sneaking like a bargain-bin ninja. What a goddamn mess, bitch."; };
      if slot == 2 { return "Sneaking like a bargain-bin ninja. Try thinking, bitch."; };
      if slot == 3 { return "Sneaking like a bargain-bin ninja. Congratulations on the bullshit, bitch."; };
      if slot == 4 { return "Subtle as a fucking grenade. Fucking brilliant, bitch."; };
      if slot == 5 { return "Subtle as a fucking grenade. What a goddamn mess, bitch."; };
      if slot == 6 { return "Subtle as a fucking grenade. Try thinking, bitch."; };
      if slot == 7 { return "Subtle as a fucking grenade. Congratulations on the bullshit, bitch."; };
      if slot == 8 { return "The cameras see your dumb ass. Fucking brilliant, bitch."; };
      if slot == 9 { return "The cameras see your dumb ass. What a goddamn mess, bitch."; };
      if slot == 10 { return "The cameras see your dumb ass. Try thinking, bitch."; };
      if slot == 11 { return "The cameras see your dumb ass. Congratulations on the bullshit, bitch."; };
      if slot == 12 { return "Your stealth is a joke. Fucking brilliant, bitch."; };
      if slot == 13 { return "Your stealth is a joke. What a goddamn mess, bitch."; };
      if slot == 14 { return "Your stealth is a joke. Try thinking, bitch."; };
      if slot == 15 { return "Your stealth is a joke. Congratulations on the bullshit, bitch."; };
      if slot == 16 { return "Even the shadows hate you. Fucking brilliant, bitch."; };
      if slot == 17 { return "Even the shadows hate you. What a goddamn mess, bitch."; };
      if slot == 18 { return "Even the shadows hate you. Try thinking, bitch."; };
      if slot == 19 { return "Even the shadows hate you. Congratulations on the bullshit, bitch."; };
    };
    if context == 4 && tone == 2 && voice == 2 {
      if slot == 0 { return "Sneaking like a bargain-bin ninja. Fucking brilliant, dickhead."; };
      if slot == 1 { return "Sneaking like a bargain-bin ninja. What a goddamn mess, dickhead."; };
      if slot == 2 { return "Sneaking like a bargain-bin ninja. Try thinking, dickhead."; };
      if slot == 3 { return "Sneaking like a bargain-bin ninja. Congratulations on the bullshit, dickhead."; };
      if slot == 4 { return "Subtle as a fucking grenade. Fucking brilliant, dickhead."; };
      if slot == 5 { return "Subtle as a fucking grenade. What a goddamn mess, dickhead."; };
      if slot == 6 { return "Subtle as a fucking grenade. Try thinking, dickhead."; };
      if slot == 7 { return "Subtle as a fucking grenade. Congratulations on the bullshit, dickhead."; };
      if slot == 8 { return "The cameras see your dumb ass. Fucking brilliant, dickhead."; };
      if slot == 9 { return "The cameras see your dumb ass. What a goddamn mess, dickhead."; };
      if slot == 10 { return "The cameras see your dumb ass. Try thinking, dickhead."; };
      if slot == 11 { return "The cameras see your dumb ass. Congratulations on the bullshit, dickhead."; };
      if slot == 12 { return "Your stealth is a joke. Fucking brilliant, dickhead."; };
      if slot == 13 { return "Your stealth is a joke. What a goddamn mess, dickhead."; };
      if slot == 14 { return "Your stealth is a joke. Try thinking, dickhead."; };
      if slot == 15 { return "Your stealth is a joke. Congratulations on the bullshit, dickhead."; };
      if slot == 16 { return "Even the shadows hate you. Fucking brilliant, dickhead."; };
      if slot == 17 { return "Even the shadows hate you. What a goddamn mess, dickhead."; };
      if slot == 18 { return "Even the shadows hate you. Try thinking, dickhead."; };
      if slot == 19 { return "Even the shadows hate you. Congratulations on the bullshit, dickhead."; };
    };
    if context == 5 && tone == 0 && voice == 1 {
      if slot == 0 { return "Phone-call checkpoint has been noted."; };
      if slot == 1 { return "Phone-call checkpoint has been recorded."; };
      if slot == 2 { return "Phone-call checkpoint is acknowledged."; };
      if slot == 3 { return "Phone-call checkpoint remains subject to game restrictions."; };
      if slot == 4 { return "Your conversation has been noted."; };
      if slot == 5 { return "Your conversation has been recorded."; };
      if slot == 6 { return "Your conversation is acknowledged."; };
      if slot == 7 { return "Your conversation remains subject to game restrictions."; };
      if slot == 8 { return "The current call has been noted."; };
      if slot == 9 { return "The current call has been recorded."; };
      if slot == 10 { return "The current call is acknowledged."; };
      if slot == 11 { return "The current call remains subject to game restrictions."; };
      if slot == 12 { return "Your dialogue has been noted."; };
      if slot == 13 { return "Your dialogue has been recorded."; };
      if slot == 14 { return "Your dialogue is acknowledged."; };
      if slot == 15 { return "Your dialogue remains subject to game restrictions."; };
      if slot == 16 { return "Your phone interaction has been noted."; };
      if slot == 17 { return "Your phone interaction has been recorded."; };
      if slot == 18 { return "Your phone interaction is acknowledged."; };
      if slot == 19 { return "Your phone interaction remains subject to game restrictions."; };
    };
    if context == 5 && tone == 0 && voice == 2 {
      if slot == 0 { return "Phone-call checkpoint has been noted."; };
      if slot == 1 { return "Phone-call checkpoint has been recorded."; };
      if slot == 2 { return "Phone-call checkpoint is acknowledged."; };
      if slot == 3 { return "Phone-call checkpoint remains subject to game restrictions."; };
      if slot == 4 { return "Your conversation has been noted."; };
      if slot == 5 { return "Your conversation has been recorded."; };
      if slot == 6 { return "Your conversation is acknowledged."; };
      if slot == 7 { return "Your conversation remains subject to game restrictions."; };
      if slot == 8 { return "The current call has been noted."; };
      if slot == 9 { return "The current call has been recorded."; };
      if slot == 10 { return "The current call is acknowledged."; };
      if slot == 11 { return "The current call remains subject to game restrictions."; };
      if slot == 12 { return "Your dialogue has been noted."; };
      if slot == 13 { return "Your dialogue has been recorded."; };
      if slot == 14 { return "Your dialogue is acknowledged."; };
      if slot == 15 { return "Your dialogue remains subject to game restrictions."; };
      if slot == 16 { return "Your phone interaction has been noted."; };
      if slot == 17 { return "Your phone interaction has been recorded."; };
      if slot == 18 { return "Your phone interaction is acknowledged."; };
      if slot == 19 { return "Your phone interaction remains subject to game restrictions."; };
    };
    if context == 5 && tone == 1 && voice == 1 {
      if slot == 0 { return "Saving this gripping phone call. Very ambitious, princess."; };
      if slot == 1 { return "Saving this gripping phone call. Excellent timing, princess."; };
      if slot == 2 { return "Saving this gripping phone call. Another masterstroke, princess."; };
      if slot == 3 { return "Saving this gripping phone call. Your judgment is legendary, princess."; };
      if slot == 4 { return "Your caller deserves a medal. Very ambitious, princess."; };
      if slot == 5 { return "Your caller deserves a medal. Excellent timing, princess."; };
      if slot == 6 { return "Your caller deserves a medal. Another masterstroke, princess."; };
      if slot == 7 { return "Your caller deserves a medal. Your judgment is legendary, princess."; };
      if slot == 8 { return "Archiving your thrilling gossip. Very ambitious, princess."; };
      if slot == 9 { return "Archiving your thrilling gossip. Excellent timing, princess."; };
      if slot == 10 { return "Archiving your thrilling gossip. Another masterstroke, princess."; };
      if slot == 11 { return "Archiving your thrilling gossip. Your judgment is legendary, princess."; };
      if slot == 12 { return "The holo is judging your choices. Very ambitious, princess."; };
      if slot == 13 { return "The holo is judging your choices. Excellent timing, princess."; };
      if slot == 14 { return "The holo is judging your choices. Another masterstroke, princess."; };
      if slot == 15 { return "The holo is judging your choices. Your judgment is legendary, princess."; };
      if slot == 16 { return "This conversation is apparently historic. Very ambitious, princess."; };
      if slot == 17 { return "This conversation is apparently historic. Excellent timing, princess."; };
      if slot == 18 { return "This conversation is apparently historic. Another masterstroke, princess."; };
      if slot == 19 { return "This conversation is apparently historic. Your judgment is legendary, princess."; };
    };
    if context == 5 && tone == 1 && voice == 2 {
      if slot == 0 { return "Saving this gripping phone call. Very ambitious, tough guy."; };
      if slot == 1 { return "Saving this gripping phone call. Excellent timing, tough guy."; };
      if slot == 2 { return "Saving this gripping phone call. Another masterstroke, tough guy."; };
      if slot == 3 { return "Saving this gripping phone call. Your judgment is legendary, tough guy."; };
      if slot == 4 { return "Your caller deserves a medal. Very ambitious, tough guy."; };
      if slot == 5 { return "Your caller deserves a medal. Excellent timing, tough guy."; };
      if slot == 6 { return "Your caller deserves a medal. Another masterstroke, tough guy."; };
      if slot == 7 { return "Your caller deserves a medal. Your judgment is legendary, tough guy."; };
      if slot == 8 { return "Archiving your thrilling gossip. Very ambitious, tough guy."; };
      if slot == 9 { return "Archiving your thrilling gossip. Excellent timing, tough guy."; };
      if slot == 10 { return "Archiving your thrilling gossip. Another masterstroke, tough guy."; };
      if slot == 11 { return "Archiving your thrilling gossip. Your judgment is legendary, tough guy."; };
      if slot == 12 { return "The holo is judging your choices. Very ambitious, tough guy."; };
      if slot == 13 { return "The holo is judging your choices. Excellent timing, tough guy."; };
      if slot == 14 { return "The holo is judging your choices. Another masterstroke, tough guy."; };
      if slot == 15 { return "The holo is judging your choices. Your judgment is legendary, tough guy."; };
      if slot == 16 { return "This conversation is apparently historic. Very ambitious, tough guy."; };
      if slot == 17 { return "This conversation is apparently historic. Excellent timing, tough guy."; };
      if slot == 18 { return "This conversation is apparently historic. Another masterstroke, tough guy."; };
      if slot == 19 { return "This conversation is apparently historic. Your judgment is legendary, tough guy."; };
    };
    if context == 5 && tone == 2 && voice == 1 {
      if slot == 0 { return "Saving your fucking gossip. Fucking brilliant, bitch."; };
      if slot == 1 { return "Saving your fucking gossip. What a goddamn mess, bitch."; };
      if slot == 2 { return "Saving your fucking gossip. Try thinking, bitch."; };
      if slot == 3 { return "Saving your fucking gossip. Congratulations on the bullshit, bitch."; };
      if slot == 4 { return "Your call is a train wreck. Fucking brilliant, bitch."; };
      if slot == 5 { return "Your call is a train wreck. What a goddamn mess, bitch."; };
      if slot == 6 { return "Your call is a train wreck. Try thinking, bitch."; };
      if slot == 7 { return "Your call is a train wreck. Congratulations on the bullshit, bitch."; };
      if slot == 8 { return "The holo is judging your ass. Fucking brilliant, bitch."; };
      if slot == 9 { return "The holo is judging your ass. What a goddamn mess, bitch."; };
      if slot == 10 { return "The holo is judging your ass. Try thinking, bitch."; };
      if slot == 11 { return "The holo is judging your ass. Congratulations on the bullshit, bitch."; };
      if slot == 12 { return "Your caller needs hazard pay. Fucking brilliant, bitch."; };
      if slot == 13 { return "Your caller needs hazard pay. What a goddamn mess, bitch."; };
      if slot == 14 { return "Your caller needs hazard pay. Try thinking, bitch."; };
      if slot == 15 { return "Your caller needs hazard pay. Congratulations on the bullshit, bitch."; };
      if slot == 16 { return "Your caller would tell you to shut up. Fucking brilliant, bitch."; };
      if slot == 17 { return "Your caller would tell you to shut up. What a goddamn mess, bitch."; };
      if slot == 18 { return "Your caller would tell you to shut up. Try thinking, bitch."; };
      if slot == 19 { return "Your caller would tell you to shut up. Congratulations on the bullshit, bitch."; };
    };
    if context == 5 && tone == 2 && voice == 2 {
      if slot == 0 { return "Saving your fucking gossip. Fucking brilliant, dickhead."; };
      if slot == 1 { return "Saving your fucking gossip. What a goddamn mess, dickhead."; };
      if slot == 2 { return "Saving your fucking gossip. Try thinking, dickhead."; };
      if slot == 3 { return "Saving your fucking gossip. Congratulations on the bullshit, dickhead."; };
      if slot == 4 { return "Your call is a train wreck. Fucking brilliant, dickhead."; };
      if slot == 5 { return "Your call is a train wreck. What a goddamn mess, dickhead."; };
      if slot == 6 { return "Your call is a train wreck. Try thinking, dickhead."; };
      if slot == 7 { return "Your call is a train wreck. Congratulations on the bullshit, dickhead."; };
      if slot == 8 { return "The holo is judging your ass. Fucking brilliant, dickhead."; };
      if slot == 9 { return "The holo is judging your ass. What a goddamn mess, dickhead."; };
      if slot == 10 { return "The holo is judging your ass. Try thinking, dickhead."; };
      if slot == 11 { return "The holo is judging your ass. Congratulations on the bullshit, dickhead."; };
      if slot == 12 { return "Your caller needs hazard pay. Fucking brilliant, dickhead."; };
      if slot == 13 { return "Your caller needs hazard pay. What a goddamn mess, dickhead."; };
      if slot == 14 { return "Your caller needs hazard pay. Try thinking, dickhead."; };
      if slot == 15 { return "Your caller needs hazard pay. Congratulations on the bullshit, dickhead."; };
      if slot == 16 { return "Your caller would tell you to shut up. Fucking brilliant, dickhead."; };
      if slot == 17 { return "Your caller would tell you to shut up. What a goddamn mess, dickhead."; };
      if slot == 18 { return "Your caller would tell you to shut up. Try thinking, dickhead."; };
      if slot == 19 { return "Your caller would tell you to shut up. Congratulations on the bullshit, dickhead."; };
    };
    if context == 6 && tone == 0 && voice == 1 {
      if slot == 0 { return "The blocked save request has been noted."; };
      if slot == 1 { return "The blocked save request has been recorded."; };
      if slot == 2 { return "The blocked save request is acknowledged."; };
      if slot == 3 { return "The blocked save request remains subject to game restrictions."; };
      if slot == 4 { return "This restricted checkpoint has been noted."; };
      if slot == 5 { return "This restricted checkpoint has been recorded."; };
      if slot == 6 { return "This restricted checkpoint is acknowledged."; };
      if slot == 7 { return "This restricted checkpoint remains subject to game restrictions."; };
      if slot == 8 { return "Your denied save has been noted."; };
      if slot == 9 { return "Your denied save has been recorded."; };
      if slot == 10 { return "Your denied save is acknowledged."; };
      if slot == 11 { return "Your denied save remains subject to game restrictions."; };
      if slot == 12 { return "The current save restriction has been noted."; };
      if slot == 13 { return "The current save restriction has been recorded."; };
      if slot == 14 { return "The current save restriction is acknowledged."; };
      if slot == 15 { return "The current save restriction remains subject to game restrictions."; };
      if slot == 16 { return "The unavailable checkpoint has been noted."; };
      if slot == 17 { return "The unavailable checkpoint has been recorded."; };
      if slot == 18 { return "The unavailable checkpoint is acknowledged."; };
      if slot == 19 { return "The unavailable checkpoint remains subject to game restrictions."; };
    };
    if context == 6 && tone == 0 && voice == 2 {
      if slot == 0 { return "The blocked save request has been noted."; };
      if slot == 1 { return "The blocked save request has been recorded."; };
      if slot == 2 { return "The blocked save request is acknowledged."; };
      if slot == 3 { return "The blocked save request remains subject to game restrictions."; };
      if slot == 4 { return "This restricted checkpoint has been noted."; };
      if slot == 5 { return "This restricted checkpoint has been recorded."; };
      if slot == 6 { return "This restricted checkpoint is acknowledged."; };
      if slot == 7 { return "This restricted checkpoint remains subject to game restrictions."; };
      if slot == 8 { return "Your denied save has been noted."; };
      if slot == 9 { return "Your denied save has been recorded."; };
      if slot == 10 { return "Your denied save is acknowledged."; };
      if slot == 11 { return "Your denied save remains subject to game restrictions."; };
      if slot == 12 { return "The current save restriction has been noted."; };
      if slot == 13 { return "The current save restriction has been recorded."; };
      if slot == 14 { return "The current save restriction is acknowledged."; };
      if slot == 15 { return "The current save restriction remains subject to game restrictions."; };
      if slot == 16 { return "The unavailable checkpoint has been noted."; };
      if slot == 17 { return "The unavailable checkpoint has been recorded."; };
      if slot == 18 { return "The unavailable checkpoint is acknowledged."; };
      if slot == 19 { return "The unavailable checkpoint remains subject to game restrictions."; };
    };
    if context == 6 && tone == 1 && voice == 1 {
      if slot == 0 { return "Your save button is disappointed. Very ambitious, princess."; };
      if slot == 1 { return "Your save button is disappointed. Excellent timing, princess."; };
      if slot == 2 { return "Your save button is disappointed. Another masterstroke, princess."; };
      if slot == 3 { return "Your save button is disappointed. Your judgment is legendary, princess."; };
      if slot == 4 { return "The game said no. Very ambitious, princess."; };
      if slot == 5 { return "The game said no. Excellent timing, princess."; };
      if slot == 6 { return "The game said no. Another masterstroke, princess."; };
      if slot == 7 { return "The game said no. Your judgment is legendary, princess."; };
      if slot == 8 { return "This checkpoint is not available. Very ambitious, princess."; };
      if slot == 9 { return "This checkpoint is not available. Excellent timing, princess."; };
      if slot == 10 { return "This checkpoint is not available. Another masterstroke, princess."; };
      if slot == 11 { return "This checkpoint is not available. Your judgment is legendary, princess."; };
      if slot == 12 { return "Your timing is questionable. Very ambitious, princess."; };
      if slot == 13 { return "Your timing is questionable. Excellent timing, princess."; };
      if slot == 14 { return "Your timing is questionable. Another masterstroke, princess."; };
      if slot == 15 { return "Your timing is questionable. Your judgment is legendary, princess."; };
      if slot == 16 { return "The restrictions have opinions. Very ambitious, princess."; };
      if slot == 17 { return "The restrictions have opinions. Excellent timing, princess."; };
      if slot == 18 { return "The restrictions have opinions. Another masterstroke, princess."; };
      if slot == 19 { return "The restrictions have opinions. Your judgment is legendary, princess."; };
    };
    if context == 6 && tone == 1 && voice == 2 {
      if slot == 0 { return "Your save button is disappointed. Very ambitious, tough guy."; };
      if slot == 1 { return "Your save button is disappointed. Excellent timing, tough guy."; };
      if slot == 2 { return "Your save button is disappointed. Another masterstroke, tough guy."; };
      if slot == 3 { return "Your save button is disappointed. Your judgment is legendary, tough guy."; };
      if slot == 4 { return "The game said no. Very ambitious, tough guy."; };
      if slot == 5 { return "The game said no. Excellent timing, tough guy."; };
      if slot == 6 { return "The game said no. Another masterstroke, tough guy."; };
      if slot == 7 { return "The game said no. Your judgment is legendary, tough guy."; };
      if slot == 8 { return "This checkpoint is not available. Very ambitious, tough guy."; };
      if slot == 9 { return "This checkpoint is not available. Excellent timing, tough guy."; };
      if slot == 10 { return "This checkpoint is not available. Another masterstroke, tough guy."; };
      if slot == 11 { return "This checkpoint is not available. Your judgment is legendary, tough guy."; };
      if slot == 12 { return "Your timing is questionable. Very ambitious, tough guy."; };
      if slot == 13 { return "Your timing is questionable. Excellent timing, tough guy."; };
      if slot == 14 { return "Your timing is questionable. Another masterstroke, tough guy."; };
      if slot == 15 { return "Your timing is questionable. Your judgment is legendary, tough guy."; };
      if slot == 16 { return "The restrictions have opinions. Very ambitious, tough guy."; };
      if slot == 17 { return "The restrictions have opinions. Excellent timing, tough guy."; };
      if slot == 18 { return "The restrictions have opinions. Another masterstroke, tough guy."; };
      if slot == 19 { return "The restrictions have opinions. Your judgment is legendary, tough guy."; };
    };
    if context == 6 && tone == 2 && voice == 1 {
      if slot == 0 { return "NO, this fucking save is blocked. Fucking brilliant, bitch."; };
      if slot == 1 { return "NO, this fucking save is blocked. What a goddamn mess, bitch."; };
      if slot == 2 { return "NO, this fucking save is blocked. Try thinking, bitch."; };
      if slot == 3 { return "NO, this fucking save is blocked. Congratulations on the bullshit, bitch."; };
      if slot == 4 { return "This checkpoint would break shit. Fucking brilliant, bitch."; };
      if slot == 5 { return "This checkpoint would break shit. What a goddamn mess, bitch."; };
      if slot == 6 { return "This checkpoint would break shit. Try thinking, bitch."; };
      if slot == 7 { return "This checkpoint would break shit. Congratulations on the bullshit, bitch."; };
      if slot == 8 { return "Your impatience is not a feature. Fucking brilliant, bitch."; };
      if slot == 9 { return "Your impatience is not a feature. What a goddamn mess, bitch."; };
      if slot == 10 { return "Your impatience is not a feature. Try thinking, bitch."; };
      if slot == 11 { return "Your impatience is not a feature. Congratulations on the bullshit, bitch."; };
      if slot == 12 { return "The save system said fuck off. Fucking brilliant, bitch."; };
      if slot == 13 { return "The save system said fuck off. What a goddamn mess, bitch."; };
      if slot == 14 { return "The save system said fuck off. Try thinking, bitch."; };
      if slot == 15 { return "The save system said fuck off. Congratulations on the bullshit, bitch."; };
      if slot == 16 { return "Put the save button down. Fucking brilliant, bitch."; };
      if slot == 17 { return "Put the save button down. What a goddamn mess, bitch."; };
      if slot == 18 { return "Put the save button down. Try thinking, bitch."; };
      if slot == 19 { return "Put the save button down. Congratulations on the bullshit, bitch."; };
    };
    if context == 6 && tone == 2 && voice == 2 {
      if slot == 0 { return "NO, this fucking save is blocked. Fucking brilliant, dickhead."; };
      if slot == 1 { return "NO, this fucking save is blocked. What a goddamn mess, dickhead."; };
      if slot == 2 { return "NO, this fucking save is blocked. Try thinking, dickhead."; };
      if slot == 3 { return "NO, this fucking save is blocked. Congratulations on the bullshit, dickhead."; };
      if slot == 4 { return "This checkpoint would break shit. Fucking brilliant, dickhead."; };
      if slot == 5 { return "This checkpoint would break shit. What a goddamn mess, dickhead."; };
      if slot == 6 { return "This checkpoint would break shit. Try thinking, dickhead."; };
      if slot == 7 { return "This checkpoint would break shit. Congratulations on the bullshit, dickhead."; };
      if slot == 8 { return "Your impatience is not a feature. Fucking brilliant, dickhead."; };
      if slot == 9 { return "Your impatience is not a feature. What a goddamn mess, dickhead."; };
      if slot == 10 { return "Your impatience is not a feature. Try thinking, dickhead."; };
      if slot == 11 { return "Your impatience is not a feature. Congratulations on the bullshit, dickhead."; };
      if slot == 12 { return "The save system said fuck off. Fucking brilliant, dickhead."; };
      if slot == 13 { return "The save system said fuck off. What a goddamn mess, dickhead."; };
      if slot == 14 { return "The save system said fuck off. Try thinking, dickhead."; };
      if slot == 15 { return "The save system said fuck off. Congratulations on the bullshit, dickhead."; };
      if slot == 16 { return "Put the save button down. Fucking brilliant, dickhead."; };
      if slot == 17 { return "Put the save button down. What a goddamn mess, dickhead."; };
      if slot == 18 { return "Put the save button down. Try thinking, dickhead."; };
      if slot == 19 { return "Put the save button down. Congratulations on the bullshit, dickhead."; };
    };
    if context == 7 && tone == 0 && voice == 1 {
      if slot == 0 { return "The protected introduction has been noted."; };
      if slot == 1 { return "The protected introduction has been recorded."; };
      if slot == 2 { return "The protected introduction is acknowledged."; };
      if slot == 3 { return "The protected introduction remains subject to game restrictions."; };
      if slot == 4 { return "Your lifepath prologue has been noted."; };
      if slot == 5 { return "Your lifepath prologue has been recorded."; };
      if slot == 6 { return "Your lifepath prologue is acknowledged."; };
      if slot == 7 { return "Your lifepath prologue remains subject to game restrictions."; };
      if slot == 8 { return "The introductory mission has been noted."; };
      if slot == 9 { return "The introductory mission has been recorded."; };
      if slot == 10 { return "The introductory mission is acknowledged."; };
      if slot == 11 { return "The introductory mission remains subject to game restrictions."; };
      if slot == 12 { return "This early save attempt has been noted."; };
      if slot == 13 { return "This early save attempt has been recorded."; };
      if slot == 14 { return "This early save attempt is acknowledged."; };
      if slot == 15 { return "This early save attempt remains subject to game restrictions."; };
      if slot == 16 { return "The opening sequence has been noted."; };
      if slot == 17 { return "The opening sequence has been recorded."; };
      if slot == 18 { return "The opening sequence is acknowledged."; };
      if slot == 19 { return "The opening sequence remains subject to game restrictions."; };
    };
    if context == 7 && tone == 0 && voice == 2 {
      if slot == 0 { return "The protected introduction has been noted."; };
      if slot == 1 { return "The protected introduction has been recorded."; };
      if slot == 2 { return "The protected introduction is acknowledged."; };
      if slot == 3 { return "The protected introduction remains subject to game restrictions."; };
      if slot == 4 { return "Your lifepath prologue has been noted."; };
      if slot == 5 { return "Your lifepath prologue has been recorded."; };
      if slot == 6 { return "Your lifepath prologue is acknowledged."; };
      if slot == 7 { return "Your lifepath prologue remains subject to game restrictions."; };
      if slot == 8 { return "The introductory mission has been noted."; };
      if slot == 9 { return "The introductory mission has been recorded."; };
      if slot == 10 { return "The introductory mission is acknowledged."; };
      if slot == 11 { return "The introductory mission remains subject to game restrictions."; };
      if slot == 12 { return "This early save attempt has been noted."; };
      if slot == 13 { return "This early save attempt has been recorded."; };
      if slot == 14 { return "This early save attempt is acknowledged."; };
      if slot == 15 { return "This early save attempt remains subject to game restrictions."; };
      if slot == 16 { return "The opening sequence has been noted."; };
      if slot == 17 { return "The opening sequence has been recorded."; };
      if slot == 18 { return "The opening sequence is acknowledged."; };
      if slot == 19 { return "The opening sequence remains subject to game restrictions."; };
    };
    if context == 7 && tone == 1 && voice == 1 {
      if slot == 0 { return "Finish the introduction first. Very ambitious, princess."; };
      if slot == 1 { return "Finish the introduction first. Excellent timing, princess."; };
      if slot == 2 { return "Finish the introduction first. Another masterstroke, princess."; };
      if slot == 3 { return "Finish the introduction first. Your judgment is legendary, princess."; };
      if slot == 4 { return "The prologue is not a save playground. Very ambitious, princess."; };
      if slot == 5 { return "The prologue is not a save playground. Excellent timing, princess."; };
      if slot == 6 { return "The prologue is not a save playground. Another masterstroke, princess."; };
      if slot == 7 { return "The prologue is not a save playground. Your judgment is legendary, princess."; };
      if slot == 8 { return "The introduction would like you to focus. Very ambitious, princess."; };
      if slot == 9 { return "The introduction would like you to focus. Excellent timing, princess."; };
      if slot == 10 { return "The introduction would like you to focus. Another masterstroke, princess."; };
      if slot == 11 { return "The introduction would like you to focus. Your judgment is legendary, princess."; };
      if slot == 12 { return "You have barely started the game. Very ambitious, princess."; };
      if slot == 13 { return "You have barely started the game. Excellent timing, princess."; };
      if slot == 14 { return "You have barely started the game. Another masterstroke, princess."; };
      if slot == 15 { return "You have barely started the game. Your judgment is legendary, princess."; };
      if slot == 16 { return "Your shortcut has been declined. Very ambitious, princess."; };
      if slot == 17 { return "Your shortcut has been declined. Excellent timing, princess."; };
      if slot == 18 { return "Your shortcut has been declined. Another masterstroke, princess."; };
      if slot == 19 { return "Your shortcut has been declined. Your judgment is legendary, princess."; };
    };
    if context == 7 && tone == 1 && voice == 2 {
      if slot == 0 { return "Finish the introduction first. Very ambitious, tough guy."; };
      if slot == 1 { return "Finish the introduction first. Excellent timing, tough guy."; };
      if slot == 2 { return "Finish the introduction first. Another masterstroke, tough guy."; };
      if slot == 3 { return "Finish the introduction first. Your judgment is legendary, tough guy."; };
      if slot == 4 { return "The prologue is not a save playground. Very ambitious, tough guy."; };
      if slot == 5 { return "The prologue is not a save playground. Excellent timing, tough guy."; };
      if slot == 6 { return "The prologue is not a save playground. Another masterstroke, tough guy."; };
      if slot == 7 { return "The prologue is not a save playground. Your judgment is legendary, tough guy."; };
      if slot == 8 { return "The introduction would like you to focus. Very ambitious, tough guy."; };
      if slot == 9 { return "The introduction would like you to focus. Excellent timing, tough guy."; };
      if slot == 10 { return "The introduction would like you to focus. Another masterstroke, tough guy."; };
      if slot == 11 { return "The introduction would like you to focus. Your judgment is legendary, tough guy."; };
      if slot == 12 { return "You have barely started the game. Very ambitious, tough guy."; };
      if slot == 13 { return "You have barely started the game. Excellent timing, tough guy."; };
      if slot == 14 { return "You have barely started the game. Another masterstroke, tough guy."; };
      if slot == 15 { return "You have barely started the game. Your judgment is legendary, tough guy."; };
      if slot == 16 { return "Your shortcut has been declined. Very ambitious, tough guy."; };
      if slot == 17 { return "Your shortcut has been declined. Excellent timing, tough guy."; };
      if slot == 18 { return "Your shortcut has been declined. Another masterstroke, tough guy."; };
      if slot == 19 { return "Your shortcut has been declined. Your judgment is legendary, tough guy."; };
    };
    if context == 7 && tone == 2 && voice == 1 {
      if slot == 0 { return "FINISH THE FUCKING INTRODUCTION. Fucking brilliant, bitch."; };
      if slot == 1 { return "FINISH THE FUCKING INTRODUCTION. What a goddamn mess, bitch."; };
      if slot == 2 { return "FINISH THE FUCKING INTRODUCTION. Try thinking, bitch."; };
      if slot == 3 { return "FINISH THE FUCKING INTRODUCTION. Congratulations on the bullshit, bitch."; };
      if slot == 4 { return "Stop trying to break the prologue. Fucking brilliant, bitch."; };
      if slot == 5 { return "Stop trying to break the prologue. What a goddamn mess, bitch."; };
      if slot == 6 { return "Stop trying to break the prologue. Try thinking, bitch."; };
      if slot == 7 { return "Stop trying to break the prologue. Congratulations on the bullshit, bitch."; };
      if slot == 8 { return "The opening quest is not your toy. Fucking brilliant, bitch."; };
      if slot == 9 { return "The opening quest is not your toy. What a goddamn mess, bitch."; };
      if slot == 10 { return "The opening quest is not your toy. Try thinking, bitch."; };
      if slot == 11 { return "The opening quest is not your toy. Congratulations on the bullshit, bitch."; };
      if slot == 12 { return "Your early save is a terrible idea. Fucking brilliant, bitch."; };
      if slot == 13 { return "Your early save is a terrible idea. What a goddamn mess, bitch."; };
      if slot == 14 { return "Your early save is a terrible idea. Try thinking, bitch."; };
      if slot == 15 { return "Your early save is a terrible idea. Congratulations on the bullshit, bitch."; };
      if slot == 16 { return "Wait until the fucking montage ends. Fucking brilliant, bitch."; };
      if slot == 17 { return "Wait until the fucking montage ends. What a goddamn mess, bitch."; };
      if slot == 18 { return "Wait until the fucking montage ends. Try thinking, bitch."; };
      if slot == 19 { return "Wait until the fucking montage ends. Congratulations on the bullshit, bitch."; };
    };
    if context == 7 && tone == 2 && voice == 2 {
      if slot == 0 { return "FINISH THE FUCKING INTRODUCTION. Fucking brilliant, dickhead."; };
      if slot == 1 { return "FINISH THE FUCKING INTRODUCTION. What a goddamn mess, dickhead."; };
      if slot == 2 { return "FINISH THE FUCKING INTRODUCTION. Try thinking, dickhead."; };
      if slot == 3 { return "FINISH THE FUCKING INTRODUCTION. Congratulations on the bullshit, dickhead."; };
      if slot == 4 { return "Stop trying to break the prologue. Fucking brilliant, dickhead."; };
      if slot == 5 { return "Stop trying to break the prologue. What a goddamn mess, dickhead."; };
      if slot == 6 { return "Stop trying to break the prologue. Try thinking, dickhead."; };
      if slot == 7 { return "Stop trying to break the prologue. Congratulations on the bullshit, dickhead."; };
      if slot == 8 { return "The opening quest is not your toy. Fucking brilliant, dickhead."; };
      if slot == 9 { return "The opening quest is not your toy. What a goddamn mess, dickhead."; };
      if slot == 10 { return "The opening quest is not your toy. Try thinking, dickhead."; };
      if slot == 11 { return "The opening quest is not your toy. Congratulations on the bullshit, dickhead."; };
      if slot == 12 { return "Your early save is a terrible idea. Fucking brilliant, dickhead."; };
      if slot == 13 { return "Your early save is a terrible idea. What a goddamn mess, dickhead."; };
      if slot == 14 { return "Your early save is a terrible idea. Try thinking, dickhead."; };
      if slot == 15 { return "Your early save is a terrible idea. Congratulations on the bullshit, dickhead."; };
      if slot == 16 { return "Wait until the fucking montage ends. Fucking brilliant, dickhead."; };
      if slot == 17 { return "Wait until the fucking montage ends. What a goddamn mess, dickhead."; };
      if slot == 18 { return "Wait until the fucking montage ends. Try thinking, dickhead."; };
      if slot == 19 { return "Wait until the fucking montage ends. Congratulations on the bullshit, dickhead."; };
    };
    return "Save request received.";
  }
  // A fresh DF context enables Immersion's existing checkpoint-request fallback.
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
    if checkpoint && !Equals(message, "") { message = message + " (Request accepted; save creation unconfirmed.)"; };
    PauseMenuGameController.NLSRebornNotify(game, message);
  }
  public static func IsProtectedIntroduction(game: GameInstance) -> Bool {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(game).GetLocalPlayerControlledGameObject() as PlayerPuppet;
    return IsDefined(player) && player.nlsRebornSafetyBlock;
  }
  // Smart queue admission is independent of permission to force a checkpoint.
  // Called only for a native-locked user request, after quicksave busy guards.
  public static func HandleSmartBlockedSave(game: GameInstance, source: Int32) -> Bool {
    let players: ref<PlayerSystem> = GameInstance.GetPlayerSystem(game);
    if !IsDefined(players) { return false; };
    let player: ref<PlayerPuppet> = players.GetLocalPlayerControlledGameObject() as PlayerPuppet;
    if !IsDefined(player) || player.NLSRebornGetMode() != 3 || player.nlsRebornSafetyBlock || !player.NLSRebornDeferredIntroComplete() { return false; };
    if player.NLSRebornDeferredQueue(source) {
      if player.NLSRebornGetNotificationsEnabled() && !player.NLSRebornGetStatusNotificationsEnabled() {
        if source == 1 {
          PauseMenuGameController.NLSRebornNotify(game, "Save queued until normal saving is available.");
        } else {
          PauseMenuGameController.NLSRebornNotify(game, "Quicksave queued until normal saving is available.");
        };
      };
      return true;
    };
    // Preserve the existing explicit combat exception when the queue is off.
    if NLSRebornPolicy.AllowForcedCheckpointFallback(game) { return false; };
    if player.NLSRebornGetNotificationsEnabled() {
      let message: String = "Saving is blocked by the current game state. No save was queued.";
      if player.NLSRebornGetTone() == 1 { message = "The game still has the save button hostage. No save queued."; };
      if player.NLSRebornGetTone() == 2 { message = "The game is still blocking this damn save. No save queued."; };
      PauseMenuGameController.NLSRebornNotify(game, message);
    };
    return true;
  }
  // Combat is the only explicit native lock exception. No native Vehicle reason exists.
  public static func SmartCombatFallback(game: GameInstance) -> Bool {
    let players: ref<PlayerSystem> = GameInstance.GetPlayerSystem(game);
    if !IsDefined(players) { return false; };
    let player: ref<PlayerPuppet> = players.GetLocalPlayerControlledGameObject() as PlayerPuppet;
    if !IsDefined(player) || !player.NLSRebornGetCombat() || !player.IsInCombat() { return false; };
    if VehicleComponent.IsMountedToVehicle(game, player) && !player.NLSRebornGetVehicle() { return false; };
    let locks: array<gameSaveLock>;
    if !GameInstance.IsSavingLocked(game, locks) || ArraySize(locks) == 0 { return false; };
    let i: Int32 = 0;
    while i < ArraySize(locks) {
      if NotEquals(locks[i].reason, gameSaveLockReason.Combat) { return false; };
      i += 1;
    };
    return true;
  }
  public static func AllowForcedCheckpointFallback(game: GameInstance) -> Bool {
    let players: ref<PlayerSystem> = GameInstance.GetPlayerSystem(game);
    if !IsDefined(players) { return false; };
    let player: ref<PlayerPuppet> = players.GetLocalPlayerControlledGameObject() as PlayerPuppet;
    if !IsDefined(player) { return false; };
    if player.nlsRebornSafetyBlock || !player.NLSRebornDeferredIntroComplete() { return false; };
    let mode: Int32 = player.NLSRebornGetMode();
    if mode == 2 { return true; };
    if mode != 3 { return false; };
    return NLSRebornPolicy.SmartCombatFallback(game);
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
  let locks: array<gameSaveLock>;
  if GameInstance.IsSavingLocked(this.m_gameInstance, locks) {
    if NLSRebornPolicy.HandleSmartBlockedSave(this.m_gameInstance, 1) { return; };
    if NLSRebornPolicy.AllowForcedCheckpointFallback(this.m_gameInstance) || dfContext > 0 {
      let queuePlayer: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.m_gameInstance).GetLocalPlayerControlledGameObject() as PlayerPuppet;
      if IsDefined(queuePlayer) && queuePlayer.NLSRebornDeferredQueue(1) {
        if queuePlayer.NLSRebornGetNotificationsEnabled() && !queuePlayer.NLSRebornGetStatusNotificationsEnabled() { PauseMenuGameController.NLSRebornNotify(this.m_gameInstance, "Save queued until normal saving is available."); };
        return;
      };
      if !IsDefined(queuePlayer) || !queuePlayer.NLSRebornRequestCheckpoint(1) { return; };
      if dfContext > 0 {
        NLSRebornPolicy.NotifyImmersionSaveRequest(this.m_gameInstance, dfContext, true);
      } else if queuePlayer.NLSRebornGetNotificationsEnabled() {
        PauseMenuGameController.NLSRebornNotify(this.m_gameInstance, NLSRebornPolicy.CheckpointMessage(this.m_gameInstance, -1) + " (Request accepted; save creation unconfirmed.)");
      };
    } else {
      if NLSRebornPolicy.IsProtectedIntroduction(this.m_gameInstance) {
        PauseMenuGameController.NLSRebornNotify(this.m_gameInstance, NLSRebornPolicy.CheckpointMessage(this.m_gameInstance, 7));
        return; // Preserve existing introduction handling.
      };
      wrappedMethod(target);
    };
    return;
  };
  wrappedMethod(target);
  if dfContext > 0 { NLSRebornPolicy.NotifyImmersionSaveRequest(this.m_gameInstance, dfContext, false); };
}

@wrapMethod(PauseMenuGameController)
private final func HandlePressToQuickSaveGame() -> Void {
  let dfContext: Int32 = NLSRebornPolicy.GetImmersionSaveContext(this.m_gameInstance);
  let locks: array<gameSaveLock>;
  if GameInstance.IsSavingLocked(this.m_gameInstance, locks) && !this.m_quickSaveInProgress && !this.IsSaveFailedNotificationActive() && !this.IsGameSavedNotificationActive() {
    if NLSRebornPolicy.HandleSmartBlockedSave(this.m_gameInstance, 2) { return; };
  };
  if GameInstance.IsSavingLocked(this.m_gameInstance, locks) && (NLSRebornPolicy.AllowForcedCheckpointFallback(this.m_gameInstance) || dfContext > 0) {
    if !this.m_quickSaveInProgress && !this.IsSaveFailedNotificationActive() && !this.IsGameSavedNotificationActive() {
      let queuePlayer: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.m_gameInstance).GetLocalPlayerControlledGameObject() as PlayerPuppet;
      if IsDefined(queuePlayer) && queuePlayer.NLSRebornDeferredQueue(2) {
        if queuePlayer.NLSRebornGetNotificationsEnabled() && !queuePlayer.NLSRebornGetStatusNotificationsEnabled() { PauseMenuGameController.NLSRebornNotify(this.m_gameInstance, "Quicksave queued until normal saving is available."); };
        return;
      };
      if !IsDefined(queuePlayer) || !queuePlayer.NLSRebornRequestCheckpoint(2) { return; };
      if dfContext > 0 {
        NLSRebornPolicy.NotifyImmersionSaveRequest(this.m_gameInstance, dfContext, true);
      } else if queuePlayer.NLSRebornGetNotificationsEnabled() {
        PauseMenuGameController.NLSRebornNotify(this.m_gameInstance, NLSRebornPolicy.CheckpointMessage(this.m_gameInstance, -1) + " (Request accepted; save creation unconfirmed.)");
      };
    };
    return;
  };
  if NLSRebornPolicy.IsProtectedIntroduction(this.m_gameInstance) && GameInstance.IsSavingLocked(this.m_gameInstance, locks) {
    PauseMenuGameController.NLSRebornNotify(this.m_gameInstance, NLSRebornPolicy.CheckpointMessage(this.m_gameInstance, 7));
    return;
  };
  let dfNotifyRequest: Bool = dfContext > 0 && !this.m_quickSaveInProgress && !this.IsSaveFailedNotificationActive() && !this.IsGameSavedNotificationActive();
  wrappedMethod();
  if dfNotifyRequest { NLSRebornPolicy.NotifyImmersionSaveRequest(this.m_gameInstance, dfContext, false); };
}

@wrapMethod(gameuiInGameMenuGameController)
private final func HandleQuickSave() -> Void {
  let dfContext: Int32 = 0;
  if IsDefined(this.GetPlayerControlledObject()) {
    dfContext = NLSRebornPolicy.GetImmersionSaveContext(this.GetPlayerControlledObject().GetGame());
  };
  let locks: array<gameSaveLock>;
  if IsDefined(this.GetPlayerControlledObject()) && GameInstance.IsSavingLocked(this.GetPlayerControlledObject().GetGame(), locks) && !this.m_quickSaveInProgress {
    if NLSRebornPolicy.HandleSmartBlockedSave(this.GetPlayerControlledObject().GetGame(), 2) { return; };
  };
  if IsDefined(this.GetPlayerControlledObject()) && GameInstance.IsSavingLocked(this.GetPlayerControlledObject().GetGame(), locks) && (NLSRebornPolicy.AllowForcedCheckpointFallback(this.GetPlayerControlledObject().GetGame()) || dfContext > 0) {
    if !this.m_quickSaveInProgress {
      let queuePlayer: ref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
      if IsDefined(queuePlayer) && queuePlayer.NLSRebornDeferredQueue(2) {
        if queuePlayer.NLSRebornGetNotificationsEnabled() && !queuePlayer.NLSRebornGetStatusNotificationsEnabled() { PauseMenuGameController.NLSRebornNotify(this.GetPlayerControlledObject().GetGame(), "Quicksave queued until normal saving is available."); };
        return;
      };
      if !IsDefined(queuePlayer) || !queuePlayer.NLSRebornRequestCheckpoint(2) { return; };
      if dfContext > 0 {
        NLSRebornPolicy.NotifyImmersionSaveRequest(this.GetPlayerControlledObject().GetGame(), dfContext, true);
      } else if queuePlayer.NLSRebornGetNotificationsEnabled() {
        PauseMenuGameController.NLSRebornNotify(this.GetPlayerControlledObject().GetGame(), NLSRebornPolicy.CheckpointMessage(this.GetPlayerControlledObject().GetGame(), -1) + " (Request accepted; save creation unconfirmed.)");
      };
    };
    return;
  };
  if IsDefined(this.GetPlayerControlledObject()) && NLSRebornPolicy.IsProtectedIntroduction(this.GetPlayerControlledObject().GetGame()) {
    let locks: array<gameSaveLock>;
    if GameInstance.IsSavingLocked(this.GetPlayerControlledObject().GetGame(), locks) {
      PauseMenuGameController.NLSRebornNotify(this.GetPlayerControlledObject().GetGame(), NLSRebornPolicy.CheckpointMessage(this.GetPlayerControlledObject().GetGame(), 7));
      return;
    };
  };
  let dfNotifyRequest: Bool = dfContext > 0 && !this.m_quickSaveInProgress;
  wrappedMethod();
  if dfNotifyRequest { NLSRebornPolicy.NotifyImmersionSaveRequest(this.GetPlayerControlledObject().GetGame(), dfContext, false); };
}
