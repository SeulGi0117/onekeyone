import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyD4f4nSxWHu68QGU0Iiikk_hM7xkRS29Vs",
        appId: "aaaa-8a6a5",
        messagingSenderId: "411960763521",
        projectId: "aaaa",
        databaseURL: "https://aaaa-8a6a5-default-rtdb.firebaseio.com/",
      ),
    );
    runApp(MyApp());
  } catch (e) {
    print('Firebase 초기화 오류: $e');
    // Firebase 초기화에 실패해도 앱은 실행되도록
    runApp(MyApp());
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Care App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: HomeScreen(),
    );
  }
}
