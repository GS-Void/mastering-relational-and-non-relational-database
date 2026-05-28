--------------------------------------------------------
--  DDL - CRIAÇÃO DE TABELAS E SEQUENCES
--------------------------------------------------------

-- cadastro base de usuarios para heranca no java
CREATE TABLE USUARIO (
    ID_USUARIO NUMBER PRIMARY KEY,
    NOME VARCHAR2(100) NOT NULL,
    CPF VARCHAR2(11) UNIQUE NOT NULL,
    TIPO_USUARIO CHAR(1) NOT NULL
);

-- dados medicos do paciente
CREATE TABLE PACIENTE (
    ID_USUARIO NUMBER PRIMARY KEY,
    DATA_NASCIMENTO DATE NOT NULL,
    PESO NUMBER(5,2),
    CONSTRAINT FK_PAC_USUARIO FOREIGN KEY (ID_USUARIO) REFERENCES USUARIO(ID_USUARIO)
);

-- identificacao do fisioterapeuta
CREATE TABLE FISIOTERAPEUTA (
    ID_USUARIO NUMBER PRIMARY KEY,
    REGISTRO_CREFITO VARCHAR2(20) UNIQUE NOT NULL,
    CONSTRAINT FK_FIS_USUARIO FOREIGN KEY (ID_USUARIO) REFERENCES USUARIO(ID_USUARIO)
);

-- regras e limites de carga
CREATE TABLE PROTOCOLO_ESPACIAL (
    ID_PROTOCOLO NUMBER PRIMARY KEY,
    NOME_PROTOCOLO VARCHAR2(100) NOT NULL,
    LIMITE_FADIGA_MAXIMA NUMBER(5,2) NOT NULL
);

-- controle dos dispositivos esp32 cadastrados
CREATE TABLE SENSOR_WEARABLE (
    ID_SENSOR NUMBER PRIMARY KEY,
    MAC_ADDRESS VARCHAR2(17) UNIQUE NOT NULL,
    STATUS VARCHAR2(10) DEFAULT 'ATIVO'
);

-- controle de agendamento e execucao dos treinos
CREATE TABLE SESSAO_REABILITACAO (
    ID_SESSAO NUMBER PRIMARY KEY,
    ID_PACIENTE NUMBER NOT NULL,
    ID_FISIO NUMBER NOT NULL,
    ID_PROTOCOLO NUMBER NOT NULL,
    DATA_INICIO DATE NOT NULL,
    STATUS_SESSAO VARCHAR2(20) DEFAULT 'ANDAMENTO',
    CONSTRAINT FK_SESSAO_PAC FOREIGN KEY (ID_PACIENTE) REFERENCES PACIENTE(ID_USUARIO),
    CONSTRAINT FK_SESSAO_FIS FOREIGN KEY (ID_FISIO) REFERENCES FISIOTERAPEUTA(ID_USUARIO),
    CONSTRAINT FK_SESSAO_PROT FOREIGN KEY (ID_PROTOCOLO) REFERENCES PROTOCOLO_ESPACIAL(ID_PROTOCOLO)
);

-- tabela de telemetria com chave composta 
CREATE TABLE LEITURA_FADIGA (
    ID_SESSAO NUMBER NOT NULL,
    SEGUNDO_LEITURA NUMBER NOT NULL,
    ID_SENSOR NUMBER NOT NULL,
    PERCENTUAL_DESGASTE NUMBER(5,2) NOT NULL,
    CONSTRAINT PK_LEITURA PRIMARY KEY (ID_SESSAO, SEGUNDO_LEITURA),
    CONSTRAINT FK_LEIT_SESSAO FOREIGN KEY (ID_SESSAO) REFERENCES SESSAO_REABILITACAO(ID_SESSAO),
    CONSTRAINT FK_LEIT_SENSOR FOREIGN KEY (ID_SENSOR) REFERENCES SENSOR_WEARABLE(ID_SENSOR)
);

