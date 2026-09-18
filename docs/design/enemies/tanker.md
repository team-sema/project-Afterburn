# Tanker

## 외형

![Tanker body](sprites/enemy_tanker_body.svg)

전방 **횡 실드**를 든 청백 네온 가드. 본체는 작은 마름모 몸통 + 좌우 날개, 실드는 넓은 가로 막 레이어다.
- 본체: `assets/svg/enemy_tanker_body.svg`
- 실드: `assets/svg/enemy_tanker_shield.svg`
- 틴트: 청백 글로우 (분홍 잡몹과 구분)

![Tanker shield](sprites/enemy_tanker_shield.svg)

## 의도

**앞을 막아 뒤를 살리는** 방벽.
사격하지 않고, 플레이어가 실드를 깎거나 우회·관통해야 Sniper 등 후방을 처리하게 만든다.

## 플레이어가 고민할 점

- 실드 먼저 깎을지, 레이저 관통·우회로 본체만 노릴지
- 뒤에 숨은 Sniper 조준을 끊을지, 가드부터 지울지
- 실드가 깨진 뒤 약한 본체(35)를 마무리할 타이밍

## 하지 않는 것

- 투사체 사격 (가드 전용)
- 단독으로 화면을 메우는 잡몹 웨이브
- Bomb 호위 탱커 (레거시 `tanker_bomb_*`는 풀 미등록)

## 편대·Encounter에서의 역할

기본은 `tanker_guard_sniper` — 전방 Tanker + 후방 Sniper. 이미 Tanker가 살아 있으면 같은 풀 추첨이 `sniper_reinforcement`로 바뀐다.


## 확정 규칙·수치


| 항목 | 값 |
|------|-----|
| 씬 | `enemies/tanker_enemy.tscn` |
| 본체 HP | 35 |
| 실드 HP | 1000 |
| 점수 | 5 (베이스 `ScoreComponent` 기본값) |
| 최소 Threat | 2 (`tanker_guard_sniper`) |
| 사격 | 없음 (`EnemyShootComponent` 제거) |

### 실드 피격 피드백

| 항목 | 규칙 |
|------|------|
| Scale | 실드 Visual ×1.08 |
| Flash | `flash_root` = 실드 Visual (다중 레이어) |
| Shake | 실드에 사용하지 않음 |
| 본체 | Scale ×1.1 · Shake 0.5 (관통 등 본체 피격 시) |
| 실드 잔량 표시 | Core 알파 단계 감소 (75/50/25% 구간) |

## 조합에서 쓰이는 곳

| Encounter | 역할 |
|-----------|------|
| `tanker_guard_sniper` | 전방 가드 · Threat 2+ 풀 |
| `sniper_reinforcement` | Tanker 생존 시 가드 편대 대체 (Tanker 미등장) |
| `tanker_bomb_*` | 레거시 · 풀 미등록 |

→ [Encounter 카탈로그](../encounters/catalog.md) · [Sniper](sniper.md)


## 완료 조건·검증

- 실드 피격은 본체 HP를 깎지 않는다. 실드 파괴 후 전방 방어가 사라지며, 관통·우회로 본체 hurtbox를 직접 맞히는 공격은 실드가 남아 있어도 본체에 피해를 준다.
- Tanker는 투사체를 발사하지 않는다.
- 검증: `tests/tanker_enemy_smoke_test.gd`
