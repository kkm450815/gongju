# assets/ — 무료 3D 라이브러리 사용 가이드

이 게임은 **CC0 라이선스 무료 에셋 팩**을 그대로 사용합니다. 모델을 직접 그리지 않습니다.
빈 상태로도 게임은 컬러 큐브로 fallback 동작하므로, 천천히 받아서 채워 넣으면 됩니다.

## 0. 권장 에셋 (모두 CC0, 출처 표기 의무 없음)

### 캐릭터(NPC)
| 팩 | 사용처 | URL |
|---|---|---|
| **Kenney — Mini Characters 1** | 마을 주민 기본형 | https://kenney.nl/assets/mini-characters-1 |
| **Kenney — Toon Characters 1** | 신부·아이 등 변형 | https://kenney.nl/assets/toon-characters-1 |
| **Quaternius — Ultimate Modular Men** | 더 다양한 외형 | https://quaternius.com/packs/ultimatemodularmen.html |

### 건물
| 팩 | 사용처 | URL |
|---|---|---|
| **Kenney — City Kit (Suburban)** | 주택 · 정원 | https://kenney.nl/assets/city-kit-suburban |
| **Kenney — City Kit (Commercial)** | 상점 · 간판 | https://kenney.nl/assets/city-kit-commercial |
| **Kenney — City Kit (Roads)** | 도로 · 교차로 | https://kenney.nl/assets/city-kit-roads |

### 자연
| 팩 | URL |
|---|---|
| **Kenney — Nature Kit** (나무·바위·풀) | https://kenney.nl/assets/nature-kit |
| **Quaternius — Nature Pack** | https://quaternius.com/packs/stylizednatureulitmate.html |

### 애니메이션 (걷기·기도·도주)
| 도구 | 사용처 | URL |
|---|---|---|
| **Mixamo** (Adobe 무료 계정) | 캐릭터에 idle/walk/run/pray/die 리타깃 | https://www.mixamo.com |

### 사운드
| 팩 | URL |
|---|---|
| **Kenney — Impact Sounds** | https://kenney.nl/assets/impact-sounds |
| **Kenney — UI Audio** | https://kenney.nl/assets/ui-audio |
| **Freesound.org** (개별 검색, CC0 필터) | https://freesound.org |

## 1. 폴더 규약

다운로드 후 압축을 풀어 다음 위치에 그대로 넣어주세요. **GLB(.glb) 형식 권장** (Godot 4가 가장 잘 지원).

```
assets/
├── kenney/
│   ├── characters/
│   │   ├── character_male_a.glb
│   │   ├── character_female_a.glb
│   │   └── ...
│   ├── buildings/
│   │   ├── house_type01.glb
│   │   ├── shop_type01.glb
│   │   └── ...
│   ├── roads/
│   ├── nature/
│   │   ├── tree_oak.glb
│   │   └── rock_small.glb
│   └── sfx/
│       ├── thunder.ogg
│       └── ui_click.ogg
├── quaternius/
│   └── ...
└── animations/
    └── walk.glb (Mixamo export)
```

`data/buildings.json`과 `data/npcs.json`은 이 경로 규약을 따라 작성되어 있습니다. 다른 폴더에 두려면 JSON 의 `model` 필드만 바꾸면 됩니다.

## 2. Kenney 팩이 FBX로 받아진다면

Godot 4는 **GLB가 가장 안정적**입니다. Kenney 팩은 GLB 버전이 함께 들어 있는 경우가 많습니다(`Models/GLB/`). 만약 FBX밖에 없다면 [Blender](https://www.blender.org)에서 한 번 열어 GLB로 export 하세요. (1분 작업)

## 3. fallback 동작

`scripts/entities/npc.gd`와 `scripts/entities/building.gd`는 다음과 같이 동작합니다:

```gdscript
func _ready():
    var path = data.get("model", "")
    if ResourceLoader.exists(path):
        var scene = load(path)
        add_child(scene.instantiate())
    else:
        # fallback: 단색 박스
        var mesh = MeshInstance3D.new()
        mesh.mesh = BoxMesh.new()
        var mat = StandardMaterial3D.new()
        mat.albedo_color = data.get("fallback_color", Color.AQUA)
        mesh.material_override = mat
        add_child(mesh)
```

→ **에셋이 없어도 게임은 멈추지 않습니다.** 빈 상태에서 색깔 다른 박스들로 마을을 보고, 천천히 Kenney 팩을 채워 넣으면 점점 예뻐집니다.

## 4. 라이선스 한 줄 요약

- **Kenney**: CC0 (출처 표기 불필요, 상업용 가능)
- **Quaternius**: CC0
- **Mixamo**: 무료 사용 가능, 게임 내 사용 OK (Adobe 계정 필요)

상업 출시 시에도 추가 비용·로열티 없습니다. 단, 패키징 시 `assets/THIRDPARTY.md`에 사용 팩 목록과 URL을 적어두기를 권장합니다(법적 의무는 아니지만 매너).
