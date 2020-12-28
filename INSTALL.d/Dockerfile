## Dockerfile for building a docker imapsync image

# $Id: Dockerfile,v 1.30 2020/03/26 07:15:04 gilles Exp gilles $
# I use the following command to build the image:
#
#  docker build -t gilleslamiral/imapsync .
#
# where this Dockerfile is in the current directory
#
# I thank you very much
# I like thanks
# I like stars
# I also like (and need) money

# Number of imapsync images pulled so far (2020_03_26): 84354
# Command used:
# curl -s https://hub.docker.com/v2/repositories/gilleslamiral/imapsync/ | jq '.pull_count'

# Ubuntu latest points to current LTS release

FROM debian:buster

LABEL   maintainer="Gilles LAMIRAL <gilles@lamiral.info>" \
        description="Imapsync" \
        documentation="https://imapsync.lamiral.info/#doc"

RUN set -xe                 && \
  apt-get update            && \
  apt-get install -y           \
  libauthen-ntlm-perl          \
  libcgi-pm-perl               \
  libcrypt-openssl-rsa-perl    \
  libdata-uniqid-perl          \
  libencode-imaputf7-perl      \
  libfile-copy-recursive-perl  \
  libfile-tail-perl            \
  libio-socket-inet6-perl      \
  libio-socket-ssl-perl        \
  libio-tee-perl               \
  libhtml-parser-perl          \
  libjson-webtoken-perl        \
  libmail-imapclient-perl      \
  libparse-recdescent-perl     \
  libmodule-scandeps-perl      \
  libreadonly-perl             \
  libregexp-common-perl        \
  libsys-meminfo-perl          \
  libterm-readkey-perl         \
  libtest-mockobject-perl      \
  libtest-pod-perl             \
  libunicode-string-perl       \
  liburi-perl                  \
  libwww-perl                  \
  libtest-nowarnings-perl      \
  libtest-deep-perl            \
  libtest-warn-perl            \
  make                         \
  cpanminus                    \
  wget

RUN wget -N https://imapsync.lamiral.info/imapsync && \
  mv imapsync /usr/bin/imapsync                    && \
  chmod +x /usr/bin/imapsync

USER nobody:nogroup

ENV HOME /var/tmp/

WORKDIR /var/tmp/

STOPSIGNAL SIGINT

CMD ["/usr/bin/imapsync"]

#
# End of imapsync Dockerfile
