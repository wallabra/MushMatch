FROM alpine:latest
LABEL maintainer="Gustavo Ramos Rehermann <rehermann6046@gmail.com>"

RUN apk add tar bzip2 gzip curl zip

RUN mkdir -pv /opt/ut-server/MushMatch
ADD . /opt/ut-server/MushMatch

WORKDIR /opt/ut-server/MushMatch
RUN ./.dockerprepare.sh
CMD ./.dockerbuild.sh
