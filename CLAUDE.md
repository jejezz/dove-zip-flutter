# Dove Zip

광고·팝업 없는 압축/해제 데스크톱 유틸리티 (Windows/macOS/Linux, Flutter).
구조는 [ARCHITECTURE.md](ARCHITECTURE.md), 화면 규칙은 [UI_UX.md](UI_UX.md),
진행 계획은 [PLAN.md](PLAN.md)를 본다.

## 공통 규약

릴리스·버전·패키징·정보 창·아이콘·라이선스·UI/UX·글꼴·언어·테마는
https://github.com/jejezz/application-release-templates/tree/main/conventions
규약을 따른다. 이 앱에 적용된 규약 버전: conventions-v1 (미적용: 릴리스
워크플로·설치 프로그램·아이콘, 정보 창·언어·테마·글꼴, README)

- 식별자 `com.ptype.doveZip`(macOS) / `com.ptype.dove_zip`(Linux)과 Windows
  `AppId`는 이미 릴리스됐으므로 바꾸지 않는다 (identity.md §5).
- 버전은 `scripts/bump-version.sh`로 올리고, 병합된 `main`에 태그를 단다.
