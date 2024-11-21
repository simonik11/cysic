#!/bin/bash

# Функция: проверяет успешность выполнения команды
check_command() {
    if [ $? -ne 0 ]; then
        echo "Ошибка выполнения команды: $1"
        exit 1
    fi
}

# Проверка, установлены ли Node.js, npm и PM2
check_installed() {
    command -v node >/dev/null 2>&1 && NODE_INSTALLED=true || NODE_INSTALLED=false
    command -v npm >/dev/null 2>&1 && NPM_INSTALLED=true || NPM_INSTALLED=false
    command -v pm2 >/dev/null 2>&1 && PM2_INSTALLED=true || PM2_INSTALLED=false
}

# Установка Node.js и PM2
install_dependencies() {

    if [ "$NODE_INSTALLED" = false ]; then
        echo "Устанавливаем Node.js и npm..."
        sudo apt install -y nodejs npm
        check_command "Ошибка при установке Node.js и npm"
    else
        echo "Node.js и npm уже установлены, пропускаем установку."
    fi

    if [ "$PM2_INSTALLED" = false ]; then
        echo "Устанавливаем PM2..."
        if ! curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -; then
            echo "Не удалось добавить репозиторий NodeSource. Пробуем альтернативный метод..."
            if ! curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -; then
                echo "Не удалось добавить репозиторий NodeSource для Node.js 16.x. Завершаем."
                exit 1
            fi
        fi

        if ! sudo apt-get install -y nodejs; then
            echo "Не удалось установить Node.js. Завершаем."
            exit 1
        fi

        echo "Версия Node.js: $(node -v)"
        echo "Версия npm: $(npm -v)"

        if ! sudo npm install pm2 -g; then
            echo "Не удалось установить PM2 через npm. Пробуем альтернативный метод..."
            if ! sudo apt install -y npm && sudo npm install pm2 -g; then
                echo "Не удалось установить PM2. Завершаем."
                exit 1
            fi
        fi

        echo "Версия PM2: $(pm2 -v)"
    else
        echo "PM2 уже установлен, пропускаем установку."
    fi
}

# Основное меню
while true; do
    echo "Выберите команду:"
    echo "1. Установить PM2 и настроить валидатор"
    echo "2. Запустить валидатор"
    echo "3. Остановить и удалить валидатор"
    echo "4. Удалить данные тестовой сети первого этапа"
    echo "0. Выйти"
    read -p "Введите номер команды: " command

    case $command in
        1)
            check_installed
            install_dependencies
            echo "PM2 и настройка валидатора завершены, возвращаемся в главное меню..."

            # Запрос адреса для вознаграждений
            read -p "Введите ваш адрес для вознаграждений: " reward_address

            # Загрузка и настройка валидатора
            echo "Скачиваем и настраиваем валидатор..."
            if curl -L https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/setup_linux.sh -o ~/setup_linux.sh; then
                bash ~/setup_linux.sh "$reward_address"
            else
                echo "Не удалось загрузить файл. Проверьте URL или подключение к сети."
            fi
            ;;

        2)
            # Запуск валидатора
            if [ ! -f pm2-start.sh ]; then
                echo "Создаем скрипт pm2-start.sh..."
                echo -e '#!/bin/bash\ncd ~/cysic-verifier/ && bash start.sh' > pm2-start.sh
                chmod +x pm2-start.sh
            fi

            echo "Запускаем валидатор..."
            if pm2 start ./pm2-start.sh --interpreter bash --name cysic-verifier; then
                echo "Cysic Verifier успешно запущен, возвращаемся в главное меню..."
            else
                echo "Не удалось запустить. Проверьте PM2 и скрипт."
            fi
            ;;

        3)
            # Остановка и удаление валидатора
            echo "Останавливаем и удаляем валидатор..."
            pm2 stop cysic-verifier
            pm2 delete cysic-verifier
            echo "Валидатор остановлен и удален, возвращаемся в главное меню..."
            ;;

        4)
            # Удаление данных тестовой сети первого этапа
            read -p "Вы уверены, что хотите удалить данные тестовой сети первого этапа? (y/n): " confirm
            if [ "$confirm" = "y" ]; then
                echo "Удаляем данные тестовой сети первого этапа..."
                sudo rm -rf ~/cysic-verifier
                sudo rm -rf ~/.cysic
                sudo rm -rf ~/.scr*
                echo "Данные тестовой сети первого этапа успешно удалены, возвращаемся в главное меню..."
            else
                echo "Операция удаления отменена, возвращаемся в главное меню."
            fi
            ;;

        0)
            echo "Выход из программы."
            exit 0
            ;;

        *)
            echo "Неверный номер команды, попробуйте снова."
            ;;
    esac
done
