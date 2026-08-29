import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'notification_service.dart';
import 'disease_history_page.dart';

// ============================================================
// IMAGE QUALITY CHECKER (PURE DART VALIDATION)
// ============================================================

class ImageQualityResult {
  final bool isValid;
  final String? errorMessage;

  const ImageQualityResult.valid()
      : isValid = true,
        errorMessage = null;

  const ImageQualityResult.invalid(this.errorMessage) : isValid = false;
}

class ImageQualityChecker {
  /// Evaluates the image bytes for resolution, corrupt data, excessive darkness,
  /// overexposure/glare, and severe blur before sending to AI.
  static Future<ImageQualityResult> evaluate(Uint8List imageBytes) async {
    if (imageBytes.isEmpty || imageBytes.lengthInBytes < 2048) {
      return const ImageQualityResult.invalid(
        'The selected image is empty or invalid. Please take a clear photo of the crop.',
      );
    }

    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;

      final width = image.width;
      final height = image.height;

      if (width < 80 || height < 80) {
        return const ImageQualityResult.invalid(
          'Image resolution is too low. Please upload a clearer, higher-resolution photo of the crop.',
        );
      }

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        return const ImageQualityResult.valid();
      }

      final buffer = byteData.buffer.asUint8List();
      final totalPixels = width * height;
      if (totalPixels <= 0) {
        return const ImageQualityResult.invalid('Invalid image data.');
      }

      // Sample up to 8,000 pixels evenly spaced for fast validation
      final step = (totalPixels / 8000).clamp(1, 100).toInt();
      double totalLuminance = 0;
      int sampleCount = 0;
      int veryDarkPixels = 0;
      int veryBrightPixels = 0;

      for (int i = 0; i < totalPixels; i += step) {
        final offset = i * 4;
        if (offset + 2 < buffer.length) {
          final r = buffer[offset];
          final g = buffer[offset + 1];
          final b = buffer[offset + 2];
          final lum = 0.299 * r + 0.587 * g + 0.114 * b;
          totalLuminance += lum;
          sampleCount++;
          if (lum < 20) veryDarkPixels++;
          if (lum > 245) veryBrightPixels++;
        }
      }

      if (sampleCount > 0) {
        final avgLuminance = totalLuminance / sampleCount;

        // Extremely dark image check
        if (avgLuminance < 25 || (veryDarkPixels / sampleCount) > 0.88) {
          return const ImageQualityResult.invalid(
            'The image is too dark to clearly see the plant or leaf. Please take a photo in brighter, natural lighting.',
          );
        }

        // Extremely bright / washed out check
        if (avgLuminance > 238 || (veryBrightPixels / sampleCount) > 0.88) {
          return const ImageQualityResult.invalid(
            'The image is overexposed or too bright with glare. Please capture a photo without direct flash or harsh reflection.',
          );
        }
      }

      // Blur / Edge Contrast check on sampled grid
      double totalGradient = 0;
      int gradientSamples = 0;
      final rowStep = (height / 50).clamp(1, 50).toInt();
      final colStep = (width / 50).clamp(1, 50).toInt();

      for (int y = 0; y < height - rowStep; y += rowStep) {
        for (int x = 0; x < width - colStep; x += colStep) {
          final idx1 = (y * width + x) * 4;
          final idx2 = (y * width + (x + colStep)) * 4;
          final idx3 = ((y + rowStep) * width + x) * 4;

          if (idx3 + 2 < buffer.length && idx2 + 2 < buffer.length) {
            final lum1 = 0.299 * buffer[idx1] + 0.587 * buffer[idx1 + 1] + 0.114 * buffer[idx1 + 2];
            final lum2 = 0.299 * buffer[idx2] + 0.587 * buffer[idx2 + 1] + 0.114 * buffer[idx2 + 2];
            final lum3 = 0.299 * buffer[idx3] + 0.587 * buffer[idx3 + 1] + 0.114 * buffer[idx3 + 2];

            final diffX = (lum1 - lum2).abs();
            final diffY = (lum1 - lum3).abs();
            totalGradient += (diffX + diffY);
            gradientSamples++;
          }
        }
      }

