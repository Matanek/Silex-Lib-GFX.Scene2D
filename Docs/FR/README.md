# Construire une scène retenue avec GFX.Scene2D

`GFX.Scene2D` possède les données qu’un utilisateur ou renderer alternatif doit
nommer pour décrire une scène 2D : `Transform`, `Camera`, `Canvas`, `Sprite`,
`TileAtlas`, `TileMap`, `Grid` et `Sampling`. Le domaine portant déjà la
dimension, ses déclarations
restent sans suffixe.

[Read this documentation in English.](../EN/README.md)

## Installer le package

```text
silex install GFX.Scene2D
```

GFX.Scene2D demande Silex 0.43.0 ou une version plus récente.

## Placer du contenu Canvas

`Components.Canvas` place un dessin retenu de `GFX.Canvas` avec un
`Components.Transform2D`. Ce fragment suppose un `world:ECS.World` existant :

```sx
use GFX.Canvas
use GFX.Color
use GFX.Components
use GFX.ECS
use STD.Math

var drawing = Canvas()
world.spawn(ECS.EntityRecipe()
    ..with(Components.Transform2D(position:Math.Vec2(40.0, 20.0)))
    ..with(Components.Canvas(drawing)..color = Color.cyan_400())
)
```

Cette forme ne définit aucun cadre : le point `(0, 0)` du dessin coïncide avec
la position du `Transform2D`, et la géométrie peut s’étendre dans toutes les
directions. `size` et le pivot normalisé appartiennent au mode cadré et ne
modifient pas ce placement local.

La forme `Components.Canvas(drawing, width, height)` conserve le comportement
historique lorsqu’un rectangle de référence est utile pour redimensionner,
pivoter ou découper le texte.

Les coordonnées monde sont utilisées par défaut avec une caméra centrée créée
par Scene2D si l’application n’en fournit aucune. Un `Components.Camera2D`
explicite remplace cette caméra pour déplacer, zoomer ou choisir le point de
vue.

Le monde Scene2D suit la convention spatiale de Scene3D : X pointe vers la
droite et Y vers le haut. Le contenu `GFX.Canvas` conserve ses coordonnées de
dessin naturelles, origine en haut à gauche et Y vers le bas ; Scene2D l’oriente
automatiquement. `Camera.project()` retourne les mêmes coordonnées viewport
adaptées au pointeur et aux API de fenêtre.

## Dessiner un champ de tuiles retenu

`Components.TileMap2D` représente toute une grille par un seul composant. Son
`TileAtlas` décrit une image régulière, sans marge ni espacement ; les indices
avancent de gauche à droite puis du haut vers le bas. Les lignes de la grille,
elles, avancent vers le haut dans le monde Scene2D : l’origine locale de la
cellule `(0, 0)` est `(0, 0)`.

```sx
use GFX.Assets.Image
use GFX.Components
use GFX.ECS
use GFX.Scene2D

let sheet = images.add(Image())
let atlas = Scene2D.TileAtlas(sheet, 16, 16)
var field = Components.TileMap2D(atlas, 256, 256)
field.set(4, 7, 3)
field.clear(4, 7)

world.spawn(ECS.EntityRecipe()
    ..with(Components.Transform2D())
    ..with(field)
)
```

Une cellule vide ne produit aucune instance. À chaque frame, le renderer
convertit les quatre coins du viewport dans l’espace local de la carte, ajoute
une cellule de garde, puis ne parcourt que ce rectangle. Une carte immense ne
crée donc ni entité ECS par cellule, ni travail de préparation proportionnel à
sa surface totale. Les cellules visibles partagent un buffer GPU instancié et
un draw par carte ; un contenu et une caméra inchangés ne retransfèrent pas ce
buffer. `color`, `layer`, `depth`, `visible` et `sampling(...)` règlent le
placement comme pour un sprite. Le mode d’échantillonnage initial est
`Sampling.pixelated`.

`coordinate_at(point)` convertit un point local en `TileCoordinate?`, tandis
que `cell_origin(column, row)` retourne l’origine locale d’une cellule. Une
coordonnée hors grille renvoie `null` pour le hit-test et provoque une erreur
explicite pour `tile`, `set`, `clear` ou `cell_origin`.

## Placer une interface dans le viewport

Le même composant emploie les coordonnées logiques de fenêtre avec
`Components.CanvasSpace.viewport`. Son `anchor` choisit un point du viewport,
tandis que `Transform2D.position` reste le décalage modifiable par l’animation :

```sx
world.spawn(ECS.EntityRecipe()
    ..with(Components.Transform2D())
    ..with(Components.Canvas(drawing, 320, 180)
        ..space = Components.CanvasSpace.viewport
        ..anchor = Math.Vec2(0.5)
        ..pivot = Math.Vec2(0.5)
    )
)
```

`Components.Canvas` est l’unique composant de placement vectoriel retenu. Son
`space` sélectionne le monde ou le viewport ; `Transform2D` porte position,
rotation et échelle dans les deux cas.

## Choisir le rendu du texte

Le texte Canvas conserve par défaut `CanvasTextMode.coverage`. Ce chemin
rastérise avec hinting chaque glyphe façonné par `GFX.Font` lors de son premier
emploi, le range dans un atlas R8 GPU, puis dessine les occurrences visibles
comme quads instanciés. Un scroll froid ne recompose donc plus une texture RGBA
par ligne. Il convient aux petites tailles, aux terminaux et aux interfaces
denses. `coverage_density` multiplie la densité physique de la fenêtre et doit
rester strictement positif :

```sx
var label = Components.Canvas(drawing, 320, 80)
label.text_mode = Scene2D.CanvasTextMode.coverage
label.coverage_density = 2.0
```

