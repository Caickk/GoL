#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <omp.h>

/*
void save_pbm(void *u, int w, int h, int iter)
{
    unsigned (*univ)[w] = u;
    char filename[64];
    sprintf(filename, "gol_%d.pbm", iter);
    FILE *f = fopen(filename, "w");
    if (!f) {
        perror("Erro ao criar o arquivo PBM");
        return;
    }
    fprintf(f, "P1\n%d %d\n", w, h);
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            fprintf(f, "%d ", univ[y][x] ? 1 : 0);
        }
        fprintf(f, "\n");
    }
    fclose(f);
}
*/

// evolve: laços invertidos (x externo, y interno) para que a
// divisão de trabalho do OpenMP seja por COLUNAS, nao por linhas.
void evolve(void *u, int w, int h)
{
    unsigned (*univ)[w] = u;
    unsigned new[h][w];

    // Diretiva OpenMP: divide as iteracoes do eixo X (colunas) entre as threads
    #pragma omp parallel for
    for (int x = 0; x < w; x++) {
        for (int y = 0; y < h; y++) {
            int n = 0;
            for (int y1 = y - 1; y1 <= y + 1; y1++) {
                for (int x1 = x - 1; x1 <= x + 1; x1++) {
                    if (univ[(y1 + h) % h][(x1 + w) % w]) {
                        n++;
                    }
                }
            }
            if (univ[y][x]) n--;
            new[y][x] = (n == 3 || (n == 2 && univ[y][x]));
        }
    }

    // Copia de volta, tambem dividida por colunas
    #pragma omp parallel for
    for (int x = 0; x < w; x++) {
        for (int y = 0; y < h; y++) {
            univ[y][x] = new[y][x];
        }
    }
}

int count_alive(void *u, int w, int h)
{
    unsigned (*univ)[w] = u;
    int total_alive = 0;
    // Reducao com particao por colunas
    #pragma omp parallel for reduction(+:total_alive)
    for (int x = 0; x < w; x++) {
        for (int y = 0; y < h; y++) {
            total_alive += univ[y][x];
        }
    }
    return total_alive;
}

void game(int w, int h, int max_iter)
{
    unsigned univ[h][w];

    // Inicializacao tambem dividida por colunas
    #pragma omp parallel for
    for (int x = 0; x < w; x++) {
        for (int y = 0; y < h; y++) {
            if (x == w / 2 || y == h / 2) {
                univ[y][x] = 1;
            } else {
                univ[y][x] = 0;
            }
        }
    }

    // const int save_interval = 500;
    for (int iter = 0; iter <= max_iter; iter++) {
        // if (iter % save_interval == 0) {
        //     save_pbm(univ, w, h, iter);
        // }
        evolve(univ, w, h);
    }
    int final_alive = count_alive(univ, w, h);
    printf("Total de celulas vivas ao final: %d\n", final_alive);
}

int main(void)
{
    int w = 500;
    int h = 500;
    int max_iter = 5000;

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    game(w, h, max_iter);

    clock_gettime(CLOCK_MONOTONIC, &end);
    double time_taken = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1000000000.0;
    printf("Tempo interno de execucao: %f segundos\n", time_taken);
    return 0;
}