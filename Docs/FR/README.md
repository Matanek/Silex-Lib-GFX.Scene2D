# Construire une scène retenue avec GFX.Scene2D

`GFX.Scene2D` possède les données qu’un utilisateur ou renderer alternatif doit
nommer pour décrire une scène 2D : `Transform`, `Camera`, `Canvas`, `Sprite`,
`Grid` et `Sampling`. Le domaine portant déjà la dimension, ses déclarations
restent sans suffixe.

[Read this documentation in English.](../EN/README.md)

## Installer le package

```text
silex install GFX.Scene2D
```

GFX.Scene2D demande Silex 0.39.0 ou une version plus récente.

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
la préparation d’une frame reste linéaire selon les dessins visibles. Les
benchmarks [UpdatingTextLayers2D](https://github.com/Matanek/Silex-Benchmarks/blob/main/Sources/UpdatingTextLayers2D.sx)
et [Boids2D](https://github.com/Matanek/Silex-Benchmarks/tree/main/Sources/Boids2D)
gardent respectivement les parcours texte et géométrie/ECS.

## Étendre le renderer

`Scene2D.Plugin` installe ses dépendances ECS, assets et rendu puis enregistre
sa passe dans le frame graph public de `GFX.Rendering.Renderer`. Un renderer
alternatif peut lire `snapshot()` et `revision()` sur le composant de placement.
Le renderer intégré suit le chemin incrémental `Canvas.Prepared` sans
matérialiser ce snapshot complet à chaque frame.

Avec `GFX.Application.Scenes`, installez `Scene2D.Plugin()` sur l’Application
pour conserver la fenêtre, le GPU, les assets, le renderer et ses caches durant
les transitions. Ajoutez ensuite `Scene2D.Content()` à chaque scène qui porte
des composants 2D : ses systèmes consultent le `World` local sans reconstruire
les géométries Canvas inchangées.

```sx
application
    ..add_plugin(Scene2D.Plugin())
    ..add_plugin(Application.Scenes(scene))

scene.add_plugin(Scene2D.Content())
```

Placez `Application.Scenes` après les Plugins de capacités globales afin que la
scène active soit finalisée avant leur arrêt. Une scène qui ajoute
`Scene2D.Content()` sans que `Scene2D.Plugin()` soit installé est refusée avant
son montage avec un diagnostic explicite.

Les shaders `Drawing.hlsl`, `Grid.hlsl` et `Sprite.hlsl` appartiennent à ce
package. Ils ne constituent pas une API obligatoire ; une extension peut lire
les données publiques de scène et fournir son propre `GPU.ShaderProgram.hlsl`.

La démonstration visuelle [AnalogClock](https://github.com/Matanek/Silex-Examples/blob/main/Sources/AnalogClock.sx)
appartient à Silex-Examples.
