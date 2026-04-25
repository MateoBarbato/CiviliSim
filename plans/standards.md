# CiviliSim - Standards & Decision Log

## Stack Tecnológico

| Componente | Elección | Versión |
|------------|----------|---------|
| Motor | Godot | 4.x |
| Lenguaje principal | GDScript | 4.x |
| Performance crítica | C# | .NET 8 |
| Arte | Pixel art 2D | - |
| Control de versión | Git | - |

## Decisiones Arquitectónicas

### GDScript vs C#

| Componente | Lenguaje | Razón |
|------------|----------|-------|
| Behavior Tree Engine | C# | Performance, muchos agentes evaluando árboles |
| Pathfinding | C# | Cálculos intensivos en grid |
| Game Simulator | C# | Loop de simulación global |
| UI / HUD | GDScript | Interacción nativa con Godot nodes |
| Colony Manager | GDScript | Lógica de juego, no performance crítica |
| Beep Agent Controller | GDScript | Bridge entre GDScript y C# |
| Resource Manager | GDScript | Operaciones simples de datos |
| Data/Config | GDScript | Datos estáticos, no requieren performance |

### Arquitectura en Capas

```
┌─────────────────────────────────────────────┐
│              UI Layer (GDScript)            │
│  HUD, Decisiones, Indicadores              │
├─────────────────────────────────────────────┤
│           System Layer (GDScript)           │
│  Colony, Resources, Spawn, Reproduction     │
├─────────────────────────────────────────────┤
│         Agent Layer (GDScript + C#)         │
│  Beep Controller + Behavior Tree Bridge     │
├─────────────────────────────────────────────┤
│        Core Engine (C#)                    │
│  Behavior Trees, Pathfinding, Simulator     │
├─────────────────────────────────────────────┤
│         Data Layer (GDScript)              │
│  Config, ResourceTypes, BuildingTypes       │
└─────────────────────────────────────────────┘
```

## Convenciones de Programación

### GDScript

#### Nomenclatura
```
# Archivos y clases
PascalCase.gd         → ColonyManager, ResourceManager
                      → (Mismo nombre que la clase principal)

# Variables
snake_case            → hunger_threshold, max_population
_underscore_prefijo   → _internal_value (private en convención)

# Constantes
UPPER_SNAKE_CASE      → MAX_HUNGER, SPAWN_INTERVAL

# Señales
snake_case            → beep_spawned, resource_collected
```

#### Estilo de Código
```gdscript
# Indentación: 4 espacios (Godot default)
# Líneas máx: 100 caracteres

# Variables declaradas arriba
class_name Beeper
extends Node2D

# Constantes
const MAX_SPEED := 100.0
const HUNGER_RATE := 0.5

# Variables exportadas para inspector
@export var hunger_threshold: float = 70.0
@export_group("Movement")
@export var move_speed: float = 100.0

# Variables privadas (convención)
var _current_task: Task
var _is_active: bool = true

# Variables públicas
var health: float = 100.0
var energy: float = 100.0

# Señales
signal task_completed(task_type: String)
signal health_changed(new_value: float)

# Funciones
func _ready() -> void:
    initialize_agent()

func _process(delta: float) -> void:
    update_stats(delta)

# Helper private
func _calculate_hunger_rate() -> float:
    return HUNGER_RATE * delta

# Public API
func assign_task(task: Task) -> void:
    _current_task = task
    emit_signal("task_assigned", task)
```

#### Reglas GDScript
- ALWAYS usar type hints cuando sean claros
- ALWAYS usar `-> void` o tipo de retorno explícito
- USAR `@export` para valores configurables desde el editor
- USAR `_prefijo` para variables "privadas" (GDScript no tiene true private)
- CONSTANTES con `:=` para valores inmutables
- Separar `_ready()`, `_process()`, `_physics_process()` del resto
- NO usar `load()` en `_process()`, precargar en `_ready()` o con `preload()`
- Signals para comunicación entre componentes (no referencias directas cuando sea posible)

### C#

#### Nomenclatura
```csharp
// Archivos y clases
PascalCase.cs         → BehaviorTree.cs, Pathfinding.cs

// Properties
PascalCase            → CurrentState, MaxEnergy

// Campos privados
_pascalCase           → _nodes, _isActive

// Métodos
PascalCase            → Evaluate(), CalculatePath()

// Constantes
UPPER_SNAKE_CASE      → MAX_ITERATIONS, TICK_RATE

// Interfaces
IPascalCase           → IBehaviorNode, IUpdatable
```

