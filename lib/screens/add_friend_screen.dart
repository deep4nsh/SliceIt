import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../services/friend_service.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/modern_card.dart';
import '../widgets/mesh_background.dart';
import '../widgets/animated_list_item.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _searchController = TextEditingController();
  final _friendService = FriendService();
  List<Friend> _searchResults = [];
  bool _isLoading = false;

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final results = await _friendService.searchUsers(query);
      setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching: $e', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addFriend(Friend friend) async {
    try {
      await _friendService.addFriend(friend);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${friend.email} added to friends!', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding friend: $e', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            "Add Friend",
            style: AppTextStyles.h2.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                "Find people by email address to start splitting bills.",
                style: AppTextStyles.bodyM.copyWith(
                  color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                      .withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              ModernCard(
                color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  style: AppTextStyles.bodyL.copyWith(
                    color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: "Enter email address...",
                    hintStyle: AppTextStyles.bodyL.copyWith(
                      color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                          .withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.search_rounded,
                        color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                      ),
                      onPressed: _search,
                    ),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Expanded(
                  child: _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search_rounded,
                                size: 64,
                                color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                    .withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No users found",
                                style: AppTextStyles.bodyL.copyWith(
                                  color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final friend = _searchResults[index];
                            return AnimatedListItem(
                              index: index,
                              child: ModernCard(
                                color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                                      backgroundImage: friend.photoUrl != null
                                          ? NetworkImage(friend.photoUrl!)
                                          : null,
                                      child: friend.photoUrl == null
                                          ? Text(
                                              (friend.name ?? friend.email)[0].toUpperCase(),
                                              style: AppTextStyles.h3.copyWith(
                                                color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            friend.name ?? "User",
                                            style: AppTextStyles.bodyL.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                            ),
                                          ),
                                          Text(
                                            friend.email,
                                            style: AppTextStyles.label.copyWith(
                                              color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.person_add_rounded,
                                        color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                      ),
                                      onPressed: () => _addFriend(friend),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
