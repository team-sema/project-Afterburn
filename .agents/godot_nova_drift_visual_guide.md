# Godot 4에서 Nova Drift풍 비주얼 구현하기

Nova Drift풍 화면은 단순히 블룸을 강하게 거는 방식만으로는 잘 나오지 않는다. 핵심은 **밝은 기하학적 코어**, **서로 크기가 다른 글로우 레이어**, **선명한 탄환과 궤적**, **여러 단계로 나뉜 폭발 효과**, **낮은 밝기의 우주 배경**을 함께 구성하는 것이다.

이 문서는 Godot 4에서 해당 스타일을 구현하기 위한 기본 구조와 작업 순서를 정리한다.

---

## 1. Nova Drift풍 비주얼의 핵심

대표적인 특징은 다음과 같다.

- 검은색 또는 매우 어두운 우주 배경
- 흰색에 가까운 날카로운 기하학적 도형
- 채도가 높은 단색 글로우
- 선명한 중심부와 넓고 옅은 외곽광
- 짧지만 강한 폭발과 피격 플래시
- 길고 부드러운 탄환 및 엔진 궤적
- 화면을 가득 채우되 판독성을 유지하는 색상 규칙

가장 중요한 원칙은 다음과 같다.

> 글로우는 하나의 블룸 효과가 아니라, 크기와 밝기가 다른 여러 시각 레이어의 합으로 만든다.

---

## 2. 오브젝트를 여러 글로우 레이어로 구성하기

함선, 적, 탄환 같은 주요 오브젝트는 하나의 `Sprite2D`만 사용하지 않고 여러 레이어로 나누는 편이 좋다.

```text
ShipVisual
├─ DiffuseGlow     Sprite2D
├─ WideGlow        Sprite2D
├─ TightGlow       Sprite2D
├─ Core            Sprite2D
├─ EngineTrail     GPUParticles2D
└─ Sparks          GPUParticles2D
```

각 레이어는 서로 다른 역할을 가진다.

### 2.1 Core

실제 오브젝트의 형태를 담당한다.

권장 특성:

- 흰색 또는 거의 흰색에 가까운 색
- 날카로운 삼각형, 마름모, 육각형
- 복잡한 표면 질감 최소화
- 내부 구조는 검은 선보다 투명한 절단면으로 표현
- 색상은 원본 이미지가 아니라 `self_modulate`로 적용

권장 머티리얼 설정:

```text
CanvasItemMaterial
├─ Blend Mode: Mix
└─ Light Mode: Unshaded
```

### 2.2 TightGlow

코어 바로 주변에 생기는 좁고 선명한 광원이다.

권장값:

```text
화면상 블러 반경: 약 2~5px
알파: 0.2~0.4
Blend Mode: Add
Scale: Core보다 약간 크게
```

이 레이어가 오브젝트의 윤곽을 네온처럼 보이게 만든다.

### 2.3 WideGlow

오브젝트 주변으로 넓게 퍼지는 옅은 후광이다.

권장값:

```text
화면상 블러 반경: 약 20~50px
알파: 0.05~0.15
Blend Mode: Add
```

WideGlow가 너무 강하면 여러 탄환과 적이 서로 뭉쳐 보이므로 낮은 알파를 유지한다.

### 2.4 DiffuseGlow

오브젝트 실루엣과 직접 일치하지 않는 원형 또는 타원형 확산광이다.

권장값:

```text
크기: 오브젝트의 1.5~3배
알파: 0.05~0.2
Blend Mode: Add
```

함선 뒤쪽이나 에너지 코어 부근에 배치하면 단순한 스프라이트보다 입체적인 발광 효과가 생긴다.

---

## 3. 아트 에셋 제작 방식

Nova Drift풍 에셋은 완성된 컬러 일러스트보다는 **흰색 마스크 또는 벡터 도형**에 가깝게 만드는 편이 좋다.

권장 작업 과정:

1. Inkscape, Affinity Designer, Photoshop Pen Tool 등으로 흰색 도형을 만든다.
2. 검은색 선 대신 투명한 공간을 사용해 내부 구조를 구분한다.
3. 실제 표시 크기의 2~4배 해상도로 출력한다.
4. Godot에서 축소해서 사용한다.
5. 색상은 `self_modulate`로 적용한다.
6. 동일한 원본 도형을 블러 처리해 TightGlow와 WideGlow를 만든다.

예시:

```gdscript
@export var energy_color := Color("62eaff")

func set_energy_color(color: Color) -> void:
    $Core.self_modulate = color
    $TightGlow.self_modulate = Color(color, 0.35)
    $WideGlow.self_modulate = Color(color, 0.12)
    $DiffuseGlow.self_modulate = Color(color, 0.08)
```

`self_modulate`의 알파는 텍스처의 기존 알파와 곱해진다. 따라서 원본 글로우 이미지가 이미 옅다면 코드에서 알파를 지나치게 낮추지 않는 편이 좋다.

---

## 4. HDR 2D와 블룸 설정

