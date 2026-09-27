import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'app_theme.dart';
import 'modern_loader.dart';

class SuperAdminScreen extends StatelessWidget {
  const SuperAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Super Admin - Manage Shops'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseUtils.firestore
            .collection('shops')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: ModernLoader(color: Colors.black));
          }

          final shops = snapshot.data!.docs;
          if (shops.isEmpty) {
            return const Center(child: Text('No shops found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final doc = shops[index];
              final data = doc.data() as Map<String, dynamic>;
              final isActive = data['is_active'] ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isActive ? Colors.green.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['shop_name'] ?? 'Unknown',
                              style: AppTextStyles.heading2(color: AppColors.textDark),
                            ),
                            const SizedBox(height: 8),
                            Text('Owner: ${data['owner_name'] ?? 'N/A'}'),
                            const SizedBox(height: 4),
                            Text('Mobile: ${data['mobile'] ?? 'N/A'}'),
                            const SizedBox(height: 4),
                            Text('Address: ${data['address'] ?? 'N/A'}'),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isActive ? 'APPROVED' : 'PENDING',
                            style: TextStyle(
                              color: isActive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Switch(
                            value: isActive,
                            activeThumbColor: Colors.green,
                            activeTrackColor: Colors.green.withValues(alpha: 0.5),
                            onChanged: (val) {
                              FirebaseUtils.firestore.collection('shops').doc(doc.id).update({
                                'is_active': val,
                                'status': val ? 'approved' : 'pending',
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
