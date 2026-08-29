/// Which vector face a character is drawn with, when it has one.
///
/// Optional on purpose: a character without a [FaceShape] keeps the emoji
/// avatar (`contracts/character-config.md` §5). The roster is being drawn
/// one animal at a time, and a half-drawn table must still render.
enum FaceShape {
  cat,
  dog,
  crocodile;

  /// Unknown or absent values degrade to `null` (the emoji avatar) instead
  /// of failing the catalog load — same leniency as `emoji` and `voice`.
  static FaceShape? fromConfig(Object? value) {
    if (value is! String) return null;
    for (final shape in FaceShape.values) {
      if (shape.name == value) return shape;
    }
    return null;
  }
}
