#!/bin/bash

while getopts ":ns:number:" opt
do
    case $opt in
        ns)
        echo "value ns is $OPTARG"; ns=$OPTARG
        ;;
        number)
        echo "value number is $OPTARG"; number=$OPTARG
        ;;
        ?)
        echo "Unknown parameter"
        exit 1;;
    esac
done

echo "value ns is $ns"
echo "value number is $number"

number=$number
ns=$ns
server=10.117.233.2

export PATH=./00-kubectl-vsphere-plugin/bin:$PATH
export KUBECTL_VSPHERE_PASSWORD="Admin!23"

kubectl vsphere login --server=$server --vsphere-username administrator@vsphere.local --insecure-skip-tls-verify --tanzu-kubernetes-cluster-namespace=$ns --tanzu-kubernetes-cluster-name=tkgs-cluster-$number
kubectl config use-context tkgs-cluster-$number

echo "Patch PSP"

while true; do
  kubectl create ns auth
  if [[ $? == 0 ]]; then
    break
  fi
  sleep 10
  echo "Wait connect to the server..."
done

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: auth
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rb-all-sa_ns-auth
  namespace: auth
roleRef:
  kind: ClusterRole
  name: psp:vmware-system-privileged
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  apiGroup: rbac.authorization.k8s.io
  name: system:serviceaccounts:auth
---
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rb-all-sa_ns-cert-manager
  namespace: cert-manager
roleRef:
  kind: ClusterRole
  name: psp:vmware-system-privileged
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  apiGroup: rbac.authorization.k8s.io
  name: system:serviceaccounts:cert-manager
---
apiVersion: v1
kind: Namespace
metadata:
  name: istio-system
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rb-all-sa_ns-istio-system
  namespace: istio-system
roleRef:
  kind: ClusterRole
  name: psp:vmware-system-privileged
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  apiGroup: rbac.authorization.k8s.io
  name: system:serviceaccounts:istio-system
---
apiVersion: v1
kind: Namespace
metadata:
  name: knative-serving
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rb-all-sa_ns-knative-serving
  namespace: knative-serving
roleRef:
  kind: ClusterRole
  name: psp:vmware-system-privileged
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  apiGroup: rbac.authorization.k8s.io
  name: system:serviceaccounts:knative-serving
---
apiVersion: v1
kind: Namespace
metadata:
  name: kubeflow
  labels:
    control-plane: kubeflow
    istio-injection: enabled
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rb-all-sa_ns-kubeflow
  namespace: kubeflow
roleRef:
  kind: ClusterRole
  name: psp:vmware-system-privileged
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  apiGroup: rbac.authorization.k8s.io
  name: system:serviceaccounts:kubeflow
EOF


# echo "Install cert-manager"
echo "Install cert-manager"
# run twice to avoid STDIN
while true; do
  kustomize build manifests-1.4-branch/common/cert-manager/cert-manager/base | kubectl apply -f -
  if [[ $? == 0 ]]; then
    break
  fi
  sleep 10
  echo "Wait cert-manager base finish..."
done

while true; do
  kustomize build manifests-1.4-branch/common/cert-manager/kubeflow-issuer/base | kubectl apply -f -
  if [[ $? == 0 ]]; then
    break
  fi
  sleep 10
  echo "Wait cert-manager kubeflow-issuer finish..."
done

# sleep 10
# echo "Install cert-manager again"
# kustomize build manifests-1.4-branch/common/cert-manager/cert-manager/base | kubectl apply -f -
# kustomize build manifests-1.4-branch/common/cert-manager/kubeflow-issuer/base | kubectl apply -f -

echo "Install istio"
# patch api server here

kustomize build manifests-1.4-branch/common/istio-1-9/istio-crds/base | kubectl apply -f -
kustomize build manifests-1.4-branch/common/istio-1-9/istio-namespace/base | kubectl apply -f -
kustomize build manifests-1.4-branch/common/istio-1-9/istio-install/base | kubectl apply -f -

echo "Install Dex"

kustomize build manifests-1.4-branch/common/dex/overlays/istio | kubectl apply -f -

echo "Install OIDC AuthService"

kustomize build manifests-1.4-branch/common/oidc-authservice/base | kubectl apply -f -

echo "Install Knative Serving"

while true; do
  kustomize build manifests-1.4-branch/common/knative/knative-serving/base | kubectl apply -f -
  if [[ $? == 0 ]]; then
    break
  fi
  sleep 10
  echo "Wait knative-serving base finish..."
done

while true; do
  kustomize build manifests-1.4-branch/common/istio-1-9/cluster-local-gateway/base | kubectl apply -f -
  if [[ $? == 0 ]]; then
    break
  fi
  sleep 10
  echo "Wait cluster-local-gateway base finish..."
