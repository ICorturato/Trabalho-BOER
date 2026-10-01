import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../model/api_product_model.dart';
import '../services/api_product_service.dart';
import '../services/poof_bg_service.dart';
import '../utils/money_input_formatter.dart';
import '../widgets/checkerboard_background.dart';

class ApiProductFormScreen extends StatefulWidget {
  const ApiProductFormScreen({super.key, this.product});

  final ApiProductModel? product;

  @override
  State<ApiProductFormScreen> createState() => _ApiProductFormScreenState();
}

class _ApiProductFormScreenState extends State<ApiProductFormScreen> {
  static const _categories = [
    'Alimentos',
    'Hortifruti',
    'Carnes e Aves',
    'Peixes e Frutos do Mar',
    'Frios e Laticínios',
    'Padaria',
    'Mercearia',
    'Grãos e Cereais',
    'Massas e Molhos',
    'Enlatados e Conservas',
    'Congelados',
    'Bebidas',
    'Doces e Sobremesas',
    'Biscoitos e Snacks',
    'Temperos e Condimentos',
    'Óleos e Azeites',
    'Higiene Pessoal',
    'Limpeza',
    'Outros',
  ];

  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiProductService.instance;
  final _poofService = PoofBgService.instance;

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _unit = 'UN';
  String? _category;
  String _imageUrl = '';
  Uint8List? _localImageBytes;
  bool _hasBgRemoved = false;
  bool _isRemovingBg = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameController.text = p.name;
      _priceController.text = MoneyInputFormatter.format(p.price);
      _costController.text = MoneyInputFormatter.format(p.cost);
      _stockController.text = p.stock.toString().replaceAll('.', ',');
      _descriptionController.text = p.description;
      _unit = p.unit;
      _category = _categories.contains(p.category) ? p.category : _categories.first;
      _imageUrl = p.imageUrl;
      _hasBgRemoved = p.hasBgRemoved;
    } else {
      _category = _categories.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  double? _parseNumber(String value) => double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1000, maxHeight: 1000, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _localImageBytes = bytes;
          _imageUrl = _poofService.bytesToDataUri(bytes);
          _hasBgRemoved = false;
        });

        // Sugere a remoção de fundo com a API Poof
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Foto carregada! Toque em "Remover Fundo (API Poof)" para tratá-la.'),
              action: SnackBarAction(
                label: 'Remover Fundo',
                textColor: Colors.amber,
                onPressed: _removeBackgroundWithPoof,
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeBackgroundWithPoof() async {
    if (_localImageBytes == null && _imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma imagem primeiro.')),
      );
      return;
    }

    setState(() => _isRemovingBg = true);

    try {
      Uint8List bytesToProcess;
      if (_localImageBytes != null) {
        bytesToProcess = _localImageBytes!;
      } else if (_imageUrl.startsWith('data:image')) {
        final commaIndex = _imageUrl.indexOf(',');
        final base64Str = commaIndex != -1 ? _imageUrl.substring(commaIndex + 1) : _imageUrl;
        bytesToProcess = base64Decode(base64Str);
      } else {
        // Se for URL externa, faz download rápido
        final response = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (response != null) {
          bytesToProcess = await response.readAsBytes();
        } else {
          throw Exception('Selecione um arquivo de imagem para remover o fundo.');
        }
      }

      final processedBytes = await _poofService.removeBackground(imageBytes: bytesToProcess);

      if (mounted) {
        setState(() {
          _localImageBytes = processedBytes;
          _imageUrl = _poofService.bytesToDataUri(processedBytes);
          _hasBgRemoved = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber),
                SizedBox(width: 8),
                Text('Fundo removido com sucesso via API Poof!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na remoção de fundo: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRemovingBg = false);
    }
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final isEditing = widget.product != null;
      final productData = ApiProductModel(
        id: widget.product?.id ?? '',
        name: _nameController.text.trim(),
        category: _category ?? 'Geral',
        price: MoneyInputFormatter.parse(_priceController.text),
        cost: MoneyInputFormatter.parse(_costController.text),
        stock: _parseNumber(_stockController.text) ?? 0.0,
        unit: _unit,
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrl.isNotEmpty
            ? _imageUrl
            : 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=300',
        hasBgRemoved: _hasBgRemoved,
      );

      if (isEditing) {
        // HTTP PUT
        await _apiService.updateProduct(productData);
      } else {
        // HTTP POST
        await _apiService.createProduct(productData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Produto atualizado com sucesso na API REST (PUT)!'
                : 'Produto cadastrado com sucesso na API REST (POST)!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar produto: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ApiProductImage(
                      imageUrl: _imageUrl,
                      size: 130,
                      showCheckerboard: true,
                    ),
                  ),
                  if (_hasBgRemoved)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_hasBgRemoved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text('Fundo Removido (API Poof)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving || _isRemovingBg
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galeria'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving || _isRemovingBg
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Câmera'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              onPressed: _isSaving || _isRemovingBg || (_localImageBytes == null && _imageUrl.isEmpty)
                  ? null
                  : _removeBackgroundWithPoof,
              icon: _isRemovingBg
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high, size: 18),
              label: Text(_isRemovingBg ? 'Removendo Fundo (API Poof)...' : 'Remover Fundo com API Poof'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Produto (REST PUT)' : 'Novo Produto (REST POST)'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildImageSection(),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Informações do Produto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Produto *',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome do produto' : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Categoria *',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _category = v),
                      validator: (v) => v == null ? 'Selecione uma categoria' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [MoneyInputFormatter()],
                            decoration: const InputDecoration(
                              labelText: 'Preço Venda (R\$) *',
                              prefixIcon: Icon(Icons.attach_money),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Informe o preço';
                              if (MoneyInputFormatter.parse(v) <= 0) return 'Preço inválido';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            initialValue: _unit,
                            decoration: const InputDecoration(
                              labelText: 'Unidade *',
                              border: OutlineInputBorder(),
                            ),
                            items: const ['UN', 'KG', 'L', 'G', 'ML', 'PCT']
                                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (v) => setState(() => _unit = v ?? 'UN'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _costController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [MoneyInputFormatter()],
                            decoration: const InputDecoration(
                              labelText: 'Custo (R\$) *',
                              prefixIcon: Icon(Icons.money_off_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Informe o custo' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                            decoration: const InputDecoration(
                              labelText: 'Estoque *',
                              prefixIcon: Icon(Icons.layers_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Informe o estoque';
                              if (_parseNumber(v) == null) return 'Número inválido';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descrição / Detalhes',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.description_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _isSaving ? null : _saveProduct,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving
                      ? 'Salvando na API REST...'
                      : (isEditing ? 'Atualizar Produto (PUT)' : 'Cadastrar Produto (POST)'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
