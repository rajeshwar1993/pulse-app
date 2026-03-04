import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pulse_app/core/services/pulse_service.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
])
import 'pulse_service_test.mocks.dart';

/// Fake SupabaseQueryBuilder that returns [FakeFilterBuilder] for all methods.
/// Tracks insert() and update() calls for verification.
class FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final dynamic _awaitResult;
  bool insertCalled = false;
  bool updateCalled = false;
  Map<String, dynamic>? lastInsertData;
  Map<String, dynamic>? lastUpdateData;

  FakeQueryBuilder([this._awaitResult]);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #insert) {
      insertCalled = true;
      if (invocation.positionalArguments.isNotEmpty) {
        final arg = invocation.positionalArguments[0];
        lastInsertData = arg is Map ? Map<String, dynamic>.from(arg) : null;
      }
    }
    if (invocation.memberName == #update) {
      updateCalled = true;
      if (invocation.positionalArguments.isNotEmpty) {
        final arg = invocation.positionalArguments[0];
        lastUpdateData = arg is Map ? Map<String, dynamic>.from(arg) : null;
      }
    }
    // Return a filter builder for all chain methods (select, insert, update, etc.)
    return FakeFilterBuilder(_awaitResult);
  }
}

/// Fake PostgrestFilterBuilder that returns self for filter methods (eq, gte, limit)
/// and handles await via then(). Supports maybeSingle() and single().
class FakeFilterBuilder extends Fake
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  final dynamic _awaitResult;

  FakeFilterBuilder([this._awaitResult]);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // count() returns a ResponsePostgrestBuilder — use a separate fake
    if (invocation.memberName == #count) {
      return FakeResponseBuilder(_awaitResult);
    }
    // maybeSingle() — returns a builder that resolves to the configured result
    if (invocation.memberName == #maybeSingle) {
      return FakeMaybeSingleBuilder(_awaitResult);
    }
    // single() — returns a builder that resolves to the configured result
    if (invocation.memberName == #single) {
      return FakeSingleBuilder(_awaitResult);
    }
    // then() — for direct await (e.g., after insert without select, or after update)
    if (invocation.memberName == #then) {
      final onValue = invocation.positionalArguments[0] as Function;
      return Future<dynamic>.value(
              _awaitResult ?? <Map<String, dynamic>>[])
          .then((v) => onValue(v));
    }
    // eq, gte, limit, select, etc. return self to continue the chain
    return this;
  }
}

/// Fake for the builder returned by count().
class FakeResponseBuilder extends Fake
    implements
        ResponsePostgrestBuilder<
            PostgrestResponse<List<Map<String, dynamic>>>,
            List<Map<String, dynamic>>,
            List<Map<String, dynamic>>> {
  final dynamic _awaitResult;

  FakeResponseBuilder([this._awaitResult]);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #then) {
      final onValue = invocation.positionalArguments[0] as Function;
      return Future<dynamic>.value(_awaitResult).then((v) => onValue(v));
    }
    return this;
  }
}

/// Fake for maybeSingle() — resolves to a single map or null when awaited.
class FakeMaybeSingleBuilder extends Fake
    implements PostgrestTransformBuilder<Map<String, dynamic>?> {
  final dynamic _awaitResult;

  FakeMaybeSingleBuilder([this._awaitResult]);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #then) {
      final onValue = invocation.positionalArguments[0] as Function;
      return Future<dynamic>.value(_awaitResult).then((v) => onValue(v));
    }
    return this;
  }
}

/// Fake for single() — resolves to a single map when awaited.
class FakeSingleBuilder extends Fake
    implements PostgrestTransformBuilder<Map<String, dynamic>> {
  final dynamic _awaitResult;

  FakeSingleBuilder([this._awaitResult]);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #then) {
      final onValue = invocation.positionalArguments[0] as Function;
      return Future<dynamic>.value(_awaitResult).then((v) => onValue(v));
    }
    // select, eq, etc. return self to continue the chain
    return this;
  }
}

