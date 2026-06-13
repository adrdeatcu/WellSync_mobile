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