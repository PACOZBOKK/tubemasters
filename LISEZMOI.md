# TubeMasters : mise en ligne avec l'API YouTube

## Contenu du dossier
- `index.html` : le jeu.
- `api/channels.js` : la fonction serveur qui interroge YouTube avec ta clé (abonnés, photo, lien de chaque chaîne).
- `youtubeurs.json` : la liste des youtubeurs et leur @handle. C'est ici qu'on corrige une chaîne mal trouvée.
- `verif.html` : la page pour vérifier que chaque youtubeur correspond à la bonne chaîne.
- `vercel.json`, `package.json` : réglages pour Vercel.

## 1. Obtenir la clé API YouTube (gratuit, environ 5 min)
1. Va sur https://console.cloud.google.com et connecte-toi avec ton compte Google.
2. En haut, clique sur le sélecteur de projet, puis sur **Nouveau projet**. Nomme-le `TubeMasters` et clique sur **Créer**. Vérifie ensuite qu'il est bien sélectionné en haut.
3. Menu ☰ > **API et services** > **Bibliothèque**. Cherche **YouTube Data API v3**, ouvre-la et clique sur **Activer**.
4. Menu ☰ > **API et services** > **Identifiants** > **+ Créer des identifiants** > **Clé API**. Copie la clé (elle commence par `AIza…`).
5. Clique sur **Modifier la clé API**. Dans **Restrictions relatives aux API**, coche **Restreindre la clé**, choisis **YouTube Data API v3** et clique sur **Enregistrer**. Laisse « Restrictions relatives aux applications » sur **Aucune** : la clé reste cachée sur le serveur Vercel.

Pas besoin de carte bancaire. Tu as 10 000 unités de quota par jour, ce qui est largement suffisant ici.
Ne partage jamais cette clé et ne la colle jamais dans `index.html`.

## 2. Mettre le projet sur GitHub
1. Sur https://github.com, clique sur **New repository**. Nomme-le `tubemasters` et clique sur **Create repository**.
2. Clique sur **uploading an existing file**. Glisse **tout le contenu** du dossier (pas le dossier lui-même) : `index.html`, `verif.html`, `youtubeurs.json`, `vercel.json`, `package.json`, `LISEZMOI.md` et le dossier `api`.
3. Clique sur **Commit changes**.

## 3. Déployer sur Vercel
1. Sur https://vercel.com, clique sur **Add New… > Project**, puis **Import** à côté du dépôt `tubemasters`.
2. Avant de cliquer sur Deploy, ouvre **Environment Variables** et ajoute :
   - Name : `YOUTUBE_API_KEY`
   - Value : ta clé `AIza…`
3. Clique sur **Deploy**.

Si tu as déjà déployé sans la variable, ajoute-la dans **Settings > Environment Variables**, puis va dans **Deployments**, clique sur **⋯** à côté du dernier déploiement, puis sur **Redeploy**.

## 4. Vérifier
- Ouvre `https://ton-site.vercel.app/api/channels`. Tu dois voir du texte avec `"count": 128` (ou proche). Le premier chargement peut prendre une vingtaine de secondes.
- Ouvre `https://ton-site.vercel.app/verif.html`. Les lignes en **jaune** (trouvées par recherche) sont à vérifier en priorité.
- Pour corriger une chaîne fausse : ouvre la bonne chaîne sur YouTube, puis récupère son identifiant `UC…` (sur la chaîne : **À propos > Partager la chaîne > Copier l'ID de la chaîne**). Dans `youtubeurs.json`, remplace `"id": null` par `"id": "UC…"` pour ce youtubeur. Fais un commit sur GitHub : Vercel redéploie tout seul.
- Astuce : recopie les identifiants de toutes les chaînes correctes dans `youtubeurs.json`. La fonction n'aura plus besoin de les chercher et consommera presque aucun quota.

## Bon à savoir
- Les données sont rafraîchies environ une fois par jour.
- La rareté dépend uniquement du nombre d'abonnés : elle suit les chiffres en direct (Légendaire ≥ 10 M, Épique ≥ 5 M, Rare ≥ 2,5 M, Peu commune ≥ 1,2 M).
- Les photos de profil restent l'image des youtubeurs. Avant de faire payer quoi que ce soit (boosters, abonnement), demande leur accord.
