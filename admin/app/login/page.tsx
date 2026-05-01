"use client";
import { useState } from "react";
import { browserClient } from "@/lib/supabase";

export default function Login() {
  const [email, setEmail] = useState("");
  const [pw, setPw] = useState("");
  const [msg, setMsg] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setMsg(null);
    const sb = browserClient();
    const { error } = await sb.auth.signInWithPassword({ email, password: pw });
    setLoading(false);
    if (error) {
      setMsg(error.message);
      return;
    }
    location.href = "/";
  }

  return (
    <div style={{ maxWidth: 400, margin: "60px auto" }}>
      <h1>관리자 로그인</h1>
      <p style={{ color: "var(--fg-dim)" }}>
        Supabase Auth로 로그인합니다. <code>profiles.role = &apos;admin&apos;</code> 행이 있어야 통과됩니다.
      </p>
      <form onSubmit={submit} style={{ display: "grid", gap: 10, marginTop: 16 }}>
        <input
          type="email"
          placeholder="you@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          autoComplete="email"
        />
        <input
          type="password"
          placeholder="비밀번호"
          value={pw}
          onChange={(e) => setPw(e.target.value)}
          required
          autoComplete="current-password"
        />
        <button className="btn primary" type="submit" disabled={loading}>
          {loading ? "로그인 중..." : "로그인"}
        </button>
        {msg && <p style={{ color: "var(--danger)" }}>{msg}</p>}
      </form>
    </div>
  );
}
