import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'market_price_service.dart';
import 'profile_page.dart';

class MarketPricesPage extends StatefulWidget {
  const MarketPricesPage({super.key});

  @override
  State<MarketPricesPage> createState() => _MarketPricesPageState();
}

class _MarketPricesPageState extends State<MarketPricesPage> {
  // Theme Colors matching the application
  static const Color _bg = Color(0xFF11140F);
  static const Color _card = Color(0xFF1B2018);
  static const Color _card2 = Color(0xFF20291B);
  static const Color _accent = Color(0xFFB7D83D);
  static const Color _darkAccent = Color(0xFF17200F);
  static const Color _grey = Color(0xFF9FA59A);
  static const Color _inputBg = Color(0xFF11150F);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Profile Location (Read-only, loaded from Firestore)
  String? _profileState;
  String? _profileDistrict;

  bool _loadingProfile = true;
  bool _loadingPrices = false;
  String? _error;

  List<MarketPriceRecord> _records = [];
  List<String> _tradedCrops = [];
  String _activeCropFilter = '';

  @override
  void initState() {
    super.initState();
    _loadProfileAndPrices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // 1. LOAD PROFILE FROM FIRESTORE AND FETCH DISTRICT PRICES
  // ----------------------------------------------------------
  Future<void> _loadProfileAndPrices({bool forceRefresh = false}) async {
    setState(() {
      _loadingProfile = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    final loc = await MarketPriceService.getFarmerProfileLocation(user?.uid);

    final state = loc['state'];
    final district = loc['district'];

    if (!mounted) return;

    if (state == null || district == null || state.isEmpty || district.isEmpty) {
      setState(() {
        _profileState = null;
        _profileDistrict = null;
        _loadingProfile = false;
      });
      return;
    }

    setState(() {
      _profileState = state;
      _profileDistrict = district;
      _loadingProfile = false;
    });

    await _fetchMarketPrices(forceRefresh: forceRefresh);
  }

  // ----------------------------------------------------------
  // 2. FETCH MARKET PRICES FOR PROFILE DISTRICT
  // ----------------------------------------------------------
  Future<void> _fetchMarketPrices({bool forceRefresh = false}) async {
    if (_profileState == null || _profileDistrict == null) return;

    setState(() {
      _loadingPrices = true;
      _error = null;
    });

    try {
      final query = _searchController.text.trim();
      final cropQuery = query.isNotEmpty
          ? query
          : (_activeCropFilter.isNotEmpty ? _activeCropFilter : null);

      if (cropQuery != null && cropQuery.isNotEmpty) {
        await MarketPriceService.saveLastSearchedCommodity(
          FirebaseAuth.instance.currentUser?.uid,
          cropQuery,
        );
      }

      final results = await MarketPriceService.searchCropsInDistrict(
        state: _profileState!,
        district: _profileDistrict!,
        cropQuery: cropQuery,
      );

      final availableCrops = await MarketPriceService.getTradedCropsInDistrict(
        state: _profileState!,
        district: _profileDistrict!,
      );

      if (mounted) {
        setState(() {
          _records = results;
          _tradedCrops = availableCrops;
          _loadingPrices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load market prices. Please check your network or try again.';
          _loadingPrices = false;
        });
      }
    }
  }

  // ----------------------------------------------------------
  // API KEY CONFIGURATION MODAL
  // ----------------------------------------------------------
  Future<void> _openApiKeyDialog() async {
    final currentKey = await MarketPriceService.getApiKey();
    final keyController = TextEditingController(text: currentKey);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: _accent, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'AGMARKNET API Key',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure your official data.gov.in API key for live AGMARKNET Mandi rates.',
              style: TextStyle(color: _grey, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: keyController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter data.gov.in API Key',
                hintStyle: const TextStyle(color: Color(0xFF686F64), fontSize: 12),
                filled: true,
                fillColor: _inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _accent, width: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Get a free API key at: https://data.gov.in',
              style: TextStyle(color: _accent, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newKey = keyController.text.trim();
              if (newKey.isNotEmpty) {
                await MarketPriceService.saveApiKey(newKey);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              _fetchMarketPrices(forceRefresh: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: _darkAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Key', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
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
              child: _loadingProfile
                  ? const Center(child: CircularProgressIndicator(color: _accent))
                  : (_profileState == null || _profileDistrict == null)
                      ? _buildMissingProfileView()
                      : RefreshIndicator(
                          color: _accent,
                          onRefresh: () => _loadProfileAndPrices(forceRefresh: true),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Read-only Location Badge
                                _buildLocationBadge(),
                                const SizedBox(height: 16),

                                // 2. Crop Search Bar
                                _buildCropSearchBar(),
                                const SizedBox(height: 14),

                                // 3. Traded Crops Quick Chips in District
                                if (_tradedCrops.isNotEmpty) ...[
                                  _buildTradedCropsChips(),
                                  const SizedBox(height: 18),
                                ],

                                // 4. Real Market Price Results
                                _buildResultsSection(),
                              ],
                            ),
                          ),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.trending_up_rounded, color: _darkAccent, size: 26),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Market Prices',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Official AGMARKNET APMC Mandi Rates',
                  style: TextStyle(
                    color: _grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openApiKeyDialog,
            icon: const Icon(Icons.key_rounded, color: _accent, size: 22),
            tooltip: 'Configure data.gov.in API Key',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 1. READ-ONLY LOCATION BADGE (AUTOMATIC FROM FIRESTORE)
  // ============================================================
  Widget _buildLocationBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded, color: _accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your District Mandis',
                  style: TextStyle(
                    color: _grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '📍 $_profileDistrict, $_profileState',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Text(
              'Profile Location',
              style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 2. CROP SEARCH BAR
  // ============================================================
  Widget _buildCropSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search crop (e.g. Onion, Soybean, Wheat, Tomato)...',
                hintStyle: const TextStyle(color: Color(0xFF686F64), fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: _accent, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: _grey, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _activeCropFilter = '';
                          });
                          _fetchMarketPrices();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              onSubmitted: (_) {
                setState(() {
                  _activeCropFilter = _searchController.text.trim();
                });
                _fetchMarketPrices();
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _activeCropFilter = _searchController.text.trim();
            });
            _fetchMarketPrices();
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Search',
              style: TextStyle(
                color: _darkAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 3. TRADED CROPS CHIPS IN DISTRICT
  // ============================================================
  Widget _buildTradedCropsChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Traded Crops in $_profileDistrict (${_tradedCrops.length}):',
                style: const TextStyle(color: _grey, fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_activeCropFilter.isNotEmpty || _searchController.text.isNotEmpty) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _activeCropFilter = '';
                  });
                  _fetchMarketPrices();
                },
                child: const Text(
                  'View All',
                  style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // "All Crops" Chip
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('All Crops'),
                  selected: _activeCropFilter.isEmpty && _searchController.text.isEmpty,
                  selectedColor: _accent,
                  backgroundColor: _card,
                  labelStyle: TextStyle(
                    color: (_activeCropFilter.isEmpty && _searchController.text.isEmpty)
                        ? _darkAccent
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(
                    color: (_activeCropFilter.isEmpty && _searchController.text.isEmpty)
                        ? _accent
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _searchController.clear();
                      setState(() {
                        _activeCropFilter = '';
                      });
                      _fetchMarketPrices();
                    }
                  },
                ),
              ),
              // Dynamic crop chips
              ..._tradedCrops.map((crop) {
                final isSelected = _activeCropFilter.toLowerCase() == crop.toLowerCase() ||
                    _searchController.text.trim().toLowerCase() == crop.toLowerCase();

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(crop),
                    selected: isSelected,
                    selectedColor: _accent,
                    backgroundColor: _card,
                    labelStyle: TextStyle(
                      color: isSelected ? _darkAccent : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 11,
                    ),
                    side: BorderSide(
                      color: isSelected ? _accent : Colors.white.withValues(alpha: 0.08),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        _searchController.text = crop;
                        setState(() {
                          _activeCropFilter = crop;
                        });
                        _fetchMarketPrices();
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 4. RESULTS SECTION (ALL APMC MANDIS IN DISTRICT)
  // ============================================================
  Widget _buildResultsSection() {
    if (_loadingPrices) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const CircularProgressIndicator(color: _accent),
              const SizedBox(height: 16),
              Text(
                'Fetching latest mandi rates for $_profileDistrict...',
                style: TextStyle(color: _grey.withValues(alpha: 0.9), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _fetchMarketPrices(forceRefresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: _darkAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _darkAccent,
              ),
              child: const Icon(Icons.info_outline, color: _accent, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Market Price Available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No market price available for this crop right now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _grey, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _activeCropFilter = '';
                });
                _searchFocusNode.requestFocus();
                _fetchMarketPrices();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _darkAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Try another crop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    final latestDate = _records.first.arrivalDate;
    final distinctMarkets = _records.map((r) => r.market).toSet().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusBanner(
          title: '$_profileDistrict District Market Prices',
          subtitle: 'Arrival Date: $latestDate • Source: AGMARKNET (GoI)',
          badgeText: '$distinctMarkets Mandis (${_records.length} Records)',
        ),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _records.length,
          separatorBuilder: (_, index) => const SizedBox(height: 14),
          itemBuilder: (_, index) => _buildPriceCard(_records[index]),
        ),
      ],
    );
  }

  // ============================================================
  // MISSING PROFILE VIEW
  // ============================================================
  Widget _buildMissingProfileView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _darkAccent,
                ),
                child: const Icon(Icons.person_pin_circle_outlined, color: _accent, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Complete Your Profile',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please complete your profile with your State and District to view local market prices.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                  _loadProfileAndPrices(forceRefresh: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: _darkAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
                label: const Text('Update Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner({
    required String title,
    required String subtitle,
    required String badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _accent.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: _accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                color: _accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MARKET PRICE CARD (DISPLAYING REAL OFFICIAL DATA)
  // ============================================================
  Widget _buildPriceCard(MarketPriceRecord record) {
    final currencyFormat = NumberFormat('#,##0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _accent.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crop and Mandi Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _darkAccent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _accent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.agriculture_rounded,
                  color: _accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          record.commodity,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (record.variety.isNotEmpty && record.variety != 'Other')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _inputBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              record.variety,
                              style: const TextStyle(color: _grey, fontSize: 10),
                            ),
                          ),
                        if (record.grade.isNotEmpty && record.grade != 'FAQ')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _inputBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              record.grade,
                              style: const TextStyle(color: _accent, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${record.market} APMC • ${record.district}, ${record.state}',
                      style: const TextStyle(
                        color: _grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (record.arrivalDate.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _card2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record.arrivalDate,
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 3-Column Price Metrics
          Row(
            children: [
              // Minimum Price
              Expanded(
                child: _buildPriceMetric(
                  label: 'Minimum Price',
                  price: '₹${currencyFormat.format(record.minPrice.round())}',
                  unit: record.priceUnit,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 8),

              // Modal Price (Prominent)
              Expanded(
                child: _buildPriceMetric(
                  label: 'Modal Price',
                  price: '₹${currencyFormat.format(record.modalPrice.round())}',
                  unit: record.priceUnit,
                  color: _accent,
                  isHighlighted: true,
                ),
              ),
              const SizedBox(width: 8),

              // Maximum Price
              Expanded(
                child: _buildPriceMetric(
                  label: 'Maximum Price',
                  price: '₹${currencyFormat.format(record.maxPrice.round())}',
                  unit: record.priceUnit,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceMetric({
    required String label,
    required String price,
    required String unit,
    required Color color,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isHighlighted ? _darkAccent : _inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? _accent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isHighlighted ? _accent : _grey,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            price,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            style: const TextStyle(
              color: _grey,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
