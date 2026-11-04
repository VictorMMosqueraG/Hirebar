# Arquitectura

Hirebar tiene dos mitades:

1. **La app** (Swift, sin IA): busca en portales públicos cada 20–30 minutos, filtra con tu perfil, avisa por Telegram y lleva horarios, lotes, cupos y métricas.
2. **Claude Code** (IA): la app lo lanza solo cuando hay trabajo aprobado. Abre tu Chrome con Claude in Chrome, analiza, redacta, envía y deja registro en archivos.

La app nunca escribe propuestas y Claude nunca decide cuándo buscar. Se comunican por archivos en la carpeta de datos.

## Capas

```
┌──────────────────────────────────────────────────┐
│ 1. Hirebar (app)        AppKit                    │  ícono, menú, Telegram setup
├──────────────────────────────────────────────────┤
│ 2. HirebarEngine        sin interfaz              │  radares, programador, comandos,
│                                                   │  cola de lotes, lanzador de Claude
├──────────────────────────────────────────────────┤
│ 3. HirebarSources       un archivo por portal     │  Workana, Freelancer, LinkedIn,
│                                                   │  Get on Board, Computrabajo…
│                                                   │  + clasificadores
├──────────────────────────────────────────────────┤
│ 4. HirebarCore          sin interfaz              │  rutas, config, perfil, lotes,
│                                                   │  cupos, métricas, Telegram, red
└──────────────────────────────────────────────────┘
```

Cada capa solo usa las de abajo y `Package.swift` lo hace cumplir. Las capas 2, 3 y 4 solo usan Foundation, así que se pueden compilar y probar sin abrir la app.

## Flujo de un aviso

```
Radar (cada 20–30 min)
  └─ ListingSource.search()  → hits por portal
  └─ clasificador + revisión de la descripción
  └─ Batch "pendiente" en lotes.json
  └─ Notifier → Telegram con botones Sí / No
        └─ "si" (o envío automático)
              └─ Controller → cola → claude -p --chrome
                    con instrucciones-<modo>.md como system prompt
              └─ Claude envía, registra y responde
        └─ la respuesta de Claude llega a Telegram
```

## Agentes

Hirebar está dividido en agentes independientes. Cada uno tiene su archivo `workspace/agentes/<id>.json` con su horario, su envío automático y sus tareas, y se prende o apaga sin afectar a los demás.

| Agente | Qué hace | Ritmo por defecto |
|---|---|---|
| Empleo | busca vacantes, postula y revisa publicaciones en redes | búsqueda cada 30 min · redes cada 2 h de 8 a. m. a 8 p. m. |
| Freelance | busca proyectos, envía propuestas y hace seguimientos | búsqueda cada 20 min · seguimientos 10 a. m. y 4 p. m. |
| Clientes | busca empresas y negocios y les escribe por correo | lunes a viernes, 7 a. m. |
| Contenido | prepara publicaciones; nada se publica sin aprobación | martes y jueves, 9 a. m. |
| Perfil | actualiza el perfil y regenera las hojas de vida | cuando se lo pides |
| Analista | análisis semanal con las métricas de cada agente | domingo, 6 p. m. |

Ejemplo de `agentes/clientes.json`:

```json
{
  "id": "clientes",
  "name": "Clientes",
  "enabled": true,
  "autoApprove": true,
  "dailyLimit": 10,
  "tasks": [
    { "mode": "prospeccion", "hours": [7], "days": ["habiles"], "windowHours": 12 }
  ]
}
```

- `hours`: horas de inicio (0–23). `days`: `todos`, `habiles` o días (`lun`, `mar`, `mie`, `jue`, `vie`, `sab`, `dom`). `windowHours`: cuántas horas después todavía puede correr si el Mac estaba dormido.
- `searchEveryMinutes` (Empleo y Freelance): cada cuánto busca en los portales.
- `autoApprove`: actúa sin esperar tu "si". `dailyLimit`: cupo diario que se le indica a Claude.
- Los campos que faltan usan el valor por defecto.

Los agentes buscan y programan por su cuenta, pero Claude atiende un trabajo a la vez, porque todos usan el mismo Chrome. Los trabajos esperan en una cola.

## Modos

Cada tarea de un agente es un modo con su playbook `instrucciones-<modo>.md` en la carpeta de datos.

| Modo | Cuándo corre | Qué hace Claude |
|---|---|---|
| `freelance` | lista aprobada | analiza la competencia y envía propuestas |
| `empleo` | lista aprobada | revisa cada vacante y postula |
| `seguimiento` | 10 a. m. y 4 p. m. | revisa lecturas y respuestas, un seguimiento por propuesta |
| `redes` | cada 2 h de 8 a. m. a 8 p. m. | busca vacantes publicadas en redes |
| `prospeccion` | lunes a viernes, 7 a. m. | arma la lista de correos del día |
| `prospeccion-envio` | "envia correos" o envío automático | envía los correos aprobados |
| `linkedin-borrador` | martes, 9 a. m. | escribe un borrador de publicación |
| `linkedin-publicar` | "publica" | publica el borrador aprobado |
| `semanal` | domingo, 6 p. m. | análisis semanal (no cambia nada) |
| `perfil` | `logro`, `trabajo` o `hv` | actualiza `perfil.json` y `perfil.md` y escribe una hoja de vida HTML por variante; la app crea los PDF |

## Carpeta de datos

`~/Library/Application Support/Hirebar/` (se puede cambiar con la variable `HIREBAR_HOME`):

```
config.json                 interruptores, chat de Telegram, envío automático, tu nombre
workspace/                  carpeta de trabajo de Claude
├── agentes/                un archivo por agente: horario, envío automático y tareas
├── perfil.json             tu experiencia, logros, habilidades con nivel y variantes de HV
├── perfil.md               lo mismo en texto, para las demás tareas
├── hv/                     plantilla y HTML de cada hoja de vida (los PDF quedan en workspace/)
├── perfil-cambios.txt      pedidos de logro o trabajo pendientes de aplicar
├── search-profile.json     palabras de búsqueda y descartes de cada radar
├── instrucciones-*.md      un playbook por modo
├── lotes.json              avisos y su estado (14 días)
├── cupos.json              contactos de Workana y ofertas de Freelancer
├── seguimiento.json        propuestas enviadas y su estado
├── historial-propuestas.md, postulaciones.md
├── metricas-radar.json     lo que cuenta la app
├── metricas-claude.json    lo que cuenta Claude
├── ejecuciones/            salida de cada corrida de Claude (30 días)
├── informes/, prospeccion/, linkedin/
```

Los nombres de los archivos de datos están en español porque los leen y escriben los playbooks.

## Perfil y habilidades

Los radares usan `search-profile.json` ampliado con las habilidades de `perfil.json`:

| Nivel | Freelance | Empleo |
|---|---|---|
| `domino` | suma a `strong` | suma a `strong` y `ownStack` |
| `conozco` | suma a `stretch` | suma a `weak` (queda como RETO) |
| `evito` | suma a `titleBlocked` y sale de las demás | suma a `blocked` y sale de las demás |

Cambiar una habilidad (`habilidad Go conozco`) no necesita a Claude ni recompilar: aplica desde la búsqueda siguiente.

## Limpieza automática

Cada domingo después del informe: ejecuciones de más de 30 días, informes de más de un año, propuestas cerradas de más de 90 días, métricas de más de 26 semanas, y recorte de los historiales cuando pasan de 3 MB.
