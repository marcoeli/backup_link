// models/backup_model.dart

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';

import '../utils/file_utils.dart';

/// A model class that handles backup operations and file system management.
/// Supports Windows-specific optimizations for handling long paths and symbolic links.
class BackupModel {
  /// List of source folders to be backed up
  List<String> sourceFolders = [];

  /// Destination folder where backups will be stored
  String? destinationFolder;

  /// List of feedback messages for operation progress and status
  List<String> feedbackMessages = [];

  /// Constants for file operations
  static const int _largeFileThreshold = 100 * 1024 * 1024; // 100MB
  static const int _sampleFileCount = 10;
  static const int _robocopySuccessMaxCode = 7;

  /// Common PowerShell parameters for file operations
  static const Map<String, List<String>> _powershellCommands = {
    'countFiles': [
      '-Command',
      "(Get-ChildItem -Path '{path}' -Recurse -File).Count"
    ],
    'listFiles': [
      '-Command',
      "Get-ChildItem -Path '{path}' -Recurse -File | ForEach-Object { \$_.FullName }"
    ],
    'calculateHash': [
      '-Command',
      "Get-FileHash -Path '{path}' -Algorithm SHA256 | Select-Object -ExpandProperty Hash"
    ]
  };

  /// Common robocopy parameters for file operations
  static const List<String> _robocopyBaseParams = [
    '/E', // Copy subdirectories
    '/COPY:DAT', // Copy data, attributes, and timestamps
    '/R:1', // Number of retries
    '/W:1', // Wait time between retries
    '/NFL', // No file list
    '/NDL' // No directory list
  ];

  // Adicionar pasta de origem à lista
  Future<void> addSourceFolder(String folderPath) async {
    // Preparar o caminho para lidar com caminhos longos
    String normalizedPath = preparePath(folderPath);

    if (_isSymbolicLink(normalizedPath)) {
      feedbackMessages.add(
          'A pasta "$folderPath" é um link simbólico e não pode ser adicionada.');
      return;
    }

    if (sourceFolders.contains(normalizedPath)) {
      feedbackMessages.add('A pasta "$folderPath" já foi adicionada.');
      return;
    }

    if (isPathTooLong(normalizedPath)) {
      // Avisa sobre caminho longo mas continua (em Windows usaremos o formato longo)
      feedbackMessages.add(
          'Atenção: O caminho "$folderPath" é muito longo, o que pode causar problemas no Windows.');
    }

    sourceFolders.add(normalizedPath);
    feedbackMessages.add('A pasta "$folderPath" foi adicionada com sucesso.');
  }

  // Definir a pasta de destino
  Future<void> setDestinationFolder(String folderPath) async {
    // Preparar o caminho para lidar com caminhos longos
    String normalizedPath = preparePath(folderPath);

    if (destinationFolder != null) {
      feedbackMessages.add(
          'Substituindo a pasta de destino existente "$destinationFolder" pela nova pasta "$folderPath".');
    }

    destinationFolder = normalizedPath;
    feedbackMessages
        .add('A pasta "$folderPath" foi definida como pasta de destino.');
  }

