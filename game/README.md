# game/ — Godot 4 프로젝트

이 폴더에는 **F5 한 번이면 즉시 동작하는 MVP 스켈레톤**이 들어 있습니다. 3D 카메라, 마을 바닥, NPC·건물 자동 스폰, 권능 시전 4종, 신력/공포/번영 게이지, 4언어 i18n, Supabase 연동(선택)까지 코드로 구현되어 있습니다. 모델은 직접 그리지 않고 **CC0 무료 라이브러리(Kenney·Quaternius)**를 그대로 사용합니다.

## 0. 실행 (3분)

1. https://godotengine.org 에서 **Godot 4.2 이상** 다운로드 (Standard 빌드)
2. Godot Project Manager → **Import** → 이 폴더의 `project.godot` 선택
3. F5 (또는 ▶ 버튼) — 메인 씬으로 자동 지정되어 있어 별도 설정 불필요
4. 실행 화면:
   - 위에서 내려다보는 마을 (컬러 큐브들이 건물·NPC, 에셋 받기 전 fallback)
   - 좌상단: 신력·인구·번영·공포 게이지
   - 하단: 재해/축복 버튼
   - 우상단: 일시정지·1×/2×/4× 속도·언어 토글

## 1. 조작

| 입력 | 동작 |
|---|---|
| 마우스 휠 | 줌인/아웃 |
| **우클릭 드래그** | 카메라 회전 (yaw + pitch) |
| **마우스 휠 누르고 드래그** | 카메라 위치 이동 (pan) |
| W/A/S/D | 카메라 이동 (키보드) |
| 권능 버튼 → 좌클릭 | 해당 위치에 권능 시전 |
| Space | 일시정지 토글 |
| 1 / 2 / 3 | 속도 1× / 2× / 4× |
| F2 | 즉시 저장 (`user://save.json`) |
| F3 | 마지막 저장에서 불러오기 |
| F4 | 저장 파일 삭제 + 새 게임 시작 |

## 1-1. 테스트 모드 (신력 무제한)

`game/data/balance.json`에 `"infinite_faith": true`가 들어가 있으면 신력이 항상 100%로 유지되어 모든 권능을 무제한 시전할 수 있습니다. 출시 전에 false로 바꾸세요.

## 2. 무료 3D 라이브러리 적용 (예쁘게 만들기)

게임이 컬러 큐브로 보일 때, [`assets/README.md`](./assets/README.md)의 안내에 따라 Kenney 팩을 받아 `assets/kenney/`에 풀어 넣으면 자동으로 모델이 표시됩니다.

추천 다운로드 (모두 CC0):
- **Kenney City Kit (Suburban / Commercial)**: 건물
- **Kenney Mini Characters / Toon Characters**: NPC
- **Kenney Nature Kit**: 나무·바위
- **Mixamo**: 걷기·기도·도주 애니메이션 (Adobe 무료)

`data/buildings.json`과 `data/npcs.json`의 `model` 경로를 받은 파일 이름과 맞춰주세요. 경로가 안 맞으면 그냥 fallback 큐브로 표시되니 게임이 멈추지 않습니다.

## 3. 폴더 구조

```
game/
├── project.godot               # 자동로드 9개 등록 + 입력 매핑
├── scenes/main.tscn            # 빈 Node3D + main.gd 부착
├── scripts/
│   ├── main.gd                 # 월드 빌더 + 입력 + 권능 시전
│   ├── systems/                # 9개 autoload (싱글톤)
│   │   ├── data_loader.gd      # data/*.json 로드
│   │   ├── i18n.gd             # i18n/*.csv 로드 + I18N.t("KEY")
│   │   ├── time_system.gd      # 일자·속도·일시정지
│   │   ├── weather_system.gd
│   │   ├── economy_system.gd   # 번영도
│   │   ├── faith_system.gd     # 신력 + 공포
│   │   ├── disaster_system.gd  # 권능 시전 → 데미지/치유 신호
│   │   ├── remote_config.gd    # Supabase에서 밸런스 fetch (선택)
│   │   └── telemetry.gd        # 30초 배치로 events POST (선택)
│   ├── entities/
│   │   ├── npc.gd              # CharacterBody3D, 무작위 wander/flee
│   │   └── building.gd         # StaticBody3D, HP·passive 보너스
│   ├── powers/
│   │   └── power_vfx.gd        # 데이터 주도 시각효과
│   └── ui/
│       └── hud.gd              # 코드로 그린 in-game UI
├── data/                       # ★ JSON만 추가하면 콘텐츠 확장
├── i18n/                       # ko/en/ja/zh CSV
└── assets/                     # Kenney 팩 등을 여기에
```

