# 관리자 대시보드 명세서

`https://admin.gongju.game` (또는 `gongju.game/admin`)

스택: **Next.js 14 (App Router) + Supabase + Recharts + Tailwind**
인증: Supabase Auth + `profiles.role = 'admin'` 행만 통과 (서버 측 미들웨어 검증)

---

## 화면 구성

### 1. 로그인 (`/admin/login`)
- 이메일·비밀번호 또는 매직링크
- 1회 가입 후 직접 DB에서 `role = 'admin'` 부여 (자가 가입 차단)

### 2. 개요 (`/admin`)

상단 KPI 카드 6개:
| 카드 | 지표 |
|---|---|
| 오늘 방문 | `visits` 24h count |
| 오늘 다운로드 | `downloads` 24h count |
| DAU | 24h 고유 user_id |
| MAU | 30d 고유 user_id |
| 전환율 | downloads / visits (24h) |
| 신규 가입 | `auth.users` 24h |

차트:
- **일 단위 방문/다운로드 라인 차트** (최근 30일)
- **시간대별 활성 사용자 히트맵**

### 3. 유입 분석 (`/admin/traffic`)

UTM 그룹별 표 + 펀널:
| utm_source | utm_medium | utm_campaign | 방문 | 다운로드 | 첫 플레이 | D1 재방문 | D7 재방문 |
|---|---|---|---|---|---|---|---|
| youtube | video | launch_2026q2 | 1,240 | 320 | 280 | 110 | 40 |
| twitter | social | launch_2026q2 | 800 | 150 | 130 | 50 | 18 |

필터: 기간(7/30/90일), source/medium/campaign 다중 선택, utm_content별 드릴다운.

### 4. 인플루언서 (`/admin/creators`)

표:
| ID | 이름 | 플랫폼 | 짧은코드 | 풀 URL | 클릭 | 다운로드 | 전환율 | QR |
|---|---|---|---|---|---|---|---|---|
| C-001 | 홍길동 | YouTube | KO-YT-001 | (복사) | 1,240 | 320 | 25.8% | (다운로드) |

각 행 액션: 링크 복사·QR 다운로드·메모·비활성화

### 5. UTM 빌더 (`/admin/utm-builder`)

폼:
- 소스(드롭다운: youtube, twitter, instagram, tiktok, blog, newsletter, manual)
- 매체(드롭다운: video, social, email, cpc, cpm, organic)
- 캠페인(자유 입력 + 최근 사용 자동완성)
- 콘텐츠(인플루언서 ID 또는 자유 입력)
- 키워드(선택)
- 랜딩 경로(/, /download, /press)

생성:
- 풀 URL: `https://gongju.game/?utm_source=...&utm_medium=...`
- 짧은 코드: `KO-YT-NNN` (소스·언어 자동 prefix + 일련번호)
- 단축 URL: `gongju.game/r/<짧은코드>`
- QR 코드 PNG 즉시 다운로드

저장: `utm_links` 테이블

### 6. 게임 밸런스 (`/admin/balance`)

`game_config` 테이블의 JSON 키-값 편집기:
- 슬라이더(min/max 메타 포함된 키)
- 숫자 입력
- JSON raw 편집(고급)
- "발행" 버튼 → `version` 1 증가, 다음 게임 세션부터 적용
- "롤백" 버튼 → 직전 버전 복구

변경 이력 표(누가, 언제, 무엇을).

### 7. 공지·이벤트 푸시 (`/admin/announcements`)

폼:
- 제목/본문(다국어 4개 언어 탭)
- 노출 기간(시작~종료)
- 대상: 전체 / 특정 언어 / 특정 OS / 특정 utm_source
- 노출 위치: 게임 내 토스트 / 메인 메뉴 배너 / 랜딩 페이지 띠

저장 시 `announcements` 테이블 INSERT, Supabase Realtime 구독으로 게임이 즉시 반영.

### 8. 리텐션·코호트 (`/admin/retention`)

PostHog 임베드 또는 자체 SQL:
- D1/D7/D30 코호트 표
- utm_source별 D7 비교 막대 차트

### 9. 피드백·버그 (`/admin/feedback`)

`feedback` 테이블 표시:
- 상태(신규/처리중/완료) · 카테고리 · 작성자 · 본문 · 첨부 스크린샷
- 답변 필드 → 사용자에게 게임 내 받은 알림으로 전달

