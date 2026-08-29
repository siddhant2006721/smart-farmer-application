import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';

import 'my_crops_page.dart';
import 'weather_service.dart';
import 'disease_detection_page.dart';
import 'farm_health_calculator.dart';
import 'notification_service.dart';

// ============================================================
// FARM HEALTH ASSESSMENT PAGE
// ============================================================

class FarmHealthPage extends StatefulWidget {
  final String? preselectedCropName;

  const FarmHealthPage({
    super.key,
    this.preselectedCropName,
  });

  @override
  State<FarmHealthPage> createState() => _FarmHealthPageState();
}

class _FarmHealthPageState extends State<FarmHealthPage> {
  // Theme Colors
  static const Color _bg = Color(0xFF0F130D);
  static const Color _card = Color(0xFF1A2117);
  static const Color _card2 = Color(0xFF20291B);
  static const Color _accent = Color(0xFFB7D83D);
  static const Color _darkAccent = Color(0xFF17200F);
  static const Color _grey = Color(0xFF899181);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // ------------------------------------------------------------
  // STATE VARIABLES
  // ------------------------------------------------------------
  bool _isLoadingInitialData = true;
  List<CropModel> _userCrops = [];
  CropModel? _selectedCrop;
  WeatherData? _weatherData;
  bool _weatherLoading = true;

  // Question Inputs
  String? _selectedCropCondition;
  String? _selectedSoilMoisture;
  String? _selectedWaterAvailability;
  String? _selectedSoilQuality;
  String? _selectedRecentIrrigation;

  // Photo & Disease Analysis (Mandatory)
  Uint8List? _imageBytes;
  bool _isCheckingQuality = false;
  String? _qualityErrorMessage;
  bool _isAnalyzingDisease = false;
  String? _diseaseAnalysisError;
  DiseaseAnalysisResult? _diseaseResult;

  // Calculation State
  bool _isCalculating = false;
  String _calculatingStatusText = 'Evaluating farm parameters...';
  FarmHealthCalculationResult? _calculationResult;

  // ------------------------------------------------------------
  // OPTIONS DEFINITIONS
  // ------------------------------------------------------------
  static const List<String> _cropConditionOptions = [
    'Healthy',
    'Slightly Stressed',
    'Moderately Stressed',
    'Severely Stressed',
  ];

  static const List<String> _soilMoistureOptions = [
    'Very Wet',
    'Normal',
    'Dry',
    'Very Dry',
  ];

  static const List<String> _waterAvailabilityOptions = [
    'Sufficient',
    'Moderate',
    'Low',
  ];

  static const List<String> _soilQualityOptions = [
    'Good',
    'Average',
    'Poor',
    'Don\'t Know',
  ];

