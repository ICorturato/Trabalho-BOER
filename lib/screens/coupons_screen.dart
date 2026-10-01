import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/coupon_model.dart';
import '../utils/money_input_formatter.dart';

class CouponsScreen extends StatelessWidget {
  CouponsScreen({super.key});

  final _coupons = FirebaseFirestore.instance.collection('coupons');

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Cupons'), backgroundColor: Colors.green, foregroundColor: Colors.white),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Criar cupom',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CouponFormScreen())),
          child: const Icon(Icons.add),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _coupons.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Erro ao carregar cupons: ${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final coupons = snapshot.data!.docs
                .map((doc) => CouponModel.fromMap(doc.id, doc.data())).toList()
              ..sort((a, b) => a.code.compareTo(b.code));
            if (coupons.isEmpty) return const Center(child: Text('Nenhum cupom cadastrado.'));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: coupons.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final coupon = coupons[index];
                final value = coupon.type == 'percent'
                    ? '${coupon.value.toString().replaceFirst(RegExp(r'\.0$'), '')}%'
                    : MoneyInputFormatter.format(coupon.value);
                return ListTile(
                  leading: Icon(Icons.local_offer_outlined, color: coupon.active ? Colors.green : Colors.grey),
                  title: Text(coupon.code),
                  subtitle: Text('$value de desconto • mínimo ${MoneyInputFormatter.format(coupon.minimum)}'),
                  trailing: Switch(
                    value: coupon.active,
                    onChanged: (active) async {
                      try {
                        await _coupons.doc(coupon.code).update({'active': active});
                      } catch (error) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao alterar cupom: $error')));
                      }
                    },
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CouponFormScreen(coupon: coupon))),
                );
              },
            );
          },
        ),
      );
}

class CouponFormScreen extends StatefulWidget {
  const CouponFormScreen({super.key, this.coupon});
  final CouponModel? coupon;

  @override
  State<CouponFormScreen> createState() => _CouponFormScreenState();
}

class _CouponFormScreenState extends State<CouponFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _minimum = TextEditingController();
  String _type = 'percent';
  bool _active = true;
  bool _saving = false;
  DateTime? _expiry;

  @override
  void initState() {
    super.initState();
    final coupon = widget.coupon;
    if (coupon != null) {
      _code.text = coupon.code;
      _type = coupon.type;
      _value.text = coupon.type == 'percent'
          ? coupon.value.toString().replaceFirst(RegExp(r'\.0$'), '')
          : MoneyInputFormatter.format(coupon.value);
      _minimum.text = MoneyInputFormatter.format(coupon.minimum);
      _active = coupon.active;
      _expiry = coupon.expiresAt;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _minimum.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final code = _code.text.trim().toUpperCase();
      final ref = FirebaseFirestore.instance.collection('coupons').doc(code);
      if (widget.coupon == null && (await ref.get()).exists) {
        throw StateError('Já existe um cupom com este código.');
      }
      await ref.set(CouponModel(
        code: code,
        type: _type,
        value: _type == 'percent' ? double.parse(_value.text.replaceAll(',', '.')) : MoneyInputFormatter.parse(_value.text),
        minimum: MoneyInputFormatter.parse(_minimum.text),
        active: _active,
        expiresAt: _expiry,
      ).toMap());
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar cupom: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.coupon == null ? 'Criar cupom' : 'Editar cupom'),
          backgroundColor: Colors.green, foregroundColor: Colors.white),
        body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
            controller: _code,
            enabled: widget.coupon == null,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]'))],
            decoration: const InputDecoration(labelText: 'Código', border: OutlineInputBorder()),
            validator: (value) => value == null || value.trim().length < 3 ? 'Use pelo menos 3 caracteres' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipo de desconto', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'percent', child: Text('Porcentagem')),
              DropdownMenuItem(value: 'fixed', child: Text('Valor fixo')),
            ],
            onChanged: (value) {
              setState(() {
                _type = value ?? 'percent';
                _value.clear();
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _type == 'fixed'
                ? [MoneyInputFormatter()]
                : [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
            decoration: InputDecoration(labelText: _type == 'percent' ? 'Desconto (%)' : 'Desconto (R\$)', border: const OutlineInputBorder()),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Informe o desconto';
              final number = _type == 'fixed' ? MoneyInputFormatter.parse(value) : double.tryParse(value.replaceAll(',', '.'));
              if (number == null || number <= 0 || (_type == 'percent' && number > 100)) return 'Informe um desconto válido';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _minimum,
            keyboardType: TextInputType.number,
            inputFormatters: [MoneyInputFormatter()],
            decoration: const InputDecoration(labelText: 'Pedido mínimo', border: OutlineInputBorder()),
            validator: (value) => value == null || value.isEmpty ? 'Informe o pedido mínimo' : null,
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Validade'),
            subtitle: Text(_expiry == null ? 'Sem data de expiração' : '${_expiry!.day}/${_expiry!.month}/${_expiry!.year}'),
            trailing: IconButton(tooltip: 'Escolher data', icon: const Icon(Icons.calendar_today_outlined), onPressed: () async {
              final date = await showDatePicker(context: context, initialDate: _expiry ?? DateTime.now(),
                firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
              if (date != null) setState(() => _expiry = DateTime(date.year, date.month, date.day, 23, 59, 59));
            }),
          ),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Cupom ativo'),
            value: _active, onChanged: (value) => setState(() => _active = value)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Salvando...' : 'Salvar cupom')),
        ])),
      );
}
