# Método de trabajo con Claude Code

Guía única del método de trabajo **personal** con Claude Code. Nació de un
proyecto real y está pensado para replicarse en **cualquier proyecto**, nuevo
o existente, **sin imponerle nada al equipo** del repo.

Esta carpeta es la **fuente de verdad del método**: las guías (`README.md`,
`BRAIN.md`, `MODEL-ROUTING.md`, `MULTI-AGENT.md`) explican el *por qué*; las
plantillas (`*.template.md`) traen el *qué se instancia*.

**Versión del método: 4.1** — cada plantilla y guía lleva un comentario
`<!-- method-version: X.Y -->`. Al mejorar una pieza, subí la versión acá y
en las piezas. Para detectar copias desactualizadas:
`grep -r "method-version" <instancias>`.

**Qué agrega v4.0** (enforcement, gate, telemetría): los task briefs llevan
**criterios de aceptación** y 0–2 skills de un registro curado
(`SKILLS-REGISTRY.md`); un hook de SubagentStop (`check-brief.sh`) bloquea
reportes de subagente sin evidencia de verificación; **`/gate`** corre lentes
de review escaladas por riesgo antes de cualquier mensaje de commit
(READY/NOT-READY, máx 2 ciclos de fix); comentarios reales de MR alimentan un
`review-checklist.md` por proyecto vía `/learn review`; y cada tarea cerrada
deja una línea de métricas — duraciones, tokens por modelo, estimado vs. real
(`METRICS.md`).

---

## 1. Filosofía en una línea

> El contexto del trabajo vive en un **cerebro personal de archivos** (el
> vault de Obsidian), no en la memoria de una conversación ni en los repos
> del equipo. Cada sesión **arranca leyendo el estado** y **cierra
> actualizándolo**, de modo que cualquier sesión nueva retoma sin perder
> nada.

El método es **personal**: las decisiones y el estado del día a día no se
comparten con el equipo (cada quien trabaja con la IA a su manera). En el
repo queda solo la documentación simple de equipo; todo lo demás vive en el
vault.

## 2. Arquitectura: dos capas

### Capa global personal (se instala UNA vez)

| Pieza | Rol | Fuente |
|---|---|---|
| `~/.claude/CLAUDE.md` | Reglas siempre-activas (flaco: el cierre vive en `/close`); se carga en **todos** tus proyectos | `engine/claude/CLAUDE.md` |
| `~/.claude/commands/start.md` | `/start` — abrir sesión (usa el árbol cacheado del hub) | `engine/claude/commands/start.md` |
| `~/.claude/commands/close.md` | `/close` — cierre de tarea/sesión (solo carga tokens al invocarse) | `engine/claude/commands/close.md` |
| `~/.claude/commands/learn.md` | `/learn` — capturar estudio en `learning/` del vault | `engine/claude/commands/learn.md` |
| `~/.claude/commands/new-project.md` | `/new-project` — alta de proyecto en un paso | `engine/claude/commands/new-project.md` |
| `~/.claude/commands/kickoff.md` | `/kickoff` — prompt maestro → alta + brief + cerebro + primer plan | `engine/claude/commands/kickoff.md` |
| `~/.claude/commands/gate.md` | `/gate` — gate de pre-commit escalado por riesgo (v4): lentes de review + ciclo de fix + READY/NOT-READY | `engine/claude/commands/gate.md` |
| `~/.claude/agents/<name>.md` | Subagentes de dominio (implementer, tester). Barridos → **Explore** nativo; review → `/code-review` nativo | `MULTI-AGENT.md` |
| `~/.claude/hooks/check-close.sh` + hooks en `~/.claude/settings.json` | Enforcement del cierre (Stop / PreCompact, §6.3) | `scripts/check-close.sh` |
| `~/.claude/hooks/check-brief.sh` (SubagentStop) | Enforcement del brief (v4): bloquea reportes de subagente sin evidencia de verificación | `scripts/check-brief.sh` |
| `~/.claude/hooks/metrics-event.sh` (SessionStart / SubagentStop / Stop) | Eventos de telemetría (v4): timestamps para duraciones — nunca bloquea | `scripts/metrics-event.sh` |
| `<vault>/` (Obsidian) | **El cerebro**: contexto, planes, sesiones, decisiones, patrones y estudio (`learning/`) | `BRAIN.md` |

### Capa por proyecto (al empezar a trabajar en un repo)

