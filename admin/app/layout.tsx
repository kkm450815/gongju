import "./globals.css";
import Link from "next/link";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "gongju admin",
  description: "Internal dashboard",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ko">
      <body>
        <header className="topbar">
          <div className="brand">
            <span className="mark" />
            <span>gongju · admin</span>
          </div>
          <nav>
            <Link href="/">개요</Link>
            <Link href="/utm-builder">UTM 빌더</Link>
            <Link href="/creators">인플루언서</Link>
            <Link href="/downloads">다운로드</Link>
          </nav>
        </header>
        <main className="page">{children}</main>
      </body>
    </html>
  );
}
