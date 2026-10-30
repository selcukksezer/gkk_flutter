import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fullstack Dart ↔ Supabase RPC Schema Contract Parity', () {
    test('All Dart .rpc() calls must exist in Supabase migrations', () {
      final Directory migrationsDir = Directory('supabase/migrations');
      expect(migrationsDir.existsSync(), isTrue, reason: 'supabase/migrations must exist');

      final RegExp fnPattern = RegExp(
        r'CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(?:(?:public|auth|extensions)\.)?([a-zA-Z0-9_]+)\s*\(',
        caseSensitive: false,
        multiLine: true,
      );

      final Set<String> definedFunctions = <String>{};
      final List<FileSystemEntity> migrationFiles = migrationsDir.listSync(recursive: true);
      for (final FileSystemEntity entity in migrationFiles) {
        if (entity is File && entity.path.endsWith('.sql')) {
          final String content = entity.readAsStringSync();
          for (final Match m in fnPattern.allMatches(content)) {
            definedFunctions.add(m.group(1)!.toLowerCase());
          }
        }
      }

      expect(definedFunctions.isNotEmpty, isTrue);

      final Directory libDir = Directory('lib');
      final RegExp rpcCallPattern = RegExp(
        r'\.rpc\s*\(\s*[\x27\x22]([a-zA-Z0-9_]+)[\x27\x22]',
        caseSensitive: false,
        multiLine: true,
      );

      final Map<String, List<String>> missingCallSites = <String, List<String>>{};
      final List<FileSystemEntity> dartFiles = libDir.listSync(recursive: true);

      for (final FileSystemEntity entity in dartFiles) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final String content = entity.readAsStringSync();
          for (final Match m in rpcCallPattern.allMatches(content)) {
            final String fnName = m.group(1)!.toLowerCase();
            if (!definedFunctions.contains(fnName)) {
              missingCallSites.putIfAbsent(fnName, () => <String>[]).add(entity.path);
            }
          }
        }
      }

      expect(
        missingCallSites,
        isEmpty,
        reason: 'The following RPC functions are called in Dart but have NO definition in SQL migrations: '
            '${missingCallSites.entries.map((e) => "${e.key} in ${e.value.toSet().join(', ')}").join('; ')}',
      );
    });
  });
}
