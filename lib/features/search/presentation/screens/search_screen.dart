import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Nearby'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              hintText: 'Search for products, shops, or categories...',
              leading: const Icon(Icons.search, color: Colors.grey),
              elevation: MaterialStateProperty.all(0),
              backgroundColor: MaterialStateProperty.all(Colors.grey[100]),
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                _buildSectionTitle(context, 'Trending Categories'),
                _buildCategories(context),
                const SizedBox(height: 16),
                _buildSectionTitle(context, 'Recent Searches'),
                _buildRecentSearchItem(Icons.history, 'USB Charger'),
                _buildRecentSearchItem(Icons.history, 'Bluetooth Headphones'),
                _buildRecentSearchItem(Icons.history, 'Grocery Store'),
                const SizedBox(height: 16),
                _buildSectionTitle(context, 'Popular Near You'),
                _buildPopularItem('Fresh Fruits', '2.5 km away'),
                _buildPopularItem('Electronics Repair', '1.2 km away'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCategories(BuildContext context) {
    final categories = ['Electronics', 'Groceries', 'Clothing', 'Pharmacy', 'Food'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((category) {
          return Chip(
            label: Text(category),
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            side: BorderSide.none,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentSearchItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      trailing: const Icon(Icons.close, color: Colors.grey, size: 20),
      onTap: () {},
    );
  }

  Widget _buildPopularItem(String title, String subtitle) {
    return ListTile(
      leading: const Icon(Icons.trending_up, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {},
    );
  }
}
