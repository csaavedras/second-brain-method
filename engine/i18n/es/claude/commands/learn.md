---
description: Capturar un aprendizaje en el cerebro (learning/ del vault)
argument-hint: [tema o descripción de lo aprendido]
---

Capturá en el vault (`@@VAULT@@`) el aprendizaje:
$ARGUMENTS

Si no hay argumentos, extraé de la conversación en curso qué se aprendió que
tenga valor más allá de hoy.

**Modo especial — `/learn review <comentario de MR>`**: el argumento es un
comentario de review que recibió una MR real. No lo archives en
`learning/`; en cambio: destilalo en UNA regla chequeable (qué revisar en un
diff, en una línea — no la anécdota), y agregala al
`@@VAULT@@/projects/<proyecto>/review-checklist.md` del proyecto actual
(creala desde REVIEW-CHECKLIST.template.md del método si no existe), con el
comentario de origen y la fecha. Deduplicá: si ya hay una regla que lo
cubre, afiná esa regla en vez de agregar una gemela. Este archivo es la
ÚNICA excepción a la regla "no tocar projects/" de más abajo — alimenta a
`/gate`. Reportá la regla agregada/actualizada y frená (saltate los pasos de
abajo).

1. **Clasificá** según BRAIN.md del método (`@@VAULT@@/method`):
   - `concept` — idea durable → `learning/<tema>/<slug>.md`
   - `resource` — curso/libro/artículo → `learning/<tema>/<slug>.md` con
     `status: in-progress | done | dropped`
   - `til` — dato puntual del día → `learning/til/<AAAA-MM-DD>-<slug>.md`
2. **Chequeá duplicados**: grep por el tema en `learning/` y `00-index/`.
   Si ya existe nota del concepto, actualizala — no crees una segunda.
3. **Escribí la nota atómica** (una idea por nota) con el frontmatter y
   formato de BRAIN.md. La explicación va en tus propias palabras, no
   copiada de la fuente.
4. **Linkeá**: al MOC del tema en `00-index/` si existe, y a conceptos,
   patterns o decisiones relacionadas. **Regla de MOC**: si el tema junta 3+
   notas y no tiene MOC, creá `00-index/<tema>.md` (type: moc) y linkeá las
   notas existentes desde ahí (+ una línea en `00-index/home.md`).
5. **Reportá**: ruta de la nota creada/actualizada, links agregados, y si
   creaste un MOC.

No toques `projects/` ni ningún CONTEXT.md: esto es captura de conocimiento,
no estado de proyecto. (Única excepción: `review-checklist.md` en el modo
`review` de arriba.)
