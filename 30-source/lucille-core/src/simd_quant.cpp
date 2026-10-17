#include "simd_quant.hpp"
#include <cmath>
#include <cstring>
#include <algorithm>
#include <sstream>

#if defined(__x86_64__) || defined(_M_X64)
#include <immintrin.h>
#endif

#if defined(__ARM_NEON) || defined(__aarch64__)
#include <arm_neon.h>
#endif

namespace lucille {

float SimdQuant::dot_product_f32(const float* a, const float* b, size_t dim) {
    if (!a || !b || dim == 0) return 0.0f;

    size_t i = 0;
    float sum = 0.0f;

#if defined(__AVX2__)
    __m256 acc0 = _mm256_setzero_ps();
    __m256 acc1 = _mm256_setzero_ps();
    __m256 acc2 = _mm256_setzero_ps();
    __m256 acc3 = _mm256_setzero_ps();

    // Process 32 floats per loop iteration (4 x 8-wide AVX2 registers)
    for (; i + 31 < dim; i += 32) {
        __m256 va0 = _mm256_loadu_ps(a + i);
        __m256 vb0 = _mm256_loadu_ps(b + i);
#if defined(__FMA__)
        acc0 = _mm256_fmadd_ps(va0, vb0, acc0);
#else
        acc0 = _mm256_add_ps(acc0, _mm256_mul_ps(va0, vb0));
#endif

        __m256 va1 = _mm256_loadu_ps(a + i + 8);
        __m256 vb1 = _mm256_loadu_ps(b + i + 8);
#if defined(__FMA__)
        acc1 = _mm256_fmadd_ps(va1, vb1, acc1);
#else
        acc1 = _mm256_add_ps(acc1, _mm256_mul_ps(va1, vb1));
#endif

        __m256 va2 = _mm256_loadu_ps(a + i + 16);
        __m256 vb2 = _mm256_loadu_ps(b + i + 16);
#if defined(__FMA__)
        acc2 = _mm256_fmadd_ps(va2, vb2, acc2);
#else
        acc2 = _mm256_add_ps(acc2, _mm256_mul_ps(va2, vb2));
#endif

        __m256 va3 = _mm256_loadu_ps(a + i + 24);
        __m256 vb3 = _mm256_loadu_ps(b + i + 24);
#if defined(__FMA__)
        acc3 = _mm256_fmadd_ps(va3, vb3, acc3);
#else
        acc3 = _mm256_add_ps(acc3, _mm256_mul_ps(va3, vb3));
#endif
    }

    // Process remaining 8-wide blocks
    for (; i + 7 < dim; i += 8) {
        __m256 va = _mm256_loadu_ps(a + i);
        __m256 vb = _mm256_loadu_ps(b + i);
#if defined(__FMA__)
        acc0 = _mm256_fmadd_ps(va, vb, acc0);
#else
        acc0 = _mm256_add_ps(acc0, _mm256_mul_ps(va, vb));
#endif
    }

    acc0 = _mm256_add_ps(acc0, acc1);
    acc2 = _mm256_add_ps(acc2, acc3);
    acc0 = _mm256_add_ps(acc0, acc2);

    // Horizontal add of 8 floats in __m256
    alignas(32) float temp[8];
    _mm256_storeu_ps(temp, acc0);
    sum = temp[0] + temp[1] + temp[2] + temp[3] + temp[4] + temp[5] + temp[6] + temp[7];

#elif defined(__ARM_NEON) || defined(__aarch64__)
    float32x4_t acc0 = vdupq_n_f32(0.0f);
    float32x4_t acc1 = vdupq_n_f32(0.0f);

    for (; i + 7 < dim; i += 8) {
        float32x4_t va0 = vld1q_f32(a + i);
        float32x4_t vb0 = vld1q_f32(b + i);
        acc0 = vmlaq_f32(acc0, va0, vb0);

        float32x4_t va1 = vld1q_f32(a + i + 4);
        float32x4_t vb1 = vld1q_f32(b + i + 4);
        acc1 = vmlaq_f32(acc1, va1, vb1);
    }
    acc0 = vaddq_f32(acc0, acc1);
    sum = vaddvq_f32(acc0);
#endif

    // Handle remaining scalar elements
    for (; i < dim; ++i) {
        sum += a[i] * b[i];
    }

    return sum;
}

float SimdQuant::l2_normalize_f32(float* vec, size_t dim) {
    if (!vec || dim == 0) return 0.0f;

    float sum_sq = dot_product_f32(vec, vec, dim);
    float norm = std::sqrt(sum_sq);

    if (norm < 1e-12f) {
        return 0.0f;
    }

    float inv_norm = 1.0f / norm;
    size_t i = 0;

#if defined(__AVX2__)
    __m256 vinv = _mm256_set1_ps(inv_norm);
    for (; i + 7 < dim; i += 8) {
        __m256 v = _mm256_loadu_ps(vec + i);
        v = _mm256_mul_ps(v, vinv);
        _mm256_storeu_ps(vec + i, v);
    }
#elif defined(__ARM_NEON) || defined(__aarch64__)
    float32x4_t vinv = vdupq_n_f32(inv_norm);
    for (; i + 3 < dim; i += 4) {
        float32x4_t v = vld1q_f32(vec + i);
        v = vmulq_f32(v, vinv);
        vst1q_f32(vec + i, v);
    }
#endif

    for (; i < dim; ++i) {
        vec[i] *= inv_norm;
    }

    return norm;
}

float SimdQuant::cosine_distance_f32(const float* a, const float* b, size_t dim) {
    float dot = dot_product_f32(a, b, dim);
    // Assuming a and b are normalized, distance = 1.0 - dot
    float dist = 1.0f - dot;
    return (dist < 0.0f) ? 0.0f : ((dist > 2.0f) ? 2.0f : dist);
}

SimdQuant::Int8QuantizedVector SimdQuant::quantize_int8(const float* src, size_t dim) {
    Int8QuantizedVector result;
    result.data.resize(dim);
    if (!src || dim == 0) return result;

    // Find maximum absolute value
    float max_abs = 0.0f;
    for (size_t i = 0; i < dim; ++i) {
        max_abs = std::max(max_abs, std::abs(src[i]));
    }

    if (max_abs < 1e-9f) {
        result.scale = 1.0f;
        std::fill(result.data.begin(), result.data.end(), 0);
        return result;
    }

    float scale = 127.0f / max_abs;
    result.scale = scale;

    size_t i = 0;
#if defined(__AVX2__)
    __m256 vscale = _mm256_set1_ps(scale);
    for (; i + 7 < dim; i += 8) {
        __m256 vf = _mm256_loadu_ps(src + i);
        __m256 vscaled = _mm256_mul_ps(vf, vscale);
        __m256i vi32 = _mm256_cvtps_epi32(vscaled);

        // Pack 32-bit ints to 16-bit, then to 8-bit
        alignas(32) int32_t temp[8];
        _mm256_storeu_si256(reinterpret_cast<__m256i*>(temp), vi32);
        for (int k = 0; k < 8; ++k) {
            int val = std::clamp(temp[k], -127, 127);
            result.data[i + k] = static_cast<int8_t>(val);
        }
    }
#endif

    for (; i < dim; ++i) {
        int val = static_cast<int>(std::round(src[i] * scale));
        result.data[i] = static_cast<int8_t>(std::clamp(val, -127, 127));
    }

    return result;
}

std::vector<float> SimdQuant::dequantize_int8(const Int8QuantizedVector& qvec) {
    std::vector<float> result(qvec.data.size());
    float inv_scale = (qvec.scale > 1e-9f) ? (1.0f / qvec.scale) : 1.0f;

    for (size_t i = 0; i < qvec.data.size(); ++i) {
        result[i] = static_cast<float>(qvec.data[i]) * inv_scale;
    }
    return result;
}

int32_t SimdQuant::dot_product_int8(const int8_t* a, const int8_t* b, size_t dim) {
    if (!a || !b || dim == 0) return 0;

    int32_t sum = 0;
    size_t i = 0;

    // Scalar fallback with auto-vectorization
    for (; i < dim; ++i) {
        sum += static_cast<int32_t>(a[i]) * static_cast<int32_t>(b[i]);
    }
    return sum;
}

SimdQuant::BinaryQuantizedVector SimdQuant::quantize_binary(const float* src, size_t dim) {
    BinaryQuantizedVector result;
    result.bit_dim = dim;
    size_t num_words = (dim + 63) / 64;
    result.words.assign(num_words, 0ULL);

    if (!src || dim == 0) return result;

    for (size_t i = 0; i < dim; ++i) {
        if (src[i] > 0.0f) {
            size_t word_idx = i / 64;
            size_t bit_idx = i % 64;
            result.words[word_idx] |= (1ULL << bit_idx);
        }
    }

    return result;
}

uint32_t SimdQuant::hamming_distance_binary(const BinaryQuantizedVector& a, const BinaryQuantizedVector& b) {
    size_t words = std::min(a.words.size(), b.words.size());
    uint32_t dist = 0;

    for (size_t i = 0; i < words; ++i) {
        uint64_t xor_val = a.words[i] ^ b.words[i];
        dist += static_cast<uint32_t>(__builtin_popcountll(xor_val));
    }
    return dist;
}

std::string SimdQuant::get_simd_capabilities() {
    std::stringstream ss;
#if defined(__AVX2__)
    ss << "AVX2 ";
#endif
#if defined(__FMA__)
    ss << "FMA ";
#endif
#if defined(__ARM_NEON)
    ss << "ARM-NEON ";
#endif
    if (ss.str().empty()) {
        ss << "Scalar-AutoVec";
    }
    return ss.str();
}

} // namespace lucille
