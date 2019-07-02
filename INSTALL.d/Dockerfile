## Dockerfile for building a docker imapsync image

# $Id: Dockerfile,v 1.15 2019/02/26 11:39:31 gilles Exp gilles $
# I use the following command to build the image:
#
#  docker build -t gilleslamiral/imapsync . 
#
# where this Dockerfile is in the current directory
# 
# I like thanks
# I like stars
# I also like (and need) money
# I thank you very much in advance


FROM debian:stretch 

LABEL maintainer "gilles@lamiral.info"

# Put a copy of the Dockerfile in the image itself
# It can help future maintenance, isn't it?

# Also put my last imapsync on / for testing purpose
COPY Dockerfile imapsync /

RUN apt-get update \
  && apt-get install -y \
  libjson-webtoken-perl \
  libauthen-ntlm-perl \
  libcgi-pm-perl \
  libcrypt-openssl-rsa-perl \
  libdata-uniqid-perl \
  libfile-copy-recursive-perl \
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
  && rm -rf /var/lib/apt/lists/*

RUN wget -N https://imapsync.lamiral.info/imapsync \
  https://imapsync.lamiral.info/prerequisites_imapsync \
  && cp imapsync /usr/bin/imapsync \
  && chmod +x /usr/bin/imapsync # just_a_comment_to_force_update 2018_09_13_14_44_03

USER nobody

ENV HOME /var/tmp/

CMD ["/usr/bin/imapsync"]

# 
# End of imapsync Dockerfile 

