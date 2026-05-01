import { redirect } from "next/navigation";
import { serverClient, adminClient } from "./supabase";

/**
 * Server-only guard for /admin pages.
 * Verifies the cookie session AND that the user has profiles.role = 'admin'.
 * Redirects to /login on failure.
 */
export async function requireAdmin() {
  const sb = serverClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) redirect("/login");

  // Use service-role to bypass RLS when reading profiles.role.
  // Profiles table is the trust boundary; admins must be set manually in SQL.
  const a = adminClient();
  const { data: profile } = await a
    .from("profiles")
    .select("role")
    .eq("user_id", user.id)
    .single();

  if (!profile || profile.role !== "admin") {
    redirect("/login?error=not_admin");
  }
  return user;
}