done

# kustomize build manifests-1.4-branch/common/knative/knative-serving/base | kubectl apply -f -
# kustomize build manifests-1.4-branch/common/istio-1-9/cluster-local-gateway/base | kubectl apply -f -

# sleep 10
# echo "Install Knative Serving again"
# kustomize build manifests-1.4-branch/common/knative/knative-serving/base | kubectl apply -f -
# kustomize build manifests-1.4-branch/common/istio-1-9/cluster-local-gateway/base | kubectl apply -f -

echo "Install kubeflow namespace"

kustomize build manifests-1.4-branch/common/kubeflow-namespace/base | kubectl apply -f -

echo "Install kubeflow roles"

kustomize build manifests-1.4-branch/common/kubeflow-roles/base | kubectl apply -f -

echo "Install istio resources"

kustomize build manifests-1.4-branch/common/istio-1-9/kubeflow-istio-resources/base | kubectl apply -f -

echo "Install kubeflow pipelines"

# run twice to avoid...
while true; do
  kustomize build manifests-1.4-branch/apps/pipeline/upstream/env/platform-agnostic-multi-user-pns | kubectl apply -f -
  if [[ $? == 0 ]]; then
    break
  fi
  sleep 10
  echo "Wait kubeflow pipelines finish..."
done

# kustomize build manifests-1.4-branch/apps/pipeline/upstream/env/platform-agnostic-multi-user-pns | kubectl apply -f -
# sleep 10
# echo "Install kubeflow pipelines again"
# kustomize build manifests-1.4-branch/apps/pipeline/upstream/env/platform-agnostic-multi-user-pns | kubectl apply -f -

echo "Install KFServing"

kustomize build manifests-1.4-branch/apps/kfserving/upstream/overlays/kubeflow | kubectl apply -f -

echo "Install Katib"

kustomize build manifests-1.4-branch/apps/katib/upstream/installs/katib-with-kubeflow | kubectl apply -f -

echo "Install Central Dashboard"

kustomize build manifests-1.4-branch/apps/centraldashboard/upstream/overlays/istio | kubectl apply -f -

echo "Install Admission Webhook"

kustomize build manifests-1.4-branch/apps/admission-webhook/upstream/overlays/cert-manager | kubectl apply -f -

echo "Install notebook controller"

kustomize build manifests-1.4-branch/apps/jupyter/notebook-controller/upstream/overlays/kubeflow | kubectl apply -f -

echo "Install Jupyter Web App"

kustomize build manifests-1.4-branch/apps/jupyter/jupyter-web-app/upstream/overlays/istio | kubectl apply -f -

echo "Install profiles and KFAM"

kustomize build manifests-1.4-branch/apps/profiles/upstream/overlays/kubeflow | kubectl apply -f -

echo "Install Volumes Web App"

kustomize build manifests-1.4-branch/apps/volumes-web-app/upstream/overlays/istio | kubectl apply -f -

echo "Install Tensorboards Web App"

kustomize build manifests-1.4-branch/apps/tensorboard/tensorboards-web-app/upstream/overlays/istio | kubectl apply -f -

echo "Install Tensorboards Controller"

kustomize build manifests-1.4-branch/apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow | kubectl apply -f -

echo "Install Training Operator"

kustomize build manifests-1.4-branch/apps/training-operator/upstream/overlays/kubeflow | kubectl apply -f -

echo "Install MPI Operator"

kustomize build manifests-1.4-branch/apps/mpi-job/upstream/overlays/kubeflow | kubectl apply -f -

echo "Create user namespace"

kustomize build manifests-1.4-branch/common/user-namespace/base | kubectl apply -f -

# while true; do
#   kubectl get ns|grep kubeflow-user-example-com | grep Active
#   if [[ $? == 0 ]]; then
#     break
#   fi
#   sleep 10
#   echo "Wait kubeflow-user-example-com namespace creating finish..."
# done

# while true; do
#   kubectl create ns kubeflow-user-example-com
#   if [[ $? == 0 ]]; then
#     break
#   fi
#   sleep 10
#   echo "Wait create kubeflow-user-example-com..."
# done

echo "Fix PSP"
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: kubeflow-user-example-com
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rb-all-sa_ns-kubeflow-user-example-com
  namespace: kubeflow-user-example-com
roleRef:
  kind: ClusterRole
  name: psp:vmware-system-privileged
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  apiGroup: rbac.authorization.k8s.io
  name: system:serviceaccounts:kubeflow-user-example-com
EOF

exit
