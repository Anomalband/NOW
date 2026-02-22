Duration remainingUntilIstanbulMidnight(DateTime now) {
  const istanbulUtcOffsetHours = 3;
  final istanbulNow = now.toUtc().add(
    const Duration(hours: istanbulUtcOffsetHours),
  );
  final nextMidnight = DateTime(
    istanbulNow.year,
    istanbulNow.month,
    istanbulNow.day + 1,
  );
  return nextMidnight.difference(istanbulNow);
}

String formatCountdown(Duration value) {
  final totalSeconds = value.inSeconds.clamp(0, 86_400).toInt();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return "${hours.toString().padLeft(2, "0")}:${minutes.toString().padLeft(2, "0")}:${seconds.toString().padLeft(2, "0")}";
}
