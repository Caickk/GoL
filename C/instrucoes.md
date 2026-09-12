# Guia de Uso: Automador de Profiling Game of Life (C/OpenMP)

Este documento detalha o funcionamento e a utilização do script `profiling_gol.sh`, projetado para automatizar a extração de métricas de desempenho e separar de maneira segura os lotes de saída `.pbm` gerados durante as execuções de profiling.

## 1. Pré-requisitos de Estrutura e Compilação

O script utiliza caminhos relativos e atua como um "coletor" no diretório atual. A estrutura antes da execução deve ser rigorosamente esta:

```text
projeto_gol/
├── gol.c                 
├── gol                   # Binário compilado da versão serial
├── gol_omp               # Binário compilado da versão OpenMP
└── profiling_gol.sh

## 2. Como Executar o Script

1. Conceda permissão de execução ao arquivo bash:
   `chmod +x profiling_gol.sh`
2. Execute o script no diretório raiz do projeto:
   `./profiling_gol.sh`

## 3. Funcionamento Interno do Script

O script opera de forma sequencial, garantindo isolamento total entre as ferramentas de medição para evitar interferência na CPU ou na RAM. Após a execução de cada bateria de testes, os bitmaps (`.pbm`) gerados pelo seu programa são movidos para subpastas dedicadas, evitando sobrescrita.

A execução é dividida em 7 etapas:
1. **Time (`/usr/bin/time -v`):** Captura tempo de relógio, CPU (*User/System*), *Page Faults* e *Context Switches* da versão serial.
2. **Strace (`strace -c`):** Intercepta e contabiliza as chamadas de sistema (Syscalls) e o tempo gasto em modo kernel.
3. **Gprof (`gprof`):** Lê o arquivo `gmon.out` (gerado automaticamente pela compilação `-pg`) para montar o *Flat Profile* e o *Call Graph*.
4. **Cachegrind (`valgrind --tool=cachegrind`):** Simula a hierarquia de cache (L1 e LLC) e gera o relatório linha a linha.
5. **Callgrind (`valgrind --tool=callgrind`):** Contabiliza o custo exato de instruções (Ir) gastas dentro de cada função do código.
6. **Perf Stat (`perf stat`):** Interage diretamente com os Contadores de Monitoramento de Performance (PMUs) do processador físico para registrar *Cycles*, *Instructions*, IPC e erros de predição de *Branches*. Realiza testes de escalabilidade executando a versão OpenMP com 1, 2, 4 e 8 threads sequencialmente.
7. **Perf Report (`perf record / report`):** Amostra a execução em tempo real para identificar a árvore de overhead de concorrência e o peso das *Worker Functions* da biblioteca OpenMP (`libgomp`).


## 4. Estrutura da Saída Gerada

Ao final da execução, a pasta `relatorios_profiling/` será criada com subdiretórios numerados. Os testes que envolvem escalabilidade (Time e Perf Stat) possuem os resultados serial e paralelos isolados internamente.

relatorios_profiling/
├── 1_time/
│   ├── bitmaps_omp_1t/
│   ├── bitmaps_omp_2t/
│   ├── bitmaps_omp_4t/
│   ├── bitmaps_omp_8t/
│   ├── bitmaps_serial/
│   ├── time_omp_1t.txt ...
│   └── time_serial.txt
├── 2_strace/
├── 3_gprof/
├── 4_cachegrind/
├── 5_callgrind/
├── 6_perf_stat/
│   ├── bitmaps_omp_1t/ ...
│   ├── perf_stat_omp_1t.txt ...
│   └── perf_stat_serial.txt
└── 7_perf_report/