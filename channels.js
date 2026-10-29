// TubeMasters : récupère les infos des chaînes via l'API YouTube Data v3.
// La clé est lue dans la variable d'environnement YOUTUBE_API_KEY (réglée sur Vercel),
// elle n'est donc jamais visible par les joueurs.
//
// Coût en quota (10 000 unités gratuites par jour) :
//   - 1 unité par youtubeur trouvé par son @handle
//   - 100 unités par youtubeur cherché par son nom (recherche)
//   - 1 unité par paquet de 50 chaînes pour les stats
// La réponse est mise en cache 24 h par Vercel, donc ce calcul tourne environ une fois par jour.
// Pour économiser du quota, recopie les "id" trouvés (page /verif.html) dans youtubeurs.json.

const LIST = require("../youtubeurs.json");
const API = "https://www.googleapis.com/youtube/v3";

async function yt(path, params) {
  const url = new URL(API + path);
  for (const [k, v] of Object.entries({ ...params, key: process.env.YOUTUBE_API_KEY })) url.searchParams.set(k, v);
  const r = await fetch(url);
  const j = await r.json();
  if (!r.ok) throw new Error((j.error && j.error.message) || "Erreur " + r.status);
  return j;
}

// Lance au plus n requêtes en même temps
async function pool(items, n, fn) {
  let i = 0;
  await Promise.all(Array.from({ length: n }, async () => {
    while (i < items.length) { const item = items[i++]; await fn(item); }
  }));
}

module.exports = async (req, res) => {
  if (!process.env.YOUTUBE_API_KEY) {
    res.status(500).json({ error: "Il manque la variable YOUTUBE_API_KEY dans les réglages Vercel (Settings > Environment Variables), puis il faut redéployer." });
    return;
  }
  try {
    const ids = {}, how = {}, errors = [];

    // 1. Chaînes dont l'id est déjà connu
    for (const x of LIST) if (x.id) { ids[x.name] = x.id; how[x.name] = "id"; }

    // 2. Recherche par @handle (1 unité)
    await pool(LIST.filter(x => !x.id && x.handle), 8, async x => {
      try {
        const j = await yt("/channels", { part: "id", forHandle: "@" + x.handle });
        if (j.items && j.items.length) { ids[x.name] = j.items[0].id; how[x.name] = "handle"; }
      } catch (e) { errors.push(x.name + " : " + e.message); }
    });

    // 3. Sinon recherche par nom, orientée France (100 unités)
    await pool(LIST.filter(x => !ids[x.name]), 4, async x => {
      try {
        const j = await yt("/search", { part: "snippet", type: "channel", q: x.name, maxResults: 1, regionCode: "FR", relevanceLanguage: "fr" });
        const it = j.items && j.items[0];
        if (it) { ids[x.name] = it.snippet.channelId; how[x.name] = "recherche"; }
      } catch (e) { errors.push(x.name + " : " + e.message); }
    });

    // 4. Stats + photo, par paquets de 50
    const entries = Object.entries(ids), byId = {};
    for (let i = 0; i < entries.length; i += 50) {
      const chunk = entries.slice(i, i + 50);
      const j = await yt("/channels", { part: "snippet,statistics", id: chunk.map(e => e[1]).join(","), maxResults: 50 });
      for (const it of j.items || []) byId[it.id] = it;
    }

    const channels = {};
    for (const [name, id] of entries) {
      const it = byId[id]; if (!it) continue;
      const st = it.statistics || {}, th = it.snippet.thumbnails || {};
      channels[name] = {
        id,
        title: it.snippet.title,
        handle: it.snippet.customUrl || null,
        subs: st.hiddenSubscriberCount ? null : Number(st.subscriberCount),
        img: (th.high || th.medium || th.default || {}).url || null,
        url: "https://www.youtube.com/channel/" + id,
        match: how[name]
      };
    }

    res.setHeader("Cache-Control", "s-maxage=86400, stale-while-revalidate=86400");
    res.status(200).json({
      updated: new Date().toISOString(),
      count: Object.keys(channels).length,
      notFound: LIST.filter(x => !channels[x.name]).map(x => x.name),
      errors,
      channels
    });
  } catch (e) {
    res.status(502).json({ error: String(e.message || e) });
  }
};
