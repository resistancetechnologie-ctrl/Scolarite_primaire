# Audit et corrections — Ecole Primaire (Flutter)

## 1. Blocage de build CI (le plus important)

Le depot ne contenait qu'un **squelette Android partiel** :
`AndroidManifest.xml` et `MainActivity.kt` seulement — sans
`settings.gradle`, `build.gradle`, wrapper Gradle, ni ressources
(`styles.xml`, icones). Le dossier **`windows/` etait totalement
absent**. En l'etat, ni `flutter build apk` ni `flutter build windows`
ne pouvaient fonctionner sur GitHub Actions (ni ailleurs).

De plus, la commande documentee dans `INSTALLATION.md`
(`flutter create . --platforms=...`, sans `--org`) genere par defaut un
`applicationId`/`namespace` `com.example.ecole_primaire`, qui **ne
correspond pas** au package reellement utilise par
`MainActivity.kt` (`com.ecole.primaire`) : l'app compilerait mais
planterait probablement au lancement (activite introuvable).

**Correction** : `.github/workflows/build.yml` complete automatiquement
le squelette manquant via `flutter create` (Android avec
`--org com.ecole`, puis correction du namespace en
`com.ecole.primaire` ; Windows sans risque de collision), sans jamais
ecraser les fichiers deja personnalises du depot. `INSTALLATION.md` a
ete corrige pour un usage local identique.

## 2. Faille de securite : contournement du code PIN

Dans `login_screen.dart`, la validation comparait `ctrl.text ==
attendu`. Or `config_ecole_screen.dart` permettait d'enregistrer un
`pinEnseignant` **vide** (aucun defaut applique, contrairement au PIN
Directeur). Resultat : si le champ etait vide, laisser le champ de
saisie vide au login suffisait a se connecter **sans aucun code**.

**Corrections** :
- `login_screen.dart` : un PIN saisi vide est desormais toujours
  rejete, meme si le PIN configure est vide.
- `config_ecole_screen.dart` : un PIN Enseignant vide retombe sur un
  defaut (`0000`), comme le PIN Directeur.
- Ajout d'un verrouillage temporaire (30 s) apres 5 echecs consecutifs
  par profil/classe, pour limiter les essais automatises (le code PIN
  a 4 chiffres est intrinsequement faible : 10 000 combinaisons).
- Les champs PIN (config ecole + edition enseignant) sont desormais
  masques (`obscureText`), ils s'affichaient auparavant en clair.

## 3. Permission Android obsolete

`READ_EXTERNAL_STORAGE` est ineffective depuis Android 13 (API 33) et
inutile ici (l'app n'ecrit que dans son dossier prive, ou passe par le
selecteur systeme). Limitee a `maxSdkVersion="32"`.

## 4. Documentation trompeuse

Le README affirmait un fichier "JSON chiffre-controle" : en realite
`local_store.dart` fait un simple `jsonEncode`, **sans chiffrement**.
Le README a ete corrige pour refleter l'etat reel (integrite SHA-256
oui, chiffrement au repos non) — a considerer comme amelioration
future si des donnees sensibles l'exigent.

## 5. `.gitignore` incomplet

Absence d'exclusions pour `local.properties`, `key.properties`,
keystores, dossiers desktop generes. Complete pour eviter de committer
des secrets de signature ou des artefacts de build.

