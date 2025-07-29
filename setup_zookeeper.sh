#!/bin/bash

# --- Переменные ---
# Параметры ZooKeeper
ZOOKEEPER_VERSION="3.8.4"                             # Версия ZooKeeper для установки
ZOOKEEPER_DOWNLOAD_URL="https://downloads.apache.org/zookeeper/zookeeper-$ZOOKEEPER_VERSION/apache-zookeeper-$ZOOKEEPER_VERSION-bin.tar.gz"
ZOOKEEPER_USER="zookeeper"                            # Имя пользователя для ZooKeeper
ZOOKEEPER_GROUP="zookeeper"                           # Названгие группы для ZooKeeper
ZOOKEEPER_LOG="/var/log/zookeeper"                    # Директории логов ZooKeeper
INSTALL_DIR="/opt/zookeeper"                          # Директории установки ZooKeeper
DATA_DIR="/var/lib/zookeeper"                         # Директории данных ZooKeeper
CONFIG_DIR="${INSTALL_DIR}/conf"                      # Директория конфигурации ZooKeeper
ZOOKEEPER_CONF="${CONFIG_DIR}/zoo.cfg"                # Конфигурационный файл ZooKeeper
SERVICE_FILE="/etc/systemd/system/zookeeper.service"  # Файл службы Systemd
ID="$1"                 # ID сервера в кластере. ВАЖНО! Поменяй значение 1 на 2 или 3.


### ЦВЕТА ###
ESC=$(printf '\033') RESET="${ESC}[0m" MAGENTA="${ESC}[35m" RED="${ESC}[31m" GREEN="${ESC}[32m"

### Функции цветного вывода ###
magentaprint() { echo; printf "${MAGENTA}%s${RESET}\n" "$1"; }
errorprint() { echo; printf "${RED}%s${RESET}\n" "$1"; }
greenprint() { echo; printf "${GREEN}%s${RESET}\n" "$1"; }


# ---------------------------------------------------------------------------------------


# --- Проверка запуска через sudo ---
if [ -z "$SUDO_USER" ]; then
    errorprint "Пожалуйста, запустите скрипт через sudo."
    exit 1
fi

# --- Проверка наличия аргументов ---
if [ -z "$1" ]; then
  errorprint "Ошибка: не указан обязательный аргумент."
  echo "Пожалуйста, укажите ID сервера в кластере."
  echo "Использование: sudo $0 <ID-сервера>"
  echo "Пример: sudo $0 1"
  echo "Где:"
  echo "  <ID-сервера> - ID сервера в кластере. ВАЖНО! Поменяй значение 1 на 2 или 3."
  exit 1
fi

# --- Установка зависимостей ---
installing_dependencies() {
  magentaprint "Установка необходимых зависимостей..."
  dnf install -y java-11-openjdk wget tar
}


# --- Создание пользователя и группы для ZooKeeper ---
creating_user_group() {
  magentaprint "Создание пользователя и группы для ZooKeeper..."
  groupadd -r $ZOOKEEPER_GROUP
  useradd -r -g $ZOOKEEPER_GROUP -s /sbin/nologin -d $INSTALL_DIR $ZOOKEEPER_USER
}


# --- Скачивание и распаковка ZooKeeper ---
downloading_unpacking_zookeeper() {
  echo $(magentaprint "Скачивание и установка ZooKeeper версии $ZOOKEEPER_VERSION ...")
  wget $ZOOKEEPER_DOWNLOAD_URL -O /tmp/zookeeper.tar.gz
  mkdir -p $INSTALL_DIR
  tar -xzf /tmp/zookeeper.tar.gz -C $INSTALL_DIR --strip-components=1
  rm -f /tmp/zookeeper.tar.gz
}


