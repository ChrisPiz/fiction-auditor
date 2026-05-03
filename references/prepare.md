# Preparación del manuscrito

Carga este módulo cuando ejecutes `scripts/prepare.sh` o necesites debuggear conversión.

## Workspace por hash

Cada manuscrito vive en su propio workspace para evitar colisiones cuando el usuario audita varias novelas.

```bash
SRC="RUTA_ORIGINAL"
HASH=$(printf '%s' "$SRC" | shasum -a 1 | cut -c1-12)
WORK="/tmp/narrative-continuity/$HASH"
```

`/tmp` se borra al reiniciar macOS. Si el usuario va a auditar a lo largo de varios días, sugiérele mover `$WORK` a `~/.narrative-continuity/$HASH` (mismo layout, sin reescribir scripts — son agnósticos del path base).

## Reuso vs reconvertir

```bash
if [ -f "$WORK/manuscript.txt" ] && [ "$WORK/manuscript.txt" -nt "$SRC" ]; then
  REUSE=1
fi
```

`-nt` (newer than) compara mtime. Si el original cambió, re-convierte y re-indexa. El script `prepare.sh` también persiste el hash SHA256 del contenido en `meta.json` para detectar cambios que no muevan mtime (raro pero posible).

## Conversión por formato

### `.txt` `.md`
Copia directa.

### `.docx` — preferir pandoc
```bash
pandoc "$SRC" -t plain -o "$WORK/manuscript.txt"
```

Fallback `python-docx`:
```bash
python3 -c "from docx import Document; import sys; doc=Document(sys.argv[1]); print('\n'.join(p.text for p in doc.paragraphs if p.text.strip()))" "$SRC" > "$WORK/manuscript.txt"
```

Si nada está disponible, **NO instales en silencio**. Pregunta:

> "Para convertir `.docx` necesito uno de:
> - `brew install pandoc` (recomendado, una sola vez)
> - `pip install --user python-docx`
>
> ¿Cuál prefieres? O exporta a `.txt` desde Word y vuelve a apuntarme."

### `.rtf`
```bash
pandoc "$SRC" -t plain -o "$WORK/manuscript.txt"
```

Fallback macOS nativo:
```bash
textutil -convert txt "$SRC" -output "$WORK/manuscript.txt"
```

### Carpeta
Concatena en orden alfabético con marcadores `=== filename ===` entre archivos. El script `prepare.sh` maneja el bucle con detección de extensión por archivo.

## Detección de idioma

Heurística simple: cuenta palabras función ES vs EN en las primeras 1000 líneas.

```bash
ES=$(head -1000 "$WORK/manuscript.txt" | grep -ciwE "(el|la|que|de|en|los|las|por|con|para|una|uno|pero|sus)")
EN=$(head -1000 "$WORK/manuscript.txt" | grep -ciwE "(the|and|of|to|in|that|it|with|for|was|but|his|her)")
LANG=$([ "$ES" -gt "$EN" ] && echo "es" || echo "en")
```

Guarda en `$WORK/meta.json`. Los scripts de extracción lo leen para escoger regex.

## Aviso de tamaño

Si `wc -w` > 150000 o `du -k` > 1000:

> "Manuscrito grande (X palabras). Modo conservador activado:
> - Nunca leeré el archivo completo
> - Búsquedas vía SQLite FTS5 (sub-ms)
> - Si pides 'todas las menciones de Y' y hay >50, te muestro 30 + count y ofrezco filtrar
> - Para auditoría holística, considera particionar por arco — puedo orquestar subagentes paralelos"

## Verificación final

Tras conversión, reporta en una sola pasada (no llames 4 comandos separados):

```bash
WORDS=$(wc -w < "$WORK/manuscript.txt" | tr -d ' ')
CHAPTERS=$(wc -l < "$WORK/chapters.tsv" | tr -d ' ')
SIZE_KB=$(du -k "$WORK/manuscript.txt" | cut -f1)
LANG=$(jq -r .lang "$WORK/meta.json" 2>/dev/null || echo "?")
FIRST3=$(head -3 "$WORK/chapters.tsv")
printf '✓ Manuscrito listo: %s palabras, %s capítulos, %s KB, idioma=%s\nPrimeros 3:\n%s\n' \
  "$WORDS" "$CHAPTERS" "$SIZE_KB" "$LANG" "$FIRST3"
```

## Errores comunes

- **`.docx` corrupto** → pandoc falla con "couldn't unzip". Pide al usuario re-exportar desde Word.
- **`.pages`** → no soportado nativo. Pide exportar a Word/PDF.
- **PDF** → no soportado en v1. Explica que OCR/extracción de PDF tiene demasiada pérdida para auditoría con citas exactas. Pide formato editable.
- **Encoding raro** (Latin-1, Mac OS Roman) → `iconv -f LATIN1 -t UTF-8` antes de procesar. Detecta con `file -I "$SRC"`.
