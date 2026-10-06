/*******************************************************************************
 * METADATA
 * Analista     : IGORCB
 * Descargado   : 06/10/2026, 11:21:28
 * Owner        : SGC_FA
 * Versión      : 7
 *******************************************************************************/
CREATE OR REPLACE PACKAGE BODY SGC_FA.Fapq_Pagoextr IS
-- procedimiento que acutaliza la cuenta de un pago extaordinario
  PROCEDURE pr_actucuenta (servicio IN NUMBER,
                                                   compania IN NUMBER,
                                                   cuenta IN NUMBER,
                                                   exito OUT BOOLEAN,
                                                   mensaje OUT VARCHAR2) IS
  CURSOR existe_pago IS
  SELECT 'X'
  FROM FAM_PAGOEXTR
  WHERE nuserv = servicio
  AND   nucomp = compania;
  pago existe_pago%ROWTYPE;
 BEGIN
  OPEN existe_pago;
  FETCH existe_pago INTO PAGO;
  IF existe_pago%FOUND THEN
      UPDATE FAM_PAGOEXTR
      SET nucuen = cuenta
      WHERE nuserv = servicio
      AND   nucomp = compania;
      exito := TRUE;
      mensaje :=  ('ACTUALIZACION EXITOSA');
  ELSE
      EXITO := TRUE;
      MENSAJE := ('NO EXISTE PAGO EXTRAORDINARIO PARA ESE SERVICIO');
  END IF;
  CLOSE existe_pago;
 END;
  PROCEDURE pr_AnulaPagoExtr     (     pa_nupagoextr NUMBER,
                                              pa_nucomp    NUMBER
                                  ) IS
          CURSOR trae_PagoExtr IS
              SELECT
                  nucargabon,
                  mopago
              FROM
                  FAD_PAGOEXTR
              WHERE
                  nupagoextr = pa_nupagoextr AND
                  nucomp = pa_nucomp;
            va_nuerro NUMBER;
            va_existe NUMBER;
      BEGIN
            -- VERIFICACION DE EXISTENCIA DEL PAGO EXTRAORDINARIO
                SELECT
                    COUNT(*)
                INTO
                    va_existe
                FROM
                    FAM_PAGOEXTR
                WHERE
                    nupagoextr = pa_nupagoextr AND
                    nucomp = pa_nucomp AND
                    stpago = 'P';
                IF va_existe=0 THEN
                    RETURN;
                END IF;
            -- ANULACION DEL DETALLE DEL PAGO EXTRAORDINARIO
                FOR va_pagoExtr IN trae_pagoExtr
          LOOP
                    Fapq_Cargabon.pr_actualizacargos (    va_PagoExtr.nucargabon,
                                                                    pa_nucomp,
                                                                    -va_PagoExtr.mopago,
                                                                    -va_PagoExtr.mopago,
                                                                    va_nuerro
                                                                );
          END LOOP;
            -- ANULACION DE LA CABECERA DEL PAGO EXTRAORDINARIO
                UPDATE
                    FAM_PAGOEXTR
                SET
                    nuemplanul     = MGPQ_SEGUACCE.Fn_TraerNuEmpl,
                    fcanul        =    SYSDATE,
                    stpago         = 'A'
                WHERE
                    nupagoextr     = pa_nupagoextr AND
                    nucomp         = pa_nucomp;
    END;
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
-- PAGOS EXTRAORDINARIOS ONLINE --------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
    FUNCTION fn_ListPagoExol RETURN MaesPagoexol IS
            va_pagoexol  MaesPagoexol;
            CURSOR trae_pagoexol IS
                SELECT * FROM FAM_PAGOEXOL WHERE stpago IN ('E') AND stregi='R';
            va_Index NUMBER(8):=0;
    BEGIN
            FOR pagoexol IN trae_pagoexol
            LOOP
                va_Index := va_Index + 1;
                va_PagoExol(va_Index) := pagoexol;
                va_PagoExol(va_Index).dtglos := TRANSLATE(va_PagoExol(va_Index).dtglos,'|*%&'||CHR(9)||CHR(10)||CHR(13)||CHR(39),'        ');
            END LOOP;
            RETURN va_PagoExol;
    END;
----------------------------------------------------------------------------------------------------------
        FUNCTION fn_DetaPagoExol(pa_nupagoexol NUMBER) RETURN DetaPagoexol IS
            va_pagoexol  DetaPagoexol;
            CURSOR trae_pagoexol IS
                SELECT nupagoexol,nuline,nucargabon,cdcargabon,mopago
                FROM faw_pagoexol WHERE nupagoexol=pa_nupagoexol ORDER BY nuline;
            va_Index NUMBER(8):=0;
    BEGIN
            FOR pagoexol IN trae_pagoexol
            LOOP
                va_Index := va_Index + 1;
                va_PagoExol(va_Index) := pagoexol;
            END LOOP;
            RETURN va_PagoExol;
    END;
----------------------------------------------------------------------------------------------------------

    PROCEDURE pr_EmitePago(Pa_nupagoExol NUMBER,pa_dsMens OUT VARCHAR2,pa_fcemis date default null,pa_fcvenc date default null) IS
              CURSOR trae_pagoexol IS
                       SELECT
                        PE.*,
                        (CASE
                            WHEN (SELECT COUNT(*) FROM FAW_PAGOEXOL WHERE nupagoexol=pe.nupagoexol and cdcargabon=247)>0 THEN (SELECT max(tidosi) from fac_conccaab WHERE cdcargabon=247) --ENERGIA PREPAGO
                            WHEN (SELECT COUNT(*) FROM FAW_PAGOEXOL WHERE nupagoexol=pe.nupagoexol and cdcargabon=265)>0 THEN (SELECT max(tidosi) from fac_conccaab WHERE cdcargabon=265) --ALQUILER BIENES INMUEBLES
                            WHEN (SELECT COUNT(*) FROM FAW_PAGOEXOL WHERE nupagoexol=pe.nupagoexol and cdcargabon=281)>0 THEN (SELECT max(tidosi) from fac_conccaab WHERE cdcargabon=281) --IMPORTACI.N DE ENERG.A
                            WHEN (SELECT COUNT(*) FROM FAW_PAGOEXOL WHERE nupagoexol=pe.nupagoexol and cdcargabon=282)>0 THEN (SELECT max(tidosi) from fac_conccaab WHERE cdcargabon=282) --EXPORTACI.N DE GAS
                            ELSE 1
                        END) TIDOSI
                     FROM FAM_PAGOEXOL PE WHERE nupagoexol=pa_nupagoexol AND stpago='R' AND stregi='R';
              va_pagoexol trae_pagoexol%ROWTYPE;
              va_ok VARCHAR2(200);
              va_fcemis date;
              va_fcvenc date;
              va_FAPAEXOL VARCHAR2(100);
              va_ctRegi number;
              va_idserv number;
              va_tidosi varchar2(10);
              va_cdactisiat varchar2(100);
              va_cddocusectsiat varchar2(100);
              va_cdformimpr varchar2(30);
              va_ticalcbpcf varchar2(30);
              va_tivenc varchar2(30);
              va_opRedEmisor varchar2(1);
              va_nucompDosi number;
              va_EsPrepago varchar2(10);

    BEGIN
        --VALIDACION PARA EMITIR PAGOS EXTRAORDINARIOS ONLINE
            select nvl(max(vapara),'N') into va_FAPAEXOL from mgm_para where cdmodu='FA' and cdpara='FAPAEXOL' and nucomp=1;
            if va_FAPAEXOL<>'S' then
                pa_dsMens:='Error. Temporalmente no esta permitido la emisi.n de pagos extraordinarios online.  Favor intentar mas tarde.';
                RETURN;
            end if;
        --FIN VALIDACION


        --VALIDANDO QUE EXISTA Y ESTE REGISTRADO
            OPEN trae_pagoexol;
            FETCH trae_pagoexol INTO va_pagoexol;
            CLOSE trae_pagoexol;
            IF va_pagoexol.nupagoexol IS NULL THEN
               pa_dsmens:='Error.  Pago ya esta emitido o anulado.';
               RETURN;
            END IF;

        --VALIDACION PARA EMITIR PAGOS EXTRAORDINARIOS ONLINE EN DOLARES
            select nvl(max(vapara),'S') into va_FAPAEXOL from mgm_para where cdmodu='FA' and cdpara='FAPAEXSU' and nucomp=1;
            if va_FAPAEXOL<>'S' then
                IF va_pagoexol.TIMONE='E' THEN
                   pa_dsMens:='Error. Temporalmente no esta permitido la emision de pagos extraordinarios en dolares.  Favor intentar mas tarde.';
                   RETURN;
                END IF;
            end if;

        --FIN VALIDACION


        --VALIDANDO QUE NO SEAN MAS DE 7 ITEMS
            SELECT
                COUNT(*)
            INTO
                va_ctRegi
            from
                faw_pagoexol
            where
                nupagoexol=pa_nupagoexol and stpago='R' and stregi='R';

            if va_ctRegi>9 then
                pa_dsMens := 'Error.  Numero de items sobrepasa al maximo numero de items  por pago extraordinario';
                return;
            end if;

        --VALIDADANDO QUE NO SEAN MAS DE UNA CONFIGURACION TODOS LOS CARGOS
            select
                count(*),max(idserv),max(tidosi),max(cdformimpr),max(ticalcbpcf),max(tivenc),max(cdactisiat),max(cddocusectsiat),max(fcvenc) fcvenc
            into
                va_ctRegi,
                va_idserv,
                va_tidosi,
                va_cdformimpr,
                va_ticalcbpcf,
                va_tivenc,
                va_cdactisiat,          --SFE
                va_cddocusectsiat,      --SFE
                va_fcvenc
            from
            (
                SELECT
                    distinct
                    ca.idserv,ca.tidosi,cdformimpr,ticalcbpcf,tivenc,ca.cdactisiat,ca.cddocusectsiat,pa.fcvenc
                FROM
                    fac_conccaab ca,
                    FAW_PAGOEXOL pa
                WHERE
                    pa.nupagoexol=pa_nupagoexol and pa.stpago='R' and pa.stregi='R' and
                    ca.cdcargabon=pa.cdcargabon and
                    (   TIDOSI IS NOT NULL or   --SOLO LOS CARGOS CON DOSIFICACION
                        (select count(*) from faw_pagoexol p2 where p2.nupagoexol=pa.nupagoexol and opcredfisc='S')=0 -- EL PAGO EXTR. NO TIENE CARGOS CON CREDITO FISCAL
                    )
            );

            if va_ctRegi<>1 then
                pa_dsMens := 'Error.  Conceptos de cargos y abonos no se pueden emitir en un mismo pago extraordinario.';
                return;
            end if;

        --VALIDANDO QUE LOS PAGOS EXTRAORNINARIOS NO PREPAGOS NO TENGAN CONCEPTOS CON IVA Y SIN IVA
        --SFE

            SELECT
                COUNT(DISTINCT OPCREDFISC) CANT_OPCREDFISC,
                NVL(MAX(CASE WHEN CDCARGABON=247 THEN 'SI' ELSE NULL END),'NO') ESPREPAGO
            INTO
                va_ctRegi,
                va_EsPrepago
            FROM
                FAW_PAGOEXOL pa
            WHERE
                NUPAGOEXOL=pa_nupagoexol;

            if nvl(va_ctRegi,0)>=2 and nvl(va_EsPrepago,'X')='NO' then
                pa_dsMens := 'Error.  Conceptos de cargos con iva y sin iva no se pueden emitir en un mismo pago extraordinario.';
                return;
            end if;


        --Fecha de emision
          if pa_fcemis is null then
              va_fcemis := TRUNC(SYSDATE,'DD');
          else
              va_fcemis := TRUNC(pa_fcemis,'DD');
          end if;
          va_fcemis := least(va_fcemis,trunc(sysdate));

          va_tidosi:=16;  --SFE

        --Ver si el tipo de Dosificacion es en Red o Punto Fijo para definir la compa.ia de la dosificaci.n
            if DCPQ_DOSIFACT.Fn_EsActiEnRedChr (va_tidosi)='S' then
                va_nucompDosi := 1;
            else
                va_nucompDosi := va_pagoexol.nucomp;
            end if;

            pa_dsmens :='SERVICIO:'||va_idserv||
                        '-TIDOSI:'||VA_TIDOSI||
                        '-NUCOMP:'||VA_NUCOMPDOSI||
                        '-FORMATO:'||VA_CDFORMIMPR||
                        '-BPCF:'||VA_TICALCBPCF||
                        '-VENCIMIENTO:'||VA_TIVENC||
                        '-DOSIFICACION EN RED?:'||DCPQ_DOSIFACT.Fn_EsActiEnRedChr (va_tidosi)||
                        '-FCEMIS:'||TO_CHAR(VA_FCEMIS,'DD/MM/YYYY');
            --return;
            pa_dsmens:=null;


        --Verificar que para dicha dosificacion no hayan pagos extraordinarios con fecha de emisi.n posterior
            --POR HACER


        -- VALIDACION PARA DEVOLUCIONES
            pa_dsMens:='0';
            if va_pagoexol.tipagoexol IN ('A','D') then --Devoluciones
                if va_pagoexol.cdnit Is Null Then -- nvl(trim(va_pagoexol.cdnit),0)<=0 then
                    pa_dsMens:='El Carnet de Identidad/NIT es obligatorio para las devoluciones.';
                    RETURN;
                end if;
            end if;
        -- FIN VALIDACION PARA DEVOLUCIONES

        --A Partir del 21 de Abril, el Carnet/NIT es obligatorio
            if va_pagoexol.cdnit is null Then -- and nvl(trim(va_pagoexol.cdnit),0)<0 then
                pa_dsMens:='El Carnet de Identidad/NIT/Otro es obligatorio.';
                RETURN;
            end if;


        pa_dsMens:='1';
        pr_CreaPagoExtraordinario(Pa_nupagoExol,pa_dsMens);
        IF pa_dsMens IS NOT NULL THEN
           --ROLLBACK;
           RETURN;
        END IF;
        --Calcula los datos de la factura
        pa_dsMens:='2';

        IF va_pagoexol.IMBPCF>0 or va_pagoexol.tidosi=2 THEN --BASE PARA CREDITO FISCAL O FACTURA PREPAGO
            IF va_pagoexol.cdnit is null Then -- or nvl(va_pagoexol.cdnit,0)<0 THEN
                pa_dsMens:='Error.  Numero de NIT nulo o invalido.  Se necesita NIT para emitir la factura.';
                --ROLLBACK;
                RETURN;
            END IF;
                --EXCEPCION PARA IMPORTACION DE ENERGIA;EXPORTACI.N DE GAS
                --MAYO/2016
                IF va_pagoexol.TIDOSI IN (4,5) THEN
                    va_pagoexol.IMBPCF:=0;
                END IF;
                sgc_dc.dcpq_pagoextr.pr_GeneraFactura(      va_fcemis,
                                                            va_pagoexol.IMBPCF,
                                                            sopq_descclie.fn_numero(va_pagoexol.cdnit),
                                                            va_pagoexol.nulote,
                                                            va_pagoexol.nufactrent,
                                                            va_pagoexol.cdcont,
                                                            pa_dsmens,
                                                            va_ok,
                                                            va_TIDOSI,
                                                            va_nucompDosi
                                                     );
                IF pa_dsmens IS NOT NULL THEN
                   --ROLLBACK;
                   RETURN;
                END IF;
        END IF;

        --Fecha de vencimiento
          if pa_fcvenc is not null then
              va_fcvenc := TRUNC(pa_fcvenc,'DD');
          end if;

        --Fecha de vencimiento
            if va_fcvenc is null then
                 if va_tivenc='DIA' then
                     va_fcvenc := trunc(sysdate,'DD');
                 elsif va_tivenc='MES' then
                     --va_fcvenc := last_day(trunc(sysdate,'DD'));
                     va_fcvenc := (trunc(sysdate,'DD')+31);
                 elsif va_tivenc='NUNCA' then
                     va_fcvenc := '31/12/2999';
                 else
                     null;
                 end if;
            end if;


        --Revisa y corrige el tipo en Cargos y Abonos cuando el ticargabon es I
            update
                fat_cargabon ca
            set
                ticargabon=(select co.ticargabon from fac_conccaab co where co.cdcargabon=ca.cdcargabon)
            where
                (ca.nucargabon,ca.nucomp) in (select pa.nucargabon,pa.nucomp from faw_pagoexol pa where pa.nupagoexol=pa_nupagoexol) and
                ca.ticargabon='I';
        --Fin Revisa y corrige el tipo en Cargos y Abonos cuando el ticargabon es I


        --Cambia el estado a publicado para que sea tomado por el monitor de Cobranza en linea
        UPDATE
            FAM_PAGOEXOL pa
        SET
            pa.stpago='E',
            pa.imbpcf=va_pagoexol.IMBPCF,
            pa.cdnit=va_pagoexol.cdnit,
            pa.nulote=va_pagoexol.nulote,
            pa.nufactrent=va_pagoexol.nufactrent,
            pa.cdcont=va_pagoexol.cdcont,
            pa.FCEMIS=va_fcemis,
            pa.FCVENC=va_fcvenc,
            pa.NUEMPLMODI=MGPQ_SEGUACCE.Fn_TraerNuEmpl,
            pa.FCMODI=SYSDATE,
            pa.CDACTISIAT=va_cdactisiat,
            pa.cddocusectsiat=va_cddocusectsiat
         WHERE
             nupagoexol=pa_nupagoexol;

        /* -- temporal pruebas ws para pago extr-- */
        --  Se cambia el NULOTE =100 PARA QUE NO SE PUBLIQUE COMO FACTURA ELECTR.NICA
        --update fam_pagoexol set nulote=100  where nupagoexol=pa_nupagoexol;
        /* -- temporal -- */

        --COMMIT;
        pa_Dsmens:='';
           EXCEPTION
               WHEN OTHERS THEN
                       pa_DsMens:=SUBSTR(NVL(pa_DsMens,'Error Inesperado. '),1,100)||SQLERRM;
                       CrPq_CtrlProc.Pr_EmitirCorreo('pablomh@cre.com.bo','PAGOS EXTR',sqlerrm);
                       RETURN;
    END;
