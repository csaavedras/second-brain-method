<!-- Guía del método — vive en esta carpeta, no se copia a los proyectos. -->
<!-- method-version: 4.0 -->

# MODEL-ROUTING.md — Elección de modelo por tipo de tarea

## El principio

El modelo de la sesión principal lo fija el humano (`/model`). Pero el
agente **elige el modelo cada vez que delega una tarea a un subagente** —
ahí vive el ahorro de tokens. La sesión principal (agente padre) razona con
el mejor modelo disponible; el trabajo mecánico se despacha barato.

> **Regla de oro:** toda tarea delegable se delega al **modelo más barato
> que la resuelve bien**.

## Los tres niveles

Para que esta guía no envejezca con los nombres comerciales, el método
define niveles; la columna de equivalencias se actualiza cuando cambia la
oferta:

| Nivel | Rol | Modelo actual (jul 2026) |
|---|---|---|
| **Explorador** | Buscar, leer, resumir, verificar estado | Haiku 4.5 |
| **Implementador** | Ejecutar tareas bien definidas con un brief | Sonnet 5 |
| **Razonador** | Planificar, decidir, revisar, debuggear | Opus 4.8 / Fable 5 (el modelo principal de la sesión) |

## Routing por tipo de tarea

| Tarea | Nivel | Por qué |
|---|---|---|
| Búsqueda/barrido de código ("¿dónde está X?", "¿qué usa Y?") | Explorador | Resultado corto; no requiere razonamiento profundo |
| Resumir docs o archivos largos | Explorador | Compresión, no criterio |
| Verificar estado (correr build/test y reportar el resultado) | Explorador | Ejecutar y leer output |
| Implementar una tarea con un brief claro (endpoint, componente, CRUD, tests) | Implementador | Alcance cerrado y convenciones dadas: el criterio ya viene decidido |
| Refactor acotado con un patrón conocido | Implementador | El brief define el patrón; solo hay que aplicarlo |
| Redactar documentación técnica de lo ya hecho | Implementador | Describe, no decide |
| Planificar / diseñar arquitectura | Razonador | Un error acá cuesta más que los tokens ahorrados |
| Debugging de una causa no evidente | Razonador | Requiere hipótesis y razonamiento sostenido |
| Code review de un diff | Razonador | Detectar lo sutil es justamente el punto |
| Decisiones de diseño / trade-offs | Razonador | Y siempre con el humano presente en la decisión |

## Escalamiento (nunca degradación)

- Si un subagente falla, reporta dudas, o su output **no pasa la
  verificación del padre** → la misma tarea se re-despacha **un nivel
  arriba**.
- Nunca al revés: no degradar el modelo a mitad de una tarea.
- Dos fallos del mismo nivel en la misma tarea = señal de que el **brief está
  mal escrito**, no (solo) de que el modelo es chico. Revisar el brief antes
  de escalar de nuevo (ver TASK-BRIEF.template.md).

## Dónde se ejerce el routing

- **En el despacho**: el parámetro de modelo al invocar el subagente.
- **En la definición del subagente**: el frontmatter `model:` de
  `~/.claude/agents/<name>.md` — cada tipo de subagente ya trae su nivel por
  defecto (ver MULTI-AGENT.md).

Dos casos que quedan fuera de la tabla de routing (v4):

- **Fork** (subagente que hereda el contexto del padre, MULTI-AGENT.md):
  siempre corre con el **modelo del padre** — un override de modelo se
  ignora. Nunca elijas un fork para ahorrar tokens; elegilo solo cuando la
  tarea necesita la historia de la sesión.
- **Fast mode** (`/fast`): el mismo modelo top con output más rápido — NO es
  un nivel más barato y no reemplaza el routing. Igual que modelo/esfuerzo,
  activalo/desactivalo en el corte `/close`→`/start`, no a mitad de sesión
  (higiene del caché de prefijos abajo).

## Higiene del caché de prefijos (v3.2)

El caché de la API matchea por **prefijo exacto** (no por semántica): reusa
el cómputo mientras el inicio del contexto no cambie, facturado a una
fracción del costo de un token nuevo. Implicancia para la **sesión
principal**:

- **Fijá el modelo y el nivel de esfuerzo al ABRIR la sesión.** Cambiarlos a
  mitad de camino —o alterar la superficie de tools / el system prompt—
  **invalida todo el caché** y fuerza recomputar el historial entero. Si
  necesitás otro modelo u otro esfuerzo, hacelo en el corte natural: `/close`
  → sesión nueva.
- Mantené el **prefijo estable**: las reglas siempre-activas van arriba y
  quietas (CLAUDE.md flaco); lo que muta (la conversación) queda al final.
- **Los subagentes NO sufren esto**: cada uno es su propio contexto efímero,
  así que el routing de modelos por despacho (Haiku/Sonnet/Opus) es gratis
  desde la óptica del caché del padre. Esta higiene aplica solo a la sesión
  principal.

## Poda de contexto — cerrar, compactar o ramificar (v3.2)

Una sesión acumula peso muerto (salidas largas, intentos fallidos) que
diluye la atención y quema tokens. Orden de preferencia:

1. **Cerrar y reabrir** (default): terminaste una tarea → `/close` → `/start`
   en una sesión nueva. Lo más limpio — el estado vive en el vault, no en el
   hilo.
2. **`/compact`** solo a mitad de UNA tarea larga que no querés cortar:
   condensa el historial preservando la intención (reescribe el prefijo →
   igual rompe el caché).
3. **Ramificar** para experimentos riesgosos: una sesión aparte para probar
   un refactor dudoso; si sale mal, se descarta sin ensuciar la principal.
4. **`/clear`** tras consolidar un módulo: reinicia el contador de contexto
   preservando solo el prefijo base + el estado del filesystem.