| Pieza | Dónde | Rol |
|---|---|---|
| `projects/<project>/` | vault | `hub.md` + `CONTEXT.md` + `plans/` + `sessions/` + `decisions/` + `review-checklist.md` + `metrics/` (v4) |
| `CLAUDE.local.md` | raíz del repo — **gitignore global, no se versiona** | Anclaje: apunta al vault, índice de convenciones, comandos seguros |
| `.claude/settings.local.json` | repo — Claude Code lo excluye de git en automático | Enforcement personal de permisos (§5.1) |

En el repo, lo único versionado sigue siendo lo del equipo (docs de
convenciones, `CLAUDE.md` de equipo si existe). El método no toca nada de
eso.

## 3. Plantillas y guías de esta carpeta

| Pieza | Se instancia en |
|---|---|
| `engine/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` (una vez, vía `./sbm install` / `./sbm update`) |
| `engine/claude/commands/start.md` | `~/.claude/commands/start.md` (una vez, vía `./sbm install` / `./sbm update`) |
| `engine/claude/commands/close.md` | `~/.claude/commands/close.md` (una vez, vía `./sbm install` / `./sbm update`) |
| `engine/claude/commands/learn.md` | `~/.claude/commands/learn.md` (una vez, vía `./sbm install` / `./sbm update`) |
| `engine/claude/commands/new-project.md` | `~/.claude/commands/new-project.md` (una vez, vía `./sbm install` / `./sbm update`) |
| `engine/claude/commands/kickoff.md` | `~/.claude/commands/kickoff.md` (una vez, vía `./sbm install` / `./sbm update`) |
| `engine/claude/commands/gate.md` | `~/.claude/commands/gate.md` (una vez, vía `./sbm install` / `./sbm update`) |
| `REVIEW-CHECKLIST.template.md` | `<vault>/projects/<project>/review-checklist.md` (por proyecto — lo crea `/learn review` en el primer comentario de MR) |
| `PROJECT-BRIEF.template.md` | `<vault>/projects/<project>/brief.md` (por proyecto — el **prompt maestro**; lo completa el humano o `/kickoff` pregunta por pregunta) |
| `scripts/check-close.sh` | `~/.claude/hooks/check-close.sh` + registro en `~/.claude/settings.json` (una vez) |
| `scripts/check-brief.sh` | `~/.claude/hooks/check-brief.sh` + registro en SubagentStop (una vez) |
| `scripts/metrics-event.sh` | `~/.claude/hooks/metrics-event.sh` + registro en SessionStart/SubagentStop/Stop (una vez) |
| `scripts/collect-metrics.sh` | no se copia: `/close` lo corre desde acá (por tarea) |
| `scripts/brain-health.sh` | no se copia: se corre desde acá (semanal) |
| `scripts/brain-metrics.sh` | no se copia: se corre desde acá (semanal — rollup de métricas) |
| `CLAUDE-LOCAL.template.md` | `<repo>/CLAUDE.local.md` (por repo — lo genera `/new-project`) |
| `CONTEXT.template.md` | `<vault>/projects/<project>/CONTEXT.md` (por proyecto — lo genera `/new-project`) |
| `TASK-BRIEF.template.md` | no se instancia: el agente padre la completa en cada despacho de subagente |

| Guía | Qué documenta |
|---|---|
| `BRAIN.md` | El vault: estructura, frontmatter estándar, plantillas de notas (hub/decisión/patrón/sesión), reglas de uso |
| `MODEL-ROUTING.md` | Qué modelo usar según el tipo de tarea (Explorador/Implementador/Razonador) y cuándo escalar |
| `MULTI-AGENT.md` | Flujo Padre → Subagentes: roles, catálogo, ciclo, tope de ciclo, paralelismo, fork y seguridad |
| `SKILLS-REGISTRY.md` | Tabla curada de skills para despachos (v4): disparadores, reglas de curación, sin búsqueda externa |
| `METRICS.md` | Telemetría (v4): qué se captura, schema de `metrics.jsonl`, cómo leer el rollup |
| `GRAPHIFY.md` | Grafo de código AST, opcional y opt-in por repo grande: activación, consultas a 0 tokens, regla de 3 capas |

Cada plantilla trae marcadores `<...>` y comentarios `<!-- ... -->` para
completar. Reemplazá todos los `<...>` antes de dar por instalado el método.

## 4. Cómo instanciarlo