      if (gradientSamples > 40) {
        final avgGradient = totalGradient / gradientSamples;
        if (avgGradient < 1.6) {
          return const ImageQualityResult.invalid(
            'The image appears very blurry or out of focus. Please hold the camera steady and capture a clear photo.',
          );
        }
      }

      return const ImageQualityResult.valid();
    } catch (e) {
      // In case of unexpected decoding failure, return valid to allow AI to attempt analysis
      return const ImageQualityResult.valid();
    }
  }
}

// ============================================================
// DISEASE DETECTION RESULT DATA MODEL
// ============================================================

class DiseaseAnalysisResult {
  final bool isHealthy;
  final String cropName;
  final String diseaseName;
  final int confidence;
  final String severity; // Low, Moderate, Severe, Healthy
  final String symptoms;
  final String recommendedSolution;
  final String preventionTips;
  final String diseaseRisk; // Low, Medium, High

  DiseaseAnalysisResult({
    required this.isHealthy,
    required this.cropName,
    required this.diseaseName,
    required this.confidence,
    required this.severity,
    required this.symptoms,
    required this.recommendedSolution,
    required this.preventionTips,
    required this.diseaseRisk,
  });

  static String _parseFieldToString(dynamic val, String fallback) {
    if (val == null) return fallback;
    if (val is List) {
      final items = val
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (items.isEmpty) return fallback;
      return items.map((e) => '• $e').join('\n');
    }
    final str = val.toString().trim();
    return str.isNotEmpty ? str : fallback;
  }

  factory DiseaseAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawHealthy = json['healthy'] ?? json['isHealthy'];
    final bool isHealthy = rawHealthy is bool
        ? rawHealthy
        : (rawHealthy.toString().toLowerCase() == 'true');

    final rawConfidence = json['confidence'];
    int confidenceVal = 92;
    if (rawConfidence is num) {
      confidenceVal = rawConfidence.toInt().clamp(50, 99);
    } else if (rawConfidence is String) {
      final parsed = int.tryParse(rawConfidence.replaceAll(RegExp(r'[^0-9]'), ''));
      if (parsed != null) confidenceVal = parsed.clamp(50, 99);
    }

    final rawCrop = (json['cropName'] ?? '').toString().trim();
    final cropName = rawCrop.isNotEmpty ? rawCrop : 'Crop Plant';

    final rawDisease = (json['diseaseName'] ?? '').toString().trim();
    final diseaseName = rawDisease.isNotEmpty
        ? rawDisease
        : (isHealthy ? 'Healthy Crop' : 'Plant Disease');

    final rawSeverity = (json['severity'] ?? '').toString().trim();
    String severity = rawSeverity.isNotEmpty ? rawSeverity : (isHealthy ? 'Healthy' : 'Moderate');
    if (!isHealthy && (severity.toLowerCase() == 'none' || severity.toLowerCase() == 'healthy')) {
      severity = 'Low';
    }

    final rawRisk = (json['diseaseRisk'] ?? json['risk'] ?? '').toString().trim();
    final diseaseRisk = rawRisk.isNotEmpty ? rawRisk : (isHealthy ? 'Low' : 'Medium');

    final symptoms = _parseFieldToString(
      json['symptoms'],
      isHealthy
          ? 'Leaves and stems appear green, intact, and free from noticeable lesions or fungal spots.'
          : 'Visible discoloration, spotting, or leaf damage detected on the plant.',
    );

    final recommendedSolution = _parseFieldToString(
      json['recommendedSolution'] ?? json['solution'],
      isHealthy
          ? 'Maintain standard watering, balanced fertilization, and monitor crops periodically.'
          : 'Isolate affected plants if feasible. Apply locally recommended organic or approved fungicide/pesticide following label instructions.',
    );

