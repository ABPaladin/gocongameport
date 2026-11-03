# Arhitectură recomandată — Godot 4 (port RPG Maker MV)

Structură pentru un RPG 2D top-down cu hărți, dialoguri, cutscene-uri și meniuri.
Tu te ocupi manual de asset-uri, mapare și coliziuni; documentul ăsta îți dă
scheletul de foldere + noduri + autoload-uri pe care le umplem împreună, sistem
cu sistem.

> Proiectul existent din `godot_project/` respectă deja o variantă din structura
> asta (îl poți folosi ca referință sau îl poți ignora complet).

---

## 1. Structura de foldere (`res://`)

```
res://
├── assets/                 # (le pui TU manual)
│   ├── characters/         # spritesheets personaje (48x48/frame în MV)
│   ├── faces/              # portrete 144x144
│   ├── parallax/           # !ground<id>, !par<id> (arta hărților)
│   ├── tilesets/           # doar dacă folosești tile-uri reale pt coliziune
│   ├── ui/                 # rame casete, butoane, iconițe
│   └── audio/
│       ├── bgm/            # .ogg (Godot nu importă .m4a/AAC)
│       └── se/
├── data/                   # JSON (baze de date, hărți, traduceri)
├── autoload/               # singletons (vezi §3)
├── actors/
│   └── player/             # Player.tscn + player.gd
├── world/
│   ├── Map.tscn            # o hartă (parallax + coliziuni + evenimente)
│   └── map.gd
├── events/
│   ├── Event.tscn          # un eveniment de pe hartă
│   └── event_runner.gd     # interpretorul de comenzi (dialog/cutscene/logică)
├── ui/
│   ├── dialogue/           # DialogueBox.tscn + dialogue_box.gd
│   ├── menu/               # MainMenu, PauseMenu
│   └── inventory/          # InventoryPanel
└── systems/                # helpere reutilizabile (timere, tween-uri, math)
```

**Convenții:** fișiere `snake_case.gd`, clase `PascalCase` (`class_name`), scene
`PascalCase.tscn`. Un script = o responsabilitate.

---

## 2. Fluxul general

```
Main (entry point)
 ├── autoload-uri (mereu în viață: GameData, GameState, Dialogue, SceneManager, Audio)
 └── harta curentă  ──(transfer)──►  altă hartă
```

`Main` cere `SceneManager` să încarce harta de start; fiecare hartă își instanțiază
Player-ul + evenimentele; interacțiunile pornesc `EventRunner`, care poate chema
`DialogueManager`, poate schimba `GameState`, sau poate cere `SceneManager` un
transfer.

---

## 3. Autoload-uri (Singletons)

Le adaugi în `Project Settings → Autoload`. Ordinea contează (dependențele întâi).

| Autoload | Rol | Persistă în save? |
|---|---|---|
| `GameData` | citește JSON-urile din `data/` (actori, iteme, hărți, traduceri) o singură dată; **read-only** | nu (e conținut static) |
| `GameState` | stare mutabilă: switches, variables, self-switches, party, inventar, gold, limbă, poziția playerului | **da** |
| `DialogueManager` | primește o coadă de mesaje, afișează `DialogueBox`, gestionează typewriter + alegeri | nu |
| `SceneManager` | schimbă hărțile (fade in/out), ține minte harta curentă | parțial (harta curentă) |
| `AudioManager` | redă BGM (loop) + SE, cu volum din 0–100 → dB | nu |

**De ce singletons:** dialogul, starea și tranzițiile de hartă trebuie accesibile
din orice eveniment/scenă, fără să le pasezi prin noduri.

---

## 4. Node tree pe scene

### Harta (`world/Map.tscn`)
```
Map (Node2D)
├── Ground (Sprite2D)                 # !ground<id>, centered=false, z_index=-10
├── Entities (Node2D, y_sort_enabled = true)
│   ├── Event, Event, …               # personaje/obiecte interactive
│   └── Player (instanță)
├── Foreground (Sprite2D)             # !par<id>, z_index=100 (deasupra playerului)
├── Collisions (Node2D)               # TU: StaticBody2D-uri / TileMapLayer de coliziune
└── (BGM: îl pornește map.gd prin AudioManager)
```
- `y_sort_enabled` pe `Entities` = personajele din spate se desenează în spate.
- Camera: `Camera2D` copil al Player-ului, `zoom = (2,2)`, cu `limit_*` pe
  marginile hărții.

### Player (`actors/player/Player.tscn`)
```
Player (CharacterBody2D)              # mișcare liberă  ▸ SAU ▸  Node2D (grid-based)
├── Sprite (AnimatedSprite2D)         # animații idle/walk × 4 direcții
├── CollisionShape2D                  # doar la mișcare liberă
└── Interact (Area2D)                 # zona din fața playerului pt „vorbește”
```

### Caseta de dialog (`ui/dialogue/DialogueBox.tscn`)
```
DialogueBox (CanvasLayer)             # deasupra hărții, neafectat de zoom
└── Root (Control, anchor bottom-wide)
    └── Panel (PanelContainer)
        └── HBox
            ├── Portrait (TextureRect)        # opțional
            └── VBox
                ├── NameLabel (Label)
                └── Text (RichTextLabel)      # typewriter: visible_ratio 0→1
```

### Meniu / Inventar (`ui/menu/`, `ui/inventory/`)
```
PauseMenu (CanvasLayer)
└── Control
    ├── PartyStatus (VBox: HP/MP/nivel din GameState)
    └── ItemList (din GameState.inventory + GameData.items)
```

---

## 5. Formatul datelor (dacă folosești JSON extern)

- **Baze de date** (`data/actors.json`, `items.json`…): dicționar cheiat pe id
  string: `{ "1": {...}, "2": {...} }`.
- **Traduceri**: cheia = textul-sursă (engleză), valoarea = `{"Romanian": "...",
  "Russian": "..."}`. La afișare: `text_tradus = msg.get(text, {}).get(limbă, text)`.
- **Dialoguri**: fie array direct în scenă, fie fișiere `data/dialogues/*.json` de
  forma `[{ "speaker": "...", "portrait": "actor1", "text": "..." }, ...]`.

---

## 6. Ordinea de implementare (pas cu pas)

1. **Player movement** (grid-based sau liber pe 8 direcții, idle/walk).
2. **Sistemul de dialog** (array/JSON, portret, typewriter, avans cu tastă).
3. **UI** (meniu principal, casete text stil RPG, inventar de bază).
4. **Evenimente / cutscene** (interpretor de comenzi: mișcare NPC, așteptări,
   set switch/variabile, condiții).
5. Extra: save/load, tranziții de hartă, schimbare de limbă.

Fiecare pas: cod comentat + explicația structurii de noduri, un sistem o dată.
```
