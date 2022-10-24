# OpenTelemetry Play

Um cluster Kubernetes local totalmente funcional para você desenvolver e testar suas aplicações
usando [OpenTelemetry](https://opentelemetry.io/)!

## Índice

1. [O que eu preciso pra começar?](#requisitos)
1. [Criando um cluster local do Kubernetes](#kind-kubernetes-in-docker)
1. [Expondo aplicações HTTP](#ingress-nginx-controller)
1. [Armazene suas métricas como dados de série temporal](#prometheus)
1. [O sistema de tracing distribuído](#jaeger)
1. [Analisando seus dados em tabelas, gráficos e alertas](#grafana)
1. [Processamento de dados de telemetria](#opentelemetry-collector)

## Requisitos

* [`Docker`](https://docs.docker.com/get-docker/)
* [`KinD`](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
* [`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl)
* [`Helm`](https://helm.sh/docs/intro/install/)

### KinD (Kubernetes IN Docker)

```shell
kind create cluster --name otelplay --config - <<EOF
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
      - role: control-plane
      - role: worker
        kubeadmConfigPatches:
          - |
            kind: JoinConfiguration
            nodeRegistration:
              kubeletExtraArgs:
                node-labels: "ingress-ready=true"
        extraPortMappings:
          - containerPort: 80
            hostPort: 80
            protocol: TCP
EOF
```

### Ingress NGINX Controller

```shell
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx                
```

```shell
helm upgrade -i nginx ingress-nginx/ingress-nginx -n nginx --create-namespace --version 4.3.0 -f - <<EOF
    controller:
      extraArgs:
        publish-status-address: 127.0.0.1
      hostPort:
        enabled: true
        ports:
          http: 80
          https: 443
      nodeSelector:
        ingress-ready: "true"
        kubernetes.io/os: linux
      publishService:
        enabled: false
      service:
        type: NodePort
EOF
```

### Prometheus

```shell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts        
```

```shell
helm upgrade -i prometheus prometheus-community/prometheus -n prometheus --create-namespace --version 15.16.1 -f - <<EOF
    alertmanager:
      enabled: false
    kubeStateMetrics:
      enabled: false
    nodeExporter:
      enabled: false
    pushgateway:
      enabled: false
    server:
      extraFlags:
        - web.enable-remote-write-receiver
      ingress:
        enabled: true
        hosts:
          - prometheus.lvh.me
        ingressClassName: nginx
    serverFiles:
      prometheus.yml:
        scrape_configs: []
EOF
```

### Jaeger

```shell
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts               
```

```shell
helm upgrade -i jaeger jaegertracing/jaeger -n jaeger --create-namespace --version 0.62.1 -f - <<EOF
    agent:
      enabled: false
    allInOne:
      enabled: true
      extraEnv:
        - name: METRICS_STORAGE_TYPE
          value: prometheus
        - name: PROMETHEUS_SERVER_URL
          value: http://prometheus-server.prometheus.svc.cluster.local
      ingress:
        enabled: false
      tag: 1.38.1
    collector:
      enabled: false
    provisionDataStore:
      cassandra: false
      elasticsearch: false
      kafka: false
    query:
      enabled: false
EOF
```

```shell
kubectl apply -n jaeger -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jaeger
spec:
  ingressClassName: nginx
  rules:
    - host: jaeger.lvh.me
      http:
        paths:
          - backend:
              service:
                name: jaeger-query
                port:
                  name: http-query
            path: /
            pathType: ImplementationSpecific
EOF
```

### Grafana

```shell
helm repo add grafana https://grafana.github.io/helm-charts                     
```

```shell
helm upgrade -i grafana grafana/grafana -n grafana --create-namespace --version 6.43.0 -f - <<EOF
    datasources:
      datasources.yaml:
        apiVersion: 1
        datasources:
          - access: proxy
            isDefault: true
            name: Prometheus
            type: prometheus
            url: http://prometheus-server.prometheus.svc.cluster.local
    grafana.ini:
      auth:
        disable_login_form: true
      auth.anonymous:
        enabled: true
        org_name: Main Org.
        org_role: Editor
    ingress:
      enabled: true
      hosts:
        - grafana.lvh.me
      ingressClassName: nginx
EOF
```

### OpenTelemetry Collector

```shell
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
```

```shell
helm upgrade -i default open-telemetry/opentelemetry-collector -n otel --create-namespace --version 0.36.3 -f - <<EOF
    config:
      exporters:
        logging:
          loglevel: debug
        otlp:
          endpoint: jaeger-collector.jaeger.svc.cluster.local:4317
          tls:
            insecure: true
        prometheusremotewrite:
          endpoint: http://prometheus-server.prometheus.svc.cluster.local/api/v1/write
      extensions:
        health_check: {}
        memory_ballast:
          size_in_percentage: 33
      processors:
        batch: {}
        memory_limiter:
          check_interval: 5s
          limit_percentage: 80
          spike_limit_percentage: 25
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: 0.0.0.0:4317
            http:
              endpoint: 0.0.0.0:4318
      service:
        extensions:
          - health_check
          - memory_ballast
        pipelines:
          metrics:
            exporters:
              - logging
              - prometheusremotewrite
            processors:
              - memory_limiter
              - batch
            receivers:
              - otlp
          traces:
            exporters:
              - logging
              - otlp
            processors:
              - memory_limiter
              - batch
            receivers:
              - otlp
        telemetry:
          metrics:
            address: 0.0.0.0:8888
    mode: deployment
EOF
```
