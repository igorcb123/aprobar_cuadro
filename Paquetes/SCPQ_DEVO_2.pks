/*******************************************************************************
 * METADATA
 * Analista     : IGORCB
 * Descargado   : 06/10/2026, 10:07:05
 * Owner        : SGC_SO
 * Versión      : 2
 *******************************************************************************/
CREATE OR REPLACE PACKAGE SGC_SO.Scpq_Devo AS
    PROCEDURE Pr_Autorizar_Impresion (Pnucomp NUMBER, Pnuserv NUMBER, Pdtglos VARCHAR2);
    FUNCTION Fn_Impresion_Autorizada (Pnucomp NUMBER, Pnuserv NUMBER) RETURN VARCHAR2;
    PROCEDURE Pr_Jobasiepagodevo (Pa_Idproc NUMBER DEFAULT NULL, Pa_Idbitaproc NUMBER DEFAULT NULL);
    FUNCTION Fn_Nombresocio (Pnusoci NUMBER, Fc DATE := SYSDATE) RETURN VARCHAR2;
    PROCEDURE Pr_Nuevoservicio (Pnusocirenu NUMBER, Pidcert NUMBER, Pnutele NUMBER,
                                Pcdmoti VARCHAR2, Pdtserv VARCHAR2, Pnucart NUMBER,
                                Poppagodeud VARCHAR2, Poprequ VARCHAR2, Popcertmedi VARCHAR2,
                                Operacionexitosa OUT BOOLEAN, Mensaje OUT VARCHAR2);
    PROCEDURE Pr_Actualizadevo (Pnucomp NUMBER, Pnuserv NUMBER);
    PROCEDURE Pr_Arregla_Decimales (Pnucomp NUMBER, Pnuserv NUMBER);
    PROCEDURE Pr_Asientocuadro (Pidcuad NUMBER, Pnuasie VARCHAR2, Ptiasie VARCHAR2);
    PROCEDURE Pr_Actualizacuadro (Pidcuad NUMBER);
    PROCEDURE Pr_Prevalidarcuadro (Pidcuad NUMBER, Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2);
    PROCEDURE Pr_Registrar_Error_Cuadro (Pidcuad NUMBER, Petapa VARCHAR2, Perror VARCHAR2);
    PROCEDURE Pr_Iniciar_Liquidacion (Pnucomp NUMBER, Pnucargabon NUMBER,
                                      Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2);
    PROCEDURE Pr_Finalizar_Liquidacion (Pnucomp NUMBER, Pnucargabon NUMBER,
                                        Pnupagoexol NUMBER,
                                        Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2);
    PROCEDURE Pr_Abortar_Liquidacion (Pnucomp NUMBER, Pnucargabon NUMBER,
                                      Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2);
    PROCEDURE Pr_Recuperar_Liquidacion (Pidcuad NUMBER,
                                        Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2);
    PROCEDURE Pr_Liberar_Liquidacion_Cuadro (Pidcuad NUMBER,
                                             Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2);
    PROCEDURE Pr_Verificar_Bloqueo_Emision (Pnupagoexol NUMBER,
                                            Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2);
    PROCEDURE Pr_Liberar_Bloqueo_Liquidacion (Opexitosa OUT VARCHAR2, Pmensaje OUT VARCHAR2);
    PROCEDURE Pr_Asientosolicitud (Pnucomp NUMBER, Pnuserv NUMBER, Pnuasie VARCHAR2, Ptiasie VARCHAR2);
    PROCEDURE Pr_Asientopagos (Fc DATE DEFAULT SYSDATE);
    PROCEDURE Pr_Datospago (Pnucomp NUMBER, Pnuserv NUMBER, Ctfact OUT NUMBER, Mofact OUT NUMBER);
    FUNCTION Fn_Ctfactpago (Pnucomp NUMBER, Pnuserv NUMBER) RETURN NUMBER;
    FUNCTION Fn_Mofactpago (Pnucomp NUMBER, Pnuserv NUMBER) RETURN NUMBER;
    PROCEDURE Pr_Generadevolucion (P_Nucomp NUMBER, P_Cdmoti VARCHAR2, P_Nucuen NUMBER,
                                   P_Nusocirenu NUMBER, P_Nuclierenu NUMBER, P_Idcert NUMBER,
                                   P_Dtserv VARCHAR2, P_Nuempl NUMBER, P_Nuofic NUMBER,
                                   P_Nuserv IN OUT NUMBER, P_Nucart NUMBER, P_Fccart DATE,
                                   P_Nutele VARCHAR2, P_Opcertmedi VARCHAR2, P_Oprequ VARCHAR2,
                                   P_Oppagodeud VARCHAR2, Operacionexitosa IN OUT BOOLEAN,
                                   Mensaje IN OUT VARCHAR2);
    PROCEDURE Pr_Actualiza_Facturas_Pagadas (Pidcuad NUMBER);
    PROCEDURE Pr_Asientovencimiento (Pnucomp NUMBER, Pnuserv NUMBER, Pdtglos VARCHAR2,
                                     Operacionexitosa OUT VARCHAR2, Mensaje OUT VARCHAR2);
    PROCEDURE Pr_Revertir_Solicitud (Pnucomp NUMBER, Pnuserv NUMBER, Pcdmoti VARCHAR2,
                                     Pdtglos VARCHAR2, Opexitosa OUT VARCHAR2, Dsmens OUT VARCHAR2);
    PROCEDURE Pr_AnularPago (pNupago NUMBER, pCdMotiAnul VARCHAR2, PDtMotiAnul VARCHAR2,
                             pIdAnulPago OUT NUMBER, pOperOK OUT BOOLEAN, pMensaje OUT VARCHAR2);
END Scpq_Devo;