# Aprobación de cuadro de devolución – ajustes 2026

## Objetivo

Documentar los cambios realizados y las validaciones agregadas al flujo de aprobación de cuadros de devolución para evitar:

- bloqueos falsos entre solicitudes del mismo cuadro;
- reintentos que puedan duplicar liquidaciones o pagos;
- pagos extraordinarios creados pero no emitidos;
- envío a SAP de asientos descuadrados por diferencias de redondeo.

## Componentes involucrados

- `Form/scrg130_fmb.xml`
- `Paquetes/SCPQ_DEVO_4.pkb`
- `Paquetes/FAPQ_CERTAPOR_19.pkb`
- `Paquetes/FAPQ_PAGOEXTR_7.pkb`
- `Paquetes/SCPQ_ASIEDEVO_0.pkb`

## 1. Manejo de bloqueo de liquidación

Se corrigió el manejo del bloqueo de sesión en `SCPQ_DEVO` para evitar que, después de procesar una solicitud, la misma sesión conserve un bloqueo residual que impida procesar la siguiente.

El cambio:

- libera el bloqueo anterior antes de avanzar a otra solicitud;
- reconoce correctamente cuando la misma sesión ya posee el bloqueo;
- evita limpiar el estado local si Oracle no pudo liberar el bloqueo;
- permite detectar correctamente si la liberación falló.

Esto no modifica la lógica de liquidación ni de generación de pagos.

## 2. Checkpoint de liquidación

`SCT_SOLIDEVO.NUPAGOEXOL` se utiliza como checkpoint persistente.

Si una solicitud ya tiene un `NUPAGOEXOL`, un reintento de la aprobación no vuelve a ejecutar la liquidación ni crea otro `FAM_PAGOEXOL`. El proceso continúa desde la emisión o desde la etapa pendiente correspondiente.

## 3. Emisión de pagos extraordinarios

`FAPQ_PAGOEXTR.PR_EMITEPAGO` crea el pago extraordinario real y cambia el estado del `FAM_PAGOEXOL` desde `R` hacia un estado emitido.

Se detectó un caso en el que un pago quedó con:

```text
STPAGO = R
NUPAGOEXTR = NULL
FCEMIS = NULL
```

Esto significa que la emisión no quedó confirmada.

Para evitar que el flujo continúe silenciosamente, el Form debe validar el estado del pago después de ejecutar `PR_EMITEPAGO` y detenerse si continúa en `R`.

## 4. Diferencias de decimales antes de SAP

Se detectó un descuadre de `0,01 BOB` en el asiento SAP.

La causa fue el uso de importes con más de dos decimales en `SCT_SOLIDEVO`, mientras SAP trabaja los importes monetarios en BOB con dos decimales.

Ejemplo real:

```text
CARGO_ACTUAL       24332,91
PAGO_ACTUAL         1868,70
DEVOLUCION_ACTUAL  22464,20
DIFERENCIA              0,01
```

Después de normalizar:

```text
CARGO_CORREGIDO     24332,90
PAGO_CORREGIDO       1868,70
DEVOLUCION           22464,20
DIFERENCIA               0,00
```

## 5. Normalización antes del asiento SAP

Dentro de `Pr_guardar_checkpoint`, después de:

```plsql
Scpq_devo.Pr_actualizacuadro(:Bk_para.Idcuaddevo);
```

se normalizan los importes BOB:

```plsql
UPDATE Sct_solidevo S
   SET S.Toordedevobs = ROUND(S.Toordedevobs, 2),
       S.Vamontfactbs = S.Topagofact
                        + ROUND(S.Toordedevobs, 2)
 WHERE S.Idcuaddevo = :Bk_para.Idcuaddevo
   AND S.Stregi = 'R'
   AND (
          S.Toordedevobs <> ROUND(S.Toordedevobs, 2)
       OR S.Vamontfactbs <>
             S.Topagofact + ROUND(S.Toordedevobs, 2)
   );
```

No se modifica automáticamente `TOPAGOFACT`, porque este valor también se concilia contra las facturas pagadas.

## 6. Validación previa al envío a SAP

Antes de confirmar el checkpoint y antes de enviar el asiento a SAP, el Form reproduce el criterio de `SCPQ_ASIEDEVO.PR_INSERTARASIENTOUNO`:

- cargos agrupados por compañía;
- pagos agrupados por compañía;
- devoluciones por solicitud;
- importes redondeados a dos decimales.

Si el resultado no es `0,00`, el proceso se detiene y no se envía a SAP.

La validación evita que SAP reciba nuevamente un asiento con diferencia de redondeo.

## 7. Checkpoint de SAP

Antes de enviar el asiento se registra `[SAP_ENVIO]` en `SCT_DEVOLOG`.

Si existe un envío previo sin conciliación local, el Form detiene el reintento con el error `-20184`.

El objetivo es evitar un posible asiento duplicado en SAP.

Nunca se deben eliminar estos checkpoints sin antes verificar:

1. que no exista un asiento tipo 1 registrado en `SCE_ASIECUADDEVO`;
2. que SAP no haya creado el documento;
3. que el motivo del rechazo anterior esté identificado y corregido.

## 8. Resultado validado

Durante la prueba del cuadro 157:

- se completaron las liquidaciones;
- se recuperó y emitió correctamente el pago extraordinario pendiente;
- se corrigió la diferencia de `0,01 BOB`;
- el asiento quedó cuadrado;
- SAP aceptó el documento.

Asiento generado:

```text
0006052359
```

## Recomendación pendiente

Como mejora definitiva, revisar `SCPQ_DEVOBS.FN_IMTOTABS` para determinar si los importes expresados en bolivianos deben redondearse a dos decimales desde el origen. Si la función tiene otros usos que requieren mayor precisión, mantener el redondeo en el punto donde se persiste el valor monetario o antes de construir el asiento SAP.
