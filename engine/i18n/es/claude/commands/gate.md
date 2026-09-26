---
description: Risk-based pre-commit gate — review lenses, fix cycle, READY/NOT-READY verdict
---

Corré el gate de calidad del método sobre el diff de trabajo actual, ANTES
de dejar un commit message. Salteálo por completo (y decilo) si el diff no
tiene superficie de runtime (docs, comentarios, notas del método).

## 1. Clasificar el diff

Mirá los paths y el contenido tocados, y clasificá (un diff puede ser
ambas cosas):

- **Sensible** — toca manejo de auth/sesión, parseo/validación de input,
  cripto, cambios de dependencias (lockfiles, manifiestos), llamadas de
  red, filesystem o ejecución de procesos, manejo de secretos.
- **Relevante en performance** — toca hot paths, queries a DB, loops sobre
  datasets, caching, concurrencia.
- **Normal** — todo lo demás.

Enunciá la clasificación en una línea antes de correr nada.

## 2. Correr las lentes que aplican

- **Siempre**: `/code-review` — el esfuerzo escala con el diff (diff chico
  → low/medium; grande o sutil → high). Para un branch tamaño-MR grande,
  sugerile `/code-review ultra` al humano en vez de quemar la sesión.
- **Sensible**: adicionalmente `/security-review`.
- **Relevante en performance**: un pase de optimización SOLO con evidencia
  — medí (profile, EXPLAIN, timing) antes de afirmar un hallazgo. Nada de
  hallazgos de micro-optimización especulativos; una opinión de
  performance sin medir no es un hallazgo.
- **Checklist del proyecto**: si existe
  `@@VAULT@@/projects/<proyecto>/review-checklist.md`, chequeá el diff
  contra cada una de sus reglas — están destiladas de comentarios de MR
  reales que recibió este proyecto; pesan más que el gusto genérico.

## 3. Triage

El parent triagea cada hallazgo:

- Solo los hallazgos **confirmados** (escenario de falla reproducible, o
  una regla de checklist verificablemente violada) se convierten en fixes.
  Los plausibles-pero-sin-verificar se listan en el veredicto como notas,
  sin actuar sobre ellos.
- Hallazgos confirmados → fix briefs → `implementer` → re-verificar la
  evidencia. **Máximo 2 ciclos de fix** (MULTI-AGENT.md); al tercero el
  diagnóstico sube al humano.

## 4. Veredicto (obligatorio, última línea del gate)

```
GATE: READY            — lenses run, no confirmed findings open
GATE: NOT-READY — <n> confirmed finding(s) open: <one line each>
```

Solo **READY** habilita dejar el commit message. NOT-READY en el tope del
ciclo → presentale los hallazgos abiertos al humano y frená; nunca "READY
con salvedades".

Reglas: el gate corre sobre el diff **integrado** (después de mergear el
trabajo de los subagentes), nunca por subagente. El gate en sí no toma
decisiones de diseño — los hallazgos que impliquen una suben al humano.
</content>
