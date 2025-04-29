#include "PCFG.h"
#include <chrono>
#include <fstream>
#include "md5.h"
#include <iomanip>
using namespace std;
using namespace chrono;

// 编译指令如下：
// g++ correctness.cpp train.cpp guessing.cpp md5.cpp -o test.exe


// 通过这个函数，你可以验证你实现的SIMD哈希函数的正确性
int main()
{
    bit32 state[4][4];
    string str_arr[4] =
    {
        "fkasdfnav",
        "bvaisdbja",
        "adfasjdva",
        "vkjnakdjf"
    };

    //MD5Hash("bvaisdbjasdkafkasdfnavkjnakdjfejfanjsdnfkajdfkajdfjkwanfdjaknsvjkanbjbjadfajwefajksdfakdnsvjadfasjdvabvaisdbjasdkafkasdfnavkjnakdjfejfanjsdnfkajdfkajdfjkwanfdjaknsvjkanbjbjadfajwefajksdfakdnsvjadfasjdvabvaisdbjasdkafkasdfnavkjnakdjfejfanjsdnfkajdfkajdfjkwanfdjaknsvjkanbjbjadfajwefajksdfakdnsvjadfasjdvabvaisdbjasdkafkasdfnavkjnakdjfejfanjsdnfkajdfkajdfjkwanfdjaknsvjkanbjbjadfajwefajksdfakdnsvjadfasjdva", state);
    
    SIMD_MD5Hash(str_arr, state);

    for(int i0 = 0; i0 < 4; i0 += 1)
    {
        for (int i1 = 0; i1 < 4; i1 += 1)
        {
            cout << std::setw(8) << std::setfill('0') << hex << state[i0][i1];
        }
    }
    cout << endl;
}