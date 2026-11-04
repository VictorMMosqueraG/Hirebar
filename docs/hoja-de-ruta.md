# Hoja de ruta

Objetivo: que Hirebar se mejore editando archivos y ajustes, no código. El código sabe *hacer*; tu perfil, los portales, los cazadores y los playbooks dicen *qué* hacer.

```
                    ┌──────────── PERFIL (perfil.json) ────────────┐
                    │ datos · experiencia · logros · habilidades    │
                    │ con nivel · preferencias · hojas de vida      │
                    └───┬──────────┬──────────┬──────────┬─────────┘
                        ▼          ▼          ▼          ▼
                     EMPLEO    FREELANCE   CLIENTES   CONTENIDO
                   (portales  (portales   (negocios   (Instagram de
                    de empleo) freelance)  sin web o   la empresa y
                                           web mala)   LinkedIn personal)
                        └──────────┴────┬─────┴──────────┘
                                        ▼
        buscar → filtrar → avisar → Claude actúa → registrar → seguimiento → informe
```

## Fase 1 — Perfil único y hojas de vida (hecha en 0.2.0)

- `perfil.json` es la fuente única: experiencia, logros con tecnologías, habilidades con nivel (`domino`, `conozco`, `evito`), preferencias y variantes de hoja de vida.
- Las habilidades amplían las palabras de búsqueda y los filtros de los radares: `domino` → ENCAJA, `conozco` → RETO, `evito` → se descarta.
- Telegram: `logro …`, `trabajo …`, `habilidad <nombre> <nivel>`, `habilidades`, `hv`.
- Claude actualiza `perfil.json` y `perfil.md` y escribe una hoja de vida HTML por variante. La app crea los PDF con Chrome sin ventana y te los manda por Telegram.
- Una variante nueva (por ejemplo, Cloud/DevOps) es un elemento más en `cvVariants`.

## Fase 2 — Contenido para redes

Publicaciones para traer clientes y visibilidad, no solo sobre tu perfil.

- **Canales** en `contenido/canales.json`: Instagram de la empresa y LinkedIn personal, cada uno con su objetivo, tono, días y horas.
- **Qué publicar:** Claude revisa cada semana qué está funcionando (fechas y eventos de la semana, temas en tendencia, y alcance de las publicaciones anteriores mirando las estadísticas en tu Chrome). Con eso arma un calendario en `contenido/calendario.md`.
- **Pilares de ejemplo para la empresa:** antes y después de páginas web, tips para negocios, casos reales, mitos sobre software a medida y ofertas. **Para LinkedIn:** logros técnicos sacados de `perfil.json`, lecciones y proyectos.
- **Piezas:** texto y carrusel. Claude diseña cada lámina en HTML de 1080×1350 y la app la convierte en PNG con Chrome sin ventana, igual que los PDF de la HV.
- **Aprobación:** te llegan a Telegram con `publica ig 1`, `publica li 2`, `cambia 1 <qué>` o `salta`. Con tu aprobación, Claude publica desde tu Chrome y registra el resultado.
- **Informe:** alcance y mensajes recibidos por publicación, con su efecto en el plan de la semana siguiente.

## Fase 3 — Portales como archivos y ventana de Ajustes

- Cada portal es un archivo en `portales/<id>.json` con su tipo:
  - **api**: URL pública con `{busqueda}` y dónde están el título, el enlace y la fecha.
  - **pagina**: lista HTML pública y cómo reconocer cada oferta.
  - **claude**: solo nombre y URL; Claude busca con tu Chrome (Indeed, Torre, Hireline, Upwork…).
- Los portales actuales siguen como adaptadores en Swift; los nuevos casi siempre bastan como `claude` o `api`.
- Ventana de Ajustes como la de Gatebar: Perfil, Habilidades, Hojas de vida, Portales (agregar, apagar, probar), Cazadores (horario, envío automático y cupo diario) y Telegram.

## Fase 4 — Cazador de clientes

- **Negocios sin página:** por ciudad y categoría con OpenStreetMap (gratis y permitido; muestra si el negocio tiene web), completado con búsqueda web. Google Maps no se lee directo porque sus términos no lo permiten.
- **Negocios con página mejorable:** Claude revisa velocidad en celular, diseño adaptable, https, formulario o WhatsApp y si la información está desactualizada, y deja un diagnóstico corto.
- Correo concreto con el problema y la mejora; solo contactos públicos, línea para darse de baja y nunca empresas de tu hoja de vida.
- Los mejores "antes y después" alimentan la fase 2.

## Fase 5 — Registro único de oportunidades

- Empleo, freelance, clientes y contenido comparten un modelo: tipo, portal o canal, estado, fechas, texto enviado y respuesta.
- Reemplaza `postulaciones.md`, `historial-propuestas.md`, `seguimiento.json` y `lotes.json` con migración de lo existente.
- Métricas comparables por portal, por variante de hoja de vida y por canal de contenido.

## Carpeta de datos al terminar

```
Hirebar/
├── config.json
└── workspace/
    ├── perfil.json · perfil.md · hv/
    ├── portales/      un archivo por portal
    ├── cazadores/     empleo · freelance · clientes · contenido
    ├── contenido/     canales · calendario · piezas
    ├── instrucciones-*.md
    └── datos/         oportunidades · cupos · métricas
```
