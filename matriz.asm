.MODEL SMALL
.STACK 100h

.DATA
    filedados   db 'DADOS.TXT', 0
    fileexp     db 'EXP.TXT', 0
    fileresult  db 'RESULT.TXT', 0
    handle      dw 0
    buffer      db 1000 dup(?)
    buffer_exp  db 1000 dup(?)
    bytes_read  dw 0
    matriz      dw 100 dup(20 dup(?)) ;matriz 100x20 (linhas x colunas)
    matriz_numeros dw 100 dup(20 dup(?)) ;matriz de numero
    linhas      dw 0                  ;número de linhas lidas
    colunas     dw 0                  ;número de colunas
    temp_colunas dw 0                 ;contador temporário de colunas
    num_colunas dw 0
    si_num dw  0
    buffer_temp db 6 dup(0) ;espaco para escrever digitos dos numeros das expressoes 
    buffer_temp_num db 7 dup(0) ;numero mais terminador 0
    indice_resultado dw 0
    operando1 dw 0
    operando2 dw 0
    operacao db 0
    expressao_atual db 100 dup(?) ;buffer para gravar cada linha com * e grava-la no result.txt
    handle_resultado dw 0
    arquivo_result_aberto db 0 ;flag se esta aberto o arquivo result
    quebra_linha db 0Dh, 0Ah
    operando1_linha dw 0  ;flag se é linha ou constante 
    operando2_linha dw 0 ;flag se é linha ou constante
    escrever_result dw 0 ;se for * escreve matriz
    separador_coluna db ';'
    
    ; Mensagens de erro
    msg_erro_abertura db 'Erro ao abrir arquivo!', '$'
    msg_erro_leitura  db 'Erro ao ler arquivo!', '$'
    msg_erro_colunas  db 'Erro: Numero de colunas invalido! Somente (1-20)', 0Dh, 0Ah, '$'
    msg_erro_num_colunas  db 'Erro: Numero de colunas diferente do esperado!', 0Dh, 0Ah, '$'
    msg_erro_formato db'Erro: formato de expressao invalido', 0Dh, 0Ah, '$'
    msg_erro_indice  db 'Erro: indice de linha invalido', 0Dh, 0Ah, '$'
    msg_erro_formato_neg db'Erro: indice negativo', 0Dh, 0Ah, '$'
    msg_erro_op db'Erro: operacao invalida', 0Dh, 0Ah, '$'
    msg_div_zero db 'Erro: divisao por zero detectada.', 0Dh, 0Ah, '$'

.CODE
.startup
    ;1. Abrir o arquivo
    mov ah, 3Dh                 ;funcao abrir arquivo
    mov al, 0                   ;modo leitura
    lea dx, filedados
    int 21h
    jnc arquivo_aberto          ;pula se não houve erro (CF=0)
    jmp erro_abertura

arquivo_aberto:
    mov handle, ax
    
    ;2. Ler do arquivo
    mov ah, 3Fh
    mov bx, handle
    mov cx, 10000                ;máximo de bytes a ler
    lea dx, buffer 
    int 21h
    jnc leitura_ok
    jmp erro_leitura

leitura_ok:
    mov bytes_read, ax
    
    ;3. Fechar o arquivo
    mov ah, 3Eh
    mov bx, handle
    int 21h
    
    ;extrair número de colunas (primeira linha)
    call extrair_numero_colunas
    
    ;verificar se número de colunas está entre 1 e 20
    cmp num_colunas, 1
    jb erro_colunas
    cmp num_colunas, 20
    ja erro_colunas
    
    ;processar o restante do buffer (linhas e colunas da matriz)
    call processar_buffer
    
    ;converte matriz string para numeros 
    call converter_para_numeros
    
    mov handle, 0 ;zera handle para usar dnv
    mov bytes_read, 0 ;zera bytes_read para usar dnv 
     
    
    ;1. Abrir o arquivo
    mov ah, 3Dh                 ;funcao abrir arquivo
    mov al, 0                   ;modo leitura
    lea dx, fileexp
    int 21h
    jnc arquivo_abertoo          ;pula se não houve erro (CF=0)
    jmp erro_abertura
    
arquivo_abertoo:
    mov handle, ax
    
    
    ;2. Ler do arquivo
    mov ah, 3Fh
    mov bx, handle
    mov cx, 10000                ;máximo de bytes a ler
    lea dx, buffer_exp 
    int 21h
    jnc leitura_okk
    jmp erro_leitura
    
leitura_okk:
    mov bytes_read, ax
    
    ;3. Fechar o arquivo
    mov ah, 3Eh
    mov bx, handle
    int 21h
    
    call processar_expressoes
    
    ;terminar o programa com sucesso
    .exit

;--------------------------------------------------
;Extrai o número de colunas da primeira linha
;--------------------------------------------------
extrair_numero_colunas proc near

    push ax
    push bx
    push cx
    push si
    
    lea si, buffer       ;começa do início do buffer
    mov bx, 0          ;BX acumulará o número
    mov cx, 0          ;contador de dígitos
    
proximo_digito:
    mov al, [si]
    inc si
    
    ;verifica se é dígito (ASCII '0'-'9')
    cmp al, '0'
    jb fim_numero
    cmp al, '9'
    ja fim_numero
    
    ;converte dígito ASCII para valor
    sub al, '0'
    mov ah, 0
    xchg ax, bx          ;BX = novo dígito, AX = valor acumulado
    mov dx, 10
    mul dx               ;AX *= 10
    add bx, ax           ;BX += novo dígito
    
    inc cx
    jmp proximo_digito
    
