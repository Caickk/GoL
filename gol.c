#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>

void evolve(void *u, int w, int h)
{
   unsigned (*univ)[w] = u;
   unsigned new[h][w];

   for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
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

   for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
         univ[y][x] = new[y][x];
      }
   }
}

// A função game recebe largura e altura da matriz, o total de iterações 
void game(int w, int h, int max_iter)
{
   unsigned univ[h][w];
   
   // Inicialização aleatória
   for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
         univ[y][x] = rand() < RAND_MAX / 10 ? 1 : 0;
      }
   }

   // Substituição do while(1) por um laço iterativo
   for (int iter = 0; iter <= max_iter; iter++) {
      evolve(univ, w, h);
   }
}

int main(void)
{
   // Dimensões e iterações fixas
   int w = 100;
   int h = 100;
   int max_iter = 2000;
   
   // Semente randômica baseada no tempo para gerar matrizes diferentes a cada execução
   srand(time(NULL));

   // Estruturas de tempo obrigatórias para validação
   struct timespec start, end;

   // Captura o tempo EXATAMENTE ANTES do processamento iniciar
   clock_gettime(CLOCK_MONOTONIC, &start);

   // Chama a função principal
   game(w, h, max_iter);

   // Captura o tempo EXATAMENTE APÓS o processamento terminar
   clock_gettime(CLOCK_MONOTONIC, &end);

   // Calcula o tempo total combinando segundos e nanossegundos
   double time_taken = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1000000000.0;

   // Imprime o tempo de validação exigido pela atividade
   printf("Tempo interno de execucao: %f segundos\n", time_taken);
   
   return 0;
}
