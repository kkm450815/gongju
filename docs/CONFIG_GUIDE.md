# 데이터 주도 설정 가이드 (Config Guide)

> 코드 수정 없이 **JSON 파일만 추가/수정**하면 새 건물·재해·축복·NPC·이벤트가 게임에 반영되도록 설계되어 있습니다. 이 문서는 각 JSON의 스키마와 예시를 정리합니다.

위치: `game/data/*.json`
인코딩: UTF-8, 들여쓰기 2칸
검증: Godot 첫 로드 시 `scripts/systems/data_loader.gd`가 스키마 검증 및 에러 로그 출력

---

## 공통 규칙

- 모든 항목은 고유 `id`(snake_case)를 가진다.
- 표시용 텍스트는 `*_key` 형태로 i18n 키만 둔다(`name_key`, `desc_key`). 실제 번역은 `game/i18n/*.csv`에 추가.
- 색상은 `#RRGGBB` 16진수.
- 좌표·거리 단위는 미터(m). 시간은 초(s).
- 아이콘·VFX 경로는 `res://...` 절대 경로.

---

## 1. `disasters.json` — 재해

```json
[
  {
    "id": "lightning",
    "name_key": "DISASTER_LIGHTNING_NAME",
    "desc_key": "DISASTER_LIGHTNING_DESC",
    "icon": "res://assets/icons/lightning.png",
    "vfx_scene": "res://scenes/powers/lightning.tscn",
    "sfx": "res://assets/sfx/thunder.ogg",
    "damage": 80,
    "radius": 5,
    "cost_faith": 10,
    "cooldown_sec": 3,
    "fear_increase": 15,
    "tags": ["weather", "instant"],
    "unlock_level": 1
  },
  {
    "id": "earthquake",
    "name_key": "DISASTER_EARTHQUAKE_NAME",
    "desc_key": "DISASTER_EARTHQUAKE_DESC",
    "icon": "res://assets/icons/earthquake.png",
    "vfx_scene": "res://scenes/powers/earthquake.tscn",
    "sfx": "res://assets/sfx/quake.ogg",
    "damage": 200,
    "radius": 30,
    "cost_faith": 80,
    "cooldown_sec": 60,
    "fear_increase": 60,
    "tags": ["geology", "area"],
    "unlock_level": 4
  }
]
```

| 필드 | 타입 | 설명 |
|---|---|---|
| `damage` | float | 건물·NPC 1회 피해량 |
| `radius` | float | 영향 반경(m) |
| `cost_faith` | float | 시전 시 소모 신력 |
| `cooldown_sec` | float | 다음 시전까지 대기 |
| `fear_increase` | float | 마을 공포 지수 증가 |
| `tags` | string[] | 필터·시너지 그룹 |
| `unlock_level` | int | 신력 레벨 |

---

## 2. `blessings.json` — 축복

```json
[
  {
    "id": "harvest",
    "name_key": "BLESSING_HARVEST_NAME",
    "desc_key": "BLESSING_HARVEST_DESC",
    "icon": "res://assets/icons/harvest.png",
    "vfx_scene": "res://scenes/powers/harvest.tscn",
    "prosperity_delta": 30,
    "duration_sec": 120,
    "radius": 20,
    "cost_faith": 25,
    "cooldown_sec": 30,
    "faith_gain_on_use": 5,
    "tags": ["economy", "farming"],
    "unlock_level": 2
  }
]
```

축복은 데미지 대신 **지표 증감**(`prosperity_delta`, `population_delta`, `health_delta`)을 갖고, `duration_sec`로 지속 시간을 둘 수 있습니다.

---

## 3. `buildings.json` — 건물

```json
[
  {
    "id": "house_small",
    "name_key": "BUILDING_HOUSE_SMALL_NAME",
    "model": "res://assets/models/buildings/house_small.glb",
    "footprint": [3, 3],
    "max_residents": 4,
    "hp": 100,
    "build_cost": 50,
    "tags": ["residential"]
  },
  {
    "id": "church",
    "name_key": "BUILDING_CHURCH_NAME",
    "model": "res://assets/models/buildings/church.glb",
    "footprint": [6, 8],
    "max_residents": 0,
    "hp": 400,
    "build_cost": 500,
    "faith_per_sec": 0.5,
    "tags": ["religious", "faith_source"]
  }
]
```

