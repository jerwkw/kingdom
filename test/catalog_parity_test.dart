import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom/config/achievements_config.dart';
import 'package:kingdom/config/store_config.dart';

// The Functions catalogs are authoritative; the Flutter display catalogs must
// list exactly the same ids with the same prices/thresholds.
void main() {
  test('store catalog matches functions/lib/store-catalog.json', () {
    final server =
        jsonDecode(
              File('functions/lib/store-catalog.json').readAsStringSync(),
            )['items']
            as Map<String, dynamic>;
    final client = {for (final item in StoreConfig.catalog) item.id: item};

    expect(client.keys.toSet(), server.keys.toSet());
    server.forEach((id, value) {
      expect(client[id]!.cost, value['cost'], reason: '$id cost');
      expect(
        client[id]!.category.name,
        value['category'],
        reason: '$id category',
      );
    });
  });

  test('achievements match functions/lib/achievements.json', () {
    final server =
        (jsonDecode(
                  File('functions/lib/achievements.json').readAsStringSync(),
                )['achievements']
                as List)
            .cast<Map<String, dynamic>>();
    expect(
      AchievementsConfig.all.map((a) => (a.id, a.threshold)).toList(),
      server.map((a) => (a['id'], a['threshold'])).toList(),
    );
  });
}
