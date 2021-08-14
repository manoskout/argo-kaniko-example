FROM ubuntu:latest

RUN printf 'echo "THIS_IS_TOOL_1" > /tmp/del1.txt \
\ncat /tmp/del1.txt $1 > $2\
\necho "Appended to $1 and saved to $2"\
' > /tool1.sh

RUN cat /tool1.sh
