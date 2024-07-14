import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  GenerativeModel? _model;
  ChatSession? _chat;
  bool _isApiInitialized = false;
  bool _isTyping = false;
  bool _isAITyping = false;
  Timer? _inactivityTimer;
  int _lastMessageTime = 0;
  final List<int> _inactivityIntervals = [
    5 * 60,
    10 * 60,
    20 * 60,
    30 * 60,
    60 * 60,
    2 * 60 * 60,
    6 * 60 * 60,
    12 * 60 * 60,
    24 * 60 * 60
  ];
  int _currentIntervalIndex = 0;
  final int _maxInactivityTime = 24 * 60 * 60; // 24시간

  Map<String, String> emojiToLottieMap = {
    '😊': 'happy.json',
    '😢': 'sad.json',
    '❤️': 'heart.json',
    '🙏': 'pray.json',
    '😍': 'love_face.json',
    '😂': 'laughing.json',
    '😁': 'laughing.json',
    '😀': 'laughing.json',
    '😄': 'laughing.json',
    '🤔': 'thinking.json',
    '👍': 'thumbs_up.json',
    //
    '🎉': 'celebration.json',
    '😎': 'cool.json',
    '😴': 'sleeping.json',
    '🤗': 'hugging.json',
    '😮': 'surprised.json',
    '🤓': 'nerd.json',
    '🤯': 'mind_blown.json',
  };

  final RegExp emojiRegExp = RegExp(
    r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initGeminiApi();
    _startInactivityTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startInactivityTimer();
    } else if (state == AppLifecycleState.paused) {
      _inactivityTimer?.cancel();
    }
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _checkInactivity();
    });
  }

  void _checkInactivity() {
    int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int elapsedTime = currentTime - _lastMessageTime;

    if (elapsedTime >= _maxInactivityTime) {
      _inactivityTimer?.cancel();
      return;
    }

    if (elapsedTime >= _inactivityIntervals[_currentIntervalIndex]) {
      _sendAIMessage();
      _currentIntervalIndex =
          (_currentIntervalIndex + 1) % _inactivityIntervals.length;
    }
  }

  void _updateLastMessageTime() {
    _lastMessageTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _currentIntervalIndex = 0;
    _startInactivityTimer(); // 타이머 재시작
  }

  Future<void> _sendAIMessage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final chatDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final chatList =
          (chatDoc.data() as Map<String, dynamic>)['chat'] as List<dynamic>;
      final recentMessages = chatList.reversed.take(50).toList();
      if (recentMessages.isNotEmpty) {
        String prompt = '''
Based on our previous conversation, please initiate a new topic or ask a follow-up question to the user. 
Make sure to keep the context and tone consistent with our earlier chat. 
Your message should be engaging and encourage the user to continue the conversation.

Here's a transcript of our previous conversation, so please use it as a guide to continue our conversation:
---
${recentMessages.reversed.map((message) => "${message['response'] == 'user' ? 'user' : 'AI'}: ${message['text']}").join('\n')}
---
''';

        final response = await _chat!.sendMessage(Content.text(prompt));
        if (response.text != null) {
          await _saveAndDisplayAIMessage(response.text!);
          print(response.text);
        }
      }
    } catch (e) {
      print('Error sending AI message: $e');
    }
  }

  Future<void> _saveAndDisplayAIMessage(String message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final newResponse = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'text': message,
        'response': 'gemini',
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'chat': FieldValue.arrayUnion([newResponse])
      });

      setState(() {
        // UI 업데이트를 위한 상태 변경
      });
    }
  }

  Future<void> _initGeminiApi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('api') ?? '';
      if (apiKey.isNotEmpty) {
        _model = GenerativeModel(
          model: 'gemini-1.5-pro',
          apiKey: apiKey,
          safetySettings: [
            SafetySetting(
                HarmCategory.dangerousContent, HarmBlockThreshold.none),
            SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
            SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.high),
            SafetySetting(
                HarmCategory.sexuallyExplicit, HarmBlockThreshold.high),
          ],
        );
        final basePrompt = Content.text(
            '''The person you're talking to is at high risk for severe depression and suicide, so you need to be sensitive when you talk to them.
It's important to be a good listener, empathetic, non-judgmental, and take their feelings and thoughts seriously.
If the person seems to be at high risk for suicide, you can try talking directly to them about suicide and act as a deterrent to suicidal thoughts.
Encourage them to seek professional help, and explain the importance of diagnosis and treatment by a mental health professional.
Emphasize the importance of social support for the person you're talking to, and explain that support from family, friends, and the community can be very helpful in recovery.
Help the person develop a specific safety plan, including what to do in a crisis and who to call.
Encourage positive lifestyle habits and help them establish a good lifestyle pattern, recommending healthy eating, getting enough sleep, and getting adequate exercise.
It's important to be patient and supportive, understanding that recovery is a process that takes time. Never use emojis, and always be nice, no matter what the other person says. Being respectful is a must.
When using emojis, make sure to use them in no more than one of your answers, and avoid using emojis whenever possible. If you reply with more than two emojis, someone will be shot and killed. So never, ever, ever use more than one emoji in a response.''');
        _chat = _model!.startChat(history: [basePrompt]);
        setState(() {
          _isApiInitialized = true;
        });
        await _loadChatHistory();
      } else {
        print('API key not found.');
      }
    } catch (e) {
      print('Gemini API initialization error: $e');
    }
  }

  Stream<DocumentSnapshot> _getChatStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    }
    return const Stream.empty();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini with Y❤️U'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _showDeleteConfirmationDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _getChatStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(child: Text('No chat history.'));
                  }

                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  final chatList = (userData['chat'] as List<dynamic>?) ?? [];

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: chatList.length,
                    itemBuilder: (context, index) {
                      final message = chatList[chatList.length - 1 - index]
                          as Map<String, dynamic>;
                      final timestamp = message['timestamp'] as int;
                      final dateTime =
                          DateTime.fromMillisecondsSinceEpoch(timestamp);
                      final isUser = message['response'] == 'user';

                      final timeFormat = DateFormat('HH:mm');
                      final dateFormat = DateFormat('yyyy - MM - dd');

                      final timeString = timeFormat.format(dateTime);
                      final dateString = dateFormat.format(dateTime);

                      final isNewDate = index == chatList.length - 1 ||
                          dateString !=
                              dateFormat.format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                      chatList[chatList.length - 2 - index]
                                          ['timestamp'] as int));

                      final isFirstInGroup = index == chatList.length - 1 ||
                          isUser !=
                              (chatList[chatList.length - 2 - index]
                                      ['response'] ==
                                  'user') ||
                          timeString !=
                              timeFormat.format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                      chatList[chatList.length - 2 - index]
                                          ['timestamp'] as int));

                      final isLastInTimeGroup = index == 0 ||
                          timeString !=
                              timeFormat.format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                      chatList[chatList.length - index]
                                          ['timestamp'] as int)) ||
                          isUser !=
                              (chatList[chatList.length - index]['response'] ==
                                  'user');

                      final isLastInGroup = index == 0 ||
                          isUser !=
                              (chatList[chatList.length - index]['response'] ==
                                  'user');

                      return Column(
                        children: [
                          if (isNewDate)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                dateString,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4.0, horizontal: 8.0),
                            child: Stack(
                              children: [
                                Row(
                                  mainAxisAlignment: isUser
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (!isUser) const SizedBox(width: 40),
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isUser
                                              ? Colors.yellow[200]
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.grey.withOpacity(0.5),
                                              spreadRadius: 1,
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (message['lottieFile'] != null)
                                              Lottie.asset(
                                                'assets/lottie/${message['lottieFile']}',
                                                width: 150,
                                                height: 150,
                                                fit: BoxFit.contain,
                                              ),
                                            Text(message['text']),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (!isUser && isLastInTimeGroup)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 8.0),
                                        child: Text(
                                          timeString,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (!isUser && isFirstInGroup)
                                  const Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: CircleAvatar(
                                        backgroundImage:
                                            AssetImage('assets/image/128.png'),
                                        radius: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (index == 0 && _isTyping)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundImage:
                                        AssetImage('assets/image/128.png'),
                                    radius: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: LoadingAnimationWidget
                                        .staggeredDotsWave(
                                      color: Colors.grey,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isLastInGroup && index != 0)
                            const SizedBox(height: 16), // 그룹 사이의 간격 추가
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration:
                          const InputDecoration(hintText: 'input message...'),
                      onFieldSubmitted: (_) =>
                          _isAITyping ? null : _sendMessage(),
                      enabled: !_isAITyping,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _isAITyping ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadChatHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final chatDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (chatDoc.exists) {
        final chatData = chatDoc.data() as Map<String, dynamic>;
        final chatList = (chatData['chat'] as List<dynamic>?) ?? [];

        final recentMessages = chatList.reversed.take(50).toList();

        if (recentMessages.isNotEmpty) {
          // 이전 대화 요약 및 새 대화 시작 알림
          String contextPrompt = '''
Previously, you had the following conversation:
---
${recentMessages.reversed.map((message) => "${message['response'] == 'user' ? 'user' : 'AI'}: ${message['text']}").join('\n')}
---
Now let's keep the context of this conversation in mind as we move forward. Please respond appropriately to the following messages from your users.
Keep the language you used in the conversation the same. From now on, users will continue the conversation based on the previous chat, so keep it real.
''';

          final _ = await _chat!.sendMessage(Content.text(contextPrompt));
          //print(_.text);
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newMessage = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'text': _messageController.text,
      'response': 'user',
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'chat': FieldValue.arrayUnion([newMessage])
      });

      _messageController.clear();
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      // Gemini API 호출
      if (_isApiInitialized && _chat != null) {
        await _getGeminiResponse(newMessage['text'] as String);
      } else {
        print('Gemini API not initialized or chat session not initialized.');
      }
    } catch (e) {
      print('send message error: $e');
    }
  }

  Future<void> _getGeminiResponse(String userMessage) async {
    setState(() {
      _isTyping = true;
      _isAITyping = true;
    });

    try {
      if (_chat == null) {
        print('Chat session not initialized.');
        return;
      }

      final response = await _chat!.sendMessage(Content.text(userMessage));
      var geminiResponse = response.text;
      if (geminiResponse != null) {
        geminiResponse = geminiResponse.replaceAll(
            RegExp(r'^(AI:|user:)\s*', multiLine: true), '');
      }

      if (geminiResponse != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final sentences = geminiResponse.split(RegExp(r'(?<=[.!?])\s+'));
          for (var i = 0; i < sentences.length; i++) {
            final sentence = sentences[i].trim(); // 문장 시작의 공백 제거
            final lines = sentence.split('\n');
            for (var j = 0; j < lines.length; j++) {
              final line = lines[j].trimLeft(); // 각 줄 시작의 공백 제거
              if (line.isNotEmpty) {
                final parts = extractEmojiAndText(line);
                for (var k = 0; k < parts.length; k++) {
                  final part = parts[k];
                  final newResponse = {
                    'timestamp': DateTime.now().millisecondsSinceEpoch,
                    'text': part['content'],
                    'response': 'gemini',
                  };

                  if (part['type'] == 'emoji' && part['lottieFile'] != null) {
                    newResponse['lottieFile'] = part['lottieFile'];
                  }

                  // 각 메시지를 개별적으로 Firestore에 추가
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({
                    'chat': FieldValue.arrayUnion([newResponse])
                  });

                  // 마지막 부분이 아닌 경우에만 딜레이 적용
                  if (i < sentences.length - 1 ||
                      j < lines.length - 1 ||
                      k < parts.length - 1) {
                    int delay = _calculateDelay(part['content']);
                    await Future.delayed(Duration(milliseconds: delay));
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Gemini API error: $e');
    } finally {
      setState(() {
        _isTyping = false;
        _isAITyping = false;
      });
    }

    _updateLastMessageTime();
  }

  int _calculateDelay(String text) {
    final random = Random();

    // 기본 타이핑 속도 (단어당 평균 시간, 밀리초)
    int baseSpeed = 1000;

    // 단어 수 계산
    int wordCount = text.split(' ').length;

    // 기본 딜레이 계산
    int baseDelay = wordCount * baseSpeed;

    // 랜덤 변동 추가 (±30%)
    double randomFactor = 0.7 + (random.nextDouble() * 0.6);
    int delay = (baseDelay * randomFactor).round();

    // 최소 및 최대 딜레이 설정
    int minDelay = 500;
    int maxDelay = 5000;
    delay = delay.clamp(minDelay, maxDelay);

    // 추가적인 랜덤 일시 정지 추가
    if (random.nextDouble() < 0.2) {
      // 20% 확률로
      delay += random.nextInt(1000); // 0~1000ms 추가 딜레이
    }

    return delay;
  }

  List<Map<String, dynamic>> extractEmojiAndText(String text) {
    List<Map<String, dynamic>> result = [];
    String remainingText = text;

    while (remainingText.isNotEmpty) {
      final match = emojiRegExp.firstMatch(remainingText);
      if (match != null && match.start == 0) {
        final emoji = match.group(0)!;
        if (emojiToLottieMap.containsKey(emoji)) {
          result.add({
            'type': 'emoji',
            'content': emoji,
            'lottieFile': emojiToLottieMap[emoji],
          });
        } else {
          result.add({
            'type': 'text',
            'content': emoji,
          });
        }
        remainingText = remainingText.substring(emoji.length);
      } else {
        final nextEmojiIndex = match?.start ?? remainingText.length;
        final textPart = remainingText.substring(0, nextEmojiIndex);
        if (textPart.isNotEmpty) {
          result.add({
            'type': 'text',
            'content': textPart,
          });
        }
        remainingText = remainingText.substring(nextEmojiIndex);
      }
    }

    return result;
  }

  Future<void> _showDeleteConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete all messages?'),
          content: const Text('Are you sure you want to delete all messages?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAllMessages();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAllMessages() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'chat': []});

        setState(() {
          // UI 업데이트
        });
      } catch (e) {
        print('메시지 삭제 오류: $e');
      }
    }
  }
}
