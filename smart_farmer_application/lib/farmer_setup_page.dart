import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard.dart';
import 'welcome_page.dart';


class FarmerSetupPage extends StatefulWidget {
  const FarmerSetupPage({super.key});

  @override
  State<FarmerSetupPage> createState() => _FarmerSetupPageState();
}

class _FarmerSetupPageState extends State<FarmerSetupPage> {
  // ============================================================
  // COLORS - SAME STYLE AS LOGIN PAGE
  // ============================================================

  static const Color backgroundColor = Color(0xFF11140F);
  static const Color cardColor = Color(0xFF1B2018);
  static const Color inputColor = Color(0xFF11150F);
  static const Color accentColor = Color(0xFFB7D83D);
  static const Color darkAccent = Color(0xFF17200F);

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final PageController pageController = PageController();

  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final stateController = TextEditingController();
  final districtController = TextEditingController();
  final talukaController = TextEditingController();
  final villageController = TextEditingController();
  final pinController = TextEditingController();


  int currentStep = 0;
  bool loading = false;

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore =
      FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser == null) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomePage()),
          (_) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    pageController.dispose();

    nameController.dispose();
    mobileController.dispose();
    stateController.dispose();
    districtController.dispose();
    talukaController.dispose();
    villageController.dispose();
    pinController.dispose();

    super.dispose();
  }

  // ============================================================
  // NEXT STEP
  // ============================================================

  void nextStep() {
    if (!_validateStep()) {
      return;
    }

    if (currentStep < 2) {
      setState(() {
        currentStep++;
      });

      pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      saveProfile();
    }
  }

  // ============================================================
  // PREVIOUS STEP
  // ============================================================

  void previousStep() {
    if (currentStep == 0) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    setState(() {
      currentStep--;
    });

    pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool _validateStep() {
    if (currentStep == 0) {
      if (nameController.text.trim().isEmpty) {
        showMessage('Please enter your name.');
        return false;
      }

      if (mobileController.text.trim().length != 10) {
        showMessage(
          'Please enter a valid 10-digit mobile number.',
        );
        return false;
      }


    }

    if (currentStep == 1) {
      if (stateController.text.trim().isEmpty) {
        showMessage('Please enter your state.');
        return false;
      }

      if (districtController.text.trim().isEmpty) {
        showMessage('Please enter your district.');
        return false;
      }

      if (talukaController.text.trim().isEmpty) {
        showMessage('Please enter your taluka.');
        return false;
      }
    }

    if (currentStep == 2) {
      if (villageController.text.trim().isEmpty) {
        showMessage('Please enter your village.');
        return false;
      }

      if (pinController.text.trim().length != 6) {
        showMessage(
          'Please enter a valid 6-digit PIN code.',
        );
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // FIRESTORE SAVE
  // ============================================================

  Future<void> saveProfile() async {
    if (!_validateStep()) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('No logged-in user found.');
      print('ERROR: Firebase user is null');
      return;
    }

    setState(() {
      loading = true;
    });

    print('====================================');
    print('FIREBASE SAVE STARTED');
    print('User UID: ${user.uid}');
    print('Name: ${nameController.text}');
    print('State: ${stateController.text}');
    print('District: ${districtController.text}');
    print('Taluka: ${talukaController.text}');
    print('Village: ${villageController.text}');
    print('====================================');

    try {
      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'name': nameController.text.trim(),
        'mobile': mobileController.text.trim(),


        'state': stateController.text.trim(),
        'district': districtController.text.trim(),
        'taluka': talukaController.text.trim(),
        'village': villageController.text.trim(),
        'pinCode': pinController.text.trim(),

        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const DashboardPage(),
        ),
        (_) => false,
      );

      print('====================================');
      print('FIRESTORE SAVE SUCCESSFUL');
      print('Document: farmers/${user.uid}');
      print('====================================');

      if (!mounted) return;

      showMessage('Profile saved successfully! 🌾');

    } on FirebaseException catch (e) {
      print('====================================');
      print('FIRESTORE ERROR');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('====================================');

      if (!mounted) return;

      showMessage(
        'Firebase error: ${e.message}',
      );
    } catch (e) {
      print('====================================');
      print('GENERAL ERROR');
      print(e);
      print('====================================');

      if (!mounted) return;

      showMessage(
        'Error: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================
  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: accentColor,
        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),

        content: Text(
          message,
          style: const TextStyle(
            color: darkAccent,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MAIN UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: PageView(
                controller: pageController,
                physics:
                const NeverScrollableScrollPhysics(),
                children: [
                  _buildPersonalStep(),
                  _buildLocationStep(),
                  _buildFinalStep(),
                ],
              ),
            ),

            _buildBottomButtons(),
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
      padding: const EdgeInsets.fromLTRB(
        24,
        20,
        24,
        10,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: previousStep,
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color:
                    Colors.white.withOpacity(0.08),
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(width: 15),

              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.agriculture_rounded,
                  color: darkAccent,
                  size: 27,
                ),
              ),

              const SizedBox(width: 13),

              const Expanded(
                child: Text(
                  'Farmer Setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              Text(
                '${currentStep + 1}/3',
                style: const TextStyle(
                  color: Color(0xFF858B80),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value:
              (currentStep + 1) / 3,
              minHeight: 6,
              backgroundColor:
              Colors.white.withOpacity(0.08),
              valueColor:
              const AlwaysStoppedAnimation(
                accentColor,
              ),
            ),
          ),

          const SizedBox(height: 25),

          Text(
            _getTitle(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _getSubtitle(),
            style: const TextStyle(
              color: Color(0xFF9FA59A),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    if (currentStep == 0) {
      return 'Let’s get to know you 🌾';
    }

    if (currentStep == 1) {
      return 'Where is your farm?';
    }

    return 'Almost there! 🌱';
  }

  String _getSubtitle() {
    if (currentStep == 0) {
      return 'Tell us a little about yourself to personalize your farming experience.';
    }

    if (currentStep == 1) {
      return 'Enter your farm location so we can provide local insights.';
    }

    return 'Add your village details and complete your farmer profile.';
  }

  // ============================================================
  // STEP 1
  // ============================================================

  Widget _buildPersonalStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        24,
        10,
        24,
        20,
      ),
      child: _buildCard(
        title: 'Your profile',
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildLabel('Farmer Name'),

            _buildInput(
              controller: nameController,
              hint: 'Enter your full name',
              icon:
              Icons.person_outline_rounded,
            ),

            const SizedBox(height: 18),

            _buildLabel('Mobile Number'),

            _buildInput(
              controller: mobileController,
              hint: 'Enter your mobile number',
              icon:
              Icons.phone_outlined,
              keyboardType:
              TextInputType.phone,
              maxLength: 10,
            ),


          ],
        ),
      ),
    );
  }

  // ============================================================
  // STEP 2
  // ============================================================

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        24,
        10,
        24,
        20,
      ),
      child: _buildCard(
        title: 'Farm location',
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildLabel('State'),

            _buildInput(
              controller: stateController,
              hint: 'Enter your state',
              icon: Icons.map_outlined,
            ),

            const SizedBox(height: 18),

            _buildLabel('District'),

            _buildInput(
              controller: districtController,
              hint: 'Enter your district',
              icon:
              Icons.location_city_outlined,
            ),

            const SizedBox(height: 18),

            _buildLabel('Taluka'),

            _buildInput(
              controller: talukaController,
              hint: 'Enter your taluka',
              icon:
              Icons.account_balance_outlined,
            ),

            const SizedBox(height: 22),

            _buildAiTip(
              'Your location helps Kisan Mitra provide relevant weather, crop and farming recommendations.',
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STEP 3
  // ============================================================

  Widget _buildFinalStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        24,
        10,
        24,
        20,
      ),
      child: Column(
        children: [
          _buildCard(
            title: 'Village details',
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _buildLabel('Village'),

                _buildInput(
                  controller:
                  villageController,
                  hint: 'Enter your village name',
                  icon:
                  Icons.home_work_outlined,
                ),

                const SizedBox(height: 18),

                _buildLabel('PIN Code'),

                _buildInput(
                  controller:
                  pinController,
                  hint: 'Enter 6-digit PIN code',
                  icon:
                  Icons.pin_drop_outlined,
                  keyboardType:
                  TextInputType.number,
                  maxLength: 6,
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          _buildCompletionCard(),
        ],
      ),
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _buildCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius:
        BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white
              .withOpacity(0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
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
      padding:
      const EdgeInsets.only(bottom: 8),
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
  // INPUT
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

      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),

      decoration: InputDecoration(
        counterText: '',

        hintText: hint,

        hintStyle:
        const TextStyle(
          color: Color(0xFF686F64),
          fontSize: 13,
        ),

        prefixIcon: Icon(
          icon,
          color:
          const Color(0xFF7F887A),
          size: 20,
        ),

        filled: true,
        fillColor: inputColor,

        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),

        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(15),
          borderSide:
          BorderSide.none,
        ),

        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(15),
          borderSide:
          BorderSide.none,
        ),

        focusedBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(15),
          borderSide:
          const BorderSide(
            color: accentColor,
            width: 1.2,
          ),
        ),
      ),
    );
  }



  // ============================================================
  // AI TIP
  // ============================================================

  Widget _buildAiTip(String text) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF242A20),
        borderRadius:
        BorderRadius.circular(17),
        border: Border.all(
          color: accentColor
              .withOpacity(0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: accentColor
                  .withOpacity(0.12),
              borderRadius:
              BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: accentColor,
              size: 18,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              text,
              style:
              const TextStyle(
                color:
                Color(0xFF9FA59A),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMPLETION CARD
  // ============================================================

  Widget _buildCompletionCard() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accentColor
            .withOpacity(0.09),
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: accentColor
              .withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: darkAccent,
              size: 25,
            ),
          ),

          const SizedBox(width: 13),

          const Expanded(
            child: Text(
              'Your farmer profile is ready. Let’s personalize your farming journey.',
              style: TextStyle(
                color: Color(0xFFD2D7CD),
                fontSize: 12.5,
                height: 1.45,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM BUTTONS
  // ============================================================

  Widget _buildBottomButtons() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        24,
        8,
        24,
        20,
      ),
      child: Row(
        children: [
          if (currentStep > 0)
            GestureDetector(
              onTap:
              loading
                  ? null
                  : previousStep,
              child: Container(
                height: 55,
                width: 55,
                decoration:
                BoxDecoration(
                  color:
                  Colors.white
                      .withOpacity(
                    0.08,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    17,
                  ),
                ),
                child: const Icon(
                  Icons
                      .arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
            ),

          if (currentStep > 0)
            const SizedBox(width: 12),

          Expanded(
            child: SizedBox(
              height: 55,
              child:
              ElevatedButton(
                onPressed:
                loading
                    ? null
                    : nextStep,

                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  accentColor,

                  foregroundColor:
                  darkAccent,

                  disabledBackgroundColor:
                  const Color(
                    0xFF6C792D,
                  ),

                  elevation: 0,

                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      17,
                    ),
                  ),
                ),

                child: loading
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                    darkAccent,
                  ),
                )
                    : Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,
                  children: [
                    Text(
                      currentStep == 2
                          ? 'COMPLETE PROFILE'
                          : 'CONTINUE',
                      style:
                      const TextStyle(
                        fontSize: 13,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      width: 9,
                    ),

                    Icon(
                      currentStep == 2
                          ? Icons
                          .check_rounded
                          : Icons
                          .arrow_forward_rounded,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}