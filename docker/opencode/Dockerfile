FROM ghcr.io/anomalyco/opencode:latest

RUN apk add --no-cache bash ca-certificates curl git openssh-client rsync \
    python3 py3-pip py3-matplotlib \
    && rm -rf /tmp/opencode

ARG USER_UID=1000
RUN adduser -D -u "${USER_UID}" -h /home/agent -s /bin/bash agent \
    && mkdir -p /workspace \
    && chown agent:agent /workspace

USER agent
ENV HOME=/home/agent
WORKDIR /workspace
ENTRYPOINT ["opencode"]
