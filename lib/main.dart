import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:win32/win32.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Folder Backup App',
      home: BackupScreen(),
    );
  }
}

class BackupScreen extends StatefulWidget {
  const BackupScreen({Key? key}) : super(key: key);

  @override
  BackupScreenState createState() => BackupScreenState();
}

class BackupScreenState extends State<BackupScreen> {
  List<String> selectedFolderPaths = [];
  String selectedDestinationPath = '';
  String feedbackMessage = '';
  bool isCopying = false;
  bool isIntegrityCheckComplete = false;

  Future<void> selectFolders() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        setState(() {
          selectedFolderPaths.add(result);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao selecionar pastas: $e');
      }
    }
  }

  Future<void> selectDestination() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        setState(() {
          selectedDestinationPath = result;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao selecionar a pasta de destino: $e');
      }
    }
  }

  Future<void> backupFolders() async {
    setState(() {
      isCopying = true;
      feedbackMessage = 'Backup em andamento...';
    });
    for (var folderPath in selectedFolderPaths) {
      final backupDirectory = Directory(path.join(selectedDestinationPath, path.basename(folderPath)));
      final originalDirectory = Directory(folderPath);

      if (!await backupDirectory.exists()) {
        await backupDirectory.create(recursive: true);
      }

      await _copyFolder(originalDirectory, backupDirectory);
    }
    setState(() {
      isCopying = false;
      feedbackMessage = 'Backup concluído. Verificando integridade...';
    });

    checkBackupIntegrity();
  }

  Future<void> checkBackupIntegrity() async {
    bool integrityCheck = true;
    for (var folderPath in selectedFolderPaths) {
      final backupDirectory = Directory(path.join(selectedDestinationPath, path.basename(folderPath)));
      final originalDirectory = Directory(folderPath);
      if (!_compareDirectories(originalDirectory, backupDirectory)) {
        integrityCheck = false;
        break;
      }
    }
    setState(() {
      isIntegrityCheckComplete = true;
      feedbackMessage = integrityCheck ? 'Integridade verificada com sucesso!' : 'Erro na verificação de integridade!';
    });
  }

  bool _compareDirectories(Directory dir1, Directory dir2) {
    final entities1 = dir1.listSync(recursive: true);
    final entities2 = dir2.listSync(recursive: true);

    if (entities1.length != entities2.length) {
      return false;
    }

    for (int i = 0; i < entities1.length; i++) {
      if (entities1[i] is File && entities2[i] is File) {
        final file1Bytes = (entities1[i] as File).readAsBytesSync();
        final file2Bytes = (entities2[i] as File).readAsBytesSync();
        if (!listEquals(file1Bytes, file2Bytes)) {
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _copyFolder(Directory source, Directory destination) async {
    for (var entity in source.listSync()) {
      if (entity is Directory) {
        final newDirectory = Directory(path.join(destination.path, entity.uri.pathSegments.last));
        if (!newDirectory.existsSync()) {
          newDirectory.createSync();
        }
        await _copyFolder(entity, newDirectory);
      } else if (entity is File) {
        entity.copySync(path.join(destination.path, entity.uri.pathSegments.last));
      }
    }
  }

  void removeReadOnlyAttributeRecursive(String folderPath) {
    final pathPointer = TEXT(folderPath);

    final attributes = GetFileAttributes(pathPointer);
    const invalidFileAttributes = -1;

    if (attributes != invalidFileAttributes && (attributes & FILE_ATTRIBUTE_READONLY) != 0) {
      SetFileAttributes(pathPointer, attributes & ~FILE_ATTRIBUTE_READONLY);
    }
    free(pathPointer);

    final dir = Directory(folderPath);
    for (var entity in dir.listSync()) {
      if (entity is Directory) {
        removeReadOnlyAttributeRecursive(entity.path);
      } else if (entity is File) {
        final filePathPointer = TEXT(entity.path);
        final fileAttributes = GetFileAttributes(filePathPointer);
        if (fileAttributes != invalidFileAttributes && (fileAttributes & FILE_ATTRIBUTE_READONLY) != 0) {
          SetFileAttributes(filePathPointer, fileAttributes & ~FILE_ATTRIBUTE_READONLY);
        }
        free(filePathPointer);
      }
    }
  }

  Future<void> createSymbolicLink(String target, String link) async {
    final processResult = await Process.run('cmd', ['/c', 'mklink', '/D', link, target]);
    if (processResult.exitCode != 0) {
      throw Exception('Erro ao criar link simbólico: ${processResult.stderr}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder Backup App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: selectFolders,
              child: const Text('Selecionar Pastas de Origem'),
            ),
            const SizedBox(height: 20),
            if (selectedFolderPaths.isNotEmpty) ...[
              const Text(
                'Pastas selecionadas:',
                style: TextStyle(fontSize: 16),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: selectedFolderPaths.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(selectedFolderPaths[index]),
                    );
                  },
                ),
              ),
            ],
            ElevatedButton(
              onPressed: selectDestination,
              child: const Text('Selecionar Pasta de Destino'),
            ),
            if (selectedDestinationPath.isNotEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Confirmação'),
                        content: const Text('Deseja fazer o backup?'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              backupFolders();
                            },
                            child: const Text('Confirmar'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text('Fazer Backup'),
              ),
            ],
            if (isIntegrityCheckComplete) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Confirmação'),
                        content: const Text('Deseja criar o link simbólico e apagar a pasta de origem?'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              for (var folderPath in selectedFolderPaths) {
                                final originalDirectory = Directory(folderPath);
                                removeReadOnlyAttributeRecursive(folderPath);
                                originalDirectory.deleteSync(recursive: true);
                                createSymbolicLink(selectedDestinationPath, folderPath);
                              }
                              setState(() {
                                feedbackMessage = 'Link simbólico criado e pasta de origem apagada.';
                              });
                            },
                            child: const Text('Confirmar'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text('Criar Link Simbólico e Apagar Pasta de Origem'),
              ),
            ],
            const SizedBox(height: 20),
            if (isCopying) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Realizando a cópia...'),
            ],
            const SizedBox(height: 20),
            Text(feedbackMessage),
          ],
        ),
      ),
    );
  }
}
