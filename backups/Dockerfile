FROM python:3.10.14-alpine3.20

RUN apk add --no-cache bash docker-cli

WORKDIR /app

COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY ./ ./

CMD ["bash", "database_backup.sh"]