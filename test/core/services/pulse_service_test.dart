import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pulse_app/core/services/pulse_service.dart';

// Generate mocks for Supabase classes
@GenerateMocks([SupabaseClient, GoTrueClient, User, SupabaseQueryBuilder, PostgrestFilterBuilder])
import 'pulse_service_test.mocks.dart';

void main() {
  late PulseService pulseService;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    // Setup auth mocks
    when(mockSupabase.auth).thenReturn(mockAuth);
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('test-user-id');

    pulseService = PulseService(mockSupabase);
  });

  group('getStartOfPulseDay', () {
    test('returns today at 4 AM when current time is after 4 AM', () {
      // Create a time that is after 4 AM (e.g., 10:30 AM)
      final testTime = DateTime(2024, 2, 15, 10, 30);

      // Note: This test uses the actual system time, so we're testing the logic manually
      final result = pulseService.getStartOfPulseDay();
      final now = DateTime.now();
      final expected4AM = DateTime(now.year, now.month, now.day, 4, 0, 0);

      if (now.hour >= 4) {
        // Current time is after 4 AM
        expect(result.year, equals(expected4AM.year));
        expect(result.month, equals(expected4AM.month));
        expect(result.day, equals(expected4AM.day));
        expect(result.hour, equals(4));
        expect(result.minute, equals(0));
      } else {
        // Current time is before 4 AM
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
      // Mock the query builder chain
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();

      when(mockSupabase.from('daily_pulses')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.select('id')).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.eq('user_id', any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.gte('created_at', any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.count(CountOption.exact)).thenAnswer((_) async =>
        PostgrestResponse(count: 1, data: []));

      final result = await pulseService.hasPulsedToday();

      expect(result, isTrue);
    });

    test('returns false when no pulse exists for today', () async {
      // Mock the query builder chain
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();

      when(mockSupabase.from('daily_pulses')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.select('id')).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.eq('user_id', any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.gte('created_at', any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.count(CountOption.exact)).thenAnswer((_) async =>
        PostgrestResponse(count: 0, data: []));

      final result = await pulseService.hasPulsedToday();

      expect(result, isFalse);
    });

    test('returns false when user is not authenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final result = await pulseService.hasPulsedToday();

      expect(result, isFalse);
    });

    test('returns false and logs error when query fails', () async {
      when(mockSupabase.from('daily_pulses')).thenThrow(Exception('Database error'));

      final result = await pulseService.hasPulsedToday();

      expect(result, isFalse);
    });
  });

  group('sendPulse', () {
    test('successfully inserts pulse into database', () async {
      // Mock the query builder
      final mockQueryBuilder = MockSupabaseQueryBuilder();

      when(mockSupabase.from('daily_pulses')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.insert(any)).thenAnswer((_) async => []);

      final result = await pulseService.sendPulse();

      expect(result, isTrue);
      verify(mockQueryBuilder.insert({
        'user_id': 'test-user-id',
        'status': 'active',
      })).called(1);
    });

    test('returns false when user is not authenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final result = await pulseService.sendPulse();

      expect(result, isFalse);
    });

    test('returns false and logs error when insert fails', () async {
      when(mockSupabase.from('daily_pulses')).thenThrow(Exception('Insert failed'));

      final result = await pulseService.sendPulse();

      expect(result, isFalse);
    });
  });

  group('checkAndPulse', () {
    test('sends pulse when user has not pulsed today', () async {
      // Mock hasPulsedToday to return false
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();

      when(mockSupabase.from('daily_pulses')).thenReturn(mockQueryBuilder);

      // First call: hasPulsedToday (returns count 0)
      when(mockQueryBuilder.select('id')).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.eq('user_id', any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.gte('created_at', any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.count(CountOption.exact)).thenAnswer((_) async =>
        PostgrestResponse(count: 0, data: []));

      // Second call: sendPulse (inserts row)
      when(mockQueryBuilder.insert(any)).thenAnswer((_) async => []);

      final result = await pulseService.checkAndPulse();

      expect(result, isTrue);
      verify(mockQueryBuilder.insert(any)).called(1);
    });

    test('does not send pulse when user has already pulsed today', () async {
      // Mock hasPulsedToday to return true
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();

      when(mockSupabase.from('daily_pulses')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.select('id')).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.eq('user_id', any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.gte('created_at', any)).thenReturn(mockFilterBuilder);
      when(mockFilterBuilder.count(CountOption.exact)).thenAnswer((_) async =>
        PostgrestResponse(count: 1, data: []));

      final result = await pulseService.checkAndPulse();

      expect(result, isFalse);
      verifyNever(mockQueryBuilder.insert(any));
    });

    test('returns false when error occurs', () async {
      when(mockSupabase.from('daily_pulses')).thenThrow(Exception('Error'));

      final result = await pulseService.checkAndPulse();

      expect(result, isFalse);
    });
  });
}
