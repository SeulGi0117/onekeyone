import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

class CartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final int coins;

  const CartScreen({super.key, required this.cartItems, required this.coins});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'ko_KR',
    symbol: '₩',
    decimalDigits: 0,
  );

  int _usedCoins = 0;

  void _removeFromCart(int index) {
    setState(() {
      if (widget.cartItems[index]['quantity'] > 1) {
        widget.cartItems[index]['quantity']--;
      } else {
        widget.cartItems.removeAt(index);
      }
    });
  }

  void _addToCart(int index) {
    setState(() {
      widget.cartItems[index]['quantity']++;
    });
  }

  double _calculateProductTotal() {
    double total = 0.0;
    for (var item in widget.cartItems) {
      total += item['quantity'] *
          double.parse(item['price'].replaceAll('₩', '').replaceAll(',', ''));
    }
    return total;
  }

  double _calculateTotal() {
    return _calculateProductTotal() - _usedCoins;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '장바구니',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...widget.cartItems.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> item = entry.value;
              return _buildCartItem(item['title'], item['price'],
                  item['quantity'], item['image'], index);
            }),
            const Divider(),
            _buildPointsSection(),
            const Divider(),
            _buildSummaryRow(
                '상품 총 가격', _currencyFormat.format(_calculateProductTotal())),
            _buildSummaryRow('코인 할인', '-${_currencyFormat.format(_usedCoins)}'),
            _buildSummaryRow(
                '최종 합계', _currencyFormat.format(_calculateTotal())),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // 결제 처리
                  try {
                    // 코인 차감
                    if (_usedCoins > 0) {
                      final newCoins = widget.coins - _usedCoins;
                      await FirebaseDatabase.instance
                          .ref()
                          .child('coins')
                          .set(newCoins);
                    }

                    // 결제 완료 메시지
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('결제가 완료되었습니다'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // 장바구니 비우기
                    widget.cartItems.clear();

                    // 이전 화면으로 돌아가기
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('결제 중 오류가 발생했습니다'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '결제하기',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(
      String title, String price, int quantity, String imagePath, int index) {
    double itemTotal =
        quantity * double.parse(price.replaceAll('₩', '').replaceAll(',', ''));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Image.asset(
            imagePath,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(price),
                Text('합계: ${_currencyFormat.format(itemTotal)}'),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _removeFromCart(index),
              ),
              Text(
                '$quantity',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _addToCart(index),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('사용 가능한 코인: ${widget.coins}'),
        Row(
          children: [
            SizedBox(
              width: 100,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '코인 입력',
                ),
                onChanged: (value) {
                  setState(() {
                    _usedCoins = int.tryParse(value) ?? 0;
                    if (_usedCoins > widget.coins) {
                      _usedCoins = widget.coins;
                    }
                  });
                },
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _usedCoins = widget.coins;
                });
              },
              child: const Text('전액 사용'),
            ),
          ],
        ),
        Text('사용할 코인: $_usedCoins'),
      ],
    );
  }

  Widget _buildSummaryRow(String title, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            amount,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
