# Dove Zip — 기획서 (v0.1)

## 개요
광고·팝업·인앱결제 유도로 점철된 상용/셰어웨어 압축 프로그램(WinRAR류) 대신 쓸,
**직접 만들어 쓰는 무료 올인원 압축/해제 유틸리티**를 Flutter로 구현한다.
지원 플랫폼은 **Windows, macOS, Linux (데스크톱 전용)**, 모바일은 대상 아님.

같은 제작자의 [daylight-commander-flutter](../daylight-commander-flutter)와
**동일한 비주얼 테마**(`AppColors`/`AppRadius`/`AppTheme`, 라이트/다크 동등 지원)를
그대로 이식하고, 파일 형식별 컬러 아이콘(icons8 세트)을 적극 재사용한다.
두 앱은 자매 프로젝트로, Dove Zip은 daylight-commander의 "압축/압축풀기" 기능을
독립 앱으로 떼어내 훨씬 넓은 포맷 커버리지로 확장한 것에 가깝다.

## 핵심 컨셉
- 압축파일을 **열어서 탐색/미리보기**(풀지 않고 내부 목록 확인 — daylight의
  `ArchiveViewerScreen` 개념 계승) + **선택 해제** + **새 압축파일 생성**을
  한 화면 흐름으로 제공
- **"거의 모든 포맷"을 목표**로 하되, 압축 생성(쓰기)과 압축 해제(읽기)의
  지원 범위를 명확히 구분해서 사용자에게 정직하게 표시한다(아래 3장)
- **가장 중요한 기능은 "편리함"** — 압축 해제 위치를 매번 고민하지 않도록
  3가지 모드(1.2 참고)를 제공하는 것이 이 앱의 핵심 UX (WinRAR/7-Zip의
  우클릭 메뉴가 잘하는 부분을 계승/개선)
- 드래그앤드롭 우선: Finder/탐색기에서 파일을 끌어다 놓으면 바로 압축,
  압축파일을 끌어다 놓으면 바로 해제
- 광고/트래킹/인앱결제 없음 — 이 프로젝트의 존재 이유

## 우선순위 태그 정의
- **P0 (MVP 필수)**: 1차 출시에 반드시 포함
- **P1 (Fast-follow)**: MVP 직후 우선 추가
- **P2 (추후)**: 여유 있을 때 추가, 후순위

## 1. 앱 화면 구성 (기능 리스트)

### 1.1 압축파일 탐색/미리보기
- `P0` 압축파일 열기 → 내부 파일/폴더 트리 탐색 (풀지 않고 목록만 읽음)
- `P0` 내부 파일 더블클릭 → 그 파일 하나만 임시 폴더로 꺼내 미리보기
  (텍스트/이미지/Hex — daylight `ViewerScreen` 계승, PDF/미디어는 P1)
- `P1` 압축파일 안 검색(파일명 필터) — ✅ 완료 (현재 폴더 안에서만, 하위 폴더
  재귀 검색은 아님)
- `P2` 중첩 압축(zip 안의 zip 등) 드릴다운

### 1.2 압축 해제

**`P0` 압축 해제 위치 3가지 모드 (이 앱의 핵심 편의 기능)** — 압축파일을 우클릭하거나
앱에서 "해제" 버튼을 누르면 매번 위치를 헤매지 않도록, 아래 3가지 중 하나를 즉시
고를 수 있게 한다. 셋 다 동급으로 항상 노출하되 **기본값은 "알아서 압축 해제"**.

| 모드 | 동작 |
|---|---|
| **여기에 압축 해제** | 압축파일이 있는 폴더에 내용물을 바로 풀어놓는다(별도 폴더 생성 없음) |
| **알아서 압축 해제** (기본값) | 압축파일 이름과 동일한 새 폴더를 만들고 그 안에 해제한다. 단, 압축파일 내부가 이미 압축파일명과 같은 이름의 폴더 하나로만 구성돼 있으면(예: `photos.zip` 안에 `photos/` 폴더 하나뿐) 중복 폴더를 만들지 않고 그 구조를 그대로 살린다(WinRAR/Keka 관례 — `photos/photos/...`처럼 이중 중첩되는 것 방지) |
| **원하는 곳에 압축 해제** | 폴더 선택 다이얼로그로 사용자가 대상 디렉토리를 직접 지정 |