# --- Настройка конфигурации ZooKeeper ---
creating_configuration_zookeeper() {
  magentaprint "Настройка конфигурации ZooKeeper $ZOOKEEPER_CONF"
  mkdir -p $DATA_DIR $ZOOKEEPER_LOG
    
  # --- Создание основного конфигурационного файла ZooKeeper ---
cat <<EOF > $ZOOKEEPER_CONF
# Базовый временной интервал (в миллисекундах), который ZooKeeper использует для heartbeat-сообщений и таймаутов.
# Например, initLimit и syncLimit умножаются на tickTime для определения реальных таймаутов.
# 2000 мс = 2 секунды – стандартное значение.
tickTime=2000

# Путь к директории, где ZooKeeper хранит свои снимки данных (snapshots).
dataDir=$DATA_DIR

# Путь к директории, где ZooKeeper хранит транзакционные логи (WAL – Write-Ahead Log).
dataLogDir=$ZOOKEEPER_LOG 

# Порт, на котором ZooKeeper принимает клиентские подключения.
clientPort=2181

# Максимальное количество одновременных подключений от одного клиента (по IP).
# Ограничивает нагрузку от одного клиента (защита от DDoS или ошибок в коде).
maxClientCnxns=60

# Время (в tickTime), в течение которого новые узлы (followers) могут подключиться к лидеру (leader) в кластере.
# 5 × 2000 мс = 10 секунд – максимальное время инициализации.
initLimit=5

# Максимальное количество tickTime, которое сервер позволяет другим узлам использовать для синхронизации состояния.
# 2 × 2000 мс = 4 секунды.
syncLimit=2

# Определение узлов кластера.
# Формат: server.X=<hostname>:<port1>:<port2>
# •	<hostname>: Имя хоста или IP-адрес.
# •	<port1>: Порт для обмена данными между серверами.
# •	<port2>: Порт для выборов лидера.
server.1=10.100.10.1:2888:3888
server.2=10.100.10.2:2888:3888
server.3=10.100.10.3:2888:3888

# Разрешает команды 4-letter word (4lw) для выполнения (stat, ruok, conf, wchs).
4lw.commands.whitelist=*

EOF

  # --- Создание файла myid для идентификации сервера в кластере. ---
  echo "$ID" > $DATA_DIR/myid
  chown -R $ZOOKEEPER_USER:$ZOOKEEPER_GROUP $DATA_DIR $INSTALL_DIR $ZOOKEEPER_LOG
  chmod 0700 $DATA_DIR $INSTALL_DIR $ZOOKEEPER_LOG
}


# --- Настройка сервиса Systemd для ZooKeeper ---
create_unit_zookeeper() {
magentaprint "Создание и настройка службы ZooKeeper в Systemd $SERVICE_FILE"
cat <<EOF > $SERVICE_FILE
[Unit]
Description=Apache ZooKeeper $ZOOKEEPER_VERSION Service
Documentation=https://zookeeper.apache.org
After=network.target

[Service]
Type=simple
User=$ZOOKEEPER_USER
Group=$ZOOKEEPER_GROUP
Environment="ZOOKEEPER_HOME=$INSTALL_DIR"
Environment="ZOOKEEPER_CONF=$CONFIG_DIR"
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/bin/zkServer.sh start-foreground
ExecStop=$INSTALL_DIR/bin/zkServer.sh stop
ExecReload=$INSTALL_DIR/bin/zkServer.sh restart
StandardOutput=append:$ZOOKEEPER_LOG/zookeeper.log
StandardError=append:$ZOOKEEPER_LOG/zookeeper-error.log
Restart=always
RestartSec=10
PrivateTmp=yes
PrivateDevices=yes
LimitCORE=infinity
LimitNOFILE=500000

[Install]
WantedBy=multi-user.target
Alias=zookeeper.service
EOF
}


# --- Перезагрузка Systemd и запуск ZooKeeper как сервиса ---
start_enable_zookeeper() {
  magentaprint "Перезагрузка Systemd и запуск ZooKeeper как сервиса..."
  systemctl daemon-reload
  systemctl enable zookeeper
  systemctl start zookeeper
}


# --- Функция проверки состояния ZooKeeper ---
check_status_zookeeper() {
  magentaprint "Проверка статуса службы ZooKeeper..."
  systemctl status zookeeper --no-pager
  magentaprint "ZooKeeper $ZOOKEEPER_VERSION успешно установлен и настроен как служба."
}


# --- Создание функций main ---
main() {
  installing_dependencies
  creating_user_group
  downloading_unpacking_zookeeper
  creating_configuration_zookeeper
  create_unit_zookeeper
  start_enable_zookeeper
  check_status_zookeeper
}

# --- Вызов функции main ---
main