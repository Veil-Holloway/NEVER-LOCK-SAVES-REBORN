// Neutral contextual request messages. Detection and notification switches are unchanged.
public class NLSRebornDFMessages {
  public static func Message(game: GameInstance, context: Int32, checkpoint: Bool) -> String {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(game).GetLocalPlayerControlledGameObject() as PlayerPuppet;
    if !IsDefined(player) || !player.NLSRebornGetNotificationsEnabled() { return ""; };
    let prefix: String = "Saving game. ";
    if context == 8 { return prefix + "Vehicle sleep is active."; };
    if context == 9 { return prefix + "Addiction is active."; };
    if context == 10 { return prefix + "You are starving."; };
    if context == 11 { return prefix + "You are dehydrated."; };
    return prefix + "";
  }
}
