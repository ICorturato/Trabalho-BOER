import 'package:cloud_firestore/cloud_firestore.dart';

class CouponModel {
  const CouponModel({
    required this.code,
    required this.type,
    required this.value,
    required this.minimum,
    required this.active,
    this.expiresAt,
  });

  final String code;
  final String type;
  final double value;
  final double minimum;
  final bool active;
  final DateTime? expiresAt;

  factory CouponModel.fromMap(String code, Map<String, dynamic> data) => CouponModel(
        code: code,
        type: data['type'] as String? ?? 'fixed',
        value: (data['value'] as num? ?? 0).toDouble(),
        minimum: (data['minimum'] as num? ?? 0).toDouble(),
        active: data['active'] as bool? ?? false,
        expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'type': type,
        'value': value,
        'minimum': minimum,
        'active': active,
        'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
      };

  String? validate(double subtotal) {
    if (!active) return 'Cupom indisponível.';
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return 'Cupom expirado.';
    if (subtotal < minimum) return 'Pedido mínimo de R\$ ${minimum.toStringAsFixed(2).replaceAll('.', ',')}.';
    if (value <= 0 || (type == 'percent' && value > 100)) return 'Cupom inválido.';
    return null;
  }

  double discount(double subtotal) {
    final raw = type == 'percent' ? subtotal * value / 100 : value;
    return raw.clamp(0, subtotal).toDouble();
  }
}
