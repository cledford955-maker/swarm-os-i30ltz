#pragma once

#include <vector>
#include <cstdint>
#include <cstddef>
#include <string>

namespace lucille {

// Embedding dimension constants (e.g. bge-small / all-MiniLM-L6-v2 = 384)
constexpr size_t kDefaultEmbeddingDim = 384;
constexpr size_t kBinaryWords384 = (kDefaultEmbeddingDim + 63) / 64; // 6 words = 48 bytes

class SimdQuant {
public:
    // --- 1. Float32 SIMD Acceleration (AVX2 / FMA / NEON) ---
    
    // Dot product between two float arrays (dimension should be a multiple of 8 or handled with remainder)
    static float dot_product_f32(const float* a, const float* b, size_t dim);

    // In-place L2 normalization: v_i = v_i / ||v||_2
    static float l2_normalize_f32(float* vec, size_t dim);

    // Cosine distance: 1.0 - dot_product(norm_a, norm_b)
    static float cosine_distance_f32(const float* a, const float* b, size_t dim);

    // --- 2. Int8 Scalar Quantization ---
    
    struct Int8QuantizedVector {
        std::vector<int8_t> data;
        float scale{1.0f};
        float offset{0.0f};
    };

    // Quantize float32 embedding into signed 8-bit integers
    static Int8QuantizedVector quantize_int8(const float* src, size_t dim);

    // Dequantize int8 back to float32
    static std::vector<float> dequantize_int8(const Int8QuantizedVector& qvec);

    // Fast SIMD integer dot product
    static int32_t dot_product_int8(const int8_t* a, const int8_t* b, size_t dim);

    // --- 3. 1-Bit Binary Quantization ---
    
    struct BinaryQuantizedVector {
        std::vector<uint64_t> words; // Packed 64-bits words
        size_t bit_dim{0};
    };

    // Pack float signs into binary bits (bit=1 if x > 0 else 0)
    static BinaryQuantizedVector quantize_binary(const float* src, size_t dim);

    // Fast Hamming distance using bitwise XOR and popcount
    static uint32_t hamming_distance_binary(const BinaryQuantizedVector& a, const BinaryQuantizedVector& b);

    // Check CPU features at runtime
    static std::string get_simd_capabilities();
};

} // namespace lucille