----------------------------------------------------------------------------------------------------------
    PROCEDURE pr_PublicaPago(Pa_nupagoExol NUMBER,pa_dsMens OUT VARCHAR2) IS
    BEGIN
        --stpago ( R) REGISTRADO (E)mitido para Cobranza, (P)ublicado en cobranza, Pagado En (L)inea, (C)onsolidado, (V)encido
        --stregi (A)Anulado, (R) registrado
        UPDATE
            FAM_PAGOEXOL pa
        SET
            pa.stpago='P',
            pa.FCPUBL=SYSDATE,
            pa.FCMODI=SYSDATE
         WHERE
             nupagoexol=pa_nupagoexol AND
            pa.stpago='E';
        COMMIT;
           EXCEPTION
               WHEN OTHERS THEN
                       pa_DsMens:=NVL(pa_DsMens,'Error Inesperado');
                       RETURN;
    END;
---------------------------------------------------------------------------------------------------------
    PROCEDURE pr_AnulaPago(Pa_nupagoExol NUMBER,pa_dsMens OUT VARCHAR2) IS
        --stpago (E)mitido para Cobranza, (P)ublicado en cobranza, Pagado En (L)inea, (C)onsolidado, (V)encido,N En proceso de anulaci.n
        --stregi (A)Anulado, (R) registrado
        -- Solo se puede anular los Registrados/Emitidos y Publicados
              CURSOR trae_pagoexol IS
                       SELECT
                            PE.*,
                            SGC_CB.cbpq_coblinweb_PagoExtrSFE.FN_STFIRMA (NUPAGOEXOL,NUCOMP) STFIRM
                        FROM
                            FAM_PAGOEXOL PE
                        WHERE nupagoexol=pa_nupagoexol;
              va_pagoexol trae_pagoexol%ROWTYPE;
              va_ok VARCHAR2(200);
    BEGIN
        OPEN trae_pagoexol;
        FETCH trae_pagoexol INTO va_pagoexol;
        CLOSE trae_pagoexol;
        IF va_pagoexol.nupagoexol IS NULL THEN
           pa_dsmens:='Error.  Pago no existe.';
           RETURN;
        END IF;
        IF va_pagoexol.stregi='A' THEN
           pa_dsmens:='Error.  Pago ya est. anulado.';
           RETURN;
        END IF;
        IF va_pagoexol.stpago NOT IN ('R','E','P') THEN
           pa_dsmens:='Error.  Pago no se puede anular puesto que est. pagado / vencido.';
           RETURN;
        END IF;

        IF  va_pagoexol.stpago IN ('E','P') THEN
            IF va_pagoexol.stpago = 'P' THEN
                --COBLIN-WEB
                sgc_cb.cbpq_coblinweb_pagoextr.PR_ANULAPAGOEXTR (va_pagoexol.nupagoexol,va_pagoexol.nucomp,va_pagoexol.timone, va_Ok,pa_dsMens);
            END IF;
            IF va_Ok='N' THEN
                RETURN;
            END IF;

            --SE ANULA EL PAGO EXTRAORDINARIO ANTIGUO PRIMERO
            pr_AnulaPagoExtraordinario(pa_nupagoexol,pa_dsmens);
            if pa_dsmens is not null then
                RETURN;
            end if;

            --SE ANULA EL PAGO EXTRAORDINARIO ONLINE
            IF nvl(va_pagoexol.STFIRM,'X')=('PRO')  -- FIRMADO SFE
               OR NVL(va_pagoexol.NULOTE,0)<>1000 THEN          -- NO ES FIRMA ELECTRONICA
                UPDATE
                    FAM_PAGOEXOL pa
                SET
                    pa.stpago='V',
                    pa.NUEMPLMODI=NVL(MGPQ_SEGUACCE.Fn_TraerNuEmpl,0),
                    pa.FCMODI=SYSDATE
                 WHERE
                    nupagoexol=pa_nupagoexol;
            ELSE
                if pa_dsmens is not null then
                    RETURN;
                end if;
                UPDATE
                    FAM_PAGOEXOL pa
                SET
                    pa.stpago='R',
                    pa.stregi='A',
                    pa.NUEMPLANUL=NVL(MGPQ_SEGUACCE.Fn_TraerNuEmpl,0),
                    pa.FCANUL=SYSDATE
                 WHERE
                    nupagoexol=pa_nupagoexol;
            END IF;
        ELSE
                UPDATE
                    FAM_PAGOEXOL pa
                SET
                    pa.stpago='R',
                    pa.stregi='A',
                    pa.NUEMPLANUL=NVL(MGPQ_SEGUACCE.Fn_TraerNuEmpl,0),
                    pa.FCANUL=SYSDATE
                 WHERE
                    nupagoexol=pa_nupagoexol;
        END IF;
        COMMIT;


           EXCEPTION
               WHEN OTHERS THEN
                       pa_DsMens:=NVL(pa_DsMens,'Error Inesperado');
                       RETURN;
    END;
