// Copies the validated JSON content into the Flutter bundle
// (apps/mobile/assets/content). A copy, not a symlink: symlinks break on Windows.
// CI fails when the copy is stale (content_test.ts).
// deno run --allow-read --allow-write scripts/content/sync-app.ts
import { CONTENT_DIR, loadContent } from "./lib.ts";

export const APP_CONTENT_DIR = new URL("../../apps/mobile/assets/content/", import.meta.url);

/// Relative path -> file contents of everything the app must ship.
export async function appFiles(): Promise<Map<string, string>> {
  const { index, errors } = await loadContent();
  if (errors.length) throw new Error(`content invalid:\n${errors.join("\n")}`);
  const files = new Map<string, string>();
  const add = async (rel: string) => files.set(rel, await Deno.readTextFile(new URL(rel, CONTENT_DIR)));
  await add("index.json");
  for (const e of index.exams) await add(`exams/${e.level}/${e.id}.json`);
  for (const d of index.diagrams) await add(`diagrams/${d}.json`);
  return files;
}

if (import.meta.main) {
  await Deno.remove(APP_CONTENT_DIR, { recursive: true }).catch(() => {});
  for (const [rel, text] of await appFiles()) {
    const url = new URL(rel, APP_CONTENT_DIR);
    await Deno.mkdir(new URL(".", url), { recursive: true });
    await Deno.writeTextFile(url, text);
  }
  for (const level of ["B1", "B2", "C1"]) await Deno.mkdir(new URL(`exams/${level}/`, APP_CONTENT_DIR), { recursive: true });
  await Deno.mkdir(new URL("diagrams/", APP_CONTENT_DIR), { recursive: true });
  console.log(`synced ${APP_CONTENT_DIR.pathname}`);
}
