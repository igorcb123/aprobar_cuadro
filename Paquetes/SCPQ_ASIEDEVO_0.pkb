/*******************************************************************************
 * METADATA
 * Analista     : IGORCB
 * Descargado   : 06/10/2026, 11:41:21
 * Owner        : SGC_SO
 * Versión      : 0
 *******************************************************************************/
CREATE OR REPLACE PACKAGE BODY SGC_SO.SCPQ_ASIEDEVO AS
/***********************************************************************************
   Descripcion   : Procedimientos y funciones que permiten el registro de asientos
                   contables mediante interfaces WebSap.
   Creacion      : 13/11/2018
   Autor         : Guido Hurtado
*************************************************************************************/

  --
  -- PROCEDIMIENTO QUE GENERA EL ASIENTO 1
  PROCEDURE Pr_InsertarAsientoUno(pIdCuad   IN NUMBER,
                                  pNuAsie   OUT VARCHAR2,
                                  pOperOK   OUT VARCHAR2,
                                  pMensOper OUT VARCHAR2,
                                  pfcregi   IN DATE DEFAULT SYSDATE) IS
    CURSOR cValidarSolicitud IS
      SELECT *
       FROM  sct_solidevo
       WHERE idcuaddevo = pIdCuad
         AND stregi = 'R';
    CURSOR cCargo IS
      SELECT nucomp,SUM(vamontfactbs) tocargabon
       FROM  sct_solidevo
       WHERE idcuaddevo = pIdCuad
         AND stsolidevo = 'CUA'
         AND stregi = 'R'
       GROUP BY nucomp
       ORDER BY nucomp;
    CURSOR cPago IS
      SELECT nucomp,SUM(topagofact) topago
       FROM  sct_solidevo
       WHERE idcuaddevo = pIdCuad
         AND stsolidevo = 'CUA'
         AND stregi = 'R'
       GROUP BY nucomp
       ORDER BY nucomp;
    CURSOR cSolicitud IS
      SELECT *
       FROM  sct_solidevo
       WHERE idcuaddevo = pIdCuad
         AND stsolidevo = 'CUA'
         AND stregi = 'R'
       ORDER BY nucomp,nuserv;
    --
    pacabecera       SGC_SO.SCPQ_ASIEDEVO.r_cabecera;
    pacuentaMayor    SGC_SO.SCPQ_ASIEDEVO.t_poscuenmayor;
    pacuentaAcreedor SGC_SO.SCPQ_ASIEDEVO.t_posacreedor;
    paimporte        SGC_SO.SCPQ_ASIEDEVO.t_importe;
    paretencion      SGC_SO.SCPQ_ASIEDEVO.t_retencion;
    --
    vfcregi          DATE;
    vctauno          VARCHAR2(10) := '3120100000';
    vctados          VARCHAR2(10) := '1136401145';
    vctatres         VARCHAR2(10) := '2114623000';
    vnuitem          NUMBER;
    vnroasignacion   VARCHAR2(18);
    vnroposicion     NUMBER;
    vtextoposicion   VARCHAR2(50);
    vnuciapro        VARCHAR2(50);
    vcddivi          VARCHAR2(4);
    --
    vdife            NUMBER;
    EstadoSolicitud  EXCEPTION;
  BEGIN
    pOperOK := 'N';
    --
    FOR k IN cValidarSolicitud LOOP
      IF k.stsolidevo IS NULL THEN
        pMensOper := 'La solicitud ' || k.nucomp || '-' || k.nuserv || ' esta con estado NULO';
        RAISE EstadoSolicitud;
      END IF;
      IF k.stsolidevo <> 'CUA' THEN
        pMensOper := 'La solicitud ' || k.nucomp || '-' || k.nuserv || ' esta con estado ' || k.stsolidevo;
        RAISE EstadoSolicitud;
      END IF;
      vdife := nvl(k.vamontfactbs,0) - nvl(k.topagofact,0) - nvl(k.toordedevobs,0);
      IF vdife <> 0 THEN
        pMensOper := 'La solicitud ' || k.nucomp || '-' || k.nuserv || ' tiene una diferencia en sus importes';
        RAISE EstadoSolicitud;
      END IF;
    END LOOP;
    --
    vnuciapro := Fn_CiCuadro(pIdCuad);
    -- Datos de la cabecera
    vfcregi := pfcregi;
    pacabecera.claseDocumento := 'IC';
    pacabecera.ejercicio := to_char(vFcRegi,'YYYY');
    --Modificado a solicitud de Paula Ponce 16/11/2022
    --pacabecera.usuario := 'sigecom';
    pacabecera.usuario := Fn_UsuarioSAP;
    pacabecera.fechaContabilizacion := to_char(vFcRegi,'YYYYMMDD');
    pacabecera.fechaDocumento := to_char(vFcRegi,'YYYYMMDD');
    pacabecera.mes := to_char(vFcRegi,'MM');
    pacabecera.nroDocumentoReferencia := rpad(vnuciapro,16,' ');
    pacabecera.textoCabecera := rpad('Dev.Cert.Aport. ' || to_char(vFcRegi,'dd/mm/yy'),25,' ');
    -- Datos cuenta mayor e importe (devolución certificados agrupado por compañía)
    vnuitem := 0;
    vnroasignacion := 'Dev.Cert.Aport';
    vnroposicion := 0;
    vtextoposicion := vnuciapro || ' Dev.Cert.Aport';
    FOR k IN cCargo LOOP
      vnuitem := vnuitem + 1;
      vnroposicion := vnroposicion + 1;
      vcddivi := Fn_DivisionCompañia(k.nucomp);
      --
      pacuentaMayor(vnuitem).cuentaMayor := vctauno;
      pacuentaMayor(vnuitem).division:= vcddivi;
      pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
      pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
      pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
      --
      paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
      paimporte(vnuitem).moneda := 'BOB';
      paimporte(vnuitem).importe := to_char(k.tocargabon,'99999990.00');
    END LOOP;
    -- Datos cuenta mayor e importe (pago de deuda agrupado por compañía)
    vnroasignacion := 'Dev.Cert.Aport';
    vtextoposicion := vnuciapro || ' Dev.Cert.Aport';
    FOR k IN cPago LOOP
      vnuitem := vnuitem + 1;
      vnroposicion := vnroposicion + 1;
      vcddivi := Fn_DivisionCompañia(k.nucomp);
      --
      pacuentaMayor(vnuitem).cuentaMayor := vctados;
      pacuentaMayor(vnuitem).division:= vcddivi;
      pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
      pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
      pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
      --
      paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
      paimporte(vnuitem).moneda := 'BOB';
      paimporte(vnuitem).importe := to_char(k.topago * -1,'99999990.00');
    END LOOP;
    -- Datos cuenta mayor e importe (saldo certificado por socio)
    vnroasignacion := NULL;
    vtextoposicion := NULL;
    vcddivi := Fn_DivisionCompañia(1);
    FOR k IN cSolicitud LOOP
      vnuitem := vnuitem + 1;
      vnroposicion := vnroposicion + 1;
      vnroasignacion := k.idcert;
      vtextoposicion := Fn_DescripcionTextoPosicion(k.nucomp,k.nuserv,'DCA');
      --
      pacuentaMayor(vnuitem).cuentaMayor := vctatres;
      pacuentaMayor(vnuitem).division:= vcddivi;
      pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
      pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
      pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
      --
      paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
      paimporte(vnuitem).moneda := 'BOB';
      paimporte(vnuitem).importe := to_char(k.toordedevobs * -1,'99999990.00');
    END LOOP;
    -- Llamar al procedimiento del asiento contable
    Pr_InsertarAsientoSAP(pacabecera,pacuentaMayor,pacuentaAcreedor,paimporte,paretencion,pnuasie,pOperOK,pMensOper);
    EXCEPTION
      WHEN EstadoSolicitud THEN
        pMensOper := 'Pr_InsertarAsientoUno. ' || pMensOper;
        pOperOK := 'N';
      WHEN Others THEN
        pMensOper := 'Pr_InsertarAsientoUno. ' || sqlerrm;
        pOperOK := 'N';
  END Pr_InsertarAsientoUno;

  --
  -- PROCEDIMIENTO QUE GENERA EL ASIENTO 2
  PROCEDURE Pr_InsertarAsientoDos(pFcPago   IN DATE,
                                  pNuAsie   OUT VARCHAR2,
                                  pOperOK   OUT VARCHAR2,
                                  pMensOper OUT VARCHAR2,
                                  pFcRegi   IN DATE DEFAULT NULL) IS
    CURSOR cSolicitud IS
      SELECT *
       FROM  sct_solidevo
       WHERE trunc(fcpagoorde,'dd') = trunc(pFcPago,'dd')
         AND stregi = 'R'
       ORDER BY nucomp,nuserv;
    --
    CURSOR cEntidadFinanciera IS
      SELECT nuentifina,centrocobro,nucuencont,sum(toordedevobs) toordedevobs
       FROM  scw_solidevo1
       WHERE trunc(fcpagoorde,'dd') = trunc(pFcPago,'dd')
         AND stregi = 'R'
      GROUP BY nuentifina,centrocobro,nucuencont
      ORDER BY nuentifina;
    --
    pacabecera       SGC_SO.SCPQ_ASIEDEVO.r_cabecera;
    pacuentaMayor    SGC_SO.SCPQ_ASIEDEVO.t_poscuenmayor;
    pacuentaAcreedor SGC_SO.SCPQ_ASIEDEVO.t_posacreedor;
    paimporte        SGC_SO.SCPQ_ASIEDEVO.t_importe;
    paretencion      SGC_SO.SCPQ_ASIEDEVO.t_retencion;
    --
    vfcregi          DATE;
    vctauno          VARCHAR2(10) := '2114623000';
    --Se cambia la cuenta dos que era de FASSIL 1112111025 el 24/04/2023 a solicitud de Marcia
    --vctados          VARCHAR2(10) := '1112111025'; --FASSIL
    vctados          VARCHAR2(10) := '1112120475'; --LA MERCED
    vnuitem          NUMBER;
    vnroasignacion   VARCHAR2(18);
    vnroposicion     NUMBER;
    vtextoposicion   VARCHAR2(50);
    vimpt            NUMBER;
    vcddivi          VARCHAR2(4);
    --
    CuentaContable   EXCEPTION;
  BEGIN
    pOperOK := 'N';
    -- Datos de la cabecera
    vfcregi := pFcPago;
    IF pFcRegi IS NOT NULL THEN
      vfcregi := pFcRegi;
    END IF;
    pacabecera.claseDocumento := 'IC';
    pacabecera.ejercicio := to_char(vFcRegi,'YYYY');
    --Modificado a solicitud de Paula Ponce 16/11/2022
    --pacabecera.usuario := 'sigecom';
    pacabecera.usuario := Fn_UsuarioSAP;
    pacabecera.fechaContabilizacion := to_char(vFcRegi,'YYYYMMDD');
    pacabecera.fechaDocumento := to_char(vFcRegi,'YYYYMMDD');
    pacabecera.mes := to_char(vFcRegi,'MM');
    pacabecera.nroDocumentoReferencia := rpad('Pago Dev.Cert.Ap',16,' ');
    pacabecera.textoCabecera := rpad('Pago Dev.Cert.Aportación',25,' ');
    -- Datos cuenta mayor e importe (pago orden de devolución por socio)
    vimpt := 0;
    vnuitem := 0;
    vnroasignacion := NULL;
    vnroposicion := 0;
    vtextoposicion := NULL;
    vcddivi := Fn_DivisionCompañia(1);
    FOR k IN cSolicitud LOOP
      vnuitem := vnuitem + 1;
      vnroposicion := vnroposicion + 1;
      vnroasignacion := k.idcert;
      vtextoposicion := Fn_DescripcionTextoPosicion(k.nucomp,k.nuserv,'DCA');
      vimpt := vimpt + k.toordedevobs;
      --
      pacuentaMayor(vnuitem).cuentaMayor := vctauno;
      pacuentaMayor(vnuitem).division:= vcddivi;
      pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
      pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
      pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
      --
      paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
      paimporte(vnuitem).moneda := 'BOB';
      paimporte(vnuitem).importe := to_char(k.toordedevobs,'99999990.00');
    END LOOP;
    -- Datos cuenta mayor e importe (entidades financieras)
    vnroasignacion := '44';
    vcddivi := Fn_DivisionCompañia(1);
    vtextoposicion := rpad('Dev.Cert.Aport. ' || to_char(pFcPago,'dd/mm/yy'),25,' ');
    FOR c IN cEntidadFinanciera LOOP
      IF c.nucuencont IS NULL THEN
        pMensOper := 'La entidad financiera ' || c.centrocobro || ' no tiene definida su cuenta contable.';
        RAISE CuentaContable;
      END IF;
      vnuitem := vnuitem + 1;
      vnroposicion := vnroposicion + 1;
      --
      pacuentaMayor(vnuitem).cuentaMayor := c.nucuencont; --vctados;
      pacuentaMayor(vnuitem).division:= vcddivi;
      pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
      pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
      pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
      --
      paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
      paimporte(vnuitem).moneda := 'BOB';
      paimporte(vnuitem).importe := to_char(c.toordedevobs * -1,'99999990.00'); --to_char(vimpt * -1,'99999990.00');
    END LOOP;
    -- Llamar al procedimiento del asiento contable
    Pr_InsertarAsientoSAP(pacabecera,pacuentaMayor,pacuentaAcreedor,paimporte,paretencion,pnuasie,pOperOK,pMensOper);
    EXCEPTION
      WHEN CuentaContable THEN
        pMensOper := 'Pr_InsertarAsientoDos. ' || pMensOper;
        pOperOK := 'N';
      WHEN Others THEN
        pMensOper := 'Pr_InsertarAsientoDos ' || sqlerrm;
        pOperOK := 'N';
  END Pr_InsertarAsientoDos;

  --
  -- PROCEDIMIENTO QUE GENERA EL ASIENTO 3
  PROCEDURE Pr_InsertarAsientoTres(pNuComp   IN NUMBER,
                                   pNuServ   IN NUMBER,
                                   pCdAnul   IN VARCHAR2,
                                   pNuAsie   OUT VARCHAR2,
                                   pOperOK   OUT VARCHAR2,
                                   pMensOper OUT VARCHAR2) IS
    CURSOR cSolicitud(p_nucomp IN NUMBER,p_nuserv IN NUMBER) IS
      SELECT *
       FROM  sct_solidevo
       WHERE nucomp = p_nucomp
         AND nuserv = p_nuserv
         AND stregi = 'R';
    vSolicitud cSolicitud%RowType;
    --
    pacabecera       SGC_SO.SCPQ_ASIEDEVO.r_cabecera;
    pacuentaMayor    SGC_SO.SCPQ_ASIEDEVO.t_poscuenmayor;
    pacuentaAcreedor SGC_SO.SCPQ_ASIEDEVO.t_posacreedor;
    paimporte        SGC_SO.SCPQ_ASIEDEVO.t_importe;
    paretencion      SGC_SO.SCPQ_ASIEDEVO.t_retencion;
    --
    vfcregi          DATE;
    vctauno          VARCHAR2(10) := '3120100000';
    vctados          VARCHAR2(10) := '1136401145';
    vctatres         VARCHAR2(10) := '2114623000';
    vnuitem          NUMBER;
    vnroasignacion   VARCHAR2(18);
    vnroposicion     NUMBER;
    vtextoposicion   VARCHAR2(50);
    vnuciapro        VARCHAR2(50);
    vcddivi          VARCHAR2(4);
  BEGIN
    pOperOK := 'N';
    --
    OPEN cSolicitud(pnucomp,pnuserv);
    FETCH cSolicitud INTO vSolicitud;
    CLOSE cSolicitud;
    --
    vnuciapro := Fn_CiCuadro(vSolicitud.idcuaddevo);
    -- Datos de la cabecera
    vfcregi := sysdate;
    pacabecera.claseDocumento := 'IC';
    pacabecera.ejercicio := to_char(vFcRegi,'YYYY');
    --Modificado a solicitud de Paula Ponce 16/11/2022
    --pacabecera.usuario := 'sigecom';
    pacabecera.usuario := Fn_UsuarioSAP;
    pacabecera.fechaContabilizacion := to_char(vFcRegi,'YYYYMMDD');
    pacabecera.fechaDocumento := to_char(vFcRegi,'YYYYMMDD');
    pacabecera.mes := to_char(vFcRegi,'MM');
    pacabecera.nroDocumentoReferencia := rpad(vnuciapro,16,' ');
    IF pcdanul = '001' OR pcdanul = '002' THEN
      pacabecera.textoCabecera := rpad('Anul. DCA p.cambio nombre',25,' ');
    ELSIF pcdanul = '003' THEN
      pacabecera.textoCabecera := rpad('Anul. DCA p.extravío',25,' ');
    ELSIF pcdanul = '004' THEN
      pacabecera.textoCabecera := rpad('Anul. DCA p.monto incorre',25,' ');
    ELSIF pcdanul = '005' THEN
      pacabecera.textoCabecera := rpad('Anul. DCA p.pago equivoca',25,' ');
    ELSE
      pacabecera.textoCabecera := rpad('Anul. DCA p.desent. socio',25,' ');
    END IF;
    -- Datos cuenta mayor e importe (cuenta 1)
    vnuitem := 1;
    vnroposicion := 1;
    vcddivi := Fn_DivisionCompañia(vSolicitud.nucomp);
    vnroasignacion := vSolicitud.idcert;
    vtextoposicion := 'Anul. ' || vnuciapro || ' Dev.Cert.Aport';
    --
    pacuentaMayor(vnuitem).cuentaMayor := vctauno;
    pacuentaMayor(vnuitem).division:= vcddivi;
    pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
    pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
    pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
    --
    paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
    paimporte(vnuitem).moneda := 'BOB';
    paimporte(vnuitem).importe := to_char(vSolicitud.vamontfactbs * -1,'99999990.00');
    -- Datos cuenta mayor e importe (cuenta 2)
    vnuitem := 2;
    vnroposicion := 2;
    vcddivi := Fn_DivisionCompañia(vSolicitud.nucomp);
    vnroasignacion := vSolicitud.idcert;
    vtextoposicion := 'Anul. ' || vnuciapro || ' Dev.Cert.Aport';
    --
    pacuentaMayor(vnuitem).cuentaMayor := vctados;
    pacuentaMayor(vnuitem).division:= vcddivi;
    pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
    pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
    pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
    --
    paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
    paimporte(vnuitem).moneda := 'BOB';
    paimporte(vnuitem).importe := to_char(vSolicitud.topagofact,'99999990.00');
    -- Datos cuenta mayor e importe (cuenta 3)
    vnuitem := 3;
    vnroposicion := 3;
    vcddivi := Fn_DivisionCompañia(1);
    vnroasignacion := vSolicitud.idcert;
    IF pcdanul = '001' OR pcdanul = '002' THEN --Cambio nombre
      vtextoposicion := Fn_DescripcionTextoPosicionAnu(vSolicitud.nucomp,vSolicitud.nuserv,'Anul. DCA');
    ELSE --Extravío, Monto incorrecto, Desentimiento socio, Pago equivocado
      vtextoposicion := Fn_DescripcionTextoPosicion(vSolicitud.nucomp,vSolicitud.nuserv,'Anul. DCA');
    END IF;
    --
    pacuentaMayor(vnuitem).cuentaMayor := vctatres;
    pacuentaMayor(vnuitem).division:= vcddivi;
    pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
    pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
    pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
    --
    paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
    paimporte(vnuitem).moneda := 'BOB';
    paimporte(vnuitem).importe := to_char(vSolicitud.toordedevobs,'99999990.00');
    -- Llamar al procedimiento del asiento contable
    Pr_InsertarAsientoSAP(pacabecera,pacuentaMayor,pacuentaAcreedor,paimporte,paretencion,pnuasie,pOperOK,pMensOper);
    EXCEPTION
      WHEN Others THEN
        pMensOper := 'Pr_InsertarAsientoTres ' || sqlerrm;
        pOperOK := 'N';
  END Pr_InsertarAsientoTres;

  --
  -- PROCEDIMIENTO QUE GENERA EL ASIENTO 4
  PROCEDURE Pr_InsertarAsientoCuatro(pNuComp   IN NUMBER,
                                     pNuServ   IN NUMBER,
                                     pNuAsie   OUT VARCHAR2,
                                     pOperOK   OUT VARCHAR2,
                                     pMensOper OUT VARCHAR2) IS
    CURSOR cSolicitud(p_nucomp IN NUMBER,p_nuserv IN NUMBER) IS
      SELECT *
       FROM  sct_solidevo
       WHERE nucomp = p_nucomp
         AND nuserv = p_nuserv
         AND stregi = 'R';
    vSolicitud cSolicitud%RowType;
    --
    pacabecera       SGC_SO.SCPQ_ASIEDEVO.r_cabecera;
    pacuentaMayor    SGC_SO.SCPQ_ASIEDEVO.t_poscuenmayor;
    pacuentaAcreedor SGC_SO.SCPQ_ASIEDEVO.t_posacreedor;
    paimporte        SGC_SO.SCPQ_ASIEDEVO.t_importe;
    paretencion      SGC_SO.SCPQ_ASIEDEVO.t_retencion;
    --
    vfcregi          DATE;
    vctauno          VARCHAR2(10) := '2114623000';
    vctados          VARCHAR2(10) := '3120101000';
    vnuitem          NUMBER;
    vnroasignacion   VARCHAR2(18);
    vnroposicion     NUMBER;
    vtextoposicion   VARCHAR2(50);
    vnuciapro        VARCHAR2(50);
    vcddivi          VARCHAR2(4);
    vauxi            VARCHAR2(50);
  BEGIN
    pOperOK := 'N';
    --
    OPEN cSolicitud(pnucomp,pnuserv);
    FETCH cSolicitud INTO vSolicitud;
    CLOSE cSolicitud;
    --
    vnuciapro := Fn_CiCuadro(vSolicitud.idcuaddevo);
    -- Datos de la cabecera
    vfcregi := sysdate;
    pacabecera.claseDocumento := 'IC';
    pacabecera.ejercicio := to_char(vFcRegi,'YYYY');
    --Modificado a solicitud de Paula Ponce 16/11/2022
    --pacabecera.usuario := 'sigecom';
    pacabecera.usuario := Fn_UsuarioSAP;
    pacabecera.fechaContabilizacion := to_char(vFcRegi,'YYYYMMDD');
    pacabecera.fechaDocumento := to_char(vFcRegi,'YYYYMMDD');
    pacabecera.mes := to_char(vFcRegi,'MM');
    pacabecera.nroDocumentoReferencia := rpad('Rever.Art.26 Est',16,' ');
    pacabecera.textoCabecera := rpad('Rev.p/ve.' || vnuciapro,25,' ');
    -- Datos cuenta mayor e importe (cuenta 1)
    vnuitem := 1;
    vnroposicion := 1;
    vcddivi := Fn_DivisionCompañia(1);
    vnroasignacion := vSolicitud.idcert;
    vauxi := Fn_DescripcionTextoPosicion(vSolicitud.nucomp,vSolicitud.nuserv,'DCA');
    IF length(vauxi) > 37 THEN
      vauxi := substr(vauxi,0,37);
    END IF;
    vtextoposicion := vauxi || ', Art 26 Est.';
    --
    pacuentaMayor(vnuitem).cuentaMayor := vctauno;
    pacuentaMayor(vnuitem).division:= vcddivi;
    pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
    pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
    pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
    --
    paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
    paimporte(vnuitem).moneda := 'BOB';
    paimporte(vnuitem).importe := to_char(vSolicitud.toordedevobs,'99999990.00');
    -- Datos cuenta mayor e importe (cuenta 2)
    vnuitem := 2;
    vnroposicion := 2;
    vcddivi := Fn_DivisionCompañia(1);
    vnroasignacion := vSolicitud.idcert;
    vauxi := Fn_DescripcionTextoPosicion(vSolicitud.nucomp,vSolicitud.nuserv,'DCA');
    IF length(vauxi) > 37 THEN
      vauxi := substr(vauxi,0,37);
    END IF;
    vtextoposicion := vauxi || ', Art 26 Est.';
    --
    pacuentaMayor(vnuitem).cuentaMayor := vctados;
    pacuentaMayor(vnuitem).division:= vcddivi;
    pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
    pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
    pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
    --
    paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
    paimporte(vnuitem).moneda := 'BOB';
    paimporte(vnuitem).importe := to_char(vSolicitud.toordedevobs * -1,'99999990.00');
    -- Llamar al procedimiento del asiento contable
    Pr_InsertarAsientoSAP(pacabecera,pacuentaMayor,pacuentaAcreedor,paimporte,paretencion,pnuasie,pOperOK,pMensOper);
    EXCEPTION
      WHEN Others THEN
        pMensOper := 'Pr_InsertarAsientoCuatro ' || sqlerrm;
        pOperOK := 'N';
  END Pr_InsertarAsientoCuatro;

  --
  -- PROCEDIMIENTO QUE GENERA EL ASIENTO 5
  PROCEDURE Pr_InsertarAsientoCinco(pNuComp   IN NUMBER,
                                    pNuServ   IN NUMBER,
                                    pNuAsie   OUT VARCHAR2,
                                    pOperOK   OUT VARCHAR2,
                                    pMensOper OUT VARCHAR2) IS
    CURSOR cSolicitud(p_nucomp IN NUMBER,p_nuserv IN NUMBER) IS
      SELECT *
       FROM  sct_solidevo
       WHERE nucomp = p_nucomp
         AND nuserv = p_nuserv
         AND stregi = 'R';
    vSolicitud cSolicitud%RowType;
    --
    pacabecera       SGC_SO.SCPQ_ASIEDEVO.r_cabecera;
    pacuentaMayor    SGC_SO.SCPQ_ASIEDEVO.t_poscuenmayor;
    pacuentaAcreedor SGC_SO.SCPQ_ASIEDEVO.t_posacreedor;
    paimporte        SGC_SO.SCPQ_ASIEDEVO.t_importe;
    paretencion      SGC_SO.SCPQ_ASIEDEVO.t_retencion;
    --
    vfcregi          DATE;
    vctauno          VARCHAR2(10) := '3120100000';
    vctados          VARCHAR2(10) := '1136401145';
    vctatres         VARCHAR2(10) := '2114623000';
    vnuitem          NUMBER;
    vnroasignacion   VARCHAR2(18);
    vnroposicion     NUMBER;
    vtextoposicion   VARCHAR2(50);
    vnuciapro        VARCHAR2(50);
    vcddivi          VARCHAR2(4);
    vdife            NUMBER;
    EstadoSolicitud  EXCEPTION;
  BEGIN
    pOperOK := 'N';
    --
    OPEN cSolicitud(pnucomp,pnuserv);
    FETCH cSolicitud INTO vSolicitud;
    CLOSE cSolicitud;
    vdife := nvl(vSolicitud.vamontfactbs,0) - nvl(vSolicitud.topagofact,0) - nvl(vSolicitud.toordedevobs,0);
    IF vdife <> 0 THEN
      pMensOper := 'La solicitud ' || vSolicitud.nucomp || '-' || vSolicitud.nuserv || ' tiene una diferencia en sus importes';
      RAISE EstadoSolicitud;
    END IF;
    --
    vnuciapro := Fn_CiCuadro(vSolicitud.idcuaddevo);
    vnuciapro := vnuciapro || ' (R)';
    -- Datos de la cabecera
    vfcregi := sysdate;
    pacabecera.claseDocumento := 'IC';
    pacabecera.ejercicio := to_char(vFcRegi,'YYYY');
    --Modificado a solicitud de Paula Ponce 16/11/2022
    --pacabecera.usuario := 'sigecom';
    pacabecera.usuario := Fn_UsuarioSAP;
    pacabecera.fechaContabilizacion := to_char(vFcRegi,'YYYYMMDD');
    pacabecera.fechaDocumento := to_char(vFcRegi,'YYYYMMDD');
    pacabecera.mes := to_char(vFcRegi,'MM');
    pacabecera.nroDocumentoReferencia := rpad(vnuciapro,16,' ');
    pacabecera.textoCabecera := rpad('Dev.Cert.Aport. ' || to_char(vFcRegi,'dd/mm/yy'),25,' ');
    -- Datos cuenta mayor e importe (cuenta 1)
    vnuitem := 1;
    vnroposicion := 1;
    vcddivi := Fn_DivisionCompañia(vSolicitud.nucomp);
    vnroasignacion := vSolicitud.idcert;
    vtextoposicion := vnuciapro || ' Dev.Cert.Aport';
    --
    pacuentaMayor(vnuitem).cuentaMayor := vctauno;
    pacuentaMayor(vnuitem).division:= vcddivi;
    pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
    pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
    pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
    --
    paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
    paimporte(vnuitem).moneda := 'BOB';
    paimporte(vnuitem).importe := to_char(vSolicitud.vamontfactbs,'99999990.00');
    -- Datos cuenta mayor e importe (cuenta 2)
    vnuitem := 2;
    vnroposicion := 2;
    vcddivi := Fn_DivisionCompañia(vSolicitud.nucomp);
    vnroasignacion := vSolicitud.idcert;
    vtextoposicion := vnuciapro || ' Dev.Cert.Aport';
    --
    pacuentaMayor(vnuitem).cuentaMayor := vctados;
    pacuentaMayor(vnuitem).division:= vcddivi;
    pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
    pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
    pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
    --
    paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
    paimporte(vnuitem).moneda := 'BOB';
    paimporte(vnuitem).importe := to_char(vSolicitud.topagofact * -1,'99999990.00');
    -- Datos cuenta mayor e importe (cuenta 3)
    vnuitem := 3;
    vnroposicion := 3;
    vcddivi := Fn_DivisionCompañia(1);
    vnroasignacion := vSolicitud.idcert;
    vtextoposicion := Fn_DescripcionTextoPosicion(vSolicitud.nucomp,vSolicitud.nuserv,'DCA');
    --
    pacuentaMayor(vnuitem).cuentaMayor := vctatres;
    pacuentaMayor(vnuitem).division:= vcddivi;
    pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
    pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
    pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
    --
    paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
    paimporte(vnuitem).moneda := 'BOB';
    paimporte(vnuitem).importe := to_char(vSolicitud.toordedevobs * -1,'99999990.00');
    -- Llamar al procedimiento del asiento contable
    Pr_InsertarAsientoSAP(pacabecera,pacuentaMayor,pacuentaAcreedor,paimporte,paretencion,pnuasie,pOperOK,pMensOper);
    EXCEPTION
      WHEN EstadoSolicitud THEN
        pMensOper := 'Pr_InsertarAsientoCinco. ' || pMensOper;
        pOperOK := 'N';
      WHEN Others THEN
        pMensOper := 'Pr_InsertarAsientoCinco ' || sqlerrm;
        pOperOK := 'N';
  END Pr_InsertarAsientoCinco;

  --
  -- PROCEDIMIENTO QUE GENERA EL ASIENTO 2
  PROCEDURE Pr_InsertarAsientoSeis(pNuComp   IN NUMBER,
                                   pNuServ   IN NUMBER,
                                   pNuAsie   OUT VARCHAR2,
                                   pOperOK   OUT VARCHAR2,
                                   pMensOper OUT VARCHAR2) IS
    CURSOR cSolicitud(p_nucomp IN NUMBER, p_nuserv IN NUMBER) IS
      SELECT *
       FROM  sct_solidevo
       WHERE nucomp = p_nucomp
         AND nuserv = p_nuserv
         AND stregi = 'R';
    vSolicitud cSolicitud%RowType;
    --
    CURSOR cEntidadFinanciera(p_nucomp IN NUMBER, p_nuserv IN NUMBER, p_fcpagoorde DATE) IS
      SELECT nuentifina,centrocobro,nucuencont,toordedevobs
       FROM  scw_solidevo1
       WHERE nucomp = p_nucomp
         AND nuserv = p_nuserv
         AND trunc(fcpagoorde,'dd') = trunc(p_fcpagoorde,'dd')
         AND stregi = 'R'
      ORDER BY nuentifina;
    vEntidadFinanciera cEntidadFinanciera%RowType;
    --
    pacabecera       SGC_SO.SCPQ_ASIEDEVO.r_cabecera;
    pacuentaMayor    SGC_SO.SCPQ_ASIEDEVO.t_poscuenmayor;
    pacuentaAcreedor SGC_SO.SCPQ_ASIEDEVO.t_posacreedor;
    paimporte        SGC_SO.SCPQ_ASIEDEVO.t_importe;
    paretencion      SGC_SO.SCPQ_ASIEDEVO.t_retencion;
    --
    vfcregi          DATE;
    vctauno          VARCHAR2(10) := '2114623000';
    --Se cambia la cuenta dos que era de FASSIL 1112111025 el 24/04/2023 a solicitud de Marcia
    --vctados          VARCHAR2(10) := '1112111025'; --FASSIL
    vctados          VARCHAR2(10) := '1112120475'; --LA MERCED
    vnuitem          NUMBER;
    vnroasignacion   VARCHAR2(18);
    vnroposicion     NUMBER;
    vtextoposicion   VARCHAR2(50);
    vcddivi          VARCHAR2(4);
    --
    CuentaContable   EXCEPTION;
  BEGIN
    pOperOK := 'N';
    -- Datos de la cabecera
    vfcregi := sysdate;
    pacabecera.claseDocumento := 'IC';
    pacabecera.ejercicio := to_char(vFcRegi,'YYYY');
    --Modificado a solicitud de Paula Ponce 16/11/2022
    --pacabecera.usuario := 'sigecom';
    pacabecera.usuario := Fn_UsuarioSAP;
    pacabecera.fechaContabilizacion := to_char(vFcRegi,'YYYYMMDD');
    pacabecera.fechaDocumento := to_char(vFcRegi,'YYYYMMDD');
    pacabecera.mes := to_char(vFcRegi,'MM');
    pacabecera.nroDocumentoReferencia := rpad('Anul. Pago DCA',16,' ');
    pacabecera.textoCabecera := rpad('Anul. Pago Dev.Cert.Apor.',25,' ');
    --
    vnuitem := 0;
    vnroasignacion := NULL;
    vnroposicion := 0;
    vtextoposicion := NULL;
    --
    OPEN cSolicitud(pnucomp,pnuserv);
    FETCH cSolicitud INTO vSolicitud;
    CLOSE cSolicitud;
    -- Datos cuenta mayor e importe (entidades financieras)
    OPEN cEntidadFinanciera(pnucomp,pnuserv,vSolicitud.fcpagoorde);
    FETCH cEntidadFinanciera INTO vEntidadFinanciera;
    CLOSE cEntidadFinanciera;
    vnroasignacion := '44';
    vcddivi := Fn_DivisionCompañia(1);
    vtextoposicion := rpad('Anul. Pago Dev.Cert.Aport. ' || to_char(vSolicitud.fcpagoorde,'dd/mm/yy'),25,' ');
    --
    IF vEntidadFinanciera.nucuencont IS NULL THEN
      pMensOper := 'La entidad financiera ' || vEntidadFinanciera.centrocobro || ' no tiene definida su cuenta contable.';
      RAISE CuentaContable;
    END IF;
    vnuitem := vnuitem + 1;
    vnroposicion := vnroposicion + 1;
    --
    pacuentaMayor(vnuitem).cuentaMayor := vEntidadFinanciera.nucuencont; --vctados;
    pacuentaMayor(vnuitem).division:= vcddivi;
    pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
    pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
    pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
    --
    paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
    paimporte(vnuitem).moneda := 'BOB';
    paimporte(vnuitem).importe := to_char(vEntidadFinanciera.toordedevobs,'99999990.00');
    -- Datos cuenta mayor e importe (pago orden de devolución por socio)
    vnuitem := vnuitem + 1;
    vnroposicion := vnroposicion + 1;
    vnroasignacion := vSolicitud.idcert;
    vcddivi := Fn_DivisionCompañia(1);
    vtextoposicion := Fn_DescripcionTextoPosicion(vSolicitud.nucomp,vSolicitud.nuserv,'Anul. Pago DCA');
    --
    pacuentaMayor(vnuitem).cuentaMayor := vctauno;
    pacuentaMayor(vnuitem).division:= vcddivi;
    pacuentaMayor(vnuitem).nroAsignacion:= vnroasignacion;
    pacuentaMayor(vnuitem).nroPosicion:= lpad(to_char(vnroposicion),10,'0');
    pacuentaMayor(vnuitem).textoPosicion:= vtextoposicion;
    --
    paimporte(vnuitem).nroPosicion := lpad(to_char(vnroposicion),10,'0');
    paimporte(vnuitem).moneda := 'BOB';
    paimporte(vnuitem).importe := to_char(vSolicitud.toordedevobs * -1,'99999990.00');
    -- Llamar al procedimiento del asiento contable
    Pr_InsertarAsientoSAP(pacabecera,pacuentaMayor,pacuentaAcreedor,paimporte,paretencion,pnuasie,pOperOK,pMensOper);
    EXCEPTION
      WHEN CuentaContable THEN
        pMensOper := 'Pr_InsertarAsientoSeis. ' || pMensOper;
        pOperOK := 'N';
      WHEN Others THEN
        pMensOper := 'Pr_InsertarAsientoSeis ' || sqlerrm;
        pOperOK := 'N';
  END Pr_InsertarAsientoSeis;

  --
  -- PROCEDIMIENTO QUE LLAMA A UN WEBSAP PARA GENERAR EL ASIENTO CONTABLE
  PROCEDURE Pr_InsertarAsientoSAP(pacabecera     IN r_cabecera,
                                  paposcuenmayor IN t_poscuenmayor,
                                  paposacreedor  IN t_posacreedor,
                                  paimporte      IN t_importe,
                                  paretencion    IN t_retencion,
                                  pNuAsie        OUT VARCHAR2,
                                  pOperOK        OUT VARCHAR2,
                                  pMensOper      OUT VARCHAR2)
  IS
    cadenaXML                      clob; --VARCHAR2(32767);
    dsUrl                          VARCHAR2(3000); /*:= 'http://pi' || ambiente || '.cre.com.bo:50000/XISOAPAdapter/MessageServlet?senderParty=' ||
                                                     '&' || 'senderService=SIGECOM_'||sistema||'_BS'||'&'||'receiverParty='||'&'||
                                                     'receiverService='||'&'||'interface=fi_documentos_cxp_si'||'&'||
                                                     'interfaceNamespace=urn:cre:fi:documentos';*/
    dsSoapActi                     VARCHAR2(100) := 'http://sap.com/xi/WebService/soap1.1';
    respXML                        Sys.XmlType;
    respHTTP                       VARCHAR2(32767);
    http_requ                      Utl_http.req;
    http_resp                      Utl_http.resp;
    cabecera                       clob; --VARCHAR2(1000);
    posicionesCuentaMayor          clob; --VARCHAR2(7500);
    items_posicionesCuentaMayor    clob; --VARCHAR2(7000);
    posicionesCuentaAcreedor       clob; --VARCHAR2(4000);
    items_posicionesCuentaAcreedor clob; --VARCHAR2(3000);
    posicionesImporte              clob; --VARCHAR2(4000);
    items_posicionesImporte        clob; --VARCHAR2(3000);
    posicionesRetencion            clob; --VARCHAR2(4000);
    items_posicionesRetencion      clob; --VARCHAR2(3000);
    contador                       NUMBER;
    vAsiento                       TAsiento;
    verror                         VARCHAR2(10000);
    vAmbienteSAP                   VARCHAR2(3);
    vSistemaSAP                    VARCHAR2(3);
    vOperOK                        VARCHAR2(1);
    vMensOper                      VARCHAR2(200);
    NoAmbienteSAP                  EXCEPTION;
    --
    req_length                     binary_integer;
    buffer                         VARCHAR2(2000);
    amount                         pls_integer := 2000;
    offset                         pls_integer := 1;
  BEGIN
