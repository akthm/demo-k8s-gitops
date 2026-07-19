# Transit Demo Observability

This document captures the ETL path used by the transit demo and the runtime architecture used on OKE.

## Grafana dashboard

The transit demo chart now provisions a Grafana sidecar-discovered dashboard ConfigMap:

- `helm-charts/transit-demo/templates/grafana-dashboard.yaml`

The dashboard expects two Grafana PostgreSQL datasources:

- one pointed at `postgres-source`
- one pointed at `postgres-mirror`

It uses datasource variables, so it does not require fixed datasource names.

## ETL flow

```mermaid
flowchart LR
    A[SIRI-SM simulator\nPoll every 10s] --> B[(postgres-source\nfact_arrival_event)]
    B --> C[Debezium connector\ntransit-source]
    C --> D[(Redpanda topic\ntransit.public.fact_arrival_event)]
    D --> E[JDBC sink connector\ntransit-sink]
    E --> F[(postgres-mirror\nfact_arrival_event)]

    G[Prefect flow\ngtfs-reference-etl] --> H[(postgres-source\ngtfs_dim tables)]
    I[GTFS ZIP cache] --> G

    F --> J[Prefect flow\ndwh-mart-aggregation]
    J --> K[(postgres-mirror\ndwh.mart_route_performance)]

    B --> L[pgweb source]
    F --> M[pgweb mirror]
    F --> N[Grafana BI dashboard]
    K --> N
```

## Kubernetes architecture

```mermaid
flowchart TB
    U[User browser] --> IN[NGINX Ingress]
    IN --> PORTAL[transit-demo-portal]
    IN --> PREFECT[Prefect UI/API]
    IN --> PGS[pgweb-source]
    IN --> PGM[pgweb-mirror]

    subgraph NS[Namespace: transit-demo]
        SIM[simulator Deployment]
        SRC[(postgres-source)]
        CONN[Kafka Connect]
        RP[(Redpanda)]
        SINK[(postgres-mirror)]
        RUNNER[prefect-runner]
        PREFECT
        PGS
        PGM
        DASH[Grafana dashboard ConfigMap]
    end

    SIM --> SRC
    SRC --> CONN
    CONN --> RP
    RP --> CONN
    CONN --> SINK
    RUNNER --> PREFECT
    RUNNER --> SRC
    RUNNER --> SINK
    DASH -. sidecar discovery .-> GRAF[Grafana in monitoring namespace]
    GRAF --> SINK
    GRAF --> SRC
```

## BI dashboard intent

The dashboard is aimed at interview/demo narration rather than infra metrics. It focuses on:

- source freshness and mirror freshness
- event ingestion rate on source and mirror
- route delay trends from mirrored operational data
- mart trends from `dwh.mart_route_performance`
- latest mirrored arrival predictions as a live operational table