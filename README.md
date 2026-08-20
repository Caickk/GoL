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

* **Medição de tempo total e recursos:** `/usr/bin/time -v ./gol 1000 1000 500 50`
* **Contagem de eventos de hardware:** `perf stat ./gol 1000 1000 500 50`
* **Gravação do overhead por função:** `perf record -g ./gol 1000 1000 500 50`
* **Simulação de instruções de CPU:** `valgrind --tool=callgrind ./gol 1000 1000 500 50`
* **Simulação de acessos e misses de memória L1/L2:** `valgrind --tool=cachegrind ./gol 1000 1000 500 50`
* **Rastreamento de chamadas de sistema:** `strace -c ./gol 1000 1000 500 50`
  
# Tabelas de resultados do time, gprof, perf, Valgrind e strace

Abaixo estão os resultados extraídos de cada ferramenta de profiling em dois ambientes de hardware distintos, seguindo os parâmetros definidos na especificação do projeto.

## Especificações dos Ambientes de Teste

**Ambiente 1 (CPU 1)**
* **Processador (CPU):** AMD Ryzen 5 7520U (4 Núcleos / 8 Threads)
* **Memória Cache:** L1: 128 KiB / L2: 2 MiB / L3: 4 MiB
* **Memória RAM:** 16 GB (2x 8GB) LPDDR5 Samsung @ 5500 MT/s (Dual-Channel)
* **Sistema Operacional:** Ubuntu 26
* **Kernel Linux:** 7.0.0-27-generic

**Ambiente 2 (CPU 2)**
* **Processador (CPU):** Intel® Core™ i5-1135G7 (4 Núcleos / 8 Threads)
* **Memória Cache:** L1: 320 / L2: 5MB / L3: 8MB 
* **Memória RAM:** 12 GB DDR4
* **Sistema Operacional:** Ubuntu 26.04 
* **Kernel Linux:** 7.0.0-29-generic

## 1. Medição de Tempo (`/usr/bin/time`)
| Métrica | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| Wall-clock time | 1:04.45 (64.45 s) | |
| User time | 64.42 s | |
| System time | 0.01 s | |
| Maximum RSS (uso de memória) | 9528 KB | |
| Page faults | 2035 (Minor)| |
| Context switches | 696 (3 vol / 693 invol) | |

## 2. Profiling com `gprof`
| Métrica | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| Função hotspot (maior self time) | `evolve` | |
| Tempo gasto na função hotspot (Self time) | 64.45 s | |
| Percentual de impacto no tempo total | 100.00% | |

## 3. Profiling de Hardware (`perf stat`)
| Métrica | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| Cycles | | |
| Instructions | | |
| IPC (Instruções por Ciclo) | | |
| Cache-references | | |
| Cache-misses | | |
| Branches | | |
| Branch-misses | | |
| L1-dcache-load-misses | | |
| LLC-load-misses | | |

## 4. Profiling com Valgrind (Callgrind e Cachegrind)
| Métrica | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| Número exato de instruções (Callgrind) | | |
| Chamadas por função (Callgrind) | | |
| Acessos de memória L1 e L2 (Cachegrind) | | |
| Misses de memória L1 e L2 (Cachegrind) | | |

## 5. Rastreamento com `strace`
| Métrica | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| 1ª Syscall mais frequente | | |
| 2ª Syscall mais frequente | | |
| 3ª Syscall mais frequente | | |
| Tempo total despendido em modo kernel | | |
# Diagnóstico e análise crítica sobre qual ferramenta foi mais útil para o diagnóstico
## Código de referencia: https://rosettacode.org/wiki/Conway%27s_Game_of_Life
