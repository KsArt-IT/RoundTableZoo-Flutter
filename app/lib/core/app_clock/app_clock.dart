import 'package:timezone/timezone.dart' as tz;

/// Единственный источник «сейчас» и текущего часового пояса устройства.
///
/// `domain/`, `data/` и Cubit обязаны получать время только отсюда —
/// `DateTime.now()` нигде за пределами `SystemAppClock` не вызывается
/// (принцип IV).
abstract interface class AppClock {
  /// Текущий момент в UTC.
  DateTime nowUtc();

  /// Текущая локация устройства.
  tz.Location get location;

  /// Тик раз в минуту, выровненный на начало минуты. Значение тика — момент
  /// в UTC на момент срабатывания; потребитель обязан использовать именно
  /// его, а не запрашивать время заново.
  Stream<DateTime> get minuteTicks;

  /// Переустановить локацию (вызывается на resume, если системный пояс
  /// сменился).
  void updateLocation(tz.Location location);
}
