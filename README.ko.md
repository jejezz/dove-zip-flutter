<!-- From jejezz/application-release-templates common/tool/readme @ conventions-v1.
     구성과 규칙: conventions/readme-guide.md. README.md와 내용을 같게 유지합니다.
     검사: python3 tool/readme/check_readme.py -->

<p align="center">
  <img src="assets/icon/app_icon.png" width="128" alt="Dove Zip 아이콘">
</p>

<h1 align="center">Dove Zip</h1>

<p align="center">
  광고·팝업 없는 <b>macOS·Windows·Linux용 무료 압축 유틸리티</b> — ZIP, 7Z, RAR, TAR 압축파일을
  풀지 않고 들여다보고, 원하는 방식으로 풀고 만듭니다.
</p>

<p align="center">
  <a href="https://github.com/jejezz/dove-zip-flutter/releases/latest"><img src="https://img.shields.io/github/v/release/jejezz/dove-zip-flutter?style=flat-square&color=4c9dff" alt="최신 릴리스"></a>
  <a href="https://github.com/jejezz/dove-zip-flutter/releases"><img src="https://img.shields.io/github/downloads/jejezz/dove-zip-flutter/total?style=flat-square&color=7c5cff" alt="다운로드"></a>
  <img src="https://img.shields.io/badge/platform-macOS%20%C2%B7%20Windows%20%C2%B7%20Linux-34d399?style=flat-square" alt="macOS · Windows · Linux">
  <img src="https://img.shields.io/badge/built%20with-Flutter-02569b?style=flat-square" alt="Flutter">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/jejezz/dove-zip-flutter?style=flat-square" alt="MIT 라이선스"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <b>한국어</b>
</p>

<p align="center">
  <img src="docs/screenshots/demo.gif" width="720" alt="Dove Zip 데모: 압축파일을 끌어다 놓고, 안을 둘러보고, 고른 항목만 풀기">
</p>

## 기능

- **풀지 않고 탐색** — 항목 목록만 읽어서 보여 주고, 텍스트·이미지는 더블클릭으로 바로 미리보기.
  압축파일 안의 압축파일도 몇 단계든 그대로 들어갑니다
- **3가지 해제 모드** — *여기에*, *알아서*(압축파일 이름으로 새 폴더, 같은 이름 폴더가 이중으로
  생기지 않음), *원하는 곳에*. 마지막에 고른 모드를 기억하고, 고른 항목만 풀 수도 있습니다
  (⌘/Ctrl·Shift-클릭)
- **손상된 압축파일도 부분 해제** — 못 읽는 항목이 있어도 나머지는 계속 풀고, 건너뛴 항목 목록을
  보여 줍니다(복사 가능)
- **압축 만들기** — 압축 레벨(저장/빠름/보통/최대)과 예상 크기·완료 후 압축률, 확장자 필터,
  심볼릭 링크 처리, ZIP·7Z **AES-256 비밀번호**, 분할 압축(`이름.zip.001`, `.002`, … — Dove Zip
  자체 방식)
- **끌어 넣고 끌어내기** — 파일을 끌어다 놓아 열거나 압축하고, 항목을 Finder·탐색기로 끌어내면 그
  자리에 풀립니다. macOS에서는 Finder 서비스 메뉴에 *여기에 압축* / *여기에 풀기*가 생깁니다
- **라이트·다크, 한국어·English** — 시스템 설정을 따르거나 툴바에서 고를 수 있습니다

<p align="center">
  <img src="docs/screenshots/home.png" width="360" alt="홈: 드롭 영역과 최근 연 압축파일">
  <img src="docs/screenshots/browser.png" width="360" alt="압축파일 안을 둘러보는 화면과 해제 모드 막대">
</p>

### 지원 포맷

| 포맷 | 해제 | 생성 |
|---|---|---|
| ZIP | ✅ | ✅ (비밀번호 포함) |
| TAR, TAR.GZ/TGZ, TAR.BZ2/TBZ2, TAR.XZ | ✅ | ✅ |
| GZIP, BZIP2, XZ (단일 파일) | ✅ | ✅ |
| 7Z | ✅ | ✅ (비밀번호 포함) |
| RAR (RAR5 전체, RAR4는 대부분) | ✅ | ❌ (라이선스상 불가능 — 업계 공통 제약) |
| ZSTD, TAR.ZST | ❌ 보류 | ❌ 보류 |

포맷별 정책과 근거: [`PLAN.md`](PLAN.md) 3장.

## 설치

[**Releases**](https://github.com/jejezz/dove-zip-flutter/releases/latest)에서 받습니다.

| OS | 파일 |
|---|---|
| macOS 12.0 이상 | `DoveZip-<버전>-macos-universal.dmg` — 열어서 앱을 Applications 폴더로 끌어다 놓으세요 |
| Windows 10/11 (x64) | `DoveZip-<버전>-windows-x64-setup.exe` |
| Linux (x64) | `DoveZip-<버전>-linux-x64.tar.gz` — 압축을 풀고 `./install.sh` 실행 (`--remove`로 제거) |

**Windows:** 설치 프로그램에 아직 코드 서명이 없어서 SmartScreen이 "Windows의 PC 보호" 창을 띄웁니다. **추가 정보 → 실행**을 누르세요.

## 동작 방식

모든 포맷을 순수 Dart로 처리합니다 — ZIP·TAR 계열은 [`archive`](https://pub.dev/packages/archive),
7Z·RAR은 [`koni_sevenz` / `koni_rar`](https://github.com/zenbaku/koni_archive)(MIT). 그래서 세 운영체제에
따로 네이티브 압축 라이브러리를 넣고 맞출 필요가 없습니다. 네이티브 백엔드가 필요한 포맷(ZSTD, LZ4,
ISO, CAB)은 일부러 다음 버전으로 미뤘습니다([`PLAN.md`](PLAN.md) 4장). 끌어내기는
[`flutter_drag_out`](https://github.com/jejezz/flutter_drag_out)을 씁니다. macOS는 놓는 순간 그
자리에 풀어서 크기 제한이 없고, Windows·Linux는 끌기 시작할 때 미리 풀어 두는 방식이라 512 MB
이하 항목만 가능합니다.

## 개발

```bash
flutter pub get
flutter run -d macos     # 또는 windows, linux
flutter test
```

설계와 배경: [`ARCHITECTURE.md`](ARCHITECTURE.md)(레이어, 도메인 모델, 백엔드, 구현하며 달라진 점),
[`UI_UX.md`](UI_UX.md)(화면, 컴포넌트, 테마), [`PLAN.md`](PLAN.md)(기능, 포맷 매트릭스, 우선순위 —
완료·보류 항목의 기준). Flutter와 Riverpod으로 만들었고, 문자열은 `lib/l10n/`의 ARB 파일(`gen-l10n`)입니다.

릴리스: `scripts/bump-version.sh patch` → 병합 → `vX.Y.Z` 태그. CI가 모든 플랫폼을 빌드·서명해서
올립니다. 자세한 절차: [`docs/RELEASE.md`](docs/RELEASE.md). 규칙: [application-release-templates/conventions](https://github.com/jejezz/application-release-templates/tree/main/conventions).

## 크레딧

- 글꼴: [서울남산체](https://www.seoul.go.kr/seoul/font.do) (서울특별시, 공공누리 제1유형)
- 아이콘: [Icons8](https://icons8.com)
- 7Z/RAR 해제: [koni_archive](https://github.com/zenbaku/koni_archive) (MIT)

## 라이선스

[MIT](LICENSE) © 2026 Jongyun Ahn
