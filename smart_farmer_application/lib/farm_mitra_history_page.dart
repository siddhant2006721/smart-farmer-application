import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FarmMitraHistoryPage extends StatefulWidget {
  const FarmMitraHistoryPage({super.key});

  @override
  State<FarmMitraHistoryPage> createState() => _FarmMitraHistoryPageState();
}

class _FarmMitraHistoryPageState extends State<FarmMitraHistoryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFFB7D83D);
    const Color backgroundColor = Color(0xFF0F130D);
    const Color cardColor = Color(0xFF1A2117);

    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: const Text(
          'Chat History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Please log in to see history.',
                style: TextStyle(color: Colors.white),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('farmers')
                  .doc(user.uid)
                  .collection('farm_mitra_chats')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error loading history.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryGreen),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No past questions found.',
                      style: TextStyle(color: Color(0xFF899181)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final question = (data['userMessage'] ?? data['question'] ?? '').toString().trim();
                    final rawAnswer = (data['aiResponse'] ?? data['answer'] ?? '').toString().trim();
                    final status = (data['status'] ?? (rawAnswer.isNotEmpty ? 'success' : 'pending')).toString().toLowerCase();
                    final errorMessage = (data['errorMessage'] ?? '').toString().trim();
                    final timestamp = (data['timestamp'] ?? data['createdAt']) as Timestamp?;

                    String dateStr = 'Unknown Date';
                    if (timestamp != null) {
                      dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
                    }

                    final bool isFailed = status == 'failed';
                    final bool isPending = status == 'pending';

                    String displayAnswer = rawAnswer;
                    if (displayAnswer.isEmpty) {
                      if (isFailed) {
                        displayAnswer = errorMessage.isNotEmpty
                            ? errorMessage
                            : 'AI response could not be generated.';
                      } else if (isPending) {
                        displayAnswer = 'Waiting for response...';
                      } else {
                        displayAnswer = 'No response recorded.';
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFailed
                              ? Colors.redAccent.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  dateStr,
                                  style: const TextStyle(
                                    color: Color(0xFF899181),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isFailed)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Failed',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else if (isPending)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Pending',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.person, color: primaryGreen, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  question.isNotEmpty ? question : 'User Question',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isFailed
                                    ? Icons.error_outline_rounded
                                    : Icons.auto_awesome,
                                color: isFailed
                                    ? Colors.redAccent
                                    : (isPending ? Colors.amber : Colors.blueAccent),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  displayAnswer,
                                  style: TextStyle(
                                    color: isFailed
                                        ? const Color(0xFFC9B4B6)
                                        : Colors.white70,
                                    fontSize: 14,
                                    fontStyle: (isFailed || isPending)
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
