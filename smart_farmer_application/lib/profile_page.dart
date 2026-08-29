import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color _bg = Color(0xFF11140F);
  static const Color _card = Color(0xFF1B2018);
  static const Color _accent = Color(0xFFB7D83D);
  static const Color _darkAccent = Color(0xFF17200F);
  static const Color _grey = Color(0xFF9FA59A);
  static const Color _labelColor = Color(0xFFD2D7CD);
  static const Color _inputBg = Color(0xFF11150F);

  // ============================================================
  // STATE
  // ============================================================

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'No logged-in user found.';
        _loading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('farmers')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        setState(() {
          _data = {
            ...doc.data()!,
            'email': user.email ?? '',
          };
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Profile data not found.';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load profile: $e';
        _loading = false;
      });
    }
  }

  // ============================================================
  // OPEN EDIT — reload on return
  // ============================================================

  Future<void> _openEdit() async {
    if (_data == null) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(profileData: _data!),
      ),
    );

    // If user saved changes, reload from Firestore
    if (updated == true && mounted) {
      _loadProfile();
    }
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
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _accent),
                    )
                  : _error != null
                      ? _buildError()
                      : _buildContent(),
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
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
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 15),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_rounded, color: _darkAccent, size: 26),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Text(
                  'My Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              // EDIT BUTTON
              if (!_loading && _error == null)
                GestureDetector(
                  onTap: _openEdit,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded, color: _darkAccent, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Edit',
                          style: TextStyle(
                            color: _darkAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Your farmer information 🌾',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'All the information saved during your profile setup.',
            style: TextStyle(color: _grey, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _darkAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    final d = _data!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
      child: Column(
        children: [
          _buildCard(
            title: 'Personal Information',
            icon: Icons.person_outline_rounded,
            children: [
              _buildField(label: 'Farmer Name', value: d['name'] ?? '', icon: Icons.person_outline_rounded),
              _buildField(label: 'Mobile Number', value: d['mobile'] ?? '', icon: Icons.phone_outlined),
              _buildField(label: 'Email Address', value: d['email'] ?? '', icon: Icons.mail_outline_rounded),
            ],
          ),

          const SizedBox(height: 18),

          _buildCard(
            title: 'Farm Location',
            icon: Icons.location_on_outlined,
            children: [
              _buildField(label: 'State', value: d['state'] ?? '', icon: Icons.map_outlined),
              _buildField(label: 'District', value: d['district'] ?? '', icon: Icons.location_city_outlined),
              _buildField(label: 'Taluka', value: d['taluka'] ?? '', icon: Icons.account_balance_outlined),
            ],
          ),

          const SizedBox(height: 18),

          _buildCard(
            title: 'Village Details',
            icon: Icons.home_work_outlined,
            children: [
              _buildField(label: 'Village', value: d['village'] ?? '', icon: Icons.home_work_outlined),
              _buildField(label: 'PIN Code', value: d['pinCode'] ?? '', icon: Icons.pin_drop_outlined),
            ],
          ),

          const SizedBox(height: 18),

          // Profile complete badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Container(
                  height: 45,
                  width: 45,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.verified_rounded, color: _darkAccent, size: 24),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Text(
                    'Profile complete. Your farm data is personalised for you.',
                    style: TextStyle(
                      color: _labelColor,
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Full-width Edit Profile button at bottom
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _openEdit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _darkAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_rounded, size: 18),
                  SizedBox(width: 9),
                  Text(
                    'EDIT PROFILE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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
  // CARD
  // ============================================================

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _accent, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // FIELD (read-only display)
  // ============================================================

  Widget _buildField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _grey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _inputBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF7F887A), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value.isEmpty ? '—' : value,
                    style: TextStyle(
                      color: value.isEmpty ? const Color(0xFF686F64) : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
}