----------------------------------------------------------------------------------------------------------
    PROCEDURE pr_RealPagoOff(Pa_nupagoExol number,PA_NUENTIFINA number,PA_NUAGEN NUMBER,PA_NUCAJE number,pa_FcPagoReal date,pa_NutranCobl number, pa_dsMens out varchar2,pa_operro out boolean) is

        CURSOR trae_pagoexol IS
             SELECT *
               FROM faw_pagoexol
              WHERE nupagoexol=pa_nupagoexol;

            va_moti VARCHAR2(10);
            va_nuserv NUMBER;
            va_nuerro NUMBER;
            va_dsMens VARCHAR2(100);
         OperacionExitosa BOOLEAN;
         mensaje VARCHAR2(200);
         impagos number:=0;
         cobrados number:=0;

    BEGIN
            --Actualiza el Pago Online
                UPDATE
                        FAM_PAGOEXOL
                    SET
                        stpago='L',
                        nuentifina=NVL(pa_nuentifina,0),
                        nuagen=NVL(pa_nuagen,0),
                        nucaje=pa_nucaje,
                        fcpagoreal=pa_fcpagoreal,
                        nutrancobl=pa_nutrancobl,
                        FCPAGO=SYSDATE,
                        FCMODI=SYSDATE
                     WHERE
                        nupagoexol=pa_nupagoexol;
                UPDATE
                      FAM_PAGOEXTR
                SET
                        stpago='P',
                        nuentifina=pa_nuentifina,
                        nuagen=pa_nuagen,
                        nudepo=pa_nutrancobl,
                        fcpago=pa_fcpagoreal
                WHERE
                      nupagoextr = (SELECT nupagoextr FROM FAM_PAGOEXOL WHERE nupagoexol=pa_nupagoexol);

              --ACTUALIZACION DEL MONTO FACTURADO EN LOS CARGOS
              FOR pagoexol IN trae_pagoexol  LOOP
                Fapq_Cargabon.pr_actualizacargos (pagoexol.nucargabon,pagoexol.nucomp,0,pagoexol.mopago,va_nuerro);


                DBMS_output.put_line ('Fapq_Cargabon.pr_actualizacargos: Mensaje devuelto'||va_nuerro);
              END LOOP;
              COMMIT;

              -- ENV.OS DE MAIL
              FOR pagoexol IN trae_pagoexol  LOOP
                -- Env.o de mail si es TIPAGOEXOL='V' (VENTA | NORMAL)
                -- David Chalup
                -- Julio 2011
                    if pagoexol.tipagoexol='V' then
                        DECLARE
                            va_Empl varchar2(500);
                            va_para varchar2(500);
                            va_asunto varchar2(500);
                            va_Servicio varchar2(500);
                            va_cuerpo varchar2(10000);
                        BEGIN
                            select max(trim(noempl)) into va_Empl from mgm_empl where nuempl=pagoexol.nuemplregi;
                            select max(trim(cdusua)) into va_para from mgm_usua where nuempl=pagoexol.nuemplregi;
                            if va_para is not null then
                                va_para := va_para||'@cre.com.bo';
                                va_Asunto := 'Cobranza Pago Extraordinario '||pagoexol.nupagoexol;
                                va_Servicio := fapq_traedesc.fn_cargabon(pagoexol.cdcargabon);
                                va_Cuerpo := 'El pago extraordinario '||pagoexol.nupagoexol||
                                             ' emitido por '||va_Empl||
                                             ' en fecha '||to_char(pagoexol.fcemis,'DD/MM/YYYY')||
                                             ' para la persona '||pagoexol.dsnomb||
                                             ' por el producto/servicio '||va_Servicio||
                                             ' por un monto de '||pagoexol.mopago||' '||pagoexol.moneda||
                                             ' ha sido pagado en cobranza en l.nea'||
                                             ' en fecha '||to_char(pagoexol.fcpago,'DD/MM/YYYY HH24:MI');
                                FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo',va_para,va_Asunto,va_Cuerpo,NULL);
                                FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','royrf@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                                --FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','juliaar@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                                --FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','cielocg@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                                --FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','davidcm@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                                IF pagoexol.cdcargabon IN (250) THEN --ALQUILER DE POSTES
                                  FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','juliaar@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                                  FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','mariarbu@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                                  FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','mariamn@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                                  FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','betzyaca@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                                END IF;

                                if pagoexol.DSMAILNOTI is not null then
                                    FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo',pagoexol.DSMAILNOTI,va_Asunto,va_Cuerpo,NULL);
                                end if;
                                if pagoexol.DSMAILNOT1 is not null then
                                    FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo',pagoexol.DSMAILNOT1,va_Asunto,va_Cuerpo,NULL);
                                end if;
                                if pagoexol.DSMAILNOT2 is not null then
                                    FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo',pagoexol.DSMAILNOT2,va_Asunto,va_Cuerpo,NULL);
                                end if;
                            end if;
                        END;
                    end if;
            END LOOP;
            --  FIN ENV.OS DE MAIL

            --  ACCIONES POSTERIORES
              FOR pagoexol IN trae_pagoexol  LOOP

                --REGISTRO DEL SERVICIO CUANDO LA CUENTA EXISTE Y EL SERVICIO NO EXISTE
                    IF nvl(pagoexol.nuserv,0)=0 and nvl(pagoexol.nucuen,0)>0 THEN
                        IF    pagoexol.cdcargabon IN (2,144) THEN --CERTIFICADOS DE APORTACION
                            va_Moti:='260';
                        ELSIF    pagoexol.cdcargabon IN (64,65,139) THEN --ELECTROAGROS
                            va_Moti:='310';
                        ELSIF    pagoexol.cdcargabon IN (120,141,142,166,167,241) THEN --VENTA MEDIDOR ELECTRONICO
                            va_Moti:='295';
                        ELSE
                            va_Moti:='386';
                        END IF;
                       pr_RegistraServicio(     pagoexol.nucomp,
                                             '126',
                                             va_Moti,
                                             pagoexol.nucuen,
                                             nvl(pagoexol.nuemplregi,0),
                                             pagoexol.fcemis,
                                             pagoexol.dtglos,
                                             va_nuserv,
                                             pa_dsMens
                                           );
                       if nvl(va_nuserv,0)>0 then
                            update fam_pagoexol set nuserv=va_nuserv where nupagoexol=pa_nupagoexol;
                       end if;
                       COMMIT;
                    END IF;
                -- FIN REGISTRO DEL SERVICIO

                -- ACTIVACIONES DISPARADAS POR EL PAGO.  SON EXCLUYENTES

                    -- 1.- LABORATORIO DE ACEITES
                    -- David Chalup
                    -- Septiembre 2011
                        if pagoexol.cdcargabon IN (183) then
                            ltpq_laboaceite.PR_PROFFACT(pagoexol.nupagoexol,va_dsMens);
                            EXIT;
                        end if;
                    -- Fin activaci.n proforma laboratorio de aceites

                    -- 2.- VENTA DE MEDIDOR ELECTRONICO MD/GD
                    /* 	-------------------------------------------------------------------
                    	MEDIDOR ELECTR.NICO C/DEMANDA (241)
                    	....................................................................
                    	Se cambia la ubicaci.n del cargo 241 del bloque 4 (trif.sicos) hacia
                    	el bloque 2, porque corresponde a cargos que se presentan como .nicos
                    	a cobrar cuando se especifican en un servicio, por lo tanto, no hay
                    	posibilidad de cobro de acometida para .stos medidores.
                    	....................................................................
                    	Autor: Gabriela Salvador
                    	Fecha: 05/Diciembre/2016
                    	-------------------------------------------------------------------	*/
                    	dbms_output.put_line ('Bloque 2.'||' Cargo '||pagoexol.cdcargabon||
                                                            ' Electronico ? '||Sopq_datoCarg.Fn_EsVentaMedidorElectronico (pagoexol.cdcargabon));
                        IF  Sopq_datoCarg.Fn_EsVentaMedidorElectronico (pagoexol.cdcargabon) = 'S' THEN --VENTA MEDIDOR ELECTRONICO
                             DECLARE
                                 rservicio sopq_datoserv.tservicio;
                                 rctrlserv sopq_datoserv.tctrlserv;
                                 vFechaEven DATE;
                                 vNuempl NUMBER(6);
                                 OperacionExitosa BOOLEAN;
                                 mensaje VARCHAR2(200);
                                 nresp NUMBER(3);
                                 ErrorEmision EXCEPTION;
                                 va_nuserv NUMBER(10);
                                 va_stcobr  VARCHAR2(1);
                                 VA_CAABVEME  mgm_para.dspara%TYPE;
                             BEGIN
                                SELECT
                                   NVL(MAX(stCobr),'I') stCobr,
                                   NVL(MAX(nuserv),0) nuserv
                                INTO
                                   va_stCobr,
                                   va_nuserv
                                FROM
                                   FAT_CARGABON
                                WHERE
                                   nucargabon=pagoexol.nucargabon AND
                                   nucomp=pagoexol.nucomp;

                                va_nuserv:=NVL(pagoexol.nuserv,va_nuserv);

                                dbms_output.put_line ('Bloque 2.'||' Electronicos, estado del cargo '||va_stCobr);

                                IF va_stCobr='C' AND NVL(va_nuserv,0)>0 THEN -- Cargo por venta de medidor facturado y existe nro de servicio
                                   SOPQ_DATOSERV.Pr_TraeServicio(pagoexol.nucomp, va_nuserv, rServicio, rCtrlServ);
                                   vFechaEven := SYSDATE;
                                   vNuEmpl    := MGPQ_SEGUACCE.Fn_TraerNuEmpl;
                                   sopq_datotabla.pr_ActuCtrlServ(pagoexol.nucomp, pagoexol.nuserv,rCtrlserv, OperacionExitosa, Mensaje);


                                            /* ---------------------------------------------------------------------------
                                                NUEVAS CONEXIONES C/INSPECCI.N
                                                Autor: Gabriela Salvador
                                                Fecha: 29/Enero/2015
                                                ---------------------------------------------------------------------------
                                                Se adiciona un par.metro que por defecto est. en NULO. Este par.metro deber.
                                                contener el valor "PAGOMEDIDOR" cuando el procedimiento sea llamado desde
                                                Facturaci.n como resultado de cancelar cargos obligatorios de medidor y/o
                                                acometida.
                                                Este par.metro indicar. al procedimiento que debe ir a buscar el requisito
                                                del servicio con c.digo "PMA" para actualizarlo como "cumplido".
                                                ---------------------------------------------------------------------------    */
                                       SOPQ_ProcServ.Pr_EmiteServicio   (rServicio, rCtrlServ,vFechaEven, vNuEmpl,
                                               OperacionExitosa, Mensaje, 'PAGOMEDIDOR');
                                       dbms_output.put_line ('Bloque 2.'||' Mensaje EMITESERVICIO '||Mensaje);

                                   COMMIT;
                                   EXIT;
                                END IF;
                             END;
                        END IF;
                      -- FIN ACCIONES POR VENTA DE MEDIDOR ELECTRONICO

                     -- 3.- CONEXIONES TEMPORALES
                     -- SOLICITADO POR JUAN JOS. CANAVIRI / GABRIELA SALVADOR
                     -- MAYO 2012
                        IF Sopq_DatoServAdic.Fn_ServCuenTemp(pagoexol.nuComp, pagoexol.nuServ) = 'S' then
                            select
                                nvl(sum(decode(stcobr,'I',1,0)),0),
                                nvl(sum(decode(stcobr,'C',1,0)),0)
                            into
                                impagos,
                                cobrados
                            from
                                fat_cargabon
                            where
                                nuserv=pagoexol.nuserv and
                                nucomp=pagoexol.nucomp and
                                stregi='R';
                            if impagos=0 and cobrados>0 then
                                sopq_ActuServ.Pr_EmitePorPago (pagoexol.nuComp, pagoexol.nuServ, OperacionExitosa, Mensaje);
                                commit;
                                exit;
                            end if;
                        END IF;
                     -- FIN ACCIONES POR CONEXIONES TEMPORALES

                     -- 4.- VENTA DE MEDIDOR TRIFASICO, ACOMETIDA TRIFASICA Y CALIBRACI.N
                            IF pagoexol.cdcargabon IN (167,168,169,36) THEN
                                 DECLARE
                                     rservicio sopq_datoserv.tservicio;
                                     rctrlserv sopq_datoserv.tctrlserv;
                                     vFechaEven DATE;
                                     vNuempl NUMBER(6);
                                     nresp NUMBER(3);
                                     ErrorEmision EXCEPTION;
                                     va_nuserv NUMBER(10);
                                     va_stCobr VARCHAR2(2);
                                     VA_CAABVEME  mgm_para.dspara%TYPE;
                                     vctCargMediTrif NUMBER;
                                 BEGIN
                                    va_nuserv:=NVL(pagoexol.nuserv,va_nuserv);
                                    IF NVL(va_nuserv,0)>0 THEN
                                        If     Sopq_InfoServ.Fn_EsChequeoMedidorSolicitante (pagoexol.nucomp, va_nuserv)='S' Then
                                            --Cambio solicitado por Gabriela Salvador
                                            --18/03/2016
                                            --Reemplazo de llamadas
                                                --vctCargMediTrif := Sopq_DatoCarg.Fn_CantidadCargosCheqMediSoli(pagoexol.nucomp,NVL(va_nuserv,-1));
                                                vctCargMediTrif :=sopq_datocarg.Fn_CantidadCargosMediTrif(pagoexol.nucomp,NVL(va_nuserv,-1)) ;
                                            --Fin Cambio

                                            If Nvl(vctCargMediTrif,0)>0 Then
                                                va_stcobr:= Fapq_CargAbon.fn_EstadoCargosChequeoMediSoli (pagoexol.nucomp,va_nuserv);
                                                If  (vctCargMediTrif=1 AND INSTR(va_stcobr,'C')>0) OR   -- Un cargo por calibraci.n . acometida trif.sica
                                                    (vctCargMediTrif=2 AND va_stcobr='CC') Then         -- Ambos: Calibraci.n y acometida trif.sica
                                                    Sopq_DatoServ.Pr_TraeServicio(pagoexol.nucomp, va_nuserv, rServicio, rCtrlServ);
                                                    vFechaEven := Sysdate;
                                                    vNuEmpl    := Mgpq_SeguAcce.Fn_TraerNuEmpl;
                                                    sopq_datotabla.pr_ActuCtrlServ(pagoexol.nucomp, pagoexol.nuserv,rCtrlserv, OperacionExitosa, Mensaje);

                                                                    /* ---------------------------------------------------------------------------
                                                                        NUEVAS CONEXIONES C/INSPECCI.N
                                                                        Autor: Gabriela Salvador
                                                                        Fecha: 29/Enero/2015
                                                                        ---------------------------------------------------------------------------
                                                                        Se adiciona un par.metro que por defecto est. en NULO. Este par.metro deber.
                                                                        contener el valor "PAGOMEDIDOR" cuando el procedimiento sea llamado desde
                                                                        Facturaci.n como resultado de cancelar cargos obligatorios de medidor y/o
                                                                        acometida.
                                                                        Este par.metro indicar. al procedimiento que debe ir a buscar el requisito
                                                                        del servicio con c.digo "PMA" para actualizarlo como "cumplido".
                                                                        ---------------------------------------------------------------------------    */
                                                        SOPQ_ProcServ.Pr_EmiteServicio   (rServicio, rCtrlServ,vFechaEven, vNuEmpl,
                                                                                                    OperacionExitosa, Mensaje,'PAGOMEDIDOR');

                                                    Commit;
                                                 End If;
                                            End If;

                                        Else
                                             vctCargMediTrif := Sopq_DatoCarg.Fn_CantidadCargosMediTrif(pagoexol.nucomp,NVL(va_nuserv,-1));
                                             IF NVL(vctCargMediTrif,0)>0 THEN
                                                 va_stcobr:=Fapq_Cargabon.fn_EstadoCargosMedidorTrif(pagoexol.nucomp,va_nuserv);
                                                 IF  (vctCargMediTrif=1 AND INSTR(va_stcobr,'C')>0) OR   -- Un cargo por venta de medidor trifasico o acometida
                                                     (vctCargMediTrif=2 AND va_stcobr='CC') THEN         -- Ambos: Cargo por venta de medidor trifasico + acometida
                                                    SOPQ_DATOSERV.Pr_TraeServicio(pagoexol.nucomp, va_nuserv, rServicio, rCtrlServ);
                                                    vFechaEven := SYSDATE;
                                                    vNuEmpl    := MGPQ_SEGUACCE.Fn_TraerNuEmpl;
                                                    sopq_datotabla.pr_ActuCtrlServ(pagoexol.nucomp, pagoexol.nuserv,rCtrlserv, OperacionExitosa, Mensaje);

                                                                    /* ---------------------------------------------------------------------------
                                                                        NUEVAS CONEXIONES C/INSPECCI.N
                                                                        Autor: Gabriela Salvador
                                                                        Fecha: 29/Enero/2015
                                                                        ---------------------------------------------------------------------------
                                                                        Se adiciona un par.metro que por defecto est. en NULO. Este par.metro deber.
                                                                        contener el valor "PAGOMEDIDOR" cuando el procedimiento sea llamado desde
                                                                        Facturaci.n como resultado de cancelar cargos obligatorios de medidor y/o
                                                                        acometida.
                                                                        Este par.metro indicar. al procedimiento que debe ir a buscar el requisito
                                                                        del servicio con c.digo "PMA" para actualizarlo como "cumplido".
                                                                        ---------------------------------------------------------------------------    */
                                                        SOPQ_ProcServ.Pr_EmiteServicio   (rServicio, rCtrlServ,vFechaEven, vNuEmpl,
                                                                                                    OperacionExitosa, Mensaje,'PAGOMEDIDOR');
                                                    COMMIT;
                                                 END IF;
                                             END IF;
                                        End If;
                                    END IF;
                                 END;

                            END IF;
                     -- FIN ACCIONES POR VENTA DE MEDIDOR ELECTRONICO

                     -- 5.- CONEXIONES PRE PAGO: VENTA DE ENERGIA, CARGO POR CONEXI.N, AL.PUBLICO (si corresponde)
                             If Sopq_DatoServAdic.Fn_ServCuenPrePago(pagoexol.nuComp, pagoexol.nuServ) = 'S'
                                         And pagoexol.cdcargabon IN (19,20,21,22,247,248,254,255,167,168,286,287) Then
                                 DECLARE
                                     rservicio         sopq_datoserv.tservicio;
                                     rctrlserv         sopq_datoserv.tctrlserv;
                                     vFechaEven     DATE;
                                     vNuempl         NUMBER(6);
                                     nresp             NUMBER(3);
                                     ErrorEmision     EXCEPTION;
                                     va_nuserv         NUMBER(10);
                                     va_ctCobr       NUMBER;
                                     vctCarg         NUMBER;
                                     BEGIN

                                         va_nuserv:=NVL(pagoexol.nuserv,va_nuserv);

                                         If Nvl(va_nuserv,0)>0 Then

                                                    vctCarg := Sopq_DatoCarg.Fn_CantidadCargosPrepago(pagoexol.nucomp,NVL(va_nuserv,-1));

                                                    If Nvl(vctCarg,0)>0 Then

                                                        va_ctcobr:=Fapq_Cargabon2.fn_CantCargosPagados(pagoexol.nucomp,va_nuserv);

                                                        If    vctCarg=va_ctCobr
                                                        Then

                                                            Sopq_DatoServ.Pr_TraeServicio(pagoexol.nucomp, va_nuserv, rServicio, rCtrlServ);
                                                            vFechaEven := SYSDATE;
                                                            vNuEmpl    := MGPQ_SEGUACCE.Fn_TraerNuEmpl;
                                                             Sopq_datotabla.pr_ActuCtrlServ(pagoexol.nucomp, pagoexol.nuserv,rCtrlserv, OperacionExitosa, Mensaje);
                                                            /*
                                                            Sopq_ProcServ.Pr_EmiteServicio   (rServicio, rCtrlServ,vFechaEven, vNuEmpl,
                                                                                         OperacionExitosa, Mensaje);
                                                                                         */
                                                            SOPQ_ProcServ.Pr_EmiteServicio   (rServicio, rCtrlServ,vFechaEven, vNuEmpl,
                                                                   OperacionExitosa, Mensaje, 'PAGOMEDIDOR');

                                                        End If;

                                                        COMMIT;
                                                    End If;
                                                End If;
                                     END ;
                             End If;

                     -- FIN ACCIONES CONEXIONES PRE PAGO
                     /* --------------------------------------------------------------------------------
                       6.- VENTA DE MEDIDOR MONOF.SICO
                                    Fecha: 22/Diciembre/2015
                                    Verifica el pago del cargo por venta de medidor monof.sico para
                                    luego emitir el servicio.
                        --------------------------------------------------------------------------------
                            Ahora existe el cargo de acometida monof.sica, se adiciona a la comprobaci.n
                            del pago de ambos cargos.
                            ............................................................................
                            Fecha: Febrero/2023
                            Autor: Gabriela Salvador
                        --------------------------------------------------------------------------------     */
                       If       Sopq_datoCarg.Fn_EsVentaMedidorMonofasico (pagoexol.cdcargabon)  = 'S'
                            Or Sopq_datoCarg.Fn_EsVentaAcomMonofasica    (pagoexol.cdcargabon)  = 'S'  Then

                                 DECLARE
                                     rservicio                    sopq_datoserv.tservicio;
                                     rctrlserv                    sopq_datoserv.tctrlserv;
                                     vFechaEven DATE;
                                     vNuempl                   NUMBER(6);
                                     nresp                         NUMBER(3);
                                     ErrorEmision            EXCEPTION;
                                     va_nuserv                 NUMBER(10);
                                     va_stCobr                 VARCHAR2(3);
                                     vctCarg                     NUMBER;
                                   BEGIN
                                        va_nuserv:=NVL(pagoexol.nuserv,va_nuserv);

                                        If  Nvl(va_nuserv,0)>0 Then

                                            vctCarg := sopq_datoCarg.Fn_CantidadCargosMonofasicos  (  pagoexol.nucomp, va_nuserv);

                                            IF  NVL(vctCarg,0)>0 THEN
                                                va_stcobr:=Fapq_cargAbon.fn_EstadoCargoVentaMediMono(pagoexol.nucomp, va_nuserv);

                                                IF  (vctCarg=1 AND INSTR(va_stcobr,'C')>0) OR   -- Un cargo por venta de medidor monof.sico o acometida
                                                    (vctCarg=2 AND va_stcobr='CC') THEN         -- . ambos cargos en el servicio


                                                    Sopq_DatoServ.Pr_TraeServicio(pagoexol.nucomp, va_nuserv, rServicio, rCtrlServ);
                                                    vFechaEven := SYSDATE;
                                                    vNuEmpl    := MGPQ_SEGUACCE.Fn_TraerNuEmpl;
                                                    Sopq_datotabla.pr_ActuCtrlServ(pagoexol.nucomp, pagoexol.nuserv,rCtrlserv, OperacionExitosa, Mensaje);
                                                    SOPQ_ProcServ.Pr_EmiteServicio   (rServicio, rCtrlServ,vFechaEven, vNuEmpl,
                                                                                  OperacionExitosa, Mensaje,'PAGOMEDIDOR');
                                                    COMMIT;
                                                End If;
                                            End If;
                                        End If;
                                   END ;
                       End If;


                    -- FIN ACCIONES VENTA DE MEDIDOR MONOF.SICO
                     /* --------------------------------------------------------------------------------
                       7.- VENTA DE MATERIALES Y SERVICIOS CON PROFORMA
                            Fecha: 07/Marzo/2019
                            Verifica si el cargo que se est. pagando es parte de una PROFORMA de Materiales
                            y Servicios elaborada en el servicio
                       ---------------------------------------------------------------------------------     */
                    --dbms_output.put_line ('REALPAGOOFF: Antes de Sopq_ActuServ.Fn_tieneCargProf : '|| pagoexol.nuComp||' '||pagoexol.nuServ||' '||pagoexol.cdcargabon);
                    If  Sopq_ActuServ.Fn_tieneCargProf(   pagoexol.nuComp, pagoexol.nuServ, pagoexol.cdcargabon) = 'S' Then

                        DECLARE
                            rservicio   sopq_datoserv.tservicio;
                            rctrlserv   sopq_datoserv.tctrlserv;
                            vFechaEven  DATE;
                            vNuempl     NUMBER(6);
                            nresp       NUMBER(3);
                            ErrorEmision            EXCEPTION;
                            va_nuserv                 NUMBER(10);
                            va_stCobr                 VARCHAR2(3);
                            vctCarg                     NUMBER;
                        BEGIN
                                            --dbms_output.put_line ('SERVICIO CON PROFORMA  cargo : '||pagoexol.nucargabon||'. proforma impaga? '||Sopq_DatoCarg.Fn_tieneCargProfImpa (pagoexol.nuComp, pagoexol.nuServ));
                            va_nuserv:=NVL(pagoexol.nuserv,va_nuserv);
                            If  Nvl(va_nuserv,0)>0 Then

                                If  Sopq_DatoCarg.Fn_tieneCargProfImpa (    pagoexol.nuComp, pagoexol.nuServ) ='N' Then

                                    Sopq_DatoServ.Pr_TraeServicio(pagoexol.nucomp, va_nuserv, rServicio, rCtrlServ);
                                    vFechaEven := SYSDATE;
                                    vNuEmpl    := MGPQ_SEGUACCE.Fn_TraerNuEmpl;
                                    Sopq_datotabla.pr_ActuCtrlServ(pagoexol.nucomp, pagoexol.nuserv,rCtrlserv, OperacionExitosa, Mensaje);
                                    SOPQ_ProcServ.Pr_EmiteServicio   (rServicio, rCtrlServ,vFechaEven, vNuEmpl, OperacionExitosa, Mensaje,'PAGOMEDIDOR');
                                End If;
                                COMMIT;
                            End If;
                        END ;
                    End If;


              END LOOP;
           EXCEPTION
               WHEN OTHERS THEN
                       pa_DsMens:=NVL(pa_DsMens,'Error Inesperado');
                       RETURN;
    END;
    ----------------------------------------------------------------------------------------------------------
    PROCEDURE pr_RealizaPago(pa_NuPagoExol NUMBER,pa_NuEntiFina NUMBER,pa_NuAgen NUMBER,pa_NuCaje NUMBER,pa_FcPagoReal DATE,pa_NuTranCobl NUMBER, pa_DsMens OUT VARCHAR2) IS
    BEGIN
        INSERT INTO FAP_PAGOEXOL
            VALUES (
                pa_NuPagoExol,
                pa_NuEntiFina,
                pa_NuAgen,
                pa_NuCaje,
                pa_FcPagoReal,
                pa_NuTranCobl,
                'E',
                SYSDATE,
                NULL,
                NULL,
                NULL
                );
        COMMIT;
		--pr_EjecutePago;
        EXCEPTION
               WHEN OTHERS THEN
                   pa_DsMens:=NVL(pa_DsMens,'Error Inesperado');
                       RETURN;
    END;
