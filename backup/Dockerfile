FROM debian:latest
#COPY script.sh /root/script.sh
#RUN chmod +x /root/script.sh
COPY percona.deb /percona.deb
CMD mysql start
ENV DB_USER \
    DB_PASS \   
    DB_HOST  \
    ALL_DATABASES 
