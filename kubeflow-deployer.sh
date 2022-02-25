#!/bin/bash

number=22
ns=zyajing
server=10.117.233.2

export PATH=./00-kubectl-vsphere-plugin/bin:$PATH
export KUBECTL_VSPHERE_PASSWORD="Admin!23"

#Patch PSP --- robelBinding
kubectl vsphere login --server=$server --vsphere-username administrator@vsphere.local --insecure-skip-tls-verify --tanzu-kubernetes-cluster-namespace=$ns --tanzu-kubernetes-cluster-name=tkgs-cluster-$number
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
echo "Patch PSP -- done"

while ! kustomize build ./manifests-1.4-branch/example | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 10; done

while true; do
  kubectl get pods -A |grep Running
  if [[ $? == 0 ]]; then
    break
  fi
  sleep 10
  echo "Wait Pods Running..."
done

sleep 200

while true; do
  kubectl get ns|grep kubeflow-user-example-com
  if [[ $? == 0 ]]; then
    break
  fi
  sleep 10
  echo "Wait kubeflow-user-example-com namespace creating finish..."
done
cat << EOF | kubectl apply -f -
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
echo "deploy kubeflow -- done"

exit
