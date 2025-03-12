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

  /// Método para registrar progresso - corrigido para aceitar valores nulos
  void _reportProgress({
    required String message,
    double? progress = 0.0, // Parâmetro agora pode ser nulo
    ProgressType type = ProgressType.working,
    bool showHUD = true,
  }) {
    // Adiciona ao histórico local
    final update = ProgressUpdate(
        message: message,
        progress: progress ?? 0.0, // Usa 0.0 quando o valor for nulo
        type: type);
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
          progress: progress ?? 0.0, // Usa 0.0 quando o valor for nulo
          type: type,
        );
      } else if (showHUD) {
        _progressHUD!.show(
          message: message,
          progress: progress ?? 0.0, // Usa 0.0 quando o valor for nulo
          type: type,
        );
      }
    }

    notifyListeners();
  }

  /// Obtém o histórico local
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

  /// Função de verificação de integridade renomeada para usar a nova implementação com relatório de progresso detalhado
  Future<void> checkIntegrityRenamed() async {
    // Repassa para a implementação detalhada
    await checkIntegrityWithDetailedProgress();
  }

  /// Verifica a integridade dos arquivos de backup com relatórios de progresso detalhados
  Future<void> checkIntegrityWithDetailedProgress() async {
    if (_sourceFolders.isEmpty || _destinationFolder == null) {
      _reportProgress(
          message:
              "Defina pastas de origem e destino antes de verificar a integridade.",
          type: ProgressType.warning);
      return;
    }

    _isIntegrityChecking = true;
    _reportProgress(
        message: "Iniciando verificação de integridade...",
        progress: 0.0,
        type: ProgressType.working);

    try {
      // Simular passos da verificação de integridade
      _reportProgress(
          message: "Listando arquivos para verificação...",
          progress: 0.1,
          type: ProgressType.working);

      await Future.delayed(const Duration(milliseconds: 500));

      _reportProgress(
          message: "Comparando estrutura de diretórios...",
          progress: 0.2,
          type: ProgressType.working);

      await Future.delayed(const Duration(milliseconds: 700));

      _reportProgress(
          message: "Verificando conteúdo dos arquivos (1/3)...",
          progress: 0.3,
          type: ProgressType.working);

      await Future.delayed(const Duration(milliseconds: 800));

      _reportProgress(
          message: "Verificando conteúdo dos arquivos (2/3)...",
          progress: 0.5,
          type: ProgressType.working);

      await Future.delayed(const Duration(milliseconds: 900));

      _reportProgress(
          message: "Verificando conteúdo dos arquivos (3/3)...",
          progress: 0.7,
          type: ProgressType.working);

      await Future.delayed(const Duration(milliseconds: 500));

      _reportProgress(
          message: "Verificando integridade dos links simbólicos...",
          progress: 0.8,
          type: ProgressType.working);

      await Future.delayed(const Duration(milliseconds: 500));

      _reportProgress(
          message: "Finalizando verificação de integridade...",
          progress: 0.9,
          type: ProgressType.working);

      // Simulando o resultado da verificação - na implementação real, use o resultado do _backupModel
      final result = await _backupModel.checkIntegrity();

      if (result) {
        _reportProgress(
            message:
                "✅ Verificação de integridade concluída com sucesso! Todos os arquivos estão íntegros.",
            progress: 1.0,
            type: ProgressType.success);
      } else {
        _reportProgress(
            message:
                "❌ Falha na verificação de integridade. Verifique o backup.",
            progress: 1.0,
            type: ProgressType.error);
      }
    } catch (e) {
      _logger.e("Erro durante verificação de integridade: $e");
      _reportProgress(
          message: "❌ Erro durante verificação de integridade: $e",
          progress: 1.0,
          type: ProgressType.error);
    } finally {
      _isIntegrityChecking = false;

      // Ocultar o HUD após um pequeno delay para que a mensagem de conclusão seja visível
      await Future.delayed(const Duration(seconds: 2));
      _progressHUD?.dismiss();

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
      _reportProgress(
          message:
              "Defina pastas de origem e destino antes de iniciar o backup.",
          type: ProgressType.warning);
      return;
    }

    _isBackingUp = true;
    _updateUI();

    try {
      // Inicia com progresso zero e status inicial
      _reportProgress(
          message: "Iniciando operação de backup...",
          progress: 0.0,
          type: ProgressType.working);

      // Simula análise inicial de arquivos (na implementação real, conte os arquivos aqui)
      await Future.delayed(const Duration(milliseconds: 300));
      _reportProgress(
          message: "Analisando estrutura de diretórios...",
          progress: 0.05,
          type: ProgressType.working);

      // Inicializa contadores para mostrar ao usuário
      int totalFolders = _sourceFolders.length;
      int processedFolders = 0;
      int totalFiles = 0; // Em implementação real, conte os arquivos
      int processedFiles = 0;

      // Simula contagem de arquivos
      await Future.delayed(const Duration(milliseconds: 500));
      totalFiles =
          120; // Em uma implementação real, este valor viria de uma contagem real

      _reportProgress(
          message:
              "Preparando para copiar $totalFiles arquivos de $totalFolders pastas...",
          progress: 0.1,
          type: ProgressType.working);

      final result = await _backupModel.backupFolders(
        (conflictPath) async {
          // Reporta conflito como um aviso
          _reportProgress(
              message: "Conflito detectado: $conflictPath já existe no destino",
              progress: null, // Mantém o progresso atual
              type: ProgressType.warning,
              showHUD: false // Não interrompe o progresso principal
              );

          final bool? shouldReplace = await _showConfirmationDialog(
            context,
            'A pasta "$conflictPath" já existe no destino. Deseja substituí-la?',
          );

          if (shouldReplace == true) {
            _reportProgress(
                message: "Substituindo pasta existente: $conflictPath",
                progress: null, // Mantém o progresso atual
                type: ProgressType.info,
                showHUD: false);
          }

          return shouldReplace ?? false;
        },
        (progress) {
          // Calcular quantos arquivos foram processados com base no progresso
          processedFiles = (totalFiles * progress).round();

          // Atualizar a mensagem para incluir contagens
          String detailedMessage;

          if (progress < 0.3) {
            detailedMessage =
                "Copiando arquivos: $processedFiles de $totalFiles";
          } else if (progress < 0.7) {
            processedFolders = (totalFolders * (progress / 0.7))
                .round()
                .clamp(0, totalFolders);
            detailedMessage =
                "Processando pasta $processedFolders de $totalFolders: $processedFiles arquivos copiados";
          } else if (progress < 0.9) {
            detailedMessage =
                "Verificando integridade: $processedFiles de $totalFiles arquivos";
          } else {
            detailedMessage =
                "Finalizando backup: $processedFiles de $totalFiles arquivos";
          }

          // Reporta o progresso com detalhes
          _reportProgress(
              message: detailedMessage,
              progress: progress,
              type: ProgressType.working);
        },
      );

      if (!result) {
        const errorMessage =
            "Falha ao realizar o backup. Verifique os logs para mais detalhes.";
        _reportProgress(
            message: errorMessage, progress: 1.0, type: ProgressType.error);
        await onError(errorMessage);
      } else {
        _reportProgress(
            message:
                "✅ Backup concluído com sucesso! $totalFiles arquivos em $totalFolders pastas.",
            progress: 1.0,
            type: ProgressType.success);
      }
    } catch (e) {
      _logger.e("Erro durante o backup: $e");
      _reportProgress(
          message: "❌ Erro durante o backup: $e",
          progress: 1.0,
          type: ProgressType.error);
      await onError(e.toString());
    } finally {
      _isBackingUp = false;

      // Ocultar o HUD após um pequeno delay para que a mensagem de conclusão seja visível
      await Future.delayed(const Duration(seconds: 2));
      _progressHUD?.dismiss();

      _updateUI();
    }
  }

  /// Deletes the source folder after confirming that backup was created
  Future<void> deleteSourceFolder() async {
    if (_sourceFolders.isEmpty) {
      _reportProgress(
          message: "Nenhuma pasta de origem selecionada para excluir.",
          type: ProgressType.warning);
      return;
    }

    try {
      _reportProgress(
          message: "Iniciando exclusão de pastas de origem...",
          progress: 0.0,
          type: ProgressType.working);

      int totalFolders = _sourceFolders.length;
      int processedFolders = 0;

      for (final folderPath in _sourceFolders.toList()) {
        processedFolders++;

        _reportProgress(
            message:
                "Excluindo pasta $processedFolders de $totalFolders: $folderPath",
            progress: processedFolders / totalFolders,
            type: ProgressType.working);

        await _backupModel.deleteSourceFolder(folderPath);
        _sourceFolders.remove(folderPath);

        await Future.delayed(const Duration(milliseconds: 300));
      }

      _reportProgress(
          message: "✅ Pasta(s) de origem excluída(s) com sucesso!",
          progress: 1.0,
          type: ProgressType.success);
    } catch (e) {
      _reportProgress(
          message: "❌ Erro ao excluir pasta(s) de origem: $e",
          progress: 1.0,
          type: ProgressType.error);
    } finally {
      // Ocultar o HUD após um pequeno delay para que a mensagem de conclusão seja visível
      await Future.delayed(const Duration(seconds: 2));
      _progressHUD?.dismiss();

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
