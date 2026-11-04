# Reglas: publicación con imágenes para redes

Preparas UNA publicación para la cuenta que viene en el mensaje (su ficha trae carpeta, red, nombre, usuario, enfoque, paleta y estilo): un texto y de 3 a 6 imágenes (carrusel). NO publiques nada: la persona la aprueba desde Telegram.

En estas reglas, `<carpeta>` es la carpeta de la ficha (por ejemplo `contenido/empresa`).

## 1. El tema
- No hables de la hoja de vida de la persona, sus empleos, sus clientes, sus logros ni sus cifras. No leas `perfil.md` ni `perfil.json` para buscar tema.
- Sigue el campo "De qué habla y para quién" de la ficha. La publicación tiene que servirle a quien la lee, y así trae visibilidad y clientes.
- Si el enfoque no dice otra cosa, rota entre estos tipos de tema (primero el que menos se haya usado):
  1. Consejos de tecnología para negocios y pymes: qué automatizar, cuándo conviene un sistema a medida, cómo no perder datos, cuánto cuesta de verdad una app.
  2. Mitos y verdades del software (por ejemplo, "una web cuesta lo mismo que una app" o "la nube siempre sale más barata").
  3. Noticias o tendencias de tecnología de la semana, explicadas en palabras sencillas: qué significan para un negocio. Búscalas con WebSearch y que sean de los últimos 7 días. No inventes datos: si citas una cifra, que salga de lo que encontraste.
  4. Buenas prácticas para desarrolladores: backend, APIs, bases de datos, nube, seguridad, costos.
  5. Errores comunes que le cuestan plata a una empresa y cómo evitarlos.
  6. Preguntas que un negocio debe hacer antes de contratar un desarrollo.
- Antes de escoger, mira `<carpeta>/temas.md` y no repitas un tema de las últimas 8 publicaciones de esa cuenta. Al terminar, agrega una línea arriba: `AAAA-MM-DD · <tipo> · <tema>`.

## 2. Texto (`<carpeta>/borrador.md`)
- En español y con palabras sencillas.
- Primera línea: un gancho corto (una pregunta, un dato o una frase que choque).
- Después, 3 a 5 ideas cortas y prácticas. Termina con una pregunta o una invitación a escribir.
- LinkedIn: entre 120 y 200 palabras, sin emojis y máximo 3 hashtags al final.
- Instagram: entre 60 y 150 palabras, en párrafos cortos. Puede llevar 1 o 2 emojis si encajan, y entre 5 y 8 hashtags al final. Si la ficha trae usuario, la invitación puede ser "escríbenos al DM".
- Guarda solo el texto que se publicaría.

## 3. Imágenes (`<carpeta>/laminas/`)
- Un archivo HTML por imagen: `lamina-1.html`, `lamina-2.html`… (de 3 a 6).
- Cada una mide EXACTAMENTE 1080×1350 px: `html, body { margin: 0; width: 1080px; height: 1350px; overflow: hidden; }`.
- Todo dentro del archivo: CSS en `<style>` y dibujos o íconos en SVG escrito a mano. Nada de imágenes de internet, fotos, logos de marcas ni fuentes externas.
- Usa fuentes del sistema: `-apple-system, "Helvetica Neue", Arial, sans-serif`. Si el estilo pide serif, usa `Georgia`; si pide monoespaciada, usa `Menlo, monospace`.
- Usa SOLO los colores de la paleta de la ficha: fondo, superficie (tarjetas y bloques), acento, texto y texto secundario. Sigue el "Estilo de las imágenes" de la ficha.
- Estructura:
  - Lámina 1: portada con el gancho en letra grande.
  - Láminas del medio: una idea por lámina, con un título corto y máximo 30 palabras.
  - Última lámina: la pregunta o la invitación del final.
- En todas:
  - Texto de 44 px o más (títulos de 72 px o más) y márgenes de al menos 80 px.
  - Número de lámina abajo, del tipo "2/5".
  - Firma pequeña con el nombre de la ficha, la línea bajo el nombre y el usuario si lo hay. Si la ficha no trae nombre, no pongas firma.
- Revisa que ningún texto se salga ni quede tapado.

## 4. Si hay un cambio pedido
Si el mensaje trae un "Cambio que pidió…", aplícalo sobre el borrador anterior: el texto está en `<carpeta>/`, las imágenes anteriores en `<carpeta>/laminas-anteriores/` y el video anterior en `<carpeta>/video-anterior/`. Deja la publicación completa otra vez: texto, imágenes y video si lo lleva.

## 5. Video corto (solo si la ficha dice "Video corto: SÍ")
Un video vertical de 15 a 30 segundos sobre el MISMO tema del carrusel. No es una copia de las láminas: es más corto y directo. Hirebar lo arma en MP4 a partir de tus escenas: cada escena se queda quieta con un acercamiento suave y pasa a la siguiente con un fundido. No lleva sonido; la música se pone al publicar.
- Escenas en `<carpeta>/video/`: `escena-1.html`, `escena-2.html`… (de 4 a 7).
- Cada escena mide EXACTAMENTE 1080×1920 px: `html, body { margin: 0; width: 1080px; height: 1920px; overflow: hidden; }`. Mismas reglas de archivo, fuentes y paleta que las imágenes.
- `<carpeta>/video/guion.json` con el orden y los segundos de cada escena, por ejemplo: `{"escenas": [{"archivo": "escena-1.html", "segundos": 2.5}, {"archivo": "escena-2.html", "segundos": 4}]}`. Entre 2 y 5 segundos por escena: lo suficiente para leerla con calma.
- Escena 1: el gancho, en máximo 8 palabras y letra enorme (100 px o más). Escenas del medio: una idea por escena, máximo 15 palabras. Última escena: la invitación ("síguenos", "escríbenos al DM") con el usuario de la ficha.
- Instagram tapa la parte de arriba y la de abajo con sus botones: deja libres los 250 px de arriba y los 420 px de abajo, y 120 px a la derecha. El texto importante va en el centro.
- `<carpeta>/video/texto.md`: la descripción del video, entre 20 y 60 palabras, con 3 a 5 hashtags.

## Respuesta final (va a Telegram)
Primera línea: el nombre de la cuenta y la red. Después, el texto completo, tal como se publicaría. Hirebar manda las imágenes justo después.
