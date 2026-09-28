<!-- Guía del método — vive en esta carpeta, no se copia a los proyectos. -->
<!-- method-version: 4.0 -->

# SKILLS-REGISTRY.md — Selección curada de skills para despachos

## El principio

Los skills son baratos de mantener instalados (uno sin usar cuesta ~1 línea
de índice) pero caros de elegir mal: un subagente cargado con el skill
equivocado sigue el playbook equivocado. La regla del método:

> **Selección dinámica desde un registro local curado — nunca búsqueda
> externa dinámica.** El orquestador consulta este registro al redactar un
> task brief y nombra **0–2 skills** en la sección "Skills a usar" del
> brief. Traer o instalar skills desde internet al momento del despacho está
> prohibido: agrega latencia, no-determinismo y un riesgo real de cadena de
> suministro (ejecutar instrucciones de un playbook que nadie curó).

Los subagentes (`implementer`, `tester`) llevan la herramienta `Skill` e
invocan **solo** los skills nombrados en su brief — no navegan el catálogo.

## El registro

Una fila por skill que tengas instalado y validado. Mantenelo honesto: esta
tabla es lo que lee el orquestador al momento del despacho.

| Skill | Usarlo cuando | Stacks / tareas |
|---|---|---|
| `verify` | El cambio tiene superficie en runtime y hay que ejercitarlo de punta a punta, no solo testearlo | cualquiera |
| `code-review` | Revisar un diff por corrección + prácticas + eficiencia (lo corre el padre, vía `/gate`) | cualquiera |
| `security-review` | El diff toca auth, manejo de input, cripto, deps o red (lo corre el padre, vía `/gate`) | cualquiera |
| `dataviz` | La tarea produce un gráfico, dashboard o visualización de datos | frontend, notebooks, reportes |
| `frontend-design` | Construir UI que se vea intencional, no default | frontend web |
| `test-driven-development` | El brief pide flujo de tests primero | cualquiera |
| <agregá el tuyo> | <una línea: el disparador, no la descripción> | <dónde aplica> |

Las filas marcadas "lo corre el padre" son lentes de gate — nunca se nombran
en un brief de subagente; el padre las invoca directamente durante `/gate`.

## Reglas de curación

1. **Agregar al primer uso real.** Un skill entra al registro la primera vez
   que se ganó de verdad su lugar en una tarea — con una línea de disparador
   escrita por vos, no copiada de su descripción.
2. **Podar por desuso.** Un skill que no se disparó en **~10 sesiones** sale
   de la tabla (el skill puede seguir instalado; solo deja de ser material
   de despacho). Revisar durante el mantenimiento del vault, p.ej. al correr
   `brain-health.sh`.
3. **Una línea de disparador por skill.** Si no podés decir en una línea
   *cuándo* aplica, no conocés el skill lo suficiente como para rutearle
   trabajo.
4. **El registro vive en el vault** (`<vault>/method/SKILLS-REGISTRY.md`) —
   es curación personal, como el resto del cerebro.

## Cómo se ejerce

```
parent writes a task brief
  └─ consults this table: does any trigger match the task?
       ├─ no  → "Skills to use" is omitted (most tasks)
       └─ yes → names 0–2 skills + one line of why, e.g.:
                 "- test-driven-development — brief asks for tests-first"
            └─ subagent invokes ONLY those, via its Skill tool
```

Nombrar más de 2 skills en un brief es un olor: la tarea probablemente es
demasiado grande — mejor partir el brief.
