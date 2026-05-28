#include <cuda_runtime.h>
#include <tvm/ffi/container/tensor.h>
#include <tvm/ffi/error.h>
#include <tvm/ffi/function.h>

namespace hmdemo_mlsys26_contest {

void kernel(tvm::ffi::TensorView output) {
    (void)output;
    TVM_FFI_THROW(RuntimeError)
        << "TODO: implement solution/cuda/kernel.cu::kernel for the selected definition";
}

}  // namespace hmdemo_mlsys26_contest

TVM_FFI_DLL_EXPORT_TYPED_FUNC(kernel, hmdemo_mlsys26_contest::kernel);