fim_numero:
    ;verifica se leu pelo menos 1 dígito
    cmp cx, 0
    je erro_colunas
    
    mov num_colunas, bx
    
    pop si
    pop cx
    pop bx
    pop ax
    ret
    
extrair_numero_colunas endp

;--------------------------------------------------
;Processa o buffer e preenche a matriz
;--------------------------------------------------
processar_buffer proc near

    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    mov linhas, 0     ;zera variaveis
    mov colunas, 0
    mov temp_colunas, 0
    
    lea si, buffer  ;carrega variveis 
    lea di, matriz
    mov cx, bytes_read
    je fim_processar
    
    ;--- Pular a primeira linha (usada apenas para num_colunas) ---
pular_primeira_linha:
    cmp byte ptr [si], 0Dh  ;CR
    je pula_crlf
    cmp byte ptr [si], 0Ah  ;LF direto
    je fim_pular_primeira
    inc si                     ;avanca buffer
    dec cx                     ;decrementa os bytes que ja foram lidos 
    jnz pular_primeira_linha
    jmp fim_processar

pula_crlf:               ;pula se for crlf
    inc si
    dec cx
    jz fim_processar   ;se cx != 0 comparamos com lf, se for igual a zero vai pro fim processar pois nao tem nada no txt

    cmp byte ptr [si], 0Ah
    jne fim_pular_primeira
    inc si             
    dec cx
fim_pular_primeira:
    ; Flag para indicar se estamos em uma linha vazia
    xor bx, bx
;continua agora lendo matriz    
processar_caractere:
    mov al, [si]
    
    ;verifica se é fim de linha
    cmp al, 0Dh
    je trata_cr
    cmp al, 0Ah
    je fim_linha
    
    ;verifica se é separador de coluna
    cmp al, ';'
    je fim_coluna
    
    ;caractere válido - armazena na matriz
    mov [di], al
    inc di
    inc si
    dec cx
    mov bx, 1        ;marca que há dados na linha
    jnz processar_caractere
    jmp ultimo_caractere
    
fim_coluna:
    mov byte ptr [di], 0 ;coloca 0 na string
    inc di
    inc temp_colunas  ;incrementa temp_coluna pois ja foi um novo valor 
    inc si
    dec cx
    jnz processar_caractere
    jmp ultimo_caractere

trata_cr:
    ;termina o último valor da linha com 00
    mov byte ptr [di], 0
    inc di
    
    jz ultimo_caractere

    ;se próximo for LF, pula também
    cmp byte ptr [si], 0Ah
    jne fim_linha
    inc si
    dec cx
    
    jmp fim_linha
    
fim_linha:
    ;só conta como linha se houve dados
    cmp bx, 0
    je nao_compara ;seja o ultimo caracter da linha nao compara, pois a comparacao ja foi feita antes
    
    ;checa se número de colunas está correto
    mov ax, temp_colunas           ;incrementamos o temp_colunas pois tinhamos nele o numero de ";", mas queremos o numero de colunas que é 1 valor a mais 
    inc ax
    cmp num_colunas, ax   ;se nao for igual, mensagem de erro
    jne erro_num_colunas

    inc linhas
    
nao_compara:
    ;prepara para nova linha 
    mov temp_colunas, 0
    xor bx, bx
    
    ;trata CRLF
    inc si
    dec cx
    jz ultimo_caractere     ;se for o ultimo caracter dps dele acabou de preencher a matriz
    
    jmp processar_caractere
    
ultimo_caractere:
    ;só conta como linha se houve dados
    cmp bx, 0
    je fim_processar
    
    mov byte ptr [di], 0 ;coloca zero na string
    inc di
     
    mov ax, temp_colunas ;ve se o numero dessa ultima linha tbm é igual a de num_colunas
    inc ax
    cmp num_colunas, ax
    jne erro_num_colunas
    inc linhas
    
fim_processar:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
processar_buffer endp

;----------------------------------------------------
;CONVERTE A MATRIZ STRING PARA NUMEROS
;----------------------------------------------------
converter_para_numeros proc near

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    lea si, matriz        ;SI aponta para começo das strings
    lea di, matriz_numeros       ;DI aponta para onde vamos gravar os números

    xor cx, cx            ;contador de células convertidas

prox_string:
    ;checa fim da string (00 marca cada valor)
    cmp byte ptr [si], 0
    je  fim_string

    ;BX aponta para string que será convertida
    mov bx, si


 ;checa se é negativo
    mov al, [bx]
    cmp al, '-' ;se for negativo, converte com neg
    jne continua_atoi
    inc bx   ;pula o neg para converter o numero positivo
    mov si_num, 1   ;marca que é nagativo
    jmp chama_atoi
    
continua_atoi:
    mov si_num, 0  ;marca que é positivo

chama_atoi:
    call atoi             ;AX recebe o valor inteiro

    cmp si_num, 0
    je gravarr
    neg ax        ;se for negativo negamos o numero convertido
    
gravarr:                ;grava AX como word na matriz
    mov [di], ax
    add di, 2             ;avança para próxima posição word

    ;pula string original
avanca_si:
    cmp byte ptr [si], 0 ;se for 0 a string terminou
    je terminou_string
    inc si
    jmp avanca_si

terminou_string:
    inc si                ;pula o 00 final
    jmp prox_string

fim_string:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
converter_para_numeros endp


