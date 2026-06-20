/// Deterministic "puzzle of the day" selection (Phase 0 §7).
///
/// Same local calendar date → same pool index for everyone, with no backend:
/// the date string `YYYY-MM-DD` is hashed (FNV-1a 32-bit) and reduced modulo the
/// pool size. We deliberately do NOT use `DateTime.hashCode` / `String.hashCode`
/// (Dart randomizes `String.hashCode` per run, so it is not stable across app
/// launches). FNV-1a over the ASCII date is stable on native (mobile) targets;
/// see the web caveat in PHASE3_NOTES.md.
///
/// The index spans the WHOLE pool (not a single difficulty band), so the daily
/// difficulty varies day to day — measured: all pool indices used across a year,
/// no consecutive-day repeats. Rationale + alternative in PHASE3_NOTES.md.
class DailyPuzzleSelector {
  const DailyPuzzleSelector._();

  /// Index into a pool of [poolLength] for the local calendar [date].
  static int indexForDate(DateTime date, int poolLength) {
    if (poolLength <= 0) {
      throw ArgumentError.value(poolLength, 'poolLength', 'must be > 0');
    }
    return _fnv1a(dateKey(date)) % poolLength;
  }

  /// Stable `YYYY-MM-DD` key from the date part of [date].
  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static int _fnv1a(String s) {
    var hash = 0x811c9dc5; // 2166136261
    for (final byte in s.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF; // *16777619, keep 32 bits
    }
    return hash;
  }
}
