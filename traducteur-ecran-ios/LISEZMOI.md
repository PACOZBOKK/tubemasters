# Traducteur d'écran FR → JA (iPhone)

L'appli lit en continu le texte français affiché sur ton iPhone, dans n'importe quelle appli,
et affiche la traduction japonaise dans une **fenêtre flottante** (Picture in Picture) qui reste par-dessus tout.
Tout se passe sur le téléphone, hors ligne : pas de serveur, pas de clé API, rien n'est envoyé sur Internet.

## Comment ça marche
1. **Capture** : une extension « Diffusion de l'écran » (ReplayKit) reçoit les images de l'écran.
2. **Lecture** : Vision (reconnaissance de texte d'Apple) lit le français environ une fois par seconde.
3. **Traduction** : le framework Translation d'Apple traduit en japonais, sur l'appareil.
4. **Affichage** : le résultat est dessiné dans la fenêtre flottante Picture in Picture.

iOS n'autorise pas une appli à dessiner directement par-dessus les autres : la fenêtre flottante
Picture in Picture est le seul moyen autorisé, c'est donc elle qui sert de « sous-titres ».

## Ce qu'il te faut
- Un **Mac** avec **Xcode 26** ou plus récent (gratuit sur l'App Store).
- Un **iPhone sous iOS 26** ou plus récent, et son câble.
- Un compte Apple (le gratuit suffit ; avec le gratuit, il faut réinstaller l'appli depuis Xcode tous les 7 jours).

## Installation
1. Sur le Mac, installe XcodeGen : ouvre **Terminal** et tape `brew install xcodegen`
   (si `brew` n'existe pas, installe d'abord Homebrew depuis https://brew.sh).
2. Télécharge ce dépôt, puis dans Terminal :
   ```
   cd chemin/vers/tubemasters/traducteur-ecran-ios
   xcodegen generate
   open TraducteurEcran.xcodeproj
   ```
3. Dans `project.yml`, remplace `com.exemple.traducteurecran` par un identifiant à toi
   (par exemple `com.tonprenom.traducteurecran`), puis relance `xcodegen generate`.
4. Dans Xcode, clique sur le projet **TraducteurEcran** à gauche. Pour **chacune** des deux cibles
   (`TraducteurEcran` et `CaptureEcran`) : onglet **Signing & Capabilities** → **Team** → choisis ton compte Apple.
   Vérifie que l'**App Group** `group.<ton identifiant>` est bien coché sur les deux cibles.
5. Branche l'iPhone, choisis-le en haut de Xcode, clique sur ▶︎.
6. La première fois, sur l'iPhone : **Réglages → Général → VPN et gestion de l'appareil** → fais confiance à ton compte.
   Active aussi le **mode développeur** si iOS le demande (Réglages → Confidentialité et sécurité).

## Utilisation
1. Ouvre **Traducteur** et touche **Télécharger français + japonais** (une seule fois, ~quelques dizaines de Mo).
2. Touche **Ouvrir la fenêtre flottante**.
3. Touche le **rond** de l'étape 3, choisis **Traducteur FR→JA**, puis **Commencer la diffusion**.
4. Va dans n'importe quelle appli : la fenêtre flottante affiche le japonais au fur et à mesure.
5. Pour arrêter : touche la pastille rouge en haut de l'écran (ou reviens dans l'appli et retouche le rond).

Astuce : pince la fenêtre flottante pour l'agrandir, ou glisse-la sur le bord pour la cacher un moment.
L'option **Afficher aussi le français** montre le texte original au-dessus de chaque traduction.

## Limites à connaître
- Délai d'environ **1 à 2 secondes** entre l'apparition du texte et sa traduction.
- Les vidéos protégées (Netflix, Disney+…) apparaissent noires dans une capture : leurs sous-titres ne peuvent pas être lus.
- L'extension de capture n'a droit qu'à ~50 Mo de mémoire : sur un écran très chargé, la lecture peut être moins précise.
- La fenêtre flottante elle-même est filtrée (le japonais est ignoré), pour ne pas se traduire elle-même.
- Une appli qui fait ça ne serait pas forcément acceptée telle quelle sur l'App Store : elle est faite pour ton usage perso.

## Fichiers
- `App/` : l'application (écran principal, traduction, fenêtre flottante).
- `CaptureEcran/SampleHandler.swift` : l'extension qui capture l'écran et lit le texte.
- `Shared/Partage.swift` : l'échange de texte entre l'extension et l'appli.
- `project.yml` : la description du projet pour XcodeGen.
