import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ============================================================
// CROP MODEL
// ============================================================

class CropModel {
  final String id;
  final String name;
  final String variety;
  final String area;
  final String season;
  final String sowingDate;
  final dynamic createdAt;

  CropModel({
    required this.id,
    required this.name,
    this.variety = '',
    this.area = '',
    this.season = '',
    this.sowingDate = '',
    this.createdAt,
  });

  factory CropModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CropModel(
      id: doc.id,
      name: (data['cropName'] ?? data['name'] ?? '').toString().trim(),
      variety: (data['variety'] ?? '').toString().trim(),
      area: (data['area'] ?? '').toString().trim(),
      season: (data['season'] ?? '').toString().trim(),
      sowingDate: (data['sowingDate'] ?? '').toString().trim(),
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cropName': name,
      'name': name,
      'variety': variety,
      'area': area,
      'season': season,
      'sowingDate': sowingDate,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

// ============================================================
// MY CROPS PAGE
// ============================================================

class MyCropsPage extends StatefulWidget {
  const MyCropsPage({super.key});

  @override
  State<MyCropsPage> createState() => _MyCropsPageState();
}

class _MyCropsPageState extends State<MyCropsPage> {
  // Theme Colors matching the application
  static const Color _bg = Color(0xFF11140F);
  static const Color _card = Color(0xFF1B2018);
  static const Color _card2 = Color(0xFF20291B);
  static const Color _accent = Color(0xFFB7D83D);
  static const Color _darkAccent = Color(0xFF17200F);
  static const Color _grey = Color(0xFF9FA59A);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ------------------------------------------------------------
  // OPEN ADD / EDIT BOTTOM SHEET
  // ------------------------------------------------------------

  void _openCropSheet({CropModel? existingCrop}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CropFormSheet(
        existingCrop: existingCrop,
        onSave: (name, variety, area, season, sowingDate) async {
          await _saveCropToFirestore(
            cropId: existingCrop?.id,
            name: name,
            variety: variety,
            area: area,
            season: season,
            sowingDate: sowingDate,
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // SAVE TO FIRESTORE
  // ------------------------------------------------------------

  Future<void> _saveCropToFirestore({
    String? cropId,
    required String name,
    required String variety,
    required String area,
    required String season,
    required String sowingDate,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnackbar('Please log in to manage crops.', isError: true);
      return;
    }

    try {
      final cropsRef = _firestore
          .collection('farmers')
          .doc(user.uid)
          .collection('crops');

      final data = {
        'cropName': name,
        'name': name,
        'variety': variety,
        'area': area,
        'season': season,
        'sowingDate': sowingDate,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (cropId == null) {
        // Add new crop
        data['createdAt'] = FieldValue.serverTimestamp();
        await cropsRef.add(data);
        _showSnackbar('$name added successfully! 🌾');
      } else {
        // Update existing crop
        await cropsRef.doc(cropId).update(data);
        _showSnackbar('$name updated successfully! 🌱');
      }
    } catch (e) {
      _showSnackbar('Failed to save crop: $e', isError: true);
    }
  }

  // ------------------------------------------------------------
  // DELETE CROP
  // ------------------------------------------------------------

  Future<void> _deleteCrop(CropModel crop) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Crop',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove "${crop.name}" from your crops list?',
          style: const TextStyle(color: _grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('farmers')
          .doc(user.uid)
          .collection('crops')
          .doc(crop.id)
          .delete();

      _showSnackbar('${crop.name} deleted.');
    } catch (e) {
      _showSnackbar('Failed to delete crop: $e', isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.redAccent : _accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          message,
          style: TextStyle(
            color: isError ? Colors.white : _darkAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: user == null
                  ? _buildNotLoggedIn()
                  : StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('farmers')
                          .doc(user.uid)
                          .collection('crops')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          // Fallback to unordered query if index is not yet built or createdAt is null
                          return StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('farmers')
                                .doc(user.uid)
                                .collection('crops')
                                .snapshots(),
                            builder: (context, fallbackSnap) {
                              if (fallbackSnap.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(color: _accent),
                                );
                              }
                              if (fallbackSnap.hasError) {
                                return _buildErrorState(fallbackSnap.error.toString());
                              }
                              final docs = fallbackSnap.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return _buildEmptyState();
                              }
                              final crops = docs.map((d) => CropModel.fromFirestore(d)).toList();
                              return _buildCropList(crops);
                            },
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: _accent),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return _buildEmptyState();
                        }

                        final crops = docs.map((d) => CropModel.fromFirestore(d)).toList();
                        return _buildCropList(crops);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCropSheet(),
        backgroundColor: _accent,
        foregroundColor: _darkAccent,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Add Crop',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: const Icon(Icons.grass_rounded, color: _darkAccent, size: 26),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Crops',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Farm Manager Crops',
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
          const SizedBox(height: 18),
          const Text(
            'Your Registered Crops 🌱',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Keep track of your active crops, varieties, and sowing schedule.',
            style: TextStyle(color: _grey, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _card,
              ),
              child: const Icon(
                Icons.grass_outlined,
                color: _accent,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Crops Added',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You haven\'t added any crops yet.\nTap below to add your first crop.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _grey,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openCropSheet(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add First Crop'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _darkAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              'Error loading crops: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotLoggedIn() {
    return const Center(
      child: Text(
        'Please sign in to view your crops.',
        style: TextStyle(color: _grey, fontSize: 14),
      ),
    );
  }

  // ============================================================
  // CROP LIST
  // ============================================================

  Widget _buildCropList(List<CropModel> crops) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
      itemCount: crops.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final crop = crops[index];
        return _buildCropCard(crop);
      },
    );
  }

  // ============================================================
  // CROP CARD
  // ============================================================

  Widget _buildCropCard(CropModel crop) {
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _darkAccent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _accent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.agriculture,
                  color: _accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crop.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (crop.variety.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Variety: ${crop.variety}',
                        style: const TextStyle(
                          color: _grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: _card2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                icon: const Icon(Icons.more_vert, color: _grey, size: 20),
                onSelected: (val) {
                  if (val == 'edit') {
                    _openCropSheet(existingCrop: crop);
                  } else if (val == 'delete') {
                    _deleteCrop(crop);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, color: _accent, size: 18),
                        SizedBox(width: 10),
                        Text('Edit', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (crop.area.isNotEmpty || crop.season.isNotEmpty || crop.sowingDate.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (crop.area.isNotEmpty)
                  _buildBadge(Icons.straighten, crop.area),
                if (crop.season.isNotEmpty)
                  _buildBadge(Icons.wb_sunny_outlined, crop.season),
                if (crop.sowingDate.isNotEmpty)
                  _buildBadge(Icons.calendar_today_outlined, 'Sown: ${crop.sowingDate}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _accent, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD2D7CD),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CROP FORM BOTTOM SHEET (ADD / EDIT)
// ============================================================

class _CropFormSheet extends StatefulWidget {
  final CropModel? existingCrop;
  final Future<void> Function(
    String name,
    String variety,
    String area,
    String season,
    String sowingDate,
  ) onSave;

  const _CropFormSheet({
    this.existingCrop,
    required this.onSave,
  });

  @override
  State<_CropFormSheet> createState() => _CropFormSheetState();
}

class _CropFormSheetState extends State<_CropFormSheet> {
  static const Color _card = Color(0xFF1B2018);
  static const Color _inputBg = Color(0xFF11150F);
  static const Color _accent = Color(0xFFB7D83D);
  static const Color _darkAccent = Color(0xFF17200F);
  static const Color _grey = Color(0xFF9FA59A);

  late final TextEditingController _nameController;
  late final TextEditingController _varietyController;
  late final TextEditingController _areaController;
  late final TextEditingController _seasonController;
  late final TextEditingController _sowingDateController;

  bool _saving = false;
  String? _nameError;

  final List<String> _commonSeasons = [
    'Kharif (Monsoon)',
    'Rabi (Winter)',
    'Zaid (Summer)',
    'Annual / Perennial',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.existingCrop;
    _nameController = TextEditingController(text: c?.name ?? '');
    _varietyController = TextEditingController(text: c?.variety ?? '');
    _areaController = TextEditingController(text: c?.area ?? '');
    _seasonController = TextEditingController(text: c?.season ?? '');
    _sowingDateController = TextEditingController(text: c?.sowingDate ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _varietyController.dispose();
    _areaController.dispose();
    _seasonController.dispose();
    _sowingDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accent,
              surface: _card,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = DateFormat('dd MMM yyyy').format(picked);
      setState(() {
        _sowingDateController.text = formatted;
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = 'Crop Name is required';
      });
      return;
    }

    setState(() {
      _nameError = null;
      _saving = true;
    });

    try {
      await widget.onSave(
        name,
        _varietyController.text.trim(),
        _areaController.text.trim(),
        _seasonController.text.trim(),
        _sowingDateController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingCrop != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(22, 20, 22, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.grass_rounded, color: _darkAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Crop' : 'Add New Crop',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _grey, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // CROP NAME (Required)
            _buildFieldLabel('Crop Name *'),
            _buildTextField(
              controller: _nameController,
              hint: 'e.g. Wheat, Soybean, Onion',
              icon: Icons.grass,
              errorText: _nameError,
            ),
            const SizedBox(height: 14),

            // VARIETY (Optional)
            _buildFieldLabel('Variety (Optional)'),
            _buildTextField(
              controller: _varietyController,
              hint: 'e.g. Lokwan 148, Sharbati',
              icon: Icons.category_outlined,
            ),
            const SizedBox(height: 14),

            // AREA (Optional)
            _buildFieldLabel('Area / Land (Optional)'),
            _buildTextField(
              controller: _areaController,
              hint: 'e.g. 2.5 Acres / 5 Bigha',
              icon: Icons.straighten,
            ),
            const SizedBox(height: 14),

            // SEASON (Optional)
            _buildFieldLabel('Season (Optional)'),
            _buildTextField(
              controller: _seasonController,
              hint: 'e.g. Rabi, Kharif, Summer',
              icon: Icons.wb_sunny_outlined,
            ),
            const SizedBox(height: 8),

            // Quick Season Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _commonSeasons.map((s) {
                  final label = s.split(' ').first;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(label, style: const TextStyle(fontSize: 11)),
                      backgroundColor: _inputBg,
                      labelStyle: const TextStyle(color: _grey),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      onPressed: () {
                        setState(() {
                          _seasonController.text = s;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // SOWING DATE (Optional)
            _buildFieldLabel('Sowing Date (Optional)'),
            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: _buildTextField(
                  controller: _sowingDateController,
                  hint: 'Select sowing date',
                  icon: Icons.calendar_today_outlined,
                  suffixIcon: const Icon(Icons.event, color: _accent, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: _darkAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: _darkAccent,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Text(
                        isEdit ? 'Update Crop' : 'Save Crop',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFD2D7CD),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF686F64), fontSize: 12),
            prefixIcon: Icon(icon, color: const Color(0xFF7F887A), size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: _inputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _accent, width: 1.2),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText,
            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
          ),
        ],
      ],
    );
  }
}
