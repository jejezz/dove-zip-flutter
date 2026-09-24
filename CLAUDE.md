# Dove Zip

광고·팝업 없는 압축/해제 데스크톱 유틸리티 (Windows/macOS/Linux, Flutter).
구조는 [ARCHITECTURE.md](ARCHITECTURE.md), 화면 규칙은 [UI_UX.md](UI_UX.md),
진행 계획은 [PLAN.md](PLAN.md)를 본다.

## 공통 규약

릴리스·버전·패키징·정보 창·아이콘·라이선스·UI/UX·글꼴·언어·테마는
https://github.com/jejezz/application-release-templates/tree/main/conventions
규약을 따른다. 이 앱에 적용된 규약 버전: conventions-v1 (전 영역 적용)

- 식별자 `com.ptype.doveZip`(macOS) / `com.ptype.dove_zip`(Linux)과 Windows
  `AppId`는 이미 릴리스됐으므로 바꾸지 않는다 (identity.md §5).
- 버전은 `scripts/bump-version.sh`로 올리고, 병합된 `main`에 태그를 단다.
- `lib/about/`·`lib/settings/`의 공통 파일은 템플릿과 같게 둔다. 앱 고유
  정보 창 문구는 `lib/about/dove_zip_about.dart`, 테마 색은
  `lib/presentation/theme/app_theme.dart`(dove-zip 고유)에 둔다.
- 테마·언어는 `AppSettings`(키 `theme_mode`, `app_locale`)로 다룬다.
- 사용자에게 보이는 오류는 data/domain에서 데이터를 담은 전용 예외로 던지고,
  문구는 `lib/presentation/widgets/error_message.dart`의 `describeError`가
  ARB에서 고른다. 코드에 한국어 문자열을 두지 않는다 — 내부 오류(UI가 막는
  입력, 불변식 위반)는 영어 개발자 메시지로 쓴다.
- README는 `README.md`(영어)와 `README.ko.md`(한국어)를 같은 내용으로
  유지하고 `python3 tool/readme/check_readme.py`로 검사한다. 스크린샷은
  `tool/readme/capture.sh`로 찍는다. 릴리스 절차는 `docs/RELEASE.md`.
- 아이콘은 `assets/icon/source_glyph.png`를 바꾸고
  `python3 tool/icon/generate_icons.py`로 다시 만든다. 손으로 고치지 않는다.
