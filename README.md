# DamballahRetro GameInfo for OBS

Overlay HTML automatique pour **RetroBat + OBS**.

Le programme détecte automatiquement le jeu rétro actuellement lancé par RetroBat,
récupère ses informations et génère un overlay HTML utilisable comme source
Navigateur dans OBS.

> **Projet personnel / communautaire — DamballahRetro**

## ✨ Fonctionnalités

- 🎮 Détection automatique du jeu lancé dans RetroBat
- 🖼️ Affichage de la jaquette lorsqu'elle est disponible
- 🏷️ Nom du jeu
- 💿 Système / plateforme
- 📅 Année
- 🎯 Genre
- 👨‍💻 Développeur
- 🏢 Éditeur
- 📝 Description du jeu
- 📜 Description défilante
- ⏱️ Délai configurable avant l'apparition de l'overlay
- 👁️ Durée d'affichage configurable
- 🔁 Intervalle configurable entre deux affichages
- 📐 Overlay horizontal avec mise en page responsive
- 🌑 Ombre de l'overlay activable ou désactivable depuis `config.ini`
- ⚙️ Paramétrage centralisé dans un fichier `.ini`
- 🔄 Détection périodique du jeu en cours

## 🖥️ Principe

Le fonctionnement est volontairement simple :

```text
RetroBat
   │
   │ jeu lancé
   ▼
GameInfo.ps1
   │
   ├── détecte le processus / chemin de la ROM
   ├── récupère les informations du jeu
   └── génère l'overlay HTML
            │
            ▼
       overlay.html
            │
            ▼
           OBS
      Source Navigateur
```

Lorsqu'aucun jeu n'est détecté, l'overlay ne présente pas d'informations de jeu.

## 📁 Installation

### 1. Copier les fichiers

Copiez les fichiers du projet dans un dossier, par exemple :

```text
C:\RetroBat\system\gameinfo_obs\
```

Le dossier peut être différent, mais le chemin utilisé doit rester cohérent
avec votre installation RetroBat.

### 2. Configurer `config.ini`

Ouvrez `config.ini` avec un éditeur de texte et adaptez les paramètres.

Configuration actuellement utilisée comme exemple :

```ini
RomsPath=C:\RetroBat\roms
Title=DAMBALLAHRETRO

Width=720
Height=250

ScrollSpeed=8
TriggerDelaySeconds=3

VisibleSeconds=30
HiddenSeconds=600

PollSeconds=1

Shadow=false
```

### 3. Lancer le programme

Lancez le fichier `.bat` fourni avec le projet.

Le programme commence alors à rechercher automatiquement le jeu lancé
dans RetroBat.

### 4. Ajouter l'overlay dans OBS

Dans OBS :

1. Ajoutez une **Source navigateur**.
2. Utilisez l'adresse locale de l'overlay indiquée par le programme.
3. Donnez à la source les mêmes dimensions que celles définies dans `config.ini`.
4. Positionnez l'overlay dans votre scène.

Une fois configuré, vous pouvez laisser OBS et RetroBat ouverts pendant vos sessions.

---

# ⚙️ Configuration de `config.ini`

## `RomsPath`

Chemin du dossier `roms` de RetroBat.

Exemple :

```ini
RomsPath=C:\RetroBat\roms
```

## `Title`

Nom affiché dans l'en-tête de l'overlay.

Exemple :

```ini
Title=DAMBALLAHRETRO
```

## `Width` et `Height`

Dimensions de l'overlay horizontal.

Exemples :

```ini
Width=720
Height=250
```

```ini
Width=500
Height=175
```

```ini
Width=320
Height=125
```

Le CSS responsive adapte la composition aux différentes tailles.

### Recommandations

| Taille | Utilisation |
|---|---|
| `720×250` | Taille standard |
| `500×175` | Taille intermédiaire |
| `320×125` | Format compact |

## `ScrollSpeed`

Contrôle la vitesse de défilement de la description.

Exemple :

```ini
ScrollSpeed=8
```

Plus la valeur est élevée, plus le défilement est rapide.

## `TriggerDelaySeconds`

Nombre de secondes à attendre après la détection du lancement du jeu
avant d'afficher ses informations.

