import time
import os
from concurrent.futures import ThreadPoolExecutor

def save_pbm(univ, w, h, iter_count):
    filename = f"gol_{iter_count}.pbm"
    try:
        with open(filename, "w") as f:
            f.write(f"P1\n{w} {h}\n")
            for row in univ:
                f.write("".join(f"{cell} " for cell in row) + "\n")
    except IOError as e:
        print(f"Erro ao criar o arquivo PBM: {e}")

def process_chunk(univ, new, w, h, start_y, end_y):
    """Calcula o próximo estado para um bloco de linhas."""
    for y in range(start_y, end_y):
        for x in range(w):
            n = 0
            
            for y1 in range(y - 1, y + 2):
                for x1 in range(x - 1, x + 2):
                    if univ[(y1 + h) % h][(x1 + w) % w]:
                        n += 1

            if univ[y][x]:
                n -= 1
            
            if n == 3 or (n == 2 and univ[y][x]):
                new[y][x] = 1
            else:
                new[y][x] = 0

def copy_chunk(univ, new, w, start_y, end_y):
    """Copia o novo estado de volta para a matriz original para o bloco correspondente."""
    for y in range(start_y, end_y):
        for x in range(w):
            univ[y][x] = new[y][x]

def evolve_mt(univ, w, h, executor, num_threads):
    new = [[0 for _ in range(w)] for _ in range(h)]
    
    chunk_size = h // num_threads
    futures = []
    
    # Fase 1: Calcula o próximo estado em paralelo
    for i in range(num_threads):
        start_y = i * chunk_size
        # Garante que a última thread pegue qualquer resto de divisão
        end_y = h if i == num_threads - 1 else (i + 1) * chunk_size
        futures.append(executor.submit(process_chunk, univ, new, w, h, start_y, end_y))
        
    # Sincroniza as threads antes de iniciar a cópia
    for f in futures:
        f.result()
        
    # Fase 2: Copia o estado calculado de volta em paralelo
    futures = []
    for i in range(num_threads):
        start_y = i * chunk_size
        end_y = h if i == num_threads - 1 else (i + 1) * chunk_size
        futures.append(executor.submit(copy_chunk, univ, new, w, start_y, end_y))
        
    for f in futures:
        f.result()

def game(w, h, max_iter, num_threads):
    # Inicialização determinística: Uma cruz perfeita cruzando a matriz ao meio
    univ = [[1 if (x == w // 2 or y == h // 2) else 0 for x in range(w)] for y in range(h)]

    # Inicializa o executor fora do laço para não recriar threads a cada geração
    save_interval = 500
    with ThreadPoolExecutor(max_workers=num_threads) as executor:
        for iter_count in range(max_iter + 1):
            if iter_count % save_interval == 0:
                save_pbm(univ, w, h, iter_count)
                
            evolve_mt(univ, w, h, executor, num_threads)

def main():
    # Dimensões e iterações mantidas conforme a versão original
    w = 500
    h = 500
    max_iter = 5000
    num_threads = int(os.environ.get("GOL_WORKERS", 4))
    
    start = time.perf_counter()

    game(w, h, max_iter, num_threads)

    end = time.perf_counter()
    time_taken = end - start

    print(f"Tempo interno de execucao (Multithread): {time_taken:f} segundos")

if __name__ == "__main__":
    main()
