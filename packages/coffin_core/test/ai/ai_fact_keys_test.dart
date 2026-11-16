import 'package:coffin_core/src/ai/ai_fact_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the four key strings are exact', () {
    expect(AiFactKeys.streakCount, 'streakCount');
    expect(AiFactKeys.daysSinceLastCommit, 'daysSinceLastCommit');
    expect(AiFactKeys.ghostName, 'ghostName');
    expect(AiFactKeys.projectName, 'projectName');
  });
}