-- historico de quebras de limite de seguranca
CREATE TABLE ALERTA_CRITICO (
    ID_ALERTA NUMBER PRIMARY KEY,
    ID_SESSAO NUMBER NOT NULL,
    TIMESTAMP_ALERTA TIMESTAMP NOT NULL,
    NIVEL_ATINGIDO NUMBER(5,2),
    CONSTRAINT FK_ALERTA_SESSAO FOREIGN KEY (ID_SESSAO) REFERENCES SESSAO_REABILITACAO(ID_SESSAO)
);

-- pk dos alertas criticos
CREATE SEQUENCE SEQ_ALERTA START WITH 1 INCREMENT BY 1;

-- tabela de seguranca para rastrear updates de status
CREATE TABLE LOG_AUDITORIA_SESSAO (
    DATA_HORA TIMESTAMP,
    ACAO VARCHAR2(20),
    ID_SESSAO NUMBER,
    STATUS_ANTIGO VARCHAR2(20)
);

-- entrega de nosql integrada usando coluna checada como json
CREATE TABLE TELEMETRIA_RAW_JSON (
    ID_LOG NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ID_SESSAO NUMBER,
    DADOS_JSON CLOB,
    CONSTRAINT CK_DADOS_JSON CHECK (DADOS_JSON IS JSON)
);

--------------------------------------------------------
--  DML - CARGA DE DADOS INICIAIS E NOSQL
--------------------------------------------------------

-- inserts para testar integridade das fks
INSERT INTO USUARIO VALUES (1, 'Pedro Henrique', '11122233344', 'P');
INSERT INTO PACIENTE VALUES (1, TO_DATE('2000-01-01', 'YYYY-MM-DD'), 75.5);
INSERT INTO USUARIO VALUES (2, 'Dr. Guilherme Macedo', '99988877766', 'F');
INSERT INTO FISIOTERAPEUTA VALUES (2, 'CREFITO-1234');
INSERT INTO PROTOCOLO_ESPACIAL VALUES (1, 'Protocolo ISS Padrão', 80.00);
INSERT INTO SENSOR_WEARABLE VALUES (1, '00:1B:44:11:3A:B7', 'ATIVO');
INSERT INTO SESSAO_REABILITACAO VALUES (1, 1, 2, 1, SYSDATE, 'ANDAMENTO');
INSERT INTO SESSAO_REABILITACAO VALUES (2, 1, 2, 1, SYSDATE, 'CANCELADA');

-- insert de teste para validar a estrutura bsson/json
INSERT INTO TELEMETRIA_RAW_JSON (ID_SESSAO, DADOS_JSON) 
VALUES (1, '{ "sensor": "ESP32_01", "temperatura": 36.5, "bateria": 88, "eventos": ["iniciado", "calibrado"] }');

COMMIT;

--------------------------------------------------------
--  PACKAGE, PROC, FUNC E TRIGGER
--------------------------------------------------------

-- escopo global do package de gestao da clinica
CREATE OR REPLACE PACKAGE PKG_VOID_GESTAO AS
    FUNCTION calcular_media_fadiga(p_id_sessao NUMBER) RETURN NUMBER;
    PROCEDURE registrar_alerta(p_id_sessao NUMBER, p_nivel NUMBER);
END PKG_VOID_GESTAO;
/

-- implementacao das regras do package
CREATE OR REPLACE PACKAGE BODY PKG_VOID_GESTAO AS

    -- calcula o desgaste medio para relatorios de evolucao
    FUNCTION calcular_media_fadiga(p_id_sessao NUMBER) RETURN NUMBER IS
        v_media NUMBER(5,2);
    BEGIN
        SELECT AVG(PERCENTUAL_DESGASTE) INTO v_media 
        FROM LEITURA_FADIGA 
        WHERE ID_SESSAO = p_id_sessao;
        
        RETURN NVL(v_media, 0);
    END calcular_media_fadiga;

    -- insere na tabela de alertas usando a sequence global
    PROCEDURE registrar_alerta(p_id_sessao NUMBER, p_nivel NUMBER) IS
    BEGIN
        INSERT INTO ALERTA_CRITICO (ID_ALERTA, ID_SESSAO, TIMESTAMP_ALERTA, NIVEL_ATINGIDO)
        VALUES (SEQ_ALERTA.NEXTVAL, p_id_sessao, SYSTIMESTAMP, p_nivel);
    END registrar_alerta;
    
