# Installation

## En local (Flutter SDK installe sur votre machine)

1. Installer Flutter (3.19+ recommande) : https://docs.flutter.dev/get-started/install
2. Dans le dossier du projet :

```bash
flutter pub get
flutter run                        # ou : flutter build apk --release
```

Le dossier `android/` est desormais un projet Gradle complet et coherent
(namespace/applicationId `com.ecole.primaire`, aligne avec le package declare
dans `android/app/src/main/kotlin/com/ecole/primaire/MainActivity.kt`).

> ⚠️ **Un seul fichier ne peut pas etre fourni tel quel dans cette archive :
> `android/gradle/wrapper/gradle-wrapper.jar`** (binaire compile). Les
> scripts `gradlew`/`gradlew.bat` et `gradle-wrapper.properties` sont bien
> presents, mais ce `.jar` doit etre (re)genere une seule fois avant le
> premier build local :
> - Le plus simple : ouvrir le dossier `android/` dans Android Studio, qui
>   le regenere automatiquement a l'ouverture ; ou
> - En ligne de commande, si Gradle est installe sur la machine :
>   `cd android && gradle wrapper --gradle-version 8.4 && cd ..`.
>
> Sur **GitHub Actions** et sur **FlutLab**, ce fichier est regenere
> automatiquement (SDK Flutter/Gradle deja installes cote serveur) : aucune
> action requise dans ces deux cas.

Pour generer aussi le dossier `windows/` (executable de bureau, non requis
pour Android/FlutLab) :

```bash
flutter create --platforms=windows .
flutter build windows --release
```

## Sur FlutLab (flutlab.io)

FlutLab est un IDE Flutter en ligne : il ne complete pas automatiquement les
dossiers de plateforme manquants (contrairement a `flutter create` en local
ou en CI), il faut donc lui fournir un projet deja complet — ce que fait
cette archive.

1. Compresser le contenu de ce dossier en `.zip` (pubspec.yaml a la racine
   de l'archive).
2. Sur flutlab.io : **New Project → Upload as .zip** (ou "Import from
   codebase").
3. Ouvrir le projet, cliquer sur **pub get**, puis choisir la cible
   **Android** et cliquer sur **Build**.
4. Si FlutLab signale une erreur liee au wrapper Gradle (`gradle-wrapper.jar`
   introuvable), utilisez le bouton **Build** une seconde fois : FlutLab
   provisionne son propre toolchain Gradle cote serveur des le premier
   build reussi. Si l'erreur persiste, regenerez le `.jar` localement (voir
   ci-dessus) puis re-uploadez le zip.

> ℹ️ FlutLab construit des APK/AAB Android, des IPA iOS et des apps Web. Il
> ne compile pas d'executable Windows (.exe) — cette cible reste disponible
> uniquement via `flutter build windows` en local ou via le workflow GitHub
> Actions fourni (`.github/workflows/build.yml`).

Codes par defaut : Directeur = 1234, Enseignant = 0000 (a changer des la
premiere utilisation dans Configuration de l'ecole -- un PIN laisse vide y
est desormais refuse).
