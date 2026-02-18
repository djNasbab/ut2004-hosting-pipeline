# UT2004 is 32-bit x86 — always build for amd64, even on Apple Silicon.
FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV UT2004_DIR=/opt/ut2004

# Tools the installer script uses (jq, unshield, aria2/curl), plus 32-bit runtime libs.
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl jq aria2 unshield p7zip-full lbzip2 \
      libstdc++6:i386 libgcc-s1:i386 libc6:i386 \
      libx11-6:i386 libxext6:i386 libxrender1:i386 libxi6:i386 \
      libxrandr2:i386 libxinerama1:i386 libxcursor1:i386 \
      libasound2:i386 \
    && rm -rf /var/lib/apt/lists/*

# Fetch installer script
RUN curl -fsSL -o /tmp/install-ut2004.sh \
      https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-ut2004.sh \
    && chmod +x /tmp/install-ut2004.sh

# Install UT2004 headlessly into /opt/ut2004
# Pipe "yes" to auto-accept the Epic Games Terms of Service prompt
RUN yes | /tmp/install-ut2004.sh \
      --ui-mode none \
      --destination "${UT2004_DIR}" \
      --application-entry skip \
      --desktop-shortcut skip \
    && rm -f /tmp/install-ut2004.sh

# Add entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR ${UT2004_DIR}/System

# Game port, game port +1 (UDP), query port
EXPOSE 7777/udp 7778/udp 7787/udp

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