Godot 4에서는 2D HDR와 `WorldEnvironment`의 Glow를 사용할 수 있다.

### 4.1 HDR 2D 활성화

```text
Project Settings
└─ Rendering
   └─ Viewport
      └─ HDR 2D = On
```

설정 변경 후에는 에디터 재시작이 필요할 수 있다.

### 4.2 WorldEnvironment 설정

```text
WorldEnvironment
└─ Environment
   ├─ Background Mode = Canvas
   └─ Glow = Enabled
```

HUD와 UI는 별도의 `CanvasLayer`에 배치해 글로우 영향을 최소화하는 편이 좋다.

### 4.3 블룸의 적절한 역할

블룸은 글로우의 주된 생성 수단이 아니라 최종 보정으로 사용하는 것이 좋다.

권장 비중:

```text
글로우 형태의 70~90%: Sprite2D 레이어
최종 밝기 강조 10~30%: WorldEnvironment Glow
```

블룸만 강하게 사용하면 다음 문제가 생긴다.

- 탄환의 형태가 둥근 빛덩어리처럼 보임
- 가까운 오브젝트가 서로 뭉개짐
- 화면 전체가 회색빛 또는 우윳빛으로 뜸
- 오브젝트별 글로우 두께를 통제하기 어려움

---

## 5. 탄환 구성

탄환은 단순한 원형 스프라이트보다 Core, Glow, Trail을 분리하는 편이 좋다.

```text
Projectile
├─ CoreSprite
├─ TightGlow
├─ WideGlow
├─ Trail
└─ ImpactEmitter
```

### 권장 구성

- **Core**: 작고 밝은 마름모, 삼각형 또는 선
- **TightGlow**: 탄두 윤곽을 따라가는 강한 발광
- **WideGlow**: 진행 방향으로 약간 길게 늘어난 광원
- **Trail**: 탄두보다 어둡고 천천히 사라지는 꼬리
- **ImpactEmitter**: 충돌 시 방사형 선과 작은 불꽃 생성

탄환 전체를 밝게 만드는 것보다 중심부만 흰색으로 유지하고, 꼬리에는 주색을 적용하는 편이 판독성이 좋다.

---

## 6. 엔진과 탄환 궤적 만들기

### 6.1 GPUParticles2D가 적합한 경우

다음 효과에는 `GPUParticles2D`가 적합하다.

- 플레이어 엔진 불꽃
- 미사일 꼬리
- 작은 불꽃
- 파편
- 연속적인 에너지 잔상

권장 시작값:

```text
Lifetime: 0.2~0.5
Amount: 24~64
Explosiveness: 0
Local Coords: Off
Direction: 함선 후방
Spread: 5~15°
Scale Curve: 1 → 0
Color Ramp: 불투명 → 투명
Blend Mode: Add
```

파티클 트레일을 사용하는 경우:

```text
Trail Enabled: On
Trail Lifetime: 0.15~0.35
Trail Sections: 8~16
Trail Section Subdivisions: 2~4
```

### 6.2 Line2D가 적합한 경우

다음 효과에는 `Line2D`가 적합하다.

- 레이저
- 전기 빔
- 촉수형 에너지
- 길고 연속적인 궤적
- 정확한 형태가 필요한 무기

하나의 굵은 선 대신 세 개의 선을 겹치면 좋다.

```text
Wide Line
- 폭: 약 20
- 낮은 알파
- Blend Mode: Add

Medium Line
- 폭: 약 8
- 강한 주색
- Blend Mode: Add

Core Line
- 폭: 약 2~3
- 흰색 또는 거의 흰색
```

이 구조를 사용하면 중심부는 강하게 타오르고, 외곽은 색이 있는 네온처럼 보인다.

---

## 7. 폭발 구성

폭발은 하나의 파티클 이미터로 끝내지 않고 여러 요소를 짧은 시간차로 겹치는 편이 좋다.

```text
Explosion
├─ FlashSprite
├─ GlowSprite
├─ RingSprite
├─ StreakParticles
├─ SparkParticles
└─ DebrisParticles
```

### 7.1 구성 요소

1. **White Flash**
   - 가장 밝은 순간
   - 약 0.03~0.08초
   - 가장 먼저 사라짐

2. **Colored Radial Glow**
   - 폭발 주색을 담당
   - 약 0.1~0.2초

3. **Sharp Radial Streaks**
   - 날카로운 방사형 선
   - 짧고 빠르게 사라짐

4. **Expanding Ring**
   - 충격파 역할
   - 크기는 커지고 알파는 감소

5. **Small Sparks**
   - 작은 점 또는 선 형태
   - 약 0.3~0.5초

6. **Debris Fragments**
   - 가장 오래 남는 요소
   - 약 0.5~1초

예시 타이밍:

```text
FlashSprite:      0.05초
GlowSprite:       0.15초
RingSprite:       0.25초
StreakParticles:  0.15초
SparkParticles:   0.4초
DebrisParticles:  0.7초
```

모든 요소를 같은 시간에 사라지게 하지 않는 것이 중요하다.

