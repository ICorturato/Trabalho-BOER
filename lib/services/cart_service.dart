import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CartService {
  final Map<String, double> _localCart = {};
  final _localCartController = StreamController<Map<String, double>>.broadcast();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _items {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('cart');
  }

  Stream<Map<String, double>> watchCart() {
    final items = _items;
    if (items == null) {
      return Stream<Map<String, double>>.value(Map<String, double>.unmodifiable(_localCart))
          .concatWith([_localCartController.stream]);
    }
    return items.snapshots().map(
      (snapshot) {
        final map = <String, double>{};
        for (final doc in snapshot.docs) {
          map[doc.id] = (doc.data()['quantity'] as num? ?? 0).toDouble();
        }
        return map;
      },
    ).handleError((e) {
      debugPrint('Aviso no stream do carrinho Firestore: $e. Usando cache local.');
      return Map.unmodifiable(_localCart);
    });
  }

  Future<void> changeQuantity(String productId, double delta) async {
    final currentLocal = _localCart[productId] ?? 0;
    final newLocal = currentLocal + delta;
    if (newLocal <= 0) {
      _localCart.remove(productId);
    } else {
      _localCart[productId] = newLocal;
    }
    _localCartController.add(Map.unmodifiable(_localCart));

    final items = _items;
    if (items != null) {
      try {
        final reference = items.doc(productId);
        final doc = await reference.get();
        final currentQty = (doc.data()?['quantity'] as num? ?? 0).toDouble();
        final updatedQty = currentQty + delta;
        if (updatedQty <= 0) {
          await reference.delete();
        } else {
          await reference.set({'quantity': updatedQty});
        }
      } catch (e) {
        debugPrint('Aviso ao sincronizar carrinho com Firestore: $e');
      }
    }
  }

  Future<void> remove(String productId) async {
    _localCart.remove(productId);
    _localCartController.add(Map.unmodifiable(_localCart));

    final items = _items;
    if (items != null) {
      try {
        await items.doc(productId).delete();
      } catch (e) {
        debugPrint('Aviso ao remover do carrinho no Firestore: $e');
      }
    }
  }

  Future<void> clear() async {
    _localCart.clear();
    _localCartController.add(Map.unmodifiable(_localCart));

    final items = _items;
    if (items != null) {
      try {
        final snapshot = await items.get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } catch (e) {
        debugPrint('Aviso ao limpar carrinho no Firestore: $e');
      }
    }
  }
}

extension _StreamConcat<T> on Stream<T> {
  Stream<T> concatWith(Iterable<Stream<T>> others) async* {
    yield* this;
    for (final s in others) {
      yield* s;
    }
  }
}
