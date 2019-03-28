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
timeout 600 pharos up -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json || exit $?
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
timeout 300 pharos up -y -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json || exit $?

if [ ! -f e2e/digitalocean/worker.json ]; then
  echo "Worker JSON not found, skipping."
  exit 0
fi

echo "Setting up 'pharos worker up'.."

apt-get update && apt-get install -y jq || exit $?

pharos_worker_host=$(jq ".address[0]" e2e/digitalocean/worker.json | sed 's/"//g')

if [ "${pharos_worker_host}" = "" ]; then
  echo "Couldn't get pharos worker host from worker.json"
  exit 1
fi

ssh_key="e2e/digitalocean/ssh_key.pem"
ssh_userhost="root@${pharos_worker_host}"

scp -o StrictHostKeyChecking=no -i "${ssh_key}" pharos-cluster*.gem "${ssh_userhost}:"
ssh -o StrictHostKeyChecking=no -i "${ssh_key}" "${ssh_userhost}" -- "sudo http_proxy=http://10.133.37.156:8888 apt-get update"
ssh -o StrictHostKeyChecking=no -i "${ssh_key}" "${ssh_userhost}" -- "sudo http_proxy=http://10.133.37.156:8888 apt-get -y install ruby build-essential ruby-dev"
ssh -o StrictHostKeyChecking=no -i "${ssh_key}" "${ssh_userhost}" -- "sudo http_proxy=http://10.133.37.156:8888 HTTP_PROXY=http://10.133.37.156:8888 https_proxy=http://10.133.37.156:8888 HTTPS_PROXY=http://10.133.37.156:8888 gem install --no-document pharos-cluster*.gem"
ssh -o StrictHostKeyChecking=no -i "${ssh_key}" "${ssh_userhost}" -- "pharos --version"

worker_hostname=$(ssh -o StrictHostKeyChecking=no -i "${ssh_key}" "${ssh_userhost}" -- hostname -s)

echo "Generating join command"
join_command=$(pharos exec -c e2e/digitalocean/cluster.yml --tf-json e2e/digitalocean/tf.json -r master -f -- sudo kubeadm token create --print-join-command | tail -1)

if [[ "${join_command}" != *"--token"* ]]; then
  echo "Invalid join command: ${join_command}"
  exit 1
fi

echo "Running 'pharos worker up' on target host"

timeout 600 ssh -o StrictHostKeyChecking=no -i "${ssh_key}" "${ssh_userhost}" -- pharos worker up \
  --image-repository registry-tuusula.pharos.sh/kontenapharos \
  -e "HTTPS_PROXY=http://10.133.37.156:8888" \
  -e "HTTP_PROXY=http://10.133.37.156:8888" \
  -e "NO_PROXY=localhost,0,1,2,3,4,5,6,7,8,9" \
  -e "http_proxy=http://10.133.37.156:8888" \
  -e "https_proxy=http://10.133.37.156:8888" \
  -e "no_proxy=localhost,0,1,2,3,4,5,6,7,8,9" \
  --join-command \""${join_command}"\" \
  --master-ip "$(jq ".pharos_hosts.value.masters[0].address[0]" e2e/digitalocean/tf.json | sed 's/"//g')"

echo "Waiting for node to come online"
(retry 30 node_online "${worker_hostname}") || exit $?

