# Persistent playthrough identity — bounded research

Date: October 24, 2026. No production files changed, game launched or compiler run.

## Finding

Modern Codeware source exposes a real `playthroughID: String` in both
`saveGameMetadata` and `saveMetadata`. That improves the prior evidence: it is
incorrect to claim the game has no such identifier at all. However, a declared
metadata field is not a verified supported read-only getter for the currently
loaded playthrough. No such accessor was established in this focused research.

The current game script's `GetLatestSaveMetadata()` returns the separate
`LatestSaveMetadataInfo` type, which does not expose `playthroughID`. Its latest
save may differ from the older save the player loaded. `SaveMetadataInfo` supplied
to the load UI also lacks the field and describes one enumerated save slot.
The Codeware addon to latest metadata adds only game version/content IDs.

Codeware's `GameSessionEvent` contains restored/pregame booleans, not an ID.
The original CET-kit `GameSession.GetKey()` uses a generated mod key persisted by
writing `_psxgs_session_key` as a quest fact. It is not a native read-only ID and
must not be introduced under the current project constraint.

## Recommendation

Retain explicit manual presets and keep automatic character/playthrough binding
marked unavailable. Do not substitute player wrapper/entity ID, lifepath, body,
elapsed time, latest-save identity, guessed API names, new quest facts or an
unverified C++ offset/ABI bridge.

The optional closed-game companion could eventually inspect an explicitly
selected save slot's metadata without editing it and report a validated stored
playthrough ID with provenance. That would describe that selected disk save;
it still would not establish which playthrough is currently loaded in CET.
Such an extension requires its own stable-byte/schema/source contract and is
not implemented by this research task.

## Evidence

`IDENTITY-EVIDENCE.json` records eight freshly fetched primary files with commit
and blob SHA. Sources are Codeware commit
`a652bbbcf6feb65988c67f15f428e9398a3d827c`, current game-script snapshot
`cfcf5071e5363962a44c33cb7cab749688b0ca51`, and CET-kit commit
`f64c837e589ffffc030e79ed0123688eb3091098`. Codeware's recursive tree returned
7,709 entries without truncation; targeted source queries focused on metadata,
playthrough and session interfaces. No result is a guarantee of global API
absence or of compatibility with the user's exact installed versions.
