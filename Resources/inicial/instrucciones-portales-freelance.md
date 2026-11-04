# Reglas: revisar los portales que agregó la persona (proyectos freelance)

La persona agregó estos portales desde Ajustes. Tu trabajo es **encontrar** proyectos freelance recientes que encajen con ella y dejarlos anotados. **No postules, no envíes propuestas ni escribas a nadie**: la app le muestra la lista en Telegram y, cuando la apruebe, otra tarea hace el envío.

## Antes de empezar
- Lee `perfil.md` (experiencia y habilidades), `search-profile.json` (qué se descarta) y las reglas de descarte de `instrucciones-freelance.md`.
- Lee `historial-propuestas.md` para no repetir lo que ya se envió.

## En cada portal
1. Abre la URL con Claude in Chrome usando la sesión de la persona. Si pide iniciar sesión o un CAPTCHA, sáltalo y dilo en la respuesta final. Nunca escribas contraseñas.
2. Si hay "Indicaciones", síguelas (por ejemplo, un filtro o una sección).
3. Revisa solo lo publicado en los últimos 24 horas.
4. Abre cada oferta que parezca encajar y lee la descripción. Descarta con las mismas reglas de `instrucciones-freelance.md` (idioma, modalidad, años, tecnologías que la persona evita, presupuesto).
5. Máximo 8 hallazgos en total, primero los que mejor encajan.

## Archivo de salida
Escribe `portales-hallazgos.json` (sobrescribe) como una lista:
```json
[
  {"id": "identificador o URL", "portal": "Nombre del portal", "titulo": "Título de la oferta",
   "url": "https://enlace-directo-a-la-oferta", "detalle": "empresa o cliente · hace 3 h · salario o presupuesto",
   "encaje": "ENCAJA"}
]
```
- `encaje`: "ENCAJA" si es del fuerte de la persona; "RETO" si es cercano pero no su base.
- `url` debe ser el enlace directo a la oferta, no al listado.
- Si no encontraste nada, no crees el archivo.

Cierra las pestañas que abriste.

## Respuesta final (va a Telegram)
- Si no hubo nada nuevo, responde exactamente: SIN_NOVEDADES
- Si hubo, una línea por portal: nombre · cuántas ofertas viste · cuántas anotaste · problemas (sesión, CAPTCHA).
