<!-- Guía del método — vive con el método, no se copia a los proyectos. -->
<!-- method-version: 4.0 -->

# BRAIN.md — El cerebro persistente (vault de Obsidian)

## Qué es

Un único vault de Obsidian, **personal**, que es el hogar de **todo** el
estado del método para **todos** los proyectos: contexto vivo, planes,
sesiones, decisiones y patrones. El repo de cada proyecto queda solo con la
documentación simple de equipo. El vault es markdown puro: el agente lee y
escribe con herramientas de archivos, sin plugins ni MCP (Dataview/Bases son
opcionales, para consultas del humano).

> El grafo ES el cerebro: cada nota enlaza con [[wikilinks]] a las notas que
> la explican. Una decisión enlaza al hub de su proyecto y al patrón que
> aplicó; un patrón enlaza a las decisiones donde nació.

## Estructura

```
<vault>/
  00-index/                 # MOCs: mapas de contenido por tema (+ home.md)
  projects/<project>/
    hub.md                  # qué es, estado macro, ruta del repo local
    CONTEXT.md              # estado vivo (ver CONTEXT.template.md)
    plans/                  # planes aprobados de tareas grandes
    sessions/               # historia cerrada: YYYY-MM-DD.md
    decisions/              # decisiones de diseño del proyecto
    graph/                  # grafo de código generado (AST, ver plan v3)
    review-checklist.md     # reglas destiladas de comentarios reales de MR
                            #   (v4: la escribe /learn review, la lee /gate)
    metrics/                # telemetría (v4, ver METRICS.md): events.jsonl
                            #   (timestamps de hooks) + metrics.jsonl (1 línea
                            #   por tarea cerrada) — archivos de datos, no notas
  patterns/                 # recetas/patrones nacidos de proyectos
  learning/                 # estudio: conceptos, recursos, TILs (ver abajo)
    <topic>/                # conceptos y recursos del tema
    til/                    # aprendizajes sueltos: YYYY-MM-DD-<slug>.md
  briefs/                   # task briefs que valió la pena guardar
```

## Frontmatter estándar

Toda nota del vault abre con:

```yaml
---
type: hub | context | plan | session | decision | pattern | brief |
      concept | resource | til | moc | checklist
project: <project>           # omitir en patterns y learning transversales
date: YYYY-MM-DD
status: active | current | resolved | archived   # según el tipo
tags: []
---
```

`type` + `project` + `date` habilitan las búsquedas por grep del agente y las
consultas Dataview/Bases del humano sin abrir cada nota.

## Convenciones de nombres

- kebab-case; fecha ISO al frente cuando el orden importa.
- Decisiones: `decisions/<YYYY-MM-DD>-<topic>.md`
- Sesiones: `sessions/<YYYY-MM-DD>.md`
- Patrones: `patterns/<topic>.md` (sin fecha en el nombre: se actualizan)

## Plantillas de notas

### Hub — `projects/<project>/hub.md` (una por proyecto)

```markdown
---
type: hub
project: <project>
date: <YYYY-MM-DD>
status: active
---
# <project>
- **Qué es:** <1-2 líneas>
- **Repo local:** `<ruta absoluta>`
- **Stack:** <1 línea>

## Estado macro
<2-3 líneas; se actualiza al cerrar hitos — el detalle vive en [[CONTEXT]]>

## Decisiones clave
- [[<YYYY-MM-DD>-<topic>]] — <1 línea>

## Patrones que usa
- [[<pattern>]]
```

### Decisión — `decisions/<YYYY-MM-DD>-<topic>.md`

```markdown
---
type: decision
project: <project>
date: <YYYY-MM-DD>
status: current
---
# <la decisión en una línea>
**Contexto:** <qué problema había>
**Decisión:** <qué se decidió>
**Porqué:** <alternativas descartadas y motivo>

Relacionado: [[hub]] · [[<pattern>]]
```

### Patrón — `patterns/<topic>.md`

```markdown
---
type: pattern
date: <YYYY-MM-DD>
tags: []
---
# <pattern>
**Cuándo aplica:** <...>
**Receta:** <pasos o ejemplo mínimo>
**Origen:** [[<decisión o sesión donde nació>]]
```

### Sesión — `sessions/<YYYY-MM-DD>.md`

