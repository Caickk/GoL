# Descrição do algoritmo

# Detalhes de compilação para cada um dos métodos utilizados

Para atender aos requisitos do trabalho e garantir a correta medição pelas diferentes ferramentas de profiling, foram utilizados dois métodos distintos de compilação.

## Compilação Base (time, perf, Valgrind e strace)
Para a execução padrão e análise com ferramentas que leem eventos do sistema ou de hardware (`/usr/bin/time`, `perf`, `Valgrind`, `strace`), o código deve ser compilado via terminal com otimização desativada e inclusão de símbolos de depuração.

* **Comando utilizado:** 
  `gcc -O0 -g -o gol gol.c`

* **Detalhes das flags:**
  * `-O0`: Desativa as otimizações do compilador. Isso é obrigatório para garantir que o tempo de execução alcance pelo menos 2 segundos (wall-clock time) com um volume de dados suficiente, sem que o compilador altere a estrutura serial do código.
  * `-g`: Adiciona símbolos de debug, permitindo que ferramentas como o *perf* e o *Valgrind* consigam mapear as instruções de máquina de volta para as linhas exatas do código-fonte em C.
  * `-o gol`: Define o nome do arquivo executável gerado.

## Compilação para Profiling com gprof
O `gprof` exige uma compilação específica com instrumentação de código para conseguir rastrear o grafo de chamadas (call graph) e os tempos de execução internos das funções (flat profile).

* **Comando utilizado:** 
  `gcc -pg -O0 -g -o gol gol.c`

* **Detalhes da flag adicional:**
  * `-pg`: Habilita o suporte a perfilamento. O compilador insere um código extra no executável que registra as informações de tempo e contagem de chamadas de cada função executada, gerando o arquivo `gmon.out` necessário para a leitura do `gprof`.
  
# Execução e Parâmetros de Linha de Comando

O código fonte foi estruturado para receber quatro parâmetros numéricos via linha de comando: a largura da placa, a altura da placa, o número máximo de iterações e a frequência de salvamento das iterações (parâmetro XX). 

O formato de execução padrão segue a estrutura:
`./gol [largura] [altura] [max_iter] [print_freq]`

* **Exemplo de execução:** `./gol 1000 1000 500 50`

Para satisfazer os critérios do experimento, os parâmetros de entrada (dimensões da matriz e número de iterações) devem ser grandes o suficiente para que o programa processe um volume de dados adequado, garantindo que o tempo de execução alcance pelo menos 2 segundos em *wall-clock time* utilizando a compilação base.

Durante a coleta de métricas, a execução do binário foi encapsulada pelas ferramentas de profiling exigidas. Utilizando o exemplo de parâmetros acima, os comandos executados foram:

* **Medição de tempo total e recursos:** `/usr/bin/time ./gol 1000 1000 500 50`
* **Contagem de eventos de hardware:** `perf stat ./gol 1000 1000 500 50`
* **Gravação do overhead por função:** `perf record -g ./gol 1000 1000 500 50`
* **Simulação de instruções de CPU:** `valgrind --tool=callgrind ./gol 1000 1000 500 50`
* **Simulação de acessos e misses de memória L1/L2:** `valgrind --tool=cachegrind ./gol 1000 1000 500 50`
* **Rastreamento de chamadas de sistema:** `strace -c ./gol 1000 1000 500 50`
# Tabelas de resultados do time, gprof, perf, Valgrind e strace

# Análise crítica sobre qual ferramenta foi mais útil para o diagnóstico
## Código de referencia: https://rosettacode.org/wiki/Conway%27s_Game_of_Life
