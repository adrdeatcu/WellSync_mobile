// lib/mobile_community_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_repository.dart';
import 'models/community_models.dart';

class MobileCommunityPage extends StatefulWidget {
  const MobileCommunityPage({super.key});

  @override
  State<MobileCommunityPage> createState() => _MobileCommunityPageState();
}

class _MobileCommunityPageState extends State<MobileCommunityPage> {
  late final CommunityRepository _repo;

  bool _loadingMy = false;
  bool _loadingPublic = false;
  String? _errorMy;
  String? _errorPublic;

  List<CommunityActivity> _myActivities = [];
  List<CommunityActivity> _publicAll = [];
  List<CommunityActivity> _publicFiltered = [];

  String _cityFilter = '';
  bool _friendsOnly = false;

  bool _joining = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _repo = CommunityRepository(supabase: Supabase.instance.client);
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadMyActivities(),
      _loadPublicActivities(),
    ]);
  }

  Future<void> _loadMyActivities() async {
    setState(() {
      _loadingMy = true;
      _errorMy = null;
    });

    try {
      final myActs = await _repo.listMyActivities();
      if (!mounted) return;
      setState(() {
        _myActivities = myActs;
      });
      _applyPublicFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMy = 'Failed to load your activities.';
      });
    }

    if (!mounted) return;
    setState(() {
      _loadingMy = false;
    });
  }

  Future<void> _loadPublicActivities() async {
    setState(() {
      _loadingPublic = true;
      _errorPublic = null;
    });

    try {
      final public = await _repo.listPublicActivities();
      if (!mounted) return;
      setState(() {
        _publicAll = public;
      });
      _applyPublicFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorPublic = 'Failed to load activities.';
      });
    }

    if (!mounted) return;
    setState(() {
      _loadingPublic = false;
    });
  }

  void _applyPublicFilters() {
    final q = _cityFilter.trim().toLowerCase();
    final myIds = _myActivities.map((a) => a.id).toSet();

    var base = _publicAll.where((a) => !myIds.contains(a.id)).toList();

    if (_friendsOnly) {
      base = base.where((a) => a.isFriendHost).toList();
    }

    if (q.isNotEmpty) {
      base = base
          .where((a) => (a.city.toLowerCase()).contains(q))
          .toList();
    }

    setState(() {
      _publicFiltered = base;
    });
  }

  Future<void> _handleJoin(CommunityActivity activity) async {
    if (_joining) return;
    setState(() {
      _joining = true;
    });

    try {
      await _repo.joinActivity(activity.id);
      if (!mounted) return;

      final joined = CommunityActivity(
        id: activity.id,
        creatorUserId: activity.creatorUserId,
        creatorName: activity.creatorName,
        isFriendHost: activity.isFriendHost,
        title: activity.title,
        description: activity.description,
        city: activity.city,
        locationDetails: activity.locationDetails,
        startTimeUtc: activity.startTimeUtc,
        endTimeUtc: activity.endTimeUtc,
        isPublic: activity.isPublic,
        createdAt: activity.createdAt,
        participantsCount: activity.participantsCount,
        isCreator: false,
      );

      setState(() {
        final exists = _myActivities.any((a) => a.id == activity.id);
        if (!exists) {
          _myActivities = [joined, ..._myActivities];
        }
        _publicAll =
            _publicAll.where((a) => a.id != activity.id).toList();
        _applyPublicFilters();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to join activity.'),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _joining = false;
    });
  }

  Future<void> _handleLeave(CommunityActivity activity) async {
    if (_leaving) return;
    setState(() {
      _leaving = true;
    });

    try {
      await _repo.leaveActivity(activity.id);
      if (!mounted) return;

      setState(() {
        _myActivities =
            _myActivities.where((a) => a.id != activity.id).toList();

        if (activity.isPublic) {
          final exists =
              _publicAll.any((a) => a.id == activity.id);
          if (!exists) {
            _publicAll = [activity, ..._publicAll];
          }
        }
        _applyPublicFilters();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to leave activity.'),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _leaving = false;
    });
  }

  Future<void> _handleDelete(CommunityActivity activity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete activity?'),
        content: Text(
          'You are about to delete "${activity.title}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repo.deleteActivityIfCreator(activity.id);
      if (!mounted) return;

      setState(() {
        _myActivities =
            _myActivities.where((a) => a.id != activity.id).toList();
        _publicAll =
            _publicAll.where((a) => a.id != activity.id).toList();
        _applyPublicFilters();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete activity.'),
        ),
      );
    }
  }

  void _openCreateActivitySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _CreateActivitySheet(
          onCreate: _handleCreateActivity,
        ),
      ),
    );
  }

  Future<void> _handleCreateActivity({
    required String title,
    required String description,
    required String city,
    required String locationDetails,
    required DateTime startTimeLocal,
    required DateTime endTimeLocal,
    required bool isPublic,
  }) async {
    try {
      final created = await _repo.createActivity(
        title: title,
        description: description.isEmpty ? null : description,
        city: city,
        locationDetails:
            locationDetails.isEmpty ? null : locationDetails,
        startTimeLocal: startTimeLocal,
        endTimeLocal: endTimeLocal,
        isPublic: isPublic,
      );

      if (!mounted) return;

      setState(() {
        _myActivities = [created, ..._myActivities];
        if (created.isPublic) {
          _publicAll = [created, ..._publicAll];
        }
        _applyPublicFilters();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create activity.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandBg = Color(0xFFEAF5F3);
    const brandBorder = Color(0xFFD8E9E6);
    const brandText = Color(0xFF1F3B3A);
    const brandMuted = Color(0xFF5D7B79);
    const brandDeep = Color(0xFF1F5F63);

    return Scaffold(
      backgroundColor: brandBg,
      appBar: AppBar(
        title: const Text('Community'),
        backgroundColor: Colors.white,
        foregroundColor: brandText,
        elevation: 0.5,
      ),
      body: Stack(
        children: [
          // decorative blobs
          Positioned(
            top: -160,
            left: -160,
            child: Opacity(
              opacity: 0.35,
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(210),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7CC2B5), Color(0xFF1F5F63)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            right: -180,
            child: Opacity(
              opacity: 0.28,
              child: Container(
                width: 460,
                height: 460,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(230),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7CC2B5), Color(0xFF1F5F63)],
                  ),
                ),
              ),
            ),
          ),
          // content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Intro card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: brandBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Join walks and challenges',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: brandText,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Discover community activities, create your own challenges, and see what your friends are up to.',
                          style: TextStyle(
                            fontSize: 13,
                            color: brandMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Your activities
                  _SectionCard(
                    title: 'Your activities',
                    loading: _loadingMy,
                    error: _errorMy,
                    child: _myActivities.isEmpty && !_loadingMy
                        ? const Text(
                            'You have no activities yet. Create or join one!',
                            style: TextStyle(
                              fontSize: 13,
                              color: brandMuted,
                            ),
                          )
                        : Column(
                            children: _myActivities
                                .map(
                                  (a) => _ActivityTile(
                                    activity: a,
                                    isMineSection: true,
                                    onJoin: null,
                                    onLeave: () => _handleLeave(a),
                                    onDelete: a.isCreator
                                        ? () => _handleDelete(a)
                                        : null,
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Public activities with filters
                  _SectionCard(
                    title: 'Public activities',
                    loading: _loadingPublic,
                    error: _errorPublic,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // filters
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  hintText: 'Filter by city',
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _cityFilter = value;
                                  });
                                  _applyPublicFilters();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                Switch(
                                  value: _friendsOnly,
                                  onChanged: (val) {
                                    setState(() {
                                      _friendsOnly = val;
                                    });
                                    _applyPublicFilters();
                                  },
                                  activeThumbColor: brandDeep,
                                ),
                                const Text(
                                  'Friends only',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: brandMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_publicFiltered.isEmpty && !_loadingPublic)
                          const Text(
                            'No public activities match your filters.',
                            style: TextStyle(
                              fontSize: 13,
                              color: brandMuted,
                            ),
                          )
                        else
                          Column(
                            children: _publicFiltered
                                .map(
                                  (a) => _ActivityTile(
                                    activity: a,
                                    isMineSection: false,
                                    onJoin: () => _handleJoin(a),
                                    onLeave: null,
                                    onDelete: null,
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateActivitySheet,
        backgroundColor: brandDeep,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ------- UI helpers -------

class _SectionCard extends StatelessWidget {
  final String title;
  final bool loading;
  final String? error;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.loading,
    required this.error,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const brandBorder = Color(0xFFD8E9E6);
    const brandText = Color(0xFF1F3B3A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: brandText,
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                error!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                ),
              ),
            )
          else
            child,
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final CommunityActivity activity;
  final bool isMineSection;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;
  final VoidCallback? onDelete;

  const _ActivityTile({
    required this.activity,
    required this.isMineSection,
    this.onJoin,
    this.onLeave,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const brandText = Color(0xFF1F3B3A);
    const brandMuted = Color(0xFF5D7B79);
    const brandBorder = Color(0xFFD8E9E6);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title + chip row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: brandText,
                  ),
                ),
              ),
              if (activity.isFriendHost && !isMineSection)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xFFE3F2FD),
                  ),
                  child: const Text(
                    'Friend host',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            activity.description ?? 'No description provided.',
            style: const TextStyle(
              fontSize: 12,
              color: brandMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${activity.city} • ${activity.scheduledForLabel}',
            style: const TextStyle(
              fontSize: 12,
              color: brandMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${activity.participantsCount} participant(s)',
            style: const TextStyle(
              fontSize: 11,
              color: brandMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isMineSection && onLeave != null)
                TextButton(
                  onPressed: onLeave,
                  child: const Text(
                    'Leave',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              if (!isMineSection && onJoin != null)
                TextButton(
                  onPressed: onJoin,
                  child: const Text('Join'),
                ),
              if (isMineSection && onDelete != null)
                TextButton(
                  onPressed: onDelete,
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// Bottom-sheet create activity form
class _CreateActivitySheet extends StatefulWidget {
  final Future<void> Function({
    required String title,
    required String description,
    required String city,
    required String locationDetails,
    required DateTime startTimeLocal,
    required DateTime endTimeLocal,
    required bool isPublic,
  }) onCreate;

  const _CreateActivitySheet({required this.onCreate});

  @override
  State<_CreateActivitySheet> createState() => _CreateActivitySheetState();
}

class _CreateActivitySheetState extends State<_CreateActivitySheet> {
  final _formKey = GlobalKey<FormState>();

  String _title = '';
  String _description = '';
  String _city = '';
  String _locationDetails = '';
  DateTime? _start;
  DateTime? _end;
  bool _isPublic = true;
  bool _submitting = false;

  bool get _canSubmit =>
      _title.trim().isNotEmpty &&
      _city.trim().isNotEmpty &&
      _start != null &&
      _end != null;

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted) return;
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (!mounted) return;
    if (time == null) return;

    setState(() {
      _start =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickEnd() async {
    final base = _start ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: base,
      lastDate: base.add(const Duration(days: 365)),
    );
    if (!mounted) return;
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base.add(const Duration(hours: 1))),
    );
    if (!mounted) return;
    if (time == null) return;

    setState(() {
      _end =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    if (_end!.isBefore(_start!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time.'),
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    await widget.onCreate(
      title: _title.trim(),
      description: _description.trim(),
      city: _city.trim(),
      locationDetails: _locationDetails.trim(),
      startTimeLocal: _start!,
      endTimeLocal: _end!,
      isPublic: _isPublic,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const brandBorder = Color(0xFFD8E9E6);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New activity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Activity title',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _title = v),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (v) => setState(() => _description = v),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _city = v),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Location details (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _locationDetails = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickStart,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: brandBorder),
                      ),
                      child: Text(
                        _start == null
                            ? 'Pick start'
                            : 'Start: ${_start!.toLocal()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickEnd,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: brandBorder),
                      ),
                      child: Text(
                        _end == null
                            ? 'Pick end'
                            : 'End: ${_end!.toLocal()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Switch(
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),
                  const Text(
                    'Public activity (visible to others)',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _canSubmit && !_submitting ? _submit : null,
                  child: Text(_submitting ? 'Creating...' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}