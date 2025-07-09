/* Syscalls
	Open (1024)
		params
 		* a0 = string of path
		* a1 = flags {0->RO, 1->WO, 9->WA}
		returns
		* a0 = file descriptor (-1 if error)
	Close (57)
		params
		* a0 = file descriptor
	LSeek (62)
		params
		* a0 = file descriptor
		* a1 = offset
		* a2 = flag {0->beginning, 1->curr pos, 2->EOF}
		returns
		* a0 = selected position from beginning of the file (-1 if error)
	Read (63)
		params
		* a0 = file descriptor
		* a1 = address of buffer
		* a2 = max len to read
		returns
		* a0 = len read (-1 if error)
	Write (64)
		params
		* a0 = file descriptor
		* a1 = address of buffer
		* a2 = len to write
		returns
		* a0 = num of char written
*/

#include <stdlib.h>
#include <stdio.h>
#include <errno.h>

#ifdef _WIN32
#include <Windows.h>
#else
#include <unistd.h>
#endif

#include "rs232.h"

FILE *files[1024] = {0};

enum SYSCALLS {OPEN = 1, CLOSE, LSEEK, READ, WRITE};

int cport_nr; /* número da COM - 1 */

char RS232_ReadByte(int cport_nr) {
	char result;
	while (1) {
		int n = RS232_PollComport(cport_nr, &result, 1);
		if (n == 0)
			continue;
		return result;
	}
}

int RS232_ReadInt(int cport_nr) {
	/* big endian */
	int result = 0;
	for (int i = 3; i >= 0; i--) {
		unsigned char aux = RS232_ReadByte(cport_nr);
		unsigned int mask = aux << (8 * i);
		result = result | mask;
	}
	return result;
}

void RS232_ReadString(int cport_nr, char *buf) {
	while (1) {
		char c = RS232_ReadByte(cport_nr);
		*(buf++) = c;
		if (!c)
			return;
	}
}

void RS232_ReadBuf(int cport_nr, unsigned char *buf, int size) {
	for (int i = 0; i < size; i++) {
		unsigned char c = RS232_ReadByte(cport_nr);
		buf[i] = c;
	}
}

int RS232_SendInt(int cport_nr, int data) {
	/* big endian */
	unsigned char buf[4];
	for (int i = 0; i < 4; i++) {
		unsigned char aux = (unsigned int) data >> (8 * (3 - i));
		buf[i] = aux;
	}
	int ret = RS232_SendBuf(cport_nr, buf, 4);
	if (ret != 4) {
		printf("Erro ao transmitir int\n");
		return -1;
	}
	return 0;
}

void syscall_open() {
	char filepath[255];
	RS232_ReadString(cport_nr, filepath);
	printf("filepath: %s\n", filepath);
	char flags = RS232_ReadByte(cport_nr);
	printf("flags: %hhd\n", flags);
	const char *mode;
	/* flags {0->RO, 1->WO, 9->WA} */
	switch (flags) {
		case 0:
			mode = "rb";
			break;
		case 1:
			mode = "wb";
			break;
		case 9:
			mode = "ab";
			break;
	}
	int fd;
	FILE *f = fopen(filepath, mode);
	if (!f) {
		fprintf(stderr, "Erro ao abrir o arquivo %s: %s\n", filepath, strerror(errno)); 
		fd = -1;
	} else {
		fd = fileno(f);
		files[fd] = f;	/* salva o stream do arquivo aberto no indice do descritor do arquivo */
		printf("Arquivo %s aberto no descritor %d com sucesso\n", filepath, fd);
	}
	int ret = RS232_SendInt(cport_nr, fd);
	if (ret == -1)
		printf("Erro ao mandar descritor do arquivo\n");
	return;
}

void syscall_close() {
	int fd = RS232_ReadInt(cport_nr);
	FILE *f = files[fd];
	int ret = fclose(f);
	if (ret)
		perror("Erro ao fechar o arquivo");
}

void syscall_lseek() {
	int fd = RS232_ReadInt(cport_nr);
	printf("fd: %d\n", fd);
	int offset = RS232_ReadInt(cport_nr);
	printf("offset: %d\n", offset);
	char w = RS232_ReadByte(cport_nr);
	printf("whence: %d\n", w);
	int whence[3] = {SEEK_SET, SEEK_CUR, SEEK_END};
	int tmp = fseek(files[fd], offset, whence[w]);
	int ret;
	if (tmp == -1) {
		fprintf(stderr, "Erro no fseek: %s\n", strerror(errno));
		ret = -1;
	} else
		ret = ftell(files[fd]);
	RS232_SendInt(cport_nr, ret);
}

void syscall_read() {
	int fd = RS232_ReadInt(cport_nr);
	printf("fd: %d\n", fd);
	int n = RS232_ReadInt(cport_nr);
	printf("n: %d\n", n);
	char buf[n];
	int count = fread(buf, 1, n, files[fd]);
	printf("%d bytes lidos\n", count);
	RS232_SendInt(cport_nr, count);
	int r = RS232_SendBuf(cport_nr, buf, count);
	if (r == -1)
		printf("Erro ao mandar bytes lidos.\n");
	else
		printf("%d bytes mandados\n", r);
	return;
}

void syscall_write() {
	int fd = RS232_ReadInt(cport_nr);
	printf("fd: %d\n", fd);
	int n = RS232_ReadInt(cport_nr);
	printf("n: %d\n", n);
	char buf[n];
	RS232_ReadBuf(cport_nr, buf, n);
	int count = fwrite(buf, 1, n, files[fd]);
	printf("%d bytes escritos\n", count);
	RS232_SendInt(cport_nr, count);
}

int main(int argc, char **argv) {
  if (argc == 2) cport_nr = atoi(argv[1]);
  else {puts("o primeiro argumento deve ser o numero da COM - 1"); return 1;}
  int bdrate=115200;
  char mode[]={'8','N','2',0};

  if(RS232_OpenComport(cport_nr, bdrate, mode))
  {
    printf("Can not open comport\n");
    return(0);
  }

	while (1) {
		Sleep(1);
		printf("Esperando syscall\n");
		unsigned char syscall = RS232_ReadByte(cport_nr);
		printf("Syscall: %hhu\n", syscall);
		switch (syscall) {
			case OPEN:
				syscall_open();
				break;
			case CLOSE:
				syscall_close();
				break;
			case LSEEK:
				syscall_lseek();
				break;
			case READ:
				syscall_read();
				break;
			case WRITE:
				syscall_write();
				break;
			default:
				printf("No syscall (%hhd)\n", syscall);
		}
	}
}
