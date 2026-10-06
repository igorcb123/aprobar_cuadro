/*******************************************************************************
 * METADATA
 * Analista     : IGORCB
 * Descargado   : 06/10/2026, 10:07:17
 * Owner        : SGC_SO
 * Versión      : 4
 *******************************************************************************/
CREATE OR REPLACE PACKAGE BODY SGC_SO.Scpq_Devo
AS
    G_lockhandle VARCHAR2(128);
    G_lockname   VARCHAR2(200);

    -- Mantener un unico bloqueo de liquidacion por sesion. La liberacion
    -- es idempotente: si Oracle informa que la sesion ya no posee el lock
    -- (resultado 4), se limpia solamente el estado local del paquete.
    PROCEDURE Pr_Soltar_Bloqueo;

    PROCEDURE Pr_Tomar_Bloqueo(Pnucomp NUMBER, Pnucargabon NUMBER,
                               Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2)
    IS
        Lresultado NUMBER;
        Lrequested_name VARCHAR2(200);
    BEGIN
        Opexitosa := 'N';
        Pmensaje := NULL;
        Lrequested_name := 'CRE:DEVOLUCION:' || Pnucomp || ':' || Pnucargabon;

        IF G_lockhandle IS NOT NULL THEN
            IF G_lockname = Lrequested_name THEN
                Opexitosa := 'S';
                RETURN;
            END IF;

            -- Al avanzar a otra solicitud no debe quedar un handle residual
            -- de la liquidacion anterior.
            Pr_Soltar_Bloqueo;
            IF G_lockhandle IS NOT NULL THEN
                Pmensaje := 'La sesion conserva otro bloqueo de liquidacion que no pudo liberarse.';
                RETURN;
            END IF;
        END IF;

        G_lockname := Lrequested_name;
        DBMS_LOCK.ALLOCATE_UNIQUE_AUTONOMOUS(
            lockname => G_lockname,
            lockhandle => G_lockhandle,
            expiration_secs => 864000);

        Lresultado := DBMS_LOCK.REQUEST(
            lockhandle => G_lockhandle,
            lockmode => DBMS_LOCK.X_MODE,
            timeout => 0,
            release_on_commit => FALSE);

        -- 0 = lock obtenido. 4 = la misma sesion ya posee el lock.
        IF Lresultado NOT IN (0, 4) THEN
            G_lockhandle := NULL;
            G_lockname := NULL;
            Opexitosa := 'N';
            Pmensaje := 'La solicitud esta siendo procesada por otra sesion.';
            RETURN;
        END IF;

        Opexitosa := 'S';
    EXCEPTION
        WHEN OTHERS THEN
            -- Intentar limpiar cualquier handle parcial sin ocultar el error.
            Pr_Soltar_Bloqueo;
            Pmensaje := SUBSTR('No se pudo tomar el bloqueo de liquidacion: ' || SQLERRM, 1, 1000);
    END Pr_Tomar_Bloqueo;

    PROCEDURE Pr_Soltar_Bloqueo IS
        Lresultado NUMBER;
    BEGIN
        IF G_lockhandle IS NULL THEN
            G_lockname := NULL;
            RETURN;
        END IF;

        Lresultado := DBMS_LOCK.RELEASE(G_lockhandle);

        -- 0 = liberado correctamente.
        -- 4 = la sesion ya no posee ese lock; el handle local estaba residual.
        IF Lresultado IN (0, 4) THEN
            G_lockhandle := NULL;
            G_lockname := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- Ante un error inesperado conservar el handle evita continuar
            -- como si la liberacion hubiera sido exitosa.
            NULL;
    END Pr_Soltar_Bloqueo;
    PROCEDURE Pr_Revertir_Solicitud (Pnucomp         NUMBER,
                                     Pnuserv         NUMBER,
                                     Pcdmoti         VARCHAR2,
                                     Pdtglos         VARCHAR2,
                                     Opexitosa   OUT VARCHAR2,
                                     Dsmens      OUT VARCHAR2)
    IS
        CURSOR C_Soli IS
            SELECT Sol.Nucomp,
                   Sol.Nuserv,
                   Sol.Idcuaddevo,
                   Sol.Stsolidevo,
                   Sol.Idcert,
                   Sol.Nucargabon,
                   Sol.Vamontcobr,
                   Sol.Todeudfact,
                   Sol.Topagofact,
                   Sol.Toordedevo,
                   Sol.Fccalcdeud,
                   Sol.Nupagoexol,
                   Sol.Fcpagoorde,
                   Sol.Stregi,
                   Sol.Nuemplregi,
                   Sol.Fcregi,
                   Sol.Nuemplanul,
                   Sol.Fcanul,
                   Sol.Nutele,
                   Sol.Oppagodeud,
                   Sol.Oprequ,
                   Sol.Nusoci,
                   Sol.Opcertmedi,
                   Sol.Vamontfact,
                   Sol.Toordedevobs,
                   Sol.Vamontcobrbs,
                   Sol.Vamontfactbs,
                   Sol.Fccart,
                   Serv.Nucuen,
                   Serv.Stserv,
                   Serv.Cdserv
              FROM Sct_Solidevo Sol, Sot_Serv Serv
             WHERE     Sol.Nucomp = Pnucomp
                   AND Sol.Nuserv = Pnuserv
                   AND Sol.Nucomp = Serv.Nucomp
                   AND Sol.Nuserv = Serv.Nuserv;

        L_Soli           C_Soli%ROWTYPE;

        CURSOR C_Cuen IS
            SELECT *
              FROM Som_Cuen
             WHERE Nucomp = Pnucomp AND Nucuen = L_Soli.Nucuen;

        L_Cuen           C_Cuen%ROWTYPE;

        CURSOR C_Carg (Pnucargabon NUMBER)
        IS
            SELECT *
              FROM Fat_Cargabon
             WHERE Nucomp = Pnucomp AND Nucargabon = Pnucargabon;

        L_Carg           C_Carg%ROWTYPE;
        L_Devo           C_Carg%ROWTYPE;
        L_Stcert         VARCHAR2 (3) := 'EMI';

        CURSOR Traeultimovi IS
            SELECT A.Numovi
              FROM Soe_Movititu A
             WHERE     A.Nucuen = L_Cuen.Nucuen
                   AND A.Nucomp = L_Cuen.Nucomp
                   AND A.Numovi =
                       (SELECT MAX (X.Numovi)
                          FROM Soe_Movititu X
                         WHERE X.Nucuen = A.Nucuen AND X.Nucomp = A.Nucomp);

        CURSOR Traedatosultimovi (Prm_Numovi IN Soe_Movititu.Numovi%TYPE)
        IS
            SELECT A.*
              FROM Soe_Movititu A
             WHERE     A.Nucuen = L_Cuen.Nucuen
                   AND A.Nucomp = L_Cuen.Nucomp
                   AND A.Numovi = Prm_Numovi;



        Vnumoviulti      Soe_Movititu.Numovi%TYPE;
        Rdatosultimovi   Traedatosultimovi%ROWTYPE;

        CURSOR C_Soci IS
            SELECT *
              FROM Scm_Soci
             WHERE Nusoci = L_Soli.Nusoci;

        L_Soci           C_Soci%ROWTYPE;
    BEGIN
        Opexitosa := 'N';

        OPEN C_Soli;

        FETCH C_Soli INTO L_Soli;

        CLOSE C_Soli;

        OPEN C_Soci;

        FETCH C_Soci INTO L_Soci;

        CLOSE C_Soci;

        OPEN Traeultimovi;

        FETCH Traeultimovi INTO Vnumoviulti;

        CLOSE Traeultimovi;

        OPEN Traedatosultimovi (Vnumoviulti);

        FETCH Traedatosultimovi INTO Rdatosultimovi;

        CLOSE Traedatosultimovi;



        --Validaciones
        IF L_Soli.Stserv <> 'E'
        THEN
            Dsmens :=
                   'El servicio no est¿ en estado Emitido sino '
                || L_Soli.Stserv;
            Opexitosa := 'N';
            RETURN;
        END IF;

        IF NVL (L_Soli.Idcuaddevo, 0) > 0
        THEN
            Dsmens :=
                   'El servicio ya est¿ incluido en el cuadro '
                || L_Soli.Idcuaddevo;
            Opexitosa := 'N';
            RETURN;
        END IF;

        IF L_Soli.Cdserv <> '092'
        THEN
            Dsmens :=
                'El servicio no es una solicitud de devoluci¿n de certificado de aportaci¿n';
            Opexitosa := 'N';
            RETURN;
        END IF;

        IF     L_Soli.Nucuen IS NOT NULL
           AND Rdatosultimovi.Nuserv <> L_Soli.Nuserv
           AND Rdatosultimovi.Nuserv <> L_Soci.Nuservbaja
        THEN
            Dsmens :=
                'El servicio de solicitud de devoluci¿n no es el ¿ltimo que ha modificado la afiliaci¿n, no se puede revertir!!!';
            Opexitosa := 'N';
            RETURN;
        END IF;


        IF L_Soli.Stsolidevo = 'CUA'
        THEN
            Opexitosa := 'N';
            Dsmens :=
                'No se puede anular una solicitud cuando se encuentra en cuadro.';
            RETURN;
        END IF;

        IF L_Soli.Stsolidevo = 'PRO'
        THEN
            Opexitosa := 'N';
            Dsmens :=
                'No se puede anular una solicitud cuando se encuentra procesada';
            RETURN;
        END IF;

        IF L_Soli.Stsolidevo <> 'EMI'
        THEN
            Opexitosa := 'N';
            Dsmens := 'La solicitud no se encuentra emitida';
            RETURN;
        END IF;

        IF L_Soli.Stserv <> 'E'
        THEN
            Opexitosa := 'N';
            Dsmens :=
                'No se puede anular una solicitud cuando su servicio no se encuentra en estado emitido.';
            RETURN;
        END IF;


         -- CUENTA La cuenta debe ser de afiliaci¿n CONSUMIDOR
        IF L_Soli.Nucuen IS NOT NULL AND L_Soli.Nucuen > 0
        THEN
            OPEN C_Cuen;

            FETCH C_Cuen INTO L_Cuen;

            CLOSE C_Cuen;



            IF NVL (L_Cuen.Tiafil, 'C') <> 'C'
            THEN
                Opexitosa := 'N';
                Dsmens := 'La cuenta no es consumidor';
                RETURN;
            END IF;
        END IF;

         -- CARGO CONDICI¿N PARA DEVOLUCION DE CERTIFICADO
        OPEN C_Carg (L_Soli.Nucargabon);

        FETCH C_Carg INTO L_Carg;

        CLOSE C_Carg;

        OPEN C_Carg (L_Carg.Nucaabasoc);

        FETCH C_Carg INTO L_Devo;

        CLOSE C_Carg;


         -- CARGO Opfact = 'N'
        IF L_Carg.Opfactcaab <> 'N'
        THEN
            Opexitosa := 'N';
            Dsmens :=
                   'El cargo '
                || L_Carg.Nucargabon
                 || ' no est¿ marcado como no facturar';
            RETURN;
        END IF;

         -- CARGO Debe existir el abono de devoluci¿n de certificado
        IF L_Devo.Nucargabon IS NULL
        THEN
            Opexitosa := 'N';
            Dsmens := 'La devoluci¿n ' || L_Carg.Nucaabasoc || ' no existe';
            RETURN;
        END IF;

        -- SERVICIO Anular el servicio
        UPDATE Sot_Serv
           SET Stserv = 'A'
         WHERE Nucomp = Pnucomp AND Nuserv = Pnuserv AND Stserv = 'E';

        INSERT INTO Soe_Anulserv (Nucomp,
                                  Nuserv,
                                  Cdmoti,
                                  Dsanulserv,
                                  Fcregi,
                                  Nuemplregi)
             VALUES (Pnucomp,
                     Pnuserv,
                     Pcdmoti,
                     Pdtglos,
                     SYSDATE,
                     Mgpq_Seguacce.Fn_Traernuempl);

         -- CUENTA SE CAMBIA LA AFILIACI¿N A SOCIO
        IF L_Soli.Nucuen IS NOT NULL
        THEN
            -- Elimina el registro creado por el servicio de baja
             --y el de solicitud de devoluci¿n en el hist¿rico
             -- de la afiliaci¿n de la cuenta
            DELETE FROM
                Soe_Movititu
                  WHERE     Nucuen = L_Soli.Nucuen
                        AND Nucomp = L_Soli.Nucomp
                        AND Nuserv IN (L_Soli.Nuserv, L_Soci.Nuservbaja);

             -- Recupera el ¿ltimo movimiento actual del hist¿rico y abre nuevamente la vigencia en ¿se movimiento.
            OPEN Traeultimovi;

            FETCH Traeultimovi INTO Vnumoviulti;

            CLOSE Traeultimovi;

            UPDATE Soe_Movititu
               SET Fcfina = NULL
             WHERE     Nucuen = L_Soli.Nucuen
                   AND Nucomp = L_Soli.Nucomp
                   AND Numovi = Vnumoviulti;

            OPEN Traedatosultimovi (Vnumoviulti);

            FETCH Traedatosultimovi INTO Rdatosultimovi;

            CLOSE Traedatosultimovi;

            UPDATE Som_Cuen
               SET Tiafil = 'S'                        --Rdatosultimovi.Tiafil
             WHERE Nucomp = Pnucomp AND Nucuen = L_Soli.Nucuen;
        END IF;

         -- CARGO SE ACTUALIZA LA OPCION DE FACTURAR A SI Opfact='S'
         -- CARGO Desvincular el abono vinculado
        UPDATE Fat_Cargabon
           SET Opfactcaab = 'S', Nucaabasoc = NULL
         WHERE Nucomp = Pnucomp AND Nucargabon = L_Soli.Nucargabon/*AND Stfact = 'F'
                                                                  AND Stcobr = 'C'*/
                                                                  ;

         -- CARGO Anular el abono y dar de baja la orden de devoluci¿n en coblin
        UPDATE Fat_Cargabon
           SET Opfactcaab = 'N', Stregi = 'A', Nucaabasoc = NULL
         WHERE Nucomp = Pnucomp AND Nucargabon = L_Devo.Nucargabon;



         -- CARGO BIT¿CORA DE CAMBIOS (TO-DO)
        -- CERTIFICADO Se actualiza el Estado del Certificado al estado anterior
         -- CERTIFICADO EMI si ya se termin¿ de pagar y PEN si a¿n est¿ siendo pagado
        IF L_Carg.Vamontcobr < L_Carg.Vamont
        THEN
            L_Stcert := 'PEN';
        ELSE
            L_Stcert := 'EMI';
        END IF;

        UPDATE Scm_Cert
           SET Stcert = L_Stcert
         WHERE Idcert = L_Soli.Idcert;

         -- CERTIFICADO BIT¿CORA DE CAMBIOS (TO-DO)
         -- SOCIO Cambiar estado a Alta stsoci='A'
         -- SOCIO BIT¿CORA DE CAMBIOS (TO-DO)
        -- Pone en null el servicio y la fecha de baja
        UPDATE Scm_Soci
           SET Stsoci = 'A',
               Fcbaja = NULL,
               Nuservbaja = NULL,
               Cdmotibaja = NULL
         WHERE Nusoci = L_Soli.Nusoci AND Stsoci = 'B';

        --Anula el servicio de baja y actualiza scm_soci
        IF NVL (L_Soci.Nuservbaja, 0) > 0
        THEN
            UPDATE Sot_Serv
               SET Stserv = 'A'
             WHERE Nuserv = L_Soci.Nuservbaja AND Nucomp = L_Soli.Nucomp;

            BEGIN
                INSERT INTO Soe_Anulserv (Nucomp,
                                          Nuserv,
                                          Cdmoti,
                                          Dsanulserv,
                                          Fcregi,
                                          Nuemplregi)
                     VALUES (L_Soli.Nucomp,
                             L_Soci.Nuservbaja,
                             Pcdmoti,
                             Pdtglos,
                             SYSDATE,
                             Mgpq_Seguacce.Fn_Traernuempl);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        UPDATE Sct_Solidevo
           SET Stsolidevo = 'ANU'
         WHERE Nucomp = Pnucomp AND Nuserv = Pnuserv;



        Opexitosa := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            Opexitosa := 'N';
            Dsmens := SQLERRM || ' - ' || DBMS_UTILITY.Format_Error_Backtrace;
    END;


    PROCEDURE Pr_Autorizar_Impresion (Pnucomp   NUMBER,
                                      Pnuserv   NUMBER,
                                      Pdtglos   VARCHAR2)
    IS
    BEGIN
        INSERT INTO Sce_Imprdevo (Nucomp,
                                  Nuserv,
                                  Dtglos,
                                  Opauto,
                                  Nuemplauto,
                                  Fcauto,
                                  Opimpr)
             VALUES (Pnucomp,
                     Pnuserv,
                     Pdtglos,
                     'S',
                     Mgpq_Seguacce.Fn_Traernuempl,
                     SYSDATE,
                     'N');
    END;

    FUNCTION Fn_Impresion_Autorizada (Pnucomp NUMBER, Pnuserv NUMBER)
        RETURN VARCHAR2
    IS
        CURSOR C_Autoriza IS
            SELECT 'x'
              FROM Sce_Imprdevo I
             WHERE     I.Nucomp = Pnucomp
                   AND I.Nuserv = Pnuserv
                   AND Opauto = 'S'
                   AND Opimpr = 'N';

        Dummy   VARCHAR2 (1);
    BEGIN
        OPEN C_Autoriza;

        FETCH C_Autoriza INTO Dummy;

        IF C_Autoriza%FOUND
        THEN
            CLOSE C_Autoriza;

            RETURN 'S';
        ELSE
            CLOSE C_Autoriza;

            RETURN 'N';
        END IF;
    END;

    PROCEDURE Pr_Jobasiepagodevo (Pa_Idproc       NUMBER DEFAULT NULL,
                                  Pa_Idbitaproc   NUMBER DEFAULT NULL)
    IS
        Poperok            VARCHAR2 (1);
        Pnuasie            VARCHAR2 (1000);
        Pmensoper          VARCHAR2 (1000);
        Va_Resumen         Cbpq_Coblinweb_Resuproc.Re_Resumen;

        CURSOR C_Documentos IS
            SELECT *
              FROM Clw_Docucons
             WHERE Idserv = 8 AND TRUNC (Fcpago, 'dd') = TRUNC (SYSDATE - 1);

        CURSOR C_Solicitudes IS
            SELECT *
              FROM Sct_Solidevo
             WHERE TRUNC (Fcpagoorde) = TRUNC (SYSDATE - 1);

        Hubopagos          BOOLEAN := FALSE;

        Operacionexitosa   BOOLEAN;
        Vcc                VARCHAR2 (1000) := 'igorcb@cre.com.bo';
    BEGIN
        -- TRAE LA FECHA DE PAGO DE LOS DOCUMENTOS PAGADOS
        FOR D IN C_Documentos
        LOOP
            UPDATE Sct_Solidevo
               SET Fcpagoorde = D.Fcpago
             WHERE Nucomp = D.Nucomp AND Nupagoexol = TO_NUMBER (D.Nudocu);

            Hubopagos := TRUE;
        END LOOP;

        --VERIFICANDO SI LA BASE DE DATOS ES REAL
        IF Cbpq_Coblinweb_Util.Fn_Esbdreal = 'N'
        THEN
            --NO ES BD REAL.  Es muy posible que sea una Base de Datos de trabajo
            RETURN;
        END IF;

        --VERIFICACION DEL SEMAFORO
        IF Cbpq_Coblinweb_Resuproc.Fn_Estasemaforoenrojo ('ASPADE') = 'S'
        THEN
            RETURN;
        END IF;

        --PONE EL SEMAROJO EN ROJO POR 30 MINUTOS
        Cbpq_Coblinweb_Resuproc.Pr_Setsemaforoenrojo (
            'ASPADE',
            30,
            'ASIENTO 2, PAGO DE DEVOLUCION');
        Cbpq_Coblinweb_Resuproc.Pr_Inic (Va_Resumen,
                                         'Asiento de pago de devoluci¿n',
                                         10,
                                         0);

        IF Hubopagos = TRUE
        THEN
            Scpq_Asiedevo.Pr_Insertarasientodos (TRUNC (SYSDATE - 1),
                                                 Pnuasie,
                                                 Poperok,
                                                 Pmensoper);

            IF NVL (Poperok, 'N') = 'N'
            THEN
                Pr_Sendmail (
                    'sigecoop@cre.com.bo',
                    'robinghs@cre.com.bo',
                       'Error al crear asiento de pago de Ordenes de devolucion de fecha '
                    || TO_CHAR (TRUNC (SYSDATE - 1), 'dd/mm/yyyy'),
                    Vcc,
                       'Al intentar crear asiento de pago de Ordenes de devolucion de fecha '
                    || TO_CHAR (TRUNC (SYSDATE - 1), 'dd/mm/yyyy')
                    || ' se produjo el siguiente error: '
                    || Pmensoper
                    || ' en el procedimiento Scpq_Asiedevo.Pr_Insertarasientodos ',
                    Operacionexitosa,
                    Pmensoper);
            ELSE
                Pr_Sendmail (
                    'sigecoop@cre.com.bo',
                    'robinghs@cre.com.bo',
                       'Se gener¿ asiento de pago de Ordenes de devolucion de fecha '
                    || TO_CHAR (TRUNC (SYSDATE - 1), 'dd/mm/yyyy'),
                    Vcc,
                       'Se ha generado exitosamente en SAP el asiento '
                    || Pnuasie
                    || ' de pago de Ordenes de Devolucion para la fecha '
                    || TO_CHAR (TRUNC (SYSDATE - 1), 'dd/mm/yyyy')
                    || ' Scpq_Asiedevo.Pr_Insertarasientodos ',
                    Operacionexitosa,
                    Pmensoper);
            END IF;

            FOR S IN C_Solicitudes
            LOOP
                Pr_Asientosolicitud (S.Nucomp,
                                     S.Nuserv,
                                     Pnuasie,
                                     '2');
            END LOOP;

            COMMIT;
        ELSE
            Pr_Sendmail (
                'sigecoop@cre.com.bo',
                'robinghs@cre.com.bo',
                   'No hubo pagos de Ordenes de Devoluci¿n en la fecha '
                || TO_CHAR (TRUNC (SYSDATE - 1), 'dd/mm/yyyy'),
                Vcc,
                   'No hubo pagos de Ordenes de Devoluci¿n en la fecha '
                || TO_CHAR (TRUNC (SYSDATE - 1), 'dd/mm/yyyy')
                 || ' por tanto no se ejecut¿ el proceso Scpq_Asiedevo.Pr_Insertarasientodos ',
                Operacionexitosa,
                Pmensoper);
        END IF;

        Cbpq_Coblinweb_Resuproc.Pr_Mail (Va_Resumen);
        --PONE EL SEMAROJO EN VERDE
        Cbpq_Coblinweb_Resuproc.Pr_Setsemaforoenrojo ('ASPADE', 0);
    END;

    FUNCTION Fn_Nombresocio (Pnusoci NUMBER, Fc DATE:= SYSDATE)
        RETURN VARCHAR2
    IS /*
     CURSOR C_Nombre IS
         SELECT REPLACE (REPLACE (TRIM (Noclie) || ' ' || TRIM (Dsapelpate) || ' ' || TRIM (Dsapelmate) || DECODE (TRIM (Dsapelcasa), NULL, NULL, DECODE (Stcivi, 'V', ' VDA DE ', ' DE ') || TRIM (Dsapelcasa)), '  ', ' '), '  ', ' ') Nocuen
           FROM Scm_Soci C, Som_Clie P
          WHERE P.Nuclie = C.Nuclie AND C.Nusoci = Pnusoci;
          */
        CURSOR C_Nombre IS
              SELECT REPLACE (
                         REPLACE (
                                TRIM (Noclie)
                             || ' '
                             || TRIM (Dsapelpate)
                             || ' '
                             || TRIM (Dsapelmate)
                             || DECODE (
                                    TRIM (Dsapelcasa),
                                    NULL, NULL,
                                       DECODE (Stcivi, 'V', ' VDA DE ', ' DE ')
                                    || TRIM (Dsapelcasa)),
                             '  ',
                             ' '),
                         '  ',
                         ' ')    Nocuen
                FROM Scm_Soci C, Sod_Moviclie P
               WHERE     P.Nuclie = C.Nuclie
                     AND C.Nusoci = Pnusoci
                     AND Fc BETWEEN P.Fcinic AND NVL (P.Fcfina, SYSDATE + 1)
            ORDER BY P.Fcinic DESC;

        CURSOR C_Nombre_Actual IS
            SELECT REPLACE (
                       REPLACE (
                              TRIM (Noclie)
                           || ' '
                           || TRIM (Dsapelpate)
                           || ' '
                           || TRIM (Dsapelmate)
                           || DECODE (
                                  TRIM (Dsapelcasa),
                                  NULL, NULL,
                                     DECODE (Stcivi, 'V', ' VDA DE ', ' DE ')
                                  || TRIM (Dsapelcasa)),
                           '  ',
                           ' '),
                       '  ',
                       ' ')    Nocuen
              FROM Scm_Soci C, Som_Clie P
             WHERE P.Nuclie = C.Nuclie AND C.Nusoci = Pnusoci;



        L_Nombre             VARCHAR2 (1000);
        Encontro_Historico   BOOLEAN := FALSE;
    BEGIN
        OPEN C_Nombre;

        FETCH C_Nombre INTO L_Nombre;

        Encontro_Historico := C_Nombre%FOUND;

        CLOSE C_Nombre;

        IF    TRUNC (SYSDATE) = TRUNC (Fc)
           OR NVL (TRIM (L_Nombre), '') = ''
           OR Encontro_Historico = FALSE
        THEN
            OPEN C_Nombre_Actual;

            FETCH C_Nombre_Actual INTO L_Nombre;

            CLOSE C_Nombre_Actual;
        END IF;


        RETURN L_Nombre;
    END;

    PROCEDURE Pr_Generadevolucion (Pidcert                   NUMBER,
                                   Pnutele                   NUMBER,
                                   Pcdmoti                   VARCHAR2,
                                   Pdtserv                   VARCHAR2,
                                   Pnucart                   NUMBER,
                                   Poppagodeud               VARCHAR2,
                                   Poprequ                   VARCHAR2,
                                   Popcertmedi               VARCHAR2,
                                   Operacionexitosa   IN OUT BOOLEAN,
                                   Mensaje            IN OUT VARCHAR2)
    IS
        Pnucuen               NUMBER;
        Pnucomp               NUMBER;
        Pnuclierenu           NUMBER;
        Pnusocirenu           NUMBER;
        Pnuserv               NUMBER;

        CURSOR C_Scm_Cert IS
            SELECT C.*,
                   (SELECT Nusoci
                      FROM Scm_Soci
                     WHERE Nuclie = C.Nuclie)    Nusoci
              FROM Scm_Cert C
             WHERE Idcert = Pidcert;

        Lscm_Cert             C_Scm_Cert%ROWTYPE;
        Vfceven               DATE;
        Rcertserv             Soe_Certserv%ROWTYPE;
        Rservabre             Sopq_Datoserv.Tservabre;
        Rctrlserv             Sopq_Datoserv.Tctrlserv;
        Rservsoci             Sct_Serv%ROWTYPE;
        -- Datos para generar el servicio de Baja de Socio
        Vcdmoti               Sct_Serv.Cdmoti%TYPE;
        Vdtserv               Sot_Serv.Dtserv%TYPE;
        Vnuserv               Sot_Serv.Nuserv%TYPE;
        Vnucuen               Sot_Serv.Nucuen%TYPE := 0;
        Errordevolucion       EXCEPTION;
        Errorrequisitos       EXCEPTION;
        Errorobservacion      EXCEPTION;
        Nresp                 NUMBER (3);
        Lnucargabon           NUMBER;
        Lvamontcobr           NUMBER;

        CURSOR C_Nucargabon IS
            SELECT C.Nucargabon, F.Vamontcobr
              FROM Scm_Cert C, Fat_Cargabon F
             WHERE C.Idcert = Pidcert AND F.Nucargabon = C.Nucargabon;

        CURSOR Traeoficserv IS
            SELECT Nuoficemis
              FROM Sot_Serv
             WHERE Nuserv = Pnuserv AND Nucomp = Pnucomp;

        Vnuofic               Sot_Serv.Nuoficemis%TYPE;
        Vnutrab               NUMBER;
        Rtrabajo              Sopq_Datotrab.Ttrabajo;
        Listoparaprocesarse   BOOLEAN;
        -- Variable que indica si se debe PROCESAR  el servicio (NO ES RELEVANTE)
        Ultcarg               NUMBER;
    BEGIN
        OPEN C_Scm_Cert;

        FETCH C_Scm_Cert INTO Lscm_Cert;

        CLOSE C_Scm_Cert;

        Pnucuen := Lscm_Cert.Nucuen;
        Pnucomp := Lscm_Cert.Nucomp;
        Pnusocirenu := Lscm_Cert.Nusoci;
        Pnuclierenu := Lscm_Cert.Nuclie;

        LOOP
            SELECT MAX (Nucargabon)
              INTO Ultcarg
              FROM Fat_Cargabon
             WHERE Nucomp = Pnucomp;

            IF Mgpq_Secu.Fn_Siguientevalor (Pnucomp, 'nucargabon') > Ultcarg
            THEN
                EXIT;
            END IF;
        END LOOP;

        -- Construye la estructura del certificado a enviar al servicio
        Rcertserv.Idcert := Pidcert;
        Scpq_Servsoci.Pr_Genedevolapor (Pnucomp,
                                        Pcdmoti,
                                        Pnucuen,
                                        Pnusocirenu,
                                        Pidcert,
                                        Pdtserv,
                                        Mgpq_Seguacce.Fn_Traernuempl,
                                        Mgpq_Seguacce.Fn_Traernuofic,
                                        Pnuserv,
                                        Vfceven,
                                        Operacionexitosa,
                                        Mensaje,
                                        Pnucart,
                                        FALSE           --NO DEBE HACER COMMIT
                                             );

        IF NOT Operacionexitosa
        THEN
            RAISE Errordevolucion;
        END IF;

        ----OJO bORRAR PARA LA SALIDA EN ncre
        /* Sopq_CierServ.Pr_CierraServicio (:Bk_parametros.Nucomp, :Bk_parametros.nuserv,  :Bk_certificados.Nucuen, Vfceven,
                       :Bk_control.Nuempl, OperacionExitosa, Mensaje);

           If not OperacionExitosa Then
              RAISE Errordevolucion;
           End If ;  */
        -- FIN BORRAR

        /*20/11/2018
        Igor Cabrera
           1. No debe cerrar el servicio en el procedimiento scpq_servsoci.Pr_GeneDevolApor, el servicio debe quedar como emitido
               2. Se debe hacer insert en sct_solidevo
                2.1 Se debe crear la devoluci¿n en fam_pagoexol igual que en la FARG436 ver paquete con David
               3. Si se ha marcado que Cumple Requisitos se debe crear el trabajo requisitos
               4. Si no se ha marcado que Cumple Requisitos se debe pedir una glosa y observar el servicio
               5. Se debe poner el certificado en estado BLQ
                6. Se debe cambiar la afiliaci¿n de la cuenta
                7. Se debe dar de baja al socio si es su ¿nico certificado
        */
        --2. inserta solicitud en en sct_solidevo
        OPEN C_Nucargabon;

        FETCH C_Nucargabon INTO Lnucargabon, Lvamontcobr;

        CLOSE C_Nucargabon;

        INSERT INTO Sct_Solidevo (Nucomp,
                                  Nuserv,
                                  Nusoci,
                                  Nutele,
                                  Idcert,
                                  Nucargabon,
                                  Vamontcobr,
                                  Nuemplregi,
                                  Oppagodeud,
                                  Oprequ,
                                  Opcertmedi)
             VALUES (Pnucomp,
                     Pnuserv,
                     Pnusocirenu,
                     Pnutele,
                     Pidcert,
                     Lnucargabon,
                     Lvamontcobr,
                     Mgpq_Seguacce.Fn_Traernuempl,
                     Poppagodeud,
                     Poprequ,
                     Popcertmedi);

        Vnucuen := Pnucuen;
        --- PARA QUE FALLE
        DBMS_OUTPUT.Put_Line ('7');
        Sopq_Cierserv.Pr_Enviaconceptos (
            Pnucomp,
            --IN SOT_SERV.nucomp%TYPE,
            Pnuserv,
            --IN SOT_SERV.nuserv%TYPE,
            Pnucuen,
            --IN Sot_Serv.nucuen%TYPE,
            Sopq_Paramodu.Fn_Devolucionaportacion,
            --:Bk_parametros.cdserv            --IN sot_serv.cdserv%TYPE,
            Pcdmoti,
            --IN sot_serv.cdmoti%TYPE,
            Mgpq_Seguacce.Fn_Traernuempl,
            --prm_nuEmpl                 In sot_serv.nuEmplEmis%Type,
            Operacionexitosa,
            Mensaje);
        DBMS_OUTPUT.Put_Line (
            'Sopq_cierserv.Pr_enviaconceptos (Pnucomp, ' || Mensaje);

        IF Operacionexitosa
        THEN
            --Se da de baja si fue su ¿ltimo certificado
            IF NOT Scpq_Certificados.Fn_Consulta_Por_Persona (Pnuclierenu)
            THEN
                Scpq_Socios.Pr_Bajasocio (Pnucomp,
                                          Pnuserv,
                                          Operacionexitosa,
                                          Mensaje);

                IF NOT Operacionexitosa
                THEN
                    Operacionexitosa := FALSE;
                    Mensaje := ('ERROR Al dar de Baja al socio:' || Mensaje);
                    ROLLBACK;
                END IF;
            END IF;
        ELSE
            Mensaje :=
                ('ERROR: en sopq_cierserv.Pr_EnviaConceptos ' || Mensaje);
            Operacionexitosa := FALSE;
            ROLLBACK;
        END IF;
    EXCEPTION
        WHEN Errordevolucion
        THEN
            Operacionexitosa := FALSE;
        WHEN Errorrequisitos
        THEN
            Operacionexitosa := FALSE;
        WHEN Errorobservacion
        THEN
            Operacionexitosa := FALSE;
        WHEN OTHERS
        THEN
            Operacionexitosa := FALSE;
            Mensaje := ('ERROR:' || SQLERRM);
    END;

    PROCEDURE Pr_Nuevoservicio (Pnusocirenu            NUMBER,
                                Pidcert                NUMBER,
                                Pnutele                NUMBER,
                                Pcdmoti                VARCHAR2,
                                Pdtserv                VARCHAR2,
                                Pnucart                NUMBER,
                                Poppagodeud            VARCHAR2,
                                Poprequ                VARCHAR2,
                                Popcertmedi            VARCHAR2,
                                Operacionexitosa   OUT BOOLEAN,
                                Mensaje            OUT VARCHAR2)
    IS
        Nresp         NUMBER (3);
        Salir         EXCEPTION;
        Lnuclierenu   NUMBER;

        CURSOR Cnuclierenu IS
            SELECT Nuclie
              FROM Scm_Soci
             WHERE Nusoci = Pnusocirenu;

        CURSOR C_Beca IS
              SELECT Be.Nubeca,
                     TRIM (Scpq_Pers.Fn_Nombrepersona (Pe.Nupers))     Nopers,
                     Un.Nocarr,
                     Be.Fcinsc,
                     Be.Cduniv,
                     Be.Stbeca
                FROM Scm_Soci    So,
                     Som_Cuen    Cu,
                     Sot_Serv    Se,
                     Scm_Becauniv Be,
                     Scm_Pers    Pe,
                     Scc_Carruniv Un
               WHERE                   /*be.cduniv = 'UPSA'
                          and*/
                         So.Nusoci = Pnusocirenu
                     AND Pe.Nupers = Be.Nupers
                     AND Un.Cduniv = Be.Cduniv
                     AND Un.Cdcarr = Be.Cdcarr
                     --and be.stbeca = 'CON'
                     AND Se.Nucomp = Be.Nucomp
                     AND Se.Nuserv = Be.Nuserv
                     AND Cu.Nuclie = So.Nuclie
                     AND Se.Nucomp = Cu.Nucomp
                     AND Se.Nucuen = Cu.Nucuen
            ORDER BY Be.Nubeca;

        L_Beca        C_Beca%ROWTYPE;
        Msbene        VARCHAR2 (10000);
        Rcara         Scpq_Socios.Tcara;
        Opvalido      VARCHAR2 (1) := 'S';
    BEGIN
        IF Scpq_Socios.Fn_Tienecaracteristicas (Lnuclierenu)
        THEN
            Scpq_Socios.Pr_Ultimacaracteristica (Lnuclierenu, Rcara);
            Msbene :=
                   'Socio '
                || RTRIM (LTRIM (Rcara.Dscara))
                || ', '
                || 'DESDE FECHA: '
                || TO_CHAR (Rcara.Fcinic, 'dd/mm/yyyy');

            IF Rcara.Fcfina IS NOT NULL
            THEN
                Msbene :=
                       Msbene
                    || ' A '
                    || TO_CHAR (Rcara.Fcfina, 'dd/mm/yyyy')
                    || CHR (13)
                    || CHR (10);
            END IF;

            IF     NVL (Rcara.Fcfina, SYSDATE + 1) > SYSDATE
               AND Scpq_Certificados.Fn_Cantidad_Por_Persona (Lnuclierenu) =
                   1
            THEN
                Msbene :=
                       Msbene
                     || ' y el certificado que se desea devolver es su ¿nico certificado, por lo tanto la solicitud no procede.';
                Opvalido := 'N';
            END IF;

            Msbene := Msbene || CHR (13) || CHR (10);
        END IF;

        OPEN C_Beca;

        FETCH C_Beca INTO L_Beca;

        IF C_Beca%FOUND
        THEN
            Msbene :=
                   Msbene
                || (   'El socio tiene fue beneficiado con una beca para su hijo '
                    || L_Beca.Nopers
                    || ' para estudiar '
                    || L_Beca.Nocarr
                    || ' en la universidad '
                    || L_Beca.Cduniv);

            IF     L_Beca.Stbeca NOT IN ('CON', 'REN')
               AND Scpq_Certificados.Fn_Cantidad_Por_Persona (Lnuclierenu) =
                   1
            THEN
                Msbene :=
                       Msbene
                     || ' la devoluci¿n no procede porque ser¿a dado de baja. En tanto no concluya la carrera o renuncie a la beca no se puede proceder a la devoluci¿n.';
                Opvalido := 'N';
            END IF;
        END IF;

        CLOSE C_Beca;

        IF Opvalido = 'N'
        THEN
            RETURN;
        END IF;

        IF NVL (Pnutele, 0) = 0
        THEN
            Mensaje := 'Debe introducir un n¿mero de contacto';
            RAISE Salir;
        END IF;

        --         Pq_validaciones.Pr_validadevolucion (Operacionexitosa, Mensaje);
        --Pq_procesos.Pr_generadevolucion (Operacionexitosa, Mensaje);
        Pr_Generadevolucion (Pidcert,
                             Pnutele,
                             Pcdmoti,
                             Pdtserv,
                             Pnucart,
                             Poppagodeud,
                             Poprequ,
                             Popcertmedi,
                             Operacionexitosa,
                             Mensaje);

        IF NOT Operacionexitosa
        THEN
            RAISE Salir;
        END IF;
    EXCEPTION
        WHEN Salir
        THEN
            ROLLBACK;
            Operacionexitosa := FALSE;
    END;

    PROCEDURE Pr_Logdevo (Pnucomp NUMBER, Pnuserv NUMBER, Ms VARCHAR2)
    IS
    BEGIN
        INSERT INTO Sct_Devolog (Nucomp, Nuserv, Dslog)
             VALUES (Pnucomp, Pnuserv, Ms);
    END;

    FUNCTION Pr_Validaliquidacion (Pnucomp           NUMBER,
                                   Pnuserv           NUMBER,
                                   Pnucargabon       NUMBER,
                                   Pnupagoexol       NUMBER,
                                   Op            OUT BOOLEAN,
                                   Ms            OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        CURSOR C_Vamontfactbs IS
            SELECT ROUND (LEAST (Abo.Vamontfact, 410) * Mgfn_Tipocamb, 2)    Vamontfactbs
              FROM Fat_Cargabon Car, Fat_Cargabon Abo
             WHERE     Car.Nucomp = Pnucomp
                   AND Car.Nucargabon = Pnucargabon
                   AND Abo.Nucargabon = Car.Nucaabasoc
                   AND Abo.Nucomp = Car.Nucomp;

        Vamontfactbs   NUMBER;

        CURSOR C_Toordedevobs IS
            SELECT Imtotabs
              FROM Fam_Pagoexol
             WHERE Nupagoexol = Pnupagoexol;

        Toordedevobs   NUMBER;

        CURSOR C_Topagofact IS
            SELECT NVL (SUM (Todocu), 0)
              FROM Dct_Docu D, Sce_Devofact F
             WHERE     F.Nucomp = Pnucomp
                   AND F.Nuserv = Pnuserv
                   AND F.Nucomp = D.Nucomp
                   AND F.Nudocu = D.Nudocu;

        Topagofact     NUMBER;
    BEGIN
        Op := TRUE;
        Ms := '';

        OPEN C_Vamontfactbs;

        FETCH C_Vamontfactbs INTO Vamontfactbs;

        CLOSE C_Vamontfactbs;

        OPEN C_Toordedevobs;

        FETCH C_Toordedevobs INTO Toordedevobs;

        CLOSE C_Toordedevobs;

        OPEN C_Topagofact;

        FETCH C_Topagofact INTO Topagofact;

        CLOSE C_Topagofact;
    END;

    PROCEDURE Pr_Arregla_Decimales (Pidcuad NUMBER)
    IS
        Va_Dsmens   VARCHAR2 (1000);

        CURSOR Trae_Liqui IS
              SELECT *
                FROM (SELECT Re.*,
                             Vamontdevbs - Montoliqubs    Montodevok,
                             (CASE
                                  WHEN ABS (Vamontfact - Vamontdev) <= 0.00
                                  THEN
                                      'OK'
                                  ELSE
                                      'ERROR'
                              END)                        Obsdev1, --CARGO IGUAL QUE EL ABONO
                             (CASE
                                  WHEN Montoliqu <= Vamontfact THEN 'OK'
                                  ELSE 'ERROR'
                              END)                        Obsdev2, --LIQUIDACION($US) MAYOR AL CERTIFICADO
                             (CASE
                                  WHEN Montoliqubs <= Vamontdevbs THEN 'OK'
                                  ELSE 'ERROR'
                              END)                        Obsdev3, --LIQUIDACION(BS.) MAYOR AL CERTIFICADO
                             (CASE
                                  WHEN ABS (
                                           Montodev - (Vamontfact - Montoliqu)) <=
                                       0.02
                                  THEN
                                      'OK'
                                  ELSE
                                      'ERROR'
                               END)                        Obsdev4, --DEVOLUCI¿N ($US) DIFERENTE AL SALDO DEL CERTIFICADO Y LA LIQUIDACION
                             (CASE
                                  WHEN ABS (
                                             Montodevbs
                                           - (Vamontdevbs - Montoliqubs)) <=
                                       0.00
                                  THEN
                                      'OK'
                                  ELSE
                                      'ERROR'
                               END)                        Obsdev5, --DEVOLUCI¿N (BS.) DIFERENTE AL SALDO DEL CERTIFICADO Y LA LIQUIDACION
                             (CASE
                                  WHEN ABS (
                                             Todocusus
                                           - ROUND (
                                                   Montodevbs
                                                 / Mgfn_Cambdiar (Fcpubl) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                         ,
                                                 2)) <=
                                       0.00
                                  THEN
                                      'OK'
                                  ELSE
                                      'ERROR'
                               END)                        Obsdev6, --DEVOLUCI¿N EN DOLARES IGUAL A DEVOLUCI¿N EN BOLIVIANOS
                             (CASE
                                  WHEN TRIM (Dsnomb) = TRIM (Dsnombok)
                                  THEN
                                      'OK'
                                  ELSE
                                      'ERROR'
                              END)                        Obsdev7 --NOMBRE DE LA DEVOLUCION EQUIVOCADO
                        FROM (SELECT Cuad.Idcuad,
                                     Cuad.Fcapro,
                                     Soli.Nucomp,
                                     Soli.Nuserv,
                                     Serv.Nucuen,
                                     Soli.Nucargabon,
                                     (SELECT Car.Nucaabasoc
                                        FROM Fat_Cargabon Car
                                       WHERE     Nucomp = Soli.Nucomp
                                             AND Nucargabon = Soli.Nucargabon)
                                         Abono,
                                     Soli.Nupagoexol,
                                     (SELECT Stpago
                                        FROM Fam_Pagoexol
                                       WHERE Nupagoexol = Soli.Nupagoexol)
                                         Stpago,
                                     (SELECT Fcpubl
                                        FROM Fam_Pagoexol
                                       WHERE Nupagoexol = Soli.Nupagoexol)
                                         Fcpubl,
                                     (SELECT Ticamb
                                        FROM Fam_Pagoexol
                                       WHERE Nupagoexol = Soli.Nupagoexol)
                                         Ticamb,
                                     (SELECT Nupagoextr
                                        FROM Fam_Pagoexol
                                       WHERE Nupagoexol = Soli.Nupagoexol)
                                         Nupagoextr,
                                     (SELECT Car.Vamontfact
                                        FROM Fat_Cargabon Car
                                       WHERE     Car.Nucomp = Soli.Nucomp
                                             AND Car.Nucargabon =
                                                 Soli.Nucargabon)
                                         Vamontreal,
                                     (SELECT LEAST (Car.Vamontfact, 410)
                                        FROM Fat_Cargabon Car
                                       WHERE     Car.Nucomp = Soli.Nucomp
                                             AND Car.Nucargabon =
                                                 Soli.Nucargabon)
                                         Vamontfact,
                                     (SELECT LEAST (Abo.Vamont, 410)
                                        FROM Fat_Cargabon Car, Fat_Cargabon Abo
                                       WHERE     Car.Nucomp = Soli.Nucomp
                                             AND Car.Nucargabon =
                                                 Soli.Nucargabon
                                             AND Abo.Nucargabon =
                                                 Car.Nucaabasoc
                                             AND Abo.Nucomp = Car.Nucomp)
                                         Vamontdev,
                                     (SELECT ROUND (
                                                   LEAST (Abo.Vamont, 410)
                                                 * Mgfn_Cambdiar (Abo.Fccargo) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                              ,
                                                 2)
                                        FROM Fat_Cargabon Car, Fat_Cargabon Abo
                                       WHERE     Car.Nucomp = Soli.Nucomp
                                             AND Car.Nucargabon =
                                                 Soli.Nucargabon
                                             AND Abo.Nucargabon =
                                                 Car.Nucaabasoc
                                             AND Abo.Nucomp = Car.Nucomp)
                                         Vamontdevbs,
                                     (SELECT COUNT (Todocu)
                                        FROM Clw_Docucons
                                       WHERE     Cdcuenalte =
                                                 TO_CHAR (Serv.Nucuen)
                                             AND Nucomp = Serv.Nucomp
                                             AND Idserv = 1
                                             AND Fcpago BETWEEN NVL (
                                                                    Fcapro,
                                                                      SYSDATE
                                                                    - 30)
                                                            AND   NVL (Fcapro,
                                                                       SYSDATE)
                                                                + 15
                                             AND Nucaje = 18293)
                                         Ctfactliqu,
                                     (SELECT NVL (
                                                 SUM (
                                                     ROUND (
                                                           Todocu
                                                         / Mgfn_Cambdiar (
                                                               Fcexpo) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                      ,
                                                         2)),
                                                 0)
                                        FROM Clw_Docucons
                                       WHERE     Cdcuenalte =
                                                 TO_CHAR (Serv.Nucuen)
                                             AND Nucomp = Serv.Nucomp
                                             AND Idserv = 1
                                             AND Fcpago BETWEEN NVL (
                                                                    Fcapro,
                                                                      SYSDATE
                                                                    - 30)
                                                            AND   NVL (Fcapro,
                                                                       SYSDATE)
                                                                + 15
                                             AND Nucaje = 18293)
                                         Montoliqu,
                                     (SELECT NVL (SUM (Todocu), 0)
                                        FROM Clw_Docucons
                                       WHERE     Cdcuenalte =
                                                 TO_CHAR (Serv.Nucuen)
                                             AND Nucomp = Serv.Nucomp
                                             AND Idserv = 1
                                             AND Fcpago BETWEEN NVL (
                                                                    Fcapro,
                                                                      SYSDATE
                                                                    - 30)
                                                            AND   NVL (Fcapro,
                                                                       SYSDATE)
                                                                + 15
                                             AND Nucaje = 18293)
                                         Montoliqubs,
                                     (SELECT NVL (
                                                 SUM (
                                                     ROUND (
                                                           Todocu
                                                         / Mgfn_Cambdiar (
                                                               Fcemis) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                      ,
                                                         2)),
                                                 0)
                                        FROM Clt_Docu
                                       WHERE     Cdcuenalte =
                                                 TO_CHAR (Soli.Nupagoexol)
                                             AND Nucomp = Serv.Nucomp
                                             AND Idserv = 8)
                                         Montodev,
                                     (SELECT SUM (Topago)
                                        FROM Faw_Pagoexol
                                       WHERE     Tipagoexol = 'D'
                                             AND Cdcargabon = 2
                                             AND Nuserv = Soli.Nuserv
                                             AND Nucomp = Serv.Nucomp
                                             AND Stregi = 'R'
                                             AND Stpago IN ('E',
                                                            'P',
                                                            'L',
                                                            'C'))
                                         Todocusus,
                                     (SELECT NVL (SUM (Todocu), 0)
                                        FROM Clt_Docu
                                       WHERE     Cdcuenalte =
                                                 TO_CHAR (Soli.Nupagoexol)
                                             AND Nucomp = Serv.Nucomp
                                             AND Idserv = 8)
                                         Montodevbs,
                                     (SELECT MAX (Dsnomb)
                                        FROM Faw_Pagoexol
                                       WHERE     Tipagoexol = 'D'
                                             AND Cdcargabon = 2
                                             AND Nuserv = Soli.Nuserv
                                             AND Nucomp = Serv.Nucomp
                                             AND Stregi = 'R'
                                             AND Stpago IN ('E',
                                                            'P',
                                                            'L',
                                                            'C'))
                                         Dsnomb,
                                     TRIM (Scpq_Devo.Fn_Nombresocio (Nusoci))
                                         Dsnombok
                                FROM Sot_Serv    Serv,
                                     Sct_Solidevo Soli,
                                     Sct_Cuaddevo Cuad
                               WHERE                      --cuad.idcuad=93 and
                                         --cuad.stcuad not in ('EMI') and
                                         Soli.Idcuaddevo = Cuad.Idcuad
                                     AND Soli.Nuserv = Soli.Nuserv + 0
                                     AND Soli.Nucomp = Soli.Nucomp + 0
                                     AND Soli.Nucomp = Serv.Nucomp
                                     AND Soli.Nuserv = Serv.Nuserv
                                     AND Serv.Nucuen = Serv.Nucuen + 0 --and serv.nucuen IN (201180)
                                                                      --and serv.nuserv=18819203
                                                                      --and nupagoexol>0
                                                                      ) Re) R2
               WHERE     Idcuad = Idcuad + 0
                     AND Idcuad = Pidcuad
                     --nupagoexol is not null
                     --and nupagoexol=1275845
                     --and stpago in ('R','E','P','L','C','V')
                     AND NOT (    Obsdev1 = 'OK'
                              AND Obsdev2 = 'OK'
                              AND Obsdev3 = 'OK'
                              AND Obsdev4 = 'OK'
                              AND Obsdev5 = 'OK'
                              AND Obsdev6 = 'OK'
                              AND Obsdev7 = 'OK')
            ORDER BY Nupagoexol NULLS FIRST;
    BEGIN
        FOR Liqui IN Trae_Liqui
        LOOP
            IF Liqui.Nupagoexol IS NOT NULL
            THEN
                IF Liqui.Stpago IN ('R', 'E', 'P')
                THEN
                    DBMS_OUTPUT.Put_Line (
                        'Corrigiendo Nupagoexol: ' || Liqui.Nupagoexol);

                    --ACTUALIZANDO LOS MONTOS A CERO
                    UPDATE Fad_Pagoexol
                       SET Mopago = 1
                     WHERE Nupagoexol = Liqui.Nupagoexol;

                    UPDATE Fam_Pagoexol
                       SET Topago = 1, Imtotabs = 1, Fcmodi = SYSDATE
                     WHERE Nupagoexol = Liqui.Nupagoexol;

                    UPDATE Fad_Pagoextr
                       SET Mopago = 1
                     WHERE Nupagoextr = Liqui.Nupagoextr;

                    UPDATE Fam_Pagoextr
                       SET Vamont = 1
                     WHERE Nupagoextr = Liqui.Nupagoextr;

                    UPDATE Fat_Cargabon
                       SET Vamontfact = 1
                     WHERE Nucargabon = Liqui.Abono AND Nucomp = Liqui.Nucomp;

                    IF Liqui.Stpago = 'R'
                    THEN
                        Fapq_Pagoextr.Pr_Emitepago (
                            Liqui.Nupagoexol,
                            Va_Dsmens,
                            TRUNC (SYSDATE, 'DD'),
                            TRUNC (SYSDATE + 720, 'DD'));
                        DBMS_OUTPUT.Put_Line (
                               'Emitiendo Nupagoexol: '
                            || Liqui.Nupagoexol
                            || '  RESULTADO:'
                            || Va_Dsmens);
                        COMMIT;
                    END IF;

                    --ACTUALIZANDO LOS MONTOS OK
                    UPDATE Fad_Pagoexol
                       SET Mopago =
                               ROUND (
                                     (Liqui.Vamontdevbs - Liqui.Montoliqubs)
                                   /  (Liqui.ticamb) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                 ,
                                   2)
                     WHERE Nupagoexol = Liqui.Nupagoexol;

                    UPDATE Fam_Pagoexol
                       SET Topago =
                               ROUND (
                                     (Liqui.Vamontdevbs - Liqui.Montoliqubs)
                                   / (Liqui.ticamb) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                 ,
                                   2),
                           Imtotabs = Liqui.Vamontdevbs - Liqui.Montoliqubs
                     WHERE Nupagoexol = Liqui.Nupagoexol;

                    UPDATE Fad_Pagoextr
                       SET Mopago =
                               ROUND (
                                     (Liqui.Vamontdevbs - Liqui.Montoliqubs)
                                   / (Liqui.ticamb) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                 ,
                                   2)
                     WHERE Nupagoextr = Liqui.Nupagoextr;

                    UPDATE Fam_Pagoextr
                       SET Vamont =
                               ROUND (
                                     (Liqui.Vamontdevbs - Liqui.Montoliqubs)
                                   / (Liqui.ticamb) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                 ,
                                   2)
                     WHERE Nupagoextr = Liqui.Nupagoextr;

                    UPDATE Fat_Cargabon
                       SET Vamontfact = Liqui.Vamontfact
                     WHERE Nucargabon = Liqui.Abono AND Nucomp = Liqui.Nucomp;

                    IF Liqui.Stpago = 'P'
                    THEN
                        UPDATE Fam_Pagoexol
                           SET Stpago = 'E'
                         WHERE Nupagoexol = Liqui.Nupagoexol;
                    END IF;

                    COMMIT;
                END IF;
            END IF;
        END LOOP;
    -- Sgc_Cb.Cbpq_Coblinweb_Pagoextr.Pr_Publicadocu (1, 1);
    END;

    PROCEDURE Pr_Arregla_Decimales (Pnucomp NUMBER, Pnuserv NUMBER)
    IS
        Va_Dsmens          VARCHAR2 (1000);

        CURSOR Trae_Liqui IS
              SELECT *
                FROM (SELECT Re.*,
                             Vamontdevbs - Montoliqubs    Montodevok,
                             (CASE
                                  WHEN ABS (Vamontfact - Vamontdev) <= 0.00
                                  THEN
                                      'OK'
                                  ELSE
                                      'ERROR'
                              END)                        Obsdev1, --CARGO IGUAL QUE EL ABONO
                             (CASE
                                  WHEN Montoliqu <= Vamontfact THEN 'OK'
                                  ELSE 'ERROR'
                              END)                        Obsdev2, --LIQUIDACION($US) MAYOR AL CERTIFICADO
                             (CASE
                                  WHEN Montoliqubs <= Vamontdevbs THEN 'OK'
                                  ELSE 'ERROR'
                              END)                        Obsdev3, --LIQUIDACION(BS.) MAYOR AL CERTIFICADO
                             (CASE
                                  WHEN ABS (
                                           Montodev - (Vamontfact - Montoliqu)) <=
                                       0.02
                                  THEN
                                      'OK'
                                  ELSE
                                      'ERROR'
                               END)                        Obsdev4, --DEVOLUCI¿N ($US) DIFERENTE AL SALDO DEL CERTIFICADO Y LA LIQUIDACION
                             (CASE
                                  WHEN ABS (
                                             Montodevbs
                                           - (Vamontdevbs - Montoliqubs)) <=
                                       0.00
                                  THEN
                                      'OK'
                                  ELSE
                                      'ERROR'
                               END)                        Obsdev5, --DEVOLUCI¿N (BS.) DIFERENTE AL SALDO DEL CERTIFICADO Y LA LIQUIDACION
                             (CASE
                                  WHEN ABS (
                                             Todocusus
                                           - ROUND (
                                                   Montodevbs
                                                 / Mgfn_Cambdiar (Fcpubl) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                         ,
                                                 2)) <=
                                       0.00
                                  THEN
                                      'OK'
                                  ELSE
                                      'ERROR'
                               END)                        Obsdev6, --DEVOLUCI¿N EN DOLARES IGUAL A DEVOLUCI¿N EN BOLIVIANOS
                             (CASE
                                  WHEN TRIM (Dsnomb) = TRIM (Dsnombok)
                                  THEN
                                      'OK'
                                  ELSE
                                      'ERROR'
                              END)                        Obsdev7 --NOMBRE DE LA DEVOLUCION EQUIVOCADO
                        FROM (SELECT Cuad.Idcuad,
                                     Cuad.Fcapro,
                                     Soli.Fcregi,
                                     Soli.Nucomp,
                                     Soli.Nuserv,
                                     Serv.Nucuen,
                                     Soli.Nucargabon,
                                     (SELECT Car.Nucaabasoc
                                        FROM Fat_Cargabon Car
                                       WHERE     Nucomp = Soli.Nucomp
                                             AND Nucargabon = Soli.Nucargabon)
                                         Abono,
                                     Soli.Nupagoexol,
                                     (SELECT Stpago
                                        FROM Fam_Pagoexol
                                       WHERE Nupagoexol = Soli.Nupagoexol)
                                         Stpago,
                                     (SELECT Fcpubl
                                        FROM Fam_Pagoexol
                                       WHERE Nupagoexol = Soli.Nupagoexol)
                                         Fcpubl,
                                         (SELECT Ticamb
                                        FROM Fam_Pagoexol
                                       WHERE Nupagoexol = Soli.Nupagoexol)
                                         Ticamb,
                                     (SELECT Nupagoextr
                                        FROM Fam_Pagoexol
                                       WHERE Nupagoexol = Soli.Nupagoexol)
                                         Nupagoextr,
                                     (SELECT Car.Vamontfact
                                        FROM Fat_Cargabon Car
                                       WHERE     Car.Nucomp = Soli.Nucomp
                                             AND Car.Nucargabon =
                                                 Soli.Nucargabon)
                                         Vamontreal,
                                     (SELECT LEAST (Car.Vamontfact, 410)
                                        FROM Fat_Cargabon Car
                                       WHERE     Car.Nucomp = Soli.Nucomp
                                             AND Car.Nucargabon =
                                                 Soli.Nucargabon)
                                         Vamontfact,
                                     LEAST (
                                         (SELECT LEAST (Abo.Vamont, 410)
                                            FROM Fat_Cargabon Car,
                                                 Fat_Cargabon Abo
                                           WHERE     Car.Nucomp = Soli.Nucomp
                                                 AND Car.Nucargabon =
                                                     Soli.Nucargabon
                                                 AND Abo.Nucargabon =
                                                     Car.Nucaabasoc
                                                 AND Abo.Nucomp = Car.Nucomp),
                                         (SELECT LEAST (Car.Vamontfact, 410)
                                            FROM Fat_Cargabon Car
                                           WHERE     Car.Nucomp = Soli.Nucomp
                                                 AND Car.Nucargabon =
                                                     Soli.Nucargabon))
                                         Vamontdev,
                                     LEAST (
                                         (SELECT ROUND (
                                                       LEAST (Abo.Vamont, 410)
                                                     * Mgfn_Cambdiar (
                                                           Abo.Fccargo) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                       ,
                                                     --2)
                                                     1)
                                            FROM Fat_Cargabon Car,
                                                 Fat_Cargabon Abo
                                           WHERE     Car.Nucomp = Soli.Nucomp
                                                 AND Car.Nucargabon =
                                                     Soli.Nucargabon
                                                 AND Abo.Nucargabon =
                                                     Car.Nucaabasoc
                                                 AND Abo.Nucomp = Car.Nucomp),
                                           (SELECT LEAST (Car.Vamontfact, 410)
                                              FROM Fat_Cargabon Car
                                             WHERE     Car.Nucomp = Soli.Nucomp
                                                   AND Car.Nucargabon =
                                                       Soli.Nucargabon)
                                         * Mgfn_Cambdiar (Fcemis) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                  )
                                         Vamontdevbs,
                                     (SELECT COUNT (Todocu)
                                        FROM Clw_Docucons
                                       WHERE     Cdcuenalte =
                                                 TO_CHAR (Serv.Nucuen)
                                             AND Nucomp = Serv.Nucomp
                                             AND Idserv = 1
                                             AND Fcpago BETWEEN NVL (
                                                                    Fcapro,
                                                                      SYSDATE
                                                                    - 30)
                                                            AND   NVL (Fcapro,
                                                                       SYSDATE)
                                                                + 15
                                             AND Nucaje = 18293)
                                         Ctfactliqu,
                                     (SELECT NVL (
                                                 SUM (
                                                     ROUND (
                                                           Todocu
                                                         / Mgfn_Cambdiar (
                                                               Fcemis) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                      ,
                                                         2)),
                                                 0)
                                        FROM Clw_Docucons
                                       WHERE     Cdcuenalte =
                                                 TO_CHAR (Serv.Nucuen)
                                             AND Nucomp = Serv.Nucomp
                                             AND Idserv = 1
                                             AND Fcpago BETWEEN NVL (
                                                                    Fcapro,
                                                                      SYSDATE
                                                                    - 30)
                                                            AND   NVL (Fcapro,
                                                                       SYSDATE)
                                                                + 15
                                             AND Nucaje = 18293)
                                         Montoliqu,
                                     (SELECT NVL (SUM (Todocu), 0)
                                        FROM Clw_Docucons
                                       WHERE     Cdcuenalte =
                                                 TO_CHAR (Serv.Nucuen)
                                             AND Nucomp = Serv.Nucomp
                                             AND Idserv = 1
                                             AND Fcpago BETWEEN NVL (
                                                                    Fcapro,
                                                                      SYSDATE
                                                                    - 30)
                                                            AND   NVL (Fcapro,
                                                                       SYSDATE)
                                                                + 15
                                             AND Nucaje = 18293)
                                         Montoliqubs,
                                     (SELECT NVL (
                                                 SUM (
                                                     ROUND (
                                                           Todocu
                                                         / Mgfn_Cambdiar (
                                                               Fcemis) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                      ,
                                                         2)),
                                                 0)
                                        FROM Clt_Docu
                                       WHERE     Cdcuenalte =
                                                 TO_CHAR (Soli.Nupagoexol)
                                             AND Nucomp = Serv.Nucomp
                                             AND Idserv = 8)
                                         Montodev,
                                     (SELECT SUM (Topago)
                                        FROM Faw_Pagoexol
                                       WHERE     Tipagoexol = 'D'
                                             AND Cdcargabon = 2
                                             AND Nuserv = Soli.Nuserv
                                             AND Nucomp = Serv.Nucomp
                                             AND Stregi = 'R'
                                             AND Stpago IN ('E',
                                                            'P',
                                                            'L',
                                                            'C'))
                                         Todocusus,
                                     (SELECT NVL (SUM (Todocu), 0)
                                        FROM Clt_Docu
                                       WHERE     Cdcuenalte =
                                                 TO_CHAR (Soli.Nupagoexol)
                                             AND Nucomp = Serv.Nucomp
                                             AND Idserv = 8)
                                         Montodevbs,
                                     (SELECT MAX (Dsnomb)
                                        FROM Faw_Pagoexol
                                       WHERE     Tipagoexol = 'D'
                                             AND Cdcargabon = 2
                                             AND Nuserv = Soli.Nuserv
                                             AND Nucomp = Serv.Nucomp
                                             AND Stregi = 'R'
                                             AND Stpago IN ('E',
                                                            'P',
                                                            'L',
                                                            'C'))
                                         Dsnomb,
                                     TRIM (Scpq_Devo.Fn_Nombresocio (Nusoci))
                                         Dsnombok
                                FROM Sot_Serv    Serv,
                                     Sct_Solidevo Soli,
                                     Sct_Cuaddevo Cuad
                               WHERE                      --cuad.idcuad=93 and
                                         --cuad.stcuad not in ('EMI') and
                                         Soli.Nucomp = Pnucomp
                                     AND Soli.Nuserv = Pnuserv
                                     AND Soli.Idcuaddevo = Cuad.Idcuad
                                     AND Soli.Nuserv = Soli.Nuserv + 0
                                     AND Soli.Nucomp = Soli.Nucomp + 0
                                     AND Soli.Nucomp = Serv.Nucomp
                                     AND Soli.Nuserv = Serv.Nuserv
                                     AND Serv.Nucuen = Serv.Nucuen + 0 --and serv.nucuen IN (201180)
                                                                      --and serv.nuserv=18819203
                                                                      --and nupagoexol>0
                                                                      ) Re) R2
               WHERE     Idcuad = Idcuad + 0
                     --AND Idcuad = Pidcuad
                     --nupagoexol is not null
                     --and nupagoexol=1275845
                     --and stpago in ('R','E','P','L','C','V')
                     AND NOT (    Obsdev1 = 'OK'
                              AND Obsdev2 = 'OK'
                              AND Obsdev3 = 'OK'
                              AND Obsdev4 = 'OK'
                              AND Obsdev5 = 'OK'
                              AND Obsdev6 = 'OK'
                              AND Obsdev7 = 'OK')
            ORDER BY Nupagoexol NULLS FIRST;

        CURSOR C_Pagadas (Pnucomp NUMBER, Pnucuen NUMBER, Pfc DATE)
        IS
            SELECT *
              FROM Clw_Docucons
             WHERE     Nucomp = Pnucomp
                   AND Cdcuenalte = TO_CHAR (Pnucuen)
                   AND Idserv = 1
                   AND Fcpago >= TRUNC (Pfc)
                   AND Nucaje = 18293;

        Monto_Pagadas      NUMBER;
        Cantidad_Pagadas   NUMBER;
    BEGIN
        FOR Liqui IN Trae_Liqui
        LOOP
            IF Liqui.Nupagoexol IS NOT NULL
            THEN
                IF Liqui.Stpago IN ('R', 'E', 'P')
                THEN
                    DBMS_OUTPUT.Put_Line (
                        'Corrigiendo Nupagoexol: ' || Liqui.Nupagoexol);

                    --ACTUALIZANDO LOS MONTOS A CERO
                    UPDATE Fad_Pagoexol
                       SET Mopago = 1
                     WHERE Nupagoexol = Liqui.Nupagoexol;

                    UPDATE Fam_Pagoexol
                       SET Topago = 1, Imtotabs = 1, Fcmodi = SYSDATE
                     WHERE Nupagoexol = Liqui.Nupagoexol;

                    UPDATE Fad_Pagoextr
                       SET Mopago = 1
                     WHERE Nupagoextr = Liqui.Nupagoextr;

                    UPDATE Fam_Pagoextr
                       SET Vamont = 1
                     WHERE Nupagoextr = Liqui.Nupagoextr;

                    UPDATE Fat_Cargabon
                       SET Vamontfact = 1
                     WHERE Nucargabon = Liqui.Abono AND Nucomp = Liqui.Nucomp;

                    IF Liqui.Stpago = 'R'
                    THEN
                        Fapq_Pagoextr.Pr_Emitepago (
                            Liqui.Nupagoexol,
                            Va_Dsmens,
                            TRUNC (SYSDATE, 'DD'),
                            TRUNC (SYSDATE + 720, 'DD'));
                        DBMS_OUTPUT.Put_Line (
                               'Emitiendo Nupagoexol: '
                            || Liqui.Nupagoexol
                            || '  RESULTADO:'
                            || Va_Dsmens);
                        COMMIT;
                    END IF;

                    --ACTUALIZANDO LOS MONTOS OK
                    UPDATE Fad_Pagoexol
                       SET Mopago =
                               ROUND (
                                     (Liqui.Vamontdevbs - Liqui.Montoliqubs) /*OJO*/
                                   / (Liqui.ticamb) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                 ,
                                   2)
                     WHERE Nupagoexol = Liqui.Nupagoexol;

                    UPDATE Fam_Pagoexol
                       SET Topago =
                               ROUND (
                                     (Liqui.Vamontdevbs - Liqui.Montoliqubs)
                                   /  (Liqui.ticamb) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                 ,
                                   2),
                           Imtotabs = Liqui.Vamontdevbs - Liqui.Montoliqubs
                     WHERE Nupagoexol = Liqui.Nupagoexol;

                    UPDATE Fad_Pagoextr
                       SET Mopago =
                               ROUND (
                                     (Liqui.Vamontdevbs - Liqui.Montoliqubs)
                                   /  (Liqui.ticamb) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                 ,
                                   2)
                     WHERE Nupagoextr = Liqui.Nupagoextr;

                    UPDATE Fam_Pagoextr
                       SET Vamont =
                               ROUND (
                                     (Liqui.Vamontdevbs - Liqui.Montoliqubs)
                                   /  (Liqui.ticamb) /*6.96  igorcb:29/06/2026 el tipo de cambio deja de estar harcodeado */
                                                                 ,
                                   2)
                     WHERE Nupagoextr = Liqui.Nupagoextr;

                    UPDATE Fat_Cargabon
                       SET Vamontfact = Liqui.Vamontfact
                     WHERE Nucargabon = Liqui.Abono AND Nucomp = Liqui.Nucomp;

                    IF Liqui.Stpago = 'P'
                    THEN
                        UPDATE Fam_Pagoexol
                           SET Stpago = 'E'
                         WHERE Nupagoexol = Liqui.Nupagoexol;
                    END IF;

                    COMMIT;
                END IF;
            END IF;

            -------------------------------


            UPDATE Sct_Solidevo S
               SET Nupagoexol =
                       (SELECT Nupagoexol
                          FROM Fam_Pagoexol
                         WHERE Nucomp = S.Nucomp AND Nuserv = S.Nuserv)
             WHERE     Nucomp = Pnucomp
                   AND Nuserv = Pnuserv
                   AND Nupagoexol IS NULL;

            DELETE Sce_Devofact
             WHERE Nucomp = Pnucomp AND Nuserv = Pnuserv;


            Monto_Pagadas := 0;
            Cantidad_Pagadas := 0;

            FOR Fact IN C_Pagadas (Liqui.Nucomp, Liqui.Nucuen, Liqui.Fcregi)
            LOOP
                --insertar factura pagada
                INSERT INTO Sce_Devofact (Nucomp,
                                          Nuserv,
                                          Nudocu,
                                          Dstabl)
                     VALUES (Pnucomp,
                             Pnuserv,
                             Fact.Nudocu,
                             'DCT_DOCU');

                -- incrementar monto
                Monto_Pagadas := Monto_Pagadas + Fact.Todocu;

                Cantidad_Pagadas := Cantidad_Pagadas + 1;
            END LOOP;

            DBMS_OUTPUT.Put_Line (
                   Pnucomp
                || ' '
                || Pnuserv
                || 'Monto_Pagadas = '
                || Monto_Pagadas);

            --actualizar resumen de la solicitud
            UPDATE Sct_Solidevo S
               SET S.Topagofact = Monto_Pagadas
             WHERE Nucomp = Pnucomp AND Nuserv = Pnuserv;
        END LOOP;

        Pr_Actualizadevo (Pnucomp, Pnuserv);
    -- Sgc_Cb.Cbpq_Coblinweb_Pagoextr.Pr_Publicadocu (1, 1);
    END;

    PROCEDURE Pr_Actualizadevo (Pnucomp NUMBER, Pnuserv NUMBER)
    IS
    BEGIN
        UPDATE Sct_Solidevo S
           SET Vamontfact =
                   (SELECT LEAST (Abo.Vamont, 410)
                      FROM Fat_Cargabon Car, Fat_Cargabon Abo
                     WHERE     Car.Nucomp = S.Nucomp
                           AND Car.Nucargabon = S.Nucargabon
                           AND Abo.Nucargabon = Car.Nucaabasoc
                           AND Abo.Nucomp = Car.Nucomp),
               Vamontfactbs =
                   (SELECT ROUND (LEAST (Abo.Vamont, 410) * Mgfn_Tipocamb, 1) --2)
                      FROM Fat_Cargabon Car, Fat_Cargabon Abo
                     WHERE     Car.Nucomp = S.Nucomp
                           AND Car.Nucargabon = S.Nucargabon
                           AND Abo.Nucargabon = Car.Nucaabasoc
                           AND Abo.Nucomp = Car.Nucomp),
               Vamontcobr =
                   (SELECT Vamontcobr
                      FROM Fat_Cargabon
                     WHERE Nucomp = S.Nucomp AND Nucargabon = S.Nucargabon),
               Vamontcobrbs =
                     (SELECT Vamontcobr
                        FROM Fat_Cargabon
                       WHERE Nucomp = S.Nucomp AND Nucargabon = S.Nucargabon)
                   * Mgfn_Tipocamb,
               Toordedevo =
                   (SELECT Topago
                      FROM Fam_Pagoexol
                     WHERE Nupagoexol = S.Nupagoexol),
               Toordedevobs =
                   (SELECT Imtotabs
                      FROM Fam_Pagoexol
                     WHERE Nupagoexol = S.Nupagoexol)
         WHERE Nucomp = Pnucomp AND Nuserv = Pnuserv;
    END;

    PROCEDURE Pr_Prevalidarcuadro (Pidcuad NUMBER,
                                   Opexitosa OUT VARCHAR2,
                                   Pmensaje OUT VARCHAR2)
    IS
        l_cantidad_solicitudes NUMBER := 0;
        l_cantidad_abonos       NUMBER;
        l_abono                 NUMBER;
        l_saldo_abono           NUMBER;
        l_tope_facturas_bs      NUMBER;
        l_importe_oficial_bs    NUMBER;
        l_tipo_cambio           NUMBER;
        l_topagofact            NUMBER;
        l_estado_remoto         VARCHAR2(3);
        l_cantidad_remota       NUMBER;
        l_cantidad_pagos        NUMBER;
        l_estado_pago            VARCHAR2(1);
        l_errores               VARCHAR2(32767);

        PROCEDURE agregar_error (Ptexto VARCHAR2) IS
        BEGIN
            l_errores := l_errores || CASE WHEN l_errores IS NULL THEN NULL ELSE CHR(10) END
                         || Ptexto;
        END;
    BEGIN
        Opexitosa := 'N';
        Pmensaje := NULL;

        FOR Solicitud IN (
            SELECT Sol.Nucomp,
                   Sol.Nuserv,
                   Sol.Nucargabon,
                   Sol.Stsolidevo,
                   Sol.Nupagoexol,
                   Serv.Nucuen,
                   Serv.Stserv
              FROM Sct_Solidevo Sol
              JOIN Sot_Serv Serv
                ON Serv.Nucomp = Sol.Nucomp
               AND Serv.Nuserv = Sol.Nuserv
             WHERE Sol.Idcuaddevo = Pidcuad
               AND Sol.Stregi = 'R'
             ORDER BY Sol.Nucomp, Sol.Nuserv
        ) LOOP
            l_cantidad_solicitudes := l_cantidad_solicitudes + 1;

            IF Solicitud.Stsolidevo = 'LIQ' THEN
                agregar_error('Solicitud ' || Solicitud.Nucomp || '-' || Solicitud.Nuserv
                              || ': tiene una liquidacion incierta pendiente de conciliacion.');
                CONTINUE;
            END IF;

            IF Solicitud.Nupagoexol IS NOT NULL THEN
                SELECT COUNT(*), MAX(Car.Nucaabasoc)
                  INTO l_cantidad_abonos, l_abono
                  FROM Fat_Cargabon Car
                 WHERE Car.Nucomp = Solicitud.Nucomp
                   AND Car.Nucargabon = Solicitud.Nucargabon
                   AND Car.Stregi = 'R';
                IF l_cantidad_abonos <> 1 OR l_abono IS NULL THEN
                    agregar_error('Solicitud ' || Solicitud.Nucomp || '-' || Solicitud.Nuserv
                                  || ': no tiene un abono asociado unico para validar el pago.');
                    CONTINUE;
                END IF;
                SELECT COUNT(DISTINCT P.Nupagoexol), MAX(P.Stpago)
                  INTO l_cantidad_pagos, l_estado_pago
                  FROM Fam_Pagoexol P
                 WHERE P.Nupagoexol = Solicitud.Nupagoexol
                    AND P.Nucomp = Solicitud.Nucomp
                    AND P.Stregi = 'R'
                    AND P.Tipagoexol = 'D'
                    AND EXISTS (
                        SELECT 1
                          FROM Faw_Pagoexol D
                         WHERE D.Nupagoexol = P.Nupagoexol
                           AND D.Nucomp = Solicitud.Nucomp
                           AND D.Nucargabon = l_abono);
                IF l_cantidad_pagos <> 1 OR l_estado_pago NOT IN ('R', 'E', 'P', 'L', 'C') THEN
                    agregar_error('Solicitud ' || Solicitud.Nucomp || '-' || Solicitud.Nuserv
                                  || ': el pago asociado no es unico o no permite reanudacion.');
                END IF;
                CONTINUE;
            END IF;

            IF Solicitud.Stsolidevo <> 'CUA' OR Solicitud.Stserv <> 'E' THEN
                agregar_error('Solicitud ' || Solicitud.Nucomp || '-' || Solicitud.Nuserv
                              || ': estado de solicitud o servicio no aprobable.');
                CONTINUE;
            END IF;

            SELECT COUNT(*), MAX(Car.Nucaabasoc)
              INTO l_cantidad_abonos, l_abono
              FROM Fat_Cargabon Car
             WHERE Car.Nucomp = Solicitud.Nucomp
               AND Car.Nucargabon = Solicitud.Nucargabon
               AND Car.Stregi = 'R';

            IF l_cantidad_abonos <> 1 OR l_abono IS NULL THEN
                agregar_error('Solicitud ' || Solicitud.Nucomp || '-' || Solicitud.Nuserv
                              || ': no tiene un abono asociado unico.');
                CONTINUE;
            END IF;

            SELECT Vamont - Vamontfact
              INTO l_saldo_abono
              FROM Fat_Cargabon
             WHERE Nucomp = Solicitud.Nucomp
               AND Nucargabon = l_abono
               AND Stregi = 'R'
               AND Cdcargabon = 2
               AND Ticargabon = 'A';

            l_importe_oficial_bs := Scpq_Devobs.Fn_Imtotabs(
                                        Solicitud.Nucomp,
                                        Solicitud.Nucargabon
                                    );
            l_tipo_cambio := Mgfn_Tipocamb;
            l_tope_facturas_bs := LEAST(
                ROUND(l_saldo_abono * l_tipo_cambio, 1),
                l_importe_oficial_bs
            );

            IF l_tope_facturas_bs <= 0 THEN
                agregar_error('Solicitud ' || Solicitud.Nucomp || '-' || Solicitud.Nuserv
                              || ': el tope oficial para facturas no es positivo.');
                CONTINUE;
            END IF;

            l_topagofact := 0;
            FOR Documento IN (
                SELECT D.Nudocu,
                       D.Todocu,
                       SUM(D.Todocu) OVER (
                           ORDER BY D.Andocu, D.Medocu, D.Nudocu
                           ROWS UNBOUNDED PRECEDING
                       ) Acumulado
                  FROM Dct_Docu D
                 WHERE D.Nucomp = Solicitud.Nucomp
                   AND D.Nucuen = Solicitud.Nucuen
                   AND D.Stpago = 'I'
                   AND D.Stfact = 'N'
            ) LOOP
                EXIT WHEN Documento.Acumulado > l_tope_facturas_bs;

                SELECT COUNT(*), MAX(Remoto.Stdocu)
                  INTO l_cantidad_remota, l_estado_remoto
                  FROM Clt_Docu Remoto
                 WHERE Remoto.Nucomp = Solicitud.Nucomp
                   AND Remoto.Idserv = 1
                   AND Remoto.Nudocu = TO_CHAR(Documento.Nudocu);

                IF l_cantidad_remota <> 1 OR l_estado_remoto <> 'EMI' THEN
                    agregar_error('Solicitud ' || Solicitud.Nucomp || '-' || Solicitud.Nuserv
                                  || ', factura ' || Documento.Nudocu
                                  || ': no esta disponible para pago en COBLIN.');
                ELSE
                    l_topagofact := l_topagofact + Documento.Todocu;
                END IF;
            END LOOP;

            IF l_importe_oficial_bs - l_topagofact < 0 THEN
                agregar_error('Solicitud ' || Solicitud.Nucomp || '-' || Solicitud.Nuserv
                              || ': la devolucion neta esperada es negativa.');
            END IF;
        END LOOP;

        IF l_cantidad_solicitudes = 0 THEN
            agregar_error('El cuadro no tiene solicitudes registradas.');
        END IF;

        IF l_errores IS NOT NULL THEN
            Pmensaje := SUBSTR(l_errores, 1, 1000);
            RETURN;
        END IF;

        Opexitosa := 'S';
        Pmensaje := 'Prevalidacion satisfactoria.';
    EXCEPTION
        WHEN OTHERS THEN
            Opexitosa := 'N';
            Pmensaje := SUBSTR('Error en prevalidacion: ' || SQLERRM, 1, 1000);
    END;

    PROCEDURE Pr_Registrar_Error_Cuadro (Pidcuad NUMBER,
                                         Petapa VARCHAR2,
                                         Perror VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        FOR Solicitud IN (
            SELECT Nucomp, Nuserv
              FROM Sct_Solidevo
             WHERE Idcuaddevo = Pidcuad
               AND Stregi = 'R'
        ) LOOP
            INSERT INTO Sct_Devolog (Nucomp, Nuserv, Dslog)
            VALUES (
                Solicitud.Nucomp,
                Solicitud.Nuserv,
                SUBSTR('[' || Petapa || '] ' || Perror, 1, 1000)
            );
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
    END;

    PROCEDURE Pr_Actualizacuadro (Pidcuad NUMBER)
    IS
        L_Ok               VARCHAR2(1);
        L_Mensaje          VARCHAR2(4000);

        CURSOR C_Importes IS
            SELECT Nucomp,
                   Nuserv,
                   Nucargabon,
                   Topagofact
              FROM Sct_Solidevo
             WHERE Idcuaddevo = Pidcuad
               AND Stregi = 'R'
             ORDER BY Nucomp, Nuserv;
    BEGIN
        --Pr_Arregla_Decimales (Pidcuad);

        UPDATE Sct_Solidevo S
           SET Nupagoexol =
                   (SELECT Nupagoexol
                      FROM Fam_Pagoexol
                     WHERE Nucomp = S.Nucomp AND Nuserv = S.Nuserv)
         WHERE Idcuaddevo = Pidcuad AND Nupagoexol IS NULL;

        Pr_Actualiza_Facturas_Pagadas (Pidcuad);

        UPDATE Sct_Solidevo S
           SET Vamontfact =
                   (SELECT LEAST (Abo.Vamont, 410)
                      FROM Fat_Cargabon Car, Fat_Cargabon Abo
                     WHERE     Car.Nucomp = S.Nucomp
                           AND Car.Nucargabon = S.Nucargabon
                           AND Abo.Nucargabon = Car.Nucaabasoc
                           AND Abo.Nucomp = Car.Nucomp),
              /* Vamontfactbs =
                   (SELECT ROUND (LEAST (Abo.Vamont, 410) * Mgfn_Tipocamb, 2)
                      FROM Fat_Cargabon Car, Fat_Cargabon Abo
                     WHERE     Car.Nucomp = S.Nucomp
                           AND Car.Nucargabon = S.Nucargabon
                           AND Abo.Nucargabon = Car.Nucaabasoc
                           AND Abo.Nucomp = Car.Nucomp),*/
               Vamontcobr =
                   (SELECT Vamontcobr
                      FROM Fat_Cargabon
                     WHERE Nucomp = S.Nucomp AND Nucargabon = S.Nucargabon),
              /* Vamontcobrbs =
                     (SELECT Vamontcobr
                        FROM Fat_Cargabon
                       WHERE Nucomp = S.Nucomp AND Nucargabon = S.Nucargabon)
                   * Mgfn_Tipocamb,*/
               Toordedevo =
                   (SELECT Topago
                      FROM Fam_Pagoexol
                     WHERE Nupagoexol = S.Nupagoexol)
               /*Toordedevobs =
                   (SELECT Imtotabs
                      FROM Fam_Pagoexol
                     WHERE Nupagoexol = S.Nupagoexol)*/
          WHERE Idcuaddevo = Pidcuad;

        -- Corrige los montos Bs. despues de que este procedimiento haya
        -- reconstruido TOPAGOFACT y aplicado sus actualizaciones generales.
        FOR Solicitud IN C_Importes
        LOOP
            Scpq_Devobs.Pr_Actualizabs(
                Solicitud.Nucomp,
                Solicitud.Nucargabon,
                NVL(Solicitud.Topagofact, 0),
                L_Ok,
                L_Mensaje
            );

            IF NVL(L_Ok, 'N') <> 'S' THEN
                RAISE_APPLICATION_ERROR(
                    -20150,
                    'No se pudieron actualizar los importes Bs. de la solicitud '
                    || Solicitud.Nucomp || '-' || Solicitud.Nuserv || ': '
                    || NVL(L_Mensaje, 'Error no informado.')
                );
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            Pr_Registrar_Error_Cuadro(
                Pidcuad,
                'SCPQ_DEVO.PR_ACTUALIZACUADRO',
                SQLERRM || CHR(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
            RAISE;
    END;

    PROCEDURE Pr_Asientocuadro (Pidcuad   NUMBER,
                                Pnuasie   VARCHAR2,
                                Ptiasie   VARCHAR2)
    IS
    BEGIN
        INSERT INTO Sce_Asiecuaddevo (Idcuad,
                                      Nuasie,
                                      Tiasie,
                                      Nuemplregi)
             VALUES (Pidcuad,
                     Pnuasie,
                     Ptiasie,
                     Mgpq_Seguacce.Fn_Traernuempl);
    END;

    PROCEDURE Pr_Asientosolicitud (Pnucomp   NUMBER,
                                   Pnuserv   NUMBER,
                                   Pnuasie   VARCHAR2,
                                   Ptiasie   VARCHAR2)
    IS
    BEGIN
        INSERT INTO Sce_Asiedevo (Nucomp,
                                  Nuserv,
                                  Nuasie,
                                  Tiasie,
                                  Nuemplregi)
             VALUES (Pnucomp,
                     Pnuserv,
                     Pnuasie,
                     Ptiasie,
                     Mgpq_Seguacce.Fn_Traernuempl);
    END;

    PROCEDURE Pr_Asientopagos (Fc DATE DEFAULT SYSDATE)
    IS
        Pnuasie            VARCHAR2 (100);
        Poperok            VARCHAR2 (1);
        Pmensoper          VARCHAR2 (10000);

        CURSOR Csolicitud IS
              SELECT *
                FROM Sct_Solidevo S
               WHERE     Fcpagoorde BETWEEN TRUNC (Fc) - 30 AND TRUNC (Fc) + 1
                     AND Stregi = 'R'
                     AND NOT EXISTS
                             (SELECT 'x'
                                FROM Sce_Asiedevo
                               WHERE     Nucomp = S.Nucomp
                                     AND Nuserv = S.Nuserv
                                     AND Tiasie = '2')
            ORDER BY Nucomp, Nuserv;

        Operacionexitosa   BOOLEAN;
        Mensaje            VARCHAR2 (1000);
        Vcc                VARCHAR2 (1000) := 'igorcb@cre.com.bo';
    BEGIN
        /*Reformular si guido lo vuelve por servicio*/
        Scpq_Asiedevo.Pr_Insertarasientodos (Fc,
                                             Pnuasie,
                                             Poperok,
                                             Pmensoper);

        IF Poperok = 'S'
        THEN
            FOR S IN Csolicitud
            LOOP
                Pr_Asientosolicitud (S.Nucomp,
                                     S.Nuserv,
                                     Pnuasie,
                                     '2');
            END LOOP;

            /*Operacionexitosa   BOOLEAN;
        Mensaje            VARCHAR2 (1000);*/

            Pr_Sendmail (
                'sigecom@cre.com.bo',
                'marciamg@cre.com.bo',                -- Field To of the email
                    'Asiento por pago de devoluciones de certificado de aportaci¿n '
                || ' de fecha '
                || TO_CHAR (Fc, 'dd/mm/yyyy'),         -- Subject of the email
                Vcc,                                              -- con copia
                   'Se ha generado el asiento n¿mero '
                || Pnuasie
                 || ' por pago de devoluciones de devoluci¿n de certificado de aportaci¿n '
                || ' de fecha '
                || TO_CHAR (Fc, 'dd/mm/yyyy'),
                Operacionexitosa,
                Mensaje);
        ELSE
            FOR S IN Csolicitud
            LOOP
                Pr_Logdevo (
                    S.Nucomp,
                    S.Nuserv,
                       'Al llamar Scpq_asiedevo.Pr_insertarasientodos '
                    || Pmensoper);
            END LOOP;
        END IF;
    END;

    PROCEDURE Pr_Asientovencimientos (Fc DATE DEFAULT SYSDATE)
    IS
        Pnuasie            VARCHAR2 (100);
        Poperok            VARCHAR2 (1);
        Pmensoper          VARCHAR2 (10000);

        CURSOR Csolicitud IS
              SELECT S.*
                FROM Sct_Solidevo S, Fam_Pagoexol P
               WHERE     P.Fcvenc BETWEEN TRUNC (Fc) - 30 AND TRUNC (Fc) + 1
                     AND S.Stregi = 'R'
                     AND P.Nupagoexol = S.Nupagoexol
                     AND NOT EXISTS
                             (SELECT 'x'
                                FROM Sce_Asiedevo
                               WHERE     Nucomp = S.Nucomp
                                     AND Nuserv = S.Nuserv
                                     AND Tiasie = '4')
            ORDER BY S.Nucomp, S.Nuserv;

        Operacionexitosa   BOOLEAN;
        Mensaje            VARCHAR2 (1000);
        Vcc                VARCHAR2 (1000) := 'igorcb@cre.com.bo';
    BEGIN
        FOR S IN Csolicitud
        LOOP
            Scpq_Asiedevo.Pr_Insertarasientocuatro (S.Nucomp,
                                                    S.Nuserv,
                                                    Pnuasie,
                                                    Poperok,
                                                    Pmensoper);


            /*Operacionexitosa   BOOLEAN;
            Mensaje            VARCHAR2 (1000);*/

            Pr_Sendmail (
                'sigecom@cre.com.bo',
                'marciamg@cre.com.bo',                -- Field To of the email
                   'Asiento por vencimiento de devoluci¿n de certificado de aportaci¿n '
                || S.Nucomp
                || ' - '
                || S.Nuserv,                           -- Subject of the email
                Vcc,                                              -- con copia
                   'Se ha generado el asiento n¿mero '
                || Pnuasie
                 || ' por vencimiento de devoluci¿n de certificado de aportaci¿n '
                || S.Nucomp
                || ' - '
                || S.Nuserv,                              -- Body of the email
                Operacionexitosa,
                Mensaje);

            IF Poperok = 'S'
            THEN
                Pr_Asientosolicitud (S.Nucomp,
                                     S.Nuserv,
                                     Pnuasie,
                                     '4');
            ELSE
                Pr_Logdevo (
                    S.Nucomp,
                    S.Nuserv,
                       'Al llamar Scpq_asiedevo.Pr_insertarasientocuatro '
                    || Pmensoper);
            END IF;
        END LOOP;
    END;

    PROCEDURE Pr_Datospago (Pnucomp       NUMBER,
                            Pnuserv       NUMBER,
                            Ctfact    OUT NUMBER,
                            Mofact    OUT NUMBER)
    IS
        Lctfact         NUMBER;
        Lmofact         NUMBER;

        CURSOR Cdatos IS
              SELECT S.Nucuen,
                     S.Stserv,
                     SUM (Todocu)     Mofact,
                     COUNT (*)        Ctfact
                FROM Sot_Serv S, Sce_Devofact D, Dct_Docu F
               WHERE     S.Nucomp = Pnucomp
                     AND S.Nuserv = Pnuserv
                     AND D.Nucomp = S.Nucomp
                     AND D.Nuserv = S.Nuserv
                     AND F.Nucomp = D.Nucomp
                     AND F.Nudocu = D.Nudocu
            GROUP BY S.Nucuen, S.Stserv;

        Pnucuen         NUMBER;
        Lstserv         Sot_Serv.Stserv%TYPE;

        CURSOR C_Fact (Pmonto NUMBER)
        IS
              SELECT *
                FROM (  SELECT COUNT (*)
                                   OVER (
                                       PARTITION BY Nucomp, Nucuen
                                       ORDER BY
                                           Andocu,
                                           Medocu,
                                           Nudocu,
                                           Fcemis
                                       ROWS BETWEEN UNBOUNDED PRECEDING
                                            AND     CURRENT ROW)    Nuorde,
                               SUM (Todocu)
                                   OVER (
                                       PARTITION BY Nucomp, Nucuen
                                       ORDER BY
                                           Andocu,
                                           Medocu,
                                           Nudocu,
                                           Fcemis
                                       ROWS BETWEEN UNBOUNDED PRECEDING
                                            AND     CURRENT ROW)    Moacum,
                                  LPAD (D.Medocu, 2, '0')
                               || '/'
                               || LPAD (D.Andocu, 4, '0')           Dsperi,
                               D.Nudocu,
                               D.Nucomp,
                               D.Nucuen,
                               D.Andocu,
                               D.Medocu,
                               D.Todocu
                          FROM Dct_Docu D
                         WHERE     Stpago = 'I'
                               AND Opbloq = 'N'
                               AND Stfact = 'N'
                               AND Tidocu = 'A'
                               AND Nucomp = Pnucomp
                               AND Nucuen = Pnucuen
                      --NO VENCIDOS
                      ORDER BY Andocu,
                               Medocu,
                               Nudocu,
                               Fcemis)
               WHERE Moacum <= Pmonto
            ORDER BY Nuorde DESC;

        L_Fact          C_Fact%ROWTYPE;

        CURSOR C_Fat_Cargabon IS
            SELECT *
              FROM Fat_Cargabon
             WHERE     Nucomp = Pnucomp
                   AND Nucuen = Pnucuen
                   AND Cdcargabon = 2
                   AND Stregi = 'R'
                   AND Ticargabon = 'C';

        Lfat_Cargabon   C_Fat_Cargabon%ROWTYPE;

        CURSOR C_Serv IS
            SELECT Nucuen, Stserv
              FROM Sot_Serv
             WHERE Nucomp = Pnucomp AND Nuserv = Pnuserv;
    BEGIN
        OPEN Cdatos;

        FETCH Cdatos
            INTO Pnucuen,
                 Lstserv,
                 Lmofact,
                 Lctfact;

        CLOSE Cdatos;

        OPEN C_Serv;

        FETCH C_Serv INTO Pnucuen, Lstserv;

        CLOSE C_Serv;

        IF Lstserv = 'P'
        THEN
            Ctfact := Lctfact;
            Mofact := Lmofact;
        ELSE
            OPEN C_Fat_Cargabon;

            FETCH C_Fat_Cargabon INTO Lfat_Cargabon;

            CLOSE C_Fat_Cargabon;

            OPEN C_Fact (
                LEAST (Lfat_Cargabon.Vamontcobr, 410) * Mgfn_Tipocamb);

            FETCH C_Fact INTO L_Fact;

            CLOSE C_Fact;

            Ctfact := L_Fact.Nuorde;
            Mofact := L_Fact.Moacum;
        END IF;
    END;

    FUNCTION Fn_Ctfactpago (Pnucomp NUMBER, Pnuserv NUMBER)
        RETURN NUMBER
    IS
        Ctfact   NUMBER;
        Mofact   NUMBER;
    BEGIN
        Pr_Datospago (Pnucomp,
                      Pnuserv,
                      Ctfact,
                      Mofact);
        RETURN NVL (Ctfact, 0);
    END;

    FUNCTION Fn_Mofactpago (Pnucomp NUMBER, Pnuserv NUMBER)
        RETURN NUMBER
    IS
        Ctfact   NUMBER;
        Mofact   NUMBER;
    BEGIN
        Pr_Datospago (Pnucomp,
                      Pnuserv,
                      Ctfact,
                      Mofact);
        RETURN NVL (Mofact, 0);
    END;

    PROCEDURE Pr_Generadevolucion (P_Nucomp                  NUMBER,
                                   P_Cdmoti                  VARCHAR2,
                                   P_Nucuen                  NUMBER,
                                   P_Nusocirenu              NUMBER,
                                   P_Nuclierenu              NUMBER,
                                   P_Idcert                  NUMBER,
                                   P_Dtserv                  VARCHAR2,
                                   P_Nuempl                  NUMBER,
                                   P_Nuofic                  NUMBER,
                                   P_Nuserv           IN OUT NUMBER,
                                   P_Nucart                  NUMBER,
                                   P_Fccart                  DATE,
                                   P_Nutele                  VARCHAR2,
                                   P_Opcertmedi              VARCHAR2,
                                   P_Oprequ                  VARCHAR2,
                                   P_Oppagodeud              VARCHAR2,
                                   Operacionexitosa   IN OUT BOOLEAN,
                                   Mensaje            IN OUT VARCHAR2)
    IS
        Vfceven               DATE;
        Rcertserv             Soe_Certserv%ROWTYPE;
        Rservabre             Sopq_Datoserv.Tservabre;
        Rctrlserv             Sopq_Datoserv.Tctrlserv;
        Rservsoci             Sct_Serv%ROWTYPE;
        -- Datos para generar el servicio de Baja de Socio
        Vcdmoti               Sct_Serv.Cdmoti%TYPE;
        Vdtserv               Sot_Serv.Dtserv%TYPE;
        Vnuserv               Sot_Serv.Nuserv%TYPE;
        Vnucuen               Sot_Serv.Nucuen%TYPE := 0;
        Errordevolucion       EXCEPTION;
        Errorrequisitos       EXCEPTION;
        Errorobservacion      EXCEPTION;
        Nresp                 NUMBER (3);
        Lnucargabon           NUMBER;
        Lvamontcobr           NUMBER;

        CURSOR C_Nucargabon IS
            SELECT C.Nucargabon, F.Vamontcobr
              FROM Scm_Cert C, Fat_Cargabon F
             WHERE C.Idcert = P_Idcert AND F.Nucargabon = C.Nucargabon;

        CURSOR Traeoficserv IS
            SELECT Nuoficemis
              FROM Sot_Serv
             WHERE Nuserv = P_Nuserv AND Nucomp = P_Nucomp;

        Vnuofic               Sot_Serv.Nuoficemis%TYPE;
        Vnutrab               NUMBER;
        Rtrabajo              Sopq_Datotrab.Ttrabajo;
        Listoparaprocesarse   BOOLEAN;
        Ultcarg               NUMBER;
        Lnucuen               NUMBER := P_Nucuen;
    -- Lnuserv               NUMBER := P_Nuserv;
    BEGIN
        LOOP
            SELECT MAX (Nucargabon)
              INTO Ultcarg
              FROM Fat_Cargabon
             WHERE Nucomp = P_Nucomp;

            IF Mgpq_Secu.Fn_Siguientevalor (P_Nucomp, 'nucargabon') > Ultcarg
            THEN
                EXIT;
            END IF;
        END LOOP;

        -- Construye la estructura del certificado a enviar al servicio
        Rcertserv.Idcert := P_Idcert;


        Scpq_Servsoci.Pr_Genedevolapor (P_Nucomp,
                                        P_Cdmoti,
                                        Lnucuen,
                                        P_Nusocirenu,
                                        P_Idcert,
                                        P_Dtserv,
                                        P_Nuempl,
                                        P_Nuofic,
                                        P_Nuserv,
                                        Vfceven,
                                        Operacionexitosa,
                                        Mensaje,
                                        P_Nucart,
                                        FALSE           --NO DEBE HACER COMMIT
                                             );



        IF NOT Operacionexitosa
        THEN
            RAISE Errordevolucion;
        END IF;

        /*20/11/2018
        Igor Cabrera
           1. No debe cerrar el servicio en el procedimiento scpq_servsoci.Pr_GeneDevolApor, el servicio debe quedar como emitido
               2. Se debe hacer insert en sct_solidevo
                2.1 Se debe crear la devoluci¿n en fam_pagoexol igual que en la FARG436 ver paquete con David
               3. Si se ha marcado que Cumple Requisitos se debe crear el trabajo requisitos
               4. Si no se ha marcado que Cumple Requisitos se debe pedir una glosa y observar el servicio
               5. Se debe poner el certificado en estado BLQ
                6. Se debe cambiar la afiliaci¿n de la cuenta
                7. Se debe dar de baja al socio si es su ¿nico certificado
        */
        --2. inserta solicitud en en sct_solidevo
        OPEN C_Nucargabon;

        FETCH C_Nucargabon INTO Lnucargabon, Lvamontcobr;

        CLOSE C_Nucargabon;

        INSERT INTO Sct_Solidevo (Nucomp,
                                  Nuserv,
                                  Nusoci,
                                  Nutele,
                                  Idcert,
                                  Nucargabon,
                                  Vamontcobr,
                                  Fccart,
                                  Nuemplregi,
                                  Oppagodeud,
                                  Oprequ,
                                  Opcertmedi)
             VALUES (P_Nucomp,
                     P_Nuserv,
                     P_Nusocirenu,
                     P_Nutele,
                     P_Idcert,
                     Lnucargabon,
                     Lvamontcobr,
                     P_Fccart,
                     Mgpq_Seguacce.Fn_Traernuempl,
                     P_Oppagodeud,
                     P_Oprequ,
                     P_Opcertmedi);


        Vnucuen := P_Nucuen;


        --- PARA QUE FALLE



        Sopq_Cierserv.Pr_Enviaconceptos (
            P_Nucomp,                               --IN SOT_SERV.nucomp%TYPE,
            P_Nuserv,                               --IN SOT_SERV.nuserv%TYPE,
            P_Nucuen,                               --IN Sot_Serv.nucuen%TYPE,
            Sopq_Paramodu.Fn_Devolucionaportacion,
            --p_cdserv            --IN sot_serv.cdserv%TYPE,
            P_Cdmoti,                               --IN sot_serv.cdmoti%TYPE,
            Mgpq_Seguacce.Fn_Traernuempl,
            --prm_nuEmpl                 In sot_serv.nuEmplEmis%Type,
            Operacionexitosa,
            Mensaje);

        IF Operacionexitosa
        THEN
             --Se da de baja si fue su ¿ltimo certificado
            IF NOT Scpq_Certificados.Fn_Consulta_Por_Persona (P_Nuclierenu)
            THEN
                Scpq_Socios.Pr_Bajasocio (P_Nucomp,
                                          P_Nuserv,
                                          Operacionexitosa,
                                          Mensaje);

                IF Operacionexitosa
                THEN
                    COMMIT;
                ELSE
                    Mensaje := ('ERROR Al dar de Baja al socio:' || Mensaje);
                    ROLLBACK;
                    RETURN;
                END IF;
            END IF;
        ELSE
            Mensaje :=
                'ERROR: en sopq_cierserv.Pr_EnviaConceptos ' || Mensaje;
            ROLLBACK;
            RETURN;
        END IF;
    EXCEPTION
        WHEN Errordevolucion
        THEN
            NULL;
        WHEN Errorrequisitos
        THEN
            NULL;
        WHEN Errorobservacion
        THEN
            NULL;
        WHEN OTHERS
        THEN
            Mensaje := 'ERROR:' || SQLERRM;
    END;

    PROCEDURE Pr_Actualiza_Facturas_Pagadas (Pidcuad NUMBER)
    IS
        CURSOR C_Solicitudes IS
            SELECT S.Nucomp,
                   S.Nucuen,
                   S.Nuserv,
                   D.Nucargabon,
                   S.Fcregi
              FROM Sct_Solidevo D, Sot_Serv S
             WHERE     D.Idcuaddevo = Pidcuad
                   AND D.Stregi = 'R'
                   AND S.Nucomp = D.Nucomp
                   AND S.Nuserv = D.Nuserv --and s.nucomp=8 and s.nuserv=83343
                                          ;

        CURSOR C_Pagadas (Pnucomp NUMBER, Pnucargabon NUMBER)
        IS
            SELECT DISTINCT D.Nudocu,
                            D.Todocu
              FROM Fat_Cargabon CAR
              JOIN Fad_Pagoextr PD
                ON PD.Nucomp = CAR.Nucomp
               AND PD.Nucargabon = CAR.Nucaabasoc
              JOIN Fam_Pagoextr PM
                ON PM.Nucomp = PD.Nucomp
               AND PM.Nupagoextr = PD.Nupagoextr
               AND PM.Stpago = 'P'
               AND NVL(PM.Nuserv, 0) = 0
               AND PM.Nudepo IS NOT NULL
              JOIN Dct_Docu D
                ON D.Nucomp = PM.Nucomp
               AND D.Nudocu = PM.Nudepo
             WHERE CAR.Nucomp = Pnucomp
               AND CAR.Nucargabon = Pnucargabon
               AND D.Stfact = 'N';

        Monto_Pagadas      NUMBER := 0;
        Cantidad_Pagadas   NUMBER := 0;
    BEGIN
        DELETE Sce_Devofact
         WHERE (Nucomp, Nuserv) IN (SELECT Nucomp, Nuserv
                                      FROM Sct_Solidevo
                                     WHERE Idcuaddevo = Pidcuad);

        FOR Sol IN C_Solicitudes
        LOOP
            Monto_Pagadas := 0;
            Cantidad_Pagadas := 0;

            FOR Fact IN C_Pagadas (Sol.Nucomp, Sol.Nucargabon)
            LOOP
                --insertar factura pagada
                INSERT INTO Sce_Devofact (Nucomp,
                                          Nuserv,
                                          Nudocu,
                                          Dstabl)
                     VALUES (Sol.Nucomp,
                             Sol.Nuserv,
                             Fact.Nudocu,
                             'DCT_DOCU');

                -- incrementar monto
                Monto_Pagadas := Monto_Pagadas + Fact.Todocu;

                Cantidad_Pagadas := Cantidad_Pagadas + 1;
            END LOOP;

            DBMS_OUTPUT.Put_Line (
                   Sol.Nucomp
                || ' '
                || Sol.Nuserv
                || 'Monto_Pagadas = '
                || Monto_Pagadas);

            --actualizar resumen de la solicitud
            UPDATE Sct_Solidevo S
               SET S.Topagofact = Monto_Pagadas
              WHERE Nucomp = Sol.Nucomp AND Nuserv = Sol.Nuserv;
        END LOOP;

    END;

    PROCEDURE Pr_Asientovencimiento (Pnucomp                NUMBER,
                                     Pnuserv                NUMBER,
                                     Pdtglos                VARCHAR2,
                                     Operacionexitosa   OUT VARCHAR2,
                                     Mensaje            OUT VARCHAR2)
    IS
        Vnuasie    VARCHAR2 (100);

        CURSOR Casiento IS
            SELECT *
              FROM Sce_Asiedevo
             WHERE     Nucomp = Pnucomp
                   AND Nuserv = Pnuserv
                   AND Nuasie = Vnuasie
                   AND Tiasie = '4';

        Vasiento   Casiento%ROWTYPE;
        Vcc        VARCHAR2 (1000) := 'robinghs@cre.com.bo';
        Opex       BOOLEAN;
    BEGIN
        Scpq_Asiedevo.Pr_Insertarasientocuatro (Pnucomp,
                                                Pnuserv,
                                                Vnuasie,
                                                Operacionexitosa,
                                                Mensaje);

        IF Operacionexitosa = 'S'
        THEN
            Opex := TRUE;
            Pr_Asientosolicitud (Pnucomp,
                                 Pnuserv,
                                 Vnuasie,
                                 '4');

            OPEN Casiento;

            FETCH Casiento INTO Vasiento;

            CLOSE Casiento;

            INSERT INTO Sce_Asievenc
                 VALUES (Vasiento.Id,
                         Pnucomp,
                         Pnuserv,
                         Pdtglos);

            COMMIT;
            Pr_Sendmail (
                'sigecom@cre.com.bo',
                'marciamg@cre.com.bo',                -- Field To of the email
                    'Asiento por vencimiento de orden de pago de devoluci¿n de certificado de aportaci¿n '
                || Pnucomp
                || ' - '
                || Pnuserv,                            -- Subject of the email
                Vcc,                                              -- con copia
                    'Se ha generado el asiento n¿mero '
                || Vnuasie
                 || ' por vencimiento de orden de pago de devoluci¿n de certificado de aportaci¿n '
                || Pnucomp
                || ' - '
                || Pnuserv,                               -- Body of the email
                Opex,
                Mensaje);
        END IF;
    END;

    PROCEDURE Pr_Anularpago (Pnupago           NUMBER,
                             Pcdmotianul       VARCHAR2,
                             Pdtmotianul       VARCHAR2,
                             Pidanulpago   OUT NUMBER,
                             Poperok       OUT BOOLEAN,
                             Pmensaje      OUT VARCHAR2)
    IS
        CURSOR Cdevolucion IS
            SELECT *
              FROM Fam_Pagoexol
             WHERE Nupagoexol = Pnupago;

        Vdevolucion               Cdevolucion%ROWTYPE;

        CURSOR Cpago (Prm_Nucomp NUMBER, Prm_Nuserv NUMBER)
        IS
            SELECT *
              FROM Fam_Pagoextr
             WHERE Nucomp = Prm_Nucomp AND Nuserv = Prm_Nuserv;

        Vpago                     Cpago%ROWTYPE;

        CURSOR Csolicitud (Prm_Nucomp NUMBER, Prm_Nuserv NUMBER)
        IS
            SELECT *
              FROM Sct_Solidevo
             WHERE Nucomp = Prm_Nucomp AND Nuserv = Prm_Nuserv;

        Vsolicitud                Csolicitud%ROWTYPE;

        CURSOR Ccargabon (Prm_Nucomp NUMBER, Prm_Nucargabon NUMBER)
        IS
            SELECT *
              FROM Fat_Cargabon
             WHERE Nucomp = Prm_Nucomp AND Nucargabon = Prm_Nucargabon;

        Vcargabon                 Ccargabon%ROWTYPE;
        Vcargabonasoc             Ccargabon%ROWTYPE;

        CURSOR Casiento (Prm_Nucomp NUMBER, Prm_Nuserv NUMBER)
        IS
              SELECT *
                FROM Sce_Asiedevo
               WHERE     Nucomp = Prm_Nucomp
                     AND Nuserv = Prm_Nuserv
                     AND Tiasie = 2
                     AND Stregi = 'R'
            ORDER BY Fcregi DESC;

        Vasiento                  Casiento%ROWTYPE;
        --
        Vnudocu                   VARCHAR2 (10);
        Vejercicio                NUMBER;
        Vestadoasiento            Sgc_So.Scpq_Asiedevo.Testadoasiento;
        --
        Vnuasie                   VARCHAR2 (20);
        Vidanulpago               NUMBER;
        Voperok                   VARCHAR2 (1);
        Noestadoasientoinvalido   EXCEPTION;
        Noinsertoasiento          EXCEPTION;
    BEGIN
        Poperok := FALSE;

        --
        OPEN Cdevolucion;

        FETCH Cdevolucion INTO Vdevolucion;

        CLOSE Cdevolucion;

        OPEN Cpago (Vdevolucion.Nucomp, Vdevolucion.Nuserv);

        FETCH Cpago INTO Vpago;

        CLOSE Cpago;

        OPEN Csolicitud (Vdevolucion.Nucomp, Vdevolucion.Nuserv);

        FETCH Csolicitud INTO Vsolicitud;

        CLOSE Csolicitud;

        OPEN Ccargabon (Vsolicitud.Nucomp, Vsolicitud.Nucargabon);

        FETCH Ccargabon INTO Vcargabon;

        CLOSE Ccargabon;

        OPEN Ccargabon (Vcargabon.Nucomp, Vcargabon.Nucaabasoc);

        FETCH Ccargabon INTO Vcargabonasoc;

        CLOSE Ccargabon;

        OPEN Casiento (Vdevolucion.Nucomp, Vdevolucion.Nuserv);

        FETCH Casiento INTO Vasiento;

        CLOSE Casiento;

        --
        Vnudocu := Vasiento.Nuasie;
        Vejercicio := TO_CHAR (Vasiento.Fcregi, 'yyyy');
        Sgc_So.Scpq_Asiedevo.Pr_Recuperarestadoasiento (Vnudocu,
                                                        Vejercicio,
                                                        Vestadoasiento,
                                                        Voperok,
                                                        Pmensaje);

        IF Voperok = 'S'
        THEN
            IF Vestadoasiento (1).Estado_Documento_Contable <>
               'SIN ANULAR Y SIN COMPENSAR'
            THEN
                RAISE Noestadoasientoinvalido;
            END IF;
        ELSE
            RAISE Noestadoasientoinvalido;
        END IF;

        Voperok := 'N';
        Pmensaje := NULL;
        --
        Scpq_Asiedevo.Pr_Insertarasientoseis (Vdevolucion.Nucomp,
                                              Vdevolucion.Nuserv,
                                              Vnuasie,
                                              Voperok,
                                              Pmensaje);

        IF Voperok = 'S'
        THEN
            Scpq_Devo.Pr_Asientosolicitud (Vdevolucion.Nucomp,
                                           Vdevolucion.Nuserv,
                                           Vnuasie,
                                           '6');
        ELSE
            RAISE Noinsertoasiento;
        END IF;

        --
        SELECT NVL (MAX (Idanulpago), 0) + 1
          INTO Vidanulpago
          FROM Ajt_Anulpago;

        INSERT INTO Ajt_Anulpago
             VALUES (Vidanulpago,
                     Vdevolucion.Nucomp,
                     Vdevolucion.Nupagoexol,
                     Vasiento.Nuasie,
                     Vnuasie,
                     Pcdmotianul,
                     Pdtmotianul,
                     'R',
                     SYSDATE,
                     Mgpq_Seguacce.Fn_Traernuempl,
                     NULL,
                     NULL);

        --
        UPDATE Sct_Solidevo
           SET Fcpagoorde = NULL
         WHERE Nucomp = Vdevolucion.Nucomp AND Nuserv = Vdevolucion.Nuserv;

        --
        UPDATE Fam_Pagoexol
           SET Stpago = 'E',
               Fcpago = NULL,
               Fcpagoreal = NULL,
               Fcmodi = SYSDATE,
               Nuemplmodi = Mgpq_Seguacce.Fn_Traernuempl,
               Nuentifina = NULL,
               Nuagen = NULL,
               Nucaje = NULL,
               Nutrancobl = NULL
         WHERE Nupagoexol = Vdevolucion.Nupagoexol;

        --
        UPDATE Fam_Pagoextr
           SET Fcpago = NULL,
               Nuentifina = 0,
               Nuagen = 0,
               Nudepo = NULL
         WHERE Nucomp = Vdevolucion.Nucomp AND Nuserv = Vdevolucion.Nuserv;

        --
        UPDATE Fat_Cargabon
           SET Stfact = 'I', Stcobr = 'I'
         WHERE     Nucomp = Vcargabon.Nucomp
               AND Nucargabon = Vcargabon.Nucargabon;

        --
        UPDATE Fat_Cargabon
           SET Stfact = 'I', Stcobr = 'I'
         WHERE     Nucomp = Vcargabonasoc.Nucomp
               AND Nucargabon = Vcargabonasoc.Nucargabon;

        --
        COMMIT;
        Poperok := TRUE;
        Pidanulpago := Vidanulpago;
    EXCEPTION
        WHEN Noestadoasientoinvalido
        THEN
            ROLLBACK;
            Poperok := FALSE;
            Pmensaje :=
                   'Error al validar el estado del asiento de pago. '
                || Pmensaje;
        WHEN Noinsertoasiento
        THEN
            ROLLBACK;
            Poperok := FALSE;
            Pmensaje :=
                    'Error al registrar el asiento de anulaci¿n de pago. '
                || Pmensaje;
        WHEN OTHERS
        THEN
            ROLLBACK;
            Poperok := FALSE;
            Pmensaje := 'Error no definido al anular el pago. ' || SQLERRM;
    END Pr_Anularpago;
    PROCEDURE Pr_Iniciar_Liquidacion (Pnucomp NUMBER, Pnucargabon NUMBER,
                                      Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        Opexitosa := 'N';
        Pmensaje := NULL;
        Pr_Tomar_Bloqueo(Pnucomp, Pnucargabon, Opexitosa, Pmensaje);
        IF Opexitosa <> 'S' THEN
            RETURN;
        END IF;
        UPDATE Sct_Solidevo S
           SET Stsolidevo = 'LIQ'
         WHERE S.Nucomp = Pnucomp
           AND S.Stregi = 'R'
           AND S.Stsolidevo = 'CUA'
           AND S.Nupagoexol IS NULL
           AND EXISTS (
                SELECT 1
                  FROM Fat_Cargabon Car
                 WHERE Car.Nucomp = S.Nucomp
                   AND Car.Nucargabon = S.Nucargabon
                   AND Car.Nucaabasoc = Pnucargabon
                   AND Car.Stregi = 'R');
        IF SQL%ROWCOUNT <> 1 THEN
            ROLLBACK;
            Pr_Soltar_Bloqueo;
            Pmensaje := 'La solicitud ya esta liquidandose, ya tiene pago o no esta disponible.';
            RETURN;
        END IF;
        COMMIT;
        Opexitosa := 'S';
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            Pr_Soltar_Bloqueo;
            Pmensaje := SUBSTR('No se pudo reservar la liquidacion: ' || SQLERRM, 1, 1000);
    END Pr_Iniciar_Liquidacion;

    PROCEDURE Pr_Finalizar_Liquidacion (Pnucomp NUMBER, Pnucargabon NUMBER,
                                        Pnupagoexol NUMBER,
                                        Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        Opexitosa := 'N';
        Pmensaje := NULL;
        IF Pnupagoexol IS NULL THEN
            Pmensaje := 'No se puede finalizar la liquidacion sin NUPAGOEXOL.';
            RETURN;
        END IF;
        Pr_Tomar_Bloqueo(Pnucomp, Pnucargabon, Opexitosa, Pmensaje);
        IF Opexitosa <> 'S' THEN
            RETURN;
        END IF;
        UPDATE Sct_Solidevo S
           SET Stsolidevo = 'CUA',
               Nupagoexol = Pnupagoexol
         WHERE S.Nucomp = Pnucomp
           AND S.Stregi = 'R'
           AND S.Stsolidevo IN ('LIQ', 'CUA')
           AND S.Nupagoexol IS NULL
           AND EXISTS (
                SELECT 1
                  FROM Fat_Cargabon Car
                 WHERE Car.Nucomp = S.Nucomp
                   AND Car.Nucargabon = S.Nucargabon
                   AND Car.Nucaabasoc = Pnucargabon);
        IF SQL%ROWCOUNT <> 1 THEN
            ROLLBACK;
            Pr_Soltar_Bloqueo;
            Pmensaje := 'No se pudo confirmar el checkpoint de liquidacion.';
            RETURN;
        END IF;
        COMMIT;
        Opexitosa := 'S';
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            Pr_Soltar_Bloqueo;
            Pmensaje := SUBSTR('No se pudo confirmar la liquidacion: ' || SQLERRM, 1, 1000);
    END Pr_Finalizar_Liquidacion;

    PROCEDURE Pr_Abortar_Liquidacion (Pnucomp NUMBER, Pnucargabon NUMBER,
                                      Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        Opexitosa := 'N';
        Pmensaje := NULL;
        Pr_Tomar_Bloqueo(Pnucomp, Pnucargabon, Opexitosa, Pmensaje);
        IF Opexitosa <> 'S' THEN
            RETURN;
        END IF;
        UPDATE Sct_Solidevo S
            SET Stsolidevo = 'CUA'
         WHERE S.Nucomp = Pnucomp
           AND S.Stregi = 'R'
           AND S.Stsolidevo = 'LIQ'
           AND S.Nupagoexol IS NULL
           AND EXISTS (
                SELECT 1
                  FROM Fat_Cargabon Car
                 WHERE Car.Nucomp = S.Nucomp
                   AND Car.Nucargabon = S.Nucargabon
                   AND Car.Nucaabasoc = Pnucargabon);
        IF SQL%ROWCOUNT <> 1 THEN
            ROLLBACK;
            Pr_Soltar_Bloqueo;
            Pmensaje := 'No se pudo liberar la solicitud en liquidacion.';
            RETURN;
        END IF;
        COMMIT;
        Opexitosa := 'S';
        Pr_Soltar_Bloqueo;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            Pr_Soltar_Bloqueo;
            Pmensaje := SUBSTR('No se pudo liberar la liquidacion: ' || SQLERRM, 1, 1000);
    END Pr_Abortar_Liquidacion;

    PROCEDURE Pr_Recuperar_Liquidacion (Pidcuad NUMBER,
                                        Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        Lrecuperadas NUMBER := 0;
        Lpendientes NUMBER := 0;
        Lnupagoexol NUMBER;
        Lcantidad NUMBER;
        Ldetalle VARCHAR2(1000);
        Labono NUMBER;
        Loplock VARCHAR2(1);
        Lmslock VARCHAR2(1000);
    BEGIN
        Opexitosa := 'S';
        Pmensaje := NULL;
        FOR S IN (SELECT Nucomp, Nuserv, Nucargabon
                    FROM Sct_Solidevo
                   WHERE Idcuaddevo = Pidcuad
                     AND Stregi = 'R'
                      AND Stsolidevo = 'LIQ') LOOP
            SELECT COUNT(*), MAX(Nucaabasoc)
              INTO Lcantidad, Labono
              FROM Fat_Cargabon
             WHERE Nucomp = S.Nucomp
               AND Nucargabon = S.Nucargabon
               AND Stregi = 'R';
            IF Lcantidad <> 1 OR Labono IS NULL THEN
                Lpendientes := Lpendientes + 1;
                Ldetalle := 'Solicitud ' || S.Nucomp || '-' || S.Nuserv
                   || ' permanece en LIQ; no se identifico el abono.';
                CONTINUE;
            END IF;
            Pr_Tomar_Bloqueo(S.Nucomp, Labono, Loplock, Lmslock);
            IF Loplock <> 'S' THEN
                Lpendientes := Lpendientes + 1;
                Ldetalle := 'Solicitud ' || S.Nucomp || '-' || S.Nuserv
                   || ' sigue activa en otra sesion.';
                CONTINUE;
            END IF;
            Lnupagoexol := NULL;
            Lcantidad := 0;
            SELECT COUNT(DISTINCT P.Nupagoexol), MAX(P.Nupagoexol)
              INTO Lcantidad, Lnupagoexol
              FROM Fam_Pagoexol P
             WHERE P.Nucomp = S.Nucomp
               AND P.Stregi = 'R'
               AND P.Tipagoexol = 'D'
                AND EXISTS (
                   SELECT 1
                     FROM Faw_Pagoexol D
                    WHERE D.Nupagoexol = P.Nupagoexol
                      AND D.Nucomp = S.Nucomp
                      AND D.Nucargabon = Labono);
            IF Lcantidad = 1 THEN
                UPDATE Sct_Solidevo
                   SET Stsolidevo = 'CUA', Nupagoexol = Lnupagoexol
                 WHERE Nucomp = S.Nucomp AND Nuserv = S.Nuserv
                   AND Idcuaddevo = Pidcuad AND Stsolidevo = 'LIQ';
                Lrecuperadas := Lrecuperadas + SQL%ROWCOUNT;
                COMMIT;
            ELSE
                Lpendientes := Lpendientes + 1;
                IF Lcantidad > 1 THEN
                    Ldetalle := 'Solicitud ' || S.Nucomp || '-' || S.Nuserv
                       || ': existen ' || Lcantidad
                       || ' pagos de devolucion para el mismo abono. Se requiere conciliacion.';
                ELSE
                    Ldetalle := 'Solicitud ' || S.Nucomp || '-' || S.Nuserv
                       || ' permanece en LIQ; no se encontro pago para recuperar.';
                END IF;
            END IF;
            Pr_Soltar_Bloqueo;
        END LOOP;
        IF Lpendientes > 0 THEN
            Opexitosa := 'N';
            Pmensaje := Ldetalle;
        ELSIF Lrecuperadas > 0 THEN
            Opexitosa := 'R';
            Pmensaje := 'Se recuperaron ' || Lrecuperadas
               || ' checkpoint(s). Conciliar antes de continuar.';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            Pr_Soltar_Bloqueo;
            Opexitosa := 'N';
            Pmensaje := SUBSTR('No se pudo recuperar la liquidacion: ' || SQLERRM, 1, 1000);
    END Pr_Recuperar_Liquidacion;

    PROCEDURE Pr_Liberar_Liquidacion_Cuadro (Pidcuad NUMBER,
                                             Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        Lcantidad NUMBER := 0;
        Labono NUMBER;
        Lpagos NUMBER;
        Loplock VARCHAR2(1);
        Lmslock VARCHAR2(1000);
    BEGIN
        Opexitosa := 'N';
        Pmensaje := NULL;
        FOR S IN (SELECT Nucomp, Nuserv, Nucargabon
                    FROM Sct_Solidevo
                   WHERE Idcuaddevo = Pidcuad
                     AND Stregi = 'R'
                     AND Stsolidevo = 'LIQ') LOOP
            SELECT MAX(Nucaabasoc) INTO Labono
              FROM Fat_Cargabon
             WHERE Nucomp = S.Nucomp
               AND Nucargabon = S.Nucargabon
               AND Stregi = 'R';
            IF Labono IS NULL THEN
                ROLLBACK;
                Pmensaje := 'No se libera la solicitud ' || S.Nucomp || '-' || S.Nuserv
                   || ': no se identifico el abono.';
                RETURN;
            END IF;
            Pr_Tomar_Bloqueo(S.Nucomp, Labono, Loplock, Lmslock);
            IF Loplock <> 'S' THEN
                ROLLBACK;
                Pmensaje := 'No se libera la solicitud ' || S.Nucomp || '-' || S.Nuserv
                   || ': sigue activa en otra sesion.';
                RETURN;
            END IF;
            SELECT COUNT(DISTINCT P.Nupagoexol) INTO Lpagos
              FROM Fam_Pagoexol P
             WHERE P.Nucomp = S.Nucomp
               AND P.Stregi = 'R'
               AND P.Tipagoexol = 'D'
               AND EXISTS (
                   SELECT 1 FROM Faw_Pagoexol D
                    WHERE D.Nupagoexol = P.Nupagoexol
                      AND D.Nucomp = P.Nucomp
                      AND D.Nucargabon = Labono);
            IF Lpagos <> 0 THEN
                ROLLBACK;
                Pr_Soltar_Bloqueo;
                Pmensaje := 'No se libera la solicitud ' || S.Nucomp || '-' || S.Nuserv
                   || ': existe pago de devolucion para conciliar.';
                RETURN;
            END IF;
            UPDATE Sct_Solidevo
               SET Stsolidevo = 'CUA'
             WHERE Nucomp = S.Nucomp AND Nuserv = S.Nuserv
                AND Idcuaddevo = Pidcuad AND Stsolidevo = 'LIQ'
                AND Nupagoexol IS NULL;
            Lcantidad := Lcantidad + SQL%ROWCOUNT;
            COMMIT;
            Pr_Soltar_Bloqueo;
        END LOOP;
        Opexitosa := 'S';
        Pmensaje := 'Se liberaron ' || Lcantidad || ' solicitud(es) en LIQ.';
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            Pr_Soltar_Bloqueo;
            Opexitosa := 'N';
            Pmensaje := SUBSTR('No se pudo liberar el cuadro: ' || SQLERRM, 1, 1000);
    END Pr_Liberar_Liquidacion_Cuadro;

    PROCEDURE Pr_Verificar_Bloqueo_Emision (Pnupagoexol NUMBER,
                                            Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2)
    IS
        Ldummy NUMBER;
        Litems NUMBER := 0;
        Lstpago VARCHAR2(1);
        Lnucomp NUMBER;
        Lnucargabon NUMBER;
        Lcantidad_abonos NUMBER;
        E_resource_busy EXCEPTION;
        PRAGMA EXCEPTION_INIT(E_resource_busy, -54);
    BEGIN
        Opexitosa := 'N';
        Pmensaje := NULL;
        IF Pnupagoexol IS NULL THEN
            Pmensaje := 'No se recibio NUPAGOEXOL para validar la emision.';
            RETURN;
        END IF;

        SAVEPOINT Sp_precheck_emision;
        SELECT COUNT(DISTINCT D.Nucomp || ':' || D.Nucargabon),
               MAX(D.Nucomp), MAX(D.Nucargabon)
          INTO Lcantidad_abonos, Lnucomp, Lnucargabon
          FROM Faw_Pagoexol D
         WHERE D.Nupagoexol = Pnupagoexol;
        IF Lcantidad_abonos <> 1 THEN
            ROLLBACK TO Sp_precheck_emision;
            Pmensaje := 'El pago no tiene un unico abono para identificar su bloqueo.';
            RETURN;
        END IF;
        Pr_Tomar_Bloqueo(Lnucomp, Lnucargabon, Opexitosa, Pmensaje);
        IF Opexitosa <> 'S' THEN
            RETURN;
        END IF;

        -- Preflight: detectar bloqueos antes de entrar a FAPQ_PAGOEXTR.
        SELECT Stpago INTO Lstpago
          FROM Fam_Pagoexol
         WHERE Nupagoexol = Pnupagoexol
           AND Stregi = 'R'
         FOR UPDATE NOWAIT;

        FOR D IN (SELECT Rowid Rid
                    FROM Faw_Pagoexol
                   WHERE Nupagoexol = Pnupagoexol) LOOP
            SELECT 1 INTO Ldummy FROM Faw_Pagoexol WHERE Rowid = D.Rid FOR UPDATE NOWAIT;
            Litems := Litems + 1;
        END LOOP;
        IF Litems = 0 THEN
            ROLLBACK TO Sp_precheck_emision;
            Pr_Soltar_Bloqueo;
            Pmensaje := 'El pago no tiene detalle FAW_PAGOEXOL para emitir.';
            RETURN;
        END IF;

        FOR C IN (
            SELECT DISTINCT Ca.Rowid Rid
              FROM Fat_Cargabon Ca
              JOIN Faw_Pagoexol D
                ON D.Nucomp = Ca.Nucomp
               AND D.Nucargabon = Ca.Nucargabon
             WHERE D.Nupagoexol = Pnupagoexol) LOOP
            SELECT 1 INTO Ldummy FROM Fat_Cargabon WHERE Rowid = C.Rid FOR UPDATE NOWAIT;
        END LOOP;

        Opexitosa := 'S';
    EXCEPTION
        WHEN E_resource_busy THEN
            ROLLBACK TO Sp_precheck_emision;
            Pr_Soltar_Bloqueo;
            Pmensaje := 'El pago o un cargo relacionado esta bloqueado por otra sesion.';
        WHEN NO_DATA_FOUND THEN
            ROLLBACK TO Sp_precheck_emision;
            Pr_Soltar_Bloqueo;
            Pmensaje := 'El pago no esta registrado y no puede emitirse.';
        WHEN OTHERS THEN
            ROLLBACK TO Sp_precheck_emision;
            Pr_Soltar_Bloqueo;
            Pmensaje := SUBSTR('No se pudo validar el bloqueo de emision: ' || SQLERRM, 1, 1000);
    END Pr_Verificar_Bloqueo_Emision;

    PROCEDURE Pr_Liberar_Bloqueo_Liquidacion (Opexitosa OUT VARCHAR2,
                                              Pmensaje OUT VARCHAR2)
    IS
    BEGIN
        Pr_Soltar_Bloqueo;
        IF G_lockhandle IS NULL THEN
            Opexitosa := 'S';
            Pmensaje := NULL;
        ELSE
            Opexitosa := 'N';
            Pmensaje := 'No se pudo liberar el bloqueo de liquidacion de la sesion.';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            Opexitosa := 'N';
            Pmensaje := SUBSTR('No se pudo liberar el bloqueo: ' || SQLERRM, 1, 1000);
    END Pr_Liberar_Bloqueo_Liquidacion;

 END Scpq_Devo;