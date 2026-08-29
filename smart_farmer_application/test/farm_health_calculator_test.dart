import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farmer_application/farm_health_calculator.dart';
import 'package:smart_farmer_application/disease_detection_page.dart';
import 'package:smart_farmer_application/weather_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FarmHealthCalculator Unit Tests', () {
    test('Calculates perfect/excellent score for optimal inputs', () {
      final weather = WeatherData(
        temperature: 25.0,
        apparentTemperature: 25.0,
        humidity: 50,
        weatherCode: 0, // Clear Sky
        windSpeed: 10.0,
        windDirection: 0,
        precipitation: 0.0,
        rainProbability: 0,
        uvIndex: 4.0,
        visibility: 10.0,
        sunrise: '6:00 AM',
        sunset: '6:30 PM',
        minTempToday: 18.0,
        maxTempToday: 28.0,
        locationName: 'Pune',
      );

      final disease = DiseaseAnalysisResult(
        isHealthy: true,
        cropName: 'Tomato',
        diseaseName: 'Healthy Crop',
        confidence: 95,
        severity: 'Healthy',
        symptoms: 'Green leaves',
        recommendedSolution: 'Standard care',
        preventionTips: 'Regular inspection',
        diseaseRisk: 'Low',
      );

      final result = FarmHealthCalculator.calculate(
        cropName: 'Tomato',
        cropCondition: 'Healthy',
        soilMoisture: 'Normal',
        waterAvailability: 'Sufficient',
        soilQuality: 'Good',
        recentIrrigation: 'Irrigated Recently',
        diseaseResult: disease,
        weather: weather,
      );

      expect(result.totalScore, greaterThanOrEqualTo(95));
      expect(result.status, 'Excellent');
      expect(result.cropConditionFactor.score, 100);
      expect(result.soilMoistureFactor.score, 100);
      expect(result.waterAvailabilityFactor.score, 100);
      expect(result.soilQualityFactor.score, 100);
      expect(result.diseaseFactor.score, 100);
    });

    test('Calculates critical/poor score for stressed, diseased, and drought conditions', () {
      final weather = WeatherData(
        temperature: 42.0, // extreme heat
        apparentTemperature: 45.0,
        humidity: 90,
        weatherCode: 95, // thunderstorm
        windSpeed: 30.0, // strong wind
        windDirection: 0,
        precipitation: 20.0,
        rainProbability: 90,
        uvIndex: 11.0,
        visibility: 5.0,
        sunrise: '6:00 AM',
        sunset: '6:30 PM',
        minTempToday: 30.0,
        maxTempToday: 42.0,
        locationName: 'Vidarbha',
      );

      final disease = DiseaseAnalysisResult(
        isHealthy: false,
        cropName: 'Wheat',
        diseaseName: 'Leaf Rust',
        confidence: 90,
        severity: 'Severe',
        symptoms: 'Rust spots',
        recommendedSolution: 'Apply fungicide',
        preventionTips: 'Crop rotation',
        diseaseRisk: 'High',
      );

      final result = FarmHealthCalculator.calculate(
        cropName: 'Wheat',
        cropCondition: 'Severely Stressed',
        soilMoisture: 'Very Dry',
        waterAvailability: 'Low',
        soilQuality: 'Poor',
        recentIrrigation: 'Not Irrigated Recently',
        diseaseResult: disease,
        weather: weather,
      );

      expect(result.totalScore, lessThanOrEqualTo(25));
      expect(result.status == 'Poor' || result.status == 'Critical', isTrue);
    });

    test('Calculates accurate scores across various disease severities (Low, Moderate, Severe)', () {
      final lowDisease = DiseaseAnalysisResult(
        isHealthy: false,
        cropName: 'Maize',
        diseaseName: 'Early Blight',
        confidence: 85,
        severity: 'Low',
        symptoms: 'Minor leaf spots',
        recommendedSolution: 'Monitor closely',
        preventionTips: 'Maintain plant spacing',
        diseaseRisk: 'Low',
      );

      final modDisease = DiseaseAnalysisResult(
        isHealthy: false,
        cropName: 'Maize',
        diseaseName: 'Corn Rust',
        confidence: 88,
        severity: 'Moderate',
        symptoms: 'Visible fungal pustules',
        recommendedSolution: 'Apply fungicide',
        preventionTips: 'Sanitize equipment',
        diseaseRisk: 'Medium',
      );

      final lowScore = FarmHealthCalculator.scoreDiseaseAnalysis(lowDisease);
      final modScore = FarmHealthCalculator.scoreDiseaseAnalysis(modDisease);

      expect(lowScore, 70.0);
      expect(modScore, 40.0);
    });

    test('Handles missing/offline weather and unknown soil quality gracefully without crashing', () {
      final disease = DiseaseAnalysisResult(
        isHealthy: true,
        cropName: 'Maize',
        diseaseName: 'Healthy Crop',
        confidence: 92,
        severity: 'Healthy',
        symptoms: 'Healthy foliage',
        recommendedSolution: 'Normal watering',
        preventionTips: 'Regular monitoring',
        diseaseRisk: 'Low',
      );

      final result = FarmHealthCalculator.calculate(
        cropName: 'Maize',
        cropCondition: 'Slightly Stressed',
        soilMoisture: 'Normal',
        waterAvailability: 'Moderate',
        soilQuality: 'Don\'t Know',
        recentIrrigation: 'Irrigated a Few Days Ago',
        diseaseResult: disease,
        weather: null, // Offline
      );

      expect(result.totalScore, inInclusiveRange(60, 90));
      expect(result.weatherFactor.score, 50.0);
      expect(result.soilQualityFactor.score, 50.0);
    });

    test('Classification logic matches required score bands', () {
      expect(FarmHealthCalculator.classifyScore(95), 'Excellent');
      expect(FarmHealthCalculator.classifyScore(80), 'Excellent');
      expect(FarmHealthCalculator.classifyScore(79), 'Good');
      expect(FarmHealthCalculator.classifyScore(60), 'Good');
      expect(FarmHealthCalculator.classifyScore(59), 'Moderate');
      expect(FarmHealthCalculator.classifyScore(40), 'Moderate');
      expect(FarmHealthCalculator.classifyScore(39), 'Poor');
      expect(FarmHealthCalculator.classifyScore(20), 'Poor');
      expect(FarmHealthCalculator.classifyScore(19), 'Critical');
      expect(FarmHealthCalculator.classifyScore(0), 'Critical');
    });

    test('toFirestore contains all required fields for Firebase persistence', () {
      final disease = DiseaseAnalysisResult(
        isHealthy: false,
        cropName: 'Wheat',
        diseaseName: 'Leaf Rust',
        confidence: 88,
        severity: 'Moderate',
        symptoms: 'Rust spots',
        recommendedSolution: 'Fungicide',
        preventionTips: 'Crop rotation',
        diseaseRisk: 'Medium',
      );

      final weather = WeatherData(
        temperature: 28.0,
        apparentTemperature: 28.0,
        humidity: 65,
        weatherCode: 1,
        windSpeed: 12.0,
        windDirection: 0,
        precipitation: 0.0,
        rainProbability: 10,
        uvIndex: 5.0,
        visibility: 10.0,
        sunrise: '6:00 AM',
        sunset: '6:30 PM',
        minTempToday: 20.0,
        maxTempToday: 30.0,
        locationName: 'Nashik',
      );

      final result = FarmHealthCalculator.calculate(
        cropName: 'Wheat',
        cropCondition: 'Healthy',
        soilMoisture: 'Normal',
        waterAvailability: 'Sufficient',
        soilQuality: 'Good',
        recentIrrigation: 'Irrigated Recently',
        diseaseResult: disease,
        weather: weather,
      );

      final map = result.toFirestore();

      // Verify all minimum required persistence fields per specification
      expect(map['cropName'], 'Wheat');
      expect(map['score'], result.totalScore);
      expect(map['status'], result.status);
      expect(map['cropCondition'], 'Healthy');
      expect(map['soilMoisture'], 'Normal');
      expect(map['waterAvailability'], 'Sufficient');
      expect(map['soilQuality'], 'Good');
      expect(map['recentIrrigation'], 'Irrigated Recently');
      expect(map['diseaseName'], 'Leaf Rust');
      expect(map['diseaseSeverity'], 'Moderate');
      expect(map['diseaseConfidence'], 88);
      expect(map['diseaseScore'], 40);
      expect(map['weatherRisk'], isA<int>());
      expect(map['recommendation'], isNotEmpty);
      expect(map.containsKey('calculatedAt'), isTrue);
      expect(map.containsKey('timestamp'), isTrue);

      // Verify weather fields
      expect(map['weatherTemperature'], 28.0);
      expect(map['weatherHumidity'], 65);
      expect(map['weatherPrecipitation'], 0.0);
      expect(map['weatherWindSpeed'], 12.0);
      expect(map['weatherLocation'], 'Nashik');
    });

    test('Weights match deterministic calculation specification', () {
      expect(FarmHealthCalculator.weightCropCondition, 0.25);
      expect(FarmHealthCalculator.weightSoilMoisture, 0.20);
      expect(FarmHealthCalculator.weightWaterAvailability, 0.15);
      expect(FarmHealthCalculator.weightSoilQuality, 0.15);
      expect(FarmHealthCalculator.weightDisease, 0.15);
      expect(FarmHealthCalculator.weightWeather, 0.10);
      expect(
        FarmHealthCalculator.weightCropCondition +
            FarmHealthCalculator.weightSoilMoisture +
            FarmHealthCalculator.weightWaterAvailability +
            FarmHealthCalculator.weightSoilQuality +
            FarmHealthCalculator.weightDisease +
            FarmHealthCalculator.weightWeather,
        closeTo(1.0, 0.0001),
      );
    });
  });
}
