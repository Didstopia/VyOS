FROM debian:bullseye

# Tell the OS that we want to run non-interactively at all times,
# however only do this at build time, using ARG instead of ENV.
ARG DEBIAN_FRONTEND=noninteractive

# Setup locales
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      locales && \
    rm -rf /var/lib/apt/lists/* && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install dependencies, eg. for Docker-in-Docker support.
RUN apt-get update && apt-get install -y --no-install-recommends \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg \
      gnupg-agent \
      lsb-release \
      software-properties-common \
      wget \
      curl \
      git \
      sudo && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
      sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      docker-ce \
      docker-ce-cli \
      containerd.io

# Export the Docker socket as a volume
VOLUME /var/run/docker.sock

## TODO: Use an entrypoint script that ensure that the Docker socket is available?

# Switch working directory
WORKDIR /vyos

# Add the build script and set it as the primary entrypoint.
COPY scripts/build.sh /vyos/build.sh
RUN chmod +x /vyos/build.sh
ENTRYPOINT [ "/vyos/build.sh" ]
