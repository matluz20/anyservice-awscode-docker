FROM xueshanf/awscli

RUN apk add --update \
    zip \
    git \
  && rm -rf /var/cache/apk/*

ADD scripts/start-build /usr/local/bin
ADD scripts/push-to-pipeline /usr/local/bin