END PKG_VOID_GESTAO;
/

-- gatilho para salvar o estado anterior antes de fechar a sessao
CREATE OR REPLACE TRIGGER TRG_AUDIT_SESSAO
AFTER UPDATE ON SESSAO_REABILITACAO
FOR EACH ROW
BEGIN
    INSERT INTO LOG_AUDITORIA_SESSAO (DATA_HORA, ACAO, ID_SESSAO, STATUS_ANTIGO)
    VALUES (SYSTIMESTAMP, 'UPDATE_STATUS', :OLD.ID_SESSAO, :OLD.STATUS_SESSAO);
END;
/

--------------------------------------------------------
-- BLOCOS ANÔNIMOS COM CURSORES (REGRAS DE NEGÓCIO)
--------------------------------------------------------

-- Loop simples (FOR) e INSERT com variável
DECLARE
    v_desgaste NUMBER;
BEGIN
    FOR i IN 1..85 LOOP
        v_desgaste := 10 + (i * 0.8); 
        INSERT INTO LEITURA_FADIGA (ID_SESSAO, SEGUNDO_LEITURA, ID_SENSOR, PERCENTUAL_DESGASTE)
        VALUES (1, i, 1, v_desgaste);
    END LOOP;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro na geração da carga de dados.');
END;
/

-- Cursor explícito 1, FOR LOOP e Condicional 1 (IF)
DECLARE
    CURSOR c_leituras IS SELECT SEGUNDO_LEITURA, PERCENTUAL_DESGASTE FROM LEITURA_FADIGA WHERE ID_SESSAO = 1;
BEGIN
    FOR v_linha IN c_leituras LOOP
        IF v_linha.PERCENTUAL_DESGASTE > 70.00 THEN
            DBMS_OUTPUT.PUT_LINE('Alerta: Desgaste alto no segundo ' || v_linha.SEGUNDO_LEITURA || ' (' || v_linha.PERCENTUAL_DESGASTE || '%)');
        END IF;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro na leitura do cursor 1.');
END;
/

-- Cursor explícito 2, LOOP clássico e Condicional 2 (IF/ELSE)
DECLARE
    CURSOR c_sensor IS SELECT ID_SENSOR, STATUS FROM SENSOR_WEARABLE;
    v_id NUMBER;
    v_status VARCHAR2(10);
BEGIN
    OPEN c_sensor;
    LOOP
        FETCH c_sensor INTO v_id, v_status;
        EXIT WHEN c_sensor%NOTFOUND;
        
        IF v_status = 'ATIVO' THEN
            DBMS_OUTPUT.PUT_LINE('Sensor ' || v_id || ' operante.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Sensor ' || v_id || ' inativo ou em falha.');
        END IF;
    END LOOP;
    CLOSE c_sensor;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro na validação dos sensores.');
END;
/

-- Cursor explícito 3, WHILE LOOP e DELETE com variável
DECLARE
    CURSOR c_sessoes IS SELECT ID_SESSAO, STATUS_SESSAO FROM SESSAO_REABILITACAO WHERE STATUS_SESSAO = 'CANCELADA';
    v_registro c_sessoes%ROWTYPE;
BEGIN
    OPEN c_sessoes;
    FETCH c_sessoes INTO v_registro;
    WHILE c_sessoes%FOUND LOOP
        DELETE FROM SESSAO_REABILITACAO WHERE ID_SESSAO = v_registro.ID_SESSAO;
        FETCH c_sessoes INTO v_registro;
    END LOOP;
    CLOSE c_sessoes;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro ao apagar sessões canceladas.');
END;
/

-- Cursor explícito 4, LOOP e Condicional 3 (IF) com UPDATE em variável
DECLARE
    CURSOR c_equipamento IS SELECT ID_SENSOR, MAC_ADDRESS FROM SENSOR_WEARABLE;
    v_equip c_equipamento%ROWTYPE;
