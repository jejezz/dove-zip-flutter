import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../core/cancel_token.dart';
import '../domain/entities/compress_progress.dart';
import '../domain/entities/compression_options.dart';
import '../domain/entities/archive_handle.dart';
import '../domain/entities/extract_conflict.dart';
import '../domain/entities/extract_destination_mode.dart';
import '../domain/entities/extract_progress.dart';
import '../domain/repositories/archive_reader.dart';
import '../domain/repositories/archive_writer.dart';
import 'usecases/create_archive.dart';
import 'usecases/extract_entries.dart';
import 'usecases/open_archive.dart';

/// [CreateArchive]·[OpenArchive]·[ExtractEntries]를 백그라운드 isolate에서
/// 돌린다. 지금의 압축·해제 코드는 파일 하나를 통째로 메모리에서 동기적으로
/// 인코딩해서, UI isolate에서 돌리면 그동안 화면도 타이머도 멈춘다 —
/// 탐색기 우클릭 메뉴의 작은 창(진행률·취소, PLAN.md 1.4)이 제때 뜨고
/// 반응하려면 작업을 밖으로 빼야 한다.
///
/// 함수 모양은 각 유스케이스의 `call`과 같다 — 테스트는 유스케이스를 그대로
/// 넘겨 isolate 없이 돌린다.
Future<void> compressInBackground({
  required List<Uri> sources,
  required Uri destination,
  required CompressionOptions options,
  CompressProgressCallback? onProgress,
  CancelToken? cancelToken,
}) async {
  try {
    await _runInIsolate<void>(
      _compressJob(sources, destination, options),
      onProgress: (p) => onProgress?.call(p as CompressProgress),
      cancelToken: cancelToken,
    );
  } on OperationCancelledException {
    // 취소하면 isolate를 죽이므로 쓰다 만 파일이 남을 수 있다 — 새로 만들던
    // 이름이라(quickCompressDestination) 지워도 된다.
    final file = File(destination.toFilePath());
    if (await file.exists()) await file.delete();
    rethrow;
  }
}

Future<ArchiveHandle> openArchiveInBackground(Uri location) =>
    _runInIsolate<ArchiveHandle>(_openJob(location));

Future<ExtractResult> extractInBackground({
  required ArchiveHandle handle,
  required ExtractDestinationMode mode,
  List<String>? entryPaths,
  String? password,
  Uri? userChosenFolder,
  required ConflictResolver onConflict,
  ExtractProgressCallback? onProgress,
  CancelToken? cancelToken,
}) =>
    _runInIsolate<ExtractResult>(
      _extractJob(handle, mode, entryPaths, password, userChosenFolder),
      onProgress: (p) => onProgress?.call(p as ExtractProgress),
      onConflict: onConflict,
      cancelToken: cancelToken,
    );

// isolate로 보내는 작업은 따로 만든다 — Dart 클로저는 같은 함수 안의 다른
// 클로저와 변수 묶음을 같이 들고 가서, 위 함수에서 바로 만들면 UI 쪽 콜백
// (onProgress 등, isolate로 보낼 수 없음)까지 딸려 간다.

Future<void> Function(_Worker) _compressJob(List<Uri> sources, Uri destination, CompressionOptions options) =>
    (worker) => const CreateArchive()(
          sources: sources,
          destination: destination,
          options: options,
          onProgress: worker.progress,
          cancelToken: worker.cancelToken,
        );

Future<ArchiveHandle> Function(_Worker) _openJob(Uri location) => (_) => const OpenArchive()(location);

Future<ExtractResult> Function(_Worker) _extractJob(
  ArchiveHandle handle,
  ExtractDestinationMode mode,
  List<String>? entryPaths,
  String? password,
  Uri? userChosenFolder,
) =>
    (worker) => const ExtractEntries()(
          handle: handle,
          mode: mode,
          entryPaths: entryPaths,
          password: password,
          userChosenFolder: userChosenFolder,
          onConflict: worker.askConflict,
          onProgress: worker.progress,
          cancelToken: worker.cancelToken,
        );

/// isolate 안에서 작업이 쓰는 것 — 진행률 보내기, 충돌 묻기, 취소 확인.
class _Worker {
  _Worker(this.cancelToken, this.progress, this.askConflict);

