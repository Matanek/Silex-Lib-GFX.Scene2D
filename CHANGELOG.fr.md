# Changelog

## [0.4.0] - 2026-11-09

- Garder les surfaces Canvas découpées vivantes jusqu’à la fin de leur préparation ou frame englobante. La pression du cache ne reconstruit plus un enfant à travers son parent actif, ce qui pouvait étirer les en-têtes de tableau au survol. Des entrées temporaires couvrent les surfaces actives au-delà des 128 entrées conservées au repos.

- Adopte la déclaration `Result` unique : l’appel ordinaire rend la valeur
  ou arrête le programme sur erreur ; `try appel()` conserve le `Result`. Les
  anciens appels stockant un résultat et propagations deviennent explicites.
  Cette version requiert Silex 0.48.0 ou supérieur et les versions coordonnées
  de ses dépendances.

- Les uploads des instances de glyphes préservent les buffers de transfert et de dessin déjà référencés par des passes GPU. Les rangées Canvas découpées restent complètes lorsque plusieurs surfaces partagent un lot différé, y compris au survol et à la sélection.

- Composer les groupes Canvas découpés avec les surfaces GPU retenues, après leurs effets enfants. Les groupes vides sont ignorés ; les changements de limites invalident leur surface sans reconstruire les groupes inchangés.

- Les caches vectoriels distinguent les faces de chaque glyphe pour les lignes Canvas qui utilisent une police de secours.

- Correction des fonds et bordures conservant leur ancienne géométrie après redimensionnement de dessins Canvas réutilisés. Le cache suit la révision de chaque contenu ; les dessins inchangés ne provoquent pas de nouvel upload.

- Ajout de `Parallax` pour les sprites et les tilemaps : facteurs X/Y, origine et répétition en coordonnées monde. Les copies visibles d’une tilemap partagent sa préparation et un seul dessin GPU ; les positions ECS restent inchangées.

- Correction des fuites de pixels entre régions d’atlas pour les sprites et les tilemaps lors des déplacements fractionnaires de caméra. Les shaders bornent la lecture à la région sélectionnée, sans réduire les UV ; une régression GPU hors écran couvre le MSAA ×4 et les deux modes d’échantillonnage.

- Correction de la densité du texte coverage : le zoom de la caméra, l’échelle et le redimensionnement du Canvas sont pris en compte pour éviter d’agrandir des glyphes rastérisés trop petits.

- Ajout de TilePatch pour les surfaces de neuf tuiles ; révisions de contenu distinctes entre cartes et copies. Cache CPU des instances visibles, invalidé par le contenu, la plage visible ou les dimensions de l’atlas, avec tests GPU de défilement et d’éditions.
