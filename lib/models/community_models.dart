// lib/community_models.dart

enum ActivityType { walk, run, steps, challenge }

class CommunityActivity {
  final String id;
  final String creatorUserId;
  final String? creatorName;
  final bool isFriendHost;
  final String title;
  final String? description;
  final String city;
  final String? locationDetails;
  final DateTime startTimeUtc;
  final DateTime endTimeUtc;
  final bool isPublic;
  final DateTime createdAt;
  final int participantsCount;
  final bool isCreator;

  CommunityActivity({
    required this.id,
    required this.creatorUserId,
    required this.creatorName,
    required this.isFriendHost,
    required this.title,
    required this.description,
    required this.city,
    required this.locationDetails,
    required this.startTimeUtc,
    required this.endTimeUtc,
    required this.isPublic,
    required this.createdAt,
    required this.participantsCount,
    required this.isCreator,
  });

  String get scheduledForLabel {
    return 'Starts • ${startTimeUtc.toLocal().toString()}';
  }
}

/// Chat message for an activity
class ActivityMessage {
  final int id;
  final String activityId;
  final String senderUserId;
  final String senderName; // full_name + (@username) or fallback
  final String content;
  final DateTime createdAt;

  ActivityMessage({
    required this.id,
    required this.activityId,
    required this.senderUserId,
    required this.senderName,
    required this.content,
    required this.createdAt,
  });
}

/// Invitation to join a community activity
class ActivityInvitation {
  final int id;
  final String activityId;
  final String activityTitle;
  final String city;
  final DateTime startTimeUtc;
  final String scheduledForLabel;
  final String inviterName;

  ActivityInvitation({
    required this.id,
    required this.activityId,
    required this.activityTitle,
    required this.city,
    required this.startTimeUtc,
    required this.scheduledForLabel,
    required this.inviterName,
  });
}

/// Utility to build display name like on web:
/// full name + (@username), or just one of them.
String buildDisplayNameMobile({
  String? fullName,
  String? username,
}) {
  final full = (fullName ?? '').trim();
  final user = (username ?? '').trim();

  if (full.isNotEmpty && user.isNotEmpty) {
    return '$full (@$user)';
  }
  if (full.isNotEmpty) return full;
  if (user.isNotEmpty) return '@$user';
  return 'Participant';
}