--dbms_output.PUT_LINE('Pr_InsertarAsientoSAP');
    pOperOK := 'N';
    -- Determinando el ambiente SAP --
    /*Pr_AmbienteSAP(vAmbienteSAP,vSistemaSAP,vOperOK,vMensOper);
    IF vOperOK = 'N' THEN
      RAISE NoAmbienteSAP;
    END IF;*/
    IF cbpq_coblinweb_util.Fn_EsProduccion = 'S' THEN
      --Produccion
      dbms_output.PUT_LINE('*** Producción ***');
      dsUrl := 'http://vpoprd.cre.com.bo:50000/XISOAPAdapter/MessageServlet?senderParty=' ||
             '&' || 'senderService=SIGECOM_PRD_BS'||'&'||'receiverParty='||'&'||
             'receiverService='||'&'||'interface=fi_documentos_cxp_si'||'&'||
             'interfaceNamespace=urn:cre:fi:documentos';
      dbms_output.PUT_LINE(dsUrl);
      --dsUrl := 'http://pi' || vAmbienteSAP || '.cre.com.bo:50000/XISOAPAdapter/MessageServlet?senderParty=' ||
      --       '&' || 'senderService=SIGECOM_'||vSistemaSAP||'_BS'||'&'||'receiverParty='||'&'||
      --       'receiverService='||'&'||'interface=fi_documentos_cxp_si'||'&'||
      --       'interfaceNamespace=urn:cre:fi:documentos';
    ELSE
      --Desarrollo
      dbms_output.PUT_LINE('*** Desarrollo ***');
      dsUrl := 'http://vpodev.cre.com.bo:50000/XISOAPAdapter/MessageServlet?senderParty=' ||
             '&' || 'senderService=SIGECOM_DEV_BS'||'&'||'receiverParty='||'&'||
             'receiverService='||'&'||'interface=fi_documentos_cxp_si'||'&'||
             'interfaceNamespace=urn:cre:fi:documentos';
      dbms_output.PUT_LINE(dsUrl);
      --dsUrl := 'http://pi' || vAmbienteSAP || '.cre.com.bo:50000/XISOAPAdapter/MessageServlet?senderParty=' ||
      --       '&' || 'senderService=SIGECOM_'||vSistemaSAP||'_BS'||'&'||'receiverParty='||'&'||
      --       'receiverService='||'&'||'interface=fi_documentos_cxp_si'||'&'||
      --       'interfaceNamespace=urn:cre:fi:documentos';
    END IF;
