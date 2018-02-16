FROM xueshanf/awscli

RUN apk add --update \
    zip \
    git \
  && rm -rf /var/cache/apk/*

ADD scripts/ /usr/local/bin

RUN chmod +x /usr/local/bin/start-build
RUN chmod +x /usr/local/bin/push-to-pipeline
RUN chmod +x /usr/local/bin/aws_assume_role
