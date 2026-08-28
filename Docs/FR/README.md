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
    ..with(Components.Canvas(drawing, 320, 180)..color = Color.cyan_400())
)
```

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

Les placements qui partagent une même valeur Canvas partagent aussi leur
géométrie en cache et sont rendus comme instances. Le renderer interne les
déduplique également quand des Canvas distincts décrivent une géométrie
équivalente. Couleur, couche, pivot et taille restent propres à chaque entité.

`Canvas.replace(...)` met à jour un dessin progressivement. La géométrie mutable
réutilise une allocation GPU bornée et chaque commande de texte conserve une
identité de cache indépendante. Modifier un libellé ne rastérise et ne
transfère donc que celui-ci.

Les identités de textures de sprites et de textes sont indexées directement ;
la préparation d’une frame reste linéaire selon les dessins visibles. Les
benchmarks [UpdatingTextLayers2D](https://github.com/Matanek/Silex-Benchmarks/blob/main/Sources/UpdatingTextLayers2D.sx)
et [Boids2D](https://github.com/Matanek/Silex-Benchmarks/tree/main/Sources/Boids2D)
gardent respectivement les parcours texte et géométrie/ECS.

## Étendre le renderer

`Scene2D.Plugin` installe ses dépendances ECS, assets et rendu puis enregistre
sa passe dans le frame graph public de `GFX.Rendering.Renderer`. Un renderer
alternatif lit `snapshot()` et `revision()` sur le composant de placement au
lieu de dépendre du cache GPU interne.

Les shaders `Drawing.hlsl`, `Grid.hlsl` et `Sprite.hlsl` appartiennent à ce
package. Ils ne constituent pas une API obligatoire ; une extension peut lire
les données publiques de scène et fournir son propre `GPU.ShaderProgram.hlsl`.

La démonstration visuelle [AnalogClock](https://github.com/Matanek/Silex-Examples/blob/main/Sources/AnalogClock.sx)
appartient à Silex-Examples.