--dbms_output.PUT_LINE('Cabecera');
    ----- Armando la cabecera -----
    cabecera := '<cabecera>'||
                '<operacion_empresarial>'|| pacabecera.operacionEmpresarial || '</operacion_empresarial>'||
                '<usuario>' || pacabecera.usuario || '</usuario>' ||
                '<texto_cabecera>' || pacabecera.textoCabecera || '</texto_cabecera>' ||
                '<sociedad>' || pacabecera.sociedad || '</sociedad>' ||
                '<fecha_documento>' || pacabecera.fechaDocumento || '</fecha_documento>' ||
                '<fecha_contabilizacion>' || pacabecera.fechaContabilizacion || '</fecha_contabilizacion>' ||
                '<ejercicio>' || pacabecera.ejercicio || '</ejercicio>' ||
                '<mes>' || pacabecera.mes || '</mes>' ||
                '<clase_documento>' || pacabecera.claseDocumento || '</clase_documento>' ||
                '<nro_documento_referencia>' || pacabecera.nroDocumentoReferencia || '</nro_documento_referencia>' ||
                '</cabecera>';
    ----- Armando la cuenta mayor -----
--dbms_output.PUT_LINE('Cuenta mayor');
    items_posicionesCuentaMayor := '';
    FOR i IN paposcuenmayor.FIRST .. paposcuenmayor.LAST
    LOOP
      items_posicionesCuentaMayor := items_posicionesCuentaMayor ||
                                     '<posicion>' ||
                                       '<nro_posicion>' || paposcuenmayor(i).nroPosicion || '</nro_posicion>' ||
                                       '<cuenta_de_mayor>' || paposcuenmayor(i).cuentaMayor || '</cuenta_de_mayor>' ||
                                       '<texto_posicion>' || paposcuenmayor(i).textoPosicion || '</texto_posicion>' ||
                                       '<clase_documento>'|| paposcuenmayor(i).claseDocumento || '</clase_documento>'||
                                       '<sociedad>' || paposcuenmayor(i).sociedad || '</sociedad>' ||
                                       '<division>' || paposcuenmayor(i).division || '</division>' ||
                                       '<nro_asignacion>' || paposcuenmayor(i).nroAsignacion || '</nro_asignacion>' ||
                                       '<indicador_impuesto>' || paposcuenmayor(i).indicadorImpuesto || '</indicador_impuesto>' ||
                                       '<centro_costo>' || paposcuenmayor(i).centroCosto || '</centro_costo>' ||
                                     '</posicion>';
    END LOOP;
    posicionesCuentaMayor := '<posiciones_cuenta_mayor>' || items_posicionesCuentaMayor || '</posiciones_cuenta_mayor>';
    ----- Armando la cuenta acreedor -----
