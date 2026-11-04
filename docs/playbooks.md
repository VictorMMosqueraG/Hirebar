# Playbooks

Un playbook es el archivo `instrucciones-<modo>.md` que Hirebar le pasa a Claude Code como instrucciones de sistema en cada corrida. Viven en la carpeta de datos, no en el código, así que puedes ajustarlos sin recompilar.

La primera vez que abres Hirebar se copian los de [playbooks/](../playbooks) si no existen. Después son tuyos: Hirebar nunca los sobrescribe.

## Lo que la app espera de Claude

- **Respuesta final** en texto plano: va directo a tu Telegram.
- **`SIN_NOVEDADES`** como primera línea en `seguimiento` y `redes` cuando no hubo nada: la app no te molesta.
- **`prospeccion/pendientes.json`** con `correos` numerados (`n`). Los de tipo `RESPUESTA` nunca se envían solos.
- **`cupos.json`** actualizado con lo que muestra cada plataforma, para no buscar donde ya no quedan contactos.
- **`hv/<id>.html`** por cada elemento de `cvVariants` en la tarea `perfil`. La app los convierte en `<file>.pdf` con Chrome sin ventana y borra `perfil-cambios.txt` si todo salió bien.
- **`metricas-claude.json`** por semana ISO (`AAAA-SNN`) y sección (`freelance`, `empleo`, `prospeccion`).

## Herramientas que tiene Claude

`Read`, `Write`, `Edit`, `Glob`, `Grep`, `WebFetch`, `WebSearch` y Claude in Chrome. No tiene terminal. Corre con la carpeta `workspace/` como directorio de trabajo y se detiene a la hora.
