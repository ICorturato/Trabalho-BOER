import 'package:flutter_test/flutter_test.dart';
import 'package:app/model/api_product_model.dart';
import 'package:app/services/api_product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ApiProductModel', () {
    test('serializes and deserializes from JSON correctly', () {
      final json = {
        'id': '101',
        'name': 'Café Premium 500g',
        'category': 'Mercearia',
        'price': 18.50,
        'cost': 11.20,
        'stock': 40.0,
        'unit': 'PCT',
        'description': 'Café torrado e moído especial.',
        'imageUrl': 'https://example.com/cafe.png',
        'hasBgRemoved': true,
      };

      final product = ApiProductModel.fromJson(json);

      expect(product.id, '101');
      expect(product.name, 'Café Premium 500g');
      expect(product.category, 'Mercearia');
      expect(product.price, 18.50);
      expect(product.cost, 11.20);
      expect(product.stock, 40.0);
      expect(product.unit, 'PCT');
      expect(product.hasBgRemoved, true);

      final exported = product.toJson();
      expect(exported['name'], 'Café Premium 500g');
      expect(exported['hasBgRemoved'], true);
    });

    test('copyWith updates properties properly', () {
      const original = ApiProductModel(
        id: '1',
        name: 'Suco de Laranja',
        category: 'Bebidas',
        price: 9.90,
        cost: 5.0,
        stock: 20.0,
        unit: 'L',
        description: 'Suco natural',
        imageUrl: '',
      );

      final updated = original.copyWith(
        price: 11.50,
        hasBgRemoved: true,
      );

      expect(updated.id, '1');
      expect(updated.name, 'Suco de Laranja');
      expect(updated.price, 11.50);
      expect(updated.hasBgRemoved, true);
    });
  });

  group('ApiProductService CRUD operations', () {
    final service = ApiProductService.instance;

    test('getProducts returns list of products', () async {
      final list = await service.getProducts();
      expect(list, isNotEmpty);
    });

    test('create, get, update and delete product cycle', () async {
      // 1. CREATE (POST)
      const newProduct = ApiProductModel(
        id: '',
        name: 'Biscoito Recheado Teste',
        category: 'Biscoitos e Snacks',
        price: 4.50,
        cost: 2.50,
        stock: 50.0,
        unit: 'PCT',
        description: 'Biscoito de chocolate',
        imageUrl: '',
      );

      final created = await service.createProduct(newProduct);
      expect(created.id, isNotEmpty);
      expect(created.name, 'Biscoito Recheado Teste');

      // 2. READ by ID (GET)
      final fetched = await service.getProductById(created.id);
      expect(fetched.name, 'Biscoito Recheado Teste');

      // 3. UPDATE (PUT)
      final toUpdate = created.copyWith(price: 5.20, name: 'Biscoito Recheado Especial');
      final updated = await service.updateProduct(toUpdate);
      expect(updated.price, 5.20);
      expect(updated.name, 'Biscoito Recheado Especial');

      // 4. DELETE (DELETE)
      await service.deleteProduct(created.id);
      final listAfterDelete = await service.getProducts();
      expect(listAfterDelete.any((p) => p.id == created.id), isFalse);
    });
  });
}