--dbms_output.PUT_LINE('Cuenta acreedor');
    IF paposacreedor.COUNT > 0 THEN
      items_posicionesCuentaAcreedor := '';
      FOR i IN paposacreedor.FIRST .. paposacreedor.LAST
      LOOP
        items_posicionesCuentaAcreedor := items_posicionesCuentaAcreedor ||
                                          '<posicion>' ||
                                            '<nro_posicion>' || paposacreedor(i).nroPosicion || '</nro_posicion>' ||
                                            '<nro_cuenta_acreedor>' || paposacreedor(i).nroCuentaAcreedor || '</nro_cuenta_acreedor>' ||
                                            '<cuenta_de_mayor>' || paposacreedor(i).cuentaMayor || '</cuenta_de_mayor>' ||
                                            '<sociedad>' || paposacreedor(i).sociedad || '</sociedad>' ||
                                            '<division>' || paposacreedor(i).division || '</division>' ||
                                            '<clave_condicion_pago>' || paposacreedor(i).claveCondicionPago || '</clave_condicion_pago>' ||
                                            '<clave_bloqueo_pago>' || paposacreedor(i).claveBloqueoPago || '</clave_bloqueo_pago>' ||
                                            '<nro_asignacion>' || paposacreedor(i).nroAsignacion || '</nro_asignacion>' ||
                                            '<texto_posicion>' || paposacreedor(i).textoPosicion || '</texto_posicion>' ||
                                            '<indicador_impuesto>' || paposacreedor(i).indicadorImpuesto || '</indicador_impuesto>' ||
                                          '</posicion>';
      END LOOP;
      posicionesCuentaAcreedor := '<posiciones_acreedor>' || items_posicionesCuentaAcreedor || '</posiciones_acreedor>';
    END IF;
    ----- Armando los importes -----
