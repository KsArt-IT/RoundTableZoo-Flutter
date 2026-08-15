import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  final resolver = DayResolver();
  late tz.Location kyiv;
  late tz.Location kiritimati;
  late tz.Location saoPaulo;

  setUpAll(() {
    tz.initializeTimeZones();
    kyiv = tz.getLocation('Europe/Kyiv');
    kiritimati = tz.getLocation('Pacific/Kiritimati');
    saoPaulo = tz.getLocation('America/Sao_Paulo');
  });

  DateTime utcOfLocal(tz.Location zone, int y, int m, int d, int h, [int min = 0]) =>
      tz.TZDateTime(zone, y, m, d, h, min).toUtc();

  group('resolve — dayStartHour = 0', () {
    test('23:59 local stays on the current calendar date', () {
      final instant = utcOfLocal(kyiv, 2026, 3, 10, 23, 59);
      final key = resolver.resolve(instant, zone: kyiv, dayStartHour: 0);
      expect(key, const DayKey(year: 2026, month: 3, day: 10));
    });

    test('00:00 local rolls to the next calendar date', () {
      final instant = utcOfLocal(kyiv, 2026, 3, 11, 0);
      final key = resolver.resolve(instant, zone: kyiv, dayStartHour: 0);
      expect(key, const DayKey(year: 2026, month: 3, day: 11));
    });
  });

  group('resolve — dayStartHour = 4', () {
    test('02:00 local still belongs to the previous calendar date', () {
      final instant = utcOfLocal(kyiv, 2026, 3, 11, 2);
      final key = resolver.resolve(instant, zone: kyiv, dayStartHour: 4);
      expect(key, const DayKey(year: 2026, month: 3, day: 10));
    });

    test('04:00 local rolls onto the current calendar date', () {
      final instant = utcOfLocal(kyiv, 2026, 3, 11, 4);
      final key = resolver.resolve(instant, zone: kyiv, dayStartHour: 4);
      expect(key, const DayKey(year: 2026, month: 3, day: 11));
    });
  });

  test('same instant resolves to different days in different zones, instant itself is unchanged', () {
    final instant = utcOfLocal(kyiv, 2026, 3, 10, 20);
    final inKyiv = resolver.resolve(instant, zone: kyiv, dayStartHour: 0);
    final inKiritimati = resolver.resolve(instant, zone: kiritimati, dayStartHour: 0);

    expect(inKyiv, isNot(equals(inKiritimati)));
    expect(instant.isUtc, isTrue);
  });

  test('resolve depends only on its arguments, never on the system clock', () {
    final instant = utcOfLocal(kyiv, 2020, 1, 1, 12);
    final first = resolver.resolve(instant, zone: kyiv, dayStartHour: 4);
    final second = resolver.resolve(instant, zone: kyiv, dayStartHour: 4);
    expect(first, second);
  });

  group('boundsUtc — DST in America/Sao_Paulo', () {
    test('spring-forward day still yields a continuous, non-overlapping bound', () {
      // Historical Brazil DST start: 2018-11-04 00:00 -> 01:00 (clocks skip forward).
      final key = const DayKey(year: 2018, month: 11, day: 4);
      final bounds = resolver.boundsUtc(key, zone: saoPaulo, dayStartHour: 0);
      final nextBounds = resolver.boundsUtc(key.next, zone: saoPaulo, dayStartHour: 0);

      expect(bounds.endUtc, nextBounds.startUtc);
      expect(bounds.endUtc.difference(bounds.startUtc), isNot(const Duration(hours: 24)));
    });

    test('fall-back day still yields a continuous, non-overlapping bound', () {
      // Historical Brazil DST end: 2018-02-18 00:00 -> clocks fall back an
      // hour, so the extra hour falls inside 2018-02-17 (25h day).
      final key = const DayKey(year: 2018, month: 2, day: 17);
      final bounds = resolver.boundsUtc(key, zone: saoPaulo, dayStartHour: 0);
      final nextBounds = resolver.boundsUtc(key.next, zone: saoPaulo, dayStartHour: 0);

      expect(bounds.endUtc, nextBounds.startUtc);
      expect(bounds.endUtc.difference(bounds.startUtc), isNot(const Duration(hours: 24)));
    });
  });

  test('boundsUtc skipped local hour still produces a valid half-open range', () {
    // dayStartHour lands inside the skipped hour on the spring-forward date;
    // TZDateTime normalizes it instead of throwing.
    final key = const DayKey(year: 2018, month: 11, day: 4);
    final bounds = resolver.boundsUtc(key, zone: saoPaulo, dayStartHour: 0);

    expect(bounds.startUtc.isBefore(bounds.endUtc), isTrue);
  });
}
