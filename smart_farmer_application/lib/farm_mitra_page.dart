import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:intl/intl.dart';
import 'farm_mitra_history_page.dart';
import 'weather_service.dart';
import 'market_price_service.dart';

class FarmMitraPage extends StatefulWidget {
  const FarmMitraPage({super.key});

  @override
  State<FarmMitraPage> createState() => _FarmMitraPageState();
}

class _FarmMitraPageState extends State<FarmMitraPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isLoadingHistory = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  // ============================================================
  // LOAD PREVIOUS CHAT HISTORY FROM FIRESTORE
  // ============================================================

  Future<void> _loadChatHistory() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingHistory = false);
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('farmers')
          .doc(user.uid)
          .collection('farm_mitra_chats')
          .orderBy('createdAt', descending: false)
          .get();

      final loadedMessages = <Map<String, String>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final question = (data['userMessage'] ?? data['question'] ?? '').toString().trim();
        final answer = (data['aiResponse'] ?? data['answer'] ?? '').toString().trim();
        if (question.isNotEmpty) {
          loadedMessages.add({'role': 'user', 'text': question});
        }
        if (answer.isNotEmpty) {
          loadedMessages.add({'role': 'model', 'text': answer});
        }
      }

      if (mounted) {
        setState(() {
          _messages.addAll(loadedMessages);
          _isLoadingHistory = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Farm Mitra: Failed to load history: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  void _sendMessage() async {
    if (_isLoading) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final user = _auth.currentUser;
    debugPrint('FARM_MITRA_DEBUG currentUser.uid=${user?.uid}');
    if (user == null) {
      _showError('You must be logged in to ask Farm Mitra.');
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _scrollToBottom();

    // 1. Immediately create and save chat document in Firestore BEFORE calling Gemini
    DocumentReference<Map<String, dynamic>>? docRef;
    try {
      debugPrint('[FarmMitra] Saving question...');
      debugPrint('FARM_MITRA_DEBUG: path=farmers/${user.uid}/farm_mitra_chats');
      docRef = await _firestore
          .collection('farmers')
          .doc(user.uid)
          .collection('farm_mitra_chats')
          .add({
        'userMessage': text,
        'question': text,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'userId': user.uid,
      });
      debugPrint('[FarmMitra] Firestore write successful');
      debugPrint('FARM_MITRA_DEBUG: docId=${docRef.id}');
    } on FirebaseException catch (e, st) {
      debugPrint('[FarmMitra] Firestore write failed: code=${e.code}, message=${e.message}');
      debugPrint('FARM_MITRA_DEBUG: stack=$st');
      _showError('Unable to save your message (${e.message ?? e.code}). Please check your connection and try again.');
      if (mounted) setState(() => _isLoading = false);
      return;
    } catch (e, st) {
      debugPrint('[FarmMitra] Firestore write failed: $e');
      debugPrint('FARM_MITRA_DEBUG: stack=$st');
      _showError('Unable to save your message. Please check your connection and try again.');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 2. Only AFTER user message is saved to Firestore, call Gemini AI
    try {
      debugPrint('FARM_MITRA_DEBUG: ===== Gemini call started =====');
      final answer = await _askFarmMitra(text, user);
      debugPrint('FARM_MITRA_DEBUG: Gemini responded — answerLength=${answer.length}');

      // 3. If Gemini succeeds: update the SAME chat document with AI response
      debugPrint('[FarmMitra] Saving answer...');
      try {
        await docRef.update({
          'aiResponse': answer,
          'answer': answer,
          'status': 'success',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[FarmMitra] Firestore write successful');
        debugPrint('FARM_MITRA_DEBUG: docId=${docRef.id}');
      } on FirebaseException catch (updateErr) {
        debugPrint('[FarmMitra] Firestore write failed: code=${updateErr.code}, message=${updateErr.message}');
      } catch (updateErr) {
        debugPrint('[FarmMitra] Firestore write failed: $updateErr');
      }

      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'model', 'text': answer});
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e, st) {
      debugPrint('FARM_MITRA_DEBUG: ===== Gemini request failed =====');
      debugPrint('FARM_MITRA_DEBUG: type=${e.runtimeType}');
      debugPrint('FARM_MITRA_DEBUG: error=$e');
      debugPrint('FARM_MITRA_DEBUG: stack=$st');

      final safeErrorMsg = _userFriendlyAiError(e);

      // 4. If Gemini fails: DO NOT delete user's question — update status to failed
      try {
        await docRef.update({
          'status': 'failed',
          'errorMessage': safeErrorMsg,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[FarmMitra] Status updated to failed — userMessage preserved. docId=${docRef.id}');
      } on FirebaseException catch (updateErr) {
        debugPrint('[FarmMitra] Firestore write failed: code=${updateErr.code}, message=${updateErr.message}');
      } catch (updateErr) {
        debugPrint('[FarmMitra] Firestore write failed: $updateErr');
      }

      final errorMsg = kDebugMode ? 'Farm Mitra Error: $e' : safeErrorMsg;
      _showError(errorMsg);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // REAL-TIME CONTEXT BUILDER (Date/Time, Profile, Weather, Prices)
  // ============================================================

  Future<String> _buildRealTimeContext(String question, User user) async {
    final now = DateTime.now();
    final dateStr = DateFormat('d MMMM yyyy').format(now);
    final dayStr = DateFormat('EEEE').format(now);
    final monthStr = DateFormat('MMMM').format(now);
    final yearStr = now.year.toString();
    final timeStr = DateFormat('HH:mm').format(now);
    final yesterdayStr = DateFormat('d MMMM yyyy').format(now.subtract(const Duration(days: 1)));
    final tomorrowStr = DateFormat('d MMMM yyyy').format(now.add(const Duration(days: 1)));

    final buffer = StringBuffer();
    buffer.writeln('=== REAL-TIME TEMPORAL CONTEXT (Dynamic from device) ===');
    buffer.writeln('- Current Date: $dateStr');
    buffer.writeln('- Current Day: $dayStr');
    buffer.writeln('- Current Month: $monthStr');
    buffer.writeln('- Current Year: $yearStr');
    buffer.writeln('- Current Time: $timeStr IST');
    buffer.writeln('- Yesterday was: $yesterdayStr');
    buffer.writeln('- Tomorrow is: $tomorrowStr');
    buffer.writeln();

    String farmerState = '';
    String farmerDistrict = '';
    String farmerTaluka = '';
    String farmerVillage = '';
    String farmerName = '';
    final registeredCropNames = <String>[];
    String latestHealthSummary = '';

    // Fetch Farmer Profile, Registered Crops, and Health Summary in parallel
    try {
      final results = await Future.wait([
        _firestore.collection('farmers').doc(user.uid).get().timeout(const Duration(seconds: 3)),
        _firestore.collection('farmers').doc(user.uid).collection('crops').get().timeout(const Duration(seconds: 3)),
        _firestore.collection('farmers').doc(user.uid).collection('farm_health').doc('latest').get().timeout(const Duration(seconds: 3)),
      ]);

      final profileDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      if (profileDoc.exists && profileDoc.data() != null) {
        final data = profileDoc.data()!;
        farmerName = (data['name'] ?? '').toString().trim();
        farmerState = (data['state'] ?? '').toString().trim();
        farmerDistrict = (data['district'] ?? '').toString().trim();
        farmerTaluka = (data['taluka'] ?? '').toString().trim();
        farmerVillage = (data['village'] ?? '').toString().trim();
      }

      final cropsSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      for (final doc in cropsSnap.docs) {
        final cData = doc.data();
        final cName = (cData['cropName'] ?? cData['name'] ?? '').toString().trim();
        final cVar = (cData['variety'] ?? '').toString().trim();
        if (cName.isNotEmpty) {
          registeredCropNames.add(cVar.isNotEmpty ? '$cName ($cVar)' : cName);
        }
      }

      final healthDoc = results[2] as DocumentSnapshot<Map<String, dynamic>>;
      if (healthDoc.exists && healthDoc.data() != null) {
        final hData = healthDoc.data()!;
        final cName = (hData['cropName'] ?? '').toString().trim();
        final score = hData['score']?.toString() ?? '';
        final status = (hData['status'] ?? '').toString().trim();
        final disName = (hData['diseaseName'] ?? '').toString().trim();
        final disSev = (hData['diseaseSeverity'] ?? '').toString().trim();
        if (cName.isNotEmpty) {
          latestHealthSummary = 'Crop: $cName, Health Score: $score/100 ($status), Condition: $disName ($disSev severity)';
        }
      }
    } catch (e) {
      debugPrint('FarmMitra: Profile context fetch (non-fatal): $e');
    }

    buffer.writeln('=== FARMER PROFILE & FARM CONTEXT ===');
    if (farmerName.isNotEmpty) buffer.writeln('- Farmer Name: $farmerName');
    if (farmerState.isNotEmpty || farmerDistrict.isNotEmpty) {
      buffer.writeln('- Location: ${[farmerVillage, farmerTaluka, farmerDistrict, farmerState].where((s) => s.isNotEmpty).join(', ')}');
    } else {
      buffer.writeln('- Location: Not specified in profile');
    }
    if (registeredCropNames.isNotEmpty) {
      buffer.writeln('- Registered Crops in My Crops: ${registeredCropNames.join(', ')}');
    } else {
      buffer.writeln('- Registered Crops: None registered yet');
    }
    if (latestHealthSummary.isNotEmpty) {
      buffer.writeln('- Latest Farm Health Assessment: $latestHealthSummary');
    }
    buffer.writeln();

    final cleanQ = question.toLowerCase();

    // 1. Weather Context
    final isWeatherQuery = cleanQ.contains('weather') ||
        cleanQ.contains('rain') ||
        cleanQ.contains('temperature') ||
        cleanQ.contains('humidity') ||
        cleanQ.contains('wind') ||
        cleanQ.contains('forecast') ||
        cleanQ.contains('climate') ||
        cleanQ.contains('storm') ||
        cleanQ.contains('cloud') ||
        cleanQ.contains('precipitation') ||
        cleanQ.contains('mausam') ||
        cleanQ.contains('baarish') ||
        cleanQ.contains('tavman') ||
        cleanQ.contains('varsha');

    try {
      final weather = await WeatherService.fetchWeatherForUser(user.uid).timeout(const Duration(seconds: 4));
      if (weather != null) {
        buffer.writeln('=== LIVE WEATHER DATA (from Open-Meteo API) ===');
        buffer.writeln('- Station/Location: ${weather.locationName}');
        buffer.writeln('- Current Temperature: ${weather.temperature.round()}°C (feels like ${weather.apparentTemperature.round()}°C)');
        buffer.writeln('- Current Condition: ${weather.conditionText}');
        buffer.writeln('- Relative Humidity: ${weather.humidity}%');
        buffer.writeln('- Current Precipitation: ${weather.precipitation} mm');
        buffer.writeln('- Rain Probability: ${weather.rainProbability}%');
        buffer.writeln('- Wind Speed: ${weather.windSpeed.round()} km/h (${weather.windDirectionText})');
        buffer.writeln('- Today Temperature Range: Min ${weather.minTempToday.round()}°C / Max ${weather.maxTempToday.round()}°C');
        if (weather.daily.length > 1) {
          final tmrw = weather.daily[1];
          buffer.writeln('- Tomorrow (${DateFormat('d MMMM').format(tmrw.date)}): Condition: ${getWeatherCondition(tmrw.weatherCode)}, Min ${tmrw.minTemp.round()}°C / Max ${tmrw.maxTemp.round()}°C, Rain Probability: ${tmrw.precipitationProbability}%, Rain: ${tmrw.precipitationSum} mm');
        }
        if (weather.farmingAdvices.isNotEmpty) {
          buffer.writeln('- Weather Farm Advisory: ${weather.farmingAdvices.map((a) => "${a.title}: ${a.advice}").join(" | ")}');
        }
        buffer.writeln();
      } else if (isWeatherQuery) {
        buffer.writeln('=== LIVE WEATHER DATA ===');
        buffer.writeln('STATUS: Live weather data for the farmer\'s location could NOT be retrieved at this moment.');
        buffer.writeln();
      }
    } catch (e) {
      debugPrint('FarmMitra: Weather fetch (non-fatal): $e');
      if (isWeatherQuery) {
        buffer.writeln('=== LIVE WEATHER DATA ===');
        buffer.writeln('STATUS: Live weather data for the farmer\'s location could NOT be retrieved at this moment.');
        buffer.writeln();
      }
    }

    // 2. Market Price Context
    final isPriceQuery = cleanQ.contains('price') ||
        cleanQ.contains('rate') ||
        cleanQ.contains('bhav') ||
        cleanQ.contains('mandi') ||
        cleanQ.contains('apmc') ||
        cleanQ.contains('cost') ||
        cleanQ.contains('selling') ||
        cleanQ.contains('market') ||
        cleanQ.contains('quintal') ||
        cleanQ.contains('rupee') ||
        cleanQ.contains('rs') ||
        cleanQ.contains('₹') ||
        cleanQ.contains('kimat');

    if (isPriceQuery && farmerState.isNotEmpty && farmerDistrict.isNotEmpty) {
      try {
        final records = await MarketPriceService.fetchAllRecordsForDistrict(
          state: farmerState,
          district: farmerDistrict,
        ).timeout(const Duration(seconds: 4));

        if (records.isNotEmpty) {
          final matched = <MarketPriceRecord>[];
          for (final rec in records) {
            final com = rec.commodity.toLowerCase();
            final aliases = MarketPriceService.getSearchAliases(com);
            if (cleanQ.contains(com) || aliases.any((a) => cleanQ.contains(a.toLowerCase()))) {
              matched.add(rec);
            }
          }

          if (matched.isEmpty && registeredCropNames.isNotEmpty) {
            for (final crop in registeredCropNames) {
              final cleanCrop = crop.split('(')[0].trim().toLowerCase();
              final matches = records.where((r) => r.commodity.toLowerCase().contains(cleanCrop));
              matched.addAll(matches);
            }
          }

          if (matched.isNotEmpty) {
            buffer.writeln('=== VERIFIED APMC MANDI MARKET PRICES (Agmarknet) ===');
            for (final rec in matched.take(6)) {
              buffer.writeln('- Commodity: ${rec.commodity} (${rec.variety}), Mandi: ${rec.market} (${rec.district}, ${rec.state}), Modal Price: ₹${rec.modalPrice.round()} / Quintal (Min: ₹${rec.minPrice.round()}, Max: ₹${rec.maxPrice.round()}), Arrival Date: ${rec.arrivalDate}');
            }
            buffer.writeln();
          } else {
            buffer.writeln('=== APMC MANDI MARKET PRICES ===');
            buffer.writeln('STATUS: No verified market price records found for this specific commodity in $farmerDistrict, $farmerState today.');
            buffer.writeln();
          }
        } else {
          buffer.writeln('=== APMC MANDI MARKET PRICES ===');
          buffer.writeln('STATUS: No verified APMC market price records found for $farmerDistrict, $farmerState today.');
          buffer.writeln();
        }
      } catch (e) {
        debugPrint('FarmMitra: Market price fetch (non-fatal): $e');
        buffer.writeln('=== APMC MANDI MARKET PRICES ===');
        buffer.writeln('STATUS: Real-time verified market prices could not be retrieved at this moment.');
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Calls Gemini through Firebase AI Logic (Gemini Developer API).
  /// The Gemini API key stays on Google's servers — it is never put in the app.
  Future<String> _askFarmMitra(String question, User user) async {
    final history = <Content>[];
    for (int i = 0; i < _messages.length - 1; i++) {
      final msg = _messages[i];
      final messageText = msg['text'] ?? '';
      if (messageText.isEmpty) continue;
      if (msg['role'] == 'user') {
        history.add(Content.text(messageText));
      } else {
        history.add(Content.model([TextPart(messageText)]));
      }
    }

    const primaryModel = 'gemini-3.6-flash';
    const fallbackModel = 'gemini-3.5-flash-lite';
    const modelCandidates = <String>[
      primaryModel,
      fallbackModel,
    ];

    final app = Firebase.app();
    debugPrint('FARM_MITRA_DEBUG ===== Initializing Farm Mitra AI =====');
    debugPrint('FARM_MITRA_DEBUG projectId=${app.options.projectId}');
    debugPrint('FARM_MITRA_DEBUG appId=${app.options.appId}');
    debugPrint('FARM_MITRA_DEBUG authUser=${user.uid}');
    debugPrint('FARM_MITRA_DEBUG historyTurns=${history.length}');
    debugPrint('FARM_MITRA_DEBUG primaryModel=$primaryModel fallbackModel=$fallbackModel');

    // Build rich, real-time dynamic context (date/time, profile, live weather, verified prices)
    final realTimeContext = await _buildRealTimeContext(question, user);
    final now = DateTime.now();
    final currentMonth = DateFormat('MMMM').format(now);
    final currentDate = DateFormat('d MMMM yyyy').format(now);
    final currentDay = DateFormat('EEEE').format(now);
    final currentYear = now.year.toString();

    final systemInstructionText = '''
You are Farm Mitra, a highly knowledgeable, practical, and dependable agricultural AI assistant for Indian farmers.

$realTimeContext

CORE OPERATIONAL RULES:
1. NEVER GUESS OR INVENT FACTS (ACCURACY > CONFIDENCE):
   - Farm Mitra must NEVER invent, assume, or hallucinate information.
   - If the answer is known with high confidence from verified facts or standard agronomy, answer directly and clearly.
   - If information is uncertain, unavailable, or missing, clearly say: "I don't have enough reliable information to answer that accurately."
   - Do NOT make up market prices, weather forecasts, dates, chemical dosages, pesticide formulations, government schemes, or statistics.

2. TEMPORAL ACCURACY & DATE/TIME:
   - Always use the REAL-TIME TEMPORAL CONTEXT supplied above (current date: $currentDate, current month: $currentMonth, current year: $currentYear, current day: $currentDay).
   - For "What month is now?" or "Which month is now?" -> Answer directly: "$currentMonth."
   - For "What is today's date?" -> Answer directly with today's date: "$currentDate."
   - For "What year is this?" -> Answer directly: "$currentYear."
   - For "What day is today?" -> Answer directly: "$currentDay."
   - For questions about yesterday or tomorrow, compute strictly relative to today ($currentDate).

3. WEATHER QUERIES:
   - For questions about today's or tomorrow's weather, rain, temperature, or wind, use ONLY the LIVE WEATHER DATA provided in the context above.
   - If live weather data is unavailable or could not be retrieved, explicitly state that live weather data is currently unavailable. Do NOT guess weather from general training data.

4. MARKET PRICE QUERIES:
   - For questions about crop prices, mandi rates, or APMC prices, use ONLY the VERIFIED APMC MANDI MARKET PRICES provided above.
   - If verified market price data is unavailable, explicitly state that current verified market price data is unavailable for that commodity/mandi. Never invent numbers.

5. PRACTICAL FARMING & AGRONOMY:
   - Provide sound, farmer-friendly, technically correct agronomic recommendations for crop care, fertilizer usage, irrigation, pest management, soil health, and organic farming.
   - If recommending fertilizer or pesticide: do NOT provide arbitrary, unsafe, or dangerous chemical dosages. Clearly state that exact dosage depends on the crop variety, growth stage, soil test, and product concentration, and advise following the product manufacturer's label instructions.

6. DISEASE QUERIES:
   - Clearly distinguish between a confirmed diagnosed disease (from verified image scans) versus possible causes based on verbal symptoms. Do not fabricate disease presence.

7. AMBIGUOUS QUERIES:
   - If a question is ambiguous or lacks crucial details, ask a short, polite clarification question instead of guessing.

8. LANGUAGE:
   - YOU MUST ALWAYS RESPOND IN ENGLISH, NO MATTER WHAT LANGUAGE THE USER ASKS IN.

9. RESPONSE STYLE:
   - Keep answers clear, practical, concise, well-structured, and easy for a farmer to read.
''';

    Object? lastError;
    for (final modelName in modelCandidates) {
      try {
        debugPrint('FARM_MITRA_DEBUG Calling FirebaseAI googleAI generativeModel with model=$modelName');
        final model = FirebaseAI.googleAI().generativeModel(
          model: modelName,
          systemInstruction: Content.system(systemInstructionText),
        );

        final response = await model.generateContent([
          ...history,
          Content.text(question),
        ]);
        final answer = response.text?.trim() ?? '';
        debugPrint(
          'FARM_MITRA_DEBUG Success with model=$modelName '
          'candidates=${response.candidates.length} '
          'answerLength=${answer.length}',
        );

        if (answer.isEmpty) {
          throw StateError('Farm Mitra returned an empty response from $modelName.');
        }
        return answer;
      } catch (e, st) {
        lastError = e;
        debugPrint('FARM_MITRA_DEBUG Model $modelName failed: $e');
        debugPrint('FARM_MITRA_DEBUG StackTrace: $st');
      }
    }

    throw lastError ?? StateError('Failed to get a Farm Mitra response.');
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _userFriendlyAiError(Object error) {
    final details = error.toString().toLowerCase();

    if (details.contains('app check') || details.contains('appcheck')) {
      return 'Farm Mitra could not verify this app. Please try again later.';
    }
    if (details.contains('unauthenticated') ||
        details.contains('authentication')) {
      return 'Your sign-in session has expired. Please sign in again.';
    }
    if (details.contains('not found') ||
        details.contains('not_found') ||
        details.contains('invalid model') ||
        details.contains('unsupported model') ||
        details.contains('no longer available')) {
      return 'Farm Mitra is updating its AI model. Please try again in a few moments.';
    }
    if (details.contains('empty response')) {
      return 'Farm Mitra did not return an answer. Please try again.';
    }
    if (details.contains('socket') ||
        details.contains('network') ||
        details.contains('connection') ||
        details.contains('timeout') ||
        details.contains('unavailable')) {
      return 'Unable to reach Farm Mitra. Please check your connection and try again.';
    }
    if (details.contains('quota') || details.contains('resource_exhausted') || details.contains('429')) {
      return 'Farm Mitra is temporarily busy. Please wait a moment and try again.';
    }
    if (details.contains('firebase') || details.contains('gemini')) {
      return 'Farm Mitra is temporarily unavailable. Please try again later.';
    }
    return 'Failed to get a Farm Mitra response. Please try again.';
  }

  void _showError(String errorMsg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMsg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFFB7D83D);
    const Color darkGreen = Color(0xFF17200F);
    const Color backgroundColor = Color(0xFF0F130D);
    const Color cardColor = Color(0xFF1A2117);
    const Color greyText = Color(0xFF899181);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Farm Mitra',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Ask me anything about farming.',
              style: TextStyle(
                color: Color(0xFF899181),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Chat History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FarmMitraHistoryPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // --------------------------------------------------------
          // CHAT AREA
          // --------------------------------------------------------
          Expanded(
            child: _isLoadingHistory
                // History still loading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryGreen),
                  )
                : _messages.isEmpty
                    // EMPTY STATE — welcome message
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: darkGreen,
                                ),
                                child: const Icon(
                                  Icons.support_agent_outlined,
                                  color: primaryGreen,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Hello! I am Farm Mitra.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Ask me anything about farming.\nI\'m here to help you grow better.',
                                style: TextStyle(
                                  color: greyText,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              // Example question chips
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  'Which fertilizer for wheat?',
                                  'How to control pests?',
                                  'When to irrigate crops?',
                                  'Improve soil health?',
                                ]
                                    .map(
                                      (q) => GestureDetector(
                                        onTap: () {
                                          _messageController.text = q;
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: cardColor,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: primaryGreen
                                                  .withValues(alpha: 0.25),
                                            ),
                                          ),
                                          child: Text(
                                            q,
                                            style: const TextStyle(
                                              color: primaryGreen,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      )
                    // MESSAGE LIST
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isUser = message['role'] == 'user';
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 12.0),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.78,
                              ),
                              decoration: BoxDecoration(
                                color: isUser ? primaryGreen : cardColor,
                                borderRadius:
                                    BorderRadius.circular(16).copyWith(
                                  bottomRight: isUser
                                      ? const Radius.circular(0)
                                      : const Radius.circular(16),
                                  bottomLeft: isUser
                                      ? const Radius.circular(16)
                                      : const Radius.circular(0),
                                ),
                              ),
                              child: Text(
                                message['text'] ?? '',
                                style: TextStyle(
                                  color: isUser ? darkGreen : Colors.white,
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // --------------------------------------------------------
          // AI THINKING INDICATOR
          // --------------------------------------------------------
          if (_isLoading)
            const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: primaryGreen,
                      strokeWidth: 2.2,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Farm Mitra is thinking...',
                      style: TextStyle(color: greyText, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // --------------------------------------------------------
          // INPUT BAR
          // --------------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0, vertical: 12.0),
            decoration: const BoxDecoration(
              color: cardColor,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _isLoading ? null : _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type your farming question...',
                      hintStyle:
                          const TextStyle(color: Color(0xFF899181)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: backgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 14.0),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isLoading ? null : _sendMessage,
                  child: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: _isLoading ? greyText : primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send,
                      color: _isLoading ? Colors.white38 : darkGreen,
                    ),
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