  // Fazer backup das pastas de origem para a pasta de destino
  Future<bool> backupFolders(
      Future<bool> Function(String conflictingFolder) onFolderConflict,
      void Function(double progress) onProgress) async {
    if (destinationFolder == null || sourceFolders.isEmpty) {
      feedbackMessages.add(
          'Por favor, defina a pasta de destino e adicione pastas de origem antes de prosseguir com o backup.');
      return false;
    }

    try {
      // Reportar progresso inicial para mostrar que a operação começou
      onProgress(0.01);

      // Para cada pasta de origem, contar arquivos usando métodos alternativos
      int totalFiles = await _countTotalFiles();

      if (totalFiles == 0) totalFiles = 1; // Evitar divisão por zero

      feedbackMessages.add('Iniciando backup de $totalFiles arquivos...');
      onProgress(0.05); // Atualiza progresso após contagem

      // Realizar o backup de cada pasta de origem
      int folderIndex = 0;
      for (var folderPath in sourceFolders) {
        folderIndex++;
        final folderName = path.basename(shortenPath(folderPath));
        final backupDirectoryPath = path.join(destinationFolder!, folderName);
        final normalizedBackupPath = preparePath(backupDirectoryPath);
        final backupDirectory = Directory(normalizedBackupPath);

        // Atualizar progresso ao iniciar cada pasta
        onProgress(0.05 + (0.90 * (folderIndex - 1) / sourceFolders.length));
        feedbackMessages.add(
            'Processando pasta $folderIndex de ${sourceFolders.length}: "$folderName"');

        // Verificar se já existe na pasta de destino
        try {
          if (await backupDirectory.exists()) {
            bool replace = await onFolderConflict(backupDirectoryPath);
            if (replace) {
              // Para caminhos longos, usar robocopy com opção /PURGE no Windows
              if (Platform.isWindows) {
                await _deleteDirectoryWithRobocopy(backupDirectory.path);
              } else {
                await backupDirectory.delete(recursive: true);
              }

              // Passar uma função de progresso que atualiza corretamente baseado no progresso geral
              double progressBasePorcentagem =
                  0.05 + (0.90 * (folderIndex - 1) / sourceFolders.length);
              double progressIncrementoPorPasta = 0.90 / sourceFolders.length;

              await _copyFolderAlternative(folderPath, normalizedBackupPath,
                  (folderProgress) {
                double overallProgress = progressBasePorcentagem +
                    (progressIncrementoPorPasta * folderProgress);
                onProgress(overallProgress);
              });
            }
          } else {
            // Passar uma função de progresso que atualiza corretamente baseado no progresso geral
            double progressBasePorcentagem =
                0.05 + (0.90 * (folderIndex - 1) / sourceFolders.length);
            double progressIncrementoPorPasta = 0.90 / sourceFolders.length;

            await _copyFolderAlternative(folderPath, normalizedBackupPath,
                (folderProgress) {
              double overallProgress = progressBasePorcentagem +
                  (progressIncrementoPorPasta * folderProgress);
              onProgress(overallProgress);
            });
          }
        } catch (e) {
          feedbackMessages
              .add('Erro durante o backup da pasta "$folderPath": $e');
          return false;
        }
      }

      // Progresso final
      onProgress(1.0);
      feedbackMessages.add('Backup concluído com sucesso.');
      return true;
    } catch (e) {
      feedbackMessages.add('Erro durante o processo de backup: $e');
      return false;
    }
  }

  Future<void> _copyFolder(String sourcePath, String destinationPath,
      void Function(double progress) onProgress) async {
    final sourceDirectory = Directory(sourcePath);
    final destinationDirectory = Directory(destinationPath);

    if (!await destinationDirectory.exists()) {
      await destinationDirectory.create(recursive: true);
    }

    try {
      // Copiando conteúdo
      await for (var entity in sourceDirectory.list()) {
        if (entity is Directory) {
          final destSubDir =
              path.join(destinationPath, path.basename(entity.path));
          final normalizedDestSubDir = preparePath(destSubDir);
          await _copyFolder(entity.path, normalizedDestSubDir, onProgress);
        } else if (entity is File) {
          final destFile =
              path.join(destinationPath, path.basename(entity.path));
          final normalizedDestFile = preparePath(destFile);
          await entity.copy(normalizedDestFile);
          onProgress(1.0);
        }
      }
    } catch (e) {
      // Tenta uma abordagem alternativa para caminhos problemáticos
      if (Platform.isWindows && e.toString().contains('path')) {
        // Usa robocopy no Windows para arquivos com caminhos muito longos
        try {
          final srcShortened = shortenPath(sourcePath);
          final destShortened = shortenPath(destinationPath);

          final result = await _executeRobocopy(srcShortened, destShortened);

          // Robocopy tem códigos de saída específicos que não indicam erro
          if (!_isRobocopySuccess(result.exitCode)) {
            throw Exception('Erro ao usar robocopy: ${result.stderr}');
          }

          onProgress(1.0);
        } catch (robocopyError) {
          throw Exception(
              'Falha ao copiar usando métodos alternativos: $robocopyError');
        }
      } else {
        throw Exception('Erro ao copiar pasta: $e');
      }
    }
  }

