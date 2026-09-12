#!/bin/bash

mkdir -p relatorios_profiling/C_OpenMP

echo "====================================================================="
echo " LIMPANDO AMBIENTE C: Removendo lotes PBM de execuções passadas..."
rm -f *.pbm
echo "====================================================================="
echo ""

# ------------------------------------------------------------------------------
# 1. Análise de Sistema e Tempo (/usr/bin/time)
# ------------------------------------------------------------------------------
echo "[1/7] Extraindo métricas de tempo e memória (/usr/bin/time)..."
mkdir -p relatorios_profiling/C_OpenMP/1_time

echo "      -> Testando Serial..."
/usr/bin/time -v ./gol 2> relatorios_profiling/C_OpenMP/1_time/time_serial.txt
mkdir -p relatorios_profiling/C_OpenMP/1_time/bitmaps_serial && mv *.pbm relatorios_profiling/C_OpenMP/1_time/bitmaps_serial/ 2>/dev/null || true

echo "      -> Testando OpenMP com 1 thread..."
OMP_NUM_THREADS=1 /usr/bin/time -v ./gol_omp 2> relatorios_profiling/C_OpenMP/1_time/time_omp_1t.txt
mkdir -p relatorios_profiling/C_OpenMP/1_time/bitmaps_omp_1t && mv *.pbm relatorios_profiling/C_OpenMP/1_time/bitmaps_omp_1t/ 2>/dev/null || true

echo "      -> Testando OpenMP com 2 threads..."
OMP_NUM_THREADS=2 /usr/bin/time -v ./gol_omp 2> relatorios_profiling/C_OpenMP/1_time/time_omp_2t.txt
mkdir -p relatorios_profiling/C_OpenMP/1_time/bitmaps_omp_2t && mv *.pbm relatorios_profiling/C_OpenMP/1_time/bitmaps_omp_2t/ 2>/dev/null || true

echo "      -> Testando OpenMP com 4 threads..."
OMP_NUM_THREADS=4 /usr/bin/time -v ./gol_omp 2> relatorios_profiling/C_OpenMP/1_time/time_omp_4t.txt
mkdir -p relatorios_profiling/C_OpenMP/1_time/bitmaps_omp_4t && mv *.pbm relatorios_profiling/C_OpenMP/1_time/bitmaps_omp_4t/ 2>/dev/null || true

echo "      -> Testando OpenMP com 8 threads..."
OMP_NUM_THREADS=8 /usr/bin/time -v ./gol_omp 2> relatorios_profiling/C_OpenMP/1_time/time_omp_8t.txt
mkdir -p relatorios_profiling/C_OpenMP/1_time/bitmaps_omp_8t && mv *.pbm relatorios_profiling/C_OpenMP/1_time/bitmaps_omp_8t/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 2. Syscalls e Tempo de Kernel (Strace)
# ------------------------------------------------------------------------------
echo "[2/7] Mapeando chamadas de sistema (Strace)..."
mkdir -p relatorios_profiling/C_OpenMP/2_strace
strace -c -o relatorios_profiling/C_OpenMP/2_strace/strace_report.txt ./gol
mkdir -p relatorios_profiling/C_OpenMP/2_strace/bitmaps && mv *.pbm relatorios_profiling/C_OpenMP/2_strace/bitmaps/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 3. Profiling de Tempo de Execução e Call Graph (Gprof)
# ------------------------------------------------------------------------------
echo "[3/7] Gerando flat profile e call graph (Gprof)..."
mkdir -p relatorios_profiling/C_OpenMP/3_gprof
./gol > /dev/null
gprof ./gol gmon.out > relatorios_profiling/C_OpenMP/3_gprof/analise_gprof.txt
mkdir -p relatorios_profiling/C_OpenMP/3_gprof/bitmaps && mv *.pbm relatorios_profiling/C_OpenMP/3_gprof/bitmaps/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 4. Análise de Cache e Branch Prediction (Cachegrind)
# ------------------------------------------------------------------------------
echo "[4/7] Simulando comportamento de cache L1/LLC (Cachegrind)..."
mkdir -p relatorios_profiling/C_OpenMP/4_cachegrind
valgrind --tool=cachegrind --cachegrind-out-file=cachegrind.out ./gol > /dev/null 2>&1
cg_annotate cachegrind.out --show=Ir,I1mr,ILmr,Dr,D1mr,DLmr,Dw,D1mw,DLmw > relatorios_profiling/C_OpenMP/4_cachegrind/cachegrind_report.txt
rm -f cachegrind.out
mkdir -p relatorios_profiling/C_OpenMP/4_cachegrind/bitmaps && mv *.pbm relatorios_profiling/C_OpenMP/4_cachegrind/bitmaps/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 5. Custo Computacional de Funções (Callgrind)
# ------------------------------------------------------------------------------
echo "[5/7] Contabilizando custo de instruções por função (Callgrind)..."
mkdir -p relatorios_profiling/C_OpenMP/5_callgrind
valgrind --tool=callgrind --callgrind-out-file=callgrind.out ./gol > /dev/null 2>&1
callgrind_annotate callgrind.out > relatorios_profiling/C_OpenMP/5_callgrind/callgrind_report.txt
rm -f callgrind.out
mkdir -p relatorios_profiling/C_OpenMP/5_callgrind/bitmaps && mv *.pbm relatorios_profiling/C_OpenMP/5_callgrind/bitmaps/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 6. Contadores Físicos de Hardware (Perf Stat)
# ------------------------------------------------------------------------------
echo "[6/7] Lendo PMUs físicos (Perf Stat)..."
mkdir -p relatorios_profiling/C_OpenMP/6_perf_stat

