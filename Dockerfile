FROM debian:12.5-slim

# Railway динамически назначает PORT через переменную окружения
ENV PORT=9118
# Минимизация логирования для Railway (лимит 500 logs/sec)
ENV ASPNETCORE_ENVIRONMENT=Production
ENV Logging__LogLevel__Default=Warning
ENV Logging__LogLevel__Microsoft=Warning
ENV Logging__LogLevel__Microsoft.AspNetCore=Warning
EXPOSE ${PORT}
WORKDIR /home

# Установка зависимостей
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    libicu-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Установка .NET Runtime 9.0.9
RUN curl -fSL -k -o dotnet.tar.gz https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/9.0.9/aspnetcore-runtime-9.0.9-linux-x64.tar.gz \
    && mkdir -p /usr/share/dotnet \
    && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz

# Скачивание и распаковка Lampac
RUN curl -L -k -o publish.zip https://github.com/immisterio/Lampac/releases/latest/download/publish.zip \
    && unzip -o publish.zip && rm -f publish.zip && rm -rf merchant \
    && rm -rf runtimes/os* && rm -rf runtimes/win* && rm -rf runtimes/linux-arm runtimes/linux-arm64 runtimes/linux-musl-arm64 runtimes/linux-musl-x64 \
    && touch isdocker

# Обновление конфигурации
RUN curl -k -s https://raw.githubusercontent.com/immisterio/Lampac/main/Build/Docker/update.sh | bash

# Установка TorrServer
RUN mkdir -p torrserver && curl -L -k -o torrserver/TorrServer-linux https://github.com/YouROK/TorrServer/releases/latest/download/TorrServer-linux-amd64 \
    && chmod +x torrserver/TorrServer-linux

# Создание базовой конфигурации для облачного деплоя (weblog отключен для Railway)
RUN echo '{"listen":{"port":"$PORT","scheme":"https"},"KnownProxies":[{"ip":"0.0.0.0","prefixLength":0}],"mikrotik":true,"typecache":"mem","watcherInit":"cron","pirate_store":false,"rch":{"keepalive":900},"weblog":{"enable":false},"chromium":{"enable":false},"firefox":{"enable":false},"LampaWeb":{"autoupdate":false,"initPlugins":{"timecode":false,"backup":false,"sync":false}},"cub":{"enable":true},"tmdb":{"enable":true},"serverproxy":{"verifyip":false,"buffering":{"enable":false},"image":{"cache":false,"cache_rsize":false}},"online":{"checkOnlineSearch":false}}' > /home/init.conf

# Конфигурация JacRed
RUN echo '"typesearch":"webapi","merge":null' > /home/module/JacRed.conf

# Конфигурация модулей
RUN echo '[{"enable":true,"dll":"SISI.dll"},{"enable":true,"dll":"Online.dll"},{"enable":true,"initspace":"Catalog.ModInit","dll":"Catalog.dll"},{"enable":true,"initspace":"TorrServer.ModInit","dll":"TorrServer.dll"},{"enable":true,"initspace":"Jackett.ModInit","dll":"JacRed.dll"}]' > /home/module/manifest.json

# Запуск приложения
ENTRYPOINT /usr/share/dotnet/dotnet Lampac.dll --urls "http://0.0.0.0:${PORT}"
