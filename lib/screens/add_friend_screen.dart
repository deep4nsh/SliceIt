import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_model.dart';
import '../services/friend_service.dart';
import '../services/contact_sync_service.dart';
import '../services/sms_invite_service.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../utils/deep_link_config.dart';
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
  List<Friend> _foundFriends = [];
  List<Map<String, String>> _notFoundContacts = [];
  List<Map<String, String>> _phoneContacts = [];
  Set<String> _selectedContactKeys = {};
  bool _isLoading = false;
  bool _isSyncingContacts = false;

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final results = await _friendService.searchUsers(query);
      setState(() => _foundFriends = results);
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

  Future<void> _loadPhoneContacts() async {
    setState(() => _isSyncingContacts = true);
    try {
      final contacts = await ContactSyncService.getContactsWithPhones();
      if (mounted) {
        setState(() => _phoneContacts = contacts);
        _showContactsBottomSheet();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading contacts: $e', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingContacts = false);
    }
  }

  void _showContactsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface2
          : AppColors.lightSurface1,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (bottomSheetContext, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final contactFilterController = TextEditingController();
            List<Map<String, String>> filteredContacts = _phoneContacts;

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.95,
              builder: (context, scrollController) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Contacts',
                          style: AppTextStyles.h2.copyWith(
                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ModernCard(
                          color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: TextField(
                            controller: contactFilterController,
                            style: AppTextStyles.bodyL.copyWith(
                              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Filter contacts...',
                              hintStyle: AppTextStyles.bodyL.copyWith(
                                color: (isDark
                                        ? AppColors.textLightSecondary
                                        : AppColors.textDarkSecondary)
                                    .withValues(alpha: 0.4),
                              ),
                              border: InputBorder.none,
                              suffixIcon: Icon(
                                Icons.search_rounded,
                                color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                              ),
                            ),
                            onChanged: (query) {
                              setState(() {
                                if (query.isEmpty) {
                                  filteredContacts = _phoneContacts;
                                } else {
                                  final lowerQuery = query.toLowerCase();
                                  filteredContacts = _phoneContacts
                                      .where((contact) {
                                        final name = contact['name']?.toLowerCase() ?? '';
                                        final phone = contact['phone']?.toLowerCase() ?? '';
                                        final email = contact['email']?.toLowerCase() ?? '';
                                        return name.contains(lowerQuery) ||
                                            phone.contains(lowerQuery) ||
                                            email.contains(lowerQuery);
                                      })
                                      .toList();
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: filteredContacts.length,
                      separatorBuilder: (_, __) => Divider(
                        color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final contact = filteredContacts[index];
                        final name = contact['name'] ?? 'Contact';
                        final phone = contact['phone'];
                        final email = contact['email'];
                        final contactKey = phone ?? email ?? '';
                        final isSelected = _selectedContactKeys.contains(contactKey);

                        return CheckboxListTile(
                          activeColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                          tileColor: Colors.transparent,
                          value: isSelected,
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedContactKeys.add(contactKey);
                              } else {
                                _selectedContactKeys.remove(contactKey);
                              }
                            });
                          },
                          title: Text(
                            name,
                            style: AppTextStyles.bodyL.copyWith(
                              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            ),
                          ),
                          subtitle: Text(
                            phone ?? email ?? 'No contact info',
                            style: AppTextStyles.label.copyWith(
                              color: (isDark
                                      ? AppColors.textLightSecondary
                                      : AppColors.textDarkSecondary)
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                          foregroundColor: isDark ? AppColors.textDarkPrimary : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                        ),
                        onPressed: _selectedContactKeys.isEmpty
                            ? null
                            : () async {
                                Navigator.of(bottomSheetContext).pop();
                                await _searchAndInviteContacts();
                              },
                        child: Text(
                          'Find or Invite (${_selectedContactKeys.length})',
                          style: AppTextStyles.button.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _searchAndInviteContacts() async {
    if (_selectedContactKeys.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Separate contacts by email/phone
      final selectedContacts = _phoneContacts
          .where((c) => _selectedContactKeys.contains(c['phone'] ?? c['email']))
          .toList();

      final emails = selectedContacts
          .where((c) => c['email'] != null && c['email']!.isNotEmpty)
          .map((c) => c['email']!)
          .toList();

      // Search for emails on SliceIt
      List<Friend> foundFriends = [];
      if (emails.isNotEmpty) {
        foundFriends = await _friendService.searchUsersByEmails(emails);
      }

      // Find contacts not on SliceIt
      final foundEmails = foundFriends.map((f) => f.email).toSet();
      final notFound = selectedContacts
          .where((c) => c['phone'] != null || (c['email'] != null && !foundEmails.contains(c['email'])))
          .toList();

      setState(() {
        _foundFriends = foundFriends;
        _notFoundContacts = notFound;
        _searchController.clear();
      });

      if (mounted) {
        if (foundFriends.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Found ${foundFriends.length} on SliceIt${notFound.isNotEmpty ? ', ${notFound.length} to invite' : ''}',
                style: AppTextStyles.bodyM,
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (notFound.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${notFound.length} contacts to invite',
                style: AppTextStyles.bodyM,
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching contacts: $e', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendSMSInvite(Map<String, String> contact) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final phoneNumber = contact['phone'];
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No phone number available', style: AppTextStyles.bodyM),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      final inviteLink = DeepLinkConfig.friendInviteHttp(user.uid);
      await SMSInviteService.sendSMSInvite(
        phoneNumber: SMSInviteService.formatPhoneNumber(phoneNumber),
        inviteLink: inviteLink,
        senderName: user.displayName ?? 'A friend',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invite sent to ${contact['name']!}', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending SMS: $e', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _copyInviteLink() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final inviteLink = DeepLinkConfig.friendInviteHttp(user.uid);
    await Clipboard.setData(ClipboardData(text: inviteLink));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite link copied!', style: AppTextStyles.bodyM),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showFriendInviteQRDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final inviteLink = DeepLinkConfig.friendInviteHttp(user.uid);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(
            color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
            width: 1,
          ),
        ),
        title: Text(
          'Invite to SliceIt',
          style: AppTextStyles.h2.copyWith(
            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: QrImageView(
                data: inviteLink,
                version: QrVersions.auto,
                size: 250,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan to add you as a friend',
              style: AppTextStyles.label.copyWith(
                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: inviteLink));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Link copied!', style: AppTextStyles.bodyM),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: Text(
              'Copy Link',
              style: AppTextStyles.button.copyWith(
                color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
              foregroundColor: isDark ? AppColors.textDarkPrimary : Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              await Share.share(
                'Add me as a friend on SliceIt: $inviteLink',
                subject: 'Join me on SliceIt!',
              );
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
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
                "Find people by email or import contacts to split bills. Not on SliceIt yet? Send them an SMS invite!",
                style: AppTextStyles.bodyM.copyWith(
                  color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                      .withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ModernCard(
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
                  ),
                  const SizedBox(width: 12),
                  ModernCard(
                    color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: Icon(
                        Icons.contacts_rounded,
                        color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                      ),
                      onPressed: _isSyncingContacts ? null : _loadPhoneContacts,
                      tooltip: 'Import from contacts',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ModernCard(
                      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                      padding: const EdgeInsets.all(8),
                      child: IconButton(
                        icon: Icon(
                          Icons.link_rounded,
                          color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                        ),
                        onPressed: _copyInviteLink,
                        tooltip: 'Copy invite link',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ModernCard(
                      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                      padding: const EdgeInsets.all(8),
                      child: IconButton(
                        icon: Icon(
                          Icons.qr_code_rounded,
                          color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                        ),
                        onPressed: _showFriendInviteQRDialog,
                        tooltip: 'Share QR code',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Share your link or QR code with friends',
                      style: AppTextStyles.label.copyWith(
                        color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_foundFriends.isEmpty && _notFoundContacts.isEmpty)
                Expanded(
                  child: Center(
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
                          "No results yet",
                          style: AppTextStyles.bodyL.copyWith(
                            color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Search by email or import from contacts",
                          style: AppTextStyles.label.copyWith(
                            color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      if (_foundFriends.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Already on SliceIt (${_foundFriends.length})',
                            style: AppTextStyles.bodyL.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            ),
                          ),
                        ),
                        ...List.generate(
                          _foundFriends.length,
                          (index) {
                            final friend = _foundFriends[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AnimatedListItem(
                                index: index,
                                child: ModernCard(
                                  color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor:
                                            isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                                        backgroundImage: friend.photoUrl != null
                                            ? NetworkImage(friend.photoUrl!)
                                            : null,
                                        child: friend.photoUrl == null
                                            ? Text(
                                                (friend.name ?? friend.email)[0].toUpperCase(),
                                                style: AppTextStyles.h3.copyWith(
                                                  color: isDark
                                                      ? AppColors.secondaryAccent
                                                      : AppColors.primaryAccent,
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
                                                color: isDark
                                                    ? AppColors.textLightPrimary
                                                    : AppColors.textDarkPrimary,
                                              ),
                                            ),
                                            Text(
                                              friend.email,
                                              style: AppTextStyles.label.copyWith(
                                                color: (isDark
                                                        ? AppColors.textLightSecondary
                                                        : AppColors.textDarkSecondary)
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
                              ),
                            );
                          },
                        ),
                        if (_notFoundContacts.isNotEmpty) const SizedBox(height: 24),
                      ],
                      if (_notFoundContacts.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Send SMS Invite (${_notFoundContacts.length})',
                            style: AppTextStyles.bodyL.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            ),
                          ),
                        ),
                        ...List.generate(
                          _notFoundContacts.length,
                          (index) {
                            final contact = _notFoundContacts[index];
                            final name = contact['name'] ?? 'Contact';
                            final phone = contact['phone'];
                            final email = contact['email'];
                            final contactInfo = phone ?? email ?? 'No info';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AnimatedListItem(
                                index: index,
                                child: ModernCard(
                                  color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor:
                                            isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                                        child: Text(
                                          name[0].toUpperCase(),
                                          style: AppTextStyles.h3.copyWith(
                                            color: isDark
                                                ? AppColors.secondaryAccent
                                                : AppColors.primaryAccent,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: AppTextStyles.bodyL.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? AppColors.textLightPrimary
                                                    : AppColors.textDarkPrimary,
                                              ),
                                            ),
                                            Text(
                                              contactInfo,
                                              style: AppTextStyles.label.copyWith(
                                                color: (isDark
                                                        ? AppColors.textLightSecondary
                                                        : AppColors.textDarkSecondary)
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.sms_rounded,
                                          color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                        ),
                                        onPressed: () => _sendSMSInvite(contact),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
