import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final double price;
  final String unit;
  final String category;
  final double cost;
  final double stock;
  final String imageUrl;
  final Uint8List? imageBytes;
  final bool isFromApi;
  final bool hasBgRemoved;

  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    required this.category,
    required this.cost,
    required this.stock,
    required this.imageUrl,
    this.imageBytes,
    this.isFromApi = false,
    this.hasBgRemoved = false,
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> data) => ProductModel(
        id: id,
        name: data['name'] as String? ?? '',
        price: (data['price'] as num? ?? 0).toDouble(),
        unit: data['unit'] as String? ?? 'UN',
        category: data['category'] as String? ?? '',
        cost: (data['cost'] as num? ?? 0).toDouble(),
        stock: (data['stock'] as num? ?? 0).toDouble(),
        imageUrl: data['imageUrl'] as String? ?? '',
        imageBytes: (data['imageBytes'] as Blob?)?.bytes,
        isFromApi: false,
        hasBgRemoved: false,
      );

  factory ProductModel.fromApi(dynamic api) => ProductModel(
        id: 'api_${api.id}',
        name: api.name as String,
        price: (api.price as num).toDouble(),
        unit: api.unit as String,
        category: api.category as String,
        cost: (api.cost as num).toDouble(),
        stock: (api.stock as num).toDouble(),
        imageUrl: api.imageUrl as String,
        imageBytes: null,
        isFromApi: true,
        hasBgRemoved: api.hasBgRemoved as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'unit': unit,
        'category': category,
        'cost': cost,
        'stock': stock,
        'imageUrl': imageUrl,
        'imageBytes': imageBytes == null ? null : Blob(imageBytes!),
      };
}
