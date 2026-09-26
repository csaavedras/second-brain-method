<!-- Guía del método — vive en esta carpeta, no se copia a los proyectos. -->
<!-- method-version: 4.0 -->

# METRICS.md — Telemetría del método (duraciones, tokens, estimaciones)

## Por qué

Estimar ("pointear") y mejorar el método necesitan datos, no impresiones:
cuánto tardó realmente una tarea, adónde fueron los tokens, qué tan cerca
estuvo la estimación. El método captura esto en los límites de sus rituales
existentes — cero ceremonias nuevas, ~5 segundos de input humano por tarea
cerrada.

## Cómo se captura (tres capas)

1. **Eventos de hook** (`metrics-event.sh`, registrado en SessionStart /
   SubagentStop / Stop): agrega líneas `{event, ts, epoch, session_id}` a
   `<vault>/projects/<project>/metrics/events.jsonl` — `epoch` (segundos
   Unix) es lo que lee la matemática de duración del colector; `ts`
   (ISO-8601) es para humanos. Silencioso, siempre sale con 0 — **la
   telemetría nunca bloquea el flujo**. Los repos sin `CLAUDE.local.md` no
   loguean nada.
2. **Colección por tarea** (`scripts/collect-metrics.sh`, invocado por
   `/close`): parsea el transcript de la sesión (`~/.claude/projects/…/*.jsonl`)
   con `jq` — uso de tokens por modelo, padre vs. sidechain (subagentes) — y
   lo cruza con las líneas de esta sesión en `events.jsonl` (filtradas por
   `session_id`) para las duraciones. Los args `--task`/`--type`/`--estimate`
   del humano completan el registro; el script mismo emite la línea completa.
3. **Rollup** (`scripts/brain-metrics.sh`, corrido semanalmente como
   `brain-health.sh`): agrega el `metrics.jsonl` de todos los proyectos —
   0 tokens de LLM.

## Schema — una línea por tarea cerrada en `metrics/metrics.jsonl`

```json
{
  "date": "YYYY-MM-DD",
  "session_id": "…",
  "task": "short task title",
  "type": "feat | bug | refactor | spike",
  "estimate": "3pt | 2h | null",
  "duration": { "total_min": 0, "plan_min": 0, "exec_min": 0 },
  "subagents": [ { "role": "implementer", "model": "sonnet", "duration_s": 0 } ],
  "tokens": {
    "in": 0, "out": 0, "cache_read": 0,
    "by_model": { "<model-id>": { "in": 0, "out": 0 } },
    "parent": { "in": 0, "out": 0 },
    "subagents_total": { "in": 0, "out": 0 }
  }
}
```

Notas sobre la semántica:

- `duration.plan_min`: inicio de sesión → primera aprobación de plan (fase de
  refinamiento); `exec_min` = el resto. Se deriva de los timestamps de los
  eventos — exacto.
- `type` y `estimate` vienen del humano en `/close` — son lo que hace que el
  dato sea comparable con el pointing ágil. `estimate: null` está bien; una
  estimación errada registrada con honestidad vale más que un blanco.
- Los campos que el colector no puede calcular (p.ej. sin archivo de
  eventos) quedan en `null`, y la línea se escribe igual: dato parcial >
  ningún dato.

## Leer los datos

`brain-metrics.sh` reporta por proyecto y en total:

- tokens/tarea y duración por `type` (¿qué cuesta un "bug" contra un "feat"?)
- estimación vs. real (tu precisión de pointing en el tiempo)
- reparto de tokens padre vs. subagente (¿la delegación realmente ahorra?)
- evolución mes a mes (¿el método se vuelve más barato/rápido?)

Los archivos jsonl son datos, no notas: sin frontmatter, excluidos de los
chequeos de `brain-health.sh` (solo escanea `*.md`), y exportables sin
esfuerzo a cualquier dashboard después (el schema es lo bastante plano para
`jq`/DuckDB).

## Qué deliberadamente no hacemos

- No hay infra de OpenTelemetry/collector: el 90% del valor correcto a 0
  infra. El jsonl migra sin esfuerzo si ese día llega.
- No hay columna de costo en dólares: los precios cambian y dependen del
  plan; tokens y modelos son la verdad de base estable. Calculá el costo al
  momento de leer si hace falta.
