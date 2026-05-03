# Patrones regex bilingües (ES / EN)

Fuente única para todos los patrones del skill. Los scripts en `scripts/` leen estos patrones desde aquí (vía variables de entorno) o los hardcodean si son críticos. Este archivo documenta el contrato.

## Capítulos

```
ES_CHAPTER='^(#+[[:space:]]*)?(Cap[íi]tulo|CAP[ÍI]TULO)[[:space:]]+([0-9IVXLCDM]+|[A-Za-zÀ-ÿ]+)'
EN_CHAPTER='^(#+[[:space:]]*)?(Chapter|CHAPTER)[[:space:]]+([0-9IVXLCDM]+|[A-Za-z]+)'
ANY_CHAPTER='^(#+[[:space:]]*)?(Cap[íi]tulo|Chapter|CAP[ÍI]TULO|CHAPTER)[[:space:]]+'
```

Acepta numerales arábigos (1, 2), romanos (I, II), o escritos (Uno, One). Soporta encabezados Markdown (`#`, `##`).

## Marcadores temporales

### Español

```
ES_TIME_RELATIVE='(hace|hacía)[[:space:]]+([a-z0-9]+)[[:space:]]+(años?|meses?|semanas?|días?|horas?)|([a-z0-9]+)[[:space:]]+(años?|meses?|semanas?|días?|horas?)[[:space:]]+(después|antes|atrás|más tarde)'

ES_TIME_ABSOLUTE='en[[:space:]]+(el[[:space:]]+año[[:space:]]+)?[0-9]{4}|[0-9]{1,2}[[:space:]]+de[[:space:]]+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)'

ES_TIME_DAYS='(lunes|martes|miércoles|miercoles|jueves|viernes|sábado|sabado|domingo)'

ES_TIME_NEXT='al día siguiente|esa (mañana|tarde|noche)|aquella (mañana|tarde|noche)|la (siguiente|próxima) (mañana|tarde|noche)'

ES_TIME_AGE='(tenía|tenia|tiene)[[:space:]]+([0-9]+)[[:space:]]+años|de[[:space:]]+([0-9]+)[[:space:]]+años|cumplió[[:space:]]+([0-9]+)'

ES_SEASON='(invierno|primavera|verano|otoño|otono)'

ES_HEDGE='(creo|me parece|como|más o menos|tal vez|quizá|quizás)'
```

### Inglés

```
EN_TIME_RELATIVE='(two|three|four|five|six|seven|eight|nine|ten|[0-9]+)[[:space:]]+(years?|months?|weeks?|days?|hours?)[[:space:]]+(later|ago|before|after)'

EN_TIME_ABSOLUTE='in[[:space:]]+(the[[:space:]]+year[[:space:]]+)?[0-9]{4}|(january|february|march|april|may|june|july|august|september|october|november|december)[[:space:]]+[0-9]{1,2}'

EN_TIME_DAYS='(monday|tuesday|wednesday|thursday|friday|saturday|sunday)'

EN_TIME_NEXT='next[[:space:]]+(morning|day|week|month|year)|that[[:space:]]+(morning|afternoon|evening|night)|the[[:space:]]+(following|previous)[[:space:]]+(day|week|month|year)'

EN_TIME_AGE='(was|is|been)[[:space:]]+([0-9]+)[[:space:]]+years[[:space:]]+old|aged[[:space:]]+([0-9]+)|turned[[:space:]]+([0-9]+)'

EN_SEASON='(winter|spring|summer|autumn|fall)'

EN_HEDGE='(I think|maybe|perhaps|kind of|sort of)'
```

## Dialog tags

```
ES_DIALOG='—[a-záéíóúñ]+[[:space:]]+([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)|dijo[[:space:]]+([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)|preguntó[[:space:]]+([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)|respondió[[:space:]]+([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)|susurró[[:space:]]+([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)|gritó[[:space:]]+([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)|exclamó[[:space:]]+([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)'

EN_DIALOG='([A-Z][a-z]+)[[:space:]]+(said|asked|whispered|shouted|yelled|replied|murmured|exclaimed)|"[^"]*",?[[:space:]]+([A-Z][a-z]+)[[:space:]]+(said|asked)'
```

## Atributos físicos

