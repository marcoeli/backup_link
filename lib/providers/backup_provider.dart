import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

import '../models/backup_model.dart';
import '../models/progress_update.dart';
import '../widgets/progress_hud.dart';

/// A ChangeNotifier that manages the state and UI updates for backup operations.
/// Acts as a bridge between the UI and the BackupModel.
class BackupProvider extends ChangeNotifier {
  final BackupModel _backupModel = BackupModel();
  final Logger _logger = Logger();

  /// Maximum number of log messages to keep in memory
  static const int _maxLogMessages = 100;

  /// Standard delay for showing operation completion
  static const Duration _completionDelay = Duration(seconds: 1);

  /// Progress HUD widget state for showing progress
  ProgressHUDState? _progressHUD;

  // State variables
  List<String> _sourceFolders = [];
  String? _destinationFolder;
  bool _isBackingUp = false;
  bool _isIntegrityChecking = false;
  String _feedbackMessage = '';
  List<String> _logMessages = [];

  // Getters for state variables
  List<String> get sourceFolders => _sourceFolders;
  String? get destinationFolder => _destinationFolder;
  bool get isBackingUp => _isBackingUp;
  bool get isIntegrityChecking => _isIntegrityChecking;
  String get feedbackMessage => _feedbackMessage;
  List<String> get logMessages => _logMessages;

  final List<ProgressUpdate> _localHistory = [];
  final int _maxHistoryItems = 100; // Limite de itens no histórico

  /// Sets up the ProgressHUD widget for showing operation progress
  void setProgressHUD(ProgressHUDState? progressHUD) {
    _progressHUD = progressHUD;
    _logger.i("ProgressHUD configured: ${progressHUD != null}");
  }

  // Método para registrar progresso
  void _reportProgress({
    required String message,
    double progress = 0.0,
    ProgressType type = ProgressType.working,
    bool showHUD = true,
  }) {
    // Adiciona ao histórico local
    final update =
        ProgressUpdate(message: message, progress: progress, type: type);
    _localHistory.add(update);

    // Mantém o histórico dentro do limite
    if (_localHistory.length > _maxHistoryItems) {
      _localHistory.removeAt(0);
    }

    // Atualiza mensagem de feedback
    _feedbackMessage = message;

    // Atualiza o ProgressHUD se disponível
    if (_progressHUD != null && showHUD) {
      if (_progressHUD!.isLoading) {
        _progressHUD!.updateProgress(
          message: message,
          progress: progress,
          type: type,
        );
      } else if (showHUD) {
        _progressHUD!.show(
          message: message,
          progress: progress,
          type: type,
        );
      }
    }

    notifyListeners();
  }

  // Método para finalizar operação
  void _completeOperation({
    required String message,
    required bool success,
    bool hideHUD = true,
  }) {
    final type = success ? ProgressType.success : ProgressType.error;

    // Registra a conclusão
    _reportProgress(
      message: message,
      progress: 1.0,
      type: type,
      showHUD: false,
    );

    // Oculta o HUD se solicitado
    if (_progressHUD != null && hideHUD) {
      _progressHUD!.hide(completionMessage: message, type: type);
    }

    notifyListeners();
  }

  // Obtém o histórico local
  List<ProgressUpdate> get operationHistory => List.unmodifiable(_localHistory);

  // Expõe o ProgressHUD para widgets que precisam acessá-lo (como o widget de histórico)
  ProgressHUDState? get progressHUD => _progressHUD;

  /// Clears the operation history
  void clearOperationHistory() {
    _localHistory.clear();
    notifyListeners();
  }

  /// Adds a source folder to the backup list
  Future<void> addSourceFolder(String folderPath) async {
    // Normalizar caminho para formato Windows
    final normalizedPath = path.windows.normalize(folderPath);
    await _backupModel.addSourceFolder(normalizedPath);
    _sourceFolders = [normalizedPath, ..._sourceFolders];
    _updateFeedback();
  }

  /// Sets the destination folder for backups
  Future<void> setDestinationFolder(String folderPath) async {
    // Normalizar caminho para formato Windows
    final normalizedPath = path.windows.normalize(folderPath);
    await _backupModel.setDestinationFolder(normalizedPath);
    _destinationFolder = normalizedPath;
    _updateFeedback();
  }