- `P0` 전체 해제 / 선택 항목만 해제 — ✅ 완료. Ctrl(⌘)+클릭으로 항목 하나씩,
  Shift+클릭으로 범위, Ctrl(⌘)+A로 전체 선택(daylight-commander-flutter와
  동일한 클릭 규약 — UI_UX.md 8장). 선택된 항목이 있으면 `ExtractModeBar`
  3버튼 모두 "선택 항목 ..."으로 라벨이 바뀌고, 폴더를 선택하면 그 안의
  파일까지 전부 펼쳐서(`expandSelectionToEntryPaths`) 해제한다. 선택은
  폴더 이동과 무관하게 유지되고, 앱바의 선택 해제 아이콘이나 해제 성공
  시 자동으로 정리된다.
- `P0` 진행률 표시, 취소
- `P0` 압축 해제 시 충돌 처리 (덮어쓰기/건너뛰기/이름변경/모두 적용) — 위 3모드
  중 어느 것을 골라도 최종적으로 대상 폴더가 정해진 뒤 동일한 충돌 처리 흐름을 탄다
- `P1` 마지막으로 고른 모드를 기억하거나, 설정에서 기본 모드를 바꿀 수 있게 함
  — ✅ 완료 (`ExtractModeBar`의 강조 버튼이 마지막 선택을 따라감)
- `P1` 비밀번호로 보호된 zip/7z 해제 (암호 입력 다이얼로그) — ✅ **zip/7z 모두**
  완료(`koni_sevenz` 도입 — 3장 참고). 올바른 비밀번호를 넣을 때까지 다시
  물어보고, 세션 동안 기억한다.
- `P1` 분할 압축 해제 — ✅ **DoveZip 자체 스킴만** 완료. 7z/RAR/zip의 진짜
  멀티볼륨 스펙(다른 프로그램이 만든 `.7z.001`, `.part1.rar`, `.z01` 등)을
  읽는 것은 여전히 보류 — libarchive/네이티브 백엔드가 있어야 그 스펙들을
  파싱할 수 있다. 대신 DoveZip이 압축 생성 시 완성된 단일 압축파일을
  고정 크기로 잘라 `이름.zip.001`, `이름.zip.002`, ... 로 이어 붙인 조각을
  만들고, 해제할 때는 그 조각들을 다시 이어붙여 원래 바이트로 복원한다
  (`FormatRegistry.isSplitVolumePart`/`stripSplitVolumeSuffix`,
  `DartArchiveReader._readArchiveBytes`, `split_volume_locator.dart` 참고).
  **DoveZip이 만든 조각만 DoveZip 스스로 다시 열 수 있다** — 7-Zip/WinRAR
  등 다른 프로그램이 만든 멀티볼륨이나 그 반대(DoveZip 조각을 다른
  프로그램으로 열기)는 여전히 호환되지 않는다.
- `P2` 손상된 압축파일 복구/부분 해제 시도
- `P2` 위 3모드를 OS 컨텍스트 메뉴(daylight PLAN.md 2장의 셸 확장 항목과 동일선상)
  에도 동일한 3개 메뉴 항목("여기에 압축 풀기"/"압축 풀기"/"다른 이름으로 압축
  풀기")으로 그대로 노출 — 로직은 앱 내부와 100% 공유(아래 ARCHITECTURE.md
  `ResolveExtractDestination` 유스케이스 참고)

