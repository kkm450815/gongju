import { requireAdmin } from "@/lib/auth";
import { adminClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

const OS_LIST = ["windows", "macos", "linux", "android", "ios", "web"] as const;

export default async function Page() {
  await requireAdmin();
  const sb = adminClient();

  const since30d = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString();
  const { data } = await sb
    .from("downloads")
    .select("os, lang, ref_code, created_at")
    .gte("created_at", since30d)
    .order("created_at", { ascending: false })
    .limit(2000);

  const rows = data ?? [];

  // aggregate by OS
  const byOs: Record<string, number> = {};
  for (const o of OS_LIST) byOs[o] = 0;
  rows.forEach((r: any) => { byOs[r.os] = (byOs[r.os] ?? 0) + 1; });

  // aggregate by ref_code
  const byRef: Record<string, number> = {};
  rows.forEach((r: any) => {
    const k = r.ref_code ?? "(none)";
    byRef[k] = (byRef[k] ?? 0) + 1;
  });
  const refRows = Object.entries(byRef).sort((a, b) => b[1] - a[1]).slice(0, 30);

  // aggregate by language
  const byLang: Record<string, number> = {};
  rows.forEach((r: any) => {
    const k = (r.lang ?? "—").slice(0, 2);
    byLang[k] = (byLang[k] ?? 0) + 1;
  });

  return (
    <>
      <h1>다운로드</h1>
      <p style={{ color: "var(--fg-dim)" }}>최근 30일, 최대 2,000건 표본 기준.</p>

      <h2>OS별</h2>
      <div className="cards" style={{ gridTemplateColumns: "repeat(6,1fr)" }}>
        {OS_LIST.map(o => (
          <div key={o} className="card">
            <div className="label">{o}</div>
            <div className="value">{byOs[o] ?? 0}</div>
          </div>
        ))}
      </div>

      <h2>언어별</h2>
      <table>
        <thead><tr><th>언어</th><th>다운로드</th></tr></thead>
        <tbody>
          {Object.entries(byLang).sort((a, b) => b[1] - a[1]).map(([k, v]) => (
            <tr key={k}><td>{k}</td><td>{v}</td></tr>
          ))}
        </tbody>
      </table>

      <h2>짧은 코드별 상위 30개</h2>
      <table>
        <thead><tr><th>ref_code</th><th>다운로드</th></tr></thead>
        <tbody>
          {refRows.map(([k, v]) => (
            <tr key={k}><td className="mono">{k}</td><td>{v}</td></tr>
          ))}
        </tbody>
      </table>
    </>
  );
}
