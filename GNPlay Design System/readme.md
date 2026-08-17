# GNPlay Design System

GNPlay est une plateforme mobile guinéenne de vidéo à la demande : des créateurs publient des vidéos et mini-séries payantes ou gratuites, les spectateurs les découvrent, les achètent (solde interne ou mobile money) et les regardent. Ce design system est extrait du prototype cliquable "GNPlay Créateur" (29 écrans : parcours créateur + parcours spectateur), qui reste la source de vérité visuelle — pas de Figma ni de codebase attachés à ce projet.

Sources : `GNPlay Createur.dc.html` (prototype complet, 29 écrans) et `GNPlay Createur-print.dc.html` (export PDF) à la racine du projet.

## Contenu

- `styles.css` — point d'entrée, importe les tokens.
- `tokens/` — couleurs, typographie, espacement/rayons/ombres.
- `components/` — primitives React : `forms/` (Button, TextField, ToggleSwitch), `feedback/` (StatusPill), `surfaces/` (Card, StatTile), `navigation/` (BottomNav).
- `guidelines/` — cartes de fondations (couleurs, type, espacement, ombres, dégradés, logo).
- `assets/logo.png` — logo GNPlay (fond transparent).
- `GNPlay Createur.dc.html` — le prototype complet ; sert de UI kit de référence (29 écrans, créateur + spectateur).

## Fondamentaux de contenu

- Français, vouvoiement systématique ("Connectez-vous à votre espace créateur").
- Ton direct et factuel, jamais enjoué ou marketing ; pas d'émoji.
- Montants toujours en GNF, espace fine comme séparateur de milliers ("4 820 000 GNF").
- Micro-copie honnête sur les limites : "Le solde retirable ne compte que vos gains de ventes.", "Cette action est définitive."
- Labels d'action courts et verbaux : "Retirer mes gains", "Devenir créateur", "Continuer".

## Fondations visuelles

- **Couleurs** : fond quasi noir (#0B0B0D) avec un dégradé bordeaux radial en haut ; bordeaux (#2A0E1F→#C4183F) pour le contenu/la marque, or (#F5A623/#FFCB6B) réservé à l'argent et aux actions principales. Jamais plus de 2 couleurs d'accent à l'écran.
- **Typographie** : Sora (700/800) pour titres, montants, KPI ; Inter (400–600) pour le corps et les labels ; monospace pour les placeholders techniques ("miniature — URL de l'image").
- **Espacement** : grille 4px ; rayons 9–20px selon la taille (boutons/champs 12px, cartes 16px, hero 18-20px), pilule pour les badges/switches.
- **Cartes** : fond `surface-1` (#16161A), bordure 1px `border-1` (#2C2C33), pas d'ombre portée sauf modales/FAB.
- **Dégradés** : diagonaux (135–140°), toujours bordeaux→bordeaux ou bordeaux→or (jamais bleu/violet). Réservés aux héros, soldes, CTA de gamme.
- **États** : hover = surface légèrement plus claire ou bordure qui passe au bordeaux ; pas d'effet de scale au clic ; transitions 150–200ms linéaires, pas de rebond.
- **Icônes** : SVG traits (1.7–2px), géométrie 24×24, jamais de remplissage plein sauf lecture/FAB. Pas d'émoji, pas de police d'icônes.
- **Layout mobile** : conçu pour 390×844 (iPhone), barre de navigation basse à 5 onglets avec FAB central surélevé pour l'action de publication.

## Iconographie

Aucune bibliothèque d'icônes externe : tous les pictos sont des `<svg>` inline dessinés à la main dans le prototype (trait 1.7–2px, viewBox 24×24, `stroke-linecap="round"`). Aucune police d'icônes, aucun sprite, aucun émoji. En reprenant ce système ailleurs, dessinez de nouvelles icônes dans la même géométrie plutôt que d'importer une lib différente (Lucide/Heroicons casseraient la cohérence de trait).

## Index

- `readme.md` — ce fichier.
- `tokens/colors.css`, `tokens/typography.css`, `tokens/spacing.css`
- `components/forms/` — Button, TextField, ToggleSwitch
- `components/feedback/` — StatusPill
- `components/surfaces/` — Card, StatTile
- `components/navigation/` — BottomNav
- `guidelines/` — 13 cartes de fondations (Colors, Type, Spacing, Brand)
- `GNPlay Createur.dc.html` — prototype de référence, 29 écrans
- `SKILL.md` — skill portable pour Claude Code

## Limites connues

- Pas de logo distinct pour un mode clair : le système est conçu sombre uniquement (le prototype le confirme).
- Aucune police propriétaire trouvée : Sora + Inter via Google Fonts, à confirmer avec l'équipe brand si une police maison existe.
