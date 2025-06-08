delay: delay.c
	gcc -c delay.c
server: server.asm delay
	fasm server.asm
	ld server.o delay.o -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2 -lm -o server
client: client.asm
	fasm client.asm
	ld client.o delay.o -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2 -lm -o client
