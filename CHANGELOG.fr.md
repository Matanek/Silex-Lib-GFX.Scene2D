# Changelog

## [Unreleased]

- Correction de la densité du texte coverage : le zoom de la caméra, l’échelle et le redimensionnement du Canvas sont pris en compte pour éviter d’agrandir des glyphes rastérisés trop petits.

- Ajout de TilePatch pour les surfaces de neuf tuiles ; révisions de contenu distinctes entre cartes et copies. Cache CPU des instances visibles, invalidé par le contenu, la plage visible ou les dimensions de l’atlas, avec tests GPU de défilement et d’éditions.
