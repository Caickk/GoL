#!/bin/bash

# ==============================================================================
# Script de Profiling e Análise de Desempenho - Game of Life (Python)
# ==============================================================================

PY_SERIAL="gol.py"
PY_THREAD="gol_multithread.py"
PY_PROC="gol_multiprocess.py"
RELATORIOS_DIR="relatorios_python"
PERF_EVENTS="cycles,instructions,cache-references,cache-misses,branches,branch-misses,L1-dcache-load-misses,LLC-load-misses"

mkdir -p $RELATORIOS_DIR

echo "====================================================================="
echo " LIMPANDO AMBIENTE: Removendo lotes PBM de execuções passadas..."
rm -f *.pbm
echo "====================================================================="
echo ""

# ------------------------------------------------------------------------------
# 1. VERSÃO PYTHON SERIAL
# ------------------------------------------------------------------------------
echo "[1/3] Executando profiling da versão Serial..."
DIR_SER="$RELATORIOS_DIR/1_serial"
mkdir -p $DIR_SER

echo "      -> Gerando cProfile..."
python3 -m cProfile -s cumulative \(PY_SERIAL >\)DIR_SER/cprofile_serial.txt
mkdir -p \(DIR_SER/bitmaps_cprofile && mv *.pbm\)DIR_SER/bitmaps_cprofile/ 2>/dev/null || true

echo "      -> Coletando PMUs de hardware (Perf Stat)..."
perf stat -e \(PERF_EVENTS -o\)DIR_SER/perf_stat_serial.txt python3$PY_SERIAL
mkdir -p \(DIR_SER/bitmaps_perf && mv *.pbm\)DIR_SER/bitmaps_perf/ 2>/dev/null || true

echo "      -> Mapeando syscalls e modo kernel (Strace)..."
strace -c -o \(DIR_SER/strace_serial.txt python3\)PY_SERIAL
mkdir -p \(DIR_SER/bitmaps_strace && mv *.pbm\)DIR_SER/bitmaps_strace/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 2. VERSÃO MULTITHREADING (GIL Analysis)
# ------------------------------------------------------------------------------
echo "[2/3] Executando profiling da versão Multithreading..."
DIR_MT="$RELATORIOS_DIR/2_multithreading"
mkdir -p $DIR_MT

export GOL_WORKERS=4
echo "      -> Gerando cProfile (4 threads)..."
python3 -m cProfile -s cumulative \(PY_THREAD >\)DIR_MT/cprofile_mt_4t.txt
mkdir -p \(DIR_MT/bitmaps_cprofile && mv *.pbm\)DIR_MT/bitmaps_cprofile/ 2>/dev/null || true

echo "      -> Coletando PMUs de hardware (Perf Stat - 4 threads)..."
perf stat -e \(PERF_EVENTS -o\)DIR_MT/perf_stat_mt_4t.txt python3$PY_THREAD
mkdir -p \(DIR_MT/bitmaps_perf && mv *.pbm\)DIR_MT/bitmaps_perf/ 2>/dev/null || true

echo "      -> Analisando Escalabilidade e impacto do GIL (1, 2, 4, 8 threads)..."
for W in 1 2 4 8; do
    export GOL_WORKERS=$W
    /usr/bin/time -v python3 \(PY_THREAD 2>\)DIR_MT/time_mt_${W}t.txt
    mkdir -p \(DIR_MT/bitmaps_time_\){W}t && mv *.pbm \(DIR_MT/bitmaps_time_\){W}t/ 2>/dev/null || true
done

# ------------------------------------------------------------------------------
# 3. VERSÃO MULTIPROCESSING (Escalabilidade real)
# ------------------------------------------------------------------------------
echo "[3/3] Executando profiling da versão Multiprocessing..."
DIR_MP="$RELATORIOS_DIR/3_multiprocessing"
mkdir -p $DIR_MP

export GOL_WORKERS=4
echo "      -> Gerando cProfile (4 processos)..."
python3 -m cProfile -s cumulative \(PY_PROC >\)DIR_MP/cprofile_mp_4p.txt
mkdir -p \(DIR_MP/bitmaps_cprofile && mv *.pbm\)DIR_MP/bitmaps_cprofile/ 2>/dev/null || true

echo "      -> Coletando PMUs de hardware (Perf Stat - 4 processos)..."
perf stat -e \(PERF_EVENTS -o\)DIR_MP/perf_stat_mp_4p.txt python3$PY_PROC
mkdir -p \(DIR_MP/bitmaps_perf && mv *.pbm\)DIR_MP/bitmaps_perf/ 2>/dev/null || true

echo "      -> Registrando overhead de IPC (Perf Record/Report - 4 processos)..."
perf record -g -o perf_mp.data python3 $PY_PROC > /dev/null 2>&1
perf report -i perf_mp.data --stdio > $DIR_MP/perf_report_mp_4p.txt
rm perf_mp.data
mkdir -p \(DIR_MP/bitmaps_record && mv *.pbm\)DIR_MP/bitmaps_record/ 2>/dev/null || true

echo "      -> Analisando Escalabilidade (1, 2, 4, 8 processos)..."
for W in 1 2 4 8; do
    export GOL_WORKERS=$W
    /usr/bin/time -v python3 \(PY_PROC 2>\)DIR_MP/time_mp_${W}p.txt
    mkdir -p \(DIR_MP/bitmaps_time_\){W}p && mv *.pbm \(DIR_MP/bitmaps_time_\){W}p/ 2>/dev/null || true
done

echo ""
echo "Concluído! Todos os relatórios Python e lotes PBM foram isolados em: $RELATORIOS_DIR/"