  /// Updates the progress HUD with a new value and message
  void _updateProgress(double value, String message) {
    if (_progressHUD != null) {
      _progressHUD!.setValue(value);
      _progressHUD!.setText(message);
    }
  }

  /// Shows the progress HUD with initial values
  void _showProgress(String initialMessage) {
    if (_progressHUD != null) {
      _progressHUD!.show();
      _updateProgress(0.0, initialMessage);
    }
  }

  /// Hides the progress HUD
  void _hideProgress() {
    _progressHUD?.dismiss();
  }

  /// Performs the backup operation with progress updates
  Future<bool> startBackup() async {
    if (_sourceFolders.isEmpty || _destinationFolder == null) {
      setFeedbackMessage(
          "Defina pastas de origem e destino antes de iniciar o backup.");
      return false;
    }

    _isBackingUp = true;
    _showProgress(
        "Iniciando backup..."); // Mostrar progresso antes de limpar mensagens
    _logMessages.clear();
    _updateUI();

    try {
      final result = await _backupModel.backupFolders(
        (conflictPath) async => true, // Always replace on conflict
        (progress) {
          final percentage = (progress * 100).toInt();
          if (progress < 0.1) {
            _updateProgress(progress, "Preparando arquivos...");
          } else if (progress < 0.5) {
            _updateProgress(progress, "Copiando arquivos: $percentage%");
          } else if (progress < 0.9) {
            _updateProgress(progress, "Finalizando cópias: $percentage%");
          } else {
            _updateProgress(progress, "Concluindo backup: $percentage%");
          }
          _updateFeedback();
        },
      );

      if (result) {
        _updateProgress(1.0, "Backup concluído!");
        await Future.delayed(_completionDelay);
      }

      return result;
    } catch (e) {
      _logger.e("Erro ao realizar backup: $e");
      setFeedbackMessage("Erro ao realizar backup: $e");
      return false;
    } finally {
      _isBackingUp = false;
      _hideProgress();
      _updateUI();
    }
  }

  /// Checks the integrity of backed up files
  Future<void> checkIntegrity() async {
    if (_sourceFolders.isEmpty || _destinationFolder == null) {
      setFeedbackMessage(
          "Defina pastas de origem e destino antes de verificar a integridade.");
      return;
    }

    _isIntegrityChecking = true;
    _showProgress(
        "Verificando integridade..."); // Mostrar progresso antes de limpar mensagens
    _logMessages.clear();
    _updateUI();

    try {
      // Garantir que o ProgressHUD seja mostrado antes de qualquer operação
      _showProgress("Verificando integridade...");

      // Start integrity check progress simulation
      final progressUpdater =
          Stream.periodic(const Duration(milliseconds: 500), (i) => i);
      final subscription = progressUpdater.listen((i) {
        if (_isIntegrityChecking) {
          final progress = 0.05 + (i * 0.03);
          if (progress <= 0.95) {
            _updateProgress(progress, "Verificando arquivos...");
          }
        }
      });

      final result = await _backupModel.checkIntegrity();
      await subscription.cancel();

      _updateProgress(
          1.0,
          result
              ? "Verificação concluída com sucesso!"
              : "Falha na verificação!");
      await Future.delayed(_completionDelay);

      setFeedbackMessage(result
          ? "✅ Verificação de integridade concluída com sucesso!"
          : "❌ Falha na verificação de integridade. Verifique o backup.");
    } catch (e) {
      _logger.e("Erro durante verificação de integridade: $e");
      setFeedbackMessage("❌ Erro durante verificação de integridade: $e");
    } finally {
      _isIntegrityChecking = false;
      _hideProgress();
      _updateUI();
    }
  }

  /// Creates symbolic links for backed up folders
  Future<bool> createSymbolicLink() async {
    if (_sourceFolders.isEmpty || _destinationFolder == null) {
      setFeedbackMessage(
          "Defina pastas de origem e destino antes de criar links simbólicos.");
      return false;
    }

    try {
      _showProgress("Criando link simbólico...");

      for (String folderPath in _sourceFolders) {
        String linkName = path.basename(folderPath);
        String targetPath = path.join(_destinationFolder!, linkName);
        await _backupModel.createSymbolicLink(targetPath, folderPath);
        _updateFeedback();
      }

      _updateProgress(1.0, "Link simbólico criado!");
      await Future.delayed(_completionDelay);

      return true;
    } catch (e) {
      _logger.e("Erro ao criar link simbólico: $e");
      setFeedbackMessage("Erro ao criar link simbólico: $e");
      return false;
    } finally {
      _hideProgress();
    }
  }