### Setup global (una sola vez)
Corré **`./sbm install [--lang en|es] [--vault PATH] [--yes]`** desde la
raíz del repo (`./install.sh <path>` sigue funcionando como alias de
compatibilidad). Instala `engine/claude/{CLAUDE.md,commands,agents,hooks}`
en `~/.claude` (sin pisar nada tuyo — lo que colisiona sale como
`<file>.new`), fusiona los hooks del método en `settings.json` sin pisar tu
configuración, crea el vault (carpetas + home + git init), y copia
`engine/method/` a `<vault>/method/`. Renderiza el marcador de la ruta
del vault embebido en `CLAUDE.md`, los commands y
`scripts/{brain-health,brain-metrics}.sh` con la ruta real del vault — no
completás nada a mano. Actualizá después con **`./sbm update`**. Configurá
el gitignore global para `CLAUDE.local.md` aparte:
`git config --global core.excludesFile ~/.gitignore_global` y agregá la
línea (el instalador imprime este recordatorio al final).

### En cada proyecto (nuevo o existente)
Un solo paso: parado en la raíz del repo, **`/new-project <name>`** — crea la
carpeta del proyecto en el vault (hub con árbol cacheado + CONTEXT.md), el
`CLAUDE.local.md` y el `.claude/settings.local.json` (§5.1), y registra el
proyecto en el home del vault. Para repos existentes, el CONTEXT.md inicial
es la foto real de partida (el barrido lo hace el subagente Explore).

Después, cada sesión se abre con `/start`.

## 5. Reglas de proceso (el corazón del método)

Viven en `~/.claude/CLAUDE.md` y aplican a todos los proyectos:

1. **Plan antes de código.** Nunca se escribe código sin mostrar el plan y
   recibir aprobación. Para tareas que modifican código se usa el **plan
   mode nativo** (§5.2): la aprobación es un gate del harness, no una
   promesa.
2. **Git siempre con aprobación.** Nunca `git add` / `commit` / `push` /
   `checkout` sin confirmación explícita.
3. **Operaciones destructivas siempre con aprobación.** Nunca `rm` / `mv`
   sobre archivos que no se crearon en la misma sesión.
4. **Permisos explícitos y aplicados por el harness.** La política se
   documenta en `CLAUDE.local.md` y se **aplica** en
   `.claude/settings.local.json` (§5.1). La prosa explica; el settings
   obliga.
5. **Branches con convención.** Feature/fix en branch propio (`feat/<topic>`,
   `fix/<topic>`), nunca directo sobre `main`/`master`. Crear el branch
   también requiere aprobación (es un comando git).
6. **Delegación con routing de modelos.** Toda tarea delegable se despacha a
   un subagente con task brief (`TASK-BRIEF.template.md`) — criterios de
   aceptación + 0–2 skills del registro — y con el modelo más barato que la
   resuelve bien (`MODEL-ROUTING.md`). El padre verifica el reporte antes de
   dar la tarea por hecha (`MULTI-AGENT.md`).
7. **Gate antes de commit (v4).** El código destinado a un commit/MR pasa
   `/gate` sobre el diff integrado: lentes de review escaladas por riesgo +
   el `review-checklist.md` del proyecto; solo READY habilita el mensaje de
   commit. Comentarios reales de MR alimentan el checklist vía
   `/learn review`.

### 5.1 Permisos: política (CLAUDE.local.md) + enforcement (settings.local.json)

Las reglas escritas en prosa dependen de que el modelo las respete. Claude
Code tiene un mecanismo real de permisos que las hace obligatorias:
`.claude/settings.local.json` en la raíz del repo — la variante **personal**
(Claude Code la excluye del control de versiones en automático, así no
tocás nada del equipo).

Ejemplo base para adaptar en cada repo:

```json
{
  "permissions": {
    "allow": [
      "Bash(make build:*)",
      "Bash(make test:*)",
      "Bash(make lint:*)",
      "Bash(npx jest:*)",
      "Bash(grep:*)",
      "Bash(find:*)",
      "Bash(cat:*)",
      "Bash(ls:*)"
    ],
    "ask": [
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git checkout:*)",
      "Bash(rm:*)",
      "Bash(mv:*)"
    ]
  }
}
```

- `allow`: corre sin preguntar (builds, tests, lint, lecturas).
- `ask`: pide confirmación **siempre**, aunque el modelo "olvide" la regla.

El `CLAUDE.local.md` documenta los comandos seguros del repo; el
settings.local.json los obliga. Mantener ambos en sincronía.

### 5.2 Plan mode nativo

Claude Code trae un plan mode integrado: mientras está activo, el modelo
puede leer y analizar pero **no puede editar nada** hasta que el humano
aprueba el plan explícitamente. La regla del método: *"para cualquier tarea
que modifique código, entrar en plan mode y presentar el plan como todo list
antes de tocar archivos"*.

### 5.3 Planes persistidos para tareas grandes

