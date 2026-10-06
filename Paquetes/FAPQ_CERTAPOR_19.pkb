/*******************************************************************************
 * METADATA
 * Analista     : IGORCB
 * Descargado   : 06/10/2026, 10:28:09
 * Owner        : SGC_FA
 * Versión      : 19
 *******************************************************************************/
CREATE OR REPLACE PACKAGE BODY SGC_FA.fapq_CertApor IS
-- Descripci¿n    : Paquete que implementa procedimientos para la regularizaci¿n y estadisticas de Certificados de Aportaci¿n
-- Tablas         :
-- Creaci¿n       : JUNIO 2016
-- Finalizaci¿n   :
-- Autor          : David Chalup
-- Modificaci¿n   :
---- Autor          :

    va_DiaReviSaldoAFCOOP number := 2;  --Dia inicial de revisi¿n de tasa AFCOOP

    FUNCTION FN_CUOTACAPITALFACTNORM (PA_NUCARGABON NUMBER,PA_NUCOMP NUMBER) RETURN NUMBER IS
        va_valor number;
    BEGIN
        select
            nvl(sum(mocapisus),0)
        into
            va_valor
        from
            dct_docu doc,
            dce_cargabon car
        where
            car.nucargabon=pa_nucargabon and
            car.nucomp=pa_nucomp and
            doc.nudocu=car.nudocu and
            doc.nucomp=car.nucomp and
            doc.stfact NOT IN ('M','A','X','C');
        return va_valor;
    END;

    FUNCTION FN_CUOTACAPITALPAGOEXTR (PA_NUCARGABON NUMBER,PA_NUCOMP NUMBER) RETURN NUMBER IS
        va_valor number;
    BEGIN
        select
            nvl(sum(mopago),0)
        into
            va_valor
        from
            fam_pagoextr m,
            fad_pagoextr d
        where
            d.nucargabon=PA_nucargabon and
            d.nucomp=PA_nucomp and
            m.nupagoextr=d.nupagoextr and
            m.nucomp=d.nucomp and
            m.stpago = 'P';
        return va_valor;
    END;

   FUNCTION FN_CUOTACAPITAL (PA_NUCARGABON NUMBER,PA_NUCOMP NUMBER) RETURN NUMBER IS
   BEGIN
        RETURN FN_CUOTACAPITALFACTNORM(PA_NUCARGABON,PA_NUCOMP) + FN_CUOTACAPITALPAGOEXTR(PA_NUCARGABON,PA_NUCOMP);
   END;


    FUNCTION FN_CAPITALREAL (   PA_NUCOMP NUMBER,
                                pa_nucuen number,
                                PA_VERSION NUMBER,
                                pa_andocu number,
                                pa_medocu number,
                                pa_mocapibs number,
                                pa_mointebs number,
                                pa_mocapisus number
                            ) return number IS
        va_tipocamb number;
        va_capireal number;
        va_intereal number;
    BEGIN
        va_tipocamb := mgfn_tipocamb(to_date(pa_andocu*100+pa_medocu,'YYYYMM'));
        va_capireal := nvl(round(pa_mocapibs/va_tipocamb,2),0);
        if abs(nvl(va_capireal,0)-round(nvl(pa_mocapisus,0),2))>0.01 then
            return va_capireal;
        else
            return pa_mocapisus;
        end if;
    END;

    FUNCTION FN_INTERESREAL (   PA_NUCOMP NUMBER,
                                pa_nucuen number,
                                PA_VERSION NUMBER,
                                pa_andocu number,
                                pa_medocu number,
                                pa_mocapibs number,
                                pa_mointebs number,
                                pa_mointesus number
                            ) return number IS
        va_tipocamb number;
        va_capireal number;
        va_intereal number;
    BEGIN
        va_tipocamb := mgfn_tipocamb(to_date(pa_andocu*100+pa_medocu,'YYYYMM'));
        va_intereal := nvl(round(pa_mointebs/va_tipocamb,2),0);
        if abs(nvl(va_intereal,0)-round(nvl(pa_mointesus,0),2))>0.01 then
            return va_intereal;
        else
            return pa_mointesus;
        end if;
        return va_intereal;
    END;

    FUNCTION FN_INTERESMIX (   PA_NUCOMP NUMBER,
                                pa_nucuen number,
                                PA_VERSION NUMBER,
                                pa_andocu number,
                                pa_medocu number,
                                pa_mocapibs number,
                                pa_mointebs number,
                                pa_mocapisus number
                            ) return number IS
    BEGIN

      --SI YA TIENE INTERES EN BOLIVIANOS, 21F (SE RESPETA)
        if nvl(pa_mointebs,0)>0 then
            return 0;
        end if;

      --DESAGREGACION COMPA¿IA 1
        if pa_nucomp=1 then
            if pa_andocu*100+pa_medocu<=199901 then --SEGUN CI/GF/03/2017
                if pa_mocapisus<=1.67 then
                    return 0;
                else
                    return 1.67;
                end if;
            else
                return 0;
            end if;
        end if;


      --DESAGREGACION COMPA¿IA 2

        if pa_nucomp=2 then
            if pa_andocu*100+pa_medocu<=200210 then
                if pa_mocapisus<=1.67 then
                    return 0;
                else
                    return 1.67;
                end if;
            else
                return 0;
            end if;
        end if;

      --DESAGREGACION COMPA¿IA 3

        if pa_nucomp=3 then
            if pa_andocu*100+pa_medocu<=200210 then
                if pa_mocapisus<=0.41 then
                    return 0;
                else
                    return 0.41;
                end if;
            else
                return 0;
            end if;
        end if;


      --DESAGREGACION COMPA¿IA 4

        if pa_nucomp=4 then
            if pa_andocu*100+pa_medocu<=199912 then
                if pa_mocapisus<=1.11 then
                    return 0;
                else
                    return 1.11;
                end if;
            else
                return 0;
            end if;
        end if;

      --DESAGREGACION COMPA¿IA 5

        if pa_nucomp=5 then
            if pa_andocu*100+pa_medocu<=200210 then
                if pa_mocapisus<=0.41 then
                    return 0;
                else
                    return 0.41;
                end if;
            else
                return 0;
            end if;
        end if;

      --DESAGREGACION COMPA¿IA 6

        if pa_nucomp=6 then
            if pa_andocu*100+pa_medocu<=200608 then
                if pa_mocapisus<=1.67 then
                    return 0;
                else
                    return 1.67;
                end if;
            else
                return 0;
            end if;
        end if;


      --DESAGREGACION RESTO COMPA¿IAS
        return 0;

    END;

    PROCEDURE PR_SALDOCERTAPOR (    pa_ansald number default to_char(add_months(sysdate,-1),'YYYY'),
                                    pa_mesald number default to_char(add_months(sysdate,-1),'MM')
                                    ,pa_nucomp number default null,pa_nucargabon number default null
                               ) IS
        --DEMORA 5 HORAS
        Cursor trae_ca is

            SELECT
                ca.nucomp,
                ca.nucargabon,
                ca.cdcargabon,
                ca.nucuen,
                ca.version,
                ca.fccargo,
                ca.vamont,
                ca.vamontfact,
                ca.vamontcobr,
                ca.stregi,
                ca.stfact,
                ca.opfactcaab,
                (SELECT TIAFIL          FROM SOM_CUEN WHERE NVL(CA.NUCUEN,0)>0 AND NUCOMP=CA.NUCOMP AND NUCUEN=CA.NUCUEN) TIAFIL,
                (SELECT STCUEN          FROM SOM_CUEN WHERE NVL(CA.NUCUEN,0)>0 AND NUCOMP=CA.NUCOMP AND NUCUEN=CA.NUCUEN) STCUEN,
                (SELECT TRUNC(FCALTA)   FROM SOM_CUEN WHERE NVL(CA.NUCUEN,0)>0 AND NUCOMP=CA.NUCOMP AND NUCUEN=CA.NUCUEN) FCALTA
            FROM
                fat_cargabon ca
            WHERE
                ca.cdcargabon=2
              AND  ca.timone='E'
              AND  ca.ticargabon='C'
              and  ca.nucomp=nvl(pa_nucomp,ca.nucomp) and ca.nucargabon=nvl(pa_nucargabon,ca.nucargabon)
              AND  ca.vamont IN (400,410);


    va_saldcaNull far_saldca%rowtype;
    va_saldca far_saldca%rowtype;
BEGIN
    DELETE FROM far_saldca ca
    where
        ca.nucomp=nvl(pa_nucomp,ca.nucomp) and ca.nucargabon=nvl(pa_nucargabon,ca.nucargabon) and
        ansald=pa_ansald and
        mesald=pa_mesald;
    commit;

    for ca in trae_ca
    loop
        va_saldca.ansald            := pa_ansald;
        va_saldca.mesald            := pa_mesald;
        va_saldca.nucomp            := ca.nucomp;
        va_saldca.nucuen            := ca.nucuen;
        va_saldca.cdcargabon        := ca.cdcargabon;
        va_saldca.nucargabon        := ca.nucargabon;
        va_saldca.fccargo           := ca.fccargo;
        va_saldca.nuvers            := ca.version;
        va_saldca.vamont            := ca.vamont;
        va_saldca.vamontfact        := ca.vamontfact;
        va_saldca.mopagoextr        := 0;
        va_saldca.mopagoextrbs      := 0;
        va_saldca.fcregi            := sysdate;
        va_saldca.stregi            := ca.stregi;
        va_saldca.STFACT            := ca.STFACT;
        va_saldca.OPFACTCAAB        := ca.OPFACTCAAB;
        va_saldca.TIAFIL            := ca.TIAFIL;
        va_saldca.STCUEN            := ca.STCUEN;
        va_saldca.FCALTA            := ca.FCALTA;


        insert into far_saldca values va_saldca;
        commit;
    end loop;

    PR_SALDOCERTAPORFACT    (pa_ansald,pa_mesald,pa_nucomp,pa_nucargabon);
    PR_SALDOCERTAPORPE      (pa_ansald,pa_mesald,pa_nucomp,pa_nucargabon);
    PR_APORTACIONES         (pa_ansald,pa_mesald,pa_nucomp,pa_nucargabon);
    PR_DEVOLUCIONES         (pa_ansald,pa_mesald,pa_nucomp,pa_nucargabon);
    PR_CERTIFICADOS         (pa_ansald,pa_mesald,pa_nucomp,pa_nucargabon);
    PR_SALDOPOSTERIOR       (pa_ansald,pa_mesald,pa_nucomp,pa_nucargabon);
    PR_FACTMES              (pa_ansald,pa_mesald,pa_nucomp,pa_nucargabon);


    --BORRANDO LOS CARGOS POSTERIORES AL PERIODO
        DELETE FROM
            far_Saldca ca
        where
               ansald=pa_ansald and
               mesald=pa_mesald AND
               ca.nucomp=nvl(pa_nucomp,ca.nucomp) and ca.nucargabon=nvl(pa_nucargabon,ca.nucargabon) and
               TO_CHAR(fccargo,'YYYYMM')>pa_ansald*100+pa_mesald AND
               NVL(MOCAPISUS,0)+NVL(MOPAGOEXTR,0)=0;
        COMMIT;

    --ACTUALIZANDO EL ESTADO DEL CERTIFICADO DE APORTACION
        UPDATE
            FAR_SALDCA SAL
        SET
            STCERT =
                        (CASE
                            WHEN STCERT='DEV' AND NVL(MOCAPISUS,0)=0 THEN 'DEV'
                            WHEN MOCAPISUSDEVO>0 THEN 'DEV'
                            WHEN NVL(MOCAPISUSCOBR,0)+NVL(MOPAGOEXTR,0)=0 THEN 'SUS'
                            WHEN NVL(MOCAPISUSCOBR,0)+NVL(MOPAGOEXTR,0)>=410 THEN 'EMI'
                            ELSE 'PEN'
                        END)
        WHERE
            ANSALD=pa_ansald AND
            MESALD=pa_mesald AND
            STREGI='R' AND
            NVL(STCERT,'X') <>
                        (CASE
                            WHEN MOCAPISUSDEVO>0 THEN 'DEV'
                            WHEN STCERT='DEV' AND NVL(MOCAPISUS,0)=0 THEN 'DEV'
                            WHEN NVL(MOCAPISUSCOBR,0)+NVL(MOPAGOEXTR,0)=0 THEN 'SUS'
                            WHEN NVL(MOCAPISUSCOBR,0)+NVL(MOPAGOEXTR,0)>=410 THEN 'EMI'
                            ELSE 'PEN'
                        END) ;
        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
        gopq_cpt.Enviar_mail('tecnologia@cre.com.bo','davidcm@cre.com.bo','Error PR_SALDOCERTAPOR',SQLERRM,null);


END;

PROCEDURE PR_SALDOCERTAPORFACT (    pa_ansald number default to_char(add_months(sysdate,-1),'YYYY'),
                                    pa_mesald number default to_char(add_months(sysdate,-1),'MM')
                                    ,pa_nucomp number default null,pa_nucargabon number default null
                               ) IS
    --DEMORA 2 HORAS

        va_fcpago date := to_date(pa_ansald*100+pa_mesald,'YYYYMM');
        va_fcpagoMesSig date := add_months(va_fcpago,1);


        cursor trae_docu is
            SELECT
                y.nucargabon,
                y.nucomp,
                sum(Y.mocapisus) mocapisus,
                sum(
                    (case when  stpago in ('P','L','R','T') and
                                nvl(fcpago,'01/01/1900')<va_fcpagoMesSig then mocapisus
                                else 0 end)
                ) mocapisuscobr,
                sum(Y.mocapibs) mocapibs,
                sum(
                    (case when  stpago in ('P','L','R','T') and
                                nvl(fcpago,'01/01/1900')<va_fcpagoMesSig then mocapibs
                                else 0 end)
                ) mocapibscobr,
                sum(
                    (case when (    stpago not in ('P','L','R','T') or --IMPAGO
                                    nvl(fcpago,'01/01/1900')>=trunc(va_fcpagoMesSig,'MM') --PAGADO MES SIGUIENTE
                               ) and
                               exists (select 'x' from dct_movidocu movi where movi.nudocu=x.nudocu and movi.nucomp=x.nucomp and movi.timovi='CA')
                               then mocapisus else 0 end)
                ) mocapisuscast,
                sum((fapq_CertApor.FN_CAPITALREAL(
                                                  X.NUCOMP,
                                                  X.nucuen,
                                                  Y.NUVERSCAPI,
                                                  X.andocu,
                                                  X.medocu,
                                                  Y.mocapibs,
                                                  Y.mointebs,
                                                  Y.mocapisus
                                                )
                )) mocapisusajus,
                sum((fapq_CertApor.FN_INTERESMIX(
                                                  X.NUCOMP,
                                                  X.nucuen,
                                                  Y.NUVERSCAPI,
                                                  X.andocu,
                                                  X.medocu,
                                                  Y.mocapibs,
                                                  Y.mointebs,
                                                  Y.mocapisus
                                                )
                )) mointemix,
                sum(Y.mointesus) mointesus,
                sum((fapq_CertApor.FN_INTERESREAL(
                                                  X.NUCOMP,
                                                  X.nucuen,
                                                  Y.NUVERSCAPI,
                                                  X.andocu,
                                                  X.medocu,
                                                  Y.mocapibs,
                                                  Y.mointebs,
                                                  Y.mointesus
                                                )
                )) mointesusajus,
                count(*) cant,
                min(andocu*100+medocu) desde,
                max(andocu*100+medocu) Hasta
            FROM
                dct_docu x,
                dce_cargabon y
            WHERE
                y.nudocu=y.nudocu+0
                and y.nuconccapi=2
                and x.nucomp=y.nucomp
                and x.nudocu=y.nudocu
                AND x.stfact IN ('N','F')
                and y.nucomp=nvl(pa_nucomp,y.nucomp) and y.nucargabon=nvl(pa_nucargabon,y.nucargabon)
            group by
                y.nucargabon,
                y.nucomp;

BEGIN
    UPDATE far_saldca ca
    SET
        MOCAPISUS=NULL,
        mocapisuscobr=null,
        mocapibs=null,
        mocapibscobr=null,
        mocapisuscast=null,
        MOCAPISUSAJUS=NULL,
        MOINTEMIX=NULL,
        MOINTESUS=NULL,
        MOINTESUSAJUS=NULL
    WHERE
        ca.nucomp=nvl(pa_nucomp,ca.nucomp) and ca.nucargabon=nvl(pa_nucargabon,ca.nucargabon) and
        ANSALD=PA_ANSALD AND
        MESALD=PA_MESALD;

    COMMIT;

    for docu in trae_docu
    loop
        update
            far_saldca
        set
            MOCAPISUS=NVL(DOCU.mocapisus,0),
            MOCAPISUSCOBR=NVL(DOCU.mocapisuscobr,0),
            MOCAPIBS=NVL(DOCU.mocapiBS,0),
            MOCAPIBSCOBR=NVL(DOCU.mocapiBScobr,0),
            MOCAPISUSCAST=NVL(DOCU.mocapisuscast,0),
            MOCAPISUSAJUS=NVL(DOCU.mocapisusajus,0),
            MOINTEMIX=NVL(DOCU.MOINTEMIX,0),
            MOINTESUS=NVL(DOCU.mointesus,0),
            MOINTESUSAJUS=NVL(DOCU.mointesusajus,0),
            fcmodi=sysdate
        where
            ANSALD=PA_ANSALD AND
            MESALD=PA_MESALD AND
            nucargabon=docu.nucargabon and
            nucomp=docu.nucomp;
        commit;
    end loop;

END;

PROCEDURE PR_SALDOCERTAPORPE (    pa_ansald number default to_char(add_months(sysdate,-1),'YYYY'),
                                    pa_mesald number default to_char(add_months(sysdate,-1),'MM')
                                    ,pa_nucomp number default null,pa_nucargabon number default null
                               ) IS
    --DEMORA 3 MINUTOS

        va_fcpago date := to_date(pa_ansald*100+pa_mesald,'YYYYMM');
        va_fcpagoMesSig date := add_months(va_fcpago,1);

    cursor trae_pe is
        select
            d.nucargabon,
            d.nucomp,
            nvl(sum(mopago),0) mopago,
            nvl(sum(round(mopago*tipocamb,1)),0) mopagoBS
        from
            fam_pagoextr m,
            fad_pagoextr d
        where
            d.nucomp=nvl(pa_nucomp,d.nucomp) and d.nucargabon=nvl(pa_nucargabon,d.nucargabon) and
            d.nucargabon=d.nucargabon+0 and
            d.nupagoextr=d.nupagoextr+0 and
            exists (select 'x' from fat_cargabon c where
                        c.nucargabon=d.nucargabon and
                        c.nucomp=d.nucomp and
                        c.cdcargabon=2
                   ) and
            m.nupagoextr=d.nupagoextr and
            m.nucomp=d.nucomp and
            m.stpago='P' and
            m.fcpago<va_fcpagoMesSig
        group by
            d.nucargabon,
            d.nucomp;

begin

    update
        far_saldca ca
    set
        MOPAGOEXTR=NULL,
        MOPAGOEXTRBS=NULL
    WHERE
        ca.nucomp=nvl(pa_nucomp,ca.nucomp) and ca.nucargabon=nvl(pa_nucargabon,ca.nucargabon) and
        ANSALD=PA_ANSALD AND
        MESALD=PA_MESALD AND
        MOPAGOEXTR IS NOT NULL;
    COMMIT;

    for pe in trae_pe
    loop
        update
            far_saldca
        set
            MOPAGOEXTR=NVL(pe.MOPAGO,0),
            mopagoextrbs=NVL(pe.MOPAGOBS,0),
            fcmodi=sysdate
        where
            ANSALD=PA_ANSALD AND
            MESALD=PA_MESALD AND
            nucargabon=pe.nucargabon and
            nucomp=pe.nucomp;
        commit;
    end loop;

    --TABLA TEMPORAL DE PAGOS EXTRAORDINARIOS POR RECONOCIMIENTOS

    if pa_ansald*100+pa_mesald<=201803 THEN --MES DE REGULARIZACION
        DELETE FROM far_certaporPE;
        commit;

        INSERT INTO far_certaporPE
        select
            CA.NUCOMP,
            CA.NUCUEN,
            CA.NUCARGABON,
            TO_CHAR(CA.FCCARGO,'YYYY-MM') FCCARG,
            TO_CHAR(NVL(CA.FCULTIPAGO,CA.FCMODI),'YYYY-MM') FCMODI,
            (SELECT CU.STCUEN FROM SOM_CUEN CU WHERE CU.NUCUEN=CA.NUCUEN AND CU.NUCOMP=CA.NUCOMP) STCUEN,
            CA.STREGI,
            CA.STFACT,
            CA.OPFACTCAAB,
            CA.VAMONT,
            CA.VAMONTFACT,
            DE.MOPAGO,
            PM.NUPAGOEXTR,
            PM.NUCUEN NUCUENP,
            (select tiafil from som_cuen cu where cu.nucomp=pm.nucomp and cu.nucuen=pm.nucuen) tiafil,
            TRUNC(PM.FCPAGO) FCPAGO,
            PM.CDCUENBANC,
            PM.NUDEPO,
            translate(PM.GLOSA,chr(9)||chr(10)||chr(13),'   ') GLOSA,
            COUNT(*) OVER (PARTITION BY CA.NUCARGABON,CA.NUCOMP,DE.MOPAGO) DUPLI,
            MIN(PM.NUPAGOEXTR) OVER (PARTITION BY CA.NUCARGABON,CA.NUCOMP,DE.MOPAGO) NUPAGOVAL
        from
            fam_pagoextr pm,
            fad_pagoextr de,
            fat_cargabon ca
        where
            ca.cdcargabon=2 and
            ca.timone='E' and
            ca.stregi='R' and
            ca.ticargabon='C' and
            ca.vamont IN (400,410) and
            ca.nucargabon=ca.nucargabon+0 and
            ca.nucomp=ca.nucomp+0 and
            de.nucargabon=ca.nucargabon and
            de.nucomp=ca.nucomp and
            pm.nupagoextr=de.nupagoextr and
            pm.nucomp=de.nucomp and
            pm.stpago='P' AND
            NOT EXISTS (SELECT 'X' FROM FAM_PAGOEXOL WHERE NUPAGOEXOL=SOPQ_DESCCLIE.FN_NUMERO(cdcuenbanc)) AND
            GLOSA IN (
                            'PAGOS REALIZADOS EN EQUIPO SISCO',
                            'PAGO AL CONTADO',
                            'PAGOS REALIZADOS EN EQUIPO PRIME ANTES DE 01/11/1994',
                            'PAGO EXTRAORDINARIO POR LA FACTURACION DE CUOTAS PARCIALES DEL CERTIFICADO DE APORTACION',
                            'PAGO EXTRAORDINARIO CONTRATO DE TRANSFERENCIA DE BIENES Y ACTIVOS DEL SISTEMA ELECTRICO DE SAN IGNACIO DE VELASCO N¿ 003-E-2004',
                            'PAGO EXTRAORDINARIO POR RECONOCIMIENTO DE LOS ACTIVOS DE COMAYO SEGUN CI GGSH/19/08',
                            'RECONOCIMIENTO DE 24.14 US$ DEL CERTIFICADO DE APORTACION POR TRANSFERENCIA DE ACTIVOS DE LA COOPERATIVA 6 DE OCTUBRE',
                            'PAGO EXTRAORDINARIO POR RECONOCIMIENTO DE LOS ACTIVOS DE COSEPUR',
                            'RECONOCIMIENTO DE LOS ACTIVOS DE COSSAJA - RES.# 003-E-2005 DEL 08/06/2005',
                            'PAGO EXTRAORDINARIO CONTRATO DE TRANSFERENCIA DE BIENES Y ACTIVOS DEL SISTEMA ELECTRICO DE SAN MIGUEL DE VELASCO N¿ 006-E-2006',
                            'PAGOS A DEVOLVER',
                            'PAGO EXTRAORDINARIO POR RECONOCIMIENTO DE LOS ACTIVOS DE COSEPUSAL - SEGUN CI GIAR/42/07',
                            'PAGO POR RECONOCIMIENTO CONSEJO DE ADMINISTRACION',
                            'RECONOCIMIENTO DE 24.14 US$ DEL CERTIFICADO DE APORTACION POR TRANSFERENCIA DE ACTIVOS DE LA COOPERATIVA 12 DE OCTUBRE'
                     );

        COMMIT;
    END IF;



end;


    PROCEDURE PR_APORTACIONES (    pa_ansald number default to_char(add_months(sysdate,-1),'YYYY'),
                                   pa_mesald number default to_char(add_months(sysdate,-1),'MM')
                                   ,pa_nucomp number default null,pa_nucargabon number default null
                               ) IS
    BEGIN
        NULL;
    END;


    PROCEDURE PR_DEVOLUCIONES  (    pa_ansald number default to_char(add_months(sysdate,-1),'YYYY'),
                                    pa_mesald number default to_char(add_months(sysdate,-1),'MM')
                                    ,pa_nucomp number default null,pa_nucargabon number default null
                               ) IS
        Cursor trae_Devo is

            select
                *
            from
                fat_cargabon abo
            where
                abo.nucomp=nvl(pa_nucomp,abo.nucomp) and abo.nucargabon=nvl(pa_nucargabon,abo.nucargabon) and
                abo.cdcargabon=2 and
                abo.ticargabon='A' and
                abo.stregi='R' and
                to_char(abo.fccargo,'YYYYMM')<=pa_ansald*100+pa_mesald;

    BEGIN

        for devo in trae_devo
        loop
            update
                far_saldca
            set
                mocapisusdevo=NVL(MOCAPISUS,0) - NVL(MOINTEMIX,0) + NVL(MOPAGOEXTR,0),
                fcmodi=sysdate
            where
                ansald=pa_ansald and
                mesald=pa_mesald and
                nucargabon=devo.nucaabasoc and
                nucomp=devo.nucomp;
            commit;
        end loop;

    END;

    PROCEDURE PR_CERTIFICADOS  (    pa_ansald number default to_char(add_months(sysdate,-1),'YYYY'),
                                    pa_mesald number default to_char(add_months(sysdate,-1),'MM')
                                    ,pa_nucomp number default null,pa_nucargabon number default null
                               ) is

        cursor trae_saldca is

            select
                rowid filaid,
                nucargabon,
                nucomp,
                (select idcert from scm_cert ce     where CE.STREGI='R' AND ce.nucargabon=sa.nucargabon and ce.nucomp=sa.nucomp and rownum=1) idcert,
                (select stcert from scm_cert ce     where CE.STREGI='R' AND ce.nucargabon=sa.nucargabon and ce.nucomp=sa.nucomp and rownum=1) stcert,
                (select NUCLIE from fat_Cargabon ca where ca.nucargabon=sa.nucargabon and ca.nucomp=sa.nucomp) nuclie,
                (select nusoci     from scm_soci so,fat_Cargabon ca where ca.nucargabon=sa.nucargabon and ca.nucomp=sa.nucomp and so.nuclie=ca.nuclie) nusoci,
                (select nuservalta from scm_soci so,fat_Cargabon ca where ca.nucargabon=sa.nucargabon and ca.nucomp=sa.nucomp and so.nuclie=ca.nuclie) nuservalta
            from
                far_saldca SA
            where
                sa.nucomp=nvl(pa_nucomp,sa.nucomp) and sa.nucargabon=nvl(pa_nucargabon,sa.nucargabon) and
                ansald=pa_ansald and
                mesald=pa_mesald;

    begin

        for saldo in trae_saldca
        loop
            update
                far_saldca SA
            set
                IDCERT = SALDO.IDCERT,
                STCERT = SALDO.STCERT,
                NUCLIE = SALDO.NUCLIE,
                NUSOCI = SALDO.NUSOCI,
                NOCLIE = translate(substr(trim(sopq_datoclie.Fn_TraeNombreCliente(SALDO.nuclie)),1,100),chr(9)||chr(10)||chr(13),'   '),
                NUSERVALTA = SALDO.NUSERVALTA,
                fcmodi=sysdate
            where
                ROWID=SALDO.FILAID;

            commit;

        end loop;

    end;


    PROCEDURE PR_SALDOPOSTERIOR    (    pa_ansald number default to_char(add_months(sysdate,-1),'YYYY'),
                                        pa_mesald number default to_char(add_months(sysdate,-1),'MM')
                                        ,pa_nucomp number default null,pa_nucargabon number default null
                                   ) IS
        --DEMORA 3 MINUTOS

            va_fcpago date := to_date(pa_ansald*100+pa_mesald,'YYYYMM');
            va_fcpagoMesSig date := add_months(va_fcpago,1);

        cursor trae_fact is
            select
                pag.nucargabon,
                pag.nucomp,
                pag.anpago,
                pag.mepago,
                pag.vamontcapi,
                round(pag.vamontcapi*vatipocamb,1) vamontcapibs
            from
                fat_cargabon car,
                fae_cargabon pag,
                fat_prefact pre
            where
                car.nucomp=nvl(pa_nucomp,car.nucomp) and car.nucargabon=nvl(pa_nucargabon,car.nucargabon) and
                pre.fcemis >= va_fcpagoMesSig and
                pre.nuprefact=pre.nuprefact+0 and
                pre.stfact='C' AND
                pag.nuprefact = pre.nuprefact AND
                pag.nucomp = pre.nucomp AND
                car.nucargabon=pag.nucargabon and
                car.nucomp=pag.nucomp and
                car.cdcargabon in (1,2);

        cursor trae_anul is
            select
                car.nucomp,
                car.nucargabon,
                doc.andocu,
                doc.medocu,
                car.mocapisus,
                car.mocapibs
            from
                dce_cargabon car,
                dct_docu doc,
                ajt_docuajus dcj,
                ajt_ajus ajt
            where
                car.nucomp=nvl(pa_nucomp,car.nucomp) and car.nucargabon=nvl(pa_nucargabon,car.nucargabon) and
                ajt.fcprod>=va_fcpagoMesSig
                and ajt.stregi = 'R'
                and ajt.stajus in ('E','D')
                and ajt.tiajus in ('M','X','xP')  --SE QUITO EL ESTADO P
                and dcj.nuajus = ajt.nuajus
                and dcj.nucomp = ajt.nucomp
                and doc.nucomp = dcj.nucomp
                and doc.nudocu = dcj.nudocuorig
                and car.nudocu = doc.nudocu
                and car.nucomp = doc.nucomp
                and car.nuconccapi in (2);

        cursor trae_emit is
            select
                car.nucomp,
                car.nucargabon,
                dnu.andocu,
                dnu.medocu,
                mocapisus,
                mocapibs
            from
                dce_cargabon car,
                dct_docu dor,
                dct_docu dnu,
                ajt_docuajus d,
                ajt_ajus ajt
            where
                car.nucomp=nvl(pa_nucomp,car.nucomp) and car.nucargabon=nvl(pa_nucargabon,car.nucargabon) and
                ajt.fcprod >= va_fcpagoMesSig
                and ajt.tiajus='M'
                and ajt.stregi='R'
                and ajt.stajus in ('E','D')
                and d.nucomp=ajt.nucomp
                and d.nuajus=ajt.nuajus
                and dnu.nucomp=d.nucomp
                and dnu.nudocu=d.nudocunuev
                and dor.nucomp=d.nucomp
                and dor.nudocu=d.nudocuorig
                and car.nudocu = dnu.nudocu
                and car.nucomp = dnu.nucomp
                and car.nuconccapi in (2);

        cursor trae_pextr is
            select
                m.nupagoextr,cdcuenbanc,d.nucomp,d.nucargabon,fcpago,m.nucuen,stpago,m.nuserv,mopago,glosa
            from
                fat_cargabon c,
                fam_pagoextr m,
                fad_pagoextr d
            where
                d.nucomp=nvl(pa_nucomp,d.nucomp) and d.nucargabon=nvl(pa_nucargabon,d.nucargabon) and
                --d.nucargabon=1680625 and d.nucomp=1 and
                m.nupagoextr=d.nupagoextr and
                m.fcpago >= va_fcpagoMesSig and
                m.stpago = 'P' and
                c.nucargabon=d.nucargabon and
                c.nucomp=d.nucomp and
                c.cdcargabon in (1,2);

        begin
            --FACTURADA
            for ca in trae_fact
            loop
                update
                    far_saldca
                set
                    VAMONTFACT = VAMONTFACT - ca.vamontcapi,
                    MOCAPISUS  = MOCAPISUS  - ca.vamontcapi,
                    MOCAPIBS  = MOCAPIBS  - ca.vamontcapibs,
                    FCMODI=sysdate
                where
                    ANSALD=PA_ANSALD AND
                    MESALD=PA_MESALD AND
                    nucargabon=ca.nucargabon and
                    nucomp=ca.nucomp;
                commit;
            end loop;

            --ANULADA
            for ca in trae_anul
            loop
                update
                    far_saldca
                set
                    VAMONTFACT = VAMONTFACT + ca.mocapisus,
                    MOCAPISUS  = MOCAPISUS  + ca.mocapisus,
                    MOCAPIBS  = MOCAPIBS  - ca.mocapibs,
                    fcmodi=sysdate
                where
                    ANSALD=PA_ANSALD AND
                    MESALD=PA_MESALD AND
                    nucargabon=ca.nucargabon and
                    nucomp=ca.nucomp;
                commit;
            end loop;

            --EMITIDA
            for ca in trae_emit
            loop
                update
                    far_saldca
                set
                    VAMONTFACT = VAMONTFACT - ca.mocapisus,
                    MOCAPISUS  = MOCAPISUS  - ca.mocapisus,
                    MOCAPIBS   = MOCAPIBS  - ca.mocapibs,
                    fcmodi=sysdate
                where
                    ANSALD=PA_ANSALD AND
                    MESALD=PA_MESALD AND
                    nucargabon=ca.nucargabon and
                    nucomp=ca.nucomp;
                commit;
            end loop;

            /*
            --PAGOS EXTRAORDINARIOS
            for ca in trae_pextr
            loop
                update
                    far_saldca
                set
                    VAMONTFACT = VAMONTFACT - ca.mopago,
                    MOCAPISUS  = MOCAPISUS  - ca.mopago,
                    fcmodi=sysdate
                where
                    ANSALD=PA_ANSALD AND
                    MESALD=PA_MESALD AND
                    nucargabon=ca.nucargabon and
                    nucomp=ca.nucomp;
                commit;
            end loop;
            */

        end;


    PROCEDURE PR_FACTMES        (    pa_ansald number default to_char(add_months(sysdate,-1),'YYYY'),
                                        pa_mesald number default to_char(add_months(sysdate,-1),'MM')
                                        ,pa_nucomp number default null,pa_nucargabon number default null
                               ) IS

    --DEMORA 1 MINUTO

    Cursor trae_fact is

    SELECT
        TO_CHAR(pre.fcemis,'YYYY') ANFACT,
        TO_CHAR(pre.fcemis,'MM') MEFACT,
        PRE.NUCOMP,
        CAR.NUCARGABON,
        CAR.MOCAPISUS VAMONTCAPI,
        CAR.MOCAPIBS  VAMONTCAPIBS,
        'FACTURADO' TIOPER
    from
        dce_cargabon car,
