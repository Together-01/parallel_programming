#include "PCFG.h"
#include"cuda_runtime.h"
#include"device_launch_parameters.h"
#include <cstring>

using namespace std;

void PriorityQueue::CalProb(PT &pt)
{
    // 计算PriorityQueue里面一个PT的流程如下：
    // 1. 首先需要计算一个PT本身的概率。例如，L6S1的概率为0.15
    // 2. 需要注意的是，Queue里面的PT不是“纯粹的”PT，而是除了最后一个segment以外，全部被value实例化的PT
    // 3. 所以，对于L6S1而言，其在Queue里面的实际PT可能是123456S1，其中“123456”为L6的一个具体value。
    // 4. 这个时候就需要计算123456在L6中出现的概率了。假设123456在所有L6 segment中的概率为0.1，那么123456S1的概率就是0.1*0.15

    // 计算一个PT本身的概率。后续所有具体segment value的概率，直接累乘在这个初始概率值上
    pt.prob = pt.preterm_prob;

    // index: 标注当前segment在PT中的位置
    int index = 0;


    for (int idx : pt.curr_indices)
    {
        // pt.content[index].PrintSeg();
        if (pt.content[index].type == 1)
        {
            // 下面这行代码的意义：
            // pt.content[index]：目前需要计算概率的segment
            // m.FindLetter(seg): 找到一个letter segment在模型中的对应下标
            // m.letters[m.FindLetter(seg)]：一个letter segment在模型中对应的所有统计数据
            // m.letters[m.FindLetter(seg)].ordered_values：一个letter segment在模型中，所有value的总数目
            pt.prob *= m.letters[m.FindLetter(pt.content[index])].ordered_freqs[idx];
            pt.prob /= m.letters[m.FindLetter(pt.content[index])].total_freq;
            // cout << m.letters[m.FindLetter(pt.content[index])].ordered_freqs[idx] << endl;
            // cout << m.letters[m.FindLetter(pt.content[index])].total_freq << endl;
        }
        if (pt.content[index].type == 2)
        {
            pt.prob *= m.digits[m.FindDigit(pt.content[index])].ordered_freqs[idx];
            pt.prob /= m.digits[m.FindDigit(pt.content[index])].total_freq;
            // cout << m.digits[m.FindDigit(pt.content[index])].ordered_freqs[idx] << endl;
            // cout << m.digits[m.FindDigit(pt.content[index])].total_freq << endl;
        }
        if (pt.content[index].type == 3)
        {
            pt.prob *= m.symbols[m.FindSymbol(pt.content[index])].ordered_freqs[idx];
            pt.prob /= m.symbols[m.FindSymbol(pt.content[index])].total_freq;
            // cout << m.symbols[m.FindSymbol(pt.content[index])].ordered_freqs[idx] << endl;
            // cout << m.symbols[m.FindSymbol(pt.content[index])].total_freq << endl;
        }
        index += 1;
    }
    // cout << pt.prob << endl;
}

void PriorityQueue::init()
{
    // cout << m.ordered_pts.size() << endl;
    // 用所有可能的PT，按概率降序填满整个优先队列
    for (PT pt : m.ordered_pts)
    {
        for (segment seg : pt.content)
        {
            if (seg.type == 1)
            {
                // 下面这行代码的意义：
                // max_indices用来表示PT中各个segment的可能数目。例如，L6S1中，假设模型统计到了100个L6，那么L6对应的最大下标就是99
                // （但由于后面采用了"<"的比较关系，所以其实max_indices[0]=100）
                // m.FindLetter(seg): 找到一个letter segment在模型中的对应下标
                // m.letters[m.FindLetter(seg)]：一个letter segment在模型中对应的所有统计数据
                // m.letters[m.FindLetter(seg)].ordered_values：一个letter segment在模型中，所有value的总数目
                pt.max_indices.emplace_back(m.letters[m.FindLetter(seg)].ordered_values.size());
            }
            if (seg.type == 2)
            {
                pt.max_indices.emplace_back(m.digits[m.FindDigit(seg)].ordered_values.size());
            }
            if (seg.type == 3)
            {
                pt.max_indices.emplace_back(m.symbols[m.FindSymbol(seg)].ordered_values.size());
            }
        }
        pt.preterm_prob = float(m.preterm_freq[m.FindPT(pt)]) / m.total_preterm;
        // pt.PrintPT();
        // cout << " " << m.preterm_freq[m.FindPT(pt)] << " " << m.total_preterm << " " << pt.preterm_prob << endl;

        // 计算当前pt的概率
        CalProb(pt);
        // 将PT放入优先队列
        priority.emplace_back(pt);
    }
    // cout << "priority size:" << priority.size() << endl;
}

