import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pulse_app/core/services/pulse_service.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
])
import 'pulse_service_test.mocks.dart';

/// Fake SupabaseQueryBuilder that returns [FakeFilterBuilder] for all methods.
/// Tracks insert() calls for verification.
class FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final dynamic _awaitResult;
  bool insertCalled = false;
  Map<String, dynamic>? lastInsertData;

  FakeQueryBuilder([this._awaitResult]);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #insert) {
      insertCalled = true;
      if (invocation.positionalArguments.isNotEmpty) {
        lastInsertData =
            invocation.positionalArguments[0] as Map<String, dynamic>?;
      }
    }
    // Return a filter builder for all chain methods (select, insert, etc.)
    return FakeFilterBuilder(_awaitResult);
  }
}

/// Fake PostgrestFilterBuilder that returns self for filter methods (eq, gte)
/// and a [FakeResponseBuilder] for count(). Handles await via then().
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
    // then() — for direct await (e.g., after insert)
    if (invocation.memberName == #then) {
      final onValue = invocation.positionalArguments[0] as Function;
      return Future<dynamic>.value(_awaitResult ?? <Map<String, dynamic>>[]).then((v) => onValue(v));
    }
    // eq, gte, etc. return self to continue the chain
    return this;
  }
}

/// Fake for the builder returned by count(). Resolves to configured result
/// when awaited.
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

void main() {
  late PulseService pulseService;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    when(mockSupabase.auth).thenReturn(mockAuth);
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('test-user-id');

    pulseService = PulseService(mockSupabase);
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

  group('hasPulsedToday', () {
    test('returns true when pulse exists for today', () async {
      when(mockSupabase.from('daily_pulses')).thenAnswer(
        (_) => FakeQueryBuilder(PostgrestResponse(count: 1, data: <Map<String, dynamic>>[])),
      );

      final result = await pulseService.hasPulsedToday();

      expect(result, isTrue);
    });

    test('returns false when no pulse exists for today', () async {
      when(mockSupabase.from('daily_pulses')).thenAnswer(
        (_) => FakeQueryBuilder(PostgrestResponse(count: 0, data: <Map<String, dynamic>>[])),
      );

      final result = await pulseService.hasPulsedToday();

      expect(result, isFalse);
    });

    test('returns false when user is not authenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final result = await pulseService.hasPulsedToday();

      expect(result, isFalse);
    });

    test('returns false and logs error when query fails', () async {
      when(mockSupabase.from('daily_pulses'))
          .thenThrow(Exception('Database error'));

      final result = await pulseService.hasPulsedToday();

      expect(result, isFalse);
    });
  });

  group('sendPulse', () {
    test('successfully inserts pulse into database', () async {
      final fakeBuilder = FakeQueryBuilder();
      when(mockSupabase.from('daily_pulses'))
          .thenAnswer((_) => fakeBuilder);

      final result = await pulseService.sendPulse();

      expect(result, isTrue);
      expect(fakeBuilder.insertCalled, isTrue);
      expect(fakeBuilder.lastInsertData, {
        'user_id': 'test-user-id',
        'status': 'active',
      });
    });

    test('returns false when user is not authenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final result = await pulseService.sendPulse();

      expect(result, isFalse);
    });

    test('returns false and logs error when insert fails', () async {
      when(mockSupabase.from('daily_pulses'))
          .thenThrow(Exception('Insert failed'));

      final result = await pulseService.sendPulse();

      expect(result, isFalse);
    });
  });

  group('checkAndPulse', () {
    test('sends pulse when user has not pulsed today', () async {
      var callCount = 0;
      final insertBuilder = FakeQueryBuilder();

      when(mockSupabase.from('daily_pulses')).thenAnswer((_) {
        callCount++;
        if (callCount == 1) {
          return FakeQueryBuilder(PostgrestResponse(count: 0, data: <Map<String, dynamic>>[]));
        }
        return insertBuilder;
      });

      final result = await pulseService.checkAndPulse();

      expect(result, isTrue);
      expect(insertBuilder.insertCalled, isTrue);
    });

    test('does not send pulse when user has already pulsed today', () async {
      final fakeBuilder = FakeQueryBuilder(
        PostgrestResponse(count: 1, data: <Map<String, dynamic>>[]),
      );
      when(mockSupabase.from('daily_pulses'))
          .thenAnswer((_) => fakeBuilder);

      final result = await pulseService.checkAndPulse();

      expect(result, isFalse);
      expect(fakeBuilder.insertCalled, isFalse);
    });

    test('returns false when error occurs', () async {
      when(mockSupabase.from('daily_pulses'))
          .thenThrow(Exception('Error'));

      final result = await pulseService.checkAndPulse();

      expect(result, isFalse);
    });
  });
}
