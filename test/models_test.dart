import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom/models/building_model.dart';
import 'package:kingdom/models/bulletin_model.dart';
import 'package:kingdom/models/notification_model.dart';
import 'package:kingdom/models/user_model.dart';
import 'package:kingdom/services/api_client.dart';
import 'package:kingdom/utils/achievement_timeline.dart';

void main() {
  group('UserModel', () {
    test('loads legacy profiles that still carry a role', () {
      final user = UserModel.fromMap('u', {
        'name': 'Legacy',
        'role': 'gardener',
        'fishBalance': 12,
        'avatarConfig': {'hairStyle': 'short_classic'},
      });
      expect(user.name, 'Legacy');
      expect(user.fishBalance, 12);
      expect(user.toMap().containsKey('role'), isFalse);
    });
  });

  group('BulletinPost reactions', () {
    test('toggle replaces, clears and never touches other members', () {
      const others = {'bob': '🙏'};
      final added = BulletinPost.toggledReactions(others, 'alice', '🙌');
      expect(added, {'bob': '🙏', 'alice': '🙌'});
      final replaced = BulletinPost.toggledReactions(added, 'alice', '❤️');
      expect(replaced, {'bob': '🙏', 'alice': '❤️'});
      final cleared = BulletinPost.toggledReactions(replaced, 'alice', '❤️');
      expect(cleared, others);
    });

    test('parses legacy posts with authorRole', () {
      final post = BulletinPost.fromMap('p', {
        'userId': 'u',
        'authorName': 'A',
        'authorRole': 'gardener',
        'type': 'thanksgiving',
        'text': 'hi',
      });
      expect(post.type, BulletinType.thanksgiving);
      expect(post.isEdited, isFalse);
    });
  });

  group('AppNotification', () {
    test('parses target and read state', () {
      final n = AppNotification.fromMap('n', {
        'type': 'achievement_unlocked',
        'text': 'Unlocked',
        'target': 'achievements',
        'readAt': null,
      });
      expect(n.target, NotificationTarget.achievements);
      expect(n.isRead, isFalse);
      expect(n.emoji, '🏆');
      expect(
        AppNotification.fromMap('m', {'target': 'bogus'}).target,
        NotificationTarget.guild,
      );
    });
  });

  group('achievement timeline', () {
    test(
      'orders unlocks chronologically, then locked milestones with progress',
      () {
        final timeline = buildAchievementTimeline([
          AchievementUnlock(
            achievementId: 'playground',
            unlockedAt: DateTime.utc(2026, 9, 2),
            fundBalance: 55,
          ),
          AchievementUnlock(
            achievementId: 'first_fish',
            unlockedAt: DateTime.utc(2026, 9, 1),
            fundBalance: 12,
          ),
          const AchievementUnlock(
            achievementId: 'founded',
            fundBalance: 0,
            backfilled: true,
          ),
        ], 75);

        expect(timeline.map((e) => e.definition.id).toList(), [
          'founded',
          'first_fish',
          'playground',
          'fountain',
          'sanctuary',
          'citadel',
        ]);
        expect(timeline.take(3).every((e) => e.isUnlocked), isTrue);
        expect(timeline[3].progress, closeTo(0.75, 1e-9));
        expect(timeline[5].progress, closeTo(0.15, 1e-9));
      },
    );
  });

  group('API errors', () {
    test('maps stable codes to user-facing messages', () {
      expect(
        () =>
            decodeApiResponse(400, '{"code":"INSUFFICIENT_FUNDS","error":"x"}'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'INSUFFICIENT_FUNDS')
              .having(
                (e) => e.message,
                'message',
                'You do not have enough fish for that.',
              ),
        ),
      );
    });

    test('falls back to the server message, then a generic one', () {
      expect(
        () =>
            decodeApiResponse(418, '{"code":"NEW_CODE","error":"Server says"}'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Server says',
          ),
        ),
      );
      expect(
        () => decodeApiResponse(502, '<html>Bad gateway</html>'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'HTTP_502')
              .having(
                (e) => e.message,
                'message',
                'Something went wrong. Please try again.',
              ),
        ),
      );
    });

    test('returns the body for successful responses', () {
      expect(
        decodeApiResponse(200, '{"success":true,"newBalance":3}')['newBalance'],
        3,
      );
    });
  });
}
