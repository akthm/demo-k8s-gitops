# Transit Demo on OKE (Single 50Gi PVC)

This runbook deploys the CDC + ETL transit demo on OKE free tier constraints.

## What was implemented

- Helm chart: helm-charts/transit-demo
- ArgoCD app (staging): apps/oci-staging/transit-demo.yaml
- ArgoCD app (local): apps/local/transit-demo.yaml

## Profile design

- Single persistent component: postgres-mirror with one 50Gi PVC
- Ephemeral components: postgres-source, redpanda, prefect, simulator, connect, portal
- Optional by default: minio and lake-consumer are disabled
- Single platform entrypoint: portal host links to Prefect and pgweb UIs

## Required container images

The chart expects these images to exist in a registry reachable by OKE nodes:

- ghcr.io/akthm/etl-connect:0.1.0
- ghcr.io/akthm/etl-simulator:0.1.0
- ghcr.io/akthm/etl-prefect-runner:0.1.0
- ghcr.io/akthm/etl-lake-consumer:0.1.0 (optional)

If your registry/tag differs, update:
- helm-charts/transit-demo/values.oci-staging.yaml

## Build and push images from ETL repo

Run from /workspaces/docker-in-docker/portfolio/etl:

```bash
docker build -t ghcr.io/akthm/etl-connect:0.1.0 ./connect
docker build -t ghcr.io/akthm/etl-simulator:0.1.0 ./simulator
docker build -t ghcr.io/akthm/etl-prefect-runner:0.1.0 ./prefect
docker build -t ghcr.io/akthm/etl-lake-consumer:0.1.0 ./lake

# Push to registry
docker push ghcr.io/akthm/etl-connect:0.1.0
docker push ghcr.io/akthm/etl-simulator:0.1.0
docker push ghcr.io/akthm/etl-prefect-runner:0.1.0
docker push ghcr.io/akthm/etl-lake-consumer:0.1.0
```

## Deploy via ArgoCD

```bash
kubectl apply -f apps/oci-staging/transit-demo.yaml
```

## DNS and ingress hosts

Set DNS records to your ingress endpoint for these hosts:

- transit-demo.adaas-il.com
- prefect-transit.adaas-il.com
- pgweb-source-transit.adaas-il.com
- pgweb-mirror-transit.adaas-il.com

Optional (if MinIO enabled):

- minio-transit.adaas-il.com

## Post-deploy checks

1. Pods and PVC:
```bash
kubectl -n transit-demo get pods
kubectl -n transit-demo get pvc
```

2. Connector bootstrap job:
```bash
kubectl -n transit-demo get jobs
kubectl -n transit-demo logs job/connect-bootstrap
kubectl -n transit-demo logs job/transit-demo-smoke-check
```

3. Connector status:
```bash
kubectl -n transit-demo run curl --rm -it --image=curlimages/curl:8.9.1 -- \
  curl -s http://connect:8083/connectors/transit-source/status
kubectl -n transit-demo run curl --rm -it --image=curlimages/curl:8.9.1 -- \
  curl -s http://connect:8083/connectors/transit-sink/status
```

4. Validate UI entrypoint:
- Open portal: https://transit-demo.adaas-il.com

## Notes

- Chart keeps source DB ephemeral intentionally; simulator repopulates it.
- Prefect metadata is ephemeral in this demo profile.
- To enable MinIO and lake consumer, set minio.enabled=true and lakeConsumer.enabled=true in values override.
- Optional ingress basic auth is available via `ingress.basicAuth.*` values.
- If `ingress.basicAuth.enabled=true`, set `ingress.basicAuth.htpasswd` to htpasswd file content.