El plan aprobado vive en la conversación y muere con ella. Para tareas
grandes (varias sesiones, o más de ~5 pasos), al aprobarse se guarda en:

```
<vault>/projects/<project>/plans/<YYYY-MM-DD>-<task>.md
```

con los pasos como checklist (`[ ]` / `[x]`). El todo list de CONTEXT.md
**referencia** el plan en vez de duplicarlo. Si la sesión se corta a mitad
de ejecución, la siguiente retoma del plan persistido, no de memoria.

### 5.4 Higiene de contexto (consumo de tokens)

El contexto de la sesión es el recurso más caro del método: todo lo que se
carga de más se paga en cada mensaje. Reglas:

1. **Archivos auto-cargados flacos.** `~/.claude/CLAUDE.md` y
   `CLAUDE.local.md` se cargan completos en cada sesión → tope de **~100
   líneas** entre ambos por proyecto. El detalle largo va a docs bajo
   demanda.
2. **Lectura en dos niveles al abrir sesión:**
   - SIEMPRE: el `CONTEXT.md` del vault (+ el plan en curso si hay).
   - BAJO DEMANDA: los docs de convenciones se listan en `CLAUDE.local.md`
     como **índice con una línea de descripción**; el agente lee solo los
     relevantes a la tarea del día, y reporta cuáles va a leer y por qué.
3. **Búsquedas amplias → delegarlas.** Los barridos de código no se hacen en
   la sesión principal (contaminan el contexto con dumps); se delegan a un
   subagente de solo lectura y vuelve únicamente la conclusión. En repos con
   grafo Graphify activo (opt-in, `GRAPHIFY.md`), las preguntas
   **estructurales** ("¿quién llama a…?") van primero al grafo: responde a
   0 tokens sin barrido ni subagente.
4. **Archivos grandes → lectura por secciones**, no completos.
5. **Delegar vs. inline:** una tarea de 1-2 pasos sobre archivos ya
   conocidos → inline (delegar costaría más contexto del que ahorra); un
   barrido amplio o una tarea autocontenida que genera mucho output
   intermedio → subagente.

## 6. Regla de cierre de tarea

Al completar **cada** tarea del todo list, antes de pasar a la siguiente:

1. **Verificar antes de marcar `[x]`.** Correr el build/test/lint que
   corresponda y registrar en CONTEXT.md **qué comando corrió y con qué
   resultado**. Sin verde, la tarea queda `[~]`. Los cambios no triviales con
   superficie en runtime también se ejercitan de punta a punta (skill nativo
   `/verify`).
2. **Gate (v4).** Código destinado a un commit/MR: `/gate` sobre el diff
   integrado debe estar READY.
3. Actualizar el `CONTEXT.md` del vault: tarea `[x]`, decisiones nuevas,
   preguntas abiertas, "Estado actual" con fecha ISO `YYYY-MM-DD`.
4. **Métricas (v4).** `collect-metrics.sh` + el `type`/`estimate` del humano
   → una línea en `metrics/metrics.jsonl` (`METRICS.md`). Nunca bloquea el
   cierre.
5. **Registrar en el cerebro** lo que tenga valor transversal: decisión
   no-obvia → `decisions/` (+ link en el hub); aprendizaje reutilizable →
   `patterns/` (ver `BRAIN.md`).
6. Dejar el mensaje de commit **listo para copiar** (Conventional Commits,
   inglés, una línea, ≤ 100 chars).

No se avanza a la siguiente tarea hasta completar los 6 puntos.

La regla se ejecuta invocando **`/close`** (así el detalle no se paga en
tokens en cada mensaje: vive en el command, no en el CLAUDE.md global).

### 6.1 Cierre de sesión a mitad de tarea

Si la sesión termina con una tarea a medias (tiempo, contexto, o un
bloqueo):

1. Marcar la tarea como `[~]` en el todo list.
2. Volcar en "⭐ PRÓXIMA SESIÓN" el punto **exacto**: archivo que se estaba
   tocando, decisión pendiente, test que falla, comando que todavía hay que
   correr.
3. Registrar hallazgos parciales aunque estén sin confirmar (marcarlos).
4. Actualizar "Estado actual" con la fecha.

La prueba de fuego: una sesión nueva tiene que poder retomar sin preguntar
nada.

### 6.2 Archivado de CONTEXT.md

Cuando se completa una **fase/hito**, o el archivo supera **~150 líneas**: la
historia cerrada baja a una nota de `sessions/` del proyecto en el vault
(plantilla en `BRAIN.md`), y en CONTEXT.md quedan solo: estado actual,
"⭐ PRÓXIMA SESIÓN", todo list vivo, decisiones **vigentes** y preguntas
abiertas. Dejar el wikilink a la sesión archivada en "Historia previa".