processar_expressoes proc near 

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    lea si, buffer_exp         ;SI aponta para início do buffer
    mov cx, bytes_read ;ve se chegou no fim do arquivo

proxima_expressao:
    cmp cx, 0
    je fim_processar_exp   ;fim do arquivo
    mov escrever_result, 0
    mov expressao_atual, 0
    ;ignora linhas vazias
    cmp byte ptr [si], 0Dh
    jne nao_vazia
    inc si
    dec cx
    cmp cx, 0
    je fim_processar_exp
    
    cmp byte ptr [si], 0Ah
    jne nao_vazia
    inc si
    dec cx
    jmp proxima_expressao
    
 nao_vazia:
    ;verifica se começa com '*'
    mov bl, 0              ;BL = 1 se for escrita no arquivo
    cmp byte ptr [si], '*'
    jne verifica_abre_colchete
    mov bl, 1              ;marcar escrita no arquivo
    mov escrever_result, 1 ;se for escreve matriz
    push bx
    push ax
    
    push cx
    
    
    
    mov bx, si                         ; copia SI para BX, que será usado para ler a linha
    mov di, offset expressao_atual     ; DI aponta para buffer que receberá a linha

copy_linha_expressao:
    mov al, [bx]
    cmp al, 0Dh                    ; fim da linha?
    je fim_copy_expr
    mov [di], al
    inc di
    inc bx
    jmp copy_linha_expressao

fim_copy_expr:
    mov byte ptr [di], 0           ; finaliza a string com 0
    
    ;escreve a expressao no txt
    cmp arquivo_result_aberto,1
    je continuar_ja_aberto
    
    ;CRIA O RESULT.TXT---------   ;cria o arquivo pela primeira vez e deixa aberto ate acabar as impressoes 
    mov ah, 3Ch ;cria o arquivo
    xor cx, cx
    lea dx, fileresult
    int 21h
    jc erro_abertura
    
    mov handle_resultado, ax
    mov arquivo_result_aberto,1
    
continuar_ja_aberto:    ;se ja esta abeto so copia a expressao atual no txt caso tenha *
    ;escreve expressao  
    lea dx, expressao_atual
    push cx
    push bx
    push si
    call strlen             ;chama para contar o tanto que vai escrever 
    mov cx, ax
    mov ah, 40h
    mov bx, handle_resultado
    int 21h
    pop si
    pop bx
    pop cx
    
    ;colocamos o crlf
    lea dx, quebra_linha
    mov cx, 2
    mov ah, 40h
    mov bx, handle_resultado
    int 21h
    
    pop cx
    pop ax
    pop bx
    ;apos gravar a linha da expressao continuamos para gravar os operandos e a operacao 
    inc si     ;avança para '['
    dec cx     ;decrementa cx para indicar que ja foi lido e dps checar se chegou em 0, que significa que terminou de ler o arquivo
    
verifica_abre_colchete:
    cmp byte ptr [si], '[' ;compara de é conchetes
    jne erro_formato ;se nao for ha um erro no formato da expressao
    inc si
    dec cx
    
    lea di, buffer_temp ;DI aponta para onde vai copiar os digitos do indice 
    
copiar_indice:
    mov al, [si]
    cmp al, ']'   ;se for igual chegamos ao fim do numero do indice 
    je fim_indice 
    
    ;validamos o digito 
    cmp al, '0'
    jb erro_formato_neg ; se estiver fora das strings validas, ex '-', entao é erro
    cmp al, '9'
    ja erro_formato_neg
    
   
    
    
    ;copia o caractere para o buffer_temp
    mov [di], al
    inc di
    inc si
    dec cx
    jmp copiar_indice
    
fim_indice:
    mov byte ptr [di], 0 ;termina a string com 0
    inc si   ;avancamos para sair ']'
    dec cx
    
    ;converte atoi
    lea bx, buffer_temp
    push cx  ;salva cx para a leitura do arquivo
    call atoi
    pop cx
    
    cmp ax, linhas 
    jae erro_indice
    
    mov indice_resultado, ax   ;guardamos o indice
    
    ;ler o =
    cmp byte ptr[si], '=' ;vemos se é o caractere =
    jne erro_formato
    inc si ;avancamos 
    dec cx
    
    ;ler operando1
    call ler_op1 ;chamamos a funcao que grava na variavel operando1 o valor em inteiro do operando1, podendo ser constante negativa ou linha 
    
    ;ler operador
    mov al, [si]
    mov operacao, al
    inc si
    dec cx
    
    ;ler operando2
    call ler_op2
    
    ; Validar operador
    mov al, operacao
    cmp al, '+'
    je chama_soma
    cmp al, '-'
    je chama_sub
    cmp al, '*'
    je chama_mul
    cmp al, '/'
    je chama_div
    cmp al, '%'
    je chama_modl
    cmp al, '&'
    je chama_and
    cmp al, '|'
    je chama_or
    cmp al, '^'
    je chama_xor

    jmp erro_op ; operador inválido

    chama_soma: ;chama cada funcao de sua operacao e imprime a matriz modificada
    call soma
    cmp escrever_result, 1
    jne operador_valido
    call imprimir_matriz
    jmp operador_valido

    chama_sub:
    call subtracao
    cmp escrever_result, 1
    jne operador_valido
    call imprimir_matriz
    jmp operador_valido

    chama_mul:
    call multi
    cmp escrever_result, 1
    jne operador_valido
    call imprimir_matriz
    jmp operador_valido

    chama_div:
    call divi
    cmp escrever_result, 1
    jne operador_valido
    call imprimir_matriz
    jmp operador_valido

    chama_modl:
    call modl
    cmp escrever_result, 1
    jne operador_valido
    call imprimir_matriz
    jmp operador_valido

    chama_and:
    call and_operacao
    cmp escrever_result, 1
    jne operador_valido
    call imprimir_matriz
    jmp operador_valido

    chama_or:
    call or_operacao
    cmp escrever_result, 1
    jne operador_valido
    call imprimir_matriz
    jmp operador_valido

    chama_xor:
    call xor_operacao
    cmp escrever_result, 1
    jne operador_valido
    call imprimir_matriz
    jmp operador_valido
    