## 4. 콘텐츠 추가 (코드 수정 없음)

새 재해/축복/건물/NPC를 추가하려면 [`../docs/CONFIG_GUIDE.md`](../docs/CONFIG_GUIDE.md)를 참조하세요. JSON에 한 항목 추가 + i18n CSV 4개에 키 추가만으로 게임에 즉시 등장합니다.

## 5. Supabase 연동 (선택)

게임이 통계와 원격 밸런스를 사용하게 하려면:

1. Supabase 무료 프로젝트 생성 → SQL Editor에 `../server/supabase/schema.sql` 적용
2. `scripts/systems/remote_config.gd`와 `telemetry.gd` 상단의 상수를 채움:
   ```gdscript
   const SUPABASE_URL := "https://xxxx.supabase.co"
   const SUPABASE_ANON_KEY := "eyJ..."
   ```
3. F5 — 30초 후 Supabase `events` 테이블에 `session_start` 행, `power_cast` 행 INSERT 확인

비워두면 모든 네트워크 호출은 스킵되고 게임은 오프라인으로 동작합니다.

## 6. Export (출시 빌드)

`Project > Export`에서 프리셋 추가:

| 플랫폼 | 비고 |
|---|---|
| Web | `Cross-Origin-Opener-Policy: same-origin` 헤더(Cloudflare Pages `_headers`) |
| Windows Desktop | NSIS 인스톨러 후처리 |
| macOS | 출시 직전 공증(notarization) |
| Linux/X11 | AppImage 권장 |
| Android | Keystore 별도 |
| iOS | Xcode export → TestFlight |

## 7. 구현된 기능 (현재)

- ✅ 3D 카메라 (yaw+pitch orbit, middle-pan, WASD, wheel zoom)
- ✅ **낮/밤 사이클** — 태양이 시간에 따라 회전, 색·강도·앰비언트 변화
- ✅ **절차적 캐릭터** — 머리·몸·팔·다리·머리카락·눈·입까지 조합 (라이브러리 없어도 사람 형태)
- ✅ **절차적 건물** — 본체·삼각 지붕·창문·문, 교회는 첨탑+십자가, 상점은 간판
- ✅ **자동차** — 도로 위를 차선 따라 왕복, 헤드라이트·바퀴 포함
- ✅ **나무 절차 생성** — 줄기 + 3단 잎사귀, 무작위 색상/크기
- ✅ **NPC 인격 시스템** — 각자 직업(농부/의사/대장장이/상인…)과 취미(낚시/요리/그림…) 보유, 머리 위 이모지 말풍선으로 표시
- ✅ **감정 반응** — 재해 시 떨림 + 😱, 축복 시 점프 + ❤️
- ✅ **절차적 사운드** — Kenney 파일 없어도 즉석에서 합성 (번개=노이즈 버스트, 치유=벨, 풍년=아르페지오)
- ✅ NPC AI 상태머신 (WANDER / GO_HOME / AT_HOME / GO_WORK / AT_WORK / GO_PRAY / PRAYING / FLEE)
- ✅ TownRegistry로 건물 분류 (residential/economy/religious/nature)
- ✅ 권능 시전 (재해 4종·축복 3종)
- ✅ 신력·공포·번영·인구 게이지 + 신력 무제한 테스트 모드
- ✅ 4언어 i18n (ko/en/ja/zh)
- ✅ SaveSystem — 60초마다 자동 저장 + F2/F3/F4 수동 조작
- ✅ Telemetry / RemoteConfig — Supabase 키 입력 시 활성화
- ✅ Kenney CC0 모델로 자동 업그레이드 — `tools/setup_assets.sh` 사용

## 8. 알려진 한계

- 결혼·출산·노화 등 인구 동역학 미구현(인구는 현재 정적)
- 사운드 라이브러리는 Kenney 파일을 받아 `assets/kenney/sfx/`에 넣어야 활성
- 멀티플레이 미구현
- 모바일 터치 입력 미세조정 필요(현재는 데스크탑 마우스 위주)

12주 풀 일정은 [`../docs/PRODUCTION_MANUAL.md`](../docs/PRODUCTION_MANUAL.md) §9 참조.
