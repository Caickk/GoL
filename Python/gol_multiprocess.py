import multiprocessing as mp
import os
import time

def save_pbm(univ, w, h, iter_count):
    filename = f"gol_{iter_count}.pbm"
    try:
        with open(filename, "w") as f:
            f.write(f"P1\n{w} {h}\n")
            for row in univ:
                f.write("".join(f"{cell} " for cell in row) + "\n")
    except IOError as e:
        print(f"Erro ao criar o arquivo PBM: {e}")

def _split_columns(w, n_tasks):
    base = w // n_tasks
    extra = w % n_tasks
    blocks = []
    x = 0
    for i in range(n_tasks):
        size = base + (1 if i < extra else 0)
        blocks.append((x, x + size))
        x += size
    return blocks

def _worker(task_id, n_tasks, local_w, h, max_iter,
            init_cols, left_conn, right_conn, result_conn):
    cur = init_cols
    nxt = [[0] * local_w for _ in range(h)]
    save_interval = 500

    for _gen in range(max_iter + 1):
        # Sincroniza e envia dados para o processo principal salvar o PBM
        if _gen % save_interval == 0 and result_conn is not None:
            result_conn.send(cur)
            result_conn.recv() # Aguarda ACK do processo pai para continuar

        if n_tasks == 1:
            left_ghost = [cur[y][local_w - 1] for y in range(h)]
            right_ghost = [cur[y][0] for y in range(h)]
        else:
            left_col = [cur[y][0] for y in range(h)]
            right_col = [cur[y][local_w - 1] for y in range(h)]

            left_conn.send(left_col)
            right_conn.send(right_col)

            left_ghost = left_conn.recv()
            right_ghost = right_conn.recv()

        for y in range(h):
            for x in range(local_w):
                n = 0
                for dy in (-1, 0, 1):
                    yy = (y + dy) % h
                    for dx in (-1, 0, 1):
                        xx = x + dx
                        if xx < 0:
                            val = left_ghost[yy]
                        elif xx >= local_w:
                            val = right_ghost[yy]
                        else:
                            val = cur[yy][xx]
                        if val:
                            n += 1
                if cur[y][x]:
                    n -= 1
                nxt[y][x] = 1 if (n == 3 or (n == 2 and cur[y][x])) else 0

        cur, nxt = nxt, cur

    if result_conn is not None:
        result_conn.close()
    if left_conn is not None:
        left_conn.close()
    if right_conn is not None:
        right_conn.close()

def run_parallel_columns(w, h, max_iter, n_tasks=None, gather_result=True):
    if n_tasks is None:
        n_tasks = os.cpu_count() or 1
    n_tasks = max(1, min(n_tasks, w))

    col_blocks = _split_columns(w, n_tasks)
    full_init = [[1 if (x == w // 2 or y == h // 2) else 0 for x in range(w)] for y in range(h)]
    
    init_blocks = []
    for (x_start, x_end) in col_blocks:
        block = [[full_init[y][x] for x in range(x_start, x_end)] for y in range(h)]
        init_blocks.append(block)

    right_ends = [None] * n_tasks   
    left_ends = [None] * n_tasks    

    if n_tasks > 1:
        for i in range(n_tasks):
            a, b = mp.Pipe(duplex=True)
            right_ends[i] = a                  
            left_ends[(i + 1) % n_tasks] = b   

    result_parent_conns = [None] * n_tasks
    result_child_conns = [None] * n_tasks
    if gather_result:
        for i in range(n_tasks):
            p_conn, c_conn = mp.Pipe(duplex=True) # Alterado para True para permitir ACK
            result_parent_conns[i] = p_conn
            result_child_conns[i] = c_conn

    processes = []
    for i in range(n_tasks):
        local_w = col_blocks[i][1] - col_blocks[i][0]
        proc = mp.Process(
            target=_worker,
            args=(i, n_tasks, local_w, h, max_iter,
                  init_blocks[i], left_ends[i], right_ends[i], result_child_conns[i]),
        )
        processes.append(proc)

    for proc in processes:
        proc.start()

    for i in range(n_tasks):
        if result_child_conns[i] is not None:
            result_child_conns[i].close()

    save_interval = 500
    for _gen in range(max_iter + 1):
        if _gen % save_interval == 0 and gather_result:
            final_board = [[0] * w for _ in range(h)]
            for i, (x_start, x_end) in enumerate(col_blocks):
                block = result_parent_conns[i].recv()
                for y in range(h):
                    for j, x in enumerate(range(x_start, x_end)):
                        final_board[y][x] = block[y][j]
                result_parent_conns[i].send(True) # Libera o worker
            
            save_pbm(final_board, w, h, _gen)

    for proc in processes:
        proc.join()

    return None

def main():

    w = int(os.environ.get("GOL_W", 500))
    h = int(os.environ.get("GOL_H", 500))
    max_iter = int(os.environ.get("GOL_ITER", 5000))
    n_tasks = int(os.environ.get("GOL_WORKERS", 4))  
    

    print(f"Executando com {n_tasks} tarefas (blocos de colunas), "
          f"grade {w}x{h}, {max_iter} gerações...")

    start = time.perf_counter()

    # gather_result forçado para True para habilitar a captura e salvamento
    run_parallel_columns(w, h, max_iter, n_tasks=n_tasks, gather_result=True)

    end = time.perf_counter()
    time_taken = end - start

    print(f"Tempo interno de execucao: {time_taken:f} segundos")

if __name__ == "__main__":
    mp.set_start_method("fork") 
    main()