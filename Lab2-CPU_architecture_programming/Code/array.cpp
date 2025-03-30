#include <iostream>
#include <windows.h>

using namespace std;

int N;

const int START=20000;
const int END=20000;
const int STEP=100;
const int LOOP=1000;

double *a;
double sum=0;

void init()
{
    a=new double[N];
    for(int i=0;i<N;i++)
    {
        a[i]=i;
    }
}

void cleanup() {
    delete[] a;
}

int main()
{
    long long head, tail, freq;

    for (N = START; N <= END; N += STEP) {
        init();

        QueryPerformanceFrequency((LARGE_INTEGER*)&freq);
        QueryPerformanceCounter((LARGE_INTEGER*)&head);

        for(int k=0;k<LOOP;k++)
        {
            sum=0;

            //normal
            /*
            for(int i=0;i<N;i++)
            {
                sum+=a[i];
            }
            */

            //optimize_multi_route
            /*
            double sum1=0,sum2=0;
            for(int i=0;i<N;i+=2)
            {
                sum1+=a[i];
                sum2+=a[i+1];
            }
            sum=sum1+sum2;
            */

            //optimize_iter_r

            for(int m=N;m>1;m/=2)
            {
                for(int i=0;i<m/2;i++)
                {
                    a[i]=a[i*2]+a[i*2+1];
                }
            }
            sum=a[0];

        }

        QueryPerformanceCounter((LARGE_INTEGER*)&tail);

        cout  << N << ":" << ((tail - head) * 1000000.0 / freq) / LOOP << " us"<< endl;

        cleanup();
    }

    return 0;
}
