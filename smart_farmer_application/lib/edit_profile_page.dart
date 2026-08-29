import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  /// Existing profile data passed from ProfilePage so fields are pre-filled.
  final Map<String, dynamic> profileData;

  const EditProfilePage({super.key, required this.profileData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // ============================================================
  // COLORS — matches existing app theme
  // ============================================================

  static const Color _bg = Color(0xFF11140F);
  static const Color _card = Color(0xFF1B2018);
  static const Color _accent = Color(0xFFB7D83D);
  static const Color _darkAccent = Color(0xFF17200F);
  static const Color _grey = Color(0xFF9FA59A);
  static const Color _inputBg = Color(0xFF11150F);

  // ============================================================
  // CONTROLLERS
  // ============================================================

  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _stateController;
  late final TextEditingController _districtController;
  late final TextEditingController _talukaController;
  late final TextEditingController _villageController;
  late final TextEditingController _pinController;

  bool _saving = false;

  // ============================================================
  // INIT — pre-fill from existing data
  // ============================================================

  @override
  void initState() {
    super.initState();
    final d = widget.profileData;
    _nameController     = TextEditingController(text: d['name']     ?? '');
    _mobileController   = TextEditingController(text: d['mobile']   ?? '');
    _stateController    = TextEditingController(text: d['state']    ?? '');
    _districtController = TextEditingController(text: d['district'] ?? '');
    _talukaController   = TextEditingController(text: d['taluka']   ?? '');
    _villageController  = TextEditingController(text: d['village']  ?? '');
    _pinController      = TextEditingController(text: d['pinCode']  ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _talukaController.dispose();
    _villageController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool _validate() {
    final name   = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final state  = _stateController.text.trim();
    final district = _districtController.text.trim();
    final taluka = _talukaController.text.trim();
    final village = _villageController.text.trim();
    final pin    = _pinController.text.trim();

    if (name.isEmpty) {
      _showMessage('Please enter your name.');
      return false;
    }
    if (mobile.length != 10 || int.tryParse(mobile) == null) {
      _showMessage('Please enter a valid 10-digit mobile number.');
      return false;
    }
    if (state.isEmpty) {
      _showMessage('Please enter your state.');
      return false;
    }
    if (district.isEmpty) {
      _showMessage('Please enter your district.');
      return false;
    }
    if (taluka.isEmpty) {
      _showMessage('Please enter your taluka.');
      return false;
    }
    if (village.isEmpty) {
      _showMessage('Please enter your village.');
      return false;
    }
    if (pin.length != 6 || int.tryParse(pin) == null) {
      _showMessage('Please enter a valid 6-digit PIN code.');
      return false;
    }
    return true;
  }

  // ============================================================
  // SAVE — update Firestore, do NOT overwrite profileCompleted
  // ============================================================

  Future<void> _saveChanges() async {
    if (!_validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('No logged-in user found.');
      return;
    }

    setState(() => _saving = true);

    try {
      // Use update() so only these fields change; profileCompleted stays intact.
      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(user.uid)
          .update({
        'name':     _nameController.text.trim(),
        'mobile':   _mobileController.text.trim(),
        'state':    _stateController.text.trim(),
        'district': _districtController.text.trim(),
        'taluka':   _talukaController.text.trim(),
        'village':  _villageController.text.trim(),
        'pinCode':  _pinController.text.trim(),
        // Explicitly keep profileCompleted = true
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage('Profile updated successfully! 🌾');

      // Small delay so snackbar is visible, then pop with true to trigger reload
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context, true);

    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showMessage('Firebase error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error saving profile: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: _darkAccent, fontWeight: FontWeight.w700),
        ),
        backgroundColor: _accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
                child: Column(
                  children: [
                    // Personal info
                    _buildCard(
                      title: 'Personal Information',
                      icon: Icons.person_outline_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Farmer Name'),
                          _buildInput(
                            controller: _nameController,
                            hint: 'Enter your full name',
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 18),
                          _buildLabel('Mobile Number'),
                          _buildInput(
                            controller: _mobileController,
                            hint: 'Enter your mobile number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                          ),
                          const SizedBox(height: 6),
                          // Email is non-editable — tied to Firebase Auth
                          _buildLabel('Email Address'),
                          _buildReadonlyField(
                            value: widget.profileData['email'] ?? '',
                            icon: Icons.mail_outline_rounded,
                            hint: 'Email cannot be changed here',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Location
                    _buildCard(
                      title: 'Farm Location',
                      icon: Icons.location_on_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('State'),
                          _buildInput(
                            controller: _stateController,
                            hint: 'Enter your state',
                            icon: Icons.map_outlined,
                          ),
                          const SizedBox(height: 18),
                          _buildLabel('District'),
                          _buildInput(
                            controller: _districtController,
                            hint: 'Enter your district',
                            icon: Icons.location_city_outlined,
                          ),
                          const SizedBox(height: 18),
                          _buildLabel('Taluka'),
                          _buildInput(
                            controller: _talukaController,
                            hint: 'Enter your taluka',
                            icon: Icons.account_balance_outlined,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Village details
                    _buildCard(
                      title: 'Village Details',
                      icon: Icons.home_work_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Village'),
                          _buildInput(
                            controller: _villageController,
                            hint: 'Enter your village name',
                            icon: Icons.home_work_outlined,
                          ),
                          const SizedBox(height: 18),
                          _buildLabel('PIN Code'),
                          _buildInput(
                            controller: _pinController,
                            hint: 'Enter 6-digit PIN code',
                            icon: Icons.pin_drop_outlined,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: _darkAccent,
                          disabledBackgroundColor: const Color(0xFF6C792D),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _darkAccent,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_rounded, size: 18),
                                  SizedBox(width: 9),
                                  Text(
                                    'SAVE CHANGES',
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
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
                child: const Icon(Icons.edit_rounded, color: _darkAccent, size: 24),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Update your information ✏️',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Changes will be saved to your farmer profile.',
            style: TextStyle(color: _grey, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD WRAPPER
  // ============================================================

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
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
          child,
        ],
      ),
    );
  }

  // ============================================================
  // LABEL
  // ============================================================

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

  // ============================================================
  // EDITABLE INPUT
  // ============================================================

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF686F64), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF7F887A), size: 20),
        filled: true,
        fillColor: _inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _accent, width: 1.2),
        ),
      ),
    );
  }

  // ============================================================
  // READ-ONLY FIELD (email)
  // ============================================================

  Widget _buildReadonlyField({
    required String value,
    required IconData icon,
    required String hint,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      decoration: BoxDecoration(
        color: _inputBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF505850), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? hint : value,
              style: TextStyle(
                color: value.isEmpty ? const Color(0xFF505850) : const Color(0xFF686F64),
                fontSize: 14,
              ),
            ),
          ),
          const Icon(Icons.lock_outline_rounded, color: Color(0xFF505850), size: 15),
        ],
      ),
    );
  }
}
