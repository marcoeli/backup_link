import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/backup_provider.dart';
import '../widgets/progress_hud.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  @override
  void initState() {
    super.initState();
    // Configurar o ProgressHUD após o build inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final progressHUD = ProgressHUD.of(context);
      if (progressHUD != null) {
        Provider.of<BackupProvider>(context, listen: false)
            .setProgressHUD(progressHUD);
      }
    });
  }

  Future<bool?> showConfirmationDialog(
      BuildContext context, String message) async {
    final navigator = Navigator.of(context);
    // Guardar o contexto para uso posterior
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmação'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => navigator.pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProgressHUD(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Backup Link'),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            // Determine se estamos em um layout de tela larga (tablet/desktop) ou estreita (celular)
            final bool isWideScreen = constraints.maxWidth > 600;

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isWideScreen)
                      // Layout para telas largas - exibe pastas de origem e destino lado a lado
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Seleção de pastas de origem
                          Expanded(
                            flex: 1,
                            child: _buildSourceFoldersCard(),
                          ),
                          const SizedBox(width: 16),
                          // Seleção de pasta de destino
                          Expanded(
                            flex: 1,
                            child: _buildDestinationFolderCard(),
                          ),
                        ],
                      )
                    else
                      // Layout para telas estreitas - exibe pastas de origem e destino em coluna
                      Column(
                        children: [
                          _buildSourceFoldersCard(),
                          const SizedBox(height: 16),
                          _buildDestinationFolderCard(),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Operações
                    _buildOperationsCard(isWideScreen),

                    const SizedBox(height: 16),

                    // Feedback
                    _buildFeedbackCard(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Métodos para construir os diferentes cards da interface
  Widget _buildSourceFoldersCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pastas de Origem',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 12),
            SourceFoldersWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationFolderCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pasta de Destino',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 12),
            DestinationFolderWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationsCard(bool isWideScreen) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Operações',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            ResponsiveOperationsWidget(isWideScreen: isWideScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FeedbackWidget(),
          ],
        ),
      ),
    );
  }
}

// Widget responsivo para os botões de operação
class ResponsiveOperationsWidget extends StatelessWidget {
  final bool isWideScreen;

  const ResponsiveOperationsWidget({super.key, required this.isWideScreen});

  @override
  Widget build(BuildContext context) {
    // Obter o BackupProvider
    final backupProvider = Provider.of<BackupProvider>(context);

    // Lista de operações disponíveis
    final List<OperationButton> operations = [
      OperationButton(
        label: 'Iniciar Backup',
        icon: Icons.backup,
        onPressed: () async {
          final navigator = Navigator.of(context);
          bool? confirm =
              await showConfirmationDialog(context, 'Deseja iniciar o backup?');
          if (confirm == true) {
            backupProvider.backupFolders(context, (error) async {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Erro'),
                  content: Text('Ocorreu um erro durante o backup: $error'),
                  actions: [
                    TextButton(
                      onPressed: () => navigator.pop(),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              );
              return false;
            });
          }
        },
      ),
      OperationButton(
        label: 'Verificar Integridade',
        icon: Icons.verified,
        onPressed: () async {
          bool? confirm = await showConfirmationDialog(
              context, 'Deseja verificar a integridade do backup?');
          if (confirm == true) {
            backupProvider.checkIntegrity();
          }
        },
      ),
      OperationButton(
        label: 'Apagar Pasta de Origem',
        icon: Icons.delete_forever,
        onPressed: () async {
          bool? confirm = await showConfirmationDialog(
              context, 'Deseja apagar a pasta de origem?');
          if (confirm == true) {
            backupProvider.deleteSourceFolder();
          }
        },
      ),
      OperationButton(
        label: 'Criar Link Simbólico',
        icon: Icons.link,
        onPressed: () async {
          bool? confirm = await showConfirmationDialog(
              context, 'Deseja criar um link simbólico?');
          if (confirm == true) {
            backupProvider.createSymbolicLink();
          }
        },
      ),
    ];

    // Layout responsivo para os botões
    return isWideScreen
        ? Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children:
                operations.map((op) => _buildOperationButton(op)).toList(),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: operations
                .map((op) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _buildOperationButton(op),
                    ))
                .toList(),
          );
  }

  Widget _buildOperationButton(OperationButton operation) {
    return ElevatedButton.icon(
      onPressed: operation.onPressed,
      icon: Icon(operation.icon),
      label: Text(operation.label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }
}

// Modelo para botões de operação
class OperationButton {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  OperationButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

class SourceFoldersWidget extends StatelessWidget {
  const SourceFoldersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Usando o Provider para acessar o BackupProvider
    final backupProvider = Provider.of<BackupProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            // Logic to select and add a source folder
            String? folderPath = await showFolderPickerDialog(context);
            if (folderPath != null) {
              backupProvider.addSourceFolder(folderPath);
            }
          },
          icon: const Icon(Icons.create_new_folder),
          label: const Text('Adicionar Pasta de Origem'),
        ),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: backupProvider.sourceFolders.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Nenhuma pasta de origem selecionada',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: backupProvider.sourceFolders.length,
                  itemBuilder: (context, index) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(
                          backupProvider.sourceFolders[index],
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            backupProvider.removeSourceFolder(
                                backupProvider.sourceFolders[index]);
                          },
                        ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            // Lógica para selecionar e definir a pasta de destino
            String? folderPath = await showFolderPickerDialog(context);
            if (folderPath != null) {
              backupProvider.setDestinationFolder(folderPath);
            }
          },
          icon: const Icon(Icons.folder_special),
          label: const Text('Definir Pasta de Destino'),
        ),
        const SizedBox(height: 16),
        // Exibe a pasta de destino selecionada
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: backupProvider.destinationFolder != null &&
                  backupProvider.destinationFolder!.isNotEmpty
              ? Row(
                  children: [
                    const Icon(Icons.folder_open),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        backupProvider.destinationFolder!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : const Text(
                  'Nenhuma pasta de destino selecionada',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
        ),
      ],
    );
  }
}

// Implementação do método showFolderPickerDialog
Future<String?> showFolderPickerDialog(BuildContext context) async {
  String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'Selecione uma pasta',
  );
  return selectedDirectory;
}

Future<bool?> showConfirmationDialog(
    BuildContext context, String message) async {
  final navigator = Navigator.of(context);
  return await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Confirmação'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => navigator.pop(true),
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
    final bool hasFeedback = backupProvider.feedbackMessage.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline),
              SizedBox(width: 8),
              Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasFeedback ? Colors.blue.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    hasFeedback ? Colors.blue.shade200 : Colors.grey.shade300,
              ),
            ),
            child: Text(
              hasFeedback
                  ? backupProvider.feedbackMessage
                  : 'Nenhuma operação realizada ainda.',
              style: TextStyle(
                fontStyle: hasFeedback ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
