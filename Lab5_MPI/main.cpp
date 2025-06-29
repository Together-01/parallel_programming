#include "PCFG.h"
#include <fstream>
#include <iomanip>
#include "md5.h"
#include <mpi.h>
using namespace std;

// mpic++ main.cpp train.cpp guessing.cpp md5.cpp -o main -O2
// qsub qsub_mpi.sh

int main(int argc, char **argv)
{
    MPI_Init(&argc, &argv);
    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    double start_train = MPI_Wtime();
    PriorityQueue q;
    q.m.train("/guessdata/Rockyou-singleLined-full.txt");
    q.m.order();
    q.init();
    double end_train = MPI_Wtime();
    double time_train = end_train - start_train;

    double start_guess = MPI_Wtime();
    int local_num = 0;
    int curr_num = 0;
    int history = 0;
    double hash_time = 0.0;

    while (!q.priority.empty())
    {
        q.PopNext();
        local_num = q.guesses.size();

        int global_curr_num;
        MPI_Allreduce(&local_num, &global_curr_num, 1, MPI_INT, MPI_SUM, MPI_COMM_WORLD);

        if (global_curr_num - curr_num >= 100000)
        {
            if (rank == 0)
            {
                cout << "Guesses generated: " << history + global_curr_num << endl;
            }
            curr_num = global_curr_num;

            int generate_n = 10000000;
            if (history + global_curr_num > generate_n)
                break;
        }

        if (local_num > 1000000)
        {
            double start_hash = MPI_Wtime();

            bit32 state[4];
            for (const string &pw : q.guesses)
            {
                MD5Hash(pw, state);
            }

            double end_hash = MPI_Wtime();
            hash_time += end_hash - start_hash;

            history += curr_num;
            curr_num = 0;
            q.guesses.clear();
        }
    }

    double end_guess = MPI_Wtime();
    double guess_time = end_guess - start_guess;

    double global_guess_time, global_hash_time;
    MPI_Reduce(&guess_time, &global_guess_time, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
    MPI_Reduce(&hash_time, &global_hash_time, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);

    if (rank == 0)
    {
        cout << fixed << setprecision(6);
        cout << "Guess time (excluding hash): " << global_guess_time - global_hash_time << " seconds" << endl;
        cout << "Hash time (max among processes): " << global_hash_time << " seconds" << endl;
        cout << "Train time: " << time_train << " seconds" << endl;
    }

    MPI_Finalize();
    return 0;
}
