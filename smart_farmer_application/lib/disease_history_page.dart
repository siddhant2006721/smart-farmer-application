import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DiseaseHistoryPage extends StatefulWidget {
  const DiseaseHistoryPage({super.key});

  @override
  State<DiseaseHistoryPage> createState() => _DiseaseHistoryPageState();
}

class _DiseaseHistoryPageState extends State<DiseaseHistoryPage> {
  static const Color _bg = Color(0xFF0F130D);
  static const Color _card = Color(0xFF1A2117);
  static const Color _card2 = Color(0xFF20291B);
  static const Color _accent = Color(0xFFB7D83D);
  static const Color _darkAccent = Color(0xFF17200F);
  static const Color _grey = Color(0xFF899181);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _filter = 'all'; // 'all', 'diseased', 'healthy'

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else if (timestamp is int) {
      date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return 'Recently';
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':
      case 'high':
        return const Color(0xFFEF5350);
      case 'moderate':
      case 'medium':
        return const Color(0xFFFFA726);
      case 'low':
        return const Color(0xFFFFEE58);
      default:
        return _accent;
    }
  }

  void _showRecordDetails(BuildContext context, Map<String, dynamic> data) {
    final isHealthy = data['isHealthy'] == true;
    final cropName = (data['cropName'] ?? 'Crop').toString();
    final diseaseName = (data['diseaseName'] ?? (isHealthy ? 'Healthy Crop' : 'Disease Detected')).toString();
    final confidence = data['confidence']?.toString() ?? '90';
    final severity = (data['severity'] ?? (isHealthy ? 'Healthy' : 'Moderate')).toString();
    final symptoms = (data['symptoms'] ?? '').toString();
    final recommendedSolution = (data['recommendedSolution'] ?? '').toString();
    final preventionTips = (data['preventionTips'] ?? '').toString();
    final diseaseRisk = (data['diseaseRisk'] ?? 'Low').toString();
    final createdAt = _formatDate(data['createdAt']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: ListView(
            controller: scrollController,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isHealthy ? _darkAccent : const Color(0xFF331E1E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isHealthy ? _accent.withValues(alpha: 0.4) : Colors.redAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      isHealthy ? Icons.eco_rounded : Icons.coronavirus_outlined,
                      color: isHealthy ? _accent : Colors.redAccent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          diseaseName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Crop: $cropName • $createdAt',
                          style: const TextStyle(
                            color: _grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Metrics Chips Row
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _buildMetricBadge(
                    'Confidence',
                    '$confidence%',
                    Icons.verified_outlined,
                    _accent,
                  ),
                  if (!isHealthy)
                    _buildMetricBadge(
                      'Severity',
                      severity,
                      Icons.warning_amber_rounded,
                      _getSeverityColor(severity),
                    ),
                  _buildMetricBadge(
                    'Risk',
                    diseaseRisk,
                    Icons.shield_outlined,
                    isHealthy ? _accent : _getSeverityColor(diseaseRisk),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 14),

              if (symptoms.isNotEmpty) ...[
                _buildSectionHeader('Symptoms Observed', Icons.visibility_outlined),
                const SizedBox(height: 6),
                Text(
                  symptoms,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 18),
              ],

              if (recommendedSolution.isNotEmpty) ...[
                _buildSectionHeader(
                  isHealthy ? 'Care Advice' : 'Recommended Solution',
                  Icons.medical_services_outlined,
                ),
                const SizedBox(height: 6),
                Text(
                  recommendedSolution,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 18),
              ],

              if (preventionTips.isNotEmpty) ...[
                _buildSectionHeader('Prevention Tips', Icons.health_and_safety_outlined),
                const SizedBox(height: 6),
                Text(
                  preventionTips,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 18),
              ],

              // Safe Advisory Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _darkAccent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha: 0.15)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: _accent, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Always consult local agricultural extension officers and read approved product labels before applying chemical crop protection.',
                        style: TextStyle(color: _grey, fontSize: 11, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBadge(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(color: _grey, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _accent, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteRecord(String docId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('farmers')
          .doc(user.uid)
          .collection('disease_detections')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record removed from history'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete record. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterTabs(),
            Expanded(
              child: user == null
                  ? const Center(
                      child: Text(
                        'Please sign in to view your detection history.',
                        style: TextStyle(color: _grey),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('farmers')
                          .doc(user.uid)
                          .collection('disease_detections')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: _accent),
                          );
                        }

                        if (snapshot.hasError) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Unable to load history at this time.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _grey),
                              ),
                            ),
                          );
                        }

                        final allDocs = snapshot.data?.docs ?? [];
                        final filteredDocs = allDocs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>? ?? {};
                          final isHealthy = data['isHealthy'] == true;
                          if (_filter == 'healthy') return isHealthy;
                          if (_filter == 'diseased') return !isHealthy;
                          return true;
                        }).toList();

                        if (filteredDocs.isEmpty) {
                          return _buildEmptyState();
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                          itemCount: filteredDocs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data = doc.data() as Map<String, dynamic>? ?? {};
                            return _buildHistoryCard(doc.id, data);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.history_rounded, color: _darkAccent, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detection History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Previous crop health checks',
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
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('all', 'All Scans'),
          const SizedBox(width: 8),
          _buildFilterChip('diseased', 'Diseased'),
          const SizedBox(width: 8),
          _buildFilterChip('healthy', 'Healthy'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? _accent : _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _accent : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _darkAccent : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(String docId, Map<String, dynamic> data) {
    final isHealthy = data['isHealthy'] == true;
    final cropName = (data['cropName'] ?? 'Unknown Crop').toString();
    final diseaseName = (data['diseaseName'] ?? (isHealthy ? 'Healthy' : 'Disease Detected')).toString();
    final confidence = data['confidence']?.toString() ?? '90';
    final severity = (data['severity'] ?? (isHealthy ? 'Healthy' : 'Moderate')).toString();
    final timeStr = _formatDate(data['createdAt']);

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
      ),
      onDismissed: (_) => _deleteRecord(docId),
      child: GestureDetector(
        onTap: () => _showRecordDetails(context, data),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHealthy
                  ? _accent.withValues(alpha: 0.15)
                  : Colors.redAccent.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isHealthy ? _darkAccent : const Color(0xFF2B1B1B),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isHealthy
                        ? _accent.withValues(alpha: 0.3)
                        : Colors.redAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  isHealthy ? Icons.eco_rounded : Icons.coronavirus_outlined,
                  color: isHealthy ? _accent : Colors.redAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            diseaseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          timeStr,
                          style: const TextStyle(color: _grey, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crop: $cropName',
                      style: const TextStyle(color: _grey, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _card2,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Confidence: $confidence%',
                            style: const TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (!isHealthy)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getSeverityColor(severity).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Severity: $severity',
                              style: TextStyle(
                                color: _getSeverityColor(severity),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: _grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _darkAccent,
              ),
              child: const Icon(Icons.history_outlined, color: _accent, size: 32),
            ),
            const SizedBox(height: 18),
            const Text(
              'No detection history',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your crop disease detection scans will be saved here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _grey,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