void main() {
  late PulseService pulseService;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    when(mockSupabase.auth).thenReturn(mockAuth);
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('test-user-id');

    pulseService = PulseService(mockSupabase, prefs);
  });

  group('isCacheFresh', () {
    test('returns false when no cache exists', () {
      expect(pulseService.isCacheFresh(), isFalse);
    });

    test('returns true when cache is within 30 minutes', () {
      prefs.setInt('pulse_last_timestamp',
          DateTime.now().millisecondsSinceEpoch);
      expect(pulseService.isCacheFresh(), isTrue);
    });

    test('returns false when cache is older than 30 minutes', () {
      final oldTimestamp = DateTime.now()
          .subtract(const Duration(minutes: 31))
          .millisecondsSinceEpoch;
      prefs.setInt('pulse_last_timestamp', oldTimestamp);
      expect(pulseService.isCacheFresh(), isFalse);
    });
  });

  group('getStartOfPulseDay', () {
    test('returns today at 4 AM when current time is after 4 AM', () {
      final result = pulseService.getStartOfPulseDay();
      final now = DateTime.now();
      final expected4AM = DateTime(now.year, now.month, now.day, 4, 0, 0);

      if (now.hour >= 4) {
        expect(result.year, equals(expected4AM.year));
        expect(result.month, equals(expected4AM.month));
        expect(result.day, equals(expected4AM.day));
        expect(result.hour, equals(4));
        expect(result.minute, equals(0));
      } else {
        final yesterday4AM = expected4AM.subtract(const Duration(days: 1));
        expect(result.year, equals(yesterday4AM.year));
        expect(result.month, equals(yesterday4AM.month));
        expect(result.day, equals(yesterday4AM.day));
        expect(result.hour, equals(4));
        expect(result.minute, equals(0));
      }
    });

    test('returns 4 AM time with zero minutes and seconds', () {
      final result = pulseService.getStartOfPulseDay();

      expect(result.hour, equals(4));
      expect(result.minute, equals(0));
      expect(result.second, equals(0));
    });
  });

  group('getTodayPulseId', () {
    test('returns pulse id when pulse exists for today', () async {
      when(mockSupabase.from('daily_pulses')).thenAnswer(
        (_) => FakeQueryBuilder(<String, dynamic>{'id': 'pulse-123'}),
      );

      final result = await pulseService.getTodayPulseId();

      expect(result, equals('pulse-123'));
    });

    test('returns null when no pulse exists for today', () async {
      when(mockSupabase.from('daily_pulses')).thenAnswer(
        (_) => FakeQueryBuilder(null),
      );

      final result = await pulseService.getTodayPulseId();

      expect(result, isNull);
    });

    test('returns null when user is not authenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final result = await pulseService.getTodayPulseId();

      expect(result, isNull);
    });

    test('returns null when query fails', () async {
      when(mockSupabase.from('daily_pulses'))
          .thenThrow(Exception('Database error'));

      final result = await pulseService.getTodayPulseId();

      expect(result, isNull);
    });
  });

  group('hasPulsedToday', () {
    test('returns true when pulse exists for today', () async {
      when(mockSupabase.from('daily_pulses')).thenAnswer(
        (_) => FakeQueryBuilder(<String, dynamic>{'id': 'pulse-123'}),
      );

      final result = await pulseService.hasPulsedToday();

      expect(result, isTrue);
    });

    test('returns false when no pulse exists for today', () async {
      when(mockSupabase.from('daily_pulses')).thenAnswer(
        (_) => FakeQueryBuilder(null),
      );

      final result = await pulseService.hasPulsedToday();

      expect(result, isFalse);
    });

    test('returns false when user is not authenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final result = await pulseService.hasPulsedToday();

      expect(result, isFalse);
    });
  });

  group('refreshPulse', () {
    test('successfully updates pulse timestamp', () async {
      final fakeBuilder = FakeQueryBuilder();
      when(mockSupabase.from('daily_pulses'))
          .thenAnswer((_) => fakeBuilder);

      final result = await pulseService.refreshPulse('pulse-123');

      expect(result, isTrue);
      expect(fakeBuilder.updateCalled, isTrue);
      expect(fakeBuilder.lastUpdateData, containsPair('created_at', isA<String>()));
    });

    test('returns false when user is not authenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final result = await pulseService.refreshPulse('pulse-123');

      expect(result, isFalse);
    });

    test('returns false when update fails', () async {
      when(mockSupabase.from('daily_pulses'))
          .thenThrow(Exception('Update failed'));

      final result = await pulseService.refreshPulse('pulse-123');

      expect(result, isFalse);
    });
  });

  group('sendPulse', () {
    test('successfully inserts pulse and returns id', () async {
      final fakeBuilder = FakeQueryBuilder(<String, dynamic>{'id': 'new-pulse-id'});
      when(mockSupabase.from('daily_pulses'))
          .thenAnswer((_) => fakeBuilder);

      final result = await pulseService.sendPulse();

      expect(result, equals('new-pulse-id'));
      expect(fakeBuilder.insertCalled, isTrue);
      expect(fakeBuilder.lastInsertData, {
        'user_id': 'test-user-id',
        'status': 'active',
      });
    });

    test('returns null when user is not authenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final result = await pulseService.sendPulse();

      expect(result, isNull);
    });

    test('returns null when insert fails', () async {
      when(mockSupabase.from('daily_pulses'))
          .thenThrow(Exception('Insert failed'));

      final result = await pulseService.sendPulse();

      expect(result, isNull);
    });
  });

  group('checkAndPulse', () {
    test('skips DB calls when cache is fresh', () async {
      // Set fresh cache
      prefs.setInt('pulse_last_timestamp',
          DateTime.now().millisecondsSinceEpoch);

      final result = await pulseService.checkAndPulse();

      expect(result, isFalse);
      // Verify no Supabase calls were made
      verifyNever(mockSupabase.from(any));
    });

    test('inserts new pulse when no pulse exists today', () async {
      var callCount = 0;
      final insertBuilder = FakeQueryBuilder(<String, dynamic>{'id': 'new-pulse-id'});

      when(mockSupabase.from('daily_pulses')).thenAnswer((_) {
        callCount++;
        if (callCount == 1) {
          // getTodayPulseId — no existing pulse
          return FakeQueryBuilder(null);
        }
        // sendPulse — insert
        return insertBuilder;
      });

      final result = await pulseService.checkAndPulse();

      expect(result, isTrue);
      expect(insertBuilder.insertCalled, isTrue);
      // Verify cache was set
      expect(prefs.getInt('pulse_last_timestamp'), isNotNull);
    });

    test('refreshes pulse when pulse already exists today', () async {
      var callCount = 0;
      final updateBuilder = FakeQueryBuilder();

      when(mockSupabase.from('daily_pulses')).thenAnswer((_) {
        callCount++;
        if (callCount == 1) {
          // getTodayPulseId — existing pulse found
          return FakeQueryBuilder(<String, dynamic>{'id': 'existing-pulse-id'});
        }
        // refreshPulse — update
        return updateBuilder;
      });

      final result = await pulseService.checkAndPulse();

      expect(result, isTrue);
      expect(updateBuilder.updateCalled, isTrue);
      // Verify cache was set
      expect(prefs.getInt('pulse_last_timestamp'), isNotNull);
    });

    test('does not cache on failure', () async {
      when(mockSupabase.from('daily_pulses'))
          .thenThrow(Exception('Error'));

      final result = await pulseService.checkAndPulse();

      expect(result, isFalse);
      expect(prefs.getInt('pulse_last_timestamp'), isNull);
    });
  });
}
