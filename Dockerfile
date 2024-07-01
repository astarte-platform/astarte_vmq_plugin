FROM hexpm/elixir:1.15.5-erlang-26.1-debian-bullseye-20230612-slim as builder

# install build dependencies
# --allow-releaseinfo-change allows to pull from 'oldstable'
RUN apt-get update --allow-releaseinfo-change -y \
  && apt-get install -y build-essential git curl \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /build

# Needed for VerneMQ 1.13.0
RUN apt-get -qq update && apt-get -qq install libsnappy-dev libssl-dev

# Let's start by building VerneMQ
RUN git clone https://github.com/vernemq/vernemq.git -b 2.0.0

RUN cd vernemq && \
  make rel && \
  cd ..

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix hex.info

ENV MIX_ENV prod

# Pass --build-arg BUILD_ENV=dev to build a dev image
ARG BUILD_ENV=prod

ENV MIX_ENV=$BUILD_ENV

# Cache elixir deps
ADD mix.exs mix.lock astarte_vmq_plugin/
RUN cd astarte_vmq_plugin && \
  mix do deps.get, deps.compile && \
  cd ..

# Add all the rest
ADD . astarte_vmq_plugin/

# Build and release
RUN cd astarte_vmq_plugin && \
  mix do compile, release && \
  cd ..

# Copy the schema over
RUN cp astarte_vmq_plugin/priv/astarte_vmq_plugin.schema vernemq/_build/default/rel/vernemq/share/schema/

# Copy configuration files here - mainly because we want to keep the target image as small as possible
# and avoid useless layers.
COPY docker/files/vm.args /build/vernemq/_build/default/rel/vernemq/etc/
COPY docker/files/vernemq.conf /build/vernemq/_build/default/rel/vernemq/etc/
COPY docker/bin/rand_cluster_node.escript /build/vernemq/_build/default/rel/vernemq/bin/
COPY docker/bin/vernemq.sh /build/vernemq/_build/default/rel/vernemq/bin/
RUN chmod +x /build/vernemq/_build/default/rel/vernemq/bin/vernemq.sh

# Note: it is important to keep Debian versions in sync, or incompatibilities between libcrypto will happen
FROM debian:bullseye-slim

# Set the locale
ENV LANG C.UTF-8

# We have to redefine this here since it goes out of scope for each build stage
ARG BUILD_ENV=prod

# We need SSL, curl, iproute2 and jq - and to ensure /etc/ssl/astarte
RUN apt-get -qq update && apt-get -qq install libssl1.1 curl jq iproute2 netcat libsnappy1v5 && apt-get clean && mkdir -p /etc/ssl/astarte

# Copy our built stuff (both are self-contained with their ERTS release)
COPY --from=builder /build/vernemq/_build/default/rel/vernemq /opt/vernemq/
COPY --from=builder /build/astarte_vmq_plugin/_build/$BUILD_ENV/rel/astarte_vmq_plugin /opt/astarte_vmq_plugin/

# Add the wait-for utility
RUN cd /usr/bin && curl -O https://raw.githubusercontent.com/eficode/wait-for/master/wait-for && chmod +x wait-for && cd -

# MQTT
EXPOSE 1883

# MQTT for Reverse Proxy
EXPOSE 1885

# MQTT/SSL
EXPOSE 8883

# VerneMQ Message Distribution
EXPOSE 44053

# EPMD - Erlang Port Mapper Daemon
EXPOSE 4369

# Specific Distributed Erlang Port Range
EXPOSE 9100 9101 9102 9103 9104 9105 9106 9107 9108 9109

# Prometheus Metrics
EXPOSE 8888

# Expose port for webroot ACME verification (in case)
EXPOSE 80

CMD ["/opt/vernemq/bin/vernemq.sh"]
