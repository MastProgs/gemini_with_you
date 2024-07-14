import 'package:client/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController apiKeyController = TextEditingController();
  bool _isEmailValid = false;

  Future<void> _showErrorDialog(BuildContext context, String message) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveApiKey(String userId, String apiKey) async {
    // Firestore에 API 키 저장
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'uid': userId,
      'api': apiKey,
    }, SetOptions(merge: true));

    // SharedPreferences에 API 키 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api', apiKey);
  }

  Future<void> _login(BuildContext context) async {
    if (!_isEmailValid) {
      await _showErrorDialog(context, 'Please enter a valid e-mail address.');
      return;
    }

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      // Firestore에서 API 키 확인
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      String apiKey = '';
      if (!userDoc.exists ||
          !(userDoc.data() as Map<String, dynamic>).containsKey('api')) {
        // API 키가 없는 경우
        if (apiKeyController.text.isEmpty) {
          await _showErrorDialog(context, 'Please enter your API key.');
          return; // 로그인 프로세스 중단
        }
        apiKey = apiKeyController.text;
        await _saveApiKey(userCredential.user!.uid, apiKey);
      } else {
        // Firestore에서 API 키 가져오기
        apiKey = (userDoc.data() as Map<String, dynamic>)['api'] as String;
      }

      // API 키를 SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api', apiKey);

      //print('저장된 API 키: $apiKey'); // 디버깅용 로그

      // 필요한 최소한의 사용자 데이터만 가져오기
      final _ = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      // 나머지 데이터는 백그라운드에서 비동기적으로 가져오기
      _fetchAdditionalUserData(userCredential.user!.uid);

      // 로그인 성공 후 처리
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (context) => const ChatPage()), // ChatPage은 채팅 화면 위젯입니다.
      );
    } catch (e) {
      await _showErrorDialog(context, 'Login failed: $e');
      // 로그인 실패 시 여기서 함수가 종료되므로 화면 전환이 일어나지 않습니다.
    } finally {}
  }

  Future<void> _signUp(BuildContext context) async {
    if (!_isEmailValid) {
      await _showErrorDialog(context, 'Please enter a valid e-mail address.');
      return;
    }

    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      await _showErrorDialog(context, 'Please enter your email and password.');
      return;
    }

    if (apiKeyController.text.isEmpty) {
      await _showErrorDialog(context, 'Please enter your Gemini API key.');
      return;
    }

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      // Firestore에 사용자 문서 생성
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'api': apiKeyController.text,
      });

      // 회원가입 성공 후 처리
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ChatPage()),
      );
    } catch (e) {
      await _showErrorDialog(context, 'Sign up failed: $e');
    }
  }

  Future<void> _fetchAdditionalUserData(String userId) async {
    // 추가 사용자 데이터를 비동기적으로 가져오기
    // 이 데이터는 UI 업데이트에 즉시 필요하지 않은 정보들입니다.
  }

  // 이메일 유효성 검사 함수
  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _validateEmail(String value) {
    setState(() {
      _isEmailValid = isValidEmail(value);
    });
  }

  void _showApiKeyInstructions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('How to create Gemini API key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1. Click the link below to go to Google AI Studio.'),
              InkWell(
                child: const Text(
                  'https://aistudio.google.com/app/apikey',
                  style: TextStyle(
                      color: Colors.blue, decoration: TextDecoration.underline),
                ),
                onTap: () =>
                    _launchUrl('https://aistudio.google.com/app/apikey'),
              ),
              const SizedBox(height: 10),
              const Text('2. Sign in with your Google account.'),
              const Text('3. Click the "Create API Key" button.'),
              const Text('4. Copy the generated API key and paste it here.'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini with Y❤️U')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'e-mail',
                errorText: _isEmailValid
                    ? null
                    : 'Please enter a valid e-mail address.',
              ),
              keyboardType: TextInputType.emailAddress,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9@._-]')),
              ],
              onChanged: (value) {
                _validateEmail(value);
              },
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _login(context),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'password'),
              obscureText: true,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _login(context),
            ),
            TextField(
              controller: apiKeyController,
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'If you have no API key, click here.',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: _showApiKeyInstructions,
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_\-.]')),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(context),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isEmailValid ? () => _signUp(context) : null,
                  child: const Text('Sign Up'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isEmailValid ? () => _login(context) : null,
                  child: const Text('Login'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
