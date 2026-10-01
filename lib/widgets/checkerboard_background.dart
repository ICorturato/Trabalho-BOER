import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Widget que exibe o padrão quadriculado transparente típico de editores de imagem,
/// facilitando a visualização de imagens com fundo transparente geradas pela API Poof.
class CheckerboardWidget extends StatelessWidget {
  const CheckerboardWidget({
    super.key,
    required this.child,
    this.borderRadius = 8.0,
  });

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CustomPaint(
        painter: _CheckerboardPainter(),
        child: child,
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = Colors.white;
    final paint2 = Paint()..color = const Color(0xFFE2E8F0);
    const squareSize = 8.0;

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isEven = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isEven ? paint1 : paint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Widget auxiliar para renderizar a imagem do produto (suporta URL remota e Base64 Data URI)
class ApiProductImage extends StatelessWidget {
  const ApiProductImage({
    super.key,
    required this.imageUrl,
    this.size = 56,
    this.showCheckerboard = true,
  });

  final String imageUrl;
  final double size;
  final bool showCheckerboard;

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (imageUrl.isEmpty) {
      imageWidget = Container(
        width: size,
        height: size,
        color: Colors.green.shade50,
        child: Icon(Icons.shopping_bag_outlined, color: Colors.green.shade700, size: size * 0.5),
      );
    } else if (imageUrl.startsWith('data:image')) {
      try {
        final commaIndex = imageUrl.indexOf(',');
        final base64Str = commaIndex != -1 ? imageUrl.substring(commaIndex + 1) : imageUrl;
        final Uint8List bytes = base64Decode(base64Str);
        imageWidget = Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _errorPlaceholder(),
        );
      } catch (_) {
        imageWidget = _errorPlaceholder();
      }
    } else {
      imageWidget = Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _errorPlaceholder(),
      );
    }

    if (showCheckerboard) {
      return CheckerboardWidget(
        borderRadius: 8,
        child: SizedBox(
          width: size,
          height: size,
          child: imageWidget,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: size, height: size, child: imageWidget),
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.shade200,
      child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade500, size: size * 0.5),
    );
  }
}
