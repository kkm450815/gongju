# admin/ — gongju 관리자 대시보드

Next.js 14 + Supabase로 만든 내부 운영 도구입니다. 별도 호스트(예: `admin.gongju.game` 또는 Vercel)에 배포해 `gongju.game` 본 도메인과 분리하세요.

## 화면

| 경로 | 내용 |
|---|---|
| `/login` | 이메일/비밀번호 로그인 (`profiles.role = 'admin'` 행 필요) |
| `/` | 24h KPI 카드 6개 + UTM 펀널 상위 20개 |
| `/utm-builder` | 새 캠페인 링크 생성 → `utm_links` INSERT, 짧은 코드 자동 생성, QR 다운로드 |
| `/creators` | `v_creator_stats` 뷰 기반 인플루언서별 방문/다운로드/전환율 |
| `/downloads` | OS·언어·짧은코드별 30일 다운로드 통계 |

## 셋업 (5분)

```bash
cd admin
cp .env.example .env.local
# .env.local 편집: NEXT_PUBLIC_SUPABASE_URL / ANON_KEY / SUPABASE_SERVICE_ROLE_KEY 채우기

npm install        # 또는 pnpm i, yarn
npm run dev        # http://localhost:3001
```

`server/supabase/schema.sql`이 적용된 Supabase 프로젝트가 필요합니다.

## admin 권한 부여

가입 후, Supabase SQL Editor에서:

```sql
insert into profiles (user_id, role, display_name)
values ('<auth.users 의 본인 uuid>', 'admin', 'me')
on conflict (user_id) do update set role = 'admin';
```

## 배포

| 호스트 | 절차 |
|---|---|
| **Vercel** (추천) | `admin/`을 root로 import, 환경변수 3개 설정 |
| **Cloudflare Pages** | Build command `npm run build`, output `.next` |
| **자체 호스팅** | `npm run build && npm start` (포트 3001) |

## 보안 메모

- `SUPABASE_SERVICE_ROLE_KEY`는 **서버 측에서만** 사용됩니다. `lib/supabase.ts`의 `adminClient()`만 이 키를 씁니다.
- `lib/auth.ts`의 `requireAdmin()`이 모든 admin 페이지 진입 시 `profiles.role = 'admin'` 검증합니다.
- 자가 가입을 통한 권한 상승을 막기 위해, admin 권한은 항상 SQL로 직접 설정하세요.

## 다음 (v2 / v3)

| 버전 | 추가 기능 |
|---|---|
| v2 | 게임 밸런스 편집기 (`game_config` JSON), 공지·이벤트 푸시, 인플루언서 추가 폼 |
| v3 | 리텐션·코호트 차트(Recharts), 피드백 인박스 답변, A/B 테스트 |