--dbms_output.PUT_LINE('Importes');
    items_posicionesImporte := '';
    FOR i IN paimporte.FIRST .. paimporte.LAST
    LOOP
      items_posicionesImporte := items_posicionesImporte ||
                                 '<posicion>' ||
                                   '<nro_posicion>' || paimporte(i).nroPosicion || '</nro_posicion>' ||
                                   '<moneda>' || paimporte(i).moneda || '</moneda>' ||
                                   '<importe>' || paimporte(i).importe || '</importe>' ||
                                   '<importe_base_impuesto>' || paimporte(i).importe_base_impuesto || '</importe_base_impuesto>' ||
                                 '</posicion>';
    END LOOP;
    posicionesImporte := '<posiciones_importe>' || items_posicionesImporte || '</posiciones_importe>';
    ----- Armando las retenciones -----
--dbms_output.PUT_LINE('Retenciones');
    IF paretencion.COUNT > 0 THEN
      items_posicionesRetencion := '';
      FOR i IN paretencion.FIRST .. paretencion.LAST
      LOOP
        items_posicionesRetencion := items_posicionesRetencion ||
                                     '<posicion>' ||
                                       '<nro_posicion>' || paretencion(i).nroPosicion || '</nro_posicion>' ||
                                       '<tipo_retencion>' || paretencion(i).tipoRetencion || '</tipo_retencion>' ||
                                       '<codigo_retencion>' || paretencion(i).codigoRetencion || '</codigo_retencion>' ||
                                     '</posicion>';
      END LOOP;
      posicionesRetencion := '<posiciones_retenciones>' || items_posicionesRetencion || '</posiciones_retenciones>';
    END IF;
    ----- Armando la cadena XML -----
    --paso := '1';
