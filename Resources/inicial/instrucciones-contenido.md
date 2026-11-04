# Reglas: publicación con imágenes para LinkedIn

Preparas UNA publicación para el LinkedIn de la persona: un texto y de 3 a 6 imágenes (carrusel). NO publiques nada: la persona la aprueba desde Telegram.

## 1. El tema NO es la persona
- No hables de su hoja de vida, sus empleos, sus clientes, sus logros ni sus cifras. No leas `perfil.md` ni `perfil.json` para buscar tema; de ahí solo puedes tomar su nombre para la firma de las imágenes.
- La publicación tiene que servirle a quien la lee: dueños de negocio, emprendedores y otros desarrolladores. Así trae visibilidad y clientes sin parecer una hoja de vida.
- Rota entre estos tipos de tema (el que menos se haya usado va primero):
  1. Consejos de tecnología para negocios y pymes (qué automatizar, cuándo conviene un sistema a medida, cómo no perder datos, cuánto cuesta de verdad una app).
  2. Mitos y verdades del software (por ejemplo, "una web cuesta lo mismo que una app", "la nube siempre sale más barata").
  3. Noticias o tendencias de tecnología de la semana. Búscalas con WebSearch, que sean de los últimos 7 días, y explica en palabras sencillas qué significan para un negocio. No inventes datos: si citas una cifra, que salga de lo que encontraste.
  4. Buenas prácticas para desarrolladores: backend, APIs, bases de datos, nube, seguridad, costos.
  5. Errores comunes que le cuestan plata a una empresa y cómo evitarlos.
  6. Preguntas que un negocio debe hacer antes de contratar un desarrollo.
- Antes de escoger, mira `linkedin/temas.md` y no repitas un tema de las últimas 8 publicaciones. Al terminar, agrega una línea arriba: `AAAA-MM-DD · <tipo> · <tema>`.

## 2. Texto (`linkedin/borrador.md`)
- Entre 120 y 200 palabras, en español y con palabras sencillas.
- Primera línea: un gancho corto (una pregunta, un dato o una frase que choque).
- Después, 3 a 5 ideas cortas y prácticas. Termina con una pregunta para que la gente comente.
- Sin emojis y máximo 3 hashtags al final.
- Guarda solo el texto que se publicaría.

## 3. Imágenes (`linkedin/laminas/`)
- Un archivo HTML por imagen: `lamina-1.html`, `lamina-2.html`… (de 3 a 6).
- Cada una mide EXACTAMENTE 1080×1350 px: `html, body { margin: 0; width: 1080px; height: 1350px; overflow: hidden; }`.
- Todo dentro del archivo: CSS en `<style>`, íconos o dibujos en SVG escrito a mano. Nada de imágenes de internet, fotos, logos de marcas ni fuentes externas. Usa fuentes del sistema: `-apple-system, "Helvetica Neue", Arial, sans-serif`.
- Estructura:
  - Lámina 1: portada con el gancho en letra grande.
  - Láminas del medio: una idea por lámina, con un título corto y máximo 30 palabras.
  - Última lámina: la pregunta del final y la firma.
- Diseño:
  - Texto de 44 px o más (títulos de 72 px o más), buen contraste y márgenes de al menos 80 px.
  - Las mismas dos o tres tonalidades en todas las láminas, con un detalle gráfico (formas, líneas, un ícono SVG).
  - Número de lámina abajo, del tipo "2/5".
  - Firma pequeña en todas: el nombre de la persona y "Software a medida · Backend y nube".
- Revisa que ningún texto se salga ni quede tapado.

## 4. Si hay un cambio pedido
Si el mensaje trae un "Cambio que pidió…", aplícalo sobre el borrador anterior: el texto anterior está en `linkedin/` y las imágenes anteriores en `linkedin/laminas-anteriores/`. Deja la publicación nueva completa, texto e imágenes.

## Respuesta final (va a Telegram)
El texto completo, tal como se publicaría. Hirebar manda las imágenes justo después.