void PriorityQueue::PopNext()
{

    // 对优先队列最前面的PT，首先利用这个PT生成一系列猜测
    Generate(priority.front());

    // 然后需要根据即将出队的PT，生成一系列新的PT
    vector<PT> new_pts = priority.front().NewPTs();
    for (PT pt : new_pts)
    {
        // 计算概率
        CalProb(pt);
        // 接下来的这个循环，作用是根据概率，将新的PT插入到优先队列中
        for (auto iter = priority.begin(); iter != priority.end(); iter++)
        {
            // 对于非队首和队尾的特殊情况
            if (iter != priority.end() - 1 && iter != priority.begin())
            {
                // 判定概率
                if (pt.prob <= iter->prob && pt.prob > (iter + 1)->prob)
                {
                    priority.emplace(iter + 1, pt);
                    break;
                }
            }
            if (iter == priority.end() - 1)
            {
                priority.emplace_back(pt);
                break;
            }
            if (iter == priority.begin() && iter->prob < pt.prob)
            {
                priority.emplace(iter, pt);
                break;
            }
        }
    }

    // 现在队首的PT善后工作已经结束，将其出队（删除）
    priority.erase(priority.begin());
}

// 这个函数你就算看不懂，对并行算法的实现影响也不大
// 当然如果你想做一个基于多优先队列的并行算法，可能得稍微看一看了
vector<PT> PT::NewPTs()
{
    // 存储生成的新PT
    vector<PT> res;

    // 假如这个PT只有一个segment
    // 那么这个segment的所有value在出队前就已经被遍历完毕，并作为猜测输出
    // 因此，所有这个PT可能对应的口令猜测已经遍历完成，无需生成新的PT
    if (content.size() == 1)
    {
        return res;
    }
    else
    {
        // 最初的pivot值。我们将更改位置下标大于等于这个pivot值的segment的值（最后一个segment除外），并且一次只更改一个segment
        // 上面这句话里是不是有没看懂的地方？接着往下看你应该会更明白
        int init_pivot = pivot;

        // 开始遍历所有位置值大于等于init_pivot值的segment
        // 注意i < curr_indices.size() - 1，也就是除去了最后一个segment（这个segment的赋值预留给并行环节）
        for (int i = pivot; i < curr_indices.size() - 1; i += 1)
        {
            // curr_indices: 标记各segment目前的value在模型里对应的下标
            curr_indices[i] += 1;

            // max_indices：标记各segment在模型中一共有多少个value
            if (curr_indices[i] < max_indices[i])
            {
                // 更新pivot值
                pivot = i;
                res.emplace_back(*this);
            }

            // 这个步骤对于你理解pivot的作用、新PT生成的过程而言，至关重要
            curr_indices[i] -= 1;
        }
        pivot = init_pivot;
        return res;
    }

    return res;
}

#define MAX_LEN 32
#define CUDA_THRESHOLD 10000

__global__ void generateGuessesCUDA(const char* prefix, const char* all_values, const int* value_offsets,
                                    int num_values, char* output, int prefix_len, int max_len, int* d_flag)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_values) return;

    const char* val = all_values + value_offsets[idx];
    char* out = output + idx * max_len;

    // Copy prefix
    for (int i = 0; i < prefix_len && i < max_len - 1; ++i)
        out[i] = prefix[i];

    // Copy value
    int j = 0;
    while (val[j] != '\0' && (prefix_len + j) < max_len - 1)
    {
        out[prefix_len + j] = val[j];
        ++j;
    }
    out[prefix_len + j] = '\0';

    if (val[j] != '\0') {
        atomicExch(d_flag, 1);
    }
}