#### Estilo de Código
```csharp
using Godot;
using System.Collections.Generic;

namespace CiviliSim.Core
{
    public class BehaviorTree
    {
        // Constants
        private const int MaxDepth = 20;
        private const float EvaluationInterval = 0.5f;

        // Fields
        private IBehaviorNode _root;
        private bool _isRunning;

        // Properties
        public IBehaviorNode Root
        {
            get => _root;
            set => _root = value;
        }

        public bool IsRunning => _isRunning;

        // Constructor
        public BehaviorTree(IBehaviorNode root)
        {
            _root = root;
            _isRunning = false;
        }

        // Public API
        public Status Evaluate()
        {
            if (_root == null) return Status.Failure;
            return _root.Execute();
        }

        // Internal
        private void ValidateNode(IBehaviorNode node)
        {
            if (node == null)
            {
                GD.PrintErr("Null node in behavior tree");
            }
        }
    }
}
```

#### Reglas C#
- ALWAYS envolver en `namespace CiviliSim.{Layer}`
- USAR properties en lugar de campos públicos
- USAR interfaces para abstracciones (`IBehaviorNode`, etc.)
- `private` fields con `_` prefix
- `const` para valores inmutables, `readonly` para valores calculados en constructor
- Godot's `GD.Print` para logging, NO `Console.WriteLine`
- Precompiled assemblies: compilar en debug mode durante desarrollo

## Patrones de Diseño

### Singleton Pattern (Autoload)
```
# Managers que deben ser accesibles globalmente:
- ColonyManager     (Autoload: "ColonyManager")
- ResourceManager   (Autoload: "ResourceManager")
- SpawnManager      (Autoload: "SpawnManager")
- GameConfig        (Autoload: "GameConfig")
```

### Signal-Based Communication
```
# Comunicación entre componentes:
- Managers emiten signals → UI los escucha
- Beeps emiten signals   → Managers los escucha
- NO usar get_node() / get_tree().get_root() para comunicación
```

### Component-Based (Godot Way)
```
# Cada entidad es un árbol de nodos:
Beep (CharacterBody2D)
├── Sprite2D
├── CollisionShape2D
├── AnimatedSprite2D
└── BeepStats (Node)
```

### Object Pooling
```
# Para Beeps y ResourceNodes:
- Pre-crear instancias en _ready()
- Desactivar/activar con queue_free() y reparent()
- Pool sizes configurables desde GameConfig
```

## Estructura de Carpetas

```
CiviliSim/
├── scenes/
│   ├── main/           # Escena principal
│   ├── world/          # Mundo y TileMap
│   ├── beep/           # Agente Beep
│   ├── buildings/      # Edificios
│   ├── resources/      # ResourceNodes
│   ├── ui/             # Interfaces
│   └── camera/         # Control de cámara
├── scripts/
│   ├── core/           # C# - BehaviorTree, Pathfinding, Simulator
│   ├── systems/        # GDScript - Managers
│   ├── agents/         # GDScript - Beep controller y stats
│   └── data/           # GDScript - Configs y tipos
└── assets/
    ├── tiles/          # Tilesets
    ├── sprites/        # Sprites de entidades
    ├── ui/             # Assets de interfaz
    └── fonts/          # Fuentes
```

## Reglas de Git

### Commits
```
# Formato: tipo: descripción corta

tipos:
- feat:    nueva funcionalidad
- fix:     corrección de bug
- refactor: mejora de código sin cambiar comportamiento
- docs:    documentación
- chore:   tareas de mantenimiento
- perf:    mejoras de performance

# Ejemplos:
feat: add ResourceNode scene for food, wood, stone
fix: correct hunger decay rate calculation
refactor: extract behavior tree evaluation to separate method
docs: update architecture decision for signal-based communication
```

### Branches
```
main          → Rama principal, siempre funcional
feature/*     → Nuevas funcionalidades (feature/behavior-tree)
bugfix/*      → Correcciones (bugfix/hunger-calculation)
```

## Performance Guidelines

### General
- Behavior Tree evaluado en intervalos (0.5s), NO cada frame
- Object pooling para Beeps y recursos
- Culling de agentes fuera de cámara
- `preload()` para recursos conocidos en compile-time
- Minimizar `_process()` - usar señales y timers

### Memory
- NO crear objetos en `_process()`
- Reutilizar arrays y dicts cuando sea posible
- `queue_free()` para limpiar nodos no usados

### C# Specific
- `Span<T>` para operaciones en arrays grandes
- `ObjectPool` custom para BehaviorTree nodes
- Evitar allocations en el evaluation loop

## Testing Strategy

### Durante Desarrollo
- Godot's built-in debugger para lógica de juego
- `GD.Print()` para tracing durante desarrollo
- Scenes de test aisladas para cada sistema

### Post-MVP1
- Unit tests para C# core (xUnit/NUnit)
- Integration tests para managers
- Performance benchmarks para Behavior Tree evaluation

