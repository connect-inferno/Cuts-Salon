import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/models.dart';
import 'package:mobile/firebase/salon_firestore.dart';
import 'package:mobile/widgets/birthday_picker.dart';

void main() {
  test('the erased-client name matches the one firestore.rules allows', () {
    // The rules let a bill's customerName change to exactly this text and
    // nothing else, so a mismatch would make every erase fail at the bills.
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains("return '$kErasedClientName';"));
  });

  group('consentChanges', () {
    test('ticking records when and who', () {
      final c = SalonFirestore.consentChanges(was: false, now: true, byId: 'u1', byName: 'Asha');
      expect(c['whatsappConsentAt'], isA<FieldValue>());
      expect(c['whatsappConsentBy'], 'u1');
      expect(c['whatsappConsentByName'], 'Asha');
      expect(c['whatsappOptOutAt'], isA<FieldValue>());
    });

    test('unticking records the withdrawal only', () {
      final c = SalonFirestore.consentChanges(was: true, now: false, byId: 'u1', byName: 'Asha');
      expect(c.keys, ['whatsappOptOutAt']);
    });

    test('no change, no stamps', () {
      expect(SalonFirestore.consentChanges(was: true, now: true, byId: 'u1', byName: 'Asha'), isEmpty);
      expect(SalonFirestore.consentChanges(was: false, now: false, byId: 'u1', byName: 'Asha'), isEmpty);
    });
  });

  group('WhatsAppOptInTile', () {
    Future<void> pump(WidgetTester tester, {required bool value, DateTime? at, String? by}) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WhatsAppOptInTile(value: value, onChanged: (_) {}, recordedAt: at, recordedBy: by),
            ),
          ),
        );

    testWidgets('shows when consent was recorded and by whom', (tester) async {
      await pump(tester, value: true, at: DateTime(2026, 11, 2), by: 'Asha');
      expect(find.textContaining('Agreed 2 Nov 2026 · recorded by Asha'), findsOneWidget);
    });

    testWidgets('says nothing about it once unticked', (tester) async {
      await pump(tester, value: false, at: DateTime(2026, 11, 2), by: 'Asha');
      expect(find.textContaining('Agreed'), findsNothing);
    });

    testWidgets('says nothing for a tick saved before this was kept', (tester) async {
      await pump(tester, value: true);
      expect(find.textContaining('Agreed'), findsNothing);
    });
  });
}
