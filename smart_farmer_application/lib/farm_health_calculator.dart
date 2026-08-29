import 'package:flutter/material.dart';
import 'weather_service.dart';
import 'disease_detection_page.dart';

// ============================================================
// FARM HEALTH FACTOR RESULT
// ============================================================

class HealthFactorDetail {
  final String title;
  final String selectedValue;
  final double score; // 0 to 100
  final double weight; // e.g. 0.25
  final double weightedScore;
  final String statusDescription;
  final IconData icon;

  const HealthFactorDetail({
    required this.title,
    required this.selectedValue,
    required this.score,
    required this.weight,
    required this.weightedScore,
    required this.statusDescription,
    required this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'selectedValue': selectedValue,
      'score': score.round(),
      'weight': weight,
      'weightedScore': double.parse(weightedScore.toStringAsFixed(1)),
      'statusDescription': statusDescription,
    };
  }
}

// ============================================================
// COMPLETE FARM HEALTH CALCULATION RESULT
// ============================================================

class FarmHealthCalculationResult {
  final String cropName;
  final String? cropVariety;
  final int totalScore; // 0 to 100
  final String status; // Excellent, Good, Moderate, Poor, Critical
  final String summary;
  final HealthFactorDetail cropConditionFactor;
  final HealthFactorDetail soilMoistureFactor;
  final HealthFactorDetail waterAvailabilityFactor;
  final HealthFactorDetail soilQualityFactor;
  final HealthFactorDetail diseaseFactor;
  final HealthFactorDetail weatherFactor;
  final String recentIrrigation;
  final String diseaseName;
  final String diseaseSeverity;
  final int diseaseConfidence;
  final bool isDiseaseHealthy;
  final Map<String, dynamic> weatherInfo;
  final List<String> recommendations;

  const FarmHealthCalculationResult({
    required this.cropName,
    this.cropVariety,
    required this.totalScore,
    required this.status,
    required this.summary,
    required this.cropConditionFactor,
    required this.soilMoistureFactor,
    required this.waterAvailabilityFactor,
    required this.soilQualityFactor,
    required this.diseaseFactor,
    required this.weatherFactor,
    required this.recentIrrigation,
    required this.diseaseName,
    required this.diseaseSeverity,
    required this.diseaseConfidence,
    required this.isDiseaseHealthy,
    required this.weatherInfo,
    required this.recommendations,
  });

  List<HealthFactorDetail> get allFactors => [
        cropConditionFactor,
        soilMoistureFactor,
        waterAvailabilityFactor,
        soilQualityFactor,
        diseaseFactor,
        weatherFactor,
      ];

