import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bestfin/features/llm/data/services/llm_service.dart';
import 'package:bestfin/features/llm/data/services/model_download_service.dart';
import 'package:bestfin/features/llm/domain/models/ai_model_type.dart';
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/domain/services/financial_context_builder.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_insights_provider.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_narrative_provider.dart';

// Singleton LlmService shared across providers
final llmServiceProvider = Provider<LlmService>((ref) {
  final service = LlmService();
  ref.onDispose(() => service.dispose());
  return service;
});

class SelectedModelNotifier extends Notifier<AiModelType> {
  static const _keyAiModel = 'selected_ai_model';

  @override
  AiModelType build() {
    _load();
    if (Platform.isLinux) return AiModelType.minicpmV4_6;
    if (Platform.isAndroid) return AiModelType.qwen3_0_6bLiteRt;
    return AiModelType.minicpm5_1b;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModelId = prefs.getString(_keyAiModel);
    if (savedModelId != null) {
      try {
        final model = AiModelType.values.firstWhere(
          (e) => e.id == savedModelId,
        );
        if (Platform.isAndroid && model == AiModelType.gemma3nE2bLiteRt) {
          return;
        }
        if (!_isModelAvailableOnCurrentPlatform(model)) return;
        state = model;
      } catch (_) {}
    }
  }

  Future<void> setModel(AiModelType model) async {
    if (!_isModelAvailableOnCurrentPlatform(model)) return;
    if (state == model) return;
    state = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiModel, model.id);
  }

  bool _isModelAvailableOnCurrentPlatform(AiModelType model) {
    if (Platform.isLinux) return !model.isAndroidOnly;
    if (Platform.isAndroid) return !model.isLinuxOnly;
    return !model.isLinuxOnly && !model.isAndroidOnly;
  }
}

final selectedModelProvider =
    NotifierProvider<SelectedModelNotifier, AiModelType>(
      SelectedModelNotifier.new,
    );

final llmStateProvider = NotifierProvider<LlmStateNotifier, LlmState>(
  LlmStateNotifier.new,
);

class LlmStateNotifier extends Notifier<LlmState> {
  Future<void>? _loadingFuture;

  @override
  LlmState build() {
    // Watching selectedModelProvider causes this notifier to automatically
    // rebuild and re-initialize whenever the selected model changes.
    ref.watch(selectedModelProvider);
    _loadingFuture = null;
    Future.microtask(() => initialize());
    return const LlmState.initial();
  }

  Future<void> initialize() async {
    final service = ref.read(llmServiceProvider);
    if (state.status == LlmStatus.ready && service.isLoaded) {
      return;
    }

    if (state.status == LlmStatus.loading ||
        state.status == LlmStatus.downloading) {
      if (_loadingFuture != null) {
        await _loadingFuture;
      }
      return;
    }

    final modelType = ref.read(selectedModelProvider);
    final modelPresent = await ModelDownloadService.isModelPresent(modelType);
    if (!modelPresent) {
      if (Platform.isAndroid) {
        final activeId = await ModelDownloadService.getActiveDownloadId(
          'active_download_id_model_${modelType.id}',
        );
        if (activeId != null) {
          unawaited(downloadAndLoad());
          return;
        }
      }
      state = const LlmState.initial();
      return;
    }

    await _executeLoad();
  }

  Future<void> _executeLoad() async {
    if (_loadingFuture != null) {
      return _loadingFuture!;
    }
    _loadingFuture = _loadModel();
    try {
      await _loadingFuture;
    } finally {
      _loadingFuture = null;
    }
  }

  Future<void> downloadAndLoad() async {
    if (state.isBusy) return;

    state = state.copyWith(status: LlmStatus.downloading, downloadProgress: 0);

    try {
      final modelType = ref.read(selectedModelProvider);
      await for (final progress in ModelDownloadService.downloadModel(
        modelType,
      )) {
        state = state.copyWith(downloadProgress: progress.fraction);
      }
      await _executeLoad();
    } catch (e, st) {
      debugPrint('[LLM] Falha ao baixar o modelo: $e\n$st');
      state = state.copyWith(
        status: LlmStatus.error,
        errorMessage: 'Falha ao baixar o modelo: $e',
      );
    }
  }

