FROM quay.io/footloose/ubuntu18.04

RUN apt-get update && apt-get install -y \
  sudo kmod locales

RUN echo exit 0 > /usr/sbin/policy-rc.d
