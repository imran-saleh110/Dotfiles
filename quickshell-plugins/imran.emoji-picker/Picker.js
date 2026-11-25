// Local, bounded parsing and search for the bundled emoji catalog.
// Nothing here executes downloaded content; all data ships with the plugin.

function parse(raw) {
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (e) {
    return []
  }
  if (!data || !Array.isArray(data.categories)) return []

  var cats = []
  var total = 0
  for (var c = 0; c < data.categories.length && cats.length < 20; c++) {
    var source = data.categories[c]
    if (!source || typeof source.id !== "string" || typeof source.name !== "string") continue
    if (source.id.length > 40 || source.name.length > 80 || !Array.isArray(source.emojis)) continue

    var items = []
    for (var i = 0; i < source.emojis.length && items.length < 1000 && total < 3000; i++) {
      var e = source.emojis[i]
      if (!e || typeof e.e !== "string" || !e.e || e.e.length > 16) continue
      var item = {
        e: e.e,
        n: typeof e.n === "string" ? e.n.slice(0, 80) : "",
        c: typeof e.c === "string" ? e.c.slice(0, 60) : "",
        k: typeof e.k === "string" ? e.k.slice(0, 300) : ""
      }
      items.push(item)
      total++
    }
    if (items.length) {
      cats.push({
        id: source.id,
        name: source.name.slice(0, 80),
        icon: typeof source.icon === "string" ? source.icon.slice(0, 8) : "",
        emojis: items
      })
    }
  }
  return cats
}

function filter(categories, query, limit) {
  var values = Array.isArray(categories) ? categories : []
  var needle = String(query || "").trim().toLowerCase().replace(/^:+/, "").replace(/:+$/, "")
  var max = Number(limit)
  if (isNaN(max) || max <= 0) max = 1000

  if (!needle) {
    var all = []
    var used = 0
    for (var a = 0; a < values.length && used < max; a++) {
      var take = values[a].emojis.slice(0, max - used)
      all.push({
        id: values[a].id,
        name: values[a].name,
        icon: values[a].icon,
        emojis: take
      })
      used += take.length
    }
    return all
  }

  var out = []
  var count = 0
  for (var j = 0; j < values.length && count < max; j++) {
    var cat = values[j]
    var matches = []
    for (var k = 0; k < cat.emojis.length && count < max; k++) {
      var emoji = cat.emojis[k]
      if (emoji.k.indexOf(needle) >= 0 || emoji.c.toLowerCase().indexOf(needle) >= 0) {
        matches.push(emoji)
        count++
      }
    }
    if (matches.length) {
      out.push({ id: cat.id, name: cat.name, icon: cat.icon, emojis: matches })
    }
  }
  return out
}

if (typeof module !== "undefined") {
  module.exports = { parse: parse, filter: filter }
}
