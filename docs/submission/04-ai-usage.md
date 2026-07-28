# AI 활용 기술 문서

> **제출물 4** · 초안 · 확정 후 PDF로 export  
> `TODO` 는 제출 전 보강·확정 항목입니다.

---

## 1. AI 활용 개요

본 프로젝트는 **Cursor Agent**(코딩 에이전트)를 개발 워크플로의 중심에 두고, 기획 문서화·구현·리팩터·티켓 관리까지 AI와 사람이 역할 분담하는 방식으로 제작했습니다.

| 역할 | 담당 |
|------|------|
| AI (Cursor Agent) | 스펙·Task 초안, 코드·씬 구현 초안, 문서·칸반 갱신, Godot API 조회 |
| 사람 (팀) | 게임 방향·수치 결정, 플레이 검증, AC 확정, `done` 판정, 최종 커밋·머지 승인 |

AI가 생성한 내용은 **저장소 규칙·시스템 스펙**에 맞게 검수 후 반영합니다. 플레이 영상·최종 디자인 판단은 AI 조작·합성이 아닌 **실제 플레이·사람 결정**입니다.

---

## 2. 사용 도구

| 도구 | 용도 |
|------|------|
| **Cursor** (Agent / Composer) | 기능 구현, 리팩터, 문서 작성, `/feature`·`/push` 워크플로 실행 |
| **Context7 MCP** | Godot **4.7** 공식 문서 조회 (API·마이그레이션 확인) |
| **Git / GitHub** | `feature/*` 브랜치, main 머지, Pages 문서 배포 |
| **Godot 4.7** | 에디터 플레이·씬 편집 (최종 검증은 사람) |

> 모델명·플랜은 제출 시점 Cursor 설정 기준으로 `TODO: 사용 모델명 (예: Composer / Claude 등)` 기입.

---

## 3. 개발 파이프라인 (AI + 규칙)

저장소에 **에이전트용 스킬·룰**을 두어, 매번 같은 순서로 일하게 했습니다.

```text
아이디어 / 칸반 카드
    → /feature (브랜치 + 시스템 스펙 + Task)
    → 구현 (스펙 범위만)
    → /push (정합성 검사 + 커밋 + main 머지)
    → 칸반 review → 사람 플레이 검증 → done
```

### 주요 지시·프롬프트 패턴 (요약)

실제로는 `.cursor/rules/`, `.cursor/skills/`, `.agents/skills/`에 상주합니다. 대표 지시:

1. **스펙 우선** — 동작 변경 시 `docs/design/systems/<slug>.md` → Task → 코드 순. 현황 정본은 `docs/spec/`.
2. **범위 제한** — `feature/<slug>`에서는 해당 slug 관련 경로만 수정. 무관 리팩터 금지.
3. **Godot 4.7** — Context7의 `/websites/godotengine_en_4_7` 우선. Godot 3 패턴 금지.
4. **칸반 연동** — `/feature` 시 카드 생성·`doing`, `/push` 직전 카드 → `review`. `done`은 사람만.
5. **비주얼** — `.agents/godot_nova_drift_visual_guide.md`를 네온 비주얼 가이드로 참조.

### 구조 설명 (한 줄)

> “**마크다운 칸반 + 시스템 스펙**을 정본으로 두고, Cursor가 그 정본을 읽고 코드를 쓰는” 구조입니다.

---

## 4. 칸반 보드 기반 관리

티켓은 `docs/board/`에 두고, `.cursor/rules`로 에이전트가 카드 열을 읽고·갱신하게 했습니다.  
프로토콜은 채팅 일회성이 아니라 저장소 룰·스킬에 고정되어 있으며, 열 이동·커밋·스펙 diff로 추적됩니다.

