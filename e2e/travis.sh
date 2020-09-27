#!/bin/bash
# shellcheck disable=SC2039 disable=SC1091

set -ue

source ./e2e/util.sh

ssh-keygen -t rsa -f ~/.ssh/id_rsa_travis -N ""
cat ~/.ssh/id_rsa_travis.pub > ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys

ifconfig

envsubst < e2e/cluster.yml > cluster.yml
envsubst < e2e/footloose.yaml > footloose.yaml

curl -sSL https://git.io/g-install | sh -s -- -y
git clone https://github.com/jakolehm/footloose.git footloose-src
pushd footloose-src/
  make vendor
  make bin/footloose
  mv bin/footloose ../
popd
chmod +x ./footloose
./footloose create
./footloose ssh root@master0 -- 'apt-get install -y curl || yum install -y curl which openssh-clients'
./footloose ssh root@worker0 -- 'apt-get install -y curl || yum install -y curl which openssh-clients'

bundle exec bin/pharos
bundle exec bin/pharos -v
bundle exec bin/pharos version
bundle exec bin/pharos up -y -c cluster.yml
bundle exec bin/pharos ssh --role master -c cluster.yml -- kubectl get nodes
bundle exec bin/pharos kubeconfig -c cluster.yml > kubeconfig.e2e
export KUBECONFIG=./kubeconfig.e2e

# Verify that workloads start running
curl -sLO https://storage.googleapis.com/kubernetes-release/release/v1.18.8/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv kubectl /usr/local/bin/

echo "==> Checking that metrics-server is running:"
(retry 30 pods_running "k8s-app=metrics-server" "kube-system") || exit $?

echo "==> Test with sonobuoy"
curl -L https://github.com/vmware-tanzu/sonobuoy/releases/download/v0.18.4/sonobuoy_0.18.4_linux_amd64.tar.gz | tar xzv
chmod +x ./sonobuoy
(
  sleep 30
  ./sonobuoy logs -f
)&
logs_pid=$!
./sonobuoy run --wait=600 --plugin-env=e2e.E2E_USE_GO_RUNNER=true '--e2e-focus=\[sig-network\].*\[Conformance\]' '--e2e-skip=\[Serial\]' --e2e-parallel=y
kill $logs_pid
results=$(./sonobuoy retrieve)
./sonobuoy results "${results}"
./sonobuoy status | grep -q -E ' +e2e +complete +passed +'

# Test re-up
bundle exec bin/pharos up -y -c cluster.yml

echo "==> Test reset"
bundle exec bin/pharos reset -y -c cluster.yml
