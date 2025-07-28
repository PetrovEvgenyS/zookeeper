# ZooNavigator

Интерфейс для работы с ZooKeeper через веб-браузер.

## Быстрый старт

1. Запустите контейнер ZooNavigator с помощью Docker:

    ```bash
    docker run -d \
        -p 9000:9000 \
        -e http_port=9000 \
        --name zoonavigator \
        --restart unless-stopped \
        elkozmon/zoonavigator:latest
    ```

2. Откройте браузер и перейдите по адресу: [http://localhost:9000](http://localhost:9000)

3. В поле **Connection string (Required)** укажите адрес ZooKeeper, например:

    ```
    10.100.10.1:2181
    ```

## Дополнительно

- [Документация ZooNavigator](https://github.com/elkozmon/zoonavigator)
- Для подключения можно использовать любой доступный адрес ZooKeeper.