import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../model/product_model.dart';
import '../services/product_service.dart';
import '../utils/money_input_formatter.dart';
import '../widgets/checkerboard_background.dart';
import 'coupons_screen.dart';

class ProductsScreen extends StatelessWidget {
  ProductsScreen({super.key});

  final _service = ProductService();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Produtos'), backgroundColor: Colors.green, foregroundColor: Colors.white,
          actions: [IconButton(tooltip: 'Gerenciar cupons', icon: const Icon(Icons.local_offer_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CouponsScreen())))]),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen())),
          tooltip: 'Cadastrar produto',
          child: const Icon(Icons.add),
        ),
        body: StreamBuilder<List<ProductModel>>(
          stream: _service.watchProducts(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Erro ao carregar produtos: ${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final products = snapshot.data!;
            if (products.isEmpty) return const Center(child: Text('Nenhum produto cadastrado.'));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final product = products[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ProductImage(product: product, size: 52),
                  title: Text(product.name),
                  subtitle: Text('${product.category} • ${product.unit} • Estoque: ${product.stock}'),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Opções do produto',
                    onSelected: (action) async {
                      if (action == 'edit') {
                        if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)));
                      } else {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Excluir produto?'),
                            content: Text(product.name),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
                              TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Excluir')),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          try {
                            await _service.delete(product);
                          } catch (error) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $error')));
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                );
              },
            );
          },
        ),
      );
}

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.product, required this.size});
  final ProductModel product;
  final double size;

  Widget _buildRawImage() {
    if (product.imageBytes != null) {
      return Image.memory(product.imageBytes!, fit: BoxFit.contain);
    }
    if (product.imageUrl.isNotEmpty) {
      if (product.imageUrl.startsWith('data:image')) {
        try {
          final commaIndex = product.imageUrl.indexOf(',');
          final base64Str = commaIndex != -1 ? product.imageUrl.substring(commaIndex + 1) : product.imageUrl;
          final Uint8List bytes = base64Decode(base64Str);
          return Image.memory(bytes, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));
        } catch (_) {
          return const Icon(Icons.broken_image_outlined);
        }
      }
      return Image.network(product.imageUrl, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));
    }
    return const Icon(Icons.inventory_2_outlined);
  }

  @override
  Widget build(BuildContext context) {
    if (product.hasBgRemoved) {
      return CheckerboardWidget(
        borderRadius: 8,
        child: SizedBox(
          width: size,
          height: size,
          child: _buildRawImage(),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: _buildRawImage(),
      ),
    );
  }
}

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});
  final ProductModel? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
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
    'Beleza e Cuidados',
    'Limpeza',
    'Bebês e Infantil',
    'Pet Shop',
    'Casa e Bazar',
    'Saúde e Farmácia',
    'Outros',
  ];

  final _formKey = GlobalKey<FormState>();
  final _service = ProductService();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _stock = TextEditingController();
  XFile? _image;
  String _unit = 'UN';
  String? _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product != null) {
      _name.text = product.name;
      _price.text = MoneyInputFormatter.format(product.price);
      _category = _categories.contains(product.category) ? product.category : null;
      _cost.text = MoneyInputFormatter.format(product.cost);
      _stock.text = product.stock.toString().replaceAll('.', ',');
      _unit = product.unit;
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _price, _cost, _stock]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String value) => double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_image == null && widget.product == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma imagem do produto.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final id = widget.product?.id ?? _service.newId();
      final imageBytes = _image == null
          ? widget.product?.imageBytes
          : await _service.prepareImage(_image!);
      final product = ProductModel(
        id: id,
        name: _name.text.trim(),
        price: MoneyInputFormatter.parse(_price.text),
        unit: _unit,
        category: _category!,
        cost: MoneyInputFormatter.parse(_cost.text),
        stock: _number(_stock.text)!,
        imageUrl: _image == null ? widget.product?.imageUrl ?? '' : '',
        imageBytes: imageBytes,
      );
      await _service.save(product);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar produto: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _textField(TextEditingController controller, String label, {bool number = false, bool money = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: controller,
          keyboardType: number || money ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: money ? [MoneyInputFormatter()] : number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))] : null,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Campo obrigatório';
            if (number && (_number(value) == null || _number(value)! < 0)) return 'Informe um número válido';
            if (money && MoneyInputFormatter.parse(value) == 0 && label == 'Valor') return 'O valor deve ser maior que zero';
            return null;
          },
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.product == null ? 'Cadastrar produto' : 'Editar produto'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : () async {
                  final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
                  if (image != null) setState(() => _image = image);
                },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_image?.name ?? (widget.product == null ? 'Selecionar imagem' : 'Trocar imagem')),
              ),
              if (widget.product != null && _image == null)
                Center(child: ProductImage(product: widget.product!, size: 130)),
              const SizedBox(height: 12),
              _textField(_name, 'Nome'),
              _textField(_price, 'Valor', money: true),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Unidade', border: OutlineInputBorder()),
                  items: const ['UN', 'KG', 'L', 'G', 'ML', 'PCT']
                      .map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                  onChanged: (value) => setState(() => _unit = value ?? 'UN'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  menuMaxHeight: 320,
                  decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                  items: _categories
                      .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                      .toList(),
                  onChanged: (value) => setState(() => _category = value),
                  validator: (value) => value == null ? 'Selecione uma categoria' : null,
                ),
              ),
              _textField(_cost, 'Custo', money: true),
              _textField(_stock, 'Estoque', number: true),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Salvando...' : 'Salvar produto'),
              ),
            ],
          ),
        ),
      );
}