  /// Updates feedback message and logs
  void setFeedbackMessage(String message) {
    _feedbackMessage = message;
    _logMessages.add(message);
    _trimLogMessages();
    _updateUI();
  }

  /// Removes a source folder from the backup list
  void removeSourceFolder(String folderPath) {
    _backupModel.removeSourceFolder(folderPath);
    _sourceFolders.remove(folderPath);
    _updateFeedback();
  }

  /// Trims log messages to prevent memory issues
  void _trimLogMessages() {
    if (_logMessages.length > _maxLogMessages) {
      _logMessages =
          _logMessages.sublist(_logMessages.length - _maxLogMessages);
    }
  }

  /// Updates feedback from the backup model
  void _updateFeedback() {
    if (_backupModel.feedbackMessages.isNotEmpty) {
      final newMessage = _backupModel.feedbackMessages.last;
      if (newMessage != _feedbackMessage) {
        setFeedbackMessage(newMessage);
      }
    }
  }

  /// Notifies listeners of state changes
  void _updateUI() {
    notifyListeners();
  }

  Future<bool?> _showConfirmationDialog(
      BuildContext context, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirmação'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  /// Executa o backup das pastas selecionadas
  Future<void> backupFolders(
    BuildContext context,
    Future<bool> Function(String error) onError,
  ) async {
    if (_sourceFolders.isEmpty || _destinationFolder == null) {
      setFeedbackMessage(
          "Defina pastas de origem e destino antes de iniciar o backup.");
      return;
    }

    _isBackingUp = true;
    _updateUI();

    try {
      final result = await _backupModel.backupFolders(
        (conflictPath) async {
          final bool? shouldReplace = await _showConfirmationDialog(
            context,
            'A pasta "$conflictPath" já existe no destino. Deseja substituí-la?',
          );
          return shouldReplace ?? false;
        },
        (progress) {
          _updateProgress(
              progress, "Fazendo backup: ${(progress * 100).toInt()}%");
        },
      );

      if (!result) {
        const errorMessage =
            "Falha ao realizar o backup. Verifique os logs para mais detalhes.";
        await onError(errorMessage);
      } else {
        setFeedbackMessage("✅ Backup concluído com sucesso!");
      }
    } catch (e) {
      await onError(e.toString());
    } finally {
      _isBackingUp = false;
      _hideProgress();
      _updateUI();
    }
  }

  /// Deletes the source folder after confirming that backup was created
  Future<void> deleteSourceFolder() async {
    if (_sourceFolders.isEmpty) {
      setFeedbackMessage("Nenhuma pasta de origem selecionada para excluir.");
      return;
    }

    try {
      _showProgress("Excluindo pasta de origem...");

      for (final folderPath in _sourceFolders.toList()) {
        await _backupModel.deleteSourceFolder(folderPath);
        _sourceFolders.remove(folderPath);
      }

      setFeedbackMessage("✅ Pasta(s) de origem excluída(s) com sucesso!");
    } catch (e) {
      setFeedbackMessage("❌ Erro ao excluir pasta(s) de origem: $e");
    } finally {
      _hideProgress();
      _updateUI();
    }
  }

  Future<bool> deleteSourceFolderAndCreateLink() async {
    if (_sourceFolders.isEmpty || _destinationFolder == null) {
      setFeedbackMessage(
          "Defina pastas de origem e destino antes de apagar e criar links simbólicos.");
      return false;
    }

    try {
      _showProgress("Apagando pasta de origem e criando link simbólico...");

      for (String folderPath in _sourceFolders) {
        // Apagar a pasta de origem
        await _backupModel.deleteSourceFolder(folderPath);

        // Criar o link simbólico
        String linkName = path.basename(folderPath);
        String targetPath = path.join(_destinationFolder!, linkName);
        await _backupModel.createSymbolicLink(targetPath, folderPath);
        _updateFeedback();
      }

      _updateProgress(1.0, "Pasta apagada e link simbólico criado!");
      await Future.delayed(_completionDelay);

      return true;
    } catch (e) {
      _logger.e("Erro ao apagar pasta e criar link simbólico: $e");
      setFeedbackMessage("Erro ao apagar pasta e criar link simbólico: $e");
      return false;
    } finally {
      _hideProgress();
    }
  }
}
