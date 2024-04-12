local t = import 'kube-thanos/thanos.libsonnet';

// promethues https proxy
local ingress(params) = {
  config:: params,

  apiVersion: 'networking.k8s.io/v1',
  kind: 'Ingress',
  metadata: {
    name: params.name,
    namespace: params.namespace,
    annotations: params.annotations,
  },
  spec: { rules: params.rules },
};

// For an example with every option and component, please check all.jsonnet

local commonConfig = {
  config+:: {
    local cfg = self,
    namespace: 'monitoring',
    version: 'v0.25.0',
    image: 'quay.io/thanos/thanos:' + cfg.version,
    imagePullPolicy: 'IfNotPresent',
    objectStorageConfig: {
      name: 'thanos-objectstorage',
      key: 'thanos.yaml',
    },
    hashringConfigMapName: 'hashring-config',
    volumeClaimTemplate: {
      spec: {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: '10Gi',
          },
        },
      },
    },
    autoDownsampling: false,
  },
};

local i = t.receiveIngestor(commonConfig.config {
  replicas: 1,
  replicaLabels: ['receive_replica'],
  replicationFactor: 1,
  // Disable shipping to object storage for the purposes of this example
  objectStorageConfig: null,
  serviceMonitor: true,
});

local r = t.receiveRouter(commonConfig.config {
  replicas: 1,
  replicaLabels: ['receive_replica'],
  replicationFactor: 1,
  // Disable shipping to object storage for the purposes of this example
  objectStorageConfig: null,
  endpoints: i.endpoints,
});

local s = t.store(commonConfig.config {
  replicas: 1,
  serviceMonitor: true,
});

// customizing query
local q = t.query(commonConfig.config {
  replicas: 1,
  replicaLabels: ['prometheus_replica', 'rule_replica'],
  serviceMonitor: true,
  // promethues server(thanos sidecar)
  stores: ['dnssrv+_grpc._tcp.prometheus-operated.monitoring.svc'],
});

local ig = {
  ingress+:: {
    'thanos-query': ingress(commonConfig.config {
      name: 'thanos-query',
      annotations: {
        'nginx.ingress.kubernetes.io/ssl-redirect': 'false',
      },
      rules: [{
        host: 'thanos-query.example.com',
        http: {
          paths: [{
            path: '/',
            pathType: 'Prefix',
            backend: {
              service: {
                name: 'thanos-query',
                port: {
                  name: 'http',
                },
              },
            },
          }],
        },
      }],
    }),
    // remote sidecar(promethues)
    // https://thanos.io/tip/operating/cross-cluster-tls-communication.md/#client-clusters-sidecarcingressyaml
    'thanos-sidecar': ingress(commonConfig.config {
      name: 'thanos-sidecar',
      annotations: {
        // grpc proxy
        'nginx.ingress.kubernetes.io/ssl-redirect': 'false',
        'nginx.ingress.kubernetes.io/backend-protocol': 'GRPC',
        'nginx.ingress.kubernetes.io/grpc-backend': 'true',
        'nginx.ingress.kubernetes.io/protocol': 'h2c',
        'nginx.ingress.kubernetes.io/proxy-read-timeout': '160',
      },
      tls: [{
        'hosts': [
          'thanos.sidecardomain.com'
        ],
        'secretName': 'thanos-tls'
      }],
      rules: [{
        host: 'thanos.sidecardomain.com',
        paths: [{
          path: '/',
          pathType: 'Prefix',
          backend: {
            service: {
              name: 'prometheus-k8s',
              port: {
                name: 'grpc',
              },
            },
          },
        }],
      }]
    }),
  },
};

{ ['thanos-query-' + name]: q[name] for name in std.objectFields(q) } +
{ [name + '-ingress']: ig.ingress[name] for name in std.objectFields(ig.ingress) }