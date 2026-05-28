# Kernel Contracts

This page records the callable CUDA TVM-FFI contracts needed to create minimal runnable kernels for the MoE and DSA contest definitions in this repository. The source of truth is the local dataset definitions under `extern/orphan/mlsys26-contest/definitions/` plus the installed `flashinfer_bench` destination-passing call path.

The repository CUDA path uses `language = "cuda"`, `entry_point = "kernel.cu::kernel"`, `binding = "tvm-ffi"`, and `destination_passing_style = true`. The callable receives all definition inputs in definition order, followed by all output tensors in definition order. Use `tvm::ffi::TensorView` for tensors, `double` for scalar float inputs, and `int64_t` for scalar integer inputs.

```cpp
#include <cstdint>
#include <tvm/ffi/container/tensor.h>
#include <tvm/ffi/function.h>

using tvm::ffi::TensorView;
```

Local benchmarking checks correctness before accepting performance timing. A kernel that only builds and writes placeholder outputs is useful for validating the interface, but it will not produce a passed timing result unless it also satisfies correctness.

## MoE

Definition ID: `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`

Only `seq_len` varies across workloads. Fixed geometry:

- `num_experts = 256`
- `num_local_experts = 32`
- `hidden_size = 7168`
- `intermediate_size = 2048`
- `gemm1_out_size = 4096`
- `block_size = 128`
- `num_hidden_blocks = 56`
- `num_intermediate_blocks = 16`
- `num_gemm1_out_blocks = 32`
- `top_k = 8`
- `n_group = 8`
- `topk_group = 4`

Input order:

| Pos | Name | Shape | Dtype |
| --- | --- | --- | --- |
| 1 | `routing_logits` | `[seq_len, 256]` | `float32` |
| 2 | `routing_bias` | `[256]` | `bfloat16` |
| 3 | `hidden_states` | `[seq_len, 7168]` | `float8_e4m3fn` |
| 4 | `hidden_states_scale` | `[56, seq_len]` | `float32` |
| 5 | `gemm1_weights` | `[32, 4096, 7168]` | `float8_e4m3fn` |
| 6 | `gemm1_weights_scale` | `[32, 32, 56]` | `float32` |
| 7 | `gemm2_weights` | `[32, 7168, 2048]` | `float8_e4m3fn` |
| 8 | `gemm2_weights_scale` | `[32, 56, 16]` | `float32` |
| 9 | `local_expert_offset` | scalar | `int32` logical, pass as `int64_t` |
| 10 | `routed_scaling_factor` | scalar | `float32` logical, pass as `double` |

Output order:

| Pos | Name | Shape | Dtype |
| --- | --- | --- | --- |
| 11 | `output` | `[seq_len, 7168]` | `bfloat16` |

TVM-FFI destination-passing signature:

```cpp
void kernel(
    TensorView routing_logits,
    TensorView routing_bias,
    TensorView hidden_states,
    TensorView hidden_states_scale,
    TensorView gemm1_weights,
    TensorView gemm1_weights_scale,
    TensorView gemm2_weights,
    TensorView gemm2_weights_scale,
    int64_t local_expert_offset,
    double routed_scaling_factor,
    TensorView output);
```

For local timing, set `config.toml` to this exact definition ID. Coarse names such as `fused_moe` are not present in the local trace set definitions.

## DSA Sparse Attention

Definition ID: `dsa_sparse_attention_h16_ckv512_kpe64_topk2048_ps64`

Variable axes are `num_tokens` and `num_pages`. Fixed geometry:

- `num_qo_heads = 16`
- `head_dim_ckv = 512`
- `head_dim_kpe = 64`
- `page_size = 64`
- `topk = 2048`

Input order:

| Pos | Name | Shape | Dtype |
| --- | --- | --- | --- |
| 1 | `q_nope` | `[num_tokens, 16, 512]` | `bfloat16` |
| 2 | `q_pe` | `[num_tokens, 16, 64]` | `bfloat16` |
| 3 | `ckv_cache` | `[num_pages, 64, 512]` | `bfloat16` |
| 4 | `kpe_cache` | `[num_pages, 64, 64]` | `bfloat16` |
| 5 | `sparse_indices` | `[num_tokens, 2048]` | `int32` |
| 6 | `sm_scale` | scalar | `float32` logical, pass as `double` |

Output order:

| Pos | Name | Shape | Dtype |
| --- | --- | --- | --- |
| 7 | `output` | `[num_tokens, 16, 512]` | `bfloat16` |
| 8 | `lse` | `[num_tokens, 16]` | `float32` |

TVM-FFI destination-passing signature:

```cpp
void kernel(
    TensorView q_nope,
    TensorView q_pe,
    TensorView ckv_cache,
    TensorView kpe_cache,
    TensorView sparse_indices,
    double sm_scale,
    TensorView output,
    TensorView lse);
```

`sparse_indices` uses `-1` for invalid padding entries. For `page_size = 64`, valid entries encode token locations as `page_idx * 64 + offset`.

## DSA Top-K Indexer

Definition ID: `dsa_topk_indexer_fp8_h64_d128_topk2048_ps64`

Variable axes are `batch_size`, `max_num_pages`, and `num_pages`. Fixed geometry:

- `num_index_heads = 64`
- `index_head_dim = 128`
- `page_size = 64`
- `topk = 2048`
- `kv_cache_num_heads = 1`
- `head_dim_with_scale = 132`

Input order:

| Pos | Name | Shape | Dtype |
| --- | --- | --- | --- |
| 1 | `q_index_fp8` | `[batch_size, 64, 128]` | `float8_e4m3fn` |
| 2 | `k_index_cache_fp8` | `[num_pages, 64, 1, 132]` | `int8` storage interpreted as FP8 bytes plus scales |
| 3 | `weights` | `[batch_size, 64]` | `float32` |
| 4 | `seq_lens` | `[batch_size]` | `int32` |
| 5 | `block_table` | `[batch_size, max_num_pages]` | `int32` |

Output order:

| Pos | Name | Shape | Dtype |
| --- | --- | --- | --- |
| 6 | `topk_indices` | `[batch_size, 2048]` | `int32` |

TVM-FFI destination-passing signature:

```cpp
void kernel(
    TensorView q_index_fp8,
    TensorView k_index_cache_fp8,
    TensorView weights,
    TensorView seq_lens,
    TensorView block_table,
    TensorView topk_indices);
```

`topk_indices` uses `-1` for padding when a sequence has fewer than 2048 valid tokens. Valid output indices are token indices in the physical paged cache space.

## Verification Targets

When updating this page, verify against these local files:

- `extern/orphan/mlsys26-contest/definitions/moe/moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048.json`
- `extern/orphan/mlsys26-contest/definitions/dsa_paged/dsa_sparse_attention_h16_ckv512_kpe64_topk2048_ps64.json`
- `extern/orphan/mlsys26-contest/definitions/dsa_paged/dsa_topk_indexer_fp8_h64_d128_topk2048_ps64.json`
- `extern/orphan/mlsys26-contest/solutions/baseline/moe/`
- `extern/orphan/mlsys26-contest/solutions/baseline/dsa/`
