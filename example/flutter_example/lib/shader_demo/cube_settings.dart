abstract final class CubeSettings {
  static const size = 0.50;

  static const rotationsPerSecond = 1.0 / 12.0;

  static const tilt = 0.45;

  static Duration get rotationPeriod {
    final microseconds = (Duration.microsecondsPerSecond / rotationsPerSecond).round();
    return Duration(microseconds: microseconds);
  }
}
