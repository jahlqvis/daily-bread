import 'package:flutter/foundation.dart';

import '../../core/constants/reading_plans.dart';
import '../../data/datasources/local_data_source.dart';
import '../../data/models/reading_plan_model.dart';
import '../../data/models/user_model.dart';

class ReadingPlanProvider extends ChangeNotifier {
  final LocalDataSource _localDataSource;
  bool _isLoading = true;
  String? _activePlanId;

  ReadingPlanProvider(this._localDataSource);

  bool get isLoading => _isLoading;
  List<ReadingPlan> get plans => ReadingPlans.all;
  String? get activePlanId => _activePlanId;

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
    } else {
      _activePlanId = persistedPlanId;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> activatePlan(String planId) async {
    if (!hasPlan(planId)) {
      throw ArgumentError('Unknown reading plan id: $planId');
    }
    _activePlanId = planId;
    await _localDataSource.saveActivePlanId(planId);
    notifyListeners();
  }

  Future<void> clearActivePlan() async {
    _activePlanId = null;
    await _localDataSource.clearActivePlanId();
    notifyListeners();
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
}
