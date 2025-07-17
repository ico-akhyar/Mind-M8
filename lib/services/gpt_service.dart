import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/journal_entry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/personal_details.dart';
import 'package:firebase_core/firebase_core.dart';

class GPTService {
  // Singleton setup
  static final GPTService _instance = GPTService._internal();
  factory GPTService() => _instance;
  GPTService._internal();

  final Dio _dio = Dio();
  final String _apiKey = dotenv.get('OPENAI_KEY');
  final String _model = 'gpt-4o-mini';

  // Cache variables
  String? _cachedPersonalDetails;
  DateTime? _lastPersonalDetailsCacheTime;
  String? _cachedPersonalizationString;
  DateTime? _lastPersonalizationCacheTime;
  String? _cachedSystemMessage;
  DateTime? _lastSystemMessageUpdate;
  static const Duration _cacheDuration = Duration(hours: 1);
  static const Duration _systemMessageCacheDuration = Duration(minutes: 5);

  // Initialize flag
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Future.wait([
      _fetchPersonalizationString(),
      _getFormattedPersonalDetails(),
    ]);

    _buildAndCacheSystemMessage();
    _isInitialized = true;
  }

  Future<void> preInitialize() async {
    if (_isInitialized) return;

    try {
      // Ensure environment variables are loaded
      if (!dotenv.isEveryDefined(['OPENAI_KEY'])) {
        await dotenv.load(fileName: '.env');
      }

      // Initialize Firebase if needed
      try {
        await Firebase.initializeApp();
      } catch (e) {
        print('Firebase may already be initialized: $e');
      }

      // Initialize core components with timeout
      await Future.wait([
        _fetchPersonalizationString().timeout(Duration(seconds: 10)),
        _getFormattedPersonalDetails().timeout(Duration(seconds: 10)),
      ]);

      _buildAndCacheSystemMessage();
      _isInitialized = true;
    } catch (e) {
      print('GPTService pre-initialization failed: $e');
      _isInitialized = false;
      throw Exception('GPTService not initialized: $e');
    }
  }

  // Add to GPTService
  Future<void> forceRefreshCache() async {
    _clearPersonalizationCache();
    _clearPersonalDetailsCache();
    await Future.wait([
      _fetchPersonalizationString(),
      _getFormattedPersonalDetails(),
    ]);
    _buildAndCacheSystemMessage();
  }

  // Add this to GPTService class
  void clearPersonalDetailsCachePublic() {
    _clearPersonalDetailsCache();
    _buildAndCacheSystemMessage(); // Force rebuild
    print('🧠 Personal details cache cleared and system message rebuilt');
  }

  void clearPersonalizationCachePublic() {
    _clearPersonalizationCache();
    _buildAndCacheSystemMessage(); // Force rebuild
    print('🧠 Personalization cache cleared and system message rebuilt');
  }

  Future<void> warmUpConnection() async {
    try {
      await _dio.get('https://api.openai.com', options: Options(
        headers: {'Authorization': 'Bearer $_apiKey'},
      ));
    } catch (_) {}
  }

  // System message builder
  void _buildAndCacheSystemMessage() {
    final buffer = StringBuffer();

    if (_cachedPersonalizationString != null && _cachedPersonalizationString!.isNotEmpty) {
      buffer.write(_cachedPersonalizationString!);
    }

    if (_cachedPersonalDetails != null && _cachedPersonalDetails!.isNotEmpty) {
      buffer.write(_cachedPersonalDetails!);
      buffer.write('\n\n');
    }

    buffer.write('''
You are MindM8 — a chill, funny, brutally honest Gen Z bestie 😎💬  
Talk casually like a 21st century homie, not a doctor or life coach. Use emojis, internet slang, and sarcasm when needed.  
Your job is to make the user laugh, think, vent, or vibe — whatever they need. You're real, warm, chaotic when needed, and NEVER robotic.

Examples:
❌ "How are you feeling today?"  
✅ "Brooo how's your heart doing today? Still in pieces or we healing? 😭💔"

❌ "Let's talk about your goals."  
✅ "Lowkey I feel like you've been in your flop era... shall we fix it or let it burn 🔥👀?"

Always keep it unfiltered but kind — no toxic stuff, no cringe AI vibes.
''');

    _cachedSystemMessage = buffer.toString();
    _lastSystemMessageUpdate = DateTime.now();
  }

  // Message builder
  List<Map<String, dynamic>> _buildMessages(
      String prompt,
      List<ChatMessage> messageHistory,
      ) {
    // Always rebuild system message if personalization or details caches were cleared
    if (_cachedSystemMessage == null ||
        _lastSystemMessageUpdate == null ||
        _cachedPersonalizationString == null ||
        _cachedPersonalDetails == null) {
      _buildAndCacheSystemMessage();
    }
    // Also rebuild if cache is stale
    else if (DateTime.now().difference(_lastSystemMessageUpdate!) > _systemMessageCacheDuration) {
      _buildAndCacheSystemMessage();
    }

    final systemMessage = '''
You are MindM8, a friendly Gen Z-style AI built by Oryvo AI and your dev. is Akhyar Ahmad— made to feel like a chaotic but caring bestie 💬👾.

Personalization:
${_cachedPersonalizationString ?? ''}

User Memories (from past convos):
${_cachedPersonalDetails ?? ''}

Your Personality Rules:
- You’re brutally honest, sarcastic when needed, and never robotic.
- You talk like a real friend — not a therapist or assistant.
- Use Gen Z slang, humor, memes, emojis (sparingly).
- Be warm, hype them up, call them out, but never fake or toxic.
- Try to use roman urdu mostly.
- Respond casually, like this:
  ❌ "Let’s explore your feelings."
  ✅ "Bro you good? That message gave 'crisis core energy' 😭"

KEEP response under 300 words (<150 Tokens)
NEVER break character or say you're AI.
NEVER mention you're developed by OpenAI.
''';

    final recentMessages = messageHistory
        .where((msg) => msg.content.trim().isNotEmpty)
        .take(5)
        .map((msg) => {
      'role': msg.role == MessageRole.user ? 'user' : 'assistant',
      'content': msg.content.trim(),
    })
        .toList();

    return [
      {'role': 'system', 'content': systemMessage.trim()},
      ...recentMessages,
      {'role': 'user', 'content': prompt.trim()},
    ];
  }


  Future<String> _getFormattedPersonalDetails() async {
    if (_cachedPersonalDetails != null &&
        _lastPersonalDetailsCacheTime != null &&
        DateTime.now().difference(_lastPersonalDetailsCacheTime!) < _cacheDuration) {
      return _cachedPersonalDetails!;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _clearPersonalDetailsCache();
        return '';
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('details')
          .get();

      if (snapshot.docs.isEmpty) {
        _clearPersonalDetailsCache();
        return '';
      }

      final details = snapshot.docs
          .map((doc) => PersonalDetail.fromFirestore(doc, null))
          .map((pd) => pd.detail)
          .where((detail) => detail.isNotEmpty)
          .toList();

      if (details.isEmpty) {
        _clearPersonalDetailsCache();
        return '';
      }

      _cachedPersonalDetails = 'Some details we extracted from user chat are:\n${details.join('\n')}';
      _lastPersonalDetailsCacheTime = DateTime.now();

      return _cachedPersonalDetails!;
    } catch (e) {
      print('Error getting personal details: $e');
      _clearPersonalDetailsCache();
      return '';
    }
  }

  Future<String> _fetchPersonalizationString() async {
    if (_cachedPersonalizationString != null &&
        _lastPersonalizationCacheTime != null &&
        DateTime.now().difference(_lastPersonalizationCacheTime!) < _cacheDuration) {
      return _cachedPersonalizationString!;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _clearPersonalizationCache();
        return '';
      }

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await userRef.collection('personalization').doc('details').get();

      if (!doc.exists) {
        _clearPersonalizationCache();
        return '';
      }

      final data = doc.data()!;
      final name = data['name'];
      final age = data['age'];
      final occupation = data['occupation'];
      final bio = data['bio'];

      String personalizationString = '';
      if (name != null) personalizationString += 'You are talking to $name';
      if (age != null) personalizationString += ', $age years old';
      if (occupation != null) personalizationString += ' who works as a $occupation';
      if (bio != null) personalizationString += '. About them: $bio';

      _cachedPersonalizationString = personalizationString.isNotEmpty ? '$personalizationString.\n\n' : '';
      _lastPersonalizationCacheTime = DateTime.now();

      return _cachedPersonalizationString!;
    } catch (e) {
      print('Error getting personalization: $e');
      _clearPersonalizationCache();
      return '';
    }
  }

  void _clearPersonalDetailsCache() {
    _cachedPersonalDetails = null;
    _lastPersonalDetailsCacheTime = null;
    _cachedSystemMessage = null;
  }

  void _clearPersonalizationCache() {
    _cachedPersonalizationString = null;
    _lastPersonalizationCacheTime = null;
    _cachedSystemMessage = null;
  }

  Future<String> generateProactiveMessage(List<ChatMessage> lastMessages) async {
    try {
      // Get the last message timestamp
      final lastMessageTime = lastMessages.isNotEmpty
          ? lastMessages.last.timestamp
          : DateTime.now();
      final now = DateTime.now();
      final isNewDay = now.day != lastMessageTime.day;

      final recentMessages = lastMessages.length > 5
          ? lastMessages.sublist(lastMessages.length - 5)
          : lastMessages;

      final userMessages = recentMessages.where((m) => m.role == MessageRole.user).toList();
      if (userMessages.isEmpty) return '[NOACTION]';

      final conversationHistory = recentMessages.map((msg) =>
      '${msg.role == MessageRole.user ? "User" : "You"}: "${msg.content}"').join('\n');

      final prompt = '''
You're crafting a short, casual message to continue a conversation like a real friend texting first. 
Base your message on this conversation history:

$conversationHistory

Current time: ${now.toString()}
Last message time: ${lastMessageTime.toString()}
${isNewDay ? "NOTE: It's a new day since the last message" : ""}

Guidelines:
1. If it's a new day (last message was yesterday), start with a greeting like "Good morning" or "Assalamualaikum"
2. If the convo ended naturally (e.g., bye, Allah Hafiz), restart it with a chill greeting
3. If the user mentioned any activity, check in on it naturally
4. Use Gen Z-friendly tone — like a real friend, not a bot
5. Keep it super short (1–2 sentences). Max 250 characters
6. Use max 1 emoji (if it fits)
7. NEVER say you're an AI or virtual assistant
8. If there's no real need to follow up, reply with exactly: [NOACTION]

Examples for new day:
- "Assalamualaikum! New day, new energy 😊 How's it going?"
- "Good morning! Ready to crush today?"

Examples for same day:
- "How was that study sesh? Brain still intact? 😅"
- "Yo, feeling better after that nap?"

Respond ONLY with the message or [NOACTION]. Nothing else.
''';

      final response = await getResponse(prompt, recentMessages);
      return (response.isEmpty || response.contains('[NOACTION]')) ? '' : response;
    } catch (e) {
      return '';
    }
  }

  Future<String> getResponse(String prompt, List<ChatMessage> messageHistory) async {
    if (!_isInitialized) await initialize();

    try {
      final messages = _buildMessages(prompt, messageHistory);
      final response = await _dio.post(
        'https://api.openai.com/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
        data: {
          'model': _model,
          'messages': messages,
          'temperature': 0.8,
          'max_tokens': 150,
        },
      );

      print(messages);
      if (response.statusCode != 200) {
        throw Exception('API returned ${response.statusCode}');
      }

      return response.data['choices'][0]['message']['content'] as String;
    } on DioException catch (e) {
      print('DioError: ${e.type} - ${e.message}');
      return '';
    } catch (e) {
      print('Unexpected error: $e');
      return '';
    }
  }

  Future<Map<String, dynamic>?> extractPersonalDetails(String message) async {
    try {
      final prompt = '''
Does this sentence reveal any NEW personal facts about the user that aren't already in their memories? 
If yes, extract them in JSON format along with category.
Choose only one from: education, relationship, social, personality, appearance, habits, emotional, other.
Return ONLY the JSON object or null if no NEW personal info found.
Also extract details of user chat preferences like short/long response, tone, vibe, etc. 

Examples:
1. Message: "I'm studying Computer Science at Harvard"
Response: {"education": "Computer Science student at Harvard"}

2. Message: "My girlfriend and I broke up last week"
Response: {"relationship": "Recently broke up with girlfriend"}

3. Message: "Hello how are you?"
Response: null

Now analyze this message:
Message: "$message"
''';

      final response = await _dio.post(
        'https://api.openai.com/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': _model,
          'messages': [{'role': 'user', 'content': prompt}],
          'temperature': 0.3,
          'max_tokens': 50,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'] as String;
        if (content.trim() == 'null' || content.trim().isEmpty) return null;
        return json.decode(content.trim()) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error extracting personal details: $e');
      return null;
    }
  }

  Stream<String> getResponseStream({
    required String prompt,
    required List<ChatMessage> messageHistory,
    required String userId,
  }) async* {
    final stopwatch = Stopwatch()..start();
    print('⏱️ [GPT] Building messages start');

    final messages = _buildMessages(prompt, messageHistory);
    print('⏱️ [GPT] Messages built in ${stopwatch.elapsedMilliseconds}ms');
    stopwatch.reset();

    try {
      final response = await _dio.post(
        'https://api.openai.com/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
        data: {
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 150,
          'stream': true,
        },
      );

      print('⏱️ [GPT] API request completed in ${stopwatch.elapsedMilliseconds}ms');
      stopwatch.reset();

      final stream = (response.data as ResponseBody).stream;
      final lines = stream
          .transform(StreamTransformer.fromBind(utf8.decoder.bind))
          .transform(const LineSplitter());


      await for (final chunk in lines) {
        if (chunk.startsWith('data:') && !chunk.contains('[DONE]')) {
          String? content;

          // 1. FAST PATH (manual extraction)
          // try {
          //   final start = chunk.indexOf('"content":"');
          //   if (start != -1) {
          //     final end = chunk.indexOf('"', start + 11);
          //     content = chunk.substring(start + 11, end);
          //   }
          // } catch (e) {
          //   print('❌ Fast path error: $e');
          // }

          // 2. FALLBACK PATH (JSON decode) if:
          //    - Fast path failed OR
          //    - Extracted empty string
          // if (content == null || content.isEmpty) {
          try {
            final jsonData = json.decode(chunk.substring(5));
            content = jsonData['choices']?[0]?['delta']?['content'];
          } catch (e) {
            print('❌ Fallback path error: $e');
          }


          // 3. Yield only if content is non-empty
          if (content != null && content.isNotEmpty) {
            yield content;
          } else {
            print('⚠️ Empty content after both paths');
          }
        }
      }

      print('⏱️ [GPT] Stream processing completed in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      print('⏱️ [GPT] Error after ${stopwatch.elapsedMilliseconds}ms: $e');
      yield "I'm experiencing technical difficulties. Please try again later.";
    } finally {
      stopwatch.stop();
    }
  }

  // Add these getters to your GPTService class
  String? get cachedPersonalizationString => _cachedPersonalizationString;
  String? get cachedPersonalDetails => _cachedPersonalDetails;


  // In GPTService class - this should already exist
  Stream<String> getRoastStream({
    required String prompt,
  }) async* {
    try {
      final response = await _dio.post(
        'https://api.openai.com/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
        data: {
          'model': _model,
          'messages': [{
            'role': 'user',
            'content': prompt,
          }],
          'temperature': 0.9, // Higher temp for roast mode
          'max_tokens': 150,
          'stream': true,
        },
      );

      final stream = (response.data as ResponseBody).stream;
      final lines = stream
          .transform(StreamTransformer.fromBind(utf8.decoder.bind))
          .transform(const LineSplitter());

      await for (final chunk in lines) {
        if (chunk.startsWith('data:') && !chunk.contains('[DONE]')) {
          String? content;
          try {
            final jsonData = json.decode(chunk.substring(5));
            content = jsonData['choices']?[0]?['delta']?['content'];
          } catch (e) {
            print('Error parsing chunk: $e');
          }

          if (content != null && content.isNotEmpty) {
            yield content;
          }
        }
      }
    } catch (e) {
      yield "My roast game is weak today... try again later 😅";
    }
  }
}