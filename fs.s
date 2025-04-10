.data

.eqv RS232_BASE_ADDRESS 0xFF200120  
# RX_ADDRESS = 0xFF200120  
# TX_ADDRESS = 0xFF200121  
# CRTL_ADDRESS = 0xFF200122

.eqv OPEN 1
.eqv CLOSE 2
.eqv LSEEK 3
.eqv READ 4
.eqv WRITE 5


test_buf: .word 0,0,0
test_file: .string "test.txt"
write_buf: .string "abcdefghij"

.include "MACROSv24.s"

.macro print_int(%i,%x,%y)
mv a0, %i
mv a1, %x
mv a2, %y
li a3, 0x00FF
li a7, 101
ecall
.end_macro


.macro print_str(%s,%x,%y)
la a0, %s
mv a1, %x
mv a2, %y
li a3, 0x00FF
li a7, 104
ecall
.end_macro


.macro print_char(%c,%x,%y)
mv a0, %c
mv a1, %x
mv a2, %y
li a3, 0x00FF
li a4, 0
li a7, 111
ecall
.end_macro

.text

# testando
li a0, 0
li a1, 0
li a7, 48
ecall

la a0, test_file
li a1, 9
jal Open
mv s1, a0
la a1, write_buf
li a2, 10
jal Write
mv a0, s1
jal Close

la a0, test_file
li a1, 0
jal Open
mv s1, a0
li a1, 1
li a2, 0
jal LSeek
mv a0, s1
la a1, test_buf
li a2, 3
jal Read
print_str(test_buf, zero, zero)
mv a0, s1
li a1, 1
li a2, 1
jal LSeek
mv a0, s1
la a1, test_buf
li a2, 3
jal Read
li t0, 8
print_str(test_buf, zero, t0)
mv a0, s1
li a1, -4
li a2, 2
jal LSeek
mv a0, s1
la a1, test_buf
li a2, 3
jal Read
li t0, 16
print_str(test_buf, zero, t0)
mv a0, s1
jal Close
li a7, 10
ecall


# a0 = byte a ser transmitido
RS232_SendByte: li t0, RS232_BASE_ADDRESS
RS232_SendByte.wait: lb t1, 2(t0)			# le o byte de controle
		andi t1, t1, 0x02	# mascara para obter o bit busy
		bnez t1, RS232_SendByte.wait	# caso esteja busy, espere
		sb a0, 1(t0)			# escreve o byte em TX
		li t1, 1
		sb t1, 2(t0)			# ativa o bit start
		sb zero, 2(t0)	# desativa o bit start
		ret

# a0 = int a ser transmitido
# big endian
RS232_SendInt: addi sp, sp, -8
		sw ra, 0(sp)	# salva endereco de retorno
		sw s0, 4(sp)

		mv s0, a0
		li t2, 3		# contador i (vai ate 0)
RS232_SendInt.loop:
		slli t0, t2, 3	# i * 8
		srl a0, s0, t0	# a0 >> (i * 8)
		andi a0, a0, 0x00FF
		jal RS232_SendByte
		addi t2, t2, -1
		bgez t2, RS232_SendInt.loop

		lw s0, 4(sp)
		lw ra, 0(sp)
		addi sp, sp, 8
		ret

# a0 = endereco do buffer
# a1 = quantidade de bytes a serem transmitidos
RS232_SendBuf: addi sp, sp, -8
		sw ra, 0(sp)
		sw s0, 4(sp)

		mv s0, a0
		add t2, a0, a1		# t2 = ultimo endereco + 1
RS232_SendBuf.loop:
		lb a0, 0(s0)
		jal RS232_SendByte
		addi s0, s0, 1
		blt s0, t2, RS232_SendBuf.loop

		lw s0, 4(sp)
		lw ra, 0(sp)
		addi sp, sp, 8
		ret

# a0 = endereco do inicio da string
RS232_SendString: addi sp, sp, -8
		sw ra, 0(sp)
		sw s0, 4(sp)

		mv s0, a0
RS232_SendString.loop:
		lb a0, 0(s0)
		jal RS232_SendByte
		beqz a0, RS232_SendString.end
		addi s0, s0, 1
		j RS232_SendString.loop

RS232_SendString.end:
		lw s0, 4(sp)
		lw ra, 0(sp)
		addi sp, sp, 8
		ret

# Retorna
# a0 = byte lido
# blocking
RS232_ReadByte: li t0, RS232_BASE_ADDRESS
RS232_ReadByte.wait: lb t1, 2(t0)			# le o byte de controle
		andi t1, t1, 0x04	# mascara para obter o bit ready
		beqz t1, RS232_ReadByte.wait	# caso nao esteja ready, espere
		lbu a0, 0(t0)	# le o byte que esta em RX 
RS232_ReadByte.wait2: lb t1, 2(t0)		# le o byte de controle
		bnez t1, RS232_ReadByte.wait2		# espera o bit ready desativar
		ret

