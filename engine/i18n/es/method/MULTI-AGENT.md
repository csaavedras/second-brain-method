<!-- Guía del método — vive en esta carpeta, no se copia a los proyectos. -->
<!-- method-version: 4.0 -->

# MULTI-AGENT.md — Flujo Padre → Subagentes

## Arquitectura

```
PARENT AGENT (main session)
  · The only one with historical context: CONTEXT.md, plan, decisions, brain
  · Orchestrates: plans, writes briefs, dispatches, verifies, integrates
  · The only one that updates CONTEXT.md and proposes git commands
  · Does not implement large tasks directly
        │  dispatches with a TASK BRIEF + model per MODEL-ROUTING.md
        ▼
SUBAGENT (ephemeral, one per task)
  · Context = ONLY its brief: goal, files, pointed conventions
  · Generic role and stack-agnostic: detects the repo's stack; reads
    conventions from the repo's CLAUDE.local.md
  · Does NOT read CONTEXT.md, does NOT touch git, does NOT decide design
  · Returns a REPORT with a fixed format and bounded length
```

La separación protege dos cosas a la vez: **tokens** (el subagente no carga
historia que no necesita; el padre no se contamina con el output intermedio
del subagente) y **seguridad** (el estado y git tienen un solo dueño).

## El Agente Padre

- Es la sesión principal de Claude Code, con el modelo Razonador.
- Al abrir sesión carga el estado (CONTEXT.md + plan en curso) — es el único
  que lo hace.
- Por cada tarea del plan aprobado decide: ¿inline o delegar? (heurística de
  higiene de contexto, README §5.4).
- Si delega: redacta el **task brief** (TASK-BRIEF.template.md) con criterios
  de aceptación medibles, consulta SKILLS-REGISTRY.md para nombrar 0–2
  skills, y elige el subagente del catálogo y el modelo según
  MODEL-ROUTING.md.
- Al recibir el reporte: **verifica la evidencia** antes de marcar `[x]` —
  nunca confía en el "listo" del subagente sin verificar. Si el reporte trae
  el output literal en verde, alcanza con re-correr el comando más barato
  (lint o el test puntual); la re-verificación completa se reserva para
  integraciones o reportes dudosos.
- Integra: actualiza CONTEXT.md, deja el mensaje de commit, sigue con la
  siguiente tarea.

## Los Subagentes

Reglas fijas (van en el prompt de toda definición de subagente):

1. Trabajar **solo** dentro del alcance del brief. Si falta información,
   reportarlo como bloqueo — no explorar a ciegas ni resolverlo por su
   cuenta.
2. **No ejecutar comandos git.** Nunca.
3. **No modificar** CONTEXT.md ni archivos de estado del método.
4. **No tomar decisiones de diseño**: las dudas vuelven al padre en el
   reporte, y si son decisiones, del padre al humano.
5. **No terminó hasta que cada criterio de aceptación tenga evidencia.**
   Correr los comandos de "Criterios de aceptación" del brief, ejercitar
   cada ítem de comportamiento, y devolver el reporte en el formato exigido
   (máx ~30 líneas) con una línea de evidencia por criterio. Las líneas de
   verificación usan la forma verificable por máquina
   ``Verification: `<command>` → <literal result>`` — el hook
   `check-brief.sh` (SubagentStop) revisa el reporte final de todo subagente
   despachado con un TASK BRIEF y lo bloquea (una vez) cuando falta esa
   línea o una sección "Criteria evidence"; la regla la aplica el harness,
   no la obediencia.
6. Invocar solo los skills nombrados en el brief ("Skills a usar"); nunca
   explorar o buscar skills por su cuenta (SKILLS-REGISTRY.md).

## Catálogo de subagentes

Regla v3.1: los subagentes de trabajo son de **rol genérico y
stack-agnóstico** — detectan el stack del repo y leen sus convenciones del
`CLAUDE.local.md`. No se define uno por stack (eso ataba el método a
NestJS/React y dejaba fuera cualquier otro lenguaje, p.ej. un repo Python).
Los roles nativos ya vienen integrados y no se mantienen:

| Rol | Se cubre con | Notas |
|---|---|---|
| Buscar, leer, resumir, verificar estado | **Explore** (subagente nativo, read-only) | Optimizado para barridos: lee extractos, no archivos completos |
| Revisar un diff contra convenciones | **/code-review** (nativo) | Multi-nivel; no requiere definición propia |

Los de trabajo se definen **una vez a nivel personal** en
`~/.claude/agents/<name>.md` — disponibles en todos tus proyectos sin
agregar nada a los repos del equipo:

