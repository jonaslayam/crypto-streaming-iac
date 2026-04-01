# Crypto Streaming Platform Architecture

## 1. Overview
An end-to-end data platform designed for quantitative analysis and automated cryptocurrency trading. The architecture prioritizes FinOps, high-availability data streaming, and stateful processing to ensure scalable and cost-effective operations.

## 2. Technology Stack
* **Ingestion:** Python (WebSockets for real-time data, REST API for historical backfilling).
* **Message Broker:** Redpanda (Kafka-compatible, high-performance streaming).
* **Stream Processing:** Apache Flink (Stateful functions, 1-hour tumbling windows).
* **Tiered Storage:**
    * *Hot:* Flink Memory (Open trade states and active metrics).
    * *Warm:* Oracle Autonomous Data Warehouse (ADW) for metrics, signals, and feature stores.
    * *Cold/Archive:* OCI Object Storage (Zstd compressed Parquet files).
* **ML & Analytics:** Oracle Machine Learning (OML) for in-database inference; DuckDB for ROI optimization and fast backtesting.
* **Infrastructure:** OCI Ampere (ARM 4 ECPUs, 24GB RAM) running on Linux (Ubuntu/Fedora).

## 3. Data Flow Architecture
* **Dual Ingestion:** Upon startup, the Python producer detects data gaps. If gaps exist, it triggers `Backfill_Manager` (REST API); otherwise, it connects via `Stream_Manager` (WebSockets).
* **Streaming (Redpanda):** Raw data payloads are compressed (Zstd) and published to the `binance_raw` topic.
* **Stream Processing (Flink):**
    * Aggregates raw ticks into 1-hour candlesticks.
    * Maintains state variables: `is_in_trade`, `entry_price`, `last_signal`.
    * **Stop Loss Logic:** Continuous tick monitoring against the `entry_price` stored in memory.
    * Implements Flink savepoints and automated recovery strategies.
* **Inference (OML):** At the close of each window, Flink invokes the predictive model stored in ADW.
* **Action & Alerting:** If the prediction probability exceeds the threshold AND `is_in_trade == False`, an alert is dispatched to Telegram and the ADW ledger is updated.
* **Resiliency:** Circuit breaker pattern implemented to prevent Flink job blocking if OML or ADW experience latency spikes.

## 4. FinOps Strategy
* **Data Archiving:** Only closed candlestick events and trade alerts are persisted to ADW. High-frequency individual ticks are routed to OCI Object Storage, significantly reducing database storage costs.
* **Compute Optimization:** Leveraging ARM architecture and highly optimized Flink processes to maximize the OCI Always Free tier capabilities (avoiding paid ECPU scaling).
* **Broker Retention:** Redpanda tiered storage strategy configured to retain only the last 30 minutes of messages on local disk, keeping the VM's storage footprint lean.

## 5. Implementation Roadmap
### Phase 1: Core Infrastructure & Ingestion
* Provision Cloud Infrastructure (ARM VM, VCN, Object Storage, ADW) via Terraform.
* Configure Dockerized environment for Redpanda and Apache Flink.
* Develop Python producer with dual-mode ingestion (Backfill/WebSocket).
* Define the Data Contract (JSON/Avro schema) for candlestick messages.

### Phase 2: Observability & Monitoring
* Implement Flink metrics and Redpanda lag monitoring.
* Deploy anomaly detection alerts for the data pipeline flow.
* Setup centralized logging (OCI Logging or Prometheus/Grafana stack).

---

# Arquitectura de la Plataforma de Crypto Streaming

## 1. Visión General
Plataforma de datos de extremo a extremo diseñada para el análisis cuantitativo y el trading automatizado de criptomonedas. La arquitectura se centra en la optimización de costos (FinOps), el streaming de alta disponibilidad y el procesamiento de estado (Stateful Processing).

## 2. Stack Tecnológico
* **Ingesta:** Python (WebSockets para tiempo real, API REST para Backfill histórico).
* **Message Broker:** Redpanda (Compatible con Kafka, alto rendimiento).
* **Procesamiento de Stream:** Apache Flink (Stateful functions, ventanas de tiempo de 1 hora).
* **Almacenamiento (Tiered Storage):**
    * *Hot:* Memoria de Flink (Estado de operaciones abiertas).
    * *Warm:* Oracle Autonomous Data Warehouse (ADW) para métricas y señales.
    * *Cold/Archive:* OCI Object Storage (Archivos Parquet comprimidos).
* **ML & Analítica:** Oracle Machine Learning (OML) para inferencia en base de datos; DuckDB para optimización de ROI y Backtesting.
* **Infraestructura:** OCI Ampere (ARM 4 ECPUs, 24GB RAM) sobre Linux (Ubuntu/Fedora).

## 3. Diagrama de Flujo de Datos
* **Ingesta Dual:** Al iniciar, el productor detecta "gaps" de datos. Si hay faltantes, dispara el `Backfill_Manager` (REST); si no, conecta el `Stream_Manager` (WebSockets).
* **Streaming (Redpanda):** Los datos crudos se comprimen (Zstd) y se envían al tópico `binance_raw`.
* **Procesamiento (Flink):**
    * Agrega los datos en velas de 1 hora.
    * Mantiene el estado de las variables: `is_in_trade`, `entry_price`, `last_signal`.
    * **Lógica de Stop Loss:** Monitoreo continuo de cada tick contra el `entry_price` en memoria.
    * Implementa "savepoints" y estrategias de recuperación ante fallos.
* **Inferencia (OML):** Al cierre de cada vela, Flink invoca el modelo predictivo alojado en ADW.
* **Acción y Alertas:** Si la probabilidad supera el umbral (threshold) Y `is_in_trade == False`, se envía una alerta a Telegram y se actualiza el registro en ADW.
* **Resiliencia:** Patrón de "Circuit breaker" implementado para evitar bloqueos en los jobs de Flink si OML o ADW no responden.

## 4. Estrategia de FinOps
* **Data Archiving:** Solo los eventos de velas cerradas y alertas se guardan en ADW. Los ticks individuales van a OCI Object Storage, reduciendo drásticamente los costos de almacenamiento.
* **Optimización de Compute:** Uso de instancias ARM y procesos de Flink optimizados para maximizar el tier gratuito de OCI (evitando costos adicionales por ECPUs).
* **Retención en Broker:** Estrategia de almacenamiento por niveles en Redpanda para mantener solo los últimos 30 minutos de mensajes en el disco local de la VM.

## 5. Roadmap de Implementación
### Fase 1: Infraestructura Core e Ingesta
* Desplegar Infraestructura (VM ARM, VCN, Object Storage, ADW) mediante Terraform.
* Configurar entorno Docker para Redpanda y Apache Flink.
* Desarrollar el productor en Python con lógica de resiliencia y Backfilling.
* Definir el Contrato de Datos (Esquema JSON/Avro) para los mensajes.

### Fase 2: Observabilidad y Monitoreo
* Implementar métricas de Flink y monitoreo de "lag" en Redpanda.
* Desplegar alertas de anomalías en el flujo de datos.
* Configurar logging centralizado (OCI Logging o stack Prometheus/Grafana).