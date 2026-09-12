# Guia de Uso: Automador de Profiling Game of Life (Python)

Este documento detalha o script `profiling_python.sh`, criado para automatizar a extração de métricas (cProfile, Perf, Strace, /usr/bin/time) e lidar com os lotes de saída `.pbm` gerados pelas abordagens Seriais e Paralelas em Python.

## 1. Estrutura do Diretório e Preparação

Os scripts e os arquivos fonte Python devem estar juntos na raiz do diretório.

```text
projeto_gol_python/
├── gol.py                 # Código Serial
├── gol_multithread.py     # Código Multithreading
├── gol_multiprocess.py    # Código Multiprocessing
└── profiling_python.sh    # Script de Automação Bash

## 2. Como Executar o Script
O Python não precisa de etapas prévias de compilação. Basta garantir as permissões e rodar o orquestrador:

    chmod +x profiling_python.sh

    ./profiling_python.sh

## 3. Fluxo de Profiling Aplicado

Diferente do C, o Python possui uma máquina virtual e um interpretador. O fluxo de profiling adaptado utiliza:

    cProfile (-m cProfile -s cumulative): Substitui o Gprof/Callgrind, capturando chamadas nativas de funções internas do Python para mapear os gargalos de alto nível.

    Perf Stat: Mantém a mesma interface do C, registrando eventos em nível de CPU física, sendo excelente para demonstrar se a máquina virtual aproveitou ou não os ciclos do hardware.

    Perf Record (-g): O parâmetro especial -g (Call-Graph) é introduzido para capturar as pilhas de execução de troca de contexto e Comunicação Interprocessos (IPC) via Pipes no Multiprocessing.

    Escalabilidade (/usr/bin/time -v): Executado em laço (1, 2, 4, 8) para revelar empiricamente o impacto do Global Interpreter Lock (GIL) no Threading comparado ao isolamento de memória do Multiprocessing.

## 4. Estrutura da Saída Gerada

A execução criará a pasta relatorios_python/ isolando relatórios e varrendo imediatamente os matrizes geradas:

relatorios_python/
├── 1_serial/
│   ├── bitmaps_cprofile/
│   ├── bitmaps_perf/
│   ├── bitmaps_strace/
│   ├── cprofile_serial.txt
│   ├── perf_stat_serial.txt
│   └── strace_serial.txt
├── 2_multithreading/
│   ├── bitmaps_time_1t/ ...
│   ├── bitmaps_time_8t/
│   ├── cprofile_mt_4t.txt
│   ├── perf_stat_mt_4t.txt
│   └── time_mt_1t.txt ...
└── 3_multiprocessing/
    ├── bitmaps_record/
    ├── bitmaps_time_1p/ ...
    ├── cprofile_mp_4p.txt
    ├── perf_report_mp_4p.txt
    ├── perf_stat_mp_4p.txt
    └── time_mp_1p.txt ...