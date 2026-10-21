import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom/models/building_model.dart';
import 'package:kingdom/models/user_model.dart';
import 'package:kingdom/providers/auth_provider.dart';
import 'package:kingdom/providers/building_provider.dart';
import 'package:kingdom/providers/notifications_provider.dart';
import 'package:kingdom/screens/neighbourhood_tab.dart';

Future<void> _pumpTab(
  WidgetTester tester, {
  required double width,
  required int fish,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final user = UserModel(
    uid: 'me',
    name: 'Me',
    buildingId: 'home',
    fishBalance: fish,
    avatarConfig: const {},
  );
  final building = BuildingModel(
    id: 'home',
    name: 'A Rather Long Neighbourhood Guild Name',
    inviteCode: 'HOME2026',
    leaderUid: 'me',
    adminUids: const ['me'],
    memberIds: const ['me'],
    groupFund: 42,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith((ref) => Stream.value(user)),
        currentBuildingDocProvider.overrideWith(
          (ref) => Stream.value(building),
        ),
        buildingMemberStatsProvider.overrideWith((ref) async => const []),
        notificationsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: NeighbourhoodTab()),
    ),
  );
  await tester.pumpAndSettle();
}

ButtonStyleButton _depositButton(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.textContaining('Deposit Fish'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );

void main() {
  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets(
      'deposit action is visible with balance at ${width.toInt()}px',
      (tester) async {
        await _pumpTab(tester, width: width, fish: 12);
        expect(tester.takeException(), isNull); // no overflow
        expect(find.text('Deposit Fish · 12 🐟'), findsOneWidget);
        expect(_depositButton(tester).onPressed, isNotNull);

        await tester.tap(find.text('Deposit Fish · 12 🐟'));
        await tester.pumpAndSettle();
        expect(find.text('Your Balance: 12 Fish'), findsOneWidget);
      },
    );
  }

  testWidgets('zero balance disables deposit and explains how to earn fish', (
    tester,
  ) async {
    await _pumpTab(tester, width: 390, fish: 0);
    expect(_depositButton(tester).onPressed, isNull);
    expect(find.textContaining('No fish to deposit yet'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Tooltip &&
            (w.message ?? '').contains('Complete goals and daily reflections'),
      ),
      findsOneWidget,
    );
  });
}
