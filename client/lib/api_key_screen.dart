import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApiKeyScreen extends StatefulWidget {
  final String userId;

  const ApiKeyScreen({super.key, required this.userId});

  @override
  _ApiKeyScreenState createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final TextEditingController _apiKeyController = TextEditingController();

  Future<void> _saveApiKey() async {
    if (_apiKeyController.text.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .set({
          'api': _apiKeyController.text,
        }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key saved')),
        );

        // API 키 저장 후 이전 화면으로 돌아가기
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving API key: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter API key')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter API key')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API key',
                hintText: 'Enter API key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveApiKey,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50), // 버튼의 최소 크기 설정
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
