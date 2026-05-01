# gongju

> 마을의 신이 되어 자연재해와 축복을 내리는 3D 로우폴리 샌드박스 게임. 1인 개발 / 다국어(ko·en·ja·zh) / 웹·데스크탑·모바일 동시 배포.

## 이 저장소에 들어 있는 것

| 폴더 | 내용 |
|---|---|
| [`docs/`](./docs) | 제작 설명서 · 데이터 스키마 · 관리자 명세 · 마케팅 플레이북 |
| [`landing/`](./landing) | **다운로드 가능한 단일 파일 랜딩 페이지** (i18n + UTM 캡처 내장) |
| [`server/supabase/`](./server/supabase) | Supabase 스키마(SQL) · RLS · 기본 밸런스 시드 |
| [`game/`](./game) | Godot 4 프로젝트 부트스트랩 가이드 |

## 문서 인덱스

1. [전체 제작 설명서](./docs/PRODUCTION_MANUAL.md) — 기술 스택·아키텍처·운영비·서버 연결·일정
2. [데이터 주도 설정 가이드](./docs/CONFIG_GUIDE.md) — JSON만 추가해 새 재해/축복/건물 만들기
3. [관리자 대시보드 명세](./docs/ADMIN_DASHBOARD.md) — UTM 빌더, 게임 밸런스 원격 조정, 통계 화면
4. [마케팅 플레이북](./docs/MARKETING_PLAYBOOK.md) — UTM 명명 규칙·인플루언서 운영·체크리스트
5. [랜딩 페이지 가이드](./landing/README.md) — 배포 전 수정 항목, QA 체크리스트
6. [Godot 프로젝트 부트스트랩](./game/README.md) — 첫 빌드까지 단계별 절차

## 핵심 의사결정 요약

| 항목 | 선택 | 이유 |
|---|---|---|
| 게임 엔진 | **Godot 4** | MIT 라이선스, 3D 지원, Web/Win/Mac/Linux/Android/iOS export 모두 무료 |
| 백엔드 | **Supabase** | 무료 티어로 익명 인증·DB·RLS·Realtime 즉시 |
| 호스팅 | **Cloudflare Pages + R2** | 정적·빌드 무료, egress 무료 |
| 분석 | **PostHog 무료 + Supabase visits/downloads** | 펀널·리텐션 + 자체 진실 데이터 |
| 콘텐츠 추가 | **JSON 데이터 주도** | 코드 수정 없이 권능·건물·NPC 확장 |
| 언어 | **ko·en·ja·zh** 1차 | i18n CSV로 분리 |
| 운영비(출시 전) | **월 $1 수준** | 도메인만 유료, 나머지 무료 티어 |

## 빠르게 시작하기

```bash
# 1) 랜딩 페이지를 즉시 확인
open landing/index.html         # macOS
xdg-open landing/index.html     # Linux
start landing/index.html        # Windows

# 2) Supabase 프로젝트 만들고 스키마 적용
#    SQL Editor에 server/supabase/schema.sql 전체를 붙여넣어 실행

# 3) landing/index.html 안 CONFIG 객체에 SUPABASE_URL / ANON_KEY / DOWNLOADS 입력

# 4) Godot 4 LTS 설치 후 game/ 폴더에 새 프로젝트 생성
#    (game/README.md 절차를 그대로 따라가면 됨)
```

## 라이선스

코드와 문서: MIT (별도 표기가 없는 한)
브랜드명 "gongju" 및 로고: 사용 전 문의

## 기여

이 저장소는 1인 개발 단계입니다. 이슈·PR은 환영하지만 회신이 늦을 수 있습니다.
