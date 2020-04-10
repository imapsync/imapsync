## Dockerfile for building a docker imapsync image

# $Id: Dockerfile,v 1.28 2019/12/02 13:19:41 gilles Exp gilles $
# I use the following command to build the image:
#
#  docker build -t gilleslamiral/imapsync . 
#
# where this Dockerfile is in the current directory
# 
# I like thanks
# I like stars
# I also like (and need) money
# I thank you very much

# Number of imapsync images pulled so far (2019_12_02): 32732
# Command used:
# curl -s https://hub.docker.com/v2/repositories/gilleslamiral/imapsync/ | jq '.pull_count'


FROM debian:buster 

LABEL   maintainer="Gilles LAMIRAL <gilles@lamiral.info>" \
        description="Imapsync" \
        documentation="https://imapsync.lamiral.info/#doc"

# Put a copy of the Dockerfile in the image itself
# It can help future maintenance, isn't it?

COPY Dockerfile /

# Also put my local imapsync on /usr/bin/ for testing purpose
# renamed imapsync_local since would be erased by the wget

COPY imapsync /usr/bin/imapsync_local
COPY prerequisites_imapsync /usr/bin/prerequisites_imapsync_local

RUN set -xe && \
  apt-get update \
  && apt-get install -y \
  libauthen-ntlm-perl \
  libcgi-pm-perl \
  libcrypt-openssl-rsa-perl \
  libdata-uniqid-perl \
  libencode-imaputf7-perl \
  libfile-copy-recursive-perl \
  libfile-tail-perl        \
  libio-socket-ssl-perl \
  libio-socket-inet6-perl \
  libio-tee-perl \
  libhtml-parser-perl \
  libjson-webtoken-perl \
  libmail-imapclient-perl \
  libparse-recdescent-perl \
  libmodule-scandeps-perl \
  libpar-packer-perl \
  libreadonly-perl \
  libregexp-common-perl \
  libsys-meminfo-perl \
  libterm-readkey-perl \
  libtest-mockobject-perl \
  libtest-pod-perl \
  libunicode-string-perl \
  liburi-perl  \
  libwww-perl \
  procps \
  wget \
  make \
  cpanminus \
  lsof \
  && rm -rf /var/lib/apt/lists/*

RUN set -xe \
  && pwd \
  && wget -N https://imapsync.lamiral.info/imapsync \
     https://imapsync.lamiral.info/prerequisites_imapsync \
  && mv imapsync /usr/bin/imapsync \
  && chmod +x /usr/bin/imapsync /usr/bin/imapsync_local # just_a_comment_to_force_update 2019_11_26_12_58_34


USER nobody:nogroup

ENV HOME /var/tmp/

WORKDIR /var/tmp/

STOPSIGNAL SIGINT

CMD ["/usr/bin/imapsync"]

# 
# End of imapsync Dockerfile 

