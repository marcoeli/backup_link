import 'package:flutter/material.dart';

import '../models/progress_update.dart';

/// Widget que exibe um indicador de progresso sobreposto na interface
class ProgressHUD extends StatefulWidget {
  final Widget child;

  const ProgressHUD({super.key, required this.child});

  @override
  State<ProgressHUD> createState() => ProgressHUDState();

  /// Método estático para acessar o estado do ProgressHUD
  static ProgressHUDState? of(BuildContext context) {
    return context.findAncestorStateOfType<ProgressHUDState>();
  }
}

/// Estado do widget ProgressHUD, responsável por gerenciar a visualização do HUD de progresso
class ProgressHUDState extends State<ProgressHUD> {
  // Usando public para evitar erros de API pública com tipo privado
  bool isLoading = false;
  ProgressUpdate? currentProgress;

  /// Lista para manter histórico de atualizações
  final List<ProgressUpdate> _progressHistory = [];

  /// Mostra o indicador de progresso com uma mensagem
  void show(
      {String message = 'Processando...',
      double progress = 0.0,
      ProgressType type = ProgressType.working}) {
    setState(() {
      isLoading = true;
      currentProgress =
          ProgressUpdate(message: message, progress: progress, type: type);

      // Adiciona ao histórico
      _progressHistory.add(currentProgress!);
    });
  }

  /// Define o valor do progresso (0.0 a 1.0)
  void setValue(double value) {
    if (currentProgress != null) {
      setState(() {
        currentProgress = currentProgress!.copyWith(progress: value);
      });
    }
  }

  /// Define o texto a ser exibido no HUD
  void setText(String message) {
    if (currentProgress != null) {
      setState(() {
        currentProgress = currentProgress!.copyWith(message: message);
      });
    }
  }

  /// Atualiza o progresso atual
  void updateProgress(
      {required String message,
      required double progress,
      ProgressType type = ProgressType.working}) {
    setState(() {
      currentProgress = ProgressUpdate(
        message: message,
        progress: progress,
        type: type,
      );

      // Atualiza o histórico
      _progressHistory.add(currentProgress!);
    });
  }

  /// Oculta o indicador de progresso
  void hide(
      {String? completionMessage, ProgressType type = ProgressType.success}) {
    setState(() {
      isLoading = false;

      // Adicionar mensagem de conclusão ao histórico, se fornecida
      if (completionMessage != null) {
        _progressHistory.add(ProgressUpdate(
          message: completionMessage,
          progress: 1.0,
          type: type,
        ));
      }
    });
  }

  /// Alias para hide() - para manter compatibilidade com APIs existentes
  void dismiss() {
    hide();
  }

  /// Limpa o histórico de operações
  void clearHistory() {
    setState(() {
      _progressHistory.clear();
    });
  }

  /// Retorna o histórico de progresso
  List<ProgressUpdate> get progressHistory =>
      List.unmodifiable(_progressHistory);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        currentProgress?.type.icon ?? Icons.hourglass_bottom,
                        color: currentProgress?.type.color ?? Colors.purple,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      if (currentProgress != null) ...[
                        Text(
                          currentProgress!.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            value: currentProgress!.progress > 0
                                ? currentProgress!.progress
                                : null,
                            minHeight: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              currentProgress!.type.color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Exibir progresso em percentual
                        Text(
                          currentProgress!.progress > 0
                              ? '${(currentProgress!.progress * 100).toStringAsFixed(1)}%'
                              : 'Aguarde...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ] else
                        const CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
