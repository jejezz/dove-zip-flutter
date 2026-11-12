import 'dart:async';

import 'package:dove_zip/application/launch_request.dart';
import 'package:dove_zip/application/usecases/extract_entries.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/archive_handle.dart';
import 'package:dove_zip/domain/entities/compression_options.dart';
import 'package:dove_zip/domain/entities/extract_destination_mode.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:dove_zip/domain/repositories/archive_writer.dart';
import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/quick/quick_task_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 탐색기 우클릭 메뉴를 창 없이 처리하는 화면 — 언제 창이 보이고 언제 끝나는지.
void main() {
  late List<bool> shows; // showWindow 호출마다 prompt 값
  late int exits;

  setUp(() {
    shows = [];
    exits = 0;
  });

  Future<void> pump(
    WidgetTester tester,
    LaunchRequest request, {
    CompressJob? compress,
    ExtractJob? extract,
  }) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: QuickTaskScreen(
        request: request,
        showWindow: ({bool prompt = false}) async => shows.add(prompt),
        exitApp: () => exits++,
        revealAfter: const Duration(seconds: 1),
        createArchive: compress ?? _noCompress,
        openArchive: (uri) async => ArchiveHandle(location: uri, format: ArchiveFormat.zip, entries: const []),
        extractEntries: extract ?? _noExtract,
      ),
    ));
    await tester.pump(); // 첫 프레임 뒤 작업 시작
  }

  const compressRequest = LaunchRequest(LaunchAction.compressHere, [r'C:\work\a.txt']);
  const extractRequest = LaunchRequest(LaunchAction.extractHere, [r'C:\work\a.zip']);

  testWidgets('빨리 끝나면 창을 한 번도 보이지 않고 끝낸다', (tester) async {
    await pump(tester, compressRequest);
    await tester.pump(const Duration(seconds: 2));
    expect(exits, 1);
    expect(shows, isEmpty);
  });

  testWidgets('1초가 넘게 걸리면 작은 창을 보이고, 끝나면 스스로 닫는다', (tester) async {
    final job = Completer<void>();
    await pump(tester, compressRequest, compress: _compressUntil(job));

    await tester.pump(const Duration(milliseconds: 900));
    expect(shows, isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    expect(shows, [false]);
    expect(find.text('압축 생성 중...'), findsOneWidget);

    job.complete();
    await tester.pump();
    expect(exits, 1);
  });

  testWidgets('취소를 누르면 작업에 취소를 알리고 조용히 끝낸다', (tester) async {
    CancelToken? token;
    final job = Completer<void>();
    await pump(tester, compressRequest, compress: ({
      required sources,
      required destination,
      required options,
      onProgress,
      cancelToken,
    }) async {
      token = cancelToken;
      await job.future;
      cancelToken!.throwIfCancelled();
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('취소'));
    expect(token!.isCancelled, isTrue);
    job.complete();
    await tester.pump();
    expect(exits, 1);
  });

  testWidgets('실패하면 창을 보이고 이유를 알린다 — 닫기를 눌러야 끝난다', (tester) async {
    await pump(tester, compressRequest, compress: ({
      required sources,
      required destination,
      required options,
      onProgress,
      cancelToken,
    }) async =>
        throw StateError('disk full'));
    await tester.pump();

    expect(shows, isNotEmpty);
    expect(find.textContaining('압축 생성 실패'), findsOneWidget);
    expect(exits, 0);
    await tester.tap(find.text('닫기'));
    expect(exits, 1);
  });

  testWidgets('비밀번호가 필요하면 창을 키워 묻고, 받은 비밀번호로 다시 푼다', (tester) async {
    final passwords = <String?>[];
    await pump(tester, extractRequest, extract: ({
      required handle,
      required mode,
      entryPaths,
      password,
      userChosenFolder,
      required onConflict,
      onProgress,
      cancelToken,
    }) async {
      passwords.add(password);
      expect(mode, ExtractDestinationMode.smart);
      if (password == null) throw const ArchivePasswordRequiredException('secret.txt');
      return ExtractResult(destination: Uri.directory(r'C:\work'), failures: const []);
    });
    // 진행 막대가 계속 움직여 settle되지 않는다 — 대화상자 애니메이션만큼 넘긴다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(shows, contains(true));
    await tester.enterText(find.byType(TextField), 'pw');
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(passwords, [null, 'pw']);
    expect(exits, 1);
  });

  testWidgets('압축파일이 아닌 항목은 건너뛴다', (tester) async {
    var calls = 0;
    await pump(
      tester,
      const LaunchRequest(LaunchAction.extractHere, [r'C:\work\notes.txt']),
      extract: ({
        required handle,
        required mode,
        entryPaths,
        password,
        userChosenFolder,
        required onConflict,
        onProgress,
        cancelToken,
      }) async {
        calls++;
        return ExtractResult(destination: Uri.directory(r'C:\work'), failures: const []);
      },
    );
    await tester.pump();
    expect(calls, 0);
    expect(exits, 1);
  });
}

Future<void> _noCompress({
  required List<Uri> sources,
  required Uri destination,
  required CompressionOptions options,
  CompressProgressCallback? onProgress,
  CancelToken? cancelToken,
}) async {}

Future<ExtractResult> _noExtract({
  required ArchiveHandle handle,
  required ExtractDestinationMode mode,
  List<String>? entryPaths,
  String? password,
  Uri? userChosenFolder,
  required ConflictResolver onConflict,
  ExtractProgressCallback? onProgress,
  CancelToken? cancelToken,
}) async =>
    ExtractResult(destination: Uri.directory(r'C:\work'), failures: const []);

CompressJob _compressUntil(Completer<void> done) => ({
      required sources,
      required destination,
      required options,
      onProgress,
      cancelToken,
    }) =>
        done.future;
