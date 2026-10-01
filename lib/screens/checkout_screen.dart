import 'package:flutter/material.dart';

import '../model/coupon_model.dart';
import '../model/product_model.dart';
import '../services/checkout_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.products, required this.quantities});

  final List<ProductModel> products;
  final Map<String, double> quantities;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _service = CheckoutService();
  final _couponController = TextEditingController();
  final _addressController = TextEditingController();
  CouponModel? _coupon;
  String _payment = 'pix_delivery';
  bool _checking = false;
  bool _placing = false;

  static const _methods = [
    ('pix_delivery', 'Pix na entrega', Icons.pix),
    ('credit_delivery', 'Crédito na entrega', Icons.credit_card),
    ('debit_delivery', 'Débito na entrega', Icons.payment),
    ('cash', 'Dinheiro na entrega', Icons.payments_outlined),
  ];

  @override
  void dispose() {
    _couponController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  double get subtotal {
    final byId = {for (final p in widget.products) p.id: p};
    return widget.quantities.entries.fold<double>(0, (sum, entry) =>
        sum + (byId[entry.key]?.price ?? 0) * entry.value);
  }

  double get discount => _coupon?.discount(subtotal) ?? 0;

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    setState(() => _checking = true);
    try {
      final coupon = await _service.findCoupon(code);
      final error = coupon.validate(subtotal);
      if (error != null) throw StateError(error);
      if (mounted) setState(() => _coupon = coupon);
    } catch (error) {
      if (mounted) {
        setState(() => _coupon = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _placeOrder() async {
    if (_placing) return;
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o endereço de entrega.')));
      return;
    }
    setState(() => _placing = true);
    try {
      final id = await _service.placeOrder(
        cart: widget.quantities,
        expectedPrices: {for (final product in widget.products) product.id: product.price},
        paymentMethod: _payment,
        deliveryAddress: _addressController.text,
        productsList: widget.products,
        couponCode: _coupon?.code,
      );
      if (!mounted) return;
      await showDialog<void>(context: context, barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pedido realizado'),
          content: Text('Pedido #${id.substring(0, 8).toUpperCase()} registrado. O pagamento será feito na entrega.'),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Concluir'))],
        ));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível finalizar: $error')));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Widget _line(String label, String value, {bool emphasized = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: emphasized ? const TextStyle(fontWeight: FontWeight.bold) : null)),
          Text(value, style: TextStyle(fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
            color: emphasized ? Colors.green.shade800 : null)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Finalizar pedido'), backgroundColor: Colors.green, foregroundColor: Colors.white),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Entrega', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          TextField(
            controller: _addressController,
            maxLines: 2,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Endereço completo',
              hintText: 'Rua, número, bairro, cidade e CEP',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Cupom de desconto', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(
              controller: _couponController,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) { if (_coupon != null) setState(() => _coupon = null); },
              decoration: const InputDecoration(labelText: 'Código do cupom', prefixIcon: Icon(Icons.local_offer_outlined), border: OutlineInputBorder()),
            )),
            const SizedBox(width: 8),
            FilledButton(onPressed: _checking ? null : _applyCoupon, child: Text(_checking ? '...' : 'Aplicar')),
          ]),
          if (_coupon != null) Padding(padding: const EdgeInsets.only(top: 8),
            child: Text('${_coupon!.code} aplicado', style: const TextStyle(color: Colors.green))),
          const SizedBox(height: 24),
          Text('Pagamento na entrega', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._methods.map((method) => ListTile(
            onTap: () => setState(() => _payment = method.$1),
            title: Text(method.$2),
            leading: Icon(method.$3),
            trailing: Icon(_payment == method.$1 ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: _payment == method.$1 ? Colors.green : Colors.grey),
            contentPadding: EdgeInsets.zero,
          )),
          const SizedBox(height: 16),
          Text('Resumo', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _line('Produtos', money(subtotal)),
          _line('Desconto', '- ${money(discount)}'),
          const Divider(),
          _line('Total', money(subtotal - discount), emphasized: true),
          const SizedBox(height: 16),
          const Text('O pagamento será combinado na entrega. Nenhuma cobrança é feita no aplicativo.',
            style: TextStyle(color: Colors.black54)),
        ]),
        bottomNavigationBar: SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _placing ? null : _placeOrder,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_placing ? 'Finalizando...' : 'Confirmar pedido • ${money(subtotal - discount)}')),
          ),
        )),
      );
}