  Map<String, dynamic> toFirestore() {
    return {
      'cropName': cropName,
      'selectedCrop': cropName,
      'cropVariety': cropVariety ?? '',
      'score': totalScore,
      'status': status,
      'summary': summary,
      // Assessment inputs — both field name variants saved for compatibility
      'cropCondition': cropConditionFactor.selectedValue,
      'soilMoisture': soilMoistureFactor.selectedValue,
      'waterAvailability': waterAvailabilityFactor.selectedValue,
      'soilQuality': soilQualityFactor.selectedValue,
      'recentIrrigation': recentIrrigation,   // required field name per spec
      'irrigationStatus': recentIrrigation,   // backward-compat alias
      // Disease analysis results
      'diseaseName': diseaseName,
      'diseaseSeverity': diseaseSeverity,
      'diseaseConfidence': diseaseConfidence,
      'diseaseScore': diseaseFactor.score.round(),
      'isHealthy': isDiseaseHealthy,
      // Weather values & risk used during calculation
      'weatherRisk': weatherFactor.score.round(),
      'weatherTemperature': weatherInfo['temperature'],
      'weatherHumidity': weatherInfo['humidity'],
      'weatherPrecipitation': weatherInfo['precipitation'],
      'weatherWindSpeed': weatherInfo['windSpeed'],
      'weatherCondition': weatherInfo['conditionText'],
      'weatherLocation': weatherInfo['locationName'],
      // Factor breakdown & recommendations
      'contributingFactors': allFactors.map((f) => f.toMap()).toList(),
      'recommendation': recommendations.isNotEmpty ? recommendations.first : summary,
      'recommendations': recommendations,
      // Timestamps (calculatedAt and timestamp)
      'calculatedAt': DateTime.now().toIso8601String(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

// ============================================================
// DETERMINISTIC FARM HEALTH CALCULATOR
// ============================================================

class FarmHealthCalculator {
  // Weights (Sum = 100%)
  static const double weightCropCondition = 0.25;
  static const double weightSoilMoisture = 0.20;
  static const double weightWaterAvailability = 0.15;
  static const double weightSoilQuality = 0.15;
  static const double weightDisease = 0.15;
  static const double weightWeather = 0.10;

  // ----------------------------------------------------------
  // 1. CROP CONDITION (Weight: 25%)
  // ----------------------------------------------------------
  static double scoreCropCondition(String condition) {
    switch (condition.trim().toLowerCase()) {
      case 'healthy':
        return 100.0;
      case 'slightly stressed':
        return 65.0;
      case 'moderately stressed':
        return 35.0;
      case 'severely stressed':
        return 10.0;
      default:
        return 50.0;
    }
  }

  // ----------------------------------------------------------
  // 2. SOIL MOISTURE (Weight: 20%)
  // ----------------------------------------------------------
  static double scoreSoilMoisture(String moisture) {
    switch (moisture.trim().toLowerCase()) {
      case 'normal':
        return 100.0;
      case 'very wet':
        return 50.0; // Waterlogging stress
      case 'dry':
        return 50.0; // Moisture deficit
      case 'very dry':
        return 20.0; // Severe drought stress
      default:
        return 50.0;
    }
  }

  // ----------------------------------------------------------
  // 3. WATER AVAILABILITY (Weight: 15%)
  // ----------------------------------------------------------
  static double scoreWaterAvailability(String water) {
    switch (water.trim().toLowerCase()) {
      case 'sufficient':
        return 100.0;
      case 'moderate':
        return 60.0;
      case 'low':
        return 20.0;
      default:
        return 50.0;
    }
  }

  // ----------------------------------------------------------
  // 4. SOIL QUALITY (Weight: 15%)
  // ----------------------------------------------------------
  static double scoreSoilQuality(String quality) {
    switch (quality.trim().toLowerCase()) {
      case 'good':
        return 100.0;
      case 'average':
        return 65.0;
      case 'don\'t know':
      case 'dont know':
        return 50.0; // Neutral strategy for unknown
      case 'poor':
        return 25.0;
      default:
        return 50.0;
    }
  }

  // ----------------------------------------------------------
  // 5. DISEASE HEALTH (Weight: 15%) — Mandatory from AI result
  // ----------------------------------------------------------
  static double scoreDiseaseAnalysis(DiseaseAnalysisResult diseaseResult) {
    if (diseaseResult.isHealthy) {
      return 100.0;
    }

    final severity = diseaseResult.severity.trim().toLowerCase();
    if (severity == 'low') {
      return 70.0;
    } else if (severity == 'moderate' || severity == 'medium') {
      return 40.0;
    } else if (severity == 'severe' || severity == 'high') {
      return 15.0;
    }

    return 40.0;
  }

  // ----------------------------------------------------------
  // 6. WEATHER HEALTH (Weight: 10%)
  // ----------------------------------------------------------
  static double scoreWeather(WeatherData? weather) {
    if (weather == null) {
      return 50.0; // Neutral fallback if offline / no weather
    }

    double score = 100.0;

    // Temperature stress
    if (weather.temperature >= 40) {
      score -= 30; // Extreme heat
    } else if (weather.temperature >= 35) {
      score -= 15;
    } else if (weather.temperature <= 5) {
      score -= 30; // Frost/extreme cold
    } else if (weather.temperature <= 12) {
      score -= 15;
    }

    // Humidity + Fungal risk
    if (weather.humidity >= 85 && weather.temperature >= 20 && weather.temperature <= 32) {
      score -= 25; // Severe fungal risk condition
    } else if (weather.humidity >= 78) {
      score -= 15;
    } else if (weather.humidity <= 20 && weather.temperature > 30) {
      score -= 15; // High transpiration/desiccation
    }

    // Precipitation & Storm
    if (weather.weatherCode >= 95 || weather.precipitation > 15) {
      score -= 30; // Thunderstorm / heavy rain
    } else if (weather.precipitation > 5 || (weather.weatherCode >= 61 && weather.weatherCode <= 67)) {
      score -= 15;
    }

    // Wind stress
    if (weather.windSpeed > 28) {
      score -= 20;
    } else if (weather.windSpeed > 18) {
      score -= 10;
    }

    return score.clamp(15.0, 100.0);
  }

  // ----------------------------------------------------------
  // CLASSIFICATION (80-100: Excellent, 60-79: Good, 40-59: Moderate, 20-39: Poor, 0-19: Critical)
  // ----------------------------------------------------------
  static String classifyScore(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Moderate';
    if (score >= 20) return 'Poor';
    return 'Critical';
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return const Color(0xFFB7D83D);
      case 'good':
        return const Color(0xFF8BC34A);
      case 'moderate':
        return const Color(0xFFFFB74D);
      case 'poor':
        return const Color(0xFFFF7043);
      case 'critical':
        return const Color(0xFFEF5350);
      default:
        return const Color(0xFFB7D83D);
    }
  }

  // ----------------------------------------------------------
  // COMPLETE CALCULATION
  // ----------------------------------------------------------
  static FarmHealthCalculationResult calculate({
    required String cropName,
    String? cropVariety,
    required String cropCondition,
    required String soilMoisture,
    required String waterAvailability,
    required String soilQuality,
    required String recentIrrigation,
    required DiseaseAnalysisResult diseaseResult,
    WeatherData? weather,
  }) {
    // 1. Calculate raw factor scores
    final ccScore = scoreCropCondition(cropCondition);
    final smScore = scoreSoilMoisture(soilMoisture);
    final waScore = scoreWaterAvailability(waterAvailability);
    final sqScore = scoreSoilQuality(soilQuality);
    final disScore = scoreDiseaseAnalysis(diseaseResult);
    final wtScore = scoreWeather(weather);

    // 2. Weighted sum
    final ccWeighted = ccScore * weightCropCondition;
    final smWeighted = smScore * weightSoilMoisture;
    final waWeighted = waScore * weightWaterAvailability;
    final sqWeighted = sqScore * weightSoilQuality;
    final disWeighted = disScore * weightDisease;
    final wtWeighted = wtScore * weightWeather;

    final rawTotal = ccWeighted + smWeighted + waWeighted + sqWeighted + disWeighted + wtWeighted;
    final totalScore = rawTotal.round().clamp(0, 100);
    final status = classifyScore(totalScore);

    // 3. Build factor details
    final ccFactor = HealthFactorDetail(
      title: 'Crop Condition',
      selectedValue: cropCondition,
      score: ccScore,
      weight: weightCropCondition,
      weightedScore: ccWeighted,
      statusDescription: _getCropConditionDesc(cropCondition),
      icon: Icons.eco_rounded,
    );

    final smFactor = HealthFactorDetail(
      title: 'Soil Moisture',
      selectedValue: soilMoisture,
      score: smScore,
      weight: weightSoilMoisture,
      weightedScore: smWeighted,
      statusDescription: _getSoilMoistureDesc(soilMoisture),
      icon: Icons.water_drop_rounded,
    );

    final waFactor = HealthFactorDetail(
      title: 'Water Availability',
      selectedValue: waterAvailability,
      score: waScore,
      weight: weightWaterAvailability,
      weightedScore: waWeighted,
      statusDescription: _getWaterAvailabilityDesc(waterAvailability),
      icon: Icons.waves_rounded,
    );

    final sqFactor = HealthFactorDetail(
      title: 'Soil Quality',
      selectedValue: soilQuality,
      score: sqScore,
      weight: weightSoilQuality,
      weightedScore: sqWeighted,
      statusDescription: _getSoilQualityDesc(soilQuality),
      icon: Icons.landscape_rounded,
    );

    final disFactor = HealthFactorDetail(
      title: 'Disease Health',
      selectedValue: diseaseResult.isHealthy
          ? 'Healthy Plant (${diseaseResult.confidence}%)'
          : '${diseaseResult.diseaseName} (${diseaseResult.severity})',
      score: disScore,
      weight: weightDisease,
      weightedScore: disWeighted,
      statusDescription: diseaseResult.isHealthy
          ? 'AI confirmed no visible foliar disease or fungal lesions.'
          : 'AI detected ${diseaseResult.diseaseName} with ${diseaseResult.severity} severity (${diseaseResult.confidence}% confidence).',
      icon: Icons.biotech_rounded,
    );

    final wtFactor = HealthFactorDetail(
      title: 'Weather Impact',
      selectedValue: weather != null
          ? '${weather.temperature.round()}°C • ${weather.conditionText}'
          : 'Not Available',
      score: wtScore,
      weight: weightWeather,
      weightedScore: wtWeighted,
      statusDescription: weather != null
          ? 'Humidity ${weather.humidity}%, Wind ${weather.windSpeed.round()} km/h'
          : 'Live weather data was unavailable at assessment time.',
      icon: Icons.wb_sunny_rounded,
    );

    // Summary phrase
    final summary = '$cropName health assessment evaluated as $status ($totalScore/100).';

    // Fallback Rule-based Recommendations
    final fallbackRecs = _generateFallbackRecommendations(
      cropName: cropName,
      cropCondition: cropCondition,
      soilMoisture: soilMoisture,
      waterAvailability: waterAvailability,
      soilQuality: soilQuality,
      recentIrrigation: recentIrrigation,
      diseaseResult: diseaseResult,
      weather: weather,
    );

    final weatherMap = <String, dynamic>{
      'temperature': weather?.temperature,
      'humidity': weather?.humidity,
      'precipitation': weather?.precipitation,
      'windSpeed': weather?.windSpeed,
      'conditionText': weather?.conditionText ?? 'Unavailable',
      'locationName': weather?.locationName ?? '',
    };

    return FarmHealthCalculationResult(
      cropName: cropName,
      cropVariety: cropVariety,
      totalScore: totalScore,
      status: status,
      summary: summary,
      cropConditionFactor: ccFactor,
      soilMoistureFactor: smFactor,
      waterAvailabilityFactor: waFactor,
      soilQualityFactor: sqFactor,
      diseaseFactor: disFactor,
      weatherFactor: wtFactor,
      recentIrrigation: recentIrrigation,
      diseaseName: diseaseResult.diseaseName,
      diseaseSeverity: diseaseResult.severity,
      diseaseConfidence: diseaseResult.confidence,
      isDiseaseHealthy: diseaseResult.isHealthy,
      weatherInfo: weatherMap,
      recommendations: fallbackRecs,
    );
  }

  // ----------------------------------------------------------
  // DESCRIPTIONS
  // ----------------------------------------------------------
  static String _getCropConditionDesc(String cond) {
    switch (cond.toLowerCase()) {
      case 'healthy':
        return 'Vigorous crop growth with green, active foliage.';
      case 'slightly stressed':
        return 'Minor leaf pale/curling or mild growth slowdown.';
      case 'moderately stressed':
        return 'Visible nutrient or hydration deficiency noticed.';
      case 'severely stressed':
        return 'Severe plant stress, wilting or stunted growth.';
      default:
        return 'Crop condition reported as $cond.';
    }
  }

  static String _getSoilMoistureDesc(String moisture) {
    switch (moisture.toLowerCase()) {
      case 'normal':
        return 'Optimal soil moisture for roots and nutrient uptake.';
      case 'very wet':
        return 'High water saturation; risk of aeration loss & root rot.';
      case 'dry':
        return 'Soil lacks adequate moisture; irrigation needed soon.';
      case 'very dry':
        return 'Critical moisture depletion causing root dehydration.';
      default:
        return 'Moisture level: $moisture.';
    }
  }

  static String _getWaterAvailabilityDesc(String water) {
    switch (water.toLowerCase()) {
      case 'sufficient':
        return 'Adequate water supply available for next irrigation cycles.';
      case 'moderate':
        return 'Moderate water reserves; schedule watering conservatively.';
      case 'low':
        return 'Limited water supply; prioritize critical root zones.';
      default:
        return 'Water availability: $water.';
    }
  }

  static String _getSoilQualityDesc(String quality) {
    switch (quality.toLowerCase()) {
      case 'good':
        return 'Fertile soil with balanced texture and organic matter.';
      case 'average':
        return 'Moderate soil structure; supplemental nutrition recommended.';
      case 'poor':
        return 'Low fertility or poor texture; organic compost recommended.';
      default:
        return 'Soil quality not specifically tested.';
    }
  }

  // ----------------------------------------------------------
  // FALLBACK ACTIONABLE RECOMMENDATIONS
  // ----------------------------------------------------------
  static List<String> _generateFallbackRecommendations({
    required String cropName,
    required String cropCondition,
    required String soilMoisture,
    required String waterAvailability,
    required String soilQuality,
    required String recentIrrigation,
    required DiseaseAnalysisResult diseaseResult,
    WeatherData? weather,
  }) {
    final List<String> recs = [];

    // Irrigation & Moisture advice
    if (soilMoisture.toLowerCase() == 'dry' || soilMoisture.toLowerCase() == 'very dry') {
      if (weather != null && weather.precipitation > 2.0) {
        recs.add('Rain is expected in your area (${weather.precipitation}mm). Delay heavy artificial irrigation and monitor actual rainfall absorption.');
      } else {
        recs.add('Apply a light to moderate irrigation during early morning or evening hours to restore root zone moisture without heat shock.');
      }
    } else if (soilMoisture.toLowerCase() == 'very wet') {
      recs.add('Avoid further watering and clear drainage furrows to prevent water stagnation and root asphyxiation.');
    } else {
      recs.add('Maintain the current scheduled irrigation cycle as soil moisture is in a healthy balance.');
    }

    // Disease / Crop Protection advice
    if (!diseaseResult.isHealthy) {
      recs.add('Disease Alert (${diseaseResult.diseaseName}): ${diseaseResult.recommendedSolution.isNotEmpty ? diseaseResult.recommendedSolution : "Inspect affected leaves and apply locally recommended protection steps following label instructions."}');
    } else if (weather != null && weather.humidity >= 78 && weather.temperature >= 20 && weather.temperature <= 32) {
      recs.add('High ambient humidity (${weather.humidity}%) favors fungal development. Periodically scout lower leaf surfaces for early spot symptoms.');
    }

    // Soil & Nutrition advice
    if (soilQuality.toLowerCase() == 'poor' || soilQuality.toLowerCase() == 'average') {
      recs.add('Incorporate well-decomposed organic compost or vermicompost to enhance soil organic carbon and nutrient retention for $cropName.');
    }

    // Heat / Wind advice
    if (weather != null && weather.temperature >= 35) {
      recs.add('High temperature (${weather.temperature.round()}°C) can cause heat stress. Mulch the base of the crop to conserve soil moisture.');
    }

    if (recs.isEmpty) {
      recs.add('Continue standard farming practices, balanced fertilization, and weekly field inspections for $cropName.');
    }

    return recs;
  }
}