BEGIN
    OPEN c_equipamento;
    LOOP
        FETCH c_equipamento INTO v_equip;
        EXIT WHEN c_equipamento%NOTFOUND;
        
        IF v_equip.ID_SENSOR = 1 THEN
            UPDATE SENSOR_WEARABLE SET STATUS = 'CALIBRACAO' WHERE ID_SENSOR = v_equip.ID_SENSOR;
        END IF;
    END LOOP;
    CLOSE c_equipamento;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro ao atualizar calibragem do sensor.');
END;
/

-- SELECT INTO e Condicional 4 (IF/ELSIF/ELSE)
DECLARE
    v_tipo_usuario CHAR(1);
    v_id_busca NUMBER := 1;
BEGIN
    SELECT TIPO_USUARIO INTO v_tipo_usuario FROM USUARIO WHERE ID_USUARIO = v_id_busca;
    
    IF v_tipo_usuario = 'P' THEN
        DBMS_OUTPUT.PUT_LINE('Usuário validado como Paciente apto para reabilitação.');
    ELSIF v_tipo_usuario = 'F' THEN
        DBMS_OUTPUT.PUT_LINE('Usuário validado como Fisioterapeuta responsável.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Tipo de usuário desconhecido no sistema.');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Usuário não localizado no banco de dados.');
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('Inconsistência: Mais de um usuário retornado.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro genérico na validação de usuário.');
END;
/

--------------------------------------------------------
-- CONSULTAS GERENCIAIS (RELATÓRIOS COM JOIN)
--------------------------------------------------------

-- view basica do tipo de acesso de cada usuario
SELECT U.ID_USUARIO, U.NOME, U.CPF, 
       CASE WHEN U.TIPO_USUARIO = 'P' THEN 'Paciente' ELSE 'Fisioterapeuta' END AS FUNCAO
FROM USUARIO U;

-- prontuario cruzando a tabela pai com a extensao de paciente
SELECT U.NOME, U.CPF, P.DATA_NASCIMENTO, P.PESO
FROM USUARIO U
JOIN PACIENTE P ON U.ID_USUARIO = P.ID_USUARIO;

-- historico geral mapeando medico, paciente e o protocolo iss aplicado
SELECT S.ID_SESSAO, UP.NOME AS NOME_PACIENTE, UF.NOME AS NOME_FISIO, PR.NOME_PROTOCOLO, S.STATUS_SESSAO
FROM SESSAO_REABILITACAO S
JOIN USUARIO UP ON S.ID_PACIENTE = UP.ID_USUARIO
JOIN USUARIO UF ON S.ID_FISIO = UF.ID_USUARIO
JOIN PROTOCOLO_ESPACIAL PR ON S.ID_PROTOCOLO = PR.ID_PROTOCOLO;

-- feed de telemetria ordenado por tempo para alimentar o dashboard mobile
SELECT S.ID_SESSAO, UP.NOME, L.SEGUNDO_LEITURA, L.PERCENTUAL_DESGASTE, W.MAC_ADDRESS
FROM LEITURA_FADIGA L
JOIN SESSAO_REABILITACAO S ON L.ID_SESSAO = S.ID_SESSAO
JOIN USUARIO UP ON S.ID_PACIENTE = UP.ID_USUARIO
JOIN SENSOR_WEARABLE W ON L.ID_SENSOR = W.ID_SENSOR
ORDER BY L.SEGUNDO_LEITURA ASC;

-- analytics para buscar a maior taxa de fadiga registrada por treino
SELECT UP.NOME AS PACIENTE, S.ID_SESSAO, MAX(L.PERCENTUAL_DESGASTE) AS PICO_FADIGA
FROM SESSAO_REABILITACAO S
JOIN LEITURA_FADIGA L ON S.ID_SESSAO = L.ID_SESSAO
JOIN USUARIO UP ON S.ID_PACIENTE = UP.ID_USUARIO
GROUP BY UP.NOME, S.ID_SESSAO;
