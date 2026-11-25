import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import path from "node:path";

const dir = path.dirname(fileURLToPath(import.meta.url));
const pluginDir = path.resolve(dir, "..");
const require = createRequire(import.meta.url);
const Picker = require(path.join(pluginDir, "Picker.js"));
const raw = readFileSync(path.join(pluginDir, "data", "emojis.json"), "utf8");

test("bundled catalog has only the eight Facebook-style categories", () => {
  const categories = Picker.parse(raw);
  assert.deepEqual(categories.map(c => c.id), [
    "people", "nature", "foods", "activity", "places", "objects", "symbols", "flags"
  ]);
  assert.equal(categories.reduce((sum, c) => sum + c.emojis.length, 0), 1870);
  for (const cat of categories) {
    for (const emoji of cat.emojis) {
      assert.ok(emoji.e.length <= 16, "emoji field is bounded");
      assert.equal(emoji.p, undefined, "no image paths remain");
    }
  }
});

test("categories and emojis use Facebook-style popularity order", () => {
  const categories = Picker.parse(raw);
  assert.equal(categories[0].name, "Smileys & People");
  assert.equal(categories[0].emojis[0].e, "😀");
  assert.equal(categories[0].emojis[1].e, "😃");
  assert.equal(categories[7].emojis[0].e, "🏁");
  const people = categories[0].emojis.map(e => e.e);
  assert.ok(people.indexOf("😀") < people.indexOf("🫠"), "popular faces come first");
});

test("search matches names, keywords and GitHub shortcode aliases", () => {
  const categories = Picker.parse(raw);
  assert.ok(Picker.filter(categories, "grinning", 50).length > 0);
  assert.ok(Picker.filter(categories, ":grinning:", 50).length > 0);
  assert.equal(Picker.filter(categories, "octocat", 50).length, 0);
});

test("markup-shaped queries cannot inject or overflow the picker", () => {
  const categories = Picker.parse(raw);
  assert.equal(Picker.filter(categories, '<img src="https://example.invalid/x">', 50).length, 0);
  assert.equal(Picker.filter(categories, "😀".repeat(500), 10).length, 0);
  const parsed = Picker.parse('{"categories":[{"id":"x","name":"x","emojis":[{"e":"<img>","c":"x","p":"../../etc/passwd"}]}]}');
  assert.equal(parsed[0].emojis[0].p, undefined);
});
