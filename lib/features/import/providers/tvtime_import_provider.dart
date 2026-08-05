import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/tvtime_import_api.dart';

enum TvTimeImportPhase { idle, selected, uploading, processing, done, failed }

// TvTimeImportStatus.errorMessage (the backend's own error string, e.g. a
// PHP stack trace) is deliberately never carried into this state - it's a
// server-side implementation detail (already recorded in user_import.error
// for debugging), not something a user could act on. TvTimeImportPhase.
// failed alone is enough for _FailedView's generic "try again" message.
class TvTimeImportState {
  const TvTimeImportState({
    this.phase = TvTimeImportPhase.idle,
    this.fileName,
    this.fileSize,
    this.fileBytes,
    this.summary,
  });

  final TvTimeImportPhase phase;
  final String? fileName;
  final int? fileSize;
  final List<int>? fileBytes;
  final TvTimeImportSummary? summary;

  TvTimeImportState copyWith({
    TvTimeImportPhase? phase,
    String? fileName,
    int? fileSize,
    List<int>? fileBytes,
    TvTimeImportSummary? summary,
  }) {
    return TvTimeImportState(
      phase: phase ?? this.phase,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileBytes: fileBytes ?? this.fileBytes,
      summary: summary ?? this.summary,
    );
  }
}

class TvTimeImportController extends Notifier<TvTimeImportState> {
  // The delay *between* polls, not a fixed tick - each call to the status
  // endpoint also advances the job itself by one time-boxed batch server-
  // side (see Api\Controller\Import\TvTimeStatus's own docblock), which can
  // take up to ~45 real seconds when there's work to do. A plain
  // Timer.periodic would keep firing every 3s regardless, piling up many
  // overlapping in-flight requests against the same job - _poll() instead
  // waits for each response before scheduling the next one.
  static const _pollInterval = Duration(seconds: 3);

  late final TvTimeImportApi _api;
  bool _polling = false;

  @override
  TvTimeImportState build() {
    _api = TvTimeImportApi();
    ref.onDispose(() => _polling = false);
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
    _polling = false;
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
      _poll(id);
    } catch (_) {
      state = state.copyWith(phase: TvTimeImportPhase.failed);
    }
  }

  /// Called once when TvTimeImportScreen opens - this in-memory state
  /// doesn't survive the app process restarting (e.g. the phone killing a
  /// backgrounded app mid-import), so on a genuinely fresh state (idle,
  /// nothing already polling) it asks the server whether this user has an
  /// import it forgot about, and if so resumes right where the server
  /// left off. A no-op if the app already knows what's going on - either a
  /// real idle state (nothing to resume) or an import already being
  /// tracked from earlier this same session.
  Future<void> resumeIfInProgress() async {
    if (state.phase != TvTimeImportPhase.idle || _polling) return;
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      final current = await _api.getCurrent(token: token);
      final id = current?.id;
      if (current == null || id == null) return;
      if (current.status == 'done') {
        state = state.copyWith(
          phase: TvTimeImportPhase.done,
          summary: current.summary,
        );
      } else if (current.status == 'failed') {
        state = state.copyWith(phase: TvTimeImportPhase.failed);
      } else {
        state = state.copyWith(
          phase: TvTimeImportPhase.processing,
          summary: current.summary,
        );
        _poll(id);
      }
    } catch (_) {
      // couldn't reach the server to check - stay idle rather than show a
      // spurious error for what might just be a transient network hiccup
    }
  }

  /// [id]'s token is re-read fresh from authProvider on every tick, rather
  /// than captured once by the caller - a session that ends for any reason
  /// while this loop is running (logs out, token gets revoked) would
  /// otherwise keep being polled forever with the same now-dead token,
  /// each tick's 401 re-triggering decodeApiResponse's onAuthExpired ->
  /// logOut() again - a self-sustaining loop that logs the user right back
  /// out moments after any fresh login, since this same zombie poll never
  /// stopped running in the background. Confirmed empirically: exactly this
  /// happened live, hundreds of consecutive 401s against one job.
  Future<void> _poll(int id) async {
    _polling = true;
    while (_polling) {
      final token = ref.read(authProvider).token;
      if (token == null) {
        _polling = false;
        return;
      }
      try {
        final status = await _api.getStatus(id, token: token);
        if (!_polling) return;
        state = state.copyWith(summary: status.summary);
        if (status.status == 'done') {
          _polling = false;
          state = state.copyWith(phase: TvTimeImportPhase.done);
          return;
        } else if (status.status == 'failed') {
          _polling = false;
          state = state.copyWith(phase: TvTimeImportPhase.failed);
          return;
        }
      } catch (_) {
        // transient network hiccup while polling - keep trying on the next
        // tick rather than failing the whole import over one missed poll
      }
      if (!_polling) return;
      await Future.delayed(_pollInterval);
    }
  }

  void reset() {
    _polling = false;
    state = const TvTimeImportState();
  }
}

final tvTimeImportProvider =
    NotifierProvider<TvTimeImportController, TvTimeImportState>(
      TvTimeImportController.new,
    );
