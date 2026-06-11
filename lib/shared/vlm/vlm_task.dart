/// The set of image-understanding tasks the VLM assistant can perform.
///
/// Every non-realtime understanding feature (reading, in-hand, currency, brand,
/// scene description, ask-image) maps to one of these. Realtime safety (obstacle,
/// traffic light, danger signs, finders) never goes through here — that stays on
/// local CV. See `docs/ROADMAP.md`.
enum VlmTask {
  /// Quick one-line spoken gist of what the camera is pointed at (what it is +
  /// the key fact). Local-preferred. Powers the SCAN sub-mode.
  scan,

  /// Read the text aloud like a document — faithful but condensed, skipping page
  /// furniture. Local-preferred. Powers the READ sub-mode.
  read,

  /// "What's in front of me" scene description. Cloud-preferred (heavier reasoning).
  describeScene,

  /// Identify the object the user is holding. Local-preferred.
  inHand,

  /// Identify a banknote / currency value. Local-preferred.
  currency,

  /// Identify a product brand or packaging. Local-preferred.
  brand,

  /// One-shot spoken question about the current frame. Cloud-preferred.
  askImage,
}
