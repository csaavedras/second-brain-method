<!--
  PLANTILLA — el PROMPT MAESTRO de un proyecto. Se completa UNA vez al
  arrancar (a mano, o con el agente pregunta por pregunta vía /kickoff) y se
  persiste en <vault>/projects/<project>/brief.md.
  Es la fuente de verdad de la VISIÓN: no se reescribe, se enmienda.
  Regla de calidad: si no sabés una sección, escribí "A DECIDIR" — eso se
  resuelve con el agente en plan mode, no se inventa.
-->
<!-- method-version: 3.2 -->

---
type: brief
project: <project>
date: <YYYY-MM-DD>
status: current
---

# PROMPT MAESTRO — <nombre del proyecto>

## 1. Visión
<!-- Elevator pitch: 2-3 líneas. Qué es y para quién. Si no lo podés decir
     en 3 líneas, todavía no está claro. -->
<...>

## 2. Problema
<!-- Qué duele hoy y por qué vale la pena resolverlo. Sin un problema real,
     el proyecto muere en la semana 2. -->
<...>

## 3. Usuarios
<!-- Quién lo usa y en qué contexto (¿solo vos? ¿público? ¿móvil/desktop?).
     Cambia TODO: auth, deploy, UI. -->
<...>

## 4. Alcance del MVP
<!-- Qué SÍ hace la v1. Entre 3 y 7 funcionalidades, cada una VERIFICABLE
     (que se pueda demostrar). Numeradas: el plan del MVP sale de acá. -->
1. <...>
2. <...>
3. <...>

## 5. Fuera de alcance (v1)
<!-- Qué NO hace la v1, aunque duela. Tan importante como el punto 4:
     es el freno contra el scope creep. -->
- <...>

## 6. Stack y restricciones
<!-- Separá lo FIJO de lo A DECIDIR: -->
- **Fijo:** <tecnologías que ya elegiste y por qué — p.ej. TS + React porque
  es tu stack>
- **A decidir:** <lo que querés resolver con el agente en plan mode —
  p.ej. ¿SQLite o Postgres? ¿deploy dónde?>
- **Restricciones:** <presupuesto $0, solo local, debe correr en X, etc.>

## 7. Datos y entidades
<!-- Los sustantivos del dominio y sus relaciones gruesas. No es el schema:
     es el vocabulario. P.ej.: Usuario tiene N Cuentas; Cuenta tiene N
     Movimientos; Movimiento pertenece a una Categoría. -->
- <...>

## 8. Criterios de éxito
<!-- Cómo sabés que el MVP está TERMINADO. Medibles y honestos.
     P.ej. "cargo los gastos del mes en <2 min y veo el total por categoría". -->
- <...>

## 9. Riesgos y dudas abiertas
<!-- Lo que todavía no sabés (técnico o de producto). Van directo a
     "Preguntas abiertas" del CONTEXT.md y se resuelven antes o durante el
     plan. -->
- <...>

## 10. Referencias
<!-- Apps parecidas, diseños que te gustan, docs, repos de inspiración. -->
- <...>