  // Método alternativo para copiar pasta usando robocopy no Windows
  Future<void> _copyFolderAlternative(String sourcePath, String destinationPath,
      void Function(double progress) onProgress) async {
    try {
      // Indicar início da operação
      onProgress(0.01);

      if (Platform.isWindows) {
        // Usar robocopy para Windows
        final srcPath = shortenPath(sourcePath);
        final destPath = shortenPath(destinationPath);

        // Para feedback visual durante o processo, vamos usar um timer que atualiza o progresso
        // pois o robocopy não fornece atualizações em tempo real
        bool operationComplete = false;
        int stepCount = 0;

        // Timer para simular o progresso
        final progressTimer =
            Stream.periodic(const Duration(milliseconds: 500), (i) => i);
        final subscription = progressTimer.listen((i) {
          if (!operationComplete) {
            // Limita o progresso a 0.99 para reservar 1.0 para conclusão
            double simulatedProgress = 0.01 + (i * 0.03);
            if (simulatedProgress > 0.99) simulatedProgress = 0.99;
            onProgress(simulatedProgress);
            stepCount++;

            // Reportar progresso contínuo a cada 10 passos
            if (stepCount % 10 == 0) {
              feedbackMessages.add(
                  'Copiando arquivos... (tempo decorrido: ${stepCount / 2} segundos)');
            }
          }
        });

        // Exemplo de uso do robocopy com parâmetros aprimorados
        final result = await _executeRobocopy(srcPath, destPath);

        // Cancelar o timer de progresso
        operationComplete = true;
        await subscription.cancel();

        // Robocopy tem códigos de saída específicos (0-7 são considerados sucessos)
        if (!_isRobocopySuccess(result.exitCode)) {
          throw Exception('Erro ao usar robocopy: ${result.stderr}');
        }

        // Progresso concluído
        onProgress(1.0);
      } else {
        // Método padrão para outros sistemas operacionais
        await _copyFolder(sourcePath, destinationPath, onProgress);
      }
    } catch (e) {
      throw Exception('Erro ao copiar pasta: $e');
    }
  }

  // Método para apagar diretório usando robocopy (para lidar com caminhos longos no Windows)
  Future<void> _deleteDirectoryWithRobocopy(String directoryPath) async {
    if (Platform.isWindows) {
      // Criar um diretório vazio temporário
      final tempDir = Directory.systemTemp.createTempSync('empty_dir_');
      try {
        // Usar robocopy com /MIR para espelhar o diretório vazio no diretório alvo, efetivamente apagando-o
        final result = await _executeRobocopy(
            tempDir.path, shortenPath(directoryPath), ['/MIR']);

        // Robocopy retorna códigos não zero mesmo em caso de sucesso
        // 0-7 são considerados sucesso para robocopy
        if (!_isRobocopySuccess(result.exitCode)) {
          throw Exception(
              'Erro ao apagar diretório usando robocopy: ${result.stderr}');
        }

        // Remover o diretório vazio temporário após o uso
        await tempDir.delete(recursive: true);
      } catch (e) {
        // Remover o diretório vazio temporário em caso de erro
        await tempDir.delete(recursive: true);
        rethrow;
      }
    } else {
      // Em outros sistemas, usar método padrão
      await Directory(directoryPath).delete(recursive: true);
    }
  }

