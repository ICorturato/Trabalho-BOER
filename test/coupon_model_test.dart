import 'package:flutter_test/flutter_test.dart';

import 'package:app/model/coupon_model.dart';

void main() {
  test('percentage coupon respects the minimum and computes the discount', () {
    const coupon = CouponModel(
      code: 'MERCADO10', type: 'percent', value: 10, minimum: 50, active: true,
    );

    expect(coupon.validate(49.99), isNotNull);
    expect(coupon.validate(100), isNull);
    expect(coupon.discount(100), 10);
  });

  test('fixed coupon never discounts more than the subtotal', () {
    const coupon = CouponModel(
      code: 'DESCONTO20', type: 'fixed', value: 20, minimum: 0, active: true,
    );

    expect(coupon.discount(12), 12);
  });

  test('inactive and expired coupons are rejected', () {
    const inactive = CouponModel(
      code: 'INATIVO', type: 'fixed', value: 5, minimum: 0, active: false,
    );
    final expired = CouponModel(
      code: 'EXPIRADO', type: 'percent', value: 5, minimum: 0, active: true,
      expiresAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    expect(inactive.validate(100), isNotNull);
    expect(expired.validate(100), isNotNull);
  });
}