  static const List<String> _recentIrrigationOptions = [
    'Irrigated Recently',
    'Irrigated a Few Days Ago',
    'Not Irrigated Recently',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // ------------------------------------------------------------
  // INITIAL DATA LOADING (Crops & Weather)
  // ------------------------------------------------------------
  Future<void> _loadInitialData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoadingInitialData = false);
      }
      return;
    }

    List<CropModel> crops = [];
    WeatherData? weather;

    // â”€â”€ 1. Fetch user crops from Firestore â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // Primary: ordered query (requires index). Fallback: unordered if index
    // is missing or Firestore hangs. Both protected by a 10-second timeout.
    try {
      final cropsSnap = await _firestore
          .collection('farmers')
          .doc(user.uid)
          .collection('crops')
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 10));
      crops = cropsSnap.docs.map((doc) => CropModel.fromFirestore(doc)).toList();
    } catch (primaryErr) {
      debugPrint('FarmHealthPage: Ordered crops fetch failed ($primaryErr). Trying fallback...');
      // Fallback: fetch without orderBy (no composite index required)
      try {
        final fallbackSnap = await _firestore
            .collection('farmers')
            .doc(user.uid)
            .collection('crops')
            .get()
            .timeout(const Duration(seconds: 8));
        crops = fallbackSnap.docs.map((doc) => CropModel.fromFirestore(doc)).toList();
      } catch (fallbackErr) {
        debugPrint('FarmHealthPage: Fallback crops fetch also failed ($fallbackErr). Crops will be empty.');
        crops = [];
      }
    }

    // â”€â”€ 2. Fetch live weather (non-blocking â€” failure is safe) â”€â”€
    try {
      weather = await WeatherService.fetchWeatherForUser(user.uid);
    } catch (weatherErr) {
      debugPrint('FarmHealthPage: Weather fetch failed ($weatherErr). Proceeding without weather.');
      weather = null;
    }

    if (mounted) {
      setState(() {
        _userCrops = crops;
        _weatherData = weather;
        _weatherLoading = false;
        _isLoadingInitialData = false;

        // Select preselected crop if specified, or first available crop
        if (widget.preselectedCropName != null && widget.preselectedCropName!.isNotEmpty) {
          _selectedCrop = crops.firstWhere(
            (c) => c.name.toLowerCase() == widget.preselectedCropName!.toLowerCase(),
            orElse: () => crops.isNotEmpty ? crops.first : CropModel(id: '', name: widget.preselectedCropName!),
          );
        } else if (crops.isNotEmpty) {
          _selectedCrop = crops.first;
        }
      });
    }
  }

  // ------------------------------------------------------------
  // IMAGE PICKING & AI ANALYSIS (MANDATORY FOR CURRENT CROP)
  // ------------------------------------------------------------
  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (status.isPermanentlyDenied) {
          _showPermissionDialog('Camera');
          return;
        }
        if (!status.isGranted && !status.isLimited) {
          _showSnackBar('Camera permission is required to capture crop leaf photo.');
          return;
        }
      }

      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );

      if (picked == null) return;
      final bytes = await picked.readAsBytes();

      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _qualityErrorMessage = null;
        _diseaseAnalysisError = null;
        _diseaseResult = null;
        _isCheckingQuality = true;
      });

      // Step 1: Image Quality Validation
      final quality = await ImageQualityChecker.evaluate(bytes);
      if (!mounted) return;

      if (!quality.isValid) {
        setState(() {
          _isCheckingQuality = false;
          _qualityErrorMessage = quality.errorMessage ?? 'Photo is too blurry or dark. Please capture a clearer photo.';
        });
        return;
      }

      // Step 2: Image Quality Passed -> Run Gemini AI Disease Analysis for CURRENT selected crop
      setState(() {
        _isCheckingQuality = false;
        _isAnalyzingDisease = true;
      });

      await _analyzeDiseaseWithGemini(bytes);
    } catch (e) {
      debugPrint('FarmHealthPage: Image error: $e');
      if (!mounted) return;
      setState(() {
        _isCheckingQuality = false;
        _isAnalyzingDisease = false;
        _diseaseAnalysisError = 'Could not process image. Please retake or choose a clearer photo.';
      });
    }
  }

  void _showPermissionDialog(String feature) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$feature Permission Needed',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '$feature permission is required to take crop photos. Please enable it in device settings.',
          style: const TextStyle(color: _grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings', style: TextStyle(color: _accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x42 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  Future<void> _analyzeDiseaseWithGemini(Uint8List bytes) async {
    final mimeType = _detectMimeType(bytes);
    const primaryModel = 'gemini-3.6-flash';
    const fallbackModel = 'gemini-3.5-flash-lite';
    const modelCandidates = [primaryModel, fallbackModel];

    final targetCrop = _selectedCrop?.name ?? 'Crop Plant';

    final systemPrompt = '''
You are an expert plant pathologist assessing a photo for a farm health check.
The farmer has specified this crop is: "$targetCrop".
Analyze the provided leaf/plant photo carefully for the crop "$targetCrop".
Determine whether the crop is healthy or affected by a plant disease, fungal infection, nutrient deficiency, or pest damage.

Respond ONLY with a valid JSON object in this exact schema without markdown backticks or commentary:
{
  "healthy": true or false,
  "cropName": "$targetCrop",
  "diseaseName": "Specific disease/pest name if diseased (e.g. Early Blight, Leaf Rust, Powdery Mildew, Anthracnose, Leaf Curl) or 'Healthy Crop' if healthy",
  "confidence": integer percentage between 70 and 99,
  "severity": "Low" or "Moderate" or "Severe" or "Healthy",
  "symptoms": [
    "Short symptom point 1",
    "Short symptom point 2"
  ],
  "recommendedSolution": [
    "Actionable crop protection step 1",
    "Actionable crop protection step 2"
  ],
  "preventionTips": [
    "Prevention tip 1"
  ],
  "diseaseRisk": "Low" or "Medium" or "High"
}
''';

    try {
      final token = await FirebaseAppCheck.instance.getToken(true);
      debugPrint('FarmHealth: AppCheck token status: ${token != null ? "obtained" : "empty"}');
    } catch (_) {}

    Object? lastError;

    for (final modelName in modelCandidates) {
      try {
        final model = FirebaseAI.googleAI().generativeModel(
          model: modelName,
          systemInstruction: Content.system(systemPrompt),
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.2,
          ),
        );

        final response = await model.generateContent([
          Content.multi([
            TextPart('Analyze this leaf/crop photo for disease and health status for the crop $targetCrop.'),
            InlineDataPart(mimeType, bytes),
          ]),
        ]);

        final responseText = response.text?.trim() ?? '';
        if (responseText.isEmpty) throw StateError('Empty response from $modelName');

        String cleanedJson = responseText;
        if (cleanedJson.contains('```json')) {
          cleanedJson = cleanedJson.split('```json')[1].split('```')[0].trim();
        } else if (cleanedJson.contains('```')) {
          cleanedJson = cleanedJson.split('```')[1].split('```')[0].trim();
        }
        final firstBrace = cleanedJson.indexOf('{');
        final lastBrace = cleanedJson.lastIndexOf('}');
        if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
          cleanedJson = cleanedJson.substring(firstBrace, lastBrace + 1);
        }

        final parsed = jsonDecode(cleanedJson) as Map<String, dynamic>;
        final diseaseResult = DiseaseAnalysisResult.fromJson(parsed);

        if (!mounted) return;
        setState(() {
          _diseaseResult = diseaseResult;
          _isAnalyzingDisease = false;
          _diseaseAnalysisError = null;
        });

        // Save to disease_detections collection
        final user = _auth.currentUser;
        if (user != null) {
          try {
            await _firestore
                .collection('farmers')
                .doc(user.uid)
                .collection('disease_detections')
                .add(diseaseResult.toFirestore(user.uid));
          } catch (_) {}
        }
        return;
      } catch (e) {
        lastError = e;
        debugPrint('FarmHealth: Gemini error with $modelName: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _isAnalyzingDisease = false;
      _diseaseAnalysisError = 'Could not analyze crop photo with AI ($lastError). Please retake or choose another photo.';
    });
  }

  // ------------------------------------------------------------
  // GEMINI RECOMMENDATIONS GENERATOR
  // ------------------------------------------------------------
  Future<List<String>> _generateGeminiRecommendations({
    required String cropName,
    required int score,
    required String status,
    required String cropCondition,
    required String soilMoisture,
    required String waterAvailability,
    required String soilQuality,
    required String recentIrrigation,
    required DiseaseAnalysisResult diseaseResult,
    WeatherData? weather,
  }) async {
    final weatherDesc = weather != null
        ? '${weather.temperature.round()}Â°C, humidity ${weather.humidity}%, rainfall ${weather.precipitation}mm, wind ${weather.windSpeed.round()} km/h (${weather.conditionText})'
        : 'Weather unavailable';

    final diseaseDesc = diseaseResult.isHealthy
        ? 'Healthy crop'
        : '${diseaseResult.diseaseName} (${diseaseResult.severity} severity, ${diseaseResult.confidence}% confidence)';

    final prompt = '''
You are an expert agronomist. Provide 3 to 4 concise, highly actionable, farmer-friendly recommendations for a farmer growing $cropName based on these assessed conditions:

- Calculated Farm Health Score: $score/100 ($status)
- Visual Crop Condition: $cropCondition
- Soil Moisture: $soilMoisture
- Water Availability: $waterAvailability
- Soil Quality: $soilQuality
- Recent Irrigation: $recentIrrigation
- AI Disease Analysis: $diseaseDesc
- Live Weather: $weatherDesc

Respond ONLY with a valid JSON array of 3 or 4 concise strings, like:
[
  "Direct actionable step 1...",
  "Direct actionable step 2...",
  "Direct actionable step 3..."
]
Do not include markdown fences, code blocks or extra text.
''';

    const modelCandidates = ['gemini-3.6-flash', 'gemini-3.5-flash-lite'];

    for (final modelName in modelCandidates) {
      try {
        final model = FirebaseAI.googleAI().generativeModel(
          model: modelName,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.3,
          ),
        );

        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text?.trim() ?? '';
        if (text.isNotEmpty) {
          String cleaned = text;
          if (cleaned.contains('```json')) {
            cleaned = cleaned.split('```json')[1].split('```')[0].trim();
          } else if (cleaned.contains('```')) {
            cleaned = cleaned.split('```')[1].split('```')[0].trim();
          }
          final firstB = cleaned.indexOf('[');
          final lastB = cleaned.lastIndexOf(']');
          if (firstB != -1 && lastB != -1 && lastB > firstB) {
            cleaned = cleaned.substring(firstB, lastB + 1);
          }

          final list = (jsonDecode(cleaned) as List).map((e) => e.toString().trim()).toList();
          if (list.isNotEmpty) {
            return list;
          }
        }
      } catch (e) {
        debugPrint('FarmHealth: Gemini recommendations error with $modelName: $e');
      }
    }

    // Return deterministic fallback recommendations if AI recommendations fail
    return FarmHealthCalculator.calculate(
      cropName: cropName,
      cropCondition: cropCondition,
      soilMoisture: soilMoisture,
      waterAvailability: waterAvailability,
      soilQuality: soilQuality,
      recentIrrigation: recentIrrigation,
      diseaseResult: diseaseResult,
      weather: weather,
    ).recommendations;
  }

  // ------------------------------------------------------------
  // CALCULATION EXECUTION & FIRESTORE SAVE
  // ------------------------------------------------------------
  Future<void> _executeCalculation() async {
    // 1. Validation for Crop Selection
    if (_selectedCrop == null) {
      _showValidationAlert('Please select a crop from your registered My Crops.');
      return;
    }

    // 2. Validation for Assessment Questions
    if (_selectedCropCondition == null) {
      _showValidationAlert('Please answer: How is your crop currently?');
      return;
    }
    if (_selectedSoilMoisture == null) {
      _showValidationAlert('Please answer: How is the soil moisture?');
      return;
    }
    if (_selectedWaterAvailability == null) {
      _showValidationAlert('Please answer: How is water availability for this crop?');
      return;
    }
    if (_selectedSoilQuality == null) {
      _showValidationAlert('Please answer: How is the soil quality?');
      return;
    }
    if (_selectedRecentIrrigation == null) {
      _showValidationAlert('Please answer: When was this crop irrigated recently?');
      return;
    }

    // 3. Validation for Crop Photo (Mandatory)
    if (_imageBytes == null) {
      _showValidationAlert('Please upload a clear crop photo to analyze crop health before calculating the Farm Health Score.');
      return;
    }

    if (_isCheckingQuality || _isAnalyzingDisease) {
      _showValidationAlert('Crop photo is currently being analyzed by AI. Please wait a moment.');
      return;
    }

    if (_qualityErrorMessage != null) {
      _showValidationAlert('Image quality check failed: $_qualityErrorMessage. Please take or select a clearer photo.');
      return;
    }

    if (_diseaseResult == null || _diseaseAnalysisError != null) {
      _showValidationAlert('AI Disease Analysis could not be completed for the uploaded photo. Please retake or choose a clearer photo of the crop leaf.');
      return;
    }

    // Auth check â€” must be logged in before starting (Firestore save cannot be skipped)
    final user = _auth.currentUser;
    if (user == null) {
      _showValidationAlert('You must be logged in to calculate and save your Farm Health Score. Please sign in and try again.');
      return;
    }

    debugPrint('[FarmHealth] Calculating score...');
    debugPrint('FARM_HEALTH_DEBUG: crop=${_selectedCrop!.name} uid=${user.uid}');

    setState(() {
      _isCalculating = true;
      _calculatingStatusText = 'Evaluating crop and soil parameters...';
    });

    try {
      // Refresh weather data if needed
      if (_weatherData == null) {
        setState(() => _calculatingStatusText = 'Fetching live local weather...');
        _weatherData = await WeatherService.fetchWeatherForUser(_auth.currentUser?.uid);
      }

      setState(() => _calculatingStatusText = 'Computing deterministic score...');

      // 4. Deterministic Dart Calculation (Source of truth)
      final initialResult = FarmHealthCalculator.calculate(
        cropName: _selectedCrop!.name,
        cropVariety: _selectedCrop!.variety,
        cropCondition: _selectedCropCondition!,
        soilMoisture: _selectedSoilMoisture!,
        waterAvailability: _selectedWaterAvailability!,
        soilQuality: _selectedSoilQuality!,
        recentIrrigation: _selectedRecentIrrigation!,
        diseaseResult: _diseaseResult!,
        weather: _weatherData,
      );

      debugPrint('[FarmHealth] Score calculated: ${initialResult.totalScore} (${initialResult.status})');
      debugPrint('FARM_HEALTH_DEBUG: disease=${initialResult.diseaseName} severity=${initialResult.diseaseSeverity}');

      setState(() => _calculatingStatusText = 'Generating smart recommendations...');

      // 5. AI Recommendations
      final smartRecommendations = await _generateGeminiRecommendations(
        cropName: _selectedCrop!.name,
        score: initialResult.totalScore,
        status: initialResult.status,
        cropCondition: _selectedCropCondition!,
        soilMoisture: _selectedSoilMoisture!,
        waterAvailability: _selectedWaterAvailability!,
        soilQuality: _selectedSoilQuality!,
        recentIrrigation: _selectedRecentIrrigation!,
        diseaseResult: _diseaseResult!,
        weather: _weatherData,
      );

      final finalResult = FarmHealthCalculationResult(
        cropName: initialResult.cropName,
        cropVariety: initialResult.cropVariety,
        totalScore: initialResult.totalScore,
        status: initialResult.status,
        summary: initialResult.summary,
        cropConditionFactor: initialResult.cropConditionFactor,
        soilMoistureFactor: initialResult.soilMoistureFactor,
        waterAvailabilityFactor: initialResult.waterAvailabilityFactor,
        soilQualityFactor: initialResult.soilQualityFactor,
        diseaseFactor: initialResult.diseaseFactor,
        weatherFactor: initialResult.weatherFactor,
        recentIrrigation: initialResult.recentIrrigation,
        diseaseName: initialResult.diseaseName,
        diseaseSeverity: initialResult.diseaseSeverity,
        diseaseConfidence: initialResult.diseaseConfidence,
        isDiseaseHealthy: initialResult.isDiseaseHealthy,
        weatherInfo: initialResult.weatherInfo,
        recommendations: smartRecommendations,
      );

      // â”€â”€ FIRESTORE SAVE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      // MUST succeed BEFORE showing the result as successfully completed.
      // Full .set() overwrite â€” no merge â€” so recalculating for a different
      // crop fully replaces the previous result (Tomato completely replaces Wheat).
      // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      setState(() => _calculatingStatusText = 'Saving result to Firebase...');

      final docData = finalResult.toFirestore();
      docData['calculatedAt'] = FieldValue.serverTimestamp();
      docData['timestamp'] = FieldValue.serverTimestamp();
      docData['uid'] = user.uid;

      debugPrint('[FarmHealth] Saving latest result...');
      debugPrint('FARM_HEALTH_DEBUG: Firestore save started â€” path: farmers/${user.uid}/farm_health/latest');
      debugPrint('FARM_HEALTH_DEBUG: saving cropName=${docData['cropName']} score=${docData['score']}');

      try {
        // Full overwrite â€” previous crop result is completely replaced
        await _firestore
            .collection('farmers')
            .doc(user.uid)
            .collection('farm_health')
            .doc('latest')
            .set(docData);

        debugPrint('[FarmHealth] Firestore write successful');
        debugPrint('FARM_HEALTH_DEBUG: Document confirmed at farmers/${user.uid}/farm_health/latest');
      } on FirebaseException catch (e, fsSt) {
        debugPrint('[FarmHealth] Firestore write failed: code=${e.code}, message=${e.message}');
        debugPrint('FARM_HEALTH_DEBUG: stack=$fsSt');

        if (mounted) {
          setState(() => _isCalculating = false);
          _showSnackBar(
            'Farm Health Score was calculated but could not be saved (${e.message ?? e.code}). Please try again.',
          );
        }
        return; // Stop here â€” do NOT continue to show the success UI
      } catch (firestoreError, fsSt) {
        debugPrint('[FarmHealth] Firestore write failed: $firestoreError');
        debugPrint('FARM_HEALTH_DEBUG: stack=$fsSt');

        if (mounted) {
          setState(() => _isCalculating = false);
          // Do NOT show success result â€” save failed
          _showSnackBar(
            'Farm Health Score was calculated but could not be saved. Please try again.',
          );
        }
        return; // Stop here â€” do NOT continue to show the success UI
      }
      // â”€â”€ END FIRESTORE SAVE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

      // Optional: trigger notification for critical/poor scores (non-fatal if notification fails)
      if (finalResult.totalScore < 40) {
        try {
          await NotificationService.addNotification(
            user.uid,
            title: 'Farm Health Alert: ${finalResult.cropName}',
            message: '${finalResult.cropName} scored ${finalResult.totalScore}/100 (${finalResult.status}). Review immediate management steps.',
            type: 'disease',
            targetPage: 'dashboard',
          );
        } catch (notifErr) {
          debugPrint('FARM_HEALTH_DEBUG: Notification send failed (non-fatal): $notifErr');
        }
      }

      // Show success result ONLY after Firestore save is confirmed
      if (!mounted) return;
      setState(() {
        _isCalculating = false;
        _calculationResult = finalResult;
      });
    } catch (e, st) {
      debugPrint('FARM_HEALTH_DEBUG: ===== Calculation error (pre-save stage) =====');
      debugPrint('FARM_HEALTH_DEBUG: type=${e.runtimeType}');
      debugPrint('FARM_HEALTH_DEBUG: error=$e');
      debugPrint('FARM_HEALTH_DEBUG: stack=$st');
      if (mounted) {
        setState(() => _isCalculating = false);
        _showSnackBar('An error occurred during farm health calculation. Please try again.');
      }
    }
  }

  void _showValidationAlert(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _accent, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Input Required',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFFC9B4B6), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: _accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _resetAssessment() {
    setState(() {
      _calculationResult = null;
      _selectedCropCondition = null;
      _selectedSoilMoisture = null;
      _selectedWaterAvailability = null;
      _selectedSoilQuality = null;
      _selectedRecentIrrigation = null;
      _imageBytes = null;
      _diseaseResult = null;
      _diseaseAnalysisError = null;
      _qualityErrorMessage = null;
    });
  }

  // ============================================================
  // BUILD METHOD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoadingInitialData
                  ? const Center(
                      child: CircularProgressIndicator(color: _accent),
                    )
                  : _isCalculating
                      ? _buildCalculatingView()
                      : _calculationResult != null
                          ? _buildResultView()
                          : _buildAssessmentForm(),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE57373),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.favorite_rounded, color: Color(0xFF24181A), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farm Health Score',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  'Crop Health & Risk Assessment',
                  style: TextStyle(
                    color: _grey,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // CALCULATING LOADING VIEW
  // ------------------------------------------------------------
  Widget _buildCalculatingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _card,
                border: Border.all(color: _accent.withValues(alpha: 0.3)),
              ),
              child: const Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    color: _accent,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Calculating Farm Health Score',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _calculatingStatusText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ASSESSMENT FORM VIEW
  // ------------------------------------------------------------
  Widget _buildAssessmentForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Crop Selector â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _buildCropSelectorSection(),
          const SizedBox(height: 18),

          // â”€â”€ Assessment Questions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _buildQuestionCard(
            questionNumber: 'A',
            title: 'Crop Condition',
            subtitle: 'How is your crop currently?',
            options: _cropConditionOptions,
            selectedValue: _selectedCropCondition,
            onSelected: (val) => setState(() => _selectedCropCondition = val),
            icon: Icons.eco_rounded,
          ),
          const SizedBox(height: 16),

          _buildQuestionCard(
            questionNumber: 'B',
            title: 'Soil Moisture',
            subtitle: 'How is the soil moisture?',
            options: _soilMoistureOptions,
            selectedValue: _selectedSoilMoisture,
            onSelected: (val) => setState(() => _selectedSoilMoisture = val),
            icon: Icons.water_drop_rounded,
          ),
          const SizedBox(height: 16),

          _buildQuestionCard(
            questionNumber: 'C',
            title: 'Water Availability',
            subtitle: 'How is water availability for this crop?',
            options: _waterAvailabilityOptions,
            selectedValue: _selectedWaterAvailability,
            onSelected: (val) => setState(() => _selectedWaterAvailability = val),
            icon: Icons.waves_rounded,
          ),
          const SizedBox(height: 16),

          _buildQuestionCard(
            questionNumber: 'D',
            title: 'Soil Quality',
            subtitle: 'How is the soil quality?',
            options: _soilQualityOptions,
            selectedValue: _selectedSoilQuality,
            onSelected: (val) => setState(() => _selectedSoilQuality = val),
            icon: Icons.landscape_rounded,
          ),
          const SizedBox(height: 16),

          _buildQuestionCard(
            questionNumber: 'E',
            title: 'Recent Irrigation',
            subtitle: 'When was this crop irrigated recently?',
            options: _recentIrrigationOptions,
            selectedValue: _selectedRecentIrrigation,
            onSelected: (val) => setState(() => _selectedRecentIrrigation = val),
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(height: 18),

          // â”€â”€ Crop Photo & AI Disease Scan (Section F - Mandatory) â”€
          _buildCropPhotoSection(),
          const SizedBox(height: 18),

          // â”€â”€ Auto Weather Preview Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _buildWeatherPreviewCard(),
          const SizedBox(height: 24),

          // â”€â”€ Calculate Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _executeCalculation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: const Color(0xFF11140F),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.health_and_safety_rounded, size: 22),
                  SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Calculate Farm Health Score',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // CROP SELECTOR SECTION
  // ------------------------------------------------------------
  Widget _buildCropSelectorSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _darkAccent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.grass_rounded, color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Crop for Assessment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Choose from your registered My Crops',
                      style: TextStyle(
                        color: _grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_userCrops.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No crops found in My Crops.',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Please add your crops to My Crops first to calculate an accurate health score.',
                    style: TextStyle(color: _grey, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyCropsPage()),
                      ).then((_) => _loadInitialData());
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Crop in My Crops'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xFF11140F),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            )
          else
            InputDecorator(
              decoration: InputDecoration(
                filled: true,
                fillColor: _card2,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _accent.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _accent.withValues(alpha: 0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _accent, width: 1.5),
                ),
              ),
              child: DropdownButton<CropModel>(
                value: _selectedCrop,
                dropdownColor: _card2,
                borderRadius: BorderRadius.circular(16),
                isExpanded: true,
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _accent),
                items: _userCrops.map((crop) {
                  return DropdownMenuItem<CropModel>(
                    value: crop,
                    child: Row(
                      children: [
                        const Icon(Icons.eco_outlined, color: _accent, size: 18),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            crop.variety.isNotEmpty ? '${crop.name} (${crop.variety})' : crop.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (newCrop) {
                  if (newCrop != null) {
                    setState(() {
                      _selectedCrop = newCrop;
                      // Reset image and disease result when changing crop
                      _imageBytes = null;
                      _diseaseResult = null;
                      _diseaseAnalysisError = null;
                      _qualityErrorMessage = null;
                    });
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // QUESTION CARD COMPONENT
  // ------------------------------------------------------------
  Widget _buildQuestionCard({
    required String questionNumber,
    required String title,
    required String subtitle,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selectedValue != null ? _accent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selectedValue != null ? _accent : _darkAccent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accent.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    questionNumber,
                    style: TextStyle(
                      color: selectedValue != null ? const Color(0xFF11140F) : _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: _accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: _grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),

          // Options Grid / Wrap
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = selectedValue == option;
              return InkWell(
                onTap: () => onSelected(option),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? _accent : _card2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _accent : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF11140F) : Colors.white,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTION F: CROP PHOTO & AI DISEASE DETECTION (MANDATORY)
  // ------------------------------------------------------------
  Widget _buildCropPhotoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _diseaseResult != null
              ? _accent.withValues(alpha: 0.35)
              : _diseaseAnalysisError != null || _qualityErrorMessage != null
                  ? Colors.redAccent.withValues(alpha: 0.4)
                  : _accent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _diseaseResult != null ? _accent : _darkAccent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accent.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    'F',
                    style: TextStyle(
                      color: _diseaseResult != null ? const Color(0xFF11140F) : _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.camera_alt_rounded, color: _accent, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Crop Photo & Disease AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Take or upload a clear photo of ${_selectedCrop?.name ?? 'the selected crop'} for mandatory AI disease health analysis.',
            style: const TextStyle(
              color: _grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18, color: _accent),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Take Photo', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _card2,
                    side: BorderSide(color: _accent.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18, color: _accent),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Gallery', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _card2,
                    side: BorderSide(color: _accent.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          // Photo Preview & Status
          if (_imageBytes != null || _isCheckingQuality || _isAnalyzingDisease || _diseaseResult != null || _diseaseAnalysisError != null || _qualityErrorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _card2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _diseaseResult != null
                      ? _accent.withValues(alpha: 0.3)
                      : _diseaseAnalysisError != null || _qualityErrorMessage != null
                          ? Colors.redAccent.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _imageBytes!,
                        width: 55,
                        height: 55,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        color: _darkAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.biotech_rounded, color: _accent),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isCheckingQuality)
                          const Row(
                            children: [
                              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: _accent, strokeWidth: 1.8)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Validating image quality...', style: TextStyle(color: _grey, fontSize: 12)),
                              ),
                            ],
                          )
                        else if (_isAnalyzingDisease)
                          const Row(
                            children: [
                              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: _accent, strokeWidth: 1.8)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Gemini AI analyzing leaf...', style: TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          )
                        else if (_qualityErrorMessage != null) ...[
                          Text(_qualityErrorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                          const SizedBox(height: 4),
                          const Text('Please tap above to retake photo.', style: TextStyle(color: _grey, fontSize: 10)),
                        ] else if (_diseaseResult != null) ...[
                          Row(
                            children: [
                              Icon(
                                _diseaseResult!.isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
                                color: _diseaseResult!.isHealthy ? _accent : const Color(0xFFFFA726),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _diseaseResult!.diseaseName,
                                  style: TextStyle(
                                    color: _diseaseResult!.isHealthy ? _accent : const Color(0xFFFFA726),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Crop: ${_diseaseResult!.cropName} â€¢ Severity: ${_diseaseResult!.severity} â€¢ Confidence: ${_diseaseResult!.confidence}%',
                            style: const TextStyle(color: _grey, fontSize: 11),
                            softWrap: true,
                          ),
                        ] else if (_diseaseAnalysisError != null) ...[
                          Text(_diseaseAnalysisError!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                          const SizedBox(height: 4),
                          const Text('Please tap above to retake or choose another photo.', style: TextStyle(color: _grey, fontSize: 10)),
                        ],
                      ],
                    ),
                  ),
                  if (_imageBytes != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _grey, size: 18),
                      onPressed: () {
                        setState(() {
                          _imageBytes = null;
                          _diseaseResult = null;
                          _diseaseAnalysisError = null;
                          _qualityErrorMessage = null;
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // AUTO WEATHER PREVIEW CARD
  // ------------------------------------------------------------
  Widget _buildWeatherPreviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _darkAccent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withValues(alpha: 0.2)),
            ),
            child: Icon(
              _weatherData?.weatherIcon ?? Icons.cloud_outlined,
              color: _accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Live Weather Factor',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '10% Weight',
                        style: TextStyle(color: _accent, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_weatherLoading)
                  const Text('Fetching local weather...', style: TextStyle(color: _grey, fontSize: 11))
                else if (_weatherData != null)
                  Text(
                    '${_weatherData!.temperature.round()}Â°C â€¢ ${_weatherData!.conditionText} â€¢ ${_weatherData!.locationName} (Humidity ${_weatherData!.humidity}%)',
                    style: const TextStyle(color: _grey, fontSize: 11),
                    softWrap: true,
                  )
                else
                  const Text('Standard neutral weather baseline applied.', style: TextStyle(color: _grey, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // RESULT VIEW
  // ------------------------------------------------------------
  Widget _buildResultView() {
    final res = _calculationResult!;
    final statusColor = FarmHealthCalculator.getStatusColor(res.status);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Main Score Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  statusColor.withValues(alpha: 0.18),
                  _card,
                ],
              ),
              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                // Crop Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _darkAccent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.eco_rounded, color: _accent, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          res.cropVariety != null && res.cropVariety!.isNotEmpty
                              ? '${res.cropName} (${res.cropVariety})'
                              : res.cropName,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Circle Score Indicator
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: res.totalScore / 100,
                          strokeWidth: 10,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          color: statusColor,
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${res.totalScore}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                          const Text(
                            '/ 100',
                            style: TextStyle(
                              color: _grey,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    res.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  res.summary,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _grey, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // â”€â”€ Contributing Factors Breakdown â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          const Text(
            'Contributing Factor Breakdown',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          ...res.allFactors.map((factor) => _buildFactorTile(factor)),
          const SizedBox(height: 22),

          // â”€â”€ Recommendations Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _accent.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_rounded, color: _accent, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Actionable Recommendations',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...res.recommendations.map((rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rec,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // â”€â”€ Action Buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetAssessment,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _accent.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Assess Another Crop',
                      style: TextStyle(color: _accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: const Color(0xFF11140F),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Back to Dashboard',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // FACTOR BREAKDOWN TILE
  // ------------------------------------------------------------
  Widget _buildFactorTile(HealthFactorDetail factor) {
    final factorColor = factor.score >= 80
        ? _accent
        : factor.score >= 60
            ? const Color(0xFF8BC34A)
            : factor.score >= 40
                ? const Color(0xFFFFB74D)
                : const Color(0xFFEF5350);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(factor.icon, color: _accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  factor.title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: factorColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${factor.score.round()}/100 (${(factor.weight * 100).round()}%)',
                  style: TextStyle(color: factorColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: factor.score / 100,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: factorColor,
                    minHeight: 5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${factor.selectedValue} â€¢ ${factor.statusDescription}',
            style: const TextStyle(color: _grey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

