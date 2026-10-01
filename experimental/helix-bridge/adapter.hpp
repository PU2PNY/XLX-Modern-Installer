#pragma once
#include <array>
#include <cstdint>

namespace xuv {

using XlxVoice9 = std::array<std::uint8_t, 9>;
using Bits72 = std::array<std::uint8_t, 72>;
using Dibits36 = std::array<std::uint8_t, 36>;

// D-STAR no XLX: 9 bytes = 72 bits, MSB primeiro.
Bits72 dstar_bytes_to_bits(const XlxVoice9& in);
XlxVoice9 dstar_bits_to_bytes(const Bits72& in);

// AMBE+2 no XLX/DMR/YSF: 9 bytes = 36 dibits de 2 bits, MSB primeiro.
Dibits36 ambe2_bytes_to_dibits(const XlxVoice9& in);
XlxVoice9 ambe2_dibits_to_bytes(const Dibits36& in);

} // namespace xuv
