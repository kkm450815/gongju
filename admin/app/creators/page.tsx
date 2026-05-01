import { requireAdmin } from "@/lib/auth";
import { adminClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export default async function Page() {
  await requireAdmin();
  const sb = adminClient();
  const { data } = await sb
    .from("v_creator_stats")
    .select("*")
    .order("downloads", { ascending: false });

  return (
    <>
      <h1>인플루언서 성과</h1>
      <p style={{ color: "var(--fg-dim)" }}>
        모든 인플루언서의 단축 코드별 누적 방문/다운로드. 새 인플루언서는 SQL 또는
        후속 폼으로 <code>creators</code> 테이블에 추가하세요.
      </p>

      {(!data || data.length === 0) ? (
        <p className="empty">아직 등록된 인플루언서가 없습니다.</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>이름</th>
              <th>플랫폼</th>
              <th>코드 prefix</th>
              <th>방문</th>
              <th>다운로드</th>
              <th>전환율</th>
            </tr>
          </thead>
          <tbody>
            {data.map((row: any) => {
              const v = Number(row.visits ?? 0);
              const d = Number(row.downloads ?? 0);
              const conv = v > 0 ? ((100 * d) / v).toFixed(1) : "0.0";
              return (
                <tr key={row.id}>
                  <td>{row.name}</td>
                  <td><span className="tag">{row.platform}</span></td>
                  <td className="mono">{row.short_code_prefix ?? "—"}</td>
                  <td>{v}</td>
                  <td>{d}</td>
                  <td>{conv}%</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </>
  );
}
