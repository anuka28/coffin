import 'package:coffin_core/coffin_core.dart';

import '../domain/grave.dart';
import '../domain/scene/stable_hash.dart';
import '../domain/seance/seance_facts.dart';

/// Longest Verdict_Line the séance asks for, in UTF-16 code units.
const int verdictMaxLength = 140;

/// How long the séance waits for the primary generator before it falls back.
const Duration verdictWaitLimit = Duration(seconds: 3);

/// Builds the request for the séance verdict of [grave].
///
/// Carries exactly two facts: the grave name and the day count from [facts].
/// The seed depends only on the grave id, so the same grave always asks the
/// same question.
AiRequest buildVerdictRequest({
  required Grave grave,
  required SeanceFacts facts,
}) {
  return AiRequest(
    purpose: AiPurpose.seanceVerdict,
    facts: <String, Object?>{
      AiFactKeys.projectName: grave.name,
      AiFactKeys.daysSinceLastCommit: facts.dayCount,
    },
    maxLength: verdictMaxLength,
    seed: StableHash.of(grave.id) % (AiRequest.maxSeed + 1),
  );
}

/// Builds the generator the séance asks for its verdict.
///
/// Both the primary and the secondary are the offline generator, so no
/// network and no key are involved. [verdictWaitLimit] bounds the wait.
FallbackCoffinAI buildSeanceAi() {
  return FallbackCoffinAI(
    primary: const OfflineCoffinAI(),
    secondary: const OfflineCoffinAI(),
    timeout: verdictWaitLimit,
  );
}
