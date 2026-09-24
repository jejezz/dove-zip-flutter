# Dove Zip

광고·팝업·인앱결제 유도 없는, **직접 만들어 쓰는 압축/해제 유틸리티**입니다.
Flutter로 만든 Windows/macOS/Linux 데스크톱 전용 앱이며, 같은 제작자의
[daylight-commander-flutter](../daylight-commander-flutter)와 동일한 비주얼
테마를 공유하는 자매 프로젝트입니다.

## 핵심 기능

- **압축파일 탐색/미리보기** — 풀지 않고 내부 목록만 읽어서 탐색하고, 텍스트/
  이미지 파일은 더블클릭으로 바로 미리보기
- **중첩 압축 드릴다운** — 압축파일 안에 또 압축파일이 있으면 그 안으로 곧장
  들어가서 탐색(몇 단계든 재귀적으로)
- **3가지 해제 모드** — 여기에 압축 풀기 / 알아서(압축파일 이름으로 새 폴더
  자동 생성, 이중 중첩 방지) / 원하는 곳에 — 마지막으로 고른 모드를 기억
- **선택 항목만 해제** — Ctrl(⌘)/Shift-클릭으로 원하는 파일·폴더만 골라서 해제
- **손상된 압축파일 부분 해제** — 항목 하나가 손상돼 못 읽어도 전체를 멈추지
  않고 나머지는 계속 해제, 건너뛴 항목 목록을 알려줌(복사 가능)
- **압축 생성** — 압축 레벨(저장/빠름/보통/최대), 압축 전 예상 크기·완료 후
  압축률 표시
- **압축 시 파일 필터** — 특정 확장자 제외, 심볼릭 링크 따라가기/건너뛰기 선택
- **비밀번호 보호(AES-256)** — ZIP, 7Z
- **분할 압축** — 완성된 압축파일을 지정한 크기로 잘라 `이름.zip.001`,
  `이름.zip.002`, ... 로 저장(이 앱 자체 방식 — 다른 프로그램과의 호환은
  보장하지 않음, 상세는 `PLAN.md` 참고)
- **다국어(한국어/영어)** 및 라이트/다크 테마
- **최근 연 압축파일 목록**, 드래그앤드롭으로 열기/압축하기
- **끌어내서 해제** — 압축 목록의 항목을 Finder/탐색기로 끌어다 놓으면 그
  자리에 풀림. macOS는 드롭된 뒤 그 위치에 바로 풀어 크기 제한이 없고,
  Windows/Linux는 끌기 시작할 때 미리 풀어 두는 방식이라 원본 512MB
  이하만. 암호화된 항목은 비밀번호를 한 번 입력한 뒤
- **macOS Finder 통합**(macOS 전용) — 우클릭 서비스 메뉴로 "여기에 압축"/
  "여기에 풀기", zip/tar/7z 등 확장자를 더블클릭하면 바로 열기(시스템 기본
  프로그램을 가로채지는 않음)

## 지원 포맷

| 포맷 | 해제 | 생성 |
|---|---|---|
| ZIP | ✅ | ✅ (비밀번호 포함) |
| TAR, TAR.GZ/TGZ, TAR.BZ2/TBZ2, TAR.XZ | ✅ | ✅ |
| GZIP, BZIP2, XZ (단일 파일) | ✅ | ✅ |
| 7Z | ✅ | ✅ (비밀번호 포함) |
| RAR (RAR5 전체, RAR4는 대부분) | ✅ | ❌ (라이선스상 불가능 — 업계 공통 제약) |
| ZSTD, TAR.ZST | ❌ 보류 | ❌ 보류 |

포맷별 정책과 구현 현황의 자세한 근거는 [`PLAN.md`](PLAN.md) 3장을 참고하세요.

## 시작하기

```bash
flutter pub get
flutter run -d macos   # 또는 windows, linux
```

테스트:

```bash
flutter test
```

## 프로젝트 구조 및 설계 문서

- [`PLAN.md`](PLAN.md) — 기능 목록, 포맷 지원 매트릭스, 우선순위
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — 레이어 구조, 도메인 모델, 백엔드
  설계, 구현하면서 계획과 달라진 부분("구현 후 수정")
- [`UI_UX.md`](UI_UX.md) — 화면/컴포넌트/테마 스펙

## 기술 스택

- **Flutter** (Riverpod 상태관리) — macOS/Windows/Linux 데스크톱
- 압축/해제 백엔드: `archive`(ZIP/TAR 계열, 순수 Dart),
  [`koni_sevenz`/`koni_rar`](https://github.com/zenbaku/koni_archive)
  (7Z/RAR, 순수 Dart, MIT) — 자세한 설계 배경은 `ARCHITECTURE.md` 4장 참고
- `flutter_localizations` + ARB 기반 다국어(`gen-l10n`)
- [`flutter_drag_out`](https://github.com/jejezz/flutter_drag_out) — 앱 밖으로
  끌어내기(자체 플러그인, daylight-commander와 공유)

## 상태

개인 프로젝트로, 필요한 기능부터 순서대로 만들어 가는 중입니다. 완료/보류
항목은 `PLAN.md`에 그때그때 반영합니다.

이번 버전은 순수 Dart 백엔드(`archive` + `koni_sevenz`/`koni_rar`)만으로
핵심 기능을 마무리했고, ZSTD/LZ4/Brotli나 ISO9660/CAB 등 레거시 해제 전용
포맷처럼 네이티브(libarchive/Rust) 백엔드가 필요한 항목은 다음 버전으로
미뤘습니다 — 자세한 배경은 [`PLAN.md`](PLAN.md) 4장 상단 결정 참고.