```markdown
---
type: session
project: <project>
date: <YYYY-MM-DD>
---
# Sesión <YYYY-MM-DD>
**Qué se hizo:** <bullets>
**Verificación:** <comandos corridos + resultado>
**Se decidió:** [[<decisión>]] <si hubo>
**Quedó pendiente:** <...>
```

## Capa de aprendizaje (`learning/`)

El cerebro no es solo de proyectos: también almacena lo que se estudia. Tres
tipos de nota, capturados con el comando `/learn` (o a mano):

- **concept** — idea durable explicada en tus palabras. Atómica: una idea
  por nota. `learning/<topic>/<slug>.md`
- **resource** — curso/libro/artículo con estado de avance
  (`status: in-progress | done | dropped`). `learning/<topic>/<slug>.md`
- **til** — un dato puntual del día ("today I learned"), captura rápida sin
  pretensión de permanencia. `learning/til/<YYYY-MM-DD>-<slug>.md`

### Concepto — `learning/<topic>/<slug>.md`

```markdown
---
type: concept
date: <YYYY-MM-DD>
tags: []
---
# <concept>
<explicación en tus palabras, 3-10 líneas — una sola idea>

Relacionado: [[<MOC del tema>]] · [[<otro concepto o patrón>]]
Fuente: [[<resource>]] <o URL>
```

### Recurso — `learning/<topic>/<slug>.md`

```markdown
---
type: resource
date: <YYYY-MM-DD>
status: in-progress
tags: []
---
# <curso / libro / artículo>
- **Qué es:** <1 línea + URL>
- **Por qué lo estudio:** <1 línea>

## Notas que salieron de acá
- [[<concept>]] — <1 línea>

## Pendiente
- <...>
```

### TIL — `learning/til/<YYYY-MM-DD>-<slug>.md`

```markdown
---
type: til
date: <YYYY-MM-DD>
tags: []
---
# TIL: <lo aprendido en una línea>
<detalle mínimo + ejemplo si aplica>

Relacionado: [[<...>]]
```

### Regla de MOC

Los MOCs (`00-index/<topic>.md`, `type: moc`) son puntos de entrada por tema,
no índices exhaustivos. **Regla: al tercer wikilink hacia un tema que no
tiene MOC, se crea el MOC** y las notas existentes se linkean desde ahí. Un
TIL que con el tiempo demuestra ser durable se promueve a concept (y el TIL
original queda con un wikilink a la nota nueva).

## Cómo lo usa el método

### Al abrir sesión (`/start`)
El padre lee `projects/<project>/CONTEXT.md` (+ el plan en curso si hay).
Para contexto histórico largo consulta `hub.md` y sigue los wikilinks — no
escarba archivos viejos.

### Al cerrar tarea (extiende la regla de cierre)
Además de actualizar CONTEXT.md:
- Decisión no-obvia tomada → nota en `decisions/` + link en el hub.
- Aprendizaje reutilizable en otros proyectos → nota en `patterns/`.
- El hub se actualiza al cerrar **hitos**, no en cada tarea.

### Archivado
Al completar una fase, o cuando CONTEXT.md supera ~150 líneas: la historia
cerrada baja a una nota de `sessions/` y CONTEXT.md queda solo con lo vivo
(estado actual, próxima sesión, todo list, decisiones vigentes, preguntas
abiertas).

## Memoria nativa de Claude Code vs. el vault (v4)

Claude Code trae su propia memoria persistente por proyecto (un directorio
`memory/` de archivos de hechos más un índice `MEMORY.md`). El método es
anterior y **no** migra a ella — un solo cerebro, no dos:

- **El vault es la fuente de verdad del estado y el conocimiento**: contexto,
  planes, decisiones, sesiones, patrones, aprendizaje, métricas. Todo lo que
  `/start` lee y `/close` escribe vive acá, navegable en Obsidian.
- **La memoria nativa es solo para micro-preferencias**: hechos chicos sobre
  cómo te gusta que trabaje el agente (tono, manías de formato) que no
  necesitan grafo, ni historia, ni navegación humana. Nada de lo que `/close`
  persistiría pertenece ahí.
- Si un hecho aparece en ambos, gana el vault; borrá la copia nativa.

## Seguridad

El vault no se versiona en los repos, pero suele sincronizarse (Obsidian
Sync, iCloud, git privado). Ahí **tampoco** van valores de secretos, tokens
ni credenciales: nombres de variables y dónde obtenerlas, nunca los valores.
