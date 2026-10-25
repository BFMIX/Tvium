final class ParentalUnlockLease {
  ParentalUnlockLease({required this.clock});

  static const duration = Duration(minutes: 15);
  final DateTime Function() clock;
  String? _profileId;
  DateTime? _unlockedAt;

  void unlock(String profileId) {
    _profileId = profileId;
    _unlockedAt = clock();
  }

  bool isUnlocked(String profileId) {
    final unlockedAt = _unlockedAt;
    if (_profileId != profileId || unlockedAt == null) return false;
    final elapsed = clock().difference(unlockedAt);
    if (elapsed.isNegative || elapsed >= duration) {
      clear();
      return false;
    }
    return true;
  }

  void clear() {
    _profileId = null;
    _unlockedAt = null;
  }
}