operador_valido:

pular_fim_linha:
    ; Avança para próxima linha
    cmp byte ptr [si], 0Dh
    jne pula_so_um  ;se so for o cr, pula 1 
    inc si
    dec cx
    cmp cx, 0
    je fim_processar_exp

    ;se tiver LF pula tbm
    cmp byte ptr [si], 0Ah
    jne pula_so_um
    inc si
    dec cx
    jmp proxima_expressao
    
 pula_so_um:
    ;se nao for crlf, so incrementa 1 vez
    inc si
    dec cx
    jmp proxima_expressao
    
fim_processar_exp:

    cmp arquivo_result_aberto, 1
    jne fechar_arquivo_skip
    
    mov bx, handle_resultado
    mov ah, 3Eh      ; função DOS: fechar arquivo
    int 21h
    mov arquivo_result_aberto, 0

fechar_arquivo_skip:

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
processar_expressoes endp

ler_op1 proc near

    push ax
    push bx
    push di

    mov bl, 0        ; flag para número negativo
    mov al, [si]

    cmp al, '[' ;vemos se é referente a uma linha ou se é constante
    jne ler_constante
    mov operando1_linha, 1   ;flag para a soma ser de linha 
    ;avanca 
    inc si
    dec cx

    lea di, buffer_temp ;colocaremos a string do valor de op1 no buffer_temp

ler_op1_ref_loop:
    mov al, [si]
    cmp al, ']' ;ve se va viu todo o numero
    je ler_op1_ref_fim

    cmp al, '0' ;ve se é valor valido, nao por exemplo [-1]
    jb erro_formato_neg
    cmp al, '9'
    ja erro_formato_neg

    mov [di], al
    inc di
    inc si
    dec cx
    jmp ler_op1_ref_loop

ler_op1_ref_fim:
    mov byte ptr [di], 0 ;terminador 0 na string
    inc si
    dec cx

    lea bx, buffer_temp
    push cx
    call atoi            ;AX valor do operando
    pop cx
    
    cmp ax, linhas ;ve se é linha valida 
    jae erro_indice
    
    mov operando1, ax
    
    jmp ler_op1_fim

;============CONSTANTE============
ler_constante:
    mov operando1_linha, 0   ;flag para a soma ser de contante
    ; verifica sinal '-'
    cmp al, '-'
    jne ler_op1_const_loop
    mov bl, 1            ; negativo
    inc si
    dec cx

ler_op1_const_loop:
    lea di, buffer_temp

ler_op1_const_read:
    mov al, [si]
    ;termina ao encontrar operador ou fim linha
    cmp al, 0
    je ler_op1_const_fim ;compara para ver se é valido o caracter
    cmp al, 0Dh
    je ler_op1_const_fim
    cmp al, 0Ah
    je ler_op1_const_fim
    cmp al, '+'
    je ler_op1_const_fim
    cmp al, '-'
    je ler_op1_const_fim
    cmp al, '*'
    je ler_op1_const_fim
    cmp al, '/'
    je ler_op1_const_fim
    cmp al, '%'
    je ler_op1_const_fim
    cmp al, '&'
    je ler_op1_const_fim
    cmp al, '|'
    je ler_op1_const_fim
    cmp al, '^'
    je ler_op1_const_fim

    cmp al, '0'
    jb erro_formato
    cmp al, '9'
    ja erro_formato

    mov [di], al ;move constante pro di
    inc di
    inc si
    dec cx
    jmp ler_op1_const_read

ler_op1_const_fim:
    mov byte ptr [di], 0
    push bx ;precisamos da flag se é positivo ou negativo, por isso push e pop bx
    lea bx, buffer_temp ;converte o valor
    push cx
    call atoi
    pop cx

    pop bx
    cmp bl, 0
    je ler_op1_const_salvar
    neg ax

ler_op1_const_salvar:
    mov operando1, ax

ler_op1_fim:
    pop di
    pop bx
    pop ax
    ret
    
ler_op1 endp

ler_op2 proc near

    push ax
    push bx
    push di

    mov bl, 0        ; flag para número negativo
    mov al, [si]

    cmp al, '['
    jne ler_op2_constante
    mov operando2_linha, 1 ;flag para a soma ser de linha

    ;se nao for constante é linha 
    inc si
    dec cx

    lea di, buffer_temp

ler_op2_ref_loop:          ;mesma logica op1, so que sem comparar com o prox byte ser de alguma operacao 
    mov al, [si]
    cmp al, ']'
    je ler_op2_ref_fim

    cmp al, '0'
    jb erro_formato_neg
    cmp al, '9'
    ja erro_formato_neg

    mov [di], al
    inc di
    inc si
    dec cx
    jmp ler_op2_ref_loop

