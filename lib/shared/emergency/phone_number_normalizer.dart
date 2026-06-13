import 'package:phone_numbers_parser/phone_numbers_parser.dart';

class PhoneNumberNormalizer {
  const PhoneNumberNormalizer();

  String? normalize(String raw, {IsoCode defaultCountry = IsoCode.EG}) {
    try {
      final trimmed = raw.trim();
      final parsed = trimmed.startsWith('+')
          ? PhoneNumber.parse(trimmed)
          : PhoneNumber.parse(trimmed, destinationCountry: defaultCountry);
      if (!parsed.isValid()) return null;
      return parsed.international;
    } on Object {
      return null;
    }
  }
}
