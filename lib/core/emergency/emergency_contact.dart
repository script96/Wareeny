import 'dart:convert';

/// A single trusted emergency contact who will be called/texted in danger mode.
class EmergencyContact {
  const EmergencyContact({required this.name, required this.phone});

  /// Human-readable name, e.g. "Mom" or "أمي".
  final String name;

  /// Phone number in international format, e.g. "+201234567890".
  final String phone;

  // ── Serialization ───────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String,
      phone: json['phone'] as String,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Encodes a list to a single JSON string for SharedPreferences.
  static String encodeList(List<EmergencyContact> list) {
    return jsonEncode(list.map((c) => c.toJson()).toList());
  }

  /// Decodes a JSON string (from SharedPreferences) back to a list.
  static List<EmergencyContact> decodeList(String json) {
    try {
      final data = jsonDecode(json) as List<dynamic>;
      return data
          .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmergencyContact &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          phone == other.phone;

  @override
  int get hashCode => name.hashCode ^ phone.hashCode;

  @override
  String toString() => 'EmergencyContact(name: $name, phone: $phone)';
}
