import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// WMO WEATHER CODE MAPPINGS
// ============================================================

String getWeatherCondition(int weatherCode) {
  switch (weatherCode) {
    case 0:
      return 'Clear Sky';
    case 1:
      return 'Mainly Clear';
    case 2:
      return 'Partly Cloudy';
    case 3:
      return 'Overcast';
    case 45:
    case 48:
      return 'Foggy';
    case 51:
    case 53:
    case 55:
      return 'Drizzle';
    case 56:
    case 57:
      return 'Freezing Drizzle';
    case 61:
      return 'Slight Rain';
    case 63:
      return 'Moderate Rain';
    case 65:
      return 'Heavy Rain';
    case 66:
    case 67:
      return 'Freezing Rain';
    case 71:
    case 73:
    case 75:
      return 'Snowfall';
    case 77:
      return 'Snow Grains';
    case 80:
    case 81:
    case 82:
      return 'Rain Showers';
    case 85:
    case 86:
      return 'Snow Showers';
    case 95:
      return 'Thunderstorm';
    case 96:
    case 99:
      return 'Thunderstorm with Hail';
    default:
      return 'Clear Weather';
  }
}

IconData getWeatherIcon(int weatherCode) {
  switch (weatherCode) {
    case 0:
    case 1:
      return Icons.wb_sunny_rounded;
    case 2:
    case 3:
      return Icons.cloud_outlined;
    case 45:
    case 48:
      return Icons.foggy;
    case 51:
    case 53:
    case 55:
    case 56:
    case 57:
      return Icons.water_drop_outlined;
    case 61:
    case 63:
    case 65:
    case 66:
    case 67:
    case 80:
    case 81:
    case 82:
      return Icons.grain_rounded;
    case 71:
    case 73:
    case 75:
    case 77:
    case 85:
    case 86:
      return Icons.ac_unit_rounded;
    case 95:
    case 96:
    case 99:
      return Icons.thunderstorm_outlined;
    default:
      return Icons.cloud_outlined;
  }
}

// ============================================================
// FARMING ADVICE MODEL
// ============================================================

enum AdviceType { good, info, warning, alert }

class FarmingAdvice {
  final String title;
  final String advice;
  final AdviceType type;
  final IconData icon;

  const FarmingAdvice({
    required this.title,
    required this.advice,
    required this.type,
    required this.icon,
  });
}

// ============================================================
// HOURLY FORECAST MODEL
// ============================================================

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final int weatherCode;
  final int precipitationProbability;

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    required this.precipitationProbability,
  });

  String get conditionText => getWeatherCondition(weatherCode);
  IconData get icon => getWeatherIcon(weatherCode);

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'temperature': temperature,
        'weatherCode': weatherCode,
        'precipitationProbability': precipitationProbability,
      };

  factory HourlyForecast.fromJson(Map<String, dynamic> json) => HourlyForecast(
        time: DateTime.parse(json['time']),
        temperature: (json['temperature'] as num).toDouble(),
        weatherCode: (json['weatherCode'] as num).toInt(),
        precipitationProbability:
            (json['precipitationProbability'] as num?)?.toInt() ?? 0,
      );
}

// ============================================================
// DAILY FORECAST MODEL
// ============================================================

class DailyForecast {
  final DateTime date;
  final int weatherCode;
  final double maxTemp;
  final double minTemp;
  final double precipitationSum;
  final int precipitationProbability;
  final String sunrise;
  final String sunset;
  final double uvIndex;

  DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
    required this.precipitationSum,
    required this.precipitationProbability,
    required this.sunrise,
    required this.sunset,
    required this.uvIndex,
  });

  String get conditionText => getWeatherCondition(weatherCode);
  IconData get icon => getWeatherIcon(weatherCode);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weatherCode': weatherCode,
        'maxTemp': maxTemp,
        'minTemp': minTemp,
        'precipitationSum': precipitationSum,
        'precipitationProbability': precipitationProbability,
        'sunrise': sunrise,
        'sunset': sunset,
        'uvIndex': uvIndex,
      };

  factory DailyForecast.fromJson(Map<String, dynamic> json) => DailyForecast(
        date: DateTime.parse(json['date']),
        weatherCode: (json['weatherCode'] as num).toInt(),
        maxTemp: (json['maxTemp'] as num).toDouble(),
        minTemp: (json['minTemp'] as num).toDouble(),
        precipitationSum:
            (json['precipitationSum'] as num?)?.toDouble() ?? 0.0,
        precipitationProbability:
            (json['precipitationProbability'] as num?)?.toInt() ?? 0,
        sunrise: json['sunrise']?.toString() ?? '',
        sunset: json['sunset']?.toString() ?? '',
        uvIndex: (json['uvIndex'] as num?)?.toDouble() ?? 0.0,
      );
}

