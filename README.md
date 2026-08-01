# Ecole Primaire - Gestion Scolaire (Flutter, 100% Offline)

Application Flutter complete de gestion d'une ecole primaire, fonctionnant
**entierement hors connexion Internet**. Toutes les donnees sont stockees
localement sur l'appareil (fichier JSON dans le repertoire prive de
l'application, avec sauvegardes automatiques horodatees et controle
d'integrite par somme SHA-256 lors des exports/imports).

> ⚠️ Le fichier de donnees local **n'est pas chiffre** (JSON en clair dans
> le stockage prive de l'app). Sur un appareil perdu/vole sans verrouillage
> d'ecran, les donnees restent lisibles hors de l'application. Envisager un
> chiffrement au repos (ex. package `encrypt`) si des donnees sensibles
> d'eleves l'exigent.

## Installation

```bash
flutter pub get
# regenerer les dossiers de plateforme si necessaire :
flutter create . --platforms=android,ios,windows
flutter run
```

## Profils
- **Directeur** : acces complet (configuration ecole, toutes les classes,
  statistiques generales, import JSON des enseignants, signature + cachet,
  verrouillage des notes, promotion, archives, inspection...).
- **Enseignant** : selectionne sa classe, saisit les notes, gere ses eleves,
  fait l'appel quotidien, genere bulletins et exporte le JSON de sa classe.

## Classes fixes
CP1, CP2, CE1, CE2, CM1, CM2 (non creables) avec matieres predefinies par niveau.

## Modules implementes
1. Connexion par profil + PIN
2. Configuration de l'ecole (logo, devise, adresse, tel, email, annee scolaire)
3. Enseignant unique par classe
4. Signature et cachet (import image, sinon espaces reserves)
5. Eleves + matricule automatique (AAAA-CLASSE-NNN) + photo
6. Saisie des notes (9 evaluations / 3 trimestres) + coefficients
7. Moyennes, totaux, rangs, mentions, appreciations automatiques
8. Bulletins PDF (logo, photo, signature, cachet, QR code d'authentification)
9. Fiches de deliberation, fiches de calcul des moyennes
10. Registres officiels (appel, notes, resultats)
11. Presences quotidiennes + historique + recherche par date + statistiques + alertes
12. Statistiques par matiere, par classe, comparaison des 9 evaluations
13. Tableau d'honneur, classements, admis / recales
14. Tableau de bord directeur + statistiques comparatives de l'ecole
15. Alertes pedagogiques intelligentes
16. Rapport annuel automatique
17. Mode Inspection scolaire (dossier complet PDF)
18. Assistant de controle avant generation des bulletins
19. Import / Export JSON (mensuel, trimestriel, annuel) avec checksum SHA-256
20. Sauvegarde / restauration complete + sauvegardes automatiques
21. Archivage des annees scolaires + promotion automatique
22. Historique des modifications (audit)
23. Cahier de textes numerique
24. Devoirs et exercices
25. Emploi du temps
26. Frais scolaires
27. Carnet de comportement
28. Communication ecole-parents (documents imprimables)
29. Documents administratifs (attestations, certificats, convocations, cartes)
30. Transferts d'eleves
31. Dossier complet de l'eleve
32. Groupes de niveau
33. Recherche rapide (nom, prenom, matricule)
34. Impression groupee + export PDF
35. Journal de bord du directeur
36. Verification QR d'un bulletin
37. Protection par PIN, interface responsive telephone / tablette / desktop

## Theme
Palette WhatsApp : vert teal #075E54, vert #128C7E, vert clair #25D366,
bulle #DCF8C6, fond chat #ECE5DD.
