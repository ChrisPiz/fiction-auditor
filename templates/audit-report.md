# Auditoría de continuidad — {{TITULO_MANUSCRITO}}

**Manuscrito:** `{{SOURCE_PATH}}`
**Generado:** {{TIMESTAMP}}
**Stats:** {{WORDS}} palabras · {{CHAPTERS}} capítulos · idioma {{LANG}}

---

## Resumen ejecutivo

- **Hallazgos HARD (incompatibles):** {{HARD_COUNT}}
- **Hallazgos SOFT (compatibles con cambio):** {{SOFT_COUNT}}
- **Drifts (variación menor de descripción):** {{DRIFT_COUNT}}
- **Hilos abiertos sin resolver:** {{UNRESOLVED_THREADS}}
- **Marcadores temporales detectados:** {{TIMELINE_MARKERS}}

---

## ⚠️ Inconsistencias HARD

> Contradicciones que el manuscrito no puede sostener simultáneamente. Revisar antes de pulir.

### {{ENTIDAD}} — atributo: {{ATRIBUTO}}

**Cita A — {{CHAPTER_A}}, línea {{LINE_A}}**
> {{TEXT_A}}

**Cita B — {{CHAPTER_B}}, línea {{LINE_B}}**
> {{TEXT_B}}

**Análisis:** {{ANALYSIS}}

---

## 🟡 Inconsistencias SOFT

> Valores distintos pero coherentes con paso de tiempo o cambio de circunstancias. Verificar intención.

### {{ENTIDAD}} — atributo: {{ATRIBUTO}}

| Cita | Cap | Línea | Valor |
|---|---|---|---|
| A | {{CAP_A}} | {{L_A}} | {{V_A}} |
| B | {{CAP_B}} | {{L_B}} | {{V_B}} |

**Δt narrativo entre citas:** {{DELTA_T}}

---

## 🔵 Drifts descriptivos

> Variaciones menores en la descripción de un mismo elemento. Pueden ser deliberadas o ruido.

| Entidad | Atributo | Variantes | Capítulos |
|---|---|---|---|
| {{ENTITY}} | {{ATTR}} | {{VARIANTS}} | {{CHAPTERS}} |

---

## 🧵 Hilos sin resolver

### Promesas

| Cap | Línea | Promesa | Confianza de falta de cierre |
|---|---|---|---|
| {{CAP}} | {{LINE}} | {{TEXT}} | {{CONFIDENCE}} |

### Preguntas abiertas

| Cap | Línea | Pregunta | Confianza de falta de cierre |
|---|---|---|---|
| {{CAP}} | {{LINE}} | {{TEXT}} | {{CONFIDENCE}} |

### Personajes huérfanos

| Cap | Línea | Personaje | Notas |
|---|---|---|---|
| {{CAP}} | {{LINE}} | {{NAME}} | freq baja, dialog tag detectado |

### Objetos no disparados (Chekhov's gun)

| Cap | Línea | Objeto | Descripción |
|---|---|---|---|
| {{CAP}} | {{LINE}} | {{OBJECT}} | {{DESC}} |

---

## ⏰ Cronología

### Marcadores anclados

```
{{ANCHOR_CHAIN}}
```

### Conflictos cronológicos detectados

| Cap | Línea | Marcador | Conflicto |
|---|---|---|---|
| {{CAP}} | {{LINE}} | {{MARKER}} | {{CONFLICT}} |

---

## Limitaciones de esta auditoría

- Sin coreference: pronombres ("ella", "él") no se asocian a entidades
- Inconsistencias implícitas (subtexto, tono) no detectadas
- Prosa metafórica puede generar falsos positivos
- No reemplaza editor humano de desarrollo

---

## Próximos pasos sugeridos

1. Resolver HARDs antes de pulir
2. Confirmar SOFTs (¿deliberados?). Si sí, registrar en `exceptions.tsv`
3. Cerrar o marcar como deliberados los hilos sin resolver
4. Releer escenas de drift descriptivo y unificar si no son intencionales
5. Verificar conflictos cronológicos contra la línea narrativa interna
