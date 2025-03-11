import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/backup_model.dart';

class BackupProvider with ChangeNotifier {
  final BackupModel _backupModel = BackupModel();

  // Variáveis de estado e suas respectivas operações
  List<String> _sourceFolders = [];
  String? _destinationFolder;
  bool _isBackingUp = false;
  bool _isIntegrityChecking = false;
  String _feedbackMessage = '';

  List<String> get sourceFolders => _sourceFolders;
  String? get destinationFolder => _destinationFolder;
  bool get isBackingUp => _isBackingUp;
  bool get isIntegrityChecking => _isIntegrityChecking;
  String get feedbackMessage => _feedbackMessage;

  void addSourceFolder(String folderPath) async {
    await _backupModel.addSourceFolder(folderPath);
    _sourceFolders = _backupModel.sourceFolders;
    _feedbackMessage = _backupModel.feedbackMessages.last;
    notifyListeners();
  }

  void setDestinationFolder(String folderPath) async {
    await _backupModel.setDestinationFolder(folderPath);
    _destinationFolder = _backupModel.destinationFolder;
    _feedbackMessage = _backupModel.feedbackMessages.last;
    notifyListeners();
  }

  Future<void> backupFolders(
      Future<bool> Function(String conflictingFolder) onFolderConflict) async {
    _isBackingUp = true;
    notifyListeners();

    await _backupModel.backupFolders(onFolderConflict);

    _feedbackMessage = _backupModel.feedbackMessages.last;
    _isBackingUp = false;
    notifyListeners();
  }

  Future<void> checkIntegrity() async {
    _isIntegrityChecking = true;
    notifyListeners();

    await _backupModel.checkIntegrity();

    _feedbackMessage = _backupModel.feedbackMessages.last;
    _isIntegrityChecking = false;
    notifyListeners();
  }

  void deleteSourceFolder() {
    for (String folderPath in _sourceFolders) {
      _sourceFolders
          .remove(folderPath); // Remover da lista local de pastas de origem

      _feedbackMessage = _backupModel.feedbackMessages.last;
      notifyListeners();
    }
  }

Future<void> createSymbolicLink() async {
  for (String folderPath in _sourceFolders) {
    String linkName = path.basename(folderPath);
    String targetPath = path.join(_destinationFolder!, linkName);
    
    await _backupModel.createSymbolicLink(targetPath, folderPath);

    _feedbackMessage = _backupModel.feedbackMessages.last;
    notifyListeners();
  }
}


  void setFeedbackMessage(String message) {
    _feedbackMessage = message;
    notifyListeners();
  }

  void removeSourceFolder(String folderPath) {
    _backupModel.removeSourceFolder(
        folderPath); // Esta operação também precisa ser adicionada no BackupModel
    _sourceFolders.remove(folderPath);
    notifyListeners();
  }

  // Outras operações e métodos conforme necessário
}