    final preventionTips = _parseFieldToString(
      json['preventionTips'] ?? json['prevention'],
      'Ensure good air circulation, avoid overhead watering late in the evening, and maintain healthy soil nutrition.',
    );

    return DiseaseAnalysisResult(
      isHealthy: isHealthy,
      cropName: cropName,
      diseaseName: diseaseName,
      confidence: confidenceVal,
      severity: severity,
      symptoms: symptoms,
      recommendedSolution: recommendedSolution,
      preventionTips: preventionTips,
      diseaseRisk: diseaseRisk,
    );
  }

  Map<String, dynamic> toFirestore(String userId) {
    return {
      'userId': userId,
      'isHealthy': isHealthy,
      'cropName': cropName,
      'diseaseName': diseaseName,
      'confidence': confidence,
      'severity': severity,
      'symptoms': symptoms,
      'recommendedSolution': recommendedSolution,
      'preventionTips': preventionTips,
      'diseaseRisk': diseaseRisk,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// ============================================================
// DISEASE DETECTION SCREEN
// ============================================================

class DiseaseDetectionPage extends StatefulWidget {
  const DiseaseDetectionPage({super.key});

  @override
  State<DiseaseDetectionPage> createState() => _DiseaseDetectionPageState();
}

class _DiseaseDetectionPageState extends State<DiseaseDetectionPage> {
  // Theme Colors
  static const Color _bg = Color(0xFF0F130D);
  static const Color _card = Color(0xFF1A2117);
  static const Color _card2 = Color(0xFF20291B);
  static const Color _accent = Color(0xFFB7D83D);
  static const Color _darkAccent = Color(0xFF17200F);
  static const Color _grey = Color(0xFF899181);

  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Uint8List? _imageBytes;

  bool _isCheckingQuality = false;
  String? _qualityErrorMessage;

  bool _isAnalyzing = false;
  String? _analysisErrorMessage;

  DiseaseAnalysisResult? _result;
  bool _savedToFirestore = false;

  // ============================================================
  // IMAGE PICKING & FLOW
  // ============================================================

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Permission checking
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (status.isPermanentlyDenied) {
          _showPermissionDialog('Camera');
          return;
        }
        if (!status.isGranted && !status.isLimited) {
          _showSnackBar('Camera access is required to capture photos of crop leaves.');
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
        _analysisErrorMessage = null;
        _result = null;
        _savedToFirestore = false;
        _isCheckingQuality = true;
      });

      // ── Step 1: Image Quality Validation ────────────────────
      final qualityResult = await ImageQualityChecker.evaluate(bytes);

      if (!mounted) return;

      if (!qualityResult.isValid) {
        setState(() {
          _isCheckingQuality = false;
          _qualityErrorMessage = qualityResult.errorMessage ??
              'The image quality is insufficient. Please upload a clearer image of the affected crop/leaf.';
        });
        return;
      }

      // ── Step 2: Quality is GOOD → Directly run AI Analysis ───
      setState(() {
        _isCheckingQuality = false;
        _isAnalyzing = true;
      });

      await _analyzeWithGemini(bytes);
    } catch (e, stackTrace) {
      debugPrint('========== DISEASE AI ERROR ==========');
      debugPrint('Stage: image picking / quality / analysis wrapper');
      debugPrint('Exception: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('======================================');
      if (mounted) {
        setState(() {
          _isCheckingQuality = false;
          _isAnalyzing = false;
          _analysisErrorMessage = 'Unable to process the image right now. Please try again.';
        });
      }
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
          '$feature permission is needed to select crop photos. Please enable it in device settings.',
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

  // ============================================================
  // MIME TYPE DETECTOR
  // ============================================================

  String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
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

  // ============================================================
  // AI DISEASE ANALYSIS VIA FIREBASE AI LOGIC
  // ============================================================

  Future<void> _analyzeWithGemini(Uint8List bytes) async {
    final user = _auth.currentUser;
    final mimeType = _detectMimeType(bytes);
    final firebaseApp = Firebase.app();

    const primaryModel = 'gemini-3.6-flash';
    const fallbackModel = 'gemini-3.5-flash-lite';
    const modelCandidates = <String>[
      primaryModel,
      fallbackModel,
    ];

    const systemPrompt = '''
You are an expert plant pathologist and agricultural extension specialist assisting a farmer.
Analyze the provided image of the plant leaf, crop, or stem carefully.
Determine whether the crop is healthy or affected by a plant disease or pest.

Respond ONLY with a valid JSON object in this exact schema without markdown backticks or commentary:
{
  "healthy": true or false,
  "cropName": "Crop name (e.g. Tomato, Wheat, Rice, Potato, Cotton, Maize, etc.)",
  "diseaseName": "Specific disease name if diseased (e.g. Early Blight, Powdery Mildew, Leaf Rust) or 'Healthy Crop' if no disease",
  "confidence": integer percentage between 70 and 99,
  "severity": "Low" or "Moderate" or "Severe" or "Healthy",
  "symptoms": [
    "Simple farmer-friendly bullet 1",
    "Simple farmer-friendly bullet 2"
  ],
  "recommendedSolution": [
    "Actionable crop management step 1. If chemical protection is mentioned, instruct the farmer to use only locally approved products and follow the product label and agricultural-extension guidance. Never recommend unsafe pesticide dosages.",
    "Actionable crop management step 2"
  ],
  "preventionTips": [
    "Practical prevention step 1",
    "Practical prevention step 2"
  ],
  "diseaseRisk": "Low" or "Medium" or "High"
}
Always use clear, simple, farmer-friendly English.
''';

    debugPrint('DISEASE_DEBUG ===== Starting Disease Analysis =====');
    debugPrint('DISEASE_DEBUG projectId=${firebaseApp.options.projectId}');
    debugPrint('DISEASE_DEBUG appId=${firebaseApp.options.appId}');
    debugPrint('DISEASE_DEBUG user=${user?.uid}');
    debugPrint('DISEASE_DEBUG imageBytes=${bytes.lengthInBytes} bytes');
    debugPrint('DISEASE_DEBUG detectedMimeType=$mimeType');
    debugPrint('DISEASE_DEBUG primaryModel=$primaryModel fallbackModel=$fallbackModel');

    await _refreshAppCheckTokenForAi();

    Object? lastError;

    for (final modelName in modelCandidates) {
      try {
        debugPrint('DISEASE_DEBUG calling FirebaseAI googleAI generativeModel model=$modelName');
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
            TextPart(
              'Analyze this plant leaf or crop image for disease and health status. '
              'Return the analysis strictly as structured JSON.',
            ),
            InlineDataPart(mimeType, bytes),
          ]),
        ]);

        final responseText = response.text?.trim() ?? '';
        debugPrint('DISEASE_DEBUG firebasevertexai request succeeded for model=$modelName');
        debugPrint('DISEASE_DEBUG candidates=${response.candidates.length}');
        if (response.candidates.isNotEmpty) {
          debugPrint(
            'DISEASE_DEBUG finishReason=${response.candidates.first.finishReason} '
            'finishMessage=${response.candidates.first.finishMessage}',
          );
        }
        debugPrint('DISEASE_DEBUG promptFeedback=${response.promptFeedback}');
        debugPrint('DISEASE_DEBUG model=$modelName response length=${responseText.length}');
        debugPrint('DISEASE_DEBUG rawResponse: $responseText');

        if (responseText.isEmpty) {
          throw StateError('Empty AI response from $modelName');
        }

        // Clean possible markdown fences
        String cleanedJson = responseText;
        if (cleanedJson.contains('```json')) {
          cleanedJson = cleanedJson.split('```json')[1].split('```')[0].trim();
        } else if (cleanedJson.contains('```')) {
          cleanedJson = cleanedJson.split('```')[1].split('```')[0].trim();
        }

        // Extract outer JSON block if wrapped
        final firstBrace = cleanedJson.indexOf('{');
        final lastBrace = cleanedJson.lastIndexOf('}');
        if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
          cleanedJson = cleanedJson.substring(firstBrace, lastBrace + 1);
        }

        final Map<String, dynamic> parsedMap = jsonDecode(cleanedJson) as Map<String, dynamic>;
        final analysisResult = DiseaseAnalysisResult.fromJson(parsedMap);

        debugPrint('DISEASE_DEBUG analysis parsed successfully: crop=${analysisResult.cropName}, disease=${analysisResult.diseaseName}, isHealthy=${analysisResult.isHealthy}, severity=${analysisResult.severity}');

        if (!mounted) return;

        setState(() {
          _result = analysisResult;
          _isAnalyzing = false;
          _analysisErrorMessage = null;
        });

        // ── Save to Firestore ─────────────────────────────────
        if (user != null) {
          await _saveResultAndNotify(user.uid, analysisResult);
        }

        return;
      } catch (e, st) {
        lastError = e;
        _logDiseaseAiError(
          modelName: modelName,
          mimeType: mimeType,
          bytes: bytes,
          error: e,
          stackTrace: st,
        );
      }
    }

    debugPrint('========== DISEASE AI FINAL FAILURE ==========');
    debugPrint('Tried models: $modelCandidates');
    debugPrint('Last error: $lastError');
    debugPrint('==============================================');

    if (!mounted) return;

    setState(() {
      _isAnalyzing = false;
      _analysisErrorMessage = _friendlyErrorMessage(lastError);
    });
  }

  Future<void> _refreshAppCheckTokenForAi() async {
    try {
      final token = await FirebaseAppCheck.instance.getToken(true);
      final present = token != null && token.isNotEmpty;
      debugPrint('DISEASE_DEBUG App Check status: ${present ? 'token_obtained' : 'empty_token'}');
      debugPrint('DISEASE_DEBUG App Check token length=${token?.length ?? 0}');
    } catch (e, st) {
      debugPrint('========== DISEASE AI ERROR ==========');
      debugPrint('App Check getToken(true) failed before Gemini request');
      debugPrint('Exception: $e');
      debugPrint('StackTrace: $st');
      if (e is FirebaseException) {
        debugPrint('FirebaseException code: ${e.code}');
        debugPrint('FirebaseException message: ${e.message}');
        debugPrint('FirebaseException details: ${e.toString()}');
      }
      debugPrint('======================================');
    }
  }

  void _logDiseaseAiError({
    required String modelName,
    required String mimeType,
    required Uint8List bytes,
    required Object error,
    required StackTrace stackTrace,
  }) {
    final details = error.toString();
    final httpStatus = _extractHttpStatus(details);

    debugPrint('========== DISEASE AI ERROR ==========');
    debugPrint('Model: $modelName');
    debugPrint('MIME: $mimeType');
    debugPrint('Image bytes: ${bytes.length}');
    debugPrint('Exception type: ${error.runtimeType}');
    debugPrint('HTTP status: ${httpStatus ?? 'unknown'}');
    debugPrint('Exception: $error');
    debugPrint('StackTrace: $stackTrace');
    debugPrint('======================================');

    if (error is FirebaseException) {
      debugPrint('FirebaseException code: ${error.code}');
      debugPrint('FirebaseException message: ${error.message}');
      debugPrint('FirebaseException details: ${error.toString()}');
    }
    if (error is FirebaseAIException) {
      debugPrint('FirebaseAIException message: ${error.message}');
    }
  }

  String? _extractHttpStatus(String details) {
    final bracket = RegExp(r'\[(\d{3})\]').firstMatch(details);
    if (bracket != null) return bracket.group(1);
    final code = RegExp(r'code:\s*(\d{3})').firstMatch(details);
    if (code != null) return code.group(1);
    final status = RegExp(r'status(?:Code)?:\s*(\d{3})', caseSensitive: false)
        .firstMatch(details);
    if (status != null) return status.group(1);
    return null;
  }

  String _friendlyErrorMessage(Object? error) {
    if (error == null) return 'Unable to analyze the image right now. Please try again.';
    final details = error.toString().toLowerCase();

    if (details.contains('app check') || details.contains('appcheck') || details.contains('attestation')) {
      return 'AI verification is not ready. Please try again after app verification is completed.';
    }
    if (details.contains('network') ||
        details.contains('socket') ||
        details.contains('connection') ||
        details.contains('timeout') ||
        details.contains('failed host lookup')) {
      return 'Internet connection is unavailable. Please check your connection and try again.';
    }
    if (details.contains('serviceapinotenabled') ||
        details.contains('not enabled') ||
        details.contains('firebase ai logic') ||
        details.contains('firebasevertexai')) {
      return 'Firebase AI Logic is not enabled. Please enable it in the Firebase Console.';
    }
    if (details.contains('format') ||
        details.contains('json') ||
        details.contains('unexpected character') ||
        details.contains('empty response')) {
      return 'Unable to interpret the AI result. Please try the scan again.';
    }
    if (details.contains('quota') || details.contains('resource_exhausted') || details.contains('429')) {
      return 'AI analysis is temporarily busy. Please wait a moment and try again.';
    }
    return 'AI analysis is temporarily unavailable. Please try again later.';
  }

  // ============================================================
  // FIRESTORE SAVE & NOTIFICATION TRIGGER
  // ============================================================

  Future<void> _saveResultAndNotify(String userId, DiseaseAnalysisResult res) async {
    try {
      await _firestore
          .collection('farmers')
          .doc(userId)
          .collection('disease_detections')
          .add(res.toFirestore(userId));

      if (mounted) {
        setState(() => _savedToFirestore = true);
      }

      // Trigger Crop Alert notification for Moderate or Severe disease
      if (!res.isHealthy) {
        final sev = res.severity.toLowerCase();
        if (sev == 'moderate' || sev == 'severe' || sev == 'high') {
          await NotificationService.addNotification(
            userId,
            title: 'Crop Alert: ${res.diseaseName}',
            message: 'Crop Alert: ${res.diseaseName} detected in your ${res.cropName} crop. Review the recommended management steps.',
            type: 'disease',
            targetPage: 'disease_detection',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save disease detection to Firestore: $e');
    }
  }

  void _resetFlow() {
    setState(() {
      _imageBytes = null;
      _qualityErrorMessage = null;
      _analysisErrorMessage = null;
      _result = null;
      _savedToFirestore = false;
      _isCheckingQuality = false;
      _isAnalyzing = false;
    });
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':
      case 'high':
        return const Color(0xFFEF5350);
      case 'moderate':
      case 'medium':
        return const Color(0xFFFFA726);
      case 'low':
        return const Color(0xFFFFEE58);
      default:
        return _accent;
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

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
              color: _accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.biotech_rounded, color: _darkAccent, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disease Detection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'AI Crop Health Scanner',
                  style: TextStyle(
                    color: _grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiseaseHistoryPage()),
              );
            },
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _accent.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.history_rounded, color: _accent, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'History',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

  // ============================================================
  // MAIN BODY CONTENT
  // ============================================================

  Widget _buildContent() {
    // 1. Initial State: No Image Selected
    if (_imageBytes == null) {
      return _buildInitialPickerView();
    }

    // 2. Loading State: Checking Quality or AI Analyzing
    if (_isCheckingQuality || _isAnalyzing) {
      return _buildLoadingView();
    }

    // 3. Bad Quality State: Quality check failed
    if (_qualityErrorMessage != null) {
      return _buildQualityErrorView();
    }

    // 4. Analysis Error State
    if (_analysisErrorMessage != null) {
      return _buildAnalysisErrorView();
    }

    // 5. Result State: AI Analysis Complete
    if (_result != null) {
      return _buildResultView();
    }

    return _buildInitialPickerView();
  }

  // ============================================================
  // 1. INITIAL PICKER VIEW
  // ============================================================

  Widget _buildInitialPickerView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Intro Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _accent.withValues(alpha: 0.14)),
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
                    ),
                    child: const Icon(Icons.eco_rounded, color: _accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Instant Crop Health Scan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Detect crop infections, fungal spots, and plant health issues with automated smart disease analysis.',
                style: TextStyle(color: _grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              _buildTipItem('Hold camera steady and focus on the affected leaf or stem'),
              const SizedBox(height: 8),
              _buildTipItem('Ensure adequate, natural daytime lighting'),
              const SizedBox(height: 8),
              _buildTipItem('Avoid extreme darkness or direct bright flash reflections'),
            ],
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          'Select Image Source',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Take Photo',
                subtitle: 'Capture with camera',
                icon: Icons.camera_alt_rounded,
                isPrimary: true,
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'Upload Image',
                subtitle: 'Choose from gallery',
                icon: Icons.photo_library_rounded,
                isPrimary: false,
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // History Quick Access Card
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DiseaseHistoryPage()),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: const Row(
              children: [
                Icon(Icons.history_edu_rounded, color: _accent, size: 24),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View Detection History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Browse previous crop scans & diagnoses',
                        style: TextStyle(color: _grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: _grey, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(Icons.check_circle_outline_rounded, color: _accent, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isPrimary ? _darkAccent : _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary ? _accent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
            width: isPrimary ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPrimary ? _accent : _card2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isPrimary ? _darkAccent : _accent,
                size: 24,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: _grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 2. LOADING VIEW
  // ============================================================

  Widget _buildLoadingView() {
    final statusText = _isCheckingQuality
        ? 'Checking image clarity & lighting...'
        : 'AI analyzing crop for diseases...';

    return Column(
      children: [
        _buildImagePreview(showOverlayBadge: true, badgeText: 'Analyzing'),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: _accent,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isCheckingQuality ? 'Image Quality Check' : 'Disease Analysis in Progress',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _grey, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 3. QUALITY ERROR VIEW
  // ============================================================

  Widget _buildQualityErrorView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImagePreview(showOverlayBadge: true, badgeText: 'Quality Issue', isError: true),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF281C1C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Image Quality Insufficient',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _qualityErrorMessage ??
                    'Please upload a clearer, well-lit photo of the affected crop or leaf.',
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Try again with a better photo:',
          style: TextStyle(color: _grey, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Retake Image'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: _darkAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Upload Another'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // 4. ANALYSIS ERROR VIEW
  // ============================================================

  Widget _buildAnalysisErrorView() {
    return Column(
      children: [
        _buildImagePreview(),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 36),
              const SizedBox(height: 12),
              const Text(
                'Analysis Incomplete',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _analysisErrorMessage ?? 'Unable to analyze the image right now. Please try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetFlow,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_imageBytes != null) {
                          setState(() {
                            _isAnalyzing = true;
                            _analysisErrorMessage = null;
                          });
                          _analyzeWithGemini(_imageBytes!);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: _darkAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Try Again'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 5. RESULT VIEW (HEALTHY VS DISEASED)
  // ============================================================

  Widget _buildResultView() {
    final res = _result!;
    final isHealthy = res.isHealthy;
    final sevColor = _getSeverityColor(res.severity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image thumbnail bar with change image action
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: Image.memory(
                    _imageBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crop: ${res.cropName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          isHealthy ? Icons.check_circle_rounded : Icons.warning_rounded,
                          color: isHealthy ? _accent : sevColor,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            isHealthy ? 'Appears Healthy' : 'Disease Detected',
                            style: TextStyle(
                              color: isHealthy ? _accent : sevColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: _grey, size: 22),
                tooltip: 'Scan another plant',
                onPressed: _resetFlow,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Primary Health Status Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isHealthy ? _darkAccent : const Color(0xFF271C1B),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isHealthy
                  ? _accent.withValues(alpha: 0.4)
                  : Colors.redAccent.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isHealthy ? _card : const Color(0xFF381F1F),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isHealthy ? _accent : Colors.redAccent,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isHealthy ? Icons.eco_rounded : Icons.coronavirus_outlined,
                      color: isHealthy ? _accent : Colors.redAccent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHealthy ? 'Healthy Crop' : 'Disease Detected',
                          style: TextStyle(
                            color: isHealthy ? _accent : const Color(0xFFFF8A80),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          res.diseaseName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isHealthy) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Crop appears healthy. No significant disease symptoms detected.',
                            style: TextStyle(color: _grey, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Metrics Chips: Confidence, Severity, Risk
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildResultChip(
                    'Confidence',
                    '${res.confidence}%',
                    Icons.verified_outlined,
                    _accent,
                  ),
                  if (!isHealthy)
                    _buildResultChip(
                      'Severity',
                      res.severity,
                      Icons.warning_amber_rounded,
                      sevColor,
                    ),
                  _buildResultChip(
                    'Disease Risk',
                    res.diseaseRisk,
                    Icons.shield_outlined,
                    isHealthy ? _accent : _getSeverityColor(res.diseaseRisk),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Symptoms Section
        _buildInfoCard(
          title: 'Symptoms Observed',
          icon: Icons.visibility_outlined,
          content: res.symptoms,
        ),

        const SizedBox(height: 14),

        // Recommended Solution Section
        _buildInfoCard(
          title: isHealthy ? 'Care & Maintenance' : 'Recommended Solution',
          icon: Icons.medical_services_outlined,
          content: res.recommendedSolution,
          accentColor: isHealthy ? _accent : const Color(0xFFFFB74D),
        ),

        const SizedBox(height: 14),

        // Prevention Tips Section
        _buildInfoCard(
          title: 'Prevention Tips',
          icon: Icons.health_and_safety_outlined,
          content: res.preventionTips,
        ),

        const SizedBox(height: 16),

        // Advisory Note
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: _accent, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Instructions: Use only locally approved agricultural products. Always follow the product label instructions and local agricultural extension guidance.',
                  style: TextStyle(color: _grey, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Action Buttons: Scan Another & History
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _resetFlow,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Scan Another Plant'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: _darkAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DiseaseHistoryPage()),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('History'),
            ),
          ],
        ),

        if (_savedToFirestore) ...[
          const SizedBox(height: 12),
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done_rounded, color: _accent, size: 14),
                SizedBox(width: 6),
                Text(
                  'Result saved to your Detection History',
                  style: TextStyle(color: _grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(color: _grey, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required String content,
    Color? accentColor,
  }) {
    final effectiveAccent = accentColor ?? _accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: effectiveAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // IMAGE PREVIEW COMPONENT
  // ============================================================

  Widget _buildImagePreview({
    bool showOverlayBadge = false,
    String? badgeText,
    bool isError = false,
  }) {
    if (_imageBytes == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isError
              ? Colors.redAccent.withValues(alpha: 0.5)
              : _accent.withValues(alpha: 0.25),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              _imageBytes!,
              fit: BoxFit.cover,
            ),
            if (showOverlayBadge && badgeText != null)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isError
                        ? Colors.red.withValues(alpha: 0.85)
                        : _darkAccent.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isError ? Colors.redAccent : _accent,
                    ),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: isError ? Colors.white : _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
