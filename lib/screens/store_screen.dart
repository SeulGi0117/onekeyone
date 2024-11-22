import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'cart_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int _coins = 0;
  final List<Map<String, dynamic>> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  Future<void> _loadCoins() async {
    final snapshot = await FirebaseDatabase.instance.ref().child('coins').get();
    if (snapshot.exists) {
      setState(() {
        _coins = (snapshot.value as int?) ?? 0;
      });
    }
  }

  void _addToCart(String title, String price, String imagePath) {
    setState(() {
      int index = _cartItems.indexWhere((item) => item['title'] == title);
      if (index != -1) {
        _cartItems[index]['quantity']++;
      } else {
        _cartItems.add({
          'title': title,
          'price': price,
          'quantity': 1,
          'image': imagePath
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title이(가) 장바구니에 담겼습니다.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on,
                    color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Text(
                  '보유 코인: $_coins',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildProductItem(
                    '식물 키트', '₩33,000', 'assets/images/store_images/식물키트.jpg'),
                _buildProductItem(
                    '식물 영양제', '₩5,000', 'assets/images/store_images/식물영양제.jpg'),
                _buildProductItem(
                    '식물 비료', '₩10,000', 'assets/images/store_images/식물비료.jpg'),
                _buildProductItem(
                    '원예 도구', '₩30,000', 'assets/images/store_images/원예도구.jpg'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: '상품',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: '장바구니',
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CartScreen(
                  cartItems: _cartItems,
                  coins: _coins,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildProductItem(String title, String price, String imagePath) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              child: Image.asset(
                imagePath,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: () => _addToCart(title, price, imagePath),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 36),
                  ),
                  child: const Text(
                    '장바구니 담기',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