  // Verificar a integridade dos backups
  Future<bool> checkIntegrity() async {
    if (destinationFolder == null || sourceFolders.isEmpty) {
      feedbackMessages.add(
          'Por favor, defina a pasta de destino e adicione pastas de origem antes de verificar a integridade.');
      return false;
    }

    try {
      for (var folderPath in sourceFolders) {
        final folderName = path.basename(shortenPath(folderPath));
        final backupDirectoryPath = path.join(destinationFolder!, folderName);

        feedbackMessages.add('Verificando pasta: "$folderName"');
        feedbackMessages.add('Caminho de origem: "$folderPath"');
        feedbackMessages.add('Caminho de backup: "$backupDirectoryPath"');

        // Normalizar caminhos para evitar problemas com caminhos longos
        final normalizedBackupPath = preparePath(backupDirectoryPath);

        final originalDirectory = Directory(folderPath);
        final backupDirectory = Directory(normalizedBackupPath);

        // Verificar se as pastas existem
        if (!await originalDirectory.exists()) {
          feedbackMessages.add(
              'A pasta de origem "$folderPath" não existe mais. Verifique se foi removida ou movida.');
          return false;
        }

        if (!await backupDirectory.exists()) {
          feedbackMessages.add(
              'A pasta de backup "$backupDirectoryPath" não existe. Verifique se o backup foi realizado.');
          return false;
        }

        // Primeiro, verificar se o número de arquivos corresponde
        feedbackMessages.add('Contando arquivos nas pastas...');
        bool countMatch =
            await _verifyFileCount(originalDirectory, backupDirectory);
        if (!countMatch) {
          feedbackMessages.add(
              'Falha na verificação de integridade: número de arquivos diferente.');
          return false;
        }

        // Se a contagem estiver correta, realizar verificação de hash em arquivos selecionados
        feedbackMessages
            .add('Verificando integridade dos arquivos (usando hash)...');
        bool hashMatch =
            await _verifySelectedFileHashes(originalDirectory, backupDirectory);
        if (!hashMatch) {
          feedbackMessages.add(
              'Falha na verificação de integridade: hash dos arquivos não correspondem.');
          return false;
        }

        feedbackMessages.add('✓ Pasta "$folderName" verificada com sucesso!');
      }

      feedbackMessages.add(
          '✅ Verificação de integridade concluída com sucesso para todas as pastas.');
      return true;
    } catch (e) {
      feedbackMessages.add('❌ Erro durante a verificação de integridade: $e');
      return false;
    }
  }

  // Método para verificar se o número de arquivos corresponde
  Future<bool> _verifyFileCount(Directory original, Directory backup) async {
    try {
      // No Windows, usar PowerShell para contar arquivos
      if (Platform.isWindows) {
        final psCommand = '''
          \$origFiles = (Get-ChildItem -Path '${shortenPath(original.path).replaceAll("'", "''")}' -Recurse -File -ErrorAction SilentlyContinue).Count
          \$backupFiles = (Get-ChildItem -Path '${shortenPath(backup.path).replaceAll("'", "''")}' -Recurse -File -ErrorAction SilentlyContinue).Count
          Write-Output "\$origFiles;\$backupFiles"
        ''';

        final result = await _executePowerShell(psCommand, original.path);
        final output = result.stdout.toString().trim();
        final parts = output.split(';');

        if (parts.length == 2) {
          final origCount = int.tryParse(parts[0]) ?? 0;
          final backupCount = int.tryParse(parts[1]) ?? 0;

          feedbackMessages.add('Arquivos na pasta de origem: $origCount');
          feedbackMessages.add('Arquivos na pasta de backup: $backupCount');

          return origCount == backupCount;
        }

        return false;
      } else {
        // Para outros sistemas operacionais, usar código Dart
        int origCount = 0;
        int backupCount = 0;

        await for (var entity in original.list(recursive: true)) {
          if (entity is File) origCount++;
        }

        await for (var entity in backup.list(recursive: true)) {
          if (entity is File) backupCount++;
        }

        feedbackMessages.add('Arquivos na pasta de origem: $origCount');
        feedbackMessages.add('Arquivos na pasta de backup: $backupCount');

        return origCount == backupCount;
      }
    } catch (e) {
      feedbackMessages.add('Erro ao contar arquivos: $e');
      return false;
    }
  }

