// lib/friends_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendUser {
  final String id;
  final String? username;
  final String? fullName;

  FriendUser({
    required this.id,
    required this.username,
    required this.fullName,
  });
}

class FriendsOverview {
  final List<FriendUser> friends;
  final List<FriendUser> incomingRequests;
  final List<FriendUser> outgoingRequests;

  FriendsOverview({
    required this.friends,
    required this.incomingRequests,
    required this.outgoingRequests,
  });
}

class FriendsRepository {
  final SupabaseClient supabase;

  FriendsRepository({required this.supabase});

  Future<String> _requireUserId() async {
    final session = supabase.auth.currentSession;
    final user = session?.user;
    if (user == null) {
      throw Exception('Not logged in');
    }
    return user.id;
  }

  Future<List<FriendUser>> searchUsersByNameOrUsername(
    String query, {
    int limit = 10,
  }) async {
    final userId = await _requireUserId();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final data = await supabase
        .from('profiles')
        .select('id, username, full_name')
        .neq('id', userId)
        .or(
          'username.ilike.%$trimmed%,full_name.ilike.%$trimmed%',
        )
        .limit(limit);

    final rows = (data as List).cast<Map<String, dynamic>>();
    return rows
        .map(
          (row) => FriendUser(
            id: row['id'] as String,
            username: row['username'] as String?,
            fullName: row['full_name'] as String?,
          ),
        )
        .toList();
  }

  Future<FriendsOverview> getFriendsOverview() async {
    final userId = await _requireUserId();

    final data = await supabase
        .from('friends')
        .select('id, user_id, friend_user_id, status, created_at')
        .or('user_id.eq.$userId,friend_user_id.eq.$userId');

    final rows = (data as List).cast<Map<String, dynamic>>();

    final friendIds = <String>{};
    final incomingIds = <String>{};
    final outgoingIds = <String>{};

    for (final row in rows) {
      final userIdRow = row['user_id'] as String;
      final friendUserIdRow = row['friend_user_id'] as String;
      final status = row['status'] as String;
      final otherId = userIdRow == userId ? friendUserIdRow : userIdRow;

      if (status == 'accepted') {
        friendIds.add(otherId);
      } else if (status == 'pending') {
        if (userIdRow == userId) {
          outgoingIds.add(otherId);
        } else {
          incomingIds.add(otherId);
        }
      }
    }

    final allIds = <String>{
      ...friendIds,
      ...incomingIds,
      ...outgoingIds,
    };

    if (allIds.isEmpty) {
      return FriendsOverview(
        friends: [],
        incomingRequests: [],
        outgoingRequests: [],
      );
    }

    final profilesData = await supabase
        .from('profiles')
        .select('id, username, full_name')
        .filter('id', 'in', '(${allIds.join(',')})');

    final profilesRows =
        (profilesData as List).cast<Map<String, dynamic>>();

    final byId = <String, FriendUser>{};
    for (final row in profilesRows) {
      final id = row['id'] as String;
      byId[id] = FriendUser(
        id: id,
        username: row['username'] as String?,
        fullName: row['full_name'] as String?,
      );
    }

    List<FriendUser> toList(Set<String> ids) =>
        ids.map((id) {
          final existing = byId[id];
          if (existing != null) return existing;
          return FriendUser(
            id: id,
            username: null,
            fullName: null,
          );
        }).toList();

    return FriendsOverview(
      friends: toList(friendIds),
      incomingRequests: toList(incomingIds),
      outgoingRequests: toList(outgoingIds),
    );
  }

  Future<void> sendFriendRequest(String targetUserId) async {
    final currentUserId = await _requireUserId();
    if (currentUserId == targetUserId) {
      throw Exception('Cannot add yourself as a friend');
    }

    await supabase.from('friends').upsert(
      {
        'user_id': currentUserId,
        'friend_user_id': targetUserId,
        'status': 'pending',
      },
      onConflict: 'user_id,friend_user_id',
    );
  }

  Future<void> acceptFriendRequest(String otherUserId) async {
    final currentUserId = await _requireUserId();

    await supabase
        .from('friends')
        .update({'status': 'accepted'})
        .eq('user_id', otherUserId)
        .eq('friend_user_id', currentUserId)
        .eq('status', 'pending');
  }

  Future<void> declineFriendRequest(String otherUserId) async {
    final currentUserId = await _requireUserId();

    await supabase
        .from('friends')
        .delete()
        .eq('user_id', otherUserId)
        .eq('friend_user_id', currentUserId)
        .eq('status', 'pending');
  }
}