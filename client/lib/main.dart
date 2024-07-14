import 'package:client/chat_screen.dart';
import 'package:client/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:client/api_key_screen.dart';

import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseOptions? firebaseOptions;

  if (kIsWeb) {
    firebaseOptions = DefaultFirebaseOptions.web;
  } else if (Platform.isAndroid) {
    firebaseOptions = DefaultFirebaseOptions.android;
  } else if (Platform.isIOS) {
    firebaseOptions = DefaultFirebaseOptions.ios;
  } else if (Platform.isMacOS) {
    firebaseOptions = DefaultFirebaseOptions.macos;
  } else if (Platform.isWindows) {
    firebaseOptions = DefaultFirebaseOptions.windows;
  } else if (Platform.isLinux) {
    firebaseOptions = DefaultFirebaseOptions.linux;
  }

  if (firebaseOptions != null) {
    await Firebase.initializeApp(
      options: firebaseOptions,
    );
  } else {
    print('Unsupported platform.');
    // 여기서 앱을 종료하거나 다른 처리를 할 수 있습니다.
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini with You',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return const LoginPage();
          } else {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (BuildContext context,
                  AsyncSnapshot<DocumentSnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  }

                  if (snapshot.hasData && snapshot.data!.exists) {
                    Map<String, dynamic> data =
                        snapshot.data!.data() as Map<String, dynamic>;
                    if (data.containsKey('api') &&
                        data['api'] != null &&
                        data['api'].toString().isNotEmpty) {
                      return const ChatPage();
                    }
                  }

                  // API 키가 없거나 유효하지 않은 경우
                  return ApiKeyScreen(userId: user.uid);
                }

                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              },
            );
          }
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