--dbms_output.PUT_LINE('CadenaXML');
    cadenaXML := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:cre:fi:documentos">'||
                 '<soapenv:Header/>' ||
                 '<soapenv:Body>'||
                 '<urn:crear_documento_cxp_req_mt>'||
                 cabecera ||
                 posicionesCuentaMayor ||
                 posicionesCuentaAcreedor ||
                 posicionesImporte ||
                 posicionesRetencion ||
                 '</urn:crear_documento_cxp_req_mt>'||
                 ' </soapenv:Body>'||
                '</soapenv:Envelope>';
    --paso := '2';
    http_requ := UTL_HTTP.BEGIN_REQUEST(dsurl,'POST','HTTP/1.1');
    UTL_HTTP.SET_AUTHENTICATION(http_requ, 'sigecom','sigpi731');
    UTL_HTTP.SET_BODY_CHARSET(http_requ,'UTF-8');
    UTL_HTTP.set_header(http_requ, 'Content-Type', 'text/xml;charset=UTF-8');
    UTL_HTTP.set_header(http_requ, 'Transfer-Encoding','chunked');
    --UTL_HTTP.set_header(http_requ, 'Content-Length', LENGTH(cadenaXML));
    UTL_HTTP.set_header(http_requ, 'SOAPAction',dsSoapActi);

dbms_output.PUT_LINE('Envio CadenaXML');
    req_length := DBMS_LOB.getlength(cadenaXML);
    WHILE (offset < req_length)
     LOOP
       DBMS_LOB.read (cadenaXML,
                        amount,
                        offset,
                        buffer);
       UTL_HTTP.write_text(http_requ, buffer);
dbms_output.PUT_LINE(buffer);
       offset := offset + amount;
     END LOOP;

    --paso := '3';
    --utl_http.write_text(http_requ, cadenaXML);
    --paso := '4';
    ----- Capturando la respuesta del servicio HTTP -----
--dbms_output.PUT_LINE('GET_RESPONSE');
    http_resp := UTL_HTTP.GET_RESPONSE(http_requ);
    --paso := '5';
    UTL_HTTP.READ_TEXT(http_resp,respHttp);
    --paso := '6';
    UTL_HTTP.END_RESPONSE(http_resp);
    --paso := '7';
--dbms_output.PUT_LINE('respXML');
    respXML := XMLTYPE.createxml(respHttp);
dbms_output.PUT_LINE('Respuesta respHttp');
dbms_output.PUT_LINE(respHttp);
    -----
    contador := 1;
    verror := '';
    WHILE (respXML.existsNode('//item[' || contador || ']') = 1) --existsNode devuelve 0=No existe o 1=Existe
    LOOP
      IF respXML.extract('//item[' || contador || ']/tipo/text()') IS NOT NULL THEN
        vAsiento(contador).tipo := respXML.extract('//item[' || contador || ']/tipo/text()').getStringVal();
      END IF;
      IF respXML.extract('//item[' || contador || ']/texto_mensaje/text()') IS NOT NULL THEN
        vAsiento(contador).texto_mensaje := respXML.extract('//item[' || contador || ']/texto_mensaje/text()').getStringVal();
        verror := verror || vAsiento(contador).texto_mensaje;
      END IF;
      IF respXML.extract('//item[' || contador || ']/mensaje_v1/text()') IS NOT NULL THEN
        vAsiento(contador).mensaje_v1 := respXML.extract('//item[' || contador || ']/mensaje_v1/text()').getStringVal();
        verror := verror || ', ' || vAsiento(contador).mensaje_v1;
      END IF;
      IF respXML.extract('//item[' || contador || ']/mensaje_v2/text()') IS NOT NULL THEN
        vAsiento(contador).mensaje_v2 := respXML.extract('//item[' || contador || ']/mensaje_v2/text()').getStringVal();
        verror := verror || ', ' || vAsiento(contador).mensaje_v2;
      END IF;
      IF respXML.extract('//item[' || contador || ']/mensaje_v3/text()') IS NOT NULL THEN
        vAsiento(contador).mensaje_v3 := respXML.extract('//item[' || contador || ']/mensaje_v3/text()').getStringVal();
        verror := verror || ', ' || vAsiento(contador).mensaje_v3;
      END IF;
      IF respXML.extract('//item[' || contador || ']/mensaje_v4/text()') IS NOT NULL THEN
        vAsiento(contador).mensaje_v4 := respXML.extract('//item[' || contador || ']/mensaje_v4/text()').getStringVal();
        verror := verror || ', ' || vAsiento(contador).mensaje_v4;
      END IF;
      verror := verror || chr(13) || chr(10) || chr(13) || chr(10);
      contador := contador + 1;
    END LOOP;
dbms_output.PUT_LINE('Luego de analisis');
    IF vAsiento(1).tipo = 'S' THEN
      pOperOK := 'S';
      pnuasie := vAsiento(1).mensaje_v2;
      pnuasie := SUBSTR(pnuasie,1,10);
dbms_output.PUT_LINE('pnuasie ' || pnuasie);
    ELSE
dbms_output.PUT_LINE('No encontro asiento');
      pOperOK := 'N';
      pMensOper := verror;
