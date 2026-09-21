# Dove Zip — 아키텍처 설계 (v0.1)

[PLAN.md](PLAN.md)의 기능 리스트(P0/P1/P2)와 3장 포맷 매트릭스를 기준으로 한 초안
아키텍처. UI 위젯 디테일은 제외하고 네이티브 압축 엔진 연동/상태관리/데이터 흐름에
집중한다. daylight-commander-flutter의 레이어 구조·작업 큐 패턴을 최대한 계승하되,
이 앱만의 핵심 과제인 **네이티브 압축 백엔드(libarchive + Rust) 연동**을 새로
설계한다.

## 1. 레이어 구조

```
presentation/   화면, 다이얼로그, Riverpod 컨트롤러(StateNotifier/AsyncNotifier)
application/    유스케이스 (OpenArchive, ListEntries, ExtractEntries, CreateArchive ...)
domain/         엔티티(ArchiveEntry, ArchiveFormat, CompressionOptions), Backend 인터페이스
data/           FormatRegistry, 영속성(설정/최근 파일 목록)
native/         (신규) dart:ffi ↔ libarchive 바인딩, flutter_rust_bridge ↔ Rust 크레이트
core/           OperationQueue, CancelToken, 에러 타입 — daylight와 공용 개념 계승
```

의존 방향은 `presentation → application → domain ← data`이며, `native/`는 `data/`
아래에서만 참조된다(도메인/유스케이스는 백엔드가 FFI인지 Rust인지 모른다). daylight의
`domain ← data`(Repository 패턴) 원칙을 그대로 유지한다.

## 2. 상태관리: Riverpod

daylight와 동일하게 채택(검증된 패턴 재사용). 주요 Provider 구성(예시):

- `archiveBrowserProvider(Uri archiveLocation)` — 열린 압축파일의 엔트리 트리 상태
  (`AsyncNotifier<ArchiveBrowserState>`)
  > **구현 후 수정**: 이 앱은 한 번에 압축파일을 하나만 여는 단일 창 구조라,
  > `OpenArchive`가 이미 엔트리 전체를 한 번에 다 읽어 온 뒤(`ArchiveHandle`)
  > `ArchiveBrowserScreen`에 생성자로 넘겨준다. 화면 안에서의 폴더 이동은
  > 순수 인메모리 필터링(8장 `childrenOf`)이라 별도 비동기 로딩 상태가
  > 필요 없어서, 전역 Riverpod family provider 대신 `StatefulWidget`의 로컬
  > 상태(`_currentPath`)로 충분했다 — daylight가 `FileSystemRepository`
  > 추상화를 "실제로는 더 얇게" 구현했던 것과 같은 종류의 판단(4장 참고).
- `operationQueueProvider` — 진행 중인 압축/해제 작업 목록 (daylight의
  `operationQueueProvider`와 동일 개념, Job 종류만 `Compress`/`Extract`로 확장)
- `recentArchivesProvider`, `settingsProvider` — 영속 데이터
- `formatRegistryProvider` — 3장 매트릭스를 코드화한 정적 레지스트리 (읽기 전용,
  Provider로 노출하는 이유는 UI가 "이 포맷은 생성 가능한가"를 매번 질의하기 위함)

## 3. 핵심 엔티티