// ============================================================
// WEATHER DATA MODEL
// ============================================================

class WeatherData {
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final int weatherCode;
  final double windSpeed;
  final int windDirection;
  final double precipitation;
  final int rainProbability;
  final double uvIndex;
  final double visibility;
  final String sunrise;
  final String sunset;
  final double minTempToday;
  final double maxTempToday;
  final String locationName;
  final bool hasFarmerLocation;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;

  WeatherData({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.weatherCode,
    required this.windSpeed,
    required this.windDirection,
    required this.precipitation,
    required this.rainProbability,
    required this.uvIndex,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    required this.minTempToday,
    required this.maxTempToday,
    required this.locationName,
    this.hasFarmerLocation = true,
    this.hourly = const [],
    this.daily = const [],
  });

  String get conditionText => getWeatherCondition(weatherCode);
  IconData get weatherIcon => getWeatherIcon(weatherCode);

  String get windDirectionText {
    const directions = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'
    ];
    final index = ((windDirection + 11.25) % 360 / 22.5).floor();
    return directions[index % 16];
  }

  // ==========================================================
  // FARMING WEATHER ADVISORY ALGORITHMS
  // ==========================================================

  List<FarmingAdvice> get farmingAdvices {
    final List<FarmingAdvice> list = [];

    // 1. Irrigation Recommendation
    if (precipitation > 1.0 || rainProbability >= 50) {
      list.add(FarmingAdvice(
        title: 'Irrigation: Delay Recommended',
        advice: 'Rain expected ($rainProbability% chance). Postpone scheduled watering to prevent waterlogging and save irrigation water.',
        type: AdviceType.warning,
        icon: Icons.water_drop,
      ));
    } else if (temperature > 32 && humidity < 50) {
      list.add(const FarmingAdvice(
        title: 'Irrigation: Recommended',
        advice: 'Dry conditions and high evaporation rate. Water crops during early morning or late evening for optimal moisture absorption.',
        type: AdviceType.info,
        icon: Icons.water_drop_outlined,
      ));
    } else {
      list.add(const FarmingAdvice(
        title: 'Irrigation: Normal Schedule',
        advice: 'Soil moisture loss is moderate. Maintain your standard scheduled watering cycle.',
        type: AdviceType.good,
        icon: Icons.water_drop_outlined,
      ));
    }

    // 2. Rain Warning
    if (weatherCode >= 95) {
      list.add(const FarmingAdvice(
        title: 'Rain Warning: Severe Thunderstorm',
        advice: 'Thunderstorms and potential hail predicted. Secure loose equipment, protect open nurseries, and keep livestock sheltered.',
        type: AdviceType.alert,
        icon: Icons.thunderstorm_outlined,
      ));
    } else if (precipitation > 2.0 || rainProbability >= 60 || (weatherCode >= 61 && weatherCode <= 67) || (weatherCode >= 80 && weatherCode <= 82)) {
      list.add(FarmingAdvice(
        title: 'Rain Warning: Moderate to Heavy Rain',
        advice: 'Rainfall expected ($rainProbability% probability). Ensure drainage channels in fields are clear to prevent water stagnation.',
        type: AdviceType.warning,
        icon: Icons.grain_rounded,
      ));
    } else if (rainProbability >= 30) {
      list.add(FarmingAdvice(
        title: 'Rain Notice: Light Showers Possible',
        advice: '$rainProbability% chance of passing showers. Monitor sky conditions before outdoor crop drying or harvesting.',
        type: AdviceType.info,
        icon: Icons.cloud_outlined,
      ));
    }

    // 3. Heat & Sun Warning
    if (temperature >= 38 || uvIndex >= 9) {
      list.add(FarmingAdvice(
        title: 'Heat Warning: Extreme Heat',
        advice: 'High temperature (${temperature.round()}°C) and UV Index (${uvIndex.toStringAsFixed(1)}). Provide shade for seedlings and avoid strenuous midday fieldwork.',
        type: AdviceType.alert,
        icon: Icons.wb_sunny_rounded,
      ));
    } else if (temperature >= 34 || uvIndex >= 7) {
      list.add(FarmingAdvice(
        title: 'Heat Notice: Warm & High UV',
        advice: 'Warm afternoon (${temperature.round()}°C). Maintain crop hydration and shade young nursery beds.',
        type: AdviceType.info,
        icon: Icons.wb_sunny_outlined,
      ));
    }

    // 4. High Humidity & Fungal Risk
    if (humidity >= 78 && temperature >= 20 && temperature <= 32) {
      list.add(FarmingAdvice(
        title: 'Fungal Risk: High Alert',
        advice: 'Warm temperature (${temperature.round()}°C) and high humidity ($humidity%) favor mildew, rust, and blight. Inspect crop leaves closely.',
        type: AdviceType.alert,
        icon: Icons.coronavirus_outlined,
      ));
    } else if (humidity >= 70) {
      list.add(const FarmingAdvice(
        title: 'Fungal Risk: Moderate',
        advice: 'Elevated moisture levels. Ensure proper row aeration and check vulnerable plants.',
        type: AdviceType.info,
        icon: Icons.bug_report_outlined,
      ));
    }

    // 5. Farm Activities (Spraying, Fieldwork, Harvesting)
    if (windSpeed > 18) {
      list.add(FarmingAdvice(
        title: 'Farm Activities: High Wind Drift',
        advice: 'Wind speed is ${windSpeed.round()} km/h. Unsuitable for pesticide/fertilizer spraying. Postpone until wind calms below 15 km/h.',
        type: AdviceType.warning,
        icon: Icons.air_rounded,
      ));
    } else if (rainProbability >= 40) {
      list.add(const FarmingAdvice(
        title: 'Farm Activities: Delay Chemical Spraying',
        advice: 'Rain probability may wash off applied pesticides or foliar fertilizers. Postpone chemical treatments.',
        type: AdviceType.warning,
        icon: Icons.science_outlined,
      ));
    } else {
      list.add(const FarmingAdvice(
        title: 'Farm Activities: Highly Suitable',
        advice: 'Calm breeze and clear skies make today optimal for field preparation, fertilizing, spraying, and harvesting.',
        type: AdviceType.good,
        icon: Icons.check_circle_outline,
      ));
    }

    return list;
  }

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'apparentTemperature': apparentTemperature,
        'humidity': humidity,
        'weatherCode': weatherCode,
        'windSpeed': windSpeed,
        'windDirection': windDirection,
        'precipitation': precipitation,
        'rainProbability': rainProbability,
        'uvIndex': uvIndex,
        'visibility': visibility,
        'sunrise': sunrise,
        'sunset': sunset,
        'minTempToday': minTempToday,
        'maxTempToday': maxTempToday,
        'locationName': locationName,
        'hasFarmerLocation': hasFarmerLocation,
        'hourly': hourly.map((e) => e.toJson()).toList(),
        'daily': daily.map((e) => e.toJson()).toList(),
      };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
        apparentTemperature: (json['apparentTemperature'] as num?)?.toDouble() ??
            (json['temperature'] as num?)?.toDouble() ??
            0.0,
        humidity: (json['humidity'] as num?)?.toInt() ?? 0,
        weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
        windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0.0,
        windDirection: (json['windDirection'] as num?)?.toInt() ?? 0,
        precipitation: (json['precipitation'] as num?)?.toDouble() ?? 0.0,
        rainProbability: (json['rainProbability'] as num?)?.toInt() ?? 0,
        uvIndex: (json['uvIndex'] as num?)?.toDouble() ?? 0.0,
        visibility: (json['visibility'] as num?)?.toDouble() ?? 10.0,
        sunrise: json['sunrise']?.toString() ?? '',
        sunset: json['sunset']?.toString() ?? '',
        minTempToday: (json['minTempToday'] as num?)?.toDouble() ?? 0.0,
        maxTempToday: (json['maxTempToday'] as num?)?.toDouble() ?? 0.0,
        locationName: json['locationName']?.toString() ?? '',
        hasFarmerLocation: json['hasFarmerLocation'] as bool? ?? true,
        hourly: (json['hourly'] as List?)
                ?.map((e) =>
                    HourlyForecast.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        daily: (json['daily'] as List?)
                ?.map((e) =>
                    DailyForecast.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
      );
}

