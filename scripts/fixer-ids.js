// Lit la réponse de /api/channels (live.json) et enregistre les identifiants de chaîne
// trouvés dans youtubeurs.json, pour que le site n'ait plus à les chercher (économise le quota).
const fs = require("fs");
const live = JSON.parse(fs.readFileSync("live.json", "utf8"));
const list = JSON.parse(fs.readFileSync("youtubeurs.json", "utf8"));
const ch = live.channels || {};
let added = 0;
for (const x of list) {
  const c = ch[x.name];
  if (c && !x.id) { x.id = c.id; x.src = c.match === "recherche" ? "recherche" : "handle"; added++; }
}
fs.writeFileSync("youtubeurs.json", JSON.stringify(list, null, 1) + "\n");
const etat = {
  verifieLe: new Date().toISOString(),
  reponseDu: live.updated || null,
  erreurGlobale: live.error || null,
  trouvees: live.count || 0,
  idsAjoutes: added,
  sansId: list.filter(x => !x.id).map(x => x.name),
  sansPhoto: Object.entries(ch).filter(([, v]) => !v.img).map(([k]) => k),
  quotaEpuise: !!live.quotaEpuise,
  rejetees: live.rejected || [],
  correspondances: Object.fromEntries(Object.entries(ch).map(([k, v]) => [k, `${v.title} | ${v.handle || ""} | ${v.subs ?? "masqué"} | ${v.match}`])),
  erreurs: live.errors || []
};
fs.writeFileSync("etat-api.json", JSON.stringify(etat, null, 1) + "\n");
console.log(JSON.stringify(etat, null, 1));
