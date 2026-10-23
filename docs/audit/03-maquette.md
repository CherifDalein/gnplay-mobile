# Audit maquette GNPlay vs app Flutter (lecture seule)

Sources comparées
- Maquette : `/home/saliou/Bureau/gnplay/gnplay-mobile/GNPlay Design System/GNPlay Createur.dc.html` (source réelle des écrans ; `GNPlay Createur-print.dc.html` ne contient que la liste des 29 pages et un `<dc-import screen=...>` par page, aucun markup d'écran), `tokens/*.css`, `components/*/*.jsx`, `readme.md`.
- App : `/home/saliou/Bureau/gnplay/gnplay-mobile/lib`. Numéros de ligne relevés sur l'arbre de travail actuel (certains fichiers sont modifiés non commités : `video_detail_screen.dart`, `full_video_player_screen.dart`, `main.dart`).
- Convention : « mockup » = maquette ; tous les textes entre guillemets sont copiés de la maquette. Les écrans spectateur (17 à 29) sont inventoriés mais hors périmètre de l'app créateur ; l'écran « Séries » est exclu du décompte des manques (retiré volontairement).

---------------------------------------------------------------------

## 1. Inventaire des écrans de la maquette

La maquette a 29 écrans : 16 « CRÉATEUR » + 13 « SPECTATEUR », plus 3 surcouches globales (modale de suppression, toast, barre de navigation basse).

### Créateur

**01 Connexion (`login`)**
- Logo centré 150 px rendu en blanc (`filter: brightness(0) invert(1)`), titre « Content de vous revoir » (Sora 700 24/32), sous-titre « Connectez-vous à votre espace créateur. » (13 px, text-3).
- Champ « Numéro de téléphone » : libellé 11 px au-dessus, boîte 50 px, préfixe « +224 », séparateur vertical, valeur « 621 45 88 07 ».
- Champ « Mot de passe » : « •••••••• » + bouton texte or « Afficher » / « Masquer ».
- État erreur dessiné : « Numéro de téléphone ou mot de passe incorrect » (11.5 px, danger).
- Bouton primaire h52 « Se connecter » / « Connexion… » (chargement), lien « Mot de passe oublié ? » (12.5 px, text-2), séparateur « ou », bouton secondaire bordure brand-700 « Créer un compte ».

**02 Inscription · vérification (`signup`)**
- Flèche retour 20 px + 2 barres de progression (3 px, or / border).
- Étape 1 : « Créer votre compte », « Étape 1 sur 2 · vos informations ». Champs Nom complet (« Mariama Diallo »), Pays (« Guinée (GNF) » + chevron), Numéro de téléphone, Mot de passe. Bouton « Continuer ».
- Étape 2 : « Vérification », « Code à 6 chiffres envoyé au +224 621 45 88 07 ». 6 cases (ratio 1/1.15, Sora 700 20, la case active a une bordure or). « Renvoyer le code dans 00:42 » (compte à rebours en or). Bouton « Vérifier ». Note : « Votre compte est créé en tant que spectateur. Vous pourrez passer créateur juste après. »

**03 Devenir créateur (`become`)**
- Hero 300 px, dégradé 135° #2A0E1F, #5C1330 à 45 %, #C4183F, rayures verticales, 3 petites barres blanches en haut à gauche. Titre « Passez créateur sur GNPlay » (Sora 800 32/38, max 270).
- 3 avantages numérotés (pastille ronde or 26 px) : « Vendez vos vidéos / Fixez votre prix, ou publiez gratuitement. », « Suivez vos statistiques / Vues, achats, taux de complétion par vidéo. », « Retirez vos gains / Versement direct sur votre compte mobile money. ».
- Bouton h54 « Devenir créateur », « Cette action est définitive. ». Toast de succès « Vous êtes créateur. Publiez votre première vidéo ! », puis redirection vers l'upload.

**04 Tableau de bord (`dash`, onglet Accueil)**
- Avatar dégradé 42 px (initiales), nom (14.5/600), pastille « CRÉATEUR » (brand, point or). Cloche 40 px avec point or 8 px (sans compteur).
- Carte solde (rayon 18, padding 20, cercle pointillé décoratif à right/top −30) : « SOLDE RETIRABLE » (11.5, letter-spacing .04em), montant Sora 800 34 or clair + « GNF », « Solde du portefeuille : … GNF · +… ce mois-ci » (le « +… ce mois-ci » en vert), bouton translucide « Retirer mes gains » (h40 rayon 10).
- Grille 2×2 de stat tiles : « Vidéos publiées » (icône vidéo), « Vues totales » (œil), « Abonnés » (utilisateurs), « Revenu du mois » (pièces ; valeur « 1,24 M »).
- « Vos vidéos les plus vues » + lien « Tout voir » ; 3 lignes (miniature 74×48, titre, « N vues · X GNF » en or clair, chevron).
- Aucun état vide ni erreur dessiné.

**05 Mon contenu — vidéos (`videos`, onglet Vidéos)**
- Titre « Mon contenu » (22 px) + pastille d'action « Nouvelle vidéo » (icône +, h34, pill or translucide).
- Barre de recherche (« Rechercher une vidéo ») + bouton filtre 44 px (actif : fond brand 20 %, bordure #C4183F, icône blanche, point or).
- Onglets segmentés « Vidéos (5) » / « Séries (3) » avec pastille de compteur.
- Panneau de filtres (chips) : « Toutes », « Publiées », « En traitement », « Brouillons », « Échecs ». Ligne « Filtre : » + chip fermable + compteur « N vidéos ».
- Carte vidéo : miniature 104×66 (durée en bas à droite), titre 13.5/600, pastille de statut (« Publiée », « Masquée », « En traitement », « Échec »), « prix · N vues · X GNF ». Pied de carte avec libellé « Publiée » / « Masquée » + switch, affiché seulement si la vidéo est publiée.
- État échec : bandeau rouge « Le transfert a échoué à 62 %. » + bouton plein « Réessayer ».
- Onglet Séries : voir 06 (hors périmètre).

**06 Détail d'une série (`series`)** : écran retiré volontairement. Contenu : hero 180 px, « Mode de vente » (« Pack saison » / « Par épisode »), liste d'épisodes réordonnable, stats, switch « Série publiée ». Ne pas compter comme manquant.

**07 Détail vidéo (`detail`)**
- Zone d'aperçu 212 px (rayures, texte mono « lecture de l'aperçu 15 s », pastille « Aperçu 15 s », fine barre de progression or à 38 %, bouton retour rond).
- Titre Sora 700 19/25, ligne « statut · prix · publiée le 12 juin », bouton « Modifier » (bordure border-1, rayon 10).
- Grille 3×2 de tuiles : « Vues », « Spectateurs uniques », « Vues complétées », « Likes », « Achats », « Revenu net ».
- Carte « Taux de complétion moyen » + « 68 % » + barre dégradée.
- Bouton ligne « Voir les statistiques détaillées » + chevron (h48, surface-1, bordure).
- Carte « Publiée / Masquée » avec « Visible dans le catalogue public » + switch 46×26.
- Bouton danger « Supprimer la vidéo ».
- Modale de suppression (bottom sheet) : « Supprimer cette vidéo ? », « Elle disparaîtra du catalogue. Les spectateurs qui l'ont déjà achetée garderont leur accès. », boutons « Annuler » / « Supprimer » (plein #FF5A5F, texte #1A0712).

**08 Statistiques (`stats`)**
- Titre « Statistiques » ; sélecteur de vidéo (titre + « Changer ⌄ » en or, h48).
- Anneau 170 px (trait 11 sur un viewBox de 120, donc environ 15.6 px à l'échelle) avec « 68% » et « taux de complétion moyen ».
- Tableau : « Vues totales », « Spectateurs uniques », « Vues complétées », « Likes », « Nombre d'achats », « Revenu net (part créateur) » (« 1 842 000 GNF » en or clair).
- Note : « Le revenu affiché est déjà net de la commission de la plateforme. »

**09 Nouvel upload (`upload`, 4 étapes)**
Titre « Nouvelle vidéo » + « Annuler », 4 barres, « Étape N sur 4 · {Sélection | Informations | Envoi | Traitement} ».
- 1 Sélection : zone en tirets 1.5 px (icône lecture pleine or dans un rond), « Choisir une vidéo », « MP4 ou MOV · l'envoi reprend automatiquement s'il est interrompu ». Ligne fichier « konakry-nights-final.mp4 », « 842 Mo · 24 min 08 s » + coche verte. « Continuer ».
- 2 Informations : « Titre * » (étoile rouge), « Description », « Prix » (« 15 000 GNF »), tuile « Gratuite / Prix = 0 », « Miniature — URL de l'image » (mono), bandeau info bleu « L'envoi direct d'un fichier image n'est pas encore disponible côté API — collez une URL en attendant. », bouton « Envoyer la vidéo ».
- 3 Envoi : « 62 % » (Sora 800 44, « % » en 20 px text-3), « Envoi en cours… », barre dégradée 8 px, « Ne quittez pas l'application. En cas de coupure, l'envoi reprendra où il s'est arrêté. », lien rouge « Annuler l'envoi ».
- 4 Traitement : rond pulsant avec triangle de lecture, « Traitement en cours », « Génération des qualités vidéo et de l'aperçu de 15 secondes. », barre jaune #E8B23D, « N % · vous pouvez fermer l'app », bouton « Traitement… » (désactivé) puis « Terminer ». Toast « Vidéo prête et publiée ».

**10 Portefeuille (`wallet`, onglet Gains)**
- Titre « Portefeuille », 2 cartes : « PORTEFEUILLE » (« GNF · tout confondu ») et « RETIRABLE » (dégradé #2A0E1F→#8A1436, bordure #C4183F, bouton « i », « GNF · gains nets »).
- Info-bulle : « Le solde retirable ne compte que vos gains de ventes. Il peut être inférieur au portefeuille si vous avez rechargé votre compte pour acheter des vidéos. »
- Boutons « Retirer mes gains » (h48, primaire) et « Recharger » (contour).
- « Historique » : lignes avec icône 34 px colorée (↓ vert, ↑ rouge marque, bleu pour recharge, gris pour achat, jaune pour remboursement), libellé, date, montant sans « GNF » (« +126 000 », « −500 000 »). Exemples : « Gain sur vente — Nuits de Conakry », « Retrait Orange Money », « Recharge du compte », « Achat — La saison des pluies », « Remboursement retrait échoué ».
- Toutes les lignes ouvrent le détail de retrait.

**11 Demande de retrait (`payout`)**
- « Retirer mes gains », carte « Solde retirable ».
- « Montant » : boîte avec montant Sora 800 30 + « GNF ». Message « Minimum : 10 000 GNF » / « Solde insuffisant » (rouge) + lien « Tout retirer ».
- Pavé numérique 3×4 : 1-9, « 000 », 0, « ⌫ » (h44).
- « Opérateur mobile money » : 3 tuiles h52 « Orange Money » (instantané), « MTN MoMo » (~5 min), « Wave » (instantané).
- Champ « Numéro destinataire ».
- État limite : « Vous avez atteint la limite de demandes de retrait. Réessayez dans quelques minutes. »
- Bouton h54 : « Confirmer le retrait » / « Montant trop faible » / « Solde insuffisant » / « Envoi de la demande… ». Désactivé = #1f1f25 + texte text-3.

**12 Suivi du retrait (`payoutDetail`)**
- Rond 72 px + icône, « 500 000 GNF » (Sora 800 28), statut « En cours de traitement » (bleu) / « Retrait terminé » (vert) / « Retrait échoué » (rouge).
- En attente : point bleu pulsant + « Actualisation automatique ».
- Tableau : « Opérateur », « Numéro », « Référence » (PO-4F82C1), « Demandé le » (« 20 juin, 09:41 »), « Traité le ».
- En échec : « Motif » (« Compte destinataire injoignable ») + « Montant recrédité au portefeuille ».
- Bouton « démo — voir l'état suivant » : élément de prototype, à ne pas implémenter.

**13 Profil (`profile`, onglet Profil)**
- Titre « Profil », avatar 72 px dégradé 2 couleurs (#5C1330→#C4183F) avec badge « + » or, nom (Sora 700 17), « @mariama.films » (or), bio « Documentariste, Conakry. ».
- 2 tuiles : « 1 284 / Abonnés » et « 12 / Vidéos publiées ».
- Liste : « Appareils connectés » (badge « 2/3 »), « Notifications », « Réglages & sécurité », « Statistiques de la chaîne » (ouvre l'écran Statistiques).
- Bouton danger « Se déconnecter » h48.

**14 Appareils connectés (`devices`)**
- « Appareils connectés », « N/3 appareils actifs » + 3 segments or/gris.
- Carte d'appareil : icône téléphone 34 px, nom, pastille « CET APPAREIL » (9.5 px 700 vert sans point), méta (« iOS 17 · actif maintenant »), bouton « Révoquer » (rouge contour, absent pour l'appareil courant).
- Bandeau jaune si 3/3 : « Limite atteinte. Révoquez un appareil avant d'en connecter un nouveau. »

**15 Notifications créateur (`notifs`)**
Seul l'état vide est dessiné : cercle en tirets avec cloche, « Aucune notification pour le moment », « Vos alertes apparaîtront ici. », lien « Tout marquer comme lu » toujours visible. La note de la maquette précise « pas de notification créateur » (limite API). Le design de ligne de notification n'existe que côté spectateur (écran 28).

**16 Réglages & sécurité (`settings`)**
- Sections « SÉCURITÉ » (10.5 px, letter-spacing .08em) : « Changer le mot de passe », « Se déconnecter de cet appareil », « Se déconnecter de tous les appareils » (rouge).
- « PRÉFÉRENCES » : « Mode sombre » / « Recommandé pour la vidéo » + switch. Toast « Le mode clair arrive dans une prochaine version ».
- « À PROPOS » : « GNPlay Créateur · version 1.0.0 », « Conditions générales · Mentions légales ».

### Spectateur (hors périmètre de l'app créateur, listés pour exhaustivité)
- **17 Catalogue** : « Bonsoir, Mariama », « À regarder ce soir », pastille solde, recherche + filtre catégories, « Reprendre », carte « À LA UNE », « Mini-séries », rangées « Nouveautés » et « Populaires cette semaine » (badge « ACHETÉE »).
- **18 Recherche** : « Titre, créateur, catégorie… », « RECHERCHES RÉCENTES », « CATÉGORIES » (tuiles dégradées).
- **19 Fiche vidéo** : hero 228, badge « Aperçu 15 s gratuit », stats, créateur + « S'abonner », description, bloc « MINI-SÉRIE », CTA sticky « Acheter · 15 000 GNF » / « Reprendre la lecture ».
- **20 Fiche série** : « MINI-SÉRIE », carte « PACK SAISON », « Acheter la saison », liste « Épisodes ».
- **21 Chaîne créateur** : bannière, avatar, « S'abonner », onglets Vidéos / Séries, grille.
- **22 Paiement** : « Moyen de paiement » (Solde GNPlay / Orange Money / MTN MoMo), « Solde insuffisant. Rechargez votre portefeuille ou payez par mobile money. », « Frais de service », « Total à payer ».
- **23 Lecteur** : « flux vidéo — 720p », menu qualités, « Fin de l'aperçu gratuit », « Achetez la vidéo pour la regarder en entier. », « ÉPISODE SUIVANT ».
- **24 Ma bibliothèque** : onglets « Achetées » / « En cours » / « Gratuites », vide « Rien ici pour l'instant » + « Explorer le catalogue ».
- **25 Mes abonnements**.
- **26 Solde & achats** (« Mon solde », « DISPONIBLE »).
- **27 Recharger** : « Solde actuel », « Montant » (grille 3 colonnes), « Payer avec » (Orange Money / MTN MoMo / Wave avec délais), « Nouveau solde », « Recharger X GNF », « Vous recevrez une demande de confirmation sur votre téléphone. ».
- **28 Notifications spectateur** : cartes avec icône, titre, corps, heure, point or si non lue.
- **29 Profil spectateur** : « Vous filmez aussi ? », « Passez créateur et vendez vos vidéos sur GNPlay. », « Devenir créateur ».

### Surcouches globales
- **Barre de navigation créateur** : Accueil / Vidéos / Publier (FAB 48 px, dégradé 140° #C4183F→#F5A623, translateY −16, ombre `0 8px 20px rgba(196,24,63,.45)`) / Gains / Profil. Hauteur 86, fond rgba(11,11,13,.92) + `backdrop-filter: blur(14px)`, icônes 22 px trait 1.8, libellé 9.5 px.
- **Toast** : bas de l'écran (bottom 110), surface #1f1f25, bordure border-1, rayon 14, point vert 8 px, ombre card.
- **Modale de suppression** : voir écran 07.

---------------------------------------------------------------------

## 2. Correspondance Flutter et écarts écran par écran

Légende : [BUG] comportement ou rendu manifestement faux ; [TXT] texte différent ; [DESIGN] visuel ou composant différent ; [MANQUE] absent ; [EXTRA] présent côté Flutter mais pas dans la maquette.

### Transverse (affecte tous les écrans)
1. [BUG] **Police Sora non appliquée à certains textes.** `AppFonts.display = 'Sora'` (`app_theme.dart:102`) est passé à `TextStyle.fontFamily` brut. Le package `google_fonts` enregistre ses familles sous des noms comme `Sora_700`, et `pubspec.yaml` ne déclare aucune police embarquée (bloc `fonts:` commenté, l.89-102). `fontFamily: 'Sora'` ne se résout donc probablement pas : repli sur la police système. Utilisations touchées :
   - `gn_button.dart:67` : **tous les libellés de boutons** (la maquette impose Sora 700).
   - `become_creator_screen.dart:137` (titre du hero) et `:204` (numéros des avantages).
   - `earnings_screen.dart:358` (montants de l'historique).
   À confirmer visuellement, mais le risque est élevé. Correctif : remplacer par `GoogleFonts.sora(...)` ou bundler Sora/Inter dans `assets/fonts` et les déclarer dans `pubspec.yaml` (ce qui supprime aussi la dépendance réseau au premier lancement).
2. [DESIGN] **Icônes** : le design system interdit les polices d'icônes (« Aucune police d'icônes… »). Le code utilise 31 occurrences de `Icons.*` (Material) dans 13 fichiers : `arrow_back` ×7, `search`, `tune`, `close`, `chevron_right` ×2, `add`, `edit_outlined`, `phone_iphone`, `notifications_none`, `check`, `play_arrow_rounded`, `pause`, `volume_*`, `refresh`, `priority_high`, `wifi_off_rounded`, `check_circle_rounded`, `error_outline_rounded`. `GnLineIcon` (`gn_line_icon.dart`) ne couvre que 12 icônes (home, video, plus, wallet, user, bell, eye, group, chevronRight, arrowUp, arrowDown, info). Manquent : arrowLeft, search, filter (sliders), close, check, coins, phone, refresh, alert, play (plein), pause, heart, settings.
3. [DESIGN] **Bouton retour** : la maquette utilise partout le même tracé (`M19 12H5M11.5 5.5 5 12l6.5 6.5`, trait 2, text-2). L'app a 7 versions : `Icons.arrow_back` dans video_stats, payout_request, payout_detail, devices, notifications, settings, forgot_password, video_detail (l.217, l.637), et un `_BackArrowPainter` privé dans `register_screen.dart:652`. Il faut un `GnBackButton` partagé.
4. [DESIGN] **En-tête d'écran secondaire** dupliqué 7 fois (`_Header` : IconButton + Sora 17). Même contenu partout ; à factoriser (`GnScreenHeader`).
5. [DESIGN] **Toasts** : la maquette a un toast unique (surface #1f1f25, bordure, rayon 14, point vert 8 px). L'app utilise 18 `SnackBar` par défaut, rouges pleins (`AppColors.danger`) pour les erreurs ou `surface3`/`warning`. Pas de `SnackBarTheme` dans `AppTheme` (`app_theme.dart:169-210`). Messages de succès de la maquette absents : « Vidéo masquée du catalogue » / « Vidéo publiée », « Appareil révoqué », « Tout est marqué comme lu », « Vous êtes créateur. Publiez votre première vidéo ! », « Vidéo prête et publiée », « Demande envoyée — statut « En cours » », « Vidéo supprimée du catalogue ».
6. [DESIGN] **Modales** : la maquette n'a qu'un bottom sheet (fond rgba(5,5,7,.72), carte surface-1, rayon haut 22, Sora 700 18, texte 12.5 text-2, boutons h48 « Annuler » contour + « Supprimer » plein #FF5A5F texte #1A0712). L'app utilise des `AlertDialog` centrés (`video_detail_screen.dart:141`, `settings_screen.dart:138`) avec boutons texte Material.
7. [DESIGN] **Switch** : `GnContentSwitch` (`creator_content_widgets.dart:80-127`) est dupliqué hors du design system et utilise `accent500` (or) pour l'état actif (l.94). Le `ToggleSwitch.jsx` de la maquette et tous les écrans utilisent `brand-600` #A8123B (`#A8123B` dans `switchBg` et `darkBg`). Manque aussi la variante `size: 'sm'` (44×25, bouton 19, left 22) des cartes de liste. L'app utilise 46×26 partout, y compris dans la liste.
8. [DESIGN] **Marge basse du contenu** : 116 px partout dans l'app (`EdgeInsets.fromLTRB(20,14,20,116)`) contre `padBottom: 100px` dans la maquette pour les écrans avec nav et 40 px sans. Sur les écrans sans nav (devices, notifications, settings, stats), l'app garde 116 alors que la maquette met 40.
9. [DESIGN] **Fond d'application** : le dégradé radial `AppGradients.appBackground` (`app_theme.dart:74-79`) donne un cercle de rayon 1.65 × largeur d'écran ; la maquette est `radial-gradient(1200px 700px at 20% -10%, #1A0712 0%, #0B0B0D 60%)` (ellipse 1200×700, donc un halo beaucoup plus large). Écart faible.
10. [DESIGN] **Miniature par défaut** : `_StripedPlaceholder` (`creator_content_widgets.dart:359-409`) et `_ThumbnailPlaceholder` (`creator_dashboard_screen.dart:535-558`) peignent des rayures à 45° de #1A0C12 sur fond `brand950` #1A0712 ; la maquette alterne #241019 / #1a0c12 à 115° (`repeating-linear-gradient(115deg,#241019 0 6px,#1a0c12 6px 12px)`). Deux implémentations identiques à fusionner.
11. [DESIGN] **États de chargement/erreur** : l'app a `GnLoadingState` / `GnAsyncError` (spinner, icône `wifi_off`, « Impossible de charger le contenu », « Réessayer »), jamais dessinés dans la maquette. Aucune règle de design à respecter, mais à valider côté design : bouton pill `OutlinedButton`, icône Material, texte brut de l'exception (`friendlyErrorMessage` renvoie `error.toString()`).
12. Navigation : la maquette ouvre les sous-écrans (Appareils, Notifications, Réglages, Statistiques) par push avec retour ; `profile_screen.dart:218` envoie « Statistiques de la chaîne » vers `/home`.

---

### 01 Connexion → `lib/features/auth/presentation/screens/login_screen.dart`
Très fidèle (textes, séquence, espacements 26/34/14/22/16/26/18).
- [DESIGN] Logo : mockup l'affiche en blanc (`brightness(0) invert(1)`, largeur 150) ; `GnplayLogo` (`gnplay_logo.dart:11`) charge `LOGO_TRANSPARENT.png` en couleur, hauteur 150 (pas largeur). Choisir/produire la variante blanche.
- [DESIGN] Champ téléphone : mockup = boîte 50 px avec préfixe « +224 » en 13/600 text-3, séparateur 1×18, valeur à droite. App = un seul `GnTextField` (l.100-112) avec placeholder « +224 621 45 88 07 » : pas de préfixe fixe ni de séparateur ; le pays n'est pas dissocié. Hauteur du champ par défaut ≈ 46 contre 50.
- [TXT] Bouton œil : « Voir » (l.134) au lieu de « Afficher ». Taille 10 px (`micro`) au lieu de 11 px. Rendu en `TextButton` (zone tactile et padding Material) au lieu d'un texte or aligné.
- [TXT] Erreur : le message de l'API (`error.message`, l.55-59) s'affiche à la place de « Numéro de téléphone ou mot de passe incorrect » ; à normaliser pour 401.
- [DESIGN] Bouton chargement : `GnButton.isLoading` affiche un spinner ; le mockup remplace le libellé par « Connexion… ».
- [DESIGN] « Mot de passe oublié ? » : `TextButton` avec padding Material (zone 48 px) au lieu d'un texte centré 12.5 px ; ajuster `padding`.

### 02 Inscription · vérification → `register_screen.dart`
Fidèle sur la structure et les textes (« Créer votre compte », « Étape 1 sur 2 · vos informations », « Vérification », « Code à 6 chiffres envoyé au », « Vérifier », note spectateur).
- [BUG] Compte à rebours **figé** : `'00:45'` en dur (l.386). Mockup : « Renvoyer le code dans 00:42 » qui décompte. Ajouter un minuteur ; désactiver le renvoi tant qu'il tourne. Aujourd'hui le bouton « Renvoyer » est cliquable immédiatement.
- [DESIGN] Champ Pays : `GnCard` + glyphe texte `⌄` (l.583-586) au lieu du chevron SVG 13 px text-3 ; non interactif (mockup identique, mais c'est un sélecteur).
- [DESIGN] Libellés flottants Material (`GnTextField label`, `floatingLabelBehavior.always`) : ressemble au mockup (libellé 10.5 au-dessus de la valeur), mais la hauteur et l'alignement vertical diffèrent car le libellé flotte sur la bordure Material et non dans la boîte (padding 11/14 + libellé 10.5 + marge 3-4 + valeur 14).
- [DESIGN] Champ mot de passe de l'étape 1 : bouton « Voir » dans un champ où la maquette n'a pas de bouton œil (ni sur ce champ). Écart mineur (fonction utile, à décider).
- [DESIGN] Cases OTP : case active = bordure or ✓ ; cases remplies sans bordure distincte ✓. Le champ réel est un `TextFormField` transparent (opacité .01) : accessibilité et collage à vérifier ; apparence OK.
- [DESIGN] Flèche retour : `_BackArrowPainter` privé (voir transverse 3).

### 03 Devenir créateur → `lib/features/creator/presentation/screens/become_creator_screen.dart`
Fidèle (textes, hauteur 300, rayures, 3 barres, bouton h54, « Cette action est définitive. »).
- [DESIGN] Dégradé du hero : `AppGradients.brand` (stops 0 / .5 / 1) au lieu de 0 / 45 % / 100 % (l.111). Rayures : alpha .07 (l.245) alors que la maquette les compose avec `opacity:.5`, donc effectivement ≈ .035.
- [BUG] Titre du hero en `fontFamily: 'Sora'` brut (l.137) : voir transverse 1 (même problème pour le numéro des avantages, l.204).
- [MANQUE] Toast « Vous êtes créateur. Publiez votre première vidéo ! » après succès (l.67-69 redirige vers `/publish` sans message).
- [DESIGN] Pastille des avantages : or 14 % ✓. Séparateurs `surface1` ✓.

### 04 Tableau de bord → `creator_dashboard_screen.dart`
Très fidèle (structure, textes, espacements 20/14/24/12/10).
- [DESIGN] Cloche : le point or 8 px sans chiffre de la maquette est remplacé par une pastille avec compteur (« 9+ ») (l.165-191). Écart de design assumé ? À trancher.
- [DESIGN] « SOLDE RETIRABLE » : `letterSpacing: 0` (l.233) au lieu de .04em ≈ 0.46 px.
- [DESIGN] Cercle pointillé décoratif : décalage `right/top: -50` (l.218-219) alors que la maquette met −30 ; il paraît plus petit/éloigné. Les pointillés sont 42 arcs au lieu d'un `border: 1px dashed`.
- [DESIGN] Dégradé de la carte : `AppGradients.brand` finit à `brand500` à 100 % ; la maquette finit à 130 % (couleur finale moins saturée dans le coin). Voir tokens.
- [DESIGN] Tuiles : `GridView.count` avec `childAspectRatio: 1.55` fixe (l.332) → hauteur dépend de la largeur ; risque de débordement avec la police agrandie. Mockup : hauteur au contenu.
- [DESIGN] Icône « Revenu du mois » : `wallet` (l.362) au lieu de « pièces » ; « Abonnés » : `group` (ok, équivalent).
- [DESIGN] Liste top vidéos : `.take(5)` (l.53) au lieu de 3. Valeur de revenu `formatMoney` → « 1 842 000 GNF » ✓.
- [DESIGN] Marge basse 116 vs 100.
- [EXTRA] `_NotCreatorYet`, `_NoVideosYet`, `GnLoadingState`, `GnAsyncError` : états non dessinés.

### 05 Mon contenu (vidéos) → `lib/features/videos/presentation/screens/videos_screen.dart`
- [TXT] Bouton d'action : « Publier » (l.246) au lieu de « Nouvelle vidéo » ; taille `micro` 11.5 ✓, hauteur 34 ✓.
- [MANQUE] Onglets segmentés avec compteur (« Vidéos 5 ») : absents. Sans la série, il reste un seul onglet ; décider si on garde un compteur visible (par ex. sous le titre : « 5 vidéos »).
- [DESIGN] Recherche : `TextField` Material avec `Icons.search` (l.290), `contentPadding: zero` ; mockup = icône trait 16 px, texte 13 px, padding 14. Bouton filtre : actif = `brand950` + bordure `brand700` + icône or (l.314-327) alors que la maquette passe en fond brand 20 %, bordure #C4183F, icône blanche. `Icons.tune` ≠ icône « sliders » du mockup (`M4 6h16M7 12h10M10 18h4`).
- [TXT] Chips de filtre : ordre et libellés (l.681-689) = « Toutes », « Publiées », « Brouillons », « Traitement », « Échec » ; mockup = « Toutes », « Publiées », « En traitement », « Brouillons », « Échecs ». L'enum (l.14) est dans le mauvais ordre.
- [DESIGN] `ChoiceChip` : sélectionné = `brand800` #5C1330 (l.386) au lieu de `brand600` #A8123B ; padding, check Material éventuel, hauteur 32+ ; mockup = pill 7×13, 12/600, pas de coche. Utiliser un chip maison.
- [TXT] « Filtre : » ✓. Compteur : « N résultat(s) » (l.444) au lieu de « N vidéos » / « 1 vidéo ». `Icons.close` au lieu de la croix SVG 11 px.
- [DESIGN] Carte : chevron droit ajouté (l.542-549), absent du mockup. Pastille statut ✓ (`GnStatusPill` neutre = #22222A ✓).
- [TXT] Statuts : `statusLabel` (`video_with_stats.dart:50-61`) = « Échec » / « Traitement » / « Publiée » / « Brouillon » ; mockup = « Échec » / « En traitement » / « Publiée » / « Masquée ». Remplacer « Traitement » et « Brouillon ».
- [TXT] Bandeau d'échec : « Le traitement de la vidéo a échoué. » (l.575) au lieu de « Le transfert a échoué à 62 %. » (nécessite le pourcentage ; sinon formulation neutre à valider). Le bouton « Réessayer » ✓ (mockup renvoie vers l'upload ; l'app relance le transcodage, comportement différent mais cohérent avec l'API).
- [DESIGN] Pied de carte : visible **toujours** (l.605-637) avec switch désactivé pour les vidéos en traitement/échec ; mockup ne l'affiche que pour les vidéos publiées/masquées (`toggleable`). Libellés : « Vidéo publiée » / « Publier dans le catalogue » (l.618-620) au lieu de « Publiée » / « Masquée ».
- [DESIGN] Switch or (voir transverse 7), 46×26 au lieu de 44×25.
- [DESIGN] Titre carte : `label` 13.5 avec interligne 1.4 (≈ 19) vs 18 px.
- [EXTRA] État vide « Aucune vidéo publiée » / « Aucun résultat » (carte `surface2`).

### 07 Détail vidéo → `lib/features/videos/presentation/screens/video_detail_screen.dart`
- [DESIGN] Bouton retour rond : `IconButton` + `Icons.arrow_back` (l.636-639, `_RoundIconButton` l.966-992) ; mockup = 34 px rgba(0,0,0,.55) avec flèche SVG 20 px trait 2.
- [DESIGN] Aperçu : bouton lecture central 62 px noir translucide (l.763-784), bouton muet (l.667-676) et lecture réelle ; mockup = aucun bouton central, simple barre 3 px or (38 %). Fonctionnel > maquette, mais le style du bouton (rond noir + `Icons.play_arrow_rounded`) devrait suivre le CTA du lecteur spectateur (rond or 64 px, triangle plein #1A0712) ou rester discret.
- [TXT] Ligne méta : `'${statusLabel} · ${prix} · publiée le ${date}'` (l.812) : affiche « publiée le » même pour un brouillon/échec/traitement et utilise `createdAt`. Mockup : « Publiée · 15 000 GNF · publiée le 12 juin ». À rendre conditionnel.
- [DESIGN] Bouton « Modifier » : `GnButton ghost sm` (Sora 12.5, h38/40, fond surface-1, rayon 12) ; mockup = texte 12/600 Inter, padding 8/12, transparent, bordure border-1, rayon 10.
- [TXT]/[DESIGN] Tuiles (l.853-871) : « Vues », « Spectateurs », « Achats », « Likes », « Revenu GNF », « Durée » ; mockup = « Vues », « Spectateurs uniques », « Vues complétées », « Likes », « Achats », « Revenu net » (ordre : vues, uniques, complétées, likes, achats, revenu). `Durée` à retirer ; ajouter « Vues complétées » (`analytics.completedViews`). Revenu : valeur compacte « 1,84 M » dans la maquette, entier avec espaces dans l'app. `childAspectRatio: 1.1` fixe (l.851).
- [EXTRA] Bouton « Voir la vidéo complète » (ghost, icône vidéo) (l.321-330) ; absent. À garder (fonction), mais pas de style défini dans la maquette.
- [DESIGN] « Voir les statistiques détaillées » : `GnButton ghost` centré avec icône œil à gauche (l.332-341) ; mockup = ligne h48 alignée à gauche, texte 13.5/600, **chevron à droite**, pas d'icône à gauche.
- [DESIGN] Complétion : ✓ (barre dégradée, « Taux de complétion moyen », « 68 % »). Écart : espace `SizedBox(14)`.
- [TXT] Carte publication : « Vidéo publiée » / « Publier cette vidéo » (l.938) au lieu de « Publiée » / « Masquée » ; sous-texte ✓.
- [TXT]/[DESIGN] Suppression : `AlertDialog` titre « Supprimer la vidéo », contenu = titre de la vidéo (l.141-166). Mockup : bottom sheet « Supprimer cette vidéo ? » + « Elle disparaîtra du catalogue. Les spectateurs qui l'ont déjà achetée garderont leur accès. » + boutons h48 (Supprimer en plein #FF5A5F). Le bouton « Supprimer la vidéo » ✓ (variant danger : bordure .35 ✓ mais h52 au lieu de 48).
- [DESIGN] Feuille « Modifier la vidéo » (l.994-1106) : non dessinée dans la maquette (« Formulaire d'édition — à câbler sur PATCH /videos/{id} ») ; fond `surface2` flottant avec marge 20. À aligner sur la carte de la modale (fond surface-1, rayon haut 22, poignée).
- [EXTRA] Bannière d'échec (« Le traitement de cette vidéo a échoué. », « Relancer le traitement »), vue « Cette vidéo n'existe plus. », bouton retour en `Icons.arrow_back` (l.215-218).

### 08 Statistiques → `lib/features/videos/presentation/screens/video_stats_screen.dart`
- [MANQUE] Sélecteur de vidéo : `_VideoPickerTile` (l.155-179) est une carte statique ; mockup = bouton h48 avec « Changer ⌄ » en or (11 px) qui change de vidéo. Pas de chevron/« Changer », pas d'action.
- [TXT] Lignes du tableau (l.188-195) : « Vues », « Spectateurs uniques », « Vues complètes », « Likes », « Achats », « Revenu » → mockup : « Vues totales », « Spectateurs uniques », « Vues complétées », « Likes », « Nombre d'achats », « Revenu net (part créateur) ».
- [DESIGN] Anneau : trait 11 px sur 170 px (`_RingPainter` l.419-428) au lieu d'environ 15.6 px (11 sur 120 ramené à 170) ; rayon 76 vs ≈ 73.7 ; pas d'animation (mockup transition .7 s). Texte central ✓.
- [DESIGN] En-tête : `Icons.arrow_back`. Le titre « Statistiques » ✓ (17 px). Note sous le tableau ✓ (texte identique).
- [DESIGN] Marge basse 116 (pas de nav dans la maquette).

### 09 Nouvel upload → `lib/features/publish/presentation/screens/publish_screen.dart`
- [TXT] Noms d'étapes (l.619-626) : « Fichier », « Détails », « Upload », « Traitement » → « Sélection », « Informations », « Envoi », « Traitement ».
- [DESIGN] Zone de dépôt : bordure pleine 1.5 px (l.282) au lieu de tirets ; icône `GnLineIcon.video` au lieu d'un triangle de lecture plein or ; pas d'animation `pulse` à l'étape 4 (la maquette fait pulser le rond).
- [MANQUE] Ligne fichier : « 842 Mo · 24 min 08 s » → l'app affiche « 842.1 Mo » avec point décimal anglais (l.360, `toStringAsFixed(1)`) et aucune durée ; coche `Icons.check` (l.369).
- [DESIGN] Étape 2 : « Titre * » (étoile non rouge, l.409) ; champs `GnTextField` (voir transverse). « Prix » : digits seuls, sans séparateur ni suffixe « GNF » (mockup : « 15 000 GNF »). Tuile « Gratuite / Prix = 0 » (bouton qui remet le prix à 0) remplacée par une tuile avec **switch** (l.430-449) → [DESIGN]. La tuile fait 104 px ✓.
- [DESIGN] Bandeau info : barre bleue de hauteur fixe 44 (l.469) ; mockup = barre pleine hauteur (stretch). Fond `infoBg` .14 vs .09, bordure .3 ✓.
- [DESIGN] Étape 3 : pourcentage sans le « % » en 20 px text-3 (l.514-520 : « 62 » seul) ; libellé « Envoi en cours… (3/10) » (l.524) avec compteur de parts au lieu de « Envoi en cours… » ; [MANQUE] lien rouge « Annuler l'envoi » sous le texte (seul « Annuler » en haut existe).
- [DESIGN] Étape 4 : barre jaune pleine #E8B23D dans la maquette ; `GnProgressBar` dessine un dégradé brand600→warning (`creator_content_widgets.dart:205`). Libellé final « Voir mon contenu » (l.610) au lieu de « Terminer » ; état intermédiaire « Traitement… » (bouton gris) → l'app affiche « Voir mon contenu » désactivé. Titre « Vidéo prête » (l.577) + « Publiée dans votre catalogue » : non dessinés (la maquette bascule sur toast + détail).
- [DESIGN] Bouton « Continuer » désactivé tant que pas de fichier : état gris ✓.
- [DESIGN] Échec d'upload : seulement un SnackBar rouge (l.47-55) ; la maquette propose « Réessayer » depuis la liste (« Le transfert a échoué à 62 % »). Pas d'état échec inline.

### 10 Portefeuille → `lib/features/earnings/presentation/screens/earnings_screen.dart`
Structure fidèle (titre 22, deux cartes, info-bulle, boutons, Historique).
- [DESIGN] Libellés des cartes : « PORTEFEUILLE » / « RETIRABLE » en `text3` des deux côtés (l.254-257) ; mockup : « RETIRABLE » en rgba(255,255,255,.75) et la légende « GNF · gains nets » en rgba(255,255,255,.6) sur la carte dégradée. Letter-spacing .03em absent.
- [DESIGN] Bouton « i » : `GnLineIcon.info` text2 (l.212) ; mockup = rond 13 px bordure blanche .5 avec « i » 9 px.
- [DESIGN] Boutons : `GnButton` `md` h52 pour les deux (l.103-114) ; mockup h48, « Retirer mes gains » Sora 13.5 (Inter 13 pour « Recharger »), « Recharger » transparent avec bordure border-1, padding 0/16.
- [DESIGN] Icônes d'historique : couleur « retrait » = `danger` #FF5A5F sur `dangerBg` (l.374-377) ; mockup = #C4183F (brand-500) sur rgba(168,18,59,.18). Achat/neutre #22222A ✓, remboursement jaune ✓, recharge bleu ✓, vente vert ✓.
- [TXT] Montants : « +126 000 GNF » / « -500 000 GNF » (l.355, trait d'union ASCII) ; mockup : « +126 000 » / « −500 000 » (vrai signe moins U+2212, sans « GNF »).
- [DESIGN] Lignes cliquables seulement si `payoutId != null` ; mockup : toutes ouvrent le détail (démo). OK fonctionnellement.
- [DESIGN] « Recharger » ouvre `showTopupSheet` (`topup_sheet.dart`) : bottom sheet DexPay (« Recharger mon portefeuille », montant libre, 4 montants rapides, « Payer avec mobile money », « Vous serez redirigé vers la page de paiement sécurisée DexPay. »). La maquette n'a pas de flux côté créateur (bouton `noop`) ; le flux « Recharger » le plus proche est l'écran spectateur 27 (grille 3×2 de montants, « Payer avec » Orange Money / MTN MoMo / Wave avec délais, « Nouveau solde », bouton « Recharger X GNF », « Vous recevrez une demande de confirmation sur votre téléphone. »). Écarts : sheet au lieu d'écran, chips Material `ActionChip`, icônes `Icons.check_circle_rounded` / `Icons.error_outline_rounded`, pas de « Solde actuel » / « Nouveau solde ».

### 11 Demande de retrait → `lib/features/earnings/presentation/screens/payout_request_screen.dart`
- [MANQUE] **Pavé numérique** 3×4 (touches « 1 »…« 9 », « 000 », « 0 », « ⌫ », h44, rayon 11, Sora 600 15) : absent ; l'app utilise un `TextField` + clavier système (l.154-170).
- [DESIGN] Montant affiché sans séparateurs de milliers (« 250000 ») ; mockup : « 250 000 ». Taille 30 ✓.
- [DESIGN] Sélecteur d'opérateur : `Wrap` de chips (l.236-250) avec le seul nom ; mockup = 3 tuiles égales h52 avec nom (12/600) **et délai** (« instantané », « ~5 min », 9.5 px). Données de délai à ajouter dans `PayoutProviderOption`.
- [TXT]/[BUG] Message minimum : « Minimum : 0 GNF » tant que le fournisseur n'est pas chargé (l.188 avec `minAmount` = 0).
- [TXT] Libellé du bouton : seulement « Confirmer le retrait » / « Envoi de la demande… » ; il manque « Montant trop faible » et « Solde insuffisant » sur le bouton désactivé (l.277-283). Bouton h52 (`md`) au lieu de 54 (`lg`).
- [DESIGN] Numéro destinataire : `GnTextField` éditable avec libellé flottant ; mockup = carte avec libellé 10.5 + valeur 14. OK.
- [DESIGN] Bandeau limite : ✓ texte identique, affiché sur erreur 429 uniquement.
- [DESIGN] En-tête `Icons.arrow_back`. Pas de padding bas pour la nav (40 ✓).

### 12 Suivi du retrait → `payout_detail_screen.dart`
- [TXT] Statuts (`payout_request.dart:26-38`) : « En attente » / « En cours » / « Retrait terminé » / « Retrait échoué » / « Annulé » ; mockup : « En cours de traitement » / « Retrait terminé » / « Retrait échoué ». Remplacer « En attente » et « En cours » par « En cours de traitement ».
- [DESIGN] Montant : `displayMd` 26 (l.543) au lieu de Sora 800 28. Icônes Material (`check`, `priority_high`, `refresh`) au lieu des tracés `check` / `alert` / `refresh` de la maquette (30 px, trait 2).
- [DESIGN] Point « Actualisation automatique » statique ; mockup = pulsation 1.4 s.
- [TXT] Dates : `20/06/2026, 09:41` (l.607-613) au lieu de « 20 juin, 09:41 ». Ligne en plus pour l'échec : le texte « Montant recrédité à votre portefeuille. » (l.598-601) est hors du tableau et orthographié « à votre » ; mockup : ligne supplémentaire du tableau « Montant recrédité au portefeuille ». « Motif » ✓.
- [DESIGN] Erreur de chargement = texte brut centré (l.461-472), pas de bouton réessayer.

### 13 Profil → `profile_screen.dart`
- [DESIGN] Avatar : `AppGradients.brand` à 3 stops (l.295) alors que mockup/dashboard = 2 couleurs `#5C1330→#C4183F` ; tailles 72 ✓, badge « + » ✓ (icône Material).
- [DESIGN] Abonnés : valeur brute `'${totalFollowers}'` (l.149, 175) au lieu de `formatGrouped` (« 1 284 ») ; typographie 20 ✓.
- [MANQUE] Badge « 2/3 » sur « Appareils connectés » (l.200-203) ; mockup affiche le compteur d'appareils.
- [DESIGN] « Statistiques de la chaîne » → `/home` (l.218) au lieu de l'écran Statistiques.
- [EXTRA] Bouton `Icons.edit_outlined` + feuille « Modifier le profil » ; libellé technique « Identifiant public (page_name) » (l.467) à remplacer par un libellé métier (« Identifiant public »).
- [DESIGN] Chevron `Icons.chevron_right`. Bouton déconnexion `danger` h52 (mockup h48).
- [DESIGN] Pas de bio de repli (le mockup montre toujours une ligne).

### 14 Appareils connectés → `devices_screen.dart`
- [TXT] ✓ (« N/3 appareils actifs », « Limite atteinte. Révoquez un appareil avant d'en connecter un nouveau. », « Révoquer », « CET APPAREIL »).
- [DESIGN] Pastille « CET APPAREIL » via `GnStatusPill` (avec point, 10 px, padding 8/2.5) ; mockup = 9.5 px/700, padding 2/6, **sans point**, vert 14 %.
- [DESIGN] Icône `Icons.phone_iphone`. Bouton « Révoquer » : TextButton rayon 9 ✓ bordure .3 ✓.
- [BUG] Erreur de chargement non traitée : `devicesState.valueOrNull ?? []` (l.34) → affiche « Aucun appareil enregistré » en cas d'erreur réseau. Ajouter un état erreur.
- [DESIGN] Méta : « iOS · il y a 2 j » vs « iOS 17 · il y a 2 jours » (le mockup écrit « il y a 2 jours », « il y a 3 semaines » ; l'app « il y a 2 j », « il y a 3 sem. »).

### 15 Notifications → `notifications_screen.dart`
- [DESIGN] « Tout marquer comme lu » visible seulement s'il y a des non lues (l.58) ; mockup : toujours visible.
- [DESIGN] Icône d'état vide `Icons.notifications_none` couleur border (invisible) dans un cercle plein ; mockup = cercle **en tirets** (`1px dashed`) et icône cloche à trait (#2C2C33). Texte ✓ (« Aucune notification pour le moment » Sora 600 15 : l'app utilise `label` Inter 13 → [DESIGN]).
- [DESIGN] Lignes (point or 7 px à gauche, titre 13, corps 11.5, heure 10 micro) : design non défini pour le créateur ; la maquette spectateur (28) utilise une carte avec tuile-icône 34 px, titre 12.5/600, corps 11 text-3 interligne 16, heure 10.5 text-4, **point or 8 px à droite**, fond de ligne différent pour les non lues. L'app s'en écarte (point à gauche, séparateur au lieu de carte).
- [BUG] Chargement/erreur : `valueOrNull ?? []` → une erreur s'affiche comme l'état vide.

### 16 Réglages & sécurité → `settings_screen.dart`
- [BUG]/[DESIGN] Switch « Mode sombre » : `final bool _dark = true` (l.18) ; le switch ne bouge jamais et ouvre un SnackBar (« Le mode clair arrive dans une prochaine version. » avec point final ; mockup sans point final, toast stylé).
- [DESIGN] Libellés de section : `micro` 10 + letter-spacing 1.2 px (l.226-229) vs 10.5 px et .08em (≈ 0.84 px).
- [DESIGN] Dernière ligne de carte sans séparateur dans l'app ; mockup : bordure basse sur toutes les lignes (masquée par le rayon ; écart visuel nul).
- [TXT] « Changer le mot de passe » ouvre `/forgot-password` via `context.go` (remplace la pile) ; mockup : toast « Envoi d'un code OTP de réinitialisation ». Confirmation « Se déconnecter de tous les appareils » en `AlertDialog` : « Déconnexion de tous les appareils » / « Toutes vos sessions actives seront révoquées, y compris celle-ci. » ; mockup : action directe + toast « Toutes les sessions ont été révoquées ».
- [DESIGN] Chevron `Icons.chevron_right`. Marge basse 116 vs 40.

### Écrans sans équivalent dans la maquette (hors série)
- `splash_screen.dart` : logo 96 + spinner or ; non dessiné.
- `forgot_password_screen.dart` : « Mot de passe oublié », « Recevez un code de vérification par SMS. », « Code envoyé au … », « Envoyer le code », « Réinitialiser le mot de passe », « Changer de numéro », « Mot de passe mis à jour. Connectez-vous. » ; non dessiné. Utiliser les mêmes composants que 01/02 (bouton retour, titre 24, cases OTP du 02 au lieu d'un `GnTextField` « Code à 6 chiffres »).
- `full_video_player_screen.dart` : plein écran créateur. Le plus proche : écran 23 Lecteur (barre supérieure titre + sélecteur de qualité, contrôles centraux, temps, « Fin de l'aperçu gratuit »). Messages d'erreur : « Impossible d'obtenir le lien de lecture sécurisé. », « Vous avez atteint la limite de 3 appareils actifs. Révoquez-en un pour regarder des vidéos sur celui-ci. », « La lecture a échoué. » : textes propres à l'app, aucun équivalent maquette.
- Écrans de série : `series` (06) absent volontairement.

### Écrans spectateur 17 à 29
Tous absents de l'app (aucune route spectateur dans `app_router.dart`). Non comptés comme manquants pour une app créateur. Éléments partagés à réutiliser si le spectateur est ajouté : écran 26 « Recharger », 27 notifications (design de ligne), 28 profil spectateur (carte « Vous filmez aussi ? »).

---------------------------------------------------------------------

## 3. Tokens : maquette vs `lib/core/theme/app_theme.dart`

### Couleurs (`tokens/colors.css` vs `AppColors`, l.4-45)
Toutes les couleurs nommées de la maquette existent avec la même valeur : `bg-app` #0B0B0D, `surface-1/2/3` (#16161A / #111116 / #1F1F25), `border-1/2` (#2C2C33 / #202026), `brand-950…500`, `accent-500/600/300`, `text-1…4`, `text-inverse` #1A0712, `success`, `warning`, `danger`, `info`, et leurs fonds (`.14` / `.1` / `.1` / `.14` : 0x24, 0x1A, 0x1A, 0x24 ✓).
Écarts :
- `AppColors.accent600` (#D98A0E, état survol du primaire) défini mais **jamais utilisé** (aucun état pressed/hover sur `GnButton`).
- Couleurs en dur hors tokens dans l'app et dans la maquette : #22222A (pastille neutre ; `gn_status_pill.dart:74`, `earnings_screen.dart:383,391`), #1A0C12 (rayures ; `creator_content_widgets.dart:395`, `creator_dashboard_screen.dart:593`), #241019 (rayures, seulement maquette). Créer `AppColors.surfaceNeutral` (#22222A) et `AppColors.thumbStripeA/B`.
- Valeurs de la maquette sans token : rgba(168,18,59,.22) (pill brand, présent en dur `0x38A8123B` dans `gn_status_pill.dart:78`), rgba(168,18,59,.18) (tuile icône, ≈ `brand600.withValues(.18)`), rgba(168,18,59,.2) (chip / filtre actif), rgba(245,166,35,.12/.14/.35) (pill or), overlays noirs rgba(0,0,0,.55/.6/.65), scrim modale rgba(5,5,7,.72), `#8b8b95` (onglet inactif ; « fg » des onglets segmentés et du menu), `#3a2a1a` (bordure d'épisode non publié), `#E8B23D` pour la barre de traitement (= `warning`).
- `AppColors.navBg` 0xEB0B0B0D (.92 ✓).

### Dégradés (`--gradient-*`, `AppGradients`, l.71-99)
- `gradient-brand` : `linear-gradient(135deg,#2A0E1F 0%,#5C1330 50%,#C4183F 130%)` ; Flutter `brand` : topLeft→bottomRight, stops 0 / .5 / 1 (la couleur finale est atteinte à 100 % au lieu de 130 %, donc plus saturée dans le coin). Le hero « Devenir créateur » utilise 45 % / 100 % (variante). L'avatar du profil/dashboard utilise 2 couleurs `#5C1330→#C4183F` (non tokenisé : défini en ligne `creator_dashboard_screen.dart:104-108`, mais `profile_screen.dart:295` prend `brand`).
- `gradient-brand-soft` : `140deg,#2A0E1F,#8A1436` ✓ ; la carte « Solde & achats » spectateur utilise `140deg,#2A0E1F,#8A1436 80%,#C4183F` (variante non tokenisée).
- `gradient-cta` : `90deg,#A8123B,#F5A623` ✓ pour les barres de progression ; **mais** le FAB de la nav utilise `140deg,#C4183F,#F5A623` (dans les écrans) alors que `BottomNav.jsx` du design system utilise `var(--gradient-cta)` : incohérence interne à la maquette ; l'app utilise `cta` (`gn_bottom_nav.dart:99`).
- Les angles CSS (135° / 140°) ne sont pas équivalents à `Alignment.topLeft → bottomRight` sur des boîtes non carrées. Utiliser `GradientRotation` ou des `Alignment` calculés pour les grandes cartes.

### Rayons (`--radius-*`, `AppRadii` l.60-69)
`sm` 9, `md` 12, `lg` 16, `xl` 20, `pill` 999, `phone` 46 : valeurs identiques. Rayons réellement utilisés par la maquette absents des tokens : 8 (tuile icône), 10 (boutons secondaires, miniatures, bandeaux), 11 (touches du pavé, tuiles de ledger), 13 (tuiles de métriques, cartes de liste), 14 (cartes secondaires), 18 (carte solde, zone de dépôt), 22 (bottom sheet haut). Le code Flutter les saisit en dur (`radius: 13`, `14`, `BorderRadius.circular(10)`…). À ajouter : `xs 8`, `r10`, `r11`, `r13`, `r14`, `r18`, `sheet 22`, ou réaligner la maquette sur 9/12/16/20.

### Espacements (`--space-*`, `AppSpacing` l.47-58)
Identiques (4, 8, 12, 16, 20, 24, 32, 40), mais la maquette utilise 6, 7, 9, 10, 11, 13, 14, 18, 22, 26, 28 en plus ; le code est truffé de valeurs en dur (`SizedBox(11)`, `13`, `26`…). Ce n'est pas un écart de valeur, mais l'échelle de 4 px n'est pas respectée par la maquette elle-même.

### Typographie (`tokens/typography.css` vs `AppTextStyles`, l.109-166)
- `text-display-lg` 800 34/1.1 Sora ✓, `display-md` 800 26/1.15 ✓, `title` 700 20/1.3 ✓, `heading` 700 16/1.3 ✓, `label` 600 13/1.4 Inter ✓, `body` 400 14/1.5 ✓, `caption` 500 11.5/1.4 ✓, `micro` 600 10/1.3 ✓.
- Tailles utilisées par la maquette **hors échelle** (toutes recréées en `copyWith(fontSize:)` dans l'app) : titre d'écran principal Sora 700 **22** (Mon contenu, Portefeuille, Profil) ; titre de sous-écran Sora 700 **17** ; titre auth Sora 700 **24/32** ; Sora 700 **19** (Nouvelle vidéo, détail) ; Sora 800 **44** (pourcentage d'upload), **30** (montant), **28** (montant de retrait) ; Sora 800 **20/22/17/16** (valeurs de stat) ; 10.5, 11, 12, 12.5, 13.5, 14.5, 15 (boutons). Ajouter des styles `screenTitle` (22), `appBarTitle` (17), `authTitle` (24/32), `amountXl` (30/44), `buttonLabel` (Sora 700 15), `fieldLabel` (11/500), `sectionLabel` (10.5, letter-spacing .08em), `numberDisplay`.
- Interlignes : la maquette fixe des hauteurs en px (18, 19, 25, 29, 32, 38) ; Flutter utilise des multiples (1.3, 1.4). Écarts de 1-2 px par texte.
- `font-mono` : `ui-monospace, Menlo, monospace` ; `AppFonts.mono = 'monospace'` OK.
- Chargement des polices : `google_fonts` à l'exécution (réseau requis au premier affichage) ; `fontFamily: 'Sora'` brut ne fonctionne pas (voir transverse 1). `AppTheme.dark` ne définit pas `fontFamily` global ni `SnackBarTheme`, `BottomSheetTheme`, `DialogTheme`, `InputDecorationTheme`, `SwitchTheme`, `ChipTheme`, `ElevatedButtonTheme`.

### Ombres (`--shadow-*`)
- `shadow-card: 0 12px 30px rgba(0,0,0,.5)` (toast) et `shadow-fab: 0 8px 20px rgba(196,24,63,.45)` : **aucun token** ; le FAB de `gn_bottom_nav.dart:100-106` code la valeur en dur ; le toast n'existe pas. `shadow-phone` n'a pas lieu d'être sur mobile.

### Animations (readme : « transitions 150-200ms linéaires »)
`fadeUp .35s` à l'entrée de chaque écran, `pulse` (cercle de traitement, point « Actualisation automatique »), anneau 0.7 s, barre .4/.5 s, switch .18 s. Flutter : switch 160 ms ✓ ; aucune entrée `fadeUp`, ni `pulse`, ni animation d'anneau/barre.

---------------------------------------------------------------------

## 4. Composants : maquette vs `lib/shared/widgets/design_system/`

| Composant maquette | Flutter | Écart |
|---|---|---|
| **Button** (`Button.jsx` : primary / secondary / ghost / danger ; sm 40/12.5/14, md 52/15/18, lg 54/15/22 ; rayon 12 ; Sora 700) | `GnButton` (`gn_button.dart`) | Tailles et rayon ✓. [BUG] police Sora non résolue (l.67). Pas d'état pressed/hover (`accent600` #D98A0E ignoré). Désactivé : `surface3` + `text3` ✓ (maquette ajoute `opacity:.7`). Variante `danger` : bordure `0x59` ≈ .35 ✓ (maquette écran = .3 ou .35). Manquent : variante **danger plein** (« Supprimer » #FF5A5F texte #1A0712), **primaire h48** (retirer / recharger, h42 / h44 / h40 sur d'autres CTA), **pill translucide or** (« Nouvelle vidéo », h34) et **bouton translucide blanc** (« Retirer mes gains » dans la carte solde, h40 rayon 10) ; `OutlinedButton` ad hoc dans le code à la place (`creator_dashboard_screen.dart:289`, `videos_screen.dart:227`). Pas de variante lien/texte (« Annuler », « Tout voir », « Tout retirer » = `TextButton` Material). La description du composant dit « pill-radius CTA » (`Button.prompt.md`) alors que le code et les écrans sont à rayon 12 : la doc est fausse. |
| **TextField** (`TextField.jsx` : boîte surface-1, bordure 1 (danger si erreur), rayon 12, padding 11/14, libellé 10.5 text-3 au-dessus de la valeur 14, erreur 11.5 sous la boîte à 8 px) | `GnTextField` (`gn_text_field.dart`) | Même fond, bordure, rayon, padding. Libellé flottant Material (au-dessus mais sur le trait, `floatingLabelBehavior.always`) au lieu d'un libellé intérieur ; texte de placeholder 14 text-3 ✓. Pas de variante : champ téléphone avec préfixe « +224 » + séparateur (h50), champ mot de passe avec action « Afficher/Masquer » (le `suffixIcon` est un `TextButton`), champ montant Sora 800 30 + « GNF ». Pas d'état « rempli / validé » (bordure #5C1330 dans l'upload). Erreur : Material affiche l'erreur dans l'`InputDecoration` (`errorText`) avec l'espace réservé, au lieu d'une ligne séparée à 8 px. |
| **ToggleSwitch** (`ToggleSwitch.jsx` : md 46×26 bouton 20 / sm 44×25 bouton 19 ; on = brand-600, off = border-1 ; 0.18 s) | `GnContentSwitch` (dans `creator_content_widgets.dart:80`, hors du design system) | [DESIGN] couleur active or (`accent500`) au lieu de `brand600`. Pas de variante `sm`. Non exporté par `gn_design_system.dart`. Loading : fond `surface3`. |
| **StatusPill** (`StatusPill.jsx` : success / warning / danger / info / neutral / brand ; padding 2.5/8 ; point 5 ; 10/600 ; letter-spacing .02em) | `GnStatusPill` (`gn_status_pill.dart`) | Couleurs ✓ (brand : `0x38A8123B` = .22 ✓). Pas de `letterSpacing: .02em`. Pas de variante « badge de compteur » (min-width 20, h20, fond or, texte #1A0712 11/700 : `_NavRow` code le sien) ni « CET APPAREIL » (sans point, 9.5/700, padding 2/6). |
| **Card** (`Card.jsx` : surface-1, bordure 1, rayon 16, padding 14) | `GnCard` (`gn_card.dart`) | Équivalent. Les rayons 13/14/18 sont passés en dur par les écrans (voir tokens). Variantes absentes : carte héro dégradée (bordée #C4183F), carte info (bandeau bleu avec barre) / avertissement (jaune) / erreur (rouge) en tant que composants `GnBanner`. |
| **StatTile** (`StatTile.jsx` : padding 14, icône 26×26 rayon 8 fond brand 18 %, valeur Sora 800 22 à 10 px, légende 11.5 à 4 px) | `GnStatTile` (`gn_stat_tile.dart`) | Même structure. Bug mineur : l'icône est enveloppée d'un `IconTheme` accent500 puis les écrans passent `GnLineIcon` avec leur propre couleur brand500, donc l'`IconTheme` est ignoré. Taille d'icône 16 (le dashboard passe 15). Seule la variante 2×2 : les tuiles à 3 colonnes (rayon 13, padding 11, valeur 16-17 px, légende 10 px) sont reconstruites par `GnMetricTile` dans `creator_content_widgets.dart:129` (hors design system). |
| **BottomNav** (`BottomNav.jsx` : hauteur 86, `padding:11px 8px 0`, fond rgba(11,11,13,.92) + `backdrop-filter: blur(14px)`, bordure haute surface-1, icônes **22 px** trait 1.8, libellé 9.5/600, FAB 48 px, `margin-top:-16`, ombre fab) | `GnBottomNav` (`gn_bottom_nav.dart`) | Hauteur 86 ✓, couleurs ✓, FAB 48 + translate −16 ✓ + ombre ✓. [DESIGN] icônes **20 px** (l.119-125) au lieu de 22 ; icône FAB 24 au lieu de 22 trait 2 ; pas de flou d'arrière-plan (pas de `BackdropFilter`) ; padding horizontal 8 absent ; `SafeArea` ajoute l'inset système sous les 86 px (la maquette inclut déjà la zone d'indicateur dans les 86) ; dégradé FAB `cta` (brand-600→or, horizontal) au lieu de 140° #C4183F→#F5A623 ; zone tactile via `InkWell` plein-hauteur avec ondulation Material (la maquette n'a pas d'effet). |
| **GnLineIcon** | présent | 12 icônes (voir transverse 2). Les tracés SVG de la maquette (24×24, viewBox) existent sous forme de chemins dans `GNPlay Createur.dc.html` (`I.home`, `I.video`, `I.wallet`, `I.user`, `I.plus`, `I.eye`, `I.users`, `I.coins`, `I.down`, `I.up`, `I.check`, `I.refresh`, `I.alert`, `I.search`, `I.heart`, `I.download`, `I.share`, `I.pause`, `I.play`) : à porter dans `GnLineIcon` (ou `flutter_svg`). |
| **GnAppBackground** | présent | OK (voir transverse 9). |

**Composants de la maquette sans équivalent dans le design system Flutter** (reconstruits écran par écran ou absents) :
1. En-tête d'écran avec retour (`GnScreenHeader` + `GnBackButton`).
2. Barre de progression d'étapes (3 px) : dupliquée dans `register_screen.dart:612` et `publish_screen.dart:229`.
3. Progress bar / jauge dégradée (`GnProgressBar`, hors DS), anneau de complétion (`GnCompletionRing`, hors DS).
4. Onglets segmentés (« Vidéos / Séries », « Achetées / En cours / Gratuites ») : conteneur #111116 bordé, h36, rayon 9, actif brand-600 avec compteur : **absent**.
5. Chips de filtre / chip actif fermable (pill, 12/600, brand-600 + #C4183F quand actif) : `ChoiceChip` / `ActionChip` Material (`videos_screen.dart:377,420`).
6. Bouton filtre carré 44 px avec point d'activité.
7. Barre de recherche (`GnSearchField`).
8. Bandeau d'information / avertissement / erreur (4 variantes dupliquées en ligne : `publish_screen.dart:459`, `payout_request_screen.dart:259`, `devices_screen.dart:89`, `videos_screen.dart:558`).
9. Ligne de liste « label + valeur » dans une carte (tableau de retrait, métriques) : trois implémentations privées (`_Row`, `_TableLine`, `_NavRow`).
10. Ligne de transaction (icône 34 px colorée + libellé/date + montant).
11. Toast, bottom sheet de confirmation, pavé numérique, cases OTP (privée à `register_screen.dart`), tuile-opérateur, carte de vidéo (privée à `videos_screen.dart`), miniature rayée (`GnVideoThumbnail`, hors DS), état vide (3 versions : `videos_screen`, `devices_screen`, `notifications_screen`).
12. Avatar à initiales (dupliqué : `creator_dashboard_screen.dart:98`, `profile_screen.dart:289`).

---------------------------------------------------------------------

## 5. Liste priorisée de ce qu'il faut faire

P0 = bug visible ou texte/comportement manifestement différent de la maquette ; P1 = composant ou écart de design notable ; P2 = finition.

### Transverse / design system
- **P0** `app_theme.dart:102` + `gn_button.dart:67`, `become_creator_screen.dart:137,204`, `earnings_screen.dart:358` : remplacer `fontFamily: AppFonts.display` par `GoogleFonts.sora(...)` ou bundler Sora/Inter (`pubspec.yaml:89-102`). Vérifier à l'écran.
- **P0** `creator_content_widgets.dart:94` : couleur active du switch → `AppColors.brand600` ; déplacer `GnContentSwitch` dans le design system (`gn_toggle_switch.dart`) avec une variante `sm` (44×25) pour les listes (`videos_screen.dart:627`).
- **P0** `video_with_stats.dart:50-61` : libellés « Traitement » → « En traitement », « Brouillon » → « Masquée ». `videos_screen.dart:681-689` : chips dans l'ordre « Toutes, Publiées, En traitement, Brouillons, Échecs ».
- **P0** `payout_request.dart:26-38` : « En attente » / « En cours » → « En cours de traitement ».
- **P1** Ajouter `GnBackButton` (tracé `M19 12H5M11.5 5.5 5 12l6.5 6.5`) + `GnScreenHeader` et remplacer les 7 `_Header` et `register_screen.dart:629-674`.
- **P1** Étendre `GnLineIcon` (search, filter, close, check, coins, phone, refresh, alert, play, pause, arrowLeft, settings) et supprimer les `Icons.*` listés (transverse 2).
- **P1** Ajouter un widget `GnToast` (point vert, surface3, rayon 14, ombre card) + `SnackBarTheme` ; remplacer les 18 `SnackBar`.
- **P1** Ajouter `GnConfirmSheet` (bottom sheet 22 px) et remplacer `AlertDialog` (`video_detail_screen.dart:141`, `settings_screen.dart:138`).
- **P1** Ajouter dans `AppColors` : `surfaceNeutral` #22222A, `thumbStripeA` #241019, `thumbStripeB` #1A0C12, `fgMuted` #8B8B95 ; dans `AppRadii` : 8, 10, 11, 13, 14, 18, 22 ; dans `AppGradients` : `avatar`, `brand` à stops 0 / .5 / 1.3 (via `GradientTransform` ou en réalignant sur 100 %), `ctaFab` (140°) ; ombres `shadowCard` / `shadowFab` ; styles typo (`screenTitle` 22, `appBarTitle` 17, `authTitle` 24, `buttonLabel`).
- **P1** `GnBottomNav` (`gn_bottom_nav.dart:119-125`) : icônes 22 px, FAB icône 22 trait 2, `BackdropFilter(blur 14)`, dégradé FAB 140° #C4183F→#F5A623, padding horizontal 8, ne pas ajouter l'inset système sous les 86 px (ou le compter dans les 86).
- **P1** `GnButton` : ajouter variantes `dangerFilled`, `pillGold` (h34), `glass` (h40, rayon 10), tailles h48 ; état pressed `accent600`.
- **P1** `GnTextField` : variantes `prefix` (+224), `amount`, trailing-text ; libellé intérieur plutôt que flottant.
- **P2** Fusionner les deux placeholders de miniatures (`creator_content_widgets.dart:359`, `creator_dashboard_screen.dart:535`) avec les couleurs #241019 / #1A0C12 à 115°.
- **P2** Composants à promouvoir dans le DS : `GnMetricTile`, `GnProgressBar`, `GnCompletionRing`, `GnVideoThumbnail`, `GnBanner`, `GnSegmentedTabs`, `GnFilterChip`, `GnSearchField`, `GnTransactionTile`, `GnEmptyState`, `GnAvatar`.
- **P2** Animations : `fadeUp` .35 s sur les écrans, `pulse` (traitement), anneau et barres animés.
- **P2** Marge basse : 100 (écrans avec nav) / 40 (sans nav) au lieu de 116.

### 01 Connexion — `login_screen.dart`
- P0 : libellé « Afficher » (l.134) au lieu de « Voir » ; message d'erreur 401 « Numéro de téléphone ou mot de passe incorrect » (l.55-59).
- P1 : champ téléphone avec préfixe « +224 » + séparateur et h50 (l.100-112) ; logo blanc (`gnplay_logo.dart:11`) à largeur 150 ; texte « Connexion… » dans le bouton (l.153-157).
- P2 : `Mot de passe oublié ?` sans padding Material (l.159-175) ; taille « Afficher » 11 px.

### 02 Inscription — `register_screen.dart`
- P0 : compte à rebours réel (l.385-390 : '00:45' figé) ; bloquer « Renvoyer » pendant le délai.
- P1 : chevron SVG pour Pays (l.583-586) ; champ pays sélecteur.
- P2 : bouton « Voir » sur le mot de passe (l.296-302) ; revue de l'alignement des libellés.

### 03 Devenir créateur — `become_creator_screen.dart`
- P0 : toast « Vous êtes créateur. Publiez votre première vidéo ! » (l.67-69).
- P1 : police Sora du titre (l.137).
- P2 : dégradé 45 %/100 % (l.111), rayures alpha .035 (l.245).

### 04 Tableau de bord — `creator_dashboard_screen.dart`
- P1 : tuiles sans `childAspectRatio` fixe (l.332) ; icône « pièces » pour « Revenu du mois » (l.362) ; `take(3)` (l.53).
- P2 : cloche = point or 8 px sans compteur (l.165-191), ou valider le compteur avec le design ; `letterSpacing .04em` (l.233) ; cercle pointillé −30 (l.218-219) ; couleur des rayures miniature (l.541-593) ; padding bas 100.

### 05 Mon contenu — `videos_screen.dart`
- P0 : « Nouvelle vidéo » (l.246) ; « N vidéos » (l.444) ; bandeau « Le transfert a échoué à 62 %. » ou formulation validée (l.575) ; pied de carte seulement si publiée/masquée avec « Publiée » / « Masquée » (l.605-637).
- P1 : chips custom (fond brand600, bordure brand500, sans coche, l.377-393) ; bouton filtre actif fond brand 20 % + bordure #C4183F + icône blanche (l.311-330) ; retirer le chevron de la carte (l.542-549) ; icônes `search` / `tune` / `close` en `GnLineIcon` ; onglet segmenté avec compteur (ou compteur sous le titre).
- P2 : interligne du titre (l.504) ; état vide.

### 07 Détail vidéo — `video_detail_screen.dart`
- P0 : tuiles « Vues », « Spectateurs uniques », « Vues complétées », « Likes », « Achats », « Revenu net » (l.853-871) ; supprimer la tuile « Durée » ; ligne méta conditionnelle (l.812) ; « Publiée » / « Masquée » dans la carte de publication (l.938) ; modale de suppression conforme (l.138-168).
- P1 : « Voir les statistiques détaillées » = ligne à chevron (l.332-341) ; bouton « Modifier » en variante contour 10 px (l.822-831) ; bouton retour rond maison (l.966-992) ; `GnContentSwitch` brand ; valeur compacte du revenu (« 1,84 M ») dans les tuiles ; feuille d'édition alignée sur le style bottom sheet (l.994-1106).
- P2 : bouton de lecture central discret ; barre de progression 3 px or ; `childAspectRatio` (l.851).

### 08 Statistiques — `video_stats_screen.dart`
- P0 : libellés du tableau (l.188-195) = « Vues totales », « Spectateurs uniques », « Vues complétées », « Likes », « Nombre d'achats », « Revenu net (part créateur) ».
- P1 : sélecteur de vidéo cliquable avec « Changer ⌄ » (l.155-179) ; trait de l'anneau ≈ 15.6 px (`creator_content_widgets.dart:423,428`, rayon ≈ 73.7).
- P2 : retour `GnBackButton` ; padding bas 40 ; animation de l'anneau.

### 09 Nouvel upload — `publish_screen.dart`
- P0 : noms d'étapes « Sélection / Informations / Envoi / Traitement » (l.619-626) ; « % » après le pourcentage (l.514-520) ; lien « Annuler l'envoi » rouge (après l.537) ; bouton final « Terminer » (l.610) ; zone de dépôt en tirets (l.282) ; tuile « Gratuite / Prix = 0 » (l.430-449) au lieu d'un switch.
- P1 : « Titre * » avec étoile rouge (l.409) ; prix formaté « 15 000 GNF » ; ligne fichier « N Mo · durée » (format français, l.360) ; barre jaune pleine à l'étape 4 (l.592-596 + `creator_content_widgets.dart:205`) ; icône lecture pleine or ; toast « Vidéo prête et publiée » puis navigation vers le détail (l.111).
- P2 : animation pulse (l.558-574) ; barre info stretch (l.467-474).

### 10 Portefeuille — `earnings_screen.dart`
- P0 : montants « +126 000 » / « −500 000 » sans « GNF » avec U+2212 (l.355) ; couleur « retrait » #C4183F sur fond brand 18 % (l.374-377).
- P1 : libellés de carte en blanc .75/.6 sur la carte dégradée (l.254-257,280-283) ; boutons h48 (l.103-114) ; bouton « i » rond (l.207-218).
- P2 : flux « Recharger » : décider entre feuille (`topup_sheet.dart`) et écran dédié selon la maquette spectateur 27 ; remplacer `ActionChip` (l.586) par la grille de 6 montants 3×2 et ajouter « Solde actuel » / « Nouveau solde ».

### 11 Demande de retrait — `payout_request_screen.dart`
- P0 : pavé numérique 3×4 (remplacer le clavier système, l.154-170) ; montant formaté « 250 000 » ; tuiles d'opérateur avec délai (« instantané », « ~5 min ») (l.236-250, 351-388) ; libellés de bouton « Montant trop faible » / « Solde insuffisant » (l.277-283).
- P1 : bouton h54 (`GnButtonSize.lg`) ; « Minimum : 10 000 GNF » sans afficher 0 (l.188) ; état de chargement des opérateurs en tuiles.

### 12 Suivi du retrait — `payout_detail_screen.dart`
- P0 : statuts (voir P0 global) ; dates « 20 juin, 09:41 » (l.607-613) ; ligne « Montant recrédité au portefeuille » dans le tableau (l.596-602).
- P1 : montant Sora 800 28 (l.543) ; icônes de statut SVG ; erreur avec « Réessayer ».
- P2 : pulsation du point.

### 13 Profil — `profile_screen.dart`
- P0 : badge « 2/3 » sur « Appareils connectés » (l.200-203) ; « Statistiques de la chaîne » → écran Statistiques (l.218) ; `formatGrouped` pour les abonnés / vidéos (l.149,175).
- P1 : dégradé d'avatar 2 couleurs (l.295) ; libellé « Identifiant public » (l.467) ; déconnexion h48 (l.224).
- P2 : chevrons SVG ; bouton d'édition cohérent avec le design.

### 14 Appareils connectés — `devices_screen.dart`
- P0 : état d'erreur (l.34, 107-139).
- P1 : pastille « CET APPAREIL » sans point 9.5/700 (l.258-261) ; icône téléphone SVG ; format « il y a 2 jours » / « il y a 3 semaines » (l.316-331).

### 15 Notifications — `notifications_screen.dart`
- P0 : « Tout marquer comme lu » toujours visible (l.58) ; état erreur (l.34-35).
- P1 : cercle en tirets + icône cloche à trait + titre Sora 600 15 (l.244-262) ; ligne de notification selon le design spectateur 28 (tuile-icône, point or à droite).

### 16 Réglages — `settings_screen.dart`
- P0 : switch « Mode sombre » (l.18, 89-105) : afficher l'état et le toast stylé sans point final.
- P1 : libellé de section 10.5 / .08em (l.226-229) ; confirmation « tous les appareils » en bottom sheet (l.136-165) ; marge basse 40.

### Hors maquette
- `forgot_password_screen.dart` : aligner sur login/register (bouton retour, titre 24/32, cases OTP) ; `full_video_player_screen.dart` : s'inspirer du lecteur 23 ; `splash_screen.dart` : logo blanc.