```dart
enum ArchiveFormat {
  zip, tar, tarGz, tarBz2, tarXz, tarZst, gzip, bzip2, xz, zstd,
  sevenZip, lz4, brotli,       // 생성+해제 대상 (P0~P2)
  rar,                          // 해제 전용 (RAR4/RAR5)
  iso9660, cab, arj, lha, cpio, ar, xar, warc, // 해제 전용, libarchive 커버리지
}

class ArchiveEntry {
  final String pathInArchive;   // posix 스타일, "dir/sub/file.txt"
  final bool isDirectory;
  final int? uncompressedSize;
  final int? compressedSize;
  final DateTime? modifiedAt;
  final bool isEncrypted;       // 항목 단위 암호화 표시(zip은 항목별, 7z는 전체 헤더 암호화 가능)
}

class ArchiveHandle {
  final Uri location;           // file:///path/to.ext
  final ArchiveFormat format;
  final List<ArchiveEntry> entries; // 플랫 리스트 — UI가 pathInArchive의 '/'로
                                     // 가상 폴더 트리를 구성 (daylight
                                     // ArchiveViewerScreen과 동일 패턴, 4.3 참고)
}

class CompressionOptions {
  final ArchiveFormat format;   // FormatRegistry.canWrite(format) == true 인 것만 허용
  final CompressionLevel level; // store / fast / normal / max
  final String? password;       // zip(AES-256)/7z(AES-256)만 유효, 그 외 null 고정
  final int? splitVolumeBytes;  // null = 분할 안 함
}

enum ExtractDestinationMode { here, smart, chooseFolder } // 5장 참고 — 이 앱의 핵심 편의 기능

class ExtractionOptions {
  final ExtractDestinationMode mode;
  final Uri? chosenDestination;   // mode == chooseFolder일 때만 사용
  final List<String>? entryPaths; // null = 전체 해제
  final String? password;
  final ConflictResolver onConflict; // daylight의 ConflictDialog 재사용
}
```

`FileEntry`(daylight)와 달리 `ArchiveEntry`는 압축파일 **내부**의 항목이라 실제
파일시스템 URI를 갖지 않는다 — `ArchiveHandle.location` + `pathInArchive` 조합으로만
식별된다.

## 4. 포맷 레지스트리 & 백엔드 추상화

PLAN.md 3장 매트릭스를 코드로 고정하는 정적 테이블이 이 앱의 중심축이다. UI(포맷
선택 드롭다운에 "생성" 가능한 것만 노출)와 `application` 레이어(어느 백엔드로
라우팅할지) 양쪽이 이 하나의 소스를 참조한다.

```dart
class FormatCapability {
  final ArchiveFormat format;
  final bool canRead;
  final bool canWrite;
  final BackendKind readBackend;      // libarchive | rustNative
  final BackendKind? writeBackend;    // null이면 해제 전용
}

enum BackendKind { libarchive, rustNative }

abstract class ArchiveReader {
  bool supports(ArchiveFormat format);
  Future<List<ArchiveEntry>> listEntries(Uri archive, {String? password});
  Stream<ExtractProgress> extract(Uri archive, ExtractionOptions options);
}

abstract class ArchiveWriter {
  bool supports(ArchiveFormat format);
  Stream<CompressProgress> compress(
      List<Uri> sources, Uri destination, CompressionOptions options);
}
```

- `LibarchiveReader implements ArchiveReader` — `native/libarchive_bindings.dart`
  (dart:ffi) 위에서 동작. zip/tar 계열/gzip/bzip2/xz/zstd 필터 + **rar(읽기)** +
  iso/cab/arj/lha/cpio/ar/xar/warc 전부 이 하나의 구현체가 담당(6.4 리스크 검증 후
  일부는 P2로 순연 가능)
- `RustArchiveWriter implements ArchiveWriter` — `native/rust_bridge/`
  (flutter_rust_bridge) 위에서 동작. zip(AES 포함)/tar 계열/gzip/bzip2/xz/zstd/7z/
  lz4/brotli 생성 담당
- `RustArchiveWriter`는 자신이 만든 포맷의 **해제도 동일 크레이트로 처리 가능**하지만,
  MVP는 "해제는 항상 libarchive 우선, 실패 시 Rust 백엔드로 폴백"을 기본 정책으로
  둔다 — libarchive가 압축 해제 쪽에서 훨씬 널리 검증돼 있기 때문(6.4 확정 필요 항목)
- `CompositeArchiveService`(application)가 `FormatRegistry`를 보고 리더/라이터를
  선택 — UI/유스케이스는 백엔드를 모른다

