class ApiProductModel {
  const ApiProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.cost,
    required this.stock,
    required this.unit,
    required this.description,
    required this.imageUrl,
    this.hasBgRemoved = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final double cost;
  final double stock;
  final String unit;
  final String description;
  final String imageUrl;
  final bool hasBgRemoved;
  final String? createdAt;

  factory ApiProductModel.fromJson(Map<String, dynamic> json) {
    return ApiProductModel(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? json['nome'] as String? ?? '',
      category: json['category'] as String? ?? json['categoria'] as String? ?? 'Geral',
      price: (json['price'] ?? json['preco'] as num? ?? 0.0).toDouble(),
      cost: (json['cost'] ?? json['custo'] as num? ?? 0.0).toDouble(),
      stock: (json['stock'] ?? json['estoque'] as num? ?? 0.0).toDouble(),
      unit: json['unit'] as String? ?? json['unidade'] as String? ?? 'UN',
      description: json['description'] as String? ?? json['descricao'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? json['imagem'] as String? ?? json['avatar'] as String? ?? '',
      hasBgRemoved: json['hasBgRemoved'] as bool? ?? json['fundoRemovido'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? json['criadoEm'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'cost': cost,
      'stock': stock,
      'unit': unit,
      'description': description,
      'imageUrl': imageUrl,
      'hasBgRemoved': hasBgRemoved,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  ApiProductModel copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    double? cost,
    double? stock,
    String? unit,
    String? description,
    String? imageUrl,
    bool? hasBgRemoved,
    String? createdAt,
  }) {
    return ApiProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      hasBgRemoved: hasBgRemoved ?? this.hasBgRemoved,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
