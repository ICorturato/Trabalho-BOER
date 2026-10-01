import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_product_service.dart';
import '../services/poof_bg_service.dart';

class ApiConfigDialog extends StatefulWidget {
  const ApiConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ApiConfigDialog(),
    );
  }

  @override
  State<ApiConfigDialog> createState() => _ApiConfigDialogState();
}

class _ApiConfigDialogState extends State<ApiConfigDialog> {
  late final TextEditingController _restUrlController;
  late final TextEditingController _poofKeyController;

  @override
  void initState() {
    super.initState();
    _restUrlController = TextEditingController(text: ApiProductService.instance.baseUrl);
    _poofKeyController = TextEditingController(text: PoofBgService.instance.apiKey);
  }

  @override
  void dispose() {
    _restUrlController.dispose();
    _poofKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newUrl = _restUrlController.text.trim();
    if (newUrl.isNotEmpty) {
      ApiProductService.instance.baseUrl = newUrl;
    }
    PoofBgService.instance.apiKey = _poofKeyController.text.trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (newUrl.isNotEmpty) await prefs.setString('api_base_url_storage_v1', newUrl);
      await prefs.setString('poof_api_key_storage_v1', PoofBgService.instance.apiKey);
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _resetDefaults() async {
    setState(() {
      _restUrlController.text = 'https://66e39ff9d2405277b06da8d3.mockapi.io/api/v1/products';
      _poofKeyController.clear();
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('api_base_url_storage_v1');
      await prefs.remove('poof_api_key_storage_v1');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings_ethernet, color: Colors.green),
          SizedBox(width: 8),
          Text('Configurar APIs'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'API REST para CRUD (Persistência):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _restUrlController,
              decoration: const InputDecoration(
                labelText: 'URL Endpoint da API REST',
                hintText: 'https://seu-endpoint.mockapi.io/api/v1/products',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'API Poof (Remoção de Fundo):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _poofKeyController,
              decoration: const InputDecoration(
                labelText: 'Chave de API Poof (x-api-key)',
                hintText: 'Opcional (se vazio, usa fallback transparente)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dica: A API Poof aceita fotos no cadastro e remove o fundo gerando imagens PNG transparentes automaticamente.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _resetDefaults,
          child: const Text('Restaurar Padrão'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
          onPressed: _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
