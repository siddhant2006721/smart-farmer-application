import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farmer_application/disease_detection_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ImageQualityChecker passes for valid crop images', () async {
    final file = File('assets/images/farmer.png');
    expect(file.existsSync(), isTrue);
    final bytes = await file.readAsBytes();

    final quality = await ImageQualityChecker.evaluate(bytes);
    expect(quality.isValid, isTrue);
    expect(quality.errorMessage, isNull);
  });

  test('DiseaseAnalysisResult correctly parses JSON output with healthy key and arrays from Gemini', () {
    final sampleJson = {
      'healthy': false,
      'cropName': 'Tomato',
      'diseaseName': 'Early Blight',
      'confidence': 92,
      'severity': 'Moderate',
      'symptoms': [
        'Brown spots on leaves',
        'Yellowing around affected areas'
      ],
      'recommendedSolution': [
        'Remove heavily affected leaves',
        'Improve field sanitation'
      ],
      'preventionTips': [
        'Avoid prolonged leaf wetness',
        'Maintain proper plant spacing'
      ],
      'diseaseRisk': 'High'
    };

    final result = DiseaseAnalysisResult.fromJson(sampleJson);
    expect(result.isHealthy, isFalse);
    expect(result.cropName, 'Tomato');
    expect(result.diseaseName, 'Early Blight');
    expect(result.confidence, 92);
    expect(result.severity, 'Moderate');
    expect(result.diseaseRisk, 'High');
    expect(result.symptoms.contains('Brown spots on leaves'), isTrue);
    expect(result.recommendedSolution.contains('Remove heavily affected leaves'), isTrue);
    expect(result.preventionTips.contains('Avoid prolonged leaf wetness'), isTrue);
  });

  test('DiseaseAnalysisResult correctly parses Healthy crop JSON with healthy: true and lists', () {
    final sampleJson = {
      'healthy': true,
      'cropName': 'Wheat',
      'diseaseName': 'Healthy Crop',
      'confidence': 96,
      'severity': 'Healthy',
      'symptoms': [
        'Lush green foliage with no fungal or bacterial lesions'
      ],
      'recommendedSolution': [
        'Continue standard irrigation and balanced fertilizer schedule'
      ],
      'preventionTips': [
        'Monitor soil moisture and scout weekly for pest activity'
      ],
      'diseaseRisk': 'Low'
    };

    final result = DiseaseAnalysisResult.fromJson(sampleJson);
    expect(result.isHealthy, isTrue);
    expect(result.cropName, 'Wheat');
    expect(result.diseaseName, 'Healthy Crop');
    expect(result.confidence, 96);
    expect(result.diseaseRisk, 'Low');
  });
}
