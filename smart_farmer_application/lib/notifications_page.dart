import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';
import 'detailed_weather_page.dart';
import 'market_prices_page.dart';
import 'my_crops_page.dart';
import 'government_schemes_page.dart';
import 'farm_mitra_page.dart';
import 'disease_detection_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // Application Theme Colors
  static const Color _bg = Color(0xFF11140F);
  static const Color _card = Color(0xFF1B2018);
  static const Color _card2 = Color(0xFF20291B);
  static const Color _accent = Color(0xFFB7D83D);
  static const Color _darkAccent = Color(0xFF17200F);
  static const Color _grey = Color(0xFF9FA59A);

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ----------------------------------------------------------
  // RELATIVE TIME FORMATTER
  // ----------------------------------------------------------
  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? "minute" : "minutes"} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? "hour" : "hours"} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('dd MMM, hh:mm a').format(dateTime);
    }
  }

  // ----------------------------------------------------------
  // TYPE ICON & COLOR
  // ----------------------------------------------------------
  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'weather':
        return Icons.cloud_outlined;
      case 'market':
      case 'market_prices':
        return Icons.trending_up_rounded;
      case 'crop':
      case 'my_crops':
        return Icons.grass_outlined;
      case 'disease':
        return Icons.biotech_outlined;
      case 'scheme':
      case 'government_schemes':
        return Icons.account_balance_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'weather':
        return Colors.lightBlueAccent;
      case 'market':
      case 'market_prices':
        return _accent;
      case 'crop':
      case 'my_crops':
        return const Color(0xFF81C784);
      case 'disease':
        return Colors.amberAccent;
      case 'scheme':
      case 'government_schemes':
        return const Color(0xFFFFD54F);
      default:
        return _grey;
    }
  }

  // ----------------------------------------------------------
  // NAVIGATE TO TARGET PAGE
  // ----------------------------------------------------------
  void _handleNotificationTap(NotificationModel notification) {
    final user = _auth.currentUser;
    if (!notification.isRead) {
      NotificationService.markAsRead(user?.uid, notification.id);
    }

    final target = notification.targetPage?.toLowerCase();
    if (target == null || target.isEmpty) return;

    if (target == 'weather') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DetailedWeatherPage()),
      );
    } else if (target == 'market' || target == 'market_prices') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MarketPricesPage()),
      );
    } else if (target == 'crop' || target == 'my_crops') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyCropsPage()),
      );
    } else if (target == 'scheme' || target == 'government_schemes') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GovernmentSchemesPage()),
      );
    } else if (target == 'mitra' || target == 'farm_mitra') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FarmMitraPage()),
      );
    } else if (target == 'disease' || target == 'disease_detection') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DiseaseDetectionPage()),
      );
    }
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
            _buildHeader(user?.uid),
            Expanded(
              child: StreamBuilder<List<NotificationModel>>(
                stream: NotificationService.getNotificationsStream(user?.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _accent),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error loading notifications: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _grey),
                        ),
                      ),
                    );
                  }

                  final notifications = snapshot.data ?? [];

                  if (notifications.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationCard(notification, user?.uid);
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

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader(String? userId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
            child: const Icon(Icons.notifications_rounded, color: _darkAccent, size: 26),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Alerts & Farm Updates',
                  style: TextStyle(
                    color: _grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<int>(
            stream: NotificationService.getUnreadCountStream(userId),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount <= 0) return const SizedBox.shrink();

              return TextButton(
                onPressed: () => NotificationService.markAllAsRead(userId),
                style: TextButton.styleFrom(
                  foregroundColor: _accent,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                child: const Text(
                  'Mark all read',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NOTIFICATION CARD (READ / UNREAD STYLING)
  // ============================================================
  Widget _buildNotificationCard(NotificationModel notification, String? userId) {
    final isUnread = !notification.isRead;
    final typeColor = _getTypeColor(notification.type);
    final typeIcon = _getTypeIcon(notification.type);
    final timeStr = _formatRelativeTime(notification.createdAt);

    return Dismissible(
      key: Key(notification.id),
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
      onDismissed: (_) {
        NotificationService.deleteNotification(userId, notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification removed'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _handleNotificationTap(notification),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUnread ? _card2 : _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isUnread ? _accent.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.05),
              width: isUnread ? 1.2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isUnread ? _darkAccent : _bg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(typeIcon, color: typeColor, size: 21),
              ),
              const SizedBox(width: 13),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: TextStyle(
                            color: isUnread ? _accent : _grey,
                            fontSize: 10,
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: isUnread ? Colors.white.withValues(alpha: 0.9) : _grey,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    if (notification.targetPage != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                              color: _accent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, color: _accent, size: 13),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Unread Indicator Dot
              if (isUnread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _darkAccent,
              ),
              child: const Icon(Icons.notifications_off_outlined, color: _accent, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'No notifications yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Alerts about weather forecasts, market prices, and government schemes will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _grey,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