echo "      -> Testando Serial..."
perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses,L1-dcache-load-misses,LLC-load-misses -o relatorios_profiling/C_OpenMP/6_perf_stat/perf_stat_serial.txt ./gol
mkdir -p relatorios_profiling/C_OpenMP/6_perf_stat/bitmaps_serial && mv *.pbm relatorios_profiling/C_OpenMP/6_perf_stat/bitmaps_serial/ 2>/dev/null || true

echo "      -> Testando OpenMP com 1 thread..."
OMP_NUM_THREADS=1 perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses,L1-dcache-load-misses,LLC-load-misses -o relatorios_profiling/C_OpenMP/6_perf_stat/perf_stat_omp_1t.txt ./gol_omp
mkdir -p relatorios_profiling/C_OpenMP/6_perf_stat/bitmaps_omp_1t && mv *.pbm relatorios_profiling/C_OpenMP/6_perf_stat/bitmaps_omp_1t/ 2>/dev/null || true

echo "      -> Testando OpenMP com 2 threads..."
OMP_NUM_THREADS=2 perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses,L1-dcache-load-misses,LLC-load-misses -o relatorios_profiling/C_OpenMP/6_perf_stat/perf_stat_omp_2t.txt ./gol_omp
mkdir -p relatorios_profiling/C_OpenMP/6_perf_stat/bitmaps_omp_2t && mv *.pbm relatorios_profiling/C_OpenMP/6_perf_stat/bitmaps_omp_2t/ 2>/dev/null || true

echo "      -> Testando OpenMP com 4 threads..."
OMP_NUM_THREADS=4 perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses,L1-dcache-load-misses,LLC-load-misses -o relatorios_profiling/C_OpenMP/6_perf_stat/perf_stat_omp_4t.txt ./gol_omp
mkdir -p relatorios_profiling/C_OpenMP/6_perf_stat/bitmaps_omp_4t && mv *.pbm relatorios_profiling/C_OpenMP/6_perf_stat/bitmaps_omp_4t/ 2>/dev/null || true

echo "      -> Testando OpenMP com 8 threads..."
OMP_NUM_THREADS=8 perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses,L1-dcache-load-misses,LLC-load-misses -o relatorios_profiling/C_OpenMP/6_perf_stat/perf_stat_omp_8t.txt ./gol_omp
mkdir -p relatorios_profiling/C_OpenMP/6_perf_stat/bitmaps_omp_8t && mv *.pbm relatorios_profiling/C_OpenMP/6_perf_stat/bitmaps_omp_8t/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 7. Identificação de Overhead (Perf Report)
# ------------------------------------------------------------------------------
echo "[7/7] Registrando overhead de concorrência e hotspots (Perf Record)..."
mkdir -p relatorios_profiling/C_OpenMP/7_perf_report

echo "      -> Testando Serial..."
perf record -o perf_serial.data ./gol > /dev/null 2>&1
perf report -i perf_serial.data --stdio > relatorios_profiling/C_OpenMP/7_perf_report/perf_report_serial.txt
mkdir -p relatorios_profiling/C_OpenMP/7_perf_report/bitmaps_serial && mv *.pbm relatorios_profiling/C_OpenMP/7_perf_report/bitmaps_serial/ 2>/dev/null || true

echo "      -> Testando OpenMP (4 threads)..."
OMP_NUM_THREADS=4 perf record -o perf_omp.data ./gol_omp > /dev/null 2>&1
perf report -i perf_omp.data --stdio > relatorios_profiling/C_OpenMP/7_perf_report/perf_report_omp_4t.txt
mkdir -p relatorios_profiling/C_OpenMP/7_perf_report/bitmaps_omp_4t && mv *.pbm relatorios_profiling/C_OpenMP/7_perf_report/bitmaps_omp_4t/ 2>/dev/null || true

rm -f perf_serial.data perf_omp.data
echo ""
echo "Concluído! Todos os relatórios C e lotes PBM foram isolados em: relatorios_profiling/C_OpenMP/"