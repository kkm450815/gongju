# game/ — Godot 4 프로젝트

이 폴더에는 아직 코드가 없습니다. 본 README는 **1인 개발자가 첫 빌드를 띄우기까지의 부트스트랩 절차**를 정리합니다. 본격 구현은 별도 작업으로 분리되어 있습니다.

## 0. 사전 준비

- Godot 4 LTS 다운로드: https://godotengine.org (Standard 빌드, C# 사용 시 `.NET` 빌드)
- Git LFS (모델·텍스처 용량 큰 경우 권장)

## 1. 프로젝트 생성

1. Godot 실행 → **New Project**
2. Project Path: `<repo>/game`
3. Renderer: **Forward+** (모바일에선 자동으로 Mobile 렌더러 fallback)
4. 생성 후 Editor 종료한 채 폴더 구조를 아래처럼 맞춥니다.

```
game/
├── project.godot
├── scenes/
│   ├── main.tscn
│   ├── town.tscn
│   ├── buildings/
│   ├── npc/
│   └── powers/
├── scripts/
│   ├── systems/
│   ├── entities/
│   └── powers/
├── data/
│   ├── buildings.json
│   ├── npcs.json
│   ├── disasters.json
│   ├── blessings.json
│   ├── events.json
│   └── balance.json
├── i18n/
│   ├── ko.csv
│   ├── en.csv
│   ├── ja.csv
│   └── zh.csv
├── addons/
└── assets/
    ├── models/
    ├── textures/
    └── sfx/
```

## 2. Autoload(싱글톤) 등록

`Project > Project Settings > Autoload`에서 다음을 등록:

| 이름 | 경로 | 역할 |
|---|---|---|
| `DataLoader` | `res://scripts/systems/data_loader.gd` | `data/*.json` 부팅 시 로드·검증 |
| `TimeSystem` | `res://scripts/systems/time_system.gd` | 낮/밤·계절·게임 속도 |
| `WeatherSystem` | `res://scripts/systems/weather_system.gd` | 날씨·계절 효과 |
| `EconomySystem` | `res://scripts/systems/economy_system.gd` | 번영도·생산량 |
| `FaithSystem` | `res://scripts/systems/faith_system.gd` | 신력·신앙·레벨 |
| `DisasterSystem` | `res://scripts/systems/disaster_system.gd` | 권능 시전·이벤트 |
| `RemoteConfig` | `res://scripts/systems/remote_config.gd` | Supabase에서 balance JSON 받아 덮어쓰기 |
| `Telemetry` | `res://scripts/systems/telemetry.gd` | events 배치 전송 |

## 3. i18n 등록

1. `Project > Project Settings > Localization > Translations`
2. `i18n/ko.csv`, `en.csv`, `ja.csv`, `zh.csv` 4개 파일 추가
3. 코드에서 `tr("KEY")`로 호출

CSV 형식과 키 규약은 [`../docs/CONFIG_GUIDE.md`](../docs/CONFIG_GUIDE.md#7-i18n-csv-형식) 참고.

## 4. Supabase 연결

1. Supabase 프로젝트 생성 → `../server/supabase/schema.sql` 실행
2. `scripts/systems/telemetry.gd`와 `remote_config.gd`에 `SUPABASE_URL`, `SUPABASE_ANON_KEY` 입력
3. 앱 시작 시 `auth.signInAnonymously` → access_token을 메모리 보관
4. 30초마다 `events` POST, 시작 시 `game_config` GET

## 5. Export 프리셋

`Project > Export`에서 다음 프리셋을 만들고 **자주 빌드해 회귀를 잡습니다**.

| 프리셋 | 비고 |
|---|---|
| Web | `Cross-Origin-Opener-Policy: same-origin` 헤더 필요(Cloudflare Pages `_headers`) |
| Windows Desktop | NSIS 인스톨러는 후처리 단계에서 |
| macOS | 공증은 출시 직전 단계에서 |
| Linux/X11 | AppImage가 가장 간단 |
| Android | Keystore 별도 관리 |
| iOS | Xcode 프로젝트 export 후 Apple Developer 계정 필요 |

## 6. 첫 권능(번개) 만들기 — 데이터 주도 검증용

1. `data/disasters.json`에 `lightning` 항목 추가 ([CONFIG_GUIDE.md](../docs/CONFIG_GUIDE.md) 예시)
2. `i18n/*.csv` 4개에 `DISASTER_LIGHTNING_NAME`/`_DESC` 키 추가
3. `scenes/powers/lightning.tscn` 만들기 (간단한 GPUParticles3D + 라이트 1개로 충분)
4. 게임 실행 → 권능 메뉴에 자동 노출, 클릭 후 마을 클릭 → 시전

여기까지 동작하면 **모든 후속 권능은 코드 수정 없이 JSON + i18n 키만으로 추가** 가능합니다.

## 7. 다음 단계

- 본격 시스템 구현은 `docs/PRODUCTION_MANUAL.md` §9 일정 가이드 참조
- 콘텐츠 추가는 `docs/CONFIG_GUIDE.md`만 보면 됨