dbms_output.PUT_LINE('Error ' || verror);
    END IF;
  EXCEPTION
    WHEN NoAmbienteSAP THEN
dbms_output.PUT_LINE('NoAmbienteSAP');
      pOperOK := 'N';
      pMensOper := vMensOper;
    WHEN UTL_HTTP.REQUEST_FAILED THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. The request fails to executes';
      UTL_HTTP.END_RESPONSE(http_resp);
    WHEN UTL_HTTP.BAD_URL THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. The request URL is badly formed';
    WHEN UTL_HTTP.BAD_ARGUMENT THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. The argument passed to the interface is bad';
    WHEN UTL_HTTP.PROTOCOL_ERROR THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. An HTTP protocol error occurs when communicating with the Web server';
      UTL_HTTP.END_RESPONSE(http_resp);
    WHEN UTL_HTTP.END_OF_BODY THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. The end of HTTP response body is reached';
      UTL_HTTP.END_RESPONSE(http_resp);
    WHEN UTL_HTTP.HTTP_CLIENT_ERROR THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. A client error has ocurred';
      UTL_HTTP.END_RESPONSE(http_resp);
    WHEN UTL_HTTP.HTTP_SERVER_ERROR THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. A server error has ocurred';
      UTL_HTTP.END_RESPONSE(http_resp);
    WHEN UTL_HTTP.TRANSFER_TIMEOUT THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. No data is read and a read timeout ocurred';
      UTL_HTTP.END_RESPONSE(http_resp);
    WHEN OTHERS THEN
      pOperOK := 'N';
      pMensOper := SqlErrm;
  END Pr_InsertarAsientoSAP;

  -- FUNCION QUE DEVUELVE LA COMUNICACION INTERNA DE APROBACION DEL CUADRO
  FUNCTION Fn_CiCuadro(pIdCuad IN NUMBER)
    RETURN VARCHAR IS
    CURSOR cCuadro IS
      SELECT *
       FROM  sct_cuaddevo
       WHERE idcuad = pIdCuad;
    vCuadro   cCuadro%RowType;
    vnuciapro VARCHAR2(50);
  BEGIN
    OPEN cCuadro;
    FETCH cCuadro INTO vCuadro;
    CLOSE cCuadro;
    vnuciapro := vCuadro.nuciapro;
    RETURN vnuciapro;
  END Fn_CiCuadro;

  -- FUNCION QUE DEVUELVE LA DIVISION DE LA COMPAÑÍA
  FUNCTION Fn_DivisionCompañia(pNuComp IN NUMBER)
    RETURN VARCHAR IS
    CURSOR cDivision IS
      SELECT cddivi
       FROM  mgm_comp
       WHERE nucomp = pnucomp;
    vcddivi VARCHAR2(4);
  BEGIN
    OPEN cDivision;
    FETCH cDivision INTO vcddivi;
    CLOSE cDivision;
    RETURN vcddivi;
  END Fn_DivisionCompañia;

  --FUNCION QUE DEVUELVE DESCRIPCION DEL TEXTO POSICION
  FUNCTION Fn_DescripcionTextoPosicion(pNuComp IN NUMBER,
                                       pNuServ IN NUMBER,
                                       pDsText IN VARCHAR2)
    RETURN VARCHAR IS
    CURSOR cServicio IS
      SELECT *
       FROM  sot_serv
       WHERE nucomp = pnucomp
         AND nuserv = pnuserv;
    vServicio cServicio%RowType;
    vnomb     VARCHAR2(180);
    vauxi     VARCHAR2(200);
  BEGIN
    OPEN cServicio;
    FETCH cServicio INTO vServicio;
    CLOSE cServicio;
    vnomb := Fn_NombreCliente(vServicio.nucomp,vServicio.nuserv);
    --50 caracteres
    IF vServicio.nucuen > 0 THEN
      vauxi := pdstext || ' ' || vServicio.nucuen || '-' || vServicio.nucomp || ' ' || vnomb;
    ELSE
      vauxi := pdstext || ' ' || vServicio.nuserv || '-' || vServicio.nucomp || ' ' || vnomb;
    END IF;
    IF length(vauxi) > 50 THEN
      vauxi := substr(vauxi,0,50);
    END IF;
    RETURN vauxi;
  END Fn_DescripcionTextoPosicion;

  --FUNCION QUE DEVUELVE DESCRIPCION DEL TEXTO POSICION ANULACION
  FUNCTION Fn_DescripcionTextoPosicionAnu(pNuComp IN NUMBER,
                                          pNuServ IN NUMBER,
                                          pDsText IN VARCHAR2)
    RETURN VARCHAR IS
    CURSOR cServicio IS
      SELECT *
       FROM  sot_serv
       WHERE nucomp = pnucomp
         AND nuserv = pnuserv;
    vServicio cServicio%RowType;
    vnomb     VARCHAR2(180);
    vauxi     VARCHAR2(200);
  BEGIN
    OPEN cServicio;
    FETCH cServicio INTO vServicio;
    CLOSE cServicio;
    vnomb := Fn_NombreClienteAnul(vServicio.nucomp,vServicio.nuserv);
    --50 caracteres
    IF vServicio.nucuen > 0 THEN
      vauxi := pdstext || ' ' || vServicio.nucuen || '-' || vServicio.nucomp || ' ' || vnomb;
    ELSE
      vauxi := pdstext || ' ' || vServicio.nuserv || '-' || vServicio.nucomp || ' ' || vnomb;
    END IF;
    IF length(vauxi) > 50 THEN
      vauxi := substr(vauxi,0,50);
    END IF;
    RETURN vauxi;
  END Fn_DescripcionTextoPosicionAnu;

  -- FUNCION QUE DEVUELVE EL NOMBRE DEL CLIENTE
  FUNCTION Fn_NombreCliente(pNuComp IN NUMBER,
                            pNuServ IN NUMBER)
    RETURN VARCHAR IS
    CURSOR cPago IS
      SELECT pa.*
       FROM  fam_pagoexol pa, sct_solidevo de
       WHERE de.nucomp = pnucomp
         AND de.nuserv = pnuserv
         AND pa.nucomp = de.nucomp
         AND pa.nupagoexol = de.nupagoexol;
    vPago cPago%RowType;
    vdsnomb fam_pagoexol.dsnomb%Type;
  BEGIN
    vdsnomb := '';
    OPEN cPago;
    FETCH cPago INTO vPago;
    IF cPago%FOUND THEN
      vdsnomb := vPago.dsnomb;
    END IF;
    CLOSE cPago;
    RETURN vdsnomb;
  END Fn_NombreCliente;

  -- FUNCION QUE DEVUELVE EL NOMBRE DEL CLIENTE ANULACION
  FUNCTION Fn_NombreClienteAnul(pNuComp IN NUMBER,
                                pNuServ IN NUMBER)
    RETURN VARCHAR IS
    CURSOR cPago IS
      SELECT pa.*
       FROM  fam_pagoexol pa, sct_solidevo de, ajt_ajuspago aj
       WHERE de.nucomp = pnucomp
         AND de.nuserv = pnuserv
         AND aj.nucomp = de.nucomp
         AND aj.nupagonuev = de.nupagoexol
         AND pa.nucomp = aj.nucomp
         AND pa.nupagoexol = aj.nupago;
    vPago cPago%RowType;
    vdsnomb fam_pagoexol.dsnomb%Type;
  BEGIN
    vdsnomb := '';
    OPEN cPago;
    FETCH cPago INTO vPago;
    IF cPago%FOUND THEN
      vdsnomb := vPago.dsnomb;
    END IF;
    CLOSE cPago;
    RETURN vdsnomb;
  END Fn_NombreClienteAnul;

  -- PROCEDIMIENTO QUE DEVUELVE EL AMBIENTE SAP
  PROCEDURE Pr_AmbienteSAP(pAmbienteSAP OUT VARCHAR2,
                           pSistemaSAP  OUT VARCHAR2,
                           pOperOK      OUT VARCHAR2,
                           pMensOper    OUT VARCHAR2) IS
    vAmbienteBD VARCHAR2(10);
  BEGIN
    vAmbienteBD := Fn_AmbienteBaseDatos;
    CASE vAmbienteBD
      WHEN 'CRE' THEN
        pAmbienteSAP := 'prd';
        pSistemaSAP := 'PRD';
        pOperOK := 'S';
        pMensOper := '';
      WHEN 'CRECAP' THEN
        pAmbienteSAP := 'qas';
        pSistemaSAP := 'QAS';
        pOperOK := 'S';
        pMensOper := '';
      WHEN 'CREDES' THEN
        pAmbienteSAP := 'dev';
        pSistemaSAP := 'DEV';
        pOperOK := 'S';
        pMensOper := '';
      ELSE
        pAmbienteSAP := '';
        pSistemaSAP := '';
        pOperOK := 'N';
        pMensOper := 'NO SE PUDO RECUPERAR EL AMBIENTE DE BASE DE DATOS PARA GENERAR EL ENLACE SAP';
    END CASE;
  END;

  -- FUNCION QUE DEVUELVE EL AMBIENTE DE LA BASE DE DATOS
  FUNCTION Fn_AmbienteBaseDatos
    RETURN VARCHAR IS
    CURSOR cAmbiente IS
      SELECT MAX(Property_value) ambiente
       FROM  Database_properties
       WHERE Property_name = 'GLOBAL_DB_NAME';
    vAmbiente cAmbiente%RowType;
  BEGIN
    OPEN cAmbiente;
    FETCH cAmbiente INTO vAmbiente;
    CLOSE cAmbiente;
    RETURN vAmbiente.ambiente;
  END;

  --
  -- FUNCION QUE DEVUELVE EL USUARIO SAP
  FUNCTION Fn_UsuarioSAP
    RETURN VARCHAR2
  IS
    vUsuarioSAP VARCHAR2(12);
  BEGIN
    IF cbpq_coblinweb_util.Fn_EsProduccion = 'S' THEN
      vUsuarioSAP := CD_USUA_SAP_PRD;
    ELSE
      vUsuarioSAP := CD_USUA_SAP_DEV;
    END IF;
    return vUsuarioSAP;
  END Fn_UsuarioSAP;

  --
  -- PROCEDIMIENTO QUE LLAMA A UN WEBSAP PARA RECUPERAR EL ESTADO DE UN ASIENTO
  PROCEDURE Pr_RecuperarEstadoAsiento(pNuDocu        IN VARCHAR2,
                                      pEjercicio     IN NUMBER,
                                      pEstadoAsiento OUT TEstadoAsiento,
                                      pOperOK        OUT VARCHAR2,
                                      pMensOper      OUT VARCHAR2) IS
    env               VARCHAR2(32767);
    res               VARCHAR2(32767);
    http_requ         UTL_HTTP.req;
    http_resp         UTL_HTTP.resp;
    -- DESARROLLO
    ampersand         VARCHAR2(1) := CHR(38);
    url               VARCHAR2(2000);
    soapaction        VARCHAR2(100) := 'http://sap.com/xi/WebService/soap1.1';
    dsautenticacion   VARCHAR2(100) := '';
    respXML           SYS.XMLTYPE;
    vvalor            VARCHAR2(100);
    nuerro            NUMBER;
    dsmens            VARCHAR2(300);
    contador          NUMBER;
    vAsiento          SGC_SO.SCPQ_AMI.TAnularAsiento;
    vnuasie           VARCHAR2(20);
    vEstado           VARCHAR2(30);
    vSociedad         VARCHAR2(20);
  BEGIN
    pOperOK := 'N';
    IF cbpq_coblinweb_util.Fn_EsProduccion = 'S' THEN
      --Produccion
      url := 'http://vpoprd.cre.com.bo:50000/XISOAPAdapter/MessageServlet?senderParty=' ||
               '&' || 'senderService=SIGECOM_PRD_BS'||'&'||'receiverParty='||'&'||
               'receiverService='||'&'||'interface=fi_documentos_contables_si'||'&'||
               'interfaceNamespace=urn:cre:fi:documentos';
    ELSE
      --Desarrollo
      url := 'http://vpodev.cre.com.bo:50000/XISOAPAdapter/MessageServlet?senderParty=' ||
             '&' || 'senderService=SIGECOM_DEV_BS'||'&'||'receiverParty='||'&'||
             'receiverService='||'&'||'interface=fi_documentos_contables_si'||'&'||
             'interfaceNamespace=urn:cre:fi:documentos';
    END IF;
    ----- Armando la cadena XML -----
    --paso := '1';
    env := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:cre:fi:documentos"> '
         || '<soapenv:Header/> '
         || '<soapenv:Body> '
         || '<urn:consultar_estado_doc_contable_fi_req_mt> '
         --|| '<numero_documento>4009017</numero_documento> '
         || '<numero_documento>' || pnudocu || '</numero_documento> '
         --|| '<ejercicio>2022</ejercicio> '
         || '<ejercicio>' || pEjercicio || '</ejercicio> '
         || '</urn:consultar_estado_doc_contable_fi_req_mt> '
         || '</soapenv:Body> '
         || '</soapenv:Envelope>';
    --paso := '2';
    http_requ := UTL_HTTP.begin_request(url, 'POST', 'HTTP/1.1');
    UTL_HTTP.set_authentication (http_requ, 'sigecom', 'sigpi731');
    UTL_HTTP.set_body_charset (http_requ, 'UTF-8');
    UTL_HTTP.set_header (http_requ, 'Content-Type', 'text/xml');
    UTL_HTTP.set_header (http_requ, 'Content-Length', LENGTH (env));
    UTL_HTTP.set_header (http_requ, 'SOAPAction', soapaction);
    --paso := '3';
    UTL_HTTP.write_text (http_requ, env);
    dbms_output.PUT_LINE('Envio env');
    dbms_output.PUT_LINE(env);
    ----- Capturando la respuesta del servicio HTTP -----
    --paso := '4';
    http_resp := UTL_HTTP.get_response (http_requ);
    --paso := '5';
    UTL_HTTP.read_text (http_resp, res);
    --paso := '6';
    UTL_HTTP.end_response (http_resp);
    --paso := '7';
    dbms_output.PUT_LINE('Respuesta res');
    DBMS_OUTPUT.put_line (res);
    respXML := XMLTYPE.createxml(res);
    -----
    contador := 1;
    WHILE (respXML.existsNode('//estado_documento_contable[' || contador || ']') = 1) --existsNode devuelve 0=No existe o 1=Existe
    LOOP
      IF respXML.extract('//estado_documento_contable[' || contador || ']/text()') IS NOT NULL THEN
        pEstadoAsiento(contador).estado_documento_contable := respXML.extract('//estado_documento_contable[' || contador || ']/text()').getStringVAl();
      END IF;
      IF respXML.extract('//sociedad[' || contador || ']/text()') IS NOT NULL THEN
        pEstadoAsiento(contador).sociedad := respXML.extract('//sociedad[' || contador || ']/text()').getStringVAl();
      END IF;
      IF respXML.extract('//numero_documento_anulacion[' || contador || ']/text()') IS NOT NULL THEN
        pEstadoAsiento(contador).numero_documento_anulacion := respXML.extract('//numero_documento_anulacion[' || contador || ']/text()').getStringVAl();
      END IF;
      IF respXML.extract('//ejercicio_documento_anulacion[' || contador || ']/text()') IS NOT NULL THEN
        pEstadoAsiento(contador).ejercicio_documento_anulacion := respXML.extract('//ejercicio_documento_anulacion[' || contador || ']/text()').getStringVAl();
      END IF;
      IF respXML.extract('//numero_documento_compensacion[' || contador || ']/text()') IS NOT NULL THEN
        pEstadoAsiento(contador).numero_documento_compensacion := respXML.extract('//numero_documento_compensacion[' || contador || ']/text()').getStringVAl();
      END IF;
      IF respXML.extract('//fecha_documento_compensacion[' || contador || ']/text()') IS NOT NULL THEN
        pEstadoAsiento(contador).fecha_documento_compensacion := respXML.extract('//fecha_documento_compensacion[' || contador || ']/text()').getStringVAl();
        --pEstadoAsiento(contador).fecha_documento_compensacion := to_date(respXML.extract('//fecha_documento_compensacion[' || contador || ']/text()').getStringVAl(),'yyyy-mm-dd');
      END IF;
      pOperOK := 'S';
      EXIT;
    END LOOP;
    IF pOperOk = 'N' THEN
      pMensOper := 'No se pudo recuperar el estado del asiento. ';
    END IF;
  EXCEPTION
    WHEN UTL_HTTP.REQUEST_FAILED THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. The request fails to executes';
      UTL_HTTP.END_RESPONSE(http_resp);
    WHEN UTL_HTTP.BAD_URL THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. The request URL is badly formed';
    WHEN UTL_HTTP.BAD_ARGUMENT THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. The argument passed to the interface is bad';
    WHEN UTL_HTTP.PROTOCOL_ERROR THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. An HTTP protocol error occurs when communicating with the Web server';
      UTL_HTTP.END_RESPONSE(http_resp);
    WHEN UTL_HTTP.END_OF_BODY THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. The end of HTTP response body is reached';
      UTL_HTTP.END_RESPONSE(http_resp);
    WHEN UTL_HTTP.HTTP_CLIENT_ERROR THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. A client error has ocurred';
      UTL_HTTP.END_RESPONSE(http_resp);
    WHEN UTL_HTTP.HTTP_SERVER_ERROR THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. A server error has ocurred';
      UTL_HTTP.END_RESPONSE(http_resp);
    WHEN UTL_HTTP.TRANSFER_TIMEOUT THEN
      pOperOK := 'N';
      pMensOper := 'No se pudo generar el registro del asiento contable. No data is read and a read timeout ocurred';
      UTL_HTTP.END_RESPONSE(http_resp);
    WHEN OTHERS THEN
      pOperOK := 'N';
      pMensOper := SqlErrm;
  END Pr_RecuperarEstadoAsiento;
END SCPQ_ASIEDEVO;