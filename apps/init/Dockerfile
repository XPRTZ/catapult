FROM alpine
RUN apk update && apk add --no-cache postgresql17-client nodejs

WORKDIR /database/
COPY apps/init/database-init.sh .
RUN chmod +x database-init.sh

CMD ["./database-init.sh"]
