import 'dart:async';
import 'package:flutter/material.dart';

import '../model/product_model.dart';
import '../services/api_product_service.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import 'checkout_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'profile_screen.dart';
import 'api_products_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final products = ProductService();
  final cart = CartService();
  final search = TextEditingController();
  final apiService = ApiProductService.instance;

  late final Stream<List<ProductModel>> productStream = products.watchProducts();
  late final Stream<Map<String, double>> cartStream = cart.watchCart();
  List<ProductModel> _apiProducts = [];
  StreamSubscription? _apiSub;
  int page = 0;

  @override
  void initState() {
    super.initState();
    _loadApiProducts();
    _apiSub = apiService.productsStream.listen((list) {
      if (mounted) {
        setState(() {
          _apiProducts = list.map((item) => ProductModel.fromApi(item)).toList();
        });
      }
    });
  }

  Future<void> _loadApiProducts() async {
    try {
      final list = await apiService.getProducts();
      if (mounted) {
        setState(() {
          _apiProducts = list.map((item) => ProductModel.fromApi(item)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _openRestCrud() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ApiProductsScreen()));
    _loadApiProducts();
  }

  @override
  void dispose() {
    _apiSub?.cancel();
    search.dispose();
    super.dispose();
  }

  String money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> change(ProductModel product, double delta, double current) async {
    if (delta > 0 && current + delta > product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estoque insuficiente.')));
      return;
    }
    try {
      await cart.changeQuantity(product.id, delta);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro no carrinho: $error')));
    }
  }

  Widget catalog(List<ProductModel> items, Map<String, double> quantities) {
    final allItems = [...items, ..._apiProducts];
    final query = search.text.trim().toLowerCase();
    final visible = allItems.where((p) => query.isEmpty || p.name.toLowerCase().contains(query) || p.category.toLowerCase().contains(query)).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        elevation: 0,
        color: Colors.green.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.green.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.cloud_sync_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CRUD API REST + Poof BG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Gerencie produtos via REST e remova fundo com IA!', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
                onPressed: _openRestCrud,
                child: const Text('Abrir', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(controller: search, onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'Buscar produtos ou categorias', prefixIcon: Icon(Icons.search), border: OutlineInputBorder())),
      const SizedBox(height: 20),
      Row(
        children: [
          Text('Produtos', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          if (_apiProducts.isNotEmpty)
            Text('${_apiProducts.length} via API REST', style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
        ],
      ),
      const SizedBox(height: 12),
      if (visible.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Nenhum produto encontrado.'))),
      ...visible.map((p) => Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          ProductImage(product: p, size: 76),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${p.category} • ${p.unit}', style: TextStyle(color: Colors.grey.shade700)),
            Text(money(p.price), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            if (p.isFromApi)
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(p.hasBgRemoved ? Icons.auto_awesome : Icons.cloud_outlined, size: 11, color: Colors.green),
                    const SizedBox(width: 3),
                    Text(p.hasBgRemoved ? 'API REST • Poof BG' : 'API REST',
                        style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            if (p.stock <= 0) const Text('Sem estoque', style: TextStyle(color: Colors.red)),
          ])),
          IconButton.filled(tooltip: 'Adicionar ao carrinho', icon: const Icon(Icons.add_shopping_cart),
            onPressed: p.stock <= 0 ? null : () => change(p, 1, quantities[p.id] ?? 0)),
        ]),
      ))),
    ]);
  }

  Widget cartPage(List<ProductModel> items, Map<String, double> quantities) {
    final byId = {for (final p in items) p.id: p};
    final entries = quantities.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) {
      return const Center(child: Text('Seu carrinho está vazio.'));
    }
    final total = entries.fold<double>(0, (sum, e) => sum + (byId[e.key]?.price ?? 0) * e.value);
    return Column(children: [
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: entries.length, itemBuilder: (context, index) {
        final entry = entries[index];
        final p = byId[entry.key];
        if (p == null) {
          return ListTile(title: const Text('Produto indisponível'),
            trailing: IconButton(tooltip: 'Remover', icon: const Icon(Icons.delete_outline), onPressed: () => cart.remove(entry.key)));
        }
        return Card(child: Column(children: [
          ListTile(
            leading: ProductImage(product: p, size: 48),
            title: Text(p.name), subtitle: Text('${money(p.price)} / ${p.unit}'),
            trailing: IconButton(tooltip: 'Remover', icon: const Icon(Icons.delete_outline), onPressed: () => cart.remove(p.id)),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton(tooltip: 'Diminuir', icon: const Icon(Icons.remove), onPressed: () => change(p, -1, entry.value)),
            Text(entry.value.toStringAsFixed(0)),
            IconButton(tooltip: 'Aumentar', icon: const Icon(Icons.add), onPressed: () => change(p, 1, entry.value)),
            const SizedBox(width: 12), Text(money(p.price * entry.value), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
          ]),
        ]));
      })),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text('Total: ${money(total)}', style: Theme.of(context).textTheme.titleLarge)),
          TextButton(onPressed: () async {
          final confirm = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
            title: const Text('Esvaziar carrinho?'), actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
              TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Esvaziar')),
            ]));
          if (confirm == true) await cart.clear();
          }, child: const Text('Esvaziar')),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton(
          onPressed: entries.any((e) => !byId.containsKey(e.key)) ? null : () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => CheckoutScreen(products: items, quantities: Map.of(quantities)))),
          child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Continuar para pagamento')),
        )),
      ]))),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.grey.shade100,
    appBar: AppBar(backgroundColor: Colors.green, foregroundColor: Colors.white,
      title: Text(['Meu Mercado', 'Buscar', 'Carrinho', 'Perfil'][page]),
      actions: [
        IconButton(tooltip: 'CRUD REST & Poof BG', icon: const Icon(Icons.cloud_sync_outlined),
          onPressed: _openRestCrud),
        IconButton(tooltip: 'Meus pedidos', icon: const Icon(Icons.receipt_long_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()))),
        IconButton(tooltip: 'Gerenciar produtos', icon: const Icon(Icons.inventory_2_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen()))),
        IconButton(tooltip: 'Carrinho', icon: const Icon(Icons.shopping_cart_outlined), onPressed: () => setState(() => page = 2)),
      ]),
    body: page == 3 ? const ProfileScreen() : StreamBuilder<List<ProductModel>>(
      stream: productStream, builder: (context, productSnapshot) {
        if (productSnapshot.hasError) return Center(child: Text('Erro ao carregar produtos: ${productSnapshot.error}'));
        if (!productSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        return StreamBuilder<Map<String, double>>(stream: cartStream, builder: (context, cartSnapshot) {
          if (cartSnapshot.hasError) return Center(child: Text('Erro ao carregar carrinho: ${cartSnapshot.error}'));
          if (!cartSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final allItems = [...productSnapshot.data!, ..._apiProducts];
          return page == 2 ? cartPage(allItems, cartSnapshot.data!) : catalog(productSnapshot.data!, cartSnapshot.data!);
        });
      }),
    bottomNavigationBar: NavigationBar(selectedIndex: page, onDestinationSelected: (index) => setState(() => page = index),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
        NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
        NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Carrinho'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
      ]),
  );
}
