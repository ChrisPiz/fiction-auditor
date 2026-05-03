# Character Bible — {{TITULO_MANUSCRITO}}

> Generado por narrative-continuity. Editable: añade información que el extractor no detectó, marca aliases en `aliases.tsv`, registra excepciones en `exceptions.tsv`.

**Stats:**
- Palabras: {{WORDS}}
- Capítulos: {{CHAPTERS}}
- Idioma detectado: {{LANG}}
- Generado: {{TIMESTAMP}}

---

## Personajes principales

> Frecuencia ≥ 10. Tipo confirmado por dialog tags + relaciones.

### {{NOMBRE}}

- **Tipo:** personaje
- **Primera mención:** {{FIRST_CHAPTER}}, línea {{FIRST_LINE}}
- **Frecuencia:** {{FREQ}} menciones
- **Dialog tags:** {{DIALOG_COUNT}}
- **Relaciones detectadas:** {{RELATIONS}}

#### Atributos detectados

| Atributo | Valor citado | Cap | Línea |
|---|---|---|---|
| Edad | {{EDAD}} | | |
| Ojos | {{OJOS}} | | |
| Pelo | {{PELO}} | | |
| Altura | {{ALTURA}} | | |
| Profesión | {{PROFESION}} | | |

#### Citas clave

(Top 5 ordenadas por relevancia)

> {{CITA_1}} — Cap {{CAP_1}}, L{{LINEA_1}}

> {{CITA_2}} — Cap {{CAP_2}}, L{{LINEA_2}}

#### Notas del autor

<!-- escribe aquí lo que el extractor no detectó -->

---

## Personajes secundarios

> Frecuencia 3-9. Revisar si merecen arco propio o si son parte de hilos abiertos.

| Nombre | Freq | Primera mención | Dialog tags | Notas |
|---|---|---|---|---|
| {{NOMBRE}} | {{FREQ}} | {{FIRST_CH}} L{{FIRST_LINE}} | {{DT}} | |

---

## Lugares

| Nombre | Freq | Primera mención | Descripciones |
|---|---|---|---|
| {{LUGAR}} | {{FREQ}} | {{FIRST_CH}} L{{FIRST_LINE}} | {{DESCRIPCIONES}} |

---

## Objetos relevantes

| Objeto | Freq | Primera mención | Posible Chekhov's gun |
|---|---|---|---|
| {{OBJETO}} | {{FREQ}} | {{FIRST_CH}} L{{FIRST_LINE}} | {{SI_NO}} |

---

## Aliases registrados

> Si un personaje aparece con varios nombres (apodos, apellidos solos, formas formales), regístralos en `aliases.tsv` con formato `canonical<TAB>alias1<TAB>alias2`. Los scripts de auditoría los normalizarán.

| Canónico | Aliases |
|---|---|
| {{CANONICAL}} | {{ALIASES}} |

---

## Excepciones registradas

> Cambios deliberados que NO son inconsistencias (ej: personaje envejece entre tomos, se tiñe el pelo, cambia profesión). Regístralos en `exceptions.tsv` con formato `entity<TAB>attribute<TAB>justification`.

| Entidad | Atributo | Justificación |
|---|---|---|
| {{ENTITY}} | {{ATTR}} | {{JUSTIFICATION}} |

---

## Limitaciones de este bible

- No hace coreference de pronombres
- Personajes referidos solo por descripción ("el viejo del faro") no aparecen
- En primera persona, el narrador a veces no es nombrado
- Apodos no se fusionan automáticamente con nombre canónico (registra en aliases.tsv)

Trata el bible como **draft inicial**. Edítalo, complétalo, y úsalo como input para auditorías futuras del manuscrito.
