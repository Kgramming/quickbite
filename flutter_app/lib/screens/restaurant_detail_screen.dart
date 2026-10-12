import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/restaurant_provider.dart';

class RestaurantDetailScreen extends ConsumerWidget {
  final String restaurantId;

  const RestaurantDetailScreen({
    Key? key,
    required this.restaurantId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(restaurantMenuProvider((restaurantId, 1)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: menuAsync.when(
        data: (menu) {
          return ListView.builder(
            itemCount: menu.items.length,
            itemBuilder: (context, index) {
              final item = menu.items[index];
              return ListTile(
                title: Text(item.name),
                subtitle: Text(item.description),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(item.price),
                    if (!item.available)
                      const Text('Out of stock', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ),
                onTap: item.available
                    ? () {
                        // Add to cart
                        ref.read(cartProvider.notifier).addItem(item, restaurantId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${item.name} added to cart')),
                        );
                      }
                    : null,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
