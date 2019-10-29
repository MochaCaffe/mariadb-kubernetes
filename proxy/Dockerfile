FROM mariadb:10.4
COPY script.sh /root/
RUN chmod +x /root/script.sh \
    && apt update \
    && apt -y install dnsutils \
    && rm -rf /var/lib/apt/lists/*
CMD /root/script.sh
