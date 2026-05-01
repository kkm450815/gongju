import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";

/**
 * Middleware: refreshes Supabase session cookies on every request so
 * server components can call sb.auth.getUser() without an extra round-trip.
 * Does NOT enforce admin role here — that's done in lib/auth.requireAdmin().
 */
export async function middleware(req: NextRequest) {
  const res = NextResponse.next();
  const sb = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get: (n) => req.cookies.get(n)?.value,
        set: (n, v, opts) => res.cookies.set({ name: n, value: v, ...opts }),
        remove: (n, opts) => res.cookies.set({ name: n, value: "", ...opts }),
      },
    },
  );
  await sb.auth.getUser();
  return res;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\..*).*)"],
};
