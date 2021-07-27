FROM sebp/elk:latest
COPY 10-syslog.conf /etc/logstash/conf.d/
COPY syslog-ng.conf /etc/syslog-ng/
COPY GeoLite2-City.mmdb /etc/logstash/
RUN mkdir /var/log/bigip/bot /var/log/bigip/bot && rm -f /etc/logstash/conf.d/02-beats-input.conf /etc/logstash/conf.d/11-nginx.conf /etc/logstash/conf.d/30-output.conf && systemctl restart syslog