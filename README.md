# Pharos Cluster

[![Build Status](https://drone-1-0.hel-1.pharos.sh/api/badges/kontena/pharos-cluster/status.svg)](https://drone-1-0.hel-1.pharos.sh/kontena/pharos-cluster)
[![Build Status](https://travis-ci.org/kontena/pharos-cluster.svg?branch=master)](https://travis-ci.org/kontena/pharos-cluster)
[![Join the chat at https://slack.kontena.io](https://img.shields.io/badge/chat-on%20slack-green.svg?logo=slack&longCache=true&style=flat-square)](https://slack.kontena.io)

Pharos Cluster is a [Kontena Pharos](https://pharos.sh) (Kubernetes distribution) management tool. It handles cluster bootstrapping, upgrades and other maintenance tasks via SSH connection and Kubernetes API access.

## Installation

### chpharos
The easiest way to install is to use the Kontena Pharos version switcher [chpharos](https://github.com/kontena/pharos-cluster).

```
$ chpharos install latest
$ pharos --help
```

### Download binaries

The binary packages are available on the Downloads section of your [Kontena Account](https://account.kontena.io/) page.

### Build and install Ruby gem

You need Ruby version 2.5

```
$ gem build pharos-cluster.gemspec
$ gem install pharos-cluster*.gem
$ pharos --help
```

## Usage

See [documentation](https://pharos.sh/docs/).

## Further Information

- [Slack](https://slack.kontena.io)
- [Website](https://pharos.sh/)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kontena/pharos-cluster.
