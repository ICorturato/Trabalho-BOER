import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../model/coupon_model.dart';
import '../model/product_model.dart';
import 'api_product_service.dart';

class CheckoutService {
  final _db = FirebaseFirestore.instance;

  Future<CouponModel> findCoupon(String code) async {
    final normalized = code.trim().toUpperCase();
    try {
      final doc = await _db.collection('coupons').doc(normalized).get();
      if (!doc.exists || doc.data() == null) throw StateError('Cupom não encontrado.');
      return CouponModel.fromMap(doc.id, doc.data()!);
    } catch (e) {
      if (e is StateError) rethrow;
      throw StateError('Não foi possível verificar o cupom no momento.');
    }
  }

  Future<String> placeOrder({
    required Map<String, double> cart,
    required Map<String, double> expectedPrices,
    required String paymentMethod,
    required String deliveryAddress,
    List<ProductModel>? productsList,
    String? couponCode,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'cliente_${Random().nextInt(99999)}';
    if (cart.isEmpty) throw StateError('O carrinho está vazio.');
    if (deliveryAddress.trim().isEmpty) throw StateError('Informe o endereço de entrega.');
    if (!const ['cash', 'credit_delivery', 'debit_delivery', 'pix_delivery'].contains(paymentMethod)) {
      throw StateError('Selecione uma forma de pagamento.');
    }

    final orderId = 'ORD${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final byId = {for (final p in (productsList ?? [])) p.id: p};
    final lines = <Map<String, dynamic>>[];
    final firestoreUpdates = <DocumentReference, double>{};
    final apiUpdates = <String, double>{};
    double subtotal = 0.0;

    for (final entry in cart.entries) {
      final productId = entry.key;
      final quantity = entry.value;
      if (quantity <= 0) continue;

      if (productId.startsWith('api_')) {
        // Produto vindo da API REST
        final rawId = productId.replaceFirst('api_', '');
        final product = byId[productId];
        if (product == null) {
          throw StateError('Produto da API REST não encontrado no catálogo.');
        }

        if (product.stock < quantity) {
          throw StateError('Estoque insuficiente para ${product.name}.');
        }

        final itemTotal = product.price * quantity;
        subtotal += itemTotal;

        lines.add({
          'productId': productId,
          'name': product.name,
          'unit': product.unit,
          'quantity': quantity,
          'unitPrice': product.price,
          'total': itemTotal,
        });

        apiUpdates[rawId] = product.stock - quantity;
      } else {
        // Produto do Firestore
        try {
          final productDoc = await _db.collection('products').doc(productId).get();
          if (productDoc.exists && productDoc.data() != null) {
            final data = productDoc.data()!;
            final stock = (data['stock'] as num? ?? 0).toDouble();
            final price = (data['price'] as num? ?? 0).toDouble();

            if (stock < quantity) {
              throw StateError('Estoque insuficiente para ${data['name']}.');
            }

            final itemTotal = price * quantity;
            subtotal += itemTotal;

            lines.add({
              'productId': productId,
              'name': data['name'] as String? ?? '',
              'unit': data['unit'] as String? ?? 'UN',
              'quantity': quantity,
              'unitPrice': price,
              'total': itemTotal,
            });

            firestoreUpdates[productDoc.reference] = stock - quantity;
          } else {
            // Fallback usando o objeto em memória
            final product = byId[productId];
            if (product != null) {
              final itemTotal = product.price * quantity;
              subtotal += itemTotal;
              lines.add({
                'productId': productId,
                'name': product.name,
                'unit': product.unit,
                'quantity': quantity,
                'unitPrice': product.price,
                'total': itemTotal,
              });
            }
          }
        } catch (e) {
          if (e is StateError) rethrow;
          debugPrint('Aviso ao consultar produto no Firestore: $e');
        }
      }
    }

    if (lines.isEmpty) {
      throw StateError('Nenhum item válido encontrado no carrinho.');
    }

    double discount = 0.0;
    final code = couponCode?.trim().toUpperCase();
    if (code != null && code.isNotEmpty) {
      try {
        final couponDoc = await _db.collection('coupons').doc(code).get();
        if (couponDoc.exists && couponDoc.data() != null) {
          final coupon = CouponModel.fromMap(code, couponDoc.data()!);
          final error = coupon.validate(subtotal);
          if (error != null) throw StateError(error);
          discount = coupon.discount(subtotal);
        }
      } catch (e) {
        if (e is StateError) rethrow;
      }
    }

    final total = (subtotal - discount) > 0 ? (subtotal - discount) : 0.0;

    // Tenta persistir o pedido e atualizar estoque no Firestore
    try {
      final orderRef = _db.collection('orders').doc(orderId);
      final batch = _db.batch();

      for (final update in firestoreUpdates.entries) {
        batch.update(update.key, {'stock': update.value});
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final cartItems = _db.collection('users').doc(currentUser.uid).collection('cart');
        for (final entry in cart.entries) {
          batch.delete(cartItems.doc(entry.key));
        }
      }

      batch.set(orderRef, {
        'userId': uid,
        'items': lines,
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'couponCode': code ?? '',
        'paymentMethod': paymentMethod,
        'paymentStatus': 'pending_delivery',
        'deliveryAddress': deliveryAddress.trim(),
        'status': 'placed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Aviso: Firestore não disponível para salvar pedido ($e). Pedido confirmado localmente.');
    }

    // Atualiza o estoque na API REST para produtos da API REST
    for (final update in apiUpdates.entries) {
      try {
        final apiProd = await ApiProductService.instance.getProductById(update.key);
        final updated = apiProd.copyWith(stock: update.value);
        await ApiProductService.instance.updateProduct(updated);
      } catch (e) {
        debugPrint('Aviso ao atualizar estoque na API REST: $e');
      }
    }

    return orderId;
  }
}