### 1.3 압축 생성
- `P0` 파일/폴더 선택(드래그앤드롭 또는 파일 피커) → 새 압축파일 생성
- `P0` 포맷 선택 (zip / tar.gz / 7z 등, 3장 매트릭스 기준)
- `P0` 압축 레벨 선택 (저장/빠름/보통/최대)
- `P1` 비밀번호 설정 (zip: AES-256, 7z: AES-256) — ✅ **zip/7z 모두** 완료
  (zip은 `ZipEncoder`, 7z는 `koni_sevenz`의 AES-256 지원을 그대로 사용)
- `P1` 분할 압축(볼륨 크기 지정) — ✅ 완료. `CompressDialog`에 체크박스 +
  볼륨 크기(MB) 입력창을 노출하고, 포맷과 무관하게(단일 파일 포맷 포함)
  지원한다 — 완성된 압축파일 바이트를 자르는 후처리라서다. 위 해제 항목과
  동일한 DoveZip 자체 스킴 한계를 공유한다.
- `P1` 압축 전 예상 크기/현재 압축률 표시 — ✅ 완료 (원본 크기는 압축 시작
  전에 미리 계산, 압축률은 완료 메시지에 "X → Y, N% 감소"로 표시)
- `P2` 압축 시 파일 필터(특정 확장자 제외, 심볼릭 링크 처리 옵션)

### 1.4 편의 기능 (daylight 패턴 계승)
- `P0` 다크/라이트 테마 토글 (시스템 → 라이트 → 다크 순환, 설정 저장)
- `P1` 다국어(한국어/영어) — ✅ 완료 (flutter_localizations + ARB +
  gen-l10n, daylight-commander-flutter와 동일한 패턴. 앱바의 지구본
  아이콘으로 시스템 → 한국어 → 영어 순환, 선택 유지)
- `P1` 최근 연 압축파일 목록 — ✅ 완료 (최대 10개, 홈 화면 하단에 표시,
  개별 삭제 가능)
- `P2` OS 파일 연결(더블클릭으로 Dove Zip이 열리도록 확장자 등록: zip/7z/tar 등)
- `P2` OS 컨텍스트 메뉴("여기에 압축", "여기에 풀기") — 3장 참고, 난이도 높아 후순위

## 2. 1차 범위 밖 (비목표)
- OS 셸 확장(우클릭 "압축/풀기" 메뉴) — 플랫폼별 네이티브 개발 필요, MVP 이후 검토
- RAR **생성**(압축) — 3장 참고, 라이선스상 사실상 불가능(업계 전체 공통 제약)
- 클라우드 스토리지 업로드/연동
- 파일 관리자 기능 전반(2-pane 탐색, 이동/복사 등) — 그건 daylight-commander의 역할
- 모바일(Android/iOS)

## 3. 포맷 지원 매트릭스 (이 앱의 핵심 차별점)

상용 압축 프로그램도 실제로는 "생성 가능한 포맷"이 매우 제한적이고(대개 zip/7z만),
나머지는 해제만 지원한다. Dove Zip도 이 현실을 인정하고 **정직하게 등급을 나눈다**.

| 등급 | 포맷 | 비고 |
|---|---|---|
| `P0` 생성+해제 | ZIP (Deflate/Store) | 가장 보편적, 최우선 — ✅ 완료(비밀번호 포함) |
| `P0` 생성+해제 | TAR, TAR.GZ/TGZ, TAR.BZ2 | Unix 계열 표준 — ✅ 완료 |
| `P0` 생성+해제 | GZIP, BZIP2 (단일 파일) | ✅ 완료 |
| `P1` 생성+해제 | TAR.XZ, XZ (단일 파일) | ✅ 완료 |
| `P1` 생성+해제 | TAR.ZST, ZSTD (단일 파일) | 보류 — `archive` 패키지에도, 지금 채택한 `koni_codecs`(아래 참고)에도 아직 zstd 코덱이 없다 |
| `P1` 생성+해제 | 7Z (LZMA2) | ✅ 완료 — `koni_sevenz`(순수 Dart, 아래 참고)로 구현. 압축 "레벨" 조절은 없음(store만 선택 가능, 나머지는 LZMA2 고정) |
| `P1` 생성+해제 | ZIP (AES-256 암호화) | ✅ 완료(임시 Dart 백엔드로 먼저 구현) |
| `P2` 생성+해제 | LZ4, Brotli (단일 파일) | |
| `P1` **해제 전용** | RAR (RAR5 전체, RAR4는 대부분) | ✅ 완료 — `koni_rar`(순수 Dart). 아래 "RAR 정책" 참고 |
| `P2` **해제 전용** | ISO9660, CAB, ARJ, LHA/LZH, CPIO, AR, XAR, WARC | `libarchive` 커버리지 그대로 활용 |
| `P2` **해제 전용** | DEB(`ar`+`tar`), RPM(`cpio` 부분) | 리눅스 패키지 내용물 열람용 |
| 비목표 | RAR **생성**, 멀티볼륨 RAR 생성 | |

