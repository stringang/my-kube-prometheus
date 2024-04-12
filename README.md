# Customizing kube-prometheus
基于 `release-0.10` 分支构建。

自定义 kube-prometheus 添加：
1. ingress
2. thanos sidecar

自定义 kube-thanos 添加：
1. 部署 thanos-query
2. thanos-query ingress
3. remote thanos sidecar ingress

## 初始化

```shell
# kube-prometheus
mkdir my-kube-prometheus; cd my-kube-prometheus
go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
jb init
jb install github.com/prometheus-operator/kube-prometheus/jsonnet/kube-prometheus@release-0.10
wget https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/release-0.10/example.jsonnet -O example.jsonnet
wget https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/release-0.10/build.sh -O build.sh
chmod +x build.sh

# kube-thanos
jb init
jb install github.com/thanos-io/kube-thanos/jsonnet/kube-thanos@main
wget https://raw.githubusercontent.com/thanos-io/kube-thanos/main/example.jsonnet -O example.jsonnet
wget https://raw.githubusercontent.com/thanos-io/kube-thanos/main/build.sh -O build.sh
chmod +x build.sh
```

## 编译 manifests

```shell
go install github.com/brancz/gojsontoyaml@latest
go install github.com/google/go-jsonnet/cmd/jsonnet@latest

./build.sh example.jsonnet
```

## 部署

```shell
kubectl apply --server-side -f manifests/setup
kubectl wait --for condition=Established --all CustomResourceDefinition --namespace=monitoring
kubectl apply -f manifests/
```

## 卸载

```shell
kubectl delete --ignore-not-found=true -f manifests/ -f manifests/setup
```