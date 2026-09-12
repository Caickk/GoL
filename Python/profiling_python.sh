#!/bin/bash

mkdir -p relatorios_profiling/Python

echo "====================================================================="
echo " LIMPANDO AMBIENTE PYTHON: Removendo lotes PBM de execuções passadas..."
rm -f *.pbm
echo "====================================================================="
echo ""

# ------------------------------------------------------------------------------
# 1. VERSÃO PYTHON SERIAL
# ------------------------------------------------------------------------------
echo "[1/3] Executando profiling da versão Serial..."
mkdir -p relatorios_profiling/Python/1_serial

echo "      -> Gerando cProfile..."
python3 -m cProfile -s cumulative gol.py > relatorios_profiling/Python/1_serial/cprofile_serial.txt
mkdir -p relatorios_profiling/Python/1_serial/bitmaps_cprofile && mv *.pbm relatorios_profiling/Python/1_serial/bitmaps_cprofile/ 2>/dev/null || true

echo "      -> Coletando PMUs de hardware (Perf Stat)..."
perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses,L1-dcache-load-misses,LLC-load-misses -o relatorios_profiling/Python/1_serial/perf_stat_serial.txt python3 gol.py
mkdir -p relatorios_profiling/Python/1_serial/bitmaps_perf && mv *.pbm relatorios_profiling/Python/1_serial/bitmaps_perf/ 2>/dev/null || true

echo "      -> Mapeando syscalls e modo kernel (Strace)..."
strace -c -o relatorios_profiling/Python/1_serial/strace_serial.txt python3 gol.py
mkdir -p relatorios_profiling/Python/1_serial/bitmaps_strace && mv *.pbm relatorios_profiling/Python/1_serial/bitmaps_strace/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 2. VERSÃO MULTITHREADING (GIL Analysis)
# ------------------------------------------------------------------------------
echo "[2/3] Executando profiling da versão Multithreading..."
mkdir -p relatorios_profiling/Python/2_multithreading

export GOL_WORKERS=4
echo "      -> Gerando cProfile (4 threads)..."
python3 -m cProfile -s cumulative gol_multithread.py > relatorios_profiling/Python/2_multithreading/cprofile_mt_4t.txt
mkdir -p relatorios_profiling/Python/2_multithreading/bitmaps_cprofile && mv *.pbm relatorios_profiling/Python/2_multithreading/bitmaps_cprofile/ 2>/dev/null || true

echo "      -> Coletando PMUs de hardware (Perf Stat - 4 threads)..."
perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses,L1-dcache-load-misses,LLC-load-misses -o relatorios_profiling/Python/2_multithreading/perf_stat_mt_4t.txt python3 gol_multithread.py
mkdir -p relatorios_profiling/Python/2_multithreading/bitmaps_perf && mv *.pbm relatorios_profiling/Python/2_multithreading/bitmaps_perf/ 2>/dev/null || true

echo "      -> Analisando Escalabilidade e impacto do GIL (1, 2, 4, 8 threads)..."
export GOL_WORKERS=1
/usr/bin/time -v python3 gol_multithread.py 2> relatorios_profiling/Python/2_multithreading/time_mt_1t.txt
mkdir -p relatorios_profiling/Python/2_multithreading/bitmaps_time_1t && mv *.pbm relatorios_profiling/Python/2_multithreading/bitmaps_time_1t/ 2>/dev/null || true

export GOL_WORKERS=2
/usr/bin/time -v python3 gol_multithread.py 2> relatorios_profiling/Python/2_multithreading/time_mt_2t.txt
mkdir -p relatorios_profiling/Python/2_multithreading/bitmaps_time_2t && mv *.pbm relatorios_profiling/Python/2_multithreading/bitmaps_time_2t/ 2>/dev/null || true

export GOL_WORKERS=4
/usr/bin/time -v python3 gol_multithread.py 2> relatorios_profiling/Python/2_multithreading/time_mt_4t.txt
mkdir -p relatorios_profiling/Python/2_multithreading/bitmaps_time_4t && mv *.pbm relatorios_profiling/Python/2_multithreading/bitmaps_time_4t/ 2>/dev/null || true

