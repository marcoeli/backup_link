import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/progress_update.dart';
import '../providers/backup_provider.dart';

/// Widget que exibe detalhes visuais do progresso da operação atual
class ProgressDetailsWidget extends StatelessWidget {
  const ProgressDetailsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtém o provider para acessar o histórico de operações
    final backupProvider = Provider.of<BackupProvider>(context);
    final history = backupProvider.operationHistory;

    // Se não houver histórico, não exibe nada
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    // Pega o último item (operação atual ou mais recente)
    final currentOperation = history.last;
    final bool isWorkInProgress = currentOperation.type == ProgressType.working;

    // Se não estiver em progresso e tiver progresso completo, não mostra
    if (!isWorkInProgress && currentOperation.progress >= 1.0) {
      return const SizedBox.shrink();
    }

    // Extrai as etapas anteriores da operação atual
    List<ProgressUpdate> operationSteps = _getRecentOperationSteps(history);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título da seção
            Row(
              children: [
                Icon(
                  isWorkInProgress
                      ? Icons.pending_actions
                      : Icons.assignment_turned_in,
                  color: currentOperation.type.color,
                ),
                const SizedBox(width: 8),
                Text(
                  isWorkInProgress
                      ? 'Operação em Andamento'
                      : 'Última Operação',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Indicador de progresso linear
            LinearProgressIndicator(
              value: currentOperation.progress > 0
                  ? currentOperation.progress
                  : null,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor:
                  AlwaysStoppedAnimation<Color>(currentOperation.type.color),
            ),

            // Percentual de progresso
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  currentOperation.progress > 0
                      ? '${(currentOperation.progress * 100).toStringAsFixed(1)}%'
                      : 'Processando...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: currentOperation.type.color,
                  ),
                ),
              ),
            ),

            // Mensagem atual
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // Usando os atributos modernos para cores
                color: Color.fromRGBO(
                    currentOperation.type.color.red,
                    currentOperation.type.color.green,
                    currentOperation.type.color.blue,
                    0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: currentOperation.type.color),
              ),
              child: Row(
                children: [
                  Icon(currentOperation.type.icon,
                      color: currentOperation.type.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentOperation.message,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getDarkerColor(currentOperation.type.color),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Lista de etapas anteriores
            if (operationSteps.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Etapas concluídas:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children:
                    operationSteps.map((step) => _buildStepItem(step)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Constrói um item individual para representar uma etapa do processo
  Widget _buildStepItem(ProgressUpdate step) {
    // Formatador para exibir o horário da etapa
    final formatter = DateFormat('HH:mm:ss');
    final timeString = formatter.format(step.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: step.type.color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.message,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            timeString,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Filtra o histórico para obter apenas as etapas da operação atual
  List<ProgressUpdate> _getRecentOperationSteps(List<ProgressUpdate> history) {
    // Pega as últimas 5 etapas da operação atual, excluindo a última (atual)
    List<ProgressUpdate> steps = [];

    // Identifica o tipo atual de operação baseado na última mensagem
    final currentType = _identifyOperationType(history.last.message);

    // Percorre o histórico de trás para frente
    for (int i = history.length - 2; i >= 0 && steps.length < 5; i--) {
      final item = history[i];
      // Inclui apenas se for do mesmo tipo de operação
      if (_identifyOperationType(item.message) == currentType) {
        steps.add(item);
      } else {
        // Se mudar o tipo de operação, para de adicionar
        break;
      }
    }

    // Inverte para mostrar em ordem cronológica
    return steps.reversed.toList();
  }

  /// Identifica o tipo de operação baseado na mensagem
  String _identifyOperationType(String message) {
    message = message.toLowerCase();
    if (message.contains('backup')) return 'backup';
    if (message.contains('integrid')) return 'integrity';
    if (message.contains('exclu')) return 'delete';
    if (message.contains('link')) return 'symlink';
    return 'other';
  }

  /// Retorna uma versão mais escura da cor para melhor contraste
  Color _getDarkerColor(Color color) {
    // Usa HSLColor para manipular a luminosidade de forma mais intuitiva
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.3).clamp(0.0, 1.0)).toColor();
  }
}
