#!/bin/bash
# shellcheck disable=SC2039 disable=SC1091

set -u

if [ ! -f e2e/digitalocean/tf.json ]
then
    echo "TF output not found, skipping."
    exit 0
fi

source ./e2e/util.sh

export PHAROS_NON_OSS=true

gem build pharos-cluster.gemspec
gem install pharos-cluster*.gem

# Test that we can actually load everything
pharos || exit $?
pharos -v || exit $?
pharos version || exit $?

# Smoke the license commands
pharos license assign --help || exit $?
pharos license inspect --help || exit $?

# Test cluster bootstrapping
timeout 700 pharos up -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json || exit $?
(pharos kubeconfig -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json > kubeconfig.e2e) || exit $?
(pharos exec --role master -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json -- kubectl get nodes -o wide) || exit $?

# Verify that workloads start running
echo "Downloading kubectl ..."
curl -sLO https://storage.googleapis.com/kubernetes-release/release/v1.13.5/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv kubectl /usr/local/bin/
export KUBECONFIG=./kubeconfig.e2e

echo "Checking that ingress-nginx is running:"
(retry 30 pods_running "app=ingress-nginx" "ingress-nginx") || exit $?

echo "Checking that kontena-lens is running:"
(retry 30 pods_running "app=dashboard" "kontena-lens") || exit $?

# Rerun up to confirm that non-initial run goes through
cat <<EOF >>e2e/digitalocean/cluster.yml
api:
  endpoint: "127-0-0-1.nip.io"
EOF
timeout 300 pharos up -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json || exit $?
echo "Checking that certificate has been updated:"
(pharos exec --role master -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json -- "timeout 3 openssl s_client -connect localhost:6443 | openssl x509 -noout -text |grep DNS:127-0-0-1.nip.io") || exit $?

# Subcommand "pharos worker up" test

if [ ! -f e2e/digitalocean/worker_up_address.txt ]; then
  echo "File worker_up_address.txt not found, skipping worker up test."
  exit 0
fi

echo "Setting up 'pharos worker up'.."

apt-get update && apt-get install -y jq

pharos_worker_host=$(<"e2e/digitalocean/worker_up_address.txt")
if [ "${pharos_worker_host}" = "" ]; then
  echo "Couldn't get pharos worker host from worker_up_address.txt"
  exit 1
fi

pharos_master_host=$(<"e2e/digitalocean/master_address.txt")
if [ "${pharos_master_host}" = "" ]; then
  echo "Couldn't get pharos master host from master_address.txt"
  exit 1
fi

ssh_key="e2e/digitalocean/ssh_key.pem"
ssh_userhost="root@${pharos_worker_host}"

scp -o StrictHostKeyChecking=no -i "${ssh_key}" pharos-cluster*.gem "${ssh_userhost}:"

ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -i "${ssh_key}" "${ssh_userhost}" -- "sudo bash -c '\
  export http_proxy=http://10.133.37.156:8888 HTTP_PROXY=http://10.133.37.156:8888 https_proxy=http://10.133.37.156:8888 HTTPS_PROXY=http://10.133.37.156:8888 DEBIAN_FRONTEND=noninteractive;
  apt-get update && apt-get -y -qq install ruby build-essential ruby-dev && \
  gem install --no-document pharos-cluster*.gem && \
  pharos --version'"

worker_hostname=$(ssh -o StrictHostKeyChecking=no -i "${ssh_key}" "${ssh_userhost}" -- hostname -s)

echo "Generating join command.."
join_command=$(pharos exec -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json -r master -f -- sudo kubeadm token create --print-join-command | tail -1)

echo "Running 'pharos worker up' on target host.."

timeout 600 ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -i "${ssh_key}" "${ssh_userhost}" -- pharos worker up \
  --image-repository registry-tuusula.pharos.sh/kontenapharos \
  -e "HTTPS_PROXY=http://10.133.37.156:8888" \
  -e "HTTP_PROXY=http://10.133.37.156:8888" \
  -e "NO_PROXY=localhost,0,1,2,3,4,5,6,7,8,9" \
  -e "http_proxy=http://10.133.37.156:8888" \
  -e "https_proxy=http://10.133.37.156:8888" \
  -e "no_proxy=localhost,0,1,2,3,4,5,6,7,8,9" \
  --yes \
  \""${join_command}"\" "${pharos_master_host}"  || exit $?

echo "Waiting for node to come online.."
(retry 30 node_online "${worker_hostname}") || exit $?
echo "Node is online:"
kubectl get nodes "${worker_hostname}" -o wide
