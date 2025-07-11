# leituradematriz
Programa feito em assembly MASM
Este programa lê um txt, com o nome "DADOS.TXT", que contém uma matriz escrita na primeira linha o número de colunas (mínimo 1 e máximo 20) e a matriz em si, em que é separado cada coluna po ";". Em outro txt, com o nome "EXP.TXT", temos várias expressões que serão feitas com base na matriz, números com colchetes "[]" significam a linha da matriz e números sem colchetes significam contantes. Depois de executado o programa, é gerado um txt, chamado "RESULT.TXT", esse txt contém cada expressão que tinha no EXP com "*" e logo abaixo a matriz modificada.

exemplo de dados.txt:
3
1;2;3
2;3;4
3;4;5
5;6;7


exemplo de exp.txt:
[0]=[1]+[2]            ;a linha 1 será somada da linha 2 e colocada na linha 0
[2]=1-[3]              ;a contante 1 será diminuida da linha 3 e colocada na linha 2


será também anexado exemplos de txts
