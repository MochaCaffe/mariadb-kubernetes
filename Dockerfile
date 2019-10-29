FROM mariadb:10.4
WORKDIR /root/
#COPY *.sh /root/
COPY background-script.sh /root/background-script.sh
COPY backup/script.sh /root/backup-script.sh
RUN chmod +x /root/background-script.sh \
    && apt update \
    && apt -y install dnsutils netcat \
    && rm -rf /var/lib/apt/lists/*
