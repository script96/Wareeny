import 'package:wareeny/shared/bridges/indoor_navigation_bridge.dart';

class IndoorNavigationPhrases {
  const IndoorNavigationPhrases._();

  static const _phrases = {
    IndoorPathCode.clearPath: 'الطريق قدامك واضح',
    IndoorPathCode.cautionLeft: 'في عائق ناحية الشمال',
    IndoorPathCode.cautionRight: 'في عائق ناحية اليمين',
    IndoorPathCode.obstacleAhead: 'في عائق قدامك',
    IndoorPathCode.tripHazardCenter: 'خد بالك، في حاجة ممكن تكعبل قدامك',
    IndoorPathCode.moveLeft: 'اتحرك سنة شمال',
    IndoorPathCode.moveRight: 'اتحرك سنة يمين',
    IndoorPathCode.forwardKeepCenter: 'امشي لقدام شوية وخليك في النص',
    IndoorPathCode.forwardThenSlightLeft: 'امشي لقدام شوية وبعدها ميل سنة شمال',
    IndoorPathCode.forwardThenSlightRight:
        'امشي لقدام شوية وبعدها ميل سنة يمين',
    IndoorPathCode.keepLeft: 'خليك ناحية الشمال',
    IndoorPathCode.keepRight: 'خليك ناحية اليمين',
    IndoorPathCode.narrowPath: 'المكان ضيق، امشي ببطء',
    IndoorPathCode.pathBlocked: 'الطريق مقفول، وقف',
    IndoorPathCode.lowLightUncertain:
        'الإضاءة ضعيفة، مش قادر أحدد الطريق بأمان',
  };

  static String forCode(IndoorPathCode code) {
    return _phrases[code] ?? 'مش قادر أحدد الطريق بأمان';
  }

  static String forPrototypeText(String stateText) {
    final code = IndoorPathCode.fromPrototypeText(stateText);
    if (code == null) {
      return 'مش قادر أحدد الطريق بأمان';
    }
    return forCode(code);
  }
}
