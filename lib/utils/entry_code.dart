import 'dart:math';

/// Generates a unique-enough 6-digit public identifier used for contest numbers
/// and video numbers. Shown to users and used in search / share / ads
/// (e.g. "Competition #240915", "Vote for video #247183").
String generateEntryCode() => (100000 + Random().nextInt(900000)).toString();