  final CancelToken cancelToken;
  final void Function(Object progress) progress;
  final ConflictResolver askConflict;
}

/// 취소한 뒤 이만큼 기다려도 isolate가 끝나지 않으면(큰 파일 하나를 인코딩하는
/// 중이면 취소 확인에 닿지 못한다) 죽인다.
const _killGrace = Duration(milliseconds: 300);

Future<R> _runInIsolate<R>(
  Future<R> Function(_Worker worker) job, {
  void Function(Object progress)? onProgress,
  ConflictResolver? onConflict,
  CancelToken? cancelToken,
}) async {
  cancelToken?.throwIfCancelled();
  final events = ReceivePort();
  final result = Completer<R>();
  SendPort? control;
  Timer? cancelWatch;
  Timer? killTimer;
  final isolate = await Isolate.spawn(_entry, _Start(events.sendPort, job), onExit: events.sendPort);

  void finish(void Function() complete) {
    if (result.isCompleted) return;
    complete();
    cancelWatch?.cancel();
    killTimer?.cancel();
    events.close();
  }

  cancelWatch = Timer.periodic(const Duration(milliseconds: 50), (timer) {
    if (cancelToken?.isCancelled != true) return;
    timer.cancel();
    control?.send(const _Cancel());
    killTimer = Timer(_killGrace, () {
      isolate.kill(priority: Isolate.immediate);
      finish(() => result.completeError(const OperationCancelledException()));
    });
  });

  events.listen((message) async {
    switch (message) {
      case SendPort port:
        control = port;
      case _Progress(:final value):
        onProgress?.call(value);
      case _ConflictAsk(:final id, :final conflict):
        final action = onConflict == null ? ConflictAction.cancel : await onConflict(conflict);
        control?.send(_ConflictAnswer(id, action));
      case _Done(:final value):
        finish(() => result.complete(value as R));
      case _Failed(:final error, :final stack):
        finish(() => result.completeError(error, StackTrace.fromString(stack)));
      case null:
        // onExit — 결과를 보내지 못하고 끝났다(죽였거나 보낼 수 없는 값).
        finish(() => result.completeError(
              cancelToken?.isCancelled == true
                  ? const OperationCancelledException()
                  : StateError('Background job exited without a result'),
            ));
    }
  });
  return result.future;
}

Future<void> _entry(_Start start) async {
  final control = ReceivePort();
  start.events.send(control.sendPort);
  final token = CancelToken();
  final pending = <int, Completer<ConflictAction>>{};
  var nextId = 0;
  control.listen((message) {
    switch (message) {
      case _Cancel():
        token.cancel();
        for (final c in pending.values) {
          c.complete(ConflictAction.cancel);
        }
        pending.clear();
      case _ConflictAnswer(:final id, :final action):
        pending.remove(id)?.complete(action);
    }
  });

  final worker = _Worker(
    token,
    (progress) => start.events.send(_Progress(progress)),
    (conflict) {
      final id = nextId++;
      final answer = Completer<ConflictAction>();
      pending[id] = answer;
      start.events.send(_ConflictAsk(id, conflict));
      return answer.future;
    },
  );

  try {
    start.events.send(_Done(await start.job(worker)));
  } catch (error, stack) {
    try {
      start.events.send(_Failed(error, stack.toString()));
    } catch (_) {
      // 보낼 수 없는 예외 객체 — 글로만 넘긴다.
      start.events.send(_Failed(StateError(error.toString()), stack.toString()));
    }
  }
  control.close();
}

class _Start {
  const _Start(this.events, this.job);

  final SendPort events;
  final Future<Object?> Function(_Worker worker) job;
}

class _Cancel {
  const _Cancel();
}

class _Progress {
  const _Progress(this.value);

  final Object value;
}

class _ConflictAsk {
  const _ConflictAsk(this.id, this.conflict);

  final int id;
  final ExtractConflict conflict;
}

class _ConflictAnswer {
  const _ConflictAnswer(this.id, this.action);

  final int id;
  final ConflictAction action;
}

class _Done {
  const _Done(this.value);

  final Object? value;
}

class _Failed {
  const _Failed(this.error, this.stack);

  final Object error;
  final String stack;
}
