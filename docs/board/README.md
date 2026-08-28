# 백로그 칸반 (GitHub Pages)

백로그를 `docs/board/` 칸반으로 봅니다.

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

## 운영 보드 (Notion)

열 이동 정본은 [아이템 칸반](https://app.notion.com/p/102c71bf78394bcaa9ff627548faf7f9?v=3c9b8c11155f8111bfeb000c00cae3b8)이다.

`/feature`·`/push`는 Notion 카드 **초안을 추천**한다. 카드 생성·열 이동은 사람이 Notion에서 한다. 이 Pages 보드의 `cards.json`은 스냅샷이다.

## 팀 반영 방법 (Pages 보드 → Notion)

브라우저 드래그는 **미리보기**만 합니다. JSON 다운로드로 커밋하지 않습니다.

1. (선택) Pages 보드에서 카드 드래그
2. **에이전트 프롬프트 복사** 클릭
3. Cursor 채팅에 붙여넣기
4. 에이전트가 **Notion 아이템 칸반** `상태`만 갱신 (git 커밋 없음)

사람 검증 후 `검증 대기` → `완료`/`수정 필요`는 Notion에서 직접 드래그하거나 에이전트에게 말해도 된다.

## 로컬 미리보기

```bash
cd docs
python -m http.server 8080
```

- 홈: http://localhost:8080/
- 스펙: http://localhost:8080/spec/
- 칸반: http://localhost:8080/board/