## Points verifies sans anomalie bloquante
Calculs de moyennes/rangs (`calcul_service.dart`), export/import avec
checksum SHA-256 (`sync_service.dart`), noms de fichiers d'export
(pas d'injection de chemin detectee).

## 6. Compatibilite FlutLab (suite de l'audit)

FlutLab (IDE Flutter en ligne) **ne complete pas automatiquement** les
dossiers de plateforme manquants lors d'un upload de zip — contrairement a
`flutter create` en local ou a l'etape ajoutee dans le workflow CI. Le
dossier `android/` a donc ete rendu **complet et autonome** dans le depot :
`settings.gradle`, `build.gradle`, `gradle.properties`, `app/build.gradle`
(namespace/applicationId `com.ecole.primaire`, aligne sur `MainActivity.kt`),
themes, fond de lancement, icones de lanceur (placeholder), manifestes
debug/profile, et le wrapper Gradle (`gradlew`, `gradlew.bat`,
`gradle-wrapper.properties`).

Seul `android/gradle/wrapper/gradle-wrapper.jar` (fichier **binaire**
compile) n'a pas pu etre inclus depuis cet environnement d'analyse (pas
d'acces reseau pour le recuperer). Il se regenere automatiquement a
l'ouverture dans Android Studio, via `gradle wrapper` en local, ou
directement sur GitHub Actions / FlutLab (toolchain deja installee cote
serveur) — voir `INSTALLATION.md`.

FlutLab compile des APK/AAB Android, IPA iOS et apps Web, mais **pas
d'executable Windows** : cette cible reste couverte uniquement par
`flutter build windows` (local) et par le workflow GitHub Actions fourni.

## 7. Corrections complementaires (notes, verrouillage, absences)

- `setNote()` (state) refusait desormais les notes hors plage 0-10 et
  respecte le verrouillage de periode (`estVerrouille`) — ces deux
  controles n'existaient auparavant qu'au niveau de l'ecran de saisie et
  pouvaient etre contournes via un import de fichier JSON externe.
- `sync_service.importerClasse()` applique la meme validation lors de la
  fusion des notes importees (plage 0-10 + periode non verrouillee) et
  rapporte desormais le nombre de notes rejetees dans le resume d'import.
- Le bulletin affichait un total d'absences **annuel** en le presentant
  comme si il etait propre a la periode du bulletin (aucune date de
  trimestre n'est stockee dans le modele pour permettre un vrai filtrage
  par periode) : le libelle a ete corrige en "Absences (cumul annee)" pour
  eviter toute confusion sur un document officiel.
- `AlerteService.absencesConsecutives()` comptait comme "consecutives" des
  absences isolees separees de plusieurs semaines des lors qu'aucun
  enregistrement de presence n'existait entre les deux (faux positifs).
  Un ecart de calendrier maximal de 3 jours (tolerance week-end) est
  desormais exige entre deux absences pour qu'elles comptent dans la meme
  serie.

## 8. Ajout du dossier iOS (`ios/`)

Le dossier `ios/` etait totalement absent. Il a ete cree integralement
(Runner.xcodeproj, Runner.xcworkspace, Info.plist, AppDelegate.swift,
Podfile, icones, storyboards, cible RunnerTests) avec un bundle id
`com.ecole.primaire`, coherent avec `android/` (`com.ecole.primaire`) et le
package Kotlin de `MainActivity.kt`.

⚠️ **Le fichier `project.pbxproj`** (projet Xcode) est le plus complexe de
tout le squelette : il a ete reconstruit a la main sur le modele standard du
template Flutter (aucun outil Xcode n'etant disponible dans cet
environnement d'analyse pour le generer ou le valider directement). Sa
structure a ete verifiee (XML/JSON valides, accolades/parentheses
equilibrees), et un job de verification a ete ajoute au workflow GitHub
Actions (`build-ios`, sur `macos-latest`, build non signe via
`flutter build ios --release --no-codesign`) pour confirmer sa validite a
chaque push. Si ce job echoue, la methode la plus sure reste de regenerer
le dossier avec `flutter create --platforms=ios --org com.ecole .` (qui ne
touchera pas aux fichiers Android/lib deja en place) puis de reappliquer
manuellement le `NSCameraUsageDescription`/`NSPhotoLibraryUsageDescription`
ajoutes dans `Info.plist`.

Ce job de verification ne produit pas d'IPA distribuable (necessiterait un
certificat et un profil de provisionnement Apple, hors de portee d'une
verification automatisee) : il sert uniquement a s'assurer que le projet
Xcode compile.