### 10. 다운로드 트래킹 (`/admin/downloads`)

OS별·언어별·UTM별 다운로드 카운트 표 + 일별 라인 차트.

---

## DB 스키마 요약 (전체는 `server/supabase/schema.sql`)

```
visits          (id, user_id, session_id, utm_source, utm_medium,
                 utm_campaign, utm_content, utm_term, ref_code,
                 ua, lang, country, path, referrer, created_at)

downloads       (id, session_id, user_id, os, lang, ref_code, created_at)

events          (id, user_id, type, payload jsonb, created_at)
                  -- type: session_start, level_up, power_cast, ...

utm_links       (id, source, medium, campaign, content, term, path,
                 short_code unique, created_by, created_at, disabled)

creators        (id, name, platform, contact, notes, short_code_prefix,
                 created_at, disabled)

game_config     (key text PK, value jsonb, version int,
                 updated_by, updated_at)

config_history  (id, key, value jsonb, version, updated_by, updated_at)

announcements   (id, title_i18n jsonb, body_i18n jsonb, audience jsonb,
                 starts_at, ends_at, location, created_at)

feedback        (id, user_id, category, body, screenshot_url, status,
                 reply, created_at, replied_at)

profiles        (user_id PK, role text default 'user',
                 created_at)
```

---

## 권한(RLS) 정책 요약

| 테이블 | anon (게임 클라이언트) | admin |
|---|---|---|
| `visits` | INSERT only | SELECT all |
| `downloads` | INSERT only | SELECT all |
| `events` | INSERT only(자기 user_id) | SELECT all |
| `utm_links` | SELECT(`disabled = false`) | ALL |
| `creators` | SELECT(공개 필드만 view 통해) | ALL |
| `game_config` | SELECT all | ALL |
| `announcements` | SELECT(현재 노출 기간만 view 통해) | ALL |
| `feedback` | INSERT only(자기 user_id) | ALL |
| `profiles` | SELECT(자기) | ALL |

---

## 단축 URL 라우팅 (`/r/<short_code>`)

Cloudflare Pages Function 또는 Supabase Edge Function 1개:

```ts
// /functions/r/[code].ts (Cloudflare Pages Function)
export const onRequest: PagesFunction = async ({ params, request, env }) => {
  const code = params.code as string;
  const link = await env.DB.prepare("SELECT * FROM utm_links WHERE short_code = ? AND disabled = false")
                           .bind(code).first();
  if (!link) return Response.redirect("https://gongju.game", 302);

  // 클릭 카운트
  await env.DB.prepare("INSERT INTO visits (ref_code, ...) VALUES (?, ...)").bind(code, /*...*/).run();

  const url = new URL("https://gongju.game" + link.path);
  url.searchParams.set("utm_source", link.source);
  url.searchParams.set("utm_medium", link.medium);
  url.searchParams.set("utm_campaign", link.campaign);
  if (link.content) url.searchParams.set("utm_content", link.content);
  if (link.term) url.searchParams.set("utm_term", link.term);
  url.searchParams.set("ref", code);

  return Response.redirect(url.toString(), 302);
};
```

> Cloudflare D1 대신 Supabase REST를 fetch해도 무방. 응답 시간이 50ms 이하면 OK.

---

## 배포

1. `admin/` 폴더에 Next.js 14 프로젝트 초기화 (별도 작업)
2. Vercel 또는 Cloudflare Pages 연결, 환경변수에 `SUPABASE_URL`/`SUPABASE_SERVICE_KEY`(서버 측만)
3. `gongju.game/admin` 또는 `admin.gongju.game` 서브도메인 연결
4. Supabase Auth에서 Admin 이메일 1개 생성 → SQL로 `profiles.role = 'admin'` 직접 설정

---

## 우선순위 v1 → v2 → v3

| 버전 | 포함 화면 |
|---|---|
| v1 (출시 전) | 로그인, 개요, UTM 빌더, 인플루언서 표, 다운로드 트래킹 |
| v2 (베타) | 유입 분석 펀널, 게임 밸런스 편집기, 공지 푸시 |
| v3 (성장기) | 리텐션·코호트, 피드백 인박스 답변, A/B 테스트 |
