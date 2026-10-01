import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../model/product_model.dart';

class ProductService {
  final _products = FirebaseFirestore.instance.collection('products');

  Stream<List<ProductModel>> watchProducts() => _products
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.id, doc.data()))
          .toList());

  String newId() => _products.doc().id;

  Future<Uint8List> prepareImage(XFile file) async {
    final source = img.decodeImage(await file.readAsBytes());
    if (source == null) throw const FormatException('Formato de imagem não suportado. Use JPG ou PNG.');
    final longestSide = source.width > source.height ? source.width : source.height;
    final resized = longestSide > 800
        ? img.copyResize(
            source,
            width: source.width >= source.height ? 800 : null,
            height: source.height > source.width ? 800 : null,
          )
        : source;
    final bytes = img.encodeJpg(resized, quality: 65);
    if (bytes.length > 700000) {
      throw const FormatException('A foto é grande demais. Escolha outra imagem.');
    }
    return bytes;
  }

  Future<void> save(ProductModel product) =>
      _products.doc(product.id).set(product.toMap()).timeout(const Duration(seconds: 20));

  Future<void> delete(ProductModel product) =>
      _products.doc(product.id).delete().timeout(const Duration(seconds: 20));
}
