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
    let quota = false;
    const call = async (path, params) => {
      if (quota) throw new Error("quota épuisé");
      try { return await yt(path, params); }
      catch (e) { if (/quota/i.test(e.message)) quota = true; throw e; }
    };
    // "id" = identifiant mis à la main (toujours accepté). Les identifiants enregistrés automatiquement
    // gardent leur origine (handle / recherche) et restent soumis à la protection contre les homonymes.
    for (const x of LIST) if (x.id) { ids[x.name] = x.id; how[x.name] = x.src === "recherche" ? "recherche" : x.src ? "handle" : "id"; }

    await pool(LIST.filter(x => !x.id && x.handle), 8, async x => {
      try {
        const j = await call("/channels", { part: "id", forHandle: "@" + x.handle });
        if (j.items && j.items.length) { ids[x.name] = j.items[0].id; how[x.name] = "handle"; }
      } catch (e) { errors.push(x.name + " : " + e.message); }
    });

    await pool(LIST.filter(x => !ids[x.name]), 4, async x => {
      try {
        const j = await call("/search", { part: "snippet", type: "channel", q: x.name, maxResults: 1, regionCode: "FR", relevanceLanguage: "fr" });
        const it = j.items && j.items[0];
        if (it) { ids[x.name] = it.snippet.channelId; how[x.name] = "recherche"; }
      } catch (e) { errors.push(x.name + " : " + e.message); }
    });

    const entries = Object.entries(ids), byId = {};
    for (let i = 0; i < entries.length; i += 50) {
      const chunk = entries.slice(i, i + 50);
      const j = await yt("/channels", { part: "snippet,statistics", id: chunk.map(e => e[1]).join(","), maxResults: 50 });
      for (const it of j.items || []) byId[it.id] = it;
    }

    // Protection contre les homonymes : une chaîne trouvée automatiquement (par @ ou par recherche)
    // avec moins de MIN_SUBS abonnés n'est presque jamais la bonne. On l'écarte.
    // Pour forcer une chaîne précise, mets son identifiant "id" dans youtubeurs.json.
    const MIN_SUBS = 20000;
    const channels = {}, rejected = [];
    for (const [name, id] of entries) {
      const it = byId[id]; if (!it) continue;
      const st = it.statistics || {}, th = it.snippet.thumbnails || {};
      const n = st.hiddenSubscriberCount ? null : Number(st.subscriberCount);
      if (how[name] !== "id" && n !== null && n < MIN_SUBS) { rejected.push(name + " → " + it.snippet.title + " (" + n + " abonnés)"); continue; }
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

    // Résultat incomplet (quota, erreur) : cache court pour réessayer vite ; sinon 24 h
    res.setHeader("Cache-Control", errors.length ? "s-maxage=900" : "s-maxage=86400, stale-while-revalidate=86400");
    res.status(200).json({
      updated: new Date().toISOString(),
      count: Object.keys(channels).length,
      notFound: LIST.filter(x => !channels[x.name]).map(x => x.name),
      rejected,
      quotaEpuise: quota,
      errors,
      channels
    });
  } catch (e) {
    res.status(502).json({ error: String(e.message || e) });
  }
};
