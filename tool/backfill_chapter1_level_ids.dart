// One-time deterministic backfill of explicit Chapter 1 level ids
// (schema freeze, Batch 1). Run from the project root with:
//   dart run tool/backfill_chapter1_level_ids.dart
//
// Reads the Chapter 1 pool asset FROM THE GIT BLOB at the design-approved base
// commit (never from the working-tree copy, which could be stale or already
// converted), verifies it is exactly the expected legacy pool (100 entries, no
// level_id anywhere), and writes the converted asset:
//
//   * envelope gains  schema_version: 1, chapter_id: "c1", pool_version: 1
//   * every entry gains an explicit  level_id: "rs_NNN"  equal to its
//     historical zero-based position (rs_000 … rs_099)
//   * every existing envelope + entry field is preserved unchanged, in order
//
// The transformation is pure and deterministic: same blob in, same bytes out.
// It is also idempotent — if the on-disk asset already equals the target
// output, nothing is written and the tool reports "already up to date".

import 'dart:convert';
import 'dart:io';

/// feature/chapter2-data-model-design head — the reviewed baseline commit.
const String baseCommit = '50ccb80b321d05fa8eb1724a882508d34cea8c68';

const String assetPath = 'assets/levels/runic_sudoku_levels.json';

/// Guards against resolving the wrong blob (wrong commit / wrong path).
const int expectedBaselineBytes = 140223;
const int expectedEntryCount = 100;
const Map<String, int> expectedCounts = {
  'Quick': 20,
  'Normal': 30,
  'Tricky': 30,
  'Deep': 20,
};

Never fail(String message) {
  stderr.writeln('ERROR: $message');
  exit(1);
}

void main() {
  // 1. Baseline = the Git blob at the reviewed base commit.
  final res = Process.runSync(
    'git',
    ['show', '$baseCommit:$assetPath'],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (res.exitCode != 0) {
    fail('git show $baseCommit:$assetPath failed:\n${res.stderr}');
  }
  final baselineText = res.stdout as String;
  final baselineBytes = utf8.encode(baselineText).length;
  if (baselineBytes != expectedBaselineBytes) {
    fail('baseline blob is $baselineBytes bytes, '
        'expected $expectedBaselineBytes — wrong commit or path?');
  }

  // 2. Verify the baseline is exactly the legacy pool this tool was written
  //    for. Refuse to proceed on any surprise.
  final doc = jsonDecode(baselineText) as Map<String, dynamic>;
  if (doc['schema'] != 'runic_sudoku_level_pool_v1') {
    fail('unexpected baseline schema marker: ${doc['schema']}');
  }
  if (doc.containsKey('schema_version')) {
    fail('baseline already has schema_version — not the legacy pool');
  }
  final levels = (doc['levels'] as List).cast<Map<String, dynamic>>();
  if (levels.length != expectedEntryCount) {
    fail('baseline has ${levels.length} entries, '
        'expected exactly $expectedEntryCount');
  }
  final counts = <String, int>{};
  for (var i = 0; i < levels.length; i++) {
    final e = levels[i];
    if (e.containsKey('level_id')) {
      fail('baseline entry $i already has a level_id');
    }
    final label = e['difficulty_label'];
    if (label is! String) fail('baseline entry $i has no difficulty_label');
    counts[label] = (counts[label] ?? 0) + 1;
  }
  if (counts.length != expectedCounts.length ||
      expectedCounts.entries.any((en) => counts[en.key] != en.value)) {
    fail('baseline difficulty counts $counts != expected $expectedCounts');
  }

  // 3. Pure transformation: versioned envelope + explicit positional ids.
  final out = <String, dynamic>{
    'schema': doc['schema'],
    'schema_version': 1,
    'chapter_id': 'c1',
    'pool_version': 1,
    'note': doc['note'],
    'grid_size': doc['grid_size'],
    'box_shape': doc['box_shape'],
    'counts': doc['counts'],
    'levels': [
      for (var i = 0; i < levels.length; i++)
        <String, dynamic>{
          'level_id': 'rs_${i.toString().padLeft(3, '0')}',
          ...levels[i],
        },
    ],
  };
  final targetText = const JsonEncoder.withIndent('  ').convert(out);

  // 4. Idempotent write.
  final file = File(assetPath);
  if (file.existsSync() && file.readAsStringSync() == targetText) {
    stdout.writeln('OK: $assetPath already up to date '
        '(${utf8.encode(targetText).length} bytes); nothing written.');
    return;
  }
  file.writeAsStringSync(targetText);
  stdout
    ..writeln('Converted $assetPath from Git baseline '
        '$baseCommit ($expectedBaselineBytes bytes).')
    ..writeln('Wrote ${utf8.encode(targetText).length} bytes, '
        '${levels.length} entries, ids rs_000 … '
        'rs_${(levels.length - 1).toString().padLeft(3, '0')}.');
}