----------------------------------------------------------------------------------------------------------
    PROCEDURE pr_EjecutePago IS
        CURSOR Trae_PagoExol IS
            SELECT * FROM Fap_PagoExol
                WHERE stproc in ('E')
                ORDER BY fcregi,nupagoexol;
        vDatosPagoExol Trae_PagoExol%ROWTYPE;
        dsmens2 VarChar2(100);
        operro boolean;
        va_nupagoexol number;
        flag boolean:=FALSE;
    BEGIN
        FOR vDatosPagoExol IN Trae_PagoExol LOOP
            --Registrando el inicio de la ejecuci.n
                update fap_pagoexol set stproc='I',fcmodi=sysdate where nupagoexol=vDatosPagoExol.nupagoexol;
                commit;
            --Fin registro
            pr_RealPagoOff(vDatosPagoExol.nupagoexol,vDatosPagoExol.nuentifina,vDatosPagoExol.nuagen,
                                  vDatosPagoExol.nucaje,vDatosPagoExol.fcpagoreal,vDatosPagoExol.nutrancobl,dsmens2,operro);
            IF dsmens2 IS NULL then
                UPDATE FAP_PAGOEXOL
                      SET stproc = 'P',
                          fcmodi = sysdate
                    WHERE nupagoexol = vDatosPagoExol.nupagoexol;
                COMMIT;
            ELSE
                UPDATE FAP_PAGOEXOL
                      SET fcerro = sysdate,
                          dsmens = dsmens2
                    WHERE nupagoexol = vDatosPagoExol.nupagoexol;
                COMMIT;
            END IF;
        END LOOP;

        --Reportanto bloqueos
            select max(nupagoexol) into va_nupagoexol from fap_pagoexol where stproc='I';
            if nvl(va_nupagoexol,0)>0 then
                FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','davidcm@cre.com.bo' ,'Bloqueo Cobranza Pago Extraordinario','Se ha producido un bloqueo en el pago extraordinario '||va_nupagoexol,NULL);
                FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','gabriesv@cre.com.bo','Bloqueo Cobranza Pago Extraordinario','Se ha producido un bloqueo en el pago extraordinario '||va_nupagoexol,NULL);
                --Intentando desbloquear pagos extraordinarios despues de 30 minutos para ser procesado en el siguiente job
                update fap_pagoexol set stproc='E' where stproc='I' and ((sysdate-fcmodi)*24*60)>=30;
                commit;
            end if;

    END;
