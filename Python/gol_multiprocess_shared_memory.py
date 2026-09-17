"""
Game of Life - multiprocessing + shared_memory

Mesma decomposicao logica do codigo original baseado em Pipe (blocos de
colunas contiguos, bordas verticais trocadas entre vizinhos), mas trocando
a troca de bordas via Pipe (serializacao a cada geracao) por leitura direta
de um bloco unico de shared_memory (sem serializacao, sem copia).
"""

import multiprocessing as mp
import os
import time
from multiprocessing import shared_memory

RULE = bytes(1 if i in (3, 19, 20) else 0 for i in range(256))
TO_ASCII = bytes((0x30 + i) if i < 2 else 0x30 for i in range(256))

def split_columns(w, n_tasks):
    base, extra = divmod(w, n_tasks)
    blocks, x = [], 0
    for i in range(n_tasks):
        size = base + (1 if i < extra else 0)
        blocks.append((x, x + size))
        x += size
    return blocks

def _worker(shm_name, w, h, x0, x1, max_iter, barrier):
    """Cada worker cuida das colunas [x0, x1) de TODAS as h linhas."""
    
    # 1. Abre a conexao com a memoria compartilhada usando o nome
    shm = shared_memory.SharedMemory(name=shm_name)
    
    try:
        buf = shm.buf
        plane = w * h
        cur_off, nxt_off = 0, plane
        local_w = x1 - x0
        rule = RULE

        # 2. Correção (max_iter + 1) para igualar exatamente à versão do Pipe
        for _gen in range(max_iter + 1):
            for y in range(h):
                row_base = cur_off + y * w
                up_base = cur_off + ((y - 1) % h) * w
                dn_base = cur_off + ((y + 1) % h) * w
                out_base = nxt_off + y * w

                for x in range(x0, x1):
                    n = 0
                    for yy_base in (up_base, row_base, dn_base):
                        left_x = (x - 1) % w
                        right_x = (x + 1) % w
                        n += buf[yy_base + left_x]
                        n += buf[yy_base + x]
                        n += buf[yy_base + right_x]

                    idx = n + (buf[row_base + x] << 4)
                    buf[out_base + x] = rule[idx]

            barrier.wait()
            cur_off, nxt_off = nxt_off, cur_off

    finally:
        # 3. CRÍTICO: Fecha a referência local do worker para evitar "Out of Memory" e vazamentos
        shm.close()


def count_alive(shm, w, h, cur_off):
    plane = w * h
    return sum(shm.buf[cur_off:cur_off + plane])


def run(w, h, max_iter, n_tasks=None, save_interval=500):
    if n_tasks is None:
        n_tasks = os.cpu_count() or 1
    n_tasks = max(1, min(n_tasks, w))

    plane = w * h
    shm = shared_memory.SharedMemory(create=True, size=2 * plane)
    try:
        buf = shm.buf
        buf[0:plane] = bytes(plane)
        row_mid = bytearray(w)
        for x in range(w):
            row_mid[x] = 1
        buf[(h // 2) * w:(h // 2) * w + w] = row_mid
        xc = w // 2
        for y in range(h):
            buf[y * w + xc] = 1

        barrier = mp.Barrier(n_tasks + 1)
        blocks = split_columns(w, n_tasks)

        procs = [
            mp.Process(target=_worker,
                       # 4. Passamos shm.name ao invés do objeto inteiro
                       args=(shm.name, w, h, x0, x1, max_iter, barrier))
            for (x0, x1) in blocks
        ]
        for p in procs:
            p.start()

        cur_off = 0
        # 5. Correção (max_iter + 1) para sincronizar com os workers
        for gen in range(max_iter + 1):
            barrier.wait()
            cur_off = plane - cur_off

        for p in procs:
            p.join()

        final_alive = count_alive(shm, w, h, cur_off)

        del buf
    finally:
        shm.close()
        shm.unlink()

    return final_alive


def main():
    w = int(os.environ.get("GOL_W", 500))
    h = int(os.environ.get("GOL_H", 500))
    max_iter = int(os.environ.get("GOL_ITER", 5000))
    n_tasks = int(os.environ.get("GOL_WORKERS", 4))
    interval = int(os.environ.get("GOL_SAVE", 500))

    print(f"Executando com {n_tasks} tarefas (blocos de colunas, shared_memory), "
          f"grade {w}x{h}, {max_iter} geracoes...")

    start = time.perf_counter()
    final_alive = run(w, h, max_iter, n_tasks=n_tasks, save_interval=interval)
    end = time.perf_counter()

    print(f"Total de celulas vivas ao final: {final_alive}")
    print(f"Tempo interno de execucao: {end - start:f} segundos")


if __name__ == "__main__":
    mp.set_start_method("fork")
    main()