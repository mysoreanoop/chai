#include "hip/hip_runtime.h"
/*
 * Copyright (c) 2016 University of Cordoba and University of Illinois
 * All rights reserved.
 *
 * Developed by:    IMPACT Research Group
 *                  University of Cordoba and University of Illinois
 *                  http://impact.crhc.illinois.edu/
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * with the Software without restriction, including without limitation the 
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 *      > Redistributions of source code must retain the above copyright notice,
 *        this list of conditions and the following disclaimers.
 *      > Redistributions in binary form must reproduce the above copyright
 *        notice, this list of conditions and the following disclaimers in the
 *        documentation and/or other materials provided with the distribution.
 *      > Neither the names of IMPACT Research Group, University of Cordoba, 
 *        University of Illinois nor the names of its contributors may be used 
 *        to endorse or promote products derived from this Software without 
 *        specific prior written permission.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
 * CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS WITH
 * THE SOFTWARE.
 *
 */

#define _CUDA_COMPILER_

#include "support/common.h"

// HIP kernel ------------------------------------------------------------------------------------------
__global__ void TaskQueue_gpu(task_t *queues, int *n_task_in_queue, int *n_written_tasks, int *n_consumed_tasks, 
    int *data, int gpuQueueSize, int iterations) {

    HIP_DYNAMIC_SHARED( int, l_mem)
    int* last_queue = l_mem;
    task_t* t = (task_t*)&last_queue[1];

    const int tid       = threadIdx.x;
    const int tile_size = blockDim.x;

    while(true) {
        // Fetch task
        if(tid == 0) {
            int  idx_queue = *last_queue;
            int  j, jj;
            bool not_done = true;

            do {
                if(atomicAdd(n_consumed_tasks + idx_queue, 0) == atomicAdd(n_written_tasks + idx_queue, 0)) { //if(atomicAdd_system(n_consumed_tasks + idx_queue, 0) == atomicAdd_system(n_written_tasks + idx_queue, 0)) {
                    idx_queue = (idx_queue + 1) % NUM_TASK_QUEUES;
                } else {
                    if(atomicAdd(n_task_in_queue + idx_queue, 0) > 0) { //atomicAdd_system(n_task_in_queue + idx_queue, 0)
                        j = atomicAdd(n_task_in_queue + idx_queue, -1) - 1; //atomicAdd_system(n_task_in_queue + idx_queue, -1)
                        if(j >= 0) {
                            t->id    = (queues + idx_queue * gpuQueueSize + j)->id;
                            t->op    = (queues + idx_queue * gpuQueueSize + j)->op;
                            jj       = atomicAdd(n_consumed_tasks + idx_queue, 1) + 1; //atomicAdd_system(n_consumed_tasks + idx_queue, 1)
                            not_done = false;
                            if(jj == atomicAdd(n_written_tasks + idx_queue, 0)) { //atomicAdd_system(n_written_tasks + idx_queue, 0)
                                idx_queue = (idx_queue + 1) % NUM_TASK_QUEUES;
                            }
                            *last_queue = idx_queue;
                        } else {
                            idx_queue = (idx_queue + 1) % NUM_TASK_QUEUES;
                        }
                    } else {
                        idx_queue = (idx_queue + 1) % NUM_TASK_QUEUES;
                    }
                }
            } while(not_done);
        }
        __syncthreads();

        // Compute task
        if(t->op == SIGNAL_STOP_KERNEL) {
            break;
        } else {
            if(t->op == SIGNAL_WORK_KERNEL) {
                for(int i = 0; i < iterations; i++) {
                    data[t->id * tile_size + tid] += tile_size;
                }

                data[t->id * tile_size + tid] += t->id;
            }
            if(t->op == SIGNAL_NOTWORK_KERNEL) {
                for(int i = 0; i < 1; i++) {
                    data[t->id * tile_size + tid] += tile_size;
                }

                data[t->id * tile_size + tid] += t->id;
            }
        }
    }
}

hipError_t call_TaskQueue_gpu(int blocks, int threads, task_t *queues, int *n_task_in_queue, 
    int *n_written_tasks, int *n_consumed_tasks, int *data, int gpuQueueSize, int iterations, 
    int l_mem_size){

    dim3 dimGrid(blocks);
    dim3 dimBlock(threads);
    hipLaunchKernelGGL(TaskQueue_gpu, dim3(dimGrid), dim3(dimBlock), l_mem_size, 0, queues, n_task_in_queue, n_written_tasks, 
        n_consumed_tasks, data, gpuQueueSize, iterations);
    
    hipError_t err = hipGetLastError();
    return err;
}
