# Hirebar

**Tu búsqueda de trabajo, corriendo sola desde la barra de menú.**

Hirebar es una app para la barra de menú de macOS pensada para desarrolladores en Latinoamérica que buscan empleo remoto y proyectos freelance al mismo tiempo. Revisa los portales cada pocos minutos, filtra con tu perfil y te avisa por Telegram. Cuando respondes "si", o si activaste el envío automático, [Claude Code](https://claude.com/claude-code) abre tu Chrome, analiza cada oportunidad, redacta la propuesta o llena la postulación y te cuenta qué hizo.

```
💼 ●
├── Radar freelance: 10:42, 2 avisado(s) · próxima en 18 min   ▸  Workana · Freelancer · cupos
├── Radar empleo: 10:30, nada nuevo · próxima en 6 min          ▸  LinkedIn · Get on Board · Computrabajo · elempleo · Magneto
├── Seguimientos e informe                                      ▸  próximos en 5 h 18 min · informe del domingo
├── Telegram: conectado a tu chat
├── Claude: haciendo 2 propuestas (desde 10:43)
├── Ver registro · Abrir carpeta de datos
├── Abrir al iniciar sesión
└── Salir de Hirebar
```

## Qué hace

- **Radar freelance:** Workana y Freelancer. Prioriza lo reciente y con pocas propuestas, respeta los contactos que te quedan y descarta lo que no es para ti.
- **Radar de empleo:** LinkedIn, Get on Board, Computrabajo, elempleo y Magneto. Antes de avisarte lee la descripción completa y descarta inglés obligatorio, híbrido fuera de tu ciudad, remoto solo para otro país, años de más o stack ajeno.
- **Telegram:** la lista llega numerada con botones *Sí* / *No*. También funcionan `si 1 3`, `estado`, `buscar`, `informe`, `anota …`, `auto si` y otros. Si no configuras Telegram, los avisos llegan por [ntfy](https://ntfy.sh).
- **Claude hace el trabajo pesado:** propuestas con precio según la competencia, postulaciones, seguimientos a las 48 h, prospección por correo, borrador semanal de LinkedIn e informe del domingo con ajustes que apruebas desde el celular.
- **Perfil sin código:** palabras clave, bloqueos, salario mínimo, años máximos y ciudad en `search-profile.json`. Las reglas para Claude están en playbooks Markdown que puedes editar.
- **Todo local:** tus datos viven en tu Mac. El token de Telegram queda en el Llavero.

## Requisitos

- macOS 13 Ventura o superior.
- [Claude Code](https://claude.com/claude-code) instalado y con sesión iniciada (`claude` en la terminal).
- Google Chrome con la extensión Claude in Chrome y tu sesión iniciada en los portales donde quieres que postule.
- Un bot de Telegram (lo creas en 1 minuto con @BotFather).
- Para compilar: Xcode 15 o Swift 5.9+.

## Instalación

```sh
git clone https://github.com/VictorMMosqueraG/Hirebar.git
cd Hirebar
scripts/bundle.sh --install     # compila y abre ~/Applications/Hirebar.app
```

Después:

1. Menú de Hirebar → **Telegram → Configurar bot…**, pega el token y envíale `/start` a tu bot.
2. **Abrir carpeta de datos** → completa `workspace/perfil.md` con tu experiencia real.
3. Ajusta `workspace/search-profile.json` a tu stack (viene con un perfil backend de ejemplo).
4. Activa **Abrir al iniciar sesión**.

### Opciones de `bundle.sh`

| Comando | Qué hace |
|---|---|
| `scripts/bundle.sh` | Arma `dist/Hirebar.app`. |
| `scripts/bundle.sh --install` | Además lo copia a `~/Applications` y lo abre. |
| `scripts/bundle.sh --zip` | Además crea `dist/Hirebar-<versión>.zip` (lo usa el CI al publicar). |

## Configuración

| Archivo | Para qué |
|---|---|
| `config.json` | Portales activos (`sources`), envío automático (`autoFreelance`, `autoJobs`, `autoEmails`), minutos entre búsquedas, tu nombre (`ownerName`), chat de Telegram y tema de ntfy. Casi todo se cambia desde el menú o con comandos de Telegram. |
| `workspace/search-profile.json` | Qué busca y qué descarta cada radar. Si un campo falta, se usa el valor por defecto. |
| `workspace/perfil.md` | Tu experiencia. Claude no inventa nada que no esté aquí. |
| `workspace/instrucciones-*.md` | Un playbook por tarea. Mira [docs/playbooks.md](docs/playbooks.md). |

Todo está en `~/Library/Application Support/Hirebar/`.

### Comandos de Telegram

| Comando | Qué hace |
|---|---|
| `si` · `si 1 3` · `no` | Aprueba toda la lista, solo algunos números, o la descarta. |
| `estado` | Cupos, próximas búsquedas y qué está haciendo Claude. |
| `buscar` · `buscar freelance` · `buscar empleo` | Busca ya. |
| `seguimientos` · `informe` | Corre esas tareas ya. |
| `anota <texto>` | Guarda una nota para el informe del domingo. |
| `post` · `post cambia <qué>` · `post salta` · `publica` | Borrador de LinkedIn. |
| `envia correos` · `envia correos 1 3` · `no correos` | Correos de prospección del día. |
| `auto si` · `auto no` · `auto freelance si` · `auto empleo no` · `auto correos si` | Envío automático sin esperar tu "si". |

## Arquitectura

```
┌──────────────────────────────────────────────────┐
│ 1. Hirebar (app)        AppKit                    │  ícono, menú
├──────────────────────────────────────────────────┤
│ 2. HirebarEngine        sin interfaz              │  radares, horarios, comandos, Claude
├──────────────────────────────────────────────────┤
│ 3. HirebarSources       un archivo por portal     │  Workana, LinkedIn… + filtros
├──────────────────────────────────────────────────┤
│ 4. HirebarCore          sin interfaz              │  config, perfil, lotes, Telegram, red
└──────────────────────────────────────────────────┘
```

```
Sources/
├── Hirebar/            capa 1: main, AppDelegate, StatusMenu, StatusIcon
├── HirebarEngine/      capa 2: FreelanceRadar, JobRadar, Scheduler, Controller, Commands, ClaudeCLI, AgentPrompts
├── HirebarSources/     capa 3: ListingSource, un *Source por portal, FreelanceClassifier, JobScreener
└── HirebarCore/        capa 4: Paths, Config, SearchProfile, Models, BatchStore, Quotas, Metrics, Telegram, Notifier…
playbooks/              instrucciones por defecto para cada tarea de Claude
templates/              perfil.md, search-profile.json y cupos.json iniciales
Tests/                  pruebas de las capas 3 y 4
scripts/                bundle.sh
```

- Todos los portales cumplen el mismo contrato (`ListingSource` o `JobSource`). Agregar uno es un archivo nuevo: [docs/agregar-un-portal.md](docs/agregar-un-portal.md).
- La app solo busca y organiza. Claude solo trabaja cuando hay algo aprobado, con herramientas limitadas (archivos de la carpeta de trabajo, web y Chrome) y un tope de una hora por corrida.
- Si la sesión de Claude Code se vence, las listas no se pierden: quedan pendientes para reintentar y te llega un aviso.

Más detalle en [docs/arquitectura.md](docs/arquitectura.md).

## Uso responsable

Hirebar actúa con tus cuentas y en tu nombre. Revisa los términos de cada portal, mantén `perfil.md` honesto y empieza con el envío automático apagado hasta que confíes en los filtros y en los playbooks. Hirebar nunca resuelve CAPTCHAs ni crea cuentas.

## Desarrollo

```sh
swift build
swift test
shellcheck -s sh scripts/*.sh
```

El código va en inglés y sin comentarios; la documentación va en español. Más detalles en [CONTRIBUTING.md](CONTRIBUTING.md).

## Desinstalar

```sh
pkill -x Hirebar
rm -rf ~/Applications/Hirebar.app ~/Library/Logs/Hirebar
rm -rf ~/Library/Application\ Support/Hirebar      # tus datos: haz una copia antes si los quieres
security delete-generic-password -s Hirebar -a telegram-bot
defaults delete com.vmsoftware.hirebar
```

## Licencia

MIT. Mira [LICENSE](LICENSE).
