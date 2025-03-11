// models/backup_model.dart

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';

class BackupModel {
  List<String> sourceFolders = [];
  String? destinationFolder;
  List<String> feedbackMessages = [];

  // Adicionar pasta de origem à lista
  Future<void> addSourceFolder(String folderPath) async {
    if (_isSymbolicLink(folderPath)) {
      feedbackMessages.add(
          'A pasta "$folderPath" é um link simbólico e não pode ser adicionada.');
      return;
    }

    if (sourceFolders.contains(folderPath)) {
      feedbackMessages.add('A pasta "$folderPath" já foi adicionada.');
      return;
    }

    sourceFolders.add(folderPath);
    feedbackMessages.add('A pasta "$folderPath" foi adicionada com sucesso.');
  }

  // Definir a pasta de destino
  Future<void> setDestinationFolder(String folderPath) async {
    if (destinationFolder != null) {
      feedbackMessages.add(
          'Substituindo a pasta de destino existente "$destinationFolder" pela nova pasta "$folderPath".');
    }

    destinationFolder = folderPath;
    feedbackMessages
        .add('A pasta "$folderPath" foi definida como pasta de destino.');
  }

  // Fazer backup das pastas de origem para a pasta de destino
  Future<void> backupFolders(
      Future<bool> Function(String conflictingFolder) onFolderConflict) async {
    if (destinationFolder == null || sourceFolders.isEmpty) {
      feedbackMessages.add(
          'Por favor, defina a pasta de destino e adicione pastas de origem antes de prosseguir com o backup.');
      return;
    }

    for (var folderPath in sourceFolders) {
      final backupDirectoryPath =
          path.join(destinationFolder!, path.basename(folderPath));
      final backupDirectory = Directory(backupDirectoryPath);

      // Verificar se já existe na pasta de destino
      if (await backupDirectory.exists()) {
        bool replace = await onFolderConflict(backupDirectoryPath);
        if (replace) {
          await backupDirectory.delete(
              recursive: true); // Exclui a pasta existente antes de copiar
          await _copyFolder(folderPath, backupDirectoryPath);
        }
      } else {
        await _copyFolder(folderPath, backupDirectoryPath);
      }
    }

    feedbackMessages.add('Backup concluído com sucesso.');
  }

  Future<void> _copyFolder(String sourcePath, String destinationPath) async {
    final sourceDirectory = Directory(sourcePath);
    final destinationDirectory = Directory(destinationPath);

    if (!await destinationDirectory.exists()) {
      await destinationDirectory.create(recursive: true);
    }

    // Copiando conteúdo
    for (var entity in sourceDirectory.listSync()) {
      if (entity is Directory) {
        await _copyFolder(entity.path,
            path.join(destinationPath, path.basename(entity.path)));
      } else if (entity is File) {
        await entity
            .copy(path.join(destinationPath, path.basename(entity.path)));
      }
    }
  }

  // Verificar a integridade dos backups
  Future<bool> checkIntegrity() async {
    for (var folderPath in sourceFolders) {
      final backupDirectoryPath =
          path.join(destinationFolder!, path.basename(folderPath));
      final originalDirectory = Directory(folderPath);
      final backupDirectory = Directory(backupDirectoryPath);

      if (!await _compareDirectoryHashes(originalDirectory, backupDirectory)) {
        feedbackMessages.add(
            'Falha na verificação de integridade para a pasta $folderPath.');
        return false;
      }
    }

    feedbackMessages.add('Verificação de integridade concluída com sucesso.');
    return true;
  }

  Future<bool> _compareDirectoryHashes(
      Directory original, Directory backup) async {
    final originalFiles =
        original.listSync(recursive: true).whereType<File>().toList();
    final backupFiles =
        backup.listSync(recursive: true).whereType<File>().toList();

    if (originalFiles.length != backupFiles.length) {
      return false;
    }

    for (int i = 0; i < originalFiles.length; i++) {
      final originalHash = await _calculateFileHash(originalFiles[i].path);
      final backupHash = await _calculateFileHash(backupFiles[i].path);

      if (originalHash != backupHash) {
        return false;
      }
    }

    return true;
  }

  // Auxiliar para calcular o hash de um arquivo
  Future<String> _calculateFileHash(String filePath) async {
    final fileBytes = await File(filePath).readAsBytes();
    return sha256.convert(fileBytes).toString();
  }

  // Remover o atributo somente leitura de uma pasta e seus subdiretórios/arquivos
  void _removeReadOnlyAttributeRecursive(String folderPath) {
    // Remova o atributo somente leitura da pasta principal
    _removeReadOnlyAttribute(folderPath);

    // Iterar pelos conteúdos do diretório
    final dir = Directory(folderPath);
    for (var entity in dir.listSync()) {
      if (entity is Directory) {
        _removeReadOnlyAttributeRecursive(
            entity.path); // Chamada recursiva para subdiretórios
      } else if (entity is File) {
        _removeReadOnlyAttribute(entity.path);
      }
    }
  }

  void _removeReadOnlyAttribute(String path) {
    final pathPointer = TEXT(path);
    final attributes = GetFileAttributes(pathPointer);
    const invalidFileAttributes = -1;

    if (attributes != invalidFileAttributes &&
        (attributes & FILE_ATTRIBUTE_READONLY) != 0) {
      SetFileAttributes(pathPointer, attributes & ~FILE_ATTRIBUTE_READONLY);
    }
    free(pathPointer); // Libera a memória alocada para o ponteiro
  }

  // Apagar a pasta de origem
  Future<void> deleteSourceFolder(String folderPath) async {
    final directory = Directory(folderPath);

    if (await directory.exists()) {
      _removeReadOnlyAttributeRecursive(
          folderPath); // Remover qualquer atributo "somente leitura"
      await directory.delete(recursive: true);
    }
  }

  // Criar um link simbólico
  Future<void> createSymbolicLink(String target, String link) async {
    final processResult =
        await Process.run('cmd', ['/c', 'mklink', '/D', link, target]);

    if (processResult.exitCode != 0) {
      throw Exception('Erro ao criar link simbólico: ${processResult.stderr}');
    }
  }

  // Auxiliar para verificar se uma pasta é um link simbólico
  bool _isSymbolicLink(String folderPath) {
    final pathPointer = TEXT(folderPath);
    final fileAttributes = GetFileAttributes(pathPointer);
    free(pathPointer);
    return (fileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
  }
  void removeSourceFolder(String folderPath) {
  sourceFolders.remove(folderPath);
}

}
