# Aventure R36S - Le secret des 4 octets

## Contexte
- Console R36S (V12 2023-08-18 2445) affichait des bandes verticales.
- La carte SD était mal enfoncée, puis correctement insérée.
- Problème logiciel : le pilote Linux 4.4.189 ne lisait pas le bon timing.

## Découverte
- Le fichier `rk3326-r36s-panel3-linux.dtb` contenait deux tables de timings : `/original` (46/2/44) et `/adjust` (150/4/150).
- Le DTB avait `native-mode` pointant sur `/original` (offset 0x9C3C, valeur 159) au lieu de `/adjust` (offset 0x9C3C, valeur 269).
- Le pointeur de 4 octets (`native-mode`) déterminait quel jeu de timings était utilisé.

## Correction
1. Extraction du DTB original.
2. Modification du champ `native-mode` de 159 à 269.
3. Re‑écriture du fichier `rk3326-r36s-panel3-adjust.dtb`.
4. Mise à jour de `boot.ini` pour charger `rk3326-r36s-panel3-adjust.dtb`.
5. Re‑installation du menu `CHOISIR-PANEL.bat` avec la bonne configuration.

## Résultat
- L’écran s’affiche correctement (60 Hz, pas de bandes).
- Tous les DTB sont vérifiés par MD5, sauvegardés, et le menu fonctionne.
- Le problème montre qu’un seul entier de 4 bytes peut bloquer tout un système.

## Leçons
- Toujours vérifier les tables de timing et le pointeur `native-mode`.
- Ne jamais formater la carte sans preuve de panne.
- Un repo git permet de retracer chaque étape et de partager la solution.