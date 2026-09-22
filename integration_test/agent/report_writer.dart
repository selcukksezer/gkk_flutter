/// Report writer for AI swarm coverage (JSON + MD).
library;

import 'dart:convert';
import 'dart:io';

import 'feature_goal_registry.dart';

class LivePlayReportWriter {
  LivePlayReportWriter(this.outDir);

  final Directory outDir;

  Future<void> writeAll(Map<String, dynamic> summary) async {
    await outDir.create(recursive: true);
    final File summaryFile = File('${outDir.path}/summary.json');
    await summaryFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(summary),
    );

    final Map<String, dynamic> coverage = Map<String, dynamic>.from(
      (summary['coverage_by_goal'] as Map<String, dynamic>?) ??
          <String, dynamic>{},
    );
    await File('${outDir.path}/coverage_matrix.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(coverage),
    );

    await File('${outDir.path}/coverage_by_goal.md').writeAsString(
      _coverageByGoalMd(coverage, summary),
    );
    await File('${outDir.path}/live_play_rapor.md').writeAsString(
      _raporMd(summary, coverage),
    );
    await File('${outDir.path}/BUGS.md').writeAsString(
      _bugsMd(summary),
    );
    await File('${outDir.path}/social_mesh.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        summary['mesh'] ?? <String, dynamic>{},
      ),
    );
  }

  String _coverageByGoalMd(
    Map<String, dynamic> coverage,
    Map<String, dynamic> summary,
  ) {
    final StringBuffer buf = StringBuffer()
      ..writeln('# Coverage by goal')
      ..writeln()
      ..writeln('| Goal | PASS | FAIL | SKIP |')
      ..writeln('|------|-----:|-----:|-----:|');
    final List<String> ids = coverage.keys.toList()..sort();
    for (final String id in ids) {
      final Map<String, dynamic> c =
          Map<String, dynamic>.from(coverage[id] as Map? ?? <String, dynamic>{});
      buf.writeln(
        '| `$id` | ${c['PASS'] ?? 0} | ${c['FAIL'] ?? 0} | ${c['SKIP'] ?? 0} |',
      );
    }
    buf
      ..writeln()
      ..writeln('Registry size: ${FeatureGoalRegistry.all.length}')
      ..writeln('Bots total: ${summary['bots_total']}');
    return buf.toString();
  }

  String _raporMd(
    Map<String, dynamic> summary,
    Map<String, dynamic> coverage,
  ) {
    final int botsPass = (summary['bots_pass'] as num?)?.toInt() ?? 0;
    final int botsFail = (summary['bots_fail'] as num?)?.toInt() ?? 0;
    final int botsTotal = (summary['bots_total'] as num?)?.toInt() ?? 0;
    return '''
# AI Live-Play Swarm Raporu

**Verdict:** `${summary['verdict'] ?? 'UNKNOWN'}`  
**Bots:** $botsPass PASS / $botsFail FAIL / $botsTotal total  
**Range:** ${summary['from']}–${summary['to']}  
**Registry goals:** ${FeatureGoalRegistry.all.length}

## Özet

Headless SQL marathon (`qa_live_play_swarm`) + FeatureGoalRegistry coverage.

## Coverage özeti

Toplam goal satırı: ${coverage.length}. Detay: `coverage_by_goal.md`.

## Not

Pre-launch QA DB. Launch öncesi `qa_wipe_live_play_bots` + [WIPE_CHECKLIST.md](WIPE_CHECKLIST.md).
''';
  }

  String _bugsMd(Map<String, dynamic> summary) {
    final List<dynamic> bots =
        (summary['bots'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> failed = bots
        .where((dynamic b) => (b as Map)['verdict'] == 'FAIL')
        .toList();
    final StringBuffer buf = StringBuffer()
      ..writeln('# BUGS')
      ..writeln()
      ..writeln('Failed bots: ${failed.length}')
      ..writeln();
    for (final dynamic b in failed) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(b as Map);
      buf.writeln('- bot ${m['bot_index']}: failed=${m['failed']} skipped=${m['skipped']}');
    }
    if (failed.isEmpty) {
      buf.writeln('_No FAIL bots._');
    }
    return buf.toString();
  }
}
