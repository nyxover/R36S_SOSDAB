# R36S SOSDAB — Réparation écran bandes verticales

> Console **R36S V12 (2023-08-18 2445)** : écran avec bandes verticales blanches/magenta → **résolu** en modifiant 4 octets dans le DTB.

## Contexte

- Console R36S (V12 2023-08-18 2445) affichait des bandes verticales.
- Problème logiciel : le pilote Linux 4.4.189 ne lisait pas le bon timing.

## Symptômes couverts

- Bandes verticales blanches et/ou magenta/rouges.
- Écran qui change (rouge / noir avec bande centrale) mais jamais d'image correcte.
- Son fonctionnel, console démarre normalement.

**Compatible avec** : R36S V12, firmware (d)ArkOSen / AURKNIX, noyau Linux 4.4.189, DTB `rk3326-r36s-panel3-linux.dtb`.

## Cause racine

Le pilote d'affichage (Linux 4.4.189) lit la propriété **`native-mode`** du DTB pour choisir le mode d'affichage. Dans le fichier `rk3326-r36s-panel3-linux.dtb` :

| Table | Offset | Valeur native-mode | Timing |
|---|---|---|---|
| `/original` | 0x9C3C | **159** | 46/2/44 → **bandes** |
| `/adjust` | 0x9C3C | **268** | 150/4/150 → **60 Hz correct** |

Le pilote utilisait `/original` (bandes) au lieu de `/adjust` (écran correct). La bonne table existait mais n'était jamais lue.

## Correction

4 octets à modifier à l'offset **0x9C3C** dans le DTB du noyau :

```
159 (0x9F) → 268 (0x10C)    // native-mode : /original → /adjust
```

Le fichier corrigé est : `rk3326-r36s-panel3-adjust.dtb`

## Installation rapide

1. **Préparer la carte SD** (démarrage ArkOSen existant)
   - Extraire la carte du R36S
   - Brancher sur PC (la partition BOOT doit être visible, généralement en FAT32)

2. **Copier les fichiers**
   - `rk3326-r36s-panel3-adjust.dtb` → racine de la carte (partition BOOT)
   - `uboot-panel3.dtb` → racine de la carte (partition BOOT)

3. **Modifier boot.ini**
   - Chercher la ligne : `load mmc 1:1 ${dtb_loadaddr} rk3326-r36s-panel3-linux.dtb`
   - Remplacer `rk3326-r36s-panel3-linux.dtb` par `rk3326-r36s-panel3-adjust.dtb`
   - **Ne pas** laisser d'autres DTB dans la racine (éviter les conflits)

4. **Tester**
   - Éjecter la carte, réinsérer dans le R36S, démarrer
   - L'écran doit afficher une image correcte (60 Hz)

## Dépannage

| Problème | Solution |
|---|---|
| Écran noir après modification | Vérifier que `boot.ini` pointe bien vers `rk3326-r36s-panel3-adjust.dtb` et non `rk3326-r36s-panel3-linux.dtb` |
| Bandes persistentes | Essayer `rk3326-r36s-panel3-flags.dtb` (porches + dsi,flags 0xE03) |
| Carte non détectée | Réinsérer la carte SD correctement (contact), essayer un autre lecteur |
| Démarrage OK mais écran noir | Essayer `rk3326-r36s-panel3-porches.dtb` (porches seuls) |

## Contenu du dépôt

| Fichier | Description |
|---|---|
| `rk3326-r36s-panel3-adjust.dtb` | **DTB corrigé** (native-mode → /adjust) — à copier sur la carte |
| `uboot-panel3.dtb` | **DTB u-boot corrigé** — à copier sur la carte |
| `rk3326-r36s-panel3-linux.dtb` | DTB d'origine (référence) |
| `rk3326-r36s-panel1-linux.dtb` | Variante panel1 |
| `rk3326-r36s-panel2-linux.dtb` | Variante panel2 |
| `rk3326-r36s-panel4-linux.dtb` | Variante panel4 |
| `CURRENT-card.dtb` | Copie d'un DTB de carte |
| `uboot-0x800000.bin` | Binaire u-boot complet (10 MiB) |
| `boot.ini` | Fichier de démarrage d'exemple |
| `install-panel3.ps1` | Script d'installation avec détection de partition |
| `install-panel3-simple.ps1` | Script d'installation simple (sans détection automatique) |
| `verify-phandle.ps1` | Script de vérification du DTB |
| `read-panel3.ps1` | Lecture des propriétés du DTB |
| `patch-native-mode.ps1` | Script de patch manuel du DTB |
| `LIRE-MOI-DTB.txt` | Documentation détaillée en français |

## Scripts utiles

- `install-panel3.ps1` : Installation automatique avec détection de la partition BOOT
- `install-panel3-simple.ps1` : Installation manuelle (sans détection automatique)
- `verify-phandle.ps1` : Vérifie que `native-mode` pointe vers `/adjust`
- `patch-native-mode.ps1` : Modifie manuellement un DTB existant

## Vérification du DTB

Pour vérifier qu'un DTB est bien corrigé :

```powershell
.\verify-phandle.ps1 -Path .\rk3326-r36s-panel3-adjust.dtb
```

Résultat attendu :
```
=== rk3326-r36s-panel3-adjust.dtb ===
  native-mode = 268  (offset 0x9AC8)
    -> phandle 268 : /dsi@ff450000/panel@0/display-timings/adjust
```

## Leçons

- Toujours vérifier les tables de timing et le pointeur `native-mode`.
- Ne jamais formater la carte sans preuve de panne.
- Un repo git permet de retracer chaque étape et de partager la solution.

## Historique du projet

Ce dépôt documente le diagnostic complet :
- Fausse alerte de carte SD morte (mal enfoncée)
- Analyse des séquences d'init (188 commandes vs 155)
- Comparaison des timings (`/original` vs `/adjust`)
- Correction par modification de 4 octets
- Tests multiples (porches, flags, u-boot)
- Documentation complète en français

## Licence

Ce projet est fourni tel quel, sans garantie. Utilisez-le à vos risques et périls.

---

**Auteur** : [nyxover](https://github.com/nyxover)  
**Date** : Novembre 2026  
**Version** : 1.1 — R36S V12 2023-08-18 2445