**비목표(스코프 축소)**: 기존 압축파일에 파일을 추가/수정하는 "제자리 업데이트"는
지원하지 않는다 — 압축 생성은 항상 소스 목록 전체로 새로 만든다(대부분의 포맷이
append를 지원하지 않거나 지원해도 위험이 커서 daylight의 "폴더 통째 전송은 재귀
헬퍼에 위임" 스코프 축소와 같은 판단).

> **구현 후 수정**: `LibarchiveReader`/`RustArchiveWriter`는 아직 없고, 그
> 자리를 임시 Dart 백엔드(`DartArchiveReader`/`DartArchiveWriter`, 6.1 참고)가
> 대신하고 있다. `archive` 패키지에 이미 코덱이 있던 zip/tar/tar.gz/tar.bz2/
> tar.xz/gzip/bzip2/xz는 실제로 동작한다 — tar 계열은 zip과 같은
> `Archive`/`ArchiveFile` 모델을 쓰기 때문에 엔트리 매핑·해제 루프·충돌
> 처리 로직을 그대로 공유하고, 바이트를 어떻게 인/디코딩할지만 포맷별로
> 갈라진다. gzip/bzip2/xz(파일 하나만 감싸는 포맷)는 압축 시 소스가
> 정확히 파일 하나가 아니면 명확한 에러를 던진다.
>
> 7z/RAR는 `archive` 패키지의 `Archive`/`ArchiveFile` 모델에 맞지 않아
> (엔트리 내용을 지연 스트리밍하는 별도 API) 이 코덱 스위치가 아니라
> `_openKoniReader`/`_compressSevenZip`이라는 완전히 다른 경로를 탄다 —
> [zenbaku/koni_archive](https://github.com/zenbaku/koni_archive)의
> `koni_sevenz`/`koni_rar`(둘 다 순수 Dart, MIT)를 쓴다. 7z는 읽기/쓰기
> (AES-256 포함) 모두, RAR는 읽기만(RAR5 전체, RAR4는 옛 압축 방식 하나만
> 예외) 지원한다 — 실제 `7z`(p7zip) CLI 및 진짜 RAR 도구로 만든 픽스처와
> 교차 검증했다(`dart_archive_writer_sevenzip_test.dart`,
> `dart_archive_reader_rar_test.dart`). 해제 루프의 충돌/진행률/취소
> 처리는 `_extractEntries` 하나로 두 백엔드가 공유한다. **zstd/tar.zst만
> 여전히 막혀 있다** — koni 생태계의 zstd 코덱이 아직 pub.dev에 배포되지
> 않았다(PLAN.md 3장 참고).

> **구현 후 수정 — 분할 압축(PLAN.md 1.2/1.3)**: 7z/RAR/zip의 진짜
> 멀티볼륨 스펙은 여전히 libarchive 없이는 읽을 수 없다. 대신 DoveZip은
> 자체적인 "완성된 단일 압축파일을 고정 크기로 잘라 붙이는" 스킴을 쓴다 —
> `DartArchiveWriter`가 `_encodeArchive`/단일 파일 인코딩 결과 바이트를
> 만든 뒤, `splitVolumeBytes`가 있으면 그 크기로 잘라 `이름.zip.001`,
> `이름.zip.002`, ... 로 쓴다(원래 이름의 파일 자체는 만들지 않음).
> `DartArchiveReader`는 열려는 파일 이름이 `FormatRegistry.isSplitVolumePart`에
> 걸리면 같은 폴더에서 `split_volume_locator.dart`의 `findSplitVolumeParts`로
> 모든 조각을 찾아 번호순으로 이어붙인 뒤 평소처럼 디코딩한다 — 어떤 조각을
> 열어도 동일하게 동작하고, 중간 조각이 비면 명확한 에러를 던진다.
> `FormatRegistry.detectFromFileName`/`stripKnownExtension` 둘 다 먼저
> 번호 접미사를 뗀 뒤 판별하므로, 상위 유스케이스(`OpenArchive`,
> `resolveExtractDestination`)는 분할 여부를 몰라도 그대로 동작한다.
> **호환성 한계**: DoveZip이 만든 조각은 DoveZip만 다시 열 수 있다 —
> 7-Zip/WinRAR 등 다른 프로그램이 만든 멀티볼륨을 읽거나, DoveZip 조각을
> 다른 프로그램에서 여는 것은 지원하지 않는다(네이티브 백엔드 도입 후
> 재검토 대상으로 남겨둠).

## 5. 빠른 해제 (Extract 3-모드) 위치 결정 로직

PLAN.md 1.2의 "가장 중요한 편의 기능" — 압축 해제 시 목적지를 계산하는 로직을
`application` 레이어의 순수 함수 하나로 분리해, **앱 내부 UI 버튼**과 (P2로 예정된)
**OS 컨텍스트 메뉴 확장** 양쪽에서 완전히 동일하게 재사용할 수 있게 한다 — "편의성"
로직이 두 곳에 따로 구현돼 나중에 어긋나는 일을 막는다.

```dart
/// 압축파일 경로와 모드로부터 실제 해제 대상 폴더를 계산한다.
/// 파일시스템에 접근하지 않는 순수 함수라 유닛 테스트가 쉽다.
Uri resolveExtractDestination({
  required Uri archiveLocation,
  required ExtractDestinationMode mode,
  required List<ArchiveEntry> entries, // smart 모드의 단일폴더 감지에 필요
  Uri? userChosenFolder,               // chooseFolder 모드일 때만 사용
}) {
  final archiveDir = archiveLocation.resolve('.');       // 압축파일이 있는 폴더
  final baseName = basenameWithoutArchiveExtensions(archiveLocation); // "photos.tar.gz" → "photos"

  switch (mode) {
    case ExtractDestinationMode.here:
      return archiveDir;

    case ExtractDestinationMode.smart:
      if (hasSingleTopLevelFolderNamed(entries, baseName)) {
        // 압축파일 내부가 이미 "photos/" 폴더 하나로만 구성돼 있으면 그대로 사용
        return archiveDir;
      }
      return archiveDir.resolve('$baseName/');

    case ExtractDestinationMode.chooseFolder:
      return userChosenFolder!;
  }
}
```

- **`basenameWithoutArchiveExtensions`**: `.tar.gz`/`.tar.bz2`/`.tar.xz`/
  `.tar.zst`처럼 **이중 확장자**를 한 번에 제거해야 한다 — `path` 패키지의
  `basenameWithoutExtension`은 마지막 확장자 하나만 제거해서 `photos.tar.gz` →
  `photos.tar`로 남는 문제가 있어 별도 유틸이 필요하다. `FormatRegistry`(4장)가
  이미 포맷별 확장자 목록을 갖고 있으므로 이를 재사용해 매칭한다.
- **`hasSingleTopLevelFolderNamed`**: 엔트리 목록의 최상위(`pathInArchive`의 `/`
  기준 첫 세그먼트)가 전부 동일한 폴더 이름 하나뿐인지 확인한다 — WinRAR/Keka가
  하는 "이미 폴더로 감싸져 있으면 이중 중첩 안 함" 관례를 재현. 이름이 다르면
  (대소문자 차이 포함) 항상 새 폴더를 만드는 쪽(엄격 매칭)이 안전하다.
- **폴더 이름 충돌**: `smart` 모드가 만들 폴더가 이미 존재하고 비어있지 않으면,
  자동으로 `photos (1)/`처럼 이름을 바꾸지 않고 6장의 표준 충돌 처리 플로우
  (덮어쓰기/건너뛰기/이름변경/모두 적용)를 그대로 태운다 — daylight와 동일하게
  "위치를 조용히 바꾸기보다 항상 사용자에게 확인" 원칙을 유지한다.
- `chooseFolder`를 고를 때 뜨는 폴더 선택 다이얼로그만 `presentation` 레이어에서
  UI로 처리하고, 그 결과(`userChosenFolder`)를 이 함수에 넘긴다. 나머지 두 모드는
  사용자 입력 없이 즉시 계산되므로 다이얼로그 없이 바로 해제가 시작된다(이게
  "여기에"/"알아서" 모드가 실제로 빠르게 느껴지는 이유).
- 기본값은 PLAN.md 1.2와 동일하게 **`smart`** — 마지막으로 고른 모드를 기억하는
  기능(P1)은 `settingsProvider`에 `lastExtractMode`로 저장.

## 6. 네이티브 브리지 상세 설계

### 6.1 libarchive (dart:ffi)
- libarchive의 C API(`archive_read_*`/`archive_write_*`)는 콜백 기반 스트리밍
  구조라, Dart FFI가 직접 콜백을 받기 번거로움 → **얇은 C 셰임 레이어**
  (`native/shim/dove_zip_archive.c`, 필요시 C++로 진행률/취소 로직만 캡슐화)를 두고
  Dart는 이 셰임이 노출하는 단순한 함수(엔트리 목록 얻기, 엔트리 하나 추출, 취소
  플래그 설정)만 호출한다.
- **취소**: 셰임이 `atomic<int>* cancelFlag`를 폴링하며 엔트리 경계마다 체크 후
  중단 — libarchive 콜백 모델 특성상 **취소 단위는 파일(엔트리) 단위**이지 바이트
  단위가 아니다(daylight의 파일 작업 큐도 파일 경계 취소라 일관된 정책).
- **블로킹 회피**: FFI 호출 자체는 동기(sync)이므로 반드시 **Dart Isolate**(또는
  `Isolate.run`) 안에서 실행해 UI 스레드를 막지 않는다. 7장의 작업 큐가 이 Isolate
  스폰을 담당.
- 라이브러리 실체: macOS/Linux는 시스템 제공 버전과 앱 번들에 정적 링크한 버전이
  다를 수 있어 **항상 앱에 특정 버전을 벤더링**해 플랫폼 간 동작 일관성을 보장한다
  (12장 빌드 파이프라인).

### 6.2 Rust 크레이트 (flutter_rust_bridge)
- 후보 크레이트: `zip`(AES 암호화 지원), `sevenz-rust2`(7z 읽기/쓰기), `flate2`
  (gzip/deflate), `xz2`/`liblzma-sys`(xz), `zstd`, `lz4_flex`, `brotli`, `tar`
- `flutter_rust_bridge_codegen`으로 Dart 바인딩을 자동 생성 — Rust 쪽은 이미
  비동기(async) 스트림을 자연스럽게 Dart `Stream`으로 노출하므로, libarchive처럼
  수동 Isolate 관리가 필요 없다(브리지가 내부적으로 별도 스레드에서 실행).
- **취소**: 브리지가 지원하는 `CancelHandle`(또는 채널 기반 취소 신호)을 Rust 함수
  시그니처에 파라미터로 넘겨 파일 단위로 체크 — libarchive 쪽과 동일한 취소 단위
  정책을 유지해 UX 일관성 확보.

### 6.3 진행률/취소 신호 통일
두 백엔드의 진행률 이벤트를 공통 타입으로 정규화한다:

```dart
sealed class ArchiveProgressEvent {}
class EntryStarted extends ArchiveProgressEvent { final String path; }
class EntryDone extends ArchiveProgressEvent { final String path; final int bytesWritten; }
class ConflictDetected extends ArchiveProgressEvent { final String path; } // 해제 시
class Failed extends ArchiveProgressEvent { final Object error; }
```

`application` 레이어는 어느 백엔드가 이벤트를 보냈는지 신경 쓰지 않고 이 타입만
소비 — daylight의 `TransferProgress`/`ConflictEvent` 패턴 계승.

> **구현 후 수정**: `DartArchiveReader.extractAll`은 위 `Stream<ArchiveProgressEvent>`
> 대신 daylight의 `FileOperationService`와 완전히 동일한 **콜백 3종**
> (`ConflictResolver = Future<ConflictAction> Function(ExtractConflict)`,
> `ExtractProgressCallback = void Function(ExtractProgress)`, `CancelToken`)으로
> 구현했다. 지금은 실제 Isolate/포트 통신이 없는 단일 async 함수라 스트림+포트
> 왕복보다 `Future` 콜백이 훨씬 단순하고, daylight에서 이미 검증된 패턴이라
> 신뢰도도 높다. libarchive/Rust 백엔드가 진짜 Isolate로 옮겨가는 시점(7장)에
> 이 콜백들을 스트림 기반으로 다시 감쌀지 재검토한다. `ConflictAction` enum은
> `domain/entities/extract_conflict.dart`, `CancelToken`은 `core/cancel_token.dart`.

### 6.4 확정 필요 항목 (PoC 우선순위, PLAN.md 4.3과 연결)
1. Windows에서 libarchive 정적/동적 빌드 및 앱 번들 동봉 방식
2. 3개 데스크톱 플랫폼에서 `flutter_rust_bridge` 크로스컴파일 파이프라인
3. zip처럼 두 백엔드가 겹치는 포맷의 해제 우선순위(위 4장 정책의 실측 검증 —
   libarchive가 특정 zip 변종(zip64, 특이 압축방식)에서 실패하면 Rust로 폴백)
4. 대용량 아카이브에서 엔트리 목록을 메모리에 전부 올리지 않고 스트리밍하는 방식
   (daylight의 zip 미리보기가 중앙 디렉터리만 읽던 것과 동일한 최적화 필요)

## 7. 압축/해제 작업 큐 — 진행률·취소·충돌 처리

daylight의 `OperationQueue`(Isolate + Port 스트리밍) 패턴을 그대로 계승하되, Job
종류가 `CopyJob`/`MoveJob` 대신 `CompressJob`/`ExtractJob`이다.

```
UI ── enqueue(ExtractJob) ──▶ OperationQueue
                                 │ spawn Isolate (libarchive 경로) 또는
                                 │ flutter_rust_bridge 스트림 구독 (Rust 경로)
                                 ▼
                        ┌─────────────────┐
                        │ extract worker  │──▶ ArchiveProgressEvent 스트림
                        └─────────────────┘──▶ ConflictDetected ─┐
                                 ▲                                ▼
                                 └────── ConflictResolution ◀── UI 다이얼로그
```

- **충돌 처리**: 해제 대상 폴더에 동일 이름 파일이 있으면 daylight와 동일한
  덮어쓰기/건너뛰기/이름변경/모두 적용 다이얼로그(`ConflictDialog` 재사용)
- **큐 정책**: 압축/해제는 CPU 바운드 작업이라 기본 **순차 실행**(동시 1개) —
  여러 작업을 동시에 돌리면 오히려 각 작업이 느려짐(네트워크 병목이 아닌 CPU 병목)
- `OperationQueueProvider`가 Job 상태(`queued/running/error/done/cancelled`)를
  노출, 하단 상태 패널에서 구독(daylight와 동일 UI 패턴)

## 8. 압축파일 탐색(브라우저) 구조

daylight의 `ArchiveViewerScreen`(zip을 풀지 않고 목록만 읽어 폴더 트리처럼 보여주는
기능)을 이 앱의 메인 화면으로 승격한다.

```dart
class ArchiveBrowserState {
  final ArchiveHandle handle;
  final String currentVirtualPath; // 트리 내 현재 위치, ""이면 루트
  final Set<String> selection;     // 선택된 pathInArchive 집합
}
```

- `ArchiveHandle.entries`(플랫 리스트)를 `pathInArchive`의 `/`로 분해해 가상 폴더
  트리를 구성 — 실제 폴더 엔트리가 압축파일에 없어도(일부 tar/zip은 디렉터리
  엔트리를 생략) 파일 경로로부터 폴더를 유추해 만든다.
- ".." 항목으로 상위 이동, 폴더 진입은 인메모리 필터링(entries를 다시 읽지 않음)
- 파일 항목을 열면(더블클릭/F3) 그 항목 하나만 임시 폴더로 추출한 뒤 9장의
  뷰어로 전달 — 압축파일 전체는 절대 풀지 않는다(daylight와 동일 원칙)

## 9. 미리보기 뷰어 확장 구조

daylight의 `FileViewer` 추상화를 그대로 이식한다.

```dart
abstract class FileViewer {
  bool canHandle(ArchiveEntry entry);
  Widget build(BuildContext context, File extractedTempFile);
}
```

- P0: 텍스트(UTF-8→Latin-1 폴백), 이미지(jpg/png/gif/webp) — **구현 완료**
- P1: Hex 덤프(256KB 미리보기 상한 — daylight와 동일 기준)
- P2: PDF(`pdfrx`), 오디오/비디오(`media_kit`) — daylight에서 이미 검증된 패키지
  그대로 재사용

> **구현 후 수정**: `canHandle`의 인자를 `ArchiveEntry` 전체가 아니라
> `String extension`(소문자, 점 없이)으로 단순화했다 — daylight의
> `ViewerScreen`도 실제로는 확장자 화이트리스트만으로 판정하지, 엔트리의
> 다른 필드(크기·수정일 등)는 쓰지 않는다. 압축파일 항목 하나를 임시
> 폴더로 꺼내는 것은 `ArchiveReader.extractEntryToTemp`(신규 메서드)가
> 맡고, 그 결과를 `PreviewArchiveEntry` 유스케이스가 `EntryViewerScreen`에
> 넘긴다 — 매번 새 임시 폴더를 쓰므로 daylight의 zip 미리보기와 달리
> 이름 충돌/정리 로직이 필요 없다.
- `ViewerRegistry`에 등록, 확장자 기준 매칭 → 매칭 실패 시 "OS 기본 앱으로 열기"

## 10. 영속성

| 데이터 | 저장 방식 |
|---|---|
| 앱 설정(테마, 언어, 기본 압축 레벨/포맷, `lastExtractMode`) | `shared_preferences` |
| 최근 연 압축파일 목록 | `shared_preferences` (경로 문자열 리스트, daylight의 "최근 방문 폴더"와 동일 패턴) |
| 압축/해제 비밀번호 | **저장하지 않음** — 세션 중에만 메모리에 유지, 앱 종료 시 소멸 (daylight가 네트워크 드라이브 비밀번호를 저장하지 않는 원칙과 동일) |

## 11. 플랫폼별 고려사항

- **macOS**: App Sandbox 비활성화 여부는 daylight와 같은 이유(임의 경로 접근,
  Finder에서 드래그된 임의 파일 압축)로 **비활성화 유지**가 유력 — 단, 이 앱은
  파일 매니저보다 접근 범위가 좁을 수 있어(사용자가 명시적으로 선택/드롭한 파일만
  다룸) Sandbox + 보안 스코프 북마크(security-scoped bookmark)로 App Store 배포
  가능성을 열어두는 것도 검토 가치 있음 — PoC 단계에서 확정
- **Windows**: libarchive 동적 라이브러리(.dll) 벤더링 필수(6.1/6.4 참고), 확장자
  연결(`.zip`/`.7z`/`.tar` 등 "연결 프로그램"에 Dove Zip 등록)은 P2, 설치 프로그램이
  레지스트리에 등록
- **Linux**: 배포판별 압축 유틸리티(예: `unrar` 비패키지 배포판)와 무관하게 동작해야
  하므로 libarchive를 반드시 정적 링크 또는 AppImage/Flatpak 내부에 동봉,
  `.desktop` 파일의 MIME 타입 연결(`application/zip` 등)은 P2

## 12. 빌드 파이프라인 (네이티브 라이브러리 벤더링)

- libarchive: 플랫폼별 CI(GitHub Actions macos-latest/windows-latest/
  ubuntu-latest)에서 소스 빌드 → `macos/`, `windows/`, `linux/` 각 러너 디렉터리에
  사전 빌드된 바이너리로 커밋(또는 릴리스 아티팩트로 다운로드 스크립트 실행) —
  daylight가 Flutter 표준 스캐폴드만 썼던 것과 달리 이 앱은 네이티브 빌드 스텝이
  CI에 추가된다
- Rust: `flutter_rust_bridge_codegen`이 생성한 바인딩 + `cargo build --release`
  결과물(각 플랫폼 타겟 트리플)을 동일한 방식으로 벤더링
- 개발 중(로컬 `flutter run`)에는 사전 빌드된 바이너리를 그대로 쓰거나, Rust는
  `cargo build`를 `flutter run` 전 단계에 후킹(Makefile/스크립트)해 자동화

## 13. 제안 패키지 (초안)

- 상태관리: `flutter_riverpod` (daylight와 동일)
- 네이티브 브리지: `flutter_rust_bridge`, `ffi`(dart:ffi 보조)
- 드래그앤드롭(OS → 앱): `desktop_drop` (daylight에서 검증 완료된 패키지 재사용)
- OS 네이티브 파일/폴더 선택 다이얼로그: `file_selector` (flutter.dev 공식 —
  "열기", "원하는 곳에 압축 해제", 압축 생성 시 저장 위치 선택에 사용)
- 커스텀 타이틀바/창 제어: `window_manager`
- 파일 유형 아이콘: `flutter_svg` + daylight의 icons8 SVG 자산 재사용
- 경로 처리: `path`
- 다국어: `flutter_localizations` + `intl` + `gen-l10n`
- PDF/미디어(P2): `pdfrx`, `media_kit`(+`media_kit_video`/`media_kit_libs_video`)

## 14. 테스트 전략

- `domain`/`application`: 순수 Dart 유닛 테스트
- **`resolveExtractDestination`(5장) 유닛 테스트**: 3모드 × (단일 최상위 폴더 있음/
  없음) × (이중 확장자 포함 파일명) 조합을 표로 검증 — 파일시스템 접근이 없는
  순수 함수라 가장 저렴하게 신뢰도를 높일 수 있는 지점이자, "편의성"이라는 핵심
  가치가 실제로 맞게 동작하는지 보장하는 테스트라 최우선 작성 대상
- **포맷별 라운드트립 테스트가 핵심**: 각 `canWrite` 포맷에 대해 "샘플 파일 압축 →
  같은 백엔드로 해제 → 원본과 바이트 동일성 비교"를 자동화. `canRead`만 되는
  포맷(rar 등)은 고정된 샘플 아카이브(리포지토리에 fixture로 포함)를 해제해
  기대 목록/내용과 비교
- libarchive FFI 바인딩은 플랫폼별로 동작이 미묘하게 다를 수 있어 **3개 OS 모두
  CI에서 라운드트립 테스트를 돌린다**(daylight가 FTP/SFTP/WebDAV를 실제 로컬
  서버로 통합 테스트했던 것과 같은 이유 — 목(mock)만으로는 신뢰할 수 없는 영역)
- 대용량 파일(예: 1GB급) 압축/해제 취소 테스트 — 파일 경계 취소가 실제로 중간에
  멈추는지, 취소 후 임시 파일이 정리되는지 확인

## 다음 단계
PLAN.md 7장과 동일 — 이 문서 검토 후 6.4의 네이티브 백엔드 PoC(특히 Windows
libarchive 빌드)를 최우선으로 진행하고, 결과에 따라 4장 백엔드 라우팅 정책을
확정한다. 진행 상태 추적은 [PLAN.md](PLAN.md)가 맡는다(이 문서는 설계 근거·결정
기록용).
