/// Outcome of `AppBootstrap.start()` — which repository implementations
/// (real vs. read-only) DI should register (FR-021).
enum StorageMode {
  /// The database opened normally; reads and writes go to disk.
  persistent,

  /// The user chose "continue without saving" after a startup failure.
  /// Reads return empty/defaults, writes fail with
  /// `DatabaseFailure(storageReadOnly)` — nothing is persisted, nothing is
  /// silently deleted (FR-021d).
  readOnly,

  /// The database could not be opened and the user hasn't chosen a
  /// recovery action yet — the app shows `/storage-error` instead of the
  /// shell (FR-021a, FR-021b).
  unavailable,
}
