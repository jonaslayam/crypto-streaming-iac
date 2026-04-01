    1. Visión General

    Plataforma de datos de extremo a extremo para el análisis cuantitativo y trading automatizado de criptomonedas, con enfoque en FinOps, Streaming de alta disponibilidad y Procesamiento de estado.
    2. Stack Tecnológico

        Ingesta: Python (WebSockets para tiempo real, REST API para Backfill).

        Message Broker: Redpanda (Kafka compatible).

        Procesamiento de Stream: Apache Flink (Stateful functions, Windows de 1h).

        Almacenamiento (Tiered Storage):

            Hot: Memoria de Flink (Estado de operaciones abiertas).

            Warm: Oracle Autonomous Data Warehouse (ADW) para métricas y señales.

            Cold/Archive: OCI Object Storage (Archivos Parquet comprimidos).

        ML & Analítica: Oracle Machine Learning (OML) para inferencia; DuckDB para optimización de ROI (Backtesting).

        Infraestructura: OCI Ampere (ARM 4 OCPU, 24GB RAM) sobre Fedora/Oracle Linux.

    3. Diagrama de Flujo de Datos

        Ingesta Dual: El productor detecta gaps al iniciar. Si hay faltantes, dispara Backfill_Manager (REST); si no, conecta Stream_Manager (WS).

        Streaming (Redpanda): Los datos crudos se comprimen (Zstd) y se envían al tópico binance_raw.

        Procesamiento (Flink):

            Agrega velas de 1h.

            Mantiene el estado: is_in_trade, entry_price, last_signal.

            Lógica de Stop Loss: Monitoreo de cada tick contra el entry_price en memoria.

            Flink savepoints y recovery strategies.

        Inferencia (OML): Al cierre de cada vela, Flink invoca el modelo en ADW.

        Acción: Si probabilidad > threshold Y is_in_trade == False, enviar alerta a Telegram y actualizar ADW.
        
        Circuit breaker si OML o ADW no responden para evitar bloqueos en Flink.

    4. Estrategia de FinOps

        Data Archiving: Solo los eventos de velas cerradas y alertas van a ADW. Los ticks individuales van a Object Storage (100x más barato).

        Compute Optimization: Uso de instancias ARM y procesos de Flink optimizados para evitar el pago de OCPUs adicionales en ADW.

        Tiered Storage en Redpanda: Mantener solo los últimos 30 minutos de mensajes en disco local.

    5. Roadmap de Implementación (Fase 1)

        Infraestructura: Configurar la instancia ARM y el entorno Docker (Redpanda + Flink).

        Ingesta & Resiliencia: Desarrollar el productor de Python con lógica de Backfilling (REST + WS).

        Contrato de Datos: Definir el esquema JSON/Avro para los mensajes de velas.

        Sugerencia: agregar Fase 2 con métricas de observabilidad:
        
        Fase 2:
        - Flink metrics + Redpanda lag
        - Alerts de anomalías en el flujo de datos
        - Logging centralizado (OCI Logging o Prometheus/Grafana)