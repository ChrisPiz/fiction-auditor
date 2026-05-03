# Auditoría de consistencia

Detecta contradicciones explícitas — afirmaciones del manuscrito que se contradicen entre sí. **No infiere contradicciones.** Solo reporta cuando hay dos citas directas que no pueden ser ambas verdad.

## Atributos auditables

Categorías cubiertas por `scripts/audit-attribute.sh`:

| Atributo | Patrón ES | Patrón EN |
|---|---|---|
| edad | `(tenía/tiene) [N] años`, `de [N] años` | `(was/is) [N] years old`, `aged [N]` |
| ojos | `ojos (color)` | `(color) eyes` |
| pelo | `pelo (color/largo)`, `cabello` | `(color/length) hair` |
| altura | `[N] (metros\|cm) de alto`, `alto/alta/bajo/baja` | `[N] (feet\|inches) tall`, `tall/short` |
| profesión | `era (médica\|profesor\|...)` | `was a (doctor\|teacher\|...)` |
| relaciones | `su (madre\|padre\|...) NOMBRE` | `her/his (mother\|father\|...) NAME` |
| ubicación de objeto | `el/la X estaba en` | `the X was in/on` |

Patrones completos en `references/patterns-bilingual.md`.

## Algoritmo

```
1. Para entidad E + atributo A:
2.   FTS5 query: NEAR("E" "patrones de A", 12)
3.   Para cada hit:
4.     extrae el valor del atributo (regex sobre el snippet)
5.     guarda (line, chapter, value, full_quote)
6. Agrupa hits por valor:
7.   Si 2+ valores distintos → contradicción candidata
8.   Verifica que ambos refieran al mismo sujeto (no homónimos)
9.   Reporta con flag de severidad:
       hard:  valores incompatibles (34 vs 36 años en ventana <1 año narrativo)
       soft:  valores compatibles con cambio (28 vs 31 años en saga de 5 años)
       drift: descripción ligeramente distinta (ojos "verdes" vs "azulados")
```

## Salida

```
⚠️ Inconsistencia HARD — atributo: edad de Marta

Cita A — Capítulo 3, línea 245
> "Marta tenía 34 años cuando empezó todo."

Cita B — Capítulo 11, línea 2103
> "Marta acaba de cumplir 36, dijo su madre."

Tiempo narrativo entre citas: ~8 meses (según marcadores en Cap 4-11).
Diferencia: 2 años. Imposible.

🟡 Inconsistencia SOFT — atributo: edad de Marta

Cita A — Capítulo 1, línea 23
> "tenía 28 años recién cumplidos"

Cita B — Capítulo 18, línea 5402
> "—Tengo 31 —dijo Marta."

Tiempo narrativo: ~3 años. Diferencia: 3 años. Coherente.

🔵 Drift — atributo: ojos de Elena

Cita A — Capítulo 4, línea 230
> "los ojos verdes de Elena brillaban"

Cita B — Capítulo 12, línea 412
> "lo miraba con esos ojos azulados, casi grises"

Posible cambio de luz/contexto, o inconsistencia. El escritor decide.
```

## Cross-check con timeline

Para atributos que dependen del tiempo (edad, etapa de vida, embarazo, enfermedad), cruza el `timeline.tsv`:

```bash
bash scripts/audit-attribute.sh "$WORK" "Marta" "edad" --cross-timeline
```

El script:
1. Extrae todos los valores de edad citados
2. Para cada cita, calcula posición temporal vía `timeline.tsv`
3. Verifica que `edad_t1 - edad_t0 ≈ Δt`
4. Marca como `hard` si la diferencia excede un margen razonable (>±1 año)

## Modo auditoría general

```bash
bash scripts/audit-attribute.sh "$WORK" --all
```

Itera sobre todas las entidades en `entities.tsv` con freq ≥ 5 y todos los atributos auditables. Reporta inconsistencias agrupadas por entidad y severidad. Salida en `$WORK/audit-report.md` usando `templates/audit-report.md` como base.

Costo: ~10-30s en manuscrito de 150k palabras.

## Edge cases

- **Cambio deliberado**: personaje envejece, cambia profesión, se tiñe el pelo. El audit no distingue intención. Si el escritor confirma que es deliberado, agrega excepción a `$WORK/exceptions.tsv` (`entity<TAB>attribute<TAB>justification`) y futuras auditorías la respetan.
- **Personajes con mismo nombre**: dos Martas distintas en la novela. El extractor las trata como una. Pide al escritor que las desambigüe (Marta_madre, Marta_hija) en `$WORK/aliases.tsv`.
- **Atributos heredados / metafóricos**: "tenía los ojos de su padre" — se enmascara como atributo. El extractor a veces los captura mal. Marca como soft y deja al escritor.
- **Cambios no físicos**: profesión, residencia, estado civil. El audit los reporta como contradicción "sin verificar trayectoria temporal". El escritor decide si tiene sentido en el arco.

## Falsos positivos comunes

- **Diálogo de personaje no fiable**: si el personaje miente sobre su edad, no es inconsistencia. El extractor no detecta mentira contextual. Reporta y deja al escritor.
- **Recuerdos imprecisos**: "creo que tenía como diez años" vs "cuando tenía nueve" — el primero es estimación, no afirmación. El extractor los marca como `tentative` si detecta hedge ("creo", "como", "más o menos").
- **Cambio de POV**: distintos narradores describen al mismo personaje con énfasis distinto. Los drifts de descripción son esperables. Etiqueta el cambio de POV en el reporte si los capítulos están marcados.

## Limitaciones

- Sin coreference, "él tenía 34" no se asocia a la entidad correcta. El audit pide al usuario confirmar antes de reportar.
- Atributos descritos con metáfora ("tenía la edad del cansancio") quedan fuera.
- No detecta inconsistencias de comportamiento (personalidad, valores). Solo atributos discretos.

Reporta limitaciones al final de cada audit run.