ler_op2_ref_fim:
    mov byte ptr [di], 0
    inc si
    dec cx

    lea bx, buffer_temp
    push cx
    call atoi
    pop cx

    cmp ax, linhas
    jae erro_indice

    mov operando2, ax
    jmp ler_op2_fim

;====================CONSTANTE=====================
ler_op2_constante:
    mov operando2_linha, 0   ;flag para a soma ser de constante
    cmp al, '-'
    jne ler_op2_const_loop
    mov bl, 1        ; valor negativo
    inc si
    dec cx

ler_op2_const_loop:
    lea di, buffer_temp

ler_op2_const_read:
    mov al, [si]

    cmp al, 0Dh
    je ler_op2_const_fim
    cmp al, 0Ah
    je ler_op2_const_fim

    cmp al, '0'
    jb erro_formato
    cmp al, '9'
    ja erro_formato

    mov [di], al
    inc di
    inc si
    dec cx
    jmp ler_op2_const_read

ler_op2_const_fim:
    mov byte ptr [di], 0
    push bx
    lea bx, buffer_temp
    push cx
    call atoi
    pop cx

    pop bx
    cmp bl, 0
    je salvar_op2
    neg ax

salvar_op2:
    mov operando2, ax

ler_op2_fim:
    pop di
    pop bx
    pop ax
    ret
    
ler_op2 endp
    
;-----------------------------------
;ATOI DO MOODLE
;-----------------------------------
atoi	proc near

		; A = 0;
		mov		ax,0
		
atoi_2:
		; while (*S!='\0') {
		cmp		byte ptr[bx], 0
		jz	atoi_1

		; 	A = 10 * A
		mov		cx,10
		mul		cx

		; 	A = A + *S
		mov		ch,0
		mov		cl,[bx]
		add		ax,cx

		; 	A = A - '0'
		sub		ax,'0'

		; 	++S
		inc		bx
		
		;}
		jmp		atoi_2

atoi_1:
		; return
        ret

atoi	endp

itoa proc near

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, di        ;salva início do buffer
    mov bx, 10        ;divisor
    xor cx, cx        ;contador
    xor dx, dx

    cmp ax, 0
    jge positivo

    ;negativo  salva '-' no início
    mov byte ptr [di], '-'
    inc di
    neg ax

positivo:
    ;converter AX em string (números invertidos)
conv_loop:
    xor dx, dx
    div bx           ;AX / 10  AX = quociente, DX = resto
    add dl, '0'
    push dx
    inc cx
    cmp ax, 0
    jne conv_loop

    ;escreve os caracteres armazenados na pilha
grava_loop:
    pop dx
    mov [di], dl
    inc di
    loop grava_loop

    ;coloca terminador zero
    mov byte ptr [di], 0

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
itoa endp


strlen proc near ;conta quanto eu tenho que escrever
   
   push di
    push cx
    xor ax, ax
    mov di, dx
proximo_char:
    cmp byte ptr [di], 0
    je fim_strlen
    inc di
    inc ax
    jmp proximo_char
fim_strlen:
    pop cx
    pop di
    ret
    
strlen endp



soma proc near

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ;preparar endereço da linha de destino
    mov ax, indice_resultado
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea di, matriz_numeros
    add di, ax

    ;preparar SI com linha 1
    cmp operando1_linha, 1
    jne op1_const  ;se for constante, trata como constante 
    mov ax, operando1
    mov cx, [num_colunas]
    mov bx, cx
    mul bx        ;AX = indice * colunas
    shl ax, 1
    lea si, matriz_numeros
    add si, ax    ;SI = endereco linha op1
    jmp op2_prep
    
op1_const:
    mov si, -1   ;se for conatnte flag de constante

op2_prep:   ;mesma logica pro op2
    cmp operando2_linha, 1
    jne op2_const
    mov ax, operando2
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea bx, matriz_numeros
    add bx, ax
    jmp soma_exec
    
op2_const:
    mov bx, -1

;quantas vezes faz soma na matriz
soma_exec:
    mov cx, [num_colunas]

soma_loop:
    cmp si, -1
    je op1_is_const
    mov ax, [si]   ;se SI for diferente de -1 AX = elemento linha 1 
    jmp op1_done
    
op1_is_const:
    mov ax, operando1   ;se SI = -1, AX = valor constante operando1
    
op1_done:
    cmp bx, -1
    je op2_is_const
    add ax, [bx]        ;soma com valor da linha op2
    jmp store
    
op2_is_const:       ;soma com constante op2
    add ax, operando2

store:
    mov [di], ax   ;coloca resultado na linha destino
    add di, 2

    cmp si, -1
    je skip_si
    add si, 2  ;se op1 for linha, avança para prox valor
    
skip_si:
    cmp bx, -1
    je skip_bx
    add bx, 2  ;se op2 for linha avança tbm
    
skip_bx:
    loop soma_loop  ;repete para todas as colunas

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
soma endp

subtracao proc near

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ;preparar endereço da linha de destino
    mov ax, indice_resultado ;onde vai ficar o resultado
    mov cx, [num_colunas]   ;cx = num colunas matriz
    mov bx, cx
    mul bx       ;posicao da linha da matriz
    shl ax, 1          ;multiplica por 2 (pois cada num tem 2 bytes)
    lea di, matriz_numeros
    add di, ax    ;inicio destino

    ;preparar SI com linha 1 (operando1)
    cmp operando1_linha, 1     ;verifica se é linha, se nao é constante
    jne op1_const_sub          
    mov ax, operando1
    mov cx, [num_colunas]
    mov bx, cx
    mul bx                    ;op1 * colunas
    shl ax, 1
    lea si, matriz_numeros          ;SI = base da matriz
    add si, ax
    jmp op2_prep_sub
    