# Retorna
# a0 = inteiro lido
# big endian
RS232_ReadInt: addi sp, sp, -8
		sw ra, 0(sp)	# salva endereco de retorno
		sw s0, 4(sp)

		mv s0, zero
		li t2, 3			# contador i (vai ate 0)
RS232_ReadInt.loop:
		jal RS232_ReadByte
		slli t0, t2, 3	# i * 8
		sll a0, a0, t0	# a0 << (i * 8)
		or s0, s0, a0
		addi t2, t2, -1
		bgez t2, RS232_ReadInt.loop
		mv a0, s0

		lw s0, 4(sp)
		lw ra, 0(sp)
		addi sp, sp, 8
		ret

# a0 = endereco do buffer
# a1 = quantidade de bytes a serem lidos
RS232_ReadBuf: addi sp, sp, -8
		sw ra, 0(sp)	# salva endereco de retorno
		sw s0, 4(sp)

		mv s5, a1
		mv s0, a0
		mv t2, zero		# contador
RS232_ReadBuf.loop:
		jal RS232_ReadByte
		sb a0, 0(s0)
		addi t2, t2, 1
		addi s0, s0, 1
		blt t2, s5, RS232_ReadBuf.loop

		lw s0, 4(sp)
		lw ra, 0(sp)
		addi sp, sp, 8
		ret

##################################################
# Open
# a0 = endereco da string com o caminho do arquivo
# a1 = flag (0: read only, 1: write only, 9: write append)
#####
# retornos
# a0 = descritor do arquivo (-1 em caso de erro)
################################################
Open: addi sp, sp, -4
		sw ra, 0(sp)	# salva endereco de retorno

		mv s0, a0
		li a0, OPEN
		jal RS232_SendByte		# manda codigo da chamada pro pc
		mv a0, s0
		jal RS232_SendString	# manda caminho do arquivo pro pc
		mv a0, a1
		jal RS232_SendByte		# manda flag pro pc

		jal RS232_ReadInt			# le o descritor do arquivo

		lw ra, 0(sp)
		addi sp, sp, 4
		ret

#############################################
#	Close
# a0 = descritor do arquivo
#########################################
Close: addi sp, sp, -4
		sw ra, 0(sp)

		mv s0, a0
		li a0, CLOSE
		jal RS232_SendByte	# manda o codigo da chamada pro pc
		mv a0, s0
		jal RS232_SendInt		# manda o descritor do arquivo pro pc 

		lw ra, 0(sp)
		addi sp, sp, 4
		ret


#####################################
# LSeek
# a0 = descritor do arquivo
# a1 = offset
# a2 = whence (0: inicio, 1: posicao atual, 2: final)
#####
# retorna
# a0 = posicao no arquivo a partir do inicio
########################################
LSeek: addi sp, sp, -4
		sw ra, 0(sp)

		mv s0, a0
		li a0, LSEEK
		jal RS232_SendByte	# manda o codigo da chamada pro pc
		mv a0, s0
		jal RS232_SendInt		# manda o descritor do arquivo pro pc 
		mv a0, a1
		jal RS232_SendInt		# manda offset pro pc
		mv a0, a2
		jal RS232_SendByte	# manda whence pro pc

		jal RS232_ReadInt		# le a posicao final no arquivo

		lw ra, 0(sp)
		addi sp, sp, 4
		ret

#####################################
# Read
# a0 = descritor do arquivo
# a1 = endereco do buffer onde os bytes serao escritos
# a2 = quantidade de bytes a serem lidos
#####
# retorna
# a0 = quantidade de bytes lidos
########################################
Read: addi sp, sp, -4
		sw ra, 0(sp)

		mv s0, a0
		li a0, READ
		jal RS232_SendByte	# manda o codigo da chamada pro pc
		mv a0, s0
		jal RS232_SendInt		# manda descritor do arquivo pro pc
		mv a0, a2
		jal RS232_SendInt		# manda quantidade de bytes a serem lidos pro pc

		jal RS232_ReadInt		# le quantos bytes foram lidos
		mv s0, a0
		mv a0, a1
		mv a1, s0
		jal RS232_ReadBuf
		mv a0, s0

		lw ra, 0(sp)
		addi sp, sp, 4
		ret

#####################################
# Write
# a0 = descritor do arquivo
# a1 = endereco do buffer com os bytes que serao escritos
# a2 = quantidade de bytes a serem escritos
#####
# retorna
# a0 = quantidade de bytes escritos
########################################
Write: addi sp, sp, -4
		sw ra, 0(sp)

		mv s0, a0
		li a0, WRITE
		jal RS232_SendByte	# manda o codigo da chamada pro pc
		mv a0, s0
		jal RS232_SendInt		# manda descritor do arquivo pro pc
		mv a0, a2
		jal RS232_SendInt		# manda quantidade de bytes a serem escritos pro pc

		mv a0, a1
		mv a1, a2
		jal RS232_SendBuf		# manda bytes a serem escritos pro pc

		jal RS232_ReadInt		# le quantos bytes foram escritos

		lw ra, 0(sp)
		addi sp, sp, 4
		ret


.include "SYSTEMv24.s"
