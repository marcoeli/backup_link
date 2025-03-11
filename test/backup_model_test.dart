import 'dart:io';

import 'package:backup_link/models/backup_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late BackupModel backupModel;
  late Directory tempDir;
  late Directory sourceDir;
  late Directory destDir;

  setUp(() async {
    backupModel = BackupModel();
    tempDir = await Directory.systemTemp.createTemp('backup_test_');
    sourceDir = Directory(path.join(tempDir.path, 'source'));
    destDir = Directory(path.join(tempDir.path, 'dest'));
    await sourceDir.create();
    await destDir.create();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('BackupModel Tests', () {
    test('addSourceFolder adds valid folder', () async {
      await backupModel.addSourceFolder(sourceDir.path);
      expect(backupModel.sourceFolders, contains(sourceDir.path));
    });

    test('setDestinationFolder sets folder correctly', () async {
      await backupModel.setDestinationFolder(destDir.path);
      expect(backupModel.destinationFolder, equals(destDir.path));
    });

    test('removeSourceFolder removes folder from list', () async {
      await backupModel.addSourceFolder(sourceDir.path);
      backupModel.removeSourceFolder(sourceDir.path);
      expect(backupModel.sourceFolders, isEmpty);
    });

    test('backupFolders fails when no source/destination set', () async {
      final result = await backupModel.backupFolders(
        (folder) async => true,
        (progress) {},
      );
      expect(result, isFalse);
    });
  });

  group('File Operations Tests', () {
    test('_calculateFileHash generates consistent hashes', () async {
      final testFile = File(path.join(sourceDir.path, 'test.txt'));
      await testFile.writeAsString('test content');

      final hash1 = await backupModel.calculateFileHash(testFile.path);
      final hash2 = await backupModel.calculateFileHash(testFile.path);

      expect(hash1, equals(hash2));
    });
  });
}