op1_const_sub:
    mov si, -1

op2_prep_sub:           ;mesma logica op2
    cmp operando2_linha, 1
    jne op2_const_sub
    mov ax, operando2
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea bx, matriz_numeros
    add bx, ax
    jmp sub_exec
    
op2_const_sub:
    mov bx, -1

;quantas vezes faz sub na matriz
sub_exec:
    mov cx, [num_colunas]  ;número de colunas

sub_loop:                    ;verifica constante
    cmp si, -1
    je op1_is_const_sub
    mov ax, [si]
    jmp op1_done_sub
    
op1_is_const_sub:
    mov ax, operando1
    
op1_done_sub:
    cmp bx, -1
    je op2_is_const_sub
    sub ax, [bx]       ;subtrai
    jmp store_sub
    
op2_is_const_sub:
    sub ax, operando2

store_sub:
    mov [di], ax
    add di, 2      ;prox valor destino

    cmp si, -1
    je skip_si_sub
    add si, 2      ;prox valor op1
    
skip_si_sub:
    cmp bx, -1
    je skip_bx_sub
    add bx, 2    ;prox valor op2
    
skip_bx_sub:
    loop sub_loop      ;repete ate todas as colunas serem feitas

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
subtracao endp

multi proc near

    push ax
    push bx
    push cx
    push dx
    push si
    push di


    mov ax, indice_resultado        ;AX = índice da linha armazenando o resultado
    mov cx, [num_colunas]
    mov bx, cx
    mul bx                          ;AX = índice * colunas
    shl ax, 1                       ;converte para bytes (2 por número)
    lea di, matriz_numeros
    add di, ax                      ;DI aponta para o início da linha destino

  
    cmp operando1_linha, 1
    jne op1_const_mul               ;se não for linha, é constante
    mov ax, operando1
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea si, matriz_numeros
    add si, ax                      ; SI aponta para a linha do operando1
    jmp op2_prep_mul

op1_const_mul:
    mov si, -1                      ;flag: operando1 é constante


op2_prep_mul:
    cmp operando2_linha, 1
    jne op2_const_mul
    mov ax, operando2
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea bx, matriz_numeros
    add bx, ax                      ;BX aponta para a linha do operando2
    jmp mul_exec

op2_const_mul:
    mov bx, -1                      ;flag: operando2 é constante

;quantas vezes faz mul na matriz
mul_exec:
    mov cx, [num_colunas]           ;contador de colunas

mul_loop:
    ;carrega operando1
    cmp si, -1
    je op1_is_const_mul
    mov ax, [si]                    ;valor da linha op1
    jmp op1_done_mul
    
op1_is_const_mul:
    mov ax, operando1   ;valor constante op1

op1_done_mul:
    cmp bx, -1
    je op2_is_const_mul
    mov dx, [bx]
    imul dx                  ;*= valor da linha op2
    jmp store_mul
op2_is_const_mul:
    mov dx, operando2
    imul dx              ;*= constante op2

store_mul:
    mov [di], ax                   
    add di, 2   ;prox valor destino

    cmp si, -1
    je skip_si_mul
    add si, 2  ;prox valor op1
    
skip_si_mul:
    cmp bx, -1
    je skip_bx_mul
    add bx, 2        ;prox valor op2
    
skip_bx_mul:
    loop mul_loop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
multi endp

divi proc near
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ;endereço de destino
    mov ax, indice_resultado
    mov cx, [num_colunas]
    mul cx
    shl ax, 1
    lea di, matriz_numeros
    add di, ax

    ;prepara SI (operando1)
    cmp operando1_linha, 1   
    jne op1_const_div
    mov ax, operando1
    mov cx, [num_colunas]
    mul cx
    shl ax, 1
    lea si, matriz_numeros
    add si, ax
    jmp prepara_op2_div
    
op1_const_div:
    mov si, -1

prepara_op2_div:
    ;prepara BX (operando2)
    cmp operando2_linha, 1
    jne op2_const_div
    ;caso matriz calcula ponteiro inicial
    mov ax, operando2
    mov cx, [num_colunas]
    mul cx
    shl ax, 1
    lea bx, matriz_numeros
    add bx, ax
    push bx             ;guarda ponteiro original
    mov bx, [bx]        ;carrega primeiro valor
    jmp exec_div
    
op2_const_div:
    ;caso constante: carrega valor diretamente
    mov bx, operando2
    jmp exec_div

;quantas vezes faz div na matriz
exec_div:
    mov cx, [num_colunas]

div_loop:
    ;operando1 em AX
    cmp si, -1
    je usa_op1_const_div
    mov ax, [si]
    jmp op1_ok_div
usa_op1_const_div:
    mov ax, operando1
    
op1_ok_div:
    cwd                 ;estende sinal 

    ;já temos operando2 em BX (constante ou valor da matriz)
    cmp bx, 0
    jne faz_div
    
    ;tratamento de divisão por zero
    mov dx, offset msg_div_zero
    mov ah, 9
    int 21h
    mov ax, 4C01h
    int 21h

faz_div:
    idiv bx             ;DX:AX / BX  AX=quociente, DX=resto
    mov [di], ax        ;armazena resultado
    add di, 2           ;avança ponteiro de resultado

    ;avança SI se for matriz
    cmp operando1_linha, 1
    jne skip_si_div
    add si, 2
