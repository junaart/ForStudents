import socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  # создаем сокет
sock.connect(('localhost', 1111))  # подключемся к серверному сокету
message=input('Введите сообщение для сервера')
sock.send(bytes(message, encoding = 'UTF-8'))  # отправляем сообщение
data = sock.recv(1024)  # читаем ответ от серверного сокета
print(str(data))
sock.close()  # закрываем соединение
