import { requireAdmin } from "@/lib/auth";
import { adminClient } from "@/lib/supabase";
import UTMBuilderForm from "@/components/UTMBuilderForm";

export const dynamic = "force-dynamic";

export default async function Page() {
  await requireAdmin();
  const sb = adminClient();
  const { data: links } = await sb
    .from("utm_links")
    .select("short_code")
    .order("created_at", { ascending: false });
  const { data: creators } = await sb
    .from("creators")
    .select("id, name, platform, short_code_prefix")
    .eq("disabled", false)
    .order("name");

  const base = process.env.NEXT_PUBLIC_LANDING_BASE_URL ?? "https://gongju.game";

  return (
    <>
      <h1>UTM 빌더</h1>
      <p style={{ color: "var(--fg-dim)" }}>
        새 캠페인 링크를 만듭니다. 짧은 코드는 자동으로 생성됩니다 (KO-YT-001 형식).
        만든 링크는 즉시 <code>/r/&lt;코드&gt;</code> 단축 URL로도 접근 가능합니다.
      </p>
      <UTMBuilderForm
        existingShortCodes={(links ?? []).map((l: any) => l.short_code as string)}
        creators={(creators ?? []) as any}
        landingBase={base}
      />
    </>
  );
}
