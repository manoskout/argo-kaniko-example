FROM ubuntu:latest

RUN printf 'echo "THIS_IS_TOOL_2" > /tmp/del2.txt \
\ncat /tmp/del2.txt $1 > $2 \
\necho "Appended to $1 and saved to $2" \
' > /tool2.sh

RUN cat /tool2.sh