export GOL_WORKERS=8
/usr/bin/time -v python3 gol_multithread.py 2> relatorios_profiling/Python/2_multithreading/time_mt_8t.txt
mkdir -p relatorios_profiling/Python/2_multithreading/bitmaps_time_8t && mv *.pbm relatorios_profiling/Python/2_multithreading/bitmaps_time_8t/ 2>/dev/null || true

# ------------------------------------------------------------------------------
# 3. VERSÃO MULTIPROCESSING (Escalabilidade real)
# ------------------------------------------------------------------------------
echo "[3/3] Executando profiling da versão Multiprocessing..."
mkdir -p relatorios_profiling/Python/3_multiprocessing

export GOL_WORKERS=4
echo "      -> Gerando cProfile (4 processos)..."
python3 -m cProfile -s cumulative gol_multiprocess.py > relatorios_profiling/Python/3_multiprocessing/cprofile_mp_4p.txt
mkdir -p relatorios_profiling/Python/3_multiprocessing/bitmaps_cprofile && mv *.pbm relatorios_profiling/Python/3_multiprocessing/bitmaps_cprofile/ 2>/dev/null || true

echo "      -> Coletando PMUs de hardware (Perf Stat - 4 processos)..."
perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses,L1-dcache-load-misses,LLC-load-misses -o relatorios_profiling/Python/3_multiprocessing/perf_stat_mp_4p.txt python3 gol_multiprocess.py
mkdir -p relatorios_profiling/Python/3_multiprocessing/bitmaps_perf && mv *.pbm relatorios_profiling/Python/3_multiprocessing/bitmaps_perf/ 2>/dev/null || true

echo "      -> Registrando overhead de IPC (Perf Record/Report - 4 processos)..."
perf record -g -o perf_mp.data python3 gol_multiprocess.py > /dev/null 2>&1
perf report -i perf_mp.data --stdio > relatorios_profiling/Python/3_multiprocessing/perf_report_mp_4p.txt
rm -f perf_mp.data
mkdir -p relatorios_profiling/Python/3_multiprocessing/bitmaps_record && mv *.pbm relatorios_profiling/Python/3_multiprocessing/bitmaps_record/ 2>/dev/null || true

echo "      -> Analisando Escalabilidade (1, 2, 4, 8 processos)..."
export GOL_WORKERS=1
/usr/bin/time -v python3 gol_multiprocess.py 2> relatorios_profiling/Python/3_multiprocessing/time_mp_1p.txt
mkdir -p relatorios_profiling/Python/3_multiprocessing/bitmaps_time_1p && mv *.pbm relatorios_profiling/Python/3_multiprocessing/bitmaps_time_1p/ 2>/dev/null || true

export GOL_WORKERS=2
/usr/bin/time -v python3 gol_multiprocess.py 2> relatorios_profiling/Python/3_multiprocessing/time_mp_2p.txt
mkdir -p relatorios_profiling/Python/3_multiprocessing/bitmaps_time_2p && mv *.pbm relatorios_profiling/Python/3_multiprocessing/bitmaps_time_2p/ 2>/dev/null || true

export GOL_WORKERS=4
/usr/bin/time -v python3 gol_multiprocess.py 2> relatorios_profiling/Python/3_multiprocessing/time_mp_4p.txt
mkdir -p relatorios_profiling/Python/3_multiprocessing/bitmaps_time_4p && mv *.pbm relatorios_profiling/Python/3_multiprocessing/bitmaps_time_4p/ 2>/dev/null || true

export GOL_WORKERS=8
/usr/bin/time -v python3 gol_multiprocess.py 2> relatorios_profiling/Python/3_multiprocessing/time_mp_8p.txt
mkdir -p relatorios_profiling/Python/3_multiprocessing/bitmaps_time_8p && mv *.pbm relatorios_profiling/Python/3_multiprocessing/bitmaps_time_8p/ 2>/dev/null || true

echo ""
echo "Concluído! Todos os relatórios Python e lotes PBM foram isolados em: relatorios_profiling/Python/"