# 신(神) 시점 마을 시뮬레이션 — 전체 제작 설명서

> 작업 코드네임: **gongju** (공주, 共主 — 마을의 운명을 함께 쥔 자)
> 장르: 신 게임(God Game) · 샌드박스 · 시뮬레이션
> 시점: 마을을 위에서 내려다보는 자유 카메라(3D 로우폴리)
> 컨셉: 현대 마을의 NPC들이 살아가고, 플레이어는 신력을 모아 **재해**(번개·지진·홍수·태풍·역병)나 **축복**(풍요·치유·번영·날씨 보정)을 내리며 마을의 흥망성쇠를 만든다.

---

## 0. 이 문서의 사용법

이 문서는 **1인 개발자가 처음부터 끝까지 따라갈 수 있는 단일 진입점**입니다. 각 섹션은 다른 세부 문서로 연결됩니다.

| 단계 | 참조 문서 |
|---|---|
| 콘텐츠(건물·재해·축복) 추가 | [`CONFIG_GUIDE.md`](./CONFIG_GUIDE.md) |
| 관리자 대시보드 만들기 | [`ADMIN_DASHBOARD.md`](./ADMIN_DASHBOARD.md) |
| UTM·인플루언서 운영 | [`MARKETING_PLAYBOOK.md`](./MARKETING_PLAYBOOK.md) |
| Supabase 스키마 적용 | [`../server/supabase/schema.sql`](../server/supabase/schema.sql) |
| 랜딩 페이지 수정 | [`../landing/README.md`](../landing/README.md) |
| Godot 프로젝트 시작 | [`../game/README.md`](../game/README.md) |

---

## 1. 게임 디자인 요약

### 1.1 핵심 루프 (30초)

1. 신력(信仰心 게이지)이 시간/공물에 따라 차오른다.
2. 플레이어가 권능(재해/축복)을 선택해 마을 어딘가에 시전.
3. NPC와 건물이 반응 → 사망·붕괴·풍년·치유 등 결과.
4. 마을 인구·신앙심·경제 지표가 갱신.
5. 일정 주기로 랜덤 이벤트(축제·외부인 방문·전염병)가 트리거.

### 1.2 핵심 자원

| 자원 | 의미 | 증가 | 감소 |
|---|---|---|---|
| **신력(Faith)** | 권능 시전 비용 | 신도 수, 공물, 기적 | 큰 권능 시전, 무차별 학살 |
| **인구(Population)** | 마을 규모 | 출산, 이주 | 사망, 도주 |
| **번영도(Prosperity)** | 경제 지표 | 풍년, 거래, 축복 | 재해, 약탈, 역병 |
| **공포(Fear)** | NPC 행동 변화 | 재해 목격 | 시간 경과 |

### 1.3 카메라/조작

- 마우스 드래그로 시점 회전, 휠로 줌인/아웃, WASD 또는 화면 가장자리 패닝
- 모바일: 두 손가락 핀치/드래그
- 스페이스바: 일시정지 / 1·2·3: 게임 속도 1×/2×/4×

### 1.4 권능(Powers) 1차 라인업

**재해**: 번개, 지진, 홍수, 태풍, 화재, 역병, 가뭄, 운석
**축복**: 풍년, 치유, 비, 햇빛, 평화의 안개, 영감(생산성), 가호(데미지 감소)

각각의 데이터 정의는 [`CONFIG_GUIDE.md`](./CONFIG_GUIDE.md) 참조.

---

## 2. 기술 스택 결정

### 2.1 엔진 선택: Godot 4.x

| 후보 | 결과 | 이유 |
|---|---|---|
| **Godot 4** ✅ | 채택 | MIT 라이선스(수수료 0), 3D, Web/Win/Mac/Linux/Android/iOS export 모두 무료, i18n 내장(CSV/PO), 1인 학습 곡선 완만 |
| Unity | 보류 | 매출 한도 초과 시 라이선스 비용, 정책 변경 이력으로 인한 신뢰 리스크 |
| Unreal | 비채택 | 3D 로우폴리에 과한 사양, 5% 로열티, 빌드 크기 큼 |
| Phaser/Three.js | 비채택 | 3D 가능하나 모바일·데스크탑 빌드 파이프라인 별도 필요 |

### 2.2 언어: GDScript (+ 필요시 C#)

- **GDScript**가 기본. 파이썬 유사 문법, 엔진 호출 직결, 핫 리로드.
- 무거운 시뮬레이션 계산이 필요해지면 일부 모듈만 **C#** 또는 **GDExtension(C++)**으로 마이그레이션. 초기에는 불필요.

### 2.3 백엔드: Supabase

- 무료 티어: DB 500MB, MAU 50K, Storage 1GB, Edge Functions 500K 호출/월
- 익명 로그인 → 사용자 ID 발급 → 통계·리더보드·원격 설정 모두 한 곳
- RLS(Row Level Security)로 클라이언트 직접 호출 안전

### 2.4 분석

