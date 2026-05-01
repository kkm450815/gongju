/** UTM helpers shared between server and client. */

export type UTMInput = {
  source: string;
  medium: string;
  campaign: string;
  content?: string;
  term?: string;
  path?: string;
  short_code: string;
};

const LANG_BY_PREFIX: Record<string, string> = {
  KO: "korean", EN: "english", JA: "japanese", ZH: "chinese",
};

const PLATFORM_BY_PREFIX: Record<string, string> = {
  YT: "youtube", TW: "twitter", IG: "instagram", TT: "tiktok",
  BL: "blog", NL: "newsletter", DC: "discord", RD: "reddit",
};

export function fullUrl(base: string, u: UTMInput): string {
  const url = new URL((u.path ?? "/") , base);
  url.searchParams.set("utm_source", u.source);
  url.searchParams.set("utm_medium", u.medium);
  url.searchParams.set("utm_campaign", u.campaign);
  if (u.content) url.searchParams.set("utm_content", u.content);
  if (u.term) url.searchParams.set("utm_term", u.term);
  url.searchParams.set("ref", u.short_code);
  return url.toString();
}

export function shortUrl(base: string, code: string): string {
  return new URL(`/r/${encodeURIComponent(code)}`, base).toString();
}

/** "KO-YT-001" -> {lang, platform, num} */
export function parseShortCode(code: string) {
  const m = code.match(/^([A-Z]{2})-([A-Z]{2})-(\d{3,5})$/);
  if (!m) return null;
  const [, lang, platform, num] = m;
  return {
    lang_prefix: lang,
    platform_prefix: platform,
    lang_label: LANG_BY_PREFIX[lang] ?? lang.toLowerCase(),
    platform_label: PLATFORM_BY_PREFIX[platform] ?? platform.toLowerCase(),
    num: Number(num),
  };
}

/** Suggest the next short code given existing codes for a (lang, platform). */
export function nextShortCode(existing: string[], langPrefix: string, platformPrefix: string): string {
  const prefix = `${langPrefix}-${platformPrefix}-`;
  const nums = existing
    .filter(c => c.startsWith(prefix))
    .map(c => Number(c.slice(prefix.length)))
    .filter(n => Number.isFinite(n));
  const next = (nums.length ? Math.max(...nums) : 0) + 1;
  return `${prefix}${String(next).padStart(3, "0")}`;
}
