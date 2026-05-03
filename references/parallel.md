# Subagentes paralelos para auditoría holística

Carga este módulo cuando:
- Manuscrito > 150k palabras
- Saga multi-volumen (carpeta con varios `.md`)
- Usuario pide "auditoría completa" / "audita todo el libro"
- Cross-check de >5 atributos × >5 entidades

## Por qué paralelizar

Tu ventana de contexto no soporta leer 200k palabras + razonar sobre todas a la vez. Particionar el trabajo en subagentes que reportan hallazgos estructurados (TSV/JSON) permite agregar sin saturar tu contexto principal.

**Costo**: cada subagente consume tokens propios. Solo dispara cuando el manuscrito justifica.

## Estrategias de partición

### Por arco / volumen
Mejor para sagas o estructuras tripartitas. Cada subagente recibe un rango de capítulos.

```
Subagente 1: caps 1-7   (acto 1)
Subagente 2: caps 8-15  (acto 2)
Subagente 3: caps 16-22 (acto 3)
```

### Por entidad
Mejor para auditoría enfocada en personajes principales. Cada subagente audita una entidad a través de todo el manuscrito.

```
Subagente 1: Marta — todos los atributos, toda la cronología
Subagente 2: Elena — íbid
Subagente 3: el padre — íbid
```

### Por dimensión
Mejor para auditoría general estructurada.

```
Subagente 1: extract-entities + bible auto-build
Subagente 2: extract-timeline + audit cronológico
Subagente 3: extract-threads + clasificación de hilos
Subagente 4: audit-attribute --all sobre top-10 entidades
```

## Patrón de invocación

Usa el tool `Agent` con `subagent_type=general-purpose`. Cada subagente debe:

1. Recibir ruta `$WORK` y rango / entidad asignada
2. Ejecutar scripts deterministas del skill (no reimplementar)
3. Reportar en TSV o JSON estructurado, NO prosa larga
4. Limitarse a la partición — no leer fuera de su scope

### Prompt template para subagente

```
Eres un subagente del skill trama.

Workspace: /tmp/trama/<HASH>/
Tu scope: <RANGO o ENTIDAD>

Tareas:
1. Lee referencias del skill: <lista de references/*.md relevantes>
2. Ejecuta los scripts indicados sobre tu scope
3. Reporta hallazgos en formato TSV con header

Output esperado:
- Un solo bloque TSV con columnas: type, line, chapter, severity, summary, citation
- Sin prosa adicional fuera del bloque
- Máximo 200 hallazgos. Si hay más, reporta top-200 por severidad.

NO escribas prosa para el escritor. Solo datos estructurados.
NO hagas inferencias sin cita directa.
NO leas el manuscrito completo — usa fts-query.sh y los TSV existentes.
```

### Agregación

Tras todos los subagentes:

1. Recolecta TSVs en `$WORK/findings/`
2. Concatena con `cat *.tsv > $WORK/audit-all.tsv`
3. Deduplica (algunos hallazgos pueden aparecer en partición de arco Y de entidad)
4. Ordena por severidad: hard > soft > drift > info
5. Genera reporte final usando `templates/audit-report.md`

## Decisión: paralelizar sí/no

Heurística:

| Manuscrito | Operación | Decisión |
|---|---|---|
| <50k palabras | cualquiera | inline (sin subagentes) |
| 50-150k | query puntual | inline |
| 50-150k | auditoría completa | 2 subagentes (entidad-cluster + temporal-cluster) |
| 150-500k | query puntual | inline |
| 150-500k | auditoría completa | 3-4 subagentes por dimensión |
| >500k (saga) | cualquiera | 1 subagente por volumen + 1 agregador final |

Pregunta al usuario antes de disparar 4+ subagentes — el costo (tiempo + tokens) es notable.

## Coordinación

Disparar subagentes en **paralelo** (un solo mensaje con N tool calls Agent simultáneos). No serializar — pierdes la ventaja principal.

Mientras corren, prepara el scaffold del reporte agregado para no perder tiempo cuando vuelvan.

## Ejemplo concreto

Usuario: "Audita completa mi novela de 280k palabras."

```
1. Verifica que $WORK existe e índice está construido.
2. Pregunta al usuario:
   "Voy a disparar 4 subagentes paralelos:
    - Entidades + bible
    - Cronología
    - Hilos abiertos
    - Cross-check atributos
   Tiempo estimado 2-4 minutos. ¿Sigo?"
3. Confirma → spawn 4 Agents en un solo mensaje.
4. Mientras corren, prepara scaffold de reporte.
5. Recibe TSVs, agrega, dedupe, ordena.
6. Genera $WORK/audit-report.md y muestra al usuario resumen + ruta.
```

## Tendencias a evitar

- **No serializar subagentes** — paralelo siempre.
- **No pedir prosa al subagente** — solo TSV/JSON. La prosa la escribes tú con la data agregada.
- **No leer el manuscrito completo en el agente principal** — confía en los TSVs reportados por subagentes.
- **No re-disparar subagentes para refinar** — si el primer pase es insuficiente, ajusta scope y re-corre. Iteraciones múltiples queman tokens.

## Si el usuario rechaza paralelo

Algunos usuarios no quieren consumir tokens en subagentes. Plan B: auditoría secuencial dentro del agente principal, scope acotado por dimensión, y reportes parciales conforme avanzas. Más lento, mismo resultado al final.
