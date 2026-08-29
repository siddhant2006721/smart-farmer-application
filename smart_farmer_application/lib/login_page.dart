import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'farmer_setup_page.dart';
import 'register_page.dart';
import 'dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool loading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ---------------- LOGIN ----------------

  Future<void> login() async {

    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {

      showMessage('Please enter email and password.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {

      await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      showMessage('Welcome back! 🌾');

      // Check if the user already completed their profile
      final user = _auth.currentUser;
      bool profileDone = false;

      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('farmers')
              .doc(user.uid)
              .get();
          profileDone =
              doc.exists && (doc.data()?['profileCompleted'] == true);
        } catch (_) {
          profileDone = false;
        }
      }

      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;

      if (profileDone) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const FarmerSetupPage()),
          (_) => false,
        );
      }

    } on FirebaseAuthException catch (e) {

      String message = 'Login failed.';

      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      } else if (e.code == 'invalid-credential') {
        message = 'Email or password is incorrect.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email.';
      }

      showMessage(message);

    } catch (e) {

      showMessage('Something went wrong. Please try again.');

    } finally {

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ---------------- MESSAGE ----------------

  void showMessage(String message) {

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF11140F),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [

                const SizedBox(height: 22),

                // BACK BUTTON
                GestureDetector(
                  onTap: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // SMALL ICON
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB7D83D),
                    borderRadius:
                    BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.agriculture_rounded,
                    size: 30,
                    color: Color(0xFF17200F),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'Welcome back! 🌾',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 9),

                const Text(
                  'Sign in to continue your smart '
                      'farming journey.',
                  style: TextStyle(
                    color: Color(0xFF9FA59A),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),

                // LOGIN CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2018),
                    borderRadius:
                    BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.07),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [

                      const Text(
                        'Your account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // EMAIL
                      _label('Email'),

                      _inputField(
                        controller: emailController,
                        hint: 'Enter your email',
                        icon: Icons.mail_outline_rounded,
                        keyboardType:
                        TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 18),

                      // PASSWORD
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [

                          _label('Password'),

                          GestureDetector(
                            onTap: () {
                              // Add forgot password later
                              showMessage(
                                'Password reset will be added soon.',
                              );
                            },
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: Color(0xFFB7D83D),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      _inputField(
                        controller: passwordController,
                        hint: 'Enter your password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: hidePassword,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              hidePassword =
                              !hidePassword;
                            });
                          },
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF8D9487),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // LOGIN BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed:
                          loading ? null : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFFB7D83D),
                            foregroundColor:
                            const Color(0xFF17200F),
                            elevation: 0,
                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(17),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                            height: 22,
                            width: 22,
                            child:
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(
                                0xFF17200F,
                              ),
                            ),
                          )
                              : const Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [

                              Text(
                                'SIGN IN',
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),

                              SizedBox(width: 10),

                              Icon(
                                Icons
                                    .arrow_forward_rounded,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // REGISTER
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [

                    const Text(
                      "Don't have an account?",
                      style: TextStyle(
                        color: Color(0xFF858B80),
                        fontSize: 13,
                      ),
                    ),

                    TextButton(
                      onPressed: () {

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                            const RegisterPage(),
                          ),
                        );

                      },
                      child: const Text(
                        'Create account',
                        style: TextStyle(
                          color: Color(0xFFB7D83D),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                const Center(
                  child: Text(
                    '🌱 Your farm. Your data. Your decisions.',
                    style: TextStyle(
                      color: Color(0xFF646A60),
                      fontSize: 11,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- LABEL ----------------

  Widget _label(String text) {

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

  // ---------------- INPUT ----------------

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF686F64),
          fontSize: 13,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF7F887A),
          size: 20,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF11150F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Color(0xFFB7D83D),
            width: 1.2,
          ),
        ),
      ),
    );
  }
}