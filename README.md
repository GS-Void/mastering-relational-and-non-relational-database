# 🗄️ Projeto VOID - Banco de Dados (Relacional e Não-Relacional)

## 🌍 Global Solution 2026.1

### Mastering Relational and Non-Relational Database

---

## 👥 1. Integrantes (Turma 2TDSPO)

| Integrante                       | RM     |
| -------------------------------- | -------|
| Pedro Henrique Luiz Alves Duarte | 563405 |
| Guilherme Macedo Martins         | 562396 |
| Henrique Martins                 | 563620 |

---

## 📖 2. Visão Geral do Projeto

O **VOID** é uma plataforma disruptiva de monitoramento biométrico para reabilitação física.

Este repositório contém a modelagem e a implementação do **banco de dados híbrido Oracle**, responsável por sustentar toda a aplicação, garantindo a integridade dos dados clínicos e o armazenamento escalável da telemetria de IoT.

O script unificado `void-database.sql` contempla:

* Criação das estruturas (**DDL**)
* Carga de dados (**DML**)
* Blocos anônimos
* Rotinas **PL/SQL**
* Relatórios gerenciais

---

## 🏗️ 3. Estrutura Híbrida do Banco de Dados

A modelagem atende tanto aos requisitos relacionais tradicionais quanto às demandas não-relacionais (**NoSQL**) advindas de sensores de hardware.

### 🏥 3.1 Modelo Relacional (Gestão Clínica)

#### Usuários e Perfis

* `TB_VOID_USUARIO`
* `TB_VOID_PACIENTE`
* `TB_VOID_FISIOTERAPEUTA`

> Herança simulada através de chaves estrangeiras (FKs), permitindo a separação dos atributos específicos de cada perfil.

#### Operacional

* `TB_VOID_SESSAO_REABILITACAO`
* `PROTOCOLO_ESPACIAL`
* `SENSOR_WEARABLE`

Responsáveis pelo agendamento, monitoramento e execução dos protocolos de reabilitação.

#### Telemetria e Segurança

* `LEITURA_FADIGA`
* `ALERTA_CRITICO`
* `LOG_AUDITORIA_SESSAO`

Garantem rastreabilidade completa dos eventos clínicos e operacionais.

---

### 📡 3.2 Modelo Não-Relacional (Ingestão IoT)

#### TELEMETRIA_RAW_JSON

Tabela otimizada para armazenamento de telemetria bruta proveniente dos dispositivos IoT.

Características:

* Tipo de dado `CLOB`
* Constraint:

```sql
CHECK (DADOS_JSON IS JSON)
```

Permite armazenar payloads completos enviados pelo **ESP32** e **Node-RED**, contendo informações como:

* Bateria
* Temperatura
* Sensores biométricos
* Dados complementares de telemetria

Essa abordagem garante flexibilidade para evolução da estrutura dos dados sem alterações frequentes no modelo relacional.

---

## ⚙️ 4. Recursos PL/SQL Implementados

O projeto utiliza recursos avançados da linguagem **PL/SQL Oracle** para automação, segurança e consistência dos dados.

### 📦 Packages e Procedures

O package `PKG_VOID_SYSTEM` encapsula regras de negócio críticas da aplicação.

Principais rotinas:

* `PR_CANCELA_SESSAO`
* `FN_TOTAL_ALERTAS`

---

### 🔄 Triggers

Automação de auditoria através da trigger:

* `TRG_AUDITORIA_SESSAO`

Responsável pelo registro automático de alterações realizadas nas sessões de reabilitação.

---

### 🔍 Cursores Explícitos

Utilização de:

* `FOR`
* `WHILE`
* `FOR UPDATE`

Aplicados para:

* Varredura de sensores
* Exclusão controlada de sessões
* Monitoramento de limites de esforço
* Geração de alertas críticos

---

### 🚨 Tratamento de Exceções

Implementação de validações robustas utilizando:

* Exceções personalizadas
* Comando `RAISE`

Exemplo:

* Bloqueio de registros com fadiga superior a 100%
* Validação de consistência dos dados clínicos

---

## 🚀 5. Como Executar

### 1️⃣ Configurar o Banco

Instale e configure um ambiente Oracle compatível:

* Oracle Database XE
* Oracle Cloud Database

### 2️⃣ Escolher uma IDE

Utilize uma ferramenta de gerenciamento SQL:

* Oracle SQL Developer
* DBeaver
* DataGrip (Opcional)

### 3️⃣ Baixar o Script

Faça o download do arquivo:

```text
void-database.sql
```

### 4️⃣ Executar o Setup

* Abra o script na IDE
* Conecte-se ao banco Oracle
* Execute o arquivo completo como script

No SQL Developer utilize:

```text
F5
```

O script executará automaticamente:

* DDL
* DML
* Procedures
* Functions
* Triggers
* Packages
* Relatórios

---

## 📊 6. Relatórios Gerenciais Disponíveis

Ao final do script estão disponíveis consultas analíticas para geração de insights.

### 📋 Histórico de Sessões

* Sessões realizadas
* Pacientes envolvidos
* Fisioterapeutas responsáveis

### 🚨 Alertas Críticos

Comparação entre:

* Alertas gerados
* Limite de segurança individual

### 📡 Telemetria JSON

Extração completa do payload bruto armazenado na estrutura NoSQL.

### ⌚ Monitoramento de Wearables

Varredura de dispositivos para identificar:

* Desgaste excessivo
* Equipamentos com necessidade de manutenção
* Sensores fora dos padrões operacionais

---

## 🛠️ Tecnologias Utilizadas

* Oracle Database
* SQL
* PL/SQL
* JSON Storage
* Oracle CLOB
* Oracle SQL Developer
* DBeaver
* IoT Telemetry
* ESP32
* Node-RED

---

## 🎯 Objetivo da Solução

A arquitetura de banco de dados do VOID foi projetada para:

* Garantir integridade dos dados clínicos
* Suportar grandes volumes de telemetria IoT
* Permitir rastreabilidade completa dos eventos
* Automatizar processos através de PL/SQL
* Facilitar auditorias e compliance
* Atender requisitos relacionais e não-relacionais em uma única plataforma

---

> 📌 Documentação técnica otimizada para os critérios de avaliação da **Global Solution 2026.1**.
