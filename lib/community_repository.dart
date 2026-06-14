// lib/community_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/community_models.dart';

class CommunityRepository {
  final SupabaseClient supabase;

  CommunityRepository({required this.supabase});

  Future<String> _requireUserId() async {
    final session = supabase.auth.currentSession;
    final user = session?.user;
    if (user == null) {
      throw Exception('Not logged in');
    }
    return user.id;
  }

  // -------- Helpers --------

  Future<Map<String, Map<String, dynamic>>> _loadProfiles(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};

    final data = await supabase
        .from('profiles')
        .select('id, full_name, username')
        .filter('id', 'in', '(${userIds.join(',')})');

    final map = <String, Map<String, dynamic>>{};
    for (final row in data as List) {
      final r = row as Map<String, dynamic>;
      map[r['id'] as String] = {
        'full_name': r['full_name'],
        'username': r['username'],
      };
    }
    return map;
  }

  String? _buildDisplayName(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final full = (profile['full_name'] as String?)?.trim() ?? '';
    final user = (profile['username'] as String?)?.trim() ?? '';
    if (full.isNotEmpty && user.isNotEmpty) return '$full (@$user)';
    if (full.isNotEmpty) return full;
    if (user.isNotEmpty) return '@$user';
    return null;
  }

  // -------- Public activities --------

  Future<List<CommunityActivity>> listPublicActivities() async {
    final userId = await _requireUserId();

    final nowIso = DateTime.now().toUtc().toIso8601String();

    final data = await supabase
        .from('community_activities')
        .select(
          'id, creator_user_id, title, description, city, '
          'location_details, start_time_utc, end_time_utc, '
          'is_public, created_at',
        )
        .eq('is_public', true)
        .gte('end_time_utc', nowIso)
        .order('start_time_utc');

    final activities = (data as List).cast<Map<String, dynamic>>();
    if (activities.isEmpty) return [];

    // load participant counts
    final ids = activities.map((a) => a['id'] as String).toList();

    final membersData = await supabase
        .from('community_activity_members')
        .select('activity_id')
        .filter('activity_id', 'in', '(${ids.join(',')})');

    final counts = <String, int>{};
    for (final row in membersData as List) {
      final r = row as Map<String, dynamic>;
      final actId = r['activity_id'] as String;
      counts[actId] = (counts[actId] ?? 0) + 1;
    }

    // load creator profiles
    final creatorIds = activities
        .map((a) => a['creator_user_id'] as String)
        .toSet()
        .toList();
    final profilesById = await _loadProfiles(creatorIds);

    // load friend relations for current user vs creators
    final friendsData = await supabase
        .from('friends')
        .select('user_id, friend_user_id, status')
        .eq('status', 'accepted')
        .or(
          'and(user_id.eq.$userId,friend_user_id.in.(${creatorIds.join(',')})),'
          'and(friend_user_id.eq.$userId,user_id.in.(${creatorIds.join(',')}))',
        );

    final friendCreatorIds = <String>{};
    for (final row in friendsData as List) {
      final r = row as Map<String, dynamic>;
      final u = r['user_id'] as String;
      final f = r['friend_user_id'] as String;
      final other = u == userId ? f : u;
      friendCreatorIds.add(other);
    }

    return activities.map((a) {
      final creatorId = a['creator_user_id'] as String;
      final profile = profilesById[creatorId];
      final creatorName = _buildDisplayName(profile) ?? 'Host';
      final isFriendHost = friendCreatorIds.contains(creatorId);

      return CommunityActivity(
        id: a['id'] as String,
        creatorUserId: creatorId,
        creatorName: creatorName,
        isFriendHost: isFriendHost,
        title: a['title'] as String,
        description: a['description'] as String?,
        city: a['city'] as String,
        locationDetails: a['location_details'] as String?,
        startTimeUtc: DateTime.parse(a['start_time_utc'] as String),
        endTimeUtc: DateTime.parse(a['end_time_utc'] as String),
        isPublic: a['is_public'] as bool,
        createdAt: DateTime.parse(a['created_at'] as String),
        participantsCount: counts[a['id'] as String] ?? 0,
        isCreator: false,
      );
    }).toList();
  }

  // -------- My activities --------

  Future<List<CommunityActivity>> listMyActivities() async {
    final userId = await _requireUserId();

    final data = await supabase
        .from('community_activity_members')
        .select(
          'role, activity:community_activities ('
          'id, creator_user_id, title, description, city, '
          'location_details, start_time_utc, end_time_utc, '
          'is_public, created_at'
          ')',
        )
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    final rows = (data as List).cast<Map<String, dynamic>>();
    final activities = <CommunityActivity>[];
    final ids = <String>[];

    for (final row in rows) {
      final act = row['activity'] as Map<String, dynamic>?;
      if (act == null) continue;

      final actId = act['id'] as String;
      final creatorId = act['creator_user_id'] as String;
      final role = row['role'] as String;
      final isCreator = role == 'creator';

      activities.add(
        CommunityActivity(
          id: actId,
          creatorUserId: creatorId,
          creatorName: isCreator ? 'You' : 'Host',
          isFriendHost: false,
          title: act['title'] as String,
          description: act['description'] as String?,
          city: act['city'] as String,
          locationDetails: act['location_details'] as String?,
          startTimeUtc:
              DateTime.parse(act['start_time_utc'] as String),
          endTimeUtc:
              DateTime.parse(act['end_time_utc'] as String),
          isPublic: act['is_public'] as bool,
          createdAt: DateTime.parse(act['created_at'] as String),
          participantsCount: 0,
          isCreator: isCreator,
        ),
      );
      ids.add(actId);
    }

    if (ids.isEmpty) return [];

    final membersData = await supabase
        .from('community_activity_members')
        .select('activity_id')
        .filter('activity_id', 'in', '(${ids.join(',')})');

    final counts = <String, int>{};
    for (final row in membersData as List) {
      final r = row as Map<String, dynamic>;
      final actId = r['activity_id'] as String;
      counts[actId] = (counts[actId] ?? 0) + 1;
    }

    return activities
        .map(
          (a) => CommunityActivity(
            id: a.id,
            creatorUserId: a.creatorUserId,
            creatorName: a.creatorName,
            isFriendHost: a.isFriendHost,
            title: a.title,
            description: a.description,
            city: a.city,
            locationDetails: a.locationDetails,
            startTimeUtc: a.startTimeUtc,
            endTimeUtc: a.endTimeUtc,
            isPublic: a.isPublic,
            createdAt: a.createdAt,
            participantsCount: counts[a.id] ?? 0,
            isCreator: a.isCreator,
          ),
        )
        .toList();
  }

  // -------- Create, join, leave, delete --------

  Future<CommunityActivity> createActivity({
    required String title,
    String? description,
    required String city,
    String? locationDetails,
    required DateTime startTimeLocal,
    required DateTime endTimeLocal,
    required bool isPublic,
  }) async {
    final userId = await _requireUserId();

    final startUtc = startTimeLocal.toUtc().toIso8601String();
    final endUtc = endTimeLocal.toUtc().toIso8601String();

    try {
      final inserted = await supabase
          .from('community_activities')
          .insert({
            'creator_user_id': userId,
            'title': title,
            'description': description,
            'city': city,
            'location_details': locationDetails,
            'start_time_utc': startUtc,
            'end_time_utc': endUtc,
            'is_public': isPublic,
          })
          .select(
            'id, creator_user_id, title, description, city, '
            'location_details, start_time_utc, end_time_utc, '
            'is_public, created_at',
          )
          .single();

      final row = inserted;

      await supabase.from('community_activity_members').insert({
        'activity_id': row['id'],
        'user_id': userId,
        'role': 'creator',
      });

      return CommunityActivity(
        id: row['id'] as String,
        creatorUserId: row['creator_user_id'] as String,
        creatorName: 'You',
        isFriendHost: false,
        title: row['title'] as String,
        description: row['description'] as String?,
        city: row['city'] as String,
        locationDetails: row['location_details'] as String?,
        startTimeUtc: DateTime.parse(row['start_time_utc'] as String),
        endTimeUtc: DateTime.parse(row['end_time_utc'] as String),
        isPublic: row['is_public'] as bool,
        createdAt: DateTime.parse(row['created_at'] as String),
        participantsCount: 1,
        isCreator: true,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> joinActivity(String activityId) async {
    final userId = await _requireUserId();

    final activity = await supabase
        .from('community_activities')
        .select('creator_user_id')
        .eq('id', activityId)
        .maybeSingle();

    if (activity == null) {
      throw Exception('Activity not found');
    }

    final creatorId = activity['creator_user_id'] as String;
    final role = creatorId == userId ? 'creator' : 'member';

    await supabase.from('community_activity_members').insert({
      'activity_id': activityId,
      'user_id': userId,
      'role': role,
    });
  }

  Future<void> leaveActivity(String activityId) async {
    final userId = await _requireUserId();

    await supabase
        .from('community_activity_members')
        .delete()
        .eq('activity_id', activityId)
        .eq('user_id', userId);
  }

  Future<void> deleteActivityIfCreator(String activityId) async {
    final userId = await _requireUserId();

    final activity = await supabase
        .from('community_activities')
        .select('id, creator_user_id')
        .eq('id', activityId)
        .maybeSingle();

    if (activity == null) {
      throw Exception('Activity not found');
    }
    if (activity['creator_user_id'] != userId) {
      throw Exception('Only the creator can delete this activity');
    }

    await supabase
        .from('community_activities')
        .delete()
        .eq('id', activityId);
  }

  // -------- Activity chat --------

  Future<List<ActivityMessage>> listActivityMessages(String activityId) async {
    await _requireUserId();

    final data = await supabase
        .from('community_activity_messages')
        .select(
          'id, activity_id, sender_user_id, content, created_at',
        )
        .eq('activity_id', activityId)
        .order('created_at', ascending: true); // explicit ascending

    final rows = (data as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return [];

    final senderIds = rows
        .map((row) => row['sender_user_id'] as String)
        .toSet()
        .toList();

    final profilesData = await supabase
        .from('profiles')
        .select('id, full_name, username')
        .filter('id', 'in', '(${senderIds.join(',')})');

    final profilesRows =
        (profilesData as List).cast<Map<String, dynamic>>();

    final byId = <String, Map<String, String?>>{};
    for (final row in profilesRows) {
      final id = row['id'] as String;
      byId[id] = {
        'full_name': row['full_name'] as String?,
        'username': row['username'] as String?,
      };
    }

    return rows.map((row) {
      final senderId = row['sender_user_id'] as String;
      final profile = byId[senderId];
      final senderName = buildDisplayNameMobile(
        fullName: profile?['full_name'],
        username: profile?['username'],
      );

      return ActivityMessage(
        id: row['id'] as int,
        activityId: row['activity_id'] as String,
        senderUserId: senderId,
        senderName: senderName,
        content: row['content'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  Future<ActivityMessage> sendActivityMessage({
    required String activityId,
    required String content,
  }) async {
    final userId = await _requireUserId();
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw Exception('Message content cannot be empty');
    }

    final inserted = await supabase
        .from('community_activity_messages')
        .insert({
          'activity_id': activityId,
          'sender_user_id': userId,
          'content': trimmed,
        })
        .select(
          'id, activity_id, sender_user_id, content, created_at',
        )
        .single();

    final profileData = await supabase
        .from('profiles')
        .select('full_name, username')
        .eq('id', userId)
        .maybeSingle();

    final senderName = buildDisplayNameMobile(
      fullName: profileData?['full_name'] as String?,
      username: profileData?['username'] as String?,
    );

    return ActivityMessage(
      id: inserted['id'] as int,
      activityId: inserted['activity_id'] as String,
      senderUserId: inserted['sender_user_id'] as String,
      senderName: senderName,
      content: inserted['content'] as String,
      createdAt: DateTime.parse(inserted['created_at'] as String),
    );
  }
}