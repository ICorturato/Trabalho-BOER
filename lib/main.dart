import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeuMercadoApp());
}

Future<FirebaseApp> _initializeFirebase() => Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyAtYmEESuoKbXwR7rRfwGtzcbuw9o_0hdI',
        authDomain: 'mercadoboer.firebaseapp.com',
        projectId: 'mercadoboer',
        storageBucket: 'mercadoboer.firebasestorage.app',
        messagingSenderId: '317406157643',
        appId: '1:317406157643:web:2bd9ebadd84c720f30a6ce',
      ),
    );

class MeuMercadoApp extends StatelessWidget {
  const MeuMercadoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meu Mercado',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        useMaterial3: true,
      ),
      home: const _AppStartup(),
    );
  }
}

class _AppStartup extends StatefulWidget {
  const _AppStartup();

  @override
  State<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<_AppStartup> {
  late Future<FirebaseApp> _firebase = _initializeFirebase();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _firebase,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const SplashScreen();
        }

        if (snapshot.hasError) {
          debugPrint('Firebase não foi inicializado: ${snapshot.error}');
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Não foi possível iniciar o aplicativo.'),
                    const SizedBox(height: 8),
                    SelectableText('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _firebase = _initializeFirebase());
                      },
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const Scaffold(
          backgroundColor: Colors.green,
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      },
    );
  }
}