----------------------------------------------------------------------------------------------------------
    PROCEDURE pr_ConsolidaPago(Pa_nupagoExol NUMBER,pa_dsMens OUT VARCHAR2) IS
        CURSOR trae_pagoexol IS
               SELECT * FROM FAM_PAGOEXOL WHERE nupagoexol=pa_nupagoexol AND stpago='L' AND stregi='R';
        CURSOR trae_pagoexol2 IS
             SELECT * FROM faw_pagoexol WHERE nupagoexol=pa_nupagoexol;
        va_pagoexol trae_pagoexol%ROWTYPE;
    BEGIN
            OPEN trae_pagoexol;
            FETCH trae_pagoexol INTO va_pagoexol;
            CLOSE trae_pagoexol;
            IF va_pagoexol.nupagoexol IS NULL THEN
               pa_dsmens:='Error.  Pago ya esta emitido o anulado.';
               RETURN;
            END IF;
            UPDATE
                FAM_PAGOEXOL pa
            SET
                pa.stpago='C',
                pa.FCMODI=SYSDATE
             WHERE
                 nupagoexol=pa_nupagoexol;
            COMMIT;
           EXCEPTION
               WHEN OTHERS THEN
                       pa_DsMens:=NVL(pa_DsMens,'Error Inesperado');
                       RETURN;
    END;
----------------------------------------------------------------------------------------------------------
    PROCEDURE pr_ReviertePago(Pa_nupagoExol NUMBER,pa_dsMens OUT VARCHAR2) IS
        --Tiene que estar en estado L
        CURSOR trae_pagoexol IS
             SELECT * FROM faw_pagoexol WHERE nupagoexol=pa_nupagoexol;
           va_cantidad NUMBER;
            va_nuerro NUMBER;
    BEGIN
        pr_EjecutePago;
        SELECT COUNT(*) INTO va_cantidad FROM FAM_PAGOEXOL WHERE nupagoexol=pa_nupagoexol AND stregi='R' AND stpago='L';
        IF va_cantidad=0 THEN
            pa_dsMens :='No se puede Revertir el Registro.  S.lo se revierten los que estan en estado Pago en Linea';
            RETURN;
        END IF;
        UPDATE
                FAM_PAGOEXOL
            SET
                stpago='P',
                nuentifina=NULL,
                nuagen=NULL,
                nucaje=NULL,
                fcpagoreal=NULL,
                nutrancobl=NULL,
                FCPAGO=NULL,
                FCMODI=SYSDATE
             WHERE
                 nupagoexol=pa_nupagoexol;
        UPDATE
              FAM_PAGOEXTR
        SET
                nuentifina=0,
                nuagen=0,
                nudepo=NULL,
                fcpago=NULL
        WHERE
              nupagoextr = (SELECT nupagoextr FROM FAM_PAGOEXOL WHERE nupagoexol=pa_nupagoexol);
        --Revierte los pagos en cada cargo
              FOR pagoexol IN trae_pagoexol
              LOOP
                  Fapq_Cargabon.pr_actualizacargos (pagoexol.nucargabon,pagoexol.nucomp,0,-pagoexol.mopago,va_nuerro);
              END LOOP;
        COMMIT;
           EXCEPTION
               WHEN OTHERS THEN
                       pa_DsMens:=NVL(pa_DsMens,'Error Inesperado');
                       RETURN;
    END;
----------------------------------------------------------------------------------------------------------
    PROCEDURE pr_VencePagos IS
        CURSOR trae_vencidos IS
           SELECT * FROM FAM_PAGOEXOL WHERE fcvenc < TRUNC(SYSDATE,'DD') AND stpago IN ('E','P');
        va_dsMens VARCHAR2(1000);
    BEGIN
      FOR vencidos IN trae_vencidos
      LOOP
            pr_AnulaPago(vencidos.nupagoexol,va_dsMens);
            --pr_AnulaPagoExtraordinario(vencidos.nupagoExol,va_dsMens);
            --UPDATE FAM_PAGOEXOL SET stpago='V',fcmodi=SYSDATE WHERE nupagoexol=vencidos.nupagoexol;
      END LOOP;
      COMMIT;
    END;
----------------------------------------------------------------------------------------------------------
    PROCEDURE pr_CreaPagoExtraordinario (Pa_nupagoExol NUMBER,pa_dsMens OUT VARCHAR2) IS
       va_nupagoextr NUMBER;
          va_nuerro NUMBER;
          va_saldo NUMBER;
          CURSOR trae_pagoexol IS
             SELECT * FROM faw_pagoexol WHERE nupagoexol=pa_nupagoexol;
    BEGIN
        --Registra Maestro de Pagos extraordinarios
          pa_dsMens:='Intentando crear el Pago Extraordinario';
          SELECT SGC_FA_PAGOEXTR.NEXTVAL INTO va_nupagoextr FROM dual;
          INSERT INTO
             FAM_PAGOEXTR
          (
                NUPAGOEXTR,
                NUCOMP,
                CDCUENBANC,
                FCPAGO,
                NUCUEN,
                STPAGO,
                NUEMPLREGI,
                FCREGI,
                GLOSA,
                NUENTIFINA,
                NUAGEN,
                NUEMPLANUL,
                FCANUL,
                NUDEPO,
                VAMONT,
                NUSERV
          )
          SELECT
                  va_nupagoextr,
                nucomp,
                nupagoexol,
                fcpago,
                NVL(nucuen,0),
                'P',
                nuemplregi,
                fcregi,
                substr(dtglos,1,240),
                NVL(nuentifina,0),
                NVL(nuagen,0),
                NULL,
                NULL,
                NULL,
                topago,
                nuserv
          FROM
          FAM_PAGOEXOL
          WHERE
              nupagoexol=pa_nupagoexol;
          --Registro del Detalle
          pa_dsMens:='Intentando crear los cargos';
      FOR pagoexol IN trae_pagoexol
      LOOP
                INSERT INTO FAD_PAGOEXTR
              (
                NUPAGOEXTR ,
                NUCOMP     ,
                NUCARGABON ,
                MOPAGO     ,
                NUDETA     ,
                INTERES    ,
                TIMONE     ,
                TIPOCAMB   ,
                NUSERV
              )
              VALUES
              (
                va_nupagoextr,
                pagoexol.nucomp,
                pagoexol.nucargabon,
                pagoexol.mopago,
                pagoexol.nuline,
                0,
                pagoexol.timone,
                pagoexol.ticamb,
                pagoexol.nuserv
              );
              Fapq_Cargabon.pr_actualizacargos (pagoexol.nucargabon,pagoexol.nucomp,pagoexol.mopago,0,va_nuerro);
              --Verificaci.n del saldo
                  SELECT NVL(MAX(vamont-vamontfact),0) INTO va_saldo FROM FAT_CARGABON WHERE nucargabon=pagoexol.nucargabon AND nucomp=pagoexol.nucomp;
                  --CORRECCION ENERO 2014
                if pagoexol.timone='N' then
                    va_saldo := round(va_saldo,1);
                else
                    va_saldo := round(va_saldo,2);
                end if;
                  --FIN CORRECCION ENERO 2014
                  IF va_Saldo<0 THEN
                      pa_DsMens:='Monto del cargo '|| pagoexol.dscargabon ||' mayor al saldo. ('|| to_char(va_saldo) ||')';
                      RETURN;
                  END IF;
              --Fin verificaci.n de saldos
      END LOOP;
          UPDATE FAM_PAGOEXOL SET nupagoextr=va_nupagoextr WHERE nupagoexol=pa_nupagoexol;
          pa_dsmens:='';
           EXCEPTION
               WHEN OTHERS THEN
                       pa_DsMens:=NVL(pa_DsMens,'Error Inesperado');
                       RETURN;
    END;
