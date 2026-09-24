# 릴리스

예전 README의 "릴리스" 절을 conventions-v1 기준으로 옮긴 문서입니다. 규칙
전체는 [application-release-templates/conventions](https://github.com/jejezz/application-release-templates/tree/main/conventions)
(`versioning.md`, `tagging.md`, `workflow.md`, `packaging.md`)에 있습니다.

## 절차

1. 릴리스 브랜치에서 버전을 올립니다. build number는 자동으로 1 오릅니다.
   ```bash
   git switch -c release/v0.2.0
   scripts/bump-version.sh minor      # 또는 patch / major, 커밋까지 함
   ```
2. PR로 `main`에 병합합니다.
3. 병합된 `main`에 태그를 답니다. 태그와 `pubspec.yaml` 버전이 다르면
   `check` 잡이 멈추고 릴리스를 만들지 않습니다.
   ```bash
   git switch main && git pull --ff-only
   git tag -a v0.2.0 -m "Dove Zip 0.2.0"
   git push origin v0.2.0
   ```
4. macOS·Windows·Linux 빌드가 모두 성공해야 GitHub Release 하나에 아래가
   함께 올라갑니다. 하나라도 실패하면 릴리스가 만들어지지 않습니다.

| 플랫폼 | 산출물 | 비고 |
|---|---|---|
| macOS | `DoveZip-<버전>-macos-universal.dmg` | Developer ID 서명 + 공증 |
| Windows | `DoveZip-<버전>-windows-x64-setup.exe` | Inno Setup, 서명 없음 (SmartScreen 경고) |
| Linux | `DoveZip-<버전>-linux-x64.tar.gz` | 번들 + 아이콘 + `.desktop` + `install.sh` |
| 공통 | `SHA256SUMS.txt` | 체크섬 |

태그 전에 빌드만 확인하려면 수동 실행을 씁니다. 세 플랫폼을 빌드하고
릴리스는 만들지 않습니다.

```bash
gh workflow run release.yml --ref <브랜치>
```

## 바꾸면 안 되는 것

- Windows 설치 프로그램의 `AppId`(`installer/windows/app.iss`)는 업그레이드와
  제거가 같은 앱으로 인식되는 기준입니다. **한 번 릴리스한 뒤에는 절대
  바꾸지 않습니다.**
- 식별자 `com.ptype.doveZip`(macOS), `com.ptype.dove_zip`(Linux)도 이미
  릴리스됐으므로 그대로 둡니다.

## 시크릿

macOS 서명·공증용 시크릿은 저장소에 등록돼 있습니다:
`MACOS_CERTIFICATE_P12_BASE64`, `MACOS_CERTIFICATE_PASSWORD`,
`MACOS_KEYCHAIN_PASSWORD`, `APPLE_ID`, `APPLE_ID_PASSWORD`, `APPLE_TEAM_ID`.
Windows·Linux는 시크릿이 필요 없습니다.
