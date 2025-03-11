import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../providers/backup_provider.dart';

Future<String?> showFolderPickerDialog(BuildContext context) async {
  // Usando o Provider para acessar o BackupProvider
  final backupProvider = Provider.of<BackupProvider>(context, listen: false);

  try {
    // Usar o FilePicker para obter o caminho da pasta selecionada
    final result = await FilePicker.platform.getDirectoryPath();

    if (result != null && result.isNotEmpty) {
      // Normaliza o caminho para evitar problemas com caminhos longos
      return preparePath(result);
    }
  } catch (e) {
    backupProvider.setFeedbackMessage('Erro ao selecionar pasta: $e');
  }

  return null;
}

/// Prepara um caminho para ser usado, lidando com caminhos longos no Windows
String preparePath(String filePath) {
  if (Platform.isWindows) {
    // Normaliza o caminho (converte / para \ e remove separadores duplicados)
    String normalizedPath = path.normalize(filePath);

    // Verifica se o caminho já está no formato longo do Windows
    if (!normalizedPath.startsWith(r'\\?\')) {
      // Se o caminho for muito longo ou tiver caracteres especiais, converte para o formato longo
      if (normalizedPath.length > 240 || normalizedPath.contains(' ')) {
        normalizedPath = r'\\?\' + normalizedPath;
      }
    }

    return normalizedPath;
  }

  // Em outros sistemas operacionais, apenas normaliza o caminho
  return path.normalize(filePath);
}

/// Converte um caminho longo do Windows de volta para o formato regular (se possível)
String shortenPath(String longPath) {
  if (Platform.isWindows && longPath.startsWith(r'\\?\')) {
    return longPath.substring(4);
  }
  return longPath;
}

/// Verifica se um caminho está dentro do limite seguro para Windows (< 260 caracteres)
bool isPathTooLong(String filePath) {
  if (Platform.isWindows) {
    // Desconta 12 caracteres para permitir nomes de arquivos
    return path.normalize(filePath).length >= 248;
  }
  return false;
}

/// Tenta encontrar um caminho alternativo mais curto se o caminho for muito longo
Future<String> findShorterPath(String originalPath) async {
  if (!isPathTooLong(originalPath)) {
    return originalPath;
  }

  if (Platform.isWindows) {
    // Tenta usar o caminho 8.3 mais curto no Windows
    try {
      final result = await Process.run(
          'cmd', ['/c', 'for %I in ("$originalPath") do @echo %~sI']);
      final shortPath = result.stdout.toString().trim();
      if (shortPath.isNotEmpty && shortPath != originalPath) {
        return shortPath;
      }
    } catch (e) {
      // Ignora erros e usa a solução alternativa
    }

    // Solução alternativa: mover arquivos para um caminho mais curto temporariamente
    final tempDir = Directory.systemTemp;
    final String fileName = path.basename(originalPath);
    final String tempPath = path.join(tempDir.path, fileName);

    return tempPath;
  }

  return originalPath;
}
