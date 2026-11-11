/// Bharat ka mobile: "+91 98765-43210", "098765 43210", "919876543210" → "9876543210".
/// Galat ho to null.
String? normalizePhone(String? input) {
  if (input == null) return null;
  var d = input.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  return RegExp(r'^[6-9]\d{9}$').hasMatch(d) ? d : null;
}

/// Supabase Auth ke liye E.164: "+919876543210"
String e164(String phone10) => '+91$phone10';
