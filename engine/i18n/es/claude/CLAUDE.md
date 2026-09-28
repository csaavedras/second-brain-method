<!-- method-version: 4.1 — instalado por install.sh (adelgazado: el
     detalle del cierre vive en /close). Fuente: @@VAULT@@/method/ -->

# Método de trabajo personal

## Cerebro
- Vault: `@@VAULT@@` — todo el estado del método vive ahí.
- Estado del proyecto actual: `<vault>/projects/<proyecto>/`; la ruta exacta
  la indica el `CLAUDE.local.md` de cada repo.

## Reglas siempre activas
- Tarea que modifica código → **plan mode** y plan como todo list antes de
  tocar archivos. Tareas grandes (varias sesiones o >~5 pasos): guardar el
  plan aprobado en `<vault>/projects/<proyecto>/plans/<AAAA-MM-DD>-<tarea>.md`.
- Nunca `git add` / `commit` / `push` / `checkout` sin aprobación explícita.
- Nunca `rm` / `rmdir` / `mv` sobre archivos no creados en la misma sesión.
- Feature/fix en branch propio (`feat/<tema>`, `fix/<tema>`), nunca directo
  sobre `main`/`master`. Crear el branch también pide aprobación.
- Decisiones de diseño: siempre con el humano presente. Nadie decide hacia abajo.
- Secretos: nunca leer ni registrar valores de tokens/credenciales — solo
  nombres de variables y dónde obtener sus valores.

## Contexto y delegación
- Docs de convenciones: leer bajo demanda solo los relevantes a la tarea
  (índice en el `CLAUDE.local.md` del repo), nunca todos de entrada.
- La sesión principal **orquesta**: mantiene el contexto y las decisiones, y
  **delega los cambios**. Elegir por objetivo (no por costumbre): búsqueda →
  **Explore**; implementar → **`implementer`**; tests → **`tester`**; review
  de diffs → **`/code-review`**. Los subagentes son de **rol genérico** y
  detectan el stack del repo — las convenciones viven en su `CLAUDE.local.md`.
  Los briefs llevan criterios de aceptación + 0–2 skills de
  `method/SKILLS-REGISTRY.md`.
- Código destinado a un commit/MR → `/gate` sobre el diff integrado; solo un
  veredicto READY habilita dejar el commit message (detalle en el comando).
- Modelo por uso (Explorador→Haiku · Implementador→Sonnet · Razonador→Opus):
  toda tarea delegable va al **modelo más barato que la resuelve bien**
  (detalle en `method/MODEL-ROUTING.md` y `MULTI-AGENT.md`).
- Verificar el reporte del subagente antes de dar la tarea por hecha. En el
  reporte de `/start`, nombrar qué skill/rol y qué modelo se usará.

## Sesiones
- Abrir sesión: `/start`. Cerrar cada tarea o la sesión: `/close` —
  obligatorio antes de avanzar a la siguiente tarea o cortar.
- Modelo y esfuerzo se fijan al abrir; cambiarlos a mitad **invalida el
  caché** → hacelo en el corte `/close`→`/start`. Poda de contexto y detalle
  en `method/MODEL-ROUTING.md`.
</content>
