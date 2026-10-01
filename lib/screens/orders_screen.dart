import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  String money(num value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  String paymentLabel(String method) => switch (method) {
        'cash' => 'Dinheiro na entrega',
        'credit_delivery' => 'Crédito na entrega',
        'debit_delivery' => 'Débito na entrega',
        'pix_delivery' => 'Pix na entrega',
        _ => 'Pagamento na entrega',
      };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Entre na sua conta para ver os pedidos.')));

    return Scaffold(
      appBar: AppBar(title: const Text('Meus pedidos'), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').where('userId', isEqualTo: uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erro ao carregar pedidos: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aDate = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bDate = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return bDate.compareTo(aDate);
            });
          if (docs.isEmpty) return const Center(child: Text('Você ainda não tem pedidos.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final lines = (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
              final date = (data['createdAt'] as Timestamp?)?.toDate();
              return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text('Pedido #${doc.id.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                    Text(money(data['total'] as num? ?? 0),
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ]),
                  if (date != null) Padding(padding: const EdgeInsets.only(top: 4),
                    child: Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}')),
                  const SizedBox(height: 10),
                  ...lines.map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${(line['quantity'] as num? ?? 0).toStringAsFixed(0)}x ${line['name']}'),
                  )),
                  const Divider(),
                  Text(paymentLabel(data['paymentMethod'] as String? ?? '')),
                  Text(data['deliveryAddress'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  if ((data['couponCode'] as String? ?? '').isNotEmpty)
                    Text('Cupom: ${data['couponCode']}'),
                ],
              )));
            },
          );
        },
      ),
    );
  }
}
