/*******************************************************
 * Copyright (c) 2014, ArrayFire
 * All rights reserved.
 *
 * This file is distributed under 3-clause BSD license.
 * The complete license agreement can be obtained at:
 * http://arrayfire.com/licenses/BSD-3-Clause
 ********************************************************/

// Parts of this code sourced from SnopyDogy
// https://gist.github.com/SnopyDogy/a9a22497a893ec86aa3e

#if defined(WITH_GRAPHICS)

#include <interopManager.hpp>
#include <err_cuda.hpp>
#include <cstdio>

namespace cuda
{

void InteropManager::destroyResources()
{
    int n = getActiveDeviceId();
    for(iter_t iter = interop_maps[n].begin(); iter != interop_maps[n].end(); iter++)
        CUDA_CHECK(cudaGraphicsUnregisterResource(iter->second));
}

InteropManager::~InteropManager()
{
    for(int i = 0; i < getDeviceCount(); i++) {
        setDevice(i);
        destroyResources();
    }
}

InteropManager& InteropManager::getInstance()
{
    static InteropManager my_instance;
    return my_instance;
}

cudaGraphicsResource* InteropManager::getBufferResource(const fg_image_handle key)
{
    int device = getActiveDeviceId();

    if(interop_maps[device].find(key) == interop_maps[device].end()) {
        cudaGraphicsResource *cudaPBOResource;
        // Register PBO with CUDA
        CUDA_CHECK(cudaGraphicsGLRegisterBuffer(&cudaPBOResource, key->gl_PBO, cudaGraphicsMapFlagsWriteDiscard));
        interop_maps[device][key] = cudaPBOResource;
    }

    return interop_maps[device][key];
}

cudaGraphicsResource* InteropManager::getBufferResource(const fg_plot_handle key)
{
    int device = getActiveDeviceId();

    iter_t iter = interop_maps[device].find(key);

    if(iter == interop_maps[device].end()) {

        // Not found. Create New
        cudaGraphicsResource *cudaVBOResource;
        // Register VBO with CUDA
        CUDA_CHECK(cudaGraphicsGLRegisterBuffer(&cudaVBOResource, key->gl_vbo[0], cudaGraphicsMapFlagsWriteDiscard));
        interop_maps[device][key] = cudaVBOResource;

    } else {

        // Find a better way to handle this
        // Problem is cudaGraphicsResource keeps the same size until it is
        // unregistered

        // Buffer was found
        cudaGraphicsResource *cudaVBOResource = iter->second;
        // Check if buffer size is same
        void* d_vbo = NULL;
        size_t num_bytes = 0;
        cudaGraphicsMapResources(1, &cudaVBOResource, 0);
        cudaGraphicsResourceGetMappedPointer((void **)&d_vbo, &num_bytes, cudaVBOResource);
        cudaGraphicsUnmapResources(1, &cudaVBOResource, 0);

        if(num_bytes != key->vbosize) {
            // Delete and reallocate
            CUDA_CHECK(cudaGraphicsUnregisterResource(cudaVBOResource));
            CUDA_CHECK(cudaGraphicsGLRegisterBuffer(&cudaVBOResource, key->gl_vbo[0],
                       cudaGraphicsMapFlagsWriteDiscard));
            interop_maps[device][key] = cudaVBOResource;
        }
    }

    return interop_maps[device][key];
}

}

#endif
