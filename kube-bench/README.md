# CIS security benchmarks

This folder has helper scripts and descriptors to easily run [kube-bench](https://github.com/aquasecurity/kube-bench) CIS security benchmarks.

## Running the benchmarks

The benchmarks are split ionto two categories, one purely for control plane node check and one for worker plane checks.

The helper script `run-bench.sh` is able to create a `Job` for each type of test, show the logs and then cleanup.

To execute the benchmarks for a worker node, you'd use:
```sh
./run-bench.sh node
```

For a master node run:
```sh
./run-bench.sh master
```