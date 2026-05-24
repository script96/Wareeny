import 'package:flutter_test/flutter_test.dart';
import 'package:wareeny/features/indoor_navigation/indoor_navigation_feedback_controller.dart';
import 'package:wareeny/features/indoor_navigation/indoor_navigation_phrases.dart';
import 'package:wareeny/shared/bridges/indoor_navigation_bridge.dart';

void main() {
  test('maps indoor states to precise Egyptian Arabic phrases', () {
    expect(
      IndoorNavigationPhrases.forCode(IndoorPathCode.pathBlocked),
      'الطريق مقفول، وقف',
    );
    expect(
      IndoorNavigationPhrases.forCode(IndoorPathCode.narrowPath),
      'المكان ضيق، امشي ببطء',
    );
    expect(
      IndoorNavigationPhrases.forCode(IndoorPathCode.forwardThenSlightLeft),
      'امشي لقدام شوية وبعدها ميل سنة شمال',
    );
  });

  test('maps prototype English state text to Egyptian Arabic phrases', () {
    expect(
      IndoorNavigationPhrases.forPrototypeText('CLEAR PATH'),
      'الطريق قدامك واضح',
    );
    expect(
      IndoorNavigationPhrases.forPrototypeText('PATH BLOCKED'),
      'الطريق مقفول، وقف',
    );
    expect(
      IndoorNavigationPhrases.forPrototypeText('UNKNOWN STATE'),
      'مش قادر أحدد الطريق بأمان',
    );
  });

  test('speaks path blocked only after stable danger samples', () {
    final controller = IndoorNavigationFeedbackController();
    final start = DateTime(2026, 1, 1);
    final state = _state(
      IndoorPathCode.pathBlocked,
      IndoorPathSeverity.danger,
      score: 0.9,
    );

    expect(controller.handle(state, start), isNull);
    final command = controller.handle(
      state,
      start.add(const Duration(milliseconds: 100)),
    );

    expect(command?.text, 'الطريق مقفول، وقف');
    expect(command?.interrupt, isTrue);
  });

  test('suppresses repeated danger state during cooldown', () {
    final controller = IndoorNavigationFeedbackController();
    final start = DateTime(2026, 1, 1);
    final state = _state(
      IndoorPathCode.pathBlocked,
      IndoorPathSeverity.danger,
      score: 0.9,
    );

    controller.handle(state, start);
    expect(
      controller.handle(state, start.add(const Duration(milliseconds: 100))),
      isNotNull,
    );
    expect(
      controller.handle(state, start.add(const Duration(seconds: 1))),
      isNull,
    );
  });

  test('does not speak unstable left right flicker', () {
    final controller = IndoorNavigationFeedbackController();
    final start = DateTime(2026, 1, 1);

    expect(
      controller.handle(
        _state(IndoorPathCode.moveLeft, IndoorPathSeverity.navigationCue),
        start,
      ),
      isNull,
    );
    expect(
      controller.handle(
        _state(IndoorPathCode.moveRight, IndoorPathSeverity.navigationCue),
        start.add(const Duration(milliseconds: 100)),
      ),
      isNull,
    );
    expect(
      controller.handle(
        _state(IndoorPathCode.moveLeft, IndoorPathSeverity.navigationCue),
        start.add(const Duration(milliseconds: 200)),
      ),
      isNull,
    );
  });

  test('speaks narrow path after stable cue samples', () {
    final controller = IndoorNavigationFeedbackController();
    final start = DateTime(2026, 1, 1);
    final state = _state(
      IndoorPathCode.narrowPath,
      IndoorPathSeverity.navigationCue,
    );

    expect(controller.handle(state, start), isNull);
    expect(
      controller.handle(state, start.add(const Duration(milliseconds: 100))),
      isNull,
    );
    final command = controller.handle(
      state,
      start.add(const Duration(milliseconds: 200)),
    );

    expect(command?.text, 'المكان ضيق، امشي ببطء');
    expect(command?.interrupt, isFalse);
  });

  test('speaks clear path only after a previous warning state', () {
    final controller = IndoorNavigationFeedbackController();
    final start = DateTime(2026, 1, 1);
    final clear = _state(
      IndoorPathCode.clearPath,
      IndoorPathSeverity.clear,
      score: 0.9,
    );

    for (var index = 0; index < 5; index += 1) {
      expect(
        controller.handle(
          clear,
          start.add(Duration(milliseconds: index * 100)),
        ),
        isNull,
      );
    }

    controller.reset();
    final blocked = _state(
      IndoorPathCode.pathBlocked,
      IndoorPathSeverity.danger,
      score: 0.9,
    );
    controller.handle(blocked, start);
    controller.handle(blocked, start.add(const Duration(milliseconds: 100)));

    IndoorSpeechCommand? command;
    for (var index = 0; index < 5; index += 1) {
      command = controller.handle(
        clear,
        start.add(Duration(seconds: 5, milliseconds: index * 100)),
      );
    }

    expect(command?.text, 'الطريق قدامك واضح');
  });
}

IndoorPathState _state(
  IndoorPathCode code,
  IndoorPathSeverity severity, {
  double score = 0.8,
}) {
  return IndoorPathState(
    code: code,
    severity: severity,
    score: score,
    stateText: code.prototypeText,
    timestamp: DateTime(2026, 1, 1),
  );
}
