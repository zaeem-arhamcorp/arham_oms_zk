import 'dart:math' as math;

final List<String> selfieDialogTaglines = [
  'Flash a winner smile—we\'re excited to start something great!',
  'Show us your best smile—let\'s make today amazing!',
  'Smile big—your success story starts now!',
  'Ready to shine? Let\'s capture the moment!',
  'Your smile is our fuel—let\'s go places!',
  'Grin and win—let\'s make it happen!',
  'Smile like you mean it—greatness awaits!',
  'Beam with confidence—today\'s your day!',
  'Show that radiant smile—let\'s get started!',
  'Spark joy and success—smile now!',
];

String getRandomSelfieDialogTagline() {
  final random = math.Random();
  return selfieDialogTaglines[random.nextInt(selfieDialogTaglines.length)];
}
