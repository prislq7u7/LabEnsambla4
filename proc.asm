section .data

section .text
global proc

%macro procesar_bloque 4
    ;suma brillo con saturación
    vpaddusb %1, %1, %2 ; %1 = píxeles + brillo 
    
    ;compara con umbral
    vpcmpgtb %1, %1, %3 ;%1 = 0xFF si > umbral, 0 si no
    
    ;guarda resultado en salida
    vmovdqu [%4], %1
%endmacro

%macro cargar_parametros_simd 4
    ;carga brillo 
    movd xmm0, %3 ;xmm0 = [0,0,0,brightness]
    vpbroadcastb %1, xmm0 ;%1 = 32 veces brightness
    
    ;carga umbral
    movd xmm0, %4 ;xmm0 = [0,0,0,threshold]
    vpbroadcastb %2, xmm0 ;%2 = 32 veces threshold
%endmacro

proc:
    ;prólogo
    push rbp
    mov rbp, rsp
    push rbx
    
    ;usa vzeroupper para evitar mezclar AVX con SSE
    vzeroupper
    
    ;guarda parámetros 
    mov rbx, rdi ;rbx = input
    mov rcx, rsi ;rcx = output
    mov rdx, rdx ;rdx = pixel_count
    movzx rsi, cl ;rsi = brightness (extendido a 64 bits)
    movzx r8, r8b ;r8 = threshold (extendido a 64 bits)
    
    ;carga parámetros SIMD usando macro
    cargar_parametros_simd ymm1, ymm2, esi, r8d ;ymm1 = brightness, ymm2 = threshold
    
    ;procesa bloques de 32 píxeles
    mov rax, 0 contador de bloques procesados
    
.procesar_bloque:
    ;verifica si quedan al menos 32 píxeles
    cmp rdx, 32
    jb .procesar_resto
    
    ;carga 32 píxeles
    vmovdqu ymm0, [rbx] ;ymm0 = 32 bytes de la imagen
    
    ;procesa loque usando macro
    procesar_bloque ymm0, ymm1, ymm2, rcx
    
    ;avanza punteros
    add rbx, 32
    add rcx, 32
    sub rdx, 32
    jmp .procesar_bloque
    
.procesar_resto:
    ;procesa píxeles restantes sin SIMD
    cmp rdx, 0
    je .fin
    
.procesar_byte:
    ;carga un píxel
    movzx rax, byte [rbx]
    
    ;suma brillo con saturación
    add al, sil
    cmp al, 255
    jbe .no_saturar
    mov al, 255
.no_saturar:
    
    ;umbralización
    cmp al, r8b
    jle .menor_igual
    mov al, 255
    jmp .guardar
.menor_igual:
    mov al, 0
.guardar:
    
    ;guarda resultado
    mov [rcx], al
    
    ;avanza
    inc rbx
    inc rcx
    dec rdx
    jnz .procesar_byte
    
.fin:
    vzeroupper
    pop rbx 
    pop rbp
    ret