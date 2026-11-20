// Bundles each Edge Function into ONE file (its _shared imports inlined;
// npm:/jsr: specifiers left as imports for the Deno runtime). Used to deploy
// through the Supabase MCP, which takes file contents rather than a directory.
// node scripts/deploy/bundle-functions.mjs <esbuild-path> <outdir>
import { execFileSync } from "node:child_process";
import { readdirSync, existsSync, mkdirSync } from "node:fs";
import { join, resolve } from "node:path";

const [esbuild, outdir] = process.argv.slice(2);
const root = resolve("apps/backend/supabase/functions");
mkdirSync(outdir, { recursive: true });
for (const name of readdirSync(root)) {
  const entry = join(root, name, "index.ts");
  if (name.startsWith("_") || !existsSync(entry)) continue;
  execFileSync(esbuild, [
    entry, "--bundle", "--format=esm", "--platform=neutral", "--target=es2022",
    "--external:npm:*", "--external:jsr:*", "--legal-comments=none",
    `--outfile=${join(outdir, name + ".js")}`,
  ], { stdio: "inherit" });
}
