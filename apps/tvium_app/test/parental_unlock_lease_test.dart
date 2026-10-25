import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/parental/parental_unlock_lease.dart';

void main() {
  test(
    'parental unlock expires after 15 minutes and never crosses profiles',
    () {
      var now = DateTime.utc(2026, 1, 1);
      final lease = ParentalUnlockLease(clock: () => now);
      lease.unlock('profile-a');

      expect(lease.isUnlocked('profile-a'), isTrue);
      expect(lease.isUnlocked('profile-b'), isFalse);
      now = now.add(const Duration(minutes: 14));
      expect(lease.isUnlocked('profile-a'), isTrue);
      now = now.add(const Duration(minutes: 1));
      expect(lease.isUnlocked('profile-a'), isFalse);
    },
  );

  test('parental unlock clears when the app leaves the foreground', () {
    final lease = ParentalUnlockLease(clock: () => DateTime.utc(2026));
    lease.unlock('profile-a');
    lease.clear();

    expect(lease.isUnlocked('profile-a'), isFalse);
  });

  test('device clock rollback cannot extend an unlocked session', () {
    var now = DateTime.utc(2026, 1, 1, 12);
    final lease = ParentalUnlockLease(clock: () => now);
    lease.unlock('profile-a');
    now = now.subtract(const Duration(minutes: 1));

    expect(lease.isUnlocked('profile-a'), isFalse);
  });
}
