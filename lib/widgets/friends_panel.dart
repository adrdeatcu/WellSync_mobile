// lib/widgets/friends_panel.dart
import 'package:flutter/material.dart';

import '../friends_repository.dart';
import '../community_repository.dart';
import '../models/community_models.dart';

class FriendsPanelSheet extends StatefulWidget {
  final FriendsRepository friendsRepo;
  final CommunityRepository communityRepo;

  const FriendsPanelSheet({
    super.key,
    required this.friendsRepo,
    required this.communityRepo,
  });

  @override
  State<FriendsPanelSheet> createState() => _FriendsPanelSheetState();
}

class _FriendsPanelSheetState extends State<FriendsPanelSheet> {
  FriendsOverview? _overview;
  bool _friendsLoading = false;
  String? _friendsError;

  String _searchQuery = '';
  List<FriendUser> _searchResults = [];
  bool _searchLoading = false;
  String? _searchError;

  bool _friendsListOpen = true;

  // Activity invitations
  List<ActivityInvitation> _activityInvitations = [];
  bool _invitesLoading = false;
  String? _invitesError;

  @override
  void initState() {
    super.initState();
    _loadFriendsOverview();
    _loadActivityInvitations();
  }

  Future<void> _loadFriendsOverview() async {
    setState(() {
      _friendsLoading = true;
      _friendsError = null;
    });

    try {
      final data = await widget.friendsRepo.getFriendsOverview();
      if (!mounted) return;
      setState(() {
        _overview = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _friendsError = 'Failed to load friends: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _friendsLoading = false;
        });
      }
    }
  }

  Future<void> _loadActivityInvitations() async {
    setState(() {
      _invitesLoading = true;
      _invitesError = null;
    });

    try {
      final invites =
          await widget.communityRepo.listMyActivityInvitations();
      if (!mounted) return;
      setState(() {
        _activityInvitations = invites;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invitesError = 'Failed to load activity invitations: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _invitesLoading = false;
        });
      }
    }
  }

  Future<void> _handleInvitationDecision(
    ActivityInvitation invitation,
    String decision, // 'accept' or 'decline'
  ) async {
    try {
      await widget.communityRepo.respondToActivityInvitation(
        invitationId: invitation.id,
        decision: decision,
      );
      await _loadActivityInvitations();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'accept'
                ? 'Activity invitation accepted'
                : 'Activity invitation declined',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to respond to invitation: $e'),
        ),
      );
    }
  }

  Future<void> _handleSearchSubmit() async {
    final q = _searchQuery.trim();
    if (q.isEmpty) return;

    setState(() {
      _searchLoading = true;
      _searchError = null;
      _searchResults = [];
    });

    try {
      final results =
          await widget.friendsRepo.searchUsersByNameOrUsername(q);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = 'Search failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _searchLoading = false;
        });
      }
    }
  }

  Future<void> _handleSendFriendRequest(String userId) async {
    try {
      await widget.friendsRepo.sendFriendRequest(userId);
      await _loadFriendsOverview();
      await _handleSearchSubmit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e')),
      );
    }
  }

  Future<void> _handleAcceptFriend(String userId) async {
    try {
      await widget.friendsRepo.acceptFriendRequest(userId);
      await _loadFriendsOverview();
      await _handleSearchSubmit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request accepted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept request: $e')),
      );
    }
  }

  Future<void> _handleDeclineFriend(String userId) async {
    try {
      await widget.friendsRepo.declineFriendRequest(userId);
      await _loadFriendsOverview();
      await _handleSearchSubmit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request declined')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decline request: $e')),
      );
    }
  }

  bool _isFriend(String userId) {
    final overview = _overview;
    if (overview == null) return false;
    return overview.friends.any((f) => f.id == userId);
  }

  bool _hasOutgoing(String userId) {
    final overview = _overview;
    if (overview == null) return false;
    return overview.outgoingRequests.any((f) => f.id == userId);
  }

  bool _hasIncoming(String userId) {
    final overview = _overview;
    if (overview == null) return false;
    return overview.incomingRequests.any((f) => f.id == userId);
  }

  @override
  Widget build(BuildContext context) {
    const brandBorder = Color(0xFFD8E9E6);
    const brandText = Color(0xFF1F3B3A);
    const brandMuted = Color(0xFF5D7B79);
    const brandDeep = Color(0xFF1F5F63);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Friends & requests',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: brandText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                setState(() {
                  _friendsListOpen = !_friendsListOpen;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Friends & requests',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: brandText,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _friendsListOpen ? 0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.chevron_right,
                      color: brandMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _friendsListOpen
                  ? SingleChildScrollView(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: brandBorder),
                          color: const Color(0xFFF5FAF8),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Search by name or @username',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      const BorderSide(color: brandBorder),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              onSubmitted: (_) => _handleSearchSubmit(),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6),
                                  backgroundColor: brandDeep,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _searchLoading ||
                                        _searchQuery.trim().isEmpty
                                    ? null
                                    : _handleSearchSubmit,
                                child: Text(
                                  _searchLoading ? 'Searching…' : 'Search',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (_searchError != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _searchError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                            if (_searchResults.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 150),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: brandBorder),
                                  ),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final u = _searchResults[index];
                                    final alreadyFriend = _isFriend(u.id);
                                    final outgoing = _hasOutgoing(u.id);
                                    final incoming = _hasIncoming(u.id);

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                u.fullName ?? 'Unnamed',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: brandText,
                                                ),
                                              ),
                                              Text(
                                                u.username != null
                                                    ? '@${u.username}'
                                                    : 'No username',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: brandMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (alreadyFriend)
                                            const Text(
                                              'Already friends',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF8AA19F),
                                              ),
                                            )
                                          else if (outgoing)
                                            const Text(
                                              'Request sent',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF8AA19F),
                                              ),
                                            )
                                          else if (incoming)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextButton(
                                                  onPressed: () =>
                                                      _handleAcceptFriend(
                                                    u.id,
                                                  ),
                                                  style: TextButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    minimumSize: Size.zero,
                                                  ),
                                                  child: const Text(
                                                    'Accept',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                TextButton(
                                                  onPressed: () =>
                                                      _handleDeclineFriend(
                                                    u.id,
                                                  ),
                                                  style: TextButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.red,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    minimumSize: Size.zero,
                                                  ),
                                                  child: const Text(
                                                    'Decline',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            TextButton(
                                              onPressed: () =>
                                                  _handleSendFriendRequest(
                                                u.id,
                                              ),
                                              style: TextButton.styleFrom(
                                                backgroundColor: brandDeep,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                minimumSize: Size.zero,
                                              ),
                                              child: const Text(
                                                'Add',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            if (_friendsError != null)
                              Text(
                                _friendsError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            if (_friendsLoading)
                              const Text(
                                'Loading friends…',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: brandMuted,
                                ),
                              )
                            else
                              _buildFriendsOverviewSection(
                                overview: _overview,
                                brandMuted: brandMuted,
                              ),
                            const SizedBox(height: 12),
                            _buildActivityInvitationsSection(brandMuted),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsOverviewSection({
    required FriendsOverview? overview,
    required Color brandMuted,
  }) {
    if (overview == null) {
      return Text(
        'No friends loaded yet.',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Incoming requests',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: brandMuted,
          ),
        ),
        const SizedBox(height: 2),
        if (overview.incomingRequests.isEmpty)
          Text(
            'None',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          )
        else
          Column(
            children: overview.incomingRequests.map((u) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _friendUserLabel(u, brandMuted),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _handleAcceptFriend(u.id),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: () => _handleDeclineFriend(u.id),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: const Text(
                            'Decline',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
        Text(
          'Sent requests',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: brandMuted,
          ),
        ),
        const SizedBox(height: 2),
        if (overview.outgoingRequests.isEmpty)
          Text(
            'None',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          )
        else
          Column(
            children: overview.outgoingRequests.map((u) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _friendUserLabel(u, brandMuted),
                    Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
        Text(
          'Friends',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: brandMuted,
          ),
        ),
        const SizedBox(height: 2),
        if (overview.friends.isEmpty)
          Text(
            'You have no friends yet.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          )
        else
          SizedBox(
            height: 140,
            child: ListView.builder(
              itemCount: overview.friends.length,
              itemBuilder: (context, index) {
                final u = overview.friends[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _friendUserLabel(u, brandMuted),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildActivityInvitationsSection(Color brandMuted) {
    const brandText = Color(0xFF1F3B3A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity invitations',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: brandMuted,
          ),
        ),
        const SizedBox(height: 4),
        if (_invitesError != null)
          Text(
            _invitesError!,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.red,
            ),
          )
        else if (_invitesLoading)
          Text(
            'Loading invitations…',
            style: TextStyle(
              fontSize: 12,
              color: brandMuted,
            ),
          )
        else if (_activityInvitations.isEmpty)
          Text(
            'No invitations at the moment.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          )
        else
          Column(
            children: _activityInvitations.map((inv) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFD8E9E6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.activityTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: brandText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${inv.city} • ${inv.scheduledForLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          color: brandMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Invited by ${inv.inviterName}',
                        style: TextStyle(
                          fontSize: 11,
                          color: brandMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                _handleInvitationDecision(inv, 'decline'),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                            ),
                            child: const Text(
                              'Decline',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () =>
                                _handleInvitationDecision(inv, 'accept'),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                            ),
                            child: const Text(
                              'Accept',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _friendUserLabel(FriendUser u, Color brandMuted) {
    const brandText = Color(0xFF1F3B3A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          u.fullName ?? 'Unnamed',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: brandText,
          ),
        ),
        Text(
          u.username != null ? '@${u.username}' : 'No username',
          style: TextStyle(
            fontSize: 11,
            color: brandMuted,
          ),
        ),
      ],
    );
  }
}