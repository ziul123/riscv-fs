.data

.eqv RS232_BASE_ADDRESS 0xFF200120  
# RX_ADDRESS = 0xFF200120  
# TX_ADDRESS = 0xFF200121  
# CRTL_ADDRESS = 0xFF200122

test_buf: .space 10

.include "MACROSv24.s"

.text

# testando
jal RS232_ReadByte
jal RS232_SendByte
jal RS232_ReadInt
jal RS232_SendInt
la a0, test_buf
li a1, 10
jal RS232_ReadBuf
la a0, test_buf
li a1, 10
jal RS232_SendBuf
la a0, test_buf
li a1, 5
jal RS232_ReadBuf
la a0, test_buf
jal RS232_SendString
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

.include "SYSTEMv24.s"
