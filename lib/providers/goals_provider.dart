import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bulletin_model.dart';
import '../models/goal_model.dart';
import '../services/api_client.dart';
import '../utils/period_keys.dart';
import 'auth_provider.dart';
import 'building_provider.dart';
import 'bulletin_provider.dart';

typedef GoalDoc = ({String id, Map<String, dynamic> data});

final _goalDocsProvider = StreamProvider<List<GoalDoc>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref
      .watch(firestoreInstanceProvider)
      .collection('goals')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) (id: d.id, data: d.data())]);
});

// Completion documents are server-controlled; the client only reads its own.
final _completionDocsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref
      .watch(firestoreInstanceProvider)
      .collection('completions')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) d.data()]);
});

/// Builds goal models, marking each completed when a completion record (or a
/// server-confirmed completion not yet visible in the stream) matches its
/// current period key.
List<GoalModel> mergeGoalsWithCompletions(
  List<GoalDoc> goals,
  List<Map<String, dynamic>> completions,
  DateTime now, {
  Map<String, String> confirmedPeriods = const {},
}) {
  final completedKeys = <String>{
    for (final c in completions)
      if (c['refType'] == 'goal')
        '${c['refId']}|${c['periodKey'] ?? c['date']}',
  };
  return [
    for (final goal in goals)
      () {
        final model = GoalModel.fromMap(goal.id, goal.data);
        final key = periodKey(model.frequency, now);
        final done =
            completedKeys.contains('${goal.id}|$key') ||
            confirmedPeriods[goal.id] == key;
        return model.copyWith(isCompletedToday: done);
      }(),
  ];
}

/// All of the user's goals (active and archived) with current-period
/// completion state. Combines two independent streams, so neither
/// resubscribes when the other emits.
final userGoalsProvider = Provider<AsyncValue<List<GoalModel>>>((ref) {
  final goals = ref.watch(_goalDocsProvider);
  final completions = ref.watch(_completionDocsProvider);
  final confirmed = ref.watch(goalCompletionStatusProvider).confirmedPeriods;

  if (goals.hasError) return AsyncValue.error(goals.error!, goals.stackTrace!);
  if (completions.hasError) {
    return AsyncValue.error(completions.error!, completions.stackTrace!);
  }
  if (!goals.hasValue || !completions.hasValue) {
    return const AsyncValue.loading();
  }
  return AsyncValue.data(
    mergeGoalsWithCompletions(
      goals.value!,
      completions.value!,
      DateTime.now(),
      confirmedPeriods: confirmed,
    ),
  );
});

// ---------------------------------------------------------------------------
// Per-goal completion requests
// ---------------------------------------------------------------------------

enum GoalRequestPhase { pending, failed }

class GoalCompletionStatus {
  /// Goals with an in-flight or failed completion request.
  final Map<String, ({GoalRequestPhase phase, String? error})> requests;

  /// goalId -> period key the server confirmed as completed.
  final Map<String, String> confirmedPeriods;

  const GoalCompletionStatus({
    this.requests = const {},
    this.confirmedPeriods = const {},
  });

  bool isPending(String goalId) =>
      requests[goalId]?.phase == GoalRequestPhase.pending;

  String? errorFor(String goalId) =>
      requests[goalId]?.phase == GoalRequestPhase.failed
      ? requests[goalId]?.error
      : null;
}

class GoalCompletionController extends StateNotifier<GoalCompletionStatus> {
  final Ref _ref;
  GoalCompletionController(this._ref) : super(const GoalCompletionStatus());

  void _setRequest(String goalId, GoalRequestPhase? phase, [String? error]) {
    final requests = Map.of(state.requests);
    if (phase == null) {
      requests.remove(goalId);
    } else {
      requests[goalId] = (phase: phase, error: error);
    }
    state = GoalCompletionStatus(
      requests: requests,
      confirmedPeriods: state.confirmedPeriods,
    );
  }

