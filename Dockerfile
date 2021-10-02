FROM 32bit/debian:latest
LABEL maintainer="Gustavo Ramos Rehermann <rehermann6046@gmail.com>"

# Install build dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update &&\
    apt install -y --force-yes tar bzip2 gzip curl zip git bash parallel &&\
    rm -rf /var/lib/apt/lists/*

# Grab Go, and use it to grab another build dependency
RUN curl -L -C- https://golang.org/dl/go1.17.1.linux-386.tar.gz -o/var/tmp/go1.17.1.linux-386.tar.gz &&\
    tar -C /usr/local -xf /var/tmp/go1.17.1.linux-386.tar.gz &&\
    rm /var/tmp/go1.17.1.linux-386.tar.gz

RUN echo PATH="$PATH:/usr/local/go/bin">>$HOME/.profile &&\
    /usr/local/go/bin/go install github.com/cbroglie/mustache/...@latest

# Prepare the build environment
RUN mkdir -pv /opt/ut-server/MushMatch
ADD . /opt/ut-server/MushMatch

WORKDIR /opt/ut-server/MushMatch
RUN ./.dockerprepare.sh
CMD ./.dockerbuild.sh
