import 'package:flutter/material.dart';

/// Modelo para representar atualizações de progresso em operações
class ProgressUpdate {
  /// Mensagem descritiva da etapa atual
  final String message;

  /// Progresso atual (0.0 a 1.0) ou null para indeterminado
  final double progress;

  /// Tipo de atualização para definir cores e ícones
  final ProgressType type;

  /// Hora em que o progresso foi registrado
  final DateTime timestamp;

  /// Construtor para criar uma nova atualização de progresso
  ProgressUpdate({
    required this.message,
    double? progress, // Agora aceita nulo como entrada
    this.type = ProgressType.info,
    DateTime? timestamp,
  })  :
        // Se progress for nulo, usamos 0.0 como valor padrão
        progress = progress ?? 0.0,
        timestamp = timestamp ?? DateTime.now();

  /// Método para criar cópia do objeto com alguns campos alterados
  ProgressUpdate copyWith({
    String? message,
    double? progress,
    ProgressType? type,
    DateTime? timestamp,
  }) {
    return ProgressUpdate(
      message: message ?? this.message,
      progress: progress, // Será null se não for especificado
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

int valorInteiro = 0; // Inicializa com um valor padrão

/// Tipos de atualizações de progresso
enum ProgressType { info, success, warning, error, working }

/// Extensão para obter cores e ícones com base no tipo de progresso
extension ProgressTypeExtension on ProgressType {
  /// Retorna a cor associada ao tipo de progresso
  Color get color {
    switch (this) {
      case ProgressType.info:
        return Colors.blue;
      case ProgressType.success:
        return Colors.green;
      case ProgressType.warning:
        return Colors.orange;
      case ProgressType.error:
        return Colors.red;
      case ProgressType.working:
        return Colors.purple;
    }
  }

  /// Retorna o ícone associado ao tipo de progresso
  IconData get icon {
    switch (this) {
      case ProgressType.info:
        return Icons.info_outline;
      case ProgressType.success:
        return Icons.check_circle_outline;
      case ProgressType.warning:
        return Icons.warning_amber_outlined;
      case ProgressType.error:
        return Icons.error_outline;
      case ProgressType.working:
        return Icons.hourglass_bottom;
    }
  }
}

/// Extensão para métodos auxiliares de cor
extension SafeColorMethods on Color {
  /// Versão segura do método para cores com transparência
  Color safeWithOpacity(double opacity) {
    // Usando os atributos modernos r, g, b em vez dos obsoletos
    return Color.fromRGBO(red, green, blue, opacity);
  }
}
