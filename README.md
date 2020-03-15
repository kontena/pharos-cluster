# Pharos Cluster

[![Build Status](https://travis-ci.org/kontena/pharos-cluster.svg?branch=master)](https://travis-ci.org/kontena/pharos-cluster)
[![Chat on Slack](https://img.shields.io/badge/chat-on%20slack-green.svg?logo=slack&longCache=true&style=flat-square)](https://join.slack.com/t/kontenacommunity/shared_invite/enQtOTc5NjAyNjYyOTk4LWU1NDQ0ZGFkOWJkNTRhYTc2YjVmZDdkM2FkNGM5MjhiYTRhMDU2NDQ1MzIyMDA4ZGZlNmExOTc0N2JmY2M3ZGI)

Pharos Cluster is a [Kontena Pharos](https://pharos.sh) (Kubernetes distribution) management tool. It handles cluster bootstrapping, upgrades and other maintenance tasks via SSH connection and Kubernetes API access.

## Installation

### Download binaries

The binary packages are available on the [releases](https://github.com/kontena/pharos-cluster/releases) page.

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

- [Slack](https://kontenacommunity.slack.com) (get invite [here](https://join.slack.com/t/kontenacommunity/shared_invite/enQtOTc5NjAyNjYyOTk4LWU1NDQ0ZGFkOWJkNTRhYTc2YjVmZDdkM2FkNGM5MjhiYTRhMDU2NDQ1MzIyMDA4ZGZlNmExOTc0N2JmY2M3ZGI))
- [Website](https://pharos.sh/)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kontena/pharos-cluster.
