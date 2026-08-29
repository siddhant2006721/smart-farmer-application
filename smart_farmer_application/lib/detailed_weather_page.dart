import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'weather_service.dart';
import 'profile_page.dart';

// ============================================================
// COLORS - SAME STYLE AS DASHBOARD
// ============================================================

const Color backgroundColor = Color(0xFF0F130D);
const Color cardColor = Color(0xFF1A2117);
const Color cardColor2 = Color(0xFF20291B);
const Color primaryGreen = Color(0xFFB7D83D);
const Color darkGreen = Color(0xFF17200F);
const Color greyText = Color(0xFF899181);

class DetailedWeatherPage extends StatefulWidget {
  final WeatherData? initialWeather;

  const DetailedWeatherPage({
    super.key,
    this.initialWeather,
  });

  @override
  State<DetailedWeatherPage> createState() => _DetailedWeatherPageState();
}

class _DetailedWeatherPageState extends State<DetailedWeatherPage> {
  WeatherData? weather;
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    weather = widget.initialWeather;
    if (weather != null && weather!.hourly.isNotEmpty) {
      loading = false;
    }
    loadWeather();
  }

  Future<void> loadWeather() async {
    if (!mounted) return;
    if (weather == null) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      final fetched = await WeatherService.fetchWeatherForUser(user?.uid);

      if (mounted) {
        setState(() {
          if (fetched != null) {
            weather = fetched;
            errorMessage = null;
          } else if (weather == null) {
            errorMessage = 'Unable to load weather forecast. Please check your internet connection.';
          }
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (weather == null) {
            errorMessage = 'Error loading weather: $e';
          }
          loading = false;
        });
      }
    }
  }

  String formatHour(DateTime dt) {
    final now = DateTime.now();
    if (dt.hour == now.hour && dt.day == now.day) {
      return 'Now';
    }
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour $period';
  }

  String formatDayName(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              weather != null && weather!.locationName.isNotEmpty
                  ? weather!.locationName
                  : 'Farm Weather',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Detailed Forecast & Advisory',
              style: TextStyle(
                color: greyText,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryGreen,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                  ),
            onPressed: loading ? null : loadWeather,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: primaryGreen,
        backgroundColor: cardColor,
        onRefresh: loadWeather,
        child: loading && weather == null
            ? const Center(
                child: CircularProgressIndicator(
                  color: primaryGreen,
                ),
              )
            : errorMessage != null && weather == null
                ? _buildErrorView()
                : _buildContent(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: darkGreen,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: primaryGreen,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              errorMessage ?? 'Error loading weather',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: loadWeather,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: darkGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingLocationBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_off_rounded,
              color: Colors.amberAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Farm Location Not Configured',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Showing regional forecast for ${weather?.locationName.isNotEmpty == true ? weather!.locationName : "Maharashtra"}. Update your profile to get local farm weather.',
                  style: const TextStyle(
                    color: Color(0xFFB1B8A9),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfilePage(),
                      ),
                    ).then((_) => loadWeather());
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Set Location in Profile',
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: primaryGreen,
                          size: 14,
                        ),
                      ],
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

  Widget _buildContent() {
    final w = weather!;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If Firestore location was not configured, show guidance banner
          if (!w.hasFarmerLocation) _buildMissingLocationBanner(),

          // ==================================================
          // 1. HERO WEATHER OVERVIEW
          // ==================================================
          _buildHeroCard(w),

          const SizedBox(height: 20),

          // ==================================================
          // 2. FARMING ADVISORY SECTION
          // ==================================================
          _buildFarmingAdvisorySection(w),

          const SizedBox(height: 22),

          // ==================================================
          // 3. HOURLY FORECAST
          // ==================================================
          _buildHourlyForecastSection(w),

          const SizedBox(height: 22),

          // ==================================================
          // 4. 7-DAY FORECAST
          // ==================================================
          _build7DayForecastSection(w),

          const SizedBox(height: 22),

          // ==================================================
          // 5. WEATHER DETAILS GRID
          // ==================================================
          _buildWeatherDetailsGrid(w),

          const SizedBox(height: 20),

          // ==================================================
          // 6. SUNRISE & SUNSET
          // ==================================================
          _buildSunCard(w),
        ],
      ),
    );
  }

  // ============================================================
  // HERO CURRENT WEATHER CARD
  // ============================================================

  Widget _buildHeroCard(WeatherData w) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: primaryGreen.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${w.temperature.round()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const Text(
                        '°C',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    w.conditionText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Feels like ${w.apparentTemperature.round()}°C',
                    style: const TextStyle(
                      color: greyText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryGreen.withValues(alpha: 0.20),
                      darkGreen,
                    ],
                  ),
                  border: Border.all(
                    color: primaryGreen.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: Icon(
                  w.weatherIcon,
                  color: primaryGreen,
                  size: 48,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    icon: Icons.arrow_upward_rounded,
                    iconColor: Colors.orangeAccent,
                    label: 'High',
                    value: '${w.maxTempToday.round()}°C',
                  ),
                ),
                Container(
                  height: 25,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                Expanded(
                  child: _buildMiniStat(
                    icon: Icons.arrow_downward_rounded,
                    iconColor: Colors.lightBlueAccent,
                    label: 'Low',
                    value: '${w.minTempToday.round()}°C',
                  ),
                ),
                Container(
                  height: 25,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                Expanded(
                  child: _buildMiniStat(
                    icon: Icons.water_drop_outlined,
                    iconColor: primaryGreen,
                    label: 'Rain Chance',
                    value: '${w.rainProbability}%',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: greyText,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FARMING WEATHER ADVISORY SECTION
  // ============================================================

  Widget _buildFarmingAdvisorySection(WeatherData w) {
    final advices = w.farmingAdvices;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryGreen.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.eco_rounded,
                color: primaryGreen,
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Farming Weather Advisory',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Smart suggestions tailored for your daily farm activities',
            style: TextStyle(
              color: greyText,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 15),
          ...advices.map((advice) => _buildAdviceCard(advice)),
        ],
      ),
    );
  }

  Widget _buildAdviceCard(FarmingAdvice advice) {
    Color badgeColor;
    Color badgeTextColor;
    String badgeText;

    switch (advice.type) {
      case AdviceType.good:
        badgeColor = primaryGreen.withValues(alpha: 0.15);
        badgeTextColor = primaryGreen;
        badgeText = 'SUITABLE';
        break;
      case AdviceType.info:
        badgeColor = Colors.blueAccent.withValues(alpha: 0.15);
        badgeTextColor = Colors.lightBlueAccent;
        badgeText = 'NOTICE';
        break;
      case AdviceType.warning:
        badgeColor = Colors.amber.withValues(alpha: 0.18);
        badgeTextColor = Colors.amberAccent;
        badgeText = 'CAUTION';
        break;
      case AdviceType.alert:
        badgeColor = Colors.redAccent.withValues(alpha: 0.18);
        badgeTextColor = Colors.redAccent;
        badgeText = 'ALERT';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badgeTextColor.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              advice.icon,
              color: badgeTextColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        advice.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeTextColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  advice.advice,
                  style: const TextStyle(
                    color: Color(0xFFB1B8A9),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HOURLY FORECAST
  // ============================================================

  Widget _buildHourlyForecastSection(WeatherData w) {
    if (w.hourly.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryGreen.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: primaryGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hourly Forecast (Next 24h)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 115,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: w.hourly.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = w.hourly[index];
                final isNow = index == 0;

                return Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isNow ? darkGreen : cardColor2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isNow
                          ? primaryGreen
                          : Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatHour(item.time),
                        style: TextStyle(
                          color: isNow ? primaryGreen : greyText,
                          fontSize: 11,
                          fontWeight: isNow ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      Icon(
                        item.icon,
                        color: isNow ? primaryGreen : Colors.white,
                        size: 24,
                      ),
                      Text(
                        '${item.temperature.round()}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.precipitationProbability > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.water_drop,
                              color: Colors.lightBlueAccent,
                              size: 10,
                            ),
                            Text(
                              '${item.precipitationProbability}%',
                              style: const TextStyle(
                                color: Colors.lightBlueAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox(height: 10),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 7-DAY FORECAST
  // ============================================================

  Widget _build7DayForecastSection(WeatherData w) {
    if (w.daily.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryGreen.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: primaryGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '7-Day Farm Forecast',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...w.daily.map((day) {
            final isToday = formatDayName(day.date) == 'Today';

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 75,
                    child: Text(
                      formatDayName(day.date),
                      style: TextStyle(
                        color: isToday ? primaryGreen : Colors.white,
                        fontSize: 13,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    day.icon,
                    color: isToday ? primaryGreen : Colors.white,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      day.conditionText,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: greyText,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (day.precipitationProbability > 10)
                    Row(
                      children: [
                        const Icon(
                          Icons.water_drop,
                          color: Colors.lightBlueAccent,
                          size: 11,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${day.precipitationProbability}%',
                          style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  Row(
                    children: [
                      Text(
                        '${day.minTemp.round()}°',
                        style: const TextStyle(
                          color: greyText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${day.maxTemp.round()}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================
  // WEATHER DETAILS GRID (2x2 / 2x3 METRICS)
  // ============================================================

  Widget _buildWeatherDetailsGrid(WeatherData w) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDetailCard(
                icon: Icons.water_drop_outlined,
                title: 'Humidity',
                value: '${w.humidity}%',
                subtitle: w.humidity > 70
                    ? 'High moisture'
                    : (w.humidity < 40 ? 'Dry air' : 'Normal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailCard(
                icon: Icons.air_rounded,
                title: 'Wind',
                value: '${w.windSpeed.round()} km/h',
                subtitle: 'Direction: ${w.windDirectionText}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDetailCard(
                icon: Icons.grain_rounded,
                title: 'Precipitation',
                value: '${w.precipitation.toStringAsFixed(1)} mm',
                subtitle: '${w.rainProbability}% probability',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailCard(
                icon: Icons.wb_sunny_outlined,
                title: 'UV Index',
                value: w.uvIndex.toStringAsFixed(1),
                subtitle: w.uvIndex >= 8
                    ? 'Very High'
                    : (w.uvIndex >= 5 ? 'Moderate' : 'Low'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDetailCard(
                icon: Icons.visibility_outlined,
                title: 'Visibility',
                value: '${w.visibility.toStringAsFixed(1)} km',
                subtitle: w.visibility >= 10 ? 'Clear visibility' : 'Hazy / Low',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailCard(
                icon: Icons.thermostat_outlined,
                title: 'Feels Like',
                value: '${w.apparentTemperature.round()}°C',
                subtitle: 'Actual: ${w.temperature.round()}°C',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryGreen.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: darkGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: primaryGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: greyText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF9AA192),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUNRISE & SUNSET CARD
  // ============================================================

  Widget _buildSunCard(WeatherData w) {
    if (w.sunrise.isEmpty && w.sunset.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: primaryGreen.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.wb_twilight_rounded,
                    color: Colors.orangeAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sunrise',
                        style: TextStyle(
                          color: greyText,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        w.sunrise.isNotEmpty ? w.sunrise : '--',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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
          Container(
            height: 35,
            width: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.nights_stay_rounded,
                    color: Colors.pinkAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sunset',
                        style: TextStyle(
                          color: greyText,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        w.sunset.isNotEmpty ? w.sunset : '--',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}