- **PostHog 무료 티어** (1M 이벤트/월) — UTM 자동 파싱, 펀널, 리텐션, 세션 리플레이
- (대안) Plausible Self-host 또는 Umami — 더 가볍고 GDPR 친화

### 2.5 호스팅

| 자원 | 서비스 | 비용 |
|---|---|---|
| 랜딩·관리자 페이지 | **Cloudflare Pages** 또는 **Vercel** | 무료 |
| 게임 빌드 다운로드 (Win/Mac/Linux 설치 파일) | **Cloudflare R2** | 10GB까지 무료, egress 무료 |
| 웹 빌드(WASM) | **Cloudflare Pages** | 무료 |
| 모바일 빌드 | **Google Play / App Store** | 등록비 1회성 (Play $25, Apple $99/년) |
| DB·Auth·Storage | **Supabase** | 무료 시작 → Pro $25/월 |
| 도메인 | Cloudflare Registrar (.com 약 $10/년) | $0.83/월 |

---

## 3. 운영비 시나리오

| 단계 | MAU | 월 고정비 | 변동비 | 합계 |
|---|---|---|---|---|
| 출시 전 | 0 | 도메인 $0.83 | 0 | **~$1** |
| 베타 | 1K | $1 | 0 (전부 무료 티어) | **~$1** |
| 초기 성장 | 10K | Supabase Pro $25 + 도메인 | 0 | **~$26** |
| 본격 운영 | 50K | $25 + R2 약 $5 | PostHog Growth($0~50) | **$30~80** |
| 광고 운영 | — | 위와 동일 | 광고 예산 별도 | **별도** |

> Apple Developer($99/년)과 Google Play 등록비($25 1회)는 모바일 출시 결정 후 합산.

---

## 4. 프로젝트 구조

```
gongju/
├── README.md                      # 저장소 진입점
├── docs/                          # 문서
├── game/                          # Godot 프로젝트
│   ├── project.godot
│   ├── scenes/
│   │   ├── main.tscn
│   │   ├── town.tscn
│   │   ├── buildings/
│   │   ├── npc/
│   │   └── powers/
│   ├── scripts/
│   │   ├── systems/               # 시간·날씨·경제·신앙·재해 시스템
│   │   ├── entities/
│   │   └── powers/
│   ├── data/                      # ★ JSON 콘텐츠 (코드 수정 없이 추가)
│   │   ├── buildings.json
│   │   ├── npcs.json
│   │   ├── disasters.json
│   │   ├── blessings.json
│   │   ├── events.json
│   │   └── balance.json
│   ├── i18n/                      # ko/en/ja/zh
│   ├── addons/
│   └── assets/
├── landing/
│   └── index.html                 # 단일 파일 랜딩 페이지
├── admin/                         # Next.js 관리자 (별도 프로젝트)
└── server/
    └── supabase/
        ├── schema.sql
        └── functions/
```

---

## 5. 수정하기 쉬운 설계 원칙

### 5.1 데이터 주도 (Data-Driven)

코드와 콘텐츠를 분리합니다. **새 재해/축복/건물을 만들 때 코드 수정 없이 JSON만 추가**.

예) `data/disasters.json`에 한 줄 추가하면 게임이 자동으로 권능 메뉴에 노출하고, 시전 시 정의된 데미지·범위·이펙트로 작동.

자세한 스키마는 [`CONFIG_GUIDE.md`](./CONFIG_GUIDE.md).

### 5.2 시스템 분리

각 시스템(`time_system.gd`, `weather_system.gd`, `economy_system.gd` 등)은 **싱글톤(autoload)**으로 등록하고, 서로 **시그널(이벤트)**로만 통신합니다. 결합도 최소.

```
DisasterSystem.disaster_struck.connect(EconomySystem._on_disaster)
DisasterSystem.disaster_struck.connect(FaithSystem._on_disaster)
```

### 5.3 권능 클래스 계층

```gdscript
# scripts/powers/power_base.gd
class_name PowerBase
extends Resource

@export var id: String
@export var damage: float
@export var radius: float
@export var cost_faith: float
@export var cooldown_sec: float
@export var vfx_scene: PackedScene

func cast(target_pos: Vector3) -> void:
    pass  # override
```

새 권능은 `power_base.gd` 상속하거나 단순한 경우 JSON만으로 정의.

### 5.4 원격 밸런스

게임 시작 시 Supabase `game_config` 테이블에서 JSON 받아 로컬 `data/balance.json`을 덮어씀 → 관리자 페이지에서 수치 변경 시 다음 세션부터 적용.

### 5.5 i18n 분리

모든 UI 문자열은 `tr("KEY")`로 호출, `i18n/*.csv`에서 번역 추가. 코드 변경 없음.

---

## 6. 서버 연결 방식

**Backend-as-a-Service (BaaS) 직결** — 별도 백엔드 코드 없이 Godot이 Supabase REST를 직접 호출.

### 6.1 인증

