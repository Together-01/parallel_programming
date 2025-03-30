#include <iostream>
#include <windows.h>

using namespace std;

const int START=4000;
const int END=4000;
const int STEP=100;
const int LOOP=10;

int N;
double *a, **b, *col_sum;

void init() {
    a = new double[N];
    b = new double*[N];
    col_sum = new double[N];

    for (int i = 0; i < N; i++) {
        a[i] = i;
        b[i] = new double[N];
        for (int j = 0; j < N; j++) {
            b[i][j] = i + j;
        }
    }
}

void cleanup() {
    delete[] a;
    delete[] col_sum;
    for (int i = 0; i < N; i++) {
        delete[] b[i];
    }
    delete[] b;
}

int main() {
    long long head, tail, freq;

    for (N = START; N <= END; N += STEP) {
        init();
        int loop=LOOP;

        QueryPerformanceFrequency((LARGE_INTEGER*)&freq);
        QueryPerformanceCounter((LARGE_INTEGER*)&head);

        for (int k = 0; k < loop; k++) {
            // normal
            /*
            for (int i = 0; i < N; i++) {
                col_sum[i] = 0.0;
                for (int j = 0; j < N; j++) {
                    col_sum[i] += b[j][i] * a[j];
                }
            }
            */
            // cache

            for (int i = 0; i < N; i++) {
                col_sum[i] = 0.0;
            }
            for (int j = 0; j < N; j++) {
                for (int i = 0; i < N; i++) {
                    col_sum[i] += b[j][i] * a[j];
                }
            }

        }

        QueryPerformanceCounter((LARGE_INTEGER*)&tail);

        cout  << N << ":" << ((tail - head) * 1000.0 / freq) / loop << " ms" << endl;

        cleanup();
    }

    return 0;
}
