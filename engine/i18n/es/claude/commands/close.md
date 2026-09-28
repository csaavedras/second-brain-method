---
description: Cierre de tarea o de sesión — persistir el estado en el vault
---

Ejecutá el cierre según el método. Determiná qué caso aplica:

## A. Cierre de tarea completada

1. **Verificar antes de marcar `[x]`**: correr el build/test/lint que
   corresponda y registrar en CONTEXT.md el comando y su resultado. Sin
   verde, la tarea queda `[~]`. Para cambios no triviales con superficie de
   runtime, ejercitar también el flujo de punta a punta (skill nativa
   `/verify`) — tests en verde solos dejan pasar justo los bugs que después
   aparecen como comentarios de MR.
2. **Gate**: si la tarea produjo código destinado a un commit/MR, `/gate`
   tiene que haber corrido sobre el diff integrado con veredicto **READY**.
   NOT-READY → el cierre se frena acá; los hallazgos abiertos deciden el
   próximo paso.
3. Actualizar el CONTEXT.md del vault: tarea, decisiones nuevas, preguntas
   abiertas, "Estado actual" con fecha ISO `AAAA-MM-DD`.
4. **Métricas**: preguntame dos cosas — `type` de la tarea (feat / bug /
   refactor / spike) y `estimate` opcional (puntos o tiempo que te había
   asignado) — y después corré el collector y anexá su línea de stdout
   (emite el registro completo):

   ```
   @@VAULT@@/method/scripts/collect-metrics.sh \
     <transcript> @@VAULT@@/projects/<proyecto>/metrics/events.jsonl \
     --task "<título corto>" --type <type> [--estimate "<estimate>"] \
     >> @@VAULT@@/projects/<proyecto>/metrics/metrics.jsonl
   ```

   `<transcript>` es el JSONL de esta sesión: el archivo modificado más
   recientemente en `~/.claude/projects/<cwd-con-slashes-como-guiones>/*.jsonl`.
   Schema en `method/METRICS.md`. Si el script falla, reportalo y seguí: el
   cierre nunca se bloquea por telemetría.
5. Registrar en el cerebro lo transversal: decisión no-obvia → `decisions/`
   (+ link en el hub); aprendizaje reutilizable → `patterns/` o `learning/`.
6. Dejar el commit message listo: Conventional Commits con scope, inglés,
   una línea, ≤ 100 caracteres.

No avanzar a la siguiente tarea hasta completar los 6 puntos.

## B. Cierre de sesión con tarea a medias

1. Marcar la tarea `[~]` en el todo list.
2. Volcar en "⭐ PRÓXIMA SESIÓN" el punto **exacto**: archivo que se estaba
   tocando, decisión pendiente, test que falla, comando que faltó correr.
3. Registrar hallazgos parciales (marcados como sin confirmar).
4. Actualizar "Estado actual" con la fecha.

Prueba de fuego: una sesión nueva tiene que retomar sin preguntar nada.

## Mantenimiento (chequear en todo cierre)

- Fase completada o CONTEXT.md > ~150 líneas → mover la historia cerrada a
  `sessions/<AAAA-MM-DD>.md` del proyecto y dejar solo lo vivo. Wikilink en
  "Historia previa".
- El hub se actualiza solo al cerrar **hitos**, no en cada tarea.
- Si el árbol del repo cambió estructuralmente en esta sesión, actualizar el
  árbol cacheado del hub.

## Respaldo del cerebro (último paso, SIEMPRE)

El vault (`@@VAULT@@`) es un repo git:

1. `git -C @@VAULT@@ status --porcelain` — si está limpio, listo.
2. Si hay cambios: mostrame el resumen y **con mi OK** corré add + commit:
   `chore(brain): AAAA-MM-DD cierre <proyecto|estudio>` — un solo commit
   con todo lo de la sesión.
3. Si hay remoto configurado, push (también con mi OK). Si el push falla
   (sin red, sin remoto), reportalo y terminá igual: el respaldo nunca
   bloquea el cierre.

Nota: esto versiona SOLO el vault. Los repos de código de cada proyecto
tienen su propio git y sus propias reglas (nunca sin aprobación).