### 6.3 Enforcement del cierre (hooks)

La regla de cierre escrita en prosa depende de que el modelo la respete; dos
hooks del harness la obligan (mismo principio que §5.1: la prosa explica, el
settings obliga). Script: `scripts/check-close.sh`, instanciado en
`~/.claude/hooks/` y registrado en `~/.claude/settings.json`:

- **Stop**: si la sesión termina en un repo con `CLAUDE.local.md` y el
  CONTEXT.md del vault no se modificó desde el inicio de la sesión, bloquea
  **una vez** y exige ejecutar `/close` (o declarar explícitamente que fue
  una sesión de solo consulta).
- **PreCompact**: ante una compactación con estado sin persistir, avisa al
  humano e instruye al modelo a volcar el estado antes de que la
  compactación (que es con pérdida) decida qué sobrevive.

En repos sin `CLAUDE.local.md` los hooks salen mudos: las sesiones casuales
no pagan nada.

v4 agrega dos piezas más aplicadas por el harness bajo el mismo principio:
**check-brief.sh** (SubagentStop) bloquea el reporte de un subagente que
carece de evidencia de verificación (MULTI-AGENT.md), y **metrics-event.sh**
(SessionStart/SubagentStop/Stop) registra timestamps de telemetría — esto
último nunca bloquea nada (METRICS.md).

## 7. El ciclo de una sesión

```
Open a session in the repo
   └─ /start
        └─ Claude reads CLAUDE.local.md → locates the project in the vault
             └─ reads CONTEXT.md (+ in-progress plan); conventions only the
                ones relevant to the task, per the index (§5.4)
                  └─ reports state + tree (cached in the hub, doesn't
                     re-explore) + next step + which docs it'll read,
                     and waits for confirmation
                       └─ plan (plan mode) → human approval
                            └─ [for each task of the plan]
                                  inline or delegate? (§5.4)
                                    ├─ inline: direct changes by the parent
                                    └─ delegate: brief → subagent (model per
                                       MODEL-ROUTING.md) → report
                                  → parent verifies (build/test green +
                                    criteria evidence) →
                                    /gate READY (code for commit/MR) →
                                    /close: updates CONTEXT.md + metrics +
                                    brain → leaves commit message
                                       └─ (git only with your OK)
```

Lo aprendido que trasciende el proyecto se captura en cualquier momento con
`/learn` (capa `learning/` del vault, ver BRAIN.md).

`~/.claude/CLAUDE.md` y `CLAUDE.local.md` no se listan en la lectura: Claude
Code los carga en automático al abrir la sesión.

## 8. Tareas que cruzan repos

Una feature puede tocar varios repos (una lib + un API, por ejemplo). El
vault lo simplifica:

- La tarea vive en **un solo** `projects/<project>/` del vault — el del repo
  principal (normalmente donde se ve el resultado). Su CONTEXT.md es el
  único dueño del estado y registra qué se toca en cada repo y por qué.
- Los `CLAUDE.local.md` de los repos secundarios no cambian: siguen
  apuntando a su propio proyecto del vault, y su hub puede linkear la tarea
  ajena.
- Nunca dos CONTEXT.md llevando el estado de la misma tarea en paralelo.

## 9. Seguridad del contenido

- El vault no se versiona en los repos, pero suele **sincronizarse**
  (Obsidian Sync, iCloud, git privado): ahí tampoco van valores de
  secretos.
- `CLAUDE.local.md` está gitignoreado pero vive dentro del repo: misma
  regla.
- En notas de entorno: **nombres** de variables y dónde obtener sus valores
  (Secrets Manager, `.env` local, a quién pedir acceso) — **nunca** valores
  de secretos, tokens ni credenciales.

## 10. Mantener este método

- Si mejorás una regla en una instancia (tu `~/.claude/CLAUDE.md`, un
  `CLAUDE.local.md`), actualizá la **plantilla** de esta carpeta, subí la
  versión (`method-version`) acá y en las piezas, y propagá a las
  instancias.
- Las guías explican el *por qué*; las plantillas traen el *qué se copia*.
  No dupliques contenido de plantillas dentro de las guías.
- **Hogar permanente:** esta carpeta vive en `<vault>/method/` — el método
  viaja con el cerebro y no depende de ningún repo. (`brain-health.sh`
  excluye `method/` del chequeo: sus archivos no son notas del grafo.)