> **구현 현황**: 이 매트릭스는 원래 네이티브 백엔드(libarchive+Rust)
> 도입을 전제로 짰지만, 실제로는 순수 Dart 패키지 두 벌로 상당 부분을
> 먼저 채웠다 — `archive`(zip/tar 계열, `DartArchiveReader`/
> `DartArchiveWriter`)와 `koni_sevenz`/`koni_rar`(7z/RAR, MIT,
> [zenbaku/koni_archive](https://github.com/zenbaku/koni_archive)).
> 그 결과 **ZIP(비밀번호 포함)/TAR/TAR.GZ/TAR.BZ2/TAR.XZ/GZIP/BZIP2/XZ/
> 7Z(비밀번호 포함)/RAR(해제)**가 전부 실제로 동작한다. gzip/bzip2/xz는
> 파일 하나만 압축할 수 있는 포맷이라(폴더·다중 선택은 tar로 먼저 묶어야
> 함) 그 경우 명확한 에러를 던진다. **ZSTD/TAR.ZST만 여전히 막혀 있다** —
> `koni_zstd`/zstd 지원이 GitHub 메인 브랜치에는 있지만 이 앱이 쓰는
> pub.dev 배포판(koni_codecs 0.9.0, 2026-07-17 기준)에는 아직 없다.
> zstd를 마저 채우려면 (a) koni 생태계가 pub.dev에 zstd를 배포할 때까지
> 기다리거나, (b) 다른 순수 Dart 패키지(예: `just_zstd` — 디코드 위주,
> 스펙 커버리지 제한적)를 쓰거나, (c) FFI+네이티브 빌드훅이 필요한
> 패키지(예: `zstd_dart`)를 쓰는 선택지가 있다 — 아직 결정 안 함.
>
> `koni_rar`는 RAR5는 전체, RAR4는 대부분(구식 RAR 1.5 압축 방식만 예외)
> 해제한다 — 실제 RAR 7.23으로 만든 픽스처로 검증(`test/fixtures/rar/`,
> `dart_archive_reader_rar_test.dart`). `koni_sevenz`는 실제 `7z`(p7zip)
> CLI와 양방향(우리가 만든 7z를 7z로 풀기 / 7z가 만든 7z를 우리가 풀기,
> 비밀번호 포함)으로 교차 검증했다(`dart_archive_writer_sevenzip_test.dart`).
> RAR **쓰기**는 여전히 지원하지 않는다(아래 "RAR 정책", 라이선스 제약은
> koni_rar를 쓰든 안 쓰든 동일).

### RAR 정책 (중요)
RAR 압축 알고리즘은 RARLAB의 특허/독점 기술이라 **오픈소스로 압축 생성 기능을
합법적으로 구현할 수 없다** — 이건 7-Zip, WinZip, Keka 등 모든 서드파티 도구가
공통으로 겪는 제약이며 전부 "RAR 해제만 지원"한다. Dove Zip도 동일하게
**RAR은 해제 전용**으로 명시하고, 사용자에게도 이 사실을 UI에 드러낸다(포맷
선택 목록에 RAR은 "생성" 옵션 자체가 없음).

해제는 지금 `koni_rar`(순수 Dart, MIT — RARLAB 소스를 전혀 참조하지 않고
스펙을 독립 구현)를 쓴다. 원래 계획이던 `libarchive`의 RAR 리더로 나중에
바꿀 수도 있지만(ARCHITECTURE.md 4장), 당장은 네이티브 빌드 없이 오늘
바로 동작하는 쪽을 택했다. RARLAB의 `unrar` 소스는 라이선스 조항(경쟁
제품 개발 금지 등)이 애매해 **번들링하지 않는다**는 원칙은 그대로다.

## 4. 기술 스택 및 네이티브 압축 엔진 설계

### 4.1 왜 Dart만으로는 부족한가
Dart의 `archive` 패키지는 zip/tar/gzip/bzip2/xz 정도까지만 지원한다.
7z/RAR는 `koni_sevenz`/`koni_rar`(순수 Dart, MIT, 3장 참고)로 이미 메웠지만
— 이 항목이 이 절 작성 당시의 목표였다 — **zstd/lz4/brotli, 그리고
iso9660/cab/arj/lha/cpio/ar/xar/warc 같은 레거시·니치 포맷은 여전히 어느
순수 Dart 패키지도 커버하지 못한다**("거의 모든 포맷" 목표와 충돌). 이
남은 격차를 메우기 위해 네이티브 레이어(Rust, 필요시 C/C++)를 도입하는
계획은 유효하다 — 다만 7z/RAR가 이미 동작하니 그 두 포맷만 보면 더는
급하지 않고, 진짜 멀티볼륨 스펙 읽기(PLAN.md 1.2)나 대용량 성능 최적화
같은 이유로도 여전히 검토 대상이다.

### 4.2 두 개의 네이티브 백엔드를 병행하는 안 (제안)

| 백엔드 | 역할 | 이유 |
|---|---|---|
| **libarchive** (C 라이브러리, `dart:ffi`로 직접 바인딩) | **해제(읽기) 전담**, 광범위한 레거시/니치 포맷 커버 | 하나의 라이브러리로 tar/zip/7z(읽기)/rar(읽기)/cab/iso/cpio/ar/lha/xar/warc + gzip/bzip2/xz/lzma/zstd/lz4 필터를 전부 커버. macOS Archive Utility, 7-Zip 대체 앱 Keka도 실제로 libarchive 기반. BSD 라이선스로 자유롭게 사용 가능 |
| **Rust 크레이트** (`flutter_rust_bridge`로 브리지) | **생성(쓰기) 전담** + 최신 포맷/암호화 | libarchive는 7z 쓰기를 지원하지 않고 zip 쓰기 시 AES 암호화 등도 제한적. Rust 생태계(`zip`, `sevenz-rust2`, `flate2`, `xz2`, `zstd`, `tar` crate)가 압축 **생성** 쪽 완성도가 높고 크로스컴파일도 3플랫폼 모두 검증되어 있음 |

두 백엔드를 Dart 서비스 계층(`ArchiveService`, daylight의
`archive_service.dart` 패턴 계승)이 감싸서, UI 레이어는 "이 포맷이 libarchive로
해제됐는지 Rust로 압축됐는지" 신경 쓰지 않는다.

**C++의 역할**: libarchive는 C API가 콜백 기반 스트리밍 구조라, 진행률
콜백/취소 토큰을 Dart FFI 쪽에 자연스럽게 연결하기 위한 **얇은 C/C++ 셰임
레이어**가 필요할 가능성이 높다(순수 C로 충분할 수도 있음 — PoC 단계에서
확정). 그 외 C++은 향후(P2) OS 셸 확장(Windows 탐색기 컨텍스트 메뉴는 COM
기반 C++, macOS는 Swift가 자연스럽지만 코어 로직 재사용 시 Objective-C++)을
염두에 둔 선택지로만 남겨두고, MVP 범위에서는 강제하지 않는다.

### 4.3 리스크 및 검증 필요 사항 (PoC 우선순위)
1. **Windows에서 libarchive 빌드/배포** — macOS/Linux는 시스템에 있는 경우가
   많지만 Windows는 직접 정적/동적 빌드해 앱에 동봉해야 함 (최우선 검증)
2. `flutter_rust_bridge`로 3개 데스크톱 플랫폼 모두 Rust 크레이트 크로스컴파일
3. libarchive와 Rust 백엔드 사이 포맷 중복(zip 등) 시 우선순위 규칙 확정
4. 대용량 파일 스트리밍 처리(전체를 메모리에 올리지 않기 — daylight의 zip
   미리보기 방식 계승) 두 백엔드 모두에서 유지 가능한지

## 5. 아키텍처 레이어 (daylight-commander 계승 + 확장)

```
presentation/   화면, 다이얼로그, Riverpod 컨트롤러
application/    유스케이스 (OpenArchive, ExtractEntries, CreateArchive, ListEntries ...)
domain/         엔티티(ArchiveEntry, ArchiveFormat, CompressionOptions), Repository 인터페이스
data/           Repository 구현체 — native/ 백엔드 호출을 감쌈
native/         (신규) dart:ffi → libarchive 바인딩, flutter_rust_bridge → Rust 크레이트
core/           OperationQueue, 취소 토큰, 에러 타입 등 daylight와 공용 개념 계승
```

상태관리는 daylight와 동일하게 **Riverpod** 채택(검증된 패턴 재사용).

## 6. UI/테마 (daylight-commander-flutter 이식)

- `AppColors`/`AppRadius`/`AppTheme.dark()/.light()` 구조를 그대로 복사해
  이식 (다크 퍼스트가 아닌 라이트/다크 동등 지원 원칙도 동일)
- 파일 유형별 컬러 아이콘(icons8 SVG 세트)도 그대로 재사용 — 압축 관련 아이콘
  (`icons8-zip-240`, `icons8-7zip-240`, `icons8-rar-240`, `icons8-tar-240`,
  `icons8-archive-240`, `icons8-open-archive-240`)은 daylight에 이미
  준비되어 있어 그대로 가져다 쓸 수 있음. 부족한 포맷(xz/zstd/iso 등)
  아이콘은 icons8에서 동일 스타일로 추가 수급
- UI 크롬 아이콘(`assets/icons/ui/*`)도 톤 유지를 위해 재사용, 압축 특화
  신규 아이콘(비밀번호 잠금, 압축 레벨 슬라이더, 분할 볼륨)만 추가
- 폰트(SeoulNamsan)·다국어(ARB/gen-l10n) 구조도 동일하게 이식
- 화면 구성은 daylight의 2-pane과 달리 **단일 패널 + 압축파일 탐색 트리**
  형태(WinRAR/Keka류 UX)로, 상세 레이아웃은 별도 UI_UX.md에서 설계

## 7. 다음 단계
1. 본 계획서 검토 및 포맷 매트릭스(3장) 확정 — RAR 해제 전용 정책 확정 포함
2. 네이티브 백엔드 PoC — 특히 Windows에서 libarchive 빌드, 3플랫폼
   `flutter_rust_bridge` 크로스컴파일 검증 (4.3 리스크 항목)
3. ~~아키텍처 설계서 작성~~ — 완료, [ARCHITECTURE.md](ARCHITECTURE.md) 참고
   (네이티브 백엔드 라우팅 + `resolveExtractDestination` 편의 로직 포함)
4. ~~UI/UX 설계서 작성~~ — 완료, [UI_UX.md](UI_UX.md) 참고 (daylight 테마 이식 +
   `ExtractModeBar` 등 압축 전용 화면 목업)
5. 프로젝트 초기 세팅 (Flutter 데스크톱 스캐폴드 3종, 테마/아이콘 이식)
6. P0 기능 구현 시작