  /// Requests the reward. Duplicate taps while pending are ignored. On
  /// success, waits (bounded) for the completion record to arrive so the
  /// checkbox and stream agree before reporting success. Returns a message
  /// for the user.
  Future<String?> completeGoal(String goalId) async {
    if (state.isPending(goalId)) return null;
    _setRequest(goalId, GoalRequestPhase.pending);

    final Map<String, dynamic> data;
    try {
      data = await _ref.read(apiClientProvider).post('completeGoal', {
        'goalId': goalId,
      });
    } on ApiException catch (e) {
      // Already done this period: the completion stream will show it checked.
      _setRequest(
        goalId,
        e.code == 'ALREADY_COMPLETED' ? null : GoalRequestPhase.failed,
        e.message,
      );
      return e.message;
    }

    final completionId = data['completionId'] as String?;
    if (completionId != null) {
      try {
        await _ref
            .read(firestoreInstanceProvider)
            .collection('completions')
            .doc(completionId)
            .snapshots()
            .firstWhere((doc) => doc.exists)
            .timeout(const Duration(seconds: 8));
      } on TimeoutException {
        // The server confirmed the completion; trust it until the stream
        // catches up.
      }
    }

    final period = data['periodKey'] as String?;
    state = GoalCompletionStatus(
      requests: Map.of(state.requests)..remove(goalId),
      confirmedPeriods: {...state.confirmedPeriods, goalId: ?period},
    );
    _ref.invalidate(buildingMemberStatsProvider);
    return data['message'] as String? ?? 'Goal completed! (+10 🐟)';
  }

  void clearError(String goalId) => _setRequest(goalId, null);
}

final goalCompletionStatusProvider =
    StateNotifierProvider<GoalCompletionController, GoalCompletionStatus>(
      (ref) => GoalCompletionController(ref),
    );

// ---------------------------------------------------------------------------
// Daily reflection
// ---------------------------------------------------------------------------

final todayDailyChallengeProvider = StreamProvider<Map<String, dynamic>?>((
  ref,
) {
  final firestore = ref.watch(firestoreInstanceProvider);
  return firestore
      .collection('dailyChallenges')
      .doc(todayKeyUtc())
      .snapshots()
      .map((doc) => doc.exists ? doc.data() : null);
});

final isChallengeCompletedTodayProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(false);

  final completionId = '${user.uid}_challenge_${todayKeyUtc()}';
  return ref
      .watch(firestoreInstanceProvider)
      .collection('completions')
      .doc(completionId)
      .snapshots()
      .map((doc) => doc.exists);
});

// ---------------------------------------------------------------------------
// Goal management
// ---------------------------------------------------------------------------

class GoalsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  GoalsNotifier(this._ref) : super(const AsyncValue.data(null));

  CollectionReference<Map<String, dynamic>> get _goals =>
      _ref.read(firestoreInstanceProvider).collection('goals');

  Future<void> addTemplatedGoal({
    required String task,
    required String frequency,
  }) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;
    await _goals.add({
      'userId': user.uid,
      'type': 'templated',
      'task': task,
      'text': '',
      'frequency': frequency,
      'currentStreak': 0,
      'sharedToBulletin': false,
      'archived': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addSmartGoal({
    required String goalText,
    String frequency = 'daily',
  }) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;
    await _goals.add({
      'userId': user.uid,
      'type': 'smart',
      'task': 'SMART Goal',
      'text': goalText.trim(),
      'frequency': frequency,
      'currentStreak': 0,
      'sharedToBulletin': false,
      'archived': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateGoal(
    String goalId, {
    String? task,
    String? text,
    GoalFrequency? frequency,
  }) async {
    await _goals.doc(goalId).update({
      'task': ?task,
      if (text != null) 'text': text.trim(),
      if (frequency != null) 'frequency': frequency.name,
    });
  }

  Future<void> setArchived(String goalId, bool archived) =>
      _goals.doc(goalId).update({'archived': archived});

  Future<void> deleteGoal(String goalId) => _goals.doc(goalId).delete();

  /// Posts a reviewed copy of the goal text to the bulletin. The private goal
  /// document itself is never exposed to other members.
  Future<String?> shareToBulletin(GoalModel goal, String sharedText) async {
    final error = await _ref
        .read(bulletinNotifierProvider.notifier)
        .createPost(type: BulletinType.sharing, text: sharedText);
    if (error != null) return error;
    await _goals.doc(goal.id).update({'sharedToBulletin': true});
    return null;
  }

  Future<String?> completeDailyChallenge() async {
    try {
      final data = await _ref
          .read(apiClientProvider)
          .post('completeDailyChallenge');
      return data['message'] as String? ?? 'Reflection completed! (+10 🐟)';
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Asks the server to publish today's reflection if the scheduled job has
  /// not yet run.
  Future<String?> ensureDailyChallenge() async {
    try {
      await _ref.read(apiClientProvider).post('ensureDailyChallenge');
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}

final goalsNotifierProvider =
    StateNotifierProvider<GoalsNotifier, AsyncValue<void>>((ref) {
      return GoalsNotifier(ref);
    });
