module Immortal
    # Подключаем библиотеку, связанную с временем
    include("./utils/Utils.jl")
    import .Utils

    # Подключаем библиотеку для работы с RabbitMQ и каналами
    include("./rabbitmq/Rabbit.jl")
    import .Rabbit


    """Функция для запуска сервера для работы с Rabbit.


    login: логин пользователя на сервисе очередей, 
    password: пароль пользователя на сервисе очередей, 
    vhost: вируальный хост на сервисе очередей, 
    port: порт подключения для сервиса очередей
    """
    function run(login::String, password::String, vhost::String, port::Int64)
        @info Utils.Chronometer.message_with_time("Вызвана функция запуска сервера...")
        # Задаём значение хоста по умолчанию
        host::String = "api.seon.cloud"
        # Логер вызова функции для режима отладки
        @debug "Параметры вызова функции:"
        @debug "- логин пользователя для подключения к серверу RabbitMQ" login
        @debug "- пароль пользователя для подключения к серверу RabbitMQ" password
        @debug "- virtialhost для подключения к серверу RabbitMQ" vhost
        @debug "- порт для подключения к серверу RabbitMQ" port
        @debug "- хост для подключения к серверу RabbitMQ" host
        # Задаем значение статуса соединеня с сервером RabbitMQ
        is_connected::Bool = false
        # Инициализируем переменную соединения с пустым значеним
        connection = nothing

        # Подключаемся к серверу RabbitMQ
        try
            # Получаем параметры автризации на сервисе очередей
            auth_params::Dict{String, Any} = Rabbit.get_auth_params(login, password)
            # Получаем соединени с сервером очередей
            connection = Rabbit.get_connection(vhost, host, port, auth_params)
            # Создаём канал для работы с сервисом очередей
            chanel = Rabbit.get_channel(connection, nothing, true)
            # Создаём обменник
            exchanger::Dict{String, Any} = Rabbit.Exchanges.declare(chanel, "test", "direct")
            # Регистрируем очередь внутри виртуалхоста
            queue_1::Dict{String, Any} = Rabbit.Queues.declare(chanel, "MyFirstQueue")
            queue_2::Dict{String, Any} = Rabbit.Queues.declare(chanel, "MySecondQueue")
            #
            q1_name::Any = get(queue_1, "NAME", nothing)
            q2_name::Any = get(queue_2, "NAME", nothing)
            #
            queue_1_deleted::Dict{String, Any} = Rabbit.Queues.delete(chanel, q1_name)
            #
            exchanger_name::Any = get(exchanger, "NAME", nothing)
            route::Dict{String, Any} = Rabbit.Queues.bind(chanel, q2_name, exchanger_name, "MyTestRoute")
            route_name::Any = get(route, "NAME", nothing)

            example_data = "Hello, world"
            msg_props = Dict{String, Any}(
                "CONTENT_TYPE" => "plain/text"
            )
            publish_result = Rabbit.Messages.create_and_publish(chanel, exchanger_name, route_name, example_data, msg_props)

            user_consumer(message) = println(message)
            subscribe_queue = Rabbit.Queues.subscribe(chanel, q2_name, user_consumer)

            unsubscrive_queue = Rabbit.Queues.unsubscribe(chanel, "some_tag")

            purge_messages = Rabbit.Queues.purge(chanel, q2_name)
            reoute_deleted::Bool = Rabbit.Queues.unbind(chanel, q2_name, exchanger_name, route_name)
            # Удаление обменника
            exchange_deleted::Bool = Rabbit.Exchanges.delete(chanel, exchanger_name)

            # Меняем значение статуса соединеня
            is_connected = true
        catch error
            @error Utils.Chronometer.message_with_time("Завершение работы сервера. Ошибка") error
            exit()
        end

        Rabbit.shotdown(connection)
    end
end