  // Método para verificar hash de arquivos selecionados (uma amostra)
  Future<bool> _verifySelectedFileHashes(
      Directory original, Directory backup) async {
    try {
      // Selecionar uma amostra de arquivos para verificação (até 10 arquivos)
      final sampleFiles = await _getSampleFiles(original);

      if (sampleFiles.isEmpty) {
        feedbackMessages
            .add('Nenhum arquivo encontrado para verificação de hash.');
        return true; // Consideramos sucesso se não há arquivos para verificar
      }

      feedbackMessages
          .add('Verificando hash de ${sampleFiles.length} arquivo(s)...');

      for (final origFile in sampleFiles) {
        // Obter caminho relativo
        final relativePath = origFile.path.substring(original.path.length);

        // Construir caminho correspondente na pasta de backup
        final backupFilePath = path.join(backup.path, relativePath);
        final backupFile = File(backupFilePath);

        // Verificar se arquivo existe no backup
        if (!await backupFile.exists()) {
          feedbackMessages.add(
              'Arquivo não encontrado no backup: ${path.basename(origFile.path)}');
          return false;
        }

        // Calcular e comparar hashes
        try {
          final origHash = await _calculateFileHash(origFile.path);
          final backupHash = await _calculateFileHash(backupFile.path);

          if (origHash != backupHash) {
            feedbackMessages.add(
                'Hash diferente para o arquivo: ${path.basename(origFile.path)}');
            return false;
          }

          feedbackMessages.add(
              '✓ Hash verificado com sucesso: ${path.basename(origFile.path)}');
        } catch (e) {
          feedbackMessages.add(
              'Erro ao calcular hash para ${path.basename(origFile.path)}: $e');
          return false;
        }
      }

      return true;
    } catch (e) {
      feedbackMessages.add('Erro ao verificar hash dos arquivos: $e');
      return false;
    }
  }

  // Método para selecionar uma amostra de arquivos para verificação
  Future<List<File>> _getSampleFiles(Directory directory) async {
    List<File> allFiles = [];

    try {
      if (Platform.isWindows) {
        // Usar PowerShell para listar arquivos
        final result = await _executePowerShell(
            _powershellCommands['listFiles']!.join(' '), directory.path);

        final paths = result.stdout
            .toString()
            .trim()
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .map((line) => File(line.trim()))
            .toList();

        // Se encontramos menos de 10 arquivos, use todos eles
        if (paths.length <= _sampleFileCount) return paths;

        // Caso contrário, selecionar 10 arquivos aleatoriamente
        paths.shuffle();
        return paths.take(_sampleFileCount).toList();
      } else {
        // Para outros SOs, usar código Dart
        await for (var entity in directory.list(recursive: true)) {
          if (entity is File) {
            allFiles.add(entity);
            if (allFiles.length >= _sampleFileCount) break;
          }
        }

        // Se encontramos menos de 10 arquivos, use todos eles
        if (allFiles.length <= _sampleFileCount) return allFiles;

        // Caso contrário, selecionar 10 arquivos aleatoriamente
        allFiles.shuffle();
        return allFiles.take(_sampleFileCount).toList();
      }
    } catch (e) {
      feedbackMessages.add('Erro ao selecionar arquivos para amostra: $e');
      return [];
    }
  }