Exemple :

```ini
TriggerDelaySeconds=3
```

## `VisibleSeconds`

Durée pendant laquelle l'overlay reste visible.

Exemple :

```ini
VisibleSeconds=30
```

## `HiddenSeconds`

Temps d'attente avant une nouvelle apparition.

Exemple :

```ini
HiddenSeconds=600
```

`600` secondes correspondent à **10 minutes**.

## `PollSeconds`

Fréquence à laquelle le programme vérifie l'état de RetroBat.

Exemple :

```ini
PollSeconds=1
```

## `Shadow`

Permet d'activer ou désactiver l'ombre du cadre principal.

Désactivée :

```ini
Shadow=false
```

Activée :

```ini
Shadow=true
```

> L'ombre de la jaquette est indépendante de ce paramètre.

---

# 🎨 Responsive

L'overlay est conçu pour conserver une présentation cohérente lorsque ses
dimensions changent.

À petite taille, plusieurs éléments sont automatiquement réduits :

- taille de la jaquette ;
- taille du titre ;
- taille des informations secondaires ;
- taille de la description ;
- espacements internes.

La description reste dans sa zone d'affichage et continue de défiler.

---

# 📝 Description défilante

La description est affichée dans une zone limitée afin d'éviter qu'elle ne
déborde du cadre.

La vitesse peut être ajustée avec :

```ini
ScrollSpeed=8
```

Si vous souhaitez un défilement plus lent, réduisez la valeur.

Si vous souhaitez un défilement plus rapide, augmentez-la.

---

# 🔧 Fichiers du projet

```text
GameInfo.bat
GameInfo.ps1
config.ini
overlay.html
README.md
```

### `GameInfo.bat`

Point d'entrée simple pour lancer le programme.

### `GameInfo.ps1`

Moteur principal :

- lecture de la configuration ;
- détection du jeu ;
- récupération des informations ;
- génération de l'overlay ;
- gestion du serveur local ;
- logique d'affichage.

### `config.ini`

Tous les paramètres facilement modifiables.

### `overlay.html`

Page HTML utilisée par OBS.

Elle est générée / mise à jour automatiquement par le programme.

---

# 💡 Utilisation avec RetroBat

Le projet est pensé pour une installation RetroBat utilisant une arborescence
de ROMs classique.

Par défaut, l'exemple fourni utilise :

```text
C:\RetroBat\roms
```

Si RetroBat est installé ailleurs, modifiez simplement :

```ini
RomsPath=...
```

---

# 🐛 Dépannage

### L'overlay est vide

Vérifiez d'abord que :

1. RetroBat est lancé ;
2. un jeu est réellement lancé ;
3. `RomsPath` correspond à votre dossier `roms` ;
4. `GameInfo.bat` est toujours en fonctionnement ;
5. la source Navigateur OBS utilise bien l'overlay local.

### Le jeu apparaît dans la fenêtre CMD mais pas dans OBS

Vérifiez la source Navigateur dans OBS et son URL locale.

Vous pouvez également ouvrir cette même URL dans un navigateur pour
diagnostiquer séparément le fonctionnement de l'overlay et celui d'OBS.

### Le texte dépasse

Vérifiez les dimensions `Width` / `Height` et utilisez une taille prévue
pour votre scène.

Les trois profils de départ sont :

```text
720×250
500×175
320×125
```

---

# 📌 Conseils

Pour modifier l'apparence graphique, le fichier principal à examiner est :

```text
GameInfo.ps1
```

Le CSS de l'overlay est intégré au modèle HTML généré par le script.

Pour modifier les paramètres de fonctionnement sans toucher au code,
utilisez plutôt :

```text
config.ini
```

---

# 📄 Licence

Ce dépôt est destiné à être partagé comme projet personnel / communautaire.

Ajoutez ou remplacez cette section par la licence de votre choix avant une
publication définitive si vous souhaitez imposer des conditions précises de
réutilisation.

---

## 👾 DamballahRetro

Projet créé pour accompagner les streams et contenus **DamballahRetro** autour
du retrogaming.

Si vous utilisez ce projet et que vous l'améliorez, n'hésitez pas à partager
vos améliorations !
