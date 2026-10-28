import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/features/matches/data/match_models.dart';
import 'package:histae_app/features/notifications/data/notification_models.dart';
import 'support/auth_fixture.dart';
import 'support/matches_fixture.dart';
import 'support/notifications_fixture.dart';

void main() {
  test('archive is accessible at day ten and expires at day thirty', () {
    final now = DateTime.utc(2030, 1, 1);
    final deadline = now.add(const Duration(days: 20));
    final match = UserMatch.fromJson({
      ...publicMatchJson(status: 'confirmed'),
      'archived': true,
      'inactivity_expires_at': deadline.toIso8601String(),
    }, testUser);
    expect(match.isArchivedAt(now.subtract(const Duration(microseconds: 1))), isFalse);
    expect(match.isArchivedAt(now), isTrue);
    expect(match.historyAllowed, isTrue);
    expect(match.sendAllowed, isTrue);
    expect(match.isInactivityExpiredAt(deadline), isTrue);
    expect(match.isArchivedAt(deadline), isFalse);
  });

  test('a renewed server deadline restores an archived conversation', () {
    final now = DateTime.utc(2030, 1, 1);
    final match = UserMatch.fromJson({
      ...publicMatchJson(status: 'confirmed'),
      'archived': false,
      'inactivity_expires_at': now.add(const Duration(days: 30)).toIso8601String(),
    }, testUser);
    expect(match.isArchivedAt(now), isFalse);
    expect(match.isInactivityExpiredAt(now), isFalse);
  });

  test('inactivity notification opens only the referenced conversation', () {
    final intent = PushIntent.parse({
      'notification_id': notificationOne,
      'type': 'match_expiring',
      'match_id': testMatch,
      'message': 'Untrusted provider text',
    });
    expect(intent?.kind, PushKind.matchExpiring);
    expect(intent?.matchId, testMatch);
    expect(PushIntent.parse({'notification_id': notificationOne, 'type': 'match_expiring'}), isNull);
  });
}
