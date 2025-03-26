.data

.eqv RS232_BASE_ADDRESS 0xFF200120  
# RX_ADDRESS = 0xFF200120  
# TX_ADDRESS = 0xFF200121  
# CRTL_ADDRESS = 0xFF200122

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
		sb sb zero, 2(t0)	# desativa o bit start
		ret

# a0 = int a ser transmitido
# big endian
RS232_SendInt: addi sp, sp, -8
		sw ra, 0(sp)	# salva endereco de retorno
		sw s0, 4(sp)

		mv s0, a0
		mv t2, zero		# contador
		li t3, 4			# maximo de iteracoes
RS232_SendInt.loop:
		neg t0, t2
		addi t0, t0, 3
		slli t0, t0, 3
		srl a0, s0, t0
		andi a0, a0, 0x00FF
		jal RS232_SendByte
		addi t2, t2, 1
		blt t2, t3, RS232_SendInt.loop

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
		beqz a0, RS232_SendString.end
		jal RS232_SendByte
		addi a0, a0, 1
		j RS232_SendString.loop

RS232_SendString.end
		lw s0, 4(sp)
		lw ra, 0(sp)
		addi sp, sp, 8
		ret


.include "SYSTEMv24.s"
