# Dove Zip

광고·팝업·인앱결제 유도 없는, **직접 만들어 쓰는 압축/해제 유틸리티**입니다.
Flutter로 만든 Windows/macOS/Linux 데스크톱 전용 앱이며, 같은 제작자의
[daylight-commander-flutter](../daylight-commander-flutter)와 동일한 비주얼
테마를 공유하는 자매 프로젝트입니다.

## 핵심 기능

- **압축파일 탐색/미리보기** — 풀지 않고 내부 목록만 읽어서 탐색하고, 텍스트/
  이미지 파일은 더블클릭으로 바로 미리보기
- **3가지 해제 모드** — 여기에 압축 풀기 / 알아서(압축파일 이름으로 새 폴더
  자동 생성, 이중 중첩 방지) / 원하는 곳에 — 마지막으로 고른 모드를 기억
- **압축 생성** — 압축 레벨(저장/빠름/보통/최대), 압축 전 예상 크기·완료 후
  압축률 표시
- **비밀번호 보호(AES-256)** — ZIP, 7Z
- **분할 압축** — 완성된 압축파일을 지정한 크기로 잘라 `이름.zip.001`,
  `이름.zip.002`, ... 로 저장(이 앱 자체 방식 — 다른 프로그램과의 호환은
  보장하지 않음, 상세는 `PLAN.md` 참고)
- **다국어(한국어/영어)** 및 라이트/다크 테마
- **최근 연 압축파일 목록**, 드래그앤드롭으로 열기/압축하기

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

## 상태

개인 프로젝트로, 필요한 기능부터 순서대로 만들어 가는 중입니다. 완료/보류
항목은 `PLAN.md`에 그때그때 반영합니다.
