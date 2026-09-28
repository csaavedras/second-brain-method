# 🧠 Segundo Cerebro para Claude Code

[English](README.md) · **Español**

> Un método de trabajo que le da a [Claude Code](https://claude.com/claude-code)
> memoria persistente. Instalalo una vez y cada sesión **retoma donde la
> dejaste**, sin tener que reexplicar nada. macOS.

---

## Qué es

Claude Code no recuerda nada entre sesiones: cada vez que abrís la
terminal, arranca en blanco. Este método le da **memoria** — un "segundo
cerebro" en tu disco donde queda escrito el estado de cada proyecto y todo
lo que aprendés.

En la práctica, se instalan tres cosas juntas:

- Un set de **comandos** (`/start`, `/close`, `/learn`, …) que cargan y
  guardan tu contexto con disciplina.
- Un **vault** (una carpeta) donde vive todo ese conocimiento, que podés
  abrir y navegar en [Obsidian](https://obsidian.md).
- Un set de **reglas de seguridad** para que Claude nunca toque git, borre
  archivos ni exponga secretos sin tu permiso.

---

## ✨ Por qué usarlo — los beneficios

| Sin el método | Con el método |
|---|---|
| Cada sesión arranca de cero: reexplicás el proyecto y Claude re-explora el repo, quemando tiempo y tokens | `/start` retoma en 30 segundos con el estado exacto y el próximo paso |
| Lo que decidiste ayer se evapora cuando cerrás la terminal | `/close` deja escrito qué se hizo, qué falta y **por qué** se decidió cada cosa |
| Lo que estudiás se pierde o queda disperso en notas sueltas | `/learn` acumula tu aprendizaje en un grafo de notas conectadas que crece con el tiempo |
| Claude puede hacer cambios riesgosos (git, borrados, branches) por su cuenta | Ningún git ni borrado sin tu aprobación explícita; los secretos nunca se leen ni se guardan |
| Gastás tokens cargando contexto de más en cada mensaje | Solo se carga lo mínimo necesario y el resto se trae bajo demanda → **más barato y más rápido** |

**En una frase:** trabajás con un asistente que tiene memoria, criterio y
frenos — y que mañana sabe exactamente dónde lo dejaste.

La prueba de fuego: mañana escribís `/start` y seguís trabajando **sin
explicar nada**.

---

## Requisitos

- **macOS** (este instalador es solo para Mac).
- **[Claude Code](https://claude.com/claude-code)** instalado (el CLI `claude`).
- **git**.
- **jq** — `brew install jq`.
- **perl** — viene con macOS, no hay que instalar nada.
- **[Obsidian](https://obsidian.md)** (opcional, recomendado) para ver y
  navegar tu cerebro visualmente.

---

## Instalación

```bash
git clone https://github.com/csaavedras/second-brain-method.git
cd second-brain-method
./sbm install
```

Sin flags pregunta `Language [en]:` y `Ruta del vault [~/second-brain]:`
(Enter acepta el valor por defecto). Para saltear las preguntas:
`./sbm install --yes`, o indicá todo con `--lang en|es` y `--vault PATH`
(acepta `~`, y una ruta relativa se resuelve contra tu directorio actual).
Si ya estaba instalado, `sbm` te avisa y te sugiere `./sbm update`.

A un vault nuevo o vacío se le arma la estructura (carpetas, `.gitignore`, un
`00-index/home.md` inicial, su propio `git init`); un vault existente
mantiene su contenido — solo se agregan los archivos `method/` del método
(más un `git init` si todavía no es un repo git). Termina con un checklist
"CÓMO EMPEZAR" — mirá [Cómo trabajar](#cómo-trabajar).

Si la ruta del vault que diste ya existe, no está vacía, y no parece un
vault de segundo cerebro (no tiene carpeta `method/` ni `projects/`),
install te pregunta `[y/N]` antes de adoptarlo — `--yes` convierte eso en un
abort directo (no se escribe nada) salvo que también pases `--force`, que
saltea el chequeo por completo. Una carpeta que ya tiene `method/` o
`projects/` siempre se adopta directo, sin preguntar.

`./install.sh` sigue funcionando como alias de `./sbm install` — hasta
acepta una ruta como primer argumento (`./install.sh <path>`, se traduce a
`--vault <path>`) para bookmarks/docs viejos, pero preferí `./sbm`. Cada
subcomando también respeta una variable de entorno `CLAUDE_HOME` (por
defecto `~/.claude`), útil para probar el método en un sandbox primero.

---

## Actualización

```bash
./sbm update
```

Por defecto esto hace pull (`git pull --ff-only`) del repo desde el que
instalaste (tiene que estar en `main`, limpio, si no `sbm` sugiere
`--no-pull`), y después re-aplica el método. Flags: `--no-pull` (aplicar
tal cual está), `--take-new` (ver abajo), `--lang en|es`.

**Nunca se sobreescribe en silencio nada que hayas editado** — cada
archivo gestionado se rastrea por checksum. Los archivos sin tocar se
actualizan en el lugar; un archivo editado (o uno preexistente tuyo) recibe
su nueva versión escrita al lado como `<file>.new` para mergear a mano;
`--take-new` lo reemplaza en cambio, respaldando el viejo en
`~/.claude/.second-brain/backups/<UTC timestamp>/…`.
`settings.json` siempre se mergea (tu modelo, tema, plugins y hooks se
mantienen). `CLAUDE.md`: solo se gestiona el bloque entre los marcadores
`BEGIN`/`END SECOND BRAIN METHOD`, y también se rastrea por checksum —
editá a mano *adentro* del bloque y el próximo update lo trata igual que
cualquier otro archivo editado (un `CLAUDE.md.new` al lado de tu archivo
intacto; `--take-new` lo respalda y lo reemplaza); editá afuera del bloque
(tus propias reglas) y eso siempre se conserva. Una instalación vieja sin
marcadores también recibe un `CLAUDE.md.new` en un update normal —
`--take-new` ahí respalda el archivo y después *agrega* el bloque a tu
contenido existente, así que tus propias reglas sobreviven. Marcadores
rotos abortan antes de tocar nada.

Tanto install como update terminan con un resumen —
`▸ added=N updated=N conflict=N taken=N deleted=N orphaned=N` —
donde `conflict`/`taken` necesitan tu revisión (`.new` escrito /
reemplazado con un backup) y `deleted`/`orphaned` son archivos que salieron
del método, eliminados si no estaban editados o dejados en su lugar si los
habías editado.

---

## Estado

```bash
./sbm status
```

Solo lectura: versión instalada, idioma y vault; avisa si la versión de
este repo avanzó (`corré ./sbm update`); lista cualquier archivo `.new`
pendiente y cualquier archivo gestionado editado desde el último apply —
o, cuando no hay nada que mirar, `ok — sin archivos .new, nada editado
desde el último apply.`

---

## Idioma

`en` (inglés) o `es` (español rioplatense con voseo) — se elige al
instalar, se cambia después con `./sbm update --lang <en|es>`. Se traduce:
el bloque de `CLAUDE.md`, los comandos, los agentes, los docs `method/`
del vault, y los propios mensajes de `sbm`; los nombres de comandos y
archivos nunca cambian. El idioma y la ruta del vault se recuerdan en
`~/.claude/.second-brain/config.json`.

---

## Adoptar un setup existente

¿Ya tenés un `~/.claude` armado a mano, o una versión vieja de este
método? `./sbm install --vault <tu vault existente>` — no se sobreescribe
nada. Todo lo tuyo que colisione sale como `<file>.new`; `./sbm status`
los lista todos, después mergeá a mano o `./sbm update --no-pull
--take-new` para tomar la versión del método en todos lados (los archivos
viejos se respaldan primero). Un `CLAUDE.md` sin marcadores recibe el
bloque del método *agregado* al final con `--take-new`, no reemplazado —
tus reglas existentes se mantienen. Si la ruta del vault no tiene todavía
`method/` ni `projects/`, install te pregunta antes de adoptarla (o
rechaza directo con `--yes`); pasá `--force` para saltear eso.

---

## Cómo trabajar

Todo gira alrededor de tres operaciones de memoria: **cargar** (`/start`),
**guardar** (`/close`) y **capitalizar** (`/learn`).

### Arrancar un proyecto
```bash
cd ~/my-project && claude
```
```
/new-project my-project    ← da de alta el proyecto en tu cerebro
/start                     ← abre la sesión
```

### Un día de trabajo normal
```
/start          ← te dice dónde lo dejaste y cuál es el próximo paso
...trabajás...   ← Claude propone un plan, vos lo aprobás, lo ejecuta
/close          ← al final de cada tarea y cuando parás: guarda el estado
```
Si te olvidás de cerrar, el método te lo recuerda antes de que termines.

### Aprender algo (con o sin proyecto)
```
/learn          ← al final de un chat: guarda lo aprendido en tu cerebro
```
O algo específico: `/learn react hooks`.

### Repasar lo que sabés
No hace falta Claude: abrí tu vault en **Obsidian** y navegá el estado de
tus proyectos, las decisiones que tomaste y todo lo que aprendiste —
graph view incluida.

---

## Los comandos

| Comando | Cuándo | Qué hace |
|---|---|---|
| `/new-project <name>` | Al agregar un proyecto | Lo da de alta en el cerebro y ancla el repo |
| `/kickoff [name] [brief]` | Al arrancar un proyecto desde un prompt maestro | Da de alta el proyecto, guarda el brief, deriva el cerebro y propone un primer plan |
| `/start` | Al abrir cada sesión | Carga el estado y te dice el próximo paso |
| `/close` | Al cerrar cada tarea y la sesión | Guarda qué se hizo, qué falta y por qué |
| `/learn [topic]` | Cuando aprendés algo que dura más que el día | Lo agrega a tu grafo de conocimiento |
| `/gate` | Antes de dejar un commit message | Corre las lentes de revisión que corresponden al diff y da un veredicto READY/NOT-READY |

---

## Dónde vive todo

- Los comandos y las reglas: en `~/.claude/` (config de Claude Code), más
  su propio estado bajo `~/.claude/.second-brain/` (`config.json`,
  `manifest.json`, `backups/`).
- Tu conocimiento: en el **vault** (`~/second-brain` por defecto) — es
  tuyo, local, y podés versionarlo en tu propio repo git.

---

## Desinstalar

No existe `sbm uninstall` — sacar el método es un paso manual y
deliberado para que nunca se lleve puesto tu vault ni tus propias
personalizaciones de `~/.claude`:

```bash
# cada archivo que instaló el método (comandos, agentes, hooks, el method/ del vault)
jq -r 'keys[]' ~/.claude/.second-brain/manifest.json |
  while IFS= read -r f; do rm -f "$f"; done
rm -rf ~/.claude/.second-brain/   # el estado propio del método
```

Después, a mano: borrá el bloque entre los marcadores `BEGIN`/`END SECOND
BRAIN METHOD` en `~/.claude/CLAUDE.md`, y sacá las entradas de hooks del
método de `~/.claude/settings.json`. El vault es tuyo — guardalo o
borralo, independientemente de lo anterior.

---

## Privacidad

Tu cerebro es **local**. Si decidís sincronizarlo con un repo git, tené en
cuenta que el método está diseñado para **nunca** guardar valores secretos
(tokens, contraseñas): solo registra *nombres* de variables y dónde
conseguir sus valores. Aun así, revisá antes de hacer público cualquier
vault.

---

## ¿Cómo funciona por dentro?

Para quien quiera el detalle, la especificación completa del método (la
arquitectura, el sistema multi-agente, los templates) vive dentro de tu
vault en `method/README.md` una vez instalado.

---

## Licencia

MIT — usalo, adaptalo y compartilo.