## Decisiones Tomadas

### 2025-04-25 - ResourceNode MVP1
- **Decisión:** ResourceNode como Node2D simple con Sprite2D + CollisionShape2D + Label
- **Razón:** Suficiente para MVP1, sin necesidad de CharacterBody2D (no se mueven)
- **Comportamiento:** Regeneración lenta post-recolección, no desaparición permanente
- **Valores:** Food (80 units, +2/s), Wood (60 units, +0.5/s), Stone (40 units, +0.25/s)

### 2025-04-25 - Escenas Godot
- **Decisión:** Crear .tscn para cada entidad (ResourceNode, Beep, Building)
- **Razón:** Compatibilidad con Godot's scene system, instanciación desde SpawnManager

### 2025-04-25 - SpawnManager como Instancia
- **Decisión:** SpawnManager como hijo del World, no Autoload
- **Razón:** El spawneo está acoplado al mundo, no necesita acceso global
- **Arquitectura:** World → SpawnManager → ResourceContainer → ResourceNodes

### 2025-04-25 - Spawneo Procedural
- **30 recursos iniciales** al iniciar el juego
- **Nuevo recurso cada 30s** durante el juego
- **Pesos:** Food 40%, Wood 35%, Stone 25%
- **Señales:** ResourceNode → World → ResourceManager (cadena de señales)

### 2025-04-25 - Beep Agent Architecture
- **BeepStats como nodo hijo** del Beep, no script separado
- **Razón:** Acceso directo a stats sin referencias externas, ciclo de vida acoplado
- **Estados:** IDLE, WORKING, EATING, RESTING, MOVING, DEAD
- **BeepAgent:** CharacterBody2D con movimiento básico y detección de recursos
- **Registro automático:** Beep se registra/deregistra en ColonyManager en _ready/_death
- **2 Beeps iniciales** spawneados por SpawnManager

### 2025-04-25 - Pathfinding Integration
- **Pathfinding en C#** (A* optimizado) con wrapper GDScript
- **Razón:** Múltiples agentes calculando rutas concurrentes
- **Evaluación cada 0.5s** por Beep, no cada frame
- **Grid walkable** por defecto todo transit

### 2025-04-25 - Behavior Tree Engine (Fase 4)
- **Motor completo en C#:** BehaviorTree, BehaviorNode, Selector, Sequence, Parallel, Repeater, Action, Condition
- **BeepBehaviorBuilder:** Construye el árbol específico del Beep
- **BeepBehaviorBridge:** Node C# que conecta el motor con el BeepAgent GDScript
- **Árbol del Beep:** EmergencyEat > Rest > SeekShelter > ColonyPriority > Wander
- **Comunicación C#→GDScript:** GodotObject.Call() para invocar métodos del BeepAgent
- **Comunicación GDScript→C#:** Script attachment directo en escena

### 2025-04-25 - Reproduction System (Fase 8)
- **ReproductionSystem:** Check cada 60s, cooldown 90s entre nacimientos
- **Condiciones:** mín 4 Beeps, máx 50, requiere 30 comida, 60 energía por Beep
- **Selección:** Beeps con energía >= 60 y salud >= 50
- **Spawn:** posición entre padres con offset aleatorio
- **Herencia:** salud promedio de padres * 1.1 (mejora generacional)
- **Registro:** ColonyManager registra/deregistra automáticamente

### 2025-04-25 - Decision System (Fase 7)
- **DecisionSystem como autoload:** Gestiona eventos, timers, y efectos sobre variables globales
- **Event pool:** 9 tipos de eventos (resource_shortage, population, disaster, moral, exploration, technology)
- **Timer de respuesta:** 30 segundos por defecto, timeout aplica efectos por defecto
- **Efectos:** Modifican recursos, felicidad, salud, orden social, prioridad de colonia
- **DecisionPanel UI:** Panel flotante con descripción, barra de tiempo, y botones de opciones
- **GameUI HUD:** Panel superior izquierdo con recursos, población, prioridad, tiempo

### 2025-04-25 - Building System (Fase 5/6)
- **BuildingBase:** Clase base con construcción progresiva, ocupantes, capacidad
- **ShelterBuilding:** Refugio con curación de ocupantes
- **Construcción:** Beep consume recursos (15 madera, 5 piedra) y spawnea edificio
- **Edificios registrados** en ColonyManager para tracking global
- **Refugio:** Beeps pueden entrar, descansar y curarse (1 HP/s)

## Decisiones Pendientes

- [ ] Resolución del juego (target: 1920x1080 con pixel scaling)
- [ ] Frame rate target (target: 60 FPS)
- [ ] Sistema de guardado (target: JSON + checkpoints)
- [ ] Asset pipeline (procedural vs hand-drawn sprites)
