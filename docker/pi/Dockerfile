FROM node:24-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash ca-certificates curl git openssh-client ripgrep rsync \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent \
    && npm cache clean --force

ARG USER_UID=1000
RUN usermod --uid "${USER_UID}" node \
    && mkdir -p /workspace \
    && chown node:node /workspace

USER node
ENV HOME=/home/node
WORKDIR /workspace
ENTRYPOINT ["pi"]
