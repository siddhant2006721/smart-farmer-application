import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'weather_service.dart';
import 'detailed_weather_page.dart';
import 'government_schemes_page.dart';
import 'farm_mitra_page.dart';
import 'profile_page.dart';
import 'welcome_page.dart';
import 'account_deletion_service.dart';
import 'my_crops_page.dart';
import 'market_prices_page.dart';
import 'notifications_page.dart';
import 'notification_service.dart';
import 'daily_work_section.dart';
import 'disease_detection_page.dart';
import 'farm_health_page.dart';

void main() {
  runApp(const FarmApp());
}

// ============================================================
// APP
// ============================================================

class FarmApp extends StatelessWidget {
  const FarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Farm Manager',

      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,

        colorScheme: const ColorScheme.dark(
          primary: primaryGreen,
          secondary: primaryGreen,
          surface: cardColor,
        ),

        fontFamily: 'Roboto',

        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          elevation: 0,
        ),
      ),

      home: const DashboardPage(),
    );
  }
}

// ============================================================
// COLORS
// ============================================================

const Color backgroundColor = Color(0xFF0F130D);
const Color cardColor = Color(0xFF1A2117);
const Color cardColor2 = Color(0xFF20291B);
const Color primaryGreen = Color(0xFFB7D83D);
const Color darkGreen = Color(0xFF17200F);
const Color greyText = Color(0xFF899181);

// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  WeatherData? weatherData;
  bool weatherLoading = true;
  String? weatherError;

  StreamSubscription<QuerySnapshot>? _cropsSubscription;
  StreamSubscription<User?>? _authGuardSub;
  List<String> _cropNames = [];
  bool _cropsLoading = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectIfUnauthenticated();
    });
    _authGuardSub = _auth.authStateChanges().listen((user) {
      if (user == null) {
        _redirectIfUnauthenticated();
      }
    });
    loadWeather();
    _listenToCrops();
  }

  void _redirectIfUnauthenticated() {
    if (!mounted) return;
    if (AccountDeletionService.inProgress) return;
    if (_auth.currentUser != null) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _authGuardSub?.cancel();
    _cropsSubscription?.cancel();
    super.dispose();
  }


  void _listenToCrops() {
    _cropsSubscription?.cancel();
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _cropNames = [];
        _cropsLoading = false;
      });
      return;
    }

    _cropsSubscription = _firestore
        .collection('farmers')
        .doc(user.uid)
        .collection('crops')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        final names = snapshot.docs
            .map((doc) {
              final data = doc.data();
              return (data['cropName'] ?? data['name'] ?? '').toString().trim();
            })
            .where((name) => name.isNotEmpty)
            .toList();

        if (mounted) {
          setState(() {
            _cropNames = names;
            _cropsLoading = false;
          });
        }
      },
      onError: (e) {
        _cropsSubscription = _firestore
            .collection('farmers')
            .doc(user.uid)
            .collection('crops')
            .snapshots()
            .listen((snapshot) {
          final names = snapshot.docs
              .map((doc) {
                final data = doc.data();
                return (data['cropName'] ?? data['name'] ?? '').toString().trim();
              })
              .where((name) => name.isNotEmpty)
              .toList();

          if (mounted) {
            setState(() {
              _cropNames = names;
              _cropsLoading = false;
            });
          }
        });
      },
    );
  }

  // ==========================================================
  // LOAD WEATHER
  // ==========================================================

  Future<void> loadWeather() async {
    if (!mounted) return;

    setState(() {
      weatherLoading = true;
      weatherError = null;
    });

    try {
      final user = _auth.currentUser;
      final fetched = await WeatherService.fetchWeatherForUser(user?.uid);

      if (mounted) {
        setState(() {
          if (fetched != null) {
            weatherData = fetched;
            weatherError = null;
          } else if (weatherData == null) {
            weatherError = 'Offline';
          }
          weatherLoading = false;
        });
        if (fetched != null) {
          unawaited(_notifyFromWeather(fetched));
        }
      }
    } catch (e) {
      debugPrint('Dashboard weather error: $e');
      if (mounted) {
        setState(() {
          if (weatherData == null) {
            weatherError = 'Offline';
          }
          weatherLoading = false;
        });
      }
    }
  }

  Future<void> _notifyFromWeather(WeatherData weather) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final day = DateTime.now().toIso8601String().substring(0, 10);

    for (final advice in weather.farmingAdvices) {
      if (advice.type != AdviceType.alert && advice.type != AdviceType.warning) {
        continue;
      }

      final isDisease = advice.title.toLowerCase().contains('fungal');

      await NotificationService.addUniqueNotification(
        uid,
        title: isDisease ? 'Disease Alert' : 'Weather Alert',
        message: advice.advice,
        type: isDisease ? 'disease' : 'weather',
        targetPage: isDisease ? 'my_crops' : 'weather',
        dedupeKey: '$day-${advice.title}',
      );
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      // ========================================================
      // THREE LINE MENU
      // ========================================================

      drawer: FarmDrawer(weatherData: weatherData),

      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,

        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(
                Icons.menu,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),

        title: const Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Farm Manager',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(
              'Smart farming dashboard',
              style: TextStyle(
                color: greyText,
                fontSize: 11,
              ),
            ),
          ],
        ),

        actions: [
          StreamBuilder<int>(
            stream: NotificationService.getUnreadCountStream(_auth.currentUser?.uid),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      );
                    },
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                              color: Color(0xFF11140F),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: RefreshIndicator(
        color: primaryGreen,

        onRefresh: () async {
          _listenToCrops();
          await loadWeather();
        },


        child: SingleChildScrollView(
          physics:
          const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            30,
          ),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              // ==================================================
              // GREETING
              // ==================================================

              const Text(
                'Good Morning, Farmer! 🌱',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Plan your farm day with ease.',
                style: TextStyle(
                  color: greyText,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 22),

              // ==================================================
              // WEATHER
              // ==================================================

              WeatherCard(
                weather: weatherData,
                loading: weatherLoading,
                error: weatherError,
              ),

              const SizedBox(height: 16),

              // ==================================================
              // FARM HEALTH SCORE (display-only)
              // ==================================================

              const FarmHealthScoreCard(),

              const SizedBox(height: 16),

              // ==================================================
              // MY CROPS (display-only)
              // ==================================================

              MyCropsDisplayCard(
                cropNames: _cropNames,
                loading: _cropsLoading,
              ),

              const SizedBox(height: 25),

              const DailyTimeWorkSection(),

            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// WEATHER CARD
// ============================================================

class WeatherCard extends StatelessWidget {
  final WeatherData? weather;
  final bool loading;
  final String? error;

  const WeatherCard({
    super.key,
    this.weather,
    this.loading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final String tempText = weather != null
        ? '${weather!.temperature.round()}°C'
        : '--°C';

    final IconData icon =
        weather?.weatherIcon ?? Icons.cloud_outlined;

    final String conditionText = weather != null
        ? (weather!.locationName.isNotEmpty
            ? '${weather!.conditionText} • ${weather!.locationName}'
            : weather!.conditionText)
        : (loading
            ? 'Fetching live weather...'
            : (error != null
                ? 'Weather data unavailable.'
                : 'Weather information will appear here.'));

    final String humidityText = weather != null
        ? 'Humidity ${weather!.humidity}%'
        : 'Humidity --%';

    final circleSize =
        (MediaQuery.sizeOf(context).width * 0.28).clamp(84.0, 110.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryGreen.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primaryGreen.withOpacity(0.18),
                  darkGreen,
                ],
              ),
              border: Border.all(
                color: primaryGreen.withOpacity(0.35),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading && weather == null)
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      color: primaryGreen,
                      strokeWidth: 2.2,
                    ),
                  )
                else ...[
                  Icon(
                    icon,
                    color: primaryGreen,
                    size: circleSize < 96 ? 28 : 35,
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tempText,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Text(
                    'Weather',
                    style: TextStyle(
                      color: greyText,
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Today\u2019s Weather',
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (loading && weather != null) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  conditionText,
                  style: const TextStyle(
                    color: greyText,
                    fontSize: 12,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.water_drop_outlined,
                          color: primaryGreen,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          humidityText,
                          style: const TextStyle(
                            color: greyText,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (weather != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.air_rounded,
                            color: primaryGreen,
                            size: 17,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${weather!.windSpeed.round()} km/h',
                            style: const TextStyle(
                              color: greyText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FARM HEALTH SCORE (display-only)
// ============================================================

class FarmHealthScoreCard extends StatelessWidget {
  const FarmHealthScoreCard({super.key});

  static const Color _heart = Color(0xFFE57373);
  static const Color _heartSoft = Color(0xFF3A2224);

  Color _getStatusColor(String status) {
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

  String _getDefaultStatus(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Moderate';
    if (score >= 20) return 'Poor';
    return 'Critical';
  }

  int? _parseScore(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toInt().clamp(0, 100);
    if (val is String) {
      final parsed = num.tryParse(val.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null) return parsed.toInt().clamp(0, 100);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data ?? FirebaseAuth.instance.currentUser;
        if (user == null) {
          return _buildNotCalculatedCard();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('farmers')
              .doc(user.uid)
              .collection('farm_health')
              .doc('latest')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError ||
                !snapshot.hasData ||
                !snapshot.data!.exists ||
                snapshot.data!.data() == null) {
              return _buildNotCalculatedCard();
            }

            final data = snapshot.data!.data()!;
            final rawScore = data['score'] ??
                data['totalScore'] ??
                data['farmHealthScore'] ??
                data['healthScore'];
            final score = _parseScore(rawScore);

            if (score == null) {
              return _buildNotCalculatedCard();
            }

            final cropName = (data['cropName'] ??
                    data['selectedCrop'] ??
                    data['crop'] ??
                    '')
                .toString()
                .trim();
            final status = (data['status'] ??
                    data['healthStatus'] ??
                    _getDefaultStatus(score))
                .toString()
                .trim();
            final statusColor = _getStatusColor(status);

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    statusColor.withValues(alpha: 0.16),
                    const Color(0xFF1A2117),
                  ],
                ),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite_rounded, color: statusColor, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Farm Health Score',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (cropName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF17200F),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            cropName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 92,
                          height: 92,
                          child: CircularProgressIndicator(
                            value: score / 100,
                            strokeWidth: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            color: statusColor,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$score',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                            const Text(
                              '/ 100',
                              style: TextStyle(
                                color: greyText,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotCalculatedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF24181A),
            Color(0xFF1A2117),
          ],
        ),
        border: Border.all(
          color: _heart.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_rounded, color: _heart, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Farm Health Score',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 92,
                  height: 92,
                  child: CircularProgressIndicator(
                    value: 0,
                    strokeWidth: 8,
                    backgroundColor: _heartSoft,
                    color: _heart,
                  ),
                ),
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: darkGreen.withValues(alpha: 0.65),
                    border: Border.all(color: _heart.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    color: _heart,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Not Calculated',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFFC9B4B6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MY CROPS DISPLAY CARD (display-only)
// ============================================================

class MyCropsDisplayCard extends StatelessWidget {
  final List<String> cropNames;
  final bool loading;

  const MyCropsDisplayCard({
    super.key,
    required this.cropNames,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryGreen.withOpacity(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: darkGreen,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: primaryGreen.withOpacity(0.25),
                  ),
                ),
                child: const Icon(
                  Icons.grass_rounded,
                  color: primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Crops',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      loading
                          ? 'Loading...'
                          : cropNames.isEmpty
                              ? 'No crops registered'
                              : '${cropNames.length} crop${cropNames.length == 1 ? '' : 's'} registered',
                      style: const TextStyle(
                        color: greyText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Divider ──────────────────────────────────────────
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: primaryGreen.withOpacity(0.08),
          ),
          const SizedBox(height: 14),

          // ── Crop list ────────────────────────────────────────
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: primaryGreen,
                    strokeWidth: 2.2,
                  ),
                ),
              ),
            )
          else if (cropNames.isEmpty)
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF222E1A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.eco_outlined,
                    color: greyText,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'No Crops Added',
                  style: TextStyle(
                    color: greyText,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                for (int i = 0; i < cropNames.take(5).length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.75),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          cropNames[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (cropNames.length > 5) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: darkGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${cropNames.length - 5} more crops',
                      style: const TextStyle(
                        color: greyText,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}


// ============================================================
// DRAWER
// ============================================================

class FarmDrawer extends StatelessWidget {
  final WeatherData? weatherData;

  const FarmDrawer({
    super.key,
    this.weatherData,
  });

  // --------------------------------------------------------
  // LOGOUT HANDLER
  // --------------------------------------------------------

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to logout? Your account and all saved data will be permanently deleted.',
          style: TextStyle(color: greyText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: greyText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    var loadingShown = false;

    void showLoading() {
      if (!context.mounted || loadingShown) return;
      loadingShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(
            child: CircularProgressIndicator(color: primaryGreen),
          ),
        ),
      );
    }

    void hideLoading() {
      if (!context.mounted || !loadingShown) return;
      loadingShown = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    showLoading();

    try {
      await AccountDeletionService.deleteCurrentAccount(
        requestPassword: () async {
          hideLoading();
          if (!context.mounted) return null;
          final password = await _promptReauthPassword(context);
          if (password != null && password.isNotEmpty && context.mounted) {
            showLoading();
          }
          return password;
        },
      );

      hideLoading();
      if (!context.mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (_) => false,
      );
    } on AccountDeletionCancelled {
      hideLoading();
    } catch (e) {
      hideLoading();
      if (kDebugMode) {
        debugPrint('Account deletion failed: $e');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_deletionErrorMessage(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      AccountDeletionService.inProgress = false;
    }
  }

  Future<String?> _promptReauthPassword(BuildContext context) {
    final passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm your password',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'For security, enter your password to permanently delete this account.',
              style: TextStyle(color: greyText),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: const TextStyle(color: greyText),
                filled: true,
                fillColor: backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: greyText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, passwordController.text),
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ).whenComplete(passwordController.dispose);
  }

  String _deletionErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      if (error.code == 'wrong-password' ||
          error.code == 'invalid-credential') {
        return 'Incorrect password. Please try again.';
      }
    }
    if (error is FirebaseException &&
        error.code == 'daily-work-delete-failed') {
      return 'Unable to delete Daily Work data. Please try again.';
    }
    return 'Unable to delete your account. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: backgroundColor,

      child: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Container(
              width: double.infinity,

              padding: const EdgeInsets.fromLTRB(
                20,
                25,
                20,
                22,
              ),

              decoration: const BoxDecoration(
                color: cardColor,
              ),

              child: Row(
                children: [
                  Container(
                    width: 55,
                    height: 55,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: darkGreen,
                      border: Border.all(
                        color: primaryGreen,
                        width: 1.5,
                      ),
                    ),

                    child: const Icon(
                      Icons.agriculture,
                      color: primaryGreen,
                      size: 29,
                    ),
                  ),

                  const SizedBox(width: 14),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Farm Manager',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: 4),

                        Text(
                          'Smart Farming',
                          style: TextStyle(
                            color: greyText,
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
            ),

            const SizedBox(height: 8),

            // ==================================================
            // MENU ITEMS
            // ==================================================

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                ),

                children: [
                  const DrawerItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                  ),

                  DrawerItem(
                    icon: Icons.favorite_outline,
                    title: 'Farm Health Score',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FarmHealthPage(),
                        ),
                      );
                    },
                  ),

                  DrawerItem(
                    icon: Icons.grass_outlined,
                    title: 'My Crops',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyCropsPage(),
                        ),
                      );
                    },
                  ),

                  DrawerItem(
                    icon: Icons.support_agent_outlined,
                    title: 'Farm Mitra',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FarmMitraPage(),
                        ),
                      );
                    },
                  ),

                  DrawerItem(
                    icon: Icons.biotech_outlined,
                    title: 'Disease Detection',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DiseaseDetectionPage(),
                        ),
                      );
                    },
                  ),

                  DrawerItem(
                    icon: Icons.account_balance_outlined,
                    title: 'Government Schemes',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GovernmentSchemesPage(),
                        ),
                      );
                    },
                  ),

                  DrawerItem(
                    icon: Icons.trending_up_outlined,
                    title: 'Market Prices',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MarketPricesPage(),
                        ),
                      );
                    },
                  ),

                  DrawerItem(
                    icon: Icons.cloud_outlined,
                    title: 'Weather',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailedWeatherPage(
                            initialWeather: weatherData,
                          ),
                        ),
                      );
                    },
                  ),

                  // Notifications with real-time unread badge
                  StreamBuilder<int>(
                    stream: NotificationService.getUnreadCountStream(
                      FirebaseAuth.instance.currentUser?.uid,
                    ),
                    builder: (context, snapshot) {
                      final unread = snapshot.data ?? 0;
                      return DrawerItem(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        badge: unread > 0 ? (unread > 9 ? '9+' : '$unread') : null,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsPage(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // ==================================================
            // PROFILE + LOGOUT — fixed bottom section
            // ==================================================

            Container(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              child: DrawerItem(
                icon: Icons.person_outline,
                title: 'Profile',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfilePage(),
                    ),
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: DrawerItem(
                icon: Icons.logout,
                title: 'Logout',
                isLogout: true,
                onTap: () => _handleLogout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DRAWER ITEM
// ============================================================


class DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isLogout;
  final VoidCallback? onTap;
  final String? badge; // unread count string, e.g. "3" or "9+"

  const DrawerItem({
    super.key,
    required this.icon,
    required this.title,
    this.isLogout = false,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2,
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          onTap: onTap ?? () {},

          borderRadius: BorderRadius.circular(15),

          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 7,
            ),

            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,

                  decoration: BoxDecoration(
                    color: isLogout
                        ? Colors.red.withOpacity(0.08)
                        : darkGreen,

                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: Icon(
                    icon,
                    color: isLogout
                        ? Colors.redAccent
                        : primaryGreen,
                    size: 21,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isLogout
                          ? Colors.redAccent
                          : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Color(0xFF11140F),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                Icon(
                  Icons.chevron_right,
                  color: isLogout
                      ? Colors.redAccent.withOpacity(0.5)
                      : greyText,
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
