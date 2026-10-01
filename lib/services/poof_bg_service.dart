import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Serviço de integração com a API Poof (https://poof.bg) para remoção de fundo de imagens
class PoofBgService {
  PoofBgService._internal();
  static final PoofBgService instance = PoofBgService._internal();

  /// URL oficial da API Poof
  static const String defaultEndpoint = 'https://api.poof.bg/v1/remove';

  /// Chave de API configurável (o usuário pode alterar nas configurações do app)
  String apiKey = '';

  /// Remove o fundo da imagem enviando uma requisição HTTP POST Multipart para a API Poof
  /// Retorna os bytes da imagem PNG com fundo transparente.
  Future<Uint8List> removeBackground({
    required Uint8List imageBytes,
    String? customApiKey,
  }) async {
    final key = customApiKey ?? apiKey;

    // Se houver uma chave de API fornecida, faz a requisição real à API Poof
    if (key.trim().isNotEmpty) {
      try {
        final uri = Uri.parse(defaultEndpoint);
        final request = http.MultipartRequest('POST', uri)
          ..headers['x-api-key'] = key.trim()
          ..files.add(
            http.MultipartFile.fromBytes(
              'image_file',
              imageBytes,
              filename: 'product_image.jpg',
            ),
          );

        final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          debugPrint('API Poof: Fundo removido com sucesso via HTTP POST (Poof Cloud)!');
          return response.bodyBytes;
        } else {
          final errorMsg = response.body.isNotEmpty ? response.body : 'Status ${response.statusCode}';
          debugPrint('API Poof retornou status ${response.statusCode}: $errorMsg. Usando fallback de processamento transparente.');
          // Prossegue para o fallback inteligente
        }
      } catch (e) {
        debugPrint('Erro na chamada HTTP da API Poof: $e. Aplicando processamento de transparência.');
      }
    }

    // Processamento / Fallback local para demonstração ou quando a chave da API não estiver preenchida:
    // Decodifica a imagem e converte pixels brancos/claros do fundo em canal Alfa transparente (PNG)
    return await compute(_processTransparencyLocal, imageBytes);
  }

  /// Converte a imagem tratada em Data URI Base64 pronta para persistência no CRUD REST
  String bytesToDataUri(Uint8List bytes) {
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }
}

/// Função de processamento isolado para remoção de fundo com transparência real em Dart (PNG com Alpha)
Uint8List _processTransparencyLocal(Uint8List inputBytes) {
  final original = img.decodeImage(inputBytes);
  if (original == null) return inputBytes;

  // Redimensiona para um tamanho ideal para transporte REST
  final resized = img.copyResize(
    original,
    width: original.width > 600 ? 600 : null,
    height: original.height > 600 ? 600 : null,
  );

  final result = img.Image(
    width: resized.width,
    height: resized.height,
    numChannels: 4, // RGBA com canal alfa
  );

  // Amostra a cor média das bordas da imagem para identificar o fundo
  int bgR = 255, bgG = 255, bgB = 255;
  if (resized.width > 4 && resized.height > 4) {
    final corner1 = resized.getPixel(0, 0);
    final corner2 = resized.getPixel(resized.width - 1, 0);
    final corner3 = resized.getPixel(0, resized.height - 1);
    final corner4 = resized.getPixel(resized.width - 1, resized.height - 1);

    bgR = ((corner1.r + corner2.r + corner3.r + corner4.r) / 4).round();
    bgG = ((corner1.g + corner2.g + corner3.g + corner4.g) / 4).round();
    bgB = ((corner1.b + corner2.b + corner3.b + corner4.b) / 4).round();
  }

  const threshold = 48.0; // Sensibilidade de tolerância para remoção do fundo

  for (int y = 0; y < resized.height; y++) {
    for (int x = 0; x < resized.width; x++) {
      final pixel = resized.getPixel(x, y);
      final r = pixel.r;
      final g = pixel.g;
      final b = pixel.b;

      // Distância Euclidiana de cor em relação à cor de fundo detectada
      final diff = ((r - bgR) * (r - bgR) + (g - bgG) * (g - bgG) + (b - bgB) * (b - bgB));
      final distance = diff > 0 ? (diff < 65536 ? (diff).toDouble() : 65536.0) : 0.0;

      if (distance < threshold * threshold || (r > 235 && g > 235 && b > 235)) {
        // Torna pixel 100% transparente
        result.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        result.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }

  return Uint8List.fromList(img.encodePng(result));
}
