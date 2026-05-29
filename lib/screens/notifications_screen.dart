import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/modern_card.dart';
import '../widgets/mesh_background.dart';
import '../widgets/animated_list_item.dart';
import '../services/app_notification_service.dart';
import '../models/app_notification.dart';
import 'group_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = AppNotificationService();
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  String _getRelativeTime(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('dd MMM').format(createdAt);
    }
  }

  Map<String, dynamic> _getNotificationStyle(String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case 'expense_added':
        return {
          'icon': Icons.receipt_long_rounded,
          'color': AppColors.secondaryAccent,
        };
      case 'group_invite':
        return {
          'icon': Icons.group_add_rounded,
          'color': const Color(0xFFEC4899),
        };
      case 'settlement':
        return {
          'icon': Icons.handshake_rounded,
          'color': AppColors.success,
        };
      case 'split_bill':
        return {
          'icon': Icons.call_split_rounded,
          'color': const Color(0xFFF59E0B),
        };
      case 'payment_reminder':
        return {
          'icon': Icons.alarm_rounded,
          'color': AppColors.error,
        };
      default:
        return {
          'icon': Icons.notifications_rounded,
          'color': isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
        };
    }
  }

  void _handleNotificationTap(AppNotification notification) async {
    await _notificationService.markRead(_currentUserId, notification.id);

    if (notification.relatedId != null && mounted) {
      if (notification.type == 'expense_added' || notification.type == 'settlement') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupDetailScreen(groupId: notification.relatedId!),
          ),
        );
      } else if (notification.type == 'group_invite') {
        Navigator.pushNamed(context, '/groups');
      } else if (notification.type == 'split_bill') {
        Navigator.pushNamed(context, '/split');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: AppTextStyles.h2.copyWith(
            color: isDark ? Colors.white : AppColors.textDarkPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : AppColors.textDarkPrimary,
        elevation: 0,
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () => _notificationService.markAllRead(_currentUserId),
            child: Text(
              'Mark all read',
              style: AppTextStyles.bodyM.copyWith(
                color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: MeshBackground(
        child: StreamBuilder<List<AppNotification>>(
          stream: _notificationService.getNotifications(_currentUserId),
          initialData: const [],
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && snapshot.data!.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final notifications = snapshot.data ?? [];

            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 80,
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All caught up!',
                      style: AppTextStyles.h3.copyWith(
                        color: isDark ? Colors.white : AppColors.textDarkPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No notifications yet.',
                      style: AppTextStyles.bodyM.copyWith(
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                  sliver: SliverList.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final style = _getNotificationStyle(notification.type);
                      final icon = style['icon'] as IconData;
                      final color = style['color'] as Color;

                      return AnimatedListItem(
                        index: index,
                        child: ModernCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          onTap: () => _handleNotificationTap(notification),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                ),
                                child: Icon(icon, color: color, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notification.title,
                                      style: AppTextStyles.bodyL.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: notification.isRead
                                            ? (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                            : (isDark ? Colors.white : AppColors.textDarkPrimary),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notification.body,
                                      style: AppTextStyles.bodyM.copyWith(
                                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _getRelativeTime(notification.createdAt),
                                      style: AppTextStyles.label.copyWith(
                                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!notification.isRead) ...[
                                const SizedBox(width: 12),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            );
          },
        ),
      ),
    );
  }
}
