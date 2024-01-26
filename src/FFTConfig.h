// Copyright Mihai Preda

#pragma once

#include "common.h"

#include <string>
#include <tuple>
#include <vector>
#include <cmath>

// Format 'n' with a K or M suffix if multiple of 1024 or 1024*1024
string numberK(u32 n);

struct FFTConfig {
  static constexpr const float MIN_BPW = 6;

  // On 2020-03-30, I examined the middle=10 FFTs from 1.25M to 80M.
  // On this date, exponent 95460001 had an average roundoff error of 0.2441.
  // This should be periodically tested to make sure rocm optimizer hasn't made accuracy worse.
  //
  // I'm targetting an average max roundoff of 0.262, which ought to give us some roundoff
  // errors above 0.4 and I hope none above 0.5.  The 1.25M FFT ended up with 18.814 bits-per-word
  // and the 80M FFT ended up with 17.141 bits-per-word.  This gives a simple formula of
  //		bits-per-word = 18.814 - 0.279 * log2 (FFTsize / 1.25M)
  // At a later date, we might should create a different formula for each Middle value as
  // the multiplication chains in MiddleIn/Out may have a big affect on the roundoff error.
  //
  // Also note, that I did not see any evidence that we need to be more conservative during P-1.
  // However, P-1 does not output average max roundoff error, so I'm not 100% confident.
  //
  // On 2020-04-12 we implemented options to minimize multiply chain lengths in MiddleMul kernels.
  // This allows more bits-per-FFT-word.  We also gathered roundoff data for each MIDDLE length
  // for use in the calculations below.
  //
  // On 2020-06-01 we implemented MAX_ACCURACY and changed our target.  For max exponent we want a
  // pErr around 0.2%.  For the MM_CHAIN crossovers we target an even more conservative pErr since
  // the penalty for passing these "mini-crossovers" is quite small.
  static u32 getMaxExp(u32 fftSize, u32 middle) { return
      middle == 2 ? fftSize * (19.0766 - 0.279 * log2(fftSize / (1 * 1024 * 1024))) :
                middle == 3 ? fftSize * (19.0766 - 0.279 * log2(fftSize / (1.5 * 1024 * 1024))) :
                middle == 4 ? fftSize * (18.9862 - 0.279 * log2(fftSize / (2.0 * 1024 * 1024))) :
                middle == 5 ? fftSize * (18.8482 - 0.279 * log2(fftSize / (2.5 * 1024 * 1024))) :
                middle == 6 ? fftSize * (18.7810 - 0.279 * log2(fftSize / (3.0 * 1024 * 1024))) :
                middle == 7 ? fftSize * (18.7113 - 0.279 * log2(fftSize / (3.5 * 1024 * 1024))) :
                middle == 8 ? fftSize * (18.6593 - 0.279 * log2(fftSize / (4.0 * 1024 * 1024))) :
                middle == 9 ? fftSize * (18.6135 - 0.279 * log2(fftSize / (4.5 * 1024 * 1024))) :
                middle == 10 ? fftSize * (18.5719 - 0.279 * log2(fftSize / (5.0 * 1024 * 1024))) :
                middle == 11 ? fftSize * (18.5317 - 0.279 * log2(fftSize / (5.5 * 1024 * 1024))) :
                middle == 12 ? fftSize * (18.5185 - 0.279 * log2(fftSize / (6.0 * 1024 * 1024))) :
                middle == 13 ? fftSize * (18.4795 - 0.279 * log2(fftSize / (6.5 * 1024 * 1024))) :
                middle == 14 ? fftSize * (18.4451 - 0.279 * log2(fftSize / (7.0 * 1024 * 1024))) :
			       fftSize * (18.3804 - 0.279 * log2(fftSize / (7.5 * 1024 * 1024))); }
  
  static u32 getMaxCarry32(u32 fftSize, u32 exponent);
  static std::vector<FFTConfig> genConfigs();

  static tuple<u32, u32, bool> getChainLengths(u32 fftSize, u32 exponent, u32 middle);

  // FFTConfig(u32 w, u32 m, u32 h) : width(w), middle(m), height(h) {}
  static FFTConfig fromSpec(const string& spec);
  
  u32 width  = 0;
  u32 middle = 0;
  u32 height = 0;
    
  u32 fftSize() const { return width * height * middle * 2; }
  u32 maxExp() const { return getMaxExp(fftSize(), middle); }
  std::string spec() const { return numberK(width) + ':' + numberK(middle) + ':' + numberK(height); }
};