```gdscript
# 첫 실행 시 익명 가입 → 토큰 로컬 저장
func sign_in_anonymous() -> void:
    var body = {} 
    var http = HTTPRequest.new()
    add_child(http)
    http.request(SUPABASE_URL + "/auth/v1/signup",
        ["apikey: " + SUPABASE_ANON_KEY, "Content-Type: application/json"],
        HTTPClient.METHOD_POST, JSON.stringify(body))
```

### 6.2 이벤트 전송 (배치)

성능을 위해 이벤트를 큐에 쌓고 **30초마다 배치로 전송**. 오프라인이면 큐에 누적 후 재시도.

### 6.3 보안

- 클라이언트는 익명 키만 보유. 서비스 키는 절대 클라이언트에 두지 않는다.
- RLS 정책으로 본인 user_id 행만 INSERT/SELECT 가능하도록 설정.
- 리더보드 점수는 **Edge Function**에서 검증 후 INSERT (클라 직접 INSERT 금지).

[전체 스키마: `server/supabase/schema.sql`](../server/supabase/schema.sql)

---

## 7. UTM·홍보 추적

[자세한 운영 매뉴얼: `MARKETING_PLAYBOOK.md`](./MARKETING_PLAYBOOK.md)

요약:
1. 관리자 페이지 **UTM 빌더**로 인플루언서별 링크 발급 → 짧은 코드(예: `KO-YT-001`)
2. 단축 URL `gongju.game/r/KO-YT-001` → 풀 UTM 파라미터로 302 → `visits` 테이블 기록
3. 다운로드 클릭 → `downloads` 테이블 INSERT(같은 세션 ID)
4. 관리자 대시보드에서 인플루언서별 방문→다운로드→첫 플레이→재방문 펀널 조회

---

## 8. 빌드·배포 체크리스트

### 8.1 Godot 빌드

| 플랫폼 | 출력 | 메모 |
|---|---|---|
| Web | `.html`, `.wasm`, `.pck` | Cloudflare Pages 업로드, 헤더 `Cross-Origin-Opener-Policy: same-origin` 필요 |
| Windows | `.exe` 인스톨러(NSIS) 또는 zip | Code signing은 선택 |
| macOS | `.dmg` | 공증(notarization)은 선택, Apple Developer 필요 |
| Linux | `.AppImage` | 가장 간단 |
| Android | `.apk` 또는 `.aab` | Keystore 필수, Play Store 등록 시 .aab |
| iOS | Xcode 프로젝트 export | TestFlight 우선 |

### 8.2 출시 전 체크리스트

- [ ] 4개 언어(ko/en/ja/zh) i18n CSV 누락 키 0
- [ ] `data/*.json` 스키마 검증 통과
- [ ] Supabase RLS 모든 테이블 적용 확인
- [ ] 익명 사용자 로그인 → 이벤트 INSERT 흐름 e2e 테스트
- [ ] 랜딩 페이지에서 다운로드 버튼 클릭 시 `downloads` 카운트 +1 확인
- [ ] PostHog/UTM 캡처 동작 확인(테스트 utm_source=manual)
- [ ] 개인정보처리방침·이용약관 페이지 링크
- [ ] 게임 내 "버그 신고" 버튼 → `feedback` 테이블 동작
- [ ] 모바일 세로/가로 양쪽 UI 깨짐 점검
- [ ] WASM 빌드 첫 로딩 60초 이하

---

## 9. 1인 개발 일정 가이드 (예시 12주)

| 주 | 목표 |
|---|---|
| 1 | Godot 프로젝트 셋업, 카메라·조작 프로토 |
| 2 | NPC AI 1종 + 건물 1종 + 시간 시스템 |
| 3 | 권능 1종(번개) 풀 구현, 데이터 주도 파이프라인 검증 |
| 4 | 권능 6종 추가, 신력 게이지·UI |
| 5 | 경제·신앙 시스템, 마을 성장 곡선 튜닝 |
| 6 | 사운드·VFX, 일/주/월 통계 화면 |
| 7 | i18n 4언어 1차 |
| 8 | Supabase 연결: 익명 로그인·이벤트·밸런스 원격 |
| 9 | 관리자 대시보드 v1 (UTM 빌더, 통계) |
| 10 | 랜딩 페이지·도메인·CDN 셋업, 클로즈 베타 |
| 11 | 베타 피드백 반영, 빌드 5종 export 검증 |
| 12 | 출시 마케팅 캠페인 + 정식 공개 |

---

## 10. 다음 단계

1. **Godot 4 LTS 설치** → `game/` 안에 `project.godot` 생성
2. **Supabase 프로젝트 생성** → `server/supabase/schema.sql` 적용
3. **랜딩 페이지의 `SUPABASE_URL`, `SUPABASE_ANON_KEY` 교체**
4. 도메인 구입 → Cloudflare Pages에 `landing/index.html` 배포
5. 첫 권능(번개)을 [`CONFIG_GUIDE.md`](./CONFIG_GUIDE.md) 따라 구현해보며 데이터 주도 파이프라인 검증
