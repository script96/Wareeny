enum EmergencyContactSource { manual, deviceContact }

class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.phoneNumber,
    required this.relationship,
    required this.source,
    required this.verified,
  });

  final String name;
  final String phoneNumber;
  final String relationship;
  final EmergencyContactSource source;
  final bool verified;

  Map<String, dynamic> toJson() => {
    'name': name,
    'phoneNumber': phoneNumber,
    'relationship': relationship,
    'source': switch (source) {
      EmergencyContactSource.manual => 'manual',
      EmergencyContactSource.deviceContact => 'device_contact',
    },
    'verified': verified,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      relationship: json['relationship'] as String? ?? '',
      source: json['source'] == 'device_contact'
          ? EmergencyContactSource.deviceContact
          : EmergencyContactSource.manual,
      verified: json['verified'] as bool? ?? false,
    );
  }
}