skip_si_div:

    ;avança BX se for matriz
    cmp operando2_linha, 1
    jne skip_bx_div
    pop bx              ;recupera ponteiro
    add bx, 2           ;avança
    push bx             ;guarda novamente
    mov bx, [bx]        ;carrega próximo valor
skip_bx_div:

    loop div_loop

    ;limpeza final se operando2 era matriz
    cmp operando2_linha, 1
    jne fim_div
    pop bx              ;remove ponteiro da pilha
fim_div:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
divi endp


modl proc near
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ;endereço de destino
    mov ax, indice_resultado
    mov cx, [num_colunas]
    mul cx
    shl ax, 1
    lea di, matriz_numeros
    add di, ax

    ;prepara SI (operando1)
    cmp operando1_linha, 1   
    jne op1_const_modl
    mov ax, operando1
    mov cx, [num_colunas]
    mul cx
    shl ax, 1
    lea si, matriz_numeros
    add si, ax
    jmp prepara_op2_modl
    
op1_const_modl:
    mov si, -1

prepara_op2_modl:
    cmp operando2_linha, 1
    jne op2_const_modl
    ;caso matriz
    mov ax, operando2
    mov cx, [num_colunas]
    mul cx
    shl ax, 1
    lea bx, matriz_numeros
    add bx, ax
    push bx             ;guarda ponteiro original
    mov bx, [bx]        ;carrega primeiro valor
    jmp exec_modl
    
op2_const_modl:
    ;caso constante
    mov bx, operando2
    ;não precisa push/pop adicional para constantes
    jmp exec_modl

;quantas vezes faz mod na matriz
exec_modl:
    mov cx, [num_colunas]

modl_loop:
    ;operando1 em AX
    cmp si, -1
    je usa_op1_const_modl
    mov ax, [si]
    jmp op1_ok_modl
usa_op1_const_modl:
    mov ax, operando1
    
op1_ok_modl:
    cwd                 ;estende sinal para DX:AX

    cmp bx, 0
    jne faz_modl
    
    ;tratamento de divisão por zero
    mov dx, offset msg_div_zero
    mov ah, 9
    int 21h
    mov ax, 4C01h
    int 21h

faz_modl:
    idiv bx             ;DX:AX / BX DX=resto
    mov [di], dx        ;armazena o resto
    add di, 2

    ;avança SI se for matriz
    cmp operando1_linha, 1
    jne skip_si_modl
    add si, 2
skip_si_modl:

    ;avança BX se for matriz
    cmp operando2_linha, 1
    jne skip_bx_modl
    pop bx              ;recupera ponteiro
    add bx, 2           ;avança (2 pq é word)
    push bx             ;guarda novamente
    mov bx, [bx]        ;carrega próximo valor
skip_bx_modl:

    loop modl_loop

    ;limpeza final só se operando2 era matriz
    cmp operando2_linha, 1
    jne fim_modl
    pop bx              ;remove ponteiro da pilha
fim_modl:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
modl endp

and_operacao proc near

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ;endereço de destino (linha resultado)
    mov ax, indice_resultado
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea di, matriz_numeros
    add di, ax

    ;prepara SI (operando1)
    cmp operando1_linha, 1
    jne op1_const_and
    mov ax, operando1
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea si, matriz_numeros
    add si, ax
    jmp prepara_op2_and

op1_const_and:
    mov si, -1

;prepara BX (operando2)
prepara_op2_and:
    cmp operando2_linha, 1
    jne op2_const_and
    mov ax, operando2
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea bx, matriz_numeros
    add bx, ax
    jmp exec_and

op2_const_and:
    mov bx, -1

;qunatas vezes faz and na  matriz
exec_and:
    mov cx, [num_colunas]

and_loop:
    ;operando1 em AX
    cmp si, -1
    je usa_op1_const_and
    mov ax, [si]
    jmp op1_ok_and
    
usa_op1_const_and:
    mov ax, operando1
    
op1_ok_and:
    ;operando2 em DX
    cmp bx, -1
    je usa_op2_const_and
    mov dx, [bx]
    jmp faz_and
    
usa_op2_const_and:
    mov dx, operando2

faz_and:
    and ax, dx      ;faz o and 
    mov [di], ax    ;guarda resultado
    add di, 2

    cmp si, -1
    je skip_si_and
    add si, 2
    
skip_si_and:
    cmp bx, -1
    je skip_bx_and
    add bx, 2
    
skip_bx_and:
    loop and_loop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
and_operacao endp

or_operacao proc near

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ;endereço de destino (linha resultado)
    mov ax, indice_resultado
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea di, matriz_numeros
    add di, ax

    ;prepara SI (operando1)
    cmp operando1_linha, 1
    jne op1_const_or
    mov ax, operando1
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea si, matriz_numeros
    add si, ax
    jmp prepara_op2_or

op1_const_or:
    mov si, -1

;prepara BX (operando2)
prepara_op2_or:
    cmp operando2_linha, 1
    jne op2_const_or
    mov ax, operando2
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea bx, matriz_numeros
    add bx, ax
    jmp exec_or

op2_const_or:
    mov bx, -1

;quantas vezes faz or na matriz
exec_or:
    mov cx, [num_colunas]

or_loop:
    ;operando1 em AX
    cmp si, -1
    je usa_op1_const_or
    mov ax, [si]
    jmp op1_ok_or
    
usa_op1_const_or:
    mov ax, operando1
    
op1_ok_or:
    ;operando2 em DX
    cmp bx, -1
    je usa_op2_const_or
    mov dx, [bx]
    jmp faz_or
    
