import 'package:flutter/material.dart';

import '../model/api_product_model.dart';
import '../services/api_product_service.dart';
import '../utils/money_input_formatter.dart';
import '../widgets/checkerboard_background.dart';
import 'api_config_dialog.dart';
import 'api_product_form_screen.dart';

class ApiProductsScreen extends StatefulWidget {
  const ApiProductsScreen({super.key});

  @override
  State<ApiProductsScreen> createState() => _ApiProductsScreenState();
}

class _ApiProductsScreenState extends State<ApiProductsScreen> {
  final _apiService = ApiProductService.instance;
  final _searchController = TextEditingController();

  List<ApiProductModel> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'Todas';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _apiService.getProducts();
      if (mounted) {
        setState(() {
          _products = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteProduct(ApiProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Excluir Produto?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tem certeza que deseja remover o produto "${product.name}"?'),
            const SizedBox(height: 8),
            const Text(
              'Esta ação realizará uma requisição HTTP DELETE na API REST.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Excluir (DELETE)'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _apiService.deleteProduct(product.id);
        if (mounted) {
          _loadProducts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showProductDetails(ApiProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Center(
              child: ApiProductImage(
                imageUrl: product.imageUrl,
                size: 140,
                showCheckerboard: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                if (product.hasBgRemoved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.amber, size: 14),
                        SizedBox(width: 4),
                        Text('Poof BG', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${product.category} • ${product.unit}', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metricItem('Preço Venda', MoneyInputFormatter.format(product.price), Colors.green),
                  _metricItem('Custo', MoneyInputFormatter.format(product.cost), Colors.blueGrey),
                  _metricItem('Estoque', '${product.stock.toStringAsFixed(product.stock % 1 == 0 ? 0 : 2)} ${product.unit}', Colors.indigo),
                ],
              ),
            ),
            if (product.description.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Descrição:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(product.description, style: TextStyle(color: Colors.grey.shade800)),
            ],
            const SizedBox(height: 10),
            Text('ID no REST: ${product.id}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteProduct(product);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Excluir', style: TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => ApiProductFormScreen(product: product)),
                      );
                      if (updated == true) _loadProducts();
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar (PUT)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final categories = ['Todas', ...{for (final p in _products) p.category}];

    final filtered = _products.where((p) {
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query);
      final matchesCategory = _selectedCategory == 'Todas' || p.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Catálogo REST & Poof BG'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Configurar Endpoints e Chaves',
            icon: const Icon(Icons.tune),
            onPressed: () => ApiConfigDialog.show(context),
          ),
          IconButton(
            tooltip: 'Atualizar (GET)',
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const ApiProductFormScreen()),
          );
          if (created == true) _loadProducts();
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Produto (POST)'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: Column(
          children: [
            // Banner explicativo do CRUD REST + Poof
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  const Icon(Icons.cloud_done_outlined, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CRUD REST (GET, POST, PUT, DELETE) integrado com API Poof de remoção de fundo.',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                    ),
                  ),
                ],
              ),
            ),
            // Barra de busca
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar por nome, categoria ou detalhe...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            // Filtro por categorias (Chips)
            if (categories.length > 1)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  itemBuilder: (ctx, idx) {
                    final cat = categories[idx];
                    final isSelected = cat == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                        selected: isSelected,
                        selectedColor: Colors.green,
                        backgroundColor: Colors.white,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedCategory = cat);
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            // Conteúdo principal (Listagem / Read)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.green))
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _loadProducts,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? 'Nenhum produto encontrado para o filtro.'
                                        : 'Nenhum produto cadastrado na API REST.',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                    onPressed: () async {
                                      final created = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(builder: (_) => const ApiProductFormScreen()),
                                      );
                                      if (created == true) _loadProducts();
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Cadastrar Primeiro Produto'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final product = filtered[index];
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _showProductDetails(product),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Stack(
                                            alignment: Alignment.bottomRight,
                                            children: [
                                              ApiProductImage(
                                                imageUrl: product.imageUrl,
                                                size: 64,
                                                showCheckerboard: true,
                                              ),
                                              if (product.hasBgRemoved)
                                                Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.amber,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${product.category} • ${product.unit}',
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Text(
                                                      MoneyInputFormatter.format(product.price),
                                                      style: const TextStyle(
                                                        color: Colors.green,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Estoque: ${product.stock.toStringAsFixed(product.stock % 1 == 0 ? 0 : 2)}',
                                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            tooltip: 'Opções do Produto',
                                            onSelected: (action) async {
                                              if (action == 'view') {
                                                _showProductDetails(product);
                                              } else if (action == 'edit') {
                                                final updated = await Navigator.push<bool>(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => ApiProductFormScreen(product: product),
                                                  ),
                                                );
                                                if (updated == true) _loadProducts();
                                              } else if (action == 'delete') {
                                                _deleteProduct(product);
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'view',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.visibility_outlined, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Consultar (GET)'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Editar (PUT)'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Excluir (DELETE)', style: TextStyle(color: Colors.red)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
