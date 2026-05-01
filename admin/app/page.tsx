import { requireAdmin } from "@/lib/auth";
import { adminClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type KPIs = {
  visits24: number;
  downloads24: number;
  dau: number;
  mau: number;
  signups24: number;
};

async function getKPIs(): Promise<KPIs> {
  const sb = adminClient();
  const since24 = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
  const since30d = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString();

  const [v24, d24, dauRes, mauRes, signups] = await Promise.all([
    sb.from("visits").select("id", { count: "exact", head: true }).gte("created_at", since24),
    sb.from("downloads").select("id", { count: "exact", head: true }).gte("created_at", since24),
    sb.from("events").select("user_id").gte("created_at", since24),
    sb.from("events").select("user_id").gte("created_at", since30d),
    sb.from("profiles").select("user_id", { count: "exact", head: true }).gte("created_at", since24),
  ]);

  const dau = new Set((dauRes.data ?? []).map((r: any) => r.user_id)).size;
  const mau = new Set((mauRes.data ?? []).map((r: any) => r.user_id)).size;
  return {
    visits24: v24.count ?? 0,
    downloads24: d24.count ?? 0,
    dau,
    mau,
    signups24: signups.count ?? 0,
  };
}

async function getFunnel(): Promise<Array<{
  source: string; medium: string; campaign: string; visits: number; downloads: number; conv: number;
}>> {
  const sb = adminClient();
  const { data } = await sb.from("v_utm_funnel").select("*").order("visits", { ascending: false }).limit(20);
  return (data ?? []).map((r: any) => ({
    source: r.utm_source ?? "(direct)",
    medium: r.utm_medium ?? "—",
    campaign: r.utm_campaign ?? "—",
    visits: Number(r.visits ?? 0),
    downloads: Number(r.downloads ?? 0),
    conv: Number(r.conversion_pct ?? 0),
  }));
}

export default async function Page() {
  await requireAdmin();
  const [k, funnel] = await Promise.all([getKPIs(), getFunnel()]);
  const conv = k.visits24 > 0 ? ((100 * k.downloads24) / k.visits24).toFixed(1) : "0.0";

  return (
    <>
      <h1>개요</h1>
      <p style={{ color: "var(--fg-dim)" }}>지난 24시간 / 30일 기준</p>

      <div className="cards">
        <Card label="오늘 방문"      value={k.visits24} />
        <Card label="오늘 다운로드"  value={k.downloads24} />
        <Card label="DAU"            value={k.dau} />
        <Card label="MAU (30d)"      value={k.mau} />
        <Card label="전환율 (24h)"   value={`${conv}%`} />
        <Card label="신규 가입 (24h)" value={k.signups24} />
      </div>

      <h2>유입 펀널 — 상위 20개 UTM 조합</h2>
      {funnel.length === 0 ? (
        <p className="empty">아직 데이터가 없습니다. 랜딩 페이지에 UTM 파라미터를 붙여 접속해보세요.</p>
      ) : (
        <table>
          <thead>
            <tr><th>source</th><th>medium</th><th>campaign</th><th>방문</th><th>다운로드</th><th>전환율</th></tr>
          </thead>
          <tbody>
            {funnel.map((r, i) => (
              <tr key={i}>
                <td>{r.source}</td>
                <td>{r.medium}</td>
                <td>{r.campaign}</td>
                <td>{r.visits}</td>
                <td>{r.downloads}</td>
                <td>{r.conv.toFixed(1)}%</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </>
  );
}

function Card({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="card">
      <div className="label">{label}</div>
      <div className="value">{value}</div>
    </div>
  );
}