// ============================================================
// WEATHER SERVICE (OPEN-METEO API)
// ============================================================

class WeatherService {
  static String formatIsoTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (_) {
      return isoString;
    }
  }

  static Future<Map<String, dynamic>?> _geocodeQuery(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;
    try {
      final geoUrl = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(clean)}&count=1&language=en&format=json',
      );

      final geoRes =
          await http.get(geoUrl).timeout(const Duration(seconds: 8));

      if (geoRes.statusCode == 200) {
        final geoData = jsonDecode(geoRes.body);
        final results = geoData['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final first = results[0];
          final lat = (first['latitude'] as num?)?.toDouble();
          final lon = (first['longitude'] as num?)?.toDouble();
          final name = first['name']?.toString() ?? clean;
          if (lat != null && lon != null) {
            return {'lat': lat, 'lon': lon, 'name': name};
          }
        }
      }
    } catch (e) {
      debugPrint('WeatherService: Geocoding error for "$query": $e');
    }
    return null;
  }

  static Future<WeatherData?> fetchWeatherForUser(String? userId) async {
    String village = '';
    String taluka = '';
    String district = '';
    String state = '';
    bool hasFarmerLocation = false;

    // 1. Fetch farmer location from Firestore
    if (userId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('farmers')
            .doc(userId)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          village = data['village']?.toString().trim() ?? '';
          taluka = data['taluka']?.toString().trim() ?? '';
          district = data['district']?.toString().trim() ?? '';
          state = data['state']?.toString().trim() ?? '';

          if (village.isNotEmpty ||
              taluka.isNotEmpty ||
              district.isNotEmpty ||
              state.isNotEmpty) {
            hasFarmerLocation = true;
          }
        }
      } catch (e) {
        debugPrint('WeatherService: Error fetching farmer profile: $e');
      }
    }

    // 2. Geocode location via Open-Meteo Geocoding API with multi-tier fallback
    double? lat;
    double? lon;
    String displayLocation = '';

    // Step A: Try Village with District or alone
    if (village.isNotEmpty) {
      if (district.isNotEmpty) {
        final res = await _geocodeQuery('$village, $district');
        if (res != null) {
          lat = res['lat'];
          lon = res['lon'];
          displayLocation = '$village, $district';
        }
      }
      if (lat == null) {
        final res = await _geocodeQuery(village);
        if (res != null) {
          lat = res['lat'];
          lon = res['lon'];
          displayLocation = district.isNotEmpty ? '$village, $district' : village;
        }
      }
    }

    // Step B: Fallback to Taluka if village geocoding failed
    if (lat == null && taluka.isNotEmpty) {
      if (district.isNotEmpty) {
        final res = await _geocodeQuery('$taluka, $district');
        if (res != null) {
          lat = res['lat'];
          lon = res['lon'];
          displayLocation = '$taluka, $district';
        }
      }
      if (lat == null) {
        final res = await _geocodeQuery(taluka);
        if (res != null) {
          lat = res['lat'];
          lon = res['lon'];
          displayLocation = district.isNotEmpty ? '$taluka, $district' : taluka;
        }
      }
    }

    // Step C: Fallback to District if village and taluka failed
    if (lat == null && district.isNotEmpty) {
      if (state.isNotEmpty) {
        final res = await _geocodeQuery('$district, $state');
        if (res != null) {
          lat = res['lat'];
          lon = res['lon'];
          displayLocation = '$district, $state';
        }
      }
      if (lat == null) {
        final res = await _geocodeQuery(district);
        if (res != null) {
          lat = res['lat'];
          lon = res['lon'];
          displayLocation = district;
        }
      }
    }

    // Step D: Fallback to State if district failed
    if (lat == null && state.isNotEmpty) {
      final res = await _geocodeQuery('$state, India');
      if (res != null) {
        lat = res['lat'];
        lon = res['lon'];
        displayLocation = state;
      } else {
        final res2 = await _geocodeQuery(state);
        if (res2 != null) {
          lat = res2['lat'];
          lon = res2['lon'];
          displayLocation = state;
        }
      }
    }

    // Step E: Default fallback (Maharashtra / Central India coordinates)
    if (lat == null || lon == null) {
      lat = 19.7515;
      lon = 75.7139;
      if (displayLocation.isEmpty) {
        if (hasFarmerLocation) {
          displayLocation = [village, district, state]
              .where((s) => s.isNotEmpty)
              .join(', ');
          if (displayLocation.isEmpty) displayLocation = 'Maharashtra';
        } else {
          displayLocation = 'Maharashtra';
        }
      }
    }

    // 3. Fetch comprehensive forecast from Open-Meteo Forecast API
    try {
      final forecastUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m'
        '&hourly=temperature_2m,relative_humidity_2m,precipitation_probability,weather_code,visibility,uv_index'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_sum,precipitation_probability_max'
        '&timezone=auto',
      );

      final forecastRes =
          await http.get(forecastUrl).timeout(const Duration(seconds: 8));

      if (forecastRes.statusCode == 200) {
        final data = jsonDecode(forecastRes.body);
        final current = data['current'];
        final hourlyData = data['hourly'];
        final dailyData = data['daily'];

        if (current != null) {
          // Parse hourly forecast (next 24 hours from current time)
          final List<HourlyForecast> hourlyList = [];
          if (hourlyData != null && hourlyData['time'] is List) {
            final List times = hourlyData['time'];
            final List temps = (hourlyData['temperature_2m'] is List)
                ? hourlyData['temperature_2m']
                : [];
            final List codes = (hourlyData['weather_code'] is List)
                ? hourlyData['weather_code']
                : [];
            final List pops = (hourlyData['precipitation_probability'] is List)
                ? hourlyData['precipitation_probability']
                : [];

            final now = DateTime.now();
            for (int i = 0; i < times.length && hourlyList.length < 24; i++) {
              final dt = DateTime.tryParse(times[i]?.toString() ?? '');
              if (dt != null &&
                  dt.isAfter(now.subtract(const Duration(hours: 1)))) {
                hourlyList.add(HourlyForecast(
                  time: dt,
                  temperature: (temps.length > i && temps[i] != null
                      ? (temps[i] as num).toDouble()
                      : 0.0),
                  weatherCode: (codes.length > i && codes[i] != null
                      ? (codes[i] as num).toInt()
                      : 0),
                  precipitationProbability: (pops.length > i && pops[i] != null
                      ? (pops[i] as num).toInt()
                      : 0),
                ));
              }
            }

            // Fallback if timestamp filtering resulted in empty list
            if (hourlyList.isEmpty) {
              for (int i = 0; i < times.length && i < 24; i++) {
                final dt = DateTime.tryParse(times[i]?.toString() ?? '') ??
                    DateTime.now().add(Duration(hours: i));
                hourlyList.add(HourlyForecast(
                  time: dt,
                  temperature: (temps.length > i && temps[i] != null
                      ? (temps[i] as num).toDouble()
                      : 0.0),
                  weatherCode: (codes.length > i && codes[i] != null
                      ? (codes[i] as num).toInt()
                      : 0),
                  precipitationProbability: (pops.length > i && pops[i] != null
                      ? (pops[i] as num).toInt()
                      : 0),
                ));
              }
            }
          }

          // Parse 7-day daily forecast
          final List<DailyForecast> dailyList = [];
          double minToday =
              (current['temperature_2m'] as num?)?.toDouble() ?? 0.0;
          double maxToday =
              (current['temperature_2m'] as num?)?.toDouble() ?? 0.0;
          String sunriseToday = '';
          String sunsetToday = '';
          int maxPopToday = 0;

          if (dailyData != null && dailyData['time'] is List) {
            final List dTimes = dailyData['time'];
            final List dCodes = (dailyData['weather_code'] is List)
                ? dailyData['weather_code']
                : [];
            final List dMaxTemps = (dailyData['temperature_2m_max'] is List)
                ? dailyData['temperature_2m_max']
                : [];
            final List dMinTemps = (dailyData['temperature_2m_min'] is List)
                ? dailyData['temperature_2m_min']
                : [];
            final List dPrecipSums = (dailyData['precipitation_sum'] is List)
                ? dailyData['precipitation_sum']
                : [];
            final List dPrecipPops =
                (dailyData['precipitation_probability_max'] is List)
                    ? dailyData['precipitation_probability_max']
                    : [];
            final List dSunrises =
                (dailyData['sunrise'] is List) ? dailyData['sunrise'] : [];
            final List dSunsets =
                (dailyData['sunset'] is List) ? dailyData['sunset'] : [];
            final List dUvs = (dailyData['uv_index_max'] is List)
                ? dailyData['uv_index_max']
                : [];

            for (int i = 0; i < dTimes.length && i < 7; i++) {
              final dDt = DateTime.tryParse(dTimes[i]?.toString() ?? '') ??
                  DateTime.now().add(Duration(days: i));
              final maxT = (dMaxTemps.length > i && dMaxTemps[i] != null)
                  ? (dMaxTemps[i] as num).toDouble()
                  : 0.0;
              final minT = (dMinTemps.length > i && dMinTemps[i] != null)
                  ? (dMinTemps[i] as num).toDouble()
                  : 0.0;
              final sRise = (dSunrises.length > i && dSunrises[i] != null)
                  ? formatIsoTime(dSunrises[i].toString())
                  : '';
              final sSet = (dSunsets.length > i && dSunsets[i] != null)
                  ? formatIsoTime(dSunsets[i].toString())
                  : '';
              final pop = (dPrecipPops.length > i && dPrecipPops[i] != null)
                  ? (dPrecipPops[i] as num).toInt()
                  : 0;

              if (i == 0) {
                minToday = minT;
                maxToday = maxT;
                sunriseToday = sRise;
                sunsetToday = sSet;
                maxPopToday = pop;
              }

              dailyList.add(DailyForecast(
                date: dDt,
                weatherCode: (dCodes.length > i && dCodes[i] != null)
                    ? (dCodes[i] as num).toInt()
                    : 0,
                maxTemp: maxT,
                minTemp: minT,
                precipitationSum: (dPrecipSums.length > i && dPrecipSums[i] != null)
                    ? (dPrecipSums[i] as num).toDouble()
                    : 0.0,
                precipitationProbability: pop,
                sunrise: sRise,
                sunset: sSet,
                uvIndex: (dUvs.length > i && dUvs[i] != null)
                    ? (dUvs[i] as num).toDouble()
                    : 0.0,
              ));
            }
          }

          // Calculate current UV and Visibility from hourly if available
          double currentUv = 0.0;
          double currentVisKm = 10.0;
          if (hourlyData != null) {
            final List uvs = (hourlyData['uv_index'] is List)
                ? hourlyData['uv_index']
                : [];
            final List viss = (hourlyData['visibility'] is List)
                ? hourlyData['visibility']
                : [];
            if (uvs.isNotEmpty && uvs[0] != null) {
              currentUv = (uvs[0] as num).toDouble();
            }
            if (viss.isNotEmpty && viss[0] != null) {
              currentVisKm =
                  ((viss[0] as num).toDouble() / 1000).clamp(0.1, 50.0);
            }
          }

          final weather = WeatherData(
            temperature:
                (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
            apparentTemperature:
                (current['apparent_temperature'] as num?)?.toDouble() ??
                    (current['temperature_2m'] as num?)?.toDouble() ??
                    0.0,
            humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
            weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
            windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
            windDirection:
                (current['wind_direction_10m'] as num?)?.toInt() ?? 0,
            precipitation:
                (current['precipitation'] as num?)?.toDouble() ?? 0.0,
            rainProbability: maxPopToday,
            uvIndex: currentUv > 0
                ? currentUv
                : (dailyList.isNotEmpty ? dailyList[0].uvIndex : 0.0),
            visibility: currentVisKm,
            sunrise: sunriseToday,
            sunset: sunsetToday,
            minTempToday: minToday,
            maxTempToday: maxToday,
            locationName: displayLocation,
            hasFarmerLocation: hasFarmerLocation,
            hourly: hourlyList,
            daily: dailyList,
          );

          // Cache in local storage
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'cached_detailed_weather',
              jsonEncode(weather.toJson()),
            );
          } catch (_) {}

          return weather;
        }
      }
    } catch (e) {
      debugPrint('WeatherService: Forecast API error: $e');
    }

    // Check offline cache on error
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_detailed_weather');
      if (cachedJson != null) {
        final decoded = jsonDecode(cachedJson);
        return WeatherData.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}

    return null;
  }
}
