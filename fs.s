.data

.eqv RS232_BASE_ADDRESS 0xFF200120  
# RX_ADDRESS = 0xFF200120  
# TX_ADDRESS = 0xFF200121  
# CRTL_ADDRESS = 0xFF200122

test_buf: .space 10

.include "MACROSv24.s"

.text

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

		mv s0, a0
		mv t2, zero		# contador
RS232_ReadBuf.loop:
		jal RS232_ReadByte
		sb a0, 0(s0)
		addi t2, t2, 1
		addi s0, s0, 1
		blt t2, a1, RS232_ReadBuf.loop

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

		jal RS232_SendInt		# manda o descritor do arquivo pro pc 

		lw ra, 0(sp)
		addi sp, sp, 4

#####################################
# Read
# a0 = descritor do arquivo
# a1 = endereco do buffer onde os bytes serao escritos
# a2 = quantidade de bytes a serem escritos
#####
# retorna
# a0 = quantidade de bytes lidos
########################################
Read: addi sp, sp, -4
		sw ra, 0(sp)

		jal RS232_SendInt		# manda descritor do arquivo pro pc
		mv a0, a2
		jal RS232_SendInt		# manda quantidade de bytes a serem lidos pro pc

		jal RS232_ReadInt		# le quantos bytes foram lidos
		mv t0, a1
		mv a1, a0
		mv a0, t0		# a0 = endereco do buffer, a1 = quantos bytes ler
		jal RS232_ReadBuf
		mv a0, a1

		lw ra, 0(sp)
		addi sp, sp, 4
		ret


.include "SYSTEMv24.s"
