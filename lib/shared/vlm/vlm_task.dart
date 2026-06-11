/// The set of image-understanding tasks the VLM assistant can perform.
///
/// Every non-realtime understanding feature (scan, reading, scene description,
/// ask-image) maps to one of these. Realtime safety (obstacle, traffic light,
/// danger signs, finders) never goes through here — that stays on local CV.
/// See `docs/ROADMAP.md`.
enum VlmTask {
  /// The Scan mode: one capture → one spoken answer identifying whatever the
  /// camera is pointed at. Subsumes the old in-hand / currency / brand tasks —
  /// the model decides if it's money (total + breakdown), a packaged product
  /// (read off the label), a sign/label (gist), or a generic object.
  /// Local-preferred.
  scan,

  /// Read the text aloud like a document — faithful but condensed, skipping page
  /// furniture. Local-preferred.
  read,

  /// "What's in front of me" scene description. Cloud-preferred (heavier reasoning).
  describeScene,

  /// One-shot spoken question about the current frame. Cloud-preferred.
  askImage,
}
