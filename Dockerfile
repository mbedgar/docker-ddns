FROM mcr.microsoft.com/powershell:alpine-3.8

WORKDIR /Script
ENV Slack="Not_Set"
ENV poll=300
COPY ddns.ps1 .
ENTRYPOINT ["pwsh"]
CMD ["./ddns.ps1"]