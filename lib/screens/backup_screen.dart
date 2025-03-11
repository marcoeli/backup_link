import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/backup_provider.dart';
import '../utils/file_utils.dart';
// Importe também seu BackupProvider aqui

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder Backup App'),
      ),
      body: const Column(
        children: [
          // Widgets para selecionar pastas de origem
          SourceFoldersWidget(),

          // Widget para selecionar pasta de destino
          DestinationFolderWidget(),

          // Botões para operações
          OperationsWidget(),

          // Widget para feedback e progresso
          FeedbackWidget(),
        ],
      ),
    );
  }
}

class SourceFoldersWidget extends StatelessWidget {
  const SourceFoldersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Usando o Provider para acessar o BackupProvider
    final backupProvider = Provider.of<BackupProvider>(context);

    return Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            // Logic to select and add a source folder
            String? folderPath = await showFolderPickerDialog(
                context); // Você precisará implementar essa função
            if (folderPath != null) {
              backupProvider.addSourceFolder(folderPath);
            }
          },
          child: const Text('Adicionar Pasta de Origem'),
        ),
        SizedBox(height: 200,
          child: ListView.builder(
            itemCount: backupProvider.sourceFolders.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(backupProvider.sourceFolders[index]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    backupProvider.removeSourceFolder(backupProvider
                            .sourceFolders[
                        index]); // Adicionamos esta operação no BackupProvider
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class DestinationFolderWidget extends StatelessWidget {
  const DestinationFolderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Usando o Provider para acessar o BackupProvider
    final backupProvider = Provider.of<BackupProvider>(context);

    return Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            // Lógica para selecionar e definir a pasta de destino
            String? folderPath = await showFolderPickerDialog(context);
            if (folderPath != null) {
              backupProvider.setDestinationFolder(folderPath);
            }
          },
          child: const Text('Definir Pasta de Destino'),
        ),
        const SizedBox(height: 10),
        // Exibe a pasta de destino selecionada
        if (backupProvider.destinationFolder != null &&
            backupProvider.destinationFolder!.isNotEmpty)
          Text('Pasta de Destino: ${backupProvider.destinationFolder}'),
      ],
    );
  }
}

class OperationsWidget extends StatelessWidget {
  const OperationsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Usando o Provider para acessar o BackupProvider
    final backupProvider = Provider.of<BackupProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              // Pedir confirmação ao usuário
              bool? confirm = await showConfirmationDialog(
                  context, 'Deseja iniciar o backup?');
              if (confirm == true) {
                backupProvider.backupFolders((error) async {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Erro'),
                      content: Text('Ocorreu um erro durante o backup: $error'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Fechar'),
                        ),
                      ],
                    ),
                  );
                  return false; // Agora que a função é async, retornará um Future<bool>
                });
              }
            },
            child: const Text('Iniciar Backup'),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () async {
                // Pedir confirmação ao usuário
                bool? confirm = await showConfirmationDialog(
                    context, 'Deseja verificar a integridade do backup?');
                if (confirm == true) {
                  backupProvider.checkIntegrity();
                }
              },
              child: const Text('Verificar Integridade'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () async {
                // Pedir confirmação ao usuário
                bool? confirm = await showConfirmationDialog(
                    context, 'Deseja apagar a pasta de origem?');
                if (confirm == true) {
                  backupProvider.deleteSourceFolder();
                }
              },
              child: const Text('Apagar Pasta de Origem'),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Pedir confirmação ao usuário
              bool? confirm = await showConfirmationDialog(
                  context, 'Deseja criar um link simbólico?');
              if (confirm == true) {
                backupProvider.createSymbolicLink();
              }
            },
            child: const Text('Criar Link Simbólico'),
          ),
        ],
      ),
    );
  }
}

Future<bool?> showConfirmationDialog(
    BuildContext context, String message) async {
  return await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
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
      );
    },
  );
}

class FeedbackWidget extends StatelessWidget {
  const FeedbackWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenha o BackupProvider para acessar as mensagens de feedback
    final backupProvider = Provider.of<BackupProvider>(context, listen: true);
    
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Text(
            'Feedback:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(backupProvider.feedbackMessage),
        ],
      ),
    );
  }
}


