# 증강 카드 편집

`augment_card_base.tscn`은 공통 배치, `augment_card_silver.tscn`, `augment_card_gold.tscn`, `augment_card_prismatic.tscn`은 등급별 상속 씬입니다. 게임도 이 세 씬을 인스턴스화하므로 저장한 수정이 실제 선택 UI에 적용됩니다.

## 에디터에서 조정하기

1. 수정할 등급 씬을 엽니다. `@tool` 스크립트가 실행 없이 2D 화면에 재질과 장식을 그립니다.
2. 루트의 **Editor Preview**에서 `Preview Animate`를 끄면 정지합니다. `Preview Time`으로 원하는 시점을 고릅니다. `Preview Focused`를 껐다 켜면 포커스 파동을 확인할 수 있습니다.
3. `Icon`, `Title`, `Description`, `TierLabel`, `TierAccent`는 실제 Control 노드입니다. 2D 화면에서 위치·크기를 바꾸고, Label의 Theme Overrides에서 글꼴·크기·색상을 수정합니다. 씬의 예시 문구와 아이콘은 미리보기용이며 실행 시 증강 내용으로 교체됩니다. 레이아웃·색상은 유지되고 긴 문구의 글자 크기만 필요에 따라 줄어듭니다.
4. `MedallionAnchor`는 메달과 광륜 중심, `CrestAnchor`는 상단 장식, `DividerAnchor`는 본문 구분선, `OrnamentAnchor`는 하단 보석 위치입니다. Marker2D를 이동하면 장식도 따라갑니다. 아이콘은 별도 노드이므로 함께 이동하려면 두 노드를 함께 선택하세요.
5. `ParticlesArea`의 위치·크기는 입자가 떠오르는 범위입니다. 루트 **Particles**에서 개수·속도·투명도를 조정합니다.
6. 루트 **Decoration**에서 금속 장식 색상, 메달·광륜 반경, 회전 속도, 호 길이·색상, 보석 크기를 조정합니다. `Orbit Colors` 개수만큼 회전 호가 생깁니다. `Rotating Orbits Enabled`, `Static Arcs Enabled`, `Side Gems Enabled`와 **Particles → Particles Enabled**로 각 장식을 독립적으로 켭니다. 등급에 따른 제한은 없습니다.
7. `Surface` → **Material → Shader Parameters**에서 `Metal`, `Corner Cut`, `Glow Strength`, `Reflection Strength`, `Spectrum Speed`, `Halo Strength`, `Mist Strength`를 조정합니다. 각 등급의 ShaderMaterial은 독립적이며 Local To Scene이 켜져 있어 인스턴스끼리 애니메이션 상태가 섞이지 않습니다.

`Motion`, `Emphasis`, `Activation`, 크기·좌표·`Halo Radius` 셰이더 값은 스크립트가 노드와 루트 설정에서 계산합니다. 이 값은 재질에서 직접 편집하지 마세요.

셰이더와 장식에는 등급 입력이나 등급 분기가 없습니다. 등급은 선택 화면에서 어떤 씬을 로드할지만 결정합니다. 프리즘 외형은 해당 씬에 저장된 효과 설정의 조합입니다.

- `Spectrum Amount`: 무지갯빛 혼합 비율. 0은 금속색, 1은 전체 스펙트럼입니다.
- `Ray Strength` / `Ray Speed`: 방사형 회전 광선의 강도와 속도. 강도 0은 끄기, 음수 속도는 반대 방향입니다.
- `Focus Ring Strength`: 포커스 때 퍼지는 고리의 강도. 0이면 꺼집니다.
- `Base Glow` / `Base Reflection`: 기본 발광과 반사광 밝기입니다. 기존 `Glow Strength` / `Reflection Strength`는 전체 배율입니다.
- `Halo Strength` / `Mist Strength`: 원형 광채와 안개의 강도. 각각 0이면 꺼집니다.

예를 들어 골드 씬에서도 `Ray Strength`를 0.22로 설정하면 회전 광선이 나타납니다. 테두리 색을 유지하려면 `Spectrum Amount`는 0으로 둡니다. 프리즘 씬에서는 반대로 개별 강도를 0으로 내려 원하는 효과만 뺄 수 있습니다.

## 공통 변경과 등급별 변경

- 세 등급 모두의 배치를 바꾸려면 기본 씬을 수정합니다.
- 특정 등급만 바꾸려면 해당 상속 씬에서 노드 속성을 덮어씁니다. Inspector의 되돌리기 화살표로 공통 씬 값을 다시 상속할 수 있습니다.
- 현재 선택 화면은 156×188 카드에 맞춰져 있습니다. 카드 전체 크기 변경은 선택 화면의 카드 크기·회전 배치도 함께 수정해야 합니다. 내부 노드와 장식 조정은 바로 적용됩니다.
- `.gd`는 장식 도형의 구조와 동작, `.gdshader`는 빛 계산 자체를 바꿀 때만 수정하면 됩니다.

## 게임 동작 확인

`res://menus/augment_frame_test.tscn`을 열고 F6으로 실행합니다. 1~4는 혼합/실버/골드/프리즘, 방향키는 회전, Enter는 선택, R은 리롤, F5는 다시 열기입니다. 등급별 `.tscn`의 F6 실행은 카드 단독 보기이며 선택 동작은 테스트 씬에서 확인합니다.
