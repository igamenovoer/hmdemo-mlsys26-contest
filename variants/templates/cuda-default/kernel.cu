#include <cuda_runtime.h>
#include <tvm/ffi/container/tensor.h>
#include <tvm/ffi/error.h>
#include <tvm/ffi/function.h>

namespace cuda_variant {

void kernel(tvm::ffi::TensorView output) {
    (void)output;
    TVM_FFI_THROW(RuntimeError)
        << "TODO: implement this variant's kernel.cu::kernel for the selected definition";
}

}  // namespace cuda_variant

TVM_FFI_DLL_EXPORT_TYPED_FUNC(kernel, cuda_variant::kernel);
