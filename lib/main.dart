import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    await dotenv.load(fileName: ".env");
    print("환경변수 로드 성공");

    final firebaseOptions = FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '',
      appId: dotenv.env['FIREBASE_APP_ID'] ?? '',
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
      projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
      databaseURL: dotenv.env['FIREBASE_DATABASE_URL'] ?? '',
    );

    await Firebase.initializeApp(options: firebaseOptions);
    print("Firebase 초기화 성공");

    runApp(MyApp());
  } catch (e, stackTrace) {
    print("초기화 중 에러 발생: $e");
    print("Stack trace: $stackTrace");
    runApp(ErrorApp(error: e.toString()));
  }
}

// 에러 표시용 위젯
class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '앱 초기화 중 오류가 발생했습니다',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(error, style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
    );
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
