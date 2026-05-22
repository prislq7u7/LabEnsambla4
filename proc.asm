section .data

section .text
global proc

;procesa un bloque de 32 pixeles
%macro procesar_bloque 4
    ;suma brillo con saturacion
    vpaddusb %1, %1, %2 ; 
    vpmaxub %1, %1, %3 ;%1 = max(pixel, umbral)
    vpcmpeqb %1, %1, %3 ;pixel == umbral
    vpandn %1, %1, [rel masc] ;invierte pixel > umbral

    ;guarda resultado en salida
    vmovdqu [%4], %1
%endmacro

;carga brightness y threshold 
%macro load_parametros 4
    ;loads brillo
    vmovd xmm0, %3 
    vpbroadcastb %1, xmm0 

    ;loads umbral
    vmovd xmm0, %4 
    vpbroadcastb %2, xmm0 
%endmacro

section .data
    masc: times 32 db 0xFF

section .text

proc:
    ;prólogo
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14

    ;guarda parámetros
    mov rbx, rdi ;input
    mov r12, rsi ;output
    mov r13, rdx ;pixel_count
    movzx r14d, cl;brightness sin signo
    movzx r9d, r8b ;threshold sin signo

    vzeroupper
    load_parametros ymm1, ymm2, r14d, r9d 

.procesar_bloque:
    ;verifica si quedan al menos 32 pixel es
    cmp r13, 32
    jb .procesar_resto

    ;carga 32 pixel es de la imagen de entrada
    vmovdqu ymm0, [rbx]

    ;procesa el bloque usando macro
    procesar_bloque ymm0, ymm1, ymm2, r12

    ;avanza punteros
    add rbx, 32
    add r12, 32
    sub r13, 32
    jmp .procesar_bloque

.procesar_resto:
    ;procesa pixeles restantes uno por uno 
    cmp r13, 0
    je .fin

.procesar_byte:
    ;carga un pixel 
    movzx rax, byte [rbx]

    ;suma brillo con saturación
    add al, r14b ;brightness
    jnc .no_saturar ;si no hubo carry, no satura
    mov al, 255
.no_saturar:

    ;comparación sin signo con ja
    cmp al, r9b ;compara pixel con umbral
    ja .mayor ;pixel > umbral
    mov al, 0
    jmp .guardar
.mayor:
    mov al, 255

.guardar:
    mov [r12], al

    ;avanza punteros
    inc rbx
    inc r12
    dec r13
    jnz .procesar_byte

.fin:
    vzeroupper
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret