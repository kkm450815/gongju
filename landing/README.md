# landing/ — gongju 랜딩 페이지

`index.html` 한 파일로 동작하는 자체 완결 랜딩입니다. **그대로 다운로드하여 더블클릭만 해도** 4개 언어 UI와 UTM 캡처가 동작합니다.

## 구성

- `index.html` — 단일 파일 (HTML + CSS + JS + i18n 사전 모두 인라인)
  - 다국어: ko/en/ja/zh, 우상단 토글 + 브라우저 언어 자동 감지
  - UTM 캡처: `utm_source/medium/campaign/content/term`, `ref` → `localStorage` + Supabase `visits` POST
  - 다운로드 트래킹: 버튼 클릭 시 `downloads` 테이블 INSERT
  - 뉴스레터: 이메일 검증 후 `newsletter` 테이블 INSERT
  - OS 자동 감지 → 본인 OS 다운로드 버튼 강조
  - 반응형, prefers-reduced-motion 대응, OG 메타 포함

## 배포 전 필수 수정 4가지

`index.html` 안의 `CONFIG` 객체를 본인 값으로 교체하세요.

```js
const CONFIG = {
  SUPABASE_URL:      "https://xxxxx.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOi...",      // anon key (service key 절대 X)
  DOWNLOADS: {
    windows: "https://r2.gongju.game/builds/gongju-win-x64.zip",
    macos:   "https://r2.gongju.game/builds/gongju-mac.dmg",
    linux:   "https://r2.gongju.game/builds/gongju-linux.AppImage",
    android: "https://play.google.com/store/apps/details?id=game.gongju",
    ios:     "https://apps.apple.com/app/idXXXXXXXXX",
    web:     "https://play.gongju.game"
  }
};
```

`SUPABASE_URL`이 비어 있으면 네트워크 호출은 모두 스킵되며, 페이지는 로컬 파일로도 정상 동작합니다(개발용).

## 호스팅 옵션

| 방법 | 절차 |
|---|---|
| **Cloudflare Pages** (추천) | 저장소 연결 → Build command 비우고 Output directory `landing/` |
| **Vercel** | New Project → `landing/` 디렉터리 import → Framework `Other` |
| **Netlify** | drag&drop으로 `landing/` 업로드 |
| **자체 호스팅** | 어디든 정적 파일 서빙. 단 HTTPS 필수(crypto.randomUUID 사용) |

## QA 체크리스트

- [ ] `?utm_source=test&utm_medium=plan&utm_campaign=verify&ref=KO-YT-001` 으로 접속 → DevTools Application > LocalStorage 에 `gongju.utm` 저장 확인
- [ ] 4개 언어 토글 시 모든 텍스트 변경
- [ ] 모바일 뷰(360×640)에서 레이아웃 깨짐 없음
- [ ] OS별 다운로드 버튼 클릭 시 콘솔에 `[gongju] download {os}` 로그
- [ ] Supabase 키 입력 후 `visits` 테이블에 행 INSERT 확인
- [ ] 잘못된 이메일 입력 시 빨간 에러 메시지

## 단축 URL `/r/<code>` 만들기 (선택)

Cloudflare Pages Functions에 다음 파일을 추가하면 단축 URL이 동작합니다:

`landing/functions/r/[code].ts`
```ts
export const onRequest: PagesFunction<{SUPABASE_URL:string, SUPABASE_ANON_KEY:string}> =
  async ({ params, env, request }) => {
    const code = params.code as string;
    const r = await fetch(
      `${env.SUPABASE_URL}/rest/v1/utm_links?short_code=eq.${encodeURIComponent(code)}&disabled=eq.false&select=*`,
      { headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${env.SUPABASE_ANON_KEY}` } }
    );
    const rows = await r.json();
    if (!rows[0]) return Response.redirect("https://gongju.game", 302);
    const link = rows[0];
    const url = new URL("https://gongju.game" + (link.path || "/"));
    for (const k of ["source","medium","campaign","content","term"]) {
      if (link[k]) url.searchParams.set(`utm_${k}`, link[k]);
    }
    url.searchParams.set("ref", code);
    return Response.redirect(url.toString(), 302);
  };
```

환경변수 `SUPABASE_URL`/`SUPABASE_ANON_KEY`을 Cloudflare Pages 프로젝트 설정에 추가하세요.
