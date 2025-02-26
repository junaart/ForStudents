import socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  # создаем сокет
sock.bind(('', 1111))  # связываем сокет с портом, где он будет ожидать сообщения
sock.listen(10)  # указываем сколько может сокет принимать соединений
print('Server is running')
conn, addr = sock.accept()  # начинаем принимать соединения
print('connected:', addr)  # выводим информацию о подключении
data = conn.recv(1024)  # принимаем данные от клиента, по 1024 байт
print(str(data))
conn.send(bytes("Server answer", encoding = 'UTF-8'))  # в ответ клиенту
conn.close()  # закрываем соединение
