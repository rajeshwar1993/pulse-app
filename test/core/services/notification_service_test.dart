import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_app/core/services/notification_service.dart';

import 'pulse_service_test.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseMessaging>(),
  MockSpec<NotificationSettings>(),
])
import 'notification_service_test.mocks.dart';

// Re-use mocks from pulse_service_test
import 'pulse_service_test.mocks.dart'
    show MockSupabaseClient, MockGoTrueClient, MockUser;

void main() {
  late NotificationService service;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockFirebaseMessaging mockMessaging;
  late MockNotificationSettings mockSettings;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockMessaging = MockFirebaseMessaging();
    mockSettings = MockNotificationSettings();

    when(mockSupabase.auth).thenReturn(mockAuth);
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('test-user-id');

    // Default messaging stubs
    when(mockMessaging.setForegroundNotificationPresentationOptions(
      alert: anyNamed('alert'),
      badge: anyNamed('badge'),
      sound: anyNamed('sound'),
    )).thenAnswer((_) async {});

    when(mockMessaging.onTokenRefresh).thenAnswer(
      (_) => const Stream<String>.empty(),
    );

    service = NotificationService(mockSupabase, prefs, mockMessaging);
  });

  group('hasRequestedPermission', () {
    test('returns false before permission is requested', () {
      expect(service.hasRequestedPermission, isFalse);
    });

    test('returns true after permission is requested', () async {
      when(mockSettings.authorizationStatus)
          .thenReturn(AuthorizationStatus.authorized);
      when(mockMessaging.requestPermission(
        alert: anyNamed('alert'),
        badge: anyNamed('badge'),
        sound: anyNamed('sound'),
        announcement: anyNamed('announcement'),
        carPlay: anyNamed('carPlay'),
        criticalAlert: anyNamed('criticalAlert'),
        provisional: anyNamed('provisional'),
      )).thenAnswer((_) async => mockSettings);

      await service.requestPermission();
      expect(service.hasRequestedPermission, isTrue);
    });
  });

  group('requestPermission', () {
    test('returns true when permission is granted', () async {
      when(mockSettings.authorizationStatus)
          .thenReturn(AuthorizationStatus.authorized);
      when(mockMessaging.requestPermission(
        alert: anyNamed('alert'),
        badge: anyNamed('badge'),
        sound: anyNamed('sound'),
        announcement: anyNamed('announcement'),
        carPlay: anyNamed('carPlay'),
        criticalAlert: anyNamed('criticalAlert'),
        provisional: anyNamed('provisional'),
      )).thenAnswer((_) async => mockSettings);

      final result = await service.requestPermission();
      expect(result, isTrue);
    });

    test('returns true when permission is provisional', () async {
      when(mockSettings.authorizationStatus)
          .thenReturn(AuthorizationStatus.provisional);
      when(mockMessaging.requestPermission(
        alert: anyNamed('alert'),
        badge: anyNamed('badge'),
        sound: anyNamed('sound'),
        announcement: anyNamed('announcement'),
        carPlay: anyNamed('carPlay'),
        criticalAlert: anyNamed('criticalAlert'),
        provisional: anyNamed('provisional'),
      )).thenAnswer((_) async => mockSettings);

      final result = await service.requestPermission();
      expect(result, isTrue);
    });

    test('returns false when permission is denied', () async {
      when(mockSettings.authorizationStatus)
          .thenReturn(AuthorizationStatus.denied);
      when(mockMessaging.requestPermission(
        alert: anyNamed('alert'),
        badge: anyNamed('badge'),
        sound: anyNamed('sound'),
        announcement: anyNamed('announcement'),
        carPlay: anyNamed('carPlay'),
        criticalAlert: anyNamed('criticalAlert'),
        provisional: anyNamed('provisional'),
      )).thenAnswer((_) async => mockSettings);

      final result = await service.requestPermission();
      expect(result, isFalse);
    });
  });

  group('registerToken', () {
    test('returns false when no auth user', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final result = await service.registerToken();
      expect(result, isFalse);
    });

    test('returns false when token is null', () async {
      when(mockMessaging.getToken()).thenAnswer((_) async => null);

      final result = await service.registerToken();
      expect(result, isFalse);
    });

    test('skips DB call when token is unchanged', () async {
      // Pre-cache a token
      await prefs.setString('fcm_cached_token', 'existing-token');

      when(mockMessaging.getToken())
          .thenAnswer((_) async => 'existing-token');

      final result = await service.registerToken();
      expect(result, isTrue);
      // No Supabase call should have been made
      verifyNever(mockSupabase.from(any));
    });

    test('upserts to DB when token is new', () async {
      when(mockMessaging.getToken())
          .thenAnswer((_) async => 'new-fcm-token');

      final fakeBuilder = FakeQueryBuilder();
      when(mockSupabase.from('fcm_tokens'))
          .thenAnswer((_) => fakeBuilder);

      final result = await service.registerToken();
      expect(result, isTrue);
      expect(prefs.getString('fcm_cached_token'), equals('new-fcm-token'));
    });

    test('upserts to DB when token changed', () async {
      await prefs.setString('fcm_cached_token', 'old-token');

      when(mockMessaging.getToken())
          .thenAnswer((_) async => 'new-fcm-token');

      final fakeBuilder = FakeQueryBuilder();
      when(mockSupabase.from('fcm_tokens'))
          .thenAnswer((_) => fakeBuilder);

      final result = await service.registerToken();
      expect(result, isTrue);
      expect(prefs.getString('fcm_cached_token'), equals('new-fcm-token'));
    });
  });

  group('unregisterToken', () {
    test('returns true when no cached token (nothing to delete)', () async {
      final result = await service.unregisterToken();
      expect(result, isTrue);
    });

    test('deletes token from DB and clears cache', () async {
      await prefs.setString('fcm_cached_token', 'token-to-delete');

      final fakeBuilder = FakeQueryBuilder();
      when(mockSupabase.from('fcm_tokens'))
          .thenAnswer((_) => fakeBuilder);

      final result = await service.unregisterToken();
      expect(result, isTrue);
      expect(prefs.getString('fcm_cached_token'), isNull);
    });
  });
}
