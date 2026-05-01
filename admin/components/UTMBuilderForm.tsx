"use client";
import { useMemo, useState } from "react";
import QRCode from "qrcode";
import { browserClient } from "@/lib/supabase";
import { fullUrl, shortUrl, nextShortCode } from "@/lib/utm";

type Creator = { id: string; name: string; platform: string; short_code_prefix: string | null };

const SOURCES = ["youtube", "twitter", "instagram", "tiktok", "blog", "newsletter", "discord", "reddit", "manual"];
const MEDIUMS = ["video", "social", "email", "cpc", "cpm", "organic", "referral"];
const PATHS = ["/", "/download", "/press"];
const LANG_PREFIXES = ["KO", "EN", "JA", "ZH"];
const PLATFORM_PREFIXES = ["YT", "TW", "IG", "TT", "BL", "NL", "DC", "RD"];

export default function UTMBuilderForm({
  existingShortCodes,
  creators,
  landingBase,
}: {
  existingShortCodes: string[];
  creators: Creator[];
  landingBase: string;
}) {
  const [source, setSource] = useState("youtube");
  const [medium, setMedium] = useState("video");
  const [campaign, setCampaign] = useState("launch_2026q2");
  const [content, setContent] = useState("");
  const [term, setTerm] = useState("");
  const [path, setPath] = useState("/");
  const [creatorId, setCreatorId] = useState<string>("");
  const [langPrefix, setLangPrefix] = useState("KO");
  const [platformPrefix, setPlatformPrefix] = useState("YT");
  const [qrUrl, setQrUrl] = useState<string | null>(null);
  const [savedCode, setSavedCode] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  const shortCode = useMemo(
    () => nextShortCode(existingShortCodes, langPrefix, platformPrefix),
    [existingShortCodes, langPrefix, platformPrefix],
  );
  const full = useMemo(
    () => fullUrl(landingBase, { source, medium, campaign, content: content || undefined, term: term || undefined, path, short_code: shortCode }),
    [landingBase, source, medium, campaign, content, term, path, shortCode],
  );
  const short = useMemo(() => shortUrl(landingBase, shortCode), [landingBase, shortCode]);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setMsg(null);
    const sb = browserClient();
    const { error } = await sb.from("utm_links").insert({
      short_code: shortCode,
      source, medium, campaign,
      content: content || null,
      term: term || null,
      path,
      creator_id: creatorId || null,
    });
    setBusy(false);
    if (error) {
      setMsg(error.message);
      return;
    }
    setSavedCode(shortCode);
    setMsg(`저장되었습니다: ${shortCode}`);
    const dataUrl = await QRCode.toDataURL(short, { width: 320, margin: 1 });
    setQrUrl(dataUrl);
  }

  function copy(text: string) {
    navigator.clipboard.writeText(text);
    setMsg(`복사됨: ${text}`);
  }

  return (
    <form onSubmit={save} style={{ marginTop: 16 }}>
      <div className="row">
        <Field label="utm_source"><select value={source} onChange={e => setSource(e.target.value)}>
          {SOURCES.map(s => <option key={s}>{s}</option>)}
        </select></Field>
        <Field label="utm_medium"><select value={medium} onChange={e => setMedium(e.target.value)}>
          {MEDIUMS.map(s => <option key={s}>{s}</option>)}
        </select></Field>
        <Field label="utm_campaign">
          <input value={campaign} onChange={e => setCampaign(e.target.value)} required />
        </Field>
        <Field label="utm_content (인플루언서 ID 등)">
          <input value={content} onChange={e => setContent(e.target.value)} placeholder="creator_001" />
        </Field>
        <Field label="utm_term (선택)">
          <input value={term} onChange={e => setTerm(e.target.value)} />
        </Field>
        <Field label="랜딩 경로">
          <select value={path} onChange={e => setPath(e.target.value)}>
            {PATHS.map(p => <option key={p}>{p}</option>)}
          </select>
        </Field>
        <Field label="언어 prefix">
          <select value={langPrefix} onChange={e => setLangPrefix(e.target.value)}>
            {LANG_PREFIXES.map(p => <option key={p}>{p}</option>)}
          </select>
        </Field>
        <Field label="플랫폼 prefix">
          <select value={platformPrefix} onChange={e => setPlatformPrefix(e.target.value)}>
            {PLATFORM_PREFIXES.map(p => <option key={p}>{p}</option>)}
          </select>
        </Field>
        <Field label="인플루언서 (선택)">
          <select value={creatorId} onChange={e => setCreatorId(e.target.value)}>
            <option value="">— 없음 —</option>
            {creators.map(c => (
              <option key={c.id} value={c.id}>{c.name} ({c.platform})</option>
            ))}
          </select>
        </Field>
      </div>

      <h2>미리보기</h2>
      <Field label="짧은 코드"><div className="copy-input"><input readOnly value={shortCode} /><button type="button" className="btn" onClick={() => copy(shortCode)}>복사</button></div></Field>
      <Field label="단축 URL"><div className="copy-input"><input readOnly value={short} /><button type="button" className="btn" onClick={() => copy(short)}>복사</button></div></Field>
      <Field label="풀 UTM URL"><div className="copy-input"><input readOnly value={full} /><button type="button" className="btn" onClick={() => copy(full)}>복사</button></div></Field>

      <div className="actions">
        <button className="btn primary" type="submit" disabled={busy}>{busy ? "저장 중..." : "링크 저장"}</button>
        {savedCode && <span style={{ color: "var(--accent-2)" }}>✓ {savedCode}</span>}
      </div>
      {msg && <p style={{ marginTop: 8, color: "var(--fg-dim)" }}>{msg}</p>}
      {qrUrl && (
        <div style={{ marginTop: 18 }}>
          <h2>QR 코드</h2>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={qrUrl} alt="QR" width={240} height={240} style={{ background: "#fff", padding: 8, borderRadius: 8 }} />
          <div style={{ marginTop: 8 }}>
            <a className="btn" href={qrUrl} download={`${savedCode ?? shortCode}.png`}>QR 다운로드</a>
          </div>
        </div>
      )}
    </form>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label style={{ display: "block", marginBottom: 12 }}>
      <div style={{ color: "var(--fg-dim)", fontSize: ".82rem", marginBottom: 4 }}>{label}</div>
      {children}
    </label>
  );
}