`CanvasTextMode.vector` consomme les `GlyphRun` et contours du même
`TextLayer`. Il échoue explicitement si un glyphe visible ne possède pas de
contour ; il ne retire jamais silencieusement ce glyphe. `automatic` choisit le
vectoriel lorsque tous les glyphes non vides sont vectorisables et revient à
la couverture fidèle dans les autres cas. Ce choix ne dépend pas d'un seuil de
zoom caché : demander une couverture hintée reste explicite et déterministe.

```sx
world.spawn(ECS.EntityRecipe()
    ..with(Components.Transform2D())
    ..with(Components.Canvas(drawing, 320, 80)
        ..text_mode = Scene2D.CanvasTextMode.vector
    )
)
```

Le chemin vectoriel applique la règle de remplissage non-zero à tous les
contours d'un glyphe ; les contreformes de `O` ou `B` restent donc ouvertes.
Les meshes normalisés sont partagés entre tailles, couleurs et placements.
Trois classes de détail stables couvrent le petit texte, le dessin courant et
le fort agrandissement ; rester dans une classe ne retesselle pas. Une couleur,
translation, rotation ou échelle ne modifie que l'instance GPU.

## Comprendre la rétention et les caches

Le composant conserve l'identité du `GFX.Canvas.Canvas` reçu. Si le producteur
appelle ensuite `clear()`, `paint(...)` ou une autre opération qui modifie ce
dessin, Scene2D observe sa nouvelle révision avant le rendu suivant. Il n'est
donc pas nécessaire d'appeler `world.update(...)` ni `replace(...)` pour animer
les commandes d'une même instance Canvas.

Les placements qui partagent cette instance partagent aussi leur géométrie en
cache et sont rendus comme instances. Le renderer interne déduplique également
les géométries équivalentes de Canvas distincts. Couleur et couche restent
propres à chaque entité ; pivot et taille s'appliquent aux placements cadrés.
Un placement qui demeure statique conserve le `Snapshot` déjà mémorisé par son
dessin : créer plusieurs milliers de placements depuis la même instance ne
vectorise donc le contenu qu'une fois. La paire de meshes `Canvas.Prepared`
n'est créée qu'au premier changement observé sur ce placement.

`Canvas.replace(...)` change la source du composant lorsque l'application veut
fournir une autre instance Canvas. Après cette première mutation, la géométrie
est préparée dans deux meshes CPU retenus, réutilise une allocation GPU bornée
et chaque commande de texte conserve une identité de cache indépendante. Une
frame animée réécrit ainsi les valeurs du mesh sans reconstruire ses capacités.
Modifier uniquement un libellé ne transfère ni la géométrie, ni les autres
couches de texte.

Les identités de textures de sprites et de textes sont indexées directement ;
la préparation d’une frame reste linéaire selon les dessins visibles. Le cache
vectoriel garde au plus 2 048 meshes de glyphes et 256 couches préparées. Après
warm-up, un texte vectoriel statique ne refaçonne, ne décompose, ne tesselle,
ne rastérise et n'upload plus de pixels ; le chemin coverage conserve ses
glyphes hintés dans au plus quatre pages d'atlas 2 048 × 2 048 en R8 (16 Mio
alloués au maximum), avec une table directe bornée. Le clipping est appliqué
aux quads dans l'espace local du Canvas ; une couverture qui ne tient pas dans
l'atlas revient au chemin de texture de couche. Un découpage rectangulaire
attaché à une commande texte Canvas retaille chaque quad visible de l'atlas et
sa région UV dans l'espace local du Canvas. Un texte découpé emploie le chemin
coverage même si le composant demande par ailleurs les contours vectoriels :
le bord reste exact sans reconstruire les meshes de glyphes ni allouer une
texture hors écran pendant le scroll. Les
benchmarks [UpdatingTextLayers2D](https://github.com/Matanek/Silex-Benchmarks/blob/main/Sources/UpdatingTextLayers2D.sx)
et [Boids2D](https://github.com/Matanek/Silex-Benchmarks/tree/main/Sources/Boids2D)
gardent respectivement les parcours texte et géométrie/ECS.

## Étendre le renderer

`Plugins.Scene2D` installe ses dépendances ECS, assets et rendu puis enregistre
sa passe dans le frame graph public de `GFX.Rendering.Renderer`. Un renderer
alternatif peut lire `snapshot()` et `revision()` sur le composant de placement.
Le renderer intégré suit le chemin incrémental `Canvas.Prepared` sans
matérialiser ce snapshot complet à chaque frame.

Avec `Plugins.BundleManager`, installez `Plugins.Scene2D()` sur l’Application
pour conserver la fenêtre, le GPU, les assets, le renderer et ses caches durant
les transitions. `Scene2D` étend automatiquement les Bundles avec le même
Plugin : leurs systèmes consultent leur `World` local sans type `Content`
supplémentaire et sans reconstruire les géométries Canvas inchangées.

```sx
use GFX.Plugins

application
    ..add_plugin(Plugins.Scene2D())
    ..add_plugin(Plugins.BundleManager(bundle))
```

Un Bundle autonome peut aussi installer `Plugins.Scene2D()` directement ; il
possède alors sa fenêtre et sa pile de rendu si elles ne viennent pas du parent.

Les shaders `Drawing.hlsl`, `Grid.hlsl` et `Sprite.hlsl` appartiennent à ce
package. Ils ne constituent pas une API obligatoire ; une extension peut lire
les données publiques de scène et fournir son propre `GPU.ShaderProgram.hlsl`.

La démonstration visuelle [AnalogClock](https://github.com/Matanek/Silex-Examples/blob/main/Sources/AnalogClock.sx)
appartient à Silex-Examples.
