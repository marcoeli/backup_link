import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/progress_update.dart';
import '../providers/backup_provider.dart';

/// Widget que exibe o histórico de operações realizadas
class OperationHistoryWidget extends StatelessWidget {
  const OperationHistoryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final backupProvider = Provider.of<BackupProvider>(context);
    final history = backupProvider.operationHistory;

    // Se não houver histórico, exibe mensagem
    if (history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Nenhuma operação foi realizada ainda',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    // Exibe lista de operações em ordem cronológica inversa (mais recente primeiro)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Histórico de Operações',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            TextButton.icon(
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Limpar'),
              onPressed: () {
                // Limpar o histórico através do BackupProvider
                final provider =
                    Provider.of<BackupProvider>(context, listen: false);

                // Limpar histórico no ProgressHUD se disponível
                if (provider.progressHUD != null) {
                  provider.progressHUD!.clearHistory();
                }

                // Limpar histórico local no provider
                provider.clearOperationHistory();
              },
            ),
          ],
        ),
        const Divider(),
        ListView.builder(
          shrinkWrap: true,
          reverse: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length > 10
              ? 10
              : history.length, // Limita a exibição a 10 itens
          itemBuilder: (context, index) {
            // Índice reverso para mostrar itens mais recentes primeiro
            final item = history[history.length - 1 - index];
            return _buildHistoryItem(item);
          },
        ),
        if (history.length > 10)
          Center(
            child: TextButton(
              onPressed: () {
                // Abrir modal com histórico completo
                _showFullHistoryDialog(context, history);
              },
              child: const Text('Ver histórico completo'),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryItem(ProgressUpdate update) {
    final formatter = DateFormat('HH:mm:ss');
    final timeString = formatter.format(update.timestamp);

    return ListTile(
      leading: Icon(
        update.type.icon,
        color: update.type.color,
      ),
      title: Text(update.message),
      subtitle: Text(
        'Às $timeString',
        style: const TextStyle(fontSize: 12),
      ),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showFullHistoryDialog(
      BuildContext context, List<ProgressUpdate> history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Histórico Completo'),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            reverse: true,
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[history.length - 1 - index];
              return _buildHistoryItem(item);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