  Future<void> _loadModel() async {
    state = state.copyWith(status: LlmStatus.loading);
    try {
      final modelType = ref.read(selectedModelProvider);
      final path = await ModelDownloadService.modelPath(modelType);
      // Load mmproj for vision support if available
      final mmProjPath = modelType.hasVision
          ? await ModelDownloadService.mmProjPath(modelType)
          : null;
      final mmProjExists =
          mmProjPath != null &&
          await ModelDownloadService.isMmProjPresent(modelType);
      final context = modelType.runtime == AiModelRuntime.liteRtLm
          ? ''
          : FinancialContextBuilder.build(ref);
      final service = ref.read(llmServiceProvider);
      await service.load(
        path,
        modelType: modelType,
        systemPrompt: context,
        mmProjPath: mmProjExists ? mmProjPath : null,
      );
      state = state.copyWith(status: LlmStatus.ready);
      // Trigger insight + narrative refresh if cache is stale
      ref.read(llmInsightsCacheInvalidatorProvider).call();
      ref.read(llmNarrativeCacheInvalidatorProvider).call();
    } catch (e, st) {
      debugPrint('[LLM] Falha ao carregar o modelo: $e\n$st');
      state = state.copyWith(
        status: LlmStatus.error,
        errorMessage: 'Falha ao carregar o modelo: $e',
      );
    }
  }

  void setGenerating(bool generating) {
    if (state.status == LlmStatus.ready && generating) {
      state = state.copyWith(status: LlmStatus.generating);
    } else if (state.status == LlmStatus.generating && !generating) {
      state = state.copyWith(status: LlmStatus.ready);
    }
  }

  void clearError() {
    state = const LlmState.initial();
  }

  // Public entry point for reloading the model (e.g., after mmproj download).
  Future<void> reload() => _executeLoad();
}

/// Controls whether the current chat model should use its thinking mode.
final llmThinkingEnabledProvider = NotifierProvider<_ThinkingNotifier, bool>(
  _ThinkingNotifier.new,
);

class _ThinkingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Whether vision (mmproj) is available for the selected model.
final visionAvailableProvider = FutureProvider<bool>((ref) async {
  if (!Platform.isLinux) return false;
  final modelType = ref.watch(selectedModelProvider);
  if (!modelType.hasVision) return false;
  return ModelDownloadService.isMmProjPresent(modelType);
});

/// Notifier for downloading the mmproj (vision projector) file.
/// Tracks download progress as 0.0–1.0; null when idle.
final mmProjDownloadProgressProvider =
    NotifierProvider<MmProjDownloadNotifier, double?>(() {
      return MmProjDownloadNotifier();
    });

class MmProjDownloadNotifier extends Notifier<double?> {
  @override
  double? build() {
    final modelType = ref.watch(selectedModelProvider);
    if (Platform.isAndroid && modelType.hasVision) {
      Future.microtask(() async {
        final activeId = await ModelDownloadService.getActiveDownloadId(
          'active_download_id_mmproj_${modelType.id}',
        );
        if (activeId != null) {
          unawaited(download());
        }
      });
    }
    return null;
  }

  Future<void> download() async {
    if (state != null) return; // Already downloading
    final modelType = ref.read(selectedModelProvider);
    if (!modelType.hasVision || modelType.mmProjUrl == null) return;

    state = 0.0;
    try {
      await for (final progress in ModelDownloadService.downloadMmProj(
        modelType,
      )) {
        state = progress.fraction;
      }
      // Reload model with mmproj now available
      await ref.read(llmStateProvider.notifier).reload();
      ref.invalidate(visionAvailableProvider);
    } catch (e) {
      debugPrint('[LLM] Falha ao baixar mmproj: $e');
    } finally {
      state = null;
    }
  }
}
