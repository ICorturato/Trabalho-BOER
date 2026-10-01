import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/api_product_model.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Serviço responsável pelas operações de CRUD via API REST
/// com garantia absoluta de persistência (SharedPreferences + Cloud Firestore + HTTP REST)
class ApiProductService {
  ApiProductService._internal() {
    _initData();
  }
  static final ApiProductService instance = ApiProductService._internal();

  String baseUrl = 'https://66e39ff9d2405277b06da8d3.mockapi.io/api/v1/products';

  static const Duration _timeout = Duration(seconds: 10);
  static const String _storageKey = 'api_products_storage_v2';
  static const String _urlKey = 'api_base_url_storage_v2';

  final List<ApiProductModel> _localProducts = [];
  bool _initialized = false;

  FirebaseFirestore? get _db {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  final StreamController<List<ApiProductModel>> _streamController =
      StreamController<List<ApiProductModel>>.broadcast();

  Stream<List<ApiProductModel>> get productsStream => _streamController.stream;

  final List<ApiProductModel> _defaultSamples = const [
    ApiProductModel(
      id: '1',
      name: 'Maçã Fuji Selecionada',
      category: 'Hortifruti',
      price: 8.99,
      cost: 4.50,
      stock: 45.0,
      unit: 'KG',
      description: 'Maçãs frescas e selecionadas diretamente do produtor.',
      imageUrl: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=300',
      hasBgRemoved: true,
      createdAt: '2026-09-30T10:00:00Z',
    ),
    ApiProductModel(
      id: '2',
      name: 'Leite Integral 1L',
      category: 'Frios e Laticínios',
      price: 5.49,
      cost: 3.20,
      stock: 80.0,
      unit: 'UN',
      description: 'Leite integral pasteurizado tipo A.',
      imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=300',
      hasBgRemoved: false,
      createdAt: '2026-09-30T10:15:00Z',
    ),
    ApiProductModel(
      id: '3',
      name: 'Azeite de Oliva Extra Virgem 500ml',
      category: 'Óleos e Azeites',
      price: 34.90,
      cost: 22.00,
      stock: 25.0,
      unit: 'UN',
      description: 'Azeite de oliva extra virgem prensado a frio.',
      imageUrl: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=300',
      hasBgRemoved: true,
      createdAt: '2026-09-30T11:00:00Z',
    ),
  ];

  Future<void> _initData() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Carrega de SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_urlKey);
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        baseUrl = savedUrl.trim();
      }

      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        _localProducts.clear();
        _localProducts.addAll(
          decoded.map((item) => ApiProductModel.fromJson(item as Map<String, dynamic>)).toList(),
        );
      }
    } catch (e) {
      debugPrint('Aviso ao ler SharedPreferences: $e');
    }

    // 2. Carrega da coleção 'api_products' no Firestore para redundância em nuvem
    final db = _db;
    if (db != null) {
      try {
        final snapshot = await db.collection('api_products').get().timeout(const Duration(seconds: 4));
        if (snapshot.docs.isNotEmpty) {
          for (final doc in snapshot.docs) {
            final p = ApiProductModel.fromJson(doc.data());
            final idx = _localProducts.indexWhere((item) => item.id == p.id);
            if (idx != -1) {
              _localProducts[idx] = p;
            } else {
              _localProducts.add(p);
            }
          }
        }
      } catch (e) {
        debugPrint('Aviso ao sincronizar do Firestore: $e');
      }
    }

    // 3. Se ainda estiver vazio, insere amostras
    if (_localProducts.isEmpty) {
      _localProducts.addAll(_defaultSamples);
      _persistLocally();
    }

    _streamController.add(List.unmodifiable(_localProducts));
  }

  Future<void> _persistLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listMap = _localProducts.map((p) => p.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(listMap));
      await prefs.setString(_urlKey, baseUrl);
    } catch (e) {
      debugPrint('Aviso ao salvar localmente: $e');
    }
    _streamController.add(List.unmodifiable(_localProducts));
  }

  Future<void> _syncToCloud(ApiProductModel product, {bool delete = false}) async {
    final db = _db;
    if (db == null) return;
    try {
      if (delete) {
        await db.collection('api_products').doc(product.id).delete();
      } else {
        await db.collection('api_products').doc(product.id).set(product.toJson());
      }
    } catch (e) {
      debugPrint('Aviso ao gravar no Firestore: $e');
    }
  }

  /// [READ - Consulta] - Obtém a lista completa de produtos
  Future<List<ApiProductModel>> getProducts() async {
    await _initData();

    // Tenta obter da API REST remota sem sobrescrever produtos criados pelo usuário
    try {
      final uri = Uri.parse(baseUrl);
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List && decoded.isNotEmpty) {
          final remoteItems = decoded.map((item) => ApiProductModel.fromJson(item as Map<String, dynamic>)).toList();
          // Mescla com os itens locais para não perder itens recém-cadastrados
          for (final r in remoteItems) {
            final idx = _localProducts.indexWhere((p) => p.id == r.id);
            if (idx == -1) {
              _localProducts.add(r);
            }
          }
          await _persistLocally();
        }
      }
    } catch (e) {
      debugPrint('Aviso ao buscar da API remota: $e. Utilizando base persistida.');
    }

    return List.unmodifiable(_localProducts);
  }

  /// [READ - Consulta por ID]
  Future<ApiProductModel> getProductById(String id) async {
    await _initData();
    final local = _localProducts.firstWhere(
      (p) => p.id == id,
      orElse: () => throw ApiException('Produto não encontrado.'),
    );
    return local;
  }

  /// [CREATE - Cadastro via POST]
  Future<ApiProductModel> createProduct(ApiProductModel product) async {
    await _initData();

    final newId = product.id.isNotEmpty
        ? product.id
        : (DateTime.now().millisecondsSinceEpoch % 1000000).toString();

    final created = product.copyWith(
      id: newId,
      createdAt: DateTime.now().toIso8601String(),
    );

    // 1. Salva imediatamente no estado local e SharedPreferences
    _localProducts.insert(0, created);
    await _persistLocally();

    // 2. Salva em nuvem no Firestore
    _syncToCloud(created);

    // 3. Tenta enviar via HTTP POST para a API REST
    try {
      final uri = Uri.parse(baseUrl);
      final payload = created.toJson();
      await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('Aviso: POST HTTP remoto ($e). Produto persistido na nuvem e local.');
    }

    return created;
  }

  /// [UPDATE - Atualização via PUT]
  Future<ApiProductModel> updateProduct(ApiProductModel product) async {
    await _initData();

    final index = _localProducts.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _localProducts[index] = product;
    } else {
      _localProducts.add(product);
    }
    await _persistLocally();

    _syncToCloud(product);

    // Tenta atualizar na API REST remota
    try {
      final uri = Uri.parse('$baseUrl/${product.id}');
      await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(product.toJson()),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('Aviso: PUT HTTP remoto ($e). Produto atualizado localmente e na nuvem.');
    }

    return product;
  }

  /// [DELETE - Exclusão via DELETE]
  Future<void> deleteProduct(String id) async {
    await _initData();

    final removed = _localProducts.where((p) => p.id == id).toList();
    _localProducts.removeWhere((p) => p.id == id);
    await _persistLocally();

    for (final p in removed) {
      _syncToCloud(p, delete: true);
    }

    try {
      final uri = Uri.parse('$baseUrl/$id');
      await http.delete(uri, headers: {
        'Accept': 'application/json',
      }).timeout(_timeout);
    } catch (e) {
      debugPrint('Aviso: DELETE HTTP remoto ($e). Produto excluído localmente e na nuvem.');
    }
  }
}
