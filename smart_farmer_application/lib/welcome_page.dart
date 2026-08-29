import 'package:flutter/material.dart';
import 'login_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11140F),
      body: SafeArea(
        child: Stack(
          children: [

            // Background glow
            Positioned(
              top: -100,
              right: -80,
              child: Container(
                height: 280,
                width: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF789C28).withOpacity(0.25),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const SizedBox(height: 25),

                  // APP NAME
                  Row(
                    children: [
                      Container(
                        height: 43,
                        width: 43,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB7D83D),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.agriculture_rounded,
                          color: Color(0xFF17200F),
                          size: 25,
                        ),
                      ),

                      const SizedBox(width: 12),

                      const Flexible(
                        child: Text(
                          'SMART FARMER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // HEADING
                  const Text(
                    'Grow smarter.\nHarvest better.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Smart technology and farming knowledge, '
                        'designed around your farm.',
                    style: TextStyle(
                      color: Color(0xFFB5B9AE),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // FARMER IMAGE CARD
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [

                          Image.asset(
                            'assets/images/farmer.png',
                            fit: BoxFit.cover,
                          ),

                          // Dark gradient
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.75),
                                ],
                              ),
                            ),
                          ),

                          // Image text
                          Positioned(
                            left: 18,
                            right: 18,
                            bottom: 18,
                            child: Row(
                              children: [

                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius:
                                    BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Colors.white
                                          .withOpacity(0.2),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.eco_rounded,
                                    color: Color(0xFFD4E85C),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                const Expanded(
                                  child: Text(
                                    'Your farm. Your decisions.\n'
                                        'Smarter farming starts here.',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // GET STARTED BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFFB7D83D),
                        foregroundColor:
                        const Color(0xFF17200F),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Text(
                            'GET STARTED',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(
                            Icons.arrow_forward_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Center(
                    child: Text(
                      'Built for farmers • Powered by smart technology',
                      style: TextStyle(
                        color: Color(0xFF777C70),
                        fontSize: 11,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}