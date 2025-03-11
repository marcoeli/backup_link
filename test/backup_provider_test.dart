/*import 'package:backup_link/providers/backup_provider.dart';
import 'package:backup_link/widgets/progress_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

class TestProgressHUDState extends StatefulWidget {
  const TestProgressHUDState({super.key});

  @override
  State<TestProgressHUDState> createState() => _TestProgressHUDState();
}

class _TestProgressHUDState extends State<TestProgressHUDState>
    implements ProgressHUDState {
  double? currentValue;
  String? currentText;
  bool isShowing = false;

  @override
  void setValue(double value) => currentValue = value;

  @override
  void setText(String text) => currentText = text;

  @override
  void show() => isShowing = true;

  @override
  void dismiss() => isShowing = false;

  @override
  Widget build(BuildContext context) => Container();
}

void main() {
  late BackupProvider provider;
  late _TestProgressHUDState mockProgressHUD;

  setUp(() {
    provider = BackupProvider();
    const testWidget = TestProgressHUDState();
    mockProgressHUD = (testWidget.createState() as _TestProgressHUDState);
    provider.setProgressHUD(mockProgressHUD);
  });

  group('BackupProvider State Management', () {
    test('initial state is empty', () {
      expect(provider.sourceFolders, isEmpty);
      expect(provider.destinationFolder, isNull);
      expect(provider.isBackingUp, isFalse);
      expect(provider.isIntegrityChecking, isFalse);
      expect(provider.feedbackMessage, isEmpty);
      expect(provider.logMessages, isEmpty);
    });

    test('addSourceFolder updates state with Windows path', () async {
      final testPath = path.windows.normalize(r'D:\test\path');
      await provider.addSourceFolder(testPath);
      expect(provider.sourceFolders, contains(testPath));
      expect(provider.logMessages, isNotEmpty);
    });

    test('setDestinationFolder updates state with Windows path', () async {
      final testPath = path.windows.normalize(r'D:\dest\path');
      await provider.setDestinationFolder(testPath);
      expect(provider.destinationFolder, equals(testPath));
      expect(provider.logMessages, isNotEmpty);
    });

    test('removeSourceFolder removes folder from list', () async {
      final testPath = path.windows.normalize(r'D:\test\path');
      await provider.addSourceFolder(testPath);
      provider.removeSourceFolder(testPath);
      expect(provider.sourceFolders, isEmpty);
    });
  });

  group('Progress HUD Interaction', () {
    test('startBackup shows and updates progress', () async {
      final sourcePath = path.windows.normalize(r'D:\source');
      final destPath = path.windows.normalize(r'D:\dest');

      await provider.setDestinationFolder(destPath);
      await provider.addSourceFolder(sourcePath);

      // Start backup operation
      provider.startBackup();

      // Verify progress HUD was shown
      expect(mockProgressHUD.isShowing, isTrue);
      expect(mockProgressHUD.currentText, contains('Iniciando'));
    });

    test('checkIntegrity shows progress updates', () async {
      final sourcePath = path.windows.normalize(r'D:\source');
      final destPath = path.windows.normalize(r'D:\dest');

      await provider.setDestinationFolder(destPath);
      await provider.addSourceFolder(sourcePath);

      // Start integrity check
      provider.checkIntegrity();

      // Verify progress HUD was shown
      expect(mockProgressHUD.isShowing, isTrue);
      expect(mockProgressHUD.currentText, contains('Verificando'));
    });
  });

  group('Log Message Management', () {
    test('logs are trimmed when exceeding max length', () {
      // Add more messages than the max
      for (int i = 0; i < 110; i++) {
        provider.setFeedbackMessage('Test message $i');
      }

      // Verify logs were trimmed
      expect(provider.logMessages.length, lessThanOrEqualTo(100));
      // Verify most recent messages were kept
      expect(provider.logMessages.last, contains('109'));
    });
  });
}*/
