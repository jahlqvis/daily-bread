import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _repository;
  UserModel _user = UserModel();
  bool _isLoading = true;
  String? _lastXpGain;

  UserProvider(this._repository);

  UserModel get user => _user;
  bool get isLoading => _isLoading;
  String? get lastXpGain => _lastXpGain;

  Future<void> loadUser() async {
    _isLoading = true;
    notifyListeners();
    
    _user = await _repository.getUser();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markChapterAsRead(String book, int chapter) async {
    final previousXp = _user.totalXp;
    final previousLevel = _user.level;
    
    _user = await _repository.markChapterAsRead(book, chapter);
    
    final xpGained = _user.totalXp - previousXp;
    if (xpGained > 0) {
      _lastXpGain = '+$xpGained XP';
      if (_user.level > previousLevel) {
        _lastXpGain = '$_lastXpGain - Level Up!';
      }
    }
    
    notifyListeners();
    
    Future.delayed(const Duration(seconds: 3), () {
      _lastXpGain = null;
      notifyListeners();
    });
  }

  Future<void> useStreakFreeze() async {
    await _repository.useStreakFreeze();
    _user = await _repository.getUser();
    notifyListeners();
  }

  int get xpToNextLevel {
    final thresholds = [0, 100, 250, 500, 850, 1300, 1850, 2500, 3250, 4100];
    int nextLevel = _user.level + 1;
    if (nextLevel > 10) return 0;
    return thresholds[nextLevel - 1] - _user.totalXp;
  }

  double get levelProgress {
    final thresholds = [0, 100, 250, 500, 850, 1300, 1850, 2500, 3250, 4100];
    int currentThreshold = _user.level > 1 ? thresholds[_user.level - 1] : 0;
    int nextThreshold = _user.level < 10 ? thresholds[_user.level] : thresholds.last;
    
    if (nextThreshold == currentThreshold) return 1.0;
    
    return (_user.totalXp - currentThreshold) / (nextThreshold - currentThreshold);
  }
}
