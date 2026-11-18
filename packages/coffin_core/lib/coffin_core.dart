/// Public API surface for the Coffin skeleton.
///
/// Apps import `package:coffin_core/coffin_core.dart` and must never
/// import files under `src/`.
library;

export 'package:go_router/go_router.dart'
    show GoRouter, GoRouterHelper, GoRouterState;

export 'src/ai/ai_fact_keys.dart' show AiFactKeys;
export 'src/ai/ai_fallback_error.dart' show AiFallbackError;
export 'src/ai/ai_issue.dart' show AiIssue;
export 'src/ai/ai_issue_kind.dart' show AiIssueKind;
export 'src/ai/ai_issue_reporter.dart' show AiIssueReporter, discardAiIssues;
export 'src/ai/ai_purpose.dart' show AiPurpose;
export 'src/ai/ai_reply.dart' show AiReply;
export 'src/ai/ai_request.dart' show AiRequest;
export 'src/ai/ai_timer_factory.dart' show AiTimerFactory;
export 'src/ai/coffin_ai.dart' show CoffinAI;
export 'src/ai/fallback_coffin_ai.dart' show FallbackCoffinAI;
export 'src/ai/offline_coffin_ai.dart' show OfflineCoffinAI;
export 'src/ai/reply_source.dart' show ReplySource;
export 'src/router/app_route.dart' show AppRoute;
export 'src/router/fog_frame.dart' show FogFrame;
export 'src/router/fog_math.dart' show FogMath;
export 'src/router/fog_router.dart' show FogRouter;
export 'src/router/fog_transition.dart' show FogTransition;
export 'src/router/fog_transition_page.dart' show FogTransitionPage;
export 'src/router/not_found_page.dart' show NotFoundPage;
export 'src/storage/hive_flutter_initializer.dart' show hiveFlutterInitializer;
export 'src/storage/issue_reporter.dart' show IssueReporter, discardIssues;
export 'src/storage/json_map.dart' show JsonMap;
export 'src/storage/key_validator.dart' show KeyValidator;
export 'src/storage/memory_record_repository.dart' show MemoryRecordRepository;
export 'src/storage/migration_hook.dart' show MigrationHook;
export 'src/storage/opened_repository.dart' show OpenedRepository;
export 'src/storage/record_codec.dart' show RecordCodec;
export 'src/storage/record_repository.dart' show RecordRepository;
export 'src/storage/storage_event.dart' show StorageEvent;
export 'src/storage/storage_event_kind.dart' show StorageEventKind;
export 'src/storage/storage_issue.dart' show StorageIssue;
export 'src/storage/storage_issue_kind.dart' show StorageIssueKind;
export 'src/storage/storage_opener.dart' show StorageInitializer, StorageOpener;
export 'src/theme/coffin_color_tokens.dart' show CoffinColorTokens;
export 'src/theme/coffin_glow.dart' show CoffinGlow;
export 'src/theme/coffin_metrics.dart' show CoffinMetrics;
export 'src/theme/coffin_theme.dart' show CoffinTheme;
export 'src/theme/coffin_typography.dart' show CoffinTypography;
export 'src/theme/contrast_pair.dart' show ContrastPair;
export 'src/theme/wcag_contrast.dart' show WcagContrast;
export 'src/widgets/coffin_mark.dart' show CoffinMark;
export 'src/widgets/crypt_gallery.dart' show CryptGallery;
export 'src/widgets/flicker_text.dart' show FlickerText;
export 'src/widgets/fog_background.dart' show FogBackground;
export 'src/widgets/ghost_loader.dart' show GhostLoader;
export 'src/widgets/ghost_mood.dart' show GhostMood;
export 'src/widgets/ghost_painter.dart' show GhostPainter;
export 'src/widgets/tombstone_card.dart' show TombstoneCard;
