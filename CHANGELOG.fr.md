# Changelog

## [Unreleased]

- Ajout de `Parallax` pour les sprites et les tilemaps : facteurs X/Y, origine et répétition en coordonnées monde. Les copies visibles d’une tilemap partagent sa préparation et un seul dessin GPU ; les positions ECS restent inchangées.

- Correction des fuites de pixels entre régions d’atlas pour les sprites et les tilemaps lors des déplacements fractionnaires de caméra. Les shaders bornent la lecture à la région sélectionnée, sans réduire les UV ; une régression GPU hors écran couvre le MSAA ×4 et les deux modes d’échantillonnage.

- Correction de la densité du texte coverage : le zoom de la caméra, l’échelle et le redimensionnement du Canvas sont pris en compte pour éviter d’agrandir des glyphes rastérisés trop petits.

- Ajout de TilePatch pour les surfaces de neuf tuiles ; révisions de contenu distinctes entre cartes et copies. Cache CPU des instances visibles, invalidé par le contenu, la plage visible ou les dimensions de l’atlas, avec tests GPU de défilement et d’éditions.
