#!/bin/bash

# ==============================================================================
# Script de Profiling e Análise de Desempenho - Game of Life (C/OpenMP)
# ==============================================================================

EXEC_SEQ="./gol"
EXEC_OMP="./gol_omp"
RELATORIOS_DIR="relatorios_profiling"

mkdir -p $RELATORIOS_DIR

echo "====================================================================="
echo " LIMPANDO AMBIENTE: Removendo lotes PBM de execuções passadas..."
rm -f *.pbm
echo "====================================================================="
echo ""

# ------------------------------------------------------------------------------
# 1. Análise de Sistema e Tempo (/usr/bin/time)
# ------------------------------------------------------------------------------
echo "[1/7] Extraindo métricas de tempo e memória (/usr/bin/time)..."
DIR_TIME="$RELATORIOS_DIR/1_time"
mkdir -p $DIR_TIME

echo "      -> Testando Serial..."
/usr/bin/time -v \(EXEC_SEQ 2>\)DIR_TIME/time_serial.txt
mkdir -p \(DIR_TIME/bitmaps_serial && mv *.pbm\)DIR_TIME/bitmaps_serial/ 2>/dev/null || true

for THREADS in 1 2 4 8; do
    echo "      -> Testando OpenMP com $THREADS thread(s)..."
    OMP_NUM_THREADS=\(THREADS /usr/bin/time -v\)EXEC_OMP 2> \(DIR_TIME/time_omp_\){THREADS}t.txt
    mkdir -p \(DIR_TIME/bitmaps_omp_\){THREADS}t && mv *.pbm \(DIR_TIME/bitmaps_omp_\){THREADS}t/ 2>/dev/null || true
done

# ------------------------------------------------------------------------------
# 2. Syscalls e Tempo de Kernel (Strace)
# ------------------------------------------------------------------------------
echo "[2/7] Mapeando chamadas de sistema (Strace)..."
DIR_STRACE="$RELATORIOS_DIR/2_strace"
mkdir -p $DIR_STRACE
strace -c -o \(DIR_STRACE/strace_report.txt\)EXEC_SEQ
mkdir -p \(DIR_STRACE/bitmaps && mv *.pbm\)DIR_STRACE/bitmaps/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 3. Profiling de Tempo de Execução e Call Graph (Gprof)
# ------------------------------------------------------------------------------
echo "[3/7] Gerando flat profile e call graph (Gprof)..."
DIR_GPROF="$RELATORIOS_DIR/3_gprof"
mkdir -p \(DIR_GPROF\)EXEC_SEQ > /dev/null
gprof \(EXEC_SEQ gmon.out >\)DIR_GPROF/analise_gprof.txt
mkdir -p \(DIR_GPROF/bitmaps && mv *.pbm\)DIR_GPROF/bitmaps/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 4. Análise de Cache e Branch Prediction (Cachegrind)
# ------------------------------------------------------------------------------
echo "[4/7] Simulando comportamento de cache L1/LLC (Cachegrind)..."
DIR_CACHE="$RELATORIOS_DIR/4_cachegrind"
mkdir -p $DIR_CACHE
valgrind --tool=cachegrind --cachegrind-out-file=cachegrind.out $EXEC_SEQ > /dev/null 2>&1
cg_annotate cachegrind.out --show=Ir,I1mr,ILmr,Dr,D1mr,DLmr,Dw,D1mw,DLmw > $DIR_CACHE/cachegrind_report.txt
rm cachegrind.out
mkdir -p \(DIR_CACHE/bitmaps && mv *.pbm\)DIR_CACHE/bitmaps/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 5. Custo Computacional de Funções (Callgrind)
# ------------------------------------------------------------------------------
echo "[5/7] Contabilizando custo de instruções por função (Callgrind)..."
DIR_CALL="$RELATORIOS_DIR/5_callgrind"
mkdir -p $DIR_CALL
valgrind --tool=callgrind --callgrind-out-file=callgrind.out $EXEC_SEQ > /dev/null 2>&1
callgrind_annotate callgrind.out > $DIR_CALL/callgrind_report.txt
rm callgrind.out
mkdir -p \(DIR_CALL/bitmaps && mv *.pbm\)DIR_CALL/bitmaps/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 6. Contadores Físicos de Hardware (Perf Stat)
# ------------------------------------------------------------------------------
echo "[6/7] Lendo PMUs físicos (Perf Stat)..."
DIR_STAT="$RELATORIOS_DIR/6_perf_stat"
mkdir -p $DIR_STAT

echo "      -> Testando Serial..."
perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses,L1-dcache-load-misses,LLC-load-misses -o \(DIR_STAT/perf_stat_serial.txt\)EXEC_SEQ
mkdir -p \(DIR_STAT/bitmaps_serial && mv *.pbm\)DIR_STAT/bitmaps_serial/ 2>/dev/null || true

for THREADS in 1 2 4 8; do
    echo "      -> Testando OpenMP com $THREADS thread(s)..."
    OMP_NUM_THREADS=\(THREADS perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses,L1-dcache-load-misses,LLC-load-misses -o\)DIR_STAT/perf_stat_omp_\({THREADS}t.txt\)EXEC_OMP
    mkdir -p \(DIR_STAT/bitmaps_omp_\){THREADS}t && mv *.pbm \(DIR_STAT/bitmaps_omp_\){THREADS}t/ 2>/dev/null || true
done

# ------------------------------------------------------------------------------
# 7. Identificação de Overhead (Perf Report)
# ------------------------------------------------------------------------------
echo "[7/7] Registrando overhead de concorrência e hotspots (Perf Record)..."
DIR_REPORT="$RELATORIOS_DIR/7_perf_report"
mkdir -p $DIR_REPORT

echo "      -> Testando Serial..."
perf record -o perf_serial.data $EXEC_SEQ > /dev/null 2>&1
perf report -i perf_serial.data --stdio > $DIR_REPORT/perf_report_serial.txt
mkdir -p \(DIR_REPORT/bitmaps_serial && mv *.pbm\)DIR_REPORT/bitmaps_serial/ 2>/dev/null || true

echo "      -> Testando OpenMP (4 threads)..."
OMP_NUM_THREADS=4 perf record -o perf_omp.data $EXEC_OMP > /dev/null 2>&1
perf report -i perf_omp.data --stdio > $DIR_REPORT/perf_report_omp_4t.txt
mkdir -p \(DIR_REPORT/bitmaps_omp_4t && mv *.pbm\)DIR_REPORT/bitmaps_omp_4t/ 2>/dev/null || true

rm perf_serial.data perf_omp.data

echo ""
echo "Concluído! Todos os relatórios e lotes de PBM foram separados no diretório: $RELATORIOS_DIR/"