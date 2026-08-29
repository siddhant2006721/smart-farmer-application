import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// MARKET PRICE RECORD MODEL
// ============================================================

class MarketPriceRecord {
  final String commodity;
  final String variety;
  final String grade;
  final String market;
  final String district;
  final String state;
  final double minPrice;
  final double maxPrice;
  final double modalPrice;
  final String priceUnit;
  final String arrivalDate;
  final DateTime? fetchedAt;

  MarketPriceRecord({
    required this.commodity,
    required this.variety,
    this.grade = 'FAQ',
    required this.market,
    required this.district,
    required this.state,
    required this.minPrice,
    required this.maxPrice,
    required this.modalPrice,
    this.priceUnit = '₹/Quintal',
    required this.arrivalDate,
    this.fetchedAt,
  });

  static String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }

  factory MarketPriceRecord.fromJson(Map<String, dynamic> json) {
    double parsePrice(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      final str = val.toString().replaceAll(',', '').trim();
      return double.tryParse(str) ?? 0.0;
    }

    final rawState = (json['state'] ?? '').toString().trim();
    final rawDistrict = (json['district'] ?? '').toString().trim();
    final rawMarket = (json['market'] ?? '').toString().trim();
    final rawCommodity = (json['commodity'] ?? '').toString().trim();
    final rawVariety = (json['variety'] ?? 'Other').toString().trim();
    final rawGrade = (json['grade'] ?? json['Grade'] ?? 'FAQ').toString().trim();

    return MarketPriceRecord(
      commodity: rawCommodity.isNotEmpty ? toTitleCase(rawCommodity) : 'Unknown',
      variety: rawVariety.isNotEmpty ? toTitleCase(rawVariety) : 'Other',
      grade: rawGrade.isNotEmpty ? rawGrade : 'FAQ',
      market: rawMarket.isNotEmpty ? toTitleCase(rawMarket) : 'Unknown Mandi',
      district: rawDistrict.isNotEmpty ? toTitleCase(rawDistrict) : 'Unknown District',
      state: rawState.isNotEmpty ? toTitleCase(rawState) : 'Unknown State',
      minPrice: parsePrice(json['min_price'] ?? json['minPrice']),
      maxPrice: parsePrice(json['max_price'] ?? json['maxPrice']),
      modalPrice: parsePrice(json['modal_price'] ?? json['modalPrice']),
      priceUnit: (json['price_unit'] ?? '₹/Quintal').toString().trim(),
      arrivalDate: (json['arrival_date'] ?? json['arrivalDate'] ?? '').toString().trim(),
      fetchedAt: json['fetched_at'] != null
          ? DateTime.tryParse(json['fetched_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'commodity': commodity,
        'variety': variety,
        'grade': grade,
        'market': market,
        'district': district,
        'state': state,
        'min_price': minPrice,
        'max_price': maxPrice,
        'modal_price': modalPrice,
        'price_unit': priceUnit,
        'arrival_date': arrivalDate,
        'fetched_at': fetchedAt?.toIso8601String(),
      };
}

// ============================================================
// MARKET PRICE SERVICE (PROFILE-DRIVEN AGMARKNET)
// ============================================================

class MarketPriceService {
  static const String resourceId = '9ef84268-d588-465a-a308-a864a43d0070';
  static const String baseUrl = 'https://api.data.gov.in/resource/$resourceId';

  // Open Government Data India (data.gov.in) key
  static const String defaultApiKey = '579b464db66ec23bdd000001cdd3946e44ce4aad7209ff7b23ac571b';

  // In-memory cache for district records: key = 'state_district'
  static final Map<String, List<MarketPriceRecord>> _districtRecordCache = {};

  static void clearMemoryCache() {
    _districtRecordCache.clear();
  }

  // ----------------------------------------------------------
  // API KEY STORAGE
  // ----------------------------------------------------------
  static Future<String> getApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = prefs.getString('data_gov_in_api_key');
      if (userKey != null && userKey.trim().isNotEmpty) {
        return userKey.trim();
      }
    } catch (_) {}
    return defaultApiKey;
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('data_gov_in_api_key', key.trim());
  }

  // ----------------------------------------------------------
  // 1. GET LOCATION DIRECTLY FROM FARMER'S FIRESTORE PROFILE
  // ----------------------------------------------------------
  static Future<Map<String, String?>> getFarmerProfileLocation(String? userId) async {
    if (userId == null) {
      return {'state': null, 'district': null, 'village': null};
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('farmers')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final state = (data['state'] ?? '').toString().trim();
        final district = (data['district'] ?? '').toString().trim();
        final village = (data['village'] ?? '').toString().trim();

        return {
          'state': state.isNotEmpty ? MarketPriceRecord.toTitleCase(state) : null,
          'district': district.isNotEmpty ? MarketPriceRecord.toTitleCase(district) : null,
          'village': village.isNotEmpty ? MarketPriceRecord.toTitleCase(village) : null,
        };
      }
    } catch (e) {
      debugPrint('MarketPriceService: Firestore profile read error: $e');
    }

    return {'state': null, 'district': null, 'village': null};
  }

  // ----------------------------------------------------------
  // COMMODITY ALIASES & SEARCH HELPERS
  // ----------------------------------------------------------
  static const Map<String, List<String>> _commodityAliases = {
    'onion': ['Onion'],
    'pyaj': ['Onion'],
    'kanda': ['Onion'],
    'soybean': ['Soyabean', 'Soybean'],
    'soya': ['Soyabean', 'Soybean'],
    'wheat': ['Wheat', 'Kanak(Wheat)'],
    'gehun': ['Wheat'],
    'tomato': ['Tomato'],
    'tamatar': ['Tomato'],
    'cotton': ['Cotton', 'Cotton (Unginned)'],
    'kapas': ['Cotton'],
    'maize': ['Maize'],
    'makka': ['Maize'],
    'corn': ['Maize'],
    'potato': ['Potato'],
    'aloo': ['Potato'],
    'gram': ['Bengal Gram(Gram)(Whole)', 'Gram Raw(Chholia)', 'Gram', 'Chana'],
    'chana': ['Bengal Gram(Gram)(Whole)', 'Gram Raw(Chholia)', 'Gram', 'Chana'],
    'sugarcane': ['Sugarcane', 'Gur(Jaggery)'],
    'ganna': ['Sugarcane'],
    'rice': ['Paddy(Dhan)(Common)', 'Paddy(Dhan)(Basmati)', 'Rice'],
    'paddy': ['Paddy(Dhan)(Common)', 'Paddy(Dhan)(Basmati)', 'Rice'],
    'dhan': ['Paddy(Dhan)(Common)', 'Paddy(Dhan)(Basmati)', 'Rice'],
    'mustard': ['Mustard', 'Mustard Oil'],
    'sarson': ['Mustard'],
    'rai': ['Mustard'],
    'groundnut': ['Groundnut', 'Groundnut (Split)'],
    'peanut': ['Groundnut'],
    'mungfali': ['Groundnut'],
    'banana': ['Banana', 'Banana - Green'],
    'kela': ['Banana'],
    'apple': ['Apple'],
    'seb': ['Apple'],
    'mango': ['Mango', 'Mango (Raw-Ripe)'],
    'aam': ['Mango'],
    'moong': ['Green Gram (Moong)(Whole)', 'Moong(Mung)'],
    'urad': ['Black Gram (Urd Beans)(Whole)', 'Urad'],
    'tur': ['Arhar (Tur/Red Gram)(Whole)', 'Tur'],
    'arhar': ['Arhar (Tur/Red Gram)(Whole)', 'Tur'],
    'ginger': ['Ginger(Green)', 'Ginger(Dry)'],
    'adrak': ['Ginger(Green)'],
    'garlic': ['Garlic'],
    'lahsun': ['Garlic'],
    'chilli': ['Green Chilli', 'Chilli Red', 'Dry Chillies'],
    'mirchi': ['Green Chilli', 'Chilli Red'],
    'turmeric': ['Turmeric', 'Turmeric (raw)'],
    'haldi': ['Turmeric'],
    'bajra': ['Bajra(Pearl Millet/Cumbu)'],
    'jowar': ['Jowar(Sorghum)'],
    'brinjal': ['Brinjal'],
    'cabbage': ['Cabbage'],
    'cauliflower': ['Cauliflower'],
    'coriander': ['Coriander(Leaves)'],
    'cucumber': ['Cucumber(Kheera)'],
    'guava': ['Guava'],
    'lemon': ['Lemon'],
    'lime': ['Lemon'],
    'orange': ['Orange'],
    'papaya': ['Papaya'],
    'pomegranate': ['Pomegranate'],
    'watermelon': ['Water Melon'],
  };

  static List<String> getSearchAliases(String query) {
    final clean = query.trim().toLowerCase();
    for (final entry in _commodityAliases.entries) {
      if (clean == entry.key || clean.contains(entry.key) || entry.key.contains(clean)) {
        return entry.value;
      }
    }
    return [query.trim()];
  }

  // ----------------------------------------------------------
  // 2. FETCH ALL MARKET RECORDS FOR FARMER'S DISTRICT
  // ----------------------------------------------------------
  // 2. FETCH ALL MARKET RECORDS FOR FARMER'S DISTRICT
  // ----------------------------------------------------------
  static Future<List<MarketPriceRecord>> fetchAllRecordsForDistrict({
    required String state,
    required String district,
    bool forceRefresh = false,
  }) async {
    final cleanState = state.trim();
    final cleanDistrict = district.trim();
    final cacheKey = '${cleanState.toLowerCase()}_${cleanDistrict.toLowerCase()}';

    if (!forceRefresh &&
        _districtRecordCache.containsKey(cacheKey) &&
        _districtRecordCache[cacheKey]!.isNotEmpty) {
      debugPrint('MarketPriceService: Returning ${_districtRecordCache[cacheKey]!.length} records from memory cache.');
      return _districtRecordCache[cacheKey]!;
    }

    final apiKey = await getApiKey();
    final List<MarketPriceRecord> records = [];
    const int pageSize = 100;

    try {
      // 1. Query with filters for State & District in a single safe request
      final uri = Uri.parse(baseUrl).replace(queryParameters: {
        'api-key': apiKey,
        'format': 'json',
        'limit': pageSize.toString(),
        'offset': '0',
        'filters[state]': cleanState,
        'filters[district]': cleanDistrict,
      });

      debugPrint('MarketPriceService: Requesting market prices for state="$cleanState", district="$cleanDistrict"');
      http.Response res = await http.get(uri).timeout(const Duration(seconds: 12));

      debugPrint('MarketPriceService: HTTP Status Code = ${res.statusCode}');

      // If rate-limited (429), retry once after a short backoff
      if (res.statusCode == 429) {
        debugPrint('MarketPriceService: 429 received, retrying once after delay...');
        await Future.delayed(const Duration(milliseconds: 1500));
        res = await http.get(uri).timeout(const Duration(seconds: 12));
        debugPrint('MarketPriceService: Retry HTTP Status Code = ${res.statusCode}');
      }

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body['records'] as List?;
        debugPrint('MarketPriceService: Response contains data = ${list != null && list.isNotEmpty}, raw records count = ${list?.length ?? 0}');

        if (list != null && list.isNotEmpty) {
          final parsed = list
              .map((r) => MarketPriceRecord.fromJson(Map<String, dynamic>.from(r)))
              .where((r) => r.modalPrice > 0 || r.minPrice > 0 || r.maxPrice > 0)
              .toList();

          records.addAll(parsed);
          debugPrint('MarketPriceService: Parsed valid priced records = ${records.length}');
          if (records.isNotEmpty) {
            final sample = records.first;
            debugPrint('MarketPriceService: Sample record: commodity="${sample.commodity}", min=${sample.minPrice}, max=${sample.maxPrice}, modal=${sample.modalPrice}');
          }
        }
      }

      // If district-level query returned 0 records (e.g. spelling variation in data.gov.in),
      // perform a single state-level fallback query and filter locally
      if (records.isEmpty) {
        debugPrint('MarketPriceService: No records from exact district filter. Trying state fallback for "$cleanState"...');
        final stateRecords = await _fetchStateRecordsFallback(cleanState, apiKey);
        final matchedInDistrict = stateRecords.where((r) {
          final rDist = r.district.toLowerCase();
          final targetDist = cleanDistrict.toLowerCase();
          return rDist.contains(targetDist) || targetDist.contains(rDist);
        }).toList();

        if (matchedInDistrict.isNotEmpty) {
          records.addAll(matchedInDistrict);
          debugPrint('MarketPriceService: State fallback matched ${records.length} records for district "$cleanDistrict".');
        }
      }

      if (records.isNotEmpty) {
        _districtRecordCache[cacheKey] = records;
        _cacheDistrictLocally(cacheKey, records);
        return records;
      }
    } catch (e) {
      debugPrint('MarketPriceService: District fetch error: $e');
    }

    // Check offline persistent cache
    final cached = await _getCachedDistrictLocally(cacheKey);
    if (cached.isNotEmpty) {
      debugPrint('MarketPriceService: Returning ${cached.length} records from offline storage cache.');
      _districtRecordCache[cacheKey] = cached;
      return cached;
    }

    debugPrint('MarketPriceService: No records found for "$cleanDistrict, $cleanState".');
    return records;
  }

  // ----------------------------------------------------------
  // 3. SEARCH CROPS IN DISTRICT (CASE-INSENSITIVE & ALL APMCS)
  // ----------------------------------------------------------
  static Future<List<MarketPriceRecord>> searchCropsInDistrict({
    required String state,
    required String district,
    String? cropQuery,
  }) async {
    final districtRecords = await fetchAllRecordsForDistrict(
      state: state,
      district: district,
    );

    if (cropQuery == null || cropQuery.trim().isEmpty || cropQuery == 'All Crops') {
      return districtRecords;
    }

    final aliases = getSearchAliases(cropQuery);

    final filtered = districtRecords.where((r) {
      final commLower = r.commodity.toLowerCase();
      for (final a in aliases) {
        final aLower = a.toLowerCase();
        if (commLower.contains(aLower) || aLower.contains(commLower)) {
          return true;
        }
      }
      return false;
    }).toList();

    return filtered;
  }

  // ----------------------------------------------------------
  // 4. GET ACTIVE TRADED CROPS IN DISTRICT
  // ----------------------------------------------------------
  static Future<List<String>> getTradedCropsInDistrict({
    required String state,
    required String district,
  }) async {
    final districtRecords = await fetchAllRecordsForDistrict(
      state: state,
      district: district,
    );

    final Map<String, String> normalized = {};
    for (final r in districtRecords) {
      if (r.commodity.isNotEmpty && r.commodity != 'Unknown') {
        final title = MarketPriceRecord.toTitleCase(r.commodity);
        normalized[title.toLowerCase()] = title;
      }
    }

    final sorted = normalized.values.toList()..sort();
    return sorted;
  }

  // ----------------------------------------------------------
  // LAST SEARCHED COMMODITY (FOR DASHBOARD CARD)
  // ----------------------------------------------------------
  static String _lastCommodityKey(String userId) =>
      'last_market_commodity_$userId';

  static Future<void> saveLastSearchedCommodity(
    String? userId,
    String commodity,
  ) async {
    if (userId == null) return;
    final trimmed = commodity.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'all crops') return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCommodityKey(userId), trimmed);
    } catch (_) {}
  }

  static Future<String?> getLastSearchedCommodity(String? userId) async {
    if (userId == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_lastCommodityKey(userId));
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _firstFarmerCropName(String userId) async {
    try {
      QuerySnapshot snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('farmers')
            .doc(userId)
            .collection('crops')
            .orderBy('createdAt', descending: true)
            .limit(8)
            .get();
      } catch (_) {
        snap = await FirebaseFirestore.instance
            .collection('farmers')
            .doc(userId)
            .collection('crops')
            .limit(8)
            .get();
      }

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final name = (data['cropName'] ?? data['name'] ?? '').toString().trim();
        if (name.isNotEmpty) return name;
      }
    } catch (e) {
      debugPrint('MarketPriceService: farmer crop read error: $e');
    }
    return null;
  }

  // ----------------------------------------------------------
  // DASHBOARD SUMMARY (PROFILE DISTRICT + SEARCHED CROP)
  // ----------------------------------------------------------
  static Future<List<MarketPriceRecord>> fetchDashboardPrices(String? userId) async {
    if (userId == null) return [];

    final loc = await getFarmerProfileLocation(userId);
    final state = loc['state'];
    final district = loc['district'];
    if (state == null ||
        district == null ||
        state.trim().isEmpty ||
        district.trim().isEmpty) {
      return [];
    }

    String? commodity = await getLastSearchedCommodity(userId);
    commodity ??= await _firstFarmerCropName(userId);
    if (commodity == null || commodity.isEmpty) {
      return [];
    }

    final records = await searchCropsInDistrict(
      state: state,
      district: district,
      cropQuery: commodity,
    );

    final priced = records
        .where((r) => r.modalPrice > 0 || r.minPrice > 0 || r.maxPrice > 0)
        .toList();
    if (priced.isEmpty) return [];

    priced.sort((a, b) {
      final aPrice = a.modalPrice > 0 ? a.modalPrice : a.minPrice;
      final bPrice = b.modalPrice > 0 ? b.modalPrice : b.minPrice;
      return bPrice.compareTo(aPrice);
    });

    return [priced.first];
  }

  // ----------------------------------------------------------
  // STATE-WIDE FALLBACK HELPER
  // ----------------------------------------------------------
  static Future<List<MarketPriceRecord>> _fetchStateRecordsFallback(String state, String apiKey) async {
    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: {
        'api-key': apiKey,
        'format': 'json',
        'limit': '100',
        'offset': '0',
        'filters[state]': state.trim(),
      });
      debugPrint('MarketPriceService: Requesting state fallback prices for state="${state.trim()}"');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('MarketPriceService: State fallback HTTP Status = ${res.statusCode}');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body['records'] as List?;
        if (list != null && list.isNotEmpty) {
          final records = list
              .map((r) => MarketPriceRecord.fromJson(Map<String, dynamic>.from(r)))
              .where((r) => r.modalPrice > 0 || r.minPrice > 0 || r.maxPrice > 0)
              .toList();
          debugPrint('MarketPriceService: State fallback loaded ${records.length} records.');
          return records;
        }
      }
    } catch (e) {
      debugPrint('MarketPriceService: State fallback error: $e');
    }
    return [];
  }

  // ----------------------------------------------------------
  // LOCAL CACHE PERSISTENCE
  // ----------------------------------------------------------
  static Future<void> _cacheDistrictLocally(String cacheKey, List<MarketPriceRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'cache_market_dist_$cacheKey';
      final jsonList = records.map((r) => r.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<List<MarketPriceRecord>> _getCachedDistrictLocally(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'cache_market_dist_$cacheKey';
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        final List list = jsonDecode(jsonString);
        return list
            .map((item) => MarketPriceRecord.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
