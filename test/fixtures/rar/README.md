# RAR 테스트 픽스처 출처

이 폴더의 `.rar` 파일들은 우리가 만든 게 아니다 — 이 앱이 RAR 해제에 쓰는
[zenbaku/koni_archive](https://github.com/zenbaku/koni_archive)(MIT
라이선스) 프로젝트의 `koni_rar/test/fixtures/rar/` 디렉터리에서 그대로
가져왔다. 우리 스스로는 RAR를 **만들 수 없어서**(이 앱도 RAR 생성은
라이선스상 지원하지 않는다 — PLAN.md 3장 "RAR 정책" 참고) 진짜 RAR 도구가
만든 바이트가 필요했고, koni_archive 자신이 그 검증을 위해 실제 RAR 7.23
으로 만들어 커밋해 둔 픽스처를 재사용했다.

| 파일 | 원본 이름 | 내용 (koni_archive의 `tool/generate_fixtures.dart`, `RarFixtureSet` 참고) |
|---|---|---|
| `normal.rar` | 동일 | RAR5, `-m3`. `hello.txt`("hello, rar!\n"), `empty.txt`(0바이트), `nested/deep/data.bin`(100000바이트, `((i*7)^(i>>3))&0xFF` 생성), `日本語/ページ001.txt`("unicode page\n") |
| `synthetic_comic.rar` | `synthetic_comic.cbr` | RAR5, `-m3`. `comic/ComicInfo.xml` + `comic/page00{1,2,3}.png`. 원본 확장자 `.cbr`은 이 앱의 `FormatRegistry`가 아직 인식하지 않아(별도 스코프) `.rar`로 바꿔 가져왔다 |
| `encrypted.rar` | 동일 | RAR5, `-m0 -psecret`(내용 암호화). `hello.txt`("hello, rar!\n") |
| `encrypted_headers.rar` | 동일 | RAR5, `-m0 -hpsecret`(헤더까지 암호화). `hello.txt`("hello, rar!\n") |

`dart_archive_reader_rar_test.dart`가 이 파일들로 실제 해제 결과를
검증한다.
