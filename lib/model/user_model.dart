class UserModel {
  final String? id;
  final String name;
  final String phone;
  final String email;
 
  UserModel({
    this.id,
    required this.name,
    required this.phone,
    required this.email,
  });
 
  // Converter para o Firestore (Salvar / Inserir)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'createdAt': DateTime.now(),
    };
  }
 
  // Criar o objeto a partir do Firestore (Ler / Listar)
  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      id: docId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
    );
  }
}