void PriorityQueue::Generate(PT pt)
{
    CalProb(pt);

    string prefix;
    if (pt.content.size() > 1)
    {
        int seg_idx = 0;
        for (int idx : pt.curr_indices) 
        {
            if (seg_idx >= pt.content.size() - 1) break;

            if (pt.content[seg_idx].type == 1)
                prefix += m.letters[m.FindLetter(pt.content[seg_idx])].ordered_values[idx];

            if (pt.content[seg_idx].type == 2)
                prefix += m.digits[m.FindDigit(pt.content[seg_idx])].ordered_values[idx];

            if (pt.content[seg_idx].type == 3)
                prefix += m.symbols[m.FindSymbol(pt.content[seg_idx])].ordered_values[idx];

            seg_idx++;
        }
    }

    segment* a;
    if (pt.content.back().type == 1)
        a = &m.letters[m.FindLetter(pt.content.back())];
    if (pt.content.back().type == 2)
        a = &m.digits[m.FindDigit(pt.content.back())];
    if (pt.content.back().type == 3)
        a = &m.symbols[m.FindSymbol(pt.content.back())];

    int num = pt.max_indices.back();

    // 如果猜测数量较小，直接用CPU串行生成所有猜测，避免GPU启动开销
    if (num < CUDA_THRESHOLD) 
    {
        // cout<<"[INFO] Use CPU"<<endl;
        for (int i = 0; i < num; ++i)
        {
            string g = prefix + a->ordered_values[i];
            guesses.emplace_back(g);
            total_guesses += 1;
        }
        return;
    }

    // cout<<"[INFO] Use GPU"<<endl;

    // 1. 分配并拷贝prefix字符串到GPU内存
    char* d_prefix;
    cudaMalloc(&d_prefix, prefix.size());
    cudaMemcpy(d_prefix, prefix.c_str(), prefix.size(), cudaMemcpyHostToDevice);

    // 2. 计算所有最后一个segment字符串的总长度（含结束符）
    size_t total_value_len = 0;
    for (int i = 0; i < num; ++i)
        total_value_len += a->ordered_values[i].size() + 1;

    // 3. 在CPU端连续分配内存，拷贝所有字符串并记录偏移
    int* value_offsets = new int[num];
    char* temp_all_values = new char[total_value_len];
    int offset = 0;
    for (int i = 0; i < num; ++i)
    {
        strcpy(temp_all_values + offset, a->ordered_values[i].c_str());
        value_offsets[i] = offset;
        offset += a->ordered_values[i].size() + 1;
    }

    // 4. 分配GPU内存并拷贝字符串数据
    char* d_all_values;
    cudaMalloc(&d_all_values, total_value_len);
    cudaMemcpy(d_all_values, temp_all_values, total_value_len, cudaMemcpyHostToDevice);

    // 5. 分配GPU内存并拷贝偏移数组
    int* d_offsets;
    cudaMalloc(&d_offsets, sizeof(int) * num);
    cudaMemcpy(d_offsets, value_offsets, sizeof(int) * num, cudaMemcpyHostToDevice);

    // 6. 分配GPU输出缓冲区，用于存储每条猜测字符串，长度为num * MAX_LEN
    char* d_output;
    cudaMalloc(&d_output, num * MAX_LEN);

    // 7. 分配GPU设备标志位内存（用于检测超长字符串等异常，初始化为0）
    int* d_flag;
    int h_flag = 0;
    cudaMalloc(&d_flag, sizeof(int));
    cudaMemcpy(d_flag, &h_flag, sizeof(int), cudaMemcpyHostToDevice);

    // 8. 启动CUDA核函数，执行猜测生成，线程块大小256，计算块数确保覆盖所有猜测
    int threads = 256;
    int blocks = (num + threads - 1) / threads;
    generateGuessesCUDA<<<blocks, threads>>>(d_prefix, d_all_values, d_offsets, num, d_output,
                                             prefix.size(), MAX_LEN, d_flag);
    cudaDeviceSynchronize();
    
    // 9. 拷贝设备标志位回CPU，检测是否有猜测超长被截断
    cudaMemcpy(&h_flag, d_flag, sizeof(int), cudaMemcpyDeviceToHost);
    if (h_flag) 
    {
        cerr << "[Warning] One or more guesses exceeded MAX_LEN and were truncated." << endl;
    }

    // 10. 从GPU拷贝生成的所有猜测回CPU内存
    char* h_output = new char[num * MAX_LEN];
    cudaMemcpy(h_output, d_output, num * MAX_LEN, cudaMemcpyDeviceToHost);

    // 11. 逐条将GPU生成的猜测存入全局猜测结果容器
    for (int i = 0; i < num; ++i)
    {
        guesses.emplace_back(h_output + i * MAX_LEN);
        total_guesses += 1;
    }

    // 12. 释放所有申请的GPU和CPU内存，防止内存泄漏
    cudaFree(d_prefix);
    cudaFree(d_all_values);
    cudaFree(d_offsets);
    cudaFree(d_output);
    cudaFree(d_flag);
    delete[] temp_all_values;
    delete[] value_offsets;
    delete[] h_output;
}