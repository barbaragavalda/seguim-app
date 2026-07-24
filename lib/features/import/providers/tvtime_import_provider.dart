import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/tvtime_import_api.dart';

enum TvTimeImportPhase { idle, selected, uploading, processing, done, failed }

class TvTimeImportState {
  const TvTimeImportState({
    this.phase = TvTimeImportPhase.idle,
    this.fileName,
    this.fileSize,
    this.fileBytes,
    this.summary,
    this.errorMessage,
  });

  final TvTimeImportPhase phase;
  final String? fileName;
  final int? fileSize;
  final List<int>? fileBytes;
  final TvTimeImportSummary? summary;
  final String? errorMessage;

  TvTimeImportState copyWith({
    TvTimeImportPhase? phase,
    String? fileName,
    int? fileSize,
    List<int>? fileBytes,
    TvTimeImportSummary? summary,
    String? errorMessage,
  }) {
    return TvTimeImportState(
      phase: phase ?? this.phase,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileBytes: fileBytes ?? this.fileBytes,
      summary: summary ?? this.summary,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class TvTimeImportController extends Notifier<TvTimeImportState> {
  static const _pollInterval = Duration(seconds: 3);

  late final TvTimeImportApi _api;
  Timer? _pollTimer;

  @override
  TvTimeImportState build() {
    _api = TvTimeImportApi();
    ref.onDispose(() => _pollTimer?.cancel());
    return const TvTimeImportState();
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file?.bytes == null) return;

    state = TvTimeImportState(
      phase: TvTimeImportPhase.selected,
      fileName: file!.name,
      fileSize: file.size,
      fileBytes: file.bytes,
    );
  }

  void clearFile() {
    _pollTimer?.cancel();
    state = const TvTimeImportState();
  }

  Future<void> startImport() async {
    final token = ref.read(authProvider).token;
    final bytes = state.fileBytes;
    final name = state.fileName;
    if (token == null || bytes == null || name == null) return;

    state = state.copyWith(phase: TvTimeImportPhase.uploading);
    try {
      final id = await _api.upload(bytes: bytes, filename: name, token: token);
      state = state.copyWith(phase: TvTimeImportPhase.processing);
      _poll(id, token);
    } catch (_) {
      state = state.copyWith(
        phase: TvTimeImportPhase.failed,
        errorMessage: null,
      );
    }
  }

  void _poll(int id, String token) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      try {
        final status = await _api.getStatus(id, token: token);
        state = state.copyWith(summary: status.summary);
        if (status.status == 'done') {
          _pollTimer?.cancel();
          state = state.copyWith(phase: TvTimeImportPhase.done);
        } else if (status.status == 'failed') {
          _pollTimer?.cancel();
          state = state.copyWith(
            phase: TvTimeImportPhase.failed,
            errorMessage: status.errorMessage,
          );
        }
      } catch (_) {
        // transient network hiccup while polling - keep trying on the next
        // tick rather than failing the whole import over one missed poll
      }
    });
  }

  void reset() {
    _pollTimer?.cancel();
    state = const TvTimeImportState();
  }
}

final tvTimeImportProvider =
    NotifierProvider<TvTimeImportController, TvTimeImportState>(
      TvTimeImportController.new,
    );