----------------------------------------------------------------------------------------------------------
    PROCEDURE pr_AnulaPagoExtraordinario (Pa_nupagoExol NUMBER,pa_dsMens OUT VARCHAR2) IS
       va_nupagoextr NUMBER;
       va_stregi varchar2(1);
          va_nuerro NUMBER;
          CURSOR trae_pagoexol IS
             SELECT * FROM faw_pagoexol WHERE nupagoexol=pa_nupagoexol;

        va_Empl varchar2(500);
        va_para varchar2(500);
        va_asunto varchar2(1500);
        va_Servicio varchar2(1500);
        va_cuerpo varchar2(10000);
        va_tipagoexol varchar2(10);
        va_dsmens varchar2(200);
    BEGIN
      select max(stregi) into va_stregi from fam_pagoexol where nupagoexol=pa_nupagoexol;
      IF nvl(va_stregi,'A')<>'R' then
        pa_dsmens := 'Pago no existe o ya ha sido anulado.';
        return;
      END IF;

      pa_dsMens:= 'Revirtiendo cargos';
      FOR pagoexol IN trae_pagoexol
      LOOP
                va_nupagoextr:=pagoexol.nupagoextr;
                if pagoexol.stpago='C' then
                  Fapq_Cargabon.pr_actualizacargos (pagoexol.nucargabon,pagoexol.nucomp,-pagoexol.mopago,-pagoexol.mopago,va_nuerro);
              else
                  Fapq_Cargabon.pr_actualizacargos (pagoexol.nucargabon,pagoexol.nucomp,-pagoexol.mopago,0,va_nuerro);
              end if;
              va_tipagoexol := pagoexol.tipagoexol;
      END LOOP;

      pa_dsMens:= 'Anulando el pago extraordinario';
      UPDATE
              FAM_PAGOEXTR
      SET
              fcanul= SYSDATE,
              stpago='A'
      WHERE
             nupagoextr=va_nupagoextr;

      -- Env.o de mail si es TIPAGOEXOL='V' (VENTA | NORMAL)
      -- David Chalup
      -- Julio 2011
      pa_dsMens:= 'Enviando mail';
      if va_tipagoexol='V' then
          FOR pagoexol IN trae_pagoexol
          LOOP
                select max(trim(noempl)) into va_Empl from mgm_empl where nuempl=pagoexol.nuemplregi;
                select max(trim(cdusua)) into va_para from mgm_usua where nuempl=pagoexol.nuemplregi;
                if va_para is not null then
                    va_para := va_para||'@cre.com.bo';
                    va_Asunto := 'Cobranza Pago Extraordinario '||pagoexol.nupagoexol;
                    va_Servicio := fapq_traedesc.fn_cargabon(pagoexol.cdcargabon);
                    va_Cuerpo := 'El pago extraordinario '||pagoexol.nupagoexol||
                                 ' emitido por '||va_Empl||
                                 ' en fecha '||to_char(pagoexol.fcemis,'DD/MM/YYYY')||
                                 ' para la persona '||pagoexol.dsnomb||
                                 ' por el producto/servicio '||va_Servicio||
                                 ' por un monto de '||pagoexol.mopago||' '||pagoexol.moneda||
                                 ' ha sido anulado/vencido en cobranza en l.nea'||
                                 ' en fecha '||to_char(pagoexol.fcanul,'DD/MM/YYYY HH24:MI');
                    FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo',va_para,va_Asunto,va_Cuerpo,NULL);
                    FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','royrf@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                    --FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','juliaar@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                    --FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','cielocg@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                    FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','davidcm@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                    IF pagoexol.cdcargabon IN (250) THEN --ALQUILER DE POSTES
                      FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','juliaar@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                      FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','mariarbu@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                      FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','mariamn@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                      FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo','betzyaca@cre.com.bo',va_Asunto,va_Cuerpo,NULL);
                    END IF;

                    if pagoexol.DSMAILNOTI is not null then
                        FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo',pagoexol.DSMAILNOTI,va_Asunto,va_Cuerpo,NULL);
                    end if;
                    if pagoexol.DSMAILNOT1 is not null then
                        FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo',pagoexol.DSMAILNOT1,va_Asunto,va_Cuerpo,NULL);
                    end if;
                    if pagoexol.DSMAILNOT2 is not null then
                        FAPQ_TRAEDESC.Send_mail('cobranza@cre.com.bo',pagoexol.DSMAILNOT2,va_Asunto,va_Cuerpo,NULL);
                    end if;

                end if;

                -- Anulaci.n de la proforma de Laboratorio de aceites
                -- David Chalup
                -- Diciembre 2011
                    if pagoexol.cdcargabon IN (183) then
                        ltpq_laboaceite.PR_ANULAPRO(pagoexol.nucomp,pagoexol.nupagoexol,va_dsMens);
                    end if;
                -- Fin anulaci.n proforma laboratorio de aceites
          END LOOP;
       end if;
        -- Fin Env.o de Mail
      pa_dsMens:= NULL;


       EXCEPTION
           WHEN OTHERS THEN
                pa_DsMens:=NVL(pa_DsMens,'Error Inesperado..'||pa_dsmens);
                RETURN;
    END;

    PROCEDURE pr_RegistraServicio (      pa_nucomp NUMBER,
                                            pa_cdserv VARCHAR2,
                                          pa_cdmoti VARCHAR2,
                                          pa_nucuen NUMBER,
                                          pa_nuemplemis NUMBER,
                                          pa_fcemis DATE,
                                          pa_dtserv VARCHAR2,
                                          pa_nuserv OUT NUMBER,
                                          pa_Mensaje OUT VARCHAR2
                                      ) IS
        rServicio       Sopq_DatoServ.tServicio;
        vnusupe VARCHAR2(2);
        OperacionExitosa BOOLEAN;
        rMensaje Mgpq_mensreso.TRegistroMensaje ;
        Mensaje VARCHAR2(1000);
        BEGIN
                rServicio.nuComp         := pa_nucomp; -- compa..a
                rServicio.cdserv         := pa_cdserv;            -- c.digo del servicio
                rServicio.cdMoti         := pa_cdmoti;            -- motivo del servicio (en este caso CRE)
                rServicio.nuCuen         := pa_nucuen; -- cuenta del servicio
                rServicio.stserv         := 'P';              -- estado (en este caso EMITIDO)
                rServicio.tiprio         := 'M';              -- prioridad (en este caso MEDIA)
                rServicio.tiorig         := 'P';              -- origen (en este caso PERSONAL)
                rServicio.nuEmplemis     := pa_nuemplemis; -- Empleado que emite
                rServicio.fcemis         := pa_fcemis; -- Fecha de emisi.n
                rServicio.fcsoli         := pa_fcemis; -- Fecha de solicitud (que para este caso es la misma que la emisi.n)
                rServicio.fcregi         := SYSDATE; -- Fecha de registro (que para este caso es la misma que la emisi.n)
                rServicio.nuoficemis     := 1; -- Oficina que emite
                rServicio.nuoficDest     := 1; -- Oficina que cierra el servicio (es la misma que emite)
                rServicio.cdAreaEjecEmis := '001'; -- Area Ejecutora que emite el servicio
                rServicio.cdAreaEjecDest := '001'; -- Area Ejecutora que cierra el servicio
                rServicio.dtServ         := SUBSTR(pa_dtserv,1,240);      -- Glosa explicativa el servicio
            -- Solicitud de n.mero de servicio y n.mero de secuencia .nica de atenci.n
                SOPQ_CtrlCorr.Pr_GenerarCorrelativo(  rServicio.nucomp,
                                                      rServicio.nuemplEmis,
                                                        'OT', -- Seg.n el motivo que se vaya a asignar a .ste servicio,
                                                        rServicio.cdserv,
                                                        rServicio.cdmoti,
                                                        'C',
                                                        rServicio.fcregi,
                                                        rServicio.nuserv,
                                                        vnusupe,
                                                        OperacionExitosa,
                                                      rMensaje);
            -- Almacenamiento de encabezado de servicio, y generaci.n de los trabajos obligatorios
            -- para .ste tipo de servicio seg.n la configuraci.n existente. (no genera cargos)
               sopq_DatoServ.Pr_GrabaServicioInterno (rServicio,
                                                         rServicio.nucomp,
                                                      rServicio.nuserv,
                                                      OperacionExitosa,
                                                      Mensaje);
                IF OperacionExitosa THEN
                       Sopq_CtrlCorr.Pr_AceptoOperacion (rServicio.nucomp,
                                                          'C',
                                                          rServicio.nuserv,
                                                          OperacionExitosa,
                                                          rMensaje);
               END IF;
                pa_nuserv := rServicio.nuserv;
                --pa_mensaje:=Mensaje;
                --pa_mensaje:=rMensaje.detalleSituacion;
                COMMIT;
           EXCEPTION
               WHEN OTHERS THEN
                       pa_Mensaje:=NVL(pa_Mensaje,'Error Inesperado');
                       RETURN;
        END;

    PROCEDURE pr_CreaPagoExol (
                                pa_nucomp NUMBER,
                                pa_nucuen NUMBER,
                                pa_nuserv NUMBER,
                                pa_Nombre VARCHAR2,
                                pa_NIT    VARCHAR2,
                                pa_DTGLOS   VARCHAR2,
                                pa_nucargabon NUMBER,
                                pa_monto NUMBER,
                                pa_nupagoexol out NUMBER,
                                pa_dsmens out VARCHAR2,
                                pa_tipagoexol varchar2 default 'N',
                                pa_cddocu varchar2 default NULL,
                                pa_nutele number default null,
                                pa_email varchar2 default null
                              ) IS
        va_nupagoexol number;
        va_dsnomb varchar2(1000);
        va_cdnit  varchar2(100);
        va_nucuen number;
        va_nuserv number;
        cursor trae_cargabon is
            select
                ca.*,
                co.opcredfisc
            from
                fac_cargabon co,
                fat_cargabon ca
            where
                ca.nucargabon=pa_nucargabon and
                ca.nucomp=pa_nucomp and
                (ca.nucuen=va_nucuen or ca.nuserv=va_nuserv) and
                ca.stregi='R' and
                co.cdcargabon=ca.cdcargabon and
                co.nucomp=ca.nucomp and
                co.version=ca.version;

    ca trae_cargabon%rowtype;
    VA_TOPAGO number;
    VA_TICAMB NUMBER;
    VA_IMTOTABS NUMBER;
    VA_IMBPCF NUMBER;
    BEGIN
        --VALIDACI.N DE DATOS
            -- Validando la cuenta
            va_nucuen:=pa_nucuen;
            va_nuserv:=pa_nuserv;
            if va_nucuen is not null then
                va_nuserv:=null;
                va_dsnomb:=substr(sopq_datocuen.fn_traenombreafacturar(pa_nucomp,va_nucuen),1,100);
                va_cdnit := sopq_datocuenadic.fn_NITdeCuenta(pa_nucomp,va_nucuen);
            else
                va_nucuen:=null;
                select substr(max(nosoli),1,100) into va_dsnomb from sot_serv where nuserv=va_nuserv and nucomp=pa_nucomp;
            end if;
            va_dsnomb:= substr(nvl(ltrim(rtrim(pa_Nombre)),va_dsnomb),1,60);
            if va_dsnomb is null then
                pa_dsmens:='Nombre no valido.';
                return;
            end if;
            va_cdnit := nvl(nvl(ltrim(rtrim(pa_nit)),va_cdnit),'0');
            if va_cdnit is null then
                pa_dsmens:='NIT no valido.';
                return;
            end if;
            if pa_DTGLOS is null then
                pa_dsmens:='Falta campo glosa.';
                return;
            end if;
            if nvl(pa_monto,0)<=0 then
                pa_dsmens:='Monto no v.lido.';
                return;
            end if;
            open trae_cargabon;
            fetch trae_cargabon into ca;
            close trae_cargabon;
            if ca.nucargabon is null then
                pa_dsmens:='Cargo no existe.';
                return;
            end if;
            if (ca.vamont-ca.vamontfact)<pa_monto then
                pa_dsmens:='Monto excede el valor del saldo por facturar.';
                return;
            end if;

            if pa_tipagoexol in ('A','D') and ca.ticargabon='C' then
                pa_dsmens:='El tipo del cargo/abono debe ser del tipo Abono.';
                return;
            end if;

            if pa_tipagoexol in ('N','V') and ca.ticargabon='A' then
                pa_dsmens:='El tipo del cargo/abono debe ser del tipo Cargo.';
                return;
            end if;

        -- Calculos
           va_ticamb   := mgfn_cambdiar(TRUNC(SYSDATE-0/24,'DD'));
            select nvl( decode(ca.timone,'N',round(pa_monto,1),round(pa_monto,2)),0) into va_topago from dual;
            select nvl( decode(ca.timone,'N',round(pa_monto,1),round(round(pa_monto,2)*va_ticamb,1) ),0) into va_imtotabs from dual;
            select nvl( decode(ca.opcredfisc,'S',1,0) * ( decode(ca.timone,'N',round(pa_monto,1),round(round(pa_monto,2)*va_ticamb,1) ) ),0) into va_imbpcf from dual;

        --Registra Maestro de Pagos extraordinarios
          pa_dsMens:='Intentando crear el Pago Extraordinario';


          SELECT NUPAGOEXOL.NEXTVAL INTO va_nupagoexol FROM dual;

          INSERT INTO
             FAM_PAGOEXOL
          (
            NUPAGOEXOL ,
            NUCOMP     ,
            NUCUEN     ,
            NUSERV     ,
            DSNOMB     ,
            CDNIT      ,
            DTGLOS     ,
            STPAGO     ,
            STREGI     ,
            FCREGI     ,
            NUEMPLREGI ,
            TIMONE     ,
            TOPAGO     ,
            TICAMB     ,
            IMTOTABS   ,
            IMBPCF       ,
            TIPAGOEXOL,
            cddocu,
            nutele,
            email
          )
          VALUES
          (
                  va_nupagoexol,
                pa_nucomp,
                va_nucuen,
                va_nuserv,
                va_dsnomb,
                NVL(va_cdnit,'0'),
                pa_dtglos,
                'R',
                'R',
                SYSDATE,
                NVL(MGPQ_SEGUACCE.Fn_TraerNuEmpl,0),
                ca.timone,
                va_topago,
                va_ticamb,
                va_imtotabs,
                va_imbpcf,
                pa_tipagoexol,
                pa_cddocu,
                pa_nutele,
                pa_email
          );
          --Registro del Detalle
          pa_dsMens:='Intentando crear los cargos';
                INSERT INTO FAD_PAGOEXOL
              (
                NUPAGOEXOL,
                NULINE,
                NUCARGABON,
                MOPAGO
              )
              VALUES
              (
                va_nupagoexol,
                1,
                pa_nucargabon,
                pa_monto
              );
          pa_dsmens:= null;
          pa_nupagoexol := va_nupagoexol;
          --commit;
          return;

           EXCEPTION
               WHEN OTHERS THEN
                       pa_dsmens:= pa_dsmens||'. ERROR '||SQLCODE||SQLERRM;
                       fapq_insitu.pr_guardar_bitacora(    nvl(va_nucuen,0),
                                                           pa_nucomp,
                                                           to_char(sysdate,'YYYY'),
                                                           to_char(sysdate,'MM'),
                                                           pa_dsmens||'|'||to_char(va_nucuen)||'|'||to_char(va_nuserv)||'|'||va_dsnomb||'|'||va_cdnit||'|'||pa_dtglos||'|'||ca.timone||'|'||to_char(va_topago)||'|'||to_char(va_ticamb)||'|'||to_char(va_imtotabs)||'|'||to_char(va_imbpcf),
                                                           0,'PE','S');
                    --ROLLBACK;
                    return;
    END;
