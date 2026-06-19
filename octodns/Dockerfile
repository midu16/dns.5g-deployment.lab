FROM python:3.12-slim

WORKDIR /octodns
COPY requirements.txt /octodns/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

ENTRYPOINT ["octodns-sync"]
CMD ["--config-file", "/octodns/config.yaml"]