`tags`로 시스템이 분기:
- `residential` → NPC 거주
- `faith_source` → 신력 자동 증가
- `economy` → 번영도 기여
- `critical` → 파괴 시 공포 가중

---

## 4. `npcs.json` — NPC 종류

```json
[
  {
    "id": "villager",
    "name_key": "NPC_VILLAGER_NAME",
    "model": "res://assets/models/npc/villager.glb",
    "hp": 100,
    "speed": 2.5,
    "faith_contribution": 1.0,
    "fear_threshold": 80,
    "behaviors": ["work", "eat", "sleep", "pray", "flee"]
  },
  {
    "id": "priest",
    "name_key": "NPC_PRIEST_NAME",
    "model": "res://assets/models/npc/priest.glb",
    "hp": 80,
    "speed": 2.0,
    "faith_contribution": 5.0,
    "behaviors": ["pray", "preach", "heal"]
  }
]
```

`behaviors` 항목은 `scripts/entities/behaviors/<name>.gd` 파일과 1:1 매핑됩니다(예: `work.gd`). 새 행동 추가 시 파일 1개만 만들면 됨.

---

## 5. `events.json` — 랜덤 이벤트

```json
[
  {
    "id": "festival",
    "name_key": "EVENT_FESTIVAL_NAME",
    "trigger": { "type": "interval", "min_sec": 600, "max_sec": 1200 },
    "conditions": { "min_population": 30, "max_fear": 50 },
    "effects": [
      { "type": "prosperity_delta", "value": 50 },
      { "type": "faith_delta", "value": 20 }
    ],
    "duration_sec": 180
  },
  {
    "id": "plague_outbreak",
    "name_key": "EVENT_PLAGUE_NAME",
    "trigger": { "type": "random_daily", "chance": 0.05 },
    "conditions": { "min_population": 50 },
    "effects": [
      { "type": "spawn_disaster", "id": "plague", "radius": 25 }
    ],
    "duration_sec": 300
  }
]
```

---

## 6. `balance.json` — 전역 밸런스 (원격 조정 대상)

```json
{
  "version": 12,
  "faith_regen_per_sec": 0.2,
  "max_faith_base": 100,
  "max_faith_per_level": 50,
  "fear_decay_per_sec": 0.1,
  "day_length_sec": 600,
  "npc_birth_rate": 0.001,
  "npc_death_rate_base": 0.0005,
  "save_autosave_interval_sec": 60
}
```

게임 시작 시 Supabase `game_config` 테이블에서 같은 키 JSON을 받아 **버전이 더 높으면 덮어쓰기**.

---

## 7. i18n CSV 형식

`game/i18n/ko.csv`
```csv
KEY,VALUE
DISASTER_LIGHTNING_NAME,번개
DISASTER_LIGHTNING_DESC,한 점에 신의 분노를 떨어뜨립니다.
BLESSING_HARVEST_NAME,풍년
BLESSING_HARVEST_DESC,선택 지역의 농업 생산성을 일시적으로 크게 올립니다.
```

같은 KEY를 `en.csv`, `ja.csv`, `zh.csv`에도 추가. Godot의 `Project > Localization`에서 4개 파일을 등록하면 자동 인식.

---

## 8. 새 권능을 추가하는 흐름 (5분 작업)

1. `data/disasters.json` 또는 `data/blessings.json`에 항목 추가
2. `i18n/*.csv` 4개 파일에 `*_NAME` / `*_DESC` 키 추가
3. (선택) 특별한 시각효과가 필요하면 `scenes/powers/<id>.tscn` 만들고 `vfx_scene` 경로 연결
4. (선택) 일반 데미지 처리로 부족하면 `scripts/powers/<id>.gd`에 `cast()` 오버라이드
5. 게임 실행 → 권능 메뉴에 자동 등장

---

## 9. 검증 도구

`scripts/systems/data_loader.gd`가 부팅 시:
- 필수 필드 누락 → 에러 로그
- 동일 `id` 중복 → 에러
- i18n 키 누락 → 경고
- `model`/`vfx_scene` 경로 미존재 → 경고

CI에서 동일 검증을 돌리려면 `godot --headless --script tools/validate_data.gd`로 호출.
