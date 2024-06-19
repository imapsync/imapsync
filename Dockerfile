# Use an official Perl runtime as a parent image
FROM perl:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    git \
    cpanminus \
    make \
    libauthen-ntlm-perl \
    libclass-load-perl \
    libcrypt-openssl-rsa-perl \
    libdata-uniqid-perl \
    libdigest-hmac-perl \
    libfile-copy-recursive-perl \
    libio-compress-perl \
    libio-socket-inet6-perl \
    libio-socket-ssl-perl \
    libmail-imapclient-perl \
    libmodule-scandeps-perl \
    libnet-ssleay-perl \
    libpar-packer-perl \
    libssl-dev \
    libterm-readkey-perl \
    libtest-mock-guard-perl \
    libtest-pod-perl \
    libunicode-string-perl \
    wget \
    gcc \
    libc-dev

# Install Perl modules
RUN cpanm --force Test::NoWarnings && \
    cpanm --force Digest::HMAC_SHA1 && \
    cpanm --force Encode::IMAPUTF7 && \
    cpanm --force File::Copy::Recursive && \
    cpanm --force IO::Socket::INET6 && \
    cpanm  --force IO::Tee  && \
    cpanm  --force  Mail::IMAPClient && \
    cpanm  --force Term::ReadKey && \
    cpanm  --force Unicode::String && \ 
    cpanm  --force Readonly && \
    cpanm  --force  Sys::MemInfo && \
    cpanm  --force  Regexp::Common && \
    cpanm  --force  File::Tail 

# Clone the imapsync repository
RUN git clone https://github.com/imapsync/imapsync.git /opt/imapsync

# Set the working directory
WORKDIR /opt/imapsync

# Make imapsync executable
RUN chmod +x imapsync

# Define the entry point
ENTRYPOINT ["./imapsync"]