usa_op2_const_or:
    mov dx, operando2

faz_or:
    or ax, dx      ;aqui o or é feito
    mov [di], ax    ;guarda resultado
    add di, 2

    cmp si, -1
    je skip_si_or
    add si, 2
    
skip_si_or:
    cmp bx, -1
    je skip_bx_or
    add bx, 2
    
skip_bx_or:
    loop or_loop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
or_operacao endp

xor_operacao proc near
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ;endereço de destino (linha resultado)
    mov ax, indice_resultado
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea di, matriz_numeros
    add di, ax

    ;prepara SI (operando1)
    cmp operando1_linha, 1
    jne op1_const_xor
    mov ax, operando1
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea si, matriz_numeros
    add si, ax
    jmp prepara_op2_xor

op1_const_xor:
    mov si, -1

;prepara BX (operando2)
prepara_op2_xor:
    cmp operando2_linha, 1
    jne op2_const_xor
    mov ax, operando2
    mov cx, [num_colunas]
    mov bx, cx
    mul bx
    shl ax, 1
    lea bx, matriz_numeros
    add bx, ax
    jmp exec_xor
    
;flag constante
op2_const_xor:
    mov bx, -1
    
;quantas vezes faz o xor na matriz
exec_xor:
    mov cx, [num_colunas]

xor_loop:
    ;operando1 em AX
    cmp si, -1
    je usa_op1_const_xor
    mov ax, [si]
    jmp op1_ok_xor
usa_op1_const_xor:
    mov ax, operando1
op1_ok_xor:

    ;operando2 em DX
    cmp bx, -1
    je usa_op2_const_xor
    mov dx, [bx]
    jmp faz_xor
usa_op2_const_xor:
    mov dx, operando2

faz_xor:
    xor ax, dx      ;faz o xor
    mov [di], ax    ;guarda resultado
    add di, 2

    cmp si, -1
    je skip_si_xor
    add si, 2
skip_si_xor:

    cmp bx, -1
    je skip_bx_xor
    add bx, 2
skip_bx_xor:

    loop xor_loop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
xor_operacao endp

imprimir_matriz proc near

    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ;verifica se o arquivo está aberto
    cmp arquivo_result_aberto, 1
    jne fim_imprimir_matriz

    mov cx, linhas           ;número de linhas
    lea si, matriz_numeros   ;SI aponta para matriz
    xor di, di               ;DI será contador de linhas

linha_loop:
    push cx
    push di

    mov cx, num_colunas      ;número de colunas
    xor bx, bx               ;BX será contador de colunas

coluna_loop:
    push cx

    mov ax, [si]
    lea di, buffer_temp_num
    call itoa

    lea dx, buffer_temp_num
    call strlen
    mov cx, ax
    push bx
    mov ah, 40h           ;escrevo o numero
    mov bx, handle_resultado
    int 21h
    pop bx
    
    ;se não for a última coluna, imprime ;
    mov ax, num_colunas
    dec ax
    cmp bx, ax
    je proxima_coluna  ;caso ja esteja na ultima coluna nao imprime o ;
    push bx
    mov ah, 40h
    mov bx, handle_resultado
    lea dx, separador_coluna
    mov cx, 1
    int 21h
    pop bx

proxima_coluna:
    add si, 2 ;anda para o prox numero da matriz (2 bytes)
    inc bx
    pop cx
    loop coluna_loop

    ;escreve quebra de linha
    lea dx, quebra_linha
    mov cx, 2
    mov ah, 40h
    mov bx, handle_resultado
    int 21h

    pop di
    pop cx
    inc di
    loop linha_loop

fim_imprimir_matriz:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

imprimir_matriz endp



;Tratamento de erros
erro_op:
    mov ah, 09h
    lea dx, msg_erro_op
    int 21h
    mov ax, 4C01h        ;termina com código de erro
    int 21h
    jmp fim_programa
    
erro_formato_neg:
    mov ah, 09h
    lea dx, msg_erro_formato_neg
    int 21h
    mov ax, 4C01h        ;termina com código de erro
    int 21h
    jmp fim_programa
    
erro_indice:
    mov ah, 09h
    lea dx, msg_erro_indice
    int 21h
    mov ax, 4C01h        ;termina com código de erro
    int 21h
    jmp fim_programa

erro_formato:
    mov ah, 09h
    lea dx, msg_erro_formato
    int 21h
    mov ax, 4C01h        ;termina com código de erro
    int 21h
    jmp fim_programa

erro_num_colunas:          ;se as colunas estiverem erradas da erro
    mov ah, 09h
    lea dx, msg_erro_num_colunas
    int 21h
    mov ax, 4C01h        ;termina com código de erro
    int 21h
    jmp fim_programa

erro_colunas:          ;se o valor de colunas for dofiferente de 1-20
    mov ah, 09h
    lea dx, msg_erro_colunas
    int 21h
    mov ax, 4C01h        ;termina com código de erro
    int 21h
    jmp fim_programa


erro_abertura:          ;se tiver erro ao abrir o txt
    mov ah, 09h
    lea dx, msg_erro_abertura
    int 21h
    jmp fim_programa

erro_leitura:                 ;erro ao ler o txt
    mov ah, 3Eh
    mov bx, handle
    int 21h
    
    mov ah, 09h
    lea dx, msg_erro_leitura
    int 21h

fim_programa:
    mov ax, 4C01h      ;termina programa caso erro
    int 21h

end