--        fat_cargabon car,
--        fae_cargabon pag,
        fat_prefact pre
    where
        car.nucomp=nvl(pa_nucomp,car.nucomp) and car.nucargabon=nvl(pa_nucargabon,car.nucargabon) and
        pre.fcemis >= TO_DATE(PA_ANSALD*100+PA_MESALD,'YYYYMM') and
        pre.fcemis <  ADD_MONTHS(TO_DATE(PA_ANSALD*100+PA_MESALD,'YYYYMM'),1) and
        pre.nuprefact=pre.nuprefact+0 and
        pre.stfact='C' AND
        pre.nudocu = pre.nudocu + 0 AND
        car.nudocu = pre.nudocu and
        car.nucomp = pre.nucomp and
        car.nuconccapi in (1,2);

        --pag.nuprefact = pre.nuprefact AND
        --pag.nucomp = pre.nucomp AND
        --car.nucargabon=pag.nucargabon and
        --car.nucomp=pag.nucomp and
        --car.cdcargabon=2;

    Cursor trae_Anul is
        select
            TO_CHAR(ajt.fcprod,'YYYY') ANFACT,
            TO_CHAR(ajt.fcprod,'MM') MEFACT,
            CAR.NUCOMP,
            CAR.NUCARGABON,
            CAR.MOCAPISUS VAMONTCAPI,
            CAR.MOCAPIBS  VAMONTCAPIBS,
            'ANULADO' TIOPER
        from
            dce_cargabon car,
            dct_docu doc,
            ajt_docuajus dcj,
            ajt_ajus ajt
        where
            car.nucomp=nvl(pa_nucomp,car.nucomp) and car.nucargabon=nvl(pa_nucargabon,car.nucargabon) and
            ajt.fcprod >= TO_DATE(pa_ansald*100+pa_mesald,'YYYYMM') and
            ajt.fcprod <  ADD_MONTHS(TO_DATE(pa_ansald*100+pa_mesald,'YYYYMM'),1)
            and ajt.stregi = 'R'
            and ajt.stajus in ('E','D')
            and ajt.tiajus in ('M','X','xP')  --SE QUITO EL ESTADO P
            and dcj.nuajus = ajt.nuajus
            and dcj.nucomp = ajt.nucomp
            and doc.nucomp = dcj.nucomp
            and doc.nudocu = dcj.nudocuorig
            and car.nudocu = doc.nudocu
            and car.nucomp = doc.nucomp
            and car.nuconccapi in (2)
            and not exists (select 'x' from dct_movidocu movi where movi.nudocu=doc.nudocu and movi.nucomp=doc.nucomp and movi.timovi='CA');

    Cursor trae_AnulCast is
        select
            TO_CHAR(ajt.fcprod,'YYYY') ANFACT,
            TO_CHAR(ajt.fcprod,'MM') MEFACT,
            CAR.NUCOMP,
            CAR.NUCARGABON,
            CAR.MOCAPISUS VAMONTCAPI,
            CAR.MOCAPIBS  VAMONTCAPIBS,
            'CASTIGADO' TIOPER
        from
            dce_cargabon car,
            dct_docu doc,
            ajt_docuajus dcj,
            ajt_ajus ajt
        where
            car.nucomp=nvl(pa_nucomp,car.nucomp) and car.nucargabon=nvl(pa_nucargabon,car.nucargabon) and
            ajt.fcprod >= TO_DATE(pa_ansald*100+pa_mesald,'YYYYMM') and
            ajt.fcprod <  ADD_MONTHS(TO_DATE(pa_ansald*100+pa_mesald,'YYYYMM'),1)
            and ajt.stregi = 'R'
            and ajt.stajus in ('E','D')
            and ajt.tiajus in ('M','X','xP')  --SE QUITO EL ESTADO P
            and dcj.nuajus = ajt.nuajus
            and dcj.nucomp = ajt.nucomp
            and doc.nucomp = dcj.nucomp
            and doc.nudocu = dcj.nudocuorig
            and car.nudocu = doc.nudocu
            and car.nucomp = doc.nucomp
            and car.nuconccapi in (2)
            and exists (select 'x' from dct_movidocu movi where movi.nudocu=doc.nudocu and movi.nucomp=doc.nucomp and movi.timovi='CA');


    Cursor trae_Emit is
    select
        TO_CHAR(ajt.fcprod,'YYYY') ANFACT,
        TO_CHAR(ajt.fcprod,'MM') MEFACT,
        CAR.NUCOMP,
        CAR.NUCARGABON,
        CAR.mocapisus VAMONTCAPI,
        CAR.MOCAPIBS  VAMONTCAPIBS,
        'EMITIDO' TIOPER
    from
        dce_cargabon car,
        dct_docu dor,
        dct_docu dnu,
        ajt_docuajus d,
        ajt_ajus ajt
    where
        car.nucomp=nvl(pa_nucomp,car.nucomp) and car.nucargabon=nvl(pa_nucargabon,car.nucargabon) and
        ajt.fcprod >= TO_DATE(pa_ansald*100+pa_mesald,'YYYYMM') and
        ajt.fcprod <  ADD_MONTHS(TO_DATE(pa_ansald*100+pa_mesald,'YYYYMM'),1)
        and ajt.tiajus='M'
        --and ajt.stregi='R'
        and ajt.stajus in ('E','D')
        and d.nucomp=ajt.nucomp
        and d.nuajus=ajt.nuajus
        and dnu.nucomp=d.nucomp
        and dnu.nudocu=d.nudocunuev
        and dor.nucomp=d.nucomp
        and dor.nudocu=d.nudocuorig
        and car.nudocu = dnu.nudocu
        and car.nucomp = dnu.nucomp
        and car.nuconccapi in (2);

    Cursor trae_PExtr is
        select
            TO_CHAR(MA.FCPAGO,'YYYY') ANFACT,
            TO_CHAR(MA.FCPAGO,'MM') MEFACT,
            CA.NUCOMP,
            CA.NUCARGABON,
            DE.MOPAGO VAMONTCAPI,
            ROUND(DE.MOPAGO*DE.TIPOCAMB,1) VAMONTCAPIBS,
            'PAGO EXTR' TIOPER
        FROM
            FAT_CARGABON CA,
            FAD_PAGOEXTR DE,
            FAM_PAGOEXTR MA
        WHERE
            ca.nucomp=nvl(pa_nucomp,ca.nucomp) and ca.nucargabon=nvl(pa_nucargabon,ca.nucargabon) and
            MA.FCPAGO >= TO_DATE(pa_ansald*100+pa_mesald,'YYYYMM') and
            MA.FCPAGO <  ADD_MONTHS(TO_DATE(pa_ansald*100+pa_mesald,'YYYYMM'),1) and
            MA.STPAGO='P' AND
            DE.NUPAGOEXTR=MA.NUPAGOEXTR AND
            CA.NUCARGABON=DE.NUCARGABON AND
            CA.NUCOMP=DE.NUCOMP AND
            CA.CDCARGABON=2 AND
            CA.TICARGABON='C';

    --INGRESOS POR COBRANZA DE FACTURAS CASTIGADAS
    Cursor trae_CobrCast is
            select
                coli.nucomp,
                carg.nucargabon,
                to_char(coli.fccobr,'YYYY') ansald,
                to_char(coli.fccobr,'MM') mesald,
                mocapisus VAMONTCAPI,
                mocapibs  VAMONTCAPIBS
            FROM
                dce_cargabon carg,
                cbh_cargcoli coli
            WHERE
                carg.nucomp=nvl(pa_nucomp,carg.nucomp) and carg.nucargabon=nvl(pa_nucargabon,carg.nucargabon) and
                coli.fccobr >= TO_DATE(pa_ansald*100+pa_mesald,'YYYYMM') and
                coli.fccobr <  ADD_MONTHS(TO_DATE(pa_ansald*100+pa_mesald,'YYYYMM'),1) and
                coli.cdtipo='C' and
                coli.nucomp=coli.nucomp+0 and
                coli.nudocu=coli.nudocu+0 and
                carg.nucomp=coli.nucomp and
                carg.nudocu=coli.nudocu and
                carg.nuconccapi in (1,2) and
                exists (select 'x' from dct_movidocu movi where movi.nudocu=coli.nudocu and movi.nucomp=coli.nucomp and movi.timovi='CA');

        Cursor trae_Devo is
            select
                TO_CHAR(CA.FCCARGO,'YYYY') ANFACT,
                TO_CHAR(CA.FCCARGO,'MM') MEFACT,
                CA.NUCOMP,
                CA.NUCAABASOC NUCARGABON,
                VAMONT VAMONTCAPI,
                ROUND(VAMONT*MGFN_CAMBDIAR,1) VAMONTCAPIBS,
                'DEVOLUCION' TIOPER
            FROM
                FAT_CARGABON CA
            WHERE
                ca.nucomp=nvl(pa_nucomp,ca.nucomp) and ca.nucargabon=nvl(pa_nucargabon,ca.nucargabon) and
                CDCARGABON=2 AND
                TICARGABON='A' AND
                FCCARGO >= TO_DATE(pa_ansald*100+pa_mesald,'YYYYMM') and
                FCCARGO <  ADD_MONTHS(TO_DATE(pa_ansald*100+pa_mesald,'YYYYMM'),1) and
                STREGI='R';

    CURSOR TRAE_DEVOFIX IS

        SELECT
            R2.*
        FROM
        (
            select
                r1.*,
                SALDO_MEANTE+TOTALMES-saldo DIFE,
                (CASE
                    WHEN STCERT IN ('EMI','PEN') AND STCERT_MEANTE='DEV' THEN 'CASO 1: DEVOLUCION REVERTIDA'
                    WHEN STCERT='DEV' AND NVL(VADEVOMESSUS,0)>0 AND STCERT_MEANTE='DEV' THEN 'CASO 2: DEVOLUCION REPETIDA'
                    WHEN STCERT='DEV' AND NVL(VADEVOMESSUS,0)=0 AND STCERT_MEANTE IN ('PEN','EMI') THEN 'CASO 3: DEVOLUCION INCORRECTA'
                    --WHEN TOTALMES=DIFE THEN 'CASO 4: CUOTA NO REGISTRADA'
                END) OBSE,
                (CASE
                    WHEN STCERT='DEV' OR STCERT_MEANTE='DEV' THEN 'DEVOLUCIONES'
                END) PROBLEMA
            from
            (
                select
                    nucomp,
                    nucuen,
                    nucargabon,
                    NUCLIE,
                    ANSALD,
                    MESALD,
                    vamont,
                    stcert,
                    stregi,
                    mocapisus facturado,
                    mopagoextr pagos_extr,
                    mocapisusdevo devolucion,
                    VADEVOMESSUS,
                    (NVL(MOCAPISUS,0)+NVL(MOPAGOEXTR,0)-NVL(MOCAPISUSDEVO,0)) SALDO,
                    (MOFACTMES) TOTALMES,
                    (select
                        STCERT
                        from far_saldca s2
                        where
                            s2.nucomp=ca.nucomp and s2.nucargabon=ca.nucargabon
                            and ansald=to_char(add_months(to_date(ca.ansald*100+ca.mesald,'YYYYMM'),-1),'YYYY')
                            and mesald=to_char(add_months(to_date(ca.ansald*100+ca.mesald,'YYYYMM'),-1),'MM')
                    ) STCERT_MEANTE,
                    (select
                        NVL(s2.MOCAPISUSDEVO,0) DEVO
                        from far_saldca s2
                        where
                            s2.nucomp=ca.nucomp and s2.nucargabon=ca.nucargabon
                            and ansald=to_char(add_months(to_date(ca.ansald*100+ca.mesald,'YYYYMM'),-1),'YYYY')
                            and mesald=to_char(add_months(to_date(ca.ansald*100+ca.mesald,'YYYYMM'),-1),'MM')
                    ) DEVO_MEANTE,
                    (select
                        (NVL(s2.MOCAPISUS,0)+NVL(s2.MOPAGOEXTR,0)-NVL(s2.MOCAPISUSDEVO,0))
                        from far_saldca s2
                        where
                            s2.nucomp=ca.nucomp and s2.nucargabon=ca.nucargabon
                            and ansald=to_char(add_months(to_date(ca.ansald*100+ca.mesald,'YYYYMM'),-1),'YYYY')
                            and mesald=to_char(add_months(to_date(ca.ansald*100+ca.mesald,'YYYYMM'),-1),'MM')
                    ) SALDO_MEANTE,
                    DTOBSFIX
                from
                    far_saldca ca
                where
                    ca.nucomp=nvl(pa_nucomp,ca.nucomp) and ca.nucargabon=nvl(pa_nucargabon,ca.nucargabon) and
                    ansald = pa_ansald and mesald=pa_mesald and
                    stregi='R'
            ) r1
            ) R2
            where
                SALDO_MEANTE+TOTALMES-saldo<>0
            ORDER BY
                NUCOMP,
                NUCUEN,
                NUCARGABON;


    BEGIN

        UPDATE
            FAR_SALDCA car
        SET
            MOFACTMES=0,
            VAFACTSUS        = NULL,
            VAFACTBS         = NULL,
            VAANULNOCASTSUS  = NULL,
            VAANULNOCASTBS   = NULL,
            VAANULCASTSUS    = NULL,
            VAANULCASTBS     = NULL,
            VAEMITSUS        = NULL,
            VAEMITBS         = NULL,
            VAPAEXSUS        = NULL,
            VAPAEXBS         = NULL,
            VADEVOMESSUS     = NULL,
            VADEVOMESBS      = NULL,
            VACOBRCASTSUS    = NULL,
            VACOBRCASTBS     = NULL,
            DTOBSFIX         = NULL,
            VADEVOMESPRSUS   = NULL,
            VADEVOACCPRSUS   = NULL,
            FCMODI           = SYSDATE
        WHERE
            car.nucomp=nvl(pa_nucomp,car.nucomp) and car.nucargabon=nvl(pa_nucargabon,car.nucargabon) and
            ANSALD=pa_ansald AND
            MESALD=pa_mesald;

        COMMIT;

        --FACTURADA
        for carg in trae_fact
        loop
            UPDATE
                FAR_SALDCA
            SET
                MOFACTMES=NVL(MOFACTMES,0) + NVL(CARG.VAMONTCAPI,0),
                VAFACTSUS=CARG.VAMONTCAPI,
                VAFACTBS=CARG.VAMONTCAPIBS
            WHERE
                NUCARGABON=CARG.NUCARGABON AND
                NUCOMP=CARG.NUCOMP AND
                ANSALD=PA_ANSALD AND
                MESALD=PA_MESALD;

                if SQL%NOTFOUND then
                    insert into
                        FAR_SALDCA ta
                        (ANSALD,MESALD,NUCOMP,NUCARGABON,STREGI,MOFACTMES,VAFACTSUS,VAFACTBS,FCREGI)
                    values
                        (PA_ANSALD,PA_MESALD,CARG.NUCOMP,CARG.NUCARGABON,'R',CARG.VAMONTCAPI,CARG.VAMONTCAPI,CARG.VAMONTCAPIBS,sysdate);
                end if;
            COMMIT;
        end loop;


        --ANULADO NO CASTIGADO
        for carg in trae_Anul
        loop
            UPDATE
                FAR_SALDCA
            SET
                MOFACTMES        = NVL(MOFACTMES,0) - NVL(CARG.VAMONTCAPI,0),
                VAANULNOCASTSUS  = NVL(VAANULNOCASTSUS,0) + NVL(CARG.VAMONTCAPI  ,0)  ,
                VAANULNOCASTBS   = NVL(VAANULNOCASTBS ,0) + NVL(CARG.VAMONTCAPIBS,0)
            WHERE
                NUCARGABON=CARG.NUCARGABON AND
                NUCOMP=CARG.NUCOMP AND
                ANSALD=PA_ANSALD AND
                MESALD=PA_MESALD;

                if SQL%NOTFOUND then
                    insert into
                        FAR_SALDCA ta
                        (ANSALD,MESALD,NUCOMP,NUCARGABON,STREGI,MOFACTMES,
                        VAANULNOCASTSUS,VAANULNOCASTBS,
                        FCREGI)
                    values
                        (PA_ANSALD,PA_MESALD,CARG.NUCOMP,CARG.NUCARGABON,'R',-CARG.VAMONTCAPI,
                        CARG.VAMONTCAPI,
                        CARG.VAMONTCAPIBS,
                        sysdate);
                end if;
            COMMIT;
        end loop;

        --ANULADO CASTIGADO
        for carg in trae_AnulCast
        loop
            UPDATE
                FAR_SALDCA
            SET
                MOFACTMES        = NVL(MOFACTMES,0) - NVL(CARG.VAMONTCAPI,0),
                VAANULCASTSUS    = NVL(VAANULCASTSUS  ,0) + NVL(CARG.VAMONTCAPI  ,0),
                VAANULCASTBS     = NVL(VAANULCASTBS   ,0) + NVL(CARG.VAMONTCAPIBS,0)
            WHERE
                NUCARGABON=CARG.NUCARGABON AND
                NUCOMP=CARG.NUCOMP AND
                ANSALD=PA_ANSALD AND
                MESALD=PA_MESALD;

                if SQL%NOTFOUND then
                    insert into
                        FAR_SALDCA ta
                        (ANSALD,MESALD,NUCOMP,NUCARGABON,STREGI,MOFACTMES,
                        VAANULCASTSUS,VAANULCASTBS,
                        FCREGI)
                    values
                        (PA_ANSALD,PA_MESALD,CARG.NUCOMP,CARG.NUCARGABON,'R',-CARG.VAMONTCAPI,
                        CARG.VAMONTCAPI,
                        CARG.VAMONTCAPIBS,
                        sysdate);
                end if;
            COMMIT;
        end loop;

        --EMITIDA
        for carg in trae_Emit
        loop
            UPDATE
                FAR_SALDCA
            SET
                MOFACTMES = NVL(MOFACTMES,0) + NVL(CARG.VAMONTCAPI,0),
                VAEMITSUS = NVL(VAEMITSUS,0) + NVL(CARG.VAMONTCAPI,0),
                VAEMITBS  = NVL(VAEMITBS,0)  + NVL(CARG.VAMONTCAPIBS,0)
            WHERE
                NUCARGABON=CARG.NUCARGABON AND
                NUCOMP=CARG.NUCOMP AND
                ANSALD=PA_ANSALD AND
                MESALD=PA_MESALD;

                if SQL%NOTFOUND then
                    insert into
                        FAR_SALDCA ta
                        (ANSALD,MESALD,NUCOMP,NUCARGABON,STREGI,MOFACTMES,VAEMITSUS,VAEMITBS,FCREGI)
                    values
                        (PA_ANSALD,PA_MESALD,CARG.NUCOMP,CARG.NUCARGABON,'R',CARG.VAMONTCAPI,CARG.VAMONTCAPI,CARG.VAMONTCAPIBS,sysdate);
                end if;
            COMMIT;
        end loop;


        --PAGOS EXTRAORDINARIOS
        for carg in trae_PExtr
        loop
            UPDATE
                FAR_SALDCA
            SET
                MOFACTMES=NVL(MOFACTMES,0) + NVL(CARG.VAMONTCAPI,0),
                VAPAEXSUS = NVL(VAPAEXSUS,0) + CARG.VAMONTCAPI,
                VAPAEXBS  = NVL(VAPAEXBS ,0) + CARG.VAMONTCAPIBS
            WHERE
                NUCARGABON=CARG.NUCARGABON AND
                NUCOMP=CARG.NUCOMP AND
                ANSALD=PA_ANSALD AND
                MESALD=PA_MESALD;

                if SQL%NOTFOUND then
                    insert into
                        FAR_SALDCA ta
                        (ANSALD,MESALD,NUCOMP,NUCARGABON,STREGI,MOFACTMES,VAPAEXSUS,VAPAEXBS,FCREGI)
                    values
                        (PA_ANSALD,PA_MESALD,CARG.NUCOMP,CARG.NUCARGABON,'R',CARG.VAMONTCAPI,CARG.VAMONTCAPI,CARG.VAMONTCAPIBS,sysdate);
                end if;
            COMMIT;
        end loop;

        --INGRESOS COBRANZAS DE FACTURAS CASTIGADAS
        for carg in trae_CobrCast
        loop
            UPDATE
                FAR_SALDCA
            SET
                VACOBRCASTSUS = NVL(VACOBRCASTSUS,0) + CARG.VAMONTCAPI,
                VACOBRCASTBS  = NVL(VACOBRCASTBS ,0) + CARG.VAMONTCAPIBS
            WHERE
                NUCARGABON=CARG.NUCARGABON AND
                NUCOMP=CARG.NUCOMP AND
                ANSALD=PA_ANSALD AND
                MESALD=PA_MESALD;

                if SQL%NOTFOUND then
                    insert into
                        FAR_SALDCA ta
                        (ANSALD,MESALD,NUCOMP,NUCARGABON,STREGI,VACOBRCASTSUS,VACOBRCASTBS,FCREGI)
                    values
                        (PA_ANSALD,PA_MESALD,CARG.NUCOMP,CARG.NUCARGABON,'R',CARG.VAMONTCAPI,CARG.VAMONTCAPIBS,sysdate);
                end if;
            COMMIT;
        end loop;



        --DEVOLUCIONES
        for carg in trae_devo
        loop
            UPDATE
                FAR_SALDCA
            SET
                MOFACTMES=NVL(MOFACTMES,0) - NVL(CARG.VAMONTCAPI,0),
                VADEVOMESSUS = NVL(VADEVOMESSUS,0) + CARG.VAMONTCAPI,
                VADEVOMESBS  = NVL(VADEVOMESBS ,0) + CARG.VAMONTCAPIBS
            WHERE
                NUCARGABON=CARG.NUCARGABON AND
                NUCOMP=CARG.NUCOMP AND
                ANSALD=PA_ANSALD AND
                MESALD=PA_MESALD;

                if SQL%NOTFOUND then
                    insert into
                        FAR_SALDCA ta
                        (ANSALD,MESALD,NUCOMP,NUCARGABON,STREGI,MOFACTMES,VADEVOMESSUS,VADEVOMESBS,FCREGI)
                    values
                        (PA_ANSALD,PA_MESALD,CARG.NUCOMP,CARG.NUCARGABON,'R',-CARG.VAMONTCAPI,CARG.VAMONTCAPI,CARG.VAMONTCAPIBS,sysdate);
                end if;
            COMMIT;
        end loop;

        --DEVOLUCIONES FIX
        --DEVOLUCIONES
            for carg in trae_devofix
            loop

                if carg.problema='DEVOLUCIONES' then
                    UPDATE
                        FAR_SALDCA
                    SET
                        MOFACTMES=NVL(MOFACTMES,0) - NVL(CARG.DIFE,0),
                        VADEVOMESSUS = NVL(VADEVOMESSUS,0) + CARG.DIFE,
                        VADEVOMESBS  = NVL(VADEVOMESBS ,0) + round(CARG.DIFE*mgfn_tipocamb(to_date(ansald*100+mesald,'YYYYMM')),1),
                        DTOBSFIX     = CARG.OBSE
                    WHERE
                        NUCARGABON=CARG.NUCARGABON AND
                        NUCOMP=CARG.NUCOMP AND
                        ANSALD=CARG.ANSALD AND
                        MESALD=CARG.MESALD;

                    COMMIT;
                end if;
            end loop;

        --DEVOLUCIONES PROCESADAS (PAGADAS)
        DECLARE
            Cursor trae_devoproc is
                select
                    nucargabon,
                    (select nucaabasoc from fat_Cargabon ca where ca.nucargabon=abo.nucargabon and ca.nucomp=abo.nucomp) nucaabasoc,
                    nucomp,
                    nucuen,
                    mopago,
                    (case when to_char(fcpago,'YYYYMM')=PA_ANSALD*100+PA_MESALD THEN MOPAGO ELSE NULL END) mopagomes,
                    stpago,
                    fcpago fcpago
                from
                    faw_pagoexol abo
                where
                    abo.cdcargabon=2 and
                    abo.ticargabon='A' and
                    abo.stregi='R' and
                    fcpago is not null;
        BEGIN
            FOR carg in trae_devoproc
            loop
                    UPDATE
                        FAR_SALDCA
                    SET
                        VADEVOMESPRSUS=nvl(VADEVOMESPRSUS,0) + nvl(carg.mopagoMes,0),
                        VADEVOACCPRSUS=nvl(VADEVOACCPRSUS,0) + nvl(carg.mopago,0)
                    WHERE
                        NUCARGABON=CARG.nucaabasoc AND
                        NUCOMP=CARG.NUCOMP AND
                        ANSALD=PA_ANSALD and
                        MESALD=PA_MESALD;
            end loop;
            commit;
        END;



    END;


    PROCEDURE PR_FIXTIPOCAMB (PA_CDCARGABON NUMBER DEFAULT 2) IS
        --DEMORA 5 HORAS
        cursor trae_cargo is

            select * from
            (
            SELECT
                y.rowid filaid,
                y.nucargabon,
                y.nucomp,
                x.nudocu,
                x.andocu,
                x.medocu,
                Y.mocapisus mocapisus,
                fapq_CertApor.FN_CAPITALREAL(
                                                  X.NUCOMP,
                                                  X.nucuen,
                                                  Y.NUVERSCAPI,
                                                  X.andocu,
                                                  X.medocu,
                                                  Y.mocapibs,
                                                  Y.mointebs,
                                                  Y.mocapisus
                                            ) mocapisusajus,
                Y.mointesus mointesus,
                fapq_CertApor.FN_INTERESREAL(
                                                  X.NUCOMP,
                                                  X.nucuen,
                                                  Y.NUVERSCAPI,
                                                  X.andocu,
                                                  X.medocu,
                                                  Y.mocapibs,
                                                  Y.mointebs,
                                                  Y.mointesus
                                            ) mointesusajus
            FROM
                dct_docu x,
                dce_cargabon y
            WHERE
                --Y.NUCARGABON=13904 AND
                y.nudocu=y.nudocu+0
                and y.nuconccapi=PA_CDCARGABON
                and x.nucomp=y.nucomp
                and x.nudocu=y.nudocu
                AND x.stfact IN ('N','F')
        ) re
        where
            abs(nvl(mocapisus,0)-nvl(mocapisusajus,0))>0.01 or
            abs(nvl(mointesus,0)-nvl(mointesusajus,0))>0.01;

    BEGIN
        --INICIANDO EL CONTADOR
            UPDATE
                MGM_PARA
            SET
                VAPARA=0,
                DSPARA='CONTADOR INICIADO EN FECHA '||TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS')
            WHERE
                CDMODU='FA' AND
                CDPARA='CTREG';
            COMMIT;

        --REALIZANDO EL AJUSTE
            for cargo in trae_cargo
            loop
                update
                    dce_cargabon
                set
                    mocapisus=cargo.mocapisusajus,
                    mointesus=cargo.mointesusajus
                where
                    rowid=cargo.filaid;
                UPDATE MGM_PARA SET VAPARA=VAPARA+1 WHERE CDMODU='FA' AND CDPARA='CTREG';
               commit;
            end loop;
            UPDATE
                MGM_PARA
            SET
                DSPARA=DSPARA||' Y FINALIZADO EN '||TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS')
            WHERE
                CDMODU='FA' AND
                CDPARA='CTREG';
            COMMIT;
    END;


    PROCEDURE PR_JOBHORA IS
    BEGIN
        IF TO_CHAR(SYSDATE,'HH24') IN (6,13,20,23) THEN
            PR_FIXCERTIFICADOS;
        END IF;
    END;


    PROCEDURE PR_JOBS02AM IS
        va_cdSema        varchar2(100) := 'FACUCA';
        va_dsSema        varchar2(100) := 'CUADRAR CERTIFICADOS DE APORTACION';
        va_idSema       number;
        va_Resumen cbpq_coblinweb_ResuProc.re_Resumen;
        va_isOk            varchar2(1);
        va_dsmens        varchar2(100);
        va_cant         number;
    BEGIN

        --OBTENER EL ID DEL SEMAFORO
            va_idSema := cbpq_coblinweb_RESUPROC.FN_GETIDSEMAFORO  (va_cdsema);
            if va_idSema is null then
                cbpq_coblinweb_RESUPROC.PR_CREARSEMAFORO (  va_cdsema,
                                                            va_dssema,          --Nombre del Sem¿foro
                                                            1440,              --Frecuencia de Inspeccion en Minutos
                                                            substr(va_cdsema,1,2),               --M¿dulo
                                                            va_idSema,          --Id del Semaforo
                                                            va_isOk,
                                                            va_dsMens
                                                         );
                if va_isOk='N' then
                    return;
                end if;
            end if;

       --VERIFICACION DEL SEMAFORO DE ELIMINACION
            if cbpq_coblinweb_resuproc.FN_ESTASEMAFOROENROJO (va_cdsema) = 'S' then
                va_dsMens := 'Este proceso est¿ siendo ejecutado en otra sesi¿n.  Favor esperar que termine';
                return;
            end if;

        --PONE EL SEMAFORO EN ROJO POR 600 MINUTOS Y LO INICIA
            cbpq_coblinweb_resuproc.PR_SETSEMAFOROENROJO (va_cdSema,600,va_dsSema);
            cbpq_coblinweb_ResuProc.pr_Inic(va_Resumen,va_dsSema,va_idSema,0);

        --PROCESOS

            cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(01) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
            PR_CUADRARCERTAPOR(2,'C');  --Cargos
            cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(02) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
            PR_CUADRARCERTAPOR(2,'A');  --Abonos

            cbpq_coblinweb_ResuProc.pr_Revi(va_Resumen);
            cbpq_coblinweb_ResuProc.pr_Proc(va_Resumen);


        --GENERACI¿N DEL N¿MERO DE CERTIFICADO
            cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(03) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
            PR_FIXNUSECUCERT;
            cbpq_coblinweb_ResuProc.pr_Revi(va_Resumen);
            cbpq_coblinweb_ResuProc.pr_Proc(va_Resumen);


        --PAGOS EXTRAORDINARIOS IMPAGOS EMITIDOS EL MES ANTERIOR
		--SE EXTIENDE PARA TODOS LOS PAGOS EXTRAORDINARIOS SIN BPCF

            UPDATE
                FAM_PAGOEXOL
            SET
                FCEMIS=TRUNC(SYSDATE,'MM')
            WHERE
                (NUPAGOEXOL) IN
                (select NUPAGOEXOL
                from faw_pagoexol
            where
				IMBPCF=0 AND
				FCVENC<'31/12/2050' AND
                --cdcargabon=2 and
				ticargabon='C' AND
                STPAGO IN ('E','P') AND
                FCPAGO IS NULL AND
                TRUNC(FCEMIS,'MM')<TRUNC(SYSDATE,'MM'));

            commit;

        --RESTAURANDO LAS DEVOLUCIONES POR EXCESO DE CERTIFICADO DE APORTACION.
            UPDATE
                FAT_CARGABON
            SET
                OPFACTCAAB='S'
            WHERE
                CDCARGABON=252 AND
                STREGI='R' AND
                OPFACTCAAB='N' AND
                VAMONT<200;

            COMMIT;

        --GENERACI¿N DE SALDOS DE CERTIFICADOS EL PRIMERO DE CADA MES
            cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(04) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
            select
                count(*)
            into
                va_cant
            from
            far_saldca
            where
            ansald=to_char(add_months(sysdate,-1),'YYYY') and
            mesald=to_char(add_months(sysdate,-1),'MM');

            IF TO_NUMBER(TO_CHAR(SYSDATE,'DD')) IN (1) or nvl(va_cant,0)<=0 THEN
                FAPQ_CERTAPOR.PR_SALDOCERTAPOR;
                cbpq_coblinweb_ResuProc.pr_Revi(va_Resumen);
                cbpq_coblinweb_ResuProc.pr_Proc(va_Resumen);
            END IF;

            IF TO_NUMBER(TO_CHAR(SYSDATE,'DD')) IN (16)  THEN
                FAPQ_CERTAPOR.PR_SALDOCERTAPOR (2026,7);
            end if;


        --REVISION DE LOS CERTIFICADOS
            cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(05) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
            PR_REVISION;

        --BORRAR LAS BITACORAS DUPLICADAS
            IF TO_NUMBER(TO_CHAR(SYSDATE,'D')) IN (1) THEN
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(06) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_BITACAAB_DELETE_DUPLICADOS;
            END IF;

        --PONE EL SEMAFORO EN VERDE
            cbpq_coblinweb_resuproc.PR_SETSEMAFOROENVERDE (va_cdSema);

        --FINALIZA EL PROCESO Y ENVIAR MAIL
            cbpq_coblinweb_ResuProc.pr_Mail(va_Resumen,'N','davidcm@cre.com.bo');

    END;




    PROCEDURE PR_CUADRARCERTAPOR (pa_cdcargabon number default 2,pa_ticargabon varchar2 default 'C',pa_nucargabon number default null,pa_nucomp number default null) IS

        va_diasrev     number       := 30;

        cursor trae_cargo is

            select
                nucargabon,
                nucomp,
                trunc(fccargo) fccargo,
                nucuen,
                vamont,
                vamontfact,
                mocapi,
                vapagoextr,
                mocapi+vapagoextr vamontok,
                abs( vamontfact - mocapi  - vapagoextr ) diffact,
                vamontcobr,
                mocapicobr,
                mocapicobr+vapagoextr montcobrok,
                abs( vamontcobr - mocapicobr  - vapagoextr ) difcobr,
                opfactcaab,
                stregi,
                stfact,
                stcobr,
                trunc(fcregi) fcregi,
                trunc(fcmodi) fcmodi,
                trunc(fcultipago) fcultipago,
                VAMONTHF
            from
            (
                select /*+ FULL(caxxx) */
                    /*+ INDEX (CA FAT_CARGABON_IN03XXX) */
                    nucargabon,
                    nucomp,
                    nucuen,
                    vamont,
                    nvl(vamontfact,0) vamontfact,
                    nvl((
                        select
                            /*+ INDEX (CT FAE_CARGABON_IN01) */
                            nvl(sum(vamontcapi),0)
                        from
                            fae_cargabon ct
                        where
                            ct.nucargabon=ca.nucargabon and
                            ct.nucomp=ca.nucomp and
                            ct.anpago=to_char(sysdate,'YYYY') and
                            ct.mepago=to_char(sysdate,'MM') and
                            ct.stregi='R' and
                            nvl(ct.nudocucbr,0)=0
                    ),0) vamonthf,
                    nvl((
                            select
                                /*+ INDEX (CAR DCE_CARGABON_IN01) */
                                nvl(sum(decode(timone,'E',round(mocapisus,2),round(mocapibs,1))),0)
                            from
                                dct_docu doc,
                                dce_cargabon car
                            where
                                car.nucargabon=ca.nucargabon and
                                car.nucomp=ca.nucomp and
                                doc.nudocu=car.nudocu and
                                doc.nucomp=car.nucomp and
                                doc.stfact in ('N','F')
                    ),0) mocapi,
                    nvl((
                            select
                                /*+ INDEX (CAR DCE_CARGABON_IN01) */
                                nvl(sum(decode(timone,'E',round(mocapisus,2),round(mocapibs,1))),0)
                            from
                                dct_docu doc,
                                dce_cargabon car
                            where
                                car.nucargabon=ca.nucargabon and
                                car.nucomp=ca.nucomp and
                                doc.nudocu=car.nudocu and
                                doc.nucomp=car.nucomp and
                                doc.stfact in ('N','F') and
                                doc.stpago in ('P','L','R','T')
                    ),0) mocapicobr,
                    nvl((    select
                            nvl(sum(mopago),0)
                        from
                            fam_pagoextr m,
                            fad_pagoextr d
                        where
                            d.nucargabon=ca.nucargabon and
                            d.nucomp=ca.nucomp and
                            m.nupagoextr=d.nupagoextr and
                            m.nucomp=d.nucomp and
                            --m.nucuen=ca.nucuen and
                            m.stpago='P'
                    ),0) vapagoextr,
                    vamontcobr,
                    opfactcaab,
                    stregi,
                    stfact,
                    stcobr,
                    fcregi,
                    fccargo,
                    fcmodi,
                    fcultipago
                from
                    fat_cargabon ca
                where
                    --1=2 and
                    nucomp in (1,2,3,4,5,6,7,8,9,10) and
                    cdcargabon  = pa_cdcargabon and
                    nucomp      = nvl(pa_nucomp,nucomp+0) and
                    version     = version+0 and
                    --timone='E' AND
                    ticargabon  = pa_ticargabon and
                    nucargabon=nvl(pa_nucargabon,nucargabon+0) and
                    (
                        to_char(sysdate,'DD') in (1) OR --El primer dia de mes
                        to_char(sysdate,'D')  in (7) OR --Los domingos
                        fcregi      between trunc(sysdate-va_diasrev,'MM') and sysdate or
                        fcmodi      between trunc(sysdate-va_diasrev,'MM') and sysdate or
                        fccargo     between trunc(sysdate-va_diasrev,'MM') and sysdate or
                        fcultipago  between trunc(sysdate-va_diasrev,'MM') and sysdate
                    )
            )
            where
                vamontHF=0 and
                (
                         abs( vamontfact - mocapi      - vapagoextr )> 0
                      or abs( vamontcobr - mocapicobr  - vapagoextr )> 0
                );

        va_nuerro number;

    BEGIN

        DBMS_OUTPUT.PUT_LINE('FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

         -- Cuadra los saldos de los cargos
            FOR cargo IN trae_cargo
            LOOP
                fapq_cargabon.pr_actualizacargos (  cargo.nucargabon,
                                                    cargo.nucomp,
                                                    cargo.mocapi+cargo.vapagoextr-cargo.vamontfact,
                                                    cargo.mocapicobr+cargo.vapagoextr-cargo.vamontcobr,
                                                    va_nuerro
                                                 );
                commit;
            END LOOP;

            --ACTUALIZACI¿N DEL ESTADO DE LA FACTURACI¿N Y EL COBRO

            if pa_cdcargabon=2 then

                UPDATE
                    FAT_CARGABON
                SET
                    VAMONTFACT=ROUND(VAMONTFACT,2),
                    VAMONTCOBR=ROUND(VAMONTCOBR,2),
                    FCMODI=SYSDATE,
                    NUEMPLMODI=0
                WHERE
                    CDCARGABON=2 AND
                    STREGI='R' AND
                    (
                        ROUND(VAMONTFACT,2)<>VAMONTFACT OR
                        ROUND(VAMONTCOBR,2)<>VAMONTCOBR
                    );

                UPDATE
                    FAT_CARGABON
                SET
                    STFACT=(CASE WHEN ROUND(VAMONTFACT,2)>=410 THEN 'F' ELSE 'I' END),
                    STCOBR=(CASE WHEN ROUND(VAMONTCOBR,2)>=410 THEN 'C' ELSE 'I' END),
                    FCMODI=SYSDATE,
                    NUEMPLMODI=0
                WHERE
                    CDCARGABON=2 AND
                    STREGI='R' AND
                    (
                        (ROUND(VAMONTCOBR,2)>=410 AND STCOBR='I') OR
                        (ROUND(VAMONTCOBR,2)< 410 AND STCOBR='F') OR
                        (ROUND(VAMONTFACT,2)>=410 AND STFACT='I') OR
                        (ROUND(VAMONTFACT,2)< 410 AND STFACT='F')
                    );


                COMMIT;
            end if;

        DBMS_OUTPUT.PUT_LINE('FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

        EXCEPTION
            WHEN OTHERS THEN
            gopq_cpt.Enviar_mail('tecnologia@cre.com.bo','davidcm@cre.com.bo','Error PR_CUADRARCERTAPOR',SQLERRM,null);


    END;


    PROCEDURE PR_CUADRARSALDOCARGO (PA_CDCARGABON NUMBER DEFAULT 2,pa_ticargabon varchar2 default 'C',pa_nucargabon number default null,pa_nucomp number default null) is
    begin
        PR_CUADRARCERTAPOR (pa_cdcargabon,pa_ticargabon,pa_nucargabon,pa_nucomp);
    end;



    PROCEDURE PR_FIXCERTIFICADOS IS

        Cursor trae_devo is

            select
                nucargabon,
                nucomp,
                fccargo,
                nucuen,
                nuserv,
                vamont,
                nuclie,
                nucaabasoc,
                (select nucargabon from fat_cargabon
                    where NUCUEN=ABO.NUCUEN AND
                            NUCOMP=ABO.NUCOMP AND
                            cdcargabon in (2) and
                            ticargabon='C' and
                            nucaabasoc is null and
                            stregi='R') nucargoOK,
                (select vamontfact from fat_cargabon
                    where NUCUEN=ABO.NUCUEN AND
                            NUCOMP=ABO.NUCOMP AND
                            cdcargabon in (2) and
                            ticargabon='C' and
                            nucaabasoc is null and
                            stregi='R') vamontfact,
                (select nuclie from fat_cargabon
                    where NUCUEN=ABO.NUCUEN AND
                            NUCOMP=ABO.NUCOMP AND
                            cdcargabon in (2) and
                            ticargabon='C' and
                            nucaabasoc is null and
                            stregi='R') nuclieOK
            from
                fat_cargabon abo
            where
                abo.cdcargabon in (2) and
                abo.ticargabon='A' and
                abo.stregi='R' and
                abo.nucaabasoc is null
            order by
                fccargo,
                nucuen;

    BEGIN

        --ACTUALIZACION DEL NUCLIE

            UPDATE
                FAT_CARGABON CA
            SET
                NUCLIE=(SELECT CU.NUCLIE FROM SOM_CUEN CU WHERE NUCOMP=CA.NUCOMP AND NUCUEN=CA.NUCUEN),
                FCMODI=SYSDATE,
                NUEMPLMODI=0
            WHERE
                CA.CDCARGABON=2 AND
                CA.TIMONE='E' AND
                CA.STREGI='R' AND
                TICARGABON='C' AND
                VAMONT IN (410) AND
                NVL(NUCAABASOC,0)=0 AND
                NVL(NUCUEN,0)>0 AND
                NVL(NUCOMP,0)>0 AND
                (
                    NVL(NUCLIE,0)=0  OR
                    NVL(NUCLIE,-1)<> NVL((SELECT CU.NUCLIE FROM SOM_CUEN CU WHERE CU.NUCOMP=CA.NUCOMP AND CU.NUCUEN=CA.NUCUEN),-2)
                ) ;

            COMMIT;

        --ACTUALIZACI¿N DE LAS DEVOLUCIONES
        for devo in trae_devo
        loop
            --ACTUALIZACION DE LA DEVOLUCI¿N
                update
                    FAT_CARGABON
                SET
                    nucaabasoc=devo.nucargook,
                    nuclie=devo.nuclieok,
                    FCMODI=SYSDATE,
                    NUEMPLMODI=0
                where
                    nucomp=devo.nucomp and
                    nucargabon=devo.nucargabon;

            --ACTUALIZACION DEL CARGO
                update
                    FAT_CARGABON
                SET
                    nucaabasoc=devo.nucargabon,
                    FCMODI=SYSDATE,
                    NUEMPLMODI=0
                where
                    nucomp=devo.nucomp and
                    nucargabon=devo.nucargook;

            COMMIT;
        end loop;

        -- ANULACI¿N DE CARGOS NO FACTURADOS
        -- Y DESCONECTADOS SIN EL NUMERO DE CLIENTE
        -- CON SERVICIOS ANULADOS O RECHAZADOS

            UPDATE
                FAT_CARGABON CA
            SET
                STREGI='A',
                FCMODI=SYSDATE,
                NUEMPLMODI=0
            WHERE
                (NUCOMP,NUCARGABON) IN
                (
                SELECT
                    NUCOMP,
                    NUCARGABON
                FROM
                (
                SELECT
                    NUCOMP,
                    NUCARGABON,
                    NUCUEN,
                    NUCLIE,
                    CDCARGABON,
                    FCCARGO,
                    NUSERV,
                    (SELECT STSERV FROM SOT_SERV WHERE NUCOMP=CA.NUCOMP AND NUSERV=CA.NUSERV) STSERV,
                    VAMONT,
                    VAMONTFACT,
                    STREGI,
                    STFACT,
                    STCOBR
                FROM
                    FAT_CARGABON CA
                WHERE
                    CA.CDCARGABON IN (2) AND
                    CA.TIMONE='E' AND
                    CA.STREGI='R' AND
                    TICARGABON='C' AND
                    VAMONT = 410 AND
                    NVL(NUCAABASOC,0)=0 AND
                    NVL(NUCUEN,0)=0 AND
                    NVL(NUCLIE,0)=0
                )
                WHERE
                    NVL(VAMONTFACT,0)=0 AND
                    (
                        NVL(STSERV,'E') IN ('A')
                        OR Sopq_CtrlServ.Fn_esAtencionRechazada(NUCOMP,NUSERV)='S'
                    )
                );

        COMMIT;

       -- ASEGURAR QUE LAS DEVOLUCIONES NO EST¿N DISPONIBLES PARA LA FACTURACI¿N MENSUAL

            update
                fat_cargabon
            set
                opfactcaab='N'
            where
                cdcargabon=2 and
                ticargabon='A' and
                OPFACTCAAB='S';

        COMMIT;

       -- ANULACION DE CARGOS DUPLICADOS NO FACTURADOS POR CUENTA

            update
                fat_cargabon
            set
                stregi='A',
                nuemplmodi=0,
                fcmodi=sysdate
            where
                (nucomp,nucargabon) in
                (
                select
                    nucomp,
                    max(decode(vamontfact,0,nucargabon,0)) anul
                from
                    fat_cargabon
                where
                    cdcargabon=2  and
                    ticargabon='C' AND STREGI='R' and nvl(nucaabasoc,0)=0 and
                    nvl(nucuen,0)>0
                group by
                    nucomp,
                    nucuen
                having
                    count(*)>1
                );

            COMMIT;

       --INCONSISTENCIAS EN STFACT Y OPFACTCAAB
        DECLARE

            CURSOR TRAE_CARGO IS

                SELECT
                    R2.*
                FROM
                (
                    SELECT
                        RE.*,
                        (CASE
                            WHEN VAMONTFACT>=410 AND STFACT='I'                     THEN 'F'
                            WHEN VAMONTFACT<410 AND STFACT='F'                      THEN 'I'
                            ELSE NULL
                         END
                        ) STFACTOK,
                        (CASE
                            WHEN TIAFIL='C' AND OPFACTCAAB='S'                      THEN 'N'
                            WHEN NVL(NUCAABASOC,0)>0 AND OPFACTCAAB='S'             THEN 'N'
                            WHEN TIAFIL='S' AND VAMONTFACT>=410 AND NVL(NUCAABASOC,0)=0 AND OPFACTCAAB='N' THEN 'S'
                            WHEN TIAFIL='S' AND VAMONTFACT< 410 AND NVL(NUCAABASOC,0)=0 AND OPFACTCAAB='N' AND ANULTIPAGO>=201701 THEN 'S'
                            ELSE NULL
                         END
                        ) OPFACTCAABOK
                    FROM
                    (
                        SELECT
                            NUCOMP,
                            NVL((SELECT TIAFIL FROM SOM_CUEN WHERE NUCOMP=CA.NUCOMP AND NUCUEN=CA.NUCUEN AND CA.NUCUEN>0),'C') TIAFIL,
                            (SELECT MAX(ANPAGO*100+MEPAGO) FROM FAE_CARGABON WHERE NUCOMP=CA.NUCOMP AND NUCARGABON=CA.NUCARGABON AND STREGI='R') ANULTIPAGO,
                            NUCARGABON,
                            NUCUEN,
                            VAMONT,
                            VAMONTFACT,
                            VAMONTCOBR,
                            STFACT,
                            STCOBR,
                            STREGI,
                            OPFACTCAAB,
                            NUCAABASOC
                        FROM
                            FAT_CARGABON CA
                        WHERE
                            CDCARGABON=2 AND
                            TICARGABON='C' AND
                            STREGI='R'
                    ) RE
                ) R2
                WHERE
                    STFACTOK  IS NOT NULL OR
                    OPFACTCAABOK IS NOT NULL;

        BEGIN
            FOR CARGO IN TRAE_CARGO
            LOOP

                update
                    FAT_CARGABON
                SET
                    STFACT      = NVL (CARGO.STFACTOK,STFACT),
                    OPFACTCAAB  = NVL (CARGO.OPFACTCAABOK,OPFACTCAAB),
                    FCMODI=SYSDATE,
                    NUEMPLMODI=0
                where
                    nucomp=cargo.nucomp and
                    nucargabon=cargo.nucargabon;

                commit;

            END LOOP;
        END;

        --ANULACI¿N DE DEVOLUCI¿N CON SERVICIOS OBSERVADOS

            FAPQ_CERTAPOR.PR_FIXDEVOSINSERV;


        --ACTUALIZACION DEL CLIENTE DEL CERTIFICADO

            UPDATE
                SCM_cERT ce
            SET
                NUCLIE = (select NUCLIE from fat_Cargabon where nucargabon=ce.nucargabon and nucomp=ce.nucomp),
                FCMODI = SYSDATE,
                NUEMPLMODI= 0
            WHERE
                IDCERT IN
            (
                SELECT
                    idcert
                FROM
                (
                    SELECT
                        CE.IDCERT,
                        CE.NUCARGABON,
                        CE.STCERT,
                        CE.NUCLIE,
                        (SELECT NUCLIE      FROM FAT_CARGABON WHERE NUCARGABON=CE.NUCARGABON AND NUCOMP=CE.NUCOMP AND CDCARGABON=2 AND TICARGABON='C' AND STREGI='R') NUCLIECARG
                    FROM
                        SCM_CERT CE
                    WHERE
                        NVL(NUCARGABON,0)>0 AND
                        STREGI='R'
                )
                WHERE
                    NVL(NUCLIE,-1)<>NVL(NUCLIECARG,-1)and
                    NUCLIECARG IS NOT NULL
            );

            COMMIT;

        --ANULACI¿N DE CERTIFICADOS NO RELACIONADOS A UN CARGO
            UPDATE
                SCM_CERT CE
            SET
                STREGI='A'
            WHERE
                CE.STREGI='R' AND
                NOT EXISTS (
                                SELECT 'X' FROM
                                FAT_CARGABON CA
                                WHERE
                                    NUCARGABON=NVL(CE.NUCARGABON,-1) AND
                                    NUCOMP=NVL(CE.NUCOMP,0) AND
                                    TICARGABON='C' AND
                                    TIMONE='E' AND
                                    CA.STREGI='R' AND
                                    VAMONT IN (410) AND
                                    CDCARGABON =2
                            );

            COMMIT;

        --ACTUALIZACION DE LA CUENTA DEL CERTIFICADO

            UPDATE
                SCM_cERT ce
            SET
                NUCUEN = (select nucuen from fat_Cargabon where nucargabon=ce.nucargabon and nucomp=ce.nucomp),
                FCMODI = SYSDATE,
                NUEMPLMODI= 0
            WHERE
                IDCERT IN
            (
                SELECT
                    idcert
                FROM
                (
                    SELECT
                        CE.IDCERT,
                        CE.NUCARGABON,
                        CE.STCERT,
                        CE.NUCUEN,
                        (SELECT NUCUEN      FROM FAT_CARGABON WHERE NUCARGABON=CE.NUCARGABON AND NUCOMP=CE.NUCOMP AND CDCARGABON=2 AND TICARGABON='C' AND STREGI='R') NUCUENCARG
                    FROM
                        SCM_CERT CE
                    WHERE
                        STREGI='R' AND
                        NVL(NUCARGABON,0)>0
                )
                WHERE
                    NVL(NUCUEN,-1)<>NVL(NUCUENCARG,-1)
            );

            COMMIT;

        --CREACI¿N DEL ABONO EN SERVICIOS DE DEVOLUCION

            DECLARE

                CURSOR TRAE_DEVO IS

                    SELECT
                        RE.*,
                        (SELECT OPFACTCAAB FROM FAT_CARGABON WHERE NUCARGABON=RE.NUCARGABON AND NUCOMP=RE.NUCOMP) OPFACTCAAB,
                        (SELECT NUCUEN     FROM FAT_CARGABON WHERE NUCARGABON=RE.NUCARGABON AND NUCOMP=RE.NUCOMP) NUCUEN2,
                        (SELECT NUCLIE     FROM FAT_CARGABON WHERE NUCARGABON=RE.NUCARGABON AND NUCOMP=RE.NUCOMP) NUCLIE,
                        (SELECT NUCAABASOC FROM FAT_CARGABON WHERE NUCARGABON=RE.NUCARGABON AND NUCOMP=RE.NUCOMP) NUCAABASOC
                    FROM
                    (
                        SELECT
                            NUCOMP,
                            NUSERV,
                            CDSERV,
                            TRUNC(FCREGI) FCREGI,
                            CDMOTI,
                            NUCUEN,
                            STSERV,
                            (SELECT LISTAGG(NUCAABASOC) WITHIN GROUP (ORDER BY NUCAABASOC) FROM FAT_CARGABON CA WHERE NUSERV=SE.NUSERV AND NUCOMP=SE.NUCOMP AND STREGI='R' AND CDCARGABON IN (1,2)) SERVCARGOS,
                            sopq_descclie.fn_numero(substr(dtserv,31,8)) idcert,
                            (SELECT NUCARGABON FROM SCM_CERT WHERE IDCERT=sopq_descclie.fn_numero(substr(dtserv,31,8))) NUCARGABON,
                            DTSERV
                        FROM
                            SOT_SERV SE
                        WHERE
                            CDSERV='092' AND
                            STSERV IN ('E','P')
                    ) RE
                    WHERE
                        SERVCARGOS IS NULL;

            BEGIN

                FOR DEVO IN TRAE_DEVO
                LOOP

                    --EMITIDO Y CON DEVOLUCION EXISTENTE
                    IF DEVO.STSERV='E' AND NVL(DEVO.NUCAABASOC,0)>0 THEN
                        UPDATE
                            SOT_SERV
                        SET
                            STSERV='A'
                        WHERE
                            NUSERV=DEVO.NUSERV AND
                            NUCOMP=DEVO.NUCOMP;
                        COMMIT;
                    END IF;

                    IF DEVO.STSERV='P' AND NVL(DEVO.NUCUEN,0)=0 AND
                        NVL(DEVO.NUCAABASOC,0)=0 AND NVL(DEVO.NUCARGABON,0)>0 THEN

                        SGC_FA.PR_DEVOLUCIONFIX (   DEVO.NUSERV,
                                                    DEVO.NUCOMP,
                                                    DEVO.FCREGI,
                                                    DEVO.NUCUEN,
                                                    DEVO.NUCARGABON,
                                                    DEVO.IDCERT
                                                );
                    END IF;

                END LOOP;

                COMMIT;

            END;

        --FIN CREACI¿N DEL ABONO EN SERVICIOS DE DEVOLUCION

        -- ANULACI¿N DE CERTIFICADOS QUE APUNTAN A UN MISMO CARGO

            UPDATE
                SCM_CERT
            SET
                STREGI='A',
                NUEMPLMODI=0,
                FCMODI=SYSDATE
            WHERE
                IDCERT IN
                (
                SELECT
                    MAX(IDCERT) IDCERTDUPLI
                FROM
                    SCM_CERT CE
                WHERE
                    NVL(NUCARGABON,0)>0
                    AND STREGI='R'
                GROUP BY
                    NUCOMP,
                    NUCARGABON,
                    NUCUEN,
                    NUCLIE
                HAVING
                    COUNT(*)>1
                );

            COMMIT;

        --ACTUALIZA EL ESTADO DE LOS CERTIFICADOS

            PR_FIXSTCERT;

        --CREACI¿N DE CERTIFICADOS

        DECLARE

            CURSOR TRAE_CARGO IS

                SELECT
                    0 IDCERT,
                    NULL NUSECUCERT,
                    NUCARGABON,
                    nvl(NUCLIE,
                    (select nuclie from soe_clieserv where nuserv=ca.nuserv and nucomp=ca.nucomp)) nuclie,
                    '1' TICERT,
                    'C' TICOBR,
                    'S' TIORIGCERT,
                    (CASE
                        WHEN VAMONTFACT=0 THEN 'I'
                        WHEN VAMONTFACT<410 THEN 'C'
                        ELSE 'F'
                     END) STCOBR,
                    (CASE
                        WHEN VAMONTCOBR=0 THEN 'I'
                        WHEN VAMONTCOBR<410 THEN 'C'
                        ELSE 'P'
                     END) STPAGO,
                    'A' TIORIGVALO,
                    (CASE
                        WHEN NVL(NUCAABASOC,0)>0 THEN 'DEV'
                        WHEN VAMONTFACT=0 THEN 'SUS'
                        WHEN VAMONTFACT<410 THEN 'PEN'
                        ELSE 'EMI'
                     END) STCERT,
                     'S' TIPROPI,
                     'N' OPTRAN,
                     NUCOMP,
                     NUCUEN,
                     NULL FCEMIS,
                     'R' STREGI,
                     SYSDATE FCREGI,
                     0 NUEMPLREGI,
                     NULL FCMODI,
                     NULL NUEMPLMODI
                FROM
                    FAT_CARGABON CA
                WHERE
                    CDCARGABON=2 AND
                    TICARGABON='C' AND
                    STREGI='R' AND
                    NOT EXISTS (
                                    SELECT 'X' FROM SCM_CERT CE
                                    WHERE
                                    CE.NUCARGABON=CA.NUCARGABON AND
                                    CE.NUCOMP=CA.NUCOMP AND
                                    CE.STREGI='R'
                                ) AND
                    (
                        NVL(VAMONTFACT,0)>0 OR
                        NVL((SELECT STSERV FROM SOT_SERV SO WHERE SO.NUSERV=CA.NUSERV AND SO.NUCOMP=CA.NUCOMP),'A') IN ('P','A')
                    )
                ORDER BY
                    FCREGI DESC;


            va_index NUMBER;

        BEGIN
            FOR CARGO IN TRAE_CARGO
            LOOP

                    SELECT
                        scm_sq_cert.NEXTVAL
                    into
                        va_index
                    FROM
                        DUAL;

                    cargo.idcert := va_index;

                    INSERT INTO SCM_CERT VALUES CARGO;
                COMMIT;

            END LOOP;
        END;

        --CREACI¿N DE SOCIOS (INICIALMENTE SE LO CREA COMO SOCIO DE BAJA)

           Insert Into scm_soci
           (       nusoci,           nuclie,          fcregi,       fcalta,
                   fcbaja,       cdmotibaja,      nuservalta,   nuservbaja,
                   stsoci,           nucomp,STREGI)
            (
            SELECT
                nvl(MgPq_Secu.Fn_EjecutarSecuencia('SGC_SQ_SC_SOCIOS'),0) NUSOCI,
                NUCLIE,
                SYSDATE FCREGI,
                FCREGI FCALTA,
                SYSDATE FCBAJA,
                '156' CDMOTIBAJA,  --VER TABLA MGC_MOTI
                NUSERV NUSERVALTA,
                NULL NUSERVBAJA,
                'B' STSOCI,
                NUCOMP,
                'R' STREGI
            FROM
            (
                SELECT
                    *
                FROM
                (
                    SELECT
                        NUCOMP,
                        NUCARGABON,
                        NUCUEN,
                        NUCLIE,
                        NUSERV,
                        VAMONTFACT,
                        STREGI,
                        FCREGI,
                        FCMODI,
                        (SELECT STREGI||STSOCI FROM SCM_SOCI SO WHERE SO.NUCLIE=CA.NUCLIE) STSOCI,
                        (SELECT NUSOCI FROM SCM_SOCI SO WHERE SO.NUCLIE=CA.NUCLIE) NUSOCI,
                        (SELECT STSERV FROM SOT_SERV SO WHERE SO.NUSERV=CA.NUSERV AND SO.NUCOMP=CA.NUCOMP AND NVL(CA.NUSERV,0)>0) STSERV
                    FROM
                        FAT_CARGABON CA
                    WHERE
                        NVL(NUCAABASOC,0)=0 AND
                        CDCARGABON=2 AND
                        TICARGABON='C' AND
                        STREGI='R' AND
                        NOT EXISTS (SELECT 'X' FROM SCM_SOCI SO WHERE SO.NUCLIE=CA.NUCLIE ) AND
                        CA.NUCLIE IS NOT NULL
                ) CA
            )
            );

        --ELIMINAR SOCIOS DUPLICADOS

            delete scm_soci where nusoci in
            (
                    SELECT MAX(NUSOCI)
                    FROM SCM_SOCI SO
                    GROUP BY NUCLIE
                    HAVING COUNT(*)>1
            );

            COMMIT;

        --DAR DE ALTA A AQUELLOS SOCIOS QUE TIENEN AL MENOS UNA CUOTA COBRADA

            UPDATE
                SCM_SOCI
            SET
                STSOCI='A',
                STREGI='R',
                FCALTA=SYSDATE,
                CDMOTIBAJA=NULL,
                FCMODI=SYSDATE,
                NUEMPLMODI=0
            WHERE
                NUCLIE IN
            (
                SELECT
                    distinct nuclie
                FROM
                (
                    SELECT
                        NUCOMP,
                        NUCARGABON,
                        NUCUEN,
                        NUCLIE,
                        NUSERV,
                        VAMONTFACT,
                        VAMONTCOBR,
                        STREGI,
                        FCREGI,
                        FCMODI,
                        (SELECT STREGI||STSOCI FROM SCM_SOCI SO WHERE SO.NUCLIE=CA.NUCLIE) STSOCI,
                        (SELECT NUSOCI FROM SCM_SOCI SO WHERE SO.NUCLIE=CA.NUCLIE) NUSOCI,
                        (SELECT STSERV FROM SOT_SERV SO WHERE SO.NUSERV=CA.NUSERV AND SO.NUCOMP=CA.NUCOMP AND NVL(CA.NUSERV,0)>0) STSERV
                    FROM
                        FAT_CARGABON CA
                    WHERE
                        NVL(NUCAABASOC,0)=0 AND
                        CDCARGABON=2 AND
                        TICARGABON='C' AND
                        STREGI='R'
                        AND NVL(VAMONTCOBR,0)>0
                ) CA
                WHERE
                    --NUCARGABON=9534448 AND
                    NOT EXISTS (SELECT 'X' FROM SCM_SOCI SO
                    WHERE SO.NUCLIE=CA.NUCLIE AND SO.STSOCI='A' AND SO.STREGI='R')
            );

            COMMIT;

        --DAR DE BAJA A LOS SOCIOS ACTIVOS SIN EL CARGO COBRADO

            UPDATE
                SCM_SOCI SO
            SET
                STSOCI      = 'B',
                FCBAJA      = SYSDATE,
                NUSERVBAJA  = 0,
                CDMOTIBAJA  = '156',  --PAGO NO REPORTADO POR CENTRO DE COBRANZA DE LA TABLA
                NUEMPLMODI  = 0,
                FCMODI      = SYSDATE
            where
                NUSOCI IN
            (
            SELECT
                NUSOCI
            FROM
            (
                SELECT
                    NUSOCI,
                    NUCLIE,
                    NUSERVALTA,
                    NUCOMP,
                    STSOCI,
                    STREGI,
                    FCALTA,
                    FCBAJA,
                    NUSERVBAJA,
                    CDMOTIBAJA,
                    FCREGI,
                    (
                        SELECT
                            SUM(VAMONTFACT)
                        FROM
                            FAT_CARGABON
                        WHERE
                            NUCLIE=SO.NUCLIE AND
                            CDCARGABON=2 AND
                            TICARGABON='C' AND
                            STREGI='R' AND
                            NVL(NUCAABASOC,0)=0
                    ) VAMONTFACT,
                    (
                        SELECT
                            SUM(VAMONTCOBR)
                        FROM
                            FAT_CARGABON
                        WHERE
                            NUCLIE=SO.NUCLIE AND
                            CDCARGABON=2 AND
                            TICARGABON='C' AND
                            STREGI='R' AND
                            NVL(NUCAABASOC,0)=0
                    ) VAMONTCOBR,
                    (
                        SELECT
                            COUNT(*)
                        FROM
                            FAT_CARGABON
                        WHERE
                            NUCLIE=SO.NUCLIE AND
                            CDCARGABON=2 AND
                            TICARGABON='C' AND
                            STREGI='R' AND
                            NVL(NUCAABASOC,0)=0
                    ) CANT
                FROM
                    SCM_SOCI SO
                where
                    stsoci='A' AND
                    STREGI='R'
                )
            WHERE
                (
                    NVL(CANT,0)=0
                    OR NVL(VAMONTCOBR,0)=0
                )
            );


        COMMIT;

    --DAR DE BAJA A SOCIOS SIN CERTIFICADO EMITIDO

        UPDATE
            SCM_SOCI SO
        SET
            STSOCI      = 'B',
            FCBAJA      = SYSDATE,
            NUSERVBAJA  = 0,
            CDMOTIBAJA  = 'A01', --REGULARIZACION. VER TABLA MGC_MOTI
            NUEMPLMODI  = 0,
            FCMODI      = SYSDATE
        where
            NUSOCI IN
        (
            SELECT
                NUSOCI
            FROM
                SCM_SOCI SO
            where
                stsoci='A' AND
                STREGI='R' AND
                NOT EXISTS (SELECT 'X' FROM SCM_CERT CE WHERE CE.NUCLIE=SO.NUCLIE AND STREGI='R' AND STCERT NOT IN ('DEV','XSUS'))
        );

        COMMIT;

    --INTEGRIDAD EN LA FECHA DE BAJA

        UPDATE
            SCM_SOCI
        SET
            FCBAJA = NVL(FCBAJA,SYSDATE),
            CDMOTIBAJA='A01' --REGULARIZACION
        WHERE
            STSOCI='B' AND
            ( FCBAJA IS NULL OR CDMOTIBAJA IS NULL);

        COMMIT;

    --CARGOS DUPLICADOS POR CUENTA
        PR_FIXDUPLICADOS;

    --INTEGRIDAD FECHA DE ALTA
    --VALIDA CON LO ¿LTIMO ENVIADO A LA AFCOOP
    --SOCIOS DE ALTA DEL PRESENTE MES
    --EL ALTA DE UN SOCIO PUEDE DARSE POR:
        -- PAGO DE SU PRIMER CUOTA DE CERTIFICADO
        -- TRANSFERENCIA DE DERECHO
    --NO ENVIADO A LA AFCOOP EN EL ¿LTIMO MES Y QUE  EST¿ DE ALTA. DEBE TENER FECHA DE ALTA EN EL PRESENTE MES
    --SE DEBE EJECUTAR DESPUES DE QUE SE GENER¿ LA TASA AFCOOP

/*
--ESTO YA NO APLICA
-04/09/2019
    IF TO_CHAR(SYSDATE,'DD')>va_DiaReviSaldoAFCOOP THEN

        UPDATE
            SCM_SOCI
        SET
            FCALTA=SYSDATE,
            CDMOTIBAJA=NULL,
            FCMODI=SYSDATE,
            NUEMPLMODI=0
        WHERE
            NUSOCI IN
        (
            SELECT
                NUSOCI
            FROM
            (
            SELECT
                NUSOCI,
                (SELECT NUCLIE      FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) NUCLIE,
                (SELECT FCALTA      FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) FCALTA
            FROM
            (
            SELECT NUSOCI FROM SCM_SOCI WHERE STSOCI='A' AND STREGI='R'
            MINUS
            SELECT NUSOCI FROM SCT_TASAAFCO WHERE ANTASA=TO_CHAR(SYSDATE,'YYYY') AND METASA=TO_CHAR(SYSDATE,'MM') AND STREGI='R' AND VATASAAPLI>0
            ) RE
            ) R2
            WHERE
                FCALTA IS NULL OR
                FCALTA < TRUNC(SYSDATE,'MM')
        );

        COMMIT;

    END IF;
*/

    end;


    PROCEDURE PR_FIXDUPLICADOS IS
        --DEMORA 1 MINUTO

        CURSOR TRAE_CERTDUPLI IS

                SELECT
                    NUCUEN,
                    NUCOMP,
                    STCUEN,
                    STCONE,
                    NUCLIE,
                    NUSOCI,
                    FCALTA,
                    TICUEN,
                    CTCARG2,
                        (
                            SELECT
                                MAX(NUCARGABON)
                            FROM
                                FAT_CARGABON CA
                            WHERE
                                CA.NUCUEN=RE.NUCUEN AND
                                CA.NUCOMP=RE.NUCOMP AND
                                CA.CDCARGABON IN (2) AND
                                CA.TIMONE='E' AND
                                CA.STREGI='R' AND
                                TICARGABON='C' AND
                                NVL(NUCAABASOC,0)=0  --NO DEVUELTO
                                AND VAMONT IN (400,410)
                        ) NUCARGABON2
                FROM
                (
                    SELECT
                        NUCUEN,
                        NUCOMP,
                        stcuen,
                        stcone,
                        nuclie,
                        (select nusoci from scm_soci where nuclie=cu.nuclie and stsoci='A') nusoci,
                        FCALTA,
                        (select dscuen from soc_cuen where cdcuen=cu.cdcuen and nucomp=cu.nucomp) ticuen,
                        (
                            SELECT
                                COUNT(*)
                            FROM
                                FAT_CARGABON CA
                            WHERE
                                CA.NUCUEN=CU.NUCUEN AND
                                CA.NUCOMP=CU.NUCOMP AND
                                CA.CDCARGABON IN (2) AND
                                CA.TIMONE='E' AND
                                CA.STREGI='R' AND
                                TICARGABON='C' AND
                                NVL(NUCAABASOC,0)=0  --NO DEVUELTO
                                AND VAMONT IN (400,410)
                        ) CTCARG2
                    FROM
                        SOM_CUEN CU
                    WHERE
                        --NUCUEN=6636 AND
                        NVL(CU.NUCUEN,0)>0
                ) RE
                WHERE
                    NVL(CTCARG2,0)>1     --CARGO 2 DUPLICADO
                ORDER BY
                    NUCOMP,
                    NUCUEN DESC;

    BEGIN
        FOR dupli in trae_certdupli
        loop
            update
                fat_cargabon
            set
                opfactcaab='N',
                NUCUEN=0,
                fcmodi=sysdate,
                nuemplmodi=0
            where
                nucomp=dupli.nucomp and
                nucargabon=dupli.nucargabon2;
            commit;
            --DBMS_OUTPUT.PUT_LINE(' Se desconect¿ de la cuenta el cargo '||dupli.nucargabon2||'-'||dupli.nucomp);
        end loop;
    END;


    PROCEDURE PR_FIXNUSECUCERT IS

            VA_NUSECUCERT NUMBER;

            CURSOR TRAE_CERT IS

                SELECT
                    CE.ROWID FILAID,
                    CE.IDCERT,
                    CE.NUCOMP,
                    CE.NUCARGABON,
                    CE.NUSECUCERT,
                    CA.VAMONT,
                    CA.VAMONTCOBR,
                    CA.FCCARGO,
                    CA.FCULTIPAGO,
                    CA.STREGI,
                    CA.NUCAABASOC,
                    CA.CDCARGABON,
                    CA.STFACT,
                    CA.STCOBR,
                    CA.FCMODI
                FROM
                    FAT_CARGABON CA,
                    SCM_CERT CE
                WHERE
                    NVL(CE.NUCARGABON,0)>0
                    AND CE.STREGI='R' AND
                    CA.NUCARGABON=CE.NUCARGABON AND
                    CA.NUCOMP=CE.NUCOMP AND
                    ROUND(CA.VAMONTCOBR,2)>=410 AND
                    NVL(CA.NUCAABASOC,0)=0 AND --NO DEVUELTO
                    NVL(NUSECUCERT,0)=0
                ORDER BY
                    CA.FCULTIPAGO,
                    CA.FCCARGO,
                    CA.NUCUEN,
                    CA.NUCOMP,
                    IDCERT;


        BEGIN

            --ACTUALIZACION DE LA FECHA DE ULTIMO PAGO

                PR_FIXFCULTIPAGOCERT;

            --ACTUALIZACI¿N DEL ESTADO DEL CERTIFICADO

                PR_FIXSTCERT;

            --ACTUALIZACION DEL N¿MERO DE CERTIFICADO

            SELECT NVL(MAX(NUSECUCERT),0) INTO VA_NUSECUCERT FROM SCM_CERT;

            for cert in trae_cert
            loop

                va_nusecucert := va_nusecucert + 1;

                update
                    SCM_CERT
                set
                    NUSECUCERT = va_nusecucert,
                    STCERT = 'EMI',
                    FCEMIS = GREATEST(CERT.FCULTIPAGO,TO_DATE('14/11/2018','DD/MM/YYYY')),
                    FCMODI = SYSDATE,
                    NUEMPLMODI= 0
                where
                    ROWID=CERT.FILAID;

                commit;

            end loop;

            UPDATE
                SCM_CERT CE
            SET
                FCEMIS = (SELECT GREATEST(FCULTIPAGO,TO_DATE('14/11/2018','DD/MM/YYYY')) FROM FAT_CARGABON WHERE NUCARGABON=CE.NUCARGABON AND NUCOMP=CE.NUCOMP)
            WHERE
                STCERT = 'EMI' AND
                NVL(FCEMIS,SYSDATE) <> (SELECT GREATEST(FCULTIPAGO,TO_DATE('14/11/2018','DD/MM/YYYY')) FROM FAT_CARGABON WHERE NUCARGABON=CE.NUCARGABON AND NUCOMP=CE.NUCOMP);

            commit;


        END;

    PROCEDURE PR_FIXFCULTIPAGOCERT IS

            CURSOR TRAE_FCULTIPAGO IS

                select
                    FILAID,NUCOMP,NUCARGABON,NUCUEN,FCREGI,FCCARGO,FCULTIPAGO,fcpagofact,fcpagoextr,
                    greatest(nvl(fcpagofact,fcpagoextr),nvl(fcpagoextr,fcpagofact)) FCULTIPAGOOK
                from
                (
                select
                    CA.ROWID FILAID,
                    nucomp,
                    nucargabon,
                    nucuen,
                    fcregi,
                    fccargo,
                    fcultipago,
                    (   select
                            max(fcpago)
                        from
                            dct_docu doc,
                            dce_cargabon car
                        where
                            car.nucargabon=ca.nucargabon and
                            car.nucomp=ca.nucomp and
                            doc.nudocu=car.nudocu and
                            doc.nucomp=car.nucomp and
                            doc.stfact in ('N','F') and
                            doc.stpago in ('P','L','R','T')
                    ) fcpagofact,
                    (    select
                            max(m.fcpago)
                        from
                            fam_pagoextr m,
                            fad_pagoextr d
                        where
                            d.nucargabon=ca.nucargabon and
                            d.nucomp=ca.nucomp and
                            m.nupagoextr=d.nupagoextr and
                            m.nucomp=d.nucomp and
                            --m.nucuen=ca.nucuen and
                            m.stpago='P'
                    )fcpagoextr
                from
                    fat_cargabon ca
                where
                    cdcargabon=2 and
                    stregi='R' and
                    vamontcobr>=410
                )
                where
                    --NUCARGABON=9302011 AND
                    NVL(fcultipago,SYSDATE)<>greatest(nvl(fcpagofact,fcpagoextr),nvl(fcpagoextr,fcpagofact));
    BEGIN


                for carg in TRAE_FCULTIPAGO
                loop

                    update
                        FAT_CARGABON
                    set
                        FCULTIPAGO = carg.fcultipagook,
                        FCMODI = SYSDATE,
                        NUEMPLMODI= 0
                    where
                        ROWID=CARG.FILAID;

                    commit;

                end loop;

    END;

    PROCEDURE PR_FIXDEVOSINSERV IS

        Cursor trae_abonSinServ is

            select
                *
            from
                fat_cargabon abo
            where
                abo.cdcargabon in (2) and
                abo.ticargabon='A' and
                abo.stregi='R' and
                --abo.nucargabon=9963182 and
                abo.nuserv=abo.nuserv+0 and
                abo.nucomp=abo.nucomp+0 and
                not exists (select 'X' from sot_Serv where nuserv=abo.nuserv and nucomp=abo.nucomp AND CDSERV IN ('092','054') AND STSERV IN ('E','P'));

    begin

        for abono in trae_abonSinServ
        loop
            if abono.vamontfact=0 then
                update fat_cargabon set stregi='A',fcmodi=sysdate,nuemplmodi=0 where nucargabon=abono.nucargabon and nucomp=abono.nucomp;
                update fat_cargabon set nucaabasoc=null,fcmodi=sysdate,nuemplmodi=0 where nucargabon=abono.nucaabasoc and nucomp=abono.nucomp;
                commit;
            end if;
        end loop;
        fapq_certapor.PR_FIXSTCERT;

    end;

    PROCEDURE PR_FIXSTCERT IS

            CURSOR TRAE_STCERT IS

                SELECT
                    *
                FROM
                (
                    SELECT
                        CE.ROWID FILAID,
                        CE.IDCERT,
                        CE.NUCOMP,
                        CE.NUCARGABON,
                        CE.NUSECUCERT,
                        CE.STCERT,
                        (CASE
                            WHEN NVL(NUCAABASOC,0)>0 THEN 'DEV'
                            WHEN NVL(VAMONTCOBR,0)=0 THEN 'SUS'
                            WHEN NVL(VAMONTCOBR,0)>=410 THEN 'EMI'
                            ELSE 'PEN'
                         END) STCERTOK,
                        CA.VAMONT,
                        CA.VAMONTCOBR,
                        CA.FCCARGO,
                        CA.FCULTIPAGO,
                        CA.STREGI,
                        CA.NUCAABASOC,
                        CA.CDCARGABON,
                        CA.STFACT,
                        CA.STCOBR,
                        CA.FCMODI
                    FROM
                        FAT_CARGABON CA,
                        SCM_CERT CE
                    WHERE
                        NVL(CE.NUCARGABON,0)>0
                        AND CE.STREGI='R' AND
                        CA.NUCARGABON=CE.NUCARGABON AND
                        CA.NUCOMP=CE.NUCOMP
                )
            WHERE
                STCERT<>STCERTOK;
    BEGIN

            --ACTUALIZACI¿N DEL ESTADO DEL CERTIFICADO

            for cert in TRAE_STCERT
            loop

                update
                    SCM_CERT
                set
                    STCERT = cert.stcertok,
                    FCMODI = SYSDATE,
                    NUEMPLMODI= 0
                where
                    ROWID=CERT.FILAID;

                commit;

            end loop;

    END;



    PROCEDURE PR_REVISION IS
        va_cdSema            varchar2(100) := 'FARECA';
        va_dsSema            varchar2(100) := 'REVISI¿N DE CERTIFICADOS DE APORTACION';
        va_idSema           number;
        va_MinInspeccion    number:=1440;
        va_MinRojo          number:=600;
        va_Resumen cbpq_coblinweb_ResuProc.re_Resumen;
        va_isOk                varchar2(1);
        va_dsmens            varchar2(30000);
        va_ctErro           number;
    BEGIN

        --OBTENER EL ID DEL SEMAFORO
            va_idSema := cbpq_coblinweb_RESUPROC.FN_GETIDSEMAFORO  (va_cdsema);
            if va_idSema is null then
                cbpq_coblinweb_RESUPROC.PR_CREARSEMAFORO (  va_cdsema,
                                                            va_dssema,          --Nombre del Sem¿foro
                                                            va_MinInspeccion,   --Frecuencia de Inspeccion en Minutos
                                                            substr(va_cdsema,1,2),               --M¿dulo
                                                            va_idSema,          --Id del Semaforo
                                                            va_isOk,
                                                            va_dsMens
                                                         );
                if va_isOk='N' then
                    return;
                end if;
            end if;

       --VERIFICACION DEL SEMAFORO DE ELIMINACION
            if cbpq_coblinweb_resuproc.FN_ESTASEMAFOROENROJO (va_cdsema) = 'S' then
                va_dsMens := 'Este proceso est¿ siendo ejecutado en otra sesi¿n.  Favor esperar que termine';
                return;
            end if;

        --PONE EL SEMAFORO EN ROJO POR 600 MINUTOS Y LO INICIA
            cbpq_coblinweb_resuproc.PR_SETSEMAFOROENROJO (va_cdSema,va_minRojo,va_dsSema);
            cbpq_coblinweb_ResuProc.pr_Inic(va_Resumen,va_dsSema,va_idSema,0);

        --MENSAJE
        cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'*** Revisi¿n realizada en el paquete fapq_certapor.PR_REVISION ***');

        --FIX PREVIO A LAS REVISIONES
            va_dsmens := 'Intentanto ejecutar PR_FIXCERTIFICADOS';
            cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(07) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
            PR_FIXCERTIFICADOS;

        -- REVISIONES DE CUENTAS
            va_dsmens := 'Intentanto ejecutar PR_REVISION01';
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(08) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION01 (va_Resumen);
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(09) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION02 (va_Resumen);

        -- REVISIONES DE CARGOS
            va_dsmens := 'Intentanto ejecutar PR_REVISION11';
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(11) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION11 (va_Resumen);
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(12) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION12 (va_Resumen);
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(13) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION13 (va_Resumen);
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(14) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION14 (va_Resumen);
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(15) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION15 (va_Resumen);
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(16) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION16 (va_Resumen);
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(17) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION17 (va_Resumen);

        -- REVISIONES EN ABONOS

            va_dsmens := 'Intentanto ejecutar PR_REVISION20';
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(20) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION20 (va_Resumen);
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(21) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION21 (va_Resumen);
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(22) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION22 (va_Resumen);
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(23) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION23 (va_Resumen);

                --NO REALIZAR ESTA VALIDACI¿N LOS PRIMEROS DIAS DEL MES
                --RESUMEN DE SALDOS MENSUALES
                if TO_CHAR(SYSDATE,'DD')>=va_DiaReviSaldoAFCOOP then
                    PR_REVISION24 (va_Resumen);
                    PR_REVISION25 (va_Resumen);
                end if;

        --REVISIONES EN CERTIFICADOS

                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(30) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION30 (va_Resumen);
                PR_REVISION31 (va_Resumen);
                PR_REVISION32 (va_Resumen);
                PR_REVISION33 (va_Resumen);
                PR_REVISION34 (va_Resumen);
                PR_REVISION35 (va_Resumen);
                PR_REVISION36 (va_Resumen);
                PR_REVISION37 (va_Resumen);
                PR_REVISION38 (va_Resumen);
                PR_REVISION39 (va_Resumen);

        --REVISIONES EN SOCIOS
                cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'-------(40) FECHA-HORA: '||To_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));
                PR_REVISION40 (va_Resumen);
                PR_REVISION41 (va_Resumen);
                PR_REVISION42 (va_Resumen);
                PR_REVISION43 (va_Resumen);
                PR_REVISION44 (va_Resumen);
                PR_REVISION45 (va_Resumen);
                PR_REVISION46 (va_Resumen);

                --NO REALIZAR ESTA VALIDACI¿N LOS PRIMEROS DIAS DEL MES
                --TASA AFCOOP
                if TO_CHAR(SYSDATE,'DD')>=va_DiaReviSaldoAFCOOP then
                    PR_REVISION47 (va_Resumen);
                    PR_REVISION48 (va_Resumen);
                end if;
                PR_REVISION49 (va_Resumen);  --REVISION GENERACI¿N TASA AFCOOP

        --REVISIONES EN SALDOS MENSUALES
                --NO REALIZAR ESTA VALIDACI¿N LOS PRIMEROS DIAS DEL MES
                --RESUMEN DE SALDOS MENSUALES
                if TO_CHAR(SYSDATE,'DD')>=va_DiaReviSaldoAFCOOP then
                    PR_REVISION50 (va_Resumen);
                end if;
                PR_REVISION51 (va_Resumen);
                PR_REVISION52 (va_Resumen);
                PR_REVISION53 (va_Resumen);
                PR_REVISION54 (va_Resumen);
                PR_REVISION55 (va_Resumen);
                PR_REVISION56 (va_Resumen);
                PR_REVISION57 (va_Resumen);
                PR_REVISION58 (va_Resumen);
                PR_REVISION59 (va_Resumen);

        --MENSAJE
            cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'*** Revisi¿n realizada en el paquete fapq_certapor.PR_REVISION ***');

        --FINALIZAR EL SEM¿FORO
            cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,'Revisi¿n finalizada.');
            cbpq_coblinweb_ResuProc.pr_Mens(va_Resumen,' ');

        --PONE EL SEMAFORO EN VERDE
            cbpq_coblinweb_resuproc.PR_SETSEMAFOROENVERDE (va_cdSema);

        --FINALIZA EL PROCESO Y ENVIA MAIL
            cbpq_coblinweb_ResuProc.pr_Mail(va_Resumen,'S');

    EXCEPTION

        WHEN OTHERS THEN
            va_dsmens := va_dsmens||'-'||SQLERRM;
            gopq_cpt.Enviar_mail('tecnologia@cre.com.bo','davidcm@cre.com.bo','Revision de Certificados',va_dsmens,null);

            --PONE EL SEMAFORO EN VERDE
            cbpq_coblinweb_ResuProc.pr_Revi(va_Resumen);
            cbpq_coblinweb_ResuProc.pr_erro(va_Resumen,va_dsMens);
            cbpq_coblinweb_resuproc.PR_SETSEMAFOROENVERDE (va_cdSema);
            cbpq_coblinweb_ResuProc.pr_Mail(va_Resumen,'S');
            --cbpq_coblinweb_ResuProc.pr_Mail(va_Resumen,'S','davidcm@cre.com.bo');
            --cbpq_coblinweb_ResuProc.pr_Mail(va_Resumen,'S','davidcm@cre.com.bo');


    END;


    PROCEDURE PR_REVISION01 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) IS

    --CUENTAS CON AFILIACION SOCIO QUE NO TIENEN CARGO POR
    --CERTIFICADO DE APORTACION

        cursor trae_cuen is

            SELECT
                NUCOMP,
                NUCUEN,
                tiafil,
                stcuen,
                stcone,
                nuclie,
                (select nusoci from scm_soci where nuclie=cu.nuclie and stsoci='A') nusoci,
                TRUNC(FCALTA) FCALTA,
                (select dscuen from soc_cuen where cdcuen=cu.cdcuen and nucomp=cu.nucomp) ticuen
            FROM
                SOM_CUEN CU
            WHERE
                TIAFIL='S' AND
                STCUEN<>'N' AND
                NUCUEN=NUCUEN+0 AND
                NOT EXISTS (SELECT
                                'X'
                            FROM
                                FAT_CARGABON CA
                            WHERE
                                CA.NUCUEN=CU.NUCUEN AND
                                CA.NUCOMP=CU.NUCOMP AND
                                CA.CDCARGABON IN (2) AND
                                CA.STREGI='R' AND
                                TICARGABON='C' AND
                                NVL(NUCAABASOC,0)=0
                            )
            ORDER BY
                NUCOMP,
                NUCUEN;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 01: CUENTAS CON AFILIACI¿N SOCIO SIN EL CARGO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCUEN   NUCOMP   FCALTA';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ============================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for cuen in trae_cuen
        loop
            va_dsmens := '   '||
                         rpad(cuen.nucuen,8)||' '||
                         rpad(cuen.nucomp,8)||' '||
                         to_char(cuen.fcalta,'DD/MM/RRRR');
            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');

    END;

    PROCEDURE PR_REVISION02 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) IS

    --CUENTAS CON MAS DE 1 CARGO 2 NO DEVUELTO

        cursor trae_cuen is

            SELECT
                NUCUEN,
                NUCOMP,
                STCUEN,
                STCONE,
                NUCLIE,
                NUSOCI,
                FCALTA,
                TICUEN,
                CTCARG2
            FROM
            (
                SELECT
                    NUCUEN,
                    NUCOMP,
                    stcuen,
                    stcone,
                    nuclie,
                    (select nusoci from scm_soci where nuclie=cu.nuclie and stsoci='A') nusoci,
                    FCALTA,
                    (select dscuen from soc_cuen where cdcuen=cu.cdcuen and nucomp=cu.nucomp) ticuen,
                    (
                        SELECT
                            COUNT(*)
                        FROM
                            FAT_CARGABON CA
                        WHERE
                            CA.NUCUEN=CU.NUCUEN AND
                            CA.NUCOMP=CU.NUCOMP AND
                            CA.CDCARGABON IN (2) AND
                            CA.TIMONE='E' AND
                            CA.STREGI='R' AND
                            TICARGABON='C' AND
                            NVL(NUCAABASOC,0)=0  --NO DEVUELTO
                            AND VAMONT IN (400,410)
                    ) CTCARG2
                FROM
                    SOM_CUEN CU
                WHERE
                    NVL(CU.NUCUEN,0)>0
            ) RE
            WHERE
                NVL(CTCARG2,0)>1     --CARGO 2 DUPLICADO
            ORDER BY
                NUCOMP,
                NUCUEN DESC;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 02: CUENTAS CON MAS DE UN CARGO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCUEN   NUCOMP   FCALTA';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ============================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for cuen in trae_cuen
        loop
            va_dsmens := '   '||
                         rpad(cuen.nucuen,8)||' '||
                         rpad(cuen.nucomp,8)||' '||
                         to_char(cuen.fcalta,'DD/MM/RRRR');
            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;


    PROCEDURE PR_REVISION11 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

        --CARGOS INVALIDOS

        cursor trae_carg is

            SELECT
                NUCARGABON,
                NUCOMP,
                NUCUEN,
                FCCARGO,
                CDCARGABON,
                TIMONE,
                TICARGABON,
                VAMONT
            FROM
                FAT_CARGABON
            WHERE
                CDCARGABON IN (1,2) AND
                STREGI='R' AND
                (
                    CDCARGABON=1 OR
                    NVL(TIMONE,'X')<>'E' OR
                    (NVL(TICARGABON,'X')='C' AND NVL(VAMONT,0)<>410)
                );

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 11: CARGOS INVALIDOS');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    CDCARG TIMOME TICARG VAMONT';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   =================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/RRRR')||' '||
                         rpad(carg.cdcargabon,6)||' '||
                         rpad(carg.timone,6)||' '||
                         rpad(carg.ticargabon,4)||' '||
                         to_char(carg.vamont,'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION12 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

        --CARGOS CONECTADOS SIN EL NUMERO DE CLIENTE
        --     O CLIENTE DISTINTO A LA CUENTA

        cursor trae_carg is

        SELECT
            *
        FROM
        (
        SELECT
            NUCUEN,
            NUCOMP,
            NUCARGABON,
            FCCARGO,
            NUCLIE,
            (SELECT CU.NUCLIE FROM SOM_CUEN CU WHERE CU.NUCOMP=CA.NUCOMP AND CU.NUCUEN=CA.NUCUEN) NUCLIECUEN,
            CDCARGABON,
            VAMONT,
            VAMONTFACT,
            STREGI,
            STFACT,
            STCOBR,
            NUSERV,
            (SELECT STSERV FROM SOT_SERV WHERE NUCOMP=CA.NUCOMP AND NUSERV=CA.NUSERV) STSERV
        FROM
            FAT_CARGABON CA
        WHERE
            CA.CDCARGABON IN (2) AND
            CA.STREGI='R' AND
            TICARGABON='C' AND
            NVL(NUCAABASOC,0)=0 AND
            NVL(NUCUEN,0)>0
        )
        WHERE
            NVL(NUCLIE,0)=0 OR
            (NVL(NUCLIE,-1)>0 AND NVL(NUCLIE,-1)<>NVL(NUCLIECUEN,-2))
        ORDER BY
            NUCOMP,
            NUCUEN DESC;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 12: NUCLIE EN NULO O DISTINTO DE LA CUENTA');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCLIE2    VAMONT  VAMONTF';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   =========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/RRRR')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucliecuen,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         to_char(NVL(carg.vamontfact,0),'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION13 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

        --NO TIENE EL NUCLIE EN CARGOS DEVUELTOS

        cursor trae_carg is

        SELECT
            R1.*,
            (SELECT MIN(NUCLIE) FROM SOE_MOVITITU WHERE NUCUEN=R1.NUCUEN AND NUSERV=R1.NUSERVDEV AND NUCOMP=R1.NUCOMP AND TIAFIL='C') NUCLIESERVDEV
        FROM
        (
            SELECT
                NUCUEN,
                NUCOMP,
                CDCARGABON,
                NUCARGABON,
                FCCARGO,
                STREGI,
                NUSERV,
                NUCLIE,
                VAMONT,
                (SELECT NUCLIE FROM FAT_CARGABON WHERE NUCARGABON=CA.NUCAABASOC AND NUCOMP=CA.NUCOMP) NUCLIEDEV,
                (SELECT NUSERV FROM FAT_CARGABON WHERE NUCARGABON=CA.NUCAABASOC AND NUCOMP=CA.NUCOMP) NUSERVDEV
            FROM
                FAT_CARGABON CA
            WHERE
                CA.CDCARGABON IN (2) AND
                CA.TIMONE='E' AND
                CA.STREGI='R' AND
                TICARGABON='C' AND
                NVL(NUCAABASOC,0)>0 AND
                NVL(NUCLIE,0)=0
        )  R1 ;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 13: NO TIENE EL NUCLIE EN CARGOS DEVUELTOS');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCLIEDEV  VAMONT NUSERV';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/RRRR')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucliedev,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         rpad(NVL(carg.nuserv,0),8);

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION14 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    -- SIN EL NUMERO DE CLIENTE EN CARGOS DESCONECTADOS FACTURADOS

        cursor trae_carg is

        SELECT
            NUCOMP,
            NUCARGABON,
            NUCUEN,
            NUCLIE,
            CDCARGABON,
            FCCARGO,
            NUSERV,
            (SELECT STSERV FROM SOT_SERV WHERE NUCOMP=CA.NUCOMP AND NUSERV=CA.NUSERV) STSERV,
            (SELECT NUCUEN FROM SOT_SERV WHERE NUCOMP=CA.NUCOMP AND NUSERV=CA.NUSERV) NUCUENSERV,
            (SELECT CL.NUCLIE FROM SOE_CLIESERV CL WHERE CL.NUCOMP=CA.NUCOMP AND CL.NUSERV=CA.NUSERV) NUCLIESERV,
            VAMONT,
            VAMONTFACT,
            STREGI,
            STFACT,
            STCOBR
        FROM
            FAT_CARGABON CA
        WHERE
            CA.CDCARGABON = 2 AND
            CA.TIMONE='E' AND
            CA.STREGI='R' AND
            TICARGABON='C' AND
            NVL(NUCUEN,0)=0 AND
            NVL(NUCLIE,0)=0 AND
            VAMONTFACT>0
        ORDER BY
            NUCOMP,
            NUCARGABON DESC;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 14: CARGOS FACTURADOS Y DESCONECTADOS SIN EL NUMERO DE CLIENTE');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCLIESERV VAMONT VAMONTFACT';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/RRRR')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nuclieserv,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         to_char(carg.vamontFACT,'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION15 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    --CARGOS NO FACTURADOS Y DESCONECTADOS SIN EL NUMERO DE CLIENTE
    --CON SERVICIOS PROCESADOS

        cursor trae_carg is

        SELECT
            *
        FROM
        (
        SELECT
            NUCOMP,
            NUCARGABON,
            NUCUEN,
            NUCLIE,
            CDCARGABON,
            FCCARGO,
            NUSERV,
            (SELECT MAX(NUCLIE) FROM SOE_CLIESERV WHERE NUSERV=CA.NUSERV AND NUCOMP=CA.NUCOMP) NUCLIESERV,
            (SELECT STSERV FROM SOT_SERV WHERE NUCOMP=CA.NUCOMP AND NUSERV=CA.NUSERV) STSERV,
            (SELECT NUCUEN FROM SOT_SERV WHERE NUCOMP=CA.NUCOMP AND NUSERV=CA.NUSERV) NUCUENSERV,
            VAMONT,
            VAMONTFACT,
            STREGI,
            STFACT,
            STCOBR
        FROM
            FAT_CARGABON CA
        WHERE
            CA.CDCARGABON IN (2) AND
            CA.TIMONE='E' AND
            CA.STREGI='R' AND
            TICARGABON='C' AND
            NVL(NUCAABASOC,0)=0 AND
            NVL(NUCUEN,0)=0 AND
            NVL(NUCLIE,0)=0 AND
            NVL(VAMONTFACT,0)=0
        )
        WHERE
            NVL(STSERV,'E') IN ('P')
        ORDER BY
            NUCOMP,
            NUCARGABON DESC;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 15: CARGOS NO FACTURADOS Y DESCONECTADOS SIN EL NUMERO DE CLIENTE');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCLIESERV VAMONT NUSERV';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/RRRR')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nuclieserv,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         rpad(NVL(carg.nuserv,0),8);

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;


    PROCEDURE PR_REVISION16 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    -- CARGOS NO FACTURADOS Y DESCONECTADOS SIN EL NUMERO DE CLIENTE
    -- CON SERVICIOS ANULADOS O RECHAZADOS

        cursor trae_carg is

        SELECT
            *
        FROM
        (
        SELECT
            NUCOMP,
            NUCARGABON,
            NUCUEN,
            NUCLIE,
            CDCARGABON,
            FCCARGO,
            NUSERV,
            (SELECT MAX(NUCLIE) FROM SOE_CLIESERV WHERE NUSERV=CA.NUSERV AND NUCOMP=CA.NUCOMP) NUCLIESERV,
            (SELECT STSERV FROM SOT_SERV WHERE NUCOMP=CA.NUCOMP AND NUSERV=CA.NUSERV) STSERV,
            (SELECT NUCUEN FROM SOT_SERV WHERE NUCOMP=CA.NUCOMP AND NUSERV=CA.NUSERV) NUCUENSERV,
            VAMONT,
            VAMONTFACT,
            STREGI,
            STFACT,
            STCOBR
        FROM
            FAT_CARGABON CA
        WHERE
            CA.CDCARGABON IN (2) AND
            CA.TIMONE='E' AND
            CA.STREGI='R' AND
            TICARGABON='C' AND
            NVL(NUCAABASOC,0)=0 AND
            NVL(NUCUEN,0)=0 AND
            NVL(NUCLIE,0)=0 AND
            NVL(VAMONTFACT,0)=0
        )
        WHERE
            NVL(STSERV,'E') IN ('A') OR
            Sopq_CtrlServ.Fn_esAtencionRechazada(NUCOMP,NUSERV)='S'
        ORDER BY
            NUCOMP,
            NUCARGABON DESC;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 16: CARGOS NO FACTURADOS Y DESCONECTADOS SIN EL NUMERO DE CLIENTE CON SERVICIOS ANULADOS O RECHAZADOS');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCLIESERV VAMONT NUSERV';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/RRRR')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nuclieserv,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         rpad(NVL(carg.nuserv,0),8);

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;


    PROCEDURE PR_REVISION17 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    --INCONSISTENCIAS ENTRE OPFACTCAAB, STFACT,STCOBR,VAMONTFACT,NUCAABASOC

        cursor trae_carg is

            SELECT
                R2.*
            FROM
            (
                SELECT
                    RE.*,
                    (CASE
                        WHEN VAMONTFACT>=410 AND STFACT='I'                     THEN 'F'
                        WHEN VAMONTFACT<410 AND STFACT='F'                      THEN 'I'
                        ELSE NULL
                     END
                    ) STFACTOK,
                    (CASE
                        WHEN TIAFIL='C' AND OPFACTCAAB='S'                      THEN 'N'
                        WHEN NVL(NUCAABASOC,0)>0 AND OPFACTCAAB='S'             THEN 'N'
                        WHEN TIAFIL='S' AND VAMONTFACT>=410 AND NVL(NUCAABASOC,0)=0 AND OPFACTCAAB='N' THEN 'S'
                        WHEN TIAFIL='S' AND VAMONTFACT< 410 AND NVL(NUCAABASOC,0)=0 AND OPFACTCAAB='N' AND ANULTIPAGO>=201701 THEN 'S'
                        ELSE NULL
                     END
                    ) OPFACTCAABOK
                FROM
                (
                    SELECT
                        NUCOMP,
                        NVL((SELECT TIAFIL FROM SOM_CUEN WHERE NUCOMP=CA.NUCOMP AND NUCUEN=CA.NUCUEN AND CA.NUCUEN>0),'C') TIAFIL,
                        (SELECT MAX(ANPAGO*100+MEPAGO) FROM FAE_CARGABON WHERE NUCOMP=CA.NUCOMP AND NUCARGABON=CA.NUCARGABON AND STREGI='R') ANULTIPAGO,
                        NUCARGABON,
                        NUCUEN,
                        NUCLIE,
                        FCCARGO,
                        VAMONT,
                        VAMONTFACT,
                        VAMONTCOBR,
                        STFACT,
                        STCOBR,
                        STREGI,
                        OPFACTCAAB,
                        NUCAABASOC
                    FROM
                        FAT_CARGABON CA
                    WHERE
                        CDCARGABON=2 AND
                        TICARGABON='C' AND
                        STREGI='R'
                ) RE
            ) R2
            WHERE
                STFACTOK  IS NOT NULL OR
                OPFACTCAABOK IS NOT NULL;


        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 17: INCONSISTENCIAS ENTRE OPFACTCAAB, STFACT,STCOBR,VAMONTFACT,NUCAABASOC');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCAABASOC VAMONT VAMONTF  OPFACT  STFACT  STCOBR';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   =============================================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/RRRR')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucaabasoc,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         rpad(carg.opfactcaab,8)||' '||
                         rpad(carg.stfact,8)||' '||
                         rpad(carg.stcobr,8);

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;


    PROCEDURE PR_REVISION20 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    --DEVOLUCIONES DUPLICADAS

        cursor trae_carg is

             SELECT
                NUCOMP,
                NUCAABASOC,
                MAX(NUCARGABON) NUCARGABON,
                MAX(FCCARGO) FCCARGO,
                MAX(NUCUEN) NUCUEN,
                MAX(NUCLIE) NUCLIE,
                MAX(NUSERV) NUSERV,
                MAX(VAMONT) VAMONT,
                COUNT(*) CANT FROM
             (
             SELECT
                NUCARGABON,NUCOMP,CDCARGABON,TICARGABON,NUCLIE,
                STREGI,FCCARGO,NUSERV,NUCUEN,NUCAABASOC,VAMONT
             FROM
                        fat_cargabon abo
                    where
                        abo.cdcargabon=2 and
                        abo.ticargabon='A' and
                        abo.stregi='R' and
                        nvl(NUCAABASOC,0)>0
            )
            GROUP BY
                NUCAABASOC,NUCOMP
            HAVING COUNT(*)>1;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 20: DEVOLUCIONES DUPLICADAS');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCAABASOC VAMONT NUSERV';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/RRRR')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucaabasoc,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         rpad(NVL(carg.nuserv,0),8);

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION21 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    --CARGOS INCORRECTOS (VER OBSERVACION)

        cursor trae_carg is

    select
        *
    from
    (
        SELECT
            car.NUCOMP,
            car.NUCARGABON,
            car.nuclie nucliecarg,
            car.fccargo,
            car.vamont,
            car.nucuen,
            car.nuserv,
            car.NUCAABASOC nucargabondev,
            abo.fccargo fcdevo,
            abo.vamont vamontdev,
            abo.nucuen nucuendev,
            abo.nuclie nuclie,
            abo.NUCAABASOC nucaabasocdev,
            (case
                when abo.nucargabon is null then 'DEVOLUCION NO EXISTE'
                when abo.cdcargabon<>2 then 'DEVOLUCION NO ES UN CARGO 2'
                when abo.ticargabon<>'A' then 'NO ES UNA DEVOLUCION'
                when nvl(abo.nucuen,0)<>nvl(car.nucuen,0) then 'DEVOLUCION EN DIFERENTE CUENTA'
                when nvl(abo.nuclie,nvl(car.nuclie,0))<>nvl(car.nuclie,0) then 'DEVOLUCION EN DIFERENTE CLIENTE'
                when nvl(car.vamontfact,0)<>nvl(abo.vamont,-1)  and nvl(car.vamontfact,-1)<410  then 'ABONO CON MONTO INCORRECTO'
                when abo.cdcargabon not in (1,2) then 'NO ES UNA DEVOLUCION DE CERTIFICADO DE APORTACION'
                when abo.timone='N' then 'ESTA EN MONEDA NACIONAL'
                when abo.stregi='A' then 'ABONO ANULADO'
                when abo.cdcargabon = (1) then 'ASOCIADO A LA DEVOLUCION 1'
                --when abo.vamont not in (10,40,64.08,400,410) then 'MONTO INCORRECTO'
                when abo.opfactcaab='S' then 'SE SIGUE FACTURANDO'
                when nvl(car.nucaabasoc,-1)<>nvl(abo.nucargabon,-2) then 'ABONO MAL RELACIONADO'
                end
            ) obs
        from
            fat_cargabon abo,
            fat_cargabon car
        where
            car.cdcargabon in (2) and
            car.ticargabon='C' and
            car.stregi='R' and
            nvl(car.nucaabasoc,-1)>0 and
            abo.nucargabon (+) = car.nucaabasoc and
            abo.nucomp (+) = car.nucomp
        )
        WHERE
            OBS IS NOT NULL
        ORDER BY
            nucomp,
            nucuen desc;

        cursor trae_inco is
            select
                *
            from
            (
                select
                    nucargabon,
                    nucomp,
                    nucuen,
                    fccargo,
                    nuclie,
                    ticargabon,
                    nucaabasoc,
                    vamont,
                    nuserv,
                    'CARGO/ABONO MAL RELACIONADO' obs,
                    (select count(*)   from fat_cargabon c2 where c2.cdcargabon=2 and c2.stregi='R' AND c2.nucargabon=c1.nucaabasoc and c2.nucomp=c1.nucomp) ct,
                    (select max(nucargabon) from fat_cargabon c2 where c2.cdcargabon=2 and c2.stregi='R' AND c2.nucargabon=c1.nucaabasoc and c2.nucomp=c1.nucomp) nucaabasoc2,
                    (select max(nucaabasoc) from fat_cargabon c2 where c2.cdcargabon=2 and c2.stregi='R' AND c2.nucargabon=c1.nucaabasoc and c2.nucomp=c1.nucomp) nucargabon2,
                    (select max(ticargabon) from fat_cargabon c2 where c2.cdcargabon=2 and c2.stregi='R' AND c2.nucargabon=c1.nucaabasoc and c2.nucomp=c1.nucomp) ticargabon2
                from
                    fat_cargabon c1
                where
                    cdcargabon=2 and
                    stregi='R' and
                    nvl(c1.nucaabasoc,-1)>0
            )
            where
                nucargabon<>nvl(nucargabon2,-1) or
                nucaabasoc<>nvl(nucaabasoc2,-1) or
                ticargabon=nvl(ticargabon2,'X') or
                ct<>1;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 21: CARGOS INCORRECTOS (VER OBSERVACION)');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCAABASOC VAMONT NUSERV OBSERVACION';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ===================================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/RRRR')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucargabondev,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         rpad(NVL(carg.nuserv,0),8)||' '||
                         carg.obs;

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        for carg in trae_inco
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/RRRR')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucaabasoc,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         rpad(NVL(carg.nuserv,0),8)||' '||
                         carg.obs;

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION22 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    --ABONOS INCORRECTOS (VER OBSERVACION)

        cursor trae_carg is

        SELECT * FROM
        (
        SELECT
            abo.NUCOMP,
            abo.NUCARGABON,
            abo.fccargo,
            abo.nuserv,
            abo.nuclie,
            abo.vamont vamontdev,
            abo.nucuen nucuendev,
            abo.nuclie nucliedev,
            abo.NUCAABASOC,
            car.ticargabon,
            car.nucuen,
            car.timone,
            car.vamont,
            car.stfact,
            car.cdcargabon,
            car.OPFACTCAAB,
            (case
                when nvl(abo.nucaabasoc,0)=0 then 'DEVOLUCION NO RELACIONADA'
                when car.nucargabon is null then 'CARGO NO EXISTE'
                when car.ticargabon='A' then 'NO ES UN CARGO'
                when abo.cdcargabon =1 AND
                (SELECT COUNT(*) FROM FAT_CARGABON C1 WHERE C1.NUCOMP=ABO.NUCOMP AND C1.NUCUEN=ABO.NUCUEN AND NVL(ABO.NUCUEN,0)>0 AND C1.TICARGABON='C' AND C1.CDCARGABON=2 AND C1.STREGI='R' AND C1.FCCARGO<ABO.FCCARGO)>0
                then 'ABONO TIPO 1 SIENDO QUE EXISTE TIPO 2'
                when car.nucomp=1 and car.cdcargabon=1 and nvl(car.nucuen,0)> 79509 then 'ABONO MAL ASOCIADO A CARGO 1'
                when nvl(abo.nucuen,0)<>nvl(car.nucuen,0) then 'DEVOLUCION EN DIFERENTE CUENTA'
                when car.cdcargabon not in (1,2) then 'NO ES UN CARGO DE CERTIFICADO DE APORTACION'
                when car.timone='N' then 'ESTA EN MONEDA NACIONAL'
                when car.stregi='A' then 'CARGO ANULADO'
                when car.vamont not in (10,40,64.08,400,410) then 'CARGO CON MONTO INCORRECTO'
                when abo.vamont<>nvl(car.vamontfact,-1)  and nvl(car.vamontfact,-1)<410 then 'ABONO CON MONTO INCORRECTO'
                when car.opfactcaab='S' then 'SE SIGUE FACTURANDO'
                when nvl(car.nucaabasoc,0)=0 then 'CARGO NO RELACIONADO'
                when nvl(car.nucaabasoc,-1)<>nvl(abo.nucargabon,-2) then 'CARGO MAL RELACIONADO'
                when nvl(abo.nuclie,nvl(car.nuclie,0))<>nvl(car.nuclie,0) then 'DEVOLUCION EN DIFERENTE CLIENTE'
                --when (select count(*) from fam_pagoextr m,fad_pagoextr d where d.nucargabon=abo.nucargabon and d.nucomp=abo.nucomp and m.nupagoextr=d.nupagoextr and m.nucomp=d.nucomp and m.stpago='P')>0 then 'ABONO TIENE PAGO EXTR'
                when NVL((select stserv from sot_Serv where nuserv=abo.nuserv and nucomp=abo.nucomp AND CDSERV IN ('092','054')),'X')='A' then 'ABONO CON SERVICIO ANULADO'
                when NVL((select stserv from sot_Serv where nuserv=abo.nuserv and nucomp=abo.nucomp AND CDSERV IN ('092','054')),'X') NOT IN ('P','E') then 'ABONO CON SERVICIO INCORRECTO'
                end
            ) obs
        from
            fat_cargabon car,
            fat_cargabon abo
        where
            abo.cdcargabon in (2) and
            abo.ticargabon='A' and
            abo.stregi='R' and
            car.nucargabon  (+)= abo.nucaabasoc and
            car.nucomp      (+)= abo.nucomp
        )
        WHERE
            1=1
            and OBS IS NOT NULL
        ORDER BY
            FCCARGO,
            NUCOMP,
            NUCUENDEV;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 22: ABONOS INCORRECTOS (VER OBSERVACION)');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCAABASOC VAMONT NUSERV  OBSERVACION';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   =====================================================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/RRRR')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucaabasoc,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         rpad(NVL(carg.nuserv,0),8)||' '||
                         carg.obs;

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION23 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    --SERVICIOS DE DEVOLUCION SIN ABONO

        cursor trae_carg is

        SELECT
            RE.*
        FROM
        (
            SELECT
                NUCOMP,
                NUSERV,
                CDSERV,
                TRUNC(FCREGI) FCREGI,
                CDMOTI,
                NUCUEN,
                STSERV,
                --(SELECT WM_CONCAT(NUCAABASOC) FROM FAT_CARGABON CA WHERE NUSERV=SE.NUSERV AND NUCOMP=SE.NUCOMP AND STREGI='R' AND CDCARGABON IN (1,2)) SERVCARGOS,
                --(SELECT WM_CONCAT(NUCAABASOC) FROM FAT_CARGABON CA WHERE NUSERV=SE.NUSERV AND NUCOMP=SE.NUCOMP AND STREGI='R' AND CDCARGABON IN (1,2)) SERVCARGOS,
                (SELECT LISTAGG(NUCAABASOC) WITHIN GROUP (ORDER BY NUCAABASOC) FROM FAT_CARGABON CA WHERE NUSERV=SE.NUSERV AND NUCOMP=SE.NUCOMP AND STREGI='R' AND CDCARGABON IN (1,2)) SERVCARGOS,
                sopq_descclie.fn_numero(substr(dtserv,31,8)) idcert,
                DTSERV
            FROM
                SOT_SERV SE
            WHERE
                CDSERV='092' AND
                STSERV IN ('E','P')
        ) RE
        WHERE
            SERVCARGOS IS NULL;


        va_dsMens varchar2(3000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 23: SERVICIOS DE DEVOLUCION SIN ABONO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUSERV     NUCOMP NUCUEN   FCSERVICIO DETALLE';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ===================================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nuserv,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fcregi,'DD/MM/YYYY')||' '||
                         substr(carg.dtserv,1,40);

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION24 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    --CARGOS FACTURADOS ANULADOS

        cursor trae_carg is

            SELECT
                NUCOMP,
                NUCARGABON,
                fccargo,
                nuserv,
                nuclie,
                vamont,
                vamontfact,
                nucuen,
                NUCAABASOC,
                ticargabon,
                stregi,
                stfact
                OPFACTCAAB
            FROM
                FAT_CARGABON
            WHERE
                (NUCARGABON,NUCOMP) IN
            (
                select
                    nucargabon,
                    nucomp
                from
                    far_Saldca SA
                where
                    (
                        (
                            ansald=TO_CHAR(ADD_MONTHS(SYSDATE,-2),'YYYY') and
                            mesald=TO_CHAR(ADD_MONTHS(SYSDATE,-2),'MM')
                        ) OR
                        (
                            ansald=TO_CHAR(ADD_MONTHS(SYSDATE,-1),'YYYY') and
                            mesald=TO_CHAR(ADD_MONTHS(SYSDATE,-1),'MM')
                        )
                    ) AND
                    stregi='R' AND
                    VAMONTFACT>0 AND
                    NOT EXISTS (    SELECT 'X' FROM FAT_CARGABON WHERE
                                    NUCARGABON=SA.NUCARGABON AND
                                    NUCOMP=SA.NUCOMP AND
                                    STREGI='R'
                                )
            ) AND
            VAMONTFACT>0;

        --TODOS LOS CARGOS FACTURADOS DEL MES ANTERIOR DEBEN ESTAR EN LOS SALDOS
        cursor trae_Carg2 is

            SELECT
                CAR.NUCARGABON,
                CAR.NUCOMP,
                CAR.NUCUEN,
                CAR.NUCLIE,
                CAR.FCCARGO,
                CAR.NUCAABASOC,
                CAR.VAMONT,
                CAR.VAMONTFACT,
                PAG.VAMONTCAPI
            from
                fat_cargabon car,
                fae_cargabon pag,
                fat_prefact pre
            where
                pre.fcemis >= ADD_MONTHS(TRUNC(SYSDATE-1,'MM'),-1) AND
                pre.fcemis <  ADD_MONTHS(TRUNC(SYSDATE-1,'MM'),-0) AND
                pre.nuprefact=pre.nuprefact+0 and
                pre.stregi='R' AND
                pag.nuprefact = pre.nuprefact AND
                pag.nucomp = pre.nucomp AND
                car.nucargabon=pag.nucargabon and
                car.nucomp=pag.nucomp and
                car.cdcargabon in (2) AND
                not exists (select 'x' from far_Saldca
                            where nucargabon=car.nucargabon and nucomp=car.nucomp and
                            ansald=to_char(pre.fcemis,'YYYY') AND
                            MESALD=to_char(pre.fcemis,'MM') and
                            stregi='R'
                            );


    --CARGOS FACTURADOS ANULADOS POSTERIOR AL 2018

        cursor trae_carg3 is
            select
                nucargabon,FCCARGO,nucomp,nucuen,nuclie,vamont,
                vamontfact,stregi,vamontcobr,nucaabasoc,nuserv,ticargabon,
                (select se.stserv from sot_serv se where nuserv=ca.nuserv and nucomp=ca.nucomp) stserv
            from
                fat_cargabon ca
            where
                cdcargabon=2 and ticargabon='C' and vamontfact>0 and nvl(nucaabasoc,0)=0 and
                VAMONT=410 AND
                FCCARGO>=TO_DATE('14/11/2018','DD/MM/YYYY') AND
                stregi='A';


        va_dsMens varchar2(3000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 24: CARGOS FACTURADOS ANULADOS');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCAABASOC VAMONT VAMONTFACT';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/RRRR')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucaabasoc,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         to_char(carg.vamontfact,'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;

        for carg2 in trae_Carg2
        loop
            va_dsmens := '   '||
                         rpad(carg2.nucargabon,11)||' '||
                         rpad(carg2.nucomp,5)||' '||
                         rpad(carg2.nucuen,8)||' '||
                         to_char(carg2.fccargo,'DD/MM/RRRR')||' '||
                         rpad(NVL(carg2.nuclie,0),8)||' '||
                         rpad(NVL(carg2.nucaabasoc,0),8)||' '||
                         to_char(carg2.vamont,'9990.99')||' '||
                         to_char(carg2.vamontfact,'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;


        for carg3 in trae_Carg3
        loop
            va_dsmens := '   '||
                         rpad(carg3.nucargabon,11)||' '||
                         rpad(carg3.nucomp,5)||' '||
                         rpad(carg3.nucuen,8)||' '||
                         to_char(carg3.fccargo,'DD/MM/RRRR')||' '||
                         rpad(NVL(carg3.nuclie,0),8)||' '||
                         rpad(NVL(carg3.nucaabasoc,0),8)||' '||
                         to_char(carg3.vamont,'9990.99')||' '||
                         to_char(carg3.vamontfact,'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;

        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;


    PROCEDURE PR_REVISION25 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    --DIFERENCIA MES ANTERIOR Y MES ACTUAL

        cursor trae_carg is

            SELECT
                NUCOMP,
                NUCARGABON,
                fccargo,
                nuserv,
                nuclie,
                vamont,
                vamontfact,
                nucuen,
                NUCAABASOC,
                ticargabon,
                stregi,
                stfact
                OPFACTCAAB
            FROM
                FAT_CARGABON
            WHERE
                (NUCARGABON,NUCOMP)
                IN
                (
                select nucargabon,nucomp from far_Saldca where
                ansald=TO_CHAR(ADD_MONTHS(SYSDATE,-2),'YYYY') and
                mesald=TO_CHAR(ADD_MONTHS(SYSDATE,-2),'MM') and
                stregi='R'
                MINUS
                select nucargabon,nucomp from far_Saldca where
                ansald=TO_CHAR(ADD_MONTHS(SYSDATE,-1),'YYYY') and
                mesald=TO_CHAR(ADD_MONTHS(SYSDATE,-1),'MM') and
                stregi='R'
                ) and
                nvl(vamontfact,0)>0
            ORDER BY
                NUCOMP,
                NUCARGABON;


        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 25: DIFERENCIA MES ANTERIOR Y MES ACTUAL');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCAABASOC VAMONT VAMONTFACT';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/YYYY')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucaabasoc,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         to_char(carg.vamontfact,'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;


    PROCEDURE PR_REVISION30 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    --CERTIFICADOS NO RELACIONADOS A UN CARGO
    --SI EL CARGO EXISTE (MONTO CERO Y ANULADO), ES UN WARNINGS.
    --SI EL CARGO EXISTE (MONTO FACTURADO MAYOR A CERO) ES UN ERROR.


        cursor trae_cert is

        SELECT
            IDCERT,
            NUSECUCERT,
            NUCARGABON,
            (SELECT 'STREGI:'||STREGI||'-NUCUEN'||NUCUEN||'-NUCOMP'||NUCOMP||'-NUSERV'||NUSERV||'-NUCLIE'||NUCLIE||'-VAMONTFACT'||VAMONTFACT
            FROM FAT_CARGABON WHERE NUCOMP=CE.NUCOMP AND NUCARGABON=CE.NUCARGABON) DATOCARG,
            NUCOMP,
            NUCLIE,
            NUCUEN,
            STREGI,
            FCREGI,
            FCMODI
        FROM
            SCM_CERT CE
        WHERE
            CE.STREGI='R' AND
            NOT EXISTS (
                            SELECT 'X' FROM
                            FAT_CARGABON CA
                            WHERE
                                NUCARGABON=NVL(CE.NUCARGABON,-1) AND
                                NUCOMP=NVL(CE.NUCOMP,0) AND
                                TICARGABON='C' AND
                                TIMONE='E' AND
                                CA.STREGI='R' AND
                                VAMONT IN (410) AND
                                CDCARGABON =2
                        );

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 30: CERTIFICADOS NO RELACIONADOS A UN CARGO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCERT     NUCLIE   IDCERT     DATOCARG';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for cert in trae_cert
        loop
            va_dsmens := '   '||
                         rpad(cert.nucargabon,11)||' '||
                         rpad(cert.nucomp,5)||' '||
                         rpad(cert.nucuen,8)||' '||
                         to_char(cert.fcregi,'DD/MM/YYYY')||' '||
                         rpad(NVL(cert.nuclie,0),8)||' '||
                         rpad(NVL(cert.idcert,0),8)||' '||
                         cert.DATOCARG;

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION31 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    --CARGOS NO RELACIONADOS A CERTIFICADOS

     cursor trae_carg is

        SELECT
            *
        FROM
        (
        SELECT
            NUCOMP,
            NUCARGABON,
            CDCARGABON,
            NUCUEN,
            NUSERV,
            FCCARGO,
            NUCAABASOC,
            (SELECT STSERV FROM SOT_SERV SO WHERE SO.NUSERV=CA.NUSERV AND SO.NUCOMP=CA.NUCOMP) STSERV,
            NUCLIE,
            (select nuclie from soe_clieserv where nuserv=ca.nuserv and nucomp=ca.nucomp) nuclie2,
            (select listagg(idcert||'-'||nucargabon||STCERT) within group (order by idcert) from scm_Cert CE where CE.STREGI='R' AND nuclie=ca.nuclie and fcregi>=ca.fcregi) idcert,
--            (select wm_concat(idcert||'-'||CE.nucargabon||CE.STCERT||c1.stregi)
            (select listagg(idcert||'-'||CE.nucargabon||CE.STCERT||c1.stregi) within group (order by idcert)
            from
                FAT_cARGABON C1,
                scm_Cert CE
            where
                CE.STREGI='R' AND
                CE.nuclie=ca.nuclie and
                CE.fcregi>=ca.fcregi AND
                C1.NUCARGABON=CE.NUCARGABON AND
                C1.NUCOMP=CE.NUCOMP
                ) CARGODEV,
            VAMONT,
            VAMONTFACT,
            STREGI,
            STFACT,
            FCREGI,
            FCMODI
        FROM
            FAT_CARGABON CA
        WHERE
            CDCARGABON=2 AND
            TICARGABON='C' AND
            STREGI='R' AND
            NOT EXISTS (
                            SELECT 'X' FROM SCM_CERT CE
                            WHERE
                            CE.STREGI='R' AND
                            CE.NUCARGABON=CA.NUCARGABON AND
                            CE.NUCOMP=CA.NUCOMP
                        ) AND
            (
                NVL(VAMONTFACT,0)>0 OR
                NVL((SELECT STSERV FROM SOT_SERV SO WHERE SO.NUSERV=CA.NUSERV AND SO.NUCOMP=CA.NUCOMP),'A') IN ('P','A')
            )
        )
        ORDER BY
            FCREGI DESC;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 31: CARGOS NO RELACIONADOS A CERTIFICADOS');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCAABASOC VAMONT VAMONTFACT';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/YYYY')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucaabasoc,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         to_char(carg.vamontfact,'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;


    PROCEDURE PR_REVISION32 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    --CERTIFICADOS QUE APUNTAN A UN MISMO CARGO Y ABONO

     cursor trae_carg is

        SELECT
            RE.*,
            SUBSTR((SELECT LISTAGG(NUCUEN) WITHIN GROUP (ORDER BY NUCUEN) FROM SCM_CERT CE WHERE CE.STREGI='R' AND NUCOMP=RE.NUCOMP AND NUCARGABON=RE.NUCARGABON),1,100) CUENTAS,
            SUBSTR((SELECT LISTAGG(IDCERT) WITHIN GROUP (ORDER BY IDCERT) FROM SCM_CERT CE WHERE CE.STREGI='R' AND NUCOMP=RE.NUCOMP AND NUCARGABON=RE.NUCARGABON),1,100) CERTIFICADOS
        FROM
        (
            SELECT
                NUCOMP,
                NUCARGABON,
                MAX(IDCERT) IDCERT1,
                (SELECT STREGI FROM FAT_CARGABON  WHERE NUCARGABON=CE.NUCARGABON AND NUCOMP=CE.NUCOMP) STREGICARG,
                COUNT(*) CANT
            FROM
                SCM_CERT CE
            WHERE
                NVL(NUCARGABON,0)>0
                AND STREGI='R'
            GROUP BY
                NUCOMP,
                NUCARGABON
            HAVING
                COUNT(*)>1
        ) RE
            ORDER BY
            NUCOMP,
            NUCARGABON;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 32: CERTIFICADOS QUE APUNTAN A UN MISMO CARGO Y ABONO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP STREGI    CANT   CERTIFICADOS';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.stregicarg,8)||' '||
                         rpad(NVL(carg.cant,0),8)||' '||
                         carg.certificados;

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION33 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

        --CERTIFICADOS SIN NUCLIE

        cursor trae_cert is

        SELECT
            IDCERT,
            NUCUEN,
            NUCOMP,
            NUCLIE,
            NUCARGABON,
            FCREGI
        FROM
            SCM_CERT
        WHERE
            NVL(NUCLIE,0)=0 AND
            STREGI='R';


        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 33: CERTIFICADOS SIN CLIENTE');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCERT     NUCLIE   IDCERT     ';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for cert in trae_cert
        loop
            va_dsmens := '   '||
                         rpad(cert.nucargabon,11)||' '||
                         rpad(cert.nucomp,5)||' '||
                         rpad(cert.nucuen,8)||' '||
                         to_char(cert.fcregi,'DD/MM/YYYY')||' '||
                         rpad(NVL(cert.nuclie,0),8)||' '||
                         rpad(NVL(cert.idcert,0),8);

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION34 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

        --CLIENTE O CUENTA DEL CERTIFICADO INCONSISTENTES CON CARGOS

        cursor trae_cert is

        SELECT
            *
        FROM
        (
            SELECT
                CE.IDCERT,
                CE.NUCARGABON,
                CE.NUCOMP,
                CE.STCERT,
                CE.NUCUEN,
                CE.NUCLIE,
                CE.FCREGI,
                CE.FCMODI,
                (SELECT NUCUEN      FROM FAT_CARGABON WHERE NUCARGABON=CE.NUCARGABON AND NUCOMP=CE.NUCOMP AND CDCARGABON=2 AND TICARGABON='C' AND STREGI='R') NUCUENCARG,
                (SELECT NUCLIE      FROM FAT_CARGABON WHERE NUCARGABON=CE.NUCARGABON AND NUCOMP=CE.NUCOMP AND CDCARGABON=2 AND TICARGABON='C' AND STREGI='R') NUCLIECARG,
                (SELECT FCMODI      FROM FAT_CARGABON WHERE NUCARGABON=CE.NUCARGABON AND NUCOMP=CE.NUCOMP AND CDCARGABON=2 AND TICARGABON='C' AND STREGI='R') FCMODICARG
            FROM
                SCM_CERT CE
            WHERE
                NVL(NUCARGABON,0)>0 AND
                STREGI='R'
        )
        WHERE
            NVL(NUCLIE,-1)<>NVL(NUCLIECARG,-2) OR
            NVL(NUCUEN,-1)<>NVL(NUCUENCARG,-2);


        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 34: CLIENTE DEL CERTIFICADO INCONSISTENTE CON EL CARGO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCMODI     NUCLIE   IDCERT     ';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for cert in trae_cert
        loop
            va_dsmens := '   '||
                         rpad(cert.nucargabon,11)||' '||
                         rpad(cert.nucomp,5)||' '||
                         rpad(cert.nucuen,8)||' '||
                         to_char(NVL(cert.fcmodi,cert.fcregi),'DD/MM/YYYY')||' '||
                         rpad(NVL(cert.nuclie,0),8)||' '||
                         rpad(NVL(cert.idcert,0),8);

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION35 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

        --ESTADO DEL CERTIFICADO

        cursor trae_cert is

                SELECT
                    *
                FROM
                (
                    SELECT
                        CE.IDCERT,
                        CE.NUCOMP,
                        CE.NUCARGABON,
                        CE.NUCUEN,
                        CE.NUSECUCERT,
                        CE.STCERT,
                        (CASE
                            WHEN NVL(NUCAABASOC,0)>0 THEN 'DEV'
                            WHEN NVL(VAMONTCOBR,0)=0 THEN 'SUS'
                            WHEN NVL(VAMONTCOBR,0)<410 THEN 'PEN'
                            ELSE 'EMI'
                         END) STCERTOK,
                        CA.VAMONT,
                        CA.NUCLIE,
                        CA.VAMONTCOBR,
                        CA.FCCARGO,
                        CA.STREGI,
                        CA.NUCAABASOC,
                        CA.CDCARGABON,
                        CA.STFACT,
                        CA.STCOBR,
                        CA.FCREGI,
                        CA.FCMODI
                    FROM
                        FAT_CARGABON CA,
                        SCM_CERT CE
                    WHERE
                        NVL(CE.NUCARGABON,0)>0
                        AND CE.STREGI='R' AND
                        CA.NUCARGABON=CE.NUCARGABON AND
                        CA.NUCOMP=CE.NUCOMP
                )
            WHERE
                STCERT<>STCERTOK;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 35: ESTADO DEL CERTIFICADO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCMODI     NUCLIE   IDCERT   STCERT STCERTOK  ';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for cert in trae_cert
        loop
            va_dsmens := '   '||
                         rpad(cert.nucargabon,11)||' '||
                         rpad(cert.nucomp,5)||' '||
                         rpad(cert.nucuen,8)||' '||
                         to_char(NVL(cert.fcmodi,cert.fcregi),'DD/MM/YYYY')||' '||
                         rpad(NVL(cert.nuclie,0),8)||' '||
                         rpad(NVL(cert.idcert,0),8)||' '||
                         rpad(cert.stcert,8)||' '||
                         rpad(cert.stcertok,8);

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION36 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
        --CERTIFICADO DEVUELTO CON CARGO NO DEVUELTO

        cursor trae_cert is

        SELECT
            *
        FROM
        (
            SELECT
                CE.IDCERT,
                CE.NUCARGABON,
                CE.STCERT,
                CE.NUCUEN,
                CE.NUCLIE,
                CE.NUCOMP,
                CE.FCREGI,
                CE.FCMODI,
                (SELECT NUCAABASOC      FROM FAT_CARGABON WHERE NUCARGABON=CE.NUCARGABON AND NUCOMP=CE.NUCOMP AND CDCARGABON=2 AND TICARGABON='C' AND STREGI='R') NUCAABASOC
            FROM
                SCM_CERT CE
            WHERE
                CE.STREGI='R' AND
                CE.STCERT='DEV'
        )
        WHERE
            NUCAABASOC IS NULL;



        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 36: CERTIFICADO DEVUELTO CON CARGO NO DEVUELTO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCMODI     NUCLIE   IDCERT     ';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for cert in trae_cert
        loop
            va_dsmens := '   '||
                         rpad(cert.nucargabon,11)||' '||
                         rpad(cert.nucomp,5)||' '||
                         rpad(cert.nucuen,8)||' '||
                         to_char(NVL(cert.fcmodi,cert.fcregi),'DD/MM/YYYY')||' '||
                         rpad(NVL(cert.nuclie,0),8)||' '||
                         rpad(NVL(cert.idcert,0),8);

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION37 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    --CARGO DEVUELTO CON CERTIFICADO NO DEVUELTO

     cursor trae_carg is

        SELECT
            *
        FROM
        (
            SELECT
                NUCARGABON,
                NUCOMP,
                NUCUEN,
                FCCARGO,
                NUCLIE,
                NUCAABASOC,
                VAMONT,
                VAMONTFACT,
                FCMODI,
                (SELECT LISTAGG(IDCERT) WITHIN GROUP (ORDER BY IDCERT) FROM SCM_CERT CE WHERE CE.NUCARGABON=CA.NUCARGABON AND CE.NUCOMP=CA.NUCOMP AND CE.STREGI='R') IDCERT,
                (SELECT MAX(STCERT) FROM SCM_CERT CE WHERE CE.NUCARGABON=CA.NUCARGABON AND CE.NUCOMP=CA.NUCOMP AND CE.STREGI='R') STCERT
            FROM
                FAT_CARGABON CA
            WHERE
                CDCARGABON=2 AND
                TICARGABON='C' AND
                NVL(NUCAABASOC,0)>0 AND
                STREGI='R'
        )
        WHERE
            NVL(STCERT,'X')<>'DEV';


        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 37: CARGO DEVUELTO CON CERTIFICADO NO DEVUELTO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCAABASOC VAMONT VAMONTFACT';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/YYYY')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucaabasoc,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         to_char(carg.vamontfact,'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION38 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    BEGIN
        NULL;
    END;

    PROCEDURE PR_REVISION39 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    BEGIN
        NULL;
    END;

    PROCEDURE PR_REVISION40 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

    --SOCIOS DUPLICADOS

     cursor trae_socio is

        SELECT NUCLIE,COUNT(*) CANT,MIN(NUCOMP) NUCOMP,MAX(NUSOCI) NUSOCI,MAX(FCREGI) FCREGI,MAX(FCALTA) FCALTA,MIN(STSOCI) STSOCI
        FROM SCM_SOCI SO
        GROUP BY NUCLIE
        HAVING COUNT(*)>1;


        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 40: SOCIOS DUPLICADOS');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUSOCI  NUCLIE  NUCOMP FCREGI     FCALTA     STSOCI';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for socio in trae_socio
        loop
            va_dsmens := '   '||
                         rpad(socio.NUSOCI,11)||' '||
                         rpad(socio.nuclie,8)||' '||
                         rpad(socio.nucomp,5)||' '||
                         to_char(socio.fcregi,'DD/MM/YYYY')||' '||
                         socio.stsoci;

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION41 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    --CARGOS CON COBRO SIN SOCIO ACTIVO

     cursor trae_carg is

        SELECT
            *
        FROM
        (
            SELECT
                NUCOMP,
                NUCARGABON,
                NUCUEN,
                NUCLIE,
                NUSERV,
                VAMONT,
                VAMONTFACT,
                VAMONTCOBR,
                nucaabasoc,
                STREGI,
                FCCARGO,
                FCREGI,
                FCMODI,
                (SELECT STREGI||STSOCI FROM SCM_SOCI SO WHERE SO.NUCLIE=CA.NUCLIE) STSOCI,
                (SELECT NUSOCI FROM SCM_SOCI SO WHERE SO.NUCLIE=CA.NUCLIE) NUSOCI,
                (SELECT STSERV FROM SOT_SERV SO WHERE SO.NUSERV=CA.NUSERV AND SO.NUCOMP=CA.NUCOMP AND NVL(CA.NUSERV,0)>0) STSERV
            FROM
                FAT_CARGABON CA
            WHERE
                NVL(NUCAABASOC,0)=0 AND
                CDCARGABON=2 AND
                TICARGABON='C' AND
                STREGI='R'
                AND NVL(VAMONTCOBR,0)>0
        ) CA
        WHERE
            --NUCARGABON=9534448 AND
            NOT EXISTS (SELECT 'X' FROM SCM_SOCI SO
            WHERE SO.NUCLIE=CA.NUCLIE AND SO.STSOCI='A' AND SO.STREGI='R')
        ORDER BY NUCLIE;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 41: CARGOS CON COBRO SIN SOCIO ACTIVO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCAABASOC VAMONT VAMONTCOBR';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/YYYY')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucaabasoc,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         to_char(carg.vamontcobr,'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION42 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    --CARGOS DEVUELTO SIN SOCIO

     cursor trae_carg is

        SELECT
            *
        FROM
        (
            SELECT
                NUCOMP,
                NUCARGABON,
                NUCUEN,
                NUCLIE,
                NUSERV,
                VAMONTFACT,
                STREGI,
                VAMONT,
                VAMONTCOBR,
                nucaabasoc,
                FCREGI,
                FCCARGO,
                FCMODI,
                (SELECT STREGI||STSOCI FROM SCM_SOCI SO WHERE SO.NUCLIE=CA.NUCLIE) STSOCI,
                (SELECT NUSOCI FROM SCM_SOCI SO WHERE SO.NUCLIE=CA.NUCLIE) NUSOCI,
                (SELECT STSERV FROM SOT_SERV SO WHERE SO.NUSERV=CA.NUSERV AND SO.NUCOMP=CA.NUCOMP AND NVL(CA.NUSERV,0)>0) STSERV
            FROM
                FAT_CARGABON CA
            WHERE
                NVL(NUCAABASOC,0)>0 AND
                CDCARGABON=2 AND
                TICARGABON='C' AND
                STREGI='R'
        ) CA
        WHERE
            --NUCARGABON=5135103
            NOT EXISTS (SELECT 'X' FROM SCM_SOCI SO
            WHERE SO.NUCLIE=CA.NUCLIE AND
            SO.STREGI='R')
        ORDER BY NUCLIE;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 42: CARGOS DEVUELTO SIN SOCIO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCCARGO    NUCLIE   NUCAABASOC VAMONT VAMONTCOBR';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fccargo,'DD/MM/YYYY')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucaabasoc,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         to_char(carg.vamontcobr,'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION43 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
        --CERTIFICADO SIN SOCIO

        cursor trae_cert is

        SELECT
            *
        FROM
        (
            SELECT
                IDCERT,
                NUCARGABON,
                NUCUEN,
                NUCOMP,
                NUCLIE,
                STCERT,
                (SELECT STREGI||STSOCI FROM SCM_SOCI SO WHERE SO.NUCLIE=CE.NUCLIE) STSOCI,
                (SELECT VAMONTFACT FROM FAT_CARGABON CA WHERE CA.NUCOMP=CE.NUCOMP AND CA.NUCARGABON=CE.NUCARGABON) VAMONTFACT,
                (SELECT VAMONTCOBR FROM FAT_CARGABON CA WHERE CA.NUCOMP=CE.NUCOMP AND CA.NUCARGABON=CE.NUCARGABON) VAMONTCOBR,
                (SELECT NUSERV     FROM FAT_CARGABON CA WHERE CA.NUCOMP=CE.NUCOMP AND CA.NUCARGABON=CE.NUCARGABON) NUSERV,
                (SELECT STSERV FROM SOT_SERV SO,FAT_CARGABON CA WHERE CA.NUCOMP=CE.NUCOMP AND CA.NUCARGABON=CE.NUCARGABON AND SO.NUSERV=CA.NUSERV AND SO.NUCOMP=CA.NUCOMP) STSERV,
                STREGI,
                FCREGI,
                FCMODI
            FROM
                SCM_CERT CE
            WHERE
                STREGI='R' AND
                STCERT NOT IN ('DEV','SUS') AND
                NOT EXISTS (SELECT 'X' FROM SCM_SOCI SO
                WHERE SO.NUCLIE=CE.NUCLIE AND SO.STREGI='R' AND SO.STSOCI='A')
        )
        WHERE
            (
                NVL(STSERV,'A') IN ('P','A')
                OR NVL(VAMONTFACT,0)>0
            );



        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 43: CERTIFICADO SIN SOCIO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCMODI     NUCLIE   IDCERT     ';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for cert in trae_cert
        loop
            va_dsmens := '   '||
                         rpad(cert.nucargabon,11)||' '||
                         rpad(cert.nucomp,5)||' '||
                         rpad(cert.nucuen,8)||' '||
                         to_char(NVL(cert.fcmodi,cert.fcregi),'DD/MM/YYYY')||' '||
                         rpad(NVL(cert.nuclie,0),8)||' '||
                         rpad(NVL(cert.idcert,0),8);

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION44 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

        --SOCIOS ACTIVOS SIN CARGO COBRADO

        Cursor trae_socio is

        SELECT
            *
        FROM
        (
            SELECT
                NUSOCI,
                NUCLIE,
                (
                    SELECT
                        MAX(NUCUEN) STCUEN
                    FROM
                        FAT_CARGABON CA
                    WHERE
                        CA.NUCLIE=SO.NUCLIE AND
                        CDCARGABON=2 AND
                        TICARGABON='C' AND
                        STREGI='R' AND
                        OPFACTCAAB='S' AND
                        NVL(CA.NUCUEN,0)>0 AND
                        NVL(NUCAABASOC,0)=0
                ) NUCUEN,
                (
                    SELECT
                        MIN(STCUEN) STCUEN
                    FROM
                        SOM_CUEN CU,
                        FAT_CARGABON CA
                    WHERE
                        CA.NUCLIE=SO.NUCLIE AND
                        CDCARGABON=2 AND
                        TICARGABON='C' AND
                        STREGI='R' AND
                        OPFACTCAAB='S' AND
                        NVL(CA.NUCUEN,0)>0 AND
                        NVL(NUCAABASOC,0)=0 AND
                        CU.NUCUEN=CA.NUCUEN AND
                        CU.NUCOMP=CA.NUCOMP
                ) STCUEN,
                (
                    SELECT
                        MAX(OPFACTCAAB)
                    FROM
                        SOM_CUEN CU,
                        FAT_CARGABON CA
                    WHERE
                        CA.NUCLIE=SO.NUCLIE AND
                        CDCARGABON=2 AND
                        TICARGABON='C' AND
                        STREGI='R' AND
                        OPFACTCAAB='S' AND
                        NVL(CA.NUCUEN,0)>0 AND
                        NVL(NUCAABASOC,0)=0 AND
                        CU.NUCUEN=CA.NUCUEN AND
                        CU.NUCOMP=CA.NUCOMP
                ) OPFACTCAAB,
                NUSERVALTA,
                NUCOMP,
                STSOCI,
                STREGI,
                FCALTA,
                FCBAJA,
                NUSERVBAJA,
                CDMOTIBAJA,
                FCREGI,
                (
                    SELECT
                        COUNT(*)
                    FROM
                        FAT_CARGABON
                    WHERE
                        NUCLIE=SO.NUCLIE AND
                        CDCARGABON=2 AND
                        TICARGABON='C' AND
                        STREGI='R' AND
                        NVL(NUCAABASOC,0)=0
                ) CANT,
                (
                    SELECT
                        SUM(VAMONTFACT)
                    FROM
                        FAT_CARGABON
                    WHERE
                        NUCLIE=SO.NUCLIE AND
                        CDCARGABON=2 AND
                        TICARGABON='C' AND
                        STREGI='R' AND
                        NVL(NUCAABASOC,0)=0
                ) VAMONTFACT,
                (
                    SELECT
                        SUM(VAMONTCOBR)
                    FROM
                        FAT_CARGABON
                    WHERE
                        NUCLIE=SO.NUCLIE AND
                        CDCARGABON=2 AND
                        TICARGABON='C' AND
                        STREGI='R' AND
                        NVL(NUCAABASOC,0)=0
                ) VAMONTCOBR
            FROM
                SCM_SOCI SO
            where
                stsoci='A' AND
                STREGI='R'
            )
        WHERE
            (
                NVL(CANT,0)=0
                OR NVL(VAMONTCOBR,0)=0
            )
            --AND ( FCALTA>'01/03/2019' OR NVL(STCUEN,'I') in ('I','N') OR NUCUEN IS NULL OR FCALTA<TRUNC(SYSDATE-180,'MM'))
        ORDER BY
            FCALTA DESC,
            FCBAJA,
            STSOCI,
            FCREGI DESC;

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 44: SOCIOS ACTIVOS SIN CARGO COBRADO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUSOCI  NUCLIE  NUCOMP FCREGI     FCALTA     STSOCI';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for socio in trae_socio
        loop
            va_dsmens := '   '||
                         rpad(socio.NUSOCI,11)||' '||
                         rpad(socio.nuclie,8)||' '||
                         rpad(socio.nucomp,5)||' '||
                         to_char(socio.fcregi,'DD/MM/YYYY')||' '||
                         socio.stsoci;

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION45 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
        --SOCIOS ACTIVOS SIN CERTIFICADO PENDIENTE O EMITIDO

        Cursor trae_socio is

        SELECT
            NUSOCI,
            NUCLIE,
            NUSERVALTA,
            NUCOMP,
            STSOCI,
            FCALTA,
            FCREGI,
            FCMODI
        FROM
            SCM_SOCI SO
        where
            stsoci='A' AND
            STREGI='R' AND
            NOT EXISTS (SELECT 'X' FROM SCM_CERT CE WHERE CE.NUCLIE=SO.NUCLIE AND STREGI='R' AND STCERT IN ('PEN','EMI'));


        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 45: SOCIOS ACTIVOS SIN CERTIFICADO PENDIENTE O EMITIDO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUSOCI  NUCLIE  NUCOMP FCREGI     FCALTA     STSOCI';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for socio in trae_socio
        loop
            va_dsmens := '   '||
                         rpad(socio.NUSOCI,11)||' '||
                         rpad(socio.nuclie,8)||' '||
                         rpad(socio.nucomp,5)||' '||
                         to_char(socio.fcregi,'DD/MM/YYYY')||' '||
                         socio.stsoci;

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION46 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
        --INTEGRIDAD EN LA FECHA DE BAJA

        Cursor trae_socio is

        SELECT * FROM SCM_SOCI WHERE
            STSOCI='B' AND
            ( FCBAJA IS NULL OR CDMOTIBAJA IS NULL)
        ORDER BY FCALTA;


        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 46: INTEGRIDAD EN LA FECHA DE BAJA');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUSOCI  NUCLIE  NUCOMP FCREGI     FCALTA     STSOCI';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for socio in trae_socio
        loop
            va_dsmens := '   '||
                         rpad(socio.NUSOCI,11)||' '||
                         rpad(socio.nuclie,8)||' '||
                         rpad(socio.nucomp,5)||' '||
                         to_char(socio.fcregi,'DD/MM/YYYY')||' '||
                         socio.stsoci;

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION47 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    --INTEGRIDAD FECHA DE ALTA CON LO ENVIADO A LA AFCOOP
    --SOCIOS DE ALTA DEL PRESENTE MES
    --EL ALTA DE UN SOCIO PUEDE DARSE POR:
        -- PAGO DE SU PRIMER CUOTA
        -- TRANSFERENCIA DE DERECHO
    --NO ENVIADO A LA AFCOOP EN EL ¿LTIMO MES Y QUE  EST¿ DE ALTA. DEBE TENER FECHA DE ALTA EN EL PRESENTE MES
    --10 SEGUNDOS

        Cursor trae_socio is

        SELECT
            r2.*,
            (SELECT listagg(NUCARGABON||'-'||NUCOMP) within group (order by NUCARGABON) FROM FAT_CARGABON WHERE NUCLIE=R2.NUCLIE AND CDCARGABON=2 AND TICARGABON='C' AND STREGI='R' AND NVL(NUCAABASOC,0)=0) NUCARGABON,
            (SELECT listagg(NUCUEN||'-'||NUCOMP)     within group (order by NUCUEN    ) FROM FAT_CARGABON WHERE NUCLIE=R2.NUCLIE AND CDCARGABON=2 AND TICARGABON='C' AND STREGI='R' AND NVL(NUCAABASOC,0)=0) NUCUEN,
            (SELECT TRUNC(MAX(FCULTIPAGO)) FROM FAT_CARGABON WHERE NUCLIE=R2.NUCLIE AND CDCARGABON=2 AND TICARGABON='C' AND STREGI='R' AND NVL(NUCAABASOC,0)=0 AND NVL(VAMONTCOBR,0)>0) FCULTIPAGO
        FROM
        (
        SELECT
            NUSOCI,
            (SELECT NUCOMP      FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) NUCOMP,
            (SELECT NUCLIE      FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) NUCLIE,
            (SELECT STSOCI      FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) STSOCI,
            (SELECT FCALTA      FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) FCALTA,
            (SELECT FCREGI      FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) FCREGI
        FROM
        (
        SELECT NUSOCI FROM SCM_SOCI WHERE STSOCI='A' AND STREGI='R'
        MINUS
        SELECT NUSOCI FROM SCT_TASAAFCO WHERE ANTASA=TO_CHAR(SYSDATE,'YYYY') AND METASA=TO_CHAR(SYSDATE,'MM') AND STREGI='R' AND VATASAAPLI>0
        ) RE
        ) R2
        WHERE
            FCALTA IS NULL OR
            FCALTA < TRUNC(SYSDATE,'MM')
        ORDER BY 3;

        va_dsMens varchar2(30000);

    BEGIN

        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 47: INTEGRIDAD FECHA DE ALTA');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUSOCI  NUCLIE  NUCOMP FCREGI     FCALTA     STSOCI';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for socio in trae_socio
        loop
            va_dsmens := '   '||
                         rpad(socio.NUSOCI,11)||' '||
                         rpad(socio.nuclie,8)||' '||
                         rpad(socio.nucomp,5)||' '||
                         to_char(socio.fcregi,'DD/MM/YYYY')||' '||
                         socio.stsoci;

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Warn(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;


    PROCEDURE PR_REVISION48 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    --INTEGRIDAD DE SOCIOS DE BAJA CON LO ENVIADO A LA AFCOOP
    --SOCIOS DE BAJA DEL PRESENTE MES
    --LA BAJA DE UN SOCIO PUEDE DARSE POR:
        -- PAGO DE SU PRIMER CUOTA
        -- TRANSFERENCIA DE DERECHO
        -- FUSION
        -- SUCESION HEREDITARIA
        -- RENUNCIA
    --ENVIADO A LA AFCOOP EN EL ¿LTIMO MES Y QUE  EST¿ DE BAJA. DEBE TENER FECHA DE BAJA EN EL PRESENTE MES
    --10 SEGUNDOS

        Cursor trae_socio is

        SELECT
            *
        FROM
        (
        SELECT
            NUSOCI,
            (SELECT NUCLIE      FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) NUCLIE,
            (SELECT FCBAJA      FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) FCBAJA,
            (SELECT CDMOTIBAJA  FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) CDMOTIBAJA,
            (SELECT NUCOMP      FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) NUCOMP,
            (SELECT STSOCI      FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) STSOCI,
            (SELECT FCALTA      FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) FCALTA,
            (SELECT FCREGI      FROM SCM_SOCI     WHERE NUSOCI=RE.NUSOCI) FCREGI,
            (SELECT DSMOTI      FROM MGC_MOTI MO,SCM_SOCI SO  WHERE NUSOCI=RE.NUSOCI AND MO.CDMOTI=SO.CDMOTIBAJA) DESCRIPCION
        FROM
        (
        SELECT NUSOCI FROM SCT_TASAAFCO WHERE ANTASA=TO_CHAR(SYSDATE,'YYYY') AND METASA=TO_CHAR(SYSDATE,'MM') AND STREGI='R' AND VATASAAPLI>0
        MINUS
        SELECT NUSOCI FROM SCM_SOCI WHERE STSOCI='A' AND STREGI='R'
        ) RE
        )
        WHERE
            FCBAJA IS NULL OR
            FCBAJA <= TRUNC(SYSDATE,'MM')
        ORDER BY 3;

        va_dsMens varchar2(30000);

    BEGIN

        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 48: INTEGRIDAD DE SOCIOS DE BAJA');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUSOCI  NUCLIE  NUCOMP FCREGI     FCALTA     STSOCI';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for socio in trae_socio
        loop
            va_dsmens := '   '||
                         rpad(socio.NUSOCI,11)||' '||
                         rpad(socio.nuclie,8)||' '||
                         rpad(socio.nucomp,5)||' '||
                         to_char(socio.fcregi,'DD/MM/YYYY')||' '||
                         socio.stsoci;

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION49 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

        VA_ANTASAACTU NUMBER    := TO_CHAR(ADD_MONTHS(SYSDATE,-0),'YYYY');
        VA_METASAACTU NUMBER    := TO_CHAR(ADD_MONTHS(SYSDATE,-0),'MM');
        VA_ANTASAANTE NUMBER    := TO_CHAR(ADD_MONTHS(SYSDATE,-1),'YYYY');
        VA_METASAANTE NUMBER    := TO_CHAR(ADD_MONTHS(SYSDATE,-1),'MM');

        Cursor trae_afcoop is

            SELECT
                *
            FROM
            (
                SELECT
                    CANTACTU,
                    CANTANTE,
                    (CASE WHEN NVL(CANTACTU,0)=0 THEN 'ERROR. NO SE HA GENERADO LA TASA AFCOOP'
                          WHEN CANTACTU-CANTANTE NOT BETWEEN -500 AND 2000 THEN 'ERROR. HAY UNA DIFERENCIA DE '|| TO_CHAR(CANTACTU-CANTANTE) ||' TASAS RESPECTO EL MES ANTERIOR'
                          WHEN ABS(((CANTACTU/CANTANTE)-1)*100)>=1 THEN 'ERROR. HAY UNA VARIACI¿N DE '|| TO_CHAR(CANTACTU-CANTANTE) ||' TASAS RESPECTO AL MES ANTERIOR'
                          ELSE 'OK'
                          END
                    ) OBS
                FROM
                (
                    SELECT
                        (SELECT COUNT(*) FROM SCT_TASAAFCO WHERE ANTASA=VA_ANTASAACTU AND METASA=VA_METASAACTU AND stregi='R' AND nvl(vatasaapli,0)>0) CANTACTU,
                        (SELECT COUNT(*) FROM SCT_TASAAFCO WHERE ANTASA=VA_ANTASAANTE AND METASA=VA_METASAANTE AND stregi='R' AND nvl(vatasaapli,0)>0) CANTANTE
                    FROM
                        DUAL
                )
            )
            WHERE
                OBS<>'OK';

        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 49: TASA AFCOOP');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   OBSERVACI¿N GENERACI¿N TASA AFCOOP';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for afcoop in trae_afcoop
        loop
            va_dsmens := '   '||afcoop.obs;

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION50 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

        PA_ANSALD NUMBER        := TO_CHAR(ADD_MONTHS(SYSDATE,-1),'YYYY');
        PA_MESALD NUMBER        := TO_CHAR(ADD_MONTHS(SYSDATE,-1),'MM');
        PA_ANSALDANTE NUMBER    := TO_CHAR(ADD_MONTHS(SYSDATE,-2),'YYYY');
        PA_MESALDANTE NUMBER    := TO_CHAR(ADD_MONTHS(SYSDATE,-2),'MM');

        CURSOR TRAE_CARG1 IS

            SELECT
                RE.*
            FROM
            (
                SELECT
                    NUCARGABON,
                    NUCOMP,
                    NUCUEN,
                    ANSALD,
                    MESALD,
                    STREGI STREGIANTE,
                    VAMONTFACT-NVL(MOCAPISUSDEVO,0) MONTOANTE,
                    (SELECT STREGI FROM FAR_SALDCA WHERE ANSALD=PA_ANSALD AND MESALD=PA_MESALD AND NUCOMP=SA.NUCOMP AND NUCARGABON=SA.NUCARGABON) STREGI,
                    (SELECT VAMONTFACT-NVL(MOCAPISUSDEVO,0) FROM FAR_SALDCA WHERE ANSALD=PA_ANSALD AND MESALD=PA_MESALD AND NUCOMP=SA.NUCOMP AND NUCARGABON=SA.NUCARGABON) MONTO,
                    (SELECT MOFACTMES FROM FAR_SALDCA WHERE ANSALD=PA_ANSALD AND MESALD=PA_MESALD AND NUCOMP=SA.NUCOMP AND NUCARGABON=SA.NUCARGABON) MOFACTMES
                FROM
                    FAR_SALDCA SA
                WHERE
                    ANSALD=PA_ANSALDANTE AND
                    MESALD=PA_MESALDANTE
            )
            RE
            WHERE
                NVL(MONTO,0)-NVL(MONTOANTE,0)<>NVL(MOFACTMES,0) OR
                (STREGI='A' AND NVL(MOFACTMES,0)>0) OR
                (STREGI='R' AND STREGIANTE='A');

        CURSOR TRAE_CARG2 IS

        SELECT
            RE.*
        FROM
        (
            SELECT
                NUCARGABON,
                NUCOMP,
                NUCUEN,
                ANSALD,
                MESALD,
                STREGI,
                VAMONTFACT-NVL(MOCAPISUSDEVO,0) MONTO,
                (SELECT STREGI FROM FAR_SALDCA WHERE ANSALD=PA_ANSALDANTE AND MESALD=PA_MESALDANTE AND NUCOMP=SA.NUCOMP AND NUCARGABON=SA.NUCARGABON) STREGIANTE,
                (SELECT VAMONTFACT-NVL(MOCAPISUSDEVO,0) FROM FAR_SALDCA WHERE ANSALD=PA_ANSALDANTE AND MESALD=PA_MESALDANTE AND NUCOMP=SA.NUCOMP AND NUCARGABON=SA.NUCARGABON) MONTOANTE,
                (SELECT MOFACTMES FROM FAR_SALDCA WHERE ANSALD=PA_ANSALD AND MESALD=PA_MESALD AND NUCOMP=SA.NUCOMP AND NUCARGABON=SA.NUCARGABON) MOFACTMES
            FROM
                FAR_SALDCA SA
            WHERE
                ANSALD=PA_ANSALD AND
                MESALD=PA_MESALD
        )
        RE
        WHERE
            NVL(MONTO,0)-NVL(MONTOANTE,0)<>NVL(MOFACTMES,0) OR
            (STREGI='A' AND NVL(MOFACTMES,0)>0) OR
            (STREGI='R' AND STREGIANTE='A');



        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 50: DIFERENCIA MES ANTERIOR Y MES ACTUAL');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN    MONT-ANTE MOFACTMES  MONT-ACTU ';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg1
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.montoante,'9990.99')||' '||
                         to_char(carg.mofactmes,'9990.99')||' '||
                         to_char(carg.monto,'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Warn(pa_Resumen,va_dsMens);
        end loop;
        for carg in trae_carg2
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.montoante,'9990.99')||' '||
                         to_char(carg.mofactmes,'9990.99')||' '||
                         to_char(carg.monto,'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Warn(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION51 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is

     --SERVICIOS DE CAMBIO DE TITULAR SIN CARGO DESCONECTADO

     cursor trae_carg is

        SELECT
            (SELECT MAX(NUCARGABON) FROM FAT_CARGABON WHERE NUCOMP=RE.NUCOMP AND NUSERV=RE.SERVSOCIO AND STREGI='A' AND TICARGABON='C' AND CDCARGABON=2) CARGOANUL,
            RE.*,
            (SELECT NUCAABASOC FROM FAT_CARGABON WHERE NUCOMP=RE.NUCOMP AND NUCARGABON=RE.NUCARGABON) NUCAABASOC,
            (SELECT VAMONT     FROM FAT_CARGABON WHERE NUCOMP=RE.NUCOMP AND NUCARGABON=RE.NUCARGABON) VAMONT,
            (SELECT VAMONTFACT FROM FAT_CARGABON WHERE NUCOMP=RE.NUCOMP AND NUCARGABON=RE.NUCARGABON) VAMONTFACT,
            (SELECT NUCLIE FROM FAT_CARGABON WHERE NUCOMP=RE.NUCOMP AND NUCARGABON=RE.NUCARGABON) NUCLIECARG,
            (SELECT OPFACTCAAB FROM FAT_CARGABON WHERE NUCOMP=RE.NUCOMP AND NUCARGABON=RE.NUCARGABON) OPFACTCAAB
        FROM
        (
            SELECT
                NUSERV,
                NUCUEN,
                (SELECT TIAFIL FROM SOM_CUEN WHERE NUCUEN=SE.NUCUEN AND NUCOMP=SE.NUCOMP) TIAFIL,
                (SELECT MIN(NUSERV) FROM SOT_SERV WHERE NUCUEN=SE.NUCUEN AND NUCOMP=SE.NUCOMP AND NUSERV>SE.NUSERV AND CDSERV='111' AND STSERV='P') SERVSOCIO,
                NUCOMP,
                CDSERV,
                CDMOTI,
                STSERV,
                FCEMIS,
                (   SELECT
                        MAX(NUCARGABON)
                    FROM
                        FAT_CARGABON
                    WHERE
                        NUCUEN=SE.NUCUEN AND
                        NUCOMP=SE.NUCOMP AND
                        CDCARGABON=2 AND
                        TICARGABON='C' AND
                        STREGI='R' AND
                        NVL(NUCAABASOC,0)=0 AND
                        FCREGI<TRUNC(FCEMIS)
                ) NUCARGABON,
                (
                    SELECT
                        MAX(NUCLIE)
                    FROM
                        SOE_MOVITITU
                    WHERE
                        NUCOMP=SE.NUCOMP AND
                        NUMOVI =(   SELECT
                                        MAX(NUMOVI)
                                    FROM
                                        SOE_MOVITITU
                                    WHERE
                                        NUCUEN=SE.NUCUEN AND
                                        NUCOMP=SE.NUCOMP AND
                                        FCFINA<SE.FCCIER)
                ) NUCLIE
            FROM
                SOT_SERV SE
            WHERE
                STSERV='P' AND
                CDSERV='117' AND
                CDMOTI NOT IN ('033','A01','A05')
                and Exists
                (select 'x'
                   From soe_clieserv x
                   where x.nuserv=se.nuserv
                     and x.nucomp=se.nucomp
                     and x.optrancert ='N'
                    )
        )    RE
        WHERE
            NUCARGABON IS NOT NULL
        ORDER BY
            FCEMIS DESC;



        va_dsMens varchar2(30000);

    BEGIN
        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 51: SERVICIOS DE CAMBIO DE TITULAR SIN CARGO DESCONECTADO');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   FCEMIS     NUCLIE   NUCAABASOC VAMONT VAMONTFACT';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop
            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         to_char(carg.fcemis,'DD/MM/YYYY')||' '||
                         rpad(NVL(carg.nuclie,0),8)||' '||
                         rpad(NVL(carg.nucaabasoc,0),8)||' '||
                         to_char(carg.vamont,'9990.99')||' '||
                         to_char(carg.vamontfact,'9990.99');

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;

    PROCEDURE PR_REVISION52 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
     --CUADRATURA DE LAS DEVOLUCIONES ONLINE

        --va_tipocamb number := 6.96;

     cursor trae_carg is

        select
            *
        from
        (
            select
                re.*,
                MGFN_CAMBDIAR(TRUNC(FCAPRO)) TIPOCAMB,
                vamontdevbs-montoliqubs montodevok,
                (case when abs(vamontfact-vamontdev)<=0.00                  THEN 'OK' ELSE 'ERROR' END) OBSDEV1, --CARGO IGUAL QUE EL ABONO
                (case when montoliqu<=vamontfact                            then 'OK' ELSE 'ERROR' END) OBSDEV2, --LIQUIDACION($US) MAYOR AL CERTIFICADO
                (case when montoliqubs<=vamontdevbs                         then 'OK' ELSE 'ERROR' END) OBSDEV3, --LIQUIDACION(BS.) MAYOR AL CERTIFICADO
                (CASE WHEN ABS(montodev-(vamontfact-montoliqu))<=0.03       THEN 'OK' ELSE 'ERROR' END) OBSDEV4, --DEVOLUCI¿N ($US) DIFERENTE AL SALDO DEL CERTIFICADO Y LA LIQUIDACION
                (case when ABS(montodevbs-(vamontdevbs-montoliqubs))<=0.00  then 'OK' ELSE 'ERROR' END) OBSDEV5, --DEVOLUCI¿N (BS.) DIFERENTE AL SALDO DEL CERTIFICADO Y LA LIQUIDACION
                (case when abs(todocusus-round(montodevbs/MGFN_CAMBDIAR(TRUNC(FCAPRO)),2))<=0.00    then 'OK' ELSE 'ERROR' END) OBSDEV6, --DEVOLUCI¿N EN DOLARES IGUAL A DEVOLUCI¿N EN BOLIVIANOS
                (case when soundex(trim(dsnomb))=soundex(trim(dsnombok))    then 'OK' ELSE 'ERROR' END) OBSDEV7,  --NOMBRE DE LA DEVOLUCION EQUIVOCADO
                (select count(*) from faw_pagoexol where nucargabon=re.abono and nucomp=re.nucomp and stpago in ('E','P','L','C')) CTDEVO
            from
            (
                select
                    cuad.idcuad,
                    cuad.FCAPRO,
                    soli.nucomp,
                    soli.nuserv,
                    serv.nucuen,
                    soli.nucargabon,
                    (select car.NUCAABASOC from fat_cargabon car where nucomp=soli.nucomp and nucargabon=soli.nucargabon) abono,
                    soli.nupagoexol,
                    (SELECT stpago from fam_pagoexol where nupagoexol=soli.nupagoexol) stpago,
                    (SELECT fcpubl from fam_pagoexol where nupagoexol=soli.nupagoexol) fcpubl,
                    (SELECT nupagoextr from fam_pagoexol where nupagoexol=soli.nupagoexol) nupagoextr,
                    (select car.vamontfact from fat_cargabon car where car.nucomp=soli.nucomp and car.nucargabon=soli.nucargabon) vamontreal,
                    (select least(car.vamontfact,410) from fat_cargabon car where car.nucomp=soli.nucomp and car.nucargabon=soli.nucargabon) vamontfact,
                    (select least(abo.vamont,410) from fat_cargabon car,fat_cargabon abo where car.nucomp=soli.nucomp and car.nucargabon=soli.nucargabon and abo.nucargabon=car.nucaabasoc and abo.nucomp=car.nucomp) vamontdev,
                    (select round(least(abo.vamont,410)*MGFN_CAMBDIAR(TRUNC(FCAPRO)),2) from fat_cargabon car,fat_cargabon abo where car.nucomp=soli.nucomp and car.nucargabon=soli.nucargabon and abo.nucargabon=car.nucaabasoc and abo.nucomp=car.nucomp) vamontdevbs,
                    (select
                            count(todocu)
                        from clw_docucons
                        where cdcuenalte=to_char(serv.nucuen) and nucomp=serv.nucomp and idserv=1 and fcpago BETWEEN NVL(FCAPRO,SYSDATE-30) AND NVL(FCAPRO,SYSDATE)+15 and NUCAJE=18293
                    ) ctfactliqu,
                    (select
                            nvl(sum(round(todocu/MGFN_CAMBDIAR(TRUNC(FCAPRO)),2)),0)
                        from clw_docucons
                        where cdcuenalte=to_char(serv.nucuen) and nucomp=serv.nucomp and idserv=1 and fcpago BETWEEN NVL(FCAPRO,SYSDATE-30) AND NVL(FCAPRO,SYSDATE)+15 and NUCAJE=18293
                    ) montoliqu,
                    (select
                            nvl(sum(todocu),0)
                        from clw_docucons
                        where cdcuenalte=to_char(serv.nucuen) and nucomp=serv.nucomp and idserv=1 and fcpago BETWEEN NVL(FCAPRO,SYSDATE-30) AND NVL(FCAPRO,SYSDATE)+15 and NUCAJE=18293
                    ) montoliqubs,
                    (select
                            nvl(sum(round(todocu/MGFN_CAMBDIAR(TRUNC(FCAPRO)),2)),0)
                        from clt_docu
                        where cdcuenalte=to_char(soli.nupagoexol) and nucomp=serv.nucomp and idserv=8
                    ) montodev,
                    (select
                            SUM(topago)
                        from faw_pagoexol
                        where tipagoexol='D' and cdcargabon=2 and nuserv=soli.nuserv and nucomp=serv.nucomp and stregi='R' and stpago in ('E','P','L','C')
                    ) todocusus,
                    (select
                            nvl(sum(todocu),0)
                        from clt_docu
                        where cdcuenalte=to_char(soli.nupagoexol) and nucomp=serv.nucomp and idserv=8
                    ) montodevbs,
                    (select
                            MAX(dsnomb)
                        from faw_pagoexol
                        where tipagoexol='D' and cdcargabon=2 and nuserv=soli.nuserv and nucomp=serv.nucomp and stregi='R' and stpago in ('E','P','L','C')
                    ) dsnomb,
                    SCPQ_DEVO.FN_NOMBRESOCIO(nusoci) dsnombok
                from
                    sot_serv serv,
                    sct_solidevo soli,
                    sct_cuaddevo cuad
                where
                    CUAD.FCAPRO>=TRUNC(SYSDATE-30,'MM') AND
                    --cuad.idcuad=92 and
                    --cuad.stcuad not in ('EMI') and
                    soli.idcuaddevo=cuad.idcuad and
                    soli.nuserv=soli.nuserv+0 and
                    soli.nucomp=soli.nucomp+0 and
                    soli.nucomp=serv.nucomp and
                    soli.nuserv=serv.nuserv and
                    serv.nucuen=serv.nucuen+0
                    --and serv.nucuen IN (33748)
                    --and nupagoexol>0
            ) re
        ) r2
        where nupagoexol is not null
        and stpago in ('E','P','L','C')
        and not(obsdev1='OK' and obsdev2='OK' and obsdev3='OK' and obsdev4='OK' and obsdev5='OK' and obsdev6='OK' and obsdev7='OK' and nvl(CTDEVO,0)=1)
        order by
        nupagoexol;




        va_dsMens varchar2(30000);
        va_Obs  varchar2(1000);

    BEGIN

        return;


        cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen,'REVISION 52: CUADRATURA DE LAS DEVOLUCIONES ONLINE');
        cbpq_coblinweb_ResuProc.pr_Proc(pa_Resumen);
        va_dsMens := '   NUCARGABON NUCOMP NUCUEN   OBSERVACION';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        va_dsMens := '   ========================================================================';
        cbpq_coblinweb_ResuProc.PR_Mens (pa_Resumen,va_dsmens);
        for carg in trae_carg
        loop

            va_obs := 'ERRO';
            IF      carg.OBSDEV1='ERROR' then
                    va_obs := 'CARGO IGUAL QUE EL ABONO';
            elsif   carg.OBSDEV2='ERROR' then
                    va_obs := 'LIQUIDACION($US) MAYOR AL CERTIFICADO';
            elsif   carg.OBSDEV3='ERROR' then
                    va_obs := 'LIQUIDACION(BS.) MAYOR AL CERTIFICADO';
            elsif   carg.OBSDEV4='ERROR' then
                    va_obs := 'DEVOLUCI¿N ($US) DIFERENTE AL SALDO DEL CERTIFICADO Y LA LIQUIDACION';
            elsif   carg.OBSDEV5='ERROR' then
                    va_obs := 'DEVOLUCI¿N (BS.) DIFERENTE AL SALDO DEL CERTIFICADO Y LA LIQUIDACION';
            elsif   carg.OBSDEV6='ERROR' then
                    va_obs := 'DEVOLUCI¿N EN DOLARES IGUAL A DEVOLUCI¿N EN BOLIVIANOS';
            elsif   carg.OBSDEV7='ERROR' then
                    va_obs := 'NOMBRE DE LA DEVOLUCION EQUIVOCADO';
            end if;

            va_dsmens := '   '||
                         rpad(carg.nucargabon,11)||' '||
                         rpad(carg.nucomp,5)||' '||
                         rpad(carg.nucuen,8)||' '||
                         va_obs;

            cbpq_coblinweb_ResuProc.pr_Revi(pa_Resumen);
            if va_obs='NOMBRE DE LA DEVOLUCION EQUIVOCADO' then
                cbpq_coblinweb_ResuProc.pr_Warn(pa_Resumen,va_dsMens);
            else
                cbpq_coblinweb_ResuProc.pr_Warn(pa_Resumen,va_dsMens);
                --cbpq_coblinweb_ResuProc.pr_Erro(pa_Resumen,va_dsMens);
            end if;
        end loop;
        cbpq_coblinweb_ResuProc.pr_Mens(pa_Resumen,' ');
    END;




    PROCEDURE PR_REVISION53 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    BEGIN
        NULL;
    END;

    PROCEDURE PR_REVISION54 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    BEGIN
        NULL;
    END;

    PROCEDURE PR_REVISION55 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    BEGIN
        NULL;
    END;

    PROCEDURE PR_REVISION56 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    BEGIN
        NULL;
    END;

    PROCEDURE PR_REVISION57 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    BEGIN
        NULL;
    END;

    PROCEDURE PR_REVISION58 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    BEGIN
        NULL;
    END;

    PROCEDURE PR_REVISION59 (pa_Resumen in out cbpq_coblinweb_ResuProc.re_Resumen) is
    BEGIN
        NULL;
    END;


    PROCEDURE PR_LIQUIDACION (
                                PA_NUCARGABON NUMBER,
                                PA_NUCOMP NUMBER,
                                PA_NUPAGOEXOL OUT NUMBER,
                                PA_ISOK OUT VARCHAR2,
                                PA_DSMENS OUT VARCHAR2,
                                PA_OPLIQUFACT VARCHAR2 DEFAULT 'S'
                            ) IS

        Cursor trae_Cargo is
            select
                nucargabon,
                nucomp,
                nuclie,
                nucuen,
                nuserv,
--                vamont,
--                least(vamontfact,410) vamontfact,
--                (vamont-least(vamontfact,410)) saldo,
                least(vamont,410) vamont,
                vamontfact,
                greatest((least(vamont,410)-vamontfact),0) saldo,
                NVL((SELECT sopq_descclie.fn_numero(NUDOCU) FROM sod_docuiden WHERE NUCLIE=ca.nuclie AND CDDOCU='CI'),
                (SELECT (case when substr(nudocu,1,2)='E-' then sopq_descclie.fn_numero(substr(NUDOCU,3)) else sopq_descclie.fn_numero(NUDOCU) end) FROM sod_docuiden WHERE NUCLIE=ca.nuclie AND CDDOCU='CIE')) CI,
                (SELECT sopq_descclie.fn_numero(max(PERS.NUDOCU)) FROM sod_docupers PERS WHERE PERS.NUCLIE=ca.nuclie AND PERS.CDDOCU='NIT' AND PERS.STREGI='R') NIT,
                --sopq_datoclie.FN_TRAENOMBRECLIENTE(nuclie) TITULAR,
                SCPQ_DEVO.FN_NOMBRESOCIO((select nusoci from scm_soci where nuclie=ca.nuclie)) TITULAR,
                (select nusoci from scm_soci so where nuclie=ca.nuclie and so.stregi='R' and stsoci='A') nusoci
            from
                fat_cargabon ca
            where
                nucargabon = PA_NUCARGABON and
                nucomp=pa_nucomp and
                stregi='R' and
                cdcargabon=2 and
                ticargabon='A';

        va_Cargo trae_Cargo%rowtype;

        Cursor trae_AFCOOP is

            SELECT
                NUCARGABON,
                NUCOMP,
                FCCARGO,
                NUCUEN,
                NUSERV,
                NUCLIE,
                VAMONT,
                VAMONTFACT,
                nvl((VAMONT-VAMONTFACT),0) SALDO,
                FCREGI,FCMODI,
                FCULTIPAGO
            FROM
                FAT_CARGABON
            WHERE
                NUCLIE=va_Cargo.nuclie AND
                CDCARGABON=283 AND
                STREGI='R' AND
                (VAMONT-VAMONTFACT)>0 ;

        Cursor trae_docuimpa (pa_nucuen number,pa_MontoMax number) is
            select
                *
            from
            (
                select
                    doc.nudocu,
                    doc.nucomp,
                    doc.andocu,
                    doc.medocu,
                    to_char(to_date(doc.andocu*100+doc.medocu,'YYYYMM'),'MM/YYYY') periodo,
                    doc.nucuen,
                    doc.todocu,
                    sum(todocu) over (order by andocu,medocu,nudocu rows unbounded preceding) todocuacum
                from
                    dct_docu doc
                where
                    PA_OPLIQUFACT = 'S' and
                    doc.nucomp = pa_nucomp and
                    doc.nucuen = pa_nucuen and
                    doc.stpago = 'I' and  --Facturas Impagas
                    doc.stfact = 'N' and --Facturacion Normal
                    -- MCRECAP puede conservar STPAGO = 'I' despues de que QASCL
                    -- confirme el pago. No reenviar un documento remoto procesado.
                    not exists (
                        select 1
                          from clt_docu docu_qascl
                         where docu_qascl.nucomp = doc.nucomp
                           and docu_qascl.idserv = 1
                           and docu_qascl.nudocu = to_char(doc.nudocu)
                           and docu_qascl.stdocu = 'PRO'
                    )
            )
            where
                -- Incluir la ultima factura cuando el acumulado coincide
                -- exactamente con el saldo disponible.
                todocuacum <= pa_MontoMax
            order by
                andocu,
                medocu,
                nudocu;

        va_saldosus number;
        va_saldobs  number;
        va_topefactbs number;
        va_limitefactbs number;
        va_nucargooriginal number;
        va_cantidad_solidevo number;
        va_idMovi   number;
        va_todocu   number;
        va_todocuSus number;
        va_nupagoextr number;
        va_dtGlos varchar2(200);
        va_opliq varchar2(1);
        va_msliq varchar2(1000);
        va_cantpagoexistente NUMBER;
        va_nupagoexistente NUMBER;
        l_efecto_externo_iniciado BOOLEAN := FALSE;

        PROCEDURE pr_abortar_si_seguro IS
        BEGIN
            IF NOT l_efecto_externo_iniciado THEN
                SCPQ_DEVO.PR_ABORTAR_LIQUIDACION(
                    pa_nucomp, pa_nucargabon, va_opliq, va_msliq);
            END IF;
        END pr_abortar_si_seguro;


    BEGIN
        --INICIALIZAR LAS VARIABLES
            pa_IsOk := 'N';
            pa_dsMens := 'Iniciando el proceso de Liquidaci¿n';

        --OBTENER DATOS DEL CARGO
            open trae_Cargo;
            fetch trae_Cargo into va_Cargo;
            close trae_Cargo;

        --VALIDACIONES
            if va_cargo.nucargabon is null then
                pa_isOk     := 'N';
                pa_dsMens   := 'Devoluci¿n no existe.';
                Return;
            end if;

            if va_cargo.titular is null then
                pa_isOk     := 'N';
                pa_dsMens   := 'Devoluci¿n no tiene relacionado una persona.';
                Return;
            end if;


            va_Cargo.ci := nvl(va_cargo.ci,va_cargo.nit);
            if va_cargo.ci is null then
                pa_isOk     := 'N';
                pa_dsMens   := 'Persona no tiene Documento de Identidad/NIT.';
                Return;
            end if;

            if va_cargo.Saldo<=0 then
                pa_isOk     := 'N';
                pa_dsMens   := 'Saldo a devolver es cero o nulo.';
                Return;
            end if;

        --LIQUIDAR DEUDA AFCOOP SI EL CLIENTE YA NO ES SOCIO
            pa_dsMens := 'Tipo de Cambio';
            va_saldosus := va_cargo.saldo;
            va_saldobs  := round(va_saldosus * MGFN_TIPOCAMB,1);

            -- El abono recibido identifica el cargo original mediante NUCAABASOC.
            -- La liquidacion solo es valida si pertenece a una solicitud registrada.
            SELECT COUNT(*), MAX(sol.nucargabon)
              INTO va_cantidad_solidevo, va_nucargooriginal
              FROM sct_solidevo sol
              JOIN fat_cargabon cargo
                ON cargo.nucomp = sol.nucomp
               AND cargo.nucargabon = sol.nucargabon
             WHERE sol.nucomp = pa_nucomp
               AND sol.stregi = 'R'
               AND cargo.nucaabasoc = pa_nucargabon;

            IF va_cantidad_solidevo <> 1 THEN
                pa_isok := 'N';
                pa_dsmens := 'El abono debe estar asociado a una unica solicitud de devolucion registrada.';
                RETURN;
            END IF;

            SELECT COUNT(DISTINCT P.Nupagoexol), MAX(P.Nupagoexol)
              INTO va_cantpagoexistente, va_nupagoexistente
              FROM Fam_Pagoexol P
             WHERE P.Nucomp = pa_nucomp
               AND P.Stregi = 'R'
               AND P.Tipagoexol = 'D'
               AND EXISTS (
                   SELECT 1
                     FROM Faw_Pagoexol D
                    WHERE D.Nupagoexol = P.Nupagoexol
                      AND D.Nucomp = pa_nucomp
                      AND D.Nucargabon = pa_nucargabon);
            IF va_cantpagoexistente = 1 THEN
                pa_nupagoexol := va_nupagoexistente;
                SCPQ_DEVO.PR_FINALIZAR_LIQUIDACION(
                    pa_nucomp, pa_nucargabon, pa_nupagoexol, va_opliq, va_msliq);
                IF va_opliq <> 'S' THEN
                    pa_isok := 'N';
                    pa_dsmens := NVL(va_msliq, 'No se pudo vincular el pago existente.');
                    RETURN;
                END IF;
                pa_isok := 'S';
                pa_dsmens := NULL;
                RETURN;
            ELSIF va_cantpagoexistente > 1 THEN
                pa_isok := 'N';
                pa_dsmens := 'Existe mas de un pago extraordinario para el abono; conciliar antes de continuar.';
                RETURN;
            END IF;

            SCPQ_DEVO.PR_INICIAR_LIQUIDACION(
                pa_nucomp, pa_nucargabon, va_opliq, va_msliq);
            IF va_opliq <> 'S' THEN
                pa_isok := 'N';
                pa_dsmens := NVL(va_msliq,
                    'La solicitud ya esta liquidandose por otra sesion.');
                RETURN;
            END IF;

            -- FN_IMTOTABS es el importe oficial que respalda la devolucion. Las
            -- facturas no pueden consumir mas que ese importe, aunque el abono
            -- tenga un saldo convertido mayor.
            va_topefactbs := sgc_so.scpq_devobs.fn_imtotabs(
                                  pa_nucomp,
                                  va_nucargooriginal
                              );
            va_limitefactbs := LEAST(va_saldobs, va_topefactbs);

            IF va_limitefactbs <= 0 THEN
                pr_abortar_si_seguro;
                pa_isok := 'N';
                pa_dsmens := 'El importe oficial disponible para liquidar facturas es cero o negativo.';
                RETURN;
            END IF;

            --TO-DO

        --LIQUIDAR FACTURAS PENDIENTES
            pa_dsMens := 'Facturas pendientes';
            for docuimpa in trae_docuimpa (va_cargo.nucuen,va_limitefactbs)
            loop
                pa_dsMens := 'Pagando factura';
                DBMS_OUTPUT.PUT_LINE('Procesando factura '||docuimpa.nudocu);
                -- Desde esta llamada el resultado remoto puede ser incierto.
                l_efecto_externo_iniciado := TRUE;
                CBPQ_COBLINWEB_WSBANCA.pr_ProcesaDocumento  (   1, --Servicio de Facturacion
                                                                docuimpa.nudocu,
                                                                docuimpa.nucomp,
                                                                '000007bcre', --nologi
                                                                null,
                                                                null,
                                                                va_idMovi,
                                                                va_todocu,
                                                                pa_dsMens,
                                                                5 --Canal de Cobro SIGECOM
                                                            );

                -- No generar la devolucion si QASCL no confirmo el pago de la
                -- factura. El pago remoto no participa de la transaccion local.
                IF pa_dsMens IS NOT NULL THEN
                    pa_isOk := 'N';
                    RETURN;
                END IF;

                if pa_dsMens is null then
                    va_saldobs  := va_saldobs - va_todocu;
                    va_todocuSus := round(va_todocu  / MGFN_CAMBDIAR,3);
                    va_saldosus  := round(va_saldobs / MGFN_CAMBDIAR,3);
                    va_dtGlos    := 'Factura pagada del periodo '||docuimpa.periodo||' por un monto de '||trim(to_char(va_todocu,'9,990.99'))||'Bs. ('|| trim(to_char(va_todocusus,'9,990.99')) ||'  $us) en el proceso de Liquidaci¿n del Certificado de Aportaci¿n.';
                    --Registrar Pago Extraordinario Antiguo
                    PR_REGISTRAPAGOEXTR (   va_cargo.nucargabon,
                                                va_cargo.nucomp,
                                                'E',--Moneda
                                                va_cargo.nucuen,
                                                null, --Nuserv,
                                                sysdate, --Fecha de Pago
                                                va_todocuSus,
                                                docuimpa.nudocu,
                                                vA_DTGLOS,
                                                va_nupagoextr,
                                                PA_ISOK,
                                               PA_DSMENS
                                               );
                    IF PA_ISOK <> 'S' OR PA_DSMENS IS NOT NULL THEN
                        RETURN;
                    END IF;
                    commit;
                end if;

                --TO-DO
                --REGISTRAR EL PAGO SCE_DEVOFACT

            end loop;

            -- El saldo definitivo se obtiene del abono despues de aplicar los
            -- pagos remotos y registrar sus pagos extraordinarios.
            -- PR_CREAPAGOEXOL emite TOPAGO con la precision propia de la moneda.
            -- Truncar al mismo nivel evita que un redondeo ascendente exceda el
            -- saldo real del abono y sea rechazado durante PR_EMITEPAGO.
            SELECT TRUNC(
                       vamont - vamontfact,
                       CASE timone
                           WHEN 'N' THEN 1
                           ELSE 2
                       END
                   )
              INTO va_saldosus
              FROM fat_cargabon
             WHERE nucomp = pa_nucomp
               AND nucargabon = pa_nucargabon
               AND cdcargabon = 2
               AND ticargabon = 'A'
               AND stregi = 'R';

            IF va_saldosus <= 0 THEN
                pr_abortar_si_seguro;
                pa_isok := 'N';
                pa_dsmens := 'El saldo definitivo del abono es cero o negativo.';
                RETURN;
            END IF;

        --GENERAR DEVOLUCI¿N EXTRAORDINARIA DEL SALDO

          pa_dsMens := 'Generando la devolucion.';
          FaPq_PagoExtr.Pr_CreaPagoExol (va_cargo.nucomp ,
                                         null ,
                                         va_cargo.nuserv ,
                                         substr(va_cargo.titular,1,60) ,
                                         va_cargo.ci,
                                         'Devoluci¿n de Saldo de Certificado de Aportaci¿n'   ,
                                         va_Cargo.nucargabon ,
                                         va_saldosus  ,
                                         PA_NUPAGOEXOL,
                                         pa_dsmens,
                                         'D' );           -- Tipo = DEVOLUCI¿N

           if pa_dsmens is not null then
               IF pa_nupagoexol IS NULL THEN
                   pr_abortar_si_seguro;
               ELSE
                   SCPQ_DEVO.PR_FINALIZAR_LIQUIDACION(
                       pa_nucomp, pa_nucargabon, pa_nupagoexol, va_opliq, va_msliq);
               END IF;
               pa_isOk := 'N';
               RETURN;
           end if;


           If pa_dsmens is not null then
             Rollback;
             pr_abortar_si_seguro;
             pa_isOk := 'N';
            Return;
          End If;

          commit;

          /*

          -- 4. Emisi¿n del Pago Extraordinario
          pa_dsMens := 'Emitiendo el pago.';
          FaPq_PagoExtr.Pr_EmitePago(pa_nupagoexol,pa_dsmens,TRUNC(SYSDATE,'DD'),TRUNC(SYSDATE+720,'DD'));
          If pa_dsmens Is Not Null Then
            Rollback;
            pa_isOk := 'N';
            Return;
          End If;

          Commit;

          */


           PR_LIQUIDACIONFIX ( PA_NUCARGABON,PA_NUCOMP,PA_NUPAGOEXOL);

           SCPQ_DEVO.PR_FINALIZAR_LIQUIDACION(
               pa_nucomp, pa_nucargabon, pa_nupagoexol, va_opliq, va_msliq);
           IF va_opliq <> 'S' THEN
               pa_isok := 'N';
               pa_dsmens := NVL(va_msliq, 'No se pudo guardar el checkpoint de liquidacion.');
               RETURN;
           END IF;

        --FINALIZANDO
            pa_IsOk := 'S';
            pa_dsMens := NULL;

    EXCEPTION
        WHEN OTHERS THEN
              Rollback;
              IF PA_NUPAGOEXOL IS NULL THEN
                  pr_abortar_si_seguro;
              ELSE
                  SCPQ_DEVO.PR_FINALIZAR_LIQUIDACION(
                      pa_nucomp, pa_nucargabon, pa_nupagoexol, va_opliq, va_msliq);
              END IF;
              pa_isOk   := 'N';
              pa_dsmens := pa_dsmens || SQLERRM ;

   END;

    PROCEDURE PR_LIQUIDACIONFIX (
                                    PA_NUCARGABON NUMBER DEFAULT NULL,
                                    PA_NUCOMP NUMBER DEFAULT NULL,
                                    PA_NUPAGOEXOL NUMBER DEFAULT NULL
                                ) IS

    va_dsmens varchar2(1000);
    --va_tipocamb number := 6.96;

    CURSOR trae_liqui is

        select
            *
        from
        (
            select
                re.*,
                MGFN_CAMBDIAR(TRUNC(FCAPRO)) TIPOCAMB,
                vamontdevbs-montoliqubs montodevok,
                (case when abs(vamontfact-vamontdev)<=0.00                  THEN 'OK' ELSE 'ERROR' END) OBSDEV1, --CARGO IGUAL QUE EL ABONO
                (case when montoliqu<=vamontfact                            then 'OK' ELSE 'ERROR' END) OBSDEV2, --LIQUIDACION($US) MAYOR AL CERTIFICADO
                (case when montoliqubs<=vamontdevbs                         then 'OK' ELSE 'ERROR' END) OBSDEV3, --LIQUIDACION(BS.) MAYOR AL CERTIFICADO
                (CASE WHEN ABS(montodev-(vamontfact-montoliqu))<=0.02       THEN 'OK' ELSE 'ERROR' END) OBSDEV4, --DEVOLUCI¿N ($US) DIFERENTE AL SALDO DEL CERTIFICADO Y LA LIQUIDACION
                (case when ABS(montodevbs-(vamontdevbs-montoliqubs))<=0.00  then 'OK' ELSE 'ERROR' END) OBSDEV5, --DEVOLUCI¿N (BS.) DIFERENTE AL SALDO DEL CERTIFICADO Y LA LIQUIDACION
                (case when abs(todocusus-round(montodevbs/MGFN_CAMBDIAR(TRUNC(FCAPRO)),2))<=0.00    then 'OK' ELSE 'ERROR' END) OBSDEV6, --DEVOLUCI¿N EN DOLARES IGUAL A DEVOLUCI¿N EN BOLIVIANOS
                (case when TRIM(dsnomb)=TRIM(dsnombok)                      then 'OK' ELSE 'ERROR' END) OBSDEV7  --NOMBRE DE LA DEVOLUCION EQUIVOCADO
            from
            (
                select
                    cuad.idcuad,
                    cuad.FCAPRO,
                    soli.nucomp,
                    soli.nuserv,
                    serv.nucuen,
                    soli.nucargabon,
                    (select car.NUCAABASOC from fat_cargabon car where nucomp=soli.nucomp and nucargabon=soli.nucargabon) abono,
                    soli.nupagoexol,
                    (SELECT pextr.stregi     from fam_pagoexol pextr where pextr.nupagoexol=soli.nupagoexol) stregiEXTR,
                    (SELECT pextr.stpago     from fam_pagoexol pextr where pextr.nupagoexol=soli.nupagoexol) stpagoEXTR,
                    (SELECT pextr.fcpubl     from fam_pagoexol pextr where pextr.nupagoexol=soli.nupagoexol) fcpublEXTR,
                    (SELECT pextr.nupagoextr from fam_pagoexol pextr where pextr.nupagoexol=soli.nupagoexol) nupagoEXTR,
                    (select car.vamontfact from fat_cargabon car where car.nucomp=soli.nucomp and car.nucargabon=soli.nucargabon) vamontreal,
                    (select least(car.vamontfact,410) from fat_cargabon car where car.nucomp=soli.nucomp and car.nucargabon=soli.nucargabon) vamontfact,
                    (select least(abo.vamont,410) from fat_cargabon car,fat_cargabon abo where car.nucomp=soli.nucomp and car.nucargabon=soli.nucargabon and abo.nucargabon=car.nucaabasoc and abo.nucomp=car.nucomp) vamontdev,
                    (select round(least(abo.vamont,410)*MGFN_CAMBDIAR(TRUNC(FCAPRO)),2) from fat_cargabon car,fat_cargabon abo where car.nucomp=soli.nucomp and car.nucargabon=soli.nucargabon and abo.nucargabon=car.nucaabasoc and abo.nucomp=car.nucomp) vamontdevbs,
                    (select
                            count(todocu)
                        from clw_docucons
                        where cdcuenalte=to_char(serv.nucuen) and nucomp=serv.nucomp and idserv=1 and fcpago BETWEEN NVL(FCAPRO,SYSDATE-30) AND NVL(FCAPRO,SYSDATE)+15 and NUCAJE=18293
                    ) ctfactliqu,
                    (select
                            nvl(sum(round(todocu/MGFN_CAMBDIAR(TRUNC(FCAPRO)),2)),0)
                        from clw_docucons
                        where cdcuenalte=to_char(serv.nucuen) and nucomp=serv.nucomp and idserv=1 and fcpago BETWEEN NVL(FCAPRO,SYSDATE-30) AND NVL(FCAPRO,SYSDATE)+15 and NUCAJE=18293
                    ) montoliqu,
                    (select
                            nvl(sum(todocu),0)
                        from clw_docucons
                        where cdcuenalte=to_char(serv.nucuen) and nucomp=serv.nucomp and idserv=1 and fcpago BETWEEN NVL(FCAPRO,SYSDATE-30) AND NVL(FCAPRO,SYSDATE)+15 and NUCAJE=18293
                    ) montoliqubs,
                    (select
                            nvl(sum(round(todocu/MGFN_CAMBDIAR(TRUNC(FCAPRO)),2)),0)
                        from clt_docu
                        where cdcuenalte=to_char(soli.nupagoexol) and nucomp=serv.nucomp and idserv=8
                    ) montodev,
                    (select
                            sum(topago)
                        from faw_pagoexol
                        where tipagoexol='D' and cdcargabon=2 and nuserv=soli.nuserv and nucomp=serv.nucomp and stregi='R'  and stpago in ('E','P','L','C')
                    ) todocusus,
                    (select
                            nvl(sum(todocu),0)
                        from clt_docu
                        where cdcuenalte=to_char(soli.nupagoexol) and nucomp=serv.nucomp and idserv=8
                    ) montodevbs,
                    (select
                            max(dsnomb)
                        from faw_pagoexol
                        where tipagoexol='D' and cdcargabon=2 and nuserv=soli.nuserv and nucomp=serv.nucomp and stregi='R' and stpago in ('E','P','L','C')
                    ) dsnomb,
                    TRIM(SCPQ_DEVO.FN_NOMBRESOCIO(nusoci)) dsnombok
                from
                    sot_serv serv,
                    sct_solidevo soli,
                    sct_cuaddevo cuad
                where
                    soli.nucargabon=nvl(pa_nucargabon,soli.nucargabon) and
                    soli.nucomp=nvl(pa_nucomp,soli.nucomp) and
                    soli.nupagoexol=nvl(pa_nupagoexol,soli.nupagoexol) and
                    soli.idcuaddevo=cuad.idcuad and
                    soli.nuserv=soli.nuserv+0 and
                    soli.nucomp=soli.nucomp+0 and
                    soli.nucomp=serv.nucomp and
                    soli.nuserv=serv.nuserv and
                    serv.nucuen=serv.nucuen+0
            ) re
        ) r2
        where
            IDCUAD=IDCUAD+0
            and not(obsdev1='OK' and obsdev2='OK' and obsdev3='OK' and obsdev4='OK' and obsdev5='OK' and obsdev6='OK' and obsdev7='OK')
        order by
            nupagoexol NULLS FIRST;

    begin

        return;
        --va_tipocamb := 6.96;
        --va_tipocamb := mgfn_tipocamb(trunc(sysdate));

        for liqui in trae_liqui
        loop
            --ACTUALIZACION DE MONTOS
            if liqui.nupagoexol is not null then
                if liqui.stpagoEXTR in ('R','E','P') and liqui.stregiEXTR='R' THEN

                    --ACTUALIZANDO LOS MONTOS A CERO
                    update fad_pagoexol set mopago=0 where nupagoexol=liqui.nupagoexol;
                    update fam_pagoexol set topago=0,imtotabs=0,fcmodi=sysdate where nupagoexol=liqui.nupagoexol;
                    update fad_pagoextr set mopago=0 where nupagoextr=liqui.nupagoextr;
                    update fam_pagoextr set vamont=0 where nupagoextr=liqui.nupagoextr;
                    update fat_cargabon set vamontfact=0 where nucargabon=liqui.abono and nucomp=liqui.nucomp;

                    if liqui.stpagoEXTR='R' then
                        FaPq_PagoExtr.Pr_EmitePago(liqui.nupagoexol,va_dsmens,TRUNC(SYSDATE,'DD'),TRUNC(SYSDATE+720,'DD'));
                        COMMIT;
                    end if;

                    --ACTUALIZANDO LOS MONTOS OK
                    update fad_pagoexol set mopago=round((liqui.vamontdevbs-liqui.montoliqubs)/liqui.tipocamb,2) where nupagoexol=liqui.nupagoexol;
                    update fam_pagoexol set topago=round((liqui.vamontdevbs-liqui.montoliqubs)/liqui.tipocamb,2),imtotabs=liqui.vamontdevbs-liqui.montoliqubs where nupagoexol=liqui.nupagoexol;
                    update fad_pagoextr set mopago=round((liqui.vamontdevbs-liqui.montoliqubs)/liqui.tipocamb,2) where nupagoextr=liqui.nupagoextr;
                    update fam_pagoextr set vamont=round((liqui.vamontdevbs-liqui.montoliqubs)/liqui.tipocamb,2) where nupagoextr=liqui.nupagoextr;
                    update fat_cargabon set vamontfact=round(liqui.vamontfact,2) where nucargabon=liqui.abono and nucomp=liqui.nucomp;

                    if liqui.stpagoEXTR='P' then
                        update fam_pagoexol set stpago='E' where nupagoexol=liqui.nupagoexol;
                    end if;

                    --ACTUALIZACION DEL NOMBRE
                    /*
                        if liqui.obsdev7='ERROR' and liqui.STPAGO in ('E','P') then
                            update fam_pagoexol set DSNOMB=liqui.DSNOMBOK,STPAGO='E',FCMODI=SYSDATE WHERE NUPAGOEXOL=liqui.NUPAGOEXOL;
                        end if;

                        commit;
                    */
                end if;
            end if;



        end loop;
        SGC_CB.cbpq_coblinweb_PAGOEXTR.PR_PUBLICADOCU(1,1);

        UPDATE
            FAT_CARGABON
        SET
            VAMONTFACT=ROUND(VAMONTFACT,2)
        WHERE
            nucargabon=nvl(pa_nucargabon,nucargabon) and
            nucomp=nvl(pa_nucomp,nucomp) and
            cdcargabon=2 and
            ticargabon='A' and
            stregi='R' AND
            VAMONTFACT<>ROUND(VAMONTFACT,2);

        commit;

    end;



    PROCEDURE PR_REGISTRAPAGOEXTR ( PA_NUCARGABON NUMBER,
                                    PA_NUCOMP NUMBER,
                                    PA_TIMONE VARCHAR2,
                                    PA_NUCUEN NUMBER,
                                    PA_NUSERV NUMBER,
                                    PA_FCPAGO DATE,
                                    PA_VAMONT  NUMBER,
                                    PA_NUDOCU NUMBER, --ALMACENAR EN NUDEPO
                                    PA_DTGLOS VARCHAR2,
                                    PA_NUPAGOEXTR OUT NUMBER,
                                    PA_ISOK OUT VARCHAR2,
                                    PA_DSMENS OUT VARCHAR2
                                  ) IS
        va_nupagoextr number;
    BEGIN

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
          VALUES
          (
            va_nupagoextr,
            pa_nucomp,
            '1052-001878',
            pa_fcpago,
            pa_nucuen,
            'P',
            nvl(MGPQ_SEGUACCE.Fn_TraerNuEmpl,0),
            sysdate,
            pa_dtglos,
            20,
            151,
            null,
            null,
            pa_nudocu,
            pa_vamont,
            0
         );


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
               PA_NUCOMP,
               PA_nucargabon,
               nvl(pa_vamont,0),
               1,
               0,
               pa_timone,
               MGFN_CAMBDIAR,
               0
              );
            --Actualiza Saldos
                Fapq_Cargabon.pr_actualizacargos (PA_nucargabon,PA_nucomp,pa_vamont,pa_vamont,pa_dsmens);
    END;

    --BORRAR LAS BITACORAS DUPLICADAS
    PROCEDURE PR_BITACAAB_DELETE_DUPLICADOS IS
        --DEMORA ENTRE 20 MINUTOS Y 60 MINUTOS

            CURSOR TRAE_BITACAAB  IS

                SELECT /*+ FULL(BI) */
                    ROWID           FILAID,
                    NUCOMP          ,
                    NUCARGABON      ,
                    FCCARGO         ,
                    CDCARGABON      ,
                    VERSION         ,
                    TICARGABON      ,
                    TICALC          ,
                    VAPLAZ          ,
                    VAKWH           ,
                    NUCUEN          ,
                    NUSERV          ,
                    NUCLIE          ,
                    TIMONE          ,
                    VAMONT          ,
                    VAMONTFACT      ,
                    VAMONTCOBR      ,
                    OPFACTCAAB      ,
                    STREGI          ,
                    STFACT          ,
                    STCOBR          ,
                    TIDML           ,
                    NUCAABASOC      ,
                    NUEMPLTRAN      ,
                    TO_CHAR(FCTRAN,'YYYYMM') PERIODO,
                    FCTRAN
                FROM
                    FAB_BITACAAB BI
                WHERE
                    --NUCARGABON=3493834 AND NUCOMP=1 AND NUCUEN=322908 AND
                    SYS_EXTRACT_UTC("FCTRAN")<TRUNC(SYSDATE-30,'MM')
                ORDER BY
                    NUCOMP,
                    NUCARGABON,
                    FCTRAN DESC;

            VA_BITACAABANTE TRAE_BITACAAB%ROWTYPE;
            va_borrados number := 0;
            va_revisados number := 0;
            va_fcinic date;
            va_fcfina date;
        BEGIN
            va_fcinic := sysdate;
            FOR VA_BITACAAB IN TRAE_BITACAAB
            LOOP
                va_revisados := va_revisados + 1;
                IF VA_BITACAABANTE.NUCARGABON=VA_BITACAAB.NUCARGABON AND  VA_BITACAABANTE.NUCOMP=VA_BITACAAB.NUCOMP THEN
                    IF
                        VA_BITACAABANTE.FCCARGO                     =   VA_BITACAAB.FCCARGO    AND
                        VA_BITACAABANTE.CDCARGABON                  =   VA_BITACAAB.CDCARGABON AND
                        VA_BITACAABANTE.VERSION                     =   VA_BITACAAB.VERSION    AND
                        VA_BITACAABANTE.TICARGABON                  =   VA_BITACAAB.TICARGABON AND
                        VA_BITACAABANTE.TICALC                      =   VA_BITACAAB.TICALC     AND
                        VA_BITACAABANTE.VAPLAZ                      =   VA_BITACAAB.VAPLAZ     AND
                        NVL(VA_BITACAABANTE.VAKWH,-1)               =   NVL(VA_BITACAAB.VAKWH,-1) AND
                        NVL(VA_BITACAABANTE.NUCUEN,-1)              =   NVL(VA_BITACAAB.NUCUEN,-1)     AND
                        NVL(VA_BITACAABANTE.NUSERV,-1)              =   NVL(VA_BITACAAB.NUSERV,-1)     AND
                        NVL(VA_BITACAABANTE.NUCLIE,-1)              =   NVL(VA_BITACAAB.NUCLIE,-1)     AND
                        VA_BITACAABANTE.TIMONE                      =   VA_BITACAAB.TIMONE     AND
                        VA_BITACAABANTE.VAMONT                      =   VA_BITACAAB.VAMONT     AND
                        VA_BITACAABANTE.VAMONTFACT                  =   VA_BITACAAB.VAMONTFACT AND
                        --VA_BITACAABANTE.VAMONTCOBR                  =   VA_BITACAAB.VAMONTCOBR AND
                        VA_BITACAABANTE.OPFACTCAAB                  =   VA_BITACAAB.OPFACTCAAB AND
                        VA_BITACAABANTE.STREGI                      =   VA_BITACAAB.STREGI     AND
                        VA_BITACAABANTE.STFACT                      =   VA_BITACAAB.STFACT     AND
                        VA_BITACAABANTE.STCOBR                      =   VA_BITACAAB.STCOBR     AND
                        VA_BITACAABANTE.TIDML                       =   VA_BITACAAB.TIDML      AND
                        NVL(VA_BITACAABANTE.NUCAABASOC,-1)          =   NVL(VA_BITACAAB.NUCAABASOC,-1) AND
                        VA_BITACAABANTE.PERIODO                     =   VA_BITACAAB.PERIODO
                        --VA_BITACAABANTE.NUEMPLTRAN                  =   VA_BITACAAB.NUEMPLTRAN AND
                        --TRUNC(VA_BITACAABANTE.FCTRAN,'MI')          =   TRUNC(VA_BITACAAB.FCTRAN,'MI')
                    THEN
                        --DBMS_OUTPUT.PUT_LINE('Borrando el registro '||VA_BITACAAB.filaid||' del cargo/abono '||VA_BITACAAB.nucargabon||'-'||VA_BITACAAB.nucomp);
                        va_borrados := va_borrados + 1;
                        DELETE FAB_BITACAAB WHERE ROWID=VA_BITACAAB.FILAID;
                        --DBMS_OUTPUT.PUT_LINE(nvl(sql%rowcount,0)||' registros borrados para el documento '||VA_BITACAAB.nucargabon||'-'||VA_BITACAAB.nucomp);
                        if mod(va_borrados,100)=0 then
                            commit;
                        end if;
                    END IF;
                END IF;
                VA_BITACAABANTE := VA_BITACAAB;
            END LOOP;
            commit;
            va_fcfina := sysdate;
            DBMS_OUTPUT.PUT_LINE('Fecha Inicial: '||to_char(va_fcinic,'DD/MM/YYYY HH24:MI:SS'));
            DBMS_OUTPUT.PUT_LINE('Fecha Final:   '||to_char(va_fcfina,'DD/MM/YYYY HH24:MI:SS'));
            DBMS_OUTPUT.PUT_LINE('Tiempo:        '||trim(to_char((va_fcfina-va_fcinic)*24*60,'9990.9')||' minutos'));
            DBMS_OUTPUT.PUT_LINE('Revisados:     '||trim(to_char(va_revisados,'999,999,999,990')||' registros'));
            DBMS_OUTPUT.PUT_LINE('Borrados:      '||trim(to_char(va_borrados,'999,999,999,990')||' registros'));
        END;

    PROCEDURE PR_DEVOLUCION_EXCESO IS

            va_cdCargoAjuste number := 252;

            Cursor trae_Exceso_Cert is

                    select
                        re.*,
                        (vamontfact-vamont) exceso,
                        (vamontfact-greatest(vamont_ab,vamontfact_ab)) exceso2
                        --(case when vamont-vamont_ab<>0 then vamont-vamont_ab else 0 end) DifDevo,
                        --(case when vamont_ab>410 then vamont_ab-410 else 0 end) DevoMayor410
                    from
                    (
                        select
                            nucomp,
                            nucargabon,
                            nuclie,
                            nucuen,
                            trunc(fccargo) fccargo,
                            ticargabon,
                            timone,
                            cdcargabon,
                            vamont,
                            vamontfact,
                            vamontcobr,
                            stregi,
                            stfact,
                            stcobr,
                            opfactcaab,
                            nucaabasoc,
                            (select ab.vamont     from fat_cargabon ab where ab.nucargabon=ca.nucaabasoc and ab.nucomp=ca.nucomp and ab.stregi='R') vamont_ab,
                            (select ab.vamontfact from fat_cargabon ab where ab.nucargabon=ca.nucaabasoc and ab.nucomp=ca.nucomp and ab.stregi='R') vamontfact_ab,
                            (select ab.vamontcobr from fat_cargabon ab where ab.nucargabon=ca.nucaabasoc and ab.nucomp=ca.nucomp and ab.stregi='R') vamontcobr_ab,
                            ca.vaplaz
                        from
                            fat_cargabon ca
                        where
                            --NUCOMP=3 AND
                            --nuclie=129209 and
                            --nucuen in (1011105) and
                            --nucargabon=439683 and nucomp=1 and
                            cdcargabon=2 and
                            ticargabon='C' and
                            stregi='R' and
                            --vamont>410 and
                            vamontfact>410
                    ) re
                    where
                        nucaabasoc is null
                        --nucaabasoc is not null and vamontfact>vamontfact_ab
                    order by
                        vamontfact_ab,
                        EXCESO;

            va_registro varchar2(1000);
            pa_dsMens varchar2(1000);
            va_dtGlos varchar2(1000);
            va_nuserv number;
            va_fccargo date;
            va_vaplaz  number;
            va_nucargabon number;
            pa_nuerro number;
            va_nupagoextrOrigen number;
            va_debug varchar2(1):='N';


         begin
                for  va_exceso in trae_Exceso_Cert
                loop
                    va_registro := '--- Iniciando el ajuste del cargo '|| va_exceso.nucargabon ||'-'|| va_exceso.nucomp ||' Codfijo '||va_exceso.nucuen||' por un monto de '|| trim(to_char(va_exceso.exceso,'990.99')) ||' dolares.';
                    pa_dsMens   := va_registro;
                    if va_debug='S' then
                        DBMS_OUTPUT.PUT_LINE(pa_dsmens);
                    end if;

                    --VALIDANDO EL EXCESO
                        if nvl(va_exceso.exceso,0)<=0 then
                            continue;
                        end if;

                    --CREANDO EL SERVICIO
                        pa_dsMens :='Intentando crear el servicio.';
                        if va_debug='S' then
                            DBMS_OUTPUT.PUT_LINE('      '||pa_dsmens);
                        end if;
                        va_dtGlos := 'AJUSTE DE CERTIFICADO DE APORTACION DEL CARGO '|| lpad(va_exceso.nucargabon,10) ||' CUENTA '|| trim(va_exceso.nucuen)||' POR UN MONTO DE '|| trim(to_char(va_exceso.exceso,'990.99')) ||' dolares.';
                        fapq_pagoextr.pr_CreaServicio(va_exceso.nucomp,va_exceso.nucuen,'DECISION DE CRE',va_dtglos,va_nuserv,pa_dsmens);
                        if pa_dsmens is not null then
                            DBMS_OUTPUT.PUT_LINE('      '||va_registro);
                            DBMS_OUTPUT.PUT_LINE('      '||pa_dsmens);
                            pa_nuerro := '38503';
                            continue;
                        end if;
                        pa_dsMens :='Se ha creado el servicio '||va_nuserv;
                        if va_debug='S' then
                            DBMS_OUTPUT.PUT_LINE('      '||pa_dsmens);
                        end if;

                    --CREACION DEL ABONO POR IMPORTE NETO
                        pa_dsMens :='Intentando crear el abono Ajuste Certificado de Aportacion';
                        if va_debug='S' then
                            DBMS_OUTPUT.PUT_LINE('      '||pa_dsmens);
                        end if;
                        fapq_cargabon.pr_inscargserv (  va_exceso.nucomp,
                                                        va_exceso.nucuen,
                                                        va_nuserv,
                                                        va_cdCargoAjuste,
                                                        'A',
                                                        va_exceso.nucargabon,
                                                        'FA',
                                                        null,
                                                        va_fccargo,
                                                        va_vaplaz,
                                                        va_exceso.exceso,
                                                        va_nucargabon,
                                                        pa_nuerro
                                                    );
                        if pa_nuerro is not null then
                            pa_dsmens := pa_dsMens ||'. Error: '||pa_nuerro;
                            DBMS_OUTPUT.PUT_LINE('      '||va_registro);
                            DBMS_OUTPUT.PUT_LINE('      '||pa_dsmens);
                            pa_nuerro := '38504';
                            continue;
                        end if;
                        --actualizacion del Cliente
                        update fat_cargabon set nuclie=va_exceso.nuclie where nucomp=va_exceso.nucomp and nucargabon=va_nucargabon;
                        pa_dsMens :='Se ha creado el abono '||va_nucargabon;
                        if va_debug='S' then
                            DBMS_OUTPUT.PUT_LINE('      '||pa_dsmens);
                        end if;


                    --INSERTANDO EL PAGO EXTRAORDINARIO ANTIGUO
                        SELECT SGC_FA_PAGOEXTR.NEXTVAL INTO va_nupagoextrOrigen FROM dual;
                        pa_dsMens :='Intentando crear el pago extraordinario '||va_nupagoextrOrigen;
                        if va_debug='S' then
                            DBMS_OUTPUT.PUT_LINE('      '||pa_dsmens);
                        end if;

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
                          VALUES
                          (
                            va_nupagoextrOrigen,
                            va_exceso.NUCOMP,
                            'AJUSTE CERT-APORT',
                            TRUNC(SYSDATE),
                            va_exceso.nucuen,
                            'P',
                            0,
                            SYSDATE,
                            'AJUSTE PARA DEVOLUCION AL SOCIO EN EL ABONO 252 NRO. '||va_nucargabon||'. ',
                            0,
                            0,
                            NULL,
                            NULL,
                            va_nucargabon,
                            -va_exceso.exceso,
                            va_nuserv
                         );

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
                          values
                          (
                            va_nupagoextrOrigen,
                            va_exceso.nucomp,
                            va_exceso.nucargabon,
                            -va_exceso.exceso,
                            1,
                            0,
                            va_exceso.timone,
                            1,
                            va_nuserv
                          );


                    --INSERTANDO EL PAGO EXTRAORDINARIO ANTIGUO
                        pa_dsMens :='Intentando actualizar los saldos del abono '||va_exceso.nucargabon;
                        if va_debug='S' then
                            DBMS_OUTPUT.PUT_LINE('      '||pa_dsmens);
                        end if;
                        UPDATE
                            FAT_CARGABON
                        SET
                            VAMONTFACT=VAMONTFACT-va_exceso.exceso,
                            VAMONTCOBR=VAMONTCOBR-va_exceso.exceso,
                            FCMODI=SYSDATE,
                            NUEMPLMODI=0
                        WHERE
                            NUCOMP=va_exceso.nucomp AND
                            NUCARGABON=va_exceso.nucargabon;

                    --ACTIVACION DEL ABONO
                        --pa_dsMens :='Intentando activar el abono '||va_nucargabon;
                        --DBMS_OUTPUT.PUT_LINE('      '||pa_dsmens);
                        --fapq_cargabon.pr_setopfactcaab (va_exceso.nucomp,va_nucargabon,'S',pa_nuerro);
                        --if pa_nuerro is not null then
                        --    pa_dsmens := pa_dsMens ||'. Error: '||pa_nuerro;
                        --    pa_nuerro := '38504';
                        --    return;
                        --end if;

                    --FINALIZNDO Y REALIZANDO COMMIT
                        pa_dsMens :='Proceso finalizado correctamente.';
                        if va_debug='S' then
                            DBMS_OUTPUT.PUT_LINE('      '||pa_dsmens);
                        end if;
                        COMMIT;

                        pa_dsmens := null;
                        pa_nuerro := null;

                end loop;
        end;

END;