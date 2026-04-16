import 'package:flutter/foundation.dart';

import '../../core/constants/reading_plans.dart';
import '../../data/datasources/local_data_source.dart';
import '../../data/models/reading_plan_model.dart';
import '../../data/models/user_model.dart';

enum ReadingPlanStatus {
  activeInProgress,
  activeCompleted,
  completed,
  paused,
  inactive,
}

class ReadingPlanProvider extends ChangeNotifier {
  final LocalDataSource _localDataSource;
  bool _isLoading = true;
  String? _activePlanId;
  DateTime? _activePlanStartedAt;
  Set<String> _completedPlanRewardIds = <String>{};

  ReadingPlanProvider(this._localDataSource);

  bool get isLoading => _isLoading;
  List<ReadingPlan> get plans => ReadingPlans.all;
  String? get activePlanId => _activePlanId;
  DateTime? get activePlanStartedAt => _activePlanStartedAt;

  bool hasClaimedCompletionReward(String planId) {
    return _completedPlanRewardIds.contains(planId);
  }

  bool hasPlan(String planId) {
    return plans.any((plan) => plan.id == planId);
  }

  ReadingPlan? get activePlan {
    if (_activePlanId == null) {
      return null;
    }

    for (final plan in plans) {
      if (plan.id == _activePlanId) {
        return plan;
      }
    }
    return null;
  }

  Future<void> loadPlanState() async {
    _isLoading = true;
    notifyListeners();
    final persistedPlanId = _localDataSource.getActivePlanId();
    if (persistedPlanId != null && !hasPlan(persistedPlanId)) {
      _activePlanId = null;
      await _localDataSource.clearActivePlanId();
      await _localDataSource.clearActivePlanStartedAt();
    } else {
      _activePlanId = persistedPlanId;
      _activePlanStartedAt = _localDataSource.getActivePlanStartedAt();
    }
    _completedPlanRewardIds = _localDataSource.getCompletedPlanRewardIds();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> activatePlan(String planId, {DateTime? startedAt}) async {
    if (!hasPlan(planId)) {
      throw ArgumentError('Unknown reading plan id: $planId');
    }

    final shouldResetStartDate =
        _activePlanId != planId || _activePlanStartedAt == null;
    _activePlanId = planId;
    if (shouldResetStartDate) {
      _activePlanStartedAt = startedAt ?? DateTime.now();
    }

    await _localDataSource.saveActivePlanId(planId);
    if (_activePlanStartedAt != null) {
      await _localDataSource.saveActivePlanStartedAt(_activePlanStartedAt!);
    }
    notifyListeners();
  }

  Future<void> clearActivePlan() async {
    _activePlanId = null;
    _activePlanStartedAt = null;
    await _localDataSource.clearActivePlanId();
    await _localDataSource.clearActivePlanStartedAt();
    notifyListeners();
  }

  ReadingPlanStatus planStatusFor(UserModel user, ReadingPlan plan) {
    final completed = completedCountForPlan(user, plan) >= plan.totalDays;
    final isActive = _activePlanId == plan.id;
    final hasProgress = completedCountForPlan(user, plan) > 0;

    if (isActive && completed) {
      return ReadingPlanStatus.activeCompleted;
    }
    if (isActive) {
      return ReadingPlanStatus.activeInProgress;
    }
    if (completed) {
      return ReadingPlanStatus.completed;
    }
    if (hasProgress) {
      return ReadingPlanStatus.paused;
    }
    return ReadingPlanStatus.inactive;
  }

  ReadingPlanStatus activePlanStatus(UserModel user) {
    final plan = activePlan;
    if (plan == null) {
      return ReadingPlanStatus.inactive;
    }
    return planStatusFor(user, plan);
  }

  bool isChapterInActivePlan(String book, int chapter) {
    final plan = activePlan;
    if (plan == null) {
      return false;
    }

    return plan.chapters.any(
      (reference) => reference.book == book && reference.chapter == chapter,
    );
  }

  int completedCount(UserModel user) {
    final plan = activePlan;
    if (plan == null) {
      return 0;
    }

    return completedCountForPlan(user, plan);
  }

  int completedCountForPlan(UserModel user, ReadingPlan plan) {
    return plan.chapters.where((reference) {
      return user.readingProgress[reference.book]?.contains(
            reference.chapter,
          ) ??
          false;
    }).length;
  }

  double progress(UserModel user) {
    final plan = activePlan;
    if (plan == null || plan.totalDays == 0) {
      return 0;
    }
    return completedCount(user) / plan.totalDays;
  }

  bool isCompleted(UserModel user) {
    final plan = activePlan;
    if (plan == null) {
      return false;
    }
    return completedCount(user) >= plan.totalDays;
  }

  Future<bool> claimCompletionRewardIfNeeded(UserModel user) async {
    final plan = activePlan;
    if (plan == null || !isCompleted(user)) {
      return false;
    }
    if (_completedPlanRewardIds.contains(plan.id)) {
      return false;
    }

    _completedPlanRewardIds = {..._completedPlanRewardIds, plan.id};
    await _localDataSource.saveCompletedPlanRewardIds(_completedPlanRewardIds);
    notifyListeners();
    return true;
  }

  ReadingReference? nextChapter(UserModel user) {
    final plan = activePlan;
    if (plan == null) {
      return null;
    }

    for (final reference in plan.chapters) {
      final isRead =
          user.readingProgress[reference.book]?.contains(reference.chapter) ??
          false;
      if (!isRead) {
        return reference;
      }
    }
    return null;
  }

  ReadingReference? resumeReference(UserModel user, DateTime now) {
    final plan = activePlan;
    if (plan == null || isCompleted(user) || plan.chapters.isEmpty) {
      return null;
    }

    final startedAt = _activePlanStartedAt;
    if (startedAt != null) {
      final nowDate = DateTime(now.year, now.month, now.day);
      final startDate = DateTime(
        startedAt.year,
        startedAt.month,
        startedAt.day,
      );
      final elapsedDays = nowDate.difference(startDate).inDays;
      final targetIndex = elapsedDays.clamp(0, plan.chapters.length - 1);
      final todaysReference = plan.chapters[targetIndex];
      final todaysRead =
          user.readingProgress[todaysReference.book]?.contains(
            todaysReference.chapter,
          ) ??
          false;
      if (!todaysRead) {
        return todaysReference;
      }
    }

    return nextChapter(user);
  }
}
