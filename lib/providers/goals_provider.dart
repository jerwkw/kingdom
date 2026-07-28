import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/goal_model.dart';
import 'auth_provider.dart';

final userGoalsProvider = StreamProvider<List<GoalModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  final firestore = ref.watch(firestoreInstanceProvider);
  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Listen to private completions to mark goals completed today
  final completionsStream = firestore
      .collection('completions')
      .where('userId', isEqualTo: user.uid)
      .where('date', isEqualTo: todayStr)
      .snapshots();

  final goalsStream = firestore
      .collection('goals')
      .where('userId', isEqualTo: user.uid)
      .snapshots();

  return goalsStream.asyncMap((goalsSnap) async {
    final completionsSnap = await completionsStream.first;
    final completedGoalIds = completionsSnap.docs
        .where((d) => d.data()['refType'] == 'goal')
        .map((d) => d.data()['refId'].toString())
        .toSet();

    return goalsSnap.docs.map((doc) {
      final isCompleted = completedGoalIds.contains(doc.id);
      return GoalModel.fromMap(doc.id, doc.data(), isCompletedToday: isCompleted);
    }).toList();
  });
});

final todayDailyChallengeProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final firestore = ref.watch(firestoreInstanceProvider);
  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

  return firestore.collection('dailyChallenges').doc(todayStr).snapshots().map((doc) {
    if (!doc.exists) return null;
    return doc.data();
  });
});

final isChallengeCompletedTodayProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(false);

  final firestore = ref.watch(firestoreInstanceProvider);
  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final completionId = '${user.uid}_challenge_$todayStr';
  return firestore.collection('completions').doc(completionId).snapshots().map((doc) => doc.exists);
});

class GoalsNotifier extends StateNotifier<AsyncValue<String?>> {
  final Ref _ref;
  GoalsNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addTemplatedGoal({
    required String task,
    required String frequency,
  }) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;

    final firestore = _ref.read(firestoreInstanceProvider);
    await firestore.collection('goals').add({
      'userId': user.uid,
      'type': 'templated',
      'task': task,
      'text': '',
      'frequency': frequency,
      'currentStreak': 0,
      'sharedToBulletin': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addSmartGoal({required String goalText}) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;

    final firestore = _ref.read(firestoreInstanceProvider);
    await firestore.collection('goals').add({
      'userId': user.uid,
      'type': 'smart',
      'task': 'SMART Goal',
      'text': goalText.trim(),
      'frequency': 'daily',
      'currentStreak': 0,
      'sharedToBulletin': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> completeGoal(String goalId) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return 'Not authenticated';

    state = const AsyncValue.loading();
    try {
      final token = await user.getIdToken();
      final baseUrl = _ref.read(piServerBaseUrlProvider);

      final response = await http.post(
        Uri.parse('$baseUrl/completeGoal'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'goalId': goalId}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        state = const AsyncValue.data(null);
        return data['message'] ?? 'Goal Completed!';
      } else {
        final errorMsg = data['error'] ?? 'Failed to complete goal';
        state = AsyncValue.error(errorMsg, StackTrace.current);
        return errorMsg;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 'Connection error. Please check server URL.';
    }
  }

  Future<String?> completeDailyChallenge() async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return 'Not authenticated';

    state = const AsyncValue.loading();
    try {
      final token = await user.getIdToken();
      final baseUrl = _ref.read(piServerBaseUrlProvider);

      final response = await http.post(
        Uri.parse('$baseUrl/completeDailyChallenge'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        state = const AsyncValue.data(null);
        return data['message'] ?? 'Challenge Completed!';
      } else {
        final errorMsg = data['error'] ?? 'Failed to complete challenge';
        state = AsyncValue.error(errorMsg, StackTrace.current);
        return errorMsg;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 'Connection error. Please check server URL.';
    }
  }
}

final goalsNotifierProvider = StateNotifierProvider<GoalsNotifier, AsyncValue<String?>>((ref) {
  return GoalsNotifier(ref);
});