### Edad
```
ES_AGE='(tenía|tiene)[[:space:]]+([0-9]+)[[:space:]]+años|de[[:space:]]+([0-9]+)[[:space:]]+años|cumplió[[:space:]]+([0-9]+)|recién[[:space:]]+cumplidos[[:space:]]+([0-9]+)'
EN_AGE='(was|is)[[:space:]]+([0-9]+)[[:space:]]+years[[:space:]]+old|aged[[:space:]]+([0-9]+)|turned[[:space:]]+([0-9]+)'
```

### Ojos
```
ES_EYES='ojos[[:space:]]+(verdes|azules|negros|marrones|castaños|grises|color[[:space:]]+[a-z]+)'
EN_EYES='(green|blue|black|brown|hazel|grey|gray)[[:space:]]+eyes'
```

### Pelo
```
ES_HAIR='(pelo|cabello|melena)[[:space:]]+(rubio|moreno|negro|castaño|pelirrojo|cano|gris|corto|largo|rizado|liso|ondulado)'
EN_HAIR='(blonde|brown|black|red|grey|gray|short|long|curly|straight|wavy)[[:space:]]+hair'
```

### Altura
```
ES_HEIGHT='([0-9]+\.?[0-9]*)[[:space:]]+(metros|cm|centímetros)|(alto|alta|bajo|baja|menudo|menuda)'
EN_HEIGHT='([0-9]+\.?[0-9]*)[[:space:]]+(feet|ft|inches|in|cm)|(tall|short|petite)'
```

## Relaciones

```
ES_RELATION='su[[:space:]]+(madre|padre|hermano|hermana|hijo|hija|tío|tía|primo|prima|abuelo|abuela|esposo|esposa|marido|mujer)[[:space:]]+([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)'

EN_RELATION='(his|her)[[:space:]]+(mother|father|brother|sister|son|daughter|uncle|aunt|cousin|grandfather|grandmother|husband|wife)[[:space:]]+([A-Z][a-z]+)'
```

## Promesas / planes

```
ES_PROMISE='(prometió|juró|se prometió|decidió que|se juró)|voy a|algún día|cuando vuelva|cuando regrese|en cuanto pueda'

EN_PROMISE='(promised|swore|vowed|decided to)|(I.ll|I will)|someday|when I return|as soon as'
```

## Preguntas abiertas (epistémicas)

```
ES_QUESTION='¿(qué|quién|cuándo|dónde|por qué|cómo)[[:space:]]+(será|sería|habrá|hizo|haría|estaba|estará)[^?]*\?'

EN_QUESTION='(what|who|when|where|why|how)[[:space:]]+(will|would|could|did|had|was|is)[^?]*\?'
```

## Stopwords capitalizadas (filtrar de extracción de entidades)

```
ES_STOPWORDS='Y|O|El|La|Los|Las|Un|Una|Pero|Que|Como|Si|No|Cuando|Donde|Mientras|Aunque|Porque|Aún|Aun|Más|Mas|Todo|Toda|Todos|Todas|Entonces|Después|Antes|Hoy|Ayer|Mañana|Eso|Esto|Aquello|Ese|Este|Aquel|Esa|Esta|Aquella'

EN_STOPWORDS='The|And|Or|But|If|When|Where|While|He|She|It|They|This|That|These|Those|Then|After|Before|Today|Yesterday|Tomorrow|Yes|No|Maybe|However|Although|Because|Though'
```

## Notas para shells

`grep -E` (POSIX ERE) y `rg` (PCRE-lite) aceptan estos patrones. Para `awk`, usa `--posix` si fallan. Para SQLite FTS5, los patrones de tokenización son distintos — FTS5 usa booleanos (AND/OR/NEAR) sobre palabras tokenizadas, no regex.

`[[:space:]]` en lugar de `\s` por portabilidad macOS BSD grep. Para detectar tildes españolas usa el rango `À-ÿ` o clases POSIX `[[:upper:]]` con locale UTF-8 activo:

```bash
LC_ALL=en_US.UTF-8 grep -E "$PATTERN"
```

## Mantenimiento

Cuando agregues un nuevo patrón:
1. Documenta aquí con ES + EN cuando aplique
2. Etiqueta el regex con su variable (`ES_X` / `EN_X`)
3. Actualiza el script que lo consume — referencia este archivo en su comentario inicial
4. Nunca dupliques regex en otro archivo del skill