참고: [칸반](https://team-sema.github.io/project-Afterburn/board/) · [스펙](https://team-sema.github.io/project-Afterburn/spec/)

### 구성

| 파일 | 역할 |
|------|------|
| `docs/board/cards.json` | 카드 인덱스 (id, title, column, tags) |
| `docs/board/cards/<id>.md` | 카드 본문 (목표·AC·이력) |
| GitHub Pages `/board/` | 브라우저에서 열 상태 공유 |

열: `ideas` → `speccing` → `ready` → `doing` → `review` → `fix` → `done`

### AI가 하는 일

- `/feature` 시작 시 slug로 카드 검색, 없으면 생성, 열을 `speccing`/`doing`으로 이동.
- 구현 범위·AC를 카드·시스템 스펙과 맞춤.
- `/push` 직전 열을 **`review`** 로 바꾸고 이력 한 줄 추가 (같은 커밋에 포함).
- `done`으로는 자동 이동하지 않음 → **사람 플레이 검증** 후에만 완료.
- 보드에서 복사한 **에이전트 프롬프트**를 받으면 `cards.json` 열만 반영.

### 사람이 하는 일

- 백로그 우선순위, `ready`/`ideas` 판단.
- `review` 카드 플레이 확인 → 보드에서 `done`/`fix`으로 드래그 → **에이전트 프롬프트 복사** → Cursor에 붙여넣기.
- 2인 협업 시 같은 날 `main` pull, feature는 짧게 유지.

### 예시 흐름

1. 사람이 “무기 슬롯 로드아웃” 요청  
2. Agent: `feature/weapon-slot-loadout` 생성 + 카드 `doing` + 시스템 스펙·Task 작성  
3. Agent: 스펙 범위 내 코드 구현  
4. `/push` → 카드 `review` + main 머지  
5. 사람: 플레이 확인 후 보드에서 `done` (또는 `fix`) → 프롬프트 복사로 저장소 반영

---

## 5. AI 적용 영역 맵

| 영역 | AI | 사람 |
|------|----|------|
| 시스템 스펙·Task | 초안·갱신 | AC 확정, 방향 결정 |
| 게임플레이 코드·컴포넌트 | 구현·리팩터 | 플레이 검증, 밸런스 |
| UI·메뉴·오그먼트 오버레이 | 구현 보조 | UX·카피 최종 |
| 네온 비주얼 | 가이드 기반 구현 | 연출 취향 |
| 칸반·문서 사이트 | 카드/스펙 동기화 | 우선순위·done |
| 에셋(원본 아트) | (해당 시) 보조 | 출처·라이선스 관리 |

---

## 6. 외부 에셋 · 오픈소스 출처

기반 튜토리얼 리소스:  
[uheartbeast/galaxy_defiance_resources](https://github.com/uheartbeast/galaxy_defiance_resources)  
(Godot 4 컴포넌트형 슈팅 튜토리얼 리소스. 스크립트 MIT · 에셋은 README 라이선스.)

| 항목 | 출처 | 라이선스 | Afterburn에서의 사용 |
|------|------|----------|----------------------|
| 컴포넌트 스크립트 (기반) | HeartBeast / Heart Gamedev LLC | MIT | 다수 사용·일부 수정·확장 |
| 스프라이트 (레거시 PNG) | GrafxKid ([OpenGameArt](https://opengameart.org/content/arcade-space-shooter-game-assets)) via HeartBeast 리소스 | CC0 | `assets/*.png` (일부 `blaster_*`로 파일명 변경, 내용 동일) |
| Kenney Mini Square | [Kenney Fonts](https://kenney.nl/assets/kenney-fonts) | CC0 | `fonts/kenney_mini_square.ttf` |
| SFX (`explosion`, `hit`, `blaster`←laser) | HeartBeast | CC0 | `sounds/*.wav` |
| BGM `music.ogg` | HeartBeast 리소스 저장소 포함 파일 | 튜토리얼 리소스와 동일 파일 | `sounds/music.ogg` |
| white flash 셰이더 | HeartBeast 리소스 | MIT 계열 스크립트/리소스 | `effects/white_flash_material.*` |
| Mulmaru 폰트 | [Mushsooni / Mulmaru](https://github.com/mushsooni/mulmaru) | SIL OFL 1.1 | UI 한글·타이틀 |
| 네온 SVG·글로우 연출 | 팀 제작 (+ Nova Drift **스타일 참고**, 에셋 복제 아님) | 팀 | `assets/svg/`, `effects/` 확장분 |
| Godot Engine | godotengine.org | MIT | 엔진 |
| `assets/Beam.png` | `TODO: 출처 확인` | `TODO` | 사용 시 명시 |

MIT 스크립트 사용 시 저작권·허가 고지 유지 (원 LICENSE: Copyright (c) 2023 Heart Gamedev LLC).

### 팀 추가·변경분 (요약)

- 오그먼트(플레이어/적) 선택 루프, XP·시간 트리거  
- 무기 슬롯 로드아웃·드롭 획득  
- Nova Drift풍 네온 비주얼·SVG  
- Cursor `/feature`·`/push`·칸반·스펙 사이트 워크플로  

---

## 7. 한계와 책임

- AI 산출물은 스펙·플레이로 검수하며, 오동작·범위 이탈은 사람이 되돌리거나 `fix` 티켓으로 처리합니다.  
- 외부 저작물·아이디어는 위 출처표에 따라 사용하며, 무단 도용을 하지 않습니다.  
- 제출 영상은 실제 플레이 화면이며, AI 조작·합성·타인 영상 도용을 하지 않습니다.

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-07-28 | §4 칸반: ‘왜 적합한가’ 제거, 본문에 압축 |
| 2026-07-28 | 보드→에이전트 프롬프트 복사 반영 경로 반영 |
| 2026-07-28 | 초안 작성 (칸반 AI 사례·Galaxy Defiance 출처 포함) |