---------------------------------------------------------------------------------------------------------

   PROCEDURE pr_AdicCargoPagoExol ( pa_nupagoexol number,
                                    pa_nucomp number,
                                    pa_nucargabon number,
                                    pa_Monto number,
                                    pa_dsMens out VARCHAR2
                                  ) is
        va_topago   number;
        va_imtotabs number;
        va_imbpcf   number;
        va_ticamb   number;
        cursor trae_pagoexol is
            select
                nupagoexol,
                nuline,
                timone
            from faw_pagoexol where nupagoexol=pa_nupagoexol and stregi='R' and stpago='R'
            order by
                nuline desc;
        va_pagoexol trae_pagoexol%rowtype;

        cursor trae_cargabon is
            select
                nucargabon,timone,(vamont-vamontfact) saldo
            from fat_cargabon where nucargabon=pa_nucargabon and nucomp=pa_nucomp and stregi='R';
        va_cargabon trae_cargabon%rowtype;
    BEGIN
        --REVISANDO QUE EL PAGO EXTRAORDINARIO ESTE EN ESTADO REGISTRADO
            open trae_pagoexol;
            fetch trae_pagoexol into va_pagoexol;
            close trae_pagoexol;
            if va_pagoexol.nupagoexol is null then
                pa_dsMens := 'Pago extraordinario no existe o ya est. emitido.';
                return;
            end if;

        --REVISANDO EL CARGO
            open trae_cargabon;
            fetch trae_cargabon into va_cargabon;
            close trae_cargabon;
            if va_cargabon.nucargabon is null then
                pa_dsMens := 'Cargo no existe.';
                return;
            end if;

            if va_pagoexol.timone<>va_cargabon.timone then
                pa_dsMens := 'Moneda del cargo difiere del Pago Extraordinario.';
                return;
            end if;

            if pa_Monto <=0 then
                pa_dsMens := 'Monto debe ser mayor a cero.';
                return;
            end if;

            if pa_Monto>va_cargabon.saldo then
                pa_dsMens := 'Monto mayor que el saldo por facturar.';
                return;
            end if;

        --INSERTANDO EL CARGO
                INSERT INTO FAD_PAGOEXOL
              (
                NUPAGOEXOL,
                NULINE,
                NUCARGABON,
                MOPAGO
              )
              VALUES
              (
                pa_nupagoexol,
                va_pagoexol.nuline+1,
                pa_nucargabon,
                pa_monto
              );


        --RECALCULO DE LOS MONTOS
            va_ticamb   := mgfn_cambdiar(TRUNC(SYSDATE-0/24,'DD'));
            select
                nvl(sum( decode(ticargabon,'C',1,'A',-1,0) * decode(ca.timone,'N',round(mopago,1),round(mopago,2)) ),0),
                nvl(sum( decode(ticargabon,'C',1,'A',-1,0) * decode(ca.timone,'N',round(mopago,1),round(round(mopago,2)*va_ticamb,1) ) ),0),
                nvl(sum( decode(ticargabon,'C',1,'A',-1,0) * decode(co.opcredfisc,'S',1,0) * ( decode(ca.timone,'N',round(mopago,1),round(round(mopago,2)*va_ticamb,1) ) ) ),0)
            into
                va_topago,
                va_imtotabs,
                va_IMBPCF
            from
                fac_cargabon co,
                fat_cargabon ca,
                fad_pagoexol pa
            where
                pa.nupagoexol=pa_nupagoexol and
                ca.nucargabon=pa.nucargabon and
                ca.nucomp=pa_nucomp and
                co.cdcargabon=ca.cdcargabon and
                co.nucomp=ca.nucomp and
                co.version=ca.version;

        --ACTUALIZACION DE LOS TOTALES
            update
                fam_pagoexol
            set
                ticamb      = va_ticamb,
                topago      = va_topago,
                imtotabs    = va_imtotabs,
                imbpcf      = va_imbpcf
            where
                nupagoexol=pa_nupagoexol;
    END;







---------------------------------------------------------------------------------------------------------
    PROCEDURE pr_AnulaPagoConsolidado(Pa_nupagoExol NUMBER,pa_dsMens OUT VARCHAR2) IS
        --stpago (E)mitido para Cobranza, (P)ublicado en cobranza, Pagado En (L)inea, (C)onsolidado, (V)encido,N En proceso de anulaci.n
        --stregi (A)Anulado, (R) registrado
        -- Este procedimiento solo anula los pagos consolidados
              CURSOR trae_pagoexol IS
                       SELECT * FROM FAM_PAGOEXOL WHERE nupagoexol=pa_nupagoexol;
              va_pagoexol trae_pagoexol%ROWTYPE;
              va_ok VARCHAR2(200);
    BEGIN
      --VALIDACIONES
        OPEN trae_pagoexol;
        FETCH trae_pagoexol INTO va_pagoexol;
        CLOSE trae_pagoexol;
        IF va_pagoexol.nupagoexol IS NULL THEN
           pa_dsmens:='Error.  Pago no existe.';
           RETURN;
        END IF;
        IF va_pagoexol.stregi='A' THEN
           pa_dsmens:='Error.  Pago ya est. anulado.';
           RETURN;
        END IF;
        IF va_pagoexol.stpago NOT IN ('C') THEN
           pa_dsmens:='Error.  Pago no se encuentra consolidado.';
           RETURN;
        END IF;

        --pr_AnulaPago(Pa_nupagoExol,pa_dsMens); --SFE Merece una revision
        pr_AnulaPagoExtraordinario(pa_nupagoexol,pa_dsmens);
        if pa_dsmens is not null then
            RETURN;
        end if;
        UPDATE
            FAM_PAGOEXOL pa
        SET
            pa.stregi='A',
            pa.NUEMPLANUL=MGPQ_SEGUACCE.Fn_TraerNuEmpl,
            pa.FCANUL=SYSDATE
         WHERE
            nupagoexol=pa_nupagoexol;
        EXCEPTION
               WHEN OTHERS THEN
                       pa_DsMens:=NVL(pa_DsMens,'Error Inesperado');
                       RETURN;
    END;
