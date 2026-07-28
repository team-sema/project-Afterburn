# 백로그 칸반 (GitHub Pages)

Issues / Projects 없이 백로그를 칸반으로 봅니다.

## URL (Pages)

- 문서 홈: `https://team-sema.github.io/project-Afterburn/`
- 스펙: `https://team-sema.github.io/project-Afterburn/spec/`
- 칸반: `https://team-sema.github.io/project-Afterburn/board/`

## Pages 설정 (한 번만)

1. 저장소 **Settings → Pages**
2. **Source**: Deploy from a branch
3. **Branch**: `main` / 폴더 **`/docs`**
4. Save

## 열

1. 아이디어 / 백로그  
2. 스펙 작성 중  
3. 구현 대기  
4. 구현 중  
5. 검증 대기  
6. 수정 필요  
7. 완료  

## 카드 = MD

| 파일 | 역할 |
|------|------|
| `cards.json` | id, title, description, column, file, tags |
| `cards/<id>.md` | 상세 본문 (팝업) |

## 팀 반영 방법 (보드 → 저장소)

브라우저 드래그는 **미리보기**만 합니다. JSON 다운로드로 커밋하지 않습니다.

1. 보드에서 카드 드래그 (예: 검증 대기 → 완료)
2. **에이전트 프롬프트 복사** 클릭
3. Cursor 채팅에 붙여넣기
4. 에이전트가 `cards.json`(·카드 MD) 갱신 후 커밋 (요청 시)

`/feature`·`/push` 중의 열 이동은 에이전트가 파일로 직접 반영합니다.  
보드 프롬프트는 주로 **사람 검증 후 `review` → `done`/`fix`** 용입니다.

## 로컬 미리보기

```bash
cd docs
python -m http.server 8080
```

- 홈: http://localhost:8080/
- 스펙: http://localhost:8080/spec/
- 칸반: http://localhost:8080/board/