| Subagente | Rol | Nivel/modelo | Herramientas |
|---|---|---|---|
| `implementer` | Implementar según brief, en **cualquier stack** (lo detecta) | Implementador (Sonnet) | Read, Edit, Write, Bash, Glob, Grep |
| `tester` | Escribir y correr los tests del brief, en **cualquier framework** | Implementador (Sonnet) | Read, Edit, Write, Bash, Glob, Grep |

## Ejemplo de definición — `~/.claude/agents/implementer.md`

```markdown
---
name: implementer
description: Implements a code task from a task brief, in ANY stack. Detects the repo's stack and follows its conventions.
tools: Read, Edit, Write, Bash, Glob, Grep, Skill
model: sonnet
---

You are a stack-agnostic implementer. First step ALWAYS: detect the stack
from its manifests (package.json, pyproject.toml, Cargo.toml, go.mod,
*.xcodeproj…) and read the conventions from the repo's CLAUDE.local.md. Only
then implement, mimicking the neighboring code's patterns.

Fixed rules:
- Work ONLY within the brief's scope; if something is missing, report it as a
  blocker, don't resolve it on your own.
- Don't run git commands. Don't modify CONTEXT.md or state files.
- Don't make design decisions: doubts go in the report.
- You are not done until every acceptance criterion has evidence: run the
  brief's "Acceptance criteria" commands and paste the literal result.
- Report (max ~30 lines): detected stack, files touched (1 line each),
  verification (command + result), criteria evidence (1 line per
  criterion), findings, doubts/blockers.
```

El mismo molde sirve para `tester` — cambia la descripción y el foco
(detectar el framework de test e imitar el estilo de los tests vecinos).

## Ciclo por tarea

```
parent takes the next task from the approved plan
  └─ inline or delegate? (README §5.4)
       └─ delegate: brief → subagent (model per MODEL-ROUTING.md)
            └─ report → parent VERIFIES the evidence (build/test +
               criteria evidence)
                 ├─ green → /gate (code destined for commit/MR)
                 │      ├─ READY → /close: CONTEXT.md + metrics +
                 │      │           commit message → next
                 │      └─ NOT-READY → fix briefs (gate findings) →
                 │                     re-dispatch (counts as a cycle)
                 └─ fail/doubts → fix the brief or ESCALATE the model
                                   (MODEL-ROUTING.md) and re-dispatch
```

**Tope de ciclo: 2.** La misma tarea se re-despacha como máximo **dos veces**
por el mismo criterio fallido o hallazgo de gate — ya sea por escalamiento o
por fixes de gate. Al tercer fallo el problema ya no es el subagente: o el
brief está mal escrito (reescribilo) o hay una decisión de diseño escondida
adentro (sube al humano). Un agente puliendo en círculos nunca converge — el
tope fuerza el diagnóstico hacia arriba.

## Paralelismo

- Dos o más **tareas independientes y sin archivos compartidos** pueden
  despacharse en paralelo. La partición la decide el padre al planificar:
  divide por dueño de archivo, no por tema — si dos tareas "sobre cosas
  distintas" tocan el mismo módulo, son secuenciales.
- **Nunca** dos subagentes sobre los mismos archivos al mismo tiempo.
- El padre integra los reportes **secuencialmente**, verificando después de
  cada integración (no al final de todas).
- **`/gate` corre después de integrar**, sobre el diff combinado — nunca por
  subagente. Revisar fragmentos bendice partes que se rompen en combinación.

## Fork: la excepción que hereda contexto

Los subagentes basados en brief de arriba arrancan **en frío** — ese es el
punto (aislamiento de tokens y contexto). Claude Code también ofrece
**fork**: un subagente que hereda la conversación completa y el modelo del
padre. Usalo solo cuando la tarea *necesita la historia* pero su output
contaminaría al padre:

| Situación | Despacho |
|---|---|
| Tarea bien definida, alcance autocontenido | Subagente en frío + brief (default) |
| Necesita las decisiones/discusión de la sesión para hacer el trabajo (p.ej. redactar un doc a partir de la conversación, un experimento riesgoso sobre el estado actual) | Fork |

Un fork ignora el routing de modelos (siempre corre con el modelo del padre)
— así que nunca es el camino barato; es el camino que preserva contexto. Se
aplican las mismas reglas fijas: sin git, sin CONTEXT.md, las dudas vuelven.

## Reglas de seguridad

- Los subagentes operan bajo los mismos permisos del proyecto (la política
  de README §5.1 aplica a todos por igual).
- El plan sigue siendo aprobado por el humano ANTES de cualquier despacho:
  multi-agente no saltea el gate de plan mode.
- Si un subagente devuelve dudas o bloqueos, suben al padre; si son
  decisiones de diseño, suben al humano. Nadie decide hacia abajo.