----------------------------------------------------------------------------------------------------------
   PROCEDURE pr_CreaServicio(pa_nucomp        number,
                             pa_nucuen        number,
                             pa_Nombre        varchar2,
                             pa_Glosa         varchar2,
                             pa_nuserv  out   number,
                             pa_mensaje out   varchar2)
   IS
      CURSOR TraeAreaEjec IS
      SELECT    cdareaejec
        FROM   mge_emplarej
       WHERE  nucomp     = pa_nucomp
         AND nuempl      = MGPQ_SEGUACCE.Fn_TraerNuEmpl
         AND stregi      = 'R'
         AND ROWNUM      = 1 ;

      rServicio         Sopq_Datoserv.tServicio                                ;
      rMensaje          Mgpq_mensreso.TRegistroMensaje             ;

      vfceven          DATE;
      vnuSupe          NUMBER;
      vnuCargAbon       Fat_cargabon.nuCargAbon%TYPE                       ;
      vcdareaejec      VARCHAR2(6);

      SalirError      EXCEPTION ;
      va_nucargabon     number;
      va_nuerro         number;
      va_fccargo         date := sysdate;
      va_plazo        number := 1;
      va_monto         number := 0;
      OperacionExitosa boolean;
      va_existe        number;
   BEGIN
      OPEN  TraeAreaEjec ;
      FETCH TraeAreaEjec INTO vcdareaejec ;
      CLOSE TraeAreaEjec ;

      --PREPAGO
      vcdareaejec := nvl(vcdareaejec,0);

      IF vcdareaejec IS NULL  THEN
         pa_Mensaje := 'El empleado no tiene Area Ejecutora';
         return;
      END IF ;

      if nvl(pa_nucuen,0)>0 then
         select count(*) into va_existe from som_cuen where nucomp=pa_nucomp and nucuen=pa_nucuen;
         if va_existe=0 then
            pa_Mensaje := 'C.digo fijo no existe';
            return;
         end if;
      end if;

      rServicio.nuComp         := pa_nucomp           ;
      rServicio.cdserv         := '096'                              ; --  OTROS CARGOS
      rServicio.cdMoti         := '386'                              ; --  OTROS CARGOS
      rServicio.nuCuen         := nvl(pa_nucuen,0);
      rServicio.stserv         := 'P';
      rServicio.tiprio         := 'M';
      rServicio.tiorig         := 'P';
      rServicio.nuEmplemis     := nvl(MGPQ_SEGUACCE.Fn_TraerNuEmpl,0);
      rServicio.nuEmplcier     := nvl(MGPQ_SEGUACCE.Fn_TraerNuEmpl,0);
      rServicio.fcemis         := sysdate;
      rServicio.fcsoli         := sysdate;
      rServicio.fcregi         := sysdate;
      rServicio.fccier         := sysdate;
      rServicio.nuoficemis     := '01';
      rServicio.nuoficDest     := '01';
      rServicio.cdAreaEjecEmis := vcdareaejec           ;
      rServicio.cdAreaEjecDest := vcdareaejec            ;
      rServicio.dtServ         := pa_glosa;
      rServicio.Nosoli         := pa_Nombre;

      Sopq_Ctrlcorr.Pr_GenerarCorrelativo(rServicio.nucomp, rServicio.nuemplEmis, 'OT', rServicio.cdserv,
                                          rServicio.cdmoti, 'C', rServicio.fcregi, rServicio.nuserv,
                                          vnusupe, OperacionExitosa,  rMensaje);
      IF NOT OperacionExitosa THEN
         pa_Mensaje := rMensaje.DetalleSituacion;
         return;
      END IF ;
      Sopq_Datoserv.Pr_GrabaServicioInterno (rServicio, rServicio.nucomp, rServicio.nuserv,
                                             OperacionExitosa, pa_Mensaje);
      IF not OperacionExitosa THEN
         return;
      END IF ;

      Sopq_Ctrlcorr.Pr_AceptoOperacion (rServicio.nucomp, 'C', rServicio.nuserv, OperacionExitosa, rMensaje);
      IF NOT OperacionExitosa THEN
         pa_mensaje := rMensaje.DetalleSituacion;
         return;
      END IF ;
      pa_nuserv:=rServicio.nuserv;
      COMMIT ;
      pa_mensaje:=null;

      EXCEPTION
         WHEN OTHERS THEN
            OperacionExitosa := FALSE ;
            pa_Mensaje:=SQLERRM ;
   END;

/*
    ----------------------------------------------------------------
    GENERACI.N/EMISI.N DE PAGO EXTRAORDINARIO CON Y SIN QR
    .................................................................
    1)  Se adicionan par.metros nuevos, por defecto en NULO, tal y como
        lo requieren ahora los pagos extraordinario:
        - CDDOCU (CI/NIT/OTRO/NULO por defecto)==> Valores obtenidos de la
              FARG430
        - TEL.FONO
        - MAIL
        - CON/SIN QR
        - VIGENCIA para el QR  (se recibe el valor en MINUTOS),por defecto 10 min
        La necesidad surge para disponer de un WS que permita a TILUCHI generar
        pagos extraordinarios por la venta de pliegos.
    2) El TEL.FONO es un dato obligatorio (tal como es en la pantalla FARG430),
       adem.s debe ser v.lido
    .................................................................
    Fecha: Abril/2024
    Autor: Gabriela Salvador
    ----------------------------------------------------------------    */
    PROCEDURE pr_EmiteVentaServicio (
                                        pa_nucomp       NUMBER,
                                        pa_nucuen       NUMBER,
                                        pa_Nombre       VARCHAR2,
                                        pa_NIT          VARCHAR2,
                                        pa_DTGLOS       VARCHAR2,
                                        pa_cdcargabon   NUMBER,
                                        pa_monto        in out NUMBER,
                                        pa_nupagoexol   out NUMBER,
                                        pa_dsmens       out VARCHAR2,
                                        pa_fcemis       date default null,
                                        pa_fcvenc       date default null,
                                        -- Abril/2024
                                        pa_cddocu       varchar2 default null,
                                        pa_nutele       number default 0,
                                        pa_email        varchar2 default null
                                      ) is
        va_nuserv number;
        va_nucargabon number;
        va_fccargo         date := sysdate;
        va_plazo        number := 1;
        va_nuerro       number;
        va_fcvenc       date;
        va_tivenc       varchar2(100);
    begin

        if pa_cdcargabon is null then
            pa_dsmens:='Indique el producto o servicio';
            return;
        end if;

        if NVL(pa_MONTO,0)<=0 then
            pa_dsmens:='Indique el monto del producto o servicio';
            return;
        end if;

        if pa_Nombre is null then
            pa_dsmens:='Indique el Nombre';
            return;
        end if;

        if pa_DTGLOS is null then
            pa_dsmens:='Indique la Glosa';
            return;
        end if;

        if Nvl(pa_nutele,0)=0 then
            pa_dsmens:='Indique el n.mero de tel.fono';
            return;
        end if;

        If sopq_ivr.Fn_TelefonoValido(pa_nutele) ='N' Then
            pa_dsmens:='El tel.fono no es v.lido';
            return;
        END IF;

        --CREACI.N DEL SERVICIO
        pr_CreaServicio(pa_nucomp,pa_nucuen,pa_Nombre,pa_dtglos,va_nuserv,pa_dsmens);
        if pa_dsmens is not null then
            return;
        end if;

        --CREACION DEL CARGO
        fapq_cargabon.pr_inscargserv (  pa_nucomp,
                                        pa_nucuen,
                                        va_NUSERV,
                                        pa_cdcargabon,
                                        'C',
                                        NULL,
                                        'FA',
                                        null,
                                        va_fccargo,
                                        va_plazo,
                                        pa_monto,
                                        va_nucargabon,
                                        va_nuerro
                                    );

        if va_nuerro is not null then
            return;
        end if;

        --CREACI.N DEL PAGO EXTRAORDINARIO
        pr_CreaPagoExol (
                                        pa_nucomp ,
                                        NULL ,
                                        va_nuserv ,
                                        pa_Nombre ,
                                        NVL(pa_NIT,'0')    ,
                                        pa_DTGLOS   ,
                                        va_nucargabon ,
                                        pa_monto  ,
                                        pa_nupagoexol,
                                        pa_dsmens,
                                        'V',
                                        pa_cddocu,
                                        pa_nutele,
                                        pa_email
                                      );
        IF pa_dsmens is not null then
            rollback;
            return;
        END IF;

        va_fcvenc := pa_fcvenc;
        if va_fcvenc is null then
             select max(tivenc) into va_tivenc from fac_conccaab where cdcargabon=pa_cdcargabon;
             if va_tivenc='DIA' then
                 va_fcvenc := trunc(sysdate,'DD');
             elsif va_tivenc='MES' then
                 --va_fcvenc := last_day(trunc(sysdate,'DD'));
                 va_fcvenc := (trunc(sysdate,'DD')+31);
             elsif va_tivenc='NUNCA' then
                 va_fcvenc := '31/12/2999';
             else
                 null;
             end if;
        end if;

        --EMISI.N DEL PAGO EXTRAORDINARIO
        fapq_pagoextr.pr_EmitePago(pa_nupagoexol,pa_dsmens,pa_fcemis,va_fcvenc);
        commit;

        EXCEPTION
                WHEN OTHERS THEN
                     rollback;
                     pa_dsmens:=pa_dsmens || SQLERRM ;

    END;


    FUNCTION fn_PagoEstaAnulado (Pa_nupagoExol number) return varchar2 is
        va_stregi varchar2(10);
    begin
        select max(stregi) into va_stregi from fam_pagoexol where nupagoexol=Pa_nupagoExol;
        if nvl(va_stregi,'X')='A' then
            return 'S';
        else
            return 'N';
        end if;
    end;

    PROCEDURE pr_TransfiereCargos   (   pa_nupagoexol number,
                                        pa_nuservHasta number,
                                        pa_nucomp number,
                                        pa_dsMens out varchar2
                                    ) is
        va_nuservDesde number;
        va_Existe number;
    BEGIN
        --OBTENIENDO EL N.MERO DE SERVICIO
            pa_dsMens := 'Intentando obtener el servicio origen.';
            select
                max(nuserv)
            into
                va_nuservdesde
            from
                fam_pagoexol
            where
                nupagoexol=pa_nupagoexol and
                nucomp=pa_nucomp;

            if va_nuservDesde is null then
               pa_dsMens:='Pago extraordinario no existe o no est. relacionado a ning.n servicio.';
               return;
            end if;

        --VERIFICANDO QUE EXISTA EL SERVICIO DESTINO
           SELECT count(*) into va_existe from sot_Serv
           where nucomp=pa_nucomp and nuserv=pa_nuservHasta;

           if va_existe=0 then
               pa_dsMens:='Nuevo Servicio no Existe.';
               return;
           end if;


        --ACTUALIZANDO EL PAGO EXTRAORDINARIO AL NUEVO SERVICIO
            pa_dsMens := 'Intentando actualizar el pago extraordinario al nuevo servicio.';
            update
                fam_pagoexol
            set
                nuserv=pa_nuservHasta
            where
                nuserv=va_nuservDesde and
                nupagoexol=pa_nupagoexol and
                nucomp=pa_nucomp;

            update
                fam_pagoextr
            set
                nuserv=pa_nuservHasta,
                nucuen=(select max(nucuen) from sot_serv where nuserv=pa_nuservHasta and nucomp=pa_nucomp)
            where
                nuserv=va_nuservDesde and
                cdcuenbanc=pa_nupagoexol and
                nucomp=pa_nucomp;

         --ACTUALIZANDO EL CARGO AL NUEVO SERVICIO
            pa_dsMens := 'Intentando actualizar el cargo al nuevo servicio.';
            update
                fat_cargabon
            set
                nuserv=pa_nuservHasta,
                nucuen=(select max(nucuen) from sot_serv where nuserv=pa_nuservHasta and nucomp=pa_nucomp)
            where
                nuserv=va_nuservDesde and
                nucomp=pa_nucomp and
                cdcargabon in (select cdcargabon from faw_pagoexol where nupagoexol=pa_nupagoexol and nucomp=pa_nucomp);


         --POR SEGURIDAD, CAMBIANDO EL ESTADO DEL CARGO A ESTADO REGISTRADO A LOS CARGOS COBRADOS
            pa_dsMens := 'Intentando cambiar el estado del cargo a Registrado.';
            UPDATE
                fat_cargabon
            set
                stregi='R'
            where
                nuserv=pa_nuservHasta and
                nucomp=pa_nucomp and
                --cdcargabon in (36,120,141,142,167,168,169,170,241,253) and
                stregi='A' and
                vamontcobr>=vamont;

         --POR SEGURIDAD, CAMBIANDO EL ESTADO DEL CARGO A ESTADO ANULADO A LOS CARGOS IMPAGOS
            pa_dsMens := 'Intentando cambiar el estado del cargo a Anulado.';
            /*
            UPDATE
                fat_cargabon
            set
                stregi='A'
            where
                nuserv=pa_nuservHasta and
                nucomp=pa_nucomp and
                --cdcargabon in (36,120,141,142,167,168,169,170,241,253) and
                stregi='R' and
                vamontfact=0 and
                vamontcobr=0;
            */
            commit;
           pa_dsMens:=NULL;
           return;

           EXCEPTION
               WHEN OTHERS THEN
                    pa_dsMens := SQLERRM || CHR (13)||CHR (10) || pa_dsmens;
                    RETURN;

    END;

END;