// QA types — data classes for document question-answering.
//
// Used by GeminiService.answerQuestionFromDocument() and
// VisionService QA state machine.

/// A single question-answer exchange in QA history.
class QaTurn {
  final String question;
  final String answer;

  const QaTurn({required this.question, required this.answer});

  @override
  String toString() => 'QaTurn(q: $question, a: $answer)';
}

/// Result from a document QA API call.
class DocumentQaResult {
  final String answer;
  final bool isError;

  const DocumentQaResult({required this.answer, this.isError = false});

  const DocumentQaResult.error(String msg)
      : answer = msg,
        isError = true;

  @override
  String toString() => 'DocumentQaResult(error: $isError, answer: $answer)';
}

/// Trims a list of QA turns to keep only the latest [maxTurns].
List<QaTurn> trimQaHistory(List<QaTurn> history, {int maxTurns = 5}) {
  if (history.length <= maxTurns) return List.from(history);
  return history.sublist(history.length - maxTurns);
}