  // Auxiliar para calcular o hash de um arquivo - versão melhorada
  Future<String> _calculateFileHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Arquivo não existe: $filePath');
      }

      // Para arquivos muito grandes, usar abordagem de stream para evitar carregar tudo na memória
      if (await file.length() > _largeFileThreshold) {
        // 100MB
        feedbackMessages.add(
            'Usando hash parcial para arquivo grande: ${path.basename(filePath)}');
        return _calculatePartialFileHash(filePath);
      }

      // Para arquivos menores, ler tudo de uma vez
      final fileBytes = await file.readAsBytes();
      return sha256.convert(fileBytes).toString();
    } catch (e) {
      // Se o erro for relacionado a caminhos longos no Windows
      if (Platform.isWindows &&
          (e.toString().contains('path') ||
              e.toString().contains('caminho') ||
              e.toString().contains('não foi possível'))) {
        // Tenta usar o caminho com prefixo '\\?\' para resolver problemas de caminhos longos
        try {
          final nativePath = preparePath(filePath);
          final file = File(nativePath);
          final fileBytes = await file.readAsBytes();
          return sha256.convert(fileBytes).toString();
        } catch (e2) {
          // Se ainda falhar, tenta usar PowerShell para calcular o hash
          try {
            return await _calculateHashWithPowerShell(filePath);
          } catch (e3) {
            throw Exception(
                'Todas as tentativas de calcular hash falharam: $e3');
          }
        }
      }

      throw Exception('Erro ao calcular hash do arquivo $filePath: $e');
    }
  }

  /// Calculates a hash for the given file. For large files, only portions are hashed.
  /// Public for testing purposes.
  Future<String> calculateFileHash(String filePath) async {
    return _calculateFileHash(filePath);
  }

  // Calcular hash parcial (apenas início, meio e fim do arquivo)
  Future<String> _calculatePartialFileHash(String filePath) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();

      // Ler blocos do início, meio e fim do arquivo
      final startBytes =
          await _readFileChunk(file, 0, 1024 * 1024); // 1MB do início

      // Posição do meio (menos metade do bloco)
      final middlePosition = (fileSize ~/ 2) - (512 * 1024);
      final middleBytes = await _readFileChunk(
          file, middlePosition, 1024 * 1024); // 1MB do meio

      // Posição do final (1MB antes do fim)
      final endPosition = fileSize - (1024 * 1024);
      final endBytes =
          await _readFileChunk(file, endPosition, 1024 * 1024); // 1MB do fim

      // Combinar os bytes e calcular hash
      final combinedBytes = [...startBytes, ...middleBytes, ...endBytes];
      return sha256.convert(combinedBytes).toString();
    } catch (e) {
      throw Exception('Erro ao calcular hash parcial: $e');
    }
  }

  // Ler um pedaço específico do arquivo
  Future<List<int>> _readFileChunk(File file, int start, int length) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      await raf.setPosition(start);
      // Limitar o tamanho da leitura ao tamanho do arquivo
      final fileSize = await file.length();
      final actualLength =
          (start + length > fileSize) ? (fileSize - start).toInt() : length;
      return raf.readSync(actualLength).toList();
    } finally {
      await raf.close();
    }
  }

  // Usar PowerShell para calcular hash (para casos onde o acesso direto falha)
  Future<String> _calculateHashWithPowerShell(String filePath) async {
    final result = await _executePowerShell(
        _powershellCommands['calculateHash']!.join(' '), filePath);

    if (result.exitCode != 0 || result.stdout.toString().trim().isEmpty) {
      throw Exception('Erro ao calcular hash com PowerShell: ${result.stderr}');
    }

    return result.stdout.toString().trim().toLowerCase();
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
      _removeReadOnlyAttributeRecursive(folderPath);

      try {
        await directory.delete(recursive: true);
        feedbackMessages.add('Pasta "$folderPath" foi apagada com sucesso.');
      } catch (e) {
        // Em caso de erro, tenta usar o comando rd no Windows
        if (Platform.isWindows) {
          try {
            final shortPath = shortenPath(folderPath);
            final result =
                await Process.run('cmd', ['/c', 'rd', '/s', '/q', shortPath]);

            if (result.exitCode == 0) {
              feedbackMessages.add(
                  'Pasta "$folderPath" foi apagada com sucesso usando comando alternativo.');
            } else {
              throw Exception(
                  'Erro ao apagar pasta usando comando alternativo: ${result.stderr}');
            }
          } catch (cmdError) {
            throw Exception('Não foi possível apagar a pasta: $cmdError');
          }
        } else {
          throw Exception('Erro ao apagar pasta: $e');
        }
      }
    }
  }

  // Criar um link simbólico
  Future<void> createSymbolicLink(String target, String link) async {
    // Preparar os caminhos
    final normalizedTarget = preparePath(target);
    final normalizedLink = preparePath(link);

    try {
      if (Platform.isWindows) {
        // No Windows, usa o comando mklink diretamente
        final shortTarget = shortenPath(normalizedTarget);
        final shortLink = shortenPath(normalizedLink);

        final processResult = await Process.run(
            'cmd', ['/c', 'mklink', '/D', shortLink, shortTarget]);

        if (processResult.exitCode != 0) {
          throw Exception(
              'Erro ao criar link simbólico: ${processResult.stderr}');
        }

        feedbackMessages.add(
            'Link simbólico criado com sucesso de "$link" para "$target".');
      } else {
        // Em sistemas Unix-like
        await Link(normalizedLink).create(normalizedTarget);
        feedbackMessages.add(
            'Link simbólico criado com sucesso de "$link" para "$target".');
      }
    } catch (e) {
      feedbackMessages.add('Erro ao criar link simbólico: $e');
      throw Exception('Erro ao criar link simbólico: $e');
    }
  }

  // Auxiliar para verificar se uma pasta é um link simbólico
  bool _isSymbolicLink(String folderPath) {
    if (Platform.isWindows) {
      final pathPointer = TEXT(shortenPath(folderPath));
      final fileAttributes = GetFileAttributes(pathPointer);
      free(pathPointer);
      return (fileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
    } else {
      return FileSystemEntity.isLinkSync(folderPath);
    }
  }

  void removeSourceFolder(String folderPath) {
    sourceFolders.remove(folderPath);
    feedbackMessages.add('Pasta "$folderPath" removida da lista de origem.');
  }

  /// Execute a PowerShell command with proper error handling
  Future<ProcessResult> _executePowerShell(String command, String path) async {
    final normalizedPath = shortenPath(path).replaceAll("'", "''");
    final fullCommand = command.replaceAll('{path}', normalizedPath);
    return Process.run('powershell', ['-Command', fullCommand]);
  }

  /// Execute robocopy with standard parameters
  Future<ProcessResult> _executeRobocopy(String source, String destination,
      [List<String> additionalParams = const []]) async {
    final params = [
      shortenPath(source),
      shortenPath(destination),
      ..._robocopyBaseParams,
      ...additionalParams,
    ];
    return Process.run('robocopy', params);
  }

  /// Verify robocopy exit code (0-7 indicate success)
  bool _isRobocopySuccess(int exitCode) => exitCode <= _robocopySuccessMaxCode;

  /// Conta o número total de arquivos em todas as pastas de origem
  Future<int> _countTotalFiles() async {
    int totalFiles = 0;
    for (var folderPath in sourceFolders) {
      try {
        if (Platform.isWindows) {
          // Usar PowerShell para contar arquivos
          final result = await _executePowerShell(
              _powershellCommands['countFiles']!.join(' '), folderPath);

          if (result.exitCode == 0) {
            final count = int.tryParse(result.stdout.toString().trim()) ?? 0;
            totalFiles += count;
            feedbackMessages
                .add('Encontrados $count arquivos em "$folderPath"');
          } else {
            // Fallback: assumir um valor base se não conseguir contar
            totalFiles += 100; // Valor arbitrário
            feedbackMessages.add(
                'Não foi possível contar arquivos em "$folderPath". Usando estimativa.');
          }
        } else {
          final files = Directory(folderPath)
              .listSync(recursive: true)
              .whereType<File>()
              .length;
          totalFiles += files;
          feedbackMessages.add('Encontrados $files arquivos em "$folderPath"');
        }
      } catch (e) {
        // Fallback: assumir um valor base se não conseguir contar
        totalFiles += 100; // Valor arbitrário
        feedbackMessages.add(
            'Não foi possível contar arquivos em "$folderPath". Usando estimativa.');
      }
    }
    return totalFiles;
  }
}
