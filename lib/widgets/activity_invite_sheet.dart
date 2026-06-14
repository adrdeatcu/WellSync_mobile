// lib/widgets/activity_invite_sheet.dart
import 'package:flutter/material.dart';

import '../community_repository.dart';
import '../friends_repository.dart';
import '../models/community_models.dart';

class ActivityInviteSheet extends StatefulWidget {
  final CommunityActivity activity;
  final FriendsRepository friendsRepo;
  final CommunityRepository communityRepo;

  const ActivityInviteSheet({
    super.key,
    required this.activity,
    required this.friendsRepo,
    required this.communityRepo,
  });

  @override
  State<ActivityInviteSheet> createState() => _ActivityInviteSheetState();
}

class _ActivityInviteSheetState extends State<ActivityInviteSheet> {
  bool _loading = true;
  String? _error;

  FriendsOverview? _friendsOverview;
  Set<String> _joinedFriendIds = {};
  Set<String> _invitedFriendIds = {};

  bool _inviting = false;
  String? _inviteError;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
      _inviteError = null;
    });

    try {
      final friendsFuture = widget.friendsRepo.getFriendsOverview();
      final joinedFuture = widget.communityRepo
          .listJoinedUserIdsForActivity(widget.activity.id);
      final invitedFuture = widget.communityRepo
          .listPendingInviteeIdsForActivity(widget.activity.id);

      final results = await Future.wait([
        friendsFuture,
        joinedFuture,
        invitedFuture,
      ]);

      if (!mounted) return;

      setState(() {
        _friendsOverview = results[0] as FriendsOverview;
        _joinedFriendIds = results[1] as Set<String>;
        _invitedFriendIds = results[2] as Set<String>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load friends or invitations.';
      });
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Future<void> _handleInvite(String friendId) async {
    if (_inviting) return;

    setState(() {
      _inviting = true;
      _inviteError = null;
    });

    try {
      await widget.communityRepo.inviteFriendToActivity(
        activityId: widget.activity.id,
        inviteeUserId: friendId,
      );

      if (!mounted) return;
      setState(() {
        _invitedFriendIds = {..._invitedFriendIds, friendId};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inviteError = 'Failed to send invitation: $e';
      });
      // Optional: also log to console for debugging
      // // ignore: avoid_print
      // print('inviteFriendToActivity error: $e');
    }

    if (!mounted) return;
    setState(() {
      _inviting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const brandText = Color(0xFF1F3B3A);
    const brandMuted = Color(0xFF5D7B79);
    const brandBorder = Color(0xFFD8E9E6);
    const brandDeep = Color(0xFF1F5F63);

    final friends = _friendsOverview?.friends ?? [];

    return SafeArea(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Invite friends',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: brandText,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 8),
            child: Text(
              'Choose friends to invite to “${widget.activity.title}”.',
              style: const TextStyle(
                fontSize: 13,
                color: brandMuted,
              ),
            ),
          ),
          if (_inviteError != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _inviteError!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                ),
              ),
            ),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (friends.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'You have no friends to invite yet.',
                  style: TextStyle(
                    fontSize: 13,
                    color: brandMuted,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListView.separated(
                  itemCount: friends.length,
                  separatorBuilder: (_, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final f = friends[index];
                    final joined = _joinedFriendIds.contains(f.id);
                    final invited = _invitedFriendIds.contains(f.id);

                    Widget right;
                    if (joined) {
                      right = const Text(
                        'Joined',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    } else if (invited) {
                      right = const Text(
                        'Invited',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8AA19F),
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    } else {
                      right = TextButton(
                        onPressed: _inviting ? null : () => _handleInvite(f.id),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          backgroundColor: brandDeep,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          _inviting ? 'Inviting...' : 'Invite',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }

                    final name = f.fullName?.trim().isNotEmpty == true
                        ? f.fullName!.trim()
                        : 'Unnamed';
                    final username = f.username?.trim().isNotEmpty == true
                        ? '@${f.username!.trim()}'
                        : 'No username';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: brandBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: brandText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  username,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: brandMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          right,
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}