---

## 8. 배경 구성

배경은 완전한 검정색보다 매우 어두운 남색이나 보라색이 좋다.

예시:

```text
기본 배경: #050716
성운 알파: 0.03~0.10
별 개수: 화면당 약 30~100개
밝은 별: 극소수
```

권장 노드 구조:

```text
Background
├─ NebulaFar
├─ StarsFar
├─ StarsMid
├─ DustParticles
└─ Planets
```

카메라 이동에 따라 서로 다른 속도로 움직이게 하면 패럴랙스가 생긴다.

가장 중요한 밝기 규칙:

> 배경의 가장 밝은 부분도 게임 플레이 오브젝트의 가장 어두운 공격보다 낮아야 한다.

배경이 지나치게 밝으면 탄환과 적의 윤곽이 묻힌다.

---

## 9. 색상 규칙

화면에 다양한 색을 사용하더라도 역할별 색상을 미리 고정하는 편이 좋다.

예시:

```text
플레이어:       청록색 또는 파란색
플레이어 공격:  플레이어색 + 흰색 중심
일반 적:        분홍색 또는 자주색
위험 공격:      주황색 또는 붉은색
보호막:         청색 또는 보라색
회복·보상:      녹색 또는 금색
```

한 오브젝트에서 사용하는 색은 보통 다음 정도로 제한한다.

```text
흰색 Core
주색 Glow
보조색 소량
```

여러 색을 동시에 강하게 사용하면 특수 공격과 일반 공격의 시각적 구분이 사라진다.

---

## 10. 타격감과 화면 피드백

Nova Drift풍 비주얼은 정지 화면보다 움직임과 반응에서 완성된다.

권장 효과:

- 피격 순간 0.02~0.06초 히트스톱
- 큰 공격에만 적용되는 화면 흔들림
- 피격 오브젝트의 흰색 플래시
- 짧게 팽창하는 충격파
- 공격 방향으로 튀는 파편
- 폭발 직후 잠깐 강해지는 글로우
- 강한 공격의 짧은 카메라 줌 펄스
- 보스 공격에 제한적으로 적용하는 색수차

화면 흔들림과 색수차는 자주 사용하면 화면이 피로해지므로 중요한 공격에만 사용한다.

---

## 11. 권장 프로토타입 제작 순서

처음부터 모든 효과를 구현하기보다 다음 순서로 진행하는 것이 효율적이다.

### 1단계: 함선

- 흰색 삼각형 또는 기하학적 함선 제작
- TightGlow 추가
- WideGlow 추가
- DiffuseGlow 추가

### 2단계: 탄환

- 밝은 Core 제작
- TightGlow와 WideGlow 추가
- GPUParticles2D 또는 Line2D 궤적 추가

### 3단계: 충돌 효과

- White Flash
- Expanding Ring
- Sparks

### 4단계: 화면 보정

- HDR 2D
- WorldEnvironment Glow
- 약한 화면 흔들림
- 히트스톱

### 5단계: 배경

- 어두운 배경색
- 별
- 성운
- 패럴랙스

이 다섯 단계만 구현해도 전체 화면의 인상은 상당히 Nova Drift 계열에 가까워진다.

---

## 12. 최소 구현 체크리스트

### 오브젝트

- [ ] Core가 흰색에 가깝다
- [ ] TightGlow가 별도 레이어로 존재한다
- [ ] WideGlow가 별도 레이어로 존재한다
- [ ] Blend Mode가 적절히 Add로 설정되어 있다
- [ ] 색상은 `self_modulate`로 조절한다

### 탄환

- [ ] 중심부가 꼬리보다 밝다
- [ ] 탄두의 형태가 블룸 속에서도 보인다
- [ ] 궤적의 알파가 자연스럽게 감소한다
- [ ] 적 공격과 플레이어 공격의 색이 구분된다

### 폭발

- [ ] 흰색 플래시가 있다
- [ ] 방사형 선 또는 불꽃이 있다
- [ ] 팽창하는 링이 있다
- [ ] 각 요소의 수명이 서로 다르다

### 배경

- [ ] 게임 플레이 요소보다 어둡다
- [ ] 별과 성운이 과도하게 밝지 않다
- [ ] 카메라 이동 시 패럴랙스가 있다

### 화면 효과

- [ ] 블룸이 오브젝트 형태를 완전히 지우지 않는다
- [ ] 화면 흔들림은 큰 충돌에만 적용한다
- [ ] UI는 글로우의 영향을 덜 받는다
- [ ] 히트스톱이 짧고 명확하다

---

## 13. 참고 자료

- Nova Drift 커스텀 스킨 및 글로우 구성 설명  
  <https://blog.novadrift.io/customskins/>

- Godot `CanvasItemMaterial` 문서  
  <https://docs.godotengine.org/en/stable/classes/class_canvasitemmaterial.html>

- Godot Environment 및 후처리 문서  
  <https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html>

- Godot `GPUParticles2D` 문서  
  <https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html>
