import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/backup_provider.dart';

Future<String?> showFolderPickerDialog(BuildContext context) async {
  // Usando o Provider para acessar o BackupProvider
  final backupProvider = Provider.of<BackupProvider>(context, listen: false);

  try {
    // Usar o FilePicker para obter o caminho da pasta selecionada
    final result = await FilePicker.platform.getDirectoryPath();

    if (result != null && result.isNotEmpty) {
      return result;
    }
  } catch (e) {
    backupProvider.setFeedbackMessage('Erro ao selecionar pasta: $e');
  }

  return null;
}
